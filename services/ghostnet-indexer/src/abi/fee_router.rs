//! ABI bindings for `FeeRouter` contract events.
//!
//! `FeeRouter` handles fee collection and distribution:
//! - Toll collection (ETH fees for game actions)
//! - Buyback and burn (ETH → DATA → burn)
//! - Operations fund withdrawals
//!
//! # Fee Flow
//!
//! ```text
//! User Action (e.g., jackIn)
//!     │
//!     └── ETH Toll ──┬── 70% → Buyback Pool
//!                    │
//!                    └── 30% → Operations Fund
//!
//! Buyback Trigger (weekly or manual)
//!     │
//!     └── Buyback Pool ──┬── Buy DATA on DEX
//!                        │
//!                        └── Burn purchased DATA
//! ```
//!
//! # Solidity Contract
//!
//! ```solidity
//! contract FeeRouter {
//!     event TollCollected(address indexed from, uint256 amount, bytes32 indexed reason);
//!     event BuybackExecuted(uint256 ethSpent, uint256 dataReceived, uint256 dataBurned);
//!     event OperationsWithdrawn(address indexed to, uint256 amount);
//! }
//! ```

use alloy::sol;

sol! {
    /// Emitted when toll is collected for a game action.
    ///
    /// # Indexed Fields
    /// - `from`: Who paid the toll
    /// - `reason`: Action identifier (keccak256 hash of action name)
    ///
    /// # Data Fields
    /// - `amount`: ETH amount collected
    ///
    /// # Reason Hashes
    ///
    /// | Action | Reason Hash |
    /// |--------|-------------|
    /// | jackIn | keccak256("jackIn") |
    /// | addStake | keccak256("addStake") |
    /// | extract | keccak256("extract") |
    /// | placeBet | keccak256("placeBet") |
    #[derive(Debug, PartialEq, Eq)]
    event TollCollected(
        address indexed from,
        uint256 amount,
        bytes32 indexed reason
    );

    /// Emitted when buyback is executed.
    ///
    /// Accumulated ETH is used to buy DATA on the DEX,
    /// then the purchased DATA is burned.
    ///
    /// # Data Fields
    /// - `ethSpent`: ETH used for buyback
    /// - `dataReceived`: DATA tokens bought
    /// - `dataBurned`: DATA tokens burned (should equal dataReceived)
    #[derive(Debug, PartialEq, Eq)]
    event BuybackExecuted(
        uint256 ethSpent,
        uint256 dataReceived,
        uint256 dataBurned
    );

    /// Emitted when operations funds are withdrawn.
    ///
    /// Operations fund covers:
    /// - Server costs
    /// - Marketing
    /// - Development
    ///
    /// # Indexed Fields
    /// - `to`: Recipient address
    ///
    /// # Data Fields
    /// - `amount`: ETH amount withdrawn
    #[derive(Debug, PartialEq, Eq)]
    event OperationsWithdrawn(
        address indexed to,
        uint256 amount
    );
}

#[cfg(test)]
mod tests {
    use alloy::sol_types::SolEvent;

    use super::*;

    #[test]
    fn toll_collected_signature() {
        assert_eq!(
            TollCollected::SIGNATURE,
            "TollCollected(address,uint256,bytes32)"
        );
    }

    #[test]
    fn buyback_executed_signature() {
        assert_eq!(
            BuybackExecuted::SIGNATURE,
            "BuybackExecuted(uint256,uint256,uint256)"
        );
    }

    #[test]
    fn operations_withdrawn_signature() {
        assert_eq!(
            OperationsWithdrawn::SIGNATURE,
            "OperationsWithdrawn(address,uint256)"
        );
    }

    #[test]
    fn all_fee_router_events_have_unique_signatures() {
        let signatures = [
            TollCollected::SIGNATURE_HASH,
            BuybackExecuted::SIGNATURE_HASH,
            OperationsWithdrawn::SIGNATURE_HASH,
        ];

        let unique: std::collections::HashSet<_> = signatures.iter().collect();
        assert_eq!(
            unique.len(),
            3,
            "All FeeRouter events should have unique signatures"
        );
    }
}
