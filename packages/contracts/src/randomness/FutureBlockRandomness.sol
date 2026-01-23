// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { BlockhashHistory } from "./BlockhashHistory.sol";

/// @title FutureBlockRandomness
/// @notice Abstract base for games that require provably fair randomness
/// @dev Uses future block hash pattern with automatic fallback to EIP-2935 extended history.
///
///      RANDOMNESS FLOW:
///      1. COMMIT: Call _commitSeed(roundId) during bet acceptance
///         - Records seedBlock = block.number + _seedBlockDelay()
///         - Attacker cannot predict what hash this future block will have
///
///      2. WAIT: Wait for seedBlock to be mined
///         - Default 10 blocks = 1 second on MegaETH (100ms blocks)
///         - Games can override _seedBlockDelay() for custom timing
///
///      3. REVEAL: Call _revealSeed(roundId) to capture the seed
///         - Retrieves blockhash(seedBlock)
///         - Must be called before seedBlock + NATIVE_LIMIT (256 blocks)
///         - If missed, EIP-2935 provides extended window (8191 blocks)
///         - If both windows expire, seed is EXPIRED and round must refund
///
///      SECURITY PROPERTIES:
///      - Unpredictable: No one can predict future blockhash at commit time
///      - Verifiable: Anyone can verify the seed by checking blockhash
///      - Manipulation-resistant: Cost of block manipulation >> expected gain
///
///      ATTACK VECTORS & MITIGATIONS:
///      - Block proposer manipulation: Limited by stake slashing + impractical at MegaETH's speed
///      - Selective reveal: Operator incentivized to reveal (keeper rewards)
///      - Replay attacks: Seed derivation includes roundId, address, chainid
///
///      GAS COSTS:
///      - Commit: ~25,000 (2 storage writes)
///      - Reveal (native blockhash): ~30,000 (1 read + 3 writes)
///      - Reveal (EIP-2935): ~32,600 (adds staticcall overhead)
///
/// @custom:security-contact security@ghostnet.game
abstract contract FutureBlockRandomness {
    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Default blocks to wait before seed is ready
    /// @dev Block time varies by network:
    ///      - MegaETH mainnet: 100ms blocks → 2 blocks = 200ms
    ///      - MegaETH testnet: ~1s blocks → 2 blocks = ~2 seconds
    ///      Games can override via _seedBlockDelay() for different security/UX tradeoffs.
    uint256 public constant DEFAULT_SEED_BLOCK_DELAY = 2;

    /// @notice Minimum allowed seed block delay (safety floor)
    /// @dev Must be at least 1 block to ensure future block hash is used.
    ///      1 block provides minimum unpredictability guarantee.
    uint256 public constant MIN_SEED_BLOCK_DELAY = 1;

    /// @notice Maximum blocks before native blockhash() returns 0 (EVM hard limit)
    /// @dev On MegaETH: 256 blocks = 25.6 seconds reveal window
    uint256 public constant MAX_BLOCK_AGE = 256;

    /// @notice Extended history window via EIP-2935 (Prague EVM)
    /// @dev If MegaETH supports Prague EVM, we can access ~13.6 minutes of history.
    ///      Falls back to native blockhash if EIP-2935 unavailable.
    uint256 public constant EXTENDED_HISTORY_WINDOW = 8191;

    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Attempted operation on uncommitted seed
    error SeedNotCommitted();

    /// @notice Attempted reveal before seed block is mined
    error SeedNotReady();

    /// @notice Seed block is beyond all available history windows
    error SeedExpired();

    /// @notice Attempted to commit when seed already committed
    error SeedAlreadyCommitted();

    /// @notice Attempted to reveal when seed already revealed
    error SeedAlreadyRevealed();

    /// @notice Attempted seed operation on invalid round
    error InvalidRoundId();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when a seed block is committed
    /// @param roundId The round identifier
    /// @param seedBlock The block number that will provide randomness
    /// @param deadline The last block before seed expires (considering EIP-2935)
    event SeedCommitted(uint256 indexed roundId, uint256 seedBlock, uint256 deadline);

    /// @notice Emitted when a seed is revealed
    /// @param roundId The round identifier
    /// @param blockHash The captured block hash
    /// @param seed The derived seed value
    /// @param usedExtendedHistory True if EIP-2935 was used for retrieval
    event SeedRevealed(
        uint256 indexed roundId, bytes32 blockHash, uint256 seed, bool usedExtendedHistory
    );

    /// @notice Emitted when a seed expires (all history windows passed)
    /// @param roundId The round identifier
    /// @param seedBlock The seed block that expired
    /// @param expiredAtBlock The block when expiry was detected
    event SeedExpiredEvent(uint256 indexed roundId, uint256 seedBlock, uint256 expiredAtBlock);

    // ══════════════════════════════════════════════════════════════════════════════
    // STORAGE
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Seed tracking per round
    /// @dev Packed for storage efficiency: 8 + 8 + 1 + 1 + 1 = 19 bytes in slot 0,
    ///      then 32 + 32 bytes for hash and seed in slots 1-2
    struct RoundSeed {
        uint64 seedBlock; // Block number to use for seed
        uint64 commitBlock; // Block when commitment was made
        bool committed; // Seed block set
        bool revealed; // Seed captured
        bool usedExtendedHistory; // True if EIP-2935 was used
        bytes32 blockHash; // Captured block hash
        uint256 seed; // Final derived seed
    }

    /// @notice Seed storage per round
    mapping(uint256 roundId => RoundSeed) internal _roundSeeds;

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS - CORE
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Commit to a future block for randomness
    /// @dev Call this when bets are finalized and game is ready to generate outcome.
    ///      SECURITY: Must be called BEFORE players make choices that depend on randomness.
    ///
    /// @param roundId The round identifier (must be unique per game session)
    function _commitSeed(
        uint256 roundId
    ) internal {
        if (roundId == 0) revert InvalidRoundId();

        RoundSeed storage rs = _roundSeeds[roundId];
        if (rs.committed) revert SeedAlreadyCommitted();

        // Get delay from virtual function (allows game-specific configuration)
        uint256 delay = _seedBlockDelay();

        // Enforce minimum for safety
        if (delay < MIN_SEED_BLOCK_DELAY) {
            delay = MIN_SEED_BLOCK_DELAY;
        }

        uint64 seedBlock = uint64(block.number + delay);
        rs.seedBlock = seedBlock;
        rs.commitBlock = uint64(block.number);
        rs.committed = true;

        // Calculate deadline using effective window (considers EIP-2935 availability)
        uint256 deadline = seedBlock + _getEffectiveWindow();

        emit SeedCommitted(roundId, seedBlock, deadline);
    }

    /// @notice Get the seed block delay for this game
    /// @dev Override to customize delay. Higher stakes games may want longer delays.
    ///      Return value is clamped to MIN_SEED_BLOCK_DELAY minimum.
    ///
    ///      Recommended values for MegaETH (100ms blocks):
    ///      - Low stakes (< 100 DATA): 10 blocks (1 second)
    ///      - Medium stakes (100-1000 DATA): 15 blocks (1.5 seconds)
    ///      - High stakes (> 1000 DATA): 20+ blocks (2+ seconds)
    ///
    /// @return delay Number of blocks to wait
    function _seedBlockDelay() internal view virtual returns (uint256 delay) {
        return DEFAULT_SEED_BLOCK_DELAY;
    }

    /// @notice Reveal and cache the seed
    /// @dev Attempts native blockhash first (cheaper), falls back to EIP-2935.
    ///      SECURITY: The seed is derived with round-specific data to prevent cross-game replay.
    ///
    ///      IMPORTANT: This function should be called by:
    ///      1. Any user action that needs the seed (automatic reveal)
    ///      2. A keeper bot proactively (before window closes)
    ///      3. Admin in emergency (to enable refunds on expiry)
    ///
    /// @param roundId The round identifier
    /// @return seed The derived seed value (deterministic and verifiable)
    function _revealSeed(
        uint256 roundId
    ) internal returns (uint256 seed) {
        RoundSeed storage rs = _roundSeeds[roundId];

        if (!rs.committed) revert SeedNotCommitted();
        if (rs.revealed) return rs.seed; // Idempotent - return cached value
        if (block.number <= rs.seedBlock) revert SeedNotReady();

        // Try to get blockhash using library (native + EIP-2935 fallback)
        (bytes32 hash, bool usedExtended) = BlockhashHistory.getBlockhashWithFallback(rs.seedBlock);

        if (hash == bytes32(0)) {
            // Both native and extended failed - seed is truly expired
            emit SeedExpiredEvent(roundId, rs.seedBlock, block.number);
            revert SeedExpired();
        }

        // Derive seed with round-specific data to prevent cross-game replay
        // SECURITY: Including address(this) and block.chainid prevents:
        // - Replay attacks across different game contracts
        // - Replay attacks across different chains
        // - Collisions if same roundId is used in different games
        seed = uint256(keccak256(abi.encode(hash, roundId, address(this), block.chainid)));

        // Cache the revealed seed
        rs.blockHash = hash;
        rs.seed = seed;
        rs.revealed = true;
        rs.usedExtendedHistory = usedExtended;

        emit SeedRevealed(roundId, hash, seed, usedExtended);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS - QUERIES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get the cached seed for a round (reverts if not revealed)
    /// @param roundId The round identifier
    /// @return seed The cached seed value
    function _getSeed(
        uint256 roundId
    ) internal view returns (uint256 seed) {
        RoundSeed storage rs = _roundSeeds[roundId];
        if (!rs.revealed) revert SeedNotCommitted();
        return rs.seed;
    }

    /// @notice Get the cached seed if revealed, or try to reveal it
    /// @dev Convenience function that auto-reveals if possible
    /// @param roundId The round identifier
    /// @return seed The seed value
    function _getSeedOrReveal(
        uint256 roundId
    ) internal returns (uint256 seed) {
        RoundSeed storage rs = _roundSeeds[roundId];
        if (rs.revealed) {
            return rs.seed;
        }
        return _revealSeed(roundId);
    }

    /// @notice Check if seed is committed
    /// @param roundId The round identifier
    /// @return committed True if seed block has been set
    function _isSeedCommitted(
        uint256 roundId
    ) internal view returns (bool committed) {
        return _roundSeeds[roundId].committed;
    }

    /// @notice Check if seed is revealed
    /// @param roundId The round identifier
    /// @return revealed True if seed has been captured
    function _isSeedRevealed(
        uint256 roundId
    ) internal view returns (bool revealed) {
        return _roundSeeds[roundId].revealed;
    }

    /// @notice Check if seed can be revealed now
    /// @param roundId The round identifier
    /// @return ready True if seed block has been mined and hash is available
    function _isSeedReady(
        uint256 roundId
    ) internal view returns (bool ready) {
        RoundSeed storage rs = _roundSeeds[roundId];

        if (!rs.committed || rs.revealed) return false;
        if (block.number <= rs.seedBlock) return false;

        // Check if within any available window
        uint256 age = block.number - rs.seedBlock;
        return age <= _getEffectiveWindow();
    }

    /// @notice Check if seed has expired (beyond all recovery options)
    /// @dev IMPORTANT: If true, the game should transition to refund state
    /// @param roundId The round identifier
    /// @return expired True if seed is no longer retrievable
    function _isSeedExpired(
        uint256 roundId
    ) internal view returns (bool expired) {
        RoundSeed storage rs = _roundSeeds[roundId];

        if (!rs.committed || rs.revealed) return false;
        if (block.number <= rs.seedBlock) return false;

        uint256 age = block.number - rs.seedBlock;
        return age > _getEffectiveWindow();
    }

    /// @notice Get remaining blocks before seed expires
    /// @param roundId The round identifier
    /// @return remaining Blocks until expiry (0 if expired or not applicable)
    function _getRemainingRevealWindow(
        uint256 roundId
    ) internal view returns (uint256 remaining) {
        RoundSeed storage rs = _roundSeeds[roundId];

        if (!rs.committed || rs.revealed) return 0;
        if (block.number <= rs.seedBlock) {
            // Seed not ready yet - return full window from when it becomes ready
            return _getEffectiveWindow() + (rs.seedBlock - block.number);
        }

        uint256 age = block.number - rs.seedBlock;
        uint256 window = _getEffectiveWindow();

        if (age >= window) return 0;
        return window - age;
    }

    /// @notice Get the seed block for a round
    /// @param roundId The round identifier
    /// @return seedBlock The block number that provides randomness
    function _getSeedBlock(
        uint256 roundId
    ) internal view returns (uint256 seedBlock) {
        return _roundSeeds[roundId].seedBlock;
    }

    /// @notice Get full round seed info
    /// @param roundId The round identifier
    /// @return info The complete RoundSeed struct
    function _getRoundSeedInfo(
        uint256 roundId
    ) internal view returns (RoundSeed memory info) {
        return _roundSeeds[roundId];
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS - UTILITIES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get effective history window based on EIP-2935 availability
    /// @return window Maximum blocks of history available
    function _getEffectiveWindow() internal view returns (uint256 window) {
        return BlockhashHistory.getEffectiveWindow();
    }

    /// @notice Derive a sub-seed for multiple random values from one seed
    /// @dev Use this when you need multiple random values from a single seed.
    ///      Each index produces a deterministic, independent random value.
    ///
    ///      Example: For a game needing player order + card draws:
    ///      - subSeed(seed, 0) -> player order
    ///      - subSeed(seed, 1) -> first card
    ///      - subSeed(seed, 2) -> second card
    ///
    /// @param seed The base seed
    /// @param index The sub-seed index
    /// @return subSeed A derived random value
    function _deriveSubSeed(
        uint256 seed,
        uint256 index
    ) internal pure returns (uint256 subSeed) {
        return uint256(keccak256(abi.encode(seed, index)));
    }

    /// @notice Convert seed to a random value in range [0, max)
    /// @dev Uses modulo for uniform distribution.
    ///      The bias is negligible for max << 2^256.
    /// @param seed The seed value
    /// @param max The exclusive upper bound (must be > 0)
    /// @return result A uniformly distributed random value in [0, max)
    function _seedToRange(
        uint256 seed,
        uint256 max
    ) internal pure returns (uint256 result) {
        // SAFETY: Validate input to prevent division by zero
        if (max == 0) {
            return 0; // Safe fallback - caller error
        }
        return seed % max;
    }

    /// @notice Convert seed to a random value in range [min, max]
    /// @dev Inclusive on both ends
    /// @param seed The seed value
    /// @param min The inclusive lower bound
    /// @param max The inclusive upper bound (must be >= min)
    /// @return result A uniformly distributed random value in [min, max]
    function _seedToRangeInclusive(
        uint256 seed,
        uint256 min,
        uint256 max
    ) internal pure returns (uint256 result) {
        // SAFETY: Validate input to prevent underflow
        if (max < min) {
            return min; // Safe fallback - caller error
        }
        return min + (seed % (max - min + 1));
    }

    /// @notice Convert seed to a boolean with given probability
    /// @dev probability is in basis points (0-10000)
    /// @param seed The seed value
    /// @param probabilityBps The probability of returning true (0-10000)
    /// @return result True with given probability
    function _seedToBool(
        uint256 seed,
        uint256 probabilityBps
    ) internal pure returns (bool result) {
        return (seed % 10_000) < probabilityBps;
    }
}
