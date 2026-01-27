---
type: capability
domain: core
updated: 2026-01-27
tags:
  - type/capability
  - domain/core
---

# Core Game

## Overview

The Core Game is the foundational economic engine of GHOSTNET. Players "jack in" by staking $DATA tokens at their chosen security clearance level, earn yield passively, and must survive periodic "trace scans" that can liquidate their positions. The core game requires **zero interaction after staking**—players can simply watch and earn.

The design follows an **Inverted Risk Tower**: capital flows UP from high-risk zones (degens) to safe zones (whales). This creates sustainable yield without inflation by **harvesting dead capital** through redistribution.

## Concepts

### Risk Levels

GHOSTNET has 5 risk levels (also called "security clearances" in-game), each with different death rates and scan frequencies:

| Level | Name | Death Rate | Scan Frequency | Target APY | Min Stake |
|-------|------|------------|----------------|------------|-----------|
| 1 | THE VAULT | 0% (Safe) | Never | 100-500% | 100 $DATA |
| 2 | MAINFRAME | 2% | Every 24h | 1,000% | 50 $DATA |
| 3 | SUBNET | 15% | Every 8h | 5,000% | 30 $DATA |
| 4 | DARKNET | 40% | Every 2h | 20,000% | 15 $DATA |
| 5 | BLACK ICE | 90% | Every 30m | Instant 2x | 5 $DATA |

### Ghost Status

When you survive a trace scan, you maintain "Ghost Status" and continue earning yield. Your survival streak increases, providing psychological satisfaction and potential bonuses.

### The Cascade

When players die, their capital is redistributed (not lost). See [[capabilities/economy#🟣-fr-econ-001-the-cascade]] for details.

---

## Capabilities

### 🟣 FR-CORE-001: Jack In

**What:** Players can stake $DATA tokens to enter the game at their chosen security clearance level.

**How it works:**

1. Player selects a risk level (1-5)
2. Player specifies stake amount (must meet minimum for level)
3. Contract transfers $DATA from player to protocol
4. Position is created with initial yield of 0
5. Player begins earning yield immediately
6. Event emitted to feed: `> 0x7a3f jacked in [DARKNET] 500D`

**Constraints:**

- Minimum stake varies by level (5-100 $DATA)
- Player can have only **one position total** (level is locked once chosen; to change levels, must extract and re-enter, incurring 10% transfer tax friction)
- Cannot jack in during lock period (60 seconds before scan)
- Gas fee applies (~$2 ETH toll)

**Edge cases:**

| Case | Handling |
|------|----------|
| Below minimum stake | Transaction reverts |
| Level at capacity | Triggers The Culling (FR-CORE-008) |
| During trace scan | Blocked until scan completes |
| Insufficient balance | Transaction reverts |

**Related:** [[FR-CORE-002]], [[FR-CORE-004]], [[FR-ECON-008]]

---

### 🟣 FR-CORE-002: Extract

**What:** Players can withdraw their stake plus accumulated yield at any time.

**How it works:**

1. Player initiates extraction for a specific position
2. Protocol calculates total: stake + accumulated yield
3. Protocol fee (5%) deducted from total
4. Remaining amount transferred to player
5. Position closed
6. Event emitted: `> 0x3b1a extracted 847D [+312 gain]`

**Constraints:**

- 5% protocol fee on total extracted amount
- Cannot extract during active trace scan
- Extraction resets yield accumulation
- Gas fee applies (~$2 ETH toll)

**Edge cases:**

| Case | Handling |
|------|----------|
| During trace scan | Blocked until scan completes |
| Position doesn't exist | Transaction reverts |
| Zero yield accumulated | Still allowed (just returns stake minus fee) |

**Related:** [[FR-CORE-001]], [[FR-ECON-002]]

---

### 🟣 FR-CORE-003: Trace Scan

**What:** Periodic survival checks that probabilistically liquidate positions based on their security clearance.

**How it works:**

1. Scan warning appears in feed (60 seconds before):
   `> TRACE SCAN [DARKNET] in 00:60`
2. Positions are **locked** during this 60-second window (no extraction allowed)
3. Scan executes using **block-based randomness** (`prevrandao` + multi-component seed)
4. Each position in the scanned level gets a death roll
5. If roll < death rate: position is TRACED (liquidated)
6. If roll >= death rate: position SURVIVES
7. Results stream to feed in real-time:
   ```
   > 0x7a3f survived [DARKNET]
   > 0x9c2d TRACED -Loss 120D
   ```
8. The Cascade distributes dead capital

**Constraints:**

- Different levels scan at different frequencies
- Death rate modified by network state and player boosts
- Scan is atomic—all positions in level resolved together
- Randomness is deterministic and verifiable: `isDead(seed, address, deathRate)` is a pure function anyone can verify

**Death Rate Formula:**

```
EFFECTIVE_RATE = BASE_RATE x NETWORK_MOD x PERSONAL_MOD

Where:
- BASE_RATE = Clearance base rate (e.g., 40% for DARKNET)
- NETWORK_MOD = Function of TVL (more TVL = safer)
- PERSONAL_MOD = Player's active boosts from mini-games
```

**Network Modifier:**

| TVL | Modifier |
|-----|----------|
| < $100k | 1.2x (more dangerous) |
| $100k-$500k | 1.0x (normal) |
| $500k-$1M | 0.9x (safer) |
| > $1M | 0.85x (network strength) |

**Related:** [[FR-CORE-004]], [[FR-CORE-006]], [[FR-GAME-001]]

---

### 🟣 FR-CORE-004: Risk Levels

**What:** The system provides 5 distinct risk levels (thematically called "security clearances") with different risk/reward profiles.

**How it works:**

Each risk level is a self-contained pool with its own:
- Death rate (trace probability)
- Scan frequency
- Yield emission allocation
- Minimum stake requirement

**Level Details:**

| Level | Role | Description |
|-------|------|-------------|
| THE VAULT | Bank | Safe haven for whales. Absorbs yield from all levels below. |
| MAINFRAME | Conservative | Eats yield from Levels 3, 4, 5. Low risk, decent returns. |
| SUBNET | Mid-Curve | Balance of survival and greed. The "normal" player zone. |
| DARKNET | Degen | High velocity. Feeds L1-3 with frequent deaths. |
| BLACK ICE | Casino | 30-minute rounds. Double or nothing mentality. |

**Yield Emission Distribution:**

```
THE MINE: 60,000,000 $DATA over 24 months
Daily Emission: ~82,000 $DATA

- VAULT (Level 1):     5% of daily emission
- MAINFRAME (Level 2): 10% of daily emission
- SUBNET (Level 3):    20% of daily emission
- DARKNET (Level 4):   30% of daily emission
- BLACK ICE (Level 5): 35% of daily emission
```

**Related:** [[FR-CORE-001]], [[FR-CORE-003]]

---

### 🟣 FR-CORE-005: Yield Accrual

**What:** Players earn yield in real-time based on their stake and security clearance level.

**How it works:**

1. Yield accrues every second (displayed in real-time)
2. Rate determined by:
   - Player's stake relative to total staked in level
   - Level's share of daily emission
   - Active multiplier boosts (from mini-games)
3. Yield only realizable on extraction

**Yield Calculation:**

```
PLAYER_YIELD = (PLAYER_STAKE / LEVEL_TVL) x LEVEL_EMISSION x TIME x MULTIPLIER
```

**Multipliers (from Active Boost Layer):**

| Source | Multiplier | Duration |
|--------|------------|----------|
| Hack Run (3/5 nodes) | 1.25x | 4 hours |
| Hack Run (4/5 nodes) | 1.5x | 4 hours |
| Hack Run (5/5 nodes) | 2x | 4 hours |
| Hack Run (Perfect) | 3x | 4 hours |
| Daily Ops Bonus | +5-10% | 24 hours |
| Crew Size Bonus | +2-12% | While in crew |
| Crew Raid Complete | 2x | 24 hours |

**Related:** [[FR-CORE-002]], [[FR-GAME-002]]

---

### 🟣 FR-CORE-006: Death Handling

**What:** When a position is traced, it is liquidated and its capital redistributed via The Cascade.

**How it works:**

1. Position marked as TRACED
2. Stake amount captured
3. The Cascade splits capital:
   - 60% to reward pool (survivors + upper levels)
   - 30% burned permanently
   - 10% to protocol treasury
4. Position deleted
5. Feed event with dramatic visual:
   ```
   > 0x9c2d TRACED -Loss 120D
   > CASCADE INITIATED: 120 $DATA redistributed
   ```
6. Screen flashes red briefly for all viewers

**Constraints:**

- No partial deaths—full stake is liquidated
- Dead players can immediately re-jack-in
- Death breaks survival streak

**Related:** [[FR-CORE-003]], [[FR-ECON-001]], [[FR-ECON-003]]

---

### 🟣 FR-CORE-007: System Reset Timer

**What:** A global countdown timer that creates urgency for new deposits.

**How it works:**

1. Timer runs continuously (starts at 24 hours)
2. Every deposit resets timer based on amount:
   - < 50 $DATA: +1 hour
   - 50-200 $DATA: +4 hours
   - 200-500 $DATA: +8 hours
   - 500-1000 $DATA: +16 hours
   - > 1000 $DATA: Full reset (24 hours)
3. If timer hits 00:00:00 (collapse):
   - All positions lose 25% of stake
   - 50% of penalty pool goes to last depositor (JACKPOT)
   - 30% of penalty pool burned
   - 20% to protocol

**Why This Works:**

- Creates constant urgency in the feed
- Incentivizes deposits (reset timer, save everyone)
- Whale incentive (big deposits = full reset)
- Jackpot creates "last-second hero" content moments

**Related:** [[FR-CORE-001]]

---

### 🧠 FR-CORE-008: The Culling

**What:** Capacity enforcement that removes small positions when levels are full.

**Planned approach:**

When a level reaches maximum capacity:

1. New entrant triggers weighted random selection from bottom 50%
2. Selected position loses 80% of stake (redistributed)
3. Selected position receives 20% as "severance"
4. New position created

**Notes:**

This is still being defined. Key design questions:
- What is maximum capacity per level?
- Should culling be preventable through mini-games?
- Should there be warning indicators?

**Related:** [[FR-CORE-001]], [[FR-CORE-006]]

---

### 🟣 FR-CORE-009: Emergency Pause

**Summary:** System can be paused by admin multisig in emergency situations.

**Behavior:**

1. Admin calls `pause()` on core contract
2. All deposits, scans, and extracts are blocked
3. Emergency withdraw remains available (FR-CORE-010)
4. Event emitted: `SystemPaused(address admin, uint256 timestamp)`

**Unpausing:**

1. Admin calls `unpause()` after threat resolved
2. Requires timelock (24h minimum) to prevent hasty resumption
3. Event emitted: `SystemUnpaused(address admin, uint256 timestamp)`

**Rationale:** Required for security response to exploits or critical bugs. The circuit breaker is essential for any protocol handling user funds.

**Related:**
- [[quality#NFR-SEC-004]] - Circuit breaker requirement
- [[FR-CORE-010]] - Emergency withdraw
- [[architecture#emergency-procedures]]

---

### 🟣 FR-CORE-010: Emergency Withdraw

**Summary:** Users can withdraw their principal (no yield) during emergency pause.

**Behavior:**

1. Only callable when system is paused
2. User calls `emergencyWithdraw(levelId)`
3. Contract returns original stake amount (no yield, no fees)
4. Position is closed
5. Event emitted: `EmergencyWithdraw(address user, uint256 level, uint256 amount)`

**Constraints:**

- No yield calculation - returns exact principal
- No protocol fee - users aren't penalized for emergency
- Preserves solvency invariant (total_staked == sum_of_positions)
- Cannot be called when system is operational

**Rationale:** Ensures users are never trapped in the protocol. Even during a security incident, users can recover their principal. This is non-negotiable for user trust.

**Related:**
- [[FR-CORE-009]] - Emergency pause
- [[quality#NFR-SEC-002]] - Admin key safety

---

### 🚧 FR-CORE-011: Read-Only Mode

**Summary:** App functions in read-only mode when wallet is not connected.

**Behavior:**

Without wallet connected, users can:
- View the live feed (all events)
- See network vitals (TVL, active positions, recent scans)
- Browse leaderboards
- View aggregate statistics
- Preview mini-game interfaces

Without wallet connected, users cannot:
- Jack in (stake tokens)
- Extract positions
- Play mini-games for rewards
- Access personal position panel

**UI Indicators:**

- Position panel shows "Connect wallet to play"
- Action buttons show "Connect" instead of action
- Clear call-to-action for wallet connection

**Rationale:** New users should explore and understand the game before committing. Reduces friction and allows "window shopping" which builds interest.

**Related:**
- [[quality#NFR-REL-003]] - Read-only mode support
- [[FR-SOCIAL-008]] - Spectator mode

---

## Operations Capabilities

### 🧠 FR-OPS-001: Keeper Automation

**Summary:** Trace scans are triggered automatically by a keeper bot.

**Planned Behavior:**

1. Keeper monitors scan schedules for all levels
2. When scan time is reached, keeper calls `triggerScan(levelId)`
3. Contract validates timing requirements are met
4. Scan executes normally (FR-CORE-003)
5. Keeper is compensated via gas refund or keeper reward

**Implementation Options:**

| Option | Pros | Cons |
|--------|------|------|
| Gelato | Managed service, reliable | External dependency |
| Chainlink Automation | Battle-tested, decentralized | Higher cost |
| Custom Keeper | Full control | Ops burden |

**Security Considerations:**

- Anyone can trigger a scan (trustless)
- Scan only executes if timing requirements met
- Lock period prevents front-running regardless of caller
- Keeper failure doesn't break game (users can trigger manually)

**Related:**
- [[FR-CORE-003]] - Trace Scan
- [[quality#NFR-REL-004]] - Uptime requirements

---

### 🟣 FR-OPS-002: Upgrade Governance

**Summary:** Contract upgrades require timelock for transparent governance.

**Behavior:**

1. Admin proposes upgrade via timelock contract
2. 48-hour minimum delay before execution
3. Upgrade details visible on-chain during delay
4. Community can verify upgrade code
5. Emergency multisig can cancel (but not accelerate)
6. After delay, upgrade executed

**Events:**

- `UpgradeProposed(address newImpl, uint256 executeAfter)`
- `UpgradeCancelled(address newImpl)`
- `UpgradeExecuted(address oldImpl, address newImpl)`

**Constraints:**

- No instant upgrades except emergency pause
- All upgrade proposals visible on-chain
- Emergency pause is separate from upgrade path
- UUPS pattern preferred for upgradeability

**Rationale:** Timelocks protect users from malicious or hasty upgrades. Transparency builds trust.

**Related:**
- [[quality#NFR-SEC-007]] - Key management
- [[FR-CORE-009]] - Emergency pause

---

## Domain Rules

### Business Rules

| Rule | Description |
|------|-------------|
| One position per user | A player can only have one active position total (level is locked once chosen) |
| No negative yield | Yield can never go negative; minimum is 0 |
| Scans are atomic | All positions in a level are resolved in the same transaction |
| Death is final | Once traced, position cannot be recovered |

### Validation Rules

| Field | Rule | Error |
|-------|------|-------|
| Stake amount | >= level minimum | "Insufficient stake for level" |
| Player balance | >= stake amount | "Insufficient $DATA balance" |
| Level | 1-5 only | "Invalid security clearance" |

---

## Domain Invariants

> [!warning] Must Always Be True

1. **Total staked = Sum of all positions** - No $DATA can be created or destroyed within the staking system
2. **Death rate never exceeds 100%** - Even with negative modifiers
3. **Yield emission matches schedule** - The Mine distribution follows the 24-month vesting
4. **Randomness is deterministic** - All trace scans use verifiable on-chain randomness (prevrandao + lock period)

---

## Integration Points

### With Economy Domain

- Deaths trigger The Cascade (FR-ECON-001)
- Extractions deduct protocol fee (FR-ECON-002)
- Deaths contribute to burn (FR-ECON-003)

### With Mini-Games Domain

- Trace Evasion reduces death rate (FR-GAME-001)
- Hack Runs provide yield multipliers (FR-GAME-002)
- Daily Ops affect death rate (FR-GAME-006)

### With Social Domain

- All events streamed to The Feed (FR-SOCIAL-001)
- Crew bonuses affect yield (FR-SOCIAL-003)

---

## Related

- [[architecture#core-economic-engine]]
- [[design/arcade/]] - Mini-game specifications
- [[economy]] - Burn and redistribution mechanics
