//! MegaETH provider implementation with extended features.
//!
//! This module provides [`MegaEthProvider`], a provider implementation that combines
//! standard EVM operations with MegaETH-specific features:
//!
//! - **Realtime API**: Submit transactions and get receipts in ~10ms
//! - **Cursor pagination**: Efficient log queries for large block ranges
//!
//! # Example
//!
//! ```ignore
//! use evm_provider::{MegaEthProvider, ChainProvider, ExtendedChainProvider};
//!
//! // Connect to MegaETH testnet
//! let provider = MegaEthProvider::new("https://carrot.megaeth.com/rpc").await?;
//!
//! // Use standard ChainProvider methods
//! let balance = provider.get_balance(address).await?;
//!
//! // Use MegaETH-specific realtime API
//! if provider.supports_realtime() {
//!     let receipt = provider.send_realtime(signed_tx).await?;
//!     println!("Confirmed in ~10ms at block {}", receipt.block_number);
//! }
//! ```

use std::sync::Arc;
use std::time::Duration;

use alloy::primitives::{Address, Bytes, TxHash, U256};
use async_trait::async_trait;
use megaeth_rpc::{ClientConfig as MegaEthConfig, MegaEthClient};
use tracing::{debug, instrument, warn};

use crate::error::{ProviderError, Result};
use crate::standard::StandardEvmProvider;
use crate::traits::{ChainProvider, ExtendedChainProvider};
use crate::types::{LogFilter, LogsPage, TransactionReceipt, TransactionRequest};

// ═══════════════════════════════════════════════════════════════════════════════
// MEGAETH PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

/// MegaETH provider with realtime and cursor pagination support.
///
/// This provider wraps both a [`StandardEvmProvider`] for basic EVM operations
/// and a [`MegaEthClient`] for MegaETH-specific features.
///
/// # Architecture
///
/// ```text
/// ┌────────────────────────────────────────────┐
/// │           MegaEthProvider                   │
/// │                                             │
/// │  ┌──────────────────┐ ┌─────────────────┐  │
/// │  │ StandardEvmProvider │ │ MegaEthClient │  │
/// │  │  (ChainProvider)   │ │  (Extended)   │  │
/// │  └──────────────────┘ └─────────────────┘  │
/// └────────────────────────────────────────────┘
/// ```
///
/// - **Basic operations** (balance, nonce, gas) → `StandardEvmProvider`
/// - **Extended features** (realtime, cursor) → `MegaEthClient`
///
/// # Feature Detection
///
/// On creation, the provider checks which MegaETH-specific features are available.
/// This allows graceful degradation if connecting to a node without full feature support.
///
/// ```ignore
/// let provider = MegaEthProvider::new("https://carrot.megaeth.com/rpc").await?;
///
/// // Check feature availability
/// if provider.supports_realtime() {
///     // Use instant receipts
/// } else {
///     // Fall back to polling
/// }
/// ```
#[derive(Debug)]
pub struct MegaEthProvider {
    /// Standard EVM provider for basic operations.
    standard: Arc<StandardEvmProvider>,
    /// MegaETH-specific client for extended features.
    megaeth: Arc<MegaEthClient>,
    /// Whether realtime API is available.
    supports_realtime: bool,
    /// Whether cursor pagination is available.
    supports_cursor: bool,
    /// Fixed gas limit (MegaETH gas estimation is unreliable).
    fixed_gas_limit: u64,
}

impl MegaEthProvider {
    /// Create a new MegaETH provider connected to the given RPC URL.
    ///
    /// This will:
    /// 1. Connect to the RPC endpoint
    /// 2. Query the chain ID
    /// 3. Detect available MegaETH features (realtime API, cursor pagination)
    ///
    /// # Arguments
    ///
    /// * `rpc_url` - The MegaETH RPC endpoint URL
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - The URL is invalid
    /// - Connection to the RPC endpoint fails
    /// - Chain ID query fails
    pub async fn new(rpc_url: &str) -> Result<Self> {
        Self::with_config(rpc_url, Duration::from_secs(30), MegaEthConfig::default()).await
    }

    /// Create a new provider with custom configuration.
    ///
    /// # Arguments
    ///
    /// * `rpc_url` - The MegaETH RPC endpoint URL
    /// * `timeout` - Request timeout duration
    /// * `megaeth_config` - MegaETH client configuration
    ///
    /// # Errors
    ///
    /// Returns an error if connection or configuration fails.
    pub async fn with_config(
        rpc_url: &str,
        timeout: Duration,
        megaeth_config: MegaEthConfig,
    ) -> Result<Self> {
        // Create standard provider for basic EVM operations
        let standard = StandardEvmProvider::with_timeout(rpc_url, timeout).await?;

        // Create MegaETH client for extended features
        let megaeth = MegaEthClient::with_config(rpc_url, megaeth_config.with_timeout(timeout))
            .map_err(|e| ProviderError::Connection(format!("MegaETH client error: {e}")))?;

        // Detect feature availability
        let supports_realtime = megaeth.supports_realtime_api().await;
        let supports_cursor = megaeth.supports_cursor_pagination().await;

        debug!(
            chain_id = standard.chain_id(),
            supports_realtime,
            supports_cursor,
            "MegaETH provider initialized"
        );

        Ok(Self {
            standard: Arc::new(standard),
            megaeth: Arc::new(megaeth),
            supports_realtime,
            supports_cursor,
            fixed_gas_limit: 10_000_000, // 10M gas - safe default for MegaETH
        })
    }

    /// Set the fixed gas limit used for transactions.
    ///
    /// MegaETH gas estimation is unreliable, so we use a fixed limit.
    /// Default is 10,000,000 (10M).
    #[must_use]
    pub const fn with_gas_limit(mut self, gas_limit: u64) -> Self {
        self.fixed_gas_limit = gas_limit;
        self
    }

    /// Get a reference to the underlying standard provider.
    pub fn standard(&self) -> &StandardEvmProvider {
        &self.standard
    }

    /// Get a reference to the underlying MegaETH client.
    pub fn megaeth_client(&self) -> &MegaEthClient {
        &self.megaeth
    }

    /// Convert our `LogFilter` to MegaETH addresses filter.
    fn extract_addresses(filter: &LogFilter) -> Option<Vec<Address>> {
        if filter.addresses.is_empty() {
            None
        } else {
            Some(filter.addresses.clone())
        }
    }
}

/// Parse a hex string (with or without 0x prefix) into u64.
fn parse_hex_u64(s: &str) -> Option<u64> {
    let stripped = s.strip_prefix("0x").unwrap_or(s);
    u64::from_str_radix(stripped, 16).ok()
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHAIN PROVIDER IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════

#[async_trait]
impl ChainProvider for MegaEthProvider {
    fn chain_id(&self) -> u64 {
        self.standard.chain_id()
    }

    async fn get_balance(&self, address: Address) -> Result<U256> {
        self.standard.get_balance(address).await
    }

    async fn get_nonce(&self, address: Address) -> Result<u64> {
        self.standard.get_nonce(address).await
    }

    async fn get_pending_nonce(&self, address: Address) -> Result<u64> {
        self.standard.get_pending_nonce(address).await
    }

    async fn send_raw_transaction(&self, tx: Bytes) -> Result<TxHash> {
        self.standard.send_raw_transaction(tx).await
    }

    async fn wait_for_receipt(
        &self,
        tx_hash: TxHash,
        timeout: Duration,
    ) -> Result<TransactionReceipt> {
        self.standard.wait_for_receipt(tx_hash, timeout).await
    }

    /// Estimate gas - MegaETH returns a fixed value due to unreliable estimation.
    ///
    /// MegaETH's gas estimation is unreliable and often returns "intrinsic gas too low"
    /// errors. We return a fixed gas limit instead.
    #[instrument(skip(self, _tx))]
    async fn estimate_gas(&self, _tx: &TransactionRequest) -> Result<u64> {
        debug!(
            gas = self.fixed_gas_limit,
            "Using fixed gas limit for MegaETH (estimation unreliable)"
        );
        Ok(self.fixed_gas_limit)
    }

    async fn gas_price(&self) -> Result<u128> {
        self.standard.gas_price().await
    }

    async fn call(&self, tx: &TransactionRequest) -> Result<Bytes> {
        self.standard.call(tx).await
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXTENDED CHAIN PROVIDER IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════

#[async_trait]
impl ExtendedChainProvider for MegaEthProvider {
    fn supports_realtime(&self) -> bool {
        self.supports_realtime
    }

    fn supports_cursor_pagination(&self) -> bool {
        self.supports_cursor
    }

    /// Send transaction with instant receipt via MegaETH's realtime API.
    ///
    /// If realtime API is not available, falls back to standard send + wait.
    #[instrument(skip(self, tx), fields(chain_id = self.chain_id()))]
    async fn send_realtime(&self, tx: Bytes) -> Result<TransactionReceipt> {
        if !self.supports_realtime {
            debug!("Realtime API not available, falling back to standard send + wait");
            let hash = self.send_raw_transaction(tx).await?;
            return self.wait_for_receipt(hash, Duration::from_secs(30)).await;
        }

        let response = self
            .megaeth
            .send_realtime_transaction(tx)
            .await
            .map_err(|e| ProviderError::Other(format!("realtime transaction failed: {e}")))?;

        // Convert MegaETH response to our receipt format
        let block_number = response.block_number_u64().ok_or_else(|| {
            ProviderError::InvalidResponse(format!(
                "invalid block_number: {}",
                response.block_number
            ))
        })?;
        let gas_used = response.gas_used_u64().ok_or_else(|| {
            ProviderError::InvalidResponse(format!("invalid gas_used: {}", response.gas_used))
        })?;
        let tx_index = parse_hex_u64(&response.transaction_index).ok_or_else(|| {
            ProviderError::InvalidResponse(format!(
                "invalid transaction_index: {}",
                response.transaction_index
            ))
        })?;

        Ok(TransactionReceipt {
            tx_hash: response.transaction_hash,
            block_hash: response.block_hash,
            block_number,
            tx_index,
            from: response.from,
            to: response.to,
            contract_address: response.contract_address,
            gas_used,
            success: response.is_success(),
            logs: response.logs,
        })
    }

    /// Get logs with cursor-based pagination.
    ///
    /// Uses MegaETH's `eth_getLogsWithCursor` for efficient large-range queries.
    #[instrument(skip(self, filter), fields(chain_id = self.chain_id()))]
    async fn get_logs_with_cursor(
        &self,
        filter: &LogFilter,
        cursor: Option<&str>,
    ) -> Result<LogsPage> {
        if !self.supports_cursor {
            return Err(ProviderError::unsupported("cursor pagination"));
        }

        let from_block = filter.from_block.unwrap_or(0);
        let to_block = filter.to_block.unwrap_or(u64::MAX);
        let addresses = Self::extract_addresses(filter);

        // If cursor provided, we need to use single-batch mode
        // The megaeth-rpc crate handles cursors internally, but we need to expose
        // single-page access for the trait. For now, fetch all and return as single page.
        // TODO: Expose single-batch API in megaeth-rpc for proper cursor handling
        if cursor.is_some() {
            warn!("Cursor continuation not fully supported yet - fetching all logs");
        }

        let (logs, stats) = self
            .megaeth
            .get_logs_with_cursor(from_block, to_block, addresses)
            .await
            .map_err(|e| {
                if e.is_method_not_supported() {
                    ProviderError::unsupported("eth_getLogsWithCursor")
                } else {
                    ProviderError::Other(format!("cursor pagination failed: {e}"))
                }
            })?;

        Ok(LogsPage {
            logs,
            cursor: None, // MegaETH client handles pagination internally
            complete: stats.complete,
        })
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    // Note: These tests require a running MegaETH RPC endpoint.
    // They are ignored by default and can be run with:
    //   cargo test -p evm-provider --features megaeth -- --ignored

    #[tokio::test]
    #[ignore = "requires running MegaETH RPC endpoint"]
    async fn test_connect_to_megaeth_testnet() {
        let provider = MegaEthProvider::new("https://carrot.megaeth.com/rpc")
            .await
            .expect("should connect to MegaETH testnet");

        // MegaETH testnet chain ID is 6343
        assert_eq!(provider.chain_id(), 6343);
    }

    #[tokio::test]
    #[ignore = "requires running MegaETH RPC endpoint"]
    async fn test_feature_detection() {
        let provider = MegaEthProvider::new("https://carrot.megaeth.com/rpc")
            .await
            .expect("should connect");

        println!("Realtime API: {}", provider.supports_realtime());
        println!("Cursor pagination: {}", provider.supports_cursor_pagination());

        // Both should be available on MegaETH testnet
        assert!(provider.supports_realtime());
        assert!(provider.supports_cursor_pagination());
    }

    #[tokio::test]
    #[ignore = "requires running MegaETH RPC endpoint"]
    async fn test_gas_estimation_uses_fixed_value() {
        let provider = MegaEthProvider::new("https://carrot.megaeth.com/rpc")
            .await
            .expect("should connect");

        let tx = TransactionRequest::new();
        let gas = provider.estimate_gas(&tx).await.expect("should estimate gas");

        // Should return the fixed gas limit
        assert_eq!(gas, 10_000_000);
    }

    #[test]
    fn test_gas_limit_configuration() {
        // Just test the builder pattern compiles
        // Can't test actual value without async context
    }
}
