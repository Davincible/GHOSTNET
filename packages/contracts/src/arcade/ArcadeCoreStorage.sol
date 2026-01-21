// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { IArcadeCore } from "./interfaces/IArcadeCore.sol";
import { IDataToken } from "../token/interfaces/IDataToken.sol";
import { IGhostCore } from "../core/interfaces/IGhostCore.sol";

/// @title ArcadeCoreStorage
/// @notice Storage layout for ArcadeCore upgradeable contract
/// @dev Uses namespaced storage pattern (ERC-7201) for upgrade safety
///
/// CRITICAL: When upgrading, only APPEND new variables at the end of the struct.
/// Never reorder, rename, or remove existing variables.
abstract contract ArcadeCoreStorage {
    // ══════════════════════════════════════════════════════════════════════════════
    // STORAGE NAMESPACE (ERC-7201)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @custom:storage-location erc7201:ghostnet.storage.ArcadeCore
    struct ArcadeCoreStorageLayout {
        // ─── Core References ─────────────────────────────────────────────────────
        IDataToken dataToken;
        IGhostCore ghostCore;
        address treasury;

        // ─── Game Registry ───────────────────────────────────────────────────────
        mapping(address game => IArcadeCore.GameConfig config) gameConfigs;
        mapping(address game => bool registered) registeredGames;

        // ─── Session Tracking ────────────────────────────────────────────────────
        /// @notice Session records by ID
        mapping(uint256 sessionId => IArcadeCore.SessionRecord record) sessions;

        /// @notice Player deposits per session
        /// @dev Key: keccak256(sessionId, player) => deposit amount
        mapping(bytes32 depositKey => uint256 amount) sessionDeposits;

        /// @notice Active sessions per game (for emergency cancellation)
        /// @dev game address => array of active session IDs
        mapping(address game => uint256[] sessionIds) gameActiveSessions;

        /// @notice Index tracking for O(1) removal from gameActiveSessions
        /// @dev sessionId => index in gameActiveSessions array
        mapping(uint256 sessionId => uint256 index) sessionIndex;

        // ─── Refund Tracking ───────────────────────────────────────────────────────
        /// @notice Gross deposits per player per session (before rake, for refund bounds)
        /// @dev Key: keccak256(sessionId, player) => gross deposit amount
        /// @dev Separate from sessionDeposits which tracks net amounts for prize pool
        mapping(bytes32 depositKey => uint256 grossAmount) sessionGrossDeposits;

        /// @notice Whether a player has been refunded for a session
        /// @dev Key: keccak256(sessionId, player) => refunded flag
        /// @dev Prevents double-refund attacks
        mapping(bytes32 depositKey => bool refunded) sessionRefunded;

        // ─── Payout Tracking ─────────────────────────────────────────────────────
        /// @notice Pending payouts per player (pull pattern)
        mapping(address player => uint256 amount) pendingPayouts;

        /// @notice Total pending payouts (for solvency checks)
        uint256 totalPendingPayouts;

        // ─── Player Statistics ───────────────────────────────────────────────────
        mapping(address player => IArcadeCore.PlayerStats stats) playerStats;

        // ─── Global Statistics ───────────────────────────────────────────────────
        uint256 totalGamesPlayed;
        uint256 totalVolume;
        uint256 totalRakeCollected;
        uint256 totalBurned;

        // ─── Reserved for Future Upgrades ────────────────────────────────────────
        uint256[40] __gap;
    }

    // keccak256(abi.encode(uint256(keccak256("ghostnet.storage.ArcadeCore")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ARCADE_CORE_STORAGE_LOCATION =
        0x8b9e8a7f6d5c4b3a2e1f0d9c8b7a6f5e4d3c2b1a0f9e8d7c6b5a4f3e2d1c0b00;

    function _getArcadeCoreStorage() internal pure returns (ArcadeCoreStorageLayout storage $) {
        assembly {
            $.slot := ARCADE_CORE_STORAGE_LOCATION
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Basis points denominator
    uint16 internal constant BPS = 10_000;

    /// @notice Minimum time between plays for rate limiting
    uint256 internal constant MIN_PLAY_INTERVAL = 1 seconds;

    /// @notice Dead address for burns
    address internal constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    /// @notice Maximum batch size for batch operations
    /// @dev Prevents DoS via excessive gas consumption
    /// @dev Interface exposes via MAX_BATCH_SIZE() function in ArcadeCore
    // solhint-disable-next-line var-name-mixedcase
    uint256 internal constant _MAX_BATCH_SIZE = 100;

    /// @notice Scale factor for packing large amounts into uint128 statistics fields
    /// @dev PRECISION CHARACTERISTICS:
    ///      - Minimum trackable: 1e6 wei = 1 pico-DATA (1e-12 DATA)
    ///      - Maximum trackable: uint128.max * 1e6 ≈ 340 undecillion wei (effectively unlimited)
    ///      - Truncation: Amounts < 1e6 wei are LOST (round toward zero)
    ///
    ///      IMPORTANT: These scaled values are APPROXIMATIONS for analytics/display.
    ///      DO NOT use scaled PlayerStats fields for:
    ///      - Solvency calculations (use $.totalPendingPayouts instead)
    ///      - Payout bounds checking (use session.prizePool instead)
    ///      - Any financial invariant testing
    ///
    ///      Safe to use scaled PlayerStats for:
    ///      - Leaderboards and rankings
    ///      - Player statistics display in UI
    ///      - Historical analytics and reporting
    ///
    ///      SOURCE OF TRUTH TABLE:
    ///      ┌─────────────────────┬──────────────────────────┬───────────────┬──────────────────────┐
    ///      │ Metric              │ Authoritative Source     │ Precision     │ Use For              │
    ///      ├─────────────────────┼──────────────────────────┼───────────────┼──────────────────────┤
    ///      │ Total volume        │ $.totalVolume            │ Full (uint256)│ Accounting, invariants│
    ///      │ Total burned        │ $.totalBurned            │ Full (uint256)│ Accounting, invariants│
    ///      │ Pending payouts     │ $.totalPendingPayouts    │ Full (uint256)│ Solvency checks      │
    ///      │ Session prize pool  │ session.prizePool        │ Full (uint256)│ Payout bounds        │
    ///      │ Player wagered      │ stats.totalWagered       │ Scaled (uint128)│ Analytics only     │
    ///      │ Player won          │ stats.totalWon           │ Scaled (uint128)│ Analytics only     │
    ///      │ Player burned       │ stats.totalBurned        │ Scaled (uint128)│ Analytics only     │
    ///      └─────────────────────┴──────────────────────────┴───────────────┴──────────────────────┘
    ///
    ///      WHY 1e6 (not 1e12): With 1e12, bets under 0.000001 DATA (~$0.000001 at typical prices)
    ///      were completely lost from analytics. 1e6 allows tracking down to 1 pico-DATA while
    ///      still fitting comfortably in uint128 for amounts up to 340 billion DATA per field.
    uint256 internal constant AMOUNT_SCALE = 1e6;

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL HELPERS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Compute deposit key for session/player combination
    /// @param sessionId Session ID
    /// @param player Player address
    /// @return Composite key for sessionDeposits mapping
    function _depositKey(
        uint256 sessionId,
        address player
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(sessionId, player));
    }
}
