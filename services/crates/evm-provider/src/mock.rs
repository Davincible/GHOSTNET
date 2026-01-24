//! Mock provider for testing.
//!
//! This module provides a [`MockProvider`] that implements [`ChainProvider`]
//! for use in tests without needing a real blockchain connection.
//!
//! # Panics
//!
//! The mock provider methods will panic if internal locks are poisoned.
//! This should only happen if a test panics while holding a lock.

// Allow expect in this module since it's for testing only and we want to panic
// on poisoned locks (indicates a bug in tests).
#![allow(clippy::expect_used)]
#![allow(clippy::missing_panics_doc)]

use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::RwLock;
use std::time::Duration;

use alloy::primitives::{Address, Bytes, TxHash, U256};
use async_trait::async_trait;

use crate::error::Result;
use crate::traits::ChainProvider;
use crate::types::{TransactionReceipt, TransactionRequest};

// ═══════════════════════════════════════════════════════════════════════════════
// MOCK PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

/// Mock blockchain provider for testing.
///
/// This provider stores balances and nonces in memory, allowing tests to
/// simulate blockchain interactions without a real network.
///
/// # Example
///
/// ```
/// use evm_provider::mock::MockProvider;
/// use evm_provider::ChainProvider;
/// use alloy::primitives::{Address, U256};
///
/// #[tokio::main]
/// async fn main() {
///     let provider = MockProvider::new();
///     provider.set_balance(Address::ZERO, U256::from(1000));
///     
///     let balance = provider.get_balance(Address::ZERO).await.unwrap();
///     assert_eq!(balance, U256::from(1000));
/// }
/// ```
#[derive(Debug)]
pub struct MockProvider {
    /// Chain ID.
    chain_id: u64,

    /// Balances by address.
    balances: RwLock<HashMap<Address, U256>>,

    /// Nonces by address.
    nonces: RwLock<HashMap<Address, u64>>,

    /// Token balances by (token, account).
    token_balances: RwLock<HashMap<(Address, Address), U256>>,

    /// Gas price in wei.
    gas_price: AtomicU64,

    /// Transaction counter for generating hashes.
    tx_counter: AtomicU64,

    /// Call responses by (to, data selector).
    call_responses: RwLock<HashMap<(Address, [u8; 4]), Bytes>>,
}

impl Default for MockProvider {
    fn default() -> Self {
        Self::new()
    }
}

impl MockProvider {
    /// Create a new mock provider with default settings.
    #[must_use]
    pub fn new() -> Self {
        Self::with_chain_id(31337) // Default anvil chain ID
    }

    /// Create a new mock provider with a specific chain ID.
    #[must_use]
    pub fn with_chain_id(chain_id: u64) -> Self {
        Self {
            chain_id,
            balances: RwLock::new(HashMap::new()),
            nonces: RwLock::new(HashMap::new()),
            token_balances: RwLock::new(HashMap::new()),
            gas_price: AtomicU64::new(1_000_000_000), // 1 gwei
            tx_counter: AtomicU64::new(1),
            call_responses: RwLock::new(HashMap::new()),
        }
    }

    /// Set the native balance for an address.
    pub fn set_balance(&self, address: Address, balance: U256) {
        self.balances
            .write()
            .expect("lock poisoned")
            .insert(address, balance);
    }

    /// Set the nonce for an address.
    pub fn set_nonce(&self, address: Address, nonce: u64) {
        self.nonces
            .write()
            .expect("lock poisoned")
            .insert(address, nonce);
    }

    /// Set a token balance.
    pub fn set_token_balance(&self, token: Address, account: Address, balance: U256) {
        self.token_balances
            .write()
            .expect("lock poisoned")
            .insert((token, account), balance);
    }

    /// Set the gas price.
    pub fn set_gas_price(&self, price: u64) {
        self.gas_price.store(price, Ordering::Relaxed);
    }

    /// Register a response for a specific call.
    ///
    /// The response will be returned when `call()` is invoked with
    /// the matching `to` address and function selector (first 4 bytes of data).
    pub fn register_call_response(&self, to: Address, selector: [u8; 4], response: Bytes) {
        self.call_responses
            .write()
            .expect("lock poisoned")
            .insert((to, selector), response);
    }

    /// Generate a mock transaction hash.
    fn next_tx_hash(&self) -> TxHash {
        let counter = self.tx_counter.fetch_add(1, Ordering::Relaxed);
        let mut bytes = [0u8; 32];
        bytes[24..32].copy_from_slice(&counter.to_be_bytes());
        TxHash::from(bytes)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHAIN PROVIDER IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════

#[async_trait]
impl ChainProvider for MockProvider {
    fn chain_id(&self) -> u64 {
        self.chain_id
    }

    fn as_any(&self) -> &dyn std::any::Any {
        self
    }

    async fn get_balance(&self, address: Address) -> Result<U256> {
        Ok(self
            .balances
            .read()
            .expect("lock poisoned")
            .get(&address)
            .copied()
            .unwrap_or(U256::ZERO))
    }

    async fn get_token_balance(&self, token: Address, account: Address) -> Result<U256> {
        Ok(self
            .token_balances
            .read()
            .expect("lock poisoned")
            .get(&(token, account))
            .copied()
            .unwrap_or(U256::ZERO))
    }

    async fn get_nonce(&self, address: Address) -> Result<u64> {
        Ok(self
            .nonces
            .read()
            .expect("lock poisoned")
            .get(&address)
            .copied()
            .unwrap_or(0))
    }

    async fn get_pending_nonce(&self, address: Address) -> Result<u64> {
        // In mock, pending nonce is same as confirmed nonce
        self.get_nonce(address).await
    }

    async fn send_raw_transaction(&self, _tx: Bytes) -> Result<TxHash> {
        // Return a mock transaction hash
        Ok(self.next_tx_hash())
    }

    async fn get_block_number(&self) -> Result<u64> {
        Ok(12345) // Fixed mock block number
    }

    async fn wait_for_receipt(
        &self,
        tx_hash: TxHash,
        _timeout: Duration,
    ) -> Result<TransactionReceipt> {
        // Return a mock successful receipt
        Ok(TransactionReceipt {
            tx_hash,
            block_hash: alloy::primitives::B256::ZERO,
            block_number: 12345,
            tx_index: 0,
            from: Address::ZERO,
            to: None,
            contract_address: None,
            gas_used: 50000,
            success: true,
            logs: vec![],
        })
    }

    async fn estimate_gas(&self, _tx: &TransactionRequest) -> Result<u64> {
        // Return a reasonable default
        Ok(100_000)
    }

    async fn gas_price(&self) -> Result<u128> {
        Ok(u128::from(self.gas_price.load(Ordering::Relaxed)))
    }

    async fn call(&self, tx: &TransactionRequest) -> Result<Bytes> {
        // Check if we have a registered response
        if let (Some(to), Some(data)) = (&tx.to, &tx.data)
            && data.len() >= 4
        {
            let mut selector = [0u8; 4];
            selector.copy_from_slice(&data[..4]);

            if let Some(response) = self
                .call_responses
                .read()
                .expect("lock poisoned")
                .get(&(*to, selector))
            {
                return Ok(response.clone());
            }
        }

        // Default: return empty bytes
        Ok(Bytes::new())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn default_balance_is_zero() {
        let provider = MockProvider::new();
        let balance = provider.get_balance(Address::ZERO).await.unwrap();
        assert_eq!(balance, U256::ZERO);
    }

    #[tokio::test]
    async fn set_and_get_balance() {
        let provider = MockProvider::new();
        let addr = Address::repeat_byte(0x01);
        let amount = U256::from(1_000_000);

        provider.set_balance(addr, amount);
        let balance = provider.get_balance(addr).await.unwrap();

        assert_eq!(balance, amount);
    }

    #[tokio::test]
    async fn token_balances() {
        let provider = MockProvider::new();
        let token = Address::repeat_byte(0x01);
        let account = Address::repeat_byte(0x02);
        let amount = U256::from(500);

        provider.set_token_balance(token, account, amount);
        let balance = provider.get_token_balance(token, account).await.unwrap();

        assert_eq!(balance, amount);
    }

    #[tokio::test]
    async fn nonces() {
        let provider = MockProvider::new();
        let addr = Address::repeat_byte(0x01);

        // Default nonce is 0
        assert_eq!(provider.get_nonce(addr).await.unwrap(), 0);

        provider.set_nonce(addr, 42);
        assert_eq!(provider.get_nonce(addr).await.unwrap(), 42);
    }

    #[tokio::test]
    async fn send_transaction_returns_hash() {
        let provider = MockProvider::new();
        let tx = Bytes::from_static(b"fake transaction");

        let hash1 = provider.send_raw_transaction(tx.clone()).await.unwrap();
        let hash2 = provider.send_raw_transaction(tx).await.unwrap();

        // Each transaction gets a unique hash
        assert_ne!(hash1, hash2);
    }

    #[tokio::test]
    async fn wait_for_receipt_succeeds() {
        let provider = MockProvider::new();
        let tx_hash = TxHash::ZERO;

        let receipt = provider
            .wait_for_receipt(tx_hash, Duration::from_secs(1))
            .await
            .unwrap();

        assert!(receipt.success);
        assert_eq!(receipt.tx_hash, tx_hash);
    }

    #[tokio::test]
    async fn chain_id() {
        let provider = MockProvider::new();
        assert_eq!(provider.chain_id(), 31337);

        let custom = MockProvider::with_chain_id(6343);
        assert_eq!(custom.chain_id(), 6343);
    }

    #[tokio::test]
    async fn registered_call_response() {
        let provider = MockProvider::new();
        let contract = Address::repeat_byte(0x01);
        let selector = [0x12, 0x34, 0x56, 0x78];
        let response = Bytes::from_static(b"response data");

        provider.register_call_response(contract, selector, response.clone());

        let mut data = Vec::new();
        data.extend_from_slice(&selector);
        data.extend_from_slice(b"extra args");

        let tx = TransactionRequest::new()
            .with_to(contract)
            .with_data(Bytes::from(data));

        let result = provider.call(&tx).await.unwrap();
        assert_eq!(result, response);
    }
}
