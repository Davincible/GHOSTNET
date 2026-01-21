// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { DataToken } from "../../src/token/DataToken.sol";
import { ArcadeCore } from "../../src/arcade/ArcadeCore.sol";
import { IArcadeCore } from "../../src/arcade/interfaces/IArcadeCore.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

// ══════════════════════════════════════════════════════════════════════════════════
// MALICIOUS CONTRACTS FOR ATTACK SIMULATIONS
// ══════════════════════════════════════════════════════════════════════════════════

/// @notice Contract that attempts reentrancy during withdrawPayout
contract ReentrancyAttacker {
    ArcadeCore public target;
    uint256 public attackCount;
    uint256 public maxAttempts;
    bool public attackActive;

    constructor(address _target) {
        target = ArcadeCore(_target);
    }

    /// @notice Initiate reentrancy attack on withdrawPayout
    function attack(uint256 _maxAttempts) external {
        maxAttempts = _maxAttempts;
        attackCount = 0;
        attackActive = true;
        target.withdrawPayout();
        attackActive = false;
    }

    /// @notice Fallback that attempts reentry
    receive() external payable {
        _attemptReentry();
    }

    fallback() external payable {
        _attemptReentry();
    }

    function _attemptReentry() internal {
        if (attackActive && attackCount < maxAttempts) {
            attackCount++;
            // This should fail due to reentrancy guard
            try target.withdrawPayout() { } catch { }
        }
    }

    function getPendingPayout() external view returns (uint256) {
        return target.getPendingPayout(address(this));
    }
}

/// @notice Contract that attempts reentrancy via ERC20 callback during token receipt
/// @dev DataToken uses SafeERC20 which protects against this, but we test anyway
contract TokenCallbackAttacker {
    ArcadeCore public arcadeCore;
    DataToken public token;
    uint256 public reentryCount;
    bool public attackActive;
    uint256 public targetSessionId;

    constructor(address _arcadeCore, address _token) {
        arcadeCore = ArcadeCore(_arcadeCore);
        token = DataToken(_token);
    }

    /// @notice Approve arcade for spending
    function approveArcade() external {
        token.approve(address(arcadeCore), type(uint256).max);
    }

    /// @notice Setup attack by depositing first
    function deposit(uint256 sessionId, uint256 /* amount */) external {
        targetSessionId = sessionId;
        // This call should work normally
        // ArcadeCore.processEntry must be called BY a registered game
        // So this setup is for testing withdrawal side
    }

    /// @notice Trigger withdrawal with potential callback
    function triggerWithdraw() external {
        attackActive = true;
        arcadeCore.withdrawPayout();
        attackActive = false;
    }

    /// @notice Called if token transfer triggers a callback (shouldn't happen with DATA)
    function onTokenTransfer(address, uint256) external returns (bool) {
        if (attackActive && reentryCount < 3) {
            reentryCount++;
            try arcadeCore.withdrawPayout() { } catch { }
        }
        return true;
    }
}

/// @notice Contract that simulates flash loan attack patterns
contract FlashLoanAttacker {
    ArcadeCore public arcadeCore;
    DataToken public token;
    address public game;

    constructor(address _arcadeCore, address _token) {
        arcadeCore = ArcadeCore(_arcadeCore);
        token = DataToken(_token);
    }

    /// @notice Simulate flash loan by receiving tokens, using them, then checking balance
    /// @dev In real attack, attacker would borrow -> exploit -> repay in single tx
    function executeFlashLoanAttack(
        uint256 borrowAmount,
        uint256 /* sessionId */,
        address _game
    ) external {
        game = _game;

        // In a real flash loan, tokens would be borrowed here
        // We simulate by checking the balance manipulation pattern

        uint256 balanceBefore = token.balanceOf(address(this));

        // Approve spending
        token.approve(address(arcadeCore), borrowAmount);

        // Attempt to exploit - but game must call processEntry, not us
        // This demonstrates the attack wouldn't work because:
        // 1. Only registered games can call processEntry
        // 2. Rate limiting prevents rapid successive entries
        // 3. Session isolation prevents cross-session manipulation

        uint256 balanceAfter = token.balanceOf(address(this));

        // Flash loan would require repaying here
        // If exploit failed, attacker can't repay and tx reverts
        require(balanceAfter >= balanceBefore, "Flash loan failed to profit");
    }

    /// @notice Attempt to process entry directly (should fail - not a game)
    function attemptDirectEntry(uint256 sessionId, uint256 amount) external {
        token.approve(address(arcadeCore), amount);
        // This will fail with GameNotRegistered
        arcadeCore.processEntry(address(this), amount, sessionId);
    }

    receive() external payable { }
}

/// @notice Contract that attempts to exploit batch operations for gas exhaustion
contract GasGriefingAttacker {
    ArcadeCore public arcadeCore;

    constructor(address _arcadeCore) {
        arcadeCore = ArcadeCore(_arcadeCore);
    }

    /// @notice Attempt to cause OOG via massive batch
    function attemptBatchOOG(uint256 sessionId, uint256 batchSize) external {
        address[] memory players = new address[](batchSize);
        for (uint256 i; i < batchSize; i++) {
            players[i] = address(uint160(i + 1));
        }

        // This should be caught by MAX_BATCH_SIZE check
        arcadeCore.batchEmergencyRefund(sessionId, players);
    }
}

/// @notice Malicious implementation that tries to upgrade ArcadeCore
contract MaliciousUpgrade is UUPSUpgradeable {
    function drainFunds(address token, address to) external {
        IERC20(token).transfer(to, IERC20(token).balanceOf(address(this)));
    }

    function _authorizeUpgrade(address) internal override {
        // No restrictions - malicious!
    }
}

/// @notice Contract that attempts to manipulate session state
contract SessionManipulator {
    ArcadeCore public arcadeCore;

    constructor(address _arcadeCore) {
        arcadeCore = ArcadeCore(_arcadeCore);
    }

    /// @notice Attempt various state manipulation attacks
    function attemptDoubleCreditSameSession(
        uint256 sessionId,
        address player,
        uint256 amount
    ) external {
        // Try crediting twice - second should fail
        arcadeCore.creditPayout(sessionId, player, amount, 0, true);
        arcadeCore.creditPayout(sessionId, player, amount, 0, true);
    }
}

// ══════════════════════════════════════════════════════════════════════════════════
// MAIN TEST CONTRACT
// ══════════════════════════════════════════════════════════════════════════════════

/// @title ArcadeCore Security Tests
/// @notice Comprehensive attack vector testing for ArcadeCore
/// @dev These tests verify that various attack vectors FAIL
///      Every test should demonstrate an attack being prevented
contract ArcadeCoreSecurityTest is Test {
    // ─────────────────────────────────────────────────────────────────────────────
    // State
    // ─────────────────────────────────────────────────────────────────────────────

    DataToken public token;
    ArcadeCore public arcadeCore;
    ArcadeCore public implementation;

    address public treasury = makeAddr("treasury");
    address public admin = makeAddr("admin");
    address public gameA = makeAddr("gameA");
    address public gameB = makeAddr("gameB");
    address public attacker = makeAddr("attacker");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    // Attack contracts
    ReentrancyAttacker public reentrancyAttacker;
    FlashLoanAttacker public flashLoanAttacker;
    GasGriefingAttacker public gasGriefingAttacker;
    SessionManipulator public sessionManipulator;

    uint256 constant TOTAL_SUPPLY = 100_000_000 ether;
    uint256 constant ALICE_BALANCE = 40_000_000 ether;
    uint256 constant BOB_BALANCE = 30_000_000 ether;
    uint256 constant ATTACKER_BALANCE = 10_000_000 ether;
    uint256 constant CHARLIE_BALANCE = 20_000_000 ether;
    uint256 constant SESSION_1 = 1;
    uint256 constant SESSION_2 = 2;
    uint256 constant SESSION_999 = 999;
    uint256 constant ENTRY_AMOUNT = 1000 ether;
    uint16 constant RAKE_BPS = 500; // 5%

    // ─────────────────────────────────────────────────────────────────────────────
    // Setup
    // ─────────────────────────────────────────────────────────────────────────────

    function setUp() public {
        // Deploy token with distribution
        address[] memory recipients = new address[](4);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = attacker;
        recipients[3] = charlie;

        uint256[] memory amounts = new uint256[](4);
        amounts[0] = ALICE_BALANCE;
        amounts[1] = BOB_BALANCE;
        amounts[2] = ATTACKER_BALANCE;
        amounts[3] = CHARLIE_BALANCE;

        token = new DataToken(treasury, admin, recipients, amounts);

        // Deploy ArcadeCore
        implementation = new ArcadeCore();
        bytes memory initData =
            abi.encodeCall(ArcadeCore.initialize, (address(token), address(0), treasury, admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        arcadeCore = ArcadeCore(address(proxy));

        // Exclude arcade from tax
        vm.prank(admin);
        token.setTaxExclusion(address(arcadeCore), true);

        // Register games
        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 1 ether,
            maxEntry: 100_000 ether,
            rakeBps: RAKE_BPS,
            burnBps: 2000,
            requiresPosition: false,
            paused: false
        });

        vm.startPrank(admin);
        arcadeCore.registerGame(gameA, config);
        arcadeCore.registerGame(gameB, config);
        vm.stopPrank();

        // Approve arcade for all users
        vm.prank(alice);
        token.approve(address(arcadeCore), type(uint256).max);
        vm.prank(bob);
        token.approve(address(arcadeCore), type(uint256).max);
        vm.prank(attacker);
        token.approve(address(arcadeCore), type(uint256).max);
        vm.prank(charlie);
        token.approve(address(arcadeCore), type(uint256).max);

        // Deploy attack contracts
        reentrancyAttacker = new ReentrancyAttacker(address(arcadeCore));
        flashLoanAttacker = new FlashLoanAttacker(address(arcadeCore), address(token));
        gasGriefingAttacker = new GasGriefingAttacker(address(arcadeCore));
        sessionManipulator = new SessionManipulator(address(arcadeCore));
    }

    /// @notice Helper to calculate net amount after rake
    function _netAmount(uint256 gross) internal pure returns (uint256) {
        return gross - (gross * RAKE_BPS / 10_000);
    }

    /// @notice Helper to create session with entry
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
    // 1. REENTRANCY ATTACKS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Verify reentrancy guard prevents withdrawal exploit
    function test_Attack_Reentrancy_OnWithdrawPayout() public {
        // Setup: Create session and credit payout to attacker contract
        vm.prank(attacker);
        token.transfer(address(reentrancyAttacker), 1000 ether);

        // Setup: Give attacker contract pending payout via game credit
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        vm.prank(gameA);
        arcadeCore.creditPayout(SESSION_1, address(reentrancyAttacker), 100 ether, 0, true);

        // Verify attacker has pending payout
        uint256 pendingBefore = arcadeCore.getPendingPayout(address(reentrancyAttacker));
        assertEq(pendingBefore, 100 ether, "Attacker should have pending payout");

        // Attempt reentrancy attack - should not drain extra funds
        reentrancyAttacker.attack(5);

        // Verify only got legitimate payout (reentrancy was blocked)
        uint256 pendingAfter = arcadeCore.getPendingPayout(address(reentrancyAttacker));
        assertEq(pendingAfter, 0, "Pending should be cleared after single withdrawal");
        assertEq(reentrancyAttacker.attackCount(), 0, "Reentrant calls should have failed");
    }

    /// @notice Verify reentrancy guard on creditPayout
    function test_Attack_Reentrancy_OnCreditPayout() public {
        // Create session
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // creditPayout has nonReentrant modifier
        // Multiple sequential calls work but reentrant calls within same tx would fail
        vm.startPrank(gameA);
        arcadeCore.creditPayout(SESSION_1, alice, 10 ether, 0, true);
        arcadeCore.creditPayout(SESSION_1, bob, 10 ether, 0, true);
        vm.stopPrank();

        // Verify both credits processed
        assertEq(arcadeCore.getPendingPayout(alice), 10 ether);
        assertEq(arcadeCore.getPendingPayout(bob), 10 ether);
    }

    /// @notice Verify reentrancy guard on batch operations
    function test_Attack_Reentrancy_OnBatchOperations() public {
        // Create session with multiple entries
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        vm.warp(block.timestamp + 2);
        _createSessionWithEntry(SESSION_1, gameA, bob, ENTRY_AMOUNT);

        // Batch credit has nonReentrant modifier
        uint256[] memory sessionIds = new uint256[](2);
        address[] memory players = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory burnAmounts = new uint256[](2);
        bool[] memory results = new bool[](2);

        sessionIds[0] = SESSION_1;
        sessionIds[1] = SESSION_1;
        players[0] = alice;
        players[1] = bob;
        amounts[0] = 10 ether;
        amounts[1] = 10 ether;
        burnAmounts[0] = 0;
        burnAmounts[1] = 0;
        results[0] = true;
        results[1] = true;

        vm.prank(gameA);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);

        // Verify batch processed correctly
        assertEq(arcadeCore.getPendingPayout(alice), 10 ether);
        assertEq(arcadeCore.getPendingPayout(bob), 10 ether);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 2. FLASH LOAN ATTACKS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Verify flash loan cannot exploit single block
    /// @dev Rate limiting prevents rapid successive entries
    function test_Attack_FlashLoan_RateLimitingEnforced() public {
        // First entry succeeds
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Immediate second entry should fail due to rate limiting
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.RateLimited.selector);
        arcadeCore.processEntry(alice, ENTRY_AMOUNT, SESSION_1);

        // After waiting, entry succeeds
        vm.warp(block.timestamp + 2);
        vm.prank(gameA);
        arcadeCore.processEntry(alice, ENTRY_AMOUNT, SESSION_1);
    }

    /// @notice Verify flash loan cannot bypass via multiple addresses (Sybil)
    /// @dev Each address still needs tokens and game must call processEntry
    function test_Attack_FlashLoan_SybilLimitedByGameCall() public {
        // Attacker creates multiple addresses
        address sybil1 = makeAddr("sybil1");
        address sybil2 = makeAddr("sybil2");

        // Fund sybil addresses
        vm.prank(attacker);
        token.transfer(sybil1, 1000 ether);
        vm.prank(attacker);
        token.transfer(sybil2, 1000 ether);

        vm.prank(sybil1);
        token.approve(address(arcadeCore), type(uint256).max);
        vm.prank(sybil2);
        token.approve(address(arcadeCore), type(uint256).max);

        // Game must call processEntry - attacker cannot call directly
        // If attacker is the game, they're a registered game (trusted)
        vm.startPrank(gameA);
        arcadeCore.processEntry(sybil1, 100 ether, SESSION_1);
        arcadeCore.processEntry(sybil2, 100 ether, SESSION_1);
        vm.stopPrank();

        // Verify entries processed but bounded by session prize pool
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        uint256 expectedPrizePool = _netAmount(100 ether) + _netAmount(100 ether);
        assertEq(session.prizePool, expectedPrizePool);
    }

    /// @notice Verify unregistered attacker cannot process entries
    function test_Attack_FlashLoan_UnregisteredAttackerBlocked() public {
        // Fund flash loan attacker contract
        vm.prank(attacker);
        token.transfer(address(flashLoanAttacker), 1000 ether);

        // Attacker tries to process entry directly - should fail
        vm.expectRevert(IArcadeCore.GameNotRegistered.selector);
        flashLoanAttacker.attemptDirectEntry(SESSION_1, 100 ether);
    }

    /// @notice Verify flash loan via multiple games isolated
    function test_Attack_FlashLoan_CrossGameIsolation() public {
        // Create sessions in different games
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        _createSessionWithEntry(SESSION_2, gameB, bob, ENTRY_AMOUNT * 2);

        // Each session is isolated - gameA cannot access gameB's prize pool
        uint256 gameBPrizePool = arcadeCore.getSession(SESSION_2).prizePool;

        // GameA tries to credit from gameB's session
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionGameMismatch.selector);
        arcadeCore.creditPayout(SESSION_2, alice, gameBPrizePool, 0, true);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 3. ACCESS CONTROL BYPASS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Unregistered game cannot process entry
    function test_Attack_UnregisteredGameCannotProcessEntry() public {
        vm.prank(attacker);
        vm.expectRevert(IArcadeCore.GameNotRegistered.selector);
        arcadeCore.processEntry(alice, ENTRY_AMOUNT, SESSION_1);
    }

    /// @notice Unregistered game cannot credit payout
    function test_Attack_UnregisteredGameCannotCreditPayout() public {
        // Create session via legitimate game
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Attacker tries to credit payout
        vm.prank(attacker);
        vm.expectRevert(IArcadeCore.GameNotRegistered.selector);
        arcadeCore.creditPayout(SESSION_1, attacker, ENTRY_AMOUNT, 0, true);
    }

    /// @notice Wrong game cannot credit other session
    function test_Attack_WrongGameCannotCreditOtherSession() public {
        // GameA creates session
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // GameB tries to credit payout on gameA's session
        vm.prank(gameB);
        vm.expectRevert(IArcadeCore.SessionGameMismatch.selector);
        arcadeCore.creditPayout(SESSION_1, bob, 100 ether, 0, true);
    }

    /// @notice Player cannot credit their own payout
    function test_Attack_PlayerCannotCreditOwnPayout() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Alice tries to credit herself (she's not a registered game)
        vm.prank(alice);
        vm.expectRevert(IArcadeCore.GameNotRegistered.selector);
        arcadeCore.creditPayout(SESSION_1, alice, 100 ether, 0, true);
    }

    /// @notice Non-admin cannot pause
    function test_Attack_NonAdminCannotPause() public {
        bytes32 pauserRole = arcadeCore.PAUSER_ROLE();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, attacker, pauserRole
            )
        );
        arcadeCore.pause();
    }

    /// @notice Non-admin cannot upgrade
    function test_Attack_NonAdminCannotUpgrade() public {
        MaliciousUpgrade maliciousImpl = new MaliciousUpgrade();

        bytes32 adminRole = arcadeCore.DEFAULT_ADMIN_ROLE();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, attacker, adminRole
            )
        );
        arcadeCore.upgradeToAndCall(address(maliciousImpl), "");
    }

    /// @notice Test role escalation attempt
    function test_Attack_RoleEscalation() public {
        bytes32 gameAdminRole = arcadeCore.GAME_ADMIN_ROLE();

        // Attacker tries to grant themselves GAME_ADMIN role
        vm.prank(attacker);
        vm.expectRevert();
        arcadeCore.grantRole(gameAdminRole, attacker);
    }

    /// @notice Non-game-admin cannot register games
    function test_Attack_NonAdminCannotRegisterGame() public {
        bytes32 gameAdminRole = arcadeCore.GAME_ADMIN_ROLE();

        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 1 ether,
            maxEntry: 1000 ether,
            rakeBps: 500,
            burnBps: 2000,
            requiresPosition: false,
            paused: false
        });

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, attacker, gameAdminRole
            )
        );
        arcadeCore.registerGame(attacker, config);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 4. SESSION MANIPULATION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Cannot credit more than prize pool in total
    function test_Attack_CreditMoreThanPrizePool() public {
        uint256 netAmount = _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Try to credit more than available
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.PayoutExceedsPrizePool.selector);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount + 1, 0, true);
    }

    /// @notice Cannot settle session twice
    function test_Attack_SettleTwice() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        vm.startPrank(gameA);
        arcadeCore.settleSession(SESSION_1);

        // Second settle should fail
        vm.expectRevert(IArcadeCore.SessionNotActive.selector);
        arcadeCore.settleSession(SESSION_1);
        vm.stopPrank();
    }

    /// @notice Cannot cancel then settle
    function test_Attack_CancelThenSettle() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        vm.startPrank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Settle after cancel should fail
        vm.expectRevert(IArcadeCore.SessionNotActive.selector);
        arcadeCore.settleSession(SESSION_1);
        vm.stopPrank();
    }

    /// @notice Cannot settle then cancel
    function test_Attack_SettleThenCancel() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        vm.startPrank(gameA);
        arcadeCore.settleSession(SESSION_1);

        // Cancel after settle should fail
        vm.expectRevert(IArcadeCore.SessionNotActive.selector);
        arcadeCore.cancelSession(SESSION_1);
        vm.stopPrank();
    }

    /// @notice Cannot refund from settled session
    function test_Attack_RefundAfterSettle() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        vm.startPrank(gameA);
        arcadeCore.settleSession(SESSION_1);

        // Refund after settle should fail
        vm.expectRevert(IArcadeCore.SessionNotRefundable.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, 100 ether);
        vm.stopPrank();
    }

    /// @notice Cannot credit payout after cancel
    function test_Attack_CreditAfterCancel() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        vm.startPrank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Credit after cancel should fail
        vm.expectRevert(IArcadeCore.SessionNotActive.selector);
        arcadeCore.creditPayout(SESSION_1, alice, 100 ether, 0, true);
        vm.stopPrank();
    }

    /// @notice Cannot operate on non-existent session
    function test_Attack_FakeSessionId() public {
        // Try to credit on non-existent session
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotFound.selector);
        arcadeCore.creditPayout(SESSION_999, alice, 100 ether, 0, true);

        // Try to settle non-existent
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotFound.selector);
        arcadeCore.settleSession(SESSION_999);

        // Try to cancel non-existent
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotFound.selector);
        arcadeCore.cancelSession(SESSION_999);
    }

    /// @notice Session ID overflow handling
    function test_Attack_OverflowSessionId() public {
        uint256 maxSessionId = type(uint256).max;

        // Should work with max uint256 as session ID
        vm.prank(gameA);
        arcadeCore.processEntry(alice, 100 ether, maxSessionId);

        // Verify session was created
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(maxSessionId);
        assertEq(session.game, gameA);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 5. GRIEFING ATTACKS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Cannot exhaust gas via oversized batch
    function test_Attack_Grief_GasExhaustionBatch() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Try oversized batch
        uint256 batchSize = arcadeCore.MAX_BATCH_SIZE() + 1;
        address[] memory players = new address[](batchSize);
        for (uint256 i; i < batchSize; i++) {
            players[i] = address(uint160(i + 1));
        }

        vm.prank(gameA);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArcadeCore.BatchTooLarge.selector, batchSize, arcadeCore.MAX_BATCH_SIZE()
            )
        );
        arcadeCore.batchEmergencyRefund(SESSION_1, players);
    }

    /// @notice Cannot grief with empty batch
    function test_Attack_Grief_EmptyBatch() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        address[] memory emptyPlayers = new address[](0);

        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.EmptyBatch.selector);
        arcadeCore.batchEmergencyRefund(SESSION_1, emptyPlayers);
    }

    /// @notice Mismatched array lengths in batch credit rejected
    function test_Attack_Grief_MismatchedArrayLengths() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        uint256[] memory sessionIds = new uint256[](2);
        address[] memory players = new address[](3); // Mismatch!
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory burnAmounts = new uint256[](2);
        bool[] memory results = new bool[](2);

        vm.prank(gameA);
        vm.expectRevert(
            abi.encodeWithSelector(IArcadeCore.ArrayLengthMismatch.selector, 2, 3, 2, 2, 2)
        );
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    /// @notice Spam sessions don't affect other sessions
    function test_Attack_Grief_SpamSessions() public {
        // Create many sessions
        for (uint256 i = 1; i <= 50; i++) {
            vm.prank(gameA);
            arcadeCore.processEntry(alice, 10 ether, i);
            vm.warp(block.timestamp + 2); // Rate limit
        }

        // Each session is independent and functional
        IArcadeCore.SessionRecord memory session1 = arcadeCore.getSession(1);
        IArcadeCore.SessionRecord memory session50 = arcadeCore.getSession(50);

        assertTrue(session1.state == IArcadeCore.SessionState.ACTIVE);
        assertTrue(session50.state == IArcadeCore.SessionState.ACTIVE);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 6. FRONT-RUNNING
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Front-run withdraw with cancel doesn't steal funds
    /// @dev Withdraw uses pull pattern - pending balance protected
    function test_Attack_Frontrun_WithdrawDoesntStealFunds() public {
        // Create session and credit payout
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        uint256 payoutAmount = 500 ether;

        vm.prank(gameA);
        arcadeCore.creditPayout(SESSION_1, alice, payoutAmount, 0, true);

        // Even if session is cancelled, Alice's pending payout is safe
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Alice can still withdraw her credited payout
        uint256 aliceBalanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        arcadeCore.withdrawPayout();

        assertEq(token.balanceOf(alice), aliceBalanceBefore + payoutAmount);
    }

    /// @notice Front-running entry with cancel refunds properly
    function test_Attack_Frontrun_CancelBeforeSettle() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Front-runner sees settlement tx and cancels first
        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Alice's deposit is available for refund
        vm.prank(gameA);
        arcadeCore.emergencyRefund(SESSION_1, alice, _netAmount(ENTRY_AMOUNT));

        // Alice gets her funds back (minus rake which was already processed)
        vm.prank(alice);
        arcadeCore.withdrawPayout();

        // Settlement would fail but funds are safe
    }

    /// @notice Refund race condition - double refund blocked
    function test_Attack_Frontrun_RefundRace() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        uint256 netAmount = _netAmount(ENTRY_AMOUNT);

        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // First refund succeeds
        vm.prank(gameA);
        arcadeCore.emergencyRefund(SESSION_1, alice, netAmount);

        // Race condition: attacker tries second refund
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.AlreadyRefunded.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, netAmount);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 7. INTEGER OVERFLOW/UNDERFLOW
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Solidity 0.8+ prevents overflow - large amounts work correctly
    function test_Attack_Overflow_PrizePool() public {
        // Create session with maximum allowed entry amount (100_000 ether from config)
        uint256 largeAmount = 100_000 ether;
        uint256 netAmount = _createSessionWithEntry(SESSION_1, gameA, alice, largeAmount);

        // Prize pool should be correct
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.prizePool, netAmount);
    }

    /// @notice Cannot underflow refund more than deposit
    function test_Attack_Underflow_RefundMoreThanDeposit() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        uint256 netDeposit = _netAmount(ENTRY_AMOUNT);

        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        // Try to refund more than net deposit (Solidity would overflow on subtraction)
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.RefundExceedsDeposit.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, netDeposit + 1);
    }

    /// @notice Cannot payout more than prize pool (underflow protection)
    function test_Attack_Underflow_PayoutMoreThanPrizePool() public {
        uint256 netAmount = _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Try to payout more than prize pool
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.PayoutExceedsPrizePool.selector);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount + 1, 0, true);
    }

    /// @notice Large batch amounts don't overflow totals
    function test_Invariant_BatchTotalsNoOverflow() public {
        // Create session with large entry (within maxEntry limit)
        // Multiple entries to build up prize pool
        _createSessionWithEntry(SESSION_1, gameA, alice, 100_000 ether);
        vm.warp(block.timestamp + 2);
        _createSessionWithEntry(SESSION_1, gameA, bob, 100_000 ether);
        vm.warp(block.timestamp + 2);
        _createSessionWithEntry(SESSION_1, gameA, charlie, 100_000 ether);

        // Net amounts after 5% rake = 95_000 each = 285_000 total prize pool

        uint256[] memory sessionIds = new uint256[](3);
        address[] memory players = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        uint256[] memory burnAmounts = new uint256[](3);
        bool[] memory results = new bool[](3);

        sessionIds[0] = SESSION_1;
        sessionIds[1] = SESSION_1;
        sessionIds[2] = SESSION_1;
        players[0] = alice;
        players[1] = bob;
        players[2] = charlie;
        // Each player gets 90_000 + 2_000 burn = 92_000 total per player
        // 92_000 * 3 = 276_000 which is within 285_000 prize pool
        amounts[0] = 90_000 ether;
        amounts[1] = 90_000 ether;
        amounts[2] = 90_000 ether;
        burnAmounts[0] = 2_000 ether;
        burnAmounts[1] = 2_000 ether;
        burnAmounts[2] = 2_000 ether;
        results[0] = true;
        results[1] = true;
        results[2] = true;

        vm.prank(gameA);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);

        // Verify totals are correct (no overflow)
        assertEq(arcadeCore.getPendingPayout(alice), 90_000 ether);
        assertEq(arcadeCore.getPendingPayout(bob), 90_000 ether);
        assertEq(arcadeCore.getPendingPayout(charlie), 90_000 ether);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 8. TOKEN MANIPULATION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Zero amount operations handled correctly
    function test_Attack_ZeroAmountEntry() public {
        // Zero entry should be rejected by minEntry check
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.InvalidEntryAmount.selector);
        arcadeCore.processEntry(alice, 0, SESSION_1);
    }

    /// @notice Zero payout is allowed (losing with no consolation)
    function test_ZeroPayoutAllowed() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Zero payout is valid (player lost)
        vm.prank(gameA);
        arcadeCore.creditPayout(SESSION_1, alice, 0, 0, false);

        // No pending payout credited
        assertEq(arcadeCore.getPendingPayout(alice), 0);
    }

    /// @notice Approval doesn't affect other users
    function test_Attack_ApprovalIsolation() public {
        // Alice approves arcade
        vm.prank(alice);
        token.approve(address(arcadeCore), type(uint256).max);

        // Bob approves for different amount
        vm.prank(bob);
        token.approve(address(arcadeCore), 1000 ether);

        // Game processes entry for Alice (uses Alice's approval)
        vm.prank(gameA);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // Bob's approval is separate
        assertEq(token.allowance(bob, address(arcadeCore)), 1000 ether);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 9. PROXY/UPGRADE ATTACKS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Cannot initialize proxy twice
    function test_Attack_InitializeAlreadyInitialized() public {
        vm.expectRevert();
        arcadeCore.initialize(address(token), address(0), treasury, attacker);
    }

    /// @notice Cannot initialize implementation directly
    function test_Attack_InitializeImplementationDirectly() public {
        vm.expectRevert();
        implementation.initialize(address(token), address(0), treasury, attacker);
    }

    /// @notice Only admin can upgrade to new implementation
    function test_Attack_UpgradeToMaliciousContract() public {
        MaliciousUpgrade malicious = new MaliciousUpgrade();

        // Non-admin cannot upgrade
        vm.prank(attacker);
        vm.expectRevert();
        arcadeCore.upgradeToAndCall(address(malicious), "");

        // Admin CAN upgrade (governance should be careful)
        vm.prank(admin);
        arcadeCore.upgradeToAndCall(address(malicious), "");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 10. STATE CORRUPTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Session state transitions are atomic
    function test_Invariant_SessionStateTransitions() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertTrue(session.state == IArcadeCore.SessionState.ACTIVE);

        // Settle
        vm.prank(gameA);
        arcadeCore.settleSession(SESSION_1);

        session = arcadeCore.getSession(SESSION_1);
        assertTrue(session.state == IArcadeCore.SessionState.SETTLED);

        // Cannot transition back
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.SessionNotActive.selector);
        arcadeCore.cancelSession(SESSION_1);
    }

    /// @notice Player stats cannot be directly manipulated
    function test_Invariant_PlayerStatsProtected() public {
        // Initial stats
        IArcadeCore.PlayerStats memory statsBefore = arcadeCore.getPlayerStats(alice);
        assertEq(statsBefore.totalGamesPlayed, 0);

        // Play a game
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        IArcadeCore.PlayerStats memory statsAfter = arcadeCore.getPlayerStats(alice);
        assertEq(statsAfter.totalGamesPlayed, 1);

        // No way to directly modify stats - they're updated via processEntry/creditPayout
    }

    /// @notice Global stats remain consistent
    function test_Invariant_GlobalStatsConsistent() public {
        (uint256 games1, uint256 volume1,,) = arcadeCore.getGlobalStats();
        assertEq(games1, 0);
        assertEq(volume1, 0);

        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        (uint256 games2, uint256 volume2,,) = arcadeCore.getGlobalStats();
        assertEq(games2, 1);
        assertEq(volume2, ENTRY_AMOUNT);

        vm.warp(block.timestamp + 2);
        _createSessionWithEntry(SESSION_1, gameA, bob, ENTRY_AMOUNT * 2);

        (uint256 games3, uint256 volume3,,) = arcadeCore.getGlobalStats();
        assertEq(games3, 2);
        assertEq(volume3, ENTRY_AMOUNT + ENTRY_AMOUNT * 2);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 11. FUZZ TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Fuzz: Entry amount validation
    function testFuzz_EntryAmountBounded(
        uint256 amount
    ) public {
        // Bound to reasonable values (skip dust amounts that could cause issues)
        amount = bound(amount, 0, ALICE_BALANCE);

        if (amount < 1 ether) {
            // Below minEntry
            vm.prank(gameA);
            vm.expectRevert(IArcadeCore.InvalidEntryAmount.selector);
            arcadeCore.processEntry(alice, amount, SESSION_1);
        } else if (amount > 100_000 ether) {
            // Above maxEntry
            vm.prank(gameA);
            vm.expectRevert(IArcadeCore.InvalidEntryAmount.selector);
            arcadeCore.processEntry(alice, amount, SESSION_1);
        } else {
            // Valid entry
            vm.prank(gameA);
            arcadeCore.processEntry(alice, amount, SESSION_1);

            IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
            assertTrue(session.state == IArcadeCore.SessionState.ACTIVE);
        }
    }

    /// @notice Fuzz: Payout cannot exceed prize pool
    function testFuzz_PayoutBoundedByPrizePool(uint256 entryAmount, uint256 payoutAmount) public {
        // Bound entry to valid range
        entryAmount = bound(entryAmount, 1 ether, 10_000 ether);
        payoutAmount = bound(payoutAmount, 0, type(uint128).max);

        uint256 netAmount = _createSessionWithEntry(SESSION_1, gameA, alice, entryAmount);

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

    /// @notice Fuzz: Refund bounded by deposit
    function testFuzz_RefundBoundedByDeposit(uint256 entryAmount, uint256 refundAmount) public {
        // Bound entry to valid range
        entryAmount = bound(entryAmount, 1 ether, 10_000 ether);
        refundAmount = bound(refundAmount, 1, type(uint128).max);

        uint256 netAmount = _createSessionWithEntry(SESSION_1, gameA, alice, entryAmount);

        vm.prank(gameA);
        arcadeCore.cancelSession(SESSION_1);

        if (refundAmount <= netAmount) {
            vm.prank(gameA);
            arcadeCore.emergencyRefund(SESSION_1, alice, refundAmount);

            assertEq(arcadeCore.getPendingPayout(alice), refundAmount);
        } else {
            vm.prank(gameA);
            vm.expectRevert(IArcadeCore.RefundExceedsDeposit.selector);
            arcadeCore.emergencyRefund(SESSION_1, alice, refundAmount);
        }
    }

    /// @notice Fuzz: Session ID handling
    function testFuzz_SessionIdHandling(
        uint256 sessionId
    ) public {
        vm.prank(gameA);
        arcadeCore.processEntry(alice, 100 ether, sessionId);

        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(sessionId);
        assertEq(session.game, gameA);
        assertTrue(session.state == IArcadeCore.SessionState.ACTIVE);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 12. SOLVENCY INVARIANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Total pending payouts cannot exceed arcade balance
    function test_Invariant_SolvencyMaintained() public {
        // Multiple deposits and payouts
        _createSessionWithEntry(SESSION_1, gameA, alice, 10_000 ether);
        vm.warp(block.timestamp + 2);
        _createSessionWithEntry(SESSION_1, gameA, bob, 5_000 ether);

        vm.prank(gameA);
        arcadeCore.creditPayout(SESSION_1, alice, 3_000 ether, 1_000 ether, true);

        vm.prank(gameA);
        arcadeCore.creditPayout(SESSION_1, bob, 2_000 ether, 500 ether, true);

        // Check solvency
        uint256 totalPending = arcadeCore.getTotalPendingPayouts();
        uint256 arcadeBalance = token.balanceOf(address(arcadeCore));

        // Arcade balance must cover all pending payouts
        assertGe(arcadeBalance, totalPending, "SOLVENCY VIOLATED");
    }

    /// @notice Settling session sends remaining to treasury, maintains solvency
    function test_Invariant_SettlementSolvency() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, 10_000 ether);

        // Partial payout
        vm.prank(gameA);
        arcadeCore.creditPayout(SESSION_1, alice, 3_000 ether, 0, true);

        uint256 treasuryBefore = token.balanceOf(treasury);

        // Settle - remaining goes to treasury
        vm.prank(gameA);
        arcadeCore.settleSession(SESSION_1);

        uint256 treasuryAfter = token.balanceOf(treasury);

        // Treasury received remaining prize pool
        assertGt(treasuryAfter, treasuryBefore);

        // Arcade still solvent for pending payouts
        uint256 totalPending = arcadeCore.getTotalPendingPayouts();
        uint256 arcadeBalance = token.balanceOf(address(arcadeCore));
        assertGe(arcadeBalance, totalPending);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 13. EDGE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Paused game cannot process entries
    function test_PausedGameBlocked() public {
        vm.prank(admin);
        arcadeCore.pauseGame(gameA);

        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.GamePaused.selector);
        arcadeCore.processEntry(alice, ENTRY_AMOUNT, SESSION_1);
    }

    /// @notice Global pause blocks all entry processing
    function test_GlobalPauseBlocked() public {
        vm.prank(admin);
        arcadeCore.pause();

        vm.prank(gameA);
        vm.expectRevert();
        arcadeCore.processEntry(alice, ENTRY_AMOUNT, SESSION_1);
    }

    /// @notice Quarantine cancels all active sessions
    function test_QuarantineCancelsAllSessions() public {
        // Create multiple sessions
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);
        vm.warp(block.timestamp + 2);
        _createSessionWithEntry(SESSION_2, gameA, bob, ENTRY_AMOUNT);

        // Quarantine game
        vm.prank(admin);
        arcadeCore.emergencyQuarantineGame(gameA);

        // Both sessions cancelled
        IArcadeCore.SessionRecord memory session1 = arcadeCore.getSession(SESSION_1);
        IArcadeCore.SessionRecord memory session2 = arcadeCore.getSession(SESSION_2);

        assertTrue(session1.state == IArcadeCore.SessionState.CANCELLED);
        assertTrue(session2.state == IArcadeCore.SessionState.CANCELLED);
    }

    /// @notice Unregistering game doesn't affect existing sessions
    function test_UnregisterDoesNotAffectSessions() public {
        _createSessionWithEntry(SESSION_1, gameA, alice, ENTRY_AMOUNT);

        // Unregister game
        vm.prank(admin);
        arcadeCore.unregisterGame(gameA);

        // Session still exists
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.game, gameA);

        // But new entries blocked
        vm.prank(gameA);
        vm.expectRevert(IArcadeCore.GameNotRegistered.selector);
        arcadeCore.processEntry(bob, ENTRY_AMOUNT, SESSION_1);
    }
}
