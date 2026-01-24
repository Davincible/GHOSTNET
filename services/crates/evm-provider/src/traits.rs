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
pub trait ChainProvider: Send + Sync + std::fmt::Debug + 'static {
    /// Chain identifier (e.g., 1 for Ethereum mainnet, 6343 for MegaETH testnet).
    fn chain_id(&self) -> u64;

    /// Returns self as `Any` for downcasting.
    ///
    /// This allows converting `dyn ChainProvider` back to a concrete type when needed.
    ///
    /// # Example
    ///
    /// ```ignore
    /// if let Some(mock) = provider.as_any().downcast_ref::<MockProvider>() {
    ///     mock.set_balance(address, balance);
    /// }
    /// ```
    fn as_any(&self) -> &dyn std::any::Any;

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
        tracing::debug!(
            gas = 500_000,
            "Using default gas estimate - override estimate_gas() for accurate estimates"
        );
        Ok(500_000)
    }

    /// Get current gas price in wei.
    ///
    /// For EIP-1559 chains, this typically returns the suggested max fee.
    async fn gas_price(&self) -> Result<u128>;

    /// Get the current block number.
    ///
    /// Returns the number of the most recently mined block.
    async fn get_block_number(&self) -> Result<u64>;

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
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// - The token address is not a contract
    /// - The contract doesn't implement `balanceOf(address)`
    /// - The contract returns malformed data
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
        if result.is_empty() {
            return Err(ProviderError::InvalidResponse(format!(
                "balanceOf({account}) on {token} returned no data - \
                 contract may not exist or may not implement ERC20"
            )));
        }

        if result.len() < 32 {
            return Err(ProviderError::InvalidResponse(format!(
                "balanceOf({account}) on {token} returned {} bytes, expected 32 - \
                 contract may not be ERC20 compliant",
                result.len()
            )));
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

    /// Fetch the most recent logs for a contract, up to `limit`.
    ///
    /// This is a convenience method for the common use case of fetching recent
    /// activity. It works backwards from the latest block, fetching in chunks
    /// until `limit` logs are collected or block 0 is reached.
    ///
    /// # Arguments
    ///
    /// * `address` - Contract address to fetch logs for
    /// * `limit` - Maximum number of logs to return
    ///
    /// # Returns
    ///
    /// Logs in chronological order (oldest first), up to `limit` entries.
    ///
    /// # Example
    ///
    /// ```ignore
    /// // Get the last 1000 events from a contract
    /// let logs = provider.get_recent_logs(contract_address, 1000).await?;
    /// for log in logs {
    ///     println!("Event at block {}", log.block_number.unwrap_or_default());
    /// }
    /// ```
    async fn get_recent_logs(
        &self,
        address: Address,
        limit: usize,
    ) -> Result<Vec<alloy::rpc::types::Log>> {
        use alloy::rpc::types::Log;

        // Fetch in chunks, working backwards from latest block
        const CHUNK_SIZE: u64 = 50_000;

        if !self.supports_cursor_pagination() {
            return Err(ProviderError::unsupported("cursor pagination required for get_recent_logs"));
        }

        if limit == 0 {
            return Ok(Vec::new());
        }

        let latest_block = self.get_block_number().await?;

        let mut all_logs: Vec<Log> = Vec::new();
        let mut to_block = latest_block;

        while all_logs.len() < limit && to_block > 0 {
            let from_block = to_block.saturating_sub(CHUNK_SIZE);

            let filter = LogFilter::new(from_block, to_block).with_address(address);

            let page = self.get_logs_with_cursor(&filter, None).await?;
            all_logs.extend(page.logs);

            if from_block == 0 {
                break;
            }
            to_block = from_block.saturating_sub(1);
        }

        // Sort by block number (oldest first) and truncate to limit
        all_logs.sort_by_key(|log| log.block_number.unwrap_or_default());

        // Take the most recent `limit` logs
        if all_logs.len() > limit {
            // We want the LAST `limit` logs (most recent)
            all_logs = all_logs.split_off(all_logs.len() - limit);
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
    ///
    /// # Warning
    ///
    /// This is a synchronous method. Some implementations (like [`LocalNonceManager`](crate::LocalNonceManager))
    /// use blocking locks internally. If called from within an async runtime while
    /// another task holds the lock, it may deadlock. Use async alternatives when available.
    fn set(&self, address: Address, nonce: u64);

    /// Get the current nonce without incrementing.
    ///
    /// Useful for checking the current state without consuming a nonce.
    ///
    /// # Warning
    ///
    /// This is a synchronous method. Some implementations (like [`LocalNonceManager`](crate::LocalNonceManager))
    /// use blocking locks internally. If called from within an async runtime while
    /// another task holds the lock, it may deadlock. Use async alternatives when available.
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

    fn as_any(&self) -> &dyn std::any::Any {
        // For Arc<T>, we return self as Any
        // This allows checking if the Arc wraps a specific type
        self
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

    async fn get_block_number(&self) -> Result<u64> {
        (**self).get_block_number().await
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
    #[derive(Debug)]
    struct MockProvider {
        chain_id: u64,
    }

    #[async_trait]
    impl ChainProvider for MockProvider {
        fn chain_id(&self) -> u64 {
            self.chain_id
        }

        fn as_any(&self) -> &dyn std::any::Any {
            self
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

        async fn get_block_number(&self) -> Result<u64> {
            Ok(100)
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

    // ─────────────────────────────────────────────────────────────────────────────
    // get_token_balance tests
    // ─────────────────────────────────────────────────────────────────────────────

    /// Mock that captures the call request for verification
    #[derive(Debug)]
    struct CallCapturingProvider {
        last_call: std::sync::Mutex<Option<TransactionRequest>>,
        response: Bytes,
    }

    impl CallCapturingProvider {
        fn new(response: Bytes) -> Self {
            Self {
                last_call: std::sync::Mutex::new(None),
                response,
            }
        }

        fn empty_response() -> Self {
            Self::new(Bytes::new())
        }

        fn short_response() -> Self {
            Self::new(Bytes::from(vec![0u8; 16])) // Only 16 bytes
        }

        fn valid_response(value: U256) -> Self {
            Self::new(Bytes::from(value.to_be_bytes_vec()))
        }

        fn last_call(&self) -> Option<TransactionRequest> {
            self.last_call.lock().ok().and_then(|guard| guard.clone())
        }
    }

    #[async_trait]
    impl ChainProvider for CallCapturingProvider {
        fn chain_id(&self) -> u64 {
            1
        }

        fn as_any(&self) -> &dyn std::any::Any {
            self
        }

        async fn get_balance(&self, _: Address) -> Result<U256> {
            Ok(U256::ZERO)
        }

        async fn get_nonce(&self, _: Address) -> Result<u64> {
            Ok(0)
        }

        async fn send_raw_transaction(&self, _: Bytes) -> Result<TxHash> {
            Ok(TxHash::ZERO)
        }

        async fn wait_for_receipt(&self, hash: TxHash, _: Duration) -> Result<TransactionReceipt> {
            Ok(TransactionReceipt {
                tx_hash: hash,
                block_hash: alloy::primitives::B256::ZERO,
                block_number: 1,
                tx_index: 0,
                from: Address::ZERO,
                to: None,
                contract_address: None,
                gas_used: 21000,
                success: true,
                logs: vec![],
            })
        }

        async fn gas_price(&self) -> Result<u128> {
            Ok(1_000_000_000)
        }

        async fn get_block_number(&self) -> Result<u64> {
            Ok(1)
        }

        async fn call(&self, tx: &TransactionRequest) -> Result<Bytes> {
            if let Ok(mut guard) = self.last_call.lock() {
                *guard = Some(tx.clone());
            }
            Ok(self.response.clone())
        }
    }

    #[tokio::test]
    async fn get_token_balance_encodes_calldata_correctly() {
        let provider = CallCapturingProvider::valid_response(U256::from(1000));

        let token: Address = "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            .parse()
            .unwrap();
        let account: Address = "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
            .parse()
            .unwrap();

        let balance = provider.get_token_balance(token, account).await.unwrap();
        assert_eq!(balance, U256::from(1000));

        // Verify the call was made correctly
        let call = provider.last_call().expect("call should have been made");
        assert_eq!(call.to, Some(token));

        // Verify calldata: selector (4 bytes) + padded address (32 bytes)
        let data = call.data.expect("data should be set");
        assert_eq!(data.len(), 36); // 4 + 32

        // Check selector is balanceOf(address) = 0x70a08231
        assert_eq!(&data[0..4], &[0x70, 0xa0, 0x82, 0x31]);

        // Check address is properly padded (12 zero bytes + 20 address bytes)
        assert_eq!(&data[4..16], &[0u8; 12]); // padding
        assert_eq!(&data[16..36], account.as_slice()); // address
    }

    #[tokio::test]
    async fn get_token_balance_returns_error_on_empty_response() {
        let provider = CallCapturingProvider::empty_response();

        let token: Address = "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            .parse()
            .unwrap();
        let account: Address = "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
            .parse()
            .unwrap();

        let result = provider.get_token_balance(token, account).await;
        assert!(result.is_err());

        let err = result.unwrap_err();
        let msg = err.to_string();
        assert!(msg.contains("returned no data"), "error: {msg}");
        assert!(msg.contains("may not exist"), "error: {msg}");
    }

    #[tokio::test]
    async fn get_token_balance_returns_error_on_short_response() {
        let provider = CallCapturingProvider::short_response();

        let token: Address = "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            .parse()
            .unwrap();
        let account: Address = "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
            .parse()
            .unwrap();

        let result = provider.get_token_balance(token, account).await;
        assert!(result.is_err());

        let err = result.unwrap_err();
        let msg = err.to_string();
        assert!(msg.contains("16 bytes"), "error: {msg}");
        assert!(msg.contains("expected 32"), "error: {msg}");
    }
}
