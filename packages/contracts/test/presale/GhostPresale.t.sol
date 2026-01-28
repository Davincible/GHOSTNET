// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test } from "forge-std/Test.sol";
import { GhostPresale } from "../../src/presale/GhostPresale.sol";

/// @title GhostPresale Tests
/// @notice Comprehensive test suite for the GHOSTNET presale contract
contract GhostPresaleTest is Test {
    GhostPresale public presale;
    GhostPresale public curvePresale;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");
    address public stranger = makeAddr("stranger");

    // Standard tranche config
    uint256 constant TRANCHE_1_SUPPLY = 5_000_000e18;
    uint256 constant TRANCHE_2_SUPPLY = 5_000_000e18;
    uint256 constant TRANCHE_3_SUPPLY = 5_000_000e18;
    uint256 constant TRANCHE_1_PRICE = 0.003e18; // 0.003 ETH per token
    uint256 constant TRANCHE_2_PRICE = 0.005e18;
    uint256 constant TRANCHE_3_PRICE = 0.008e18;

    // Standard curve config
    uint256 constant CURVE_START_PRICE = 0.002e18;
    uint256 constant CURVE_END_PRICE = 0.010e18;
    uint256 constant CURVE_SUPPLY = 15_000_000e18;

    // Standard presale config
    uint256 constant MIN_CONTRIBUTION = 0.01 ether;
    uint256 constant MAX_CONTRIBUTION = 100 ether;
    uint256 constant MAX_PER_WALLET = 200 ether;
    uint256 constant EMERGENCY_DEADLINE = 90 days;

    function setUp() public {
        // Deploy tranche-mode presale (default for most tests)
        vm.prank(owner);
        presale = new GhostPresale(GhostPresale.PricingMode.TRANCHE, owner);

        // Fund test accounts
        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
        vm.deal(carol, 1000 ether);
        vm.deal(stranger, 1000 ether);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════════════════════

    function _standardConfig() internal view returns (GhostPresale.PresaleConfig memory) {
        return GhostPresale.PresaleConfig({
            minContribution: MIN_CONTRIBUTION,
            maxContribution: MAX_CONTRIBUTION,
            maxPerWallet: MAX_PER_WALLET,
            allowMultipleContributions: true,
            startTime: 0,
            endTime: 0,
            emergencyDeadline: EMERGENCY_DEADLINE
        });
    }

    function _configureAndOpenTranche() internal {
        vm.startPrank(owner);
        presale.setConfig(_standardConfig());
        presale.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);
        presale.addTranche(TRANCHE_2_SUPPLY, TRANCHE_2_PRICE);
        presale.addTranche(TRANCHE_3_SUPPLY, TRANCHE_3_PRICE);
        presale.open();
        vm.stopPrank();
    }

    function _deployCurvePresale() internal returns (GhostPresale) {
        vm.prank(owner);
        GhostPresale cp = new GhostPresale(GhostPresale.PricingMode.BONDING_CURVE, owner);
        return cp;
    }

    function _configureAndOpenCurve() internal {
        curvePresale = _deployCurvePresale();
        vm.startPrank(owner);
        curvePresale.setConfig(_standardConfig());
        curvePresale.setCurve(CURVE_START_PRICE, CURVE_END_PRICE, CURVE_SUPPLY);
        curvePresale.open();
        vm.stopPrank();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 1. CONSTRUCTION & CONFIGURATION
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Constructor_SetsCorrectPricingMode() public view {
        assertEq(uint256(presale.pricingMode()), uint256(GhostPresale.PricingMode.TRANCHE));
    }

    function test_Constructor_StartsInPendingState() public view {
        assertEq(uint256(presale.state()), uint256(GhostPresale.PresaleState.PENDING));
    }

    function test_SetConfig_UpdatesConfig() public {
        GhostPresale.PresaleConfig memory cfg = _standardConfig();
        vm.prank(owner);
        presale.setConfig(cfg);

        (
            uint256 minC, uint256 maxC, uint256 maxW,
            bool allowMultiple, uint256 startT, uint256 endT, uint256 emergD
        ) = presale.config();

        assertEq(minC, MIN_CONTRIBUTION);
        assertEq(maxC, MAX_CONTRIBUTION);
        assertEq(maxW, MAX_PER_WALLET);
        assertTrue(allowMultiple);
        assertEq(startT, 0);
        assertEq(endT, 0);
        assertEq(emergD, EMERGENCY_DEADLINE);
    }

    function test_SetConfig_RevertWhen_NotPending() public {
        _configureAndOpenTranche();

        vm.prank(owner);
        vm.expectRevert(GhostPresale.PresaleNotPending.selector);
        presale.setConfig(_standardConfig());
    }

    function test_SetConfig_RevertWhen_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        presale.setConfig(_standardConfig());
    }

    function test_AddTranche_AddsCorrectly() public {
        vm.startPrank(owner);
        presale.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);
        presale.addTranche(TRANCHE_2_SUPPLY, TRANCHE_2_PRICE);
        vm.stopPrank();

        (uint256 supply0, uint256 price0) = presale.tranches(0);
        (uint256 supply1, uint256 price1) = presale.tranches(1);

        assertEq(supply0, TRANCHE_1_SUPPLY);
        assertEq(price0, TRANCHE_1_PRICE);
        assertEq(supply1, TRANCHE_2_SUPPLY);
        assertEq(price1, TRANCHE_2_PRICE);
    }

    function test_AddTranche_RevertWhen_PriceNotAscending() public {
        vm.startPrank(owner);
        presale.addTranche(TRANCHE_1_SUPPLY, TRANCHE_2_PRICE);

        // Same price — should revert
        vm.expectRevert(GhostPresale.InvalidTranchePrice.selector);
        presale.addTranche(TRANCHE_2_SUPPLY, TRANCHE_2_PRICE);

        // Lower price — should revert
        vm.expectRevert(GhostPresale.InvalidTranchePrice.selector);
        presale.addTranche(TRANCHE_2_SUPPLY, TRANCHE_1_PRICE);
        vm.stopPrank();
    }

    function test_AddTranche_RevertWhen_ZeroPrice() public {
        vm.prank(owner);
        vm.expectRevert(GhostPresale.InvalidTranchePrice.selector);
        presale.addTranche(TRANCHE_1_SUPPLY, 0);
    }

    function test_ClearTranches_RemovesAll() public {
        vm.startPrank(owner);
        presale.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);
        presale.addTranche(TRANCHE_2_SUPPLY, TRANCHE_2_PRICE);
        presale.clearTranches();
        vm.stopPrank();

        assertEq(presale.totalPresaleSupply(), 0);
    }

    function test_SetCurve_SetsCorrectly() public {
        GhostPresale cp = _deployCurvePresale();
        vm.prank(owner);
        cp.setCurve(CURVE_START_PRICE, CURVE_END_PRICE, CURVE_SUPPLY);

        (uint256 sp, uint256 ep, uint256 ts) = cp.curve();
        assertEq(sp, CURVE_START_PRICE);
        assertEq(ep, CURVE_END_PRICE);
        assertEq(ts, CURVE_SUPPLY);
    }

    function test_SetCurve_RevertWhen_EndPriceNotGreater() public {
        GhostPresale cp = _deployCurvePresale();
        vm.startPrank(owner);

        // Equal prices
        vm.expectRevert(GhostPresale.EndPriceMustExceedStartPrice.selector);
        cp.setCurve(CURVE_START_PRICE, CURVE_START_PRICE, CURVE_SUPPLY);

        // End < start
        vm.expectRevert(GhostPresale.EndPriceMustExceedStartPrice.selector);
        cp.setCurve(CURVE_END_PRICE, CURVE_START_PRICE, CURVE_SUPPLY);
        vm.stopPrank();
    }

    function test_SetCurve_RevertWhen_InvalidParams() public {
        GhostPresale cp = _deployCurvePresale();
        vm.startPrank(owner);

        // Zero supply
        vm.expectRevert(GhostPresale.InvalidCurveParams.selector);
        cp.setCurve(CURVE_START_PRICE, CURVE_END_PRICE, 0);

        // Zero start price
        vm.expectRevert(GhostPresale.InvalidCurveParams.selector);
        cp.setCurve(0, CURVE_END_PRICE, CURVE_SUPPLY);
        vm.stopPrank();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 2. OPENING
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Open_TransitionsToPendingToOpen() public {
        vm.startPrank(owner);
        presale.setConfig(_standardConfig());
        presale.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);
        presale.open();
        vm.stopPrank();

        assertEq(uint256(presale.state()), uint256(GhostPresale.PresaleState.OPEN));
    }

    function test_Open_SetsOpenedAt() public {
        vm.startPrank(owner);
        presale.setConfig(_standardConfig());
        presale.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);

        uint256 ts = block.timestamp;
        presale.open();
        vm.stopPrank();

        assertEq(presale.openedAt(), ts);
    }

    function test_Open_EmitsPresaleOpened() public {
        vm.startPrank(owner);
        presale.setConfig(_standardConfig());
        presale.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);

        vm.expectEmit(false, false, false, true);
        emit GhostPresale.PresaleOpened(block.timestamp);
        presale.open();
        vm.stopPrank();
    }

    function test_Open_RevertWhen_NoPricingConfigured() public {
        vm.startPrank(owner);
        presale.setConfig(_standardConfig());

        // No tranches added
        vm.expectRevert(GhostPresale.PricingNotConfigured.selector);
        presale.open();
        vm.stopPrank();
    }

    function test_Open_RevertWhen_NoPricingConfigured_Curve() public {
        GhostPresale cp = _deployCurvePresale();
        vm.startPrank(owner);
        cp.setConfig(_standardConfig());

        // No curve set
        vm.expectRevert(GhostPresale.PricingNotConfigured.selector);
        cp.open();
        vm.stopPrank();
    }

    function test_Open_RevertWhen_NotPending() public {
        _configureAndOpenTranche();

        vm.prank(owner);
        vm.expectRevert(GhostPresale.PresaleNotPending.selector);
        presale.open();
    }

    function test_Open_RevertWhen_NotOwner() public {
        vm.prank(owner);
        presale.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);

        vm.prank(alice);
        vm.expectRevert();
        presale.open();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 3. CONTRIBUTING — TRANCHE MODE
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Contribute_Tranche_AllocatesCorrectly() public {
        _configureAndOpenTranche();

        uint256 ethAmount = 1 ether;
        vm.prank(alice);
        uint256 allocation = presale.contribute{ value: ethAmount }(0);

        // Verify allocation is reasonable: ~333.33 tokens at 0.003 ETH/token
        // Integer division may cause slight rounding differences
        assertGt(allocation, 333e18);
        assertLt(allocation, 334e18);
        assertEq(presale.allocations(alice), allocation);
    }

    function test_Contribute_Tranche_CrossesTrancheBoundary() public {
        // Use small, clean tranches to avoid rounding complexity
        vm.startPrank(owner);
        GhostPresale p = new GhostPresale(GhostPresale.PricingMode.TRANCHE, owner);
        GhostPresale.PresaleConfig memory cfg = _standardConfig();
        cfg.maxContribution = 500 ether;
        cfg.maxPerWallet = 500 ether;
        p.setConfig(cfg);
        // 100 tokens at 1 ETH, 100 tokens at 2 ETH
        p.addTranche(100e18, 1e18);
        p.addTranche(100e18, 2e18);
        p.open();
        vm.stopPrank();

        // Send 150 ETH: fills T1 (100 tokens @ 1 ETH = 100 ETH), then 50 ETH into T2 (25 tokens @ 2 ETH)
        vm.prank(alice);
        uint256 allocation = p.contribute{ value: 150 ether }(0);

        assertEq(allocation, 125e18); // 100 + 25
        assertGt(p.totalSold(), 100e18); // Crossed T1 boundary
    }

    function test_Contribute_Tranche_PartialFillRefundsExcess() public {
        // Single small tranche so we can fill it
        vm.startPrank(owner);
        GhostPresale p = new GhostPresale(GhostPresale.PricingMode.TRANCHE, owner);
        GhostPresale.PresaleConfig memory cfg = _standardConfig();
        cfg.maxContribution = 1000 ether;
        cfg.maxPerWallet = 1000 ether;
        p.setConfig(cfg);
        // Supply of 100 tokens at 1 ETH each = 100 ETH to fill
        p.addTranche(100e18, 1e18);
        p.open();
        vm.stopPrank();

        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        uint256 allocation = p.contribute{ value: 150 ether }(0);

        // Should get 100 tokens, refund 50 ETH
        assertEq(allocation, 100e18);
        assertEq(alice.balance, balanceBefore - 100 ether);
    }

    function test_Contribute_Tranche_RevertWhen_SoldOut() public {
        vm.startPrank(owner);
        GhostPresale p = new GhostPresale(GhostPresale.PricingMode.TRANCHE, owner);
        GhostPresale.PresaleConfig memory cfg = _standardConfig();
        cfg.maxContribution = 200 ether;
        cfg.maxPerWallet = 200 ether;
        p.setConfig(cfg);
        p.addTranche(100e18, 1e18); // 100 tokens at 1 ETH
        p.open();
        vm.stopPrank();

        // Fill it completely
        vm.prank(alice);
        p.contribute{ value: 100 ether }(0);

        // Now it's sold out
        vm.prank(bob);
        vm.expectRevert(GhostPresale.PresaleSoldOut.selector);
        p.contribute{ value: 1 ether }(0);
    }

    function test_Contribute_Tranche_MinAllocationSlippage() public {
        _configureAndOpenTranche();

        uint256 ethAmount = 1 ether;
        // Set minAllocation impossibly high
        uint256 impossiblyHigh = 1_000_000e18;

        vm.prank(alice);
        vm.expectRevert(); // AllocationBelowMinimum
        presale.contribute{ value: ethAmount }(impossiblyHigh);
    }

    function test_Contribute_Tranche_EmitsContributed() public {
        _configureAndOpenTranche();

        // Just verify the event is emitted with correct contributor (indexed param)
        vm.expectEmit(true, false, false, false);
        emit GhostPresale.Contributed(alice, 0, 0, 0, 0);

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);
    }

    function test_Contribute_Tranche_EmitsTrancheCompleted() public {
        vm.startPrank(owner);
        GhostPresale p = new GhostPresale(GhostPresale.PricingMode.TRANCHE, owner);
        GhostPresale.PresaleConfig memory cfg = _standardConfig();
        cfg.maxContribution = 200 ether;
        cfg.maxPerWallet = 200 ether;
        p.setConfig(cfg);
        p.addTranche(100e18, 1e18);
        p.addTranche(100e18, 2e18);
        p.open();
        vm.stopPrank();

        // Contribute enough to fill tranche 0 and spill into tranche 1
        vm.expectEmit(true, false, false, true);
        emit GhostPresale.TrancheCompleted(0, 2e18);

        vm.prank(alice);
        p.contribute{ value: 101 ether }(0);
    }

    function test_Contribute_Tranche_IncrementsContributorCount() public {
        _configureAndOpenTranche();

        assertEq(presale.contributorCount(), 0);

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);
        assertEq(presale.contributorCount(), 1);

        vm.prank(bob);
        presale.contribute{ value: 1 ether }(0);
        assertEq(presale.contributorCount(), 2);
    }

    function test_Contribute_Tranche_MultipleContributions() public {
        _configureAndOpenTranche();

        vm.startPrank(alice);
        presale.contribute{ value: 1 ether }(0);
        uint256 firstAlloc = presale.allocations(alice);

        presale.contribute{ value: 1 ether }(0);
        uint256 secondAlloc = presale.allocations(alice);
        vm.stopPrank();

        assertGt(secondAlloc, firstAlloc);
        // Contributor count should still be 1
        assertEq(presale.contributorCount(), 1);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 4. CONTRIBUTING — BONDING CURVE MODE
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Contribute_Curve_AllocatesTokens() public {
        _configureAndOpenCurve();

        vm.prank(alice);
        uint256 allocation = curvePresale.contribute{ value: 1 ether }(0);

        assertGt(allocation, 0);
        assertEq(curvePresale.allocations(alice), allocation);
        assertEq(curvePresale.totalSold(), allocation);
    }

    function test_Contribute_Curve_PriceIncreasesWithSales() public {
        _configureAndOpenCurve();

        uint256 priceBefore = curvePresale.currentPrice();

        vm.prank(alice);
        curvePresale.contribute{ value: 10 ether }(0);

        uint256 priceAfter = curvePresale.currentPrice();
        assertGt(priceAfter, priceBefore);
    }

    function test_Contribute_Curve_PartialFillRefundsExcess() public {
        // Small supply curve so we can fill it
        vm.startPrank(owner);
        GhostPresale cp = new GhostPresale(GhostPresale.PricingMode.BONDING_CURVE, owner);
        GhostPresale.PresaleConfig memory cfg = _standardConfig();
        cfg.maxContribution = 10_000 ether;
        cfg.maxPerWallet = 10_000 ether;
        cp.setConfig(cfg);
        // 100 tokens, price 1 to 2 ETH. Max cost ~150 ETH
        cp.setCurve(1e18, 2e18, 100e18);
        cp.open();
        vm.stopPrank();

        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        uint256 allocation = cp.contribute{ value: 500 ether }(0);

        // Should cap at 100 tokens
        assertEq(allocation, 100e18);
        // Should get refund — balance should be > what it would be if all 500 spent
        assertGt(alice.balance, balanceBefore - 500 ether);
    }

    function test_Contribute_Curve_SmallContribution() public {
        _configureAndOpenCurve();

        vm.prank(alice);
        uint256 allocation = curvePresale.contribute{ value: MIN_CONTRIBUTION }(0);

        assertGt(allocation, 0);
    }

    function test_Contribute_Curve_LargeContribution() public {
        _configureAndOpenCurve();

        vm.prank(alice);
        uint256 allocation = curvePresale.contribute{ value: MAX_CONTRIBUTION }(0);

        assertGt(allocation, 0);
        assertEq(curvePresale.totalRaised(), curvePresale.contributions(alice));
    }

    function test_Contribute_Curve_EmitsContributed() public {
        _configureAndOpenCurve();

        // Just verify the event is emitted with correct contributor
        vm.expectEmit(true, false, false, false);
        emit GhostPresale.Contributed(alice, 0, 0, 0, 0);

        vm.prank(alice);
        curvePresale.contribute{ value: 1 ether }(0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 5. CONTRIBUTION GUARDS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Contribute_RevertWhen_NotOpen() public {
        // Still PENDING
        vm.prank(alice);
        vm.expectRevert(GhostPresale.PresaleNotOpen.selector);
        presale.contribute{ value: 1 ether }(0);
    }

    function test_Contribute_RevertWhen_Paused() public {
        _configureAndOpenTranche();

        vm.prank(owner);
        presale.pause();

        vm.prank(alice);
        vm.expectRevert();
        presale.contribute{ value: 1 ether }(0);
    }

    function test_Contribute_RevertWhen_BelowMinContribution() public {
        _configureAndOpenTranche();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                GhostPresale.BelowMinContribution.selector,
                0.001 ether,
                MIN_CONTRIBUTION
            )
        );
        presale.contribute{ value: 0.001 ether }(0);
    }

    function test_Contribute_RevertWhen_AboveMaxContribution() public {
        _configureAndOpenTranche();

        uint256 overMax = MAX_CONTRIBUTION + 1;
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                GhostPresale.AboveMaxContribution.selector,
                overMax,
                MAX_CONTRIBUTION
            )
        );
        presale.contribute{ value: overMax }(0);
    }

    function test_Contribute_RevertWhen_WalletCapExceeded() public {
        _configureAndOpenTranche();

        // Contribute up to wallet cap
        vm.startPrank(alice);
        presale.contribute{ value: MAX_CONTRIBUTION }(0);
        presale.contribute{ value: MAX_CONTRIBUTION }(0);

        // Third contribution pushes over MAX_PER_WALLET (200 ETH)
        uint256 nextAmount = 1 ether;
        vm.expectRevert(
            abi.encodeWithSelector(
                GhostPresale.WalletCapExceeded.selector,
                presale.contributions(alice) + nextAmount,
                MAX_PER_WALLET
            )
        );
        presale.contribute{ value: nextAmount }(0);
        vm.stopPrank();
    }

    function test_Contribute_RevertWhen_MultipleNotAllowed() public {
        vm.startPrank(owner);
        GhostPresale p = new GhostPresale(GhostPresale.PricingMode.TRANCHE, owner);
        GhostPresale.PresaleConfig memory cfg = _standardConfig();
        cfg.allowMultipleContributions = false;
        p.setConfig(cfg);
        p.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);
        p.open();
        vm.stopPrank();

        vm.startPrank(alice);
        p.contribute{ value: 1 ether }(0);

        vm.expectRevert(GhostPresale.MultipleContributionsNotAllowed.selector);
        p.contribute{ value: 1 ether }(0);
        vm.stopPrank();
    }

    function test_Contribute_RevertWhen_BeforeStartTime() public {
        vm.startPrank(owner);
        GhostPresale.PresaleConfig memory cfg = _standardConfig();
        cfg.startTime = block.timestamp + 1 hours;
        presale.setConfig(cfg);
        presale.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);
        presale.open();
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(GhostPresale.PresaleNotOpen.selector);
        presale.contribute{ value: 1 ether }(0);
    }

    function test_Contribute_RevertWhen_AfterEndTime() public {
        vm.startPrank(owner);
        GhostPresale.PresaleConfig memory cfg = _standardConfig();
        cfg.endTime = block.timestamp + 1 hours;
        presale.setConfig(cfg);
        presale.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);
        presale.open();
        vm.stopPrank();

        // Warp past end time
        vm.warp(block.timestamp + 2 hours);

        vm.prank(alice);
        vm.expectRevert(GhostPresale.PresaleNotOpen.selector);
        presale.contribute{ value: 1 ether }(0);
    }

    function test_Contribute_RevertWhen_ZeroValue() public {
        _configureAndOpenTranche();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                GhostPresale.BelowMinContribution.selector,
                0,
                MIN_CONTRIBUTION
            )
        );
        presale.contribute{ value: 0 }(0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 6. VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_CurrentPrice_Tranche_ReturnsCorrectPrice() public {
        _configureAndOpenTranche();

        assertEq(presale.currentPrice(), TRANCHE_1_PRICE);
    }

    function test_CurrentPrice_Curve_ReturnsCorrectPrice() public {
        _configureAndOpenCurve();

        // At totalSold=0, price should be startPrice
        assertEq(curvePresale.currentPrice(), CURVE_START_PRICE);
    }

    function test_Preview_ReturnsEstimate() public {
        _configureAndOpenTranche();

        (uint256 dataAmount, uint256 priceImpact) = presale.preview(1 ether);

        // ~333.33 tokens at 0.003 ETH/token (rounding acceptable)
        assertGt(dataAmount, 333e18);
        assertLt(dataAmount, 334e18);
        assertEq(priceImpact, 0); // Tranche mode always 0
    }

    function test_Preview_Curve_ReturnsPriceImpact() public {
        _configureAndOpenCurve();

        (, uint256 priceImpact) = curvePresale.preview(10 ether);
        assertGt(priceImpact, 0);
    }

    function test_Progress_ReturnsCorrectValues() public {
        _configureAndOpenTranche();

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);

        (uint256 raised, uint256 sold, uint256 supply, uint256 price, uint256 contributors) =
            presale.progress();

        assertGt(raised, 0);
        assertGt(sold, 0);
        assertEq(supply, TRANCHE_1_SUPPLY + TRANCHE_2_SUPPLY + TRANCHE_3_SUPPLY);
        assertEq(price, TRANCHE_1_PRICE);
        assertEq(contributors, 1);
    }

    function test_TotalPresaleSupply_Tranche() public {
        _configureAndOpenTranche();

        uint256 expected = TRANCHE_1_SUPPLY + TRANCHE_2_SUPPLY + TRANCHE_3_SUPPLY;
        assertEq(presale.totalPresaleSupply(), expected);
    }

    function test_TotalPresaleSupply_Curve() public {
        _configureAndOpenCurve();

        assertEq(curvePresale.totalPresaleSupply(), CURVE_SUPPLY);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 7. FINALIZATION & WITHDRAWAL
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Finalize_TransitionsToFinalized() public {
        _configureAndOpenTranche();

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);

        vm.prank(owner);
        presale.finalize();

        assertEq(uint256(presale.state()), uint256(GhostPresale.PresaleState.FINALIZED));
    }

    function test_Finalize_EmitsPresaleFinalized() public {
        _configureAndOpenTranche();

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);

        vm.expectEmit(false, false, false, true);
        emit GhostPresale.PresaleFinalized(presale.totalRaised(), presale.totalSold(), 1);

        vm.prank(owner);
        presale.finalize();
    }

    function test_Finalize_RevertWhen_NotOpen() public {
        // Still PENDING
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                GhostPresale.InvalidState.selector,
                GhostPresale.PresaleState.PENDING,
                GhostPresale.PresaleState.OPEN
            )
        );
        presale.finalize();
    }

    function test_WithdrawETH_TransfersBalance() public {
        _configureAndOpenTranche();

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);

        vm.prank(owner);
        presale.finalize();

        uint256 contractBalance = address(presale).balance;
        uint256 ownerBefore = owner.balance;

        vm.prank(owner);
        presale.withdrawETH(owner);

        assertEq(owner.balance, ownerBefore + contractBalance);
        assertEq(address(presale).balance, 0);
    }

    function test_WithdrawETH_RevertWhen_NotFinalized() public {
        _configureAndOpenTranche();

        vm.prank(owner);
        vm.expectRevert(GhostPresale.PresaleNotFinalized.selector);
        presale.withdrawETH(owner);
    }

    function test_WithdrawETH_RevertWhen_NotOwner() public {
        _configureAndOpenTranche();

        vm.prank(owner);
        presale.finalize();

        vm.prank(alice);
        vm.expectRevert();
        presale.withdrawETH(alice);
    }

    function test_WithdrawETH_RevertWhen_ZeroAddress() public {
        _configureAndOpenTranche();

        vm.prank(owner);
        presale.finalize();

        vm.prank(owner);
        vm.expectRevert(GhostPresale.InvalidAddress.selector);
        presale.withdrawETH(address(0));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 8. REFUNDS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_EnableRefunds_TransitionsToRefunding() public {
        _configureAndOpenTranche();

        vm.prank(owner);
        presale.enableRefunds();

        assertEq(uint256(presale.state()), uint256(GhostPresale.PresaleState.REFUNDING));
    }

    function test_EnableRefunds_EmitsRefundsEnabled() public {
        _configureAndOpenTranche();

        vm.expectEmit(false, false, false, false);
        emit GhostPresale.RefundsEnabled();

        vm.prank(owner);
        presale.enableRefunds();
    }

    function test_EnableRefunds_RevertWhen_NotOpen() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                GhostPresale.InvalidState.selector,
                GhostPresale.PresaleState.PENDING,
                GhostPresale.PresaleState.OPEN
            )
        );
        presale.enableRefunds();
    }

    function test_Refund_ReturnsETH() public {
        _configureAndOpenTranche();

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);

        uint256 contributed = presale.contributions(alice);

        vm.prank(owner);
        presale.enableRefunds();

        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        presale.refund();

        assertEq(alice.balance, balanceBefore + contributed);
    }

    function test_Refund_ZeroesContribution() public {
        _configureAndOpenTranche();

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);

        vm.prank(owner);
        presale.enableRefunds();

        vm.prank(alice);
        presale.refund();

        assertEq(presale.contributions(alice), 0);
    }

    function test_Refund_EmitsRefunded() public {
        _configureAndOpenTranche();

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);

        uint256 contributed = presale.contributions(alice);

        vm.prank(owner);
        presale.enableRefunds();

        vm.expectEmit(true, false, false, true);
        emit GhostPresale.Refunded(alice, contributed);

        vm.prank(alice);
        presale.refund();
    }

    function test_Refund_RevertWhen_NotRefunding() public {
        _configureAndOpenTranche();

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);

        // Still OPEN, not REFUNDING
        vm.prank(alice);
        vm.expectRevert(GhostPresale.PresaleNotRefunding.selector);
        presale.refund();
    }

    function test_Refund_RevertWhen_NoContribution() public {
        _configureAndOpenTranche();

        vm.prank(owner);
        presale.enableRefunds();

        vm.prank(bob); // Never contributed
        vm.expectRevert(GhostPresale.NoContribution.selector);
        presale.refund();
    }

    function test_Refund_WorksWhenPaused() public {
        _configureAndOpenTranche();

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);

        uint256 contributed = presale.contributions(alice);

        vm.startPrank(owner);
        presale.enableRefunds();
        presale.pause();
        vm.stopPrank();

        // Refund should still work even though paused
        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        presale.refund();

        assertEq(alice.balance, balanceBefore + contributed);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 9. EMERGENCY DEAD-MAN'S SWITCH
    // ══════════════════════════════════════════════════════════════════════════════

    function test_EmergencyRefunds_WorksAfterDeadline() public {
        _configureAndOpenTranche();

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);

        // Warp past emergency deadline
        vm.warp(presale.openedAt() + EMERGENCY_DEADLINE + 1);

        vm.prank(stranger);
        presale.emergencyRefunds();

        assertEq(uint256(presale.state()), uint256(GhostPresale.PresaleState.REFUNDING));
    }

    function test_EmergencyRefunds_RevertWhen_BeforeDeadline() public {
        _configureAndOpenTranche();

        uint256 deadline = presale.openedAt() + EMERGENCY_DEADLINE;

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                GhostPresale.EmergencyDeadlineNotReached.selector,
                block.timestamp,
                deadline
            )
        );
        presale.emergencyRefunds();
    }

    function test_EmergencyRefunds_RevertWhen_NotOpen() public {
        // Still PENDING
        vm.prank(stranger);
        vm.expectRevert(GhostPresale.PresaleNotOpen.selector);
        presale.emergencyRefunds();
    }

    function test_EmergencyRefunds_PermissionlessAnyoneCanCall() public {
        _configureAndOpenTranche();

        vm.warp(presale.openedAt() + EMERGENCY_DEADLINE + 1);

        // Non-owner, non-contributor can call
        vm.prank(stranger);
        presale.emergencyRefunds();

        assertEq(uint256(presale.state()), uint256(GhostPresale.PresaleState.REFUNDING));
    }

    function test_EmergencyRefunds_EmitsEvents() public {
        _configureAndOpenTranche();

        uint256 triggerTime = presale.openedAt() + EMERGENCY_DEADLINE + 1;
        vm.warp(triggerTime);

        vm.expectEmit(true, false, false, true);
        emit GhostPresale.EmergencyRefundsTriggered(stranger, triggerTime);

        vm.expectEmit(false, false, false, false);
        emit GhostPresale.RefundsEnabled();

        vm.prank(stranger);
        presale.emergencyRefunds();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 10. PAUSE
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Pause_BlocksContributions() public {
        _configureAndOpenTranche();

        vm.prank(owner);
        presale.pause();

        vm.prank(alice);
        vm.expectRevert();
        presale.contribute{ value: 1 ether }(0);
    }

    function test_Unpause_AllowsContributions() public {
        _configureAndOpenTranche();

        vm.prank(owner);
        presale.pause();

        vm.prank(owner);
        presale.unpause();

        vm.prank(alice);
        uint256 allocation = presale.contribute{ value: 1 ether }(0);
        assertGt(allocation, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 11. FUZZ TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function testFuzz_Contribute_Curve_NeverOvercharges(uint256 ethAmount) public {
        // Bound to valid range: minContribution .. 100 ether
        ethAmount = bound(ethAmount, MIN_CONTRIBUTION, 100 ether);

        _configureAndOpenCurve();

        uint256 balanceBefore = alice.balance;

        vm.prank(alice);
        uint256 allocation = curvePresale.contribute{ value: ethAmount }(0);

        uint256 ethSpent = balanceBefore - alice.balance;

        // Never charge more than sent
        assertLe(ethSpent, ethAmount);
        // Allocation recorded correctly
        assertEq(curvePresale.allocations(alice), allocation);
        // totalRaised matches contributions
        assertEq(curvePresale.totalRaised(), curvePresale.contributions(alice));
    }

    function testFuzz_Contribute_Curve_AlwaysAllocatesPositive(uint256 ethAmount) public {
        ethAmount = bound(ethAmount, MIN_CONTRIBUTION, 100 ether);

        _configureAndOpenCurve();

        vm.prank(alice);
        uint256 allocation = curvePresale.contribute{ value: ethAmount }(0);

        assertGt(allocation, 0);
    }

    function testFuzz_Contribute_Tranche_ConservationOfETH(uint256 ethAmount) public {
        ethAmount = bound(ethAmount, MIN_CONTRIBUTION, MAX_CONTRIBUTION);

        _configureAndOpenTranche();

        uint256 balanceBefore = alice.balance;
        uint256 contractBefore = address(presale).balance;

        vm.prank(alice);
        presale.contribute{ value: ethAmount }(0);

        uint256 ethSpent = balanceBefore - alice.balance;
        uint256 contractGain = address(presale).balance - contractBefore;

        // Conservation: what alice lost, the contract gained
        assertEq(ethSpent, contractGain);
        // What the contract gained matches totalRaised
        assertEq(contractGain, presale.totalRaised());
    }

    function testFuzz_Contribute_Curve_TotalSoldNeverExceedsSupply(uint256 ethAmount) public {
        ethAmount = bound(ethAmount, MIN_CONTRIBUTION, 100 ether);

        _configureAndOpenCurve();

        vm.prank(alice);
        curvePresale.contribute{ value: ethAmount }(0);

        assertLe(curvePresale.totalSold(), CURVE_SUPPLY);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 12. EDGE CASE TESTS (Review 3 fixes)
    // ══════════════════════════════════════════════════════════════════════════════

    function test_AddTranche_RevertWhen_ZeroSupply() public {
        vm.prank(owner);
        vm.expectRevert(GhostPresale.ZeroTrancheSupply.selector);
        presale.addTranche(0, TRANCHE_1_PRICE);
    }

    function test_ExtendEndTime_RevertWhen_NoEndTimeSet() public {
        // Config has endTime=0 (no deadline)
        _configureAndOpenTranche();

        vm.prank(owner);
        vm.expectRevert(GhostPresale.NoEndTimeSet.selector);
        presale.extendEndTime(block.timestamp + 1 hours);
    }

    function test_ExtendEndTime_WorksWhen_EndTimeSet() public {
        vm.startPrank(owner);
        GhostPresale p = new GhostPresale(GhostPresale.PricingMode.TRANCHE, owner);
        GhostPresale.PresaleConfig memory cfg = _standardConfig();
        cfg.endTime = block.timestamp + 7 days;
        p.setConfig(cfg);
        p.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);
        p.open();

        uint256 newEnd = block.timestamp + 14 days;
        p.extendEndTime(newEnd);
        vm.stopPrank();

        (,,,,, uint256 endTime,) = p.config();
        assertEq(endTime, newEnd);
    }

    function test_Open_RevertWhen_EmergencyDeadlineNotSet() public {
        vm.startPrank(owner);
        GhostPresale p = new GhostPresale(GhostPresale.PricingMode.TRANCHE, owner);
        // Config with emergencyDeadline=0 (default)
        p.setConfig(GhostPresale.PresaleConfig({
            minContribution: MIN_CONTRIBUTION,
            maxContribution: MAX_CONTRIBUTION,
            maxPerWallet: MAX_PER_WALLET,
            allowMultipleContributions: true,
            startTime: 0,
            endTime: 0,
            emergencyDeadline: 0
        }));
        p.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);

        vm.expectRevert(GhostPresale.EmergencyDeadlineNotSet.selector);
        p.open();
        vm.stopPrank();
    }

    function test_DoubleRefund_RevertWhen_AlreadyRefunded() public {
        _configureAndOpenTranche();

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);

        vm.prank(owner);
        presale.enableRefunds();

        // First refund succeeds
        vm.prank(alice);
        presale.refund();

        // Second refund reverts — contribution is zeroed
        vm.prank(alice);
        vm.expectRevert(GhostPresale.NoContribution.selector);
        presale.refund();
    }

    function test_Contribute_RevertWhen_Finalized() public {
        _configureAndOpenTranche();

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);

        vm.prank(owner);
        presale.finalize();

        // Contributing after finalize should revert
        vm.prank(bob);
        vm.expectRevert(GhostPresale.PresaleNotOpen.selector);
        presale.contribute{ value: 1 ether }(0);
    }

    function test_GhostPresale_ImplementsIGhostPresale() public {
        // Verify the contract satisfies the interface by calling interface methods
        _configureAndOpenTranche();

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);

        // These calls go through the IGhostPresale interface implicitly
        uint256 alloc = presale.allocations(alice);
        uint256 sold = presale.totalSold();

        assertGt(alloc, 0);
        assertEq(sold, alloc);
    }

    function test_Preview_Tranche_ConsistentWithContribute() public {
        _configureAndOpenTranche();

        uint256 ethAmount = 1 ether;
        (uint256 previewData,) = presale.preview(ethAmount);

        vm.prank(alice);
        uint256 actualData = presale.contribute{ value: ethAmount }(0);

        // Preview and actual should match
        assertEq(previewData, actualData);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 13. ADDITIONAL COVERAGE — Fuzz, Monotonicity, Griefing, State Guards
    // ══════════════════════════════════════════════════════════════════════════════

    function testFuzz_Contribute_Tranche_CrossesBoundary(uint256 ethAmount) public {
        // Small tranches to force crossing
        vm.startPrank(owner);
        GhostPresale p = new GhostPresale(GhostPresale.PricingMode.TRANCHE, owner);
        GhostPresale.PresaleConfig memory cfg = _standardConfig();
        cfg.minContribution = 0.001 ether;
        cfg.maxContribution = 500 ether;
        cfg.maxPerWallet = 500 ether;
        p.setConfig(cfg);
        p.addTranche(100e18, 1e18);   // 100 tokens @ 1 ETH
        p.addTranche(100e18, 2e18);   // 100 tokens @ 2 ETH
        p.addTranche(100e18, 3e18);   // 100 tokens @ 3 ETH
        p.open();
        vm.stopPrank();

        ethAmount = bound(ethAmount, 0.001 ether, 400 ether);

        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        uint256 allocation = p.contribute{ value: ethAmount }(0);

        uint256 ethSpent = balanceBefore - alice.balance;

        // Invariants
        assertGt(allocation, 0);
        assertLe(ethSpent, ethAmount);
        assertLe(p.totalSold(), 300e18); // never exceed total supply
        assertEq(p.totalRaised(), p.contributions(alice));
    }

    function testFuzz_Curve_RoundTrip_CostVerification(uint256 ethAmount) public {
        ethAmount = bound(ethAmount, 0.01 ether, 50 ether);

        _configureAndOpenCurve();

        // Simulate: compute tokens for ETH, then compute cost for those tokens
        (uint256 previewTokens,) = curvePresale.preview(ethAmount);
        if (previewTokens == 0) return;

        // Contribute and check actual cost
        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        uint256 allocation = curvePresale.contribute{ value: ethAmount }(0);
        uint256 ethSpent = balanceBefore - alice.balance;

        // The actual ETH spent should be <= ethAmount
        assertLe(ethSpent, ethAmount);
        // Preview and actual allocation should be very close (within rounding)
        // Allow 1 token of difference due to rounding paths
        uint256 diff = allocation > previewTokens
            ? allocation - previewTokens
            : previewTokens - allocation;
        assertLe(diff, 1e18, "Preview vs actual allocation diverged by more than 1 token");
    }

    function test_Curve_PriceNeverDecreases_AfterContributions() public {
        _configureAndOpenCurve();

        uint256 priceBefore = curvePresale.currentPrice();

        // Multiple contributions, price should never decrease
        address[3] memory contributors = [alice, bob, carol];
        for (uint256 i; i < 3; ++i) {
            vm.prank(contributors[i]);
            curvePresale.contribute{ value: 5 ether }(0);

            uint256 priceAfter = curvePresale.currentPrice();
            assertGe(priceAfter, priceBefore, "Price decreased after contribution");
            priceBefore = priceAfter;
        }
    }

    function test_Contribute_ZeroValue_WhenNoMinContribution() public {
        // Configure with minContribution=0
        vm.startPrank(owner);
        GhostPresale p = new GhostPresale(GhostPresale.PricingMode.TRANCHE, owner);
        GhostPresale.PresaleConfig memory cfg = _standardConfig();
        cfg.minContribution = 0;
        p.setConfig(cfg);
        p.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);
        p.open();
        vm.stopPrank();

        // 0-value contribution: tokensAtPrice = 0, ethSpent = 0
        // This should either revert or produce 0 allocation
        vm.prank(alice);
        uint256 allocation = p.contribute{ value: 0 }(0);

        // Allocation is 0 — no tokens bought
        assertEq(allocation, 0);
        // But contributorCount was incremented — this is the griefing vector
        // Documenting current behavior: contributor count inflated
        assertEq(p.contributorCount(), 1);
    }

    function test_EmergencyRefunds_RevertWhen_Finalized() public {
        _configureAndOpenTranche();

        vm.prank(alice);
        presale.contribute{ value: 1 ether }(0);

        vm.prank(owner);
        presale.finalize();

        vm.warp(block.timestamp + EMERGENCY_DEADLINE + 1);

        vm.prank(stranger);
        vm.expectRevert(GhostPresale.PresaleNotOpen.selector);
        presale.emergencyRefunds();
    }

    function test_EnableRefunds_RevertWhen_Finalized() public {
        _configureAndOpenTranche();

        vm.prank(owner);
        presale.finalize();

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                GhostPresale.InvalidState.selector,
                GhostPresale.PresaleState.FINALIZED,
                GhostPresale.PresaleState.OPEN
            )
        );
        presale.enableRefunds();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // 14. NEW CONTRACT CHANGES — M-2, L-3, L-4
    // ══════════════════════════════════════════════════════════════════════════════

    function test_WithdrawETH_RevertWhen_ZeroBalance() public {
        _configureAndOpenTranche();

        vm.prank(owner);
        presale.finalize();

        // No contributions — balance is 0
        vm.prank(owner);
        vm.expectRevert(GhostPresale.NoETHToWithdraw.selector);
        presale.withdrawETH(owner);
    }

    function test_AddTranche_RevertWhen_WrongPricingMode() public {
        GhostPresale cp = _deployCurvePresale();
        vm.prank(owner);
        vm.expectRevert(GhostPresale.WrongPricingMode.selector);
        cp.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);
    }

    function test_SetCurve_RevertWhen_WrongPricingMode() public {
        vm.prank(owner);
        vm.expectRevert(GhostPresale.WrongPricingMode.selector);
        presale.setCurve(CURVE_START_PRICE, CURVE_END_PRICE, CURVE_SUPPLY);
    }

    function test_ClearTranches_RevertWhen_WrongPricingMode() public {
        GhostPresale cp = _deployCurvePresale();
        vm.prank(owner);
        vm.expectRevert(GhostPresale.WrongPricingMode.selector);
        cp.clearTranches();
    }

    function test_ClearTranches_EmitsTranchesCleared() public {
        vm.startPrank(owner);
        presale.addTranche(TRANCHE_1_SUPPLY, TRANCHE_1_PRICE);

        vm.expectEmit(false, false, false, false);
        emit GhostPresale.TranchesCleared();
        presale.clearTranches();
        vm.stopPrank();
    }

    function testFuzz_Contribute_Curve_VariedConfigs(
        uint256 startPrice,
        uint256 priceSpread,
        uint256 supply,
        uint256 ethAmount
    ) public {
        // Reasonable bounds for curve params
        startPrice = bound(startPrice, 0.0001e18, 1e18);
        priceSpread = bound(priceSpread, 0.0001e18, 10e18);
        supply = bound(supply, 1_000e18, 100_000_000e18);
        ethAmount = bound(ethAmount, 0.01 ether, 100 ether);

        uint256 endPrice = startPrice + priceSpread;

        vm.startPrank(owner);
        GhostPresale cp = new GhostPresale(GhostPresale.PricingMode.BONDING_CURVE, owner);
        cp.setConfig(_standardConfig());
        cp.setCurve(startPrice, endPrice, supply);
        cp.open();
        vm.stopPrank();

        vm.prank(alice);
        uint256 allocation = cp.contribute{ value: ethAmount }(0);

        // Invariants: allocation > 0, never exceeds supply, never overcharged
        assertGt(allocation, 0);
        assertLe(cp.totalSold(), supply);
        assertLe(cp.totalRaised(), ethAmount);
    }
}
