//! GHOSTNET-specific state types.
//!
//! This module defines the state structures stored in `WalletState.plugin_states["ghostnet"]`.

use alloy::primitives::U256;
use serde::{Deserialize, Serialize};

// ═══════════════════════════════════════════════════════════════════════════════
// LEVEL ENUM
// ═══════════════════════════════════════════════════════════════════════════════

/// Risk levels in GHOSTNET.
///
/// Higher levels have higher death rates but also higher potential rewards.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[repr(u8)]
pub enum Level {
    /// No position / invalid.
    None = 0,
    /// THE VAULT - Safest (5% death rate).
    Vault = 1,
    /// MAINFRAME - Conservative (15% death rate).
    Mainframe = 2,
    /// SUBNET - Balanced (25% death rate).
    Subnet = 3,
    /// DARKNET - High risk (35% death rate).
    Darknet = 4,
    /// BLACK ICE - Maximum risk (45% death rate).
    BlackIce = 5,
}

impl Level {
    /// Convert from u8.
    #[must_use]
    pub const fn from_u8(value: u8) -> Option<Self> {
        match value {
            0 => Some(Self::None),
            1 => Some(Self::Vault),
            2 => Some(Self::Mainframe),
            3 => Some(Self::Subnet),
            4 => Some(Self::Darknet),
            5 => Some(Self::BlackIce),
            _ => None,
        }
    }

    /// Convert to u8.
    #[must_use]
    pub const fn as_u8(self) -> u8 {
        self as u8
    }

    /// Get the base death rate in basis points.
    #[must_use]
    pub const fn base_death_rate_bps(self) -> u16 {
        match self {
            Self::None => 0,
            Self::Vault => 500,     // 5%
            Self::Mainframe => 1500, // 15%
            Self::Subnet => 2500,   // 25%
            Self::Darknet => 3500,  // 35%
            Self::BlackIce => 4500, // 45%
        }
    }

    /// Get the scan interval in seconds.
    #[must_use]
    pub const fn scan_interval_secs(self) -> u32 {
        match self {
            Self::None => 0,
            Self::Vault => 86400,    // 24 hours
            Self::Mainframe => 28800, // 8 hours
            Self::Subnet => 14400,   // 4 hours
            Self::Darknet => 7200,   // 2 hours
            Self::BlackIce => 1800,  // 30 minutes
        }
    }

    /// Check if this is a valid playable level.
    #[must_use]
    pub const fn is_valid(self) -> bool {
        !matches!(self, Self::None)
    }

    /// Get display name.
    #[must_use]
    pub const fn display_name(self) -> &'static str {
        match self {
            Self::None => "NONE",
            Self::Vault => "THE VAULT",
            Self::Mainframe => "MAINFRAME",
            Self::Subnet => "SUBNET",
            Self::Darknet => "DARKNET",
            Self::BlackIce => "BLACK ICE",
        }
    }
}

impl std::fmt::Display for Level {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.display_name())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// POSITION
// ═══════════════════════════════════════════════════════════════════════════════

/// A user's staking position in GhostCore.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Position {
    /// Total staked DATA (in wei).
    pub amount: U256,

    /// Risk level.
    pub level: Level,

    /// When the position was created.
    pub entry_timestamp: u64,

    /// When stake was last added.
    pub last_add_timestamp: u64,

    /// Whether the position is alive.
    pub alive: bool,

    /// Consecutive scan survivals.
    pub ghost_streak: u16,

    /// Pending rewards (in wei).
    pub pending_rewards: U256,

    /// Effective death rate after boosts (basis points).
    pub effective_death_rate_bps: u16,

    /// Whether the position is in lock period.
    pub in_lock_period: bool,
}

impl Position {
    /// Check if the position can be extracted.
    #[must_use]
    pub const fn can_extract(&self) -> bool {
        self.alive && !self.in_lock_period
    }

    /// Check if more stake can be added.
    #[must_use]
    pub const fn can_add_stake(&self) -> bool {
        self.alive
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HASHCRASH STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Current state of a HashCrash round.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HashCrashRound {
    /// Round ID.
    pub round_id: u64,

    /// Whether the round is accepting bets.
    pub is_betting: bool,

    /// When betting ends (Unix timestamp).
    pub betting_ends_at: u64,

    /// Number of players in the round.
    pub player_count: u32,

    /// Total prize pool.
    pub prize_pool: U256,
}

impl HashCrashRound {
    /// Check if we can still place a bet.
    #[must_use]
    pub const fn can_bet(&self, now_unix: u64) -> bool {
        self.is_betting && now_unix < self.betting_ends_at
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GHOSTNET STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Complete GHOSTNET state for a wallet.
///
/// This is stored in `WalletState.plugin_states["ghostnet"]`.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct GhostnetState {
    /// Current GhostCore position (if any).
    pub position: Option<Position>,

    /// DATA token balance (in wei).
    pub data_balance: U256,

    /// DATA token allowance for GhostCore (in wei).
    pub ghost_core_allowance: U256,

    /// DATA token allowance for ArcadeCore (in wei).
    pub arcade_core_allowance: U256,

    /// Current HashCrash round (if betting is open).
    pub hashcrash_round: Option<HashCrashRound>,

    /// Timestamp when state was last refreshed.
    pub last_refresh: u64,
}

impl GhostnetState {
    /// Check if the wallet has an active position.
    #[must_use]
    pub fn has_active_position(&self) -> bool {
        self.position.as_ref().is_some_and(|p| p.alive)
    }

    /// Check if the wallet has a dead position.
    #[must_use]
    pub fn has_dead_position(&self) -> bool {
        self.position.as_ref().is_some_and(|p| !p.alive)
    }

    /// Get the position if it's alive.
    #[must_use]
    pub fn active_position(&self) -> Option<&Position> {
        self.position.as_ref().filter(|p| p.alive)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn level_roundtrip() {
        for level_u8 in 0..=5 {
            let level = Level::from_u8(level_u8).expect("valid level");
            assert_eq!(level.as_u8(), level_u8);
        }
    }

    #[test]
    fn level_invalid() {
        assert!(Level::from_u8(6).is_none());
        assert!(Level::from_u8(255).is_none());
    }

    #[test]
    fn death_rate_increases_with_level() {
        let levels = [
            Level::Vault,
            Level::Mainframe,
            Level::Subnet,
            Level::Darknet,
            Level::BlackIce,
        ];

        let mut prev = 0;
        for level in levels {
            let rate = level.base_death_rate_bps();
            assert!(rate > prev, "{level} should have higher death rate");
            prev = rate;
        }
    }

    #[test]
    fn scan_interval_decreases_with_level() {
        let levels = [
            Level::Vault,
            Level::Mainframe,
            Level::Subnet,
            Level::Darknet,
            Level::BlackIce,
        ];

        let mut prev = u32::MAX;
        for level in levels {
            let interval = level.scan_interval_secs();
            assert!(interval < prev, "{level} should have shorter scan interval");
            prev = interval;
        }
    }

    #[test]
    fn position_can_extract() {
        let position = Position {
            amount: U256::from(100),
            level: Level::Subnet,
            entry_timestamp: 0,
            last_add_timestamp: 0,
            alive: true,
            ghost_streak: 5,
            pending_rewards: U256::ZERO,
            effective_death_rate_bps: 2500,
            in_lock_period: false,
        };

        assert!(position.can_extract());
        assert!(position.can_add_stake());

        let dead_position = Position {
            alive: false,
            ..position.clone()
        };
        assert!(!dead_position.can_extract());
        assert!(!dead_position.can_add_stake());

        let locked_position = Position {
            in_lock_period: true,
            ..position
        };
        assert!(!locked_position.can_extract());
        assert!(locked_position.can_add_stake());
    }

    #[test]
    fn ghostnet_state_position_helpers() {
        let mut state = GhostnetState::default();
        assert!(!state.has_active_position());
        assert!(!state.has_dead_position());
        assert!(state.active_position().is_none());

        state.position = Some(Position {
            amount: U256::from(100),
            level: Level::Subnet,
            entry_timestamp: 0,
            last_add_timestamp: 0,
            alive: true,
            ghost_streak: 0,
            pending_rewards: U256::ZERO,
            effective_death_rate_bps: 2500,
            in_lock_period: false,
        });

        assert!(state.has_active_position());
        assert!(!state.has_dead_position());
        assert!(state.active_position().is_some());

        state.position.as_mut().unwrap().alive = false;
        assert!(!state.has_active_position());
        assert!(state.has_dead_position());
        assert!(state.active_position().is_none());
    }
}
