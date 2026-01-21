// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";
import { ArcadeCore } from "../../src/arcade/ArcadeCore.sol";
import { ArcadeCoreStorage } from "../../src/arcade/ArcadeCoreStorage.sol";
import { IArcadeCore } from "../../src/arcade/interfaces/IArcadeCore.sol";
import { DataToken } from "../../src/token/DataToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title ArcadeCore Emergency Refund Tests
/// @notice Tests for Critical Issue #4: Session-bound emergency refunds
/// @dev Verifies:
///      - Games can only refund own session players
///      - Refund amounts bounded by player deposits
///      - Double-refund prevention
///      - Batch refund edge cases
///      - Self-service expired refund
contract ArcadeCoreEmergencyRefundTest is Test {
    // ══════════════════════════════════════════════════════════════════════════════
    // TEST FIXTURES
    // ══════════════════════════════════════════════════════════════════════════════

    ArcadeCore public arcadeCore;
    DataToken public dataToken;

    address public admin = makeAddr("admin");
    address public treasury = makeAddr("treasury");
    address public gameA = makeAddr("gameA");
    address public gameB = makeAddr("gameB");
    address public maliciousGame = makeAddr("maliciousGame");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 public constant SESSION_1 = 1;
    uint256 public constant SESSION_2 = 2;
    uint256 public constant SESSION_3 = 3;
    uint256 public constant ENTRY_AMOUNT = 100 ether;
    uint256 public constant RAKE_BPS = 500; // 5%

    /// @notice Calculate net amount after rake
    function _netAmount(
        uint256 gross
    ) internal pure returns (uint256) {
        return gross - (gross * RAKE_BPS / 10_000);
    }

    // Events for verification
    event EmergencyRefund(
        address indexed game, address indexed player, uint256 indexed sessionId, uint256 amount
    );

    event BatchEmergencyRefund(
        address indexed game,
        uint256 indexed sessionId,
        uint256 playersRefunded,
        uint256 totalRefunded
    );

    event ExpiredRefundClaimed(address indexed player, uint256 indexed sessionId, uint256 amount);

    event SessionCancelled(address indexed game, uint256 indexed sessionId, uint256 prizePool);

    // ══════════════════════════════════════════════════════════════════════════════
    // SETUP
    // ══════════════════════════════════════════════════════════════════════════════

    function setUp() public {
        // Deploy DataToken with initial distribution
        address[] memory recipients = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        recipients[0] = admin;
        amounts[0] = 100_000_000 ether; // 100M tokens

        vm.startPrank(admin);
        dataToken = new DataToken(treasury, admin, recipients, amounts);

        // Deploy ArcadeCore via proxy
        ArcadeCore implementation = new ArcadeCore();
        bytes memory initData = abi.encodeCall(
            ArcadeCore.initialize, (address(dataToken), address(0), treasury, admin)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        arcadeCore = ArcadeCore(address(proxy));

        // Setup game configs
        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 1 ether,
            maxEntry: 1000 ether,
            rakeBps: 500, // 5% rake
            burnBps: 2000, // 20% of rake burned
            requiresPosition: false,
            paused: false
        });

        arcadeCore.registerGame(gameA, config);
        arcadeCore.registerGame(gameB, config);
        // maliciousGame NOT registered

        // Fund test accounts
        dataToken.transfer(alice, 1000 ether);
        dataToken.transfer(bob, 1000 ether);
        dataToken.transfer(charlie, 1000 ether);

        // Set DATA exclusions for arcade
        dataToken.setTaxExclusion(address(arcadeCore), true);
        vm.stopPrank();

        // Players approve arcade
        vm.prank(alice);
        dataToken.approve(address(arcadeCore), type(uint256).max);
        vm.prank(bob);
        dataToken.approve(address(arcadeCore), type(uint256).max);
        vm.prank(charlie);
        dataToken.approve(address(arcadeCore), type(uint256).max);
    }

    // Helper to create a session with a player entry
    function _createSessionWithEntry(
        uint256 sessionId,
        address game,
        address player,
        uint256 amount
    ) internal returns (uint256 netAmount) {
        vm.prank(game);
        netAmount = arcadeCore.processEntry(player, amount, sessionId);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EMERGENCY REFUND - OWNERSHIP VALIDATION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Game can only refund players in its own session
    function test_EmergencyRefund_GameOwnsSession() public {
        // Setup: Alice deposits to gameA's session
        uint256 grossDeposit = ENTRY_AMOUNT;
        uint256 rake = (grossDeposit * 500) / 10_000; // 5% rake
        uint256 netDeposit = grossDeposit - rake;

        _createSessionWithEntry(SESSION_1, gameA, alice, grossDeposit);

        // Cancel session to enable refunds
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // GameA can refund Alice the NET amount
        uint256 aliceBalanceBefore = dataToken.balanceOf(alice);

        vm.prank(gameA);
        vm.expectEmit(true, true, true, true);
        emit EmergencyRefund(gameA, alice, SESSION_1, netDeposit);
        arcadeCore.emergencyRefund(SESSION_1, alice, netDeposit);

        // Alice can withdraw
        vm.prank(alice);
        arcadeCore.withdrawPayout();

        assertEq(
            dataToken.balanceOf(alice),
            aliceBalanceBefore + netDeposit,
            "Alice should receive NET deposit (rake already taken)"
        );
    }

    /// @notice Game cannot refund players from another game's session
    function test_EmergencyRefund_RevertWhen_WrongGameAttemptsRefund() public {
        // Setup: Alice deposits to gameA's session
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // GameB attempts to refund Alice from gameA's session
        vm.prank(gameB);
        vm.expectRevert(IArcadeCore.SessionGameMismatch.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, ENTRY_AMOUNT);
    }

    /// @notice Unregistered game cannot refund anyone
    function test_EmergencyRefund_RevertWhen_UnregisteredGame() public {
        // Setup: Alice deposits to gameA's session
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Malicious unregistered game attempts refund
        vm.prank(maliciousGame);
        vm.expectRevert(IArcadeCore.GameNotRegistered.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, ENTRY_AMOUNT);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EMERGENCY REFUND - AMOUNT VALIDATION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Refund bounded by player's NET deposit (what's in prize pool)
    function test_EmergencyRefund_BoundedByNetDeposit() public {
        uint256 grossDeposit = ENTRY_AMOUNT;
        uint256 rake = (grossDeposit * 500) / 10_000; // 5%
        uint256 netDeposit = grossDeposit - rake;

        // Setup: Alice deposits
        _createSessionWithEntry(SESSION_1, gameA, alice, grossDeposit);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Verify player can get back NET amount (rake already taken)
        vm.prank(gameA);
        arcadeCore.emergencyRefund(SESSION_1, alice, netDeposit);

        // Verify pending payout is net amount
        assertEq(
            arcadeCore.getPendingPayout(alice),
            netDeposit,
            "Refund should equal net deposit (rake already taken)"
        );
    }

    /// @notice Cannot refund more than net deposit
    function test_EmergencyRefund_RevertWhen_AmountExceedsDeposit() public {
        uint256 grossDeposit = ENTRY_AMOUNT;
        uint256 rake = (grossDeposit * 500) / 10_000; // 5%
        uint256 netDeposit = grossDeposit - rake;

        _createSessionWithEntry(SESSION_1, gameA, alice, grossDeposit);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Attempt to refund more than NET deposit (even if less than gross)
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.RefundExceedsDeposit.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, netDeposit + 1);
    }

    /// @notice Cannot refund zero amount
    function test_EmergencyRefund_RevertWhen_ZeroAmount() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.InvalidRefundAmount.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, 0);
    }

    /// @notice Cannot refund player with no deposit
    function test_EmergencyRefund_RevertWhen_NoDeposit() public {
        // Create session but Bob doesn't deposit
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Attempt to refund Bob who has no deposit
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.NoDepositFound.selector);
        arcadeCore.emergencyRefund(SESSION_1, bob, ENTRY_AMOUNT);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EMERGENCY REFUND - DOUBLE-REFUND PREVENTION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Cannot refund same player twice
    function test_EmergencyRefund_RevertWhen_DoubleRefund() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        uint256 netDeposit = _netAmount(ENTRY_AMOUNT);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // First refund succeeds
        vm.prank(gameA);
        arcadeCore.emergencyRefund(SESSION_1, alice, netDeposit);

        // Second refund fails
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.AlreadyRefunded.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, netDeposit);
    }

    /// @notice Cannot partial refund after full refund
    function test_EmergencyRefund_RevertWhen_PartialAfterFull() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        uint256 netDeposit = _netAmount(ENTRY_AMOUNT);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Full refund
        vm.prank(gameA);
        arcadeCore.emergencyRefund(SESSION_1, alice, netDeposit);

        // Partial refund attempt fails
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.AlreadyRefunded.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, 1 ether);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EMERGENCY REFUND - SESSION STATE VALIDATION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Cannot refund from settled session
    function test_EmergencyRefund_RevertWhen_SessionSettled() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Settle session
        vm.prank(gameA);
        arcadeCore.settleSession(SESSION_1);

        // Attempt refund
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotRefundable.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, ENTRY_AMOUNT);
    }

    /// @notice Can refund from cancelled session
    function test_EmergencyRefund_AllowsFromCancelledSession() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        uint256 netDeposit = _netAmount(ENTRY_AMOUNT);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Refund succeeds
        vm.prank(gameA);
        arcadeCore.emergencyRefund(SESSION_1, alice, netDeposit);

        assertEq(arcadeCore.getPendingPayout(alice), netDeposit);
    }

    /// @notice Cannot refund from non-existent session
    function test_EmergencyRefund_RevertWhen_SessionNotExists() public {
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotFound.selector);
        arcadeCore.emergencyRefund(999, alice, ENTRY_AMOUNT);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BATCH EMERGENCY REFUND
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Batch refund refunds all players their NET deposits
    function test_BatchEmergencyRefund_RefundsAllPlayers() public {
        // Setup: Multiple players deposit
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        vm.warp(block.timestamp + 2); // Rate limit
        _createSessionWithEntry(SESSION_1, gameA, bob, ENTRY_AMOUNT * 2);
        vm.warp(block.timestamp + 2);
        _createSessionWithEntry(SESSION_1, gameA, charlie, ENTRY_AMOUNT * 3);

        // Calculate expected net refunds
        uint256 aliceNet = _netAmount(ENTRY_AMOUNT);
        uint256 bobNet = _netAmount(ENTRY_AMOUNT * 2);
        uint256 charlieNet = _netAmount(ENTRY_AMOUNT * 3);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Batch refund
        address[] memory players = new address[](3);
        players[0] = alice;
        players[1] = bob;
        players[2] = charlie;

        vm.prank(gameA);
        vm.expectEmit(true, true, true, true);
        emit BatchEmergencyRefund(
            gameA,
            SESSION_1,
            3, // players refunded
            aliceNet + bobNet + charlieNet // total NET
        );
        arcadeCore.batchEmergencyRefund(SESSION_1, players);

        // Verify each player's pending payout (NET amounts)
        assertEq(arcadeCore.getPendingPayout(alice), aliceNet);
        assertEq(arcadeCore.getPendingPayout(bob), bobNet);
        assertEq(arcadeCore.getPendingPayout(charlie), charlieNet);
    }

    /// @notice Batch refund skips players with no deposit
    function test_BatchEmergencyRefund_SkipsNoDeposit() public {
        // Only Alice deposits
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        uint256 aliceNet = _netAmount(ENTRY_AMOUNT);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Batch includes Bob who has no deposit
        address[] memory players = new address[](2);
        players[0] = alice;
        players[1] = bob; // No deposit

        vm.prank(gameA);
        arcadeCore.batchEmergencyRefund(SESSION_1, players);

        // Alice refunded, Bob skipped
        assertEq(arcadeCore.getPendingPayout(alice), aliceNet);
        assertEq(arcadeCore.getPendingPayout(bob), 0);
    }

    /// @notice Batch refund skips already refunded players
    function test_BatchEmergencyRefund_SkipsAlreadyRefunded() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        vm.warp(block.timestamp + 2);
        _createSessionWithEntry(SESSION_1, gameA, bob, ENTRY_AMOUNT);

        uint256 netDeposit = _netAmount(ENTRY_AMOUNT);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Refund Alice individually first
        vm.prank(gameA);
        arcadeCore.emergencyRefund(SESSION_1, alice, netDeposit);

        // Batch includes already-refunded Alice
        address[] memory players = new address[](2);
        players[0] = alice;
        players[1] = bob;

        vm.prank(gameA);
        arcadeCore.batchEmergencyRefund(SESSION_1, players);

        // Both have correct amounts (Alice not double-refunded)
        assertEq(arcadeCore.getPendingPayout(alice), netDeposit);
        assertEq(arcadeCore.getPendingPayout(bob), netDeposit);
    }

    /// @notice Batch refund fails for wrong game
    function test_BatchEmergencyRefund_RevertWhen_WrongGame() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        address[] memory players = new address[](1);
        players[0] = alice;

        // GameB tries to batch refund gameA's session
        vm.prank(gameB);
        vm.expectRevert(IArcadeCore.SessionGameMismatch.selector);
        arcadeCore.batchEmergencyRefund(SESSION_1, players);
    }

    /// @notice Batch refund fails for empty batch
    function test_BatchEmergencyRefund_RevertWhen_EmptyBatch() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        address[] memory players = new address[](0);

        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.EmptyBatch.selector);
        arcadeCore.batchEmergencyRefund(SESSION_1, players);
    }

    /// @notice Batch refund fails for oversized batch
    function test_BatchEmergencyRefund_RevertWhen_BatchTooLarge() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Create batch exceeding limit
        uint256 batchSize = arcadeCore.MAX_BATCH_SIZE() + 1;
        address[] memory players = new address[](batchSize);
        for (uint256 i; i < batchSize; i++) {
            players[i] = alice;
        }

        vm.prank(gameA);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArcadeCore.BatchTooLarge.selector, batchSize, arcadeCore.MAX_BATCH_SIZE()
            )
        );
        arcadeCore.batchEmergencyRefund(SESSION_1, players);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SELF-SERVICE EXPIRED REFUND
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Anyone can claim refund for expired (cancelled) sessions
    function test_ClaimExpiredRefund_Permissionless() public {
        uint256 aliceNet = _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Game cancels session (e.g., seed expired)
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Bob (random third party) triggers Alice's refund
        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit ExpiredRefundClaimed(alice, SESSION_1, aliceNet);
        arcadeCore.claimExpiredRefund(SESSION_1, alice);

        // Alice receives NET refund (rake already taken)
        assertEq(arcadeCore.getPendingPayout(alice), aliceNet);
    }

    /// @notice Player can claim their own expired refund
    function test_ClaimExpiredRefund_Self() public {
        uint256 aliceNet = _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Game cancels session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Alice claims her own refund
        vm.prank(alice);
        arcadeCore.claimExpiredRefund(SESSION_1, alice);

        // Alice receives NET refund (rake already taken)
        assertEq(arcadeCore.getPendingPayout(alice), aliceNet);
    }

    /// @notice Cannot claim expired refund for non-cancelled session
    function test_ClaimExpiredRefund_RevertWhen_SessionActive() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Session still active (not cancelled)
        vm.prank(bob);
        vm.expectRevert(IArcadeCore.SessionNotRefundable.selector);
        arcadeCore.claimExpiredRefund(SESSION_1, alice);
    }

    /// @notice Cannot claim expired refund for settled session
    function test_ClaimExpiredRefund_RevertWhen_SessionSettled() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Settle session
        vm.prank(gameA);
        arcadeCore.settleSession(SESSION_1);

        vm.prank(bob);
        vm.expectRevert(IArcadeCore.SessionNotRefundable.selector);
        arcadeCore.claimExpiredRefund(SESSION_1, alice);
    }

    /// @notice Cannot double-claim expired refund
    function test_ClaimExpiredRefund_RevertWhen_AlreadyRefunded() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // First claim
        vm.prank(bob);
        arcadeCore.claimExpiredRefund(SESSION_1, alice);

        // Second claim fails
        vm.prank(charlie);
        vm.expectRevert(IArcadeCore.AlreadyRefunded.selector);
        arcadeCore.claimExpiredRefund(SESSION_1, alice);
    }

    /// @notice Cannot claim refund for player with no deposit
    function test_ClaimExpiredRefund_RevertWhen_NoDeposit() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Try to claim for Bob who has no deposit
        vm.prank(charlie);
        vm.expectRevert(IArcadeCore.NoDepositFound.selector);
        arcadeCore.claimExpiredRefund(SESSION_1, bob);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ATTACK SCENARIOS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Attack: Malicious game tries to drain via fake session
    function test_Attack_MaliciousGameFakeSession() public {
        // Alice deposits to legitimate gameA session
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Malicious game (even if registered) cannot access gameA's session
        vm.prank(admin);
        arcadeCore.registerGame(
            maliciousGame,
            IArcadeCore.GameConfig({
                minEntry: 1 ether,
                maxEntry: 1000 ether,
                rakeBps: 500,
                burnBps: 2000,
                requiresPosition: false,
                paused: false
            })
        );

        // Cancel gameA's session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Malicious game cannot refund
        vm.prank(maliciousGame);
        vm.expectRevert(IArcadeCore.SessionGameMismatch.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, ENTRY_AMOUNT);
    }

    /// @notice Attack: Try to refund more than total deposited by all players
    function test_Attack_RefundMoreThanTotalDeposits() public {
        // Setup: Alice and Bob deposit different amounts
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        vm.warp(block.timestamp + 2);
        _createSessionWithEntry(SESSION_1, gameA, bob, ENTRY_AMOUNT * 2);

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Try to refund Alice more than her deposit
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.RefundExceedsDeposit.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, ENTRY_AMOUNT * 3);
    }

    /// @notice Verify: Prize pool correctly decremented on refund
    function test_RefundUpdatesPrizePoolCorrectly() public {
        uint256 grossDeposit = ENTRY_AMOUNT;
        uint256 netDeposit = _netAmount(grossDeposit);

        _createSessionWithEntry(SESSION_1, gameA, alice, grossDeposit);

        // Check initial prize pool
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.prizePool, netDeposit, "Initial prize pool should equal net deposit");

        // Cancel and refund the NET amount (what's actually in the prize pool)
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        vm.prank(gameA);
        arcadeCore.emergencyRefund(SESSION_1, alice, netDeposit);

        // Prize pool should be zero after full NET refund
        session = arcadeCore.getSession(SESSION_1);
        assertEq(session.prizePool, 0, "Prize pool should be zero after full refund");
    }

    /// @notice Multiple entries by same player accumulate deposits
    function test_MultipleEntriesSamePlayer_AccumulatesDeposit() public {
        // Alice enters multiple times - track NET amounts
        uint256 net1 = _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        vm.warp(block.timestamp + 2);
        uint256 net2 = _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        vm.warp(block.timestamp + 2);
        uint256 net3 = _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Total NET deposit should be 3x net
        uint256 totalNet = net1 + net2 + net3;

        // Cancel session
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Can refund total NET amount
        vm.prank(gameA);
        arcadeCore.emergencyRefund(SESSION_1, alice, totalNet);

        assertEq(arcadeCore.getPendingPayout(alice), totalNet);
    }
}
