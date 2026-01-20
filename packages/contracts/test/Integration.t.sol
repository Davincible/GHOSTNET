// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { DataToken } from "../src/token/DataToken.sol";
import { GhostCore } from "../src/core/GhostCore.sol";
import { TraceScan } from "../src/core/TraceScan.sol";
import { DeadPool } from "../src/markets/DeadPool.sol";
import { RewardsDistributor } from "../src/periphery/RewardsDistributor.sol";
import { IGhostCore } from "../src/core/interfaces/IGhostCore.sol";
import { ITraceScan } from "../src/core/interfaces/ITraceScan.sol";
import { IDeadPool } from "../src/markets/interfaces/IDeadPool.sol";

/// @title Integration Tests
/// @notice End-to-end tests for the complete GHOSTNET game loop
contract IntegrationTest is Test {
    DataToken public token;
    GhostCore public ghostCore;
    TraceScan public traceScan;
    DeadPool public deadPool;
    RewardsDistributor public distributor;

    address public treasury = makeAddr("treasury");
    address public owner = makeAddr("owner");
    address public boostSigner = makeAddr("boostSigner");

    // Players
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");
    address public dave = makeAddr("dave");
    address public eve = makeAddr("eve");

    uint256 constant TOTAL_SUPPLY = 100_000_000 * 1e18;
    uint256 constant USER_BALANCE = 5_000_000 * 1e18;
    uint256 constant EMISSIONS = 60_000_000 * 1e18;

    function setUp() public {
        // Deploy token with initial distribution
        address[] memory recipients = new address[](7);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = carol;
        recipients[3] = dave;
        recipients[4] = eve;
        recipients[5] = treasury;
        recipients[6] = address(this); // For emissions

        uint256[] memory amounts = new uint256[](7);
        amounts[0] = USER_BALANCE;
        amounts[1] = USER_BALANCE;
        amounts[2] = USER_BALANCE;
        amounts[3] = USER_BALANCE;
        amounts[4] = USER_BALANCE;
        amounts[5] = TOTAL_SUPPLY - (USER_BALANCE * 5) - EMISSIONS;
        amounts[6] = EMISSIONS;

        token = new DataToken(treasury, owner, recipients, amounts);

        // Deploy GhostCore
        GhostCore ghostCoreImpl = new GhostCore();
        bytes memory ghostCoreInit = abi.encodeCall(
            GhostCore.initialize, (address(token), treasury, boostSigner, owner)
        );
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

        // Setup roles and exclusions
        vm.startPrank(owner);
        token.setTaxExclusion(address(ghostCore), true);
        token.setTaxExclusion(address(traceScan), true);
        token.setTaxExclusion(address(deadPool), true);
        token.setTaxExclusion(address(distributor), true);

        ghostCore.grantRole(ghostCore.SCANNER_ROLE(), address(traceScan));
        ghostCore.grantRole(ghostCore.DISTRIBUTOR_ROLE(), address(distributor));
        deadPool.grantRole(deadPool.RESOLVER_ROLE(), owner);
        vm.stopPrank();

        // Fund distributor
        token.transfer(address(distributor), EMISSIONS);

        // Approve tokens for all players
        address[5] memory players = [alice, bob, carol, dave, eve];
        for (uint256 i = 0; i < players.length; i++) {
            vm.startPrank(players[i]);
            token.approve(address(ghostCore), type(uint256).max);
            token.approve(address(deadPool), type(uint256).max);
            vm.stopPrank();
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FULL GAME LOOP TEST
    // ══════════════════════════════════════════════════════════════════════════════

    function test_FullGameLoop() public {
        // ─── PHASE 1: Players Jack In ────────────────────────────────────────────
        console.log("=== Phase 1: Players Jack In ===");

        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(bob);
        ghostCore.jackIn(200 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(carol);
        ghostCore.jackIn(300 * 1e18, IGhostCore.Level.SUBNET);

        vm.prank(dave);
        ghostCore.jackIn(500 * 1e18, IGhostCore.Level.DARKNET);

        vm.prank(eve);
        ghostCore.jackIn(1000 * 1e18, IGhostCore.Level.BLACK_ICE);

        // Verify TVL
        uint256 tvl = ghostCore.getTotalValueLocked();
        assertEq(tvl, 2100 * 1e18);
        console.log("Total Value Locked:", tvl / 1e18, "DATA");

        // ─── PHASE 2: Distribute Emissions ──────────────────────────────────────
        console.log("\n=== Phase 2: Distribute Emissions ===");

        vm.warp(block.timestamp + 1 days);
        distributor.distribute();

        // Check pending rewards
        uint256 aliceRewards = ghostCore.getPendingRewards(alice);
        console.log("Alice pending rewards:", aliceRewards / 1e18, "DATA");
        assertGt(aliceRewards, 0);

        // ─── PHASE 3: Execute Scan (VAULT) ──────────────────────────────────────
        console.log("\n=== Phase 3: Execute VAULT Scan ===");

        IGhostCore.LevelState memory vaultState = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(vaultState.nextScanTime);

        traceScan.executeScan(IGhostCore.Level.VAULT);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        console.log("Scan seed generated:", scan.seed);

        // Check who dies
        bool aliceDies = traceScan.isDead(scan.seed, alice, 500);
        bool bobDies = traceScan.isDead(scan.seed, bob, 500);
        console.log("Alice dies?", aliceDies);
        console.log("Bob dies?", bobDies);

        // Submit deaths
        address[] memory deadUsers = new address[](2);
        uint256 deathCount;
        if (aliceDies) deadUsers[deathCount++] = alice;
        if (bobDies) deadUsers[deathCount++] = bob;

        if (deathCount > 0) {
            assembly {
                mstore(deadUsers, deathCount)
            }
            traceScan.submitDeaths(IGhostCore.Level.VAULT, deadUsers);
            console.log("Deaths submitted:", deathCount);
        }

        // ─── PHASE 4: Finalize Scan & Distribute Cascade ────────────────────────
        console.log("\n=== Phase 4: Finalize Scan ===");

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        ITraceScan.Scan memory finalScan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        console.log("Total deaths:", finalScan.deathCount);
        console.log("Total dead capital:", finalScan.totalDead / 1e18, "DATA");

        // Check cascade distribution
        if (finalScan.totalDead > 0) {
            // Survivors should have received rewards
            if (!aliceDies) {
                uint256 aliceNewRewards = ghostCore.getPendingRewards(alice);
                console.log("Alice rewards after cascade:", aliceNewRewards / 1e18, "DATA");
            }
            if (!bobDies) {
                uint256 bobNewRewards = ghostCore.getPendingRewards(bob);
                console.log("Bob rewards after cascade:", bobNewRewards / 1e18, "DATA");
            }
        }

        // ─── PHASE 5: Survivor Extracts ─────────────────────────────────────────
        console.log("\n=== Phase 5: Survivor Extracts ===");

        // Warp past lock period
        vm.warp(block.timestamp + 5 hours);

        if (!aliceDies && ghostCore.isAlive(alice)) {
            uint256 aliceBalanceBefore = token.balanceOf(alice);

            vm.prank(alice);
            (uint256 amount, uint256 rewards) = ghostCore.extract();

            console.log("Alice extracted principal:", amount / 1e18, "DATA");
            console.log("Alice extracted rewards:", rewards / 1e18, "DATA");

            uint256 aliceBalanceAfter = token.balanceOf(alice);
            assertEq(aliceBalanceAfter - aliceBalanceBefore, amount + rewards);
        }

        // ─── PHASE 6: Dead Position Cannot Extract ──────────────────────────────
        console.log("\n=== Phase 6: Dead Position Cannot Extract ===");

        if (aliceDies) {
            vm.prank(alice);
            vm.expectRevert(IGhostCore.PositionDead.selector);
            ghostCore.extract();
            console.log("Alice (dead) correctly cannot extract");
        }

        console.log("\n=== Full Game Loop Complete ===");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // PREDICTION MARKET INTEGRATION
    // ══════════════════════════════════════════════════════════════════════════════

    function test_PredictionMarketFlow() public {
        console.log("=== Prediction Market Flow ===");

        // Setup: Create positions
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);
        vm.prank(bob);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Create prediction round
        uint64 deadline = uint64(block.timestamp + 1 hours);
        vm.prank(owner);
        uint256 roundId = deadPool.createRound(
            IDeadPool.RoundType.DEATH_COUNT, IGhostCore.Level.VAULT, 1, deadline // Over/under 1 death
        );

        // Players place bets
        vm.prank(carol);
        deadPool.placeBet(roundId, true, 100 * 1e18); // OVER (predicting >= 2 deaths)

        vm.prank(dave);
        deadPool.placeBet(roundId, false, 100 * 1e18); // UNDER (predicting < 2 deaths)

        console.log("Bets placed - Over: 100 DATA, Under: 100 DATA");

        // Execute scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        // Get death count
        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        bool aliceDies = traceScan.isDead(scan.seed, alice, 500);
        bool bobDies = traceScan.isDead(scan.seed, bob, 500);

        // Submit deaths
        address[] memory dead = new address[](2);
        uint256 count;
        if (aliceDies) dead[count++] = alice;
        if (bobDies) dead[count++] = bob;

        if (count > 0) {
            assembly {
                mstore(dead, count)
            }
            traceScan.submitDeaths(IGhostCore.Level.VAULT, dead);
        }

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        uint256 deaths = traceScan.getCurrentScan(IGhostCore.Level.VAULT).deathCount;
        bool overWins = deaths > 1;
        console.log("Deaths:", deaths);
        console.log("OVER wins?", overWins);

        // Resolve round
        vm.warp(deadline + 1);
        vm.prank(owner);
        deadPool.resolveRound(roundId, overWins);

        // Winner claims
        address winner = overWins ? carol : dave;
        uint256 balanceBefore = token.balanceOf(winner);

        vm.prank(winner);
        uint256 winnings = deadPool.claimWinnings(roundId);

        console.log("Winner:", winner == carol ? "Carol (OVER)" : "Dave (UNDER)");
        console.log("Winnings:", winnings / 1e18, "DATA");

        // 5% rake was burned
        assertEq(winnings, 190 * 1e18);

        console.log("\n=== Prediction Market Flow Complete ===");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // MULTI-LEVEL SCAN TEST
    // ══════════════════════════════════════════════════════════════════════════════

    function test_MultiLevelScans() public {
        console.log("=== Multi-Level Scans ===");

        // Create positions across levels
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(bob);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.SUBNET);

        vm.prank(carol);
        ghostCore.jackIn(300 * 1e18, IGhostCore.Level.DARKNET);

        // Execute scans for each level
        IGhostCore.Level[3] memory levels =
            [IGhostCore.Level.VAULT, IGhostCore.Level.SUBNET, IGhostCore.Level.DARKNET];

        for (uint256 i = 0; i < levels.length; i++) {
            IGhostCore.LevelState memory state = ghostCore.getLevelState(levels[i]);
            vm.warp(state.nextScanTime);

            traceScan.executeScan(levels[i]);
            vm.warp(block.timestamp + 121 seconds);
            traceScan.finalizeScan(levels[i]);

            ITraceScan.Scan memory scan = traceScan.getCurrentScan(levels[i]);
            console.log("Level", uint8(levels[i]), "- Deaths:", scan.deathCount);
        }

        console.log("\n=== Multi-Level Scans Complete ===");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CASCADE FLOW TEST
    // ══════════════════════════════════════════════════════════════════════════════

    function test_CascadeDistribution() public {
        console.log("=== Cascade Distribution ===");

        // Create positions in multiple levels to test cascade flow
        // Higher levels should receive upstream cascade from lower levels

        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT); // Level 1

        vm.prank(bob);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.MAINFRAME); // Level 2

        vm.prank(carol);
        ghostCore.jackIn(500 * 1e18, IGhostCore.Level.DARKNET); // Level 4

        // Get initial rewards
        uint256 aliceRewardsBefore = ghostCore.getPendingRewards(alice);
        uint256 bobRewardsBefore = ghostCore.getPendingRewards(bob);

        // Execute DARKNET scan (deaths cascade to upstream levels)
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.DARKNET);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.DARKNET);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.DARKNET);
        bool carolDies = traceScan.isDead(scan.seed, carol, 3500); // 35% death rate

        if (carolDies) {
            address[] memory dead = new address[](1);
            dead[0] = carol;
            traceScan.submitDeaths(IGhostCore.Level.DARKNET, dead);
        }

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.DARKNET);

        // Check if cascade was distributed
        if (carolDies) {
            uint256 aliceRewardsAfter = ghostCore.getPendingRewards(alice);
            uint256 bobRewardsAfter = ghostCore.getPendingRewards(bob);

            console.log("Carol died - checking cascade...");
            console.log("Alice rewards before:", aliceRewardsBefore / 1e18);
            console.log("Alice rewards after:", aliceRewardsAfter / 1e18);
            console.log("Bob rewards before:", bobRewardsBefore / 1e18);
            console.log("Bob rewards after:", bobRewardsAfter / 1e18);

            // VAULT and MAINFRAME should have received cascade
            assertGt(aliceRewardsAfter, aliceRewardsBefore, "Alice should receive cascade");
            assertGt(bobRewardsAfter, bobRewardsBefore, "Bob should receive cascade");
        }

        console.log("\n=== Cascade Distribution Complete ===");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // KEEPER AUTOMATION TEST
    // ══════════════════════════════════════════════════════════════════════════════

    function test_KeeperAutomation() public {
        console.log("=== Keeper Automation ===");

        // Create position
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Warp to scan time
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);

        // Keeper checks what to do
        (bool canExec, bytes memory payload) = traceScan.checker();
        assertTrue(canExec, "Keeper should find work");

        // Execute keeper payload
        (bool success,) = address(traceScan).call(payload);
        assertTrue(success, "Keeper execution should succeed");

        // Verify scan was executed
        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        assertGt(scan.seed, 0, "Scan should be active");

        // Warp past submission window
        vm.warp(block.timestamp + 121 seconds);

        // Keeper checks again
        (canExec, payload) = traceScan.checker();
        assertTrue(canExec, "Keeper should find finalization work");

        // Execute finalization
        (success,) = address(traceScan).call(payload);
        assertTrue(success, "Finalization should succeed");

        // Verify finalized
        scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        assertTrue(scan.finalized, "Scan should be finalized");

        console.log("Keeper successfully automated scan execution and finalization");
        console.log("\n=== Keeper Automation Complete ===");
    }
}
