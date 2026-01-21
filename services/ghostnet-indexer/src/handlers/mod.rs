//! Event handler ports for GHOSTNET contracts.
//!
//! This module defines trait-based ports (interfaces) for handling events
//! from each contract. Following hexagonal architecture, these traits allow:
//!
//! - **Testability**: Mock implementations for unit testing
//! - **Flexibility**: Swap implementations without changing routing logic
//! - **Separation of Concerns**: Each handler focuses on one domain area
//!
//! # Handler Ports
//!
//! | Port | Contract | Events |
//! |------|----------|--------|
//! | [`PositionPort`] | `GhostCore` | Position lifecycle (jack in, add, extract, cull) |
//! | [`ScanPort`] | `TraceScan` | Scan execution and finalization |
//! | [`DeathPort`] | `GhostCore` | Death processing, survivors, cascades |
//! | [`MarketPort`] | `DeadPool` | Betting rounds and claims |
//! | [`TokenPort`] | `DataToken` | ERC20 transfers and tax events |
//! | [`FeePort`] | `FeeRouter` | Fee collection and buybacks |
//! | [`EmissionsPort`] | `RewardsDistributor` | Emissions and vesting |
//!
//! # Usage
//!
//! ```ignore
//! use ghostnet_indexer::handlers::{PositionPort, ScanPort};
//!
//! // Implement the port trait
//! struct MyPositionHandler { /* ... */ }
//!
//! #[async_trait]
//! impl PositionPort for MyPositionHandler {
//!     async fn handle_jacked_in(&self, event: JackedIn, meta: EventMetadata) -> Result<()> {
//!         // Handle the event...
//!         Ok(())
//!     }
//!     // ... other methods
//! }
//! ```

mod traits;

pub use traits::{
    DeathPort, EmissionsPort, FeePort, MarketPort, PositionPort, ScanPort, TokenPort,
};

#[cfg(test)]
pub use traits::mocks;
