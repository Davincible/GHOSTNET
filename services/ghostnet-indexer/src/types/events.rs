//! Strongly-typed event structures from GHOSTNET smart contracts.
//!
//! Each struct corresponds to a Solidity event emitted by the contracts.
//! Events are decoded from blockchain logs and enriched with metadata.

use alloy::primitives::{Address, B256, U256};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use super::enums::{BoostType, Level, RoundType};

// ═══════════════════════════════════════════════════════════════════════════════
// EVENT METADATA
// ═══════════════════════════════════════════════════════════════════════════════

/// Metadata attached to every indexed event.
///
/// This provides context about where and when the event occurred on-chain.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EventMetadata {
    /// Block number where the event was emitted.
    pub block_number: u64,
    /// Hash of the block containing this event.
    pub block_hash: B256,
    /// Transaction hash that emitted this event.
    pub tx_hash: B256,
    /// Index of the transaction within the block.
    pub tx_index: u64,
    /// Index of the log within the transaction.
    pub log_index: u64,
    /// Timestamp when the block was mined.
    pub timestamp: DateTime<Utc>,
    /// Contract address that emitted this event.
    pub contract: Address,
}

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED EVENT ENUM
// ═══════════════════════════════════════════════════════════════════════════════

/// Unified enum for all GHOSTNET events.
///
/// This enum allows type-safe handling of any event from any GHOSTNET contract.
/// Use pattern matching to handle specific event types.
///
/// # Serialization
///
/// Events are serialized with a type tag for deserialization:
/// ```json
/// {"JackedIn": {"meta": {...}, "user": "0x...", "amount": "1000", ...}}
/// ```
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
#[non_exhaustive] // CRITICAL: New event types will be added as contracts evolve
pub enum GhostnetEvent {
    // ═══════════════════════════════════════════════════════════════════════════
    // GHOST CORE
    // ═══════════════════════════════════════════════════════════════════════════
    /// User entered a position
    JackedIn(JackedInEvent),
    /// User added to existing position
    StakeAdded(StakeAddedEvent),
    /// User extracted their position
    Extracted(ExtractedEvent),
    /// Deaths were processed after a scan
    DeathsProcessed(DeathsProcessedEvent),
    /// Survivor streaks were updated
    SurvivorsUpdated(SurvivorsUpdatedEvent),
    /// Cascade rewards were distributed
    CascadeDistributed(CascadeDistributedEvent),
    /// Emissions were added to a level
    EmissionsAdded(EmissionsAddedEvent),
    /// A boost was applied to a user
    BoostApplied(BoostAppliedEvent),
    /// System reset was triggered
    SystemResetTriggered(SystemResetTriggeredEvent),
    /// A position was culled
    PositionCulled(PositionCulledEvent),

    // ═══════════════════════════════════════════════════════════════════════════
    // TRACE SCAN
    // ═══════════════════════════════════════════════════════════════════════════
    /// A scan was executed (Phase 1)
    ScanExecuted(ScanExecutedEvent),
    /// Deaths were submitted for a scan
    DeathsSubmitted(DeathsSubmittedEvent),
    /// A scan was finalized (Phase 2)
    ScanFinalized(ScanFinalizedEvent),

    // ═══════════════════════════════════════════════════════════════════════════
    // DEAD POOL
    // ═══════════════════════════════════════════════════════════════════════════
    /// A new betting round was created
    RoundCreated(RoundCreatedEvent),
    /// A bet was placed
    BetPlaced(BetPlacedEvent),
    /// A round was resolved
    RoundResolved(RoundResolvedEvent),
    /// Winnings were claimed
    WinningsClaimed(WinningsClaimedEvent),

    // ═══════════════════════════════════════════════════════════════════════════
    // DATA TOKEN
    // ═══════════════════════════════════════════════════════════════════════════
    /// ERC20 transfer
    Transfer(TransferEvent),
    /// Tax was burned
    TaxBurned(TaxBurnedEvent),
    /// Tax was collected to treasury
    TaxCollected(TaxCollectedEvent),
    /// Tax exclusion status changed
    TaxExclusionSet(TaxExclusionSetEvent),

    // ═══════════════════════════════════════════════════════════════════════════
    // FEE ROUTER
    // ═══════════════════════════════════════════════════════════════════════════
    /// Toll was collected
    TollCollected(TollCollectedEvent),
    /// Buyback was executed
    BuybackExecuted(BuybackExecutedEvent),
    /// Operations funds were withdrawn
    OperationsWithdrawn(OperationsWithdrawnEvent),

    // ═══════════════════════════════════════════════════════════════════════════
    // REWARDS DISTRIBUTOR
    // ═══════════════════════════════════════════════════════════════════════════
    /// Emissions were distributed
    EmissionsDistributed(EmissionsDistributedEvent),
    /// Level weights were updated
    WeightsUpdated(WeightsUpdatedEvent),

    // ═══════════════════════════════════════════════════════════════════════════
    // TEAM VESTING
    // ═══════════════════════════════════════════════════════════════════════════
    /// Team tokens were claimed
    TokensClaimed(TokensClaimedEvent),
}

impl GhostnetEvent {
    /// Get the metadata for this event.
    #[must_use]
    pub const fn metadata(&self) -> &EventMetadata {
        match self {
            // GhostCore
            Self::JackedIn(e) => &e.meta,
            Self::StakeAdded(e) => &e.meta,
            Self::Extracted(e) => &e.meta,
            Self::DeathsProcessed(e) => &e.meta,
            Self::SurvivorsUpdated(e) => &e.meta,
            Self::CascadeDistributed(e) => &e.meta,
            Self::EmissionsAdded(e) => &e.meta,
            Self::BoostApplied(e) => &e.meta,
            Self::SystemResetTriggered(e) => &e.meta,
            Self::PositionCulled(e) => &e.meta,
            // TraceScan
            Self::ScanExecuted(e) => &e.meta,
            Self::DeathsSubmitted(e) => &e.meta,
            Self::ScanFinalized(e) => &e.meta,
            // DeadPool
            Self::RoundCreated(e) => &e.meta,
            Self::BetPlaced(e) => &e.meta,
            Self::RoundResolved(e) => &e.meta,
            Self::WinningsClaimed(e) => &e.meta,
            // DataToken
            Self::Transfer(e) => &e.meta,
            Self::TaxBurned(e) => &e.meta,
            Self::TaxCollected(e) => &e.meta,
            Self::TaxExclusionSet(e) => &e.meta,
            // FeeRouter
            Self::TollCollected(e) => &e.meta,
            Self::BuybackExecuted(e) => &e.meta,
            Self::OperationsWithdrawn(e) => &e.meta,
            // RewardsDistributor
            Self::EmissionsDistributed(e) => &e.meta,
            Self::WeightsUpdated(e) => &e.meta,
            // TeamVesting
            Self::TokensClaimed(e) => &e.meta,
        }
    }

    /// Get the event type name (for logging/metrics).
    #[must_use]
    pub const fn type_name(&self) -> &'static str {
        match self {
            Self::JackedIn(_) => "JackedIn",
            Self::StakeAdded(_) => "StakeAdded",
            Self::Extracted(_) => "Extracted",
            Self::DeathsProcessed(_) => "DeathsProcessed",
            Self::SurvivorsUpdated(_) => "SurvivorsUpdated",
            Self::CascadeDistributed(_) => "CascadeDistributed",
            Self::EmissionsAdded(_) => "EmissionsAdded",
            Self::BoostApplied(_) => "BoostApplied",
            Self::SystemResetTriggered(_) => "SystemResetTriggered",
            Self::PositionCulled(_) => "PositionCulled",
            Self::ScanExecuted(_) => "ScanExecuted",
            Self::DeathsSubmitted(_) => "DeathsSubmitted",
            Self::ScanFinalized(_) => "ScanFinalized",
            Self::RoundCreated(_) => "RoundCreated",
            Self::BetPlaced(_) => "BetPlaced",
            Self::RoundResolved(_) => "RoundResolved",
            Self::WinningsClaimed(_) => "WinningsClaimed",
            Self::Transfer(_) => "Transfer",
            Self::TaxBurned(_) => "TaxBurned",
            Self::TaxCollected(_) => "TaxCollected",
            Self::TaxExclusionSet(_) => "TaxExclusionSet",
            Self::TollCollected(_) => "TollCollected",
            Self::BuybackExecuted(_) => "BuybackExecuted",
            Self::OperationsWithdrawn(_) => "OperationsWithdrawn",
            Self::EmissionsDistributed(_) => "EmissionsDistributed",
            Self::WeightsUpdated(_) => "WeightsUpdated",
            Self::TokensClaimed(_) => "TokensClaimed",
        }
    }

    /// Get the source contract name.
    #[must_use]
    pub const fn contract_name(&self) -> &'static str {
        match self {
            Self::JackedIn(_)
            | Self::StakeAdded(_)
            | Self::Extracted(_)
            | Self::DeathsProcessed(_)
            | Self::SurvivorsUpdated(_)
            | Self::CascadeDistributed(_)
            | Self::EmissionsAdded(_)
            | Self::BoostApplied(_)
            | Self::SystemResetTriggered(_)
            | Self::PositionCulled(_) => "GhostCore",

            Self::ScanExecuted(_) | Self::DeathsSubmitted(_) | Self::ScanFinalized(_) => {
                "TraceScan"
            }

            Self::RoundCreated(_)
            | Self::BetPlaced(_)
            | Self::RoundResolved(_)
            | Self::WinningsClaimed(_) => "DeadPool",

            Self::Transfer(_)
            | Self::TaxBurned(_)
            | Self::TaxCollected(_)
            | Self::TaxExclusionSet(_) => "DataToken",

            Self::TollCollected(_) | Self::BuybackExecuted(_) | Self::OperationsWithdrawn(_) => {
                "FeeRouter"
            }

            Self::EmissionsDistributed(_) | Self::WeightsUpdated(_) => "RewardsDistributor",

            Self::TokensClaimed(_) => "TeamVesting",
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GHOST CORE EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

/// User entered a new position.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct JackedInEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// User's wallet address.
    pub user: Address,
    /// Amount of DATA staked.
    pub amount: U256,
    /// Risk level chosen.
    pub level: Level,
    /// Total staked after this action.
    pub new_total: U256,
}

/// User added to an existing position.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StakeAddedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// User's wallet address.
    pub user: Address,
    /// Amount added.
    pub amount: U256,
    /// New total stake.
    pub new_total: U256,
}

/// User extracted their position.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExtractedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// User's wallet address.
    pub user: Address,
    /// Principal returned.
    pub amount: U256,
    /// Rewards earned.
    pub rewards: U256,
}

/// Deaths were processed after a scan.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DeathsProcessedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Which level was scanned.
    pub level: Level,
    /// Number of deaths in this batch.
    pub count: U256,
    /// Total DATA from dead positions.
    pub total_dead: U256,
    /// Amount burned (30%).
    pub burned: U256,
    /// Amount distributed to survivors.
    pub distributed: U256,
}

/// Survivor streaks were updated after a scan.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SurvivorsUpdatedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Which level.
    pub level: Level,
    /// Number of survivors.
    pub count: U256,
}

/// Cascade rewards were distributed from deaths.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CascadeDistributedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Level where deaths occurred.
    pub source_level: Level,
    /// Distributed to same-level survivors (30%).
    pub same_level_amount: U256,
    /// Distributed to safer levels (30%).
    pub upstream_amount: U256,
    /// Burned (30%).
    pub burn_amount: U256,
    /// To treasury (10%).
    pub protocol_amount: U256,
}

/// Emissions were added to a level.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EmissionsAddedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Target level.
    pub level: Level,
    /// Amount of emissions.
    pub amount: U256,
}

/// A boost was applied to a user.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BoostAppliedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// User receiving boost.
    pub user: Address,
    /// Type of boost.
    pub boost_type: BoostType,
    /// Boost value in basis points.
    pub value_bps: u16,
    /// Unix timestamp when boost expires.
    pub expiry: u64,
}

/// System reset was triggered.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SystemResetTriggeredEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Total penalty extracted from all positions.
    pub total_penalty: U256,
    /// Last depositor wins jackpot.
    pub jackpot_winner: Address,
    /// Jackpot payout.
    pub jackpot_amount: U256,
}

/// A position was culled due to level capacity.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PositionCulledEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// User who was culled.
    pub victim: Address,
    /// Penalty taken.
    pub penalty_amount: U256,
    /// Amount returned to victim.
    pub returned_amount: U256,
    /// User who triggered culling.
    pub new_entrant: Address,
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRACE SCAN EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

/// A scan was executed (Phase 1).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ScanExecutedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Which level is being scanned.
    pub level: Level,
    /// Unique scan identifier.
    pub scan_id: U256,
    /// Deterministic seed from prevrandao.
    pub seed: U256,
    /// Unix timestamp.
    pub executed_at: u64,
}

/// Deaths were submitted for a scan.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DeathsSubmittedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Which level.
    pub level: Level,
    /// Which scan.
    pub scan_id: U256,
    /// Deaths in this batch.
    pub count: U256,
    /// Total DATA from deaths.
    pub total_dead: U256,
    /// Who submitted (for keeper rewards).
    pub submitter: Address,
}

/// A scan was finalized (Phase 2).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ScanFinalizedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Which level.
    pub level: Level,
    /// Which scan.
    pub scan_id: U256,
    /// Total deaths processed.
    pub death_count: U256,
    /// Total DATA lost.
    pub total_dead: U256,
    /// Unix timestamp.
    pub finalized_at: u64,
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEAD POOL EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

/// A new betting round was created.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RoundCreatedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Unique round identifier.
    pub round_id: U256,
    /// Type of round.
    pub round_type: RoundType,
    /// Target level (if applicable).
    pub target_level: Level,
    /// Over/under line.
    pub line: U256,
    /// Betting closes at.
    pub deadline: u64,
}

/// A bet was placed.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BetPlacedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Which round.
    pub round_id: U256,
    /// Bettor's address.
    pub user: Address,
    /// true = OVER, false = UNDER.
    pub is_over: bool,
    /// Amount wagered.
    pub amount: U256,
}

/// A round was resolved.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RoundResolvedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Which round.
    pub round_id: U256,
    /// true = OVER won, false = UNDER won.
    pub outcome: bool,
    /// Total pot size.
    pub total_pot: U256,
    /// Rake burned (5%).
    pub burned: U256,
}

/// Winnings were claimed.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WinningsClaimedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Which round.
    pub round_id: U256,
    /// Winner's address.
    pub user: Address,
    /// Payout amount.
    pub amount: U256,
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA TOKEN EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Standard ERC20 transfer.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TransferEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Sender (0x0 for mints).
    pub from: Address,
    /// Recipient (`DEAD_ADDRESS` for burns).
    pub to: Address,
    /// Amount transferred.
    pub value: U256,
}

/// Tokens were burned via tax.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TaxBurnedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Transfer sender.
    pub from: Address,
    /// Amount burned (9% of 10% tax).
    pub amount: U256,
}

/// Tokens were sent to treasury via tax.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TaxCollectedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Transfer sender.
    pub from: Address,
    /// Amount to treasury (1% of 10% tax).
    pub amount: U256,
}

/// Tax exclusion status changed.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TaxExclusionSetEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Affected address.
    pub account: Address,
    /// New exclusion status.
    pub excluded: bool,
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEE ROUTER EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Toll was collected (per-action fee).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TollCollectedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Who paid the toll.
    pub from: Address,
    /// ETH amount.
    pub amount: U256,
    /// Action identifier (e.g., "jackIn").
    pub reason: B256,
}

/// Buyback was executed.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BuybackExecutedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// ETH used for buyback.
    pub eth_spent: U256,
    /// DATA tokens bought.
    pub data_received: U256,
    /// DATA tokens burned.
    pub data_burned: U256,
}

/// Operations funds were withdrawn.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OperationsWithdrawnEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Recipient.
    pub to: Address,
    /// ETH amount.
    pub amount: U256,
}

// ═══════════════════════════════════════════════════════════════════════════════
// REWARDS DISTRIBUTOR EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Emissions were distributed across levels.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EmissionsDistributedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Total DATA distributed.
    pub total_amount: U256,
    /// Unix timestamp.
    pub timestamp: u64,
}

/// Level weights were updated.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WeightsUpdatedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// New weights for levels 1-5.
    pub new_weights: [u16; 5],
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEAM VESTING EVENTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Team member claimed vested tokens.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TokensClaimedEvent {
    /// Event metadata.
    pub meta: EventMetadata,
    /// Team member's address.
    pub beneficiary: Address,
    /// Amount claimed.
    pub amount: U256,
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_metadata() -> EventMetadata {
        EventMetadata {
            block_number: 12345,
            block_hash: B256::ZERO,
            tx_hash: B256::ZERO,
            tx_index: 0,
            log_index: 0,
            timestamp: Utc::now(),
            contract: Address::ZERO,
        }
    }

    #[test]
    fn ghostnet_event_type_name() {
        let event = GhostnetEvent::JackedIn(JackedInEvent {
            meta: sample_metadata(),
            user: Address::ZERO,
            amount: U256::ZERO,
            level: Level::Vault,
            new_total: U256::ZERO,
        });

        assert_eq!(event.type_name(), "JackedIn");
        assert_eq!(event.contract_name(), "GhostCore");
    }

    #[test]
    fn ghostnet_event_metadata_access() {
        let meta = sample_metadata();
        let event = GhostnetEvent::Transfer(TransferEvent {
            meta: meta.clone(),
            from: Address::ZERO,
            to: Address::ZERO,
            value: U256::ZERO,
        });

        assert_eq!(event.metadata().block_number, meta.block_number);
    }
}
