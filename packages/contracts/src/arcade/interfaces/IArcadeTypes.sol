// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title IArcadeTypes
/// @notice Shared types for GHOSTNET Arcade
/// @dev All arcade contracts import these types for consistency
interface IArcadeTypes {
    // ═══════════════════════════════════════════════════════════════════════════════
    // ENUMS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Game categories for UI grouping and configuration
    enum GameCategory {
        CASINO, // 0 - Games of chance (Hash Crash, Binary Bet)
        COMPETITIVE, // 1 - PvP games (Code Duel, Proxy War)
        SKILL, // 2 - Skill-based (Ice Breaker, Zero Day)
        PROGRESSION, // 3 - Daily/streak games (Daily Ops)
        SOCIAL // 4 - Social features (Bounty Hunt, Shadow Protocol)
    }

    /// @notice Standard game session states
    /// @dev State machine: NONE -> ACTIVE -> (SETTLED | CANCELLED)
    ///      BETTING/LOCKED/RESOLVING/EXPIRED are game-specific substates
    enum SessionState {
        NONE, // 0 - Session doesn't exist
        BETTING, // 1 - Accepting bets/entries (game-specific)
        LOCKED, // 2 - No more entries, waiting for seed (game-specific)
        ACTIVE, // 3 - Game in progress, payouts allowed
        RESOLVING, // 4 - Determining outcomes (game-specific)
        SETTLED, // 5 - Terminal: Payouts complete
        CANCELLED, // 6 - Terminal: Refunds enabled
        EXPIRED // 7 - Terminal: Seed block expired, refunding
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Entry fee configuration per game
    /// @dev Configured in GameRegistry, read by ArcadeCore during processEntry
    struct EntryConfig {
        uint128 minEntry; // Minimum entry fee in DATA
        uint128 maxEntry; // Maximum entry fee (0 = no max)
        uint16 rakeBps; // Protocol rake in basis points (max 1000 = 10%)
        uint16 burnBps; // Burn rate in basis points (of rake)
        bool requiresPosition; // Must have GhostCore position
        bool boostEligible; // Can earn death reduction boosts
    }

    /// @notice Player statistics (packed for storage efficiency)
    /// @dev Amount fields are SCALED by AMOUNT_SCALE (1e6) for uint128 packing.
    ///      These are APPROXIMATIONS for analytics/leaderboards, NOT authoritative values.
    ///
    ///      PRECISION CHARACTERISTICS:
    ///      - Stored value = actual wei / 1e6
    ///      - Minimum trackable: 1e6 wei = 1 pico-DATA (1e-12 DATA)
    ///      - Maximum trackable: uint128.max ≈ 340 undecillion scaled units
    ///      - Truncation: Amounts < 1e6 wei are LOST (round toward zero)
    ///
    ///      IMPORTANT: Do NOT use these fields for financial invariants or accounting.
    ///      Use $.totalVolume, $.totalBurned, $.totalPendingPayouts for authoritative values.
    ///
    ///      Safe to use for: Leaderboards, UI display, historical analytics.
    ///
    ///      To convert to approximate wei: multiply by 1e6
    ///      Example: stats.totalWagered * 1e6 ≈ actual wei wagered (with truncation error)
    struct PlayerStats {
        uint64 totalGamesPlayed; // Total games across all arcade
        uint64 totalWins; // Total wins
        uint64 totalLosses; // Total losses
        uint128 totalWagered; // Scaled by 1e6 - ANALYTICS ONLY, truncates < 1e6 wei
        uint128 totalWon; // Scaled by 1e6 - ANALYTICS ONLY, truncates < 1e6 wei
        uint128 totalBurned; // Scaled by 1e6 - ANALYTICS ONLY, truncates < 1e6 wei
        uint32 currentStreak; // Current win streak
        uint32 maxStreak; // Best win streak ever
        uint64 lastPlayTime; // Timestamp of last play (for rate limiting)
    }

    /// @notice Game metadata for registry
    struct GameInfo {
        bytes32 gameId; // Unique identifier (keccak256 of name)
        string name; // Display name
        string description; // Short description
        GameCategory category; // Game category
        uint8 minPlayers; // Minimum players (1 for solo)
        uint8 maxPlayers; // Maximum players (0 = unlimited)
        bool isActive; // Accepting new sessions
        uint64 launchedAt; // Launch timestamp
    }

    /// @notice Randomness seed tracking (for games using future block hash)
    struct SeedInfo {
        uint256 seedBlock; // Block number for seed
        bytes32 blockHash; // Captured block hash
        uint256 seed; // Derived seed value
        bool committed; // Seed block set
        bool revealed; // Seed captured
    }

    /// @notice Session record for payout tracking in ArcadeCore
    /// @dev Critical for security: bounds all payouts and refunds
    struct SessionRecord {
        address game; // Game contract that owns this session
        uint128 prizePool; // Total tokens available for payouts (net after rake)
        uint128 totalPaid; // Cumulative payouts + burns issued
        SessionState state; // Current state (state machine)
        uint64 createdAt; // Block timestamp of creation
        uint64 settledAt; // Block timestamp of settlement (0 if active)
    }

    /// @notice Player deposit within a session for refund tracking
    /// @dev Used to bound emergency refunds to actual player deposits
    struct PlayerSessionDeposit {
        uint128 grossAmount; // Amount deposited before rake (what player paid)
        uint128 netAmount; // Amount after rake (contribution to prize pool)
        bool refunded; // True if player has been refunded for this session
    }
}
