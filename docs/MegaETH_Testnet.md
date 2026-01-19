## TL;DR

- **Testnet V2** is current: Chain ID `6343`, RPC `https://carrot.megaeth.com/rpc`
- Full EVM compatibility - deploy standard Solidity with Foundry/Hardhat, but **gas estimation may fail** due to MegaEVM differences. Use `--skip-simulation --gas-limit 10000000` with Forge
- Use `realtime_sendRawTransaction` instead of polling for receipts - get tx confirmation in ~10ms
- Faucets are stingy: thirdweb gives 0.01 ETH/day, gas.zip gives 0.0025 ETH/day
- Verify contracts on Blockscout at `https://megaeth-testnet-v2.blockscout.com/api/`

## Stack Decisions

**Framework**: Foundry. MegaETH's speed makes Hardhat's JS overhead feel slow. Foundry's native compilation and deployment is the right fit.

**RPC Provider**: Public endpoint for dev, Alchemy for production testing. The public RPC is rate-limited and may go offline during upgrades.

**Explorer**: Blockscout. It's the only option and works well.

**Frontend Integration**: Standard ethers.js/viem, but use the Realtime API methods for instant confirmation UX.

## Project Setup

### Network Configuration

```bash
# Add to foundry.toml
[rpc_endpoints]
megaeth-testnet = "https://carrot.megaeth.com/rpc"

[etherscan]
megaeth-testnet = { key = "", url = "https://megaeth-testnet-v2.blockscout.com/api/" }
```

### MetaMask / Wallet Config

```
Network Name: MegaETH Testnet V2
RPC URL: https://carrot.megaeth.com/rpc
Chain ID: 6343
Currency Symbol: ETH
Block Explorer: https://megaeth-testnet-v2.blockscout.com/
```

### Get Test ETH

Multiple faucets, all have limits:

```bash
# Option 1: thirdweb (0.01 ETH/day)
# https://thirdweb.com/megaeth-testnet

# Option 2: Chainlink faucet
# https://faucets.chain.link/megaeth-testnet

# Option 3: gas.zip (0.0025 ETH/day)
# https://www.gas.zip/faucet/megaeth

# Option 4: Official testnet page
# https://testnet.megaeth.com/ -> FAUCET tab
```

### Deploy with Foundry

```bash
# Standard deployment - THIS WILL LIKELY FAIL due to gas estimation
forge create src/Counter.sol:Counter \
  --rpc-url megaeth-testnet \
  --private-key $PRIVATE_KEY

# CORRECT approach - skip local simulation, use hardcoded gas limit
forge create src/Counter.sol:Counter \
  --rpc-url megaeth-testnet \
  --private-key $PRIVATE_KEY \
  --gas-limit 10000000 \
  --skip-simulation

# With verification
forge create src/Counter.sol:Counter \
  --rpc-url megaeth-testnet \
  --private-key $PRIVATE_KEY \
  --gas-limit 10000000 \
  --skip-simulation \
  --verify \
  --verifier blockscout \
  --verifier-url https://megaeth-testnet-v2.blockscout.com/api/
```

### Deploy with Foundry Scripts

```solidity
// script/Deploy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";

contract DeployScript is Script {
    function run() external returns (Counter) {
        vm.startBroadcast();
        Counter counter = new Counter();
        vm.stopBroadcast();
        return counter;
    }
}
```

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url megaeth-testnet \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --gas-limit 10000000 \
  --skip-simulation \
  --verify \
  --verifier blockscout \
  --verifier-url https://megaeth-testnet-v2.blockscout.com/api/
```

### Hardhat Configuration

```javascript
// hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.24",
  networks: {
    megaethTestnet: {
      url: "https://carrot.megaeth.com/rpc",
      chainId: 6343,
      accounts: [process.env.PRIVATE_KEY],
      gasPrice: 1000000, // 0.001 gwei in wei
    }
  }
};
```

## Architecture Patterns

### Using the Realtime API

The killer feature. Instead of send tx → poll receipt, do it in one call:

```javascript
// viem example
const receipt = await client.request({
  method: 'realtime_sendRawTransaction',
  params: [signedTx]
});
// Receipt returned directly, no polling needed
```

```javascript
// ethers.js - you need a custom provider method
async function realtimeSendTransaction(provider, signedTx) {
  const result = await provider.send('realtime_sendRawTransaction', [signedTx]);
  return result; // Returns receipt directly
}
```

### WebSocket Subscriptions for Real-time Events

```javascript
// Subscribe to state changes on an address
const ws = new WebSocket('wss://carrot.megaeth.com/ws');

ws.send(JSON.stringify({
  jsonrpc: "2.0",
  method: "eth_subscribe",
  params: [
    "stateChanges",
    ["0xYourContractAddress"]
  ],
  id: 1
}));

// Subscribe to logs in real-time (from mini blocks)
ws.send(JSON.stringify({
  jsonrpc: "2.0",
  method: "eth_subscribe",
  params: [
    "logs",
    {
      address: "0xYourContract",
      fromBlock: "pending",
      toBlock: "pending"
    }
  ],
  id: 2
}));

// Subscribe to mini blocks
ws.send(JSON.stringify({
  jsonrpc: "2.0",
  method: "eth_subscribe",
  params: ["miniBlocks"],
  id: 3
}));
```

**Note**: As of current docs, most WebSocket methods except `eth_chainId` are rate-limited to 5 reqs/s. Check docs for updates.

### Paginated Log Queries

For large log datasets, use cursor-based pagination:

```javascript
async function getAllLogs(filter) {
  let allLogs = [];
  let cursor = null;
  
  do {
    const response = await provider.send('eth_getLogsWithCursor', [{
      ...filter,
      cursor: cursor
    }]);
    
    allLogs = allLogs.concat(response.logs);
    cursor = response.cursor;
  } while (cursor);
  
  return allLogs;
}
```

## Critical Gotchas

### Gas Estimation Failures

**This is the #1 issue you'll hit.** MegaEVM has a different gas model than vanilla EVM. Local simulation by Foundry/Hardhat will calculate wrong gas, causing:
- `intrinsic gas too low` errors
- Transactions reverting due to OOG

**Fix**: Always use `--skip-simulation --gas-limit <high_number>` with Forge, or rely on MegaETH's RPC for estimation.

### Mini Blocks vs EVM Blocks

MegaETH has two block types:
- **Mini blocks**: 10ms intervals, contain preconfirmed transactions
- **EVM blocks**: 1s intervals, standard Ethereum blocks

When you query with `latest` or `pending` tags, you get mini block state (real-time). When you query with a specific block number, you get EVM block state.

**Implication**: A transaction can appear "confirmed" in the Realtime API but not yet in a traditional block explorer view.

### Block Gas Limit is Massive

10 billion gas per EVM block. Don't use this as a reason to write inefficient code, but know that gas limits won't be your bottleneck.

### Base Fee is Negligible

0.001 gwei means gas costs are essentially zero on testnet. Don't optimize for gas on testnet - focus on correctness.

### RPC Instability

> "RPCs may go offline during upgrades. Contracts and states may be rolled back in rare cases."

This is testnet. Expect occasional downtime. Don't run production tests without fallback plans.

### Transaction Receipt `blockHash` Quirk

In Realtime API responses, transaction receipts may have:
- `blockHash: null` but valid `blockNumber`

This means the tx is in a mini block (preconfirmed) but not yet in an EVM block. **The preconfirmation guarantee is the same** - the sequencer commits to not rolling back.

### Contract Verification Timing

Blockscout verification can be flaky. If it fails:
1. Wait a few minutes, try again
2. Use `forge verify-contract` separately after deployment
3. Verify manually through Blockscout UI as fallback

## Production Checklist

- [ ] Test with `realtime_sendRawTransaction` for user-facing flows
- [ ] Handle `realtime transaction expired` error (10s timeout) gracefully
- [ ] Implement fallback to standard `eth_getTransactionReceipt` polling
- [ ] Set appropriate gas limits (don't rely on estimation)
- [ ] Monitor RPC health - have alerting for failures
- [ ] Test contract behavior during network maintenance windows
- [ ] Verify contracts on Blockscout for transparency
- [ ] Test WebSocket reconnection logic
- [ ] Handle mini block vs EVM block state inconsistencies in UI

## Anti-Patterns

### Relying on Local Gas Estimation

```bash
# DON'T
forge create Contract.sol:Contract --rpc-url megaeth-testnet

# DO
forge create Contract.sol:Contract --rpc-url megaeth-testnet --gas-limit 10000000 --skip-simulation
```

### Polling for Receipt After Send

```javascript
// DON'T
const txHash = await contract.someMethod();
// ... poll eth_getTransactionReceipt repeatedly

// DO
const receipt = await provider.send('realtime_sendRawTransaction', [signedTx]);
// Receipt returned immediately
```

### Assuming Block Numbers Match Transaction Order

Mini blocks and EVM blocks have different numbering. Don't assume `blockNumber` from a receipt corresponds to the EVM block you'd see on the explorer immediately.

### Using Old Chain ID 6342

The original testnet was chain ID 6342. Current testnet V2 is **6343**. Check your config.

### Ignoring Testnet Disclaimers

> "Testnet tokens and transactions have no real monetary value. Everything happening on the chain is solely for experimental purposes."

Don't build anything that depends on testnet state persisting.

## Advanced Patterns

### Debugging with mega-evme

MegaETH provides `mega-evme` for accurate local transaction simulation:

```bash
# Clone and build
git clone https://github.com/megaeth-labs/mega-evm
cd mega-evm
cargo build --release

# Use for debugging specific transactions
./target/release/mega-evme --help
```

This uses the actual MegaEVM implementation, so gas calculations match production.

### High-Frequency Trading / Gaming Patterns

For apps that need 10ms responsiveness:

```javascript
// Use WebSocket for subscriptions
const ws = new WebSocket('wss://carrot.megaeth.com/ws');

// Subscribe to your contract's state changes
ws.send(JSON.stringify({
  jsonrpc: "2.0",
  method: "eth_subscribe",
  params: ["stateChanges", [contractAddress]],
  id: 1
}));

// React to state changes in real-time
ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  if (data.params?.result) {
    const { balance, nonce, storage } = data.params.result;
    // Update UI immediately
  }
};
```

### Bridging to Testnet

For cross-chain testing, use:
- **Gasyard**: Bridge from ETH Sepolia to MegaETH Testnet
- **Rubic**: Multi-chain testnet bridge support

## Resources

**Official**
- Docs: https://docs.megaeth.com/
- Testnet Portal: https://testnet.megaeth.com/
- Blockscout Explorer: https://megaeth-testnet-v2.blockscout.com/
- GitHub: https://github.com/megaeth-labs

**Faucets**
- thirdweb: https://thirdweb.com/megaeth-testnet
- Chainlink: https://faucets.chain.link/megaeth-testnet
- gas.zip: https://www.gas.zip/faucet/megaeth

**Debugging**
- mega-evme: https://github.com/megaeth-labs/mega-evm
- Network status: https://uptime.megaeth.com

**Indexing**
- Envio guide: https://docs.envio.dev/blog/how-to-index-megaeth-data-using-envio

---

**Current as of**: January 2026. MegaETH is evolving rapidly - the RPC URL changed from `timothy.megaeth.com` to `carrot.megaeth.com` recently. Always verify against https://docs.megaeth.com/testnet for the latest.
