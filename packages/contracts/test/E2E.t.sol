// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { DataToken } from "../src/token/DataToken.sol";
import { TeamVesting } from "../src/token/TeamVesting.sol";
import { GhostCore } from "../src/core/GhostCore.sol";
import { TraceScan } from "../src/core/TraceScan.sol";
import { DeadPool } from "../src/markets/DeadPool.sol";
import { RewardsDistributor } from "../src/periphery/RewardsDistributor.sol";
import { FeeRouter } from "../src/periphery/FeeRouter.sol";
import { IGhostCore } from "../src/core/interfaces/IGhostCore.sol";
import { ITraceScan } from "../src/core/interfaces/ITraceScan.sol";
import { IDeadPool } from "../src/markets/interfaces/IDeadPool.sol";

/// @title End-to-End Tests
/// @notice Comprehensive real-life scenario tests for the complete GHOSTNET ecosystem
/// @dev Tests user journeys from start to finish, covering all major use cases
contract E2ETest is Test {
    // ══════════════════════════════════════════════════════════════════════════════
    // CONTRACTS
    // ══════════════════════════════════════════════════════════════════════════════

    DataToken public token;
    TeamVesting public teamVesting;
    GhostCore public ghostCore;
    TraceScan public traceScan;
    DeadPool public deadPool;
    RewardsDistributor public distributor;
    FeeRouter public feeRouter;
    MockSwapRouter public swapRouter;

    // ══════════════════════════════════════════════════════════════════════════════
    // ADDRESSES
    // ══════════════════════════════════════════════════════════════════════════════

    address public treasury = makeAddr("treasury");
    address public owner = makeAddr("owner");
    address public operationsWallet = makeAddr("operationsWallet");
    address public weth = makeAddr("weth");

    // Boost signer with private key for signature generation
    uint256 public boostSignerPk;
    address public boostSigner;

    // Team members
    address public teamMember1 = makeAddr("teamMember1");
    address public teamMember2 = makeAddr("teamMember2");

    // Players (simulating real users)
    address public alice = makeAddr("alice"); // New player
    address public bob = makeAddr("bob"); // Experienced staker
    address public carol = makeAddr("carol"); // Whale
    address public dave = makeAddr("dave"); // Prediction market player
    address public eve = makeAddr("eve"); // High-risk player

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    uint256 constant TOTAL_SUPPLY = 100_000_000 * 1e18;
    uint256 constant USER_BALANCE = 5_000_000 * 1e18;
    uint256 constant EMISSIONS = 60_000_000 * 1e18;
    uint256 constant TEAM_ALLOCATION = 8_000_000 * 1e18;
    uint256 constant TOLL_AMOUNT = 0.001 ether;

    // ══════════════════════════════════════════════════════════════════════════════
    // SETUP
    // ══════════════════════════════════════════════════════════════════════════════

    function setUp() public {
        // Generate boost signer keypair
        (boostSigner, boostSignerPk) = makeAddrAndKey("boostSigner");

        // Deploy token with initial distribution
        address[] memory recipients = new address[](8);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = carol;
        recipients[3] = dave;
        recipients[4] = eve;
        recipients[5] = treasury;
        recipients[6] = address(this); // For emissions
        recipients[7] = address(this); // For team vesting (will transfer)

        uint256[] memory amounts = new uint256[](8);
        amounts[0] = USER_BALANCE;
        amounts[1] = USER_BALANCE;
        amounts[2] = USER_BALANCE * 2; // Carol is a whale
        amounts[3] = USER_BALANCE;
        amounts[4] = USER_BALANCE;
        amounts[5] = TOTAL_SUPPLY - (USER_BALANCE * 6) - EMISSIONS - TEAM_ALLOCATION;
        amounts[6] = EMISSIONS;
        amounts[7] = TEAM_ALLOCATION;

        token = new DataToken(treasury, owner, recipients, amounts);

        // Deploy TeamVesting
        address[] memory teamMembers = new address[](2);
        teamMembers[0] = teamMember1;
        teamMembers[1] = teamMember2;

        uint256[] memory teamAmounts = new uint256[](2);
        teamAmounts[0] = TEAM_ALLOCATION / 2;
        teamAmounts[1] = TEAM_ALLOCATION / 2;

        teamVesting = new TeamVesting(IERC20(address(token)), teamMembers, teamAmounts);
        token.transfer(address(teamVesting), TEAM_ALLOCATION);

        // Deploy GhostCore
        GhostCore ghostCoreImpl = new GhostCore();
        bytes memory ghostCoreInit =
            abi.encodeCall(GhostCore.initialize, (address(token), treasury, boostSigner, owner));
        ghostCore = GhostCore(address(new ERC1967Proxy(address(ghostCoreImpl), ghostCoreInit)));

        // Deploy TraceScan
        TraceScan traceScanImpl = new TraceScan();
        bytes memory traceScanInit =
            abi.encodeCall(TraceScan.initialize, (address(ghostCore), owner));
        traceScan = TraceScan(address(new ERC1967Proxy(address(traceScanImpl), traceScanInit)));

        // Deploy DeadPool
        DeadPool deadPoolImpl = new DeadPool();
        bytes memory deadPoolInit = abi.encodeCall(DeadPool.initialize, (address(token), owner));
        deadPool = DeadPool(address(new ERC1967Proxy(address(deadPoolImpl), deadPoolInit)));

        // Deploy RewardsDistributor
        distributor = new RewardsDistributor(address(token), address(ghostCore), owner);

        // Deploy mock swap router and FeeRouter
        swapRouter = new MockSwapRouter(address(token));
        feeRouter = new FeeRouter(
            address(token), weth, address(swapRouter), operationsWallet, TOLL_AMOUNT, owner
        );

        // Fund swap router for buybacks
        vm.prank(treasury);
        token.transfer(address(swapRouter), 1_000_000 * 1e18);

        // Setup roles and exclusions
        vm.startPrank(owner);
        token.setTaxExclusion(address(ghostCore), true);
        token.setTaxExclusion(address(traceScan), true);
        token.setTaxExclusion(address(deadPool), true);
        token.setTaxExclusion(address(distributor), true);
        token.setTaxExclusion(address(teamVesting), true);
        token.setTaxExclusion(address(feeRouter), true);
        token.setTaxExclusion(address(swapRouter), true);

        ghostCore.grantRole(ghostCore.SCANNER_ROLE(), address(traceScan));
        ghostCore.grantRole(ghostCore.DISTRIBUTOR_ROLE(), address(distributor));
        deadPool.grantRole(deadPool.RESOLVER_ROLE(), owner);
        feeRouter.setCollector(address(ghostCore), true);
        vm.stopPrank();

        // Fund distributor with emissions
        token.transfer(address(distributor), EMISSIONS);

        // Setup player approvals
        address[5] memory players = [alice, bob, carol, dave, eve];
        for (uint256 i = 0; i < players.length; i++) {
            vm.startPrank(players[i]);
            token.approve(address(ghostCore), type(uint256).max);
            token.approve(address(deadPool), type(uint256).max);
            vm.stopPrank();
            vm.deal(players[i], 100 ether);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 1: NEW PLAYER ONBOARDING
    // ══════════════════════════════════════════════════════════════════════════════

    function test_E2E_NewPlayerOnboarding() public {
        console.log("\n========================================");
        console.log("SCENARIO: New Player Onboarding Journey");
        console.log("========================================\n");

        // Alice is a new player who just acquired DATA tokens
        uint256 aliceInitialBalance = token.balanceOf(alice);
        console.log("1. Alice starts with:", aliceInitialBalance / 1e18, "DATA");

        // Step 1: Alice researches and decides to start at VAULT level (safest)
        console.log("\n2. Alice jacks into VAULT level with 1000 DATA...");
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.Position memory alicePos = ghostCore.getPosition(alice);
        assertEq(alicePos.amount, 1000 * 1e18);
        assertEq(uint8(alicePos.level), uint8(IGhostCore.Level.VAULT));
        assertTrue(alicePos.alive);
        console.log("   Position created - Amount:", alicePos.amount / 1e18, "DATA");
        console.log("   Ghost Streak:", alicePos.ghostStreak);

        // Step 2: Wait for emissions and check pending rewards
        console.log("\n3. Waiting 1 day for emissions to accrue...");
        vm.warp(block.timestamp + 1 days);
        distributor.distribute();

        uint256 pendingRewards = ghostCore.getPendingRewards(alice);
        console.log("   Pending rewards:", pendingRewards / 1e18, "DATA");
        assertGt(pendingRewards, 0, "Should have pending rewards");

        // Step 3: Survive first scan
        console.log("\n4. First scan approaching...");
        IGhostCore.LevelState memory vaultState = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(vaultState.nextScanTime);

        traceScan.executeScan(IGhostCore.Level.VAULT);
        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);

        bool aliceSurvives = !traceScan.isDead(scan.seed, alice, 500); // 5% death rate
        console.log("   Alice survives scan?", aliceSurvives);

        // Finalize scan
        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        // Step 4: If survived, check ghost streak and extract
        if (aliceSurvives) {
            alicePos = ghostCore.getPosition(alice);
            console.log("   Ghost streak after survival:", alicePos.ghostStreak);

            // Wait past lock period and extract
            console.log("\n5. Alice extracts after surviving...");
            vm.warp(block.timestamp + 5 hours);

            vm.prank(alice);
            (uint256 principal, uint256 rewards) = ghostCore.extract();

            console.log("   Principal returned:", principal / 1e18, "DATA");
            console.log("   Rewards earned:", rewards / 1e18, "DATA");
            console.log("   Total received:", (principal + rewards) / 1e18, "DATA");

            uint256 profit = token.balanceOf(alice) - aliceInitialBalance + 1000 * 1e18;
            console.log("   Net profit:", profit / 1e18, "DATA");
        }

        console.log("\n=== New Player Onboarding Complete ===\n");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 2: LONG-TERM STAKER JOURNEY
    // ══════════════════════════════════════════════════════════════════════════════

    function test_E2E_LongTermStakerJourney() public {
        console.log("\n========================================");
        console.log("SCENARIO: Long-Term Staker Journey");
        console.log("========================================\n");

        // Bob is an experienced staker aiming for high ghost streak
        console.log("1. Bob enters SUBNET level with larger stake...");
        vm.prank(bob);
        ghostCore.jackIn(5000 * 1e18, IGhostCore.Level.SUBNET);

        uint256 survivedScans = 0;
        uint256 totalRewardsClaimed = 0;

        // Simulate multiple scan cycles
        for (uint256 cycle = 1; cycle <= 5; cycle++) {
            console.log("\n--- Scan Cycle", cycle, "---");

            // Distribute emissions
            vm.warp(block.timestamp + 1 days);
            distributor.distribute();

            // Execute scan
            IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.SUBNET);
            vm.warp(state.nextScanTime);
            traceScan.executeScan(IGhostCore.Level.SUBNET);

            ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.SUBNET);
            bool survives = !traceScan.isDead(scan.seed, bob, 2500); // 25% death rate

            vm.warp(block.timestamp + 121 seconds);
            traceScan.finalizeScan(IGhostCore.Level.SUBNET);

            if (survives) {
                survivedScans++;
                IGhostCore.Position memory pos = ghostCore.getPosition(bob);
                console.log("   Survived! Ghost streak:", pos.ghostStreak);

                // Claim rewards periodically
                if (cycle % 2 == 0) {
                    uint256 pending = ghostCore.getPendingRewards(bob);
                    if (pending > 0) {
                        vm.prank(bob);
                        uint256 claimed = ghostCore.claimRewards();
                        totalRewardsClaimed += claimed;
                        console.log("   Claimed rewards:", claimed / 1e18, "DATA");
                    }
                }
            } else {
                console.log("   Bob died in scan", cycle);
                break;
            }
        }

        console.log("\n=== Summary ===");
        console.log("Scans survived:", survivedScans);
        console.log("Total rewards claimed:", totalRewardsClaimed / 1e18, "DATA");

        // If still alive, final extraction
        if (ghostCore.isAlive(bob)) {
            vm.warp(block.timestamp + 5 hours);
            vm.prank(bob);
            (uint256 principal, uint256 finalRewards) = ghostCore.extract();
            console.log("Final extraction - Principal:", principal / 1e18, "DATA");
            console.log("Final extraction - Rewards:", finalRewards / 1e18, "DATA");
        }

        console.log("\n=== Long-Term Staker Journey Complete ===\n");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 3: BOOST APPLICATION WITH SIGNATURE
    // ══════════════════════════════════════════════════════════════════════════════

    function test_E2E_BoostApplicationFlow() public {
        console.log("\n========================================");
        console.log("SCENARIO: Boost Application Flow");
        console.log("========================================\n");

        // Carol purchases a boost off-chain (e.g., from in-game shop)
        console.log("1. Carol enters DARKNET level (high risk, 35% death rate)...");
        vm.prank(carol);
        ghostCore.jackIn(10_000 * 1e18, IGhostCore.Level.DARKNET);

        uint16 baseDeathRate = ghostCore.getEffectiveDeathRate(carol);
        console.log("   Base death rate:", baseDeathRate, "bps");

        // Step 2: Apply death reduction boost (signed by backend)
        console.log("\n2. Carol applies death reduction boost...");

        IGhostCore.BoostType boostType = IGhostCore.BoostType.DEATH_REDUCTION;
        uint16 boostValue = 1500; // 15% reduction
        uint64 expiry = uint64(block.timestamp + 7 days);
        bytes32 nonce = keccak256(abi.encodePacked("carol-boost-1"));

        bytes memory signature = _signBoost(carol, boostType, boostValue, expiry, nonce);

        vm.prank(carol);
        ghostCore.applyBoost(boostType, boostValue, expiry, nonce, signature);

        uint16 effectiveDeathRate = ghostCore.getEffectiveDeathRate(carol);
        console.log("   Effective death rate after boost:", effectiveDeathRate, "bps");
        console.log("   Death rate reduced by:", baseDeathRate - effectiveDeathRate, "bps");

        assertLt(effectiveDeathRate, baseDeathRate, "Boost should reduce death rate");

        // Verify boost is active
        IGhostCore.Boost[] memory activeBoosts = ghostCore.getActiveBoosts(carol);
        assertEq(activeBoosts.length, 1);
        console.log("   Active boosts:", activeBoosts.length);

        // Step 3: Survive scan with boost advantage
        console.log("\n3. Facing scan with boost protection...");
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.DARKNET);
        vm.warp(state.nextScanTime);

        traceScan.executeScan(IGhostCore.Level.DARKNET);
        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.DARKNET);

        // Check survival with reduced death rate
        bool survives = !traceScan.isDead(scan.seed, carol, effectiveDeathRate);
        console.log("   Carol survives with boost?", survives);

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.DARKNET);

        console.log("\n=== Boost Application Flow Complete ===\n");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 4: SYSTEM RESET (JACKPOT) SCENARIO
    // ══════════════════════════════════════════════════════════════════════════════

    function test_E2E_SystemResetScenario() public {
        console.log("\n========================================");
        console.log("SCENARIO: System Reset (Jackpot)");
        console.log("========================================\n");

        // Multiple players stake
        console.log("1. Multiple players enter the system...");
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);
        vm.prank(bob);
        ghostCore.jackIn(2000 * 1e18, IGhostCore.Level.MAINFRAME);
        vm.prank(carol);
        ghostCore.jackIn(5000 * 1e18, IGhostCore.Level.SUBNET);

        uint256 tvl = ghostCore.getTotalValueLocked();
        console.log("   Total Value Locked:", tvl / 1e18, "DATA");

        IGhostCore.SystemReset memory resetInfo = ghostCore.getSystemReset();
        console.log("   Reset deadline:", resetInfo.deadline);
        console.log("   Last depositor:", resetInfo.lastDepositor);

        // Eve makes a deposit, becoming the last depositor
        console.log("\n2. Eve makes a last-minute deposit (becomes jackpot winner)...");
        vm.prank(eve);
        ghostCore.jackIn(500 * 1e18, IGhostCore.Level.VAULT);

        resetInfo = ghostCore.getSystemReset();
        assertEq(resetInfo.lastDepositor, eve, "Eve should be last depositor");
        console.log("   Last depositor is now:", resetInfo.lastDepositor);

        // Warp to after reset deadline
        console.log("\n3. Time passes... no new deposits...");
        vm.warp(resetInfo.deadline + 1);

        console.log("\n4. System reset is triggered!");
        uint256 eveBalanceBefore = token.balanceOf(eve);
        uint256 treasuryBalanceBefore = token.balanceOf(treasury);
        uint256 deadBalanceBefore = token.balanceOf(token.DEAD_ADDRESS());

        // Anyone can trigger the reset
        ghostCore.triggerSystemReset();

        uint256 eveJackpot = token.balanceOf(eve) - eveBalanceBefore;
        uint256 treasuryShare = token.balanceOf(treasury) - treasuryBalanceBefore;
        uint256 burned = token.balanceOf(token.DEAD_ADDRESS()) - deadBalanceBefore;

        // 25% penalty on TVL, split 50/30/20
        uint256 expectedPenalty = (tvl + 500 * 1e18) * 2500 / 10_000;
        console.log("   Total penalty pool:", expectedPenalty / 1e18, "DATA");
        console.log("   Eve's jackpot (50%):", eveJackpot / 1e18, "DATA");
        console.log("   Burned (30%):", burned / 1e18, "DATA");
        console.log("   Treasury (20%):", treasuryShare / 1e18, "DATA");

        assertGt(eveJackpot, 0, "Eve should receive jackpot");

        // Check new epoch
        resetInfo = ghostCore.getSystemReset();
        console.log("\n5. New epoch started:", resetInfo.epoch);
        console.log("   New deadline:", resetInfo.deadline);

        console.log("\n=== System Reset Scenario Complete ===\n");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 5: MULTI-PLAYER CASCADE DISTRIBUTION
    // ══════════════════════════════════════════════════════════════════════════════

    function test_E2E_MultiPlayerCascade() public {
        console.log("\n========================================");
        console.log("SCENARIO: Multi-Player Cascade");
        console.log("========================================\n");

        // Create positions at different levels
        console.log("1. Setting up multi-level positions...");

        // Level 1 (VAULT) - 2 players
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);
        vm.prank(bob);
        ghostCore.jackIn(2000 * 1e18, IGhostCore.Level.VAULT);

        // Level 4 (DARKNET) - 1 player who will likely die
        vm.prank(carol);
        ghostCore.jackIn(10_000 * 1e18, IGhostCore.Level.DARKNET);

        console.log("   Alice: 1000 DATA @ VAULT");
        console.log("   Bob: 2000 DATA @ VAULT");
        console.log("   Carol: 10000 DATA @ DARKNET");

        // Record initial rewards
        uint256 aliceRewardsBefore = ghostCore.getPendingRewards(alice);
        uint256 bobRewardsBefore = ghostCore.getPendingRewards(bob);

        // Execute DARKNET scan (higher death rate = 35%)
        console.log("\n2. Executing DARKNET scan (35% death rate)...");
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.DARKNET);
        vm.warp(state.nextScanTime);

        traceScan.executeScan(IGhostCore.Level.DARKNET);
        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.DARKNET);

        bool carolDies = traceScan.isDead(scan.seed, carol, 3500);
        console.log("   Carol dies?", carolDies);

        if (carolDies) {
            address[] memory dead = new address[](1);
            dead[0] = carol;
            traceScan.submitDeaths(IGhostCore.Level.DARKNET, dead);
        }

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.DARKNET);

        // Check cascade distribution
        if (carolDies) {
            console.log("\n3. Carol died - cascade distribution:");
            console.log("   Carol's stake:", 10_000, "DATA");
            console.log("   30% to DARKNET survivors: 0 (none)");
            console.log("   30% to upstream (VAULT): distributed to Alice & Bob");
            console.log("   30% burned");
            console.log("   10% to treasury");

            uint256 aliceRewardsAfter = ghostCore.getPendingRewards(alice);
            uint256 bobRewardsAfter = ghostCore.getPendingRewards(bob);

            uint256 aliceCascade = aliceRewardsAfter - aliceRewardsBefore;
            uint256 bobCascade = bobRewardsAfter - bobRewardsBefore;

            console.log("\n   Alice's cascade rewards:", aliceCascade / 1e18, "DATA");
            console.log("   Bob's cascade rewards:", bobCascade / 1e18, "DATA");

            // Bob should get more (2x stake)
            if (aliceCascade > 0 && bobCascade > 0) {
                assertGt(bobCascade, aliceCascade, "Bob should get more (higher stake)");
                console.log("   Bob receives ~2x Alice's cascade (proportional to stake)");
            }
        }

        console.log("\n=== Multi-Player Cascade Complete ===\n");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 6: EMERGENCY PROTOCOL
    // ══════════════════════════════════════════════════════════════════════════════

    function test_E2E_EmergencyProtocol() public {
        console.log("\n========================================");
        console.log("SCENARIO: Emergency Protocol");
        console.log("========================================\n");

        // Players have active positions
        console.log("1. Players have active positions...");
        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);
        vm.prank(bob);
        ghostCore.jackIn(2000 * 1e18, IGhostCore.Level.SUBNET);

        // Accrue some rewards
        vm.warp(block.timestamp + 1 days);
        distributor.distribute();

        uint256 alicePending = ghostCore.getPendingRewards(alice);
        console.log("   Alice pending rewards:", alicePending / 1e18, "DATA");

        // Emergency discovered - admin pauses
        console.log("\n2. Emergency detected! Admin pauses protocol...");
        vm.prank(owner);
        ghostCore.pause();
        assertTrue(ghostCore.paused(), "Protocol should be paused");
        console.log("   Protocol paused: true");

        // Normal operations fail
        console.log("\n3. Normal operations are blocked...");
        vm.prank(carol);
        vm.expectRevert();
        ghostCore.jackIn(500 * 1e18, IGhostCore.Level.VAULT);
        console.log("   jackIn: BLOCKED");

        vm.prank(alice);
        vm.expectRevert();
        ghostCore.extract();
        console.log("   extract: BLOCKED");

        // Emergency withdraw available
        console.log("\n4. Emergency withdrawal available...");
        uint256 aliceBalanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        ghostCore.emergencyWithdraw();

        uint256 aliceReceived = token.balanceOf(alice) - aliceBalanceBefore;
        console.log("   Alice emergency withdrew:", aliceReceived / 1e18, "DATA");
        console.log("   Note: No rewards in emergency withdrawal (principal only)");

        assertEq(aliceReceived, 1000 * 1e18, "Should receive principal only");

        // Admin fixes issue and unpauses
        console.log("\n5. Issue fixed - admin unpauses...");
        vm.prank(owner);
        ghostCore.unpause();
        assertFalse(ghostCore.paused(), "Protocol should be unpaused");
        console.log("   Protocol unpaused: true");

        // Normal operations resume
        console.log("\n6. Normal operations resume...");
        vm.prank(carol);
        ghostCore.jackIn(500 * 1e18, IGhostCore.Level.VAULT);
        console.log("   Carol jackIn: SUCCESS");

        console.log("\n=== Emergency Protocol Complete ===\n");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 7: TEAM VESTING LIFECYCLE
    // ══════════════════════════════════════════════════════════════════════════════

    function test_E2E_TeamVestingLifecycle() public {
        console.log("\n========================================");
        console.log("SCENARIO: Team Vesting Lifecycle");
        console.log("========================================\n");

        uint256 teamMember1Allocation = TEAM_ALLOCATION / 2;

        (uint256 total, uint256 vested, uint256 claimed, uint256 claimable) =
            teamVesting.getVestingInfo(teamMember1);

        console.log("1. Initial vesting state for Team Member 1:");
        console.log("   Total allocation:", total / 1e18, "DATA");
        console.log("   Vested:", vested / 1e18, "DATA");
        console.log("   Claimable:", claimable / 1e18, "DATA");

        // Before cliff - nothing claimable
        console.log("\n2. During cliff period (30 days)...");
        vm.warp(block.timestamp + 15 days);

        claimable = teamVesting.claimableAmount(teamMember1);
        console.log("   Claimable after 15 days:", claimable / 1e18, "DATA");
        assertEq(claimable, 0, "Nothing claimable during cliff");

        // After cliff
        console.log("\n3. After cliff period...");
        vm.warp(block.timestamp + 30 days); // Now at 45 days total

        (total, vested, claimed, claimable) = teamVesting.getVestingInfo(teamMember1);
        console.log("   Vested after 45 days:", vested / 1e18, "DATA");
        console.log("   Claimable:", claimable / 1e18, "DATA");

        assertGt(claimable, 0, "Should have claimable after cliff");

        // First claim
        console.log("\n4. Team member makes first claim...");
        uint256 balanceBefore = token.balanceOf(teamMember1);

        vm.prank(teamMember1);
        uint256 firstClaim = teamVesting.claim();

        console.log("   First claim amount:", firstClaim / 1e18, "DATA");

        // Halfway through vesting
        console.log("\n5. At 1 year (halfway through 24-month vesting)...");
        vm.warp(block.timestamp + 365 days - 45 days); // 1 year total

        (total, vested, claimed, claimable) = teamVesting.getVestingInfo(teamMember1);
        console.log("   Total vested:", vested / 1e18, "DATA");
        console.log("   Already claimed:", claimed / 1e18, "DATA");
        console.log("   Now claimable:", claimable / 1e18, "DATA");

        vm.prank(teamMember1);
        uint256 secondClaim = teamVesting.claim();
        console.log("   Second claim:", secondClaim / 1e18, "DATA");

        // Fully vested
        console.log("\n6. After full vesting period (24 months)...");
        vm.warp(block.timestamp + 730 days);

        (total, vested, claimed, claimable) = teamVesting.getVestingInfo(teamMember1);
        console.log("   Fully vested:", vested / 1e18, "DATA");
        console.log("   Remaining claimable:", claimable / 1e18, "DATA");

        vm.prank(teamMember1);
        uint256 finalClaim = teamVesting.claim();
        console.log("   Final claim:", finalClaim / 1e18, "DATA");

        uint256 totalReceived = token.balanceOf(teamMember1) - balanceBefore;
        console.log("\n7. Total received:", totalReceived / 1e18, "DATA");
        assertEq(totalReceived, teamMember1Allocation, "Should receive full allocation");

        console.log("\n=== Team Vesting Lifecycle Complete ===\n");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 8: FEE ROUTER & BUYBACK FLOW
    // ══════════════════════════════════════════════════════════════════════════════

    function test_E2E_FeeRouterBuybackFlow() public {
        console.log("\n========================================");
        console.log("SCENARIO: Fee Router & Buyback Flow");
        console.log("========================================\n");

        // Simulate multiple toll collections
        console.log("1. Collecting tolls from game actions...");

        // Give ghostCore ETH to pay tolls
        vm.deal(address(ghostCore), 1 ether);

        // Multiple players pay tolls (simulating game actions)
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(address(ghostCore));
            feeRouter.collectToll{ value: TOLL_AMOUNT }(bytes32("jackIn"));
        }

        uint256 collectedETH = feeRouter.pendingBuyback();
        console.log("   Total ETH collected:", collectedETH / 1e15, "finney");

        // Direct ETH deposit (e.g., donations or refunds)
        console.log("\n2. Additional direct ETH deposit...");
        vm.prank(alice);
        (bool success,) = address(feeRouter).call{ value: 1 ether }("");
        assertTrue(success);

        collectedETH = feeRouter.pendingBuyback();
        console.log("   New total:", collectedETH / 1e18, "ETH");

        // Preview split
        (uint256 buybackAmount, uint256 opsAmount) = feeRouter.previewSplit();
        console.log("\n3. Preview buyback split:");
        console.log("   For buyback (90%):", buybackAmount / 1e15, "finney");
        console.log("   For operations (10%):", opsAmount / 1e15, "finney");

        // Execute buyback
        console.log("\n4. Executing buyback...");
        uint256 deadBefore = token.balanceOf(token.DEAD_ADDRESS());
        uint256 opsBefore = operationsWallet.balance;

        feeRouter.executeBuyback(0);

        uint256 dataBurned = token.balanceOf(token.DEAD_ADDRESS()) - deadBefore;
        uint256 opsReceived = operationsWallet.balance - opsBefore;

        console.log("   DATA burned:", dataBurned / 1e18, "DATA");
        console.log("   Operations received:", opsReceived / 1e15, "finney");
        console.log("   Total burned (historical):", feeRouter.totalBurned() / 1e18, "DATA");

        assertEq(feeRouter.pendingBuyback(), 0, "All ETH should be processed");

        console.log("\n=== Fee Router & Buyback Flow Complete ===\n");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 9: TOKEN ECONOMICS END-TO-END
    // ══════════════════════════════════════════════════════════════════════════════

    function test_E2E_TokenEconomics() public {
        console.log("\n========================================");
        console.log("SCENARIO: Token Economics E2E");
        console.log("========================================\n");

        // Track burn from various sources
        uint256 initialBurn = token.totalBurned();
        console.log("1. Initial total burned:", initialBurn / 1e18, "DATA");

        // Source 1: Transfer tax (5% burn)
        console.log("\n2. Transfer tax burns (user-to-user transfers)...");
        uint256 burnBefore = token.totalBurned();

        // Non-excluded transfer triggers tax
        vm.prank(alice);
        token.transfer(dave, 10_000 * 1e18);

        uint256 taxBurn = token.totalBurned() - burnBefore;
        console.log("   Transfer: 10000 DATA");
        console.log("   Tax burned (5%):", taxBurn / 1e18, "DATA");

        // Source 2: DeadPool rake burn
        console.log("\n3. DeadPool rake burns...");
        burnBefore = token.totalBurned();

        // Create and resolve a prediction round
        uint64 deadline = uint64(block.timestamp + 1 hours);
        vm.prank(owner);
        uint256 roundId = deadPool.createRound(
            IDeadPool.RoundType.DEATH_COUNT, IGhostCore.Level.VAULT, 1, deadline
        );

        vm.prank(alice);
        deadPool.placeBet(roundId, true, 1000 * 1e18);
        vm.prank(bob);
        deadPool.placeBet(roundId, false, 1000 * 1e18);

        vm.warp(deadline + 1);
        vm.prank(owner);
        deadPool.resolveRound(roundId, true);

        uint256 rakeBurn = token.totalBurned() - burnBefore;
        console.log("   Total pot: 2000 DATA");
        console.log("   Rake burned (5%):", rakeBurn / 1e18, "DATA");

        // Source 3: Cascade burn
        console.log("\n4. Cascade burns (death distribution)...");
        burnBefore = token.totalBurned();

        // Create position that will die
        vm.prank(carol);
        ghostCore.jackIn(5000 * 1e18, IGhostCore.Level.DARKNET);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.DARKNET);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.DARKNET);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.DARKNET);
        bool carolDies = traceScan.isDead(scan.seed, carol, 3500);

        if (carolDies) {
            address[] memory dead = new address[](1);
            dead[0] = carol;
            traceScan.submitDeaths(IGhostCore.Level.DARKNET, dead);
        }

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.DARKNET);

        uint256 cascadeBurn = token.totalBurned() - burnBefore;
        if (carolDies) {
            console.log("   Carol's stake: 5000 DATA");
            console.log("   Cascade burned (30%):", cascadeBurn / 1e18, "DATA");
        }

        // Summary
        console.log("\n5. Total deflationary impact:");
        uint256 totalBurned = token.totalBurned();
        console.log("   Total tokens burned:", totalBurned / 1e18, "DATA");
        console.log("   Percentage of supply:", (totalBurned * 100) / TOTAL_SUPPLY, "%");

        console.log("\n=== Token Economics E2E Complete ===\n");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SCENARIO 10: COMPLETE GAME WEEK SIMULATION
    // ══════════════════════════════════════════════════════════════════════════════

    function test_E2E_CompleteGameWeek() public {
        console.log("\n========================================");
        console.log("SCENARIO: Complete Game Week Simulation");
        console.log("========================================\n");

        // Day 1: Players enter at various levels
        console.log("=== DAY 1: Players Enter ===");

        vm.prank(alice);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.VAULT);
        console.log("Alice -> VAULT (1000 DATA)");

        vm.prank(bob);
        ghostCore.jackIn(3000 * 1e18, IGhostCore.Level.SUBNET);
        console.log("Bob -> SUBNET (3000 DATA)");

        vm.prank(carol);
        ghostCore.jackIn(8000 * 1e18, IGhostCore.Level.DARKNET);
        console.log("Carol -> DARKNET (8000 DATA)");

        uint256 initialTVL = ghostCore.getTotalValueLocked();
        console.log("Initial TVL:", initialTVL / 1e18, "DATA");

        // Track metrics
        uint256 totalDeaths = 0;
        uint256 totalCascaded = 0;

        // Simulate 7 days
        for (uint256 day = 2; day <= 7; day++) {
            console.log("\n=== DAY", day, "===");

            // Distribute daily emissions
            vm.warp(block.timestamp + 1 days);
            distributor.distribute();
            console.log("Emissions distributed");

            // Execute scans for each level that's due
            IGhostCore.Level[3] memory levels =
                [IGhostCore.Level.VAULT, IGhostCore.Level.SUBNET, IGhostCore.Level.DARKNET];

            for (uint256 i = 0; i < levels.length; i++) {
                IGhostCore.LevelState memory state = ghostCore.getLevelState(levels[i]);

                if (block.timestamp >= state.nextScanTime && state.aliveCount > 0) {
                    traceScan.executeScan(levels[i]);
                    ITraceScan.Scan memory scan = traceScan.getCurrentScan(levels[i]);

                    // Check deaths
                    uint16 deathRate = ghostCore.getLevelConfig(levels[i]).baseDeathRateBps;
                    address[3] memory levelPlayers = [alice, bob, carol];

                    address[] memory deadPlayers = new address[](3);
                    uint256 deadCount = 0;

                    for (uint256 j = 0; j < 3; j++) {
                        if (ghostCore.isAlive(levelPlayers[j])) {
                            IGhostCore.Position memory pos = ghostCore.getPosition(levelPlayers[j]);
                            if (pos.level == levels[i]) {
                                if (traceScan.isDead(scan.seed, levelPlayers[j], deathRate)) {
                                    deadPlayers[deadCount++] = levelPlayers[j];
                                }
                            }
                        }
                    }

                    if (deadCount > 0) {
                        assembly { mstore(deadPlayers, deadCount) }
                        traceScan.submitDeaths(levels[i], deadPlayers);
                        totalDeaths += deadCount;
                    }

                    vm.warp(block.timestamp + 121 seconds);
                    traceScan.finalizeScan(levels[i]);

                    scan = traceScan.getCurrentScan(levels[i]);
                    if (scan.totalDead > 0) {
                        totalCascaded += scan.totalDead;
                        console.log("  Level", uint8(levels[i]), "- Deaths:", scan.deathCount);
                        console.log("    Cascaded:", scan.totalDead / 1e18, "DATA");
                    }
                }
            }
        }

        // End of week summary
        console.log("\n=== WEEK SUMMARY ===");
        console.log("Total deaths:", totalDeaths);
        console.log("Total cascaded:", totalCascaded / 1e18, "DATA");
        console.log("Final TVL:", ghostCore.getTotalValueLocked() / 1e18, "DATA");

        // Survivors extract
        console.log("\nSurvivors extract:");
        address[3] memory players = [alice, bob, carol];
        for (uint256 i = 0; i < 3; i++) {
            if (ghostCore.isAlive(players[i])) {
                vm.warp(block.timestamp + 5 hours);
                vm.prank(players[i]);
                (uint256 principal, uint256 rewards) = ghostCore.extract();
                console.log(
                    "  Player extracted - Principal:", principal / 1e18, "Rewards:", rewards / 1e18
                );
            }
        }

        console.log("\n=== Complete Game Week Simulation Done ===\n");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    function _signBoost(
        address user,
        IGhostCore.BoostType boostType,
        uint16 valueBps,
        uint64 expiry,
        bytes32 nonce
    ) internal view returns (bytes memory) {
        bytes32 BOOST_TYPEHASH = keccak256(
            "Boost(address user,uint8 boostType,uint16 valueBps,uint64 expiry,bytes32 nonce)"
        );

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("GHOSTNET"),
                keccak256("1"),
                block.chainid,
                address(ghostCore)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(BOOST_TYPEHASH, user, uint8(boostType), valueBps, expiry, nonce)
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(boostSignerPk, digest);
        return abi.encodePacked(r, s, v);
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MOCK CONTRACTS
// ══════════════════════════════════════════════════════════════════════════════

contract MockSwapRouter {
    IERC20 public immutable dataToken;
    uint256 public constant RATE = 1000; // 1000 DATA per ETH

    constructor(
        address _dataToken
    ) {
        dataToken = IERC20(_dataToken);
    }

    function swapExactETHForTokens(
        uint256,
        address[] calldata,
        address to,
        uint256
    ) external payable returns (uint256[] memory amounts) {
        uint256 dataOut = msg.value * RATE;
        dataToken.transfer(to, dataOut);

        amounts = new uint256[](2);
        amounts[0] = msg.value;
        amounts[1] = dataOut;
    }

    receive() external payable { }
}
