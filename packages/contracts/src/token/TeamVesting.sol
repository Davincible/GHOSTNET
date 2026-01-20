// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title TeamVesting
/// @notice Immutable vesting contract for GHOSTNET team allocation
/// @dev 8% of total supply (8M DATA) with 1-month cliff and 24-month linear vesting
///
/// Vesting Schedule:
/// - Cliff: 1 month (no tokens claimable)
/// - Duration: 24 months total (including cliff)
/// - After cliff: Linear vesting over remaining 23 months
///
/// This contract is IMMUTABLE - vesting parameters cannot be changed after deployment.
///
/// @custom:security-contact security@ghostnet.game
contract TeamVesting is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Thrown when an invalid address is provided
    error InvalidAddress();

    /// @notice Thrown when beneficiaries and amounts arrays have different lengths
    error ArrayLengthMismatch();

    /// @notice Thrown when no vesting schedule exists for the caller
    error NoVestingSchedule();

    /// @notice Thrown when there are no tokens available to claim
    error NothingToClaim();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when tokens are claimed by a beneficiary
    /// @param beneficiary Address that claimed tokens
    /// @param amount Amount of tokens claimed
    event TokensClaimed(address indexed beneficiary, uint256 amount);

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Duration of the cliff period (1 month)
    uint256 public constant CLIFF_DURATION = 30 days;

    /// @notice Total vesting duration including cliff (24 months)
    uint256 public constant VESTING_DURATION = 730 days; // ~24 months

    // ══════════════════════════════════════════════════════════════════════════════
    // STRUCTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Vesting schedule for a beneficiary
    struct VestingSchedule {
        uint256 totalAmount; // Total tokens allocated
        uint256 claimed; // Tokens already claimed
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice The token being vested
    IERC20 public immutable token;

    /// @notice Timestamp when vesting starts
    uint256 public immutable vestingStart;

    /// @notice Timestamp when cliff ends
    uint256 public immutable cliffEnd;

    /// @notice Timestamp when vesting ends
    uint256 public immutable vestingEnd;

    /// @notice Vesting schedules for each beneficiary
    mapping(address beneficiary => VestingSchedule schedule) public vestingSchedules;

    /// @notice Total amount allocated across all beneficiaries
    uint256 public totalAllocated;

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Deploys the vesting contract and sets up beneficiary schedules
    /// @param _token The DATA token address
    /// @param _beneficiaries Array of team member addresses
    /// @param _amounts Array of token amounts for each beneficiary
    /// @dev Token transfer to this contract must happen separately after deployment
    constructor(IERC20 _token, address[] memory _beneficiaries, uint256[] memory _amounts) {
        if (address(_token) == address(0)) revert InvalidAddress();
        if (_beneficiaries.length != _amounts.length) revert ArrayLengthMismatch();

        token = _token;
        vestingStart = block.timestamp;
        cliffEnd = block.timestamp + CLIFF_DURATION;
        vestingEnd = block.timestamp + VESTING_DURATION;

        // Set up vesting schedules
        for (uint256 i; i < _beneficiaries.length; ++i) {
            if (_beneficiaries[i] == address(0)) revert InvalidAddress();

            vestingSchedules[_beneficiaries[i]] = VestingSchedule({
                totalAmount: _amounts[i],
                claimed: 0
            });
            totalAllocated += _amounts[i];
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Returns the amount of tokens vested for a beneficiary at current time
    /// @param beneficiary Address to check
    /// @return Amount of tokens vested (but not necessarily claimed)
    function vestedAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];

        if (schedule.totalAmount == 0) {
            return 0;
        }

        // Nothing vested before cliff ends
        if (block.timestamp < cliffEnd) {
            return 0;
        }

        // Fully vested after vesting period
        if (block.timestamp >= vestingEnd) {
            return schedule.totalAmount;
        }

        // Linear vesting between cliff end and vesting end
        uint256 elapsed = block.timestamp - vestingStart;
        return (schedule.totalAmount * elapsed) / VESTING_DURATION;
    }

    /// @notice Returns the amount of tokens available to claim for a beneficiary
    /// @param beneficiary Address to check
    /// @return Amount of tokens available to claim now
    function claimableAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        uint256 vested = vestedAmount(beneficiary);

        if (vested <= schedule.claimed) {
            return 0;
        }

        return vested - schedule.claimed;
    }

    /// @notice Returns full vesting information for a beneficiary
    /// @param beneficiary Address to check
    /// @return total Total tokens allocated
    /// @return vested Amount vested so far
    /// @return claimed Amount already claimed
    /// @return claimable Amount available to claim now
    function getVestingInfo(address beneficiary)
        external
        view
        returns (uint256 total, uint256 vested, uint256 claimed, uint256 claimable)
    {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        return (
            schedule.totalAmount,
            vestedAmount(beneficiary),
            schedule.claimed,
            claimableAmount(beneficiary)
        );
    }

    /// @notice Returns time until cliff ends (0 if cliff has passed)
    function timeUntilCliff() external view returns (uint256) {
        if (block.timestamp >= cliffEnd) return 0;
        return cliffEnd - block.timestamp;
    }

    /// @notice Returns time until vesting is complete (0 if complete)
    function timeUntilFullyVested() external view returns (uint256) {
        if (block.timestamp >= vestingEnd) return 0;
        return vestingEnd - block.timestamp;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CLAIM FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Claims all available vested tokens for the caller
    /// @return amount The amount of tokens claimed
    function claim() external nonReentrant returns (uint256 amount) {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];

        if (schedule.totalAmount == 0) revert NoVestingSchedule();

        amount = claimableAmount(msg.sender);
        if (amount == 0) revert NothingToClaim();

        schedule.claimed += amount;

        token.safeTransfer(msg.sender, amount);

        emit TokensClaimed(msg.sender, amount);
    }
}
