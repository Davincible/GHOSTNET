//! Full flow integration tests: Event Log → EventRouter → Handler → DB
//!
//! These tests verify the complete indexing pipeline by:
//! 1. Creating realistic event logs using ABI bindings
//! 2. Routing them through the EventRouter
//! 3. Processing with real handlers + PostgresStore
//! 4. Verifying data was persisted correctly
//!
//! This tests Phase 3.14 of the implementation plan.

mod common;

use std::sync::Arc;

use alloy::primitives::{Address, B256, U256};
use alloy::rpc::types::Log;
use alloy::sol_types::SolEvent;
use chrono::Utc;

use common::fixtures::TestDb;
use ghostnet_indexer::abi::ghost_core;
use ghostnet_indexer::handlers::{
    DeathHandler, EmissionsHandler, FeeHandler, MarketHandler, PositionHandler, ScanHandler,
    TokenHandler,
};
use ghostnet_indexer::indexer::EventRouter;
use ghostnet_indexer::ports::{MockCache, PositionStore};
use ghostnet_indexer::types::enums::Level;
use ghostnet_indexer::types::events::EventMetadata;

// ═══════════════════════════════════════════════════════════════════════════════
// TEST HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Create a test event metadata for a given block.
fn create_metadata(block_number: u64) -> EventMetadata {
    EventMetadata {
        block_number,
        block_hash: B256::from([block_number as u8; 32]),
        tx_hash: B256::from([0xAB; 32]),
        tx_index: 0,
        log_index: 0,
        timestamp: Utc::now(),
        contract: Address::ZERO,
    }
}

/// Create a JackedIn event log.
fn create_jacked_in_log(user: Address, amount: U256, level: u8, new_total: U256) -> Log {
    let event = ghost_core::JackedIn {
        user,
        amount,
        level,
        newTotal: new_total,
    };

    // Encode the event to a primitive log
    let primitive_log = event.encode_log_data();

    // Create the RPC log type
    Log {
        inner: alloy::primitives::Log {
            address: Address::ZERO,
            data: primitive_log,
        },
        block_hash: Some(B256::from([0x01; 32])),
        block_number: Some(100),
        block_timestamp: Some(1234567890),
        transaction_hash: Some(B256::from([0xAB; 32])),
        transaction_index: Some(0),
        log_index: Some(0),
        removed: false,
    }
}

/// Create a StakeAdded event log.
fn create_stake_added_log(user: Address, amount: U256, new_total: U256) -> Log {
    let event = ghost_core::StakeAdded {
        user,
        amount,
        newTotal: new_total,
    };

    let primitive_log = event.encode_log_data();

    Log {
        inner: alloy::primitives::Log {
            address: Address::ZERO,
            data: primitive_log,
        },
        block_hash: Some(B256::from([0x02; 32])),
        block_number: Some(101),
        block_timestamp: Some(1234567900),
        transaction_hash: Some(B256::from([0xCD; 32])),
        transaction_index: Some(0),
        log_index: Some(0),
        removed: false,
    }
}

/// Create an Extracted event log.
fn create_extracted_log(user: Address, amount: U256, rewards: U256) -> Log {
    let event = ghost_core::Extracted {
        user,
        amount,
        rewards,
    };

    let primitive_log = event.encode_log_data();

    Log {
        inner: alloy::primitives::Log {
            address: Address::ZERO,
            data: primitive_log,
        },
        block_hash: Some(B256::from([0x03; 32])),
        block_number: Some(102),
        block_timestamp: Some(1234567910),
        transaction_hash: Some(B256::from([0xEF; 32])),
        transaction_index: Some(0),
        log_index: Some(0),
        removed: false,
    }
}

/// Create a router with all handlers wired to the test database.
fn create_router_with_db(
    db: &TestDb,
) -> EventRouter<
    PositionHandler<ghostnet_indexer::store::PostgresStore, MockCache>,
    ScanHandler<ghostnet_indexer::store::PostgresStore, MockCache>,
    DeathHandler<
        ghostnet_indexer::store::PostgresStore,
        ghostnet_indexer::store::PostgresStore,
        MockCache,
    >,
    MarketHandler<ghostnet_indexer::store::PostgresStore, MockCache>,
    TokenHandler<MockCache>,
    FeeHandler<MockCache>,
    EmissionsHandler<MockCache>,
> {
    let store = Arc::new(db.store.clone());
    let cache = Arc::new(MockCache::new());

    let position_handler = PositionHandler::new(store.clone(), cache.clone());
    let scan_handler = ScanHandler::new(store.clone(), cache.clone());
    let death_handler = DeathHandler::new(store.clone(), store.clone(), cache.clone());
    let market_handler = MarketHandler::new(store.clone(), cache.clone());
    let token_handler = TokenHandler::new(cache.clone());
    let fee_handler = FeeHandler::new(cache.clone());
    let emissions_handler = EmissionsHandler::new(cache.clone());

    EventRouter::new(
        position_handler,
        scan_handler,
        death_handler,
        market_handler,
        token_handler,
        fee_handler,
        emissions_handler,
    )
}

// ═══════════════════════════════════════════════════════════════════════════════
// POSITION LIFECYCLE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[tokio::test]
async fn test_full_flow_jacked_in_creates_position() {
    let db = TestDb::new().await;
    let router = create_router_with_db(&db);

    // Create a JackedIn event
    let user = Address::from([0x11; 20]);
    let amount = U256::from(1_000_000_000_000_000_000u128); // 1 DATA
    let level = 2u8; // Mainframe
    let new_total = amount;

    let log = create_jacked_in_log(user, amount, level, new_total);
    let meta = create_metadata(100);

    // Route the event
    let handled = router.route_log(&log, meta).await.unwrap();
    assert!(handled, "JackedIn event should be handled");

    // Verify position was created in database
    let eth_addr = ghostnet_indexer::types::primitives::EthAddress::new(user.0.0);
    let position = db
        .store
        .get_active_position(&eth_addr)
        .await
        .unwrap()
        .expect("position should exist");

    assert_eq!(position.level, Level::Mainframe);
    assert!(position.is_alive);
    assert!(!position.is_extracted);
    assert_eq!(position.amount.to_wei(18), amount);
}

#[tokio::test]
async fn test_full_flow_stake_added_updates_position() {
    let db = TestDb::new().await;
    let router = create_router_with_db(&db);

    let user = Address::from([0x22; 20]);
    let initial_amount = U256::from(1_000_000_000_000_000_000u128); // 1 DATA
    let added_amount = U256::from(500_000_000_000_000_000u128); // 0.5 DATA
    let new_total = initial_amount + added_amount;

    // First, create a position with JackedIn
    let jack_in_log = create_jacked_in_log(user, initial_amount, 3, initial_amount); // Subnet
    let meta1 = create_metadata(100);
    router.route_log(&jack_in_log, meta1).await.unwrap();

    // Then add stake
    let stake_log = create_stake_added_log(user, added_amount, new_total);
    let meta2 = create_metadata(101);
    let handled = router.route_log(&stake_log, meta2).await.unwrap();
    assert!(handled, "StakeAdded event should be handled");

    // Verify position was updated
    let eth_addr = ghostnet_indexer::types::primitives::EthAddress::new(user.0.0);
    let position = db
        .store
        .get_active_position(&eth_addr)
        .await
        .unwrap()
        .expect("position should exist");

    assert_eq!(position.amount.to_wei(18), new_total);
    assert!(position.is_alive);
}

#[tokio::test]
async fn test_full_flow_extracted_closes_position() {
    let db = TestDb::new().await;
    let router = create_router_with_db(&db);

    let user = Address::from([0x33; 20]);
    let amount = U256::from(1_000_000_000_000_000_000u128); // 1 DATA
    let rewards = U256::from(100_000_000_000_000_000u128); // 0.1 DATA

    // First, create a position
    let jack_in_log = create_jacked_in_log(user, amount, 4, amount); // Darknet
    let meta1 = create_metadata(100);
    router.route_log(&jack_in_log, meta1).await.unwrap();

    // Verify position exists
    let eth_addr = ghostnet_indexer::types::primitives::EthAddress::new(user.0.0);
    let position_before = db
        .store
        .get_active_position(&eth_addr)
        .await
        .unwrap()
        .expect("position should exist");
    assert!(position_before.is_alive);

    // Extract the position
    let extract_log = create_extracted_log(user, amount, rewards);
    let meta2 = create_metadata(102);
    let handled = router.route_log(&extract_log, meta2).await.unwrap();
    assert!(handled, "Extracted event should be handled");

    // Verify position was closed (no active position)
    let position_after = db.store.get_active_position(&eth_addr).await.unwrap();
    assert!(
        position_after.is_none(),
        "active position should be None after extraction"
    );
}

#[tokio::test]
async fn test_full_flow_multiple_users_independent() {
    let db = TestDb::new().await;
    let router = create_router_with_db(&db);

    // Create positions for multiple users at different levels
    let users = [
        (Address::from([0x44; 20]), 2u8), // Mainframe
        (Address::from([0x55; 20]), 3u8), // Subnet
        (Address::from([0x66; 20]), 4u8), // Darknet
    ];

    for (i, (user, level)) in users.iter().enumerate() {
        let amount = U256::from((i as u128 + 1) * 1_000_000_000_000_000_000u128);
        let log = create_jacked_in_log(*user, amount, *level, amount);
        let meta = create_metadata(100 + i as u64);
        router.route_log(&log, meta).await.unwrap();
    }

    // Verify each position
    for (i, (user, expected_level)) in users.iter().enumerate() {
        let eth_addr = ghostnet_indexer::types::primitives::EthAddress::new(user.0.0);
        let position = db
            .store
            .get_active_position(&eth_addr)
            .await
            .unwrap()
            .expect("position should exist");

        let expected = Level::try_from(*expected_level).unwrap();
        assert_eq!(
            position.level, expected,
            "user {} should have correct level",
            i
        );
        assert!(position.is_alive);
    }

    // Verify counts by level
    let mainframe_count = db
        .store
        .count_positions_by_level(Level::Mainframe)
        .await
        .unwrap();
    let subnet_count = db
        .store
        .count_positions_by_level(Level::Subnet)
        .await
        .unwrap();
    let darknet_count = db
        .store
        .count_positions_by_level(Level::Darknet)
        .await
        .unwrap();

    assert_eq!(mainframe_count, 1);
    assert_eq!(subnet_count, 1);
    assert_eq!(darknet_count, 1);
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVENT ROUTING TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[tokio::test]
async fn test_unknown_event_not_handled() {
    let db = TestDb::new().await;
    let router = create_router_with_db(&db);

    // Create a log with an unknown topic
    let log = Log {
        inner: alloy::primitives::Log {
            address: Address::ZERO,
            data: alloy::primitives::LogData::new(
                vec![B256::from([0xFF; 32])], // Unknown signature
                alloy::primitives::Bytes::new(),
            )
            .unwrap(),
        },
        block_hash: Some(B256::from([0x01; 32])),
        block_number: Some(100),
        block_timestamp: Some(1234567890),
        transaction_hash: Some(B256::from([0xAB; 32])),
        transaction_index: Some(0),
        log_index: Some(0),
        removed: false,
    };

    let meta = create_metadata(100);
    let handled = router.route_log(&log, meta).await.unwrap();

    assert!(!handled, "Unknown event should return false (not handled)");
}

#[tokio::test]
async fn test_empty_log_not_handled() {
    let db = TestDb::new().await;
    let router = create_router_with_db(&db);

    // Create a log with no topics
    let log = Log {
        inner: alloy::primitives::Log {
            address: Address::ZERO,
            data: alloy::primitives::LogData::new(vec![], alloy::primitives::Bytes::new()).unwrap(),
        },
        block_hash: Some(B256::from([0x01; 32])),
        block_number: Some(100),
        block_timestamp: Some(1234567890),
        transaction_hash: Some(B256::from([0xAB; 32])),
        transaction_index: Some(0),
        log_index: Some(0),
        removed: false,
    };

    let meta = create_metadata(100);
    let handled = router.route_log(&log, meta).await.unwrap();

    assert!(!handled, "Empty log (no topics) should return false");
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMPLETE LIFECYCLE TEST
// ═══════════════════════════════════════════════════════════════════════════════

#[tokio::test]
async fn test_full_position_lifecycle() {
    let db = TestDb::new().await;
    let router = create_router_with_db(&db);

    let user = Address::from([0x77; 20]);
    let eth_addr = ghostnet_indexer::types::primitives::EthAddress::new(user.0.0);

    // Step 1: Jack in
    let initial = U256::from(2_000_000_000_000_000_000u128); // 2 DATA
    let jack_in_log = create_jacked_in_log(user, initial, 3, initial); // Subnet
    router
        .route_log(&jack_in_log, create_metadata(100))
        .await
        .unwrap();

    let pos = db
        .store
        .get_active_position(&eth_addr)
        .await
        .unwrap()
        .unwrap();
    assert_eq!(pos.level, Level::Subnet);
    assert_eq!(pos.amount.to_wei(18), initial);

    // Step 2: Add stake
    let added = U256::from(1_000_000_000_000_000_000u128); // 1 DATA
    let stake_log = create_stake_added_log(user, added, initial + added);
    router
        .route_log(&stake_log, create_metadata(101))
        .await
        .unwrap();

    let pos = db
        .store
        .get_active_position(&eth_addr)
        .await
        .unwrap()
        .unwrap();
    assert_eq!(pos.amount.to_wei(18), initial + added);

    // Step 3: Extract
    let rewards = U256::from(300_000_000_000_000_000u128); // 0.3 DATA rewards
    let extract_log = create_extracted_log(user, initial + added, rewards);
    router
        .route_log(&extract_log, create_metadata(102))
        .await
        .unwrap();

    let pos = db.store.get_active_position(&eth_addr).await.unwrap();
    assert!(pos.is_none(), "Position should be closed after extraction");

    // Step 4: Jack in again (new position)
    let new_amount = U256::from(5_000_000_000_000_000_000u128); // 5 DATA
    let jack_in_log2 = create_jacked_in_log(user, new_amount, 4, new_amount); // Darknet
    router
        .route_log(&jack_in_log2, create_metadata(103))
        .await
        .unwrap();

    let pos = db
        .store
        .get_active_position(&eth_addr)
        .await
        .unwrap()
        .unwrap();
    assert_eq!(pos.level, Level::Darknet);
    assert_eq!(pos.amount.to_wei(18), new_amount);
}
