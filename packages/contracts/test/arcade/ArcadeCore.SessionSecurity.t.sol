// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { DataToken } from "../../src/token/DataToken.sol";
import { ArcadeCore } from "../../src/arcade/ArcadeCore.sol";
import { IArcadeCore } from "../../src/arcade/interfaces/IArcadeCore.sol";

/// @title ArcadeCore Session Security Tests
/// @notice Tests covering Critical Security Issue #1: Session-Payout Binding
/// @dev These tests verify:
///      1. Game can only credit own sessions (cross-game isolation)
///      2. Payout cannot exceed prize pool (bounded payouts)
///      3. Session cannot be double-settled (terminal states)
///      4. Cancelled session cannot receive payouts (state machine)
///      5. Refunds bounded by deposits (drain prevention)
///      6. Double-refund prevention
contract ArcadeCoreSessionSecurityTest is Test {
    DataToken public token;
    ArcadeCore public arcadeCore;

    address public treasury = makeAddr("treasury");
    address public owner = makeAddr("owner");
    address public gameA = makeAddr("gameA");
    address public gameB = makeAddr("gameB");
    address public attacker = makeAddr("attacker");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant ALICE_BALANCE = 50_000_000 * 1e18;
    uint256 constant BOB_BALANCE = 50_000_000 * 1e18;
    // Note: Total = 100M which equals DataToken's TOTAL_SUPPLY
    uint256 constant SESSION_1 = 1;
    uint256 constant SESSION_2 = 2;
    uint256 constant SESSION_999 = 999;

    function setUp() public {
        // Deploy token with initial distribution (must sum to 100M)
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = ALICE_BALANCE;
        amounts[1] = BOB_BALANCE;

        token = new DataToken(treasury, owner, recipients, amounts);

        // Deploy ArcadeCore
        ArcadeCore implementation = new ArcadeCore();
        bytes memory initData =
            abi.encodeCall(ArcadeCore.initialize, (address(token), address(0), treasury, owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        arcadeCore = ArcadeCore(address(proxy));

        // Exclude ArcadeCore from tax for cleaner math
        vm.prank(owner);
        token.setTaxExclusion(address(arcadeCore), true);

        // Register two games with standard config
        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 1 * 1e18,
            maxEntry: 10_000 * 1e18,
            rakeBps: 500, // 5% rake
            burnBps: 2000, // 20% of rake burned
            requiresPosition: false,
            paused: false
        });

        vm.startPrank(owner);
        arcadeCore.registerGame(gameA, config);
        arcadeCore.registerGame(gameB, config);
        vm.stopPrank();

        // Approve token spending
        vm.prank(alice);
        token.approve(address(arcadeCore), type(uint256).max);
        vm.prank(bob);
        token.approve(address(arcadeCore), type(uint256).max);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // TEST 1: GAME CAN ONLY CREDIT OWN SESSIONS (Cross-Game Isolation)
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_SessionSecurity_GameCanOnlyCreditOwnSessions() public {
        // GameA creates session
        vm.prank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        // Verify session is owned by gameA
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.game, gameA, "Session should be owned by gameA");

        // GameB tries to credit payout on GameA's session - should FAIL
        vm.prank(gameB);
        vm.expectRevert(IArcadeCore.SessionGameMismatch.selector);
        arcadeCore.creditPayout(SESSION_1, alice, 10 * 1e18, 0, true);
    }

    function test_SessionSecurity_GameCannotSettleOtherGamesSession() public {
        // GameA creates session
        vm.prank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        // GameB tries to settle GameA's session - should FAIL
        vm.prank(gameB);
        vm.expectRevert(IArcadeCore.SessionGameMismatch.selector);
        arcadeCore.settleSession(SESSION_1);
    }

    function test_SessionSecurity_GameCannotCancelOtherGamesSession() public {
        // GameA creates session
        vm.prank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        // GameB tries to cancel GameA's session - should FAIL
        vm.prank(gameB);
        vm.expectRevert(IArcadeCore.SessionGameMismatch.selector);
        arcadeCore.cancelSession(SESSION_1);
    }

    function test_SessionSecurity_GameCannotRefundFromOtherGamesSession() public {
        // GameA creates session and cancels it (refunds require cancelled state)
        vm.startPrank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        arcadeCore.cancelSession(SESSION_1);
        vm.stopPrank();

        // GameB tries to refund from GameA's session - should FAIL
        vm.prank(gameB);
        vm.expectRevert(IArcadeCore.SessionGameMismatch.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, 10 * 1e18);
    }

    function test_SessionSecurity_UnregisteredGameCannotCreditPayout() public {
        // GameA creates session
        vm.prank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        // Unregistered attacker tries to credit payout - should FAIL
        vm.prank(attacker);
        vm.expectRevert(IArcadeCore.GameNotRegistered.selector);
        arcadeCore.creditPayout(SESSION_1, attacker, 1_000_000 * 1e18, 0, true);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // TEST 2: PAYOUT CANNOT EXCEED PRIZE POOL (Bounded Payouts)
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_SessionSecurity_PayoutCannotExceedPrizePool() public {
        // Create session with 100 DATA entry
        vm.prank(gameA);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        // Net amount should be ~95 DATA (5% rake)
        assertApproxEqRel(netAmount, 95 * 1e18, 0.01e18);

        // Try to payout more than prize pool - should FAIL
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.PayoutExceedsPrizePool.selector);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount + 1, 0, true);
    }

    function test_SessionSecurity_MultiplePayoutsCannotExceedPrizePool() public {
        // Create session with 100 DATA entry
        vm.prank(gameA);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        // Credit 50% of prize pool
        vm.prank(gameA);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount / 2, 0, true);

        // Try to credit remaining 51% - should FAIL
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.PayoutExceedsPrizePool.selector);
        arcadeCore.creditPayout(SESSION_1, bob, (netAmount / 2) + 2, 0, true);
    }

    function test_SessionSecurity_PayoutPlusBurnCannotExceedPrizePool() public {
        // Create session with 100 DATA entry
        vm.prank(gameA);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        // Try to payout + burn more than prize pool
        uint256 payout = netAmount / 2;
        uint256 burn = (netAmount / 2) + 1;

        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.PayoutExceedsPrizePool.selector);
        arcadeCore.creditPayout(SESSION_1, alice, payout, burn, true);
    }

    function test_SessionSecurity_RemainingCapacityTracksCorrectly() public {
        // Create session
        vm.prank(gameA);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        // Check initial capacity
        uint256 initialCapacity = arcadeCore.getSessionRemainingCapacity(SESSION_1);
        assertEq(initialCapacity, netAmount);

        // Credit partial payout
        uint256 payout1 = 30 * 1e18;
        uint256 burn1 = 5 * 1e18;
        vm.prank(gameA);
        arcadeCore.creditPayout(SESSION_1, alice, payout1, burn1, true);

        // Check remaining capacity
        uint256 remainingCapacity = arcadeCore.getSessionRemainingCapacity(SESSION_1);
        assertEq(remainingCapacity, netAmount - payout1 - burn1);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // TEST 3: SESSION CANNOT BE DOUBLE-SETTLED (Terminal States)
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_SessionSecurity_CannotSettleAlreadySettledSession() public {
        // Create and settle session
        vm.startPrank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        arcadeCore.settleSession(SESSION_1);
        vm.stopPrank();

        // Try to settle again - should FAIL
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotActive.selector);
        arcadeCore.settleSession(SESSION_1);
    }

    function test_SessionSecurity_CannotCancelAlreadySettledSession() public {
        // Create and settle session
        vm.startPrank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        arcadeCore.settleSession(SESSION_1);
        vm.stopPrank();

        // Try to cancel - should FAIL
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotActive.selector);
        arcadeCore.cancelSession(SESSION_1);
    }

    function test_SessionSecurity_CannotCancelAlreadyCancelledSession() public {
        // Create and cancel session
        vm.startPrank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        arcadeCore.cancelSession(SESSION_1);
        vm.stopPrank();

        // Try to cancel again - should FAIL
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotActive.selector);
        arcadeCore.cancelSession(SESSION_1);
    }

    function test_SessionSecurity_CannotSettleCancelledSession() public {
        // Create and cancel session
        vm.startPrank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        arcadeCore.cancelSession(SESSION_1);
        vm.stopPrank();

        // Try to settle - should FAIL
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotActive.selector);
        arcadeCore.settleSession(SESSION_1);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // TEST 4: CANCELLED/SETTLED SESSION CANNOT RECEIVE PAYOUTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_SessionSecurity_CannotCreditPayoutToSettledSession() public {
        // Create, partially payout, and settle session
        vm.startPrank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        arcadeCore.creditPayout(SESSION_1, alice, 10 * 1e18, 0, true);
        arcadeCore.settleSession(SESSION_1);
        vm.stopPrank();

        // Try to credit more - should FAIL
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotActive.selector);
        arcadeCore.creditPayout(SESSION_1, alice, 10 * 1e18, 0, true);
    }

    function test_SessionSecurity_CannotCreditPayoutToCancelledSession() public {
        // Create and cancel session
        vm.startPrank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        arcadeCore.cancelSession(SESSION_1);
        vm.stopPrank();

        // Try to credit payout - should FAIL
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotActive.selector);
        arcadeCore.creditPayout(SESSION_1, alice, 10 * 1e18, 0, true);
    }

    function test_SessionSecurity_CannotProcessEntryToSettledSession() public {
        // Create and settle session
        vm.startPrank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        arcadeCore.settleSession(SESSION_1);
        vm.stopPrank();

        // Try to add more entries - should FAIL
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotActive.selector);
        arcadeCore.processEntry(bob, 100 * 1e18, SESSION_1);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // TEST 5: REFUNDS BOUNDED BY DEPOSITS (Drain Prevention)
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_SessionSecurity_RefundCannotExceedGrossDeposit() public {
        // Create session and cancel it (required for refunds)
        vm.startPrank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        arcadeCore.cancelSession(SESSION_1);
        vm.stopPrank();

        // Check gross deposit (should be 100 DATA, not net amount)
        uint256 grossDeposit = arcadeCore.getSessionGrossDeposit(SESSION_1, alice);
        assertEq(grossDeposit, 100 * 1e18, "Gross deposit should be full entry amount");

        // Try to refund more than gross deposit - should FAIL
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.RefundExceedsDeposit.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, grossDeposit + 1);
    }

    function test_SessionSecurity_CannotRefundNonExistentDeposit() public {
        // Create session (only alice deposits) and cancel
        vm.startPrank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        arcadeCore.cancelSession(SESSION_1);
        vm.stopPrank();

        // Try to refund bob who never deposited - should FAIL
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.NoDepositFound.selector);
        arcadeCore.emergencyRefund(SESSION_1, bob, 50 * 1e18);
    }

    function test_SessionSecurity_RefundBlockedFromSettledSession() public {
        // Create session and settle it (not cancel)
        vm.startPrank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        arcadeCore.settleSession(SESSION_1);
        vm.stopPrank();

        // Try to refund from settled session - should FAIL
        // (ACTIVE sessions allow partial refunds, but SETTLED does not)
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotRefundable.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, 50 * 1e18);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // TEST 6: DOUBLE-REFUND PREVENTION
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_SessionSecurity_CannotDoubleRefund() public {
        // Create session and cancel
        vm.startPrank(gameA);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        arcadeCore.cancelSession(SESSION_1);

        // First refund succeeds (must use NET amount, not gross - rake already distributed)
        arcadeCore.emergencyRefund(SESSION_1, alice, netAmount);
        vm.stopPrank();

        // Verify refunded flag is set
        assertTrue(arcadeCore.isRefunded(SESSION_1, alice));

        // Second refund should FAIL (even attempting 1 wei)
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.AlreadyRefunded.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, 1);
    }

    function test_SessionSecurity_CannotClaimExpiredRefundTwice() public {
        // Create session and cancel (simulating expired seed)
        vm.startPrank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        arcadeCore.cancelSession(SESSION_1);
        vm.stopPrank();

        // Anyone can call claimExpiredRefund for the player
        vm.prank(bob);
        arcadeCore.claimExpiredRefund(SESSION_1, alice);

        // Second claim should FAIL
        vm.prank(bob);
        vm.expectRevert(IArcadeCore.AlreadyRefunded.selector);
        arcadeCore.claimExpiredRefund(SESSION_1, alice);
    }

    function test_SessionSecurity_BatchRefundMarksAllAsRefunded() public {
        // Create session with multiple players and cancel
        vm.startPrank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
        vm.stopPrank();

        vm.prank(gameA);
        arcadeCore.processEntry(bob, 50 * 1e18, SESSION_1);

        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Batch refund
        address[] memory players = new address[](2);
        players[0] = alice;
        players[1] = bob;

        vm.prank(gameA);
        arcadeCore.batchEmergencyRefund(SESSION_1, players);

        // Verify both are marked as refunded
        assertTrue(arcadeCore.isRefunded(SESSION_1, alice));
        assertTrue(arcadeCore.isRefunded(SESSION_1, bob));

        // Individual refund attempts should fail
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.AlreadyRefunded.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, 1);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // INVARIANT TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_Invariant_TotalPaidNeverExceedsPrizePool() public {
        // Complex scenario: multiple entries and payouts
        vm.prank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        vm.prank(gameA);
        arcadeCore.processEntry(bob, 50 * 1e18, SESSION_1);

        // Multiple payouts
        vm.prank(gameA);
        arcadeCore.creditPayout(SESSION_1, alice, 20 * 1e18, 5 * 1e18, true);

        vm.prank(gameA);
        arcadeCore.creditPayout(SESSION_1, bob, 30 * 1e18, 10 * 1e18, true);

        // Verify invariant
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertLe(session.totalPaid, session.prizePool, "INVARIANT VIOLATED: totalPaid > prizePool");
    }

    function testFuzz_Invariant_PayoutsAlwaysBounded(
        uint256 entryAmount,
        uint256 payoutAmount
    ) public {
        // Bound inputs to reasonable values
        entryAmount = bound(entryAmount, 1 * 1e18, 1000 * 1e18);
        payoutAmount = bound(payoutAmount, 0, 10_000 * 1e18);

        // Create session
        vm.prank(gameA);
        uint256 netAmount = arcadeCore.processEntry(alice, entryAmount, SESSION_1);

        // Attempt payout - should only succeed if within bounds
        if (payoutAmount <= netAmount) {
            vm.prank(gameA);
            arcadeCore.creditPayout(SESSION_1, alice, payoutAmount, 0, true);

            IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
            assertLe(session.totalPaid, session.prizePool);
        } else {
            vm.prank(gameA);
            vm.expectRevert(IArcadeCore.PayoutExceedsPrizePool.selector);
            arcadeCore.creditPayout(SESSION_1, alice, payoutAmount, 0, true);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // EDGE CASE TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_EdgeCase_ZeroPayoutAllowed() public {
        vm.prank(gameA);
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        // Zero payout (e.g., player loses with no consolation)
        vm.prank(gameA);
        arcadeCore.creditPayout(SESSION_1, alice, 0, 0, false);

        // Should not affect pending payouts
        assertEq(arcadeCore.getPendingPayout(alice), 0);
    }

    function test_EdgeCase_ExactPrizePoolPayout() public {
        vm.prank(gameA);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        // Payout exactly the prize pool
        vm.prank(gameA);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount, 0, true);

        // Verify
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.totalPaid, session.prizePool);
        assertEq(arcadeCore.getSessionRemainingCapacity(SESSION_1), 0);
    }

    function test_EdgeCase_SettleWithFullPayout() public {
        vm.prank(gameA);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);

        // Pay out everything
        vm.prank(gameA);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount, 0, true);

        uint256 treasuryBefore = token.balanceOf(treasury);

        // Settle - remaining should be 0
        vm.prank(gameA);
        arcadeCore.settleSession(SESSION_1);

        // Treasury should not receive anything extra (already got rake)
        uint256 treasuryAfter = token.balanceOf(treasury);
        // The only change should be from the initial rake, not settlement
        assertEq(treasuryAfter, treasuryBefore);
    }

    function test_EdgeCase_NonExistentSession() public {
        // Try operations on non-existent session
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotFound.selector);
        arcadeCore.creditPayout(SESSION_999, alice, 10 * 1e18, 0, true);

        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotFound.selector);
        arcadeCore.settleSession(SESSION_999);

        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotFound.selector);
        arcadeCore.cancelSession(SESSION_999);
    }
}
