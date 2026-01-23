//! Request and response types for MegaETH RPC methods.
//!
//! This module defines the data structures used for MegaETH-specific RPC calls:
//!
//! - [`LogsWithCursorFilter`] - Filter for cursor-based log queries
//! - [`LogsWithCursorResponse`] - Response from cursor-based queries
//! - [`FetchStats`] - Statistics from paginated fetch operations
//! - [`RealtimeResponse`] - Response from realtime transaction submission

use alloy::primitives::{Address, TxHash, B256};
use alloy::rpc::types::Log;
use serde::{Deserialize, Serialize};

// ═══════════════════════════════════════════════════════════════════════════════
// CURSOR-BASED LOG PAGINATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Filter parameters for `eth_getLogsWithCursor` - MegaETH's paginated log query API.
///
/// This extends the standard `eth_getLogs` filter with a cursor field for pagination.
/// When a query exceeds server-side resource caps, the server returns partial results
/// and a cursor that marks where it left off.
///
/// # Example
///
/// ```
/// use megaeth_rpc::types::LogsWithCursorFilter;
///
/// let filter = LogsWithCursorFilter {
///     from_block: "0x100".into(),
///     to_block: "0x200".into(),
///     address: None,
///     topics: None,
///     cursor: None,
/// };
/// ```
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LogsWithCursorFilter {
    /// Starting block (hex string like "0x100").
    pub from_block: String,

    /// Ending block (hex string like "0x200").
    pub to_block: String,

    /// Optional contract addresses to filter.
    /// When `None`, logs from all addresses are returned.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub address: Option<Vec<Address>>,

    /// Optional topics to filter.
    /// Each element is either a single topic or `None` for wildcard.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub topics: Option<Vec<Option<B256>>>,

    /// Cursor from previous response (for pagination).
    /// Pass `None` for the first request.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cursor: Option<String>,
}

impl LogsWithCursorFilter {
    /// Create a new filter for a block range.
    #[must_use]
    pub fn new(from_block: u64, to_block: u64) -> Self {
        Self {
            from_block: format!("0x{from_block:x}"),
            to_block: format!("0x{to_block:x}"),
            address: None,
            topics: None,
            cursor: None,
        }
    }

    /// Set the address filter.
    #[must_use]
    pub fn with_addresses(mut self, addresses: Vec<Address>) -> Self {
        self.address = Some(addresses);
        self
    }

    /// Set a single address filter.
    #[must_use]
    pub fn with_address(mut self, address: Address) -> Self {
        self.address = Some(vec![address]);
        self
    }

    /// Set the topics filter.
    #[must_use]
    pub fn with_topics(mut self, topics: Vec<Option<B256>>) -> Self {
        self.topics = Some(topics);
        self
    }

    /// Set the cursor for pagination.
    #[must_use]
    pub fn with_cursor(mut self, cursor: impl Into<String>) -> Self {
        self.cursor = Some(cursor.into());
        self
    }
}

/// Response from `eth_getLogsWithCursor` - MegaETH's paginated log query API.
///
/// When a query exceeds server-side resource caps, the server returns a partial
/// result and a cursor that marks where it left off.
///
/// # Fields
///
/// - `logs`: The logs returned in this batch
/// - `cursor`: If present, pass this to the next request to continue pagination.
///   When `None`, the query is complete.
#[derive(Debug, Clone, Deserialize)]
pub struct LogsWithCursorResponse {
    /// Logs returned in this batch.
    pub logs: Vec<Log>,

    /// Cursor for pagination (absent when query is complete).
    #[serde(default)]
    pub cursor: Option<String>,
}

/// Statistics from a cursor-based log fetch operation.
///
/// Returned alongside logs to provide visibility into the pagination process.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FetchStats {
    /// Total number of logs fetched across all batches.
    pub total_logs: usize,

    /// Number of batches/requests made.
    pub batches: usize,

    /// Whether the query completed (no more cursors).
    ///
    /// If `false`, the fetch was stopped early (e.g., due to batch limit).
    pub complete: bool,
}

impl Default for FetchStats {
    fn default() -> Self {
        Self {
            total_logs: 0,
            batches: 0,
            complete: true,
        }
    }
}

impl FetchStats {
    /// Create stats for a completed single-batch fetch.
    #[must_use]
    pub fn single_batch(log_count: usize) -> Self {
        Self {
            total_logs: log_count,
            batches: 1,
            complete: true,
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REALTIME API
// ═══════════════════════════════════════════════════════════════════════════════

/// Response from `realtime_sendRawTransaction` - MegaETH's instant receipt API.
///
/// Unlike standard `eth_sendRawTransaction` which returns only the tx hash,
/// MegaETH's realtime API returns the full receipt immediately after execution
/// (within ~10ms).
///
/// # Fields
///
/// This is a simplified view of the receipt focused on common use cases.
/// For full receipt details, use the alloy types directly.
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RealtimeResponse {
    /// Transaction hash.
    pub transaction_hash: TxHash,

    /// Block hash the transaction was included in.
    pub block_hash: B256,

    /// Block number the transaction was included in (hex string).
    pub block_number: String,

    /// Index of the transaction in the block.
    pub transaction_index: String,

    /// Address of the sender.
    pub from: Address,

    /// Address of the receiver (None for contract creation).
    pub to: Option<Address>,

    /// Gas used by this transaction.
    pub gas_used: String,

    /// Cumulative gas used in the block up to this transaction.
    pub cumulative_gas_used: String,

    /// Contract address created (if contract creation transaction).
    pub contract_address: Option<Address>,

    /// Status: "0x1" for success, "0x0" for failure.
    pub status: String,

    /// Logs emitted by this transaction.
    #[serde(default)]
    pub logs: Vec<Log>,
}

impl RealtimeResponse {
    /// Check if the transaction succeeded.
    #[must_use]
    pub fn is_success(&self) -> bool {
        self.status == "0x1"
    }

    /// Get the block number as u64.
    ///
    /// Returns `None` if parsing fails.
    #[must_use]
    pub fn block_number_u64(&self) -> Option<u64> {
        let stripped = self.block_number.strip_prefix("0x").unwrap_or(&self.block_number);
        u64::from_str_radix(stripped, 16).ok()
    }

    /// Get gas used as u64.
    ///
    /// Returns `None` if parsing fails.
    #[must_use]
    pub fn gas_used_u64(&self) -> Option<u64> {
        let stripped = self.gas_used.strip_prefix("0x").unwrap_or(&self.gas_used);
        u64::from_str_radix(stripped, 16).ok()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTERNAL TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// JSON-RPC request structure.
#[derive(Debug, Serialize)]
pub(crate) struct JsonRpcRequest<'a, P: Serialize> {
    pub jsonrpc: &'static str,
    pub method: &'a str,
    pub params: P,
    pub id: u64,
}

impl<'a, P: Serialize> JsonRpcRequest<'a, P> {
    pub fn new(method: &'a str, params: P, id: u64) -> Self {
        Self {
            jsonrpc: "2.0",
            method,
            params,
            id,
        }
    }
}

/// JSON-RPC response wrapper for extracting result or error.
#[derive(Debug, Deserialize)]
pub(crate) struct JsonRpcResponse<T> {
    #[allow(dead_code)]
    pub id: u64,
    pub result: Option<T>,
    pub error: Option<crate::error::RpcErrorDetail>,
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn filter_serialization_basic() {
        let filter = LogsWithCursorFilter::new(256, 512);
        let json = serde_json::to_string(&filter).expect("serialization failed");

        assert!(json.contains("\"fromBlock\":\"0x100\""));
        assert!(json.contains("\"toBlock\":\"0x200\""));
        assert!(!json.contains("address")); // Skipped when None
        assert!(!json.contains("cursor")); // Skipped when None
    }

    #[test]
    fn filter_serialization_with_cursor() {
        let filter = LogsWithCursorFilter::new(256, 512).with_cursor("0xabc123");

        let json = serde_json::to_string(&filter).expect("serialization failed");
        assert!(json.contains("\"cursor\":\"0xabc123\""));
    }

    #[test]
    fn filter_builder_pattern() {
        let addr = "0x1234567890123456789012345678901234567890"
            .parse::<Address>()
            .expect("valid address");

        let filter = LogsWithCursorFilter::new(100, 200)
            .with_address(addr)
            .with_cursor("cursor123");

        assert!(filter.address.is_some());
        assert_eq!(filter.address.as_ref().map(Vec::len), Some(1));
        assert_eq!(filter.cursor, Some("cursor123".to_string()));
    }

    #[test]
    fn response_deserialization_with_cursor() {
        let json = r#"{"logs": [], "cursor": "0xdef456"}"#;
        let response: LogsWithCursorResponse =
            serde_json::from_str(json).expect("deserialization failed");

        assert!(response.logs.is_empty());
        assert_eq!(response.cursor, Some("0xdef456".to_string()));
    }

    #[test]
    fn response_deserialization_without_cursor() {
        let json = r#"{"logs": []}"#;
        let response: LogsWithCursorResponse =
            serde_json::from_str(json).expect("deserialization failed");

        assert!(response.logs.is_empty());
        assert!(response.cursor.is_none());
    }

    #[test]
    fn fetch_stats_default() {
        let stats = FetchStats::default();
        assert_eq!(stats.total_logs, 0);
        assert_eq!(stats.batches, 0);
        assert!(stats.complete);
    }

    #[test]
    fn fetch_stats_single_batch() {
        let stats = FetchStats::single_batch(42);
        assert_eq!(stats.total_logs, 42);
        assert_eq!(stats.batches, 1);
        assert!(stats.complete);
    }

    #[test]
    fn realtime_response_success_check() {
        let json = r#"{
            "transactionHash": "0x1234567890123456789012345678901234567890123456789012345678901234",
            "blockHash": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
            "blockNumber": "0x100",
            "transactionIndex": "0x0",
            "from": "0x1234567890123456789012345678901234567890",
            "to": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
            "gasUsed": "0x5208",
            "cumulativeGasUsed": "0x5208",
            "contractAddress": null,
            "status": "0x1",
            "logs": []
        }"#;

        let response: RealtimeResponse = serde_json::from_str(json).expect("parse failed");
        assert!(response.is_success());
        assert_eq!(response.block_number_u64(), Some(256));
        assert_eq!(response.gas_used_u64(), Some(21000));
    }

    #[test]
    fn realtime_response_failure() {
        let json = r#"{
            "transactionHash": "0x1234567890123456789012345678901234567890123456789012345678901234",
            "blockHash": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
            "blockNumber": "0x100",
            "transactionIndex": "0x0",
            "from": "0x1234567890123456789012345678901234567890",
            "to": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
            "gasUsed": "0x5208",
            "cumulativeGasUsed": "0x5208",
            "contractAddress": null,
            "status": "0x0",
            "logs": []
        }"#;

        let response: RealtimeResponse = serde_json::from_str(json).expect("parse failed");
        assert!(!response.is_success());
    }
}
