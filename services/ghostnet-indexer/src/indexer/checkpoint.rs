//! Checkpoint management for indexer state persistence and recovery.
//!
//! This module provides a high-level interface for managing indexer checkpoints,
//! which track processing progress and enable recovery from restarts.
//!
//! # Checkpoint Strategy
//!
//! The indexer uses a simple checkpoint strategy:
//!
//! 1. **On block success**: Update checkpoint to the completed block
//! 2. **On restart**: Resume from the last checkpoint
//! 3. **On reorg**: Roll back checkpoint to the fork point
//!
//! ```text
//! ┌─────────────────────────────────────────────────────────────────────┐
//! │                       Checkpoint Flow                              │
//! │                                                                     │
//! │  ┌──────────────────┐    ┌──────────────────┐    ┌───────────────┐ │
//! │  │  Process Block   │───▶│  Update          │───▶│  Commit to    │ │
//! │  │  Successfully    │    │  Checkpoint      │    │  Database     │ │
//! │  └──────────────────┘    └──────────────────┘    └───────────────┘ │
//! │                                                                     │
//! │  ┌──────────────────┐    ┌──────────────────┐    ┌───────────────┐ │
//! │  │  On Restart      │───▶│  Load Last       │───▶│  Resume From  │ │
//! │  │                  │    │  Checkpoint      │    │  Checkpoint+1 │ │
//! │  └──────────────────┘    └──────────────────┘    └───────────────┘ │
//! └─────────────────────────────────────────────────────────────────────┘
//! ```
//!
//! # Recovery Modes
//!
//! The checkpoint manager supports multiple recovery modes:
//!
//! - **Resume**: Continue from the last checkpoint (default)
//! - **Reindex**: Start from a specific block (for reprocessing)
//! - **Genesis**: Start from the beginning (for fresh indexing)

use alloy::primitives::B256;
use tracing::{debug, info, instrument, warn};

use crate::error::Result;
use crate::ports::IndexerStateStore;
use crate::types::primitives::BlockNumber;

// ═══════════════════════════════════════════════════════════════════════════════
// CHECKPOINT STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// The current checkpoint state of the indexer.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CheckpointState {
    /// The last successfully processed block number.
    pub last_block: BlockNumber,
    /// The hash of the last processed block (for reorg detection).
    pub last_hash: Option<B256>,
}

impl CheckpointState {
    /// Create a new checkpoint state.
    #[must_use]
    pub const fn new(last_block: BlockNumber, last_hash: Option<B256>) -> Self {
        Self {
            last_block,
            last_hash,
        }
    }

    /// Create an empty checkpoint (no blocks processed).
    #[must_use]
    pub const fn empty() -> Self {
        Self {
            last_block: BlockNumber::new(0),
            last_hash: None,
        }
    }

    /// Get the next block to process.
    #[must_use]
    pub const fn next_block(&self) -> BlockNumber {
        self.last_block.next()
    }

    /// Check if any blocks have been processed.
    #[must_use]
    pub const fn is_empty(&self) -> bool {
        self.last_block.value() == 0 && self.last_hash.is_none()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RECOVERY MODE
// ═══════════════════════════════════════════════════════════════════════════════

/// Mode for determining the starting block on startup.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub enum RecoveryMode {
    /// Resume from the last checkpoint (default behavior).
    #[default]
    Resume,
    /// Reindex from a specific block number.
    /// Useful for reprocessing historical data.
    ReindexFrom(BlockNumber),
    /// Start from genesis (block 0).
    /// Useful for fresh indexing.
    Genesis,
    /// Start from a specific block, ignoring any existing checkpoint.
    /// Does not clear existing data - use with caution.
    StartFrom(BlockNumber),
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHECKPOINT MANAGER
// ═══════════════════════════════════════════════════════════════════════════════

/// Manages indexer checkpoints for persistence and recovery.
///
/// The checkpoint manager provides a clean interface for:
/// - Loading the last checkpoint on startup
/// - Updating checkpoints after successful block processing
/// - Determining the starting block based on recovery mode
///
/// # Type Parameters
///
/// * `S` - Store implementation that provides `IndexerStateStore`
#[derive(Debug)]
pub struct CheckpointManager<S> {
    /// Store for checkpoint persistence.
    store: S,
    /// Recovery mode for determining start block.
    recovery_mode: RecoveryMode,
    /// Minimum block to start indexing from (contract deployment block).
    min_block: BlockNumber,
}

impl<S> CheckpointManager<S>
where
    S: IndexerStateStore,
{
    /// Create a new checkpoint manager.
    ///
    /// # Arguments
    ///
    /// * `store` - Store implementation for state management
    pub fn new(store: S) -> Self {
        Self {
            store,
            recovery_mode: RecoveryMode::default(),
            min_block: BlockNumber::new(0),
        }
    }

    /// Set the recovery mode for startup.
    ///
    /// # Arguments
    ///
    /// * `mode` - The recovery mode to use
    #[must_use]
    pub const fn with_recovery_mode(mut self, mode: RecoveryMode) -> Self {
        self.recovery_mode = mode;
        self
    }

    /// Set the minimum block to start indexing from.
    ///
    /// This is typically the block where contracts were deployed.
    /// The indexer will never start before this block.
    ///
    /// # Arguments
    ///
    /// * `block` - Minimum block number
    #[must_use]
    pub const fn with_min_block(mut self, block: BlockNumber) -> Self {
        self.min_block = block;
        self
    }

    /// Load the current checkpoint state from storage.
    ///
    /// # Returns
    ///
    /// The current checkpoint state.
    ///
    /// # Errors
    ///
    /// Returns an error if the store fails to retrieve the checkpoint.
    #[instrument(skip(self))]
    pub async fn load(&self) -> Result<CheckpointState> {
        let last_block = self.store.get_last_block().await?;
        let last_hash = self.store.get_block_hash(last_block).await?;

        let state = CheckpointState::new(last_block, last_hash);

        debug!(
            last_block = %state.last_block.value(),
            has_hash = state.last_hash.is_some(),
            "Loaded checkpoint state"
        );

        Ok(state)
    }

    /// Get the block number to start indexing from.
    ///
    /// This considers:
    /// - The recovery mode
    /// - The last checkpoint
    /// - The minimum block constraint
    ///
    /// # Returns
    ///
    /// The block number to start processing from.
    ///
    /// # Errors
    ///
    /// Returns an error if the checkpoint cannot be loaded.
    #[instrument(skip(self))]
    pub async fn get_start_block(&self) -> Result<BlockNumber> {
        let checkpoint = self.load().await?;

        let start = match &self.recovery_mode {
            RecoveryMode::Resume => {
                if checkpoint.is_empty() {
                    info!("No checkpoint found, starting from min block");
                    self.min_block
                } else {
                    info!(
                        last_block = %checkpoint.last_block.value(),
                        "Resuming from checkpoint"
                    );
                    checkpoint.next_block()
                }
            }
            RecoveryMode::ReindexFrom(block) => {
                info!(block = %block.value(), "Reindexing from specified block");
                *block
            }
            RecoveryMode::Genesis => {
                info!("Starting from genesis");
                BlockNumber::new(0)
            }
            RecoveryMode::StartFrom(block) => {
                warn!(
                    block = %block.value(),
                    "Starting from specified block (ignoring checkpoint)"
                );
                *block
            }
        };

        // Ensure we don't start before min_block
        let start = if start.value() < self.min_block.value() {
            info!(
                requested = %start.value(),
                min = %self.min_block.value(),
                "Start block below minimum, using min block"
            );
            self.min_block
        } else {
            start
        };

        info!(start_block = %start.value(), "Determined start block");
        Ok(start)
    }

    /// Update the checkpoint after successfully processing a block.
    ///
    /// # Arguments
    ///
    /// * `block` - The block number that was processed
    /// * `hash` - The hash of the processed block
    ///
    /// # Errors
    ///
    /// Returns an error if the store fails to save the checkpoint.
    #[instrument(skip(self), fields(block = %block.value()))]
    pub async fn update(&self, block: BlockNumber, hash: B256) -> Result<()> {
        self.store.set_last_block(block, hash).await?;
        debug!("Checkpoint updated");
        Ok(())
    }

    /// Reset the checkpoint to a specific block (for reorg recovery).
    ///
    /// This is typically called after a reorg rollback to ensure
    /// the checkpoint reflects the new chain state.
    ///
    /// # Arguments
    ///
    /// * `block` - The block to reset the checkpoint to
    /// * `hash` - The hash of that block
    ///
    /// # Errors
    ///
    /// Returns an error if the store fails to save the checkpoint.
    #[instrument(skip(self), fields(block = %block.value()))]
    pub async fn reset_to(&self, block: BlockNumber, hash: B256) -> Result<()> {
        info!(block = %block.value(), "Resetting checkpoint after reorg");
        self.store.set_last_block(block, hash).await?;
        Ok(())
    }

    /// Get a reference to the underlying store.
    #[must_use]
    pub const fn store(&self) -> &S {
        &self.store
    }

    /// Consume the manager and return the underlying store.
    pub fn into_store(self) -> S {
        self.store
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;
    use std::sync::{Arc, Mutex};

    /// Mock store for testing checkpoint management.
    #[derive(Debug, Default, Clone)]
    struct MockStateStore {
        last_block: Arc<Mutex<Option<(u64, B256)>>>,
        block_hashes: Arc<Mutex<HashMap<u64, B256>>>,
    }

    #[async_trait::async_trait]
    impl IndexerStateStore for MockStateStore {
        async fn get_last_block(&self) -> Result<BlockNumber> {
            let guard = self.last_block.lock().unwrap();
            let value = guard.map(|(b, _)| b).unwrap_or(0);
            Ok(BlockNumber::new(value))
        }

        async fn set_last_block(&self, block: BlockNumber, hash: B256) -> Result<()> {
            let mut guard = self.last_block.lock().unwrap();
            *guard = Some((block.value(), hash));

            // Also store in block_hashes
            let mut hashes = self.block_hashes.lock().unwrap();
            hashes.insert(block.value(), hash);

            Ok(())
        }

        async fn insert_block_hash(
            &self,
            block: BlockNumber,
            hash: B256,
            _parent: B256,
            _timestamp: u64,
        ) -> Result<()> {
            let mut hashes = self.block_hashes.lock().unwrap();
            hashes.insert(block.value(), hash);
            Ok(())
        }

        async fn get_block_hash(&self, block: BlockNumber) -> Result<Option<B256>> {
            let hashes = self.block_hashes.lock().unwrap();
            Ok(hashes.get(&block.value()).copied())
        }

        async fn execute_reorg_rollback(&self, _fork_point: BlockNumber) -> Result<()> {
            Ok(())
        }

        async fn prune_old_blocks(&self, _keep_blocks: u64) -> Result<u64> {
            Ok(0)
        }
    }

    impl MockStateStore {
        fn with_checkpoint(block: u64, hash: B256) -> Self {
            let store = Self::default();
            {
                let mut last = store.last_block.lock().unwrap();
                *last = Some((block, hash));

                let mut hashes = store.block_hashes.lock().unwrap();
                hashes.insert(block, hash);
            }
            store
        }
    }

    #[test]
    fn checkpoint_state_empty() {
        let state = CheckpointState::empty();
        assert!(state.is_empty());
        assert_eq!(state.last_block.value(), 0);
        assert!(state.last_hash.is_none());
    }

    #[test]
    fn checkpoint_state_next_block() {
        let state = CheckpointState::new(BlockNumber::new(100), Some(B256::from([0xAA; 32])));
        assert_eq!(state.next_block().value(), 101);
    }

    #[test]
    fn recovery_mode_default_is_resume() {
        assert_eq!(RecoveryMode::default(), RecoveryMode::Resume);
    }

    #[tokio::test]
    async fn load_empty_checkpoint() {
        let store = MockStateStore::default();
        let manager = CheckpointManager::new(store);

        let state = manager.load().await.unwrap();
        assert!(state.is_empty());
    }

    #[tokio::test]
    async fn load_existing_checkpoint() {
        let hash = B256::from([0xAA; 32]);
        let store = MockStateStore::with_checkpoint(100, hash);
        let manager = CheckpointManager::new(store);

        let state = manager.load().await.unwrap();
        assert!(!state.is_empty());
        assert_eq!(state.last_block.value(), 100);
        assert_eq!(state.last_hash, Some(hash));
    }

    #[tokio::test]
    async fn get_start_block_resume_empty() {
        let store = MockStateStore::default();
        let manager = CheckpointManager::new(store).with_min_block(BlockNumber::new(1000));

        let start = manager.get_start_block().await.unwrap();
        assert_eq!(start.value(), 1000); // Uses min_block
    }

    #[tokio::test]
    async fn get_start_block_resume_with_checkpoint() {
        let store = MockStateStore::with_checkpoint(500, B256::from([0xAA; 32]));
        let manager = CheckpointManager::new(store);

        let start = manager.get_start_block().await.unwrap();
        assert_eq!(start.value(), 501); // Next block after checkpoint
    }

    #[tokio::test]
    async fn get_start_block_reindex_from() {
        let store = MockStateStore::with_checkpoint(500, B256::from([0xAA; 32]));
        let manager = CheckpointManager::new(store)
            .with_recovery_mode(RecoveryMode::ReindexFrom(BlockNumber::new(100)));

        let start = manager.get_start_block().await.unwrap();
        assert_eq!(start.value(), 100);
    }

    #[tokio::test]
    async fn get_start_block_genesis() {
        let store = MockStateStore::with_checkpoint(500, B256::from([0xAA; 32]));
        let manager = CheckpointManager::new(store).with_recovery_mode(RecoveryMode::Genesis);

        let start = manager.get_start_block().await.unwrap();
        assert_eq!(start.value(), 0);
    }

    #[tokio::test]
    async fn get_start_block_respects_min_block() {
        let store = MockStateStore::default();
        let manager = CheckpointManager::new(store)
            .with_recovery_mode(RecoveryMode::Genesis)
            .with_min_block(BlockNumber::new(1000));

        let start = manager.get_start_block().await.unwrap();
        assert_eq!(start.value(), 1000); // Min block overrides genesis
    }

    #[tokio::test]
    async fn update_checkpoint() {
        let store = MockStateStore::default();
        let manager = CheckpointManager::new(store.clone());

        let block = BlockNumber::new(100);
        let hash = B256::from([0xAA; 32]);

        manager.update(block, hash).await.unwrap();

        let state = manager.load().await.unwrap();
        assert_eq!(state.last_block.value(), 100);
        assert_eq!(state.last_hash, Some(hash));
    }

    #[tokio::test]
    async fn reset_checkpoint() {
        let store = MockStateStore::with_checkpoint(500, B256::from([0xBB; 32]));
        let manager = CheckpointManager::new(store);

        let new_block = BlockNumber::new(400);
        let new_hash = B256::from([0xAA; 32]);

        manager.reset_to(new_block, new_hash).await.unwrap();

        let state = manager.load().await.unwrap();
        assert_eq!(state.last_block.value(), 400);
    }

    #[test]
    fn manager_is_send_sync() {
        fn assert_send_sync<T: Send + Sync>() {}
        assert_send_sync::<CheckpointManager<MockStateStore>>();
    }
}
