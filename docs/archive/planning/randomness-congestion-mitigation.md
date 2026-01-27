# Randomness Congestion Mitigation System

**Document Version:** 1.0  
**Created:** 2026-01-21  
**Status:** DESIGN COMPLETE  
**Issue:** High Priority #5 from Architecture Review

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Analysis](#2-problem-analysis)
3. [Architecture Decision Records](#3-architecture-decision-records)
4. [Keeper Incentive System](#4-keeper-incentive-system)
5. [Graceful Degradation Design](#5-graceful-degradation-design)
6. [Monitoring & Alerting Specification](#6-monitoring--alerting-specification)
7. [Solidity Implementation](#7-solidity-implementation)
8. [Keeper Bot Specification](#8-keeper-bot-specification)
9. [Operational Runbook](#9-operational-runbook)
10. [Risk Analysis](#10-risk-analysis)

---

## 1. Executive Summary

### The Problem

The arcade randomness system uses future block hashes with a 256-block window (25.6 seconds on MegaETH's 100ms blocks). During network congestion, transaction delays can exceed this window, causing seed expiry and forced refunds.

| Scenario | Delay | Risk |
|----------|-------|------|
| Normal | 1-2s | Safe |
| Moderate congestion | 10s | Safe |
| Heavy congestion | 15s | Safe |
| Severe congestion | 20s+ | **Seed may expire** |

**Current mitigations:**
- EIP-2935 extends window to ~13.6 minutes IF available
- Refunds protect player funds on expiry

**Gaps identified:**
1. No keeper incentives for proactive seed reveals
2. No graceful degradation during congestion
3. No monitoring/alerting specification
4. MegaETH congestion patterns unknown

### The Solution

A comprehensive reliability system with four layers:

```
                    RANDOMNESS RELIABILITY STACK
    _______________________________________________________________
   |                                                               |
   |  Layer 4: MONITORING & ALERTING                              |
   |  - Real-time health metrics                                   |
   |  - Predictive congestion alerts                               |
   |  - Automatic escalation procedures                            |
   |_______________________________________________________________|
   |                                                               |
   |  Layer 3: GRACEFUL DEGRADATION                               |
   |  - Congestion detection                                       |
   |  - Adaptive delays                                            |
   |  - Auto-pause on severe conditions                            |
   |_______________________________________________________________|
   |                                                               |
   |  Layer 2: KEEPER INCENTIVES                                  |
   |  - Gas reimbursement bounty                                   |
   |  - Priority reveal rewards                                    |
   |  - Multi-keeper redundancy                                    |
   |_______________________________________________________________|
   |                                                               |
   |  Layer 1: CORE RANDOMNESS (Existing)                         |
   |  - Future block hash pattern                                  |
   |  - EIP-2935 extended history                                  |
   |  - Refunds as ultimate fallback                               |
   |_______________________________________________________________|
```

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Keeper rewards | Gas + bonus from session rake | Self-sustaining, no treasury drain |
| Degradation trigger | Block-based congestion detection | Objective, manipulation-resistant |
| Alert system | Off-chain monitoring | Flexible, no gas overhead |
| Pause authority | Automatic + manual override | Balance safety with uptime |

---

## 2. Problem Analysis

### 2.1 MegaETH Timing Model

```
MegaETH Block Timeline (100ms blocks):

Block 0    Block 50   Block 256   Block 8191
   |          |          |           |
   v          v          v           v
[Commit] --> [Ready] --> [Native] --> [EIP-2935]
   |          |       Deadline    Deadline
   |          |          |           |
   +-- 5s ----+-- 20.6s -+--- 13.1m--+
```

**Critical timing windows:**

| Window | Blocks | Time | Purpose |
|--------|--------|------|---------|
| Seed delay | 50 | 5s | Ensure unpredictability |
| Native reveal | 206 | 20.6s | Standard blockhash() |
| Extended reveal | 8141 | 13.6m | EIP-2935 fallback |

### 2.2 Congestion Scenarios

**Scenario A: Normal Operation**
```
Block 1000: Betting closes, seed committed for block 1050
Block 1050: Seed ready, keeper calls reveal within 2s
Block 1052: Seed revealed successfully
Result: SUCCESS
```

**Scenario B: Moderate Congestion**
```
Block 1000: Betting closes, seed committed for block 1050
Block 1050: Seed ready
Block 1100: Keeper tx finally included (5s delay)
Result: SUCCESS (within 206 block window)
```

**Scenario C: Severe Congestion (Native Window)**
```
Block 1000: Betting closes, seed committed for block 1050
Block 1050: Seed ready
Block 1256+: Native window expired, EIP-2935 attempt
Result: SUCCESS if EIP-2935 available, REFUND if not
```

**Scenario D: Catastrophic (All Windows Expired)**
```
Block 1000: Betting closes, seed committed for block 1050
Block 9191+: All windows expired
Result: REFUND - seed cannot be recovered
```

### 2.3 Failure Mode Analysis

| Failure Mode | Probability | Impact | Current Mitigation |
|--------------|-------------|--------|-------------------|
| Keeper offline | Medium | Session delayed | None (gap) |
| Network congestion | Low-Medium | Potential expiry | EIP-2935 |
| EIP-2935 unavailable | Unknown | Shorter window | Refund |
| All keepers fail | Low | Multiple expirations | Refund |
| Chain reorg at seed block | Very Low | Outcome changes | Accept (rare) |

---

## 3. Architecture Decision Records

### ADR-001: Keeper Incentive Mechanism

**Status:** ACCEPTED

**Context:**
The current design relies on protocol-operated keepers to call `revealSeed()`. This creates a single point of failure and no economic incentive for third parties to provide redundancy.

**Decision:**
Implement a **gas reimbursement + bonus** model where:
1. Successful revealers receive gas cost reimbursement (up to 200% of actual gas)
2. Additional bonus from session rake (0.5% of session pot)
3. No reward if seed already revealed

**Options Considered:**

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| **No reward** | Simple | Single point of failure | Rejected |
| **Gas reimbursement only** | Low cost | May not attract keepers | Rejected |
| **Fixed bounty from treasury** | Reliable | Drains treasury, needs refill | Rejected |
| **Percentage of rake** | Self-sustaining, scales with activity | Complex accounting | Rejected |
| **Gas + rake bonus** | Self-sustaining, attractive, redundancy | Moderate complexity | **ACCEPTED** |

**Economic Analysis:**

```
Example: 10,000 DATA session pot, 3% rake
- Rake amount: 300 DATA
- Keeper bonus (0.5% of pot): 50 DATA
- Gas reimbursement (estimate): 0.001 ETH worth
- Net rake to protocol: 249.9 DATA

Keeper profitability:
- Gas cost: ~50,000 gas @ 0.01 gwei = 0.0005 ETH
- Reimbursement: 0.001 ETH (200% coverage)
- Bonus: 50 DATA (~$5 at $0.10/DATA)
- Net profit: ~$5.05 per reveal

With 1000 sessions/day: ~$5,050/day keeper revenue
```

**Consequences:**
- (+) Multiple keepers compete for bounties, improving reliability
- (+) Self-sustaining economics, no treasury dependency
- (+) Scales naturally with protocol activity
- (-) Slightly reduced protocol revenue (0.5% of pot)
- (-) Requires gas price oracle for ETH->DATA conversion

---

### ADR-002: Congestion Detection Method

**Status:** ACCEPTED

**Context:**
Need to detect network congestion to trigger graceful degradation. Options include timestamp-based, block-based, and oracle-based detection.

**Decision:**
Use **block-based congestion detection** with a sliding window:
- Track blocks since last reveal
- If reveals consistently take longer than expected, increase SEED_BLOCK_DELAY
- Detection is fully on-chain, no oracle dependency

**Options Considered:**

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| **Timestamp delays** | Simple | Manipulable by sequencer | Rejected |
| **External oracle** | Accurate | Dependency, cost, trust | Rejected |
| **Block-based sliding window** | On-chain, objective | Delayed reaction | **ACCEPTED** |
| **Gas price threshold** | Direct congestion signal | Not always correlated | Rejected |

**Detection Algorithm:**

```solidity
// Track last N reveal delays
uint256[10] public recentRevealDelays; // blocks between ready and revealed
uint256 public revealDelayIndex;

// Congestion thresholds
uint256 public constant NORMAL_DELAY = 30;      // ~3 seconds
uint256 public constant ELEVATED_DELAY = 100;   // ~10 seconds
uint256 public constant SEVERE_DELAY = 150;     // ~15 seconds

function getCongestionLevel() public view returns (CongestionLevel) {
    uint256 avgDelay = _averageDelay();
    if (avgDelay >= SEVERE_DELAY) return CongestionLevel.SEVERE;
    if (avgDelay >= ELEVATED_DELAY) return CongestionLevel.ELEVATED;
    return CongestionLevel.NORMAL;
}
```

**Consequences:**
- (+) No external dependencies
- (+) Cannot be gamed without sustained congestion
- (+) Objective, verifiable on-chain
- (-) Reacts to congestion, doesn't predict it
- (-) Short spikes may not trigger adaptation

---

### ADR-003: Graceful Degradation Strategy

**Status:** ACCEPTED

**Context:**
When congestion is detected, the system should adapt rather than simply fail. Need to define what adaptations are safe and effective.

**Decision:**
Implement a **tiered degradation model**:

| Level | Trigger | Actions |
|-------|---------|---------|
| NORMAL | avgDelay < 30 blocks | Standard operation |
| ELEVATED | avgDelay 30-100 blocks | Extend SEED_BLOCK_DELAY to 100, emit warning |
| SEVERE | avgDelay > 100 blocks | Auto-pause new sessions, keeper alerts |
| CRITICAL | EIP-2935 unavailable + SEVERE | Emergency pause all games |

**Key Constraints:**
- SEED_BLOCK_DELAY must never exceed `MAX_BLOCK_AGE / 2` (128 blocks)
- Auto-pause is recoverable by admin
- Existing sessions always allowed to complete (no mid-game interruption)

**Consequences:**
- (+) System remains operational under moderate stress
- (+) Automatic protection against severe conditions
- (+) Admin can override if detection is wrong
- (-) Increased complexity
- (-) Potential for false positives during recovery from congestion

---

### ADR-004: Monitoring Architecture

**Status:** ACCEPTED

**Context:**
On-chain monitoring adds gas overhead. Off-chain monitoring adds operational complexity. Need to balance observability with efficiency.

**Decision:**
**Off-chain monitoring** with on-chain events:
- All critical state changes emit events
- Off-chain indexer processes events in real-time
- Alerting system triggers on threshold breaches
- Dashboard displays health metrics

**Event Coverage:**

| Event | Monitors |
|-------|----------|
| `SeedCommitted` | Session starts, deadline tracking |
| `SeedRevealed` | Success, latency measurement |
| `SeedExpired` | Failure, requires investigation |
| `CongestionLevelChanged` | Degradation state |
| `KeeperRewarded` | Keeper economics |

**Consequences:**
- (+) No gas overhead for monitoring
- (+) Flexible alerting logic
- (+) Can add metrics without contract changes
- (-) Requires reliable indexer infrastructure
- (-) Slight delay in detection vs on-chain checks

---

## 4. Keeper Incentive System

### 4.1 Reward Structure

```
                     KEEPER REWARD FLOW
    _______________________________________________________________
   |                                                               |
   |  SESSION POT: 10,000 DATA                                    |
   |     |                                                         |
   |     +---> Rake (3%): 300 DATA                                |
   |              |                                                |
   |              +---> Keeper Bonus (0.5% of pot): 50 DATA       |
   |              |                                                |
   |              +---> Protocol Revenue: 250 DATA                |
   |                                                               |
   |  GAS REIMBURSEMENT (separate):                               |
   |     - Actual gas cost in ETH                                  |
   |     - Converted to DATA at oracle rate                        |
   |     - Multiplier: 200% (covers overhead + profit)            |
   |     - Max cap: 500 DATA per reveal                           |
   |_______________________________________________________________|
```

### 4.2 Reward Calculation

```solidity
struct KeeperReward {
    uint256 gasReimbursement;  // DATA equivalent of gas spent
    uint256 bonusFromRake;     // 0.5% of session pot
    uint256 totalReward;       // Sum of above
}

function calculateKeeperReward(
    uint256 gasUsed,
    uint256 gasPrice,
    uint256 sessionPot,
    uint256 ethDataPrice  // DATA per ETH (from oracle)
) internal pure returns (KeeperReward memory) {
    // Gas reimbursement: 200% of actual cost, converted to DATA
    uint256 gasCostWei = gasUsed * gasPrice;
    uint256 gasCostData = (gasCostWei * ethDataPrice) / 1e18;
    uint256 gasReimbursement = gasCostData * 2; // 200%
    
    // Cap gas reimbursement
    if (gasReimbursement > MAX_GAS_REIMBURSEMENT) {
        gasReimbursement = MAX_GAS_REIMBURSEMENT;
    }
    
    // Bonus: 0.5% of session pot
    uint256 bonusFromRake = (sessionPot * KEEPER_BONUS_BPS) / 10000;
    
    return KeeperReward({
        gasReimbursement: gasReimbursement,
        bonusFromRake: bonusFromRake,
        totalReward: gasReimbursement + bonusFromRake
    });
}
```

### 4.3 Keeper Registry (Optional Enhancement)

For future consideration: a registry allowing anyone to register as a keeper and receive rewards.

```solidity
// Optional: Keeper registry for tracking and analytics
struct KeeperStats {
    uint256 totalReveals;
    uint256 totalRewards;
    uint256 successRate;    // bps
    uint256 avgResponseTime; // blocks
}

mapping(address => KeeperStats) public keeperStats;
address[] public activeKeepers;
```

**Decision:** Not implementing registry in v1. The permissionless `revealSeed()` function already allows anyone to be a keeper. Registry adds complexity without immediate value. Revisit if keeper ecosystem develops.

### 4.4 Anti-Gaming Measures

**Concern:** Keeper could delay reveal to force others to pay higher gas, then snipe.

**Mitigations:**
1. First successful revealer gets reward (race condition favors speed)
2. No partial rewards for failed attempts
3. Sliding window averages smooth out individual variations
4. Large pot sessions attract multiple keepers naturally

**Concern:** Keeper could create sessions just to claim rewards.

**Mitigations:**
1. Minimum session pot requirement (e.g., 100 DATA)
2. Reward is percentage-based, not fixed
3. Entry fees mean net loss for self-dealing

---

## 5. Graceful Degradation Design

### 5.1 Congestion Levels

```solidity
enum CongestionLevel {
    NORMAL,     // Standard operation
    ELEVATED,   // Increased delays, monitoring alert
    SEVERE,     // Auto-pause new sessions
    CRITICAL    // Emergency: all games paused
}

struct CongestionState {
    CongestionLevel level;
    uint256 lastLevelChange;
    uint256 adaptedSeedDelay;     // Current SEED_BLOCK_DELAY
    bool newSessionsPaused;
    bool eip2935Available;
}
```

### 5.2 State Transitions

```
                    CONGESTION STATE MACHINE
    
    +---------+      avgDelay > 30       +-----------+
    | NORMAL  | -----------------------> | ELEVATED  |
    +---------+                          +-----------+
         ^                                    |   |
         |                                    |   |
         | avgDelay < 20                      |   | avgDelay > 100
         | (hysteresis)                       |   |
         |                                    v   v
         |        avgDelay < 50          +---------+
         +-------------------------------| SEVERE  |
                                         +---------+
                                              |
                                              | !eip2935 && SEVERE
                                              v
                                         +----------+
                                         | CRITICAL |
                                         +----------+
                                              |
                                              | Admin reset only
                                              v
                                         +---------+
                                         | NORMAL  |
                                         +---------+
```

### 5.3 Adaptive Parameters

| Parameter | NORMAL | ELEVATED | SEVERE |
|-----------|--------|----------|--------|
| `SEED_BLOCK_DELAY` | 50 | 80 | 100 |
| New sessions allowed | Yes | Yes (warning) | No |
| Existing sessions | Normal | Normal | Complete only |
| Alert level | None | Warning | Critical |

### 5.4 Implementation

```solidity
function _updateCongestionLevel() internal {
    uint256 avgDelay = _calculateAverageDelay();
    CongestionState storage state = congestionState;
    
    CongestionLevel newLevel;
    if (avgDelay >= SEVERE_THRESHOLD) {
        newLevel = CongestionLevel.SEVERE;
    } else if (avgDelay >= ELEVATED_THRESHOLD) {
        newLevel = CongestionLevel.ELEVATED;
    } else if (avgDelay < RECOVERY_THRESHOLD) {
        // Hysteresis: need lower delay to recover
        newLevel = CongestionLevel.NORMAL;
    } else {
        newLevel = state.level; // No change
    }
    
    // Check for CRITICAL (SEVERE + no EIP-2935)
    if (newLevel == CongestionLevel.SEVERE && !state.eip2935Available) {
        newLevel = CongestionLevel.CRITICAL;
    }
    
    if (newLevel != state.level) {
        state.level = newLevel;
        state.lastLevelChange = block.timestamp;
        _adaptParameters(newLevel);
        emit CongestionLevelChanged(newLevel, avgDelay);
    }
}

function _adaptParameters(CongestionLevel level) internal {
    CongestionState storage state = congestionState;
    
    if (level == CongestionLevel.NORMAL) {
        state.adaptedSeedDelay = DEFAULT_SEED_BLOCK_DELAY;
        state.newSessionsPaused = false;
    } else if (level == CongestionLevel.ELEVATED) {
        state.adaptedSeedDelay = ELEVATED_SEED_BLOCK_DELAY;
        state.newSessionsPaused = false;
    } else if (level == CongestionLevel.SEVERE) {
        state.adaptedSeedDelay = SEVERE_SEED_BLOCK_DELAY;
        state.newSessionsPaused = true;
    } else if (level == CongestionLevel.CRITICAL) {
        // Admin must manually handle CRITICAL
        state.newSessionsPaused = true;
        _pauseAllGames();
    }
}
```

---

## 6. Monitoring & Alerting Specification

### 6.1 Event Definitions

```solidity
// Core randomness events (existing)
event SeedCommitted(uint256 indexed roundId, uint256 seedBlock, uint256 deadline);
event SeedRevealed(uint256 indexed roundId, bytes32 blockHash, uint256 seed, bool usedExtendedHistory);
event SeedExpired(uint256 indexed roundId, uint256 seedBlock, uint256 expiredAtBlock);

// Keeper incentive events
event KeeperRewarded(
    address indexed keeper,
    uint256 indexed roundId,
    uint256 gasReimbursement,
    uint256 bonusAmount,
    uint256 totalReward
);

// Congestion events
event CongestionLevelChanged(
    CongestionLevel indexed newLevel,
    uint256 averageDelay
);

event NewSessionsPaused(CongestionLevel reason);
event NewSessionsResumed();

// Health check events
event EIP2935StatusChanged(bool available);
```

### 6.2 Metrics to Track

| Metric | Source | Frequency | Purpose |
|--------|--------|-----------|---------|
| `reveal_latency_blocks` | SeedRevealed - SeedCommitted | Per reveal | Congestion indicator |
| `reveal_latency_p95` | Calculated | Per minute | Alert threshold |
| `expiry_rate` | SeedExpired count | Per hour | Reliability indicator |
| `keeper_rewards_total` | KeeperRewarded sum | Per day | Economics health |
| `active_keepers` | Unique KeeperRewarded addresses | Per day | Redundancy check |
| `eip2935_fallback_rate` | SeedRevealed.usedExtendedHistory | Per hour | Congestion severity |
| `sessions_in_progress` | SeedCommitted - (SeedRevealed + SeedExpired) | Real-time | Exposure metric |
| `congestion_level` | CongestionLevelChanged | Real-time | System state |

### 6.3 Alert Thresholds

| Alert | Condition | Severity | Action |
|-------|-----------|----------|--------|
| **Reveal Latency High** | p95 > 100 blocks | Warning | Monitor closely |
| **Reveal Latency Critical** | p95 > 150 blocks | Critical | Page on-call |
| **Seed Expired** | Any SeedExpired event | Critical | Immediate investigation |
| **Multiple Expirations** | 3+ expirations in 1 hour | SEV-1 | Emergency response |
| **Congestion Elevated** | CongestionLevelChanged to ELEVATED | Warning | Prepare response |
| **Congestion Severe** | CongestionLevelChanged to SEVERE | Critical | Page on-call |
| **Congestion Critical** | CongestionLevelChanged to CRITICAL | SEV-1 | All hands |
| **No Active Keepers** | 0 unique keepers in 24h | Warning | Check keeper bots |
| **EIP-2935 Unavailable** | EIP2935StatusChanged(false) | Warning | Reduced safety margin |
| **High Pending Sessions** | sessions_in_progress > 100 | Warning | Capacity concern |

### 6.4 Dashboard Specification

```
+------------------------------------------------------------------+
|                    RANDOMNESS SYSTEM HEALTH                       |
+------------------------------------------------------------------+
|                                                                   |
|  CONGESTION LEVEL: [NORMAL] [ELEVATED] [SEVERE] [CRITICAL]       |
|  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~     |
|                        ^                                          |
|                     Current                                       |
|                                                                   |
|  EIP-2935: [AVAILABLE]        KEEPERS ACTIVE (24h): 3            |
|                                                                   |
+------------------------------------------------------------------+
|                                                                   |
|  REVEAL LATENCY (blocks)         |  SESSION STATUS               |
|  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~ |
|     200 |                        |                               |
|         |                        |  In Progress:  12             |
|     150 |-------- CRITICAL ------|  Pending Reveal: 3            |
|         |                        |  Revealed (1h): 45            |
|     100 |-------- WARNING -------|  Expired (1h): 0              |
|         |         ____           |                               |
|      50 |    ____/    \___       |  Avg Latency: 42 blocks       |
|         |___/              \_____|  P95 Latency: 78 blocks       |
|       0 +--------------------    |                               |
|         -60m  -30m   now         |                               |
|                                                                   |
+------------------------------------------------------------------+
|                                                                   |
|  KEEPER ECONOMICS (24h)          |  EXPIRY EVENTS (7d)           |
|  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~ |
|  Total Rewards: 2,450 DATA       |  Day 1: 0                     |
|  Avg Reward: 52 DATA             |  Day 2: 0                     |
|  Unique Keepers: 3               |  Day 3: 1 (investigated)      |
|  Reveals: 47                     |  Day 4: 0                     |
|  Gas Reimbursed: 0.24 ETH equiv  |  Day 5: 0                     |
|                                  |  Day 6: 0                     |
|                                  |  Day 7: 0                     |
|                                                                   |
+------------------------------------------------------------------+
```

### 6.5 Escalation Procedures

**Level 1: Warning Alert**
```
1. Acknowledge alert within 15 minutes
2. Check dashboard for trend direction
3. If improving: monitor for 30 minutes
4. If worsening: escalate to Level 2
```

**Level 2: Critical Alert**
```
1. Page on-call engineer immediately
2. Open incident channel
3. Review last 10 minutes of events
4. Determine if intervention needed
5. If congestion SEVERE: verify auto-pause triggered
6. Notify stakeholders
```

**Level 3: SEV-1 Emergency**
```
1. All-hands mobilization
2. Confirm system state (paused/active)
3. If not paused: manually pause all games
4. Investigate root cause
5. Communicate to community
6. Post-incident review within 24 hours
```

---

## 7. Solidity Implementation

### 7.1 SeedRevealerIncentives.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {FutureBlockRandomness} from "./FutureBlockRandomness.sol";

/// @title SeedRevealerIncentives
/// @notice Extension of FutureBlockRandomness with keeper incentives
/// @dev Games inherit this instead of FutureBlockRandomness for incentivized reveals
abstract contract SeedRevealerIncentives is FutureBlockRandomness {
    
    // ═══════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Keeper bonus as basis points of session pot (50 = 0.5%)
    uint16 public constant KEEPER_BONUS_BPS = 50;
    
    /// @notice Gas reimbursement multiplier (200 = 200% of actual gas)
    uint16 public constant GAS_REIMBURSEMENT_MULTIPLIER = 200;
    
    /// @notice Maximum gas reimbursement in DATA
    uint256 public constant MAX_GAS_REIMBURSEMENT = 500 ether;
    
    /// @notice Minimum session pot to qualify for keeper bonus
    uint256 public constant MIN_POT_FOR_BONUS = 100 ether;
    
    // ═══════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════
    
    error InsufficientRewardFunds();
    
    // ═══════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event KeeperRewarded(
        address indexed keeper,
        uint256 indexed roundId,
        uint256 gasReimbursement,
        uint256 bonusAmount,
        uint256 totalReward
    );
    
    // ═══════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Price oracle for ETH->DATA conversion
    /// @dev Set to address(0) to disable gas reimbursement
    address public ethDataPriceOracle;
    
    /// @notice Reserved funds for keeper rewards
    uint256 public keeperRewardPool;
    
    /// @notice Track who revealed each round (for analytics)
    mapping(uint256 roundId => address revealer) public roundRevealers;
    
    // ═══════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Reveal seed with keeper reward
    /// @dev Override _revealSeed to add incentives
    /// @param roundId The round identifier
    /// @param sessionPot The session's total pot (for bonus calculation)
    /// @return seed The derived seed value
    function _revealSeedWithReward(
        uint256 roundId,
        uint256 sessionPot
    ) internal returns (uint256 seed) {
        uint256 gasStart = gasleft();
        
        // Call parent implementation
        seed = _revealSeed(roundId);
        
        // Only reward if this is the first reveal
        if (roundRevealers[roundId] == address(0)) {
            roundRevealers[roundId] = msg.sender;
            
            uint256 gasUsed = gasStart - gasleft() + 21000; // Include base tx cost
            _distributeKeeperReward(roundId, msg.sender, gasUsed, sessionPot);
        }
    }
    
    /// @notice Calculate and distribute keeper reward
    function _distributeKeeperReward(
        uint256 roundId,
        address keeper,
        uint256 gasUsed,
        uint256 sessionPot
    ) internal {
        // Calculate gas reimbursement
        uint256 gasReimbursement = 0;
        if (ethDataPriceOracle != address(0)) {
            uint256 ethDataPrice = _getEthDataPrice();
            uint256 gasCostWei = gasUsed * tx.gasprice;
            uint256 gasCostData = (gasCostWei * ethDataPrice) / 1e18;
            gasReimbursement = (gasCostData * GAS_REIMBURSEMENT_MULTIPLIER) / 100;
            
            if (gasReimbursement > MAX_GAS_REIMBURSEMENT) {
                gasReimbursement = MAX_GAS_REIMBURSEMENT;
            }
        }
        
        // Calculate bonus from session pot
        uint256 bonus = 0;
        if (sessionPot >= MIN_POT_FOR_BONUS) {
            bonus = (sessionPot * KEEPER_BONUS_BPS) / 10000;
        }
        
        uint256 totalReward = gasReimbursement + bonus;
        
        if (totalReward > 0) {
            if (totalReward > keeperRewardPool) {
                // Partial reward if pool insufficient
                totalReward = keeperRewardPool;
            }
            
            if (totalReward > 0) {
                keeperRewardPool -= totalReward;
                _transferReward(keeper, totalReward);
                
                emit KeeperRewarded(keeper, roundId, gasReimbursement, bonus, totalReward);
            }
        }
    }
    
    /// @notice Get ETH->DATA price from oracle
    /// @dev Override in implementation to use actual oracle
    function _getEthDataPrice() internal view virtual returns (uint256);
    
    /// @notice Transfer reward to keeper
    /// @dev Override in implementation to use actual token transfer
    function _transferReward(address keeper, uint256 amount) internal virtual;
    
    /// @notice Fund the keeper reward pool
    /// @dev Called by game contract when collecting rake
    function _fundKeeperPool(uint256 amount) internal {
        keeperRewardPool += amount;
    }
}
```

### 7.2 CongestionManager.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {BlockhashHistory} from "./BlockhashHistory.sol";

/// @title CongestionManager
/// @notice Manages congestion detection and graceful degradation
/// @dev Inherited by games that want adaptive behavior
abstract contract CongestionManager {
    
    // ═══════════════════════════════════════════════════════════════
    // TYPES
    // ═══════════════════════════════════════════════════════════════
    
    enum CongestionLevel {
        NORMAL,
        ELEVATED,
        SEVERE,
        CRITICAL
    }
    
    struct CongestionState {
        CongestionLevel level;
        uint64 lastLevelChange;
        uint64 adaptedSeedDelay;
        bool newSessionsPaused;
        bool eip2935Available;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Number of samples in sliding window
    uint256 public constant DELAY_WINDOW_SIZE = 10;
    
    /// @notice Threshold for ELEVATED (blocks)
    uint256 public constant ELEVATED_THRESHOLD = 30;
    
    /// @notice Threshold for SEVERE (blocks)
    uint256 public constant SEVERE_THRESHOLD = 100;
    
    /// @notice Recovery threshold (hysteresis)
    uint256 public constant RECOVERY_THRESHOLD = 20;
    
    /// @notice Default seed block delay
    uint64 public constant DEFAULT_SEED_DELAY = 50;
    
    /// @notice Elevated seed block delay
    uint64 public constant ELEVATED_SEED_DELAY = 80;
    
    /// @notice Severe seed block delay (max safe value)
    uint64 public constant SEVERE_SEED_DELAY = 100;
    
    // ═══════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event CongestionLevelChanged(CongestionLevel indexed newLevel, uint256 averageDelay);
    event NewSessionsPaused(CongestionLevel reason);
    event NewSessionsResumed();
    event EIP2935StatusChanged(bool available);
    
    // ═══════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════
    
    CongestionState public congestionState;
    
    /// @notice Circular buffer of recent reveal delays
    uint256[DELAY_WINDOW_SIZE] public recentDelays;
    uint256 public delayIndex;
    uint256 public delaySampleCount;
    
    // ═══════════════════════════════════════════════════════════════
    // MODIFIERS
    // ═══════════════════════════════════════════════════════════════
    
    modifier whenNewSessionsAllowed() {
        require(!congestionState.newSessionsPaused, "New sessions paused");
        _;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Record a reveal delay and update congestion level
    function _recordRevealDelay(uint256 delayBlocks) internal {
        // Update sliding window
        recentDelays[delayIndex] = delayBlocks;
        delayIndex = (delayIndex + 1) % DELAY_WINDOW_SIZE;
        if (delaySampleCount < DELAY_WINDOW_SIZE) {
            delaySampleCount++;
        }
        
        // Update congestion level
        _updateCongestionLevel();
    }
    
    /// @notice Calculate average delay from sliding window
    function _calculateAverageDelay() internal view returns (uint256) {
        if (delaySampleCount == 0) return 0;
        
        uint256 sum = 0;
        uint256 count = delaySampleCount < DELAY_WINDOW_SIZE ? delaySampleCount : DELAY_WINDOW_SIZE;
        
        for (uint256 i = 0; i < count; i++) {
            sum += recentDelays[i];
        }
        
        return sum / count;
    }
    
    /// @notice Update congestion level based on recent delays
    function _updateCongestionLevel() internal {
        uint256 avgDelay = _calculateAverageDelay();
        CongestionState storage state = congestionState;
        
        // Check EIP-2935 availability periodically
        bool eip2935Now = BlockhashHistory.isAvailable();
        if (eip2935Now != state.eip2935Available) {
            state.eip2935Available = eip2935Now;
            emit EIP2935StatusChanged(eip2935Now);
        }
        
        CongestionLevel newLevel;
        
        if (avgDelay >= SEVERE_THRESHOLD) {
            newLevel = CongestionLevel.SEVERE;
        } else if (avgDelay >= ELEVATED_THRESHOLD) {
            newLevel = CongestionLevel.ELEVATED;
        } else if (avgDelay < RECOVERY_THRESHOLD) {
            newLevel = CongestionLevel.NORMAL;
        } else {
            newLevel = state.level; // No change (hysteresis zone)
        }
        
        // Check for CRITICAL (SEVERE + no EIP-2935)
        if (newLevel == CongestionLevel.SEVERE && !state.eip2935Available) {
            newLevel = CongestionLevel.CRITICAL;
        }
        
        if (newLevel != state.level) {
            CongestionLevel oldLevel = state.level;
            state.level = newLevel;
            state.lastLevelChange = uint64(block.timestamp);
            
            _adaptParameters(newLevel);
            emit CongestionLevelChanged(newLevel, avgDelay);
            
            // Handle session pause/resume
            if (newLevel >= CongestionLevel.SEVERE && !state.newSessionsPaused) {
                state.newSessionsPaused = true;
                emit NewSessionsPaused(newLevel);
            } else if (newLevel == CongestionLevel.NORMAL && state.newSessionsPaused) {
                state.newSessionsPaused = false;
                emit NewSessionsResumed();
            }
        }
    }
    
    /// @notice Adapt parameters based on congestion level
    function _adaptParameters(CongestionLevel level) internal {
        CongestionState storage state = congestionState;
        
        if (level == CongestionLevel.NORMAL) {
            state.adaptedSeedDelay = DEFAULT_SEED_DELAY;
        } else if (level == CongestionLevel.ELEVATED) {
            state.adaptedSeedDelay = ELEVATED_SEED_DELAY;
        } else {
            state.adaptedSeedDelay = SEVERE_SEED_DELAY;
        }
    }
    
    /// @notice Get current effective seed delay
    function _getEffectiveSeedDelay() internal view returns (uint256) {
        uint64 adapted = congestionState.adaptedSeedDelay;
        return adapted > 0 ? adapted : DEFAULT_SEED_DELAY;
    }
    
    /// @notice Admin function to manually reset congestion state
    /// @dev Only use after investigation confirms false positive
    function _resetCongestionState() internal {
        CongestionState storage state = congestionState;
        state.level = CongestionLevel.NORMAL;
        state.adaptedSeedDelay = DEFAULT_SEED_DELAY;
        state.newSessionsPaused = false;
        state.lastLevelChange = uint64(block.timestamp);
        
        // Reset delay samples
        for (uint256 i = 0; i < DELAY_WINDOW_SIZE; i++) {
            recentDelays[i] = 0;
        }
        delaySampleCount = 0;
        delayIndex = 0;
        
        emit CongestionLevelChanged(CongestionLevel.NORMAL, 0);
        emit NewSessionsResumed();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Get current congestion level
    function getCongestionLevel() external view returns (CongestionLevel) {
        return congestionState.level;
    }
    
    /// @notice Get full congestion state
    function getCongestionState() external view returns (CongestionState memory) {
        return congestionState;
    }
    
    /// @notice Get average reveal delay
    function getAverageRevealDelay() external view returns (uint256) {
        return _calculateAverageDelay();
    }
    
    /// @notice Check if new sessions are allowed
    function areNewSessionsAllowed() external view returns (bool) {
        return !congestionState.newSessionsPaused;
    }
}
```

### 7.3 Integration Example: HashCrashWithIncentives.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {SeedRevealerIncentives} from "../randomness/SeedRevealerIncentives.sol";
import {CongestionManager} from "../randomness/CongestionManager.sol";
// ... other imports

/// @title HashCrashWithIncentives
/// @notice HashCrash game with keeper incentives and congestion management
contract HashCrashWithIncentives is 
    SeedRevealerIncentives,
    CongestionManager,
    // ... other bases
{
    // ... existing game code ...
    
    /// @notice Start a new round
    function startRound() external whenNewSessionsAllowed {
        // Get adaptive seed delay
        uint256 seedDelay = _getEffectiveSeedDelay();
        
        // ... create round ...
        
        // Commit seed with adaptive delay
        _commitSeedBlock(roundId);
    }
    
    /// @notice Reveal seed for round (anyone can call)
    function revealSeed(uint256 roundId) external {
        // Record timing for congestion tracking
        RoundSeed storage rs = _roundSeeds[roundId];
        uint256 delay = block.number - rs.seedBlock;
        
        // Get session pot before reveal
        uint256 sessionPot = rounds[roundId].totalPot;
        
        // Reveal with keeper reward
        uint256 seed = _revealSeedWithReward(roundId, sessionPot);
        
        // Record delay for congestion tracking
        _recordRevealDelay(delay);
        
        // ... use seed for game logic ...
    }
    
    /// @notice Allocate portion of rake to keeper pool
    function _processRake(uint256 rakeAmount) internal {
        // Reserve keeper bonus portion
        uint256 keeperPortion = (rakeAmount * KEEPER_BONUS_BPS) / 10000;
        _fundKeeperPool(keeperPortion);
        
        // Send rest to treasury
        uint256 treasuryPortion = rakeAmount - keeperPortion;
        _sendToTreasury(treasuryPortion);
    }
    
    /// @notice Override to use actual price oracle
    function _getEthDataPrice() internal view override returns (uint256) {
        // Example: Read from Chainlink or custom oracle
        return IOracle(ethDataPriceOracle).getPrice();
    }
    
    /// @notice Override to transfer DATA tokens
    function _transferReward(address keeper, uint256 amount) internal override {
        dataToken.safeTransfer(keeper, amount);
    }
}
```

---

## 8. Keeper Bot Specification

### 8.1 Architecture

```
                    KEEPER BOT ARCHITECTURE
    _______________________________________________________________
   |                                                               |
   |                      KEEPER BOT                               |
   |  ┌─────────────────────────────────────────────────────────┐ |
   |  │                                                         │ |
   |  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │ |
   |  │  │   Monitor    │  │  Evaluator   │  │  Executor    │  │ |
   |  │  │              │  │              │  │              │  │ |
   |  │  │ - Watch for  │  │ - Calculate  │  │ - Submit TX  │  │ |
   |  │  │   events     │  │   rewards    │  │ - Handle     │  │ |
   |  │  │ - Track      │  │ - Check      │  │   retries    │  │ |
   |  │  │   deadlines  │  │   profitability│ - Monitor    │  │ |
   |  │  │              │  │              │  │   confirms   │  │ |
   |  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │ |
   |  │         │                 │                 │          │ |
   |  │         └────────┬────────┴────────┬────────┘          │ |
   |  │                  │                 │                   │ |
   |  │         ┌────────▼────────┐ ┌──────▼───────┐           │ |
   |  │         │   State Store   │ │ Alert System │           │ |
   |  │         └─────────────────┘ └──────────────┘           │ |
   |  │                                                         │ |
   |  └─────────────────────────────────────────────────────────┘ |
   |                           │                                   |
   |                           ▼                                   |
   |  ┌─────────────────────────────────────────────────────────┐ |
   |  │                     MegaETH RPC                         │ |
   |  │                                                         │ |
   |  │  - Event subscription (SeedCommitted)                   │ |
   |  │  - Block number polling                                 │ |
   |  │  - Transaction submission                               │ |
   |  └─────────────────────────────────────────────────────────┘ |
   |                                                               |
   |_______________________________________________________________|
```

### 8.2 Core Logic

```typescript
// keeper-bot/src/index.ts

interface PendingReveal {
  roundId: bigint;
  gameAddress: string;
  seedBlock: bigint;
  deadline: bigint;
  sessionPot: bigint;
  estimatedReward: bigint;
  priority: number; // Higher = reveal first
}

class KeeperBot {
  private pendingReveals: Map<string, PendingReveal> = new Map();
  private readonly SAFETY_MARGIN = 50n; // Blocks before deadline
  private readonly MIN_PROFIT_THRESHOLD = 10n * 10n ** 18n; // 10 DATA minimum
  
  async start() {
    // Subscribe to SeedCommitted events across all games
    for (const game of this.games) {
      await this.subscribeToGame(game);
    }
    
    // Main loop
    while (true) {
      await this.processReveals();
      await this.sleep(100); // 100ms, matches MegaETH block time
    }
  }
  
  async onSeedCommitted(event: SeedCommittedEvent) {
    const key = `${event.gameAddress}-${event.roundId}`;
    
    const reveal: PendingReveal = {
      roundId: event.roundId,
      gameAddress: event.gameAddress,
      seedBlock: event.seedBlock,
      deadline: event.deadline,
      sessionPot: await this.getSessionPot(event.gameAddress, event.roundId),
      estimatedReward: 0n,
      priority: 0,
    };
    
    reveal.estimatedReward = this.calculateExpectedReward(reveal);
    reveal.priority = this.calculatePriority(reveal);
    
    this.pendingReveals.set(key, reveal);
    this.logger.info(`Tracking reveal: ${key}, deadline: ${reveal.deadline}`);
  }
  
  async processReveals() {
    const currentBlock = await this.provider.getBlockNumber();
    
    // Sort by priority (highest first)
    const sorted = Array.from(this.pendingReveals.values())
      .filter(r => BigInt(currentBlock) > r.seedBlock) // Ready to reveal
      .sort((a, b) => b.priority - a.priority);
    
    for (const reveal of sorted) {
      const key = `${reveal.gameAddress}-${reveal.roundId}`;
      
      // Check if approaching deadline
      const blocksRemaining = reveal.deadline - BigInt(currentBlock);
      
      if (blocksRemaining <= this.SAFETY_MARGIN) {
        // Urgent: reveal immediately regardless of profit
        await this.executeReveal(reveal, true);
      } else if (reveal.estimatedReward >= this.MIN_PROFIT_THRESHOLD) {
        // Profitable: reveal now
        await this.executeReveal(reveal, false);
      }
      // Else: wait for better timing or higher urgency
    }
  }
  
  async executeReveal(reveal: PendingReveal, urgent: boolean) {
    const key = `${reveal.gameAddress}-${reveal.roundId}`;
    
    try {
      // Estimate gas
      const gasEstimate = await this.estimateGas(reveal);
      
      // Check profitability one more time (unless urgent)
      if (!urgent) {
        const expectedProfit = this.calculateNetProfit(reveal, gasEstimate);
        if (expectedProfit < 0n) {
          this.logger.warn(`Skipping unprofitable reveal: ${key}`);
          return;
        }
      }
      
      // Submit transaction
      const tx = await this.submitReveal(reveal, gasEstimate, urgent);
      this.logger.info(`Submitted reveal TX: ${tx.hash}`);
      
      // Wait for confirmation
      const receipt = await tx.wait();
      
      if (receipt.status === 1) {
        this.logger.info(`Reveal successful: ${key}`);
        this.pendingReveals.delete(key);
        
        // Record metrics
        this.metrics.revealsSuccessful.inc();
        this.metrics.rewardsEarned.add(reveal.estimatedReward);
      } else {
        this.logger.error(`Reveal failed: ${key}`);
        this.metrics.revealsFailed.inc();
      }
    } catch (error) {
      this.logger.error(`Error revealing ${key}: ${error}`);
      
      // Check if someone else revealed
      const alreadyRevealed = await this.checkIfRevealed(reveal);
      if (alreadyRevealed) {
        this.pendingReveals.delete(key);
      }
    }
  }
  
  calculateExpectedReward(reveal: PendingReveal): bigint {
    // Gas reimbursement (estimate)
    const gasEstimate = 100_000n; // Approximate
    const gasPrice = 10n ** 7n; // 0.01 gwei
    const ethDataPrice = this.getEthDataPrice();
    const gasCostData = (gasEstimate * gasPrice * ethDataPrice) / 10n ** 18n;
    const gasReimbursement = gasCostData * 2n; // 200%
    
    // Bonus from pot
    const bonus = (reveal.sessionPot * 50n) / 10000n; // 0.5%
    
    return gasReimbursement + bonus;
  }
  
  calculatePriority(reveal: PendingReveal): number {
    // Higher priority for:
    // 1. Larger rewards
    // 2. Closer to deadline
    // 3. Larger session pots (more players affected)
    
    const rewardScore = Number(reveal.estimatedReward / 10n ** 18n);
    const potScore = Number(reveal.sessionPot / 10n ** 18n) / 1000;
    
    return rewardScore + potScore;
  }
}
```

### 8.3 Deployment Recommendations

**Infrastructure Requirements:**

| Component | Recommendation | Notes |
|-----------|---------------|-------|
| Hosting | Dedicated VM or Kubernetes | Low latency to MegaETH RPC |
| Region | Same region as MegaETH sequencer | Minimize network latency |
| Redundancy | 2-3 instances across zones | Failover capability |
| RPC | Private or premium endpoint | Avoid rate limits |
| Wallet | Hot wallet with limited balance | Only keeper reward claims |

**Operational Guidelines:**

1. **Wallet Management**
   - Keep minimal ETH for gas (auto-refill)
   - Sweep DATA rewards to cold storage daily
   - Set up low-balance alerts

2. **Monitoring**
   - Track reveal success rate (target: >99%)
   - Alert on consecutive failures (>3)
   - Monitor P&L daily

3. **Upgrades**
   - Subscribe to protocol announcements
   - Test against testnet first
   - Coordinate with other keepers if possible

4. **Emergency Procedures**
   - Pause bot on anomaly detection
   - Manual intervention for stuck reveals
   - Communication channel with protocol team

### 8.4 Multi-Keeper Coordination

**Problem:** Multiple keepers racing causes wasted gas on failed transactions.

**Solutions:**

1. **Randomized Delay**
   ```typescript
   // Add small random delay to avoid exact collision
   const jitter = Math.random() * 500; // 0-500ms
   await this.sleep(jitter);
   ```

2. **Mempool Monitoring**
   ```typescript
   // Check if reveal TX already pending
   const pending = await this.checkPendingTxs(reveal.gameAddress);
   if (pending.length > 0) {
     this.logger.info('Another keeper already submitting, backing off');
     return;
   }
   ```

3. **Nonce Management**
   ```typescript
   // Use local nonce tracking to avoid replacement collisions
   const nonce = await this.getLocalNonce();
   const tx = await this.wallet.sendTransaction({
     nonce,
     // ... other params
   });
   ```

---

## 9. Operational Runbook

### 9.1 Normal Operations Checklist

**Daily:**
- [ ] Check keeper bot health (all instances running)
- [ ] Review expiry events (should be 0)
- [ ] Verify keeper reward pool balance
- [ ] Check congestion level history (should be NORMAL)

**Weekly:**
- [ ] Review keeper P&L
- [ ] Analyze reveal latency trends
- [ ] Test alerting system
- [ ] Update keeper bot if needed

**Monthly:**
- [ ] Review and adjust alert thresholds
- [ ] Capacity planning review
- [ ] Security audit of keeper wallet
- [ ] Update runbook if procedures changed

### 9.2 Congestion Response Procedure

**ELEVATED Congestion:**

```
1. ACKNOWLEDGE
   - [ ] Receive alert notification
   - [ ] Check dashboard for trend direction
   - [ ] Document start time

2. ASSESS
   - [ ] Is congestion improving or worsening?
   - [ ] What is the likely cause? (network event, attack, organic growth)
   - [ ] Are there any SeedExpired events?

3. MONITOR
   - [ ] Watch for 15 minutes
   - [ ] If improving: continue monitoring
   - [ ] If worsening: prepare for SEVERE response

4. COMMUNICATE
   - [ ] No external communication needed for ELEVATED
   - [ ] Internal note to team
```

**SEVERE Congestion:**

```
1. ACKNOWLEDGE (within 5 minutes)
   - [ ] Page received and acknowledged
   - [ ] Join incident channel
   - [ ] Verify auto-pause triggered

2. ASSESS (within 15 minutes)
   - [ ] Confirm auto-pause is working (no new sessions)
   - [ ] Check existing sessions (can they complete?)
   - [ ] Identify root cause if possible

3. MITIGATE
   - [ ] If keeper bots down: restart or deploy backup
   - [ ] If RPC issues: switch to backup RPC
   - [ ] If network-wide: wait and monitor

4. COMMUNICATE
   - [ ] Post status update to Discord/Twitter
   - [ ] Update status page
   - [ ] Notify affected users if significant impact

5. RECOVER
   - [ ] Wait for congestion to clear (NORMAL level)
   - [ ] Verify all pending sessions resolved
   - [ ] Document incident

6. POST-INCIDENT
   - [ ] Write incident report within 24 hours
   - [ ] Identify improvements
   - [ ] Update runbook if needed
```

**CRITICAL Congestion:**

```
1. ALL-HANDS MOBILIZATION
   - [ ] All available engineers join incident
   - [ ] Assign incident commander
   - [ ] Assign communications lead

2. IMMEDIATE ACTIONS
   - [ ] Confirm all games paused
   - [ ] Verify no funds at risk
   - [ ] Assess player impact

3. ROOT CAUSE
   - [ ] Is this a MegaETH network issue?
   - [ ] Is EIP-2935 down or unavailable?
   - [ ] Any signs of attack?

4. EXTERNAL COMMUNICATION
   - [ ] Tweet acknowledgment of issue
   - [ ] Post detailed status to Discord
   - [ ] Consider Telegram broadcast

5. RECOVERY PLAN
   - [ ] Define criteria for resuming operations
   - [ ] Test in staging if possible
   - [ ] Staged rollout (one game at a time)

6. POST-INCIDENT
   - [ ] Comprehensive incident report
   - [ ] External post-mortem if user-impacting
   - [ ] Implement preventive measures
```

### 9.3 Seed Expiry Investigation Template

```markdown
## Seed Expiry Incident Report

**Date/Time:** 
**Round ID:** 
**Game:** 
**Session Pot:** 

### Timeline
- Seed committed at block: 
- Seed ready at block: 
- Expected deadline (native): 
- Expected deadline (EIP-2935): 
- Actual expiry detected at block: 

### Impact
- Number of players affected: 
- Total refund amount: 
- Protocol revenue lost: 

### Root Cause Analysis
- Was keeper bot running? [ ] Yes [ ] No
- Keeper logs show: 
- Was EIP-2935 available? [ ] Yes [ ] No
- Network congestion level: 
- Any unusual activity: 

### Resolution
- Refunds processed: [ ] Yes [ ] No
- Users notified: [ ] Yes [ ] No

### Preventive Measures
- [ ] Measure 1
- [ ] Measure 2

### Follow-up Required
- [ ] Action item 1
- [ ] Action item 2
```

### 9.4 Post-Incident Analysis Template

```markdown
## Post-Incident Review

**Incident ID:** 
**Severity:** 
**Duration:** 
**Impact:** 

### Summary
[1-2 paragraph summary of what happened]

### Timeline
| Time | Event |
|------|-------|
| T+0 | First alert |
| T+5m | Response initiated |
| ... | ... |

### What Went Well
- 
- 

### What Could Be Improved
- 
- 

### Root Cause
[Describe the underlying cause]

### Action Items
| Item | Owner | Due Date | Status |
|------|-------|----------|--------|
| | | | |

### Lessons Learned
- 
- 
```

---

## 10. Risk Analysis

### 10.1 Probability of Seed Expiry

**Assumptions:**
- Normal reveal latency: 20 blocks (2s)
- MegaETH congestion events: ~1 per week, lasting 1-4 hours
- EIP-2935 availability: 99% (assumed)

**Analysis:**

| Scenario | Sessions | Expiry Probability | Expected Expirations |
|----------|----------|-------------------|----------------------|
| Normal operation | 1000/day | 0.001% | ~0.01/day |
| Elevated congestion (1h) | 42/hour | 0.1% | ~0.04/event |
| Severe congestion (1h) | 42/hour | 1% | ~0.4/event |
| Severe + no EIP-2935 (1h) | 42/hour | 10% | ~4.2/event |

**Expected annual expirations:**
- Normal: ~4 events
- With congestion: ~25 events
- Worst case (multiple severe): ~50 events

### 10.2 Economic Impact of Expiry

**Per Expiry Event:**
- Average session pot: 5,000 DATA
- Average players affected: 10
- Refund cost: 0 (funds returned to players)
- Protocol reputation cost: Low-Medium

**Mitigated by:**
- Keeper incentives (reduces missed reveals)
- Auto-pause (limits exposure during severe congestion)
- EIP-2935 fallback (13x longer window)

### 10.3 Mitigation Effectiveness Estimates

| Mitigation | Without | With | Improvement |
|------------|---------|------|-------------|
| Keeper incentives | ~50 expirations/year | ~15 expirations/year | 70% reduction |
| Auto-pause | ~15 expirations/year | ~5 expirations/year | 67% reduction |
| EIP-2935 | ~5 expirations/year | ~1 expiration/year | 80% reduction |
| **Combined** | ~50 expirations/year | **~1 expiration/year** | **98% reduction** |

### 10.4 Residual Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Coordinated keeper failure | Very Low | High | Multi-keeper redundancy |
| MegaETH extended outage | Very Low | Critical | Nothing on-chain can help |
| EIP-2935 deprecation | Low | Medium | Update contracts |
| Game-theoretic exploit | Low | Medium | Ongoing monitoring |
| Oracle manipulation | Low | Low | Multiple oracle sources |

### 10.5 Recommendations

**Before Launch:**
1. Deploy at least 2 independent keeper bots
2. Verify EIP-2935 availability on MegaETH mainnet
3. Set up complete monitoring stack
4. Conduct load testing with artificial congestion

**After Launch:**
1. Monitor expiry rate closely for first month
2. Adjust thresholds based on observed behavior
3. Build relationships with other potential keepers
4. Consider keeper registry if ecosystem develops

---

## Appendix A: Constants Summary

```solidity
// Timing (blocks, 100ms each on MegaETH)
DEFAULT_SEED_DELAY = 50;        // 5 seconds
ELEVATED_SEED_DELAY = 80;       // 8 seconds  
SEVERE_SEED_DELAY = 100;        // 10 seconds
MAX_BLOCK_AGE = 256;            // 25.6 seconds (EVM limit)
EXTENDED_HISTORY = 8191;        // ~13.6 minutes (EIP-2935)

// Congestion thresholds (blocks)
ELEVATED_THRESHOLD = 30;        // ~3 seconds delay
SEVERE_THRESHOLD = 100;         // ~10 seconds delay
RECOVERY_THRESHOLD = 20;        // ~2 seconds (hysteresis)

// Keeper incentives
KEEPER_BONUS_BPS = 50;          // 0.5% of session pot
GAS_REIMBURSEMENT_MULT = 200;   // 200% of gas cost
MAX_GAS_REIMBURSEMENT = 500e18; // 500 DATA cap
MIN_POT_FOR_BONUS = 100e18;     // 100 DATA minimum

// Monitoring
DELAY_WINDOW_SIZE = 10;         // Sliding window samples
```

## Appendix B: Event Schemas

```solidity
// Randomness events
event SeedCommitted(uint256 indexed roundId, uint256 seedBlock, uint256 deadline);
event SeedRevealed(uint256 indexed roundId, bytes32 blockHash, uint256 seed, bool usedExtendedHistory);
event SeedExpired(uint256 indexed roundId, uint256 seedBlock, uint256 expiredAtBlock);

// Keeper events
event KeeperRewarded(address indexed keeper, uint256 indexed roundId, uint256 gasReimbursement, uint256 bonusAmount, uint256 totalReward);

// Congestion events
event CongestionLevelChanged(CongestionLevel indexed newLevel, uint256 averageDelay);
event NewSessionsPaused(CongestionLevel reason);
event NewSessionsResumed();
event EIP2935StatusChanged(bool available);
```

---

**Document Status:** Ready for implementation review  
**Next Steps:**
1. Review with security team
2. Implement contracts in `packages/contracts/src/arcade/randomness/`
3. Implement keeper bot in `services/keeper/`
4. Set up monitoring infrastructure
5. Test on MegaETH testnet
