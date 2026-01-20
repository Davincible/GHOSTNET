//! ABI bindings for `DataToken` contract events.
//!
//! `DataToken` is the ERC20 token with built-in transfer tax:
//! - 10% tax on transfers (non-excluded addresses)
//! - 9% of tax is burned
//! - 1% of tax goes to treasury
//!
//! # Tax Flow
//!
//! ```text
//! Transfer 100 DATA
//!     │
//!     ├── 90 DATA → Recipient
//!     │
//!     └── 10 DATA (10% tax)
//!           ├── 9 DATA → Burned (TaxBurned)
//!           └── 1 DATA → Treasury (TaxCollected)
//! ```
//!
//! # Tax Exclusions
//!
//! Certain addresses are excluded from tax:
//! - `GhostCore` contract (game mechanics)
//! - Liquidity pools (avoid double taxation)
//! - Team vesting contracts
//!
//! # Solidity Contract
//!
//! ```solidity
//! contract DataToken is ERC20 {
//!     event Transfer(address indexed from, address indexed to, uint256 value);
//!     event TaxBurned(address indexed from, uint256 amount);
//!     event TaxCollected(address indexed from, uint256 amount);
//!     event TaxExclusionSet(address indexed account, bool excluded);
//! }
//! ```

use alloy::sol;

sol! {
    /// Standard ERC20 transfer event.
    ///
    /// Note: `from` is 0x0 for mints, `to` is `DEAD_ADDRESS` for burns.
    ///
    /// # Indexed Fields
    /// - `from`: Sender address (0x0 for mints)
    /// - `to`: Recipient address (`DEAD_ADDRESS` for burns)
    ///
    /// # Data Fields
    /// - `value`: Amount transferred (after tax if applicable)
    #[derive(Debug, PartialEq, Eq)]
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    /// Emitted when tokens are burned via transfer tax.
    ///
    /// # Indexed Fields
    /// - `from`: Transfer sender (who triggered the tax)
    ///
    /// # Data Fields
    /// - `amount`: Amount burned (9% of 10% tax = 0.9% of transfer)
    #[derive(Debug, PartialEq, Eq)]
    event TaxBurned(
        address indexed from,
        uint256 amount
    );

    /// Emitted when tokens are collected to treasury via tax.
    ///
    /// # Indexed Fields
    /// - `from`: Transfer sender (who triggered the tax)
    ///
    /// # Data Fields
    /// - `amount`: Amount to treasury (1% of 10% tax = 0.1% of transfer)
    #[derive(Debug, PartialEq, Eq)]
    event TaxCollected(
        address indexed from,
        uint256 amount
    );

    /// Emitted when tax exclusion status changes for an address.
    ///
    /// # Indexed Fields
    /// - `account`: Affected address
    ///
    /// # Data Fields
    /// - `excluded`: New exclusion status (true = no tax on transfers)
    #[derive(Debug, PartialEq, Eq)]
    event TaxExclusionSet(
        address indexed account,
        bool excluded
    );
}

#[cfg(test)]
mod tests {
    use alloy::sol_types::SolEvent;

    use super::*;

    #[test]
    fn transfer_signature() {
        // Standard ERC20 Transfer signature
        assert_eq!(Transfer::SIGNATURE, "Transfer(address,address,uint256)");
    }

    #[test]
    fn tax_burned_signature() {
        assert_eq!(TaxBurned::SIGNATURE, "TaxBurned(address,uint256)");
    }

    #[test]
    fn tax_collected_signature() {
        assert_eq!(TaxCollected::SIGNATURE, "TaxCollected(address,uint256)");
    }

    #[test]
    fn tax_exclusion_set_signature() {
        assert_eq!(TaxExclusionSet::SIGNATURE, "TaxExclusionSet(address,bool)");
    }

    #[test]
    fn all_data_token_events_have_unique_signatures() {
        let signatures = [
            Transfer::SIGNATURE_HASH,
            TaxBurned::SIGNATURE_HASH,
            TaxCollected::SIGNATURE_HASH,
            TaxExclusionSet::SIGNATURE_HASH,
        ];

        let unique: std::collections::HashSet<_> = signatures.iter().collect();
        assert_eq!(
            unique.len(),
            4,
            "All DataToken events should have unique signatures"
        );
    }
}
