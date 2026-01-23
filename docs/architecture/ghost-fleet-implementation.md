# Ghost Fleet: Implementation Specification
## Technical Design Document

**Version:** 2.0  
**Status:** Draft  
**Date:** January 2026  

> **Prerequisites**: Read `ghost-fleet-requirements.md` first for context.

---

## Table of Contents

1. [Crate Architecture](#1-crate-architecture)
2. [Chain Abstraction](#2-chain-abstraction)
3. [Action Plugin System](#3-action-plugin-system)
4. [MegaETH Client Crate](#4-megaeth-client-crate)
5. [Fleet Core Crate](#5-fleet-core-crate)
6. [GHOSTNET Actions Plugin](#6-ghostnet-actions-plugin)
7. [Main Service](#7-main-service)
8. [Configuration](#8-configuration)
9. [Testing Strategy](#9-testing-strategy)
10. [Migration Plan](#10-migration-plan)
11. [Implementation Phases](#11-implementation-phases)

---

## 1. Crate Architecture

### 1.1 Workspace Structure

```
services/
├── Cargo.toml                    # Workspace root
│
├── crates/
│   ├── megaeth-rpc/              # MegaETH-specific RPC features
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── client.rs         # HTTP client wrapper
│   │       ├── cursor.rs         # Cursor-based pagination
│   │       ├── realtime.rs       # Realtime API
│   │       └── types.rs          # MegaETH-specific types
│   │
│   ├── evm-provider/             # Chain abstraction traits
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── traits.rs         # ChainProvider, NonceManager traits
│   │       ├── standard.rs       # Standard EVM implementation
│   │       ├── megaeth.rs        # MegaETH implementation
│   │       ├── transaction.rs    # Transaction building
│   │       └── error.rs
│   │
│   └── fleet-core/               # Orchestration primitives
│       ├── Cargo.toml
│       └── src/
│           ├── lib.rs
│           ├── wallet/           # Wallet management
│           ├── scheduler/        # Timing
│           ├── funding/          # Funding logic
│           ├── safety/           # Circuit breakers
│           ├── profiles/         # Behavior profiles
│           └── metrics/          # Observability
│
├── ghost-fleet/                  # Main service binary
│   ├── Cargo.toml
│   └── src/
│       ├── main.rs
│       ├── config.rs
│       ├── service.rs
│       └── plugins/              # Plugin loading
│
├── ghostnet-actions/             # GHOSTNET action plugin
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs
│       ├── plugin.rs             # Plugin implementation
│       ├── ghost_core.rs         # GhostCore interactions
│       ├── hash_crash.rs         # HashCrash interactions
│       └── contracts.rs          # Contract bindings
│
└── ghostnet-indexer/             # Existing (refactored to use megaeth-rpc)
```

### 1.2 Workspace Cargo.toml

```toml
# services/Cargo.toml

[workspace]
resolver = "2"
members = [
    "crates/megaeth-rpc",
    "crates/evm-provider",
    "crates/fleet-core",
    "ghost-fleet",
    "ghostnet-actions",
    "ghostnet-indexer",
]

[workspace.package]
edition = "2024"
rust-version = "1.85"
license = "MIT"
repository = "https://github.com/ghostnet/services"

[workspace.dependencies]
# Ethereum
alloy = { version = "1.4", features = ["full"] }

# Async
tokio = { version = "1", features = ["full"] }
async-trait = "0.1"
futures = "0.3"

# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"

# HTTP
reqwest = { version = "0.12", features = ["json", "rustls-tls"] }

# Observability
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }
metrics = "0.24"
metrics-exporter-prometheus = "0.16"

# Error handling
thiserror = "2"
anyhow = "1"

# Utilities
chrono = { version = "0.4", features = ["serde"] }
rand = "0.8"
dashmap = "6"
hex = "0.4"

# Crypto
aes-gcm = "0.10"
getrandom = "0.2"
base64 = "0.22"

# Config
config = { version = "0.14", features = ["toml"] }

# Web
axum = "0.8"

# Workspace crates (path dependencies)
megaeth-rpc = { path = "crates/megaeth-rpc" }
evm-provider = { path = "crates/evm-provider" }
fleet-core = { path = "crates/fleet-core" }
ghostnet-actions = { path = "ghostnet-actions" }

[workspace.lints.rust]
unsafe_code = "forbid"
missing_debug_implementations = "warn"

[workspace.lints.clippy]
all = { level = "deny", priority = -1 }
pedantic = { level = "warn", priority = -1 }
unwrap_used = "deny"
expect_used = "warn"
```

---

## 2. Chain Abstraction

### 2.1 Core Traits

```rust
// crates/evm-provider/src/traits.rs

use alloy::primitives::{Address, Bytes, TxHash, U256};
use async_trait::async_trait;

/// Core trait for interacting with any EVM chain.
/// 
/// Implementations handle chain-specific details (gas estimation,
/// transaction format, RPC quirks) while presenting a uniform interface.
#[async_trait]
pub trait ChainProvider: Send + Sync + 'static {
    /// Chain identifier (e.g., 6343 for MegaETH testnet)
    fn chain_id(&self) -> u64;
    
    /// Get native token balance (ETH)
    async fn get_balance(&self, address: Address) -> Result<U256, ProviderError>;
    
    /// Get ERC20 token balance
    async fn get_token_balance(
        &self,
        token: Address,
        account: Address,
    ) -> Result<U256, ProviderError>;
    
    /// Get current nonce (transaction count)
    async fn get_nonce(&self, address: Address) -> Result<u64, ProviderError>;
    
    /// Get pending nonce (includes mempool)
    async fn get_pending_nonce(&self, address: Address) -> Result<u64, ProviderError>;
    
    /// Send a signed transaction
    async fn send_raw_transaction(&self, tx: Bytes) -> Result<TxHash, ProviderError>;
    
    /// Wait for transaction confirmation
    async fn wait_for_receipt(
        &self,
        tx_hash: TxHash,
        timeout: std::time::Duration,
    ) -> Result<TransactionReceipt, ProviderError>;
    
    /// Estimate gas for a transaction (optional - some chains need overrides)
    async fn estimate_gas(&self, tx: &TransactionRequest) -> Result<u64, ProviderError> {
        // Default implementation returns a safe high value
        Ok(500_000)
    }
    
    /// Get current gas price
    async fn gas_price(&self) -> Result<u128, ProviderError>;
    
    /// Execute a read-only call
    async fn call(&self, tx: &TransactionRequest) -> Result<Bytes, ProviderError>;
}

/// Extended capabilities for chains that support them
#[async_trait]
pub trait ExtendedChainProvider: ChainProvider {
    /// Send transaction with instant receipt (MegaETH realtime API)
    async fn send_realtime(&self, tx: Bytes) -> Result<TransactionReceipt, ProviderError> {
        // Default: fall back to send + wait
        let hash = self.send_raw_transaction(tx).await?;
        self.wait_for_receipt(hash, std::time::Duration::from_secs(30)).await
    }
    
    /// Get logs with cursor-based pagination
    async fn get_logs_with_cursor(
        &self,
        filter: &LogFilter,
        cursor: Option<&str>,
    ) -> Result<LogsWithCursor, ProviderError> {
        // Default: not supported
        Err(ProviderError::Unsupported("cursor pagination".into()))
    }
}

/// Nonce management for high-throughput scenarios
#[async_trait]
pub trait NonceManager: Send + Sync {
    /// Get and atomically increment nonce for an address
    async fn get_and_increment(&self, address: Address) -> Result<u64, ProviderError>;
    
    /// Sync nonce from chain (call after errors)
    async fn sync(&self, address: Address) -> Result<(), ProviderError>;
    
    /// Reset nonce to specific value
    fn set(&self, address: Address, nonce: u64);
}
```

### 2.2 Transaction Building

```rust
// crates/evm-provider/src/transaction.rs

use alloy::primitives::{Address, Bytes, U256};
use alloy::signers::Signer;

/// Chain-agnostic transaction builder
pub struct TransactionBuilder<P: ChainProvider> {
    provider: P,
    gas_limit: Option<u64>,
    gas_price: Option<u128>,
}

impl<P: ChainProvider> TransactionBuilder<P> {
    pub fn new(provider: P) -> Self {
        Self {
            provider,
            gas_limit: None,
            gas_price: None,
        }
    }
    
    pub fn with_gas_limit(mut self, limit: u64) -> Self {
        self.gas_limit = Some(limit);
        self
    }
    
    /// Build and sign a contract call transaction
    pub async fn build_contract_call<S: Signer>(
        &self,
        signer: &S,
        to: Address,
        data: Bytes,
        value: U256,
        nonce: u64,
    ) -> Result<Bytes, TransactionError> {
        let gas_limit = match self.gas_limit {
            Some(g) => g,
            None => self.provider.estimate_gas(&TransactionRequest {
                to: Some(to),
                data: Some(data.clone()),
                value: Some(value),
                ..Default::default()
            }).await.unwrap_or(500_000),
        };
        
        let gas_price = match self.gas_price {
            Some(p) => p,
            None => self.provider.gas_price().await?,
        };
        
        let tx = TransactionRequest {
            chain_id: Some(self.provider.chain_id()),
            to: Some(to),
            value: Some(value),
            data: Some(data),
            nonce: Some(nonce),
            gas_limit: Some(gas_limit),
            gas_price: Some(gas_price),
            ..Default::default()
        };
        
        let signed = signer.sign_transaction(&tx).await?;
        Ok(signed.into())
    }
}
```

### 2.3 MegaETH Provider

```rust
// crates/evm-provider/src/megaeth.rs

use megaeth_rpc::MegaEthClient;
use crate::traits::{ChainProvider, ExtendedChainProvider, ProviderError};

/// MegaETH-specific provider implementation
pub struct MegaEthProvider {
    client: MegaEthClient,
    chain_id: u64,
    /// Override gas limit (MegaETH estimation can be unreliable)
    gas_limit_override: Option<u64>,
}

impl MegaEthProvider {
    pub fn new(rpc_url: &str, chain_id: u64) -> Result<Self, ProviderError> {
        let client = MegaEthClient::new(rpc_url)?;
        Ok(Self {
            client,
            chain_id,
            gas_limit_override: Some(500_000), // Default override for MegaETH
        })
    }
    
    pub fn with_gas_limit_override(mut self, limit: u64) -> Self {
        self.gas_limit_override = Some(limit);
        self
    }
}

#[async_trait]
impl ChainProvider for MegaEthProvider {
    fn chain_id(&self) -> u64 {
        self.chain_id
    }
    
    async fn get_balance(&self, address: Address) -> Result<U256, ProviderError> {
        self.client.get_balance(address).await
    }
    
    // ... other ChainProvider methods
    
    async fn estimate_gas(&self, _tx: &TransactionRequest) -> Result<u64, ProviderError> {
        // MegaETH gas estimation is unreliable - use override
        Ok(self.gas_limit_override.unwrap_or(500_000))
    }
}

#[async_trait]
impl ExtendedChainProvider for MegaEthProvider {
    async fn send_realtime(&self, tx: Bytes) -> Result<TransactionReceipt, ProviderError> {
        // Use MegaETH's realtime_sendRawTransaction
        self.client.send_realtime_transaction(tx).await
    }
    
    async fn get_logs_with_cursor(
        &self,
        filter: &LogFilter,
        cursor: Option<&str>,
    ) -> Result<LogsWithCursor, ProviderError> {
        self.client.get_logs_with_cursor(filter, cursor).await
    }
}
```

### 2.4 Standard EVM Provider

```rust
// crates/evm-provider/src/standard.rs

use alloy::providers::{Provider, ProviderBuilder};
use crate::traits::{ChainProvider, ProviderError};

/// Standard EVM provider for chains without special features
pub struct StandardEvmProvider {
    provider: Box<dyn Provider>,
    chain_id: u64,
}

impl StandardEvmProvider {
    pub async fn new(rpc_url: &str) -> Result<Self, ProviderError> {
        let provider = ProviderBuilder::new()
            .on_http(rpc_url.parse()?)
            .boxed();
        
        let chain_id = provider.get_chain_id().await?;
        
        Ok(Self { provider, chain_id })
    }
}

#[async_trait]
impl ChainProvider for StandardEvmProvider {
    fn chain_id(&self) -> u64 {
        self.chain_id
    }
    
    async fn get_balance(&self, address: Address) -> Result<U256, ProviderError> {
        self.provider.get_balance(address).await
            .map_err(ProviderError::from)
    }
    
    // ... standard implementations using alloy Provider
}
```

---

## 3. Action Plugin System

### 3.1 Plugin Trait

```rust
// crates/fleet-core/src/plugins/traits.rs

use async_trait::async_trait;
use crate::wallet::WalletState;
use crate::profiles::BehaviorProfile;

/// An action that can be executed on-chain
#[derive(Debug, Clone)]
pub struct Action {
    /// Unique action identifier
    pub id: ActionId,
    /// Human-readable name
    pub name: String,
    /// Action-specific data
    pub data: ActionData,
}

/// Plugin-specific action data (opaque to core)
pub type ActionData = serde_json::Value;

/// Unique action identifier
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct ActionId(pub String);

/// Result of executing an action
#[derive(Debug)]
pub struct ActionResult {
    pub success: bool,
    pub tx_hash: Option<TxHash>,
    pub gas_used: Option<u64>,
    pub error: Option<String>,
}

/// Trait that all action plugins must implement
#[async_trait]
pub trait ActionPlugin: Send + Sync + 'static {
    /// Plugin identifier (e.g., "ghostnet", "token_swap")
    fn id(&self) -> &str;
    
    /// Human-readable plugin name
    fn name(&self) -> &str;
    
    /// List of actions this plugin provides
    fn available_actions(&self) -> Vec<ActionId>;
    
    /// Decide what action (if any) this plugin wants to take
    /// 
    /// Called by the behavior engine. Plugin examines wallet state
    /// and profile, returns an action or None.
    async fn decide_action(
        &self,
        wallet: &WalletState,
        profile: &BehaviorProfile,
        context: &PluginContext,
    ) -> Result<Option<Action>, PluginError>;
    
    /// Execute an action
    /// 
    /// Build transaction, sign with provided signer, submit to chain.
    async fn execute_action<P: ChainProvider, S: Signer>(
        &self,
        action: &Action,
        provider: &P,
        signer: &S,
        nonce: u64,
    ) -> Result<ActionResult, PluginError>;
    
    /// Read current state relevant to this plugin
    /// 
    /// Called to refresh wallet state with plugin-specific data.
    async fn read_state<P: ChainProvider>(
        &self,
        provider: &P,
        address: Address,
    ) -> Result<PluginState, PluginError>;
}

/// Context provided to plugins for decision-making
pub struct PluginContext {
    /// Current timestamp
    pub now: chrono::DateTime<chrono::Utc>,
    /// Random number generator (for varied behavior)
    pub rng: Box<dyn RngCore + Send>,
    /// Plugin-specific configuration
    pub config: serde_json::Value,
}

/// Plugin-specific state (stored in WalletState.plugin_states)
pub type PluginState = serde_json::Value;
```

### 3.2 Plugin Registry

```rust
// crates/fleet-core/src/plugins/registry.rs

use std::collections::HashMap;
use std::sync::Arc;

/// Registry of available action plugins
pub struct PluginRegistry {
    plugins: HashMap<String, Arc<dyn ActionPlugin>>,
}

impl PluginRegistry {
    pub fn new() -> Self {
        Self {
            plugins: HashMap::new(),
        }
    }
    
    /// Register a plugin
    pub fn register(&mut self, plugin: Arc<dyn ActionPlugin>) {
        self.plugins.insert(plugin.id().to_string(), plugin);
    }
    
    /// Get a plugin by ID
    pub fn get(&self, id: &str) -> Option<&Arc<dyn ActionPlugin>> {
        self.plugins.get(id)
    }
    
    /// Get all registered plugins
    pub fn all(&self) -> impl Iterator<Item = &Arc<dyn ActionPlugin>> {
        self.plugins.values()
    }
    
    /// Get enabled plugins based on configuration
    pub fn enabled(&self, enabled_ids: &[String]) -> Vec<Arc<dyn ActionPlugin>> {
        enabled_ids
            .iter()
            .filter_map(|id| self.plugins.get(id).cloned())
            .collect()
    }
}

impl Default for PluginRegistry {
    fn default() -> Self {
        Self::new()
    }
}
```

### 3.3 Behavior Engine with Plugins

```rust
// crates/fleet-core/src/behavior/engine.rs

use crate::plugins::{ActionPlugin, PluginRegistry, PluginContext, Action};
use crate::wallet::WalletState;
use crate::profiles::BehaviorProfile;

/// Behavior engine that coordinates plugin decisions
pub struct BehaviorEngine {
    plugins: Vec<Arc<dyn ActionPlugin>>,
    rng: StdRng,
}

impl BehaviorEngine {
    pub fn new(registry: &PluginRegistry, enabled: &[String]) -> Self {
        Self {
            plugins: registry.enabled(enabled),
            rng: StdRng::from_entropy(),
        }
    }
    
    /// Decide what action a wallet should take
    /// 
    /// Queries all enabled plugins and returns the first action
    /// (or None if no plugin wants to act).
    pub async fn decide_action(
        &mut self,
        wallet: &WalletState,
        profile: &BehaviorProfile,
    ) -> Option<(Arc<dyn ActionPlugin>, Action)> {
        // Check timing/AFK first
        if wallet.is_afk() || !self.should_act_now(profile) {
            return None;
        }
        
        let context = PluginContext {
            now: chrono::Utc::now(),
            rng: Box::new(self.rng.clone()),
            config: serde_json::Value::Null, // Loaded per-plugin
        };
        
        // Query each plugin
        for plugin in &self.plugins {
            match plugin.decide_action(wallet, profile, &context).await {
                Ok(Some(action)) => {
                    return Some((plugin.clone(), action));
                }
                Ok(None) => continue,
                Err(e) => {
                    tracing::warn!(
                        plugin = plugin.id(),
                        error = %e,
                        "Plugin decision error"
                    );
                    continue;
                }
            }
        }
        
        None
    }
    
    fn should_act_now(&mut self, profile: &BehaviorProfile) -> bool {
        let hour = chrono::Utc::now().hour() as u8;
        let in_active_hours = profile.active_hours.contains(&hour);
        
        if in_active_hours {
            true
        } else {
            self.rng.gen_bool(profile.off_hours_factor)
        }
    }
}
```

---

## 4. MegaETH Client Crate

### 4.1 Structure

```rust
// crates/megaeth-rpc/src/lib.rs

//! MegaETH-specific RPC client functionality.
//! 
//! This crate provides access to MegaETH's extended JSON-RPC API,
//! including cursor-based pagination and the realtime API.
//! 
//! # Features
//! 
//! - **Cursor Pagination**: `eth_getLogsWithCursor` for efficient log queries
//! - **Realtime API**: `realtime_sendRawTransaction` for instant receipts
//! - **Connection Management**: Handles MegaETH-specific quirks
//! 
//! # Usage
//! 
//! ```ignore
//! use megaeth_rpc::MegaEthClient;
//! 
//! let client = MegaEthClient::new("https://carrot.megaeth.com/rpc")?;
//! 
//! // Cursor-based log pagination
//! let (logs, stats) = client.get_logs_with_cursor(from, to, None).await?;
//! 
//! // Realtime transaction
//! let receipt = client.send_realtime_transaction(signed_tx).await?;
//! ```

mod client;
mod cursor;
mod realtime;
mod types;
mod error;

pub use client::MegaEthClient;
pub use cursor::{LogsWithCursorResponse, LogsWithCursorFilter, FetchStats};
pub use realtime::RealtimeApi;
pub use types::*;
pub use error::MegaEthError;
```

### 4.2 Client Implementation

```rust
// crates/megaeth-rpc/src/client.rs

use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;
use reqwest::Client;
use alloy::primitives::{Address, Bytes, TxHash};
use alloy::rpc::types::{Log, TransactionReceipt};

use crate::cursor::{LogsWithCursorFilter, LogsWithCursorResponse, FetchStats};
use crate::error::MegaEthError;

const DEFAULT_TIMEOUT: Duration = Duration::from_secs(30);
const MAX_CURSOR_BATCHES: usize = 100;

/// MegaETH RPC client with extended API support
#[derive(Debug)]
pub struct MegaEthClient {
    client: Client,
    rpc_url: String,
    request_id: AtomicU64,
}

impl MegaEthClient {
    /// Create a new client
    pub fn new(rpc_url: impl Into<String>) -> Result<Self, MegaEthError> {
        let client = Client::builder()
            .timeout(DEFAULT_TIMEOUT)
            .build()
            .map_err(MegaEthError::Http)?;
        
        Ok(Self {
            client,
            rpc_url: rpc_url.into(),
            request_id: AtomicU64::new(1),
        })
    }
    
    /// Create with custom timeout
    pub fn with_timeout(
        rpc_url: impl Into<String>,
        timeout: Duration,
    ) -> Result<Self, MegaEthError> {
        let client = Client::builder()
            .timeout(timeout)
            .build()
            .map_err(MegaEthError::Http)?;
        
        Ok(Self {
            client,
            rpc_url: rpc_url.into(),
            request_id: AtomicU64::new(1),
        })
    }
    
    fn next_id(&self) -> u64 {
        self.request_id.fetch_add(1, Ordering::Relaxed)
    }
    
    /// Check if cursor pagination is supported
    pub async fn supports_cursor_pagination(&self) -> bool {
        // Implementation from existing megaeth_rpc.rs
        // ...
    }
    
    /// Fetch logs with cursor-based pagination
    pub async fn get_logs_with_cursor(
        &self,
        from_block: u64,
        to_block: u64,
        addresses: Option<Vec<Address>>,
    ) -> Result<(Vec<Log>, FetchStats), MegaEthError> {
        // Implementation from existing megaeth_rpc.rs
        // ...
    }
    
    /// Send transaction with realtime API (instant receipt)
    pub async fn send_realtime_transaction(
        &self,
        signed_tx: Bytes,
    ) -> Result<TransactionReceipt, MegaEthError> {
        let request = serde_json::json!({
            "jsonrpc": "2.0",
            "method": "realtime_sendRawTransaction",
            "params": [format!("0x{}", hex::encode(&signed_tx))],
            "id": self.next_id()
        });
        
        let response = self.client
            .post(&self.rpc_url)
            .json(&request)
            .send()
            .await
            .map_err(MegaEthError::Http)?;
        
        let body: serde_json::Value = response
            .json()
            .await
            .map_err(MegaEthError::Http)?;
        
        if let Some(error) = body.get("error") {
            return Err(MegaEthError::Rpc(error.to_string()));
        }
        
        let receipt: TransactionReceipt = serde_json::from_value(
            body.get("result").cloned().unwrap_or_default()
        ).map_err(MegaEthError::Parse)?;
        
        Ok(receipt)
    }
    
    /// Standard JSON-RPC call
    pub async fn rpc_call<T: serde::de::DeserializeOwned>(
        &self,
        method: &str,
        params: serde_json::Value,
    ) -> Result<T, MegaEthError> {
        let request = serde_json::json!({
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": self.next_id()
        });
        
        let response = self.client
            .post(&self.rpc_url)
            .json(&request)
            .send()
            .await
            .map_err(MegaEthError::Http)?;
        
        let body: serde_json::Value = response
            .json()
            .await
            .map_err(MegaEthError::Http)?;
        
        if let Some(error) = body.get("error") {
            return Err(MegaEthError::Rpc(error.to_string()));
        }
        
        serde_json::from_value(
            body.get("result").cloned().unwrap_or_default()
        ).map_err(MegaEthError::Parse)
    }
}
```

---

## 5. Fleet Core Crate

### 5.1 Wallet Management

```rust
// crates/fleet-core/src/wallet/state.rs

use alloy::primitives::{Address, U256};
use chrono::{DateTime, Utc};
use std::collections::HashMap;

/// Wallet state tracking (generic across use cases)
#[derive(Debug, Clone)]
pub struct WalletState {
    /// Wallet identifier
    pub id: String,
    
    /// Ethereum address
    pub address: Address,
    
    /// Native token balance (ETH)
    pub native_balance: U256,
    
    /// Token balances by address
    pub token_balances: HashMap<Address, U256>,
    
    /// Current nonce
    pub nonce: u64,
    
    /// Plugin-specific state
    pub plugin_states: HashMap<String, serde_json::Value>,
    
    /// Last action timestamp
    pub last_action: Option<DateTime<Utc>>,
    
    /// Next scheduled action
    pub next_action: DateTime<Utc>,
    
    /// Whether wallet is active
    pub active: bool,
    
    /// Consecutive error count
    pub consecutive_errors: u32,
    
    /// AFK until (if set)
    pub afk_until: Option<DateTime<Utc>>,
}

impl WalletState {
    pub fn new(id: String, address: Address) -> Self {
        Self {
            id,
            address,
            native_balance: U256::ZERO,
            token_balances: HashMap::new(),
            nonce: 0,
            plugin_states: HashMap::new(),
            last_action: None,
            next_action: Utc::now(),
            active: true,
            consecutive_errors: 0,
            afk_until: None,
        }
    }
    
    pub fn is_afk(&self) -> bool {
        self.afk_until
            .map(|until| Utc::now() < until)
            .unwrap_or(false)
    }
    
    /// Get token balance (returns 0 if not tracked)
    pub fn token_balance(&self, token: Address) -> U256 {
        self.token_balances.get(&token).copied().unwrap_or(U256::ZERO)
    }
    
    /// Get plugin-specific state
    pub fn plugin_state(&self, plugin_id: &str) -> Option<&serde_json::Value> {
        self.plugin_states.get(plugin_id)
    }
    
    pub fn record_success(&mut self) {
        self.consecutive_errors = 0;
        self.last_action = Some(Utc::now());
    }
    
    pub fn record_error(&mut self) {
        self.consecutive_errors += 1;
    }
}
```

### 5.2 Behavior Profiles

```rust
// crates/fleet-core/src/profiles/mod.rs

use serde::Deserialize;
use std::ops::RangeInclusive;

/// Generic behavior profile (not action-specific)
#[derive(Debug, Clone, Deserialize)]
pub struct BehaviorProfile {
    /// Profile name
    pub name: String,
    
    /// Risk tolerance (0.0 = none, 1.0 = maximum)
    pub risk_tolerance: f64,
    
    /// Activity level (actions per hour, approximate)
    pub activity_level: f64,
    
    /// Patience factor (higher = holds positions longer)
    pub patience: f64,
    
    /// Base action interval in seconds
    pub action_interval_base: u64,
    
    /// Interval jitter percentage
    pub action_interval_jitter_pct: u8,
    
    /// Active hours (UTC)
    pub active_hours: RangeInclusive<u8>,
    
    /// Activity reduction outside active hours
    pub off_hours_factor: f64,
    
    /// Probability of going AFK
    pub afk_probability: f64,
    
    /// AFK duration range (hours)
    pub afk_duration_hours: RangeInclusive<u64>,
}

impl BehaviorProfile {
    /// Standard profiles
    pub fn whale() -> Self {
        Self {
            name: "whale".into(),
            risk_tolerance: 0.2,
            activity_level: 2.0,
            patience: 0.9,
            action_interval_base: 7200,
            action_interval_jitter_pct: 40,
            active_hours: 14..=22,
            off_hours_factor: 0.3,
            afk_probability: 0.1,
            afk_duration_hours: 12..=48,
        }
    }
    
    pub fn grinder() -> Self {
        Self {
            name: "grinder".into(),
            risk_tolerance: 0.5,
            activity_level: 7.0,
            patience: 0.5,
            action_interval_base: 1800,
            action_interval_jitter_pct: 50,
            active_hours: 8..=23,
            off_hours_factor: 0.5,
            afk_probability: 0.05,
            afk_duration_hours: 4..=12,
        }
    }
    
    pub fn degen() -> Self {
        Self {
            name: "degen".into(),
            risk_tolerance: 0.85,
            activity_level: 15.0,
            patience: 0.3,
            action_interval_base: 900,
            action_interval_jitter_pct: 60,
            active_hours: 0..=24,
            off_hours_factor: 0.8,
            afk_probability: 0.02,
            afk_duration_hours: 1..=4,
        }
    }
    
    pub fn casual() -> Self {
        Self {
            name: "casual".into(),
            risk_tolerance: 0.4,
            activity_level: 3.0,
            patience: 0.6,
            action_interval_base: 3600,
            action_interval_jitter_pct: 80,
            active_hours: 10..=20,
            off_hours_factor: 0.2,
            afk_probability: 0.2,
            afk_duration_hours: 6..=72,
        }
    }
    
    pub fn sniper() -> Self {
        Self {
            name: "sniper".into(),
            risk_tolerance: 0.95,
            activity_level: 12.0,
            patience: 0.1,
            action_interval_base: 600,
            action_interval_jitter_pct: 40,
            active_hours: 0..=24,
            off_hours_factor: 1.0,
            afk_probability: 0.3,
            afk_duration_hours: 2..=24,
        }
    }
}
```

### 5.3 Circuit Breaker

```rust
// crates/fleet-core/src/safety/circuit_breaker.rs

use std::collections::{HashMap, HashSet};
use chrono::{DateTime, Duration, Utc};
use tracing::warn;

/// Circuit breaker for wallet operations
pub struct CircuitBreaker {
    max_errors: u32,
    cooldown: Duration,
    error_counts: HashMap<String, u32>,
    tripped: HashSet<String>,
    trip_times: HashMap<String, DateTime<Utc>>,
}

impl CircuitBreaker {
    pub fn new(max_errors: u32, cooldown_secs: u64) -> Self {
        Self {
            max_errors,
            cooldown: Duration::seconds(cooldown_secs as i64),
            error_counts: HashMap::new(),
            tripped: HashSet::new(),
            trip_times: HashMap::new(),
        }
    }
    
    pub fn record_success(&mut self, wallet_id: &str) {
        self.error_counts.remove(wallet_id);
    }
    
    /// Record error, returns true if circuit just tripped
    pub fn record_error(&mut self, wallet_id: &str) -> bool {
        let count = self.error_counts
            .entry(wallet_id.to_string())
            .or_insert(0);
        *count += 1;
        
        if *count >= self.max_errors && !self.tripped.contains(wallet_id) {
            warn!(
                wallet = wallet_id,
                errors = *count,
                "Circuit breaker tripped"
            );
            self.tripped.insert(wallet_id.to_string());
            self.trip_times.insert(wallet_id.to_string(), Utc::now());
            return true;
        }
        
        false
    }
    
    pub fn is_tripped(&self, wallet_id: &str) -> bool {
        self.tripped.contains(wallet_id)
    }
    
    pub fn tripped_count(&self) -> usize {
        self.tripped.len()
    }
    
    pub fn manual_reset(&mut self, wallet_id: &str) {
        self.tripped.remove(wallet_id);
        self.error_counts.remove(wallet_id);
        self.trip_times.remove(wallet_id);
    }
    
    /// Check and auto-reset wallets past cooldown
    pub fn check_auto_reset(&mut self) {
        let now = Utc::now();
        let to_reset: Vec<_> = self.trip_times
            .iter()
            .filter(|(_, time)| now - **time > self.cooldown)
            .map(|(id, _)| id.clone())
            .collect();
        
        for id in to_reset {
            self.manual_reset(&id);
        }
    }
}
```

---

## 6. GHOSTNET Actions Plugin

### 6.1 Plugin Implementation

```rust
// ghostnet-actions/src/plugin.rs

use async_trait::async_trait;
use fleet_core::plugins::{ActionPlugin, Action, ActionId, ActionResult, PluginContext, PluginError};
use fleet_core::wallet::WalletState;
use fleet_core::profiles::BehaviorProfile;
use evm_provider::ChainProvider;
use alloy::signers::Signer;

use crate::ghost_core::GhostCoreActions;
use crate::hash_crash::HashCrashActions;
use crate::contracts::GhostnetContracts;
use crate::config::GhostnetConfig;

/// GHOSTNET action plugin
pub struct GhostnetPlugin {
    config: GhostnetConfig,
    contracts: GhostnetContracts,
}

impl GhostnetPlugin {
    pub fn new(config: GhostnetConfig) -> Self {
        let contracts = GhostnetContracts::new(&config);
        Self { config, contracts }
    }
}

#[async_trait]
impl ActionPlugin for GhostnetPlugin {
    fn id(&self) -> &str {
        "ghostnet"
    }
    
    fn name(&self) -> &str {
        "GHOSTNET Protocol"
    }
    
    fn available_actions(&self) -> Vec<ActionId> {
        vec![
            ActionId("ghostnet.jack_in".into()),
            ActionId("ghostnet.add_stake".into()),
            ActionId("ghostnet.extract".into()),
            ActionId("ghostnet.claim_rewards".into()),
            ActionId("ghostnet.hashcrash_bet".into()),
            ActionId("ghostnet.hashcrash_start".into()),
        ]
    }
    
    async fn decide_action(
        &self,
        wallet: &WalletState,
        profile: &BehaviorProfile,
        context: &PluginContext,
    ) -> Result<Option<Action>, PluginError> {
        // Get GHOSTNET-specific state
        let ghost_state: Option<GhostnetState> = wallet
            .plugin_state("ghostnet")
            .and_then(|v| serde_json::from_value(v.clone()).ok());
        
        // Map generic profile to GHOSTNET-specific behavior
        let ghost_profile = GhostnetProfile::from_behavior(profile, &self.config);
        
        // Try GhostCore actions first
        if let Some(action) = GhostCoreActions::decide(
            wallet,
            ghost_state.as_ref(),
            &ghost_profile,
            context,
        )? {
            return Ok(Some(action));
        }
        
        // Try HashCrash actions
        if ghost_profile.plays_hashcrash {
            if let Some(action) = HashCrashActions::decide(
                wallet,
                ghost_state.as_ref(),
                &ghost_profile,
                context,
            )? {
                return Ok(Some(action));
            }
        }
        
        Ok(None)
    }
    
    async fn execute_action<P: ChainProvider, S: Signer>(
        &self,
        action: &Action,
        provider: &P,
        signer: &S,
        nonce: u64,
    ) -> Result<ActionResult, PluginError> {
        match action.id.0.as_str() {
            "ghostnet.jack_in" => {
                GhostCoreActions::execute_jack_in(
                    &action.data,
                    &self.contracts,
                    provider,
                    signer,
                    nonce,
                ).await
            }
            "ghostnet.add_stake" => {
                GhostCoreActions::execute_add_stake(
                    &action.data,
                    &self.contracts,
                    provider,
                    signer,
                    nonce,
                ).await
            }
            "ghostnet.extract" => {
                GhostCoreActions::execute_extract(
                    &self.contracts,
                    provider,
                    signer,
                    nonce,
                ).await
            }
            "ghostnet.hashcrash_bet" => {
                HashCrashActions::execute_bet(
                    &action.data,
                    &self.contracts,
                    provider,
                    signer,
                    nonce,
                ).await
            }
            _ => Err(PluginError::UnknownAction(action.id.clone())),
        }
    }
    
    async fn read_state<P: ChainProvider>(
        &self,
        provider: &P,
        address: Address,
    ) -> Result<serde_json::Value, PluginError> {
        let position = self.contracts.ghost_core
            .get_position(provider, address)
            .await?;
        
        let pending_rewards = self.contracts.ghost_core
            .get_pending_rewards(provider, address)
            .await?;
        
        let hashcrash_state = self.contracts.hash_crash
            .get_current_round(provider)
            .await?;
        
        let state = GhostnetState {
            position,
            pending_rewards,
            hashcrash_round_open: hashcrash_state.is_betting(),
            hashcrash_round_id: hashcrash_state.round_id,
        };
        
        Ok(serde_json::to_value(state)?)
    }
}
```

### 6.2 GhostCore Actions

```rust
// ghostnet-actions/src/ghost_core.rs

use alloy::primitives::{Address, U256};
use fleet_core::plugins::{Action, ActionId, ActionResult, PluginContext, PluginError};
use fleet_core::wallet::WalletState;
use evm_provider::{ChainProvider, TransactionBuilder};

use crate::state::{GhostnetState, GhostnetProfile, Level};
use crate::contracts::GhostnetContracts;

pub struct GhostCoreActions;

impl GhostCoreActions {
    pub fn decide(
        wallet: &WalletState,
        state: Option<&GhostnetState>,
        profile: &GhostnetProfile,
        context: &PluginContext,
    ) -> Result<Option<Action>, PluginError> {
        let mut rng = context.rng.clone();
        
        // If has dead position, decide whether to re-enter
        if let Some(state) = state {
            if let Some(ref pos) = state.position {
                if !pos.alive {
                    return Self::decide_after_death(wallet, profile, &mut rng);
                }
                
                // Has active position
                return Self::decide_with_position(wallet, state, profile, &mut rng);
            }
        }
        
        // No position - maybe create one
        Self::decide_new_position(wallet, profile, &mut rng)
    }
    
    fn decide_new_position(
        wallet: &WalletState,
        profile: &GhostnetProfile,
        rng: &mut dyn RngCore,
    ) -> Result<Option<Action>, PluginError> {
        let data_balance = wallet.token_balance(profile.data_token);
        let min_stake = profile.min_stake();
        
        if data_balance < min_stake {
            return Ok(None);
        }
        
        if !rng.gen_bool(0.7) {
            return Ok(None);
        }
        
        let level = profile.select_level(rng);
        let amount = profile.calculate_stake(data_balance, rng);
        
        Ok(Some(Action {
            id: ActionId("ghostnet.jack_in".into()),
            name: "Jack In".into(),
            data: serde_json::json!({
                "amount": amount.to_string(),
                "level": level as u8,
            }),
        }))
    }
    
    fn decide_with_position(
        wallet: &WalletState,
        state: &GhostnetState,
        profile: &GhostnetProfile,
        rng: &mut dyn RngCore,
    ) -> Result<Option<Action>, PluginError> {
        let position = state.position.as_ref().unwrap();
        
        // Check if should extract
        if position.ghost_streak >= profile.min_streak_before_extract {
            if rng.gen_bool(profile.extract_probability) {
                return Ok(Some(Action {
                    id: ActionId("ghostnet.extract".into()),
                    name: "Extract".into(),
                    data: serde_json::Value::Null,
                }));
            }
        }
        
        // Check if should compound
        let data_balance = wallet.token_balance(profile.data_token);
        if data_balance >= profile.min_stake() {
            if rng.gen_bool(profile.compound_probability) {
                let amount = profile.calculate_add_stake(data_balance, rng);
                return Ok(Some(Action {
                    id: ActionId("ghostnet.add_stake".into()),
                    name: "Add Stake".into(),
                    data: serde_json::json!({
                        "amount": amount.to_string(),
                    }),
                }));
            }
        }
        
        Ok(None)
    }
    
    // Execute methods...
    pub async fn execute_jack_in<P: ChainProvider, S: Signer>(
        data: &serde_json::Value,
        contracts: &GhostnetContracts,
        provider: &P,
        signer: &S,
        nonce: u64,
    ) -> Result<ActionResult, PluginError> {
        let amount: U256 = data["amount"].as_str()
            .ok_or(PluginError::InvalidData)?
            .parse()
            .map_err(|_| PluginError::InvalidData)?;
        let level: u8 = data["level"].as_u64()
            .ok_or(PluginError::InvalidData)? as u8;
        
        // Ensure approval
        contracts.ensure_data_approval(provider, signer, contracts.ghost_core_address, amount).await?;
        
        // Build transaction
        let calldata = contracts.ghost_core.encode_jack_in(amount, level);
        
        let tx_builder = TransactionBuilder::new(provider)
            .with_gas_limit(500_000);
        
        let signed_tx = tx_builder.build_contract_call(
            signer,
            contracts.ghost_core_address,
            calldata,
            U256::ZERO,
            nonce,
        ).await?;
        
        let receipt = provider.send_raw_transaction(signed_tx).await?;
        
        Ok(ActionResult {
            success: true,
            tx_hash: Some(receipt),
            gas_used: None,
            error: None,
        })
    }
}
```

---

## 7. Main Service

### 7.1 Entry Point

```rust
// ghost-fleet/src/main.rs

use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::info;

use fleet_core::{
    wallet::WalletManager,
    plugins::PluginRegistry,
    behavior::BehaviorEngine,
    safety::CircuitBreaker,
    scheduler::Scheduler,
};
use evm_provider::{ChainProvider, MegaEthProvider, StandardEvmProvider};
use ghostnet_actions::GhostnetPlugin;

mod config;
mod service;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Load configuration
    let settings = config::Settings::load()?;
    
    // Initialize logging
    tracing_subscriber::fmt()
        .with_env_filter(&settings.service.log_level)
        .init();
    
    info!(
        version = env!("CARGO_PKG_VERSION"),
        chain = settings.chain.chain_type,
        "Starting Ghost Fleet"
    );
    
    // Create chain provider based on configuration
    let provider: Arc<dyn ChainProvider> = match settings.chain.chain_type.as_str() {
        "megaeth" => Arc::new(
            MegaEthProvider::new(&settings.chain.rpc_url, settings.chain.chain_id)?
        ),
        _ => Arc::new(
            StandardEvmProvider::new(&settings.chain.rpc_url).await?
        ),
    };
    
    // Initialize plugin registry
    let mut registry = PluginRegistry::new();
    
    // Register enabled plugins
    if settings.plugins.enabled.contains(&"ghostnet".to_string()) {
        let ghostnet_config = settings.plugins.ghostnet
            .ok_or_else(|| anyhow::anyhow!("GHOSTNET plugin enabled but not configured"))?;
        registry.register(Arc::new(GhostnetPlugin::new(ghostnet_config)));
    }
    
    // Initialize components
    let wallet_manager = WalletManager::new(&settings.wallets, provider.as_ref()).await?;
    let behavior_engine = BehaviorEngine::new(&registry, &settings.plugins.enabled);
    let circuit_breaker = CircuitBreaker::new(
        settings.safety.max_consecutive_errors,
        settings.safety.circuit_breaker_cooldown_secs,
    );
    let scheduler = Scheduler::new();
    
    // Create service
    let service = service::FleetService::new(
        provider,
        wallet_manager,
        behavior_engine,
        circuit_breaker,
        scheduler,
        settings,
    );
    
    // Run
    service.run().await
}
```

### 7.2 Service Loop

```rust
// ghost-fleet/src/service.rs

use std::sync::Arc;
use tokio::time::{interval, Duration};
use tracing::{info, warn, error, instrument};

use fleet_core::{
    wallet::{WalletManager, WalletState},
    behavior::BehaviorEngine,
    safety::CircuitBreaker,
    scheduler::Scheduler,
    plugins::ActionPlugin,
};
use evm_provider::ChainProvider;

pub struct FleetService {
    provider: Arc<dyn ChainProvider>,
    wallet_manager: WalletManager,
    behavior_engine: BehaviorEngine,
    circuit_breaker: CircuitBreaker,
    scheduler: Scheduler,
    settings: Settings,
}

impl FleetService {
    pub async fn run(mut self) -> anyhow::Result<()> {
        info!("Fleet service starting main loop");
        
        let mut tick = interval(Duration::from_secs(1));
        
        loop {
            tick.tick().await;
            
            // Check global pause
            if self.settings.safety.global_pause {
                continue;
            }
            
            // Check auto-reset for circuit breakers
            self.circuit_breaker.check_auto_reset();
            
            // Get wallets due for action
            let due_wallets = self.scheduler.get_due_wallets();
            
            for wallet_id in due_wallets {
                if let Err(e) = self.process_wallet(&wallet_id).await {
                    error!(wallet = %wallet_id, error = %e, "Failed to process wallet");
                }
            }
            
            // Update metrics
            self.update_metrics().await;
        }
    }
    
    #[instrument(skip(self))]
    async fn process_wallet(&mut self, wallet_id: &str) -> anyhow::Result<()> {
        // Check circuit breaker
        if self.circuit_breaker.is_tripped(wallet_id) {
            return Ok(());
        }
        
        // Get wallet state and profile
        let state = self.wallet_manager.get_state(wallet_id).await
            .ok_or_else(|| anyhow::anyhow!("Wallet not found: {}", wallet_id))?;
        
        let profile_name = self.wallet_manager.get_profile(wallet_id)
            .ok_or_else(|| anyhow::anyhow!("No profile for wallet: {}", wallet_id))?;
        
        let profile = self.settings.profiles.get(profile_name)
            .ok_or_else(|| anyhow::anyhow!("Profile not found: {}", profile_name))?;
        
        // Decide action
        let decision = self.behavior_engine.decide_action(&state, profile).await;
        
        if let Some((plugin, action)) = decision {
            // Execute action
            let signer = self.wallet_manager.get_signer(wallet_id)
                .ok_or_else(|| anyhow::anyhow!("Signer not found: {}", wallet_id))?;
            
            let nonce = self.wallet_manager.get_nonce(wallet_id).await?;
            
            match plugin.execute_action(
                &action,
                self.provider.as_ref(),
                signer,
                nonce,
            ).await {
                Ok(result) => {
                    if result.success {
                        info!(
                            wallet = wallet_id,
                            action = action.name,
                            tx_hash = ?result.tx_hash,
                            "Action executed successfully"
                        );
                        self.wallet_manager.increment_nonce(wallet_id);
                        self.circuit_breaker.record_success(wallet_id);
                    } else {
                        warn!(
                            wallet = wallet_id,
                            action = action.name,
                            error = ?result.error,
                            "Action failed"
                        );
                        if self.circuit_breaker.record_error(wallet_id) {
                            metrics::counter!("circuit_breaker_trips").increment(1);
                        }
                    }
                }
                Err(e) => {
                    error!(
                        wallet = wallet_id,
                        action = action.name,
                        error = %e,
                        "Action execution error"
                    );
                    if self.circuit_breaker.record_error(wallet_id) {
                        metrics::counter!("circuit_breaker_trips").increment(1);
                    }
                }
            }
            
            metrics::counter!("actions_executed", "action" => action.name.clone()).increment(1);
        }
        
        // Schedule next action
        self.scheduler.schedule_next(wallet_id, profile);
        
        Ok(())
    }
}
```

---

## 8. Configuration

### 8.1 Main Config

```toml
# ghost-fleet/config/default.toml

[service]
name = "ghost-fleet"
log_level = "info"
health_port = 8080

# Chain configuration (provider selection)
[chain]
chain_type = "megaeth"  # or "standard"
chain_id = 6343
rpc_url = "https://carrot.megaeth.com/rpc"

# MegaETH-specific options (only used if chain_type = "megaeth")
[chain.megaeth]
gas_limit_override = 500000
use_realtime_api = true

# Wallet configuration
[wallets]
keyfile = "keys/testnet.enc"

# Funding configuration
[funding]
min_native = "10000000000000000"      # 0.01 ETH
target_native = "50000000000000000"   # 0.05 ETH

[[funding.tokens]]
address = "0x..."  # DATA token
min_balance = "50000000000000000000"
target_balance = "150000000000000000000"

# Plugin configuration
[plugins]
enabled = ["ghostnet"]

# GHOSTNET plugin config
[plugins.ghostnet]
ghost_core = "0x..."
hash_crash = "0x..."
arcade_core = "0x..."
data_token = "0x..."

# Safety settings
[safety]
max_consecutive_errors = 5
circuit_breaker_cooldown_secs = 3600
max_actions_per_wallet_per_hour = 20
global_pause = false

# Profile definitions
[profiles.whale]
risk_tolerance = 0.2
activity_level = 2.0
# ... etc
```

---

## 9. Testing Strategy

### 9.1 Unit Tests

Each crate has isolated unit tests:

```rust
// crates/evm-provider/src/tests/mod.rs

#[cfg(test)]
mod tests {
    use super::*;
    
    // Mock provider for testing
    struct MockProvider {
        balances: HashMap<Address, U256>,
        nonces: HashMap<Address, u64>,
    }
    
    #[async_trait]
    impl ChainProvider for MockProvider {
        // Implement with test data
    }
    
    #[tokio::test]
    async fn test_transaction_builder() {
        let provider = MockProvider::default();
        let builder = TransactionBuilder::new(&provider);
        // ...
    }
}
```

### 9.2 Integration Tests

Test plugins with mock providers:

```rust
// ghostnet-actions/tests/plugin_test.rs

#[tokio::test]
async fn test_ghostnet_plugin_decision() {
    let config = GhostnetConfig::test_config();
    let plugin = GhostnetPlugin::new(config);
    
    let wallet = WalletState::test_wallet_with_balance(100e18 as u128);
    let profile = BehaviorProfile::degen();
    let context = PluginContext::test_context();
    
    let decision = plugin.decide_action(&wallet, &profile, &context).await.unwrap();
    
    // Degen with balance should want to jack in
    assert!(decision.is_some());
    assert_eq!(decision.unwrap().id.0, "ghostnet.jack_in");
}
```

### 9.3 E2E Tests

Test against local anvil fork:

```rust
// ghost-fleet/tests/e2e/mod.rs

#[tokio::test]
async fn test_full_wallet_lifecycle() {
    let anvil = setup_anvil_fork().await;
    let provider = MegaEthProvider::new(&anvil.endpoint(), 31337)?;
    
    // Deploy mock contracts
    // Create wallet
    // Execute actions
    // Verify state
}
```

---

## 10. Migration Plan

### 10.1 Phase 1: Extract megaeth-rpc

1. Create `crates/megaeth-rpc/`
2. Move `MegaEthRpcClient` from indexer
3. Update indexer to use new crate
4. Verify indexer still works

### 10.2 Phase 2: Create evm-provider

1. Create `crates/evm-provider/`
2. Define `ChainProvider` trait
3. Implement `MegaEthProvider` using megaeth-rpc
4. Implement `StandardEvmProvider`

### 10.3 Phase 3: Create fleet-core

1. Create `crates/fleet-core/`
2. Implement wallet management
3. Implement scheduler
4. Implement circuit breakers
5. Define plugin traits

### 10.4 Phase 4: Create ghostnet-actions

1. Create `ghostnet-actions/`
2. Implement plugin trait
3. Move GHOSTNET-specific logic here
4. Test against mock provider

### 10.5 Phase 5: Create ghost-fleet

1. Create `ghost-fleet/`
2. Wire everything together
3. Configuration loading
4. Main service loop
5. Integration testing

---

## 11. Implementation Phases

### Week 1-2: Foundation
- [ ] Set up workspace structure
- [ ] Extract megaeth-rpc from indexer
- [ ] Create evm-provider with traits
- [ ] Verify indexer still works

### Week 3-4: Core Framework
- [ ] Create fleet-core crate
- [ ] Wallet management
- [ ] Plugin trait definition
- [ ] Scheduler implementation

### Week 5-6: GHOSTNET Plugin
- [ ] Create ghostnet-actions crate
- [ ] GhostCore actions
- [ ] HashCrash actions
- [ ] Plugin tests

### Week 7-8: Service Integration
- [ ] Create ghost-fleet service
- [ ] Configuration system
- [ ] Main loop
- [ ] Metrics & health

### Week 9-10: Production Hardening
- [ ] E2E testing
- [ ] Documentation
- [ ] Security review
- [ ] Deployment scripts

---

*End of Implementation Specification*
