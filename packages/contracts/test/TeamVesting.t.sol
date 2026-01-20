// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { DataToken } from "../src/token/DataToken.sol";
import { TeamVesting } from "../src/token/TeamVesting.sol";

/// @title TeamVesting Tests
/// @notice Tests for the GHOSTNET team token vesting contract
contract TeamVestingTest is Test {
    DataToken public token;
    TeamVesting public vesting;

    address public treasury = makeAddr("treasury");
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");

    uint256 constant TOTAL_SUPPLY = 100_000_000 * 1e18;
    uint256 constant ALICE_ALLOCATION = 4_000_000 * 1e18; // 50% of 8M team allocation
    uint256 constant BOB_ALLOCATION = 2_400_000 * 1e18;   // 30% of 8M
    uint256 constant CAROL_ALLOCATION = 1_600_000 * 1e18; // 20% of 8M
    uint256 constant TOTAL_TEAM_ALLOCATION = 8_000_000 * 1e18;

    uint256 constant CLIFF_DURATION = 30 days;
    uint256 constant VESTING_DURATION = 730 days; // ~24 months

    function setUp() public {
        // Deploy token
        address[] memory recipients = new address[](1);
        recipients[0] = treasury;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = TOTAL_SUPPLY;

        token = new DataToken(treasury, owner, recipients, amounts);

        // Deploy vesting contract with team allocations
        address[] memory beneficiaries = new address[](3);
        beneficiaries[0] = alice;
        beneficiaries[1] = bob;
        beneficiaries[2] = carol;

        uint256[] memory allocations = new uint256[](3);
        allocations[0] = ALICE_ALLOCATION;
        allocations[1] = BOB_ALLOCATION;
        allocations[2] = CAROL_ALLOCATION;

        vesting = new TeamVesting(IERC20(address(token)), beneficiaries, allocations);

        // Transfer tokens to vesting contract
        vm.prank(treasury);
        token.transfer(address(vesting), TOTAL_TEAM_ALLOCATION);

        // Exclude vesting contract from tax
        vm.prank(owner);
        token.setTaxExclusion(address(vesting), true);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Constructor_SetsCorrectState() public view {
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.vestingStart(), block.timestamp);
        assertEq(vesting.cliffEnd(), block.timestamp + CLIFF_DURATION);
        assertEq(vesting.vestingEnd(), block.timestamp + VESTING_DURATION);
        assertEq(vesting.totalAllocated(), TOTAL_TEAM_ALLOCATION);
    }

    function test_Constructor_SetsVestingSchedules() public view {
        (uint256 aliceTotal, uint256 aliceVested, uint256 aliceClaimed, uint256 aliceClaimable) = 
            vesting.getVestingInfo(alice);
        assertEq(aliceTotal, ALICE_ALLOCATION);
        assertEq(aliceVested, 0);
        assertEq(aliceClaimed, 0);
        assertEq(aliceClaimable, 0);

        (uint256 bobTotal,,,) = vesting.getVestingInfo(bob);
        assertEq(bobTotal, BOB_ALLOCATION);

        (uint256 carolTotal,,,) = vesting.getVestingInfo(carol);
        assertEq(carolTotal, CAROL_ALLOCATION);
    }

    function test_Constructor_RevertWhen_InvalidToken() public {
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = alice;
        uint256[] memory allocations = new uint256[](1);
        allocations[0] = 1000 * 1e18;

        vm.expectRevert(TeamVesting.InvalidAddress.selector);
        new TeamVesting(IERC20(address(0)), beneficiaries, allocations);
    }

    function test_Constructor_RevertWhen_ArrayLengthMismatch() public {
        address[] memory beneficiaries = new address[](2);
        beneficiaries[0] = alice;
        beneficiaries[1] = bob;
        uint256[] memory allocations = new uint256[](1);
        allocations[0] = 1000 * 1e18;

        vm.expectRevert(TeamVesting.ArrayLengthMismatch.selector);
        new TeamVesting(IERC20(address(token)), beneficiaries, allocations);
    }

    function test_Constructor_RevertWhen_BeneficiaryZeroAddress() public {
        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = address(0);
        uint256[] memory allocations = new uint256[](1);
        allocations[0] = 1000 * 1e18;

        vm.expectRevert(TeamVesting.InvalidAddress.selector);
        new TeamVesting(IERC20(address(token)), beneficiaries, allocations);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VESTING SCHEDULE TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_VestedAmount_ZeroBeforeCliff() public view {
        // At deployment, nothing is vested
        uint256 vested = vesting.vestedAmount(alice);
        assertEq(vested, 0);
    }

    function test_VestedAmount_ZeroDuringCliff() public {
        // Warp to middle of cliff period
        vm.warp(block.timestamp + 15 days);

        uint256 vested = vesting.vestedAmount(alice);
        assertEq(vested, 0);
    }

    function test_VestedAmount_LinearAfterCliff() public {
        // Warp to just after cliff (30 days)
        vm.warp(block.timestamp + CLIFF_DURATION);

        uint256 vested = vesting.vestedAmount(alice);
        // Linear vesting: 30/730 * ALICE_ALLOCATION
        uint256 expected = (ALICE_ALLOCATION * CLIFF_DURATION) / VESTING_DURATION;
        assertEq(vested, expected);
    }

    function test_VestedAmount_HalfwayVested() public {
        // Warp to halfway through vesting (365 days)
        vm.warp(block.timestamp + 365 days);

        uint256 vested = vesting.vestedAmount(alice);
        // Linear vesting: 365/730 * ALICE_ALLOCATION = 50%
        uint256 expected = (ALICE_ALLOCATION * 365 days) / VESTING_DURATION;
        assertEq(vested, expected);
    }

    function test_VestedAmount_FullyVested() public {
        // Warp past vesting end
        vm.warp(block.timestamp + VESTING_DURATION + 1 days);

        uint256 vested = vesting.vestedAmount(alice);
        assertEq(vested, ALICE_ALLOCATION);
    }

    function test_VestedAmount_ExactlyAtVestingEnd() public {
        vm.warp(block.timestamp + VESTING_DURATION);

        uint256 vested = vesting.vestedAmount(alice);
        assertEq(vested, ALICE_ALLOCATION);
    }

    function test_VestedAmount_NonBeneficiary() public {
        address stranger = makeAddr("stranger");
        uint256 vested = vesting.vestedAmount(stranger);
        assertEq(vested, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CLAIMABLE AMOUNT TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_ClaimableAmount_ZeroBeforeCliff() public view {
        uint256 claimable = vesting.claimableAmount(alice);
        assertEq(claimable, 0);
    }

    function test_ClaimableAmount_AfterPartialClaim() public {
        // Warp to 50% vested
        vm.warp(block.timestamp + 365 days);

        // Claim first
        vm.prank(alice);
        vesting.claim();

        // Now claimable should be 0
        uint256 claimable = vesting.claimableAmount(alice);
        assertEq(claimable, 0);

        // Warp more time
        vm.warp(block.timestamp + 100 days);

        // Should have more claimable
        claimable = vesting.claimableAmount(alice);
        uint256 expected = (ALICE_ALLOCATION * 100 days) / VESTING_DURATION;
        assertEq(claimable, expected);
    }

    function test_ClaimableAmount_NonBeneficiary() public {
        address stranger = makeAddr("stranger");
        uint256 claimable = vesting.claimableAmount(stranger);
        assertEq(claimable, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CLAIM TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Claim_Success() public {
        // Warp past cliff
        vm.warp(block.timestamp + 60 days);

        uint256 expectedVested = (ALICE_ALLOCATION * 60 days) / VESTING_DURATION;
        uint256 balanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        uint256 claimed = vesting.claim();

        assertEq(claimed, expectedVested);
        assertEq(token.balanceOf(alice) - balanceBefore, expectedVested);
    }

    function test_Claim_EmitsEvent() public {
        vm.warp(block.timestamp + 60 days);

        uint256 expectedVested = (ALICE_ALLOCATION * 60 days) / VESTING_DURATION;

        vm.expectEmit(true, true, true, true);
        emit TeamVesting.TokensClaimed(alice, expectedVested);

        vm.prank(alice);
        vesting.claim();
    }

    function test_Claim_UpdatesClaimedAmount() public {
        vm.warp(block.timestamp + 60 days);

        vm.prank(alice);
        uint256 claimed = vesting.claim();

        (,, uint256 totalClaimed,) = vesting.getVestingInfo(alice);
        assertEq(totalClaimed, claimed);
    }

    function test_Claim_MultipleClaims() public {
        // First claim at 60 days
        vm.warp(block.timestamp + 60 days);
        vm.prank(alice);
        uint256 firstClaim = vesting.claim();

        // Second claim at 120 days
        vm.warp(block.timestamp + 60 days); // Now at 120 days
        vm.prank(alice);
        uint256 secondClaim = vesting.claim();

        // Both claims should be equal (same time period)
        assertEq(firstClaim, secondClaim);

        (,, uint256 totalClaimed,) = vesting.getVestingInfo(alice);
        assertEq(totalClaimed, firstClaim + secondClaim);
    }

    function test_Claim_FullyVested() public {
        // Warp past vesting end
        vm.warp(block.timestamp + VESTING_DURATION + 30 days);

        uint256 balanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        uint256 claimed = vesting.claim();

        assertEq(claimed, ALICE_ALLOCATION);
        assertEq(token.balanceOf(alice) - balanceBefore, ALICE_ALLOCATION);

        // Try claiming again - should revert
        vm.prank(alice);
        vm.expectRevert(TeamVesting.NothingToClaim.selector);
        vesting.claim();
    }

    function test_Claim_RevertWhen_NoVestingSchedule() public {
        address stranger = makeAddr("stranger");

        vm.prank(stranger);
        vm.expectRevert(TeamVesting.NoVestingSchedule.selector);
        vesting.claim();
    }

    function test_Claim_RevertWhen_NothingToClaim() public {
        // During cliff period
        vm.prank(alice);
        vm.expectRevert(TeamVesting.NothingToClaim.selector);
        vesting.claim();
    }

    function test_Claim_RevertWhen_AlreadyClaimedAll() public {
        // Fully vest and claim
        vm.warp(block.timestamp + VESTING_DURATION);
        vm.prank(alice);
        vesting.claim();

        // Try to claim again
        vm.prank(alice);
        vm.expectRevert(TeamVesting.NothingToClaim.selector);
        vesting.claim();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetVestingInfo() public {
        vm.warp(block.timestamp + 365 days);

        (uint256 total, uint256 vested, uint256 claimed, uint256 claimable) = 
            vesting.getVestingInfo(alice);

        assertEq(total, ALICE_ALLOCATION);
        assertEq(vested, (ALICE_ALLOCATION * 365 days) / VESTING_DURATION);
        assertEq(claimed, 0);
        assertEq(claimable, vested);
    }

    function test_TimeUntilCliff_BeforeCliff() public view {
        uint256 timeUntil = vesting.timeUntilCliff();
        assertEq(timeUntil, CLIFF_DURATION);
    }

    function test_TimeUntilCliff_DuringCliff() public {
        vm.warp(block.timestamp + 15 days);
        uint256 timeUntil = vesting.timeUntilCliff();
        assertEq(timeUntil, 15 days);
    }

    function test_TimeUntilCliff_AfterCliff() public {
        vm.warp(block.timestamp + CLIFF_DURATION + 1 days);
        uint256 timeUntil = vesting.timeUntilCliff();
        assertEq(timeUntil, 0);
    }

    function test_TimeUntilFullyVested_AtStart() public view {
        uint256 timeUntil = vesting.timeUntilFullyVested();
        assertEq(timeUntil, VESTING_DURATION);
    }

    function test_TimeUntilFullyVested_Halfway() public {
        vm.warp(block.timestamp + 365 days);
        uint256 timeUntil = vesting.timeUntilFullyVested();
        assertEq(timeUntil, VESTING_DURATION - 365 days);
    }

    function test_TimeUntilFullyVested_AfterEnd() public {
        vm.warp(block.timestamp + VESTING_DURATION + 30 days);
        uint256 timeUntil = vesting.timeUntilFullyVested();
        assertEq(timeUntil, 0);
    }

    function test_Constants() public view {
        assertEq(vesting.CLIFF_DURATION(), 30 days);
        assertEq(vesting.VESTING_DURATION(), 730 days);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // MULTI-BENEFICIARY TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_MultipleBeneficiaries_IndependentClaims() public {
        vm.warp(block.timestamp + 365 days);

        // Alice claims
        vm.prank(alice);
        uint256 aliceClaimed = vesting.claim();

        // Bob claims
        vm.prank(bob);
        uint256 bobClaimed = vesting.claim();

        // Carol claims
        vm.prank(carol);
        uint256 carolClaimed = vesting.claim();

        // Each should get proportional amount
        assertEq(aliceClaimed, (ALICE_ALLOCATION * 365 days) / VESTING_DURATION);
        assertEq(bobClaimed, (BOB_ALLOCATION * 365 days) / VESTING_DURATION);
        assertEq(carolClaimed, (CAROL_ALLOCATION * 365 days) / VESTING_DURATION);
    }

    function test_MultipleBeneficiaries_FullVesting() public {
        vm.warp(block.timestamp + VESTING_DURATION);

        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);
        uint256 carolBalanceBefore = token.balanceOf(carol);

        vm.prank(alice);
        vesting.claim();

        vm.prank(bob);
        vesting.claim();

        vm.prank(carol);
        vesting.claim();

        assertEq(token.balanceOf(alice) - aliceBalanceBefore, ALICE_ALLOCATION);
        assertEq(token.balanceOf(bob) - bobBalanceBefore, BOB_ALLOCATION);
        assertEq(token.balanceOf(carol) - carolBalanceBefore, CAROL_ALLOCATION);

        // Vesting contract should be empty
        assertEq(token.balanceOf(address(vesting)), 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function testFuzz_VestedAmount_LinearProgression(uint256 timeElapsed) public {
        vm.assume(timeElapsed <= VESTING_DURATION * 2); // Cap at 2x vesting duration

        vm.warp(block.timestamp + timeElapsed);

        uint256 vested = vesting.vestedAmount(alice);

        if (timeElapsed < CLIFF_DURATION) {
            assertEq(vested, 0);
        } else if (timeElapsed >= VESTING_DURATION) {
            assertEq(vested, ALICE_ALLOCATION);
        } else {
            uint256 expected = (ALICE_ALLOCATION * timeElapsed) / VESTING_DURATION;
            assertEq(vested, expected);
        }
    }

    function testFuzz_ClaimableAmount_NeverExceedsTotal(uint256 timeElapsed) public {
        vm.assume(timeElapsed <= VESTING_DURATION * 2);

        vm.warp(block.timestamp + timeElapsed);

        uint256 claimable = vesting.claimableAmount(alice);
        assertLe(claimable, ALICE_ALLOCATION);
    }

    function testFuzz_Claim_TotalClaimedNeverExceedsAllocation(uint256 numClaims, uint256 timeBetween) public {
        numClaims = bound(numClaims, 1, 10);
        timeBetween = bound(timeBetween, 1 days, 100 days);

        // Start after cliff
        vm.warp(block.timestamp + CLIFF_DURATION);

        uint256 totalClaimed = 0;

        for (uint256 i = 0; i < numClaims; i++) {
            vm.warp(block.timestamp + timeBetween);

            uint256 claimable = vesting.claimableAmount(alice);
            if (claimable > 0) {
                vm.prank(alice);
                uint256 claimed = vesting.claim();
                totalClaimed += claimed;
            }
        }

        assertLe(totalClaimed, ALICE_ALLOCATION);
    }
}
