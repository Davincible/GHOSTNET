//! Market event handler implementation.
//!
//! Handles all prediction market events from the `DeadPool` contract:
//! - `RoundCreated` - New betting round created
//! - `BetPlaced` - User places a bet
//! - `RoundResolved` - Round resolved with outcome
//! - `WinningsClaimed` - User claims winnings
//!
//! # Round Lifecycle
//!
//! ```text
//! ┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
//! │  RoundCreated   │────▶│    BetPlaced     │────▶│  RoundResolved  │
//! │                 │     │   (0..N bets)    │     │                 │
//! └─────────────────┘     └──────────────────┘     └────────┬────────┘
//!                                                           │
//!                                                           ▼
//!                                                  ┌─────────────────┐
//!                                                  │ WinningsClaimed │
//!                                                  │   (per winner)  │
//!                                                  └─────────────────┘
//! ```
//!
//! # Round Types
//!
//! | Type | Description |
//! |------|-------------|
//! | `DeathCount` (0) | Over/under on deaths in next scan |
//! | `WhaleDeath` (1) | Will a 1000+ DATA position die? |
//! | `StreakRecord` (2) | Will anyone hit 20 survival streak? |
//! | `SystemReset` (3) | Will the reset timer hit <1 hour? |
//!
//! # Architecture
//!
//! The handler follows hexagonal architecture principles:
//! - Receives decoded events from the `EventRouter`
//! - Uses `MarketStore` port for persistence
//! - Uses `Cache` port for cache invalidation

use std::sync::Arc;

use async_trait::async_trait;
use chrono::{TimeZone, Utc};
use tracing::{debug, info, instrument, warn};
use uuid::Uuid;

use crate::abi::dead_pool;
use crate::error::Result;
use crate::handlers::MarketPort;
use crate::ports::{Cache, MarketStore};
use crate::types::entities::{Bet, Round};
use crate::types::enums::{Level, RoundType};
use crate::types::events::EventMetadata;
use crate::types::primitives::{EthAddress, TokenAmount};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Decimals for the $DATA token (standard ERC20).
const DATA_TOKEN_DECIMALS: u8 = 18;

// ═══════════════════════════════════════════════════════════════════════════════
// MARKET HANDLER
// ═══════════════════════════════════════════════════════════════════════════════

/// Handler for prediction market events.
///
/// Processes events from the `DeadPool` contract and maintains
/// round and bet records in the database.
#[derive(Debug)]
pub struct MarketHandler<S, C> {
    /// Market store for persistence.
    store: Arc<S>,
    /// Cache for invalidation.
    cache: Arc<C>,
}

impl<S, C> MarketHandler<S, C>
where
    S: MarketStore,
    C: Cache,
{
    /// Create a new market handler.
    pub const fn new(store: Arc<S>, cache: Arc<C>) -> Self {
        Self { store, cache }
    }

    /// Convert a u8 round type to our `RoundType` enum.
    fn to_round_type(round_type: u8) -> Result<RoundType> {
        Ok(RoundType::try_from(round_type)?)
    }

    /// Convert a u8 level to our `Level` enum for market rounds.
    ///
    /// In the `DeadPool` contract, `targetLevel` uses these semantics:
    /// - `0` = Global round (not tied to any specific level)
    /// - `1-5` = Level-specific round (Vault, Mainframe, Subnet, Darknet, BlackIce)
    ///
    /// Note: This differs from `Level::None` which represents "no position".
    /// Here, `None` means "global/all levels" for market targeting purposes.
    ///
    /// # Returns
    /// - `Ok(None)` for level 0 (global round)
    /// - `Ok(Some(Level))` for levels 1-5
    /// - `Err` for invalid level values (6+)
    fn to_optional_level(level: u8) -> Result<Option<Level>> {
        if level == 0 {
            // Global round - not targeting any specific level
            Ok(None)
        } else {
            // Level-specific round
            Ok(Some(Level::try_from(level)?))
        }
    }

    /// Convert an Alloy U256 to our `TokenAmount` type.
    fn to_token_amount(value: &alloy::primitives::U256) -> TokenAmount {
        TokenAmount::from_wei(*value, DATA_TOKEN_DECIMALS)
    }

    /// Convert an Alloy Address to our `EthAddress` type.
    fn to_eth_address(address: &alloy::primitives::Address) -> EthAddress {
        EthAddress::from(*address)
    }

    /// Convert a unix timestamp to `DateTime`.
    #[allow(clippy::cast_possible_wrap)]
    fn to_datetime(timestamp: u64) -> chrono::DateTime<Utc> {
        // Note: cast is safe for reasonable timestamps (before year 2262)
        Utc.timestamp_opt(timestamp as i64, 0)
            .single()
            .unwrap_or_else(Utc::now)
    }
}

#[async_trait]
impl<S, C> MarketPort for MarketHandler<S, C>
where
    S: MarketStore + Send + Sync,
    C: Cache + Send + Sync,
{
    /// Handle new betting round creation.
    ///
    /// Creates a new round record when a round is created.
    #[instrument(skip(self, event, meta), fields(
        round_id = %event.roundId,
        round_type = event.roundType,
        target_level = event.targetLevel
    ))]
    async fn handle_round_created(
        &self,
        event: dead_pool::RoundCreated,
        meta: EventMetadata,
    ) -> Result<()> {
        let round_id = event.roundId.to_string();
        let round_type = Self::to_round_type(event.roundType)?;
        let target_level = Self::to_optional_level(event.targetLevel)?;
        let line = Self::to_token_amount(&event.line);
        let deadline = Self::to_datetime(event.deadline);

        // Check if round already exists (idempotency)
        if let Some(existing) = self.store.get_round_by_id(&round_id).await? {
            warn!(
                existing_id = %existing.id,
                "Round already exists, skipping"
            );
            return Ok(());
        }

        // Create new round record
        let round = Round {
            id: Uuid::new_v4(),
            round_id: round_id.clone(),
            round_type,
            target_level,
            line: line.clone(),
            deadline,
            over_pool: TokenAmount::zero(),
            under_pool: TokenAmount::zero(),
            is_resolved: false,
            outcome: None,
            resolve_time: None,
            total_burned: None,
        };

        // Save to database
        self.store.save_round(&round).await?;

        // Invalidate cache
        self.cache.invalidate_all_positions();

        info!(
            round_uuid = %round.id,
            round_type = ?round_type,
            target_level = ?target_level,
            line = %line,
            deadline = %deadline,
            block = meta.block_number,
            "Round created"
        );

        Ok(())
    }

    /// Handle bet placement.
    ///
    /// Records the bet and updates the round's pool totals.
    #[instrument(skip(self, event, meta), fields(
        round_id = %event.roundId,
        user = %event.user,
        is_over = event.isOver
    ))]
    async fn handle_bet_placed(
        &self,
        event: dead_pool::BetPlaced,
        meta: EventMetadata,
    ) -> Result<()> {
        let round_id_str = event.roundId.to_string();
        let user_address = Self::to_eth_address(&event.user);
        let amount = Self::to_token_amount(&event.amount);
        let is_over = event.isOver;

        // Get the round to link the bet
        let round = self.store.get_round_by_id(&round_id_str).await?;
        let Some(round) = round else {
            warn!(
                round_id = %round_id_str,
                "BetPlaced received for unknown round"
            );
            return Ok(());
        };

        // Check if round is already resolved
        if round.is_resolved {
            warn!(
                round_id = %round_id_str,
                "BetPlaced received for already resolved round"
            );
            return Ok(());
        }

        // Create bet record
        let bet = Bet {
            id: Uuid::new_v4(),
            round_id: round.id,
            user_address,
            amount: amount.clone(),
            is_over,
            is_claimed: false,
            winnings: None,
            claimed_at: None,
        };

        // Record bet (this should also update round pool totals)
        self.store.record_bet(&bet).await?;

        // Invalidate cache
        self.cache.invalidate_all_positions();

        let side = if is_over { "OVER" } else { "UNDER" };
        info!(
            bet_id = %bet.id,
            round_id = %round_id_str,
            user = %user_address,
            amount = %amount,
            side = side,
            block = meta.block_number,
            "Bet placed"
        );

        Ok(())
    }

    /// Handle round resolution.
    ///
    /// Marks the round as resolved with the outcome.
    #[instrument(skip(self, event, meta), fields(
        round_id = %event.roundId,
        outcome = event.outcome
    ))]
    async fn handle_round_resolved(
        &self,
        event: dead_pool::RoundResolved,
        meta: EventMetadata,
    ) -> Result<()> {
        let round_id = event.roundId.to_string();
        let outcome = event.outcome;
        let total_pot = Self::to_token_amount(&event.totalPot);
        let burned = Self::to_token_amount(&event.burned);

        // Check if round exists
        let existing = self.store.get_round_by_id(&round_id).await?;
        let Some(existing) = existing else {
            warn!(
                round_id = %round_id,
                "RoundResolved received for unknown round"
            );
            return Ok(());
        };

        // Check if already resolved (idempotency)
        if existing.is_resolved {
            warn!(
                round_id = %round_id,
                "Round already resolved, skipping"
            );
            return Ok(());
        }

        // Resolve the round
        self.store
            .resolve_round(&round_id, outcome, &burned)
            .await?;

        // Invalidate cache
        self.cache.invalidate_all_positions();

        let outcome_str = if outcome { "OVER" } else { "UNDER" };
        info!(
            round_id = %round_id,
            outcome = outcome_str,
            total_pot = %total_pot,
            burned = %burned,
            block = meta.block_number,
            "Round resolved"
        );

        Ok(())
    }

    /// Handle winnings claim.
    ///
    /// Marks the bet as claimed and records the payout.
    #[instrument(skip(self, event, meta), fields(
        round_id = %event.roundId,
        user = %event.user
    ))]
    async fn handle_winnings_claimed(
        &self,
        event: dead_pool::WinningsClaimed,
        meta: EventMetadata,
    ) -> Result<()> {
        let round_id = event.roundId.to_string();
        let user_address = Self::to_eth_address(&event.user);
        let winnings = Self::to_token_amount(&event.amount);

        // Mark the bet as claimed
        self.store
            .mark_bet_claimed(&round_id, &user_address, &winnings)
            .await?;

        // Invalidate cache
        self.cache.invalidate_all_positions();

        debug!(
            round_id = %round_id,
            user = %user_address,
            winnings = %winnings,
            block = meta.block_number,
            "Winnings claimed"
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

    use alloy::primitives::U256;
    use chrono::Utc;

    use super::*;
    use crate::ports::MockCache;
    use crate::types::enums::Level;

    // ═══════════════════════════════════════════════════════════════════════════
    // MOCK MARKET STORE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Stateful mock store for testing.
    #[derive(Debug, Default)]
    struct MockMarketStore {
        rounds: RwLock<HashMap<String, Round>>,
        bets: RwLock<Vec<Bet>>,
    }

    impl MockMarketStore {
        fn new() -> Self {
            Self::default()
        }

        fn round_count(&self) -> usize {
            self.rounds.read().unwrap().len()
        }

        fn bet_count(&self) -> usize {
            self.bets.read().unwrap().len()
        }

        fn get_round(&self, round_id: &str) -> Option<Round> {
            self.rounds.read().unwrap().get(round_id).cloned()
        }

        fn get_bets(&self) -> Vec<Bet> {
            self.bets.read().unwrap().clone()
        }
    }

    #[async_trait]
    impl MarketStore for MockMarketStore {
        async fn save_round(&self, round: &Round) -> Result<()> {
            let mut rounds = self.rounds.write().unwrap();
            rounds.insert(round.round_id.clone(), round.clone());
            Ok(())
        }

        async fn record_bet(&self, bet: &Bet) -> Result<()> {
            // Update round pool totals
            let round_id = {
                let rounds = self.rounds.read().unwrap();
                rounds
                    .values()
                    .find(|r| r.id == bet.round_id)
                    .map(|r| r.round_id.clone())
            };

            if let Some(round_id) = round_id {
                let mut rounds = self.rounds.write().unwrap();
                if let Some(round) = rounds.get_mut(&round_id) {
                    if bet.is_over {
                        round.over_pool = round.over_pool.saturating_add(&bet.amount);
                    } else {
                        round.under_pool = round.under_pool.saturating_add(&bet.amount);
                    }
                }
            }

            // Record the bet
            let mut bets = self.bets.write().unwrap();
            bets.push(bet.clone());
            Ok(())
        }

        async fn resolve_round(
            &self,
            round_id: &str,
            outcome: bool,
            burned: &TokenAmount,
        ) -> Result<()> {
            let mut rounds = self.rounds.write().unwrap();
            if let Some(round) = rounds.get_mut(round_id) {
                round.is_resolved = true;
                round.outcome = Some(outcome);
                round.resolve_time = Some(Utc::now());
                round.total_burned = Some(burned.clone());
                Ok(())
            } else {
                Err(crate::error::InfraError::NotFound.into())
            }
        }

        async fn get_active_rounds(&self, limit: u32) -> Result<Vec<Round>> {
            let rounds = self.rounds.read().unwrap();
            let mut active: Vec<_> = rounds
                .values()
                .filter(|r| !r.is_resolved)
                .cloned()
                .collect();
            active.truncate(limit as usize);
            Ok(active)
        }

        async fn get_round_by_id(&self, round_id: &str) -> Result<Option<Round>> {
            Ok(self.rounds.read().unwrap().get(round_id).cloned())
        }

        async fn get_bets_for_round(&self, round_id: &str) -> Result<Vec<Bet>> {
            let rounds = self.rounds.read().unwrap();
            let round = rounds.get(round_id);
            let Some(round) = round else {
                return Ok(vec![]);
            };

            let bets = self.bets.read().unwrap();
            Ok(bets
                .iter()
                .filter(|b| b.round_id == round.id)
                .cloned()
                .collect())
        }

        async fn get_user_bets(&self, address: &EthAddress, limit: u32) -> Result<Vec<Bet>> {
            let bets = self.bets.read().unwrap();
            let mut user_bets: Vec<_> = bets
                .iter()
                .filter(|b| &b.user_address == address)
                .cloned()
                .collect();
            user_bets.truncate(limit as usize);
            Ok(user_bets)
        }

        async fn mark_bet_claimed(
            &self,
            round_id: &str,
            user: &EthAddress,
            winnings: &TokenAmount,
        ) -> Result<()> {
            // Find the round's UUID
            let round_uuid = {
                let rounds = self.rounds.read().unwrap();
                rounds.get(round_id).map(|r| r.id)
            };
            let Some(round_uuid) = round_uuid else {
                return Err(crate::error::InfraError::NotFound.into());
            };

            // Update the bet
            let mut bets = self.bets.write().unwrap();
            if let Some(bet) = bets
                .iter_mut()
                .find(|b| b.round_id == round_uuid && &b.user_address == user)
            {
                bet.is_claimed = true;
                bet.winnings = Some(winnings.clone());
                bet.claimed_at = Some(Utc::now());
                Ok(())
            } else {
                Err(crate::error::InfraError::NotFound.into())
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    fn test_address() -> alloy::primitives::Address {
        "0x1234567890123456789012345678901234567890"
            .parse()
            .unwrap()
    }

    fn test_address_2() -> alloy::primitives::Address {
        "0xABCDEF1234567890ABCDEF1234567890ABCDEF12"
            .parse()
            .unwrap()
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

    fn create_handler() -> (
        MarketHandler<MockMarketStore, MockCache>,
        Arc<MockMarketStore>,
        Arc<MockCache>,
    ) {
        let store = Arc::new(MockMarketStore::new());
        let cache = Arc::new(MockCache::new());
        let handler = MarketHandler::new(Arc::clone(&store), Arc::clone(&cache));
        (handler, store, cache)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn handler_is_send_sync() {
        fn assert_send_sync<T: Send + Sync>() {}
        assert_send_sync::<MarketHandler<MockMarketStore, MockCache>>();
    }

    #[tokio::test]
    async fn handle_round_created_creates_round() {
        let (handler, store, _cache) = create_handler();

        let event = dead_pool::RoundCreated {
            roundId: U256::from(1),
            roundType: 0,   // DeathCount
            targetLevel: 4, // Darknet
            line: U256::from(10_u64) * U256::from(10_u64).pow(U256::from(18_u64)), // 10 DATA
            deadline: 1_700_000_000,
        };

        let result = handler.handle_round_created(event, test_metadata()).await;
        assert!(result.is_ok());

        // Verify round was created
        assert_eq!(store.round_count(), 1);

        let round = store.get_round("1").unwrap();
        assert_eq!(round.round_type, RoundType::DeathCount);
        assert_eq!(round.target_level, Some(Level::Darknet));
        assert_eq!(round.line.to_string(), "10");
        assert!(!round.is_resolved);
    }

    #[tokio::test]
    async fn handle_round_created_global_round_has_no_level() {
        let (handler, store, _cache) = create_handler();

        let event = dead_pool::RoundCreated {
            roundId: U256::from(1),
            roundType: 3,   // SystemReset
            targetLevel: 0, // Global
            line: U256::from(0),
            deadline: 1_700_000_000,
        };

        handler
            .handle_round_created(event, test_metadata())
            .await
            .unwrap();

        let round = store.get_round("1").unwrap();
        assert_eq!(round.round_type, RoundType::SystemReset);
        assert_eq!(round.target_level, None);
    }

    #[tokio::test]
    async fn handle_round_created_is_idempotent() {
        let (handler, store, _cache) = create_handler();

        let event = dead_pool::RoundCreated {
            roundId: U256::from(1),
            roundType: 0,
            targetLevel: 3,
            line: U256::from(10_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            deadline: 1_700_000_000,
        };

        // First call
        handler
            .handle_round_created(event.clone(), test_metadata())
            .await
            .unwrap();
        assert_eq!(store.round_count(), 1);

        // Second call should not create duplicate
        handler
            .handle_round_created(event, test_metadata())
            .await
            .unwrap();
        assert_eq!(store.round_count(), 1);
    }

    #[tokio::test]
    async fn handle_bet_placed_records_bet() {
        let (handler, store, _cache) = create_handler();

        // First create a round
        let round_event = dead_pool::RoundCreated {
            roundId: U256::from(1),
            roundType: 0,
            targetLevel: 4,
            line: U256::from(10_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            deadline: 1_700_000_000,
        };
        handler
            .handle_round_created(round_event, test_metadata())
            .await
            .unwrap();

        // Then place a bet
        let bet_event = dead_pool::BetPlaced {
            roundId: U256::from(1),
            user: test_address(),
            isOver: true,
            amount: U256::from(100_u64) * U256::from(10_u64).pow(U256::from(18_u64)), // 100 DATA
        };

        let result = handler.handle_bet_placed(bet_event, test_metadata()).await;
        assert!(result.is_ok());

        // Verify bet was recorded
        assert_eq!(store.bet_count(), 1);

        let bets = store.get_bets();
        assert_eq!(bets[0].amount.to_string(), "100");
        assert!(bets[0].is_over);
        assert!(!bets[0].is_claimed);

        // Verify pool was updated
        let round = store.get_round("1").unwrap();
        assert_eq!(round.over_pool.to_string(), "100");
        assert_eq!(round.under_pool.to_string(), "0");
    }

    #[tokio::test]
    async fn handle_bet_placed_updates_under_pool() {
        let (handler, store, _cache) = create_handler();

        // Create round
        let round_event = dead_pool::RoundCreated {
            roundId: U256::from(1),
            roundType: 0,
            targetLevel: 4,
            line: U256::from(10_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            deadline: 1_700_000_000,
        };
        handler
            .handle_round_created(round_event, test_metadata())
            .await
            .unwrap();

        // Place UNDER bet
        let bet_event = dead_pool::BetPlaced {
            roundId: U256::from(1),
            user: test_address(),
            isOver: false, // UNDER
            amount: U256::from(50_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };
        handler
            .handle_bet_placed(bet_event, test_metadata())
            .await
            .unwrap();

        // Verify under_pool was updated
        let round = store.get_round("1").unwrap();
        assert_eq!(round.over_pool.to_string(), "0");
        assert_eq!(round.under_pool.to_string(), "50");
    }

    #[tokio::test]
    async fn handle_bet_placed_ignores_unknown_round() {
        let (handler, store, _cache) = create_handler();

        // Place bet without creating round first
        let bet_event = dead_pool::BetPlaced {
            roundId: U256::from(999),
            user: test_address(),
            isOver: true,
            amount: U256::from(100_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };

        let result = handler.handle_bet_placed(bet_event, test_metadata()).await;
        assert!(result.is_ok()); // Should not error, just log warning

        // No bet should be recorded
        assert_eq!(store.bet_count(), 0);
    }

    #[tokio::test]
    async fn handle_bet_placed_ignores_resolved_round() {
        let (handler, store, _cache) = create_handler();

        // Create round
        let round_event = dead_pool::RoundCreated {
            roundId: U256::from(1),
            roundType: 0,
            targetLevel: 4,
            line: U256::from(10_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            deadline: 1_700_000_000,
        };
        handler
            .handle_round_created(round_event, test_metadata())
            .await
            .unwrap();

        // Resolve the round
        let resolve_event = dead_pool::RoundResolved {
            roundId: U256::from(1),
            outcome: true,
            totalPot: U256::from(0),
            burned: U256::from(0),
        };
        handler
            .handle_round_resolved(resolve_event, test_metadata())
            .await
            .unwrap();

        // Try to place bet on already-resolved round
        let bet_event = dead_pool::BetPlaced {
            roundId: U256::from(1),
            user: test_address(),
            isOver: true,
            amount: U256::from(100_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };

        let result = handler.handle_bet_placed(bet_event, test_metadata()).await;
        assert!(result.is_ok()); // Should not error, just log warning

        // No bet should be recorded (round was already resolved)
        assert_eq!(store.bet_count(), 0);
    }

    #[tokio::test]
    async fn handle_round_resolved_marks_resolved() {
        let (handler, store, _cache) = create_handler();

        // Create round and place bets
        let round_event = dead_pool::RoundCreated {
            roundId: U256::from(1),
            roundType: 0,
            targetLevel: 4,
            line: U256::from(10_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            deadline: 1_700_000_000,
        };
        handler
            .handle_round_created(round_event, test_metadata())
            .await
            .unwrap();

        let bet_over = dead_pool::BetPlaced {
            roundId: U256::from(1),
            user: test_address(),
            isOver: true,
            amount: U256::from(100_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };
        handler
            .handle_bet_placed(bet_over, test_metadata())
            .await
            .unwrap();

        let bet_under = dead_pool::BetPlaced {
            roundId: U256::from(1),
            user: test_address_2(),
            isOver: false,
            amount: U256::from(50_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };
        handler
            .handle_bet_placed(bet_under, test_metadata())
            .await
            .unwrap();

        // Resolve round (OVER wins)
        let resolve_event = dead_pool::RoundResolved {
            roundId: U256::from(1),
            outcome: true, // OVER won
            totalPot: U256::from(150_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            burned: U256::from(7_u64) * U256::from(10_u64).pow(U256::from(18_u64)), // ~5% rake
        };

        let result = handler
            .handle_round_resolved(resolve_event, test_metadata())
            .await;
        assert!(result.is_ok());

        // Verify round was resolved
        let round = store.get_round("1").unwrap();
        assert!(round.is_resolved);
        assert_eq!(round.outcome, Some(true));
        assert_eq!(round.total_burned.as_ref().unwrap().to_string(), "7");
    }

    #[tokio::test]
    async fn handle_round_resolved_is_idempotent() {
        let (handler, _store, _cache) = create_handler();

        // Create and resolve round
        let round_event = dead_pool::RoundCreated {
            roundId: U256::from(1),
            roundType: 0,
            targetLevel: 4,
            line: U256::from(10_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            deadline: 1_700_000_000,
        };
        handler
            .handle_round_created(round_event, test_metadata())
            .await
            .unwrap();

        let resolve_event = dead_pool::RoundResolved {
            roundId: U256::from(1),
            outcome: true,
            totalPot: U256::from(100_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            burned: U256::from(5_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };
        handler
            .handle_round_resolved(resolve_event.clone(), test_metadata())
            .await
            .unwrap();

        // Second resolve should not error
        let result = handler
            .handle_round_resolved(resolve_event, test_metadata())
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn handle_round_resolved_ignores_unknown_round() {
        let (handler, _store, _cache) = create_handler();

        let resolve_event = dead_pool::RoundResolved {
            roundId: U256::from(999),
            outcome: true,
            totalPot: U256::from(100_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            burned: U256::from(5_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };

        let result = handler
            .handle_round_resolved(resolve_event, test_metadata())
            .await;
        assert!(result.is_ok()); // Should not error, just log warning
    }

    #[tokio::test]
    async fn handle_winnings_claimed_marks_claimed() {
        let (handler, store, _cache) = create_handler();

        // Setup: create round, place bet, resolve
        let round_event = dead_pool::RoundCreated {
            roundId: U256::from(1),
            roundType: 0,
            targetLevel: 4,
            line: U256::from(10_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            deadline: 1_700_000_000,
        };
        handler
            .handle_round_created(round_event, test_metadata())
            .await
            .unwrap();

        let bet_event = dead_pool::BetPlaced {
            roundId: U256::from(1),
            user: test_address(),
            isOver: true,
            amount: U256::from(100_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };
        handler
            .handle_bet_placed(bet_event, test_metadata())
            .await
            .unwrap();

        let resolve_event = dead_pool::RoundResolved {
            roundId: U256::from(1),
            outcome: true,
            totalPot: U256::from(100_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            burned: U256::from(5_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };
        handler
            .handle_round_resolved(resolve_event, test_metadata())
            .await
            .unwrap();

        // Claim winnings
        let claim_event = dead_pool::WinningsClaimed {
            roundId: U256::from(1),
            user: test_address(),
            amount: U256::from(190_u64) * U256::from(10_u64).pow(U256::from(18_u64)), // ~2x minus rake
        };

        let result = handler
            .handle_winnings_claimed(claim_event, test_metadata())
            .await;
        assert!(result.is_ok());

        // Verify bet was marked as claimed
        let bets = store.get_bets();
        let bet = bets
            .iter()
            .find(|b| b.user_address == EthAddress::from(test_address()))
            .unwrap();
        assert!(bet.is_claimed);
        assert_eq!(bet.winnings.as_ref().unwrap().to_string(), "190");
        assert!(bet.claimed_at.is_some());
    }

    #[tokio::test]
    async fn handle_winnings_claimed_fails_for_unknown_round() {
        let (handler, _store, _cache) = create_handler();

        // Try to claim winnings for a round that doesn't exist
        let claim_event = dead_pool::WinningsClaimed {
            roundId: U256::from(999),
            user: test_address(),
            amount: U256::from(100_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };

        // This should fail because the round doesn't exist
        let result = handler
            .handle_winnings_claimed(claim_event, test_metadata())
            .await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn handle_winnings_claimed_fails_for_unknown_user() {
        let (handler, _store, _cache) = create_handler();

        // Setup: create round, place bet by user1, resolve
        let round_event = dead_pool::RoundCreated {
            roundId: U256::from(1),
            roundType: 0,
            targetLevel: 4,
            line: U256::from(10_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            deadline: 1_700_000_000,
        };
        handler
            .handle_round_created(round_event, test_metadata())
            .await
            .unwrap();

        let bet_event = dead_pool::BetPlaced {
            roundId: U256::from(1),
            user: test_address(),
            isOver: true,
            amount: U256::from(100_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };
        handler
            .handle_bet_placed(bet_event, test_metadata())
            .await
            .unwrap();

        let resolve_event = dead_pool::RoundResolved {
            roundId: U256::from(1),
            outcome: true,
            totalPot: U256::from(100_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            burned: U256::from(5_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };
        handler
            .handle_round_resolved(resolve_event, test_metadata())
            .await
            .unwrap();

        // Try to claim winnings as a different user who didn't bet
        let claim_event = dead_pool::WinningsClaimed {
            roundId: U256::from(1),
            user: test_address_2(), // Different user
            amount: U256::from(100_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };

        // This should fail because the user didn't place a bet
        let result = handler
            .handle_winnings_claimed(claim_event, test_metadata())
            .await;
        assert!(result.is_err());
    }

    #[test]
    fn to_round_type_valid_values() {
        assert!(MarketHandler::<MockMarketStore, MockCache>::to_round_type(0).is_ok());
        assert!(MarketHandler::<MockMarketStore, MockCache>::to_round_type(1).is_ok());
        assert!(MarketHandler::<MockMarketStore, MockCache>::to_round_type(2).is_ok());
        assert!(MarketHandler::<MockMarketStore, MockCache>::to_round_type(3).is_ok());
    }

    #[test]
    fn to_round_type_invalid_value() {
        assert!(MarketHandler::<MockMarketStore, MockCache>::to_round_type(4).is_err());
        assert!(MarketHandler::<MockMarketStore, MockCache>::to_round_type(255).is_err());
    }

    #[test]
    fn to_optional_level_zero_returns_none() {
        let result = MarketHandler::<MockMarketStore, MockCache>::to_optional_level(0).unwrap();
        assert_eq!(result, None);
    }

    #[test]
    fn to_optional_level_valid_values() {
        assert_eq!(
            MarketHandler::<MockMarketStore, MockCache>::to_optional_level(1).unwrap(),
            Some(Level::Vault)
        );
        assert_eq!(
            MarketHandler::<MockMarketStore, MockCache>::to_optional_level(4).unwrap(),
            Some(Level::Darknet)
        );
    }

    #[test]
    fn to_optional_level_invalid_value() {
        assert!(MarketHandler::<MockMarketStore, MockCache>::to_optional_level(6).is_err());
    }
}
