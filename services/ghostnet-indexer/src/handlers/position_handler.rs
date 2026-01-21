//! Position event handler implementation.
//!
//! Handles all position lifecycle events from the GhostCore contract:
//! - `JackedIn` - New position created
//! - `StakeAdded` - Additional stake added to existing position
//! - `Extracted` - Position voluntarily exited
//! - `BoostApplied` - Mini-game boost applied
//! - `PositionCulled` - Position removed due to level capacity
//!
//! # Architecture
//!
//! The handler follows hexagonal architecture principles:
//! - Receives decoded events from the `EventRouter`
//! - Uses `PositionStore` port for persistence
//! - Uses `Cache` port for cache invalidation
//! - Uses `EventPublisher` port for streaming events
//!
//! ```text
//! ┌─────────────────────────────────────────────────────────────────┐
//! │                     PositionHandler                              │
//! │                                                                 │
//! │  ┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐ │
//! │  │ EventRouter  │──▶│   Handle     │──▶│   PositionStore      │ │
//! │  │ (events)     │   │   Logic      │   │   (persistence)      │ │
//! │  └──────────────┘   └──────────────┘   └──────────────────────┘ │
//! │                            │                                    │
//! │                            ▼                                    │
//! │                     ┌──────────────┐                            │
//! │                     │   Cache      │                            │
//! │                     │ (invalidate) │                            │
//! │                     └──────────────┘                            │
//! └─────────────────────────────────────────────────────────────────┘
//! ```

use std::sync::Arc;

use async_trait::async_trait;
use tracing::{debug, info, instrument, warn};
use uuid::Uuid;

use crate::abi::ghost_core;
use crate::error::{DomainError, Result};
use crate::handlers::PositionPort;
use crate::ports::{Cache, PositionStore};
use crate::types::entities::{Position, PositionAction, PositionHistoryEntry};
use crate::types::enums::{ExitReason, Level};
use crate::types::events::EventMetadata;
use crate::types::primitives::{BlockNumber, EthAddress, GhostStreak, TokenAmount};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Decimals for the $DATA token (standard ERC20).
const DATA_TOKEN_DECIMALS: u8 = 18;

// ═══════════════════════════════════════════════════════════════════════════════
// POSITION HANDLER
// ═══════════════════════════════════════════════════════════════════════════════

/// Handler for position lifecycle events.
///
/// Processes events from the GhostCore contract and maintains
/// position state in the database.
#[derive(Debug)]
pub struct PositionHandler<S, C> {
    /// Position store for persistence.
    store: Arc<S>,
    /// Cache for invalidation.
    cache: Arc<C>,
}

impl<S, C> PositionHandler<S, C>
where
    S: PositionStore,
    C: Cache,
{
    /// Create a new position handler.
    pub fn new(store: Arc<S>, cache: Arc<C>) -> Self {
        Self { store, cache }
    }

    /// Convert an Alloy address to our EthAddress type.
    fn to_eth_address(addr: &alloy::primitives::Address) -> EthAddress {
        EthAddress::new(addr.0 .0)
    }

    /// Convert an Alloy U256 to our TokenAmount type.
    fn to_token_amount(value: &alloy::primitives::U256) -> TokenAmount {
        TokenAmount::from_wei(*value, DATA_TOKEN_DECIMALS)
    }

    /// Convert a u8 level to our Level enum.
    fn to_level(level: u8) -> Result<Level> {
        Ok(Level::try_from(level)?)
    }

    /// Record a history entry for position changes.
    async fn record_history(
        &self,
        position: &Position,
        action: PositionAction,
        amount_change: TokenAmount,
        meta: &EventMetadata,
    ) -> Result<()> {
        let entry = PositionHistoryEntry {
            id: Uuid::new_v4(),
            position_id: position.id,
            user_address: position.user_address,
            action,
            amount_change,
            new_total: position.amount.clone(),
            block_number: BlockNumber::new(meta.block_number),
            timestamp: meta.timestamp,
        };

        self.store.record_history(&entry).await
    }
}

#[async_trait]
impl<S, C> PositionPort for PositionHandler<S, C>
where
    S: PositionStore + Send + Sync,
    C: Cache + Send + Sync,
{
    /// Handle a new position entry (`JackedIn` event).
    ///
    /// Creates a new position record for the user. If the user already has
    /// an active position, it is closed with `ExitReason::Superseded` to
    /// maintain data consistency (the contract should prevent this, but we
    /// handle it gracefully).
    #[instrument(skip(self, event, meta), fields(user = %event.user, level = event.level))]
    async fn handle_jacked_in(
        &self,
        event: ghost_core::JackedIn,
        meta: EventMetadata,
    ) -> Result<()> {
        let user_address = Self::to_eth_address(&event.user);
        let level = Self::to_level(event.level)?;
        let amount = Self::to_token_amount(&event.amount);

        // Check for existing position and close it if found
        // This shouldn't happen in normal operation, but we handle it gracefully
        if let Some(mut existing) = self.store.get_active_position(&user_address).await? {
            warn!(
                existing_id = %existing.id,
                existing_level = ?existing.level,
                existing_amount = %existing.amount,
                "Closing existing position due to new JackedIn event"
            );

            // Close the existing position
            existing.is_alive = false;
            existing.exit_reason = Some(ExitReason::Superseded);
            existing.exit_timestamp = Some(meta.timestamp);
            existing.updated_at = meta.timestamp;

            self.store.save_position(&existing).await?;

            // Record history for the closed position
            self.record_history(
                &existing,
                PositionAction::Superseded,
                TokenAmount::zero(), // No amount change, just closure
                &meta,
            )
            .await?;
        }

        // Create new position
        let position = Position {
            id: Uuid::new_v4(),
            user_address,
            level,
            amount: amount.clone(),
            reward_debt: TokenAmount::zero(),
            entry_timestamp: meta.timestamp,
            last_add_timestamp: None,
            ghost_streak: GhostStreak::ZERO,
            is_alive: true,
            is_extracted: false,
            exit_reason: None,
            exit_timestamp: None,
            extracted_amount: None,
            extracted_rewards: None,
            created_at_block: BlockNumber::new(meta.block_number),
            updated_at: meta.timestamp,
        };

        // Save to database
        self.store.save_position(&position).await?;

        // Record history
        self.record_history(&position, PositionAction::JackedIn, amount.clone(), &meta)
            .await?;

        // Invalidate cache (sync operation - no await)
        self.cache.invalidate_position(&position.user_address);

        info!(
            position_id = %position.id,
            amount = %amount,
            "Position created"
        );

        Ok(())
    }

    /// Handle stake addition to existing position (StakeAdded event).
    ///
    /// Updates the position's amount and records the addition time.
    #[instrument(skip(self, event, meta), fields(user = %event.user))]
    async fn handle_stake_added(
        &self,
        event: ghost_core::StakeAdded,
        meta: EventMetadata,
    ) -> Result<()> {
        let user_address = Self::to_eth_address(&event.user);
        let added_amount = Self::to_token_amount(&event.amount);
        let new_total = Self::to_token_amount(&event.newTotal);

        // Get existing position
        let mut position = self
            .store
            .get_active_position(&user_address)
            .await?
            .ok_or_else(|| DomainError::PositionNotFound(user_address.to_string()))?;

        // Update position
        position.amount = new_total;
        position.last_add_timestamp = Some(meta.timestamp);
        position.updated_at = meta.timestamp;

        // Save to database
        self.store.save_position(&position).await?;

        // Record history
        self.record_history(&position, PositionAction::StakeAdded, added_amount.clone(), &meta)
            .await?;

        // Invalidate cache (sync operation - no await)
        self.cache.invalidate_position(&user_address);

        info!(
            position_id = %position.id,
            added = %added_amount,
            new_total = %position.amount,
            "Stake added to position"
        );

        Ok(())
    }

    /// Handle position extraction (Extracted event).
    ///
    /// Marks the position as extracted and records the extracted amounts.
    #[instrument(skip(self, event, meta), fields(user = %event.user))]
    async fn handle_extracted(
        &self,
        event: ghost_core::Extracted,
        meta: EventMetadata,
    ) -> Result<()> {
        let user_address = Self::to_eth_address(&event.user);
        // Note: In the contract, `amount` is the principal returned
        let principal = Self::to_token_amount(&event.amount);
        let rewards = Self::to_token_amount(&event.rewards);

        // Get existing position
        let mut position = self
            .store
            .get_active_position(&user_address)
            .await?
            .ok_or_else(|| DomainError::PositionNotFound(user_address.to_string()))?;

        // Calculate total extracted for history
        let total_extracted = principal.saturating_add(&rewards);

        // Update position
        position.is_alive = false;
        position.is_extracted = true;
        position.exit_reason = Some(ExitReason::Extracted);
        position.exit_timestamp = Some(meta.timestamp);
        position.extracted_amount = Some(principal.clone());
        position.extracted_rewards = Some(rewards.clone());
        position.updated_at = meta.timestamp;

        // Save to database
        self.store.save_position(&position).await?;

        // Record history (negative amount since funds are leaving)
        self.record_history(&position, PositionAction::Extracted, total_extracted, &meta)
            .await?;

        // Invalidate cache (sync operation - no await)
        self.cache.invalidate_position(&user_address);

        info!(
            position_id = %position.id,
            principal = %principal,
            rewards = %rewards,
            "Position extracted"
        );

        Ok(())
    }

    /// Handle boost application (BoostApplied event).
    ///
    /// Records that a boost was applied from a mini-game.
    /// Note: Boost effects are typically tracked separately, this just logs the event.
    #[instrument(skip(self, event, meta), fields(user = %event.user, boost_type = event.boostType))]
    async fn handle_boost_applied(
        &self,
        event: ghost_core::BoostApplied,
        meta: EventMetadata,
    ) -> Result<()> {
        let user_address = Self::to_eth_address(&event.user);
        let value_bps = event.valueBps;
        let expiry = event.expiry;

        // Get existing position (boost requires active position)
        let position = self
            .store
            .get_active_position(&user_address)
            .await?
            .ok_or_else(|| DomainError::PositionNotFound(user_address.to_string()))?;

        // For now, just log the boost application
        // In Phase 5, we'll add a separate BoostStore for tracking active boosts
        debug!(
            position_id = %position.id,
            boost_type = event.boostType,
            value_bps,
            expiry,
            block = meta.block_number,
            "Boost applied to position"
        );

        // Invalidate cache (boost affects position calculations) - sync operation
        self.cache.invalidate_position(&user_address);

        Ok(())
    }

    /// Handle position culling (PositionCulled event).
    ///
    /// Marks the position as dead due to level capacity overflow.
    /// The victim loses a penalty, gets some amount returned, and makes room for new entrant.
    #[instrument(skip(self, event, meta), fields(victim = %event.victim, new_entrant = %event.newEntrant))]
    async fn handle_position_culled(
        &self,
        event: ghost_core::PositionCulled,
        meta: EventMetadata,
    ) -> Result<()> {
        let victim_address = Self::to_eth_address(&event.victim);
        let penalty_amount = Self::to_token_amount(&event.penaltyAmount);
        // TODO: Track returned_amount in Position.extracted_amount when we add partial return support
        let _returned_amount = Self::to_token_amount(&event.returnedAmount);

        // Get existing position
        let mut position = self
            .store
            .get_active_position(&victim_address)
            .await?
            .ok_or_else(|| DomainError::PositionNotFound(victim_address.to_string()))?;

        // Update position
        position.is_alive = false;
        position.exit_reason = Some(ExitReason::Culled);
        position.exit_timestamp = Some(meta.timestamp);
        position.updated_at = meta.timestamp;

        // Save to database
        self.store.save_position(&position).await?;

        // Record history (the penalty amount is what was lost)
        self.record_history(&position, PositionAction::Culled, penalty_amount.clone(), &meta)
            .await?;

        // Invalidate cache (sync operation - no await)
        self.cache.invalidate_position(&victim_address);

        info!(
            position_id = %position.id,
            penalty = %penalty_amount,
            new_entrant = %event.newEntrant,
            "Position culled"
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
    use std::sync::{Arc, RwLock};

    use alloy::primitives::{Address, U256};
    use chrono::Utc;

    use super::*;
    use crate::abi::ghost_core;
    use crate::ports::MockCache;
    use crate::types::entities::PositionHistoryEntry;
    use crate::types::enums::Level;
    use crate::types::primitives::EthAddress;

    // ═══════════════════════════════════════════════════════════════════════════
    // MOCK POSITION STORE
    // ═══════════════════════════════════════════════════════════════════════════

    /// Stateful mock store for testing.
    #[derive(Debug, Default)]
    struct MockPositionStore {
        positions: RwLock<HashMap<EthAddress, Position>>,
        history: RwLock<Vec<PositionHistoryEntry>>,
    }

    impl MockPositionStore {
        fn new() -> Self {
            Self::default()
        }

        /// Get the number of saved positions.
        fn position_count(&self) -> usize {
            self.positions.read().unwrap().len()
        }

        /// Get the number of history entries.
        fn history_count(&self) -> usize {
            self.history.read().unwrap().len()
        }

        /// Get a position by address (for test assertions).
        fn get_position(&self, address: &EthAddress) -> Option<Position> {
            self.positions.read().unwrap().get(address).cloned()
        }
    }

    #[async_trait]
    impl PositionStore for MockPositionStore {
        async fn get_active_position(
            &self,
            address: &EthAddress,
        ) -> Result<Option<Position>> {
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

        async fn get_at_risk_positions(
            &self,
            _level: Level,
            _limit: u32,
        ) -> Result<Vec<Position>> {
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

        async fn get_positions_by_level(&self, _level: Level) -> Result<Vec<Position>> {
            Ok(vec![])
        }

        async fn count_positions_by_level(&self, _level: Level) -> Result<u32> {
            Ok(0)
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
        PositionHandler<MockPositionStore, MockCache>,
        Arc<MockPositionStore>,
        Arc<MockCache>,
    ) {
        let store = Arc::new(MockPositionStore::new());
        let cache = Arc::new(MockCache::new());
        let handler = PositionHandler::new(Arc::clone(&store), Arc::clone(&cache));
        (handler, store, cache)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    #[test]
    fn handler_is_send_sync() {
        fn assert_send_sync<T: Send + Sync>() {}
        assert_send_sync::<PositionHandler<MockPositionStore, MockCache>>();
    }

    #[tokio::test]
    async fn handle_jacked_in_creates_position() {
        let (handler, store, _cache) = create_handler();

        let event = ghost_core::JackedIn {
            user: test_address(),
            amount: U256::from(1000_u64) * U256::from(10_u64).pow(U256::from(18_u64)), // 1000 tokens
            level: 3, // Subnet
            newTotal: U256::from(1000_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };

        let result = handler.handle_jacked_in(event, test_metadata()).await;
        assert!(result.is_ok());

        // Verify position was created
        assert_eq!(store.position_count(), 1);
        assert_eq!(store.history_count(), 1);

        let user_address = EthAddress::new(test_address().0 .0);
        let position = store.get_position(&user_address).unwrap();
        assert!(position.is_alive);
        assert!(!position.is_extracted);
        assert_eq!(position.level, Level::Subnet);
    }

    #[tokio::test]
    async fn handle_jacked_in_closes_existing_position() {
        let (handler, store, _cache) = create_handler();
        let user_address = EthAddress::new(test_address().0 .0);

        // Create initial position via JackedIn
        let event1 = ghost_core::JackedIn {
            user: test_address(),
            amount: U256::from(500_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            level: 2, // Mainframe
            newTotal: U256::from(500_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };
        handler.handle_jacked_in(event1, test_metadata()).await.unwrap();

        let first_position = store.get_position(&user_address).unwrap();
        let first_id = first_position.id;
        assert!(first_position.is_alive);

        // Second JackedIn should close the first and create new
        let event2 = ghost_core::JackedIn {
            user: test_address(),
            amount: U256::from(1000_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            level: 4, // Darknet
            newTotal: U256::from(1000_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };
        handler.handle_jacked_in(event2, test_metadata()).await.unwrap();

        // There should still be 1 position (the latest one overwrites)
        // But the old one was closed first
        let final_position = store.get_position(&user_address).unwrap();
        assert!(final_position.is_alive);
        assert_eq!(final_position.level, Level::Darknet);
        assert_ne!(final_position.id, first_id);

        // History should have entries for both operations
        assert!(store.history_count() >= 2);
    }

    #[tokio::test]
    async fn handle_stake_added_updates_amount() {
        let (handler, store, _cache) = create_handler();
        let user_address = EthAddress::new(test_address().0 .0);

        // First create a position
        let jacked_in = ghost_core::JackedIn {
            user: test_address(),
            amount: U256::from(1000_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            level: 3,
            newTotal: U256::from(1000_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };
        handler.handle_jacked_in(jacked_in, test_metadata()).await.unwrap();

        // Now add stake
        let stake_added = ghost_core::StakeAdded {
            user: test_address(),
            amount: U256::from(500_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            newTotal: U256::from(1500_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };
        let result = handler.handle_stake_added(stake_added, test_metadata()).await;
        assert!(result.is_ok());

        // Verify amount was updated
        let position = store.get_position(&user_address).unwrap();
        assert!(position.last_add_timestamp.is_some());
        // The amount should reflect newTotal (1500 tokens)
        assert_eq!(position.amount.to_string(), "1500");
    }

    #[tokio::test]
    async fn handle_stake_added_fails_for_unknown_user() {
        let (handler, _store, _cache) = create_handler();

        // Try to add stake without existing position
        let stake_added = ghost_core::StakeAdded {
            user: test_address(),
            amount: U256::from(500_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            newTotal: U256::from(500_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };
        let result = handler.handle_stake_added(stake_added, test_metadata()).await;

        assert!(result.is_err());
        // Should be PositionNotFound error
        let err = result.unwrap_err();
        assert!(err.to_string().contains("position not found"));
    }

    #[tokio::test]
    async fn handle_extracted_marks_position_closed() {
        let (handler, store, _cache) = create_handler();
        let user_address = EthAddress::new(test_address().0 .0);

        // First create a position
        let jacked_in = ghost_core::JackedIn {
            user: test_address(),
            amount: U256::from(1000_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            level: 3,
            newTotal: U256::from(1000_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };
        handler.handle_jacked_in(jacked_in, test_metadata()).await.unwrap();

        // Extract
        let extracted = ghost_core::Extracted {
            user: test_address(),
            amount: U256::from(900_u64) * U256::from(10_u64).pow(U256::from(18_u64)), // principal
            rewards: U256::from(100_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };
        let result = handler.handle_extracted(extracted, test_metadata()).await;
        assert!(result.is_ok());

        // Verify position is closed
        let position = store.get_position(&user_address).unwrap();
        assert!(!position.is_alive);
        assert!(position.is_extracted);
        assert_eq!(position.exit_reason, Some(ExitReason::Extracted));
        assert!(position.extracted_amount.is_some());
        assert!(position.extracted_rewards.is_some());
    }

    #[tokio::test]
    async fn handle_position_culled_marks_dead() {
        let (handler, store, _cache) = create_handler();
        let user_address = EthAddress::new(test_address().0 .0);

        // First create a position
        let jacked_in = ghost_core::JackedIn {
            user: test_address(),
            amount: U256::from(1000_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            level: 5, // BlackIce
            newTotal: U256::from(1000_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
        };
        handler.handle_jacked_in(jacked_in, test_metadata()).await.unwrap();

        // Cull the position
        let culled = ghost_core::PositionCulled {
            victim: test_address(),
            penaltyAmount: U256::from(100_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            returnedAmount: U256::from(900_u64) * U256::from(10_u64).pow(U256::from(18_u64)),
            newEntrant: "0xabcdef0123456789abcdef0123456789abcdef01"
                .parse()
                .unwrap(),
        };
        let result = handler.handle_position_culled(culled, test_metadata()).await;
        assert!(result.is_ok());

        // Verify position is dead
        let position = store.get_position(&user_address).unwrap();
        assert!(!position.is_alive);
        assert_eq!(position.exit_reason, Some(ExitReason::Culled));
    }

    #[test]
    fn to_level_valid_values() {
        assert!(PositionHandler::<MockPositionStore, MockCache>::to_level(0).is_ok());
        assert!(PositionHandler::<MockPositionStore, MockCache>::to_level(1).is_ok());
        assert!(PositionHandler::<MockPositionStore, MockCache>::to_level(5).is_ok());
    }

    #[test]
    fn to_level_invalid_value() {
        assert!(PositionHandler::<MockPositionStore, MockCache>::to_level(6).is_err());
        assert!(PositionHandler::<MockPositionStore, MockCache>::to_level(255).is_err());
    }
}
