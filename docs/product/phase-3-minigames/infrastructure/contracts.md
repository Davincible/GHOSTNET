# GHOSTNET Arcade: Smart Contract Architecture

**Version:** 1.0  
**Status:** Specification  
**Target:** Q2 2026  

---

## Overview

The GHOSTNET Arcade contract architecture provides a unified, secure, and gas-efficient foundation for 9 arcade games. All games share common infrastructure for entry fees, payouts, burns, and player tracking while maintaining game-specific logic in dedicated contracts.

### Design Philosophy

1. **Shared Infrastructure** - Common patterns for all games reduce code duplication and security surface
2. **Gas Efficiency** - Batching, storage packing, and custom errors minimize transaction costs
3. **Upgradeability** - UUPS proxy pattern allows bug fixes without losing state
4. **Security First** - ReentrancyGuard, rate limiting, and access control on all sensitive operations
5. **Composability** - Games integrate with existing GhostCore for boosts and position benefits

---

## Architecture Diagram

```
                                  GHOSTNET ARCADE CONTRACTS
+===========================================================================================+
|                                                                                            |
|   +------------------+         +-----------------+         +------------------+           |
|   |   DataToken      |<------->|   ArcadeCore    |<------->|   GhostCore      |           |
|   |   (ERC20)        |         |   (Registry)    |         |   (Main Game)    |           |
|   +------------------+         +--------+--------+         +------------------+           |
|                                         |                                                 |
|              +------------+-------------+-------------+------------+                      |
|              |            |             |             |            |                      |
|              v            v             v             v            v                      |
|   +----------+--+ +-------+-----+ +-----+------+ +---+--------+ +-+------------+         |
|   | GameRegistry| | PayoutMgr   | | FeeRouter  | | VRFCoord   | | RateLimiter  |         |
|   | (Config)    | | (Rewards)   | | (Entry)    | | (Random)   | | (Throttle)   |         |
|   +----------+--+ +-------+-----+ +-----+------+ +---+--------+ +-+------------+         |
|              |            |             |             |            |                      |
|              +------------+------+------+-------------+------------+                      |
|                                  |                                                        |
|                                  v                                                        |
|   +-----------------------------------------------------------------------------------+  |
|   |                         IArcadeGame Interface                                      |  |
|   +-----------------------------------------------------------------------------------+  |
|              |            |             |             |            |                      |
|              v            v             v             v            v                      |
|   +----------+--+ +-------+-----+ +-----+------+ +---+--------+ +-+------------+         |
|   | HashCrash   | | BinaryBet   | | CodeDuel   | | IceBreaker | | BountyHunt   |         |
|   +-------------+ +-------------+ +------------+ +------------+ +--------------+         |
|              |            |             |             |            |                      |
|   +----------+--+ +-------+-----+ +-----+------+ +---+--------+                          |
|   | DailyOps    | | ProxyWar    | | ZeroDay    | | ShadowProt |                          |
|   +-------------+ +-------------+ +------------+ +------------+                          |
|                                                                                            |
+===========================================================================================+

TOKEN FLOW:
============
                                    
    Player                          Contract                         Destinations
    ------                          --------                         ------------
       |                                |                                  |
       |------ Entry Fee (DATA) ------->|                                  |
       |                                |------ Rake (2-10%) ------------->| Treasury
       |                                |------ Burn (varies) ------------>| 0xdead
       |                                |------ Prize Pool --------------->| Winners
       |<----- Payout (DATA) -----------|                                  |
       |                                |                                  |
```

---

## Core Contracts

### 1. ArcadeCore.sol

The central hub for all arcade games. Handles game registration, entry validation, and payout routing.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IArcadeGame} from "./interfaces/IArcadeGame.sol";
import {IGameRegistry} from "./interfaces/IGameRegistry.sol";
import {IPayoutManager} from "./interfaces/IPayoutManager.sol";
import {IGhostCore} from "../core/interfaces/IGhostCore.sol";

/// @title ArcadeCore
/// @notice Central hub for GHOSTNET Arcade games
/// @dev UUPS upgradeable with role-based access control
///
/// Architecture:
/// - Games register through GameRegistry
/// - Entry fees flow through FeeRouter
/// - Payouts distributed via PayoutManager
/// - All games inherit IArcadeGame interface
///
/// @custom:security-contact security@ghostnet.game
contract ArcadeCore is
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════════════════
    // TYPES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Player statistics across all games
    struct PlayerStats {
        uint64 totalGamesPlayed;
        uint64 totalWins;
        uint64 totalLosses;
        uint128 totalWagered;      // In DATA (scaled down by 1e12 for packing)
        uint128 totalWon;          // In DATA (scaled down by 1e12 for packing)
        uint128 totalBurned;       // Contributed to burns
        uint32 currentStreak;      // Current win streak
        uint32 maxStreak;          // Best win streak ever
    }

    /// @notice Entry fee configuration
    struct EntryConfig {
        uint128 minEntry;          // Minimum entry fee
        uint128 maxEntry;          // Maximum entry fee (0 = no max)
        uint16 rakeBps;            // Protocol rake in basis points
        uint16 burnBps;            // Burn rate in basis points
        bool requiresPosition;     // Must have GhostCore position
        bool boostEligible;        // Can earn death reduction boosts
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    bytes32 public constant GAME_OPERATOR_ROLE = keccak256("GAME_OPERATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    uint16 public constant MAX_RAKE_BPS = 1000;    // 10% max rake
    uint16 public constant MAX_BURN_BPS = 10000;   // 100% max burn
    uint16 private constant BPS = 10000;

    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // ══════════════════════════════════════════════════════════════════════════════
    // STORAGE (ERC-7201 Namespaced)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @custom:storage-location erc7201:ghostnet.arcade.core
    struct ArcadeCoreStorage {
        IERC20 dataToken;
        IGhostCore ghostCore;
        address treasury;
        IGameRegistry gameRegistry;
        IPayoutManager payoutManager;
        
        // Player data
        mapping(address player => PlayerStats stats) playerStats;
        
        // Global counters
        uint256 totalGamesPlayed;
        uint256 totalVolume;
        uint256 totalBurned;
        uint256 totalRakeCollected;
        
        // Rate limiting
        mapping(address player => uint256 lastPlayTime) lastPlayTime;
        uint256 minPlayInterval;  // Seconds between plays per player
    }

    // keccak256(abi.encode(uint256(keccak256("ghostnet.arcade.core")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ARCADE_CORE_STORAGE_LOCATION =
        0x8a0c9d8ec1d9f8b3f4e5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c600;

    function _getArcadeCoreStorage() private pure returns (ArcadeCoreStorage storage $) {
        assembly {
            $.slot := ARCADE_CORE_STORAGE_LOCATION
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    error GameNotRegistered();
    error GamePaused();
    error InvalidEntryAmount();
    error PositionRequired();
    error RateLimited();
    error InvalidConfiguration();
    error TransferFailed();
    error ZeroAddress();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    event GamePlayed(
        address indexed game,
        address indexed player,
        uint256 indexed sessionId,
        uint256 entryFee
    );

    event GameSettled(
        address indexed game,
        address indexed player,
        uint256 indexed sessionId,
        uint256 payout,
        uint256 burned,
        bool won
    );

    event RakeCollected(
        address indexed game,
        uint256 amount
    );

    event BurnExecuted(
        address indexed game,
        uint256 amount
    );

    event PlayerStatsUpdated(
        address indexed player,
        uint64 totalGamesPlayed,
        uint64 totalWins,
        uint32 currentStreak
    );

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR & INITIALIZER
    // ══════════════════════════════════════════════════════════════════════════════

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the ArcadeCore contract
    /// @param _dataToken Address of the DATA token
    /// @param _ghostCore Address of the GhostCore contract
    /// @param _treasury Address for rake collection
    /// @param _admin Address with DEFAULT_ADMIN_ROLE
    function initialize(
        address _dataToken,
        address _ghostCore,
        address _treasury,
        address _admin
    ) external initializer {
        if (_dataToken == address(0) || _treasury == address(0) || _admin == address(0)) {
            revert ZeroAddress();
        }

        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        ArcadeCoreStorage storage $ = _getArcadeCoreStorage();
        $.dataToken = IERC20(_dataToken);
        $.ghostCore = IGhostCore(_ghostCore);
        $.treasury = _treasury;
        $.minPlayInterval = 1; // 1 second default

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(REGISTRAR_ROLE, _admin);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ENTRY POINT
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Process entry fee for a game session
    /// @dev Called by registered games when player enters
    /// @param player Address of the player
    /// @param amount Entry fee amount
    /// @param gameId Unique game identifier
    /// @return sessionId Unique session identifier
    /// @return netAmount Amount after rake deduction (available for prize pool)
    function processEntry(
        address player,
        uint256 amount,
        bytes32 gameId
    ) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 sessionId, uint256 netAmount) 
    {
        ArcadeCoreStorage storage $ = _getArcadeCoreStorage();
        
        // Verify caller is a registered game
        if (!$.gameRegistry.isGameRegistered(msg.sender)) {
            revert GameNotRegistered();
        }
        
        // Check game-specific pause
        if ($.gameRegistry.isGamePaused(msg.sender)) {
            revert GamePaused();
        }

        // Get entry configuration
        EntryConfig memory config = $.gameRegistry.getEntryConfig(msg.sender);
        
        // Validate entry amount
        if (amount < config.minEntry || (config.maxEntry > 0 && amount > config.maxEntry)) {
            revert InvalidEntryAmount();
        }

        // Check position requirement
        if (config.requiresPosition && !$.ghostCore.isAlive(player)) {
            revert PositionRequired();
        }

        // Rate limiting
        if (block.timestamp < $.lastPlayTime[player] + $.minPlayInterval) {
            revert RateLimited();
        }
        $.lastPlayTime[player] = block.timestamp;

        // Transfer tokens from player
        $.dataToken.safeTransferFrom(player, address(this), amount);

        // Calculate rake
        uint256 rakeAmount = (amount * config.rakeBps) / BPS;
        netAmount = amount - rakeAmount;

        // Transfer rake to treasury
        if (rakeAmount > 0) {
            $.dataToken.safeTransfer($.treasury, rakeAmount);
            $.totalRakeCollected += rakeAmount;
            emit RakeCollected(msg.sender, rakeAmount);
        }

        // Generate session ID
        sessionId = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            player,
            msg.sender,
            $.totalGamesPlayed
        )));

        // Update stats
        $.totalGamesPlayed++;
        $.totalVolume += amount;
        $.playerStats[player].totalGamesPlayed++;
        $.playerStats[player].totalWagered += uint128(amount / 1e12);

        emit GamePlayed(msg.sender, player, sessionId, amount);
    }

    /// @notice Settle a game session with payout
    /// @dev Called by registered games when session ends
    /// @param player Address of the player
    /// @param sessionId Session identifier from processEntry
    /// @param payout Amount to pay winner (0 if lost)
    /// @param burnAmount Amount to burn
    /// @param won Whether player won
    function settleGame(
        address player,
        uint256 sessionId,
        uint256 payout,
        uint256 burnAmount,
        bool won
    ) external nonReentrant {
        ArcadeCoreStorage storage $ = _getArcadeCoreStorage();
        
        if (!$.gameRegistry.isGameRegistered(msg.sender)) {
            revert GameNotRegistered();
        }

        PlayerStats storage stats = $.playerStats[player];

        // Execute burn
        if (burnAmount > 0) {
            $.dataToken.safeTransfer(DEAD_ADDRESS, burnAmount);
            $.totalBurned += burnAmount;
            stats.totalBurned += uint128(burnAmount / 1e12);
            emit BurnExecuted(msg.sender, burnAmount);
        }

        // Execute payout
        if (payout > 0) {
            $.dataToken.safeTransfer(player, payout);
            stats.totalWon += uint128(payout / 1e12);
        }

        // Update win/loss stats
        if (won) {
            stats.totalWins++;
            stats.currentStreak++;
            if (stats.currentStreak > stats.maxStreak) {
                stats.maxStreak = stats.currentStreak;
            }
        } else {
            stats.totalLosses++;
            stats.currentStreak = 0;
        }

        emit GameSettled(msg.sender, player, sessionId, payout, burnAmount, won);
        emit PlayerStatsUpdated(
            player, 
            stats.totalGamesPlayed, 
            stats.totalWins, 
            stats.currentStreak
        );
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BATCH OPERATIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Settle multiple game sessions in one transaction
    /// @dev Gas-efficient batch settlement for games with many participants
    /// @param players Array of player addresses
    /// @param sessionIds Array of session IDs
    /// @param payouts Array of payout amounts
    /// @param burnAmounts Array of burn amounts
    /// @param results Array of win/loss results
    function batchSettleGames(
        address[] calldata players,
        uint256[] calldata sessionIds,
        uint256[] calldata payouts,
        uint256[] calldata burnAmounts,
        bool[] calldata results
    ) external nonReentrant {
        ArcadeCoreStorage storage $ = _getArcadeCoreStorage();
        
        if (!$.gameRegistry.isGameRegistered(msg.sender)) {
            revert GameNotRegistered();
        }

        uint256 len = players.length;
        if (len != sessionIds.length || len != payouts.length || 
            len != burnAmounts.length || len != results.length) {
            revert InvalidConfiguration();
        }

        uint256 totalPayout;
        uint256 totalBurn;

        for (uint256 i; i < len; ) {
            PlayerStats storage stats = $.playerStats[players[i]];
            
            if (results[i]) {
                stats.totalWins++;
                stats.currentStreak++;
                if (stats.currentStreak > stats.maxStreak) {
                    stats.maxStreak = stats.currentStreak;
                }
            } else {
                stats.totalLosses++;
                stats.currentStreak = 0;
            }

            if (payouts[i] > 0) {
                totalPayout += payouts[i];
                stats.totalWon += uint128(payouts[i] / 1e12);
            }
            
            if (burnAmounts[i] > 0) {
                totalBurn += burnAmounts[i];
                stats.totalBurned += uint128(burnAmounts[i] / 1e12);
            }

            emit GameSettled(msg.sender, players[i], sessionIds[i], payouts[i], burnAmounts[i], results[i]);
            
            unchecked { ++i; }
        }

        // Batch transfers
        if (totalBurn > 0) {
            $.dataToken.safeTransfer(DEAD_ADDRESS, totalBurn);
            $.totalBurned += totalBurn;
        }

        // Individual payouts (required for different amounts)
        for (uint256 i; i < len; ) {
            if (payouts[i] > 0) {
                $.dataToken.safeTransfer(players[i], payouts[i]);
            }
            unchecked { ++i; }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get player statistics
    function getPlayerStats(address player) external view returns (PlayerStats memory) {
        return _getArcadeCoreStorage().playerStats[player];
    }

    /// @notice Get global arcade statistics
    function getGlobalStats() external view returns (
        uint256 totalGamesPlayed,
        uint256 totalVolume,
        uint256 totalBurned,
        uint256 totalRakeCollected
    ) {
        ArcadeCoreStorage storage $ = _getArcadeCoreStorage();
        return ($.totalGamesPlayed, $.totalVolume, $.totalBurned, $.totalRakeCollected);
    }

    /// @notice Check if player can play (rate limit check)
    function canPlay(address player) external view returns (bool) {
        ArcadeCoreStorage storage $ = _getArcadeCoreStorage();
        return block.timestamp >= $.lastPlayTime[player] + $.minPlayInterval;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Set the game registry contract
    function setGameRegistry(address registry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (registry == address(0)) revert ZeroAddress();
        _getArcadeCoreStorage().gameRegistry = IGameRegistry(registry);
    }

    /// @notice Set the payout manager contract
    function setPayoutManager(address manager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (manager == address(0)) revert ZeroAddress();
        _getArcadeCoreStorage().payoutManager = IPayoutManager(manager);
    }

    /// @notice Update treasury address
    function setTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress();
        _getArcadeCoreStorage().treasury = newTreasury;
    }

    /// @notice Update minimum play interval
    function setMinPlayInterval(uint256 interval) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _getArcadeCoreStorage().minPlayInterval = interval;
    }

    /// @notice Pause all arcade games
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpause arcade games
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // UPGRADE AUTHORIZATION
    // ══════════════════════════════════════════════════════════════════════════════

    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {}
}
```

### 2. IArcadeGame.sol

Standard interface all arcade games must implement.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title IArcadeGame
/// @notice Interface that all GHOSTNET Arcade games must implement
/// @dev Games implementing this interface can be registered with GameRegistry
interface IArcadeGame {
    // ══════════════════════════════════════════════════════════════════════════════
    // ENUMS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Game session states
    enum SessionState {
        NONE,           // 0 - Session doesn't exist
        PENDING,        // 1 - Waiting for game start
        ACTIVE,         // 2 - Game in progress
        COMPLETED,      // 3 - Game finished, awaiting settlement
        SETTLED,        // 4 - Payouts distributed
        CANCELLED       // 5 - Session cancelled, refunds issued
    }

    /// @notice Game categories for UI grouping
    enum GameCategory {
        CASINO,         // Games of chance (Hash Crash, Binary Bet)
        COMPETITIVE,    // PvP games (Code Duel, Proxy War)
        SKILL,          // Skill-based (Ice Breaker, Zero Day)
        PROGRESSION,    // Daily/streak games (Daily Ops)
        SOCIAL          // Social features (Bounty Hunt, Shadow Protocol)
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Game metadata for registry
    struct GameInfo {
        bytes32 gameId;           // Unique identifier
        string name;              // Display name
        string description;       // Short description
        GameCategory category;    // Game category
        uint8 minPlayers;         // Minimum players to start
        uint8 maxPlayers;         // Maximum players allowed
        bool isActive;            // Whether game accepts new sessions
        uint256 totalSessions;    // Total sessions played
        uint256 totalVolume;      // Total DATA wagered
    }

    /// @notice Basic session info
    struct SessionInfo {
        uint256 sessionId;
        SessionState state;
        uint256 startTime;
        uint256 endTime;
        uint256 prizePool;
        uint8 playerCount;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when a new game session is created
    event SessionCreated(
        uint256 indexed sessionId,
        address indexed creator,
        uint256 entryFee
    );

    /// @notice Emitted when a player joins a session
    event PlayerJoined(
        uint256 indexed sessionId,
        address indexed player,
        uint256 entryFee
    );

    /// @notice Emitted when a session starts
    event SessionStarted(
        uint256 indexed sessionId,
        uint8 playerCount,
        uint256 prizePool
    );

    /// @notice Emitted when a session ends
    event SessionEnded(
        uint256 indexed sessionId,
        address[] winners,
        uint256[] payouts,
        uint256 burned
    );

    /// @notice Emitted when a session is cancelled
    event SessionCancelled(
        uint256 indexed sessionId,
        string reason
    );

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get game metadata
    function getGameInfo() external view returns (GameInfo memory);

    /// @notice Get game's unique identifier
    function gameId() external view returns (bytes32);

    /// @notice Get session information
    function getSession(uint256 sessionId) external view returns (SessionInfo memory);

    /// @notice Check if player is in a specific session
    function isPlayerInSession(uint256 sessionId, address player) external view returns (bool);

    /// @notice Get active sessions count
    function getActiveSessionCount() external view returns (uint256);

    /// @notice Get player's active session (0 if none)
    function getPlayerActiveSession(address player) external view returns (uint256);

    // ══════════════════════════════════════════════════════════════════════════════
    // GAME LIFECYCLE
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Create a new game session
    /// @param entryFee Entry fee for this session
    /// @return sessionId New session identifier
    function createSession(uint256 entryFee) external returns (uint256 sessionId);

    /// @notice Join an existing session
    /// @param sessionId Session to join
    function joinSession(uint256 sessionId) external;

    /// @notice Start a session (when requirements met)
    /// @param sessionId Session to start
    function startSession(uint256 sessionId) external;

    /// @notice Cancel a session (refund all players)
    /// @param sessionId Session to cancel
    /// @param reason Cancellation reason
    function cancelSession(uint256 sessionId, string calldata reason) external;

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Pause the game
    function pause() external;

    /// @notice Unpause the game
    function unpause() external;

    /// @notice Check if game is paused
    function isPaused() external view returns (bool);
}
```

### 3. GameRegistry.sol

Central registry for game configuration and management.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IArcadeGame} from "./interfaces/IArcadeGame.sol";
import {IGameRegistry} from "./interfaces/IGameRegistry.sol";

/// @title GameRegistry
/// @notice Central registry for all GHOSTNET Arcade games
/// @dev Manages game registration, configuration, and status
///
/// Features:
/// - Game registration with entry fee configuration
/// - Per-game pause functionality
/// - Game categories for UI organization
/// - Historical game data tracking
///
/// @custom:security-contact security@ghostnet.game
contract GameRegistry is Ownable2Step, IGameRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // ══════════════════════════════════════════════════════════════════════════════
    // TYPES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Complete game registration data
    struct GameRegistration {
        bytes32 gameId;              // Unique game identifier
        address gameContract;        // Game contract address
        string name;                 // Display name
        string description;          // Game description
        IArcadeGame.GameCategory category;  // Game category
        EntryConfig entryConfig;     // Fee configuration
        bool isRegistered;           // Registration status
        bool isPaused;               // Pause status
        uint64 registeredAt;         // Registration timestamp
        uint64 totalSessions;        // Total sessions played
        uint128 totalVolume;         // Total DATA wagered (scaled by 1e12)
    }

    /// @notice Entry fee configuration (matches ArcadeCore)
    struct EntryConfig {
        uint128 minEntry;            // Minimum entry fee
        uint128 maxEntry;            // Maximum entry fee (0 = no max)
        uint16 rakeBps;              // Protocol rake in basis points
        uint16 burnBps;              // Burn rate in basis points
        bool requiresPosition;       // Must have GhostCore position
        bool boostEligible;          // Can earn death reduction boosts
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    uint16 public constant MAX_RAKE_BPS = 1000;   // 10% max
    uint16 public constant MAX_BURN_BPS = 10000;  // 100% max
    uint16 private constant BPS = 10000;

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════════════

    // All registered games
    EnumerableSet.AddressSet private _registeredGames;
    EnumerableSet.Bytes32Set private _gameIds;

    // Game data
    mapping(address game => GameRegistration registration) public games;
    mapping(bytes32 gameId => address game) public gameByIdLookup;

    // Games by category
    mapping(IArcadeGame.GameCategory => EnumerableSet.AddressSet) private _gamesByCategory;

    // ArcadeCore reference
    address public arcadeCore;

    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    error GameAlreadyRegistered();
    error GameNotRegistered();
    error InvalidGameContract();
    error InvalidConfiguration();
    error InvalidGameId();
    error GameIdTaken();
    error ZeroAddress();
    error NotAuthorized();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    event GameRegistered(
        address indexed game,
        bytes32 indexed gameId,
        string name,
        IArcadeGame.GameCategory category
    );

    event GameUnregistered(
        address indexed game,
        bytes32 indexed gameId
    );

    event GamePaused(
        address indexed game,
        bytes32 indexed gameId
    );

    event GameUnpaused(
        address indexed game,
        bytes32 indexed gameId
    );

    event EntryConfigUpdated(
        address indexed game,
        bytes32 indexed gameId,
        EntryConfig config
    );

    event ArcadeCoreUpdated(
        address indexed newArcadeCore
    );

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════════════

    constructor(address _owner, address _arcadeCore) Ownable(_owner) {
        if (_arcadeCore == address(0)) revert ZeroAddress();
        arcadeCore = _arcadeCore;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // REGISTRATION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Register a new game
    /// @param game Game contract address
    /// @param config Entry fee configuration
    function registerGame(
        address game,
        EntryConfig calldata config
    ) external onlyOwner {
        if (game == address(0)) revert ZeroAddress();
        if (_registeredGames.contains(game)) revert GameAlreadyRegistered();
        
        // Validate configuration
        if (config.rakeBps > MAX_RAKE_BPS) revert InvalidConfiguration();
        if (config.burnBps > MAX_BURN_BPS) revert InvalidConfiguration();
        if (config.minEntry > config.maxEntry && config.maxEntry != 0) revert InvalidConfiguration();

        // Get game info from contract
        IArcadeGame gameContract = IArcadeGame(game);
        IArcadeGame.GameInfo memory info;
        
        try gameContract.getGameInfo() returns (IArcadeGame.GameInfo memory _info) {
            info = _info;
        } catch {
            revert InvalidGameContract();
        }

        // Verify gameId not taken
        if (gameByIdLookup[info.gameId] != address(0)) revert GameIdTaken();

        // Create registration
        games[game] = GameRegistration({
            gameId: info.gameId,
            gameContract: game,
            name: info.name,
            description: info.description,
            category: info.category,
            entryConfig: config,
            isRegistered: true,
            isPaused: false,
            registeredAt: uint64(block.timestamp),
            totalSessions: 0,
            totalVolume: 0
        });

        // Add to tracking sets
        _registeredGames.add(game);
        _gameIds.add(info.gameId);
        gameByIdLookup[info.gameId] = game;
        _gamesByCategory[info.category].add(game);

        emit GameRegistered(game, info.gameId, info.name, info.category);
    }

    /// @notice Unregister a game
    /// @param game Game contract address
    function unregisterGame(address game) external onlyOwner {
        if (!_registeredGames.contains(game)) revert GameNotRegistered();

        GameRegistration storage reg = games[game];
        
        // Remove from tracking
        _registeredGames.remove(game);
        _gameIds.remove(reg.gameId);
        delete gameByIdLookup[reg.gameId];
        _gamesByCategory[reg.category].remove(game);

        bytes32 gameId = reg.gameId;
        delete games[game];

        emit GameUnregistered(game, gameId);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CONFIGURATION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Update entry configuration for a game
    /// @param game Game contract address
    /// @param config New configuration
    function updateEntryConfig(
        address game,
        EntryConfig calldata config
    ) external onlyOwner {
        if (!_registeredGames.contains(game)) revert GameNotRegistered();
        if (config.rakeBps > MAX_RAKE_BPS) revert InvalidConfiguration();
        if (config.burnBps > MAX_BURN_BPS) revert InvalidConfiguration();
        if (config.minEntry > config.maxEntry && config.maxEntry != 0) revert InvalidConfiguration();

        games[game].entryConfig = config;
        emit EntryConfigUpdated(game, games[game].gameId, config);
    }

    /// @notice Pause a specific game
    /// @param game Game contract address
    function pauseGame(address game) external onlyOwner {
        if (!_registeredGames.contains(game)) revert GameNotRegistered();
        
        games[game].isPaused = true;
        emit GamePaused(game, games[game].gameId);
    }

    /// @notice Unpause a specific game
    /// @param game Game contract address
    function unpauseGame(address game) external onlyOwner {
        if (!_registeredGames.contains(game)) revert GameNotRegistered();
        
        games[game].isPaused = false;
        emit GameUnpaused(game, games[game].gameId);
    }

    /// @notice Update ArcadeCore address
    /// @param newArcadeCore New ArcadeCore address
    function setArcadeCore(address newArcadeCore) external onlyOwner {
        if (newArcadeCore == address(0)) revert ZeroAddress();
        arcadeCore = newArcadeCore;
        emit ArcadeCoreUpdated(newArcadeCore);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // STATS UPDATE (Called by ArcadeCore)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Update game statistics
    /// @param game Game address
    /// @param volume Volume to add
    function recordSession(address game, uint256 volume) external {
        if (msg.sender != arcadeCore) revert NotAuthorized();
        if (!_registeredGames.contains(game)) revert GameNotRegistered();

        games[game].totalSessions++;
        games[game].totalVolume += uint128(volume / 1e12);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IGameRegistry
    function isGameRegistered(address game) external view returns (bool) {
        return _registeredGames.contains(game);
    }

    /// @inheritdoc IGameRegistry
    function isGamePaused(address game) external view returns (bool) {
        return games[game].isPaused;
    }

    /// @inheritdoc IGameRegistry
    function getEntryConfig(address game) external view returns (EntryConfig memory) {
        return games[game].entryConfig;
    }

    /// @notice Get full game registration data
    function getGameRegistration(address game) external view returns (GameRegistration memory) {
        return games[game];
    }

    /// @notice Get game by ID
    function getGameById(bytes32 gameId) external view returns (address) {
        return gameByIdLookup[gameId];
    }

    /// @notice Get all registered games
    function getAllGames() external view returns (address[] memory) {
        return _registeredGames.values();
    }

    /// @notice Get registered game count
    function getGameCount() external view returns (uint256) {
        return _registeredGames.length();
    }

    /// @notice Get games by category
    function getGamesByCategory(
        IArcadeGame.GameCategory category
    ) external view returns (address[] memory) {
        return _gamesByCategory[category].values();
    }

    /// @notice Get all game IDs
    function getAllGameIds() external view returns (bytes32[] memory) {
        return _gameIds.values();
    }
}
```

### 4. PayoutManager.sol

Handles prize distribution, rake calculation, and pull-payment pattern.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IPayoutManager} from "./interfaces/IPayoutManager.sol";

/// @title PayoutManager
/// @notice Manages prize distribution using pull-payment pattern
/// @dev Uses pull pattern to prevent DoS and gas griefing attacks
///
/// Features:
/// - Pull-payment pattern for safe withdrawals
/// - Batch payout registration for gas efficiency
/// - Pending balance tracking
/// - Emergency withdrawal for stuck funds
///
/// @custom:security-contact security@ghostnet.game
contract PayoutManager is Ownable2Step, ReentrancyGuard, IPayoutManager {
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════════════

    IERC20 public immutable dataToken;
    address public arcadeCore;

    // Pending payouts (pull pattern)
    mapping(address player => uint256 amount) public pendingPayouts;
    
    // Total pending (for accounting)
    uint256 public totalPending;

    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    error NothingToWithdraw();
    error NotAuthorized();
    error ZeroAddress();
    error InsufficientBalance();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    event PayoutRegistered(
        address indexed player,
        uint256 amount,
        uint256 newPendingBalance
    );

    event PayoutWithdrawn(
        address indexed player,
        uint256 amount
    );

    event BatchPayoutRegistered(
        uint256 playerCount,
        uint256 totalAmount
    );

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════════════

    constructor(
        address _dataToken,
        address _arcadeCore,
        address _owner
    ) Ownable(_owner) {
        if (_dataToken == address(0) || _arcadeCore == address(0)) {
            revert ZeroAddress();
        }
        dataToken = IERC20(_dataToken);
        arcadeCore = _arcadeCore;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // PAYOUT REGISTRATION (Called by ArcadeCore/Games)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IPayoutManager
    function registerPayout(address player, uint256 amount) external {
        if (msg.sender != arcadeCore) revert NotAuthorized();
        if (player == address(0)) revert ZeroAddress();
        if (amount == 0) return;

        pendingPayouts[player] += amount;
        totalPending += amount;

        emit PayoutRegistered(player, amount, pendingPayouts[player]);
    }

    /// @inheritdoc IPayoutManager
    function registerBatchPayouts(
        address[] calldata players,
        uint256[] calldata amounts
    ) external {
        if (msg.sender != arcadeCore) revert NotAuthorized();
        
        uint256 len = players.length;
        uint256 total;

        for (uint256 i; i < len; ) {
            if (players[i] != address(0) && amounts[i] > 0) {
                pendingPayouts[players[i]] += amounts[i];
                total += amounts[i];
            }
            unchecked { ++i; }
        }

        totalPending += total;
        emit BatchPayoutRegistered(len, total);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // WITHDRAWAL (Pull Pattern)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IPayoutManager
    function withdraw() external nonReentrant {
        uint256 amount = pendingPayouts[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        // Effects before interactions (CEI)
        pendingPayouts[msg.sender] = 0;
        totalPending -= amount;

        // Interaction
        dataToken.safeTransfer(msg.sender, amount);

        emit PayoutWithdrawn(msg.sender, amount);
    }

    /// @inheritdoc IPayoutManager
    function withdrawTo(address recipient) external nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        
        uint256 amount = pendingPayouts[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        pendingPayouts[msg.sender] = 0;
        totalPending -= amount;

        dataToken.safeTransfer(recipient, amount);

        emit PayoutWithdrawn(msg.sender, amount);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IPayoutManager
    function getPendingPayout(address player) external view returns (uint256) {
        return pendingPayouts[player];
    }

    /// @inheritdoc IPayoutManager
    function getTotalPending() external view returns (uint256) {
        return totalPending;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Update ArcadeCore address
    function setArcadeCore(address newArcadeCore) external onlyOwner {
        if (newArcadeCore == address(0)) revert ZeroAddress();
        arcadeCore = newArcadeCore;
    }

    /// @notice Emergency withdrawal of stuck tokens
    /// @dev Only for tokens accidentally sent, not pending payouts
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwner {
        if (recipient == address(0)) revert ZeroAddress();
        
        // Prevent withdrawing pending DATA payouts
        if (token == address(dataToken)) {
            uint256 available = dataToken.balanceOf(address(this)) - totalPending;
            if (amount > available) revert InsufficientBalance();
        }
        
        IERC20(token).safeTransfer(recipient, amount);
    }
}
```

---

## Interfaces

### IGameRegistry.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title IGameRegistry
/// @notice Interface for the GameRegistry contract
interface IGameRegistry {
    struct EntryConfig {
        uint128 minEntry;
        uint128 maxEntry;
        uint16 rakeBps;
        uint16 burnBps;
        bool requiresPosition;
        bool boostEligible;
    }

    function isGameRegistered(address game) external view returns (bool);
    function isGamePaused(address game) external view returns (bool);
    function getEntryConfig(address game) external view returns (EntryConfig memory);
    function recordSession(address game, uint256 volume) external;
}
```

### IPayoutManager.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title IPayoutManager
/// @notice Interface for the PayoutManager contract
interface IPayoutManager {
    /// @notice Register a payout for a player
    function registerPayout(address player, uint256 amount) external;

    /// @notice Register multiple payouts in batch
    function registerBatchPayouts(
        address[] calldata players,
        uint256[] calldata amounts
    ) external;

    /// @notice Withdraw pending payout
    function withdraw() external;

    /// @notice Withdraw pending payout to another address
    function withdrawTo(address recipient) external;

    /// @notice Get pending payout for a player
    function getPendingPayout(address player) external view returns (uint256);

    /// @notice Get total pending payouts
    function getTotalPending() external view returns (uint256);
}
```

---

## Inheritance Hierarchy

```
                           OpenZeppelin Contracts
                                    |
        +---------------------------+---------------------------+
        |                           |                           |
    Upgradeable              Non-Upgradeable              Interfaces
        |                           |                           |
+-------+-------+           +-------+-------+           +-------+-------+
|               |           |               |           |               |
UUPSUpgradeable Ownable2Step Ownable2Step  ReentrancyGuard IArcadeGame IGameRegistry
AccessControl   ReentrancyGuard                         IPayoutManager
Pausable                    
ReentrancyGuard             
        |                           |                           |
        v                           v                           v
+------------------+     +------------------+     +------------------+
|   ArcadeCore     |     |  GameRegistry    |     |  PayoutManager   |
|   (Upgradeable)  |     | (Non-Upgradeable)|     | (Non-Upgradeable)|
+------------------+     +------------------+     +------------------+
        |
        v
+------------------+     +------------------+     +------------------+
|   HashCrash      |     |   BinaryBet      |     |   CodeDuel       |
|   (Game)         |     |   (Game)         |     |   (Game)         |
+------------------+     +------------------+     +------------------+
```

---

## Security Patterns

### 1. ReentrancyGuard Usage

All state-changing functions that interact with external contracts use ReentrancyGuard:

```solidity
// Pattern: Always use nonReentrant on external-facing functions that:
// 1. Transfer tokens
// 2. Call external contracts
// 3. Update balances

function withdraw() external nonReentrant {
    uint256 amount = pendingPayouts[msg.sender];
    if (amount == 0) revert NothingToWithdraw();

    // Effects BEFORE interactions (CEI pattern)
    pendingPayouts[msg.sender] = 0;
    totalPending -= amount;

    // Interaction LAST
    dataToken.safeTransfer(msg.sender, amount);
}
```

### 2. Access Control

Role-based access control with principle of least privilege:

```solidity
// Roles hierarchy
bytes32 public constant GAME_OPERATOR_ROLE = keccak256("GAME_OPERATOR_ROLE");
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

// Usage pattern
function pauseGame(address game) external onlyRole(PAUSER_ROLE) {
    // Only pausers can pause
}

function registerGame(address game) external onlyRole(REGISTRAR_ROLE) {
    // Only registrars can register
}

function upgrade(address impl) internal override onlyRole(DEFAULT_ADMIN_ROLE) {
    // Only admin can upgrade
}
```

### 3. Pausability

Multi-level pause system:

```solidity
// Global pause (all games)
function pause() external onlyRole(PAUSER_ROLE) {
    _pause();  // Inherited from PausableUpgradeable
}

// Per-game pause
function pauseGame(address game) external onlyOwner {
    games[game].isPaused = true;
}

// Check both in entry
function processEntry(...) external whenNotPaused {  // Global check
    if ($.gameRegistry.isGamePaused(msg.sender)) {   // Game-specific check
        revert GamePaused();
    }
}
```

### 4. Rate Limiting

Per-player rate limiting to prevent spam and abuse:

```solidity
struct RateLimitConfig {
    uint256 minPlayInterval;      // Seconds between plays
    uint256 maxPlaysPerHour;      // Maximum plays per hour
    uint256 maxVolumePerHour;     // Maximum volume per hour
}

mapping(address => uint256) public lastPlayTime;
mapping(address => uint256[]) public recentPlayTimes;

modifier rateLimited() {
    if (block.timestamp < lastPlayTime[msg.sender] + minPlayInterval) {
        revert RateLimited();
    }
    lastPlayTime[msg.sender] = block.timestamp;
    _;
}
```

---

## Token Flow

### Entry Flow

```
Player                  ArcadeCore              Game Contract
  |                         |                         |
  |--- approve(amount) ---->|                         |
  |                         |                         |
  |                         |<-- processEntry() ------|
  |                         |                         |
  |<-- transferFrom() ------|                         |
  |                         |                         |
  |                         |--- rake to treasury --->|
  |                         |                         |
  |                         |--- netAmount ---------->|
  |                         |                         |
```

### Payout Flow (Pull Pattern)

```
Game Contract           ArcadeCore              PayoutManager           Player
     |                      |                         |                    |
     |-- settleGame() ----->|                         |                    |
     |                      |                         |                    |
     |                      |-- burn to 0xdead ----->|                    |
     |                      |                         |                    |
     |                      |-- registerPayout() --->|                    |
     |                      |                         |                    |
     |                      |                         |<-- withdraw() -----|
     |                      |                         |                    |
     |                      |                         |--- transfer() ---->|
     |                      |                         |                    |
```

### Burn Mechanics

Each game has configurable burn rates:

| Game | Entry Burn | Loss Burn | House Edge | Total Effective Burn |
|------|------------|-----------|------------|---------------------|
| HASH CRASH | 0% | 100% of losses | 3% | ~3% of volume |
| BINARY BET | 0% | 5% of pot | 5% | ~5% of volume |
| CODE DUEL | 0% | 10% of entry | 10% | ~10% of loser volume |
| ICE BREAKER | 100% | N/A | 100% | 100% of entry |
| BOUNTY HUNT | 100% | N/A | 100% | 100% of entry |
| DAILY OPS | 0% | 0% | 0% | 0% (rewards only) |
| PROXY WAR | 0% | 100% of loser | 100% | 50% of volume |
| ZERO DAY | 100% | N/A | 100% | 100% of entry |
| SHADOW PROTOCOL | 100% | N/A | 100% | 100% of entry |

---

## Upgrade Strategy

### UUPS Proxy Pattern

ArcadeCore uses UUPS (Universal Upgradeable Proxy Standard) for upgrades:

```solidity
// Implementation contract
contract ArcadeCoreV1 is UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(...) external initializer {
        // Initialize state
    }

    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        // Only admin can upgrade
        // Consider adding timelock
    }
}

// Deployment
ERC1967Proxy proxy = new ERC1967Proxy(
    implementation,
    abi.encodeCall(ArcadeCoreV1.initialize, (...))
);
```

### Storage Layout Rules

1. **Never remove or reorder existing variables**
2. **Only add new variables at the end**
3. **Use ERC-7201 namespaced storage for complex structures**
4. **Keep storage gaps for inheritance chains**

```solidity
/// @custom:storage-location erc7201:ghostnet.arcade.core
struct ArcadeCoreStorage {
    // Existing variables - NEVER REMOVE OR REORDER
    IERC20 dataToken;
    IGhostCore ghostCore;
    address treasury;
    // ...

    // New variables - ADD AT END ONLY
    uint256 newFeatureValue;
    mapping(address => uint256) newMapping;
}
```

### Upgrade Checklist

- [ ] Storage layout compatibility verified
- [ ] All initializers called in V2
- [ ] Access control preserved
- [ ] No constructor state in implementation
- [ ] Timelock delay respected
- [ ] Test upgrade on fork before mainnet
- [ ] Emergency pause ready if issues discovered

---

## Events & Indexing

### Standardized Event Schema

All games emit consistent events for frontend and analytics:

```solidity
// Session lifecycle
event SessionCreated(
    uint256 indexed sessionId,
    address indexed creator,
    bytes32 indexed gameId,
    uint256 entryFee,
    uint256 timestamp
);

event PlayerJoined(
    uint256 indexed sessionId,
    address indexed player,
    bytes32 indexed gameId,
    uint256 entryFee,
    uint8 playerCount
);

event SessionStarted(
    uint256 indexed sessionId,
    bytes32 indexed gameId,
    uint8 playerCount,
    uint256 prizePool,
    uint256 timestamp
);

event SessionEnded(
    uint256 indexed sessionId,
    bytes32 indexed gameId,
    address[] winners,
    uint256[] payouts,
    uint256 burned,
    uint256 duration
);

// Player actions
event GamePlayed(
    address indexed game,
    address indexed player,
    uint256 indexed sessionId,
    uint256 entryFee
);

event GameSettled(
    address indexed game,
    address indexed player,
    uint256 indexed sessionId,
    uint256 payout,
    uint256 burned,
    bool won
);

// Economic events
event RakeCollected(
    address indexed game,
    uint256 amount,
    uint256 timestamp
);

event BurnExecuted(
    address indexed game,
    uint256 amount,
    uint256 timestamp
);
```

### Indexing Strategy

Events are indexed for efficient querying:

```
Primary Indexes:
- sessionId: Find all events for a session
- player: Find all player activity
- gameId: Find all game activity

Secondary Indexes (via logs):
- timestamp: Time-range queries
- amount: Volume analysis
- won/lost: Win rate analysis
```

---

## Gas Optimization

### 1. Storage Packing

Pack related variables into single slots:

```solidity
// BAD: 4 slots (128 bytes)
struct PlayerStats {
    uint256 totalGamesPlayed;  // slot 0
    uint256 totalWins;         // slot 1
    uint256 totalLosses;       // slot 2
    uint256 totalWagered;      // slot 3
}

// GOOD: 2 slots (64 bytes) - 50% savings
struct PlayerStats {
    uint64 totalGamesPlayed;   // slot 0 (8 bytes)
    uint64 totalWins;          // slot 0 (8 bytes)
    uint64 totalLosses;        // slot 0 (8 bytes)
    uint128 totalWagered;      // slot 0 (16 bytes) - scaled by 1e12
    uint128 totalWon;          // slot 1 (16 bytes)
    uint128 totalBurned;       // slot 1 (16 bytes)
    uint32 currentStreak;      // slot 1 (4 bytes)
    uint32 maxStreak;          // slot 1 (4 bytes)
}
```

### 2. Batch Operations

Batch multiple operations to amortize base gas costs:

```solidity
// Single settlement: ~50,000 gas each
for (uint256 i; i < 100; i++) {
    settleGame(players[i], ...);  // 100 * 50,000 = 5,000,000 gas
}

// Batch settlement: ~30,000 gas each + overhead
batchSettleGames(players, ...);  // 100 * 30,000 + 20,000 = 3,020,000 gas
// Savings: ~40%
```

### 3. Custom Errors

Custom errors save ~200 gas vs string reverts:

```solidity
// BAD: String revert (~24,000 gas deployment)
require(amount > 0, "Amount must be greater than zero");

// GOOD: Custom error (~21,000 gas deployment)
error InvalidAmount();
if (amount == 0) revert InvalidAmount();
```

### 4. Unchecked Blocks

Use unchecked for known-safe arithmetic:

```solidity
// Safe: loop counter cannot overflow
for (uint256 i; i < len; ) {
    // ... loop body ...
    unchecked { ++i; }  // Saves ~100 gas per iteration
}

// Safe: checked subtraction already ensures no underflow
uint256 netAmount = amount - rakeAmount;  // Checked
unchecked {
    // rakeAmount is always <= amount due to BPS calculation
    uint256 netAmount = amount - rakeAmount;  // Unchecked OK
}
```

### 5. Calldata vs Memory

Use calldata for read-only arrays:

```solidity
// BAD: Copies array to memory (~500 gas per element)
function processPlayers(address[] memory players) external { }

// GOOD: Reads directly from calldata (~60 gas per element)
function processPlayers(address[] calldata players) external { }
```

---

## Testing Strategy

### 1. Unit Tests

Test individual functions in isolation:

```solidity
// test/arcade/ArcadeCore.t.sol
contract ArcadeCoreTest is Test {
    ArcadeCore public core;
    MockGame public game;
    MockToken public token;

    function setUp() public {
        // Deploy contracts
        token = new MockToken();
        core = new ArcadeCore();
        core.initialize(address(token), ...);
        
        // Register mock game
        game = new MockGame();
        gameRegistry.registerGame(address(game), defaultConfig);
    }

    function test_ProcessEntry_Success() public {
        vm.prank(player);
        token.approve(address(core), 100 ether);
        
        vm.prank(address(game));
        (uint256 sessionId, uint256 netAmount) = core.processEntry(
            player,
            100 ether,
            game.gameId()
        );
        
        assertGt(sessionId, 0);
        assertEq(netAmount, 97 ether);  // 3% rake
    }

    function test_ProcessEntry_RevertWhen_GameNotRegistered() public {
        vm.prank(address(0xdead));
        vm.expectRevert(ArcadeCore.GameNotRegistered.selector);
        core.processEntry(player, 100 ether, bytes32(0));
    }
}
```

### 2. Fuzz Tests

Test with random inputs to find edge cases:

```solidity
function testFuzz_ProcessEntry(
    uint256 amount,
    uint16 rakeBps
) public {
    // Bound inputs to valid ranges
    amount = bound(amount, MIN_ENTRY, MAX_ENTRY);
    rakeBps = uint16(bound(rakeBps, 0, MAX_RAKE_BPS));
    
    // Update config
    EntryConfig memory config = defaultConfig;
    config.rakeBps = rakeBps;
    gameRegistry.updateEntryConfig(address(game), config);
    
    // Execute
    vm.prank(player);
    token.approve(address(core), amount);
    
    vm.prank(address(game));
    (uint256 sessionId, uint256 netAmount) = core.processEntry(
        player,
        amount,
        game.gameId()
    );
    
    // Verify invariants
    assertGt(sessionId, 0);
    assertEq(netAmount, amount - (amount * rakeBps / 10000));
    assertEq(token.balanceOf(treasury), amount * rakeBps / 10000);
}
```

### 3. Invariant Tests

Test system-wide invariants hold under any sequence of actions:

```solidity
contract ArcadeCoreInvariantTest is Test {
    ArcadeCore public core;
    InvariantHandler public handler;

    function setUp() public {
        core = new ArcadeCore();
        // ... setup ...
        
        handler = new InvariantHandler(core);
        targetContract(address(handler));
    }

    /// @dev Total volume >= total rake + total burned + total paid out
    function invariant_VolumeAccounting() public {
        (
            uint256 totalGamesPlayed,
            uint256 totalVolume,
            uint256 totalBurned,
            uint256 totalRake
        ) = core.getGlobalStats();
        
        uint256 totalPaidOut = payoutManager.getTotalPaidOut();
        
        assertGe(
            totalVolume,
            totalRake + totalBurned + totalPaidOut
        );
    }

    /// @dev Pending payouts <= contract balance
    function invariant_SufficientBalance() public {
        uint256 pending = payoutManager.getTotalPending();
        uint256 balance = token.balanceOf(address(payoutManager));
        
        assertGe(balance, pending);
    }
}
```

### 4. Fork Tests

Test against mainnet state:

```solidity
contract ArcadeCoreForkTest is Test {
    uint256 megaEthFork;
    ArcadeCore public core;

    function setUp() public {
        megaEthFork = vm.createFork(vm.envString("MEGAETH_RPC_URL"));
        vm.selectFork(megaEthFork);
        
        // Deploy to fork
        core = new ArcadeCore();
        // ... setup using real token addresses ...
    }

    function test_IntegrationWithRealToken() public {
        // Test with actual DATA token
        IERC20 dataToken = IERC20(DATA_TOKEN_ADDRESS);
        
        // Get tokens from whale
        vm.prank(DATA_WHALE);
        dataToken.transfer(player, 1000 ether);
        
        // Test entry flow
        vm.startPrank(player);
        dataToken.approve(address(core), 100 ether);
        // ... test ...
        vm.stopPrank();
    }
}
```

### 5. Integration Tests

Test full game flows:

```solidity
contract HashCrashIntegrationTest is Test {
    ArcadeCore public core;
    GameRegistry public registry;
    PayoutManager public payoutManager;
    HashCrash public hashCrash;

    function test_FullGameCycle() public {
        // 1. Player enters game
        vm.prank(player1);
        hashCrash.placeBet(100 ether);
        
        vm.prank(player2);
        hashCrash.placeBet(200 ether);
        
        // 2. Game starts
        vm.warp(block.timestamp + BETTING_DURATION);
        hashCrash.startRound();
        
        // 3. Player 1 cashes out
        vm.prank(player1);
        hashCrash.cashOut();
        
        // 4. Game crashes
        vm.warp(block.timestamp + 30);  // VRF determines crash
        hashCrash.resolveRound();
        
        // 5. Verify outcomes
        uint256 player1Balance = token.balanceOf(player1);
        uint256 player2Balance = token.balanceOf(player2);
        
        assertGt(player1Balance, 100 ether);  // Won
        assertEq(player2Balance, 0);           // Lost
        
        // 6. Verify burns
        uint256 burned = core.totalBurned();
        assertGt(burned, 0);
    }
}
```

---

## Contract Deployment Order

```
1. Deploy DataToken (if not exists)
   └── Already deployed: 0x...

2. Deploy GhostCore (if not exists)
   └── Already deployed: 0x...

3. Deploy GameRegistry
   └── Constructor: (owner, arcadeCoreProxy)

4. Deploy PayoutManager
   └── Constructor: (dataToken, arcadeCoreProxy, owner)

5. Deploy ArcadeCore Implementation
   └── Constructor: _disableInitializers()

6. Deploy ArcadeCore Proxy (ERC1967)
   └── Initialize: (dataToken, ghostCore, treasury, admin)

7. Configure ArcadeCore
   └── setGameRegistry(gameRegistry)
   └── setPayoutManager(payoutManager)

8. Deploy Individual Games
   └── HashCrash, BinaryBet, CodeDuel, etc.

9. Register Games
   └── gameRegistry.registerGame(hashCrash, config)
   └── gameRegistry.registerGame(binaryBet, config)
   └── ...

10. Grant Roles
    └── GAME_OPERATOR_ROLE to game contracts
    └── PAUSER_ROLE to multisig
    └── REGISTRAR_ROLE to deployer (revoke after setup)
```

---

## File Structure

```
packages/contracts/src/arcade/
├── ArcadeCore.sol                    # Central hub (upgradeable)
├── GameRegistry.sol                  # Game registration
├── PayoutManager.sol                 # Prize distribution
├── interfaces/
│   ├── IArcadeGame.sol               # Game interface
│   ├── IGameRegistry.sol             # Registry interface
│   └── IPayoutManager.sol            # Payout interface
├── games/
│   ├── HashCrash.sol                 # Crash game
│   ├── BinaryBet.sol                 # Coin flip
│   ├── CodeDuel.sol                  # 1v1 typing
│   ├── IceBreaker.sol                # Reaction game
│   ├── BountyHunt.sol                # Target game
│   ├── DailyOps.sol                  # Daily challenges
│   ├── ProxyWar.sol                  # Crew battles
│   ├── ZeroDay.sol                   # Exploit chains
│   └── ShadowProtocol.sol            # Stealth mode
├── libraries/
│   ├── GameLib.sol                   # Shared game utilities
│   └── RandomnessLib.sol             # VRF helpers
└── storage/
    └── ArcadeCoreStorage.sol         # ERC-7201 storage
```

---

## Security Checklist

### Pre-Deployment

- [ ] All contracts compiled with Solidity 0.8.33
- [ ] OpenZeppelin 5.x contracts used
- [ ] ReentrancyGuard on all external state-changing functions
- [ ] Access control on all privileged functions
- [ ] Custom errors instead of require strings
- [ ] SafeERC20 for all token transfers
- [ ] Input validation on all external functions
- [ ] No use of `tx.origin`
- [ ] No selfdestruct
- [ ] No delegatecall to untrusted contracts
- [ ] Storage layout documented for upgradeable contracts
- [ ] Events emitted for all state changes

### Testing

- [ ] Unit test coverage > 90%
- [ ] Fuzz tests for all numeric inputs
- [ ] Invariant tests for economic properties
- [ ] Fork tests against production state
- [ ] Gas benchmarks documented
- [ ] Slither analysis clean (or all warnings addressed)
- [ ] Formal verification of critical invariants (optional)

### Deployment

- [ ] Timelock configured for admin functions
- [ ] Multisig for privileged roles
- [ ] Pause functionality tested
- [ ] Emergency withdrawal tested
- [ ] Upgrade path tested on testnet
- [ ] Contract verification on block explorer

---

## References

- [GHOSTNET GhostCore Contract](../../packages/contracts/src/core/GhostCore.sol)
- [GHOSTNET DataToken Contract](../../packages/contracts/src/token/DataToken.sol)
- [OpenZeppelin Contracts 5.x](https://docs.openzeppelin.com/contracts/5.x)
- [Foundry Book](https://book.getfoundry.sh/)
- [ERC-7201 Namespaced Storage](https://eips.ethereum.org/EIPS/eip-7201)
- [UUPS Proxy Pattern](https://docs.openzeppelin.com/contracts/5.x/api/proxy#UUPSUpgradeable)
