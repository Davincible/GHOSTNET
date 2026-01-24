// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console2} from "forge-std/Script.sol";

// Contract
import {DailyOps} from "../src/arcade/games/DailyOps.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title DeployDailyOps
/// @notice Deployment script for DailyOps on MegaETH testnet
/// @dev Deploys DailyOps with mission signer configuration
///
/// Environment variables:
/// - PRIVATE_KEY: Deployer private key
/// - DATA_TOKEN: Address of DATA token
/// - MISSION_SIGNER: Address that signs mission claims (optional, defaults to deployer)
///
/// Usage:
/// DATA_TOKEN=0xf278eb6Cd5255dC67CFBcdbD57F91baCB3735804 \
/// forge script script/DeployDailyOps.s.sol:DeployDailyOps \
///   --rpc-url megaeth_testnet \
///   --broadcast \
///   --skip-simulation \
///   --legacy
contract DeployDailyOps is Script {
    // Initial treasury funding for rewards
    uint256 public constant INITIAL_TREASURY = 100_000 ether; // 100k DATA for testing

    function run() external returns (address dailyOps) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address dataToken = vm.envAddress("DATA_TOKEN");

        // Mission signer defaults to deployer if not set
        address missionSigner = deployer;
        try vm.envAddress("MISSION_SIGNER") returns (address signer) {
            missionSigner = signer;
        } catch {}

        console2.log("=== DailyOps Deployment ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("DATA Token:", dataToken);
        console2.log("Mission Signer:", missionSigner);
        console2.log("");

        // Verify DATA token exists
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(dataToken)
        }
        require(codeSize > 0, "DATA token not deployed at address");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy DailyOps
        console2.log("Deploying DailyOps...");
        DailyOps ops = new DailyOps(dataToken, deployer, missionSigner);
        dailyOps = address(ops);
        console2.log("DailyOps deployed:", dailyOps);

        // Fund treasury for testing
        uint256 deployerBalance = IERC20(dataToken).balanceOf(deployer);
        if (deployerBalance >= INITIAL_TREASURY) {
            console2.log("Funding treasury with initial rewards...");
            IERC20(dataToken).approve(dailyOps, INITIAL_TREASURY);
            ops.fundTreasury(INITIAL_TREASURY);
            console2.log("Treasury funded:", INITIAL_TREASURY / 1 ether, "DATA");
        } else {
            console2.log("WARNING: Insufficient DATA balance for treasury funding");
            console2.log("Deployer balance:", deployerBalance / 1 ether, "DATA");
            console2.log("Required:", INITIAL_TREASURY / 1 ether, "DATA");
        }

        vm.stopBroadcast();

        _logDeployment(dailyOps, dataToken, missionSigner, deployer);
    }

    function _logDeployment(
        address dailyOps,
        address dataToken,
        address missionSigner,
        address admin
    ) internal pure {
        console2.log("");
        console2.log("=== DAILYOPS DEPLOYMENT COMPLETE ===");
        console2.log("");
        console2.log("--- Contract ---");
        console2.log("DailyOps:", dailyOps);
        console2.log("");
        console2.log("--- Configuration ---");
        console2.log("DATA Token:", dataToken);
        console2.log("Mission Signer:", missionSigner);
        console2.log("Admin:", admin);
        console2.log("");
        console2.log("--- Shield Costs ---");
        console2.log("1-Day Shield: 50 DATA (burned)");
        console2.log("7-Day Shield: 200 DATA (burned)");
        console2.log("");
        console2.log("--- Milestones ---");
        console2.log("7 days: 500 DATA bonus + WEEK_WARRIOR badge");
        console2.log("21 days: 1,000 DATA bonus");
        console2.log("30 days: 5,000 DATA bonus + DEDICATED_OPERATOR badge");
        console2.log("90 days: 15,000 DATA bonus + LEGEND badge");
        console2.log("");
        console2.log("--- Death Rate Reduction ---");
        console2.log("3+ days: -3%");
        console2.log("14+ days: -5%");
        console2.log("60+ days: -8%");
        console2.log("180+ days: -10%");
        console2.log("");
        console2.log("--- Frontend Update ---");
        console2.log("Add to apps/web/src/lib/web3/abis.ts:");
        console2.log("  6343: {");
        console2.log("    dailyOps: '", dailyOps, "',");
        console2.log("  }");
    }
}
