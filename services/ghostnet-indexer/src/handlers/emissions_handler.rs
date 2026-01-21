//! Emissions event handler implementation.
//!
//! Handles all emissions and vesting events from `RewardsDistributor` and `TeamVesting`:
//! - `EmissionsDistributed` - Periodic token emissions to levels
//! - `WeightsUpdated` - Level weight changes
//! - `TokensClaimed` - Team member vesting claims
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
//! # Team Vesting Schedule
//!
//! - 12-month cliff
//! - 36-month linear vesting
//! - Monthly claim periods
//!
//! # Architecture
//!
//! The handler follows hexagonal architecture principles:
//! - Receives decoded events from the `EventRouter`
//! - Uses `Cache` port for cache invalidation
//! - Logs events for analytics and debugging

use std::sync::Arc;

use async_trait::async_trait;
use chrono::{TimeZone, Utc};
use tracing::{info, instrument};

use crate::abi::rewards_distributor;
use crate::error::Result;
use crate::handlers::EmissionsPort;
use crate::ports::Cache;
use crate::types::events::EventMetadata;
use crate::types::primitives::{EthAddress, TokenAmount};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Decimals for the $DATA token (standard ERC20).
const DATA_TOKEN_DECIMALS: u8 = 18;

/// Basis points denominator (100% = 10000 bps).
const BASIS_POINTS_DENOMINATOR: u16 = 10000;

// ═══════════════════════════════════════════════════════════════════════════════
// EMISSIONS HANDLER
// ═══════════════════════════════════════════════════════════════════════════════

/// Handler for emissions and vesting events.
///
/// Processes events from `RewardsDistributor` and `TeamVesting` contracts.
/// These are lower-volume administrative events, so all are logged at info level.
#[derive(Debug)]
pub struct EmissionsHandler<C> {
    /// Cache for invalidation.
    cache: Arc<C>,
}

impl<C> EmissionsHandler<C>
where
    C: Cache,
{
    /// Create a new emissions handler.
    pub const fn new(cache: Arc<C>) -> Self {
        Self { cache }
    }

    /// Convert an Alloy Address to our `EthAddress` type.
    fn to_eth_address(address: &alloy::primitives::Address) -> EthAddress {
        EthAddress::from(*address)
    }

    /// Convert an Alloy U256 to our `TokenAmount` type.
    fn to_token_amount(value: &alloy::primitives::U256) -> TokenAmount {
        TokenAmount::from_wei(*value, DATA_TOKEN_DECIMALS)
    }

    /// Convert a unix timestamp (U256) to `DateTime`.
    #[allow(clippy::cast_possible_wrap)]
    fn to_datetime(timestamp: &alloy::primitives::U256) -> chrono::DateTime<Utc> {
        let ts: u64 = timestamp.try_into().unwrap_or(0);
        // Note: cast is safe for reasonable timestamps (before year 2262)
        Utc.timestamp_opt(ts as i64, 0)
            .single()
            .unwrap_or_else(Utc::now)
    }

    /// Convert weight basis points to percentage string.
    fn bps_to_percent(bps: u16) -> String {
        let percent = f64::from(bps) / f64::from(BASIS_POINTS_DENOMINATOR) * 100.0;
        format!("{percent:.2}%")
    }

    /// Format weights array with level names.
    fn format_weights(weights: &[u16; 5]) -> String {
        let levels = ["Vault", "Mainframe", "Subnet", "Darknet", "BlackIce"];
        levels
            .iter()
            .zip(weights.iter())
            .map(|(name, &weight)| format!("{}: {}", name, Self::bps_to_percent(weight)))
            .collect::<Vec<_>>()
            .join(", ")
    }

    /// Validate that weights sum to 100% (10000 bps).
    fn validate_weights(weights: &[u16; 5]) -> bool {
        let sum: u16 = weights.iter().sum();
        sum == BASIS_POINTS_DENOMINATOR
    }
}

#[async_trait]
impl<C> EmissionsPort for EmissionsHandler<C>
where
    C: Cache + Send + Sync,
{
    /// Handle emissions distribution.
    ///
    /// Emitted when the weekly emissions are distributed across all levels.
    #[instrument(skip(self, event, meta))]
    async fn handle_emissions_distributed(
        &self,
        event: rewards_distributor::EmissionsDistributed,
        meta: EventMetadata,
    ) -> Result<()> {
        let total_amount = Self::to_token_amount(&event.totalAmount);
        let distribution_time = Self::to_datetime(&event.timestamp);

        info!(
            total_amount = %total_amount,
            distribution_time = %distribution_time,
            block = meta.block_number,
            "Emissions distributed"
        );

        // Invalidate cache since rewards changed
        self.cache.invalidate_all_positions();

        // Note: In the future, we could track emissions stats
        // self.stats_store.increment_total_emissions(&total_amount).await?;

        Ok(())
    }

    /// Handle level weights update.
    ///
    /// Emitted when the emission weights for levels are changed.
    /// Weights are in basis points (100 = 1%), should sum to 10000 (100%).
    #[instrument(skip(self, event, meta))]
    async fn handle_weights_updated(
        &self,
        event: rewards_distributor::WeightsUpdated,
        meta: EventMetadata,
    ) -> Result<()> {
        let weights = event.newWeights;
        let formatted = Self::format_weights(&weights);
        let valid = Self::validate_weights(&weights);

        info!(
            weights = %formatted,
            valid = valid,
            raw_weights = ?weights,
            block = meta.block_number,
            "Emission weights updated"
        );

        if !valid {
            tracing::warn!(
                sum = weights.iter().sum::<u16>(),
                "Weights do not sum to 100%"
            );
        }

        // Invalidate cache since reward distribution will change
        self.cache.invalidate_all_positions();

        Ok(())
    }

    /// Handle team token claim.
    ///
    /// Emitted when a team member claims their vested tokens.
    #[instrument(skip(self, event, meta), fields(beneficiary = %event.beneficiary))]
    async fn handle_tokens_claimed(
        &self,
        event: rewards_distributor::TokensClaimed,
        meta: EventMetadata,
    ) -> Result<()> {
        let beneficiary = Self::to_eth_address(&event.beneficiary);
        let amount = Self::to_token_amount(&event.amount);

        info!(
            beneficiary = %beneficiary,
            amount = %amount,
            block = meta.block_number,
            "Team tokens claimed"
        );

        Ok(())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
#[allow(clippy::unwrap_used)]
mod tests {
    use alloy::primitives::U256;
    use chrono::Utc;

    use super::*;
    use crate::ports::MockCache;

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    fn test_address() -> alloy::primitives::Address {
        "0x1234567890123456789012345678901234567890"
            .parse()
            .unwrap()
    }

    fn test_metadata() -> EventMetadata {
        EventMetadata {
            block_number: 1000,
            block_hash: [1u8; 32].into(),
            tx_hash: [2u8; 32].into(),
            tx_index: 0,
            log_index: 0,
            timestamp: Utc::now(),
            contract: test_address(),
        }
    }

    fn create_handler() -> (EmissionsHandler<MockCache>, Arc<MockCache>) {
        let cache = Arc::new(MockCache::new());
        let handler = EmissionsHandler::new(Arc::clone(&cache));
        (handler, cache)
    }

    /// Default weights: Vault 5%, Mainframe 10%, Subnet 20%, Darknet 30%, Black Ice 35%.
    fn default_weights() -> [u16; 5] {
        [500, 1000, 2000, 3000, 3500] // Total: 10000 = 100%
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn handler_is_send_sync() {
        fn assert_send_sync<T: Send + Sync>() {}
        assert_send_sync::<EmissionsHandler<MockCache>>();
    }

    #[tokio::test]
    async fn handle_emissions_distributed_succeeds() {
        let (handler, _cache) = create_handler();

        let event = rewards_distributor::EmissionsDistributed {
            totalAmount: U256::from(100_000_u64) * U256::from(10_u64).pow(U256::from(18_u64)), // 100k DATA
            timestamp: U256::from(1_700_000_000_u64),
        };

        let result = handler
            .handle_emissions_distributed(event, test_metadata())
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_weights_updated_succeeds() {
        let (handler, _cache) = create_handler();

        let event = rewards_distributor::WeightsUpdated {
            newWeights: default_weights(),
        };

        let result = handler.handle_weights_updated(event, test_metadata()).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_weights_updated_with_invalid_sum() {
        let (handler, _cache) = create_handler();

        // Weights that don't sum to 10000
        let event = rewards_distributor::WeightsUpdated {
            newWeights: [500, 1000, 2000, 3000, 3000], // Total: 9500
        };

        // Should still succeed (just logs a warning)
        let result = handler.handle_weights_updated(event, test_metadata()).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_tokens_claimed_succeeds() {
        let (handler, _cache) = create_handler();

        let event = rewards_distributor::TokensClaimed {
            beneficiary: test_address(),
            amount: U256::from(10_000_u64) * U256::from(10_u64).pow(U256::from(18_u64)), // 10k DATA
        };

        let result = handler.handle_tokens_claimed(event, test_metadata()).await;
        assert!(result.is_ok());
    }

    #[test]
    fn bps_to_percent_conversion() {
        assert_eq!(
            EmissionsHandler::<MockCache>::bps_to_percent(500),
            "5.00%"
        );
        assert_eq!(
            EmissionsHandler::<MockCache>::bps_to_percent(1000),
            "10.00%"
        );
        assert_eq!(
            EmissionsHandler::<MockCache>::bps_to_percent(3500),
            "35.00%"
        );
        assert_eq!(
            EmissionsHandler::<MockCache>::bps_to_percent(10000),
            "100.00%"
        );
    }

    #[test]
    fn validate_weights_valid() {
        let weights = default_weights();
        assert!(EmissionsHandler::<MockCache>::validate_weights(&weights));
    }

    #[test]
    fn validate_weights_invalid_under() {
        let weights = [500, 1000, 2000, 3000, 3000]; // 9500
        assert!(!EmissionsHandler::<MockCache>::validate_weights(&weights));
    }

    #[test]
    fn validate_weights_invalid_over() {
        let weights = [500, 1000, 2000, 3000, 4000]; // 10500
        assert!(!EmissionsHandler::<MockCache>::validate_weights(&weights));
    }

    #[test]
    fn format_weights_produces_readable_output() {
        let weights = default_weights();
        let formatted = EmissionsHandler::<MockCache>::format_weights(&weights);
        assert!(formatted.contains("Vault: 5.00%"));
        assert!(formatted.contains("Mainframe: 10.00%"));
        assert!(formatted.contains("Subnet: 20.00%"));
        assert!(formatted.contains("Darknet: 30.00%"));
        assert!(formatted.contains("BlackIce: 35.00%"));
    }
}
