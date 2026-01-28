// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title IGhostPresale
/// @notice Minimal interface for reading presale state from PresaleClaim
/// @dev Only includes functions needed by the claim contract
///
/// @custom:security-contact security@ghostnet.game
interface IGhostPresale {
    /// @notice $DATA allocation for a given contributor
    function allocations(address account) external view returns (uint256);

    /// @notice Total $DATA sold across all contributors
    function totalSold() external view returns (uint256);
}
