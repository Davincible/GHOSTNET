//! Live network integration test for MegaETH testnet.
//!
//! This test validates the indexer's ability to:
//! 1. Connect to MegaETH testnet (RPC and WebSocket)
//! 2. Fetch real blocks and logs from the network
//! 3. Store indexed data in TimescaleDB
//!
//! # MegaETH Realtime API
//!
//! MegaETH executes transactions within 10ms and exposes results via a Realtime API.
//! Key features used in these tests:
//! - **HTTP RPC**: Standard Ethereum JSON-RPC, queries against latest mini block
//! - **WebSocket subscriptions**: `logs` with `fromBlock/toBlock: "pending"` for real-time streaming
//! - **Mini blocks**: ~10ms preconfirmed blocks (vs 1s EVM blocks)
//!
//! See `docs/MegaETH_RealtimeAPI.md` for full documentation.
//!
//! # Running the Tests
//!
//! ```bash
//! # Set your Alchemy API key for reliable HTTP RPC access
//! export ALCHEMY_API_KEY=your_key_here
//!
//! # Run all live network tests (requires Docker + Internet)
//! cargo test --test live_network_test --features test-utils -- --ignored --nocapture
//!
//! # Run just connectivity tests (no Docker needed)
//! cargo test --test live_network_test test_megaeth_http --features test-utils -- --ignored --nocapture
//! ```
//!
//! # Requirements
//!
//! - `ALCHEMY_API_KEY` environment variable (recommended for HTTP, falls back to public RPC)
//! - Docker daemon running (for TimescaleDB tests)
//! - Internet connection (for MegaETH testnet RPC)
//!
//! # Note
//!
//! - HTTP tests use Alchemy (most reliable) with fallback to thirdweb
//! - WebSocket tests use public endpoint (Alchemy doesn't support eth_subscribe)
//! - Tests are ignored by default as they require network access and take 30+ seconds

mod common;

use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use alloy::eips::BlockNumberOrTag;
use alloy::providers::{Provider, ProviderBuilder, WsConnect};
use alloy::rpc::types::Filter;
use chrono::Utc;
use futures::StreamExt;
use rustls::crypto::ring as rustls_ring;
use tokio::time::{sleep, timeout};
use tracing::{debug, info, warn};

use common::fixtures::TestDb;

/// Install the rustls crypto provider (required for WebSocket TLS connections).
fn install_crypto_provider() {
    // Try to install, ignore if already installed
    let _ = rustls_ring::default_provider().install_default();
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Alchemy RPC base URL (requires ALCHEMY_API_KEY env var)
const ALCHEMY_HTTP_BASE: &str = "https://megaeth-testnet.g.alchemy.com/v2/";

/// Fallback HTTP RPC via thirdweb (rate limited but works without API key)
const FALLBACK_HTTP_RPC: &str = "https://6343.rpc.thirdweb.com";

/// WebSocket RPC via MegaETH public endpoint
/// Note: Alchemy doesn't support eth_subscribe for MegaETH, so we use public endpoint
/// This endpoint may be unstable - WebSocket tests may fail during testnet maintenance
const PUBLIC_WS_RPC: &str = "wss://carrot.megaeth.com/ws";

/// MegaETH testnet chain ID
const MEGAETH_CHAIN_ID: u64 = 6343;

/// How long to run the live indexing test
const TEST_DURATION: Duration = Duration::from_secs(30);

/// Timeout for initial connection (increased for potentially slow testnet)
const CONNECTION_TIMEOUT: Duration = Duration::from_secs(30);

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Get the HTTP RPC URL, preferring Alchemy if API key is set.
fn get_http_rpc_url() -> String {
    match std::env::var("ALCHEMY_API_KEY") {
        Ok(key) if !key.is_empty() => {
            info!("Using Alchemy RPC (ALCHEMY_API_KEY set)");
            format!("{}{}", ALCHEMY_HTTP_BASE, key)
        }
        _ => {
            info!("Using fallback RPC (ALCHEMY_API_KEY not set)");
            FALLBACK_HTTP_RPC.to_string()
        }
    }
}

/// Get the WebSocket RPC URL.
///
/// Note: Alchemy doesn't support eth_subscribe for MegaETH, so we always use
/// the public endpoint for WebSocket connections. This endpoint may be unstable.
fn get_ws_rpc_url() -> String {
    // Alchemy doesn't support WebSocket subscriptions for MegaETH
    // Always use the public endpoint (may be unstable during testnet maintenance)
    info!("Using public WebSocket endpoint (Alchemy doesn't support eth_subscribe)");
    PUBLIC_WS_RPC.to_string()
}

/// Create an HTTP provider for MegaETH testnet.
///
/// Uses Alchemy if ALCHEMY_API_KEY env var is set, otherwise falls back to thirdweb.
async fn create_http_provider()
-> Result<impl Provider + Clone, Box<dyn std::error::Error + Send + Sync>> {
    let rpc_url = get_http_rpc_url();
    let url = rpc_url.parse()?;
    let provider = ProviderBuilder::new().connect_http(url);

    // Quick health check
    match timeout(Duration::from_secs(5), provider.get_chain_id()).await {
        Ok(Ok(chain_id)) => {
            info!(chain_id, "Connected to MegaETH testnet");
            return Ok(provider);
        }
        Ok(Err(e)) => {
            warn!("RPC health check failed: {}", e);
        }
        Err(_) => {
            warn!("RPC health check timed out");
        }
    }

    // If Alchemy failed, try fallback
    if rpc_url.contains("alchemy") {
        info!("Alchemy failed, trying fallback RPC...");
        let fallback_url = FALLBACK_HTTP_RPC.parse()?;
        let fallback_provider = ProviderBuilder::new().connect_http(fallback_url);
        return Ok(fallback_provider);
    }

    // Return the provider anyway, let the caller handle errors
    Ok(provider)
}

/// Create a WebSocket provider for MegaETH testnet.
///
/// Uses Alchemy if ALCHEMY_API_KEY env var is set, otherwise falls back to public endpoint.
async fn create_ws_provider()
-> Result<impl Provider + Clone, Box<dyn std::error::Error + Send + Sync>> {
    let ws_url = get_ws_rpc_url();
    let ws = WsConnect::new(&ws_url);
    let provider = timeout(CONNECTION_TIMEOUT, ProviderBuilder::new().connect_ws(ws)).await??;
    Ok(provider)
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIVE NETWORK TESTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Test: Verify HTTP RPC connectivity to MegaETH testnet
#[tokio::test]
#[ignore = "requires network access"]
async fn test_megaeth_http_connectivity() {
    tracing_subscriber::fmt::try_init().ok();
    info!("Testing MegaETH HTTP RPC connectivity...");

    // Build HTTP provider
    let provider = create_http_provider()
        .await
        .expect("Failed to create provider");

    // Test 1: Get chain ID
    let chain_id = timeout(CONNECTION_TIMEOUT, provider.get_chain_id())
        .await
        .expect("Timeout getting chain ID")
        .expect("Failed to get chain ID");

    info!(chain_id, "Connected to MegaETH testnet");
    assert_eq!(
        chain_id, MEGAETH_CHAIN_ID,
        "Expected MegaETH testnet chain ID {MEGAETH_CHAIN_ID}"
    );

    // Test 2: Get latest block number
    let block_number = provider
        .get_block_number()
        .await
        .expect("Failed to get block number");

    info!(block_number, "Current block number");
    assert!(block_number > 0, "Block number should be positive");

    // Test 3: Get a recent block
    let block = provider
        .get_block_by_number(BlockNumberOrTag::Latest)
        .await
        .expect("Failed to get block")
        .expect("Block not found");

    info!(
        block_number = block.header.number,
        tx_count = block.transactions.len(),
        timestamp = %block.header.timestamp,
        "Fetched latest block"
    );

    info!("✓ HTTP connectivity test passed");
}

/// Test: Verify WebSocket connectivity to MegaETH testnet
///
/// Note: Uses public MegaETH WebSocket endpoint which may be unstable.
/// Alchemy doesn't support eth_subscribe for MegaETH.
///
/// MegaETH Realtime API also supports `miniBlocks` subscription for
/// streaming mini blocks (~10ms) instead of EVM blocks (~1s).
#[tokio::test]
#[ignore = "requires network access; public WS endpoint may be unstable"]
async fn test_megaeth_ws_connectivity() {
    install_crypto_provider();
    tracing_subscriber::fmt::try_init().ok();
    info!("Testing MegaETH WebSocket connectivity...");

    // Build WebSocket provider
    let provider = create_ws_provider()
        .await
        .expect("Failed to create WS provider");

    // Test 1: Get chain ID via WebSocket
    let chain_id = provider
        .get_chain_id()
        .await
        .expect("Failed to get chain ID");

    info!(chain_id, "Connected via WebSocket");
    assert_eq!(
        chain_id, MEGAETH_CHAIN_ID,
        "Expected MegaETH testnet chain ID {MEGAETH_CHAIN_ID}"
    );

    // Test 2: Subscribe to new blocks and receive a few
    let block_count = Arc::new(AtomicU64::new(0));
    let block_count_clone = block_count.clone();

    let subscription = provider
        .subscribe_blocks()
        .await
        .expect("Failed to subscribe to blocks");

    info!("Subscribed to new blocks, waiting for blocks...");

    // Wait for up to 15 seconds to receive at least 1 block
    let receive_task = tokio::spawn(async move {
        let mut stream = subscription.into_stream();
        while let Some(header) = stream.next().await {
            let count = block_count_clone.fetch_add(1, Ordering::SeqCst) + 1;
            info!(
                block_number = header.number,
                count, "Received block via WebSocket"
            );
            if count >= 3 {
                break;
            }
        }
    });

    // Give it 15 seconds to receive blocks
    let _ = timeout(Duration::from_secs(15), receive_task).await;

    let received = block_count.load(Ordering::SeqCst);
    info!(received, "Total blocks received via WebSocket");

    // We should receive at least 1 block in 15 seconds
    // MegaETH has ~10ms block time, so we should receive many
    assert!(
        received >= 1,
        "Expected to receive at least 1 block, got {received}"
    );

    info!("✓ WebSocket connectivity test passed");
}

/// Test: Fetch recent logs from MegaETH testnet (any contract)
#[tokio::test]
#[ignore = "requires network access"]
async fn test_megaeth_fetch_logs() {
    tracing_subscriber::fmt::try_init().ok();
    info!("Testing log fetching from MegaETH testnet...");

    let provider = create_http_provider()
        .await
        .expect("Failed to create provider");

    // Get the latest block
    let latest_block = provider
        .get_block_number()
        .await
        .expect("Failed to get block number");

    // Fetch logs from a single block (no address filter - get ALL logs)
    // Note: MegaETH has VERY high throughput - each block can have thousands of logs
    // Thirdweb RPC limits results to 20k logs per query
    let from_block = latest_block;

    info!(from_block, to_block = latest_block, "Fetching logs...");

    let filter = Filter::new().from_block(from_block).to_block(latest_block);

    let logs = provider
        .get_logs(&filter)
        .await
        .expect("Failed to get logs");

    info!(
        log_count = logs.len(),
        from_block,
        to_block = latest_block,
        "Fetched logs from network"
    );

    // Log some sample events
    for (i, log) in logs.iter().take(5).enumerate() {
        info!(
            index = i,
            block = log.block_number,
            address = %log.address(),
            topics = log.topics().len(),
            "Sample log"
        );
    }

    info!("✓ Log fetching test passed (found {} logs)", logs.len());
}

/// Test: Full pipeline - fetch blocks and store in TimescaleDB
///
/// NOTE: This test may hit rate limits on public RPCs (429 errors).
/// It's best run against a private RPC endpoint or with significant delays.
#[tokio::test]
#[ignore = "requires network access and Docker; may hit rate limits"]
async fn test_live_indexing_pipeline() {
    tracing_subscriber::fmt::try_init().ok();
    info!("Starting live indexing pipeline test...");

    // Start TimescaleDB container
    info!("Starting TimescaleDB container...");
    let db = TestDb::new().await;

    info!("TimescaleDB ready, connecting to MegaETH...");

    // Connect to MegaETH
    let provider = create_http_provider()
        .await
        .expect("Failed to create provider");

    let chain_id = provider
        .get_chain_id()
        .await
        .expect("Failed to get chain ID");
    info!(chain_id, "Connected to MegaETH");

    // Create a table to track indexed blocks
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS indexed_blocks (
            block_number BIGINT PRIMARY KEY,
            block_hash TEXT NOT NULL,
            timestamp TIMESTAMPTZ NOT NULL,
            tx_count INTEGER NOT NULL,
            log_count INTEGER NOT NULL,
            indexed_at TIMESTAMPTZ DEFAULT NOW()
        )
        "#,
    )
    .execute(&db.pool)
    .await
    .expect("Failed to create indexed_blocks table");

    // Create a table to track indexed logs
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS indexed_logs (
            id SERIAL PRIMARY KEY,
            block_number BIGINT NOT NULL,
            log_index INTEGER NOT NULL,
            address TEXT NOT NULL,
            topic0 TEXT,
            data_size INTEGER NOT NULL,
            indexed_at TIMESTAMPTZ DEFAULT NOW()
        )
        "#,
    )
    .execute(&db.pool)
    .await
    .expect("Failed to create indexed_logs table");

    // Get starting block
    let start_block = provider
        .get_block_number()
        .await
        .expect("Failed to get block number");

    info!(start_block, "Starting from block");

    // Index blocks for TEST_DURATION
    let mut blocks_indexed = 0u64;
    let mut logs_indexed = 0u64;
    let mut current_block = start_block;

    let deadline = tokio::time::Instant::now() + TEST_DURATION;

    info!(
        duration_secs = TEST_DURATION.as_secs(),
        "Indexing blocks for duration..."
    );

    while tokio::time::Instant::now() < deadline {
        // Get latest block
        let latest = provider
            .get_block_number()
            .await
            .expect("Failed to get latest block");

        if latest <= current_block {
            // No new blocks, wait a bit
            sleep(Duration::from_millis(100)).await;
            continue;
        }

        // Process new blocks
        for block_num in (current_block + 1)..=latest {
            // Fetch block
            let block = match provider
                .get_block_by_number(BlockNumberOrTag::Number(block_num))
                .await
            {
                Ok(Some(b)) => b,
                Ok(None) => {
                    warn!(block_num, "Block not found, skipping");
                    continue;
                }
                Err(e) => {
                    warn!(block_num, error = %e, "Failed to fetch block");
                    continue;
                }
            };

            // Fetch logs for this block
            let filter = Filter::new().from_block(block_num).to_block(block_num);

            let logs = provider.get_logs(&filter).await.unwrap_or_default();

            // Store block info
            let block_hash = format!("{:?}", block.header.hash);
            let timestamp = chrono::DateTime::from_timestamp(block.header.timestamp as i64, 0)
                .unwrap_or_else(Utc::now);

            sqlx::query(
                r#"
                INSERT INTO indexed_blocks (block_number, block_hash, timestamp, tx_count, log_count)
                VALUES ($1, $2, $3, $4, $5)
                ON CONFLICT (block_number) DO NOTHING
                "#,
            )
            .bind(block_num as i64)
            .bind(&block_hash)
            .bind(timestamp)
            .bind(block.transactions.len() as i32)
            .bind(logs.len() as i32)
            .execute(&db.pool)
            .await
            .expect("Failed to insert block");

            // Store log info (first 10 per block to avoid overwhelming the test)
            for (log_idx, log) in logs.iter().take(10).enumerate() {
                let topic0 = log.topics().first().map(|t| format!("{t:?}"));

                sqlx::query(
                    r#"
                    INSERT INTO indexed_logs (block_number, log_index, address, topic0, data_size)
                    VALUES ($1, $2, $3, $4, $5)
                    "#,
                )
                .bind(block_num as i64)
                .bind(log_idx as i32)
                .bind(format!("{:?}", log.address()))
                .bind(topic0)
                .bind(log.data().data.len() as i32)
                .execute(&db.pool)
                .await
                .expect("Failed to insert log");

                logs_indexed += 1;
            }

            blocks_indexed += 1;

            if blocks_indexed.is_multiple_of(100) {
                info!(
                    blocks_indexed,
                    logs_indexed,
                    current_block = block_num,
                    "Progress update"
                );
            }
        }

        current_block = latest;
    }

    // Final stats
    info!(
        blocks_indexed,
        logs_indexed,
        start_block,
        end_block = current_block,
        "Indexing complete!"
    );

    // Verify data in database
    let block_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM indexed_blocks")
        .fetch_one(&db.pool)
        .await
        .expect("Failed to count blocks");

    let log_count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM indexed_logs")
        .fetch_one(&db.pool)
        .await
        .expect("Failed to count logs");

    info!(
        db_blocks = block_count.0,
        db_logs = log_count.0,
        "Database verification"
    );

    // Assertions
    assert!(blocks_indexed > 0, "Expected to index at least 1 block");
    assert_eq!(block_count.0 as u64, blocks_indexed, "Block count mismatch");

    // Sample some data
    let sample_blocks: Vec<(i64, i32, i32)> = sqlx::query_as(
        "SELECT block_number, tx_count, log_count FROM indexed_blocks ORDER BY block_number DESC LIMIT 5",
    )
    .fetch_all(&db.pool)
    .await
    .expect("Failed to sample blocks");

    info!("Sample indexed blocks:");
    for (block_num, tx_count, log_count) in &sample_blocks {
        info!(block = block_num, txs = tx_count, logs = log_count, "Block");
    }

    info!("✓ Live indexing pipeline test passed!");
    info!(
        "  - Indexed {} blocks in {} seconds",
        blocks_indexed,
        TEST_DURATION.as_secs()
    );
    info!("  - Captured {} logs", logs_indexed);
    info!(
        "  - Average: {:.1} blocks/sec",
        blocks_indexed as f64 / TEST_DURATION.as_secs_f64()
    );
}

/// Test: WebSocket subscription with log streaming using MegaETH Realtime API
///
/// According to MegaETH Realtime API docs, log subscriptions with
/// `fromBlock: "pending"` and `toBlock: "pending"` stream logs as soon as
/// transactions are packaged into mini blocks (~10ms latency).
#[tokio::test]
#[ignore = "requires network access; public WS endpoint may be unstable"]
async fn test_ws_log_subscription() {
    install_crypto_provider();
    tracing_subscriber::fmt::try_init().ok();
    info!("Testing WebSocket log subscription (MegaETH Realtime API)...");

    // Connect via WebSocket
    let provider = create_ws_provider()
        .await
        .expect("Failed to create WS provider");

    info!("Connected, subscribing to logs...");

    // Subscribe to ALL logs with pending block tags for real-time streaming
    // This follows MegaETH Realtime API: fromBlock/toBlock = "pending"
    let filter = Filter::new()
        .from_block(BlockNumberOrTag::Pending)
        .to_block(BlockNumberOrTag::Pending);

    let subscription = provider
        .subscribe_logs(&filter)
        .await
        .expect("Failed to subscribe to logs");

    let log_count = Arc::new(AtomicU64::new(0));
    let log_count_clone = log_count.clone();

    info!("Subscribed, waiting for logs...");

    let receive_task = tokio::spawn(async move {
        let mut stream = subscription.into_stream();
        while let Some(log) = stream.next().await {
            let count = log_count_clone.fetch_add(1, Ordering::SeqCst) + 1;
            debug!(
                count,
                block = log.block_number,
                address = %log.address(),
                "Received log"
            );
            if count >= 10 {
                info!("Received 10 logs, stopping subscription");
                break;
            }
        }
    });

    // Wait up to 30 seconds for logs
    let _ = timeout(Duration::from_secs(30), receive_task).await;

    let received = log_count.load(Ordering::SeqCst);
    info!(received, "Total logs received via WebSocket subscription");

    // Note: We might receive 0 logs if the network is quiet
    // This is not a failure, just informational
    if received == 0 {
        warn!("No logs received - network may be quiet or filter too restrictive");
    }

    info!("✓ WebSocket log subscription test complete");
}
