//! Event streaming via Apache Iggy.
//!
//! This module provides real-time event broadcasting to clients via Apache Iggy,
//! a high-performance message streaming platform.
//!
//! # Architecture
//!
//! ```text
//! ┌─────────────────────────────────────────────────────────────────────────────┐
//! │                              Event Flow                                      │
//! │                                                                             │
//! │  ┌──────────────┐     ┌──────────────────┐     ┌──────────────────────────┐ │
//! │  │   Handlers   │────▶│  IggyPublisher   │────▶│     Apache Iggy          │ │
//! │  │  (events)    │     │  (serialize &    │     │  (stream + topics)       │ │
//! │  └──────────────┘     │   send)          │     └──────────────────────────┘ │
//! │                       └──────────────────┘                │                 │
//! │                                                           ▼                 │
//! │                                                  ┌─────────────────────┐    │
//! │                                                  │   WebSocket API     │    │
//! │                                                  │   (consumers)       │    │
//! │                                                  └─────────────────────┘    │
//! └─────────────────────────────────────────────────────────────────────────────┘
//! ```
//!
//! # Topics
//!
//! Events are organized into topics by domain:
//!
//! | Topic | Events | Use Case |
//! |-------|--------|----------|
//! | `positions` | JackedIn, StakeAdded, Extracted, PositionCulled, BoostApplied | Position updates |
//! | `scans` | ScanExecuted, ScanFinalized, DeathsSubmitted | Scan lifecycle |
//! | `deaths` | DeathsProcessed, SurvivorsUpdated, CascadeDistributed | Death events |
//! | `market` | RoundCreated, BetPlaced, RoundResolved, WinningsClaimed | DeadPool bets |
//! | `system` | SystemResetTriggered, EmissionsDistributed, WeightsUpdated, TokensClaimed | System events |
//! | `token` | Transfer, TaxBurned, TaxCollected, TaxExclusionSet | Token events |
//! | `fees` | TollCollected, BuybackExecuted, OperationsWithdrawn | Fee events |
//!
//! # Usage
//!
//! ```ignore
//! use ghostnet_indexer::streaming::IggyPublisher;
//! use ghostnet_indexer::config::IggySettings;
//!
//! // Create publisher from settings
//! let publisher = IggyPublisher::new(&settings.iggy)?;
//!
//! // Connect to Iggy server (or let it auto-connect on first publish)
//! publisher.connect().await?;
//!
//! // Publish events
//! publisher.publish(&event).await?;
//!
//! // Batch publish
//! publisher.publish_batch(&events).await?;
//! ```

mod iggy_publisher;
mod topics;

pub use iggy_publisher::{IggyPublisher, NoOpPublisher};
pub use topics::{Topic, TopicConfig, STREAM_NAME};
