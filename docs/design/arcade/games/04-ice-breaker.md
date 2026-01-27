# ICE BREAKER

## Game Design Document

**Category:** Skill (Reaction Time)  
**Phase:** 3B (Skill Expansion)  
**Complexity:** Medium  
**Development Time:** 2 weeks  

---

## Overview

ICE BREAKER is a reaction-time game where players break through Intrusion Countermeasure Electronics (ICE) barriers by clicking/tapping weak points before they lock you out. It's a completely different skill from typing - testing reflexes and spatial awareness.

```
╔══════════════════════════════════════════════════════════════════╗
║                         ICE BREAKER                               ║
║                      Layer 7 of 12                                ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  ┌──────────────────────────────────────────────────────────┐    ║
║  │                                                           │    ║
║  │     ╔═══╗                    ╔═══╗                       │    ║
║  │     ║   ║    ┌───────┐       ║ ● ║  ← CLICK HERE        │    ║
║  │     ║   ║    │       │       ║   ║                       │    ║
║  │     ╚═══╝    │   ●   │       ╚═══╝                       │    ║
║  │              │       │                                    │    ║
║  │     ╔═══╗    └───────┘       ╔═══╗                       │    ║
║  │     ║ ● ║                    ║   ║                       │    ║
║  │     ║   ║       ╔═══╗        ║   ║                       │    ║
║  │     ╚═══╝       ║   ║        ╚═══╝                       │    ║
║  │                 ╚═══╝                                     │    ║
║  │                                                           │    ║
║  └──────────────────────────────────────────────────────────┘    ║
║                                                                   ║
║  ████████████████████░░░░░░░░░░ ICE INTEGRITY: 65%               ║
║                                                                   ║
║  TIME: 00:23.47       HITS: 18/24       HEALTH: ██████░░░░       ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Core Mechanics

### Game Flow

```
1. BRIEFING (3 seconds)
   └── Show ICE type and pattern preview
   └── Entry fee locked (25 $DATA burned)

2. BREAK PHASE (variable, ~30-60 seconds)
   └── ICE layers appear in sequence
   └── Click weak points (●) to break them
   └── Miss or timeout = damage
   └── Lose all health = run failed

3. EXTRACTION
   └── Complete all 12 layers = success
   └── Failed run = entry lost, no reward
   └── Success = reward + death rate reduction
```

### ICE Types

**Type 1: STATIC ICE**
- Weak points appear and stay visible
- Player has 2 seconds to click
- Good for beginners

**Type 2: BLINK ICE**
- Weak points flash briefly (0.5s)
- Must click while visible
- Tests attention

**Type 3: PATROL ICE**
- Weak points move across the screen
- Must track and click
- Tests tracking ability

**Type 4: SEQUENCE ICE**
- Multiple weak points appear
- Must click in specific order (numbered)
- Tests memory + speed

**Type 5: SHADOW ICE**
- Weak points are hidden
- Briefly revealed by "scan pulse" (every 2s)
- Tests timing

**Type 6: MIRROR ICE**
- Two weak points appear simultaneously
- Must click BOTH within 0.3s
- Tests coordination

**Type 7: ADAPTIVE ICE (Boss Layers)**
- Combines multiple types
- Appears on layers 4, 8, 12
- Significantly harder

### Layer Progression

```
Layer  1-3:  STATIC ICE (warmup)
Layer  4:    ADAPTIVE ICE (mini-boss)
Layer  5-7:  BLINK + PATROL ICE
Layer  8:    ADAPTIVE ICE (mid-boss)
Layer  9-11: SEQUENCE + SHADOW + MIRROR ICE
Layer  12:   FINAL ICE (all types combined)
```

### Scoring

```typescript
interface IceScore {
  layer: number;
  hitsRequired: number;
  hitsMade: number;
  perfectHits: number;      // Within 0.1s of optimal
  missedClicks: number;
  timeouts: number;
  reactionTimes: number[];  // Track each hit time
}

function calculateLayerScore(score: IceScore): number {
  const basePoints = score.hitsMade * 100;
  const perfectBonus = score.perfectHits * 50;
  const speedBonus = Math.max(0, (2000 - averageReaction(score)) * 0.1);
  const penalty = (score.missedClicks * 25) + (score.timeouts * 50);
  
  return Math.max(0, basePoints + perfectBonus + speedBonus - penalty);
}
```

### Health System

```
Starting Health: 100 HP

DAMAGE:
├── Miss click (wrong spot): -5 HP
├── Timeout (didn't click in time): -10 HP
├── Boss layer timeout: -20 HP

RECOVERY:
├── Complete layer without damage: +5 HP (max 100)

GAME OVER:
└── Health reaches 0 → Run failed
```

---

## User Interface

### Main Game Screen

```
╔══════════════════════════════════════════════════════════════════╗
║  ICE BREAKER          Layer 7/12          TIME: 00:23.47         ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  ┌──────────────────────────────────────────────────────────┐    ║
║  │                                                           │    ║
║  │                      PATROL ICE                           │    ║
║  │                                                           │    ║
║  │         ┌─────┐                                           │    ║
║  │         │     │                                           │    ║
║  │         │  ●──┼──→  (moving right)                       │    ║
║  │         │     │                                           │    ║
║  │         └─────┘                                           │    ║
║  │                                                           │    ║
║  │                           ┌─────┐                         │    ║
║  │                       ←──┼──●   │  (moving left)         │    ║
║  │                           └─────┘                         │    ║
║  │                                                           │    ║
║  │                                                           │    ║
║  └──────────────────────────────────────────────────────────┘    ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  HEALTH: ████████████████████░░░░░░░░░░ 72/100                   ║
║                                                                   ║
║  SCORE: 4,280        PERFECT HITS: 12        AVG TIME: 0.34s     ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Layer Transition

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║                     ░░░ LAYER 7 COMPLETE ░░░                     ║
║                                                                   ║
║                        HITS: 6/6 PERFECT                          ║
║                        TIME: 4.2 seconds                          ║
║                        SCORE: +820                                ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║                     NEXT: LAYER 8 (ADAPTIVE)                      ║
║                                                                   ║
║              ⚠️ WARNING: BOSS LAYER INCOMING ⚠️                  ║
║                                                                   ║
║                      Starting in: 3...                            ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Victory Screen

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║              ██╗ ██████╗███████╗    ██████╗ ██████╗  ██████╗     ║
║              ██║██╔════╝██╔════╝    ██╔══██╗██╔══██╗██╔═══██╗    ║
║              ██║██║     █████╗      ██████╔╝██████╔╝██║   ██║    ║
║              ██║██║     ██╔══╝      ██╔══██╗██╔══██╗██║   ██║    ║
║              ██║╚██████╗███████╗    ██████╔╝██║  ██║╚██████╔╝    ║
║              ╚═╝ ╚═════╝╚══════╝    ╚═════╝ ╚═╝  ╚═╝ ╚═════╝    ║
║                                                                   ║
║                       ICE SYSTEM BREACHED                         ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  FINAL SCORE: 12,450                                              ║
║  TIME: 47.3 seconds                                               ║
║  PERFECT HITS: 38/72 (53%)                                        ║
║  HEALTH REMAINING: 72/100                                         ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  REWARDS:                                                         ║
║  • -10% death rate (4 hours)                                     ║
║  • SPEED BONUS: -2% additional (under 50s)                       ║
║  • "ICE BREAKER" title unlocked                                  ║
║                                                                   ║
║           [ PLAY AGAIN ]              [ EXIT ]                    ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Failure Screen

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║           ████  SYSTEM LOCKOUT  ████                             ║
║                                                                   ║
║                   ICE BREACH FAILED                               ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  REACHED: Layer 9/12                                              ║
║  SCORE: 7,820                                                     ║
║  CAUSE: Health depleted                                           ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  ENTRY FEE: 25 $DATA (burned)                                    ║
║  REWARD: None                                                     ║
║                                                                   ║
║  TIP: Try to avoid missed clicks - they deal                     ║
║       more damage than you might expect.                          ║
║                                                                   ║
║           [ TRY AGAIN ]               [ EXIT ]                    ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Economic Model

### Entry & Rewards

| Parameter | Value |
|-----------|-------|
| Entry Fee | 25 $DATA (100% burned) |
| Base Reward | -10% death rate (4h) |
| Speed Bonus | -2% additional if <50s |
| Perfect Bonus | -3% additional if >80% perfect hits |
| Health Bonus | -2% additional if 100 HP remaining |

**Maximum Possible:** -17% death rate reduction for 4 hours

### Risk/Reward Analysis

```
Entry: 25 $DATA (lost regardless of outcome)

Expected Outcomes (based on skill):
├── Beginner: ~30% completion rate
│   └── Expected value: -17.5 $DATA per attempt
│   └── Death rate benefit (when successful): Very valuable
│
├── Intermediate: ~60% completion rate
│   └── Expected value: -10 $DATA per attempt
│   └── Consistent death rate benefits
│
└── Expert: ~85% completion rate
    └── Expected value: -3.75 $DATA per attempt
    └── Reliable buff farming

The value proposition increases with skill - experts get consistent
death rate reductions for minimal $DATA investment.
```

---

## Visual Design

### Color Scheme

```css
.ice-breaker {
  /* ICE Types */
  --ice-static: #00ffff;
  --ice-blink: #ff00ff;
  --ice-patrol: #ffff00;
  --ice-sequence: #00ff00;
  --ice-shadow: #8800ff;
  --ice-mirror: #ff8800;
  --ice-adaptive: #ff0000;
  
  /* Weak Points */
  --weak-point: #00ff00;
  --weak-point-critical: #ffff00;
  --weak-point-hit: #ffffff;
  
  /* Feedback */
  --hit-success: #00ff00;
  --hit-perfect: #ffff00;
  --hit-miss: #ff0000;
}
```

### Animations

**Weak Point Appear:**
```css
@keyframes weakpoint-appear {
  0% { transform: scale(0); opacity: 0; }
  50% { transform: scale(1.2); opacity: 1; }
  100% { transform: scale(1); opacity: 1; }
}
```

**Hit Feedback:**
```css
@keyframes hit-success {
  0% { transform: scale(1); }
  50% { transform: scale(1.5); background: var(--hit-success); }
  100% { transform: scale(0); opacity: 0; }
}

@keyframes hit-perfect {
  0% { transform: scale(1); }
  25% { transform: scale(2); box-shadow: 0 0 30px var(--hit-perfect); }
  100% { transform: scale(0); opacity: 0; }
}
```

**Miss Feedback:**
```css
@keyframes screen-shake {
  0%, 100% { transform: translateX(0); }
  20% { transform: translateX(-10px); }
  40% { transform: translateX(10px); }
  60% { transform: translateX(-5px); }
  80% { transform: translateX(5px); }
}
```

---

## Sound Design

| Event | Sound |
|-------|-------|
| Layer Start | Rising electronic tone |
| Weak Point Appear | Soft ping |
| Hit (normal) | Sharp click |
| Hit (perfect) | Satisfying "ping" + sparkle |
| Miss Click | Error buzz |
| Timeout | Warning alarm |
| Damage Taken | Impact + static |
| Health Low | Heartbeat pulse |
| Layer Complete | Level up chime |
| Boss Layer Warning | Alarm klaxon |
| Victory | Triumphant synth fanfare |
| Failure | System shutdown sound |

---

## Technical Implementation

### Game Loop

```typescript
// src/lib/features/arcade/ice-breaker/game.svelte.ts

interface WeakPoint {
  id: string;
  x: number;
  y: number;
  type: 'static' | 'blink' | 'patrol' | 'sequence';
  appearTime: number;
  deadline: number;
  sequenceOrder?: number;
  velocity?: { x: number; y: number };
  visible: boolean;
}

interface GameState {
  layer: number;
  health: number;
  score: number;
  weakPoints: WeakPoint[];
  iceType: IceType;
  startTime: number;
  perfectHits: number;
  totalHits: number;
  missedClicks: number;
  timeouts: number;
}

export function createIceBreakerGame() {
  let state = $state<GameState | null>(null);
  let animationFrame: number | null = null;
  
  function startGame() {
    state = {
      layer: 1,
      health: 100,
      score: 0,
      weakPoints: [],
      iceType: 'static',
      startTime: Date.now(),
      perfectHits: 0,
      totalHits: 0,
      missedClicks: 0,
      timeouts: 0
    };
    
    startLayer(1);
    startGameLoop();
  }
  
  function startLayer(layer: number) {
    const config = getLayerConfig(layer);
    state!.layer = layer;
    state!.iceType = config.iceType;
    state!.weakPoints = generateWeakPoints(config);
  }
  
  function startGameLoop() {
    function update() {
      if (!state) return;
      
      const now = Date.now();
      
      // Update patrol weak points
      state.weakPoints = state.weakPoints.map(wp => {
        if (wp.type === 'patrol' && wp.velocity) {
          return {
            ...wp,
            x: wp.x + wp.velocity.x,
            y: wp.y + wp.velocity.y
          };
        }
        return wp;
      });
      
      // Check for timeouts
      state.weakPoints.forEach(wp => {
        if (now > wp.deadline && wp.visible) {
          handleTimeout(wp);
        }
      });
      
      // Check for blink visibility
      if (state.iceType === 'blink') {
        updateBlinkVisibility(now);
      }
      
      // Check layer completion
      if (state.weakPoints.every(wp => !wp.visible)) {
        completeLayer();
      }
      
      animationFrame = requestAnimationFrame(update);
    }
    
    animationFrame = requestAnimationFrame(update);
  }
  
  function handleClick(x: number, y: number) {
    if (!state) return;
    
    const now = Date.now();
    const clickRadius = 30; // pixels
    
    // Find clicked weak point
    const hitPoint = state.weakPoints.find(wp => 
      wp.visible &&
      Math.hypot(wp.x - x, wp.y - y) < clickRadius
    );
    
    if (hitPoint) {
      // Check sequence order if applicable
      if (hitPoint.type === 'sequence') {
        const expectedOrder = state.weakPoints
          .filter(wp => !wp.visible)
          .length + 1;
        
        if (hitPoint.sequenceOrder !== expectedOrder) {
          handleMissClick();
          return;
        }
      }
      
      // Calculate reaction time
      const reactionTime = now - hitPoint.appearTime;
      const isPerfect = reactionTime < 300; // 0.3 seconds
      
      // Score hit
      hitPoint.visible = false;
      state.totalHits++;
      if (isPerfect) state.perfectHits++;
      
      state.score += isPerfect ? 150 : 100;
      
      // Emit hit event
      emitHit(hitPoint, isPerfect, reactionTime);
      
    } else {
      handleMissClick();
    }
  }
  
  function handleMissClick() {
    if (!state) return;
    
    state.missedClicks++;
    state.health -= 5;
    
    if (state.health <= 0) {
      gameOver();
    }
    
    // Visual/audio feedback
    emitMiss();
  }
  
  function handleTimeout(wp: WeakPoint) {
    if (!state) return;
    
    wp.visible = false;
    state.timeouts++;
    state.health -= 10;
    
    if (state.health <= 0) {
      gameOver();
    }
    
    emitTimeout(wp);
  }
  
  function completeLayer() {
    if (!state) return;
    
    // Health recovery
    const hadDamage = state.weakPoints.length !== state.totalHits;
    if (!hadDamage && state.health < 100) {
      state.health = Math.min(100, state.health + 5);
    }
    
    if (state.layer >= 12) {
      victory();
    } else {
      // Brief pause then next layer
      setTimeout(() => startLayer(state!.layer + 1), 2000);
    }
  }
  
  function victory() {
    stopGameLoop();
    const totalTime = (Date.now() - state!.startTime) / 1000;
    
    // Calculate rewards
    const baseReduction = 10; // 10%
    const speedBonus = totalTime < 50 ? 2 : 0;
    const perfectBonus = (state!.perfectHits / state!.totalHits) > 0.8 ? 3 : 0;
    const healthBonus = state!.health === 100 ? 2 : 0;
    
    const totalReduction = baseReduction + speedBonus + perfectBonus + healthBonus;
    
    emitVictory(state!.score, totalTime, totalReduction);
  }
  
  function gameOver() {
    stopGameLoop();
    emitGameOver(state!.layer, state!.score);
  }
  
  function stopGameLoop() {
    if (animationFrame) {
      cancelAnimationFrame(animationFrame);
      animationFrame = null;
    }
  }
  
  return {
    get state() { return state; },
    startGame,
    handleClick,
    cleanup: stopGameLoop
  };
}
```

### Touch/Click Handler

```svelte
<script lang="ts">
  import { createIceBreakerGame } from './game.svelte';
  
  const game = createIceBreakerGame();
  
  function handleInteraction(e: MouseEvent | TouchEvent) {
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    
    let x: number, y: number;
    
    if ('touches' in e) {
      x = e.touches[0].clientX - rect.left;
      y = e.touches[0].clientY - rect.top;
    } else {
      x = e.clientX - rect.left;
      y = e.clientY - rect.top;
    }
    
    game.handleClick(x, y);
  }
</script>

<div 
  class="ice-game-area"
  onclick={handleInteraction}
  ontouchstart={handleInteraction}
>
  {#if game.state}
    {#each game.state.weakPoints as wp (wp.id)}
      {#if wp.visible}
        <div 
          class="weak-point"
          class:blink={wp.type === 'blink'}
          style="left: {wp.x}px; top: {wp.y}px"
        >
          {#if wp.sequenceOrder}
            <span class="sequence-number">{wp.sequenceOrder}</span>
          {/if}
        </div>
      {/if}
    {/each}
  {/if}
</div>
```

---

## Feed Integration

```
> 0x7a3f breached ICE in 43.2s [Score: 14,280] - SPEED DEMON 🧊💥
> 0x9c2d reached Layer 11 in ICE BREAKER before lockout
> 🔥 0x3b1a achieved 92% PERFECT HITS in ICE BREAKER 🔥
> 0x8f2e earned -17% death rate from PERFECT ICE RUN 🛡️
```

---

## Testing Checklist

- [ ] All ICE types function correctly
- [ ] Hit detection accurate (click radius)
- [ ] Sequence order enforcement
- [ ] Patrol movement smooth at 60fps
- [ ] Blink timing precise
- [ ] Health calculations correct
- [ ] Layer transitions smooth
- [ ] Victory/failure detection accurate
- [ ] Reward calculations correct
- [ ] Touch support on mobile
- [ ] No memory leaks in game loop
- [ ] Sound sync with actions
- [ ] Feed events emitted correctly
