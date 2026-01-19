# Session: Smart Contracts Architecture Planning

**Date:** 2026-01-19  
**Focus:** GHOSTNET smart contract architecture and randomness strategy  
**Status:** Plan complete, pending prevrandao verification

---

## Summary

Completed initial architecture planning for GHOSTNET smart contracts. Key decision made to use block-based randomness (`prevrandao`) instead of Gelato VRF, contingent on verification that prevrandao works correctly on MegaETH.

---

## Decisions Made

### 1. Randomness Strategy: Block-Based (prevrandao)

**Decision:** Use `block.prevrandao` for trace scan death selection instead of Gelato VRF.

**Rationale:**
- Gelato VRF is NOT on-chain verifiable (BLS12-381 proofs require EIP-2537)
- Both options require trusting a reputable third party (sequencer vs Gelato operator)
- Block-based provides: zero latency, zero cost, no external dependencies
- VRF adds: ~1500ms latency, per-request costs, external dependency
- Can upgrade to VRF later if user demand exists

**Confidence:** Medium  
**Revisit if:** prevrandao verification fails on MegaETH testnet

### 2. Token: Immutable

**Decision:** DataToken.sol will NOT be upgradeable.

**Rationale:**
- Token is the primary "trust anchor" - promise that "we can't rug"
- Tax rates (9% burn, 1% treasury) should be permanent commitments
- Users need certainty these won't change

**Confidence:** High

### 3. Game Logic: UUPS Upgradeable with Timelock

**Decision:** GhostCore, TraceScan, DeadPool will use UUPS proxy pattern with 48-hour timelock.

**Rationale:**
- Game parameters will need tuning
- Bugs will be discovered
- MegaETH is new platform, may need adaptations
- Users protected by timelock visibility

**Confidence:** High

### 4. Reward Distribution: Share-Based (MasterChef Pattern)

**Decision:** Use share-based accounting for cascade distribution.

**Rationale:**
- O(1) gas regardless of participant count
- Battle-tested pattern (Sushi, Uniswap staking)
- Scales to thousands of positions

**Confidence:** High

### 5. Mini-Game Boosts: Server Signatures

**Decision:** Off-chain games validated by server, boosts claimed with signatures.

**Rationale:**
- Games (typing, hack runs) happen in browser
- Server validates gameplay, signs approval
- Appropriate trust model for entertainment features

**Confidence:** High

---

## Assumptions Made

| Assumption | Basis | Verification Needed |
|------------|-------|---------------------|
| `prevrandao` returns usable randomness on MegaETH | EVM compatibility claim | **YES - BLOCKING** |
| MegaETH sequencer won't manipulate randomness | Reputation economics | No - accepted risk |
| Gelato Automate available on MegaETH | Listed as partner | Yes - before mainnet |
| 10B gas limit sufficient for scan processing | MegaETH docs | Yes - test at scale |
| Bronto/Bebop DEX available for buybacks | Listed in ecosystem | Yes - before mainnet |

---

## Artifacts Created

1. **Architecture Plan:** `docs/architecture/smart-contracts-plan.md`
   - Complete contract architecture
   - Contract specifications (DataToken, GhostCore, TraceScan, DeadPool)
   - Economic flows (Cascade, burns)
   - Development phases (8 weeks)

2. **Verification Test Contract:** `packages/contracts/src/test/PrevRandaoTest.sol`
   - Records prevrandao samples
   - Analysis functions
   - Trace scan simulation
   - Statistical fairness testing

3. **Deployment Scripts:** `packages/contracts/script/DeployPrevRandaoTest.s.sol`
   - DeployPrevRandaoTest - Deploy test contract
   - VerifyPrevRandao - Record samples
   - AnalyzePrevRandao - Analyze results
   - SimulateTraceScan - Test death selection

4. **Verification Plan:** `docs/architecture/prevrandao-verification-plan.md`
   - Step-by-step verification procedure
   - Success criteria
   - Fallback plan (commit-reveal)
   - Quick reference commands

5. **Config Updates:**
   - `foundry.toml` - Added MegaETH RPC endpoints
   - `.env.example` - Added MegaETH and GHOSTNET config vars

---

## Next Steps

### Immediate (Before Continuing Development)

1. **Run prevrandao verification** (~1 hour)
   - Deploy PrevRandaoTest to MegaETH testnet
   - Record 10+ samples across different blocks
   - Analyze results
   - Make GO/NO-GO decision on block-based randomness

### After Verification Passes

2. **Phase 1: Foundation** (Week 1-2)
   - Implement DataToken.sol
   - Implement TeamVesting.sol
   - Basic GhostCore.sol (stake/extract only)
   - Unit tests

3. **Phase 2: Core Game** (Week 3-4)
   - TraceScan.sol with death selection
   - Complete GhostCore.sol with cascade
   - System reset timer
   - Gelato Automate integration

---

## Open Questions

1. **Team multisig composition** - Who are the 3-of-5 signers?
2. **Audit budget/timeline** - Can we get audited before launch?
3. **DEX integration** - Bronto vs Bebop for buybacks?
4. **Gelato costs** - Budget for Automate keepers?

---

## Key Insights

### Gelato VRF is Not Trustless On-Chain

From `docs/GelatoVRF.md`:
> "Gelato VRF is verifiable off-chain only (no on-chain BLS proof verification)"

This means the common assumption that "VRF = trustless" is incorrect for Gelato VRF. Your contract must trust Gelato's operator, same as trusting MegaETH's sequencer for prevrandao.

### MegaETH Block Model Implications

From `docs/MEGAETH.md`:
- Mini blocks: 10ms (preconfirmed)
- EVM blocks: 1s (finalized)
- `block.timestamp` has 1-second resolution

This means our scan timers (30min, 2h, 8h, 24h) are fine, but sub-second UI countdowns must be client-side.

### MegaEVM Gas Differences

From `docs/MEGAETH.md`:
> "Local toolchain gas estimation may fail. Use `--skip-simulation` with Foundry"

Always use `--skip-simulation` when deploying/broadcasting to MegaETH.

---

*Session logged for project continuity.*
