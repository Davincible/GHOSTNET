# Lesson: Randomness Congestion Mitigation on Fast L2s

**Date:** 2026-01-21  
**Category:** Smart Contracts / Architecture / Operations  
**Severity:** High Priority Design

---

## Problem

Using future block hash randomness on fast L2s (like MegaETH with 100ms blocks) creates a tight timing window that can fail during network congestion.

**Timing math:**
- 256-block EVM blockhash limit = 25.6 seconds on MegaETH
- Seed block delay (50 blocks) = 5 seconds
- Effective reveal window = 20.6 seconds

During severe congestion, transactions can take 20+ seconds to confirm, causing seed expiry.

## Key Insights

### 1. Keeper Incentives Are Essential

**Without incentives:**
- Single operator runs keeper
- Single point of failure
- No economic motivation for redundancy

**With incentives (gas + rake bonus):**
- Multiple keepers compete
- Self-sustaining economics
- Natural redundancy

### 2. Detection Must Be Manipulation-Resistant

**Bad approach:** Timestamp-based detection
- Sequencer can manipulate timestamps
- False positives/negatives possible

**Good approach:** Block-based sliding window
- Objective, on-chain measurable
- Cannot be gamed without sustained congestion
- Hysteresis prevents oscillation

### 3. Graceful Degradation > Binary States

**Bad approach:** Either "running" or "emergency stopped"
- Overreacts to temporary issues
- Underreacts to gradual degradation

**Good approach:** Multi-tier degradation
- NORMAL → ELEVATED → SEVERE → CRITICAL
- Each level has appropriate response
- Smooth transitions with hysteresis

### 4. EIP-2935 Is a Safety Net, Not a Solution

EIP-2935 extends the blockhash window from 256 blocks to 8191 blocks (~13.6 minutes on MegaETH). This is excellent but:
- Availability must be verified per-chain
- Still has a finite window
- Should be fallback, not primary strategy

## Design Principles Discovered

### A. Design for the Unhappy Path First

The randomness system works perfectly under normal conditions. The entire design challenge is handling edge cases:
- Network congestion
- Keeper failure
- Multiple simultaneous issues

### B. Economic Alignment Beats Technical Enforcement

Instead of complex technical solutions to ensure seed reveals:
- Make revealing profitable
- Let market forces provide redundancy
- Technical enforcement as backup only

### C. Observable > Controllable

Off-chain monitoring with rich events is more flexible than on-chain circuit breakers:
- Can evolve alerting without upgrades
- Can add metrics retroactively
- Humans make better judgment calls

## Critical Assumptions to Verify

| Assumption | Status | Action |
|------------|--------|--------|
| MegaETH has stable 100ms blocks | Assumed | Verify before mainnet |
| EIP-2935 available on MegaETH | Assumed | **CRITICAL: Must verify** |
| Congestion events are transient | Assumed | Monitor post-launch |
| Multiple keepers will participate | Assumed | May need protocol-run backup |

## Anti-Patterns Avoided

### 1. "Just Extend the Window"
Extending SEED_BLOCK_DELAY too much reduces unpredictability. There's a fundamental tradeoff between security and reliability.

### 2. "Oracle Everything"
Adding oracles (VRF, price feeds) adds dependencies and trust. On-chain detection is preferable.

### 3. "Auto-Recover Everything"
Some situations require human judgment. CRITICAL level needs manual reset for good reason.

## Related Documents

- `docs/architecture/randomness-congestion-mitigation.md` - Full design
- `docs/architecture/arcade-contracts-plan.md` - Randomness architecture section
- `docs/lessons/001-prevrandao-megaeth.md` - prevrandao behavior on MegaETH

## Checklist for Similar Designs

- [ ] Identify the failure modes
- [ ] Calculate timing windows mathematically
- [ ] Design incentives for reliability
- [ ] Build detection that can't be gamed
- [ ] Create graduated response levels
- [ ] Define clear operational procedures
- [ ] Document assumptions explicitly
- [ ] Plan for verification of assumptions
