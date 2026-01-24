//! Plugin registry for managing action plugins.
//!
//! The registry stores plugins and provides methods to query them by ID
//! or filter by enabled status.

use std::collections::HashMap;
use std::sync::Arc;

use tracing::warn;

use super::traits::{ActionId, ActionPlugin};

// ═══════════════════════════════════════════════════════════════════════════════
// PLUGIN REGISTRY
// ═══════════════════════════════════════════════════════════════════════════════

/// Registry of available action plugins.
///
/// The registry owns plugins (via `Arc`) and provides methods to:
/// - Register new plugins
/// - Look up plugins by ID
/// - Get lists of enabled plugins
///
/// # Thread Safety
///
/// The registry itself is not thread-safe for mutation. It's expected to be
/// built during startup and then only read. Plugins themselves are behind
/// `Arc` and are `Send + Sync`.
///
/// # Example
///
/// ```ignore
/// let mut registry = PluginRegistry::new();
/// registry.register(Arc::new(MyPlugin::new()));
///
/// // Get a specific plugin
/// if let Some(plugin) = registry.get("my_plugin") {
///     println!("Found: {}", plugin.name());
/// }
///
/// // Get enabled plugins based on config
/// let enabled = registry.enabled(&["my_plugin".to_string()]);
/// ```
#[derive(Debug, Default)]
pub struct PluginRegistry {
    plugins: HashMap<String, Arc<dyn ActionPlugin>>,
}

impl PluginRegistry {
    /// Create an empty registry.
    #[must_use]
    pub fn new() -> Self {
        Self {
            plugins: HashMap::new(),
        }
    }

    /// Register a plugin.
    ///
    /// If a plugin with the same ID already exists, it is replaced.
    pub fn register(&mut self, plugin: Arc<dyn ActionPlugin>) {
        let id = plugin.id().to_string();
        tracing::info!(plugin_id = %id, plugin_name = %plugin.name(), "Registering plugin");
        self.plugins.insert(id, plugin);
    }

    /// Get a plugin by ID.
    #[must_use]
    pub fn get(&self, id: &str) -> Option<&Arc<dyn ActionPlugin>> {
        self.plugins.get(id)
    }

    /// Check if a plugin is registered.
    #[must_use]
    pub fn contains(&self, id: &str) -> bool {
        self.plugins.contains_key(id)
    }

    /// Get all registered plugins.
    pub fn all(&self) -> impl Iterator<Item = &Arc<dyn ActionPlugin>> {
        self.plugins.values()
    }

    /// Get all plugin IDs.
    pub fn ids(&self) -> impl Iterator<Item = &str> {
        self.plugins.keys().map(String::as_str)
    }

    /// Get the number of registered plugins.
    #[must_use]
    pub fn len(&self) -> usize {
        self.plugins.len()
    }

    /// Check if the registry is empty.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.plugins.is_empty()
    }

    /// Get enabled plugins based on a list of IDs.
    ///
    /// Returns plugins in the order specified by `enabled_ids`.
    /// Unknown IDs log a warning and are skipped.
    #[must_use]
    pub fn enabled(&self, enabled_ids: &[String]) -> Vec<Arc<dyn ActionPlugin>> {
        enabled_ids
            .iter()
            .filter_map(|id| {
                self.plugins.get(id).cloned().or_else(|| {
                    warn!(
                        plugin_id = %id,
                        available = ?self.plugins.keys().collect::<Vec<_>>(),
                        "Unknown plugin ID in enabled list - check configuration"
                    );
                    None
                })
            })
            .collect()
    }

    /// Get all available actions across all registered plugins.
    #[must_use]
    pub fn all_actions(&self) -> Vec<ActionId> {
        self.plugins
            .values()
            .flat_map(|p| p.available_actions())
            .collect()
    }

    /// Find which plugin handles a given action ID.
    #[must_use]
    pub fn find_plugin_for_action(&self, action_id: &ActionId) -> Option<&Arc<dyn ActionPlugin>> {
        self.plugins.values().find(|p| {
            p.available_actions()
                .iter()
                .any(|a| a.0 == action_id.0)
        })
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;
    use crate::error::Result;
    use crate::plugins::traits::{Action, ActionResult, PluginContext};
    use crate::profiles::BehaviorProfile;
    use crate::wallet::WalletState;
    use alloy::primitives::Address;
    use async_trait::async_trait;

    /// Mock plugin for testing
    #[derive(Debug)]
    struct MockPlugin {
        id: String,
        name: String,
        actions: Vec<ActionId>,
    }

    impl MockPlugin {
        fn new(id: &str, actions: Vec<&str>) -> Self {
            Self {
                id: id.to_string(),
                name: format!("Mock {id}"),
                actions: actions.into_iter().map(ActionId::from).collect(),
            }
        }
    }

    #[async_trait]
    impl ActionPlugin for MockPlugin {
        fn id(&self) -> &str {
            &self.id
        }

        fn name(&self) -> &str {
            &self.name
        }

        fn available_actions(&self) -> Vec<ActionId> {
            self.actions.clone()
        }

        async fn decide_action(
            &self,
            _wallet: &WalletState,
            _profile: &BehaviorProfile,
            _context: &mut PluginContext<'_>,
        ) -> Result<Option<Action>> {
            Ok(None)
        }

        async fn execute_action(
            &self,
            _action: &Action,
            _wallet: &WalletState,
            _nonce: u64,
        ) -> Result<ActionResult> {
            Ok(ActionResult::failure("mock"))
        }

        async fn read_state(&self, _address: Address) -> Result<serde_json::Value> {
            Ok(serde_json::Value::Null)
        }
    }

    #[test]
    fn register_and_get() {
        let mut registry = PluginRegistry::new();
        let plugin = Arc::new(MockPlugin::new("test", vec!["test.action"]));

        registry.register(plugin);

        assert!(registry.contains("test"));
        assert!(!registry.contains("other"));

        let retrieved = registry.get("test").expect("should find plugin");
        assert_eq!(retrieved.id(), "test");
    }

    #[test]
    fn enabled_filters_correctly() {
        let mut registry = PluginRegistry::new();
        registry.register(Arc::new(MockPlugin::new("a", vec![])));
        registry.register(Arc::new(MockPlugin::new("b", vec![])));
        registry.register(Arc::new(MockPlugin::new("c", vec![])));

        let enabled = registry.enabled(&["a".to_string(), "c".to_string()]);
        assert_eq!(enabled.len(), 2);
        assert_eq!(enabled[0].id(), "a");
        assert_eq!(enabled[1].id(), "c");

        // Unknown ID is ignored
        let enabled = registry.enabled(&["a".to_string(), "unknown".to_string()]);
        assert_eq!(enabled.len(), 1);
    }

    #[test]
    fn all_actions_aggregates() {
        let mut registry = PluginRegistry::new();
        registry.register(Arc::new(MockPlugin::new("a", vec!["a.one", "a.two"])));
        registry.register(Arc::new(MockPlugin::new("b", vec!["b.one"])));

        let actions = registry.all_actions();
        assert_eq!(actions.len(), 3);
    }

    #[test]
    fn find_plugin_for_action() {
        let mut registry = PluginRegistry::new();
        registry.register(Arc::new(MockPlugin::new("a", vec!["a.action"])));
        registry.register(Arc::new(MockPlugin::new("b", vec!["b.action"])));

        let plugin = registry
            .find_plugin_for_action(&ActionId::from("a.action"))
            .expect("should find");
        assert_eq!(plugin.id(), "a");

        assert!(registry
            .find_plugin_for_action(&ActionId::from("unknown"))
            .is_none());
    }
}
