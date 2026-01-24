# evm-provider

Chain abstraction layer for EVM-compatible blockchains.

## Where This Crate Fits

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Ghost Fleet Services                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐   │
│  │  ghost-fleet    │     │ ghostnet-actions│     │ghostnet-indexer │   │
│  │  (orchestrator) │     │    (plugin)     │     │   (indexer)     │   │
│  └────────┬────────┘     └────────┬────────┘     └────────┬────────┘   │
│           │                       │                       │             │
│           └───────────────┬───────┴───────────────────────┘             │
│                           │                                              │
│                           ▼                                              │
│           ┌───────────────────────────────┐                             │
│           │         fleet-core            │                             │
│           │  (wallets, plugins, safety)   │                             │
│           └───────────────┬───────────────┘                             │
│                           │                                              │
│                           ▼                                              │
│           ╔═══════════════════════════════╗                             │
│           ║        evm-provider           ║  ◄── YOU ARE HERE           │
│           ║   (ChainProvider trait)       ║                             │
│           ╚═══════════════╤═══════════════╝                             │
│                           │                                              │
│              ┌────────────┴────────────┐                                │
│              │                         │                                 │
│              ▼                         ▼                                 │
│  ┌───────────────────┐     ┌───────────────────┐                        │
│  │ StandardEvmProvider│    │  MegaEthProvider  │                        │
│  │    (uses alloy)   │     │ (uses megaeth-rpc)│                        │
│  └───────────────────┘     └─────────┬─────────┘                        │
│                                      │                                   │
│                                      ▼                                   │
│                          ┌───────────────────────┐                      │
│                          │    megaeth-rpc        │                      │
│                          │  (MegaETH RPC client) │                      │
│                          └───────────────────────┘                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**This crate is the chain abstraction layer** - it defines traits that hide chain-specific
details, allowing application code to work with any EVM chain.

**Key relationships:**

| Crate | Relationship | Purpose |
|-------|--------------|---------|
| [`megaeth-rpc`](../megaeth-rpc) | **Dependency** (optional) | Low-level MegaETH RPC client; wrapped by `MegaEthProvider` |
| `fleet-core` | **Consumer** | Uses `ChainProvider` trait for wallet operations |
| `ghostnet-indexer` | **Consumer** | Uses providers for event indexing |

**When to use this crate:**
- Building application logic that should work on any EVM chain
- You want dependency injection via the `ChainProvider` trait
- You need automatic feature detection (realtime API, cursor pagination)
- You want safe defaults (gas limits, memory protection)

**When to use `megaeth-rpc` directly:**
- Building a custom indexer needing low-level cursor control
- Implementing a new provider type
- Direct RPC access without abstraction

## Overview

This crate provides a unified interface for interacting with EVM chains, abstracting away chain-specific quirks while supporting extended features like MegaETH's realtime API.

## Quick Start

```rust
use evm_provider::{ChainProvider, TransactionRequest};
use alloy::primitives::{Address, U256};

async fn check_and_send<P: ChainProvider>(
    provider: &P,
    from: Address,
    to: Address,
) -> evm_provider::Result<()> {
    // Check balance
    let balance = provider.get_balance(from).await?;
    println!("Balance: {} wei", balance);

    // Get nonce
    let nonce = provider.get_nonce(from).await?;
    
    // Build transaction
    let request = TransactionRequest::new()
        .to(to)
        .value(U256::from(1_000_000_000_000_000_000u64))
        .nonce(nonce);
    
    // Sign and send...
    Ok(())
}
```

## Core Traits

### `ChainProvider`

Basic blockchain operations:

| Method | Description |
|--------|-------------|
| `chain_id()` | Get chain identifier |
| `get_balance(address)` | Get native token balance |
| `get_nonce(address)` | Get transaction count |
| `send_raw_transaction(tx)` | Submit signed transaction |
| `wait_for_receipt(hash, timeout)` | Wait for confirmation |
| `gas_price()` | Get current gas price |
| `call(request)` | Execute read-only call |
| `estimate_gas(request)` | Estimate gas (default: 500k) |
| `get_token_balance(token, account)` | Get ERC20 balance |

### `ExtendedChainProvider`

Optional extended features (MegaETH):

| Method | Description |
|--------|-------------|
| `supports_realtime()` | Check realtime API support |
| `supports_cursor_pagination()` | Check cursor pagination support |
| `send_realtime(tx)` | Send with instant receipt |
| `get_logs_with_cursor(filter, cursor)` | Paginated log queries |
| `get_all_logs(filter)` | Fetch all logs (auto-paginate) |

### `NonceManager`

Thread-safe nonce tracking:

| Method | Description |
|--------|-------------|
| `get_and_increment(address)` | Atomic get and increment |
| `sync(address)` | Sync with chain state |
| `set(address, nonce)` | Manually override nonce |
| `peek(address)` | Get current without increment |

## Types

### `TransactionRequest`

Builder for transaction requests:

```rust
let request = TransactionRequest::new()
    .to(recipient)
    .value(U256::from(1_000_000_000_000_000_000u64))
    .data(calldata)
    .gas_limit(100_000)
    .nonce(42);
```

### `TransactionReceipt`

Confirmed transaction details:

```rust
if receipt.is_success() {
    println!("Tx {} confirmed in block {}", 
        receipt.tx_hash, 
        receipt.block_number);
}
```

### `LogFilter`

Filter for log queries:

```rust
let filter = LogFilter::new(from_block, to_block)
    .with_address(contract)
    .with_event_signature(event_sig);
```

## Nonce Management

For high-throughput scenarios, use `LocalNonceManager`:

```rust
use evm_provider::{LocalNonceManager, NonceManager};

let manager = LocalNonceManager::new(provider);

// Get unique nonces atomically
let nonce1 = manager.get_and_increment(address).await?;
let nonce2 = manager.get_and_increment(address).await?;
assert!(nonce1 != nonce2);

// After tx failure, resync with chain
manager.sync(address).await?;
```

## Error Handling

Errors are categorized for easy handling:

```rust
match result {
    Ok(data) => { /* success */ }
    Err(e) if e.is_retryable() => {
        // Retry after backoff (network issues, rate limits)
    }
    Err(e) if e.is_nonce_error() => {
        // Resync nonce and retry
        manager.sync(address).await?;
    }
    Err(e) => {
        // Handle other errors
    }
}
```

## Feature Flags

| Feature | Description |
|---------|-------------|
| `default` | Core traits and types only |
| `megaeth` | Enables `MegaEthProvider` implementation |

## Provider Implementations

### `StandardEvmProvider`

Works with any EVM chain via [alloy](https://github.com/alloy-rs/alloy). Good default for
Ethereum, Arbitrum, Optimism, Base, etc.

```rust
use evm_provider::StandardEvmProvider;

let provider = StandardEvmProvider::new("https://eth.llamarpc.com").await?;
let balance = provider.get_balance(address).await?;
```

### `MegaEthProvider` (requires `megaeth` feature)

Wraps [`megaeth-rpc`](../megaeth-rpc) to provide MegaETH-specific features through the
standard `ChainProvider` interface.

```rust
use evm_provider::MegaEthProvider;

let provider = MegaEthProvider::new("https://carrot.megaeth.com/rpc", 6343)?;

// Use standard ChainProvider methods
let balance = provider.get_balance(address).await?;

// Or extended features (via ExtendedChainProvider)
if provider.supports_realtime() {
    let receipt = provider.send_realtime(signed_tx).await?;
}
```

**What `MegaEthProvider` adds:**
- **Fixed gas limit** (10M) — MegaETH gas estimation is unreliable
- **Realtime API** — `send_realtime()` returns receipt in ~10ms
- **Cursor pagination** — `get_logs_with_cursor()` for large log ranges
- **Automatic feature detection** — checks endpoint capabilities on connect

**Why wrap instead of using megaeth-rpc directly?**
- Your application code uses `ChainProvider` trait, not concrete types
- Easy to swap providers for testing (mock) or multi-chain support
- Consistent error handling via `ProviderError`
- Memory safety defaults (max logs, max batches)

## Architecture

This crate follows the **ports-and-adapters** (hexagonal) pattern:

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Application                          │
│  (fleet-core, ghostnet-indexer, etc.)                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ depends on trait, not concrete type
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              ChainProvider / ExtendedChainProvider          │
│                         (PORT)                               │
│                                                              │
│  • Chain-agnostic interface                                 │
│  • Easy to mock for testing                                 │
│  • Swap implementations without changing app code           │
└─────────────────────────────────────────────────────────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
┌──────────────────────┐     ┌──────────────────────────────┐
│  StandardEvmProvider │     │      MegaEthProvider         │
│      (ADAPTER)       │     │        (ADAPTER)             │
│                      │     │                              │
│  • Uses alloy        │     │  • Wraps megaeth-rpc         │
│  • Any EVM chain     │     │  • Realtime API support      │
│  • Standard features │     │  • Cursor pagination         │
└──────────────────────┘     │  • Fixed gas limits          │
                             └──────────────────────────────┘
                                          │
                                          │ uses
                                          ▼
                             ┌──────────────────────────────┐
                             │        megaeth-rpc           │
                             │   (MegaETH-specific crate)   │
                             │                              │
                             │  • Low-level RPC client      │
                             │  • Cursor pagination impl    │
                             │  • Realtime transaction API  │
                             └──────────────────────────────┘
```

## Related Crates

| Crate | Relationship | Description |
|-------|--------------|-------------|
| [`megaeth-rpc`](../megaeth-rpc) | **Dependency** | MegaETH RPC client; wrapped by `MegaEthProvider` |
| `fleet-core` | **Consumer** | Wallet management, plugins; uses `ChainProvider` trait |
| `ghostnet-indexer` | **Consumer** | Event indexer; uses providers for chain access |
| `ghost-fleet` | **Consumer** | Main service; creates providers based on config |

## Versioning

This crate follows [SemVer](https://semver.org/). The public API includes:

- `ChainProvider`, `ExtendedChainProvider`, `NonceManager` traits
- `StandardEvmProvider`, `MegaEthProvider` (with `megaeth` feature)
- `LocalNonceManager` implementation
- All types in `types` module (`TransactionRequest`, `TransactionReceipt`, etc.)
- `ProviderError` and its variants

## License

MIT
