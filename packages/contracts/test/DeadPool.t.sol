// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { DataToken } from "../src/token/DataToken.sol";
import { DeadPool } from "../src/markets/DeadPool.sol";
import { IDeadPool } from "../src/markets/interfaces/IDeadPool.sol";
import { IGhostCore } from "../src/core/interfaces/IGhostCore.sol";

/// @title DeadPool Tests
/// @notice Tests for the GHOSTNET prediction market
contract DeadPoolTest is Test {
    DataToken public token;
    DeadPool public deadPool;

    address public treasury = makeAddr("treasury");
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");
    address public resolver = makeAddr("resolver");

    uint256 constant TOTAL_SUPPLY = 100_000_000 * 1e18;
    uint256 constant USER_BALANCE = 10_000_000 * 1e18;

    function setUp() public {
        // Deploy token
        address[] memory recipients = new address[](4);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = carol;
        recipients[3] = treasury;

        uint256[] memory amounts = new uint256[](4);
        amounts[0] = USER_BALANCE;
        amounts[1] = USER_BALANCE;
        amounts[2] = USER_BALANCE;
        amounts[3] = TOTAL_SUPPLY - (USER_BALANCE * 3);

        token = new DataToken(treasury, owner, recipients, amounts);

        // Deploy DeadPool
        DeadPool deadPoolImpl = new DeadPool();
        bytes memory initData = abi.encodeCall(DeadPool.initialize, (address(token), owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(deadPoolImpl), initData);
        deadPool = DeadPool(address(proxy));

        // Setup roles
        vm.startPrank(owner);
        token.setTaxExclusion(address(deadPool), true);
        deadPool.grantRole(deadPool.RESOLVER_ROLE(), resolver);
        vm.stopPrank();

        // Approve tokens
        vm.prank(alice);
        token.approve(address(deadPool), type(uint256).max);
        vm.prank(bob);
        token.approve(address(deadPool), type(uint256).max);
        vm.prank(carol);
        token.approve(address(deadPool), type(uint256).max);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ROUND CREATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_CreateRound_Success() public {
        uint64 deadline = uint64(block.timestamp + 1 hours);

        vm.prank(owner);
        uint256 roundId = deadPool.createRound(
            IDeadPool.RoundType.DEATH_COUNT, IGhostCore.Level.VAULT, 50, deadline
        );

        assertEq(roundId, 1);
        assertEq(deadPool.roundCount(), 1);

        IDeadPool.Round memory round = deadPool.getRound(roundId);
        assertEq(uint8(round.roundType), uint8(IDeadPool.RoundType.DEATH_COUNT));
        assertEq(uint8(round.targetLevel), uint8(IGhostCore.Level.VAULT));
        assertEq(round.line, 50);
        assertEq(round.deadline, deadline);
        assertFalse(round.resolved);
    }

    function test_CreateRound_EmitsEvent() public {
        uint64 deadline = uint64(block.timestamp + 1 hours);

        vm.expectEmit(true, true, true, true);
        emit IDeadPool.RoundCreated(
            1, IDeadPool.RoundType.DEATH_COUNT, IGhostCore.Level.VAULT, 50, deadline
        );

        vm.prank(owner);
        deadPool.createRound(IDeadPool.RoundType.DEATH_COUNT, IGhostCore.Level.VAULT, 50, deadline);
    }

    function test_CreateRound_RevertWhen_NotCreator() public {
        vm.prank(alice);
        vm.expectRevert();
        deadPool.createRound(
            IDeadPool.RoundType.DEATH_COUNT,
            IGhostCore.Level.VAULT,
            50,
            uint64(block.timestamp + 1 hours)
        );
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BET PLACEMENT TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_PlaceBet_Success() public {
        _createRound();
        uint256 betAmount = 100 * 1e18;

        vm.prank(alice);
        deadPool.placeBet(1, true, betAmount); // Bet OVER

        IDeadPool.Bet memory bet = deadPool.getBet(1, alice);
        assertEq(bet.amount, betAmount);
        assertTrue(bet.isOver);
        assertFalse(bet.claimed);

        IDeadPool.Round memory round = deadPool.getRound(1);
        assertEq(round.overPool, betAmount);
        assertEq(round.underPool, 0);
    }

    function test_PlaceBet_EmitsEvent() public {
        _createRound();
        uint256 betAmount = 100 * 1e18;

        vm.expectEmit(true, true, true, true);
        emit IDeadPool.BetPlaced(1, alice, true, betAmount);

        vm.prank(alice);
        deadPool.placeBet(1, true, betAmount);
    }

    function test_PlaceBet_MultipleBets() public {
        _createRound();

        vm.prank(alice);
        deadPool.placeBet(1, true, 100 * 1e18); // OVER

        vm.prank(bob);
        deadPool.placeBet(1, false, 200 * 1e18); // UNDER

        IDeadPool.Round memory round = deadPool.getRound(1);
        assertEq(round.overPool, 100 * 1e18);
        assertEq(round.underPool, 200 * 1e18);
    }

    function test_PlaceBet_CanAddToSameSide() public {
        _createRound();

        vm.startPrank(alice);
        deadPool.placeBet(1, true, 100 * 1e18);
        deadPool.placeBet(1, true, 50 * 1e18);
        vm.stopPrank();

        IDeadPool.Bet memory bet = deadPool.getBet(1, alice);
        assertEq(bet.amount, 150 * 1e18);
    }

    function test_PlaceBet_RevertWhen_RoundEnded() public {
        _createRound();

        vm.warp(block.timestamp + 2 hours); // Past deadline

        vm.prank(alice);
        vm.expectRevert(IDeadPool.RoundEnded.selector);
        deadPool.placeBet(1, true, 100 * 1e18);
    }

    function test_PlaceBet_RevertWhen_ZeroAmount() public {
        _createRound();

        vm.prank(alice);
        vm.expectRevert(IDeadPool.InvalidAmount.selector);
        deadPool.placeBet(1, true, 0);
    }

    function test_PlaceBet_RevertWhen_RoundNotFound() public {
        vm.prank(alice);
        vm.expectRevert(IDeadPool.RoundNotFound.selector);
        deadPool.placeBet(999, true, 100 * 1e18);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // RESOLUTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_ResolveRound_Success() public {
        _createRound();

        vm.prank(alice);
        deadPool.placeBet(1, true, 100 * 1e18);

        vm.prank(bob);
        deadPool.placeBet(1, false, 100 * 1e18);

        vm.warp(block.timestamp + 2 hours);

        uint256 deadBefore = token.balanceOf(token.DEAD_ADDRESS());

        vm.prank(resolver);
        deadPool.resolveRound(1, true); // OVER wins

        IDeadPool.Round memory round = deadPool.getRound(1);
        assertTrue(round.resolved);
        assertTrue(round.outcome);

        // 5% rake should be burned
        uint256 totalPot = 200 * 1e18;
        uint256 expectedRake = (totalPot * 500) / 10_000;
        assertEq(token.balanceOf(token.DEAD_ADDRESS()) - deadBefore, expectedRake);
    }

    function test_ResolveRound_EmitsEvent() public {
        _createRound();

        vm.prank(alice);
        deadPool.placeBet(1, true, 100 * 1e18);

        vm.prank(bob);
        deadPool.placeBet(1, false, 100 * 1e18);

        vm.warp(block.timestamp + 2 hours);

        uint256 totalPot = 200 * 1e18;
        uint256 rake = (totalPot * 500) / 10_000;

        vm.expectEmit(true, true, true, true);
        emit IDeadPool.RoundResolved(1, true, totalPot, rake);

        vm.prank(resolver);
        deadPool.resolveRound(1, true);
    }

    function test_ResolveRound_RevertWhen_NotEnded() public {
        _createRound();

        vm.prank(resolver);
        vm.expectRevert(IDeadPool.RoundNotEnded.selector);
        deadPool.resolveRound(1, true);
    }

    function test_ResolveRound_RevertWhen_AlreadyResolved() public {
        _createRound();

        vm.warp(block.timestamp + 2 hours);

        vm.prank(resolver);
        deadPool.resolveRound(1, true);

        vm.prank(resolver);
        vm.expectRevert(IDeadPool.RoundAlreadyResolved.selector);
        deadPool.resolveRound(1, false);
    }

    function test_ResolveRound_RevertWhen_NotResolver() public {
        _createRound();

        vm.warp(block.timestamp + 2 hours);

        vm.prank(alice);
        vm.expectRevert();
        deadPool.resolveRound(1, true);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CLAIM WINNINGS TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_ClaimWinnings_Success() public {
        _createRound();

        vm.prank(alice);
        deadPool.placeBet(1, true, 100 * 1e18); // OVER

        vm.prank(bob);
        deadPool.placeBet(1, false, 100 * 1e18); // UNDER

        vm.warp(block.timestamp + 2 hours);

        vm.prank(resolver);
        deadPool.resolveRound(1, true); // OVER wins

        uint256 balanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        uint256 winnings = deadPool.claimWinnings(1);

        // Total pot = 200, rake = 10 (5%), net = 190
        // Alice bet 100 on winning side of 100, gets all 190
        uint256 expectedWinnings = 190 * 1e18;
        assertEq(winnings, expectedWinnings);
        assertEq(token.balanceOf(alice) - balanceBefore, expectedWinnings);
    }

    function test_ClaimWinnings_EmitsEvent() public {
        _createRound();

        vm.prank(alice);
        deadPool.placeBet(1, true, 100 * 1e18);

        vm.prank(bob);
        deadPool.placeBet(1, false, 100 * 1e18);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(resolver);
        deadPool.resolveRound(1, true);

        uint256 expectedWinnings = 190 * 1e18;

        vm.expectEmit(true, true, true, true);
        emit IDeadPool.WinningsClaimed(1, alice, expectedWinnings);

        vm.prank(alice);
        deadPool.claimWinnings(1);
    }

    function test_ClaimWinnings_ProportionalSplit() public {
        _createRound();

        // Alice bets 100 OVER, Bob bets 50 OVER, Carol bets 150 UNDER
        vm.prank(alice);
        deadPool.placeBet(1, true, 100 * 1e18);

        vm.prank(bob);
        deadPool.placeBet(1, true, 50 * 1e18);

        vm.prank(carol);
        deadPool.placeBet(1, false, 150 * 1e18);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(resolver);
        deadPool.resolveRound(1, true); // OVER wins

        // Total pot = 300, rake = 15 (5%), net = 285
        // OVER pool = 150, so alice gets 100/150 * 285 = 190
        // Bob gets 50/150 * 285 = 95

        vm.prank(alice);
        uint256 aliceWinnings = deadPool.claimWinnings(1);
        assertEq(aliceWinnings, 190 * 1e18);

        vm.prank(bob);
        uint256 bobWinnings = deadPool.claimWinnings(1);
        assertEq(bobWinnings, 95 * 1e18);
    }

    function test_ClaimWinnings_RevertWhen_NotResolved() public {
        _createRound();

        vm.prank(alice);
        deadPool.placeBet(1, true, 100 * 1e18);

        vm.prank(alice);
        vm.expectRevert(IDeadPool.RoundNotResolved.selector);
        deadPool.claimWinnings(1);
    }

    function test_ClaimWinnings_RevertWhen_NoBet() public {
        _createRound();

        vm.warp(block.timestamp + 2 hours);

        vm.prank(resolver);
        deadPool.resolveRound(1, true);

        vm.prank(alice);
        vm.expectRevert(IDeadPool.NoBetExists.selector);
        deadPool.claimWinnings(1);
    }

    function test_ClaimWinnings_RevertWhen_NotWinner() public {
        _createRound();

        vm.prank(alice);
        deadPool.placeBet(1, false, 100 * 1e18); // UNDER

        vm.warp(block.timestamp + 2 hours);

        vm.prank(resolver);
        deadPool.resolveRound(1, true); // OVER wins

        vm.prank(alice);
        vm.expectRevert(IDeadPool.NotWinner.selector);
        deadPool.claimWinnings(1);
    }

    function test_ClaimWinnings_RevertWhen_AlreadyClaimed() public {
        _createRound();

        vm.prank(alice);
        deadPool.placeBet(1, true, 100 * 1e18);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(resolver);
        deadPool.resolveRound(1, true);

        vm.prank(alice);
        deadPool.claimWinnings(1);

        vm.prank(alice);
        vm.expectRevert(IDeadPool.AlreadyClaimed.selector);
        deadPool.claimWinnings(1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ODDS CALCULATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetOverOdds() public {
        _createRound();

        vm.prank(alice);
        deadPool.placeBet(1, true, 100 * 1e18);

        vm.prank(bob);
        deadPool.placeBet(1, false, 100 * 1e18);

        // Total = 200, net = 190 (after 5% rake)
        // OVER pool = 100
        // Odds = 190 / 100 = 1.9x = 19000 bps
        uint16 odds = deadPool.getOverOdds(1);
        assertEq(odds, 19_000);
    }

    function test_GetUnderOdds() public {
        _createRound();

        vm.prank(alice);
        deadPool.placeBet(1, true, 50 * 1e18);

        vm.prank(bob);
        deadPool.placeBet(1, false, 150 * 1e18);

        // Total = 200, net = 190
        // UNDER pool = 150
        // Odds = 190 / 150 = 1.267x = 12666 bps
        uint16 odds = deadPool.getUnderOdds(1);
        assertEq(odds, 12_666);
    }

    function test_CalculateWinnings_View() public {
        _createRound();

        vm.prank(alice);
        deadPool.placeBet(1, true, 100 * 1e18);

        vm.prank(bob);
        deadPool.placeBet(1, false, 100 * 1e18);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(resolver);
        deadPool.resolveRound(1, true);

        uint256 winnings = deadPool.calculateWinnings(1, alice);
        assertEq(winnings, 190 * 1e18);

        // Bob lost, should get 0
        winnings = deadPool.calculateWinnings(1, bob);
        assertEq(winnings, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EDGE CASE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_PlaceBet_RevertWhen_SwitchingSides() public {
        _createRound();

        // First bet on OVER
        vm.prank(alice);
        deadPool.placeBet(1, true, 100 * 1e18);

        // Try to switch to UNDER
        vm.prank(alice);
        vm.expectRevert(IDeadPool.InvalidAmount.selector);
        deadPool.placeBet(1, false, 50 * 1e18);
    }

    function test_PlaceBet_RevertWhen_Paused() public {
        _createRound();

        vm.prank(owner);
        deadPool.pause();

        vm.prank(alice);
        vm.expectRevert();
        deadPool.placeBet(1, true, 100 * 1e18);
    }

    function test_ClaimWinnings_RevertWhen_Paused() public {
        _createRound();

        vm.prank(alice);
        deadPool.placeBet(1, true, 100 * 1e18);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(resolver);
        deadPool.resolveRound(1, true);

        vm.prank(owner);
        deadPool.pause();

        vm.prank(alice);
        vm.expectRevert();
        deadPool.claimWinnings(1);
    }

    function test_ResolveRound_RevertWhen_RoundNotFound() public {
        vm.prank(resolver);
        vm.expectRevert(IDeadPool.RoundNotFound.selector);
        deadPool.resolveRound(999, true);
    }

    function test_ResolveRound_ZeroRake() public {
        // Create round but don't place any bets
        _createRound();

        vm.warp(block.timestamp + 2 hours);

        uint256 deadBefore = token.balanceOf(token.DEAD_ADDRESS());

        vm.prank(resolver);
        deadPool.resolveRound(1, true);

        // No rake burned since no bets
        assertEq(token.balanceOf(token.DEAD_ADDRESS()), deadBefore);
    }

    function test_CalculateWinnings_ZeroWinningPool() public {
        _createRound();

        // Only bet on UNDER
        vm.prank(bob);
        deadPool.placeBet(1, false, 100 * 1e18);

        vm.warp(block.timestamp + 2 hours);

        // Resolve with OVER winning (but no OVER bets)
        vm.prank(resolver);
        deadPool.resolveRound(1, true);

        // calculateWinnings for non-existent winner should return 0
        uint256 winnings = deadPool.calculateWinnings(1, alice);
        assertEq(winnings, 0);
    }

    function test_GetOverOdds_ZeroPool() public {
        _createRound();

        // No bets yet, overPool is 0
        uint16 odds = deadPool.getOverOdds(1);
        assertEq(odds, 0);
    }

    function test_GetUnderOdds_ZeroPool() public {
        _createRound();

        // Only bet on OVER
        vm.prank(alice);
        deadPool.placeBet(1, true, 100 * 1e18);

        // underPool is 0
        uint16 odds = deadPool.getUnderOdds(1);
        assertEq(odds, 0);
    }

    function test_Pause_Success() public {
        vm.prank(owner);
        deadPool.pause();

        assertTrue(deadPool.paused());
    }

    function test_Unpause_Success() public {
        vm.prank(owner);
        deadPool.pause();

        vm.prank(owner);
        deadPool.unpause();

        assertFalse(deadPool.paused());
    }

    function test_Pause_RevertWhen_NotPauser() public {
        vm.prank(alice);
        vm.expectRevert();
        deadPool.pause();
    }

    function test_Unpause_RevertWhen_NotPauser() public {
        vm.prank(owner);
        deadPool.pause();

        vm.prank(alice);
        vm.expectRevert();
        deadPool.unpause();
    }

    function test_CalculateWinnings_NotResolved() public {
        _createRound();

        vm.prank(alice);
        deadPool.placeBet(1, true, 100 * 1e18);

        // Not resolved yet
        uint256 winnings = deadPool.calculateWinnings(1, alice);
        assertEq(winnings, 0);
    }

    function test_CalculateWinnings_NoBet() public {
        _createRound();

        vm.prank(alice);
        deadPool.placeBet(1, true, 100 * 1e18);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(resolver);
        deadPool.resolveRound(1, true);

        // Bob has no bet
        uint256 winnings = deadPool.calculateWinnings(1, bob);
        assertEq(winnings, 0);
    }

    function test_CalculateWinnings_WrongSide() public {
        _createRound();

        vm.prank(alice);
        deadPool.placeBet(1, true, 100 * 1e18);

        vm.prank(bob);
        deadPool.placeBet(1, false, 100 * 1e18);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(resolver);
        deadPool.resolveRound(1, true); // OVER wins

        // Bob bet UNDER
        uint256 winnings = deadPool.calculateWinnings(1, bob);
        assertEq(winnings, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    function _createRound() internal returns (uint256) {
        uint64 deadline = uint64(block.timestamp + 1 hours);
        vm.prank(owner);
        return deadPool.createRound(
            IDeadPool.RoundType.DEATH_COUNT, IGhostCore.Level.VAULT, 50, deadline
        );
    }
}
