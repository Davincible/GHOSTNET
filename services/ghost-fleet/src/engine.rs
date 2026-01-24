//! Behavior engine for coordinating plugin decisions.
//!
//! The behavior engine is responsible for:
//! - Selecting which plugin should act for a given wallet
//! - Providing context for decision-making (RNG, timestamp, config)
//! - Recording metrics for actions

use std::sync::Arc;

use chrono::Utc;
use fleet_core::plugins::{Action, ActionPlugin, PluginContext, PluginRegistry};
use fleet_core::profiles::BehaviorProfile;
use fleet_core::wallet::WalletState;
use rand::rngs::StdRng;
use rand::SeedableRng;
use tracing::{debug, instrument};

// ═══════════════════════════════════════════════════════════════════════════════
// BEHAVIOR ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

/// Coordinates plugin decisions for wallet actions.
#[derive(Debug)]
pub struct BehaviorEngine {
    /// Enabled plugins in priority order.
    plugins: Vec<Arc<dyn ActionPlugin>>,

    /// Random number generator.
    rng: StdRng,

    /// Plugin-specific configuration.
    plugin_config: serde_json::Value,
}

impl BehaviorEngine {
    /// Create a new behavior engine with the given plugins.
    #[must_use]
    pub fn new(registry: &PluginRegistry, enabled_ids: &[String]) -> Self {
        let plugins = registry.enabled(enabled_ids);
        Self {
            plugins,
            rng: StdRng::from_os_rng(),
            plugin_config: serde_json::Value::Null,
        }
    }

    /// Create a behavior engine with a seeded RNG (for testing).
    #[must_use]
    #[allow(dead_code)] // Public API for tests
    pub fn with_seed(registry: &PluginRegistry, enabled_ids: &[String], seed: u64) -> Self {
        let plugins = registry.enabled(enabled_ids);
        Self {
            plugins,
            rng: StdRng::seed_from_u64(seed),
            plugin_config: serde_json::Value::Null,
        }
    }

    /// Set plugin-specific configuration.
    #[allow(dead_code)] // Public API for future use
    pub fn set_plugin_config(&mut self, config: serde_json::Value) {
        self.plugin_config = config;
    }

    /// Decide what action (if any) a wallet should take.
    ///
    /// Iterates through enabled plugins in priority order, asking each
    /// to decide an action. Returns the first action decided, along with
    /// the plugin that decided it.
    ///
    /// # Arguments
    ///
    /// * `wallet` - Current wallet state
    /// * `profile` - Behavior profile for this wallet
    ///
    /// # Returns
    ///
    /// `Some((plugin, action))` if a plugin decided an action, `None` otherwise.
    #[instrument(skip(self, wallet, profile), fields(wallet_id = %wallet.id))]
    pub async fn decide_action(
        &mut self,
        wallet: &WalletState,
        profile: &BehaviorProfile,
    ) -> Option<(Arc<dyn ActionPlugin>, Action)> {
        let mut context = PluginContext::new(Utc::now(), &mut self.rng, &self.plugin_config);

        for plugin in &self.plugins {
            debug!(plugin_id = plugin.id(), "Checking plugin for action");

            match plugin.decide_action(wallet, profile, &mut context).await {
                Ok(Some(action)) => {
                    debug!(
                        plugin_id = plugin.id(),
                        action_id = %action.id,
                        "Plugin decided action"
                    );
                    return Some((Arc::clone(plugin), action));
                }
                Ok(None) => {
                    debug!(plugin_id = plugin.id(), "Plugin decided no action");
                }
                Err(e) => {
                    tracing::warn!(
                        plugin_id = plugin.id(),
                        error = %e,
                        "Plugin error during decision"
                    );
                }
            }
        }

        None
    }

    /// Get the list of enabled plugins.
    #[must_use]
    pub fn plugins(&self) -> &[Arc<dyn ActionPlugin>] {
        &self.plugins
    }

    /// Get all available actions across enabled plugins.
    #[must_use]
    #[allow(dead_code)] // Public API for future use
    pub fn available_actions(&self) -> Vec<fleet_core::plugins::ActionId> {
        self.plugins
            .iter()
            .flat_map(|p| p.available_actions())
            .collect()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn engine_with_empty_registry() {
        let registry = PluginRegistry::new();
        let engine = BehaviorEngine::new(&registry, &[]);

        assert!(engine.plugins().is_empty());
        assert!(engine.available_actions().is_empty());
    }
}
