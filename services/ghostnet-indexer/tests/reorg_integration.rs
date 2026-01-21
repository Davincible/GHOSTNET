//! Integration tests for reorg handling and checkpoint management.
//!
//! These tests verify the full reorg detection and rollback flow
//! using a real TimescaleDB instance.

mod common;

use alloy::primitives::B256;

use common::fixtures::{position_fixtures, TestDb};
use ghostnet_indexer::indexer::{
    CheckpointManager, RecoveryMode, ReorgCheckResult, ReorgHandler,
};
use ghostnet_indexer::ports::{IndexerStateStore, PositionStore};
use ghostnet_indexer::types::enums::Level;
use ghostnet_indexer::types::primitives::BlockNumber;

// ═══════════════════════════════════════════════════════════════════════════════
// REORG HANDLER INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[tokio::test]
async fn test_reorg_detection_no_reorg() {
    let db = TestDb::new().await;

    // Set up a chain of blocks: 100 -> 101 -> 102
    let hash_100 = B256::from([0x10; 32]);
    let hash_101 = B256::from([0x11; 32]);
    let hash_102 = B256::from([0x12; 32]);

    db.store
        .insert_block_hash(BlockNumber::new(100), hash_100, B256::ZERO, 1000)
        .await
        .unwrap();
    db.store
        .insert_block_hash(BlockNumber::new(101), hash_101, hash_100, 1001)
        .await
        .unwrap();
    db.store
        .insert_block_hash(BlockNumber::new(102), hash_102, hash_101, 1002)
        .await
        .unwrap();

    // Create reorg handler
    let handler = ReorgHandler::new(db.store.clone());

    // Check if block 103 with correct parent causes reorg - it shouldn't
    let result = handler
        .check_for_reorg(BlockNumber::new(103), hash_102)
        .await
        .unwrap();

    assert_eq!(result, ReorgCheckResult::NoReorg);
}

#[tokio::test]
async fn test_reorg_detection_parent_mismatch() {
    let db = TestDb::new().await;

    // Set up a chain
    let hash_100 = B256::from([0x10; 32]);
    let hash_101 = B256::from([0x11; 32]);
    let hash_102 = B256::from([0x12; 32]);

    db.store
        .insert_block_hash(BlockNumber::new(100), hash_100, B256::ZERO, 1000)
        .await
        .unwrap();
    db.store
        .insert_block_hash(BlockNumber::new(101), hash_101, hash_100, 1001)
        .await
        .unwrap();
    db.store
        .insert_block_hash(BlockNumber::new(102), hash_102, hash_101, 1002)
        .await
        .unwrap();

    let handler = ReorgHandler::new(db.store.clone());

    // Try to process block 103 with a DIFFERENT parent hash
    let wrong_parent = B256::from([0xFF; 32]);
    let result = handler
        .check_for_reorg(BlockNumber::new(103), wrong_parent)
        .await
        .unwrap();

    // Should detect a reorg
    match result {
        ReorgCheckResult::ReorgDetected { fork_point, depth } => {
            // Current implementation uses from_block.prev().prev() = 103 - 2 = 101
            // This is a simplified placeholder; real implementation would walk both chains.
            assert_eq!(fork_point.value(), 101, "fork point should be two blocks before detection");
            assert_eq!(depth, 2, "depth should match distance from detection to fork point");
        }
        other => panic!("Expected ReorgDetected, got {other:?}"),
    }
}

#[tokio::test]
async fn test_reorg_detection_first_block() {
    let db = TestDb::new().await;
    let handler = ReorgHandler::new(db.store.clone());

    // Block 0 should be considered FirstBlock (no parent to check)
    let result = handler
        .check_for_reorg(BlockNumber::new(0), B256::ZERO)
        .await
        .unwrap();

    assert_eq!(result, ReorgCheckResult::FirstBlock);
}

#[tokio::test]
async fn test_reorg_detection_parent_not_found() {
    let db = TestDb::new().await;
    let handler = ReorgHandler::new(db.store.clone());

    // No blocks stored, so parent won't be found
    let result = handler
        .check_for_reorg(BlockNumber::new(100), B256::from([0xAA; 32]))
        .await
        .unwrap();

    assert_eq!(result, ReorgCheckResult::ParentNotFound);
}

#[tokio::test]
async fn test_rollback_clears_blocks_after_fork_point() {
    let db = TestDb::new().await;

    // Set up blocks 100-105
    for i in 100..=105 {
        let hash = B256::from([i as u8; 32]);
        let parent = if i == 100 {
            B256::ZERO
        } else {
            B256::from([(i - 1) as u8; 32])
        };
        db.store
            .insert_block_hash(BlockNumber::new(i), hash, parent, i * 10)
            .await
            .unwrap();
    }

    let handler = ReorgHandler::new(db.store.clone());

    // Execute rollback to block 102
    handler
        .execute_rollback(BlockNumber::new(102))
        .await
        .unwrap();

    // Blocks 103-105 should be gone
    for i in 103..=105 {
        let hash = db.store.get_block_hash(BlockNumber::new(i)).await.unwrap();
        assert!(hash.is_none(), "Block {i} should have been rolled back");
    }

    // Blocks 100-102 should still exist
    for i in 100..=102 {
        let hash = db.store.get_block_hash(BlockNumber::new(i)).await.unwrap();
        assert!(hash.is_some(), "Block {i} should still exist");
    }
}

#[tokio::test]
async fn test_record_block_stores_hash() {
    let db = TestDb::new().await;
    let handler = ReorgHandler::new(db.store.clone());

    let block = BlockNumber::new(100);
    let hash = B256::from([0xAA; 32]);
    let parent = B256::from([0x99; 32]);

    handler
        .record_block(block, hash, parent, 12345)
        .await
        .unwrap();

    // Verify it was stored
    let stored = db
        .store
        .get_block_hash(block)
        .await
        .unwrap()
        .expect("hash should be stored");

    assert_eq!(stored, hash);
}

#[tokio::test]
async fn test_handle_reorg_full_flow() {
    let db = TestDb::new().await;

    // Set up a chain
    let hash_100 = B256::from([0x10; 32]);
    let hash_101 = B256::from([0x11; 32]);
    let hash_102 = B256::from([0x12; 32]);

    db.store
        .insert_block_hash(BlockNumber::new(100), hash_100, B256::ZERO, 1000)
        .await
        .unwrap();
    db.store
        .insert_block_hash(BlockNumber::new(101), hash_101, hash_100, 1001)
        .await
        .unwrap();
    db.store
        .insert_block_hash(BlockNumber::new(102), hash_102, hash_101, 1002)
        .await
        .unwrap();

    let handler = ReorgHandler::new(db.store.clone());

    // Handle a reorg
    let new_hash = B256::from([0xBB; 32]);
    let stats = handler
        .handle_reorg(
            BlockNumber::new(103),
            BlockNumber::new(100),
            hash_102,
            new_hash,
        )
        .await
        .unwrap();

    // Verify stats
    assert_eq!(stats.detected_at.value(), 103);
    assert_eq!(stats.fork_point.value(), 100);
    assert_eq!(stats.depth, 3);
    assert_eq!(stats.orphaned_hash, hash_102);
    assert_eq!(stats.new_hash, new_hash);

    // Blocks after fork point should be gone
    assert!(db
        .store
        .get_block_hash(BlockNumber::new(101))
        .await
        .unwrap()
        .is_none());
    assert!(db
        .store
        .get_block_hash(BlockNumber::new(102))
        .await
        .unwrap()
        .is_none());
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHECKPOINT MANAGER INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[tokio::test]
async fn test_checkpoint_load_empty() {
    let db = TestDb::new().await;
    let manager = CheckpointManager::new(db.store.clone());

    let state = manager.load().await.unwrap();

    assert!(state.is_empty());
    assert_eq!(state.last_block.value(), 0);
    assert!(state.last_hash.is_none());
}

#[tokio::test]
async fn test_checkpoint_update_and_load() {
    let db = TestDb::new().await;
    let manager = CheckpointManager::new(db.store.clone());

    let block = BlockNumber::new(100);
    let hash = B256::from([0xAA; 32]);

    // Update checkpoint
    manager.update(block, hash).await.unwrap();

    // Also store the block hash so load can find it
    db.store
        .insert_block_hash(block, hash, B256::ZERO, 1000)
        .await
        .unwrap();

    // Load it back
    let state = manager.load().await.unwrap();

    assert!(!state.is_empty());
    assert_eq!(state.last_block.value(), 100);
    assert_eq!(state.last_hash, Some(hash));
}

#[tokio::test]
async fn test_checkpoint_get_start_block_resume_empty() {
    let db = TestDb::new().await;
    let manager = CheckpointManager::new(db.store.clone())
        .with_min_block(BlockNumber::new(1000));

    let start = manager.get_start_block().await.unwrap();

    // Should use min_block when no checkpoint exists
    assert_eq!(start.value(), 1000);
}

#[tokio::test]
async fn test_checkpoint_get_start_block_resume_existing() {
    let db = TestDb::new().await;
    let manager = CheckpointManager::new(db.store.clone());

    // Set a checkpoint
    let block = BlockNumber::new(500);
    let hash = B256::from([0xBB; 32]);
    manager.update(block, hash).await.unwrap();
    db.store
        .insert_block_hash(block, hash, B256::ZERO, 5000)
        .await
        .unwrap();

    let start = manager.get_start_block().await.unwrap();

    // Should resume from checkpoint + 1
    assert_eq!(start.value(), 501);
}

#[tokio::test]
async fn test_checkpoint_reindex_from_mode() {
    let db = TestDb::new().await;

    // Set a checkpoint at 500
    let hash = B256::from([0xBB; 32]);
    db.store
        .set_last_block(BlockNumber::new(500), hash)
        .await
        .unwrap();

    let manager = CheckpointManager::new(db.store.clone())
        .with_recovery_mode(RecoveryMode::ReindexFrom(BlockNumber::new(100)));

    let start = manager.get_start_block().await.unwrap();

    // Should use the ReindexFrom block regardless of checkpoint
    assert_eq!(start.value(), 100);
}

#[tokio::test]
async fn test_checkpoint_genesis_mode() {
    let db = TestDb::new().await;

    // Set a checkpoint at 500
    let hash = B256::from([0xBB; 32]);
    db.store
        .set_last_block(BlockNumber::new(500), hash)
        .await
        .unwrap();

    let manager = CheckpointManager::new(db.store.clone())
        .with_recovery_mode(RecoveryMode::Genesis);

    let start = manager.get_start_block().await.unwrap();

    // Genesis mode should start from 0
    assert_eq!(start.value(), 0);
}

#[tokio::test]
async fn test_checkpoint_min_block_overrides_genesis() {
    let db = TestDb::new().await;

    let manager = CheckpointManager::new(db.store.clone())
        .with_recovery_mode(RecoveryMode::Genesis)
        .with_min_block(BlockNumber::new(1000));

    let start = manager.get_start_block().await.unwrap();

    // Min block should override genesis
    assert_eq!(start.value(), 1000);
}

#[tokio::test]
async fn test_checkpoint_reset_after_rollback() {
    let db = TestDb::new().await;
    let manager = CheckpointManager::new(db.store.clone());

    // Set up blocks 400 and 500
    let hash_400 = B256::from([0x40; 32]);
    let hash_500 = B256::from([0x50; 32]);

    db.store
        .insert_block_hash(BlockNumber::new(400), hash_400, B256::ZERO, 4000)
        .await
        .unwrap();
    db.store
        .insert_block_hash(BlockNumber::new(500), hash_500, hash_400, 5000)
        .await
        .unwrap();

    // Set checkpoint at 500
    manager.update(BlockNumber::new(500), hash_500).await.unwrap();

    // Simulate reorg: first execute rollback (which clears indexer_state after fork)
    db.store
        .execute_reorg_rollback(BlockNumber::new(400))
        .await
        .unwrap();

    // Then reset checkpoint to fork point
    manager.reset_to(BlockNumber::new(400), hash_400).await.unwrap();

    // Load and verify - checkpoint should be at 400
    let state = manager.load().await.unwrap();
    assert_eq!(state.last_block.value(), 400);
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMBINED REORG + CHECKPOINT TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[tokio::test]
async fn test_full_reorg_workflow_with_positions() {
    let db = TestDb::new().await;

    // 1. Create positions in blocks 100-102
    let pos1 = position_fixtures::create_test_position(
        "0x1111111111111111111111111111111111111111",
        Level::Mainframe,
    );
    let pos2 = position_fixtures::create_test_position(
        "0x2222222222222222222222222222222222222222",
        Level::Subnet,
    );

    db.store.save_position(&pos1).await.unwrap();
    db.store.save_position(&pos2).await.unwrap();

    // 2. Set up block hashes
    let hash_100 = B256::from([0x10; 32]);
    let hash_101 = B256::from([0x11; 32]);
    let hash_102 = B256::from([0x12; 32]);

    db.store
        .insert_block_hash(BlockNumber::new(100), hash_100, B256::ZERO, 1000)
        .await
        .unwrap();
    db.store
        .insert_block_hash(BlockNumber::new(101), hash_101, hash_100, 1001)
        .await
        .unwrap();
    db.store
        .insert_block_hash(BlockNumber::new(102), hash_102, hash_101, 1002)
        .await
        .unwrap();

    // 3. Set checkpoint at block 102
    let checkpoint_manager = CheckpointManager::new(db.store.clone());
    checkpoint_manager
        .update(BlockNumber::new(102), hash_102)
        .await
        .unwrap();

    // 4. Detect and handle reorg
    let reorg_handler = ReorgHandler::new(db.store.clone());

    // Simulate receiving block 103 with wrong parent
    let wrong_parent = B256::from([0xFF; 32]);
    let result = reorg_handler
        .check_for_reorg(BlockNumber::new(103), wrong_parent)
        .await
        .unwrap();

    match result {
        ReorgCheckResult::ReorgDetected { fork_point, .. } => {
            // Execute rollback
            reorg_handler.execute_rollback(fork_point).await.unwrap();

            // Reset checkpoint to fork point
            let fork_hash = db
                .store
                .get_block_hash(fork_point)
                .await
                .unwrap()
                .expect("fork point block hash should exist after rollback");
            checkpoint_manager
                .reset_to(fork_point, fork_hash)
                .await
                .unwrap();
        }
        _ => panic!("Expected reorg to be detected"),
    }

    // 5. Verify blocks after fork point are gone
    assert!(db
        .store
        .get_block_hash(BlockNumber::new(102))
        .await
        .unwrap()
        .is_none());

    // 6. Verify positions are NOT rolled back (known limitation)
    // Positions don't track block numbers, so they persist after reorg.
    // See TODO in execute_reorg_rollback() for future implementation.
    let pos1_after = db
        .store
        .get_active_position(&pos1.user_address)
        .await
        .unwrap();
    assert!(
        pos1_after.is_some(),
        "positions should persist after rollback (known limitation)"
    );
}
