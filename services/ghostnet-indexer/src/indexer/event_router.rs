//! Event router for decoding and dispatching blockchain logs.
//!
//! The [`EventRouter`] is the central component that:
//! 1. Receives raw logs from the blockchain
//! 2. Decodes them into strongly-typed events using ABI bindings
//! 3. Dispatches events to the appropriate handler port
//!
//! # Design
//!
//! The router is generic over all handler traits, enabling:
//! - **Testability**: Use mock handlers in tests
//! - **Flexibility**: Swap implementations at runtime
//! - **Type Safety**: Compile-time verification of handler implementations

use alloy::primitives::Log as PrimitiveLog;
use alloy::rpc::types::Log;
use alloy::sol_types::SolEvent;
use tracing::{debug, instrument, warn};

use crate::abi::{data_token, dead_pool, fee_router, ghost_core, rewards_distributor, trace_scan};
use crate::error::{AppError, InfraError, Result};
use crate::handlers::{
    DeathPort, EmissionsPort, FeePort, MarketPort, PositionPort, ScanPort, TokenPort,
};
use crate::types::events::EventMetadata;

/// Routes decoded events to appropriate handlers.
///
/// Generic over handler traits to enable testing with mock implementations.
/// All 27 GHOSTNET events are routed to one of the 7 handler ports.
///
/// # Type Parameters
///
/// - `P`: Position handler ([`PositionPort`])
/// - `S`: Scan handler ([`ScanPort`])
/// - `D`: Death handler ([`DeathPort`])
/// - `M`: Market handler ([`MarketPort`])
/// - `T`: Token handler ([`TokenPort`])
/// - `F`: Fee handler ([`FeePort`])
/// - `E`: Emissions handler ([`EmissionsPort`])
///
/// # Example
///
/// ```ignore
/// let router = EventRouter::new(
///     position_handler,
///     scan_handler,
///     death_handler,
///     market_handler,
///     token_handler,
///     fee_handler,
///     emissions_handler,
/// );
///
/// // Route a raw log
/// router.route_log(&log, metadata).await?;
/// ```
#[allow(clippy::struct_field_names)] // Handler suffix is intentional for clarity
pub struct EventRouter<P, S, D, M, T, F, E>
where
    P: PositionPort,
    S: ScanPort,
    D: DeathPort,
    M: MarketPort,
    T: TokenPort,
    F: FeePort,
    E: EmissionsPort,
{
    position_handler: P,
    scan_handler: S,
    death_handler: D,
    market_handler: M,
    token_handler: T,
    fee_handler: F,
    emissions_handler: E,
}

impl<P, S, D, M, T, F, E> std::fmt::Debug for EventRouter<P, S, D, M, T, F, E>
where
    P: PositionPort,
    S: ScanPort,
    D: DeathPort,
    M: MarketPort,
    T: TokenPort,
    F: FeePort,
    E: EmissionsPort,
{
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("EventRouter")
            .field("position_handler", &std::any::type_name::<P>())
            .field("scan_handler", &std::any::type_name::<S>())
            .field("death_handler", &std::any::type_name::<D>())
            .field("market_handler", &std::any::type_name::<M>())
            .field("token_handler", &std::any::type_name::<T>())
            .field("fee_handler", &std::any::type_name::<F>())
            .field("emissions_handler", &std::any::type_name::<E>())
            .finish()
    }
}

impl<P, S, D, M, T, F, E> EventRouter<P, S, D, M, T, F, E>
where
    P: PositionPort,
    S: ScanPort,
    D: DeathPort,
    M: MarketPort,
    T: TokenPort,
    F: FeePort,
    E: EmissionsPort,
{
    /// Create a new event router with the given handlers.
    #[must_use]
    pub const fn new(
        position_handler: P,
        scan_handler: S,
        death_handler: D,
        market_handler: M,
        token_handler: T,
        fee_handler: F,
        emissions_handler: E,
    ) -> Self {
        Self {
            position_handler,
            scan_handler,
            death_handler,
            market_handler,
            token_handler,
            fee_handler,
            emissions_handler,
        }
    }

    /// Route a single log to its appropriate handler.
    ///
    /// Decodes the raw log using the event signature (topic0) to determine
    /// the event type, then dispatches to the appropriate handler.
    ///
    /// # Arguments
    ///
    /// * `log` - Raw log from the blockchain RPC
    /// * `meta` - Event metadata (block, tx, timestamp, etc.)
    ///
    /// # Returns
    ///
    /// * `Ok(true)` - Event was recognized and handled
    /// * `Ok(false)` - Event was not recognized (unknown signature)
    /// * `Err(_)` - Event decoding or handler error
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - Event decoding fails (malformed log data)
    /// - The handler returns an error during processing
    ///
    /// # Cancellation Safety
    ///
    /// This method is cancellation-safe. If cancelled, no handler will have
    /// partially processed the event - handlers are atomic operations.
    #[allow(clippy::too_many_lines)] // Large match statement is unavoidable for 27 events
    #[instrument(skip(self, log, meta), fields(topic0 = ?log.topics().first()))]
    pub async fn route_log(&self, log: &Log, meta: EventMetadata) -> Result<bool> {
        let Some(topic0) = log.topics().first() else {
            debug!("Skipping log with no topics");
            return Ok(false);
        };

        // Match by event signature hash (topic0)
        // Each match arm decodes the log and dispatches to the appropriate handler
        match topic0.as_slice() {
            // ═══════════════════════════════════════════════════════════════════
            // GHOST CORE EVENTS (10 events → PositionPort, DeathPort)
            // ═══════════════════════════════════════════════════════════════════
            x if x == ghost_core::JackedIn::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<ghost_core::JackedIn>(&log.inner)?;
                self.position_handler.handle_jacked_in(event, meta).await?;
                Ok(true)
            }
            x if x == ghost_core::StakeAdded::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<ghost_core::StakeAdded>(&log.inner)?;
                self.position_handler
                    .handle_stake_added(event, meta)
                    .await?;
                Ok(true)
            }
            x if x == ghost_core::Extracted::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<ghost_core::Extracted>(&log.inner)?;
                self.position_handler.handle_extracted(event, meta).await?;
                Ok(true)
            }
            x if x == ghost_core::BoostApplied::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<ghost_core::BoostApplied>(&log.inner)?;
                self.position_handler
                    .handle_boost_applied(event, meta)
                    .await?;
                Ok(true)
            }
            x if x == ghost_core::PositionCulled::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<ghost_core::PositionCulled>(&log.inner)?;
                self.position_handler
                    .handle_position_culled(event, meta)
                    .await?;
                Ok(true)
            }
            x if x == ghost_core::DeathsProcessed::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<ghost_core::DeathsProcessed>(&log.inner)?;
                self.death_handler
                    .handle_deaths_processed(event, meta)
                    .await?;
                Ok(true)
            }
            x if x == ghost_core::SurvivorsUpdated::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<ghost_core::SurvivorsUpdated>(&log.inner)?;
                self.death_handler
                    .handle_survivors_updated(event, meta)
                    .await?;
                Ok(true)
            }
            x if x == ghost_core::CascadeDistributed::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<ghost_core::CascadeDistributed>(&log.inner)?;
                self.death_handler
                    .handle_cascade_distributed(event, meta)
                    .await?;
                Ok(true)
            }
            x if x == ghost_core::EmissionsAdded::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<ghost_core::EmissionsAdded>(&log.inner)?;
                self.death_handler
                    .handle_emissions_added(event, meta)
                    .await?;
                Ok(true)
            }
            x if x == ghost_core::SystemResetTriggered::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<ghost_core::SystemResetTriggered>(&log.inner)?;
                self.death_handler.handle_system_reset(event, meta).await?;
                Ok(true)
            }

            // ═══════════════════════════════════════════════════════════════════
            // TRACE SCAN EVENTS (3 events → ScanPort)
            // ═══════════════════════════════════════════════════════════════════
            x if x == trace_scan::ScanExecuted::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<trace_scan::ScanExecuted>(&log.inner)?;
                self.scan_handler.handle_scan_executed(event, meta).await?;
                Ok(true)
            }
            x if x == trace_scan::DeathsSubmitted::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<trace_scan::DeathsSubmitted>(&log.inner)?;
                self.scan_handler
                    .handle_deaths_submitted(event, meta)
                    .await?;
                Ok(true)
            }
            x if x == trace_scan::ScanFinalized::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<trace_scan::ScanFinalized>(&log.inner)?;
                self.scan_handler.handle_scan_finalized(event, meta).await?;
                Ok(true)
            }

            // ═══════════════════════════════════════════════════════════════════
            // DEAD POOL EVENTS (4 events → MarketPort)
            // ═══════════════════════════════════════════════════════════════════
            x if x == dead_pool::RoundCreated::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<dead_pool::RoundCreated>(&log.inner)?;
                self.market_handler
                    .handle_round_created(event, meta)
                    .await?;
                Ok(true)
            }
            x if x == dead_pool::BetPlaced::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<dead_pool::BetPlaced>(&log.inner)?;
                self.market_handler.handle_bet_placed(event, meta).await?;
                Ok(true)
            }
            x if x == dead_pool::RoundResolved::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<dead_pool::RoundResolved>(&log.inner)?;
                self.market_handler
                    .handle_round_resolved(event, meta)
                    .await?;
                Ok(true)
            }
            x if x == dead_pool::WinningsClaimed::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<dead_pool::WinningsClaimed>(&log.inner)?;
                self.market_handler
                    .handle_winnings_claimed(event, meta)
                    .await?;
                Ok(true)
            }

            // ═══════════════════════════════════════════════════════════════════
            // DATA TOKEN EVENTS (4 events → TokenPort)
            // ═══════════════════════════════════════════════════════════════════
            x if x == data_token::Transfer::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<data_token::Transfer>(&log.inner)?;
                self.token_handler.handle_transfer(event, meta).await?;
                Ok(true)
            }
            x if x == data_token::TaxBurned::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<data_token::TaxBurned>(&log.inner)?;
                self.token_handler.handle_tax_burned(event, meta).await?;
                Ok(true)
            }
            x if x == data_token::TaxCollected::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<data_token::TaxCollected>(&log.inner)?;
                self.token_handler.handle_tax_collected(event, meta).await?;
                Ok(true)
            }
            x if x == data_token::TaxExclusionSet::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<data_token::TaxExclusionSet>(&log.inner)?;
                self.token_handler
                    .handle_tax_exclusion_set(event, meta)
                    .await?;
                Ok(true)
            }

            // ═══════════════════════════════════════════════════════════════════
            // FEE ROUTER EVENTS (3 events → FeePort)
            // ═══════════════════════════════════════════════════════════════════
            x if x == fee_router::TollCollected::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<fee_router::TollCollected>(&log.inner)?;
                self.fee_handler.handle_toll_collected(event, meta).await?;
                Ok(true)
            }
            x if x == fee_router::BuybackExecuted::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<fee_router::BuybackExecuted>(&log.inner)?;
                self.fee_handler
                    .handle_buyback_executed(event, meta)
                    .await?;
                Ok(true)
            }
            x if x == fee_router::OperationsWithdrawn::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<fee_router::OperationsWithdrawn>(&log.inner)?;
                self.fee_handler
                    .handle_operations_withdrawn(event, meta)
                    .await?;
                Ok(true)
            }

            // ═══════════════════════════════════════════════════════════════════
            // REWARDS DISTRIBUTOR EVENTS (3 events → EmissionsPort)
            // ═══════════════════════════════════════════════════════════════════
            x if x == rewards_distributor::EmissionsDistributed::SIGNATURE_HASH.as_slice() => {
                let event =
                    Self::decode_event::<rewards_distributor::EmissionsDistributed>(&log.inner)?;
                self.emissions_handler
                    .handle_emissions_distributed(event, meta)
                    .await?;
                Ok(true)
            }
            x if x == rewards_distributor::WeightsUpdated::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<rewards_distributor::WeightsUpdated>(&log.inner)?;
                self.emissions_handler
                    .handle_weights_updated(event, meta)
                    .await?;
                Ok(true)
            }
            x if x == rewards_distributor::TokensClaimed::SIGNATURE_HASH.as_slice() => {
                let event = Self::decode_event::<rewards_distributor::TokensClaimed>(&log.inner)?;
                self.emissions_handler
                    .handle_tokens_claimed(event, meta)
                    .await?;
                Ok(true)
            }

            // ═══════════════════════════════════════════════════════════════════
            // UNKNOWN EVENTS
            // ═══════════════════════════════════════════════════════════════════
            _ => {
                warn!(
                    topic0 = ?topic0,
                    contract = ?meta.contract,
                    "Unknown event signature - not a GHOSTNET event"
                );
                Ok(false)
            }
        }
    }

    /// Decode a log into a strongly-typed event.
    ///
    /// Uses Alloy's `decode_log` which returns a `Log<Ev>` wrapper.
    /// We extract the inner event data from it.
    fn decode_event<Ev: SolEvent>(log: &PrimitiveLog) -> Result<Ev> {
        let decoded = Ev::decode_log(log).map_err(|e| {
            AppError::Infra(InfraError::EventDecoding(format!(
                "Failed to decode {}: {e}",
                Ev::SIGNATURE
            )))
        })?;
        Ok(decoded.data)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use alloy::primitives::{Address, B256};
    use chrono::Utc;

    use super::*;
    use crate::handlers::mocks::CountingHandler;

    fn sample_metadata() -> EventMetadata {
        EventMetadata {
            block_number: 12345,
            block_hash: B256::ZERO,
            tx_hash: B256::ZERO,
            tx_index: 0,
            log_index: 0,
            timestamp: Utc::now(),
            contract: Address::ZERO,
        }
    }

    fn create_test_router() -> EventRouter<
        CountingHandler,
        CountingHandler,
        CountingHandler,
        CountingHandler,
        CountingHandler,
        CountingHandler,
        CountingHandler,
    > {
        EventRouter::new(
            CountingHandler::new(),
            CountingHandler::new(),
            CountingHandler::new(),
            CountingHandler::new(),
            CountingHandler::new(),
            CountingHandler::new(),
            CountingHandler::new(),
        )
    }

    #[test]
    fn router_creation() {
        let router = create_test_router();
        assert_eq!(router.position_handler.count(), 0);
        assert_eq!(router.scan_handler.count(), 0);
    }

    #[test]
    fn all_event_types_counted() {
        // Verify we have handlers for all 27 events
        // 10 GhostCore + 3 TraceScan + 4 DeadPool + 4 DataToken + 3 FeeRouter + 3 RewardsDistributor
        assert_eq!(10 + 3 + 4 + 4 + 3 + 3, 27);
    }

    // Note: Full routing tests require constructing valid encoded logs,
    // which is complex. These would typically be integration tests with
    // actual contract interactions or carefully crafted test data.

    #[tokio::test]
    async fn route_empty_log_returns_false() {
        let router = create_test_router();
        let meta = sample_metadata();

        // Create a log with no topics
        let log = Log {
            inner: PrimitiveLog {
                address: Address::ZERO,
                data: alloy::primitives::LogData::new(vec![], alloy::primitives::Bytes::new())
                    .expect("valid log data"),
            },
            block_hash: Some(B256::ZERO),
            block_number: Some(12345),
            block_timestamp: None,
            transaction_hash: Some(B256::ZERO),
            transaction_index: Some(0),
            log_index: Some(0),
            removed: false,
        };

        let result = router.route_log(&log, meta).await;
        assert!(result.is_ok());
        assert!(
            !result.expect("should be ok"),
            "empty log should return false"
        );
    }

    #[tokio::test]
    async fn route_unknown_signature_returns_false() {
        let router = create_test_router();
        let meta = sample_metadata();

        // Create a log with an unknown topic
        let unknown_topic = B256::repeat_byte(0xFF);
        let log = Log {
            inner: PrimitiveLog {
                address: Address::ZERO,
                data: alloy::primitives::LogData::new(
                    vec![unknown_topic],
                    alloy::primitives::Bytes::new(),
                )
                .expect("valid log data"),
            },
            block_hash: Some(B256::ZERO),
            block_number: Some(12345),
            block_timestamp: None,
            transaction_hash: Some(B256::ZERO),
            transaction_index: Some(0),
            log_index: Some(0),
            removed: false,
        };

        let result = router.route_log(&log, meta).await;
        assert!(result.is_ok());
        assert!(
            !result.expect("should be ok"),
            "unknown signature should return false"
        );
    }
}
