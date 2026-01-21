// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Script, console2 } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Core contracts
import { DataToken } from "../src/token/DataToken.sol";
import { TeamVesting } from "../src/token/TeamVesting.sol";
import { GhostCore } from "../src/core/GhostCore.sol";
import { TraceScan } from "../src/core/TraceScan.sol";

// Markets
import { DeadPool } from "../src/markets/DeadPool.sol";

// Periphery
import { RewardsDistributor } from "../src/periphery/RewardsDistributor.sol";
import { FeeRouter } from "../src/periphery/FeeRouter.sol";

/// @title DeployConfig
/// @notice Configuration struct to avoid stack too deep errors
struct DeployConfig {
    address deployer;
    address treasury;
    address boostSigner;
    address teamBeneficiary;
    address presaleWallet;
    address liquidityWallet;
    address weth;
    address swapRouter;
    uint256 tollAmount;
}

/// @title DeployedAddresses
/// @notice Holds all deployed contract addresses
struct DeployedAddresses {
    address dataToken;
    address teamVesting;
    address ghostCoreImpl;
    address ghostCore;
    address traceScanImpl;
    address traceScan;
    address deadPoolImpl;
    address deadPool;
    address rewardsDistributor;
    address feeRouter;
}

/// @title DeployAll
/// @notice Full deployment script for GHOSTNET contracts on MegaETH
/// @dev Deploys all contracts in the correct order with proper permissions
///
/// Deployment Order:
/// 1. DataToken (immutable) - Trust anchor
/// 2. TeamVesting (immutable) - Team token vesting
/// 3. GhostCore (UUPS proxy) - Main game logic
/// 4. TraceScan (UUPS proxy) - Randomness and death verification
/// 5. DeadPool (UUPS proxy) - Prediction market
/// 6. RewardsDistributor (immutable) - Emission distribution
/// 7. FeeRouter (immutable) - ETH toll and buyback
/// 8. Configure roles and permissions
///
/// Environment Variables Required:
/// - PRIVATE_KEY: Deployer private key
/// - TREASURY_ADDRESS: Treasury multisig address
/// - BOOST_SIGNER_ADDRESS: Address that signs boost authorizations
/// - TEAM_VESTING_BENEFICIARY: Address to receive vested team tokens
///
/// Usage:
/// forge script script/Deploy.s.sol:DeployAll --rpc-url megaeth_testnet --broadcast
contract DeployAll is Script {
    // Token distribution (must sum to 100M)
    uint256 constant TOTAL_SUPPLY = 100_000_000 * 1e18;
    uint256 constant REWARDS_ALLOCATION = 60_000_000 * 1e18; // 60% - The Mine
    uint256 constant PRESALE_ALLOCATION = 15_000_000 * 1e18; // 15% - Presale
    uint256 constant LIQUIDITY_ALLOCATION = 9_000_000 * 1e18; // 9% - LP (to be burned)
    uint256 constant TEAM_ALLOCATION = 8_000_000 * 1e18; // 8% - Team vesting
    uint256 constant TREASURY_ALLOCATION = 8_000_000 * 1e18; // 8% - Treasury

    function run() external returns (DeployedAddresses memory deployed) {
        DeployConfig memory cfg = _loadConfig();

        console2.log("=== GHOSTNET Deployment ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", cfg.deployer);
        console2.log("Treasury:", cfg.treasury);
        console2.log("");

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        deployed = _deployAll(cfg);

        vm.stopBroadcast();

        _logDeployment(deployed, cfg);
    }

    function _loadConfig() internal view returns (DeployConfig memory cfg) {
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));

        cfg = DeployConfig({
            deployer: deployer,
            treasury: vm.envOr("TREASURY_ADDRESS", deployer),
            boostSigner: vm.envOr("BOOST_SIGNER_ADDRESS", deployer),
            teamBeneficiary: vm.envOr("TEAM_VESTING_BENEFICIARY", deployer),
            presaleWallet: vm.envOr("PRESALE_WALLET", deployer),
            liquidityWallet: vm.envOr("LIQUIDITY_WALLET", deployer),
            weth: vm.envOr("WETH_ADDRESS", address(0x4200000000000000000000000000000000000006)),
            swapRouter: vm.envOr("SWAP_ROUTER_ADDRESS", address(0)),
            tollAmount: vm.envOr("TOLL_AMOUNT", uint256(0.0005 ether))
        });
    }

    function _deployAll(
        DeployConfig memory cfg
    ) internal returns (DeployedAddresses memory d) {
        // Phase 1: DataToken
        d.dataToken = _deployDataToken(cfg);

        // Phase 2: TeamVesting
        d.teamVesting = _deployTeamVesting(cfg, d.dataToken);

        // Phase 3: GhostCore
        (d.ghostCoreImpl, d.ghostCore) = _deployGhostCore(cfg, d.dataToken);

        // Phase 4: TraceScan
        (d.traceScanImpl, d.traceScan) = _deployTraceScan(cfg, d.ghostCore);

        // Phase 5: DeadPool
        (d.deadPoolImpl, d.deadPool) = _deployDeadPool(cfg, d.dataToken);

        // Phase 6: RewardsDistributor
        d.rewardsDistributor = _deployRewardsDistributor(cfg, d.dataToken, d.ghostCore);

        // Phase 7: FeeRouter
        d.feeRouter = _deployFeeRouter(cfg, d.dataToken);

        // Phase 8: Configure roles
        _configureRoles(cfg, d);

        // Phase 9: Set tax exclusions
        _setTaxExclusions(d);
    }

    function _deployDataToken(
        DeployConfig memory cfg
    ) internal returns (address) {
        console2.log("Phase 1: Deploying DataToken...");

        address[] memory recipients = new address[](5);
        uint256[] memory amounts = new uint256[](5);

        recipients[0] = cfg.deployer; // Will transfer to RewardsDistributor
        amounts[0] = REWARDS_ALLOCATION;
        recipients[1] = cfg.presaleWallet;
        amounts[1] = PRESALE_ALLOCATION;
        recipients[2] = cfg.liquidityWallet;
        amounts[2] = LIQUIDITY_ALLOCATION;
        recipients[3] = cfg.deployer; // Will transfer to TeamVesting
        amounts[3] = TEAM_ALLOCATION;
        recipients[4] = cfg.treasury;
        amounts[4] = TREASURY_ALLOCATION;

        DataToken token = new DataToken(cfg.treasury, cfg.deployer, recipients, amounts);
        console2.log("DataToken deployed:", address(token));

        return address(token);
    }

    function _deployTeamVesting(
        DeployConfig memory cfg,
        address dataToken
    ) internal returns (address) {
        console2.log("Phase 2: Deploying TeamVesting...");

        address[] memory beneficiaries = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        beneficiaries[0] = cfg.teamBeneficiary;
        amounts[0] = TEAM_ALLOCATION;

        TeamVesting vesting = new TeamVesting(IERC20(dataToken), beneficiaries, amounts);
        console2.log("TeamVesting deployed:", address(vesting));

        // Transfer team allocation
        DataToken(dataToken).transfer(address(vesting), TEAM_ALLOCATION);
        console2.log("Transferred team allocation to TeamVesting");

        return address(vesting);
    }

    function _deployGhostCore(
        DeployConfig memory cfg,
        address dataToken
    ) internal returns (address impl, address proxy) {
        console2.log("Phase 3: Deploying GhostCore...");

        GhostCore implementation = new GhostCore();
        console2.log("GhostCore impl:", address(implementation));

        bytes memory initData = abi.encodeCall(
            GhostCore.initialize, (dataToken, cfg.treasury, cfg.boostSigner, cfg.deployer)
        );

        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementation), initData);
        console2.log("GhostCore proxy:", address(proxyContract));

        return (address(implementation), address(proxyContract));
    }

    function _deployTraceScan(
        DeployConfig memory cfg,
        address ghostCore
    ) internal returns (address impl, address proxy) {
        console2.log("Phase 4: Deploying TraceScan...");

        TraceScan implementation = new TraceScan();
        console2.log("TraceScan impl:", address(implementation));

        bytes memory initData = abi.encodeCall(TraceScan.initialize, (ghostCore, cfg.deployer));

        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementation), initData);
        console2.log("TraceScan proxy:", address(proxyContract));

        return (address(implementation), address(proxyContract));
    }

    function _deployDeadPool(
        DeployConfig memory cfg,
        address dataToken
    ) internal returns (address impl, address proxy) {
        console2.log("Phase 5: Deploying DeadPool...");

        DeadPool implementation = new DeadPool();
        console2.log("DeadPool impl:", address(implementation));

        bytes memory initData = abi.encodeCall(DeadPool.initialize, (dataToken, cfg.deployer));

        ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementation), initData);
        console2.log("DeadPool proxy:", address(proxyContract));

        return (address(implementation), address(proxyContract));
    }

    function _deployRewardsDistributor(
        DeployConfig memory cfg,
        address dataToken,
        address ghostCore
    ) internal returns (address) {
        console2.log("Phase 6: Deploying RewardsDistributor...");

        RewardsDistributor distributor = new RewardsDistributor(dataToken, ghostCore, cfg.deployer);
        console2.log("RewardsDistributor deployed:", address(distributor));

        // Transfer rewards allocation
        DataToken(dataToken).transfer(address(distributor), REWARDS_ALLOCATION);
        console2.log("Transferred rewards allocation to RewardsDistributor");

        return address(distributor);
    }

    function _deployFeeRouter(
        DeployConfig memory cfg,
        address dataToken
    ) internal returns (address) {
        console2.log("Phase 7: Deploying FeeRouter...");

        FeeRouter router = new FeeRouter(
            dataToken, cfg.weth, cfg.swapRouter, cfg.treasury, cfg.tollAmount, cfg.deployer
        );
        console2.log("FeeRouter deployed:", address(router));

        return address(router);
    }

    function _configureRoles(
        DeployConfig memory,
        DeployedAddresses memory d
    ) internal {
        console2.log("Phase 8: Configuring roles...");

        GhostCore ghostCore = GhostCore(d.ghostCore);
        DeadPool deadPool = DeadPool(d.deadPool);

        // Grant SCANNER_ROLE to TraceScan
        ghostCore.grantRole(ghostCore.SCANNER_ROLE(), d.traceScan);
        console2.log("Granted SCANNER_ROLE to TraceScan");

        // Grant DISTRIBUTOR_ROLE to RewardsDistributor
        ghostCore.grantRole(ghostCore.DISTRIBUTOR_ROLE(), d.rewardsDistributor);
        console2.log("Granted DISTRIBUTOR_ROLE to RewardsDistributor");

        // Grant RESOLVER_ROLE to TraceScan
        deadPool.grantRole(deadPool.RESOLVER_ROLE(), d.traceScan);
        console2.log("Granted RESOLVER_ROLE to TraceScan");
    }

    function _setTaxExclusions(
        DeployedAddresses memory d
    ) internal {
        console2.log("Phase 9: Setting tax exclusions...");

        DataToken token = DataToken(d.dataToken);

        token.setTaxExclusion(d.ghostCore, true);
        token.setTaxExclusion(d.traceScan, true);
        token.setTaxExclusion(d.deadPool, true);
        token.setTaxExclusion(d.rewardsDistributor, true);
        token.setTaxExclusion(d.teamVesting, true);

        console2.log("Tax exclusions configured");
    }

    function _logDeployment(
        DeployedAddresses memory d,
        DeployConfig memory cfg
    ) internal pure {
        console2.log("");
        console2.log("=== DEPLOYMENT COMPLETE ===");
        console2.log("");
        console2.log("--- Layer 1: Immutable Core ---");
        console2.log("DataToken:", d.dataToken);
        console2.log("TeamVesting:", d.teamVesting);
        console2.log("");
        console2.log("--- Layer 2: Upgradeable Game Logic ---");
        console2.log("GhostCore (impl):", d.ghostCoreImpl);
        console2.log("GhostCore (proxy):", d.ghostCore);
        console2.log("TraceScan (impl):", d.traceScanImpl);
        console2.log("TraceScan (proxy):", d.traceScan);
        console2.log("DeadPool (impl):", d.deadPoolImpl);
        console2.log("DeadPool (proxy):", d.deadPool);
        console2.log("");
        console2.log("--- Layer 3: Peripheral ---");
        console2.log("RewardsDistributor:", d.rewardsDistributor);
        console2.log("FeeRouter:", d.feeRouter);
        console2.log("");
        console2.log("--- Configuration ---");
        console2.log("Treasury:", cfg.treasury);
        console2.log("Boost Signer:", cfg.boostSigner);
        console2.log("");
        console2.log("IMPORTANT: Transfer admin roles to Timelock + Multisig before mainnet!");
    }
}

/// @title DeployTestnet
/// @notice Simplified deployment for testnet with mock addresses
contract DeployTestnet is Script {
    function run() external {
        console2.log("=== GHOSTNET Testnet Deployment ===");
        console2.log("Note: All roles assigned to deployer for testing");
        console2.log("");

        // Run full deployment (env vars will default to deployer)
        DeployAll deployAll = new DeployAll();
        deployAll.run();
    }
}

/// @title UpgradeGhostCore
/// @notice Upgrade script for GhostCore
contract UpgradeGhostCore is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address ghostCoreProxy = vm.envAddress("GHOST_CORE_PROXY");

        console2.log("=== Upgrading GhostCore ===");
        console2.log("Proxy:", ghostCoreProxy);

        vm.startBroadcast(deployerPrivateKey);

        GhostCore newImpl = new GhostCore();
        console2.log("New implementation:", address(newImpl));

        GhostCore(ghostCoreProxy).upgradeToAndCall(address(newImpl), "");
        console2.log("Upgrade complete!");

        vm.stopBroadcast();
    }
}

/// @title UpgradeTraceScan
/// @notice Upgrade script for TraceScan
contract UpgradeTraceScan is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address traceScanProxy = vm.envAddress("TRACE_SCAN_PROXY");

        console2.log("=== Upgrading TraceScan ===");
        console2.log("Proxy:", traceScanProxy);

        vm.startBroadcast(deployerPrivateKey);

        TraceScan newImpl = new TraceScan();
        console2.log("New implementation:", address(newImpl));

        TraceScan(traceScanProxy).upgradeToAndCall(address(newImpl), "");
        console2.log("Upgrade complete!");

        vm.stopBroadcast();
    }
}

/// @title UpgradeDeadPool
/// @notice Upgrade script for DeadPool
contract UpgradeDeadPool is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deadPoolProxy = vm.envAddress("DEAD_POOL_PROXY");

        console2.log("=== Upgrading DeadPool ===");
        console2.log("Proxy:", deadPoolProxy);

        vm.startBroadcast(deployerPrivateKey);

        DeadPool newImpl = new DeadPool();
        console2.log("New implementation:", address(newImpl));

        DeadPool(deadPoolProxy).upgradeToAndCall(address(newImpl), "");
        console2.log("Upgrade complete!");

        vm.stopBroadcast();
    }
}
