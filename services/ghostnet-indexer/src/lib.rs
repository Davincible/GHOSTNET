//! GHOSTNET Event Indexer
//!
//! A high-performance Rust-based backend service that indexes blockchain events
//! from the GHOSTNET protocol on `MegaETH`, persists them to `TimescaleDB`, streams
//! them via Apache Iggy, and exposes REST/WebSocket APIs.
//!
//! # Architecture
//!
//! The indexer follows a hexagonal architecture:
//!
//! ```text
//! ┌─────────────────────────────────────────────────────────────────┐
//! │                         INDEXER CORE                            │
//! │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
//! │  │    Block     │  │     Log      │  │    Event     │          │
//! │  │  Processor   │─▶│   Decoder    │─▶│   Router     │          │
//! │  └──────────────┘  └──────────────┘  └──────────────┘          │
//! │                                              │                  │
//! │              ┌───────────────────────────────┼──────────────┐  │
//! │              ▼                               ▼              ▼  │
//! │       ┌──────────────┐              ┌──────────────┐   ┌─────┐ │
//! │       │   Handlers   │              │    Store     │   │Cache│ │
//! │       └──────────────┘              └──────────────┘   └─────┘ │
//! └─────────────────────────────────────────────────────────────────┘
//! ```
//!
//! # Modules
//!
//! - [`types`] - Domain types (enums, events, entities, primitives)
//! - [`error`] - Layered error types
//! - [`config`] - Configuration loading and validation
//! - [`abi`] - ABI bindings for GHOSTNET contracts
//! - [`indexer`] - Core indexing logic (block processor, event router)
//! - [`handlers`] - Event handlers for each contract
//! - [`store`] - Data persistence (`PostgreSQL`, cache)
//! - [`streaming`] - Apache Iggy integration
//! - [`api`] - REST and WebSocket API
//!
//! # Getting Started
//!
//! ```bash
//! # Set up environment
//! cp .env.example .env
//! # Edit .env with your configuration
//!
//! # Run migrations
//! sqlx migrate run
//!
//! # Start the indexer
//! cargo run -- run
//! ```

#![doc(html_root_url = "https://docs.ghostnet.io/indexer")]

// Module declarations - added as each phase completes
pub mod abi;
pub mod config;
pub mod error;
pub mod handlers;
pub mod indexer;
pub mod ports;
pub mod store;
pub mod types;

// Future modules (uncomment as implemented):
// pub mod api;
// pub mod streaming;

/// Library version
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Returns the library version string
#[must_use]
pub const fn version() -> &'static str {
    VERSION
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version() {
        assert!(!version().is_empty());
        assert!(version().starts_with("0."));
    }
}
