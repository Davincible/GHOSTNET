// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title IArcadeCore
/// @notice Interface for the GHOSTNET Arcade core contract
/// @dev Manages game registration, session tracking, and payout validation
interface IArcadeCore {
    // ══════════════════════════════════════════════════════════════════════════════
    // ENUMS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Session lifecycle states
    /// @dev Terminal states (SETTLED, CANCELLED) prevent further financial operations
    enum SessionState {
        NONE, // 0 - Default, session doesn't exist
        ACTIVE, // 1 - Session created, accepting activity
        SETTLED, // 2 - Terminal: Payouts completed
        CANCELLED // 3 - Terminal: Refunds issued
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Core session tracking record
    /// @dev One record per session, created on first processEntry() call
    struct SessionRecord {
        address game; // Game contract that owns this session
        uint256 prizePool; // Total tokens available for payouts
        uint256 totalPaid; // Cumulative payouts issued (invariant: totalPaid <= prizePool)
        SessionState state; // Current state (state machine)
        uint64 createdAt; // Block timestamp of creation
        uint64 settledAt; // Block timestamp of settlement (0 if not settled)
    }

    /// @notice Configuration for a registered game
    struct GameConfig {
        uint256 minEntry; // Minimum entry amount
        uint256 maxEntry; // Maximum entry amount (0 = no limit)
        uint16 rakeBps; // Rake percentage in basis points
        uint16 burnBps; // Burn percentage of rake in basis points
        bool requiresPosition; // Whether player needs active GhostCore position
        bool paused; // Whether game is temporarily paused
    }

    /// @notice Player statistics tracking
    /// @dev Amount fields (totalWagered, totalWon) are SCALED by AMOUNT_SCALE (1e6).
    ///      These are APPROXIMATIONS for analytics/leaderboards, not authoritative values.
    ///
    ///      PRECISION CHARACTERISTICS:
    ///      - Stored value = actual wei / 1e6
    ///      - Minimum trackable: 1e6 wei = 1 pico-DATA (1e-12 DATA)
    ///      - Maximum trackable: uint128.max ≈ 340 undecillion scaled units
    ///      - Truncation: Amounts < 1e6 wei truncate to 0 in stats
    ///
    ///      WARNING: Do NOT use these fields for financial invariants.
    ///      Use $.totalVolume, $.totalBurned, $.totalPendingPayouts instead.
    ///
    ///      To convert to approximate wei: multiply by 1e6
    ///      Example: stats.totalWagered * 1e6 ≈ actual wei wagered
    struct PlayerStats {
        uint64 totalGamesPlayed;
        uint128 totalWagered; // Scaled by 1e6 - ANALYTICS ONLY, not for accounting
        uint128 totalWon; // Scaled by 1e6 - ANALYTICS ONLY, not for accounting
        uint64 totalWins;
        uint64 totalLosses;
        uint64 lastPlayTime;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    // === GAME ERRORS ===
    error GameNotRegistered();
    error GameAlreadyRegistered();
    error GamePaused();

    // === SESSION ERRORS ===
    error SessionNotFound();
    error SessionGameMismatch();
    error SessionNotActive();
    error SessionAlreadyExists();

    // === PAYOUT ERRORS ===
    error PayoutExceedsPrizePool();
    error InvalidPayoutAmount();

    // === REFUND ERRORS ===
    error RefundExceedsDeposit();
    error InvalidRefundAmount();
    error AlreadyRefunded();
    error SessionNotRefundable();
    error RefundsBlockedAfterPayouts();
    error NoDepositFound();

    // === ENTRY ERRORS ===
    error InvalidEntryAmount();
    error PositionRequired();
    error RateLimited();

    // === BATCH ERRORS ===
    /// @notice Thrown when batch arrays have mismatched lengths
    /// @param sessionIdsLen Length of sessionIds array
    /// @param playersLen Length of players array
    /// @param amountsLen Length of amounts array
    /// @param burnAmountsLen Length of burnAmounts array
    /// @param resultsLen Length of results array
    error ArrayLengthMismatch(
        uint256 sessionIdsLen,
        uint256 playersLen,
        uint256 amountsLen,
        uint256 burnAmountsLen,
        uint256 resultsLen
    );

    /// @notice Thrown when batch size exceeds maximum allowed
    /// @param size Actual batch size
    /// @param maxSize Maximum allowed batch size
    error BatchTooLarge(uint256 size, uint256 maxSize);

    /// @notice Thrown when batch is empty
    error EmptyBatch();

    // === ADMIN ERRORS ===
    error GameNotQuarantinable();
    error InvalidAddress();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when a game is registered
    event GameRegistered(address indexed game, GameConfig config);

    /// @notice Emitted when a game is unregistered
    event GameUnregistered(address indexed game);

    /// @notice Emitted when a game's config is updated
    event GameConfigUpdated(address indexed game, GameConfig config);

    /// @notice Emitted when a session is created
    event SessionCreated(address indexed game, uint256 indexed sessionId, uint64 timestamp);

    /// @notice Emitted when a session is settled
    event SessionSettled(
        address indexed game, uint256 indexed sessionId, uint256 totalPaid, uint256 remaining
    );

    /// @notice Emitted when a session is cancelled
    event SessionCancelled(address indexed game, uint256 indexed sessionId, uint256 prizePool);

    /// @notice Emitted when entry is processed
    event EntryProcessed(
        address indexed game,
        address indexed player,
        uint256 indexed sessionId,
        uint256 amount,
        uint256 netAmount,
        uint256 rakeAmount
    );

    /// @notice Emitted when a payout is credited
    event PayoutCredited(address indexed player, uint256 amount, uint256 totalPending);

    /// @notice Emitted when a game result is settled
    event GameSettled(
        address indexed game,
        address indexed player,
        uint256 indexed sessionId,
        uint256 payout,
        uint256 burned,
        bool won
    );

    /// @notice Emitted when a batch of payouts is processed
    event BatchPayoutProcessed(
        address indexed game, uint256 batchSize, uint256 totalPaid, uint256 totalBurned
    );

    /// @notice Emitted when emergency refund is issued
    event EmergencyRefund(
        address indexed game, address indexed player, uint256 indexed sessionId, uint256 amount
    );

    /// @notice Emitted when batch emergency refund is processed
    event BatchEmergencyRefund(
        address indexed game,
        uint256 indexed sessionId,
        uint256 playersRefunded,
        uint256 totalRefunded
    );

    /// @notice Emitted when player claims expired session refund
    event ExpiredRefundClaimed(address indexed player, uint256 indexed sessionId, uint256 amount);

    /// @notice Emitted when a game is quarantined
    event GameQuarantined(address indexed game, uint256 sessionsAffected);

    /// @notice Emitted when player withdraws pending payout
    event PayoutWithdrawn(address indexed player, uint256 amount);

    // ══════════════════════════════════════════════════════════════════════════════
    // GAME MANAGEMENT FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Register a new game
    /// @param game Address of the game contract
    /// @param config Initial configuration for the game
    function registerGame(
        address game,
        GameConfig calldata config
    ) external;

    /// @notice Unregister a game
    /// @param game Address of the game contract
    function unregisterGame(
        address game
    ) external;

    /// @notice Update game configuration
    /// @param game Address of the game contract
    /// @param config New configuration
    function updateGameConfig(
        address game,
        GameConfig calldata config
    ) external;

    /// @notice Pause a specific game
    /// @param game Address of the game contract
    function pauseGame(
        address game
    ) external;

    /// @notice Unpause a specific game
    /// @param game Address of the game contract
    function unpauseGame(
        address game
    ) external;

    // ══════════════════════════════════════════════════════════════════════════════
    // SESSION FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Process entry fee for a game session
    /// @param player Address of the player
    /// @param amount Entry fee amount
    /// @param sessionId Game-provided session ID
    /// @return netAmount Amount after rake (for prize pool)
    function processEntry(
        address player,
        uint256 amount,
        uint256 sessionId
    ) external returns (uint256 netAmount);

    /// @notice Credit payout to player with session validation
    /// @param sessionId Session this payout belongs to
    /// @param player Address of the player
    /// @param amount Payout amount
    /// @param burnAmount Amount to burn from prize pool
    /// @param won Whether player won
    function creditPayout(
        uint256 sessionId,
        address player,
        uint256 amount,
        uint256 burnAmount,
        bool won
    ) external;

    /// @notice Credit payouts to multiple players in a single transaction
    /// @param sessionIds Session IDs for each payout
    /// @param players Player addresses
    /// @param amounts Payout amounts
    /// @param burnAmounts Burn amounts
    /// @param results Win/loss results
    /// @dev All arrays must have equal length and length <= MAX_BATCH_SIZE
    function batchCreditPayouts(
        uint256[] calldata sessionIds,
        address[] calldata players,
        uint256[] calldata amounts,
        uint256[] calldata burnAmounts,
        bool[] calldata results
    ) external;

    /// @notice Mark session as settled
    /// @param sessionId Session to settle
    function settleSession(
        uint256 sessionId
    ) external;

    /// @notice Cancel session and mark for refunds
    /// @param sessionId Session to cancel
    function cancelSession(
        uint256 sessionId
    ) external;

    /// @notice Emergency refund with session and deposit validation
    /// @dev Games can only refund players who deposited in their sessions.
    ///      Amount must not exceed player's gross deposit (before rake).
    ///      Refunds track and prevent double-refund attacks.
    /// @param sessionId Session to refund from (must be owned by caller)
    /// @param player Address to refund
    /// @param amount Amount to refund (bounded by player's deposit)
    function emergencyRefund(
        uint256 sessionId,
        address player,
        uint256 amount
    ) external;

    /// @notice Batch emergency refund for multiple players in a session
    /// @dev More gas efficient than individual calls. Same validations apply.
    ///      Refunds each player their full gross deposit.
    /// @param sessionId Session to refund from (must be owned by caller)
    /// @param players Array of player addresses to refund
    function batchEmergencyRefund(
        uint256 sessionId,
        address[] calldata players
    ) external;

    /// @notice Self-service refund for expired sessions
    /// @dev Anyone can call this for any player with an expired session.
    ///      Enables permissionless recovery when seed blocks expire.
    ///      Session must be in EXPIRED state (set by game contract).
    /// @param sessionId Expired session to refund from
    /// @param player Address to refund
    function claimExpiredRefund(
        uint256 sessionId,
        address player
    ) external;

    // ══════════════════════════════════════════════════════════════════════════════
    // PLAYER FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Withdraw pending payouts
    /// @return amount Amount withdrawn
    function withdrawPayout() external returns (uint256 amount);

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get session record
    /// @param sessionId Session ID to query
    /// @return Session record
    function getSession(
        uint256 sessionId
    ) external view returns (SessionRecord memory);

    /// @notice Get game configuration
    /// @param game Game address to query
    /// @return Game configuration
    function getGameConfig(
        address game
    ) external view returns (GameConfig memory);

    /// @notice Check if game is registered
    /// @param game Game address to check
    /// @return Whether game is registered
    function isGameRegistered(
        address game
    ) external view returns (bool);

    /// @notice Get player's deposit in a session
    /// @param sessionId Session ID
    /// @param player Player address
    /// @return Deposit amount
    function getSessionDeposit(
        uint256 sessionId,
        address player
    ) external view returns (uint256);

    /// @notice Get player's pending payout balance
    /// @param player Player address
    /// @return Pending payout amount
    function getPendingPayout(
        address player
    ) external view returns (uint256);

    /// @notice Get player statistics
    /// @dev WARNING: Amount fields (totalWagered, totalWon) are SCALED by 1e6.
    ///      Multiply by 1e6 to get approximate wei values.
    ///      These are for display/analytics ONLY, not for financial calculations.
    ///      For authoritative accounting values, use totalVolume(), totalBurned(),
    ///      and totalPendingPayouts() instead.
    /// @param player Player address
    /// @return stats Player statistics with scaled amount fields
    function getPlayerStats(
        address player
    ) external view returns (PlayerStats memory stats);
}
