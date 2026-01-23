# evm-provider

Chain abstraction layer for EVM-compatible blockchains.

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

## Architecture

```
┌─────────────────────────────────────────────────┐
│              Your Application                    │
└─────────────────────────────────────────────────┘
                       │
                       │ uses
                       ▼
┌─────────────────────────────────────────────────┐
│           ChainProvider trait (Port)            │
└─────────────────────────────────────────────────┘
                       │
         ┌─────────────┴─────────────┐
         │                           │
         ▼                           ▼
┌─────────────────┐       ┌─────────────────────┐
│ StandardEvm     │       │ MegaEthProvider     │
│ Provider        │       │                     │
│                 │       │ + realtime API      │
│ uses: alloy     │       │ + cursor pagination │
└─────────────────┘       └─────────────────────┘
```

## License

MIT
