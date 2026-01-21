// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { DataToken } from "../src/token/DataToken.sol";
import { FeeRouter } from "../src/periphery/FeeRouter.sol";

/// @title FeeRouter Tests
/// @notice Tests for the GHOSTNET fee collection and buyback mechanism
contract FeeRouterTest is Test {
    DataToken public token;
    FeeRouter public feeRouter;
    MockSwapRouter public swapRouter;

    address public treasury = makeAddr("treasury");
    address public owner = makeAddr("owner");
    address public operationsWallet = makeAddr("operationsWallet");
    address public weth = makeAddr("weth");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public gameContract = makeAddr("gameContract");

    uint256 constant TOTAL_SUPPLY = 100_000_000 * 1e18;
    uint256 constant TOLL_AMOUNT = 0.001 ether; // ~$2 equivalent

    function setUp() public {
        // Deploy token
        address[] memory recipients = new address[](2);
        recipients[0] = treasury;
        recipients[1] = alice;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = TOTAL_SUPPLY - 1_000_000 * 1e18;
        amounts[1] = 1_000_000 * 1e18;

        token = new DataToken(treasury, owner, recipients, amounts);

        // Deploy mock swap router
        swapRouter = new MockSwapRouter(address(token));

        // Fund swap router with DATA for buybacks
        vm.prank(treasury);
        token.transfer(address(swapRouter), 10_000_000 * 1e18);

        // Deploy FeeRouter
        feeRouter = new FeeRouter(
            address(token), weth, address(swapRouter), operationsWallet, TOLL_AMOUNT, owner
        );

        // Authorize game contract as collector
        vm.prank(owner);
        feeRouter.setCollector(gameContract, true);

        // Fund test accounts with ETH
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(gameContract, 100 ether);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Constructor_SetsCorrectState() public view {
        assertEq(address(feeRouter.dataToken()), address(token));
        assertEq(feeRouter.weth(), weth);
        assertEq(feeRouter.swapRouter(), address(swapRouter));
        assertEq(feeRouter.operationsWallet(), operationsWallet);
        assertEq(feeRouter.tollAmount(), TOLL_AMOUNT);
        assertEq(feeRouter.owner(), owner);
    }

    function test_Constructor_RevertWhen_InvalidDataToken() public {
        vm.expectRevert(FeeRouter.InvalidAddress.selector);
        new FeeRouter(address(0), weth, address(swapRouter), operationsWallet, TOLL_AMOUNT, owner);
    }

    function test_Constructor_RevertWhen_InvalidWeth() public {
        vm.expectRevert(FeeRouter.InvalidAddress.selector);
        new FeeRouter(
            address(token), address(0), address(swapRouter), operationsWallet, TOLL_AMOUNT, owner
        );
    }

    function test_Constructor_RevertWhen_InvalidOperationsWallet() public {
        vm.expectRevert(FeeRouter.InvalidAddress.selector);
        new FeeRouter(address(token), weth, address(swapRouter), address(0), TOLL_AMOUNT, owner);
    }

    function test_Constructor_AllowsZeroSwapRouter() public {
        // Zero swap router is allowed (can be set later)
        FeeRouter router = new FeeRouter(
            address(token),
            weth,
            address(0), // Zero router
            operationsWallet,
            TOLL_AMOUNT,
            owner
        );
        assertEq(router.swapRouter(), address(0));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TOLL COLLECTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_CollectToll_Success() public {
        uint256 balanceBefore = address(feeRouter).balance;

        vm.prank(gameContract);
        feeRouter.collectToll{ value: TOLL_AMOUNT }(bytes32("jackIn"));

        assertEq(address(feeRouter).balance - balanceBefore, TOLL_AMOUNT);
    }

    function test_CollectToll_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit FeeRouter.TollCollected(gameContract, TOLL_AMOUNT, bytes32("jackIn"));

        vm.prank(gameContract);
        feeRouter.collectToll{ value: TOLL_AMOUNT }(bytes32("jackIn"));
    }

    function test_CollectToll_RevertWhen_Unauthorized() public {
        vm.prank(alice);
        vm.expectRevert(FeeRouter.Unauthorized.selector);
        feeRouter.collectToll{ value: TOLL_AMOUNT }(bytes32("jackIn"));
    }

    function test_CollectToll_RevertWhen_InsufficientToll() public {
        vm.prank(gameContract);
        vm.expectRevert(FeeRouter.TollRequired.selector);
        feeRouter.collectToll{ value: TOLL_AMOUNT - 1 }(bytes32("jackIn"));
    }

    function test_CollectToll_AcceptsExcessToll() public {
        uint256 excessAmount = TOLL_AMOUNT * 2;

        vm.prank(gameContract);
        feeRouter.collectToll{ value: excessAmount }(bytes32("jackIn"));

        assertEq(address(feeRouter).balance, excessAmount);
    }

    function test_Receive_DirectETHDeposit() public {
        vm.expectEmit(true, true, true, true);
        emit FeeRouter.TollCollected(alice, 1 ether, bytes32("direct"));

        vm.prank(alice);
        (bool success,) = address(feeRouter).call{ value: 1 ether }("");
        assertTrue(success);

        assertEq(address(feeRouter).balance, 1 ether);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BUYBACK EXECUTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_ExecuteBuyback_Success() public {
        // Collect some ETH
        vm.prank(alice);
        (bool success,) = address(feeRouter).call{ value: 10 ether }("");
        assertTrue(success);

        uint256 deadBefore = token.balanceOf(token.DEAD_ADDRESS());
        uint256 opsBefore = operationsWallet.balance;

        feeRouter.executeBuyback(0);

        // 90% buyback, 10% operations
        assertEq(operationsWallet.balance - opsBefore, 1 ether);

        // DATA should have been burned
        uint256 dataBurned = token.balanceOf(token.DEAD_ADDRESS()) - deadBefore;
        assertGt(dataBurned, 0);
    }

    function test_ExecuteBuyback_EmitsEvent() public {
        vm.prank(alice);
        (bool success,) = address(feeRouter).call{ value: 10 ether }("");
        assertTrue(success);

        // We can't predict exact dataReceived, but we know ETH amounts
        vm.expectEmit(true, false, false, false);
        emit FeeRouter.BuybackExecuted(9 ether, 0, 0); // Only check first param

        feeRouter.executeBuyback(0);
    }

    function test_ExecuteBuyback_UpdatesCounters() public {
        vm.prank(alice);
        (bool success,) = address(feeRouter).call{ value: 10 ether }("");
        assertTrue(success);

        uint256 totalBurnedBefore = feeRouter.totalBurned();

        feeRouter.executeBuyback(0);

        assertEq(feeRouter.totalSentToOperations(), 1 ether);
        assertEq(feeRouter.totalCollectedForBuyback(), 9 ether);
        assertGt(feeRouter.totalBurned(), totalBurnedBefore);
    }

    function test_ExecuteBuyback_RevertWhen_InsufficientBalance() public {
        vm.expectRevert(FeeRouter.InsufficientBalance.selector);
        feeRouter.executeBuyback(0);
    }

    function test_ExecuteBuyback_WithSlippageProtection() public {
        vm.prank(alice);
        (bool success,) = address(feeRouter).call{ value: 10 ether }("");
        assertTrue(success);

        // Request minimum DATA out - if not met, should revert
        // Mock returns 1000 DATA per ETH, so 9 ETH = 9000 DATA
        vm.expectRevert(FeeRouter.SwapFailed.selector);
        feeRouter.executeBuyback(100_000 * 1e18); // Asking for too much
    }

    function test_ExecuteBuyback_NoRouterConfigured() public {
        // Deploy new FeeRouter without swap router
        FeeRouter routerNoSwap = new FeeRouter(
            address(token),
            weth,
            address(0), // No router
            operationsWallet,
            TOLL_AMOUNT,
            owner
        );

        // Send ETH
        vm.prank(alice);
        (bool success,) = address(routerNoSwap).call{ value: 10 ether }("");
        assertTrue(success);

        uint256 opsBefore = operationsWallet.balance;

        // Execute buyback - should only send operations share
        routerNoSwap.executeBuyback(0);

        // Operations gets 10%
        assertEq(operationsWallet.balance - opsBefore, 1 ether);

        // Buyback amount tracked but ETH stays in contract (no swap)
        assertEq(routerNoSwap.totalCollectedForBuyback(), 9 ether);
        assertEq(address(routerNoSwap).balance, 9 ether);
    }

    function test_ExecuteBuyback_OperationsTransferFailed() public {
        // Deploy with rejecting operations wallet
        RejectingWallet rejectWallet = new RejectingWallet();
        FeeRouter routerReject = new FeeRouter(
            address(token), weth, address(swapRouter), address(rejectWallet), TOLL_AMOUNT, owner
        );

        vm.prank(alice);
        (bool success,) = address(routerReject).call{ value: 10 ether }("");
        assertTrue(success);

        vm.expectRevert(FeeRouter.TransferFailed.selector);
        routerReject.executeBuyback(0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BUYBACK WITH CUSTOM DATA TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_ExecuteBuybackWithData_Success() public {
        vm.prank(alice);
        (bool success,) = address(feeRouter).call{ value: 10 ether }("");
        assertTrue(success);

        // Create custom swap data
        bytes memory swapData = abi.encodeWithSignature("customSwap()");

        uint256 deadBefore = token.balanceOf(token.DEAD_ADDRESS());

        feeRouter.executeBuybackWithData(swapData, 0);

        // DATA should have been burned
        uint256 dataBurned = token.balanceOf(token.DEAD_ADDRESS()) - deadBefore;
        assertGt(dataBurned, 0);
    }

    function test_ExecuteBuybackWithData_RevertWhen_NoRouter() public {
        FeeRouter routerNoSwap =
            new FeeRouter(address(token), weth, address(0), operationsWallet, TOLL_AMOUNT, owner);

        vm.prank(alice);
        (bool success,) = address(routerNoSwap).call{ value: 10 ether }("");
        assertTrue(success);

        vm.expectRevert(FeeRouter.InvalidAddress.selector);
        routerNoSwap.executeBuybackWithData(bytes(""), 0);
    }

    function test_ExecuteBuybackWithData_RevertWhen_InsufficientBalance() public {
        vm.expectRevert(FeeRouter.InsufficientBalance.selector);
        feeRouter.executeBuybackWithData(bytes(""), 0);
    }

    function test_ExecuteBuybackWithData_RevertWhen_SwapFails() public {
        vm.prank(alice);
        (bool success,) = address(feeRouter).call{ value: 10 ether }("");
        assertTrue(success);

        // Make router fail
        swapRouter.setShouldFail(true);

        vm.expectRevert(FeeRouter.SwapFailed.selector);
        feeRouter.executeBuybackWithData(bytes("customSwap()"), 0);
    }

    function test_ExecuteBuybackWithData_RevertWhen_SlippageNotMet() public {
        vm.prank(alice);
        (bool success,) = address(feeRouter).call{ value: 10 ether }("");
        assertTrue(success);

        // Router returns some DATA, but we ask for more
        vm.expectRevert(FeeRouter.SwapFailed.selector);
        feeRouter.executeBuybackWithData(bytes("customSwap()"), 100_000 * 1e18);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_PendingBuyback() public {
        assertEq(feeRouter.pendingBuyback(), 0);

        vm.prank(alice);
        (bool success,) = address(feeRouter).call{ value: 5 ether }("");
        assertTrue(success);

        assertEq(feeRouter.pendingBuyback(), 5 ether);
    }

    function test_PreviewSplit() public {
        vm.prank(alice);
        (bool success,) = address(feeRouter).call{ value: 10 ether }("");
        assertTrue(success);

        (uint256 buybackAmount, uint256 operationsAmount) = feeRouter.previewSplit();

        assertEq(buybackAmount, 9 ether); // 90%
        assertEq(operationsAmount, 1 ether); // 10%
    }

    function test_PreviewSplit_ZeroBalance() public view {
        (uint256 buybackAmount, uint256 operationsAmount) = feeRouter.previewSplit();
        assert(buybackAmount == 0);
        assert(operationsAmount == 0);
    }

    function test_Constants() public view {
        assertEq(feeRouter.BUYBACK_SHARE_BPS(), 9000);
        assertEq(feeRouter.OPERATIONS_SHARE_BPS(), 1000);
        assertEq(feeRouter.DEAD_ADDRESS(), 0x000000000000000000000000000000000000dEaD);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTION TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_SetCollector_Success() public {
        address newCollector = makeAddr("newCollector");

        vm.prank(owner);
        feeRouter.setCollector(newCollector, true);

        assertTrue(feeRouter.authorizedCollectors(newCollector));
    }

    function test_SetCollector_CanRevoke() public {
        vm.prank(owner);
        feeRouter.setCollector(gameContract, false);

        assertFalse(feeRouter.authorizedCollectors(gameContract));
    }

    function test_SetCollector_RevertWhen_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        feeRouter.setCollector(alice, true);
    }

    function test_SetCollector_RevertWhen_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(FeeRouter.InvalidAddress.selector);
        feeRouter.setCollector(address(0), true);
    }

    function test_SetSwapRouter_Success() public {
        address newRouter = makeAddr("newRouter");

        vm.expectEmit(true, true, true, true);
        emit FeeRouter.SwapRouterUpdated(newRouter);

        vm.prank(owner);
        feeRouter.setSwapRouter(newRouter);

        assertEq(feeRouter.swapRouter(), newRouter);
    }

    function test_SetSwapRouter_RevertWhen_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        feeRouter.setSwapRouter(address(0));
    }

    function test_SetTollAmount_Success() public {
        uint256 newAmount = 0.002 ether;

        vm.expectEmit(true, true, true, true);
        emit FeeRouter.TollAmountUpdated(newAmount);

        vm.prank(owner);
        feeRouter.setTollAmount(newAmount);

        assertEq(feeRouter.tollAmount(), newAmount);
    }

    function test_SetTollAmount_RevertWhen_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        feeRouter.setTollAmount(0.002 ether);
    }

    function test_SetOperationsWallet_Success() public {
        address newWallet = makeAddr("newOpsWallet");

        vm.expectEmit(true, true, true, true);
        emit FeeRouter.OperationsWalletUpdated(newWallet);

        vm.prank(owner);
        feeRouter.setOperationsWallet(newWallet);

        assertEq(feeRouter.operationsWallet(), newWallet);
    }

    function test_SetOperationsWallet_RevertWhen_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        feeRouter.setOperationsWallet(alice);
    }

    function test_SetOperationsWallet_RevertWhen_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(FeeRouter.InvalidAddress.selector);
        feeRouter.setOperationsWallet(address(0));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EMERGENCY WITHDRAW TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function test_EmergencyWithdrawETH_Success() public {
        vm.prank(alice);
        (bool success,) = address(feeRouter).call{ value: 10 ether }("");
        assertTrue(success);

        address recipient = makeAddr("recipient");
        uint256 balanceBefore = recipient.balance;

        vm.prank(owner);
        feeRouter.emergencyWithdrawETH(recipient);

        assertEq(recipient.balance - balanceBefore, 10 ether);
        assertEq(address(feeRouter).balance, 0);
    }

    function test_EmergencyWithdrawETH_RevertWhen_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        feeRouter.emergencyWithdrawETH(alice);
    }

    function test_EmergencyWithdrawETH_RevertWhen_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(FeeRouter.InvalidAddress.selector);
        feeRouter.emergencyWithdrawETH(address(0));
    }

    function test_EmergencyWithdrawETH_RevertWhen_TransferFails() public {
        vm.prank(alice);
        (bool success,) = address(feeRouter).call{ value: 10 ether }("");
        assertTrue(success);

        RejectingWallet rejectWallet = new RejectingWallet();

        vm.prank(owner);
        vm.expectRevert(FeeRouter.TransferFailed.selector);
        feeRouter.emergencyWithdrawETH(address(rejectWallet));
    }

    function test_EmergencyWithdrawTokens_Success() public {
        // Exclude FeeRouter from tax to get exact amounts
        vm.prank(owner);
        token.setTaxExclusion(address(feeRouter), true);

        // Send some tokens to FeeRouter
        vm.prank(treasury);
        token.transfer(address(feeRouter), 1000 * 1e18);

        address recipient = makeAddr("recipient");

        vm.prank(owner);
        feeRouter.emergencyWithdrawTokens(address(token), recipient);

        // Recipient receives entire FeeRouter balance (may have tax applied on withdrawal)
        assertGt(token.balanceOf(recipient), 0);
        assertEq(token.balanceOf(address(feeRouter)), 0);
    }

    function test_EmergencyWithdrawTokens_RevertWhen_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        feeRouter.emergencyWithdrawTokens(address(token), alice);
    }

    function test_EmergencyWithdrawTokens_RevertWhen_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(FeeRouter.InvalidAddress.selector);
        feeRouter.emergencyWithdrawTokens(address(token), address(0));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FUZZ TESTS
    // ══════════════════════════════════════════════════════════════════════════════

    function testFuzz_TollCollection(
        uint256 amount
    ) public {
        vm.assume(amount >= TOLL_AMOUNT && amount <= 100 ether);

        vm.deal(gameContract, amount);

        vm.prank(gameContract);
        feeRouter.collectToll{ value: amount }(bytes32("fuzz"));

        assertEq(address(feeRouter).balance, amount);
    }

    function testFuzz_PreviewSplit_Correct(
        uint256 balance
    ) public {
        vm.assume(balance > 0 && balance <= 1000 ether);

        vm.deal(alice, balance);
        vm.prank(alice);
        (bool success,) = address(feeRouter).call{ value: balance }("");
        assertTrue(success);

        (uint256 buyback, uint256 ops) = feeRouter.previewSplit();

        // Verify 90/10 split
        assertEq(buyback, (balance * 9000) / 10_000);
        assertEq(ops, balance - buyback);
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MOCK CONTRACTS
// ══════════════════════════════════════════════════════════════════════════════

/// @dev Mock swap router for testing buyback functionality
contract MockSwapRouter {
    IERC20 public immutable dataToken;
    bool public shouldFail;

    // Return rate: 1000 DATA per ETH
    uint256 public constant RATE = 1000;

    constructor(
        address _dataToken
    ) {
        dataToken = IERC20(_dataToken);
    }

    function setShouldFail(
        bool _shouldFail
    ) external {
        shouldFail = _shouldFail;
    }

    // Handle standard Uniswap V2 style swap
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata,
        address to,
        uint256
    ) external payable returns (uint256[] memory amounts) {
        if (shouldFail) revert("Swap failed");

        uint256 dataOut = msg.value * RATE;
        if (dataOut < amountOutMin) revert("Insufficient output");

        dataToken.transfer(to, dataOut);

        amounts = new uint256[](2);
        amounts[0] = msg.value;
        amounts[1] = dataOut;
    }

    // Handle custom swap calls
    function customSwap() external payable {
        if (shouldFail) revert("Swap failed");

        uint256 dataOut = msg.value * RATE;
        dataToken.transfer(msg.sender, dataOut);
    }

    // Fallback for any other calls
    fallback() external payable {
        if (shouldFail) revert("Swap failed");

        uint256 dataOut = msg.value * RATE;
        dataToken.transfer(msg.sender, dataOut);
    }

    receive() external payable { }
}

/// @dev Wallet that rejects ETH transfers
contract RejectingWallet {
    receive() external payable {
        revert("No ETH accepted");
    }
}
