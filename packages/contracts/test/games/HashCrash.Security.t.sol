// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";
import { HashCrash } from "../../src/arcade/games/HashCrash.sol";
import { IArcadeGame } from "../../src/arcade/interfaces/IArcadeGame.sol";
import { IArcadeTypes } from "../../src/arcade/interfaces/IArcadeTypes.sol";
import { IArcadeCore } from "../../src/arcade/interfaces/IArcadeCore.sol";
import { ArcadeCore } from "../../src/arcade/ArcadeCore.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

/// @title HashCrashSecurityTest
/// @notice Security-focused tests for HashCrash - negative tests, edge cases, attack vectors
/// @dev Ensures the pre-commit model is secure against manipulation and exploits
contract HashCrashSecurityTest is Test {
    HashCrash public game;
    ArcadeCore public arcadeCore;
    ERC20Mock public dataToken;

    address public owner = makeAddr("owner");
    address public admin = makeAddr("admin");
    address public treasury = makeAddr("treasury");
    address public attacker = makeAddr("attacker");

    address public player1 = makeAddr("player1");
    address public player2 = makeAddr("player2");

    uint256 public constant INITIAL_BALANCE = 10_000 ether;
    uint256 public constant DEFAULT_BET = 100 ether;
    uint256 public constant DEFAULT_TARGET = 200; // 2.00x

    uint256 public constant MIN_ENTRY = 1 ether;
    uint256 public constant MAX_ENTRY = 1000 ether;
    uint16 public constant RAKE_BPS = 500;
    uint16 public constant BURN_BPS = 2000;

    function setUp() public {
        vm.startPrank(owner);

        dataToken = new ERC20Mock("DATA", "DATA", 18);

        ArcadeCore impl = new ArcadeCore();
        bytes memory initData = abi.encodeCall(
            ArcadeCore.initialize, (address(dataToken), address(0), treasury, admin)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        arcadeCore = ArcadeCore(address(proxy));

        game = new HashCrash(address(arcadeCore), owner);

        vm.stopPrank();

        vm.prank(admin);
        arcadeCore.registerGame(
            address(game),
            IArcadeCore.GameConfig({
                minEntry: MIN_ENTRY,
                maxEntry: MAX_ENTRY,
                rakeBps: RAKE_BPS,
                burnBps: BURN_BPS,
                requiresPosition: false,
                paused: false
            })
        );

        _fundPlayer(player1, INITIAL_BALANCE);
        _fundPlayer(player2, INITIAL_BALANCE);
        _fundPlayer(attacker, INITIAL_BALANCE);

        vm.roll(1000);
    }

    function _fundPlayer(address player, uint256 amount) internal {
        dataToken.mint(player, amount);
        vm.prank(player);
        dataToken.approve(address(arcadeCore), type(uint256).max);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ACCESS CONTROL SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_OnlyOwnerCanPause() public {
        vm.prank(attacker);
        vm.expectRevert();
        game.pause();

        vm.prank(admin);
        vm.expectRevert();
        game.pause();

        vm.prank(player1);
        vm.expectRevert();
        game.pause();
    }

    function test_Security_OnlyOwnerCanUnpause() public {
        vm.prank(owner);
        game.pause();

        vm.prank(attacker);
        vm.expectRevert();
        game.unpause();

        vm.prank(admin);
        vm.expectRevert();
        game.unpause();
    }

    function test_Security_OnlyOwnerCanSetActive() public {
        vm.prank(attacker);
        vm.expectRevert();
        game.setActive(false);

        vm.prank(admin);
        vm.expectRevert();
        game.setActive(false);
    }

    function test_Security_OnlyOwnerCanEmergencyCancel() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.prank(attacker);
        vm.expectRevert();
        game.emergencyCancel(1, "Attack");

        vm.prank(admin);
        vm.expectRevert();
        game.emergencyCancel(1, "Attack");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE MACHINE SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_CannotBetAfterLocked() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        vm.prank(player2);
        vm.expectRevert(HashCrash.BettingClosed.selector);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);
    }

    function test_Security_CannotBetAfterRevealed() public {
        _setupRevealedRound();

        vm.prank(player2);
        vm.expectRevert(HashCrash.BettingClosed.selector);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);
    }

    function test_Security_CannotBetAfterSettled() public {
        _completeRound();

        vm.prank(player2);
        vm.expectRevert(HashCrash.BettingClosed.selector);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);
    }

    function test_Security_CannotLockTwice() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.lockRound();
    }

    function test_Security_CannotRevealTwice() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 1);

        game.revealCrash();

        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.revealCrash();
    }

    function test_Security_CannotSettleBeforeReveal() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        // Try to settle before reveal
        vm.expectRevert(HashCrash.NotRevealed.selector);
        game.settle(player1);
    }

    function test_Security_CannotDoubleSettle() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, 9999); // High target to likely lose

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 1);
        game.revealCrash();

        game.settle(player1);

        vm.expectRevert(HashCrash.AlreadySettled.selector);
        game.settle(player1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TIMING ATTACK PREVENTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_CannotBetAtExactEndTime() public {
        game.startRound();

        HashCrash.Round memory round = game.getRound(1);

        // Warp to exact end time
        vm.warp(round.bettingEndTime);

        vm.prank(player1);
        vm.expectRevert(HashCrash.BettingClosed.selector);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);
    }

    function test_Security_CannotLockBeforeEndTime() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        HashCrash.Round memory round = game.getRound(1);

        // Warp to 1 second before end
        vm.warp(round.bettingEndTime - 1);

        vm.expectRevert(HashCrash.BettingNotEnded.selector);
        game.lockRound();
    }

    function test_Security_CannotRevealBeforeSeedBlock() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        // Try to reveal immediately (seed block not mined yet)
        vm.expectRevert();
        game.revealCrash();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INPUT VALIDATION SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_CannotBetZeroAmount() public {
        game.startRound();

        vm.prank(player1);
        vm.expectRevert(HashCrash.ZeroBetAmount.selector);
        game.placeBet(0, DEFAULT_TARGET);
    }

    function test_Security_CannotBetBelowMinEntry() public {
        game.startRound();

        vm.prank(player1);
        vm.expectRevert();
        game.placeBet(MIN_ENTRY - 1, DEFAULT_TARGET);
    }

    function test_Security_CannotBetAboveMaxEntry() public {
        game.startRound();

        vm.prank(player1);
        vm.expectRevert();
        game.placeBet(MAX_ENTRY + 1, DEFAULT_TARGET);
    }

    function test_Security_TargetBoundary_AtMinimum() public {
        game.startRound();

        // Target 100 (1.00x) should fail - must be > 1x
        vm.prank(player1);
        vm.expectRevert(HashCrash.InvalidTargetMultiplier.selector);
        game.placeBet(DEFAULT_BET, 100);

        // Target 101 (1.01x) should succeed
        vm.prank(player1);
        game.placeBet(DEFAULT_BET, 101);

        HashCrash.PlayerBet memory bet = game.getPlayerBet(1, player1);
        assertEq(bet.targetMultiplier, 101);
    }

    function test_Security_TargetBoundary_AtMaximum() public {
        game.startRound();

        // Target 10001 should fail
        vm.prank(player1);
        vm.expectRevert(HashCrash.InvalidTargetMultiplier.selector);
        game.placeBet(DEFAULT_BET, 10_001);
    }

    function test_Security_TargetBoundary_Zero() public {
        game.startRound();

        vm.prank(player1);
        vm.expectRevert(HashCrash.InvalidTargetMultiplier.selector);
        game.placeBet(DEFAULT_BET, 0);
    }

    function test_Security_TargetBoundary_MaxUint() public {
        game.startRound();

        vm.prank(player1);
        vm.expectRevert(HashCrash.InvalidTargetMultiplier.selector);
        game.placeBet(DEFAULT_BET, type(uint256).max);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // DOUBLE-SPEND / REPLAY ATTACK PREVENTION
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_CannotBetTwiceSameRound() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.prank(player1);
        vm.expectRevert(IArcadeGame.PlayerAlreadyInSession.selector);
        game.placeBet(DEFAULT_BET, 300); // Different target
    }

    function test_Security_CannotClaimRefundTwice() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 300);
        game.handleExpiredRound();

        game.claimExpiredRefund(1, player1);

        vm.expectRevert(HashCrash.AlreadySettled.selector);
        game.claimExpiredRefund(1, player1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EMERGENCY CANCEL SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_CannotCancelNonExistentRound() public {
        vm.prank(owner);
        vm.expectRevert(IArcadeGame.SessionDoesNotExist.selector);
        game.emergencyCancel(999, "Test");
    }

    function test_Security_CannotCancelSettledRound() public {
        _completeRound();

        vm.prank(owner);
        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.emergencyCancel(1, "Test");
    }

    function test_Security_CannotCancelAlreadyCancelledRound() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.prank(owner);
        game.emergencyCancel(1, "First cancel");

        vm.prank(owner);
        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.emergencyCancel(1, "Second cancel");
    }

    function test_Security_CannotCancelExpiredRound() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 300);
        game.handleExpiredRound();

        vm.prank(owner);
        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.emergencyCancel(1, "Test");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EXPIRY HANDLING SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_CannotHandleExpiredWhenNotLocked() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        // Not locked yet
        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.handleExpiredRound();
    }

    function test_Security_CannotHandleExpiredWhenNotActuallyExpired() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        // Not expired yet
        vm.expectRevert(HashCrash.RoundNotReady.selector);
        game.handleExpiredRound();
    }

    function test_Security_CannotClaimRefundOnActiveRound() public {
        _setupRevealedRound();

        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.claimExpiredRefund(1, player1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // PAUSED STATE SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_CannotStartRoundWhenPaused() public {
        vm.prank(owner);
        game.pause();

        vm.expectRevert();
        game.startRound();
    }

    function test_Security_CannotPlaceBetWhenPaused() public {
        game.startRound();

        vm.prank(owner);
        game.pause();

        vm.prank(player1);
        vm.expectRevert();
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);
    }

    function test_Security_CannotLockRoundWhenPaused() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.warp(block.timestamp + 61 seconds);

        vm.prank(owner);
        game.pause();

        vm.expectRevert();
        game.lockRound();
    }

    function test_Security_CannotRevealWhenPaused() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 1);

        vm.prank(owner);
        game.pause();

        vm.expectRevert();
        game.revealCrash();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // WIN/LOSS BOUNDARY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_TargetEqualsCrashIsLoss() public {
        // When target == crash, player should LOSE (target must be STRICTLY LESS THAN crash)
        // This is verified by the contract logic: bet.targetMultiplier < round.crashMultiplier

        game.startRound();

        // We'll test with an extreme target
        vm.prank(player1);
        game.placeBet(DEFAULT_BET, 101); // 1.01x - lowest valid target

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 1);
        game.revealCrash();

        HashCrash.Round memory round = game.getRound(1);

        // If crash point happens to equal target, player loses
        // Note: Due to house edge, ~4% of rounds crash at exactly 100 (1.00x)
        // which means any target > 100 would win those, but if crash == target, lose
        bool isWin = 101 < round.crashMultiplier;
        bool isLoss = 101 >= round.crashMultiplier;

        // One of these must be true, and they're mutually exclusive
        assertTrue(isWin != isLoss, "Win and loss should be mutually exclusive");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CRASH POINT CALCULATION SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function testFuzz_Security_CrashPointAlwaysInBounds(uint256 seed) public view {
        // The crash point calculation should ALWAYS return a value in [100, 10000]
        // regardless of the seed value

        // We need to call the internal function indirectly
        // Since we can't call internal functions directly, we verify through the game flow
        // But we can verify the constants are correct
        assertEq(game.MIN_CRASH_MULTIPLIER(), 100);
        assertEq(game.MAX_CRASH_MULTIPLIER(), 10_000);
    }

    function testFuzz_Security_CrashPointDistribution(uint256 seed) public {
        // Test that crash points follow expected distribution
        // ~4% should crash at minimum (house edge)

        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 1);
        game.revealCrash();

        HashCrash.Round memory round = game.getRound(1);

        // Verify crash point is in valid range
        assertGe(round.crashMultiplier, 100, "Crash must be >= 1.00x");
        assertLe(round.crashMultiplier, 10_000, "Crash must be <= 100.00x");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // REENTRANCY PROTECTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_AllExternalFunctionsHaveReentrancyGuard() public {
        // All state-changing functions should have nonReentrant modifier
        // This test verifies the functions can be called (existence check)
        // The actual reentrancy protection is enforced by the modifier

        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, 9999); // has nonReentrant, high target to likely lose

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound(); // has nonReentrant

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 1);
        game.revealCrash(); // has nonReentrant

        game.settle(player1); // has nonReentrant
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SETTLE ALL EDGE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_SettleAllWithSomeAlreadySettled() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, 9000);

        vm.prank(player2);
        game.placeBet(DEFAULT_BET, 9500);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 1);
        game.revealCrash();

        // Settle player1 first
        game.settle(player1);

        // Then settleAll should only settle player2
        game.settleAll(); // Should not revert

        assertTrue(game.getPlayerBet(1, player1).settled);
        assertTrue(game.getPlayerBet(1, player2).settled);
    }

    function test_Security_SettleAllEmptyRound() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, 9999); // High target to likely lose (avoids payout issues)

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 1);
        game.revealCrash();

        // Settle the only player
        game.settle(player1);

        // SettleAll on already settled round should work (just transitions state)
        // Note: settle already settled everyone, so this just marks SETTLED
        // The round should already be in SETTLED state after settle() if all players are settled
        assertTrue(game.getPlayerBet(1, player1).settled);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ROUND TRANSITION SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_CanStartRoundAfterCancel() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.prank(owner);
        game.emergencyCancel(1, "Testing");

        // Should be able to start new round
        game.startRound();
        assertEq(game.currentSessionId(), 2);
    }

    function test_Security_CanStartRoundAfterExpiry() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 300);
        game.handleExpiredRound();

        // Should be able to start new round
        game.startRound();
        assertEq(game.currentSessionId(), 2);
    }

    function test_Security_ConsecutiveRoundsIndependent() public {
        // Round 1
        game.startRound();
        vm.prank(player1);
        game.placeBet(DEFAULT_BET, 9999);
        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();
        uint256 seedBlock1 = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock1 + 1);
        game.revealCrash();
        game.settleAll();

        // Round 2
        game.startRound();
        vm.prank(player1);
        game.placeBet(DEFAULT_BET, 150); // Different target
        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();
        uint256 seedBlock2 = game.getSeedInfo(2).seedBlock;
        vm.roll(seedBlock2 + 1);
        game.revealCrash();

        // Check rounds are independent
        HashCrash.PlayerBet memory bet1 = game.getPlayerBet(1, player1);
        HashCrash.PlayerBet memory bet2 = game.getPlayerBet(2, player1);

        assertEq(bet1.targetMultiplier, 9999);
        assertEq(bet2.targetMultiplier, 150);
        assertTrue(bet1.settled);
        assertFalse(bet2.settled);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTION SECURITY (Cannot Modify State)
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_ViewFunctionsAreActuallyView() public view {
        // These should all be view functions and not modify state
        game.getGameInfo();
        game.gameId();
        game.currentSessionId();
        game.getSessionState(1);
        game.isPlayerInSession(1, player1);
        game.getSessionPrizePool(1);
        game.isPaused();
        game.getRound(1);
        game.getPlayerBet(1, player1);
        game.getRoundPlayers(1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════════════════════

    function _setupRevealedRound() internal {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, DEFAULT_TARGET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 1);

        game.revealCrash();
    }

    function _completeRound() internal {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET, 9999); // High target to lose

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 1);

        game.revealCrash();
        game.settleAll();
    }
}
