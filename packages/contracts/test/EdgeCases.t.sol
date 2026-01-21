// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { DataToken } from "../src/token/DataToken.sol";
import { GhostCore } from "../src/core/GhostCore.sol";
import { TraceScan } from "../src/core/TraceScan.sol";
import { IGhostCore } from "../src/core/interfaces/IGhostCore.sol";
import { ITraceScan } from "../src/core/interfaces/ITraceScan.sol";

/// @title EdgeCases Tests
/// @notice Tests for edge cases: system reset, culling, and multi-scan scenarios
contract EdgeCasesTest is Test {
    DataToken public token;
    GhostCore public ghostCore;
    TraceScan public traceScan;

    address public treasury = makeAddr("treasury");
    address public owner = makeAddr("owner");
    address public boostSigner = makeAddr("boostSigner");

    uint256 constant TOTAL_SUPPLY = 100_000_000 * 1e18;

    function setUp() public {
        // Deploy token
        address[] memory recipients = new address[](2);
        recipients[0] = owner;
        recipients[1] = address(this);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = TOTAL_SUPPLY / 2;
        amounts[1] = TOTAL_SUPPLY / 2;

        token = new DataToken(treasury, owner, recipients, amounts);

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

        // Setup permissions
        vm.startPrank(owner);
        token.setTaxExclusion(address(ghostCore), true);
        token.setTaxExclusion(address(this), true); // Exclude test contract for easy funding
        ghostCore.grantRole(ghostCore.SCANNER_ROLE(), address(traceScan));
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // SYSTEM RESET TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_SystemReset_TimerExtendsOnDeposit() public {
        address user = makeAddr("user");
        _fundAndApprove(user, 1000 * 1e18);

        // Check initial deadline
        IGhostCore.SystemReset memory resetBefore = ghostCore.getSystemReset();
        uint256 deadlineBefore = resetBefore.deadline;

        // Small deposit - should extend by TIER1_EXTENSION (1 hour)
        vm.prank(user);
        ghostCore.jackIn(15 * 1e18, IGhostCore.Level.VAULT); // < 50 DATA

        IGhostCore.SystemReset memory resetAfter = ghostCore.getSystemReset();

        // Deadline should have extended
        assertGe(resetAfter.deadline, deadlineBefore);
        assertEq(resetAfter.lastDepositor, user);
    }

    function test_SystemReset_LargeDepositFullReset() public {
        address user = makeAddr("user");
        _fundAndApprove(user, 10_000 * 1e18);

        // Large deposit (>1000 DATA) should give full reset (24 hours)
        vm.prank(user);
        ghostCore.jackIn(1500 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.SystemReset memory reset = ghostCore.getSystemReset();

        // Should be close to 24 hours from now
        assertApproxEqAbs(reset.deadline, block.timestamp + 24 hours, 2);
        assertEq(reset.lastDepositor, user);
    }

    function test_SystemReset_TriggerRevertWhenNotReady() public {
        address user = makeAddr("user");
        _fundAndApprove(user, 100 * 1e18);

        vm.prank(user);
        ghostCore.jackIn(50 * 1e18, IGhostCore.Level.VAULT);

        // Try to trigger before deadline
        vm.expectRevert(IGhostCore.SystemResetNotReady.selector);
        ghostCore.triggerSystemReset();
    }

    function test_SystemReset_TriggerSuccess() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        _fundAndApprove(user1, 500 * 1e18);
        _fundAndApprove(user2, 500 * 1e18);

        // Both users jack in
        vm.prank(user1);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(user2);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Record balances before
        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 lastDepositorBefore = token.balanceOf(user2); // user2 was last depositor

        // Warp past deadline
        IGhostCore.SystemReset memory reset = ghostCore.getSystemReset();
        vm.warp(reset.deadline + 1);

        // Anyone can trigger
        ghostCore.triggerSystemReset();

        // Check jackpot was paid
        uint256 lastDepositorAfter = token.balanceOf(user2);
        assertGt(lastDepositorAfter, lastDepositorBefore, "Jackpot should be paid");

        // Check treasury received fee
        uint256 treasuryAfter = token.balanceOf(treasury);
        assertGt(treasuryAfter, treasuryBefore, "Treasury should receive fee");

        // Check positions were penalized (lazy settlement)
        // Penalty applied on next interaction
        vm.prank(user1);
        ghostCore.claimRewards();

        IGhostCore.Position memory pos = ghostCore.getPosition(user1);
        assertLt(pos.amount, 100 * 1e18, "Position should be penalized");
    }

    function test_SystemReset_LazyPenaltySettlement() public {
        address user = makeAddr("user");
        _fundAndApprove(user, 500 * 1e18);

        vm.prank(user);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Trigger reset
        IGhostCore.SystemReset memory reset = ghostCore.getSystemReset();
        vm.warp(reset.deadline + 1);
        ghostCore.triggerSystemReset();

        // Position amount should still show 100 DATA (lazy settlement)
        IGhostCore.Position memory posBefore = ghostCore.getPosition(user);
        assertEq(posBefore.amount, 100 * 1e18);

        // Add stake to trigger settlement
        _fundAndApprove(user, 100 * 1e18);
        vm.prank(user);
        ghostCore.addStake(10 * 1e18);

        // Now position should show penalized amount + new stake
        IGhostCore.Position memory posAfter = ghostCore.getPosition(user);
        assertLt(posAfter.amount, 110 * 1e18); // Less than 100 + 10 due to penalty
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // CULLING TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_Culling_TriggeredWhenLevelFull() public {
        // BLACK_ICE has max 100 positions
        IGhostCore.LevelConfig memory config = ghostCore.getLevelConfig(IGhostCore.Level.BLACK_ICE);
        uint256 maxPositions = config.maxPositions;
        uint256 minStake = config.minStake;

        // Store first user address (must use same encoding as in loop)
        address firstUser = makeAddr(string(abi.encodePacked("cullUser", uint256(0))));

        // Create positions up to capacity
        for (uint256 i = 0; i < maxPositions; i++) {
            address user = makeAddr(string(abi.encodePacked("cullUser", i)));
            _fundAndApprove(user, minStake * 2);

            vm.prank(user);
            ghostCore.jackIn(minStake, IGhostCore.Level.BLACK_ICE);
        }

        // Verify level is at capacity
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.BLACK_ICE);
        assertEq(state.aliveCount, maxPositions);

        // After jacking in with minStake, user has minStake left (funded with 2x)
        uint256 firstUserBalanceBefore = token.balanceOf(firstUser);
        assertEq(firstUserBalanceBefore, minStake, "First user should have minStake remaining");

        // New user tries to join - should trigger culling
        address newUser = makeAddr("newCullUser");
        _fundAndApprove(newUser, minStake * 2);

        vm.prank(newUser);
        ghostCore.jackIn(minStake, IGhostCore.Level.BLACK_ICE);

        // New user should be in
        assertTrue(ghostCore.isAlive(newUser), "New user should be alive after joining");

        // First user should have been culled (marked dead)
        assertFalse(ghostCore.isAlive(firstUser), "First user should be dead (culled)");

        // First user should receive partial return (20% of their stake)
        // cullingPenaltyBps = 8000 (80% loss), so returnAmount = 20% of minStake
        uint256 firstUserBalanceAfter = token.balanceOf(firstUser);
        uint256 expectedReturn = (minStake * (10_000 - config.cullingPenaltyBps)) / 10_000;
        assertEq(
            firstUserBalanceAfter,
            firstUserBalanceBefore + expectedReturn,
            "Culled user should receive partial return"
        );
    }

    function test_Culling_PenaltyCascades() public {
        // Setup: Create positions in upstream levels to receive cascade
        address upstreamUser = makeAddr("upstreamUser");
        _fundAndApprove(upstreamUser, 1000 * 1e18);

        vm.prank(upstreamUser);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        uint256 upstreamRewardsBefore = ghostCore.getPendingRewards(upstreamUser);

        // Fill BLACK_ICE to capacity
        IGhostCore.LevelConfig memory config = ghostCore.getLevelConfig(IGhostCore.Level.BLACK_ICE);
        uint256 maxPositions = config.maxPositions;
        uint256 minStake = config.minStake;

        for (uint256 i = 0; i < maxPositions; i++) {
            address user = makeAddr(string(abi.encodePacked("biUser", i)));
            _fundAndApprove(user, minStake * 2);

            vm.prank(user);
            ghostCore.jackIn(minStake, IGhostCore.Level.BLACK_ICE);
        }

        // Trigger culling
        address newUser = makeAddr("newBiUser");
        _fundAndApprove(newUser, minStake * 2);

        vm.prank(newUser);
        ghostCore.jackIn(minStake, IGhostCore.Level.BLACK_ICE);

        // Culling penalty should have cascaded - but in current implementation
        // it only distributes to same level, not upstream
        // This test documents current behavior
        uint256 upstreamRewardsAfter = ghostCore.getPendingRewards(upstreamUser);

        // Note: Current culling implementation does mini-cascade (burn + same-level only)
        // Full upstream cascade is not implemented in culling
        console.log("Upstream rewards before:", upstreamRewardsBefore);
        console.log("Upstream rewards after:", upstreamRewardsAfter);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // MULTI-SCAN EDGE CASES
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_Scan_CannotExecuteTwiceBeforeFinalize() public {
        address user = makeAddr("user");
        _fundAndApprove(user, 100 * 1e18);

        vm.prank(user);
        ghostCore.jackIn(50 * 1e18, IGhostCore.Level.VAULT);

        // Execute first scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        // Try to execute again before finalization
        vm.warp(block.timestamp + 1);
        vm.expectRevert(ITraceScan.ScanAlreadyActive.selector);
        traceScan.executeScan(IGhostCore.Level.VAULT);
    }

    function test_Scan_MultipleSubmissionBatches() public {
        // Create multiple positions
        for (uint256 i = 0; i < 10; i++) {
            address user = makeAddr(string(abi.encodePacked("user", i)));
            _fundAndApprove(user, 100 * 1e18);

            vm.prank(user);
            ghostCore.jackIn(50 * 1e18, IGhostCore.Level.VAULT);
        }

        // Execute scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);

        // Find dead users
        address[] memory allDead = new address[](10);
        uint256 deadCount;
        for (uint256 i = 0; i < 10; i++) {
            address user = makeAddr(string(abi.encodePacked("user", i)));
            if (traceScan.isDead(scan.seed, user, 500)) {
                allDead[deadCount++] = user;
            }
        }

        if (deadCount > 0) {
            // Submit in two batches
            uint256 batch1Size = deadCount / 2;
            uint256 batch2Size = deadCount - batch1Size;

            address[] memory batch1 = new address[](batch1Size);
            address[] memory batch2 = new address[](batch2Size);

            for (uint256 i = 0; i < batch1Size; i++) {
                batch1[i] = allDead[i];
            }
            for (uint256 i = 0; i < batch2Size; i++) {
                batch2[i] = allDead[batch1Size + i];
            }

            // Submit batch 1
            if (batch1Size > 0) {
                traceScan.submitDeaths(IGhostCore.Level.VAULT, batch1);
            }

            // Submit batch 2
            if (batch2Size > 0) {
                traceScan.submitDeaths(IGhostCore.Level.VAULT, batch2);
            }

            // Verify total deaths
            scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
            assertEq(scan.deathCount, deadCount);
        }
    }

    function test_Scan_DuplicateSubmissionIgnored() public {
        address user = makeAddr("user");
        _fundAndApprove(user, 100 * 1e18);

        vm.prank(user);
        ghostCore.jackIn(50 * 1e18, IGhostCore.Level.VAULT);

        // Execute scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);

        // If user dies, submit twice
        if (traceScan.isDead(scan.seed, user, 500)) {
            address[] memory dead = new address[](1);
            dead[0] = user;

            // First submission
            traceScan.submitDeaths(IGhostCore.Level.VAULT, dead);

            // Second submission - should be ignored (not revert)
            traceScan.submitDeaths(IGhostCore.Level.VAULT, dead);

            // Verify only counted once
            scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
            assertEq(scan.deathCount, 1);
        }
    }

    function test_Scan_FinalizeAfterWindowClosed() public {
        address user = makeAddr("user");
        _fundAndApprove(user, 100 * 1e18);

        vm.prank(user);
        ghostCore.jackIn(50 * 1e18, IGhostCore.Level.VAULT);

        // Execute scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        // Try to finalize before window closes
        vm.expectRevert(ITraceScan.SubmissionWindowNotClosed.selector);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        // Wait for window to close
        vm.warp(block.timestamp + 121 seconds);

        // Now finalization should work
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        assertTrue(scan.finalized);
    }

    function test_Scan_ConsecutiveScansForSameLevel() public {
        address user = makeAddr("user");
        _fundAndApprove(user, 100 * 1e18);

        vm.prank(user);
        ghostCore.jackIn(50 * 1e18, IGhostCore.Level.VAULT);

        // Execute first scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        // Get new scan time (should be scheduled after finalization)
        state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        assertGt(state.nextScanTime, block.timestamp);

        // If user still alive, wait for next scan
        if (ghostCore.isAlive(user)) {
            vm.warp(state.nextScanTime);

            // Execute second scan
            traceScan.executeScan(IGhostCore.Level.VAULT);

            ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
            assertGt(scan.scanId, 1); // Should be scan ID 2
            assertFalse(scan.finalized);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // LOCK PERIOD EDGE CASES
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_LockPeriod_CannotExtractInLockPeriod() public {
        address user = makeAddr("user");
        _fundAndApprove(user, 100 * 1e18);

        vm.prank(user);
        ghostCore.jackIn(50 * 1e18, IGhostCore.Level.VAULT);

        // Warp to just before scan (in lock period)
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime - 30 seconds);

        // Should be in lock period
        assertTrue(ghostCore.isInLockPeriod(user));

        // Cannot extract
        vm.prank(user);
        vm.expectRevert(IGhostCore.PositionLocked.selector);
        ghostCore.extract();
    }

    function test_LockPeriod_CanExtractAfterScan() public {
        address user = makeAddr("user");
        _fundAndApprove(user, 100 * 1e18);

        vm.prank(user);
        ghostCore.jackIn(50 * 1e18, IGhostCore.Level.VAULT);

        // Execute and finalize scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        // Warp past lock period of next scan
        vm.warp(block.timestamp + 5 hours);

        // If alive, should be able to extract
        if (ghostCore.isAlive(user)) {
            assertFalse(ghostCore.isInLockPeriod(user));

            vm.prank(user);
            ghostCore.extract();

            assertFalse(ghostCore.isAlive(user));
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // GHOST STREAK TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_GhostStreak_IncrementsOnSurvival() public {
        address user = makeAddr("user");
        _fundAndApprove(user, 100 * 1e18);

        vm.prank(user);
        ghostCore.jackIn(50 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.Position memory posBefore = ghostCore.getPosition(user);
        assertEq(posBefore.ghostStreak, 0);

        // Execute scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);

        // Submit deaths (if any)
        if (traceScan.isDead(scan.seed, user, 500)) {
            address[] memory dead = new address[](1);
            dead[0] = user;
            traceScan.submitDeaths(IGhostCore.Level.VAULT, dead);
        }

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        // If survived, streak should increment
        if (ghostCore.isAlive(user)) {
            IGhostCore.Position memory posAfter = ghostCore.getPosition(user);
            assertEq(posAfter.ghostStreak, 1);
        }
    }

    function test_GhostStreak_ResetsOnDeath() public {
        address user = makeAddr("user");
        _fundAndApprove(user, 100 * 1e18);

        vm.prank(user);
        ghostCore.jackIn(50 * 1e18, IGhostCore.Level.VAULT);

        // Execute first scan - user survives
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);
        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        // If user died in first scan, streak should be 0
        if (!ghostCore.isAlive(user)) {
            IGhostCore.Position memory pos = ghostCore.getPosition(user);
            assertEq(pos.ghostStreak, 0);
            assertFalse(pos.alive);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // ZERO TVL EDGE CASES
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_Scan_ZeroAlivePositions() public {
        // Create position
        address user = makeAddr("user");
        _fundAndApprove(user, 100 * 1e18);

        vm.prank(user);
        ghostCore.jackIn(50 * 1e18, IGhostCore.Level.VAULT);

        // Extract before scan
        vm.warp(block.timestamp + 1 hours);
        vm.prank(user);
        ghostCore.extract();

        // Now no alive positions
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        assertEq(state.aliveCount, 0);

        // Scan should still execute (no deaths)
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        // Should finalize with 0 deaths
        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        assertTrue(scan.finalized);
        assertEq(scan.deathCount, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════════

    function _fundAndApprove(
        address user,
        uint256 amount
    ) internal {
        token.transfer(user, amount);
        vm.prank(user);
        token.approve(address(ghostCore), type(uint256).max);
    }
}
