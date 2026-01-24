//! Wallet state tracking.
//!
//! This module provides [`WalletState`], a struct that tracks all relevant
//! state for a managed wallet including balances, nonces, and plugin-specific data.

use std::collections::HashMap;

use alloy::primitives::{Address, U256};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

// ═══════════════════════════════════════════════════════════════════════════════
// WALLET STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Complete state for a managed wallet.
///
/// This struct tracks everything needed to make decisions about wallet actions:
/// - Balances (native and tokens)
/// - Nonce for transaction ordering
/// - Plugin-specific state (positions, pending actions, etc.)
/// - Timing information (last action, next scheduled action)
/// - Health status (active, error count, AFK)
///
/// # Plugin State
///
/// Plugins can store arbitrary JSON data in [`plugin_states`](Self::plugin_states).
/// This allows plugins to track protocol-specific information (e.g., current
/// positions, pending rewards) without modifying the core wallet state structure.
///
/// # Example
///
/// ```
/// use fleet_core::wallet::WalletState;
/// use alloy::primitives::Address;
///
/// let wallet = WalletState::new("wallet_1".to_string(), Address::ZERO);
/// assert!(wallet.is_active());
/// assert!(!wallet.is_afk());
/// ```
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WalletState {
    /// Unique identifier for this wallet (e.g., "whale_1", "grinder_42").
    pub id: String,

    /// Ethereum address of the wallet.
    pub address: Address,

    /// Native token balance (ETH) in wei.
    pub native_balance: U256,

    /// Token balances by token address.
    ///
    /// Keys are token contract addresses, values are balances in the token's
    /// smallest unit (e.g., wei for 18-decimal tokens).
    pub token_balances: HashMap<Address, U256>,

    /// Current confirmed nonce (transaction count).
    ///
    /// This is synced from the chain and incremented locally after each
    /// successful transaction.
    pub nonce: u64,

    /// Plugin-specific state data.
    ///
    /// Keys are plugin IDs (e.g., "ghostnet"), values are arbitrary JSON.
    /// Plugins are responsible for serializing/deserializing their own state.
    pub plugin_states: HashMap<String, serde_json::Value>,

    /// Timestamp of last successful action.
    pub last_action: Option<DateTime<Utc>>,

    /// When the next action should be considered.
    ///
    /// The scheduler uses this to determine when to check this wallet again.
    pub next_action: DateTime<Utc>,

    /// Whether the wallet is active (enabled for actions).
    ///
    /// Set to `false` to temporarily disable a wallet without removing it.
    pub active: bool,

    /// Count of consecutive errors.
    ///
    /// Reset to 0 after each successful action. Used by circuit breaker to
    /// determine when to disable a wallet.
    pub consecutive_errors: u32,

    /// If set, wallet is "away" and should not act until this time.
    ///
    /// Used to simulate natural user behavior where wallets go inactive
    /// for periods of time.
    pub afk_until: Option<DateTime<Utc>>,

    /// Name of the behavior profile assigned to this wallet.
    ///
    /// References a profile in the configuration (e.g., "whale", "degen").
    pub profile_name: String,
}

impl WalletState {
    /// Create a new wallet state with default values.
    ///
    /// The wallet starts active with zero balances and no scheduled actions.
    /// You should call [`refresh_from_chain`](Self::refresh_from_chain) to
    /// populate actual balances.
    #[must_use]
    pub fn new(id: String, address: Address) -> Self {
        Self {
            id,
            address,
            native_balance: U256::ZERO,
            token_balances: HashMap::new(),
            nonce: 0,
            plugin_states: HashMap::new(),
            last_action: None,
            next_action: Utc::now(),
            active: true,
            consecutive_errors: 0,
            afk_until: None,
            profile_name: String::new(),
        }
    }

    /// Create a wallet state with a specific profile.
    #[must_use]
    pub fn with_profile(id: String, address: Address, profile_name: String) -> Self {
        let mut state = Self::new(id, address);
        state.profile_name = profile_name;
        state
    }

    /// Check if the wallet is currently AFK (away from keyboard).
    ///
    /// Returns `true` if `afk_until` is set and is in the future.
    #[must_use]
    pub fn is_afk(&self) -> bool {
        self.afk_until
            .is_some_and(|until| Utc::now() < until)
    }

    /// Check if the wallet is active and ready to act.
    ///
    /// Returns `true` if the wallet is active and not AFK.
    #[must_use]
    pub fn is_active(&self) -> bool {
        self.active && !self.is_afk()
    }

    /// Check if it's time for this wallet to consider an action.
    ///
    /// Returns `true` if the current time is at or past `next_action`.
    #[must_use]
    pub fn is_due(&self) -> bool {
        Utc::now() >= self.next_action
    }

    /// Get the balance of a specific token.
    ///
    /// Returns `U256::ZERO` if the token is not tracked.
    #[must_use]
    pub fn token_balance(&self, token: Address) -> U256 {
        self.token_balances.get(&token).copied().unwrap_or(U256::ZERO)
    }

    /// Get plugin-specific state.
    ///
    /// Returns `None` if no state exists for the given plugin.
    #[must_use]
    pub fn plugin_state(&self, plugin_id: &str) -> Option<&serde_json::Value> {
        self.plugin_states.get(plugin_id)
    }

    /// Get plugin-specific state, deserialized to a specific type.
    ///
    /// Returns `None` if no state exists or deserialization fails.
    pub fn plugin_state_as<T: serde::de::DeserializeOwned>(&self, plugin_id: &str) -> Option<T> {
        self.plugin_states
            .get(plugin_id)
            .and_then(|v| serde_json::from_value(v.clone()).ok())
    }

    /// Set plugin-specific state.
    pub fn set_plugin_state(&mut self, plugin_id: &str, state: serde_json::Value) {
        self.plugin_states.insert(plugin_id.to_string(), state);
    }

    /// Set plugin-specific state from a serializable value.
    ///
    /// # Errors
    ///
    /// Returns an error if serialization fails.
    pub fn set_plugin_state_from<T: Serialize>(
        &mut self,
        plugin_id: &str,
        state: &T,
    ) -> Result<(), serde_json::Error> {
        let value = serde_json::to_value(state)?;
        self.set_plugin_state(plugin_id, value);
        Ok(())
    }

    /// Record a successful action.
    ///
    /// Resets error count and updates last action timestamp.
    pub fn record_success(&mut self) {
        self.consecutive_errors = 0;
        self.last_action = Some(Utc::now());
    }

    /// Record a failed action.
    ///
    /// Increments consecutive error count.
    pub const fn record_error(&mut self) {
        self.consecutive_errors = self.consecutive_errors.saturating_add(1);
    }

    /// Set the wallet as AFK until the specified time.
    pub const fn set_afk(&mut self, until: DateTime<Utc>) {
        self.afk_until = Some(until);
    }

    /// Clear AFK status.
    pub const fn clear_afk(&mut self) {
        self.afk_until = None;
    }

    /// Schedule the next action at the specified time.
    pub const fn schedule_next(&mut self, at: DateTime<Utc>) {
        self.next_action = at;
    }

    /// Update native balance.
    pub const fn set_native_balance(&mut self, balance: U256) {
        self.native_balance = balance;
    }

    /// Update token balance.
    pub fn set_token_balance(&mut self, token: Address, balance: U256) {
        self.token_balances.insert(token, balance);
    }

    /// Update nonce.
    pub const fn set_nonce(&mut self, nonce: u64) {
        self.nonce = nonce;
    }

    /// Increment nonce by 1.
    ///
    /// Call this after successfully sending a transaction.
    pub const fn increment_nonce(&mut self) {
        self.nonce = self.nonce.saturating_add(1);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Duration;

    #[test]
    fn new_wallet_is_active() {
        let wallet = WalletState::new("test".into(), Address::ZERO);
        assert!(wallet.is_active());
        assert!(!wallet.is_afk());
        assert_eq!(wallet.native_balance, U256::ZERO);
    }

    #[test]
    fn afk_status() {
        let mut wallet = WalletState::new("test".into(), Address::ZERO);

        // Set AFK in the future
        wallet.set_afk(Utc::now() + Duration::hours(1));
        assert!(wallet.is_afk());
        assert!(!wallet.is_active());

        // Set AFK in the past
        wallet.set_afk(Utc::now() - Duration::hours(1));
        assert!(!wallet.is_afk());
        assert!(wallet.is_active());

        // Clear AFK
        wallet.set_afk(Utc::now() + Duration::hours(1));
        wallet.clear_afk();
        assert!(!wallet.is_afk());
    }

    #[test]
    fn error_tracking() {
        let mut wallet = WalletState::new("test".into(), Address::ZERO);

        wallet.record_error();
        wallet.record_error();
        assert_eq!(wallet.consecutive_errors, 2);

        wallet.record_success();
        assert_eq!(wallet.consecutive_errors, 0);
        assert!(wallet.last_action.is_some());
    }

    #[test]
    fn token_balance() {
        let mut wallet = WalletState::new("test".into(), Address::ZERO);
        let token = Address::repeat_byte(0xAA);

        assert_eq!(wallet.token_balance(token), U256::ZERO);

        wallet.set_token_balance(token, U256::from(1000));
        assert_eq!(wallet.token_balance(token), U256::from(1000));
    }

    #[test]
    fn plugin_state() {
        let mut wallet = WalletState::new("test".into(), Address::ZERO);

        #[derive(Debug, Serialize, Deserialize, PartialEq)]
        struct TestState {
            value: u64,
        }

        let state = TestState { value: 42 };
        wallet
            .set_plugin_state_from("test_plugin", &state)
            .expect("serialization should work");

        let retrieved: TestState = wallet
            .plugin_state_as("test_plugin")
            .expect("should have state");
        assert_eq!(retrieved, state);

        assert!(wallet.plugin_state_as::<TestState>("nonexistent").is_none());
    }

    #[test]
    fn scheduling() {
        let mut wallet = WalletState::new("test".into(), Address::ZERO);

        // Initially due (next_action is now or past)
        assert!(wallet.is_due());

        // Schedule in future
        wallet.schedule_next(Utc::now() + Duration::hours(1));
        assert!(!wallet.is_due());

        // Schedule in past
        wallet.schedule_next(Utc::now() - Duration::hours(1));
        assert!(wallet.is_due());
    }
}
