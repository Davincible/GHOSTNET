// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Script, console2 } from "forge-std/Script.sol";

// Game contract
import { HashCrash } from "../src/arcade/games/HashCrash.sol";

// For registration
import { IArcadeCore } from "../src/arcade/interfaces/IArcadeCore.sol";

/// @title DeployHashCrash
/// @notice Deployment script for HashCrash game on MegaETH testnet
/// @dev Deploys HashCrash and registers it with existing ArcadeCore
///
/// Prerequisites:
/// - ArcadeCore must be deployed (see DeployArcade.s.sol)
/// - Deployer must have GAME_ADMIN_ROLE on ArcadeCore
///
/// Usage:
/// ARCADE_CORE=0x554a3cc63851e0526d9938817949F97dC45b00EC \
/// forge script script/DeployHashCrash.s.sol:DeployHashCrash \
///   --rpc-url megaeth_testnet \
///   --broadcast \
///   --skip-simulation \
///   --legacy
contract DeployHashCrash is Script {
    // Default config for HashCrash
    uint256 public constant MIN_ENTRY = 1 ether; // 1 DATA
    uint256 public constant MAX_ENTRY = 1000 ether; // 1000 DATA
    uint16 public constant RAKE_BPS = 500; // 5% rake
    uint16 public constant BURN_BPS = 5000; // 50% of rake burned (2.5% total burn)

    function run() external returns (address hashCrash) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address arcadeCore = vm.envAddress("ARCADE_CORE");

        console2.log("=== HashCrash Deployment ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("ArcadeCore:", arcadeCore);
        console2.log("");

        // Verify ArcadeCore exists
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(arcadeCore)
        }
        require(codeSize > 0, "ArcadeCore not deployed at address");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy HashCrash
        console2.log("Deploying HashCrash...");
        HashCrash game = new HashCrash(arcadeCore, deployer);
        hashCrash = address(game);
        console2.log("HashCrash deployed:", hashCrash);

        // Register game with ArcadeCore
        console2.log("Registering HashCrash with ArcadeCore...");
        IArcadeCore(arcadeCore).registerGame(
            hashCrash,
            IArcadeCore.GameConfig({
                minEntry: MIN_ENTRY,
                maxEntry: MAX_ENTRY,
                rakeBps: RAKE_BPS,
                burnBps: BURN_BPS,
                requiresPosition: false, // Anyone can play
                paused: false
            })
        );
        console2.log("HashCrash registered!");

        vm.stopBroadcast();

        _logDeployment(hashCrash, arcadeCore, deployer);
    }

    function _logDeployment(address hashCrash, address arcadeCore, address deployer) internal pure {
        console2.log("");
        console2.log("=== HASH CRASH DEPLOYMENT COMPLETE ===");
        console2.log("");
        console2.log("--- Contract ---");
        console2.log("HashCrash:", hashCrash);
        console2.log("");
        console2.log("--- Configuration ---");
        console2.log("ArcadeCore:", arcadeCore);
        console2.log("Owner:", deployer);
        console2.log("Min Entry (DATA):", MIN_ENTRY / 1 ether);
        console2.log("Max Entry (DATA):", MAX_ENTRY / 1 ether);
        console2.log("Rake (bps):", RAKE_BPS);
        console2.log("Burn of rake (bps):", BURN_BPS);
        console2.log("");
        console2.log("--- Game Flow ---");
        console2.log("1. Start round: call startRound()");
        console2.log("2. Place bets: call placeBet(amount) during 60s betting phase");
        console2.log("3. Lock round: call lockRound() after betting ends");
        console2.log("4. Wait for seed block: ~50 blocks (~5 seconds)");
        console2.log("5. Reveal crash: call revealCrash()");
        console2.log("6. Cash out: call cashOut(multiplier) before crash");
        console2.log("7. Resolve: call resolveRound() to settle losers");
        console2.log("");
        console2.log("--- To Play ---");
        console2.log("1. Approve ArcadeCore to spend DATA tokens");
        console2.log("2. Call game functions through HashCrash contract");
        console2.log("3. Withdraw winnings via arcadeCore.withdrawPayout()");
    }
}

/// @title DeployHashCrashOnly
/// @notice Deploy HashCrash without registering (for testing or if caller lacks GAME_ADMIN_ROLE)
contract DeployHashCrashOnly is Script {
    function run() external returns (address hashCrash) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address arcadeCore = vm.envAddress("ARCADE_CORE");

        console2.log("=== HashCrash Deployment (No Registration) ===");
        console2.log("Deployer:", deployer);
        console2.log("ArcadeCore:", arcadeCore);

        vm.startBroadcast(deployerPrivateKey);

        HashCrash game = new HashCrash(arcadeCore, deployer);
        hashCrash = address(game);

        vm.stopBroadcast();

        console2.log("");
        console2.log("HashCrash deployed:", hashCrash);
        console2.log("");
        console2.log("NOTE: Game not registered with ArcadeCore.");
        console2.log("Call arcadeCore.registerGame() with GAME_ADMIN_ROLE to enable.");
    }
}
