//! Error types for fleet-core operations.
//!
//! This module defines the error types used throughout the fleet-core crate.
//! Errors are categorized by their source (wallet, plugin, scheduler, etc.).

use thiserror::Error;

/// Result type alias for fleet-core operations.
pub type Result<T> = std::result::Result<T, FleetError>;

/// Errors that can occur in fleet-core operations.
#[derive(Debug, Error)]
pub enum FleetError {
    // ─────────────────────────────────────────────────────────────────────────
    // Wallet errors
    // ─────────────────────────────────────────────────────────────────────────
    /// Wallet not found in the manager.
    #[error("wallet not found: {0}")]
    WalletNotFound(String),

    /// Wallet is currently disabled (e.g., circuit breaker tripped).
    #[error("wallet disabled: {0}")]
    WalletDisabled(String),

    /// Wallet is AFK (away from keyboard) and should not act.
    #[error("wallet is AFK until {0}")]
    WalletAfk(chrono::DateTime<chrono::Utc>),

    // ─────────────────────────────────────────────────────────────────────────
    // Plugin errors
    // ─────────────────────────────────────────────────────────────────────────
    /// Plugin not found in the registry.
    #[error("plugin not found: {0}")]
    PluginNotFound(String),

    /// Unknown action requested from a plugin.
    #[error("unknown action: {0}")]
    UnknownAction(String),

    /// Plugin returned invalid data.
    #[error("invalid plugin data: {0}")]
    InvalidPluginData(String),

    /// Plugin execution failed.
    #[error("plugin execution failed: {0}")]
    PluginExecution(String),

    // ─────────────────────────────────────────────────────────────────────────
    // Safety errors
    // ─────────────────────────────────────────────────────────────────────────
    /// Circuit breaker has tripped for a wallet.
    #[error("circuit breaker tripped for wallet {wallet_id} after {error_count} errors")]
    CircuitBreakerTripped {
        /// The wallet that was tripped.
        wallet_id: String,
        /// Number of consecutive errors before trip.
        error_count: u32,
    },

    /// Global pause is active.
    #[error("global pause is active")]
    GlobalPause,

    // ─────────────────────────────────────────────────────────────────────────
    // Provider errors
    // ─────────────────────────────────────────────────────────────────────────
    /// Chain provider error (wrapped from evm-provider).
    #[error("provider error: {0}")]
    Provider(#[from] evm_provider::ProviderError),

    // ─────────────────────────────────────────────────────────────────────────
    // Configuration errors
    // ─────────────────────────────────────────────────────────────────────────
    /// Invalid configuration value.
    #[error("invalid configuration: {0}")]
    InvalidConfig(String),

    /// Serialization/deserialization error.
    #[error("serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
}

impl FleetError {
    /// Returns true if this error indicates a transient condition that may resolve.
    ///
    /// Transient errors include network issues, rate limits, and temporary
    /// service unavailability. Non-transient errors include invalid data,
    /// missing wallets, and configuration issues.
    #[must_use]
    #[allow(clippy::missing_const_for_fn)] // is_retryable() is not const
    pub fn is_transient(&self) -> bool {
        match self {
            Self::Provider(e) => e.is_retryable(),
            // These are all transient conditions that will resolve on their own
            Self::CircuitBreakerTripped { .. }
            | Self::WalletAfk(_)
            | Self::GlobalPause => true,
            _ => false,
        }
    }

    /// Returns true if this error should trigger circuit breaker increment.
    ///
    /// Some errors (like AFK or global pause) are expected and shouldn't
    /// count toward circuit breaker limits.
    #[must_use]
    pub const fn counts_toward_circuit_breaker(&self) -> bool {
        match self {
            // Expected/config errors - don't count toward breaker
            Self::WalletAfk(_)
            | Self::GlobalPause
            | Self::WalletDisabled(_)
            | Self::CircuitBreakerTripped { .. }
            | Self::PluginNotFound(_)
            | Self::InvalidConfig(_) => false,
            _ => true,
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn transient_errors() {
        assert!(FleetError::GlobalPause.is_transient());
        assert!(!FleetError::WalletNotFound("x".into()).is_transient());
        assert!(!FleetError::InvalidConfig("x".into()).is_transient());
    }

    #[test]
    fn circuit_breaker_counting() {
        assert!(!FleetError::GlobalPause.counts_toward_circuit_breaker());
        assert!(!FleetError::WalletDisabled("x".into()).counts_toward_circuit_breaker());
        assert!(FleetError::PluginExecution("x".into()).counts_toward_circuit_breaker());
    }
}
