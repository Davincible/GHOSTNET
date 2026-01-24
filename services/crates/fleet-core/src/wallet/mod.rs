//! Wallet state management.
//!
//! This module provides types for tracking wallet state including balances,
//! nonces, and plugin-specific data.
//!
//! # Overview
//!
//! The core type is [`WalletState`], which tracks everything needed for
//! a managed wallet:
//!
//! - Native and token balances
//! - Transaction nonce
//! - Plugin-specific state (e.g., protocol positions)
//! - Timing (last action, next scheduled action)
//! - Health (active, error count, AFK status)
//!
//! # Example
//!
//! ```
//! use fleet_core::wallet::WalletState;
//! use alloy::primitives::{Address, U256};
//!
//! // Create a new wallet
//! let mut wallet = WalletState::with_profile(
//!     "whale_1".to_string(),
//!     Address::ZERO,
//!     "whale".to_string(),
//! );
//!
//! // Update from chain state
//! wallet.set_native_balance(U256::from(1_000_000_000_000_000_000u64));
//! wallet.set_nonce(42);
//!
//! // Check readiness
//! if wallet.is_active() && wallet.is_due() {
//!     // Ready for action
//! }
//! ```

mod state;

pub use state::WalletState;
