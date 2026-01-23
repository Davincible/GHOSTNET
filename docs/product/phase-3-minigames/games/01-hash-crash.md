# HASH CRASH

## Game Design Document

**Category:** Casino  
**Phase:** 3A (Quick Win)  
**Complexity:** Low  
**Development Time:** 1 week  

---

## Overview

HASH CRASH is a **pre-commit crash prediction game**. Players bet $DATA and choose a target cash-out multiplier BEFORE the crash point is revealed. If the crash point exceeds your target, you win. If not, you lose everything.

This model eliminates timing advantages (no bot sniping) while maintaining the excitement of crash games through client-side animations.

```
╔══════════════════════════════════════════════════════════════════╗
║                         HASH CRASH                                ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║                         MULTIPLIER                                ║
║                                                                   ║
║                          ██  5.67x                                ║
║                         ██                                        ║
║                        ██      YOUR TARGET: 3.00x ✓               ║
║                       ██       ───────────────────                ║
║                     ███        You're SAFE!                       ║
║                   ███                                             ║
║                ████                                               ║
║           ██████                                                  ║
║     ████████                                                      ║
║  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀  ║
║                                                                   ║
║  YOUR BET: 100 $DATA @ 3.00x         PAYOUT: 300 $DATA           ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  RECENT CRASHES: 1.23x │ 4.56x │ 12.34x │ 1.01x │ 89.12x         ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Core Mechanics

### Game Model: Pre-Commit vs. Real-Time

Traditional crash games let players cash out in real-time, creating timing races and bot advantages. HASH CRASH uses a **pre-commit model**:

| Aspect | Traditional Crash | HASH CRASH (Pre-Commit) |
|--------|-------------------|-------------------------|
| Cash-out timing | Real-time during game | **Set BEFORE game starts** |
| Bot advantage | High (can read chain state) | **None** (blind commitment) |
| Outcome determination | When you click | **Instant on reveal** |
| Animation purpose | Determines outcome | **Pure entertainment** |
| Fairness | Timing-dependent | **Mathematically pure** |

### Game Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           HASH CRASH GAME FLOW                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. BETTING PHASE (60 seconds)                                              │
│     └─ Players place bets: 100 $DATA                                        │
│     └─ Players set target: 2.50x                                            │
│     └─ BOTH are locked in together                                          │
│     └─ No changes after betting closes                                      │
│                                                                             │
│  2. LOCK PHASE (~3 blocks)                                                  │
│     └─ Betting closes                                                       │
│     └─ Contract commits to future block hash                                │
│     └─ No one knows the crash point yet                                     │
│                                                                             │
│  3. REVEAL + SETTLE (instant)                                               │
│     └─ Future block is mined                                                │
│     └─ Crash point calculated from block hash: 3.47x                        │
│     └─ All bets instantly resolved:                                         │
│         • Target 2.50x < 3.47x → WIN (payout = 250 $DATA)                  │
│         • Target 5.00x > 3.47x → LOSE (bet burned)                         │
│                                                                             │
│  4. ANIMATION PHASE (client-side only)                                      │
│     └─ Client shows multiplier climbing: 1.00 → 1.50 → 2.50 ✓ → 3.47 💥    │
│     └─ Creates excitement even though outcome is determined                 │
│     └─ Players see "danger zone" as it approaches their target              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Why Pre-Commit Works

**Problem with real-time cash-out:**
1. Crash point is revealed on-chain
2. Bots read the crash point instantly
3. Bots cash out at `crashPoint - 1` (guaranteed max payout)
4. Human players always lose to bots

**Pre-commit solution:**
1. Players commit bet + target BEFORE reveal
2. No one knows crash point during betting
3. After reveal, outcomes are instant (no timing race)
4. Everyone plays on equal footing

### Crash Point Algorithm

Crash point is determined by **future block hash** — provably fair on-chain randomness:

```javascript
// Crash point calculation
function calculateCrashPoint(blockHashSeed: bytes32): number {
  // Convert block hash to uniform random [0, 1)
  const random = uint256(blockHashSeed) / MAX_UINT256;
  
  // House edge: 4%
  const houseEdge = 0.04;
  
  // Crash point formula (inverse of cumulative distribution)
  const crashPoint = (1 - houseEdge) / (1 - random);
  
  // Minimum crash at 1.00x
  return Math.max(1.00, crashPoint);
}
```

**Crash Point Distribution:**

| Crash Point | Probability | Win if Target ≤ |
|-------------|-------------|-----------------|
| < 1.5x | 35% | ~35% win rate |
| 1.5x - 2x | 17% | ~52% win rate |
| 2x - 3x | 15% | ~67% win rate |
| 3x - 5x | 12% | ~79% win rate |
| 5x - 10x | 10% | ~89% win rate |
| 10x - 50x | 8% | ~97% win rate |
| 50x - 100x | 2% | ~99% win rate |
| > 100x | 1% | ~100% win rate |

---

## User Interface

### Betting Phase

```
╔══════════════════════════════════════════════════════════════════╗
║  HASH CRASH                           BETTING CLOSES IN: 47      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  PLACE YOUR BET                                                   ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │                                                            │  ║
║  │  Bet Amount:    [    100    ] $DATA                        │  ║
║  │                                                            │  ║
║  │  Quick Bet:     [10] [50] [100] [500] [MAX]               │  ║
║  │                                                            │  ║
║  │  ──────────────────────────────────────────────────────── │  ║
║  │                                                            │  ║
║  │  Cash Out At:   [   2.50   ] x                             │  ║
║  │                                                            │  ║
║  │  Quick Target:  [1.5x] [2x] [3x] [5x] [10x]               │  ║
║  │                                                            │  ║
║  │  ──────────────────────────────────────────────────────── │  ║
║  │                                                            │  ║
║  │  If crash > 2.50x:   WIN   +150 $DATA  (250 total)        │  ║
║  │  If crash ≤ 2.50x:   LOSE  -100 $DATA                     │  ║
║  │                                                            │  ║
║  │  Win Probability:    ~61%                                  │  ║
║  │  Expected Value:     97 $DATA (house edge: 4%)            │  ║
║  │                                                            │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                   ║
║                      [ PLACE BET ]                                ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  OTHER PLAYERS:                                                   ║
║  0x7a3f  100 $DATA  @ 1.50x                                      ║
║  0x9c2d  500 $DATA  @ 3.00x                                      ║
║  0x3b1a   50 $DATA  @ 10.00x                                     ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Waiting for Reveal

```
╔══════════════════════════════════════════════════════════════════╗
║  HASH CRASH                           ROUND #4,847               ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║                    WAITING FOR BLOCK #18,234,567                  ║
║                                                                   ║
║                         ▓▓▓░░░░░░░                               ║
║                         3 blocks remaining                        ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  YOUR BET: 100 $DATA @ 2.50x                                     ║
║  ─────────────────────────────────────────────────────────────── ║
║  47 players waiting │ 12,450 $DATA in pot                        ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Animation Phase (Outcome Already Determined)

```
╔══════════════════════════════════════════════════════════════════╗
║  HASH CRASH                           ROUND #4,847               ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║                          2.31x                                    ║
║                                                                   ║
║           ████████████████████                                    ║
║         ██████████████████                                        ║
║       ████████████████       YOUR TARGET: 2.50x                  ║
║     ██████████████           ─────────────────                    ║
║   ████████████               Almost there...                      ║
║  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀  ║
║                    ↑                                              ║
║               Your target                                         ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  ✓ 0x7a3f  1.50x  SAFE                                           ║
║  ? 0x9c2d  3.00x  waiting...                                     ║
║  ? 0x3b1a  10.00x waiting...                                     ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Result - Win

```
╔══════════════════════════════════════════════════════════════════╗
║  HASH CRASH                           ROUND #4,847               ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║               💥 CRASHED @ 3.47x 💥                               ║
║                                                                   ║
║                    ░░░░░░░░░░░░░░░░░░░░                          ║
║                  ░░░░░░░░░░░░░░░░░░                              ║
║                ░░░░░░░░░░░░░░░░                                  ║
║              ░░░░░░░░░░░░░░                                      ║
║            ░░░░░░░░░░░░                                          ║
║  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀  ║
║                                                                   ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │                                                            │  ║
║  │       ✓ YOU WIN!  Target 2.50x < Crash 3.47x              │  ║
║  │                                                            │  ║
║  │       Bet: 100 $DATA  →  Payout: 250 $DATA                │  ║
║  │       Profit: +150 $DATA                                   │  ║
║  │                                                            │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  ✓ 0x7a3f   1.50x  WON +50 $DATA                                 ║
║  ✓ YOU      2.50x  WON +150 $DATA                                ║
║  ✓ 0x9c2d   3.00x  WON +1000 $DATA                               ║
║  ✗ 0x3b1a  10.00x  CRASHED -50 $DATA                             ║
║                                                                   ║
║  TOTAL BURNED: 423 $DATA 🔥                                      ║
║                                                                   ║
║                    NEXT ROUND IN: 05                              ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Economic Model

### Entry & Fees

| Parameter | Value |
|-----------|-------|
| Minimum Bet | 10 $DATA |
| Maximum Bet | 1,000 $DATA |
| Maximum Players | 50 per round |
| House Edge | 4% (built into crash formula) |
| Rake | 3% on entry (sent to ArcadeCore) |
| Burn Rate | 100% of loser bets |

### Win/Loss Determination

```
IF player.targetMultiplier < round.crashPoint:
    WINNER → Payout = bet × targetMultiplier
ELSE:
    LOSER → Bet is burned
```

### Example Round

```
Round #4,847
─────────────────────────────────────────────────
Crash Point: 3.47x (revealed from block hash)

Player A:  100 $DATA @ 1.50x → WIN  → 150 $DATA (profit: +50)
Player B:  100 $DATA @ 2.50x → WIN  → 250 $DATA (profit: +150)
Player C:  500 $DATA @ 3.00x → WIN  → 1500 $DATA (profit: +1000)
Player D:   50 $DATA @ 5.00x → LOSE → 0 $DATA (burned: 50)
Player E:  200 $DATA @ 10.0x → LOSE → 0 $DATA (burned: 200)
─────────────────────────────────────────────────
Total Wagered:   950 $DATA
Total Payouts:  1900 $DATA
Total Burned:    250 $DATA (losers)
Net from Pool:   950 $DATA (winners draw from losers + rake)
```

### Expected Value

No matter what target you choose, the **expected value is ~96%** due to the crash point distribution:

| Target | Win Probability | Payout if Win | Expected Value |
|--------|-----------------|---------------|----------------|
| 1.10x | ~88% | 1.10x | 0.97x |
| 1.50x | ~65% | 1.50x | 0.97x |
| 2.00x | ~49% | 2.00x | 0.97x |
| 5.00x | ~19% | 5.00x | 0.97x |
| 10.00x | ~10% | 10.00x | 0.97x |

The house edge is **mathematically guaranteed** regardless of player strategy.

---

## Technical Implementation

### Smart Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @title HashCrash - Pre-Commit Crash Game
/// @notice Players commit bet + target multiplier before crash point is revealed
/// @dev Eliminates timing races and bot advantages through blind commitment
contract HashCrash is FutureBlockRandomness, ReentrancyGuard, Pausable {
    
    // ══════════════════════════════════════════════════════════════════
    // TYPES
    // ══════════════════════════════════════════════════════════════════
    
    enum RoundState { 
        NONE,       // Round doesn't exist
        BETTING,    // Accepting bets + targets
        LOCKED,     // Waiting for seed block
        REVEALED,   // Crash point known, settling
        SETTLED     // All players paid/burned
    }
    
    struct Round {
        RoundState state;
        uint64 bettingEndTime;
        uint256 prizePool;
        uint256 crashMultiplier;  // 0 until revealed (in basis points, 250 = 2.50x)
        uint256 playerCount;
    }
    
    struct PlayerBet {
        uint128 amount;           // Bet amount (after rake)
        uint128 targetMultiplier; // Target cash-out (in basis points, 250 = 2.50x)
        bool settled;
    }

    // ══════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════
    
    uint256 public constant MULTIPLIER_PRECISION = 100;  // 2 decimal places
    uint256 public constant MIN_TARGET = 101;            // 1.01x minimum
    uint256 public constant MAX_TARGET = 10000;          // 100.00x maximum
    uint256 public constant BETTING_DURATION = 60 seconds;
    uint256 public constant MAX_PLAYERS = 50;
    uint256 public constant HOUSE_EDGE_BPS = 400;        // 4%

    // ══════════════════════════════════════════════════════════════════
    // PLAYER FUNCTIONS
    // ══════════════════════════════════════════════════════════════════

    /// @notice Place bet with pre-committed target multiplier
    /// @param amount Bet amount in $DATA
    /// @param targetMultiplier Target cash-out in basis points (250 = 2.50x)
    function placeBet(uint256 amount, uint256 targetMultiplier) external nonReentrant {
        Round storage round = _rounds[_currentRoundId];
        
        // Validate round state
        require(round.state == RoundState.BETTING, "Not betting phase");
        require(block.timestamp < round.bettingEndTime, "Betting closed");
        require(round.playerCount < MAX_PLAYERS, "Round full");
        
        // Validate target
        require(targetMultiplier >= MIN_TARGET, "Target too low");
        require(targetMultiplier <= MAX_TARGET, "Target too high");
        
        // Validate no existing bet
        require(_playerBets[_currentRoundId][msg.sender].amount == 0, "Already bet");
        
        // Process entry through ArcadeCore (handles rake)
        uint256 netAmount = arcadeCore.processEntry(msg.sender, amount, _currentRoundId);
        
        // Record bet with target
        _playerBets[_currentRoundId][msg.sender] = PlayerBet({
            amount: uint128(netAmount),
            targetMultiplier: uint128(targetMultiplier),
            settled: false
        });
        
        round.prizePool += netAmount;
        round.playerCount++;
        
        emit BetPlaced(_currentRoundId, msg.sender, amount, targetMultiplier);
    }

    // ══════════════════════════════════════════════════════════════════
    // ROUND MANAGEMENT
    // ══════════════════════════════════════════════════════════════════

    /// @notice Reveal crash point from committed seed
    function reveal() external nonReentrant {
        Round storage round = _rounds[_currentRoundId];
        require(round.state == RoundState.LOCKED, "Not locked");
        
        // Get seed from future block hash
        uint256 seed = _revealSeed(_currentRoundId);
        
        // Calculate crash point
        uint256 crashMultiplier = _calculateCrashPoint(seed);
        
        round.crashMultiplier = crashMultiplier;
        round.state = RoundState.REVEALED;
        
        emit CrashPointRevealed(_currentRoundId, crashMultiplier, seed);
    }

    /// @notice Settle a player's bet (can be called by anyone)
    function settle(address player) external nonReentrant {
        Round storage round = _rounds[_currentRoundId];
        require(round.state == RoundState.REVEALED, "Not revealed");
        
        PlayerBet storage bet = _playerBets[_currentRoundId][player];
        require(bet.amount > 0, "No bet");
        require(!bet.settled, "Already settled");
        
        bet.settled = true;
        
        if (bet.targetMultiplier < round.crashMultiplier) {
            // WINNER: Target was below crash point
            uint256 payout = (uint256(bet.amount) * bet.targetMultiplier) / MULTIPLIER_PRECISION;
            arcadeCore.creditPayout(_currentRoundId, player, payout, 0, true);
            
            emit PlayerWon(_currentRoundId, player, bet.targetMultiplier, payout);
        } else {
            // LOSER: Target was at or above crash point
            arcadeCore.creditPayout(_currentRoundId, player, 0, bet.amount, false);
            
            emit PlayerLost(_currentRoundId, player, bet.targetMultiplier, round.crashMultiplier);
        }
    }

    /// @notice Batch settle all players
    function settleAll() external nonReentrant {
        // Iterate through all players and settle
    }

    // ══════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ══════════════════════════════════════════════════════════════════

    /// @notice Calculate crash point from seed
    /// @dev Formula: crashPoint = (1 - houseEdge) / (1 - random)
    function _calculateCrashPoint(uint256 seed) internal pure returns (uint256) {
        // Use lower bits for uniform random in [0, 10000)
        uint256 random = seed % 10000;
        
        // Avoid division by zero
        if (random >= 9999) random = 9999;
        
        // crashPoint = (10000 - 400) / (10000 - random) * 100
        // = 9600 * 100 / (10000 - random)
        uint256 crashPoint = (9600 * MULTIPLIER_PRECISION) / (10000 - random);
        
        // Minimum 1.00x
        if (crashPoint < 100) crashPoint = 100;
        
        return crashPoint;
    }
}
```

### Frontend Store

```typescript
// src/lib/features/hash-crash/store.svelte.ts

import { browser } from '$app/environment';
import type { HashCrashPhase, HashCrashRound } from '$lib/core/types/arcade';
import { createCountdown, createFrameLoop } from '$lib/features/arcade/engine';

export type RoundPhase = 'idle' | 'betting' | 'locked' | 'revealed' | 'animating' | 'settled';

interface PlayerBet {
  amount: bigint;
  targetMultiplier: number;  // e.g., 2.50
}

interface PlayerResult {
  address: `0x${string}`;
  targetMultiplier: number;
  won: boolean;
  payout: bigint;
}

export function createHashCrashStore() {
  // ─────────────────────────────────────────────────────────────────
  // STATE
  // ─────────────────────────────────────────────────────────────────
  
  let phase = $state<RoundPhase>('idle');
  let roundId = $state(0);
  let crashPoint = $state<number | null>(null);      // Actual crash point (revealed)
  let displayMultiplier = $state(1.0);               // Animated display value
  let playerBet = $state<PlayerBet | null>(null);
  let playerResult = $state<'pending' | 'won' | 'lost'>('pending');
  let players = $state<PlayerResult[]>([]);
  let recentCrashPoints = $state<number[]>([]);
  
  // Timers
  const bettingCountdown = createCountdown({
    duration: 60_000,
    criticalThreshold: 10_000,
  });
  
  // Animation loop for visual multiplier climbing
  let animationStartTime = 0;
  const GROWTH_RATE = 0.06;
  
  const animationLoop = createFrameLoop((delta, time) => {
    if (phase !== 'animating' || !crashPoint) return;
    
    const elapsed = (Date.now() - animationStartTime) / 1000;
    const currentMult = Math.pow(Math.E, GROWTH_RATE * elapsed);
    
    // Check if animation reached crash point
    if (currentMult >= crashPoint) {
      displayMultiplier = crashPoint;
      animationLoop.stop();
      phase = 'settled';
    } else {
      displayMultiplier = currentMult;
      
      // Check if we passed player's target (for visual feedback)
      if (playerBet && currentMult >= playerBet.targetMultiplier && playerResult === 'pending') {
        playerResult = 'won';
      }
    }
  });

  // ─────────────────────────────────────────────────────────────────
  // DERIVED
  // ─────────────────────────────────────────────────────────────────
  
  let canBet = $derived(phase === 'betting' && playerBet === null);
  let isAnimating = $derived(phase === 'animating');
  let hasWon = $derived(playerResult === 'won');
  let potentialPayout = $derived(
    playerBet ? BigInt(Math.floor(Number(playerBet.amount) * playerBet.targetMultiplier)) : 0n
  );

  // ─────────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────────

  async function placeBet(amount: bigint, targetMultiplier: number) {
    if (!canBet) return;
    
    // Validate
    if (targetMultiplier < 1.01 || targetMultiplier > 100) {
      throw new Error('Target must be between 1.01x and 100x');
    }
    
    // Record locally (contract call happens separately)
    playerBet = { amount, targetMultiplier };
    
    // TODO: Call contract
    // await hashCrashContract.placeBet(amount, Math.floor(targetMultiplier * 100));
  }

  function startAnimation(revealedCrashPoint: number) {
    crashPoint = revealedCrashPoint;
    displayMultiplier = 1.0;
    playerResult = 'pending';
    animationStartTime = Date.now();
    phase = 'animating';
    animationLoop.start();
    
    // Determine result immediately (even though animation is running)
    if (playerBet && playerBet.targetMultiplier < revealedCrashPoint) {
      // Will show as won once animation passes target
    } else if (playerBet) {
      // Will show as lost once animation reaches crash
      playerResult = 'lost';
    }
  }

  function reset() {
    phase = 'idle';
    crashPoint = null;
    displayMultiplier = 1.0;
    playerBet = null;
    playerResult = 'pending';
    players = [];
    animationLoop.stop();
  }

  // ─────────────────────────────────────────────────────────────────
  // SIMULATION (for demo/testing)
  // ─────────────────────────────────────────────────────────────────

  function simulateRound() {
    // Start betting
    roundId++;
    phase = 'betting';
    bettingCountdown.start(10_000);  // 10 second betting for demo
    
    // After betting, reveal and animate
    setTimeout(() => {
      phase = 'locked';
      bettingCountdown.stop();
      
      // Simulate block wait
      setTimeout(() => {
        // Random crash point
        const random = Math.random();
        const simCrashPoint = 0.96 / (1 - random);
        const clampedCrash = Math.max(1.01, Math.min(100, simCrashPoint));
        
        startAnimation(clampedCrash);
        recentCrashPoints = [clampedCrash, ...recentCrashPoints.slice(0, 9)];
      }, 2000);
    }, 10_000);
  }

  return {
    // State
    get phase() { return phase; },
    get roundId() { return roundId; },
    get crashPoint() { return crashPoint; },
    get displayMultiplier() { return displayMultiplier; },
    get playerBet() { return playerBet; },
    get playerResult() { return playerResult; },
    get players() { return players; },
    get recentCrashPoints() { return recentCrashPoints; },
    get bettingCountdown() { return bettingCountdown; },
    
    // Derived
    get canBet() { return canBet; },
    get isAnimating() { return isAnimating; },
    get hasWon() { return hasWon; },
    get potentialPayout() { return potentialPayout; },
    
    // Actions
    placeBet,
    reset,
    simulateRound,
  };
}
```

---

## Visual Design

### Color Scheme

```css
.hash-crash {
  /* Multiplier colors - shifts as value increases */
  --mult-safe: var(--color-accent);       /* Below player target */
  --mult-danger: var(--color-amber);      /* Approaching target */
  --mult-critical: var(--color-red);      /* Above target */
  
  /* Result colors */
  --result-win: var(--color-accent);
  --result-lose: var(--color-red);
}
```

### Animation Behavior

Since the outcome is already determined when the animation starts:

1. **Client knows crash point** before animation begins
2. **Animation runs at fixed speed** (not real-time blockchain)
3. **Player's target line** shown on chart
4. **"SAFE" indicator** appears when multiplier passes target
5. **Crash animation** happens at predetermined point

This creates suspense while being fully deterministic.

---

## Sound Design

| Event | Sound |
|-------|-------|
| Round Start | Low hum building |
| Multiplier Rising | Pitch increases with value |
| Passed Your Target | Triumphant "safe" chime |
| Approaching Danger | Warning pulse |
| Crash | Explosion + flatline |
| Win | Victory cha-ching |
| Lose | Deflating buzz |

---

## Testing Checklist

### Smart Contract
- [ ] Bet placement requires target multiplier
- [ ] Target must be between 1.01x and 100.00x
- [ ] Cannot change bet or target after placement
- [ ] Cannot bet after betting phase ends
- [ ] Crash point only revealed after lock phase
- [ ] Win condition: target < crashPoint
- [ ] Lose condition: target >= crashPoint
- [ ] Payout calculation: bet × target (for winners)
- [ ] Losers' bets are burned

### Frontend
- [ ] Betting UI shows both amount AND target inputs
- [ ] Win probability calculator updates with target
- [ ] Animation shows player's target line
- [ ] "SAFE" indicator when multiplier passes target
- [ ] Result is correct even before animation finishes
- [ ] Recent crash history displays correctly

### Fairness
- [ ] Crash point derived from future block hash
- [ ] No one can know crash point during betting
- [ ] Verification function matches actual crash point
- [ ] House edge mathematically correct (~4%)
