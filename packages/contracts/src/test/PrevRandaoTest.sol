// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title PrevRandaoTest
/// @notice Test contract to verify prevrandao behavior on MegaETH
/// @dev Deploy to MegaETH testnet and call recordSample() multiple times
///      to verify randomness quality before using in production
contract PrevRandaoTest {
    // ============ Events ============

    /// @notice Emitted each time recordSample() is called
    /// @param sampleId Incrementing sample number
    /// @param prevrandao The block.prevrandao value
    /// @param blockNumber Current block number
    /// @param blockTimestamp Current block timestamp
    /// @param derivedRandom A hash combining multiple block values
    event RandomnessSample(
        uint256 indexed sampleId,
        uint256 prevrandao,
        uint256 blockNumber,
        uint256 blockTimestamp,
        uint256 derivedRandom
    );

    /// @notice Emitted when batch recording completes
    event BatchComplete(uint256 startId, uint256 endId, uint256 uniqueValues);

    // ============ State ============

    /// @notice Total samples recorded
    uint256 public sampleCount;

    /// @notice Historical prevrandao values for analysis
    uint256[] public prevrandaoHistory;

    /// @notice Historical derived random values
    uint256[] public derivedHistory;

    /// @notice Track unique values seen (for entropy analysis)
    mapping(uint256 => bool) public seenPrevrandao;
    uint256 public uniquePrevrandaoCount;

    /// @notice Last recorded values for quick checking
    uint256 public lastPrevrandao;
    uint256 public lastBlockNumber;
    uint256 public lastDerivedRandom;

    // ============ Core Functions ============

    /// @notice Record a single randomness sample
    /// @dev Call this multiple times across different blocks to verify randomness
    /// @return sampleId The ID of this sample
    /// @return prevrandao The block.prevrandao value
    /// @return derivedRandom A derived random value combining multiple sources
    function recordSample()
        external
        returns (uint256 sampleId, uint256 prevrandao, uint256 derivedRandom)
    {
        sampleId = sampleCount++;
        prevrandao = block.prevrandao;

        // Derive a random value similar to how we'd use it in production
        derivedRandom = uint256(
            keccak256(
                abi.encode(block.prevrandao, block.timestamp, block.number, address(this), sampleId)
            )
        );

        // Store for analysis
        prevrandaoHistory.push(prevrandao);
        derivedHistory.push(derivedRandom);

        // Track uniqueness
        if (!seenPrevrandao[prevrandao]) {
            seenPrevrandao[prevrandao] = true;
            uniquePrevrandaoCount++;
        }

        // Update last values
        lastPrevrandao = prevrandao;
        lastBlockNumber = block.number;
        lastDerivedRandom = derivedRandom;

        emit RandomnessSample(sampleId, prevrandao, block.number, block.timestamp, derivedRandom);

        return (sampleId, prevrandao, derivedRandom);
    }

    /// @notice Get current block's randomness without recording
    /// @dev Use this to quickly check values without changing state
    function getCurrentRandomness()
        external
        view
        returns (
            uint256 prevrandao,
            uint256 blockNumber,
            uint256 blockTimestamp,
            uint256 derivedRandom
        )
    {
        prevrandao = block.prevrandao;
        blockNumber = block.number;
        blockTimestamp = block.timestamp;
        derivedRandom = uint256(
            keccak256(
                abi.encode(
                    block.prevrandao,
                    block.timestamp,
                    block.number,
                    address(this),
                    sampleCount // Use current count as nonce
                )
            )
        );
    }

    // ============ Analysis Functions ============

    /// @notice Get the last N samples for analysis
    /// @param count Number of samples to return (from most recent)
    /// @return prevrandaoValues Array of prevrandao values
    /// @return derivedValues Array of derived random values
    function getRecentSamples(
        uint256 count
    ) external view returns (uint256[] memory prevrandaoValues, uint256[] memory derivedValues) {
        uint256 len = prevrandaoHistory.length;
        if (count > len) count = len;

        prevrandaoValues = new uint256[](count);
        derivedValues = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 idx = len - count + i;
            prevrandaoValues[i] = prevrandaoHistory[idx];
            derivedValues[i] = derivedHistory[idx];
        }
    }

    /// @notice Check if prevrandao appears to be working
    /// @dev Returns analysis results for verification
    /// @return isWorking True if prevrandao shows variance
    /// @return totalSamples Number of samples recorded
    /// @return uniqueValues Number of unique prevrandao values seen
    /// @return lastValue Most recent prevrandao value
    /// @return isNonZero True if last value was non-zero
    function analyze()
        external
        view
        returns (
            bool isWorking,
            uint256 totalSamples,
            uint256 uniqueValues,
            uint256 lastValue,
            bool isNonZero
        )
    {
        totalSamples = sampleCount;
        uniqueValues = uniquePrevrandaoCount;
        lastValue = lastPrevrandao;
        isNonZero = lastPrevrandao != 0;

        // Consider it "working" if we have multiple samples and they're mostly unique
        // Allow for some collisions but expect high entropy
        if (totalSamples >= 5) {
            // At least 80% unique values indicates good randomness
            isWorking = (uniqueValues * 100 / totalSamples) >= 80 && isNonZero;
        } else if (totalSamples > 0) {
            // With few samples, just check non-zero
            isWorking = isNonZero;
        } else {
            isWorking = false;
        }
    }

    /// @notice Simulate death selection like TraceScan would
    /// @param positionCount Number of positions to simulate
    /// @param deathRateBps Death rate in basis points (e.g., 4000 = 40%)
    /// @return seed The random seed used
    /// @return deaths Number of simulated deaths
    /// @return deathIndices Which position indices would die
    function simulateTraceScan(
        uint256 positionCount,
        uint256 deathRateBps
    ) external view returns (uint256 seed, uint256 deaths, uint256[] memory deathIndices) {
        require(positionCount > 0 && positionCount <= 1000, "Invalid position count");
        require(deathRateBps <= 10_000, "Invalid death rate");

        // Generate seed like we would in production
        seed = uint256(
            keccak256(abi.encode(block.prevrandao, block.timestamp, block.number, positionCount))
        );

        // Count deaths and track indices
        uint256[] memory tempIndices = new uint256[](positionCount);
        uint256 deathCount = 0;

        for (uint256 i = 0; i < positionCount; i++) {
            // Per-position randomness
            uint256 positionSeed = uint256(keccak256(abi.encode(seed, i)));
            uint256 roll = positionSeed % 10_000;

            if (roll < deathRateBps) {
                tempIndices[deathCount] = i;
                deathCount++;
            }
        }

        // Copy to correctly sized array
        deaths = deathCount;
        deathIndices = new uint256[](deathCount);
        for (uint256 i = 0; i < deathCount; i++) {
            deathIndices[i] = tempIndices[i];
        }
    }

    /// @notice Check statistical distribution of simulated death rates
    /// @dev Run multiple simulations to verify fairness
    /// @param iterations Number of trace scans to simulate
    /// @param positionCount Positions per scan
    /// @param targetDeathRateBps Expected death rate
    /// @return avgDeathRate Average observed death rate (basis points)
    /// @return minDeaths Minimum deaths in any iteration
    /// @return maxDeaths Maximum deaths in any iteration
    function statisticalTest(
        uint256 iterations,
        uint256 positionCount,
        uint256 targetDeathRateBps
    ) external view returns (uint256 avgDeathRate, uint256 minDeaths, uint256 maxDeaths) {
        require(iterations > 0 && iterations <= 100, "1-100 iterations");
        require(positionCount > 0 && positionCount <= 100, "1-100 positions");

        uint256 totalDeaths = 0;
        minDeaths = type(uint256).max;
        maxDeaths = 0;

        for (uint256 iter = 0; iter < iterations; iter++) {
            // Generate unique seed per iteration
            uint256 seed = uint256(
                keccak256(abi.encode(block.prevrandao, block.timestamp, iter, positionCount))
            );

            uint256 deaths = 0;
            for (uint256 i = 0; i < positionCount; i++) {
                uint256 positionSeed = uint256(keccak256(abi.encode(seed, i)));
                if (positionSeed % 10_000 < targetDeathRateBps) {
                    deaths++;
                }
            }

            totalDeaths += deaths;
            if (deaths < minDeaths) minDeaths = deaths;
            if (deaths > maxDeaths) maxDeaths = deaths;
        }

        avgDeathRate = (totalDeaths * 10_000) / (iterations * positionCount);
    }
}
