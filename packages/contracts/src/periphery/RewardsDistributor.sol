// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IGhostCore } from "../core/interfaces/IGhostCore.sol";

/// @title RewardsDistributor
/// @notice Distributes 60M DATA emissions over 24 months ("The Mine")
/// @dev Linear vesting with configurable level weights
///
/// Emission Schedule:
/// - Total: 60,000,000 DATA
/// - Duration: 24 months (~730 days)
/// - Rate: ~82,000 DATA per day
///
/// Level Weights (default):
/// - VAULT:     5%  (~4,100 DATA/day)
/// - MAINFRAME: 10% (~8,200 DATA/day)
/// - SUBNET:    20% (~16,400 DATA/day)
/// - DARKNET:   30% (~24,600 DATA/day)
/// - BLACK_ICE: 35% (~28,700 DATA/day)
///
/// @custom:security-contact security@ghostnet.game
contract RewardsDistributor is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    error InvalidAddress();
    error InvalidWeights();
    error NothingToDistribute();
    error DistributionEnded();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when emissions are distributed
    event EmissionsDistributed(uint256 totalAmount, uint256 timestamp);

    /// @notice Emitted when level weights are updated
    event WeightsUpdated(uint16[5] newWeights);

    /// @notice Emitted when GhostCore address is updated
    event GhostCoreUpdated(address newGhostCore);

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Total emissions (60 million DATA)
    uint256 public constant TOTAL_EMISSIONS = 60_000_000 * 1e18;

    /// @notice Emission duration (24 months)
    uint256 public constant EMISSION_DURATION = 730 days;

    /// @notice Basis points denominator
    uint16 private constant BPS = 10_000;

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice The DATA token
    IERC20 public immutable dataToken;

    /// @notice When emissions started
    uint256 public immutable emissionStart;

    /// @notice When emissions end
    uint256 public immutable emissionEnd;

    /// @notice GhostCore contract to distribute to
    IGhostCore public ghostCore;

    /// @notice Total emissions already distributed
    uint256 public totalDistributed;

    /// @notice Last distribution timestamp
    uint256 public lastDistributionTime;

    /// @notice Level weights in basis points [VAULT, MAINFRAME, SUBNET, DARKNET, BLACK_ICE]
    /// @dev Must sum to 10000 (100%)
    uint16[5] public levelWeights;

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Deploy the rewards distributor
    /// @param _dataToken Address of the DATA token
    /// @param _ghostCore Address of the GhostCore contract
    /// @param _owner Address with admin rights
    constructor(address _dataToken, address _ghostCore, address _owner) Ownable(_owner) {
        if (_dataToken == address(0)) revert InvalidAddress();

        dataToken = IERC20(_dataToken);
        ghostCore = IGhostCore(_ghostCore);

        emissionStart = block.timestamp;
        emissionEnd = block.timestamp + EMISSION_DURATION;
        lastDistributionTime = block.timestamp;

        // Default weights: 5/10/20/30/35
        levelWeights = [500, 1000, 2000, 3000, 3500];
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // DISTRIBUTION
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Distribute pending emissions to GhostCore
    /// @dev Can be called by anyone (keeper or user)
    function distribute() external nonReentrant {
        uint256 pending = pendingEmissions();
        if (pending == 0) revert NothingToDistribute();

        lastDistributionTime = block.timestamp;
        totalDistributed += pending;

        // Distribute to each level according to weights
        for (uint8 i = 0; i < 5; i++) {
            uint256 levelAmount = (pending * levelWeights[i]) / BPS;
            if (levelAmount > 0) {
                // Transfer tokens to GhostCore
                dataToken.safeTransfer(address(ghostCore), levelAmount);
                // Tell GhostCore to add to level's accRewardsPerShare
                ghostCore.addEmissionRewards(IGhostCore.Level(i + 1), levelAmount);
            }
        }

        emit EmissionsDistributed(pending, block.timestamp);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Get pending emissions since last distribution
    function pendingEmissions() public view returns (uint256) {
        if (block.timestamp <= lastDistributionTime) return 0;

        uint256 endTime = block.timestamp > emissionEnd ? emissionEnd : block.timestamp;
        uint256 startTime = lastDistributionTime > emissionStart ? lastDistributionTime : emissionStart;

        if (endTime <= startTime) return 0;

        uint256 elapsed = endTime - startTime;
        uint256 totalElapsed = emissionEnd - emissionStart;

        uint256 pending = (TOTAL_EMISSIONS * elapsed) / totalElapsed;

        // Don't exceed remaining emissions
        uint256 remaining = TOTAL_EMISSIONS - totalDistributed;
        if (pending > remaining) pending = remaining;

        return pending;
    }

    /// @notice Get total vested emissions at current time
    function totalVested() public view returns (uint256) {
        if (block.timestamp <= emissionStart) return 0;
        if (block.timestamp >= emissionEnd) return TOTAL_EMISSIONS;

        uint256 elapsed = block.timestamp - emissionStart;
        return (TOTAL_EMISSIONS * elapsed) / EMISSION_DURATION;
    }

    /// @notice Get remaining undistributed emissions
    function remainingEmissions() external view returns (uint256) {
        return TOTAL_EMISSIONS - totalDistributed;
    }

    /// @notice Get current emission rate per second
    function emissionRatePerSecond() external pure returns (uint256) {
        return TOTAL_EMISSIONS / EMISSION_DURATION;
    }

    /// @notice Get emission rate per day
    function emissionRatePerDay() external pure returns (uint256) {
        return (TOTAL_EMISSIONS * 1 days) / EMISSION_DURATION;
    }

    /// @notice Check if emissions have ended
    function emissionsEnded() external view returns (bool) {
        return block.timestamp >= emissionEnd || totalDistributed >= TOTAL_EMISSIONS;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Update level weights
    /// @param newWeights Array of 5 weights in basis points [VAULT, MAINFRAME, SUBNET, DARKNET, BLACK_ICE]
    function setLevelWeights(uint16[5] calldata newWeights) external onlyOwner {
        uint256 sum;
        for (uint256 i = 0; i < 5; i++) {
            sum += newWeights[i];
        }
        if (sum != BPS) revert InvalidWeights();

        levelWeights = newWeights;
        emit WeightsUpdated(newWeights);
    }

    /// @notice Update GhostCore address
    /// @param newGhostCore New GhostCore contract address
    function setGhostCore(address newGhostCore) external onlyOwner {
        if (newGhostCore == address(0)) revert InvalidAddress();
        ghostCore = IGhostCore(newGhostCore);
        emit GhostCoreUpdated(newGhostCore);
    }

    /// @notice Emergency withdraw (in case of migration)
    /// @param amount Amount to withdraw
    /// @param recipient Recipient address
    function emergencyWithdraw(uint256 amount, address recipient) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        dataToken.safeTransfer(recipient, amount);
    }
}
