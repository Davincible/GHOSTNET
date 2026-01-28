// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Script, console2 } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { GhostPresale } from "../src/presale/GhostPresale.sol";
import { PresaleClaim } from "../src/presale/PresaleClaim.sol";
import { IGhostPresale } from "../src/presale/interfaces/IGhostPresale.sol";

/// @title DeployPresaleConfig
/// @notice Configuration for presale deployment — avoids stack-too-deep
struct DeployPresaleConfig {
    address deployer;
    GhostPresale.PricingMode pricingMode;
    // Tranche params (used when pricingMode == TRANCHE)
    uint256 tranche1Supply;
    uint256 tranche1Price;
    uint256 tranche2Supply;
    uint256 tranche2Price;
    uint256 tranche3Supply;
    uint256 tranche3Price;
    // Curve params (used when pricingMode == BONDING_CURVE)
    uint256 curveStartPrice;
    uint256 curveEndPrice;
    uint256 curveTotalSupply;
    // General config
    uint256 minContribution;
    uint256 maxContribution;
    uint256 maxPerWallet;
    bool allowMultipleContributions;
    uint256 startTime;
    uint256 endTime;
    uint256 emergencyDeadline;
    // Claim contract
    address dataToken;
    uint256 claimDeadline;
}

/// @title DeployPresale
/// @notice Deploys GhostPresale + PresaleClaim with full configuration
/// @dev Follows the TGE Deployment Checklist from docs/design/presale-system.md §7
///
///      Deployment steps:
///      1. Deploy GhostPresale (with pricing mode)
///      2. Configure pricing (tranches or curve)
///      3. Configure limits and timing
///      4. Deploy PresaleClaim (with presale address + data token)
///      5. Log all addresses for frontend config
///
///      The presale starts in PENDING state. The owner must call `open()` separately
///      to begin accepting contributions. This is intentional — allows verification
///      before going live.
///
///      Environment Variables:
///      - PRIVATE_KEY: Deployer/owner private key
///      - PRICING_MODE: "tranche" or "curve" (default: "tranche")
///      - DATA_TOKEN: $DATA token address (required for PresaleClaim, optional otherwise)
///      - MIN_CONTRIBUTION: Min ETH per tx in wei (default: 0.01 ether)
///      - MAX_PER_WALLET: Max ETH per wallet in wei (default: 0 = unlimited)
///      - START_TIME: Unix timestamp for presale start (default: 0 = immediate on open())
///      - END_TIME: Unix timestamp for presale end (default: 0 = no deadline)
///      - EMERGENCY_DEADLINE: Seconds after open() for dead-man's switch (default: 90 days)
///      - CLAIM_DEADLINE: Unix timestamp for claim expiry (default: 180 days from now)
///
///      Usage (MegaETH testnet):
///      forge script script/DeployPresale.s.sol:DeployPresale \
///        --rpc-url https://carrot.megaeth.com/rpc --broadcast \
///        --skip-simulation --gas-limit 10000000 --legacy
///
///      Usage (local anvil):
///      forge script script/DeployPresale.s.sol:DeployPresale \
///        --rpc-url http://localhost:8545 --broadcast
contract DeployPresale is Script {
    // Default presale supply: 15M $DATA (15% of 100M total)
    uint256 constant PRESALE_SUPPLY = 15_000_000 * 1e18;

    // Default tranche configuration (equal 5M splits, ascending price)
    uint256 constant TRANCHE_SUPPLY = 5_000_000 * 1e18;
    uint256 constant TRANCHE_1_PRICE = 0.000003 ether; // per 1e18 $DATA — ~$0.003
    uint256 constant TRANCHE_2_PRICE = 0.000005 ether; // per 1e18 $DATA — ~$0.005
    uint256 constant TRANCHE_3_PRICE = 0.000008 ether; // per 1e18 $DATA — ~$0.008

    // Default curve configuration
    uint256 constant CURVE_START_PRICE = 0.000002 ether; // per 1e18 $DATA — ~$0.002
    uint256 constant CURVE_END_PRICE = 0.000010 ether; // per 1e18 $DATA — ~$0.010

    // Default timing
    uint256 constant DEFAULT_MIN_CONTRIBUTION = 0.01 ether;
    uint256 constant DEFAULT_EMERGENCY_DEADLINE = 90 days;
    uint256 constant DEFAULT_CLAIM_DEADLINE_OFFSET = 180 days;

    function run()
        external
        returns (address presaleAddr, address claimAddr)
    {
        DeployPresaleConfig memory cfg = _loadConfig();

        console2.log("=== GHOSTNET Presale Deployment ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", cfg.deployer);
        console2.log(
            "Pricing mode:",
            cfg.pricingMode == GhostPresale.PricingMode.TRANCHE
                ? "TRANCHE"
                : "BONDING_CURVE"
        );
        console2.log("");

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Step 1: Deploy GhostPresale
        GhostPresale presale = new GhostPresale(cfg.pricingMode, cfg.deployer);
        presaleAddr = address(presale);
        console2.log("GhostPresale deployed:", presaleAddr);

        // Step 2: Configure pricing
        if (cfg.pricingMode == GhostPresale.PricingMode.TRANCHE) {
            _configureTranches(presale, cfg);
        } else {
            _configureCurve(presale, cfg);
        }

        // Step 3: Configure limits and timing
        _configurePresale(presale, cfg);

        // Step 4: Deploy PresaleClaim (only if DATA_TOKEN is provided)
        if (cfg.dataToken != address(0)) {
            PresaleClaim claim = new PresaleClaim(
                IERC20(cfg.dataToken),
                IGhostPresale(presaleAddr),
                cfg.claimDeadline,
                cfg.deployer
            );
            claimAddr = address(claim);
            console2.log("PresaleClaim deployed:", claimAddr);
        } else {
            console2.log("PresaleClaim SKIPPED - no DATA_TOKEN provided");
            console2.log("Deploy PresaleClaim separately after DataToken exists");
        }

        vm.stopBroadcast();

        _logDeployment(presaleAddr, claimAddr, cfg);
    }

    function _loadConfig()
        internal
        view
        returns (DeployPresaleConfig memory cfg)
    {
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));

        // Pricing mode
        string memory modeStr = vm.envOr("PRICING_MODE", string("tranche"));
        GhostPresale.PricingMode mode;
        if (_strEq(modeStr, "curve") || _strEq(modeStr, "bonding_curve")) {
            mode = GhostPresale.PricingMode.BONDING_CURVE;
        } else {
            mode = GhostPresale.PricingMode.TRANCHE;
        }

        cfg = DeployPresaleConfig({
            deployer: deployer,
            pricingMode: mode,
            // Tranche defaults
            tranche1Supply: vm.envOr("TRANCHE_1_SUPPLY", TRANCHE_SUPPLY),
            tranche1Price: vm.envOr("TRANCHE_1_PRICE", TRANCHE_1_PRICE),
            tranche2Supply: vm.envOr("TRANCHE_2_SUPPLY", TRANCHE_SUPPLY),
            tranche2Price: vm.envOr("TRANCHE_2_PRICE", TRANCHE_2_PRICE),
            tranche3Supply: vm.envOr("TRANCHE_3_SUPPLY", TRANCHE_SUPPLY),
            tranche3Price: vm.envOr("TRANCHE_3_PRICE", TRANCHE_3_PRICE),
            // Curve defaults
            curveStartPrice: vm.envOr("CURVE_START_PRICE", CURVE_START_PRICE),
            curveEndPrice: vm.envOr("CURVE_END_PRICE", CURVE_END_PRICE),
            curveTotalSupply: vm.envOr("CURVE_TOTAL_SUPPLY", PRESALE_SUPPLY),
            // General config
            minContribution: vm.envOr("MIN_CONTRIBUTION", DEFAULT_MIN_CONTRIBUTION),
            maxContribution: vm.envOr("MAX_CONTRIBUTION", uint256(0)),
            maxPerWallet: vm.envOr("MAX_PER_WALLET", uint256(0)),
            allowMultipleContributions: vm.envOr("ALLOW_MULTIPLE", true),
            startTime: vm.envOr("START_TIME", uint256(0)),
            endTime: vm.envOr("END_TIME", uint256(0)),
            emergencyDeadline: vm.envOr("EMERGENCY_DEADLINE", DEFAULT_EMERGENCY_DEADLINE),
            // Claim
            dataToken: vm.envOr("DATA_TOKEN", address(0)),
            claimDeadline: vm.envOr("CLAIM_DEADLINE", block.timestamp + DEFAULT_CLAIM_DEADLINE_OFFSET)
        });
    }

    function _configureTranches(
        GhostPresale presale,
        DeployPresaleConfig memory cfg
    ) internal {
        console2.log("Configuring 3 tranches...");

        presale.addTranche(cfg.tranche1Supply, cfg.tranche1Price);
        presale.addTranche(cfg.tranche2Supply, cfg.tranche2Price);
        presale.addTranche(cfg.tranche3Supply, cfg.tranche3Price);

        console2.log("  Tranche 1: supply", cfg.tranche1Supply / 1e18, "$DATA @ price", cfg.tranche1Price);
        console2.log("  Tranche 2: supply", cfg.tranche2Supply / 1e18, "$DATA @ price", cfg.tranche2Price);
        console2.log("  Tranche 3: supply", cfg.tranche3Supply / 1e18, "$DATA @ price", cfg.tranche3Price);
    }

    function _configureCurve(
        GhostPresale presale,
        DeployPresaleConfig memory cfg
    ) internal {
        console2.log("Configuring bonding curve...");

        presale.setCurve(cfg.curveStartPrice, cfg.curveEndPrice, cfg.curveTotalSupply);

        console2.log("  Start price:", cfg.curveStartPrice);
        console2.log("  End price:", cfg.curveEndPrice);
        console2.log("  Total supply:", cfg.curveTotalSupply / 1e18, "$DATA");
    }

    function _configurePresale(
        GhostPresale presale,
        DeployPresaleConfig memory cfg
    ) internal {
        console2.log("Configuring presale limits...");

        presale.setConfig(
            GhostPresale.PresaleConfig({
                minContribution: cfg.minContribution,
                maxContribution: cfg.maxContribution,
                maxPerWallet: cfg.maxPerWallet,
                allowMultipleContributions: cfg.allowMultipleContributions,
                startTime: cfg.startTime,
                endTime: cfg.endTime,
                emergencyDeadline: cfg.emergencyDeadline
            })
        );

        console2.log("  Min contribution:", cfg.minContribution);
        console2.log("  Max contribution:", cfg.maxContribution == 0 ? "unlimited" : "set");
        console2.log("  Max per wallet:", cfg.maxPerWallet == 0 ? "unlimited" : "set");
        console2.log("  Multiple contributions:", cfg.allowMultipleContributions ? "yes" : "no");
    }

    function _logDeployment(
        address presaleAddr,
        address claimAddr,
        DeployPresaleConfig memory cfg
    ) internal pure {
        console2.log("");
        console2.log("=== PRESALE DEPLOYMENT COMPLETE ===");
        console2.log("");
        console2.log("GhostPresale:", presaleAddr);
        if (claimAddr != address(0)) {
            console2.log("PresaleClaim:", claimAddr);
        }
        console2.log("");
        console2.log("--- NEXT STEPS ---");
        console2.log("1. Verify contracts on block explorer");
        console2.log("2. Update frontend addresses in apps/web/src/lib/web3/abis.ts");
        console2.log("3. Call presale.open() when ready to start");
        if (claimAddr != address(0)) {
            console2.log("4. Transfer", PRESALE_SUPPLY / 1e18, "$DATA to PresaleClaim before enabling claims");
            console2.log("5. Call claim.enableClaiming() after TGE");
        } else {
            console2.log("4. Deploy PresaleClaim after DataToken is deployed");
        }
        console2.log("");
        if (cfg.pricingMode == GhostPresale.PricingMode.TRANCHE) {
            console2.log("--- PRICING: TRANCHE ---");
            console2.log("Total supply:", (cfg.tranche1Supply + cfg.tranche2Supply + cfg.tranche3Supply) / 1e18, "$DATA");
        } else {
            console2.log("--- PRICING: BONDING CURVE ---");
            console2.log("Total supply:", cfg.curveTotalSupply / 1e18, "$DATA");
        }
        console2.log("");
        console2.log("IMPORTANT: Presale is in PENDING state. Call open() to start!");
    }

    /// @dev Simple string equality check
    function _strEq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}

/// @title DeployPresaleClaim
/// @notice Standalone script to deploy PresaleClaim after DataToken exists
/// @dev Use when presale was deployed before DataToken (e.g., presale starts before TGE)
///
///      Environment Variables:
///      - PRIVATE_KEY: Deployer/owner private key
///      - DATA_TOKEN: $DATA token address (required)
///      - GHOST_PRESALE: GhostPresale contract address (required)
///      - CLAIM_DEADLINE: Unix timestamp (default: 180 days from now)
///
///      Usage:
///      forge script script/DeployPresale.s.sol:DeployPresaleClaim \
///        --rpc-url https://carrot.megaeth.com/rpc --broadcast \
///        --skip-simulation --gas-limit 10000000 --legacy
contract DeployPresaleClaim is Script {
    function run() external returns (address claimAddr) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address dataToken = vm.envAddress("DATA_TOKEN");
        address presale = vm.envAddress("GHOST_PRESALE");
        uint256 claimDeadline = vm.envOr("CLAIM_DEADLINE", block.timestamp + 180 days);

        console2.log("=== Deploy PresaleClaim ===");
        console2.log("DataToken:", dataToken);
        console2.log("GhostPresale:", presale);
        console2.log("Claim deadline:", claimDeadline);

        vm.startBroadcast(deployerKey);

        PresaleClaim claim = new PresaleClaim(
            IERC20(dataToken),
            IGhostPresale(presale),
            claimDeadline,
            deployer
        );
        claimAddr = address(claim);

        vm.stopBroadcast();

        console2.log("PresaleClaim deployed:", claimAddr);
        console2.log("");
        console2.log("NEXT: Transfer presale $DATA allocation to", claimAddr);
        console2.log("THEN: Call claim.enableClaiming() when ready");
    }
}
