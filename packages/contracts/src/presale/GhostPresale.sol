// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { UD60x18, ud } from "@prb/math/UD60x18.sol";
import { IGhostPresale } from "./interfaces/IGhostPresale.sol";

/// @title GhostPresale
/// @notice GHOSTNET presale contract — accepts ETH and tracks $DATA allocations
/// @dev IMMUTABLE — not upgradeable, no selfdestruct. Supports two pricing modes:
///      ascending tranches or a linear bonding curve, selected at deployment.
///
///      State machine: PENDING → OPEN → FINALIZED (happy path)
///                                    → REFUNDING  (emergency / dead-man's switch)
///      FINALIZED and REFUNDING are terminal — no further transitions.
///
///      All ETH transfers use low-level `call` — never `transfer` or `send`.
///      No `receive()` or `fallback()` — direct ETH transfers revert.
///
/// @custom:security-contact security@ghostnet.game
contract GhostPresale is Ownable2Step, ReentrancyGuard, Pausable, IGhostPresale {
    // ══════════════════════════════════════════════════════════════════════════════
    // ENUMS
    // ══════════════════════════════════════════════════════════════════════════════

    enum PricingMode {
        TRANCHE,
        BONDING_CURVE
    }

    enum PresaleState {
        PENDING,
        OPEN,
        FINALIZED,
        REFUNDING
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ══════════════════════════════════════════════════════════════════════════════

    struct TrancheConfig {
        uint256 supply;
        uint256 pricePerToken;
    }

    struct CurveConfig {
        uint256 startPrice;
        uint256 endPrice;
        uint256 totalSupply;
    }

    struct PresaleConfig {
        uint256 minContribution;
        uint256 maxContribution;
        uint256 maxPerWallet;
        bool allowMultipleContributions;
        uint256 startTime;
        uint256 endTime;
        uint256 emergencyDeadline;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    error PresaleNotOpen();
    error PresaleNotPending();
    error PresaleNotFinalized();
    error PresaleNotRefunding();
    error InvalidState(PresaleState current, PresaleState required);
    error BelowMinContribution(uint256 sent, uint256 minimum);
    error AboveMaxContribution(uint256 sent, uint256 maximum);
    error WalletCapExceeded(uint256 total, uint256 cap);
    error MultipleContributionsNotAllowed();
    error PresaleSoldOut();
    error AllocationBelowMinimum(uint256 allocation, uint256 minAllocation);
    error ZeroTrancheSupply();
    error InvalidTranchePrice();
    error InvalidCurveParams();
    error EndPriceMustExceedStartPrice();
    error NoContribution();
    error InvalidAddress();
    error NoEndTimeSet();
    error InvalidEndTime(uint256 newEndTime, uint256 currentEndTime);
    error EmergencyDeadlineNotReached(uint256 current, uint256 deadline);
    error PricingNotConfigured();
    error EmergencyDeadlineNotSet();
    error ETHRefundFailed();
    error NoETHToWithdraw();
    error WrongPricingMode();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when a user contributes ETH and receives a $DATA allocation
    event Contributed(
        address indexed contributor,
        uint256 ethAmount,
        uint256 dataAllocation,
        uint256 avgPrice,
        uint256 spotPrice
    );

    /// @notice Emitted when the presale transitions to OPEN
    event PresaleOpened(uint256 timestamp);

    /// @notice Emitted when the presale is finalized
    event PresaleFinalized(uint256 totalRaised, uint256 totalSold, uint256 contributors);

    /// @notice Emitted when presale configuration is updated
    event ConfigUpdated(PresaleConfig config);

    /// @notice Emitted when a tranche is fully sold and pricing advances
    event TrancheCompleted(uint256 indexed trancheIndex, uint256 nextPrice);

    /// @notice Emitted when the owner enables refunds
    event RefundsEnabled();

    /// @notice Emitted when a contributor claims a refund
    event Refunded(address indexed contributor, uint256 ethAmount);

    /// @notice Emitted when all tranches are cleared
    event TranchesCleared();

    /// @notice Emitted when the owner withdraws raised ETH
    event ETHWithdrawn(address indexed to, uint256 amount);

    /// @notice Emitted when the presale end time is extended
    event EndTimeExtended(uint256 oldEndTime, uint256 newEndTime);

    /// @notice Emitted when the dead-man's switch is triggered
    event EmergencyRefundsTriggered(address indexed triggeredBy, uint256 timestamp);

    // ══════════════════════════════════════════════════════════════════════════════
    // IMMUTABLES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Pricing mode selected at deployment (TRANCHE or BONDING_CURVE)
    PricingMode public immutable pricingMode;

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Current presale state
    PresaleState public state;

    /// @notice Timestamp when open() was called (used for emergency deadline)
    uint256 public openedAt;

    /// @notice All configurable presale parameters
    PresaleConfig public config;

    /// @notice Tranche definitions (TRANCHE mode only)
    TrancheConfig[] public tranches;

    /// @notice Bonding curve definition (BONDING_CURVE mode only)
    CurveConfig public curve;

    /// @notice ETH contributed per address
    mapping(address account => uint256 amount) public contributions;

    /// @notice $DATA allocated per address
    mapping(address account => uint256 amount) public allocations;

    /// @notice Total ETH received
    uint256 public totalRaised;

    /// @notice Total $DATA allocated — single source of truth
    uint256 public totalSold;

    /// @notice Number of unique contributors
    uint256 public contributorCount;

    /// @dev Cached total presale supply (updated by addTranche, clearTranches, setCurve)
    uint256 private _cachedTotalSupply;

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Deploy the presale contract
    /// @param _pricingMode TRANCHE or BONDING_CURVE — immutable after deployment
    /// @param _initialOwner Address that will own the contract
    constructor(PricingMode _pricingMode, address _initialOwner) Ownable(_initialOwner) {
        pricingMode = _pricingMode;
        // state defaults to PENDING (0)
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // USER FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Contribute ETH to the presale
    /// @param minAllocation Minimum $DATA the caller expects; reverts if actual < this (slippage protection)
    /// @dev Computes $DATA allocation based on pricing mode.
    ///      When contribution exceeds remaining supply, allocates remaining tokens and refunds excess ETH.
    ///      Increments contributorCount only when allocations[msg.sender] was previously 0.
    /// @return allocation Amount of $DATA allocated for this contribution
    function contribute(uint256 minAllocation) external payable nonReentrant whenNotPaused returns (uint256 allocation) {
        // --- Checks ---

        if (state != PresaleState.OPEN) revert PresaleNotOpen();

        if (config.startTime != 0 && block.timestamp < config.startTime) {
            revert PresaleNotOpen();
        }
        if (config.endTime != 0 && block.timestamp > config.endTime) {
            revert PresaleNotOpen();
        }

        uint256 ethAmount = msg.value;
        uint256 supply = totalPresaleSupply();

        if (totalSold >= supply) revert PresaleSoldOut();

        if (config.minContribution != 0 && ethAmount < config.minContribution) {
            revert BelowMinContribution(ethAmount, config.minContribution);
        }
        if (config.maxContribution != 0 && ethAmount > config.maxContribution) {
            revert AboveMaxContribution(ethAmount, config.maxContribution);
        }

        if (!config.allowMultipleContributions && allocations[msg.sender] > 0) {
            revert MultipleContributionsNotAllowed();
        }

        uint256 newWalletTotal = contributions[msg.sender] + ethAmount;
        if (config.maxPerWallet != 0 && newWalletTotal > config.maxPerWallet) {
            revert WalletCapExceeded(newWalletTotal, config.maxPerWallet);
        }

        // --- Compute allocation ---

        uint256 ethSpent;
        if (pricingMode == PricingMode.TRANCHE) {
            (allocation, ethSpent) = _computeTrancheAllocation(ethAmount);
        } else {
            (allocation, ethSpent) = _computeCurveAllocation(ethAmount);
        }

        // --- Slippage check ---

        if (allocation < minAllocation) {
            revert AllocationBelowMinimum(allocation, minAllocation);
        }

        // --- Effects ---

        bool isNewContributor = allocations[msg.sender] == 0;

        contributions[msg.sender] += ethSpent;
        allocations[msg.sender] += allocation;
        totalRaised += ethSpent;
        totalSold += allocation;

        if (isNewContributor) {
            contributorCount++;
        }

        // --- Interactions ---

        // Refund excess ETH if partial fill
        uint256 refundAmount = ethAmount - ethSpent;
        if (refundAmount > 0) {
            (bool success,) = payable(msg.sender).call{ value: refundAmount }("");
            if (!success) revert ETHRefundFailed();
        }

        // Emit with avg price and spot price after contribution
        uint256 avgPrice = (allocation > 0) ? (ethSpent * 1e18) / allocation : 0;
        uint256 spotPrice = currentPrice();

        emit Contributed(msg.sender, ethSpent, allocation, avgPrice, spotPrice);
    }

    /// @notice Preview how much $DATA a given ETH amount would buy at current state (estimate)
    /// @param ethAmount Amount of ETH to simulate
    /// @return dataAmount Estimated $DATA allocation
    /// @return priceImpact Price change percentage (bonding curve only, 0 for tranches)
    /// @dev For bonding curve mode, the actual ETH spent may differ slightly due to rounding verification in contribute(). Use as an estimate only.
    function preview(uint256 ethAmount) external view returns (uint256 dataAmount, uint256 priceImpact) {
        if (pricingMode == PricingMode.TRANCHE) {
            (dataAmount,) = _previewTrancheAllocation(ethAmount, totalSold);
            priceImpact = 0;
        } else {
            uint256 priceBefore = _curveSpotPrice(totalSold);
            dataAmount = _curveTokensForETH(ethAmount, totalSold);
            uint256 remaining = curve.totalSupply - totalSold;
            if (dataAmount > remaining) dataAmount = remaining;
            uint256 priceAfter = _curveSpotPrice(totalSold + dataAmount);
            // Price impact in basis points (1e18 = 100%)
            priceImpact = priceBefore > 0 ? ((priceAfter - priceBefore) * 1e18) / priceBefore : 0;
        }
    }

    /// @notice Get current price per $DATA
    /// @return price Current price in ETH (wei per 1e18 $DATA)
    function currentPrice() public view returns (uint256 price) {
        if (pricingMode == PricingMode.TRANCHE) {
            price = _currentTranchePrice();
        } else {
            price = _curveSpotPrice(totalSold);
        }
    }

    /// @notice Get full presale progress info
    /// @return raised Total ETH raised
    /// @return sold Total $DATA sold
    /// @return supply Total $DATA available
    /// @return price Current price
    /// @return contributors Number of unique contributors
    function progress()
        external
        view
        returns (uint256 raised, uint256 sold, uint256 supply, uint256 price, uint256 contributors)
    {
        raised = totalRaised;
        sold = totalSold;
        supply = totalPresaleSupply();
        price = currentPrice();
        contributors = contributorCount;
    }

    /// @notice Get total presale supply across all tranches or curve
    /// @return supply Total $DATA available in the presale
    function totalPresaleSupply() public view returns (uint256 supply) {
        supply = _cachedTotalSupply;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // OWNER FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Set presale configuration
    /// @dev Only callable in PENDING state
    /// @param _config The new presale configuration
    function setConfig(PresaleConfig calldata _config) external onlyOwner {
        if (state != PresaleState.PENDING) revert PresaleNotPending();
        config = _config;
        emit ConfigUpdated(_config);
    }

    /// @notice Extend the presale end time
    /// @dev Callable in OPEN state. New end time must be > current end time.
    /// @param newEndTime The new end time (unix timestamp)
    function extendEndTime(uint256 newEndTime) external onlyOwner {
        if (state != PresaleState.OPEN) revert PresaleNotOpen();
        if (config.endTime == 0) revert NoEndTimeSet();
        if (newEndTime <= config.endTime) revert InvalidEndTime(newEndTime, config.endTime);

        uint256 oldEndTime = config.endTime;
        config.endTime = newEndTime;

        emit EndTimeExtended(oldEndTime, newEndTime);
    }

    /// @notice Add a tranche (TRANCHE mode only, PENDING state)
    /// @dev Price must be > previous tranche price (strictly ascending)
    /// @param supply $DATA available in this tranche
    /// @param pricePerToken ETH per 1e18 $DATA
    function addTranche(uint256 supply, uint256 pricePerToken) external onlyOwner {
        if (state != PresaleState.PENDING) revert PresaleNotPending();
        if (pricingMode != PricingMode.TRANCHE) revert WrongPricingMode();
        if (supply == 0) revert ZeroTrancheSupply();
        if (pricePerToken == 0) revert InvalidTranchePrice();

        uint256 len = tranches.length;
        if (len > 0 && pricePerToken <= tranches[len - 1].pricePerToken) {
            revert InvalidTranchePrice();
        }

        tranches.push(TrancheConfig({ supply: supply, pricePerToken: pricePerToken }));
        _cachedTotalSupply += supply;
    }

    /// @notice Remove all tranches and re-add (for reconfiguration)
    /// @dev Only callable in PENDING state
    function clearTranches() external onlyOwner {
        if (state != PresaleState.PENDING) revert PresaleNotPending();
        if (pricingMode != PricingMode.TRANCHE) revert WrongPricingMode();
        _cachedTotalSupply = 0;
        delete tranches;
        emit TranchesCleared();
    }

    /// @notice Set bonding curve parameters (BONDING_CURVE mode only, PENDING state)
    /// @dev Reverts with EndPriceMustExceedStartPrice if endPrice <= startPrice
    /// @param startPrice ETH per 1e18 $DATA at sold=0
    /// @param endPrice ETH per 1e18 $DATA at sold=totalSupply
    /// @param _totalSupply Total $DATA available on curve
    function setCurve(uint256 startPrice, uint256 endPrice, uint256 _totalSupply) external onlyOwner {
        if (state != PresaleState.PENDING) revert PresaleNotPending();
        if (pricingMode != PricingMode.BONDING_CURVE) revert WrongPricingMode();
        if (_totalSupply == 0 || startPrice == 0) revert InvalidCurveParams();
        if (endPrice <= startPrice) revert EndPriceMustExceedStartPrice();

        curve = CurveConfig({ startPrice: startPrice, endPrice: endPrice, totalSupply: _totalSupply });
        _cachedTotalSupply = _totalSupply;
    }

    /// @notice Open the presale for contributions
    /// @dev Transitions: PENDING → OPEN. Sets openedAt = block.timestamp.
    ///      Validates pricing is configured.
    function open() external onlyOwner {
        if (state != PresaleState.PENDING) revert PresaleNotPending();
        if (config.emergencyDeadline == 0) revert EmergencyDeadlineNotSet();

        if (pricingMode == PricingMode.TRANCHE) {
            if (tranches.length == 0) revert PricingNotConfigured();
        } else {
            if (curve.totalSupply == 0 || curve.startPrice == 0 || curve.endPrice <= curve.startPrice) {
                revert PricingNotConfigured();
            }
        }

        state = PresaleState.OPEN;
        openedAt = block.timestamp;

        emit PresaleOpened(block.timestamp);
    }

    /// @notice Finalize the presale — no more contributions
    /// @dev Transitions: OPEN → FINALIZED (terminal)
    function finalize() external onlyOwner {
        if (state != PresaleState.OPEN) {
            revert InvalidState(state, PresaleState.OPEN);
        }

        state = PresaleState.FINALIZED;

        emit PresaleFinalized(totalRaised, totalSold, contributorCount);
    }

    /// @notice Withdraw raised ETH (only after finalized)
    /// @dev Uses low-level call for ETH transfer
    /// @param to Address to receive the ETH
    function withdrawETH(address to) external onlyOwner {
        if (state != PresaleState.FINALIZED) revert PresaleNotFinalized();
        if (to == address(0)) revert InvalidAddress();

        uint256 amount = address(this).balance;
        if (amount == 0) revert NoETHToWithdraw();

        (bool success,) = payable(to).call{ value: amount }("");
        if (!success) revert ETHRefundFailed();

        emit ETHWithdrawn(to, amount);
    }

    /// @notice Enable refunds — emergency exit, terminal state
    /// @dev Transitions: OPEN → REFUNDING (terminal)
    function enableRefunds() external onlyOwner {
        if (state != PresaleState.OPEN) {
            revert InvalidState(state, PresaleState.OPEN);
        }

        state = PresaleState.REFUNDING;

        emit RefundsEnabled();
    }

    /// @notice Pause the presale (blocks contributions)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the presale
    function unpause() external onlyOwner {
        _unpause();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // EMERGENCY FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Claim refund if refunds are enabled
    /// @dev Only callable in REFUNDING state. NOT gated by whenNotPaused — refunds must
    ///      always be available once enabled. This is an emergency exit.
    function refund() external nonReentrant {
        if (state != PresaleState.REFUNDING) revert PresaleNotRefunding();

        uint256 amount = contributions[msg.sender];
        if (amount == 0) revert NoContribution();

        // Effects before interaction
        contributions[msg.sender] = 0;

        (bool success,) = payable(msg.sender).call{ value: amount }("");
        if (!success) revert ETHRefundFailed();

        emit Refunded(msg.sender, amount);
    }

    /// @notice Dead-man's switch: if owner hasn't finalized or enabled refunds
    ///         within the emergency deadline, anyone can trigger refunds.
    /// @dev Transitions: OPEN → REFUNDING (terminal). Permissionless.
    function emergencyRefunds() external {
        if (state != PresaleState.OPEN) revert PresaleNotOpen();

        uint256 deadline = openedAt + config.emergencyDeadline;
        if (block.timestamp <= deadline) {
            revert EmergencyDeadlineNotReached(block.timestamp, deadline);
        }

        state = PresaleState.REFUNDING;

        emit EmergencyRefundsTriggered(msg.sender, block.timestamp);
        emit RefundsEnabled();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL — TRANCHE PRICING
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Compute allocation and ETH spent for a tranche-mode contribution
    /// @dev Walks through tranches, buying at each price until ETH is exhausted or supply runs out.
    ///      Emits TrancheCompleted when a tranche boundary is crossed.
    /// @param ethAmount ETH contributed
    /// @return allocation $DATA tokens allocated
    /// @return ethSpent ETH actually consumed
    function _computeTrancheAllocation(uint256 ethAmount)
        internal
        returns (uint256 allocation, uint256 ethSpent)
    {
        uint256 remainingETH = ethAmount;
        uint256 sold = totalSold;
        uint256 len = tranches.length;

        // Walk through tranches from the current one
        uint256 cumulative;
        uint256 i;

        // Find current tranche
        for (; i < len; ++i) {
            cumulative += tranches[i].supply;
            if (cumulative > sold) break;
        }

        // Allocate across tranches
        for (; i < len && remainingETH > 0; ++i) {
            uint256 trancheRemaining = cumulative - sold;
            uint256 price = tranches[i].pricePerToken;

            // How many tokens can this ETH buy at this tranche price?
            uint256 tokensAtPrice = (remainingETH * 1e18) / price;

            if (tokensAtPrice <= trancheRemaining) {
                // All remaining ETH fits in this tranche
                allocation += tokensAtPrice;
                ethSpent += (tokensAtPrice * price) / 1e18;
                remainingETH = 0;
                sold += tokensAtPrice;
            } else {
                // Buy remaining in this tranche, advance to next
                allocation += trancheRemaining;
                uint256 cost = (trancheRemaining * price) / 1e18;
                ethSpent += cost;
                remainingETH -= cost;
                sold += trancheRemaining;

                // Determine next price for the event
                uint256 nextPrice = (i + 1 < len) ? tranches[i + 1].pricePerToken : 0;
                emit TrancheCompleted(i, nextPrice);
            }

            // Update cumulative for next iteration
            if (i + 1 < len) {
                cumulative += tranches[i + 1].supply;
            }
        }
    }

    /// @notice Preview tranche allocation without state changes (for preview())
    /// @param ethAmount ETH to simulate
    /// @param currentSold Current totalSold
    /// @return allocation $DATA tokens that would be allocated
    /// @return ethSpent ETH that would be consumed
    function _previewTrancheAllocation(uint256 ethAmount, uint256 currentSold)
        internal
        view
        returns (uint256 allocation, uint256 ethSpent)
    {
        uint256 remainingETH = ethAmount;
        uint256 sold = currentSold;
        uint256 len = tranches.length;

        uint256 cumulative;
        uint256 i;

        for (; i < len; ++i) {
            cumulative += tranches[i].supply;
            if (cumulative > sold) break;
        }

        for (; i < len && remainingETH > 0; ++i) {
            uint256 trancheRemaining = cumulative - sold;
            uint256 price = tranches[i].pricePerToken;

            uint256 tokensAtPrice = (remainingETH * 1e18) / price;

            if (tokensAtPrice <= trancheRemaining) {
                allocation += tokensAtPrice;
                uint256 cost = (tokensAtPrice * price) / 1e18;
                ethSpent += cost;
                remainingETH = 0;
                sold += tokensAtPrice;
            } else {
                allocation += trancheRemaining;
                uint256 cost = (trancheRemaining * price) / 1e18;
                ethSpent += cost;
                remainingETH -= cost;
                sold += trancheRemaining;
            }

            if (i + 1 < len) {
                cumulative += tranches[i + 1].supply;
            }
        }
    }

    /// @notice Get the price of the current tranche based on totalSold
    /// @return price Price per token in the active tranche (or last tranche if sold out)
    function _currentTranchePrice() internal view returns (uint256 price) {
        uint256 len = tranches.length;
        if (len == 0) return 0;

        uint256 cumulative;
        for (uint256 i; i < len; ++i) {
            cumulative += tranches[i].supply;
            if (cumulative > totalSold) {
                return tranches[i].pricePerToken;
            }
        }

        // All tranches sold — return last tranche price
        return tranches[len - 1].pricePerToken;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL — BONDING CURVE PRICING
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Compute allocation and ETH spent for a bonding curve contribution
    /// @dev Uses quadratic solver via PRBMathUD60x18, then verifies cost via integral.
    /// @param ethAmount ETH contributed
    /// @return allocation $DATA tokens allocated
    /// @return ethSpent ETH actually consumed
    function _computeCurveAllocation(uint256 ethAmount)
        internal
        view
        returns (uint256 allocation, uint256 ethSpent)
    {
        uint256 remaining = curve.totalSupply - totalSold;

        allocation = _curveTokensForETH(ethAmount, totalSold);

        if (allocation > remaining) {
            allocation = remaining;
        }

        // Verify actual cost via integral to handle rounding
        ethSpent = _curveCostForTokens(allocation, totalSold);

        // Safety: never charge more than sent
        if (ethSpent > ethAmount) {
            ethSpent = ethAmount;
        }
    }

    /// @notice Compute tokens received for a given ETH contribution on the bonding curve
    /// @dev Uses the quadratic formula Z = (-b + sqrt(b² + 4ac)) / (2a) in UD60x18 space.
    ///      a = (P1 - P0) / (2 * S)
    ///      b = P0 + (P1 - P0) * Y / S  (spot price at current sold level)
    ///      c = ethAmount
    /// @param ethAmount ETH contributed (wei, 18 decimals)
    /// @param currentSold $DATA already sold (wei, 18 decimals)
    /// @return tokens $DATA tokens to allocate (wei, 18 decimals)
    function _curveTokensForETH(uint256 ethAmount, uint256 currentSold) internal view returns (uint256 tokens) {
        uint256 P0 = curve.startPrice;
        uint256 P1 = curve.endPrice;
        uint256 S = curve.totalSupply;

        // slope = P1 - P0 (always > 0, enforced by setCurve)
        UD60x18 slope = ud(P1 - P0);
        UD60x18 supply = ud(S);

        // a = slope / (2 * S)
        UD60x18 a = slope / (supply * ud(2e18));

        // b = P0 + slope * Y / S  (spot price at current sold level)
        UD60x18 b = ud(P0) + slope * ud(currentSold) / supply;

        // c = ethAmount
        UD60x18 c = ud(ethAmount);

        // discriminant = b² + 4ac
        UD60x18 disc = b * b + ud(4e18) * a * c;

        // Z = (sqrt(disc) - b) / (2a)
        UD60x18 sqrtDisc = disc.sqrt();
        UD60x18 twoA = a * ud(2e18);
        UD60x18 Z = (sqrtDisc - b) / twoA;

        tokens = Z.unwrap();

        // Cap at remaining supply
        uint256 remaining = S - currentSold;
        if (tokens > remaining) {
            tokens = remaining;
        }
    }

    /// @notice Compute the ETH cost of buying tokenAmount tokens starting at currentSold
    /// @dev cost = P0 * Z + (P1 - P0) * Z * (2Y + Z) / (2 * S)
    /// @param tokenAmount $DATA tokens to buy
    /// @param currentSold $DATA already sold
    /// @return cost ETH cost in wei
    function _curveCostForTokens(uint256 tokenAmount, uint256 currentSold) internal view returns (uint256 cost) {
        UD60x18 Z = ud(tokenAmount);
        UD60x18 Y = ud(currentSold);
        UD60x18 P0 = ud(curve.startPrice);
        UD60x18 slope = ud(curve.endPrice - curve.startPrice);
        UD60x18 S = ud(curve.totalSupply);

        // cost = P0 * Z + slope * Z * (2Y + Z) / (2S)
        UD60x18 term1 = P0 * Z;
        UD60x18 term2 = slope * Z * (Y * ud(2e18) + Z) / (S * ud(2e18));

        cost = (term1 + term2).unwrap();
    }

    /// @notice Get the spot price on the bonding curve at a given sold level
    /// @dev price(sold) = startPrice + (endPrice - startPrice) * sold / totalSupply
    /// @param sold $DATA already sold
    /// @return price Spot price in ETH per 1e18 $DATA
    function _curveSpotPrice(uint256 sold) internal view returns (uint256 price) {
        if (curve.totalSupply == 0) return 0;
        price = curve.startPrice + (curve.endPrice - curve.startPrice) * sold / curve.totalSupply;
    }
}
