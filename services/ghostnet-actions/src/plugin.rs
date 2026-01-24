//! GHOSTNET plugin implementation.
//!
//! This module provides the [`GhostnetPlugin`] which implements the
//! [`ActionPlugin`](fleet_core::ActionPlugin) trait.

use std::sync::Arc;

use alloy::primitives::{Address, Bytes, U256};
use async_trait::async_trait;
use evm_provider::ChainProvider;
use fleet_core::plugins::{Action, ActionId, ActionPlugin, ActionResult, PluginContext};
use fleet_core::profiles::BehaviorProfile;
use fleet_core::wallet::WalletState;
use tracing::{debug, info, instrument, warn};

use crate::actions::ghost_core::{
    ACTION_ADD_STAKE, ACTION_CLAIM_REWARDS, ACTION_EXTRACT, ACTION_JACK_IN,
};
use crate::actions::hashcrash::ACTION_HASHCRASH_BET;
use crate::actions::{GhostCoreDecider, HashCrashDecider};
use crate::config::GhostnetConfig;
use crate::contracts::GhostnetContracts;
use crate::error::{GhostnetError, Result};
use crate::state::{GhostnetState, Level};

// ═══════════════════════════════════════════════════════════════════════════════
// GHOSTNET PLUGIN
// ═══════════════════════════════════════════════════════════════════════════════

/// GHOSTNET protocol action plugin.
///
/// This plugin implements the `ActionPlugin` trait for GHOSTNET protocol
/// interactions, including GhostCore staking and HashCrash arcade games.
///
/// # Actions
///
/// - `ghostnet.jack_in`: Enter a new staking position
/// - `ghostnet.add_stake`: Add to existing position
/// - `ghostnet.extract`: Exit position and claim rewards
/// - `ghostnet.claim_rewards`: Claim pending rewards
/// - `ghostnet.hashcrash_bet`: Place a bet in HashCrash
///
/// # Example
///
/// ```ignore
/// use ghostnet_actions::{GhostnetPlugin, GhostnetConfig};
/// use evm_provider::MegaEthProvider;
///
/// let config = GhostnetConfig::testnet();
/// let provider = Arc::new(MegaEthProvider::new("https://rpc.megaeth.com", 6343)?);
/// let plugin = GhostnetPlugin::new(config, provider);
/// ```
pub struct GhostnetPlugin<P: ChainProvider> {
    /// Configuration.
    config: GhostnetConfig,

    /// Contract addresses and calldata builders.
    contracts: GhostnetContracts,

    /// Chain provider.
    provider: Arc<P>,
}

impl<P: ChainProvider> std::fmt::Debug for GhostnetPlugin<P> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("GhostnetPlugin")
            .field("config", &self.config)
            .field("contracts", &self.contracts)
            .finish_non_exhaustive()
    }
}

impl<P: ChainProvider> GhostnetPlugin<P> {
    /// Create a new GHOSTNET plugin.
    #[must_use]
    #[allow(clippy::missing_const_for_fn)] // from_config isn't const
    pub fn new(config: GhostnetConfig, provider: Arc<P>) -> Self {
        let contracts = GhostnetContracts::from_config(&config);
        Self {
            config,
            contracts,
            provider,
        }
    }

    /// Get the plugin configuration.
    #[must_use]
    pub const fn config(&self) -> &GhostnetConfig {
        &self.config
    }

    /// Get the contract addresses.
    #[must_use]
    pub const fn contracts(&self) -> &GhostnetContracts {
        &self.contracts
    }

    /// Get the chain provider.
    #[must_use]
    pub const fn provider(&self) -> &Arc<P> {
        &self.provider
    }

    /// Parse GHOSTNET state from wallet plugin state.
    fn parse_state(wallet: &WalletState) -> GhostnetState {
        wallet
            .plugin_state_as::<GhostnetState>("ghostnet")
            .unwrap_or_default()
    }

    /// Build transaction for an action.
    fn build_tx(&self, action: &Action, _wallet: &WalletState) -> Result<(Address, Bytes, U256)> {
        match action.id.as_str() {
            ACTION_JACK_IN => {
                let amount = Self::parse_amount(&action.data, "amount")?;
                let level_u8 = Self::parse_level(&action.data)?;
                let level =
                    Level::from_u8(level_u8).ok_or(GhostnetError::InvalidLevel(level_u8))?;

                let calldata = self.contracts.encode_jack_in(amount, level);
                Ok((self.contracts.ghost_core, calldata, U256::ZERO))
            }
            ACTION_ADD_STAKE => {
                let amount = Self::parse_amount(&action.data, "amount")?;
                let calldata = self.contracts.encode_add_stake(amount);
                Ok((self.contracts.ghost_core, calldata, U256::ZERO))
            }
            ACTION_EXTRACT => {
                let calldata = self.contracts.encode_extract();
                Ok((self.contracts.ghost_core, calldata, U256::ZERO))
            }
            ACTION_CLAIM_REWARDS => {
                let calldata = self.contracts.encode_claim_rewards();
                Ok((self.contracts.ghost_core, calldata, U256::ZERO))
            }
            ACTION_HASHCRASH_BET => {
                let amount = Self::parse_amount(&action.data, "amount")?;
                let target = action.data["target_multiplier"]
                    .as_u64()
                    .ok_or_else(|| GhostnetError::InvalidActionData("missing target_multiplier".into()))?;

                #[allow(clippy::cast_possible_truncation)]
                let target_u16 = target as u16;

                // Ensure ArcadeCore has approval
                // Note: In production, this would check and potentially approve first
                let calldata = self.contracts.encode_hashcrash_bet(amount, target_u16);
                Ok((self.contracts.hash_crash, calldata, U256::ZERO))
            }
            _ => Err(GhostnetError::InvalidActionData(format!(
                "unknown action: {}",
                action.id
            ))),
        }
    }

    /// Parse amount from action data.
    fn parse_amount(data: &serde_json::Value, field: &str) -> Result<U256> {
        data[field]
            .as_str()
            .ok_or_else(|| GhostnetError::InvalidActionData(format!("missing {field}")))?
            .parse()
            .map_err(|_| GhostnetError::InvalidActionData(format!("invalid {field}")))
    }

    /// Parse level from action data.
    fn parse_level(data: &serde_json::Value) -> Result<u8> {
        data["level"]
            .as_u64()
            .and_then(|l| u8::try_from(l).ok())
            .ok_or_else(|| GhostnetError::InvalidActionData("missing or invalid level".into()))
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION PLUGIN IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════

#[async_trait]
impl<P: ChainProvider> ActionPlugin for GhostnetPlugin<P> {
    #[allow(clippy::unnecessary_literal_bound)] // Trait signature defines `&str`
    fn id(&self) -> &str {
        "ghostnet"
    }

    #[allow(clippy::unnecessary_literal_bound)] // Trait signature defines `&str`
    fn name(&self) -> &str {
        "GHOSTNET Protocol"
    }

    fn available_actions(&self) -> Vec<ActionId> {
        vec![
            ActionId::new(ACTION_JACK_IN),
            ActionId::new(ACTION_ADD_STAKE),
            ActionId::new(ACTION_EXTRACT),
            ActionId::new(ACTION_CLAIM_REWARDS),
            ActionId::new(ACTION_HASHCRASH_BET),
        ]
    }

    #[instrument(skip(self, wallet, context), fields(wallet_id = %wallet.id))]
    async fn decide_action(
        &self,
        wallet: &WalletState,
        profile: &BehaviorProfile,
        context: &mut PluginContext<'_>,
    ) -> fleet_core::Result<Option<Action>> {
        let state = Self::parse_state(wallet);

        // Try GhostCore actions first (higher priority)
        if let Some(action) =
            GhostCoreDecider::decide(&state, profile, &self.config.behavior, context)
        {
            debug!(action = %action.id, "GhostCore action decided");
            return Ok(Some(action));
        }

        // Try HashCrash actions
        if let Some(action) =
            HashCrashDecider::decide(&state, profile, &self.config.behavior, context)
        {
            debug!(action = %action.id, "HashCrash action decided");
            return Ok(Some(action));
        }

        Ok(None)
    }

    #[instrument(skip(self, action, wallet), fields(
        wallet_id = %wallet.id,
        action_id = %action.id,
    ))]
    async fn execute_action(
        &self,
        action: &Action,
        wallet: &WalletState,
        nonce: u64,
    ) -> fleet_core::Result<ActionResult> {
        info!(action = %action.name, "Executing GHOSTNET action");

        // Build transaction
        let (to, data, value) = self
            .build_tx(action, wallet)
            .map_err(|e| fleet_core::FleetError::PluginExecution(e.to_string()))?;

        // TODO: Sign and send transaction using wallet's signer
        // For now, we just return a placeholder error indicating the transaction
        // needs to be submitted by the orchestrator with proper signing

        // In production, this would:
        // 1. Check and ensure token approval if needed
        // 2. Build the full transaction with gas estimation
        // 3. Sign with the wallet's signer
        // 4. Submit via provider.send_raw_transaction()
        // 5. Wait for receipt

        warn!(
            to = %to,
            data_len = data.len(),
            value = %value,
            nonce = nonce,
            "Transaction built but not submitted (signing not implemented)"
        );

        // Return failure for now - the orchestrator needs to handle signing
        Ok(ActionResult::failure(
            "Transaction signing not implemented in plugin - use build_transaction()",
        ))
    }

    #[instrument(skip(self), fields(address = %_address))]
    async fn read_state(&self, _address: Address) -> fleet_core::Result<serde_json::Value> {
        debug!("Reading GHOSTNET state");

        // In production, this would call the contract view functions:
        // - GhostCore.getPosition(address)
        // - GhostCore.getPendingRewards(address)
        // - GhostCore.getEffectiveDeathRate(address)
        // - DataToken.balanceOf(address)
        // - DataToken.allowance(address, ghost_core)
        // - HashCrash.getCurrentRound()

        // For now, return empty state
        let state = GhostnetState::default();

        serde_json::to_value(state).map_err(fleet_core::FleetError::Serialization)
    }

    async fn build_transaction(
        &self,
        action: &Action,
        wallet: &WalletState,
        _nonce: u64,
    ) -> fleet_core::Result<Bytes> {
        let (to, data, value) = self
            .build_tx(action, wallet)
            .map_err(|e| fleet_core::FleetError::PluginExecution(e.to_string()))?;

        // Return just the calldata - the orchestrator will build the full transaction
        debug!(
            to = %to,
            value = %value,
            data_len = data.len(),
            "Built transaction calldata"
        );

        Ok(data)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;
    use evm_provider::mock::MockProvider;

    fn test_plugin() -> GhostnetPlugin<MockProvider> {
        let config = GhostnetConfig::testnet();
        let provider = Arc::new(MockProvider::new());
        GhostnetPlugin::new(config, provider)
    }

    #[test]
    fn plugin_id_and_name() {
        let plugin = test_plugin();
        assert_eq!(plugin.id(), "ghostnet");
        assert_eq!(plugin.name(), "GHOSTNET Protocol");
    }

    #[test]
    fn available_actions() {
        let plugin = test_plugin();
        let actions = plugin.available_actions();

        assert!(actions.iter().any(|a| a.as_str() == ACTION_JACK_IN));
        assert!(actions.iter().any(|a| a.as_str() == ACTION_ADD_STAKE));
        assert!(actions.iter().any(|a| a.as_str() == ACTION_EXTRACT));
        assert!(actions.iter().any(|a| a.as_str() == ACTION_HASHCRASH_BET));
    }

    #[test]
    fn build_jack_in_tx() {
        let plugin = test_plugin();
        let wallet = WalletState::new("test".into(), Address::ZERO);

        let action = Action::with_data(
            ACTION_JACK_IN,
            "Jack In",
            serde_json::json!({
                "amount": "1000000000000000000",
                "level": 3,
            }),
        );

        let result = plugin.build_tx(&action, &wallet);
        assert!(result.is_ok());

        let (to, data, value) = result.unwrap();
        assert_eq!(to, plugin.contracts.ghost_core);
        assert!(!data.is_empty());
        assert_eq!(value, U256::ZERO);
    }

    #[test]
    fn build_extract_tx() {
        let plugin = test_plugin();
        let wallet = WalletState::new("test".into(), Address::ZERO);

        let action = Action::new(ACTION_EXTRACT, "Extract");

        let result = plugin.build_tx(&action, &wallet);
        assert!(result.is_ok());

        let (to, data, _value) = result.unwrap();
        assert_eq!(to, plugin.contracts.ghost_core);
        assert_eq!(data.len(), 4); // Just function selector
    }

    #[test]
    fn build_hashcrash_tx() {
        let plugin = test_plugin();
        let wallet = WalletState::new("test".into(), Address::ZERO);

        let action = Action::with_data(
            ACTION_HASHCRASH_BET,
            "HashCrash Bet",
            serde_json::json!({
                "amount": "1000000000000000000",
                "target_multiplier": 200,
            }),
        );

        let result = plugin.build_tx(&action, &wallet);
        assert!(result.is_ok());

        let (to, data, _value) = result.unwrap();
        assert_eq!(to, plugin.contracts.hash_crash);
        assert!(!data.is_empty());
    }
}
