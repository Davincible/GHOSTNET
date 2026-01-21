// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IDataToken
/// @notice Interface for the GHOSTNET $DATA token with transfer tax mechanics
/// @dev Token implements a 10% transfer tax: 9% burn, 1% treasury
interface IDataToken is IERC20 {
    // ══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Thrown when the treasury address is zero
    error InvalidTreasury();

    /// @notice Thrown when initial distribution arrays have mismatched lengths
    error DistributionLengthMismatch();

    /// @notice Thrown when initial distribution doesn't sum to total supply
    error DistributionSumMismatch();

    // ══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when an address's tax exclusion status is updated
    /// @param account The address whose status was updated
    /// @param excluded Whether the address is now excluded from tax
    event TaxExclusionSet(address indexed account, bool excluded);

    /// @notice Emitted when tokens are burned via tax
    /// @param from The address that triggered the burn
    /// @param amount The amount of tokens burned
    event TaxBurned(address indexed from, uint256 amount);

    /// @notice Emitted when tokens are sent to treasury via tax
    /// @param from The address that triggered the tax
    /// @param amount The amount sent to treasury
    event TaxCollected(address indexed from, uint256 amount);

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Total token supply: 100 million tokens
    function TOTAL_SUPPLY() external view returns (uint256);

    /// @notice Total tax rate in basis points (1000 = 10%)
    function TAX_RATE_BPS() external view returns (uint16);

    /// @notice Share of tax that goes to burn in basis points (9000 = 90% of tax)
    function BURN_SHARE_BPS() external view returns (uint16);

    /// @notice Share of tax that goes to treasury in basis points (1000 = 10% of tax)
    function TREASURY_SHARE_BPS() external view returns (uint16);

    /// @notice Dead address for burns
    function DEAD_ADDRESS() external view returns (address);

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE READERS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Returns the treasury address that receives 1% of transfers
    function treasury() external view returns (address);

    /// @notice Returns whether an address is excluded from transfer tax
    /// @param account The address to check
    function isExcludedFromTax(
        address account
    ) external view returns (bool);

    /// @notice Returns the total amount of tokens burned
    function totalBurned() external view returns (uint256);

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Sets the tax exclusion status for an address
    /// @dev Only callable by owner. Game contracts should be excluded.
    /// @param account The address to update
    /// @param excluded Whether to exclude from tax
    function setTaxExclusion(
        address account,
        bool excluded
    ) external;

    // ══════════════════════════════════════════════════════════════════════════════
    // PUBLIC FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Burns tokens from the caller's balance
    /// @param amount The amount of tokens to burn
    function burn(
        uint256 amount
    ) external;

    /// @notice Burns tokens from an address with allowance
    /// @param from The address to burn from
    /// @param amount The amount of tokens to burn
    function burnFrom(
        address from,
        uint256 amount
    ) external;
}
