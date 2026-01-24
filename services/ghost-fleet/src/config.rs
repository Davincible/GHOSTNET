//! Configuration loading and validation.
//!
//! Configuration is loaded from a TOML file and can be overridden by
//! environment variables.
//!
//! # Example Configuration
//!
//! ```toml
//! [service]
//! name = "ghost-fleet"
//! tick_interval_ms = 1000
//!
//! [chain]
//! chain_id = 6343
//! rpc_url = "https://carrot.megaeth.com/rpc"
//!
//! [plugins]
//! enabled = ["ghostnet"]
//!
//! [plugins.ghostnet]
//! ghost_core = "0x..."
//! ```

use std::collections::HashMap;
use std::fs;
use std::path::Path;

use alloy::primitives::Address;
use serde::{Deserialize, Serialize};
use tracing::debug;

use crate::error::{ConfigError, Result};

// ═══════════════════════════════════════════════════════════════════════════════
// SETTINGS
// ═══════════════════════════════════════════════════════════════════════════════

/// Root configuration structure.
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Settings {
    /// Service configuration.
    #[serde(default)]
    pub service: ServiceConfig,

    /// Chain/network configuration.
    pub chain: ChainConfig,

    /// Wallet configurations.
    #[serde(default)]
    pub wallets: Vec<WalletConfig>,

    /// Plugin configuration.
    #[serde(default)]
    pub plugins: PluginsConfig,

    /// Safety settings.
    #[serde(default)]
    pub safety: SafetyConfig,

    /// Behavior profile definitions.
    #[serde(default)]
    pub profiles: HashMap<String, ProfileConfig>,
}

impl Settings {
    /// Load settings from a TOML file.
    pub fn load(path: impl AsRef<Path>) -> Result<Self> {
        let path = path.as_ref();
        debug!(path = %path.display(), "Loading configuration");

        let content = fs::read_to_string(path)
            .map_err(|e| ConfigError::FileRead {
                path: path.to_path_buf(),
                source: e,
            })?;

        let settings: Self = toml::from_str(&content)
            .map_err(|e| ConfigError::Parse {
                path: path.to_path_buf(),
                source: e,
            })?;

        Ok(settings)
    }

    /// Validate the configuration.
    pub fn validate(&self) -> Result<()> {
        // Check chain configuration
        if self.chain.rpc_url.is_empty() {
            return Err(ConfigError::Validation("chain.rpc_url is required".into()).into());
        }

        // Check that enabled plugins have configuration
        for plugin_id in &self.plugins.enabled {
            if plugin_id == "ghostnet" && self.plugins.ghostnet.is_none() {
                return Err(ConfigError::Validation(
                    "Plugin 'ghostnet' is enabled but [plugins.ghostnet] is not configured".into(),
                ).into());
            }
        }

        // Check wallet configurations
        for (i, wallet) in self.wallets.iter().enumerate() {
            if wallet.id.is_empty() {
                return Err(ConfigError::Validation(
                    format!("wallets[{i}].id is required"),
                ).into());
            }
            if wallet.profile.is_empty() {
                return Err(ConfigError::Validation(
                    format!("wallets[{i}].profile is required"),
                ).into());
            }
            // Check profile exists
            if !self.profiles.contains_key(&wallet.profile) {
                let profile = &wallet.profile;
                return Err(ConfigError::Validation(
                    format!(
                        "wallets[{i}].profile '{profile}' not found in [profiles]"
                    ),
                ).into());
            }
        }

        // Check safety settings
        if self.safety.max_consecutive_errors == 0 {
            return Err(ConfigError::Validation(
                "safety.max_consecutive_errors must be > 0".into(),
            ).into());
        }

        Ok(())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICE CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

/// Service-level configuration.
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct ServiceConfig {
    /// Service name (for logging).
    #[serde(default = "default_service_name")]
    pub name: String,

    /// Main loop tick interval in milliseconds.
    #[serde(default = "default_tick_interval")]
    pub tick_interval_ms: u64,

    /// Health check HTTP port (0 to disable).
    #[serde(default)]
    pub health_port: u16,
}

fn default_service_name() -> String {
    "ghost-fleet".into()
}

const fn default_tick_interval() -> u64 {
    1000
}

impl Default for ServiceConfig {
    fn default() -> Self {
        Self {
            name: default_service_name(),
            tick_interval_ms: default_tick_interval(),
            health_port: 0,
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHAIN CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

/// Chain/network configuration.
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct ChainConfig {
    /// Chain ID.
    pub chain_id: u64,

    /// RPC URL.
    pub rpc_url: String,

    /// Chain type for provider selection.
    #[serde(default = "default_chain_type")]
    pub chain_type: String,

    /// Gas limit override (for chains with unreliable estimation).
    pub gas_limit_override: Option<u64>,

    /// Use realtime API if available (MegaETH).
    #[serde(default)]
    pub use_realtime: bool,
}

fn default_chain_type() -> String {
    "standard".into()
}

// ═══════════════════════════════════════════════════════════════════════════════
// WALLET CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

/// Individual wallet configuration.
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct WalletConfig {
    /// Unique wallet identifier.
    pub id: String,

    /// Wallet address.
    pub address: Address,

    /// Behavior profile name.
    pub profile: String,

    /// Private key (hex, with or without 0x prefix).
    /// In production, use encrypted keyfile instead.
    pub private_key: Option<String>,

    /// Path to encrypted keyfile.
    pub keyfile: Option<String>,

    /// Whether this wallet is enabled.
    #[serde(default = "default_true")]
    pub enabled: bool,
}

const fn default_true() -> bool {
    true
}

// ═══════════════════════════════════════════════════════════════════════════════
// PLUGINS CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

/// Plugin configuration.
#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct PluginsConfig {
    /// List of enabled plugin IDs.
    #[serde(default)]
    pub enabled: Vec<String>,

    /// GHOSTNET plugin configuration.
    pub ghostnet: Option<GhostnetPluginConfig>,
}

/// GHOSTNET-specific plugin configuration.
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct GhostnetPluginConfig {
    /// GhostCore contract address.
    pub ghost_core: Address,

    /// HashCrash contract address.
    pub hash_crash: Address,

    /// ArcadeCore contract address.
    pub arcade_core: Address,

    /// DATA token address.
    pub data_token: Address,

    /// Minimum stake amount (in wei).
    #[serde(default = "default_min_stake")]
    pub min_stake: String,

    /// Enable HashCrash arcade game.
    #[serde(default)]
    pub hashcrash_enabled: bool,
}

fn default_min_stake() -> String {
    "1000000000000000000".into() // 1 DATA
}

// ═══════════════════════════════════════════════════════════════════════════════
// SAFETY CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

/// Safety and circuit breaker configuration.
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct SafetyConfig {
    /// Maximum consecutive errors before circuit trips.
    #[serde(default = "default_max_errors")]
    pub max_consecutive_errors: u32,

    /// Circuit breaker cooldown in seconds.
    #[serde(default = "default_cooldown")]
    pub cooldown_secs: u64,

    /// Maximum actions per wallet per hour.
    #[serde(default = "default_max_actions")]
    pub max_actions_per_hour: u32,

    /// Global pause switch.
    #[serde(default)]
    pub global_pause: bool,
}

const fn default_max_errors() -> u32 {
    5
}

const fn default_cooldown() -> u64 {
    3600 // 1 hour
}

const fn default_max_actions() -> u32 {
    20
}

impl Default for SafetyConfig {
    fn default() -> Self {
        Self {
            max_consecutive_errors: default_max_errors(),
            cooldown_secs: default_cooldown(),
            max_actions_per_hour: default_max_actions(),
            global_pause: false,
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROFILE CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

/// Behavior profile configuration.
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct ProfileConfig {
    /// Risk tolerance (0.0 to 1.0).
    #[serde(default = "default_risk")]
    pub risk_tolerance: f64,

    /// Activity level (actions per hour).
    #[serde(default = "default_activity")]
    pub activity_level: f64,

    /// Patience factor (0.0 to 1.0).
    #[serde(default = "default_patience")]
    pub patience: f64,

    /// Base action interval in seconds.
    #[serde(default = "default_interval")]
    pub action_interval_secs: u64,

    /// Interval jitter percentage (0-100).
    #[serde(default = "default_jitter")]
    pub action_interval_jitter_pct: u8,

    /// Active hours start (UTC, 0-23).
    #[serde(default = "default_hours_start")]
    pub active_hours_start: u8,

    /// Active hours end (UTC, 0-23).
    #[serde(default = "default_hours_end")]
    pub active_hours_end: u8,

    /// Off-hours activity factor (0.0 to 1.0).
    #[serde(default = "default_off_hours")]
    pub off_hours_factor: f64,

    /// AFK probability (0.0 to 1.0).
    #[serde(default = "default_afk_prob")]
    pub afk_probability: f64,

    /// Minimum AFK duration in hours.
    #[serde(default = "default_afk_min")]
    pub afk_min_hours: u64,

    /// Maximum AFK duration in hours.
    #[serde(default = "default_afk_max")]
    pub afk_max_hours: u64,
}

const fn default_risk() -> f64 { 0.5 }
const fn default_activity() -> f64 { 5.0 }
const fn default_patience() -> f64 { 0.5 }
const fn default_interval() -> u64 { 3600 }
const fn default_jitter() -> u8 { 50 }
const fn default_hours_start() -> u8 { 8 }
const fn default_hours_end() -> u8 { 22 }
const fn default_off_hours() -> f64 { 0.3 }
const fn default_afk_prob() -> f64 { 0.1 }
const fn default_afk_min() -> u64 { 4 }
const fn default_afk_max() -> u64 { 24 }

impl Default for ProfileConfig {
    fn default() -> Self {
        Self {
            risk_tolerance: default_risk(),
            activity_level: default_activity(),
            patience: default_patience(),
            action_interval_secs: default_interval(),
            action_interval_jitter_pct: default_jitter(),
            active_hours_start: default_hours_start(),
            active_hours_end: default_hours_end(),
            off_hours_factor: default_off_hours(),
            afk_probability: default_afk_prob(),
            afk_min_hours: default_afk_min(),
            afk_max_hours: default_afk_max(),
        }
    }
}

impl ProfileConfig {
    /// Convert to fleet-core BehaviorProfile.
    #[must_use]
    pub fn to_behavior_profile(&self, name: &str) -> fleet_core::profiles::BehaviorProfile {
        fleet_core::profiles::BehaviorProfile {
            name: name.to_string(),
            risk_tolerance: self.risk_tolerance,
            activity_level: self.activity_level,
            patience: self.patience,
            action_interval_secs: self.action_interval_secs,
            action_interval_jitter_pct: self.action_interval_jitter_pct,
            active_hours_start: self.active_hours_start,
            active_hours_end: self.active_hours_end,
            off_hours_factor: self.off_hours_factor,
            afk_probability: self.afk_probability,
            afk_min_hours: self.afk_min_hours,
            afk_max_hours: self.afk_max_hours,
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
    fn default_service_config() {
        let config = ServiceConfig::default();
        assert_eq!(config.name, "ghost-fleet");
        assert_eq!(config.tick_interval_ms, 1000);
    }

    #[test]
    fn default_safety_config() {
        let config = SafetyConfig::default();
        assert_eq!(config.max_consecutive_errors, 5);
        assert_eq!(config.cooldown_secs, 3600);
        assert!(!config.global_pause);
    }

    #[test]
    fn profile_to_behavior_profile() {
        let config = ProfileConfig::default();
        let profile = config.to_behavior_profile("test");
        
        assert_eq!(profile.name, "test");
        assert!((profile.risk_tolerance - 0.5).abs() < f64::EPSILON);
    }
}
