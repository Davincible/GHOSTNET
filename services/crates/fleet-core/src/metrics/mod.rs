//! Observability primitives for fleet operations.
//!
//! This module provides types and utilities for tracking fleet metrics.
//! It's designed to work with any metrics backend (Prometheus, etc.).
//!
//! # Design Philosophy
//!
//! Rather than directly depending on a metrics crate (which may change),
//! this module defines domain-specific types that can be adapted to any
//! backend. The main service is responsible for connecting these to actual
//! metrics exporters.
//!
//! # Metrics Types
//!
//! - **Counters**: Track cumulative counts (actions executed, errors)
//! - **Gauges**: Track current values (active wallets, tripped breakers)
//! - **Histograms**: Track distributions (action latency, gas usage)
//!
//! # Example
//!
//! ```
//! use fleet_core::metrics::{FleetMetrics, ActionMetrics};
//!
//! let mut metrics = FleetMetrics::new();
//!
//! // Record an action
//! metrics.record_action(ActionMetrics {
//!     plugin_id: "ghostnet".to_string(),
//!     action_id: "ghostnet.jack_in".to_string(),
//!     wallet_id: "whale_1".to_string(),
//!     success: true,
//!     duration_ms: 150,
//!     gas_used: Some(250_000),
//! });
//!
//! assert_eq!(metrics.total_actions(), 1);
//! assert_eq!(metrics.successful_actions(), 1);
//! ```

use std::collections::HashMap;

use chrono::{DateTime, Utc};

// ═══════════════════════════════════════════════════════════════════════════════
// METRICS TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Metrics for a single action execution.
#[derive(Debug, Clone)]
pub struct ActionMetrics {
    /// Plugin that executed the action.
    pub plugin_id: String,

    /// Action that was executed.
    pub action_id: String,

    /// Wallet that performed the action.
    pub wallet_id: String,

    /// Whether the action succeeded.
    pub success: bool,

    /// Execution duration in milliseconds.
    pub duration_ms: u64,

    /// Gas used (if transaction was sent).
    pub gas_used: Option<u64>,
}

/// Snapshot of fleet-wide metrics.
#[derive(Debug, Clone, Default)]
pub struct FleetSnapshot {
    /// When this snapshot was taken.
    pub timestamp: Option<DateTime<Utc>>,

    /// Total active wallets.
    pub active_wallets: usize,

    /// Wallets currently tripped by circuit breaker.
    pub tripped_wallets: usize,

    /// Wallets currently AFK.
    pub afk_wallets: usize,

    /// Total actions executed since startup.
    pub total_actions: u64,

    /// Successful actions since startup.
    pub successful_actions: u64,

    /// Failed actions since startup.
    pub failed_actions: u64,

    /// Actions by plugin.
    pub actions_by_plugin: HashMap<String, u64>,

    /// Actions by action type.
    pub actions_by_type: HashMap<String, u64>,
}

// ═══════════════════════════════════════════════════════════════════════════════
// FLEET METRICS
// ═══════════════════════════════════════════════════════════════════════════════

/// In-memory metrics collector.
///
/// Collects metrics during operation and provides summary snapshots.
/// This is a simple implementation suitable for small fleets. For larger
/// deployments, connect to a proper metrics system (Prometheus, etc.).
#[derive(Debug, Default)]
pub struct FleetMetrics {
    /// Total actions executed.
    total_actions: u64,

    /// Successful actions.
    successful_actions: u64,

    /// Failed actions.
    failed_actions: u64,

    /// Actions by plugin ID.
    by_plugin: HashMap<String, u64>,

    /// Actions by action ID.
    by_action: HashMap<String, u64>,

    /// Actions by wallet ID.
    by_wallet: HashMap<String, u64>,

    /// Recent action durations (for percentile calculation).
    /// Limited to last 1000 entries.
    recent_durations: Vec<u64>,

    /// Recent gas usage.
    /// Limited to last 1000 entries.
    recent_gas: Vec<u64>,
}

impl FleetMetrics {
    /// Create a new metrics collector.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Record metrics for an action execution.
    pub fn record_action(&mut self, metrics: ActionMetrics) {
        self.total_actions += 1;

        if metrics.success {
            self.successful_actions += 1;
        } else {
            self.failed_actions += 1;
        }

        *self.by_plugin.entry(metrics.plugin_id).or_insert(0) += 1;
        *self.by_action.entry(metrics.action_id).or_insert(0) += 1;
        *self.by_wallet.entry(metrics.wallet_id).or_insert(0) += 1;

        // Keep recent durations (ring buffer)
        if self.recent_durations.len() >= 1000 {
            self.recent_durations.remove(0);
        }
        self.recent_durations.push(metrics.duration_ms);

        // Keep recent gas usage
        if let Some(gas) = metrics.gas_used {
            if self.recent_gas.len() >= 1000 {
                self.recent_gas.remove(0);
            }
            self.recent_gas.push(gas);
        }
    }

    /// Get total actions executed.
    #[must_use]
    pub const fn total_actions(&self) -> u64 {
        self.total_actions
    }

    /// Get successful action count.
    #[must_use]
    pub const fn successful_actions(&self) -> u64 {
        self.successful_actions
    }

    /// Get failed action count.
    #[must_use]
    pub const fn failed_actions(&self) -> u64 {
        self.failed_actions
    }

    /// Get success rate as a percentage (0-100).
    #[must_use]
    #[allow(clippy::cast_precision_loss)] // Acceptable for metrics display
    pub fn success_rate(&self) -> f64 {
        if self.total_actions == 0 {
            100.0
        } else {
            (self.successful_actions as f64 / self.total_actions as f64) * 100.0
        }
    }

    /// Get actions count for a specific plugin.
    #[must_use]
    pub fn actions_for_plugin(&self, plugin_id: &str) -> u64 {
        self.by_plugin.get(plugin_id).copied().unwrap_or(0)
    }

    /// Get actions count for a specific wallet.
    #[must_use]
    pub fn actions_for_wallet(&self, wallet_id: &str) -> u64 {
        self.by_wallet.get(wallet_id).copied().unwrap_or(0)
    }

    /// Get average action duration in milliseconds.
    #[must_use]
    #[allow(clippy::cast_precision_loss)] // Acceptable for metrics display
    pub fn avg_duration_ms(&self) -> f64 {
        if self.recent_durations.is_empty() {
            0.0
        } else {
            self.recent_durations.iter().sum::<u64>() as f64
                / self.recent_durations.len() as f64
        }
    }

    /// Get p50 (median) action duration in milliseconds.
    #[must_use]
    pub fn p50_duration_ms(&self) -> u64 {
        percentile(&self.recent_durations, 50)
    }

    /// Get p95 action duration in milliseconds.
    #[must_use]
    pub fn p95_duration_ms(&self) -> u64 {
        percentile(&self.recent_durations, 95)
    }

    /// Get p99 action duration in milliseconds.
    #[must_use]
    pub fn p99_duration_ms(&self) -> u64 {
        percentile(&self.recent_durations, 99)
    }

    /// Get average gas used per action.
    #[must_use]
    #[allow(clippy::cast_precision_loss)] // Acceptable for metrics display
    pub fn avg_gas_used(&self) -> f64 {
        if self.recent_gas.is_empty() {
            0.0
        } else {
            self.recent_gas.iter().sum::<u64>() as f64 / self.recent_gas.len() as f64
        }
    }

    /// Create a snapshot of current metrics.
    #[must_use]
    pub fn snapshot(&self) -> FleetSnapshot {
        FleetSnapshot {
            timestamp: Some(Utc::now()),
            active_wallets: 0, // Filled in by caller
            tripped_wallets: 0,
            afk_wallets: 0,
            total_actions: self.total_actions,
            successful_actions: self.successful_actions,
            failed_actions: self.failed_actions,
            actions_by_plugin: self.by_plugin.clone(),
            actions_by_type: self.by_action.clone(),
        }
    }

    /// Reset all metrics.
    pub fn reset(&mut self) {
        *self = Self::new();
    }
}

/// Calculate percentile of a dataset.
fn percentile(data: &[u64], p: usize) -> u64 {
    if data.is_empty() {
        return 0;
    }

    let mut sorted = data.to_vec();
    sorted.sort_unstable();

    let idx = (p * sorted.len() / 100).min(sorted.len() - 1);
    sorted[idx]
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_action(success: bool, duration_ms: u64) -> ActionMetrics {
        ActionMetrics {
            plugin_id: "test".to_string(),
            action_id: "test.action".to_string(),
            wallet_id: "wallet_1".to_string(),
            success,
            duration_ms,
            gas_used: Some(100_000),
        }
    }

    #[test]
    fn counts_actions() {
        let mut metrics = FleetMetrics::new();

        metrics.record_action(sample_action(true, 100));
        metrics.record_action(sample_action(true, 100));
        metrics.record_action(sample_action(false, 100));

        assert_eq!(metrics.total_actions(), 3);
        assert_eq!(metrics.successful_actions(), 2);
        assert_eq!(metrics.failed_actions(), 1);
    }

    #[test]
    fn success_rate() {
        let mut metrics = FleetMetrics::new();

        metrics.record_action(sample_action(true, 100));
        metrics.record_action(sample_action(true, 100));
        metrics.record_action(sample_action(true, 100));
        metrics.record_action(sample_action(false, 100));

        let rate = metrics.success_rate();
        assert!((rate - 75.0).abs() < 0.01);
    }

    #[test]
    fn empty_metrics_100_percent_success() {
        let metrics = FleetMetrics::new();
        assert!((metrics.success_rate() - 100.0).abs() < 0.01);
    }

    #[test]
    fn tracks_by_plugin() {
        let mut metrics = FleetMetrics::new();

        let mut action = sample_action(true, 100);
        action.plugin_id = "plugin_a".to_string();
        metrics.record_action(action.clone());
        metrics.record_action(action);

        let mut action = sample_action(true, 100);
        action.plugin_id = "plugin_b".to_string();
        metrics.record_action(action);

        assert_eq!(metrics.actions_for_plugin("plugin_a"), 2);
        assert_eq!(metrics.actions_for_plugin("plugin_b"), 1);
        assert_eq!(metrics.actions_for_plugin("unknown"), 0);
    }

    #[test]
    fn duration_percentiles() {
        let mut metrics = FleetMetrics::new();

        // Add 100 actions with durations 1-100ms
        for i in 1..=100 {
            metrics.record_action(sample_action(true, i));
        }

        // P50 should be around 50
        let p50 = metrics.p50_duration_ms();
        assert!(p50 >= 45 && p50 <= 55, "p50 was {p50}");

        // P95 should be around 95
        let p95 = metrics.p95_duration_ms();
        assert!(p95 >= 90 && p95 <= 100, "p95 was {p95}");
    }

    #[test]
    fn snapshot_captures_state() {
        let mut metrics = FleetMetrics::new();
        metrics.record_action(sample_action(true, 100));
        metrics.record_action(sample_action(false, 200));

        let snapshot = metrics.snapshot();

        assert!(snapshot.timestamp.is_some());
        assert_eq!(snapshot.total_actions, 2);
        assert_eq!(snapshot.successful_actions, 1);
        assert_eq!(snapshot.failed_actions, 1);
    }
}
