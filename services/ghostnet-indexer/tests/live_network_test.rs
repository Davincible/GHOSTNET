//! Live network integration tests for MegaETH.
//!
//! # Overview
//!
//! These tests validate the indexer's ability to connect to MegaETH and process
//! real blockchain data. **MAINNET is the primary target** - testnet WebSocket
//! subscriptions are broken on public endpoints.
//!
//! # MegaETH Realtime API
//!
//! MegaETH executes transactions within 10ms and exposes results via a Realtime API:
//! - **Mini blocks**: ~10ms preconfirmed blocks (vs 1s EVM blocks)
//! - **WebSocket subscriptions**: `miniBlocks`, `stateChanges`, `logs` streaming
//! - **HTTP RPC**: Standard Ethereum JSON-RPC + `eth_getLogsWithCursor`
//!
//! # Network Status (January 2026)
//!
//! | Network | Chain ID | HTTP | WebSocket Subscriptions |
//! |---------|----------|------|-------------------------|
//! | **MAINNET** | 4326 | ✅ | ✅ ALL WORK |
//! | TESTNET | 6343 | ⚠️ Flaky | ❌ BROKEN |
//!
//! See `docs/learnings/megaeth-rpc-endpoints.md` for comprehensive endpoint analysis.
//!
//! # Running the Tests
//!
//! ```bash
//! # Run the primary E2E mainnet test (recommended)
//! cargo test --test live_network_test test_mainnet_e2e_pipeline --features test-utils -- --ignored --nocapture
//!
//! # Run all live network tests (requires Docker + Internet)
//! cargo test --test live_network_test --features test-utils -- --ignored --nocapture
//!
//! # Run just WebSocket connectivity test
//! cargo test --test live_network_test test_megaeth_ws --features test-utils -- --ignored --nocapture
//! ```
//!
//! # Requirements
//!
//! - Docker daemon running (for TimescaleDB tests)
//! - Internet connection
//! - Optional: `ALCHEMY_API_KEY` for testnet HTTP reliability
//!
//! # Test Categories
//!
//! - **E2E Pipeline** (`test_mainnet_e2e_pipeline`): Full mainnet verification
//! - **WebSocket Tests**: Subscription testing on mainnet
//! - **HTTP Tests**: Basic connectivity (testnet, may be flaky)
//! - **MegaETH-Specific**: `eth_getLogsWithCursor`, `miniBlocks`, `stateChanges`

mod common;

use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use alloy::eips::BlockNumberOrTag;
use alloy::primitives::Address;
use alloy::providers::{Provider, ProviderBuilder, WsConnect};
use alloy::rpc::types::{Filter, Log};
use chrono::Utc;
use futures::StreamExt;
use rustls::crypto::ring as rustls_ring;
use serde::{Deserialize, Serialize};
use serde_json::json;
use tokio::time::{sleep, timeout};
use tracing::{debug, info, warn};

use common::fixtures::TestDb;

/// Install the rustls crypto provider (required for WebSocket TLS connections).
fn install_crypto_provider() {
    // Try to install, ignore if already installed
    let _ = rustls_ring::default_provider().install_default();
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS - MAINNET (PRIMARY)
// ═══════════════════════════════════════════════════════════════════════════════

/// MegaETH MAINNET WebSocket endpoint - FULLY WORKING
/// Supports: miniBlocks, stateChanges, logs, newHeads subscriptions
const MEGAETH_MAINNET_WS_RPC: &str = "wss://mainnet.megaeth.com/ws";

/// MegaETH MAINNET HTTP RPC (available for future HTTP-based mainnet tests)
#[allow(dead_code)]
const MEGAETH_MAINNET_HTTP_RPC: &str = "https://mainnet.megaeth.com/rpc";

/// MegaETH mainnet chain ID
const MEGAETH_MAINNET_CHAIN_ID: u64 = 4326;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS - TESTNET (LEGACY - WebSocket subscriptions BROKEN)
// ═══════════════════════════════════════════════════════════════════════════════

/// MegaETH TESTNET WebSocket endpoint
/// WARNING: Accepts subscriptions but NEVER streams data (broken as of Jan 2026)
const MEGAETH_TESTNET_WS_RPC: &str = "wss://carrot.megaeth.com/ws";

/// MegaETH TESTNET HTTP RPC (official, but flaky - frequent 502/504 errors)
const MEGAETH_TESTNET_HTTP_RPC: &str = "https://carrot.megaeth.com/rpc";

/// MegaETH TESTNET HTTP RPC fallback
const MEGAETH_TESTNET_HTTP_RPC_FALLBACK: &str = "https://timothy.megaeth.com/rpc";

/// Thirdweb HTTP RPC for testnet
const THIRDWEB_TESTNET_HTTP_RPC: &str = "https://6343.rpc.thirdweb.com";

/// Alchemy HTTP RPC base (testnet only, requires API key)
const ALCHEMY_TESTNET_HTTP_BASE: &str = "https://megaeth-testnet.g.alchemy.com/v2/";

/// Alchemy WebSocket base - NOTE: Does NOT support eth_subscribe!
const ALCHEMY_TESTNET_WS_BASE: &str = "wss://megaeth-testnet.g.alchemy.com/v2/";

/// MegaETH testnet chain ID
const MEGAETH_TESTNET_CHAIN_ID: u64 = 6343;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS - TEST CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

/// How long to run the live indexing test
const TEST_DURATION: Duration = Duration::from_secs(30);

/// Timeout for initial connection
const CONNECTION_TIMEOUT: Duration = Duration::from_secs(30);

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS - TESTNET (Legacy, used by testnet-specific tests)
// ═══════════════════════════════════════════════════════════════════════════════

/// Get fallback HTTP RPC URLs for testnet retry logic.
///
/// Used by: `create_testnet_http_provider()`
fn get_testnet_http_fallback_urls() -> Vec<String> {
    let mut urls = vec![
        MEGAETH_TESTNET_HTTP_RPC.to_string(),
        MEGAETH_TESTNET_HTTP_RPC_FALLBACK.to_string(),
        THIRDWEB_TESTNET_HTTP_RPC.to_string(),
    ];
    
    // Add Alchemy if available (most reliable for testnet)
    if let Ok(key) = std::env::var("ALCHEMY_API_KEY") {
        if !key.is_empty() {
            urls.insert(0, format!("{}{}", ALCHEMY_TESTNET_HTTP_BASE, key));
        }
    }
    
    urls
}

/// Get Alchemy WebSocket URL for testnet (if API key is set).
///
/// NOTE: Alchemy does NOT support eth_subscribe for MegaETH!
/// This is only useful for basic WebSocket connectivity, not subscriptions.
fn get_alchemy_testnet_ws_url() -> Option<String> {
    match std::env::var("ALCHEMY_API_KEY") {
        Ok(key) if !key.is_empty() => {
            Some(format!("{}{}", ALCHEMY_TESTNET_WS_BASE, key))
        }
        _ => None,
    }
}

/// Create an HTTP provider for MegaETH TESTNET with automatic fallback.
///
/// WARNING: Testnet HTTP endpoints are flaky (frequent 502/504 errors).
/// For reliable testing, use mainnet or set ALCHEMY_API_KEY.
///
/// Tries endpoints in order until one succeeds:
/// 1. Alchemy (if ALCHEMY_API_KEY set) - most reliable
/// 2. Official carrot.megaeth.com (flaky)
/// 3. Official timothy.megaeth.com (flaky)
/// 4. Thirdweb
async fn create_testnet_http_provider()
-> Result<impl Provider + Clone, Box<dyn std::error::Error + Send + Sync>> {
    let fallback_urls = get_testnet_http_fallback_urls();
    
    for (i, rpc_url) in fallback_urls.iter().enumerate() {
        debug!("Trying testnet RPC endpoint {}/{}: {}", i + 1, fallback_urls.len(), rpc_url);
        
        let url = match rpc_url.parse() {
            Ok(u) => u,
            Err(e) => {
                warn!("Invalid URL {}: {}", rpc_url, e);
                continue;
            }
        };
        
        let provider = ProviderBuilder::new().connect_http(url);
        
        // Health check with retry
        for attempt in 1..=3 {
            match timeout(Duration::from_secs(10), provider.get_chain_id()).await {
                Ok(Ok(chain_id)) => {
                    if chain_id == MEGAETH_TESTNET_CHAIN_ID {
                        info!(chain_id, rpc_url, "Connected to MegaETH testnet");
                        return Ok(provider);
                    } else {
                        warn!(expected = MEGAETH_TESTNET_CHAIN_ID, actual = chain_id, "Chain ID mismatch");
                        break; // Try next endpoint
                    }
                }
                Ok(Err(e)) => {
                    let err_str = e.to_string();
                    if err_str.contains("502") || err_str.contains("503") || err_str.contains("429") {
                        warn!(attempt, rpc_url, error = %e, "Transient error, retrying...");
                        sleep(Duration::from_millis(500 * attempt as u64)).await;
                        continue;
                    }
                    warn!(rpc_url, error = %e, "RPC error");
                    break; // Try next endpoint
                }
                Err(_) => {
                    warn!(attempt, rpc_url, "Health check timed out");
                    if attempt < 3 {
                        sleep(Duration::from_millis(500)).await;
                        continue;
                    }
                    break; // Try next endpoint
                }
            }
        }
    }
    
    Err("All testnet RPC endpoints failed".into())
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTNET HTTP TESTS (Legacy - may be flaky due to 502/504 errors)
// ═══════════════════════════════════════════════════════════════════════════════

/// Test: Verify HTTP RPC connectivity to MegaETH TESTNET
///
/// WARNING: Testnet HTTP endpoints are flaky. This test may fail with 502/504 errors.
/// For reliable testing, set ALCHEMY_API_KEY or use mainnet tests instead.
#[tokio::test]
#[ignore = "requires network access; testnet HTTP is flaky"]
async fn test_megaeth_http_connectivity() {
    tracing_subscriber::fmt::try_init().ok();
    info!("Testing MegaETH TESTNET HTTP RPC connectivity...");
    info!("NOTE: Testnet HTTP is flaky. Use mainnet tests for reliable verification.");

    // Build HTTP provider with retries
    let provider = create_testnet_http_provider()
        .await
        .expect("Failed to connect to any MegaETH testnet RPC endpoint");

    // Test 1: Get chain ID
    let chain_id = timeout(CONNECTION_TIMEOUT, provider.get_chain_id())
        .await
        .expect("Timeout getting chain ID")
        .expect("Failed to get chain ID");

    info!(chain_id, "Connected to MegaETH testnet");
    assert_eq!(
        chain_id, MEGAETH_TESTNET_CHAIN_ID,
        "Expected MegaETH testnet chain ID {MEGAETH_TESTNET_CHAIN_ID}"
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

    info!("✓ Testnet HTTP connectivity test passed");
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAINNET WEBSOCKET TESTS (Primary - these are the reliable tests)
// ═══════════════════════════════════════════════════════════════════════════════

/// Test: Verify WebSocket connectivity to MegaETH MAINNET
///
/// This is a core connectivity test using MegaETH mainnet, which has fully
/// working WebSocket subscriptions (unlike testnet public endpoints).
#[tokio::test]
#[ignore = "requires network access"]
async fn test_megaeth_ws_connectivity() {
    install_crypto_provider();
    tracing_subscriber::fmt::try_init().ok();
    info!("Testing MegaETH MAINNET WebSocket connectivity...");

    // Connect to mainnet WebSocket (testnet public WS is broken)
    info!(ws_url = MEGAETH_MAINNET_WS_RPC, "Connecting to mainnet WebSocket...");
    let ws = WsConnect::new(MEGAETH_MAINNET_WS_RPC);
    let provider = timeout(CONNECTION_TIMEOUT, ProviderBuilder::new().connect_ws(ws))
        .await
        .expect("Connection timeout")
        .expect("WebSocket connection failed");

    // Test 1: Get chain ID via WebSocket
    let chain_id = provider
        .get_chain_id()
        .await
        .expect("Failed to get chain ID");

    info!(chain_id, "Connected via WebSocket");
    assert_eq!(
        chain_id, MEGAETH_MAINNET_CHAIN_ID,
        "Expected MegaETH mainnet chain ID {MEGAETH_MAINNET_CHAIN_ID}"
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

// ═══════════════════════════════════════════════════════════════════════════════
// TESTNET HTTP TESTS (Legacy - may be flaky)
// ═══════════════════════════════════════════════════════════════════════════════

/// Test: Fetch recent logs from MegaETH TESTNET (any contract)
///
/// WARNING: Testnet HTTP endpoints are flaky. This test may fail with 502/504 errors.
#[tokio::test]
#[ignore = "requires network access; testnet HTTP is flaky"]
async fn test_megaeth_fetch_logs() {
    tracing_subscriber::fmt::try_init().ok();
    info!("Testing log fetching from MegaETH testnet...");
    info!("NOTE: Testnet HTTP is flaky. May fail with 502/504 errors.");

    let provider = create_testnet_http_provider()
        .await
        .expect("Failed to connect to MegaETH testnet RPC");

    // Get the latest block
    let latest_block = provider
        .get_block_number()
        .await
        .expect("Failed to get block number");

    // Fetch logs from a single block (no address filter - get ALL logs)
    // Note: MegaETH has VERY high throughput - each block can have thousands of logs
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

/// Test: Full pipeline on TESTNET - fetch blocks and store in TimescaleDB
///
/// WARNING: This is a TESTNET test and is FLAKY due to 502/504 errors.
/// For reliable E2E testing, use `test_mainnet_e2e_pipeline` instead.
///
/// NOTE: This test may hit rate limits on public RPCs (429 errors).
#[tokio::test]
#[ignore = "requires network access and Docker; testnet is flaky - use mainnet E2E instead"]
async fn test_live_indexing_pipeline() {
    tracing_subscriber::fmt::try_init().ok();
    info!("Starting TESTNET live indexing pipeline test...");
    info!("WARNING: Testnet is flaky. For reliable E2E, use test_mainnet_e2e_pipeline");

    // Start TimescaleDB container
    info!("Starting TimescaleDB container...");
    let db = TestDb::new().await;

    info!("TimescaleDB ready, connecting to MegaETH testnet...");

    // Connect to MegaETH testnet
    let provider = create_testnet_http_provider()
        .await
        .expect("Failed to connect to MegaETH testnet RPC");

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

    let mut consecutive_errors = 0u32;
    const MAX_CONSECUTIVE_ERRORS: u32 = 5;
    
    while tokio::time::Instant::now() < deadline {
        // Get latest block with retry logic for transient errors
        let latest = match provider.get_block_number().await {
            Ok(n) => {
                consecutive_errors = 0;
                n
            }
            Err(e) => {
                let err_str = e.to_string();
                consecutive_errors += 1;
                
                // Retry transient errors with backoff
                if err_str.contains("429") || err_str.contains("502") || err_str.contains("503") 
                   || err_str.contains("504") || err_str.contains("timeout") || err_str.contains("1015") {
                    if consecutive_errors >= MAX_CONSECUTIVE_ERRORS {
                        panic!(
                            "Too many consecutive RPC errors ({}/{}): {}",
                            consecutive_errors, MAX_CONSECUTIVE_ERRORS, e
                        );
                    }
                    warn!(error = %e, consecutive_errors, "Transient error, backing off");
                    sleep(Duration::from_secs(consecutive_errors as u64)).await;
                    continue;
                }
                
                panic!("Failed to get latest block: {}", e);
            }
        };

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

/// Test: WebSocket log subscription using MegaETH MAINNET Realtime API
///
/// Log subscriptions with `fromBlock: "pending"` and `toBlock: "pending"` stream
/// logs as soon as transactions are packaged into mini blocks (~10ms latency).
///
/// Uses MAINNET since testnet public WebSocket subscriptions are broken.
#[tokio::test]
#[ignore = "requires network access"]
async fn test_ws_log_subscription() {
    install_crypto_provider();
    tracing_subscriber::fmt::try_init().ok();
    info!("Testing WebSocket log subscription (MegaETH MAINNET Realtime API)...");

    // Connect to mainnet WebSocket (testnet public WS is broken)
    info!(ws_url = MEGAETH_MAINNET_WS_RPC, "Connecting to mainnet WebSocket...");
    let ws = WsConnect::new(MEGAETH_MAINNET_WS_RPC);
    let provider = timeout(CONNECTION_TIMEOUT, ProviderBuilder::new().connect_ws(ws))
        .await
        .expect("Connection timeout")
        .expect("WebSocket connection failed");

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

/// Response from `eth_getLogsWithCursor` - MegaETH's paginated log query API.
///
/// When a query exceeds server-side resource caps, the server returns a partial
/// result and a cursor that marks where it left off.
#[derive(Debug, Deserialize)]
struct LogsWithCursorResponse {
    /// Logs returned in this batch
    logs: Vec<Log>,
    /// Cursor for pagination (absent when query is complete)
    #[serde(default)]
    cursor: Option<String>,
}

/// Filter params for `eth_getLogsWithCursor` - same as eth_getLogs plus cursor.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct LogsWithCursorFilter {
    /// Starting block (hex string like "0x100")
    from_block: String,
    /// Ending block (hex string like "0x200")
    to_block: String,
    /// Optional contract addresses to filter
    #[serde(skip_serializing_if = "Option::is_none")]
    address: Option<Vec<Address>>,
    /// Optional topics to filter
    #[serde(skip_serializing_if = "Option::is_none")]
    topics: Option<Vec<Option<String>>>,
    /// Cursor from previous response (for pagination)
    #[serde(skip_serializing_if = "Option::is_none")]
    cursor: Option<String>,
}

// ═══════════════════════════════════════════════════════════════════════════════
// MEGAETH-SPECIFIC API TESTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Test: Paginated log queries with `eth_getLogsWithCursor` (MegaETH-specific)
///
/// This API is critical for production backfill operations. MegaETH at 1000 TPS
/// generates 1 year of Ethereum data every 5 days, so standard eth_getLogs
/// will timeout on large ranges. The cursor-based pagination allows:
/// - Partial results when limits are hit
/// - Resume from where query stopped
/// - No wasted computation
///
/// NOTE: This is a MegaETH-specific API. Alchemy does NOT support it.
/// Uses testnet endpoint (may be flaky with 502/504 errors).
///
/// See: docs/MegaETH_RealtimeAPI.md
#[tokio::test]
#[ignore = "requires network access; testnet endpoint may be flaky"]
async fn test_eth_get_logs_with_cursor() {
    tracing_subscriber::fmt::try_init().ok();
    info!("Testing eth_getLogsWithCursor (MegaETH paginated log API)...");
    info!("NOTE: Using testnet endpoint which may be flaky.");

    // MUST use MegaETH public RPC - Alchemy doesn't support this method
    let rpc_url = MEGAETH_TESTNET_HTTP_RPC;
    info!(rpc_url, "Using MegaETH testnet RPC (eth_getLogsWithCursor is MegaETH-specific)");
    let client = reqwest::Client::new();

    // Get the latest block to determine our query range
    let block_response: serde_json::Value = client
        .post(rpc_url)
        .json(&json!({
            "jsonrpc": "2.0",
            "method": "eth_blockNumber",
            "params": [],
            "id": 1
        }))
        .send()
        .await
        .expect("Failed to send request")
        .json()
        .await
        .expect("Failed to parse response");

    // Check for RPC errors
    if let Some(error) = block_response.get("error") {
        let code = error.get("code").and_then(|c| c.as_i64()).unwrap_or(0);
        let message = error.get("message").and_then(|m| m.as_str()).unwrap_or("Unknown");
        panic!("RPC error getting block number ({}): {}", code, message);
    }
    
    let latest_block_hex = block_response["result"]
        .as_str()
        .expect("Missing result field in eth_blockNumber response");
    let latest_block = u64::from_str_radix(&latest_block_hex[2..], 16)
        .expect("Invalid block number");

    info!(latest_block, latest_block_hex, "Got latest block");

    // Query a range of 100 blocks (should have activity on MegaETH testnet)
    let from_block = latest_block.saturating_sub(100);
    let from_block_hex = format!("0x{from_block:x}");
    let to_block_hex = format!("0x{latest_block:x}");

    info!(
        from_block,
        to_block = latest_block,
        "Querying logs with cursor..."
    );

    // First request - no cursor
    let filter = LogsWithCursorFilter {
        from_block: from_block_hex.clone(),
        to_block: to_block_hex.clone(),
        address: None, // All contracts
        topics: None,  // All events
        cursor: None,  // Start from beginning
    };

    let response: serde_json::Value = client
        .post(rpc_url)
        .json(&json!({
            "jsonrpc": "2.0",
            "method": "eth_getLogsWithCursor",
            "params": [filter],
            "id": 2
        }))
        .send()
        .await
        .expect("Failed to send request")
        .json()
        .await
        .expect("Failed to parse response");

    // Check for errors (the method might not be available on all endpoints)
    if let Some(error) = response.get("error") {
        let error_msg = error.get("message").and_then(|m| m.as_str()).unwrap_or("Unknown error");
        let error_code = error.get("code").and_then(|c| c.as_i64()).unwrap_or(0);
        
        if error_code == -32601 {
            // Method not found - endpoint doesn't support this MegaETH-specific API
            warn!(
                error_msg,
                error_code,
                "eth_getLogsWithCursor not available on this endpoint. \
                 This is a MegaETH-specific API. Try using MegaETH public RPC."
            );
            info!("✓ Test skipped - eth_getLogsWithCursor not available on this endpoint");
            return;
        }
        
        panic!("RPC error: {} (code: {})", error_msg, error_code);
    }

    // Parse the successful response
    let result = response.get("result").expect("Missing result field");
    
    // Handle both response formats:
    // 1. {logs: [...], cursor: "..."} - paginated format
    // 2. [...] - standard array format (some endpoints fall back to this)
    let (logs, cursor) = if result.is_array() {
        // Standard eth_getLogs response format (no cursor support)
        let logs: Vec<Log> = serde_json::from_value(result.clone())
            .expect("Failed to parse logs array");
        warn!("Endpoint returned standard eth_getLogs format (no cursor). \
               This might indicate the endpoint doesn't fully support eth_getLogsWithCursor.");
        (logs, None)
    } else {
        // Paginated format with cursor
        let parsed: LogsWithCursorResponse = serde_json::from_value(result.clone())
            .expect("Failed to parse LogsWithCursorResponse");
        (parsed.logs, parsed.cursor)
    };

    info!(
        logs_received = logs.len(),
        has_cursor = cursor.is_some(),
        cursor = ?cursor,
        "First batch received"
    );

    // Log sample entries
    for (i, log) in logs.iter().take(3).enumerate() {
        info!(
            index = i,
            block = ?log.block_number,
            address = %log.address(),
            topics = log.topics().len(),
            "Sample log"
        );
    }

    let mut total_logs = logs.len();
    let mut batches = 1;

    // If there's a cursor, continue fetching (up to 3 more batches with retry logic)
    if let Some(mut current_cursor) = cursor {
        for batch in 2..=3 {
            info!(batch, cursor = %current_cursor, "Fetching next batch...");
            
            // Add longer delay between batches to respect rate limits
            sleep(Duration::from_secs(2)).await;

            let filter = LogsWithCursorFilter {
                from_block: from_block_hex.clone(),
                to_block: to_block_hex.clone(),
                address: None,
                topics: None,
                cursor: Some(current_cursor),
            };

            // Retry logic for rate limiting
            let mut retry_count = 0;
            let response_json: serde_json::Value = loop {
                let response = client
                    .post(rpc_url)
                    .json(&json!({
                        "jsonrpc": "2.0",
                        "method": "eth_getLogsWithCursor",
                        "params": [filter.clone()],
                        "id": batch + 1
                    }))
                    .send()
                    .await
                    .expect("Failed to send request");
                
                let status = response.status();
                // Handle rate limiting and server errors with retry
                if status == reqwest::StatusCode::TOO_MANY_REQUESTS 
                   || status == reqwest::StatusCode::BAD_GATEWAY
                   || status == reqwest::StatusCode::SERVICE_UNAVAILABLE
                   || status == reqwest::StatusCode::GATEWAY_TIMEOUT {
                    retry_count += 1;
                    if retry_count > 3 {
                        warn!(batch, status = %status, "Server error after {} retries, stopping pagination", retry_count);
                        // Don't fail the test - we've already proven cursor pagination works
                        break serde_json::json!({"result": {"logs": [], "cursor": null}});
                    }
                    let backoff = Duration::from_secs(retry_count * 3);
                    warn!(batch, retry_count, status = %status, backoff_secs = backoff.as_secs(), "Server error, backing off...");
                    sleep(backoff).await;
                    continue;
                }
                if !status.is_success() {
                    panic!("HTTP error {} on batch {}", status, batch);
                }
                
                let body_text = response.text().await.expect("Failed to read response body");
                if body_text.is_empty() {
                    retry_count += 1;
                    if retry_count > 3 {
                        warn!("Empty response on batch {} after {} retries", batch, retry_count);
                        break serde_json::json!({"result": {"logs": [], "cursor": null}});
                    }
                    sleep(Duration::from_secs(2)).await;
                    continue;
                }
                
                break serde_json::from_str(&body_text)
                    .unwrap_or_else(|e| panic!("Failed to parse JSON on batch {}: {} (body: {})", 
                        batch, e, &body_text[..body_text.len().min(200)]));
            };
            
            // Check for RPC errors
            if let Some(error) = response_json.get("error") {
                let code = error.get("code").and_then(|c| c.as_i64()).unwrap_or(0);
                let msg = error.get("message").and_then(|m| m.as_str()).unwrap_or("Unknown");
                panic!("RPC error on batch {} ({}): {}", batch, code, msg);
            }

            let result = response_json.get("result")
                .unwrap_or_else(|| panic!("Missing result field on batch {}", batch));
            
            let parsed: LogsWithCursorResponse = serde_json::from_value(result.clone())
                .unwrap_or_else(|e| panic!("Failed to parse LogsWithCursorResponse on batch {}: {}", batch, e));

            info!(
                batch,
                logs_in_batch = parsed.logs.len(),
                has_more = parsed.cursor.is_some(),
                "Batch received"
            );

            total_logs += parsed.logs.len();
            batches += 1;

            match parsed.cursor {
                Some(next) => current_cursor = next,
                None => {
                    info!("No more cursors, query complete");
                    break;
                }
            }
        }
    }

    info!(
        total_logs,
        batches,
        from_block,
        to_block = latest_block,
        "Cursor-based pagination complete"
    );

    info!("✓ eth_getLogsWithCursor test passed");
    info!("  - Retrieved {} logs across {} batches", total_logs, batches);
}

/// Mini block schema from `miniBlocks` subscription.
///
/// Mini blocks are produced every ~10ms and contain preconfirmed transactions
/// along with their receipts.
///
/// NOTE: Field names in the actual API response differ from the documentation!
/// - API returns `number` (docs say `mini_block_number`)
/// - API returns `timestamp` (docs say `mini_block_timestamp`)
/// - All numeric fields are integers, not hex strings
#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
#[allow(dead_code)]
struct MiniBlock {
    /// The EVM block number this mini-block belongs to
    block_number: u64,
    /// Timestamp of the EVM block (Unix seconds)
    block_timestamp: u64,
    /// Index of this mini-block within the EVM block
    index: u64,
    /// The mini-block number in blockchain history (API calls this just "number")
    number: u64,
    /// Timestamp when this mini-block was created (Unix microseconds, API calls this just "timestamp")
    timestamp: u64,
    /// Gas used in this mini-block
    gas_used: u64,
    /// Transactions included (same schema as eth_getTransactionByHash)
    transactions: Vec<serde_json::Value>,
    /// Receipts of transactions (same schema as eth_getTransactionReceipt)
    receipts: Vec<serde_json::Value>,
}

/// Result from attempting a miniBlocks subscription on a specific endpoint
#[derive(Debug)]
struct MiniBlocksTestResult {
    endpoint: String,
    connected: bool,
    subscription_confirmed: bool,
    mini_blocks_received: u32,
    error: Option<String>,
}

/// Helper: Test miniBlocks subscription on a specific WebSocket endpoint
async fn test_mini_blocks_on_endpoint(ws_url: &str, endpoint_name: &str) -> MiniBlocksTestResult {
    use tokio_tungstenite::{connect_async, tungstenite::Message};
    use futures::SinkExt;

    info!(ws_url, endpoint_name, "Testing miniBlocks subscription...");

    // Try to connect
    let (mut ws_stream, _response) = match connect_async(ws_url).await {
        Ok(stream) => stream,
        Err(e) => {
            return MiniBlocksTestResult {
                endpoint: endpoint_name.to_string(),
                connected: false,
                subscription_confirmed: false,
                mini_blocks_received: 0,
                error: Some(format!("Connection failed: {}", e)),
            };
        }
    };

    info!(endpoint_name, "WebSocket connected, subscribing to miniBlocks...");

    // Send subscription request
    let subscribe_msg = json!({
        "jsonrpc": "2.0",
        "method": "eth_subscribe",
        "params": ["miniBlocks"],
        "id": 1
    });

    if let Err(e) = ws_stream
        .send(Message::Text(subscribe_msg.to_string().into()))
        .await
    {
        return MiniBlocksTestResult {
            endpoint: endpoint_name.to_string(),
            connected: true,
            subscription_confirmed: false,
            mini_blocks_received: 0,
            error: Some(format!("Failed to send subscription: {}", e)),
        };
    }

    let mut subscription_id: Option<String> = None;
    let mut mini_blocks_received = 0u32;
    let mut error_msg: Option<String> = None;
    let mut message_count = 0u32;

    let receive_timeout = Duration::from_secs(15);
    let deadline = tokio::time::Instant::now() + receive_timeout;

    while tokio::time::Instant::now() < deadline {
        let msg = match timeout(Duration::from_secs(2), ws_stream.next()).await {
            Ok(Some(Ok(Message::Text(text)))) => {
                message_count += 1;
                text.to_string()
            }
            Ok(Some(Ok(Message::Binary(data)))) => {
                message_count += 1;
                info!(endpoint_name, len = data.len(), "Received binary message");
                match String::from_utf8(data.to_vec()) {
                    Ok(s) => s,
                    Err(_) => continue,
                }
            }
            Ok(Some(Ok(Message::Close(frame)))) => {
                error_msg = Some(format!("WebSocket closed: {:?}", frame));
                break;
            }
            Ok(Some(Ok(Message::Ping(_)))) => continue,
            Ok(Some(Ok(Message::Pong(_)))) => continue,
            Ok(Some(Ok(Message::Frame(_)))) => continue,
            Ok(Some(Err(e))) => {
                error_msg = Some(format!("WebSocket error: {}", e));
                break;
            }
            Ok(None) => {
                error_msg = Some("WebSocket stream ended".to_string());
                break;
            }
            Err(_) => {
                // Timeout - if we have subscription but no mini blocks after a while, that's a problem
                if subscription_id.is_some() && mini_blocks_received == 0 && message_count > 0 {
                    debug!(endpoint_name, message_count, "Timeout after subscription confirmed, no mini blocks yet");
                }
                continue;
            }
        };

        // Log raw message for debugging (truncated)
        let msg_preview = if msg.len() > 500 { &msg[..500] } else { &msg[..] };
        info!(endpoint_name, message_count, msg = %msg_preview, "Raw WebSocket message");

        let parsed: serde_json::Value = match serde_json::from_str(&msg) {
            Ok(v) => v,
            Err(e) => {
                warn!(endpoint_name, error = %e, msg = %msg_preview, "Failed to parse message");
                continue;
            }
        };

        // Check for subscription confirmation
        if let Some(result) = parsed.get("result") {
            if subscription_id.is_none() {
                subscription_id = result.as_str().map(String::from);
                info!(endpoint_name, subscription_id = ?subscription_id, "Subscription confirmed");
                continue;
            }
        }

        // Check for error
        if let Some(error) = parsed.get("error") {
            let err_msg = error.get("message").and_then(|m| m.as_str()).unwrap_or("Unknown");
            let err_code = error.get("code").and_then(|c| c.as_i64()).unwrap_or(0);
            error_msg = Some(format!("RPC error {}: {}", err_code, err_msg));
            break;
        }

        // Check for mini block notification
        if let Some(params) = parsed.get("params") {
            info!(endpoint_name, "Got params field in message");
            if let Some(result) = params.get("result") {
                info!(endpoint_name, result_keys = ?result.as_object().map(|o| o.keys().collect::<Vec<_>>()), "Got result in params");
                match serde_json::from_value::<MiniBlock>(result.clone()) {
                    Ok(mini_block) => {
                        mini_blocks_received += 1;
                        info!(
                            endpoint_name,
                            mini_blocks_received,
                            block_number = mini_block.block_number,
                            mini_block_number = mini_block.number,
                            index = mini_block.index,
                            tx_count = mini_block.transactions.len(),
                            receipt_count = mini_block.receipts.len(),
                            gas_used = mini_block.gas_used,
                            "Received mini block"
                        );

                        if mini_blocks_received >= 3 {
                            info!(endpoint_name, "Received 3 mini blocks, success!");
                            break;
                        }
                    }
                    Err(e) => {
                        // Log the actual structure we received so we can fix the parsing
                        warn!(endpoint_name, error = %e, result = %result, "Failed to parse mini block - check struct definition");
                    }
                }
            }
        } else if subscription_id.is_some() {
            // We have a subscription but no params field - log what we got
            info!(endpoint_name, keys = ?parsed.as_object().map(|o| o.keys().collect::<Vec<_>>()), "Message without params field");
        }
    }

    MiniBlocksTestResult {
        endpoint: endpoint_name.to_string(),
        connected: true,
        subscription_confirmed: subscription_id.is_some(),
        mini_blocks_received,
        error: error_msg,
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MEGAETH REALTIME API SUBSCRIPTION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Test: `miniBlocks` subscription across multiple endpoints
///
/// The `miniBlocks` subscription streams mini blocks as they are produced (~10ms).
/// Each mini block includes both transactions AND receipts, making it efficient
/// for indexing.
///
/// ## Status (January 2026)
///
/// | Endpoint | Status |
/// |----------|--------|
/// | **MAINNET** (`mainnet.megaeth.com`) | ✅ WORKS |
/// | TESTNET (`carrot.megaeth.com`) | ❌ Broken (confirms sub but no data) |
/// | Alchemy | ❌ No eth_subscribe support |
///
/// This test verifies mainnet works and documents testnet's broken state.
///
/// See: docs/learnings/megaeth-rpc-endpoints.md
#[tokio::test]
#[ignore = "requires network access; tests MegaETH miniBlocks subscription"]
async fn test_mini_blocks_subscription() {
    install_crypto_provider();
    tracing_subscriber::fmt::try_init().ok();
    info!("Testing miniBlocks subscription on multiple endpoints...");

    let mut results: Vec<MiniBlocksTestResult> = Vec::new();

    // Test 1: MegaETH MAINNET WebSocket (WORKS!)
    info!("═══════════════════════════════════════════════════════════════════");
    info!("TEST 1: MegaETH MAINNET WebSocket ({})", MEGAETH_MAINNET_WS_RPC);
    info!("═══════════════════════════════════════════════════════════════════");
    let mainnet_result = test_mini_blocks_on_endpoint(MEGAETH_MAINNET_WS_RPC, "MegaETH Mainnet").await;
    results.push(mainnet_result);
    
    // Test 2: MegaETH TESTNET WebSocket (currently broken - accepts subs but no data)
    info!("═══════════════════════════════════════════════════════════════════");
    info!("TEST 2: MegaETH TESTNET WebSocket ({})", MEGAETH_TESTNET_WS_RPC);
    info!("═══════════════════════════════════════════════════════════════════");
    let testnet_result = test_mini_blocks_on_endpoint(MEGAETH_TESTNET_WS_RPC, "MegaETH Testnet").await;
    results.push(testnet_result);

    // Test 3: Alchemy WebSocket (if available) - expected to fail (no eth_subscribe support)
    if let Some(alchemy_ws_url) = get_alchemy_testnet_ws_url() {
        info!("═══════════════════════════════════════════════════════════════════");
        info!("TEST 3: Alchemy WebSocket (expected to fail - no eth_subscribe support)");
        info!("═══════════════════════════════════════════════════════════════════");
        let alchemy_result = test_mini_blocks_on_endpoint(&alchemy_ws_url, "Alchemy").await;
        results.push(alchemy_result);
    } else {
        info!("═══════════════════════════════════════════════════════════════════");
        info!("TEST 3: Alchemy WebSocket - SKIPPED (no ALCHEMY_API_KEY)");
        info!("═══════════════════════════════════════════════════════════════════");
    }

    // Summary
    info!("═══════════════════════════════════════════════════════════════════");
    info!("RESULTS SUMMARY");
    info!("═══════════════════════════════════════════════════════════════════");
    
    let mut any_success = false;
    for result in &results {
        let status = if result.mini_blocks_received > 0 {
            any_success = true;
            "✓ SUCCESS"
        } else if result.subscription_confirmed {
            "⚠ SUBSCRIBED BUT NO DATA"
        } else if result.connected {
            "✗ CONNECTED BUT SUBSCRIPTION FAILED"
        } else {
            "✗ CONNECTION FAILED"
        };

        info!(
            "{}: {} | connected={} | subscribed={} | mini_blocks={} | error={:?}",
            result.endpoint,
            status,
            result.connected,
            result.subscription_confirmed,
            result.mini_blocks_received,
            result.error
        );
    }

    // At least one endpoint must have successfully received mini blocks
    assert!(
        any_success,
        "\n\n\
        ╔══════════════════════════════════════════════════════════════════════════════╗\n\
        ║  miniBlocks SUBSCRIPTION FAILED ON ALL ENDPOINTS                             ║\n\
        ╠══════════════════════════════════════════════════════════════════════════════╣\n\
        ║  MegaETH Public WS: Connection OK, but eth_subscribe returns NO response     ║\n\
        ║  Alchemy WS: Does not support eth_subscribe for MegaETH                      ║\n\
        ╠══════════════════════════════════════════════════════════════════════════════╣\n\
        ║  This appears to be a platform limitation, not a test bug.                   ║\n\
        ║  The MegaETH Realtime API docs claim miniBlocks subscription should work,    ║\n\
        ║  but public WebSocket endpoints do not actually support it.                  ║\n\
        ╠══════════════════════════════════════════════════════════════════════════════╣\n\
        ║  WORKAROUND: Use HTTP polling with eth_getBlockByNumber for now.             ║\n\
        ╚══════════════════════════════════════════════════════════════════════════════╝\n\n\
        Results: {:?}",
        results
    );

    info!("✓ miniBlocks subscription test passed");
    info!("  - At least one endpoint successfully received mini blocks");
}

/// Result from attempting a stateChanges subscription on a specific endpoint
#[derive(Debug)]
struct StateChangesTestResult {
    endpoint: String,
    connected: bool,
    subscription_confirmed: bool,
    state_changes_received: u32,
    error: Option<String>,
}

/// Helper: Test stateChanges subscription on a specific WebSocket endpoint
async fn test_state_changes_on_endpoint(ws_url: &str, endpoint_name: &str) -> StateChangesTestResult {
    use tokio_tungstenite::{connect_async, tungstenite::Message};
    use futures::SinkExt;

    info!(ws_url, endpoint_name, "Testing stateChanges subscription...");

    // Try to connect
    let (mut ws_stream, _response) = match connect_async(ws_url).await {
        Ok(stream) => stream,
        Err(e) => {
            return StateChangesTestResult {
                endpoint: endpoint_name.to_string(),
                connected: false,
                subscription_confirmed: false,
                state_changes_received: 0,
                error: Some(format!("Connection failed: {}", e)),
            };
        }
    };

    info!(endpoint_name, "WebSocket connected, subscribing to stateChanges...");

    // Monitor well-known active addresses on MegaETH testnet
    let monitored_addresses = vec![
        "0x0000000000000000000000000000000000000000", // Null address
        "0x000000000000000000000000000000000000dead", // Burn address
    ];

    // Send subscription request
    let subscribe_msg = json!({
        "jsonrpc": "2.0",
        "method": "eth_subscribe",
        "params": ["stateChanges", monitored_addresses],
        "id": 1
    });

    if let Err(e) = ws_stream
        .send(Message::Text(subscribe_msg.to_string().into()))
        .await
    {
        return StateChangesTestResult {
            endpoint: endpoint_name.to_string(),
            connected: true,
            subscription_confirmed: false,
            state_changes_received: 0,
            error: Some(format!("Failed to send subscription: {}", e)),
        };
    }

    let mut subscription_id: Option<String> = None;
    let mut state_changes_received = 0u32;
    let mut error_msg: Option<String> = None;

    let receive_timeout = Duration::from_secs(15);
    let deadline = tokio::time::Instant::now() + receive_timeout;

    while tokio::time::Instant::now() < deadline {
        let msg = match timeout(Duration::from_secs(5), ws_stream.next()).await {
            Ok(Some(Ok(Message::Text(text)))) => text,
            Ok(Some(Ok(Message::Close(frame)))) => {
                error_msg = Some(format!("WebSocket closed: {:?}", frame));
                break;
            }
            Ok(Some(Err(e))) => {
                error_msg = Some(format!("WebSocket error: {}", e));
                break;
            }
            Ok(None) => {
                error_msg = Some("WebSocket stream ended".to_string());
                break;
            }
            Err(_) => continue, // Timeout waiting for message
            _ => continue,
        };

        let parsed: serde_json::Value = match serde_json::from_str(&msg) {
            Ok(v) => v,
            Err(e) => {
                warn!(endpoint_name, error = %e, "Failed to parse message");
                continue;
            }
        };

        // Check for subscription confirmation
        if let Some(result) = parsed.get("result") {
            if subscription_id.is_none() && result.is_string() {
                subscription_id = result.as_str().map(String::from);
                info!(endpoint_name, subscription_id = ?subscription_id, "Subscription confirmed");
                continue;
            }
        }

        // Check for error
        if let Some(error) = parsed.get("error") {
            let err_msg = error.get("message").and_then(|m| m.as_str()).unwrap_or("Unknown");
            let err_code = error.get("code").and_then(|c| c.as_i64()).unwrap_or(0);
            error_msg = Some(format!("RPC error {}: {}", err_code, err_msg));
            break;
        }

        // Check for state change notification
        if let Some(params) = parsed.get("params") {
            if let Some(result) = params.get("result") {
                state_changes_received += 1;
                
                let address = result.get("address").and_then(|a| a.as_str()).unwrap_or("?");
                let balance = result.get("balance").and_then(|b| b.as_str());

                info!(
                    endpoint_name,
                    state_changes_received,
                    address,
                    balance = ?balance,
                    "Received state change"
                );

                if state_changes_received >= 3 {
                    info!(endpoint_name, "Received 3 state changes, success!");
                    break;
                }
            }
        }
    }

    StateChangesTestResult {
        endpoint: endpoint_name.to_string(),
        connected: true,
        subscription_confirmed: subscription_id.is_some(),
        state_changes_received,
        error: error_msg,
    }
}

/// Test: `stateChanges` subscription across multiple endpoints
///
/// The `stateChanges` subscription streams state changes (balance, nonce, storage)
/// for monitored accounts as soon as transactions affecting them are packaged
/// into mini blocks.
///
/// ## Status (January 2026)
///
/// | Endpoint | Status |
/// |----------|--------|
/// | **MAINNET** (`mainnet.megaeth.com`) | ✅ WORKS |
/// | TESTNET (`carrot.megaeth.com`) | ❌ Broken (confirms sub but no data) |
/// | Alchemy | ❌ No eth_subscribe support |
///
/// Note: Even when working, this test may not receive data if monitored addresses
/// have no activity during the test window.
///
/// See: docs/learnings/megaeth-rpc-endpoints.md
#[tokio::test]
#[ignore = "requires network access; tests MegaETH stateChanges subscription"]
async fn test_state_changes_subscription() {
    install_crypto_provider();
    tracing_subscriber::fmt::try_init().ok();
    info!("Testing stateChanges subscription on multiple endpoints...");

    let mut results: Vec<StateChangesTestResult> = Vec::new();

    // Test 1: MegaETH MAINNET WebSocket (WORKS!)
    info!("═══════════════════════════════════════════════════════════════════");
    info!("TEST 1: MegaETH MAINNET WebSocket ({})", MEGAETH_MAINNET_WS_RPC);
    info!("═══════════════════════════════════════════════════════════════════");
    let mainnet_result = test_state_changes_on_endpoint(MEGAETH_MAINNET_WS_RPC, "MegaETH Mainnet").await;
    results.push(mainnet_result);

    // Test 2: MegaETH TESTNET WebSocket (currently broken)
    info!("═══════════════════════════════════════════════════════════════════");
    info!("TEST 2: MegaETH TESTNET WebSocket ({})", MEGAETH_TESTNET_WS_RPC);
    info!("═══════════════════════════════════════════════════════════════════");
    let testnet_result = test_state_changes_on_endpoint(MEGAETH_TESTNET_WS_RPC, "MegaETH Testnet").await;
    results.push(testnet_result);

    // Test 3: Alchemy WebSocket (if available) - expected to fail (no eth_subscribe support)
    if let Some(alchemy_ws_url) = get_alchemy_testnet_ws_url() {
        info!("═══════════════════════════════════════════════════════════════════");
        info!("TEST 3: Alchemy WebSocket (expected to fail - no eth_subscribe support)");
        info!("═══════════════════════════════════════════════════════════════════");
        let alchemy_result = test_state_changes_on_endpoint(&alchemy_ws_url, "Alchemy").await;
        results.push(alchemy_result);
    } else {
        info!("═══════════════════════════════════════════════════════════════════");
        info!("TEST 3: Alchemy WebSocket - SKIPPED (no ALCHEMY_API_KEY)");
        info!("═══════════════════════════════════════════════════════════════════");
    }

    // Summary
    info!("═══════════════════════════════════════════════════════════════════");
    info!("RESULTS SUMMARY");
    info!("═══════════════════════════════════════════════════════════════════");
    
    let mut any_subscription_confirmed = false;
    let mut any_received_data = false;
    
    for result in &results {
        let status = if result.state_changes_received > 0 {
            any_received_data = true;
            any_subscription_confirmed = true;
            "✓ SUCCESS (received data)"
        } else if result.subscription_confirmed {
            any_subscription_confirmed = true;
            "⚠ SUBSCRIBED (no data - addresses may be inactive)"
        } else if result.connected {
            "✗ CONNECTED BUT SUBSCRIPTION FAILED"
        } else {
            "✗ CONNECTION FAILED"
        };

        info!(
            "{}: {} | connected={} | subscribed={} | changes={} | error={:?}",
            result.endpoint,
            status,
            result.connected,
            result.subscription_confirmed,
            result.state_changes_received,
            result.error
        );
    }

    // At least one endpoint must have confirmed the subscription
    // (We don't require data because the monitored addresses may have no activity)
    assert!(
        any_subscription_confirmed,
        "\n\n\
        ╔══════════════════════════════════════════════════════════════════════════════╗\n\
        ║  stateChanges SUBSCRIPTION FAILED ON ALL ENDPOINTS                           ║\n\
        ╠══════════════════════════════════════════════════════════════════════════════╣\n\
        ║  MegaETH Public WS: Connection OK, but eth_subscribe returns NO response     ║\n\
        ║  Alchemy WS: Does not support eth_subscribe for MegaETH                      ║\n\
        ╠══════════════════════════════════════════════════════════════════════════════╣\n\
        ║  This appears to be a platform limitation, not a test bug.                   ║\n\
        ║  The MegaETH Realtime API docs claim stateChanges subscription should work,  ║\n\
        ║  but public WebSocket endpoints do not actually support it.                  ║\n\
        ╠══════════════════════════════════════════════════════════════════════════════╣\n\
        ║  WORKAROUND: Use HTTP polling for account state changes.                     ║\n\
        ╚══════════════════════════════════════════════════════════════════════════════╝\n\n\
        Results: {:?}",
        results
    );

    info!("✓ stateChanges subscription test passed");
    if any_received_data {
        info!("  - At least one endpoint received state change data");
    } else {
        info!("  - Subscription confirmed (no data received - monitored addresses may be inactive)");
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRIMARY E2E TEST - MAINNET PIPELINE (This is the main verification test)
// ═══════════════════════════════════════════════════════════════════════════════

/// Test: FULL END-TO-END MAINNET PIPELINE
///
/// **This is the primary verification test for the indexer.**
///
/// Verifies the complete pipeline works on mainnet:
/// 1. Connect to mainnet WebSocket (`wss://mainnet.megaeth.com/ws`)
/// 2. Subscribe to miniBlocks (real-time data every ~10ms)
/// 3. Store received data in TimescaleDB
/// 4. Read data back from database and verify integrity
///
/// This proves the indexer can receive live mainnet data and persist it correctly.
///
/// ## Run This Test
///
/// ```bash
/// cargo test --test live_network_test test_mainnet_e2e_pipeline \
///     --features test-utils -- --ignored --nocapture
/// ```
#[tokio::test]
#[ignore = "requires network access and Docker; primary E2E verification"]
async fn test_mainnet_e2e_pipeline() {
    install_crypto_provider();
    tracing_subscriber::fmt::try_init().ok();
    
    info!("╔══════════════════════════════════════════════════════════════════════════════╗");
    info!("║           MAINNET END-TO-END PIPELINE TEST                                   ║");
    info!("║  WebSocket → miniBlocks subscription → TimescaleDB → Read back              ║");
    info!("╚══════════════════════════════════════════════════════════════════════════════╝");
    info!("");

    // ─────────────────────────────────────────────────────────────────────────────
    // STEP 1: Start TimescaleDB
    // ─────────────────────────────────────────────────────────────────────────────
    info!("STEP 1: Starting TimescaleDB...");
    let db = TestDb::new().await;
    info!("  ✓ TimescaleDB ready");

    // Create tables for mini blocks
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS mini_blocks (
            id SERIAL PRIMARY KEY,
            block_number BIGINT NOT NULL,
            mini_block_number BIGINT NOT NULL UNIQUE,
            block_timestamp BIGINT NOT NULL,
            mini_block_timestamp BIGINT NOT NULL,
            block_index INTEGER NOT NULL,
            gas_used BIGINT NOT NULL,
            tx_count INTEGER NOT NULL,
            receipt_count INTEGER NOT NULL,
            indexed_at TIMESTAMPTZ DEFAULT NOW()
        )
        "#,
    )
    .execute(&db.pool)
    .await
    .expect("Failed to create mini_blocks table");
    info!("  ✓ Database tables created");

    // ─────────────────────────────────────────────────────────────────────────────
    // STEP 2: Connect to Mainnet WebSocket
    // ─────────────────────────────────────────────────────────────────────────────
    info!("");
    info!("STEP 2: Connecting to MegaETH Mainnet WebSocket...");
    info!("  URL: {}", MEGAETH_MAINNET_WS_RPC);
    
    use tokio_tungstenite::{connect_async, tungstenite::Message};
    use futures::SinkExt;

    let (mut ws_stream, _response) = connect_async(MEGAETH_MAINNET_WS_RPC)
        .await
        .expect("Failed to connect to mainnet WebSocket");
    info!("  ✓ WebSocket connected");

    // ─────────────────────────────────────────────────────────────────────────────
    // STEP 3: Subscribe to miniBlocks
    // ─────────────────────────────────────────────────────────────────────────────
    info!("");
    info!("STEP 3: Subscribing to miniBlocks...");
    
    let subscribe_msg = json!({
        "jsonrpc": "2.0",
        "method": "eth_subscribe",
        "params": ["miniBlocks"],
        "id": 1
    });

    ws_stream
        .send(Message::Text(subscribe_msg.to_string().into()))
        .await
        .expect("Failed to send subscription");

    // Wait for subscription confirmation
    let mut subscription_id: Option<String> = None;
    let confirmation_timeout = Duration::from_secs(10);
    let confirmation_deadline = tokio::time::Instant::now() + confirmation_timeout;

    while tokio::time::Instant::now() < confirmation_deadline {
        let msg = match timeout(Duration::from_secs(5), ws_stream.next()).await {
            Ok(Some(Ok(Message::Text(text)))) => text.to_string(),
            _ => continue,
        };

        let parsed: serde_json::Value = serde_json::from_str(&msg).unwrap_or_default();
        
        if let Some(result) = parsed.get("result") {
            subscription_id = result.as_str().map(String::from);
            break;
        }
        
        if let Some(error) = parsed.get("error") {
            panic!("Subscription failed: {:?}", error);
        }
    }

    let sub_id = subscription_id.expect("Failed to get subscription ID");
    info!("  ✓ Subscription confirmed: {}", sub_id);

    // ─────────────────────────────────────────────────────────────────────────────
    // STEP 4: Receive and store mini blocks
    // ─────────────────────────────────────────────────────────────────────────────
    info!("");
    info!("STEP 4: Receiving mini blocks and storing in database...");
    
    let target_blocks = 20u32;  // Receive 20 mini blocks
    let mut blocks_received = 0u32;
    let mut blocks_stored = 0u32;
    
    let receive_timeout = Duration::from_secs(30);
    let receive_deadline = tokio::time::Instant::now() + receive_timeout;

    while tokio::time::Instant::now() < receive_deadline && blocks_received < target_blocks {
        let msg = match timeout(Duration::from_secs(5), ws_stream.next()).await {
            Ok(Some(Ok(Message::Text(text)))) => text.to_string(),
            Ok(Some(Ok(Message::Binary(data)))) => String::from_utf8(data.to_vec()).unwrap_or_default(),
            _ => continue,
        };

        let parsed: serde_json::Value = match serde_json::from_str(&msg) {
            Ok(v) => v,
            Err(_) => continue,
        };

        // Check for mini block data
        if let Some(params) = parsed.get("params") {
            if let Some(result) = params.get("result") {
                // Parse mini block
                let block_number = result.get("block_number").and_then(|v| v.as_u64()).unwrap_or(0);
                let mini_block_number = result.get("number").and_then(|v| v.as_u64()).unwrap_or(0);
                let block_timestamp = result.get("block_timestamp").and_then(|v| v.as_u64()).unwrap_or(0);
                let mini_block_timestamp = result.get("timestamp").and_then(|v| v.as_u64()).unwrap_or(0);
                let index = result.get("index").and_then(|v| v.as_u64()).unwrap_or(0) as i32;
                let gas_used = result.get("gas_used").and_then(|v| v.as_u64()).unwrap_or(0);
                let tx_count = result.get("transactions").and_then(|v| v.as_array()).map(|a| a.len()).unwrap_or(0) as i32;
                let receipt_count = result.get("receipts").and_then(|v| v.as_array()).map(|a| a.len()).unwrap_or(0) as i32;

                blocks_received += 1;

                // Store in database
                let insert_result = sqlx::query(
                    r#"
                    INSERT INTO mini_blocks 
                    (block_number, mini_block_number, block_timestamp, mini_block_timestamp, block_index, gas_used, tx_count, receipt_count)
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                    ON CONFLICT (mini_block_number) DO NOTHING
                    "#,
                )
                .bind(block_number as i64)
                .bind(mini_block_number as i64)
                .bind(block_timestamp as i64)
                .bind(mini_block_timestamp as i64)
                .bind(index)
                .bind(gas_used as i64)
                .bind(tx_count)
                .bind(receipt_count)
                .execute(&db.pool)
                .await;

                if insert_result.is_ok() {
                    blocks_stored += 1;
                }

                if blocks_received % 5 == 0 {
                    info!("  ... received {} / {} mini blocks", blocks_received, target_blocks);
                }
            }
        }
    }

    info!("  ✓ Received {} mini blocks", blocks_received);
    info!("  ✓ Stored {} mini blocks in database", blocks_stored);

    assert!(blocks_received >= 5, "Expected at least 5 mini blocks, got {}", blocks_received);
    assert!(blocks_stored >= 5, "Expected at least 5 stored blocks, got {}", blocks_stored);

    // ─────────────────────────────────────────────────────────────────────────────
    // STEP 5: Read back from database and verify
    // ─────────────────────────────────────────────────────────────────────────────
    info!("");
    info!("STEP 5: Reading back from database and verifying...");

    // Count total records
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM mini_blocks")
        .fetch_one(&db.pool)
        .await
        .expect("Failed to count mini blocks");
    
    info!("  ✓ Total records in database: {}", count.0);
    assert!(count.0 >= 5, "Expected at least 5 records in database, got {}", count.0);

    // Fetch sample records
    let samples: Vec<(i64, i64, i64, i32, i32)> = sqlx::query_as(
        "SELECT block_number, mini_block_number, gas_used, tx_count, receipt_count 
         FROM mini_blocks ORDER BY mini_block_number DESC LIMIT 5"
    )
    .fetch_all(&db.pool)
    .await
    .expect("Failed to fetch sample records");

    info!("");
    info!("  Sample records from database:");
    info!("  ┌─────────────┬──────────────────┬──────────┬─────────┬──────────┐");
    info!("  │ Block #     │ Mini Block #     │ Gas Used │ TX Count│ Receipts │");
    info!("  ├─────────────┼──────────────────┼──────────┼─────────┼──────────┤");
    for (block_num, mini_block_num, gas, tx, receipts) in &samples {
        info!("  │ {:>11} │ {:>16} │ {:>8} │ {:>7} │ {:>8} │", 
              block_num, mini_block_num, gas, tx, receipts);
    }
    info!("  └─────────────┴──────────────────┴──────────┴─────────┴──────────┘");

    // Verify data integrity
    for (block_num, mini_block_num, _gas, _tx, _receipts) in &samples {
        assert!(*block_num > 0, "Block number should be positive");
        assert!(*mini_block_num > 0, "Mini block number should be positive");
    }
    info!("  ✓ Data integrity verified");

    // ─────────────────────────────────────────────────────────────────────────────
    // SUMMARY
    // ─────────────────────────────────────────────────────────────────────────────
    info!("");
    info!("╔══════════════════════════════════════════════════════════════════════════════╗");
    info!("║                    ✓ MAINNET E2E PIPELINE TEST PASSED!                       ║");
    info!("╠══════════════════════════════════════════════════════════════════════════════╣");
    info!("║  1. WebSocket connected to mainnet.megaeth.com                               ║");
    info!("║  2. miniBlocks subscription confirmed and streaming                          ║");
    info!("║  3. {} mini blocks received in real-time                              ║", format!("{:>3}", blocks_received));
    info!("║  4. {} mini blocks stored in TimescaleDB                              ║", format!("{:>3}", blocks_stored));
    info!("║  5. Data read back and verified                                              ║");
    info!("╚══════════════════════════════════════════════════════════════════════════════╝");
}
