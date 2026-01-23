//! Error types for the MegaETH RPC client.
//!
//! This module provides a comprehensive error hierarchy for MegaETH RPC operations:
//!
//! - [`MegaEthError`] - The primary error type for all client operations
//! - Various error kinds for different failure modes (network, RPC, parsing)
//!
//! # Error Philosophy
//!
//! These errors are designed to be:
//! - **Actionable**: Each variant tells you what went wrong and often how to fix it
//! - **Convertible**: Easy to convert into your application's error types
//! - **Informative**: Contains enough context for debugging without leaking secrets

use std::fmt;

use thiserror::Error;

/// Result type alias using [`MegaEthError`].
pub type Result<T> = std::result::Result<T, MegaEthError>;

/// Errors that can occur when using the MegaETH RPC client.
///
/// This is the primary error type for all operations in this crate.
///
/// # Categories
///
/// Errors fall into these categories:
///
/// | Category | Variants | Typical Cause |
/// |----------|----------|---------------|
/// | Network | `Connection`, `Timeout`, `Http` | Network issues, server down |
/// | Protocol | `Rpc`, `MethodNotSupported` | Server rejected request |
/// | Data | `Serialization`, `InvalidResponse` | Malformed data |
/// | Usage | `InvalidConfig` | Programmer error |
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum MegaEthError {
    /// Failed to establish connection to RPC endpoint.
    ///
    /// This usually indicates the endpoint is unreachable or the URL is invalid.
    #[error("connection failed: {0}")]
    Connection(String),

    /// Request timed out waiting for response.
    ///
    /// Consider increasing the timeout for large queries or checking network conditions.
    /// The actual timeout duration is determined by [`ClientConfig::timeout`](crate::ClientConfig::timeout).
    #[error("request timed out")]
    Timeout,

    /// HTTP-level error (non-2xx status code, TLS issues, etc.).
    #[error("HTTP error: {0}")]
    Http(String),

    /// JSON-RPC error returned by the server.
    ///
    /// Contains the error code and message from the RPC response.
    #[error("RPC error ({code}): {message}")]
    Rpc {
        /// JSON-RPC error code (e.g., -32601 for method not found).
        code: i64,
        /// Human-readable error message from the server.
        message: String,
        /// Optional additional data from the error response.
        data: Option<String>,
    },

    /// The requested RPC method is not supported by this endpoint.
    ///
    /// This is a specific case of [`MegaEthError::Rpc`] for method-not-found errors.
    /// It's separated because callers often want to handle this case specially
    /// (e.g., falling back to standard `eth_getLogs`).
    #[error("method not supported: {method}")]
    MethodNotSupported {
        /// The method name that was not supported.
        method: String,
    },

    /// Failed to serialize request or deserialize response.
    #[error("serialization error: {0}")]
    Serialization(#[from] serde_json::Error),

    /// Response was valid JSON but had unexpected structure.
    ///
    /// This can happen when the RPC returns a different format than expected,
    /// or when required fields are missing.
    #[error("invalid response: {0}")]
    InvalidResponse(String),

    /// Invalid configuration provided to the client.
    ///
    /// Check the configuration values (URL format, timeout range, etc.).
    #[error("invalid configuration: {0}")]
    InvalidConfig(String),

    /// Cursor pagination limit exceeded.
    ///
    /// The query required more batches than the configured maximum.
    /// Consider narrowing the block range or increasing the batch limit.
    #[error("cursor pagination limit exceeded: {batches} batches (max {max})")]
    CursorLimitExceeded {
        /// Number of batches fetched before stopping.
        batches: usize,
        /// Maximum allowed batches.
        max: usize,
    },

    /// Log collection limit exceeded.
    ///
    /// The query returned more logs than the configured maximum.
    /// This protects against memory exhaustion on high-throughput chains.
    /// Consider narrowing the block range or increasing the log limit.
    #[error("log limit exceeded: {collected} logs collected (max {max})")]
    LogLimitExceeded {
        /// Number of logs collected before stopping.
        collected: usize,
        /// Maximum allowed logs.
        max: usize,
    },
}

impl MegaEthError {
    /// Create an RPC error from code and message.
    #[must_use]
    pub fn rpc(code: i64, message: impl Into<String>) -> Self {
        Self::Rpc {
            code,
            message: message.into(),
            data: None,
        }
    }

    /// Create an RPC error with additional data.
    #[must_use]
    pub fn rpc_with_data(code: i64, message: impl Into<String>, data: impl Into<String>) -> Self {
        Self::Rpc {
            code,
            message: message.into(),
            data: Some(data.into()),
        }
    }

    /// Check if this error indicates the method is not supported.
    ///
    /// Returns `true` for both [`MegaEthError::MethodNotSupported`] and
    /// [`MegaEthError::Rpc`] with method-not-found error codes.
    #[must_use]
    pub const fn is_method_not_supported(&self) -> bool {
        match self {
            Self::MethodNotSupported { .. } => true,
            Self::Rpc { code, .. } => {
                // -32601 = Method not found (JSON-RPC standard)
                // -32600 = Invalid request (some providers use this for unsupported methods)
                *code == -32601 || *code == -32600
            }
            _ => false,
        }
    }

    /// Check if this error is likely transient and retryable.
    ///
    /// Returns `true` for network issues, timeouts, and server-side errors
    /// that might succeed on retry.
    #[must_use]
    pub fn is_retryable(&self) -> bool {
        match self {
            Self::Connection(_) | Self::Timeout => true,
            Self::Http(msg) => {
                // 5xx errors are typically retryable
                msg.contains("500")
                    || msg.contains("502")
                    || msg.contains("503")
                    || msg.contains("504")
            }
            Self::Rpc { code, .. } => {
                // Server overloaded or rate limited
                *code == -32005 // Limit exceeded
                    || *code == -32000 // Server error (generic)
            }
            _ => false,
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERSIONS FROM reqwest ERRORS
// ═══════════════════════════════════════════════════════════════════════════════

impl From<reqwest::Error> for MegaEthError {
    fn from(err: reqwest::Error) -> Self {
        if err.is_timeout() {
            Self::Timeout
        } else if err.is_connect() {
            Self::Connection(err.to_string())
        } else if err.is_request() || err.is_body() || err.is_decode() {
            Self::Http(err.to_string())
        } else {
            Self::Connection(err.to_string())
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RPC ERROR DETAILS
// ═══════════════════════════════════════════════════════════════════════════════

/// Detailed information from a JSON-RPC error response.
///
/// Used internally for parsing error responses from the server.
#[derive(Debug, Clone, serde::Deserialize)]
pub(crate) struct RpcErrorDetail {
    /// JSON-RPC error code.
    pub code: i64,
    /// Human-readable error message.
    pub message: String,
    /// Optional additional error data.
    #[serde(default)]
    pub data: Option<serde_json::Value>,
}

impl RpcErrorDetail {
    /// Convert this detail into a [`MegaEthError`].
    pub fn into_error(self, method: &str) -> MegaEthError {
        // Check for method not supported
        if self.code == -32601 || self.code == -32600 {
            return MegaEthError::MethodNotSupported {
                method: method.to_string(),
            };
        }

        MegaEthError::Rpc {
            code: self.code,
            message: self.message,
            data: self.data.map(|v| v.to_string()),
        }
    }
}

impl fmt::Display for RpcErrorDetail {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "RPC error ({}): {}", self.code, self.message)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_is_method_not_supported() {
        let explicit = MegaEthError::MethodNotSupported {
            method: "eth_getLogsWithCursor".into(),
        };
        assert!(explicit.is_method_not_supported());

        let rpc_32601 = MegaEthError::rpc(-32601, "Method not found");
        assert!(rpc_32601.is_method_not_supported());

        let rpc_32600 = MegaEthError::rpc(-32600, "Invalid request");
        assert!(rpc_32600.is_method_not_supported());

        let rpc_other = MegaEthError::rpc(-32000, "Server error");
        assert!(!rpc_other.is_method_not_supported());
    }

    #[test]
    fn error_is_retryable() {
        let timeout = MegaEthError::Timeout;
        assert!(timeout.is_retryable());

        let connection = MegaEthError::Connection("connection refused".into());
        assert!(connection.is_retryable());

        let http_503 = MegaEthError::Http("503 Service Unavailable".into());
        assert!(http_503.is_retryable());

        let method_not_supported = MegaEthError::MethodNotSupported {
            method: "test".into(),
        };
        assert!(!method_not_supported.is_retryable());

        let serialization = MegaEthError::InvalidResponse("missing field".into());
        assert!(!serialization.is_retryable());
    }

    #[test]
    fn rpc_error_detail_deserialization() {
        let json = r#"{"code": -32601, "message": "Method not found"}"#;
        let detail: RpcErrorDetail = serde_json::from_str(json).expect("parse failed");
        assert_eq!(detail.code, -32601);
        assert_eq!(detail.message, "Method not found");
        assert!(detail.data.is_none());
    }

    #[test]
    fn rpc_error_detail_with_data() {
        let json = r#"{"code": -32000, "message": "Server error", "data": {"reason": "overloaded"}}"#;
        let detail: RpcErrorDetail = serde_json::from_str(json).expect("parse failed");
        assert_eq!(detail.code, -32000);
        assert!(detail.data.is_some());
    }

    #[test]
    fn rpc_error_detail_into_method_not_supported() {
        let detail = RpcErrorDetail {
            code: -32601,
            message: "Method not found".into(),
            data: None,
        };
        let error = detail.into_error("eth_getLogsWithCursor");
        assert!(matches!(error, MegaEthError::MethodNotSupported { method } if method == "eth_getLogsWithCursor"));
    }
}
