// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IDataToken } from "./interfaces/IDataToken.sol";

/// @title DataToken
/// @notice GHOSTNET $DATA token with 10% transfer tax (9% burn, 1% treasury)
/// @dev IMMUTABLE - This contract cannot be upgraded. Tax rates are permanent commitments.
///
/// Token Distribution at Launch:
/// - 60% (60M) -> RewardsDistributor (The Mine - emissions over 24 months)
/// - 15% (15M) -> Presale participants
/// - 9%  (9M)  -> Liquidity (to be burned)
/// - 8%  (8M)  -> TeamVesting contract
/// - 8%  (8M)  -> Treasury
///
/// Tax Mechanics:
/// - All transfers between non-excluded addresses incur 10% tax
/// - 9% of tax (90% of 10%) is burned to DEAD_ADDRESS
/// - 1% of tax (10% of 10%) goes to treasury
/// - Game contracts are excluded to allow tax-free internal transfers
///
/// @custom:security-contact security@ghostnet.game
contract DataToken is ERC20, Ownable2Step, IDataToken {
    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IDataToken
    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 1e18;

    /// @inheritdoc IDataToken
    uint16 public constant TAX_RATE_BPS = 1000; // 10%

    /// @inheritdoc IDataToken
    uint16 public constant BURN_SHARE_BPS = 9000; // 90% of tax -> burn

    /// @inheritdoc IDataToken
    uint16 public constant TREASURY_SHARE_BPS = 1000; // 10% of tax -> treasury

    /// @inheritdoc IDataToken
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    uint16 private constant BPS_DENOMINATOR = 10_000;

    // ══════════════════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IDataToken
    address public immutable treasury;

    /// @notice Addresses excluded from transfer tax
    mapping(address account => bool excluded) private _taxExcluded;

    /// @inheritdoc IDataToken
    uint256 public totalBurned;

    // ══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Deploys the DataToken with initial distribution
    /// @param _treasury Address to receive 1% of transfer taxes
    /// @param _initialOwner Address that will own the contract (can set tax exclusions)
    /// @param _recipients Array of addresses to receive initial token allocation
    /// @param _amounts Array of amounts corresponding to each recipient
    /// @dev Sum of _amounts must equal TOTAL_SUPPLY
    constructor(
        address _treasury,
        address _initialOwner,
        address[] memory _recipients,
        uint256[] memory _amounts
    )
        ERC20("GHOSTNET Data", "DATA")
        Ownable(_initialOwner)
    {
        if (_treasury == address(0)) revert InvalidTreasury();
        if (_recipients.length != _amounts.length) revert DistributionLengthMismatch();

        treasury = _treasury;

        // Verify distribution sums to total supply and mint
        uint256 sum;
        for (uint256 i; i < _recipients.length; ++i) {
            sum += _amounts[i];
            _mint(_recipients[i], _amounts[i]);
        }

        if (sum != TOTAL_SUPPLY) revert DistributionSumMismatch();

        // Exclude treasury and dead address from tax by default
        _taxExcluded[_treasury] = true;
        _taxExcluded[DEAD_ADDRESS] = true;

        emit TaxExclusionSet(_treasury, true);
        emit TaxExclusionSet(DEAD_ADDRESS, true);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IDataToken
    function isExcludedFromTax(address account) external view returns (bool) {
        return _taxExcluded[account];
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IDataToken
    function setTaxExclusion(address account, bool excluded) external onlyOwner {
        _taxExcluded[account] = excluded;
        emit TaxExclusionSet(account, excluded);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // PUBLIC FUNCTIONS
    // ══════════════════════════════════════════════════════════════════════════════

    /// @inheritdoc IDataToken
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        totalBurned += amount;
    }

    /// @inheritdoc IDataToken
    function burnFrom(address from, uint256 amount) external {
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
        totalBurned += amount;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INTERNAL OVERRIDES
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Overrides ERC20 transfer to apply tax mechanics
    /// @dev Tax is applied unless sender OR recipient is excluded
    /// @param from Source address
    /// @param to Destination address
    /// @param amount Amount to transfer (before tax)
    function _update(address from, address to, uint256 amount) internal override {
        // Skip tax for mints, burns, and excluded addresses
        if (from == address(0) || to == address(0) || _taxExcluded[from] || _taxExcluded[to]) {
            super._update(from, to, amount);
            return;
        }

        // Calculate tax amounts
        // Tax = 10% of amount
        // Burn = 90% of tax = 9% of amount
        // Treasury = 10% of tax = 1% of amount
        uint256 taxAmount = (amount * TAX_RATE_BPS) / BPS_DENOMINATOR;
        uint256 burnAmount = (taxAmount * BURN_SHARE_BPS) / BPS_DENOMINATOR;
        uint256 treasuryAmount = taxAmount - burnAmount;
        uint256 transferAmount = amount - taxAmount;

        // Execute transfers
        super._update(from, to, transferAmount);
        super._update(from, DEAD_ADDRESS, burnAmount);
        super._update(from, treasury, treasuryAmount);

        // Update burn tracking
        totalBurned += burnAmount;

        emit TaxBurned(from, burnAmount);
        emit TaxCollected(from, treasuryAmount);
    }
}
