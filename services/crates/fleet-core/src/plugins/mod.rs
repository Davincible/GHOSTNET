//! Plugin system for extensible action handling.
//!
//! Plugins encapsulate protocol-specific logic (e.g., GHOSTNET staking,
//! DEX swaps) behind a common interface. This allows the orchestrator to
//! manage multiple protocols without knowing their implementation details.
//!
//! # Architecture
//!
//! ```text
//! ┌─────────────────────────────────────────────────────────────┐
//! │                     Orchestrator                             │
//! │  • Manages wallets                                          │
//! │  • Calls plugins to decide and execute actions              │
//! └─────────────────────────────────────────────────────────────┘
//!                              │
//!                              │ uses
//!                              ▼
//! ┌─────────────────────────────────────────────────────────────┐
//! │                   PluginRegistry                             │
//! │  • Stores registered plugins                                │
//! │  • Routes actions to correct plugin                         │
//! └─────────────────────────────────────────────────────────────┘
//!                              │
//!          ┌───────────────────┼───────────────────┐
//!          │                   │                   │
//!          ▼                   ▼                   ▼
//! ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
//! │  GhostnetPlugin │ │   SwapPlugin    │ │  BridgePlugin   │
//! │                 │ │                 │ │                 │
//! │  • jack_in      │ │  • swap         │ │  • bridge       │
//! │  • extract      │ │  • add_liq      │ │  • withdraw     │
//! │  • hashcrash    │ │                 │ │                 │
//! └─────────────────┘ └─────────────────┘ └─────────────────┘
//! ```
//!
//! # Implementing a Plugin
//!
//! ```ignore
//! use fleet_core::plugins::{ActionPlugin, Action, ActionId, ActionResult, PluginContext};
//! use fleet_core::wallet::WalletState;
//! use fleet_core::profiles::BehaviorProfile;
//! use async_trait::async_trait;
//!
//! #[derive(Debug)]
//! struct MyPlugin { /* ... */ }
//!
//! #[async_trait]
//! impl ActionPlugin for MyPlugin {
//!     fn id(&self) -> &str { "my_plugin" }
//!     fn name(&self) -> &str { "My Protocol Plugin" }
//!     
//!     fn available_actions(&self) -> Vec<ActionId> {
//!         vec![ActionId::new("my_plugin.stake")]
//!     }
//!     
//!     async fn decide_action(
//!         &self,
//!         wallet: &WalletState,
//!         profile: &BehaviorProfile,
//!         context: &mut PluginContext<'_>,
//!     ) -> fleet_core::error::Result<Option<Action>> {
//!         // Check conditions based on wallet state and profile
//!         // Return Some(Action) to act, None to skip
//!         Ok(None)
//!     }
//!     
//!     async fn execute_action(
//!         &self,
//!         action: &Action,
//!         wallet: &WalletState,
//!         nonce: u64,
//!     ) -> fleet_core::error::Result<ActionResult> {
//!         // Build transaction, sign, submit
//!         Ok(ActionResult::failure("not implemented"))
//!     }
//!     
//!     async fn read_state(&self, address: alloy::primitives::Address)
//!         -> fleet_core::error::Result<serde_json::Value>
//!     {
//!         // Query chain for plugin-specific state
//!         Ok(serde_json::Value::Null)
//!     }
//! }
//! ```

mod registry;
mod traits;

pub use registry::PluginRegistry;
pub use traits::{Action, ActionId, ActionPlugin, ActionResult, PluginContext};
