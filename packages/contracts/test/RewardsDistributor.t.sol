// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { DataToken } from "../src/token/DataToken.sol";
import { GhostCore } from "../src/core/GhostCore.sol";
import { RewardsDistributor } from "../src/periphery/RewardsDistributor.sol";
import { IGhostCore } from "../src/core/interfaces/IGhostCore.sol";

/// @title RewardsDistributor Tests
/// @notice Tests for the GHOSTNET emission distribution system
contract RewardsDistributorTest is Test {
    DataToken public token;
    GhostCore public ghostCore;
    RewardsDistributor public distributor;

    address public treasury = makeAddr("treasury");
    address public owner = makeAddr("owner");
    address public boostSigner = makeAddr("boostSigner");
    address public alice = makeAddr("alice");

    uint256 constant TOTAL_SUPPLY = 100_000_000 * 1e18;
    uint256 constant EMISSIONS_ALLOCATION = 60_000_000 * 1e18;
    uint256 constant USER_BALANCE = 10_000_000 * 1e18;

    function setUp() public {
        // Deploy token
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = treasury;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = USER_BALANCE;
        amounts[1] = TOTAL_SUPPLY - USER_BALANCE;

        token = new DataToken(treasury, owner, recipients, amounts);

        // Deploy GhostCore
        GhostCore ghostCoreImpl = new GhostCore();
        bytes memory initData =
            abi.encodeCall(GhostCore.initialize, (address(token), treasury, boostSigner, owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(ghostCoreImpl), initData);
        ghostCore = GhostCore(address(proxy));

        // Deploy RewardsDistributor
        distributor = new RewardsDistributor(address(token), address(ghostCore), owner);

        // Setup roles
        vm.startPrank(owner);
        token.setTaxExclusion(address(ghostCore), true);
        token.setTaxExclusion(address(distributor), true);
        ghostCore.grantRole(ghostCore.DISTRIBUTOR_ROLE(), address(distributor));
        vm.stopPrank();

        // Fund distributor with emissions allocation
        vm.prank(treasury);
        token.transfer(address(distributor), EMISSIONS_ALLOCATION);

        // Setup alice
        vm.prank(alice);
        token.approve(address(ghostCore), type(uint256).max);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INITIALIZATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Initialize_SetsCorrectState() public view {
        assertEq(address(distributor.dataToken()), address(token));
        assertEq(address(distributor.ghostCore()), address(ghostCore));
        assertEq(distributor.TOTAL_EMISSIONS(), EMISSIONS_ALLOCATION);
        assertEq(distributor.EMISSION_DURATION(), 730 days);
    }

    function test_Initialize_SetsDefaultWeights() public view {
        // Default: 5/10/20/30/35
        assertEq(distributor.levelWeights(0), 500); // VAULT
        assertEq(distributor.levelWeights(1), 1000); // MAINFRAME
        assertEq(distributor.levelWeights(2), 2000); // SUBNET
        assertEq(distributor.levelWeights(3), 3000); // DARKNET
        assertEq(distributor.levelWeights(4), 3500); // BLACK_ICE
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EMISSION CALCULATION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_PendingEmissions_ZeroAtStart() public view {
        assertEq(distributor.pendingEmissions(), 0);
    }

    function test_PendingEmissions_AccruesOverTime() public {
        vm.warp(block.timestamp + 1 days);

        uint256 pending = distributor.pendingEmissions();
        uint256 expectedDaily = (EMISSIONS_ALLOCATION * 1 days) / 730 days;

        // Allow small rounding difference
        assertApproxEqAbs(pending, expectedDaily, 1e18);
    }

    function test_TotalVested_ZeroAtStart() public view {
        assertEq(distributor.totalVested(), 0);
    }

    function test_TotalVested_FullyVestedAtEnd() public {
        vm.warp(block.timestamp + 730 days);

        assertEq(distributor.totalVested(), EMISSIONS_ALLOCATION);
    }

    function test_TotalVested_HalfwayVested() public {
        vm.warp(block.timestamp + 365 days);

        uint256 vested = distributor.totalVested();
        uint256 expectedHalf = EMISSIONS_ALLOCATION / 2;

        assertApproxEqAbs(vested, expectedHalf, 1e18);
    }

    function test_EmissionRates() public view {
        uint256 ratePerSecond = distributor.emissionRatePerSecond();
        uint256 ratePerDay = distributor.emissionRatePerDay();

        assertEq(ratePerSecond, EMISSIONS_ALLOCATION / 730 days);
        assertEq(ratePerDay, (EMISSIONS_ALLOCATION * 1 days) / 730 days);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // DISTRIBUTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Distribute_TransfersToGhostCore() public {
        // Create a position so there's TVL
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 1 days);

        uint256 pending = distributor.pendingEmissions();
        uint256 ghostCoreBefore = token.balanceOf(address(ghostCore));

        distributor.distribute();

        // GhostCore should have received the emissions (allow tiny rounding diff)
        uint256 ghostCoreAfter = token.balanceOf(address(ghostCore));
        assertApproxEqAbs(ghostCoreAfter - ghostCoreBefore, pending, 10);
    }

    function test_Distribute_UpdatesTotalDistributed() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 1 days);

        uint256 pending = distributor.pendingEmissions();

        distributor.distribute();

        assertEq(distributor.totalDistributed(), pending);
    }

    function test_Distribute_EmitsEvent() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 1 days);

        uint256 pending = distributor.pendingEmissions();

        vm.expectEmit(true, true, true, true);
        emit RewardsDistributor.EmissionsDistributed(pending, block.timestamp);

        distributor.distribute();
    }

    function test_Distribute_MultipleDistributions() public {
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // First distribution
        vm.warp(block.timestamp + 1 days);
        distributor.distribute();
        uint256 firstDistribution = distributor.totalDistributed();

        // Second distribution
        vm.warp(block.timestamp + 1 days);
        distributor.distribute();
        uint256 secondDistribution = distributor.totalDistributed();

        // Should have distributed roughly double
        assertApproxEqAbs(secondDistribution, firstDistribution * 2, 1e18);
    }

    function test_Distribute_RevertWhen_NothingPending() public {
        vm.expectRevert(RewardsDistributor.NothingToDistribute.selector);
        distributor.distribute();
    }

    function test_Distribute_RespectsLevelWeights() public {
        // Create positions in multiple levels
        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        // Get initial accRewardsPerShare
        IGhostCore.LevelState memory vaultBefore = ghostCore.getLevelState(IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 1 days);
        distributor.distribute();

        IGhostCore.LevelState memory vaultAfter = ghostCore.getLevelState(IGhostCore.Level.VAULT);

        // VAULT has 5% weight, so should receive 5% of emissions
        uint256 expectedVaultEmission = (distributor.totalDistributed() * 500) / 10_000;
        uint256 actualRewardsAdded =
            (vaultAfter.accRewardsPerShare - vaultBefore.accRewardsPerShare) * 100 * 1e18 / 1e18;

        assertApproxEqAbs(actualRewardsAdded, expectedVaultEmission, 1e18);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_SetLevelWeights_Success() public {
        uint16[5] memory newWeights = [uint16(2000), 2000, 2000, 2000, 2000];

        vm.prank(owner);
        distributor.setLevelWeights(newWeights);

        for (uint256 i = 0; i < 5; i++) {
            assertEq(distributor.levelWeights(i), 2000);
        }
    }

    function test_SetLevelWeights_EmitsEvent() public {
        uint16[5] memory newWeights = [uint16(2000), 2000, 2000, 2000, 2000];

        vm.expectEmit(true, true, true, true);
        emit RewardsDistributor.WeightsUpdated(newWeights);

        vm.prank(owner);
        distributor.setLevelWeights(newWeights);
    }

    function test_SetLevelWeights_RevertWhen_InvalidSum() public {
        uint16[5] memory newWeights = [uint16(2000), 2000, 2000, 2000, 1000]; // Sum = 9000

        vm.prank(owner);
        vm.expectRevert(RewardsDistributor.InvalidWeights.selector);
        distributor.setLevelWeights(newWeights);
    }

    function test_SetLevelWeights_RevertWhen_NotOwner() public {
        uint16[5] memory newWeights = [uint16(2000), 2000, 2000, 2000, 2000];

        vm.prank(alice);
        vm.expectRevert();
        distributor.setLevelWeights(newWeights);
    }

    function test_SetGhostCore_Success() public {
        address newGhostCore = makeAddr("newGhostCore");

        vm.prank(owner);
        distributor.setGhostCore(newGhostCore);

        assertEq(address(distributor.ghostCore()), newGhostCore);
    }

    function test_SetGhostCore_RevertWhen_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(RewardsDistributor.InvalidAddress.selector);
        distributor.setGhostCore(address(0));
    }

    function test_EmergencyWithdraw() public {
        uint256 amount = 1000 * 1e18;
        address recipient = makeAddr("recipient");

        uint256 distributorBefore = token.balanceOf(address(distributor));

        vm.prank(owner);
        distributor.emergencyWithdraw(amount, recipient);

        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.balanceOf(address(distributor)), distributorBefore - amount);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_RemainingEmissions() public {
        assertEq(distributor.remainingEmissions(), EMISSIONS_ALLOCATION);

        vm.prank(alice);
        ghostCore.jackIn(100 * 1e18, IGhostCore.Level.VAULT);

        vm.warp(block.timestamp + 1 days);
        distributor.distribute();

        assertLt(distributor.remainingEmissions(), EMISSIONS_ALLOCATION);
    }

    function test_EmissionsEnded() public {
        assertFalse(distributor.emissionsEnded());

        vm.warp(block.timestamp + 731 days);

        assertTrue(distributor.emissionsEnded());
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function testFuzz_PendingEmissions_LinearVesting(
        uint256 daysElapsed
    ) public {
        daysElapsed = bound(daysElapsed, 1, 730);

        vm.warp(block.timestamp + daysElapsed * 1 days);

        uint256 pending = distributor.pendingEmissions();
        uint256 expected = (EMISSIONS_ALLOCATION * daysElapsed * 1 days) / 730 days;

        // Allow 0.01% tolerance for rounding
        assertApproxEqRel(pending, expected, 1e14);
    }
}
