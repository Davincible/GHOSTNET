//! Core traits for EVM chain providers.
//!
//! This module defines the fundamental abstractions for interacting with EVM chains:
//!
//! - [`ChainProvider`] - Basic blockchain operations (balance, nonce, send tx)
//! - [`ExtendedChainProvider`] - Extended features (realtime API, cursor pagination)
//! - [`NonceManager`] - Thread-safe nonce tracking for high-throughput scenarios
//!
//! # Design Philosophy
//!
//! These traits are designed to:
//! - **Be chain-agnostic**: Work with any EVM-compatible chain
//! - **Hide implementation details**: Callers don't need to know about MegaETH quirks
//! - **Support testing**: Easy to implement mock providers for testing
//! - **Be minimal**: Only include operations that require chain interaction
//!
//! # Example
//!
//! ```ignore
//! use evm_provider::{ChainProvider, TransactionRequest};
//!
//! async fn send_eth<P: ChainProvider>(
//!     provider: &P,
//!     to: Address,
//!     amount: U256,
//! ) -> Result<TxHash> {
//!     let request = TransactionRequest::new()
//!         .to(to)
//!         .value(amount);
//!
//!     // Build and sign transaction...
//!     provider.send_raw_transaction(signed_tx).await
//! }
//! ```

use std::time::Duration;

use alloy::primitives::{Address, Bytes, TxHash, U256};
use async_trait::async_trait;

use crate::error::{ProviderError, Result};
use crate::types::{LogFilter, LogsPage, TransactionReceipt, TransactionRequest};

// ═══════════════════════════════════════════════════════════════════════════════
// CHAIN PROVIDER TRAIT
// ═══════════════════════════════════════════════════════════════════════════════

/// Core trait for interacting with any EVM chain.
///
/// Implementations handle chain-specific details (gas estimation, transaction format,
/// RPC quirks) while presenting a uniform interface to callers.
///
/// # Required Methods
///
/// Implementors must provide:
/// - [`chain_id`](Self::chain_id) - Chain identifier
/// - [`get_balance`](Self::get_balance) - Native token balance
/// - [`get_nonce`](Self::get_nonce) - Transaction count
/// - [`send_raw_transaction`](Self::send_raw_transaction) - Submit signed transaction
/// - [`wait_for_receipt`](Self::wait_for_receipt) - Wait for confirmation
/// - [`gas_price`](Self::gas_price) - Current gas price
/// - [`call`](Self::call) - Execute read-only call
///
/// # Optional Methods
///
/// These have default implementations but can be overridden:
/// - [`estimate_gas`](Self::estimate_gas) - Gas estimation (default: 500,000)
/// - [`get_pending_nonce`](Self::get_pending_nonce) - Includes mempool (default: same as get_nonce)
/// - [`get_token_balance`](Self::get_token_balance) - ERC20 balance (default: uses call)
#[async_trait]
pub trait ChainProvider: Send + Sync + 'static {
    /// Chain identifier (e.g., 1 for Ethereum mainnet, 6343 for MegaETH testnet).
    fn chain_id(&self) -> u64;

    /// Get native token balance (ETH) for an address.
    ///
    /// # Arguments
    ///
    /// * `address` - The address to query
    ///
    /// # Returns
    ///
    /// Balance in wei
    async fn get_balance(&self, address: Address) -> Result<U256>;

    /// Get current nonce (confirmed transaction count) for an address.
    ///
    /// This returns the nonce for the next transaction that will be confirmed.
    /// For high-throughput scenarios, use [`get_pending_nonce`](Self::get_pending_nonce)
    /// or a [`NonceManager`].
    ///
    /// # Arguments
    ///
    /// * `address` - The address to query
    async fn get_nonce(&self, address: Address) -> Result<u64>;

    /// Get pending nonce (includes mempool transactions) for an address.
    ///
    /// This returns the nonce for the next transaction that will be accepted,
    /// accounting for transactions in the mempool.
    ///
    /// Default implementation calls [`get_nonce`](Self::get_nonce) - override if
    /// your chain supports pending nonce queries.
    async fn get_pending_nonce(&self, address: Address) -> Result<u64> {
        self.get_nonce(address).await
    }

    /// Send a signed transaction to the network.
    ///
    /// # Arguments
    ///
    /// * `tx` - RLP-encoded signed transaction bytes
    ///
    /// # Returns
    ///
    /// Transaction hash. This does NOT mean the transaction is confirmed -
    /// use [`wait_for_receipt`](Self::wait_for_receipt) to wait for confirmation.
    async fn send_raw_transaction(&self, tx: Bytes) -> Result<TxHash>;

    /// Wait for a transaction to be confirmed.
    ///
    /// # Arguments
    ///
    /// * `tx_hash` - Hash of the transaction to wait for
    /// * `timeout` - Maximum time to wait
    ///
    /// # Returns
    ///
    /// The transaction receipt, or error if timeout or transaction failed.
    async fn wait_for_receipt(
        &self,
        tx_hash: TxHash,
        timeout: Duration,
    ) -> Result<TransactionReceipt>;

    /// Estimate gas for a transaction.
    ///
    /// Default implementation returns 500,000 which is safe for most operations.
    /// Override if your chain has different gas costs or supports estimation.
    ///
    /// # Note
    ///
    /// MegaETH gas estimation is unreliable - the `MegaEthProvider` overrides
    /// this to use a fixed gas limit.
    async fn estimate_gas(&self, _tx: &TransactionRequest) -> Result<u64> {
        Ok(500_000)
    }

    /// Get current gas price in wei.
    ///
    /// For EIP-1559 chains, this typically returns the suggested max fee.
    async fn gas_price(&self) -> Result<u128>;

    /// Execute a read-only call against the chain.
    ///
    /// This does not create a transaction - it simulates execution and returns
    /// the result.
    ///
    /// # Arguments
    ///
    /// * `tx` - Transaction request (only `to` and `data` are required)
    ///
    /// # Returns
    ///
    /// Return data from the call
    async fn call(&self, tx: &TransactionRequest) -> Result<Bytes>;

    /// Get ERC20 token balance for an address.
    ///
    /// Default implementation uses [`call`](Self::call) with the standard
    /// `balanceOf(address)` selector.
    async fn get_token_balance(&self, token: Address, account: Address) -> Result<U256> {
        // ERC20 balanceOf(address) selector: 0x70a08231
        let selector = [0x70, 0xa0, 0x82, 0x31];
        let mut data = selector.to_vec();
        // Pad address to 32 bytes
        data.extend_from_slice(&[0u8; 12]);
        data.extend_from_slice(account.as_slice());

        let request = TransactionRequest::new()
            .to(token)
            .data(Bytes::from(data));

        let result = self.call(&request).await?;

        // Parse U256 from 32-byte result
        if result.len() < 32 {
            return Err(ProviderError::InvalidResponse(
                "balanceOf returned less than 32 bytes".into(),
            ));
        }

        Ok(U256::from_be_slice(&result[..32]))
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXTENDED CHAIN PROVIDER TRAIT
// ═══════════════════════════════════════════════════════════════════════════════

/// Extended capabilities for chains that support them.
///
/// This trait extends [`ChainProvider`] with optional features that may not be
/// available on all chains:
///
/// - **Realtime transactions**: Send transaction and get receipt immediately
/// - **Cursor pagination**: Efficient log queries for high-throughput chains
///
/// # Feature Detection
///
/// Use [`supports_realtime`](Self::supports_realtime) and
/// [`supports_cursor_pagination`](Self::supports_cursor_pagination) to check
/// feature availability before calling these methods.
#[async_trait]
pub trait ExtendedChainProvider: ChainProvider {
    /// Check if this provider supports realtime transaction submission.
    ///
    /// When `true`, [`send_realtime`](Self::send_realtime) will return immediately
    /// with the receipt. When `false`, it falls back to send + wait.
    fn supports_realtime(&self) -> bool {
        false
    }

    /// Check if this provider supports cursor-based log pagination.
    ///
    /// When `true`, [`get_logs_with_cursor`](Self::get_logs_with_cursor) will use
    /// efficient cursor-based pagination. When `false`, it falls back to standard
    /// `eth_getLogs`.
    fn supports_cursor_pagination(&self) -> bool {
        false
    }

    /// Send transaction with instant receipt (MegaETH realtime API).
    ///
    /// On chains that support it, this submits the transaction and returns
    /// the receipt in a single call (~10ms on MegaETH).
    ///
    /// Default implementation falls back to `send_raw_transaction` + `wait_for_receipt`.
    async fn send_realtime(&self, tx: Bytes) -> Result<TransactionReceipt> {
        let hash = self.send_raw_transaction(tx).await?;
        self.wait_for_receipt(hash, Duration::from_secs(30)).await
    }

    /// Get logs with cursor-based pagination.
    ///
    /// On chains that support it, this uses efficient cursor-based pagination
    /// for querying large log ranges without hitting resource limits.
    ///
    /// # Arguments
    ///
    /// * `filter` - Log filter parameters
    /// * `cursor` - Cursor from previous page, or `None` for first page
    ///
    /// # Returns
    ///
    /// A page of logs with an optional cursor for the next page.
    ///
    /// Default implementation returns an unsupported error.
    async fn get_logs_with_cursor(
        &self,
        _filter: &LogFilter,
        _cursor: Option<&str>,
    ) -> Result<LogsPage> {
        Err(ProviderError::unsupported("cursor pagination"))
    }

    /// Get all logs matching a filter, handling pagination automatically.
    ///
    /// This is a convenience method that handles cursor pagination internally,
    /// accumulating all logs into a single vector.
    ///
    /// # Warning
    ///
    /// For very large queries, this can consume significant memory.
    /// Consider using [`get_logs_with_cursor`](Self::get_logs_with_cursor)
    /// directly for streaming processing.
    async fn get_all_logs(&self, filter: &LogFilter) -> Result<Vec<alloy::rpc::types::Log>> {
        if !self.supports_cursor_pagination() {
            return Err(ProviderError::unsupported("cursor pagination"));
        }

        let mut all_logs = Vec::new();
        let mut cursor: Option<String> = None;

        loop {
            let page = self
                .get_logs_with_cursor(filter, cursor.as_deref())
                .await?;
            all_logs.extend(page.logs);

            if page.complete || page.cursor.is_none() {
                break;
            }
            cursor = page.cursor;
        }

        Ok(all_logs)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NONCE MANAGER TRAIT
// ═══════════════════════════════════════════════════════════════════════════════

/// Thread-safe nonce management for high-throughput scenarios.
///
/// When sending many transactions quickly, querying the chain for each nonce
/// is too slow and can lead to race conditions. A `NonceManager` tracks nonces
/// locally, synchronizing with the chain as needed.
///
/// # Example
///
/// ```ignore
/// use evm_provider::NonceManager;
///
/// // Get nonce and increment atomically
/// let nonce = manager.get_and_increment(address).await?;
///
/// // Build and send transaction with this nonce...
///
/// // If transaction fails, resync with chain
/// if tx_failed {
///     manager.sync(address).await?;
/// }
/// ```
#[async_trait]
pub trait NonceManager: Send + Sync {
    /// Get the next nonce for an address and atomically increment the counter.
    ///
    /// This is the primary method for obtaining nonces. It's atomic - concurrent
    /// calls will receive different nonces.
    ///
    /// # Arguments
    ///
    /// * `address` - The address to get a nonce for
    ///
    /// # Returns
    ///
    /// The nonce to use for the next transaction
    async fn get_and_increment(&self, address: Address) -> Result<u64>;

    /// Synchronize the local nonce with the chain state.
    ///
    /// Call this after transaction failures or when you suspect the local
    /// nonce is out of sync with the chain.
    ///
    /// # Arguments
    ///
    /// * `address` - The address to sync
    async fn sync(&self, address: Address) -> Result<()>;

    /// Manually set the nonce for an address.
    ///
    /// Use with caution - this bypasses synchronization with the chain.
    /// Typically only needed for testing or recovery scenarios.
    ///
    /// # Arguments
    ///
    /// * `address` - The address to set the nonce for
    /// * `nonce` - The nonce value to set
    fn set(&self, address: Address, nonce: u64);

    /// Get the current nonce without incrementing.
    ///
    /// Useful for checking the current state without consuming a nonce.
    fn peek(&self, address: Address) -> Option<u64>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BLANKET IMPLEMENTATIONS
// ═══════════════════════════════════════════════════════════════════════════════

// Allow Arc<T> to be used as ChainProvider
#[async_trait]
impl<T: ChainProvider + ?Sized> ChainProvider for std::sync::Arc<T> {
    fn chain_id(&self) -> u64 {
        (**self).chain_id()
    }

    async fn get_balance(&self, address: Address) -> Result<U256> {
        (**self).get_balance(address).await
    }

    async fn get_nonce(&self, address: Address) -> Result<u64> {
        (**self).get_nonce(address).await
    }

    async fn get_pending_nonce(&self, address: Address) -> Result<u64> {
        (**self).get_pending_nonce(address).await
    }

    async fn send_raw_transaction(&self, tx: Bytes) -> Result<TxHash> {
        (**self).send_raw_transaction(tx).await
    }

    async fn wait_for_receipt(
        &self,
        tx_hash: TxHash,
        timeout: Duration,
    ) -> Result<TransactionReceipt> {
        (**self).wait_for_receipt(tx_hash, timeout).await
    }

    async fn estimate_gas(&self, tx: &TransactionRequest) -> Result<u64> {
        (**self).estimate_gas(tx).await
    }

    async fn gas_price(&self) -> Result<u128> {
        (**self).gas_price().await
    }

    async fn call(&self, tx: &TransactionRequest) -> Result<Bytes> {
        (**self).call(tx).await
    }

    async fn get_token_balance(&self, token: Address, account: Address) -> Result<U256> {
        (**self).get_token_balance(token, account).await
    }
}

#[async_trait]
impl<T: ExtendedChainProvider + ?Sized> ExtendedChainProvider for std::sync::Arc<T> {
    fn supports_realtime(&self) -> bool {
        (**self).supports_realtime()
    }

    fn supports_cursor_pagination(&self) -> bool {
        (**self).supports_cursor_pagination()
    }

    async fn send_realtime(&self, tx: Bytes) -> Result<TransactionReceipt> {
        (**self).send_realtime(tx).await
    }

    async fn get_logs_with_cursor(
        &self,
        filter: &LogFilter,
        cursor: Option<&str>,
    ) -> Result<LogsPage> {
        (**self).get_logs_with_cursor(filter, cursor).await
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    // Mock provider for testing
    struct MockProvider {
        chain_id: u64,
    }

    #[async_trait]
    impl ChainProvider for MockProvider {
        fn chain_id(&self) -> u64 {
            self.chain_id
        }

        async fn get_balance(&self, _address: Address) -> Result<U256> {
            Ok(U256::from(1_000_000_000_000_000_000u64))
        }

        async fn get_nonce(&self, _address: Address) -> Result<u64> {
            Ok(42)
        }

        async fn send_raw_transaction(&self, _tx: Bytes) -> Result<TxHash> {
            Ok(TxHash::ZERO)
        }

        async fn wait_for_receipt(
            &self,
            tx_hash: TxHash,
            _timeout: Duration,
        ) -> Result<TransactionReceipt> {
            Ok(TransactionReceipt {
                tx_hash,
                block_hash: alloy::primitives::B256::ZERO,
                block_number: 100,
                tx_index: 0,
                from: Address::ZERO,
                to: Some(Address::ZERO),
                contract_address: None,
                gas_used: 21000,
                success: true,
                logs: vec![],
            })
        }

        async fn gas_price(&self) -> Result<u128> {
            Ok(1_000_000_000)
        }

        async fn call(&self, _tx: &TransactionRequest) -> Result<Bytes> {
            // Return 1 ETH as U256
            let mut result = vec![0u8; 32];
            result[31] = 1;
            Ok(Bytes::from(result))
        }
    }

    #[tokio::test]
    async fn mock_provider_chain_id() {
        let provider = MockProvider { chain_id: 6343 };
        assert_eq!(provider.chain_id(), 6343);
    }

    #[tokio::test]
    async fn mock_provider_balance() {
        let provider = MockProvider { chain_id: 1 };
        let balance = provider.get_balance(Address::ZERO).await.unwrap();
        assert_eq!(balance, U256::from(1_000_000_000_000_000_000u64));
    }

    #[tokio::test]
    async fn mock_provider_estimate_gas_default() {
        let provider = MockProvider { chain_id: 1 };
        let request = TransactionRequest::new();
        let gas = provider.estimate_gas(&request).await.unwrap();
        assert_eq!(gas, 500_000);
    }

    #[tokio::test]
    async fn arc_provider_works() {
        let provider = std::sync::Arc::new(MockProvider { chain_id: 42 });
        assert_eq!(provider.chain_id(), 42);

        let balance = provider.get_balance(Address::ZERO).await.unwrap();
        assert_eq!(balance, U256::from(1_000_000_000_000_000_000u64));
    }
}
