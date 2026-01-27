---
type: capability
domain: social
updated: 2026-01-27
tags:
  - type/capability
  - domain/social
---

# Social

## Overview

GHOSTNET's social layer transforms the game from a solitary gambling experience into a **shared spectacle**. The Live Feed is the dopamine engine—a constant stream of wins, losses, drama, and opportunity visible to all players. Crews add team dynamics and coordination. Leaderboards create competitive motivation.

The social layer exploits several psychological triggers:
- **Social proof**: See others winning/losing in real-time
- **FOMO**: Whale alerts, jackpot moments
- **Tribal belonging**: Crew membership and raids
- **Competition**: Leaderboards, PvP duels

## Concepts

### The Command Center

The main screen is a **living terminal** that streams network activity:

```
+--------------------------------------------------------------------------+
| GHOSTNET v1.0.7                                           NETWORK: ONLINE |
+-----------------------------------+--------------------------------------+
|          LIVE FEED                |            YOUR STATUS               |
|                                   |  OPERATOR: 0x7a3f...9c2d             |
| > 0x7a3f jacked in [DARKNET] 500D |  STATUS: JACKED IN                   |
| > 0x9c2d TRACED -Loss 120D        |  LEVEL: DARKNET                      |
| > 0x3b1a extracted 847D [+312]    |  STAKED: 500 $DATA                   |
| > TRACE SCAN [DARKNET] in 00:45   |  DEATH RATE: 32%                     |
| > 0x8f2e jacked in [BLACK ICE]    |  YIELD: 31,500% APY                  |
|                                   |  NEXT SCAN: 01:23                    |
+-----------------------------------+--------------------------------------+
```

### Event Priority

Higher priority events stay visible longer:

| Priority | Event Type |
|----------|------------|
| 10 | Deaths (most important) |
| 9 | Whale alerts |
| 8 | Jackpots |
| 7 | System warnings |
| 6 | Scan warnings |
| 5 | Extractions |
| 4 | Crew events |
| 3 | Mini-game results |
| 2 | Survivals |
| 1 | Jack-ins |

---

## Capabilities

### ✅ FR-SOCIAL-001: The Feed

**Implemented by:** `apps/web/src/lib/features/feed/`

**What:** Real-time stream of all network events visible to all players.

**How it works:**

1. WebSocket connection streams events from protocol
2. Events rendered with appropriate styling and priority
3. Higher priority events stay visible longer
4. Visual/audio feedback on significant events

**Event Types:**

| Type | Example | Visual |
|------|---------|--------|
| Jack In | `> 0x7a3f jacked in [DARKNET] 500D` | Green pulse |
| Extraction | `> 0x3b1a extracted 847D [+312 gain]` | Gold/cyan |
| Death | `> 0x9c2d TRACED -Loss 120D` | RED FLASH |
| Survival | `> 0x5e7b survived [SUBNET] streak: 12` | Green, ghost emoji |
| Scan Warning | `> TRACE SCAN [DARKNET] in 00:45` | Amber pulse |
| System Warning | `> SYSTEM RESET in 00:05:00` | Red urgent |
| Jackpot | `> 0x2a9f JACKPOT [BLACK ICE] +2,400D` | GOLD, particles |
| Crew Event | `> [PHANTOMS] completed raid +10%` | Crew color |
| Mini-game | `> 0x6c3d perfect hack run [3x]` | Cyan |
| Whale Alert | `> WHALE: 0x4b8e jacked in 10,000D` | Special icon, glow |

**Death Event Details:**

When someone dies:
1. Red flash across entire feed
2. Glitch effect on address
3. `TRACED` text with screen shake
4. Loss amount in red
5. Cascade distribution shown
6. Your yield ticks up (if in cascade)

**Constraints:**

- Max 15 visible items
- Scroll speed adjusts to activity
- Deaths trigger global screen flash

**Related:** [[FR-CORE-003]], [[FR-CORE-006]]

---

### 🟣 FR-SOCIAL-002: Leaderboards

**What:** Rankings for various competitive metrics.

**Planned approach:**

Leaderboard Categories:

| Category | Metric | Timeframe |
|----------|--------|-----------|
| Top Survivors | Longest survival streak | All-time |
| Biggest Ghosts | Total yield extracted | Weekly |
| Death Dealers | Positions traced (volume) | Weekly |
| Whale Watch | Largest single position | Current |
| Speed Demons | Highest typing WPM | All-time |
| Crew Rankings | Crew total staked | Current |

Display Format:
```
TOP SURVIVORS (ALL-TIME)
========================
1. 0x7a3f...9c2d    Streak: 247    Level: SUBNET
2. 0x3b1a...8f2e    Streak: 189    Level: DARKNET
3. 0x9c2d...1d4c    Streak: 156    Level: MAINFRAME
...
```

**Notes:**

Leaderboard data can be derived from on-chain events. No additional contract needed.

---

### 🧠 FR-SOCIAL-003: Crews

**What:** Team formation with shared bonuses and coordination.

**Planned approach:**

Crew Structure:
- Max 20 members
- Crew name and tag visible in feed
- Shared chat channel
- Collective bonuses

Crew Bonuses:

| Milestone | Bonus | Condition |
|-----------|-------|-----------|
| 5 members | +2% yield | While active |
| 10 members | +5% yield | While active |
| 15 members | +8% yield | While active |
| 20 members (full) | +12% yield | While active |
| Daily sync (3 complete) | +10% yield | 24 hours |
| Crew survival streak | -1% death per level | Up to -10% |
| Weekly raid complete | 2x yield | 24 hours |

**Crew Display:**

```
CREW: PHANTOM_COLLECTIVE
========================
MEMBERS: 12/20              RANK: #47
TOTAL STAKED: 14,200D       WEEKLY EXTRACT: 8,400D

ACTIVE BONUSES:
- Crew Size (10+)      +5% yield
- Daily Sync (3/3)     +10% yield today
- Survival Streak (8)  -3% death rate

MEMBERS ONLINE:
* 0x7a3f (You)    DARKNET    500D    Streak: 7
* 0x9c2d          SUBNET     300D    Streak: 4
* 0x3b1a          BLACK ICE  100D    Streak: 2
o 0x8f2e          MAINFRAME  200D    (Offline)
```

**Notes:**

Crew system requires significant backend infrastructure. Deferred to later phase.

**Related:** [[FR-ECON-005]], [[FR-GAME-006]]

---

### 🧠 FR-SOCIAL-004: Crew Raids

**What:** Weekly cooperative challenges for crew-wide rewards.

**Planned approach:**

```
WEEKLY CREW RAID
"Operation: Data Heist"
========================
OBJECTIVE: Collectively complete 100 typing challenges
TIME LIMIT: 1 hour
REWARD: All crew members get 2x yield for 24 hours

PROGRESS:
[================================        ] 67/100

TIME REMAINING: 34:22

TOP CONTRIBUTORS:
1. 0x7a3f (You)    23 challenges
2. 0x9c2d          18 challenges
3. 0x3b1a          12 challenges
```

**Raid Types:**

| Raid | Objective | Reward |
|------|-----------|--------|
| Data Heist | 100 typing challenges | 2x yield 24h |
| Ghost Protocol | All members survive scan | -5% death 48h |
| Extraction Rush | Extract 10,000 $DATA total | 500 $DATA split |

**Notes:**

Requires crew system to be implemented first.

**Related:** [[FR-SOCIAL-003]]

---

### 🟣 FR-SOCIAL-005: Profile/Stats

**What:** Player statistics and achievement tracking.

**Planned approach:**

Profile Display:
```
OPERATOR: 0x7a3f...9c2d
========================
JACKED IN: 2025-01-15
TOTAL STAKED: 4,500 $DATA
TOTAL EXTRACTED: 12,847 $DATA
PROFIT: +8,347 $DATA

SURVIVAL STATS:
- Scans Survived: 147
- Times Traced: 23
- Best Streak: 34
- Current Streak: 7

MINI-GAME STATS:
- Typing Avg WPM: 78
- Typing Avg Accuracy: 94%
- Hack Runs Completed: 12
- Dead Pool Win Rate: 58%
- Duel Record: 23W-18L

BADGES:
[Week Warrior] [Dedicated Operator] [Speed Demon] [Whale]
```

**Metrics Tracked:**

| Category | Metrics |
|----------|---------|
| Staking | Total staked, extracted, profit |
| Survival | Scans survived, deaths, best streak |
| Typing | Average WPM, accuracy, perfect runs |
| Mini-games | Hack runs, Dead Pool bets, duels |
| Social | Crew membership, raid participation |

---

### 🧠 FR-SOCIAL-006: PvP Duels

**What:** Real-time competitive typing battles with wagered stakes.

**Planned approach:**

```
PVP DUEL
========================
YOU                    VS                    OPPONENT
0x7a3f                                       0x9c2d
Rank: #847                                 Rank: #234
Win Rate: 67%                            Win Rate: 71%

WAGER: 50D each (Winner takes 90D, 10D burned)

STATUS: RACING

YOUR PROGRESS:
[================              ] 42%
WPM: 78    ACC: 96%

OPPONENT PROGRESS:
[==============                ] 38%
WPM: 71    ACC: 94%

TIME: 34s remaining
```

**Mechanics:**

1. Both players type same command simultaneously
2. Real-time progress visible
3. First to complete with >90% accuracy wins
4. If tie: Higher accuracy wins
5. 10% of pot burned

**Notes:**

Requires real-time synchronization infrastructure. May use Code Duel contract as backend.

**Related:** [[FR-GAME-005]]

---

### 🚧 FR-SOCIAL-007: Event Schema Contract

**Summary:** On-chain events follow a documented, consistent schema for indexing and rendering.

**Behavior:**

All contract events include:
- Standard event signature per action type
- Indexed parameters for efficient filtering
- Consistent field ordering
- Human-readable event names

**Event Categories:**

| Category | Events |
|----------|--------|
| Position | `JackIn`, `Extract`, `EmergencyWithdraw` |
| Scan | `ScanStarted`, `ScanCompleted`, `PlayerTraced`, `PlayerSurvived` |
| System | `SystemPaused`, `SystemUnpaused`, `TimerReset`, `Collapse` |
| Economy | `CascadeDistributed`, `TokensBurned`, `FeeCollected` |
| Mini-game | `GameStarted`, `GameCompleted`, `RewardClaimed` |

**Schema Example:**

```solidity
event JackIn(
    address indexed player,
    uint8 indexed level,
    uint256 amount,
    uint256 timestamp
);

event PlayerTraced(
    address indexed player,
    uint8 indexed level,
    uint256 amount,
    bytes32 scanId,
    uint256 timestamp
);
```

**Rationale:** Consistent event schema enables reliable indexing, feed rendering, and third-party integrations. Essential for The Feed to work correctly.

**Related:**
- [[FR-SOCIAL-001]] - The Feed
- [[architecture#indexer]]

---

### 🧠 FR-SOCIAL-008: Spectator Mode

**Summary:** Non-participants can watch the feed and stats without staking.

**Behavior:**

Spectators (no position) can:
- View The Feed in real-time
- See all network statistics
- Browse leaderboards
- Watch trace scans happen live
- View aggregate death/survival statistics

Spectators cannot:
- Earn yield
- Participate in mini-games
- Access personal position features

**UI Treatment:**

- No "Connect Wallet" required to view
- Prominent "Jack In" call-to-action
- Statistics highlight opportunities ("Average survivor earns X")
- Recent jackpot winners displayed

**Rationale:** Entertainment value without commitment. Builds FOMO by showing others winning. Reduces barrier to entry for curious users.

**Related:**
- [[FR-CORE-011]] - Read-only mode
- [[FR-SOCIAL-001]] - The Feed

---

## Domain Rules

### Business Rules

| Rule | Description |
|------|-------------|
| Feed is public | All events visible to all players |
| Crew membership exclusive | Player can only be in one crew |
| Leaderboards are on-chain | Rankings derived from verifiable events |
| Profiles are opt-in | Stats only shown if player has interacted |

### Validation Rules

| Field | Rule | Error |
|-------|------|-------|
| Crew name | 3-20 characters, alphanumeric | "Invalid crew name" |
| Crew size | <= 20 members | "Crew is full" |

---

## Domain Invariants

> [!warning] Must Always Be True

1. **Feed events match on-chain** - Every feed event corresponds to a real transaction
2. **Leaderboards are accurate** - Rankings reflect actual on-chain state
3. **Crew bonuses verified** - Bonuses only applied to actual crew members

---

## Integration Points

### With Core Domain

- All core events stream to Feed
- Death/survival events are primary content
- Scan warnings create tension

### With Mini-Games Domain

- Mini-game results stream to Feed
- Code Duel powers PvP
- Daily Ops has crew component

### With Economy Domain

- Whale alerts based on stake size
- Cascade notifications show redistribution

---

## Related

- [[core#trace-scan]] - Primary feed content
- [[minigames#code-duel]] - Backend for PvP
- [[architecture#social-layer]]
