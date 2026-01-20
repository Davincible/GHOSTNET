// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test, console } from "forge-std/Test.sol";
import { DataToken } from "../src/token/DataToken.sol";
import { IDataToken } from "../src/token/interfaces/IDataToken.sol";

/// @title DataToken Tests
/// @notice Comprehensive tests for the GHOSTNET $DATA token
contract DataTokenTest is Test {
    DataToken public token;

    address public treasury = makeAddr("treasury");
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");
    address public gameContract = makeAddr("gameContract");

    uint256 constant TOTAL_SUPPLY = 100_000_000 * 1e18;
    uint256 constant INITIAL_ALICE = 10_000_000 * 1e18;
    uint256 constant INITIAL_BOB = 5_000_000 * 1e18;
    uint256 constant INITIAL_TREASURY = 85_000_000 * 1e18;

    function setUp() public {
        // Create initial distribution
        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = treasury;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = INITIAL_ALICE;
        amounts[1] = INITIAL_BOB;
        amounts[2] = INITIAL_TREASURY;

        token = new DataToken(treasury, owner, recipients, amounts);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // DEPLOYMENT TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Constructor_SetsCorrectTotalSupply() public view {
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
    }

    function test_Constructor_SetsCorrectBalances() public view {
        assertEq(token.balanceOf(alice), INITIAL_ALICE);
        assertEq(token.balanceOf(bob), INITIAL_BOB);
        assertEq(token.balanceOf(treasury), INITIAL_TREASURY);
    }

    function test_Constructor_SetsTreasury() public view {
        assertEq(token.treasury(), treasury);
    }

    function test_Constructor_SetsOwner() public view {
        assertEq(token.owner(), owner);
    }

    function test_Constructor_ExcludesTreasuryFromTax() public view {
        assertTrue(token.isExcludedFromTax(treasury));
    }

    function test_Constructor_ExcludesDeadAddressFromTax() public view {
        assertTrue(token.isExcludedFromTax(token.DEAD_ADDRESS()));
    }

    function test_Constructor_RevertWhen_InvalidTreasury() public {
        address[] memory recipients = new address[](1);
        recipients[0] = alice;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = TOTAL_SUPPLY;

        vm.expectRevert(IDataToken.InvalidTreasury.selector);
        new DataToken(address(0), owner, recipients, amounts);
    }

    function test_Constructor_RevertWhen_ArrayLengthMismatch() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = TOTAL_SUPPLY;

        vm.expectRevert(IDataToken.DistributionLengthMismatch.selector);
        new DataToken(treasury, owner, recipients, amounts);
    }

    function test_Constructor_RevertWhen_DistributionSumMismatch() public {
        address[] memory recipients = new address[](1);
        recipients[0] = alice;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = TOTAL_SUPPLY - 1; // Wrong sum

        vm.expectRevert(IDataToken.DistributionSumMismatch.selector);
        new DataToken(treasury, owner, recipients, amounts);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TAX MECHANICS TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Transfer_AppliesTax() public {
        uint256 transferAmount = 1000 * 1e18;
        uint256 expectedTax = (transferAmount * 1000) / 10_000; // 10%
        uint256 expectedBurn = (expectedTax * 9000) / 10_000; // 90% of tax
        uint256 expectedTreasury = expectedTax - expectedBurn; // 10% of tax
        uint256 expectedReceived = transferAmount - expectedTax;

        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 deadBefore = token.balanceOf(token.DEAD_ADDRESS());

        vm.prank(alice);
        token.transfer(carol, transferAmount);

        assertEq(token.balanceOf(carol), expectedReceived, "Carol should receive amount minus tax");
        assertEq(
            token.balanceOf(treasury) - treasuryBefore,
            expectedTreasury,
            "Treasury should receive 1% of transfer"
        );
        assertEq(
            token.balanceOf(token.DEAD_ADDRESS()) - deadBefore,
            expectedBurn,
            "Dead address should receive 9% burn"
        );
    }

    function test_Transfer_UpdatesTotalBurned() public {
        uint256 transferAmount = 1000 * 1e18;
        uint256 expectedBurn = (transferAmount * 900) / 10_000; // 9%

        uint256 burnedBefore = token.totalBurned();

        vm.prank(alice);
        token.transfer(carol, transferAmount);

        assertEq(token.totalBurned() - burnedBefore, expectedBurn);
    }

    function test_Transfer_NoTaxWhen_SenderExcluded() public {
        // Exclude alice from tax
        vm.prank(owner);
        token.setTaxExclusion(alice, true);

        uint256 transferAmount = 1000 * 1e18;

        vm.prank(alice);
        token.transfer(carol, transferAmount);

        assertEq(token.balanceOf(carol), transferAmount, "Carol should receive full amount");
    }

    function test_Transfer_NoTaxWhen_RecipientExcluded() public {
        // Exclude carol from tax
        vm.prank(owner);
        token.setTaxExclusion(carol, true);

        uint256 transferAmount = 1000 * 1e18;

        vm.prank(alice);
        token.transfer(carol, transferAmount);

        assertEq(token.balanceOf(carol), transferAmount, "Carol should receive full amount");
    }

    function test_Transfer_NoTaxBetweenExcludedAddresses() public {
        vm.startPrank(owner);
        token.setTaxExclusion(alice, true);
        token.setTaxExclusion(bob, true);
        vm.stopPrank();

        uint256 transferAmount = 1000 * 1e18;

        vm.prank(alice);
        token.transfer(bob, transferAmount);

        assertEq(token.balanceOf(bob), INITIAL_BOB + transferAmount);
    }

    function test_TransferFrom_AppliesTax() public {
        uint256 transferAmount = 1000 * 1e18;
        uint256 expectedReceived = (transferAmount * 9000) / 10_000; // 90%

        vm.prank(alice);
        token.approve(bob, transferAmount);

        vm.prank(bob);
        token.transferFrom(alice, carol, transferAmount);

        assertEq(token.balanceOf(carol), expectedReceived);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TAX EXCLUSION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_SetTaxExclusion_Success() public {
        assertFalse(token.isExcludedFromTax(gameContract));

        vm.prank(owner);
        token.setTaxExclusion(gameContract, true);

        assertTrue(token.isExcludedFromTax(gameContract));
    }

    function test_SetTaxExclusion_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit IDataToken.TaxExclusionSet(gameContract, true);

        vm.prank(owner);
        token.setTaxExclusion(gameContract, true);
    }

    function test_SetTaxExclusion_RevertWhen_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setTaxExclusion(gameContract, true);
    }

    function test_SetTaxExclusion_CanRemoveExclusion() public {
        vm.startPrank(owner);
        token.setTaxExclusion(gameContract, true);
        assertTrue(token.isExcludedFromTax(gameContract));

        token.setTaxExclusion(gameContract, false);
        assertFalse(token.isExcludedFromTax(gameContract));
        vm.stopPrank();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BURN TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Burn_ReducesBalance() public {
        uint256 burnAmount = 1000 * 1e18;
        uint256 aliceBalanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        token.burn(burnAmount);

        assertEq(token.balanceOf(alice), aliceBalanceBefore - burnAmount);
    }

    function test_Burn_ReducesTotalSupply() public {
        uint256 burnAmount = 1000 * 1e18;
        uint256 supplyBefore = token.totalSupply();

        vm.prank(alice);
        token.burn(burnAmount);

        assertEq(token.totalSupply(), supplyBefore - burnAmount);
    }

    function test_Burn_UpdatesTotalBurned() public {
        uint256 burnAmount = 1000 * 1e18;
        uint256 totalBurnedBefore = token.totalBurned();

        vm.prank(alice);
        token.burn(burnAmount);

        assertEq(token.totalBurned(), totalBurnedBefore + burnAmount);
    }

    function test_BurnFrom_Success() public {
        uint256 burnAmount = 1000 * 1e18;

        vm.prank(alice);
        token.approve(bob, burnAmount);

        uint256 aliceBalanceBefore = token.balanceOf(alice);

        vm.prank(bob);
        token.burnFrom(alice, burnAmount);

        assertEq(token.balanceOf(alice), aliceBalanceBefore - burnAmount);
    }

    function test_BurnFrom_RevertWhen_InsufficientAllowance() public {
        vm.prank(bob);
        vm.expectRevert();
        token.burnFrom(alice, 1000 * 1e18);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function testFuzz_Transfer_TaxCalculation(uint256 amount) public {
        // Bound amount to reasonable range
        amount = bound(amount, 1e18, INITIAL_ALICE);

        uint256 expectedTax = (amount * 1000) / 10_000;
        uint256 expectedBurn = (expectedTax * 9000) / 10_000;
        uint256 expectedTreasury = expectedTax - expectedBurn;
        uint256 expectedReceived = amount - expectedTax;

        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 deadBefore = token.balanceOf(token.DEAD_ADDRESS());

        vm.prank(alice);
        token.transfer(carol, amount);

        assertEq(token.balanceOf(carol), expectedReceived);
        assertEq(token.balanceOf(treasury) - treasuryBefore, expectedTreasury);
        assertEq(token.balanceOf(token.DEAD_ADDRESS()) - deadBefore, expectedBurn);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TAX EDGE CASES
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Transfer_SmallAmount_RoundingBehavior() public {
        // Transfer 10 wei - tax should be 1 wei (10%), burn 0 wei, treasury 1 wei
        uint256 transferAmount = 10;

        uint256 treasuryBefore = token.balanceOf(treasury);
        uint256 deadBefore = token.balanceOf(token.DEAD_ADDRESS());

        vm.prank(alice);
        token.transfer(carol, transferAmount);

        uint256 expectedTax = 1; // 10% of 10 = 1
        uint256 expectedBurn = 0; // 90% of 1 = 0 (rounds down)
        uint256 expectedTreasury = 1; // 1 - 0 = 1
        uint256 expectedReceived = 9; // 10 - 1 = 9

        assertEq(token.balanceOf(carol), expectedReceived, "Recipient gets 9 wei");
        assertEq(token.balanceOf(treasury) - treasuryBefore, expectedTreasury, "Treasury gets 1 wei");
        assertEq(token.balanceOf(token.DEAD_ADDRESS()) - deadBefore, expectedBurn, "Burn is 0 due to rounding");
    }

    function test_Transfer_VerySmallAmount_NoTax() public {
        // Transfer 9 wei - tax should be 0 (rounds down)
        uint256 transferAmount = 9;

        vm.prank(alice);
        token.transfer(carol, transferAmount);

        // With 9 wei: tax = 9 * 1000 / 10000 = 0 (rounds down)
        assertEq(token.balanceOf(carol), transferAmount, "Full amount received when tax rounds to 0");
    }

    function test_Transfer_EmitsTaxEvents() public {
        uint256 transferAmount = 1000 * 1e18;
        uint256 expectedTax = (transferAmount * 1000) / 10_000; // 100 tokens
        uint256 expectedBurn = (expectedTax * 9000) / 10_000; // 90 tokens
        uint256 expectedTreasury = expectedTax - expectedBurn; // 10 tokens

        vm.expectEmit(true, false, false, true);
        emit IDataToken.TaxBurned(alice, expectedBurn);

        vm.expectEmit(true, false, false, true);
        emit IDataToken.TaxCollected(alice, expectedTreasury);

        vm.prank(alice);
        token.transfer(carol, transferAmount);
    }

    function test_Transfer_SelfTransfer_AppliesTax() public {
        // Self-transfer should still apply tax (alice is not excluded)
        uint256 transferAmount = 1000 * 1e18;
        uint256 expectedTax = (transferAmount * 1000) / 10_000;
        uint256 aliceBalanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        token.transfer(alice, transferAmount);

        // Alice loses the tax amount
        assertEq(token.balanceOf(alice), aliceBalanceBefore - expectedTax);
    }

    function test_Transfer_MultipleConsecutive_AccumulatesBurn() public {
        uint256 transferAmount = 1000 * 1e18;
        uint256 singleBurn = (transferAmount * 900) / 10_000; // 9%

        uint256 burnedBefore = token.totalBurned();

        // Three consecutive transfers
        vm.prank(alice);
        token.transfer(carol, transferAmount);

        // Carol needs to transfer (received 90% of 1000)
        vm.prank(carol);
        token.transfer(bob, 500 * 1e18);

        vm.prank(bob);
        token.transfer(alice, 200 * 1e18);

        // Verify burns accumulated
        uint256 totalNewBurns = token.totalBurned() - burnedBefore;
        assertGt(totalNewBurns, singleBurn, "Multiple transfers should accumulate burns");
    }

    function test_Transfer_EntireBalance() public {
        uint256 aliceBalance = token.balanceOf(alice);
        uint256 expectedTax = (aliceBalance * 1000) / 10_000;
        uint256 expectedReceived = aliceBalance - expectedTax;

        vm.prank(alice);
        token.transfer(carol, aliceBalance);

        assertEq(token.balanceOf(alice), 0, "Alice should have 0 after full transfer");
        assertEq(token.balanceOf(carol), expectedReceived, "Carol receives amount minus tax");
    }

    function test_Transfer_ToTreasury_NoTax() public {
        // Treasury is excluded, so transfer TO treasury should have no tax
        uint256 transferAmount = 1000 * 1e18;
        uint256 treasuryBefore = token.balanceOf(treasury);

        vm.prank(alice);
        token.transfer(treasury, transferAmount);

        assertEq(token.balanceOf(treasury), treasuryBefore + transferAmount, "Treasury receives full amount");
    }

    function test_Transfer_FromTreasury_NoTax() public {
        // Treasury is excluded, so transfer FROM treasury should have no tax
        uint256 transferAmount = 1000 * 1e18;

        vm.prank(treasury);
        token.transfer(carol, transferAmount);

        assertEq(token.balanceOf(carol), transferAmount, "Carol receives full amount from treasury");
    }

    function testFuzz_Burn_UpdatesState(uint256 amount) public {
        amount = bound(amount, 1, INITIAL_ALICE);

        uint256 supplyBefore = token.totalSupply();
        uint256 totalBurnedBefore = token.totalBurned();
        uint256 aliceBefore = token.balanceOf(alice);

        vm.prank(alice);
        token.burn(amount);

        assertEq(token.totalSupply(), supplyBefore - amount);
        assertEq(token.totalBurned(), totalBurnedBefore + amount);
        assertEq(token.balanceOf(alice), aliceBefore - amount);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS VERIFICATION
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Constants() public view {
        assertEq(token.TOTAL_SUPPLY(), 100_000_000 * 1e18);
        assertEq(token.TAX_RATE_BPS(), 1000); // 10%
        assertEq(token.BURN_SHARE_BPS(), 9000); // 90% of tax
        assertEq(token.TREASURY_SHARE_BPS(), 1000); // 10% of tax
        assertEq(token.DEAD_ADDRESS(), 0x000000000000000000000000000000000000dEaD);
    }

    function test_TokenMetadata() public view {
        assertEq(token.name(), "GHOSTNET Data");
        assertEq(token.symbol(), "DATA");
        assertEq(token.decimals(), 18);
    }
}
