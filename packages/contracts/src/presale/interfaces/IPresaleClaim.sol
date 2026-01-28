// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title IPresaleClaim
/// @notice Interface for the GHOSTNET presale claim contract
/// @dev Deployed at TGE. Holds $DATA tokens and lets presale contributors claim their allocation.
///      Reads allocations from the GhostPresale contract with a snapshot fallback.
///
/// @custom:security-contact security@ghostnet.game
interface IPresaleClaim {
    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    error ClaimingNotEnabled();
    error AlreadyEnabled();
    error ClaimingClosed();
    error AlreadyClaimed();
    error NoAllocation();
    error InsufficientBalance(uint256 available, uint256 required);
    error ClaimDeadlineNotReached(uint256 current, uint256 deadline);
    error InvalidAddress();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when a contributor claims their $DATA allocation
    event Claimed(address indexed claimer, uint256 amount);

    /// @notice Emitted when the owner enables claiming
    event ClaimingEnabled(uint256 totalSupplyAvailable);

    /// @notice Emitted when allocations are snapshotted as backup
    event AllocationsSnapshotted(uint256 count);

    /// @notice Emitted when unclaimed tokens are recovered by the owner
    event UnclaimedRecovered(address indexed to, uint256 amount);

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Whether claiming is enabled
    function claimingEnabled() external view returns (bool);

    /// @notice Whether unclaimed tokens have been recovered (claims disabled)
    function recovered() external view returns (bool);

    /// @notice Whether an address has already claimed
    function claimed(address account) external view returns (bool);

    /// @notice Backup snapshot allocation for an address
    function snapshotted(address account) external view returns (uint256);

    /// @notice Total $DATA tokens claimed so far
    function totalClaimed() external view returns (uint256);

    /// @notice Timestamp after which unclaimed tokens can be recovered
    function claimDeadline() external view returns (uint256);

    /// @notice Amount claimable by a given address (0 if already claimed or not eligible)
    function claimable(address account) external view returns (uint256);

    // ══════════════════════════════════════════════════════════════════════════════
    // USER FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Claim $DATA allocation from presale
    /// @return amount The number of $DATA tokens transferred
    function claim() external returns (uint256 amount);

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Enable claiming after contract is funded with $DATA
    /// @dev Verifies balance >= presale.totalSold()
    function enableClaiming() external;

    /// @notice Copy allocations from presale into local backup storage
    /// @param accounts Addresses to snapshot
    function snapshotAllocations(address[] calldata accounts) external;

    /// @notice Recover unclaimed tokens after deadline. Disables further claims.
    /// @param to Address to send recovered tokens
    function recoverUnclaimed(address to) external;
}
