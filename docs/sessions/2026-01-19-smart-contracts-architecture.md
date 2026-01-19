# Session: Smart Contracts Architecture Planning

**Date:** 2026-01-19  
**Focus:** GHOSTNET smart contract architecture and randomness strategy  
**Status:** Architecture finalized, ready for implementation

---

## Summary

Completed architecture planning for GHOSTNET smart contracts. Key decisions:

1. **Randomness:** Use block-based (`prevrandao`) with 60-second pre-scan lock period
2. **Token:** Immutable ERC20 with 10% transfer tax (9% burn, 1% treasury)
3. **Game Logic:** UUPS upgradeable with 48-hour timelock
4. **Rewards:** Share-based accounting (MasterChef pattern) for O(1) gas
5. **Position Model:** Single upgradeable position per user (can add stake, cannot change level)
6. **Death Processing:** Trustless batch verification (on-chain verifiable, no off-chain trust)
7. **Cascade Split:** 30/30/30/10 absolute (same-level/upstream/burn/protocol)
8. **Yield Sources:** Emissions (The Mine) + Cascade (deaths) both contribute to rewards

The prevrandao approach was verified on MegaETH testnet. Finding: `prevrandao` stays constant for ~60 seconds, which is acceptable with the lock period mitigation.

---

## Decisions Made

### 1. Randomness Strategy: Block-Based (prevrandao) + Lock Period

**Decision:** Use `block.prevrandao` for trace scan death selection with a 60-second pre-scan lock period.

**Initial Rationale:**
- Gelato VRF is NOT on-chain verifiable (BLS12-381 proofs require EIP-2537)
- Both options require trusting a reputable third party (sequencer vs Gelato operator)
- Block-based provides: zero latency, zero cost, no external dependencies
- VRF adds: ~1500ms latency, per-request costs, external dependency

**MegaETH Verification Finding (January 2026):**
- Deployed test contract: `0x332E2bbADdF7cC449601Ea9aA9d0AB8CfBe60E08`
- **Finding:** `prevrandao` stays CONSTANT for ~60 seconds across 50+ blocks on MegaETH
- This differs from Ethereum mainnet where prevrandao changes every block

**Re-Analysis Conclusion:**
Despite constant prevrandao, this is ACCEPTABLE for GHOSTNET because:
1. **You can't change your fate** - only observe it early (address determines death)
2. **Front-running costs 19%** - extract (10% tax) + re-enter (10% tax) burns tokens
3. **Lock period eliminates exploit** - can't extract in 60s before scan
4. **Multi-component seed** - timestamp and block number change every second
5. **Fairness preserved** - selection remains uniformly random

**Confidence:** High  
**Revisit if:** Evidence of systematic front-running that damages game experience

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

### 6. Position Model: Single Upgradeable Position

**Decision:** One position per user, can add stake but cannot change level.

**Rationale:**
- Simpler data model: `mapping(address => Position)` instead of array
- Adding stake updates `lastAddTimestamp` (resets lock period calculation)
- To change levels, must extract (10% tax) and re-enter (10% tax) = natural friction
- Tracks `ghostStreak` for achievements and UI

**Position Structure:**
```solidity
struct Position {
    uint256 amount;           // Total staked (can increase)
    uint8   level;            // 1-5 (locked once chosen)
    uint64  entryTimestamp;   // When first jacked in
    uint64  lastAddTimestamp; // When last added stake
    uint256 rewardDebt;       // For share-based accounting
    bool    alive;            // false = traced
    uint16  ghostStreak;      // Consecutive survivals
}
```

**Confidence:** High

### 7. Cascade Split: 30/30/30/10 (Absolute)

**Decision:** Cascade distributes dead capital in absolute percentages:
- 30% → Same-level survivors (proportional to stake)
- 30% → Upstream levels (by TVL weight)
- 30% → Burned (permanent supply reduction)
- 10% → Protocol treasury

**Clarification:** The "60% rewards" from product spec is same-level (30%) + upstream (30%). These are absolute percentages of dead capital, not nested percentages.

**Implementation Constants:**
```solidity
uint16 constant CASCADE_SAME_LEVEL = 3000;  // 30%
uint16 constant CASCADE_UPSTREAM   = 3000;  // 30%
uint16 constant CASCADE_BURN       = 3000;  // 30%
uint16 constant CASCADE_PROTOCOL   = 1000;  // 10%
```

**Edge Case - VAULT deaths:** When Level 1 (VAULT) players die, there's no upstream. The upstream 30% goes to same-level survivors instead (total 60% to VAULT survivors).

**Rationale:**
- Matches product specification in master-design.md
- Creates "degens feed whales" dynamic (upstream flow)
- Same-level rewards create within-level competition
- Upstream flow creates the "reverse pyramid" yield structure

**Confidence:** High

### 8. System Reset Jackpot: Include in V1

**Decision:** Implement full system reset mechanics including jackpot.

**Mechanics:**
- Global countdown timer, extended by deposits (based on amount)
- If timer hits zero: 25% penalty to ALL positions
- Penalty distribution: 50% to last depositor (jackpot), 30% burned, 20% protocol
- Creates urgency and "last-second hero" content moments

**Confidence:** Medium (complexity, but important for game dynamics)

### 9. Death Processing: Trustless Batch Verification

**Decision:** On-chain deterministic death with batch proof submission.

**The Problem:**
- Iterating thousands of positions in one transaction exceeds gas limits
- Off-chain computation with trusted keeper is undesirable

**The Solution:**
```
STEP 1: Scan Execution (O(1))
├── Store seed = keccak256(prevrandao, timestamp, level, nonce)
├── Deaths NOT processed yet, just seed locked
└── Emit ScanExecuted(level, seed)

STEP 2: Death Proof Submission (Batched)
├── Anyone calls: submitDeaths(address[] deadUsers)
├── Contract VERIFIES each: isDead(seed, user) == true
├── Invalid proofs revert (can't lie)
└── Accumulates deaths for cascade

STEP 3: Cascade Finalization
├── After submission window (~60-120 seconds)
├── Distributes via accRewardsPerShare
└── Burns 30%, treasury 10%
```

**Key Properties:**
- Trustless: Contract verifies each death mathematically
- Permissionless: Anyone can submit death proofs
- Scalable: Batch 100 deaths per tx (~2.5M gas)
- Fallback: Self-check on user interaction if keeper slow

**Confidence:** High

### 10. Network Modifier: DATA-Based Thresholds

**Decision:** Use total staked DATA (not USD) for network modifier calculation.

**Rationale:**
- No oracle dependency
- Simpler implementation
- Configurable via admin setter function

**Default Thresholds:**
```
Total Staked < 1M DATA:     networkMod = 1.2 (early = dangerous)
Total Staked 1M - 5M:       networkMod = 1.0 (normal)
Total Staked 5M - 10M:      networkMod = 0.9 (getting safer)
Total Staked > 10M:         networkMod = 0.85 (network strength)
```

**Confidence:** High

### 11. Yield Sources: Emissions + Cascade

**Decision:** Two separate yield sources, both additive to `accRewardsPerShare`.

**Source 1: The Mine (Emissions)**
- Pool: 60,000,000 DATA (60% of supply)
- Duration: 24 months (~82,000 DATA/day)
- Distribution by level: 5%/10%/20%/30%/35% (Vault→Black Ice)
- Purpose: BASE yield, predictable

**Source 2: The Cascade (Deaths)**
- Pool: 60% of dead capital per scan
- Distribution: 30% same-level, 30% upstream
- Purpose: BONUS yield, PvP dynamics

**Implementation:**
- `RewardsDistributor` drips emissions to GhostCore
- `GhostCore.processDeaths()` adds cascade rewards
- Both update `accRewardsPerShare` for relevant levels
- Users claim combined rewards on extract

**APY Composition (DARKNET example at 100k DATA staked):**
- Emission yield: ~9,000% APY
- Cascade yield: ~800-1,000% APY (variable)
- Total: ~10,000-20,000% APY (matches product spec)

**Confidence:** High

---

## Assumptions Made

| Assumption | Basis | Verification Needed |
|------------|-------|---------------------|
| `prevrandao` returns usable randomness on MegaETH | EVM compatibility claim | **VERIFIED** - constant for ~60s, acceptable with lock |
| MegaETH sequencer won't manipulate randomness | Reputation economics | No - accepted risk |
| 60-second lock period sufficient to prevent front-running | Analysis of prediction window | No - matches prevrandao constant period |
| Gelato Automate available on MegaETH | Listed as partner | Yes - before mainnet |
| Batch death verification (~100 per tx) within gas limits | ~2.5M gas estimate | Yes - test on testnet |
| 120-second death submission window sufficient | Keeper reliability assumption | Yes - monitor in production |
| Single position per user sufficient for UX | Simplification decision | Revisit if users request multiple |
| DATA-based network modifier adequate (no USD oracle) | Simplicity over precision | No - accepted tradeoff |
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

### Completed

1. ~~**Run prevrandao verification**~~ ✅
   - Deployed PrevRandaoTest to MegaETH testnet: `0x332E2bbADdF7cC449601Ea9aA9d0AB8CfBe60E08`
   - Found: prevrandao constant for ~60 seconds
   - Decision: **PROCEED** with prevrandao + 60-second lock period

2. ~~**Design refinement review**~~ ✅
   - Reviewed all product docs against architecture
   - Resolved position model (single per user)
   - Resolved cascade split (30/30)
   - Designed trustless batch death processing
   - Clarified emissions vs cascade yield sources

### In Progress

3. **Phase 1: Foundation** (Week 1-2)
   - Implement DataToken.sol (ERC20 + 10% tax)
   - Implement TeamVesting.sol
   - Basic GhostCore.sol (single position, jackIn/extract, lock period)
   - Unit tests

### Upcoming

4. **Phase 2: Core Game** (Week 3-4)
   - TraceScan.sol with trustless batch death verification
   - Complete GhostCore.sol with cascade (30/30 split)
   - System reset timer with jackpot mechanics
   - RewardsDistributor.sol (emissions from The Mine)
   - Gelato Automate integration for keeper

5. **Phase 3: Prediction Market** (Week 5)
   - DeadPool.sol parimutuel betting
   - Integration with TraceScan outcomes

6. **Phase 4: Periphery & Security** (Week 6-8)
   - FeeRouter.sol (ETH toll + buyback)
   - ConsumablesShop.sol
   - Governance setup
   - Security review and testing

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

Always use `--skip-simulation --gas-limit 10000000` when deploying/broadcasting to MegaETH.

### MegaETH Testnet RPC Update

From `docs/MegaETH_Testnet.md`:
> RPC URL changed from `timothy.megaeth.com` to `carrot.megaeth.com`

Current testnet RPC: `https://carrot.megaeth.com/rpc`

### MegaETH Network Clarification

Verified network status (January 2026):

| Network | Chain ID | Status | RPC |
|---------|----------|--------|-----|
| Testnet V2 | 6343 | Public, free faucets | `carrot.megaeth.com/rpc` |
| Mainnet (Frontier) | 4326 | Live but whitelisted, requires bridged ETH | `megaeth-mainnet.g.alchemy.com` |

**Decision:** Default to testnet for all development and testing. Mainnet requires bridging real ETH from Ethereum L1.

**Testnet wallet created:**
- Address: `0xAeB643a650E374D8D62a8A3D9e5B175ecd8090D1`
- Private key: Saved in `packages/contracts/.env`
- Status: Needs faucet ETH

---

*Session logged for project continuity.*
