# GHOSTNET Phase 3: Minigame Expansion

## The Arcade Update

**Version:** 1.0  
**Status:** Planning  
**Target:** Q2 2026  

---

## Executive Summary

Phase 3 transforms GHOSTNET from a survival game with mini-games into a full **cyber arcade** experience. We're adding 9 new games across 3 sub-phases, each designed to:

1. **Increase engagement** - More reasons to stay in the app
2. **Diversify skill expression** - Not just typing speed
3. **Deepen social mechanics** - Crew battles, spectator betting
4. **Expand burn vectors** - Every game burns $DATA
5. **Create content moments** - Streamable, shareable drama

---

## Phase Structure

```
PHASE 3: THE ARCADE UPDATE
══════════════════════════════════════════════════════════════════

PHASE 3A: QUICK WINS (Weeks 1-4)
├── HASH CRASH      - Multiplier crash game
├── CODE DUEL       - 1v1 typing battles  
└── DAILY OPS       - Daily challenge system

PHASE 3B: SKILL EXPANSION (Weeks 5-10)
├── ICE BREAKER     - Reaction time game
├── BINARY BET      - Provably fair coin flip
└── BOUNTY HUNT     - Strategic target acquisition

PHASE 3C: DEEP ENGAGEMENT (Weeks 11-18)
├── PROXY WAR       - Crew vs crew battles
├── ZERO DAY        - Multi-skill exploit chains
└── SHADOW PROTOCOL - Stealth mode mechanic

══════════════════════════════════════════════════════════════════
```

---

## Game Overview Matrix

| Game | Category | Skill Type | Entry Cost | Burn Rate | Social |
|------|----------|------------|------------|-----------|--------|
| HASH CRASH | Casino | Timing | 10-1000 $DATA | 3% | Spectate |
| CODE DUEL | Competitive | Typing | 50-500 $DATA | 10% | 1v1 + Spectate |
| DAILY OPS | Progression | Mixed | Free | Streak rewards | Leaderboard |
| ICE BREAKER | Skill | Reaction | 25 $DATA | 100% entry | Solo |
| BINARY BET | Casino | Prediction | 10-500 $DATA | 5% | Multiplayer |
| BOUNTY HUNT | Strategy | Decision | 50-500 $DATA | 100% entry | Solo |
| PROXY WAR | Team | Mixed | 500 $DATA/crew | 100% loser | Crew vs Crew |
| ZERO DAY | Skill | Multi | 100 $DATA | 100% entry | Solo |
| SHADOW PROTOCOL | Meta | Strategic | 200 $DATA | 100% | Hidden |

---

## Shared Infrastructure Requirements

### 1. Game Engine Foundation

```
apps/web/src/lib/features/arcade/
├── engine/
│   ├── GameEngine.svelte.ts      # Base game state machine
│   ├── TimerSystem.svelte.ts     # Countdown/stopwatch utilities
│   ├── ScoreSystem.svelte.ts     # Points, multipliers, combos
│   └── RewardSystem.svelte.ts    # Payout calculations
├── matchmaking/
│   ├── MatchQueue.svelte.ts      # PvP matchmaking
│   ├── SpectatorManager.ts       # Watch mode
│   └── BettingPool.svelte.ts     # Spectator wagering
├── ui/
│   ├── GameShell.svelte          # Standard game container
│   ├── Countdown.svelte          # Pre-game countdown
│   ├── ResultsScreen.svelte      # Post-game summary
│   └── Leaderboard.svelte        # Rankings display
└── types/
    └── arcade.ts                 # Shared type definitions
```

### 2. Smart Contract Architecture

```
packages/contracts/src/arcade/
├── ArcadeCore.sol           # Game registry, entry fees, payouts
├── games/
│   ├── HashCrash.sol        # Crash game logic
│   ├── BinaryBet.sol        # Coin flip with block hash
│   ├── DuelEscrow.sol       # 1v1 wager escrow
│   └── BountyPool.sol       # Bounty hunt prize pools
├── social/
│   ├── SpectatorBets.sol    # Side betting on games
│   └── ProxyWarTerritory.sol # Crew territory control
└── interfaces/
    └── IArcadeGame.sol      # Standard game interface
```

### 3. Backend Services

```
services/arcade-coordinator/
├── src/
│   ├── matchmaking/         # Real-time match coordination
│   ├── randomness/          # VRF coordination for fair games
│   ├── leaderboards/        # Score aggregation
│   └── events/              # Game event streaming
└── Cargo.toml
```

---

## Document Index

### Master Documents
- **[OVERVIEW.md](./OVERVIEW.md)** - Implementation tracker with status, tasks, and progress
- **[README.md](./README.md)** - This file (executive summary)

### Game Design Documents
- [HASH CRASH](./games/01-hash-crash.md) - Multiplier crash game
- [CODE DUEL](./games/02-code-duel.md) - 1v1 typing battles
- [DAILY OPS](./games/03-daily-ops.md) - Daily challenge system
- [ICE BREAKER](./games/04-ice-breaker.md) - Reaction time game
- [BINARY BET](./games/05-binary-bet.md) - Provably fair betting
- [BOUNTY HUNT](./games/06-bounty-hunt.md) - Strategic target game
- [PROXY WAR](./games/07-proxy-war.md) - Crew battles
- [ZERO DAY](./games/08-zero-day.md) - Exploit chain puzzles
- [SHADOW PROTOCOL](./games/09-shadow-protocol.md) - Stealth mechanic

### Infrastructure Documents
- [Game Engine Architecture](./infrastructure/game-engine.md)
- [Smart Contract Specs](./infrastructure/contracts.md)
- [Matchmaking System](./infrastructure/matchmaking.md)
- [Randomness & Fairness](./infrastructure/randomness.md)

### Design Documents
- [Visual Design System](./designs/visual-system.md)
- [Sound Design](./designs/sound-design.md)
- [Animation Specifications](./designs/animations.md)

---

## Timeline

```
WEEK  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18
      ─────────────────────────────────────────────────────
3A    ████████████████
      HASH   CODE  DAILY
      CRASH  DUEL  OPS

3B                   ████████████████████████
                     ICE     BINARY  BOUNTY
                     BREAKER BET     HUNT

3C                                        ████████████████████████
                                          PROXY  ZERO   SHADOW
                                          WAR    DAY    PROTOCOL
```

---

## Success Metrics

| Metric | Current | Phase 3A Target | Phase 3C Target |
|--------|---------|-----------------|-----------------|
| Daily Active Users | Baseline | +30% | +100% |
| Avg Session Time | Baseline | +20% | +50% |
| Daily $DATA Burned | Baseline | +40% | +150% |
| Crew Participation | Baseline | +25% | +80% |
| Feed Events/Hour | Baseline | +50% | +200% |

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Game exploits | Medium | High | Extensive testing, rate limits, caps |
| Economic imbalance | Medium | High | Simulation, gradual rollout, tuning |
| Low adoption | Low | Medium | Soft launch, feedback loops, iteration |
| Smart contract bugs | Low | Critical | Audits, timelocks, upgrade patterns |
| Server overload | Medium | Medium | Load testing, auto-scaling, caching |

---

## Implementation Tracking

> **See [OVERVIEW.md](./OVERVIEW.md) for detailed implementation status, task breakdowns, and progress tracking.**

---

## Next Steps

1. **Review & Approve** - Team review of all game specs
2. **Infrastructure First** - Build shared game engine (Week 1-2)
3. **Parallel Development** - Games built on shared foundation
4. **Internal Testing** - Each game tested before mainnet
5. **Staged Rollout** - One game at a time, monitor metrics
