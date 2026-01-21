# MegaETH RPC Endpoints - Comprehensive Analysis

**Date**: January 21, 2026  
**Status**: Verified through live testing

## Executive Summary

Through extensive testing, we've mapped the actual capabilities of MegaETH RPC endpoints. **The documentation doesn't match reality** - particularly for testnet WebSocket subscriptions which are effectively broken on public endpoints.

**Key Finding**: Use **MAINNET** (`mainnet.megaeth.com`) for WebSocket subscriptions. Testnet public WebSocket accepts connections but doesn't stream data.

---

## Endpoint Summary Table

| Endpoint | Chain | HTTP | WebSocket | miniBlocks | stateChanges | Rate Limit |
|----------|-------|------|-----------|------------|--------------|------------|
| `mainnet.megaeth.com/rpc` | Mainnet (4326) | **YES** | **YES** | **YES** | **YES** | Unknown |
| `staging-mainnet.rpc.megaeth.com/rpc` | Mainnet (4326) | **YES** | **YES** | **YES** | Untested | Unknown |
| `carrot.megaeth.com/rpc` | Testnet (6343) | YES* | Partial | **NO** | **NO** | Aggressive |
| `timothy.megaeth.com/rpc` | Testnet (6343) | YES* | Partial | **NO** (502) | **NO** | Aggressive |
| `staging-testnet.rpc.megaeth.com/rpc` | Testnet (6343) | YES* | Partial | **NO** (502) | **NO** | Aggressive |
| Alchemy (megaeth-testnet) | Testnet (6343) | **YES** | **NO** | N/A | N/A | Generous |
| Tatum (megaeth-timothy) | Testnet (6343) | **YES** | **NO** | N/A | N/A | 3 req/s free |

*YES* = Works but frequently returns 502/504 errors under load

---

## Detailed Findings

### 1. MegaETH MAINNET (`mainnet.megaeth.com`)

**Chain ID**: 4326 (0x10e6)

This is the **only endpoint with fully working WebSocket subscriptions**.

```bash
# HTTP RPC
curl -X POST https://mainnet.megaeth.com/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
# Returns: {"jsonrpc":"2.0","result":"0x10e6","id":1}

# WebSocket - miniBlocks subscription WORKS!
wscat -c wss://mainnet.megaeth.com/ws
> {"jsonrpc":"2.0","method":"eth_subscribe","params":["miniBlocks"],"id":1}
# Returns subscription ID, then streams mini blocks every ~10ms
```

**Verified Working Features**:
- `eth_subscribe` with `miniBlocks` - streams every ~10ms with transactions AND receipts
- `eth_subscribe` with `stateChanges` - streams account balance/nonce/storage changes
- `eth_subscribe` with `newHeads` - streams block headers
- `eth_subscribe` with `logs` - streams transaction logs
- Standard HTTP RPC methods

**Mini Block Data Structure** (actual API response, differs from docs):
```json
{
  "block_number": 6220303,       // EVM block number
  "block_timestamp": 1769017314, // EVM block timestamp (Unix seconds)
  "index": 5,                    // Index within EVM block
  "number": 582850614,           // Mini block number (docs call this mini_block_number)
  "timestamp": 1769017313054,    // Mini block timestamp in microseconds (docs call this mini_block_timestamp)
  "gas_used": 656348,
  "transactions": [...],         // Full transaction objects
  "receipts": [...],             // Full receipt objects
  "buckets_to_canonicalize": []
}
```

**Important**: The API returns `number` and `timestamp`, NOT `mini_block_number` and `mini_block_timestamp` as documented!

---

### 2. MegaETH TESTNET (`carrot.megaeth.com`, `timothy.megaeth.com`)

**Chain ID**: 6343 (0x18c7)

**Critical Issue**: WebSocket subscriptions are **BROKEN** on testnet public endpoints.

```bash
# HTTP works (sometimes)
curl -X POST https://carrot.megaeth.com/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
# Returns: {"jsonrpc":"2.0","result":"0x18c7","id":1}

# WebSocket connects and accepts subscriptions...
wscat -c wss://carrot.megaeth.com/ws
> {"jsonrpc":"2.0","method":"eth_subscribe","params":["miniBlocks"],"id":1}
# Returns subscription ID: {"jsonrpc":"2.0","result":"0xabc123...","id":1}
# BUT THEN: silence. No mini blocks are ever sent.
```

**Behavior**:
- WebSocket connects successfully
- `eth_chainId` works over WebSocket
- `eth_subscribe` returns a subscription ID (appears to succeed)
- **NO DATA IS EVER STREAMED** after subscription confirmation

**HTTP Issues**:
- Frequent 502 Bad Gateway errors
- Frequent 504 Gateway Timeout errors
- Aggressive rate limiting (429 errors)
- `eth_getLogsWithCursor` sometimes returns 502

**Workaround**: Use Alchemy or Tatum for testnet HTTP RPC.

---

### 3. Third-Party Providers

#### Alchemy (`megaeth-testnet.g.alchemy.com`)

```bash
# HTTP works great
curl -X POST "https://megaeth-testnet.g.alchemy.com/v2/YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# WebSocket DOES NOT support eth_subscribe
wscat -c "wss://megaeth-testnet.g.alchemy.com/v2/YOUR_KEY"
> {"jsonrpc":"2.0","method":"eth_subscribe","params":["newHeads"],"id":1}
# Returns: {"jsonrpc":"2.0","error":{"code":-32601,"message":"Method 'eth_subscribe' not found"},"id":1}
```

**Supported**: HTTP RPC only  
**Not Supported**: `eth_subscribe`, `miniBlocks`, `stateChanges`, `eth_getLogsWithCursor`

#### Tatum (`megaeth-timothy.gateway.tatum.io`)

```bash
# HTTP works
curl -X POST "https://megaeth-timothy.gateway.tatum.io/" \
  -H "Content-Type: application/json" \
  -H "x-api-key: YOUR_TATUM_KEY" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# WebSocket not supported (405 Method Not Allowed)
```

**Supported**: HTTP RPC only  
**Not Supported**: WebSocket  
**Rate Limit**: 3 requests/second on free tier

---

## Recommended Configuration

### For Development (Testnet)

```javascript
// Use Alchemy for reliable HTTP
const HTTP_RPC = "https://megaeth-testnet.g.alchemy.com/v2/YOUR_KEY";

// For real-time features, use mainnet for testing WebSocket code
// then switch to testnet HTTP polling for actual testnet deployment
const WS_RPC = "wss://mainnet.megaeth.com/ws"; // For WS feature development
```

### For Production (Mainnet)

```javascript
const HTTP_RPC = "https://mainnet.megaeth.com/rpc";
const WS_RPC = "wss://mainnet.megaeth.com/ws";

// All Realtime API features work on mainnet:
// - miniBlocks subscription
// - stateChanges subscription  
// - logs subscription with pending blocks
// - eth_getLogsWithCursor
```

### Fallback Chain for HTTP

```javascript
const HTTP_FALLBACKS = [
  "https://megaeth-testnet.g.alchemy.com/v2/YOUR_KEY",  // Most reliable
  "https://carrot.megaeth.com/rpc",                     // Official, but unstable
  "https://timothy.megaeth.com/rpc",                    // Official fallback
  "https://6343.rpc.thirdweb.com",                      // Third-party
];
```

---

## API Discrepancies from Documentation

### 1. Mini Block Field Names

**Documentation says**:
```json
{
  "mini_block_number": "0x...",
  "mini_block_timestamp": "0x..."
}
```

**Actual API returns**:
```json
{
  "number": 123456789,
  "timestamp": 1769017313054
}
```

### 2. Data Types

**Documentation implies**: Hex strings for all numeric values  
**Actual API returns**: Native integers

### 3. WebSocket Subscription Availability

**Documentation claims**: All endpoints support `eth_subscribe`  
**Reality**: Only mainnet actually streams data

---

## Test Results Summary

| Test | Status | Notes |
|------|--------|-------|
| HTTP Connectivity (testnet) | Flaky | 502/504 errors common |
| HTTP Connectivity (mainnet) | PASS | Reliable |
| WebSocket Connectivity (mainnet) | PASS | All subscriptions work |
| miniBlocks Subscription (mainnet) | PASS | ~10ms intervals |
| miniBlocks Subscription (testnet) | FAIL | Confirms sub but no data |
| stateChanges Subscription (mainnet) | PASS | Real-time updates |
| stateChanges Subscription (testnet) | FAIL | Confirms sub but no data |
| eth_getLogsWithCursor | Flaky | Rate limited, 502 errors |

---

## Implications for GHOSTNET

1. **Development Phase**: Use Alchemy HTTP for testnet contract interaction
2. **Real-time Features**: Develop against mainnet WebSocket, then implement HTTP polling fallback for testnet
3. **Production**: Full Realtime API available on mainnet
4. **Indexer Strategy**: 
   - Mainnet: Use WebSocket subscriptions for instant updates
   - Testnet: Fall back to HTTP polling every few seconds

---

## Monitoring Recommendations

1. Implement health checks that test actual subscription data flow, not just connection
2. Have automatic fallback from WebSocket to HTTP polling
3. Monitor for 502/504 errors and implement exponential backoff
4. Consider Alchemy/Tatum for testnet to avoid rate limiting issues

---

## References

- MegaETH Realtime API Docs: https://docs.megaeth.com/realtime-api
- Tested: January 21, 2026
- Test code: `services/ghostnet-indexer/tests/live_network_test.rs`
