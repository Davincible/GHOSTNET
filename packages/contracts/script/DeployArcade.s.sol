// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Script, console2 } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Arcade contracts
import { ArcadeCore } from "../src/arcade/ArcadeCore.sol";
import { GameRegistry } from "../src/arcade/GameRegistry.sol";

// For testing randomness
import { BlockhashHistory } from "../src/randomness/BlockhashHistory.sol";

// Mock token for testing
import { MockERC20 } from "../src/mocks/MockERC20.sol";

/// @title DeployedArcadeAddresses
/// @notice Holds all deployed arcade contract addresses
struct DeployedArcadeAddresses {
    address mockToken; // Only set if we deployed a mock
    address arcadeCoreImpl;
    address arcadeCore;
    address gameRegistry;
}

/// @title DeployArcade
/// @notice Deployment script for GHOSTNET Arcade contracts on MegaETH
/// @dev Deploys ArcadeCore (UUPS proxy) and GameRegistry
///
/// Usage:
/// forge script script/DeployArcade.s.sol:DeployArcade \
///   --rpc-url megaeth_testnet \
///   --broadcast \
///   --skip-simulation \
///   --gas-limit 10000000
contract DeployArcade is Script {
    function run() external returns (DeployedArcadeAddresses memory deployed) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address dataToken = vm.envOr("DATA_TOKEN_ADDRESS", address(0));
        address ghostCore = vm.envOr("GHOST_CORE_ADDRESS", address(0));
        address treasury = vm.envOr("TREASURY_ADDRESS", deployer);

        console2.log("=== GHOSTNET Arcade Deployment ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Treasury:", treasury);
        console2.log("DataToken:", dataToken);
        console2.log("GhostCore:", ghostCore);
        console2.log("");

        // Verify EIP-2935 availability
        _checkEIP2935();

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock token if no dataToken provided
        address mockTokenAddr = address(0);
        if (dataToken == address(0)) {
            console2.log("No DATA_TOKEN_ADDRESS provided, deploying mock token...");
            MockERC20 mockToken = new MockERC20("Mock DATA", "mDATA");
            mockTokenAddr = address(mockToken);
            dataToken = mockTokenAddr;
            console2.log("MockERC20 deployed:", mockTokenAddr);
        }

        // Deploy ArcadeCore implementation
        console2.log("Deploying ArcadeCore implementation...");
        ArcadeCore arcadeCoreImpl = new ArcadeCore();
        console2.log("ArcadeCore impl:", address(arcadeCoreImpl));

        // Deploy ArcadeCore proxy
        // Note: ArcadeCore.initialize(dataToken, ghostCore, treasury, admin)
        console2.log("Deploying ArcadeCore proxy...");
        bytes memory initData =
            abi.encodeCall(ArcadeCore.initialize, (dataToken, ghostCore, treasury, deployer));
        ERC1967Proxy arcadeCoreProxy = new ERC1967Proxy(address(arcadeCoreImpl), initData);
        console2.log("ArcadeCore proxy:", address(arcadeCoreProxy));

        // Deploy GameRegistry (owner, arcadeCore)
        console2.log("Deploying GameRegistry...");
        GameRegistry gameRegistry = new GameRegistry(deployer, address(arcadeCoreProxy));
        console2.log("GameRegistry:", address(gameRegistry));

        vm.stopBroadcast();

        deployed = DeployedArcadeAddresses({
            mockToken: mockTokenAddr,
            arcadeCoreImpl: address(arcadeCoreImpl),
            arcadeCore: address(arcadeCoreProxy),
            gameRegistry: address(gameRegistry)
        });

        _logDeployment(deployed, deployer, treasury, dataToken, ghostCore);
    }

    function _checkEIP2935() internal view {
        console2.log("Checking EIP-2935 availability...");

        address eip2935 = 0x0000F90827F1C53a10cb7A02335B175320002935;
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(eip2935)
        }

        if (codeSize > 0) {
            console2.log("EIP-2935: AVAILABLE (extended 8191 block history)");
        } else {
            console2.log("EIP-2935: NOT AVAILABLE (limited to 256 blocks)");
            console2.log("WARNING: Seed reveals must happen within 25.6 seconds!");
        }
        console2.log("");
    }

    function _logDeployment(
        DeployedArcadeAddresses memory d,
        address deployer,
        address treasury,
        address dataToken,
        address ghostCore
    ) internal pure {
        console2.log("");
        console2.log("=== ARCADE DEPLOYMENT COMPLETE ===");
        console2.log("");
        console2.log("--- Contracts ---");
        if (d.mockToken != address(0)) {
            console2.log("MockERC20 (mDATA):", d.mockToken);
        }
        console2.log("ArcadeCore (impl):", d.arcadeCoreImpl);
        console2.log("ArcadeCore (proxy):", d.arcadeCore);
        console2.log("GameRegistry:", d.gameRegistry);
        console2.log("");
        console2.log("--- Configuration ---");
        console2.log("Deployer/Admin:", deployer);
        console2.log("Treasury:", treasury);
        console2.log("DataToken:", dataToken);
        console2.log("GhostCore:", ghostCore);
        console2.log("");
        console2.log("--- Next Steps ---");
        console2.log("1. Deploy game contracts (HashCrash, etc.)");
        console2.log("2. Register games via GameRegistry.registerGame()");
        console2.log("3. Transfer admin to Timelock + Multisig before mainnet");
    }
}

/// @title VerifyEIP2935
/// @notice Simple script to verify EIP-2935 is working on the target chain
contract VerifyEIP2935 is Script {
    function run() external view {
        console2.log("=== EIP-2935 Verification ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("");

        address eip2935 = 0x0000F90827F1C53a10cb7A02335B175320002935;

        // Check if contract exists
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(eip2935)
        }

        if (codeSize == 0) {
            console2.log("Result: EIP-2935 NOT AVAILABLE");
            console2.log("The system contract has no code.");
            console2.log("Randomness will be limited to 256 block window.");
            return;
        }

        console2.log("Result: EIP-2935 IS AVAILABLE");
        console2.log("Contract size:", codeSize, "bytes");
        console2.log("");

        // Try to query a recent block
        uint256 targetBlock = block.number > 10 ? block.number - 10 : 1;
        console2.log("Testing query for block:", targetBlock);

        // Use BlockhashHistory library
        bool available = BlockhashHistory.isAvailable();
        console2.log("BlockhashHistory.isAvailable():", available);

        if (available) {
            bytes32 hash = BlockhashHistory.getBlockhash(targetBlock);
            console2.log("BlockhashHistory.getBlockhash() returned:");
            console2.logBytes32(hash);

            uint256 window = BlockhashHistory.getEffectiveWindow();
            console2.log("Effective window:", window, "blocks");

            if (block.chainid == 6343) {
                // MegaETH testnet - 100ms blocks
                console2.log("On MegaETH (100ms blocks):");
                console2.log("  - Native window: 25.6 seconds");
                console2.log("  - Extended window (seconds):", window / 10);
                console2.log("  - Extended window (minutes):", window / 600);
            }
        }
    }
}
