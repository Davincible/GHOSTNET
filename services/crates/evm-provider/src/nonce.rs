//! Thread-safe nonce management for high-throughput transaction sending.
//!
//! When sending many transactions quickly, querying the chain for each nonce
//! is too slow and can lead to nonce collisions. This module provides a
//! thread-safe nonce manager that tracks nonces locally.
//!
//! # Example
//!
//! ```ignore
//! use evm_provider::{ChainProvider, LocalNonceManager};
//!
//! let provider = // ... create provider
//! let nonce_manager = LocalNonceManager::new(provider);
//!
//! // Get nonce atomically
//! let nonce = nonce_manager.get_and_increment(address).await?;
//!
//! // Send transaction with this nonce...
//!
//! // If transaction fails, resync
//! nonce_manager.sync(address).await?;
//! ```

use std::collections::HashMap;
use std::sync::Arc;

use alloy::primitives::Address;
use async_trait::async_trait;
use tokio::sync::RwLock;
use tracing::{debug, warn};

use crate::error::Result;
use crate::traits::{ChainProvider, NonceManager};

// ═══════════════════════════════════════════════════════════════════════════════
// LOCAL NONCE MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

/// A thread-safe nonce manager backed by a chain provider.
///
/// This manager tracks nonces locally for fast, atomic access. It syncs with
/// the chain when:
///
/// - A new address is first used
/// - [`sync`](Self::sync) is explicitly called
///
/// # Thread Safety
///
/// All operations are thread-safe. Multiple tasks can call [`get_and_increment`]
/// concurrently and will receive unique nonces.
///
/// # Example
///
/// ```ignore
/// let manager = LocalNonceManager::new(provider);
///
/// // These can run concurrently
/// let nonce1 = manager.get_and_increment(addr).await?;
/// let nonce2 = manager.get_and_increment(addr).await?;
///
/// assert!(nonce1 != nonce2);
/// ```
#[derive(Debug)]
pub struct LocalNonceManager<P> {
    provider: Arc<P>,
    nonces: RwLock<HashMap<Address, u64>>,
}

impl<P: ChainProvider> LocalNonceManager<P> {
    /// Create a new nonce manager backed by the given provider.
    ///
    /// The manager starts with no cached nonces. They will be fetched from
    /// the chain on first use for each address.
    pub fn new(provider: P) -> Self {
        Self {
            provider: Arc::new(provider),
            nonces: RwLock::new(HashMap::new()),
        }
    }

    /// Create a new nonce manager from an Arc'd provider.
    ///
    /// Use this when you want to share the provider across multiple components.
    pub fn from_arc(provider: Arc<P>) -> Self {
        Self {
            provider,
            nonces: RwLock::new(HashMap::new()),
        }
    }

    /// Check if we have a cached nonce for the given address.
    pub async fn has_cached(&self, address: Address) -> bool {
        self.nonces.read().await.contains_key(&address)
    }

    /// Clear all cached nonces.
    ///
    /// Use this when you need to resync all addresses with the chain.
    pub async fn clear(&self) {
        self.nonces.write().await.clear();
        debug!("Cleared all cached nonces");
    }

    /// Get the number of addresses with cached nonces.
    pub async fn cached_count(&self) -> usize {
        self.nonces.read().await.len()
    }

    /// Async version of [`set`](NonceManager::set).
    ///
    /// Use this when calling from an async context.
    pub async fn set_async(&self, address: Address, nonce: u64) {
        let old = self.nonces.write().await.insert(address, nonce);
        debug!(
            %address,
            nonce,
            old_nonce = ?old,
            "Manually set nonce (async)"
        );
    }

    /// Async version of [`peek`](NonceManager::peek).
    ///
    /// Use this when calling from an async context.
    pub async fn peek_async(&self, address: Address) -> Option<u64> {
        let nonces = self.nonces.read().await;
        nonces.get(&address).copied()
    }

    /// Initialize nonce from chain if not cached, then return it without incrementing.
    async fn ensure_cached(&self, address: Address) -> Result<u64> {
        // Fast path: already cached
        {
            let nonces = self.nonces.read().await;
            if let Some(&nonce) = nonces.get(&address) {
                return Ok(nonce);
            }
        }

        // Slow path: fetch from chain
        let nonce = self.provider.get_pending_nonce(address).await?;
        debug!(%address, nonce, "Initialized nonce from chain");

        let mut nonces = self.nonces.write().await;
        // Double-check in case another task initialized while we were fetching
        Ok(*nonces.entry(address).or_insert(nonce))
    }
}

#[async_trait]
impl<P: ChainProvider> NonceManager for LocalNonceManager<P> {
    async fn get_and_increment(&self, address: Address) -> Result<u64> {
        // Ensure we have a cached nonce
        self.ensure_cached(address).await?;

        // Get and increment atomically
        let mut nonces = self.nonces.write().await;
        // SAFETY: ensure_cached guarantees the address exists
        let Some(nonce) = nonces.get_mut(&address) else {
            // This should never happen due to ensure_cached
            return Err(crate::error::ProviderError::Other(
                "nonce cache inconsistency".into(),
            ));
        };
        let current = *nonce;
        *nonce += 1;
        drop(nonces); // Release lock before logging

        debug!(%address, nonce = current, "Got nonce");
        Ok(current)
    }

    async fn sync(&self, address: Address) -> Result<()> {
        let chain_nonce = self.provider.get_pending_nonce(address).await?;
        let old_nonce = self.nonces.write().await.insert(address, chain_nonce);

        if let Some(old) = old_nonce
            && old != chain_nonce
        {
            warn!(
                %address,
                old_nonce = old,
                chain_nonce,
                "Nonce resync - local was different from chain"
            );
        }

        debug!(%address, nonce = chain_nonce, "Synced nonce from chain");
        Ok(())
    }

    fn set(&self, address: Address, nonce: u64) {
        // Use blocking lock since this is typically called in sync context
        // For async context, use set_async
        let old = self.nonces.blocking_write().insert(address, nonce);

        debug!(
            %address,
            nonce,
            old_nonce = ?old,
            "Manually set nonce"
        );
    }

    fn peek(&self, address: Address) -> Option<u64> {
        // Use blocking lock for sync access
        self.nonces.blocking_read().get(&address).copied()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;
    use crate::traits::ChainProvider;
    use crate::types::{TransactionReceipt, TransactionRequest};
    use alloy::primitives::{Bytes, TxHash, B256, U256};
    use std::sync::atomic::{AtomicU64, Ordering};
    use std::time::Duration;

    /// Mock provider that tracks nonce queries
    struct MockProvider {
        chain_nonce: AtomicU64,
        query_count: AtomicU64,
    }

    impl MockProvider {
        fn new(initial_nonce: u64) -> Self {
            Self {
                chain_nonce: AtomicU64::new(initial_nonce),
                query_count: AtomicU64::new(0),
            }
        }

        fn set_chain_nonce(&self, nonce: u64) {
            self.chain_nonce.store(nonce, Ordering::SeqCst);
        }

        fn query_count(&self) -> u64 {
            self.query_count.load(Ordering::SeqCst)
        }
    }

    #[async_trait]
    impl ChainProvider for MockProvider {
        fn chain_id(&self) -> u64 {
            1
        }

        async fn get_balance(&self, _address: Address) -> Result<U256> {
            Ok(U256::ZERO)
        }

        async fn get_nonce(&self, _address: Address) -> Result<u64> {
            self.query_count.fetch_add(1, Ordering::SeqCst);
            Ok(self.chain_nonce.load(Ordering::SeqCst))
        }

        async fn get_pending_nonce(&self, address: Address) -> Result<u64> {
            self.get_nonce(address).await
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
                block_hash: B256::ZERO,
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

        async fn call(&self, _tx: &TransactionRequest) -> Result<Bytes> {
            Ok(Bytes::new())
        }
    }

    #[tokio::test]
    async fn get_and_increment_fetches_on_first_use() {
        let provider = MockProvider::new(5);
        let manager = LocalNonceManager::new(provider);

        let addr = Address::repeat_byte(0x01);

        // First call should fetch from chain
        let nonce = manager.get_and_increment(addr).await.unwrap();
        assert_eq!(nonce, 5);
        assert_eq!(manager.provider.query_count(), 1);

        // Second call should use cached value
        let nonce = manager.get_and_increment(addr).await.unwrap();
        assert_eq!(nonce, 6);
        assert_eq!(manager.provider.query_count(), 1); // No additional query
    }

    #[tokio::test]
    async fn sync_updates_from_chain() {
        let provider = MockProvider::new(10);
        let manager = LocalNonceManager::new(provider);

        let addr = Address::repeat_byte(0x02);

        // Initialize
        let nonce = manager.get_and_increment(addr).await.unwrap();
        assert_eq!(nonce, 10);

        // Simulate chain state change (e.g., tx confirmed elsewhere)
        manager.provider.set_chain_nonce(15);

        // Sync should update
        manager.sync(addr).await.unwrap();

        // Next nonce should be from chain
        let nonce = manager.get_and_increment(addr).await.unwrap();
        assert_eq!(nonce, 15);
    }

    #[tokio::test]
    async fn set_overrides_cached_value() {
        let provider = MockProvider::new(0);
        let manager = LocalNonceManager::new(provider);

        let addr = Address::repeat_byte(0x03);

        // Initialize
        let _ = manager.get_and_increment(addr).await.unwrap();

        // Override (use async version in tests)
        manager.set_async(addr, 100).await;

        // Should use set value
        let nonce = manager.get_and_increment(addr).await.unwrap();
        assert_eq!(nonce, 100);
    }

    #[tokio::test]
    async fn peek_returns_cached_value() {
        let provider = MockProvider::new(42);
        let manager = LocalNonceManager::new(provider);

        let addr = Address::repeat_byte(0x04);

        // Before init (use async version in tests)
        assert!(manager.peek_async(addr).await.is_none());

        // Initialize
        let _ = manager.get_and_increment(addr).await.unwrap();

        // After init and increment
        assert_eq!(manager.peek_async(addr).await, Some(43));
    }

    #[tokio::test]
    async fn clear_removes_all_cached() {
        let provider = MockProvider::new(0);
        let manager = LocalNonceManager::new(provider);

        let addr1 = Address::repeat_byte(0x05);
        let addr2 = Address::repeat_byte(0x06);

        // Initialize both
        let _ = manager.get_and_increment(addr1).await.unwrap();
        let _ = manager.get_and_increment(addr2).await.unwrap();

        assert_eq!(manager.cached_count().await, 2);

        // Clear
        manager.clear().await;

        assert_eq!(manager.cached_count().await, 0);
        assert!(manager.peek_async(addr1).await.is_none());
        assert!(manager.peek_async(addr2).await.is_none());
    }

    #[tokio::test]
    async fn concurrent_get_and_increment() {
        let provider = MockProvider::new(0);
        let manager = Arc::new(LocalNonceManager::new(provider));

        let addr = Address::repeat_byte(0x07);

        // Spawn multiple tasks to get nonces concurrently
        let handles: Vec<_> = (0..10)
            .map(|_| {
                let manager = Arc::clone(&manager);
                tokio::spawn(async move { manager.get_and_increment(addr).await.unwrap() })
            })
            .collect();

        // Collect results
        let mut nonces = Vec::new();
        for handle in handles {
            nonces.push(handle.await.unwrap());
        }

        // All nonces should be unique
        nonces.sort();
        let expected: Vec<u64> = (0..10).collect();
        assert_eq!(nonces, expected);
    }
}
