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
//! # Handler Implementations
//!
//! | Handler | Port | Status |
//! |---------|------|--------|
//! | [`PositionHandler`] | [`PositionPort`] | Complete |
//! | [`ScanHandler`] | [`ScanPort`] | Complete |
//! | [`DeathHandler`] | [`DeathPort`] | Complete |
//! | [`MarketHandler`] | [`MarketPort`] | Complete |
//! | [`TokenHandler`] | [`TokenPort`] | Complete |
//! | [`FeeHandler`] | [`FeePort`] | Complete |
//! | [`EmissionsHandler`] | [`EmissionsPort`] | Complete |
//!
//! # Usage
//!
//! ```ignore
//! use ghostnet_indexer::handlers::{
//!     PositionPort, ScanPort, DeathPort, MarketPort, TokenPort, FeePort, EmissionsPort
//! };
//! use ghostnet_indexer::handlers::{
//!     PositionHandler, ScanHandler, DeathHandler, MarketHandler,
//!     TokenHandler, FeeHandler, EmissionsHandler
//! };
//!
//! // Create handlers with store and cache dependencies
//! let position_handler = PositionHandler::new(position_store, cache);
//! let scan_handler = ScanHandler::new(scan_store, cache);
//! let death_handler = DeathHandler::new(death_store, position_store, cache);
//! let market_handler = MarketHandler::new(market_store, cache);
//! let token_handler = TokenHandler::new(cache);
//! let fee_handler = FeeHandler::new(cache);
//! let emissions_handler = EmissionsHandler::new(cache);
//! ```

mod death_handler;
mod emissions_handler;
mod fee_handler;
mod market_handler;
mod position_handler;
mod scan_handler;
mod token_handler;
mod traits;

pub use death_handler::DeathHandler;
pub use emissions_handler::EmissionsHandler;
pub use fee_handler::FeeHandler;
pub use market_handler::MarketHandler;
pub use position_handler::PositionHandler;
pub use scan_handler::ScanHandler;
pub use token_handler::TokenHandler;
pub use traits::{
    DeathPort, EmissionsPort, FeePort, MarketPort, PositionPort, ScanPort, TokenPort,
};

#[cfg(test)]
pub use traits::mocks;
