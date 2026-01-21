//! Core indexing logic for GHOSTNET events.
//!
//! This module contains the components that:
//! 1. Receive raw blockchain logs
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
//! # Usage
//!
//! ```ignore
//! use ghostnet_indexer::indexer::EventRouter;
//! use ghostnet_indexer::handlers::*;
//!
//! // Create handlers
//! let position_handler = MyPositionHandler::new();
//! let scan_handler = MyScanHandler::new();
//! // ... other handlers
//!
//! // Create router
//! let router = EventRouter::new(
//!     position_handler,
//!     scan_handler,
//!     death_handler,
//!     market_handler,
//!     token_handler,
//!     fee_handler,
//!     emissions_handler,
//! );
//!
//! // Route a log
//! router.route_log(&log, metadata).await?;
//! ```

mod event_router;

pub use event_router::EventRouter;
