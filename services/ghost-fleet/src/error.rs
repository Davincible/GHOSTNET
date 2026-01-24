//! Error types for the Ghost Fleet service.

use std::path::PathBuf;

use thiserror::Error;

/// Result type for Ghost Fleet operations.
pub type Result<T> = std::result::Result<T, FleetServiceError>;

/// Errors that can occur in the Ghost Fleet service.
#[derive(Debug, Error)]
#[allow(dead_code)] // Public API - some variants used in future
pub enum FleetServiceError {
    /// Configuration error.
    #[error("Configuration error: {0}")]
    Config(#[from] ConfigError),

    /// Provider error.
    #[error("Provider error: {0}")]
    Provider(#[from] evm_provider::ProviderError),

    /// Fleet core error.
    #[error("Fleet error: {0}")]
    Fleet(#[from] fleet_core::FleetError),

    /// Plugin error.
    #[error("Plugin error: {0}")]
    Plugin(String),

    /// Wallet not found.
    #[error("Wallet not found: {0}")]
    WalletNotFound(String),

    /// No signer available for wallet.
    #[error("No signer for wallet: {0}")]
    NoSigner(String),

    /// Internal error.
    #[error("Internal error: {0}")]
    Internal(String),
}

/// Configuration-specific errors.
#[derive(Debug, Error)]
pub enum ConfigError {
    /// Failed to read config file.
    #[error("Failed to read config file {path}: {source}")]
    FileRead {
        /// Path to the file.
        path: PathBuf,
        /// IO error.
        source: std::io::Error,
    },

    /// Failed to parse config file.
    #[error("Failed to parse config file {path}: {source}")]
    Parse {
        /// Path to the file.
        path: PathBuf,
        /// TOML parse error.
        source: toml::de::Error,
    },

    /// Validation error.
    #[error("Config validation failed: {0}")]
    Validation(String),
}
