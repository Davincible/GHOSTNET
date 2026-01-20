# GHOSTNET Security Audit Scope

**Version:** 1.0  
**Status:** Planning  
**Last Updated:** 2026-01-20  
**Target Audit Date:** [TBD]

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Contracts In Scope](#2-contracts-in-scope)
3. [Contracts Out of Scope](#3-contracts-out-of-scope)
4. [Critical Areas of Focus](#4-critical-areas-of-focus)
5. [Known Issues & Design Decisions](#5-known-issues--design-decisions)
6. [Testing Requirements](#6-testing-requirements)
7. [Documentation Available](#7-documentation-available)
8. [Audit Deliverables](#8-audit-deliverables)
9. [Timeline & Coordination](#9-timeline--coordination)

---

## 1. Executive Summary

### Protocol Description

GHOSTNET is a real-time survival game on MegaETH where users stake $DATA tokens across five risk levels. Periodic "trace scans" randomly eliminate positions, redistributing their capital to survivors through "The Cascade." The protocol includes a prediction market (Dead Pool), mini-game boosts, and a system reset mechanism.

### Key Economic Parameters

| Parameter | Value |
|-----------|-------|
| Token Supply | 100,000,000 DATA |
| Transfer Tax | 10% (9% burn, 1% treasury) |
| Death Rates | 5% - 40% (by level) |
| Cascade Split | 30% same-level / 30% upstream / 30% burn / 10% protocol |
| System Reset Penalty | 25% of all positions |
| Emissions | 60M DATA over 24 months |

### Technology Stack

- **Blockchain:** MegaETH (EVM-compatible L2)
- **Solidity Version:** 0.8.33
- **Frameworks:** OpenZeppelin 5.x, Foundry
- **Upgrade Pattern:** UUPS (ERC-1967)
- **Randomness:** Block-based (prevrandao) with 60s lock period

---

## 2. Contracts In Scope

### 2.1 Core Contracts

| Contract | Type | LOC (est.) | Complexity | Priority |
|----------|------|------------|------------|----------|
| **GhostCore.sol** | UUPS Proxy | ~800 | High | Critical |
| **TraceScan.sol** | UUPS Proxy | ~400 | High | Critical |
| **DataToken.sol** | Immutable | ~150 | Medium | Critical |
| **RewardsDistributor.sol** | UUPS Proxy | ~250 | Medium | High |
| **DeadPool.sol** | UUPS Proxy | ~500 | Medium | High |

### 2.2 Peripheral Contracts

| Contract | Type | LOC (est.) | Complexity | Priority |
|----------|------|------------|------------|----------|
| **FeeRouter.sol** | Immutable | ~200 | Low | Medium |
| **TeamVesting.sol** | Immutable | ~100 | Low | Medium |
| **GhostTimelock.sol** | TimelockController | ~50 | Low | Medium |

### 2.3 Libraries

| Library | LOC (est.) | Priority |
|---------|------------|----------|
| **DeathMath.sol** | ~100 | High |
| **CascadeLib.sol** | ~150 | High |
| **PositionLib.sol** | ~80 | Medium |

### Total Estimated Lines of Code: ~2,780

---

## 3. Contracts Out of Scope

| Contract/Component | Reason |
|--------------------|--------|
| OpenZeppelin base contracts | Extensively audited |
| Test contracts (`*.t.sol`) | Not deployed |
| Deployment scripts | Not on-chain |
| Frontend/Backend code | Separate audit track |
| MegaETH chain itself | Infrastructure |

---

## 4. Critical Areas of Focus

### 4.1 Access Control

**Priority: CRITICAL**

| Area | Concern | Contracts |
|------|---------|-----------|
| Role management | Incorrect role assignments | GhostCore, TraceScan |
| Admin functions | Unauthorized access | All upgradeable |
| Upgrade authorization | Bypass of timelock | All UUPS |
| Boost signer | Key compromise impact | GhostCore |
| Emergency functions | Pause/unpause abuse | GhostCore, TraceScan, DeadPool |

**Specific Checks:**
- [ ] Only SCANNER_ROLE can call `processDeaths()`
- [ ] Only DISTRIBUTOR_ROLE can call `addEmissionRewards()`
- [ ] Only DEFAULT_ADMIN_ROLE can upgrade via UUPS
- [ ] Timelock delays are enforced correctly
- [ ] Emergency multisig cannot bypass timelock for non-emergencies

### 4.1.1 EIP-7702 Considerations (Pectra Upgrade)

**Priority: CRITICAL**

EIP-7702 (activated May 2025) allows EOAs to delegate to smart contracts, breaking traditional EOA detection patterns. MegaETH inherits this capability.

| Check | Status |
|-------|--------|
| No `tx.origin == msg.sender` checks for EOA detection | [ ] |
| No `extcodesize == 0` checks for EOA detection | [ ] |
| No `msg.sender.code.length == 0` checks | [ ] |
| Rate limiting uses time-based delays, not caller-type assumptions | [ ] |
| Anti-bot measures don't rely on EOA detection | [ ] |

**Background:** Over $5.3M was stolen via broken EOA assumptions in the months following the Pectra upgrade. A delegated EOA:
- Passes `tx.origin == msg.sender` checks
- Has 23 bytes of code (`0xef0100 || delegateAddress`)
- Can execute arbitrary contract logic

**Note:** If any anti-bot or human-verification logic is added during implementation, it MUST NOT rely on EOA detection patterns. Use time delays, economic incentives, or EIP-712 signatures instead.

### 4.2 Reentrancy

**Priority: CRITICAL**

| Function | External Calls | Risk |
|----------|----------------|------|
| `jackIn()` | `transferFrom()` | Medium |
| `extract()` | `transfer()` | High |
| `claimRewards()` | `transfer()` | High |
| `processDeaths()` | `transfer()` (cascade) | High |
| `triggerSystemReset()` | Multiple `transfer()` | Critical |
| `emergencyWithdraw()` | `transfer()` | High |

**Mitigations to Verify:**
- [ ] ReentrancyGuard applied to all state-changing functions
- [ ] Checks-Effects-Interactions pattern followed
- [ ] State updates before external calls
- [ ] No callbacks to untrusted contracts

### 4.3 Arithmetic & Precision

**Priority: HIGH**

| Calculation | Risk | Location |
|-------------|------|----------|
| Share-based rewards | Precision loss | GhostCore |
| Death rate calculation | Rounding errors | TraceScan |
| Cascade distribution | Sum != 100% | GhostCore |
| Tax calculation | Rounding | DataToken |
| Emission rate | Overflow/underflow | RewardsDistributor |
| Penalty calculation | Precision | GhostCore (system reset) |

**Specific Checks:**
- [ ] `accRewardsPerShare` scaled by 1e18 correctly
- [ ] No division before multiplication
- [ ] Cascade splits sum to exactly 10000 bps
- [ ] Tax calculation doesn't lose dust
- [ ] Lazy penalty settlement maintains consistency

### 4.4 Randomness

**Priority: HIGH**

| Aspect | Concern | Contract |
|--------|---------|----------|
| Seed generation | Predictability | TraceScan |
| Lock period | Front-running window | GhostCore |
| Death determination | Manipulation | TraceScan |
| Multi-component seed | Entropy quality | TraceScan |

**Specific Checks:**
- [ ] 60-second lock period correctly enforced
- [ ] Seed includes prevrandao + timestamp + block.number + nonce
- [ ] `isDead()` is deterministic and verifiable
- [ ] Nonce prevents replay of seeds
- [ ] Position cannot be modified during lock period

### 4.5 Oracle/Price Dependencies

**Priority: MEDIUM**

| Dependency | Concern | Contract |
|------------|---------|----------|
| Network modifier thresholds | Manipulation | GhostCore |
| DEX integration (buyback) | Price manipulation | FeeRouter |

**Note:** GHOSTNET intentionally minimizes oracle dependencies. Network modifier uses DATA-based thresholds set by admin, not external price feeds.

### 4.6 Token Economics

**Priority: HIGH**

| Mechanism | Concern | Contract |
|-----------|---------|----------|
| Transfer tax | Exclusion bypass | DataToken |
| Burn mechanism | Inflation | DataToken |
| Emission schedule | Drain | RewardsDistributor |
| Cascade distribution | Leakage | GhostCore |
| System reset penalty | Extraction before reset | GhostCore |

**Specific Checks:**
- [ ] Tax exclusions cannot be abused
- [ ] Burn address (`0xdead`) is correct
- [ ] Emissions cannot exceed 60M total
- [ ] Dead capital is fully redistributed (no stuck funds)
- [ ] Reset penalty applied atomically (no front-running)

### 4.7 Upgrade Safety

**Priority: HIGH**

| Aspect | Concern | Contract |
|--------|---------|----------|
| Storage layout | Slot collision | All UUPS |
| Initializer | Re-initialization | All UUPS |
| Upgrade path | State migration | All UUPS |
| ERC-7201 compliance | Namespaced storage | GhostCore, TraceScan |

**Specific Checks:**
- [ ] `_disableInitializers()` in constructor
- [ ] Storage follows ERC-7201 namespaced pattern
- [ ] No storage slot collisions between versions
- [ ] `_authorizeUpgrade()` properly restricted
- [ ] Implementation cannot be initialized directly

### 4.8 EIP-712 Signature Security

**Priority: HIGH**

| Aspect | Concern | Contract |
|--------|---------|----------|
| Domain separator | Cross-chain replay | GhostCore |
| Nonce management | Replay attacks | GhostCore |
| Signature recovery | Malleability | GhostCore |
| Expiry enforcement | Stale signatures | GhostCore |

**Specific Checks:**
- [ ] DOMAIN_SEPARATOR includes chainId and verifyingContract
- [ ] Nonces are marked used before processing (CEI pattern)
- [ ] ECDSA.tryRecover from OpenZeppelin 5.x used with error handling
- [ ] Signature cannot be reused after expiry
- [ ] Boost signer address properly managed

**Cross-Chain Replay Protection:**

| Check | Status |
|-------|--------|
| DOMAIN_SEPARATOR computed at deployment with `block.chainid` | [ ] |
| Testnet (6343) and mainnet (4326) use different chain IDs | [ ] |
| No signature created on testnet can be valid on mainnet | [ ] |
| For upgradeable contracts, domain separator handled correctly across upgrades | [ ] |

**Chain Fork Consideration:**
If MegaETH forks, cached DOMAIN_SEPARATOR becomes invalid. Verify handling:
- Option A: Compute fresh each time (~200 gas)
- Option B: Cache and verify against `block.chainid`, revert if changed

### 4.9 Denial of Service

**Priority: MEDIUM**

| Vector | Concern | Contract |
|--------|---------|----------|
| Gas griefing | Block gas limit | TraceScan (batch size) |
| State bloat | Storage exhaustion | GhostCore (positions) |
| Keeper failure | Scan delays | TraceScan |
| System reset | Mass withdrawal | GhostCore |

**Specific Checks:**
- [ ] Batch sizes are bounded (`MAX_BATCH_SIZE = 100`)
- [ ] Position enumeration is bounded
- [ ] System reset events-only loop is gas-bounded
- [ ] Anyone can execute scans (no single point of failure)

### 4.9.1 Epoch-Based Storage Cleanup (TraceScan)

**Priority: MEDIUM**

The `processedInScan` mapping uses an epoch-based pattern to avoid O(n) gas costs for clearing stale entries.

| Check | Status |
|-------|--------|
| `processedInScan` uses 3-level mapping: `level => scanId => user => bool` | [ ] |
| Each `Scan` struct contains unique `scanId` from incrementing `scanNonce` | [ ] |
| `submitDeaths()` uses current `scan.scanId` for lookup, not just level | [ ] |
| No explicit deletion of old `processedInScan` entries in `finalizeScan()` | [ ] |
| Old scan entries become unreachable (not accessed after finalization) | [ ] |

**Invariants:**
- [ ] A user can only be marked as processed once per scan (per scanId)
- [ ] The same user can be processed in different scans (different scanIds)
- [ ] `scanNonce` always increments (never resets)
- [ ] Gas cost of `finalizeScan()` is O(1), not O(n)

**Storage Growth Analysis:**
- [ ] Document expected storage growth rate based on anticipated scan frequency
- [ ] Verify growth is bounded by protocol activity, not accumulated over time
- [ ] Confirm MegaETH storage costs are acceptable for projected growth

### 4.10 Economic Attacks

**Priority: HIGH**

| Attack | Mechanism | Contract |
|--------|-----------|----------|
| Flash loan manipulation | Inflate stake → extract | GhostCore |
| Sandwich attacks | Front-run scans | TraceScan |
| Griefing resets | Trigger reset maliciously | GhostCore |
| Pool manipulation | Drain Dead Pool | DeadPool |

**Specific Checks:**
- [ ] Lock period prevents scan front-running
- [ ] System reset requires genuine inactivity
- [ ] Dead Pool rake prevents profitable manipulation
- [ ] Flash loan + extract in same block not profitable

### 4.11 Culling Mechanism (Level Capacity Enforcement)

**Priority: HIGH**

When a level reaches maximum capacity (`maxPositions`), new entrants trigger "The Culling"—a weighted random elimination from the bottom X% of positions by stake size.

| Aspect | Concern | Contract |
|--------|---------|----------|
| Eligibility calculation | Bottom X% accuracy | GhostCore |
| Weighted selection | Fairness of random choice | GhostCore |
| Penalty distribution | Cascade correctness | GhostCore, CascadeLib |
| Gas bounds | Culling within block limits | GhostCore |
| Gaming resistance | Cannot manipulate eligibility | GhostCore |

**Specific Checks:**
- [ ] `_getEligibleForCulling()` correctly identifies bottom X% by stake size
- [ ] Weighted random selection gives lower stakes proportionally higher chance
- [ ] Victim cannot be the new entrant (new entrant triggers but is immune)
- [ ] `prevrandao` used correctly for randomness (same pattern as TraceScan)
- [ ] Culling penalty (default 80%) cascades correctly like death penalty
- [ ] Victim receives remaining portion (default 20%) correctly
- [ ] `getCullingRisk()` view function returns accurate probability
- [ ] Admin `setCullingParams()` properly restricted and validated
- [ ] Gas cost bounded: culling single victim is O(1) after eligibility computed
- [ ] Cannot game stake size to avoid bottom X% (no last-second additions)
- [ ] Lock period applies: cannot add stake during lock to escape culling
- [ ] `PositionCulled` event emits correct data for indexing

**Edge Cases:**
- [ ] Level at capacity but no eligible positions (all equal stake) → handled gracefully
- [ ] Culling with only 1 eligible position → deterministic selection
- [ ] Multiple cullings in quick succession → no reentrancy issues
- [ ] Culling when victim has pending rewards → rewards handled correctly

**Economic Invariants:**
- [ ] Total capital before culling == total capital after (distributed correctly)
- [ ] Culling penalty + victim refund + burn + protocol == original victim stake
- [ ] No dust accumulation in culling calculations

---

## 5. Known Issues & Design Decisions

### 5.1 Accepted Risks

| Issue | Decision | Rationale |
|-------|----------|-----------|
| prevrandao predictability | Accept with 60s lock | MegaETH-specific; lock period mitigates |
| Sequencer manipulation | Accept | Sequencer reputation >> GHOSTNET value |
| Admin key risk | Mitigate with timelock + multisig | Standard practice |
| Single position per user | Design choice | Simplifies logic, tax friction deters gaming |

### 5.2 Design Decisions to Review

| Decision | Context |
|----------|---------|
| Lazy reset penalty settlement | Gas optimization; verify consistency |
| Events-only for reset notifications | Verify indexer can reconstruct state |
| Trustless death verification | Verify anyone can submit proofs |
| Share-based reward accounting | Verify precision is sufficient |

---

## 6. Testing Requirements

### 6.1 Unit Tests

| Category | Coverage Target | Current |
|----------|-----------------|---------|
| Happy path | 100% | [TBD]% |
| Edge cases | 90%+ | [TBD]% |
| Revert conditions | 100% | [TBD]% |
| Access control | 100% | [TBD]% |
| Math operations | 100% | [TBD]% |

### 6.2 Integration Tests

| Scenario | Priority |
|----------|----------|
| Full game cycle (jack in → scan → extract) | Critical |
| System reset with multiple positions | Critical |
| Cascade distribution across levels | Critical |
| Boost application and expiry | High |
| Upgrade with active positions | High |
| Emergency pause and withdraw | High |

### 6.3 Invariant Tests (Foundry)

| Invariant | Contract |
|-----------|----------|
| Total staked == sum of all position amounts | GhostCore |
| aliveCount == count of positions where alive==true | GhostCore |
| accRewardsPerShare never decreases | GhostCore |
| totalDistributed <= TOTAL_EMISSIONS | RewardsDistributor |
| Dead position amount == 0 (after claim) | GhostCore |
| System reset deadline >= block.timestamp OR reset triggered | GhostCore |

### 6.4 Fuzz Tests

| Function | Fuzz Parameters |
|----------|-----------------|
| `jackIn()` | amount (0 to 10^24), level (0-255) |
| `isDead()` | seed (uint256), deathRate (0-10000) |
| `_distributeCascade()` | totalDeadCapital (0 to TVL) |
| Tax calculation | amount (0 to total supply) |

### 6.5 Formal Verification (Optional)

| Property | Tool |
|----------|------|
| No reentrancy | Certora / Halmos |
| Funds conservation | Certora |
| Access control correctness | Certora |

---

## 7. Documentation Available

### Architecture Documents

| Document | Path |
|----------|------|
| Smart Contracts Plan | `docs/architecture/smart-contracts-plan.md` |
| Contract Specifications | `docs/architecture/contract-specifications.md` |
| Frontend Architecture | `docs/architecture/frontend-architecture.md` |
| Backend Architecture | `docs/architecture/backend-architecture.md` |
| Emergency Procedures | `docs/architecture/emergency-procedures.md` |
| MegaETH Networks | `docs/architecture/megaeth-networks.md` |

### Product Documents

| Document | Path |
|----------|------|
| Product Brief | `docs/product/PRODUCT-BRIEF.md` |
| Game Mechanics | `docs/product/` |
| Tokenomics | `docs/product/` |

### Technical Notes

| Document | Path |
|----------|------|
| prevrandao Verification | `docs/lessons/001-prevrandao-megaeth.md` |
| prevrandao Plan | `docs/architecture/prevrandao-verification-plan.md` |

---

## 8. Audit Deliverables

### Expected from Auditor

1. **Audit Report** containing:
   - Executive summary
   - Methodology description
   - Findings with severity ratings
   - Recommendations for each finding
   - Code quality observations
   - Gas optimization suggestions

2. **Severity Classification:**
   - **Critical:** Direct loss of funds or permanent DoS
   - **High:** Conditional loss of funds or significant impact
   - **Medium:** Limited impact or unlikely conditions
   - **Low:** Best practices, gas optimizations
   - **Informational:** Code quality, documentation

3. **Verification:**
   - Confirmation that all Critical/High findings are addressed
   - Re-review of fixed code
   - Final report after fixes

### Expected from GHOSTNET Team

1. **Pre-Audit:**
   - [ ] All contracts finalized (feature freeze)
   - [ ] Test suite passing with >90% coverage
   - [ ] Documentation complete
   - [ ] Deployment scripts tested on testnet
   - [ ] Known issues documented

2. **During Audit:**
   - [ ] Dedicated point of contact available
   - [ ] Response to questions within 24 hours
   - [ ] Access to private repo if needed

3. **Post-Audit:**
   - [ ] Address all Critical/High findings
   - [ ] Document rationale for any unaddressed findings
   - [ ] Submit fixes for re-review
   - [ ] Publish audit report publicly

---

## 9. Timeline & Coordination

### Pre-Audit Checklist

```
[ ] Code freeze - no new features
[ ] All tests passing
[ ] Documentation finalized
[ ] Testnet deployment successful
[ ] Internal security review complete
[ ] Known issues documented
[ ] Audit firm selected and contracted
```

### Audit Timeline (Estimated)

| Phase | Duration | Status |
|-------|----------|--------|
| Code freeze | 1 week | Not started |
| Internal review | 1 week | Not started |
| Audit engagement | 2-3 weeks | Not started |
| Fix period | 1 week | Not started |
| Re-review | 3-5 days | Not started |
| Final report | 3 days | Not started |

### Communication

| Channel | Purpose |
|---------|---------|
| Shared Slack/Discord | Daily communication |
| Weekly calls | Progress updates |
| Email | Formal deliverables |
| GitHub Issues | Finding tracking |

---

## Appendix: Contract Interfaces Summary

### GhostCore.sol - Key Functions

```solidity
// User functions
function jackIn(uint256 amount, uint8 level) external;
function extract() external;
function claimRewards() external;
function emergencyWithdraw() external; // When paused
function applyBoost(uint8 boostType, uint16 valueBps, uint64 expiry, bytes32 nonce, bytes signature) external;

// Scanner functions (SCANNER_ROLE)
function processDeaths(uint8 level, address[] deadUsers, uint256 totalDeadCapital) external;
function incrementGhostStreak(uint8 level, address[] survivors) external;
function updateNextScanTime(uint8 level) external;

// Distributor functions (DISTRIBUTOR_ROLE)
function addEmissionRewards(uint8 level, uint256 amount) external;

// Admin functions (DEFAULT_ADMIN_ROLE)
function pause() external;
function unpause() external;
function setBoostSigner(address signer) external;
function updateLevelConfig(uint8 level, LevelConfig config) external;

// Anyone
function triggerSystemReset() external;
```

### TraceScan.sol - Key Functions

```solidity
// Anyone can call
function executeScan(uint8 level) external;
function submitDeaths(uint8 level, address[] deadUsers) external;
function finalizeScan(uint8 level) external;

// Keeper interface
function checker() external view returns (bool canExec, bytes execPayload);

// View
function isDead(uint256 seed, address user, uint16 deathRateBps) external pure returns (bool);
function canExecuteScan(uint8 level) external view returns (bool);
function canFinalizeScan(uint8 level) external view returns (bool);
function wouldDie(address user) external view returns (bool);
```

### DataToken.sol - Key Functions

```solidity
// Standard ERC20
function transfer(address to, uint256 amount) external returns (bool);
function transferFrom(address from, address to, uint256 amount) external returns (bool);
function approve(address spender, uint256 amount) external returns (bool);
function burn(uint256 amount) external;

// Admin (owner)
function setTaxExclusion(address account, bool excluded) external;
function setTreasury(address newTreasury) external;
```

---

*This document should be shared with the selected audit firm and updated based on their feedback.*
