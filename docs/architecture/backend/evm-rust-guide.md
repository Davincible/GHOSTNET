# Complete Guide to EVM Client Development with Rust (January 2026)

A comprehensive guide covering the latest tools, practices, antipatterns, and software versions for building Ethereum Virtual Machine (EVM) clients and infrastructure in Rust.

---

## Table of Contents

1. [Ecosystem Overview](#ecosystem-overview)
2. [Core Libraries & Frameworks](#core-libraries--frameworks)
3. [Setting Up Your Development Environment](#setting-up-your-development-environment)
4. [Alloy: The Modern Rust Ethereum Toolkit](#alloy-the-modern-rust-ethereum-toolkit)
5. [REVM: The Rust EVM Implementation](#revm-the-rust-evm-implementation)
6. [Reth: Building Full Ethereum Nodes](#reth-building-full-ethereum-nodes)
7. [Foundry: Smart Contract Development](#foundry-smart-contract-development)
8. [Helios: Light Client Development](#helios-light-client-development)
9. [Performance Optimization](#performance-optimization)
10. [Testing Strategies](#testing-strategies)
11. [Architecture Patterns](#architecture-patterns)
12. [Common Antipatterns](#common-antipatterns)
13. [Security Considerations](#security-considerations)
14. [Version Reference](#version-reference)
15. [Resources & Further Reading](#resources--further-reading)

---

## Ecosystem Overview

The Rust Ethereum ecosystem has matured significantly, with Paradigm and the community driving most of the core infrastructure. The ecosystem centers around several key projects:

| Project | Purpose | Status |
|---------|---------|--------|
| **Alloy** | RPC client library (ethers-rs successor) | v1.0+ Stable (May 2025) |
| **REVM** | EVM implementation | Production |
| **Reth** | Full Ethereum node | v1.9+ Production |
| **Foundry** | Smart contract toolkit | Production |
| **Helios** | Light client | Production |

### Recent Updates (Late 2025 - Early 2026)

- **Reth 1.9**: ~25% improvement in `newPayload` performance, overlay caching, transaction pool optimizations, new RPC endpoints (`engine_getBlobsV3`, `debug_getBadBlock`)
- **Fusaka Hard Fork**: Activated December 2025, all clients must be updated
- **Blob Count Increase**: BPO 2 (January 2026) increased blob target/max to 14/21
- **Gas Limit**: Default Ethereum mainnet gas limit now 60M

### Why Rust for EVM Development?

- **Memory safety**: Eliminates entire classes of bugs without garbage collection
- **Performance**: 2-5x faster than Go implementations, 30-50% less memory usage
- **Concurrency**: Fearless concurrency with ownership model
- **WebAssembly**: First-class WASM support for browser/embedded targets
- **Type system**: Catch errors at compile time

---

## Core Libraries & Frameworks

### Primary Dependencies

```toml
[dependencies]
# Core Ethereum toolkit (REQUIRED - replaces ethers-rs)
alloy = { version = "1.4", features = ["full"] }

# EVM implementation
revm = "19"

# Async runtime
tokio = { version = "1", features = ["full"] }

# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"

# Error handling
eyre = "0.6"
thiserror = "2"

# Logging
tracing = "0.1"
tracing-subscriber = "0.3"
```

### For Node Development (Reth-based)

```toml
[dependencies]
reth = { git = "https://github.com/paradigmxyz/reth.git" }
reth-exex = { git = "https://github.com/paradigmxyz/reth.git" }
reth-node-ethereum = { git = "https://github.com/paradigmxyz/reth.git" }
reth-db = { git = "https://github.com/paradigmxyz/reth.git" }
```

---

## Setting Up Your Development Environment

### Prerequisites

```bash
# Install Rust (use nightly for some features)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup default stable
rustup update

# Verify version (Alloy requires Rust 1.88+)
rustc --version

# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install additional tools
cargo install cargo-watch cargo-expand cargo-flamegraph
```

### Project Structure

```
my-evm-project/
├── Cargo.toml
├── src/
│   ├── main.rs
│   ├── lib.rs
│   ├── provider/          # RPC provider logic
│   ├── evm/               # EVM execution logic
│   ├── storage/           # Database layer
│   ├── types/             # Custom types
│   └── utils/             # Helper functions
├── tests/
│   ├── integration/
│   └── unit/
├── benches/               # Performance benchmarks
└── examples/
```

---

## Alloy: The Modern Rust Ethereum Toolkit

> **IMPORTANT**: ethers-rs is deprecated. All new projects should use Alloy.

### Basic Provider Setup

```rust
use alloy::{
    primitives::{address, Address, U256},
    providers::{Provider, ProviderBuilder},
    sol,
};
use std::error::Error;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // HTTP provider
    let provider = ProviderBuilder::new()
        .connect("https://eth.llamarpc.com")
        .await?;

    // Get latest block
    let block_number = provider.get_block_number().await?;
    println!("Latest block: {}", block_number);

    // Get balance
    let address = address!("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045");
    let balance = provider.get_balance(address).await?;
    println!("Balance: {} wei", balance);

    Ok(())
}
```

### Smart Contract Interaction with `sol!` Macro

```rust
use alloy::{
    primitives::{address, U256},
    providers::ProviderBuilder,
    sol,
};

// Generate type-safe bindings from Solidity
sol! {
    #[sol(rpc)]
    contract ERC20 {
        function balanceOf(address owner) public view returns (uint256);
        function transfer(address to, uint256 amount) public returns (bool);
        function approve(address spender, uint256 amount) public returns (bool);
        
        event Transfer(address indexed from, address indexed to, uint256 value);
    }
}

#[tokio::main]
async fn main() -> eyre::Result<()> {
    let provider = ProviderBuilder::new()
        .connect("https://eth.llamarpc.com")
        .await?;

    let weth = address!("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2");
    let contract = ERC20::new(weth, provider);

    let owner = address!("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045");
    let balance = contract.balanceOf(owner).call().await?;
    
    println!("WETH Balance: {}", balance);
    Ok(())
}
```

### WebSocket Subscriptions

```rust
use alloy::{
    primitives::address,
    providers::{Provider, ProviderBuilder, WsConnect},
    sol,
};
use futures_util::StreamExt;

sol! {
    #[sol(rpc)]
    contract WETH {
        function balanceOf(address) external view returns (uint256);
    }
}

#[tokio::main]
async fn main() -> eyre::Result<()> {
    let ws = WsConnect::new("wss://eth-mainnet.g.alchemy.com/v2/YOUR_KEY");
    let provider = ProviderBuilder::new().connect_ws(ws).await?;

    // Subscribe to new blocks
    let mut block_stream = provider.subscribe_blocks().await?.into_stream();

    println!("Monitoring for new blocks...");

    while let Some(block) = block_stream.next().await {
        println!("Block #{}: {}", block.number, block.hash);
    }

    Ok(())
}
```

### Multicall for Batched Requests

```rust
use alloy::contract::multicall::Multicall;

async fn batch_balance_check(provider: impl Provider) -> eyre::Result<()> {
    let multicall = Multicall::new(provider.clone(), None).await?;

    // Add multiple calls
    multicall.add_call(contract1.balanceOf(user1), false);
    multicall.add_call(contract2.balanceOf(user2), false);
    multicall.add_call(contract3.totalSupply(), false);

    // Execute all calls in single RPC request
    let results = multicall.call().await?;
    
    Ok(())
}
```

### Migration from ethers-rs

| ethers-rs | Alloy |
|-----------|-------|
| `ethers::providers` | `alloy::providers` |
| `ethers::types::U256` | `alloy::primitives::U256` |
| `ethers::types::Address` | `alloy::primitives::Address` |
| `ethers::contract::abigen!` | `alloy::sol!` |
| `ethers::middleware` | `alloy::provider::{fillers, layers}` |
| `ethers::signers` | `alloy::signers` |

---

## REVM: The Rust EVM Implementation

REVM is the high-performance EVM used by Reth, Foundry, and most Rust-based Ethereum tooling.

### Basic Transaction Execution

```rust
use revm::{
    primitives::{address, U256, Bytes, TxKind},
    Context, ExecuteEvm,
};

fn execute_transaction() -> eyre::Result<()> {
    // Create EVM context with mainnet configuration
    let mut evm = Context::mainnet()
        .with_block(block_env)
        .build_mainnet();

    // Execute transaction
    let result = evm.transact(tx)?;

    match result.result {
        revm::primitives::ExecutionResult::Success { output, gas_used, .. } => {
            println!("Success! Gas used: {}", gas_used);
        }
        revm::primitives::ExecutionResult::Revert { output, gas_used } => {
            println!("Reverted: {:?}", output);
        }
        revm::primitives::ExecutionResult::Halt { reason, gas_used } => {
            println!("Halted: {:?}", reason);
        }
    }

    Ok(())
}
```

### Using REVM with Alloy Database

```rust
use alloy::providers::{Provider, ProviderBuilder};
use revm::{
    db::{AlloyDB, CacheDB},
    primitives::{address, Address, Bytes, TxKind, U256},
    Context, Evm,
};

type AlloyCacheDB = CacheDB<AlloyDB<Http<Client>, Ethereum, Arc<RootProvider<Http<Client>>>>>;

pub fn revm_call(
    from: Address,
    to: Address,
    calldata: Bytes,
    cache_db: &mut AlloyCacheDB,
) -> eyre::Result<Bytes> {
    let mut evm = Evm::builder()
        .with_db(cache_db)
        .modify_tx_env(|tx| {
            tx.caller = from;
            tx.transact_to = TxKind::Call(to);
            tx.data = calldata;
            tx.value = U256::ZERO;
        })
        .build();

    let result = evm.transact()?;
    
    match result.result {
        ExecutionResult::Success { output: Output::Call(value), .. } => Ok(value),
        result => Err(eyre::eyre!("Execution failed: {:?}", result)),
    }
}
```

### Custom Inspector for Tracing

```rust
use revm::{
    interpreter::{CallInputs, CallOutcome, CreateInputs, CreateOutcome, Interpreter},
    Inspector,
};

#[derive(Default)]
struct CallTracer {
    calls: Vec<TracedCall>,
}

impl<DB: Database> Inspector<DB> for CallTracer {
    fn call(&mut self, context: &mut Context<DB>, inputs: &mut CallInputs) -> Option<CallOutcome> {
        self.calls.push(TracedCall {
            from: inputs.caller,
            to: inputs.target_address,
            value: inputs.value,
            input: inputs.input.clone(),
        });
        None
    }

    fn call_end(
        &mut self,
        context: &mut Context<DB>,
        inputs: &CallInputs,
        outcome: &mut CallOutcome,
    ) {
        // Handle call completion
    }
}

// Use with EVM
let mut evm = evm.with_inspector(CallTracer::default());
let result = evm.inspect_tx(tx)?;
```

---

## Reth: Building Full Ethereum Nodes

Reth is a modular, high-performance Ethereum execution client.

### Key Architecture Concepts

1. **Staged Sync**: Synchronization happens in discrete stages (headers, bodies, execution, etc.)
2. **MDBX Database**: Memory-mapped database for high-performance state storage
3. **Modular Components**: Every component is a reusable library

### Execution Extensions (ExEx)

ExEx allows building custom infrastructure that runs alongside the node:

```rust
use reth::cli::Cli;
use reth_exex::{ExExContext, ExExEvent, ExExNotification};
use reth_node_ethereum::EthereumNode;
use futures_util::StreamExt;

async fn my_exex(mut ctx: ExExContext<EthereumNode>) -> eyre::Result<()> {
    while let Some(notification) = ctx.notifications.recv().await {
        match notification {
            ExExNotification::ChainCommitted { new } => {
                for block in new.blocks() {
                    println!(
                        "Block {} committed with {} transactions",
                        block.number,
                        block.body.transactions.len()
                    );
                }
                
                // Signal that we've processed up to this block
                ctx.events.send(ExExEvent::FinishedHeight(new.tip().number))?;
            }
            ExExNotification::ChainReverted { old } => {
                println!("Chain reverted {} blocks", old.len());
            }
            ExExNotification::ChainReorged { old, new } => {
                println!("Chain reorg: {} old -> {} new", old.len(), new.len());
            }
        }
    }
    Ok(())
}

fn main() -> eyre::Result<()> {
    Cli::parse_args().run(|builder, _| async move {
        let handle = builder
            .node(EthereumNode::default())
            .install_exex("my-exex", |ctx| async move { my_exex(ctx).await })
            .launch()
            .await?;
        
        handle.wait_for_node_exit().await
    })
}
```

### Custom Precompiles

```rust
use reth::primitives::revm_primitives::{
    Precompile, PrecompileOutput, PrecompileResult,
};

fn custom_precompile(input: &Bytes, gas_limit: u64) -> PrecompileResult {
    // Implement custom logic
    let result = process_input(input)?;
    
    Ok(PrecompileOutput {
        gas_used: 1000,
        bytes: result,
    })
}

// Register precompile at address
let precompiles = PrecompileSet::new()
    .with(address!("0x0000000000000000000000000000000000000100"), custom_precompile);
```

---

## Foundry: Smart Contract Development

Foundry provides Forge (testing), Cast (CLI), Anvil (local node), and Chisel (REPL).

### Testing with Forge

```bash
# Initialize project
forge init my_project
cd my_project

# Build contracts
forge build

# Run tests
forge test -vvvv  # Maximum verbosity

# Fork mainnet tests
forge test --fork-url https://eth.llamarpc.com

# Gas snapshot
forge snapshot

# Coverage report
forge coverage
```

### Anvil for Local Development

```bash
# Start local node
anvil

# Fork mainnet
anvil --fork-url https://eth.llamarpc.com

# With specific block
anvil --fork-url https://eth.llamarpc.com --fork-block-number 18000000
```

### Cast for CLI Interactions

```bash
# Check balance
cast balance vitalik.eth --ether --rpc-url https://eth.llamarpc.com

# Call contract function
cast call 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 \
    "balanceOf(address)" 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045 \
    --rpc-url https://eth.llamarpc.com

# Decode calldata
cast 4byte-decode 0xa9059cbb000000...
```

---

## Helios: Light Client Development

Helios is a trustless light client that syncs in seconds.

### Basic Usage

```rust
use helios::{
    client::{ClientBuilder, FileDB},
    config::networks::Network,
};

#[tokio::main]
async fn main() -> eyre::Result<()> {
    let client = ClientBuilder::new()
        .network(Network::Mainnet)
        .execution_rpc("https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY")
        .consensus_rpc("https://www.lightclientdata.org")
        .build()?;

    client.start().await?;
    
    // Wait for sync
    client.wait_synced().await;

    // Now make verified RPC calls
    let block = client.get_block_number().await?;
    println!("Latest block: {}", block);

    Ok(())
}
```

### Embedding in Applications

Helios can be embedded in wallets, dApps, or compiled to WebAssembly for browser use.

---

## Performance Optimization

### 1. Zero-Copy Operations

```rust
// BAD: Unnecessary cloning
fn process_data(data: Vec<u8>) -> Vec<u8> {
    let copy = data.clone();  // Expensive!
    transform(copy)
}

// GOOD: Use references
fn process_data(data: &[u8]) -> Vec<u8> {
    transform(data)
}

// GOOD: Use Cow for conditional ownership
use std::borrow::Cow;

fn process_data(data: Cow<'_, [u8]>) -> Vec<u8> {
    if needs_modification(&data) {
        transform(data.into_owned())
    } else {
        data.into_owned()
    }
}
```

### 2. Alloy U256 Performance

Alloy's U256 (based on `ruint`) is 35-60% faster than ethers-rs:

```rust
use alloy::primitives::U256;

// AMM calculation - optimized
pub fn get_amount_out(
    amount_in: U256,
    reserve_in: U256,
    reserve_out: U256,
) -> U256 {
    let amount_in_with_fee = amount_in * U256::from(997);
    let numerator = amount_in_with_fee * reserve_out;
    let denominator = reserve_in * U256::from(1000) + amount_in_with_fee;
    numerator / denominator
}
```

### 3. Database Optimization with MDBX

```rust
use reth_db::{
    database::Database,
    mdbx::{DatabaseEnv, WriteMap},
    tables,
};

// Use read transactions for queries
let tx = db.tx()?;
let account = tx.get::<tables::PlainAccountState>(address)?;

// Batch writes in single transaction
let mut tx = db.tx_mut()?;
for (key, value) in updates {
    tx.put::<tables::PlainAccountState>(key, value)?;
}
tx.commit()?;
```

### 4. Async Best Practices

```rust
// BAD: Sequential requests
async fn get_balances_bad(addresses: Vec<Address>) -> Vec<U256> {
    let mut balances = vec![];
    for addr in addresses {
        balances.push(provider.get_balance(addr).await.unwrap());
    }
    balances
}

// GOOD: Concurrent requests
async fn get_balances_good(addresses: Vec<Address>) -> Vec<U256> {
    let futures: Vec<_> = addresses
        .iter()
        .map(|addr| provider.get_balance(*addr))
        .collect();
    
    futures::future::join_all(futures)
        .await
        .into_iter()
        .filter_map(Result::ok)
        .collect()
}
```

### 5. Caching Strategies

```rust
use revm::db::CacheDB;

// Cache contract bytecode and state
fn init_cache_db<P: Provider>(provider: Arc<P>) -> CacheDB<AlloyDB<...>> {
    let alloy_db = AlloyDB::new(provider, Default::default());
    CacheDB::new(alloy_db)
}

// Reuse cache across simulations
let mut cache = init_cache_db(provider);

for tx in transactions {
    // Bytecode is fetched once, then cached
    let result = simulate_tx(&mut cache, tx)?;
}
```

---

## Testing Strategies

### Unit Testing

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use alloy::primitives::{address, U256};

    #[test]
    fn test_amount_calculation() {
        let amount_in = U256::from(1_000_000);
        let reserve_in = U256::from(100_000_000);
        let reserve_out = U256::from(50_000_000);

        let result = get_amount_out(amount_in, reserve_in, reserve_out);
        
        assert!(result > U256::ZERO);
        assert!(result < reserve_out);
    }

    #[tokio::test]
    async fn test_provider_connection() {
        let provider = ProviderBuilder::new()
            .connect("http://localhost:8545")
            .await
            .unwrap();

        let block = provider.get_block_number().await.unwrap();
        assert!(block > 0);
    }
}
```

### Integration Testing with Anvil

```rust
use alloy::providers::ext::AnvilApi;

#[tokio::test]
async fn test_with_fork() {
    let provider = ProviderBuilder::new()
        .connect_anvil_with_config(|anvil| {
            anvil.fork("https://eth.llamarpc.com")
        });

    // Impersonate whale account
    let whale = address!("0x...");
    provider.anvil_impersonate_account(whale).await.unwrap();

    // Test with real state
    // ...
}
```

### Fuzz Testing

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn fuzz_amount_calculation(
        amount_in in 1u64..u64::MAX,
        reserve_in in 1000u64..u64::MAX,
        reserve_out in 1000u64..u64::MAX,
    ) {
        let result = get_amount_out(
            U256::from(amount_in),
            U256::from(reserve_in),
            U256::from(reserve_out),
        );
        
        // Invariant: output should never exceed reserve
        prop_assert!(result < U256::from(reserve_out));
    }
}
```

### Benchmarking

```rust
use criterion::{criterion_group, criterion_main, Criterion};

fn benchmark_u256_operations(c: &mut Criterion) {
    let a = U256::from(12345678901234567890u128);
    let b = U256::from(98765432109876543210u128);

    c.bench_function("u256_add", |bencher| {
        bencher.iter(|| a + b)
    });

    c.bench_function("u256_mul", |bencher| {
        bencher.iter(|| a * b)
    });
}

criterion_group!(benches, benchmark_u256_operations);
criterion_main!(benches);
```

---

## Architecture Patterns

### 1. Provider Layer Pattern

```rust
pub trait ChainProvider: Send + Sync {
    async fn get_block(&self, number: u64) -> eyre::Result<Block>;
    async fn get_balance(&self, address: Address) -> eyre::Result<U256>;
    async fn send_transaction(&self, tx: Transaction) -> eyre::Result<TxHash>;
}

// Implement for different backends
pub struct RpcProvider { /* ... */ }
pub struct MockProvider { /* ... */ }
pub struct CachingProvider<P: ChainProvider> { inner: P, cache: Cache }
```

### 2. Database Abstraction

```rust
pub trait StateDatabase {
    fn get_account(&self, address: Address) -> Option<Account>;
    fn get_storage(&self, address: Address, slot: U256) -> U256;
    fn set_account(&mut self, address: Address, account: Account);
    fn set_storage(&mut self, address: Address, slot: U256, value: U256);
}

// Implementations
pub struct InMemoryDb { /* ... */ }
pub struct MdbxDb { /* ... */ }
pub struct ForkDb<P: Provider> { /* ... */ }
```

### 3. Transaction Pipeline

```rust
pub struct TxPipeline {
    validator: Box<dyn TxValidator>,
    simulator: Box<dyn TxSimulator>,
    broadcaster: Box<dyn TxBroadcaster>,
}

impl TxPipeline {
    pub async fn process(&self, tx: Transaction) -> eyre::Result<TxReceipt> {
        // Validate
        self.validator.validate(&tx)?;
        
        // Simulate
        let simulation = self.simulator.simulate(&tx).await?;
        if !simulation.success {
            return Err(eyre::eyre!("Simulation failed"));
        }
        
        // Broadcast
        let hash = self.broadcaster.broadcast(tx).await?;
        
        // Wait for receipt
        self.broadcaster.wait_for_receipt(hash).await
    }
}
```

---

## Common Antipatterns

### ❌ Using Deprecated Libraries

```rust
// BAD: ethers-rs is deprecated
use ethers::prelude::*;

// GOOD: Use Alloy
use alloy::prelude::*;
```

### ❌ Blocking in Async Context

```rust
// BAD: Blocking call in async function
async fn bad_function() {
    std::thread::sleep(Duration::from_secs(1));  // Blocks executor!
}

// GOOD: Use async sleep
async fn good_function() {
    tokio::time::sleep(Duration::from_secs(1)).await;
}
```

### ❌ Ignoring Gas Estimation

```rust
// BAD: Hardcoded gas limit
let tx = TransactionRequest::default()
    .gas(21000);  // Will fail for contract calls

// GOOD: Estimate gas
let gas = provider.estimate_gas(&tx).await?;
let tx = tx.gas(gas * 120 / 100);  // Add 20% buffer
```

### ❌ Not Handling Reorgs

```rust
// BAD: Assuming finality
if tx_confirmed {
    update_database(tx);
}

// GOOD: Wait for sufficient confirmations
let confirmations = 12;
loop {
    let current = provider.get_block_number().await?;
    if current - tx_block >= confirmations {
        update_database(tx);
        break;
    }
    tokio::time::sleep(Duration::from_secs(12)).await;
}
```

### ❌ Excessive RPC Calls

```rust
// BAD: Individual calls
for addr in addresses {
    let balance = provider.get_balance(addr).await?;
}

// GOOD: Use multicall
let multicall = Multicall::new(provider, None).await?;
for addr in addresses {
    multicall.add_get_balance(addr);
}
let balances = multicall.call().await?;
```

### ❌ Not Caching Immutable Data

```rust
// BAD: Fetching bytecode every time
for _ in 0..1000 {
    let code = provider.get_code(contract_addr).await?;
    simulate(code);
}

// GOOD: Cache bytecode
let code = provider.get_code(contract_addr).await?;
for _ in 0..1000 {
    simulate(&code);
}
```

---

## Security Considerations

### 1. Private Key Management

```rust
// NEVER hardcode private keys
// BAD:
let key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

// GOOD: Use environment variables or secure storage
let key = std::env::var("PRIVATE_KEY")?;

// BETTER: Use keystore files
use alloy::signers::local::LocalSigner;
let signer = LocalSigner::decrypt_keystore(path, password)?;
```

### 2. RPC Endpoint Security

```rust
// Use authenticated endpoints
let provider = ProviderBuilder::new()
    .with_header("Authorization", format!("Bearer {}", api_key))
    .connect(rpc_url)
    .await?;

// Consider using Helios for trustless verification
```

### 3. Transaction Validation

```rust
// Always validate before signing
fn validate_transaction(tx: &Transaction) -> eyre::Result<()> {
    // Check recipient isn't a known phishing address
    if BLACKLIST.contains(&tx.to) {
        return Err(eyre::eyre!("Recipient blacklisted"));
    }
    
    // Verify value is within acceptable bounds
    if tx.value > MAX_TRANSFER_VALUE {
        return Err(eyre::eyre!("Value too high"));
    }
    
    Ok(())
}
```

### 4. Frontrunning Protection

```rust
// Use Flashbots or similar for MEV protection
use alloy::providers::ext::FlashbotsApi;

let bundle = FlashbotsBundle::new()
    .add_transaction(tx)
    .build();

provider.send_bundle(bundle).await?;
```

---

## Version Reference

### Current Stable Versions (January 2026)

| Package | Version | MSRV |
|---------|---------|------|
| **alloy** | 1.4.x | Rust 1.88 |
| **revm** | 19.x | Rust 1.85 |
| **reth** | 1.9.x | Rust 1.86 |
| **foundry** | nightly | Latest stable |
| **helios** | 0.6.x | Rust nightly |

### Recent Network Updates (Late 2025 - Early 2026)

- **Fulu-Osaka (Fusaka) Hard Fork**: Activated December 2025 on mainnet
- **BPO 2**: Epoch 419,072 (January 7, 2026) - increased blob count to target/max 14/21
- **Default Ethereum mainnet gas limit**: Now 60M (increased from 45M)
- **eth69**: Enabled by default for devp2p in Reth 1.9

### Cargo.toml Example

```toml
[package]
name = "my-evm-project"
version = "0.1.0"
edition = "2024"
rust-version = "1.88"

[dependencies]
alloy = { version = "1.4", features = ["full"] }
revm = "19"
tokio = { version = "1", features = ["full"] }
eyre = "0.6"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"

[dev-dependencies]
proptest = "1"
criterion = "0.5"

[[bench]]
name = "benchmarks"
harness = false
```

---

## Resources & Further Reading

### Official Documentation

- [Alloy Book](https://alloy.rs/)
- [Alloy Examples](https://github.com/alloy-rs/examples)
- [REVM Documentation](https://docs.rs/revm)
- [Reth Book](https://reth.rs/)
- [Foundry Book](https://book.getfoundry.sh/)
- [Helios GitHub](https://github.com/a16z/helios)

### Community Resources

- [Awesome Reth](https://github.com/jmcph4/awesome-reth)
- [ExEx Directory](https://exex.rs/)
- [Reth ExEx Examples](https://github.com/paradigmxyz/reth-exex-examples)
- [Paradigm Blog](https://www.paradigm.xyz/writing)

### Learning Resources

- [Ethereum Yellow Paper](https://ethereum.github.io/yellowpaper/paper.pdf)
- [EVM Illustrated](https://takenobu-hs.github.io/downloads/ethereum_evm_illustrated.pdf)
- [Rust Design Patterns](https://rust-unofficial.github.io/patterns/)

### Discord/Telegram Communities

- Reth Discord
- Foundry Telegram
- Paradigm Research Discord

---

## Changelog

- **2026-01**: Initial comprehensive guide covering Fusaka hard fork era
- Covers Alloy v1.0+, REVM 19, Reth 1.9, Fusaka network upgrades

---

*This guide is maintained by the community. Contributions welcome!*
