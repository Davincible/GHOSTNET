//! Fee event handler implementation.
//!
//! Handles all fee events from the `FeeRouter` contract:
//! - `TollCollected` - ETH fees collected for game actions
//! - `BuybackExecuted` - ETH spent to buy and burn DATA
//! - `OperationsWithdrawn` - ETH withdrawn to operations fund
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
//! # Toll Reason Hashes
//!
//! | Action | Reason Hash |
//! |--------|-------------|
//! | jackIn | `keccak256("jackIn")` |
//! | addStake | `keccak256("addStake")` |
//! | extract | `keccak256("extract")` |
//! | placeBet | `keccak256("placeBet")` |
//!
//! # Architecture
//!
//! The handler follows hexagonal architecture principles:
//! - Receives decoded events from the `EventRouter`
//! - Uses `Cache` port for cache invalidation
//! - Logs events for analytics and debugging

use std::sync::Arc;

use async_trait::async_trait;
use tracing::{info, instrument};

use crate::abi::fee_router;
use crate::error::Result;
use crate::handlers::FeePort;
use crate::ports::Cache;
use crate::types::events::EventMetadata;
use crate::types::primitives::{EthAddress, TokenAmount};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Decimals for ETH (18 decimals).
const ETH_DECIMALS: u8 = 18;

/// Decimals for the $DATA token (standard ERC20).
const DATA_TOKEN_DECIMALS: u8 = 18;

// Known toll reason hashes (keccak256 of action names).
// These are verified by tests to match actual keccak256 outputs.

/// Toll reason hash for `jackIn` action.
/// Computed: keccak256("jackIn")
const REASON_JACK_IN: [u8; 32] = [
    0x3d, 0xad, 0x1f, 0x6e, 0xd9, 0x9b, 0xba, 0x47, 0xd3, 0x79, 0x9f, 0x27, 0x63, 0x7c, 0x44, 0xb7,
    0xab, 0x31, 0x5e, 0x4c, 0x9d, 0xdc, 0x8b, 0xf6, 0x46, 0x6d, 0x2e, 0x24, 0xd9, 0x0a, 0x67, 0x78,
];

/// Toll reason hash for `addStake` action.
/// Computed: keccak256("addStake")
const REASON_ADD_STAKE: [u8; 32] = [
    0x17, 0x96, 0xc7, 0xaf, 0x18, 0xeb, 0xb2, 0xc1, 0x82, 0x4d, 0xbd, 0x14, 0xfc, 0x44, 0xb1, 0xcd,
    0x23, 0x37, 0x32, 0x67, 0x43, 0xc7, 0xba, 0xba, 0x7d, 0x8e, 0x5a, 0x79, 0x5c, 0xad, 0x7b, 0xe2,
];

/// Toll reason hash for `extract` action.
/// Computed: keccak256("extract")
const REASON_EXTRACT: [u8; 32] = [
    0xc3, 0xa7, 0x1a, 0xe8, 0x7b, 0x7c, 0x3e, 0xbd, 0xda, 0xc6, 0xa7, 0x1a, 0x07, 0x69, 0x39, 0x89,
    0x04, 0xaa, 0x1c, 0x02, 0x5b, 0xa7, 0x9c, 0xe8, 0x3e, 0x23, 0x7d, 0x58, 0x2b, 0x48, 0x44, 0x91,
];

/// Toll reason hash for `placeBet` action.
/// Computed: keccak256("placeBet")
const REASON_PLACE_BET: [u8; 32] = [
    0x47, 0xeb, 0x55, 0x1a, 0xa6, 0x54, 0x46, 0xb9, 0x89, 0xbe, 0xf2, 0xd9, 0x5e, 0x8c, 0xa2, 0xf6,
    0xe2, 0xc8, 0x11, 0x35, 0xc8, 0x44, 0x91, 0x0d, 0x2f, 0x2e, 0x57, 0xe6, 0x10, 0x2a, 0xd2, 0x73,
];

// ═══════════════════════════════════════════════════════════════════════════════
// FEE HANDLER
// ═══════════════════════════════════════════════════════════════════════════════

/// Handler for fee events.
///
/// Processes events from the `FeeRouter` contract. These are lower-volume
/// administrative events, so all are logged at info level.
#[derive(Debug)]
pub struct FeeHandler<C> {
    /// Cache for invalidation.
    cache: Arc<C>,
}

impl<C> FeeHandler<C>
where
    C: Cache,
{
    /// Create a new fee handler.
    pub const fn new(cache: Arc<C>) -> Self {
        Self { cache }
    }

    /// Convert an Alloy Address to our `EthAddress` type.
    fn to_eth_address(address: &alloy::primitives::Address) -> EthAddress {
        EthAddress::from(*address)
    }

    /// Convert an Alloy U256 to ETH amount.
    fn to_eth_amount(value: &alloy::primitives::U256) -> TokenAmount {
        TokenAmount::from_wei(*value, ETH_DECIMALS)
    }

    /// Convert an Alloy U256 to DATA token amount.
    fn to_data_amount(value: &alloy::primitives::U256) -> TokenAmount {
        TokenAmount::from_wei(*value, DATA_TOKEN_DECIMALS)
    }

    /// Decode a toll reason hash to a human-readable action name.
    fn decode_reason(reason: &alloy::primitives::FixedBytes<32>) -> &'static str {
        let bytes: [u8; 32] = reason.0;

        // Compare with known reason hashes
        if bytes == REASON_JACK_IN {
            "jackIn"
        } else if bytes == REASON_ADD_STAKE {
            "addStake"
        } else if bytes == REASON_EXTRACT {
            "extract"
        } else if bytes == REASON_PLACE_BET {
            "placeBet"
        } else {
            "unknown"
        }
    }
}

#[async_trait]
impl<C> FeePort for FeeHandler<C>
where
    C: Cache + Send + Sync,
{
    /// Handle toll collection.
    ///
    /// Emitted when a user pays an ETH toll for a game action.
    #[instrument(skip(self, event, meta), fields(from = %event.from))]
    async fn handle_toll_collected(
        &self,
        event: fee_router::TollCollected,
        meta: EventMetadata,
    ) -> Result<()> {
        let from = Self::to_eth_address(&event.from);
        let amount = Self::to_eth_amount(&event.amount);
        let action = Self::decode_reason(&event.reason);

        info!(
            from = %from,
            amount = %amount,
            action = action,
            reason_hash = %event.reason,
            block = meta.block_number,
            "Toll collected"
        );

        // Note: In the future, we could accumulate this into global stats
        // self.stats_store.increment_total_toll_collected(&amount).await?;

        Ok(())
    }

    /// Handle buyback execution.
    ///
    /// Emitted when accumulated ETH is used to buy and burn DATA tokens.
    /// This is a deflationary mechanism for the token.
    #[instrument(skip(self, event, meta))]
    async fn handle_buyback_executed(
        &self,
        event: fee_router::BuybackExecuted,
        meta: EventMetadata,
    ) -> Result<()> {
        let eth_spent = Self::to_eth_amount(&event.ethSpent);
        let data_received = Self::to_data_amount(&event.dataReceived);
        let data_burned = Self::to_data_amount(&event.dataBurned);

        info!(
            eth_spent = %eth_spent,
            data_received = %data_received,
            data_burned = %data_burned,
            block = meta.block_number,
            "Buyback executed"
        );

        // Invalidate cache since supply changed
        self.cache.invalidate_all_positions();

        // Note: In the future, we could track buyback stats
        // self.stats_store.increment_total_buyback_burned(&data_burned).await?;

        Ok(())
    }

    /// Handle operations fund withdrawal.
    ///
    /// Emitted when ETH is withdrawn from the operations fund.
    /// Operations fund covers server costs, marketing, development.
    #[instrument(skip(self, event, meta), fields(to = %event.to))]
    async fn handle_operations_withdrawn(
        &self,
        event: fee_router::OperationsWithdrawn,
        meta: EventMetadata,
    ) -> Result<()> {
        let to = Self::to_eth_address(&event.to);
        let amount = Self::to_eth_amount(&event.amount);

        info!(
            to = %to,
            amount = %amount,
            block = meta.block_number,
            "Operations funds withdrawn"
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
    use alloy::primitives::{FixedBytes, U256};
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

    fn test_address_2() -> alloy::primitives::Address {
        "0xABCDEF1234567890ABCDEF1234567890ABCDEF12"
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

    fn create_handler() -> (FeeHandler<MockCache>, Arc<MockCache>) {
        let cache = Arc::new(MockCache::new());
        let handler = FeeHandler::new(Arc::clone(&cache));
        (handler, cache)
    }

    fn reason_hash(name: &str) -> FixedBytes<32> {
        // Return the known constant for recognized names
        match name {
            "jackIn" => FixedBytes::from(REASON_JACK_IN),
            "addStake" => FixedBytes::from(REASON_ADD_STAKE),
            "extract" => FixedBytes::from(REASON_EXTRACT),
            "placeBet" => FixedBytes::from(REASON_PLACE_BET),
            _ => FixedBytes::ZERO,
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn handler_is_send_sync() {
        fn assert_send_sync<T: Send + Sync>() {}
        assert_send_sync::<FeeHandler<MockCache>>();
    }

    #[tokio::test]
    async fn handle_toll_collected_succeeds() {
        let (handler, _cache) = create_handler();

        let event = fee_router::TollCollected {
            from: test_address(),
            amount: U256::from(1_u64) * U256::from(10_u64).pow(U256::from(15_u64)), // 0.001 ETH
            reason: reason_hash("jackIn"),
        };

        let result = handler.handle_toll_collected(event, test_metadata()).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_toll_collected_with_unknown_reason() {
        let (handler, _cache) = create_handler();

        let event = fee_router::TollCollected {
            from: test_address(),
            amount: U256::from(1_u64) * U256::from(10_u64).pow(U256::from(15_u64)),
            reason: FixedBytes::from([0xABu8; 32]), // Unknown reason
        };

        let result = handler.handle_toll_collected(event, test_metadata()).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_buyback_executed_succeeds() {
        let (handler, _cache) = create_handler();

        let event = fee_router::BuybackExecuted {
            ethSpent: U256::from(10_u64) * U256::from(10_u64).pow(U256::from(18_u64)), // 10 ETH
            dataReceived: U256::from(100_000_u64) * U256::from(10_u64).pow(U256::from(18_u64)), // 100k DATA
            dataBurned: U256::from(100_000_u64) * U256::from(10_u64).pow(U256::from(18_u64)), // 100k DATA
        };

        let result = handler
            .handle_buyback_executed(event, test_metadata())
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_buyback_executed_with_zero_received() {
        let (handler, _cache) = create_handler();

        // Edge case: zero DATA received (shouldn't happen in practice)
        let event = fee_router::BuybackExecuted {
            ethSpent: U256::from(1_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            dataReceived: U256::ZERO,
            dataBurned: U256::ZERO,
        };

        let result = handler
            .handle_buyback_executed(event, test_metadata())
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_operations_withdrawn_succeeds() {
        let (handler, _cache) = create_handler();

        let event = fee_router::OperationsWithdrawn {
            to: test_address_2(),
            amount: U256::from(5_u64) * U256::from(10_u64).pow(U256::from(18_u64)), // 5 ETH
        };

        let result = handler
            .handle_operations_withdrawn(event, test_metadata())
            .await;
        assert!(result.is_ok());
    }

    #[test]
    fn decode_reason_jack_in() {
        let reason = FixedBytes::from(REASON_JACK_IN);
        assert_eq!(FeeHandler::<MockCache>::decode_reason(&reason), "jackIn");
    }

    #[test]
    fn decode_reason_add_stake() {
        let reason = FixedBytes::from(REASON_ADD_STAKE);
        assert_eq!(FeeHandler::<MockCache>::decode_reason(&reason), "addStake");
    }

    #[test]
    fn decode_reason_extract() {
        let reason = FixedBytes::from(REASON_EXTRACT);
        assert_eq!(FeeHandler::<MockCache>::decode_reason(&reason), "extract");
    }

    #[test]
    fn decode_reason_place_bet() {
        let reason = FixedBytes::from(REASON_PLACE_BET);
        assert_eq!(FeeHandler::<MockCache>::decode_reason(&reason), "placeBet");
    }

    #[test]
    fn decode_reason_unknown() {
        let reason = FixedBytes::from([0xFFu8; 32]);
        assert_eq!(FeeHandler::<MockCache>::decode_reason(&reason), "unknown");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // KECCAK256 HASH VERIFICATION TESTS
    // These ensure the hardcoded REASON_* constants match actual keccak256 hashes
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn verify_reason_jack_in_hash() {
        use alloy::primitives::keccak256;
        let computed = keccak256("jackIn");
        assert_eq!(
            computed.0, REASON_JACK_IN,
            "REASON_JACK_IN constant doesn't match keccak256(\"jackIn\")"
        );
    }

    #[test]
    fn verify_reason_add_stake_hash() {
        use alloy::primitives::keccak256;
        let computed = keccak256("addStake");
        assert_eq!(
            computed.0, REASON_ADD_STAKE,
            "REASON_ADD_STAKE constant doesn't match keccak256(\"addStake\")"
        );
    }

    #[test]
    fn verify_reason_extract_hash() {
        use alloy::primitives::keccak256;
        let computed = keccak256("extract");
        assert_eq!(
            computed.0, REASON_EXTRACT,
            "REASON_EXTRACT constant doesn't match keccak256(\"extract\")"
        );
    }

    #[test]
    fn verify_reason_place_bet_hash() {
        use alloy::primitives::keccak256;
        let computed = keccak256("placeBet");
        assert_eq!(
            computed.0, REASON_PLACE_BET,
            "REASON_PLACE_BET constant doesn't match keccak256(\"placeBet\")"
        );
    }
}
