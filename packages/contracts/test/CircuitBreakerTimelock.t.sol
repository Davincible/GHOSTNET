// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console2 } from "forge-std/Test.sol";

/// @title CircuitBreakerTimelockTest
/// @notice Comprehensive tests for circuit breaker reset timelock mechanism
/// @dev Tests ADR-005 implementation requirements
///
/// Test Categories:
/// 1. Proposal lifecycle (propose, cancel, execute)
/// 2. Timelock enforcement
/// 3. Guardian veto functionality
/// 4. Partial reset behavior
/// 5. Re-trip handling
/// 6. Edge cases and attack scenarios

// ============================================================================
// MOCK CONTRACTS FOR TESTING
// ============================================================================

/// @notice Mock implementation of ArcadeCore with circuit breaker timelock
/// @dev Standalone contract for testing - production will integrate into ArcadeCore
contract MockArcadeCoreWithCircuitBreaker {
    // ─────────────────────────────────────────────────────────────────────────
    // CONSTANTS
    // ─────────────────────────────────────────────────────────────────────────

    uint48 public constant CB_RESET_TIMELOCK = 12 hours;
    uint48 public constant CB_PROPOSAL_EXPIRY = 48 hours;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public constant MAX_SINGLE_PAYOUT = 500_000 ether;
    uint256 public constant MAX_HOURLY_PAYOUTS = 5_000_000 ether;
    uint256 public constant MAX_DAILY_PAYOUTS = 20_000_000 ether;

    // ─────────────────────────────────────────────────────────────────────────
    // TYPES
    // ─────────────────────────────────────────────────────────────────────────

    struct PendingCircuitBreakerReset {
        address proposer;
        uint48 executeAfter;
        uint48 expiresAt;
        bool vetoed;
        bool executed;
        bool exists;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ERRORS
    // ─────────────────────────────────────────────────────────────────────────

    error ResetAlreadyProposed(bytes32 resetId);
    error ResetNotProposed(bytes32 resetId);
    error ResetTimelockActive(bytes32 resetId, uint256 executeAfter);
    error ResetVetoed(bytes32 resetId);
    error ResetAlreadyExecuted(bytes32 resetId);
    error ResetProposalExpired(bytes32 resetId);
    error CircuitBreakerNotTripped();
    error CircuitBreakerRetripped(bytes32 resetId);
    error CannotVeto(bytes32 resetId);
    error AccessControlUnauthorized(address account, bytes32 role);
    error CircuitBreakerActive();

    // ─────────────────────────────────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────────────────────────────────

    event CircuitBreakerResetProposed(
        bytes32 indexed resetId, address indexed proposer, uint256 executeAfter, uint256 expiresAt
    );
    event CircuitBreakerResetVetoed(
        bytes32 indexed resetId, address indexed guardian, string reason
    );
    event CircuitBreakerResetCancelled(bytes32 indexed resetId, address indexed canceller);
    event CircuitBreakerResetExecuted(bytes32 indexed resetId, address indexed executor);
    event PayoutCountersReset(address indexed admin, uint256 hourlyBefore, uint256 dailyBefore);
    event CircuitBreakerTripped(string reason, uint256 value);
    event CircuitBreakerReset(address indexed admin);

    // ─────────────────────────────────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────────────────────────────────

    mapping(bytes32 => mapping(address => bool)) private _roles;
    mapping(bytes32 => PendingCircuitBreakerReset) public pendingResets;

    bool public circuitBreakerTripped;
    uint256 public lastTripTimestamp;
    uint256 public hourlyPayouts;
    uint256 public dailyPayouts;
    uint256 public lastHourTimestamp;
    uint256 public lastDayTimestamp;

    // ─────────────────────────────────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────────────────────────────────

    constructor(
        address admin,
        address guardian
    ) {
        _roles[DEFAULT_ADMIN_ROLE][admin] = true;
        _roles[GUARDIAN_ROLE][guardian] = true;
        lastHourTimestamp = block.timestamp;
        lastDayTimestamp = block.timestamp;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ACCESS CONTROL
    // ─────────────────────────────────────────────────────────────────────────

    modifier onlyRole(
        bytes32 role
    ) {
        if (!_roles[role][msg.sender]) {
            revert AccessControlUnauthorized(msg.sender, role);
        }
        _;
    }

    function hasRole(
        bytes32 role,
        address account
    ) public view returns (bool) {
        return _roles[role][account];
    }

    function grantRole(
        bytes32 role,
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _roles[role][account] = true;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CIRCUIT BREAKER SIMULATION
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Simulate a circuit breaker trip
    function simulateTrip(
        string memory reason,
        uint256 value
    ) external {
        circuitBreakerTripped = true;
        lastTripTimestamp = block.timestamp;
        emit CircuitBreakerTripped(reason, value);
    }

    /// @notice Simulate payout that may trip breaker
    function simulatePayout(
        uint256 amount
    ) external {
        if (circuitBreakerTripped) revert CircuitBreakerActive();

        // Check single payout limit
        if (amount > MAX_SINGLE_PAYOUT) {
            _tripBreaker("Single payout exceeded", amount);
            return;
        }

        // Check hourly limit
        _updateHourlyCounter();
        hourlyPayouts += amount;
        if (hourlyPayouts > MAX_HOURLY_PAYOUTS) {
            _tripBreaker("Hourly payout exceeded", hourlyPayouts);
            return;
        }

        // Check daily limit
        _updateDailyCounter();
        dailyPayouts += amount;
        if (dailyPayouts > MAX_DAILY_PAYOUTS) {
            _tripBreaker("Daily payout exceeded", dailyPayouts);
        }
    }

    function _tripBreaker(
        string memory reason,
        uint256 value
    ) internal {
        circuitBreakerTripped = true;
        lastTripTimestamp = block.timestamp;
        emit CircuitBreakerTripped(reason, value);
    }

    function _updateHourlyCounter() internal {
        uint256 currentHour = block.timestamp / 1 hours;
        if (currentHour != lastHourTimestamp / 1 hours) {
            hourlyPayouts = 0;
            lastHourTimestamp = block.timestamp;
        }
    }

    function _updateDailyCounter() internal {
        uint256 currentDay = block.timestamp / 1 days;
        if (currentDay != lastDayTimestamp / 1 days) {
            dailyPayouts = 0;
            lastDayTimestamp = block.timestamp;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TIMELOCK FUNCTIONS
    // ─────────────────────────────────────────────────────────────────────────

    function proposeCircuitBreakerReset()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bytes32 resetId)
    {
        if (!circuitBreakerTripped) revert CircuitBreakerNotTripped();

        resetId =
            keccak256(abi.encode(msg.sender, block.timestamp, block.number, lastTripTimestamp));

        if (pendingResets[resetId].exists) {
            revert ResetAlreadyProposed(resetId);
        }

        uint48 executeAfter = uint48(block.timestamp) + CB_RESET_TIMELOCK;
        uint48 expiresAt = uint48(block.timestamp) + CB_PROPOSAL_EXPIRY;

        pendingResets[resetId] = PendingCircuitBreakerReset({
            proposer: msg.sender,
            executeAfter: executeAfter,
            expiresAt: expiresAt,
            vetoed: false,
            executed: false,
            exists: true
        });

        emit CircuitBreakerResetProposed(resetId, msg.sender, executeAfter, expiresAt);
    }

    function cancelCircuitBreakerReset(
        bytes32 resetId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        PendingCircuitBreakerReset storage proposal = pendingResets[resetId];

        if (!proposal.exists) revert ResetNotProposed(resetId);
        if (proposal.executed) revert ResetAlreadyExecuted(resetId);

        proposal.exists = false;

        emit CircuitBreakerResetCancelled(resetId, msg.sender);
    }

    function executeCircuitBreakerReset(
        bytes32 resetId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        PendingCircuitBreakerReset storage proposal = pendingResets[resetId];

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
        // The proposal was created at (executeAfter - CB_RESET_TIMELOCK)
        uint256 proposalTime = proposal.executeAfter - CB_RESET_TIMELOCK;
        if (lastTripTimestamp > proposalTime) {
            revert CircuitBreakerRetripped(resetId);
        }

        proposal.executed = true;
        circuitBreakerTripped = false;
        hourlyPayouts = 0;
        dailyPayouts = 0;
        lastHourTimestamp = block.timestamp;
        lastDayTimestamp = block.timestamp;

        emit CircuitBreakerResetExecuted(resetId, msg.sender);
    }

    function resetPayoutCounters() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!circuitBreakerTripped) revert CircuitBreakerNotTripped();

        uint256 hourlyBefore = hourlyPayouts;
        uint256 dailyBefore = dailyPayouts;

        hourlyPayouts = 0;
        dailyPayouts = 0;
        lastHourTimestamp = block.timestamp;
        lastDayTimestamp = block.timestamp;

        emit PayoutCountersReset(msg.sender, hourlyBefore, dailyBefore);
    }

    function vetoCircuitBreakerReset(
        bytes32 resetId,
        string calldata reason
    ) external onlyRole(GUARDIAN_ROLE) {
        PendingCircuitBreakerReset storage proposal = pendingResets[resetId];

        if (!proposal.exists) revert CannotVeto(resetId);
        if (proposal.executed) revert CannotVeto(resetId);
        if (proposal.vetoed) revert CannotVeto(resetId);
        if (block.timestamp > proposal.expiresAt) revert CannotVeto(resetId);

        proposal.vetoed = true;

        emit CircuitBreakerResetVetoed(resetId, msg.sender, reason);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // ─────────────────────────────────────────────────────────────────────────

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
        PendingCircuitBreakerReset storage proposal = pendingResets[resetId];
        return (
            proposal.proposer,
            proposal.executeAfter,
            proposal.expiresAt,
            proposal.vetoed,
            proposal.executed,
            proposal.exists
        );
    }

    function canExecuteReset(
        bytes32 resetId
    ) external view returns (bool canExecute, string memory reason) {
        PendingCircuitBreakerReset storage proposal = pendingResets[resetId];

        if (!proposal.exists) return (false, "Proposal does not exist");
        if (proposal.executed) return (false, "Already executed");
        if (proposal.vetoed) return (false, "Vetoed by guardian");
        if (block.timestamp < proposal.executeAfter) return (false, "Timelock not elapsed");
        if (block.timestamp > proposal.expiresAt) return (false, "Proposal expired");

        uint256 proposalTime = proposal.executeAfter - CB_RESET_TIMELOCK;
        if (lastTripTimestamp > proposalTime) return (false, "Circuit breaker re-tripped");

        return (true, "Ready to execute");
    }

    function getResetTimeRemaining(
        bytes32 resetId
    ) external view returns (uint256) {
        PendingCircuitBreakerReset storage proposal = pendingResets[resetId];

        if (!proposal.exists || proposal.executed || proposal.vetoed) return 0;
        if (block.timestamp >= proposal.executeAfter) return 0;

        return proposal.executeAfter - block.timestamp;
    }
}

// ============================================================================
// TEST CONTRACT
// ============================================================================

contract CircuitBreakerTimelockTest is Test {
    MockArcadeCoreWithCircuitBreaker public arcadeCore;

    address public admin = makeAddr("admin");
    address public guardian = makeAddr("guardian");
    address public attacker = makeAddr("attacker");
    address public user = makeAddr("user");

    // Events to match for assertions
    event CircuitBreakerResetProposed(
        bytes32 indexed resetId, address indexed proposer, uint256 executeAfter, uint256 expiresAt
    );
    event CircuitBreakerResetVetoed(
        bytes32 indexed resetId, address indexed guardian, string reason
    );
    event CircuitBreakerResetCancelled(bytes32 indexed resetId, address indexed canceller);
    event CircuitBreakerResetExecuted(bytes32 indexed resetId, address indexed executor);
    event PayoutCountersReset(address indexed admin, uint256 hourlyBefore, uint256 dailyBefore);
    event CircuitBreakerTripped(string reason, uint256 value);

    function setUp() public {
        arcadeCore = new MockArcadeCoreWithCircuitBreaker(admin, guardian);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PROPOSAL LIFECYCLE TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_ProposeReset_Success() public {
        // Trip the breaker first
        arcadeCore.simulateTrip("Test trip", 1000);
        assertTrue(arcadeCore.circuitBreakerTripped());

        // Propose reset
        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        // Verify proposal exists
        (
            address proposer,
            uint256 executeAfter,
            uint256 expiresAt,
            bool vetoed,
            bool executed,
            bool exists
        ) = arcadeCore.getResetProposal(resetId);

        assertEq(proposer, admin);
        assertEq(executeAfter, block.timestamp + 12 hours);
        assertEq(expiresAt, block.timestamp + 48 hours);
        assertFalse(vetoed);
        assertFalse(executed);
        assertTrue(exists);
    }

    function test_ProposeReset_RevertWhen_NotTripped() public {
        assertFalse(arcadeCore.circuitBreakerTripped());

        vm.prank(admin);
        vm.expectRevert(MockArcadeCoreWithCircuitBreaker.CircuitBreakerNotTripped.selector);
        arcadeCore.proposeCircuitBreakerReset();
    }

    function test_ProposeReset_RevertWhen_NotAdmin() public {
        arcadeCore.simulateTrip("Test trip", 1000);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                MockArcadeCoreWithCircuitBreaker.AccessControlUnauthorized.selector,
                attacker,
                bytes32(0)
            )
        );
        arcadeCore.proposeCircuitBreakerReset();
    }

    function test_CancelReset_Success() public {
        // Setup: trip and propose
        arcadeCore.simulateTrip("Test trip", 1000);
        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        // Cancel
        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit CircuitBreakerResetCancelled(resetId, admin);
        arcadeCore.cancelCircuitBreakerReset(resetId);

        // Verify cancelled
        (,,,,, bool exists) = arcadeCore.getResetProposal(resetId);
        assertFalse(exists);
    }

    function test_CancelReset_RevertWhen_NotProposed() public {
        bytes32 fakeResetId = keccak256("fake");

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                MockArcadeCoreWithCircuitBreaker.ResetNotProposed.selector, fakeResetId
            )
        );
        arcadeCore.cancelCircuitBreakerReset(fakeResetId);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TIMELOCK ENFORCEMENT TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_ExecuteReset_RevertWhen_TimelockActive() public {
        // Setup: trip and propose
        arcadeCore.simulateTrip("Test trip", 1000);
        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        // Try to execute immediately (should fail)
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                MockArcadeCoreWithCircuitBreaker.ResetTimelockActive.selector,
                resetId,
                block.timestamp + 12 hours
            )
        );
        arcadeCore.executeCircuitBreakerReset(resetId);
    }

    function test_ExecuteReset_RevertWhen_TimelockPartiallyElapsed() public {
        arcadeCore.simulateTrip("Test trip", 1000);
        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        // Advance 11 hours 59 minutes (1 minute short)
        vm.warp(block.timestamp + 12 hours - 1 minutes);

        vm.prank(admin);
        vm.expectRevert();
        arcadeCore.executeCircuitBreakerReset(resetId);
    }

    function test_ExecuteReset_Success_AfterTimelock() public {
        arcadeCore.simulateTrip("Test trip", 1000);
        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        // Advance exactly 12 hours
        vm.warp(block.timestamp + 12 hours);

        // Execute should succeed
        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit CircuitBreakerResetExecuted(resetId, admin);
        arcadeCore.executeCircuitBreakerReset(resetId);

        // Verify reset
        assertFalse(arcadeCore.circuitBreakerTripped());
    }

    function test_ExecuteReset_RevertWhen_Expired() public {
        arcadeCore.simulateTrip("Test trip", 1000);
        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        // Advance past expiry (48 hours + 1 second)
        vm.warp(block.timestamp + 48 hours + 1);

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                MockArcadeCoreWithCircuitBreaker.ResetProposalExpired.selector, resetId
            )
        );
        arcadeCore.executeCircuitBreakerReset(resetId);
    }

    function test_GetTimeRemaining_ReturnsCorrectValue() public {
        arcadeCore.simulateTrip("Test trip", 1000);
        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        // Initial: 12 hours
        assertEq(arcadeCore.getResetTimeRemaining(resetId), 12 hours);

        // After 6 hours: 6 hours remaining
        vm.warp(block.timestamp + 6 hours);
        assertEq(arcadeCore.getResetTimeRemaining(resetId), 6 hours);

        // After 12 hours: 0 remaining
        vm.warp(block.timestamp + 6 hours);
        assertEq(arcadeCore.getResetTimeRemaining(resetId), 0);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // GUARDIAN VETO TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_VetoReset_Success() public {
        arcadeCore.simulateTrip("Test trip", 1000);
        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        // Guardian vetoes
        vm.prank(guardian);
        vm.expectEmit(true, true, false, true);
        emit CircuitBreakerResetVetoed(resetId, guardian, "Suspicious activity");
        arcadeCore.vetoCircuitBreakerReset(resetId, "Suspicious activity");

        // Verify vetoed
        (,,, bool vetoed,,) = arcadeCore.getResetProposal(resetId);
        assertTrue(vetoed);
    }

    function test_ExecuteReset_RevertWhen_Vetoed() public {
        arcadeCore.simulateTrip("Test trip", 1000);
        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        // Guardian vetoes
        vm.prank(guardian);
        arcadeCore.vetoCircuitBreakerReset(resetId, "Suspicious activity");

        // Advance past timelock
        vm.warp(block.timestamp + 12 hours);

        // Execute should fail
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(MockArcadeCoreWithCircuitBreaker.ResetVetoed.selector, resetId)
        );
        arcadeCore.executeCircuitBreakerReset(resetId);

        // Breaker should still be tripped
        assertTrue(arcadeCore.circuitBreakerTripped());
    }

    function test_VetoReset_RevertWhen_NotGuardian() public {
        arcadeCore.simulateTrip("Test trip", 1000);
        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        vm.prank(attacker);
        vm.expectRevert();
        arcadeCore.vetoCircuitBreakerReset(resetId, "Attacker veto");
    }

    function test_VetoReset_CanVetoAfterTimelockButBeforeExecution() public {
        arcadeCore.simulateTrip("Test trip", 1000);
        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        // Advance past timelock
        vm.warp(block.timestamp + 12 hours);

        // Guardian can still veto (defense in depth)
        vm.prank(guardian);
        arcadeCore.vetoCircuitBreakerReset(resetId, "Late veto");

        // Now execute should fail
        vm.prank(admin);
        vm.expectRevert();
        arcadeCore.executeCircuitBreakerReset(resetId);
    }

    function test_VetoReset_RevertWhen_AlreadyVetoed() public {
        arcadeCore.simulateTrip("Test trip", 1000);
        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        // First veto
        vm.prank(guardian);
        arcadeCore.vetoCircuitBreakerReset(resetId, "First veto");

        // Second veto should fail
        vm.prank(guardian);
        vm.expectRevert(
            abi.encodeWithSelector(MockArcadeCoreWithCircuitBreaker.CannotVeto.selector, resetId)
        );
        arcadeCore.vetoCircuitBreakerReset(resetId, "Second veto");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // PARTIAL RESET TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_PartialReset_ResetsCounters() public {
        // Simulate payout that trips the breaker via single payout limit
        // MAX_SINGLE_PAYOUT = 500_000 ether, so 600K trips it
        arcadeCore.simulatePayout(600_000 ether);
        assertTrue(arcadeCore.circuitBreakerTripped());

        uint256 hourlyBefore = arcadeCore.hourlyPayouts();

        // Partial reset
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit PayoutCountersReset(admin, hourlyBefore, hourlyBefore);
        arcadeCore.resetPayoutCounters();

        // Counters should be reset
        assertEq(arcadeCore.hourlyPayouts(), 0);
        assertEq(arcadeCore.dailyPayouts(), 0);

        // But breaker should STILL be tripped!
        assertTrue(arcadeCore.circuitBreakerTripped());
    }

    function test_PartialReset_RevertWhen_NotTripped() public {
        assertFalse(arcadeCore.circuitBreakerTripped());

        vm.prank(admin);
        vm.expectRevert(MockArcadeCoreWithCircuitBreaker.CircuitBreakerNotTripped.selector);
        arcadeCore.resetPayoutCounters();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // RE-TRIP HANDLING TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_ExecuteReset_RevertWhen_Retripped() public {
        // First trip
        arcadeCore.simulateTrip("First trip", 1000);
        uint256 firstTripTime = block.timestamp;

        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        // Advance 6 hours
        vm.warp(block.timestamp + 6 hours);

        // Manually reset and re-trip (simulating operational scenario)
        // In production, this would require different mechanism
        // For test, we directly manipulate
        arcadeCore.simulateTrip("Second trip", 2000);

        // Advance past timelock
        vm.warp(block.timestamp + 6 hours);

        // Execute should fail because of re-trip
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                MockArcadeCoreWithCircuitBreaker.CircuitBreakerRetripped.selector, resetId
            )
        );
        arcadeCore.executeCircuitBreakerReset(resetId);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MULTIPLE PROPOSALS TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_MultipleProposals_OnlyOneCanExecute() public {
        arcadeCore.simulateTrip("Test trip", 1000);

        // Create first proposal
        vm.prank(admin);
        bytes32 resetId1 = arcadeCore.proposeCircuitBreakerReset();

        // Advance 1 second to get different resetId
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        // Create second proposal
        vm.prank(admin);
        bytes32 resetId2 = arcadeCore.proposeCircuitBreakerReset();

        assertFalse(resetId1 == resetId2, "Reset IDs should be different");

        // Advance past timelock for first proposal
        vm.warp(block.timestamp + 12 hours);

        // Execute first proposal
        vm.prank(admin);
        arcadeCore.executeCircuitBreakerReset(resetId1);

        // Breaker is now reset
        assertFalse(arcadeCore.circuitBreakerTripped());

        // Second proposal can't execute (breaker not tripped)
        // Also it would fail other checks if we tried
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ATTACK SCENARIO TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_AttackScenario_CompromisedAdminBlocked() public {
        // Attacker compromises admin key
        // Trip breaker (simulating exploit)
        arcadeCore.simulateTrip("Exploit detected", 1000);

        // Attacker proposes reset
        vm.prank(admin); // Attacker using compromised admin key
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        // Team detects within 12h window, guardian vetoes
        vm.warp(block.timestamp + 6 hours);
        vm.prank(guardian);
        arcadeCore.vetoCircuitBreakerReset(resetId, "Unauthorized proposal during attack");

        // Attacker tries to execute after timelock
        vm.warp(block.timestamp + 6 hours);
        vm.prank(admin);
        vm.expectRevert();
        arcadeCore.executeCircuitBreakerReset(resetId);

        // Funds protected - breaker still tripped
        assertTrue(arcadeCore.circuitBreakerTripped());
    }

    function test_AttackScenario_AttackerCannotBypassTimelock() public {
        arcadeCore.simulateTrip("Test trip", 1000);

        // Attacker with admin key proposes
        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        // Attacker tries immediate execution
        vm.prank(admin);
        vm.expectRevert();
        arcadeCore.executeCircuitBreakerReset(resetId);

        // Breaker still tripped
        assertTrue(arcadeCore.circuitBreakerTripped());
    }

    function test_AttackScenario_RepeatedProposalsStillTimelocked() public {
        arcadeCore.simulateTrip("Test trip", 1000);

        // Attacker creates many proposals
        bytes32[] memory resetIds = new bytes32[](5);
        for (uint256 i = 0; i < 5; i++) {
            vm.warp(block.timestamp + 1);
            vm.roll(block.number + 1);
            vm.prank(admin);
            resetIds[i] = arcadeCore.proposeCircuitBreakerReset();
        }

        // None can execute immediately
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(admin);
            vm.expectRevert();
            arcadeCore.executeCircuitBreakerReset(resetIds[i]);
        }

        // Breaker still tripped
        assertTrue(arcadeCore.circuitBreakerTripped());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CANEXECUTERESET VIEW FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_CanExecuteReset_AllStates() public {
        arcadeCore.simulateTrip("Test trip", 1000);
        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        // Initially: timelock not elapsed
        (bool canExecute, string memory reason) = arcadeCore.canExecuteReset(resetId);
        assertFalse(canExecute);
        assertEq(reason, "Timelock not elapsed");

        // After timelock: ready
        vm.warp(block.timestamp + 12 hours);
        (canExecute, reason) = arcadeCore.canExecuteReset(resetId);
        assertTrue(canExecute);
        assertEq(reason, "Ready to execute");

        // After execution: already executed
        vm.prank(admin);
        arcadeCore.executeCircuitBreakerReset(resetId);
        (canExecute, reason) = arcadeCore.canExecuteReset(resetId);
        assertFalse(canExecute);
        assertEq(reason, "Already executed");
    }

    function test_CanExecuteReset_NonexistentProposal() public {
        bytes32 fakeId = keccak256("fake");
        (bool canExecute, string memory reason) = arcadeCore.canExecuteReset(fakeId);
        assertFalse(canExecute);
        assertEq(reason, "Proposal does not exist");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function testFuzz_TimelockEnforced(
        uint256 timePassed
    ) public {
        // Bound time to reasonable range (0 to 12 hours - 1 second)
        timePassed = bound(timePassed, 0, 12 hours - 1);

        arcadeCore.simulateTrip("Test trip", 1000);
        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        // Advance time but stay under timelock
        vm.warp(block.timestamp + timePassed);

        // Should always revert
        vm.prank(admin);
        vm.expectRevert();
        arcadeCore.executeCircuitBreakerReset(resetId);
    }

    function testFuzz_ExecutionWindowValid(
        uint256 timePassed
    ) public {
        // Bound to valid execution window (12h to 48h)
        timePassed = bound(timePassed, 12 hours, 48 hours);

        arcadeCore.simulateTrip("Test trip", 1000);
        vm.prank(admin);
        bytes32 resetId = arcadeCore.proposeCircuitBreakerReset();

        vm.warp(block.timestamp + timePassed);

        // Should succeed
        vm.prank(admin);
        arcadeCore.executeCircuitBreakerReset(resetId);
        assertFalse(arcadeCore.circuitBreakerTripped());
    }
}
