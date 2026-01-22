// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";
import { FutureBlockRandomness } from "../../src/randomness/FutureBlockRandomness.sol";

/// @title FutureBlockRandomnessCoverageTest
/// @notice Additional tests to achieve >90% coverage
contract FutureBlockRandomnessCoverageTest is Test {
    TestRandomnessExtended public randomness;

    function setUp() public {
        randomness = new TestRandomnessExtended();
        vm.roll(1000);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // COMMIT NEGATIVE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_CommitSeed_RevertWhen_ZeroRoundId() public {
        vm.expectRevert(FutureBlockRandomness.InvalidRoundId.selector);
        randomness.commitSeed(0);
    }

    function test_CommitSeed_RevertWhen_AlreadyCommitted() public {
        randomness.commitSeed(1);

        vm.expectRevert(FutureBlockRandomness.SeedAlreadyCommitted.selector);
        randomness.commitSeed(1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // REVEAL NEGATIVE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_RevealSeed_RevertWhen_NotCommitted() public {
        vm.expectRevert(FutureBlockRandomness.SeedNotCommitted.selector);
        randomness.revealSeed(1);
    }

    function test_RevealSeed_RevertWhen_NotReady() public {
        randomness.commitSeed(1);

        // Don't roll forward
        vm.expectRevert(FutureBlockRandomness.SeedNotReady.selector);
        randomness.revealSeed(1);
    }

    function test_RevealSeed_RevertWhen_AtSeedBlock() public {
        randomness.commitSeed(1);

        uint256 seedBlock = randomness.getSeedBlock(1);
        vm.roll(seedBlock); // Exactly at seed block, not past it

        vm.expectRevert(FutureBlockRandomness.SeedNotReady.selector);
        randomness.revealSeed(1);
    }

    function test_RevealSeed_RevertWhen_Expired() public {
        randomness.commitSeed(1);

        uint256 seedBlock = randomness.getSeedBlock(1);
        vm.roll(seedBlock + 300); // Way past window

        vm.expectRevert(FutureBlockRandomness.SeedExpired.selector);
        randomness.revealSeed(1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // GET SEED NEGATIVE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetSeed_RevertWhen_NotRevealed() public {
        randomness.commitSeed(1);

        vm.expectRevert(FutureBlockRandomness.SeedNotCommitted.selector);
        randomness.getSeed(1);
    }

    function test_GetSeed_Success() public {
        randomness.commitSeed(1);
        uint256 seedBlock = randomness.getSeedBlock(1);
        vm.roll(seedBlock + 1);

        uint256 revealedSeed = randomness.revealSeed(1);
        uint256 getSeed = randomness.getSeed(1);

        assertEq(revealedSeed, getSeed);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // GET SEED OR REVEAL TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetSeedOrReveal_AlreadyRevealed() public {
        randomness.commitSeed(1);
        uint256 seedBlock = randomness.getSeedBlock(1);
        vm.roll(seedBlock + 1);

        uint256 seed1 = randomness.revealSeed(1);
        uint256 seed2 = randomness.getSeedOrReveal(1);

        assertEq(seed1, seed2, "Should return cached seed");
    }

    function test_GetSeedOrReveal_NotRevealed() public {
        randomness.commitSeed(1);
        uint256 seedBlock = randomness.getSeedBlock(1);
        vm.roll(seedBlock + 1);

        uint256 seed = randomness.getSeedOrReveal(1);
        assertTrue(seed != 0, "Should reveal and return seed");
        assertTrue(randomness.isSeedRevealed(1), "Should be marked revealed");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE QUERY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_IsSeedCommitted_False() public view {
        assertFalse(randomness.isSeedCommitted(999));
    }

    function test_IsSeedCommitted_True() public {
        randomness.commitSeed(1);
        assertTrue(randomness.isSeedCommitted(1));
    }

    function test_IsSeedRevealed_False() public {
        randomness.commitSeed(1);
        assertFalse(randomness.isSeedRevealed(1));
    }

    function test_IsSeedRevealed_True() public {
        randomness.commitSeed(1);
        uint256 seedBlock = randomness.getSeedBlock(1);
        vm.roll(seedBlock + 1);
        randomness.revealSeed(1);

        assertTrue(randomness.isSeedRevealed(1));
    }

    function test_IsSeedReady_NotCommitted() public view {
        assertFalse(randomness.isSeedReady(999));
    }

    function test_IsSeedReady_Revealed() public {
        randomness.commitSeed(1);
        uint256 seedBlock = randomness.getSeedBlock(1);
        vm.roll(seedBlock + 1);
        randomness.revealSeed(1);

        // Already revealed, so not "ready" in the sense of needing reveal
        assertFalse(randomness.isSeedReady(1));
    }

    function test_IsSeedReady_BeforeSeedBlock() public {
        randomness.commitSeed(1);
        // Still before seed block
        assertFalse(randomness.isSeedReady(1));
    }

    function test_IsSeedExpired_NotCommitted() public view {
        assertFalse(randomness.isSeedExpired(999));
    }

    function test_IsSeedExpired_Revealed() public {
        randomness.commitSeed(1);
        uint256 seedBlock = randomness.getSeedBlock(1);
        vm.roll(seedBlock + 1);
        randomness.revealSeed(1);

        // Revealed, so not expired
        assertFalse(randomness.isSeedExpired(1));
    }

    function test_IsSeedExpired_BeforeSeedBlock() public {
        randomness.commitSeed(1);
        // Still before seed block
        assertFalse(randomness.isSeedExpired(1));
    }

    function test_IsSeedExpired_WithinWindow() public {
        randomness.commitSeed(1);
        uint256 seedBlock = randomness.getSeedBlock(1);
        vm.roll(seedBlock + 100); // Within 256 block window

        assertFalse(randomness.isSeedExpired(1));
    }

    function test_IsSeedExpired_PastWindow() public {
        randomness.commitSeed(1);
        uint256 seedBlock = randomness.getSeedBlock(1);
        vm.roll(seedBlock + 300); // Past 256 block window

        assertTrue(randomness.isSeedExpired(1));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // REMAINING WINDOW TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetRemainingRevealWindow_NotCommitted() public view {
        assertEq(randomness.getRemainingRevealWindow(999), 0);
    }

    function test_GetRemainingRevealWindow_Revealed() public {
        randomness.commitSeed(1);
        uint256 seedBlock = randomness.getSeedBlock(1);
        vm.roll(seedBlock + 1);
        randomness.revealSeed(1);

        assertEq(randomness.getRemainingRevealWindow(1), 0);
    }

    function test_GetRemainingRevealWindow_BeforeSeedBlock() public {
        randomness.commitSeed(1);
        // Should include remaining delay + full window
        uint256 remaining = randomness.getRemainingRevealWindow(1);
        assertEq(remaining, 256 + 50); // window + delay
    }

    function test_GetRemainingRevealWindow_AtExpiry() public {
        randomness.commitSeed(1);
        uint256 seedBlock = randomness.getSeedBlock(1);
        vm.roll(seedBlock + 256); // At edge

        assertEq(randomness.getRemainingRevealWindow(1), 0);
    }

    function test_GetRemainingRevealWindow_PastExpiry() public {
        randomness.commitSeed(1);
        uint256 seedBlock = randomness.getSeedBlock(1);
        vm.roll(seedBlock + 300);

        assertEq(randomness.getRemainingRevealWindow(1), 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // UTILITY FUNCTION EDGE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    function test_SeedToRange_ZeroMax() public view {
        // Should return 0 as fallback (not revert)
        uint256 result = randomness.seedToRange(12_345, 0);
        assertEq(result, 0);
    }

    function test_SeedToRange_MaxOne() public view {
        uint256 result = randomness.seedToRange(12_345, 1);
        assertEq(result, 0); // Only possible value
    }

    function test_SeedToRangeInclusive_MaxLessThanMin() public view {
        // Should return min as fallback
        uint256 result = randomness.seedToRangeInclusive(12_345, 100, 50);
        assertEq(result, 100);
    }

    function test_SeedToRangeInclusive_MinEqualsMax() public view {
        uint256 result = randomness.seedToRangeInclusive(12_345, 50, 50);
        assertEq(result, 50); // Only possible value
    }

    function test_SeedToBool_EdgeCases() public view {
        // 0% should always be false
        assertFalse(randomness.seedToBool(0, 0));
        assertFalse(randomness.seedToBool(9999, 0));

        // 100% should always be true
        assertTrue(randomness.seedToBool(0, 10_000));
        assertTrue(randomness.seedToBool(9999, 10_000));
    }

    function testFuzz_SeedToRange_NeverReverts(
        uint256 seed,
        uint256 max
    ) public view {
        // Should never revert, even with max = 0
        uint256 result = randomness.seedToRange(seed, max);
        if (max > 0) {
            assertTrue(result < max);
        } else {
            assertEq(result, 0);
        }
    }

    function testFuzz_SeedToRangeInclusive_NeverReverts(
        uint256 seed,
        uint256 min,
        uint256 max
    ) public view {
        uint256 result = randomness.seedToRangeInclusive(seed, min, max);
        if (max >= min) {
            assertTrue(result >= min);
            assertTrue(result <= max);
        } else {
            assertEq(result, min);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ROUND SEED INFO TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetRoundSeedInfo_AllFields() public {
        randomness.commitSeed(1);
        uint256 seedBlock = randomness.getSeedBlock(1);
        vm.roll(seedBlock + 1);
        randomness.revealSeed(1);

        FutureBlockRandomness.RoundSeed memory info = randomness.getRoundSeedInfo(1);

        assertEq(info.seedBlock, seedBlock);
        assertTrue(info.committed);
        assertTrue(info.revealed);
        assertTrue(info.seed != 0);
        assertTrue(info.blockHash != bytes32(0));
    }

    function test_GetRoundSeedInfo_NotCommitted() public view {
        FutureBlockRandomness.RoundSeed memory info = randomness.getRoundSeedInfo(999);

        assertEq(info.seedBlock, 0);
        assertFalse(info.committed);
        assertFalse(info.revealed);
        assertEq(info.seed, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SEED DERIVATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_DeriveSubSeed_Deterministic() public view {
        uint256 seed = 12_345;
        uint256 sub1 = randomness.deriveSubSeed(seed, 0);
        uint256 sub2 = randomness.deriveSubSeed(seed, 0);
        assertEq(sub1, sub2);
    }

    function test_DeriveSubSeed_DifferentForDifferentSeeds() public view {
        uint256 sub1 = randomness.deriveSubSeed(12_345, 0);
        uint256 sub2 = randomness.deriveSubSeed(67_890, 0);
        assertTrue(sub1 != sub2);
    }

    function test_DeriveSubSeed_DifferentForDifferentIndices() public view {
        uint256 seed = 12_345;
        uint256 sub1 = randomness.deriveSubSeed(seed, 0);
        uint256 sub2 = randomness.deriveSubSeed(seed, 1);
        uint256 sub3 = randomness.deriveSubSeed(seed, 2);

        assertTrue(sub1 != sub2);
        assertTrue(sub2 != sub3);
        assertTrue(sub1 != sub3);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EFFECTIVE WINDOW TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetEffectiveWindow_WithoutEIP2935() public view {
        // Without EIP-2935, should return native limit (256)
        uint256 window = randomness.getEffectiveWindow();
        assertEq(window, 256);
    }
}

/// @notice Extended test contract with all internal functions exposed
contract TestRandomnessExtended is FutureBlockRandomness {
    function commitSeed(
        uint256 roundId
    ) external {
        _commitSeed(roundId);
    }

    function revealSeed(
        uint256 roundId
    ) external returns (uint256) {
        return _revealSeed(roundId);
    }

    function getSeed(
        uint256 roundId
    ) external view returns (uint256) {
        return _getSeed(roundId);
    }

    function getSeedOrReveal(
        uint256 roundId
    ) external returns (uint256) {
        return _getSeedOrReveal(roundId);
    }

    function isSeedCommitted(
        uint256 roundId
    ) external view returns (bool) {
        return _isSeedCommitted(roundId);
    }

    function isSeedRevealed(
        uint256 roundId
    ) external view returns (bool) {
        return _isSeedRevealed(roundId);
    }

    function isSeedReady(
        uint256 roundId
    ) external view returns (bool) {
        return _isSeedReady(roundId);
    }

    function isSeedExpired(
        uint256 roundId
    ) external view returns (bool) {
        return _isSeedExpired(roundId);
    }

    function getRemainingRevealWindow(
        uint256 roundId
    ) external view returns (uint256) {
        return _getRemainingRevealWindow(roundId);
    }

    function getSeedBlock(
        uint256 roundId
    ) external view returns (uint256) {
        return _getSeedBlock(roundId);
    }

    function getRoundSeedInfo(
        uint256 roundId
    ) external view returns (RoundSeed memory) {
        return _getRoundSeedInfo(roundId);
    }

    function getEffectiveWindow() external view returns (uint256) {
        return _getEffectiveWindow();
    }

    function deriveSubSeed(
        uint256 seed,
        uint256 index
    ) external pure returns (uint256) {
        return _deriveSubSeed(seed, index);
    }

    function seedToRange(
        uint256 seed,
        uint256 max
    ) external pure returns (uint256) {
        return _seedToRange(seed, max);
    }

    function seedToRangeInclusive(
        uint256 seed,
        uint256 min,
        uint256 max
    ) external pure returns (uint256) {
        return _seedToRangeInclusive(seed, min, max);
    }

    function seedToBool(
        uint256 seed,
        uint256 probabilityBps
    ) external pure returns (bool) {
        return _seedToBool(seed, probabilityBps);
    }
}
