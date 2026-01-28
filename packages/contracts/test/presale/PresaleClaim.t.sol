// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import { PresaleClaim } from "../../src/presale/PresaleClaim.sol";
import { IPresaleClaim } from "../../src/presale/interfaces/IPresaleClaim.sol";
import { IGhostPresale } from "../../src/presale/interfaces/IGhostPresale.sol";
import { GhostPresale } from "../../src/presale/GhostPresale.sol";
import { MockERC20 } from "../../src/mocks/MockERC20.sol";
import { DataToken } from "../../src/token/DataToken.sol";

contract PresaleClaimTest is Test {
    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    uint256 constant TRANCHE_1_SUPPLY = 5_000_000 * 1e18;
    uint256 constant TRANCHE_2_SUPPLY = 5_000_000 * 1e18;
    uint256 constant TRANCHE_3_SUPPLY = 5_000_000 * 1e18;
    uint256 constant TOTAL_PRESALE = 15_000_000 * 1e18;

    uint256 constant TRANCHE_1_PRICE = 0.00001 ether; // per 1e18 token
    uint256 constant TRANCHE_2_PRICE = 0.00002 ether;
    uint256 constant TRANCHE_3_PRICE = 0.00003 ether;

    uint256 constant CLAIM_DEADLINE = 180 days;

    // ══════════════════════════════════════════════════════════════════════════════
    // ACTORS
    // ══════════════════════════════════════════════════════════════════════════════

    address owner = makeAddr("owner");
    address treasury = makeAddr("treasury");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address nobody = makeAddr("nobody");

    // ══════════════════════════════════════════════════════════════════════════════
    // CONTRACTS
    // ══════════════════════════════════════════════════════════════════════════════

    MockERC20 token;
    GhostPresale presale;
    PresaleClaim claim;

    // ══════════════════════════════════════════════════════════════════════════════
    // SETUP
    // ══════════════════════════════════════════════════════════════════════════════

    function setUp() public {
        // 1. Deploy mock token (mints 1B to this test contract)
        token = new MockERC20("GHOSTNET Data", "DATA");

        // 2. Deploy and configure presale
        vm.startPrank(owner);
        presale = new GhostPresale(GhostPresale.PricingMode.TRANCHE, owner);

        presale.setConfig(
            GhostPresale.PresaleConfig({
                minContribution: 0.001 ether,
                maxContribution: 100 ether,
                maxPerWallet: 100 ether,
                allowMultipleContributions: true,
                startTime: 0,
                endTime: 0,
                emergencyDeadline: 30 days
            })
        );

        presale.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);
        presale.addTranche(TRANCHE_2_SUPPLY, TRANCHE_2_PRICE);
        presale.addTranche(TRANCHE_3_SUPPLY, TRANCHE_3_PRICE);

        presale.open();
        vm.stopPrank();

        // 3. Users contribute ETH to create allocations
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);

        vm.prank(bob);
        presale.contribute{ value: 0.5 ether }(0);

        vm.prank(charlie);
        presale.contribute{ value: 0.1 ether }(0);

        // 4. Finalize presale
        vm.prank(owner);
        presale.finalize();

        // 5. Deploy claim contract
        vm.prank(owner);
        claim = new PresaleClaim(
            IERC20(address(token)),
            IGhostPresale(address(presale)),
            block.timestamp + CLAIM_DEADLINE,
            owner
        );

        // 6. Fund claim contract with enough tokens (from test contract which holds 1B)
        token.transfer(address(claim), presale.totalSold());
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════════════════════

    function _enableClaiming() internal {
        vm.prank(owner);
        claim.enableClaiming();
    }

    function _aliceAllocation() internal view returns (uint256) {
        return presale.allocations(alice);
    }

    function _bobAllocation() internal view returns (uint256) {
        return presale.allocations(bob);
    }

    function _charlieAllocation() internal view returns (uint256) {
        return presale.allocations(charlie);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 1. CONSTRUCTION
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Constructor_SetsImmutables() public view {
        assertEq(address(claim.dataToken()), address(token));
        assertEq(address(claim.presale()), address(presale));
        assertGt(claim.claimDeadline(), block.timestamp);
        assertFalse(claim.claimingEnabled());
        assertFalse(claim.recovered());
        assertEq(claim.totalClaimed(), 0);
    }

    function test_Constructor_RevertWhen_ZeroTokenAddress() public {
        vm.expectRevert(IPresaleClaim.InvalidAddress.selector);
        new PresaleClaim(
            IERC20(address(0)),
            IGhostPresale(address(presale)),
            block.timestamp + CLAIM_DEADLINE,
            owner
        );
    }

    function test_Constructor_RevertWhen_ZeroPresaleAddress() public {
        vm.expectRevert(IPresaleClaim.InvalidAddress.selector);
        new PresaleClaim(
            IERC20(address(token)),
            IGhostPresale(address(0)),
            block.timestamp + CLAIM_DEADLINE,
            owner
        );
    }

    function test_Constructor_RevertWhen_DeadlinePast() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IPresaleClaim.ClaimDeadlineNotReached.selector,
                block.timestamp,
                block.timestamp - 1
            )
        );
        new PresaleClaim(
            IERC20(address(token)),
            IGhostPresale(address(presale)),
            block.timestamp - 1,
            owner
        );
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 2. ENABLE CLAIMING
    // ══════════════════════════════════════════════════════════════════════════════

    function test_EnableClaiming_Works() public {
        _enableClaiming();
        assertTrue(claim.claimingEnabled());
    }

    function test_EnableClaiming_RevertWhen_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        claim.enableClaiming();
    }

    function test_EnableClaiming_RevertWhen_InsufficientBalance() public {
        // Deploy a new claim with no funding
        PresaleClaim unfunded = new PresaleClaim(
            IERC20(address(token)),
            IGhostPresale(address(presale)),
            block.timestamp + CLAIM_DEADLINE,
            owner
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IPresaleClaim.InsufficientBalance.selector,
                0,
                presale.totalSold()
            )
        );
        vm.prank(owner);
        unfunded.enableClaiming();
    }

    function test_EnableClaiming_RevertWhen_AlreadyEnabled() public {
        _enableClaiming();

        vm.prank(owner);
        vm.expectRevert(IPresaleClaim.AlreadyEnabled.selector);
        claim.enableClaiming();
    }

    function test_EnableClaiming_EmitsEvent() public {
        uint256 balance = token.balanceOf(address(claim));

        vm.expectEmit(true, true, true, true);
        emit IPresaleClaim.ClaimingEnabled(balance);

        vm.prank(owner);
        claim.enableClaiming();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 3. CLAIMING
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Claim_TransfersCorrectAmount() public {
        _enableClaiming();

        uint256 expected = _aliceAllocation();
        assertGt(expected, 0);

        vm.prank(alice);
        uint256 amount = claim.claim();

        assertEq(amount, expected);
        assertEq(token.balanceOf(alice), expected);
    }

    function test_Claim_SetsClaimedTrue() public {
        _enableClaiming();

        assertFalse(claim.claimed(alice));

        vm.prank(alice);
        claim.claim();

        assertTrue(claim.claimed(alice));
    }

    function test_Claim_IncrementsTotalClaimed() public {
        _enableClaiming();

        uint256 aliceAmt = _aliceAllocation();

        vm.prank(alice);
        claim.claim();

        assertEq(claim.totalClaimed(), aliceAmt);

        uint256 bobAmt = _bobAllocation();

        vm.prank(bob);
        claim.claim();

        assertEq(claim.totalClaimed(), aliceAmt + bobAmt);
    }

    function test_Claim_EmitsClaimed() public {
        _enableClaiming();

        uint256 expected = _aliceAllocation();

        vm.expectEmit(true, true, true, true);
        emit IPresaleClaim.Claimed(alice, expected);

        vm.prank(alice);
        claim.claim();
    }

    function test_Claim_RevertWhen_NotEnabled() public {
        vm.prank(alice);
        vm.expectRevert(IPresaleClaim.ClaimingNotEnabled.selector);
        claim.claim();
    }

    function test_Claim_RevertWhen_AlreadyClaimed() public {
        _enableClaiming();

        vm.prank(alice);
        claim.claim();

        vm.prank(alice);
        vm.expectRevert(IPresaleClaim.AlreadyClaimed.selector);
        claim.claim();
    }

    function test_Claim_RevertWhen_NoAllocation() public {
        _enableClaiming();

        vm.prank(nobody);
        vm.expectRevert(IPresaleClaim.NoAllocation.selector);
        claim.claim();
    }

    function test_Claim_RevertWhen_Paused() public {
        _enableClaiming();

        vm.prank(owner);
        claim.pause();

        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        claim.claim();
    }

    function test_Claim_RevertWhen_Recovered() public {
        _enableClaiming();

        // Warp past deadline and recover
        vm.warp(claim.claimDeadline() + 1);
        vm.prank(owner);
        claim.recoverUnclaimed(treasury);

        vm.prank(alice);
        vm.expectRevert(IPresaleClaim.ClaimingClosed.selector);
        claim.claim();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 4. CLAIMABLE VIEW
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Claimable_ReturnsAllocation() public {
        _enableClaiming();

        uint256 expected = _aliceAllocation();
        assertEq(claim.claimable(alice), expected);
        assertGt(expected, 0);
    }

    function test_Claimable_ReturnsZeroWhenNotEnabled() public view {
        assertEq(claim.claimable(alice), 0);
    }

    function test_Claimable_ReturnsZeroWhenClaimed() public {
        _enableClaiming();

        vm.prank(alice);
        claim.claim();

        assertEq(claim.claimable(alice), 0);
    }

    function test_Claimable_ReturnsZeroWhenRecovered() public {
        _enableClaiming();

        vm.warp(claim.claimDeadline() + 1);
        vm.prank(owner);
        claim.recoverUnclaimed(treasury);

        assertEq(claim.claimable(alice), 0);
    }

    function test_Claimable_FallsBackToSnapshot() public {
        // Snapshot alice's allocation
        address[] memory accounts = new address[](1);
        accounts[0] = alice;

        vm.prank(owner);
        claim.snapshotAllocations(accounts);

        uint256 snapshotValue = claim.snapshotted(alice);
        assertGt(snapshotValue, 0);

        // Deploy a new presale that returns 0 for alice (simulates presale upgrade/reset)
        // We can't easily zero out the presale allocation, so instead we test with a fresh
        // claim contract pointing to an empty presale
        vm.startPrank(owner);
        GhostPresale emptyPresale = new GhostPresale(GhostPresale.PricingMode.TRANCHE, owner);
        emptyPresale.setConfig(GhostPresale.PresaleConfig({
            minContribution: 0,
            maxContribution: 0,
            maxPerWallet: 0,
            allowMultipleContributions: false,
            startTime: 0,
            endTime: 0,
            emergencyDeadline: 30 days
        }));
        emptyPresale.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);
        emptyPresale.open();
        emptyPresale.finalize();

        PresaleClaim snapshotClaim = new PresaleClaim(
            IERC20(address(token)),
            IGhostPresale(address(emptyPresale)),
            block.timestamp + CLAIM_DEADLINE,
            owner
        );

        // Snapshot into the new claim
        snapshotClaim.snapshotAllocations(accounts);
        vm.stopPrank();

        // The snapshot on snapshotClaim reads from emptyPresale (which returns 0 for alice)
        // So snapshotted[alice] = 0 too. We need a different approach.
        // Instead: manually verify fallback by snapshotting from the real presale first,
        // then using a claim that points to an empty presale but has snapshot data.

        // Better approach: test that claimable falls back to snapshot when presale returns 0
        // We'll set up a mock presale for this
        MockPresale mockPresale = new MockPresale();

        vm.startPrank(owner);
        PresaleClaim fallbackClaim = new PresaleClaim(
            IERC20(address(token)),
            IGhostPresale(address(mockPresale)),
            block.timestamp + CLAIM_DEADLINE,
            owner
        );

        vm.stopPrank();

        // Set mockPresale to return allocation for alice
        mockPresale.setAllocation(alice, 500_000 * 1e18);
        mockPresale.setTotalSold(500_000 * 1e18);

        // Fund it (from test contract)
        token.transfer(address(fallbackClaim), 1_000_000 * 1e18);

        vm.startPrank(owner);
        // Snapshot
        fallbackClaim.snapshotAllocations(accounts);
        assertEq(fallbackClaim.snapshotted(alice), 500_000 * 1e18);

        // Now zero out the presale allocation
        vm.stopPrank();
        mockPresale.setAllocation(alice, 0);

        // Enable claiming
        vm.prank(owner);
        fallbackClaim.enableClaiming();

        // claimable should fall back to snapshot
        assertEq(fallbackClaim.claimable(alice), 500_000 * 1e18);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 5. SNAPSHOT
    // ══════════════════════════════════════════════════════════════════════════════

    function test_SnapshotAllocations_CopiesValues() public {
        address[] memory accounts = new address[](3);
        accounts[0] = alice;
        accounts[1] = bob;
        accounts[2] = charlie;

        vm.prank(owner);
        claim.snapshotAllocations(accounts);

        assertEq(claim.snapshotted(alice), _aliceAllocation());
        assertEq(claim.snapshotted(bob), _bobAllocation());
        assertEq(claim.snapshotted(charlie), _charlieAllocation());
    }

    function test_SnapshotAllocations_RevertWhen_NotOwner() public {
        address[] memory accounts = new address[](1);
        accounts[0] = alice;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        claim.snapshotAllocations(accounts);
    }

    function test_SnapshotAllocations_EmitsEvent() public {
        address[] memory accounts = new address[](2);
        accounts[0] = alice;
        accounts[1] = bob;

        vm.expectEmit(true, true, true, true);
        emit IPresaleClaim.AllocationsSnapshotted(2);

        vm.prank(owner);
        claim.snapshotAllocations(accounts);
    }

    function test_Claim_UsesSnapshotFallback() public {
        // Use mock presale so we can zero out allocations after snapshot
        MockPresale mockPresale = new MockPresale();
        uint256 aliceAmt = 100_000 * 1e18;
        mockPresale.setAllocation(alice, aliceAmt);
        mockPresale.setTotalSold(aliceAmt);

        vm.prank(owner);
        PresaleClaim fallbackClaim = new PresaleClaim(
            IERC20(address(token)),
            IGhostPresale(address(mockPresale)),
            block.timestamp + CLAIM_DEADLINE,
            owner
        );

        // Fund from test contract
        token.transfer(address(fallbackClaim), aliceAmt);

        // Snapshot while presale has allocation
        address[] memory accounts = new address[](1);
        accounts[0] = alice;

        vm.prank(owner);
        fallbackClaim.snapshotAllocations(accounts);

        // Zero out presale
        mockPresale.setAllocation(alice, 0);

        // Enable and claim
        vm.prank(owner);
        fallbackClaim.enableClaiming();

        vm.prank(alice);
        uint256 received = fallbackClaim.claim();

        assertEq(received, aliceAmt);
        assertEq(token.balanceOf(alice), aliceAmt);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 6. RECOVERY
    // ══════════════════════════════════════════════════════════════════════════════

    function test_RecoverUnclaimed_TransfersTokens() public {
        _enableClaiming();

        // Alice claims, bob and charlie don't
        vm.prank(alice);
        claim.claim();

        uint256 remaining = token.balanceOf(address(claim));
        assertGt(remaining, 0);

        vm.warp(claim.claimDeadline() + 1);

        vm.prank(owner);
        claim.recoverUnclaimed(treasury);

        assertEq(token.balanceOf(address(claim)), 0);
        assertEq(token.balanceOf(treasury), remaining);
    }

    function test_RecoverUnclaimed_SetsRecovered() public {
        _enableClaiming();

        vm.warp(claim.claimDeadline() + 1);

        vm.prank(owner);
        claim.recoverUnclaimed(treasury);

        assertTrue(claim.recovered());
    }

    function test_RecoverUnclaimed_DisablesClaims() public {
        _enableClaiming();

        vm.warp(claim.claimDeadline() + 1);

        vm.prank(owner);
        claim.recoverUnclaimed(treasury);

        vm.prank(alice);
        vm.expectRevert(IPresaleClaim.ClaimingClosed.selector);
        claim.claim();
    }

    function test_RecoverUnclaimed_RevertWhen_BeforeDeadline() public {
        _enableClaiming();

        vm.expectRevert(
            abi.encodeWithSelector(
                IPresaleClaim.ClaimDeadlineNotReached.selector,
                block.timestamp,
                claim.claimDeadline()
            )
        );
        vm.prank(owner);
        claim.recoverUnclaimed(treasury);
    }

    function test_RecoverUnclaimed_RevertWhen_NotOwner() public {
        vm.warp(claim.claimDeadline() + 1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        claim.recoverUnclaimed(treasury);
    }

    function test_RecoverUnclaimed_RevertWhen_ZeroAddress() public {
        vm.warp(claim.claimDeadline() + 1);

        vm.prank(owner);
        vm.expectRevert(IPresaleClaim.InvalidAddress.selector);
        claim.recoverUnclaimed(address(0));
    }

    function test_RecoverUnclaimed_EmitsEvent() public {
        _enableClaiming();

        uint256 balance = token.balanceOf(address(claim));

        vm.warp(claim.claimDeadline() + 1);

        vm.expectEmit(true, true, true, true);
        emit IPresaleClaim.UnclaimedRecovered(treasury, balance);

        vm.prank(owner);
        claim.recoverUnclaimed(treasury);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 7. PAUSE
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Pause_BlocksClaims() public {
        _enableClaiming();

        vm.prank(owner);
        claim.pause();

        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        claim.claim();
    }

    function test_Unpause_AllowsClaims() public {
        _enableClaiming();

        vm.prank(owner);
        claim.pause();

        vm.prank(owner);
        claim.unpause();

        vm.prank(alice);
        uint256 amount = claim.claim();
        assertGt(amount, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 8. INTEGRATION (Real DataToken)
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Integration_ClaimWithRealDataToken() public {
        // Deploy real DataToken with claim contract as a recipient
        // We need to know the claim address before deploying DataToken,
        // so we use CREATE2 or pre-compute. Simpler: deploy claim first with mock,
        // then deploy DataToken distributing to the claim address.

        // Step 1: Deploy presale (already done in setUp — reuse allocations)
        // Step 2: Pre-compute claim address using a deterministic approach
        //         Simpler: deploy claim, then deploy DataToken sending tokens to claim.

        // Deploy DataToken distributing to various addresses
        uint256 presaleAmount = presale.totalSold();
        uint256 remainingAmount = 100_000_000 * 1e18 - presaleAmount;

        address[] memory recipients = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        recipients[0] = owner; // will hold remaining
        amounts[0] = remainingAmount;
        recipients[1] = owner; // all to owner, we'll transfer to claim
        amounts[1] = presaleAmount;

        // Actually recipients[0] and [1] are same address — that's fine, amounts just both go to owner
        // Simpler: single recipient
        recipients = new address[](1);
        amounts = new uint256[](1);
        recipients[0] = owner;
        amounts[0] = 100_000_000 * 1e18;

        vm.prank(owner);
        DataToken dataToken = new DataToken(treasury, owner, recipients, amounts);

        // Deploy real claim with correct token address
        vm.prank(owner);
        PresaleClaim integrationClaim = new PresaleClaim(
            IERC20(address(dataToken)),
            IGhostPresale(address(presale)),
            block.timestamp + CLAIM_DEADLINE,
            owner
        );

        // Fund claim and set tax exclusion
        vm.startPrank(owner);
        dataToken.setTaxExclusion(address(integrationClaim), true);
        dataToken.transfer(address(integrationClaim), presaleAmount);
        integrationClaim.enableClaiming();
        vm.stopPrank();

        // Alice claims — should get exact amount (no tax)
        uint256 aliceExpected = presale.allocations(alice);
        vm.prank(alice);
        uint256 received = integrationClaim.claim();

        assertEq(received, aliceExpected);
        assertEq(dataToken.balanceOf(alice), aliceExpected);
    }

    function test_Integration_ClaimWithoutTaxExclusion_LosesTokens() public {
        // Same setup but WITHOUT tax exclusion — alice receives less due to 10% tax
        address[] memory recipients = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        recipients[0] = owner;
        amounts[0] = 100_000_000 * 1e18;

        vm.prank(owner);
        DataToken dataToken = new DataToken(treasury, owner, recipients, amounts);

        vm.prank(owner);
        PresaleClaim taxedClaim = new PresaleClaim(
            IERC20(address(dataToken)),
            IGhostPresale(address(presale)),
            block.timestamp + CLAIM_DEADLINE,
            owner
        );

        // Fund WITHOUT setting tax exclusion on the claim contract
        // But owner IS excluded from tax (treasury is, but owner isn't by default)
        // We need owner to be tax-excluded to transfer without loss
        vm.startPrank(owner);
        dataToken.setTaxExclusion(owner, true);
        dataToken.transfer(address(taxedClaim), presale.totalSold());
        // DO NOT set tax exclusion for taxedClaim
        taxedClaim.enableClaiming();
        vm.stopPrank();

        uint256 aliceExpected = presale.allocations(alice);

        vm.prank(alice);
        taxedClaim.claim();

        // Alice receives 90% due to 10% tax (claim contract is sender, alice is receiver,
        // neither is excluded)
        uint256 aliceBalance = dataToken.balanceOf(alice);
        uint256 expectedAfterTax = aliceExpected * 9000 / 10_000;
        assertEq(aliceBalance, expectedAfterTax);
        assertLt(aliceBalance, aliceExpected);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 9. MULTIPLE USERS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_MultipleClaims_AllUsersReceiveCorrectAmounts() public {
        _enableClaiming();

        uint256 aliceExpected = _aliceAllocation();
        uint256 bobExpected = _bobAllocation();
        uint256 charlieExpected = _charlieAllocation();

        vm.prank(alice);
        assertEq(claim.claim(), aliceExpected);

        vm.prank(bob);
        assertEq(claim.claim(), bobExpected);

        vm.prank(charlie);
        assertEq(claim.claim(), charlieExpected);

        assertEq(token.balanceOf(alice), aliceExpected);
        assertEq(token.balanceOf(bob), bobExpected);
        assertEq(token.balanceOf(charlie), charlieExpected);

        assertEq(claim.totalClaimed(), aliceExpected + bobExpected + charlieExpected);

        assertTrue(claim.claimed(alice));
        assertTrue(claim.claimed(bob));
        assertTrue(claim.claimed(charlie));
    }
    // ══════════════════════════════════════════════════════════════════════════════
    // 10. M-3: SNAPSHOT AFTER CLAIMING ENABLED
    // ══════════════════════════════════════════════════════════════════════════════

    function test_SnapshotAllocations_RevertWhen_ClaimingEnabled() public {
        _enableClaiming();

        address[] memory accounts = new address[](1);
        accounts[0] = alice;

        vm.prank(owner);
        vm.expectRevert(IPresaleClaim.AlreadyEnabled.selector);
        claim.snapshotAllocations(accounts);
    }
}

// ══════════════════════════════════════════════════════════════════════════════════
// MOCK PRESALE — minimal mock for snapshot fallback tests
// ══════════════════════════════════════════════════════════════════════════════════

contract MockPresale is IGhostPresale {
    mapping(address => uint256) private _allocations;
    uint256 private _totalSold;

    function allocations(address account) external view override returns (uint256) {
        return _allocations[account];
    }

    function totalSold() external view override returns (uint256) {
        return _totalSold;
    }

    function setAllocation(address account, uint256 amount) external {
        _allocations[account] = amount;
    }

    function setTotalSold(uint256 amount) external {
        _totalSold = amount;
    }
}
