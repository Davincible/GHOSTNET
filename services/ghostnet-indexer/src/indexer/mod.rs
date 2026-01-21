//! Core indexing logic for GHOSTNET events.
//!
//! This module contains the components that:
//! 1. Receive raw blockchain logs (HTTP polling or WebSocket)
//! 2. Decode them into typed events using ABI bindings
//! 3. Route events to appropriate handlers
//!
//! # Architecture
//!
//! ```text
//! ┌─────────────────────────────────────────────────────────────────┐
//! │                        Indexer Core                             │
//! │                                                                 │
//! │  ┌──────────────────┐     ┌──────────────────┐                 │
//! │  │   Raw Log        │────▶│   EventRouter    │                 │
//! │  │   (from RPC)     │     │   (decode+route) │                 │
//! │  └──────────────────┘     └────────┬─────────┘                 │
//! │                                     │                           │
//! │         ┌───────────────────────────┼───────────────────────┐  │
//! │         │                           │                       │  │
//! │         ▼                           ▼                       ▼  │
//! │  ┌─────────────┐           ┌─────────────┐           ┌──────┐ │
//! │  │ PositionPort│           │  ScanPort   │           │ ...  │ │
//! │  └─────────────┘           └─────────────┘           └──────┘ │
//! └─────────────────────────────────────────────────────────────────┘
//! ```
//!
//! # Ingestion Modes
//!
//! | Mode | Use Case | Latency | Component |
//! |------|----------|---------|-----------|
//! | **HTTP Polling** | Historical backfill | ~1s | [`BlockProcessor`] |
//! | **WebSocket** | Real-time streaming | ~10ms | [`RealtimeProcessor`] |
//!
//! ## MegaETH Realtime API
//!
//! MegaETH executes transactions within 10ms and exposes results via their
//! Realtime API. The [`RealtimeProcessor`] uses WebSocket subscriptions with
//! `fromBlock: "pending"` and `toBlock: "pending"` to receive logs from
//! mini-blocks immediately after execution.
//!
//! Key differences from standard Ethereum:
//! - Mini-blocks are produced every ~10ms (vs 1s+ EVM blocks)
//! - Logs are visible immediately after transaction execution
//! - Requires keep-alive pings every 30 seconds
//!
//! # Usage
//!
//! ```ignore
//! use ghostnet_indexer::indexer::{BlockProcessor, RealtimeProcessor, EventRouter};
//!
//! // For historical backfill (HTTP)
//! let block_processor = BlockProcessor::new(http_provider, contracts, log_tx)?;
//! block_processor.backfill(from_block, to_block).await?;
//!
//! // For real-time indexing (WebSocket)
//! let realtime_processor = RealtimeProcessor::new(ws_url, contracts, log_tx)?;
//! realtime_processor.start().await?; // Runs until shutdown
//! ```

mod block_processor;
mod event_router;
mod realtime_processor;

pub use block_processor::BlockProcessor;
pub use event_router::EventRouter;
pub use realtime_processor::RealtimeProcessor;
