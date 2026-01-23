//! Error types for EVM provider operations.
//!
//! This module provides a comprehensive error hierarchy for chain provider operations:
//!
//! - [`ProviderError`] - The primary error type for all provider operations
//! - Error variants for network, RPC, data, and configuration issues
//!
//! # Error Philosophy
//!
//! These errors are designed to be:
//! - **Actionable**: Each variant tells you what went wrong and suggests remediation
//! - **Convertible**: Easy to convert from underlying provider errors
//! - **Chain-agnostic**: Same error types regardless of the underlying chain

use alloy::primitives::{Address, TxHash};
use std::time::Duration;
use thiserror::Error;

/// Result type alias using [`ProviderError`].
pub type Result<T> = std::result::Result<T, ProviderError>;

/// Errors that can occur when using an EVM chain provider.
///
/// This is the primary error type for all operations in this crate.
///
/// # Categories
///
/// Errors fall into these categories:
///
/// | Category | Variants | Typical Cause |
/// |----------|----------|---------------|
/// | Network | `Connection`, `Timeout` | Network issues, server down |
/// | Protocol | `Rpc`, `Unsupported` | Server rejected request |
/// | Transaction | `TransactionFailed`, `NonceTooLow` | Tx execution issues |
/// | Data | `InvalidResponse`, `Encoding` | Malformed data |
/// | Configuration | `InvalidConfig` | Programmer error |
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum ProviderError {
    /// Failed to establish connection to RPC endpoint.
    ///
    /// This usually indicates the endpoint is unreachable or the URL is invalid.
    #[error("connection failed: {0}")]
    Connection(String),

    /// Request timed out waiting for response.
    ///
    /// Consider increasing the timeout or checking network conditions.
    #[error("request timed out after {0:?}")]
    Timeout(Duration),

    /// JSON-RPC error returned by the server.
    ///
    /// Contains the error code and message from the RPC response.
    #[error("RPC error ({code}): {message}")]
    Rpc {
        /// JSON-RPC error code (e.g., -32601 for method not found).
        code: i64,
        /// Human-readable error message from the server.
        message: String,
    },

    /// The requested operation is not supported by this provider or chain.
    ///
    /// This is common when using chain-specific features on standard providers.
    #[error("operation not supported: {0}")]
    Unsupported(String),

    /// Transaction execution failed on-chain.
    ///
    /// The transaction was submitted but reverted during execution.
    #[error("transaction {tx_hash} failed: {reason}")]
    TransactionFailed {
        /// The transaction hash.
        tx_hash: TxHash,
        /// Reason for failure (e.g., revert message).
        reason: String,
    },

    /// Transaction receipt not found after waiting.
    ///
    /// The transaction may still be pending or may have been dropped.
    #[error("transaction {0} not found after waiting")]
    ReceiptNotFound(TxHash),

    /// Nonce is too low (transaction already executed with this nonce).
    ///
    /// This typically indicates a nonce synchronization issue.
    #[error("nonce too low for {address}: expected >= {expected}, got {actual}")]
    NonceTooLow {
        /// The address sending the transaction.
        address: Address,
        /// The nonce that was expected.
        expected: u64,
        /// The nonce that was provided.
        actual: u64,
    },

    /// Failed to encode or decode transaction data.
    #[error("encoding error: {0}")]
    Encoding(String),

    /// Response was valid but had unexpected structure.
    ///
    /// This can happen when the RPC returns a different format than expected.
    #[error("invalid response: {0}")]
    InvalidResponse(String),

    /// Invalid configuration provided to the provider.
    #[error("invalid configuration: {0}")]
    InvalidConfig(String),

    /// Insufficient balance for the requested operation.
    #[error("insufficient balance: {address} has {balance}, needs {required}")]
    InsufficientBalance {
        /// The address with insufficient funds.
        address: Address,
        /// Current balance.
        balance: String,
        /// Required balance.
        required: String,
    },

    /// Generic provider error wrapping underlying implementation errors.
    ///
    /// Used when errors don't fit other categories.
    #[error("provider error: {0}")]
    Other(String),
}

impl ProviderError {
    /// Create an RPC error from code and message.
    #[must_use]
    pub fn rpc(code: i64, message: impl Into<String>) -> Self {
        Self::Rpc {
            code,
            message: message.into(),
        }
    }

    /// Create an unsupported operation error.
    #[must_use]
    pub fn unsupported(operation: impl Into<String>) -> Self {
        Self::Unsupported(operation.into())
    }

    /// Check if this error is likely transient and retryable.
    ///
    /// Returns `true` for network issues and timeouts that might succeed on retry.
    #[must_use]
    pub const fn is_retryable(&self) -> bool {
        match self {
            Self::Connection(_) | Self::Timeout(_) => true,
            Self::Rpc { code, .. } => {
                // Server overloaded or rate limited
                *code == -32005  // Limit exceeded
                    || *code == -32000 // Server error (generic)
            }
            _ => false,
        }
    }

    /// Check if this is a nonce-related error that can be fixed by resync.
    #[must_use]
    pub const fn is_nonce_error(&self) -> bool {
        matches!(self, Self::NonceTooLow { .. })
    }

    /// Check if this error indicates insufficient funds.
    #[must_use]
    pub const fn is_insufficient_balance(&self) -> bool {
        matches!(self, Self::InsufficientBalance { .. })
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERSIONS FROM alloy ERRORS
// ═══════════════════════════════════════════════════════════════════════════════

impl From<alloy::transports::TransportError> for ProviderError {
    fn from(err: alloy::transports::TransportError) -> Self {
        // Parse the error to categorize it
        // Note: This is string-based because alloy doesn't expose structured error types
        let msg = err.to_string();
        let msg_lower = msg.to_lowercase();

        if msg_lower.contains("timeout") || msg_lower.contains("timed out") {
            // Use Connection variant to preserve the original message since we
            // don't know the actual timeout duration
            Self::Connection(format!("request timed out: {msg}"))
        } else if msg_lower.contains("connection")
            || msg_lower.contains("connect")
            || msg_lower.contains("refused")
        {
            Self::Connection(msg)
        } else {
            Self::Other(msg)
        }
    }
}

impl From<alloy::contract::Error> for ProviderError {
    fn from(err: alloy::contract::Error) -> Self {
        Self::Encoding(err.to_string())
    }
}

impl From<alloy::sol_types::Error> for ProviderError {
    fn from(err: alloy::sol_types::Error) -> Self {
        Self::Encoding(err.to_string())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_is_retryable() {
        let timeout = ProviderError::Timeout(Duration::from_secs(30));
        assert!(timeout.is_retryable());

        let connection = ProviderError::Connection("connection refused".into());
        assert!(connection.is_retryable());

        let rpc_limit = ProviderError::rpc(-32005, "rate limited");
        assert!(rpc_limit.is_retryable());

        let unsupported = ProviderError::unsupported("cursor pagination");
        assert!(!unsupported.is_retryable());
    }

    #[test]
    fn error_is_nonce_error() {
        let nonce_low = ProviderError::NonceTooLow {
            address: Address::ZERO,
            expected: 10,
            actual: 5,
        };
        assert!(nonce_low.is_nonce_error());

        let timeout = ProviderError::Timeout(Duration::from_secs(30));
        assert!(!timeout.is_nonce_error());
    }

    #[test]
    fn error_is_insufficient_balance() {
        let insufficient = ProviderError::InsufficientBalance {
            address: Address::ZERO,
            balance: "1.0 ETH".into(),
            required: "2.0 ETH".into(),
        };
        assert!(insufficient.is_insufficient_balance());

        let timeout = ProviderError::Timeout(Duration::from_secs(30));
        assert!(!timeout.is_insufficient_balance());
    }
}
