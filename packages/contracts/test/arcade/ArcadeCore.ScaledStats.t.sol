// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";

/// @title ArcadeCore Scaled Statistics Tests
/// @notice Tests for AMOUNT_SCALE truncation behavior in PlayerStats
/// @dev These tests verify that:
///      1. Micro amounts (< 1e6 wei) are correctly truncated to 0 in scaled stats
///      2. Large amounts are accurately tracked with expected precision loss
///      3. Authoritative unscaled values (totalVolume, totalPendingPayouts) remain exact
///      4. Accumulation drift from truncation is acceptable for analytics use cases
///
/// IMPORTANT: These tests serve as specification for ArcadeCore implementation.
/// Uncomment and complete once ArcadeCore contract is implemented.
///
/// @custom:security This test file documents the truncation behavior that is
/// acceptable for analytics but NOT suitable for financial invariants.
abstract contract ArcadeCoreScaledStatsTest is Test {
    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS (must match ArcadeCoreStorage.sol)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Scale factor matching ArcadeCoreStorage.AMOUNT_SCALE
    uint256 internal constant AMOUNT_SCALE = 1e6;

    /// @notice Dead address for burns
    address internal constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // ══════════════════════════════════════════════════════════════════════════════
    // TEST ACCOUNTS
    // ══════════════════════════════════════════════════════════════════════════════

    address internal owner = makeAddr("owner");
    address internal player = makeAddr("player");
    address internal registeredGame = makeAddr("registeredGame");
    address internal treasury = makeAddr("treasury");

    // ══════════════════════════════════════════════════════════════════════════════
    // SETUP
    // ══════════════════════════════════════════════════════════════════════════════

    // NOTE: Implement in concrete test class once ArcadeCore exists
    // function setUp() public virtual;

    // ══════════════════════════════════════════════════════════════════════════════
    // TRUNCATION BEHAVIOR TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Verify that amounts smaller than AMOUNT_SCALE truncate to 0 in stats
    /// @dev This is expected behavior - micro amounts are lost from analytics but
    ///      NOT from actual accounting (totalVolume remains exact)
    function test_ScaledStats_TruncatesMicroAmounts_Specification() public pure {
        // Test the pure math of truncation
        uint256 microWager = 1e5; // Less than 1e6 (AMOUNT_SCALE)
        uint256 scaledValue = microWager / AMOUNT_SCALE;

        assertEq(scaledValue, 0, "Micro amounts should truncate to 0");
    }

    /// @notice Verify truncation at boundary values
    function test_ScaledStats_BoundaryTruncation_Specification() public pure {
        // Just under threshold - truncates to 0
        assertEq((AMOUNT_SCALE - 1) / AMOUNT_SCALE, 0, "999999 wei should truncate to 0");

        // Exactly at threshold - becomes 1
        assertEq(AMOUNT_SCALE / AMOUNT_SCALE, 1, "1e6 wei should become 1");

        // Just over threshold - becomes 1 (not 2)
        assertEq((AMOUNT_SCALE + 1) / AMOUNT_SCALE, 1, "1e6+1 wei should become 1");

        // Double threshold - becomes 2
        assertEq((2 * AMOUNT_SCALE) / AMOUNT_SCALE, 2, "2e6 wei should become 2");
    }

    /// @notice Verify accumulation drift from repeated micro-transactions
    /// @dev This demonstrates why scaled stats should NOT be used for accounting
    function test_ScaledStats_AccumulationDrift_Specification() public pure {
        // Simulate 1000 micro-wagers just under threshold
        uint256 microWager = AMOUNT_SCALE - 1; // 999999 wei each
        uint256 numWagers = 1000;

        // Total actual volume
        uint256 actualTotal = microWager * numWagers;

        // Scaled accumulation (what stats would show if added one by one)
        uint256 scaledAccumulated = 0;
        for (uint256 i = 0; i < numWagers; i++) {
            scaledAccumulated += microWager / AMOUNT_SCALE; // Each truncates to 0
        }

        // What we'd get if we scaled the total directly
        uint256 scaledTotal = actualTotal / AMOUNT_SCALE;

        // Accumulated is 0 (complete loss due to repeated truncation)
        assertEq(scaledAccumulated, 0, "Accumulated scaled value should be 0");

        // But scaling the total gives us a reasonable approximation
        assertGt(scaledTotal, 0, "Scaling total directly should be non-zero");

        // The actual total is 999,999,000 wei
        // Scaled directly: 999,999,000 / 1e6 = 999 (truncated from 999.999)
        assertEq(scaledTotal, 999, "Scaled total should be 999");

        console.log("Actual total wei:", actualTotal);
        console.log("Accumulated scaled (per-tx):", scaledAccumulated);
        console.log("Scaled total (batch):", scaledTotal);
        console.log("Drift: 100% loss from per-tx accumulation");
    }

    /// @notice Verify large amounts scale correctly with minimal relative error
    function test_ScaledStats_LargeAmounts_Specification() public pure {
        // Large wager: 100 ether (100e18 wei)
        uint256 largeWager = 100 ether;
        uint256 scaledValue = largeWager / AMOUNT_SCALE;

        // Expected: 100e18 / 1e6 = 100e12 = 100,000,000,000,000
        uint256 expectedScaled = 100e12;
        assertEq(scaledValue, expectedScaled, "Large amounts should scale correctly");

        // Verify we can recover approximate original (within truncation error)
        uint256 recovered = scaledValue * AMOUNT_SCALE;
        assertEq(
            recovered, largeWager, "Should recover exact value for large multiples of AMOUNT_SCALE"
        );
    }

    /// @notice Verify maximum trackable amount fits in uint128
    function test_ScaledStats_MaxValue_Specification() public pure {
        // uint128.max
        uint256 maxUint128 = type(uint128).max;

        // Maximum storable scaled value
        uint256 maxStorable = maxUint128;

        // Maximum actual wei that can be represented
        uint256 maxActual = maxStorable * AMOUNT_SCALE;

        // This should be approximately 340 undecillion wei
        // uint128.max * 1e6 = ~340e45 wei = ~340e27 DATA
        assertTrue(maxActual > 340e45, "Max trackable should exceed 340 undecillion wei");

        console.log("Max uint128:", maxUint128);
        console.log("Max trackable wei:", maxActual);
        console.log("Max trackable DATA:", maxActual / 1e18);
    }

    /// @notice Verify precision loss percentage for typical wager sizes
    function test_ScaledStats_PrecisionLoss_Specification() public pure {
        // Test various wager sizes typical for arcade games
        uint256[5] memory wagers;
        wagers[0] = 1 ether; // 1 DATA - typical small bet
        wagers[1] = 10 ether; // 10 DATA - medium bet
        wagers[2] = 100 ether; // 100 DATA - large bet
        wagers[3] = 1000 ether; // 1000 DATA - whale bet
        wagers[4] = 0.001 ether; // 0.001 DATA - micro bet

        for (uint256 i = 0; i < wagers.length; i++) {
            uint256 wager = wagers[i];
            uint256 scaled = wager / AMOUNT_SCALE;
            uint256 recovered = scaled * AMOUNT_SCALE;
            uint256 lost = wager - recovered;

            // Precision loss should be < AMOUNT_SCALE for any input
            assertTrue(lost < AMOUNT_SCALE, "Precision loss should be bounded");

            // For amounts >= AMOUNT_SCALE, relative error should be tiny
            if (wager >= AMOUNT_SCALE) {
                // Relative error = lost / wager
                // For 1 ether, max loss is 999999, relative error = 999999/1e18 = 1e-12 = 0.0000001%
                uint256 relativeErrorPpm = (lost * 1e6) / wager; // parts per million
                assertTrue(relativeErrorPpm < 1, "Relative error should be < 1 ppm");
            }

            console.log("Wager:", wager);
            console.log("  Scaled:", scaled);
            console.log("  Lost:", lost);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INVARIANT SPECIFICATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Document correct vs incorrect invariant testing
    /// @dev This test demonstrates WHY scaled values must not be used for solvency
    function test_Invariant_Documentation_WrongVsCorrect() public pure {
        // Scenario: Player deposits 1 wei (below AMOUNT_SCALE)
        uint256 deposit = 1;

        // WRONG: Using scaled stats for solvency
        // Player's stats.totalWagered would be 0 (truncated)
        uint256 scaledWagered = deposit / AMOUNT_SCALE;
        assertEq(scaledWagered, 0, "Scaled deposit is 0");

        // If we summed all scaled player stats, we'd undercount actual deposits
        // This would make an invariant like:
        //   assert(balance >= sum(stats.totalWagered * AMOUNT_SCALE))
        // ALWAYS PASS even if balance was drained, because sum is 0!

        // CORRECT: Using unscaled authoritative values
        // $.totalVolume would still be 1 (exact)
        uint256 totalVolume = deposit; // Stored without scaling
        assertEq(totalVolume, 1, "Unscaled volume is exact");

        // Correct invariant:
        //   assert(dataToken.balanceOf(arcadeCore) >= $.totalPendingPayouts)
        // Uses unscaled values for actual solvency checking
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTEGRATION TEST SPECIFICATIONS
    // ══════════════════════════════════════════════════════════════════════════════
    //
    // The following tests require ArcadeCore implementation.
    // Uncomment and implement once the contract exists.
    //

    /*
    /// @notice Integration test: Micro wagers truncate in stats but not volume
    function test_ScaledStats_TruncatesMicroAmounts_Integration() public {
        // Setup: Register game, fund player
        // ...

        // Wager amount smaller than AMOUNT_SCALE
        uint256 microWager = 1e5; // Less than 1e6

        // Process entry
        vm.prank(registeredGame);
        arcadeCore.processEntry(player, microWager, sessionId);

        // Verify stats truncated to 0
        IArcadeCore.PlayerStats memory stats = arcadeCore.getPlayerStats(player);
        assertEq(stats.totalWagered, 0, "Micro amounts should truncate to 0 in stats");

        // But totalVolume should still track it exactly
        assertEq(arcadeCore.totalVolume(), microWager, "totalVolume should be exact");
    }

    /// @notice Integration test: Accumulated micro wagers show drift
    function test_ScaledStats_AccumulationDrift_Integration() public {
        // Process 1000 micro-wagers
        uint256 microWager = 5e5; // Just under 1e6
        uint256 numWagers = 1000;

        for (uint256 i = 0; i < numWagers; i++) {
            vm.prank(registeredGame);
            arcadeCore.processEntry(player, microWager, sessionId + i);
        }

        // Stats will show 0 due to per-transaction truncation
        IArcadeCore.PlayerStats memory stats = arcadeCore.getPlayerStats(player);
        assertEq(stats.totalWagered, 0, "All micro amounts truncated");

        // But totalVolume is accurate
        assertEq(arcadeCore.totalVolume(), microWager * numWagers, "totalVolume exact");
    }

    /// @notice Integration test: Large amounts track accurately
    function test_ScaledStats_LargeAmountsAccurate_Integration() public {
        uint256 largeWager = 100 ether; // Well above AMOUNT_SCALE

        vm.prank(registeredGame);
        arcadeCore.processEntry(player, largeWager, sessionId);

        IArcadeCore.PlayerStats memory stats = arcadeCore.getPlayerStats(player);
        uint256 expectedScaled = largeWager / AMOUNT_SCALE;
        assertEq(stats.totalWagered, expectedScaled, "Large amounts scale correctly");
    }

    /// @notice Invariant test: Solvency uses correct authoritative values
    function invariant_Solvency_UsesUnscaledValues() public {
        // CORRECT: Using unscaled authoritative values
        assertGe(
            dataToken.balanceOf(address(arcadeCore)),
            arcadeCore.totalPendingPayouts(),
            "Solvency invariant: balance >= pending payouts"
        );

        // Note: We do NOT test this (it would be WRONG):
        // uint256 sumPlayerStats = ...; // Sum of scaled values
        // assertGe(balance, sumPlayerStats * AMOUNT_SCALE); // BROKEN!
    }
    */
}

/// @title ArcadeCore Scaled Stats Documentation
/// @notice This contract documents the precision characteristics for reference
/// @dev Can be deployed to verify constants match across contracts
contract ScaledStatsDocumentation {
    /// @notice Scale factor for PlayerStats amount fields
    /// @dev Must match ArcadeCoreStorage.AMOUNT_SCALE
    uint256 public constant AMOUNT_SCALE = 1e6;

    /// @notice Minimum trackable amount in wei
    /// @dev Amounts below this truncate to 0 in scaled stats
    uint256 public constant MIN_TRACKABLE = AMOUNT_SCALE; // 1e6 wei = 1 pico-DATA

    /// @notice Maximum storable scaled value
    uint256 public constant MAX_SCALED = type(uint128).max;

    /// @notice Maximum actual wei that can be represented
    /// @dev MAX_SCALED * AMOUNT_SCALE
    uint256 public constant MAX_ACTUAL_WEI = MAX_SCALED * AMOUNT_SCALE;

    /// @notice Source of truth documentation
    /// @dev Reference for which values to use for different purposes
    ///
    /// | Metric           | Authoritative Source       | Precision      | Use For              |
    /// |------------------|----------------------------|----------------|----------------------|
    /// | Total volume     | $.totalVolume              | Full (uint256) | Accounting           |
    /// | Total burned     | $.totalBurned              | Full (uint256) | Accounting           |
    /// | Pending payouts  | $.totalPendingPayouts      | Full (uint256) | Solvency checks      |
    /// | Session pool     | session.prizePool          | Full (uint256) | Payout bounds        |
    /// | Player wagered   | stats.totalWagered * 1e6   | Approx         | Analytics/UI only    |
    /// | Player won       | stats.totalWon * 1e6       | Approx         | Analytics/UI only    |
    /// | Player burned    | stats.totalBurned * 1e6    | Approx         | Analytics/UI only    |
    function getSourceOfTruthTable() external pure returns (string memory) {
        return "See NatSpec documentation above";
    }
}
