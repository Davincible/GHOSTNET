//! Topic definitions for GHOSTNET event streaming.
//!
//! Events are organized into topics by domain to allow clients to subscribe
//! only to events they care about.

use crate::types::events::GhostnetEvent;

/// Default stream name for GHOSTNET events.
pub const STREAM_NAME: &str = "ghostnet";

/// Topic names for event categories.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Topic {
    /// Position lifecycle events: JackedIn, StakeAdded, Extracted, PositionCulled, BoostApplied
    Positions,
    /// Scan events: ScanExecuted, ScanFinalized, DeathsSubmitted
    Scans,
    /// Death and distribution events: DeathsProcessed, SurvivorsUpdated, CascadeDistributed
    Deaths,
    /// DeadPool betting: RoundCreated, BetPlaced, RoundResolved, WinningsClaimed
    Market,
    /// System-wide events: SystemResetTriggered, EmissionsDistributed, WeightsUpdated
    System,
    /// Token events: Transfer, TaxBurned, TaxCollected, TaxExclusionSet
    Token,
    /// Fee events: TollCollected, BuybackExecuted, OperationsWithdrawn
    Fees,
}

impl Topic {
    /// Get the topic name as used in Iggy.
    #[must_use]
    pub const fn as_str(&self) -> &'static str {
        match self {
            Self::Positions => "positions",
            Self::Scans => "scans",
            Self::Deaths => "deaths",
            Self::Market => "market",
            Self::System => "system",
            Self::Token => "token",
            Self::Fees => "fees",
        }
    }

    /// Get all topics for stream initialization.
    #[must_use]
    pub const fn all() -> &'static [Self] {
        &[
            Self::Positions,
            Self::Scans,
            Self::Deaths,
            Self::Market,
            Self::System,
            Self::Token,
            Self::Fees,
        ]
    }

    /// Determine the appropriate topic for an event.
    #[must_use]
    pub const fn for_event(event: &GhostnetEvent) -> Self {
        match event {
            // Position lifecycle
            GhostnetEvent::JackedIn(_)
            | GhostnetEvent::StakeAdded(_)
            | GhostnetEvent::Extracted(_)
            | GhostnetEvent::PositionCulled(_)
            | GhostnetEvent::BoostApplied(_) => Self::Positions,

            // Scan lifecycle
            GhostnetEvent::ScanExecuted(_)
            | GhostnetEvent::ScanFinalized(_)
            | GhostnetEvent::DeathsSubmitted(_) => Self::Scans,

            // Death and distribution
            GhostnetEvent::DeathsProcessed(_)
            | GhostnetEvent::SurvivorsUpdated(_)
            | GhostnetEvent::CascadeDistributed(_) => Self::Deaths,

            // DeadPool market
            GhostnetEvent::RoundCreated(_)
            | GhostnetEvent::BetPlaced(_)
            | GhostnetEvent::RoundResolved(_)
            | GhostnetEvent::WinningsClaimed(_) => Self::Market,

            // System events
            GhostnetEvent::SystemResetTriggered(_)
            | GhostnetEvent::EmissionsDistributed(_)
            | GhostnetEvent::EmissionsAdded(_)
            | GhostnetEvent::WeightsUpdated(_)
            | GhostnetEvent::TokensClaimed(_) => Self::System,

            // Token events
            GhostnetEvent::Transfer(_)
            | GhostnetEvent::TaxBurned(_)
            | GhostnetEvent::TaxCollected(_)
            | GhostnetEvent::TaxExclusionSet(_) => Self::Token,

            // Fee events
            GhostnetEvent::TollCollected(_)
            | GhostnetEvent::BuybackExecuted(_)
            | GhostnetEvent::OperationsWithdrawn(_) => Self::Fees,
        }
    }
}

impl std::fmt::Display for Topic {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

/// Configuration for a topic.
#[derive(Debug, Clone)]
pub struct TopicConfig {
    /// Topic name.
    pub name: &'static str,
    /// Number of partitions.
    pub partitions: u32,
    /// Message retention in seconds (0 = unlimited).
    pub retention_secs: u64,
}

impl TopicConfig {
    /// Create a new topic config with defaults.
    #[must_use]
    pub const fn new(name: &'static str) -> Self {
        Self {
            name,
            partitions: 3,
            retention_secs: 86400 * 7, // 7 days
        }
    }

    /// Set the number of partitions.
    #[must_use]
    pub const fn with_partitions(mut self, partitions: u32) -> Self {
        self.partitions = partitions;
        self
    }

    /// Set the retention period in seconds.
    #[must_use]
    pub const fn with_retention_secs(mut self, secs: u64) -> Self {
        self.retention_secs = secs;
        self
    }
}

impl From<Topic> for TopicConfig {
    fn from(topic: Topic) -> Self {
        Self::new(topic.as_str())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn topic_names_are_lowercase() {
        for topic in Topic::all() {
            let name = topic.as_str();
            assert_eq!(name, name.to_lowercase(), "Topic name should be lowercase");
        }
    }

    #[test]
    fn all_topics_covered() {
        // Ensure we have all expected topics
        let topics = Topic::all();
        assert_eq!(topics.len(), 7);
    }

    #[test]
    fn topic_config_defaults() {
        let config = TopicConfig::new("test");
        assert_eq!(config.name, "test");
        assert_eq!(config.partitions, 3);
        assert_eq!(config.retention_secs, 86400 * 7);
    }

    #[test]
    fn topic_config_builder() {
        let config = TopicConfig::new("test")
            .with_partitions(5)
            .with_retention_secs(3600);
        assert_eq!(config.partitions, 5);
        assert_eq!(config.retention_secs, 3600);
    }
}
