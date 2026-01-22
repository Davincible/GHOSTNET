// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { IGameRegistry } from "./interfaces/IGameRegistry.sol";
import { IArcadeGame } from "./interfaces/IArcadeGame.sol";
import { IArcadeCore } from "./interfaces/IArcadeCore.sol";

/// @title GameRegistry
/// @notice Central registry for GHOSTNET Arcade games with metadata and lifecycle management
/// @dev Manages game registration, configuration, and provides grace period for removal.
///      Coordinates with ArcadeCore for actual game registration/unregistration.
///
/// Architecture:
/// - GameRegistry: Stores metadata (GameInfo), entry configs, handles removal grace period
/// - ArcadeCore: Handles session tracking, payouts, deposits (source of truth for financial ops)
/// - When a game is registered here, it's also registered in ArcadeCore
/// - When a game is removed here (after grace period), it's unregistered from ArcadeCore
///
/// Security:
/// - Uses Ownable2Step for safe ownership transfer
/// - 7-day grace period for game removal (allows players to withdraw)
/// - Removal can be cancelled during grace period
/// - Pausing is instant (emergency response)
///
/// @custom:security-contact security@ghostnet.game
contract GameRegistry is Ownable2Step, IGameRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Grace period before a game can be removed
    /// @dev 7 days allows players to withdraw pending payouts
    uint256 public constant REMOVAL_GRACE_PERIOD = 7 days;

    /// @notice Maximum rake in basis points (10%)
    uint16 public constant MAX_RAKE_BPS = 1000;

    /// @notice Maximum burn in basis points (100%)
    uint16 public constant MAX_BURN_BPS = 10_000;

    /// @notice Basis points denominator
    uint16 private constant BPS = 10_000;

    // ══════════════════════════════════════════════════════════════════════════════
    // STORAGE
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Reference to ArcadeCore contract
    IArcadeCore public arcadeCore;

    /// @notice Set of all registered game addresses
    EnumerableSet.AddressSet private _registeredGames;

    /// @notice Game metadata by address
    mapping(address game => GameInfo info) private _gameInfo;

    /// @notice Entry configuration by game address
    mapping(address game => EntryConfig config) private _entryConfigs;

    /// @notice Pause status by game address
    mapping(address game => bool paused) private _gamePaused;

    /// @notice Pending removal timestamps (0 = not pending removal)
    mapping(address game => uint256 removalTime) private _pendingRemovals;

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Initialize the GameRegistry
    /// @param owner_ Address that will own this registry
    /// @param arcadeCore_ Address of the ArcadeCore contract
    constructor(
        address owner_,
        address arcadeCore_
    ) Ownable(owner_) {
        if (arcadeCore_ == address(0)) revert ZeroAddress();
        arcadeCore = IArcadeCore(arcadeCore_);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // GAME QUERIES (IGameRegistry)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IGameRegistry
    function isGameRegistered(
        address game
    ) external view returns (bool registered) {
        return _registeredGames.contains(game);
    }

    /// @inheritdoc IGameRegistry
    function isGamePaused(
        address game
    ) external view returns (bool paused) {
        return _gamePaused[game];
    }

    /// @inheritdoc IGameRegistry
    function getEntryConfig(
        address game
    ) external view returns (EntryConfig memory config) {
        if (!_registeredGames.contains(game)) revert GameNotRegistered();
        return _entryConfigs[game];
    }

    /// @inheritdoc IGameRegistry
    function getGameInfo(
        address game
    ) external view returns (GameInfo memory info) {
        if (!_registeredGames.contains(game)) revert GameNotRegistered();
        return _gameInfo[game];
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADDITIONAL VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get all registered game addresses
    /// @return games Array of registered game addresses
    function getAllGames() external view returns (address[] memory games) {
        return _registeredGames.values();
    }

    /// @notice Get number of registered games
    /// @return count Number of registered games
    function getGameCount() external view returns (uint256 count) {
        return _registeredGames.length();
    }

    /// @notice Get pending removal time for a game
    /// @param game Game address
    /// @return removalTime Timestamp when removal can be completed (0 if not pending)
    function getPendingRemoval(
        address game
    ) external view returns (uint256 removalTime) {
        return _pendingRemovals[game];
    }

    /// @notice Check if a game can be removed (grace period passed)
    /// @param game Game address
    /// @return canRemove True if grace period has passed
    function canRemoveGame(
        address game
    ) external view returns (bool canRemove) {
        uint256 removalTime = _pendingRemovals[game];
        return removalTime > 0 && block.timestamp >= removalTime;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS (IGameRegistry)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IGameRegistry
    function registerGame(
        address game,
        EntryConfig calldata config
    ) external onlyOwner {
        if (game == address(0)) revert ZeroAddress();
        if (_registeredGames.contains(game)) revert GameAlreadyRegistered();

        // Validate configuration
        _validateEntryConfig(config);

        // Fetch game info from the game contract
        GameInfo memory info = _fetchGameInfo(game);

        // Store in registry
        _registeredGames.add(game);
        _gameInfo[game] = info;
        _entryConfigs[game] = config;
        _gamePaused[game] = false;

        // Register in ArcadeCore with converted config
        IArcadeCore.GameConfig memory coreConfig = _toGameConfig(config);
        arcadeCore.registerGame(game, coreConfig);

        emit GameRegistered(game, info.gameId, info.name);
    }

    /// @inheritdoc IGameRegistry
    function pauseGame(
        address game
    ) external onlyOwner {
        if (!_registeredGames.contains(game)) revert GameNotRegistered();

        _gamePaused[game] = true;

        // Also pause in ArcadeCore
        arcadeCore.pauseGame(game);

        emit GamePaused(game);
    }

    /// @inheritdoc IGameRegistry
    function unpauseGame(
        address game
    ) external onlyOwner {
        if (!_registeredGames.contains(game)) revert GameNotRegistered();

        _gamePaused[game] = false;

        // Also unpause in ArcadeCore
        arcadeCore.unpauseGame(game);

        emit GameUnpaused(game);
    }

    /// @inheritdoc IGameRegistry
    function updateEntryConfig(
        address game,
        EntryConfig calldata config
    ) external onlyOwner {
        if (!_registeredGames.contains(game)) revert GameNotRegistered();

        // Validate configuration
        _validateEntryConfig(config);

        // Update local storage
        _entryConfigs[game] = config;

        // Update in ArcadeCore
        IArcadeCore.GameConfig memory coreConfig = _toGameConfig(config);
        coreConfig.paused = _gamePaused[game]; // Preserve pause state
        arcadeCore.updateGameConfig(game, coreConfig);

        emit GameConfigUpdated(game);
    }

    /// @inheritdoc IGameRegistry
    function markGameForRemoval(
        address game
    ) external onlyOwner {
        if (!_registeredGames.contains(game)) revert GameNotRegistered();
        if (_pendingRemovals[game] > 0) revert GameAlreadyRegistered(); // Already marked

        uint256 removalTime = block.timestamp + REMOVAL_GRACE_PERIOD;
        _pendingRemovals[game] = removalTime;

        // Pause the game immediately to prevent new entries
        if (!_gamePaused[game]) {
            _gamePaused[game] = true;
            arcadeCore.pauseGame(game);
            emit GamePaused(game);
        }

        emit GameMarkedForRemoval(game, removalTime);
    }

    /// @inheritdoc IGameRegistry
    function cancelGameRemoval(
        address game
    ) external onlyOwner {
        if (_pendingRemovals[game] == 0) revert GameNotRegistered();

        delete _pendingRemovals[game];

        emit GameRemovalCancelled(game);
    }

    /// @inheritdoc IGameRegistry
    function removeGame(
        address game
    ) external onlyOwner {
        uint256 removalTime = _pendingRemovals[game];
        if (removalTime == 0) revert GameNotRegistered();
        if (block.timestamp < removalTime) {
            revert InvalidConfig(); // Grace period not passed
        }

        // Clear storage
        _registeredGames.remove(game);
        delete _gameInfo[game];
        delete _entryConfigs[game];
        delete _gamePaused[game];
        delete _pendingRemovals[game];

        // Unregister from ArcadeCore
        arcadeCore.unregisterGame(game);

        emit GameRemoved(game);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN CONFIGURATION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Update the ArcadeCore reference
    /// @dev Only callable by owner, use with caution
    /// @param newArcadeCore New ArcadeCore contract address
    function setArcadeCore(
        address newArcadeCore
    ) external onlyOwner {
        if (newArcadeCore == address(0)) revert ZeroAddress();
        arcadeCore = IArcadeCore(newArcadeCore);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Validate entry configuration
    /// @param config Configuration to validate
    function _validateEntryConfig(
        EntryConfig calldata config
    ) internal pure {
        if (config.rakeBps > MAX_RAKE_BPS) revert InvalidConfig();
        if (config.burnBps > MAX_BURN_BPS) revert InvalidConfig();
        if (config.minEntry > config.maxEntry && config.maxEntry != 0) {
            revert InvalidConfig();
        }
    }

    /// @notice Fetch game info from game contract
    /// @param game Game contract address
    /// @return info Game information
    function _fetchGameInfo(
        address game
    ) internal view returns (GameInfo memory info) {
        // Try to get game info from the contract
        try IArcadeGame(game).getGameInfo() returns (IArcadeGame.GameInfo memory gameInfo) {
            info = GameInfo({
                gameId: gameInfo.gameId,
                name: gameInfo.name,
                description: gameInfo.description,
                category: gameInfo.category,
                minPlayers: gameInfo.minPlayers,
                maxPlayers: gameInfo.maxPlayers,
                isActive: gameInfo.isActive,
                launchedAt: uint64(block.timestamp)
            });
        } catch {
            // If game doesn't implement getGameInfo, create minimal info
            // This allows registering games that don't fully implement IArcadeGame
            info = GameInfo({
                gameId: keccak256(abi.encodePacked(game)),
                name: "",
                description: "",
                category: GameCategory.CASINO,
                minPlayers: 1,
                maxPlayers: 0,
                isActive: true,
                launchedAt: uint64(block.timestamp)
            });
        }
    }

    /// @notice Convert EntryConfig to ArcadeCore GameConfig
    /// @param config Entry configuration
    /// @return coreConfig ArcadeCore game configuration
    function _toGameConfig(
        EntryConfig calldata config
    ) internal pure returns (IArcadeCore.GameConfig memory coreConfig) {
        coreConfig = IArcadeCore.GameConfig({
            minEntry: config.minEntry,
            maxEntry: config.maxEntry,
            rakeBps: config.rakeBps,
            burnBps: config.burnBps,
            requiresPosition: config.requiresPosition,
            paused: false // Pause state managed separately
        });
    }
}
