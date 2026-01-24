//! Error types for the GHOSTNET actions plugin.

use alloy::primitives::Address;
use thiserror::Error;

/// Result type alias for GHOSTNET operations.
pub type Result<T> = std::result::Result<T, GhostnetError>;

/// Errors that can occur in GHOSTNET plugin operations.
#[derive(Debug, Error)]
pub enum GhostnetError {
    // ─────────────────────────────────────────────────────────────────────────
    // Position errors
    // ─────────────────────────────────────────────────────────────────────────
    /// No position exists for the wallet.
    #[error("no position exists for {0}")]
    NoPosition(Address),

    /// Position is dead (traced).
    #[error("position is dead for {0}")]
    PositionDead(Address),

    /// Position already exists when trying to create new one.
    #[error("position already exists for {0}")]
    PositionExists(Address),

    /// Position is in lock period.
    #[error("position is locked until {0}")]
    PositionLocked(chrono::DateTime<chrono::Utc>),

    // ─────────────────────────────────────────────────────────────────────────
    // Balance errors
    // ─────────────────────────────────────────────────────────────────────────
    /// Insufficient DATA token balance.
    #[error("insufficient DATA balance: have {have}, need {need}")]
    InsufficientData {
        /// Current balance in wei.
        have: alloy::primitives::U256,
        /// Required balance in wei.
        need: alloy::primitives::U256,
    },

    /// Insufficient native (ETH) balance for gas.
    #[error("insufficient ETH for gas: have {have}, need {need}")]
    InsufficientGas {
        /// Current balance in wei.
        have: alloy::primitives::U256,
        /// Estimated required balance in wei.
        need: alloy::primitives::U256,
    },

    // ─────────────────────────────────────────────────────────────────────────
    // Arcade errors
    // ─────────────────────────────────────────────────────────────────────────
    /// HashCrash round is not accepting bets.
    #[error("HashCrash round {0} is not accepting bets")]
    RoundNotBetting(u64),

    /// HashCrash bet amount out of range.
    #[error("bet amount {amount} is out of range [{min}, {max}]")]
    BetAmountOutOfRange {
        /// The attempted bet amount.
        amount: alloy::primitives::U256,
        /// Minimum allowed bet.
        min: alloy::primitives::U256,
        /// Maximum allowed bet.
        max: alloy::primitives::U256,
    },

    /// HashCrash target multiplier out of range.
    #[error("target multiplier {target} is out of range [101, 10000]")]
    TargetMultiplierOutOfRange {
        /// The attempted target multiplier.
        target: u16,
    },

    // ─────────────────────────────────────────────────────────────────────────
    // Configuration errors
    // ─────────────────────────────────────────────────────────────────────────
    /// Invalid configuration.
    #[error("invalid configuration: {0}")]
    InvalidConfig(String),

    /// Invalid action data.
    #[error("invalid action data: {0}")]
    InvalidActionData(String),

    /// Invalid level.
    #[error("invalid level: {0}")]
    InvalidLevel(u8),

    // ─────────────────────────────────────────────────────────────────────────
    // Contract/Provider errors
    // ─────────────────────────────────────────────────────────────────────────
    /// Contract call failed.
    #[error("contract call failed: {0}")]
    ContractCall(String),

    /// Transaction failed.
    #[error("transaction failed: {0}")]
    TransactionFailed(String),

    /// Provider error.
    #[error("provider error: {0}")]
    Provider(#[from] evm_provider::ProviderError),

    /// Fleet core error.
    #[error("fleet error: {0}")]
    Fleet(#[from] fleet_core::FleetError),

    /// Serialization error.
    #[error("serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
}

impl GhostnetError {
    /// Returns true if this error is transient and the operation may succeed on retry.
    #[must_use]
    pub const fn is_transient(&self) -> bool {
        matches!(
            self,
            Self::Provider(_) | Self::ContractCall(_) | Self::TransactionFailed(_)
        )
    }

    /// Returns true if this error indicates insufficient balance.
    #[must_use]
    pub const fn is_insufficient_balance(&self) -> bool {
        matches!(self, Self::InsufficientData { .. } | Self::InsufficientGas { .. })
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::primitives::{Address, U256};

    #[test]
    fn transient_errors() {
        assert!(GhostnetError::ContractCall("test".into()).is_transient());
        assert!(GhostnetError::TransactionFailed("test".into()).is_transient());
        assert!(!GhostnetError::NoPosition(Address::ZERO).is_transient());
    }

    #[test]
    fn insufficient_balance_errors() {
        assert!(GhostnetError::InsufficientData {
            have: U256::ZERO,
            need: U256::from(100),
        }
        .is_insufficient_balance());

        assert!(!GhostnetError::InvalidLevel(0).is_insufficient_balance());
    }
}
