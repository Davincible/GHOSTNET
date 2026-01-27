# Lesson: MegaETH Foundry Deployment Requires --skip-simulation

**Date:** 2026-01-23  
**Category:** Smart Contracts / Deployment / MegaETH  
**Difficulty:** 2 hours (debugging gas estimation failures)

## Problem

When deploying contracts to MegaETH testnet using Foundry (`forge script` or `cast send`), transactions would fail with:
- Status `0` (failed) 
- Empty logs
- No clear error message
- Used all provided gas

Standard deployment commands that work on Ethereum mainnet or other L2s failed silently on MegaETH.

## What Didn't Work

### 1. Standard Foundry Deployment
```bash
# Failed with "intrinsic gas too low" or silent failure
forge script Deploy.s.sol --rpc-url $MEGAETH_RPC --broadcast
```

### 2. Default Cast Commands
```bash
# Failed - transaction reverted with no logs
cast send $CONTRACT "function()" --private-key $KEY --rpc-url $RPC
```

### 3. Increasing Gas Price
```bash
# Still failed - gas estimation itself was wrong
forge script Deploy.s.sol --gas-price 2gwei --broadcast
```

### 4. Low Gas Limits (100k)
```bash
# Token approvals failed at 100k gas limit
cast send $TOKEN "approve(address,uint256)" $SPENDER $AMOUNT --gas-limit 100000
```

## Solution

MegaETH uses **MegaEVM** which has different gas costs than vanilla EVM. Foundry's local gas simulation produces incorrect estimates. The fix is:

### 1. Skip Local Simulation
```bash
forge script Deploy.s.sol --rpc-url $MEGAETH_RPC --broadcast \
  --skip-simulation --gas-limit 10000000 --legacy
```

### 2. Use Higher Gas Limits
```bash
# Token operations need 200k+
cast send $TOKEN "approve(address,uint256)" $SPENDER $AMOUNT \
  --gas-limit 200000 --legacy --private-key $KEY --rpc-url $RPC

# Complex contract calls need 500k+
cast send $CONTRACT "complexFunction()" \
  --gas-limit 500000 --legacy --private-key $KEY --rpc-url $RPC
```

### 3. Use Legacy Transactions
```bash
# --legacy flag for best compatibility
forge script Deploy.s.sol --broadcast --skip-simulation --legacy
```

## Why It Works

### MegaEVM Gas Differences

MegaETH implements **MegaEVM**, an optimized execution environment that:
- Has different opcode gas costs than standard EVM
- Uses parallel execution (touching different state can run concurrently)
- Has 10 billion gas block limit (vs Ethereum's ~30M)

When Foundry simulates locally, it uses standard EVM gas costs. These don't match MegaEVM's actual costs, leading to:
- Underestimated gas limits
- "Intrinsic gas too low" errors
- Silent transaction failures

### --skip-simulation Behavior

With `--skip-simulation`:
- Foundry skips local EVM simulation
- Uses the provided `--gas-limit` directly
- Lets MegaETH RPC handle actual execution
- Transactions succeed with correct gas consumption

### --legacy Flag

MegaETH works best with legacy (Type 0) transactions:
- Simpler transaction format
- More predictable gas behavior
- Avoids EIP-1559 complications on L2

## High Gas Limits ≠ High Costs

**Important:** The high gas limits do NOT mean expensive transactions. MegaETH is extremely cheap.

### Why High Limits Are Safe

```
You Set:     --gas-limit 10,000,000
Contract Uses: ~500,000 gas
You Pay For:   500,000 gas only (unused is refunded)
```

### MegaETH Gas Economics

| Metric | Value |
|--------|-------|
| Base fee | ~0.001 gwei (vs Ethereum's ~30 gwei) |
| Cost multiplier | **30,000x cheaper than Ethereum** |
| Typical game tx | $0.0005 |
| Complex deployment | $0.01 |

### Actual Costs from Testing

| Operation | Gas Used | Cost (USD) |
|-----------|----------|------------|
| Deploy ArcadeCore | 2,500,000 | $0.0075 |
| Deploy HashCrash | 1,800,000 | $0.0054 |
| Token approve | 108,928 | $0.0003 |
| Place bet | 220,000 | $0.0007 |
| Cash out | 170,000 | $0.0005 |
| **Full test session** | 5,339,186 | **$0.016** |

Our entire deployment + full game test cost less than 2 cents!

### Cost Formula

```
Actual Cost = Gas Used × Gas Price
            = 500,000 × 0.001 gwei
            = 0.0000005 ETH
            ≈ $0.0015 at $3000/ETH
```

The high gas limits are just safety margins because Foundry can't estimate MegaEVM costs correctly. You only pay for gas actually consumed.

## Tested Operations

All verified working with correct flags:

| Operation | Gas Limit | Actual Gas | Cost |
|-----------|-----------|------------|------|
| Contract deployment (complex) | 10M | ~2.5M | $0.0075 |
| Token mint | 100k | ~94k | $0.0003 |
| Token approve | 200k | ~109k | $0.0003 |
| Game startRound() | 500k | ~119k | $0.0004 |
| Game placeBet() | 1M | ~220k | $0.0007 |
| Game cashOut() | 500k | ~170k | $0.0005 |
| Withdraw payout | 300k | ✅ |

## Prevention

### 1. Update AGENTS.md
Added MegaETH deployment section with all flags and examples.

### 2. Script Comments
Add to all deployment scripts:
```solidity
/// Usage:
/// forge script script/Deploy.s.sol --rpc-url megaeth_testnet \
///   --broadcast --skip-simulation --gas-limit 10000000 --legacy
```

### 3. CI/CD Configuration
When setting up MegaETH deployment pipelines:
```yaml
- name: Deploy to MegaETH
  run: |
    forge script script/Deploy.s.sol \
      --rpc-url ${{ secrets.MEGAETH_RPC }} \
      --broadcast \
      --skip-simulation \
      --gas-limit 10000000 \
      --legacy
```

## Additional Findings

### EIP-2935 Available
MegaETH testnet has EIP-2935 enabled, providing 8191 block history for blockhash lookups. This is beneficial for randomness-based games.

### Fast Block Times
- Mini-blocks: 10ms (preconfirmed)
- EVM blocks: ~1 second
- Seed blocks ready within 3-5 seconds

### Transaction Receipts
Receipts may have `blockHash: null` initially (in mini-block, not yet in EVM block). This is normal - transaction is still preconfirmed.

## Deployed Test Contracts

| Contract | Address |
|----------|---------|
| MockERC20 (mDATA) | `0x785Bb007015F074972705a9A827b38d6F334c2DA` |
| ArcadeCore (proxy) | `0x068E0cAA79DA7493DE8BC0b4FF197867A0eb6cA4` |
| HashCrash | `0x8ad8C19D7d63f5AA8dF1f65489fBb11158b3122a` |
| GameRegistry | `0x00d957428eCCE5Bdf2e3f243EDa0968C3F11dEB2` |

## References

- MegaETH Developer Guide: `docs/integrations/megaeth.md`
- MegaEVM Source: https://github.com/megaeth-labs/mega-evm
- Testnet Explorer: https://megaeth-testnet-v2.blockscout.com/
- Testnet RPC: `https://carrot.megaeth.com/rpc` (Chain ID: 6343)
