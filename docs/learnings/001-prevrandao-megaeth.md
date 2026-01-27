# Lesson: prevrandao Behavior on MegaETH

**Date:** 2026-01-19  
**Category:** Smart Contracts / Randomness  
**Difficulty:** 3 hours (testing + analysis)

## Problem

When implementing randomness for trace scan death selection in GHOSTNET, we needed to understand how `block.prevrandao` behaves on MegaETH. The assumption was that it would change every block like on Ethereum mainnet.

## What We Discovered

**Finding:** `block.prevrandao` stays CONSTANT for approximately 60 seconds across 50+ blocks on MegaETH testnet.

This is fundamentally different from Ethereum mainnet where prevrandao changes every block (~12 seconds).

### Test Results

```
Block 12345: prevrandao = 0xabc123...
Block 12346: prevrandao = 0xabc123... (same)
Block 12347: prevrandao = 0xabc123... (same)
... 50+ blocks over 60 seconds ...
Block 12398: prevrandao = 0xdef456... (changed!)
```

### Why This Happens

MegaETH has a different block model:
- **Mini-blocks:** 10ms (preconfirmed, for speed)
- **EVM blocks:** 1 second (for compatibility)
- **Epoch boundaries:** ~60 seconds (when prevrandao updates)

The prevrandao value appears to be tied to epoch boundaries, not individual blocks.

## Initial Concern

This seemed problematic because:
1. Players could observe the prevrandao value
2. Calculate if they would die in an upcoming scan
3. Extract their position before the scan to avoid death

This would break the game's core mechanic.

## Solution

After deeper analysis, we determined prevrandao is **acceptable** with mitigations:

### 1. Pre-Scan Lock Period (60 seconds)

```solidity
uint256 public constant LOCK_PERIOD = 60 seconds;

modifier notInLockPeriod(uint8 level) {
    uint256 nextScan = levels[level].nextScanTime;
    require(
        block.timestamp < nextScan - LOCK_PERIOD || block.timestamp >= nextScan,
        "Position locked: scan imminent"
    );
    _;
}
```

Players cannot extract in the 60 seconds before a scan, eliminating the prediction window.

### 2. Multi-Component Seed

```solidity
uint256 seed = uint256(keccak256(abi.encode(
    block.prevrandao,    // Constant for ~60s
    block.timestamp,     // Changes every 1s
    block.number,        // Changes every block
    level,
    _scanNonce++
)));
```

Even with constant prevrandao, timestamp and block number add entropy.

### 3. Economic Deterrent

Front-running death costs 19% (10% exit tax + 10% re-entry tax). This makes repeated front-running economically painful and actually burns tokens.

## Why It Works

1. **You can't change your fate** - Your address determines if you die for a given seed. You can only observe early, not change the outcome.

2. **Lock period matches prevrandao period** - 60-second lock covers the entire window where prevrandao is predictable.

3. **Fairness is preserved** - Selection is still uniformly random. Every address has equal probability.

4. **Economic incentives align** - Players who front-run pay a 19% "survival tax" that burns tokens.

## Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| Commit-reveal | Adds 1-2s latency, extra complexity, marginal benefit with lock period |
| Gelato VRF | Not on-chain verifiable, same trust model as sequencer, external dependency |
| Chainlink VRF | Not available on MegaETH |

## Prevention

When working with L2s or new chains:

1. **Never assume EVM opcodes behave identically** - Block properties can differ significantly
2. **Test on actual network** - Local simulation may not reveal chain-specific behavior
3. **Design with mitigations** - Lock periods, economic deterrents, multi-component entropy
4. **Document chain-specific findings** - Future developers need this context

## Test Contract

Deployed verification contract: `0x332E2bbADdF7cC449601Ea9aA9d0AB8CfBe60E08` (MegaETH Testnet)

Source: `packages/contracts/src/test/PrevRandaoTest.sol`

## References

- MegaETH Block Model: `docs/integrations/megaeth.md`
- Architecture Decision: `docs/architecture/smart-contracts-plan.md` Section 5
- Session Log: `docs/sessions/2026-01-19-smart-contracts-architecture.md`
