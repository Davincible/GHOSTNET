//! Orchestration primitives for Ghost Fleet.
//!
//! This crate provides chain-agnostic building blocks for managing wallets,
//! executing actions, and maintaining safety. It is the foundation layer
//! that protocol-specific plugins build upon.
//!
//! # Crate Relationships
//!
//! ```text
//! ┌──────────────────────────────────────────────────────────────┐
//! │  Application Layer                                           │
//! │  └─ ghost-fleet (main service)                               │
//! │  └─ ghostnet-actions (GHOSTNET plugin)                       │
//! └──────────────────────────────────┬───────────────────────────┘
//!                                    │
//!                                    ▼
//! ┌──────────────────────────────────────────────────────────────┐
//! │  Orchestration Layer (fleet-core) ◄── YOU ARE HERE           │
//! │  └─ WalletState: track balances, nonces, plugin state        │
//! │  └─ BehaviorProfile: define timing, risk, activity           │
//! │  └─ ActionPlugin: trait for protocol-specific actions        │
//! │  └─ CircuitBreaker: safety mechanism for error handling      │
//! │  └─ Scheduler: action timing with jitter                     │
//! │  └─ FleetMetrics: observability primitives                   │
//! └──────────────────────────────────┬───────────────────────────┘
//!                                    │
//!                                    ▼
//! ┌──────────────────────────────────────────────────────────────┐
//! │  Chain Abstraction Layer (evm-provider)                      │
//! │  └─ ChainProvider: unified interface to any EVM chain        │
//! └──────────────────────────────────────────────────────────────┘
//! ```
//!
//! # Core Concepts
//!
//! ## Wallets
//!
//! [`WalletState`](wallet::WalletState) tracks everything about a managed wallet:
//! - Balances (native and tokens)
//! - Transaction nonce
//! - Plugin-specific state (positions, rewards, etc.)
//! - Timing (last action, next scheduled action)
//! - Health (active, error count, AFK status)
//!
//! ## Profiles
//!
//! [`BehaviorProfile`](profiles::BehaviorProfile) defines how a wallet behaves:
//! - Risk tolerance (conservative whale vs aggressive degen)
//! - Activity level (actions per hour)
//! - Active hours and off-hours behavior
//! - AFK probability and duration
//!
//! Built-in profiles: `whale`, `grinder`, `degen`, `casual`, `sniper`
//!
//! ## Plugins
//!
//! [`ActionPlugin`](plugins::ActionPlugin) is the trait for protocol-specific logic:
//! - `decide_action`: examine wallet state, decide what to do
//! - `execute_action`: build and submit transaction
//! - `read_state`: query chain for protocol-specific state
//!
//! Plugins are registered in a [`PluginRegistry`](plugins::PluginRegistry).
//!
//! ## Safety
//!
//! [`CircuitBreaker`](safety::CircuitBreaker) protects wallets from cascading failures:
//! - Trips after N consecutive errors
//! - Auto-resets after cooldown period
//! - Per-wallet granularity
//!
//! ## Scheduling
//!
//! [`Scheduler`](scheduler::Scheduler) manages action timing:
//! - Profile-based intervals
//! - Random jitter for natural variation
//! - Active hours consideration
//!
//! # Example Usage
//!
//! ```ignore
//! use fleet_core::{
//!     wallet::WalletState,
//!     profiles::BehaviorProfile,
//!     plugins::{PluginRegistry, ActionPlugin},
//!     safety::CircuitBreaker,
//!     scheduler::Scheduler,
//! };
//!
//! // Create a wallet with a profile
//! let wallet = WalletState::with_profile(
//!     "whale_1".to_string(),
//!     address,
//!     "whale".to_string(),
//! );
//!
//! // Set up safety mechanisms
//! let mut breaker = CircuitBreaker::new(5, Duration::from_secs(3600));
//!
//! // Create scheduler
//! let mut scheduler = Scheduler::new();
//!
//! // Main loop (simplified)
//! loop {
//!     // Check if wallet is ready
//!     if !wallet.is_active() || !wallet.is_due() {
//!         continue;
//!     }
//!     
//!     // Check circuit breaker
//!     if breaker.is_tripped(&wallet.id) {
//!         continue;
//!     }
//!     
//!     // Decide and execute action via plugins
//!     // ...
//!     
//!     // Schedule next action
//!     let profile = BehaviorProfile::whale();
//!     let next = scheduler.calculate_next_action(&profile);
//! }
//! ```
//!
//! # Feature Flags
//!
//! This crate has no optional features - all functionality is always available.

#![doc(html_root_url = "https://docs.ghostnet.io/fleet-core")]

// ═══════════════════════════════════════════════════════════════════════════════
// MODULES
// ═══════════════════════════════════════════════════════════════════════════════

pub mod error;
pub mod metrics;
pub mod plugins;
pub mod profiles;
pub mod safety;
pub mod scheduler;
pub mod wallet;

// ═══════════════════════════════════════════════════════════════════════════════
// RE-EXPORTS
// ═══════════════════════════════════════════════════════════════════════════════

// Error types
pub use error::{FleetError, Result};

// Wallet
pub use wallet::WalletState;

// Profiles
pub use profiles::BehaviorProfile;

// Plugins
pub use plugins::{Action, ActionId, ActionPlugin, ActionResult, PluginContext, PluginRegistry};

// Safety
pub use safety::CircuitBreaker;

// Scheduler
pub use scheduler::Scheduler;

// Metrics
pub use metrics::{ActionMetrics, FleetMetrics, FleetSnapshot};

// ═══════════════════════════════════════════════════════════════════════════════
// PRELUDE
// ═══════════════════════════════════════════════════════════════════════════════

/// Convenience re-exports for common use.
///
/// ```ignore
/// use fleet_core::prelude::*;
/// ```
pub mod prelude {
    pub use crate::error::{FleetError, Result};
    pub use crate::metrics::{ActionMetrics, FleetMetrics};
    pub use crate::plugins::{Action, ActionId, ActionPlugin, ActionResult, PluginRegistry};
    pub use crate::profiles::BehaviorProfile;
    pub use crate::safety::CircuitBreaker;
    pub use crate::scheduler::Scheduler;
    pub use crate::wallet::WalletState;
}

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

    #[test]
    fn prelude_works() {
        use crate::prelude::*;

        let _profile = BehaviorProfile::whale();
        let _wallet = WalletState::new("test".into(), alloy::primitives::Address::ZERO);
        let _registry = PluginRegistry::new();
        let _breaker = CircuitBreaker::new(5, std::time::Duration::from_secs(3600));
        let _scheduler = Scheduler::new();
        let _metrics = FleetMetrics::new();
    }
}
