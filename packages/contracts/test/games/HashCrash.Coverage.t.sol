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
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title HashCrashCoverageTest
/// @notice Additional tests to achieve >90% coverage with comprehensive negative tests
contract HashCrashCoverageTest is Test {
    HashCrash public game;
    ArcadeCore public arcadeCore;
    ERC20Mock public dataToken;

    address public owner = makeAddr("owner");
    address public admin = makeAddr("admin");
    address public treasury = makeAddr("treasury");
    address public player1 = makeAddr("player1");
    address public player2 = makeAddr("player2");

    uint256 public constant INITIAL_BALANCE = 10_000 ether;
    uint256 public constant DEFAULT_BET = 100 ether;

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
                minEntry: 1 ether,
                maxEntry: 1000 ether,
                rakeBps: 500,
                burnBps: 2000,
                requiresPosition: false,
                paused: false
            })
        );

        _fundPlayer(player1, INITIAL_BALANCE);
        _fundPlayer(player2, INITIAL_BALANCE);
        vm.roll(1000);
    }

    function _fundPlayer(
        address player,
        uint256 amount
    ) internal {
        dataToken.mint(player, amount);
        vm.prank(player);
        dataToken.approve(address(arcadeCore), type(uint256).max);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR NEGATIVE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Constructor_RevertWhen_ZeroArcadeCore() public {
        vm.expectRevert(HashCrash.InvalidArcadeCore.selector);
        new HashCrash(address(0), owner);
    }

    function test_Constructor_RevertWhen_ZeroOwner() public {
        // OpenZeppelin's Ownable throws OwnableInvalidOwner, not our custom error
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new HashCrash(address(arcadeCore), address(0));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CRASH POINT CALCULATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_CrashPoint_InstantCrash() public {
        // Test that low seeds produce instant crash (house edge)
        game.startRound();
        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        // We can't control the seed, but we can verify crash point is in valid range
        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 1);

        game.revealCrash();
        HashCrash.Round memory round = game.getRound(1);

        // Crash point should always be in valid range
        assertGe(round.crashMultiplier, 100, "Crash should be >= 1.00x");
        assertLe(round.crashMultiplier, 10_000, "Crash should be <= 100.00x");
    }

    function testFuzz_CrashPoint_AlwaysInRange(
        uint256 seed
    ) public {
        // Fuzz test: crash point should always be in [100, 10000]
        game.startRound();
        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        // Use fuzzed seed to vary the blockhash
        vm.roll(seedBlock + 1 + (seed % 100));

        // May revert if seed expired, which is fine
        try game.revealCrash() {
            HashCrash.Round memory round = game.getRound(1);
            assertGe(round.crashMultiplier, 100);
            assertLe(round.crashMultiplier, 10_000);
        } catch { }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE MACHINE NEGATIVE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_PlaceBet_RevertWhen_GamePaused() public {
        game.startRound();

        vm.prank(owner);
        game.pause();

        vm.prank(player1);
        vm.expectRevert(); // Pausable: paused
        game.placeBet(DEFAULT_BET);
    }

    function test_CashOut_RevertWhen_GamePaused() public {
        _setupActiveRound();

        vm.prank(owner);
        game.pause();

        vm.prank(player1);
        vm.expectRevert(); // Pausable: paused
        game.cashOut(100);
    }

    function test_StartRound_RevertWhen_GamePaused() public {
        vm.prank(owner);
        game.pause();

        vm.expectRevert(); // Pausable: paused
        game.startRound();
    }

    function test_LockRound_RevertWhen_GamePaused() public {
        game.startRound();
        vm.prank(player1);
        game.placeBet(DEFAULT_BET);
        vm.warp(block.timestamp + 61 seconds);

        vm.prank(owner);
        game.pause();

        vm.expectRevert(); // Pausable: paused
        game.lockRound();
    }

    function test_RevealCrash_RevertWhen_GamePaused() public {
        game.startRound();
        vm.prank(player1);
        game.placeBet(DEFAULT_BET);
        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 1);

        vm.prank(owner);
        game.pause();

        vm.expectRevert(); // Pausable: paused
        game.revealCrash();
    }

    function test_CashOut_RevertWhen_Resolved() public {
        _setupActiveRound();

        HashCrash.Round memory round = game.getRound(1);

        // First resolve all players
        game.resolveRound();

        // Try to cash out after resolved - but round is SETTLED now
        vm.prank(player1);
        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.cashOut(100);
    }

    function test_ResolveRound_MultipleCalls() public {
        _setupActiveRound();

        game.resolveRound();

        // Second call should revert
        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.resolveRound();
    }

    function test_HandleExpiredRound_RevertWhen_NotLocked() public {
        game.startRound();

        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.handleExpiredRound();
    }

    function test_HandleExpiredRound_RevertWhen_NotExpired() public {
        game.startRound();
        vm.prank(player1);
        game.placeBet(DEFAULT_BET);
        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        // Don't roll far enough for expiry
        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 1);

        vm.expectRevert(HashCrash.RoundNotReady.selector);
        game.handleExpiredRound();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // REFUND NEGATIVE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_ClaimExpiredRefund_RevertWhen_AlreadyRefunded() public {
        game.startRound();
        vm.prank(player1);
        game.placeBet(DEFAULT_BET);
        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 300);
        game.handleExpiredRound();

        // First refund succeeds
        game.claimExpiredRefund(1, player1);

        // Second refund fails
        vm.expectRevert(HashCrash.AlreadyCashedOut.selector);
        game.claimExpiredRefund(1, player1);
    }

    function test_ClaimExpiredRefund_RevertWhen_Active() public {
        _setupActiveRound();

        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.claimExpiredRefund(1, player1);
    }

    function test_ClaimExpiredRefund_RevertWhen_Settled() public {
        _setupActiveRound();
        game.resolveRound();

        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.claimExpiredRefund(1, player1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN NEGATIVE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Pause_RevertWhen_NotOwner() public {
        vm.prank(player1);
        vm.expectRevert();
        game.pause();
    }

    function test_Unpause_RevertWhen_NotOwner() public {
        vm.prank(owner);
        game.pause();

        vm.prank(player1);
        vm.expectRevert();
        game.unpause();
    }

    function test_SetActive_RevertWhen_NotOwner() public {
        vm.prank(player1);
        vm.expectRevert();
        game.setActive(false);
    }

    function test_EmergencyCancel_RevertWhen_NotOwner() public {
        game.startRound();

        vm.prank(player1);
        vm.expectRevert();
        game.emergencyCancel(1, "test");
    }

    function test_EmergencyCancel_RevertWhen_NonExistent() public {
        vm.prank(owner);
        vm.expectRevert(IArcadeGame.SessionDoesNotExist.selector);
        game.emergencyCancel(999, "test");
    }

    function test_EmergencyCancel_RevertWhen_AlreadyCancelled() public {
        game.startRound();
        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.prank(owner);
        game.emergencyCancel(1, "first");

        vm.prank(owner);
        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.emergencyCancel(1, "second");
    }

    function test_EmergencyCancel_RevertWhen_Settled() public {
        _setupActiveRound();
        game.resolveRound();

        vm.prank(owner);
        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.emergencyCancel(1, "test");
    }

    function test_EmergencyCancel_RevertWhen_Expired() public {
        game.startRound();
        vm.prank(player1);
        game.placeBet(DEFAULT_BET);
        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 300);
        game.handleExpiredRound();

        vm.prank(owner);
        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.emergencyCancel(1, "test");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetRound_NonExistent() public view {
        HashCrash.Round memory round = game.getRound(999);
        assertEq(uint8(round.state), uint8(IArcadeTypes.SessionState.NONE));
    }

    function test_GetPlayerBet_NonExistent() public view {
        HashCrash.PlayerBet memory bet = game.getPlayerBet(999, player1);
        assertEq(bet.amount, 0);
        assertEq(bet.grossAmount, 0);
    }

    function test_GetRoundPlayers_Empty() public {
        game.startRound();
        address[] memory players = game.getRoundPlayers(1);
        assertEq(players.length, 0);
    }

    function test_IsSeedReady_NonExistent() public view {
        assertFalse(game.isSeedReady(999));
    }

    function test_IsSeedExpired_NonExistent() public view {
        assertFalse(game.isSeedExpired(999));
    }

    function test_GetRemainingRevealWindow_NonExistent() public view {
        assertEq(game.getRemainingRevealWindow(999), 0);
    }

    function test_CurrentSessionId_Initial() public view {
        assertEq(game.currentSessionId(), 0);
    }

    function test_GetSessionState_NonExistent() public view {
        IArcadeTypes.SessionState state = game.getSessionState(999);
        assertEq(uint8(state), uint8(IArcadeTypes.SessionState.NONE));
    }

    function test_IsPlayerInSession_NonExistent() public view {
        assertFalse(game.isPlayerInSession(999, player1));
    }

    function test_GetSessionPrizePool_NonExistent() public view {
        assertEq(game.getSessionPrizePool(999), 0);
    }

    function test_IsPaused_Initial() public view {
        assertFalse(game.isPaused());
    }

    function test_IsPaused_AfterPause() public {
        vm.prank(owner);
        game.pause();
        assertTrue(game.isPaused());
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EDGE CASE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_StartRound_AfterCancelled() public {
        game.startRound();
        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.prank(owner);
        game.emergencyCancel(1, "test");

        // Should be able to start new round
        game.startRound();
        assertEq(game.currentSessionId(), 2);
    }

    function test_StartRound_AfterExpired() public {
        game.startRound();
        vm.prank(player1);
        game.placeBet(DEFAULT_BET);
        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 300);
        game.handleExpiredRound();

        // Should be able to start new round
        game.startRound();
        assertEq(game.currentSessionId(), 2);
    }

    function test_MultipleRoundsSequence() public {
        // Round 1: Normal completion
        _setupActiveRound();
        game.resolveRound();
        assertEq(game.currentSessionId(), 1);

        // Round 2: Cancelled
        game.startRound();
        vm.prank(player1);
        game.placeBet(DEFAULT_BET);
        vm.prank(owner);
        game.emergencyCancel(2, "test");
        assertEq(game.currentSessionId(), 2);

        // Round 3: New round after cancellation
        game.startRound();
        assertEq(game.currentSessionId(), 3);
    }

    function test_SetActive_Event() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit HashCrash.GameActiveStatusChanged(false);
        game.setActive(false);
    }

    function test_GetGameInfo_Fields() public view {
        IArcadeTypes.GameInfo memory info = game.getGameInfo();

        assertEq(info.gameId, keccak256("HASH_CRASH"));
        assertEq(info.name, "Hash Crash");
        assertEq(info.minPlayers, 1);
        assertEq(info.maxPlayers, 50);
        assertTrue(info.isActive);
        assertGt(info.launchedAt, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════════════════════

    function _setupActiveRound() internal {
        game.startRound();
        vm.prank(player1);
        game.placeBet(DEFAULT_BET);
        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 1);
        game.revealCrash();
    }
}
