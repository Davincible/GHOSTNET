//! Data persistence layer (adapters for store ports).
//!
//! This module provides concrete implementations of the store ports
//! defined in [`crate::ports::store`]. The primary implementation uses
//! `PostgreSQL` with `TimescaleDB` extensions for time-series data.
//!
//! # Architecture
//!
//! ```text
//! ┌─────────────────────────────────────────────────────────────────┐
//! │                        Store Adapters                            │
//! │                                                                 │
//! │   ┌──────────────────────────────────────────────────────────┐  │
//! │   │                  PostgresStore                            │  │
//! │   │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │  │
//! │   │   │  Positions   │  │    Scans     │  │   Deaths     │   │  │
//! │   │   └──────────────┘  └──────────────┘  └──────────────┘   │  │
//! │   │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │  │
//! │   │   │   Market     │  │    Stats     │  │ IndexerState │   │  │
//! │   │   └──────────────┘  └──────────────┘  └──────────────┘   │  │
//! │   └──────────────────────────────────────────────────────────┘  │
//! │                               │                                  │
//! │                               ▼                                  │
//! │   ┌──────────────────────────────────────────────────────────┐  │
//! │   │              SQLx Connection Pool                         │  │
//! │   │         (PostgreSQL + TimescaleDB)                        │  │
//! │   └──────────────────────────────────────────────────────────┘  │
//! └─────────────────────────────────────────────────────────────────┘
//! ```
//!
//! # TimescaleDB Hypertables
//!
//! We use TimescaleDB hypertables for time-series data:
//!
//! | Table | Partition Column | Chunk Interval |
//! |-------|------------------|----------------|
//! | `positions` | `created_at` | 1 day |
//! | `position_history` | `timestamp` | 1 day |
//! | `scans` | `executed_at` | 1 day |
//! | `deaths` | `created_at` | 1 day |
//!
//! # Usage
//!
//! ```ignore
//! use ghostnet_indexer::store::PostgresStore;
//! use sqlx::postgres::PgPoolOptions;
//!
//! let pool = PgPoolOptions::new()
//!     .max_connections(10)
//!     .connect("postgres://localhost/ghostnet")
//!     .await?;
//!
//! // Run migrations
//! sqlx::migrate!("./migrations").run(&pool).await?;
//!
//! // Create store
//! let store = PostgresStore::new(pool);
//!
//! // Use via trait methods
//! let position = store.get_active_position(&address).await?;
//! ```
//!
//! # Migrations
//!
//! Migrations are located in `migrations/` and run via `sqlx migrate run`.
//! See individual migration files for schema details.

mod postgres;

pub use postgres::PostgresStore;

// Re-export commonly used types for convenience
pub use sqlx::postgres::PgPool;
