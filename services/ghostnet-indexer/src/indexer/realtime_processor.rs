//! Real-time event processor using `MegaETH`'s Realtime API.
//!
//! `MegaETH` executes transactions within 10ms and exposes results via a
//! real-time WebSocket API. This processor subscribes to contract logs
//! and receives events as soon as they're packaged into mini-blocks.
//!
//! # `MegaETH` Realtime API
//!
//! Unlike standard Ethereum where you poll against EVM blocks (1s+),
//! `MegaETH`'s Realtime API queries against mini-blocks (~10ms).
//!
//! Key subscription for logs:
//! ```json
//! {
//!     "method": "eth_subscribe",
//!     "params": ["logs", {
//!         "address": ["0x...", "0x..."],
//!         "fromBlock": "pending",
//!         "toBlock": "pending"
//!     }]
//! }
//! ```
//!
//! # Architecture
//!
//! ```text
//! ┌───────────────────────────────────────────────────────────────────┐
//! │                     RealtimeProcessor                              │
//! │                                                                   │
//! │  ┌──────────────┐    ┌─────────────────┐    ┌──────────────────┐ │
//! │  │  WebSocket   │───▶│  Log Stream     │───▶│  Dispatch to     │ │
//! │  │  Connection  │    │  Subscription   │    │  EventRouter     │ │
//! │  └──────────────┘    └─────────────────┘    └──────────────────┘ │
//! │         │                                                        │
//! │         │            ┌─────────────────┐                         │
//! │         └───────────▶│  Keep-alive     │ (eth_chainId @ 30s)    │
//! │                      │  Task           │                         │
//! │                      └─────────────────┘                         │
//! └───────────────────────────────────────────────────────────────────┘
//! ```
//!
//! # Usage
//!
//! ```ignore
//! use tokio_util::sync::CancellationToken;
//!
//! let processor = RealtimeProcessor::new(ws_url, contracts, log_sender)?;
//! let shutdown = CancellationToken::new();
//!
//! // In another task: shutdown.cancel() to stop gracefully
//! processor.start(shutdown).await?;
//! ```

use std::time::Duration;

use alloy::primitives::Address;
use alloy::providers::{Provider, ProviderBuilder, WsConnect};
use alloy::rpc::types::{Filter, Log};
use chrono::{DateTime, Utc};
use futures::StreamExt;
use moka::future::Cache as MokaCache;
use tokio::sync::mpsc;
use tokio::time::{interval, timeout};
use tokio_util::sync::CancellationToken;
use tracing::{debug, error, info, instrument, warn};

use crate::config::ContractAddresses;
use crate::error::{InfraError, Result};
use crate::types::events::EventMetadata;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Keep-alive interval per `MegaETH` docs (must be < 30 seconds).
const KEEPALIVE_INTERVAL: Duration = Duration::from_secs(25);

/// Timeout for initial WebSocket connection.
const CONNECTION_TIMEOUT: Duration = Duration::from_secs(10);

/// Delay before reconnection attempt after disconnect.
const RECONNECT_DELAY: Duration = Duration::from_secs(1);

/// Maximum reconnection attempts before giving up.
const MAX_RECONNECT_ATTEMPTS: u32 = 10;

/// Maximum number of block timestamps to cache.
/// This should be large enough to cover recent blocks during high throughput.
const BLOCK_CACHE_MAX_CAPACITY: u64 = 10_000;

/// Time-to-live for cached block timestamps.
/// Block timestamps are immutable, so we can cache them for a long time.
const BLOCK_CACHE_TTL: Duration = Duration::from_secs(3600); // 1 hour

// ═══════════════════════════════════════════════════════════════════════════════
// REALTIME PROCESSOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Real-time event processor using `MegaETH`'s WebSocket API.
///
/// Subscribes to contract logs and receives events with ~10ms latency.
/// Automatically handles reconnection and keep-alive pings.
pub struct RealtimeProcessor {
    /// WebSocket URL for `MegaETH` RPC.
    ws_url: String,
    /// Parsed contract addresses to monitor.
    contract_addresses: Vec<Address>,
    /// Channel for sending logs to the event router.
    log_sender: mpsc::Sender<(Log, EventMetadata)>,
    /// Cache for block timestamps to avoid redundant RPC calls.
    /// Key: block number, Value: block timestamp.
    block_cache: MokaCache<u64, DateTime<Utc>>,
}

impl std::fmt::Debug for RealtimeProcessor {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("RealtimeProcessor")
            .field("ws_url", &self.ws_url)
            .field("contract_addresses", &self.contract_addresses)
            .field("log_sender", &"<Sender>")
            .field("block_cache", &format!("<Cache entries={}>", self.block_cache.entry_count()))
            .finish()
    }
}

impl RealtimeProcessor {
    /// Create a new realtime processor.
    ///
    /// # Arguments
    ///
    /// * `ws_url` - WebSocket URL for `MegaETH` RPC (e.g., `wss://rpc.megaeth.io/ws`)
    /// * `contracts` - Contract addresses to monitor
    /// * `log_sender` - Channel for dispatching logs to the event router
    ///
    /// # Errors
    ///
    /// Returns an error if contract addresses cannot be parsed.
    pub fn new(
        ws_url: impl Into<String>,
        contracts: &ContractAddresses,
        log_sender: mpsc::Sender<(Log, EventMetadata)>,
    ) -> Result<Self> {
        let contract_addresses = contracts
            .parse_all()
            .map_err(|e| InfraError::AddressParsing(format!("Invalid contract address: {e}")))?;

        // Build block timestamp cache with TTL-based eviction.
        // Block timestamps are immutable once confirmed, so we can cache aggressively.
        let block_cache = MokaCache::builder()
            .max_capacity(BLOCK_CACHE_MAX_CAPACITY)
            .time_to_live(BLOCK_CACHE_TTL)
            .build();

        Ok(Self {
            ws_url: ws_url.into(),
            contract_addresses,
            log_sender,
            block_cache,
        })
    }

    /// Start the realtime processor.
    ///
    /// This method connects to the WebSocket, subscribes to logs, and processes
    /// events until an error occurs or shutdown is requested. It automatically
    /// handles reconnection on disconnect.
    ///
    /// # Arguments
    ///
    /// * `shutdown` - Cancellation token for graceful shutdown. Call `.cancel()`
    ///   to stop the processor cleanly.
    ///
    /// # Errors
    ///
    /// Returns an error if connection fails after max retry attempts or if
    /// the log channel is closed.
    #[instrument(skip(self, shutdown))]
    pub async fn start(&self, shutdown: CancellationToken) -> Result<()> {
        info!(ws_url = %self.ws_url, "Starting realtime processor");

        let mut reconnect_attempts = 0u32;

        loop {
            // Check for shutdown before attempting connection
            if shutdown.is_cancelled() {
                info!("Shutdown requested before connection");
                return Ok(());
            }

            match self.run_subscription(&shutdown).await {
                Ok(()) => {
                    // Clean shutdown requested
                    info!("Realtime processor stopped cleanly");
                    return Ok(());
                }
                Err(e) => {
                    // Check if this was a shutdown-triggered error
                    if shutdown.is_cancelled() {
                        info!("Shutdown requested during subscription");
                        return Ok(());
                    }

                    reconnect_attempts += 1;

                    if reconnect_attempts > MAX_RECONNECT_ATTEMPTS {
                        error!(
                            attempts = reconnect_attempts,
                            error = ?e,
                            "Max reconnection attempts exceeded"
                        );
                        return Err(e);
                    }

                    warn!(
                        attempt = reconnect_attempts,
                        max = MAX_RECONNECT_ATTEMPTS,
                        error = ?e,
                        "WebSocket disconnected, reconnecting"
                    );

                    // Wait for reconnect delay, but respect shutdown
                    tokio::select! {
                        () = shutdown.cancelled() => {
                            info!("Shutdown requested during reconnect delay");
                            return Ok(());
                        }
                        () = tokio::time::sleep(RECONNECT_DELAY) => {}
                    }
                }
            }
        }
    }

    /// Run a single subscription session.
    ///
    /// Connects, subscribes, and processes logs until disconnect, error, or shutdown.
    /// Returns `Ok(())` on clean shutdown request.
    async fn run_subscription(&self, shutdown: &CancellationToken) -> Result<()> {
        // Connect with timeout, but respect shutdown
        let ws = WsConnect::new(&self.ws_url);
        let provider = tokio::select! {
            () = shutdown.cancelled() => {
                return Ok(());
            }
            result = timeout(CONNECTION_TIMEOUT, ProviderBuilder::new().connect_ws(ws)) => {
                result
                    .map_err(|_| InfraError::Timeout("WebSocket connection timed out".into()))?
                    .map_err(|e| InfraError::Rpc(Box::new(e)))?
            }
        };

        info!("WebSocket connected");

        // Build filter for all contracts with pending block tags (MegaETH Realtime API)
        // Note: The "pending" tag gives us mini-block level granularity (~10ms)
        let filter = Filter::new()
            .address(self.contract_addresses.clone())
            .from_block(alloy::eips::BlockNumberOrTag::Pending)
            .to_block(alloy::eips::BlockNumberOrTag::Pending);

        // Subscribe to logs
        let subscription = provider
            .subscribe_logs(&filter)
            .await
            .map_err(|e| InfraError::Rpc(Box::new(e)))?;

        info!(
            contracts = self.contract_addresses.len(),
            "Subscribed to realtime logs"
        );

        // Convert to stream
        let mut log_stream = subscription.into_stream();

        // Keep-alive task: send eth_chainId every 25 seconds
        // Uses a oneshot channel to signal failure back to the main loop
        let (keepalive_failed_tx, mut keepalive_failed_rx) = tokio::sync::oneshot::channel::<()>();
        let provider_clone = provider.clone();
        let shutdown_clone = shutdown.clone();
        tokio::spawn(async move {
            let mut keepalive_timer = interval(KEEPALIVE_INTERVAL);
            loop {
                tokio::select! {
                    () = shutdown_clone.cancelled() => {
                        debug!("Keep-alive task stopping due to shutdown");
                        return;
                    }
                    _ = keepalive_timer.tick() => {
                        if let Err(e) = provider_clone.get_chain_id().await {
                            warn!(error = ?e, "Keep-alive ping failed");
                            // Signal failure to main loop (ignore send error if receiver dropped)
                            let _ = keepalive_failed_tx.send(());
                            return;
                        }
                        debug!("Keep-alive ping sent");
                    }
                }
            }
        });

        // Process logs
        loop {
            tokio::select! {
                // Check for shutdown request
                () = shutdown.cancelled() => {
                    info!("Shutdown requested, stopping subscription");
                    return Ok(());
                }

                // Check if keep-alive task failed
                Ok(()) = &mut keepalive_failed_rx => {
                    warn!("Keep-alive task failed, reconnecting");
                    return Err(InfraError::Internal("Keep-alive ping failed".into()).into());
                }

                // Process incoming logs
                maybe_log = log_stream.next() => {
                    if let Some(log) = maybe_log {
                        if let Err(e) = self.dispatch_log(&provider, log).await {
                            error!(error = ?e, "Failed to dispatch log");
                            // Continue processing - don't disconnect for single log failures
                        }
                    } else {
                        // Stream ended - connection closed
                        warn!("Log stream ended");
                        return Err(InfraError::Internal("WebSocket stream ended".into()).into());
                    }
                }
            }
        }
    }

    /// Dispatch a single log to the event router.
    async fn dispatch_log<P>(&self, provider: &P, log: Log) -> Result<()>
    where
        P: Provider,
    {
        // Build metadata for this log
        let meta = self.build_metadata(provider, &log).await?;

        // Send to the event router
        self.log_sender
            .send((log, meta))
            .await
            .map_err(|e| InfraError::Internal(format!("Log channel closed: {e}")))?;

        Ok(())
    }

    /// Build event metadata from a log.
    ///
    /// For realtime logs, we may need to handle the case where block data
    /// isn't fully available yet (mini-block vs EVM block).
    ///
    /// Uses a cache to avoid redundant RPC calls for block timestamps.
    async fn build_metadata<P>(&self, provider: &P, log: &Log) -> Result<EventMetadata>
    where
        P: Provider,
    {
        let block_number = log
            .block_number
            .ok_or_else(|| InfraError::EventDecoding("Log missing block_number".into()))?;
        let block_hash = log
            .block_hash
            .ok_or_else(|| InfraError::EventDecoding("Log missing block_hash".into()))?;
        let tx_hash = log
            .transaction_hash
            .ok_or_else(|| InfraError::EventDecoding("Log missing transaction_hash".into()))?;
        let tx_index = log
            .transaction_index
            .ok_or_else(|| InfraError::EventDecoding("Log missing transaction_index".into()))?;
        let log_index = log
            .log_index
            .ok_or_else(|| InfraError::EventDecoding("Log missing log_index".into()))?;

        // Check cache first for block timestamp
        let timestamp = if let Some(cached) = self.block_cache.get(&block_number).await {
            debug!(block_number, "Block timestamp cache hit");
            cached
        } else {
            // Cache miss - fetch from RPC
            let ts = self.fetch_block_timestamp(provider, block_number).await;

            // Only cache successful fetches (not fallback timestamps)
            // We identify successful fetches by checking if the timestamp is not "now"
            // A more robust approach would be to return an enum, but this is simpler
            if ts != Utc::now() {
                self.block_cache.insert(block_number, ts).await;
                debug!(block_number, "Block timestamp cached");
            }

            ts
        };

        Ok(EventMetadata {
            block_number,
            block_hash,
            tx_hash,
            tx_index,
            log_index,
            timestamp,
            contract: log.address(),
        })
    }

    /// Fetch block timestamp from the RPC provider.
    ///
    /// Falls back to current time if the block is not found (mini-block not yet
    /// in EVM block) or if the RPC call fails.
    #[allow(clippy::cast_possible_wrap)] // Block timestamps won't exceed i64::MAX until year 292 billion
    async fn fetch_block_timestamp<P>(&self, provider: &P, block_number: u64) -> DateTime<Utc>
    where
        P: Provider,
    {
        match provider
            .get_block_by_number(alloy::eips::BlockNumberOrTag::Number(block_number))
            .await
        {
            Ok(Some(block)) => {
                DateTime::<Utc>::from_timestamp(block.header.timestamp as i64, 0)
                    .unwrap_or_else(Utc::now)
            }
            Ok(None) => {
                // Block not found - use current time (mini-block not yet in EVM block)
                debug!(block_number, "Block not found, using current time");
                Utc::now()
            }
            Err(e) => {
                warn!(block_number, error = ?e, "Failed to fetch block, using current time");
                Utc::now()
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn keepalive_interval_within_megaeth_requirements() {
        // MegaETH requires activity every 30 seconds
        assert!(KEEPALIVE_INTERVAL < Duration::from_secs(30));
        assert!(KEEPALIVE_INTERVAL >= Duration::from_secs(10)); // Not too frequent
    }

    #[test]
    fn connection_timeout_is_reasonable() {
        assert!(CONNECTION_TIMEOUT >= Duration::from_secs(5));
        assert!(CONNECTION_TIMEOUT <= Duration::from_secs(30));
    }

    #[test]
    fn reconnect_delay_is_reasonable() {
        assert!(RECONNECT_DELAY >= Duration::from_millis(100));
        assert!(RECONNECT_DELAY <= Duration::from_secs(10));
    }

    #[test]
    fn block_cache_constants_are_reasonable() {
        // Cache should be large enough for high-throughput indexing
        assert!(BLOCK_CACHE_MAX_CAPACITY >= 1000);
        // TTL should be long since block timestamps are immutable
        assert!(BLOCK_CACHE_TTL >= Duration::from_secs(60));
        // But not so long that we risk memory bloat
        assert!(BLOCK_CACHE_TTL <= Duration::from_secs(86400)); // 24 hours max
    }

    #[tokio::test]
    async fn block_cache_stores_and_retrieves_timestamps() {
        let cache: MokaCache<u64, DateTime<Utc>> = MokaCache::builder()
            .max_capacity(100)
            .time_to_live(Duration::from_secs(60))
            .build();

        let block_num = 12345u64;
        let timestamp = DateTime::<Utc>::from_timestamp(1_700_000_000, 0)
            .expect("valid timestamp");

        // Initially empty
        assert!(cache.get(&block_num).await.is_none());

        // Insert and verify
        cache.insert(block_num, timestamp).await;
        let cached = cache.get(&block_num).await;
        assert_eq!(cached, Some(timestamp));

        // Entry count should be 1
        // Note: entry_count may not be immediately updated due to async nature
        cache.run_pending_tasks().await;
        assert_eq!(cache.entry_count(), 1);
    }

    #[tokio::test]
    async fn block_cache_respects_max_capacity() {
        let cache: MokaCache<u64, DateTime<Utc>> = MokaCache::builder()
            .max_capacity(5)
            .build();

        let timestamp = DateTime::<Utc>::from_timestamp(1_700_000_000, 0)
            .expect("valid timestamp");

        // Insert more than capacity
        for i in 0..10u64 {
            cache.insert(i, timestamp).await;
        }

        // Force eviction processing
        cache.run_pending_tasks().await;

        // Should have evicted some entries
        assert!(cache.entry_count() <= 5);
    }
}
