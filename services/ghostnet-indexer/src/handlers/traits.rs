//! Handler trait ports for event processing.
//!
//! Each trait defines a port for handling events from a specific domain area.
//! The [`crate::indexer::EventRouter`] dispatches decoded events to the
//! appropriate handler based on event type.

use async_trait::async_trait;

use crate::abi::{data_token, dead_pool, fee_router, ghost_core, rewards_distributor, trace_scan};
use crate::error::Result;
use crate::types::events::EventMetadata;

// ═══════════════════════════════════════════════════════════════════════════════
// POSITION PORT - Position lifecycle events from GhostCore
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for handling position lifecycle events.
///
/// Handles:
/// - Position entry (`JackedIn`)
/// - Stake additions (`StakeAdded`)
/// - Position extraction (`Extracted`)
/// - Boost applications (`BoostApplied`)
/// - Position culling (`PositionCulled`)
#[async_trait]
pub trait PositionPort: Send + Sync {
    /// Handle a new position entry.
    async fn handle_jacked_in(
        &self,
        event: ghost_core::JackedIn,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle stake addition to existing position.
    async fn handle_stake_added(
        &self,
        event: ghost_core::StakeAdded,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle position extraction.
    async fn handle_extracted(
        &self,
        event: ghost_core::Extracted,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle boost application from mini-games.
    async fn handle_boost_applied(
        &self,
        event: ghost_core::BoostApplied,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle position culling due to level capacity.
    async fn handle_position_culled(
        &self,
        event: ghost_core::PositionCulled,
        meta: EventMetadata,
    ) -> Result<()>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCAN PORT - Scan lifecycle events from TraceScan
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for handling scan lifecycle events.
///
/// Handles the two-phase scan process:
/// 1. `ScanExecuted` - Phase 1: Scan initiated with random seed
/// 2. `DeathsSubmitted` - Deaths submitted in batches by keepers
/// 3. `ScanFinalized` - Phase 2: Scan completed
#[async_trait]
pub trait ScanPort: Send + Sync {
    /// Handle scan execution (Phase 1).
    async fn handle_scan_executed(
        &self,
        event: trace_scan::ScanExecuted,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle deaths submission batch.
    async fn handle_deaths_submitted(
        &self,
        event: trace_scan::DeathsSubmitted,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle scan finalization (Phase 2).
    async fn handle_scan_finalized(
        &self,
        event: trace_scan::ScanFinalized,
        meta: EventMetadata,
    ) -> Result<()>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEATH PORT - Death processing events from GhostCore
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for handling death-related events.
///
/// Handles:
/// - Death processing after scans (`DeathsProcessed`)
/// - Survivor streak updates (`SurvivorsUpdated`)
/// - Cascade reward distribution (`CascadeDistributed`)
/// - Emissions to levels (`EmissionsAdded`)
/// - System reset (doomsday) (`SystemResetTriggered`)
#[async_trait]
pub trait DeathPort: Send + Sync {
    /// Handle deaths processed after a scan.
    async fn handle_deaths_processed(
        &self,
        event: ghost_core::DeathsProcessed,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle survivor streak updates.
    async fn handle_survivors_updated(
        &self,
        event: ghost_core::SurvivorsUpdated,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle cascade reward distribution.
    async fn handle_cascade_distributed(
        &self,
        event: ghost_core::CascadeDistributed,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle emissions added to a level.
    async fn handle_emissions_added(
        &self,
        event: ghost_core::EmissionsAdded,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle system reset (doomsday clock triggered).
    async fn handle_system_reset(
        &self,
        event: ghost_core::SystemResetTriggered,
        meta: EventMetadata,
    ) -> Result<()>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARKET PORT - Prediction market events from DeadPool
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for handling prediction market events.
///
/// Handles the `DeadPool` betting system:
/// - Round creation
/// - Bet placement
/// - Round resolution
/// - Winnings claims
#[async_trait]
pub trait MarketPort: Send + Sync {
    /// Handle new betting round creation.
    async fn handle_round_created(
        &self,
        event: dead_pool::RoundCreated,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle bet placement.
    async fn handle_bet_placed(
        &self,
        event: dead_pool::BetPlaced,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle round resolution.
    async fn handle_round_resolved(
        &self,
        event: dead_pool::RoundResolved,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle winnings claim.
    async fn handle_winnings_claimed(
        &self,
        event: dead_pool::WinningsClaimed,
        meta: EventMetadata,
    ) -> Result<()>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN PORT - ERC20 and tax events from DataToken
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for handling token events.
///
/// Handles `DataToken` ERC20 operations:
/// - Standard transfers
/// - Tax burns (9% of 10% tax)
/// - Tax collection to treasury (1% of 10% tax)
/// - Tax exclusion changes
#[async_trait]
pub trait TokenPort: Send + Sync {
    /// Handle ERC20 transfer.
    async fn handle_transfer(&self, event: data_token::Transfer, meta: EventMetadata)
    -> Result<()>;

    /// Handle tax burn.
    async fn handle_tax_burned(
        &self,
        event: data_token::TaxBurned,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle tax collection to treasury.
    async fn handle_tax_collected(
        &self,
        event: data_token::TaxCollected,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle tax exclusion status change.
    async fn handle_tax_exclusion_set(
        &self,
        event: data_token::TaxExclusionSet,
        meta: EventMetadata,
    ) -> Result<()>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEE PORT - Fee collection events from FeeRouter
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for handling fee events.
///
/// Handles `FeeRouter` monetization:
/// - Toll collection (per-action ETH fees)
/// - Buyback execution (ETH → DATA → burn)
/// - Operations fund withdrawals
#[async_trait]
pub trait FeePort: Send + Sync {
    /// Handle toll collection.
    async fn handle_toll_collected(
        &self,
        event: fee_router::TollCollected,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle buyback execution.
    async fn handle_buyback_executed(
        &self,
        event: fee_router::BuybackExecuted,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle operations fund withdrawal.
    async fn handle_operations_withdrawn(
        &self,
        event: fee_router::OperationsWithdrawn,
        meta: EventMetadata,
    ) -> Result<()>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMISSIONS PORT - Emissions and vesting events from RewardsDistributor
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for handling emissions and vesting events.
///
/// Handles `RewardsDistributor` and `TeamVesting`:
/// - Emissions distribution across levels
/// - Level weight updates
/// - Team token claims
#[async_trait]
pub trait EmissionsPort: Send + Sync {
    /// Handle emissions distribution.
    async fn handle_emissions_distributed(
        &self,
        event: rewards_distributor::EmissionsDistributed,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle level weights update.
    async fn handle_weights_updated(
        &self,
        event: rewards_distributor::WeightsUpdated,
        meta: EventMetadata,
    ) -> Result<()>;

    /// Handle team token claim.
    async fn handle_tokens_claimed(
        &self,
        event: rewards_distributor::TokensClaimed,
        meta: EventMetadata,
    ) -> Result<()>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOCK IMPLEMENTATIONS FOR TESTING
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
pub mod mocks {
    //! Mock handler implementations for testing.

    use std::sync::Arc;
    use std::sync::atomic::{AtomicUsize, Ordering};

    use super::*;

    /// Mock handler that counts method calls.
    ///
    /// Useful for verifying that the router dispatches events correctly.
    #[derive(Debug, Default, Clone)]
    pub struct CountingHandler {
        /// The number of times any handler method has been called.
        pub call_count: Arc<AtomicUsize>,
    }

    impl CountingHandler {
        /// Create a new counting handler.
        #[must_use]
        pub fn new() -> Self {
            Self::default()
        }

        /// Get the current call count.
        #[must_use]
        pub fn count(&self) -> usize {
            self.call_count.load(Ordering::SeqCst)
        }

        fn increment(&self) {
            self.call_count.fetch_add(1, Ordering::SeqCst);
        }
    }

    #[async_trait]
    impl PositionPort for CountingHandler {
        async fn handle_jacked_in(&self, _: ghost_core::JackedIn, _: EventMetadata) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_stake_added(
            &self,
            _: ghost_core::StakeAdded,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_extracted(&self, _: ghost_core::Extracted, _: EventMetadata) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_boost_applied(
            &self,
            _: ghost_core::BoostApplied,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_position_culled(
            &self,
            _: ghost_core::PositionCulled,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }
    }

    #[async_trait]
    impl ScanPort for CountingHandler {
        async fn handle_scan_executed(
            &self,
            _: trace_scan::ScanExecuted,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_deaths_submitted(
            &self,
            _: trace_scan::DeathsSubmitted,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_scan_finalized(
            &self,
            _: trace_scan::ScanFinalized,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }
    }

    #[async_trait]
    impl DeathPort for CountingHandler {
        async fn handle_deaths_processed(
            &self,
            _: ghost_core::DeathsProcessed,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_survivors_updated(
            &self,
            _: ghost_core::SurvivorsUpdated,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_cascade_distributed(
            &self,
            _: ghost_core::CascadeDistributed,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_emissions_added(
            &self,
            _: ghost_core::EmissionsAdded,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_system_reset(
            &self,
            _: ghost_core::SystemResetTriggered,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }
    }

    #[async_trait]
    impl MarketPort for CountingHandler {
        async fn handle_round_created(
            &self,
            _: dead_pool::RoundCreated,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_bet_placed(&self, _: dead_pool::BetPlaced, _: EventMetadata) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_round_resolved(
            &self,
            _: dead_pool::RoundResolved,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_winnings_claimed(
            &self,
            _: dead_pool::WinningsClaimed,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }
    }

    #[async_trait]
    impl TokenPort for CountingHandler {
        async fn handle_transfer(&self, _: data_token::Transfer, _: EventMetadata) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_tax_burned(
            &self,
            _: data_token::TaxBurned,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_tax_collected(
            &self,
            _: data_token::TaxCollected,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_tax_exclusion_set(
            &self,
            _: data_token::TaxExclusionSet,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }
    }

    #[async_trait]
    impl FeePort for CountingHandler {
        async fn handle_toll_collected(
            &self,
            _: fee_router::TollCollected,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_buyback_executed(
            &self,
            _: fee_router::BuybackExecuted,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_operations_withdrawn(
            &self,
            _: fee_router::OperationsWithdrawn,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }
    }

    #[async_trait]
    impl EmissionsPort for CountingHandler {
        async fn handle_emissions_distributed(
            &self,
            _: rewards_distributor::EmissionsDistributed,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_weights_updated(
            &self,
            _: rewards_distributor::WeightsUpdated,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }

        async fn handle_tokens_claimed(
            &self,
            _: rewards_distributor::TokensClaimed,
            _: EventMetadata,
        ) -> Result<()> {
            self.increment();
            Ok(())
        }
    }
}
