// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { DataToken } from "../src/token/DataToken.sol";
import { ArcadeCore } from "../src/arcade/ArcadeCore.sol";
import { IArcadeCore } from "../src/arcade/interfaces/IArcadeCore.sol";

/// @title ArcadeCore Tests
/// @notice Tests for the GHOSTNET Arcade core contract with focus on batch operations
contract ArcadeCoreTest is Test {
    DataToken public token;
    ArcadeCore public arcadeCore;
    ArcadeCore public implementation;

    address public treasury = makeAddr("treasury");
    address public owner = makeAddr("owner");
    address public game = makeAddr("game");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 constant TOTAL_SUPPLY = 100_000_000 * 1e18;
    uint256 constant ALICE_BALANCE = 40_000_000 * 1e18;
    uint256 constant BOB_BALANCE = 30_000_000 * 1e18;
    uint256 constant CHARLIE_BALANCE = 30_000_000 * 1e18;
    // Note: Total = 100M which equals TOTAL_SUPPLY

    uint256 constant SESSION_1 = 1;
    uint256 constant SESSION_2 = 2;

    function setUp() public {
        // Deploy token
        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = ALICE_BALANCE;
        amounts[1] = BOB_BALANCE;
        amounts[2] = CHARLIE_BALANCE;

        token = new DataToken(treasury, owner, recipients, amounts);

        // Deploy ArcadeCore implementation
        implementation = new ArcadeCore();

        // Deploy proxy
        bytes memory initData =
            abi.encodeCall(ArcadeCore.initialize, (address(token), address(0), treasury, owner));

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        arcadeCore = ArcadeCore(address(proxy));

        // Exclude ArcadeCore from tax
        vm.prank(owner);
        token.setTaxExclusion(address(arcadeCore), true);

        // Register game
        IArcadeCore.GameConfig memory gameConfig = IArcadeCore.GameConfig({
            minEntry: 1 * 1e18,
            maxEntry: 1000 * 1e18,
            rakeBps: 500, // 5% rake
            burnBps: 2000, // 20% of rake burned
            requiresPosition: false,
            paused: false
        });

        vm.prank(owner);
        arcadeCore.registerGame(game, gameConfig);

        // Approve token spending
        vm.prank(alice);
        token.approve(address(arcadeCore), type(uint256).max);
        vm.prank(bob);
        token.approve(address(arcadeCore), type(uint256).max);
        vm.prank(charlie);
        token.approve(address(arcadeCore), type(uint256).max);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SETUP HELPERS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Helper to create a session with entry
    function _createSessionWithEntry(
        uint256 sessionId,
        address player,
        uint256 amount
    ) internal returns (uint256 netAmount) {
        vm.prank(game);
        netAmount = arcadeCore.processEntry(player, amount, sessionId);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INITIALIZATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Initialize_SetsCorrectState() public {
        assertTrue(arcadeCore.isGameRegistered(game));
        assertEq(arcadeCore.MAX_BATCH_SIZE(), 100);
    }

    function test_Initialize_RevertWhen_ZeroAddresses() public {
        ArcadeCore newImpl = new ArcadeCore();

        vm.expectRevert(IArcadeCore.InvalidAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeCall(ArcadeCore.initialize, (address(0), address(0), treasury, owner))
        );

        vm.expectRevert(IArcadeCore.InvalidAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeCall(ArcadeCore.initialize, (address(token), address(0), address(0), owner))
        );

        vm.expectRevert(IArcadeCore.InvalidAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeCall(
                ArcadeCore.initialize, (address(token), address(0), treasury, address(0))
            )
        );
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SINGLE CREDIT PAYOUT TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_CreditPayout_Success() public {
        // Setup: Create session with entry
        uint256 netAmount = _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);

        // Credit payout
        uint256 payoutAmount = 50 * 1e18;
        uint256 burnAmount = 5 * 1e18;

        vm.prank(game);
        arcadeCore.creditPayout(SESSION_1, alice, payoutAmount, burnAmount, true);

        // Verify
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.totalPaid, payoutAmount + burnAmount);
        assertEq(arcadeCore.getPendingPayout(alice), payoutAmount);
    }

    function test_CreditPayout_RevertWhen_SessionNotFound() public {
        vm.prank(game);
        vm.expectRevert(IArcadeCore.SessionNotFound.selector);
        arcadeCore.creditPayout(999, alice, 10 * 1e18, 0, true);
    }

    function test_CreditPayout_RevertWhen_SessionGameMismatch() public {
        _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);

        // Register another game
        address otherGame = makeAddr("otherGame");
        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 1 * 1e18,
            maxEntry: 1000 * 1e18,
            rakeBps: 500,
            burnBps: 2000,
            requiresPosition: false,
            paused: false
        });
        vm.prank(owner);
        arcadeCore.registerGame(otherGame, config);

        // Other game tries to credit payout
        vm.prank(otherGame);
        vm.expectRevert(IArcadeCore.SessionGameMismatch.selector);
        arcadeCore.creditPayout(SESSION_1, alice, 10 * 1e18, 0, true);
    }

    function test_CreditPayout_RevertWhen_PayoutExceedsPrizePool() public {
        uint256 netAmount = _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);

        // Try to payout more than prize pool
        vm.prank(game);
        vm.expectRevert(IArcadeCore.PayoutExceedsPrizePool.selector);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount + 1, 0, true);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BATCH CREDIT PAYOUT TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_BatchCreditPayouts_Success() public {
        // Setup: Create session with multiple entries
        _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);
        _createSessionWithEntry(SESSION_1, bob, 100 * 1e18);
        _createSessionWithEntry(SESSION_1, charlie, 100 * 1e18);

        // Create batch arrays
        uint256[] memory sessionIds = new uint256[](3);
        sessionIds[0] = SESSION_1;
        sessionIds[1] = SESSION_1;
        sessionIds[2] = SESSION_1;

        address[] memory players = new address[](3);
        players[0] = alice;
        players[1] = bob;
        players[2] = charlie;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 30 * 1e18;
        amounts[1] = 25 * 1e18;
        amounts[2] = 20 * 1e18;

        uint256[] memory burnAmounts = new uint256[](3);
        burnAmounts[0] = 3 * 1e18;
        burnAmounts[1] = 2 * 1e18;
        burnAmounts[2] = 1 * 1e18;

        bool[] memory results = new bool[](3);
        results[0] = true; // Alice won
        results[1] = true; // Bob won
        results[2] = false; // Charlie lost

        // Execute batch
        vm.prank(game);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);

        // Verify payouts
        assertEq(arcadeCore.getPendingPayout(alice), 30 * 1e18);
        assertEq(arcadeCore.getPendingPayout(bob), 25 * 1e18);
        assertEq(arcadeCore.getPendingPayout(charlie), 20 * 1e18);

        // Verify player stats
        IArcadeCore.PlayerStats memory aliceStats = arcadeCore.getPlayerStats(alice);
        assertEq(aliceStats.totalWins, 1);

        IArcadeCore.PlayerStats memory charlieStats = arcadeCore.getPlayerStats(charlie);
        assertEq(charlieStats.totalLosses, 1);
    }

    function test_BatchCreditPayouts_SingleElement() public {
        _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);

        uint256[] memory sessionIds = new uint256[](1);
        sessionIds[0] = SESSION_1;

        address[] memory players = new address[](1);
        players[0] = alice;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50 * 1e18;

        uint256[] memory burnAmounts = new uint256[](1);
        burnAmounts[0] = 5 * 1e18;

        bool[] memory results = new bool[](1);
        results[0] = true;

        vm.prank(game);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);

        assertEq(arcadeCore.getPendingPayout(alice), 50 * 1e18);
    }

    function test_BatchCreditPayouts_ExactlyMaxBatchSize() public {
        // Alice already has ALICE_BALANCE, use a reasonable entry
        uint256 largeEntry = 1000 * 1e18;
        _createSessionWithEntry(SESSION_1, alice, largeEntry);

        // Create arrays at exactly MAX_BATCH_SIZE
        uint256 batchSize = arcadeCore.MAX_BATCH_SIZE();

        uint256[] memory sessionIds = new uint256[](batchSize);
        address[] memory players = new address[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);
        uint256[] memory burnAmounts = new uint256[](batchSize);
        bool[] memory results = new bool[](batchSize);

        for (uint256 i; i < batchSize; ++i) {
            sessionIds[i] = SESSION_1;
            players[i] = alice;
            amounts[i] = 1 * 1e15; // Small amount to fit within prize pool
            burnAmounts[i] = 0;
            results[i] = true;
        }

        // Should succeed at exactly MAX_BATCH_SIZE
        vm.prank(game);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);

        assertGt(arcadeCore.getPendingPayout(alice), 0);
    }

    function test_BatchCreditPayouts_MultipleSessionsInBatch() public {
        // Create two different sessions
        _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);
        _createSessionWithEntry(SESSION_2, bob, 100 * 1e18);

        uint256[] memory sessionIds = new uint256[](2);
        sessionIds[0] = SESSION_1;
        sessionIds[1] = SESSION_2;

        address[] memory players = new address[](2);
        players[0] = alice;
        players[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 30 * 1e18;
        amounts[1] = 40 * 1e18;

        uint256[] memory burnAmounts = new uint256[](2);
        burnAmounts[0] = 0;
        burnAmounts[1] = 0;

        bool[] memory results = new bool[](2);
        results[0] = true;
        results[1] = true;

        vm.prank(game);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);

        assertEq(arcadeCore.getPendingPayout(alice), 30 * 1e18);
        assertEq(arcadeCore.getPendingPayout(bob), 40 * 1e18);
    }

    function test_BatchCreditPayouts_EmitsEvent() public {
        _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);

        uint256[] memory sessionIds = new uint256[](1);
        sessionIds[0] = SESSION_1;

        address[] memory players = new address[](1);
        players[0] = alice;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50 * 1e18;

        uint256[] memory burnAmounts = new uint256[](1);
        burnAmounts[0] = 5 * 1e18;

        bool[] memory results = new bool[](1);
        results[0] = true;

        vm.expectEmit(true, false, false, true);
        emit IArcadeCore.BatchPayoutProcessed(game, 1, 50 * 1e18, 5 * 1e18);

        vm.prank(game);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BATCH VALIDATION TESTS - ARRAY LENGTH MISMATCH
    // ══════════════════════════════════════════════════════════════════════════════

    function test_BatchCreditPayouts_RevertWhen_PlayersLengthMismatch() public {
        _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);

        uint256[] memory sessionIds = new uint256[](2);
        address[] memory players = new address[](3); // Mismatched!
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory burnAmounts = new uint256[](2);
        bool[] memory results = new bool[](2);

        vm.prank(game);
        vm.expectRevert(
            abi.encodeWithSelector(IArcadeCore.ArrayLengthMismatch.selector, 2, 3, 2, 2, 2)
        );
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    function test_BatchCreditPayouts_RevertWhen_AmountsLengthMismatch() public {
        _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);

        uint256[] memory sessionIds = new uint256[](2);
        address[] memory players = new address[](2);
        uint256[] memory amounts = new uint256[](1); // Mismatched!
        uint256[] memory burnAmounts = new uint256[](2);
        bool[] memory results = new bool[](2);

        vm.prank(game);
        vm.expectRevert(
            abi.encodeWithSelector(IArcadeCore.ArrayLengthMismatch.selector, 2, 2, 1, 2, 2)
        );
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    function test_BatchCreditPayouts_RevertWhen_BurnAmountsLengthMismatch() public {
        _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);

        uint256[] memory sessionIds = new uint256[](2);
        address[] memory players = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory burnAmounts = new uint256[](4); // Mismatched!
        bool[] memory results = new bool[](2);

        vm.prank(game);
        vm.expectRevert(
            abi.encodeWithSelector(IArcadeCore.ArrayLengthMismatch.selector, 2, 2, 2, 4, 2)
        );
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    function test_BatchCreditPayouts_RevertWhen_ResultsLengthMismatch() public {
        _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);

        uint256[] memory sessionIds = new uint256[](2);
        address[] memory players = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory burnAmounts = new uint256[](2);
        bool[] memory results = new bool[](5); // Mismatched!

        vm.prank(game);
        vm.expectRevert(
            abi.encodeWithSelector(IArcadeCore.ArrayLengthMismatch.selector, 2, 2, 2, 2, 5)
        );
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    function test_BatchCreditPayouts_RevertWhen_AllArraysDifferentLengths() public {
        uint256[] memory sessionIds = new uint256[](1);
        address[] memory players = new address[](2);
        uint256[] memory amounts = new uint256[](3);
        uint256[] memory burnAmounts = new uint256[](4);
        bool[] memory results = new bool[](5);

        vm.prank(game);
        vm.expectRevert(
            abi.encodeWithSelector(IArcadeCore.ArrayLengthMismatch.selector, 1, 2, 3, 4, 5)
        );
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BATCH VALIDATION TESTS - EMPTY BATCH
    // ══════════════════════════════════════════════════════════════════════════════

    function test_BatchCreditPayouts_RevertWhen_EmptyArrays() public {
        uint256[] memory sessionIds = new uint256[](0);
        address[] memory players = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        uint256[] memory burnAmounts = new uint256[](0);
        bool[] memory results = new bool[](0);

        vm.prank(game);
        vm.expectRevert(IArcadeCore.EmptyBatch.selector);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BATCH VALIDATION TESTS - BATCH TOO LARGE
    // ══════════════════════════════════════════════════════════════════════════════

    function test_BatchCreditPayouts_RevertWhen_BatchTooLarge() public {
        uint256 oversizedBatch = arcadeCore.MAX_BATCH_SIZE() + 1;

        uint256[] memory sessionIds = new uint256[](oversizedBatch);
        address[] memory players = new address[](oversizedBatch);
        uint256[] memory amounts = new uint256[](oversizedBatch);
        uint256[] memory burnAmounts = new uint256[](oversizedBatch);
        bool[] memory results = new bool[](oversizedBatch);

        vm.prank(game);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArcadeCore.BatchTooLarge.selector, oversizedBatch, arcadeCore.MAX_BATCH_SIZE()
            )
        );
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    function test_BatchCreditPayouts_RevertWhen_BatchWayTooLarge() public {
        uint256 hugeSize = 1000;

        uint256[] memory sessionIds = new uint256[](hugeSize);
        address[] memory players = new address[](hugeSize);
        uint256[] memory amounts = new uint256[](hugeSize);
        uint256[] memory burnAmounts = new uint256[](hugeSize);
        bool[] memory results = new bool[](hugeSize);

        vm.prank(game);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArcadeCore.BatchTooLarge.selector, hugeSize, arcadeCore.MAX_BATCH_SIZE()
            )
        );
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BATCH VALIDATION TESTS - SESSION VALIDATION
    // ══════════════════════════════════════════════════════════════════════════════

    function test_BatchCreditPayouts_RevertWhen_SessionNotFound() public {
        uint256[] memory sessionIds = new uint256[](1);
        sessionIds[0] = 999; // Non-existent session

        address[] memory players = new address[](1);
        players[0] = alice;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10 * 1e18;

        uint256[] memory burnAmounts = new uint256[](1);
        burnAmounts[0] = 0;

        bool[] memory results = new bool[](1);
        results[0] = true;

        vm.prank(game);
        vm.expectRevert(IArcadeCore.SessionNotFound.selector);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    function test_BatchCreditPayouts_RevertWhen_SessionNotActive() public {
        _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);

        // Settle the session first
        vm.prank(game);
        arcadeCore.settleSession(SESSION_1);

        uint256[] memory sessionIds = new uint256[](1);
        sessionIds[0] = SESSION_1;

        address[] memory players = new address[](1);
        players[0] = alice;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10 * 1e18;

        uint256[] memory burnAmounts = new uint256[](1);
        burnAmounts[0] = 0;

        bool[] memory results = new bool[](1);
        results[0] = true;

        vm.prank(game);
        vm.expectRevert(IArcadeCore.SessionNotActive.selector);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    function test_BatchCreditPayouts_RevertWhen_PayoutExceedsPrizePool() public {
        uint256 netAmount = _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);

        uint256[] memory sessionIds = new uint256[](1);
        sessionIds[0] = SESSION_1;

        address[] memory players = new address[](1);
        players[0] = alice;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = netAmount + 1; // Exceeds prize pool

        uint256[] memory burnAmounts = new uint256[](1);
        burnAmounts[0] = 0;

        bool[] memory results = new bool[](1);
        results[0] = true;

        vm.prank(game);
        vm.expectRevert(IArcadeCore.PayoutExceedsPrizePool.selector);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    function test_BatchCreditPayouts_RevertWhen_NotRegisteredGame() public {
        _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);

        uint256[] memory sessionIds = new uint256[](1);
        sessionIds[0] = SESSION_1;

        address[] memory players = new address[](1);
        players[0] = alice;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10 * 1e18;

        uint256[] memory burnAmounts = new uint256[](1);
        burnAmounts[0] = 0;

        bool[] memory results = new bool[](1);
        results[0] = true;

        // Unregistered game tries to call
        vm.prank(makeAddr("unregistered"));
        vm.expectRevert(IArcadeCore.GameNotRegistered.selector);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BATCH PARTIAL FAILURE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_BatchCreditPayouts_RevertsAtomically() public {
        // Setup: Create session
        _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);

        // Create batch where second payout would exceed prize pool
        uint256[] memory sessionIds = new uint256[](2);
        sessionIds[0] = SESSION_1;
        sessionIds[1] = SESSION_1;

        address[] memory players = new address[](2);
        players[0] = alice;
        players[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 50 * 1e18; // First payout valid
        amounts[1] = 50 * 1e18; // Second would exceed (only ~95 * 1e18 in pool after rake)

        uint256[] memory burnAmounts = new uint256[](2);
        burnAmounts[0] = 0;
        burnAmounts[1] = 0;

        bool[] memory results = new bool[](2);
        results[0] = true;
        results[1] = true;

        // Should revert - batch is atomic
        vm.prank(game);
        vm.expectRevert(IArcadeCore.PayoutExceedsPrizePool.selector);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);

        // Verify nothing was paid out (atomic failure)
        assertEq(arcadeCore.getPendingPayout(alice), 0);
        assertEq(arcadeCore.getPendingPayout(bob), 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function testFuzz_BatchCreditPayouts_ValidBatchSizes(
        uint8 batchSize
    ) public {
        // Bound to valid range (1 to MAX_BATCH_SIZE)
        batchSize = uint8(bound(batchSize, 1, 100));

        // Alice already has ALICE_BALANCE, use a reasonable entry
        uint256 largeEntry = 1000 * 1e18;
        _createSessionWithEntry(SESSION_1, alice, largeEntry);

        // Create batch arrays
        uint256[] memory sessionIds = new uint256[](batchSize);
        address[] memory players = new address[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);
        uint256[] memory burnAmounts = new uint256[](batchSize);
        bool[] memory results = new bool[](batchSize);

        for (uint256 i; i < batchSize; ++i) {
            sessionIds[i] = SESSION_1;
            players[i] = alice;
            amounts[i] = 1 * 1e15; // Small amount
            burnAmounts[i] = 0;
            results[i] = true;
        }

        vm.prank(game);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);

        assertGt(arcadeCore.getPendingPayout(alice), 0);
    }

    function testFuzz_BatchCreditPayouts_RevertWhen_ArrayMismatch(
        uint256 sessionsLen,
        uint256 playersLen,
        uint256 amountsLen,
        uint256 burnAmountsLen,
        uint256 resultsLen
    ) public {
        // Bound to reasonable sizes
        sessionsLen = bound(sessionsLen, 1, 10);
        playersLen = bound(playersLen, 1, 10);
        amountsLen = bound(amountsLen, 1, 10);
        burnAmountsLen = bound(burnAmountsLen, 1, 10);
        resultsLen = bound(resultsLen, 1, 10);

        // Skip if all lengths happen to be equal (valid case)
        if (
            sessionsLen == playersLen && playersLen == amountsLen && amountsLen == burnAmountsLen
                && burnAmountsLen == resultsLen
        ) {
            return;
        }

        uint256[] memory sessionIds = new uint256[](sessionsLen);
        address[] memory players = new address[](playersLen);
        uint256[] memory amounts = new uint256[](amountsLen);
        uint256[] memory burnAmounts = new uint256[](burnAmountsLen);
        bool[] memory results = new bool[](resultsLen);

        vm.prank(game);
        vm.expectRevert(); // Should revert with ArrayLengthMismatch
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SESSION LIFECYCLE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_SettleSession_Success() public {
        _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);

        // Credit partial payout
        vm.prank(game);
        arcadeCore.creditPayout(SESSION_1, alice, 30 * 1e18, 0, true);

        uint256 treasuryBefore = token.balanceOf(treasury);

        // Settle session
        vm.prank(game);
        arcadeCore.settleSession(SESSION_1);

        // Verify state
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(uint8(session.state), uint8(IArcadeCore.SessionState.SETTLED));
        assertGt(session.settledAt, 0);

        // Verify remaining went to treasury
        uint256 treasuryAfter = token.balanceOf(treasury);
        assertGt(treasuryAfter, treasuryBefore);
    }

    function test_CancelSession_Success() public {
        _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);

        vm.prank(game);
        arcadeCore.cancelSession(SESSION_1);

        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(uint8(session.state), uint8(IArcadeCore.SessionState.CANCELLED));
    }

    function test_EmergencyRefund_Success() public {
        // Entry of 100 ether, rake is 5%, so gross = 100, net = 95
        uint256 entryAmount = 100 * 1e18;
        uint256 netAmount = _createSessionWithEntry(SESSION_1, alice, entryAmount);

        // Verify gross deposit is tracked (for audit trail)
        uint256 grossDeposit = arcadeCore.getSessionGrossDeposit(SESSION_1, alice);
        assertEq(grossDeposit, entryAmount, "Gross deposit should match entry");

        // Verify net deposit (what's actually refundable - rake already distributed)
        uint256 netDeposit = arcadeCore.getSessionDeposit(SESSION_1, alice);
        assertEq(netDeposit, netAmount, "Net deposit should match net amount");

        // Refund the NET amount (not gross - rake was already burned/sent to treasury)
        vm.prank(game);
        arcadeCore.emergencyRefund(SESSION_1, alice, netAmount);

        // Refund should be the NET amount
        assertEq(arcadeCore.getPendingPayout(alice), netAmount);
        // Check refund is marked
        assertTrue(arcadeCore.isRefunded(SESSION_1, alice));
    }

    function test_EmergencyRefund_RevertWhen_RefundExceedsDeposit() public {
        uint256 entryAmount = 100 * 1e18;
        _createSessionWithEntry(SESSION_1, alice, entryAmount);

        // Try to refund more than gross deposit (which equals entry amount)
        vm.prank(game);
        vm.expectRevert(IArcadeCore.RefundExceedsDeposit.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, entryAmount + 1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // WITHDRAWAL TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_WithdrawPayout_Success() public {
        _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);

        vm.prank(game);
        arcadeCore.creditPayout(SESSION_1, alice, 50 * 1e18, 0, true);

        uint256 balanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        uint256 withdrawn = arcadeCore.withdrawPayout();

        assertEq(withdrawn, 50 * 1e18);
        assertEq(token.balanceOf(alice), balanceBefore + 50 * 1e18);
        assertEq(arcadeCore.getPendingPayout(alice), 0);
    }

    function test_WithdrawPayout_ReturnsZero_WhenNoPending() public {
        vm.prank(alice);
        uint256 withdrawn = arcadeCore.withdrawPayout();

        assertEq(withdrawn, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_EmergencyQuarantineGame_Success() public {
        _createSessionWithEntry(SESSION_1, alice, 100 * 1e18);
        _createSessionWithEntry(SESSION_2, bob, 100 * 1e18);

        vm.prank(owner);
        arcadeCore.emergencyQuarantineGame(game);

        // Verify game is paused
        IArcadeCore.GameConfig memory config = arcadeCore.getGameConfig(game);
        assertTrue(config.paused);

        // Verify sessions are cancelled
        IArcadeCore.SessionRecord memory session1 = arcadeCore.getSession(SESSION_1);
        assertEq(uint8(session1.state), uint8(IArcadeCore.SessionState.CANCELLED));

        IArcadeCore.SessionRecord memory session2 = arcadeCore.getSession(SESSION_2);
        assertEq(uint8(session2.state), uint8(IArcadeCore.SessionState.CANCELLED));
    }

    function test_Pause_BlocksNewEntries() public {
        vm.prank(owner);
        arcadeCore.pause();

        vm.prank(game);
        vm.expectRevert();
        arcadeCore.processEntry(alice, 100 * 1e18, SESSION_1);
    }
}
