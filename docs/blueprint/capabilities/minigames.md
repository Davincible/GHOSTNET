---
type: capability
domain: minigames
updated: 2026-01-26
tags:
  - type/capability
  - domain/minigames
---

# Mini-Games

## Overview

Mini-games provide the **Active Boost Layer** of GHOSTNET. They are optional but provide significant edges for players who engage. The design philosophy is **passive-first with active rewards**: players who don't want to play can simply stake and watch, while players who engage get better odds, higher multipliers, and competitive advantages.

Mini-games are organized into three phases:
- **Core Games** (Trace Evasion, Hack Runs, Dead Pool) - Integrated with main game
- **Phase 3A** (Hash Crash, Code Duel, Daily Ops) - First arcade expansion
- **Phase 3B/3C** (ICE Breaker, Binary Bet, etc.) - Future expansions

## Concepts

### Boost Types

| Boost Type | Source | Duration |
|------------|--------|----------|
| Death Rate Reduction | Trace Evasion, Daily Ops | Until next scan / 24h |
| Yield Multiplier | Hack Runs | 4 hours |
| Streak Bonuses | Daily Ops | Continuous |
| Wagering | Dead Pool, Hash Crash | Per round |

### The Arcade Architecture

All Phase 3+ games use shared infrastructure:

- **ArcadeCore**: Session tracking, payouts, burns (deployed to testnet)
- **GameRegistry**: Game registration with 7-day removal grace period
- **FutureBlockRandomness**: Provably fair randomness using MegaETH's block hash + EIP-2935

See `docs/design/arcade/` for detailed specifications.

---

## Capabilities

### 🚧 FR-GAME-001: Trace Evasion

**What:** Typing challenge that reduces death probability before trace scans.

**How it works:**

1. Player activates Trace Evasion before a scan
2. Hacker-themed command appears (e.g., `ssh -L 8080:localhost:443 ghost@proxy.darknet.io`)
3. Player types the command as fast and accurately as possible
4. Performance determines death rate reduction
5. Protection lasts until next trace scan

**Reward Tiers:**

| Performance | Trace Reduction | Duration |
|-------------|-----------------|----------|
| < 50% accuracy | No bonus | - |
| 50-69% accuracy | -5% death rate | Until next scan |
| 70-84% accuracy | -10% death rate | Until next scan |
| 85-94% accuracy | -15% death rate | Until next scan |
| 95-99% accuracy | -20% death rate | Until next scan |
| 100% (Perfect) | -25% death rate | Until next scan |

**Speed Bonuses:**
- > 80 WPM + 95% acc: Additional -5%
- > 100 WPM + 95% acc: Additional -10%

**Maximum reduction: -35%** (perfect typing + speed bonus)

**Implementation Status:** Frontend implemented in `apps/web/src/lib/features/typing/`

**Related:** [[FR-CORE-003]]

---

### 🧠 FR-GAME-002: Hack Runs

**What:** Multi-node roguelike game that earns temporary yield multipliers.

**Planned approach:**

Structure:
```
START -> NODE 1 -> NODE 2 -> NODE 3 -> NODE 4 -> NODE 5 -> EXTRACT
         FIREWALL   PATROL   DATA CACHE   TRAP    ICE WALL
```

Node Types:

| Type | Risk | Reward | Typing Difficulty |
|------|------|--------|-------------------|
| FIREWALL | Medium | Standard | Medium |
| PATROL | Low | Low | Easy |
| DATA CACHE | High | High | Medium |
| TRAP | Very High | Skip reward | Hard |
| ICE WALL | Medium | Standard | Very Hard |
| HONEYPOT | Variable | Variable | Tricky |
| BACKDOOR | Low | Shortcut | Easy |

Run Completion Rewards:

| Result | Yield Multiplier | Duration |
|--------|------------------|----------|
| Failed (died) | None (lose entry) | - |
| Survived 3/5 | 1.25x yield | 4 hours |
| Survived 4/5 | 1.5x yield | 4 hours |
| Survived 5/5 | 2x yield | 4 hours |
| Perfect (no dmg) | 3x yield | 4 hours |

**Entry Fee:** 50-200 $DATA (configurable)

**Notes:**

Complex feature requiring significant frontend work. Deferred to later phase.

**Related:** [[FR-CORE-005]]

---

### 🧠 FR-GAME-003: Dead Pool

**What:** Prediction market for betting on network outcomes.

**Planned approach:**

Parimutuel betting pool where winners split losers' pool minus rake.

Pool Types:

| Round Type | Question | Options | Frequency |
|------------|----------|---------|-----------|
| Death Count | How many traced? | Over/Under line | Every scan |
| Level Collapse | Will timer hit zero? | Yes/No | Continuous |
| Whale Watch | Will 1000+ $DATA position die? | Yes/No | Every scan |
| Survival Streak | Will anyone hit 20 streak? | Yes/No | Daily |
| Perfect Run | Will anyone complete perfect hack run? | Yes/No | Hourly |

Resolution Example:
```
Total Pool: 20,000 $DATA
- UNDER bets: 12,000 $DATA (60%)
- OVER bets: 8,000 $DATA (40%)

RESULT: 67 deaths (OVER wins)

DISTRIBUTION:
- 5% Rake -> BURNED (1,000 $DATA)
- Remaining: 19,000 $DATA
- Split among OVER bettors proportionally
```

**Hedge Strategy:** Players can bet against their own survival to reduce variance.

**Notes:**

Requires oracle infrastructure for outcome verification. Deferred to later phase.

**Related:** [[FR-ECON-006]]

---

### 🚧 FR-GAME-004: Hash Crash

**What:** Casino crash game where players bet on a rising multiplier.

**Implementation Status:** Contract complete (84 tests), frontend complete, deployed to MegaETH testnet.

**How it works:**

1. **Betting Phase** (60 seconds): Players place bets
2. **Lock Phase** (3 blocks): Seed committed to future block
3. **Crash Phase**: Multiplier rises exponentially until crash point revealed
4. **Settlement**: Players who cashed out below crash point win

**Entry:** 10-1000 $DATA per round

**Burn:** 3% rake on all bets

**Crash Point Generation:**

Uses future block hash (FutureBlockRandomness) for provably fair crash points:
- House edge ~3%
- Crash distribution: 1% chance of 1.00x (instant crash)

**Theme:** "Network Penetration" - Multiplier represents "depth" into enemy firewall

**Contracts:**
- `HashCrash.sol` - Game logic
- `ArcadeCore.sol` - Session tracking, payouts

**Frontend:** `apps/web/src/lib/features/hash-crash/`

**Testnet Addresses:**
- ArcadeCore: `0xC65338Eda8F8AEaDf89bA95042b99116dD899BD0`
- HashCrash: `0x037e0554f10e5447e08e4EDdbB16d8D8F402F785`

**Related:** [[FR-ECON-006]]

---

### 🚧 FR-GAME-005: Code Duel

**What:** 1v1 competitive typing battles with wagered stakes.

**Implementation Status:** Contract complete (101 tests with 94.74% branch coverage), awaiting matchmaking service.

**How it works:**

1. Players queue with selected stake tier
2. Matchmaking pairs players with similar stakes
3. Both players type the same hacker command
4. First to complete with required accuracy wins
5. Winner takes pot minus burn

**Stake Tiers:**

| Tier | Entry | Winner Receives |
|------|-------|-----------------|
| Bronze | 50 $DATA | 90 $DATA |
| Silver | 150 $DATA | 270 $DATA |
| Gold | 300 $DATA | 540 $DATA |
| Diamond | 500 $DATA | 900 $DATA |

**Burn:** 10% of pot

**Outcomes:**
- WIN: Winner gets entire prize pool
- TIE: 45%/45% split, additional 10% burn
- FORFEIT: Non-joiner forfeits, opponent wins
- TIMEOUT: Both players can refund (net of rake)

**Contracts:** `DuelEscrow.sol`

**Notes:**

Requires `arcade-coordinator` backend service for matchmaking (not yet implemented).

**Related:** [[FR-GAME-001]]

---

### 🚧 FR-GAME-006: Daily Ops

**What:** Daily engagement system with streak rewards and death rate reduction.

**Implementation Status:** Contract complete (36 tests), frontend complete, awaiting testnet deployment.

**How it works:**

1. Daily missions appear (typing challenges, check-ins)
2. Completing missions earns streak progress
3. Consecutive days build streak with milestones
4. Streaks provide passive death rate reduction
5. Shields can protect streaks from breaks

**Missions:**
- Signal Check: Complete 1 typing challenge (+5% yield)
- Network Patrol: Check in 3 times (-3% death rate)
- Data Packet: Claim daily $DATA (10 $DATA free)
- Crew Sync: 3 crew members complete dailies (+10% crew bonus)
- Streak Keeper: 7-day streak (100 $DATA bonus)

**Streak Death Rate Reduction:**

| Streak | Reduction |
|--------|-----------|
| 7 days | -3% |
| 21 days | -5% |
| 30 days | -8% |
| 90 days | -10% |

**Badges:**
- Week Warrior (7 days)
- Dedicated Operator (30 days)
- Legend (90 days)

**Shields:**
- 1-day Shield: 50 $DATA (burned)
- 7-day Shield: 200 $DATA (burned)

**Contracts:** `DailyOps.sol`

**Frontend:** `apps/web/src/lib/features/daily/`

**Related:** [[FR-CORE-003]], [[FR-ECON-006]]

---

### 🟣 FR-GAME-007: ICE Breaker

**What:** Skill-based typing game with 100% entry burn.

**Entry:** 25 $DATA (100% burned)

**Specification:** See `docs/design/arcade/games/04-ice-breaker.md`

---

### 🟣 FR-GAME-008: Binary Bet

**What:** Binary options game using commit-reveal pattern.

**Entry:** 10-500 $DATA

**Burn:** 5% rake

**Specification:** See `docs/design/arcade/games/05-binary-bet.md`

---

### 🟣 FR-GAME-009: Bounty Hunt

**What:** Strategy game with complex mechanics.

**Entry:** 50-500 $DATA (100% burned)

**Specification:** See `docs/design/arcade/games/06-bounty-hunt.md`

---

### 🟣 FR-GAME-010: Memory Dump (Slot Machine)

**What:** Cyberpunk-themed slot machine where players "dump" corrupted memory sectors to extract data fragments.

**Entry:** 5-100 $DATA per spin

**Burn:** 5% rake (burned immediately)

**Thematic Framing:**

Not a "slot machine" - it's a **Memory Sector Dump**:
- "Spin" = "DUMP SECTOR"
- "Reels" = "Memory Banks"  
- "Symbols" = "Data Fragments"
- "Jackpot" = "CORE DUMP"
- "Bet" = "Extraction Fee"

**Core Mechanics:**

5 reels, 3 rows, 9 paylines. Players select extraction fee and dump sectors.

**Symbol Set:**

| Symbol | Name | Rarity | 3-Match | 4-Match | 5-Match |
|--------|------|--------|---------|---------|---------|
| 👻 `[GH]` | GHOST | Common | 2x | 5x | 10x |
| 💀 `[TR]` | TRACE | Common | 2x | 5x | 10x |
| 🔥 `[BN]` | BURN | Common | 2x | 5x | 10x |
| 📊 `[DA]` | DATA | Uncommon | 5x | 15x | 50x |
| 🔐 `[CR]` | CRYPTO | Uncommon | 5x | 15x | 50x |
| ⚡ `[VT]` | VOLT | Rare | 10x | 50x | 200x |
| 🌐 `[NT]` | NET | Rare | 10x | 50x | 200x |
| 💎 `[CO]` | CORE | Epic | 25x | 100x | 500x |
| 🎰 `[**]` | WILD | Legendary | - | - | 1000x |
| 🕳️ `[//]` | VOID | Special | Triggers bonus |

**Payline Configuration:**

```
Line 1: ─ ─ ─ ─ ─  (middle row)
Line 2: ▔ ▔ ▔ ▔ ▔  (top row)  
Line 3: ▁ ▁ ▁ ▁ ▁  (bottom row)
Line 4: ╲         (diagonal TL→BR)
Line 5: ╱         (diagonal BL→TR)
Line 6: ∨ ─ ─ ─ ∧ (V shape)
Line 7: ∧ ─ ─ ─ ∨ (inverted V)
Line 8: ─ ∨ ─ ∧ ─ (W shape)
Line 9: ─ ∧ ─ ∨ ─ (M shape)
```

**Special Features:**

1. **CORE DUMP (Jackpot)**
   - 5x CORE symbols = Progressive jackpot
   - 1% of all bets feed jackpot pool
   - Full screen celebration animation

2. **VOID SCATTER (Bonus Round)**
   - 3+ VOID symbols triggers "Deep Memory Access"
   - Player picks 3 of 6 memory addresses
   - Each reveals multiplier (2x, 5x, 10x, 25x, 50x) or BUST
   - BUST ends bonus immediately

3. **GHOST CHAIN (Streak Bonus)**
   - Consecutive wins increase multiplier:
     - 2 wins: 1.5x next win
     - 3 wins: 2x next win
     - 4 wins: 3x next win
     - 5+ wins: 5x + FREE DUMP
   - Chain breaks on any loss

4. **MEMORY CORRUPTION (Risk Feature)**
   - After any win, option to double-or-nothing
   - 50/50 coin flip: EXTRACT (take winnings) or CORRUPT (risk for 2x)
   - Auto-extracts after 5 second timeout

**Volatility Modes:**

| Mode | RTP | Max Win | Description |
|------|-----|---------|-------------|
| LOW | 96% | 100x | Stable memory - frequent small wins |
| MEDIUM | 94% | 500x | Standard sector - balanced (default) |
| HIGH | 92% | 2000x | Corrupted zone - rare big wins |
| EXTREME | 88% | 5000x | Black Ice memory - jackpot hunting |

**Economics:**

```
Extraction Fee Breakdown (100 $DATA bet):
├── 90 $DATA → Prize Pool (RTP ~94%)
├── 5 $DATA  → BURNED 🔥 (The Furnace)
├── 3 $DATA  → Progressive Jackpot
└── 2 $DATA  → Protocol Revenue

BURNS PER 1,000 $DATA WAGERED: ~50 $DATA
```

**GHOSTNET Integration:**

Rare bonus drops can grant main game boosts:

| Rare Drop | Effect | Duration |
|-----------|--------|----------|
| GHOST PROTOCOL | -5% death rate | 2 hours |
| DATA CACHE | +10% yield | 4 hours |
| VOLT SURGE | 1.5x hack run rewards | 1 run |
| CORE FRAGMENT | Exclusive high-roller access | 1 session |

**Visual Design:**

```
╔══════════════════════════════════════════════════════════════════╗
║  MEMORY DUMP v1.0 ░░░░░░░░░░░░░░░░░░░░░░░░░  SECTOR: ACTIVE     ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║   BALANCE: 1,247 $DATA            LAST WIN: +125 $DATA          ║
║                                                                  ║
║  ┌──────────────────────────────────────────────────────────┐   ║
║  │   ╔═══════╗ ╔═══════╗ ╔═══════╗ ╔═══════╗ ╔═══════╗    │   ║
║  │   ║  GH  ║ ║  TR  ║ ║  GH  ║ ║  BN  ║ ║  GH  ║    │   ║
║  │   ╚═══════╝ ╚═══════╝ ╚═══════╝ ╚═══════╝ ╚═══════╝    │   ║
║  │                    3x GHOST = 10x                        │   ║
║  └──────────────────────────────────────────────────────────┘   ║
║                                                                  ║
║   EXTRACTION FEE: [5] [10] [25] [50] [100] $DATA                ║
║                                                                  ║
║              ┌────────────────────────────┐                     ║
║              │      [ DUMP SECTOR ]       │                     ║
║              └────────────────────────────┘                     ║
║                                                                  ║
║   VOLATILITY: ███████░░░ MEDIUM         RTP: 94%                ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

**Audio Design:**

| Event | Sound | Description |
|-------|-------|-------------|
| Dump Start | `whir-click` | Hard drive spin-up |
| Reel Spinning | `digital-scroll` | Fast data streaming |
| Reel Stop | `lock-beep` | Terminal confirmation |
| Small Win | `data-chime` | Pleasant extraction |
| Big Win | `jackpot-alarm` | Sirens + celebration |
| CORE DUMP | `explosion-glitch` | Screen shake + chaos |
| Loss | `static-buzz` | Brief corruption noise |
| Ghost Chain | `combo-escalate` | Rising pitch per streak |

**Animation Sequences:**

- **Dump Sequence**: Reels blur with scanlines, lock left-to-right with staggered timing
- **Win Celebration**: Scaled by win size (pulse → glow → particles → screen shake)
- **CORE DUMP**: Full blackout → text typeout → explosive reveal → confetti

**Implementation:**

```
Route: /arcade/memory-dump

Components:
/lib/features/memory-dump/
├── components/
│   ├── SlotMachine.svelte        # Main game container
│   ├── Reel.svelte               # Individual reel with symbols
│   ├── Symbol.svelte             # Symbol display + animations
│   ├── PaylineOverlay.svelte     # Winning line highlights
│   ├── BetSelector.svelte        # Extraction fee picker
│   ├── PaytableModal.svelte      # Payout information
│   ├── BonusRound.svelte         # Deep Memory Access mini-game
│   ├── CorruptionGamble.svelte   # Risk feature overlay
│   ├── WinDisplay.svelte         # Win celebration overlay
│   └── RecentDumps.svelte        # Activity feed
├── store.svelte.ts               # Game state machine
├── symbols.ts                    # Symbol definitions + weights
├── paylines.ts                   # Payline configurations  
├── audio.ts                      # Sound effects
└── rng.ts                        # Provably fair (Chainlink VRF)
```

**Contracts:**

Will use shared `ArcadeCore.sol` for session tracking and payouts.
New contract: `MemoryDump.sol` for game-specific logic.

**Provably Fair:**

Uses FutureBlockRandomness pattern:
1. Player commits bet
2. Contract records future block number (current + 3)
3. When that block is mined, its hash determines outcome
4. Player can verify: `keccak256(blockHash, nonce) % weights`

**Implementation Phases:**

1. **Phase 1**: Core slot mechanics (reels, symbols, paylines, basic wins)
2. **Phase 2**: Audio + animations (satisfaction layer)
3. **Phase 3**: Special features (Ghost Chain, Corruption gamble)
4. **Phase 4**: VOID bonus round
5. **Phase 5**: Progressive jackpot + GHOSTNET integration
6. **Phase 6**: Provably fair on-chain verification

**Related:** [[FR-ECON-006]], [[FR-GAME-004]]

---

## Domain Rules

### Business Rules

| Rule | Description |
|------|-------------|
| Death reduction capped | Maximum -35% from all sources combined |
| Multipliers stack additively | 1.5x + crew 10% = 1.6x total |
| Session isolation | Mini-game sessions cannot affect core game positions |
| Provably fair | All randomness uses future block hash pattern (see [ADR-001](../../decisions/ADR-001-randomness-strategy.md)) |

### Validation Rules

| Field | Rule | Error |
|-------|------|-------|
| Entry amount | Within game's min/max | "Invalid entry amount" |
| Player has position | Must be jacked in for some games | "Must have active position" |

---

## Domain Invariants

> [!warning] Must Always Be True

1. **Burns are immediate** - Entry burns happen atomically with session creation
2. **Payouts bounded** - Cannot exceed session prize pool
3. **Double settlement prevented** - Sessions can only be settled once
4. **Randomness verifiable** - All random outcomes can be verified on-chain

---

## Integration Points

### With Core Domain

- Trace Evasion affects death rate
- Hack Runs affect yield multiplier
- Daily Ops affects death rate

### With Economy Domain

- Entry fees contribute to burns
- Rake contributes to burns

### With Social Domain

- Code Duel is competitive
- Daily Ops has crew component
- Results stream to Feed

---

## Related

- [[design/arcade/]] - Detailed game specifications
- [[core#trace-scan]] - Death rate system
- [[economy#minigame-entry]] - Burn mechanics
- `docs/design/arcade/OVERVIEW.md` - Implementation status
