# megaeth-rpc

MegaETH-specific JSON-RPC client with cursor pagination and realtime API support.

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
│           ┌───────────────────────────────┐                             │
│           │        evm-provider           │  ◄── Chain abstraction      │
│           │   (ChainProvider trait)       │      layer                  │
│           └───────────────┬───────────────┘                             │
│                           │                                              │
│              ┌────────────┴────────────┐                                │
│              │                         │                                 │
│              ▼                         ▼                                 │
│  ┌───────────────────┐     ┌───────────────────┐                        │
│  │ StandardEvmProvider│    │  MegaEthProvider  │                        │
│  │    (uses alloy)   │     │                   │                        │
│  └───────────────────┘     └─────────┬─────────┘                        │
│                                      │                                   │
│                                      ▼                                   │
│                          ╔═══════════════════════╗                      │
│                          ║    megaeth-rpc        ║  ◄── YOU ARE HERE    │
│                          ║  (MegaETH RPC client) ║                      │
│                          ╚═══════════════════════╝                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**This crate is the lowest layer** - a specialized RPC client that handles MegaETH's
unique JSON-RPC extensions. It is used by:

- **`evm-provider`**: Wraps `MegaEthClient` in `MegaEthProvider` to implement the
  `ChainProvider` trait, enabling chain-agnostic application code
- **`ghostnet-indexer`**: Uses cursor pagination directly for efficient event indexing

**When to use this crate directly:**
- Building a custom indexer that needs low-level cursor control
- Implementing a new provider in `evm-provider`
- Direct RPC access without the abstraction layer

**When to use `evm-provider` instead:**
- Building application logic that should work on any EVM chain
- You want automatic feature detection and fallbacks
- You need the `ChainProvider` trait for dependency injection

## Overview

This crate provides `MegaEthClient`, a specialized RPC client for MegaETH's extended JSON-RPC API. It handles the unique characteristics of MegaETH:

- **High throughput**: MegaETH processes ~1000 TPS, generating massive data volumes
- **Cursor pagination**: `eth_getLogsWithCursor` for efficient large-range queries
- **Realtime API**: `realtime_sendRawTransaction` for instant receipts (~10ms)

## MegaETH's Dual Block Model

Understanding why this crate exists requires understanding MegaETH's architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                      TIME FLOW →                             │
├─────────────────────────────────────────────────────────────┤
│ Mini Blocks:  [M1][M2][M3]...[M99][M100]  (10ms each)       │
│                        ↓                                     │
│ EVM Block:    [═══════════ B1 ═══════════]  (1s total)      │
│                                                              │
│ • Mini blocks: instant preconfirmation, Realtime API        │
│ • EVM blocks:  standard EVM compatibility, finality         │
└─────────────────────────────────────────────────────────────┘
```

**Key insight**: The sequencer commits to mini blocks just as strongly as EVM blocks.
Results from the Realtime API have the same preconfirmation guarantees as standard RPC.

**Standard RPC** queries against EVM blocks (1s latency).
**Realtime API** queries against mini blocks (10ms latency).

## Why This Crate?

Standard Ethereum RPC clients don't handle MegaETH's data scale. At 1000 TPS, MegaETH generates **a year of Ethereum data every 5 days**. Standard `eth_getLogs` will timeout on large ranges.

MegaETH's `eth_getLogsWithCursor` API solves this by:
- Returning partial results when server limits are hit
- Providing a cursor to resume from where the query stopped
- Eliminating wasted computation on aborted queries

This crate handles pagination automatically, making it easy to fetch arbitrarily large log ranges.

## Quick Start

```rust
use megaeth_rpc::MegaEthClient;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Create client
    let client = MegaEthClient::new("https://carrot.megaeth.com/rpc")?;

    // Check if cursor pagination is supported
    if client.supports_cursor_pagination().await {
        // Fetch logs with automatic pagination
        let (logs, stats) = client.get_logs_with_cursor(1000, 2000, None).await?;
        println!("Fetched {} logs in {} batches", stats.total_logs, stats.batches);
    }

    Ok(())
}
```

## Features

### Cursor-Based Log Pagination

Fetch large log ranges without timeout issues:

```rust
use megaeth_rpc::MegaEthClient;
use alloy::primitives::Address;

let client = MegaEthClient::new("https://carrot.megaeth.com/rpc")?;

// Fetch all logs in a range
let (logs, stats) = client.get_logs_with_cursor(0, 100_000, None).await?;

// Fetch logs for specific contracts
let contracts = vec![
    "0x1234...".parse::<Address>()?,
    "0x5678...".parse::<Address>()?,
];
let (logs, stats) = client.get_logs_with_cursor(0, 100_000, Some(contracts)).await?;

// Check completion status
if stats.complete {
    println!("Fetched all {} logs", stats.total_logs);
} else {
    println!("Fetch incomplete - hit batch limit");
}
```

### Realtime Transaction Submission

Get receipts immediately without polling:

```rust
use megaeth_rpc::MegaEthClient;
use alloy::primitives::Bytes;

let client = MegaEthClient::new("https://carrot.megaeth.com/rpc")?;

// Check if realtime API is available
if client.supports_realtime_api().await {
    // Submit transaction and get receipt immediately
    let receipt = client.send_realtime_transaction(signed_tx_bytes).await?;
    
    if receipt.is_success() {
        println!("Confirmed in block {}", receipt.block_number);
        println!("Gas used: {:?}", receipt.gas_used_u64());
    }
}
```

**How it works:**
```
Traditional flow:
  eth_sendRawTransaction → hash
  eth_getTransactionReceipt (poll) → null
  eth_getTransactionReceipt (poll) → null  
  eth_getTransactionReceipt (poll) → receipt
  
MegaETH Realtime:
  realtime_sendRawTransaction → receipt  (one call, ~10ms)
```

**Important**: The method times out after 10 seconds. If timeout occurs, fall back to
polling `eth_getTransactionReceipt`. The transaction may still succeed.

### Configuration

Customize client behavior:

```rust
use megaeth_rpc::{MegaEthClient, ClientConfig};
use std::time::Duration;

let config = ClientConfig::default()
    .with_timeout(Duration::from_secs(60))      // Longer timeout for large queries
    .with_max_cursor_batches(200)               // Allow more pagination batches
    .with_max_logs(500_000);                    // Memory protection: limit total logs

let client = MegaEthClient::with_config("https://carrot.megaeth.com/rpc", config)?;
```

### How Cursor Pagination Works

The cursor is an **opaque string** derived from `(blockNumber, logIndex)` of the last log
returned. You should treat it as opaque — don't parse or construct cursors manually.

```
Request 1: fromBlock=100, toBlock=1000, cursor=None
  → Server processes blocks 100-400, hits limit
  → Returns 5000 logs + cursor="0x0001900000000005"
  
Request 2: fromBlock=100, toBlock=1000, cursor="0x0001900000000005"  
  → Server resumes from block 400, log index 5
  → Returns 3000 logs + cursor=None (complete)
```

**Important**: Always pass the same filter parameters when continuing with a cursor.
The server uses the cursor to resume, but still validates against the original filter.

### Memory Considerations

When fetching logs with cursor pagination, **all logs are accumulated in memory** before being returned. For very large queries on high-throughput chains like MegaETH, this can consume significant memory.

**Protection options:**

1. **`max_logs`** - Limit total logs collected (recommended for production):
   ```rust
   let config = ClientConfig::default()
       .with_max_logs(100_000);  // Error if more than 100k logs
   ```

2. **`max_cursor_batches`** - Limit number of RPC calls:
   ```rust
   let config = ClientConfig::default()
       .with_max_cursor_batches(50);  // Error after 50 batches
   ```

3. **Narrow your query** - Use smaller block ranges or filter by contract address.

**Memory estimation:** Each log is approximately 200-500 bytes depending on topics and data size. 100,000 logs ≈ 20-50 MB.

### Error Handling

Errors are categorized for easy handling:

```rust
use megaeth_rpc::MegaEthClient;

let client = MegaEthClient::new("https://carrot.megaeth.com/rpc")?;

match client.get_logs_with_cursor(0, 1000, None).await {
    Ok((logs, stats)) => {
        println!("Success: {} logs", logs.len());
    }
    Err(e) if e.is_method_not_supported() => {
        // Fall back to standard eth_getLogs
        println!("Cursor pagination not supported, falling back...");
    }
    Err(e) if e.is_retryable() => {
        // Retry after backoff (network issues, server overload)
        println!("Transient error: {}, will retry", e);
    }
    Err(e) => {
        // Handle other errors
        eprintln!("Error: {}", e);
    }
}
```

## MegaETH-Specific APIs

| Method | Description | Standard Equivalent |
|--------|-------------|---------------------|
| `eth_getLogsWithCursor` | Paginated log queries | `eth_getLogs` |
| `realtime_sendRawTransaction` | Instant receipts (~10ms) | `eth_sendRawTransaction` + polling |

## API Reference

### `MegaEthClient`

The main client type. Create with `new()` or `with_config()`.

**Methods:**
- `supports_cursor_pagination()` - Check if cursor pagination is available
- `get_logs_with_cursor()` - Fetch logs with automatic pagination
- `get_contract_logs()` - Fetch logs for a single contract
- `supports_realtime_api()` - Check if realtime API is available
- `send_realtime_transaction()` - Submit tx and get receipt immediately

### `ClientConfig`

Configuration options:
- `timeout` - HTTP request timeout (default: 30s)
- `max_cursor_batches` - Max pagination batches (default: 100)
- `max_logs` - Max logs to collect, 0 for unlimited (default: 0)

### `FetchStats`

Statistics returned from pagination operations:
- `total_logs` - Total logs fetched
- `batches` - Number of requests made
- `complete` - Whether all logs were fetched

### `MegaEthError`

Error type with helpful methods:
- `is_method_not_supported()` - True for unsupported RPC methods
- `is_retryable()` - True for transient errors worth retrying

## Network Information

| Network | RPC URL | Chain ID |
|---------|---------|----------|
| Testnet | `https://carrot.megaeth.com/rpc` | 6343 |
| Mainnet | `https://mainnet.megaeth.com/rpc` | 4326 |

## Related Crates

| Crate | Relationship | Description |
|-------|--------------|-------------|
| [`evm-provider`](../evm-provider) | **Uses this** | Chain abstraction layer; wraps `MegaEthClient` in `MegaEthProvider` |
| [`fleet-core`](../fleet-core) | Upstream | Wallet management, plugins, safety; uses `evm-provider` |
| [`ghostnet-indexer`](../../ghostnet-indexer) | **Uses this** | Event indexer; uses cursor pagination directly |

## Versioning

This crate follows [SemVer](https://semver.org/). The public API includes:

- `MegaEthClient` and all its public methods
- `ClientConfig` and its builder methods
- `FetchStats`, `LogsWithCursorResponse`, `RealtimeResponse` types
- `MegaEthError` and its helper methods

Internal implementation details (private modules, internal types) may change without notice.

## License

MIT
