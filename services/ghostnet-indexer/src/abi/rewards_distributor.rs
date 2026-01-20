//! ABI bindings for `RewardsDistributor` and `TeamVesting` contract events.
//!
//! # `RewardsDistributor`
//!
//! Handles emission distribution across risk levels:
//! - Weekly emission schedule
//! - Weighted distribution by level
//! - Dynamic weight adjustments
//!
//! # `TeamVesting`
//!
//! Handles team token vesting:
//! - 12-month cliff
//! - 36-month linear vesting
//! - Monthly claim periods
//!
//! # Emission Weights (Default)
//!
//! | Level | Weight | Share |
//! |-------|--------|-------|
//! | Vault | 5% | Safe haven, minimal rewards |
//! | Mainframe | 10% | Low risk, low reward |
//! | Subnet | 20% | Balanced |
//! | Darknet | 30% | High risk, high reward |
//! | Black Ice | 35% | Maximum risk, maximum reward |
//!
//! # Solidity Contracts
//!
//! ```solidity
//! contract RewardsDistributor {
//!     event EmissionsDistributed(uint256 totalAmount, uint256 timestamp);
//!     event WeightsUpdated(uint16[5] newWeights);
//! }
//!
//! contract TeamVesting {
//!     event TokensClaimed(address indexed beneficiary, uint256 amount);
//! }
//! ```

use alloy::sol;

sol! {
    /// Emitted when emissions are distributed across levels.
    ///
    /// # Data Fields
    /// - `totalAmount`: Total DATA distributed this period
    /// - `timestamp`: Unix timestamp of distribution
    #[derive(Debug, PartialEq, Eq)]
    event EmissionsDistributed(
        uint256 totalAmount,
        uint256 timestamp
    );

    /// Emitted when level weights are updated.
    ///
    /// Weights are in basis points (100 = 1%).
    /// Array index 0 = Vault, index 4 = Black Ice.
    /// Total should sum to 10000 (100%).
    ///
    /// # Data Fields
    /// - `newWeights`: Array of 5 weights (Vault, Mainframe, Subnet, Darknet, Black Ice)
    #[derive(Debug, PartialEq, Eq)]
    event WeightsUpdated(
        uint16[5] newWeights
    );

    /// Emitted when a team member claims vested tokens.
    ///
    /// # Indexed Fields
    /// - `beneficiary`: Team member's address
    ///
    /// # Data Fields
    /// - `amount`: Amount claimed
    #[derive(Debug, PartialEq, Eq)]
    event TokensClaimed(
        address indexed beneficiary,
        uint256 amount
    );
}

#[cfg(test)]
mod tests {
    use alloy::sol_types::SolEvent;

    use super::*;

    #[test]
    fn emissions_distributed_signature() {
        assert_eq!(
            EmissionsDistributed::SIGNATURE,
            "EmissionsDistributed(uint256,uint256)"
        );
    }

    #[test]
    fn weights_updated_signature() {
        assert_eq!(WeightsUpdated::SIGNATURE, "WeightsUpdated(uint16[5])");
    }

    #[test]
    fn tokens_claimed_signature() {
        assert_eq!(TokensClaimed::SIGNATURE, "TokensClaimed(address,uint256)");
    }

    #[test]
    fn all_rewards_events_have_unique_signatures() {
        let signatures = [
            EmissionsDistributed::SIGNATURE_HASH,
            WeightsUpdated::SIGNATURE_HASH,
            TokensClaimed::SIGNATURE_HASH,
        ];

        let unique: std::collections::HashSet<_> = signatures.iter().collect();
        assert_eq!(
            unique.len(),
            3,
            "All RewardsDistributor events should have unique signatures"
        );
    }
}
