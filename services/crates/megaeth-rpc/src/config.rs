//! Configuration for the MegaETH RPC client.
//!
//! This module provides [`ClientConfig`] for customizing client behavior:
//!
//! - Request timeouts
//! - Cursor pagination limits
//! - Future: retry policies, connection pooling
//!
//! # Example
//!
//! ```
//! use megaeth_rpc::ClientConfig;
//! use std::time::Duration;
//!
//! let config = ClientConfig::default()
//!     .with_timeout(Duration::from_secs(60))
//!     .with_max_cursor_batches(200);
//! ```

use std::time::Duration;

use crate::error::{MegaEthError, Result};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Default timeout for HTTP requests to RPC endpoint.
pub const DEFAULT_REQUEST_TIMEOUT: Duration = Duration::from_secs(30);

/// Default maximum batches to fetch in a single cursor pagination operation.
pub const DEFAULT_MAX_CURSOR_BATCHES: usize = 100;

/// Default maximum logs to collect in a single cursor pagination operation.
/// Set to 0 for unlimited (only batch limit applies).
pub const DEFAULT_MAX_LOGS: usize = 0;

/// Maximum allowed logs limit (10 million).
pub const MAX_LOGS_LIMIT: usize = 10_000_000;

/// Minimum allowed timeout.
pub const MIN_TIMEOUT: Duration = Duration::from_secs(1);

/// Maximum allowed timeout.
pub const MAX_TIMEOUT: Duration = Duration::from_secs(300);

/// Minimum allowed cursor batches.
pub const MIN_CURSOR_BATCHES: usize = 1;

/// Maximum allowed cursor batches.
pub const MAX_CURSOR_BATCHES: usize = 10_000;

// ═══════════════════════════════════════════════════════════════════════════════
// CLIENT CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

/// Configuration options for [`MegaEthClient`](crate::MegaEthClient).
///
/// Use the builder pattern to customize settings:
///
/// ```
/// use megaeth_rpc::ClientConfig;
/// use std::time::Duration;
///
/// let config = ClientConfig::default()
///     .with_timeout(Duration::from_secs(60))
///     .with_max_cursor_batches(200)
///     .with_max_logs(100_000);
/// ```
///
/// # Memory Considerations
///
/// When fetching logs with cursor pagination, all logs are accumulated in memory
/// before being returned. For very large queries, this can consume significant memory.
/// Use [`with_max_logs`](Self::with_max_logs) to set a limit on the total number of
/// logs collected.
#[derive(Debug, Clone)]
pub struct ClientConfig {
    /// Request timeout for HTTP calls.
    ///
    /// Default: 30 seconds.
    /// Range: 1-300 seconds.
    pub timeout: Duration,

    /// Maximum number of batches to fetch in a single cursor pagination operation.
    ///
    /// This prevents runaway queries that could consume too much memory.
    /// When this limit is reached, the client returns an error.
    ///
    /// Default: 100 batches.
    /// Range: 1-10,000 batches.
    pub max_cursor_batches: usize,

    /// Maximum number of logs to collect in a single pagination operation.
    ///
    /// This provides memory protection for high-throughput chains where a single
    /// query might return millions of logs. When this limit is reached, the client
    /// returns an error with partial results information.
    ///
    /// Set to 0 (default) for unlimited - only `max_cursor_batches` applies.
    /// Range: 0-10,000,000 logs.
    pub max_logs: usize,
}

impl Default for ClientConfig {
    fn default() -> Self {
        Self {
            timeout: DEFAULT_REQUEST_TIMEOUT,
            max_cursor_batches: DEFAULT_MAX_CURSOR_BATCHES,
            max_logs: DEFAULT_MAX_LOGS,
        }
    }
}

impl ClientConfig {
    /// Create a new configuration with default values.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Set the request timeout.
    ///
    /// # Arguments
    ///
    /// * `timeout` - Request timeout duration (1-300 seconds)
    ///
    /// # Panics
    ///
    /// Does not panic. Invalid values are caught during validation.
    #[must_use]
    pub fn with_timeout(mut self, timeout: Duration) -> Self {
        self.timeout = timeout;
        self
    }

    /// Set the maximum cursor batches.
    ///
    /// # Arguments
    ///
    /// * `max` - Maximum number of batches (1-10,000)
    #[must_use]
    pub fn with_max_cursor_batches(mut self, max: usize) -> Self {
        self.max_cursor_batches = max;
        self
    }

    /// Set the maximum number of logs to collect.
    ///
    /// This provides memory protection for large queries. When the limit is reached,
    /// the client returns an error instead of accumulating more logs.
    ///
    /// # Arguments
    ///
    /// * `max` - Maximum number of logs (0 for unlimited, max 10,000,000)
    ///
    /// # Example
    ///
    /// ```
    /// use megaeth_rpc::ClientConfig;
    ///
    /// // Limit to 100,000 logs to prevent memory exhaustion
    /// let config = ClientConfig::default().with_max_logs(100_000);
    /// ```
    #[must_use]
    pub fn with_max_logs(mut self, max: usize) -> Self {
        self.max_logs = max;
        self
    }

    /// Validate the configuration.
    ///
    /// Called automatically when creating a client. Returns an error if
    /// any values are out of range.
    ///
    /// # Errors
    ///
    /// Returns [`MegaEthError::InvalidConfig`] if:
    /// - Timeout is less than 1 second or greater than 300 seconds
    /// - Max cursor batches is 0 or greater than 10,000
    pub fn validate(&self) -> Result<()> {
        if self.timeout < MIN_TIMEOUT {
            return Err(MegaEthError::InvalidConfig(format!(
                "timeout must be at least {:?}",
                MIN_TIMEOUT
            )));
        }

        if self.timeout > MAX_TIMEOUT {
            return Err(MegaEthError::InvalidConfig(format!(
                "timeout must be at most {:?}",
                MAX_TIMEOUT
            )));
        }

        if self.max_cursor_batches < MIN_CURSOR_BATCHES {
            return Err(MegaEthError::InvalidConfig(format!(
                "max_cursor_batches must be at least {}",
                MIN_CURSOR_BATCHES
            )));
        }

        if self.max_cursor_batches > MAX_CURSOR_BATCHES {
            return Err(MegaEthError::InvalidConfig(format!(
                "max_cursor_batches must be at most {}",
                MAX_CURSOR_BATCHES
            )));
        }

        if self.max_logs > MAX_LOGS_LIMIT {
            return Err(MegaEthError::InvalidConfig(format!(
                "max_logs must be at most {}",
                MAX_LOGS_LIMIT
            )));
        }

        Ok(())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_config() {
        let config = ClientConfig::default();
        assert_eq!(config.timeout, DEFAULT_REQUEST_TIMEOUT);
        assert_eq!(config.max_cursor_batches, DEFAULT_MAX_CURSOR_BATCHES);
        assert!(config.validate().is_ok());
    }

    #[test]
    fn builder_pattern() {
        let config = ClientConfig::new()
            .with_timeout(Duration::from_secs(60))
            .with_max_cursor_batches(200);

        assert_eq!(config.timeout, Duration::from_secs(60));
        assert_eq!(config.max_cursor_batches, 200);
        assert!(config.validate().is_ok());
    }

    #[test]
    fn validate_timeout_too_low() {
        let config = ClientConfig::new().with_timeout(Duration::from_millis(500));
        assert!(config.validate().is_err());
    }

    #[test]
    fn validate_timeout_too_high() {
        let config = ClientConfig::new().with_timeout(Duration::from_secs(600));
        assert!(config.validate().is_err());
    }

    #[test]
    fn validate_cursor_batches_zero() {
        let config = ClientConfig::new().with_max_cursor_batches(0);
        assert!(config.validate().is_err());
    }

    #[test]
    fn validate_cursor_batches_too_high() {
        let config = ClientConfig::new().with_max_cursor_batches(100_000);
        assert!(config.validate().is_err());
    }

    #[test]
    fn validate_edge_cases() {
        // Minimum valid values
        let min_config = ClientConfig::new()
            .with_timeout(MIN_TIMEOUT)
            .with_max_cursor_batches(MIN_CURSOR_BATCHES);
        assert!(min_config.validate().is_ok());

        // Maximum valid values
        let max_config = ClientConfig::new()
            .with_timeout(MAX_TIMEOUT)
            .with_max_cursor_batches(MAX_CURSOR_BATCHES);
        assert!(max_config.validate().is_ok());
    }

    #[test]
    fn max_logs_default_is_unlimited() {
        let config = ClientConfig::default();
        assert_eq!(config.max_logs, 0); // 0 means unlimited
    }

    #[test]
    fn max_logs_builder() {
        let config = ClientConfig::new().with_max_logs(100_000);
        assert_eq!(config.max_logs, 100_000);
        assert!(config.validate().is_ok());
    }

    #[test]
    fn validate_max_logs_too_high() {
        let config = ClientConfig::new().with_max_logs(MAX_LOGS_LIMIT + 1);
        assert!(config.validate().is_err());
    }

    #[test]
    fn validate_max_logs_at_limit() {
        let config = ClientConfig::new().with_max_logs(MAX_LOGS_LIMIT);
        assert!(config.validate().is_ok());
    }
}
