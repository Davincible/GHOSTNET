// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title ArcadeCoreCircuitBreakerTimelock
/// @notice Circuit breaker reset timelock implementation for ArcadeCore
/// @dev This file contains the circuit breaker timelock logic to be integrated into ArcadeCore.
///      It implements ADR-005: Circuit Breaker Reset Timelock Mechanism.
///
/// Security Model:
/// - Full reset requires 12-hour timelock (detection window for attacks)
/// - Guardian role can veto pending resets (defensive-only capability)
/// - Partial reset (counters only) available immediately (operational flexibility)
/// - Reset proposals auto-invalidate if breaker trips again during pending period
///
/// State Transitions:
/// - NORMAL -> TRIPPED: Automatic when limits exceeded
/// - TRIPPED -> RESET_PENDING: Admin proposes reset
/// - RESET_PENDING -> READY: After 12h timelock
/// - RESET_PENDING -> TRIPPED: Guardian veto or re-trip
/// - READY -> NORMAL: Admin executes
///
/// @custom:security-contact security@ghostnet.game

// ============================================================================
// CONSTANTS
// ============================================================================

/// @dev Timelock delay for circuit breaker resets (12 hours)
///      Provides detection window for security team to identify and respond to attacks.
///      Chosen based on:
///      - Typical incident detection time: 1-4 hours
///      - Investigation and coordination: 2-4 hours
///      - Buffer for global team coverage: 4 hours
uint48 constant CB_RESET_TIMELOCK = 12 hours;

/// @dev Maximum age for pending proposals before they expire
///      Prevents stale proposals from being executed much later
uint48 constant CB_PROPOSAL_EXPIRY = 48 hours;

/// @dev Guardian role identifier
bytes32 constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

// ============================================================================
// TYPES
// ============================================================================

/// @notice Pending circuit breaker reset proposal
/// @dev Packed into 2 slots for gas efficiency
struct PendingCircuitBreakerReset {
    address proposer; // Who proposed the reset (slot 1: 20 bytes)
    uint48 executeAfter; // Timestamp when execution is allowed (slot 1: 6 bytes)
    uint48 expiresAt; // Timestamp when proposal expires (slot 1: 6 bytes)
    bool vetoed; // Whether guardian has vetoed (slot 2: 1 byte)
    bool executed; // Whether reset was executed (slot 2: 1 byte)
    bool exists; // Whether proposal exists (slot 2: 1 byte)
    // Remaining: 29 bytes in slot 2 (unused)
}

// ============================================================================
// ERRORS
// ============================================================================

/// @notice Reset proposal already exists for this ID
error ResetAlreadyProposed(bytes32 resetId);

/// @notice No pending reset proposal found
error ResetNotProposed(bytes32 resetId);

/// @notice Reset timelock has not elapsed yet
error ResetTimelockActive(bytes32 resetId, uint256 executeAfter);

/// @notice Reset was vetoed by guardian
error ResetVetoed(bytes32 resetId);

/// @notice Reset was already executed
error ResetAlreadyExecuted(bytes32 resetId);

/// @notice Reset proposal has expired
error ResetProposalExpired(bytes32 resetId);

/// @notice Circuit breaker is not currently tripped
error CircuitBreakerNotTripped();

/// @notice Circuit breaker was re-tripped after proposal (invalidates proposal)
error CircuitBreakerRetripped(bytes32 resetId);

/// @notice Cannot veto - proposal doesn't exist or already finalized
error CannotVeto(bytes32 resetId);

// ============================================================================
// EVENTS
// ============================================================================

/// @notice Emitted when a circuit breaker reset is proposed
/// @param resetId Unique identifier for this reset proposal
/// @param proposer Address that proposed the reset
/// @param executeAfter Timestamp when reset can be executed
/// @param expiresAt Timestamp when proposal expires
event CircuitBreakerResetProposed(
    bytes32 indexed resetId, address indexed proposer, uint256 executeAfter, uint256 expiresAt
);

/// @notice Emitted when a guardian vetoes a pending reset
/// @param resetId The reset proposal being vetoed
/// @param guardian The guardian who vetoed
/// @param reason Human-readable reason for veto
event CircuitBreakerResetVetoed(bytes32 indexed resetId, address indexed guardian, string reason);

/// @notice Emitted when admin cancels their own reset proposal
/// @param resetId The cancelled reset proposal
/// @param canceller The admin who cancelled
event CircuitBreakerResetCancelled(bytes32 indexed resetId, address indexed canceller);

/// @notice Emitted when a reset is successfully executed
/// @param resetId The executed reset proposal
/// @param executor The admin who executed
event CircuitBreakerResetExecuted(bytes32 indexed resetId, address indexed executor);

/// @notice Emitted when payout counters are reset (partial reset)
/// @param admin The admin who reset counters
/// @param hourlyBefore Hourly counter value before reset
/// @param dailyBefore Daily counter value before reset
event PayoutCountersReset(address indexed admin, uint256 hourlyBefore, uint256 dailyBefore);

/// @notice Emitted when circuit breaker trips (enhanced with timestamp)
/// @param reason Human-readable reason for trip
/// @param value The value that triggered the trip
/// @param timestamp When the trip occurred
event CircuitBreakerTrippedWithTimestamp(string reason, uint256 value, uint256 timestamp);

// ============================================================================
// STORAGE EXTENSION (to be added to ArcadeCoreStorage)
// ============================================================================

/// @notice Extended storage for circuit breaker timelock
/// @dev Add these fields to ArcadeCoreStorage struct:
///
/// ```solidity
/// // Circuit breaker timelock state
/// mapping(bytes32 => PendingCircuitBreakerReset) pendingResets;
/// uint256 lastTripTimestamp;  // Track when breaker was last tripped
/// ```

// ============================================================================
// IMPLEMENTATION (Functions to add to ArcadeCore)
// ============================================================================

/// @title IArcadeCoreCircuitBreakerTimelock
/// @notice Interface for circuit breaker timelock functions
interface IArcadeCoreCircuitBreakerTimelock {
    // ─────────────────────────────────────────────────────────────────────────
    // ADMIN FUNCTIONS
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Propose a full circuit breaker reset
    /// @dev Only callable when circuit breaker is tripped.
    ///      Starts 12-hour timelock before reset can be executed.
    /// @return resetId Unique identifier for tracking this proposal
    function proposeCircuitBreakerReset() external returns (bytes32 resetId);

    /// @notice Cancel a pending reset proposal
    /// @dev Only the original proposer or DEFAULT_ADMIN_ROLE can cancel.
    /// @param resetId The reset proposal to cancel
    function cancelCircuitBreakerReset(
        bytes32 resetId
    ) external;

    /// @notice Execute a reset after timelock has elapsed
    /// @dev Fails if vetoed, not ready, or expired.
    /// @param resetId The reset proposal to execute
    function executeCircuitBreakerReset(
        bytes32 resetId
    ) external;

    /// @notice Reset payout counters without disabling the breaker
    /// @dev Available immediately - allows limited activity while investigating.
    ///      Breaker remains tripped, but counters start fresh.
    function resetPayoutCounters() external;

    // ─────────────────────────────────────────────────────────────────────────
    // GUARDIAN FUNCTIONS
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Veto a pending reset proposal
    /// @dev Only GUARDIAN_ROLE can veto. Defensive-only capability.
    /// @param resetId The reset proposal to veto
    /// @param reason Human-readable reason for the veto
    function vetoCircuitBreakerReset(
        bytes32 resetId,
        string calldata reason
    ) external;

    // ─────────────────────────────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Get details of a pending reset proposal
    /// @param resetId The reset proposal to query
    /// @return proposer Who proposed the reset
    /// @return executeAfter When the reset can be executed
    /// @return expiresAt When the proposal expires
    /// @return vetoed Whether the proposal was vetoed
    /// @return executed Whether the reset was executed
    /// @return exists Whether the proposal exists
    function getResetProposal(
        bytes32 resetId
    )
        external
        view
        returns (
            address proposer,
            uint256 executeAfter,
            uint256 expiresAt,
            bool vetoed,
            bool executed,
            bool exists
        );

    /// @notice Check if a reset can be executed now
    /// @param resetId The reset proposal to check
    /// @return canExecute True if reset can be executed
    /// @return reason Human-readable reason if cannot execute
    function canExecuteReset(
        bytes32 resetId
    ) external view returns (bool canExecute, string memory reason);

    /// @notice Get time remaining until reset can be executed
    /// @param resetId The reset proposal to check
    /// @return timeRemaining Seconds until execution (0 if ready or invalid)
    function getResetTimeRemaining(
        bytes32 resetId
    ) external view returns (uint256 timeRemaining);

    /// @notice Get the timestamp of the last circuit breaker trip
    /// @return timestamp When the breaker was last tripped
    function getLastTripTimestamp() external view returns (uint256 timestamp);
}

// ============================================================================
// REFERENCE IMPLEMENTATION
// ============================================================================

/*
 * The following is a reference implementation to be integrated into ArcadeCore.
 * Copy the relevant functions and adapt to the existing storage pattern.
 *
 * Key Integration Points:
 * 1. Add storage fields to ArcadeCoreStorage
 * 2. Add GUARDIAN_ROLE to role definitions
 * 3. Update _tripCircuitBreaker to set lastTripTimestamp
 * 4. Replace existing resetCircuitBreaker with new timelock version
 */

abstract contract ArcadeCoreCircuitBreakerTimelockImpl {
    // Storage - to be replaced with actual storage access
    mapping(bytes32 => PendingCircuitBreakerReset) internal _pendingResets;
    uint256 internal _lastTripTimestamp;
    bool internal _circuitBreakerTripped;
    uint256 internal _hourlyPayouts;
    uint256 internal _dailyPayouts;
    uint256 internal _lastHourTimestamp;
    uint256 internal _lastDayTimestamp;

    // Role checks - to be replaced with actual AccessControl calls
    function _checkRole(
        bytes32 role
    ) internal view virtual;
    function hasRole(
        bytes32 role,
        address account
    ) public view virtual returns (bool);

    // ─────────────────────────────────────────────────────────────────────────
    // MODIFIERS
    // ─────────────────────────────────────────────────────────────────────────

    modifier onlyWhenTripped() {
        if (!_circuitBreakerTripped) revert CircuitBreakerNotTripped();
        _;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ADMIN FUNCTIONS
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Propose a full circuit breaker reset
    function proposeCircuitBreakerReset() external onlyWhenTripped returns (bytes32 resetId) {
        _checkRole(0x00); // DEFAULT_ADMIN_ROLE

        // Generate unique reset ID
        resetId =
            keccak256(abi.encode(msg.sender, block.timestamp, block.number, _lastTripTimestamp));

        // Check for existing proposal
        if (_pendingResets[resetId].exists) {
            revert ResetAlreadyProposed(resetId);
        }

        uint48 executeAfter = uint48(block.timestamp) + CB_RESET_TIMELOCK;
        uint48 expiresAt = uint48(block.timestamp) + CB_PROPOSAL_EXPIRY;

        _pendingResets[resetId] = PendingCircuitBreakerReset({
            proposer: msg.sender,
            executeAfter: executeAfter,
            expiresAt: expiresAt,
            vetoed: false,
            executed: false,
            exists: true
        });

        emit CircuitBreakerResetProposed(resetId, msg.sender, executeAfter, expiresAt);
    }

    /// @notice Cancel a pending reset proposal
    function cancelCircuitBreakerReset(
        bytes32 resetId
    ) external {
        _checkRole(0x00); // DEFAULT_ADMIN_ROLE

        PendingCircuitBreakerReset storage proposal = _pendingResets[resetId];

        if (!proposal.exists) revert ResetNotProposed(resetId);
        if (proposal.executed) revert ResetAlreadyExecuted(resetId);

        // Mark as no longer valid (don't delete for gas efficiency on subsequent checks)
        proposal.exists = false;

        emit CircuitBreakerResetCancelled(resetId, msg.sender);
    }

    /// @notice Execute a reset after timelock has elapsed
    function executeCircuitBreakerReset(
        bytes32 resetId
    ) external {
        _checkRole(0x00); // DEFAULT_ADMIN_ROLE

        PendingCircuitBreakerReset storage proposal = _pendingResets[resetId];

        // Validate proposal state
        if (!proposal.exists) revert ResetNotProposed(resetId);
        if (proposal.executed) revert ResetAlreadyExecuted(resetId);
        if (proposal.vetoed) revert ResetVetoed(resetId);
        if (block.timestamp < proposal.executeAfter) {
            revert ResetTimelockActive(resetId, proposal.executeAfter);
        }
        if (block.timestamp > proposal.expiresAt) {
            revert ResetProposalExpired(resetId);
        }

        // Check if breaker was re-tripped after proposal
        // (invalidates proposal as situation has changed)
        if (_lastTripTimestamp > proposal.executeAfter - CB_RESET_TIMELOCK) {
            revert CircuitBreakerRetripped(resetId);
        }

        // Execute the reset
        proposal.executed = true;
        _circuitBreakerTripped = false;
        _hourlyPayouts = 0;
        _dailyPayouts = 0;
        _lastHourTimestamp = block.timestamp;
        _lastDayTimestamp = block.timestamp;

        emit CircuitBreakerResetExecuted(resetId, msg.sender);
    }

    /// @notice Reset payout counters without disabling the breaker
    function resetPayoutCounters() external onlyWhenTripped {
        _checkRole(0x00); // DEFAULT_ADMIN_ROLE

        uint256 hourlyBefore = _hourlyPayouts;
        uint256 dailyBefore = _dailyPayouts;

        _hourlyPayouts = 0;
        _dailyPayouts = 0;
        _lastHourTimestamp = block.timestamp;
        _lastDayTimestamp = block.timestamp;

        // Note: Circuit breaker remains tripped!

        emit PayoutCountersReset(msg.sender, hourlyBefore, dailyBefore);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GUARDIAN FUNCTIONS
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Veto a pending reset proposal
    function vetoCircuitBreakerReset(
        bytes32 resetId,
        string calldata reason
    ) external {
        _checkRole(GUARDIAN_ROLE);

        PendingCircuitBreakerReset storage proposal = _pendingResets[resetId];

        // Can only veto existing, non-finalized proposals
        if (!proposal.exists) revert CannotVeto(resetId);
        if (proposal.executed) revert CannotVeto(resetId);
        if (proposal.vetoed) revert CannotVeto(resetId);

        // Veto within the timelock period (before it can be executed)
        // Note: Can still veto after executeAfter but before expiry for defense-in-depth
        if (block.timestamp > proposal.expiresAt) revert CannotVeto(resetId);

        proposal.vetoed = true;

        emit CircuitBreakerResetVetoed(resetId, msg.sender, reason);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Get details of a pending reset proposal
    function getResetProposal(
        bytes32 resetId
    )
        external
        view
        returns (
            address proposer,
            uint256 executeAfter,
            uint256 expiresAt,
            bool vetoed,
            bool executed,
            bool exists
        )
    {
        PendingCircuitBreakerReset storage proposal = _pendingResets[resetId];
        return (
            proposal.proposer,
            proposal.executeAfter,
            proposal.expiresAt,
            proposal.vetoed,
            proposal.executed,
            proposal.exists
        );
    }

    /// @notice Check if a reset can be executed now
    function canExecuteReset(
        bytes32 resetId
    ) external view returns (bool canExecute, string memory reason) {
        PendingCircuitBreakerReset storage proposal = _pendingResets[resetId];

        if (!proposal.exists) {
            return (false, "Proposal does not exist");
        }
        if (proposal.executed) {
            return (false, "Already executed");
        }
        if (proposal.vetoed) {
            return (false, "Vetoed by guardian");
        }
        if (block.timestamp < proposal.executeAfter) {
            return (false, "Timelock not elapsed");
        }
        if (block.timestamp > proposal.expiresAt) {
            return (false, "Proposal expired");
        }
        if (_lastTripTimestamp > proposal.executeAfter - CB_RESET_TIMELOCK) {
            return (false, "Circuit breaker re-tripped");
        }

        return (true, "Ready to execute");
    }

    /// @notice Get time remaining until reset can be executed
    function getResetTimeRemaining(
        bytes32 resetId
    ) external view returns (uint256 timeRemaining) {
        PendingCircuitBreakerReset storage proposal = _pendingResets[resetId];

        if (!proposal.exists || proposal.executed || proposal.vetoed) {
            return 0;
        }

        if (block.timestamp >= proposal.executeAfter) {
            return 0;
        }

        return proposal.executeAfter - block.timestamp;
    }

    /// @notice Get the timestamp of the last circuit breaker trip
    function getLastTripTimestamp() external view returns (uint256 timestamp) {
        return _lastTripTimestamp;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // INTERNAL: Update to existing _tripCircuitBreaker
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Trip the circuit breaker (updated version)
    /// @dev Call this from the existing _tripCircuitBreaker function
    function _tripCircuitBreakerWithTimestamp(
        string memory reason,
        uint256 value
    ) internal {
        _circuitBreakerTripped = true;
        _lastTripTimestamp = block.timestamp;

        emit CircuitBreakerTrippedWithTimestamp(reason, value, block.timestamp);
    }
}
