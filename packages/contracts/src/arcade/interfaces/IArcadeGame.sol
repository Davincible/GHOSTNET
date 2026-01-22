// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { IArcadeTypes } from "./IArcadeTypes.sol";

/// @title IArcadeGame
/// @notice Interface that all GHOSTNET Arcade games must implement
/// @dev Games interact with ArcadeCore for:
///      - Entry fee processing (processEntry)
///      - Payout crediting (creditPayout)
///      - Session management (settleSession, cancelSession)
///      - Emergency refunds (emergencyRefund)
///
///      Security Model:
///      - Games own sessions and control their lifecycle
///      - Games can only credit payouts for sessions they created
///      - Payouts are bounded by the session's prize pool
///      - ArcadeCore holds all tokens; games never custody funds
///
/// @custom:security-contact security@ghostnet.game
interface IArcadeGame is IArcadeTypes {
    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Invalid session state for the operation
    error InvalidSessionState();

    /// @notice Session doesn't exist
    error SessionDoesNotExist();

    /// @notice Session already exists
    error SessionAlreadyExists();

    /// @notice Player not in session
    error PlayerNotInSession();

    /// @notice Player already in session
    error PlayerAlreadyInSession();

    /// @notice Invalid bet amount
    error InvalidBetAmount();

    /// @notice Round has expired (seed not revealed in time)
    error RoundExpired();

    /// @notice Action not allowed (generic)
    error ActionNotAllowed();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when a new game round/session starts
    event RoundStarted(uint256 indexed roundId, uint256 seedBlock, uint64 timestamp);

    /// @notice Emitted when a player places a bet
    event BetPlaced(
        uint256 indexed roundId, address indexed player, uint256 amount, uint256 netAmount
    );

    /// @notice Emitted when a round is resolved with outcome
    event RoundResolved(uint256 indexed roundId, uint256 seed, uint256 outcome);

    /// @notice Emitted when a player is paid out
    event PlayerPaidOut(uint256 indexed roundId, address indexed player, uint256 payout, bool won);

    /// @notice Emitted when a round is cancelled
    event RoundCancelled(uint256 indexed roundId, string reason);

    // ══════════════════════════════════════════════════════════════════════════════
    // METADATA
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get game metadata
    /// @return info The game information struct
    function getGameInfo() external view returns (GameInfo memory info);

    /// @notice Get game's unique identifier
    /// @return id The game ID (keccak256 of name)
    function gameId() external view returns (bytes32 id);

    // ══════════════════════════════════════════════════════════════════════════════
    // SESSION QUERIES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get current session/round ID
    /// @return id The current session ID (0 if none active)
    function currentSessionId() external view returns (uint256 id);

    /// @notice Get session state
    /// @param sessionId Session to query
    /// @return state The session state
    function getSessionState(
        uint256 sessionId
    ) external view returns (SessionState state);

    /// @notice Check if player is in a session
    /// @param sessionId Session to check
    /// @param player Player address
    /// @return inSession True if player is in the session
    function isPlayerInSession(
        uint256 sessionId,
        address player
    ) external view returns (bool inSession);

    /// @notice Get session prize pool (net deposits after rake)
    /// @param sessionId Session to query
    /// @return prizePool The total prize pool
    function getSessionPrizePool(
        uint256 sessionId
    ) external view returns (uint256 prizePool);

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Pause game (stops new entries)
    function pause() external;

    /// @notice Unpause game
    function unpause() external;

    /// @notice Check if game is paused
    /// @return paused True if game is paused
    function isPaused() external view returns (bool paused);

    // ══════════════════════════════════════════════════════════════════════════════
    // EMERGENCY
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emergency cancel a session and refund all players
    /// @dev Should call arcadeCore.emergencyRefund for each player
    /// @param sessionId Session to cancel
    /// @param reason Cancellation reason (for events/logging)
    function emergencyCancel(
        uint256 sessionId,
        string calldata reason
    ) external;
}
