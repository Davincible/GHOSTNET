# Session Log: Randomness Congestion Mitigation Design

**Date:** 2026-01-21  
**Task:** Design comprehensive randomness reliability system (Issue #5 from architecture review)  
**Status:** DESIGN COMPLETE

---

## Session Summary

Designed a four-layer randomness reliability system to address the risk of seed expiry during network congestion on MegaETH's fast block times (100ms).

## Key Decisions Made

### 1. Keeper Incentive Model
**Decision:** Gas reimbursement (200%) + bonus (0.5% of session pot)

**Rationale:**
- Self-sustaining economics (no treasury drain)
- Scales naturally with protocol activity
- Attractive enough to bring multiple keepers

**Alternatives rejected:**
- No reward (single point of failure)
- Fixed bounty (drains treasury)
- Rake percentage only (complex accounting)

### 2. Congestion Detection
**Decision:** Block-based sliding window (10 samples)

**Rationale:**
- Fully on-chain, no oracle dependency
- Cannot be easily gamed
- Objective and verifiable

**Alternatives rejected:**
- Timestamp-based (manipulable by sequencer)
- External oracle (adds dependency)
- Gas price threshold (not always correlated)

### 3. Graceful Degradation Strategy
**Decision:** Three-tier degradation (ELEVATED, SEVERE, CRITICAL)

**Rationale:**
- Allows continued operation under moderate stress
- Automatic protection during severe conditions
- Admin override capability

**Key parameters:**
- ELEVATED: avgDelay > 30 blocks, increase seed delay to 80
- SEVERE: avgDelay > 100 blocks, pause new sessions
- CRITICAL: SEVERE + no EIP-2935, emergency pause

### 4. Monitoring Architecture
**Decision:** Off-chain monitoring with rich on-chain events

**Rationale:**
- No gas overhead for monitoring
- Flexible alerting logic
- Can evolve without contract changes

## Assumptions Made

| Assumption | Confidence | Verification Required |
|------------|------------|----------------------|
| MegaETH 100ms block times stable | High | Confirmed in docs |
| EIP-2935 available on MegaETH | Medium | **Must verify before mainnet** |
| Congestion events ~1/week | Low | **Unknown, needs observation** |
| Keeper economics profitable at $0.10/DATA | Medium | **Monitor post-launch** |

## Open Questions

1. **EIP-2935 on MegaETH:** Need to confirm availability on mainnet. Current plan assumes it's available.

2. **Congestion patterns:** MegaETH is new, congestion behavior unknown. May need to adjust thresholds based on observation.

3. **Keeper ecosystem:** Will third-party keepers emerge? May need keeper registry if ecosystem develops.

4. **Price oracle:** What oracle to use for ETH->DATA conversion for gas reimbursement? Options:
   - Chainlink (if available)
   - Uniswap TWAP
   - Custom aggregator

## Deliverables Created

1. **Architecture Document:** `docs/architecture/randomness-congestion-mitigation.md`
   - Full design with ADRs
   - Solidity implementation specs
   - Keeper bot specification
   - Operational runbook
   - Risk analysis

## Next Steps

1. [ ] Security team review
2. [ ] Implement Solidity contracts
3. [ ] Implement keeper bot (Rust or TypeScript)
4. [ ] Set up monitoring infrastructure
5. [ ] Testnet deployment and testing
6. [ ] Load testing with artificial congestion

## Files Changed

- `docs/architecture/randomness-congestion-mitigation.md` (created)
- `docs/sessions/2026-01-21-randomness-congestion-mitigation.md` (this file)
- `docs/lessons/2026-01-21-randomness-congestion-mitigation.md` (created)

---

**Session Duration:** ~2 hours  
**Complexity:** High (cross-cutting concerns: contracts, infrastructure, operations)
