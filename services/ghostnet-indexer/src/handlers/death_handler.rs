//! Death event handler implementation.
//!
//! Handles all death-related events from the `GhostCore` contract:
//! - `DeathsProcessed` - Deaths are marked after a scan
//! - `SurvivorsUpdated` - Ghost streaks incremented for survivors
//! - `CascadeDistributed` - Rewards distributed to survivors and upstream levels
//! - `EmissionsAdded` - Emissions added to a level
//! - `SystemResetTriggered` - Doomsday clock reset
//!
//! # Death Flow
//!
//! ```text
//! TraceScan::ScanFinalized
//!         │
//!         ▼
//! ┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
//! │ DeathsProcessed │────▶│SurvivorsUpdated  │────▶│CascadeDistributed│
//! │ (mark dead)     │     │ (inc streaks)    │     │ (distribute)    │
//! └─────────────────┘     └──────────────────┘     └─────────────────┘
//! ```
//!
//! # Architecture
//!
//! The handler follows hexagonal architecture principles:
//! - Receives decoded events from the `EventRouter`
//! - Uses `DeathStore` port for death records
//! - Uses `PositionStore` port for position updates
//! - Uses `Cache` port for cache invalidation

use std::sync::Arc;

use async_trait::async_trait;
use tracing::{debug, info, instrument, warn};
use uuid::Uuid;

use crate::abi::ghost_core;
use crate::error::Result;
use crate::handlers::DeathPort;
use crate::ports::{Cache, DeathStore, PositionStore};
use crate::types::entities::{Death, PositionAction, PositionHistoryEntry};
use crate::types::enums::{ExitReason, Level};
use crate::types::events::EventMetadata;
use crate::types::primitives::{BlockNumber, EthAddress, TokenAmount};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Decimals for the $DATA token (standard ERC20).
const DATA_TOKEN_DECIMALS: u8 = 18;

// ═══════════════════════════════════════════════════════════════════════════════
// DEATH HANDLER
// ═══════════════════════════════════════════════════════════════════════════════

/// Handler for death-related events.
///
/// Processes death events from the `GhostCore` contract and maintains
/// death records and position states in the database.
#[derive(Debug)]
pub struct DeathHandler<D, P, C> {
    /// Death store for death records.
    death_store: Arc<D>,
    /// Position store for position updates.
    position_store: Arc<P>,
    /// Cache for invalidation.
    cache: Arc<C>,
}

impl<D, P, C> DeathHandler<D, P, C>
where
    D: DeathStore,
    P: PositionStore,
    C: Cache,
{
    /// Create a new death handler.
    pub const fn new(death_store: Arc<D>, position_store: Arc<P>, cache: Arc<C>) -> Self {
        Self {
            death_store,
            position_store,
            cache,
        }
    }

    /// Convert a u8 level to our Level enum.
    fn to_level(level: u8) -> Result<Level> {
        Ok(Level::try_from(level)?)
    }

    /// Convert an Alloy U256 to our `TokenAmount` type.
    fn to_token_amount(value: &alloy::primitives::U256) -> TokenAmount {
        TokenAmount::from_wei(*value, DATA_TOKEN_DECIMALS)
    }

    /// Convert an Alloy address to our `EthAddress` type.
    const fn to_eth_address(addr: &alloy::primitives::Address) -> EthAddress {
        EthAddress::new(addr.0 .0)
    }

    /// Record a position history entry.
    async fn record_history(
        &self,
        position_id: Uuid,
        user_address: EthAddress,
        action: PositionAction,
        amount_change: TokenAmount,
        new_total: TokenAmount,
        meta: &EventMetadata,
    ) -> Result<()> {
        let entry = PositionHistoryEntry {
            id: Uuid::new_v4(),
            position_id,
            user_address,
            action,
            amount_change,
            new_total,
            block_number: BlockNumber::new(meta.block_number),
            timestamp: meta.timestamp,
        };

        self.position_store.record_history(&entry).await
    }
}

#[async_trait]
impl<D, P, C> DeathPort for DeathHandler<D, P, C>
where
    D: DeathStore + Send + Sync,
    P: PositionStore + Send + Sync,
    C: Cache + Send + Sync,
{
    /// Handle deaths processed after a scan.
    ///
    /// This event indicates that deaths have been marked in the contract.
    /// We record death records and update affected positions.
    ///
    /// Note: Individual victim addresses are not included in this event.
    /// Those come from the `DeathsSubmitted` events in `TraceScan` or
    /// would need to be fetched from on-chain state.
    #[instrument(skip(self, event, meta), fields(level = event.level, count = %event.count))]
    async fn handle_deaths_processed(
        &self,
        event: ghost_core::DeathsProcessed,
        meta: EventMetadata,
    ) -> Result<()> {
        let level = Self::to_level(event.level)?;
        let count: u32 = event.count.try_into().unwrap_or(u32::MAX);
        let total_dead = Self::to_token_amount(&event.totalDead);
        let burned = Self::to_token_amount(&event.burned);
        let distributed = Self::to_token_amount(&event.distributed);

        // Note: This event doesn't include individual victim addresses.
        // In a full implementation, we would:
        // 1. Track a pending scan ID
        // 2. Correlate with DeathsSubmitted events to get victim lists
        // 3. Or fetch victims from on-chain logs/state
        //
        // For now, we log the aggregate data. Individual death records
        // would be created when we implement the full death tracking flow.

        debug!(
            level = ?level,
            death_count = count,
            total_dead = %total_dead,
            burned = %burned,
            distributed = %distributed,
            block = meta.block_number,
            "Deaths processed"
        );

        // Invalidate cache for this level
        self.cache.invalidate_level(&level);

        info!(
            level = ?level,
            count,
            total_dead = %total_dead,
            "Deaths processed for level"
        );

        Ok(())
    }

    /// Handle survivor streak updates.
    ///
    /// After a scan, survivors get their ghost streak incremented.
    #[instrument(skip(self, event, meta), fields(level = event.level, count = %event.count))]
    async fn handle_survivors_updated(
        &self,
        event: ghost_core::SurvivorsUpdated,
        meta: EventMetadata,
    ) -> Result<()> {
        let level = Self::to_level(event.level)?;
        let survivor_count: u32 = event.count.try_into().unwrap_or(u32::MAX);

        // Note: Survivor addresses are not included in this event.
        // Individual streak updates would need to be fetched from on-chain
        // or tracked through other mechanisms.

        debug!(
            level = ?level,
            survivor_count,
            block = meta.block_number,
            "Survivors updated"
        );

        // Invalidate cache for this level
        self.cache.invalidate_level(&level);

        info!(
            level = ?level,
            survivor_count,
            "Ghost streaks updated for survivors"
        );

        Ok(())
    }

    /// Handle cascade reward distribution.
    ///
    /// When deaths occur, rewards are distributed:
    /// - 30% to same-level survivors
    /// - 30% to upstream (safer) levels
    /// - 30% burned
    /// - 10% to protocol treasury
    #[instrument(skip(self, event, meta), fields(source_level = event.sourceLevel))]
    async fn handle_cascade_distributed(
        &self,
        event: ghost_core::CascadeDistributed,
        meta: EventMetadata,
    ) -> Result<()> {
        let source_level = Self::to_level(event.sourceLevel)?;
        let same_level_amount = Self::to_token_amount(&event.sameLevelAmount);
        let upstream_amount = Self::to_token_amount(&event.upstreamAmount);
        let burn_amount = Self::to_token_amount(&event.burnAmount);
        let protocol_amount = Self::to_token_amount(&event.protocolAmount);

        // Log the distribution for analytics
        debug!(
            source_level = ?source_level,
            same_level = %same_level_amount,
            upstream = %upstream_amount,
            burn = %burn_amount,
            protocol = %protocol_amount,
            block = meta.block_number,
            "Cascade distributed"
        );

        // Invalidate caches for affected levels
        // Same level and all upstream (safer) levels
        self.cache.invalidate_level(&source_level);

        // Invalidate upstream levels (Vault receives from all, etc.)
        for level_value in 0..source_level as u8 {
            if let Ok(upstream_level) = Level::try_from(level_value) {
                self.cache.invalidate_level(&upstream_level);
            }
        }

        info!(
            source_level = ?source_level,
            same_level = %same_level_amount,
            upstream = %upstream_amount,
            burn = %burn_amount,
            "Cascade rewards distributed"
        );

        Ok(())
    }

    /// Handle emissions added to a level.
    ///
    /// Emissions from the `RewardsDistributor` are added to levels
    /// based on their weights.
    #[instrument(skip(self, event, meta), fields(level = event.level))]
    async fn handle_emissions_added(
        &self,
        event: ghost_core::EmissionsAdded,
        meta: EventMetadata,
    ) -> Result<()> {
        let level = Self::to_level(event.level)?;
        let amount = Self::to_token_amount(&event.amount);

        debug!(
            level = ?level,
            amount = %amount,
            block = meta.block_number,
            "Emissions added"
        );

        // Invalidate cache for this level
        self.cache.invalidate_level(&level);

        info!(
            level = ?level,
            amount = %amount,
            "Emissions added to level"
        );

        Ok(())
    }

    /// Handle system reset (doomsday clock triggered).
    ///
    /// When the doomsday clock hits zero:
    /// - All positions take a penalty
    /// - Last depositor wins the jackpot
    /// - System is reset
    #[instrument(skip(self, event, meta), fields(jackpot_winner = %event.jackpotWinner))]
    async fn handle_system_reset(
        &self,
        event: ghost_core::SystemResetTriggered,
        meta: EventMetadata,
    ) -> Result<()> {
        let total_penalty = Self::to_token_amount(&event.totalPenalty);
        let jackpot_winner = Self::to_eth_address(&event.jackpotWinner);
        let jackpot_amount = Self::to_token_amount(&event.jackpotAmount);

        // Get all active positions across all levels
        // In a full implementation, we would:
        // 1. Iterate through all levels
        // 2. Close all active positions with ExitReason::SystemReset
        // 3. Record death/penalty records
        //
        // For now, we log the reset event

        warn!(
            total_penalty = %total_penalty,
            jackpot_winner = %jackpot_winner,
            jackpot_amount = %jackpot_amount,
            block = meta.block_number,
            "SYSTEM RESET TRIGGERED - Doomsday!"
        );

        // Process all levels
        for level_value in 0..=5 {
            if let Ok(level) = Level::try_from(level_value) {
                // Get all active positions for this level
                let positions = self.position_store.get_positions_by_level(level).await?;

                for mut position in positions {
                    if !position.is_active() {
                        continue;
                    }

                    // Close the position
                    position.is_alive = false;
                    position.exit_reason = Some(ExitReason::SystemReset);
                    position.exit_timestamp = Some(meta.timestamp);
                    position.updated_at = meta.timestamp;

                    // Save updated position
                    self.position_store.save_position(&position).await?;

                    // Record history
                    self.record_history(
                        position.id,
                        position.user_address,
                        PositionAction::SystemReset,
                        position.amount.clone(), // Amount lost
                        TokenAmount::zero(),     // New total is zero
                        &meta,
                    )
                    .await?;

                    // Create death record
                    let death = Death {
                        id: Uuid::new_v4(),
                        scan_id: None, // System reset, not a scan
                        user_address: position.user_address,
                        position_id: Some(position.id),
                        amount_lost: position.amount.clone(),
                        level: position.level,
                        ghost_streak_at_death: Some(position.ghost_streak),
                        created_at: meta.timestamp,
                    };

                    self.death_store.record_deaths(&[death]).await?;
                }

                // Invalidate cache for this level
                self.cache.invalidate_level(&level);
            }
        }

        info!(
            total_penalty = %total_penalty,
            jackpot_winner = %jackpot_winner,
            jackpot_amount = %jackpot_amount,
            "System reset complete - all positions closed"
        );

        Ok(())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
#[allow(clippy::unwrap_used)]
mod tests {
    use std::collections::HashMap;
    use std::sync::RwLock;

    use alloy::primitives::{Address, U256};
    use chrono::Utc;
    use uuid::Uuid;

    use super::*;
    use crate::ports::MockCache;
    use crate::types::entities::{Position, PositionHistoryEntry};
    use crate::types::enums::Level;
    use crate::types::primitives::GhostStreak;

    // ═══════════════════════════════════════════════════════════════════════════
    // MOCK STORES
    // ═══════════════════════════════════════════════════════════════════════════

    /// Mock death store for testing.
    #[derive(Debug, Default)]
    struct MockDeathStore {
        deaths: RwLock<Vec<Death>>,
    }

    impl MockDeathStore {
        fn new() -> Self {
            Self::default()
        }

        fn death_count(&self) -> usize {
            self.deaths.read().unwrap().len()
        }
    }

    #[async_trait]
    impl DeathStore for MockDeathStore {
        async fn record_deaths(&self, deaths: &[Death]) -> Result<()> {
            let mut store = self.deaths.write().unwrap();
            store.extend(deaths.iter().cloned());
            Ok(())
        }

        async fn get_deaths_for_scan(&self, _scan_id: &str) -> Result<Vec<Death>> {
            Ok(vec![])
        }

        async fn get_user_deaths(&self, _address: &EthAddress, _limit: u32) -> Result<Vec<Death>> {
            Ok(vec![])
        }

        async fn count_deaths_by_level(&self, level: Level) -> Result<u64> {
            let deaths = self.deaths.read().unwrap();
            Ok(deaths.iter().filter(|d| d.level == level).count() as u64)
        }

        async fn get_recent_deaths(&self, limit: u32) -> Result<Vec<Death>> {
            let deaths = self.deaths.read().unwrap();
            let mut result = deaths.clone();
            result.truncate(limit as usize);
            Ok(result)
        }
    }

    /// Mock position store for testing.
    #[derive(Debug, Default)]
    struct MockPositionStore {
        positions: RwLock<HashMap<EthAddress, Position>>,
        history: RwLock<Vec<PositionHistoryEntry>>,
    }

    impl MockPositionStore {
        fn new() -> Self {
            Self::default()
        }

        fn with_position(self, position: Position) -> Self {
            self.positions
                .write()
                .unwrap()
                .insert(position.user_address, position);
            self
        }

        fn with_positions(self, positions: Vec<Position>) -> Self {
            let mut store = self.positions.write().unwrap();
            for position in positions {
                store.insert(position.user_address, position);
            }
            drop(store);
            self
        }

        fn get_position(&self, address: &EthAddress) -> Option<Position> {
            self.positions.read().unwrap().get(address).cloned()
        }

        fn position_count(&self) -> usize {
            self.positions.read().unwrap().len()
        }

        fn alive_position_count(&self) -> usize {
            self.positions
                .read()
                .unwrap()
                .values()
                .filter(|p| p.is_alive)
                .count()
        }

        fn history_count(&self) -> usize {
            self.history.read().unwrap().len()
        }
    }

    #[async_trait]
    impl PositionStore for MockPositionStore {
        async fn get_active_position(&self, address: &EthAddress) -> Result<Option<Position>> {
            let positions = self.positions.read().unwrap();
            Ok(positions
                .get(address)
                .filter(|p| p.is_alive && !p.is_extracted)
                .cloned())
        }

        async fn save_position(&self, position: &Position) -> Result<()> {
            let mut positions = self.positions.write().unwrap();
            positions.insert(position.user_address, position.clone());
            Ok(())
        }

        async fn get_at_risk_positions(&self, _level: Level, _limit: u32) -> Result<Vec<Position>> {
            Ok(vec![])
        }

        async fn record_history(&self, entry: &PositionHistoryEntry) -> Result<()> {
            let mut history = self.history.write().unwrap();
            history.push(entry.clone());
            Ok(())
        }

        async fn get_position_by_id(&self, _id: &Uuid) -> Result<Option<Position>> {
            Ok(None)
        }

        async fn get_positions_by_level(&self, level: Level) -> Result<Vec<Position>> {
            let positions = self.positions.read().unwrap();
            Ok(positions
                .values()
                .filter(|p| p.level == level && p.is_alive)
                .cloned()
                .collect())
        }

        async fn count_positions_by_level(&self, level: Level) -> Result<u32> {
            let positions = self.positions.read().unwrap();
            Ok(positions
                .values()
                .filter(|p| p.level == level && p.is_alive)
                .count() as u32)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    fn test_address() -> Address {
        "0x1234567890123456789012345678901234567890"
            .parse()
            .unwrap()
    }

    fn test_eth_address() -> EthAddress {
        EthAddress::new(test_address().0 .0)
    }

    fn test_metadata() -> EventMetadata {
        EventMetadata {
            block_number: 1000,
            block_hash: [1u8; 32].into(),
            tx_hash: [2u8; 32].into(),
            tx_index: 0,
            log_index: 0,
            timestamp: Utc::now(),
            contract: test_address(),
        }
    }

    fn create_test_position(level: Level) -> Position {
        create_test_position_for_user(level, test_eth_address())
    }

    fn create_test_position_for_user(level: Level, user_address: EthAddress) -> Position {
        Position {
            id: Uuid::new_v4(),
            user_address,
            level,
            amount: TokenAmount::parse("1000").unwrap(),
            reward_debt: TokenAmount::zero(),
            entry_timestamp: Utc::now(),
            last_add_timestamp: None,
            ghost_streak: GhostStreak::ZERO,
            is_alive: true,
            is_extracted: false,
            exit_reason: None,
            exit_timestamp: None,
            extracted_amount: None,
            extracted_rewards: None,
            created_at_block: BlockNumber::new(900),
            updated_at: Utc::now(),
        }
    }

    fn eth_address_from_byte(byte: u8) -> EthAddress {
        let mut bytes = [0u8; 20];
        bytes[19] = byte;
        EthAddress::new(bytes)
    }

    fn create_handler() -> (
        DeathHandler<MockDeathStore, MockPositionStore, MockCache>,
        Arc<MockDeathStore>,
        Arc<MockPositionStore>,
        Arc<MockCache>,
    ) {
        let death_store = Arc::new(MockDeathStore::new());
        let position_store = Arc::new(MockPositionStore::new());
        let cache = Arc::new(MockCache::new());
        let handler = DeathHandler::new(
            Arc::clone(&death_store),
            Arc::clone(&position_store),
            Arc::clone(&cache),
        );
        (handler, death_store, position_store, cache)
    }

    fn create_handler_with_position(
        position: Position,
    ) -> (
        DeathHandler<MockDeathStore, MockPositionStore, MockCache>,
        Arc<MockDeathStore>,
        Arc<MockPositionStore>,
        Arc<MockCache>,
    ) {
        let death_store = Arc::new(MockDeathStore::new());
        let position_store = Arc::new(MockPositionStore::new().with_position(position));
        let cache = Arc::new(MockCache::new());
        let handler = DeathHandler::new(
            Arc::clone(&death_store),
            Arc::clone(&position_store),
            Arc::clone(&cache),
        );
        (handler, death_store, position_store, cache)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn handler_is_send_sync() {
        fn assert_send_sync<T: Send + Sync>() {}
        assert_send_sync::<DeathHandler<MockDeathStore, MockPositionStore, MockCache>>();
    }

    #[tokio::test]
    async fn handle_deaths_processed_succeeds() {
        let (handler, _death_store, _position_store, _cache) = create_handler();

        let event = ghost_core::DeathsProcessed {
            level: 3,
            count: U256::from(5),
            totalDead: U256::from(500_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            burned: U256::from(150_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            distributed: U256::from(350_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };

        let result = handler
            .handle_deaths_processed(event, test_metadata())
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_survivors_updated_succeeds() {
        let (handler, _death_store, _position_store, _cache) = create_handler();

        let event = ghost_core::SurvivorsUpdated {
            level: 4,
            count: U256::from(95),
        };

        let result = handler
            .handle_survivors_updated(event, test_metadata())
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_cascade_distributed_succeeds() {
        let (handler, _death_store, _position_store, _cache) = create_handler();

        let event = ghost_core::CascadeDistributed {
            sourceLevel: 4,
            sameLevelAmount: U256::from(300_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            upstreamAmount: U256::from(300_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            burnAmount: U256::from(300_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            protocolAmount: U256::from(100_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };

        let result = handler
            .handle_cascade_distributed(event, test_metadata())
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_emissions_added_succeeds() {
        let (handler, _death_store, _position_store, _cache) = create_handler();

        let event = ghost_core::EmissionsAdded {
            level: 2,
            amount: U256::from(1000_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };

        let result = handler.handle_emissions_added(event, test_metadata()).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_system_reset_closes_all_positions() {
        let position = create_test_position(Level::Subnet);
        let user_address = position.user_address;
        let (handler, death_store, position_store, _cache) =
            create_handler_with_position(position);

        let event = ghost_core::SystemResetTriggered {
            totalPenalty: U256::from(10000_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            jackpotWinner: test_address(),
            jackpotAmount: U256::from(5000_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };

        let result = handler.handle_system_reset(event, test_metadata()).await;
        assert!(result.is_ok());

        // Verify position was closed
        let updated_position = position_store.get_position(&user_address).unwrap();
        assert!(!updated_position.is_alive);
        assert_eq!(updated_position.exit_reason, Some(ExitReason::SystemReset));

        // Verify death was recorded
        assert_eq!(death_store.death_count(), 1);

        // Verify history was recorded
        assert_eq!(position_store.history_count(), 1);
    }

    #[tokio::test]
    async fn handle_system_reset_with_no_positions_succeeds() {
        let (handler, death_store, position_store, _cache) = create_handler();

        let event = ghost_core::SystemResetTriggered {
            totalPenalty: U256::from(0),
            jackpotWinner: test_address(),
            jackpotAmount: U256::from(0),
        };

        let result = handler.handle_system_reset(event, test_metadata()).await;
        assert!(result.is_ok());

        // No deaths or history since there were no positions
        assert_eq!(death_store.death_count(), 0);
        assert_eq!(position_store.history_count(), 0);
    }

    #[tokio::test]
    async fn handle_system_reset_closes_multiple_positions_across_levels() {
        // Create positions across different levels with different users
        let positions = vec![
            create_test_position_for_user(Level::Vault, eth_address_from_byte(1)),
            create_test_position_for_user(Level::Mainframe, eth_address_from_byte(2)),
            create_test_position_for_user(Level::Subnet, eth_address_from_byte(3)),
            create_test_position_for_user(Level::Darknet, eth_address_from_byte(4)),
            create_test_position_for_user(Level::BlackIce, eth_address_from_byte(5)),
        ];

        let death_store = Arc::new(MockDeathStore::new());
        let position_store = Arc::new(MockPositionStore::new().with_positions(positions));
        let cache = Arc::new(MockCache::new());
        let handler = DeathHandler::new(
            Arc::clone(&death_store),
            Arc::clone(&position_store),
            Arc::clone(&cache),
        );

        // Verify initial state
        assert_eq!(position_store.position_count(), 5);
        assert_eq!(position_store.alive_position_count(), 5);

        let event = ghost_core::SystemResetTriggered {
            totalPenalty: U256::from(50000_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            jackpotWinner: test_address(),
            jackpotAmount: U256::from(25000_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };

        let result = handler.handle_system_reset(event, test_metadata()).await;
        assert!(result.is_ok());

        // Verify all positions were closed
        assert_eq!(position_store.alive_position_count(), 0);

        // Verify deaths were recorded for all positions
        assert_eq!(death_store.death_count(), 5);

        // Verify history was recorded for all positions
        assert_eq!(position_store.history_count(), 5);

        // Verify each position has correct exit reason
        for byte in 1..=5 {
            let addr = eth_address_from_byte(byte);
            let position = position_store.get_position(&addr).unwrap();
            assert!(!position.is_alive);
            assert_eq!(position.exit_reason, Some(ExitReason::SystemReset));
        }
    }

    #[test]
    fn to_level_valid_values() {
        assert!(DeathHandler::<MockDeathStore, MockPositionStore, MockCache>::to_level(0).is_ok());
        assert!(DeathHandler::<MockDeathStore, MockPositionStore, MockCache>::to_level(5).is_ok());
    }

    #[test]
    fn to_level_invalid_value() {
        assert!(DeathHandler::<MockDeathStore, MockPositionStore, MockCache>::to_level(6).is_err());
    }
}
