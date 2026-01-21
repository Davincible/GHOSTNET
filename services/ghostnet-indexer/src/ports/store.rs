//! Storage port traits for data persistence.
//!
//! These traits define the contract for persisting and retrieving
//! domain entities. Infrastructure adapters implement these traits
//! using concrete storage backends (e.g., PostgreSQL, SQLite).

use alloy::primitives::B256;
use async_trait::async_trait;

use crate::error::Result;
use crate::types::entities::{
    Bet, Death, GlobalStats, LevelStats, LevelStatsDelta, Position, PositionHistoryEntry, Round,
    Scan, ScanFinalizationData,
};
use crate::types::enums::Level;
use crate::types::primitives::{BlockNumber, EthAddress, TokenAmount};

// ═══════════════════════════════════════════════════════════════════════════════
// POSITION STORE
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for position persistence operations.
///
/// Handles CRUD operations for player positions, including:
/// - Active position lookup by address
/// - Position creation and updates
/// - At-risk position queries for culling
/// - Position history recording
///
/// # Implementation Notes
///
/// Implementations should:
/// - Use transactions for multi-step operations
/// - Index on `user_address` for fast lookups
/// - Consider partitioning by `level` for large datasets
#[async_trait]
pub trait PositionStore: Send + Sync {
    /// Get the active (alive, not extracted) position for a user.
    ///
    /// Returns `None` if the user has no active position.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_active_position(&self, address: &EthAddress) -> Result<Option<Position>>;

    /// Save a new position or update an existing one.
    ///
    /// Uses upsert semantics - creates if not exists, updates if exists.
    ///
    /// # Errors
    ///
    /// Returns an error if the database operation fails.
    async fn save_position(&self, position: &Position) -> Result<()>;

    /// Get positions at risk of culling for a level.
    ///
    /// Returns positions ordered by entry time (oldest first) where
    /// the position count exceeds the threshold.
    ///
    /// # Arguments
    ///
    /// * `level` - The risk level to check
    /// * `threshold` - Maximum positions allowed before culling
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_at_risk_positions(&self, level: Level, threshold: u32) -> Result<Vec<Position>>;

    /// Record a position history entry.
    ///
    /// History entries track all changes to positions over time,
    /// enabling audit trails and analytics.
    ///
    /// # Errors
    ///
    /// Returns an error if the database operation fails.
    async fn record_history(&self, entry: &PositionHistoryEntry) -> Result<()>;

    /// Get position by ID.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_position_by_id(&self, id: &uuid::Uuid) -> Result<Option<Position>>;

    /// Get all active positions for a level.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_positions_by_level(&self, level: Level) -> Result<Vec<Position>>;

    /// Count active positions for a level.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn count_positions_by_level(&self, level: Level) -> Result<u32>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCAN STORE
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for scan persistence operations.
///
/// Handles the two-phase scan lifecycle:
/// 1. `ScanExecuted` → `save_scan()`
/// 2. `ScanFinalized` → `finalize_scan()`
///
/// # Implementation Notes
///
/// Implementations should:
/// - Use composite key (`level`, `scan_id`) for lookups
/// - Index on `executed_at` for time-range queries
#[async_trait]
pub trait ScanStore: Send + Sync {
    /// Save a new scan record (Phase 1).
    ///
    /// Called when a `ScanExecuted` event is received.
    ///
    /// # Errors
    ///
    /// Returns an error if the scan already exists or database fails.
    async fn save_scan(&self, scan: &Scan) -> Result<()>;

    /// Update scan with finalization data (Phase 2).
    ///
    /// Called when a `ScanFinalized` event is received.
    ///
    /// # Arguments
    ///
    /// * `scan_id` - The on-chain scan ID (U256 as string)
    /// * `data` - Finalization data including death counts and distributions
    ///
    /// # Errors
    ///
    /// Returns an error if the scan doesn't exist or database fails.
    async fn finalize_scan(&self, scan_id: &str, data: ScanFinalizationData) -> Result<()>;

    /// Get recent scans for a level.
    ///
    /// Returns scans ordered by execution time (most recent first).
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_recent_scans(&self, level: Level, limit: u32) -> Result<Vec<Scan>>;

    /// Get a scan by its on-chain ID.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_scan_by_id(&self, scan_id: &str) -> Result<Option<Scan>>;

    /// Get pending (not yet finalized) scans.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_pending_scans(&self) -> Result<Vec<Scan>>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEATH STORE
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for death record persistence.
///
/// Tracks individual deaths resulting from scans.
///
/// # Implementation Notes
///
/// Implementations should:
/// - Use batch inserts for efficiency
/// - Index on `user_address` for user history queries
/// - Index on `scan_id` for scan-related lookups
#[async_trait]
pub trait DeathStore: Send + Sync {
    /// Record deaths from a scan.
    ///
    /// Efficiently batch-inserts multiple death records.
    ///
    /// # Errors
    ///
    /// Returns an error if the database operation fails.
    async fn record_deaths(&self, deaths: &[Death]) -> Result<()>;

    /// Get all deaths for a specific scan.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_deaths_for_scan(&self, scan_id: &str) -> Result<Vec<Death>>;

    /// Get a user's death history.
    ///
    /// Returns deaths ordered by time (most recent first).
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_user_deaths(&self, address: &EthAddress, limit: u32) -> Result<Vec<Death>>;

    /// Count total deaths for a level.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn count_deaths_by_level(&self, level: Level) -> Result<u64>;

    /// Get recent deaths across all levels.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_recent_deaths(&self, limit: u32) -> Result<Vec<Death>>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARKET STORE
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for market/betting persistence.
///
/// Handles the `DeadPool` prediction market:
/// - Round creation and resolution
/// - Bet recording and claims
///
/// # Implementation Notes
///
/// Implementations should:
/// - Use transactions for bet placement (round update + bet insert)
/// - Index on `is_resolved` for active round queries
#[async_trait]
pub trait MarketStore: Send + Sync {
    /// Save a new betting round.
    ///
    /// # Errors
    ///
    /// Returns an error if the round already exists or database fails.
    async fn save_round(&self, round: &Round) -> Result<()>;

    /// Record a bet on a round.
    ///
    /// Should update round's pool totals atomically.
    ///
    /// # Errors
    ///
    /// Returns an error if the round doesn't exist or database fails.
    async fn record_bet(&self, bet: &Bet) -> Result<()>;

    /// Resolve a round with outcome.
    ///
    /// # Arguments
    ///
    /// * `round_id` - The on-chain round ID (U256 as string)
    /// * `outcome` - `true` for OVER, `false` for UNDER
    /// * `burned` - Amount of tokens burned as rake
    ///
    /// # Errors
    ///
    /// Returns an error if the round doesn't exist or is already resolved.
    async fn resolve_round(
        &self,
        round_id: &str,
        outcome: bool,
        burned: &TokenAmount,
    ) -> Result<()>;

    /// Get active (unresolved) rounds.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_active_rounds(&self, limit: u32) -> Result<Vec<Round>>;

    /// Get a round by its on-chain ID.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_round_by_id(&self, round_id: &str) -> Result<Option<Round>>;

    /// Get bets for a round.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_bets_for_round(&self, round_id: &str) -> Result<Vec<Bet>>;

    /// Get a user's betting history.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_user_bets(&self, address: &EthAddress, limit: u32) -> Result<Vec<Bet>>;

    /// Mark a bet as claimed.
    ///
    /// # Errors
    ///
    /// Returns an error if the bet doesn't exist or database fails.
    async fn mark_bet_claimed(
        &self,
        round_id: &str,
        user: &EthAddress,
        winnings: &TokenAmount,
    ) -> Result<()>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// INDEXER STATE STORE
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for indexer state management.
///
/// Tracks indexer progress and handles chain reorganizations.
///
/// # Reorg Handling
///
/// The indexer stores block hashes to detect reorgs:
/// 1. When processing a block, check if parent hash matches stored hash
/// 2. If mismatch, find the fork point
/// 3. Roll back state to fork point
/// 4. Reprocess from fork point
///
/// # Implementation Notes
///
/// Implementations should:
/// - Keep a sliding window of recent block hashes (e.g., 256 blocks)
/// - Use transactions for reorg rollback operations
#[async_trait]
pub trait IndexerStateStore: Send + Sync {
    /// Get the last successfully indexed block number.
    ///
    /// Returns `BlockNumber(0)` if no blocks have been indexed.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_last_block(&self) -> Result<BlockNumber>;

    /// Set the last indexed block.
    ///
    /// Called after successfully processing a block.
    ///
    /// # Errors
    ///
    /// Returns an error if the database operation fails.
    async fn set_last_block(&self, block: BlockNumber, hash: B256) -> Result<()>;

    /// Insert block hash for reorg detection.
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
    /// Returns an error if the database operation fails.
    async fn insert_block_hash(
        &self,
        block: BlockNumber,
        hash: B256,
        parent: B256,
        timestamp: u64,
    ) -> Result<()>;

    /// Get stored block hash for reorg check.
    ///
    /// Returns `None` if block is outside the stored window.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_block_hash(&self, block: BlockNumber) -> Result<Option<B256>>;

    /// Execute reorg rollback to the fork point.
    ///
    /// Deletes all data from blocks after `fork_point`.
    ///
    /// # Safety
    ///
    /// This operation is destructive. Ensure the fork point is correct.
    ///
    /// # Errors
    ///
    /// Returns an error if the rollback fails.
    async fn execute_reorg_rollback(&self, fork_point: BlockNumber) -> Result<()>;

    /// Prune old block hashes beyond the retention window.
    ///
    /// # Arguments
    ///
    /// * `keep_blocks` - Number of recent blocks to keep
    ///
    /// # Errors
    ///
    /// Returns an error if the database operation fails.
    async fn prune_old_blocks(&self, keep_blocks: u64) -> Result<u64>;
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATS STORE
// ═══════════════════════════════════════════════════════════════════════════════

/// Port for analytics/statistics persistence.
///
/// Maintains aggregate statistics for efficient queries.
///
/// # Implementation Notes
///
/// Implementations can use:
/// - Materialized views for complex aggregations
/// - Incremental updates via `update_level_stats`
/// - Background refresh for expensive computations
#[async_trait]
pub trait StatsStore: Send + Sync {
    /// Get global protocol statistics.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_global_stats(&self) -> Result<GlobalStats>;

    /// Get statistics for a specific level.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_level_stats(&self, level: Level) -> Result<LevelStats>;

    /// Update level statistics with delta changes.
    ///
    /// Uses atomic increments/decrements for efficiency.
    ///
    /// # Errors
    ///
    /// Returns an error if the database operation fails.
    async fn update_level_stats(&self, level: Level, delta: LevelStatsDelta) -> Result<()>;

    /// Get all level statistics.
    ///
    /// Returns stats for all 5 levels.
    ///
    /// # Errors
    ///
    /// Returns an error if the database query fails.
    async fn get_all_level_stats(&self) -> Result<Vec<LevelStats>>;

    /// Refresh global stats from source data.
    ///
    /// Used for periodic reconciliation.
    ///
    /// # Errors
    ///
    /// Returns an error if the refresh fails.
    async fn refresh_global_stats(&self) -> Result<GlobalStats>;
}
