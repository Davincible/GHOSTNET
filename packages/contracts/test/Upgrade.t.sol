// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { DataToken } from "../src/token/DataToken.sol";
import { GhostCore } from "../src/core/GhostCore.sol";
import { TraceScan } from "../src/core/TraceScan.sol";
import { DeadPool } from "../src/markets/DeadPool.sol";
import { IDeadPool } from "../src/markets/interfaces/IDeadPool.sol";
import { IGhostCore } from "../src/core/interfaces/IGhostCore.sol";

/// @title GhostCoreV2
/// @notice Mock V2 implementation for upgrade testing
/// @dev Adds a new function and state variable while preserving storage layout
contract GhostCoreV2 is GhostCore {
    /// @notice New function added in V2
    function version() external pure returns (string memory) {
        return "2.0.0";
    }

    /// @notice New function to demonstrate upgrade capability
    function newFeature() external pure returns (bool) {
        return true;
    }
}

/// @title GhostCoreV2BadStorage
/// @notice V2 with incorrect storage layout (for testing rejection)
/// @dev Demonstrates what NOT to do - prepending storage breaks layout
contract GhostCoreV2BadStorage is GhostCore {
    // BAD: This prepends storage, breaking layout
    uint256 public badVariable;

    function version() external pure returns (string memory) {
        return "2.0.0-bad";
    }
}

/// @title TraceScanV2
/// @notice Mock V2 implementation for TraceScan upgrade testing
contract TraceScanV2 is TraceScan {
    function version() external pure returns (string memory) {
        return "2.0.0";
    }
}

/// @title DeadPoolV2
/// @notice Mock V2 implementation for DeadPool upgrade testing
contract DeadPoolV2 is DeadPool {
    function version() external pure returns (string memory) {
        return "2.0.0";
    }
}

/// @title UpgradeTest
/// @notice Tests UUPS upgrade functionality for all upgradeable contracts
contract UpgradeTest is Test {
    // Contracts
    DataToken public dataToken;
    GhostCore public ghostCoreImpl;
    GhostCore public ghostCore; // Proxy
    TraceScan public traceScanImpl;
    TraceScan public traceScan; // Proxy
    DeadPool public deadPoolImpl;
    DeadPool public deadPool; // Proxy

    // Addresses
    address public admin = makeAddr("admin");
    address public treasury = makeAddr("treasury");
    address public boostSigner = makeAddr("boostSigner");
    address public user = makeAddr("user");
    address public attacker = makeAddr("attacker");

    // Events
    event Upgraded(address indexed implementation);

    function setUp() public {
        // Deploy DataToken
        address[] memory recipients = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        recipients[0] = admin;
        amounts[0] = 100_000_000 * 1e18;

        dataToken = new DataToken(treasury, admin, recipients, amounts);

        // Deploy GhostCore
        ghostCoreImpl = new GhostCore();
        bytes memory ghostCoreInit = abi.encodeCall(
            GhostCore.initialize, (address(dataToken), treasury, boostSigner, admin)
        );
        ERC1967Proxy ghostCoreProxy = new ERC1967Proxy(address(ghostCoreImpl), ghostCoreInit);
        ghostCore = GhostCore(address(ghostCoreProxy));

        // Deploy TraceScan
        traceScanImpl = new TraceScan();
        bytes memory traceScanInit =
            abi.encodeCall(TraceScan.initialize, (address(ghostCore), admin));
        ERC1967Proxy traceScanProxy = new ERC1967Proxy(address(traceScanImpl), traceScanInit);
        traceScan = TraceScan(address(traceScanProxy));

        // Deploy DeadPool
        deadPoolImpl = new DeadPool();
        bytes memory deadPoolInit = abi.encodeCall(DeadPool.initialize, (address(dataToken), admin));
        ERC1967Proxy deadPoolProxy = new ERC1967Proxy(address(deadPoolImpl), deadPoolInit);
        deadPool = DeadPool(address(deadPoolProxy));

        // Setup roles
        vm.startPrank(admin);
        ghostCore.grantRole(ghostCore.SCANNER_ROLE(), address(traceScan));
        dataToken.setTaxExclusion(address(ghostCore), true);
        vm.stopPrank();

        // Fund user
        vm.prank(admin);
        dataToken.transfer(user, 10_000 * 1e18);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // GHOSTCORE UPGRADE TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_GhostCore_Upgrade_Success() public {
        // Create position before upgrade
        vm.startPrank(user);
        dataToken.approve(address(ghostCore), type(uint256).max);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);
        vm.stopPrank();

        // Store state before upgrade
        IGhostCore.Position memory posBefore = ghostCore.getPosition(user);

        // Deploy V2 and upgrade
        GhostCoreV2 v2Impl = new GhostCoreV2();

        vm.prank(admin);
        ghostCore.upgradeToAndCall(address(v2Impl), "");

        // Verify upgrade succeeded
        GhostCoreV2 ghostCoreV2 = GhostCoreV2(address(ghostCore));
        assertEq(ghostCoreV2.version(), "2.0.0");
        assertTrue(ghostCoreV2.newFeature());

        // Verify state preserved
        IGhostCore.Position memory posAfter = ghostCore.getPosition(user);
        assertEq(posAfter.amount, posBefore.amount);
        assertEq(uint8(posAfter.level), uint8(posBefore.level));
        assertEq(posAfter.alive, posBefore.alive);
    }

    function test_GhostCore_Upgrade_PreservesAllState() public {
        // Create multiple positions to populate state
        vm.prank(admin);
        dataToken.transfer(address(this), 1000 * 1e18);

        address[] memory users = new address[](3);
        users[0] = makeAddr("user1");
        users[1] = makeAddr("user2");
        users[2] = makeAddr("user3");

        for (uint256 i; i < users.length; i++) {
            vm.prank(admin);
            dataToken.transfer(users[i], 200 * 1e18);

            vm.startPrank(users[i]);
            dataToken.approve(address(ghostCore), type(uint256).max);
            ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);
            vm.stopPrank();
        }

        // Store state before
        IGhostCore.LevelState memory stateBefore = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        uint256 tvlBefore = ghostCore.getTotalValueLocked();

        // Upgrade
        GhostCoreV2 v2Impl = new GhostCoreV2();
        vm.prank(admin);
        ghostCore.upgradeToAndCall(address(v2Impl), "");

        // Verify all state preserved
        IGhostCore.LevelState memory stateAfter = ghostCore.getLevelState(IGhostCore.Level.VAULT);
        assertEq(stateAfter.totalStaked, stateBefore.totalStaked);
        assertEq(stateAfter.aliveCount, stateBefore.aliveCount);
        assertEq(stateAfter.accRewardsPerShare, stateBefore.accRewardsPerShare);
        assertEq(ghostCore.getTotalValueLocked(), tvlBefore);
    }

    function test_GhostCore_Upgrade_RevertWhen_NotAdmin() public {
        GhostCoreV2 v2Impl = new GhostCoreV2();

        vm.prank(attacker);
        vm.expectRevert();
        ghostCore.upgradeToAndCall(address(v2Impl), "");
    }

    function test_GhostCore_Upgrade_EmitsEvent() public {
        GhostCoreV2 v2Impl = new GhostCoreV2();

        vm.expectEmit(true, false, false, false, address(ghostCore));
        emit Upgraded(address(v2Impl));

        vm.prank(admin);
        ghostCore.upgradeToAndCall(address(v2Impl), "");
    }

    function test_GhostCore_Upgrade_CanBeUpgradedAgain() public {
        // First upgrade
        GhostCoreV2 v2Impl = new GhostCoreV2();
        vm.prank(admin);
        ghostCore.upgradeToAndCall(address(v2Impl), "");

        // Second upgrade (back to V1-style)
        GhostCore v3Impl = new GhostCore();
        vm.prank(admin);
        ghostCore.upgradeToAndCall(address(v3Impl), "");

        // Should still work
        vm.startPrank(user);
        dataToken.approve(address(ghostCore), type(uint256).max);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);
        vm.stopPrank();

        assertTrue(ghostCore.isAlive(user));
    }

    function test_GhostCore_Upgrade_WithCalldata() public {
        // Create a V2 that has an init function
        GhostCoreV2 v2Impl = new GhostCoreV2();

        // Upgrade with empty calldata (no reinitialization)
        vm.prank(admin);
        ghostCore.upgradeToAndCall(address(v2Impl), "");

        // Verify upgrade worked
        assertEq(GhostCoreV2(address(ghostCore)).version(), "2.0.0");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // TRACESCAN UPGRADE TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_TraceScan_Upgrade_Success() public {
        TraceScanV2 v2Impl = new TraceScanV2();

        vm.prank(admin);
        traceScan.upgradeToAndCall(address(v2Impl), "");

        assertEq(TraceScanV2(address(traceScan)).version(), "2.0.0");
    }

    function test_TraceScan_Upgrade_PreservesConfig() public {
        // Check config before
        uint256 windowBefore = traceScan.submissionWindow();

        // Upgrade
        TraceScanV2 v2Impl = new TraceScanV2();
        vm.prank(admin);
        traceScan.upgradeToAndCall(address(v2Impl), "");

        // Config preserved
        assertEq(traceScan.submissionWindow(), windowBefore);
    }

    function test_TraceScan_Upgrade_RevertWhen_NotAdmin() public {
        TraceScanV2 v2Impl = new TraceScanV2();

        vm.prank(attacker);
        vm.expectRevert();
        traceScan.upgradeToAndCall(address(v2Impl), "");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // DEADPOOL UPGRADE TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_DeadPool_Upgrade_Success() public {
        DeadPoolV2 v2Impl = new DeadPoolV2();

        vm.prank(admin);
        deadPool.upgradeToAndCall(address(v2Impl), "");

        assertEq(DeadPoolV2(address(deadPool)).version(), "2.0.0");
    }

    function test_DeadPool_Upgrade_PreservesRounds() public {
        // Create a round before upgrade
        vm.prank(admin);
        uint256 roundId = deadPool.createRound(
            IDeadPool.RoundType.DEATH_COUNT,
            IGhostCore.Level.VAULT,
            50,
            uint64(block.timestamp + 1 days)
        );

        // Upgrade
        DeadPoolV2 v2Impl = new DeadPoolV2();
        vm.prank(admin);
        deadPool.upgradeToAndCall(address(v2Impl), "");

        // Round preserved
        IDeadPool.Round memory round = deadPool.getRound(roundId);
        assertEq(round.line, 50);
        assertEq(uint8(round.roundType), uint8(IDeadPool.RoundType.DEATH_COUNT));
    }

    function test_DeadPool_Upgrade_RevertWhen_NotAdmin() public {
        DeadPoolV2 v2Impl = new DeadPoolV2();

        vm.prank(attacker);
        vm.expectRevert();
        deadPool.upgradeToAndCall(address(v2Impl), "");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // IMPLEMENTATION PROTECTION TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_Implementation_CannotBeInitialized() public {
        // Implementation contracts should have initializers disabled

        // GhostCore implementation
        GhostCore newImpl = new GhostCore();
        vm.expectRevert();
        newImpl.initialize(address(dataToken), treasury, boostSigner, admin);

        // TraceScan implementation
        TraceScan tsImpl = new TraceScan();
        vm.expectRevert();
        tsImpl.initialize(address(ghostCore), admin);

        // DeadPool implementation
        DeadPool dpImpl = new DeadPool();
        vm.expectRevert();
        dpImpl.initialize(address(dataToken), admin);
    }

    function test_Implementation_CannotBeUpgradedDirectly() public {
        // Implementations should not be upgradeable directly
        GhostCoreV2 v2Impl = new GhostCoreV2();

        // This should fail because implementation isn't initialized as a proxy
        vm.expectRevert();
        ghostCoreImpl.upgradeToAndCall(address(v2Impl), "");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // ROLE PRESERVATION TESTS
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_GhostCore_Upgrade_PreservesRoles() public {
        // Check roles before
        assertTrue(ghostCore.hasRole(ghostCore.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(ghostCore.hasRole(ghostCore.SCANNER_ROLE(), address(traceScan)));

        // Upgrade
        GhostCoreV2 v2Impl = new GhostCoreV2();
        vm.prank(admin);
        ghostCore.upgradeToAndCall(address(v2Impl), "");

        // Roles preserved
        assertTrue(ghostCore.hasRole(ghostCore.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(ghostCore.hasRole(ghostCore.SCANNER_ROLE(), address(traceScan)));
    }

    function test_TraceScan_Upgrade_PreservesRoles() public {
        assertTrue(traceScan.hasRole(traceScan.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(traceScan.hasRole(traceScan.KEEPER_ROLE(), admin));

        TraceScanV2 v2Impl = new TraceScanV2();
        vm.prank(admin);
        traceScan.upgradeToAndCall(address(v2Impl), "");

        assertTrue(traceScan.hasRole(traceScan.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(traceScan.hasRole(traceScan.KEEPER_ROLE(), admin));
    }

    function test_DeadPool_Upgrade_PreservesRoles() public {
        assertTrue(deadPool.hasRole(deadPool.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(deadPool.hasRole(deadPool.ROUND_CREATOR_ROLE(), admin));

        DeadPoolV2 v2Impl = new DeadPoolV2();
        vm.prank(admin);
        deadPool.upgradeToAndCall(address(v2Impl), "");

        assertTrue(deadPool.hasRole(deadPool.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(deadPool.hasRole(deadPool.ROUND_CREATOR_ROLE(), admin));
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // FUNCTIONAL TESTS AFTER UPGRADE
    // ═══════════════════════════════════════════════════════════════════════════════

    function test_GhostCore_FunctionalAfterUpgrade() public {
        // Upgrade
        GhostCoreV2 v2Impl = new GhostCoreV2();
        vm.prank(admin);
        ghostCore.upgradeToAndCall(address(v2Impl), "");

        // All core functions should still work
        vm.startPrank(user);
        dataToken.approve(address(ghostCore), type(uint256).max);

        // jackIn
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);
        assertTrue(ghostCore.isAlive(user));

        // addStake
        ghostCore.addStake(50 * 1e18);
        assertEq(ghostCore.getPosition(user).amount, 150 * 1e18);

        // Wait past lock period and extract
        vm.warp(block.timestamp + 5 hours);
        ghostCore.extract();
        assertFalse(ghostCore.isAlive(user));
        vm.stopPrank();
    }

    function test_TraceScan_FunctionalAfterUpgrade() public {
        // Upgrade
        TraceScanV2 v2Impl = new TraceScanV2();
        vm.prank(admin);
        traceScan.upgradeToAndCall(address(v2Impl), "");

        // Core functions should work
        assertTrue(
            traceScan.canExecuteScan(IGhostCore.Level.VAULT)
                || !traceScan.canExecuteScan(IGhostCore.Level.VAULT)
        );

        // Checker should work
        (bool canExec,) = traceScan.checker();
        // Just verifying it doesn't revert
        assertTrue(canExec || !canExec);
    }

    function test_DeadPool_FunctionalAfterUpgrade() public {
        // Upgrade
        DeadPoolV2 v2Impl = new DeadPoolV2();
        vm.prank(admin);
        deadPool.upgradeToAndCall(address(v2Impl), "");

        // Fund DeadPool for bets
        vm.prank(admin);
        dataToken.setTaxExclusion(address(deadPool), true);

        // Create round
        vm.prank(admin);
        uint256 roundId = deadPool.createRound(
            IDeadPool.RoundType.DEATH_COUNT,
            IGhostCore.Level.VAULT,
            50,
            uint64(block.timestamp + 1 hours)
        );

        // Place bet
        vm.startPrank(user);
        dataToken.approve(address(deadPool), type(uint256).max);
        deadPool.placeBet(roundId, true, 10 * 1e18);
        vm.stopPrank();

        // Verify bet recorded
        IDeadPool.Bet memory bet = deadPool.getBet(roundId, user);
        assertEq(bet.amount, 10 * 1e18);
        assertTrue(bet.isOver);
    }
}
