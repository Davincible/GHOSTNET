# GHOSTNET Arcade Sound Design System

## Design Document

**Version:** 1.0  
**Status:** Planning  
**Target:** Phase 3 (Q2 2026)  
**Audio Implementation:** `apps/web/src/lib/core/audio/`

---

## Audio Philosophy

### The Sound of GHOSTNET

GHOSTNET's audio identity is defined by three core principles:

1. **Tension Through Minimalism**
   - Sparse, deliberate sounds create unease
   - Silence is as important as sound
   - Every audio cue carries meaning

2. **Procedural Authenticity**
   - ZzFX generates sounds in real-time
   - No pre-recorded samples (except rare victory fanfares)
   - Glitchy, digital imperfections are features, not bugs

3. **Cyberpunk Atmosphere**
   - Matrix-inspired digital rain aesthetic
   - 80s synth-wave undertones
   - Industrial, mechanical textures

### Emotional Mapping

| Emotion | Frequency Range | Waveform | Duration |
|---------|----------------|----------|----------|
| Tension | 100-300 Hz | Sawtooth/Noise | Long sustain |
| Victory | 400-800 Hz | Sine/Triangle | Rising pitch |
| Danger | 80-200 Hz | Square/Noise | Pulsing |
| Success | 600-1200 Hz | Sine | Short, bright |
| Failure | 100-150 Hz | Noise | Descending |
| Neutral UI | 800-1500 Hz | Sine | Quick, clean |

---

## Sound Categories

### 1. UI Sounds

Core interface interactions that provide instant feedback.

```typescript
const UI_SOUNDS = {
  // Button interactions
  click: [0.3, , 800, , 0.01, 0.01, , 1, , , , , , , , , , 0.5],
  hover: [0.1, , 1200, , 0.01, 0.01, , 1, , , , , , , , , , 0.3],
  
  // Modal/Panel operations
  open: [0.3, , 400, 0.01, 0.02, 0.05, , 1, , , 100, 0.01],
  close: [0.3, , 600, 0.01, 0.01, 0.03, , 1, , , -100, 0.01],
  
  // Navigation
  tabSwitch: [0.2, , 1000, , 0.01, 0.02, , 1, , , 50, 0.01],
  pageTransition: [0.2, , 500, 0.02, 0.03, 0.05, , 1, , , 200, 0.02],
  
  // Form interactions
  inputFocus: [0.15, , 1100, , 0.01, 0.01, , 1, , , , , , , , , , 0.4],
  inputError: [0.2, , 200, , 0.02, 0.03, 4, 1, , , , , , 0.3],
  inputSuccess: [0.2, , 800, , 0.02, 0.02, , 1, , , 100, 0.01],
  
  // Toggle/Switch
  toggleOn: [0.25, , 600, , 0.02, 0.03, , 1, , , 200, 0.02],
  toggleOff: [0.25, , 800, , 0.02, 0.03, , 1, , , -200, 0.02],
  
  // Selection
  select: [0.2, , 900, , 0.01, 0.02, , 1, , , 50, 0.01],
  deselect: [0.15, , 700, , 0.01, 0.01, , 1, , , -50, 0.01],
} as const;
```

### 2. Game Sounds

Actions and feedback within mini-games.

```typescript
const GAME_SOUNDS = {
  // Timing/Countdown
  countdown: [0.4, , 400, 0.01, 0.05, 0.1, , 1, , , 50, 0.05],
  countdownGo: [0.5, , 600, 0.01, 0.1, 0.2, , 1, , , 200, 0.05],
  tick: [0.15, , 600, , 0.01, 0.01, , 1, , , , , , , , , , 0.3],
  
  // Progress
  progressStep: [0.2, , 700, , 0.01, 0.02, , 1, , , 100, 0.01],
  progressMilestone: [0.3, , 500, 0.01, 0.05, 0.1, , 1, , , 150, 0.02],
  
  // Actions
  action: [0.25, , 650, , 0.02, 0.03, , 1, , , 50, 0.01],
  actionCharged: [0.35, , 400, 0.02, 0.1, 0.15, , 1, 3, , 100, 0.02],
  
  // Combos/Streaks
  comboSmall: [0.3, , 600, , 0.02, 0.03, , 1, , , 100, 0.01],
  comboMedium: [0.35, , 700, 0.01, 0.03, 0.05, , 1, , , 150, 0.02],
  comboLarge: [0.4, , 800, 0.01, 0.05, 0.08, , 1, 2, , 200, 0.03],
  comboBreak: [0.3, , 200, , 0.05, 0.1, 3, 1, , , -100, 0.02],
  
  // Multiplier changes
  multiplierUp: [0.3, , 500, 0.01, 0.03, 0.05, , 1, , , 200, 0.02],
  multiplierDown: [0.3, , 400, 0.01, 0.03, 0.05, , 1, , , -150, 0.02],
} as const;
```

### 3. Ambient Sounds

Background atmosphere and environmental audio.

```typescript
const AMBIENT_SOUNDS = {
  // Environment (loopable via rapid succession)
  digitalRain: [0.05, 0.1, 2000, , 0.01, 0.1, 4, 0.5, , , , , 0.05],
  serverHum: [0.03, , 80, , , 0.5, 1, 0.3, , , , , , 0.1],
  dataStream: [0.04, 0.2, 1500, , , 0.2, 4, 0.4, , , , , 0.1],
  
  // Tension building
  tensionLow: [0.06, , 100, , , 0.5, 1, 0.5, , , , , , 0.2],
  tensionMedium: [0.08, , 150, , , 0.4, 2, 0.6, 2, , , , , 0.3],
  tensionHigh: [0.1, , 200, , , 0.3, 3, 0.7, 3, , , , , 0.4],
  
  // Scan approaching
  scanApproaching: [0.15, , 150, 0.01, 0.1, 0.2, 2, 1, , , , , 0.2],
  scanImminent: [0.2, , 180, 0.01, 0.15, 0.15, 2, 1, 2, , , , 0.15],
} as const;
```

### 4. Alert Sounds

Warnings, notifications, and urgent cues.

```typescript
const ALERT_SOUNDS = {
  // Standard alerts
  alert: [0.5, , 300, 0.01, 0.1, 0.1, 2, 1, , , , , 0.05],
  alertUrgent: [0.6, , 350, 0.01, 0.1, 0.08, 2, 1, , , , , 0.03],
  
  // Warnings
  warning: [0.5, , 200, 0.01, 0.15, 0.1, 2, 1, , , , , 0.1],
  warningCritical: [0.6, , 180, 0.01, 0.2, 0.1, 3, 1, 2, , , , 0.08],
  
  // Danger levels
  danger: [0.6, , 150, 0.01, 0.2, 0.15, 3, 1, , , , , 0.05, 0.3],
  dangerExtreme: [0.7, , 120, 0.01, 0.25, 0.2, 3, 1, 3, , , , 0.05, 0.5],
  
  // Scan events
  scanWarning: [0.4, , 250, 0.01, 0.1, 0.05, 2, 1, , , , , 0.1],
  scanStart: [0.5, , 200, 0.02, 0.15, 0.1, 2, 1, , , , , 0.05],
  scanComplete: [0.4, , 350, 0.01, 0.1, 0.15, , 1, , , 100, 0.03],
  
  // Notifications
  notification: [0.3, , 700, 0.01, 0.03, 0.05, , 1, , , 100, 0.02],
  notificationImportant: [0.4, , 600, 0.01, 0.05, 0.08, , 1, 2, , 150, 0.03],
  
  // Incoming events
  incomingAttack: [0.5, , 200, 0.01, 0.2, 0.1, 2, 1, 3, , , , 0.1],
  incomingMessage: [0.25, , 800, 0.01, 0.03, 0.05, , 1, , , 200, 0.02],
} as const;
```

### 5. Victory/Defeat Fanfares

Major game outcome sounds with more complex patterns.

```typescript
const FANFARE_SOUNDS = {
  // Victory tiers
  victorySmall: [0.4, , 600, 0.02, 0.1, 0.2, , 1, , , 100, 0.02, , , , , , 0.8],
  victoryMedium: [0.5, , 500, 0.02, 0.15, 0.25, , 1, 3, , 150, 0.03, 0.05],
  victoryLarge: [0.6, , 400, 0.03, 0.2, 0.35, , 1, 5, , 200, 0.05, 0.1, , , , 0.1, 0.9],
  victoryEpic: [0.7, , 300, 0.03, 0.3, 0.4, , 1, 7, , 250, 0.07, 0.15, , , , 0.15, 0.95],
  
  // Defeat tiers
  defeatSmall: [0.3, , 300, 0.01, 0.1, 0.2, 3, 1, , , -50, 0.03],
  defeatMedium: [0.4, , 250, 0.02, 0.15, 0.3, 3, 1, -3, , -100, 0.05, , 0.2],
  defeatLarge: [0.5, , 200, 0.02, 0.2, 0.4, 3, 1, -5, , -150, 0.07, , 0.3],
  defeatCatastrophic: [0.6, , 150, 0.02, 0.3, 0.5, 3, 1, -7, , -200, 0.1, , 0.5, , 0.3],
  
  // Special outcomes
  jackpot: [0.6, , 300, 0.02, 0.3, 0.4, , 1, 3, , 200, 0.05, 0.1, , , , 0.1, 0.9],
  nearMiss: [0.3, , 400, 0.01, 0.1, 0.15, 2, 1, , , -50, 0.02],
  clutchWin: [0.5, , 350, 0.02, 0.2, 0.3, , 1, 5, , 250, 0.05, 0.08],
  
  // Round completion
  roundComplete: [0.4, , 500, 0.02, 0.1, 0.2, , 1, , , 100, 0.02, , , , , , 0.8],
  gameComplete: [0.5, , 400, 0.02, 0.2, 0.3, , 1, 5, , 200, 0.05, 0.1],
} as const;
```

---

## Per-Game Sound Maps

### HASH CRASH

Rising tension multiplier game with crash explosions.

```typescript
const HASH_CRASH_SOUNDS = {
  // Phase sounds
  bettingPhaseStart: [...ALERT_SOUNDS.notification],
  bettingPhaseEnd: [...GAME_SOUNDS.countdown],
  launchStart: [0.4, , 300, 0.02, 0.1, 0.2, , 1, , , 100, 0.02],
  
  // Multiplier progression (pitch increases with multiplier)
  multiplierTick: (mult: number) => {
    const basePitch = 400 + Math.min(mult * 50, 800);
    return [0.15, , basePitch, , 0.01, 0.02, , 1, , , 20, 0.01] as ZzFXParams;
  },
  
  // Tension thresholds
  tensionLow: [0.1, , 300, , 0.05, 0.1, 1, 0.5, , , , , , 0.1],      // 1-2x
  tensionMedium: [0.15, , 350, , 0.08, 0.12, 2, 0.6, 1, , , , , 0.2], // 2-5x
  tensionHigh: [0.2, , 400, , 0.1, 0.15, 2, 0.7, 2, , , , , 0.3],    // 5-10x
  tensionExtreme: [0.25, , 450, , 0.12, 0.18, 3, 0.8, 3, , , , , 0.4], // 10x+
  
  // Actions
  cashOut: [0.5, , 700, 0.01, 0.05, 0.1, , 1, , , 200, 0.02],
  cashOutOther: [0.2, , 600, , 0.02, 0.03, , 1, , , 100, 0.01],
  
  // Crash explosion
  crashExplosion: [0.8, , 100, 0.01, 0.3, 0.5, 4, 1, -10, , -200, 0.1, , 0.8, , 0.2],
  
  // Outcomes
  winSmall: [...FANFARE_SOUNDS.victorySmall],     // <2x
  winMedium: [...FANFARE_SOUNDS.victoryMedium],   // 2-5x
  winBig: [...FANFARE_SOUNDS.victoryLarge],       // 5-20x
  winMassive: [...FANFARE_SOUNDS.victoryEpic],    // 20x+
  loss: [...FANFARE_SOUNDS.defeatMedium],
} as const;

// Event to sound mapping
const HASH_CRASH_EVENT_MAP = {
  'round:betting_start': 'bettingPhaseStart',
  'round:betting_end': 'bettingPhaseEnd',
  'round:launch': 'launchStart',
  'multiplier:update': 'multiplierTick',
  'player:cash_out': 'cashOut',
  'player:cash_out_other': 'cashOutOther',
  'round:crash': 'crashExplosion',
  'round:win': 'winSmall', // Dynamic based on multiplier
  'round:loss': 'loss',
} as const;
```

### CODE DUEL

1v1 typing battles with competitive audio feedback.

```typescript
const CODE_DUEL_SOUNDS = {
  // Match flow
  matchFound: [0.5, , 500, 0.01, 0.1, 0.15, , 1, 3, , 200, 0.03],
  matchAccepted: [0.4, , 600, 0.01, 0.08, 0.1, , 1, , , 150, 0.02],
  countdown3: [0.4, , 350, 0.01, 0.05, 0.1, , 1, , , , , , , , , , 0.6],
  countdown2: [0.4, , 450, 0.01, 0.05, 0.1, , 1, , , , , , , , , , 0.7],
  countdown1: [0.4, , 550, 0.01, 0.05, 0.1, , 1, , , , , , , , , , 0.8],
  go: [0.6, , 700, 0.01, 0.1, 0.15, , 1, , , 200, 0.03],
  
  // Typing feedback
  keystroke: [0.1, , 1000, , 0.01, 0.01, , 1, , , , , , , , , , 0.3],
  keystrokeError: [0.2, , 200, , 0.02, 0.03, 4, 1, , , , , , 0.3],
  
  // Combos
  comboStart: [0.2, , 600, , 0.02, 0.03, , 1, , , 50, 0.01],
  comboBuilding: [0.25, , 700, , 0.02, 0.03, , 1, , , 100, 0.01],
  comboPeak: [0.3, , 800, 0.01, 0.03, 0.05, , 1, 2, , 150, 0.02],
  comboLost: [...GAME_SOUNDS.comboBreak],
  
  // Competition
  opponentAhead: [0.15, , 300, , 0.05, 0.08, 2, 0.5, , , , , , 0.2],
  opponentClose: [0.2, , 350, , 0.08, 0.1, 2, 0.6, 1, , , , , 0.3],
  takingLead: [0.3, , 600, , 0.03, 0.05, , 1, , , 100, 0.02],
  opponentNearFinish: [0.4, , 250, 0.01, 0.1, 0.05, 2, 1, , , , , 0.05],
  
  // Outcomes
  victory: [0.6, , 500, 0.02, 0.2, 0.3, , 1, 5, , 250, 0.05, 0.08],
  defeat: [0.4, , 250, 0.02, 0.15, 0.25, 3, 1, -3, , -100, 0.03],
  draw: [0.3, , 400, 0.02, 0.1, 0.2, , 1, , , 50, 0.02],
  
  // Spectator
  spectatorBetWin: [0.4, , 600, 0.01, 0.08, 0.1, , 1, , , 150, 0.02],
  spectatorBetLoss: [0.3, , 300, 0.01, 0.05, 0.1, 3, 1, , , -50, 0.02],
} as const;
```

### DAILY OPS

Mission and streak progression audio.

```typescript
const DAILY_OPS_SOUNDS = {
  // Mission states
  missionAvailable: [0.4, , 600, 0.01, 0.05, 0.1, , 1, , , 100, 0.02],
  missionStart: [0.3, , 500, 0.01, 0.03, 0.05, , 1, , , 50, 0.01],
  missionProgress: [0.25, , 700, , 0.02, 0.03, , 1, , , 75, 0.01],
  missionComplete: [0.5, , 600, 0.02, 0.15, 0.2, , 1, 3, , 200, 0.04],
  missionFailed: [0.3, , 250, 0.01, 0.1, 0.15, 3, 1, , , -100, 0.03],
  
  // Streak sounds
  streakContinue: [0.4, , 700, 0.01, 0.05, 0.1, , 1, , , 150, 0.02],
  streakMilestone3: [0.5, , 600, 0.02, 0.1, 0.15, , 1, 2, , 200, 0.03],
  streakMilestone7: [0.55, , 550, 0.02, 0.12, 0.18, , 1, 3, , 225, 0.04],
  streakMilestone14: [0.6, , 500, 0.02, 0.15, 0.22, , 1, 4, , 250, 0.05],
  streakMilestone30: [0.7, , 400, 0.03, 0.2, 0.3, , 1, 5, , 300, 0.07, 0.1],
  streakBroken: [0.5, , 200, 0.02, 0.2, 0.3, 3, 1, -5, , -150, 0.05, , 0.3],
  
  // Weekly
  weeklyComplete: [0.6, , 500, 0.02, 0.2, 0.25, , 1, 4, , 250, 0.05, 0.08],
  weeklyProgress: [0.3, , 600, , 0.03, 0.05, , 1, , , 100, 0.02],
  
  // Time warnings
  timeWarning1hr: [0.3, , 300, 0.01, 0.08, 0.05, 2, 1, , , , , 0.05],
  timeWarning30min: [0.4, , 280, 0.01, 0.1, 0.05, 2, 1, , , , , 0.03],
  timeWarning10min: [0.5, , 250, 0.01, 0.12, 0.05, 2, 1, 2, , , , 0.02],
} as const;
```

### ICE BREAKER

Reaction time game with hit/miss feedback.

```typescript
const ICE_BREAKER_SOUNDS = {
  // Layer states
  layerStart: [0.3, , 400, 0.01, 0.05, 0.1, , 1, , , 100, 0.02],
  layerComplete: [0.4, , 600, 0.01, 0.08, 0.12, , 1, , , 150, 0.03],
  bossLayerWarning: [0.5, , 200, 0.02, 0.15, 0.1, 2, 1, 2, , , , 0.05],
  
  // Target interactions
  targetAppear: [0.2, , 1200, , 0.01, 0.02, , 1, , , , , , , , , , 0.4],
  targetHit: [0.35, , 800, , 0.02, 0.03, , 1, , , 100, 0.01],
  targetHitPerfect: [0.45, , 1000, 0.01, 0.03, 0.05, , 1, 2, , 200, 0.02],
  targetMiss: [0.3, , 200, , 0.03, 0.05, 4, 1, , , , , , 0.2],
  targetTimeout: [0.35, , 150, 0.01, 0.05, 0.08, 3, 1, , , -50, 0.02],
  
  // Health
  damageTaken: [0.4, , 180, 0.01, 0.05, 0.1, 4, 1, , , , , , 0.3],
  healthLow: [0.3, , 100, , 0.3, 0.1, 1, 0.5, , , , , 0.2], // Heartbeat
  healthRecovered: [0.25, , 700, , 0.03, 0.05, , 1, , , 100, 0.02],
  
  // ICE types (distinctive sounds)
  iceStatic: [0.2, , 800, , 0.02, 0.03, , 1, , , , , , , , , , 0.5],
  iceBlink: [0.25, , 1000, , 0.01, 0.02, , 1, 5, , , , 0.02],
  icePatrol: [0.2, , 600, , 0.02, 0.04, 1, 1, 2, , 50, 0.01],
  iceSequence: [0.2, , 900, , 0.01, 0.03, , 1, , , 100, 0.01],
  iceShadow: [0.15, , 500, , 0.03, 0.05, 2, 0.5, , , , , , 0.2],
  iceMirror: [0.25, , 700, , 0.02, 0.03, , 1, , , , , 0.05],
  iceAdaptive: [0.3, , 400, 0.01, 0.03, 0.05, 2, 1, 3, , 100, 0.02],
  
  // Outcomes
  victory: [0.6, , 500, 0.02, 0.2, 0.3, , 1, 5, , 250, 0.05, 0.08],
  failure: [0.5, , 150, 0.02, 0.25, 0.4, 3, 1, -5, , -150, 0.07, , 0.4],
} as const;
```

### BINARY BET

Coin flip with commit-reveal drama.

```typescript
const BINARY_BET_SOUNDS = {
  // Phase transitions
  commitPhaseStart: [0.3, , 500, 0.01, 0.05, 0.08, , 1, , , 50, 0.02],
  lockPhase: [0.4, , 400, 0.02, 0.1, 0.1, 2, 1, , , , , 0.05],
  revealPhaseStart: [0.5, , 600, 0.01, 0.08, 0.1, , 1, , , 100, 0.02],
  
  // Betting
  betPlaced: [0.3, , 700, , 0.02, 0.03, , 1, , , 50, 0.01],
  betCommitted: [0.35, , 600, 0.01, 0.03, 0.05, , 1, , , 100, 0.02],
  
  // Reveal drama
  revealDrumroll: [0.2, , 300, , 0.02, 0.03, 1, 1, , , , , 0.1],
  coinFlip: [0.4, , 400, 0.01, 0.1, 0.15, , 1, 5, 0.5, 100, 0.02, 0.05],
  bitReveal0: [0.5, , 350, 0.01, 0.08, 0.12, , 1, , , -50, 0.02],
  bitReveal1: [0.5, , 550, 0.01, 0.08, 0.12, , 1, , , 50, 0.02],
  
  // Outcomes
  win: [0.5, , 600, 0.02, 0.15, 0.2, , 1, 3, , 200, 0.04],
  loss: [0.4, , 250, 0.02, 0.12, 0.18, 3, 1, , , -100, 0.03],
  forfeit: [0.5, , 150, 0.02, 0.2, 0.25, 3, 1, -3, , -150, 0.05, , 0.3],
  
  // Streaks
  streakBonus: [0.4, , 700, 0.01, 0.05, 0.08, , 1, 2, , 150, 0.02],
  streakLost: [...GAME_SOUNDS.comboBreak],
} as const;
```

### BOUNTY HUNT

Strategic hunting with detection and capture sounds.

```typescript
const BOUNTY_HUNT_SOUNDS = {
  // Game phases
  registrationOpen: [0.3, , 500, 0.01, 0.05, 0.08, , 1, , , 50, 0.02],
  targetAssigning: [0.2, , 400, , 0.1, 0.15, 2, 0.5, , , , , 0.1],
  targetAssigned: [0.4, , 300, 0.02, 0.1, 0.15, 2, 1, , , 100, 0.03],
  cycleAdvance: [0.3, , 600, 0.01, 0.03, 0.05, , 1, , , 50, 0.01],
  
  // Intel
  intelGathered: [0.3, , 800, , 0.02, 0.04, , 1, , , 100, 0.01],
  intelRevealed: [0.35, , 900, 0.01, 0.03, 0.05, , 1, , , 150, 0.02],
  suspectNarrowed: [0.4, , 700, 0.01, 0.05, 0.08, , 1, 2, , 100, 0.02],
  
  // False trails
  trailDeployed: [0.25, , 400, , 0.03, 0.05, 2, 0.5, , , -50, 0.02],
  trailExpired: [0.2, , 300, , 0.02, 0.03, 2, 0.5, , , , , , 0.2],
  
  // Execution
  executionAttempt: [0.5, , 350, 0.02, 0.1, 0.1, 2, 1, 3, , , , 0.05],
  executionHit: [0.7, , 600, 0.01, 0.15, 0.2, , 1, 5, , 250, 0.05, 0.08],
  executionMiss: [0.5, , 200, 0.02, 0.15, 0.2, 3, 1, -3, , -100, 0.05],
  
  // Being hunted
  hunterDetected: [0.3, , 250, 0.01, 0.1, 0.08, 2, 1, , , , , 0.08],
  coverBlown: [0.5, , 180, 0.02, 0.15, 0.15, 3, 1, 2, , -50, 0.03],
  
  // Outcomes
  bountyCapture: [0.6, , 500, 0.02, 0.2, 0.25, , 1, 5, , 250, 0.05, 0.1],
  eliminated: [0.5, , 150, 0.02, 0.25, 0.35, 3, 1, -5, , -200, 0.07, , 0.5],
  survived: [0.5, , 600, 0.02, 0.15, 0.2, , 1, 3, , 200, 0.04],
} as const;
```

### PROXY WAR

Crew battles with territory and combat sounds.

```typescript
const PROXY_WAR_SOUNDS = {
  // Territory
  territoryCapture: [0.5, , 500, 0.02, 0.15, 0.2, , 1, 3, , 200, 0.04],
  territoryLost: [0.5, , 200, 0.02, 0.2, 0.25, 3, 1, -3, , -150, 0.05],
  fortificationBuilt: [0.35, , 600, 0.01, 0.08, 0.1, , 1, , , 100, 0.02],
  yieldCollected: [0.3, , 700, , 0.03, 0.05, , 1, , , 50, 0.01],
  
  // Battle announcements
  attackDeclared: [0.5, , 250, 0.02, 0.15, 0.1, 2, 1, 3, , , , 0.05],
  defenseRally: [0.45, , 400, 0.01, 0.1, 0.12, 2, 1, , , 50, 0.03],
  battleCountdown: [0.4, , 350, 0.01, 0.05, 0.08, , 1, , , , , , , , , , 0.7],
  battleStart: [0.6, , 500, 0.01, 0.1, 0.15, , 1, 3, , 150, 0.03],
  
  // Combat
  attackLanding: [0.4, , 600, , 0.02, 0.04, , 1, , , 100, 0.01],
  defensHolding: [0.35, , 500, , 0.02, 0.04, , 1, , , 50, 0.01],
  scoreUpdate: [0.25, , 800, , 0.01, 0.02, , 1, , , 50, 0.01],
  leadChange: [0.4, , 700, 0.01, 0.03, 0.05, , 1, 2, , 100, 0.02],
  
  // Battle outcomes
  battleVictory: [0.7, , 450, 0.03, 0.25, 0.35, , 1, 5, , 300, 0.07, 0.12],
  battleDefeat: [0.5, , 180, 0.02, 0.2, 0.3, 3, 1, -5, , -180, 0.06, , 0.4],
  stakeBurned: [0.4, , 150, 0.01, 0.15, 0.2, 4, 1, , , , , , 0.5],
  
  // Domination
  dominationWarning: [0.5, , 200, 0.02, 0.2, 0.1, 2, 1, 3, , , , 0.05],
  dominationVictory: [0.8, , 350, 0.03, 0.35, 0.5, , 1, 7, , 350, 0.1, 0.15, , , , 0.1, 0.95],
  
  // Crew communication
  rallyCall: [0.4, , 500, 0.01, 0.08, 0.1, 2, 1, , , 100, 0.02],
  allianceFormed: [0.35, , 600, 0.01, 0.05, 0.08, , 1, , , 150, 0.02],
} as const;
```

### ZERO DAY

Multi-stage hack with escalating tension.

```typescript
const ZERO_DAY_SOUNDS = {
  // Chain flow
  targetSelected: [0.4, , 400, 0.02, 0.08, 0.1, 2, 1, , , 50, 0.02],
  chainStart: [0.5, , 500, 0.01, 0.1, 0.15, , 1, 3, , 150, 0.03],
  stageBriefing: [0.3, , 600, 0.01, 0.05, 0.08, , 1, , , 50, 0.02],
  stageStart: [0.4, , 700, 0.01, 0.08, 0.1, , 1, , , 100, 0.02],
  
  // Stage types
  injectionTyping: [0.1, , 1000, , 0.01, 0.01, , 1, , , , , , , , , , 0.3],
  crackNodeAppear: [0.2, , 1200, , 0.01, 0.02, , 1, , , , , , , , , , 0.4],
  crackNodeHit: [0.35, , 800, , 0.02, 0.03, , 1, , , 100, 0.01],
  memoryReveal: [0.3, , 600, , 0.02, 0.03, , 1, , , 50, 0.01],
  memoryHide: [0.25, , 400, , 0.03, 0.05, 2, 0.5, , , -50, 0.02],
  patternMatch: [0.3, , 750, , 0.02, 0.03, , 1, , , 100, 0.01],
  patternMismatch: [0.25, , 200, , 0.03, 0.04, 4, 1, , , , , , 0.2],
  exfilSort: [0.2, , 800, , 0.02, 0.02, , 1, , , 50, 0.01],
  exfilExpire: [0.3, , 180, 0.01, 0.05, 0.08, 3, 1, , , -50, 0.02],
  
  // Detection meter
  detectionRising: [0.15, , 200, , 0.1, 0.08, 2, 0.6, 1, , , , , 0.2],
  detectionCritical: [0.25, , 180, , 0.15, 0.08, 2, 0.7, 2, , , , , 0.3],
  detectionTriggered: [0.5, , 150, 0.01, 0.2, 0.2, 3, 1, 3, , -100, 0.05],
  
  // Stage outcomes
  stageComplete: [0.4, , 600, 0.01, 0.1, 0.15, , 1, , , 150, 0.03],
  stageFailed: [0.4, , 200, 0.02, 0.15, 0.2, 3, 1, -3, , -100, 0.04],
  
  // Multiplier
  multiplierIncrease: [0.35, , 700, 0.01, 0.03, 0.05, , 1, 2, , 150, 0.02],
  
  // Chain outcomes
  abortExtract: [0.4, , 500, 0.02, 0.1, 0.15, , 1, , , 50, 0.02],
  chainComplete: [0.7, , 400, 0.03, 0.25, 0.35, , 1, 5, , 300, 0.07, 0.12],
  chainFailed: [0.6, , 150, 0.02, 0.3, 0.4, 3, 1, -7, , -200, 0.08, , 0.5],
} as const;
```

### SHADOW PROTOCOL

Stealth meta-game with detection mechanics.

```typescript
const SHADOW_PROTOCOL_SOUNDS = {
  // Shadow activation
  shadowEnter: [0.4, , 300, 0.02, 0.15, 0.2, 2, 0.7, , , -50, 0.03, , 0.2],
  shadowActive: [0.1, , 200, , 0.5, 0.1, 1, 0.3, , , , , , 0.15],
  shadowExtend: [0.3, , 350, 0.01, 0.08, 0.1, 2, 0.6, , , 50, 0.02],
  shadowExit: [0.35, , 400, 0.02, 0.1, 0.15, , 1, , , 100, 0.02],
  
  // Evasion
  scanEvaded: [0.35, , 500, 0.01, 0.05, 0.08, , 1, , , 100, 0.02],
  bountyIncreased: [0.3, , 600, , 0.03, 0.05, , 1, , , 75, 0.01],
  
  // Detection risk
  riskIncreasing: [0.15, , 200, , 0.1, 0.1, 2, 0.5, 1, , , , , 0.2],
  riskCritical: [0.25, , 180, , 0.15, 0.1, 2, 0.6, 2, , , , , 0.3],
  
  // Hunter mode
  huntModeEnter: [0.35, , 400, 0.01, 0.08, 0.1, 2, 1, , , 50, 0.02],
  targetSelected: [0.3, , 500, 0.01, 0.05, 0.08, , 1, , , 75, 0.01],
  
  // Detection game
  patternAnalysis: [0.2, , 600, , 0.05, 0.08, , 0.5, , , , , 0.1],
  behaviorMatch: [0.25, , 700, , 0.03, 0.05, , 1, , , 100, 0.01],
  timingBlip: [0.3, , 1000, , 0.01, 0.02, , 1, , , , , , , , , , 0.5],
  timingHit: [0.35, , 800, , 0.02, 0.03, , 1, , , 100, 0.01],
  timingMiss: [0.2, , 200, , 0.02, 0.03, 4, 1, , , , , , 0.2],
  
  // Outcomes
  detectionSuccess: [0.6, , 500, 0.02, 0.2, 0.25, , 1, 5, , 250, 0.05, 0.08],
  detectionFailed: [0.3, , 300, 0.01, 0.08, 0.12, 2, 0.5, , , -50, 0.02],
  exposed: [0.7, , 150, 0.02, 0.3, 0.4, 3, 1, -5, , -200, 0.08, , 0.6],
  
  // Shadow collision
  shadowCollision: [0.5, , 300, 0.02, 0.15, 0.15, 2, 1, 3, , , , 0.08],
} as const;
```

---

## ZzFX Parameters Reference

### Parameter Index

```typescript
type ZzFXParams = [
  volume?: number,          // 0: Volume (0-1)
  randomness?: number,      // 1: Pitch randomness (0-1)
  frequency?: number,       // 2: Base frequency in Hz
  attack?: number,          // 3: Attack time in seconds
  sustain?: number,         // 4: Sustain time in seconds
  release?: number,         // 5: Release time in seconds
  shape?: number,           // 6: Wave shape (0=sin, 1=tri, 2=saw, 3=tan, 4=noise)
  shapeCurve?: number,      // 7: Shape curve (0-1)
  slide?: number,           // 8: Frequency slide
  deltaSlide?: number,      // 9: Slide acceleration
  pitchJump?: number,       // 10: Pitch jump amount (Hz)
  pitchJumpTime?: number,   // 11: Time to pitch jump (seconds)
  repeatTime?: number,      // 12: Time between repeats
  noise?: number,           // 13: Noise amount (0-1)
  modulation?: number,      // 14: Modulation depth
  bitCrush?: number,        // 15: Bit crush amount
  delay?: number,           // 16: Delay time
  sustainVolume?: number,   // 17: Sustain volume (0-1)
  decay?: number,           // 18: Decay time
  tremolo?: number          // 19: Tremolo depth
];
```

### Mood Recipes

```typescript
// TENSE - Low, rumbling, unsettling
const TENSE = [0.3, , 150, , 0.2, 0.3, 2, 0.6, , , , , , 0.3];

// URGENT - Sharp, attention-grabbing
const URGENT = [0.5, , 300, 0.01, 0.1, 0.1, 2, 1, 3, , , , 0.05];

// VICTORIOUS - Bright, rising, celebratory
const VICTORIOUS = [0.5, , 500, 0.02, 0.15, 0.2, , 1, 5, , 200, 0.05];

// DEFEATED - Heavy, falling, somber
const DEFEATED = [0.4, , 200, 0.02, 0.15, 0.25, 3, 1, -5, , -150, 0.05];

// MYSTERIOUS - Ethereal, uncertain
const MYSTERIOUS = [0.2, , 400, , 0.1, 0.15, 1, 0.5, 2, , 50, 0.02, , 0.2];

// DIGITAL - Clean, precise, electronic
const DIGITAL = [0.3, , 800, , 0.01, 0.02, , 1, , , 50, 0.01];

// GLITCH - Chaotic, broken, interference
const GLITCH = [0.25, 0.3, 600, , 0.05, 0.08, 4, 0.7, 5, 2, 100, 0.02, 0.05];
```

### Frequency Guidelines

| Context | Frequency Range | Character |
|---------|----------------|-----------|
| Bass/Danger | 80-200 Hz | Heavy, ominous |
| Low Tension | 200-350 Hz | Unsettling |
| Mid/Action | 350-600 Hz | Neutral, active |
| High/UI | 600-1000 Hz | Clear, responsive |
| Bright/Success | 1000-1500 Hz | Positive, uplifting |
| Alert/Urgent | 1500-2000 Hz | Piercing, attention |

### Duration Guidelines

| Event Type | Duration | Attack/Release |
|------------|----------|----------------|
| UI Click | 0.01-0.03s | Short attack, quick release |
| Notification | 0.1-0.2s | Medium attack, medium release |
| Feedback | 0.03-0.08s | Short attack, short release |
| Transition | 0.1-0.3s | Medium attack, medium release |
| Fanfare | 0.3-0.6s | Medium attack, long release |
| Ambience | 0.5-2.0s+ | Slow attack, slow release |

---

## Audio Settings

### Settings Interface

```typescript
interface AudioSettings {
  // Master controls
  masterEnabled: boolean;
  masterVolume: number; // 0-1
  
  // Category volumes
  uiVolume: number;       // 0-1
  gameVolume: number;     // 0-1
  ambientVolume: number;  // 0-1
  alertVolume: number;    // 0-1
  fanfareVolume: number;  // 0-1
  
  // Feature toggles
  ambientEnabled: boolean;
  criticalAlertsOnly: boolean;
  reducedMotionAudio: boolean; // Simplify sounds
  
  // Per-game overrides
  gameOverrides: Record<GameId, {
    enabled: boolean;
    volume: number;
  }>;
}

const DEFAULT_AUDIO_SETTINGS: AudioSettings = {
  masterEnabled: true,
  masterVolume: 0.7,
  
  uiVolume: 0.8,
  gameVolume: 1.0,
  ambientVolume: 0.3,
  alertVolume: 1.0,
  fanfareVolume: 0.9,
  
  ambientEnabled: true,
  criticalAlertsOnly: false,
  reducedMotionAudio: false,
  
  gameOverrides: {},
};
```

### Settings UI

```
AUDIO SETTINGS
========================================================

MASTER
  [X] Sound Enabled           Volume: [========--] 80%

CATEGORIES
  UI Sounds                   [========--] 80%
  Game Sounds                 [==========] 100%
  Ambient Sounds              [===-------] 30%
  Alert Sounds                [==========] 100%
  Victory/Defeat Fanfares     [==========-] 90%

OPTIONS
  [ ] Ambient Background Sounds
  [ ] Critical Alerts Only (reduce sound spam)
  [ ] Reduced Motion Audio (simpler sounds)

GAME-SPECIFIC
  [v] Show per-game settings
  
  HASH CRASH                  [X] [==========-] 95%
  CODE DUEL                   [X] [==========] 100%
  ICE BREAKER                 [X] [==========-] 95%
  ...

[RESET TO DEFAULTS]           [TEST SOUNDS]
```

---

## Implementation

### AudioManager Store (Svelte 5)

```typescript
// apps/web/src/lib/core/audio/manager.svelte.ts

import { browser } from '$app/environment';
import type { SettingsStore } from '$lib/core/settings';
import { zzfx, resumeAudio, type ZzFXParams } from './zzfx';

// ════════════════════════════════════════════════════════════════
// SOUND CATEGORIES
// ════════════════════════════════════════════════════════════════

type SoundCategory = 'ui' | 'game' | 'ambient' | 'alert' | 'fanfare';

interface SoundDefinition {
  params: ZzFXParams;
  category: SoundCategory;
  priority?: number; // Higher = more important (for concurrent limiting)
}

// ════════════════════════════════════════════════════════════════
// SOUND REGISTRY
// ════════════════════════════════════════════════════════════════

const SOUNDS: Record<string, SoundDefinition> = {
  // UI Sounds
  click: { params: [0.3, , 800, , 0.01, 0.01, , 1, , , , , , , , , , 0.5], category: 'ui' },
  hover: { params: [0.1, , 1200, , 0.01, 0.01, , 1, , , , , , , , , , 0.3], category: 'ui' },
  open: { params: [0.3, , 400, 0.01, 0.02, 0.05, , 1, , , 100, 0.01], category: 'ui' },
  close: { params: [0.3, , 600, 0.01, 0.01, 0.03, , 1, , , -100, 0.01], category: 'ui' },
  error: { params: [0.5, , 200, 0.01, 0.05, 0.1, 4, 1, , , , , , 0.5], category: 'ui' },
  success: { params: [0.4, , 600, 0.01, 0.05, 0.1, , 1, , , 200, 0.02], category: 'ui' },

  // Typing Game
  keystroke: { params: [0.1, , 1000, , 0.01, 0.01, , 1, , , , , , , , , , 0.3], category: 'game' },
  keystrokeError: { params: [0.2, , 200, , 0.02, 0.03, 4, 1, , , , , , 0.3], category: 'game' },
  countdown: { params: [0.4, , 400, 0.01, 0.05, 0.1, , 1, , , 50, 0.05], category: 'game' },
  countdownGo: { params: [0.5, , 600, 0.01, 0.1, 0.2, , 1, , , 200, 0.05], category: 'game' },
  roundComplete: { params: [0.4, , 500, 0.02, 0.1, 0.2, , 1, , , 100, 0.02, , , , , , 0.8], category: 'fanfare' },
  gameComplete: { params: [0.5, , 400, 0.02, 0.2, 0.3, , 1, 5, , 200, 0.05, 0.1], category: 'fanfare' },

  // Feed Events
  jackIn: { params: [0.4, , 300, 0.02, 0.1, 0.2, , 1, , , 100, 0.05], category: 'game' },
  extract: { params: [0.4, , 500, 0.02, 0.1, 0.15, , 1, , , -100, 0.05], category: 'game' },
  traced: { params: [0.6, , 100, 0.01, 0.2, 0.3, 3, 1, , , , , , 0.5, , 0.5], category: 'alert', priority: 10 },
  survived: { params: [0.4, , 600, 0.01, 0.1, 0.2, , 1, , , 150, 0.03], category: 'fanfare' },
  jackpot: { params: [0.6, , 300, 0.02, 0.3, 0.4, , 1, 3, , 200, 0.05, 0.1, , , , 0.1, 0.9], category: 'fanfare', priority: 10 },
  scanWarning: { params: [0.4, , 250, 0.01, 0.1, 0.05, 2, 1, , , , , 0.1], category: 'alert', priority: 8 },
  scanStart: { params: [0.5, , 200, 0.02, 0.15, 0.1, 2, 1, , , , , 0.05], category: 'alert', priority: 9 },

  // Alerts
  alert: { params: [0.5, , 300, 0.01, 0.1, 0.1, 2, 1, , , , , 0.05], category: 'alert' },
  warning: { params: [0.5, , 200, 0.01, 0.15, 0.1, 2, 1, , , , , 0.1], category: 'alert', priority: 7 },
  danger: { params: [0.6, , 150, 0.01, 0.2, 0.15, 3, 1, , , , , 0.05, 0.3], category: 'alert', priority: 9 },

  // Victory/Defeat
  victorySmall: { params: [0.4, , 600, 0.02, 0.1, 0.2, , 1, , , 100, 0.02, , , , , , 0.8], category: 'fanfare' },
  victoryLarge: { params: [0.6, , 400, 0.03, 0.2, 0.35, , 1, 5, , 200, 0.05, 0.1, , , , 0.1, 0.9], category: 'fanfare', priority: 10 },
  defeatSmall: { params: [0.3, , 300, 0.01, 0.1, 0.2, 3, 1, , , -50, 0.03], category: 'fanfare' },
  defeatLarge: { params: [0.5, , 200, 0.02, 0.2, 0.4, 3, 1, -5, , -150, 0.07, , 0.3], category: 'fanfare', priority: 10 },
} as const;

export type SoundName = keyof typeof SOUNDS;

// ════════════════════════════════════════════════════════════════
// CONCURRENT SOUND MANAGEMENT
// ════════════════════════════════════════════════════════════════

interface ActiveSound {
  name: string;
  startTime: number;
  priority: number;
  category: SoundCategory;
}

const MAX_CONCURRENT_SOUNDS = 8;
const SOUND_COOLDOWN_MS = 50; // Minimum time between same sound

// ════════════════════════════════════════════════════════════════
// MODULE STATE
// ════════════════════════════════════════════════════════════════

let audioInitialized = false;
let settingsRef: SettingsStore | null = null;
let activeSounds: ActiveSound[] = [];
let lastPlayedTimes: Map<string, number> = new Map();

// ════════════════════════════════════════════════════════════════
// CORE FUNCTIONS
// ════════════════════════════════════════════════════════════════

export function initAudio(): void {
  if (!browser || audioInitialized) return;
  audioInitialized = true;
  resumeAudio();
}

function getCategoryVolume(category: SoundCategory): number {
  if (!settingsRef) return 1.0;
  
  const settings = settingsRef;
  const masterVolume = settings.audioVolume ?? 0.5;
  
  // Get category-specific volume (extend settings for this)
  const categoryVolumes: Record<SoundCategory, number> = {
    ui: 0.8,
    game: 1.0,
    ambient: 0.3,
    alert: 1.0,
    fanfare: 0.9,
  };
  
  return masterVolume * (categoryVolumes[category] ?? 1.0);
}

function canPlaySound(name: string, definition: SoundDefinition): boolean {
  const now = Date.now();
  
  // Check cooldown for same sound
  const lastPlayed = lastPlayedTimes.get(name) ?? 0;
  if (now - lastPlayed < SOUND_COOLDOWN_MS) {
    return false;
  }
  
  // Check concurrent limit
  // Remove expired sounds (older than 1 second)
  activeSounds = activeSounds.filter(s => now - s.startTime < 1000);
  
  if (activeSounds.length >= MAX_CONCURRENT_SOUNDS) {
    // Allow if this sound has higher priority
    const lowestPriority = Math.min(...activeSounds.map(s => s.priority));
    const thisPriority = definition.priority ?? 5;
    
    if (thisPriority <= lowestPriority) {
      return false;
    }
    
    // Remove lowest priority sound to make room
    const indexToRemove = activeSounds.findIndex(s => s.priority === lowestPriority);
    if (indexToRemove !== -1) {
      activeSounds.splice(indexToRemove, 1);
    }
  }
  
  return true;
}

function playSound(name: SoundName): void {
  if (!browser) return;
  
  // Check settings
  if (settingsRef && !settingsRef.audioEnabled) return;
  
  // Initialize if needed
  if (!audioInitialized) {
    initAudio();
  }
  
  const definition = SOUNDS[name];
  if (!definition) {
    console.warn(`Unknown sound: ${name}`);
    return;
  }
  
  // Check if can play
  if (!canPlaySound(name, definition)) {
    return;
  }
  
  // Apply volume
  const volume = getCategoryVolume(definition.category);
  const params = [...definition.params] as ZzFXParams;
  params[0] = (params[0] ?? 1) * volume;
  
  try {
    zzfx(...params);
    
    // Track active sound
    const now = Date.now();
    lastPlayedTimes.set(name, now);
    activeSounds.push({
      name,
      startTime: now,
      priority: definition.priority ?? 5,
      category: definition.category,
    });
  } catch {
    // Audio might fail in certain contexts
  }
}

// Dynamic sound with custom params (for multiplier-based sounds, etc.)
function playDynamic(params: ZzFXParams, category: SoundCategory = 'game'): void {
  if (!browser) return;
  if (settingsRef && !settingsRef.audioEnabled) return;
  
  if (!audioInitialized) {
    initAudio();
  }
  
  const volume = getCategoryVolume(category);
  const adjustedParams = [...params] as ZzFXParams;
  adjustedParams[0] = (adjustedParams[0] ?? 1) * volume;
  
  try {
    zzfx(...adjustedParams);
  } catch {
    // Ignore
  }
}

// ════════════════════════════════════════════════════════════════
// AUDIO MANAGER INTERFACE
// ════════════════════════════════════════════════════════════════

export interface AudioManager {
  init: () => void;
  play: (name: SoundName) => void;
  playDynamic: (params: ZzFXParams, category?: SoundCategory) => void;
  
  // UI shortcuts
  click: () => void;
  hover: () => void;
  open: () => void;
  close: () => void;
  error: () => void;
  success: () => void;
  
  // Game shortcuts
  keystroke: () => void;
  keystrokeError: () => void;
  countdown: () => void;
  countdownGo: () => void;
  roundComplete: () => void;
  gameComplete: () => void;
  
  // Feed events
  jackIn: () => void;
  extract: () => void;
  traced: () => void;
  survived: () => void;
  jackpot: () => void;
  scanWarning: () => void;
  scanStart: () => void;
  
  // Alerts
  alert: () => void;
  warning: () => void;
  danger: () => void;
  
  // Victory/Defeat
  victorySmall: () => void;
  victoryLarge: () => void;
  defeatSmall: () => void;
  defeatLarge: () => void;
}

// ════════════════════════════════════════════════════════════════
// FACTORY
// ════════════════════════════════════════════════════════════════

export function createAudioManager(settings: SettingsStore): AudioManager {
  settingsRef = settings;
  
  return {
    init: initAudio,
    play: playSound,
    playDynamic,
    
    // UI
    click: () => playSound('click'),
    hover: () => playSound('hover'),
    open: () => playSound('open'),
    close: () => playSound('close'),
    error: () => playSound('error'),
    success: () => playSound('success'),
    
    // Game
    keystroke: () => playSound('keystroke'),
    keystrokeError: () => playSound('keystrokeError'),
    countdown: () => playSound('countdown'),
    countdownGo: () => playSound('countdownGo'),
    roundComplete: () => playSound('roundComplete'),
    gameComplete: () => playSound('gameComplete'),
    
    // Feed
    jackIn: () => playSound('jackIn'),
    extract: () => playSound('extract'),
    traced: () => playSound('traced'),
    survived: () => playSound('survived'),
    jackpot: () => playSound('jackpot'),
    scanWarning: () => playSound('scanWarning'),
    scanStart: () => playSound('scanStart'),
    
    // Alerts
    alert: () => playSound('alert'),
    warning: () => playSound('warning'),
    danger: () => playSound('danger'),
    
    // Fanfares
    victorySmall: () => playSound('victorySmall'),
    victoryLarge: () => playSound('victoryLarge'),
    defeatSmall: () => playSound('defeatSmall'),
    defeatLarge: () => playSound('defeatLarge'),
  };
}

// Legacy support
export function getAudioManager(): AudioManager {
  return createAudioManager(null as unknown as SettingsStore);
}
```

### Game-Specific Audio Managers

```typescript
// apps/web/src/lib/features/arcade/audio/hash-crash-audio.svelte.ts

import { createAudioManager, type AudioManager } from '$lib/core/audio';
import type { ZzFXParams } from '$lib/core/audio/zzfx';

export function createHashCrashAudio(baseAudio: AudioManager) {
  // Dynamic multiplier sound - pitch increases with multiplier
  function playMultiplierTick(multiplier: number) {
    const basePitch = 400 + Math.min(multiplier * 50, 800);
    const params: ZzFXParams = [0.15, , basePitch, , 0.01, 0.02, , 1, , , 20, 0.01];
    baseAudio.playDynamic(params, 'game');
  }
  
  // Tension levels based on multiplier
  function updateTension(multiplier: number) {
    if (multiplier < 2) return; // No tension at low multipliers
    
    if (multiplier < 5) {
      // Low tension - subtle background
      baseAudio.playDynamic([0.1, , 300, , 0.05, 0.1, 1, 0.5, , , , , , 0.1], 'ambient');
    } else if (multiplier < 10) {
      // Medium tension
      baseAudio.playDynamic([0.15, , 350, , 0.08, 0.12, 2, 0.6, 1, , , , , 0.2], 'ambient');
    } else {
      // High tension
      baseAudio.playDynamic([0.2, , 400, , 0.1, 0.15, 2, 0.7, 2, , , , , 0.3], 'ambient');
    }
  }
  
  function playCrash() {
    baseAudio.playDynamic([0.8, , 100, 0.01, 0.3, 0.5, 4, 1, -10, , -200, 0.1, , 0.8, , 0.2], 'game');
  }
  
  function playCashOut() {
    baseAudio.playDynamic([0.5, , 700, 0.01, 0.05, 0.1, , 1, , , 200, 0.02], 'game');
  }
  
  function playWin(multiplier: number) {
    if (multiplier < 2) {
      baseAudio.victorySmall();
    } else if (multiplier < 5) {
      baseAudio.play('victorySmall');
    } else if (multiplier < 20) {
      baseAudio.victoryLarge();
    } else {
      // Epic win
      baseAudio.playDynamic([0.7, , 300, 0.03, 0.3, 0.4, , 1, 7, , 250, 0.07, 0.15, , , , 0.15, 0.95], 'fanfare');
    }
  }
  
  return {
    playMultiplierTick,
    updateTension,
    playCrash,
    playCashOut,
    playWin,
    playLoss: () => baseAudio.defeatSmall(),
    playBettingStart: () => baseAudio.alert(),
    playBettingEnd: () => baseAudio.countdown(),
  };
}
```

### Sound Preloading

ZzFX generates sounds procedurally, so no preloading is needed. However, we can "warm up" the audio context:

```typescript
// apps/web/src/lib/core/audio/preload.ts

import { initAudio } from './manager.svelte';

/**
 * Warm up the audio context on first user interaction.
 * This prevents delayed sound playback on first click.
 */
export function warmUpAudio(): void {
  initAudio();
  
  // Play a silent sound to fully activate the audio context
  const ctx = new AudioContext();
  const oscillator = ctx.createOscillator();
  const gainNode = ctx.createGain();
  
  gainNode.gain.value = 0; // Silent
  oscillator.connect(gainNode);
  gainNode.connect(ctx.destination);
  
  oscillator.start();
  oscillator.stop(ctx.currentTime + 0.001);
}
```

---

## Mobile Audio Considerations

### iOS/Safari Restrictions

iOS requires user interaction before playing audio. Handle this:

```typescript
// apps/web/src/lib/core/audio/mobile.ts

import { browser } from '$app/environment';

let audioUnlocked = false;

export function isMobile(): boolean {
  if (!browser) return false;
  return /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);
}

export function isAudioUnlocked(): boolean {
  return audioUnlocked;
}

export function unlockAudio(): void {
  if (!browser || audioUnlocked) return;
  
  // Create and play a silent buffer
  const ctx = new (window.AudioContext || (window as any).webkitAudioContext)();
  const buffer = ctx.createBuffer(1, 1, 22050);
  const source = ctx.createBufferSource();
  source.buffer = buffer;
  source.connect(ctx.destination);
  source.start(0);
  
  audioUnlocked = true;
}

// Call on any touch/click event before needing audio
export function setupMobileAudio(): void {
  if (!browser || !isMobile()) return;
  
  const events = ['touchstart', 'touchend', 'click'];
  
  const unlock = () => {
    unlockAudio();
    events.forEach(e => document.removeEventListener(e, unlock));
  };
  
  events.forEach(e => document.addEventListener(e, unlock, { once: true }));
}
```

### Component Integration

```svelte
<!-- apps/web/src/lib/features/arcade/ArcadeShell.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { setupMobileAudio } from '$lib/core/audio/mobile';
  import { createAudioManager } from '$lib/core/audio';
  import { getSettings } from '$lib/core/settings';
  
  const settings = getSettings();
  const audio = createAudioManager(settings);
  
  onMount(() => {
    setupMobileAudio();
    audio.init();
  });
</script>
```

---

## Accessibility

### Visual Alternatives

Every important audio cue should have a visual equivalent:

| Audio Event | Visual Alternative |
|-------------|-------------------|
| Alert/Warning | Screen flash, icon pulse, border highlight |
| Countdown | Number display, progress bar |
| Success/Failure | Color change, icon animation |
| Keystroke | Character highlight |
| Combo | Visual streak indicator, particle effect |
| Danger | Screen tint, pulsing border |

### Implementation

```typescript
// apps/web/src/lib/core/accessibility/audio-visual.ts

export interface VisualFeedbackConfig {
  screenFlash?: { color: string; duration: number };
  iconPulse?: { target: string; scale: number };
  border?: { color: string; width: number };
  tint?: { color: string; opacity: number };
}

const AUDIO_VISUAL_MAP: Record<string, VisualFeedbackConfig> = {
  alert: { screenFlash: { color: '#ffff00', duration: 100 } },
  warning: { screenFlash: { color: '#ff8800', duration: 150 }, border: { color: '#ff8800', width: 2 } },
  danger: { screenFlash: { color: '#ff0000', duration: 200 }, tint: { color: '#ff0000', opacity: 0.1 } },
  success: { screenFlash: { color: '#00ff00', duration: 100 } },
  error: { screenFlash: { color: '#ff0000', duration: 100 } },
  traced: { screenFlash: { color: '#ff0000', duration: 300 }, tint: { color: '#ff0000', opacity: 0.2 } },
  survived: { screenFlash: { color: '#00ff00', duration: 200 } },
  jackpot: { screenFlash: { color: '#ffff00', duration: 400 } },
};

export function getVisualFeedback(soundName: string): VisualFeedbackConfig | undefined {
  return AUDIO_VISUAL_MAP[soundName];
}
```

### Captions for Important Audio

```typescript
// apps/web/src/lib/core/accessibility/captions.ts

export interface AudioCaption {
  text: string;
  duration: number;
  priority: number;
  icon?: string;
}

const AUDIO_CAPTIONS: Record<string, AudioCaption> = {
  // Critical game events
  scanWarning: { text: 'TRACE SCAN APPROACHING', duration: 3000, priority: 10, icon: '!' },
  scanStart: { text: 'TRACE SCAN IN PROGRESS', duration: 2000, priority: 10, icon: '!' },
  traced: { text: 'YOU HAVE BEEN TRACED', duration: 3000, priority: 10, icon: 'X' },
  survived: { text: 'SCAN SURVIVED', duration: 2000, priority: 8, icon: '>' },
  
  // Game outcomes
  jackpot: { text: 'JACKPOT!', duration: 3000, priority: 9, icon: '$' },
  victoryLarge: { text: 'VICTORY', duration: 2500, priority: 8, icon: '>' },
  defeatLarge: { text: 'DEFEAT', duration: 2500, priority: 8, icon: 'X' },
  
  // Countdown
  countdownGo: { text: 'GO!', duration: 1000, priority: 7 },
  
  // Arcade specific
  crashExplosion: { text: 'CRASHED!', duration: 2000, priority: 9, icon: '!' },
  exposed: { text: 'SHADOW EXPOSED!', duration: 3000, priority: 10, icon: '!' },
  dominationVictory: { text: 'DOMINATION ACHIEVED', duration: 4000, priority: 10, icon: '>' },
};

export function getCaption(soundName: string): AudioCaption | undefined {
  return AUDIO_CAPTIONS[soundName];
}
```

### Captions Component

```svelte
<!-- apps/web/src/lib/ui/accessibility/AudioCaptions.svelte -->
<script lang="ts">
  import { getCaption } from '$lib/core/accessibility/captions';
  import { getSettings } from '$lib/core/settings';
  
  const settings = getSettings();
  
  let currentCaption = $state<{ text: string; icon?: string } | null>(null);
  let timeoutId: ReturnType<typeof setTimeout> | null = null;
  
  export function showCaption(soundName: string) {
    // Only show if captions enabled in settings
    if (!settings.captionsEnabled) return;
    
    const caption = getCaption(soundName);
    if (!caption) return;
    
    if (timeoutId) clearTimeout(timeoutId);
    
    currentCaption = { text: caption.text, icon: caption.icon };
    
    timeoutId = setTimeout(() => {
      currentCaption = null;
    }, caption.duration);
  }
</script>

{#if currentCaption}
  <div class="audio-caption" role="alert" aria-live="assertive">
    {#if currentCaption.icon}
      <span class="caption-icon">[{currentCaption.icon}]</span>
    {/if}
    <span class="caption-text">{currentCaption.text}</span>
  </div>
{/if}

<style>
  .audio-caption {
    position: fixed;
    bottom: 4rem;
    left: 50%;
    transform: translateX(-50%);
    background: var(--color-bg-terminal);
    border: 1px solid var(--color-phosphor);
    padding: 0.5rem 1rem;
    font-family: var(--font-mono);
    font-size: 1rem;
    color: var(--color-phosphor);
    z-index: 9999;
    animation: caption-fade-in 0.15s ease-out;
  }
  
  .caption-icon {
    margin-right: 0.5rem;
    color: var(--color-warning);
  }
  
  @keyframes caption-fade-in {
    from {
      opacity: 0;
      transform: translateX(-50%) translateY(0.5rem);
    }
    to {
      opacity: 1;
      transform: translateX(-50%) translateY(0);
    }
  }
</style>
```

---

## Testing Checklist

### Sound Quality
- [ ] All ZzFX parameters produce audible, pleasant sounds
- [ ] No clipping or distortion at max volume
- [ ] Sounds are distinguishable from each other
- [ ] Frequency ranges don't conflict excessively

### Performance
- [ ] No audio lag on first play (context pre-warmed)
- [ ] Concurrent sound limiting prevents audio pile-up
- [ ] Mobile devices play sounds without delay
- [ ] No memory leaks from audio contexts

### Settings Integration
- [ ] Master mute works immediately
- [ ] Volume slider affects all sounds proportionally
- [ ] Category toggles work correctly
- [ ] Settings persist across sessions

### Game Integration
- [ ] Each game event triggers correct sound
- [ ] Dynamic sounds (multiplier-based) scale properly
- [ ] No missing sounds for edge cases
- [ ] Sound cooldowns prevent spam

### Accessibility
- [ ] Visual alternatives present for all critical sounds
- [ ] Captions display for important events
- [ ] Screen reader announces critical audio events
- [ ] Reduced motion setting simplifies audio

### Mobile
- [ ] Audio unlocks on first touch/click
- [ ] No console errors on iOS Safari
- [ ] Sounds play correctly on Android Chrome
- [ ] Battery impact is minimal

---

## Future Considerations

### Phase 4 Enhancements
- **Adaptive Audio**: Sound intensity based on position size/risk
- **Spatial Audio**: Web Audio API panning for multiplayer
- **Dynamic Mixing**: Automatic ducking of less important sounds
- **Ambient Layers**: Procedural background soundscapes

### Community Features
- **Custom Sound Packs**: User-uploadable ZzFX presets
- **Sound Sharing**: Share sound configurations
- **A/B Testing**: Track which sounds improve UX metrics

### Technical Improvements
- **Web Audio Worklets**: For more complex audio processing
- **Audio Sprites**: Pre-render common sequences
- **Compression**: Web Audio dynamics processing
- **Reverb/Effects**: Spatial processing for immersion
