//! Domain types for the GHOSTNET Event Indexer.
//!
//! This module contains all the core types used throughout the indexer:
//!
//! - [`enums`] - Game enumerations (`Level`, `BoostType`, `RoundType`, `ExitReason`)
//! - [`primitives`] - Validated newtypes (`EthAddress`, `TokenAmount`, `GhostStreak`, `BlockNumber`)
//! - [`events`] - Strongly-typed event structures from smart contracts
//! - [`entities`] - Domain entities for database persistence

pub mod entities;
pub mod enums;
pub mod events;
pub mod primitives;

// Re-export commonly used types at module level
pub use entities::{
    Bet, Boost, Death, GlobalStats, LeaderboardEntry, LevelStats, LevelStatsDelta, Position,
    PositionAction, PositionHistoryEntry, Round, Scan, ScanFinalizationData,
};
pub use enums::{BoostType, ExitReason, Level, RoundType};
pub use events::{EventMetadata, GhostnetEvent};
pub use primitives::{BlockNumber, EthAddress, GhostStreak, TokenAmount};
