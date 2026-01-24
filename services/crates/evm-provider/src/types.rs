//! Common types for EVM provider operations.
//!
//! This module defines chain-agnostic data structures for interacting with EVM chains:
//!
//! - [`TransactionRequest`] - Request to send a transaction
//! - [`TransactionReceipt`] - Receipt of a confirmed transaction
//! - [`LogFilter`] - Filter for querying logs
//! - [`LogsPage`] - Page of logs with optional cursor

use alloy::primitives::{Address, Bytes, TxHash, B256, U256};
use alloy::rpc::types::Log;
use serde::{Deserialize, Serialize};

// ═══════════════════════════════════════════════════════════════════════════════
// TRANSACTION TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// A request to send a transaction.
///
/// This is a chain-agnostic transaction request that can be used across different
/// provider implementations. The provider will fill in any missing fields
/// (gas price, gas limit, etc.) based on chain conditions.
///
/// # Example
///
/// ```
/// use evm_provider::TransactionRequest;
/// use alloy::primitives::{Address, Bytes, U256};
///
/// let request = TransactionRequest::new()
///     .to("0x1234567890123456789012345678901234567890".parse().unwrap())
///     .value(U256::from(1_000_000_000_000_000_000u64)) // 1 ETH
///     .data(Bytes::from(vec![0xab, 0xcd]));
/// ```
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct TransactionRequest {
    /// Sender address (filled by signer if not set).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub from: Option<Address>,

    /// Recipient address. `None` for contract creation.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub to: Option<Address>,

    /// Value to transfer in wei.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub value: Option<U256>,

    /// Transaction data (calldata for contract calls).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<Bytes>,

    /// Gas limit for the transaction.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gas_limit: Option<u64>,

    /// Gas price in wei (for legacy transactions).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gas_price: Option<u128>,

    /// Max fee per gas (for EIP-1559 transactions).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_fee_per_gas: Option<u128>,

    /// Max priority fee per gas (for EIP-1559 transactions).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_priority_fee_per_gas: Option<u128>,

    /// Nonce (filled by provider if not set).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub nonce: Option<u64>,

    /// Chain ID (filled by provider if not set).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub chain_id: Option<u64>,
}

impl TransactionRequest {
    /// Create a new empty transaction request.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Set the sender address.
    #[must_use]
    pub const fn from(mut self, from: Address) -> Self {
        self.from = Some(from);
        self
    }

    /// Set the recipient address.
    #[must_use]
    pub const fn to(mut self, to: Address) -> Self {
        self.to = Some(to);
        self
    }

    /// Set the value to transfer.
    #[must_use]
    pub const fn value(mut self, value: U256) -> Self {
        self.value = Some(value);
        self
    }

    /// Set the transaction data.
    #[must_use]
    pub fn data(mut self, data: Bytes) -> Self {
        self.data = Some(data);
        self
    }

    /// Set the recipient address (alias for `to`).
    #[must_use]
    pub const fn with_to(self, to: Address) -> Self {
        self.to(to)
    }

    /// Set the transaction data (alias for `data`).
    #[must_use]
    pub fn with_data(self, data: Bytes) -> Self {
        self.data(data)
    }

    /// Set the gas limit.
    #[must_use]
    pub const fn gas_limit(mut self, gas_limit: u64) -> Self {
        self.gas_limit = Some(gas_limit);
        self
    }

    /// Set the gas price (legacy transactions).
    #[must_use]
    pub const fn gas_price(mut self, gas_price: u128) -> Self {
        self.gas_price = Some(gas_price);
        self
    }

    /// Set the nonce.
    #[must_use]
    pub const fn nonce(mut self, nonce: u64) -> Self {
        self.nonce = Some(nonce);
        self
    }

    /// Set the chain ID.
    #[must_use]
    pub const fn chain_id(mut self, chain_id: u64) -> Self {
        self.chain_id = Some(chain_id);
        self
    }

    /// Check if this is a contract creation transaction.
    #[must_use]
    pub const fn is_contract_creation(&self) -> bool {
        self.to.is_none()
    }
}

/// Receipt of a confirmed transaction.
///
/// This is a simplified receipt focused on the most common use cases.
/// For full receipt details, use the underlying alloy types.
#[derive(Debug, Clone)]
pub struct TransactionReceipt {
    /// Transaction hash.
    pub tx_hash: TxHash,

    /// Block hash the transaction was included in.
    pub block_hash: B256,

    /// Block number the transaction was included in.
    pub block_number: u64,

    /// Index of the transaction in the block.
    pub tx_index: u64,

    /// Address of the sender.
    pub from: Address,

    /// Address of the receiver (None for contract creation).
    pub to: Option<Address>,

    /// Contract address created (if contract creation transaction).
    pub contract_address: Option<Address>,

    /// Gas used by this transaction.
    pub gas_used: u64,

    /// Whether the transaction succeeded.
    pub success: bool,

    /// Logs emitted by this transaction.
    pub logs: Vec<Log>,
}

impl TransactionReceipt {
    /// Check if the transaction succeeded.
    #[must_use]
    pub const fn is_success(&self) -> bool {
        self.success
    }

    /// Check if this transaction created a contract.
    #[must_use]
    pub const fn is_contract_creation(&self) -> bool {
        self.contract_address.is_some()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOG FILTER TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Filter parameters for querying logs.
///
/// This is a chain-agnostic filter that works with both standard `eth_getLogs`
/// and MegaETH's cursor-based `eth_getLogsWithCursor`.
#[derive(Debug, Clone, Default)]
pub struct LogFilter {
    /// Starting block (inclusive).
    pub from_block: Option<u64>,

    /// Ending block (inclusive).
    pub to_block: Option<u64>,

    /// Contract addresses to filter.
    /// When empty, logs from all addresses are returned.
    pub addresses: Vec<Address>,

    /// Topics to filter.
    /// Each element is either a single topic or `None` for wildcard.
    pub topics: Vec<Option<B256>>,
}

impl LogFilter {
    /// Create a new filter for a block range.
    #[must_use]
    pub const fn new(from_block: u64, to_block: u64) -> Self {
        Self {
            from_block: Some(from_block),
            to_block: Some(to_block),
            addresses: Vec::new(),
            topics: Vec::new(),
        }
    }

    /// Set a single address filter.
    #[must_use]
    pub fn with_address(mut self, address: Address) -> Self {
        self.addresses = vec![address];
        self
    }

    /// Set multiple address filters.
    #[must_use]
    pub fn with_addresses(mut self, addresses: Vec<Address>) -> Self {
        self.addresses = addresses;
        self
    }

    /// Add a topic filter at a specific position.
    ///
    /// Position 0 is the event signature, positions 1-3 are indexed parameters.
    #[must_use]
    pub fn with_topic(mut self, position: usize, topic: B256) -> Self {
        // Extend topics vector if needed
        while self.topics.len() <= position {
            self.topics.push(None);
        }
        self.topics[position] = Some(topic);
        self
    }

    /// Set the event signature (topic 0).
    #[must_use]
    pub fn with_event_signature(self, signature: B256) -> Self {
        self.with_topic(0, signature)
    }
}

/// A page of logs, potentially with a cursor for pagination.
///
/// Used for both standard and cursor-based log queries.
#[derive(Debug, Clone)]
pub struct LogsPage {
    /// Logs returned in this page.
    pub logs: Vec<Log>,

    /// Cursor for fetching the next page.
    /// `None` if this is the last page.
    pub cursor: Option<String>,

    /// Whether this is the complete result.
    pub complete: bool,
}

impl LogsPage {
    /// Create a complete page with no pagination.
    #[must_use]
    pub const fn complete(logs: Vec<Log>) -> Self {
        Self {
            logs,
            cursor: None,
            complete: true,
        }
    }

    /// Create a page with a cursor for continuation.
    #[must_use]
    pub const fn with_cursor(logs: Vec<Log>, cursor: String) -> Self {
        Self {
            logs,
            cursor: Some(cursor),
            complete: false,
        }
    }

    /// Check if there are more pages to fetch.
    #[must_use]
    pub const fn has_more(&self) -> bool {
        self.cursor.is_some()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn transaction_request_builder() {
        let to_addr: Address = "0x1234567890123456789012345678901234567890"
            .parse()
            .unwrap();

        let request = TransactionRequest::new()
            .to(to_addr)
            .value(U256::from(1000))
            .gas_limit(21000);

        assert_eq!(request.to, Some(to_addr));
        assert_eq!(request.value, Some(U256::from(1000)));
        assert_eq!(request.gas_limit, Some(21000));
        assert!(!request.is_contract_creation());
    }

    #[test]
    fn transaction_request_contract_creation() {
        let request = TransactionRequest::new()
            .data(Bytes::from(vec![0x60, 0x80, 0x60, 0x40]));

        assert!(request.is_contract_creation());
    }

    #[test]
    fn log_filter_builder() {
        let addr: Address = "0x1234567890123456789012345678901234567890"
            .parse()
            .unwrap();
        let topic = B256::repeat_byte(0xab);

        let filter = LogFilter::new(100, 200)
            .with_address(addr)
            .with_event_signature(topic);

        assert_eq!(filter.from_block, Some(100));
        assert_eq!(filter.to_block, Some(200));
        assert_eq!(filter.addresses.len(), 1);
        assert_eq!(filter.topics.len(), 1);
        assert_eq!(filter.topics[0], Some(topic));
    }

    #[test]
    fn logs_page_complete() {
        let page = LogsPage::complete(vec![]);
        assert!(page.complete);
        assert!(!page.has_more());
        assert!(page.cursor.is_none());
    }

    #[test]
    fn logs_page_with_cursor() {
        let page = LogsPage::with_cursor(vec![], "cursor123".to_string());
        assert!(!page.complete);
        assert!(page.has_more());
        assert_eq!(page.cursor, Some("cursor123".to_string()));
    }
}
