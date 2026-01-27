# MegaETH Integration Guide

## Quick Reference

| Network | Chain ID | RPC URL | Explorer |
|---------|----------|---------|----------|
| **Testnet** | 6343 | `https://carrot.megaeth.com/rpc` | [Blockscout](https://megaeth-testnet-v2.blockscout.com/) |
| **Mainnet (Frontier)** | 4326 | `https://mainnet.megaeth.com/rpc` | [Blockscout](https://megaeth.blockscout.com/) / [Etherscan](https://mega.etherscan.com) |

**Key facts:**
- EVM-compatible (deploy unchanged Solidity with Foundry/Hardhat)
- Dual block model: 10ms mini-blocks (preconfirmed) + 1s EVM blocks (finalized)
- Block gas limit: 10 billion | Base fee: ~0.001 gwei
- Contract size limit: 512KB (vs Ethereum's 24KB)
- Mainnet is whitelisted developers only; public mainnet expected early 2026

---

## Architecture Overview

### Dual Block Model

MegaETH produces two types of blocks:

```
┌─────────────────────────────────────────────────────────┐
│                    TIME FLOW -->                        │
├─────────────────────────────────────────────────────────┤
│ Mini Blocks:  [M1][M2][M3]...[M99][M100]  (10ms each)   │
│                        |                                │
│ EVM Block:    [=========== B1 ===========]  (1s total)  │
│                                                         │
│ - Mini blocks: instant preconfirmation, Realtime API    │
│ - EVM blocks:  standard EVM compatibility, finality     │
└─────────────────────────────────────────────────────────┘
```

**Transaction flow:**
```
User Tx --> Sequencer (10ms) --> Mini Block (preconfirmed)
                                        |
                                EVM Block (1s)
                                        |
                                L1 Anchor (Ethereum)
                                        |
                                Full Finality
```

### Key Implications

- Standard RPC queries see EVM blocks (1s resolution)
- Realtime API queries see mini blocks (10ms resolution)
- `block.timestamp` returns EVM block time, NOT mini block time
- Transaction receipts may have `blockHash: null` but valid `blockNumber` (in mini block, not yet in EVM block)

---

## Development Setup

### Network Configuration

**Foundry (foundry.toml):**
```toml
[profile.default]
solc_version = "0.8.24"

[rpc_endpoints]
megaeth = "https://mainnet.megaeth.com/rpc"
megaeth_testnet = "https://carrot.megaeth.com/rpc"

[etherscan]
megaeth_testnet = { key = "", url = "https://megaeth-testnet-v2.blockscout.com/api/" }
```

**Hardhat (hardhat.config.js):**
```javascript
module.exports = {
  solidity: "0.8.24",
  networks: {
    megaethTestnet: {
      url: "https://carrot.megaeth.com/rpc",
      chainId: 6343,
      accounts: [process.env.PRIVATE_KEY],
      gas: 10000000,
    },
    megaeth: {
      url: "https://mainnet.megaeth.com/rpc",
      chainId: 4326,
      accounts: [process.env.PRIVATE_KEY],
      gas: 10000000,
    }
  }
};
```

**MetaMask / Wallet:**
```
Network Name: MegaETH Testnet
RPC URL: https://carrot.megaeth.com/rpc
Chain ID: 6343
Currency Symbol: ETH
Block Explorer: https://megaeth-testnet-v2.blockscout.com/
```

**viem/wagmi:**
```typescript
import { defineChain } from 'viem';

export const megaethTestnet = defineChain({
  id: 6343,
  name: 'MegaETH Testnet',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: ['https://carrot.megaeth.com/rpc'] },
  },
  blockExplorers: {
    default: { name: 'Blockscout', url: 'https://megaeth-testnet-v2.blockscout.com' },
  },
});
```

### Get Testnet ETH

```bash
# Official faucet (0.005 ETH/24h, IP-limited)
# https://testnet.megaeth.com (click FAUCET)

# Chainlink faucet
# https://faucets.chain.link/megaeth-testnet

# thirdweb (0.01 ETH/day)
# https://thirdweb.com/megaeth-testnet

# gas.zip (0.0025 ETH/day)
# https://www.gas.zip/faucet/megaeth
```

### Key Contract Addresses

| Contract | Mainnet (Frontier) | Testnet |
|----------|-------------------|---------|
| WETH | `0x4200000000000000000000000000000000000006` | `0x4eB2Bd7beE16F38B1F4a0A5796Fffd028b6040e9` |
| MEGA Token | `0x28B7E77f82B25B95953825F1E3eA0E36c1c29861` | -- |
| Multicall3 | `0xcA11bde05977b3631167028862bE2a173976CA11` | `0xcA11bde05977b3631167028862bE2a173976CA11` |

---

## Realtime API

MegaETH's extension to Ethereum JSON-RPC optimized for sub-10ms latency. Queries against mini-blocks instead of EVM blocks.

### State Queries (with `pending` or `latest` tag)

These methods return results up to the most recent mini-block:

| Method | Description |
|--------|-------------|
| `eth_getBalance` | Account balance |
| `eth_getStorageAt` | Storage slot value |
| `eth_getTransactionCount` | Account nonce |
| `eth_getCode` | Contract bytecode |
| `eth_call` | Simulate call |
| `eth_estimateGas` | Estimate gas |

### Transaction Queries

These see transactions as soon as they're in a mini-block (no special params needed):

| Method | Description |
|--------|-------------|
| `eth_getTransactionByHash` | Get transaction details |
| `eth_getTransactionReceipt` | Get receipt (~10ms after submission) |

### realtime_sendRawTransaction

**The killer feature.** Send transaction and get receipt in ONE call (no polling):

```javascript
// Traditional: send tx --> poll receipt --> multiple round trips
// MegaETH: single call, receipt returned directly

const receipt = await fetch(RPC_URL, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    jsonrpc: '2.0',
    method: 'realtime_sendRawTransaction',
    params: [signedTx],
    id: 1
  })
}).then(r => r.json());

// Receipt returned directly -- no polling!
// Times out after 10s with "realtime transaction expired" error
// Fall back to eth_getTransactionReceipt if timeout
```

**Response on success:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "blockHash": "0x0000...",
    "blockNumber": "0x10",
    "status": "0x1",
    "transactionHash": "0xf98a...",
    ...
  }
}
```

**Response on timeout:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32000,
    "message": "realtime transaction expired"
  }
}
```

### WebSocket Subscriptions

Stream data as mini-blocks are produced. Keep connection alive by sending `eth_chainId` every 30 seconds.

**Subscribe to logs (real-time):**
```json
{
  "jsonrpc": "2.0",
  "method": "eth_subscribe",
  "params": [
    "logs",
    {
      "address": "0xYourContract",
      "topics": ["0xEventSignature..."],
      "fromBlock": "pending",
      "toBlock": "pending"
    }
  ],
  "id": 1
}
```

**Subscribe to state changes:**
```json
{
  "jsonrpc": "2.0",
  "method": "eth_subscribe",
  "params": [
    "stateChanges",
    ["0xAddressToMonitor"]
  ],
  "id": 1
}
```

Response schema:
```json
{
  "address": "0x...",
  "nonce": 1,
  "balance": "0x16345785d8a0000",
  "storage": {
    "0xslot1": "0xvalue1",
    "0xslot2": "0xvalue2"
  }
}
```

**Subscribe to mini-blocks:**
```json
{
  "jsonrpc": "2.0",
  "method": "eth_subscribe",
  "params": ["miniBlocks"],
  "id": 1
}
```

Response includes `block_number`, `mini_block_number`, `mini_block_timestamp` (Unix microseconds), `transactions`, and `receipts`.

### Paginated Log Queries

For large log datasets, use cursor-based pagination:

```javascript
async function getAllLogs(filter) {
  let logs = [];
  let cursor = null;
  
  do {
    const result = await provider.send('eth_getLogsWithCursor', [{
      ...filter,
      cursor
    }]);
    logs = logs.concat(result.logs);
    cursor = result.cursor; // null when complete
  } while (cursor);
  
  return logs;
}
```

---

## Critical Gotchas

### 1. Gas Estimation Failures (MOST COMMON)

MegaEVM has different gas costs than vanilla EVM. Local simulation will fail.

```bash
# WRONG - Will fail with "intrinsic gas too low"
forge script Deploy.s.sol --rpc-url $MEGAETH_RPC --broadcast

# CORRECT - Skip local simulation, hardcode gas limit
forge script Deploy.s.sol --rpc-url $MEGAETH_RPC --broadcast \
  --skip-simulation --gas-limit 10000000 --legacy

# For forge create
forge create src/Contract.sol:Contract \
  --rpc-url megaeth_testnet \
  --private-key $PRIVATE_KEY \
  --gas-limit 10000000 \
  --skip-simulation
```

**High gas limits do NOT mean high costs.** MegaETH is extremely cheap:
- Base fee: ~0.001 gwei (30,000x cheaper than Ethereum)
- Simple transfer: ~$0.0001
- Complex deployment: ~$0.01
- You only pay for gas actually used; unused gas is refunded

### 2. block.prevrandao Behavior

`block.prevrandao` stays **constant for ~60 seconds** across 50+ blocks on MegaETH (tied to epoch boundaries, not individual blocks).

**Impact:** If using for randomness, players could predict outcomes.

**Mitigation:** Use lock periods, multi-component seeds, or external VRF.

See: [learnings/001-prevrandao-megaeth.md](../learnings/001-prevrandao-megaeth.md)

### 3. block.timestamp Resolution

```solidity
// Has 1-second resolution, NOT 10ms
uint256 timestamp = block.timestamp;

// For sub-second timing, use:
// - Chainlink Data Streams (native precompile)
// - Off-chain timestamps with signatures
// - Accept 1s granularity
```

### 4. null blockHash is Normal

```javascript
const receipt = await provider.getTransactionReceipt(txHash);

if (receipt.blockHash === null && receipt.blockNumber !== null) {
  // Transaction is in a mini block, preconfirmed
  // Same guarantee as having a blockHash -- sequencer committed
  // Just not yet in an EVM block
}
```

### 5. Nonce Management

```javascript
// WRONG: Re-fetching nonce can skip pending transactions
const nonce = await provider.getTransactionCount(address, 'latest');

// RIGHT: Use pending state
const nonce = await provider.getTransactionCount(address, 'pending');

// BEST: Track nonce in-memory, don't re-fetch
let localNonce = await provider.getTransactionCount(address, 'pending');
// Increment after each tx, don't re-fetch
```

### 6. Txpool Limit

500 pending transactions per account maximum. If you hit "txpool is full":
1. Check for nonce gaps
2. Replace stuck transactions with higher gas
3. Wait for execution before sending more

### 7. eth_call Gas Limit

- RPC simulation: 10 million gas max
- On-chain execution: 10 billion gas max

If simulation fails but you expect it to work on-chain, this might be why.

### 8. WebSocket Rate Limits

Currently only `eth_chainId` is guaranteed (rate-limited 5 req/s). Other WebSocket methods may be unavailable. Check docs for current status.

### 9. Foundry 403 Errors

"Enable JavaScript and cookies to continue" = Cloudflare protection. Try different IP, VPN, or wait and retry.

### 10. Alloy.rs TLS Failures

```rust
// Must use rustls explicitly
// Cargo.toml: reqwest = { version = "...", features = ["rustls-tls"] }

let client = reqwest::Client::builder()
    .use_rustls_tls()
    .build()
    .unwrap();

// Also in main.rs:
let _ = rustls::crypto::ring::default_provider().install_default();
```

### 11. Chain ID Confusion

Original testnet was 6342, current testnet V2 is **6343**. ChainList may show outdated info.

---

## Deployment Guide

### Foundry Deployment

```bash
# Basic deployment
forge create src/MyContract.sol:MyContract \
  --rpc-url megaeth_testnet \
  --private-key $PRIVATE_KEY \
  --gas-limit 10000000 \
  --skip-simulation

# With verification
forge create src/MyContract.sol:MyContract \
  --rpc-url megaeth_testnet \
  --private-key $PRIVATE_KEY \
  --gas-limit 10000000 \
  --skip-simulation \
  --verify \
  --verifier blockscout \
  --verifier-url https://megaeth-testnet-v2.blockscout.com/api/
```

### Foundry Scripts

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url megaeth_testnet \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --gas-limit 10000000 \
  --skip-simulation \
  --legacy
```

### Contract Verification

If Blockscout verification is flaky:
1. Wait a few minutes, retry
2. Use `forge verify-contract` separately after deployment
3. Verify manually through Blockscout UI

### Local Debugging with mega-evme

MegaETH provides `mega-evme` for accurate local transaction simulation using actual MegaEVM:

```bash
git clone https://github.com/megaeth-labs/mega-evm
cd mega-evm
cargo build --release
./target/release/mega-evme --help
```

---

## Canonical Bridge (OP Stack)

MegaETH uses OP Stack's Standard Bridge (v3.0.0) for Ethereum mainnet bridging.

### Bridge ETH to MegaETH

```bash
# Simple: direct ETH transfer to bridge contract
cast send 0x0CA3A2FBC3D770b578223FBB6b062fa875a2eE75 \
  --value 0.1ether \
  --rpc-url https://eth.llamarpc.com

# With gas control
cast send 0x0CA3A2FBC3D770b578223FBB6b062fa875a2eE75 \
  'depositETH(uint32, bytes)' 61000 "0x" \
  --value 0.1ether \
  --rpc-url https://eth.llamarpc.com
```

### L1 Bridge Contracts (Ethereum Mainnet)

| Contract | Address |
|----------|---------|
| L1StandardBridgeProxy | `0x0CA3A2FBC3D770b578223FBB6b062fa875a2eE75` |
| OptimismPortalProxy | `0x7f82f57F0Dd546519324392e408b01fcC7D709e8` |
| L1CrossDomainMessengerProxy | `0x6C7198250087B29A8040eC63903Bc130f4831Cc9` |

### Third-Party Bridges

| Bridge | Type | URL |
|--------|------|-----|
| Orbiter Finance | Cross-rollup | https://test.orbiter.finance |
| Hyperlane | Permissionless interop | https://docs.hyperlane.xyz |
| Rubic | Multi-chain aggregator | https://testnet.rubic.exchange |
| Gasyard | ETH Sepolia bridge | (for testnet) |

**WARNING:** Frontier is for developers only. Bridging tokens as a regular user is extremely risky.

---

## Ecosystem Infrastructure

### Oracles

**Chainlink Data Streams** (Native precompile)
- Sub-millisecond latency via precompile
- "Just-in-time" price pulls
- Zero integration overhead
- Docs: https://docs.chain.link/data-streams

**RedStone Bolt** (Push oracle)
- 2.4ms update latency (416 updates/second)
- Plug-and-play with Aave, Compound, Morpho
- Docs: https://docs.redstone.finance

### VRF

**Gelato VRF** - Officially supported on testnet
- Uses Drand (League of Entropy) as randomness beacon
- ~1500ms delivery latency
- Docs: https://docs.gelato.network/web3-services/vrf
- See: [integrations/gelato-vrf.md](./gelato-vrf.md)

### Cross-Chain

**Chainlink CCIP** - Integrated April 2025
- Secure cross-chain token transfers and messaging
- Docs: https://docs.chain.link/ccip

### Account Abstraction

MegaETH supports EIP-7702 natively.

| Provider | Docs |
|----------|------|
| Pimlico | https://docs.pimlico.io |
| ZeroDev | https://docs.zerodev.app |
| Privy | https://docs.privy.io |

### DEXs

| Protocol | Description | URL |
|----------|-------------|-----|
| Bronto Finance | Native concentrated liquidity DEX, ve(3,3) | https://bronto.finance |
| GTE | High-performance CLOB DEX + Perps | https://gte.xyz |
| Bebop | Multi-chain DEX aggregator | https://bebop.xyz |

### Lending

| Protocol | Description | URL |
|----------|-------------|-----|
| Teko Finance | Real-time lending, micro-liquidations | https://testnet.teko.finance |
| Cap | Stablecoin engine (cUSD, bcUSD) | https://cap.app/testnet |

---

## EIP Support Reference

| EIP | Status | Notes |
|-----|--------|-------|
| EIP-55 | Not enforced | Addresses may appear lowercase |
| EIP-170 | Modified | 512KB limit instead of 24KB |
| EIP-1559 | Supported | Base fee ~0.001 gwei |
| EIP-7702 | Supported | Account abstraction |
| Cancun (TSTORE) | Supported | Transient storage works |

---

## Production Checklist

### Pre-Launch
- [ ] Test on actual testnet (local fork won't capture timing/gas differences)
- [ ] Handle null blockHash in all receipt processing
- [ ] Implement nonce management (don't rely on re-fetching after reconnects)
- [ ] Add retry logic for 502 errors (DNS resolution issues)
- [ ] Test race conditions (10ms windows = more opportunities)
- [ ] Verify gas estimation (use `--skip-simulation` or RPC estimation)

### Smart Contract
- [ ] Don't rely on block.timestamp for sub-second timing
- [ ] Handle L1 reorg edge case for high-value operations
- [ ] Test with realistic gas usage (block limit is 10B gas)
- [ ] Use TSTORE if needed (Cancun supported)
- [ ] Verify on Blockscout

### Infrastructure
- [ ] Use Realtime API for latency-sensitive operations
- [ ] Implement eth_getLogsWithCursor for large log queries
- [ ] Handle rate limits (dynamic behavior)
- [ ] Restart long-running processes if you get 502s (stale DNS)

### Monitoring
- [ ] Track mini block height at uptime.megaeth.com
- [ ] Monitor sequencer health
- [ ] Watch for chain announcements (testnet may roll back during maintenance)

---

## Anti-Patterns

### Don't treat MegaETH like a slow chain
```javascript
// WRONG: Adding artificial delays
await sleep(12000);

// RIGHT: Use instant confirmation
const receipt = await realtimeSendTx(signedTx);
```

### Don't poll for state changes
```javascript
// WRONG: Wasteful polling
setInterval(async () => {
  const balance = await provider.getBalance(address);
}, 1000);

// RIGHT: Use Realtime API subscriptions or batch queries
```

### Don't assume ms precision on block.timestamp
```solidity
// WRONG: 100ms intended but has 1s resolution
require(block.timestamp > lastAction + 100, "Too fast");

// RIGHT: Accept 1-second minimum
require(block.timestamp > lastAction + 1, "Too fast");
```

### Don't use local gas estimation
```bash
# WRONG
forge script Deploy.s.sol --broadcast

# RIGHT
forge script Deploy.s.sol --broadcast --gas-limit 10000000 --skip-simulation
```

---

## Resources

### Official
- Docs: https://docs.megaeth.com
- Testnet Portal: https://testnet.megaeth.com
- Performance Dashboard: https://uptime.megaeth.com
- MegaEVM Source: https://github.com/megaeth-labs/mega-evm
- mega-evme Debugger: https://github.com/megaeth-labs/mega-evm/blob/main/bin/mega-evme/README.md

### RPC Endpoints
| Network | Provider | URL |
|---------|----------|-----|
| Mainnet | MegaETH | https://mainnet.megaeth.com/rpc |
| Testnet | MegaETH | https://carrot.megaeth.com/rpc |
| Testnet | Thirdweb | https://6343.rpc.thirdweb.com |
| Testnet | Alchemy | https://www.alchemy.com/rpc/megaeth-testnet |

### Block Explorers
| Network | Explorer | URL |
|---------|----------|-----|
| Mainnet | Blockscout | https://megaeth.blockscout.com/ |
| Mainnet | Etherscan | https://mega.etherscan.com |
| Testnet | Blockscout | https://megaeth-testnet-v2.blockscout.com/ |

### Infrastructure Docs
- Chainlink Data Streams: https://docs.chain.link/data-streams
- Chainlink CCIP: https://docs.chain.link/ccip
- RedStone Bolt: https://docs.redstone.finance
- Gelato VRF: https://docs.gelato.network/web3-services/vrf
- Pimlico (AA): https://docs.pimlico.io
- ZeroDev (AA): https://docs.zerodev.app

### Community
- Contract Verification: https://github.com/princesinha19/megaeth-abis
- MegaExplorer: https://www.megaexplorer.xyz
- Ecosystem Hub: https://layerhub.xyz/chains/megaeth_testnet/ecosystem

---

## See Also

- [learnings/001-prevrandao-megaeth.md](../learnings/001-prevrandao-megaeth.md) - Detailed prevrandao behavior analysis
- [integrations/gelato-vrf.md](./gelato-vrf.md) - Gelato VRF integration guide

---

*Last updated: January 2026. Always verify against official docs -- MegaETH is actively developing and parameters change.*
