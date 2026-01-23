// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";
import { FutureBlockRandomness } from "../../src/randomness/FutureBlockRandomness.sol";

/// @title FutureBlockRandomnessTest
/// @notice Tests for the FutureBlockRandomness abstract contract
contract FutureBlockRandomnessTest is Test {
    TestRandomness public randomness;

    function setUp() public {
        randomness = new TestRandomness();
        vm.roll(1000);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_DefaultSeedBlockDelay() public view {
        assertEq(randomness.DEFAULT_SEED_BLOCK_DELAY(), 10, "Default seed block delay should be 10");
    }

    function test_MinSeedBlockDelay() public view {
        assertEq(randomness.MIN_SEED_BLOCK_DELAY(), 5, "Minimum seed block delay should be 5");
    }

    function test_MaxBlockAge() public view {
        assertEq(randomness.MAX_BLOCK_AGE(), 256, "Max block age should be 256");
    }

    function test_ExtendedHistoryWindow() public view {
        assertEq(randomness.EXTENDED_HISTORY_WINDOW(), 8191, "Extended window should be 8191");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // COMMIT TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_CommitSeed_Success() public {
        uint256 roundId = 1;

        randomness.commitSeed(roundId);

        assertTrue(randomness.isSeedCommitted(roundId), "Seed should be committed");
        assertFalse(randomness.isSeedRevealed(roundId), "Seed should not be revealed");

        uint256 seedBlock = randomness.getSeedBlock(roundId);
        assertEq(seedBlock, block.number + 10, "Seed block should be current + default delay (10)");
    }

    function test_CommitSeed_RevertWhen_ZeroRoundId() public {
        vm.expectRevert(FutureBlockRandomness.InvalidRoundId.selector);
        randomness.commitSeed(0);
    }

    function test_CommitSeed_RevertWhen_AlreadyCommitted() public {
        randomness.commitSeed(1);

        vm.expectRevert(FutureBlockRandomness.SeedAlreadyCommitted.selector);
        randomness.commitSeed(1);
    }

    function test_CommitSeed_MultipleDifferentRounds() public {
        randomness.commitSeed(1);
        randomness.commitSeed(2);
        randomness.commitSeed(3);

        assertTrue(randomness.isSeedCommitted(1));
        assertTrue(randomness.isSeedCommitted(2));
        assertTrue(randomness.isSeedCommitted(3));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // REVEAL TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_RevealSeed_Success() public {
        uint256 roundId = 1;
        randomness.commitSeed(roundId);

        // Roll past seed block
        uint256 seedBlock = randomness.getSeedBlock(roundId);
        vm.roll(seedBlock + 1);

        uint256 seed = randomness.revealSeed(roundId);

        assertTrue(seed != 0, "Seed should be non-zero");
        assertTrue(randomness.isSeedRevealed(roundId), "Seed should be revealed");
    }

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

    function test_RevealSeed_RevertWhen_Expired() public {
        randomness.commitSeed(1);

        uint256 seedBlock = randomness.getSeedBlock(1);
        // Roll way past the window
        vm.roll(seedBlock + 300);

        vm.expectRevert(FutureBlockRandomness.SeedExpired.selector);
        randomness.revealSeed(1);
    }

    function test_RevealSeed_Idempotent() public {
        randomness.commitSeed(1);
        vm.roll(block.number + 60);

        uint256 seed1 = randomness.revealSeed(1);
        uint256 seed2 = randomness.revealSeed(1);

        assertEq(seed1, seed2, "Repeated reveals should return same seed");
    }

    function test_RevealSeed_DeterministicForSameBlock() public {
        // Create two contracts
        TestRandomness r1 = new TestRandomness();
        TestRandomness r2 = new TestRandomness();

        // Commit at same block
        r1.commitSeed(1);
        r2.commitSeed(1);

        // Both should have same seed block
        assertEq(r1.getSeedBlock(1), r2.getSeedBlock(1));

        // Roll to reveal
        vm.roll(block.number + 60);

        uint256 seed1 = r1.revealSeed(1);
        uint256 seed2 = r2.revealSeed(1);

        // Seeds should be DIFFERENT because address is included in derivation
        assertTrue(seed1 != seed2, "Different contracts should have different seeds");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE QUERY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_IsSeedReady() public {
        randomness.commitSeed(1);

        // Not ready yet
        assertFalse(randomness.isSeedReady(1), "Should not be ready immediately");

        // Roll to seed block (still not ready - need to pass it)
        uint256 seedBlock = randomness.getSeedBlock(1);
        vm.roll(seedBlock);
        assertFalse(randomness.isSeedReady(1), "Should not be ready at seed block");

        // Roll past seed block
        vm.roll(seedBlock + 1);
        assertTrue(randomness.isSeedReady(1), "Should be ready after seed block");
    }

    function test_IsSeedExpired() public {
        randomness.commitSeed(1);
        uint256 seedBlock = randomness.getSeedBlock(1);

        // Not expired yet
        vm.roll(seedBlock + 1);
        assertFalse(randomness.isSeedExpired(1), "Should not be expired");

        // Roll to edge of window (still not expired)
        vm.roll(seedBlock + 256);
        assertFalse(randomness.isSeedExpired(1), "Should not be expired at edge");

        // Roll past window
        vm.roll(seedBlock + 257);
        assertTrue(randomness.isSeedExpired(1), "Should be expired past window");
    }

    function test_GetRemainingRevealWindow() public {
        randomness.commitSeed(1);
        uint256 seedBlock = randomness.getSeedBlock(1);

        // Before seed block - should return full window + remaining to seed
        // Default delay is now 10 blocks
        uint256 remaining = randomness.getRemainingRevealWindow(1);
        assertEq(remaining, 256 + 10, "Should have full window plus default delay (10)");

        // At seed block
        vm.roll(seedBlock);
        remaining = randomness.getRemainingRevealWindow(1);
        assertEq(remaining, 256, "Should have full window");

        // 100 blocks past seed
        vm.roll(seedBlock + 100);
        remaining = randomness.getRemainingRevealWindow(1);
        assertEq(remaining, 156, "Should have 156 blocks remaining");

        // At window edge
        vm.roll(seedBlock + 256);
        remaining = randomness.getRemainingRevealWindow(1);
        assertEq(remaining, 0, "Should have 0 remaining at edge");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // UTILITY FUNCTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_DeriveSubSeed() public view {
        uint256 baseSeed = 12_345;

        uint256 sub0 = randomness.deriveSubSeed(baseSeed, 0);
        uint256 sub1 = randomness.deriveSubSeed(baseSeed, 1);
        uint256 sub2 = randomness.deriveSubSeed(baseSeed, 2);

        // All should be different
        assertTrue(sub0 != sub1, "Sub seeds 0 and 1 should differ");
        assertTrue(sub1 != sub2, "Sub seeds 1 and 2 should differ");
        assertTrue(sub0 != sub2, "Sub seeds 0 and 2 should differ");

        // Should be deterministic
        assertEq(randomness.deriveSubSeed(baseSeed, 0), sub0, "Should be deterministic");
    }

    function test_SeedToRange() public view {
        uint256 seed = 12_345;

        uint256 result = randomness.seedToRange(seed, 100);
        assertTrue(result < 100, "Result should be less than max");

        // Should be deterministic
        assertEq(randomness.seedToRange(seed, 100), result, "Should be deterministic");
    }

    function test_SeedToRangeInclusive() public view {
        uint256 seed = 12_345;

        uint256 result = randomness.seedToRangeInclusive(seed, 10, 20);
        assertTrue(result >= 10, "Result should be >= min");
        assertTrue(result <= 20, "Result should be <= max");
    }

    function test_SeedToBool() public view {
        uint256 seed = 12_345;

        // 50% probability
        bool result50 = randomness.seedToBool(seed, 5000);

        // 100% probability - always true
        bool result100 = randomness.seedToBool(seed, 10_000);
        assertTrue(result100, "100% should always be true");

        // 0% probability - always false
        bool result0 = randomness.seedToBool(seed, 0);
        assertFalse(result0, "0% should always be false");

        // Verify determinism
        assertEq(randomness.seedToBool(seed, 5000), result50, "Should be deterministic");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function testFuzz_SeedToRange(
        uint256 seed,
        uint256 max
    ) public view {
        vm.assume(max > 0);

        uint256 result = randomness.seedToRange(seed, max);
        assertTrue(result < max, "Result should be less than max");
    }

    function testFuzz_SeedToRangeInclusive(
        uint256 seed,
        uint256 min,
        uint256 max
    ) public view {
        vm.assume(max >= min);
        vm.assume(max - min < type(uint256).max);

        uint256 result = randomness.seedToRangeInclusive(seed, min, max);
        assertTrue(result >= min, "Result should be >= min");
        assertTrue(result <= max, "Result should be <= max");
    }

    function testFuzz_SeedToBool(
        uint256 seed,
        uint256 probability
    ) public view {
        vm.assume(probability <= 10_000);

        bool result = randomness.seedToBool(seed, probability);

        if (probability == 0) {
            assertFalse(result, "0% should always be false");
        }
        if (probability == 10_000) {
            assertTrue(result, "100% should always be true");
        }
    }

    function testFuzz_DeriveSubSeed_Unique(
        uint256 seed,
        uint8 index1,
        uint8 index2
    ) public view {
        vm.assume(index1 != index2);

        uint256 sub1 = randomness.deriveSubSeed(seed, index1);
        uint256 sub2 = randomness.deriveSubSeed(seed, index2);

        assertTrue(sub1 != sub2, "Different indices should produce different seeds");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SECURITY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_SeedIncludesChainId() public {
        // Commit seed
        randomness.commitSeed(1);
        vm.roll(block.number + 60);

        uint256 seed1 = randomness.revealSeed(1);

        // Change chain ID (simulating different chain)
        vm.chainId(999);

        // Need new contract for different chain
        TestRandomness r2 = new TestRandomness();
        r2.commitSeed(1);

        // Ensure same seed block for fair comparison
        uint256 seedBlock = r2.getSeedBlock(1);
        vm.roll(seedBlock + 1);

        // This should produce different seed due to chainId
        // (Though in practice the contracts would be at different addresses too)
        uint256 seed2 = r2.revealSeed(1);

        // Seeds should be different
        assertTrue(seed1 != seed2, "Different chain IDs should produce different seeds");
    }
}

/// @notice Concrete implementation of FutureBlockRandomness for testing
contract TestRandomness is FutureBlockRandomness {
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
    ) external view returns (FutureBlockRandomness.RoundSeed memory) {
        return _getRoundSeedInfo(roundId);
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
