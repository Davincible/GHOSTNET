//! MegaETH-specific JSON-RPC client with cursor pagination and realtime API support.
//!
//! This crate provides [`MegaEthClient`], a specialized RPC client for MegaETH's
//! extended JSON-RPC API. It handles the unique characteristics of MegaETH:
//!
//! - **High throughput**: MegaETH processes ~1000 TPS, generating massive data volumes
//! - **Cursor pagination**: `eth_getLogsWithCursor` for efficient large-range queries
//! - **Realtime API**: `realtime_sendRawTransaction` for instant receipts (~10ms)
//!
//! # Crate Relationships
//!
//! This is a **low-level crate** in the Ghost Fleet stack:
//!
//! ```text
//! ┌──────────────────────────────────────────────────────────┐
//! │  Application Layer (ghost-fleet, ghostnet-indexer)       │
//! └────────────────────────────┬─────────────────────────────┘
//!                              │
//!                              ▼
//! ┌──────────────────────────────────────────────────────────┐
//! │  Abstraction Layer (evm-provider)                        │
//! │  └─ MegaEthProvider wraps this crate                     │
//! └────────────────────────────┬─────────────────────────────┘
//!                              │
//!                              ▼
//! ┌──────────────────────────────────────────────────────────┐
//! │  RPC Layer (megaeth-rpc) ◄── YOU ARE HERE                │
//! │  └─ Direct MegaETH JSON-RPC access                       │
//! └──────────────────────────────────────────────────────────┘
//! ```
//!
//! **Use this crate directly when:**
//! - Building a custom indexer needing low-level cursor control
//! - Implementing a new provider in `evm-provider`
//! - You need direct RPC access without abstraction
//!
//! **Use `evm-provider` instead when:**
//! - Building application logic that should work on any EVM chain
//! - You want the `ChainProvider` trait for dependency injection
//! - You need automatic feature detection and safe defaults
//!
//! # Quick Start
//!
//! ```ignore
//! use megaeth_rpc::MegaEthClient;
//!
//! // Create client
//! let client = MegaEthClient::new("https://carrot.megaeth.com/rpc")?;
//!
//! // Fetch logs with automatic pagination
//! let (logs, stats) = client.get_logs_with_cursor(1000, 2000, None).await?;
//! println!("Fetched {} logs in {} batches", stats.total_logs, stats.batches);
//!
//! // Send transaction with instant receipt
//! let receipt = client.send_realtime_transaction(signed_tx_bytes).await?;
//! if receipt.is_success() {
//!     println!("Confirmed in block {}", receipt.block_number);
//! }
//! ```
//!
//! # Why This Crate?
//!
//! Standard Ethereum RPC clients don't handle MegaETH's data scale. At 1000 TPS,
//! MegaETH generates a year of Ethereum data every 5 days. Standard `eth_getLogs`
//! will timeout on large ranges.
//!
//! MegaETH's `eth_getLogsWithCursor` API solves this by:
//!
//! - Returning partial results when server limits are hit
//! - Providing a cursor to resume from where the query stopped
//! - Eliminating wasted computation on aborted queries
//!
//! This crate handles pagination automatically, making it easy to fetch arbitrarily
//! large log ranges.
//!
//! # Features
//!
//! - **Cursor-based pagination**: Automatic multi-batch fetching for large queries
//! - **Realtime transactions**: Submit and get receipt in ~10ms
//! - **Graceful fallback detection**: Check if extended APIs are available
//! - **Configurable**: Timeouts, batch limits, log limits, and more
//! - **Fully typed**: All requests and responses have proper Rust types
//!
//! # Memory Considerations
//!
//! When fetching logs with cursor pagination, all logs are accumulated in memory
//! before being returned. For very large queries, configure limits to prevent
//! memory exhaustion:
//!
//! ```
//! use megaeth_rpc::ClientConfig;
//!
//! let config = ClientConfig::default()
//!     .with_max_logs(100_000)        // Limit total logs collected
//!     .with_max_cursor_batches(50);  // Limit RPC round-trips
//! ```
//!
//! **Memory estimation:** Each log is approximately 200-500 bytes. 100,000 logs ≈ 20-50 MB.
//!
//! # Modules
//!
//! - [`client`] - The main [`MegaEthClient`] implementation
//! - [`config`] - Configuration options via [`ClientConfig`]
//! - [`types`] - Request/response types for MegaETH RPC methods
//! - [`error`] - Error types with detailed context
//!
//! # MegaETH-Specific APIs
//!
//! | Method | Description | Standard Equivalent |
//! |--------|-------------|---------------------|
//! | `eth_getLogsWithCursor` | Paginated log queries | `eth_getLogs` |
//! | `realtime_sendRawTransaction` | Instant receipts | `eth_sendRawTransaction` + polling |
//!
//! # Error Handling
//!
//! All operations return [`Result<T, MegaEthError>`](error::Result). Errors are
//! categorized for easy handling:
//!
//! ```ignore
//! match client.get_logs_with_cursor(0, 1000, None).await {
//!     Ok((logs, stats)) => { /* success */ }
//!     Err(e) if e.is_method_not_supported() => {
//!         // Fall back to standard eth_getLogs
//!     }
//!     Err(e) if e.is_retryable() => {
//!         // Retry after backoff
//!     }
//!     Err(e) => {
//!         // Handle other errors
//!     }
//! }
//! ```

#![doc(html_root_url = "https://docs.ghostnet.io/megaeth-rpc")]

// ═══════════════════════════════════════════════════════════════════════════════
// MODULES
// ═══════════════════════════════════════════════════════════════════════════════

pub mod client;
pub mod config;
pub mod error;
pub mod types;

// ═══════════════════════════════════════════════════════════════════════════════
// RE-EXPORTS
// ═══════════════════════════════════════════════════════════════════════════════

// Primary types - what most users need
pub use client::MegaEthClient;
pub use config::ClientConfig;
pub use error::{MegaEthError, Result};
pub use types::{FetchStats, LogsWithCursorFilter, LogsWithCursorResponse, RealtimeResponse};

// ═══════════════════════════════════════════════════════════════════════════════
// CRATE INFO
// ═══════════════════════════════════════════════════════════════════════════════

/// Crate version.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Returns the crate version string.
#[must_use]
pub const fn version() -> &'static str {
    VERSION
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_is_set() {
        assert!(!version().is_empty());
        assert!(version().starts_with("0."));
    }

    #[test]
    fn exports_are_available() {
        // Verify main types are exported
        let _: fn() -> Result<MegaEthClient> = || MegaEthClient::new("http://localhost");
        let _: ClientConfig = ClientConfig::default();
        let _: FetchStats = FetchStats::default();
    }
}
