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

/// @title HashCrashTest
/// @notice Comprehensive tests for the HashCrash game
contract HashCrashTest is Test {
    // ══════════════════════════════════════════════════════════════════════════════
    // TEST FIXTURES
    // ══════════════════════════════════════════════════════════════════════════════

    HashCrash public game;
    ArcadeCore public arcadeCore;
    ERC20Mock public dataToken;

    address public owner = makeAddr("owner");
    address public admin = makeAddr("admin");
    address public treasury = makeAddr("treasury");

    address public player1 = makeAddr("player1");
    address public player2 = makeAddr("player2");
    address public player3 = makeAddr("player3");

    uint256 public constant INITIAL_BALANCE = 10_000 ether;
    uint256 public constant DEFAULT_BET = 100 ether;

    // Game config
    uint256 public constant MIN_ENTRY = 1 ether;
    uint256 public constant MAX_ENTRY = 1000 ether;
    uint16 public constant RAKE_BPS = 500; // 5%
    uint16 public constant BURN_BPS = 2000; // 20% of rake

    // ══════════════════════════════════════════════════════════════════════════════
    // SETUP
    // ══════════════════════════════════════════════════════════════════════════════

    function setUp() public {
        vm.startPrank(owner);

        // Deploy token
        dataToken = new ERC20Mock("DATA", "DATA", 18);

        // Deploy ArcadeCore as proxy
        ArcadeCore impl = new ArcadeCore();
        bytes memory initData = abi.encodeCall(
            ArcadeCore.initialize,
            (address(dataToken), address(0), treasury, admin)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        arcadeCore = ArcadeCore(address(proxy));

        // Deploy HashCrash
        game = new HashCrash(address(arcadeCore), owner);

        vm.stopPrank();

        // Register game in ArcadeCore
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

        // Fund players
        _fundPlayer(player1, INITIAL_BALANCE);
        _fundPlayer(player2, INITIAL_BALANCE);
        _fundPlayer(player3, INITIAL_BALANCE);

        // Roll to reasonable block
        vm.roll(1000);
    }

    function _fundPlayer(address player, uint256 amount) internal {
        dataToken.mint(player, amount);
        vm.prank(player);
        // NOTE: Players approve ArcadeCore, not the game contract
        // ArcadeCore.processEntry does the token transfer from player
        dataToken.approve(address(arcadeCore), type(uint256).max);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // GAME INFO TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GameInfo() public view {
        IArcadeTypes.GameInfo memory info = game.getGameInfo();

        assertEq(info.gameId, keccak256("HASH_CRASH"));
        assertEq(info.name, "Hash Crash");
        assertEq(uint8(info.category), uint8(IArcadeTypes.GameCategory.CASINO));
        assertEq(info.minPlayers, 1);
        assertEq(info.maxPlayers, 50);
        assertTrue(info.isActive);
    }

    function test_GameId() public view {
        assertEq(game.gameId(), keccak256("HASH_CRASH"));
    }

    function test_Constants() public view {
        assertEq(game.MULTIPLIER_PRECISION(), 100);
        assertEq(game.MIN_CRASH_MULTIPLIER(), 100);
        assertEq(game.MAX_CRASH_MULTIPLIER(), 10_000);
        assertEq(game.BETTING_DURATION(), 60 seconds);
        assertEq(game.MAX_PLAYERS_PER_ROUND(), 50);
        assertEq(game.HOUSE_EDGE_BPS(), 400);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ROUND LIFECYCLE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_StartRound() public {
        game.startRound();

        assertEq(game.currentSessionId(), 1);

        HashCrash.Round memory round = game.getRound(1);
        assertEq(uint8(round.state), uint8(IArcadeTypes.SessionState.BETTING));
        assertEq(round.prizePool, 0);
        assertEq(round.playerCount, 0);
    }

    function test_StartRound_RevertWhen_RoundInProgress() public {
        game.startRound();

        vm.expectRevert(HashCrash.RoundInProgress.selector);
        game.startRound();
    }

    function test_StartRound_AfterSettled() public {
        // Complete a round first
        _completeRound();

        // Should be able to start new round
        game.startRound();
        assertEq(game.currentSessionId(), 2);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BETTING TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_PlaceBet() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        assertTrue(game.isPlayerInSession(1, player1));

        HashCrash.PlayerBet memory bet = game.getPlayerBet(1, player1);
        // Net amount is 95% of bet (5% rake)
        assertEq(bet.amount, DEFAULT_BET * 95 / 100);
        assertEq(bet.grossAmount, DEFAULT_BET);
        assertEq(bet.cashedOutAt, 0);
        assertFalse(bet.resolved);
    }

    function test_PlaceBet_MultiplePlayers() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.prank(player2);
        game.placeBet(DEFAULT_BET * 2);

        vm.prank(player3);
        game.placeBet(DEFAULT_BET / 2);

        HashCrash.Round memory round = game.getRound(1);
        assertEq(round.playerCount, 3);

        // Prize pool should be sum of net bets
        uint256 expectedPool = (DEFAULT_BET * 95 / 100)
            + (DEFAULT_BET * 2 * 95 / 100)
            + (DEFAULT_BET / 2 * 95 / 100);
        assertEq(round.prizePool, expectedPool);
    }

    function test_PlaceBet_RevertWhen_NotBetting() public {
        // No round started
        vm.prank(player1);
        vm.expectRevert(HashCrash.BettingClosed.selector);
        game.placeBet(DEFAULT_BET);
    }

    function test_PlaceBet_RevertWhen_BettingEnded() public {
        game.startRound();

        // Skip past betting window
        vm.warp(block.timestamp + 61 seconds);

        vm.prank(player1);
        vm.expectRevert(HashCrash.BettingClosed.selector);
        game.placeBet(DEFAULT_BET);
    }

    function test_PlaceBet_RevertWhen_AlreadyBet() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.prank(player1);
        vm.expectRevert(IArcadeGame.PlayerAlreadyInSession.selector);
        game.placeBet(DEFAULT_BET);
    }

    function test_PlaceBet_RevertWhen_ZeroAmount() public {
        game.startRound();

        vm.prank(player1);
        vm.expectRevert(HashCrash.ZeroBetAmount.selector);
        game.placeBet(0);
    }

    function test_PlaceBet_AutoLock_WhenFull() public {
        game.startRound();

        // Fill to max players
        for (uint256 i = 0; i < 50; i++) {
            address player = makeAddr(string(abi.encodePacked("player", i)));
            _fundPlayer(player, INITIAL_BALANCE);

            vm.prank(player);
            game.placeBet(MIN_ENTRY);
        }

        // Round should now be locked
        HashCrash.Round memory round = game.getRound(1);
        assertEq(uint8(round.state), uint8(IArcadeTypes.SessionState.LOCKED));
    }

    function test_PlaceBet_RevertWhen_RoundFull() public {
        game.startRound();

        // Fill to max players
        for (uint256 i = 0; i < 50; i++) {
            address player = makeAddr(string(abi.encodePacked("player", i)));
            _fundPlayer(player, INITIAL_BALANCE);

            vm.prank(player);
            game.placeBet(MIN_ENTRY);
        }

        // Try to add one more
        vm.prank(player1);
        vm.expectRevert(HashCrash.BettingClosed.selector);
        game.placeBet(MIN_ENTRY);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // LOCK ROUND TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_LockRound() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        // Skip to end of betting
        vm.warp(block.timestamp + 61 seconds);

        game.lockRound();

        HashCrash.Round memory round = game.getRound(1);
        assertEq(uint8(round.state), uint8(IArcadeTypes.SessionState.LOCKED));
    }

    function test_LockRound_CancelsWhenNoBets() public {
        game.startRound();

        // Skip to end of betting without any bets
        vm.warp(block.timestamp + 61 seconds);

        game.lockRound();

        HashCrash.Round memory round = game.getRound(1);
        assertEq(uint8(round.state), uint8(IArcadeTypes.SessionState.CANCELLED));
    }

    function test_LockRound_RevertWhen_BettingNotEnded() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.expectRevert(HashCrash.BettingNotEnded.selector);
        game.lockRound();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // REVEAL CRASH TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_RevealCrash() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        // Roll past seed block
        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 1);

        game.revealCrash();

        HashCrash.Round memory round = game.getRound(1);
        assertEq(uint8(round.state), uint8(IArcadeTypes.SessionState.ACTIVE));
        assertTrue(round.crashMultiplier >= 100, "Crash point should be at least 1.00x");
        assertTrue(round.crashMultiplier <= 10_000, "Crash point should be at most 100.00x");
    }

    function test_RevealCrash_RevertWhen_NotLocked() public {
        game.startRound();

        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.revealCrash();
    }

    function test_RevealCrash_RevertWhen_SeedNotReady() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        // Don't roll forward enough
        vm.expectRevert();
        game.revealCrash();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CASHOUT TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_CashOut() public {
        _setupActiveRound();

        HashCrash.Round memory round = game.getRound(1);

        // Cash out at a safe multiplier (below crash point)
        uint256 cashoutMultiplier = 150; // 1.50x
        if (cashoutMultiplier < round.crashMultiplier) {
            vm.prank(player1);
            game.cashOut(cashoutMultiplier);

            HashCrash.PlayerBet memory bet = game.getPlayerBet(1, player1);
            assertEq(bet.cashedOutAt, cashoutMultiplier);
            assertTrue(bet.resolved);

            // Check pending payout
            uint256 expectedPayout = (DEFAULT_BET * 95 / 100) * cashoutMultiplier / 100;
            assertGt(arcadeCore.getPendingPayout(player1), 0);
        }
    }

    function test_CashOut_RevertWhen_NotActive() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.prank(player1);
        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.cashOut(150);
    }

    function test_CashOut_RevertWhen_NoBet() public {
        _setupActiveRound();

        address newPlayer = makeAddr("newPlayer");
        vm.prank(newPlayer);
        vm.expectRevert(HashCrash.NoBetPlaced.selector);
        game.cashOut(150);
    }

    function test_CashOut_RevertWhen_AlreadyCashedOut() public {
        _setupActiveRound();

        HashCrash.Round memory round = game.getRound(1);
        uint256 cashoutMultiplier = 120;

        if (cashoutMultiplier < round.crashMultiplier) {
            vm.prank(player1);
            game.cashOut(cashoutMultiplier);

            vm.prank(player1);
            vm.expectRevert(HashCrash.AlreadyCashedOut.selector);
            game.cashOut(cashoutMultiplier);
        }
    }

    function test_CashOut_RevertWhen_AboveCrashPoint() public {
        _setupActiveRound();

        HashCrash.Round memory round = game.getRound(1);

        // Try to cash out above crash point
        uint256 cashoutMultiplier = round.crashMultiplier + 100;

        vm.prank(player1);
        vm.expectRevert(HashCrash.AlreadyCrashed.selector);
        game.cashOut(cashoutMultiplier);
    }

    function test_CashOut_RevertWhen_BelowMinimum() public {
        _setupActiveRound();

        vm.prank(player1);
        vm.expectRevert(HashCrash.InvalidCashoutMultiplier.selector);
        game.cashOut(50); // Below 1.00x
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // RESOLVE ROUND TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_ResolveRound() public {
        _setupActiveRound();

        game.resolveRound();

        HashCrash.Round memory round = game.getRound(1);
        assertEq(uint8(round.state), uint8(IArcadeTypes.SessionState.SETTLED));

        // Player should have crashed (didn't cash out)
        HashCrash.PlayerBet memory bet = game.getPlayerBet(1, player1);
        assertTrue(bet.resolved);
    }

    function test_ResolveRound_WithCashout() public {
        _setupActiveRound();

        HashCrash.Round memory round = game.getRound(1);

        // Cash out if possible
        if (round.crashMultiplier > 110) {
            vm.prank(player1);
            game.cashOut(110);
        }

        game.resolveRound();

        HashCrash.Round memory finalRound = game.getRound(1);
        assertEq(uint8(finalRound.state), uint8(IArcadeTypes.SessionState.SETTLED));
    }

    function test_ResolveRound_RevertWhen_NotActive() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.resolveRound();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EXPIRY & REFUND TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_HandleExpiredRound() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        // Roll way past the window
        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 300);

        game.handleExpiredRound();

        HashCrash.Round memory round = game.getRound(1);
        assertEq(uint8(round.state), uint8(IArcadeTypes.SessionState.EXPIRED));
    }

    function test_ClaimExpiredRefund() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        // Roll way past the window
        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 300);

        game.handleExpiredRound();

        // Claim refund
        game.claimExpiredRefund(1, player1);

        // Check player was refunded (NET amount - after rake)
        // Rake is 5%, so net = 95% of gross
        uint256 expectedNet = DEFAULT_BET * 95 / 100;
        uint256 pending = arcadeCore.getPendingPayout(player1);
        assertEq(pending, expectedNet, "Should refund net amount after rake");
    }

    function test_ClaimExpiredRefund_RevertWhen_NotExpired() public {
        _setupActiveRound();

        vm.expectRevert(IArcadeGame.InvalidSessionState.selector);
        game.claimExpiredRefund(1, player1);
    }

    function test_ClaimExpiredRefund_RevertWhen_NoBet() public {
        game.startRound();

        // Player2 bets so round doesn't auto-cancel
        vm.prank(player2);
        game.placeBet(DEFAULT_BET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 300);
        game.handleExpiredRound();

        // Player1 never bet, should revert
        vm.expectRevert(HashCrash.NoBetPlaced.selector);
        game.claimExpiredRefund(1, player1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Pause() public {
        vm.prank(owner);
        game.pause();

        assertTrue(game.isPaused());
    }

    function test_Unpause() public {
        vm.prank(owner);
        game.pause();

        vm.prank(owner);
        game.unpause();

        assertFalse(game.isPaused());
    }

    function test_Pause_RevertWhen_NotOwner() public {
        vm.prank(player1);
        vm.expectRevert();
        game.pause();
    }

    function test_PlaceBet_RevertWhen_Paused() public {
        game.startRound();

        vm.prank(owner);
        game.pause();

        vm.prank(player1);
        vm.expectRevert();
        game.placeBet(DEFAULT_BET);
    }

    function test_EmergencyCancel() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.prank(owner);
        game.emergencyCancel(1, "Testing");

        HashCrash.Round memory round = game.getRound(1);
        assertEq(uint8(round.state), uint8(IArcadeTypes.SessionState.CANCELLED));
    }

    function test_EmergencyCancel_RevertWhen_NotOwner() public {
        game.startRound();

        vm.prank(player1);
        vm.expectRevert();
        game.emergencyCancel(1, "Testing");
    }

    function test_SetActive() public {
        vm.prank(owner);
        game.setActive(false);

        IArcadeTypes.GameInfo memory info = game.getGameInfo();
        assertFalse(info.isActive);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetRoundPlayers() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.prank(player2);
        game.placeBet(DEFAULT_BET);

        address[] memory players = game.getRoundPlayers(1);
        assertEq(players.length, 2);
        assertEq(players[0], player1);
        assertEq(players[1], player2);
    }

    function test_IsSeedReady() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        assertFalse(game.isSeedReady(1));

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 1);

        assertTrue(game.isSeedReady(1));
    }

    function test_IsSeedExpired() public {
        game.startRound();

        vm.prank(player1);
        game.placeBet(DEFAULT_BET);

        vm.warp(block.timestamp + 61 seconds);
        game.lockRound();

        assertFalse(game.isSeedExpired(1));

        uint256 seedBlock = game.getSeedInfo(1).seedBlock;
        vm.roll(seedBlock + 300);

        assertTrue(game.isSeedExpired(1));
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

    function _completeRound() internal {
        _setupActiveRound();
        game.resolveRound();
    }
}
