# megaeth-rpc

MegaETH-specific JSON-RPC client with cursor pagination and realtime API support.

## Overview

This crate provides `MegaEthClient`, a specialized RPC client for MegaETH's extended JSON-RPC API. It handles the unique characteristics of MegaETH:

- **High throughput**: MegaETH processes ~1000 TPS, generating massive data volumes
- **Cursor pagination**: `eth_getLogsWithCursor` for efficient large-range queries
- **Realtime API**: `realtime_sendRawTransaction` for instant receipts (~10ms)

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

## License

MIT
