//! Domain entities for database persistence.
//!
//! These structs represent the application's core domain objects that are
//! persisted to the database. They differ from events in that they represent
//! current state rather than historical occurrences.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::enums::{BoostType, ExitReason, Level, RoundType};
use super::primitives::{BlockNumber, EthAddress, GhostStreak, TokenAmount};

// ═══════════════════════════════════════════════════════════════════════════════
// POSITION
// ═══════════════════════════════════════════════════════════════════════════════

/// Active or historical staking position.
///
/// Positions track a user's stake in a specific risk level. A user can have
/// at most one active position at a time.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Position {
    /// Unique identifier.
    pub id: Uuid,
    /// User's wallet address.
    pub user_address: EthAddress,
    /// Risk level.
    pub level: Level,
    /// Current staked amount.
    pub amount: TokenAmount,
    /// Accumulated reward debt (for reward calculations).
    pub reward_debt: TokenAmount,
    /// When the position was created.
    pub entry_timestamp: DateTime<Utc>,
    /// When stake was last added (if any).
    pub last_add_timestamp: Option<DateTime<Utc>>,
    /// Consecutive scan survivals.
    pub ghost_streak: GhostStreak,
    /// Whether the position is still active.
    pub is_alive: bool,
    /// Whether the position was voluntarily extracted.
    pub is_extracted: bool,
    /// How the position ended (if closed).
    pub exit_reason: Option<ExitReason>,
    /// When the position was closed.
    pub exit_timestamp: Option<DateTime<Utc>>,
    /// Amount returned on extraction.
    pub extracted_amount: Option<TokenAmount>,
    /// Rewards received on extraction.
    pub extracted_rewards: Option<TokenAmount>,
    /// Block number when created.
    pub created_at_block: BlockNumber,
    /// Last update timestamp.
    pub updated_at: DateTime<Utc>,
}

impl Position {
    /// Check if this position is currently active (alive and not extracted).
    #[must_use]
    pub const fn is_active(&self) -> bool {
        self.is_alive && !self.is_extracted
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCAN
// ═══════════════════════════════════════════════════════════════════════════════

/// Scan execution record.
///
/// Scans are periodic events where positions in a level are checked for death.
/// The scan process has two phases: execution (selecting who dies) and
/// finalization (processing deaths).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Scan {
    /// Unique identifier (database).
    pub id: Uuid,
    /// On-chain scan ID (U256 as string for precision).
    pub scan_id: String,
    /// Which level was scanned.
    pub level: Level,
    /// Random seed used for death selection (U256 as string).
    pub seed: String,
    /// When the scan was executed (Phase 1).
    pub executed_at: DateTime<Utc>,
    /// When the scan was finalized (Phase 2).
    pub finalized_at: Option<DateTime<Utc>>,
    /// Total number of deaths.
    pub death_count: Option<u32>,
    /// Total DATA lost from deaths.
    pub total_dead: Option<TokenAmount>,
    /// Amount burned.
    pub burned: Option<TokenAmount>,
    /// Amount distributed to same-level survivors.
    pub distributed_same_level: Option<TokenAmount>,
    /// Amount distributed to upstream levels.
    pub distributed_upstream: Option<TokenAmount>,
    /// Protocol fee collected.
    pub protocol_fee: Option<TokenAmount>,
    /// Number of survivors.
    pub survivor_count: Option<u32>,
}

impl Scan {
    /// Check if this scan has been finalized.
    #[must_use]
    pub const fn is_finalized(&self) -> bool {
        self.finalized_at.is_some()
    }
}

/// Data for finalizing a scan (used by `ScanStore` port).
#[derive(Debug, Clone)]
pub struct ScanFinalizationData {
    /// When the scan was finalized.
    pub finalized_at: DateTime<Utc>,
    /// Total number of deaths.
    pub death_count: u32,
    /// Total DATA lost.
    pub total_dead: TokenAmount,
    /// Amount burned.
    pub burned: TokenAmount,
    /// Amount distributed to same-level survivors.
    pub distributed_same_level: TokenAmount,
    /// Amount distributed to upstream levels.
    pub distributed_upstream: TokenAmount,
    /// Protocol fee collected.
    pub protocol_fee: TokenAmount,
    /// Number of survivors.
    pub survivor_count: u32,
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEATH
// ═══════════════════════════════════════════════════════════════════════════════

/// Individual death record.
///
/// Records when a position was "traced" (killed) during a scan.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Death {
    /// Unique identifier.
    pub id: Uuid,
    /// Associated scan (if any).
    pub scan_id: Option<Uuid>,
    /// User who died.
    pub user_address: EthAddress,
    /// Position that died (if linked).
    pub position_id: Option<Uuid>,
    /// Amount lost.
    pub amount_lost: TokenAmount,
    /// Level where death occurred.
    pub level: Level,
    /// Ghost streak at time of death.
    pub ghost_streak_at_death: Option<GhostStreak>,
    /// When the death was recorded.
    pub created_at: DateTime<Utc>,
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEAD POOL (Prediction Market)
// ═══════════════════════════════════════════════════════════════════════════════

/// Prediction market round.
///
/// Users can bet on outcomes like death counts, whale deaths, etc.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Round {
    /// Unique identifier (database).
    pub id: Uuid,
    /// On-chain round ID (U256 as string).
    pub round_id: String,
    /// Type of prediction.
    pub round_type: RoundType,
    /// Target level (for level-specific rounds).
    pub target_level: Option<Level>,
    /// Over/under line.
    pub line: TokenAmount,
    /// When betting closes.
    pub deadline: DateTime<Utc>,
    /// Total bet on OVER.
    pub over_pool: TokenAmount,
    /// Total bet on UNDER.
    pub under_pool: TokenAmount,
    /// Whether the round has been resolved.
    pub is_resolved: bool,
    /// Outcome (true = OVER won).
    pub outcome: Option<bool>,
    /// When resolved.
    pub resolve_time: Option<DateTime<Utc>>,
    /// Total rake burned.
    pub total_burned: Option<TokenAmount>,
}

impl Round {
    /// Get the total pot size.
    #[must_use]
    pub fn total_pot(&self) -> TokenAmount {
        self.over_pool.saturating_add(&self.under_pool)
    }

    /// Check if betting is still open.
    #[must_use]
    pub fn is_betting_open(&self, now: DateTime<Utc>) -> bool {
        !self.is_resolved && now < self.deadline
    }
}

/// User bet on a round.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Bet {
    /// Unique identifier.
    pub id: Uuid,
    /// Associated round (database ID).
    pub round_id: Uuid,
    /// User who placed the bet.
    pub user_address: EthAddress,
    /// Amount wagered.
    pub amount: TokenAmount,
    /// Bet direction (true = OVER).
    pub is_over: bool,
    /// Whether winnings have been claimed.
    pub is_claimed: bool,
    /// Winnings (if won and claimed).
    pub winnings: Option<TokenAmount>,
    /// When claimed.
    pub claimed_at: Option<DateTime<Utc>>,
}

impl Bet {
    /// Check if this bet won.
    ///
    /// Returns `None` if the round isn't resolved yet.
    #[must_use]
    pub const fn is_winner(&self, round_outcome: Option<bool>) -> Option<bool> {
        match round_outcome {
            Some(outcome) => Some(self.is_over == outcome),
            None => None,
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOOST
// ═══════════════════════════════════════════════════════════════════════════════

/// Active boost on a user.
///
/// Boosts are temporary modifiers earned through mini-games.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Boost {
    /// Unique identifier.
    pub id: Uuid,
    /// User with the boost.
    pub user_address: EthAddress,
    /// Type of boost.
    pub boost_type: BoostType,
    /// Boost value in basis points.
    pub value_bps: i16,
    /// When the boost expires.
    pub expiry: DateTime<Utc>,
    /// When the boost was granted.
    pub created_at: DateTime<Utc>,
}

impl Boost {
    /// Check if this boost is still active.
    #[must_use]
    pub fn is_active(&self, now: DateTime<Utc>) -> bool {
        now < self.expiry
    }

    /// Get the boost multiplier as a decimal (e.g., 0.35 for -35% death rate).
    #[must_use]
    pub fn multiplier(&self) -> f64 {
        f64::from(self.value_bps) / 10_000.0
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// POSITION HISTORY
// ═══════════════════════════════════════════════════════════════════════════════

/// Position history entry (for tracking changes over time).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PositionHistoryEntry {
    /// Unique identifier.
    pub id: Uuid,
    /// Associated position.
    pub position_id: Uuid,
    /// User address.
    pub user_address: EthAddress,
    /// What action occurred.
    pub action: PositionAction,
    /// Change in amount (positive or negative).
    pub amount_change: TokenAmount,
    /// New total after action.
    pub new_total: TokenAmount,
    /// Block where this occurred.
    pub block_number: BlockNumber,
    /// When this occurred.
    pub timestamp: DateTime<Utc>,
}

/// Actions that can be recorded in position history.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[non_exhaustive]
pub enum PositionAction {
    /// User entered a new position.
    JackedIn,
    /// User added to existing position.
    StakeAdded,
    /// User voluntarily extracted.
    Extracted,
    /// Position was traced in a scan.
    Traced,
    /// Position was culled.
    Culled,
    /// Position was closed in system reset.
    SystemReset,
    /// User claimed accumulated rewards.
    RewardsClaimed,
    /// Position was superseded by a new JackedIn event.
    ///
    /// This indicates the old position was closed to make room for a new one.
    /// The funds moved to the new position, so this is not a loss.
    Superseded,
}

impl PositionAction {
    /// Get the display name for this action.
    #[must_use]
    pub const fn name(&self) -> &'static str {
        match self {
            Self::JackedIn => "Jacked In",
            Self::StakeAdded => "Stake Added",
            Self::Extracted => "Extracted",
            Self::Traced => "Traced",
            Self::Culled => "Culled",
            Self::SystemReset => "System Reset",
            Self::RewardsClaimed => "Rewards Claimed",
            Self::Superseded => "Superseded",
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

/// Per-level aggregate statistics.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LevelStats {
    /// Which level.
    pub level: Level,
    /// Total DATA staked at this level.
    pub total_staked: TokenAmount,
    /// Number of active positions.
    pub alive_count: u32,
    /// Total deaths ever at this level.
    pub total_deaths: u32,
    /// Total positions that extracted.
    pub total_extracted: u32,
    /// Total DATA burned from deaths.
    pub total_burned: TokenAmount,
    /// Total DATA distributed to survivors.
    pub total_distributed: TokenAmount,
    /// Highest ghost streak achieved at this level.
    pub highest_ghost_streak: GhostStreak,
    /// Last update time.
    pub updated_at: DateTime<Utc>,
}

/// Delta for updating level statistics.
///
/// Use this to atomically update stats without race conditions.
#[derive(Debug, Clone, Default)]
pub struct LevelStatsDelta {
    /// Change in total staked.
    pub staked_delta: Option<TokenAmount>,
    /// Change in alive count (can be negative).
    pub alive_delta: Option<i32>,
    /// Increment in death count.
    pub deaths_delta: Option<u32>,
    /// Increment in extraction count.
    pub extracted_delta: Option<u32>,
    /// Increment in burned amount.
    pub burned_delta: Option<TokenAmount>,
    /// Increment in distributed amount.
    pub distributed_delta: Option<TokenAmount>,
    /// New highest streak (if higher than current).
    pub new_highest_streak: Option<GhostStreak>,
}

/// Global protocol statistics.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct GlobalStats {
    /// Total DATA locked across all levels.
    pub total_value_locked: TokenAmount,
    /// Total active positions.
    pub total_positions: u32,
    /// Total deaths ever.
    pub total_deaths: u32,
    /// Total DATA burned.
    pub total_burned: TokenAmount,
    /// Total emissions distributed.
    pub total_emissions_distributed: TokenAmount,
    /// Total toll collected (ETH).
    pub total_toll_collected: TokenAmount,
    /// Total DATA burned via buyback.
    pub total_buyback_burned: TokenAmount,
    /// Number of system resets.
    pub system_reset_count: u32,
    /// Last update time.
    pub updated_at: DateTime<Utc>,
}

/// Leaderboard entry.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LeaderboardEntry {
    /// Position on the leaderboard (1-indexed).
    pub rank: u32,
    /// User address.
    pub user_address: EthAddress,
    /// Score (interpretation depends on leaderboard type).
    pub score: TokenAmount,
    /// Additional metadata (JSON).
    pub metadata: Option<serde_json::Value>,
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::expect_used)]
mod tests {
    use super::*;

    fn sample_address() -> EthAddress {
        EthAddress::from_hex("0x1234567890123456789012345678901234567890").unwrap()
    }

    mod position_tests {
        use super::*;

        #[test]
        fn active_position() {
            let pos = Position {
                id: Uuid::new_v4(),
                user_address: sample_address(),
                level: Level::Subnet,
                amount: TokenAmount::parse("100").unwrap(),
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
                created_at_block: BlockNumber::new(1000),
                updated_at: Utc::now(),
            };

            assert!(pos.is_active());
        }

        #[test]
        fn dead_position_not_active() {
            let pos = Position {
                id: Uuid::new_v4(),
                user_address: sample_address(),
                level: Level::Darknet,
                amount: TokenAmount::zero(),
                reward_debt: TokenAmount::zero(),
                entry_timestamp: Utc::now(),
                last_add_timestamp: None,
                ghost_streak: GhostStreak::ZERO,
                is_alive: false,
                is_extracted: false,
                exit_reason: Some(ExitReason::Traced),
                exit_timestamp: Some(Utc::now()),
                extracted_amount: None,
                extracted_rewards: None,
                created_at_block: BlockNumber::new(1000),
                updated_at: Utc::now(),
            };

            assert!(!pos.is_active());
        }
    }

    mod round_tests {
        use super::*;

        #[test]
        fn total_pot_calculation() {
            let round = Round {
                id: Uuid::new_v4(),
                round_id: "1".into(),
                round_type: RoundType::DeathCount,
                target_level: Some(Level::Darknet),
                line: TokenAmount::parse("10").unwrap(),
                deadline: Utc::now(),
                over_pool: TokenAmount::parse("500").unwrap(),
                under_pool: TokenAmount::parse("300").unwrap(),
                is_resolved: false,
                outcome: None,
                resolve_time: None,
                total_burned: None,
            };

            assert_eq!(round.total_pot().to_string(), "800");
        }
    }

    mod bet_tests {
        use super::*;

        #[test]
        fn bet_wins_when_matches_outcome() {
            let bet = Bet {
                id: Uuid::new_v4(),
                round_id: Uuid::new_v4(),
                user_address: sample_address(),
                amount: TokenAmount::parse("100").unwrap(),
                is_over: true,
                is_claimed: false,
                winnings: None,
                claimed_at: None,
            };

            // OVER bet wins when outcome is true (OVER)
            assert_eq!(bet.is_winner(Some(true)), Some(true));
            // OVER bet loses when outcome is false (UNDER)
            assert_eq!(bet.is_winner(Some(false)), Some(false));
            // Unknown when round not resolved
            assert_eq!(bet.is_winner(None), None);
        }
    }

    mod boost_tests {
        use super::*;
        use chrono::Duration;

        #[test]
        fn boost_active_before_expiry() {
            let now = Utc::now();
            let boost = Boost {
                id: Uuid::new_v4(),
                user_address: sample_address(),
                boost_type: BoostType::DeathReduction,
                value_bps: 3500,
                expiry: now + Duration::hours(1),
                created_at: now,
            };

            assert!(boost.is_active(now));
        }

        #[test]
        fn boost_inactive_after_expiry() {
            let now = Utc::now();
            let boost = Boost {
                id: Uuid::new_v4(),
                user_address: sample_address(),
                boost_type: BoostType::DeathReduction,
                value_bps: 3500,
                expiry: now - Duration::hours(1),
                created_at: now - Duration::hours(2),
            };

            assert!(!boost.is_active(now));
        }

        #[test]
        fn boost_multiplier_calculation() {
            let boost = Boost {
                id: Uuid::new_v4(),
                user_address: sample_address(),
                boost_type: BoostType::DeathReduction,
                value_bps: 3500, // 35%
                expiry: Utc::now(),
                created_at: Utc::now(),
            };

            let expected = 0.35_f64;
            let actual = boost.multiplier();
            assert!((actual - expected).abs() < f64::EPSILON);
        }
    }
}
