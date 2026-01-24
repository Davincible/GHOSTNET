//! Main service orchestrator.
//!
//! The [`FleetService`] is the core orchestrator that ties together:
//! - Wallet management and state tracking
//! - Plugin registration and action coordination
//! - Safety mechanisms (circuit breakers)
//! - Scheduling with profile-based timing

use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;

use anyhow::{Context, Result};
use evm_provider::mock::MockProvider;
use evm_provider::ChainProvider;
use fleet_core::plugins::PluginRegistry;
use fleet_core::profiles::BehaviorProfile;
use fleet_core::safety::CircuitBreaker;
use fleet_core::scheduler::Scheduler;
use fleet_core::wallet::WalletState;
use ghostnet_actions::{GhostnetConfig, GhostnetPlugin};
use tokio::time::interval;
use tracing::{debug, error, info, instrument, warn};

use crate::config::Settings;
use crate::engine::BehaviorEngine;

// ═══════════════════════════════════════════════════════════════════════════════
// FLEET SERVICE
// ═══════════════════════════════════════════════════════════════════════════════

/// Main orchestrator service for Ghost Fleet.
///
/// Coordinates wallet operations, plugin execution, and safety mechanisms.
/// Runs a main loop that processes wallets at regular intervals.
///
/// # Main Loop
///
/// The service runs a tick-based loop:
/// 1. Check global pause flag
/// 2. Check circuit breaker auto-reset
/// 3. Get wallets due for action
/// 4. For each due wallet:
///    a. Refresh state from chain
///    b. Check circuit breaker
///    c. Consult plugins for action decision
///    d. Execute action if decided
///    e. Schedule next action
///
/// # Example
///
/// ```ignore
/// let settings = Settings::load("config.toml")?;
/// let service = FleetService::new(settings, false).await?;
/// service.run().await?;
/// ```
#[derive(Debug)]
pub struct FleetService {
    /// Configuration settings.
    settings: Settings,

    /// Chain provider for blockchain interactions.
    provider: Arc<MockProvider>,

    /// Plugin registry.
    #[allow(dead_code)]
    registry: PluginRegistry,

    /// Behavior engine for coordinating plugins.
    engine: BehaviorEngine,

    /// Circuit breaker for error handling.
    circuit_breaker: CircuitBreaker,

    /// Scheduler for timing calculations.
    scheduler: Scheduler,

    /// Wallet states by wallet ID.
    wallets: HashMap<String, WalletState>,

    /// Behavior profiles by name.
    profiles: HashMap<String, BehaviorProfile>,

    /// Dry run mode (no transactions sent).
    dry_run: bool,
}

impl FleetService {
    /// Create a new fleet service.
    ///
    /// # Arguments
    ///
    /// * `settings` - Configuration settings
    /// * `dry_run` - If true, actions are logged but not executed
    ///
    /// # Errors
    ///
    /// Returns an error if provider initialization fails.
    #[allow(clippy::unused_async)] // async for future provider initialization
    pub async fn new(settings: Settings, dry_run: bool) -> Result<Self> {
        info!(
            chain_type = %settings.chain.chain_type,
            chain_id = settings.chain.chain_id,
            dry_run = dry_run,
            "Initializing Fleet Service"
        );

        // Create provider based on chain type
        let provider = Self::create_provider(&settings)?;

        // Initialize plugin registry
        let registry = Self::create_registry(&settings, Arc::clone(&provider));

        // Create behavior engine
        let engine = BehaviorEngine::new(&registry, &settings.plugins.enabled);

        // Create circuit breaker
        let circuit_breaker = CircuitBreaker::new(
            settings.safety.max_consecutive_errors,
            Duration::from_secs(settings.safety.cooldown_secs),
        );

        // Create scheduler
        let scheduler = Scheduler::new();

        // Initialize wallet states
        let wallets = Self::initialize_wallets(&settings);

        // Load behavior profiles
        let profiles = Self::load_profiles(&settings);

        info!(
            wallets = wallets.len(),
            profiles = profiles.len(),
            plugins = settings.plugins.enabled.len(),
            "Fleet Service initialized"
        );

        Ok(Self {
            settings,
            provider,
            registry,
            engine,
            circuit_breaker,
            scheduler,
            wallets,
            profiles,
            dry_run,
        })
    }

    /// Create the chain provider based on settings.
    fn create_provider(settings: &Settings) -> Result<Arc<MockProvider>> {
        match settings.chain.chain_type.as_str() {
            "mock" => {
                info!("Using mock provider for testing");
                Ok(Arc::new(MockProvider::with_chain_id(settings.chain.chain_id)))
            }
            "standard" | "megaeth" => {
                // For now, use mock provider as placeholder
                // In production, this would create StandardEvmProvider or MegaEthProvider
                warn!(
                    chain_type = %settings.chain.chain_type,
                    "Real provider not yet implemented, using mock"
                );
                Ok(Arc::new(MockProvider::with_chain_id(settings.chain.chain_id)))
            }
            other => {
                anyhow::bail!("Unknown chain type: {other}")
            }
        }
    }

    /// Create and populate the plugin registry.
    fn create_registry(
        settings: &Settings,
        provider: Arc<MockProvider>,
    ) -> PluginRegistry {
        let mut registry = PluginRegistry::new();

        // Register GHOSTNET plugin if enabled
        if settings.plugins.enabled.contains(&"ghostnet".to_string())
            && let Some(ghostnet_config) = &settings.plugins.ghostnet
        {
            let config = GhostnetConfig::new(
                ghostnet_config.ghost_core,
                ghostnet_config.hash_crash,
                ghostnet_config.arcade_core,
                ghostnet_config.data_token,
                settings.chain.chain_id,
            );

            let plugin = GhostnetPlugin::new(config, provider);
            registry.register(Arc::new(plugin));

            info!("Registered GHOSTNET plugin");
        }

        registry
    }

    /// Initialize wallet states from configuration.
    fn initialize_wallets(settings: &Settings) -> HashMap<String, WalletState> {
        settings
            .wallets
            .iter()
            .filter(|w| w.enabled)
            .map(|w| {
                let state = WalletState::with_profile(
                    w.id.clone(),
                    w.address,
                    w.profile.clone(),
                );
                (w.id.clone(), state)
            })
            .collect()
    }

    /// Load behavior profiles from configuration.
    fn load_profiles(settings: &Settings) -> HashMap<String, BehaviorProfile> {
        settings
            .profiles
            .iter()
            .map(|(name, config)| (name.clone(), config.to_behavior_profile(name)))
            .collect()
    }

    /// Run the service main loop.
    ///
    /// This method runs until cancelled or an unrecoverable error occurs.
    ///
    /// # Errors
    ///
    /// Returns an error if the main loop encounters an unrecoverable error.
    pub async fn run(mut self) -> Result<()> {
        let tick_duration = Duration::from_millis(self.settings.service.tick_interval_ms);
        let mut tick = interval(tick_duration);

        info!(
            tick_ms = self.settings.service.tick_interval_ms,
            "Starting main loop"
        );

        loop {
            tick.tick().await;

            // Check global pause
            if self.settings.safety.global_pause {
                debug!("Global pause active, skipping tick");
                continue;
            }

            // Auto-reset circuit breakers
            let reset_count = self.circuit_breaker.check_auto_reset();
            if reset_count > 0 {
                info!(count = reset_count, "Auto-reset circuit breakers");
            }

            // Get wallets due for action
            let due_wallets = self.get_due_wallets();

            if !due_wallets.is_empty() {
                debug!(count = due_wallets.len(), "Processing due wallets");
            }

            // Process each due wallet
            for wallet_id in due_wallets {
                if let Err(e) = self.process_wallet(&wallet_id).await {
                    error!(wallet = %wallet_id, error = %e, "Error processing wallet");
                }
            }
        }
    }

    /// Get IDs of wallets that are due for action.
    fn get_due_wallets(&self) -> Vec<String> {
        self.wallets
            .values()
            .filter(|w| w.is_active() && w.is_due())
            .filter(|w| !self.circuit_breaker.is_tripped(&w.id))
            .map(|w| w.id.clone())
            .collect()
    }

    /// Process a single wallet.
    #[instrument(skip(self), fields(wallet_id = %wallet_id))]
    async fn process_wallet(&mut self, wallet_id: &str) -> Result<()> {
        debug!("Processing wallet");

        // Get profile name first (clone to avoid borrow issues)
        let profile_name = {
            let wallet = self.wallets.get(wallet_id)
                .context("Wallet not found")?;
            wallet.profile_name.clone()
        };

        // Get profile (clone to avoid borrow issues)
        let profile = self.profiles.get(&profile_name)
            .cloned()
            .context("Profile not found for wallet")?;

        // Check if we should act based on active hours
        if !self.scheduler.should_act_now(&profile) {
            debug!("Outside active hours, scheduling next action");
            let next = self.scheduler.calculate_next_action(&profile);
            if let Some(w) = self.wallets.get_mut(wallet_id) {
                w.schedule_next(next);
            }
            return Ok(());
        }

        // Refresh wallet state from chain
        self.refresh_wallet_state(wallet_id).await?;

        // Check for AFK
        if let Some(afk_until) = self.scheduler.maybe_go_afk(&profile) {
            info!(until = %afk_until, "Wallet going AFK");
            if let Some(w) = self.wallets.get_mut(wallet_id) {
                w.set_afk(afk_until);
                w.schedule_next(afk_until);
            }
            return Ok(());
        }

        // Get wallet for action decision (clone to avoid borrow issues)
        let wallet = self.wallets.get(wallet_id)
            .cloned()
            .context("Wallet not found")?;

        // Decide action via behavior engine
        let action_decision = self.engine.decide_action(&wallet, &profile).await;

        match action_decision {
            Some((plugin, action)) => {
                info!(
                    action = %action.name,
                    plugin = plugin.id(),
                    "Action decided"
                );

                if self.dry_run {
                    info!(action = %action.name, "DRY RUN: Would execute action");
                } else {
                    // Execute the action
                    let result = plugin.execute_action(&action, &wallet, wallet.nonce).await;

                    match result {
                        Ok(action_result) => {
                            if action_result.success {
                                info!(
                                    tx_hash = ?action_result.tx_hash,
                                    "Action executed successfully"
                                );
                                self.circuit_breaker.record_success(wallet_id);
                                if let Some(w) = self.wallets.get_mut(wallet_id) {
                                    w.record_success();
                                    w.increment_nonce();
                                }
                            } else {
                                warn!(
                                    error = ?action_result.error,
                                    "Action failed"
                                );
                                self.record_wallet_error(wallet_id);
                            }
                        }
                        Err(e) => {
                            error!(error = %e, "Action execution error");
                            self.record_wallet_error(wallet_id);
                        }
                    }
                }
            }
            None => {
                debug!("No action decided");
            }
        }

        // Schedule next action
        let next = self.scheduler.calculate_next_action(&profile);
        if let Some(w) = self.wallets.get_mut(wallet_id) {
            w.schedule_next(next);
        }

        Ok(())
    }

    /// Refresh wallet state from the chain.
    #[instrument(skip(self), fields(wallet_id = %wallet_id))]
    async fn refresh_wallet_state(&mut self, wallet_id: &str) -> Result<()> {
        let address = {
            let wallet = self.wallets.get(wallet_id)
                .context("Wallet not found")?;
            wallet.address
        };

        // Fetch native balance
        let native_balance = self.provider.get_balance(address).await
            .context("Failed to fetch balance")?;

        // Fetch nonce
        let nonce = self.provider.get_nonce(address).await
            .context("Failed to fetch nonce")?;

        // Update wallet state
        if let Some(w) = self.wallets.get_mut(wallet_id) {
            w.set_native_balance(native_balance);
            w.set_nonce(nonce);
        }

        // Fetch DATA token balance if GHOSTNET plugin is configured
        if let Some(ghostnet_config) = &self.settings.plugins.ghostnet {
            let data_balance = self
                .provider
                .get_token_balance(ghostnet_config.data_token, address)
                .await
                .context("Failed to fetch token balance")?;

            if let Some(w) = self.wallets.get_mut(wallet_id) {
                w.set_token_balance(ghostnet_config.data_token, data_balance);
            }
        }

        // Read plugin-specific state
        for plugin in self.engine.plugins() {
            match plugin.read_state(address).await {
                Ok(state) => {
                    if let Some(w) = self.wallets.get_mut(wallet_id) {
                        w.set_plugin_state(plugin.id(), state);
                    }
                }
                Err(e) => {
                    warn!(
                        plugin = plugin.id(),
                        error = %e,
                        "Failed to read plugin state"
                    );
                }
            }
        }

        debug!(
            native_balance = %native_balance,
            nonce = nonce,
            "Wallet state refreshed"
        );

        Ok(())
    }

    /// Record an error for a wallet.
    fn record_wallet_error(&mut self, wallet_id: &str) {
        let tripped = self.circuit_breaker.record_error(wallet_id);
        if tripped {
            warn!(wallet = %wallet_id, "Circuit breaker tripped");
        }

        if let Some(w) = self.wallets.get_mut(wallet_id) {
            w.record_error();
        }
    }

    /// Get current wallet states (for inspection/debugging).
    #[must_use]
    #[allow(dead_code)] // Public API
    pub const fn wallets(&self) -> &HashMap<String, WalletState> {
        &self.wallets
    }

    /// Get the circuit breaker (for inspection/debugging).
    #[must_use]
    #[allow(dead_code)] // Public API
    pub const fn circuit_breaker(&self) -> &CircuitBreaker {
        &self.circuit_breaker
    }

    /// Check if dry run mode is enabled.
    #[must_use]
    #[allow(dead_code)] // Public API
    pub const fn is_dry_run(&self) -> bool {
        self.dry_run
    }

    /// Get a reference to the provider.
    #[must_use]
    #[allow(dead_code)] // Public API
    pub const fn provider(&self) -> &Arc<MockProvider> {
        &self.provider
    }

    /// Manually trigger a wallet reset (clears circuit breaker).
    #[allow(dead_code)] // Public API
    pub fn reset_wallet(&mut self, wallet_id: &str) {
        self.circuit_breaker.manual_reset(wallet_id);
        if let Some(w) = self.wallets.get_mut(wallet_id) {
            w.record_success(); // Resets error count
        }
        info!(wallet = %wallet_id, "Wallet manually reset");
    }

    /// Pause all operations.
    #[allow(dead_code)] // Public API
    pub fn pause(&mut self) {
        self.settings.safety.global_pause = true;
        info!("Service paused");
    }

    /// Resume operations.
    #[allow(dead_code)] // Public API
    pub fn resume(&mut self) {
        self.settings.safety.global_pause = false;
        info!("Service resumed");
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::{ChainConfig, PluginsConfig, ProfileConfig, SafetyConfig, ServiceConfig};

    fn test_settings() -> Settings {
        let mut profiles = HashMap::new();
        profiles.insert("test_profile".to_string(), ProfileConfig::default());

        Settings {
            service: ServiceConfig::default(),
            chain: ChainConfig {
                chain_id: 31337,
                rpc_url: "http://localhost:8545".to_string(),
                chain_type: "mock".to_string(),
                gas_limit_override: None,
                use_realtime: false,
            },
            wallets: vec![],
            plugins: PluginsConfig::default(),
            safety: SafetyConfig::default(),
            profiles,
        }
    }

    #[tokio::test]
    async fn service_initializes() {
        let settings = test_settings();
        let service = FleetService::new(settings, true).await;
        assert!(service.is_ok());

        let service = service.unwrap();
        assert!(service.is_dry_run());
        assert!(service.wallets().is_empty());
    }

    #[tokio::test]
    async fn pause_and_resume() {
        let settings = test_settings();
        let mut service = FleetService::new(settings, true).await.unwrap();

        assert!(!service.settings.safety.global_pause);

        service.pause();
        assert!(service.settings.safety.global_pause);

        service.resume();
        assert!(!service.settings.safety.global_pause);
    }

    #[tokio::test]
    async fn circuit_breaker_integration() {
        let settings = test_settings();
        let mut service = FleetService::new(settings, true).await.unwrap();

        // Record errors until circuit trips
        for _ in 0..5 {
            service.record_wallet_error("test_wallet");
        }

        assert!(service.circuit_breaker.is_tripped("test_wallet"));

        // Manual reset
        service.reset_wallet("test_wallet");
        assert!(!service.circuit_breaker.is_tripped("test_wallet"));
    }
}
