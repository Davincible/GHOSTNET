//! Main service orchestrator.
//!
//! The [`FleetService`] is the core orchestrator that ties together:
//! - Wallet management and state tracking
//! - Plugin registration and action coordination
//! - Safety mechanisms (circuit breakers, rate limiting)
//! - Scheduling with profile-based timing

use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use evm_provider::mock::MockProvider;
use evm_provider::ChainProvider;
use fleet_core::plugins::PluginRegistry;
use fleet_core::profiles::BehaviorProfile;
use fleet_core::safety::CircuitBreaker;
use fleet_core::scheduler::Scheduler;
use fleet_core::wallet::WalletState;
use ghostnet_actions::{GhostnetConfig, GhostnetPlugin};
use tokio::sync::watch;
use tokio::time::interval;
use tracing::{debug, error, info, instrument, warn};

use crate::config::Settings;
use crate::engine::BehaviorEngine;

// ═══════════════════════════════════════════════════════════════════════════════
// RATE LIMITER
// ═══════════════════════════════════════════════════════════════════════════════

/// Tracks action counts per wallet for rate limiting.
#[derive(Debug, Default)]
struct RateLimiter {
    /// Action timestamps per wallet (for sliding window).
    action_times: HashMap<String, Vec<DateTime<Utc>>>,
    /// Maximum actions per hour.
    max_per_hour: u32,
}

impl RateLimiter {
    /// Create a new rate limiter.
    fn new(max_per_hour: u32) -> Self {
        Self {
            action_times: HashMap::new(),
            max_per_hour,
        }
    }

    /// Check if the wallet would exceed the rate limit.
    fn would_exceed(&self, wallet_id: &str) -> bool {
        let Some(times) = self.action_times.get(wallet_id) else {
            return false;
        };

        let one_hour_ago = Utc::now() - chrono::Duration::hours(1);
        let recent_count = times.iter().filter(|t| **t > one_hour_ago).count();

        recent_count >= self.max_per_hour as usize
    }

    /// Record an action for rate limiting.
    fn record_action(&mut self, wallet_id: &str) {
        let times = self.action_times.entry(wallet_id.to_string()).or_default();
        times.push(Utc::now());

        // Prune old entries (older than 1 hour)
        let one_hour_ago = Utc::now() - chrono::Duration::hours(1);
        times.retain(|t| *t > one_hour_ago);
    }

    /// Get current action count in the last hour.
    #[allow(dead_code)] // Used in tests
    fn action_count(&self, wallet_id: &str) -> usize {
        let Some(times) = self.action_times.get(wallet_id) else {
            return 0;
        };

        let one_hour_ago = Utc::now() - chrono::Duration::hours(1);
        times.iter().filter(|t| **t > one_hour_ago).count()
    }
}

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
/// 1. Check shutdown signal
/// 2. Check global pause flag
/// 3. Check circuit breaker auto-reset
/// 4. Get wallets due for action
/// 5. For each due wallet:
///    a. Check rate limit
///    b. Refresh state from chain
///    c. Check circuit breaker
///    d. Consult plugins for action decision
///    e. Execute action if decided
///    f. Schedule next action
///
/// # Example
///
/// ```ignore
/// let settings = Settings::load("config.toml")?;
/// let (shutdown_tx, shutdown_rx) = tokio::sync::watch::channel(false);
/// let service = FleetService::new(settings, false).await?;
///
/// // Run in a task
/// let handle = tokio::spawn(async move {
///     service.run(shutdown_rx).await
/// });
///
/// // To stop:
/// shutdown_tx.send(true).ok();
/// handle.await??;
/// ```
#[derive(Debug)]
pub struct FleetService {
    /// Configuration settings.
    settings: Settings,

    /// Chain provider for blockchain interactions.
    ///
    /// TODO: Make this `Arc<dyn ChainProvider>` once we have real provider implementations.
    /// Currently uses MockProvider directly since GhostnetPlugin<P> requires a concrete type.
    provider: Arc<MockProvider>,

    /// Plugin registry.
    #[expect(dead_code, reason = "Stored for future plugin hot-reload")]
    registry: PluginRegistry,

    /// Behavior engine for coordinating plugins.
    engine: BehaviorEngine,

    /// Circuit breaker for error handling.
    circuit_breaker: CircuitBreaker,

    /// Rate limiter for action throttling.
    rate_limiter: RateLimiter,

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
    #[expect(clippy::unused_async, reason = "async for future provider initialization")]
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

        // Create rate limiter
        let rate_limiter = RateLimiter::new(settings.safety.max_actions_per_hour);

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
            max_actions_per_hour = settings.safety.max_actions_per_hour,
            "Fleet Service initialized"
        );

        Ok(Self {
            settings,
            provider,
            registry,
            engine,
            circuit_breaker,
            rate_limiter,
            scheduler,
            wallets,
            profiles,
            dry_run,
        })
    }

    /// Create the chain provider based on settings.
    ///
    /// TODO: Return `Arc<dyn ChainProvider>` once we have real provider implementations.
    fn create_provider(settings: &Settings) -> Result<Arc<MockProvider>> {
        match settings.chain.chain_type.as_str() {
            "mock" => {
                info!("Using mock provider for testing");
                Ok(Arc::new(MockProvider::with_chain_id(settings.chain.chain_id)))
            }
            "standard" | "megaeth" => {
                // For now, use mock provider as placeholder
                // TODO: Implement real providers (StandardEvmProvider, MegaEthProvider)
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
        // Use iter().any() to avoid string allocation, and combine conditions
        if settings.plugins.enabled.iter().any(|s| s == "ghostnet")
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
    /// This method runs until the shutdown signal is received or an
    /// unrecoverable error occurs.
    ///
    /// # Arguments
    ///
    /// * `shutdown` - Watch receiver that signals shutdown when value becomes `true`
    ///
    /// # Errors
    ///
    /// Returns an error if the main loop encounters an unrecoverable error.
    pub async fn run(mut self, mut shutdown: watch::Receiver<bool>) -> Result<()> {
        let tick_duration = Duration::from_millis(self.settings.service.tick_interval_ms);
        let mut tick = interval(tick_duration);

        info!(
            tick_ms = self.settings.service.tick_interval_ms,
            "Starting main loop"
        );

        loop {
            tokio::select! {
                _ = tick.tick() => {
                    self.process_tick().await;
                }
                _ = shutdown.changed() => {
                    if *shutdown.borrow() {
                        info!("Shutdown signal received, stopping service");
                        return Ok(());
                    }
                }
            }
        }
    }

    /// Process a single tick of the main loop.
    async fn process_tick(&mut self) {
        // Check global pause
        if self.settings.safety.global_pause {
            debug!("Global pause active, skipping tick");
            return;
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

        // Check rate limit first
        if self.rate_limiter.would_exceed(wallet_id) {
            debug!(
                wallet = %wallet_id,
                max_per_hour = self.settings.safety.max_actions_per_hour,
                "Rate limit would be exceeded, skipping"
            );
            return Ok(());
        }

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
                    // Still record for rate limiting in dry run
                    self.rate_limiter.record_action(wallet_id);
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
                                self.rate_limiter.record_action(wallet_id);
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
    #[allow(dead_code)] // Used in tests
    pub const fn wallets(&self) -> &HashMap<String, WalletState> {
        &self.wallets
    }

    /// Get the circuit breaker (for inspection/debugging).
    #[must_use]
    #[allow(dead_code)] // Used in tests
    pub const fn circuit_breaker(&self) -> &CircuitBreaker {
        &self.circuit_breaker
    }

    /// Check if dry run mode is enabled.
    #[must_use]
    #[allow(dead_code)] // Used in tests
    pub const fn is_dry_run(&self) -> bool {
        self.dry_run
    }

    /// Get a reference to the provider.
    #[must_use]
    #[allow(dead_code)] // Used in tests
    pub const fn provider(&self) -> &Arc<MockProvider> {
        &self.provider
    }

    /// Manually trigger a wallet reset (clears circuit breaker).
    #[allow(dead_code)] // Used in tests and operations
    pub fn reset_wallet(&mut self, wallet_id: &str) {
        self.circuit_breaker.manual_reset(wallet_id);
        if let Some(w) = self.wallets.get_mut(wallet_id) {
            w.record_success(); // Resets error count
        }
        info!(wallet = %wallet_id, "Wallet manually reset");
    }

    /// Pause all operations.
    #[allow(dead_code)] // Used in tests and operations
    pub fn pause(&mut self) {
        self.settings.safety.global_pause = true;
        info!("Service paused");
    }

    /// Resume operations.
    #[allow(dead_code)] // Used in tests and operations
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

    #[tokio::test]
    async fn shutdown_signal_stops_service() {
        let settings = test_settings();
        let service = FleetService::new(settings, true).await.unwrap();

        let (shutdown_tx, shutdown_rx) = watch::channel(false);

        // Spawn service in a task
        let handle = tokio::spawn(async move {
            service.run(shutdown_rx).await
        });

        // Give it a moment to start
        tokio::time::sleep(Duration::from_millis(50)).await;

        // Send shutdown signal
        shutdown_tx.send(true).unwrap();

        // Service should stop gracefully
        let result = tokio::time::timeout(Duration::from_secs(1), handle).await;
        assert!(result.is_ok(), "Service should stop within timeout");
        assert!(result.unwrap().unwrap().is_ok());
    }

    #[test]
    fn rate_limiter_tracks_actions() {
        let mut limiter = RateLimiter::new(3);

        assert!(!limiter.would_exceed("wallet_1"));
        assert_eq!(limiter.action_count("wallet_1"), 0);

        limiter.record_action("wallet_1");
        limiter.record_action("wallet_1");
        assert!(!limiter.would_exceed("wallet_1"));
        assert_eq!(limiter.action_count("wallet_1"), 2);

        limiter.record_action("wallet_1");
        assert!(limiter.would_exceed("wallet_1"));
        assert_eq!(limiter.action_count("wallet_1"), 3);
    }

    #[test]
    fn rate_limiter_independent_per_wallet() {
        let mut limiter = RateLimiter::new(2);

        limiter.record_action("wallet_1");
        limiter.record_action("wallet_1");
        assert!(limiter.would_exceed("wallet_1"));

        // wallet_2 should not be affected
        assert!(!limiter.would_exceed("wallet_2"));
        limiter.record_action("wallet_2");
        assert!(!limiter.would_exceed("wallet_2"));
    }
}
