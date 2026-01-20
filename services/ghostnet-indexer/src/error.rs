//! Layered error types for the GHOSTNET Event Indexer.
//!
//! This module provides a hierarchical error system:
//!
//! - [`DomainError`] - Business logic errors (invalid state, not found, etc.)
//! - [`InfraError`] - Infrastructure errors (database, RPC, streaming)
//! - [`AppError`] - Application-level errors combining domain and infra
//! - [`ApiError`] - HTTP API errors with status codes
//!
//! # Error Philosophy
//!
//! - Domain errors are recoverable and user-facing
//! - Infrastructure errors are logged but details hidden from users
//! - The `Result` type alias uses `AppError` for application code

use axum::Json;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use serde_json::json;
use thiserror::Error;

// ═══════════════════════════════════════════════════════════════════════════════
// DOMAIN ERRORS
// ═══════════════════════════════════════════════════════════════════════════════

/// Domain-level errors representing business logic violations.
///
/// These errors are recoverable and should be shown to users.
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum DomainError {
    /// Invalid level value (must be 0-5).
    #[error("invalid level value: {0}")]
    InvalidLevel(u8),

    /// Position not found for the given address.
    #[error("position not found for address: {0}")]
    PositionNotFound(String),

    /// Scan not found.
    #[error("scan not found: level={level}, scan_id={scan_id}")]
    ScanNotFound {
        /// The level that was searched.
        level: u8,
        /// The scan ID that was searched.
        scan_id: String,
    },

    /// Round not found.
    #[error("round not found: {0}")]
    RoundNotFound(String),

    /// Invalid state transition.
    #[error("invalid state transition: {from} -> {to}")]
    InvalidStateTransition {
        /// Current state.
        from: String,
        /// Attempted new state.
        to: String,
    },

    /// Position already exists for address.
    #[error("position already exists for address: {0}")]
    PositionAlreadyExists(String),

    /// Round already resolved.
    #[error("round already resolved: {0}")]
    RoundAlreadyResolved(String),

    /// Betting is closed for this round.
    #[error("betting closed for round: {0}")]
    BettingClosed(String),

    /// Invalid boost type.
    #[error("invalid boost type: {0}")]
    InvalidBoostType(u8),

    /// Invalid round type.
    #[error("invalid round type: {0}")]
    InvalidRoundType(u8),

    /// Invalid address format.
    #[error("invalid address: {0}")]
    InvalidAddress(String),

    /// Invalid amount (negative or malformed).
    #[error("invalid amount: {0}")]
    InvalidAmount(String),
}

// ═══════════════════════════════════════════════════════════════════════════════
// INFRASTRUCTURE ERRORS
// ═══════════════════════════════════════════════════════════════════════════════

/// Infrastructure-level errors from external systems.
///
/// These errors are typically logged but their details are hidden from users.
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum InfraError {
    /// Database error.
    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),

    /// RPC error (Ethereum node communication).
    #[error("RPC error: {0}")]
    Rpc(#[source] Box<dyn std::error::Error + Send + Sync>),

    /// Streaming error (Apache Iggy).
    #[error("streaming error: {0}")]
    Streaming(#[source] Box<dyn std::error::Error + Send + Sync>),

    /// JSON serialization/deserialization error.
    #[error("serialization error: {0}")]
    Serialization(#[from] serde_json::Error),

    /// Event decoding error.
    #[error("event decoding error: {0}")]
    EventDecoding(String),

    /// Resource not found in storage.
    #[error("resource not found")]
    NotFound,

    /// Connection pool exhausted.
    #[error("connection pool exhausted")]
    PoolExhausted,

    /// Timeout waiting for operation.
    #[error("operation timed out: {0}")]
    Timeout(String),

    /// Configuration file error.
    #[error("configuration error: {0}")]
    Config(#[from] config::ConfigError),
}

// ═══════════════════════════════════════════════════════════════════════════════
// APPLICATION ERRORS
// ═══════════════════════════════════════════════════════════════════════════════

/// Application-level errors combining domain and infrastructure errors.
///
/// This is the primary error type used throughout the application.
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum AppError {
    /// Domain logic error.
    #[error(transparent)]
    Domain(#[from] DomainError),

    /// Infrastructure error.
    #[error(transparent)]
    Infra(#[from] InfraError),

    /// Chain reorganization detected.
    #[error("chain reorg detected at block {0}")]
    ReorgDetected(u64),

    /// Configuration error.
    #[error("configuration error: {0}")]
    Config(String),

    /// Initialization error.
    #[error("initialization error: {0}")]
    Initialization(String),

    /// Graceful shutdown requested.
    #[error("shutdown requested")]
    ShutdownRequested,
}

/// Type alias for application Results.
pub type Result<T> = std::result::Result<T, AppError>;

// ═══════════════════════════════════════════════════════════════════════════════
// API ERRORS (HTTP-specific)
// ═══════════════════════════════════════════════════════════════════════════════

/// API-level errors with HTTP status codes.
///
/// These errors are converted to HTTP responses via [`IntoResponse`].
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum ApiError {
    /// Wrapped application error.
    #[error(transparent)]
    App(#[from] AppError),

    /// Rate limit exceeded.
    #[error("rate limited: retry after {retry_after_secs} seconds")]
    RateLimited {
        /// Seconds until rate limit resets.
        retry_after_secs: u64,
    },

    /// Invalid request parameters.
    #[error("invalid request: {0}")]
    BadRequest(String),

    /// Authentication required or failed.
    #[error("unauthorized")]
    Unauthorized,

    /// Internal server error (with source for logging).
    #[error("internal error")]
    Internal(#[source] eyre::Report),
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, code, message) = match &self {
            // Domain errors map to client errors (4xx)
            Self::App(AppError::Domain(
                DomainError::PositionNotFound(_)
                | DomainError::ScanNotFound { .. }
                | DomainError::RoundNotFound(_),
            )) => (StatusCode::NOT_FOUND, "NOT_FOUND", self.to_string()),

            Self::App(AppError::Domain(
                DomainError::InvalidLevel(_)
                | DomainError::InvalidStateTransition { .. }
                | DomainError::InvalidBoostType(_)
                | DomainError::InvalidRoundType(_)
                | DomainError::InvalidAddress(_)
                | DomainError::InvalidAmount(_)
                | DomainError::BettingClosed(_),
            ))
            | Self::BadRequest(_) => (StatusCode::BAD_REQUEST, "BAD_REQUEST", self.to_string()),

            Self::App(AppError::Domain(
                DomainError::PositionAlreadyExists(_) | DomainError::RoundAlreadyResolved(_),
            )) => (StatusCode::CONFLICT, "CONFLICT", self.to_string()),

            Self::RateLimited { retry_after_secs } => {
                return (
                    StatusCode::TOO_MANY_REQUESTS,
                    [("Retry-After", retry_after_secs.to_string())],
                    Json(json!({
                        "error": {
                            "code": "RATE_LIMITED",
                            "message": self.to_string(),
                            "retry_after_secs": retry_after_secs
                        }
                    })),
                )
                    .into_response();
            }

            Self::Unauthorized => (StatusCode::UNAUTHORIZED, "UNAUTHORIZED", self.to_string()),

            // Infrastructure and internal errors: log but don't expose details
            Self::App(
                AppError::Infra(_)
                | AppError::ReorgDetected(_)
                | AppError::Config(_)
                | AppError::Initialization(_)
                | AppError::ShutdownRequested,
            )
            | Self::Internal(_) => {
                tracing::error!(error = ?self, "Internal error");
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "INTERNAL_ERROR",
                    "Internal error".into(),
                )
            }
        };

        (
            status,
            Json(json!({
                "error": {
                    "code": code,
                    "message": message
                }
            })),
        )
            .into_response()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONVENIENCE CONVERSIONS
// ═══════════════════════════════════════════════════════════════════════════════

impl From<crate::types::enums::InvalidLevel> for DomainError {
    fn from(err: crate::types::enums::InvalidLevel) -> Self {
        Self::InvalidLevel(err.0)
    }
}

impl From<crate::types::enums::InvalidBoostType> for DomainError {
    fn from(err: crate::types::enums::InvalidBoostType) -> Self {
        Self::InvalidBoostType(err.0)
    }
}

impl From<crate::types::enums::InvalidRoundType> for DomainError {
    fn from(err: crate::types::enums::InvalidRoundType) -> Self {
        Self::InvalidRoundType(err.0)
    }
}

impl From<crate::types::primitives::InvalidAddress> for DomainError {
    fn from(err: crate::types::primitives::InvalidAddress) -> Self {
        Self::InvalidAddress(err.to_string())
    }
}

impl From<crate::types::primitives::InvalidAmount> for DomainError {
    fn from(err: crate::types::primitives::InvalidAmount) -> Self {
        Self::InvalidAmount(err.to_string())
    }
}

// Allow converting domain errors into application errors
impl From<crate::types::enums::InvalidLevel> for AppError {
    fn from(err: crate::types::enums::InvalidLevel) -> Self {
        Self::Domain(err.into())
    }
}

impl From<crate::types::enums::InvalidBoostType> for AppError {
    fn from(err: crate::types::enums::InvalidBoostType) -> Self {
        Self::Domain(err.into())
    }
}

impl From<crate::types::enums::InvalidRoundType> for AppError {
    fn from(err: crate::types::enums::InvalidRoundType) -> Self {
        Self::Domain(err.into())
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn domain_error_display() {
        let err = DomainError::PositionNotFound("0x1234".into());
        assert!(err.to_string().contains("0x1234"));
    }

    #[test]
    fn app_error_from_domain() {
        let domain = DomainError::InvalidLevel(99);
        let app: AppError = domain.into();
        assert!(matches!(
            app,
            AppError::Domain(DomainError::InvalidLevel(99))
        ));
    }

    #[test]
    fn app_error_from_infra() {
        let infra = InfraError::NotFound;
        let app: AppError = infra.into();
        assert!(matches!(app, AppError::Infra(InfraError::NotFound)));
    }
}
