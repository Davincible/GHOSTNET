// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { IGhostCore } from "../../core/interfaces/IGhostCore.sol";

/// @title IDeadPool
/// @notice Interface for the GHOSTNET prediction market
/// @dev Parimutuel betting on scan outcomes
interface IDeadPool {
    // ══════════════════════════════════════════════════════════════════════════════
    // ENUMS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Types of prediction rounds
    enum RoundType {
        DEATH_COUNT, // Over/under deaths in next scan
        WHALE_DEATH, // Will a 1000+ DATA position die?
        STREAK_RECORD, // Will anyone hit 20 survival streak?
        SYSTEM_RESET // Will timer hit <1 hour?
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice A betting round
    struct Round {
        RoundType roundType; // Type of prediction
        IGhostCore.Level targetLevel; // Which level (if applicable)
        uint256 line; // Over/under line (e.g., 50 deaths)
        uint256 overPool; // Total bet on OVER
        uint256 underPool; // Total bet on UNDER
        uint64 deadline; // Betting closes at
        uint64 resolveTime; // When outcome was determined
        bool resolved; // Has been resolved
        bool outcome; // true = OVER won, false = UNDER won
    }

    /// @notice A user's bet
    struct Bet {
        uint256 amount; // Amount wagered
        bool isOver; // true = OVER, false = UNDER
        bool claimed; // Has been claimed
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    error RoundNotFound();
    error RoundEnded();
    error RoundNotEnded();
    error RoundNotResolved();
    error RoundAlreadyResolved();
    error InvalidAmount();
    error NoBetExists();
    error AlreadyClaimed();
    error NotWinner();
    error NotAuthorized();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when a new round is created
    event RoundCreated(
        uint256 indexed roundId,
        RoundType roundType,
        IGhostCore.Level indexed targetLevel,
        uint256 line,
        uint64 deadline
    );

    /// @notice Emitted when a bet is placed
    event BetPlaced(uint256 indexed roundId, address indexed user, bool isOver, uint256 amount);

    /// @notice Emitted when a round is resolved
    event RoundResolved(uint256 indexed roundId, bool outcome, uint256 totalPot, uint256 burned);

    /// @notice Emitted when winnings are claimed
    event WinningsClaimed(uint256 indexed roundId, address indexed user, uint256 amount);

    // ══════════════════════════════════════════════════════════════════════════════
    // BETTING FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Place a bet on a round
    /// @param roundId The round to bet on
    /// @param isOver True for OVER, false for UNDER
    /// @param amount Amount of DATA to wager
    function placeBet(
        uint256 roundId,
        bool isOver,
        uint256 amount
    ) external;

    /// @notice Claim winnings from a resolved round
    /// @param roundId The round to claim from
    /// @return winnings Amount claimed
    function claimWinnings(
        uint256 roundId
    ) external returns (uint256 winnings);

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get round information
    function getRound(
        uint256 roundId
    ) external view returns (Round memory);

    /// @notice Get user's bet on a round
    function getBet(
        uint256 roundId,
        address user
    ) external view returns (Bet memory);

    /// @notice Calculate potential winnings for a bet
    function calculateWinnings(
        uint256 roundId,
        address user
    ) external view returns (uint256);

    /// @notice Get current odds for OVER (in basis points)
    function getOverOdds(
        uint256 roundId
    ) external view returns (uint16);

    /// @notice Get current odds for UNDER (in basis points)
    function getUnderOdds(
        uint256 roundId
    ) external view returns (uint16);

    /// @notice Get total number of rounds
    function roundCount() external view returns (uint256);
}
