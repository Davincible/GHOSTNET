// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title FeeRouter
/// @notice Collects ETH tolls and executes buyback + burn
/// @dev Toll flow: ETH → 90% buyback (swap to DATA + burn) + 10% operations
///
/// The contract collects ETH fees from game actions and periodically:
/// 1. Swaps 90% of accumulated ETH to DATA via DEX
/// 2. Burns the received DATA tokens
/// 3. Sends 10% to operations wallet
///
/// DEX integration is abstracted via ISwapRouter interface to support
/// different DEXes (Bronto, Bebop, Uniswap-style, etc.)
///
/// @custom:security-contact security@ghostnet.game
contract FeeRouter is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    error InvalidAddress();
    error InvalidAmount();
    error InsufficientBalance();
    error SwapFailed();
    error TransferFailed();
    error TollRequired();
    error Unauthorized();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when toll is collected
    event TollCollected(address indexed from, uint256 amount, bytes32 indexed reason);

    /// @notice Emitted when buyback is executed
    event BuybackExecuted(uint256 ethSpent, uint256 dataReceived, uint256 dataBurned);

    /// @notice Emitted when operations funds are withdrawn
    event OperationsWithdrawn(address indexed to, uint256 amount);

    /// @notice Emitted when swap router is updated
    event SwapRouterUpdated(address indexed newRouter);

    /// @notice Emitted when toll amount is updated
    event TollAmountUpdated(uint256 newAmount);

    /// @notice Emitted when operations wallet is updated
    event OperationsWalletUpdated(address indexed newWallet);

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Buyback share (90%)
    uint16 public constant BUYBACK_SHARE_BPS = 9000;

    /// @notice Operations share (10%)
    uint16 public constant OPERATIONS_SHARE_BPS = 1000;

    /// @notice Basis points denominator
    uint16 private constant BPS = 10_000;

    /// @notice Dead address for burns
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice DATA token
    IERC20 public immutable dataToken;

    /// @notice WETH token (for DEX swaps)
    address public immutable weth;

    /// @notice Swap router address (Uniswap-style or custom)
    address public swapRouter;

    /// @notice Operations wallet
    address public operationsWallet;

    /// @notice Default toll amount in wei ($2 equivalent, adjustable)
    uint256 public tollAmount;

    /// @notice Total ETH collected for buyback
    uint256 public totalCollectedForBuyback;

    /// @notice Total ETH sent to operations
    uint256 public totalSentToOperations;

    /// @notice Total DATA burned via buyback
    uint256 public totalBurned;

    /// @notice Authorized toll collectors (game contracts)
    mapping(address collector => bool authorized) public authorizedCollectors;

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Deploy the fee router
    /// @param _dataToken Address of DATA token
    /// @param _weth Address of WETH token
    /// @param _swapRouter Address of swap router (can be zero initially)
    /// @param _operationsWallet Address to receive operations share
    /// @param _tollAmount Initial toll amount in wei
    /// @param _owner Contract owner
    constructor(
        address _dataToken,
        address _weth,
        address _swapRouter,
        address _operationsWallet,
        uint256 _tollAmount,
        address _owner
    ) Ownable(_owner) {
        if (_dataToken == address(0) || _weth == address(0)) revert InvalidAddress();
        if (_operationsWallet == address(0)) revert InvalidAddress();

        dataToken = IERC20(_dataToken);
        weth = _weth;
        swapRouter = _swapRouter;
        operationsWallet = _operationsWallet;
        tollAmount = _tollAmount;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // TOLL COLLECTION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Collect toll from a user
    /// @dev Called by authorized game contracts
    /// @param reason Identifier for the toll reason (for analytics)
    function collectToll(bytes32 reason) external payable {
        if (!authorizedCollectors[msg.sender]) revert Unauthorized();
        if (msg.value < tollAmount) revert TollRequired();

        emit TollCollected(msg.sender, msg.value, reason);
    }

    /// @notice Receive ETH directly (for manual deposits or refunds)
    receive() external payable {
        emit TollCollected(msg.sender, msg.value, bytes32("direct"));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // BUYBACK EXECUTION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Execute buyback with accumulated ETH
    /// @dev Can be called by anyone (keeper or user)
    /// @param minDataOut Minimum DATA to receive (slippage protection)
    function executeBuyback(uint256 minDataOut) external nonReentrant {
        uint256 ethBalance = address(this).balance;
        if (ethBalance == 0) revert InsufficientBalance();

        // Calculate splits
        uint256 buybackAmount = (ethBalance * BUYBACK_SHARE_BPS) / BPS;
        uint256 operationsAmount = ethBalance - buybackAmount;

        // Send operations share
        if (operationsAmount > 0) {
            totalSentToOperations += operationsAmount;
            (bool success,) = operationsWallet.call{ value: operationsAmount }("");
            if (!success) revert TransferFailed();
            emit OperationsWithdrawn(operationsWallet, operationsAmount);
        }

        // Execute buyback if router is configured
        if (buybackAmount > 0 && swapRouter != address(0)) {
            totalCollectedForBuyback += buybackAmount;

            uint256 dataReceived = _executeSwap(buybackAmount, minDataOut);

            // Burn received DATA
            if (dataReceived > 0) {
                totalBurned += dataReceived;
                dataToken.safeTransfer(DEAD_ADDRESS, dataReceived);
            }

            emit BuybackExecuted(buybackAmount, dataReceived, dataReceived);
        } else if (buybackAmount > 0) {
            // No router configured - hold ETH for later
            totalCollectedForBuyback += buybackAmount;
        }
    }

    /// @notice Execute buyback with custom swap data (for aggregator swaps)
    /// @param swapData Encoded swap calldata for the router
    /// @param minDataOut Minimum DATA to receive
    function executeBuybackWithData(bytes calldata swapData, uint256 minDataOut)
        external
        nonReentrant
    {
        uint256 ethBalance = address(this).balance;
        if (ethBalance == 0) revert InsufficientBalance();
        if (swapRouter == address(0)) revert InvalidAddress();

        // Calculate splits
        uint256 buybackAmount = (ethBalance * BUYBACK_SHARE_BPS) / BPS;
        uint256 operationsAmount = ethBalance - buybackAmount;

        // Send operations share
        if (operationsAmount > 0) {
            totalSentToOperations += operationsAmount;
            (bool success,) = operationsWallet.call{ value: operationsAmount }("");
            if (!success) revert TransferFailed();
        }

        // Execute custom swap
        if (buybackAmount > 0) {
            totalCollectedForBuyback += buybackAmount;

            uint256 dataBefore = dataToken.balanceOf(address(this));

            (bool success,) = swapRouter.call{ value: buybackAmount }(swapData);
            if (!success) revert SwapFailed();

            uint256 dataReceived = dataToken.balanceOf(address(this)) - dataBefore;
            if (dataReceived < minDataOut) revert SwapFailed();

            // Burn received DATA
            if (dataReceived > 0) {
                totalBurned += dataReceived;
                dataToken.safeTransfer(DEAD_ADDRESS, dataReceived);
            }

            emit BuybackExecuted(buybackAmount, dataReceived, dataReceived);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get pending ETH balance available for buyback
    function pendingBuyback() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Calculate buyback and operations amounts for current balance
    function previewSplit()
        external
        view
        returns (uint256 buybackAmount, uint256 operationsAmount)
    {
        uint256 balance = address(this).balance;
        buybackAmount = (balance * BUYBACK_SHARE_BPS) / BPS;
        operationsAmount = balance - buybackAmount;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Set authorized toll collector
    function setCollector(address collector, bool authorized) external onlyOwner {
        if (collector == address(0)) revert InvalidAddress();
        authorizedCollectors[collector] = authorized;
    }

    /// @notice Update swap router
    function setSwapRouter(address newRouter) external onlyOwner {
        swapRouter = newRouter;
        emit SwapRouterUpdated(newRouter);
    }

    /// @notice Update toll amount
    function setTollAmount(uint256 newAmount) external onlyOwner {
        tollAmount = newAmount;
        emit TollAmountUpdated(newAmount);
    }

    /// @notice Update operations wallet
    function setOperationsWallet(address newWallet) external onlyOwner {
        if (newWallet == address(0)) revert InvalidAddress();
        operationsWallet = newWallet;
        emit OperationsWalletUpdated(newWallet);
    }

    /// @notice Emergency withdraw ETH (in case of migration)
    function emergencyWithdrawETH(address recipient) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        uint256 balance = address(this).balance;
        (bool success,) = recipient.call{ value: balance }("");
        if (!success) revert TransferFailed();
    }

    /// @notice Emergency withdraw tokens (in case of migration)
    function emergencyWithdrawTokens(address token, address recipient) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(recipient, balance);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @dev Execute swap via configured router
    /// @notice Override this for different DEX integrations
    function _executeSwap(uint256 ethAmount, uint256 minDataOut)
        internal
        virtual
        returns (uint256 dataReceived)
    {
        // Default implementation for Uniswap V2/V3 style routers
        // This should be overridden for specific DEX integrations

        uint256 dataBefore = dataToken.balanceOf(address(this));

        // Encode basic swap: ETH -> WETH -> DATA
        // This is a simplified example - real implementation would use proper router interface
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = address(dataToken);

        // Call router (this assumes Uniswap V2 style interface)
        // swapExactETHForTokens(uint amountOutMin, address[] path, address to, uint deadline)
        bytes memory callData = abi.encodeWithSignature(
            "swapExactETHForTokens(uint256,address[],address,uint256)",
            minDataOut,
            path,
            address(this),
            block.timestamp + 300 // 5 minute deadline
        );

        (bool success,) = swapRouter.call{ value: ethAmount }(callData);
        if (!success) revert SwapFailed();

        dataReceived = dataToken.balanceOf(address(this)) - dataBefore;
        if (dataReceived < minDataOut) revert SwapFailed();
    }
}
