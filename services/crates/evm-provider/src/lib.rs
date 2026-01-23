//! Chain abstraction layer for EVM-compatible blockchains.
//!
//! This crate provides a unified interface for interacting with EVM chains,
//! abstracting away chain-specific quirks and providing a consistent API.
//!
//! # Overview
//!
//! The core of this crate is the [`ChainProvider`] trait, which defines basic
//! blockchain operations (balance queries, transaction sending, etc.). For chains
//! with extended capabilities (like MegaETH's realtime API), the
//! [`ExtendedChainProvider`] trait adds optional methods.
//!
//! # Quick Start
//!
//! ```ignore
//! use evm_provider::{ChainProvider, TransactionRequest};
//! use alloy::primitives::{Address, U256};
//!
//! async fn check_balance<P: ChainProvider>(provider: &P, address: Address) {
//!     let balance = provider.get_balance(address).await.unwrap();
//!     println!("Balance: {} wei", balance);
//! }
//! ```
//!
//! # Features
//!
//! - **Chain-agnostic interface**: Same code works with any EVM chain
//! - **Extended capabilities**: Optional support for MegaETH's realtime API
//! - **Thread-safe nonce management**: For high-throughput transaction sending
//! - **Type-safe transactions**: Builder pattern for constructing requests
//!
//! # Modules
//!
//! - [`traits`] - Core [`ChainProvider`] and [`ExtendedChainProvider`] traits
//! - [`types`] - Transaction requests, receipts, and log filters
//! - [`nonce`] - Thread-safe nonce management via [`LocalNonceManager`]
//! - [`error`] - Error types with detailed context
//!
//! # Feature Flags
//!
//! - `megaeth` - Enables [`MegaEthProvider`] implementation (requires `megaeth-rpc` crate)
//!
//! # Provider Implementations
//!
//! | Provider | Chain Support | Extended Features |
//! |----------|--------------|-------------------|
//! | `StandardEvmProvider` | Any EVM chain | No |
//! | `MegaEthProvider` | MegaETH | Realtime API, cursor pagination |
//!
//! # Architecture
//!
//! This crate follows the ports-and-adapters (hexagonal) architecture:
//!
//! ```text
//! ┌─────────────────────────────────────────────────┐
//! │              Your Application                    │
//! └─────────────────────────────────────────────────┘
//!                        │
//!                        │ uses
//!                        ▼
//! ┌─────────────────────────────────────────────────┐
//! │           ChainProvider trait (Port)            │
//! │  - get_balance()                                │
//! │  - send_raw_transaction()                       │
//! │  - wait_for_receipt()                           │
//! └─────────────────────────────────────────────────┘
//!                        │
//!          ┌─────────────┴─────────────┐
//!          │                           │
//!          ▼                           ▼
//! ┌─────────────────┐       ┌─────────────────────┐
//! │ StandardEvm     │       │ MegaEthProvider     │
//! │ Provider        │       │ (Adapter)           │
//! │ (Adapter)       │       │                     │
//! │                 │       │ + realtime API      │
//! │ uses: alloy     │       │ + cursor pagination │
//! │                 │       │ uses: megaeth-rpc   │
//! └─────────────────┘       └─────────────────────┘
//! ```

#![doc(html_root_url = "https://docs.ghostnet.io/evm-provider")]

// ═══════════════════════════════════════════════════════════════════════════════
// MODULES
// ═══════════════════════════════════════════════════════════════════════════════

pub mod error;
pub mod nonce;
pub mod traits;
pub mod types;

// Future: Provider implementations
// pub mod standard;  // StandardEvmProvider using alloy
// #[cfg(feature = "megaeth")]
// pub mod megaeth;   // MegaEthProvider using megaeth-rpc

// ═══════════════════════════════════════════════════════════════════════════════
// RE-EXPORTS
// ═══════════════════════════════════════════════════════════════════════════════

// Primary types - what most users need
pub use error::{ProviderError, Result};
pub use nonce::LocalNonceManager;
pub use traits::{ChainProvider, ExtendedChainProvider, NonceManager};
pub use types::{LogFilter, LogsPage, TransactionReceipt, TransactionRequest};

// ═══════════════════════════════════════════════════════════════════════════════
// PRELUDE
// ═══════════════════════════════════════════════════════════════════════════════

/// Convenience re-exports for common use.
///
/// # Usage
///
/// ```ignore
/// use evm_provider::prelude::*;
/// ```
pub mod prelude {
    pub use crate::error::{ProviderError, Result};
    pub use crate::nonce::LocalNonceManager;
    pub use crate::traits::{ChainProvider, ExtendedChainProvider, NonceManager};
    pub use crate::types::{LogFilter, LogsPage, TransactionReceipt, TransactionRequest};
}

// ═══════════════════════════════════════════════════════════════════════════════
// CRATE INFO
// ═══════════════════════════════════════════════════════════════════════════════

/// Crate version.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Returns the crate version string.
#[must_use]
pub const fn version() -> &'static str {
    VERSION
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_is_set() {
        assert!(!version().is_empty());
        assert!(version().starts_with("0."));
    }

    #[test]
    fn exports_are_available() {
        // Verify main types are exported
        let _: fn() -> TransactionRequest = TransactionRequest::new;
        let _: fn(u64, u64) -> LogFilter = LogFilter::new;

        // Error type
        let _err: ProviderError = ProviderError::unsupported("test");
    }

    #[test]
    fn prelude_works() {
        use crate::prelude::*;

        let request = TransactionRequest::new();
        assert!(request.to.is_none());

        let filter = LogFilter::new(0, 100);
        assert_eq!(filter.from_block, Some(0));
    }
}
