//! Configuration for the GHOSTNET plugin.

use alloy::primitives::Address;
use serde::{Deserialize, Serialize};

// ═══════════════════════════════════════════════════════════════════════════════
// GHOSTNET CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

/// Configuration for the GHOSTNET plugin.
///
/// Contains all contract addresses and chain-specific settings needed
/// to interact with the GHOSTNET protocol.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GhostnetConfig {
    /// GhostCore contract address (main staking).
    pub ghost_core: Address,

    /// HashCrash game contract address.
    pub hash_crash: Address,

    /// ArcadeCore contract address (game management).
    pub arcade_core: Address,

    /// DATA token contract address.
    pub data_token: Address,

    /// Chain ID (6343 for MegaETH testnet, 4326 for mainnet).
    pub chain_id: u64,

    /// Behavior settings.
    #[serde(default)]
    pub behavior: BehaviorSettings,
}

impl GhostnetConfig {
    /// Create a new config with the given addresses.
    #[must_use]
    pub const fn new(
        ghost_core: Address,
        hash_crash: Address,
        arcade_core: Address,
        data_token: Address,
        chain_id: u64,
    ) -> Self {
        Self {
            ghost_core,
            hash_crash,
            arcade_core,
            data_token,
            chain_id,
            behavior: BehaviorSettings::default_const(),
        }
    }

    /// Create a config for MegaETH testnet with placeholder addresses.
    ///
    /// # Note
    ///
    /// These are placeholder addresses and should be replaced with actual
    /// deployed contract addresses before use.
    #[must_use]
    pub fn testnet() -> Self {
        // Placeholder addresses - update with actual deployed contracts
        Self {
            ghost_core: Address::repeat_byte(0x01),
            hash_crash: Address::repeat_byte(0x02),
            arcade_core: Address::repeat_byte(0x03),
            data_token: Address::repeat_byte(0x04),
            chain_id: 6343, // MegaETH testnet
            behavior: BehaviorSettings::default(),
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BEHAVIOR SETTINGS
// ═══════════════════════════════════════════════════════════════════════════════

/// Settings that control how the plugin makes decisions.
///
/// These are translated from the generic `BehaviorProfile` into
/// GHOSTNET-specific thresholds and probabilities.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BehaviorSettings {
    /// Minimum DATA balance to consider entering a position (in wei).
    /// Wallets with less than this will not attempt to jack in.
    pub min_entry_balance: u128,

    /// Minimum streak before considering extraction.
    /// Higher = hold positions longer.
    pub min_streak_before_extract: u16,

    /// Base probability of extracting when eligible (0.0 - 1.0).
    pub base_extract_probability: f64,

    /// Base probability of compounding (adding stake) when eligible (0.0 - 1.0).
    pub base_compound_probability: f64,

    /// Whether to play HashCrash game.
    pub plays_hashcrash: bool,

    /// Maximum percentage of balance to bet on HashCrash (0.0 - 1.0).
    pub max_hashcrash_bet_pct: f64,
}

impl Default for BehaviorSettings {
    fn default() -> Self {
        Self::default_const()
    }
}

impl BehaviorSettings {
    /// Create default behavior settings (const version).
    #[must_use]
    pub const fn default_const() -> Self {
        Self {
            min_entry_balance: 10_000_000_000_000_000_000, // 10 DATA
            min_streak_before_extract: 3,
            base_extract_probability: 0.3,
            base_compound_probability: 0.2,
            plays_hashcrash: true,
            max_hashcrash_bet_pct: 0.05, // 5% max per bet
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEVEL SETTINGS
// ═══════════════════════════════════════════════════════════════════════════════

/// Per-level configuration for entry decisions.
///
/// These are the protocol-defined minimums plus our own settings.
#[derive(Debug, Clone, Copy)]
pub struct LevelSettings {
    /// Minimum stake for this level (from protocol).
    pub min_stake: u128,

    /// Maximum stake we allow for this level.
    pub max_stake: u128,

    /// Risk tolerance required to enter this level (0.0 - 1.0).
    pub min_risk_tolerance: f64,
}

impl LevelSettings {
    /// Get settings for each level.
    #[must_use]
    pub const fn for_level(level: u8) -> Option<Self> {
        match level {
            1 => Some(Self {
                min_stake: 1_000_000_000_000_000_000, // 1 DATA
                max_stake: u128::MAX,
                min_risk_tolerance: 0.0,
            }),
            2 => Some(Self {
                min_stake: 10_000_000_000_000_000_000, // 10 DATA
                max_stake: u128::MAX,
                min_risk_tolerance: 0.1,
            }),
            3 => Some(Self {
                min_stake: 50_000_000_000_000_000_000, // 50 DATA
                max_stake: u128::MAX,
                min_risk_tolerance: 0.3,
            }),
            4 => Some(Self {
                min_stake: 100_000_000_000_000_000_000, // 100 DATA
                max_stake: u128::MAX,
                min_risk_tolerance: 0.5,
            }),
            5 => Some(Self {
                min_stake: 500_000_000_000_000_000_000, // 500 DATA
                max_stake: u128::MAX,
                min_risk_tolerance: 0.8,
            }),
            _ => None,
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn testnet_config_is_valid() {
        let config = GhostnetConfig::testnet();
        assert_eq!(config.chain_id, 6343);
        assert_ne!(config.ghost_core, Address::ZERO);
    }

    #[test]
    fn level_settings_exist_for_all_levels() {
        for level in 1..=5 {
            assert!(
                LevelSettings::for_level(level).is_some(),
                "level {level} should have settings"
            );
        }
        assert!(LevelSettings::for_level(0).is_none());
        assert!(LevelSettings::for_level(6).is_none());
    }

    #[test]
    fn level_risk_tolerance_increases() {
        let mut prev = 0.0;
        for level in 1..=5 {
            let settings = LevelSettings::for_level(level).unwrap();
            assert!(
                settings.min_risk_tolerance >= prev,
                "level {level} should have higher risk tolerance"
            );
            prev = settings.min_risk_tolerance;
        }
    }
}
