# MegaETH Developer Guide

## TL;DR

- **MegaETH is EVM-compatible** — your Solidity contracts deploy unchanged with Hardhat/Foundry. Target Prague EVM or earlier.
- **Dual network stage**: Mainnet (Frontier) is live for whitelisted developers (Chain ID 4326), public testnet available (Chain ID 6343). Full public mainnet expected early 2026.
- **Dual block model**: Mini blocks (10ms, preconfirmed) + EVM blocks (1s, finalized). `block.timestamp` returns EVM block time, not mini block time.
- **Use the Realtime API** for low-latency apps — `realtime_sendRawTransaction` returns receipts instantly instead of polling.
- **MegaEVM gas differences** — local toolchain gas estimation may fail. Use `--skip-simulation` with Foundry or let MegaETH RPC estimate gas.

---

## Stack Decisions

| Decision | Choice | Notes |
|----------|--------|-------|
| **Solidity version** | Any targeting Prague EVM or earlier | All modern versions work |
| **Framework** | Hardhat or Foundry | Both work with caveats (see gotchas) |
| **Client library** | ethers.js, viem, web3.js | Standard EVM tooling |
| **Wallet integration** | MetaMask (native support), Rabby, OKX | Day-one MetaMask partnership |
| **Oracle** | Chainlink Data Streams | Native precompile for ultra-low latency |
| **Oracle (push)** | RedStone Bolt | 2.4ms push oracle, plug-and-play |
| **Cross-chain** | Chainlink CCIP | Native integration (April 2025) |
| **VRF** | Gelato VRF | Officially supported on testnet |
| **Indexer** | Envio (supported), custom with Realtime API | WebSocket subscriptions for real-time updates |

---

## Project Setup

### Network Configuration

```javascript
// networks.js - Both networks

// MAINNET (Frontier) - Live for whitelisted developers
const megaethMainnet = {
  chainId: 4326,
  rpcUrl: "https://mainnet.megaeth.com/rpc",
  blockExplorer: "https://megaeth.blockscout.com/",
  nativeCurrency: {
    name: "Ether",
    symbol: "ETH",
    decimals: 18
  }
};

// TESTNET - Public, permissionless
const megaethTestnet = {
  chainId: 6343,
  rpcUrl: "https://carrot.megaeth.com/rpc",
  blockExplorer: "https://megaeth-testnet-v2.blockscout.com/",
  nativeCurrency: {
    name: "Ether",
    symbol: "ETH",
    decimals: 18
  }
};
```

### Hardhat Configuration

```javascript
// hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.24",
  networks: {
    megaeth: {
      url: "https://mainnet.megaeth.com/rpc",
      chainId: 4326,
      accounts: [process.env.PRIVATE_KEY],
      gas: 10000000, // Higher than typical - MegaEVM gas differs
    },
    megaethTestnet: {
      url: "https://timothy.megaeth.com/rpc",
      chainId: 6343,
      accounts: [process.env.PRIVATE_KEY],
      gas: 10000000,
    }
  }
};
```

### Foundry Configuration

```toml
# foundry.toml
[profile.default]
solc_version = "0.8.24"

[rpc_endpoints]
megaeth = "https://mainnet.megaeth.com/rpc"
megaeth_testnet = "https://carrot.megaeth.com/rpc"
```

```bash
# Deploy with Foundry - IMPORTANT: skip local simulation
forge create --rpc-url megaeth_testnet \
  --private-key $PRIVATE_KEY \
  --gas-limit 10000000 \
  src/MyContract.sol:MyContract

# For scripts, always use --skip-simulation
forge script Deploy.s.sol --rpc-url megaeth_testnet \
  --broadcast --gas-limit 10000000 --skip-simulation
```

### Get Testnet ETH

```bash
# Option 1: Official faucet (0.005 ETH/24h, IP-limited)
# Visit: https://testnet.megaeth.com (click FAUCET)

# Option 2: Chainlink faucet
# Visit: https://faucets.chain.link/megaeth-testnet

# Option 3: Contact team for larger amounts (protocol testing)
```

### Key Contract Addresses

| Contract | Mainnet (Frontier) | Testnet |
|----------|-------------------|---------|
| WETH | `0x4200000000000000000000000000000000000006` | `0x4eB2Bd7beE16F38B1F4a0A5796Fffd028b6040e9` |
| MEGA Token | `0x28B7E77f82B25B95953825F1E3eA0E36c1c29861` | — |
| Multicall3 | `0xcA11bde05977b3631167028862bE2a173976CA11` | `0xcA11bde05977b3631167028862bE2a173976CA11` |

**Note**: Mainnet uses OP Stack predeploy addresses. Testnet uses custom deployments.

---

## Architecture Patterns

### Understanding the Dual Block Model

MegaETH produces two types of blocks:

```
┌─────────────────────────────────────────────────────────┐
│                    TIME FLOW →                          │
├─────────────────────────────────────────────────────────┤
│ Mini Blocks:  [M1][M2][M3]...[M99][M100]  (10ms each)   │
│                        ↓                                │
│ EVM Block:    [═══════════ B1 ═══════════]  (1s total)  │
│                                                         │
│ • Mini blocks: instant preconfirmation, Realtime API    │
│ • EVM blocks:  standard EVM compatibility, finality     │
└─────────────────────────────────────────────────────────┘
```

**Key implication**: Standard RPC sees EVM blocks (1s). Realtime API sees mini blocks (10ms).

### Transaction Flow Architecture

```
User Tx → Sequencer (10ms) → Mini Block (preconfirmed)
                                    ↓
                            EVM Block (1s)
                                    ↓
                            L1 Anchor (Ethereum)
                                    ↓
                            Full Finality
```

### Pattern: Real-Time Transaction Confirmation

```javascript
// OLD WAY: Poll for receipt (adds latency)
const txHash = await wallet.sendTransaction(tx);
const receipt = await provider.waitForTransaction(txHash);

// MEGAETH WAY: Single round-trip with Realtime API
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

// Receipt returned directly — no polling
// Times out after 10s, then fall back to eth_getTransactionReceipt
```

### Pattern: Paginated Log Queries

```javascript
// Large log queries with cursor-based pagination
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

## Canonical Bridge (OP Stack)

MegaETH uses OP Stack's Standard Bridge (v3.0.0) for bridging from Ethereum mainnet.

### Bridge ETH to MegaETH

```bash
# Simplest: direct ETH transfer to bridge contract
cast send 0x0CA3A2FBC3D770b578223FBB6b062fa875a2eE75 \
  --value 0.1ether \
  --rpc-url https://eth.llamarpc.com

# With gas control (specify L2 gas limit)
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
| L1ERC721BridgeProxy | `0x3D8ee269F87A7f3F0590c5C0d825FFF06212A242` |
| OptimismMintableERC20FactoryProxy | `0xF875030B9464001fC0f964E47546b0AFEEbD7C61` |
| SystemConfigProxy | `0x1ED92E1bc9A2735216540EDdD0191144681cb77E` |

See [OP Stack docs](https://docs.optimism.io/op-stack/protocol/smart-contracts) for contract interfaces.

**⚠️ WARNING**: Frontier is for developers only. Bridging tokens to Frontier as a regular user is extremely risky and not recommended.

---

## Critical Gotchas

### 1. MegaEVM Gas Estimation Mismatch

MegaETH uses MegaEVM which has different gas costs than vanilla EVM. Toolchains using local EVM simulation will incorrectly estimate gas.

```bash
# ❌ This may fail with "intrinsic gas too low"
forge script Deploy.s.sol --rpc-url $MEGAETH_RPC --broadcast

# ✅ Skip local simulation, use hardcoded gas limit
forge script Deploy.s.sol --rpc-url $MEGAETH_RPC --broadcast \
  --gas-limit 10000000 --skip-simulation

# ✅ Or let MegaETH RPC estimate (remove local gas override in config)
```

**Best practice**: Use MegaETH's RPC for gas estimation, or use `mega-evme` for local debugging.

- **MegaEVM Source**: https://github.com/megaeth-labs/mega-evm
- **mega-evme Debugger**: https://github.com/megaeth-labs/mega-evm/blob/main/bin/mega-evme/README.md

#### High Gas Limits ≠ High Costs

**Important:** The high gas limits do NOT mean expensive transactions. MegaETH is extremely cheap:

| Metric | MegaETH | Ethereum | Comparison |
|--------|---------|----------|------------|
| Base fee | ~0.001 gwei | ~30 gwei | **30,000x cheaper** |
| Simple transfer | $0.0001 | $3-5 | |
| Token swap | $0.001 | $10-30 | |
| Complex deployment | $0.01 | $50-200 | |

You only pay for gas actually used — unused gas is refunded:

```
You Set:       --gas-limit 10,000,000
Contract Uses: ~500,000 gas  
You Pay For:   500,000 × 0.001 gwei = 0.0000005 ETH ≈ $0.0015
```

**Real-world example:** Full contract deployment + game testing session = **$0.016** (less than 2 cents)

### 2. `block.timestamp` Returns EVM Block Time, Not Mini Block Time

```solidity
// ⚠️ This has 1-second resolution, not 10ms
uint256 timestamp = block.timestamp; 

// If you need sub-second timing:
// - Use Chainlink Data Streams (native precompile)
// - Use off-chain timestamps with signatures
// - Accept 1s granularity
```

### 3. `null` blockHash is Normal for Recent Transactions

```javascript
const receipt = await provider.getTransactionReceipt(txHash);

if (receipt.blockHash === null && receipt.blockNumber !== null) {
  // Transaction is in a mini block, preconfirmed
  // Same guarantee as having a blockHash — sequencer committed
  // Just not yet in an EVM block
}
```

### 4. Nonce Management is Critical with High TPS

```javascript
// ❌ WRONG: Re-initializing nonce on reconnect
const nonce = await provider.getTransactionCount(address, 'latest');

// ✅ RIGHT: Use pending state or track locally
const nonce = await provider.getTransactionCount(address, 'pending');

// Even better: manage nonce state in-memory
let localNonce = await provider.getTransactionCount(address, 'pending');
// Increment localNonce after each tx, don't re-fetch
```

### 5. 500 Transaction Txpool Limit Per Account

```javascript
// Each account can have max 500 pending transactions
// If you hit "txpool is full":
// 1. Check for nonce gaps
// 2. Replace stuck transactions with higher gas
// 3. Wait for execution before sending more
```

### 6. Race Conditions in Simulations

```solidity
// State can change between simulation and execution
// (~10ms windows mean more race condition opportunities)

// Always handle execution failures gracefully
// Don't assume simulation results will match on-chain execution
```

### 7. L1 Reorgs Can Roll Back L2 State (Rare)

```javascript
// Extremely rare, but possible:
// If Ethereum L1 reorgs, MegaETH blocks anchored to it can roll back

// For high-value operations:
// - Wait for L1 finality (~15 minutes) for maximum security
// - Or accept preconfirmation risk for speed
```

### 8. eth_call Gas Limit is 10M (Not Block Limit)

```javascript
// RPC simulation has different limits than on-chain execution
// eth_call / eth_estimateGas: 10,000,000 gas max
// On-chain execution: 10,000,000,000 gas max (10 billion)

// If your simulation fails but you expect it to work on-chain,
// this might be why
```

### 9. WebSocket Methods Are Restricted

```javascript
// Currently only eth_chainId is available (rate-limited 5 req/s)
// Other WebSocket subscriptions may be unavailable
// Check docs for current status before building WS-dependent features
```

### 10. Foundry 403 Errors

```bash
# If you get "Enable JavaScript and cookies to continue"
# This is Cloudflare protection, not a MegaETH issue
# Try: different IP, VPN, or wait and retry
```

### 11. Alloy.rs TLS Handshake Failures

```rust
// Must use rustls explicitly
// Cargo.toml:
// reqwest = { version = "...", features = ["rustls-tls"] }

let client = reqwest::Client::builder()
    .use_rustls_tls()
    .build()
    .unwrap();

// Also add to main.rs:
let _ = rustls::crypto::ring::default_provider().install_default();
```

---

## Production Checklist

### Pre-Launch

- [ ] **Test on actual testnet** — local fork won't capture timing differences or MegaEVM gas behavior
- [ ] **Handle null blockHash** in all receipt processing code
- [ ] **Implement nonce management** — don't rely on re-fetching after reconnects
- [ ] **Add retry logic** for 502 errors (DNS resolution, upstream issues)
- [ ] **Test race conditions** — simulate state changes between blocks
- [ ] **Verify gas estimation** — use `--skip-simulation` or MegaETH RPC estimation

### Smart Contract

- [ ] **Don't rely on block.timestamp for sub-second timing**
- [ ] **Handle L1 reorg edge case** for high-value operations
- [ ] **Test with realistic gas usage** — block limit is 10B gas
- [ ] **Use TSTORE** if needed (Cancun transient storage is supported)
- [ ] **Verify on Blockscout** or submit to MegaExplorer ABI repo

### Infrastructure

- [ ] **Use Realtime API** for latency-sensitive operations
- [ ] **Implement eth_getLogsWithCursor** for large log queries
- [ ] **Handle rate limits** — RPCs are rate-limited, behavior is dynamic
- [ ] **Restart long-running processes** if you get 502s (stale DNS)
- [ ] **Don't cache RPC URLs** — they may change

### Monitoring

- [ ] **Track mini block height** at uptime.megaeth.com
- [ ] **Monitor sequencer health** — single sequencer means single point of awareness
- [ ] **Watch for chain announcements** — testnet may roll back during maintenance

---

## Anti-Patterns

### ❌ Treating MegaETH Like a Slow Chain

```javascript
// Don't add artificial delays or confirmations
// The speed is the feature — use it

// ❌ Old habit
await sleep(12000); // Wait for "confirmations"

// ✅ MegaETH way
const receipt = await realtimeSendTx(signedTx); // Instant confirmation
```

### ❌ Polling for State Changes

```javascript
// ❌ Wasteful polling
setInterval(async () => {
  const balance = await provider.getBalance(address);
}, 1000);

// ✅ Use Realtime API when available
// Or batch queries efficiently
```

### ❌ Assuming Block.timestamp Has ms Precision

```solidity
// ❌ Will not work as expected
require(block.timestamp > lastAction + 100, "Too fast"); // 100ms intended

// ✅ Accept 1-second resolution or use oracle
require(block.timestamp > lastAction + 1, "Too fast"); // 1 second minimum
```

### ❌ Ignoring Nonce State After Disconnects

```javascript
// ❌ Will cause stuck transactions
async function sendTx() {
  const nonce = await provider.getTransactionCount(address); // 'latest' default
  // If you have pending txs, this nonce is wrong
}

// ✅ Track pending state
async function sendTx() {
  const nonce = await provider.getTransactionCount(address, 'pending');
}
```

### ❌ Using Local Gas Estimation with Foundry

```bash
# ❌ Will fail with "intrinsic gas too low"
forge script Deploy.s.sol --broadcast

# ✅ Skip simulation, hardcode gas
forge script Deploy.s.sol --broadcast --gas-limit 10000000 --skip-simulation
```

---

## Advanced Patterns

### Pattern: Priority Transaction Handling

MegaETH's parallel execution supports transaction priorities. Critical transactions can skip queues.

```javascript
// Use higher gas price for priority (standard EIP-1559)
const priorityTx = {
  ...baseTx,
  maxPriorityFeePerGas: ethers.parseUnits('1', 'gwei'), // Higher tip
};
```

### Pattern: Designing for Parallel Execution

MegaETH achieves parallelism when transactions touch different state:

```solidity
// ❌ Contention hotspot — all txs write same slot
mapping(address => uint256) public globalCounter;

function increment() external {
  globalCounter[msg.sender]++; // Still writes to same mapping
}

// ✅ Sharded state — txs can parallelize
mapping(address => mapping(uint256 => uint256)) public userCounters;

function increment(uint256 shard) external {
  userCounters[msg.sender][shard]++;
}
```

### Pattern: Hybrid Finality Handling

```javascript
// For different use cases:

// Low-value, speed-critical: Accept mini block preconfirmation
async function fastPath(tx) {
  const receipt = await realtimeSend(tx);
  return receipt; // ~10ms, preconfirmed
}

// High-value: Wait for EVM block
async function safePath(tx) {
  let receipt = await realtimeSend(tx);
  while (receipt.blockHash === null) {
    await sleep(100);
    receipt = await provider.getTransactionReceipt(receipt.transactionHash);
  }
  return receipt; // ~1s, in EVM block
}

// Maximum security: Wait for L1 finality
async function maxSecurityPath(tx) {
  // After EVM block, wait for L1 finalization
  // ~15 minutes for Ethereum finality
}
```

---

## Ecosystem Infrastructure

### Oracles

**Chainlink Data Streams** — Native precompile integration
- Sub-millisecond latency via precompile (no external calls needed)
- "Just-in-time" price pulls — data refreshes when accessed
- Zero integration overhead — any contract can read directly
- Supports crypto, equities, commodities, RWAs
- First-ever native real-time oracle on any chain
- Docs: https://docs.chain.link/data-streams

**RedStone Bolt** — Ultra-low latency push oracle
- 2.4ms update latency — over 400 price updates per second
- Push model (not pull) — data proactively pushed on-chain
- Plug-and-play compatible with Aave, Compound, Morpho, Spark, Venus, Euler
- Bolt nodes co-located on MegaETH infrastructure
- Sources from CEXs, DEX feeds planned
- Docs: https://docs.redstone.finance

### VRF (Verifiable Random Function)

**Gelato VRF** — Officially supported on MegaETH Timothy Testnet

```solidity
// Gelato VRF integration
import {GelatoVRFConsumerBase} from "@gelatonetwork/vrf-contracts/GelatoVRFConsumerBase.sol";

contract RandomGame is GelatoVRFConsumerBase {
    constructor(address _operator) GelatoVRFConsumerBase(_operator) {}
    
    function requestRandomness() external {
        _requestRandomness(abi.encode(msg.sender));
    }
    
    function _fulfillRandomness(
        uint256 randomness,
        uint256 requestId,
        bytes memory extraData
    ) internal override {
        address player = abi.decode(extraData, (address));
        // Use randomness (e.g., randomness % 100 for 0-99)
    }
}
```

Gelato VRF uses Drand (League of Entropy) as the randomness beacon. Requires funding via Gelato's 1Balance system.

- **Docs**: https://docs.gelato.network/web3-services/vrf
- **Operator Address**: Confirm at https://app.gelato.network

### Cross-Chain (CCIP)

**Chainlink CCIP** — Integrated April 2025
- Secure cross-chain token transfers and messaging
- Battle-tested security with dual DON architecture
- Supports 60+ blockchains
- Docs: https://docs.chain.link/ccip

### Bridges

| Bridge | Type | URL |
|--------|------|-----|
| Canonical Bridge | OP Stack Standard Bridge | See Bridge section above |
| Orbiter Finance | Cross-rollup | https://test.orbiter.finance |
| Hyperlane | Permissionless interop | https://docs.hyperlane.xyz |
| Rubic | Multi-chain aggregator | https://testnet.rubic.exchange |

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

### Account Abstraction

MegaETH supports EIP-7702 natively.

| Provider | Description | Docs |
|----------|-------------|------|
| Pimlico | Bundlers and paymasters | https://docs.pimlico.io |
| ZeroDev | Smart account SDK | https://docs.zerodev.app |
| Privy | Embedded wallets | https://docs.privy.io |

### Automation

**Gelato Network** — Smart contract automation
- Web3 Functions (serverless off-chain compute)
- Time-based and event-based triggers
- Docs: https://docs.gelato.network

---

## EIP Support Reference

| EIP | Status | Notes |
|-----|--------|-------|
| EIP-55 | Not enforced | Addresses may appear lowercase in responses |
| EIP-170 | Modified | 512KB limit instead of 24KB |
| EIP-1559 | Supported | Base fee ~0.001 gwei, adjustment effectively disabled |
| EIP-7702 | Supported | Account abstraction via temporary smart contract accounts |
| Cancun (TSTORE) | Supported | Transient storage works |

---

## Network Parameters

| Parameter | Testnet | Mainnet (Frontier) |
|-----------|---------|-------------------|
| Chain ID | 6343 | 4326 |
| RPC | https://carrot.megaeth.com/rpc | https://mainnet.megaeth.com/rpc |
| Explorer | https://megaeth-testnet-v2.blockscout.com/ | https://megaeth.blockscout.com/ |
| Explorer (alt) | — | https://mega.etherscan.com |
| Block Time | Mini: 10ms, EVM: 1s | Mini: 10ms, EVM: 1s |
| Block Gas Limit | 10 billion | 10 billion |
| Base Fee | ~0.001 gwei | ~0.001 gwei |
| Contract Size Limit | 512KB | 512KB |
| eth_call Gas Limit | 10 million | 10 million |
| Txpool Limit | 500 per account | 500 per account |
| Status | Public | Whitelisted developers only |

**Note**: ChainList shows testnet as 6342 in some places — official docs confirm 6343.

---

## Resources

### Official

- **Docs**: https://docs.megaeth.com
- **Testnet Portal**: https://testnet.megaeth.com
- **Performance Dashboard**: https://uptime.megaeth.com
- **Faucet**: https://testnet.megaeth.com (click FAUCET)
- **MegaEVM Source**: https://github.com/megaeth-labs/mega-evm
- **mega-evme Debugger**: https://github.com/megaeth-labs/mega-evm/blob/main/bin/mega-evme/README.md

### Block Explorers

| Network | Explorer | URL |
|---------|----------|-----|
| Mainnet | Blockscout | https://megaeth.blockscout.com/ |
| Mainnet | Etherscan | https://mega.etherscan.com |
| Testnet | Blockscout | https://megaeth-testnet-v2.blockscout.com/ |

### RPC Endpoints

| Network | Provider | URL |
|---------|----------|-----|
| Mainnet | MegaETH | https://mainnet.megaeth.com/rpc |
| Testnet | MegaETH | https://carrot.megaeth.com/rpc |
| Testnet | Thirdweb | https://6343.rpc.thirdweb.com |
| Testnet | Alchemy | https://www.alchemy.com/rpc/megaeth-testnet |
| Testnet | ChainList | https://chainlist.org/chain/6343 |

### Infrastructure Docs

- **Chainlink Data Streams**: https://docs.chain.link/data-streams
- **Chainlink CCIP**: https://docs.chain.link/ccip
- **RedStone Bolt**: https://docs.redstone.finance
- **Gelato VRF**: https://docs.gelato.network/web3-services/vrf
- **Gelato Automate**: https://docs.gelato.network/web3-services/automate
- **Pimlico (AA)**: https://docs.pimlico.io
- **ZeroDev (AA)**: https://docs.zerodev.app

### Community

- **Contract Verification**: https://github.com/princesinha19/megaeth-abis
- **MegaExplorer**: https://www.megaexplorer.xyz
- **Community Wiki**: https://megaeth-1.gitbook.io/untitled
- **App Guide**: https://www.fluffle.tools
- **Ecosystem Hub**: https://layerhub.xyz/chains/megaeth_testnet/ecosystem

---

## Comparison with Other Chains

### vs Ethereum Mainnet
- 100x faster blocks (1s vs 12s EVM blocks, 10ms mini blocks)
- 512KB contract limit (vs 24KB)
- Centralized sequencer (vs decentralized validators) — trades decentralization for speed
- EigenDA for data availability (vs on-chain)

### vs Arbitrum/Optimism
- 10ms mini blocks (vs 250ms-2s)
- Realtime API for instant receipts
- Higher gas limits per block
- Different timestamp behavior (EVM block timestamp, not mini block)

### vs Monad
- L2 vs L1 architecture
- Ships sooner (mainnet beta live now)
- Different parallelization approach
- Ethereum security inheritance

---

*Last updated: January 2026. Always verify against official docs — MegaETH is actively developing and parameters change. Frontier (mainnet beta) is for developers only; full public mainnet expected early 2026.*
