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
    /// Handle a new position entry (JackedIn event).
    ///
    /// Creates a new position record for the user. If the user already has
    /// an active position, this is logged as a warning but still creates
    /// the new position (the contract should prevent this).
    #[instrument(skip(self, event, meta), fields(user = %event.user, level = event.level))]
    async fn handle_jacked_in(
        &self,
        event: ghost_core::JackedIn,
        meta: EventMetadata,
    ) -> Result<()> {
        let user_address = Self::to_eth_address(&event.user);
        let level = Self::to_level(event.level)?;
        let amount = Self::to_token_amount(&event.amount);

        // Check for existing position (shouldn't happen, but log if it does)
        if let Some(existing) = self.store.get_active_position(&user_address).await? {
            warn!(
                existing_id = %existing.id,
                "User already has active position, creating new one anyway"
            );
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
mod tests {
    // Tests will be added when we have mock implementations of PositionStore
    // For now, this handler is tested via integration tests with real stores

    #[test]
    fn handler_is_send_sync() {
        // Compile-time check
        fn assert_send_sync<T: Send + Sync>() {}

        use crate::ports::MockCache;

        // Create a mock store type for testing
        struct MockPositionStore;

        #[async_trait::async_trait]
        impl crate::ports::PositionStore for MockPositionStore {
            async fn get_active_position(
                &self,
                _: &crate::types::primitives::EthAddress,
            ) -> crate::error::Result<Option<crate::types::entities::Position>> {
                Ok(None)
            }

            async fn save_position(
                &self,
                _: &crate::types::entities::Position,
            ) -> crate::error::Result<()> {
                Ok(())
            }

            async fn get_at_risk_positions(
                &self,
                _: crate::types::enums::Level,
                _: u32,
            ) -> crate::error::Result<Vec<crate::types::entities::Position>> {
                Ok(vec![])
            }

            async fn record_history(
                &self,
                _: &crate::types::entities::PositionHistoryEntry,
            ) -> crate::error::Result<()> {
                Ok(())
            }

            async fn get_position_by_id(
                &self,
                _: &uuid::Uuid,
            ) -> crate::error::Result<Option<crate::types::entities::Position>> {
                Ok(None)
            }

            async fn get_positions_by_level(
                &self,
                _: crate::types::enums::Level,
            ) -> crate::error::Result<Vec<crate::types::entities::Position>> {
                Ok(vec![])
            }

            async fn count_positions_by_level(
                &self,
                _: crate::types::enums::Level,
            ) -> crate::error::Result<u32> {
                Ok(0)
            }
        }

        assert_send_sync::<super::PositionHandler<MockPositionStore, MockCache>>();
    }
}
