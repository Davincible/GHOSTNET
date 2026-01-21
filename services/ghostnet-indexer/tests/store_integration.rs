//! Integration tests for PostgresStore with TimescaleDB.
//!
//! These tests run against a real TimescaleDB instance in Docker.
//! They verify that our store implementations work correctly with
//! the actual database schema and TimescaleDB extensions.

mod common;

use alloy::primitives::{B256, U256};

use common::fixtures::{TestDb, death_fixtures, position_fixtures, scan_fixtures};
use ghostnet_indexer::ports::{DeathStore, IndexerStateStore, PositionStore, ScanStore};
use ghostnet_indexer::types::entities::ScanFinalizationData;
use ghostnet_indexer::types::enums::Level;
use ghostnet_indexer::types::primitives::{BlockNumber, TokenAmount};

// ═══════════════════════════════════════════════════════════════════════════════
// POSITION STORE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[tokio::test]
async fn test_position_save_and_get() {
    let db = TestDb::new().await;

    // Create and save a position
    let position = position_fixtures::create_test_position(
        "0x1111111111111111111111111111111111111111",
        Level::Mainframe,
    );
    db.store.save_position(&position).await.unwrap();

    // Retrieve it
    let retrieved = db
        .store
        .get_active_position(&position.user_address)
        .await
        .unwrap();

    assert!(retrieved.is_some());
    let retrieved = retrieved.unwrap();
    assert_eq!(retrieved.user_address, position.user_address);
    assert_eq!(retrieved.level, Level::Mainframe);
    assert!(retrieved.is_alive);
}

#[tokio::test]
async fn test_position_update() {
    let db = TestDb::new().await;

    // Create and save a position
    let mut position = position_fixtures::create_test_position(
        "0x2222222222222222222222222222222222222222",
        Level::Subnet,
    );
    db.store.save_position(&position).await.unwrap();

    // Update the position (add stake)
    position.amount = TokenAmount::from_wei(U256::from(2_000_000_000_000_000_000u128), 18);
    db.store.save_position(&position).await.unwrap();

    // Verify update
    let retrieved = db
        .store
        .get_active_position(&position.user_address)
        .await
        .unwrap()
        .unwrap();

    assert_eq!(
        retrieved.amount.to_wei(18),
        U256::from(2_000_000_000_000_000_000u128)
    );
}

#[tokio::test]
async fn test_get_positions_by_level() {
    let db = TestDb::new().await;

    // Create positions at different levels
    let pos1 = position_fixtures::create_test_position(
        "0x4444444444444444444444444444444444444444",
        Level::Darknet,
    );
    let pos2 = position_fixtures::create_test_position(
        "0x5555555555555555555555555555555555555555",
        Level::Darknet,
    );
    let pos3 = position_fixtures::create_test_position(
        "0x6666666666666666666666666666666666666666",
        Level::Mainframe, // Different level
    );

    db.store.save_position(&pos1).await.unwrap();
    db.store.save_position(&pos2).await.unwrap();
    db.store.save_position(&pos3).await.unwrap();

    // Get positions for Darknet
    let darknet_positions = db
        .store
        .get_positions_by_level(Level::Darknet)
        .await
        .unwrap();

    assert_eq!(darknet_positions.len(), 2);
    // All should be Darknet level
    for pos in &darknet_positions {
        assert_eq!(pos.level, Level::Darknet);
    }

    // Count should match
    let count = db
        .store
        .count_positions_by_level(Level::Darknet)
        .await
        .unwrap();
    assert_eq!(count, 2);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCAN STORE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[tokio::test]
async fn test_scan_save_and_get() {
    let db = TestDb::new().await;

    // Create and save a scan
    let scan = scan_fixtures::create_pending_scan(Level::Mainframe);
    db.store.save_scan(&scan).await.unwrap();

    // Retrieve it
    let retrieved = db.store.get_scan_by_id(&scan.scan_id).await.unwrap();

    assert!(retrieved.is_some());
    let retrieved = retrieved.unwrap();
    assert_eq!(retrieved.scan_id, scan.scan_id);
    assert_eq!(retrieved.level, Level::Mainframe);
    assert!(retrieved.finalized_at.is_none());
}

#[tokio::test]
async fn test_scan_finalize() {
    let db = TestDb::new().await;

    // Create and save a pending scan
    let scan = scan_fixtures::create_pending_scan(Level::Subnet);
    db.store.save_scan(&scan).await.unwrap();

    // Finalize it
    let finalization_data = ScanFinalizationData {
        finalized_at: chrono::Utc::now(),
        death_count: 5,
        total_dead: TokenAmount::from_wei(U256::from(5_000_000_000_000_000_000u128), 18),
        burned: TokenAmount::from_wei(U256::from(500_000_000_000_000_000u128), 18),
        distributed_same_level: TokenAmount::from_wei(
            U256::from(2_000_000_000_000_000_000u128),
            18,
        ),
        distributed_upstream: TokenAmount::from_wei(U256::from(1_500_000_000_000_000_000u128), 18),
        protocol_fee: TokenAmount::from_wei(U256::from(1_000_000_000_000_000_000u128), 18),
        survivor_count: 95,
    };
    db.store
        .finalize_scan(&scan.scan_id, finalization_data)
        .await
        .unwrap();

    // Verify finalization
    let retrieved = db
        .store
        .get_scan_by_id(&scan.scan_id)
        .await
        .unwrap()
        .unwrap();

    assert!(retrieved.finalized_at.is_some());
    assert_eq!(retrieved.death_count, Some(5));
    assert_eq!(retrieved.survivor_count, Some(95));
}

#[tokio::test]
async fn test_get_pending_scans() {
    let db = TestDb::new().await;

    // Create scans
    let pending1 = scan_fixtures::create_pending_scan(Level::Darknet);
    let pending2 = scan_fixtures::create_pending_scan(Level::Mainframe);
    let finalized = scan_fixtures::create_finalized_scan(Level::Subnet, 3);

    db.store.save_scan(&pending1).await.unwrap();
    db.store.save_scan(&pending2).await.unwrap();
    db.store.save_scan(&finalized).await.unwrap();

    // Get pending scans
    let pending = db.store.get_pending_scans().await.unwrap();

    // Should only return the 2 pending scans
    assert_eq!(pending.len(), 2);
    for scan in &pending {
        assert!(scan.finalized_at.is_none());
    }
}

#[tokio::test]
async fn test_get_recent_scans() {
    let db = TestDb::new().await;

    // Create multiple scans for the same level
    for i in 0..5 {
        let scan = scan_fixtures::create_finalized_scan(Level::Darknet, i);
        db.store.save_scan(&scan).await.unwrap();
    }

    // Get recent scans with limit
    let recent = db.store.get_recent_scans(Level::Darknet, 3).await.unwrap();

    assert_eq!(recent.len(), 3);
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEATH STORE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[tokio::test]
async fn test_death_record_and_count() {
    let db = TestDb::new().await;

    // Create deaths
    let deaths = vec![
        death_fixtures::create_test_death(
            "0x7777777777777777777777777777777777777777",
            Level::Darknet,
            1_000_000_000_000_000_000,
        ),
        death_fixtures::create_test_death(
            "0x8888888888888888888888888888888888888888",
            Level::Darknet,
            2_000_000_000_000_000_000,
        ),
    ];

    db.store.record_deaths(&deaths).await.unwrap();

    // Count deaths for level
    let count = db
        .store
        .count_deaths_by_level(Level::Darknet)
        .await
        .unwrap();

    assert_eq!(count, 2);
}

#[tokio::test]
async fn test_get_recent_deaths() {
    let db = TestDb::new().await;

    // Create deaths
    let deaths = vec![
        death_fixtures::create_test_death(
            "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            Level::Darknet,
            1_000_000_000_000_000_000,
        ),
        death_fixtures::create_test_death(
            "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            Level::Subnet,
            2_000_000_000_000_000_000,
        ),
        death_fixtures::create_test_death(
            "0xcccccccccccccccccccccccccccccccccccccccc",
            Level::Mainframe,
            3_000_000_000_000_000_000,
        ),
    ];

    db.store.record_deaths(&deaths).await.unwrap();

    // Get recent deaths
    let recent = db.store.get_recent_deaths(2).await.unwrap();

    assert_eq!(recent.len(), 2);
}

#[tokio::test]
async fn test_death_linked_to_scan() {
    let db = TestDb::new().await;

    // Create a scan first
    let scan = scan_fixtures::create_pending_scan(Level::Subnet);
    db.store.save_scan(&scan).await.unwrap();

    // Create a position
    let position = position_fixtures::create_test_position(
        "0x9999999999999999999999999999999999999999",
        Level::Subnet,
    );
    db.store.save_position(&position).await.unwrap();

    // Create death linked to scan
    let death = death_fixtures::create_death_for_scan(
        "0x9999999999999999999999999999999999999999",
        Level::Subnet,
        scan.id,
        position.id,
    );
    db.store.record_deaths(&[death]).await.unwrap();

    // Get deaths for scan (using on-chain scan_id, not UUID)
    let deaths = db.store.get_deaths_for_scan(&scan.scan_id).await.unwrap();

    assert_eq!(deaths.len(), 1);
    assert_eq!(deaths[0].scan_id, Some(scan.id));
    assert_eq!(deaths[0].position_id, Some(position.id));
}

// ═══════════════════════════════════════════════════════════════════════════════
// INDEXER STATE STORE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[tokio::test]
async fn test_block_tracking() {
    let db = TestDb::new().await;

    // Set last block
    let block = BlockNumber::new(12345);
    let hash = B256::from([0x42; 32]);
    db.store.set_last_block(block, hash).await.unwrap();

    // Get last block
    let last = db.store.get_last_block().await.unwrap();
    assert_eq!(last.value(), 12345);
}

#[tokio::test]
async fn test_block_hash_storage() {
    let db = TestDb::new().await;

    // Insert block hashes
    let block1 = BlockNumber::new(100);
    let hash1 = B256::from([0x01; 32]);
    let parent1 = B256::from([0x00; 32]);

    let block2 = BlockNumber::new(101);
    let hash2 = B256::from([0x02; 32]);

    db.store
        .insert_block_hash(block1, hash1, parent1, 1000)
        .await
        .unwrap();
    db.store
        .insert_block_hash(block2, hash2, hash1, 1001)
        .await
        .unwrap();

    // Retrieve and verify
    let retrieved = db.store.get_block_hash(block1).await.unwrap();
    assert_eq!(retrieved, Some(hash1));

    let retrieved2 = db.store.get_block_hash(block2).await.unwrap();
    assert_eq!(retrieved2, Some(hash2));
}

#[tokio::test]
async fn test_reorg_rollback() {
    let db = TestDb::new().await;

    // Insert block hashes for blocks 100-105
    for i in 100..=105 {
        let block = BlockNumber::new(i);
        let hash = B256::from([i as u8; 32]);
        let parent = if i == 100 {
            B256::ZERO
        } else {
            B256::from([(i - 1) as u8; 32])
        };
        db.store
            .insert_block_hash(block, hash, parent, i * 10)
            .await
            .unwrap();
        db.store.set_last_block(block, hash).await.unwrap();
    }

    // Simulate reorg at block 103
    let fork_point = BlockNumber::new(102);
    db.store.execute_reorg_rollback(fork_point).await.unwrap();

    // Verify blocks after fork point are deleted
    assert!(
        db.store
            .get_block_hash(BlockNumber::new(103))
            .await
            .unwrap()
            .is_none()
    );
    assert!(
        db.store
            .get_block_hash(BlockNumber::new(104))
            .await
            .unwrap()
            .is_none()
    );

    // Verify blocks at and before fork point still exist
    assert!(
        db.store
            .get_block_hash(BlockNumber::new(102))
            .await
            .unwrap()
            .is_some()
    );
    assert!(
        db.store
            .get_block_hash(BlockNumber::new(101))
            .await
            .unwrap()
            .is_some()
    );
}

#[tokio::test]
async fn test_prune_old_blocks() {
    let db = TestDb::new().await;

    // Insert 100 block hashes
    for i in 1..=100 {
        let block = BlockNumber::new(i);
        let hash = B256::from([i as u8; 32]);
        let parent = if i == 1 {
            B256::ZERO
        } else {
            B256::from([(i - 1) as u8; 32])
        };
        db.store
            .insert_block_hash(block, hash, parent, i * 10)
            .await
            .unwrap();
    }

    // Prune, keeping only last 50 blocks
    let pruned = db.store.prune_old_blocks(50).await.unwrap();

    // Should have pruned ~50 blocks
    assert!(pruned > 0);

    // Old blocks should be gone
    assert!(
        db.store
            .get_block_hash(BlockNumber::new(1))
            .await
            .unwrap()
            .is_none()
    );

    // Recent blocks should still exist
    assert!(
        db.store
            .get_block_hash(BlockNumber::new(100))
            .await
            .unwrap()
            .is_some()
    );
}

// ═══════════════════════════════════════════════════════════════════════════════
// TIMESCALEDB-SPECIFIC TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[tokio::test]
async fn test_timescaledb_extension_loaded() {
    let db = TestDb::new().await;

    // Verify TimescaleDB extension is available
    let result: (String,) =
        sqlx::query_as("SELECT extname FROM pg_extension WHERE extname = 'timescaledb'")
            .fetch_one(&db.pool)
            .await
            .unwrap();

    assert_eq!(result.0, "timescaledb");
}

#[tokio::test]
async fn test_hypertables_created() {
    let db = TestDb::new().await;

    // positions is now a REGULAR TABLE (not a hypertable)
    // Reason: Entity with frequent updates - hypertables with compression are slow for updates
    let result: Option<(String,)> = sqlx::query_as(
        "SELECT hypertable_name FROM timescaledb_information.hypertables WHERE hypertable_name = 'positions'"
    )
    .fetch_optional(&db.pool)
    .await
    .unwrap();

    assert!(result.is_none(), "positions should NOT be a hypertable (has updates)");

    // Check position_history hypertable (append-only audit trail)
    let result: Option<(String,)> = sqlx::query_as(
        "SELECT hypertable_name FROM timescaledb_information.hypertables WHERE hypertable_name = 'position_history'"
    )
    .fetch_optional(&db.pool)
    .await
    .unwrap();

    assert!(result.is_some(), "position_history should be a hypertable");

    // Check deaths hypertable (append-only events)
    let result: Option<(String,)> = sqlx::query_as(
        "SELECT hypertable_name FROM timescaledb_information.hypertables WHERE hypertable_name = 'deaths'"
    )
    .fetch_optional(&db.pool)
    .await
    .unwrap();

    assert!(result.is_some(), "deaths should be a hypertable");

    // Check block_history hypertable (auto-pruned)
    let result: Option<(String,)> = sqlx::query_as(
        "SELECT hypertable_name FROM timescaledb_information.hypertables WHERE hypertable_name = 'block_history'"
    )
    .fetch_optional(&db.pool)
    .await
    .unwrap();

    assert!(result.is_some(), "block_history should be a hypertable");

    // Verify scans is a regular table (not a hypertable)
    // Reason: Low volume, needs unique constraint on scan_id
    let result: Option<(String,)> = sqlx::query_as(
        "SELECT hypertable_name FROM timescaledb_information.hypertables WHERE hypertable_name = 'scans'"
    )
    .fetch_optional(&db.pool)
    .await
    .unwrap();

    assert!(
        result.is_none(),
        "scans should NOT be a hypertable (needs unique constraint on scan_id)"
    );
}
