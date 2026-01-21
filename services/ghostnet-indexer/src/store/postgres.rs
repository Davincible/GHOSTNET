//! PostgreSQL implementation of store ports using SQLx.
//!
//! This module provides the primary persistence layer using PostgreSQL
//! with TimescaleDB extensions for efficient time-series queries.
//!
//! # Type Conversions
//!
//! PostgreSQL uses signed integers (i16, i32, i64) for numeric columns while our
//! domain uses unsigned types. These casts are safe because:
//! - Level values are 0-4 (fits in u8)
//! - Block numbers won't exceed i64::MAX (~9 quintillion)
//! - Counts won't exceed i32::MAX (~2 billion)
#![allow(
    clippy::cast_possible_truncation,
    clippy::cast_sign_loss,
    clippy::cast_possible_wrap,
    clippy::cast_lossless, // Using `as i64` for u32 is clear in DB binding context
    clippy::use_self       // TryFrom implementations read better with explicit type names
)]

use alloy::primitives::B256;
use async_trait::async_trait;
use sqlx::{FromRow, postgres::PgPool};
use tracing::{debug, instrument};
use uuid::Uuid;

use crate::error::{InfraError, Result};
use crate::ports::{
    DeathStore, IndexerStateStore, MarketStore, PositionStore, ScanStore, StatsStore,
};
use crate::types::entities::{
    Bet, Death, GlobalStats, LevelStats, LevelStatsDelta, Position, PositionHistoryEntry, Round,
    Scan, ScanFinalizationData,
};
use crate::types::enums::Level;
use crate::types::primitives::{BlockNumber, EthAddress, GhostStreak, TokenAmount};

// ═══════════════════════════════════════════════════════════════════════════════
// POSTGRES STORE
// ═══════════════════════════════════════════════════════════════════════════════

/// PostgreSQL-based store implementation.
///
/// Implements all store port traits using SQLx for database access.
/// Uses TimescaleDB hypertables for efficient time-series data storage.
#[derive(Debug, Clone)]
pub struct PostgresStore {
    pool: PgPool,
}

impl PostgresStore {
    /// Create a new PostgreSQL store with the given connection pool.
    #[must_use]
    pub const fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    /// Get a reference to the underlying connection pool.
    #[must_use]
    pub const fn pool(&self) -> &PgPool {
        &self.pool
    }

    /// Run pending migrations.
    ///
    /// # Errors
    ///
    /// Returns an error if migrations fail.
    pub async fn run_migrations(&self) -> Result<()> {
        sqlx::migrate!("./migrations")
            .run(&self.pool)
            .await
            .map_err(|e| InfraError::Internal(format!("Migration error: {e}")))?;
        Ok(())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// POSITION STORE IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Database row for positions.
#[derive(Debug, FromRow)]
struct PositionRow {
    id: Uuid,
    user_address: Vec<u8>,
    level: i16,
    amount: sqlx::types::BigDecimal,
    reward_debt: sqlx::types::BigDecimal,
    entry_timestamp: chrono::DateTime<chrono::Utc>,
    last_add_timestamp: Option<chrono::DateTime<chrono::Utc>>,
    ghost_streak: i32,
    is_alive: bool,
    is_extracted: bool,
    exit_reason: Option<String>,
    exit_timestamp: Option<chrono::DateTime<chrono::Utc>>,
    extracted_amount: Option<sqlx::types::BigDecimal>,
    extracted_rewards: Option<sqlx::types::BigDecimal>,
    created_at_block: i64,
    updated_at: chrono::DateTime<chrono::Utc>,
}

impl TryFrom<PositionRow> for Position {
    type Error = InfraError;

    fn try_from(row: PositionRow) -> std::result::Result<Self, Self::Error> {
        Ok(Position {
            id: row.id,
            user_address: EthAddress::new(
                row.user_address
                    .try_into()
                    .map_err(|_| InfraError::Internal("Invalid address length in DB".into()))?,
            ),
            level: Level::try_from(row.level as u8)
                .map_err(|e| InfraError::Internal(format!("Invalid level in DB: {e}")))?,
            amount: TokenAmount::from_bigdecimal(&row.amount),
            reward_debt: TokenAmount::from_bigdecimal(&row.reward_debt),
            entry_timestamp: row.entry_timestamp,
            last_add_timestamp: row.last_add_timestamp,
            ghost_streak: GhostStreak::new(row.ghost_streak)
                .map_err(|e| InfraError::Internal(format!("Invalid ghost streak in DB: {e}")))?,
            is_alive: row.is_alive,
            is_extracted: row.is_extracted,
            exit_reason: row
                .exit_reason
                .map(|s| s.parse())
                .transpose()
                .map_err(|e| InfraError::Internal(format!("Invalid exit reason in DB: {e}")))?,
            exit_timestamp: row.exit_timestamp,
            extracted_amount: row
                .extracted_amount
                .map(|d| TokenAmount::from_bigdecimal(&d)),
            extracted_rewards: row
                .extracted_rewards
                .map(|d| TokenAmount::from_bigdecimal(&d)),
            created_at_block: BlockNumber::new(row.created_at_block as u64),
            updated_at: row.updated_at,
        })
    }
}

#[async_trait]
impl PositionStore for PostgresStore {
    #[instrument(skip(self), fields(address = %address))]
    async fn get_active_position(&self, address: &EthAddress) -> Result<Option<Position>> {
        let row = sqlx::query_as::<_, PositionRow>(
            r#"
            SELECT id, user_address, level, amount, reward_debt, entry_timestamp,
                   last_add_timestamp, ghost_streak, is_alive, is_extracted,
                   exit_reason, exit_timestamp, extracted_amount, extracted_rewards,
                   created_at_block, updated_at
            FROM positions
            WHERE user_address = $1 AND is_alive = true AND is_extracted = false
            ORDER BY entry_timestamp DESC
            LIMIT 1
            "#,
        )
        .bind(address.as_bytes())
        .fetch_optional(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        match row {
            Some(r) => Ok(Some(r.try_into()?)),
            None => Ok(None),
        }
    }

    #[instrument(skip(self, position), fields(id = %position.id, user = %position.user_address))]
    async fn save_position(&self, position: &Position) -> Result<()> {
        // Note: TimescaleDB hypertables require the partitioning column in ON CONFLICT.
        // The primary key is (id, entry_timestamp), so we use that for upsert.
        sqlx::query(
            r#"
            INSERT INTO positions (
                id, user_address, level, amount, reward_debt, entry_timestamp,
                last_add_timestamp, ghost_streak, is_alive, is_extracted,
                exit_reason, exit_timestamp, extracted_amount, extracted_rewards,
                created_at_block, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
            ON CONFLICT (id, entry_timestamp) DO UPDATE SET
                amount = EXCLUDED.amount,
                reward_debt = EXCLUDED.reward_debt,
                last_add_timestamp = EXCLUDED.last_add_timestamp,
                ghost_streak = EXCLUDED.ghost_streak,
                is_alive = EXCLUDED.is_alive,
                is_extracted = EXCLUDED.is_extracted,
                exit_reason = EXCLUDED.exit_reason,
                exit_timestamp = EXCLUDED.exit_timestamp,
                extracted_amount = EXCLUDED.extracted_amount,
                extracted_rewards = EXCLUDED.extracted_rewards,
                updated_at = EXCLUDED.updated_at
            "#,
        )
        .bind(position.id)
        .bind(position.user_address.as_bytes())
        .bind(position.level as i16)
        .bind(position.amount.to_bigdecimal())
        .bind(position.reward_debt.to_bigdecimal())
        .bind(position.entry_timestamp)
        .bind(position.last_add_timestamp)
        .bind(position.ghost_streak.value())
        .bind(position.is_alive)
        .bind(position.is_extracted)
        .bind(position.exit_reason.map(|r| r.to_string()))
        .bind(position.exit_timestamp)
        .bind(
            position
                .extracted_amount
                .as_ref()
                .map(TokenAmount::to_bigdecimal),
        )
        .bind(
            position
                .extracted_rewards
                .as_ref()
                .map(TokenAmount::to_bigdecimal),
        )
        .bind(position.created_at_block.value() as i64)
        .bind(position.updated_at)
        .execute(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        debug!("Position saved");
        Ok(())
    }

    #[instrument(skip(self), fields(level = ?level, threshold = threshold))]
    async fn get_at_risk_positions(&self, level: Level, threshold: u32) -> Result<Vec<Position>> {
        let rows = sqlx::query_as::<_, PositionRow>(
            r#"
            SELECT id, user_address, level, amount, reward_debt, entry_timestamp,
                   last_add_timestamp, ghost_streak, is_alive, is_extracted,
                   exit_reason, exit_timestamp, extracted_amount, extracted_rewards,
                   created_at_block, updated_at
            FROM positions
            WHERE level = $1 AND is_alive = true AND is_extracted = false
            ORDER BY entry_timestamp ASC
            OFFSET $2
            "#,
        )
        .bind(level as i16)
        .bind(threshold as i64)
        .fetch_all(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        rows.into_iter()
            .map(|r| Position::try_from(r).map_err(Into::into))
            .collect()
    }

    #[instrument(skip(self, entry), fields(position_id = %entry.position_id, action = ?entry.action))]
    async fn record_history(&self, entry: &PositionHistoryEntry) -> Result<()> {
        sqlx::query(
            r#"
            INSERT INTO position_history (
                id, position_id, user_address, action, amount_change, new_total,
                block_number, timestamp
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            "#,
        )
        .bind(entry.id)
        .bind(entry.position_id)
        .bind(entry.user_address.as_bytes())
        .bind(entry.action.name())
        .bind(entry.amount_change.to_bigdecimal())
        .bind(entry.new_total.to_bigdecimal())
        .bind(entry.block_number.value() as i64)
        .bind(entry.timestamp)
        .execute(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        debug!("Position history recorded");
        Ok(())
    }

    #[instrument(skip(self), fields(id = %id))]
    async fn get_position_by_id(&self, id: &Uuid) -> Result<Option<Position>> {
        let row = sqlx::query_as::<_, PositionRow>(
            r#"
            SELECT id, user_address, level, amount, reward_debt, entry_timestamp,
                   last_add_timestamp, ghost_streak, is_alive, is_extracted,
                   exit_reason, exit_timestamp, extracted_amount, extracted_rewards,
                   created_at_block, updated_at
            FROM positions
            WHERE id = $1
            "#,
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        match row {
            Some(r) => Ok(Some(r.try_into()?)),
            None => Ok(None),
        }
    }

    #[instrument(skip(self), fields(level = ?level))]
    async fn get_positions_by_level(&self, level: Level) -> Result<Vec<Position>> {
        let rows = sqlx::query_as::<_, PositionRow>(
            r#"
            SELECT id, user_address, level, amount, reward_debt, entry_timestamp,
                   last_add_timestamp, ghost_streak, is_alive, is_extracted,
                   exit_reason, exit_timestamp, extracted_amount, extracted_rewards,
                   created_at_block, updated_at
            FROM positions
            WHERE level = $1 AND is_alive = true AND is_extracted = false
            ORDER BY entry_timestamp DESC
            "#,
        )
        .bind(level as i16)
        .fetch_all(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        rows.into_iter()
            .map(|r| Position::try_from(r).map_err(Into::into))
            .collect()
    }

    #[instrument(skip(self), fields(level = ?level))]
    async fn count_positions_by_level(&self, level: Level) -> Result<u32> {
        let count: i64 = sqlx::query_scalar(
            r#"
            SELECT COUNT(*) FROM positions
            WHERE level = $1 AND is_alive = true AND is_extracted = false
            "#,
        )
        .bind(level as i16)
        .fetch_one(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        Ok(count as u32)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCAN STORE IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Database row for scans.
#[derive(Debug, FromRow)]
struct ScanRow {
    id: Uuid,
    scan_id: String,
    level: i16,
    seed: String,
    executed_at: chrono::DateTime<chrono::Utc>,
    finalized_at: Option<chrono::DateTime<chrono::Utc>>,
    death_count: Option<i32>,
    total_dead: Option<sqlx::types::BigDecimal>,
    burned: Option<sqlx::types::BigDecimal>,
    distributed_same_level: Option<sqlx::types::BigDecimal>,
    distributed_upstream: Option<sqlx::types::BigDecimal>,
    protocol_fee: Option<sqlx::types::BigDecimal>,
    survivor_count: Option<i32>,
}

impl TryFrom<ScanRow> for Scan {
    type Error = InfraError;

    fn try_from(row: ScanRow) -> std::result::Result<Self, Self::Error> {
        Ok(Scan {
            id: row.id,
            scan_id: row.scan_id,
            level: Level::try_from(row.level as u8)
                .map_err(|e| InfraError::Internal(format!("Invalid level in DB: {e}")))?,
            seed: row.seed,
            executed_at: row.executed_at,
            finalized_at: row.finalized_at,
            death_count: row.death_count.map(|c| c as u32),
            total_dead: row.total_dead.map(|d| TokenAmount::from_bigdecimal(&d)),
            burned: row.burned.map(|d| TokenAmount::from_bigdecimal(&d)),
            distributed_same_level: row
                .distributed_same_level
                .map(|d| TokenAmount::from_bigdecimal(&d)),
            distributed_upstream: row
                .distributed_upstream
                .map(|d| TokenAmount::from_bigdecimal(&d)),
            protocol_fee: row.protocol_fee.map(|d| TokenAmount::from_bigdecimal(&d)),
            survivor_count: row.survivor_count.map(|c| c as u32),
        })
    }
}

#[async_trait]
impl ScanStore for PostgresStore {
    #[instrument(skip(self, scan), fields(scan_id = %scan.scan_id, level = ?scan.level))]
    async fn save_scan(&self, scan: &Scan) -> Result<()> {
        sqlx::query(
            r#"
            INSERT INTO scans (
                id, scan_id, level, seed, executed_at, finalized_at,
                death_count, total_dead, burned, distributed_same_level,
                distributed_upstream, protocol_fee, survivor_count
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            "#,
        )
        .bind(scan.id)
        .bind(&scan.scan_id)
        .bind(scan.level as i16)
        .bind(&scan.seed)
        .bind(scan.executed_at)
        .bind(scan.finalized_at)
        .bind(scan.death_count.map(|c| c as i32))
        .bind(scan.total_dead.as_ref().map(TokenAmount::to_bigdecimal))
        .bind(scan.burned.as_ref().map(TokenAmount::to_bigdecimal))
        .bind(
            scan.distributed_same_level
                .as_ref()
                .map(TokenAmount::to_bigdecimal),
        )
        .bind(
            scan.distributed_upstream
                .as_ref()
                .map(TokenAmount::to_bigdecimal),
        )
        .bind(scan.protocol_fee.as_ref().map(TokenAmount::to_bigdecimal))
        .bind(scan.survivor_count.map(|c| c as i32))
        .execute(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        debug!("Scan saved");
        Ok(())
    }

    #[instrument(skip(self, data), fields(scan_id = %scan_id))]
    async fn finalize_scan(&self, scan_id: &str, data: ScanFinalizationData) -> Result<()> {
        let result = sqlx::query(
            r#"
            UPDATE scans SET
                finalized_at = $2,
                death_count = $3,
                total_dead = $4,
                burned = $5,
                distributed_same_level = $6,
                distributed_upstream = $7,
                protocol_fee = $8,
                survivor_count = $9
            WHERE scan_id = $1
            "#,
        )
        .bind(scan_id)
        .bind(data.finalized_at)
        .bind(data.death_count as i32)
        .bind(data.total_dead.to_bigdecimal())
        .bind(data.burned.to_bigdecimal())
        .bind(data.distributed_same_level.to_bigdecimal())
        .bind(data.distributed_upstream.to_bigdecimal())
        .bind(data.protocol_fee.to_bigdecimal())
        .bind(data.survivor_count as i32)
        .execute(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        if result.rows_affected() == 0 {
            return Err(InfraError::NotFound.into());
        }

        debug!("Scan finalized");
        Ok(())
    }

    #[instrument(skip(self), fields(level = ?level, limit = limit))]
    async fn get_recent_scans(&self, level: Level, limit: u32) -> Result<Vec<Scan>> {
        let rows = sqlx::query_as::<_, ScanRow>(
            r#"
            SELECT id, scan_id, level, seed, executed_at, finalized_at,
                   death_count, total_dead, burned, distributed_same_level,
                   distributed_upstream, protocol_fee, survivor_count
            FROM scans
            WHERE level = $1
            ORDER BY executed_at DESC
            LIMIT $2
            "#,
        )
        .bind(level as i16)
        .bind(limit as i64)
        .fetch_all(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        rows.into_iter()
            .map(|r| Scan::try_from(r).map_err(Into::into))
            .collect()
    }

    #[instrument(skip(self), fields(scan_id = %scan_id))]
    async fn get_scan_by_id(&self, scan_id: &str) -> Result<Option<Scan>> {
        let row = sqlx::query_as::<_, ScanRow>(
            r#"
            SELECT id, scan_id, level, seed, executed_at, finalized_at,
                   death_count, total_dead, burned, distributed_same_level,
                   distributed_upstream, protocol_fee, survivor_count
            FROM scans
            WHERE scan_id = $1
            "#,
        )
        .bind(scan_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        match row {
            Some(r) => Ok(Some(r.try_into()?)),
            None => Ok(None),
        }
    }

    #[instrument(skip(self))]
    async fn get_pending_scans(&self) -> Result<Vec<Scan>> {
        let rows = sqlx::query_as::<_, ScanRow>(
            r#"
            SELECT id, scan_id, level, seed, executed_at, finalized_at,
                   death_count, total_dead, burned, distributed_same_level,
                   distributed_upstream, protocol_fee, survivor_count
            FROM scans
            WHERE finalized_at IS NULL
            ORDER BY executed_at ASC
            "#,
        )
        .fetch_all(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        rows.into_iter()
            .map(|r| Scan::try_from(r).map_err(Into::into))
            .collect()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEATH STORE IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Database row for deaths.
#[derive(Debug, FromRow)]
struct DeathRow {
    id: Uuid,
    scan_id: Option<Uuid>,
    user_address: Vec<u8>,
    position_id: Option<Uuid>,
    amount_lost: sqlx::types::BigDecimal,
    level: i16,
    ghost_streak_at_death: Option<i32>,
    created_at: chrono::DateTime<chrono::Utc>,
}

impl TryFrom<DeathRow> for Death {
    type Error = InfraError;

    fn try_from(row: DeathRow) -> std::result::Result<Self, Self::Error> {
        Ok(Death {
            id: row.id,
            scan_id: row.scan_id,
            user_address: EthAddress::new(
                row.user_address
                    .try_into()
                    .map_err(|_| InfraError::Internal("Invalid address length in DB".into()))?,
            ),
            position_id: row.position_id,
            amount_lost: TokenAmount::from_bigdecimal(&row.amount_lost),
            level: Level::try_from(row.level as u8)
                .map_err(|e| InfraError::Internal(format!("Invalid level in DB: {e}")))?,
            ghost_streak_at_death: row
                .ghost_streak_at_death
                .map(GhostStreak::new)
                .transpose()
                .map_err(|e| InfraError::Internal(format!("Invalid ghost streak in DB: {e}")))?,
            created_at: row.created_at,
        })
    }
}

#[async_trait]
impl DeathStore for PostgresStore {
    #[instrument(skip(self, deaths), fields(count = deaths.len()))]
    async fn record_deaths(&self, deaths: &[Death]) -> Result<()> {
        if deaths.is_empty() {
            return Ok(());
        }

        // Use a transaction for batch insert
        let mut tx = self.pool.begin().await.map_err(InfraError::Database)?;

        for death in deaths {
            sqlx::query(
                r#"
                INSERT INTO deaths (
                    id, scan_id, user_address, position_id, amount_lost,
                    level, ghost_streak_at_death, created_at
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                "#,
            )
            .bind(death.id)
            .bind(death.scan_id)
            .bind(death.user_address.as_bytes())
            .bind(death.position_id)
            .bind(death.amount_lost.to_bigdecimal())
            .bind(death.level as i16)
            .bind(death.ghost_streak_at_death.map(|s| s.value()))
            .bind(death.created_at)
            .execute(&mut *tx)
            .await
            .map_err(InfraError::Database)?;
        }

        tx.commit().await.map_err(InfraError::Database)?;

        debug!(count = deaths.len(), "Deaths recorded");
        Ok(())
    }

    #[instrument(skip(self), fields(scan_id = %scan_id))]
    async fn get_deaths_for_scan(&self, scan_id: &str) -> Result<Vec<Death>> {
        // First get the scan's UUID from the on-chain scan_id
        let scan_uuid: Option<Uuid> = sqlx::query_scalar("SELECT id FROM scans WHERE scan_id = $1")
            .bind(scan_id)
            .fetch_optional(&self.pool)
            .await
            .map_err(InfraError::Database)?;

        let Some(uuid) = scan_uuid else {
            return Ok(Vec::new());
        };

        let rows = sqlx::query_as::<_, DeathRow>(
            r#"
            SELECT id, scan_id, user_address, position_id, amount_lost,
                   level, ghost_streak_at_death, created_at
            FROM deaths
            WHERE scan_id = $1
            ORDER BY created_at ASC
            "#,
        )
        .bind(uuid)
        .fetch_all(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        rows.into_iter()
            .map(|r| Death::try_from(r).map_err(Into::into))
            .collect()
    }

    #[instrument(skip(self), fields(address = %address, limit = limit))]
    async fn get_user_deaths(&self, address: &EthAddress, limit: u32) -> Result<Vec<Death>> {
        let rows = sqlx::query_as::<_, DeathRow>(
            r#"
            SELECT id, scan_id, user_address, position_id, amount_lost,
                   level, ghost_streak_at_death, created_at
            FROM deaths
            WHERE user_address = $1
            ORDER BY created_at DESC
            LIMIT $2
            "#,
        )
        .bind(address.as_bytes())
        .bind(limit as i64)
        .fetch_all(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        rows.into_iter()
            .map(|r| Death::try_from(r).map_err(Into::into))
            .collect()
    }

    #[instrument(skip(self), fields(level = ?level))]
    async fn count_deaths_by_level(&self, level: Level) -> Result<u64> {
        let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM deaths WHERE level = $1")
            .bind(level as i16)
            .fetch_one(&self.pool)
            .await
            .map_err(InfraError::Database)?;

        Ok(count as u64)
    }

    #[instrument(skip(self), fields(limit = limit))]
    async fn get_recent_deaths(&self, limit: u32) -> Result<Vec<Death>> {
        let rows = sqlx::query_as::<_, DeathRow>(
            r#"
            SELECT id, scan_id, user_address, position_id, amount_lost,
                   level, ghost_streak_at_death, created_at
            FROM deaths
            ORDER BY created_at DESC
            LIMIT $1
            "#,
        )
        .bind(limit as i64)
        .fetch_all(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        rows.into_iter()
            .map(|r| Death::try_from(r).map_err(Into::into))
            .collect()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARKET STORE IMPLEMENTATION (placeholder - to be completed)
// ═══════════════════════════════════════════════════════════════════════════════

#[async_trait]
impl MarketStore for PostgresStore {
    async fn save_round(&self, _round: &Round) -> Result<()> {
        // TODO: Implement market store
        Err(InfraError::Internal("Market store not yet implemented".into()).into())
    }

    async fn record_bet(&self, _bet: &Bet) -> Result<()> {
        Err(InfraError::Internal("Market store not yet implemented".into()).into())
    }

    async fn resolve_round(
        &self,
        _round_id: &str,
        _outcome: bool,
        _burned: &TokenAmount,
    ) -> Result<()> {
        Err(InfraError::Internal("Market store not yet implemented".into()).into())
    }

    async fn get_active_rounds(&self, _limit: u32) -> Result<Vec<Round>> {
        Err(InfraError::Internal("Market store not yet implemented".into()).into())
    }

    async fn get_round_by_id(&self, _round_id: &str) -> Result<Option<Round>> {
        Err(InfraError::Internal("Market store not yet implemented".into()).into())
    }

    async fn get_bets_for_round(&self, _round_id: &str) -> Result<Vec<Bet>> {
        Err(InfraError::Internal("Market store not yet implemented".into()).into())
    }

    async fn get_user_bets(&self, _address: &EthAddress, _limit: u32) -> Result<Vec<Bet>> {
        Err(InfraError::Internal("Market store not yet implemented".into()).into())
    }

    async fn mark_bet_claimed(
        &self,
        _round_id: &str,
        _user: &EthAddress,
        _winnings: &TokenAmount,
    ) -> Result<()> {
        Err(InfraError::Internal("Market store not yet implemented".into()).into())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INDEXER STATE STORE IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════

#[async_trait]
impl IndexerStateStore for PostgresStore {
    #[instrument(skip(self))]
    async fn get_last_block(&self) -> Result<BlockNumber> {
        let row: Option<i64> = sqlx::query_scalar(
            "SELECT block_number FROM indexer_state ORDER BY block_number DESC LIMIT 1",
        )
        .fetch_optional(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        Ok(BlockNumber::new(row.unwrap_or(0) as u64))
    }

    #[instrument(skip(self), fields(block = %block.value()))]
    async fn set_last_block(&self, block: BlockNumber, hash: B256) -> Result<()> {
        sqlx::query(
            r#"
            INSERT INTO indexer_state (block_number, block_hash, updated_at)
            VALUES ($1, $2, NOW())
            ON CONFLICT (block_number) DO UPDATE SET
                block_hash = EXCLUDED.block_hash,
                updated_at = NOW()
            "#,
        )
        .bind(block.value() as i64)
        .bind(hash.as_slice())
        .execute(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        debug!("Last block set");
        Ok(())
    }

    #[instrument(skip(self), fields(block = %block.value()))]
    async fn insert_block_hash(
        &self,
        block: BlockNumber,
        hash: B256,
        parent: B256,
        timestamp: u64,
    ) -> Result<()> {
        sqlx::query(
            r#"
            INSERT INTO block_hashes (block_number, block_hash, parent_hash, timestamp)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT (block_number) DO UPDATE SET
                block_hash = EXCLUDED.block_hash,
                parent_hash = EXCLUDED.parent_hash,
                timestamp = EXCLUDED.timestamp
            "#,
        )
        .bind(block.value() as i64)
        .bind(hash.as_slice())
        .bind(parent.as_slice())
        .bind(timestamp as i64)
        .execute(&self.pool)
        .await
        .map_err(InfraError::Database)?;

        Ok(())
    }

    #[instrument(skip(self), fields(block = %block.value()))]
    async fn get_block_hash(&self, block: BlockNumber) -> Result<Option<B256>> {
        let row: Option<Vec<u8>> =
            sqlx::query_scalar("SELECT block_hash FROM block_hashes WHERE block_number = $1")
                .bind(block.value() as i64)
                .fetch_optional(&self.pool)
                .await
                .map_err(InfraError::Database)?;

        match row {
            Some(bytes) => {
                let arr: [u8; 32] = bytes
                    .try_into()
                    .map_err(|_| InfraError::Internal("Invalid block hash length in DB".into()))?;
                Ok(Some(B256::from(arr)))
            }
            None => Ok(None),
        }
    }

    #[instrument(skip(self), fields(fork_point = %fork_point.value()))]
    async fn execute_reorg_rollback(&self, fork_point: BlockNumber) -> Result<()> {
        let mut tx = self.pool.begin().await.map_err(InfraError::Database)?;

        // Delete block hashes after fork point
        sqlx::query("DELETE FROM block_hashes WHERE block_number > $1")
            .bind(fork_point.value() as i64)
            .execute(&mut *tx)
            .await
            .map_err(InfraError::Database)?;

        // Delete indexer state after fork point
        sqlx::query("DELETE FROM indexer_state WHERE block_number > $1")
            .bind(fork_point.value() as i64)
            .execute(&mut *tx)
            .await
            .map_err(InfraError::Database)?;

        // Note: In a real implementation, we'd also need to:
        // - Delete positions created after fork_point
        // - Delete scans executed after fork_point
        // - Delete deaths created after fork_point
        // - Update any positions modified after fork_point
        // This requires tracking block numbers on all entities

        tx.commit().await.map_err(InfraError::Database)?;

        debug!("Reorg rollback executed");
        Ok(())
    }

    #[instrument(skip(self), fields(keep_blocks = keep_blocks))]
    async fn prune_old_blocks(&self, keep_blocks: u64) -> Result<u64> {
        // Get current max block
        let max_block: Option<i64> =
            sqlx::query_scalar("SELECT MAX(block_number) FROM block_hashes")
                .fetch_optional(&self.pool)
                .await
                .map_err(InfraError::Database)?;

        let Some(max) = max_block else {
            return Ok(0);
        };

        let cutoff = max - keep_blocks as i64;
        if cutoff <= 0 {
            return Ok(0);
        }

        let result = sqlx::query("DELETE FROM block_hashes WHERE block_number < $1")
            .bind(cutoff)
            .execute(&self.pool)
            .await
            .map_err(InfraError::Database)?;

        debug!(pruned = result.rows_affected(), "Old blocks pruned");
        Ok(result.rows_affected())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATS STORE IMPLEMENTATION (placeholder - to be completed)
// ═══════════════════════════════════════════════════════════════════════════════

#[async_trait]
impl StatsStore for PostgresStore {
    async fn get_global_stats(&self) -> Result<GlobalStats> {
        // TODO: Implement stats store
        Err(InfraError::Internal("Stats store not yet implemented".into()).into())
    }

    async fn get_level_stats(&self, _level: Level) -> Result<LevelStats> {
        Err(InfraError::Internal("Stats store not yet implemented".into()).into())
    }

    async fn update_level_stats(&self, _level: Level, _delta: LevelStatsDelta) -> Result<()> {
        Err(InfraError::Internal("Stats store not yet implemented".into()).into())
    }

    async fn get_all_level_stats(&self) -> Result<Vec<LevelStats>> {
        Err(InfraError::Internal("Stats store not yet implemented".into()).into())
    }

    async fn refresh_global_stats(&self) -> Result<GlobalStats> {
        Err(InfraError::Internal("Stats store not yet implemented".into()).into())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    // Note: Full integration tests require a PostgreSQL database
    // and are located in tests/store_integration.rs

    #[test]
    fn postgres_store_is_send_sync() {
        fn assert_send_sync<T: Send + Sync>() {}
        // This will fail to compile if PostgresStore is not Send + Sync
        // (required for async trait implementations)
        assert_send_sync::<PostgresStore>();
    }
}
