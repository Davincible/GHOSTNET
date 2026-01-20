//! ABI bindings for GHOSTNET smart contracts.
//!
//! This module provides type-safe Rust bindings for Solidity events using the
//! `alloy::sol!` macro. Each contract has its own submodule with event definitions.
//!
//! # Architecture
//!
//! ```text
//! ┌─────────────────────────────────────────────────────────────────┐
//! │                       ABI Bindings Layer                        │
//! │                                                                 │
//! │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
//! │  │ ghost_core  │  │ trace_scan  │  │  dead_pool  │             │
//! │  │  10 events  │  │  3 events   │  │  4 events   │             │
//! │  └─────────────┘  └─────────────┘  └─────────────┘             │
//! │                                                                 │
//! │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
//! │  │ data_token  │  │ fee_router  │  │ rewards_distributor     │ │
//! │  │  4 events   │  │  3 events   │  │ 3 events (incl vesting) │ │
//! │  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
//! └─────────────────────────────────────────────────────────────────┘
//! ```
//!
//! # Usage
//!
//! Events are decoded from raw logs using the `SolEvent` trait:
//!
//! ```ignore
//! use alloy::sol_types::SolEvent;
//! use ghostnet_indexer::abi::ghost_core::JackedIn;
//!
//! // Decode from a raw log
//! let event = JackedIn::decode_log(&log.inner, true)?;
//! println!("User {} jacked in at level {}", event.user, event.level);
//! ```
//!
//! # Contract Event Mapping
//!
//! | Contract | Module | Event Count | Description |
//! |----------|--------|-------------|-------------|
//! | `GhostCore` | [`ghost_core`] | 10 | Position lifecycle, boosts, system reset |
//! | `TraceScan` | [`trace_scan`] | 3 | Scan execution and finalization |
//! | `DeadPool` | [`dead_pool`] | 4 | Prediction market rounds and bets |
//! | `DataToken` | [`data_token`] | 4 | ERC20 transfers and tax events |
//! | `FeeRouter` | [`fee_router`] | 3 | Fee collection and buybacks |
//! | `RewardsDistributor` | [`rewards_distributor`] | 3 | Emissions and team vesting |

pub mod data_token;
pub mod dead_pool;
pub mod fee_router;
pub mod ghost_core;
pub mod rewards_distributor;
pub mod trace_scan;

// Re-export all event types for convenience
pub use data_token::{TaxBurned, TaxCollected, TaxExclusionSet, Transfer};
pub use dead_pool::{BetPlaced, RoundCreated, RoundResolved, WinningsClaimed};
pub use fee_router::{BuybackExecuted, OperationsWithdrawn, TollCollected};
pub use ghost_core::{
    BoostApplied, CascadeDistributed, DeathsProcessed, EmissionsAdded, Extracted, JackedIn,
    PositionCulled, StakeAdded, SurvivorsUpdated, SystemResetTriggered,
};
pub use rewards_distributor::{EmissionsDistributed, TokensClaimed, WeightsUpdated};
pub use trace_scan::{DeathsSubmitted, ScanExecuted, ScanFinalized};

#[cfg(test)]
mod tests {
    use alloy::sol_types::SolEvent;

    use super::*;

    /// Verify that all event signature hashes are unique (no collisions).
    #[test]
    fn event_signatures_are_unique() {
        let signatures = [
            // GhostCore
            JackedIn::SIGNATURE_HASH,
            StakeAdded::SIGNATURE_HASH,
            Extracted::SIGNATURE_HASH,
            DeathsProcessed::SIGNATURE_HASH,
            SurvivorsUpdated::SIGNATURE_HASH,
            CascadeDistributed::SIGNATURE_HASH,
            EmissionsAdded::SIGNATURE_HASH,
            BoostApplied::SIGNATURE_HASH,
            SystemResetTriggered::SIGNATURE_HASH,
            PositionCulled::SIGNATURE_HASH,
            // TraceScan
            ScanExecuted::SIGNATURE_HASH,
            DeathsSubmitted::SIGNATURE_HASH,
            ScanFinalized::SIGNATURE_HASH,
            // DeadPool
            RoundCreated::SIGNATURE_HASH,
            BetPlaced::SIGNATURE_HASH,
            RoundResolved::SIGNATURE_HASH,
            WinningsClaimed::SIGNATURE_HASH,
            // DataToken
            Transfer::SIGNATURE_HASH,
            TaxBurned::SIGNATURE_HASH,
            TaxCollected::SIGNATURE_HASH,
            TaxExclusionSet::SIGNATURE_HASH,
            // FeeRouter
            TollCollected::SIGNATURE_HASH,
            BuybackExecuted::SIGNATURE_HASH,
            OperationsWithdrawn::SIGNATURE_HASH,
            // RewardsDistributor
            EmissionsDistributed::SIGNATURE_HASH,
            WeightsUpdated::SIGNATURE_HASH,
            TokensClaimed::SIGNATURE_HASH,
        ];

        let mut seen = std::collections::HashSet::new();
        for sig in signatures {
            assert!(
                seen.insert(sig),
                "Duplicate event signature hash detected: {sig:?}"
            );
        }

        // Verify we have the expected count (27 events total)
        assert_eq!(seen.len(), 27, "Expected 27 unique event signatures");
    }

    /// Verify event signature strings match expected Solidity signatures.
    #[test]
    fn event_signature_strings() {
        // Spot-check a few critical events
        assert_eq!(
            JackedIn::SIGNATURE,
            "JackedIn(address,uint256,uint8,uint256)"
        );
        assert_eq!(Transfer::SIGNATURE, "Transfer(address,address,uint256)");
        assert_eq!(
            ScanExecuted::SIGNATURE,
            "ScanExecuted(uint8,uint256,uint256,uint64)"
        );
    }
}
