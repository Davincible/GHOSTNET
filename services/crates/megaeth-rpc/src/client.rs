//! MegaETH RPC client with cursor-based pagination and realtime API support.
//!
//! This module provides [`MegaEthClient`], the main entry point for interacting
//! with MegaETH's extended JSON-RPC API.
//!
//! # Features
//!
//! - **Cursor-based pagination**: Efficiently fetch large log ranges with automatic
//!   pagination via `eth_getLogsWithCursor`
//! - **Realtime API**: Submit transactions and get receipts in ~10ms via
//!   `realtime_sendRawTransaction`
//! - **Graceful fallback**: Detect when extended methods aren't available
//!
//! # Example
//!
//! ```ignore
//! use megaeth_rpc::{MegaEthClient, ClientConfig};
//!
//! let client = MegaEthClient::new("https://carrot.megaeth.com/rpc")?;
//!
//! // Check if cursor pagination is supported
//! if client.supports_cursor_pagination().await {
//!     let (logs, stats) = client.get_logs_with_cursor(1000, 2000, None).await?;
//!     println!("Fetched {} logs in {} batches", stats.total_logs, stats.batches);
//! }
//!
//! // Send transaction with instant receipt
//! let receipt = client.send_realtime_transaction(signed_tx_bytes).await?;
//! println!("Tx confirmed in block {}", receipt.block_number);
//! ```

use std::sync::atomic::{AtomicU64, Ordering};

use alloy::primitives::{Address, Bytes};
use alloy::rpc::types::Log;
use tracing::{debug, info, instrument, warn};

use crate::config::ClientConfig;
use crate::error::{MegaEthError, Result};
use crate::types::{
    FetchStats, JsonRpcRequest, JsonRpcResponse, LogsWithCursorFilter, LogsWithCursorResponse,
    RealtimeResponse,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MEGAETH RPC CLIENT
// ═══════════════════════════════════════════════════════════════════════════════

/// MegaETH-specific RPC client with cursor-based pagination and realtime API support.
///
/// This client provides access to MegaETH's extended JSON-RPC API, including:
///
/// - **`eth_getLogsWithCursor`**: Paginated log queries for high-throughput chains
/// - **`realtime_sendRawTransaction`**: Instant receipts (~10ms confirmation)
///
/// # MegaETH Data Scale
///
/// MegaETH processes ~1000 TPS, generating a year of Ethereum data every 5 days.
/// Standard `eth_getLogs` will timeout on large ranges. The cursor-based API allows:
///
/// - Partial results when server limits are hit
/// - Resume from where query stopped
/// - No wasted computation on aborted queries
///
/// # Thread Safety
///
/// This client is `Send + Sync` and can be shared across tasks. The internal
/// `reqwest::Client` is designed for concurrent use.
///
/// # Example
///
/// ```ignore
/// use megaeth_rpc::MegaEthClient;
///
/// let client = MegaEthClient::new("https://carrot.megaeth.com/rpc")?;
///
/// // Fetch logs with automatic pagination
/// let (logs, stats) = client.get_logs_with_cursor(0, 1000, None).await?;
/// ```
#[derive(Debug)]
pub struct MegaEthClient {
    /// HTTP client for JSON-RPC requests.
    client: reqwest::Client,

    /// RPC endpoint URL.
    rpc_url: String,

    /// Request ID counter for JSON-RPC correlation.
    request_id: AtomicU64,

    /// Client configuration.
    config: ClientConfig,
}

impl MegaEthClient {
    /// Create a new MegaETH RPC client with default configuration.
    ///
    /// # Arguments
    ///
    /// * `rpc_url` - HTTP URL of the MegaETH RPC endpoint
    ///
    /// # Errors
    ///
    /// Returns an error if the HTTP client cannot be created.
    ///
    /// # Example
    ///
    /// ```ignore
    /// let client = MegaEthClient::new("https://carrot.megaeth.com/rpc")?;
    /// ```
    pub fn new(rpc_url: impl Into<String>) -> Result<Self> {
        Self::with_config(rpc_url, ClientConfig::default())
    }

    /// Create a new client with custom configuration.
    ///
    /// # Arguments
    ///
    /// * `rpc_url` - HTTP URL of the MegaETH RPC endpoint
    /// * `config` - Client configuration options
    ///
    /// # Errors
    ///
    /// Returns an error if the HTTP client cannot be created or if the
    /// configuration is invalid.
    ///
    /// # Example
    ///
    /// ```ignore
    /// use megaeth_rpc::{MegaEthClient, ClientConfig};
    /// use std::time::Duration;
    ///
    /// let config = ClientConfig::default()
    ///     .with_timeout(Duration::from_secs(60))
    ///     .with_max_cursor_batches(200);
    ///
    /// let client = MegaEthClient::with_config("https://carrot.megaeth.com/rpc", config)?;
    /// ```
    pub fn with_config(rpc_url: impl Into<String>, config: ClientConfig) -> Result<Self> {
        config.validate()?;

        let client = reqwest::Client::builder()
            .timeout(config.timeout)
            .build()
            .map_err(|e| MegaEthError::Connection(format!("Failed to create HTTP client: {e}")))?;

        Ok(Self {
            client,
            rpc_url: rpc_url.into(),
            request_id: AtomicU64::new(1),
            config,
        })
    }

    /// Get the RPC URL this client is connected to.
    #[must_use]
    pub fn rpc_url(&self) -> &str {
        &self.rpc_url
    }

    /// Get the current configuration.
    #[must_use]
    pub const fn config(&self) -> &ClientConfig {
        &self.config
    }

    /// Get the next request ID for JSON-RPC correlation.
    fn next_request_id(&self) -> u64 {
        self.request_id.fetch_add(1, Ordering::Relaxed)
    }

    // ───────────────────────────────────────────────────────────────────────────
    // CURSOR-BASED LOG PAGINATION
    // ───────────────────────────────────────────────────────────────────────────

    /// Check if `eth_getLogsWithCursor` is available on this endpoint.
    ///
    /// Makes a minimal request to verify the endpoint supports cursor-based
    /// pagination. Useful for deciding whether to use this client or fall
    /// back to standard `eth_getLogs`.
    ///
    /// # Returns
    ///
    /// `true` if the endpoint supports `eth_getLogsWithCursor`, `false` otherwise.
    ///
    /// # Example
    ///
    /// ```ignore
    /// if client.supports_cursor_pagination().await {
    ///     // Use cursor-based pagination
    /// } else {
    ///     // Fall back to standard eth_getLogs
    /// }
    /// ```
    #[instrument(skip(self))]
    pub async fn supports_cursor_pagination(&self) -> bool {
        // Try to fetch logs from block 0 to 0 (should return empty result quickly)
        let filter = LogsWithCursorFilter::new(0, 0);

        match self.get_logs_single_batch(&filter).await {
            Ok(_) => true,
            Err(e) if e.is_method_not_supported() => {
                debug!("eth_getLogsWithCursor not supported");
                false
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
    /// - [`MegaEthError::MethodNotSupported`] if the endpoint doesn't support cursor pagination
    /// - [`MegaEthError::CursorLimitExceeded`] if max batches reached before completion
    /// - [`MegaEthError::Timeout`] if request times out
    ///
    /// # Example
    ///
    /// ```ignore
    /// // Fetch all logs in range
    /// let (logs, stats) = client.get_logs_with_cursor(1000, 2000, None).await?;
    ///
    /// // Fetch logs for specific contract
    /// let contract = "0x...".parse()?;
    /// let (logs, stats) = client.get_logs_with_cursor(1000, 2000, Some(vec![contract])).await?;
    /// ```
    #[instrument(skip(self, addresses), fields(from_block, to_block, address_count = addresses.as_ref().map_or(0, Vec::len)))]
    pub async fn get_logs_with_cursor(
        &self,
        from_block: u64,
        to_block: u64,
        addresses: Option<Vec<Address>>,
    ) -> Result<(Vec<Log>, FetchStats)> {
        let mut filter = LogsWithCursorFilter::new(from_block, to_block);
        if let Some(addrs) = addresses {
            filter = filter.with_addresses(addrs);
        }

        let mut all_logs = Vec::new();
        let mut batches = 0usize;

        loop {
            batches += 1;

            if batches > self.config.max_cursor_batches {
                let total_logs = all_logs.len();
                warn!(
                    batches,
                    total_logs,
                    max = self.config.max_cursor_batches,
                    "Reached max cursor batches, stopping"
                );
                return Err(MegaEthError::CursorLimitExceeded {
                    batches,
                    max: self.config.max_cursor_batches,
                });
            }

            debug!(batch = batches, cursor = ?filter.cursor, "Fetching logs batch");

            let response = self.get_logs_single_batch(&filter).await?;

            debug!(
                batch = batches,
                logs_in_batch = response.logs.len(),
                has_cursor = response.cursor.is_some(),
                "Batch received"
            );

            all_logs.extend(response.logs);

            // Check log limit (0 means unlimited)
            if self.config.max_logs > 0 && all_logs.len() > self.config.max_logs {
                let collected = all_logs.len();
                warn!(
                    collected,
                    max = self.config.max_logs,
                    batches,
                    "Reached max logs limit, stopping"
                );
                return Err(MegaEthError::LogLimitExceeded {
                    collected,
                    max: self.config.max_logs,
                });
            }

            if let Some(cursor) = response.cursor {
                filter = filter.with_cursor(cursor);
            } else {
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

    /// Fetch logs for a specific contract with cursor-based pagination.
    ///
    /// Convenience method that wraps [`get_logs_with_cursor`](Self::get_logs_with_cursor)
    /// for a single contract.
    ///
    /// # Errors
    ///
    /// See [`get_logs_with_cursor`](Self::get_logs_with_cursor) for error conditions.
    ///
    /// # Example
    ///
    /// ```ignore
    /// let contract = "0x1234...".parse()?;
    /// let (logs, stats) = client.get_contract_logs(1000, 2000, contract).await?;
    /// ```
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

    /// Execute a single `eth_getLogsWithCursor` request.
    ///
    /// This is the low-level method that makes a single RPC call. For automatic
    /// pagination, use [`get_logs_with_cursor`](Self::get_logs_with_cursor).
    async fn get_logs_single_batch(&self, filter: &LogsWithCursorFilter) -> Result<LogsWithCursorResponse> {
        let request_id = self.next_request_id();
        let request = JsonRpcRequest::new("eth_getLogsWithCursor", [filter], request_id);

        let response: JsonRpcResponse<serde_json::Value> = self.send_request(&request).await?;

        // Check for error
        if let Some(error) = response.error {
            return Err(error.into_error("eth_getLogsWithCursor"));
        }

        let result = response
            .result
            .ok_or_else(|| MegaEthError::InvalidResponse("Missing result in RPC response".into()))?;

        // Handle both response formats:
        // 1. {logs: [...], cursor: "..."} - paginated format
        // 2. [...] - standard array format (fallback)
        if result.is_array() {
            // Standard eth_getLogs response format (no cursor support)
            warn!("Endpoint returned standard eth_getLogs format (no cursor). This endpoint may not fully support eth_getLogsWithCursor.");
            let logs: Vec<Log> = serde_json::from_value(result)?;
            Ok(LogsWithCursorResponse { logs, cursor: None })
        } else {
            // Paginated format with cursor
            let parsed: LogsWithCursorResponse = serde_json::from_value(result)?;
            Ok(parsed)
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    // REALTIME API
    // ───────────────────────────────────────────────────────────────────────────

    /// Check if `realtime_sendRawTransaction` is available on this endpoint.
    ///
    /// # Returns
    ///
    /// `true` if the endpoint supports realtime transaction submission.
    #[instrument(skip(self))]
    pub async fn supports_realtime_api(&self) -> bool {
        // We can't easily test this without a real transaction, so we'll
        // try a method probe. Send empty bytes which should fail with an
        // error different from "method not found" if supported.
        let request_id = self.next_request_id();
        let request = JsonRpcRequest::new("realtime_sendRawTransaction", ["0x"], request_id);

        match self
            .client
            .post(&self.rpc_url)
            .json(&request)
            .send()
            .await
        {
            Ok(response) => {
                if let Ok(body) = response.json::<serde_json::Value>().await {
                    if let Some(error) = body.get("error") {
                        let code = error.get("code").and_then(serde_json::Value::as_i64).unwrap_or(0);
                        // Method not found codes
                        if code == -32601 || code == -32600 {
                            debug!("realtime_sendRawTransaction not supported");
                            return false;
                        }
                    }
                    // Any other response (including errors for invalid tx) means the method exists
                    true
                } else {
                    false
                }
            }
            Err(e) => {
                warn!(error = %e, "Failed to check realtime API support");
                false
            }
        }
    }

    /// Send a raw transaction and get receipt immediately via MegaETH's realtime API.
    ///
    /// Unlike standard `eth_sendRawTransaction` which returns only the transaction
    /// hash, MegaETH's realtime API returns the full receipt immediately after
    /// execution (~10ms).
    ///
    /// # Arguments
    ///
    /// * `raw_tx` - RLP-encoded signed transaction bytes
    ///
    /// # Returns
    ///
    /// The transaction receipt with all logs.
    ///
    /// # Errors
    ///
    /// - [`MegaEthError::MethodNotSupported`] if realtime API not available
    /// - [`MegaEthError::Rpc`] if transaction fails validation or execution
    ///
    /// # Example
    ///
    /// ```ignore
    /// // Sign and encode transaction
    /// let signed_tx = wallet.sign_transaction(tx).await?;
    /// let raw_bytes = signed_tx.rlp_bytes();
    ///
    /// // Send and get receipt immediately
    /// let receipt = client.send_realtime_transaction(raw_bytes).await?;
    ///
    /// if receipt.is_success() {
    ///     println!("Tx confirmed in block {}", receipt.block_number);
    /// }
    /// ```
    #[instrument(skip(self, raw_tx), fields(tx_len = raw_tx.len()))]
    pub async fn send_realtime_transaction(&self, raw_tx: Bytes) -> Result<RealtimeResponse> {
        let request_id = self.next_request_id();
        let hex_tx = format!("0x{}", hex::encode(raw_tx.as_ref()));
        let request = JsonRpcRequest::new("realtime_sendRawTransaction", [&hex_tx], request_id);

        let response: JsonRpcResponse<RealtimeResponse> = self.send_request(&request).await?;

        if let Some(error) = response.error {
            return Err(error.into_error("realtime_sendRawTransaction"));
        }

        response
            .result
            .ok_or_else(|| MegaEthError::InvalidResponse("Missing result in realtime response".into()))
    }

    // ───────────────────────────────────────────────────────────────────────────
    // INTERNAL HELPERS
    // ───────────────────────────────────────────────────────────────────────────

    /// Send a JSON-RPC request and parse the response.
    async fn send_request<P, R>(&self, request: &JsonRpcRequest<'_, P>) -> Result<JsonRpcResponse<R>>
    where
        P: serde::Serialize + Sync,
        R: serde::de::DeserializeOwned,
    {
        let response = self
            .client
            .post(&self.rpc_url)
            .json(request)
            .send()
            .await?;

        let body: JsonRpcResponse<R> = response.json().await?;
        Ok(body)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::*;
    use wiremock::matchers::{body_partial_json, method, path};
    use wiremock::{Mock, MockServer, ResponseTemplate};

    #[tokio::test]
    async fn client_creation() {
        let client = MegaEthClient::new("https://example.com/rpc").expect("client creation failed");
        assert_eq!(client.rpc_url(), "https://example.com/rpc");
    }

    #[tokio::test]
    async fn client_with_custom_config() {
        let config = ClientConfig::default()
            .with_timeout(Duration::from_secs(60))
            .with_max_cursor_batches(200);

        let client =
            MegaEthClient::with_config("https://example.com/rpc", config).expect("client creation failed");

        assert_eq!(client.config().timeout, Duration::from_secs(60));
        assert_eq!(client.config().max_cursor_batches, 200);
    }

    #[tokio::test]
    async fn supports_cursor_pagination_true() {
        let mock_server = MockServer::start().await;

        Mock::given(method("POST"))
            .and(path("/"))
            .and(body_partial_json(serde_json::json!({
                "method": "eth_getLogsWithCursor"
            })))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                "jsonrpc": "2.0",
                "id": 1,
                "result": {"logs": [], "cursor": null}
            })))
            .mount(&mock_server)
            .await;

        let client = MegaEthClient::new(mock_server.uri()).expect("client creation failed");
        assert!(client.supports_cursor_pagination().await);
    }

    #[tokio::test]
    async fn supports_cursor_pagination_false() {
        let mock_server = MockServer::start().await;

        Mock::given(method("POST"))
            .and(path("/"))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                "jsonrpc": "2.0",
                "id": 1,
                "error": {"code": -32601, "message": "Method not found"}
            })))
            .mount(&mock_server)
            .await;

        let client = MegaEthClient::new(mock_server.uri()).expect("client creation failed");
        assert!(!client.supports_cursor_pagination().await);
    }

    #[tokio::test]
    async fn get_logs_with_cursor_single_batch() {
        let mock_server = MockServer::start().await;

        Mock::given(method("POST"))
            .and(path("/"))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                "jsonrpc": "2.0",
                "id": 1,
                "result": {"logs": [], "cursor": null}
            })))
            .mount(&mock_server)
            .await;

        let client = MegaEthClient::new(mock_server.uri()).expect("client creation failed");
        let (logs, stats) = client
            .get_logs_with_cursor(100, 200, None)
            .await
            .expect("fetch failed");

        assert!(logs.is_empty());
        assert_eq!(stats.batches, 1);
        assert!(stats.complete);
    }

    #[tokio::test]
    async fn get_logs_with_cursor_multi_batch() {
        use std::sync::atomic::{AtomicU32, Ordering};
        use std::sync::Arc;
        use wiremock::{Request, Respond};

        // Stateful responder that returns different responses based on request count
        struct PaginatedResponder {
            call_count: Arc<AtomicU32>,
        }

        impl Respond for PaginatedResponder {
            fn respond(&self, _request: &Request) -> ResponseTemplate {
                let count = self.call_count.fetch_add(1, Ordering::SeqCst);
                if count == 0 {
                    // First batch: return logs with cursor
                    ResponseTemplate::new(200).set_body_json(serde_json::json!({
                        "jsonrpc": "2.0",
                        "id": 1,
                        "result": {
                            "logs": [{
                                "address": "0x1234567890123456789012345678901234567890",
                                "topics": [],
                                "data": "0x",
                                "blockNumber": "0x100",
                                "transactionHash": "0x0000000000000000000000000000000000000000000000000000000000000001",
                                "transactionIndex": "0x0",
                                "blockHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
                                "logIndex": "0x0",
                                "removed": false
                            }],
                            "cursor": "cursor_for_next_batch"
                        }
                    }))
                } else {
                    // Second batch: return logs without cursor (complete)
                    ResponseTemplate::new(200).set_body_json(serde_json::json!({
                        "jsonrpc": "2.0",
                        "id": 2,
                        "result": {
                            "logs": [{
                                "address": "0x1234567890123456789012345678901234567890",
                                "topics": [],
                                "data": "0x",
                                "blockNumber": "0x101",
                                "transactionHash": "0x0000000000000000000000000000000000000000000000000000000000000002",
                                "transactionIndex": "0x0",
                                "blockHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
                                "logIndex": "0x0",
                                "removed": false
                            }],
                            "cursor": null
                        }
                    }))
                }
            }
        }

        let mock_server = MockServer::start().await;
        let call_count = Arc::new(AtomicU32::new(0));

        Mock::given(method("POST"))
            .and(path("/"))
            .respond_with(PaginatedResponder {
                call_count: call_count.clone(),
            })
            .mount(&mock_server)
            .await;

        let client = MegaEthClient::new(mock_server.uri()).expect("client creation failed");
        let (logs, stats) = client
            .get_logs_with_cursor(100, 200, None)
            .await
            .expect("fetch failed");

        // Verify multi-batch pagination worked
        assert_eq!(stats.batches, 2, "Expected 2 batches");
        assert!(stats.complete, "Expected complete fetch");
        assert_eq!(logs.len(), 2, "Expected 2 logs (1 from each batch)");
        assert_eq!(call_count.load(Ordering::SeqCst), 2, "Expected 2 RPC calls");
    }

    #[tokio::test]
    async fn get_logs_with_cursor_method_not_supported() {
        let mock_server = MockServer::start().await;

        Mock::given(method("POST"))
            .and(path("/"))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                "jsonrpc": "2.0",
                "id": 1,
                "error": {"code": -32601, "message": "Method not found"}
            })))
            .mount(&mock_server)
            .await;

        let client = MegaEthClient::new(mock_server.uri()).expect("client creation failed");
        let result = client.get_logs_with_cursor(100, 200, None).await;

        assert!(result.is_err());
        assert!(result.unwrap_err().is_method_not_supported());
    }

    #[tokio::test]
    async fn get_logs_handles_array_fallback() {
        let mock_server = MockServer::start().await;

        // Some endpoints return plain array instead of {logs, cursor} object
        Mock::given(method("POST"))
            .and(path("/"))
            .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
                "jsonrpc": "2.0",
                "id": 1,
                "result": []
            })))
            .mount(&mock_server)
            .await;

        let client = MegaEthClient::new(mock_server.uri()).expect("client creation failed");
        let (logs, stats) = client
            .get_logs_with_cursor(100, 200, None)
            .await
            .expect("fetch failed");

        assert!(logs.is_empty());
        assert!(stats.complete);
    }
}
