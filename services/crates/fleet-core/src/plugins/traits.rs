//! Plugin trait definitions.
//!
//! This module defines the [`ActionPlugin`] trait that all action plugins must implement.

use std::fmt::Debug;

use alloy::primitives::{Address, Bytes, TxHash};
use async_trait::async_trait;

use crate::error::Result;
use crate::profiles::BehaviorProfile;
use crate::wallet::WalletState;

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Unique identifier for an action type.
///
/// Format is typically `plugin_id.action_name`, e.g., "ghostnet.jack_in".
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct ActionId(pub String);

impl ActionId {
    /// Create a new action ID.
    #[must_use]
    pub fn new(id: impl Into<String>) -> Self {
        Self(id.into())
    }

    /// Get the action ID as a string slice.
    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl std::fmt::Display for ActionId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl From<&str> for ActionId {
    fn from(s: &str) -> Self {
        Self(s.to_string())
    }
}

impl From<String> for ActionId {
    fn from(s: String) -> Self {
        Self(s)
    }
}

/// An action that can be executed on-chain.
///
/// Actions are created by plugins during the decision phase and executed
/// by the orchestrator.
#[derive(Debug, Clone)]
pub struct Action {
    /// Unique identifier for this action type.
    pub id: ActionId,

    /// Human-readable name for logging/display.
    pub name: String,

    /// Action-specific data (plugin interprets this).
    pub data: serde_json::Value,
}

impl Action {
    /// Create a new action.
    #[must_use]
    pub fn new(id: impl Into<ActionId>, name: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            name: name.into(),
            data: serde_json::Value::Null,
        }
    }

    /// Create an action with data.
    #[must_use]
    pub fn with_data(id: impl Into<ActionId>, name: impl Into<String>, data: serde_json::Value) -> Self {
        Self {
            id: id.into(),
            name: name.into(),
            data,
        }
    }
}

/// Result of executing an action.
#[derive(Debug, Clone)]
pub struct ActionResult {
    /// Whether the action was successful.
    pub success: bool,

    /// Transaction hash if a transaction was sent.
    pub tx_hash: Option<TxHash>,

    /// Gas used if known.
    pub gas_used: Option<u64>,

    /// Error message if the action failed.
    pub error: Option<String>,
}

impl ActionResult {
    /// Create a successful result.
    #[must_use]
    pub const fn success(tx_hash: TxHash) -> Self {
        Self {
            success: true,
            tx_hash: Some(tx_hash),
            gas_used: None,
            error: None,
        }
    }

    /// Create a successful result with gas info.
    #[must_use]
    pub const fn success_with_gas(tx_hash: TxHash, gas_used: u64) -> Self {
        Self {
            success: true,
            tx_hash: Some(tx_hash),
            gas_used: Some(gas_used),
            error: None,
        }
    }

    /// Create a failed result.
    #[must_use]
    pub fn failure(error: impl Into<String>) -> Self {
        Self {
            success: false,
            tx_hash: None,
            gas_used: None,
            error: Some(error.into()),
        }
    }

    /// Create a failed result with a transaction that reverted.
    #[must_use]
    pub fn reverted(tx_hash: TxHash, error: impl Into<String>) -> Self {
        Self {
            success: false,
            tx_hash: Some(tx_hash),
            gas_used: None,
            error: Some(error.into()),
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PLUGIN CONTEXT
// ═══════════════════════════════════════════════════════════════════════════════

/// Context provided to plugins for decision-making.
///
/// This contains everything a plugin needs to make decisions without
/// having access to the orchestrator internals.
///
/// The RNG is `Send + Sync` to support async trait methods in a multi-threaded context.
pub struct PluginContext<'a> {
    /// Current timestamp.
    pub now: chrono::DateTime<chrono::Utc>,

    /// Random number generator for varied behavior.
    pub rng: &'a mut (dyn rand::RngCore + Send + Sync),

    /// Plugin-specific configuration (from config file).
    pub config: &'a serde_json::Value,
}

impl std::fmt::Debug for PluginContext<'_> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("PluginContext")
            .field("now", &self.now)
            .field("rng", &"<RngCore + Send + Sync>")
            .field("config", &self.config)
            .finish()
    }
}

impl<'a> PluginContext<'a> {
    /// Create a new plugin context.
    #[must_use]
    pub fn new(
        now: chrono::DateTime<chrono::Utc>,
        rng: &'a mut (dyn rand::RngCore + Send + Sync),
        config: &'a serde_json::Value,
    ) -> Self {
        Self { now, rng, config }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION PLUGIN TRAIT
// ═══════════════════════════════════════════════════════════════════════════════

/// Trait that all action plugins must implement.
///
/// Plugins encapsulate protocol-specific logic (e.g., GHOSTNET staking,
/// token swaps) while presenting a uniform interface to the orchestrator.
///
/// # Lifecycle
///
/// 1. **Registration**: Plugin is registered with the `PluginRegistry`
/// 2. **State Reading**: `read_state` is called to populate wallet's plugin state
/// 3. **Decision**: `decide_action` is called to determine what action to take
/// 4. **Execution**: `execute_action` is called to perform the chosen action
///
/// # Example Implementation
///
/// ```ignore
/// struct MyProtocolPlugin { /* ... */ }
///
/// #[async_trait]
/// impl ActionPlugin for MyProtocolPlugin {
///     fn id(&self) -> &str { "my_protocol" }
///     fn name(&self) -> &str { "My Protocol Plugin" }
///     
///     fn available_actions(&self) -> Vec<ActionId> {
///         vec![ActionId::new("my_protocol.stake")]
///     }
///     
///     async fn decide_action(...) -> Result<Option<Action>> {
///         // Check conditions and return an action or None
///     }
///     
///     async fn execute_action(...) -> Result<ActionResult> {
///         // Build and send transaction
///     }
/// }
/// ```
#[async_trait]
pub trait ActionPlugin: Send + Sync + Debug {
    /// Unique identifier for this plugin (e.g., "ghostnet", "uniswap").
    fn id(&self) -> &str;

    /// Human-readable name for this plugin.
    fn name(&self) -> &str;

    /// List of actions this plugin can perform.
    fn available_actions(&self) -> Vec<ActionId>;

    /// Decide what action (if any) this plugin wants to take.
    ///
    /// Called by the behavior engine. The plugin examines the wallet state
    /// and profile to decide whether to act and what action to take.
    ///
    /// # Arguments
    ///
    /// * `wallet` - Current wallet state including plugin-specific data
    /// * `profile` - Behavior profile for this wallet
    /// * `context` - Additional context (time, RNG, config)
    ///
    /// # Returns
    ///
    /// * `Ok(Some(action))` - Plugin wants to perform this action
    /// * `Ok(None)` - Plugin doesn't want to act right now
    /// * `Err(e)` - Error occurred during decision (logged, wallet continues)
    async fn decide_action(
        &self,
        wallet: &WalletState,
        profile: &BehaviorProfile,
        context: &mut PluginContext<'_>,
    ) -> Result<Option<Action>>;

    /// Execute an action.
    ///
    /// Called by the orchestrator after `decide_action` returns an action.
    /// The plugin should build the transaction, sign it, and submit it.
    ///
    /// # Arguments
    ///
    /// * `action` - The action to execute (created by `decide_action`)
    /// * `wallet` - Current wallet state
    /// * `nonce` - Nonce to use for the transaction
    ///
    /// # Returns
    ///
    /// Result containing success/failure info and transaction hash.
    async fn execute_action(
        &self,
        action: &Action,
        wallet: &WalletState,
        nonce: u64,
    ) -> Result<ActionResult>;

    /// Read current state relevant to this plugin.
    ///
    /// Called to refresh wallet state with plugin-specific data. The returned
    /// value is stored in `wallet.plugin_states[plugin_id]`.
    ///
    /// # Arguments
    ///
    /// * `address` - Wallet address to query
    ///
    /// # Returns
    ///
    /// Plugin-specific state as JSON.
    async fn read_state(&self, address: Address) -> Result<serde_json::Value>;

    /// Build transaction data for an action (optional).
    ///
    /// If implemented, returns the raw transaction data that would be sent.
    /// Useful for simulation and testing without actually sending.
    ///
    /// Default implementation returns an error indicating not implemented.
    async fn build_transaction(
        &self,
        _action: &Action,
        _wallet: &WalletState,
        _nonce: u64,
    ) -> Result<Bytes> {
        Err(crate::error::FleetError::PluginExecution(
            "build_transaction not implemented".into(),
        ))
    }
}
