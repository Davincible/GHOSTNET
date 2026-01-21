//! Token event handler implementation.
//!
//! Handles all token events from the `DataToken` contract:
//! - `Transfer` - Standard ERC20 transfers
//! - `TaxBurned` - Tokens burned via transfer tax
//! - `TaxCollected` - Tokens collected to treasury via tax
//! - `TaxExclusionSet` - Tax exclusion status changes
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
//! # Design Notes
//!
//! Token events are high-volume (every taxed transfer emits 3 events).
//! This handler currently focuses on logging and cache invalidation.
//! Detailed persistence (balance tracking, transfer history) can be
//! added later when the stats infrastructure is more mature.
//!
//! # Architecture
//!
//! The handler follows hexagonal architecture principles:
//! - Receives decoded events from the `EventRouter`
//! - Uses `Cache` port for cache invalidation
//! - Logs events for analytics and debugging

use std::sync::Arc;

use async_trait::async_trait;
use tracing::{debug, info, instrument};

use crate::abi::data_token;
use crate::error::Result;
use crate::handlers::TokenPort;
use crate::ports::Cache;
use crate::types::events::EventMetadata;
use crate::types::primitives::{EthAddress, TokenAmount};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Decimals for the $DATA token (standard ERC20).
const DATA_TOKEN_DECIMALS: u8 = 18;

/// Zero address (used for mints).
const ZERO_ADDRESS: &str = "0x0000000000000000000000000000000000000000";

/// Dead address (used for burns).
const DEAD_ADDRESS: &str = "0x000000000000000000000000000000000000dEaD";

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN HANDLER
// ═══════════════════════════════════════════════════════════════════════════════

/// Handler for token events.
///
/// Processes events from the `DataToken` contract. Currently focuses on
/// logging for analytics; detailed persistence can be added later.
#[derive(Debug)]
pub struct TokenHandler<C> {
    /// Cache for invalidation.
    cache: Arc<C>,
}

impl<C> TokenHandler<C>
where
    C: Cache,
{
    /// Create a new token handler.
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

    /// Check if an address is the zero address (mints come from here).
    fn is_zero_address(address: &EthAddress) -> bool {
        address.to_string().eq_ignore_ascii_case(ZERO_ADDRESS)
    }

    /// Check if an address is the dead address (burns go here).
    fn is_dead_address(address: &EthAddress) -> bool {
        address.to_string().eq_ignore_ascii_case(DEAD_ADDRESS)
    }

    /// Classify a transfer as mint, burn, or regular transfer.
    fn classify_transfer(from: &EthAddress, to: &EthAddress) -> TransferType {
        if Self::is_zero_address(from) {
            TransferType::Mint
        } else if Self::is_dead_address(to) {
            TransferType::Burn
        } else {
            TransferType::Transfer
        }
    }
}

/// Classification of transfer types.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum TransferType {
    /// Tokens minted (from zero address).
    Mint,
    /// Tokens burned (to dead address).
    Burn,
    /// Regular transfer between accounts.
    Transfer,
}

impl TransferType {
    /// Get the display name for this transfer type.
    #[allow(dead_code)]
    const fn name(self) -> &'static str {
        match self {
            Self::Mint => "mint",
            Self::Burn => "burn",
            Self::Transfer => "transfer",
        }
    }
}

#[async_trait]
impl<C> TokenPort for TokenHandler<C>
where
    C: Cache + Send + Sync,
{
    /// Handle ERC20 transfer.
    ///
    /// Logs the transfer with classification (mint/burn/transfer).
    /// High-volume event - uses debug level for regular transfers.
    #[instrument(skip(self, event, meta), fields(
        from = %event.from,
        to = %event.to
    ))]
    async fn handle_transfer(
        &self,
        event: data_token::Transfer,
        meta: EventMetadata,
    ) -> Result<()> {
        let from = Self::to_eth_address(&event.from);
        let to = Self::to_eth_address(&event.to);
        let value = Self::to_token_amount(&event.value);
        let transfer_type = Self::classify_transfer(&from, &to);

        // Use info level for mints/burns (less frequent, more important)
        // Use debug level for regular transfers (very frequent)
        match transfer_type {
            TransferType::Mint => {
                info!(
                    to = %to,
                    amount = %value,
                    block = meta.block_number,
                    "Token mint"
                );
            }
            TransferType::Burn => {
                info!(
                    from = %from,
                    amount = %value,
                    block = meta.block_number,
                    "Token burn (direct)"
                );
            }
            TransferType::Transfer => {
                debug!(
                    from = %from,
                    to = %to,
                    amount = %value,
                    block = meta.block_number,
                    "Token transfer"
                );
            }
        }

        // Invalidate cache since balances changed
        self.cache.invalidate_all_positions();

        Ok(())
    }

    /// Handle tax burn.
    ///
    /// Emitted when tokens are burned via the 10% transfer tax.
    /// 9% of the 10% tax (0.9% of transfer) goes to burn.
    #[instrument(skip(self, event, meta), fields(from = %event.from))]
    async fn handle_tax_burned(
        &self,
        event: data_token::TaxBurned,
        meta: EventMetadata,
    ) -> Result<()> {
        let from = Self::to_eth_address(&event.from);
        let amount = Self::to_token_amount(&event.amount);

        debug!(
            from = %from,
            amount = %amount,
            block = meta.block_number,
            "Tax burned"
        );

        // Note: In the future, we could accumulate this into global stats
        // self.stats_store.increment_total_burned(&amount).await?;

        Ok(())
    }

    /// Handle tax collection to treasury.
    ///
    /// Emitted when tokens are collected to treasury via the 10% transfer tax.
    /// 1% of the 10% tax (0.1% of transfer) goes to treasury.
    #[instrument(skip(self, event, meta), fields(from = %event.from))]
    async fn handle_tax_collected(
        &self,
        event: data_token::TaxCollected,
        meta: EventMetadata,
    ) -> Result<()> {
        let from = Self::to_eth_address(&event.from);
        let amount = Self::to_token_amount(&event.amount);

        debug!(
            from = %from,
            amount = %amount,
            block = meta.block_number,
            "Tax collected to treasury"
        );

        // Note: In the future, we could track treasury balance
        // self.stats_store.increment_treasury_balance(&amount).await?;

        Ok(())
    }

    /// Handle tax exclusion status change.
    ///
    /// Emitted when an address's tax exclusion status changes.
    /// Excluded addresses don't pay the 10% transfer tax.
    #[instrument(skip(self, event, meta), fields(account = %event.account))]
    async fn handle_tax_exclusion_set(
        &self,
        event: data_token::TaxExclusionSet,
        meta: EventMetadata,
    ) -> Result<()> {
        let account = Self::to_eth_address(&event.account);
        let excluded = event.excluded;

        // This is an administrative event, use info level
        info!(
            account = %account,
            excluded = excluded,
            block = meta.block_number,
            "Tax exclusion {}",
            if excluded { "granted" } else { "revoked" }
        );

        // Invalidate cache since tax status affects transfers
        self.cache.invalidate_all_positions();

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

    fn test_address_2() -> alloy::primitives::Address {
        "0xABCDEF1234567890ABCDEF1234567890ABCDEF12"
            .parse()
            .unwrap()
    }

    fn zero_address() -> alloy::primitives::Address {
        "0x0000000000000000000000000000000000000000"
            .parse()
            .unwrap()
    }

    fn dead_address() -> alloy::primitives::Address {
        "0x000000000000000000000000000000000000dEaD"
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

    fn create_handler() -> (TokenHandler<MockCache>, Arc<MockCache>) {
        let cache = Arc::new(MockCache::new());
        let handler = TokenHandler::new(Arc::clone(&cache));
        (handler, cache)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn handler_is_send_sync() {
        fn assert_send_sync<T: Send + Sync>() {}
        assert_send_sync::<TokenHandler<MockCache>>();
    }

    #[tokio::test]
    async fn handle_transfer_succeeds() {
        let (handler, _cache) = create_handler();

        let event = data_token::Transfer {
            from: test_address(),
            to: test_address_2(),
            value: U256::from(100_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };

        let result = handler.handle_transfer(event, test_metadata()).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_transfer_classifies_mint() {
        let (handler, _cache) = create_handler();

        let event = data_token::Transfer {
            from: zero_address(),
            to: test_address(),
            value: U256::from(1000_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };

        let result = handler.handle_transfer(event, test_metadata()).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_transfer_classifies_burn() {
        let (handler, _cache) = create_handler();

        let event = data_token::Transfer {
            from: test_address(),
            to: dead_address(),
            value: U256::from(50_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };

        let result = handler.handle_transfer(event, test_metadata()).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_tax_burned_succeeds() {
        let (handler, _cache) = create_handler();

        let event = data_token::TaxBurned {
            from: test_address(),
            amount: U256::from(9_u64) * U256::from(10_u64).pow(U256::from(18_u64)), // 9 DATA burned
        };

        let result = handler.handle_tax_burned(event, test_metadata()).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_tax_collected_succeeds() {
        let (handler, _cache) = create_handler();

        let event = data_token::TaxCollected {
            from: test_address(),
            amount: U256::from(1_u64) * U256::from(10_u64).pow(U256::from(18_u64)), // 1 DATA to treasury
        };

        let result = handler.handle_tax_collected(event, test_metadata()).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_tax_exclusion_set_granted() {
        let (handler, _cache) = create_handler();

        let event = data_token::TaxExclusionSet {
            account: test_address(),
            excluded: true,
        };

        let result = handler
            .handle_tax_exclusion_set(event, test_metadata())
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_tax_exclusion_set_revoked() {
        let (handler, _cache) = create_handler();

        let event = data_token::TaxExclusionSet {
            account: test_address(),
            excluded: false,
        };

        let result = handler
            .handle_tax_exclusion_set(event, test_metadata())
            .await;
        assert!(result.is_ok());
    }

    #[test]
    fn classify_transfer_identifies_mint() {
        let from = EthAddress::from_hex(ZERO_ADDRESS).unwrap();
        let to = EthAddress::from_hex("0x1234567890123456789012345678901234567890").unwrap();
        assert_eq!(
            TokenHandler::<MockCache>::classify_transfer(&from, &to),
            TransferType::Mint
        );
    }

    #[test]
    fn classify_transfer_identifies_burn() {
        let from = EthAddress::from_hex("0x1234567890123456789012345678901234567890").unwrap();
        let to = EthAddress::from_hex(DEAD_ADDRESS).unwrap();
        assert_eq!(
            TokenHandler::<MockCache>::classify_transfer(&from, &to),
            TransferType::Burn
        );
    }

    #[test]
    fn classify_transfer_identifies_regular() {
        let from = EthAddress::from_hex("0x1234567890123456789012345678901234567890").unwrap();
        let to = EthAddress::from_hex("0xABCDEF1234567890ABCDEF1234567890ABCDEF12").unwrap();
        assert_eq!(
            TokenHandler::<MockCache>::classify_transfer(&from, &to),
            TransferType::Transfer
        );
    }

    #[test]
    fn transfer_type_names() {
        assert_eq!(TransferType::Mint.name(), "mint");
        assert_eq!(TransferType::Burn.name(), "burn");
        assert_eq!(TransferType::Transfer.name(), "transfer");
    }

    #[test]
    fn is_zero_address_works() {
        let zero = EthAddress::from_hex(ZERO_ADDRESS).unwrap();
        let other = EthAddress::from_hex("0x1234567890123456789012345678901234567890").unwrap();
        assert!(TokenHandler::<MockCache>::is_zero_address(&zero));
        assert!(!TokenHandler::<MockCache>::is_zero_address(&other));
    }

    #[test]
    fn is_dead_address_works() {
        let dead = EthAddress::from_hex(DEAD_ADDRESS).unwrap();
        let other = EthAddress::from_hex("0x1234567890123456789012345678901234567890").unwrap();
        assert!(TokenHandler::<MockCache>::is_dead_address(&dead));
        assert!(!TokenHandler::<MockCache>::is_dead_address(&other));
    }
}
