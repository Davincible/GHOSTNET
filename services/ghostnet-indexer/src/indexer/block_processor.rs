//! Block processor for fetching and dispatching blockchain events.
//!
//! The block processor is responsible for:
//! - Fetching logs from the blockchain (HTTP polling or WebSocket subscription)
//! - Building event metadata from logs and blocks
//! - Dispatching logs to the event router for processing
//!
//! # Architecture
//!
//! ```text
//! ┌──────────────────────────────────────────────────────────────────────────┐
//! │                          BlockProcessor                                   │
//! │                                                                          │
//! │  ┌─────────────┐     ┌─────────────────┐     ┌────────────────────────┐ │
//! │  │   RPC       │────▶│  Fetch Logs     │────▶│  Build Metadata        │ │
//! │  │   Provider  │     │  (concurrent)   │     │  (block + log → meta)  │ │
//! │  └─────────────┘     └─────────────────┘     └───────────┬────────────┘ │
//! │                                                          │              │
//! │                                               ┌──────────▼──────────┐   │
//! │                                               │   Dispatch to       │   │
//! │                                               │   EventRouter       │   │
//! │                                               └─────────────────────┘   │
//! └──────────────────────────────────────────────────────────────────────────┘
//! ```
//!
//! # Backfill Modes
//!
//! - **Standard**: Uses `eth_getLogs` with batched block ranges (works everywhere)
//! - **MegaETH Optimized**: Uses `eth_getLogsWithCursor` for efficient pagination
//!   on high-throughput chains where standard queries would timeout
//!
//! # Real-time Modes
//!
//! - **HTTP Polling**: Used for backfill and when WebSocket is unavailable
//! - **WebSocket Subscription**: Real-time block streaming (Phase 4)

use std::sync::Arc;
use std::time::Duration;

use alloy::eips::BlockNumberOrTag;
use alloy::primitives::Address;
use alloy::providers::Provider;
use alloy::rpc::types::{Filter, Log};
use chrono::{DateTime, Utc};
use futures::future::join_all;
use tokio::sync::mpsc;
use tokio::time::sleep;
use tracing::{debug, error, info, instrument, warn};

use super::megaeth_rpc::MegaEthRpcClient;
use crate::config::ContractAddresses;
use crate::error::{InfraError, Result};
use crate::types::events::EventMetadata;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Maximum blocks to fetch in a single batch during backfill.
const BACKFILL_BATCH_SIZE: u64 = 100;

/// Default polling interval when no new blocks are found.
const DEFAULT_POLL_INTERVAL: Duration = Duration::from_secs(1);

// ═══════════════════════════════════════════════════════════════════════════════
// BLOCK PROCESSOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Block processor for real-time and historical event ingestion.
///
/// The processor fetches logs from specified contracts and dispatches them
/// to the event router for decoding and handling.
///
/// # Type Parameters
///
/// * `P` - The provider type (must implement `Provider`)
///
/// # Backfill Optimization
///
/// When a `MegaEthRpcClient` is configured via [`Self::with_megaeth_client`],
/// the processor uses cursor-based pagination (`eth_getLogsWithCursor`) for
/// efficient backfill on high-throughput chains. This is critical for MegaETH
/// where standard `eth_getLogs` would timeout on large ranges.
#[derive(Debug)]
pub struct BlockProcessor<P> {
    /// RPC provider for blockchain access (Alloy).
    provider: Arc<P>,
    /// Optional MegaETH-specific client for cursor-based pagination.
    megaeth_client: Option<Arc<MegaEthRpcClient>>,
    /// Parsed contract addresses to monitor.
    contract_addresses: Vec<Address>,
    /// Channel for sending logs to the event router.
    log_sender: mpsc::Sender<(Log, EventMetadata)>,
    /// Polling interval for HTTP mode.
    poll_interval: Duration,
}

impl<P> BlockProcessor<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Create a new block processor.
    ///
    /// # Arguments
    ///
    /// * `provider` - RPC provider for blockchain access
    /// * `contracts` - Contract addresses to monitor
    /// * `log_sender` - Channel for dispatching logs
    /// * `poll_interval` - Interval between polls (for HTTP mode)
    ///
    /// # Errors
    ///
    /// Returns an error if contract addresses cannot be parsed.
    pub fn new(
        provider: Arc<P>,
        contracts: &ContractAddresses,
        log_sender: mpsc::Sender<(Log, EventMetadata)>,
        poll_interval: Option<Duration>,
    ) -> Result<Self> {
        let contract_addresses = contracts
            .parse_all()
            .map_err(|e| InfraError::AddressParsing(format!("Invalid contract address: {e}")))?;

        Ok(Self {
            provider,
            megaeth_client: None,
            contract_addresses,
            log_sender,
            poll_interval: poll_interval.unwrap_or(DEFAULT_POLL_INTERVAL),
        })
    }

    /// Add a MegaETH-specific RPC client for cursor-based pagination.
    ///
    /// When configured, the processor will use `eth_getLogsWithCursor` for
    /// backfill operations, which is much more efficient for MegaETH's
    /// high-throughput environment.
    ///
    /// # Arguments
    ///
    /// * `client` - MegaETH RPC client instance
    #[must_use]
    pub fn with_megaeth_client(mut self, client: Arc<MegaEthRpcClient>) -> Self {
        self.megaeth_client = Some(client);
        self
    }

    /// Check if cursor-based pagination is available.
    ///
    /// Returns `true` if a MegaETH client is configured and the endpoint
    /// supports `eth_getLogsWithCursor`.
    pub async fn supports_cursor_backfill(&self) -> bool {
        if let Some(client) = &self.megaeth_client {
            client.supports_cursor_pagination().await
        } else {
            false
        }
    }

    /// Start polling for new blocks from a given starting block.
    ///
    /// This method polls the RPC endpoint at regular intervals, fetching logs
    /// for all monitored contracts. It tracks the last processed block and
    /// continues from there on each iteration.
    ///
    /// # Arguments
    ///
    /// * `start_block` - Block number to start polling from
    ///
    /// # Errors
    ///
    /// Returns an error if the RPC provider fails or the log channel is closed.
    #[instrument(skip(self), fields(start_block))]
    pub async fn start_polling(&self, start_block: u64) -> Result<()> {
        info!(start_block, "Starting block polling");

        let mut last_processed_block = start_block.saturating_sub(1);

        loop {
            // Get the latest block number
            let latest_block = self
                .provider
                .get_block_number()
                .await
                .map_err(|e| InfraError::Rpc(Box::new(e)))?;

            // Process any new blocks
            if latest_block > last_processed_block {
                let from_block = last_processed_block + 1;
                let to_block = latest_block;

                debug!(from_block, to_block, "Processing new blocks");

                match self.process_block_range(from_block, to_block).await {
                    Ok(log_count) => {
                        info!(
                            from_block,
                            to_block, log_count, "Processed blocks successfully"
                        );
                        last_processed_block = to_block;
                    }
                    Err(e) => {
                        error!(
                            from_block,
                            to_block,
                            error = ?e,
                            "Failed to process blocks, will retry"
                        );
                        // Don't update last_processed_block so we retry
                    }
                }
            } else {
                debug!(latest_block, "No new blocks, waiting");
            }

            sleep(self.poll_interval).await;
        }
    }

    /// Backfill historical blocks from `from_block` to `to_block`.
    ///
    /// Uses batched fetching for optimal throughput. Each batch processes
    /// up to `BACKFILL_BATCH_SIZE` blocks.
    ///
    /// If a MegaETH client is configured and supports cursor pagination,
    /// use [`Self::backfill_with_cursor`] instead for better efficiency.
    ///
    /// # Arguments
    ///
    /// * `from_block` - Starting block number (inclusive)
    /// * `to_block` - Ending block number (inclusive)
    ///
    /// # Errors
    ///
    /// Returns an error if RPC calls fail or the log channel is closed.
    #[instrument(skip(self))]
    pub async fn backfill(&self, from_block: u64, to_block: u64) -> Result<()> {
        info!(from_block, to_block, "Starting historical backfill");

        let total_blocks = to_block.saturating_sub(from_block) + 1;
        let mut processed_blocks = 0u64;
        let mut current = from_block;

        while current <= to_block {
            let batch_end = (current + BACKFILL_BATCH_SIZE - 1).min(to_block);

            let log_count = self.process_block_range(current, batch_end).await?;

            processed_blocks += batch_end - current + 1;
            // Precision loss is acceptable for progress percentage display
            #[allow(clippy::cast_precision_loss)]
            let progress = (processed_blocks as f64 / total_blocks as f64) * 100.0;

            info!(
                from = current,
                to = batch_end,
                log_count,
                progress = format!("{:.1}%", progress),
                "Processed backfill batch"
            );

            current = batch_end + 1;
        }

        info!(total_blocks, "Backfill complete");
        Ok(())
    }

    /// Backfill historical blocks using MegaETH's cursor-based pagination.
    ///
    /// This method is optimized for MegaETH's high-throughput environment where
    /// standard `eth_getLogs` would timeout on large ranges. It uses
    /// `eth_getLogsWithCursor` to efficiently paginate through results.
    ///
    /// # Arguments
    ///
    /// * `from_block` - Starting block number (inclusive)
    /// * `to_block` - Ending block number (inclusive)
    ///
    /// # Errors
    ///
    /// - Returns an error if no MegaETH client is configured
    /// - Returns an error if `eth_getLogsWithCursor` is not supported
    /// - Returns an error if RPC calls fail or the log channel is closed
    ///
    /// # Example
    ///
    /// ```ignore
    /// use ghostnet_indexer::indexer::{BlockProcessor, MegaEthRpcClient};
    ///
    /// let megaeth = MegaEthRpcClient::new("https://6343.rpc.thirdweb.com")?;
    /// let processor = BlockProcessor::new(provider, contracts, tx)?
    ///     .with_megaeth_client(Arc::new(megaeth));
    ///
    /// // Use cursor-based pagination for efficient backfill
    /// processor.backfill_with_cursor(1_000_000, 2_000_000).await?;
    /// ```
    #[instrument(skip(self))]
    pub async fn backfill_with_cursor(&self, from_block: u64, to_block: u64) -> Result<()> {
        let client = self.megaeth_client.as_ref().ok_or_else(|| {
            InfraError::Internal("MegaETH client not configured for cursor backfill".into())
        })?;

        info!(
            from_block,
            to_block,
            contracts = self.contract_addresses.len(),
            "Starting cursor-based backfill"
        );

        // Fetch logs using cursor pagination
        let (logs, stats) = client
            .get_logs_with_cursor(from_block, to_block, Some(self.contract_addresses.clone()))
            .await?;

        info!(
            total_logs = stats.total_logs,
            batches = stats.batches,
            complete = stats.complete,
            "Cursor fetch complete, processing logs"
        );

        // Sort logs by (block_number, log_index) for deterministic ordering
        let mut sorted_logs = logs;
        sorted_logs.sort_by_key(|log| (log.block_number, log.log_index));

        // Dispatch each log
        let mut dispatched = 0usize;
        for log in sorted_logs {
            self.dispatch_log(log).await?;
            dispatched += 1;

            if dispatched % 10_000 == 0 {
                debug!(dispatched, "Dispatched logs");
            }
        }

        info!(
            dispatched,
            from_block,
            to_block,
            batches = stats.batches,
            "Cursor-based backfill complete"
        );

        Ok(())
    }

    /// Backfill using the best available method.
    ///
    /// Automatically selects the optimal backfill strategy:
    /// 1. If MegaETH client is configured and supports cursor pagination,
    ///    uses [`Self::backfill_with_cursor`]
    /// 2. Otherwise, falls back to standard batched [`Self::backfill`]
    ///
    /// # Arguments
    ///
    /// * `from_block` - Starting block number (inclusive)
    /// * `to_block` - Ending block number (inclusive)
    ///
    /// # Errors
    ///
    /// Returns an error if RPC calls fail or the log channel is closed.
    #[instrument(skip(self))]
    pub async fn backfill_auto(&self, from_block: u64, to_block: u64) -> Result<()> {
        // Check if cursor-based backfill is available
        if self.supports_cursor_backfill().await {
            info!("Using cursor-based pagination for backfill");
            self.backfill_with_cursor(from_block, to_block).await
        } else {
            info!("Using standard batched backfill");
            self.backfill(from_block, to_block).await
        }
    }

    /// Process a range of blocks, fetching logs and dispatching them.
    ///
    /// Returns the number of logs processed.
    async fn process_block_range(&self, from_block: u64, to_block: u64) -> Result<usize> {
        // Fetch logs for all contracts concurrently
        let logs = self.fetch_logs_concurrent(from_block, to_block).await?;
        let log_count = logs.len();

        // Process each log
        for log in logs {
            self.dispatch_log(log).await?;
        }

        Ok(log_count)
    }

    /// Fetch logs for all contracts concurrently.
    ///
    /// This pattern provides significant performance gains by parallelizing
    /// RPC calls across contracts.
    async fn fetch_logs_concurrent(&self, from_block: u64, to_block: u64) -> Result<Vec<Log>> {
        // Build filters for each contract
        let filters: Vec<Filter> = self
            .contract_addresses
            .iter()
            .map(|contract| {
                Filter::new()
                    .address(*contract)
                    .from_block(from_block)
                    .to_block(to_block)
            })
            .collect();

        // Create futures for fetching logs
        let futures: Vec<_> = filters
            .iter()
            .map(|filter| self.provider.get_logs(filter))
            .collect();

        let results = join_all(futures).await;

        let mut all_logs = Vec::new();
        for result in results {
            match result {
                Ok(logs) => all_logs.extend(logs),
                Err(e) => {
                    warn!(error = ?e, "Failed to fetch logs for contract, continuing");
                    // Continue processing other contracts - don't fail entire batch
                }
            }
        }

        // Sort by (block_number, log_index) for deterministic ordering
        all_logs.sort_by_key(|log| (log.block_number, log.log_index));

        Ok(all_logs)
    }

    /// Dispatch a single log to the event router.
    async fn dispatch_log(&self, log: Log) -> Result<()> {
        // Build metadata for this log
        let meta = self.build_metadata(&log).await?;

        // Send to the event router
        self.log_sender
            .send((log, meta))
            .await
            .map_err(|e| InfraError::Internal(format!("Log channel closed: {e}")))?;

        Ok(())
    }

    /// Build event metadata from a log.
    ///
    /// Fetches the block to get the timestamp.
    async fn build_metadata(&self, log: &Log) -> Result<EventMetadata> {
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

        // Fetch block to get timestamp
        let block = self
            .provider
            .get_block_by_number(BlockNumberOrTag::Number(block_number))
            .await
            .map_err(|e| InfraError::Rpc(Box::new(e)))?
            .ok_or_else(|| InfraError::EventDecoding(format!("Block not found: {block_number}")))?;

        // Block timestamps are always within i64 range (Unix epoch won't overflow until year 292 billion)
        #[allow(clippy::cast_possible_wrap)]
        let timestamp = DateTime::<Utc>::from_timestamp(block.header.timestamp as i64, 0)
            .ok_or_else(|| {
                InfraError::EventDecoding(format!("Invalid timestamp: {}", block.header.timestamp))
            })?;

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

    /// Build a filter covering all indexed contracts for a block range.
    #[allow(dead_code)]
    fn build_filter(&self, from_block: u64, to_block: u64) -> Filter {
        Filter::new()
            .address(self.contract_addresses.clone())
            .from_block(from_block)
            .to_block(to_block)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn backfill_batch_size_is_reasonable() {
        // Ensure batch size is within reasonable bounds
        assert!(BACKFILL_BATCH_SIZE >= 10);
        assert!(BACKFILL_BATCH_SIZE <= 1000);
    }

    #[test]
    fn default_poll_interval_is_reasonable() {
        assert!(DEFAULT_POLL_INTERVAL >= Duration::from_millis(100));
        assert!(DEFAULT_POLL_INTERVAL <= Duration::from_secs(60));
    }
}
