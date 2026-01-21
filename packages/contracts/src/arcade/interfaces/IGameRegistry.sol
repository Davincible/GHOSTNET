// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { IArcadeTypes } from "./IArcadeTypes.sol";

/// @title IGameRegistry
/// @notice Interface for the GameRegistry contract that manages game whitelist
/// @dev ArcadeCore reads from this to validate game permissions and configs
interface IGameRegistry is IArcadeTypes {
    // ═══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════════════════════

    error GameAlreadyRegistered();
    error GameNotRegistered();
    error InvalidConfig();
    error ZeroAddress();

    // ═══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════════════════

    event GameRegistered(address indexed game, bytes32 indexed gameId, string name);
    event GamePaused(address indexed game);
    event GameUnpaused(address indexed game);
    event GameConfigUpdated(address indexed game);
    event GameMarkedForRemoval(address indexed game, uint256 removalTime);
    event GameRemovalCancelled(address indexed game);
    event GameRemoved(address indexed game);

    // ═══════════════════════════════════════════════════════════════════════════════
    // GAME QUERIES
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Check if a game contract is registered
    /// @param game Address of the game contract
    /// @return registered True if game is registered (may still be paused)
    function isGameRegistered(
        address game
    ) external view returns (bool registered);

    /// @notice Check if a game is currently paused
    /// @param game Address of the game contract
    /// @return paused True if game is paused
    function isGamePaused(
        address game
    ) external view returns (bool paused);

    /// @notice Get entry configuration for a game
    /// @param game Address of the game contract
    /// @return config The entry configuration
    function getEntryConfig(
        address game
    ) external view returns (EntryConfig memory config);

    /// @notice Get game metadata
    /// @param game Address of the game contract
    /// @return info The game information
    function getGameInfo(
        address game
    ) external view returns (GameInfo memory info);

    // ═══════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Register a new game
    /// @param game Address of the game contract
    /// @param config Entry configuration for the game
    function registerGame(
        address game,
        EntryConfig calldata config
    ) external;

    /// @notice Pause a game (stops new entries)
    /// @param game Address of the game contract
    function pauseGame(
        address game
    ) external;

    /// @notice Unpause a game
    /// @param game Address of the game contract
    function unpauseGame(
        address game
    ) external;

    /// @notice Update entry configuration for a game
    /// @param game Address of the game contract
    /// @param config New entry configuration
    function updateEntryConfig(
        address game,
        EntryConfig calldata config
    ) external;

    /// @notice Mark a game for removal (starts grace period)
    /// @param game Address of the game contract
    function markGameForRemoval(
        address game
    ) external;

    /// @notice Cancel pending game removal
    /// @param game Address of the game contract
    function cancelGameRemoval(
        address game
    ) external;

    /// @notice Complete game removal after grace period
    /// @param game Address of the game contract
    function removeGame(
        address game
    ) external;
}
