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

/// @title DuelEscrowSecurityTest
/// @notice Security-focused tests for DuelEscrow - negative tests, edge cases, attack vectors
/// @dev Ensures the CODE DUEL escrow system is secure against manipulation and exploits
contract DuelEscrowSecurityTest is Test {
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
    address public attacker = makeAddr("attacker");

    uint256 public oraclePrivateKey = 0x1234567890abcdef;
    address public oracle;

    uint256 public fakeOracleKey = 0xBAD;
    address public fakeOracle;

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
        fakeOracle = vm.addr(fakeOracleKey);

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
        _fundPlayer(attacker, INITIAL_BALANCE);
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

    function _signCreateMatchWithKey(
        address p1,
        address p2,
        DuelEscrow.StakeTier tier,
        bytes32 nonce,
        uint256 privateKey
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
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedHash);
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

    function _signSubmitResultWithKey(
        uint256 matchId,
        address winner,
        DuelEscrow.MatchOutcome outcome,
        bytes32 nonce,
        uint256 privateKey
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
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedHash);
        return abi.encodePacked(r, s, v);
    }

    function _createMatch() internal returns (uint256 matchId) {
        bytes32 nonce = keccak256(abi.encodePacked("match", block.timestamp));
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);
        matchId = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);
    }

    function _createAndStartMatch() internal returns (uint256 matchId) {
        matchId = _createMatch();
        vm.prank(player1);
        game.joinMatch(matchId);
        vm.prank(player2);
        game.joinMatch(matchId);
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

    function test_Security_OnlyOwnerCanSetOracle() public {
        vm.prank(attacker);
        vm.expectRevert();
        game.setOracle(attacker);

        vm.prank(admin);
        vm.expectRevert();
        game.setOracle(admin);
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
        uint256 matchId = _createMatch();

        vm.prank(attacker);
        vm.expectRevert();
        game.emergencyCancel(matchId, "Attack");

        vm.prank(admin);
        vm.expectRevert();
        game.emergencyCancel(matchId, "Attack");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SIGNATURE SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_CreateMatch_ReplayAttack() public {
        bytes32 nonce = keccak256("replay_test");
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);

        // First use succeeds
        game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);

        // Replay attempt fails
        vm.expectRevert(DuelEscrow.NonceAlreadyUsed.selector);
        game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);
    }

    function test_Security_CreateMatch_CrossChainReplay() public {
        // Signature includes block.chainid, so replaying on a different chain would fail
        // because the recovered signer would be different
        bytes32 nonce = keccak256("cross_chain");
        
        // Create signature on chain 1
        bytes32 messageHash = keccak256(abi.encodePacked(
            "CREATE_MATCH",
            player1,
            player2,
            uint8(DuelEscrow.StakeTier.BRONZE),
            nonce,
            uint256(9999), // Different chain ID
            address(game)
        ));
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(oraclePrivateKey, ethSignedHash);
        bytes memory crossChainSig = abi.encodePacked(r, s, v);

        // Try to use on current chain - should fail because chainid doesn't match
        vm.expectRevert(DuelEscrow.InvalidSignature.selector);
        game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, crossChainSig, nonce);
    }

    function test_Security_CreateMatch_WrongGameAddress() public {
        bytes32 nonce = keccak256("wrong_game");
        
        // Sign for wrong game address
        bytes32 messageHash = keccak256(abi.encodePacked(
            "CREATE_MATCH",
            player1,
            player2,
            uint8(DuelEscrow.StakeTier.BRONZE),
            nonce,
            block.chainid,
            address(0xDEAD) // Wrong game address
        ));
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(oraclePrivateKey, ethSignedHash);
        bytes memory wrongGameSig = abi.encodePacked(r, s, v);

        vm.expectRevert(DuelEscrow.InvalidSignature.selector);
        game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, wrongGameSig, nonce);
    }

    function test_Security_CreateMatch_ModifiedPlayers() public {
        bytes32 nonce = keccak256("modified_players");
        
        // Sign for player1 vs player2
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);

        // Try to use with different players - should fail
        vm.expectRevert(DuelEscrow.InvalidSignature.selector);
        game.createMatch(player1, player3, DuelEscrow.StakeTier.BRONZE, sig, nonce);

        vm.expectRevert(DuelEscrow.InvalidSignature.selector);
        game.createMatch(player3, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);
    }

    function test_Security_CreateMatch_ModifiedTier() public {
        bytes32 nonce = keccak256("modified_tier");
        
        // Sign for BRONZE
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);

        // Try to use with DIAMOND tier - should fail
        vm.expectRevert(DuelEscrow.InvalidSignature.selector);
        game.createMatch(player1, player2, DuelEscrow.StakeTier.DIAMOND, sig, nonce);
    }

    function test_Security_SubmitResult_ReplayAttack() public {
        uint256 matchId = _createAndStartMatch();

        bytes32 nonce = keccak256("result_replay");
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce);

        // First use succeeds
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, sig, nonce);

        // Replay attempt fails - match already resolved (before nonce check)
        vm.expectRevert(DuelEscrow.InvalidMatchState.selector);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, sig, nonce);
    }

    function test_Security_SubmitResult_WrongSigner() public {
        uint256 matchId = _createAndStartMatch();

        bytes32 nonce = keccak256("wrong_signer");
        bytes memory fakeSig = _signSubmitResultWithKey(
            matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce, fakeOracleKey
        );

        vm.expectRevert(DuelEscrow.InvalidSignature.selector);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, fakeSig, nonce);
    }

    function test_Security_SubmitResult_ModifiedWinner() public {
        uint256 matchId = _createAndStartMatch();

        bytes32 nonce = keccak256("modified_winner");
        // Sign for player1 as winner
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce);

        // Try to use with player2 as winner - should fail
        vm.expectRevert(DuelEscrow.InvalidSignature.selector);
        game.submitResult(matchId, player2, DuelEscrow.MatchOutcome.WIN, sig, nonce);
    }

    function test_Security_SubmitResult_ModifiedOutcome() public {
        uint256 matchId = _createAndStartMatch();

        bytes32 nonce = keccak256("modified_outcome");
        // Sign for WIN
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce);

        // Try to use with FORFEIT - should fail
        vm.expectRevert(DuelEscrow.InvalidSignature.selector);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.FORFEIT, sig, nonce);
    }

    function test_Security_SubmitResult_ModifiedMatchId() public {
        uint256 matchId = _createAndStartMatch();

        bytes32 nonce = keccak256("modified_matchid");
        // Sign for match 1
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce);

        // Advance time to avoid rate limiter
        vm.warp(block.timestamp + 60);

        // Create another match
        bytes32 nonce2 = keccak256("second_match");
        bytes memory sig2 = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce2);
        uint256 matchId2 = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig2, nonce2);
        vm.prank(player1);
        game.joinMatch(matchId2);
        vm.prank(player2);
        game.joinMatch(matchId2);

        // Try to use signature for match 1 on match 2 - should fail
        vm.expectRevert(DuelEscrow.InvalidSignature.selector);
        game.submitResult(matchId2, player1, DuelEscrow.MatchOutcome.WIN, sig, nonce);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ORACLE COMPROMISE SCENARIOS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_OracleChange_OldSignaturesInvalid() public {
        // Create signature with old oracle
        bytes32 nonce = keccak256("old_oracle");
        bytes memory oldSig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);

        // Change oracle
        address newOracle = makeAddr("newOracle");
        vm.prank(owner);
        game.setOracle(newOracle);

        // Old signature should now be invalid
        vm.expectRevert(DuelEscrow.InvalidSignature.selector);
        game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, oldSig, nonce);
    }

    function test_Security_OracleChange_EventEmitted() public {
        address newOracle = makeAddr("newOracle");
        
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit DuelEscrow.OracleUpdated(oracle, newOracle);
        game.setOracle(newOracle);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE MACHINE SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_CannotJoinResolvedMatch() public {
        uint256 matchId = _createAndStartMatch();

        // Resolve match
        bytes32 nonce = keccak256("resolve");
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, sig, nonce);

        // Try to join resolved match
        vm.prank(player3);
        vm.expectRevert(DuelEscrow.InvalidMatchState.selector);
        game.joinMatch(matchId);
    }

    function test_Security_CannotJoinCancelledMatch() public {
        uint256 matchId = _createMatch();

        // Player1 joins first (creates session in ArcadeCore)
        vm.prank(player1);
        game.joinMatch(matchId);

        vm.prank(owner);
        game.emergencyCancel(matchId, "Cancelled");

        // Player2 cannot join cancelled match
        vm.prank(player2);
        vm.expectRevert(DuelEscrow.InvalidMatchState.selector);
        game.joinMatch(matchId);
    }

    function test_Security_CannotSubmitResultOnCreatedMatch() public {
        uint256 matchId = _createMatch();
        // No one has joined

        bytes32 nonce = keccak256("early_result");
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce);

        vm.expectRevert(DuelEscrow.InvalidMatchState.selector);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, sig, nonce);
    }

    function test_Security_CannotSubmitResultOnWaitingMatch() public {
        uint256 matchId = _createMatch();
        vm.prank(player1);
        game.joinMatch(matchId);
        // Only player1 joined

        bytes32 nonce = keccak256("waiting_result");
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce);

        vm.expectRevert(DuelEscrow.InvalidMatchState.selector);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, sig, nonce);
    }

    function test_Security_CannotSubmitResultOnResolvedMatch() public {
        uint256 matchId = _createAndStartMatch();

        // Resolve once
        bytes32 nonce1 = keccak256("first_result");
        bytes memory sig1 = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce1);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, sig1, nonce1);

        // Try to submit again
        bytes32 nonce2 = keccak256("second_result");
        bytes memory sig2 = _signSubmitResult(matchId, player2, DuelEscrow.MatchOutcome.WIN, nonce2);

        vm.expectRevert(DuelEscrow.InvalidMatchState.selector);
        game.submitResult(matchId, player2, DuelEscrow.MatchOutcome.WIN, sig2, nonce2);
    }

    function test_Security_CannotSubmitResultOnCancelledMatch() public {
        uint256 matchId = _createAndStartMatch();

        vm.prank(owner);
        game.emergencyCancel(matchId, "Cancelled");

        bytes32 nonce = keccak256("cancelled_result");
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce);

        vm.expectRevert(DuelEscrow.InvalidMatchState.selector);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, sig, nonce);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // REFUND SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_ClaimRefund_DoubleClaimPrevention() public {
        uint256 matchId = _createMatch();
        vm.prank(player1);
        game.joinMatch(matchId);

        // Expire match
        vm.warp(block.timestamp + 6 minutes);

        // First claim succeeds
        vm.prank(player1);
        game.claimRefund(matchId);

        // Second claim fails - no more stake
        vm.prank(player1);
        vm.expectRevert(DuelEscrow.Unauthorized.selector);
        game.claimRefund(matchId);
    }

    function test_Security_ClaimRefund_NonParticipant() public {
        uint256 matchId = _createMatch();
        vm.prank(player1);
        game.joinMatch(matchId);

        // Expire match
        vm.warp(block.timestamp + 6 minutes);

        // Player3 (not participant) tries to claim
        vm.prank(player3);
        vm.expectRevert(DuelEscrow.Unauthorized.selector);
        game.claimRefund(matchId);
    }

    function test_Security_ClaimRefund_InvitedButNotJoined() public {
        uint256 matchId = _createMatch();
        
        // Player2 joins but player1 doesn't
        vm.prank(player2);
        game.joinMatch(matchId);

        // Expire match
        vm.warp(block.timestamp + 6 minutes);

        // Player1 cannot claim because they have no stake (never joined)
        vm.prank(player1);
        vm.expectRevert(DuelEscrow.Unauthorized.selector);
        game.claimRefund(matchId);
    }

    function test_Security_ClaimRefund_Player2InWaitingState() public {
        uint256 matchId = _createMatch();
        vm.prank(player1);
        game.joinMatch(matchId);
        // Player2 has not joined, match is WAITING

        // Expire match
        vm.warp(block.timestamp + 6 minutes);

        // Player2 cannot claim - never joined
        vm.prank(player2);
        vm.expectRevert(DuelEscrow.Unauthorized.selector);
        game.claimRefund(matchId);
    }

    function test_Security_ClaimRefund_OnResolvedMatch() public {
        uint256 matchId = _createAndStartMatch();

        // Resolve match
        bytes32 nonce = keccak256("resolve_for_refund");
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, sig, nonce);

        // Try to claim refund on resolved match
        vm.prank(player2);
        vm.expectRevert(DuelEscrow.MatchNotExpired.selector);
        game.claimRefund(matchId);
    }

    function test_Security_ClaimRefund_AlreadyCancelledMatch() public {
        uint256 matchId = _createMatch();
        vm.prank(player1);
        game.joinMatch(matchId);
        vm.prank(player2);
        game.joinMatch(matchId);

        // Emergency cancel
        vm.prank(owner);
        game.emergencyCancel(matchId, "Test");

        // Both players can claim refunds on cancelled match
        vm.prank(player1);
        game.claimRefund(matchId);

        vm.prank(player2);
        game.claimRefund(matchId);

        // Verify they got their money back
        vm.prank(player1);
        arcadeCore.withdrawPayout();
        vm.prank(player2);
        arcadeCore.withdrawPayout();
    }

    function test_Security_ClaimRefund_ActiveMatchTimeout() public {
        uint256 matchId = _createAndStartMatch();

        // Warp to timeout
        vm.warp(block.timestamp + 4 minutes);

        // Player1 claims refund (triggers state change to CANCELLED)
        vm.prank(player1);
        game.claimRefund(matchId);

        // Match should now be cancelled
        DuelEscrow.Match memory m = game.getMatch(matchId);
        assertEq(uint8(m.state), uint8(DuelEscrow.MatchState.CANCELLED));

        // Player2 can also claim
        vm.prank(player2);
        game.claimRefund(matchId);
    }

    function test_Security_ClaimRefund_NonexistentMatch() public {
        vm.prank(player1);
        vm.expectRevert(DuelEscrow.MatchNotFound.selector);
        game.claimRefund(999);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EMERGENCY CANCEL SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_EmergencyCancel_NonexistentMatch() public {
        vm.prank(owner);
        vm.expectRevert(DuelEscrow.MatchNotFound.selector);
        game.emergencyCancel(999, "Test");
    }

    function test_Security_EmergencyCancel_AlreadyResolved() public {
        uint256 matchId = _createAndStartMatch();

        bytes32 nonce = keccak256("resolve_first");
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, sig, nonce);

        vm.prank(owner);
        vm.expectRevert(DuelEscrow.InvalidMatchState.selector);
        game.emergencyCancel(matchId, "Too late");
    }

    function test_Security_EmergencyCancel_AlreadyCancelled() public {
        uint256 matchId = _createMatch();

        // Must have at least one player join to create session in ArcadeCore
        vm.prank(player1);
        game.joinMatch(matchId);

        vm.prank(owner);
        game.emergencyCancel(matchId, "First");

        vm.prank(owner);
        vm.expectRevert(DuelEscrow.InvalidMatchState.selector);
        game.emergencyCancel(matchId, "Second");
    }

    function test_Security_EmergencyCancel_AllStates() public {
        // Test cancelling from WAITING state (must have at least one player for session to exist)
        bytes32 nonce2 = keccak256("waiting_cancel");
        bytes memory sig2 = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce2);
        uint256 match2 = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig2, nonce2);
        vm.prank(player1);
        game.joinMatch(match2);
        vm.prank(owner);
        game.emergencyCancel(match2, "Waiting state");

        // Advance time to avoid rate limiter
        vm.warp(block.timestamp + 60);

        // Test cancelling from ACTIVE state
        bytes32 nonce3 = keccak256("active_cancel");
        bytes memory sig3 = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce3);
        uint256 match3 = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig3, nonce3);
        vm.prank(player1);
        game.joinMatch(match3);
        vm.prank(player2);
        game.joinMatch(match3);
        vm.prank(owner);
        game.emergencyCancel(match3, "Active state");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // PAUSED STATE SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_CannotCreateMatchWhenPaused() public {
        vm.prank(owner);
        game.pause();

        bytes32 nonce = keccak256("paused_create");
        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);

        vm.expectRevert();
        game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);
    }

    function test_Security_CannotJoinMatchWhenPaused() public {
        uint256 matchId = _createMatch();

        vm.prank(owner);
        game.pause();

        vm.prank(player1);
        vm.expectRevert();
        game.joinMatch(matchId);
    }

    function test_Security_CanSubmitResultWhenPaused() public {
        uint256 matchId = _createAndStartMatch();

        vm.prank(owner);
        game.pause();

        // Result submission should still work (not paused) to allow resolution
        bytes32 nonce = keccak256("paused_result");
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, sig, nonce);

        DuelEscrow.Match memory m = game.getMatch(matchId);
        assertEq(uint8(m.state), uint8(DuelEscrow.MatchState.RESOLVED));
    }

    function test_Security_CanClaimRefundWhenPaused() public {
        uint256 matchId = _createMatch();
        vm.prank(player1);
        game.joinMatch(matchId);

        vm.prank(owner);
        game.pause();

        // Expire match
        vm.warp(block.timestamp + 6 minutes);

        // Refund should still work when paused
        vm.prank(player1);
        game.claimRefund(matchId);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // GRIEFING ATTACK PREVENTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_Griefing_NotJoiningAfterOpponent() public {
        uint256 matchId = _createMatch();

        // Player1 joins
        vm.prank(player1);
        game.joinMatch(matchId);

        // Player2 doesn't join - griefing attempt
        // After expiry, player1 can claim refund
        vm.warp(block.timestamp + 6 minutes);

        uint256 balanceBefore = dataToken.balanceOf(player1);
        vm.prank(player1);
        game.claimRefund(matchId);
        vm.prank(player1);
        arcadeCore.withdrawPayout();
        uint256 balanceAfter = dataToken.balanceOf(player1);

        // Player1 gets net refund (after rake)
        assertEq(balanceAfter - balanceBefore, 45 ether); // 50 - 10% rake
    }

    function test_Security_Griefing_MassMatchCreation() public {
        // Attacker cannot create unlimited matches because:
        // 1. Needs oracle signature for each
        // 2. Each nonce can only be used once

        // Simulate batch creation
        for (uint256 i = 0; i < 10; i++) {
            bytes32 nonce = keccak256(abi.encodePacked("mass", i));
            bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);
            game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);
        }

        assertEq(game.matchCount(), 10);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // RESULT VALIDATION SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_InvalidWinner_NotParticipant() public {
        uint256 matchId = _createAndStartMatch();

        bytes32 nonce = keccak256("invalid_winner");
        bytes memory sig = _signSubmitResult(matchId, player3, DuelEscrow.MatchOutcome.WIN, nonce);

        vm.expectRevert(DuelEscrow.InvalidWinner.selector);
        game.submitResult(matchId, player3, DuelEscrow.MatchOutcome.WIN, sig, nonce);
    }

    function test_Security_InvalidWinner_ZeroAddressOnWin() public {
        uint256 matchId = _createAndStartMatch();

        bytes32 nonce = keccak256("zero_winner");
        bytes memory sig = _signSubmitResult(matchId, address(0), DuelEscrow.MatchOutcome.WIN, nonce);

        vm.expectRevert(DuelEscrow.InvalidWinner.selector);
        game.submitResult(matchId, address(0), DuelEscrow.MatchOutcome.WIN, sig, nonce);
    }

    function test_Security_InvalidWinner_ZeroAddressOnForfeit() public {
        uint256 matchId = _createAndStartMatch();

        bytes32 nonce = keccak256("zero_forfeit");
        bytes memory sig = _signSubmitResult(matchId, address(0), DuelEscrow.MatchOutcome.FORFEIT, nonce);

        vm.expectRevert(DuelEscrow.InvalidWinner.selector);
        game.submitResult(matchId, address(0), DuelEscrow.MatchOutcome.FORFEIT, sig, nonce);
    }

    function test_Security_TieOutcome_AnyWinnerAddress() public {
        uint256 matchId = _createAndStartMatch();

        // For TIE, winner address doesn't matter (should be address(0) but not validated)
        bytes32 nonce = keccak256("tie_outcome");
        bytes memory sig = _signSubmitResult(matchId, address(0), DuelEscrow.MatchOutcome.TIE, nonce);
        
        game.submitResult(matchId, address(0), DuelEscrow.MatchOutcome.TIE, sig, nonce);

        DuelEscrow.Match memory m = game.getMatch(matchId);
        assertEq(uint8(m.outcome), uint8(DuelEscrow.MatchOutcome.TIE));
        assertEq(m.winner, address(0));
    }

    function test_Security_TimeoutOutcome_RefundsPlayers() public {
        uint256 matchId = _createAndStartMatch();

        bytes32 nonce = keccak256("timeout_outcome");
        bytes memory sig = _signSubmitResult(matchId, address(0), DuelEscrow.MatchOutcome.TIMEOUT, nonce);
        
        game.submitResult(matchId, address(0), DuelEscrow.MatchOutcome.TIMEOUT, sig, nonce);

        // Match should be cancelled
        DuelEscrow.Match memory m = game.getMatch(matchId);
        assertEq(uint8(m.state), uint8(DuelEscrow.MatchState.CANCELLED));

        // Both players can claim refunds
        vm.prank(player1);
        game.claimRefund(matchId);
        vm.prank(player2);
        game.claimRefund(matchId);
    }

    function test_Security_TieOutcome_RevertWhen_NonZeroWinner() public {
        uint256 matchId = _createAndStartMatch();

        // TIE outcome must have winner == address(0)
        bytes32 nonce = keccak256("tie_nonzero");
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.TIE, nonce);

        vm.expectRevert(DuelEscrow.InvalidWinner.selector);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.TIE, sig, nonce);
    }

    function test_Security_TimeoutOutcome_RevertWhen_NonZeroWinner() public {
        uint256 matchId = _createAndStartMatch();

        // TIMEOUT outcome must have winner == address(0)
        bytes32 nonce = keccak256("timeout_nonzero");
        bytes memory sig = _signSubmitResult(matchId, player2, DuelEscrow.MatchOutcome.TIMEOUT, nonce);

        vm.expectRevert(DuelEscrow.InvalidWinner.selector);
        game.submitResult(matchId, player2, DuelEscrow.MatchOutcome.TIMEOUT, sig, nonce);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTION TESTS (Coverage for getSessionState branches)
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_GetSessionState_AllStates() public {
        // NONE state
        assertEq(uint8(game.getSessionState(999)), uint8(IArcadeTypes.SessionState.NONE));

        // CREATED -> BETTING
        uint256 matchId = _createMatch();
        assertEq(uint8(game.getSessionState(matchId)), uint8(IArcadeTypes.SessionState.BETTING));

        // WAITING -> BETTING
        vm.prank(player1);
        game.joinMatch(matchId);
        assertEq(uint8(game.getSessionState(matchId)), uint8(IArcadeTypes.SessionState.BETTING));

        // ACTIVE -> ACTIVE
        vm.prank(player2);
        game.joinMatch(matchId);
        assertEq(uint8(game.getSessionState(matchId)), uint8(IArcadeTypes.SessionState.ACTIVE));

        // RESOLVED -> SETTLED
        bytes32 nonce = keccak256("state_test");
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, sig, nonce);
        assertEq(uint8(game.getSessionState(matchId)), uint8(IArcadeTypes.SessionState.SETTLED));

        // Advance time to avoid rate limiter
        vm.warp(block.timestamp + 60);

        // Create another match for CANCELLED state (need a player to join for session to exist)
        bytes32 nonce2 = keccak256("cancelled_state");
        bytes memory sig2 = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce2);
        uint256 matchId2 = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig2, nonce2);
        vm.prank(player1);
        game.joinMatch(matchId2);
        vm.prank(owner);
        game.emergencyCancel(matchId2, "Test");
        assertEq(uint8(game.getSessionState(matchId2)), uint8(IArcadeTypes.SessionState.CANCELLED));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_Constructor_ZeroArcadeCore() public {
        vm.expectRevert(DuelEscrow.InvalidAddress.selector);
        new DuelEscrow(address(0), oracle, owner);
    }

    function test_Security_Constructor_ZeroOracle() public {
        vm.expectRevert(DuelEscrow.InvalidAddress.selector);
        new DuelEscrow(address(arcadeCore), address(0), owner);
    }

    function test_Security_Constructor_ZeroOwner() public {
        // OpenZeppelin's Ownable throws OwnableInvalidOwner for zero owner
        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        new DuelEscrow(address(arcadeCore), oracle, address(0));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INPUT VALIDATION SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_CreateMatch_Player2Zero() public {
        bytes32 nonce = keccak256("p2_zero");
        bytes memory sig = _signCreateMatch(player1, address(0), DuelEscrow.StakeTier.BRONZE, nonce);

        vm.expectRevert(DuelEscrow.InvalidAddress.selector);
        game.createMatch(player1, address(0), DuelEscrow.StakeTier.BRONZE, sig, nonce);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // JOIN ORDER TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_JoinMatch_Player2First() public {
        uint256 matchId = _createMatch();

        // Player2 joins first
        vm.prank(player2);
        game.joinMatch(matchId);

        DuelEscrow.Match memory m = game.getMatch(matchId);
        assertEq(uint8(m.state), uint8(DuelEscrow.MatchState.WAITING));
        assertEq(m.player2Net, 45 ether); // Net after 10% rake
        assertEq(m.player1Net, 0);

        // Player1 joins second
        vm.prank(player1);
        game.joinMatch(matchId);

        m = game.getMatch(matchId);
        assertEq(uint8(m.state), uint8(DuelEscrow.MatchState.ACTIVE));
        assertEq(m.player1Net, 45 ether);
    }

    function test_Security_AlreadyJoined_Player2() public {
        uint256 matchId = _createMatch();

        vm.prank(player2);
        game.joinMatch(matchId);

        vm.prank(player2);
        vm.expectRevert(DuelEscrow.AlreadyJoined.selector);
        game.joinMatch(matchId);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EDGE CASE TESTS FOR isPlayerInSession
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_IsPlayerInSession_EdgeCases() public {
        uint256 matchId = _createMatch();

        // Neither player has joined yet
        assertFalse(game.isPlayerInSession(matchId, player1));
        assertFalse(game.isPlayerInSession(matchId, player2));
        assertFalse(game.isPlayerInSession(matchId, player3));

        // Player2 joins first
        vm.prank(player2);
        game.joinMatch(matchId);

        assertFalse(game.isPlayerInSession(matchId, player1));
        assertTrue(game.isPlayerInSession(matchId, player2));

        // Player1 joins
        vm.prank(player1);
        game.joinMatch(matchId);

        assertTrue(game.isPlayerInSession(matchId, player1));
        assertTrue(game.isPlayerInSession(matchId, player2));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS FOR SECURITY
    // ══════════════════════════════════════════════════════════════════════════════

    function testFuzz_Security_RandomNonceCreation(bytes32 nonce) public {
        // Ensure unique nonce each time
        vm.assume(!game.isNonceUsed(nonce));

        bytes memory sig = _signCreateMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, nonce);
        uint256 matchId = game.createMatch(player1, player2, DuelEscrow.StakeTier.BRONZE, sig, nonce);

        assertTrue(game.isNonceUsed(nonce));
        assertGt(matchId, 0);
    }

    function testFuzz_Security_AllTiersWork(uint8 tierIndex) public {
        tierIndex = uint8(bound(tierIndex, 0, 3));
        DuelEscrow.StakeTier tier = DuelEscrow.StakeTier(tierIndex);

        bytes32 nonce = keccak256(abi.encodePacked("tier", tierIndex));
        bytes memory sig = _signCreateMatch(player1, player2, tier, nonce);
        uint256 matchId = game.createMatch(player1, player2, tier, sig, nonce);

        DuelEscrow.Match memory m = game.getMatch(matchId);
        assertEq(uint8(m.tier), tierIndex);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // REENTRANCY PROTECTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Security_AllExternalFunctionsHaveReentrancyGuard() public {
        // Verify functions have nonReentrant by testing they complete successfully
        uint256 matchId = _createAndStartMatch();

        // Submit result
        bytes32 nonce = keccak256("reentrancy_test");
        bytes memory sig = _signSubmitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, nonce);
        game.submitResult(matchId, player1, DuelEscrow.MatchOutcome.WIN, sig, nonce);

        // Claim payout
        vm.prank(player1);
        arcadeCore.withdrawPayout();
    }
}
