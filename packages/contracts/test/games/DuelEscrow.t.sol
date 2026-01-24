// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";
import { DuelEscrow } from "../../src/arcade/games/DuelEscrow.sol";
import { IArcadeGame } from "../../src/arcade/interfaces/IArcadeGame.sol";
import { IArcadeTypes } from "../../src/arcade/interfaces/IArcadeTypes.sol";
import { IArcadeCore } from "../../src/arcade/interfaces/IArcadeCore.sol";
import { ArcadeCore } from "../../src/arcade/ArcadeCore.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title DuelEscrowTest
/// @notice Comprehensive tests for the CODE DUEL escrow game
contract DuelEscrowTest is Test {
    using MessageHashUtils for bytes32;

    // ══════════════════════════════════════════════════════════════════════════════
    // TEST FIXTURES
    // ══════════════════════════════════════════════════════════════════════════════

    DuelEscrow public game;
    ArcadeCore public arcadeCore;
    ERC20Mock public dataToken;

    address public owner = makeAddr("owner");
    address public admin = makeAddr("admin");
    address public treasury = makeAddr("treasury");

    uint256 public oraclePrivateKey = 0x1234567890abcdef;
    address public oracle;

    address public player1 = makeAddr("player1");
    address public player2 = makeAddr("player2");
    address public player3 = makeAddr("player3");

    uint256 public constant INITIAL_BALANCE = 10_000 ether;

    // Game config
    uint256 public constant MIN_ENTRY = 50 ether;
    uint256 public constant MAX_ENTRY = 500 ether;
    uint16 public constant RAKE_BPS = 1000; // 10%
    uint16 public constant BURN_BPS = 5000; // 50% of rake

    // ══════════════════════════════════════════════════════════════════════════════
    // SETUP
    // ══════════════════════════════════════════════════════════════════════════════

    function setUp() public {
        oracle = vm.addr(oraclePrivateKey);

        vm.startPrank(owner);

        // Deploy token
        dataToken = new ERC20Mock("DATA", "DATA", 18);

        // Deploy ArcadeCore as proxy
        ArcadeCore impl = new ArcadeCore();
        bytes memory initData = abi.encodeCall(
            ArcadeCore.initialize, (address(dataToken), address(0), treasury, admin)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        arcadeCore = ArcadeCore(address(proxy));

        // Deploy DuelEscrow
        game = new DuelEscrow(address(arcadeCore), oracle, owner);

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
    }

    function _fundPlayer(address player, uint256 amount) internal {
        dataToken.mint(player, amount);
        vm.prank(player);
        dataToken.approve(address(arcadeCore), type(uint256).max);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SIGNATURE HELPERS
    // ══════════════════════════════════════════════════════════════════════════════

    function _signCreateMatch(
        address p1,
        address p2,
        DuelEscrow.StakeTier tier,
        bytes32 nonce
    ) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encodePacked(
            "CREATE_MATCH",
            p1,
            p2,
            uint8(tier),
            nonce,
            block.chainid,
            address(game)
        ));
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(oraclePrivateKey, ethSignedHash);
        return abi.encodePacked(r, s, v);
    }

    function _signSubmitResult(
        uint256 matchId,
        address winner,
        DuelEscrow.MatchOutcome outcome,
        bytes32 nonce
    ) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encodePacked(
            "SUBMIT_RESULT",
            matchId,
            winner,
            uint8(outcome),
            nonce,
            block.chainid,
            address(game)
        ));
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(oraclePrivateKey, ethSignedHash);
        return abi.encodePacked(r, s, v);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // GAME INFO TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GameInfo() public view {
        IArcadeTypes.GameInfo memory info = game.getGameInfo();

        assertEq(info.gameId, keccak256("CODE_DUEL"));
        assertEq(info.name, "Code Duel");
        assertEq(uint8(info.category), uint8(IArcadeTypes.GameCategory.COMPETITIVE));
        assertEq(info.minPlayers, 2);
        assertEq(info.maxPlayers, 2);
        assertTrue(info.isActive);
    }

    function test_GameId() public view {
        assertEq(game.gameId(), keccak256("CODE_DUEL"));
    }

    function test_StakeAmounts() public view {
        assertEq(game.getStakeAmount(DuelEscrow.StakeTier.BRONZE), 50 ether);
        assertEq(game.getStakeAmount(DuelEscrow.StakeTier.SILVER), 150 ether);
        assertEq(game.getStakeAmount(DuelEscrow.StakeTier.GOLD), 300 ether);
        assertEq(game.getStakeAmount(DuelEscrow.StakeTier.DIAMOND), 500 ether);
    }

    function test_Constants() public view {
        assertEq(game.BRONZE_STAKE(), 50 ether);
        assertEq(game.SILVER_STAKE(), 150 ether);
        assertEq(game.GOLD_STAKE(), 300 ether);
        assertEq(game.DIAMOND_STAKE(), 500 ether);
        assertEq(game.MATCH_EXPIRY(), 5 minutes);
        assertEq(game.MATCH_TIMEOUT(), 3 minutes);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // MATCH CREATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_CreateMatch() public {
        bytes32 nonce = keccak256("nonce1");
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);

        uint256 matchId = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);

        assertEq(matchId, 1);
        assertEq(game.matchCount(), 1);

        DuelEscrow.Match memory m = game.getMatch(matchId);
        assertEq(m.player1, player1);
        assertEq(m.player2, player2);
        assertEq(m.stake, 50 ether);
        assertEq(uint8(m.state), uint8(DuelEscrow.MatchState.CREATED));
        assertEq(uint8(m.tier), uint8(DuelEscrow.StakeTier.BRONZE));
    }

    function test_CreateMatch_AllTiers() public {
        DuelEscrow.StakeTier[4] memory tiers = [
            DuelEscrow.StakeTier.BRONZE,
            DuelEscrow.StakeTier.SILVER,
            DuelEscrow.StakeTier.GOLD,
            DuelEscrow.StakeTier.DIAMOND
        ];
        uint256[4] memory stakes = [uint256(50 ether), 150 ether, 300 ether, 500 ether];

        for (uint256 i = 0; i < 4; i++) {
            bytes32 nonce = keccak256(abi.encodePacked("tier_nonce", i));
            bytes memory sig = _signCreateMatch(player1, player2, tiers[i], nonce);
            uint256 matchId = game.createMatch(player1, player2, tiers[i], sig, nonce);

            DuelEscrow.Match memory m = game.getMatch(matchId);
            assertEq(m.stake, stakes[i]);
        }
    }

    function test_CreateMatch_RevertWhen_InvalidSignature() public {
        bytes32 nonce = keccak256("bad_nonce");
        // Sign with wrong private key
        bytes32 messageHash = keccak256(abi.encodePacked(
            "CREATE_MATCH",
            player1,
            player2,
            uint8(DuelEscrow.StakeTier.BRONZE),
            nonce,
            block.chainid,
            address(game)
        ));
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xBAD, ethSignedHash);
        bytes memory badSig = abi.encodePacked(r, s, v);

        vm.expectRevert(DuelEscrow.InvalidSignature.selector);
        game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, badSig, nonce);
    }

    function test_CreateMatch_RevertWhen_NonceReused() public {
        bytes32 nonce = keccak256("reused_nonce");
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);

        game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);

        // Try to reuse nonce
        bytes memory sig2 = _signCreateMatch(player1, player3, DuelEscrow.StakeTier.BRONZE, nonce);
        vm.expectRevert(DuelEscrow.NonceAlreadyUsed.selector);
        game.createMatch(player1, player3, DuelEscrow.StakeTier.BRONZE, sig2, nonce);
    }

    function test_CreateMatch_RevertWhen_SamePlayer() public {
        bytes32 nonce = keccak256("same_player");
        bytes memory sig = _signCreateMatch(player1, player1, DuelEscrow.StakeTier.BRONZE, nonce);

        vm.expectRevert(DuelEscrow.InvalidAddress.selector);
        game.createMatch(player1, player1, DuelEscrow.StakeTier.BRONZE, sig, nonce);
    }

    function test_CreateMatch_RevertWhen_ZeroAddress() public {
        bytes32 nonce = keccak256("zero_addr");
        bytes memory sig = _signCreateMatch(address(0), player2, DuelEscrow.StakeTier.BRONZE, nonce);

        vm.expectRevert(DuelEscrow.InvalidAddress.selector);
        game.createMatch(address(0), player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // JOIN MATCH TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_JoinMatch_Player1() public {
        // Create match
        bytes32 nonce = keccak256("join1");
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);
        uint256 matchId = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);

        // Player 1 joins
        uint256 balanceBefore = dataToken.balanceOf(player1);
        vm.prank(player1);
        game.joinMatch(matchId);
        uint256 balanceAfter = dataToken.balanceOf(player1);

        // Check state
        DuelEscrow.Match memory m = game.getMatch(matchId);
        assertEq(uint8(m.state), uint8(DuelEscrow.MatchState.WAITING));
        assertTrue(m.player1Net > 0);
        assertEq(m.player2Net, 0);

        // Check tokens transferred (50 DATA stake)
        assertEq(balanceBefore - balanceAfter, 50 ether);
    }

    function test_JoinMatch_BothPlayers() public {
        // Create match
        bytes32 nonce = keccak256("join_both");
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.SILVER, nonce);
        uint256 matchId = game.createMatch(player1, player2, DuelEscrow.StakeTier.SILVER, sig, nonce);

        // Both players join
        vm.prank(player1);
        game.joinMatch(matchId);

        vm.prank(player2);
        game.joinMatch(matchId);

        // Check state
        DuelEscrow.Match memory m = game.getMatch(matchId);
        assertEq(uint8(m.state), uint8(DuelEscrow.MatchState.ACTIVE));
        assertTrue(m.player1Net > 0);
        assertTrue(m.player2Net > 0);

        // Prize pool should be both stakes minus rake
        // 150 * 2 = 300 DATA gross, 10% rake = 30 DATA, net = 270 DATA
        assertEq(m.prizePool, 270 ether);
    }

    function test_JoinMatch_RevertWhen_NotInvited() public {
        bytes32 nonce = keccak256("not_invited");
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);
        uint256 matchId = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);

        vm.prank(player3);
        vm.expectRevert(DuelEscrow.NotInvited.selector);
        game.joinMatch(matchId);
    }

    function test_JoinMatch_RevertWhen_AlreadyJoined() public {
        bytes32 nonce = keccak256("already_joined");
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);
        uint256 matchId = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);

        vm.prank(player1);
        game.joinMatch(matchId);

        vm.prank(player1);
        vm.expectRevert(DuelEscrow.AlreadyJoined.selector);
        game.joinMatch(matchId);
    }

    function test_JoinMatch_RevertWhen_MatchExpired() public {
        bytes32 nonce = keccak256("expired");
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);
        uint256 matchId = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);

        // Advance past expiry
        vm.warp(block.timestamp + 6 minutes);

        vm.prank(player1);
        vm.expectRevert(DuelEscrow.MatchNotExpired.selector);
        game.joinMatch(matchId);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // RESULT SUBMISSION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function _createAndStartMatch(DuelEscrow.StakeTier tier) internal returns (uint256 matchId) {
        bytes32 nonce = keccak256(abi.encodePacked("match", block.timestamp, tier));
        bytes memory sig = _signCreateMatch(player1, player2, tier, nonce);
        matchId = game.createMatch(player1, player2, tier, sig, nonce);

        vm.prank(player1);
        game.joinMatch(matchId);

        vm.prank(player2);
        game.joinMatch(matchId);
    }

    function test_SubmitResult_Player1Wins() public {
        uint256 matchId = _createAndStartMatch(DuelEscrow.StakeTier.BRONZE);

        // Submit result: player1 wins
        bytes32 nonce = keccak256("result1");
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, sig, nonce);

        DuelEscrow.Match memory m = game.getMatch(matchId);
        assertEq(uint8(m.state), uint8(DuelEscrow.MatchState.RESOLVED));
        assertEq(m.winner, player1);
        assertEq(uint8(m.outcome), uint8(DuelEscrow.MatchOutcome.WIN));

        // Check player1 has pending payout
        uint256 pending = arcadeCore.getPendingPayout(player1);
        // Prize pool is 90 DATA (after 10% rake on both 50 DATA stakes)
        assertEq(pending, 90 ether);
    }

    function test_SubmitResult_Player2Wins() public {
        uint256 matchId = _createAndStartMatch(DuelEscrow.StakeTier.GOLD);

        // Submit result: player2 wins
        bytes32 nonce = keccak256("result2");
        bytes memory sig = _signSubmitResult(matchId, player2, DuelEscrow.MatchOutcome.WIN, nonce);
        game.submitResult(matchId, player2, DuelEscrow.MatchOutcome.WIN, sig, nonce);

        DuelEscrow.Match memory m = game.getMatch(matchId);
        assertEq(m.winner, player2);

        // Check player2 has pending payout (540 DATA = 300*2 - 10% rake)
        uint256 pending = arcadeCore.getPendingPayout(player2);
        assertEq(pending, 540 ether);
    }

    function test_SubmitResult_Tie() public {
        uint256 matchId = _createAndStartMatch(DuelEscrow.StakeTier.SILVER);

        // Submit result: tie
        bytes32 nonce = keccak256("tie");
        bytes memory sig = _signSubmitResult(matchId, address(0), DuelEscrow.MatchOutcome.TIE, nonce);
        game.submitResult(matchId, address(0), DuelEscrow.MatchOutcome.TIE, sig, nonce);

        DuelEscrow.Match memory m = game.getMatch(matchId);
        assertEq(m.winner, address(0));
        assertEq(uint8(m.outcome), uint8(DuelEscrow.MatchOutcome.TIE));

        // Both players should get ~45% each
        // Prize pool: 270 DATA, 10% burn = 27 DATA, remaining = 243 DATA
        // In wei: 243 ether / 2 = 121.5 ether exactly
        uint256 p1Pending = arcadeCore.getPendingPayout(player1);
        uint256 p2Pending = arcadeCore.getPendingPayout(player2);
        
        // 243 ether / 2 = 121.5 ether (solidity operates on wei, so exact division)
        assertEq(p1Pending, 121.5 ether);
        // payout2 = 243 - 121.5 = 121.5 ether
        assertEq(p2Pending, 121.5 ether);
    }

    function test_SubmitResult_Forfeit() public {
        uint256 matchId = _createAndStartMatch(DuelEscrow.StakeTier.BRONZE);

        // Submit result: player2 forfeits (player1 wins)
        bytes32 nonce = keccak256("forfeit");
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.FORFEIT, nonce);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.FORFEIT, sig, nonce);

        DuelEscrow.Match memory m = game.getMatch(matchId);
        assertEq(m.winner, player1);
        assertEq(uint8(m.outcome), uint8(DuelEscrow.MatchOutcome.FORFEIT));
    }

    function test_SubmitResult_RevertWhen_InvalidSignature() public {
        uint256 matchId = _createAndStartMatch(DuelEscrow.StakeTier.BRONZE);

        bytes32 nonce = keccak256("bad_result");
        // Sign with wrong key
        bytes32 messageHash = keccak256(abi.encodePacked(
            "SUBMIT_RESULT",
            matchId,
            player1,
            uint8(DuelEscrow.MatchOutcome.WIN),
            nonce,
            block.chainid,
            address(game)
        ));
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xBAD, ethSignedHash);
        bytes memory badSig = abi.encodePacked(r, s, v);

        vm.expectRevert(DuelEscrow.InvalidSignature.selector);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, badSig, nonce);
    }

    function test_SubmitResult_RevertWhen_InvalidWinner() public {
        uint256 matchId = _createAndStartMatch(DuelEscrow.StakeTier.BRONZE);

        bytes32 nonce = keccak256("invalid_winner");
        bytes memory sig = _signSubmitResult(matchId, player3, DuelEscrow.MatchOutcome.WIN, nonce);

        vm.expectRevert(DuelEscrow.InvalidWinner.selector);
        game.submitResult(matchId, player3, DuelEscrow.MatchOutcome.WIN, sig, nonce);
    }

    function test_SubmitResult_RevertWhen_MatchNotActive() public {
        bytes32 nonce = keccak256("not_active");
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);
        uint256 matchId = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);

        // Only player1 joined - match is WAITING, not ACTIVE
        vm.prank(player1);
        game.joinMatch(matchId);

        bytes32 resultNonce = keccak256("result_not_active");
        bytes memory resultSig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, resultNonce);

        vm.expectRevert(DuelEscrow.InvalidMatchState.selector);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, resultSig, resultNonce);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // REFUND TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_ClaimRefund_MatchExpired() public {
        bytes32 nonce = keccak256("refund_expired");
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);
        uint256 matchId = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);

        // Player 1 joins
        vm.prank(player1);
        game.joinMatch(matchId);

        uint256 balanceBefore = dataToken.balanceOf(player1);

        // Advance past expiry
        vm.warp(block.timestamp + 6 minutes);

        // Claim refund (credits to pending payouts)
        vm.prank(player1);
        game.claimRefund(matchId);

        // Withdraw pending payout (pull-payment pattern)
        vm.prank(player1);
        arcadeCore.withdrawPayout();

        // Check balance restored (minus rake that was already taken)
        uint256 balanceAfter = dataToken.balanceOf(player1);
        // Net amount after 10% rake = 45 DATA refunded
        assertEq(balanceAfter - balanceBefore, 45 ether);

        // Check state
        DuelEscrow.Match memory m = game.getMatch(matchId);
        assertEq(uint8(m.state), uint8(DuelEscrow.MatchState.CANCELLED));
    }

    function test_ClaimRefund_MatchTimedOut() public {
        uint256 matchId = _createAndStartMatch(DuelEscrow.StakeTier.BRONZE);

        uint256 p1BalanceBefore = dataToken.balanceOf(player1);
        uint256 p2BalanceBefore = dataToken.balanceOf(player2);

        // Advance past timeout
        vm.warp(block.timestamp + 4 minutes);

        // Both players claim refunds
        vm.prank(player1);
        game.claimRefund(matchId);

        vm.prank(player2);
        game.claimRefund(matchId);

        // Withdraw pending payouts (pull-payment pattern)
        vm.prank(player1);
        arcadeCore.withdrawPayout();
        vm.prank(player2);
        arcadeCore.withdrawPayout();

        // Check balances restored (net after rake)
        uint256 p1BalanceAfter = dataToken.balanceOf(player1);
        uint256 p2BalanceAfter = dataToken.balanceOf(player2);

        assertEq(p1BalanceAfter - p1BalanceBefore, 45 ether);
        assertEq(p2BalanceAfter - p2BalanceBefore, 45 ether);
    }

    function test_ClaimRefund_RevertWhen_MatchNotExpired() public {
        uint256 matchId = _createAndStartMatch(DuelEscrow.StakeTier.BRONZE);

        vm.prank(player1);
        vm.expectRevert(DuelEscrow.MatchNotExpired.selector);
        game.claimRefund(matchId);
    }

    function test_ClaimRefund_RevertWhen_Unauthorized() public {
        bytes32 nonce = keccak256("unauth_refund");
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);
        uint256 matchId = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);

        vm.prank(player1);
        game.joinMatch(matchId);

        vm.warp(block.timestamp + 6 minutes);

        // Player3 tries to claim (not in match)
        vm.prank(player3);
        vm.expectRevert(DuelEscrow.Unauthorized.selector);
        game.claimRefund(matchId);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_SetOracle() public {
        address newOracle = makeAddr("newOracle");

        vm.prank(owner);
        game.setOracle(newOracle);

        assertEq(game.oracle(), newOracle);
    }

    function test_SetOracle_RevertWhen_NotOwner() public {
        vm.prank(player1);
        vm.expectRevert();
        game.setOracle(makeAddr("bad"));
    }

    function test_SetOracle_RevertWhen_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(DuelEscrow.InvalidAddress.selector);
        game.setOracle(address(0));
    }

    function test_Pause() public {
        vm.prank(owner);
        game.pause();

        assertTrue(game.isPaused());

        // Cannot create matches when paused
        bytes32 nonce = keccak256("paused");
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);
        vm.expectRevert();
        game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);
    }

    function test_Unpause() public {
        vm.startPrank(owner);
        game.pause();
        game.unpause();
        vm.stopPrank();

        assertFalse(game.isPaused());
    }

    function test_EmergencyCancel() public {
        uint256 matchId = _createAndStartMatch(DuelEscrow.StakeTier.BRONZE);

        vm.prank(owner);
        game.emergencyCancel(matchId, "Emergency test");

        DuelEscrow.Match memory m = game.getMatch(matchId);
        assertEq(uint8(m.state), uint8(DuelEscrow.MatchState.CANCELLED));
    }

    function test_EmergencyCancel_RevertWhen_AlreadyResolved() public {
        uint256 matchId = _createAndStartMatch(DuelEscrow.StakeTier.BRONZE);

        // Resolve match first
        bytes32 nonce = keccak256("resolved");
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, sig, nonce);

        vm.prank(owner);
        vm.expectRevert(DuelEscrow.InvalidMatchState.selector);
        game.emergencyCancel(matchId, "Too late");
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

    function test_GetSessionState() public {
        bytes32 nonce = keccak256("session_state");
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);
        uint256 matchId = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);

        // CREATED -> BETTING
        assertEq(uint8(game.getSessionState(matchId)), uint8(IArcadeTypes.SessionState.BETTING));

        vm.prank(player1);
        game.joinMatch(matchId);

        // WAITING -> still BETTING
        assertEq(uint8(game.getSessionState(matchId)), uint8(IArcadeTypes.SessionState.BETTING));

        vm.prank(player2);
        game.joinMatch(matchId);

        // ACTIVE -> ACTIVE
        assertEq(uint8(game.getSessionState(matchId)), uint8(IArcadeTypes.SessionState.ACTIVE));
    }

    function test_IsPlayerInSession() public {
        bytes32 nonce = keccak256("in_session");
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);
        uint256 matchId = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);

        // Not yet joined
        assertFalse(game.isPlayerInSession(matchId, player1));

        vm.prank(player1);
        game.joinMatch(matchId);

        // Now joined
        assertTrue(game.isPlayerInSession(matchId, player1));
        assertFalse(game.isPlayerInSession(matchId, player2));
    }

    function test_GetSessionPrizePool() public {
        uint256 matchId = _createAndStartMatch(DuelEscrow.StakeTier.DIAMOND);

        // 500 * 2 = 1000 gross, 10% rake = 100, net = 900
        assertEq(game.getSessionPrizePool(matchId), 900 ether);
    }

    function test_IsNonceUsed() public {
        bytes32 nonce = keccak256("nonce_check");
        assertFalse(game.isNonceUsed(nonce));

        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);
        game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);

        assertTrue(game.isNonceUsed(nonce));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function testFuzz_CreateMatch_StakeTier(uint8 tierIndex) public {
        tierIndex = uint8(bound(tierIndex, 0, 3));
        DuelEscrow.StakeTier tier = DuelEscrow.StakeTier(tierIndex);

        bytes32 nonce = keccak256(abi.encodePacked("fuzz_tier", tierIndex));
        bytes memory sig = _signCreateMatch(player1, player2, tier, nonce);
        uint256 matchId = game.createMatch(player1, player2, tier, sig, nonce);

        DuelEscrow.Match memory m = game.getMatch(matchId);
        assertEq(uint8(m.tier), tierIndex);
    }

    function testFuzz_MultipleMatches(uint8 numMatches) public {
        numMatches = uint8(bound(numMatches, 1, 20));

        for (uint256 i = 0; i < numMatches; i++) {
            bytes32 nonce = keccak256(abi.encodePacked("multi", i));
            bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);
            uint256 matchId = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);

            assertEq(matchId, i + 1);
        }

        assertEq(game.matchCount(), numMatches);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTEGRATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_FullMatchFlow_Player1Wins() public {
        uint256 p1InitialBalance = dataToken.balanceOf(player1);
        uint256 p2InitialBalance = dataToken.balanceOf(player2);

        // Create match
        uint256 matchId = _createAndStartMatch(DuelEscrow.StakeTier.GOLD);

        // Submit result: player1 wins
        bytes32 nonce = keccak256("full_flow");
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, sig, nonce);

        // Player1 withdraws winnings
        vm.prank(player1);
        arcadeCore.withdrawPayout();

        // Check final balances
        uint256 p1FinalBalance = dataToken.balanceOf(player1);
        uint256 p2FinalBalance = dataToken.balanceOf(player2);

        // Player1: Started with X, paid 300, received 540 (300*2 - 10% rake)
        // Net gain: 540 - 300 = 240 DATA
        assertEq(p1FinalBalance, p1InitialBalance + 240 ether);

        // Player2: Started with X, paid 300, received 0
        // Net loss: 300 DATA
        assertEq(p2FinalBalance, p2InitialBalance - 300 ether);
    }

    function test_FullMatchFlow_Tie() public {
        uint256 p1InitialBalance = dataToken.balanceOf(player1);
        uint256 p2InitialBalance = dataToken.balanceOf(player2);

        uint256 matchId = _createAndStartMatch(DuelEscrow.StakeTier.BRONZE);

        // Submit tie result
        bytes32 nonce = keccak256("tie_flow");
        bytes memory sig = _signSubmitResult(matchId, address(0), DuelEscrow.MatchOutcome.TIE, nonce);
        game.submitResult(matchId, address(0), DuelEscrow.MatchOutcome.TIE, sig, nonce);

        // Both withdraw
        vm.prank(player1);
        arcadeCore.withdrawPayout();
        vm.prank(player2);
        arcadeCore.withdrawPayout();

        uint256 p1FinalBalance = dataToken.balanceOf(player1);
        uint256 p2FinalBalance = dataToken.balanceOf(player2);

        // Each paid 50 DATA, prize pool = 90 DATA (after 10% rake)
        // Tie: 10% burn = 9 DATA, remaining = 81 DATA
        // 81 ether / 2 = 40.5 ether (exact in wei arithmetic)
        // Net loss each: 50 - 40.5 = 9.5 DATA
        assertEq(p1InitialBalance - p1FinalBalance, 9.5 ether);
        assertEq(p2InitialBalance - p2FinalBalance, 9.5 ether);
    }
}
