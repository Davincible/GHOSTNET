// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console2 } from "forge-std/Script.sol";
import { PrevRandaoTest } from "../src/test/PrevRandaoTest.sol";

/// @title DeployPrevRandaoTest
/// @notice Deployment script for PrevRandaoTest contract on MegaETH testnet
/// @dev Run with: forge script script/DeployPrevRandaoTest.s.sol --rpc-url megaeth_testnet --broadcast --skip-simulation --gas-limit 10000000
contract DeployPrevRandaoTest is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying PrevRandaoTest to MegaETH testnet...");
        console2.log("Deployer:", vm.addr(deployerPrivateKey));

        vm.startBroadcast(deployerPrivateKey);

        PrevRandaoTest testContract = new PrevRandaoTest();

        vm.stopBroadcast();

        console2.log("PrevRandaoTest deployed to:", address(testContract));
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Wait for deployment confirmation");
        console2.log(
            "2. Run verification script: forge script script/VerifyPrevRandao.s.sol --rpc-url megaeth_testnet --broadcast --skip-simulation"
        );
        console2.log("3. Or manually call recordSample() several times via cast");
    }
}

/// @title VerifyPrevRandao
/// @notice Script to record samples and verify prevrandao behavior
/// @dev Run multiple times across different blocks
contract VerifyPrevRandao is Script {
    function run() external {
        address testContract = vm.envAddress("PREVRANDAO_TEST_CONTRACT");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Recording prevrandao sample...");
        console2.log("Contract:", testContract);

        vm.startBroadcast(deployerPrivateKey);

        PrevRandaoTest test = PrevRandaoTest(testContract);

        // Record a sample
        (uint256 sampleId, uint256 prevrandao, uint256 derivedRandom) = test.recordSample();

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Sample Recorded ===");
        console2.log("Sample ID:", sampleId);
        console2.log("prevrandao:", prevrandao);
        console2.log("Derived random:", derivedRandom);

        // Check if prevrandao looks valid
        if (prevrandao == 0) {
            console2.log("");
            console2.log("WARNING: prevrandao returned 0!");
            console2.log("This may indicate prevrandao is not supported on this chain.");
        } else {
            console2.log("");
            console2.log("SUCCESS: prevrandao returned non-zero value");
        }
    }
}

/// @title AnalyzePrevRandao
/// @notice Script to analyze collected samples
/// @dev Run after collecting multiple samples
contract AnalyzePrevRandao is Script {
    function run() external view {
        address testContract = vm.envAddress("PREVRANDAO_TEST_CONTRACT");

        console2.log("Analyzing prevrandao samples...");
        console2.log("Contract:", testContract);
        console2.log("");

        PrevRandaoTest test = PrevRandaoTest(testContract);

        // Get analysis
        (
            bool isWorking,
            uint256 totalSamples,
            uint256 uniqueValues,
            uint256 lastValue,
            bool isNonZero
        ) = test.analyze();

        console2.log("=== Analysis Results ===");
        console2.log("Total samples:", totalSamples);
        console2.log("Unique prevrandao values:", uniqueValues);
        console2.log("Last prevrandao value:", lastValue);
        console2.log("Last value non-zero:", isNonZero);
        console2.log("");

        if (totalSamples > 0) {
            uint256 uniquePercent = (uniqueValues * 100) / totalSamples;
            console2.log("Uniqueness ratio:", uniquePercent, "%");
        }

        console2.log("");
        if (isWorking) {
            console2.log("VERDICT: prevrandao appears to be WORKING");
            console2.log("Safe to proceed with block-based randomness strategy.");
        } else if (totalSamples < 5) {
            console2.log("VERDICT: INSUFFICIENT DATA");
            console2.log("Please record at least 5 samples across different blocks.");
        } else {
            console2.log("VERDICT: prevrandao may NOT be working properly");
            console2.log("Consider using commit-reveal or VRF instead.");
        }
    }
}

/// @title SimulateTraceScan
/// @notice Script to test trace scan simulation with current block randomness
contract SimulateTraceScan is Script {
    function run() external view {
        address testContract = vm.envAddress("PREVRANDAO_TEST_CONTRACT");

        console2.log("Simulating trace scan...");

        PrevRandaoTest test = PrevRandaoTest(testContract);

        // Simulate a DARKNET scan (40% death rate, 100 positions)
        uint256 positionCount = 100;
        uint256 deathRateBps = 4000; // 40%

        (uint256 seed, uint256 deaths, uint256[] memory deathIndices) =
            test.simulateTraceScan(positionCount, deathRateBps);

        console2.log("");
        console2.log("=== Trace Scan Simulation ===");
        console2.log("Positions:", positionCount);
        console2.log("Target death rate:", deathRateBps / 100, "%");
        console2.log("Random seed:", seed);
        console2.log("Deaths:", deaths);
        console2.log("Actual death rate:", (deaths * 100) / positionCount, "%");

        if (deaths > 0 && deaths <= 10) {
            console2.log("");
            console2.log("Death indices:");
            for (uint256 i = 0; i < deaths; i++) {
                console2.log("  Position", deathIndices[i]);
            }
        }

        // Run statistical test
        console2.log("");
        console2.log("=== Statistical Test (50 iterations) ===");

        (uint256 avgDeathRate, uint256 minDeaths, uint256 maxDeaths) =
            test.statisticalTest(50, 100, 4000);

        console2.log("Average death rate:", avgDeathRate / 100, "%");
        console2.log("Min deaths:", minDeaths);
        console2.log("Max deaths:", maxDeaths);

        // Check if within acceptable variance
        // For 40% rate with 100 positions, expect ~40 deaths
        // Standard deviation ~4.9, so 3-sigma range is roughly 25-55
        if (avgDeathRate >= 3500 && avgDeathRate <= 4500) {
            console2.log("");
            console2.log("VERDICT: Death rate distribution looks FAIR");
        } else {
            console2.log("");
            console2.log("WARNING: Death rate may be biased. Investigate further.");
        }
    }
}
