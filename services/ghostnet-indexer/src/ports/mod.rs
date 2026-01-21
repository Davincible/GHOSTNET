//! Port definitions for dependency injection and testability.
//!
//! Ports are trait definitions that describe what the domain layer needs.
//! Following hexagonal architecture, adapters (in the infrastructure layer)
//! implement these traits to provide concrete functionality.
//!
//! # Architecture
//!
//! ```text
//! ┌─────────────────────────────────────────────────────────────────┐
//! │                         Domain Layer                            │
//! │                                                                 │
//! │  Uses ports (traits) to define what it needs                   │
//! │                                                                 │
//! │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
//! │  │PositionStore│  │  ScanStore  │  │ DeathStore  │            │
//! │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘            │
//! │         │                │                │                    │
//! └─────────┼────────────────┼────────────────┼────────────────────┘
//!           │                │                │
//!           ▼                ▼                ▼
//! ┌─────────────────────────────────────────────────────────────────┐
//! │                     Infrastructure Layer                        │
//! │                                                                 │
//! │  Provides adapters (implementations) for ports                 │
//! │                                                                 │
//! │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
//! │  │PostgresStore│  │ PostgresStore│  │PostgresStore│            │
//! │  │(implements  │  │(implements  │  │(implements  │            │
//! │  │PositionStore)│  │ ScanStore)  │  │ DeathStore) │            │
//! │  └─────────────┘  └─────────────┘  └─────────────┘            │
//! └─────────────────────────────────────────────────────────────────┘
//! ```
//!
//! # Port Categories
//!
//! | Category | Ports | Purpose |
//! |----------|-------|---------|
//! | Storage | [`PositionStore`], [`ScanStore`], [`DeathStore`], [`MarketStore`], [`IndexerStateStore`], [`StatsStore`] | Data persistence |
//! | Streaming | [`EventPublisher`] | Event broadcasting |
//! | Caching | [`Cache`] | In-memory caching |
//! | Time | [`Clock`] | Testable time operations |
//!
//! # Usage
//!
//! ```ignore
//! use ghostnet_indexer::ports::{PositionStore, Clock, SystemClock};
//!
//! // Application code depends on traits, not implementations
//! async fn process_position<S: PositionStore, C: Clock>(
//!     store: &S,
//!     clock: &C,
//!     address: &EthAddress,
//! ) -> Result<()> {
//!     let position = store.get_active_position(address).await?;
//!     let now = clock.now();
//!     // ...
//!     Ok(())
//! }
//!
//! // In production, use real implementations
//! let store = PostgresPositionStore::new(pool);
//! let clock = SystemClock;
//!
//! // In tests, use mocks
//! let store = MockPositionStore::new();
//! let clock = FakeClock::new(fixed_time);
//! ```

mod cache;
mod clock;
mod store;
mod streaming;

// Re-export all port traits
pub use cache::Cache;
pub use clock::{Clock, SystemClock};
pub use store::{
    DeathStore, IndexerStateStore, MarketStore, PositionStore, ScanStore, StatsStore,
};
pub use streaming::EventPublisher;

// Re-export test utilities for tests and downstream crates using test-utils feature
#[cfg(any(test, feature = "test-utils"))]
pub use clock::FakeClock;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_ports_are_send_sync() {
        // Compile-time check that all port traits require Send + Sync
        fn assert_send_sync<T: Send + Sync>() {}

        // These would fail to compile if traits don't require Send + Sync
        fn check_position_store<T: PositionStore>() {
            assert_send_sync::<T>();
        }
        fn check_scan_store<T: ScanStore>() {
            assert_send_sync::<T>();
        }
        fn check_death_store<T: DeathStore>() {
            assert_send_sync::<T>();
        }
        fn check_market_store<T: MarketStore>() {
            assert_send_sync::<T>();
        }
        fn check_indexer_state_store<T: IndexerStateStore>() {
            assert_send_sync::<T>();
        }
        fn check_stats_store<T: StatsStore>() {
            assert_send_sync::<T>();
        }
        fn check_event_publisher<T: EventPublisher>() {
            assert_send_sync::<T>();
        }
        fn check_cache<T: Cache>() {
            assert_send_sync::<T>();
        }
        fn check_clock<T: Clock>() {
            assert_send_sync::<T>();
        }
    }
}
