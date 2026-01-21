# Game Engine Architecture

## Shared Infrastructure for GHOSTNET Arcade

**Version:** 1.0  
**Status:** Planning  
**Target:** Q2 2026  

---

## 1. Overview

The GHOSTNET Arcade Game Engine provides shared infrastructure for all 9 arcade games. Rather than each game implementing its own state management, timers, scoring, and reward systems from scratch, they compose these reusable building blocks.

### Purpose

- **Consistency**: Unified state machine patterns across all games
- **Reliability**: Battle-tested timer and animation systems
- **Flexibility**: Games can extend or override default behaviors
- **Maintainability**: Single source of truth for core mechanics
- **Performance**: Optimized for 60fps rendering and mobile devices

### Scope

The engine covers:

| Component | Responsibility |
|-----------|----------------|
| `GameEngine` | State machine (phases, transitions, guards) |
| `TimerSystem` | Countdowns, game clocks, intervals |
| `ScoreSystem` | Points, multipliers, combos, streaks |
| `RewardSystem` | Payout calculations, burn rate application |

What the engine does NOT handle (game-specific):
- Game-specific logic (crash curves, typing matching, reaction zones)
- Visual rendering (each game owns its Svelte components)
- Contract interactions (handled by providers/hooks)

---

## 2. Architecture Diagram

```
                              ARCADE GAME ARCHITECTURE
================================================================================

                         +---------------------------+
                         |      INDIVIDUAL GAME      |
                         |     (HashCrash.svelte)    |
                         +---------------------------+
                                      |
                         Extends / Composes
                                      |
                                      v
+--------------------------------------------------------------------------+
|                          GAME ENGINE LAYER                                |
|                                                                           |
|   +----------------+  +----------------+  +----------------+              |
|   |  GameEngine    |  |  TimerSystem   |  |  ScoreSystem   |             |
|   |  .svelte.ts    |  |  .svelte.ts    |  |  .svelte.ts    |             |
|   +----------------+  +----------------+  +----------------+              |
|          |                   |                   |                       |
|          |    +------------------------------------+                      |
|          |    |         RewardSystem.svelte.ts     |                     |
|          |    +------------------------------------+                      |
|          |                                                                |
+--------------------------------------------------------------------------+
                                      |
                         Uses / Depends On
                                      |
                                      v
+--------------------------------------------------------------------------+
|                            CORE LAYER                                     |
|                                                                           |
|   +----------------+  +----------------+  +----------------+              |
|   |  arcade.ts     |  |  WebSocket     |  |   Provider     |             |
|   |  (types)       |  |  Manager       |  |   Context      |             |
|   +----------------+  +----------------+  +----------------+              |
|                                                                           |
+--------------------------------------------------------------------------+
                                      |
                                      v
+--------------------------------------------------------------------------+
|                         SMART CONTRACT LAYER                              |
|                                                                           |
|   +----------------+  +----------------+  +----------------+              |
|   | ArcadeCore.sol |  |  GameSpecific  |  | SpectatorBets  |             |
|   |                |  |  Contracts     |  |    .sol        |             |
|   +----------------+  +----------------+  +----------------+              |
|                                                                           |
+--------------------------------------------------------------------------+


    Data Flow:
    ==========

    User Action --> GameEngine --> ScoreSystem --> RewardSystem --> Contract
         ^              |              |               |               |
         |              v              v               v               v
         +---- UI <---- TimerSystem    Feed Event     Burn Logic    Payout
```

---

## 3. Core Components

### 3.1 GameEngine.svelte.ts

The game engine provides a finite state machine (FSM) for managing game phases. All arcade games follow a consistent lifecycle.

```typescript
// apps/web/src/lib/features/arcade/engine/GameEngine.svelte.ts

/**
 * Game Engine - Core State Machine
 * =================================
 * Provides phase management for all arcade games.
 *
 * Standard Flow: idle -> betting -> playing -> resolving -> complete
 *
 * Games extend this by:
 * 1. Adding custom phases (e.g., 'countdown', 'matching')
 * 2. Adding transition guards
 * 3. Hooking into phase callbacks
 */

// ════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════

/** Standard game phases (games can extend with custom phases) */
export type StandardPhase = 'idle' | 'betting' | 'playing' | 'resolving' | 'complete';

/** Phase transition event */
export interface PhaseTransition<TPhase extends string = StandardPhase> {
  from: TPhase;
  to: TPhase;
  timestamp: number;
  data?: Record<string, unknown>;
}

/** Configuration for a game phase */
export interface PhaseConfig<TPhase extends string = StandardPhase> {
  /** Phase identifier */
  phase: TPhase;
  /** Optional timeout (auto-transitions after duration) */
  timeout?: number;
  /** Phase to transition to on timeout */
  timeoutTarget?: TPhase;
  /** Callback when entering phase */
  onEnter?: () => void | Promise<void>;
  /** Callback when exiting phase */
  onExit?: () => void | Promise<void>;
  /** Guard function - return false to prevent transition */
  canEnter?: () => boolean;
}

/** Game engine configuration */
export interface GameEngineConfig<TPhase extends string = StandardPhase> {
  /** Initial phase (defaults to 'idle') */
  initialPhase?: TPhase;
  /** Phase configurations */
  phases: PhaseConfig<TPhase>[];
  /** Valid transitions map: phase -> allowed target phases */
  transitions: Record<TPhase, TPhase[]>;
  /** Global error handler */
  onError?: (error: Error, phase: TPhase) => void;
}

/** Game engine state */
export interface GameEngineState<TPhase extends string = StandardPhase> {
  /** Current phase */
  phase: TPhase;
  /** Previous phase (null on initial) */
  previousPhase: TPhase | null;
  /** Timestamp when current phase started */
  phaseStartTime: number;
  /** Whether a transition is in progress */
  transitioning: boolean;
  /** Error state (if any) */
  error: Error | null;
  /** Phase history for debugging */
  history: PhaseTransition<TPhase>[];
}

// ════════════════════════════════════════════════════════════════
// STORE INTERFACE
// ════════════════════════════════════════════════════════════════

export interface GameEngine<TPhase extends string = StandardPhase> {
  /** Current engine state (reactive) */
  readonly state: GameEngineState<TPhase>;
  /** Current phase (convenience getter) */
  readonly phase: TPhase;
  /** Time spent in current phase (ms) */
  readonly phaseElapsed: number;
  /** Whether in a specific phase */
  isPhase(phase: TPhase): boolean;
  /** Transition to a new phase */
  transition(to: TPhase, data?: Record<string, unknown>): Promise<boolean>;
  /** Reset to initial state */
  reset(): void;
  /** Cleanup timers on destroy */
  cleanup(): void;
}

// ════════════════════════════════════════════════════════════════
// STORE FACTORY
// ════════════════════════════════════════════════════════════════

/**
 * Create a game engine instance with custom phases and transitions.
 *
 * @example
 * ```typescript
 * type CrashPhase = 'idle' | 'betting' | 'rising' | 'crashed' | 'settling';
 *
 * const engine = createGameEngine<CrashPhase>({
 *   initialPhase: 'idle',
 *   phases: [
 *     { phase: 'betting', timeout: 10000, timeoutTarget: 'rising' },
 *     { phase: 'rising', onEnter: () => startMultiplier() },
 *     { phase: 'crashed', onEnter: () => playSound('crash') },
 *   ],
 *   transitions: {
 *     idle: ['betting'],
 *     betting: ['rising', 'idle'],
 *     rising: ['crashed'],
 *     crashed: ['settling'],
 *     settling: ['betting', 'idle'],
 *   },
 * });
 * ```
 */
export function createGameEngine<TPhase extends string = StandardPhase>(
  config: GameEngineConfig<TPhase>
): GameEngine<TPhase> {
  // ─────────────────────────────────────────────────────────────
  // STATE
  // ─────────────────────────────────────────────────────────────

  const initialPhase = config.initialPhase ?? ('idle' as TPhase);

  let state = $state<GameEngineState<TPhase>>({
    phase: initialPhase,
    previousPhase: null,
    phaseStartTime: Date.now(),
    transitioning: false,
    error: null,
    history: [],
  });

  // Phase timeout timer
  let timeoutId: ReturnType<typeof setTimeout> | null = null;

  // Phase config lookup
  const phaseConfigs = new Map<TPhase, PhaseConfig<TPhase>>();
  for (const pc of config.phases) {
    phaseConfigs.set(pc.phase, pc);
  }

  // ─────────────────────────────────────────────────────────────
  // DERIVED STATE
  // ─────────────────────────────────────────────────────────────

  const phaseElapsed = $derived(Date.now() - state.phaseStartTime);

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  function clearPhaseTimeout(): void {
    if (timeoutId) {
      clearTimeout(timeoutId);
      timeoutId = null;
    }
  }

  function setupPhaseTimeout(phaseConfig: PhaseConfig<TPhase>): void {
    if (phaseConfig.timeout && phaseConfig.timeoutTarget) {
      timeoutId = setTimeout(() => {
        transition(phaseConfig.timeoutTarget!);
      }, phaseConfig.timeout);
    }
  }

  function isValidTransition(from: TPhase, to: TPhase): boolean {
    const allowed = config.transitions[from];
    return allowed?.includes(to) ?? false;
  }

  // ─────────────────────────────────────────────────────────────
  // TRANSITIONS
  // ─────────────────────────────────────────────────────────────

  async function transition(
    to: TPhase,
    data?: Record<string, unknown>
  ): Promise<boolean> {
    const from = state.phase;

    // Prevent concurrent transitions
    if (state.transitioning) {
      console.warn(`[GameEngine] Transition blocked: already transitioning`);
      return false;
    }

    // Validate transition
    if (!isValidTransition(from, to)) {
      console.warn(`[GameEngine] Invalid transition: ${from} -> ${to}`);
      return false;
    }

    // Check entry guard
    const targetConfig = phaseConfigs.get(to);
    if (targetConfig?.canEnter && !targetConfig.canEnter()) {
      console.warn(`[GameEngine] Guard blocked transition to: ${to}`);
      return false;
    }

    state = { ...state, transitioning: true };

    try {
      // Exit current phase
      clearPhaseTimeout();
      const currentConfig = phaseConfigs.get(from);
      if (currentConfig?.onExit) {
        await currentConfig.onExit();
      }

      // Record transition
      const transitionRecord: PhaseTransition<TPhase> = {
        from,
        to,
        timestamp: Date.now(),
        data,
      };

      // Update state
      state = {
        phase: to,
        previousPhase: from,
        phaseStartTime: Date.now(),
        transitioning: false,
        error: null,
        history: [...state.history.slice(-19), transitionRecord], // Keep last 20
      };

      // Enter new phase
      if (targetConfig?.onEnter) {
        await targetConfig.onEnter();
      }

      // Setup timeout for new phase
      if (targetConfig) {
        setupPhaseTimeout(targetConfig);
      }

      return true;
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error));
      state = { ...state, transitioning: false, error: err };
      config.onError?.(err, from);
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────

  function isPhase(phase: TPhase): boolean {
    return state.phase === phase;
  }

  function reset(): void {
    clearPhaseTimeout();
    state = {
      phase: initialPhase,
      previousPhase: null,
      phaseStartTime: Date.now(),
      transitioning: false,
      error: null,
      history: [],
    };
  }

  function cleanup(): void {
    clearPhaseTimeout();
  }

  return {
    get state() {
      return state;
    },
    get phase() {
      return state.phase;
    },
    get phaseElapsed() {
      return phaseElapsed;
    },
    isPhase,
    transition,
    reset,
    cleanup,
  };
}
```

---

### 3.2 TimerSystem.svelte.ts

Provides countdown timers, game clocks, and interval management with proper cleanup.

```typescript
// apps/web/src/lib/features/arcade/engine/TimerSystem.svelte.ts

/**
 * Timer System - Countdown & Clock Management
 * ============================================
 * Provides various timer utilities for arcade games:
 * - Countdowns (betting phase, pre-game, etc.)
 * - Game clocks (elapsed time tracking)
 * - Intervals (periodic updates, animations)
 *
 * All timers clean up automatically when the store is destroyed.
 */

// ════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════

export type TimerStatus = 'idle' | 'running' | 'paused' | 'complete';

export interface CountdownState {
  /** Timer status */
  status: TimerStatus;
  /** Initial duration in ms */
  duration: number;
  /** Remaining time in ms */
  remaining: number;
  /** Progress from 0 to 1 (1 = complete) */
  progress: number;
  /** Formatted time string (MM:SS or SS.ms) */
  display: string;
  /** Whether in final seconds (for visual urgency) */
  critical: boolean;
}

export interface ClockState {
  /** Timer status */
  status: TimerStatus;
  /** Elapsed time in ms */
  elapsed: number;
  /** Formatted time string */
  display: string;
  /** Start timestamp */
  startTime: number;
}

export interface CountdownConfig {
  /** Duration in milliseconds */
  duration: number;
  /** Update interval (default: 100ms) */
  interval?: number;
  /** Threshold for critical state in ms (default: 5000) */
  criticalThreshold?: number;
  /** Show milliseconds in display (default: false) */
  showMilliseconds?: boolean;
  /** Callback when countdown completes */
  onComplete?: () => void;
  /** Callback on each tick */
  onTick?: (remaining: number) => void;
}

export interface ClockConfig {
  /** Update interval (default: 100ms) */
  interval?: number;
  /** Maximum duration before auto-stop (optional) */
  maxDuration?: number;
  /** Callback when max duration reached */
  onMaxReached?: () => void;
}

// ════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════

/**
 * Format milliseconds to MM:SS or SS.ms display
 */
export function formatTime(ms: number, showMilliseconds = false): string {
  const totalSeconds = Math.max(0, Math.ceil(ms / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;

  if (showMilliseconds && ms < 10000) {
    // Under 10 seconds, show SS.m
    const secs = Math.max(0, ms / 1000);
    return secs.toFixed(1);
  }

  if (minutes > 0) {
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  }
  return seconds.toString();
}

/**
 * Format elapsed time to HH:MM:SS
 */
export function formatElapsed(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  if (hours > 0) {
    return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }
  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
}

// ════════════════════════════════════════════════════════════════
// COUNTDOWN TIMER
// ════════════════════════════════════════════════════════════════

export interface Countdown {
  /** Current state (reactive) */
  readonly state: CountdownState;
  /** Start or restart the countdown */
  start(duration?: number): void;
  /** Pause the countdown */
  pause(): void;
  /** Resume a paused countdown */
  resume(): void;
  /** Stop and reset */
  stop(): void;
  /** Add time to the countdown */
  addTime(ms: number): void;
  /** Cleanup on destroy */
  cleanup(): void;
}

/**
 * Create a countdown timer.
 *
 * @example
 * ```typescript
 * const countdown = createCountdown({
 *   duration: 10000,
 *   onComplete: () => engine.transition('playing'),
 *   onTick: (remaining) => {
 *     if (remaining <= 3000) playSound('tick');
 *   },
 * });
 *
 * countdown.start();
 * ```
 */
export function createCountdown(config: CountdownConfig): Countdown {
  const {
    duration,
    interval = 100,
    criticalThreshold = 5000,
    showMilliseconds = false,
    onComplete,
    onTick,
  } = config;

  let state = $state<CountdownState>({
    status: 'idle',
    duration,
    remaining: duration,
    progress: 0,
    display: formatTime(duration, showMilliseconds),
    critical: false,
  });

  let intervalId: ReturnType<typeof setInterval> | null = null;
  let startTime = 0;
  let pausedRemaining = duration;

  function tick(): void {
    const elapsed = Date.now() - startTime;
    const remaining = Math.max(0, pausedRemaining - elapsed);
    const progress = 1 - remaining / state.duration;

    state = {
      ...state,
      remaining,
      progress,
      display: formatTime(remaining, showMilliseconds),
      critical: remaining <= criticalThreshold && remaining > 0,
    };

    onTick?.(remaining);

    if (remaining <= 0) {
      complete();
    }
  }

  function complete(): void {
    clearIntervalTimer();
    state = {
      ...state,
      status: 'complete',
      remaining: 0,
      progress: 1,
      display: formatTime(0, showMilliseconds),
      critical: false,
    };
    onComplete?.();
  }

  function clearIntervalTimer(): void {
    if (intervalId) {
      clearInterval(intervalId);
      intervalId = null;
    }
  }

  function start(newDuration?: number): void {
    clearIntervalTimer();

    const d = newDuration ?? duration;
    pausedRemaining = d;
    startTime = Date.now();

    state = {
      status: 'running',
      duration: d,
      remaining: d,
      progress: 0,
      display: formatTime(d, showMilliseconds),
      critical: d <= criticalThreshold,
    };

    intervalId = setInterval(tick, interval);
  }

  function pause(): void {
    if (state.status !== 'running') return;

    clearIntervalTimer();
    pausedRemaining = state.remaining;
    state = { ...state, status: 'paused' };
  }

  function resume(): void {
    if (state.status !== 'paused') return;

    startTime = Date.now();
    state = { ...state, status: 'running' };
    intervalId = setInterval(tick, interval);
  }

  function stop(): void {
    clearIntervalTimer();
    pausedRemaining = duration;
    state = {
      status: 'idle',
      duration,
      remaining: duration,
      progress: 0,
      display: formatTime(duration, showMilliseconds),
      critical: false,
    };
  }

  function addTime(ms: number): void {
    if (state.status === 'running') {
      pausedRemaining = state.remaining + ms;
      startTime = Date.now();
    } else if (state.status === 'paused') {
      pausedRemaining += ms;
    }
    state = {
      ...state,
      remaining: state.remaining + ms,
      duration: state.duration + ms,
    };
  }

  function cleanup(): void {
    clearIntervalTimer();
  }

  return {
    get state() {
      return state;
    },
    start,
    pause,
    resume,
    stop,
    addTime,
    cleanup,
  };
}

// ════════════════════════════════════════════════════════════════
// GAME CLOCK (ELAPSED TIME)
// ════════════════════════════════════════════════════════════════

export interface Clock {
  /** Current state (reactive) */
  readonly state: ClockState;
  /** Start the clock */
  start(): void;
  /** Pause the clock */
  pause(): void;
  /** Resume the clock */
  resume(): void;
  /** Stop and reset */
  stop(): void;
  /** Get current elapsed time */
  getElapsed(): number;
  /** Cleanup on destroy */
  cleanup(): void;
}

/**
 * Create an elapsed time clock.
 *
 * @example
 * ```typescript
 * const clock = createClock({
 *   maxDuration: 60000, // 1 minute max
 *   onMaxReached: () => engine.transition('resolving'),
 * });
 *
 * clock.start();
 * // Later: clock.getElapsed() -> time in ms
 * ```
 */
export function createClock(config: ClockConfig = {}): Clock {
  const { interval = 100, maxDuration, onMaxReached } = config;

  let state = $state<ClockState>({
    status: 'idle',
    elapsed: 0,
    display: '00:00',
    startTime: 0,
  });

  let intervalId: ReturnType<typeof setInterval> | null = null;
  let pausedElapsed = 0;

  function tick(): void {
    const elapsed = pausedElapsed + (Date.now() - state.startTime);

    state = {
      ...state,
      elapsed,
      display: formatElapsed(elapsed),
    };

    if (maxDuration && elapsed >= maxDuration) {
      stop();
      onMaxReached?.();
    }
  }

  function clearIntervalTimer(): void {
    if (intervalId) {
      clearInterval(intervalId);
      intervalId = null;
    }
  }

  function start(): void {
    clearIntervalTimer();
    pausedElapsed = 0;

    state = {
      status: 'running',
      elapsed: 0,
      display: '00:00',
      startTime: Date.now(),
    };

    intervalId = setInterval(tick, interval);
  }

  function pause(): void {
    if (state.status !== 'running') return;

    clearIntervalTimer();
    pausedElapsed = state.elapsed;
    state = { ...state, status: 'paused' };
  }

  function resume(): void {
    if (state.status !== 'paused') return;

    state = { ...state, status: 'running', startTime: Date.now() };
    intervalId = setInterval(tick, interval);
  }

  function stop(): void {
    clearIntervalTimer();
    pausedElapsed = 0;
    state = {
      status: 'idle',
      elapsed: 0,
      display: '00:00',
      startTime: 0,
    };
  }

  function getElapsed(): number {
    if (state.status === 'running') {
      return pausedElapsed + (Date.now() - state.startTime);
    }
    return pausedElapsed;
  }

  function cleanup(): void {
    clearIntervalTimer();
  }

  return {
    get state() {
      return state;
    },
    start,
    pause,
    resume,
    stop,
    getElapsed,
    cleanup,
  };
}

// ════════════════════════════════════════════════════════════════
// ANIMATION FRAME LOOP
// ════════════════════════════════════════════════════════════════

export interface FrameLoop {
  /** Whether loop is running */
  readonly running: boolean;
  /** Current frame timestamp */
  readonly frameTime: number;
  /** Delta since last frame (ms) */
  readonly delta: number;
  /** Start the loop */
  start(): void;
  /** Stop the loop */
  stop(): void;
}

/**
 * Create a requestAnimationFrame loop for smooth animations.
 *
 * @example
 * ```typescript
 * const loop = createFrameLoop((delta, time) => {
 *   multiplier += delta * growthRate;
 *   updateCurve();
 * });
 *
 * loop.start();
 * ```
 */
export function createFrameLoop(
  callback: (delta: number, time: number) => void
): FrameLoop {
  let running = $state(false);
  let frameTime = $state(0);
  let delta = $state(0);
  let lastTime = 0;
  let rafId: number | null = null;

  function loop(time: number): void {
    if (!running) return;

    delta = lastTime ? time - lastTime : 0;
    lastTime = time;
    frameTime = time;

    callback(delta, time);

    rafId = requestAnimationFrame(loop);
  }

  function start(): void {
    if (running) return;
    running = true;
    lastTime = 0;
    rafId = requestAnimationFrame(loop);
  }

  function stop(): void {
    running = false;
    if (rafId) {
      cancelAnimationFrame(rafId);
      rafId = null;
    }
  }

  return {
    get running() {
      return running;
    },
    get frameTime() {
      return frameTime;
    },
    get delta() {
      return delta;
    },
    start,
    stop,
  };
}
```

---

### 3.3 ScoreSystem.svelte.ts

Handles points, multipliers, combos, and streak tracking.

```typescript
// apps/web/src/lib/features/arcade/engine/ScoreSystem.svelte.ts

/**
 * Score System - Points, Multipliers, Combos
 * ==========================================
 * Provides scoring utilities for arcade games:
 * - Point accumulation with multipliers
 * - Combo tracking with decay
 * - Streak counting (consecutive successes)
 * - High score tracking
 */

// ════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════

export interface ScoreState {
  /** Current score */
  score: number;
  /** Current multiplier */
  multiplier: number;
  /** Base multiplier (before modifiers) */
  baseMultiplier: number;
  /** Current combo count */
  combo: number;
  /** Max combo this session */
  maxCombo: number;
  /** Current streak */
  streak: number;
  /** Max streak this session */
  maxStreak: number;
  /** Score history for animations */
  recentScores: ScoreEvent[];
}

export interface ScoreEvent {
  /** Unique ID for keying */
  id: string;
  /** Points added (before multiplier) */
  basePoints: number;
  /** Points added (after multiplier) */
  finalPoints: number;
  /** Multiplier at time of score */
  multiplier: number;
  /** Combo at time of score */
  combo: number;
  /** Timestamp */
  timestamp: number;
  /** Label for display */
  label?: string;
}

export interface ScoreConfig {
  /** Initial multiplier (default: 1) */
  initialMultiplier?: number;
  /** Combo decay time in ms (0 = no decay) */
  comboDecay?: number;
  /** Max combo (0 = unlimited) */
  maxCombo?: number;
  /** Multiplier increase per combo level */
  comboMultiplierBonus?: number;
  /** Number of recent scores to keep */
  recentScoresLimit?: number;
}

// ════════════════════════════════════════════════════════════════
// STORE INTERFACE
// ════════════════════════════════════════════════════════════════

export interface ScoreSystem {
  /** Current state (reactive) */
  readonly state: ScoreState;
  /** Add points with optional label */
  addScore(points: number, label?: string): ScoreEvent;
  /** Add points without affecting combo */
  addBonus(points: number, label?: string): ScoreEvent;
  /** Increment combo */
  incrementCombo(): void;
  /** Reset combo to 0 */
  breakCombo(): void;
  /** Increment streak */
  incrementStreak(): void;
  /** Reset streak to 0 */
  breakStreak(): void;
  /** Set base multiplier */
  setMultiplier(value: number): void;
  /** Add temporary multiplier modifier */
  addMultiplierModifier(modifier: number, duration?: number): void;
  /** Reset all scores */
  reset(): void;
  /** Cleanup timers */
  cleanup(): void;
}

// ════════════════════════════════════════════════════════════════
// STORE FACTORY
// ════════════════════════════════════════════════════════════════

let scoreIdCounter = 0;

/**
 * Create a score system instance.
 *
 * @example
 * ```typescript
 * const score = createScoreSystem({
 *   comboDecay: 2000,
 *   comboMultiplierBonus: 0.1, // +0.1x per combo level
 * });
 *
 * // On successful action
 * score.incrementCombo();
 * score.addScore(100, 'Perfect hit!');
 *
 * // On failure
 * score.breakCombo();
 * ```
 */
export function createScoreSystem(config: ScoreConfig = {}): ScoreSystem {
  const {
    initialMultiplier = 1,
    comboDecay = 0,
    maxCombo = 0,
    comboMultiplierBonus = 0,
    recentScoresLimit = 10,
  } = config;

  // ─────────────────────────────────────────────────────────────
  // STATE
  // ─────────────────────────────────────────────────────────────

  let state = $state<ScoreState>({
    score: 0,
    multiplier: initialMultiplier,
    baseMultiplier: initialMultiplier,
    combo: 0,
    maxCombo: 0,
    streak: 0,
    maxStreak: 0,
    recentScores: [],
  });

  // Timers
  let comboDecayTimer: ReturnType<typeof setTimeout> | null = null;
  const multiplierModifiers: Array<{ value: number; timerId?: ReturnType<typeof setTimeout> }> = [];

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  function calculateMultiplier(): number {
    let mult = state.baseMultiplier;

    // Combo bonus
    if (comboMultiplierBonus > 0) {
      mult += state.combo * comboMultiplierBonus;
    }

    // Temporary modifiers
    for (const mod of multiplierModifiers) {
      mult += mod.value;
    }

    return Math.max(0, mult);
  }

  function updateMultiplier(): void {
    state = { ...state, multiplier: calculateMultiplier() };
  }

  function resetComboDecayTimer(): void {
    if (comboDecayTimer) {
      clearTimeout(comboDecayTimer);
      comboDecayTimer = null;
    }

    if (comboDecay > 0 && state.combo > 0) {
      comboDecayTimer = setTimeout(() => {
        breakCombo();
      }, comboDecay);
    }
  }

  function generateScoreId(): string {
    return `score-${++scoreIdCounter}-${Date.now()}`;
  }

  // ─────────────────────────────────────────────────────────────
  // SCORING
  // ─────────────────────────────────────────────────────────────

  function addScore(points: number, label?: string): ScoreEvent {
    const multiplier = state.multiplier;
    const finalPoints = Math.round(points * multiplier);

    const event: ScoreEvent = {
      id: generateScoreId(),
      basePoints: points,
      finalPoints,
      multiplier,
      combo: state.combo,
      timestamp: Date.now(),
      label,
    };

    state = {
      ...state,
      score: state.score + finalPoints,
      recentScores: [event, ...state.recentScores.slice(0, recentScoresLimit - 1)],
    };

    return event;
  }

  function addBonus(points: number, label?: string): ScoreEvent {
    // Bonus doesn't use multiplier
    const event: ScoreEvent = {
      id: generateScoreId(),
      basePoints: points,
      finalPoints: points,
      multiplier: 1,
      combo: state.combo,
      timestamp: Date.now(),
      label,
    };

    state = {
      ...state,
      score: state.score + points,
      recentScores: [event, ...state.recentScores.slice(0, recentScoresLimit - 1)],
    };

    return event;
  }

  // ─────────────────────────────────────────────────────────────
  // COMBO
  // ─────────────────────────────────────────────────────────────

  function incrementCombo(): void {
    let newCombo = state.combo + 1;

    if (maxCombo > 0 && newCombo > maxCombo) {
      newCombo = maxCombo;
    }

    state = {
      ...state,
      combo: newCombo,
      maxCombo: Math.max(state.maxCombo, newCombo),
    };

    updateMultiplier();
    resetComboDecayTimer();
  }

  function breakCombo(): void {
    if (comboDecayTimer) {
      clearTimeout(comboDecayTimer);
      comboDecayTimer = null;
    }

    state = { ...state, combo: 0 };
    updateMultiplier();
  }

  // ─────────────────────────────────────────────────────────────
  // STREAK
  // ─────────────────────────────────────────────────────────────

  function incrementStreak(): void {
    const newStreak = state.streak + 1;
    state = {
      ...state,
      streak: newStreak,
      maxStreak: Math.max(state.maxStreak, newStreak),
    };
  }

  function breakStreak(): void {
    state = { ...state, streak: 0 };
  }

  // ─────────────────────────────────────────────────────────────
  // MULTIPLIER
  // ─────────────────────────────────────────────────────────────

  function setMultiplier(value: number): void {
    state = { ...state, baseMultiplier: value };
    updateMultiplier();
  }

  function addMultiplierModifier(modifier: number, duration?: number): void {
    const entry: { value: number; timerId?: ReturnType<typeof setTimeout> } = {
      value: modifier,
    };

    if (duration) {
      entry.timerId = setTimeout(() => {
        const index = multiplierModifiers.indexOf(entry);
        if (index > -1) {
          multiplierModifiers.splice(index, 1);
          updateMultiplier();
        }
      }, duration);
    }

    multiplierModifiers.push(entry);
    updateMultiplier();
  }

  // ─────────────────────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────────────────────

  function reset(): void {
    cleanup();
    state = {
      score: 0,
      multiplier: initialMultiplier,
      baseMultiplier: initialMultiplier,
      combo: 0,
      maxCombo: 0,
      streak: 0,
      maxStreak: 0,
      recentScores: [],
    };
  }

  function cleanup(): void {
    if (comboDecayTimer) {
      clearTimeout(comboDecayTimer);
      comboDecayTimer = null;
    }

    for (const mod of multiplierModifiers) {
      if (mod.timerId) {
        clearTimeout(mod.timerId);
      }
    }
    multiplierModifiers.length = 0;
  }

  return {
    get state() {
      return state;
    },
    addScore,
    addBonus,
    incrementCombo,
    breakCombo,
    incrementStreak,
    breakStreak,
    setMultiplier,
    addMultiplierModifier,
    reset,
    cleanup,
  };
}
```

---

### 3.4 RewardSystem.svelte.ts

Handles payout calculations, burn rate application, and reward distribution.

```typescript
// apps/web/src/lib/features/arcade/engine/RewardSystem.svelte.ts

/**
 * Reward System - Payout Calculations & Burn Logic
 * =================================================
 * Provides reward calculation utilities for arcade games:
 * - Bet/entry fee tracking
 * - Payout calculations with house edge
 * - Burn rate application
 * - Reward tier evaluation
 */

// ════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════

export interface RewardTier {
  /** Unique identifier */
  id: string;
  /** Display name */
  name: string;
  /** Minimum threshold to qualify */
  minThreshold: number;
  /** Reward value (interpretation depends on reward type) */
  value: number;
  /** Human-readable description */
  description: string;
}

export interface RewardConfig {
  /** House edge as decimal (0.03 = 3%) */
  houseEdge: number;
  /** Burn rate as decimal (1.0 = 100% of house edge burned) */
  burnRate: number;
  /** Minimum bet amount in wei */
  minBet: bigint;
  /** Maximum bet amount in wei */
  maxBet: bigint;
  /** Reward tiers (sorted by threshold descending) */
  tiers?: RewardTier[];
}

export interface PayoutCalculation {
  /** Original bet amount */
  bet: bigint;
  /** Multiplier applied */
  multiplier: number;
  /** Gross payout (bet * multiplier) */
  grossPayout: bigint;
  /** House edge amount */
  houseEdgeAmount: bigint;
  /** Amount burned */
  burnAmount: bigint;
  /** Net payout to player */
  netPayout: bigint;
  /** Profit (net - bet) */
  profit: bigint;
  /** Whether player is in profit */
  isWin: boolean;
}

export interface PoolPayoutCalculation {
  /** Total pool size */
  totalPool: bigint;
  /** Winning side total */
  winningPool: bigint;
  /** Losing side total */
  losingPool: bigint;
  /** Rake taken */
  rakeAmount: bigint;
  /** Amount burned */
  burnAmount: bigint;
  /** Distributable pool */
  distributablePool: bigint;
  /** Payout multiplier for winners */
  payoutMultiplier: number;
}

export interface RewardState {
  /** Current bet amount */
  currentBet: bigint;
  /** Entry fee (burned on entry) */
  entryFee: bigint;
  /** Accumulated winnings this session */
  sessionWinnings: bigint;
  /** Accumulated losses this session */
  sessionLosses: bigint;
  /** Net P&L this session */
  sessionPnL: bigint;
  /** Games played this session */
  gamesPlayed: number;
  /** Games won this session */
  gamesWon: number;
  /** Win rate (0-1) */
  winRate: number;
}

// ════════════════════════════════════════════════════════════════
// STORE INTERFACE
// ════════════════════════════════════════════════════════════════

export interface RewardSystem {
  /** Current state (reactive) */
  readonly state: RewardState;
  /** Configuration */
  readonly config: RewardConfig;
  /** Set current bet amount */
  setBet(amount: bigint): boolean;
  /** Set entry fee */
  setEntryFee(amount: bigint): void;
  /** Calculate payout for a given multiplier */
  calculatePayout(multiplier: number, bet?: bigint): PayoutCalculation;
  /** Calculate pool-based payout (for betting games) */
  calculatePoolPayout(
    totalPool: bigint,
    winningPool: bigint,
    losingPool: bigint,
    rake?: number
  ): PoolPayoutCalculation;
  /** Record a win */
  recordWin(amount: bigint): void;
  /** Record a loss */
  recordLoss(amount: bigint): void;
  /** Get reward tier for a value */
  getRewardTier(value: number): RewardTier | null;
  /** Reset session stats */
  resetSession(): void;
}

// ════════════════════════════════════════════════════════════════
// STORE FACTORY
// ════════════════════════════════════════════════════════════════

/**
 * Create a reward system instance.
 *
 * @example
 * ```typescript
 * const rewards = createRewardSystem({
 *   houseEdge: 0.03,     // 3% house edge
 *   burnRate: 1.0,       // 100% of edge burned
 *   minBet: 10n * 10n**18n,
 *   maxBet: 1000n * 10n**18n,
 *   tiers: [
 *     { id: 'perfect', name: 'PERFECT', minThreshold: 1.0, value: -0.25, description: '-25% death rate' },
 *     { id: 'excellent', name: 'Excellent', minThreshold: 0.95, value: -0.20, description: '-20% death rate' },
 *   ],
 * });
 *
 * // Calculate potential payout
 * const payout = rewards.calculatePayout(5.0);
 * console.log(`Win ${payout.netPayout} $DATA at 5x`);
 * ```
 */
export function createRewardSystem(config: RewardConfig): RewardSystem {
  // Sort tiers by threshold descending
  const sortedTiers = config.tiers
    ? [...config.tiers].sort((a, b) => b.minThreshold - a.minThreshold)
    : [];

  // ─────────────────────────────────────────────────────────────
  // STATE
  // ─────────────────────────────────────────────────────────────

  let state = $state<RewardState>({
    currentBet: 0n,
    entryFee: 0n,
    sessionWinnings: 0n,
    sessionLosses: 0n,
    sessionPnL: 0n,
    gamesPlayed: 0,
    gamesWon: 0,
    winRate: 0,
  });

  // ─────────────────────────────────────────────────────────────
  // BET MANAGEMENT
  // ─────────────────────────────────────────────────────────────

  function setBet(amount: bigint): boolean {
    if (amount < config.minBet || amount > config.maxBet) {
      return false;
    }
    state = { ...state, currentBet: amount };
    return true;
  }

  function setEntryFee(amount: bigint): void {
    state = { ...state, entryFee: amount };
  }

  // ─────────────────────────────────────────────────────────────
  // PAYOUT CALCULATIONS
  // ─────────────────────────────────────────────────────────────

  function calculatePayout(multiplier: number, bet?: bigint): PayoutCalculation {
    const betAmount = bet ?? state.currentBet;

    // Convert multiplier to bigint-safe calculation
    // multiplier is like 5.67 -> 567 / 100
    const multiplierBps = BigInt(Math.floor(multiplier * 100));
    const grossPayout = (betAmount * multiplierBps) / 100n;

    // House edge applies to profit portion
    const profit = grossPayout - betAmount;
    const houseEdgeBps = BigInt(Math.floor(config.houseEdge * 10000));
    const houseEdgeAmount = profit > 0n ? (profit * houseEdgeBps) / 10000n : 0n;

    // Burn amount
    const burnRateBps = BigInt(Math.floor(config.burnRate * 10000));
    const burnAmount = (houseEdgeAmount * burnRateBps) / 10000n;

    // Net payout
    const netPayout = grossPayout - houseEdgeAmount;
    const netProfit = netPayout - betAmount;

    return {
      bet: betAmount,
      multiplier,
      grossPayout,
      houseEdgeAmount,
      burnAmount,
      netPayout,
      profit: netProfit,
      isWin: netProfit > 0n,
    };
  }

  function calculatePoolPayout(
    totalPool: bigint,
    winningPool: bigint,
    losingPool: bigint,
    rake = 0.05
  ): PoolPayoutCalculation {
    const rakeBps = BigInt(Math.floor(rake * 10000));
    const rakeAmount = (totalPool * rakeBps) / 10000n;

    const burnRateBps = BigInt(Math.floor(config.burnRate * 10000));
    const burnAmount = (rakeAmount * burnRateBps) / 10000n;

    const distributablePool = totalPool - rakeAmount;

    // Payout multiplier for winners
    const payoutMultiplier =
      winningPool > 0n
        ? Number((distributablePool * 100n) / winningPool) / 100
        : 0;

    return {
      totalPool,
      winningPool,
      losingPool,
      rakeAmount,
      burnAmount,
      distributablePool,
      payoutMultiplier,
    };
  }

  // ─────────────────────────────────────────────────────────────
  // SESSION TRACKING
  // ─────────────────────────────────────────────────────────────

  function recordWin(amount: bigint): void {
    const newGamesPlayed = state.gamesPlayed + 1;
    const newGamesWon = state.gamesWon + 1;
    const newWinnings = state.sessionWinnings + amount;
    const newPnL = newWinnings - state.sessionLosses;

    state = {
      ...state,
      sessionWinnings: newWinnings,
      sessionPnL: newPnL,
      gamesPlayed: newGamesPlayed,
      gamesWon: newGamesWon,
      winRate: newGamesWon / newGamesPlayed,
    };
  }

  function recordLoss(amount: bigint): void {
    const newGamesPlayed = state.gamesPlayed + 1;
    const newLosses = state.sessionLosses + amount;
    const newPnL = state.sessionWinnings - newLosses;

    state = {
      ...state,
      sessionLosses: newLosses,
      sessionPnL: newPnL,
      gamesPlayed: newGamesPlayed,
      winRate: state.gamesWon / newGamesPlayed,
    };
  }

  // ─────────────────────────────────────────────────────────────
  // REWARD TIERS
  // ─────────────────────────────────────────────────────────────

  function getRewardTier(value: number): RewardTier | null {
    for (const tier of sortedTiers) {
      if (value >= tier.minThreshold) {
        return tier;
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // RESET
  // ─────────────────────────────────────────────────────────────

  function resetSession(): void {
    state = {
      currentBet: 0n,
      entryFee: 0n,
      sessionWinnings: 0n,
      sessionLosses: 0n,
      sessionPnL: 0n,
      gamesPlayed: 0,
      gamesWon: 0,
      winRate: 0,
    };
  }

  return {
    get state() {
      return state;
    },
    get config() {
      return config;
    },
    setBet,
    setEntryFee,
    calculatePayout,
    calculatePoolPayout,
    recordWin,
    recordLoss,
    getRewardTier,
    resetSession,
  };
}

// ════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ════════════════════════════════════════════════════════════════

/**
 * Format bigint token amount to human-readable string
 */
export function formatTokenAmount(amount: bigint, decimals = 18): string {
  const divisor = 10n ** BigInt(decimals);
  const whole = amount / divisor;
  const fraction = amount % divisor;

  if (fraction === 0n) {
    return whole.toLocaleString();
  }

  // Show up to 2 decimal places
  const fractionStr = fraction.toString().padStart(decimals, '0');
  const significantFraction = fractionStr.slice(0, 2);
  return `${whole.toLocaleString()}.${significantFraction}`;
}

/**
 * Parse human-readable amount to bigint
 */
export function parseTokenAmount(amount: string, decimals = 18): bigint {
  const parts = amount.split('.');
  const whole = BigInt(parts[0] || '0');
  const fraction = parts[1] ? BigInt(parts[1].padEnd(decimals, '0').slice(0, decimals)) : 0n;
  const divisor = 10n ** BigInt(decimals);

  return whole * divisor + fraction;
}
```

---

## 4. Game State Machine

The standard game lifecycle follows this finite state machine:

```
                    STANDARD GAME STATE MACHINE
================================================================================

                           ┌───────────────┐
                           │     IDLE      │
                           └───────────────┘
                                   │
                           start() │
                                   ▼
    ┌──────────────────────────────────────────────────────────────────────────┐
    │                           BETTING PHASE                                   │
    │  ─────────────────────────────────────────────────────────────────────── │
    │  • Players place bets                                                     │
    │  • Countdown timer runs                                                   │
    │  • Optional: Spectators place side bets                                  │
    │                                                                           │
    │  Guards:                                                                  │
    │    canEnter: () => hasBalance >= minBet                                  │
    │                                                                           │
    │  Timeout: 10-30 seconds → auto-transition to PLAYING                     │
    └──────────────────────────────────────────────────────────────────────────┘
                                   │
         timeout / startGame() │
                                   ▼
    ┌──────────────────────────────────────────────────────────────────────────┐
    │                           PLAYING PHASE                                   │
    │  ─────────────────────────────────────────────────────────────────────── │
    │  • Main game loop runs                                                    │
    │  • Score/progress tracked                                                 │
    │  • Game-specific logic executes                                          │
    │                                                                           │
    │  Sub-states (game-specific):                                             │
    │    • Hash Crash: RISING → CRASHED                                        │
    │    • Code Duel: COUNTDOWN → TYPING → FINISHED                           │
    │    • Ice Breaker: LAYER_1 → LAYER_2 → ... → LAYER_12                    │
    │                                                                           │
    │  Exit conditions:                                                         │
    │    • Game completes naturally                                            │
    │    • Player action (cash out, forfeit)                                   │
    │    • Timeout                                                              │
    │    • Error                                                                │
    └──────────────────────────────────────────────────────────────────────────┘
                                   │
              gameEnd() / error  │
                                   ▼
    ┌──────────────────────────────────────────────────────────────────────────┐
    │                         RESOLVING PHASE                                   │
    │  ─────────────────────────────────────────────────────────────────────── │
    │  • Final calculations                                                     │
    │  • Contract interactions (if applicable)                                 │
    │  • Payout distribution                                                    │
    │  • Burn execution                                                         │
    │                                                                           │
    │  Duration: 1-3 seconds (or until tx confirmed)                           │
    └──────────────────────────────────────────────────────────────────────────┘
                                   │
                       resolved() │
                                   ▼
    ┌──────────────────────────────────────────────────────────────────────────┐
    │                          COMPLETE PHASE                                   │
    │  ─────────────────────────────────────────────────────────────────────── │
    │  • Show results screen                                                    │
    │  • Display rewards/losses                                                 │
    │  • Emit feed events                                                       │
    │  • Offer rematch / new game                                              │
    │                                                                           │
    │  User actions:                                                            │
    │    playAgain() → BETTING                                                 │
    │    exit() → IDLE                                                          │
    └──────────────────────────────────────────────────────────────────────────┘
                                   │
          playAgain() / exit()  │
                                   ▼
                           ┌───────────────┐
                           │  IDLE / BETTING│
                           └───────────────┘


================================================================================
ERROR HANDLING
================================================================================

    Any Phase ────── error ──────▶ ERROR_STATE
                                       │
                                       │ acknowledge()
                                       ▼
                                    IDLE


================================================================================
ABORT / DISCONNECT HANDLING
================================================================================

    BETTING ──── abort() ──────▶ IDLE (refund bet if applicable)

    PLAYING ──── disconnect ───▶ RESOLVING (auto-resolve per game rules)

    PLAYING ──── abort() ──────▶ RESOLVING (forfeit, apply penalties)
```

### Phase Transition Guards

Each transition can have guards to prevent invalid state changes:

```typescript
// Example guards for Hash Crash
const hashCrashTransitions = {
  idle: ['betting'],
  betting: ['rising', 'idle'],  // Can cancel back to idle
  rising: ['crashed'],          // Only crash is valid
  crashed: ['settling'],
  settling: ['betting', 'idle'],
};

const hashCrashGuards = {
  betting: {
    canEnter: () => {
      const balance = getTokenBalance();
      return balance >= MIN_BET;
    },
  },
  rising: {
    canEnter: () => {
      // Must have at least 1 bet placed
      return getCurrentBets().length > 0;
    },
  },
};
```

---

## 5. Integration Patterns

### 5.1 Basic Game Composition

Games compose the engine utilities rather than inheriting:

```typescript
// apps/web/src/lib/features/arcade/games/hash-crash/store.svelte.ts

import { createGameEngine, type GameEngine } from '../../engine/GameEngine.svelte';
import { createCountdown, createFrameLoop } from '../../engine/TimerSystem.svelte';
import { createScoreSystem } from '../../engine/ScoreSystem.svelte';
import { createRewardSystem } from '../../engine/RewardSystem.svelte';

type CrashPhase = 'idle' | 'betting' | 'rising' | 'crashed' | 'settling';

interface CrashState {
  roundId: number;
  multiplier: number;
  crashPoint: number | null;
  bets: CrashBet[];
  cashedOut: boolean;
}

export function createHashCrashStore() {
  // ─────────────────────────────────────────────────────────────
  // COMPOSE ENGINE UTILITIES
  // ─────────────────────────────────────────────────────────────

  const engine = createGameEngine<CrashPhase>({
    initialPhase: 'idle',
    phases: [
      {
        phase: 'betting',
        timeout: 10000,
        timeoutTarget: 'rising',
        onEnter: () => bettingCountdown.start(),
        onExit: () => bettingCountdown.stop(),
      },
      {
        phase: 'rising',
        onEnter: () => {
          startMultiplierAnimation();
          requestCrashPoint();
        },
        onExit: () => stopMultiplierAnimation(),
      },
      {
        phase: 'crashed',
        onEnter: () => {
          playSound('crash');
          triggerScreenFlash();
        },
      },
      {
        phase: 'settling',
        timeout: 5000,
        timeoutTarget: 'betting',
        onEnter: () => distributePayouts(),
      },
    ],
    transitions: {
      idle: ['betting'],
      betting: ['rising', 'idle'],
      rising: ['crashed'],
      crashed: ['settling'],
      settling: ['betting', 'idle'],
    },
  });

  const bettingCountdown = createCountdown({
    duration: 10000,
    criticalThreshold: 3000,
    onComplete: () => engine.transition('rising'),
    onTick: (remaining) => {
      if (remaining <= 3000) playSound('tick');
    },
  });

  const multiplierLoop = createFrameLoop((delta) => {
    if (engine.phase !== 'rising') return;

    // Exponential growth: multiplier = e^(0.06 * seconds)
    const elapsed = engine.phaseElapsed / 1000;
    const newMultiplier = Math.exp(0.06 * elapsed);

    gameState.multiplier = Math.round(newMultiplier * 100) / 100;

    // Check if crashed
    if (gameState.crashPoint && gameState.multiplier >= gameState.crashPoint) {
      engine.transition('crashed');
    }
  });

  const rewards = createRewardSystem({
    houseEdge: 0.03,
    burnRate: 1.0,
    minBet: 10n * 10n ** 18n,
    maxBet: 1000n * 10n ** 18n,
  });

  // ─────────────────────────────────────────────────────────────
  // GAME-SPECIFIC STATE
  // ─────────────────────────────────────────────────────────────

  let gameState = $state<CrashState>({
    roundId: 0,
    multiplier: 1.0,
    crashPoint: null,
    bets: [],
    cashedOut: false,
  });

  // ─────────────────────────────────────────────────────────────
  // GAME-SPECIFIC LOGIC
  // ─────────────────────────────────────────────────────────────

  function startMultiplierAnimation() {
    gameState.multiplier = 1.0;
    multiplierLoop.start();
  }

  function stopMultiplierAnimation() {
    multiplierLoop.stop();
  }

  async function requestCrashPoint() {
    // Request from VRF service or mock
    const crashPoint = await vrfService.getCrashPoint(gameState.roundId);
    gameState.crashPoint = crashPoint;
  }

  function placeBet(amount: bigint) {
    if (engine.phase !== 'betting') return;
    if (!rewards.setBet(amount)) return;

    // Add to bets list...
  }

  function cashOut() {
    if (engine.phase !== 'rising' || gameState.cashedOut) return;

    const payout = rewards.calculatePayout(gameState.multiplier);
    gameState.cashedOut = true;

    // Record the win
    rewards.recordWin(payout.profit);

    // Emit cash out event...
  }

  // ─────────────────────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────────────────────

  function cleanup() {
    engine.cleanup();
    bettingCountdown.cleanup();
    multiplierLoop.stop();
  }

  // ─────────────────────────────────────────────────────────────
  // RETURN INTERFACE
  // ─────────────────────────────────────────────────────────────

  return {
    // Engine state
    get phase() { return engine.phase; },
    get phaseElapsed() { return engine.phaseElapsed; },

    // Timer state
    get bettingTimeLeft() { return bettingCountdown.state.remaining; },
    get bettingProgress() { return bettingCountdown.state.progress; },

    // Game state
    get roundId() { return gameState.roundId; },
    get multiplier() { return gameState.multiplier; },
    get crashPoint() { return gameState.crashPoint; },
    get cashedOut() { return gameState.cashedOut; },

    // Reward state
    get currentBet() { return rewards.state.currentBet; },
    get sessionPnL() { return rewards.state.sessionPnL; },

    // Actions
    startGame: () => engine.transition('betting'),
    placeBet,
    cashOut,
    cleanup,
  };
}
```

### 5.2 Component Integration

```svelte
<!-- apps/web/src/lib/features/arcade/games/hash-crash/HashCrash.svelte -->
<script lang="ts">
  import { createHashCrashStore } from './store.svelte';
  import { formatTokenAmount } from '../../engine/RewardSystem.svelte';

  const store = createHashCrashStore();

  // Cleanup on component destroy
  $effect(() => {
    return () => store.cleanup();
  });

  // Reactive multiplier color
  const multiplierColor = $derived(
    store.multiplier < 2 ? 'var(--green-mid)' :
    store.multiplier < 5 ? 'var(--green-bright)' :
    store.multiplier < 10 ? 'var(--cyan)' :
    'var(--gold)'
  );
</script>

<div class="hash-crash">
  {#if store.phase === 'betting'}
    <div class="betting-phase">
      <div class="countdown">{Math.ceil(store.bettingTimeLeft / 1000)}</div>
      <BetInput onSubmit={(amount) => store.placeBet(amount)} />
    </div>

  {:else if store.phase === 'rising'}
    <div class="rising-phase">
      <div class="multiplier" style:color={multiplierColor}>
        {store.multiplier.toFixed(2)}x
      </div>
      {#if !store.cashedOut}
        <button onclick={() => store.cashOut()}>
          CASH OUT @ {store.multiplier.toFixed(2)}x
        </button>
      {/if}
    </div>

  {:else if store.phase === 'crashed'}
    <div class="crashed-phase">
      <div class="crash-display">
        CRASHED @ {store.crashPoint?.toFixed(2)}x
      </div>
    </div>
  {/if}
</div>
```

---

## 6. Real-time Updates

### 6.1 WebSocket Message Protocol

Games receive real-time updates via WebSocket:

```typescript
// apps/web/src/lib/features/arcade/types/websocket.ts

/** Base message structure */
interface ArcadeMessage {
  type: string;
  gameId: string;
  timestamp: number;
}

/** Game state sync */
interface GameStateMessage extends ArcadeMessage {
  type: 'GAME_STATE';
  phase: string;
  data: Record<string, unknown>;
}

/** Player action broadcast */
interface PlayerActionMessage extends ArcadeMessage {
  type: 'PLAYER_ACTION';
  action: 'BET' | 'CASH_OUT' | 'JOIN' | 'LEAVE';
  address: `0x${string}`;
  data: Record<string, unknown>;
}

/** Round result */
interface RoundResultMessage extends ArcadeMessage {
  type: 'ROUND_RESULT';
  roundId: number;
  result: Record<string, unknown>;
  winners: Array<{ address: `0x${string}`; payout: string }>;
  burned: string;
}

/** Error message */
interface ErrorMessage extends ArcadeMessage {
  type: 'ERROR';
  code: string;
  message: string;
}

type WebSocketMessage =
  | GameStateMessage
  | PlayerActionMessage
  | RoundResultMessage
  | ErrorMessage;
```

### 6.2 WebSocket Manager Integration

```typescript
// apps/web/src/lib/features/arcade/engine/websocket.svelte.ts

import type { WebSocketMessage } from '../types/websocket';

interface WebSocketManagerConfig {
  url: string;
  gameId: string;
  onMessage: (message: WebSocketMessage) => void;
  onConnect?: () => void;
  onDisconnect?: () => void;
  onError?: (error: Error) => void;
  reconnectDelay?: number;
  maxReconnectAttempts?: number;
}

export function createWebSocketManager(config: WebSocketManagerConfig) {
  let socket: WebSocket | null = null;
  let reconnectAttempts = 0;
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null;

  let connected = $state(false);
  let error = $state<Error | null>(null);

  function connect(): void {
    if (socket?.readyState === WebSocket.OPEN) return;

    try {
      socket = new WebSocket(config.url);

      socket.onopen = () => {
        connected = true;
        error = null;
        reconnectAttempts = 0;

        // Subscribe to game channel
        socket?.send(JSON.stringify({
          type: 'SUBSCRIBE',
          gameId: config.gameId,
        }));

        config.onConnect?.();
      };

      socket.onmessage = (event) => {
        try {
          const message = JSON.parse(event.data) as WebSocketMessage;
          config.onMessage(message);
        } catch (e) {
          console.error('[WS] Failed to parse message:', e);
        }
      };

      socket.onclose = () => {
        connected = false;
        config.onDisconnect?.();
        scheduleReconnect();
      };

      socket.onerror = (e) => {
        error = new Error('WebSocket error');
        config.onError?.(error);
      };
    } catch (e) {
      error = e instanceof Error ? e : new Error(String(e));
      config.onError?.(error);
      scheduleReconnect();
    }
  }

  function scheduleReconnect(): void {
    const maxAttempts = config.maxReconnectAttempts ?? 5;
    const delay = config.reconnectDelay ?? 2000;

    if (reconnectAttempts >= maxAttempts) {
      error = new Error('Max reconnect attempts reached');
      return;
    }

    reconnectAttempts++;
    reconnectTimer = setTimeout(() => {
      connect();
    }, delay * reconnectAttempts); // Exponential backoff
  }

  function disconnect(): void {
    if (reconnectTimer) {
      clearTimeout(reconnectTimer);
      reconnectTimer = null;
    }

    if (socket) {
      socket.close();
      socket = null;
    }

    connected = false;
  }

  function send(message: object): void {
    if (socket?.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify(message));
    }
  }

  return {
    get connected() { return connected; },
    get error() { return error; },
    connect,
    disconnect,
    send,
  };
}
```

---

## 7. Error Handling

### 7.1 Error Types

```typescript
// apps/web/src/lib/features/arcade/types/errors.ts

/** Base arcade error */
export class ArcadeError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly recoverable: boolean = true
  ) {
    super(message);
    this.name = 'ArcadeError';
  }
}

/** Transaction errors */
export class TransactionError extends ArcadeError {
  constructor(
    message: string,
    public readonly txHash?: string,
    public readonly reason?: string
  ) {
    super(message, 'TX_ERROR', true);
    this.name = 'TransactionError';
  }
}

/** Connection errors */
export class ConnectionError extends ArcadeError {
  constructor(message: string) {
    super(message, 'CONNECTION_ERROR', true);
    this.name = 'ConnectionError';
  }
}

/** Game state errors */
export class GameStateError extends ArcadeError {
  constructor(message: string, public readonly phase: string) {
    super(message, 'STATE_ERROR', false);
    this.name = 'GameStateError';
  }
}

/** Timeout errors */
export class TimeoutError extends ArcadeError {
  constructor(message: string, public readonly operation: string) {
    super(message, 'TIMEOUT_ERROR', true);
    this.name = 'TimeoutError';
  }
}
```

### 7.2 Error Recovery Strategies

```typescript
// apps/web/src/lib/features/arcade/engine/error-recovery.ts

import type { GameEngine } from './GameEngine.svelte';
import { ArcadeError, TransactionError, ConnectionError, TimeoutError } from '../types/errors';

interface RecoveryStrategy {
  canHandle: (error: ArcadeError) => boolean;
  handle: (error: ArcadeError, context: RecoveryContext) => Promise<void>;
}

interface RecoveryContext {
  engine: GameEngine<string>;
  retryCount: number;
  maxRetries: number;
}

/**
 * Transaction failure recovery
 * - Retry with higher gas
 * - Prompt user to retry manually
 * - Revert game state if needed
 */
const transactionRecovery: RecoveryStrategy = {
  canHandle: (error) => error instanceof TransactionError,
  handle: async (error, context) => {
    const txError = error as TransactionError;

    if (context.retryCount < context.maxRetries) {
      // Auto-retry with backoff
      await delay(1000 * context.retryCount);
      // Retry transaction...
    } else {
      // Manual intervention needed
      showToast({
        type: 'error',
        message: 'Transaction failed. Please try again.',
        action: { label: 'Retry', onClick: () => retryTransaction() },
      });

      // Revert to safe state
      await context.engine.transition('idle');
    }
  },
};

/**
 * Connection loss recovery
 * - Attempt reconnection
 * - Sync game state on reconnect
 * - Show offline indicator
 */
const connectionRecovery: RecoveryStrategy = {
  canHandle: (error) => error instanceof ConnectionError,
  handle: async (error, context) => {
    // Pause game if in playing phase
    if (['playing', 'rising'].includes(context.engine.phase)) {
      await context.engine.transition('resolving');
    }

    showToast({
      type: 'warning',
      message: 'Connection lost. Reconnecting...',
      duration: 0, // Persistent until reconnected
    });

    // WebSocket manager handles reconnection
    // On reconnect, sync game state from server
  },
};

/**
 * Timeout recovery
 * - Auto-resolve based on game rules
 * - Apply default outcomes
 */
const timeoutRecovery: RecoveryStrategy = {
  canHandle: (error) => error instanceof TimeoutError,
  handle: async (error, context) => {
    const timeoutError = error as TimeoutError;

    // Each game defines default timeout behavior
    // e.g., Hash Crash: auto-forfeit remaining bets
    // e.g., Code Duel: declare winner based on progress

    await context.engine.transition('resolving');
  },
};

export const recoveryStrategies = [
  transactionRecovery,
  connectionRecovery,
  timeoutRecovery,
];

export async function handleError(
  error: ArcadeError,
  context: RecoveryContext
): Promise<void> {
  const strategy = recoveryStrategies.find((s) => s.canHandle(error));

  if (strategy) {
    await strategy.handle(error, context);
  } else {
    // Unrecoverable error - return to idle
    console.error('[Arcade] Unrecoverable error:', error);
    await context.engine.transition('idle');

    showToast({
      type: 'error',
      message: 'An unexpected error occurred.',
    });
  }
}
```

---

## 8. Type Definitions

### 8.1 Shared Arcade Types

```typescript
// apps/web/src/lib/features/arcade/types/arcade.ts

/**
 * GHOSTNET Arcade - Shared Type Definitions
 * =========================================
 * Types used across all arcade games.
 */

// ════════════════════════════════════════════════════════════════
// GAME REGISTRY
// ════════════════════════════════════════════════════════════════

/** Available arcade games */
export type ArcadeGameId =
  | 'hash-crash'
  | 'code-duel'
  | 'daily-ops'
  | 'ice-breaker'
  | 'binary-bet'
  | 'bounty-hunt'
  | 'proxy-war'
  | 'zero-day'
  | 'shadow-protocol';

/** Game category */
export type GameCategory = 'casino' | 'competitive' | 'skill' | 'progression' | 'team' | 'meta';

/** Game metadata */
export interface GameMeta {
  id: ArcadeGameId;
  name: string;
  description: string;
  category: GameCategory;
  minBet: bigint;
  maxBet: bigint;
  burnRate: number;
  skillType: string;
  isMultiplayer: boolean;
  hasSpectating: boolean;
  phase: '3A' | '3B' | '3C';
}

/** Game registry - metadata for all games */
export const GAME_REGISTRY: Record<ArcadeGameId, GameMeta> = {
  'hash-crash': {
    id: 'hash-crash',
    name: 'HASH CRASH',
    description: 'Multiplier crash game - cash out before it crashes',
    category: 'casino',
    minBet: 10n * 10n ** 18n,
    maxBet: 1000n * 10n ** 18n,
    burnRate: 0.03,
    skillType: 'Timing',
    isMultiplayer: true,
    hasSpectating: true,
    phase: '3A',
  },
  'code-duel': {
    id: 'code-duel',
    name: 'CODE DUEL',
    description: '1v1 typing battles for $DATA',
    category: 'competitive',
    minBet: 50n * 10n ** 18n,
    maxBet: 500n * 10n ** 18n,
    burnRate: 0.10,
    skillType: 'Typing',
    isMultiplayer: true,
    hasSpectating: true,
    phase: '3A',
  },
  'daily-ops': {
    id: 'daily-ops',
    name: 'DAILY OPS',
    description: 'Daily challenges with streak rewards',
    category: 'progression',
    minBet: 0n,
    maxBet: 0n,
    burnRate: 0,
    skillType: 'Mixed',
    isMultiplayer: false,
    hasSpectating: false,
    phase: '3A',
  },
  'ice-breaker': {
    id: 'ice-breaker',
    name: 'ICE BREAKER',
    description: 'Reaction time game - break through ICE barriers',
    category: 'skill',
    minBet: 25n * 10n ** 18n,
    maxBet: 25n * 10n ** 18n,
    burnRate: 1.0,
    skillType: 'Reaction',
    isMultiplayer: false,
    hasSpectating: false,
    phase: '3B',
  },
  'binary-bet': {
    id: 'binary-bet',
    name: 'BINARY BET',
    description: 'Provably fair coin flip',
    category: 'casino',
    minBet: 10n * 10n ** 18n,
    maxBet: 500n * 10n ** 18n,
    burnRate: 0.05,
    skillType: 'Prediction',
    isMultiplayer: true,
    hasSpectating: true,
    phase: '3B',
  },
  'bounty-hunt': {
    id: 'bounty-hunt',
    name: 'BOUNTY HUNT',
    description: 'Strategic target acquisition game',
    category: 'skill',
    minBet: 50n * 10n ** 18n,
    maxBet: 500n * 10n ** 18n,
    burnRate: 1.0,
    skillType: 'Decision',
    isMultiplayer: false,
    hasSpectating: false,
    phase: '3B',
  },
  'proxy-war': {
    id: 'proxy-war',
    name: 'PROXY WAR',
    description: 'Crew vs crew territory battles',
    category: 'team',
    minBet: 500n * 10n ** 18n,
    maxBet: 500n * 10n ** 18n,
    burnRate: 1.0,
    skillType: 'Mixed',
    isMultiplayer: true,
    hasSpectating: true,
    phase: '3C',
  },
  'zero-day': {
    id: 'zero-day',
    name: 'ZERO DAY',
    description: 'Multi-skill exploit chain puzzles',
    category: 'skill',
    minBet: 100n * 10n ** 18n,
    maxBet: 100n * 10n ** 18n,
    burnRate: 1.0,
    skillType: 'Multi',
    isMultiplayer: false,
    hasSpectating: false,
    phase: '3C',
  },
  'shadow-protocol': {
    id: 'shadow-protocol',
    name: 'SHADOW PROTOCOL',
    description: 'Stealth mode mechanic',
    category: 'meta',
    minBet: 200n * 10n ** 18n,
    maxBet: 200n * 10n ** 18n,
    burnRate: 1.0,
    skillType: 'Strategic',
    isMultiplayer: false,
    hasSpectating: false,
    phase: '3C',
  },
};

// ════════════════════════════════════════════════════════════════
// COMMON TYPES
// ════════════════════════════════════════════════════════════════

/** Player bet in any game */
export interface GameBet {
  /** Unique bet ID */
  id: string;
  /** Player address */
  address: `0x${string}`;
  /** Bet amount in wei */
  amount: bigint;
  /** Timestamp placed */
  timestamp: number;
  /** Game-specific data */
  data?: Record<string, unknown>;
}

/** Payout record */
export interface GamePayout {
  /** Bet ID this payout is for */
  betId: string;
  /** Player address */
  address: `0x${string}`;
  /** Payout amount in wei */
  amount: bigint;
  /** Original bet amount */
  originalBet: bigint;
  /** Multiplier achieved */
  multiplier: number;
  /** Profit (can be negative) */
  profit: bigint;
  /** Timestamp of payout */
  timestamp: number;
}

/** Round summary for any game */
export interface GameRound {
  /** Round ID */
  id: string;
  /** Game ID */
  gameId: ArcadeGameId;
  /** Round number */
  roundNumber: number;
  /** Start timestamp */
  startTime: number;
  /** End timestamp */
  endTime: number;
  /** Total bets placed */
  totalBets: bigint;
  /** Total payouts distributed */
  totalPayouts: bigint;
  /** Amount burned */
  amountBurned: bigint;
  /** Number of players */
  playerCount: number;
  /** Winners count */
  winnersCount: number;
  /** Game-specific result data */
  result: Record<string, unknown>;
}

// ════════════════════════════════════════════════════════════════
// PLAYER TYPES
// ════════════════════════════════════════════════════════════════

/** Player stats for a specific game */
export interface GamePlayerStats {
  /** Game ID */
  gameId: ArcadeGameId;
  /** Player address */
  address: `0x${string}`;
  /** Total games played */
  gamesPlayed: number;
  /** Games won */
  gamesWon: number;
  /** Win rate (0-1) */
  winRate: number;
  /** Total wagered */
  totalWagered: bigint;
  /** Total won */
  totalWon: bigint;
  /** Total lost */
  totalLost: bigint;
  /** Net P&L */
  netPnL: bigint;
  /** Best multiplier achieved */
  bestMultiplier: number;
  /** Best streak */
  bestStreak: number;
  /** ELO rating (for competitive games) */
  rating?: number;
}

/** Spectator in a game */
export interface GameSpectator {
  /** Spectator address */
  address: `0x${string}`;
  /** When they started watching */
  joinedAt: number;
  /** Side bet placed (if any) */
  sideBet?: {
    side: string;
    amount: bigint;
  };
}

// ════════════════════════════════════════════════════════════════
// FEED EVENT TYPES
// ════════════════════════════════════════════════════════════════

/** Arcade-specific feed events */
export type ArcadeFeedEventType =
  | 'GAME_BET'
  | 'GAME_WIN'
  | 'GAME_LOSS'
  | 'BIG_WIN'
  | 'STREAK'
  | 'MATCH_START'
  | 'MATCH_END'
  | 'SPECTATOR_BET'
  | 'CREW_BATTLE';

/** Arcade feed event data */
export interface ArcadeFeedEvent {
  id: string;
  type: ArcadeFeedEventType;
  gameId: ArcadeGameId;
  timestamp: number;
  data: ArcadeFeedEventData;
}

export type ArcadeFeedEventData =
  | { type: 'GAME_BET'; address: `0x${string}`; amount: bigint; gameId: ArcadeGameId }
  | { type: 'GAME_WIN'; address: `0x${string}`; amount: bigint; multiplier: number; gameId: ArcadeGameId }
  | { type: 'GAME_LOSS'; address: `0x${string}`; amount: bigint; gameId: ArcadeGameId }
  | { type: 'BIG_WIN'; address: `0x${string}`; amount: bigint; multiplier: number; gameId: ArcadeGameId }
  | { type: 'STREAK'; address: `0x${string}`; streak: number; gameId: ArcadeGameId }
  | { type: 'MATCH_START'; player1: `0x${string}`; player2: `0x${string}`; wager: bigint; gameId: ArcadeGameId }
  | { type: 'MATCH_END'; winner: `0x${string}`; loser: `0x${string}`; prize: bigint; gameId: ArcadeGameId }
  | { type: 'SPECTATOR_BET'; address: `0x${string}`; side: string; amount: bigint; gameId: ArcadeGameId }
  | { type: 'CREW_BATTLE'; crew1: string; crew2: string; stakes: bigint; gameId: ArcadeGameId };

// ════════════════════════════════════════════════════════════════
// MOBILE RESPONSIVENESS
// ════════════════════════════════════════════════════════════════

/** Breakpoints for responsive design */
export const BREAKPOINTS = {
  mobile: 480,
  tablet: 768,
  desktop: 1024,
  wide: 1280,
} as const;

/** Touch support detection */
export function isTouchDevice(): boolean {
  if (typeof window === 'undefined') return false;
  return 'ontouchstart' in window || navigator.maxTouchPoints > 0;
}

/** Viewport size detection */
export function getViewportSize(): 'mobile' | 'tablet' | 'desktop' | 'wide' {
  if (typeof window === 'undefined') return 'desktop';

  const width = window.innerWidth;
  if (width < BREAKPOINTS.mobile) return 'mobile';
  if (width < BREAKPOINTS.tablet) return 'tablet';
  if (width < BREAKPOINTS.desktop) return 'desktop';
  return 'wide';
}
```

### 8.2 Index Export

```typescript
// apps/web/src/lib/features/arcade/engine/index.ts

/**
 * GHOSTNET Arcade Engine
 * ======================
 * Shared infrastructure for all arcade games.
 */

// Core engine
export {
  createGameEngine,
  type GameEngine,
  type GameEngineConfig,
  type GameEngineState,
  type PhaseConfig,
  type PhaseTransition,
  type StandardPhase,
} from './GameEngine.svelte';

// Timer utilities
export {
  createCountdown,
  createClock,
  createFrameLoop,
  formatTime,
  formatElapsed,
  type Countdown,
  type CountdownConfig,
  type CountdownState,
  type Clock,
  type ClockConfig,
  type ClockState,
  type FrameLoop,
  type TimerStatus,
} from './TimerSystem.svelte';

// Score system
export {
  createScoreSystem,
  type ScoreSystem,
  type ScoreConfig,
  type ScoreState,
  type ScoreEvent,
} from './ScoreSystem.svelte';

// Reward system
export {
  createRewardSystem,
  formatTokenAmount,
  parseTokenAmount,
  type RewardSystem,
  type RewardConfig,
  type RewardState,
  type RewardTier,
  type PayoutCalculation,
  type PoolPayoutCalculation,
} from './RewardSystem.svelte';

// WebSocket manager
export {
  createWebSocketManager,
} from './websocket.svelte';

// Error handling
export {
  ArcadeError,
  TransactionError,
  ConnectionError,
  GameStateError,
  TimeoutError,
  handleError,
} from './error-recovery';
```

---

## 9. File Structure Summary

```
apps/web/src/lib/features/arcade/
├── engine/
│   ├── index.ts                    # Barrel exports
│   ├── GameEngine.svelte.ts        # Core state machine
│   ├── TimerSystem.svelte.ts       # Countdown, clock, frame loop
│   ├── ScoreSystem.svelte.ts       # Points, combos, streaks
│   ├── RewardSystem.svelte.ts      # Payouts, burn calculations
│   ├── websocket.svelte.ts         # Real-time connection manager
│   └── error-recovery.ts           # Error handling strategies
├── types/
│   ├── arcade.ts                   # Shared type definitions
│   ├── websocket.ts                # WebSocket message types
│   └── errors.ts                   # Error type definitions
├── games/
│   ├── hash-crash/
│   │   ├── store.svelte.ts         # Game-specific store
│   │   ├── HashCrash.svelte        # Main component
│   │   └── components/             # Game UI components
│   ├── code-duel/
│   │   └── ...
│   ├── daily-ops/
│   │   └── ...
│   └── ... (9 games total)
├── ui/
│   ├── GameShell.svelte            # Standard game container
│   ├── Countdown.svelte            # Pre-game countdown
│   ├── ResultsScreen.svelte        # Post-game summary
│   └── Leaderboard.svelte          # Rankings display
└── matchmaking/
    ├── MatchQueue.svelte.ts        # PvP matchmaking
    ├── SpectatorManager.ts         # Watch mode
    └── BettingPool.svelte.ts       # Spectator wagering
```

---

## 10. Next Steps

1. **Implement Core Engine** (Week 1)
   - [ ] GameEngine.svelte.ts
   - [ ] TimerSystem.svelte.ts
   - [ ] ScoreSystem.svelte.ts
   - [ ] RewardSystem.svelte.ts

2. **Build First Game** (Week 2)
   - [ ] Hash Crash using engine components
   - [ ] Validate patterns and iterate

3. **Add Real-time Layer** (Week 3)
   - [ ] WebSocket manager
   - [ ] Error recovery
   - [ ] Reconnection logic

4. **Shared UI Components** (Week 4)
   - [ ] GameShell
   - [ ] Countdown
   - [ ] ResultsScreen

5. **Remaining Games** (Weeks 5-18)
   - [ ] Apply patterns to all 9 games
   - [ ] Game-specific extensions

---

## References

- [Phase 3 README](../README.md) - Overall arcade expansion plan
- [Hash Crash GDD](../games/01-hash-crash.md) - First game implementation
- [Code Duel GDD](../games/02-code-duel.md) - PvP typing battles
- [Svelte 5 Docs](https://svelte.dev/docs) - Runes and reactivity
- [Master Design](../../master-design.md) - GHOSTNET core mechanics
