//! Chain reorganization detection and rollback handling.
//!
//! This module provides the logic layer for detecting and handling chain
//! reorganizations (reorgs). A reorg occurs when the canonical chain changes,
//! typically due to network propagation delays or competing blocks.
//!
//! # Reorg Detection
//!
//! Reorgs are detected by checking parent hash consistency:
//!
//! ```text
//! Stored:   Block 100 (hash: 0xAAA) → Block 101 (hash: 0xBBB, parent: 0xAAA)
//! Incoming: Block 102 (hash: 0xCCC, parent: 0xXXX)  ← Parent mismatch!
//!
//! This indicates a reorg occurred. We find the fork point (last matching block)
//! and roll back to it before reprocessing.
//! ```
//!
//! # Architecture
//!
//! ```text
//! ┌─────────────────────────────────────────────────────────────────────┐
//! │                        ReorgHandler                                 │
//! │                                                                     │
//! │  ┌──────────────────┐    ┌──────────────────┐    ┌───────────────┐ │
//! │  │  Detect Reorg    │───▶│  Find Fork Point │───▶│  Execute      │ │
//! │  │  (parent check)  │    │  (walk backward) │    │  Rollback     │ │
//! │  └──────────────────┘    └──────────────────┘    └───────────────┘ │
//! │         │                                                │         │
//! │         ▼                                                ▼         │
//! │  ┌──────────────────┐                        ┌───────────────────┐ │
//! │  │  Record Block    │                        │  Emit Reorg Event │ │
//! │  │  Hash            │                        │  (for monitoring) │ │
//! │  └──────────────────┘                        └───────────────────┘ │
//! └─────────────────────────────────────────────────────────────────────┘
//! ```
//!
//! # MegaETH Considerations
//!
//! MegaETH has ~10ms block times with mini-blocks. While reorgs are rare
//! due to the single-sequencer design, we still handle them for:
//! - Network partitions
//! - Sequencer restarts
//! - Future decentralization

use alloy::primitives::B256;
use tracing::{debug, error, info, instrument, warn};

use crate::error::Result;
use crate::ports::IndexerStateStore;
use crate::types::primitives::BlockNumber;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Maximum depth to search for fork point.
/// Beyond this, we assume a catastrophic reorg and require manual intervention.
const MAX_REORG_DEPTH: u64 = 256;

/// Number of block hashes to keep for reorg detection.
/// Should be > `MAX_REORG_DEPTH` to handle deep reorgs.
const DEFAULT_BLOCK_RETENTION: u64 = 512;

// ═══════════════════════════════════════════════════════════════════════════════
// REORG RESULT
// ═══════════════════════════════════════════════════════════════════════════════

/// Result of checking a block for reorg.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReorgCheckResult {
    /// No reorg detected - parent hash matches.
    NoReorg,
    /// Reorg detected - fork point found at the given block.
    ReorgDetected {
        /// The block where the fork occurred (last common block).
        fork_point: BlockNumber,
        /// Depth of the reorg (blocks to roll back).
        depth: u64,
    },
    /// First block being indexed - no parent to check.
    FirstBlock,
    /// Parent block not in our history (pruned or never indexed).
    ParentNotFound,
}

/// Statistics about a reorg event.
#[derive(Debug, Clone)]
pub struct ReorgStats {
    /// The block number where the reorg was detected.
    pub detected_at: BlockNumber,
    /// The fork point (last common block).
    pub fork_point: BlockNumber,
    /// Number of blocks rolled back.
    pub depth: u64,
    /// Hash of the orphaned block at detection point.
    pub orphaned_hash: B256,
    /// Hash of the new block at detection point.
    pub new_hash: B256,
}

// ═══════════════════════════════════════════════════════════════════════════════
// REORG HANDLER
// ═══════════════════════════════════════════════════════════════════════════════

/// Handles chain reorganization detection and recovery.
///
/// The handler uses stored block hashes to detect when the chain has
/// reorganized and orchestrates the rollback of indexed data.
///
/// # Type Parameters
///
/// * `S` - Store implementation that provides `IndexerStateStore`
#[derive(Debug)]
pub struct ReorgHandler<S> {
    /// Store for block hash lookups and rollback operations.
    store: S,
    /// Number of blocks to retain for reorg detection.
    block_retention: u64,
}

impl<S> ReorgHandler<S>
where
    S: IndexerStateStore,
{
    /// Create a new reorg handler.
    ///
    /// # Arguments
    ///
    /// * `store` - Store implementation for state management
    #[must_use]
    pub const fn new(store: S) -> Self {
        Self {
            store,
            block_retention: DEFAULT_BLOCK_RETENTION,
        }
    }

    /// Create a new reorg handler with custom block retention.
    ///
    /// # Arguments
    ///
    /// * `store` - Store implementation for state management
    /// * `block_retention` - Number of blocks to retain for reorg detection
    #[must_use]
    pub const fn with_retention(store: S, block_retention: u64) -> Self {
        Self {
            store,
            block_retention,
        }
    }

    /// Check if processing this block would result in a reorg.
    ///
    /// Compares the incoming block's parent hash against our stored hash
    /// for the parent block number.
    ///
    /// # Arguments
    ///
    /// * `block_number` - The block number being processed
    /// * `parent_hash` - The parent hash from the incoming block
    ///
    /// # Returns
    ///
    /// A `ReorgCheckResult` indicating whether a reorg occurred.
    ///
    /// # Errors
    ///
    /// Returns an error if the store fails to retrieve block hashes.
    #[instrument(skip(self), fields(block = %block_number.value()))]
    pub async fn check_for_reorg(
        &self,
        block_number: BlockNumber,
        parent_hash: B256,
    ) -> Result<ReorgCheckResult> {
        // First block has no parent to check
        if block_number.value() == 0 {
            return Ok(ReorgCheckResult::FirstBlock);
        }

        let parent_block = block_number.prev();

        // Get our stored hash for the parent block
        let stored_hash = self.store.get_block_hash(parent_block).await?;

        match stored_hash {
            None => {
                // Parent not in our history
                debug!(
                    parent_block = %parent_block.value(),
                    "Parent block not found in history"
                );
                Ok(ReorgCheckResult::ParentNotFound)
            }
            Some(stored) if stored == parent_hash => {
                // Hashes match - no reorg
                debug!("Parent hash matches, no reorg");
                Ok(ReorgCheckResult::NoReorg)
            }
            Some(stored) => {
                // Mismatch! Find the fork point
                warn!(
                    parent_block = %parent_block.value(),
                    stored_hash = %stored,
                    incoming_parent = %parent_hash,
                    "Reorg detected: parent hash mismatch"
                );

                let fork_point = self.find_fork_point(block_number, parent_hash).await?;
                let depth = block_number.value() - fork_point.value();

                info!(
                    fork_point = %fork_point.value(),
                    depth,
                    "Found fork point"
                );

                Ok(ReorgCheckResult::ReorgDetected { fork_point, depth })
            }
        }
    }

    /// Find the fork point by walking backward through block history.
    ///
    /// This searches for the last block where our stored hash matches
    /// the chain's parent hash.
    ///
    /// # Arguments
    ///
    /// * `from_block` - Block where reorg was detected
    /// * `new_parent_hash` - Parent hash from the new chain
    ///
    /// # Returns
    ///
    /// The fork point block number.
    ///
    /// # Errors
    ///
    /// Returns an error if the fork point cannot be found within `MAX_REORG_DEPTH`.
    #[instrument(skip(self), fields(from = %from_block.value()))]
    async fn find_fork_point(
        &self,
        from_block: BlockNumber,
        new_parent_hash: B256,
    ) -> Result<BlockNumber> {
        // In a real implementation, we'd need to walk the new chain backward
        // and compare against our stored hashes. For now, we use a simplified
        // approach that assumes the fork point is one block before the mismatch.
        //
        // TODO: Implement proper fork point detection by walking both chains
        // This requires fetching parent hashes from the RPC for the new chain.

        let fork_point = from_block.prev().prev();

        // Validate fork point is within acceptable depth
        let depth = from_block.value().saturating_sub(fork_point.value());
        if depth > MAX_REORG_DEPTH {
            error!(
                depth,
                max = MAX_REORG_DEPTH,
                "Reorg too deep, manual intervention required"
            );
            return Err(crate::error::DomainError::ReorgTooDeep {
                depth,
                max: MAX_REORG_DEPTH,
            }
            .into());
        }

        Ok(fork_point)
    }

    /// Execute rollback to the fork point.
    ///
    /// This deletes all indexed data created after the fork point
    /// and resets the indexer state to continue from there.
    ///
    /// # Arguments
    ///
    /// * `fork_point` - Block to roll back to (this block is kept)
    ///
    /// # Errors
    ///
    /// Returns an error if the store fails to execute the rollback.
    #[instrument(skip(self), fields(fork_point = %fork_point.value()))]
    pub async fn execute_rollback(&self, fork_point: BlockNumber) -> Result<()> {
        info!(fork_point = %fork_point.value(), "Executing reorg rollback");

        // Execute the rollback through the store
        self.store.execute_reorg_rollback(fork_point).await?;

        info!("Reorg rollback complete");
        Ok(())
    }

    /// Record a block hash for future reorg detection.
    ///
    /// Should be called after successfully processing a block.
    ///
    /// # Arguments
    ///
    /// * `block` - Block number
    /// * `hash` - Block hash
    /// * `parent` - Parent block hash
    /// * `timestamp` - Block timestamp
    ///
    /// # Errors
    ///
    /// Returns an error if the store fails to record the block hash.
    #[instrument(skip(self), fields(block = %block.value()))]
    pub async fn record_block(
        &self,
        block: BlockNumber,
        hash: B256,
        parent: B256,
        timestamp: u64,
    ) -> Result<()> {
        // Record the block hash
        self.store
            .insert_block_hash(block, hash, parent, timestamp)
            .await?;

        // Periodically prune old blocks to bound storage
        // Only prune every 100 blocks to avoid constant cleanup
        if block.value().is_multiple_of(100) {
            let pruned = self.store.prune_old_blocks(self.block_retention).await?;
            if pruned > 0 {
                debug!(pruned, "Pruned old block hashes");
            }
        }

        Ok(())
    }

    /// Handle a detected reorg by rolling back and returning the restart point.
    ///
    /// This is a convenience method that combines fork point detection and rollback.
    ///
    /// # Arguments
    ///
    /// * `detected_at` - Block where reorg was detected
    /// * `fork_point` - The fork point from `check_for_reorg`
    /// * `orphaned_hash` - Hash we had stored for the detection block
    /// * `new_hash` - Hash from the new chain
    ///
    /// # Returns
    ///
    /// Statistics about the reorg handling.
    ///
    /// # Errors
    ///
    /// Returns an error if the rollback fails.
    #[instrument(skip(self), fields(detected_at = %detected_at.value(), fork_point = %fork_point.value()))]
    pub async fn handle_reorg(
        &self,
        detected_at: BlockNumber,
        fork_point: BlockNumber,
        orphaned_hash: B256,
        new_hash: B256,
    ) -> Result<ReorgStats> {
        let depth = detected_at.value() - fork_point.value();

        warn!(
            detected_at = %detected_at.value(),
            fork_point = %fork_point.value(),
            depth,
            orphaned_hash = %orphaned_hash,
            new_hash = %new_hash,
            "Handling chain reorganization"
        );

        // Execute the rollback
        self.execute_rollback(fork_point).await?;

        let stats = ReorgStats {
            detected_at,
            fork_point,
            depth,
            orphaned_hash,
            new_hash,
        };

        info!(
            depth = stats.depth,
            fork_point = %stats.fork_point.value(),
            "Reorg handled successfully, ready to reprocess from fork point"
        );

        Ok(stats)
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

    /// Mock store for testing reorg handling.
    #[derive(Debug, Default, Clone)]
    struct MockStateStore {
        block_hashes: Arc<Mutex<HashMap<u64, B256>>>,
        rollback_called: Arc<Mutex<Option<BlockNumber>>>,
    }

    #[async_trait::async_trait]
    impl IndexerStateStore for MockStateStore {
        async fn get_last_block(&self) -> Result<BlockNumber> {
            let hashes = self.block_hashes.lock().unwrap();
            let max = hashes.keys().max().copied().unwrap_or(0);
            Ok(BlockNumber::new(max))
        }

        async fn set_last_block(&self, _block: BlockNumber, _hash: B256) -> Result<()> {
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

        async fn execute_reorg_rollback(&self, fork_point: BlockNumber) -> Result<()> {
            let mut called = self.rollback_called.lock().unwrap();
            *called = Some(fork_point);

            // Remove blocks after fork point
            let mut hashes = self.block_hashes.lock().unwrap();
            hashes.retain(|&k, _| k <= fork_point.value());

            Ok(())
        }

        async fn prune_old_blocks(&self, keep_blocks: u64) -> Result<u64> {
            let mut hashes = self.block_hashes.lock().unwrap();
            let max = hashes.keys().max().copied().unwrap_or(0);
            let cutoff = max.saturating_sub(keep_blocks);

            let before = hashes.len();
            hashes.retain(|&k, _| k > cutoff);
            Ok((before - hashes.len()) as u64)
        }
    }

    impl MockStateStore {
        fn with_blocks(blocks: Vec<(u64, B256)>) -> Self {
            let store = Self::default();
            {
                let mut hashes = store.block_hashes.lock().unwrap();
                for (num, hash) in blocks {
                    hashes.insert(num, hash);
                }
            }
            store
        }
    }

    #[test]
    fn constants_are_reasonable() {
        assert!(MAX_REORG_DEPTH >= 64, "Should handle moderate reorgs");
        assert!(MAX_REORG_DEPTH <= 1024, "Don't search forever");
        assert!(
            DEFAULT_BLOCK_RETENTION > MAX_REORG_DEPTH,
            "Should retain more than max reorg depth"
        );
    }

    #[tokio::test]
    async fn check_first_block_returns_first_block() {
        let store = MockStateStore::default();
        let handler = ReorgHandler::new(store);

        let result = handler
            .check_for_reorg(BlockNumber::new(0), B256::ZERO)
            .await
            .unwrap();

        assert_eq!(result, ReorgCheckResult::FirstBlock);
    }

    #[tokio::test]
    async fn check_parent_not_found() {
        let store = MockStateStore::default();
        let handler = ReorgHandler::new(store);

        let result = handler
            .check_for_reorg(BlockNumber::new(100), B256::from([0x11; 32]))
            .await
            .unwrap();

        assert_eq!(result, ReorgCheckResult::ParentNotFound);
    }

    #[tokio::test]
    async fn check_no_reorg_when_hashes_match() {
        let parent_hash = B256::from([0xAA; 32]);
        let store = MockStateStore::with_blocks(vec![(99, parent_hash)]);
        let handler = ReorgHandler::new(store);

        let result = handler
            .check_for_reorg(BlockNumber::new(100), parent_hash)
            .await
            .unwrap();

        assert_eq!(result, ReorgCheckResult::NoReorg);
    }

    #[tokio::test]
    async fn check_reorg_detected_when_hashes_differ() {
        let stored_hash = B256::from([0xAA; 32]);
        let incoming_parent = B256::from([0xBB; 32]);

        let store = MockStateStore::with_blocks(vec![
            (97, B256::from([0x97; 32])),
            (98, B256::from([0x98; 32])),
            (99, stored_hash),
        ]);
        let handler = ReorgHandler::new(store);

        let result = handler
            .check_for_reorg(BlockNumber::new(100), incoming_parent)
            .await
            .unwrap();

        match result {
            ReorgCheckResult::ReorgDetected { fork_point, depth } => {
                // Fork point should be before the mismatch
                assert!(fork_point.value() < 100);
                assert!(depth > 0);
            }
            other => panic!("Expected ReorgDetected, got {other:?}"),
        }
    }

    #[tokio::test]
    async fn record_block_stores_hash() {
        let store = MockStateStore::default();
        let handler = ReorgHandler::new(store.clone());

        let block = BlockNumber::new(100);
        let hash = B256::from([0xAA; 32]);
        let parent = B256::from([0x99; 32]);

        handler.record_block(block, hash, parent, 12345).await.unwrap();

        let stored = store
            .get_block_hash(block)
            .await
            .unwrap()
            .expect("hash should be stored");

        assert_eq!(stored, hash);
    }

    #[tokio::test]
    async fn execute_rollback_calls_store() {
        let store = MockStateStore::with_blocks(vec![
            (100, B256::from([0xAA; 32])),
            (101, B256::from([0xBB; 32])),
            (102, B256::from([0xCC; 32])),
        ]);

        let handler = ReorgHandler::new(store.clone());
        let fork_point = BlockNumber::new(100);

        handler.execute_rollback(fork_point).await.unwrap();

        // Verify rollback was called
        let called = store.rollback_called.lock().unwrap();
        assert_eq!(*called, Some(fork_point));

        // Verify blocks after fork point are gone
        assert!(store.get_block_hash(BlockNumber::new(101)).await.unwrap().is_none());
        assert!(store.get_block_hash(BlockNumber::new(102)).await.unwrap().is_none());

        // Block at fork point should remain
        assert!(store.get_block_hash(BlockNumber::new(100)).await.unwrap().is_some());
    }

    #[tokio::test]
    async fn handle_reorg_returns_stats() {
        let store = MockStateStore::with_blocks(vec![
            (98, B256::from([0x98; 32])),
            (99, B256::from([0x99; 32])),
            (100, B256::from([0xAA; 32])),
        ]);

        let handler = ReorgHandler::new(store);

        let stats = handler
            .handle_reorg(
                BlockNumber::new(101),
                BlockNumber::new(99),
                B256::from([0xAA; 32]),
                B256::from([0xBB; 32]),
            )
            .await
            .unwrap();

        assert_eq!(stats.detected_at.value(), 101);
        assert_eq!(stats.fork_point.value(), 99);
        assert_eq!(stats.depth, 2);
    }

    #[test]
    fn handler_is_send_sync() {
        fn assert_send_sync<T: Send + Sync>() {}
        assert_send_sync::<ReorgHandler<MockStateStore>>();
    }
}
