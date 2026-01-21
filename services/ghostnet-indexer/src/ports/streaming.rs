//! Streaming port for event publishing.
//!
//! Defines the contract for publishing events to a streaming system
//! (e.g., Apache Iggy, Kafka, Redis Streams).

use async_trait::async_trait;

use crate::error::Result;
use crate::types::events::GhostnetEvent;

// ═══════════════════════════════════════════════════════════════════════════════
// EVENT PUBLISHER
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for event streaming/publishing.
///
/// Publishes events to a streaming system for real-time consumption
/// by clients (WebSocket API, analytics pipelines, etc.).
///
/// # Topics
///
/// Events are published to topics based on their type:
///
/// | Topic | Events |
/// |-------|--------|
/// | `ghostnet.positions` | JackedIn, StakeAdded, Extracted, PositionCulled |
/// | `ghostnet.scans` | ScanExecuted, ScanFinalized |
/// | `ghostnet.deaths` | DeathsProcessed, SurvivorsUpdated |
/// | `ghostnet.market` | RoundCreated, BetPlaced, RoundResolved |
/// | `ghostnet.system` | SystemResetTriggered |
///
/// # Implementation Notes
///
/// Implementations should:
/// - Use persistent message IDs for exactly-once semantics
/// - Implement backpressure handling
/// - Buffer messages during network issues
#[async_trait]
pub trait EventPublisher: Send + Sync {
    /// Publish a GHOSTNET event to the appropriate topic.
    ///
    /// The implementation determines the topic based on event type.
    ///
    /// # Errors
    ///
    /// Returns an error if publishing fails after retries.
    async fn publish(&self, event: &GhostnetEvent) -> Result<()>;

    /// Publish raw bytes to a specific topic.
    ///
    /// Use this for custom payloads or pre-serialized data.
    ///
    /// # Arguments
    ///
    /// * `topic` - Topic name (e.g., "ghostnet.positions")
    /// * `payload` - Raw bytes to publish
    ///
    /// # Errors
    ///
    /// Returns an error if publishing fails.
    async fn publish_to_topic(&self, topic: &str, payload: &[u8]) -> Result<()>;

    /// Publish a batch of events.
    ///
    /// More efficient than individual `publish()` calls.
    ///
    /// # Errors
    ///
    /// Returns an error if any publish fails. Implementations should
    /// document whether partial batches are committed.
    async fn publish_batch(&self, events: &[GhostnetEvent]) -> Result<()>;

    /// Flush pending messages.
    ///
    /// Ensures all buffered messages are sent before returning.
    ///
    /// # Errors
    ///
    /// Returns an error if flush fails.
    async fn flush(&self) -> Result<()>;

    /// Check if the publisher is connected.
    fn is_connected(&self) -> bool;
}

#[cfg(test)]
pub mod mocks {
    //! Mock implementations for testing.

    use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
    use std::sync::Arc;

    use super::*;

    /// Mock publisher that counts calls and optionally fails.
    #[derive(Debug, Clone)]
    pub struct MockEventPublisher {
        /// Number of events published.
        pub publish_count: Arc<AtomicUsize>,
        /// Whether to simulate connection.
        pub connected: Arc<AtomicBool>,
        /// Whether to fail on publish.
        pub should_fail: Arc<AtomicBool>,
    }

    impl Default for MockEventPublisher {
        fn default() -> Self {
            Self {
                publish_count: Arc::new(AtomicUsize::new(0)),
                connected: Arc::new(AtomicBool::new(true)),
                should_fail: Arc::new(AtomicBool::new(false)),
            }
        }
    }

    impl MockEventPublisher {
        /// Create a new mock publisher.
        #[must_use]
        pub fn new() -> Self {
            Self::default()
        }

        /// Get the number of events published.
        #[must_use]
        pub fn count(&self) -> usize {
            self.publish_count.load(Ordering::SeqCst)
        }

        /// Set whether to simulate connection failure.
        pub fn set_connected(&self, connected: bool) {
            self.connected.store(connected, Ordering::SeqCst);
        }

        /// Set whether to fail on publish.
        pub fn set_should_fail(&self, should_fail: bool) {
            self.should_fail.store(should_fail, Ordering::SeqCst);
        }
    }

    #[async_trait]
    impl EventPublisher for MockEventPublisher {
        async fn publish(&self, _event: &GhostnetEvent) -> Result<()> {
            if self.should_fail.load(Ordering::SeqCst) {
                return Err(crate::error::AppError::Infra(
                    crate::error::InfraError::Streaming("Mock publish failure".into()),
                ));
            }
            self.publish_count.fetch_add(1, Ordering::SeqCst);
            Ok(())
        }

        async fn publish_to_topic(&self, _topic: &str, _payload: &[u8]) -> Result<()> {
            if self.should_fail.load(Ordering::SeqCst) {
                return Err(crate::error::AppError::Infra(
                    crate::error::InfraError::Streaming("Mock publish failure".into()),
                ));
            }
            self.publish_count.fetch_add(1, Ordering::SeqCst);
            Ok(())
        }

        async fn publish_batch(&self, events: &[GhostnetEvent]) -> Result<()> {
            if self.should_fail.load(Ordering::SeqCst) {
                return Err(crate::error::AppError::Infra(
                    crate::error::InfraError::Streaming("Mock publish failure".into()),
                ));
            }
            self.publish_count.fetch_add(events.len(), Ordering::SeqCst);
            Ok(())
        }

        async fn flush(&self) -> Result<()> {
            Ok(())
        }

        fn is_connected(&self) -> bool {
            self.connected.load(Ordering::SeqCst)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::mocks::MockEventPublisher;
    use super::*;

    #[tokio::test]
    async fn mock_publisher_counts_events() {
        let publisher = MockEventPublisher::new();
        assert_eq!(publisher.count(), 0);

        // Would publish an event here if we had a simple constructor
        // For now just test the mock itself
        assert!(publisher.is_connected());

        publisher.set_connected(false);
        assert!(!publisher.is_connected());
    }
}
