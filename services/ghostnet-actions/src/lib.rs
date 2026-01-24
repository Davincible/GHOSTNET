//! GHOSTNET Actions Plugin for Ghost Fleet.
//!
//! This crate provides the [`GhostnetPlugin`] which implements the
//! [`ActionPlugin`](fleet_core::ActionPlugin) trait for GHOSTNET protocol
//! interactions.
//!
//! # Crate Relationships
//!
//! ```text
//! ┌──────────────────────────────────────────────────────────────┐
//! │  Application Layer                                           │
//! │  └─ ghost-fleet (main service)                               │
//! │        │                                                     │
//! │        ▼                                                     │
//! │  ghostnet-actions ◄── YOU ARE HERE                           │
//! │  └─ GhostnetPlugin: implements ActionPlugin                  │
//! │  └─ GhostCore actions: jackIn, addStake, extract             │
//! │  └─ HashCrash actions: placeBet (arcade game)                │
//! └──────────────────────────────────┬───────────────────────────┘
//!                                    │
//!                                    ▼
//! ┌──────────────────────────────────────────────────────────────┐
//! │  Orchestration Layer (fleet-core)                            │
//! │  └─ ActionPlugin trait                                       │
//! │  └─ WalletState, BehaviorProfile                             │
//! │  └─ CircuitBreaker, Scheduler                                │
//! └──────────────────────────────────┬───────────────────────────┘
//!                                    │
//!                                    ▼
//! ┌──────────────────────────────────────────────────────────────┐
//! │  Chain Abstraction Layer (evm-provider)                      │
//! │  └─ ChainProvider: unified interface to any EVM chain        │
//! └──────────────────────────────────────────────────────────────┘
//! ```
//!
//! # Supported Actions
//!
//! ## GhostCore (Main Staking)
//!
//! | Action | Description |
//! |--------|-------------|
//! | `ghostnet.jack_in` | Enter a new position at a risk level |
//! | `ghostnet.add_stake` | Add stake to existing position |
//! | `ghostnet.extract` | Exit position and claim rewards |
//! | `ghostnet.claim_rewards` | Claim pending rewards without exiting |
//!
//! ## HashCrash (Arcade Game)
//!
//! | Action | Description |
//! |--------|-------------|
//! | `ghostnet.hashcrash_bet` | Place a bet in the current round |
//!
//! # Configuration
//!
//! The plugin requires a [`GhostnetConfig`] with contract addresses:
//!
//! ```ignore
//! let config = GhostnetConfig {
//!     ghost_core: "0x...".parse()?,
//!     hash_crash: "0x...".parse()?,
//!     arcade_core: "0x...".parse()?,
//!     data_token: "0x...".parse()?,
//!     chain_id: 6343,
//! };
//!
//! let plugin = GhostnetPlugin::new(config, provider);
//! ```
//!
//! # Example Usage
//!
//! ```ignore
//! use ghostnet_actions::GhostnetPlugin;
//! use fleet_core::{PluginRegistry, ActionPlugin};
//!
//! // Create plugin
//! let plugin = GhostnetPlugin::new(config, provider);
//!
//! // Register with the fleet
//! let mut registry = PluginRegistry::new();
//! registry.register(Arc::new(plugin));
//! ```

#![doc(html_root_url = "https://docs.ghostnet.io/ghostnet-actions")]

// ═══════════════════════════════════════════════════════════════════════════════
// MODULES
// ═══════════════════════════════════════════════════════════════════════════════

pub mod config;
pub mod contracts;
pub mod error;
pub mod plugin;
pub mod state;

mod actions;
mod math;

// ═══════════════════════════════════════════════════════════════════════════════
// RE-EXPORTS
// ═══════════════════════════════════════════════════════════════════════════════

pub use config::GhostnetConfig;
pub use error::{GhostnetError, Result};
pub use plugin::GhostnetPlugin;
pub use state::{GhostnetState, Level, Position};

// ═══════════════════════════════════════════════════════════════════════════════
// CRATE INFO
// ═══════════════════════════════════════════════════════════════════════════════

/// Crate version.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Returns the crate version string.
#[must_use]
pub const fn version() -> &'static str {
    VERSION
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_is_set() {
        assert!(!version().is_empty());
        assert!(version().starts_with("0."));
    }
}
