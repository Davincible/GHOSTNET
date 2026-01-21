//! MegaETH-specific RPC client for optimized blockchain access.
//!
//! This module provides access to MegaETH's extended JSON-RPC API, including
//! cursor-based log pagination (`eth_getLogsWithCursor`) which is critical for
//! efficient backfill operations on high-throughput chains.
//!
//! # MegaETH Data Scale
//!
//! MegaETH at 1000 TPS generates 1 year of Ethereum data every 5 days. Standard
//! `eth_getLogs` will timeout on large ranges. The cursor-based API allows:
//!
//! - Partial results when server limits are hit
//! - Resume from where query stopped
//! - No wasted computation on aborted queries
//!
//! # Usage
//!
//! ```ignore
//! use ghostnet_indexer::indexer::megaeth_rpc::MegaEthRpcClient;
//!
//! let client = MegaEthRpcClient::new("https://6343.rpc.thirdweb.com")?;
//!
//! // Fetch all logs with automatic pagination
//! let logs = client.get_logs_with_cursor(from_block, to_block, None).await?;
//! ```

use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use alloy::primitives::Address;
use alloy::rpc::types::Log;
use serde::{Deserialize, Serialize};
use tracing::{debug, info, instrument, warn};

use crate::error::{InfraError, Result};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Default timeout for HTTP requests to RPC endpoint.
const DEFAULT_REQUEST_TIMEOUT: Duration = Duration::from_secs(30);

/// Maximum batches to fetch in a single `get_logs_with_cursor` call.
/// Prevents runaway queries that could consume too much memory.
const MAX_CURSOR_BATCHES: usize = 100;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Response from `eth_getLogsWithCursor` - MegaETH's paginated log query API.
///
/// When a query exceeds server-side resource caps, the server returns a partial
/// result and a cursor that marks where it left off.
#[derive(Debug, Deserialize)]
pub struct LogsWithCursorResponse {
    /// Logs returned in this batch.
    pub logs: Vec<Log>,
    /// Cursor for pagination (absent when query is complete).
    #[serde(default)]
    pub cursor: Option<String>,
}

/// Filter params for `eth_getLogsWithCursor` - same as `eth_getLogs` plus cursor.
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LogsWithCursorFilter {
    /// Starting block (hex string like "0x100").
    pub from_block: String,
    /// Ending block (hex string like "0x200").
    pub to_block: String,
    /// Optional contract addresses to filter.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub address: Option<Vec<Address>>,
    /// Optional topics to filter.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub topics: Option<Vec<Option<String>>>,
    /// Cursor from previous response (for pagination).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cursor: Option<String>,
}

/// Statistics from a cursor-based log fetch operation.
#[derive(Debug, Clone)]
pub struct FetchStats {
    /// Total number of logs fetched.
    pub total_logs: usize,
    /// Number of batches/requests made.
    pub batches: usize,
    /// Whether the query completed (no more cursors).
    pub complete: bool,
}

/// Error details from a JSON-RPC error response.
#[derive(Debug, Deserialize)]
struct RpcErrorDetail {
    code: i64,
    message: String,
}

// ═══════════════════════════════════════════════════════════════════════════════
// MEGAETH RPC CLIENT
// ═══════════════════════════════════════════════════════════════════════════════

/// MegaETH-specific RPC client with cursor-based pagination support.
///
/// This client provides access to MegaETH's extended JSON-RPC API, including
/// the `eth_getLogsWithCursor` method for efficient log retrieval on
/// high-throughput chains.
///
/// # Features
///
/// - **Cursor-based pagination**: Automatically handles pagination for large
///   log ranges, resuming from where each batch left off.
/// - **Graceful fallback**: Detects when `eth_getLogsWithCursor` is unavailable
///   and returns appropriate errors for callers to handle.
/// - **Request ID tracking**: Each JSON-RPC request has a unique ID for
///   correlation in logs.
///
/// # Thread Safety
///
/// This client is `Send + Sync` and can be shared across tasks. The internal
/// `reqwest::Client` is designed for concurrent use.
#[derive(Debug)]
pub struct MegaEthRpcClient {
    /// HTTP client for JSON-RPC requests.
    client: reqwest::Client,
    /// RPC endpoint URL.
    rpc_url: String,
    /// Request ID counter for JSON-RPC correlation.
    request_id: AtomicU64,
}

impl MegaEthRpcClient {
    /// Create a new MegaETH RPC client.
    ///
    /// # Arguments
    ///
    /// * `rpc_url` - HTTP URL of the MegaETH RPC endpoint
    ///
    /// # Errors
    ///
    /// Returns an error if the HTTP client cannot be created.
    pub fn new(rpc_url: impl Into<String>) -> Result<Self> {
        let client = reqwest::Client::builder()
            .timeout(DEFAULT_REQUEST_TIMEOUT)
            .build()
            .map_err(|e| InfraError::Internal(format!("Failed to create HTTP client: {e}")))?;

        Ok(Self {
            client,
            rpc_url: rpc_url.into(),
            request_id: AtomicU64::new(1),
        })
    }

    /// Create a new client with custom timeout.
    ///
    /// # Arguments
    ///
    /// * `rpc_url` - HTTP URL of the MegaETH RPC endpoint
    /// * `timeout` - Request timeout duration
    ///
    /// # Errors
    ///
    /// Returns an error if the HTTP client cannot be created.
    pub fn with_timeout(rpc_url: impl Into<String>, timeout: Duration) -> Result<Self> {
        let client = reqwest::Client::builder()
            .timeout(timeout)
            .build()
            .map_err(|e| InfraError::Internal(format!("Failed to create HTTP client: {e}")))?;

        Ok(Self {
            client,
            rpc_url: rpc_url.into(),
            request_id: AtomicU64::new(1),
        })
    }

    /// Get the next request ID for JSON-RPC correlation.
    fn next_request_id(&self) -> u64 {
        self.request_id.fetch_add(1, Ordering::Relaxed)
    }

    /// Check if `eth_getLogsWithCursor` is available on this endpoint.
    ///
    /// Makes a minimal request to verify the endpoint supports cursor-based
    /// pagination. Useful for deciding whether to use this client or fall
    /// back to standard `eth_getLogs`.
    ///
    /// # Returns
    ///
    /// `true` if the endpoint supports `eth_getLogsWithCursor`, `false` otherwise.
    #[instrument(skip(self))]
    pub async fn supports_cursor_pagination(&self) -> bool {
        // Try to fetch logs from block 0 to 0 (should return empty result quickly)
        let filter = LogsWithCursorFilter {
            from_block: "0x0".to_string(),
            to_block: "0x0".to_string(),
            address: None,
            topics: None,
            cursor: None,
        };

        let request_id = self.next_request_id();
        let request = serde_json::json!({
            "jsonrpc": "2.0",
            "method": "eth_getLogsWithCursor",
            "params": [filter],
            "id": request_id
        });

        match self.client.post(&self.rpc_url).json(&request).send().await {
            Ok(response) => {
                if let Ok(body) = response.json::<serde_json::Value>().await {
                    // Check for error response
                    if let Some(error) = body.get("error") {
                        let code = error.get("code").and_then(|c| c.as_i64()).unwrap_or(0);
                        // -32601 = Method not found
                        // -32600 = Invalid request (Alchemy uses this for unsupported methods)
                        if code == -32601 || code == -32600 {
                            debug!("eth_getLogsWithCursor not supported (error code: {code})");
                            return false;
                        }
                    }
                    // Has result field = success
                    body.get("result").is_some()
                } else {
                    false
                }
            }
            Err(e) => {
                warn!(error = %e, "Failed to check cursor pagination support");
                false
            }
        }
    }

    /// Fetch logs with cursor-based pagination.
    ///
    /// This method automatically handles pagination, making multiple requests
    /// as needed to retrieve all logs in the specified range.
    ///
    /// # Arguments
    ///
    /// * `from_block` - Starting block number (inclusive)
    /// * `to_block` - Ending block number (inclusive)
    /// * `addresses` - Optional contract addresses to filter (None = all)
    ///
    /// # Returns
    ///
    /// A tuple of (logs, stats) where stats includes batch count and completion status.
    ///
    /// # Errors
    ///
    /// - Returns `InfraError::Rpc` if the method is not supported or RPC fails
    /// - Returns `InfraError::Timeout` if request times out
    #[instrument(skip(self, addresses), fields(from_block, to_block, address_count = addresses.as_ref().map_or(0, Vec::len)))]
    pub async fn get_logs_with_cursor(
        &self,
        from_block: u64,
        to_block: u64,
        addresses: Option<Vec<Address>>,
    ) -> Result<(Vec<Log>, FetchStats)> {
        let from_block_hex = format!("0x{from_block:x}");
        let to_block_hex = format!("0x{to_block:x}");

        let mut all_logs = Vec::new();
        let mut cursor: Option<String> = None;
        let mut batches = 0usize;

        loop {
            batches += 1;

            if batches > MAX_CURSOR_BATCHES {
                let total_logs = all_logs.len();
                warn!(
                    batches,
                    total_logs,
                    "Reached max cursor batches, stopping"
                );
                return Ok((
                    all_logs,
                    FetchStats {
                        total_logs,
                        batches,
                        complete: false,
                    },
                ));
            }

            let filter = LogsWithCursorFilter {
                from_block: from_block_hex.clone(),
                to_block: to_block_hex.clone(),
                address: addresses.clone(),
                topics: None,
                cursor: cursor.clone(),
            };

            let request_id = self.next_request_id();
            let request = serde_json::json!({
                "jsonrpc": "2.0",
                "method": "eth_getLogsWithCursor",
                "params": [filter],
                "id": request_id
            });

            debug!(
                batch = batches,
                cursor = ?cursor,
                request_id,
                "Fetching logs batch"
            );

            let response = self
                .client
                .post(&self.rpc_url)
                .json(&request)
                .send()
                .await
                .map_err(|e| {
                    if e.is_timeout() {
                        InfraError::Timeout(format!("RPC request timed out: {e}"))
                    } else {
                        InfraError::Rpc(Box::new(e))
                    }
                })?;

            let body: serde_json::Value =
                response.json().await.map_err(|e| InfraError::Rpc(Box::new(e)))?;

            // Check for RPC error
            if let Some(error) = body.get("error") {
                let error_detail: RpcErrorDetail =
                    serde_json::from_value(error.clone()).unwrap_or(RpcErrorDetail {
                        code: -1,
                        message: "Unknown error".to_string(),
                    });

                // Method not supported
                if error_detail.code == -32601 || error_detail.code == -32600 {
                    return Err(InfraError::Rpc(Box::new(std::io::Error::new(
                        std::io::ErrorKind::Unsupported,
                        format!(
                            "eth_getLogsWithCursor not supported: {}",
                            error_detail.message
                        ),
                    )))
                    .into());
                }

                return Err(InfraError::Rpc(Box::new(std::io::Error::new(
                    std::io::ErrorKind::Other,
                    format!(
                        "RPC error ({}): {}",
                        error_detail.code, error_detail.message
                    ),
                )))
                .into());
            }

            let result = body.get("result").ok_or_else(|| {
                InfraError::Rpc(Box::new(std::io::Error::new(
                    std::io::ErrorKind::InvalidData,
                    "Missing result in RPC response",
                )))
            })?;

            // Handle both response formats:
            // 1. {logs: [...], cursor: "..."} - paginated format
            // 2. [...] - standard array format (fallback)
            let (logs, next_cursor) = if result.is_array() {
                // Standard eth_getLogs response format (no cursor support)
                warn!("Endpoint returned standard eth_getLogs format (no cursor). This endpoint may not fully support eth_getLogsWithCursor.");
                let logs: Vec<Log> =
                    serde_json::from_value(result.clone()).map_err(InfraError::Serialization)?;
                (logs, None)
            } else {
                // Paginated format with cursor
                let parsed: LogsWithCursorResponse =
                    serde_json::from_value(result.clone()).map_err(InfraError::Serialization)?;
                (parsed.logs, parsed.cursor)
            };

            debug!(
                batch = batches,
                logs_in_batch = logs.len(),
                has_cursor = next_cursor.is_some(),
                "Batch received"
            );

            all_logs.extend(logs);

            match next_cursor {
                Some(c) => cursor = Some(c),
                None => {
                    // No more cursors - query complete
                    let total_logs = all_logs.len();
                    info!(total_logs, batches, "Cursor pagination complete");
                    return Ok((
                        all_logs,
                        FetchStats {
                            total_logs,
                            batches,
                            complete: true,
                        },
                    ));
                }
            }
        }
    }

    /// Fetch logs for a specific contract with cursor-based pagination.
    ///
    /// Convenience method that wraps `get_logs_with_cursor` for a single contract.
    #[instrument(skip(self), fields(from_block, to_block, contract = %contract))]
    pub async fn get_contract_logs(
        &self,
        from_block: u64,
        to_block: u64,
        contract: Address,
    ) -> Result<(Vec<Log>, FetchStats)> {
        self.get_logs_with_cursor(from_block, to_block, Some(vec![contract]))
            .await
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn filter_serialization() {
        let filter = LogsWithCursorFilter {
            from_block: "0x100".to_string(),
            to_block: "0x200".to_string(),
            address: None,
            topics: None,
            cursor: None,
        };

        let json = serde_json::to_string(&filter).expect("serialization failed");
        assert!(json.contains("fromBlock"));
        assert!(json.contains("0x100"));
        assert!(!json.contains("address")); // Should be skipped when None
        assert!(!json.contains("cursor")); // Should be skipped when None
    }

    #[test]
    fn filter_with_cursor_serialization() {
        let filter = LogsWithCursorFilter {
            from_block: "0x100".to_string(),
            to_block: "0x200".to_string(),
            address: None,
            topics: None,
            cursor: Some("0xabc123".to_string()),
        };

        let json = serde_json::to_string(&filter).expect("serialization failed");
        assert!(json.contains("cursor"));
        assert!(json.contains("0xabc123"));
    }

    #[test]
    fn response_deserialization() {
        let json = r#"{"logs": [], "cursor": "0xdef456"}"#;
        let response: LogsWithCursorResponse =
            serde_json::from_str(json).expect("deserialization failed");
        assert!(response.logs.is_empty());
        assert_eq!(response.cursor, Some("0xdef456".to_string()));
    }

    #[test]
    fn response_without_cursor() {
        let json = r#"{"logs": []}"#;
        let response: LogsWithCursorResponse =
            serde_json::from_str(json).expect("deserialization failed");
        assert!(response.logs.is_empty());
        assert!(response.cursor.is_none());
    }
}
