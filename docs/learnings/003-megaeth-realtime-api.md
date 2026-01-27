# MegaETH Realtime API for Event Indexing

**Date**: 2026-01-21  
**Category**: Architecture  
**Scope**: Backend Indexer

## Context

When building the GHOSTNET event indexer, we needed to decide between HTTP polling and WebSocket subscriptions for ingesting blockchain events. MegaETH has a unique architecture that changes the trade-offs significantly.

## The Problem

Standard Ethereum indexers poll for new blocks/logs at ~1 second intervals (EVM block time). This is fine for most applications, but GHOSTNET is a real-time survival game where events like scans, deaths, and extractions need to be reflected in the UI as fast as possible.

## MegaETH's Solution: Mini-Blocks

MegaETH introduces **mini-blocks** that are produced every ~10ms (vs 1s+ for EVM blocks). Their Realtime API exposes these immediately via WebSocket:

```json
{
    "method": "eth_subscribe",
    "params": ["logs", {
        "address": ["0x...", "0x..."],
        "fromBlock": "pending",
        "toBlock": "pending"
    }]
}
```

**Key insight**: The `fromBlock: "pending"` and `toBlock: "pending"` parameters tell MegaETH to stream logs from mini-blocks, not wait for EVM blocks.

## Our Implementation

We created two complementary processors:

| Component | Mode | Latency | Use Case |
|-----------|------|---------|----------|
| `BlockProcessor` | HTTP polling | ~1s | Historical backfill |
| `RealtimeProcessor` | WebSocket | ~10ms | Real-time streaming |

### WebSocket Keep-Alive

MegaETH requires client activity every 30 seconds. Our `RealtimeProcessor` sends `eth_chainId` every 25 seconds:

```rust
const KEEPALIVE_INTERVAL: Duration = Duration::from_secs(25);

// In the subscription loop
let mut keepalive_timer = interval(KEEPALIVE_INTERVAL);
loop {
    keepalive_timer.tick().await;
    provider.get_chain_id().await?;
}
```

### Timestamp Handling

Mini-block logs may not have an associated EVM block yet. We handle this gracefully:

```rust
let timestamp = match provider.get_block_by_number(block_number).await {
    Ok(Some(block)) => DateTime::from_timestamp(block.header.timestamp, 0),
    _ => Utc::now(), // Fall back to current time for mini-blocks
};
```

## Other MegaETH-Specific Features

For future use:

1. **`realtime_sendRawTransaction`**: Submit tx and get receipt in one call (no polling)
2. **`stateChanges` subscription**: Stream account state changes
3. **`miniBlocks` subscription**: Stream entire mini-blocks with transactions + receipts
4. **`eth_getLogsWithCursor`**: Paginated log queries for large datasets

## Key Takeaways

1. **Use WebSocket for production**: 100x lower latency than HTTP polling
2. **Use HTTP for backfill**: More efficient for historical data
3. **Handle mini-block timestamps**: May not have EVM block context yet
4. **Send keep-alive pings**: Required every 30 seconds
5. **Reconnection handling**: WebSocket connections can drop; auto-reconnect

## References

- [MegaETH Realtime API Docs](https://docs.megaeth.io/realtime-api)
- `services/ghostnet-indexer/src/indexer/realtime_processor.rs`
- `services/ghostnet-indexer/src/indexer/block_processor.rs`
