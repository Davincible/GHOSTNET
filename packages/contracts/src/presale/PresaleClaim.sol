// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IPresaleClaim } from "./interfaces/IPresaleClaim.sol";
import { IGhostPresale } from "./interfaces/IGhostPresale.sol";

/// @title PresaleClaim
/// @notice Holds $DATA tokens and lets presale contributors claim their allocation at TGE
/// @dev Reads allocations from GhostPresale with a local snapshot fallback.
///      Deployed after DataToken exists. Owner funds contract, enables claiming,
///      and can recover unclaimed tokens after the deadline.
///
/// @custom:security-contact security@ghostnet.game
contract PresaleClaim is Ownable2Step, ReentrancyGuard, Pausable, IPresaleClaim {
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════════════════
    // IMMUTABLES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice The $DATA token contract
    IERC20 public immutable dataToken;

    /// @notice The presale contract that tracks contributor allocations
    IGhostPresale public immutable presale;

    /// @inheritdoc IPresaleClaim
    uint256 public immutable claimDeadline;

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IPresaleClaim
    bool public claimingEnabled;

    /// @inheritdoc IPresaleClaim
    bool public recovered;

    /// @inheritdoc IPresaleClaim
    mapping(address account => bool) public claimed;

    /// @inheritdoc IPresaleClaim
    mapping(address account => uint256 amount) public snapshotted;

    /// @inheritdoc IPresaleClaim
    uint256 public totalClaimed;

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Deploys the claim contract
    /// @param _dataToken The $DATA token address
    /// @param _presale The GhostPresale contract to read allocations from
    /// @param _claimDeadline Unix timestamp after which unclaimed tokens can be recovered
    /// @param _initialOwner Address that will own the contract
    constructor(
        IERC20 _dataToken,
        IGhostPresale _presale,
        uint256 _claimDeadline,
        address _initialOwner
    ) Ownable(_initialOwner) {
        if (address(_dataToken) == address(0)) revert InvalidAddress();
        if (address(_presale) == address(0)) revert InvalidAddress();
        if (_claimDeadline <= block.timestamp) revert ClaimDeadlineNotReached(block.timestamp, _claimDeadline);

        dataToken = _dataToken;
        presale = _presale;
        claimDeadline = _claimDeadline;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IPresaleClaim
    function claimable(
        address account
    ) external view returns (uint256) {
        if (!claimingEnabled || recovered || claimed[account]) {
            return 0;
        }

        uint256 allocation = presale.allocations(account);
        if (allocation == 0) {
            allocation = snapshotted[account];
        }

        return allocation;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // USER FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IPresaleClaim
    function claim() external nonReentrant whenNotPaused returns (uint256 amount) {
        if (!claimingEnabled) revert ClaimingNotEnabled();
        if (recovered) revert ClaimingClosed();
        if (claimed[msg.sender]) revert AlreadyClaimed();

        // Read allocation from presale, fall back to snapshot
        amount = presale.allocations(msg.sender);
        if (amount == 0) {
            amount = snapshotted[msg.sender];
        }
        if (amount == 0) revert NoAllocation();

        // Effects
        claimed[msg.sender] = true;
        totalClaimed += amount;

        // Interactions
        dataToken.safeTransfer(msg.sender, amount);

        emit Claimed(msg.sender, amount);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IPresaleClaim
    function enableClaiming() external onlyOwner {
        if (claimingEnabled) revert AlreadyEnabled();

        uint256 required = presale.totalSold();
        uint256 available = dataToken.balanceOf(address(this));
        if (available < required) revert InsufficientBalance(available, required);

        claimingEnabled = true;

        emit ClaimingEnabled(available);
    }

    /// @inheritdoc IPresaleClaim
    function snapshotAllocations(
        address[] calldata accounts
    ) external onlyOwner {
        if (claimingEnabled) revert AlreadyEnabled();
        for (uint256 i; i < accounts.length; ++i) {
            snapshotted[accounts[i]] = presale.allocations(accounts[i]);
        }

        emit AllocationsSnapshotted(accounts.length);
    }

    /// @inheritdoc IPresaleClaim
    function recoverUnclaimed(
        address to
    ) external onlyOwner nonReentrant {
        if (to == address(0)) revert InvalidAddress();
        if (block.timestamp <= claimDeadline) revert ClaimDeadlineNotReached(block.timestamp, claimDeadline);

        uint256 recoverable = dataToken.balanceOf(address(this));

        // Effects
        recovered = true;

        // Interactions
        dataToken.safeTransfer(to, recoverable);

        emit UnclaimedRecovered(to, recoverable);
    }

    /// @notice Pauses claiming in an emergency
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses claiming
    function unpause() external onlyOwner {
        _unpause();
    }
}
