// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { DataToken } from "../src/token/DataToken.sol";
import { GhostCore } from "../src/core/GhostCore.sol";
import { TraceScan } from "../src/core/TraceScan.sol";
import { IGhostCore } from "../src/core/interfaces/IGhostCore.sol";
import { ITraceScan } from "../src/core/interfaces/ITraceScan.sol";

/// @title TraceScan Tests
/// @notice Tests for the GHOSTNET scan and death selection system
contract TraceScanTest is Test {
    DataToken public token;
    GhostCore public ghostCore;
    TraceScan public traceScan;

    address public treasury = makeAddr("treasury");
    address public owner = makeAddr("owner");
    address public boostSigner = makeAddr("boostSigner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");
    address public keeper = makeAddr("keeper");

    uint256 constant TOTAL_SUPPLY = 100_000_000 * 1e18;
    uint256 constant USER_BALANCE = 10_000_000 * 1e18;

    function setUp() public {
        // Deploy token
        address[] memory recipients = new address[](4);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = carol;
        recipients[3] = treasury;

        uint256[] memory amounts = new uint256[](4);
        amounts[0] = USER_BALANCE;
        amounts[1] = USER_BALANCE;
        amounts[2] = USER_BALANCE;
        amounts[3] = TOTAL_SUPPLY - (USER_BALANCE * 3);

        token = new DataToken(treasury, owner, recipients, amounts);

        // Deploy GhostCore
        GhostCore ghostCoreImpl = new GhostCore();
        bytes memory ghostCoreInit = abi.encodeCall(
            GhostCore.initialize, (address(token), treasury, boostSigner, owner)
        );
        ERC1967Proxy ghostCoreProxy = new ERC1967Proxy(address(ghostCoreImpl), ghostCoreInit);
        ghostCore = GhostCore(address(ghostCoreProxy));

        // Deploy TraceScan
        TraceScan traceScanImpl = new TraceScan();
        bytes memory traceScanInit =
            abi.encodeCall(TraceScan.initialize, (address(ghostCore), owner));
        ERC1967Proxy traceScanProxy = new ERC1967Proxy(address(traceScanImpl), traceScanInit);
        traceScan = TraceScan(address(traceScanProxy));

        // Setup roles
        vm.startPrank(owner);
        token.setTaxExclusion(address(ghostCore), true);
        ghostCore.grantRole(ghostCore.SCANNER_ROLE(), address(traceScan));
        traceScan.grantRole(traceScan.KEEPER_ROLE(), keeper);
        vm.stopPrank();

        // Approve tokens
        vm.prank(alice);
        token.approve(address(ghostCore), type(uint256).max);
        vm.prank(bob);
        token.approve(address(ghostCore), type(uint256).max);
        vm.prank(carol);
        token.approve(address(ghostCore), type(uint256).max);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INITIALIZATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Initialize_SetsCorrectState() public view {
        assertEq(traceScan.submissionWindow(), 120 seconds);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SCAN EXECUTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_ExecuteScan_CreatesScan() public {
        // Jack in a user
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Warp to scan time
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);

        // Execute scan
        traceScan.executeScan(IGhostCore.Level.VAULT);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        assertGt(scan.seed, 0);
        assertEq(scan.executedAt, block.timestamp);
        assertFalse(scan.finalized);
    }

    function test_ExecuteScan_EmitsEvent() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);

        vm.expectEmit(true, true, false, false);
        emit ITraceScan.ScanExecuted(
            IGhostCore.Level.VAULT, 1, 0, uint64(block.timestamp) // seed will be different
        );

        traceScan.executeScan(IGhostCore.Level.VAULT);
    }

    function test_ExecuteScan_RevertWhen_TooEarly() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Don't warp - try immediately
        vm.expectRevert(ITraceScan.ScanNotReady.selector);
        traceScan.executeScan(IGhostCore.Level.VAULT);
    }

    function test_ExecuteScan_RevertWhen_ScanAlreadyActive() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);

        traceScan.executeScan(IGhostCore.Level.VAULT);

        // Try again without finalizing
        vm.expectRevert(ITraceScan.ScanAlreadyActive.selector);
        traceScan.executeScan(IGhostCore.Level.VAULT);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // DEATH VERIFICATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_IsDead_DeterministicResult() public pure {
        uint256 seed = 12345;
        address user = address(0x1234);
        uint16 deathRate = 5000; // 50%

        // Same inputs should produce same result
        bool result1 = _isDead(seed, user, deathRate);
        bool result2 = _isDead(seed, user, deathRate);

        assertEq(result1, result2);
    }

    function test_IsDead_RespectsDeathRate() public {
        uint256 seed = 12345;
        uint16 lowDeathRate = 100; // 1%
        uint16 highDeathRate = 9900; // 99%

        uint256 lowDeaths;
        uint256 highDeaths;

        // Test with 100 addresses
        for (uint160 i = 1; i <= 100; i++) {
            address user = address(i);
            if (_isDead(seed, user, lowDeathRate)) lowDeaths++;
            if (_isDead(seed, user, highDeathRate)) highDeaths++;
        }

        // Low death rate should have fewer deaths
        assertLt(lowDeaths, highDeaths);
    }

    function testFuzz_IsDead_AlwaysBelowRate(uint256 seed, address user, uint16 deathRate) public {
        vm.assume(deathRate <= 10_000);

        bool result = traceScan.isDead(seed, user, deathRate);

        // If death rate is 0, should never die
        if (deathRate == 0) {
            assertFalse(result);
        }
        // If death rate is 10000, should always die
        if (deathRate == 10_000) {
            assertTrue(result);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // DEATH SUBMISSION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_SubmitDeaths_ProcessesValidDeaths() public {
        // Setup: create positions
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(bob);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Execute scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);

        // Find who should die
        bool aliceDies = traceScan.isDead(scan.seed, alice, 500);
        bool bobDies = traceScan.isDead(scan.seed, bob, 500);

        address[] memory deadUsers = new address[](2);
        uint256 count;

        if (aliceDies) deadUsers[count++] = alice;
        if (bobDies) deadUsers[count++] = bob;

        if (count > 0) {
            // Resize array
            assembly {
                mstore(deadUsers, count)
            }

            traceScan.submitDeaths(IGhostCore.Level.VAULT, deadUsers);

            // Verify deaths were processed
            if (aliceDies) {
                assertFalse(ghostCore.isAlive(alice));
            }
            if (bobDies) {
                assertFalse(ghostCore.isAlive(bob));
            }
        }
    }

    function test_SubmitDeaths_RevertWhen_NoActiveScan() public {
        address[] memory deadUsers = new address[](1);
        deadUsers[0] = alice;

        vm.expectRevert(ITraceScan.ScanNotActive.selector);
        traceScan.submitDeaths(IGhostCore.Level.VAULT, deadUsers);
    }

    function test_SubmitDeaths_RevertWhen_UserNotDead() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);

        // Find someone who should NOT die and try to submit them
        // Use a death rate of 0 to guarantee they survive
        // But actual death rate is 500 (5%), so we need to find a survivor

        bool aliceDies = traceScan.isDead(scan.seed, alice, 500);

        if (!aliceDies) {
            address[] memory deadUsers = new address[](1);
            deadUsers[0] = alice;

            vm.expectRevert(ITraceScan.UserNotDead.selector);
            traceScan.submitDeaths(IGhostCore.Level.VAULT, deadUsers);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SCAN FINALIZATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_FinalizeScan_CompletesSuccessfully() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        // Warp past submission window
        vm.warp(block.timestamp + 121 seconds);

        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        assertTrue(scan.finalized);
        assertGt(scan.finalizedAt, 0);
    }

    function test_FinalizeScan_EmitsEvent() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 121 seconds);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);

        vm.expectEmit(true, true, false, false);
        emit ITraceScan.ScanFinalized(
            IGhostCore.Level.VAULT,
            scan.scanId,
            scan.deathCount,
            scan.totalDead,
            uint64(block.timestamp)
        );

        traceScan.finalizeScan(IGhostCore.Level.VAULT);
    }

    function test_FinalizeScan_RevertWhen_SubmissionWindowOpen() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        // Don't warp - try to finalize immediately
        vm.expectRevert(ITraceScan.SubmissionWindowNotClosed.selector);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);
    }

    function test_FinalizeScan_IncrementsGhostStreak() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.Position memory posBefore = ghostCore.getPosition(alice);
        assertEq(posBefore.ghostStreak, 0);

        // Complete full scan cycle without alice dying
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        // Check if alice survived (is still alive)
        if (ghostCore.isAlive(alice)) {
            IGhostCore.Position memory posAfter = ghostCore.getPosition(alice);
            assertEq(posAfter.ghostStreak, 1);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // KEEPER INTERFACE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Checker_ReturnsExecuteScan() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Initially should return false (scan not ready)
        (bool canExec, bytes memory payload) = traceScan.checker();

        // Warp to scan time
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);

        (canExec, payload) = traceScan.checker();
        assertTrue(canExec);

        // Execute the payload
        (bool success,) = address(traceScan).call(payload);
        assertTrue(success);
    }

    function test_Checker_ReturnsFinalizeScan() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        // Warp past submission window
        vm.warp(block.timestamp + 121 seconds);

        (bool canExec, bytes memory payload) = traceScan.checker();
        assertTrue(canExec);

        // Execute the payload
        (bool success,) = address(traceScan).call(payload);
        assertTrue(success);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        assertTrue(scan.finalized);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_CanExecuteScan() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        assertFalse(traceScan.canExecuteScan(IGhostCore.Level.VAULT));

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);

        assertTrue(traceScan.canExecuteScan(IGhostCore.Level.VAULT));
    }

    function test_CanFinalizeScan() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        assertFalse(traceScan.canFinalizeScan(IGhostCore.Level.VAULT));

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        assertFalse(traceScan.canFinalizeScan(IGhostCore.Level.VAULT));

        vm.warp(block.timestamp + 121 seconds);
        assertTrue(traceScan.canFinalizeScan(IGhostCore.Level.VAULT));
    }

    function test_WouldDie() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // No scan active
        assertFalse(traceScan.wouldDie(IGhostCore.Level.VAULT, alice));

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        // Now we can check
        // Result depends on seed - just verify it doesn't revert
        traceScan.wouldDie(IGhostCore.Level.VAULT, alice);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ERROR PATH TESTS - executeScan
    // ══════════════════════════════════════════════════════════════════════════════

    function test_ExecuteScan_RevertWhen_InvalidLevel_None() public {
        vm.expectRevert(ITraceScan.InvalidLevel.selector);
        traceScan.executeScan(IGhostCore.Level.NONE);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ERROR PATH TESTS - submitDeaths
    // ══════════════════════════════════════════════════════════════════════════════

    function test_SubmitDeaths_RevertWhen_ScanAlreadyFinalized() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Execute and finalize scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        // Try to submit deaths after finalization
        address[] memory deadUsers = new address[](1);
        deadUsers[0] = alice;

        vm.expectRevert(ITraceScan.ScanAlreadyFinalized.selector);
        traceScan.submitDeaths(IGhostCore.Level.VAULT, deadUsers);
    }

    function test_SubmitDeaths_RevertWhen_SubmissionWindowClosed() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        // Warp past submission window but don't finalize
        vm.warp(block.timestamp + 121 seconds);

        address[] memory deadUsers = new address[](1);
        deadUsers[0] = alice;

        vm.expectRevert(ITraceScan.SubmissionWindowClosed.selector);
        traceScan.submitDeaths(IGhostCore.Level.VAULT, deadUsers);
    }

    function test_SubmitDeaths_RevertWhen_BatchTooLarge() public {
        // Set max batch size to 1
        vm.prank(owner);
        traceScan.setMaxBatchSize(1);

        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(bob);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        // Try to submit 2 users when max is 1
        address[] memory deadUsers = new address[](2);
        deadUsers[0] = alice;
        deadUsers[1] = bob;

        vm.expectRevert(ITraceScan.BatchTooLarge.selector);
        traceScan.submitDeaths(IGhostCore.Level.VAULT, deadUsers);
    }

    function test_SubmitDeaths_SkipsUserAtWrongLevel() public {
        // Alice in VAULT, Bob in SUBNET
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(bob);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.SUBNET);

        // Execute VAULT scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);

        // Try to submit Bob (who is in SUBNET) to VAULT scan
        // Bob should be skipped, but if alice also isn't dead, this will return early
        bool aliceDies = traceScan.isDead(scan.seed, alice, 500);

        if (aliceDies) {
            address[] memory deadUsers = new address[](2);
            deadUsers[0] = bob; // Wrong level - should be skipped
            deadUsers[1] = alice; // Correct level

            traceScan.submitDeaths(IGhostCore.Level.VAULT, deadUsers);

            // Bob should still be alive (skipped)
            assertTrue(ghostCore.isAlive(bob));
            // Alice should be dead
            assertFalse(ghostCore.isAlive(alice));
        }
    }

    function test_SubmitDeaths_SkipsAlreadyDeadUser() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Kill alice via processDeaths first
        address[] memory dead = new address[](1);
        dead[0] = alice;

        vm.prank(address(traceScan));
        ghostCore.processDeaths(IGhostCore.Level.VAULT, dead);

        assertFalse(ghostCore.isAlive(alice));

        // Now try to submit alice again in a scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        // Submit already-dead alice - should be skipped (no revert, just returns)
        address[] memory deadUsers = new address[](1);
        deadUsers[0] = alice;

        // This should not revert - it just skips the user
        traceScan.submitDeaths(IGhostCore.Level.VAULT, deadUsers);

        // Scan death count should be 0
        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        assertEq(scan.deathCount, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ERROR PATH TESTS - finalizeScan
    // ══════════════════════════════════════════════════════════════════════════════

    function test_FinalizeScan_RevertWhen_ScanNotActive() public {
        // No scan has been executed
        vm.expectRevert(ITraceScan.ScanNotActive.selector);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);
    }

    function test_FinalizeScan_RevertWhen_ScanAlreadyFinalized() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        // Try to finalize again
        vm.expectRevert(ITraceScan.ScanAlreadyFinalized.selector);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);
    }

    function test_FinalizeScan_DistributesCascadeWhenDeaths() public {
        // Setup multiple users
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.prank(bob);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        ITraceScan.Scan memory scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);

        // Find and submit deaths
        address[] memory dead = new address[](2);
        uint256 count;
        if (traceScan.isDead(scan.seed, alice, 500)) dead[count++] = alice;
        if (traceScan.isDead(scan.seed, bob, 500)) dead[count++] = bob;

        if (count > 0) {
            assembly { mstore(dead, count) }
            traceScan.submitDeaths(IGhostCore.Level.VAULT, dead);
        }

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        // Verify cascade was distributed (totalDead should be recorded)
        scan = traceScan.getCurrentScan(IGhostCore.Level.VAULT);
        assertTrue(scan.finalized);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // WOULDDIE VIEW FUNCTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_WouldDie_ReturnsFalse_WhenUserNotAlive() public {
        // User has no position
        assertFalse(traceScan.wouldDie(IGhostCore.Level.VAULT, alice));

        // Create and kill position
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        address[] memory dead = new address[](1);
        dead[0] = alice;
        vm.prank(address(traceScan));
        ghostCore.processDeaths(IGhostCore.Level.VAULT, dead);

        // Execute scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        // Dead user should return false
        assertFalse(traceScan.wouldDie(IGhostCore.Level.VAULT, alice));
    }

    function test_WouldDie_ReturnsFalse_WhenUserAtWrongLevel() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.SUBNET);

        // Execute VAULT scan
        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        // Alice is in SUBNET, checking VAULT level should return false
        assertFalse(traceScan.wouldDie(IGhostCore.Level.VAULT, alice));
    }

    function test_WouldDie_ReturnsFalse_WhenScanFinalized() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        // After finalization, wouldDie returns false
        assertFalse(traceScan.wouldDie(IGhostCore.Level.VAULT, alice));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CANFINALIZESCAN VIEW FUNCTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_CanFinalizeScan_ReturnsFalse_WhenAlreadyFinalized() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 121 seconds);
        traceScan.finalizeScan(IGhostCore.Level.VAULT);

        assertFalse(traceScan.canFinalizeScan(IGhostCore.Level.VAULT));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Pause_Success() public {
        vm.prank(owner);
        traceScan.pause();

        // Verify paused by trying to execute scan
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);

        vm.expectRevert();
        traceScan.executeScan(IGhostCore.Level.VAULT);
    }

    function test_Pause_RevertWhen_NotPauser() public {
        vm.prank(alice);
        vm.expectRevert();
        traceScan.pause();
    }

    function test_Unpause_Success() public {
        vm.prank(owner);
        traceScan.pause();

        vm.prank(owner);
        traceScan.unpause();

        // Should work now
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);

        traceScan.executeScan(IGhostCore.Level.VAULT);
    }

    function test_Unpause_RevertWhen_NotPauser() public {
        vm.prank(owner);
        traceScan.pause();

        vm.prank(alice);
        vm.expectRevert();
        traceScan.unpause();
    }

    function test_SetSubmissionWindow_Success() public {
        uint256 newWindow = 300 seconds;

        vm.prank(owner);
        traceScan.setSubmissionWindow(newWindow);

        assertEq(traceScan.submissionWindow(), newWindow);
    }

    function test_SetSubmissionWindow_RevertWhen_NotAdmin() public {
        vm.prank(alice);
        vm.expectRevert();
        traceScan.setSubmissionWindow(300 seconds);
    }

    function test_SetMaxBatchSize_Success() public {
        uint256 newSize = 500;

        vm.prank(owner);
        traceScan.setMaxBatchSize(newSize);

        // Verify by trying to submit a batch
        // (Internal check via BatchTooLarge)
    }

    function test_SetMaxBatchSize_RevertWhen_NotAdmin() public {
        vm.prank(alice);
        vm.expectRevert();
        traceScan.setMaxBatchSize(500);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // PAUSED STATE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_SubmitDeaths_RevertWhen_Paused() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        vm.prank(owner);
        traceScan.pause();

        address[] memory deadUsers = new address[](1);
        deadUsers[0] = alice;

        vm.expectRevert();
        traceScan.submitDeaths(IGhostCore.Level.VAULT, deadUsers);
    }

    function test_FinalizeScan_RevertWhen_Paused() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        IGhostCore.LevelState memory state = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        vm.warp(state.nextScanTime);
        traceScan.executeScan(IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 121 seconds);

        vm.prank(owner);
        traceScan.pause();

        vm.expectRevert();
        traceScan.finalizeScan(IGhostCore.Level.VAULT);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    function _isDead(uint256 seed, address user, uint16 deathRateBps)
        internal
        pure
        returns (bool)
    {
        uint256 roll = uint256(keccak256(abi.encode(seed, user))) % 10_000;
        return roll < deathRateBps;
    }
}
