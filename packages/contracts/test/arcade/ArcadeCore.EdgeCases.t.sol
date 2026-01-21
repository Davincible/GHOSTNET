// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";
import { ArcadeCore } from "../../src/arcade/ArcadeCore.sol";
import { ArcadeCoreStorage } from "../../src/arcade/ArcadeCoreStorage.sol";
import { IArcadeCore } from "../../src/arcade/interfaces/IArcadeCore.sol";
import { DataToken } from "../../src/token/DataToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ArcadeCore Edge Cases and Boundary Tests
/// @notice Comprehensive tests for edge cases, boundary conditions, and corner cases
/// @dev Tests cover:
///      1. Zero value cases
///      2. Maximum value cases
///      3. Boundary conditions
///      4. Timing edge cases
///      5. State edge cases
///      6. Array edge cases
///      7. Precision edge cases
///      8. Re-entry edge cases
///      9. Configuration edge cases
///      10. Address edge cases
///      11. Session lifecycle edge cases
///      12. Concurrent operation edge cases
contract ArcadeCoreEdgeCasesTest is Test {
    // ══════════════════════════════════════════════════════════════════════════════
    // TEST FIXTURES
    // ══════════════════════════════════════════════════════════════════════════════

    ArcadeCore public arcadeCore;
    DataToken public dataToken;

    address public admin = makeAddr("admin");
    address public treasury = makeAddr("treasury");
    address public game = makeAddr("game");
    address public gameB = makeAddr("gameB");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 public constant SESSION_1 = 1;
    uint256 public constant SESSION_2 = 2;
    uint256 public constant MIN_ENTRY = 1 ether;
    uint256 public constant MAX_ENTRY = 10_000 ether;
    uint256 public constant RAKE_BPS = 500; // 5%
    uint256 public constant BURN_BPS = 2000; // 20% of rake
    uint256 public constant BPS = 10_000;

    // ══════════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Calculate expected net amount after rake
    function _calculateNetAmount(
        uint256 gross,
        uint256 rakeBps
    ) internal pure returns (uint256) {
        uint256 rake = (gross * rakeBps) / BPS;
        return gross - rake;
    }

    /// @notice Calculate expected rake from gross amount
    function _calculateRake(
        uint256 gross,
        uint256 rakeBps
    ) internal pure returns (uint256) {
        return (gross * rakeBps) / BPS;
    }

    /// @notice Calculate expected burn from rake
    function _calculateBurn(
        uint256 rake,
        uint256 burnBps
    ) internal pure returns (uint256) {
        return (rake * burnBps) / BPS;
    }

    /// @notice Standard net amount calculation
    function _netAmount(
        uint256 gross
    ) internal pure returns (uint256) {
        return _calculateNetAmount(gross, RAKE_BPS);
    }

    /// @notice Get default game config
    function _defaultConfig() internal pure returns (IArcadeCore.GameConfig memory) {
        return IArcadeCore.GameConfig({
            minEntry: MIN_ENTRY,
            maxEntry: MAX_ENTRY,
            rakeBps: uint16(RAKE_BPS),
            burnBps: uint16(BURN_BPS),
            requiresPosition: false,
            paused: false
        });
    }

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

        // Setup game config
        arcadeCore.registerGame(game, _defaultConfig());

        // Fund test accounts
        dataToken.transfer(alice, 10_000_000 ether);
        dataToken.transfer(bob, 10_000_000 ether);
        dataToken.transfer(charlie, 10_000_000 ether);

        // Set DATA exclusions for arcade (cleaner math)
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

    // ══════════════════════════════════════════════════════════════════════════════
    // 1. ZERO VALUE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Entry with zero amount should fail - fundamental check
    /// @dev Zero entries would create sessions without any prize pool funding
    function test_EdgeCase_ProcessEntry_ZeroAmount() public {
        vm.prank(game);
        vm.expectRevert(IArcadeCore.InvalidEntryAmount.selector);
        arcadeCore.processEntry(alice, 0, SESSION_1);
    }

    /// @notice CreditPayout with zero payout AND zero burn should succeed (player loss)
    /// @dev Games need to record losses for stats even with no payout
    function test_EdgeCase_CreditPayout_ZeroPayout_ZeroBurn() public {
        // Setup session
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // Zero payout, zero burn - valid (player loses, game records it)
        vm.prank(game);
        arcadeCore.creditPayout(SESSION_1, alice, 0, 0, false);

        // Stats should update (loss recorded)
        IArcadeCore.PlayerStats memory stats = arcadeCore.getPlayerStats(alice);
        assertEq(stats.totalLosses, 1, "Loss should be recorded");
        assertEq(stats.totalWins, 0, "No wins");
    }

    /// @notice CreditPayout with zero payout but non-zero burn should succeed
    /// @dev Some game modes may burn player's stake with no return
    function test_EdgeCase_CreditPayout_ZeroPayout_NonZeroBurn() public {
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        uint256 burnAmount = 10 ether;

        // Zero payout but burn some of prize pool
        vm.prank(game);
        arcadeCore.creditPayout(SESSION_1, alice, 0, burnAmount, false);

        // Session totalPaid should include burn
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.totalPaid, burnAmount, "Burn should count toward totalPaid");
    }

    /// @notice CreditPayout with non-zero payout but zero burn should succeed
    /// @dev Standard payout scenario
    function test_EdgeCase_CreditPayout_NonZeroPayout_ZeroBurn() public {
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        uint256 payoutAmount = 50 ether;

        vm.prank(game);
        arcadeCore.creditPayout(SESSION_1, alice, payoutAmount, 0, true);

        assertEq(arcadeCore.getPendingPayout(alice), payoutAmount);
    }

    /// @notice EmergencyRefund with zero amount should fail
    /// @dev Zero refunds are meaningless and waste gas
    function test_EdgeCase_EmergencyRefund_ZeroAmount() public {
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        vm.prank(game);
        arcadeCore.cancelSession(SESSION_1);

        vm.prank(game);
        vm.expectRevert(IArcadeCore.InvalidRefundAmount.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, 0);
    }

    /// @notice SettleSession with zero prize pool should succeed
    /// @dev Edge case where all payouts/burns have consumed the pool
    function test_EdgeCase_SettleSession_ZeroPrizePool() public {
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // Payout entire prize pool
        vm.prank(game);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount, 0, true);

        // Settle with zero remaining
        vm.prank(game);
        arcadeCore.settleSession(SESSION_1);

        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(uint8(session.state), uint8(IArcadeCore.SessionState.SETTLED));
        assertEq(session.prizePool, session.totalPaid, "Pool fully consumed");
    }

    /// @notice Batch with all zero amounts should succeed (all losses)
    /// @dev Valid for recording multiple player losses in one tx
    function test_EdgeCase_BatchCreditPayouts_AllZeroAmounts() public {
        // Setup session with multiple players
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);
        vm.warp(block.timestamp + 2);
        vm.prank(game);
        arcadeCore.processEntry(bob, 100 ether, SESSION_1);

        // Batch credit with all zeros (all players lose)
        uint256[] memory sessionIds = new uint256[](2);
        address[] memory players = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory burnAmounts = new uint256[](2);
        bool[] memory results = new bool[](2);

        sessionIds[0] = SESSION_1;
        sessionIds[1] = SESSION_1;
        players[0] = alice;
        players[1] = bob;
        amounts[0] = 0;
        amounts[1] = 0;
        burnAmounts[0] = 0;
        burnAmounts[1] = 0;
        results[0] = false;
        results[1] = false;

        vm.prank(game);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);

        // Both should have loss recorded
        assertEq(arcadeCore.getPlayerStats(alice).totalLosses, 1);
        assertEq(arcadeCore.getPlayerStats(bob).totalLosses, 1);
    }

    /// @notice WithdrawPayout with zero pending should return zero gracefully
    /// @dev Not an error - just no-op
    function test_EdgeCase_WithdrawPayout_ZeroPending() public {
        uint256 balanceBefore = dataToken.balanceOf(alice);

        vm.prank(alice);
        uint256 withdrawn = arcadeCore.withdrawPayout();

        assertEq(withdrawn, 0, "Should return 0 for zero pending");
        assertEq(dataToken.balanceOf(alice), balanceBefore, "Balance unchanged");
    }

    /// @notice GetSession with ID 0 should return empty record
    /// @dev ID 0 is valid but represents non-existent session
    function test_EdgeCase_GetSession_ZeroId() public view {
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(0);

        assertEq(session.game, address(0), "Game should be zero address");
        assertEq(session.prizePool, 0, "Prize pool should be zero");
        assertEq(uint8(session.state), uint8(IArcadeCore.SessionState.NONE));
    }

    /// @notice Game config with all zeros (except paused) should be registerable
    /// @dev Zero minEntry allows any amount, zero maxEntry means no limit
    function test_EdgeCase_GameConfig_AllZeros() public {
        address newGame = makeAddr("newGame");

        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 0,
            maxEntry: 0, // 0 means no maximum
            rakeBps: 0,
            burnBps: 0,
            requiresPosition: false,
            paused: false
        });

        vm.prank(admin);
        arcadeCore.registerGame(newGame, config);

        assertTrue(arcadeCore.isGameRegistered(newGame));

        // Can process entry with zero config
        vm.prank(newGame);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_2);

        // No rake, so net equals gross
        assertEq(netAmount, 100 ether, "Zero rake means full amount to pool");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 2. MAXIMUM VALUE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice ProcessEntry with max uint256 should fail (insufficient balance)
    /// @dev Tests overflow protection and realistic limits
    function test_EdgeCase_ProcessEntry_MaxUint256() public {
        // Player cannot have max uint256 tokens
        // Should revert on transfer (insufficient balance)
        vm.prank(game);
        vm.expectRevert(); // ERC20: transfer amount exceeds balance
        arcadeCore.processEntry(alice, type(uint256).max, SESSION_1);
    }

    /// @notice Session ID can be max uint256
    /// @dev Game contracts provide session IDs - must support full range
    function test_EdgeCase_SessionId_MaxUint256() public {
        uint256 maxSessionId = type(uint256).max;

        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, maxSessionId);

        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(maxSessionId);
        assertEq(session.game, game, "Session created with max ID");
        assertGt(session.prizePool, 0, "Prize pool funded");
    }

    /// @notice Test behavior with large amounts (bounded by token supply)
    /// @dev PlayerStats uses uint128 for storage packing with AMOUNT_SCALE
    function test_EdgeCase_Amount_NearMaxUint128() public {
        // Register game with no maxEntry limit and no rake
        address bigGame = makeAddr("bigGame");
        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 0,
            maxEntry: 0, // No limit
            rakeBps: 0, // No rake for cleaner test
            burnBps: 0,
            requiresPosition: false,
            paused: false
        });

        vm.prank(admin);
        arcadeCore.registerGame(bigGame, config);

        // Use alice's existing balance (10M tokens from setUp)
        uint256 largeAmount = 5_000_000 ether; // 5 million tokens

        vm.prank(bigGame);
        uint256 netAmount = arcadeCore.processEntry(alice, largeAmount, SESSION_1);

        assertEq(netAmount, largeAmount, "Full amount added to pool");

        // Verify stats tracking at large scale
        IArcadeCore.PlayerStats memory stats = arcadeCore.getPlayerStats(alice);
        // totalWagered is scaled by 1e6, so should be largeAmount / 1e6
        uint256 expectedScaled = largeAmount / 1e6;
        assertEq(stats.totalWagered, expectedScaled, "Scaled stats recorded");
    }

    /// @notice Batch size at exactly MAX_BATCH_SIZE should succeed
    function test_EdgeCase_BatchSize_Max100() public {
        // Setup session
        vm.prank(game);
        arcadeCore.processEntry(alice, 1000 ether, SESSION_1);

        uint256 maxBatch = arcadeCore.MAX_BATCH_SIZE();
        assertEq(maxBatch, 100, "Max batch should be 100");

        // Create max-size batch
        uint256[] memory sessionIds = new uint256[](maxBatch);
        address[] memory players = new address[](maxBatch);
        uint256[] memory amounts = new uint256[](maxBatch);
        uint256[] memory burnAmounts = new uint256[](maxBatch);
        bool[] memory results = new bool[](maxBatch);

        for (uint256 i; i < maxBatch; ++i) {
            sessionIds[i] = SESSION_1;
            players[i] = alice;
            amounts[i] = 0; // Zero payouts (all losses)
            burnAmounts[i] = 0;
            results[i] = false;
        }

        vm.prank(game);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);

        // All 100 losses recorded
        assertEq(arcadeCore.getPlayerStats(alice).totalLosses, 100);
    }

    /// @notice Batch size over MAX_BATCH_SIZE should fail
    function test_EdgeCase_BatchSize_Over100() public {
        uint256 maxBatch = arcadeCore.MAX_BATCH_SIZE();
        uint256 overBatch = maxBatch + 1;

        uint256[] memory sessionIds = new uint256[](overBatch);
        address[] memory players = new address[](overBatch);
        uint256[] memory amounts = new uint256[](overBatch);
        uint256[] memory burnAmounts = new uint256[](overBatch);
        bool[] memory results = new bool[](overBatch);

        vm.prank(game);
        vm.expectRevert(
            abi.encodeWithSelector(IArcadeCore.BatchTooLarge.selector, overBatch, maxBatch)
        );
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    /// @notice Rake BPS at max (100%) should take entire entry
    function test_EdgeCase_RakeBps_Max10000() public {
        address maxRakeGame = makeAddr("maxRakeGame");

        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 1 ether,
            maxEntry: 0,
            rakeBps: 10_000, // 100% rake
            burnBps: 0,
            requiresPosition: false,
            paused: false
        });

        vm.prank(admin);
        arcadeCore.registerGame(maxRakeGame, config);

        vm.prank(maxRakeGame);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // 100% rake means zero to prize pool
        assertEq(netAmount, 0, "100% rake leaves nothing");

        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.prizePool, 0, "Prize pool should be zero");
    }

    /// @notice Burn BPS at max (100%) should burn entire rake
    function test_EdgeCase_BurnBps_Max10000() public {
        address maxBurnGame = makeAddr("maxBurnGame");

        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 1 ether,
            maxEntry: 0,
            rakeBps: 500, // 5% rake
            burnBps: 10_000, // 100% of rake burned
            requiresPosition: false,
            paused: false
        });

        vm.prank(admin);
        arcadeCore.registerGame(maxBurnGame, config);

        uint256 treasuryBefore = dataToken.balanceOf(treasury);

        vm.prank(maxBurnGame);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // 100% burn means treasury gets nothing from rake
        uint256 treasuryAfter = dataToken.balanceOf(treasury);
        assertEq(treasuryAfter, treasuryBefore, "Treasury receives nothing when 100% burned");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 3. BOUNDARY CONDITIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Entry at exactly minEntry should succeed
    function test_Boundary_ProcessEntry_ExactlyMinEntry() public {
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, MIN_ENTRY, SESSION_1);

        assertGt(netAmount, 0, "Entry should succeed at min");
    }

    /// @notice Entry at one below minEntry should fail
    function test_Boundary_ProcessEntry_OneBelowMinEntry() public {
        vm.prank(game);
        vm.expectRevert(IArcadeCore.InvalidEntryAmount.selector);
        arcadeCore.processEntry(alice, MIN_ENTRY - 1, SESSION_1);
    }

    /// @notice Entry at exactly maxEntry should succeed
    function test_Boundary_ProcessEntry_ExactlyMaxEntry() public {
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, MAX_ENTRY, SESSION_1);

        assertGt(netAmount, 0, "Entry should succeed at max");
    }

    /// @notice Entry at one above maxEntry should fail
    function test_Boundary_ProcessEntry_OneAboveMaxEntry() public {
        vm.prank(game);
        vm.expectRevert(IArcadeCore.InvalidEntryAmount.selector);
        arcadeCore.processEntry(alice, MAX_ENTRY + 1, SESSION_1);
    }

    /// @notice Payout at exactly prize pool should succeed
    function test_Boundary_CreditPayout_ExactlyPrizePool() public {
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        vm.prank(game);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount, 0, true);

        assertEq(arcadeCore.getPendingPayout(alice), netAmount);
        assertEq(arcadeCore.getSessionRemainingCapacity(SESSION_1), 0);
    }

    /// @notice Payout at one below prize pool should succeed
    function test_Boundary_CreditPayout_OneBelowPrizePool() public {
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        vm.prank(game);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount - 1, 0, true);

        assertEq(arcadeCore.getSessionRemainingCapacity(SESSION_1), 1);
    }

    /// @notice Payout at one above prize pool should fail
    function test_Boundary_CreditPayout_OneAbovePrizePool() public {
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        vm.prank(game);
        vm.expectRevert(IArcadeCore.PayoutExceedsPrizePool.selector);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount + 1, 0, true);
    }

    /// @notice Refund at exactly net deposit should succeed
    function test_Boundary_Refund_ExactlyDeposit() public {
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        vm.prank(game);
        arcadeCore.cancelSession(SESSION_1);

        vm.prank(game);
        arcadeCore.emergencyRefund(SESSION_1, alice, netAmount);

        assertEq(arcadeCore.getPendingPayout(alice), netAmount);
    }

    /// @notice Refund at one below net deposit should succeed
    function test_Boundary_Refund_OneBelowDeposit() public {
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        vm.prank(game);
        arcadeCore.cancelSession(SESSION_1);

        vm.prank(game);
        arcadeCore.emergencyRefund(SESSION_1, alice, netAmount - 1);

        assertEq(arcadeCore.getPendingPayout(alice), netAmount - 1);
    }

    /// @notice Refund at one above net deposit should fail
    function test_Boundary_Refund_OneAboveDeposit() public {
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        vm.prank(game);
        arcadeCore.cancelSession(SESSION_1);

        vm.prank(game);
        vm.expectRevert(IArcadeCore.RefundExceedsDeposit.selector);
        arcadeCore.emergencyRefund(SESSION_1, alice, netAmount + 1);
    }

    /// @notice Batch at exactly 100 should succeed
    function test_Boundary_BatchSize_Exactly100() public {
        vm.prank(game);
        arcadeCore.processEntry(alice, 1000 ether, SESSION_1);

        uint256[] memory sessionIds = new uint256[](100);
        address[] memory players = new address[](100);
        uint256[] memory amounts = new uint256[](100);
        uint256[] memory burnAmounts = new uint256[](100);
        bool[] memory results = new bool[](100);

        for (uint256 i; i < 100; ++i) {
            sessionIds[i] = SESSION_1;
            players[i] = alice;
            amounts[i] = 0;
            burnAmounts[i] = 0;
            results[i] = false;
        }

        vm.prank(game);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    /// @notice Batch at 99 should succeed
    function test_Boundary_BatchSize_Exactly99() public {
        vm.prank(game);
        arcadeCore.processEntry(alice, 1000 ether, SESSION_1);

        uint256[] memory sessionIds = new uint256[](99);
        address[] memory players = new address[](99);
        uint256[] memory amounts = new uint256[](99);
        uint256[] memory burnAmounts = new uint256[](99);
        bool[] memory results = new bool[](99);

        for (uint256 i; i < 99; ++i) {
            sessionIds[i] = SESSION_1;
            players[i] = alice;
            amounts[i] = 0;
            burnAmounts[i] = 0;
            results[i] = false;
        }

        vm.prank(game);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    /// @notice Batch at 101 should fail
    function test_Boundary_BatchSize_Exactly101() public {
        uint256[] memory sessionIds = new uint256[](101);
        address[] memory players = new address[](101);
        uint256[] memory amounts = new uint256[](101);
        uint256[] memory burnAmounts = new uint256[](101);
        bool[] memory results = new bool[](101);

        vm.prank(game);
        vm.expectRevert(abi.encodeWithSelector(IArcadeCore.BatchTooLarge.selector, 101, 100));
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    /// @notice Rate limit at exactly MIN_PLAY_INTERVAL should succeed
    /// @dev Contract uses `<` not `<=`, so exactly at interval passes
    function test_Boundary_RateLimit_ExactlyAtInterval() public {
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // Advance exactly 1 second (MIN_PLAY_INTERVAL)
        // The check is: block.timestamp < stats.lastPlayTime + MIN_PLAY_INTERVAL
        // At +1 second: timestamp is NOT < lastPlayTime + 1, so check passes
        vm.warp(block.timestamp + 1);

        // Should succeed - exactly at interval is allowed
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // Verify two entries processed
        assertEq(arcadeCore.getPlayerStats(alice).totalGamesPlayed, 2);
    }

    /// @notice Rate limit one second before interval expires should fail
    function test_Boundary_RateLimit_OneBelowInterval() public {
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // No time advance - immediate retry
        vm.prank(game);
        vm.expectRevert(IArcadeCore.RateLimited.selector);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);
    }

    /// @notice Rate limit one second after interval should succeed
    function test_Boundary_RateLimit_OneAboveInterval() public {
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // Advance past interval
        vm.warp(block.timestamp + 2);

        // Should succeed
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 4. TIMING EDGE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Multiple operations in same block are allowed (if rate limit passed)
    function test_Timing_SameBlockOperations() public {
        // Entry and payout in same block
        vm.startPrank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount / 2, 0, true);
        arcadeCore.settleSession(SESSION_1);
        vm.stopPrank();

        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(uint8(session.state), uint8(IArcadeCore.SessionState.SETTLED));
    }

    /// @notice Timestamp at max uint64 should work (year 584 billion)
    function test_Timing_TimestampMaxUint64() public {
        // Warp to max uint64 timestamp
        vm.warp(type(uint64).max);

        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.createdAt, type(uint64).max, "Timestamp should be max uint64");
    }

    /// @notice Consecutive blocks should reset rate limit properly
    function test_Timing_ConsecutiveBlocks() public {
        // Entry at block N
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // Roll forward
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 2);

        // Second entry should work
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);
    }

    /// @notice Large block gap should not cause issues
    function test_Timing_LargeBlockGap() public {
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // Jump forward 1 million blocks (~4 months at 12s/block)
        vm.roll(block.number + 1_000_000);
        vm.warp(block.timestamp + 12_000_000);

        // Should still work
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 5. STATE EDGE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice First session ever on fresh contract
    function test_State_FirstSessionEver() public view {
        // Check that no sessions exist
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(uint8(session.state), uint8(IArcadeCore.SessionState.NONE));
        assertEq(session.game, address(0));
    }

    /// @notice First entry creates session correctly
    function test_State_FirstEntryToSession() public {
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(uint8(session.state), uint8(IArcadeCore.SessionState.ACTIVE));
        assertEq(session.game, game);
        assertGt(session.prizePool, 0);
    }

    /// @notice Session with single player
    function test_State_SinglePlayer() public {
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        vm.prank(game);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount, 0, true);

        vm.prank(game);
        arcadeCore.settleSession(SESSION_1);

        // Single player took entire prize pool
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.totalPaid, session.prizePool);
    }

    /// @notice Contract with no registered games
    function test_State_NoRegisteredGames() public {
        // Deploy fresh ArcadeCore without registering games
        ArcadeCore implementation = new ArcadeCore();
        bytes memory initData = abi.encodeCall(
            ArcadeCore.initialize, (address(dataToken), address(0), treasury, admin)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        ArcadeCore freshArcade = ArcadeCore(address(proxy));

        // No games registered - operations should fail
        vm.prank(game);
        vm.expectRevert(IArcadeCore.GameNotRegistered.selector);
        freshArcade.processEntry(alice, 100 ether, SESSION_1);
    }

    /// @notice Game that gets paused mid-operation
    function test_State_AllGamesPaused() public {
        // Pause the game
        vm.prank(admin);
        arcadeCore.pauseGame(game);

        // Operations should fail
        vm.prank(game);
        vm.expectRevert(IArcadeCore.GamePaused.selector);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 6. ARRAY EDGE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Empty batch should fail
    function test_Array_EmptyBatch() public {
        uint256[] memory sessionIds = new uint256[](0);
        address[] memory players = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        uint256[] memory burnAmounts = new uint256[](0);
        bool[] memory results = new bool[](0);

        vm.prank(game);
        vm.expectRevert(IArcadeCore.EmptyBatch.selector);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    /// @notice Single element batch should succeed
    function test_Array_SingleElementBatch() public {
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        uint256[] memory sessionIds = new uint256[](1);
        address[] memory players = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory burnAmounts = new uint256[](1);
        bool[] memory results = new bool[](1);

        sessionIds[0] = SESSION_1;
        players[0] = alice;
        amounts[0] = netAmount / 2;
        burnAmounts[0] = 0;
        results[0] = true;

        vm.prank(game);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);

        assertEq(arcadeCore.getPendingPayout(alice), netAmount / 2);
    }

    /// @notice Duplicate players in batch should work (accumulates payouts)
    function test_Array_DuplicatePlayersInBatch() public {
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        uint256[] memory sessionIds = new uint256[](3);
        address[] memory players = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        uint256[] memory burnAmounts = new uint256[](3);
        bool[] memory results = new bool[](3);

        // Same player 3 times with different amounts
        sessionIds[0] = SESSION_1;
        sessionIds[1] = SESSION_1;
        sessionIds[2] = SESSION_1;
        players[0] = alice;
        players[1] = alice;
        players[2] = alice;
        amounts[0] = 10 ether;
        amounts[1] = 15 ether;
        amounts[2] = 20 ether;
        burnAmounts[0] = 0;
        burnAmounts[1] = 0;
        burnAmounts[2] = 0;
        results[0] = true;
        results[1] = true;
        results[2] = true;

        vm.prank(game);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);

        // All payouts accumulated
        assertEq(arcadeCore.getPendingPayout(alice), 45 ether);

        // All wins recorded
        assertEq(arcadeCore.getPlayerStats(alice).totalWins, 3);
    }

    /// @notice Array length mismatch should fail
    function test_Array_LengthMismatch() public {
        uint256[] memory sessionIds = new uint256[](2);
        address[] memory players = new address[](3); // Mismatch!
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory burnAmounts = new uint256[](2);
        bool[] memory results = new bool[](2);

        vm.prank(game);
        vm.expectRevert(
            abi.encodeWithSelector(IArcadeCore.ArrayLengthMismatch.selector, 2, 3, 2, 2, 2)
        );
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);
    }

    /// @notice Batch emergency refund with duplicates skips already refunded
    function test_Array_DuplicatePlayersInBatchRefund() public {
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        uint256 netAmount = arcadeCore.getSessionDeposit(SESSION_1, alice);

        vm.prank(game);
        arcadeCore.cancelSession(SESSION_1);

        // Include alice twice
        address[] memory players = new address[](3);
        players[0] = alice;
        players[1] = bob; // No deposit
        players[2] = alice; // Duplicate

        vm.prank(game);
        arcadeCore.batchEmergencyRefund(SESSION_1, players);

        // Alice refunded once (duplicate skipped)
        assertEq(arcadeCore.getPendingPayout(alice), netAmount);
        assertTrue(arcadeCore.isRefunded(SESSION_1, alice));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 7. PRECISION EDGE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Rake calculation with very small amount
    function test_Precision_RakeCalculation_SmallAmount() public {
        // Minimum entry with 5% rake
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, MIN_ENTRY, SESSION_1);

        uint256 expectedRake = (MIN_ENTRY * RAKE_BPS) / BPS;
        uint256 expectedNet = MIN_ENTRY - expectedRake;

        assertEq(netAmount, expectedNet, "Net amount should match expected");
    }

    /// @notice Rake calculation with large amount
    function test_Precision_RakeCalculation_LargeAmount() public {
        // Use the max entry for the standard game config
        uint256 largeEntry = MAX_ENTRY; // 10,000 ether

        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, largeEntry, SESSION_1);

        uint256 expectedRake = (largeEntry * RAKE_BPS) / BPS;
        uint256 expectedNet = largeEntry - expectedRake;

        assertEq(netAmount, expectedNet, "Large amount precision correct");
    }

    /// @notice Verify rake always rounds down (in favor of player)
    function test_Precision_RakeCalculation_RoundingDown() public {
        // Amount that doesn't divide evenly
        uint256 oddAmount = 123_456_789_012_345_678_901 wei; // ~123.46 tokens

        // This is below minEntry, so register a game with no min
        address noMinGame = makeAddr("noMinGame");
        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 0,
            maxEntry: 0,
            rakeBps: 300, // 3% for more interesting rounding
            burnBps: 2000,
            requiresPosition: false,
            paused: false
        });

        vm.prank(admin);
        arcadeCore.registerGame(noMinGame, config);

        vm.prank(noMinGame);
        uint256 netAmount = arcadeCore.processEntry(alice, oddAmount, SESSION_2);

        // Solidity integer division rounds down
        uint256 expectedRake = (oddAmount * 300) / BPS;
        uint256 expectedNet = oddAmount - expectedRake;

        assertEq(netAmount, expectedNet, "Rounding should favor player (round rake down)");

        // Verify sum: net + rake should not exceed original (may be less due to rounding)
        assertLe(netAmount + expectedRake, oddAmount);
    }

    /// @notice Burn calculation with small rake
    function test_Precision_BurnCalculation_SmallRake() public {
        // Very small entry to get small rake
        address smallGame = makeAddr("smallGame");
        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 0,
            maxEntry: 0,
            rakeBps: 100, // 1% rake
            burnBps: 5000, // 50% of rake burned
            requiresPosition: false,
            paused: false
        });

        vm.prank(admin);
        arcadeCore.registerGame(smallGame, config);

        uint256 entry = 100 wei;

        vm.prank(smallGame);
        uint256 netAmount = arcadeCore.processEntry(alice, entry, SESSION_2);

        // With 100 wei and 1% rake = 1 wei rake
        // 50% of 1 wei burn = 0 wei (rounds down)
        // Net should be 99 wei
        assertEq(netAmount, 99 wei, "Small entry net amount");
    }

    /// @notice Net amount after rake accumulates correctly
    function test_Precision_NetAmount_Accumulation() public {
        // Multiple small entries
        uint256 entry = 10 ether;
        uint256 totalNet;

        vm.startPrank(game);
        for (uint256 i; i < 5; ++i) {
            totalNet += arcadeCore.processEntry(alice, entry, SESSION_1);
            vm.warp(block.timestamp + 2);
        }
        vm.stopPrank();

        // Verify prize pool matches accumulated net
        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.prizePool, totalNet, "Prize pool equals accumulated net");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 8. RE-ENTRY EDGE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Same player can enter same session multiple times
    function test_Reentry_SameSession_MultipleEntries() public {
        vm.startPrank(game);

        uint256 net1 = arcadeCore.processEntry(alice, 100 ether, SESSION_1);
        vm.warp(block.timestamp + 2);
        uint256 net2 = arcadeCore.processEntry(alice, 100 ether, SESSION_1);
        vm.warp(block.timestamp + 2);
        uint256 net3 = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        vm.stopPrank();

        // Verify accumulated deposit
        uint256 totalNet = net1 + net2 + net3;
        uint256 deposit = arcadeCore.getSessionDeposit(SESSION_1, alice);
        assertEq(deposit, totalNet, "Deposits accumulate");
    }

    /// @notice Same player can play multiple games simultaneously
    function test_Reentry_SamePlayer_MultipleGames() public {
        // Register second game
        vm.prank(admin);
        arcadeCore.registerGame(gameB, _defaultConfig());

        // Alice plays game 1
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // Wait for rate limit to pass
        vm.warp(block.timestamp + 2);

        // Alice plays game 2 (different session)
        vm.prank(gameB);
        arcadeCore.processEntry(alice, 100 ether, SESSION_2);

        // Verify both sessions exist
        IArcadeCore.SessionRecord memory session1 = arcadeCore.getSession(SESSION_1);
        IArcadeCore.SessionRecord memory session2 = arcadeCore.getSession(SESSION_2);

        assertEq(session1.game, game);
        assertEq(session2.game, gameB);

        // Stats should reflect both
        assertEq(arcadeCore.getPlayerStats(alice).totalGamesPlayed, 2);
    }

    /// @notice Player can withdraw and re-enter
    function test_Reentry_AfterWithdraw() public {
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        vm.prank(game);
        arcadeCore.creditPayout(SESSION_1, alice, netAmount, 0, true);

        // Withdraw
        vm.prank(alice);
        uint256 withdrawn = arcadeCore.withdrawPayout();
        assertEq(withdrawn, netAmount);

        // Re-enter (new session)
        vm.warp(block.timestamp + 2);
        vm.prank(game);
        arcadeCore.processEntry(alice, withdrawn, SESSION_2);

        assertEq(arcadeCore.getSessionDeposit(SESSION_2, alice), _netAmount(withdrawn));
    }

    /// @notice Player can enter again after being refunded
    function test_Reentry_AfterRefund() public {
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        vm.prank(game);
        arcadeCore.cancelSession(SESSION_1);

        vm.prank(game);
        arcadeCore.emergencyRefund(SESSION_1, alice, netAmount);

        // Withdraw refund
        vm.prank(alice);
        arcadeCore.withdrawPayout();

        // Re-enter new session
        vm.warp(block.timestamp + 2);
        vm.prank(game);
        arcadeCore.processEntry(alice, 50 ether, SESSION_2);

        assertGt(arcadeCore.getSessionDeposit(SESSION_2, alice), 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 9. CONFIGURATION EDGE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Min entry equals max entry (fixed entry amount)
    function test_Config_MinEntry_EqualsMaxEntry() public {
        address fixedGame = makeAddr("fixedGame");
        uint256 fixedAmount = 50 ether;

        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: fixedAmount,
            maxEntry: fixedAmount, // Same as min
            rakeBps: 500,
            burnBps: 2000,
            requiresPosition: false,
            paused: false
        });

        vm.prank(admin);
        arcadeCore.registerGame(fixedGame, config);

        // Exact amount works
        vm.prank(fixedGame);
        arcadeCore.processEntry(alice, fixedAmount, SESSION_1);

        // Below fails
        vm.prank(fixedGame);
        vm.expectRevert(IArcadeCore.InvalidEntryAmount.selector);
        arcadeCore.processEntry(alice, fixedAmount - 1, SESSION_2);

        // Above fails
        vm.prank(fixedGame);
        vm.expectRevert(IArcadeCore.InvalidEntryAmount.selector);
        arcadeCore.processEntry(alice, fixedAmount + 1, 3);
    }

    /// @notice Zero rake means full amount to pool
    function test_Config_RakeBps_Zero() public {
        address noRakeGame = makeAddr("noRakeGame");

        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 1 ether,
            maxEntry: 0,
            rakeBps: 0, // No rake
            burnBps: 0,
            requiresPosition: false,
            paused: false
        });

        vm.prank(admin);
        arcadeCore.registerGame(noRakeGame, config);

        uint256 entry = 100 ether;
        uint256 treasuryBefore = dataToken.balanceOf(treasury);

        vm.prank(noRakeGame);
        uint256 netAmount = arcadeCore.processEntry(alice, entry, SESSION_1);

        assertEq(netAmount, entry, "No rake - full amount to pool");
        assertEq(dataToken.balanceOf(treasury), treasuryBefore, "Treasury unchanged");
    }

    /// @notice 100% burn rate burns all rake
    function test_Config_BurnBps_100Percent() public {
        address fullBurnGame = makeAddr("fullBurnGame");

        IArcadeCore.GameConfig memory config = IArcadeCore.GameConfig({
            minEntry: 1 ether,
            maxEntry: 0,
            rakeBps: 500, // 5% rake
            burnBps: 10_000, // 100% burned
            requiresPosition: false,
            paused: false
        });

        vm.prank(admin);
        arcadeCore.registerGame(fullBurnGame, config);

        uint256 entry = 100 ether;
        uint256 treasuryBefore = dataToken.balanceOf(treasury);

        vm.prank(fullBurnGame);
        arcadeCore.processEntry(alice, entry, SESSION_1);

        // Treasury gets nothing (all rake burned)
        assertEq(dataToken.balanceOf(treasury), treasuryBefore);
    }

    /// @notice Config change mid-session affects new entries only
    function test_Config_Change_MidSession() public {
        // Initial entry with 5% rake
        vm.prank(game);
        uint256 net1 = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // Change config to 10% rake
        IArcadeCore.GameConfig memory newConfig = IArcadeCore.GameConfig({
            minEntry: MIN_ENTRY,
            maxEntry: MAX_ENTRY,
            rakeBps: 1000, // 10% rake now
            burnBps: uint16(BURN_BPS),
            requiresPosition: false,
            paused: false
        });

        vm.prank(admin);
        arcadeCore.updateGameConfig(game, newConfig);

        // New entry with 10% rake
        vm.warp(block.timestamp + 2);
        vm.prank(game);
        uint256 net2 = arcadeCore.processEntry(bob, 100 ether, SESSION_1);

        // net1 should be 95 ether (5% rake)
        assertEq(net1, 95 ether);
        // net2 should be 90 ether (10% rake)
        assertEq(net2, 90 ether);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 10. ADDRESS EDGE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Zero address as player should fail (from ERC20)
    function test_Address_ZeroAddress_Player() public {
        vm.prank(game);
        vm.expectRevert(); // ERC20 transfer to zero address
        arcadeCore.processEntry(address(0), 100 ether, SESSION_1);
    }

    /// @notice Zero address as game in registration should fail
    function test_Address_ZeroAddress_Game() public {
        vm.prank(admin);
        vm.expectRevert(IArcadeCore.InvalidAddress.selector);
        arcadeCore.registerGame(address(0), _defaultConfig());
    }

    /// @notice Zero address as treasury should fail in initialization
    function test_Address_ZeroAddress_Treasury() public {
        ArcadeCore implementation = new ArcadeCore();
        bytes memory initData = abi.encodeCall(
            ArcadeCore.initialize,
            (
                address(dataToken),
                address(0), // ghostCore can be zero
                address(0), // Zero treasury - should fail
                admin
            )
        );

        vm.expectRevert(IArcadeCore.InvalidAddress.selector);
        new ERC1967Proxy(address(implementation), initData);
    }

    /// @notice Contract can be a player
    function test_Address_ContractAsPlayer() public {
        // Deploy a simple contract that can receive tokens
        MockPlayer playerContract = new MockPlayer(address(dataToken));

        // Fund the contract
        vm.prank(admin);
        dataToken.transfer(address(playerContract), 1000 ether);

        // Approve arcade
        playerContract.approve(address(arcadeCore));

        // Contract plays
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(address(playerContract), 100 ether, SESSION_1);

        assertGt(netAmount, 0);
    }

    /// @notice Same address can be admin and game (not recommended but allowed)
    function test_Address_SameAddressMultipleRoles() public {
        // Admin registers themselves as a game
        vm.prank(admin);
        arcadeCore.registerGame(admin, _defaultConfig());

        // Admin can now act as game
        vm.prank(admin);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        assertTrue(arcadeCore.isGameRegistered(admin));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 11. SESSION LIFECYCLE EDGE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Settle session immediately after creation
    function test_Session_SettleImmediately() public {
        vm.startPrank(game);

        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // Settle immediately (no payouts)
        arcadeCore.settleSession(SESSION_1);

        vm.stopPrank();

        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(uint8(session.state), uint8(IArcadeCore.SessionState.SETTLED));
        assertEq(session.totalPaid, 0, "No payouts made");
    }

    /// @notice Cancel session immediately after creation
    function test_Session_CancelImmediately() public {
        vm.startPrank(game);

        arcadeCore.processEntry(alice, 100 ether, SESSION_1);
        arcadeCore.cancelSession(SESSION_1);

        vm.stopPrank();

        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(uint8(session.state), uint8(IArcadeCore.SessionState.CANCELLED));
    }

    /// @notice Settle with no payouts sends remaining to treasury
    function test_Session_SettleWithNoPayouts() public {
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        uint256 treasuryBefore = dataToken.balanceOf(treasury);

        // Settle without any payouts
        vm.prank(game);
        arcadeCore.settleSession(SESSION_1);

        // Treasury receives entire prize pool
        uint256 treasuryAfter = dataToken.balanceOf(treasury);
        assertEq(treasuryAfter - treasuryBefore, netAmount, "Treasury gets unclaimed pool");
    }

    /// @notice Multiple settle attempts fail
    function test_Session_MultipleSettleAttempts() public {
        vm.startPrank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);
        arcadeCore.settleSession(SESSION_1);

        vm.expectRevert(IArcadeCore.SessionNotActive.selector);
        arcadeCore.settleSession(SESSION_1);

        vm.expectRevert(IArcadeCore.SessionNotActive.selector);
        arcadeCore.settleSession(SESSION_1);

        vm.stopPrank();
    }

    /// @notice Cancel after partial payouts blocks ALL refunds (security measure)
    /// @dev Once any payout is made, refunds are blocked to prevent solvency attacks.
    ///      This is a security tradeoff - games should settle normally or cancel BEFORE payouts.
    function test_Session_CancelAfterPartialPayouts() public {
        vm.startPrank(game);

        arcadeCore.processEntry(alice, 100 ether, SESSION_1);
        vm.warp(block.timestamp + 2);
        arcadeCore.processEntry(bob, 100 ether, SESSION_1);

        // Partial payout to alice
        arcadeCore.creditPayout(SESSION_1, alice, 30 ether, 0, true);

        // Cancel
        arcadeCore.cancelSession(SESSION_1);

        vm.stopPrank();

        // SECURITY: After payouts, even CANCELLED sessions cannot issue refunds
        // This prevents solvency attacks where payout + refund > balance
        uint256 bobDeposit = arcadeCore.getSessionDeposit(SESSION_1, bob);

        vm.prank(game);
        vm.expectRevert(IArcadeCore.RefundsBlockedAfterPayouts.selector);
        arcadeCore.emergencyRefund(SESSION_1, bob, bobDeposit);

        // Bob's pending is 0 (refund was blocked)
        assertEq(arcadeCore.getPendingPayout(bob), 0);
    }

    /// @notice Very long session (many entries over time)
    function test_Session_VeryLongSession() public {
        uint256 totalNet;

        // Simulate 100 entries over time
        for (uint256 i; i < 100; ++i) {
            vm.warp(block.timestamp + 2);
            vm.prank(game);
            totalNet += arcadeCore.processEntry(alice, 10 ether, SESSION_1);
        }

        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(session.prizePool, totalNet, "Prize pool accumulated correctly");

        // Can still settle
        vm.prank(game);
        arcadeCore.settleSession(SESSION_1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 12. CONCURRENT OPERATION EDGE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Two players enter in same block (different txs)
    function test_Concurrent_TwoPlayersEnterSameBlock() public {
        // In reality these would be different transactions in same block
        // Simulate by calling both without time warp

        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        vm.prank(game);
        arcadeCore.processEntry(bob, 100 ether, SESSION_1);

        // Both should succeed
        assertGt(arcadeCore.getSessionDeposit(SESSION_1, alice), 0);
        assertGt(arcadeCore.getSessionDeposit(SESSION_1, bob), 0);
    }

    /// @notice Entry and credit in same block
    function test_Concurrent_EnterAndCreditSameBlock() public {
        vm.startPrank(game);

        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // Credit payout in same block
        arcadeCore.creditPayout(SESSION_1, alice, netAmount / 2, 0, true);

        vm.stopPrank();

        assertEq(arcadeCore.getPendingPayout(alice), netAmount / 2);
    }

    /// @notice Credit and settle in same block
    function test_Concurrent_CreditAndSettleSameBlock() public {
        vm.startPrank(game);

        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // Credit and settle in same block
        arcadeCore.creditPayout(SESSION_1, alice, netAmount, 0, true);
        arcadeCore.settleSession(SESSION_1);

        vm.stopPrank();

        IArcadeCore.SessionRecord memory session = arcadeCore.getSession(SESSION_1);
        assertEq(uint8(session.state), uint8(IArcadeCore.SessionState.SETTLED));
    }

    /// @notice Refund and withdraw in same block
    function test_Concurrent_RefundAndWithdrawSameBlock() public {
        vm.prank(game);
        uint256 netAmount = arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        vm.prank(game);
        arcadeCore.cancelSession(SESSION_1);

        vm.prank(game);
        arcadeCore.emergencyRefund(SESSION_1, alice, netAmount);

        // Alice withdraws in same block
        vm.prank(alice);
        uint256 withdrawn = arcadeCore.withdrawPayout();

        assertEq(withdrawn, netAmount);
    }

    /// @notice Pause triggered during entry preparation should block
    function test_Concurrent_PauseAndEntrySameBlock() public {
        // Admin pauses entire arcade
        vm.prank(admin);
        arcadeCore.pause();

        // Entry should fail
        vm.prank(game);
        vm.expectRevert(); // Pausable: paused
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);

        // Unpause
        vm.prank(admin);
        arcadeCore.unpause();

        // Now should work
        vm.prank(game);
        arcadeCore.processEntry(alice, 100 ether, SESSION_1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // GAS MEASUREMENT TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Gas measurement for processEntry at minimum
    function test_Gas_ProcessEntry_MinEntry() public {
        uint256 gasBefore = gasleft();

        vm.prank(game);
        arcadeCore.processEntry(alice, MIN_ENTRY, SESSION_1);

        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for processEntry (min entry, new session):", gasUsed);
        // New session creation includes session initialization, so higher gas
        assertLt(gasUsed, 500_000, "Gas should be reasonable for new session");
    }

    /// @notice Gas measurement for max batch size
    function test_Gas_BatchCreditPayouts_Max100() public {
        vm.prank(game);
        arcadeCore.processEntry(alice, 10_000 ether, SESSION_1);

        uint256[] memory sessionIds = new uint256[](100);
        address[] memory players = new address[](100);
        uint256[] memory amounts = new uint256[](100);
        uint256[] memory burnAmounts = new uint256[](100);
        bool[] memory results = new bool[](100);

        for (uint256 i; i < 100; ++i) {
            sessionIds[i] = SESSION_1;
            players[i] = alice;
            amounts[i] = 1 ether;
            burnAmounts[i] = 0;
            results[i] = true;
        }

        uint256 gasBefore = gasleft();

        vm.prank(game);
        arcadeCore.batchCreditPayouts(sessionIds, players, amounts, burnAmounts, results);

        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for batchCreditPayouts (100 items):", gasUsed);
        assertLt(gasUsed, 5_000_000, "Should fit within block limits");
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// HELPER CONTRACTS
// ══════════════════════════════════════════════════════════════════════════════

/// @notice Mock contract that can act as a player
contract MockPlayer {
    IERC20 public token;

    constructor(
        address _token
    ) {
        token = IERC20(_token);
    }

    function approve(
        address spender
    ) external {
        token.approve(spender, type(uint256).max);
    }
}
