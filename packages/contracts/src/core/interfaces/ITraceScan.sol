// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { IGhostCore } from "./IGhostCore.sol";

/// @title ITraceScan
/// @notice Interface for the GHOSTNET scan and death selection contract
/// @dev Implements trustless batch verification - anyone can submit death proofs
interface ITraceScan {
    // ══════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice State of a scan in progress
    struct Scan {
        uint256 scanId; // Unique ID for epoch-based storage
        uint256 seed; // Deterministic seed for death selection
        uint64 executedAt; // When scan was executed
        uint64 finalizedAt; // When cascade was distributed
        IGhostCore.Level level; // Which level this scan targets
        uint256 totalDead; // Accumulated dead capital
        uint256 deathCount; // Number of deaths processed
        bool finalized; // Has cascade been distributed
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    error ScanNotReady();
    error ScanAlreadyActive();
    error ScanNotActive();
    error ScanAlreadyFinalized();
    error SubmissionWindowClosed();
    error SubmissionWindowNotClosed();
    error UserNotDead();
    error UserAlreadyProcessed();
    error BatchTooLarge();
    error InvalidLevel();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when a scan is executed
    event ScanExecuted(
        IGhostCore.Level indexed level, uint256 indexed scanId, uint256 seed, uint64 executedAt
    );

    /// @notice Emitted when deaths are submitted in a batch
    event DeathsSubmitted(
        IGhostCore.Level indexed level,
        uint256 indexed scanId,
        uint256 count,
        uint256 totalDead,
        address indexed submitter
    );

    /// @notice Emitted when a scan is finalized
    event ScanFinalized(
        IGhostCore.Level indexed level,
        uint256 indexed scanId,
        uint256 deathCount,
        uint256 totalDead,
        uint64 finalizedAt
    );

    // ══════════════════════════════════════════════════════════════════════════════
    // SCAN EXECUTION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Execute a scan for a level (Phase 1: seed generation)
    /// @dev Anyone can call when timer expired. Generates deterministic seed.
    /// @param level The level to scan
    function executeScan(IGhostCore.Level level) external;

    // ══════════════════════════════════════════════════════════════════════════════
    // DEATH PROOF SUBMISSION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Submit death proofs for a batch of users (Phase 2)
    /// @dev Anyone can call. Contract verifies each death is valid.
    /// @param level The level being scanned
    /// @param deadUsers Array of users who died (will be verified)
    function submitDeaths(IGhostCore.Level level, address[] calldata deadUsers) external;

    // ══════════════════════════════════════════════════════════════════════════════
    // SCAN FINALIZATION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Finalize scan and distribute cascade (Phase 3)
    /// @dev Anyone can call after submission window closes
    /// @param level The level to finalize
    function finalizeScan(IGhostCore.Level level) external;

    // ══════════════════════════════════════════════════════════════════════════════
    // DEATH VERIFICATION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Check if a user would die given a seed and death rate
    /// @dev Pure function - can be called by anyone to verify deaths off-chain
    /// @param seed The scan seed
    /// @param user The user address
    /// @param deathRateBps The death rate in basis points
    /// @return True if user dies
    function isDead(uint256 seed, address user, uint16 deathRateBps)
        external
        pure
        returns (bool);

    /// @notice Check if a user would die in the current pending scan
    /// @param level The level to check
    /// @param user The user to check
    /// @return True if user would die (false if no pending scan)
    function wouldDie(IGhostCore.Level level, address user) external view returns (bool);

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Check if a scan can be executed for a level
    function canExecuteScan(IGhostCore.Level level) external view returns (bool);

    /// @notice Check if a scan can be finalized for a level
    function canFinalizeScan(IGhostCore.Level level) external view returns (bool);

    /// @notice Get the current scan state for a level
    function getCurrentScan(IGhostCore.Level level) external view returns (Scan memory);

    /// @notice Get the submission window duration
    function submissionWindow() external view returns (uint256);

    // ══════════════════════════════════════════════════════════════════════════════
    // KEEPER INTERFACE (Gelato Automate compatible)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Gelato-compatible checker function
    /// @return canExec True if there's an action to perform
    /// @return execPayload Calldata for the action
    function checker() external view returns (bool canExec, bytes memory execPayload);
}
