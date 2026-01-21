//! Test fixtures for integration tests.
//!
//! Uses rstest for pytest-style fixtures.

use sqlx::PgPool;
use testcontainers::ContainerAsync;
use testcontainers::runners::AsyncRunner;

use super::containers::{TimescaleDb, build_connection_string};
use ghostnet_indexer::store::PostgresStore;

/// A test database instance with pool and container.
///
/// The container is kept alive as long as this struct exists.
/// When dropped, the container is automatically stopped.
pub struct TestDb {
    /// The connection pool to the test database.
    pub pool: PgPool,
    /// The PostgresStore wrapping the pool.
    pub store: PostgresStore,
    /// The container (kept alive for the duration of the test).
    _container: ContainerAsync<TimescaleDb>,
}

impl TestDb {
    /// Create a new test database with a fresh TimescaleDB container.
    ///
    /// This will:
    /// 1. Start a TimescaleDB container
    /// 2. Connect to it
    /// 3. Run all migrations
    ///
    /// # Panics
    ///
    /// Panics if container startup, connection, or migrations fail.
    pub async fn new() -> Self {
        // Start the TimescaleDB container
        let container = TimescaleDb::default()
            .start()
            .await
            .expect("Failed to start TimescaleDB container");

        // Get connection details
        let host = container.get_host().await.expect("Failed to get host");
        let port = container
            .get_host_port_ipv4(5432)
            .await
            .expect("Failed to get port");

        let connection_string = build_connection_string(&host.to_string(), port);

        // Connect to the database with retries
        let pool = connect_with_retries(&connection_string, 30)
            .await
            .expect("Failed to connect to database");

        // Create the store
        let store = PostgresStore::new(pool.clone());

        // Run migrations
        store
            .run_migrations()
            .await
            .expect("Failed to run migrations");

        Self {
            pool,
            store,
            _container: container,
        }
    }
}

/// Connect to the database with retries.
///
/// TimescaleDB can take a moment to be fully ready even after the
/// "ready to accept connections" message appears.
async fn connect_with_retries(url: &str, max_attempts: u32) -> Result<PgPool, sqlx::Error> {
    let mut attempts = 0;
    loop {
        attempts += 1;
        match PgPool::connect(url).await {
            Ok(pool) => {
                // Verify connection works
                match sqlx::query("SELECT 1").execute(&pool).await {
                    Ok(_) => return Ok(pool),
                    Err(e) if attempts < max_attempts => {
                        tracing::debug!("Connection verify failed (attempt {attempts}): {e}");
                        tokio::time::sleep(std::time::Duration::from_millis(500)).await;
                    }
                    Err(e) => return Err(e),
                }
            }
            Err(e) if attempts < max_attempts => {
                tracing::debug!("Connection failed (attempt {attempts}): {e}");
                tokio::time::sleep(std::time::Duration::from_millis(500)).await;
            }
            Err(e) => return Err(e),
        }
    }
}

/// Create test fixtures for positions.
pub mod position_fixtures {
    use alloy::primitives::U256;
    use chrono::Utc;
    use uuid::Uuid;

    use ghostnet_indexer::types::entities::Position;
    use ghostnet_indexer::types::enums::{ExitReason, Level};
    use ghostnet_indexer::types::primitives::{BlockNumber, EthAddress, GhostStreak, TokenAmount};

    /// Create a test position with defaults.
    pub fn create_test_position(user: &str, level: Level) -> Position {
        let now = Utc::now();
        Position {
            id: Uuid::new_v4(),
            user_address: EthAddress::from_hex(user).expect("valid address"),
            level,
            amount: TokenAmount::from_wei(U256::from(1_000_000_000_000_000_000u128), 18), // 1 token
            reward_debt: TokenAmount::zero(),
            entry_timestamp: now,
            last_add_timestamp: None,
            ghost_streak: GhostStreak::new(0).expect("valid streak"),
            is_alive: true,
            is_extracted: false,
            exit_reason: None,
            exit_timestamp: None,
            extracted_amount: None,
            extracted_rewards: None,
            created_at_block: BlockNumber::new(1000),
            updated_at: now,
        }
    }

    /// Create a dead position.
    pub fn create_dead_position(user: &str, level: Level, reason: ExitReason) -> Position {
        let mut pos = create_test_position(user, level);
        pos.is_alive = false;
        pos.exit_reason = Some(reason);
        pos.exit_timestamp = Some(Utc::now());
        pos
    }

    /// Create an extracted position.
    pub fn create_extracted_position(user: &str, level: Level) -> Position {
        let mut pos = create_test_position(user, level);
        pos.is_alive = false;
        pos.is_extracted = true;
        pos.exit_reason = Some(ExitReason::Extracted);
        pos.exit_timestamp = Some(Utc::now());
        pos.extracted_amount = Some(TokenAmount::from_wei(
            U256::from(1_100_000_000_000_000_000u128),
            18,
        ));
        pos.extracted_rewards = Some(TokenAmount::from_wei(
            U256::from(100_000_000_000_000_000u128),
            18,
        ));
        pos
    }
}

/// Create test fixtures for scans.
pub mod scan_fixtures {
    use alloy::primitives::U256;
    use chrono::Utc;
    use uuid::Uuid;

    use ghostnet_indexer::types::entities::Scan;
    use ghostnet_indexer::types::enums::Level;
    use ghostnet_indexer::types::primitives::TokenAmount;

    /// Create a test scan that has been executed but not finalized.
    pub fn create_pending_scan(level: Level) -> Scan {
        Scan {
            id: Uuid::new_v4(),
            scan_id: format!("scan-{}-{}", level as u8, Uuid::new_v4()),
            level,
            seed: "0x1234567890abcdef".to_string(),
            executed_at: Utc::now(),
            finalized_at: None,
            death_count: None,
            total_dead: None,
            burned: None,
            distributed_same_level: None,
            distributed_upstream: None,
            protocol_fee: None,
            survivor_count: None,
        }
    }

    /// Create a test scan that has been finalized.
    pub fn create_finalized_scan(level: Level, death_count: u32) -> Scan {
        let mut scan = create_pending_scan(level);
        scan.finalized_at = Some(Utc::now());
        scan.death_count = Some(death_count);
        scan.total_dead = Some(TokenAmount::from_wei(
            U256::from(5_000_000_000_000_000_000u128),
            18,
        ));
        scan.burned = Some(TokenAmount::from_wei(
            U256::from(500_000_000_000_000_000u128),
            18,
        ));
        scan.distributed_same_level = Some(TokenAmount::from_wei(
            U256::from(2_000_000_000_000_000_000u128),
            18,
        ));
        scan.distributed_upstream = Some(TokenAmount::from_wei(
            U256::from(1_500_000_000_000_000_000u128),
            18,
        ));
        scan.protocol_fee = Some(TokenAmount::from_wei(
            U256::from(1_000_000_000_000_000_000u128),
            18,
        ));
        scan.survivor_count = Some(100);
        scan
    }
}

/// Create test fixtures for deaths.
pub mod death_fixtures {
    use alloy::primitives::U256;
    use chrono::Utc;
    use uuid::Uuid;

    use ghostnet_indexer::types::entities::Death;
    use ghostnet_indexer::types::enums::Level;
    use ghostnet_indexer::types::primitives::{EthAddress, GhostStreak, TokenAmount};

    /// Create a test death record.
    pub fn create_test_death(user: &str, level: Level, amount_lost: u128) -> Death {
        Death {
            id: Uuid::new_v4(),
            scan_id: None,
            user_address: EthAddress::from_hex(user).expect("valid address"),
            position_id: None,
            amount_lost: TokenAmount::from_wei(U256::from(amount_lost), 18),
            level,
            ghost_streak_at_death: Some(GhostStreak::new(5).expect("valid streak")),
            created_at: Utc::now(),
        }
    }

    /// Create a death linked to a scan.
    pub fn create_death_for_scan(
        user: &str,
        level: Level,
        scan_id: Uuid,
        position_id: Uuid,
    ) -> Death {
        let mut death = create_test_death(user, level, 1_000_000_000_000_000_000);
        death.scan_id = Some(scan_id);
        death.position_id = Some(position_id);
        death
    }
}
