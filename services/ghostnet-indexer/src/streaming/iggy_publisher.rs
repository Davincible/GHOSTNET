//! Apache Iggy event publisher implementation.
//!
//! Implements the `EventPublisher` port using Apache Iggy as the streaming backend.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use async_trait::async_trait;
use bytes::Bytes;
use iggy::client::{Client, MessageClient, StreamClient, TopicClient};
use iggy::clients::client::IggyClient;
use iggy::identifier::Identifier;
use iggy::messages::send_messages::{Message, Partitioning};
use iggy::compression::compression_algorithm::CompressionAlgorithm;
use iggy::utils::expiry::IggyExpiry;
use iggy::utils::topic_size::MaxTopicSize;
use tokio::sync::RwLock;
use tracing::{debug, info, instrument};

use crate::config::IggySettings;
use crate::error::{InfraError, Result};
use crate::ports::EventPublisher;
use crate::types::events::GhostnetEvent;

use super::topics::Topic;

/// Apache Iggy-based event publisher.
///
/// Connects to an Iggy server and publishes GHOSTNET events to appropriate topics.
/// Handles stream/topic creation lazily and manages reconnection.
///
/// # Thread Safety
///
/// This type is `Send + Sync` and can be shared across tasks.
pub struct IggyPublisher {
    /// The Iggy client.
    client: Arc<IggyClient>,
    /// Stream name for all GHOSTNET events.
    stream_name: String,
    /// Number of partitions per topic.
    partition_count: u32,
    /// Whether we're connected to the Iggy server.
    connected: AtomicBool,
    /// Whether we've initialized the stream and topics.
    initialized: AtomicBool,
    /// Lock for initialization to prevent races.
    init_lock: RwLock<()>,
}

impl std::fmt::Debug for IggyPublisher {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("IggyPublisher")
            .field("stream_name", &self.stream_name)
            .field("partition_count", &self.partition_count)
            .field("connected", &self.connected.load(Ordering::SeqCst))
            .field("initialized", &self.initialized.load(Ordering::SeqCst))
            .finish_non_exhaustive()
    }
}

impl IggyPublisher {
    /// Create a new Iggy publisher from settings.
    ///
    /// This creates the client but does NOT connect. Call `connect()` to establish
    /// the connection, or let it connect lazily on first publish.
    ///
    /// # Errors
    ///
    /// Returns an error if the client cannot be created.
    pub fn new(settings: &IggySettings) -> Result<Self> {
        let client = IggyClient::builder()
            .with_tcp()
            .with_server_address(settings.url.clone())
            .build()
            .map_err(|e| InfraError::Streaming(format!("Failed to create Iggy client: {e}")))?;

        Ok(Self {
            client: Arc::new(client),
            stream_name: settings.stream_name.clone(),
            partition_count: settings.partition_count,
            connected: AtomicBool::new(false),
            initialized: AtomicBool::new(false),
            init_lock: RwLock::new(()),
        })
    }

    /// Connect to the Iggy server.
    ///
    /// # Errors
    ///
    /// Returns an error if connection fails.
    #[instrument(skip(self))]
    pub async fn connect(&self) -> Result<()> {
        self.client
            .connect()
            .await
            .map_err(|e| InfraError::Streaming(format!("Failed to connect to Iggy: {e}")))?;

        self.connected.store(true, Ordering::SeqCst);
        info!(stream = %self.stream_name, "Connected to Iggy server");
        Ok(())
    }

    /// Disconnect from the Iggy server.
    ///
    /// # Errors
    ///
    /// Returns an error if disconnection fails.
    pub async fn disconnect(&self) -> Result<()> {
        self.client
            .disconnect()
            .await
            .map_err(|e| InfraError::Streaming(format!("Failed to disconnect from Iggy: {e}")))?;

        self.connected.store(false, Ordering::SeqCst);
        self.initialized.store(false, Ordering::SeqCst);
        info!("Disconnected from Iggy server");
        Ok(())
    }

    /// Ensure the stream and topics exist.
    ///
    /// This is called lazily on first publish and is idempotent.
    /// Will auto-connect if not already connected.
    #[instrument(skip(self))]
    async fn ensure_initialized(&self) -> Result<()> {
        // Fast path: already initialized
        if self.initialized.load(Ordering::SeqCst) {
            return Ok(());
        }

        // Slow path: take lock and check again
        let _guard = self.init_lock.write().await;
        if self.initialized.load(Ordering::SeqCst) {
            return Ok(());
        }

        // Auto-connect if not connected
        if !self.connected.load(Ordering::SeqCst) {
            self.connect().await?;
        }

        // Create stream if it doesn't exist
        self.ensure_stream_exists().await?;

        // Create all topics
        for topic in Topic::all() {
            self.ensure_topic_exists(*topic).await?;
        }

        self.initialized.store(true, Ordering::SeqCst);
        info!(stream = %self.stream_name, "Initialized Iggy stream and topics");
        Ok(())
    }

    /// Ensure the stream exists.
    async fn ensure_stream_exists(&self) -> Result<()> {
        let stream_id = Identifier::from_str_value(&self.stream_name)
            .map_err(|e| InfraError::Streaming(format!("Invalid stream name: {e}")))?;

        // Try to get the stream first
        match self.client.get_stream(&stream_id).await {
            Ok(Some(_)) => {
                debug!(stream = %self.stream_name, "Stream already exists");
                return Ok(());
            }
            Ok(None) => {
                // Stream doesn't exist, create it
            }
            Err(e) => {
                // Check if it's a "not found" error, otherwise propagate
                let err_str = e.to_string();
                if !err_str.contains("not found") && !err_str.contains("NotFound") {
                    return Err(InfraError::Streaming(format!(
                        "Failed to check stream: {e}"
                    ))
                    .into());
                }
            }
        }

        // Create the stream
        match self
            .client
            .create_stream(&self.stream_name, Some(1))
            .await
        {
            Ok(_stream_details) => {
                info!(stream = %self.stream_name, "Created Iggy stream");
                Ok(())
            }
            Err(e) => {
                // Ignore "already exists" errors (race condition)
                let err_str = e.to_string();
                if err_str.contains("already exists") || err_str.contains("AlreadyExists") {
                    debug!(stream = %self.stream_name, "Stream already exists (race)");
                    Ok(())
                } else {
                    Err(InfraError::Streaming(format!("Failed to create stream: {e}")).into())
                }
            }
        }
    }

    /// Ensure a topic exists within the stream.
    async fn ensure_topic_exists(&self, topic: Topic) -> Result<()> {
        let stream_id = Identifier::from_str_value(&self.stream_name)
            .map_err(|e| InfraError::Streaming(format!("Invalid stream name: {e}")))?;
        let topic_id = Identifier::from_str_value(topic.as_str())
            .map_err(|e| InfraError::Streaming(format!("Invalid topic name: {e}")))?;

        // Try to get the topic first
        match self.client.get_topic(&stream_id, &topic_id).await {
            Ok(Some(_)) => {
                debug!(topic = %topic, "Topic already exists");
                return Ok(());
            }
            Ok(None) => {
                // Topic doesn't exist, create it
            }
            Err(e) => {
                let err_str = e.to_string();
                if !err_str.contains("not found") && !err_str.contains("NotFound") {
                    return Err(
                        InfraError::Streaming(format!("Failed to check topic: {e}")).into(),
                    );
                }
            }
        }

        // Create the topic
        match self
            .client
            .create_topic(
                &stream_id,
                topic.as_str(),
                self.partition_count,
                CompressionAlgorithm::None, // compression
                None,                       // replication_factor
                None,                       // topic_id (auto-assign)
                IggyExpiry::ServerDefault,  // message_expiry
                MaxTopicSize::ServerDefault,
            )
            .await
        {
            Ok(_topic_details) => {
                info!(topic = %topic, partitions = self.partition_count, "Created Iggy topic");
                Ok(())
            }
            Err(e) => {
                let err_str = e.to_string();
                if err_str.contains("already exists") || err_str.contains("AlreadyExists") {
                    debug!(topic = %topic, "Topic already exists (race)");
                    Ok(())
                } else {
                    Err(InfraError::Streaming(format!("Failed to create topic: {e}")).into())
                }
            }
        }
    }

    /// Serialize an event to JSON bytes.
    fn serialize_event(event: &GhostnetEvent) -> Result<Bytes> {
        serde_json::to_vec(event)
            .map(Bytes::from)
            .map_err(|e| InfraError::Streaming(format!("Failed to serialize event: {e}")).into())
    }

    /// Create an Iggy message from an event.
    fn create_message(event: &GhostnetEvent) -> Result<Message> {
        let payload = Self::serialize_event(event)?;
        // Message payload length is capped at u32::MAX by Iggy protocol.
        // Practical event payloads are always << 4GB, so this cast is safe.
        #[allow(clippy::cast_possible_truncation)]
        let length = payload.len() as u32;
        Ok(Message {
            id: 0, // Server will assign
            length,
            payload,
            headers: None,
        })
    }

    /// Send messages to a topic.
    #[instrument(skip(self, messages), fields(topic = %topic, count = messages.len()))]
    async fn send_to_topic(&self, topic: Topic, messages: &mut [Message]) -> Result<()> {
        if messages.is_empty() {
            return Ok(());
        }

        let stream_id = Identifier::from_str_value(&self.stream_name)
            .map_err(|e| InfraError::Streaming(format!("Invalid stream name: {e}")))?;
        let topic_id = Identifier::from_str_value(topic.as_str())
            .map_err(|e| InfraError::Streaming(format!("Invalid topic name: {e}")))?;

        self.client
            .send_messages(&stream_id, &topic_id, &Partitioning::balanced(), messages)
            .await
            .map_err(|e| InfraError::Streaming(format!("Failed to send messages: {e}")))?;

        debug!(topic = %topic, count = messages.len(), "Published messages to Iggy");
        Ok(())
    }
}

#[async_trait]
impl EventPublisher for IggyPublisher {
    #[instrument(skip(self, event), fields(event_type = %event.type_name()))]
    async fn publish(&self, event: &GhostnetEvent) -> Result<()> {
        self.ensure_initialized().await?;

        let topic = Topic::for_event(event);
        let mut message = Self::create_message(event)?;

        self.send_to_topic(topic, std::slice::from_mut(&mut message))
            .await
    }

    #[instrument(skip(self, payload), fields(topic = %topic, size = payload.len()))]
    async fn publish_to_topic(&self, topic: &str, payload: &[u8]) -> Result<()> {
        self.ensure_initialized().await?;

        let stream_id = Identifier::from_str_value(&self.stream_name)
            .map_err(|e| InfraError::Streaming(format!("Invalid stream name: {e}")))?;
        let topic_id = Identifier::from_str_value(topic)
            .map_err(|e| InfraError::Streaming(format!("Invalid topic name: {e}")))?;

        // Message payload length is capped at u32::MAX by Iggy protocol.
        // Practical payloads are always << 4GB, so this cast is safe.
        #[allow(clippy::cast_possible_truncation)]
        let length = payload.len() as u32;
        let mut message = Message {
            id: 0,
            length,
            payload: Bytes::copy_from_slice(payload),
            headers: None,
        };

        self.client
            .send_messages(
                &stream_id,
                &topic_id,
                &Partitioning::balanced(),
                std::slice::from_mut(&mut message),
            )
            .await
            .map_err(|e| InfraError::Streaming(format!("Failed to send message: {e}")))?;

        Ok(())
    }

    #[instrument(skip(self, events), fields(count = events.len()))]
    async fn publish_batch(&self, events: &[GhostnetEvent]) -> Result<()> {
        use std::collections::HashMap;

        if events.is_empty() {
            return Ok(());
        }

        self.ensure_initialized().await?;

        // Group events by topic for efficient batching
        let mut by_topic: HashMap<Topic, Vec<Message>> = HashMap::new();

        for event in events {
            let topic = Topic::for_event(event);
            let message = Self::create_message(event)?;
            by_topic.entry(topic).or_default().push(message);
        }

        // Send each batch to its topic
        for (topic, mut messages) in by_topic {
            self.send_to_topic(topic, &mut messages).await?;
        }

        Ok(())
    }

    async fn flush(&self) -> Result<()> {
        // Iggy doesn't have an explicit flush - messages are sent synchronously
        Ok(())
    }

    fn is_connected(&self) -> bool {
        self.connected.load(Ordering::SeqCst)
    }
}

/// A no-op publisher for testing or when streaming is disabled.
///
/// Use this when you want to satisfy the `EventPublisher` trait without
/// actually sending events anywhere.
#[derive(Debug, Default, Clone)]
pub struct NoOpPublisher;

#[async_trait]
impl EventPublisher for NoOpPublisher {
    async fn publish(&self, _event: &GhostnetEvent) -> Result<()> {
        Ok(())
    }

    async fn publish_to_topic(&self, _topic: &str, _payload: &[u8]) -> Result<()> {
        Ok(())
    }

    async fn publish_batch(&self, _events: &[GhostnetEvent]) -> Result<()> {
        Ok(())
    }

    async fn flush(&self) -> Result<()> {
        Ok(())
    }

    fn is_connected(&self) -> bool {
        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::IggySettings;

    fn test_settings() -> IggySettings {
        IggySettings {
            url: "tcp://localhost:8090".to_string(),
            stream_name: "ghostnet-test".to_string(),
            partition_count: 1,
            replication_factor: 1,
            username: "iggy".to_string(),
            password: "iggy".to_string(),
        }
    }

    #[test]
    fn publisher_debug_format() {
        // We can't fully test without a running Iggy server,
        // but we can test that the publisher can be created
        let result = IggyPublisher::new(&test_settings());
        assert!(result.is_ok());

        let publisher = result.unwrap();
        let debug_str = format!("{:?}", publisher);
        assert!(debug_str.contains("IggyPublisher"));
        assert!(debug_str.contains("ghostnet-test"));
    }

    #[test]
    fn noop_publisher_is_always_connected() {
        let publisher = NoOpPublisher;
        assert!(publisher.is_connected());
    }

    #[tokio::test]
    async fn noop_publisher_accepts_all_operations() {
        let publisher = NoOpPublisher;

        // All operations should succeed silently
        assert!(publisher.publish_to_topic("test", b"data").await.is_ok());
        assert!(publisher.publish_batch(&[]).await.is_ok());
        assert!(publisher.flush().await.is_ok());
    }
}
