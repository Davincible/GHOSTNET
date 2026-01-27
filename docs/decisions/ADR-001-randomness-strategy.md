---
status: accepted
date: 2026-01-27
decision-makers: [core team]
supersedes: 
superseded_by: 
tags:
  - type/adr
  - feature/randomness
  - domain/core
  - domain/arcade
---

# ADR-001: Randomness Strategy for GHOSTNET

## Context

GHOSTNET requires verifiable randomness for two primary use cases:

1. **Core Game (Trace Scans):** Periodic survival checks that probabilistically liquidate positions based on death rates. Occurs every 30 minutes to 24 hours depending on risk level.

2. **Arcade Games (Hash Crash, Bounty Hunt, etc.):** Casino-style games requiring unpredictable outcomes for crash points, target assignments, and betting resolutions.

On MegaETH, we discovered that `block.prevrandao` behaves differently than on Ethereum mainnet — it stays **constant for ~60 seconds** across 50+ blocks (tied to epoch boundaries rather than individual blocks). This raised concerns about predictability.

We evaluated three options:
- **Gelato VRF:** External oracle using Drand beacon
- **prevrandao + lock period:** Block-based with commit-reveal style protection
- **Future block hash (EIP-2935):** Commit to future block, use its hash as seed

## Decision

We adopt a **two-tier randomness strategy**:

### Tier 1: Core Trace Scans → prevrandao + 60-second lock period

```solidity
// TraceScan.sol
uint256 seed = uint256(keccak256(abi.encode(
    block.prevrandao,    // Constant for ~60s on MegaETH
    block.timestamp,     // Changes every second
    block.number,        // Changes every block
    level,
    scanNonce++
)));
```

**Why this works:**
- 60-second **lock period** before scans prevents extraction during the predictable window
- Multi-component seed adds entropy from timestamp and block number
- Economic deterrent: front-running costs 19% (10% exit tax + 10% re-entry tax)
- Trust model equivalent to trusting MegaETH sequencer (which users already do)

### Tier 2: Arcade Games → Future Block Hash Pattern

```solidity
// FutureBlockRandomness.sol (abstract base)
function _commitSeed(uint256 roundId) internal {
    seedBlock[roundId] = block.number + SEED_BLOCK_DELAY;
}

function _revealSeed(uint256 roundId) internal returns (uint256) {
    bytes32 hash = blockhash(seedBlock[roundId]);
    return uint256(keccak256(abi.encode(hash, roundId, address(this))));
}
```

**Why this works:**
- Bets placed **before** seed block exists — truly unpredictable
- EIP-2935 on MegaETH extends blockhash window to 8191 blocks (~13.6 minutes)
- No external dependencies or latency
- Verifiable: anyone can check `blockhash(seedBlock)` matches recorded hash

## Consequences

### Positive

- **Zero latency:** No VRF callback delay (1500ms+ with Gelato)
- **Zero cost:** No oracle fees or gas premiums
- **No external dependency:** No Gelato service availability concerns
- **Simpler architecture:** No callback patterns or subscription management
- **MegaETH-native:** Uses platform capabilities optimally

### Negative

- **Trust assumption:** Must trust MegaETH sequencer not to manipulate block production
  - *Mitigation:* Reputation cost >> game stakes; same trust already required for chain usage
- **prevrandao predictability window:** ~60 seconds of known randomness
  - *Mitigation:* Lock period covers this window completely
- **blockhash expiry:** Must reveal within 256 blocks (or 8191 with EIP-2935)
  - *Mitigation:* Keeper bots proactively reveal; games handle expiry gracefully

### Neutral

- Different pattern for core vs arcade (justified by different timing requirements)
- Future option to add VRF for ultra-high-stakes scenarios if needed

## Alternatives Considered

### Gelato VRF

| Factor | Assessment |
|--------|------------|
| On-chain verifiable | No (BLS12-381 not EVM-native until EIP-2537) |
| Latency | ~1500ms |
| Cost | Gas + 10-30% premium |
| External dependency | Yes (Gelato service) |
| MegaETH support | Testnet only, mainnet unconfirmed |

**Rejected because:** Same trust model as sequencer (trust Gelato operator vs sequencer), but adds latency, cost, and external dependency.

### Chainlink VRF

**Rejected because:** Not available on MegaETH.

### Commit-Reveal with Player Secrets

**Considered for:** Games where player choice affects outcome (Binary Bet).

**Used:** `CommitRevealBase.sol` for commit-reveal games specifically, combined with future block hash for the random component.

## References

- `docs/learnings/001-prevrandao-megaeth.md` — Empirical testing of prevrandao behavior
- `docs/archive/architecture/smart-contracts-plan.md` Section 2.1 — Original decision analysis
- `docs/design/arcade/infrastructure/randomness.md` — Arcade randomness patterns
- `packages/contracts/src/core/TraceScan.sol` — Core game implementation
- `packages/contracts/src/randomness/FutureBlockRandomness.sol` — Arcade base contract
- `docs/integrations/gelato-vrf.md` — VRF as potential fallback
