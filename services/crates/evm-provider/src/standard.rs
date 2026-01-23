//! Standard EVM provider implementation using alloy.
//!
//! This module provides [`StandardEvmProvider`], a concrete implementation of
//! [`ChainProvider`] that works with any standard EVM chain using alloy's
//! HTTP transport.
//!
//! # Example
//!
//! ```ignore
//! use evm_provider::{StandardEvmProvider, ChainProvider};
//!
//! // Connect to any EVM chain
//! let provider = StandardEvmProvider::new("https://eth.llamarpc.com").await?;
//!
//! // Use chain-agnostic interface
//! let balance = provider.get_balance(address).await?;
//! let nonce = provider.get_nonce(address).await?;
//! ```

use std::sync::Arc;
use std::time::Duration;

use alloy::network::{Ethereum, TransactionBuilder};
use alloy::primitives::{Address, Bytes, TxHash, U256};
use alloy::providers::{Provider, ProviderBuilder, RootProvider};
use alloy::rpc::types::{BlockNumberOrTag, TransactionRequest as AlloyTxRequest};
use async_trait::async_trait;
use tracing::{debug, instrument, warn};

use crate::error::{ProviderError, Result};
use crate::traits::ChainProvider;
use crate::types::{TransactionReceipt, TransactionRequest};

// ═══════════════════════════════════════════════════════════════════════════════
// STANDARD EVM PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

/// Standard EVM provider for chains without special features.
///
/// This provider uses alloy's HTTP transport and implements the full
/// [`ChainProvider`] trait for any standard EVM chain.
///
/// # Example
///
/// ```ignore
/// use evm_provider::StandardEvmProvider;
///
/// // Connect to Ethereum mainnet
/// let provider = StandardEvmProvider::new("https://eth.llamarpc.com").await?;
/// println!("Connected to chain {}", provider.chain_id());
///
/// // Connect with custom timeout
/// let provider = StandardEvmProvider::with_timeout(
///     "https://eth.llamarpc.com",
///     Duration::from_secs(60),
/// ).await?;
/// ```
#[derive(Debug, Clone)]
pub struct StandardEvmProvider {
    /// The underlying alloy provider.
    provider: Arc<RootProvider<Ethereum>>,
    /// Cached chain ID for fast access.
    chain_id: u64,
    /// Timeout for receipt polling.
    receipt_poll_interval: Duration,
}

impl StandardEvmProvider {
    /// Create a new provider connected to the given RPC URL.
    ///
    /// This will query the chain ID from the remote node.
    ///
    /// # Arguments
    ///
    /// * `rpc_url` - The HTTP RPC endpoint URL
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - The URL is invalid
    /// - Connection to the RPC endpoint fails
    /// - Chain ID query fails
    pub async fn new(rpc_url: &str) -> Result<Self> {
        Self::with_timeout(rpc_url, Duration::from_secs(30)).await
    }

    /// Create a new provider with a custom timeout.
    ///
    /// # Arguments
    ///
    /// * `rpc_url` - The HTTP RPC endpoint URL
    /// * `timeout` - Request timeout duration
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - The URL is invalid
    /// - The HTTP client cannot be built
    /// - Connection to the RPC endpoint fails
    /// - Chain ID query fails
    pub async fn with_timeout(rpc_url: &str, timeout: Duration) -> Result<Self> {
        let url: reqwest::Url = rpc_url
            .parse()
            .map_err(|e| ProviderError::InvalidConfig(format!("invalid RPC URL: {e}")))?;

        // Build HTTP client with timeout
        let client = reqwest::Client::builder()
            .timeout(timeout)
            .build()
            .map_err(|e| ProviderError::Connection(format!("failed to build HTTP client: {e}")))?;

        // Use ProviderBuilder with custom reqwest client
        // Note: ProviderBuilder::default() has no fillers enabled, which is what we want
        // for a raw provider (we manage nonces externally via NonceManager)
        let provider = ProviderBuilder::default().connect_reqwest(client, url);

        // Query chain ID
        let chain_id = provider
            .get_chain_id()
            .await
            .map_err(|e| ProviderError::Connection(format!("failed to get chain ID: {e}")))?;

        debug!(chain_id, rpc_url, "Connected to EVM chain");

        Ok(Self {
            provider: Arc::new(provider),
            chain_id,
            receipt_poll_interval: Duration::from_millis(500),
        })
    }

    /// Set the polling interval for receipt queries.
    ///
    /// Default is 500ms. Increase for busy chains or to reduce RPC load.
    #[must_use]
    pub const fn with_receipt_poll_interval(mut self, interval: Duration) -> Self {
        self.receipt_poll_interval = interval;
        self
    }

    /// Get a reference to the underlying alloy provider.
    ///
    /// Use this for operations not covered by the [`ChainProvider`] trait.
    pub fn inner(&self) -> &RootProvider<Ethereum> {
        &self.provider
    }

    /// Convert our `TransactionRequest` to alloy's format.
    fn to_alloy_request(tx: &TransactionRequest) -> AlloyTxRequest {
        let mut req = AlloyTxRequest::default();

        if let Some(from) = tx.from {
            req = req.from(from);
        }
        if let Some(to) = tx.to {
            req = req.to(to);
        }
        if let Some(value) = tx.value {
            req = req.value(value);
        }
        if let Some(ref data) = tx.data {
            req = req.input(data.clone().into());
        }
        if let Some(gas_limit) = tx.gas_limit {
            req = req.gas_limit(gas_limit);
        }
        if let Some(gas_price) = tx.gas_price {
            req = req.gas_price(gas_price);
        }
        if let Some(nonce) = tx.nonce {
            req = req.nonce(nonce);
        }
        if let Some(chain_id) = tx.chain_id {
            req.set_chain_id(chain_id);
        }

        req
    }

    /// Convert alloy receipt to our format.
    fn from_alloy_receipt(
        receipt: &alloy::rpc::types::TransactionReceipt,
    ) -> Result<TransactionReceipt> {
        Ok(TransactionReceipt {
            tx_hash: receipt.transaction_hash,
            block_hash: receipt
                .block_hash
                .ok_or_else(|| ProviderError::InvalidResponse("missing block_hash".into()))?,
            block_number: receipt
                .block_number
                .ok_or_else(|| ProviderError::InvalidResponse("missing block_number".into()))?,
            tx_index: receipt.transaction_index.unwrap_or(0),
            from: receipt.from,
            to: receipt.to,
            contract_address: receipt.contract_address,
            gas_used: receipt.gas_used,
            success: receipt.status(),
            logs: receipt.inner.logs().to_vec(),
        })
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHAIN PROVIDER IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════

#[async_trait]
impl ChainProvider for StandardEvmProvider {
    fn chain_id(&self) -> u64 {
        self.chain_id
    }

    #[instrument(skip(self), fields(chain_id = self.chain_id))]
    async fn get_balance(&self, address: Address) -> Result<U256> {
        self.provider
            .get_balance(address)
            .await
            .map_err(ProviderError::from)
    }

    #[instrument(skip(self), fields(chain_id = self.chain_id))]
    async fn get_nonce(&self, address: Address) -> Result<u64> {
        self.provider
            .get_transaction_count(address)
            .await
            .map_err(ProviderError::from)
    }

    #[instrument(skip(self), fields(chain_id = self.chain_id))]
    async fn get_pending_nonce(&self, address: Address) -> Result<u64> {
        self.provider
            .get_transaction_count(address)
            .block_id(BlockNumberOrTag::Pending.into())
            .await
            .map_err(ProviderError::from)
    }

    #[instrument(skip(self, tx), fields(chain_id = self.chain_id))]
    async fn send_raw_transaction(&self, tx: Bytes) -> Result<TxHash> {
        let pending = self
            .provider
            .send_raw_transaction(&tx)
            .await
            .map_err(ProviderError::from)?;

        Ok(*pending.tx_hash())
    }

    #[instrument(skip(self), fields(chain_id = self.chain_id))]
    async fn wait_for_receipt(
        &self,
        tx_hash: TxHash,
        timeout: Duration,
    ) -> Result<TransactionReceipt> {
        let start = std::time::Instant::now();

        loop {
            // Check timeout
            if start.elapsed() > timeout {
                return Err(ProviderError::ReceiptNotFound(tx_hash));
            }

            // Try to get receipt
            match self.provider.get_transaction_receipt(tx_hash).await {
                Ok(Some(receipt)) => {
                    return Self::from_alloy_receipt(&receipt);
                }
                Ok(None) => {
                    // Not yet mined, wait and retry
                    tokio::time::sleep(self.receipt_poll_interval).await;
                }
                Err(e) => {
                    warn!(
                        tx_hash = %tx_hash,
                        error = %e,
                        "Error fetching receipt, will retry"
                    );
                    tokio::time::sleep(self.receipt_poll_interval).await;
                }
            }
        }
    }

    #[instrument(skip(self, tx), fields(chain_id = self.chain_id))]
    async fn estimate_gas(&self, tx: &TransactionRequest) -> Result<u64> {
        let alloy_tx = Self::to_alloy_request(tx);

        self.provider
            .estimate_gas(alloy_tx)
            .await
            .map_err(ProviderError::from)
    }

    #[instrument(skip(self), fields(chain_id = self.chain_id))]
    async fn gas_price(&self) -> Result<u128> {
        self.provider
            .get_gas_price()
            .await
            .map_err(ProviderError::from)
    }

    #[instrument(skip(self, tx), fields(chain_id = self.chain_id))]
    async fn call(&self, tx: &TransactionRequest) -> Result<Bytes> {
        let alloy_tx = Self::to_alloy_request(tx);

        self.provider
            .call(alloy_tx)
            .await
            .map_err(ProviderError::from)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    // Note: These tests require a running anvil instance or real RPC endpoint.
    // They are ignored by default and can be run with:
    //   cargo test -p evm-provider -- --ignored

    #[tokio::test]
    #[ignore = "requires running RPC endpoint"]
    async fn test_connect_to_anvil() {
        let provider = StandardEvmProvider::new("http://127.0.0.1:8545")
            .await
            .expect("should connect to anvil");

        // Anvil default chain ID is 31337
        assert_eq!(provider.chain_id(), 31337);
    }

    #[tokio::test]
    #[ignore = "requires running RPC endpoint"]
    async fn test_get_balance() {
        let provider = StandardEvmProvider::new("http://127.0.0.1:8545")
            .await
            .expect("should connect");

        // Anvil's default funded address
        let address: Address = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
            .parse()
            .expect("valid address");

        let balance = provider.get_balance(address).await.expect("should get balance");

        // Anvil funds accounts with 10000 ETH by default
        assert!(balance > U256::ZERO);
    }

    #[tokio::test]
    #[ignore = "requires running RPC endpoint"]
    async fn test_get_nonce() {
        let provider = StandardEvmProvider::new("http://127.0.0.1:8545")
            .await
            .expect("should connect");

        let address: Address = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
            .parse()
            .expect("valid address");

        let nonce = provider.get_nonce(address).await.expect("should get nonce");

        // Fresh anvil instance should have nonce 0
        // (may be higher if tests have run transactions)
        assert!(nonce < 1000); // Sanity check
    }

    #[tokio::test]
    #[ignore = "requires running RPC endpoint"]
    async fn test_gas_price() {
        let provider = StandardEvmProvider::new("http://127.0.0.1:8545")
            .await
            .expect("should connect");

        let gas_price = provider.gas_price().await.expect("should get gas price");

        // Gas price should be non-zero
        assert!(gas_price > 0);
    }

    #[tokio::test]
    async fn test_invalid_url_fails() {
        let result = StandardEvmProvider::new("not-a-valid-url").await;
        assert!(result.is_err());

        let err = result.unwrap_err();
        assert!(err.to_string().contains("invalid"));
    }

    #[test]
    fn test_to_alloy_request() {
        let addr: Address = "0x1234567890123456789012345678901234567890"
            .parse()
            .expect("valid");

        let tx = TransactionRequest::new()
            .to(addr)
            .value(U256::from(1000))
            .gas_limit(21000)
            .nonce(5);

        let alloy_tx = StandardEvmProvider::to_alloy_request(&tx);

        assert_eq!(alloy_tx.to, Some(alloy::primitives::TxKind::Call(addr)));
        assert_eq!(alloy_tx.value, Some(U256::from(1000)));
        assert_eq!(alloy_tx.gas, Some(21000));
        assert_eq!(alloy_tx.nonce, Some(5));
    }
}
