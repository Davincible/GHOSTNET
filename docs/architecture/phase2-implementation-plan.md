# GHOSTNET Phase 2 Implementation Plan

**Version:** 1.1  
**Status:** In Progress (~65% Complete)  
**Created:** 2026-01-20  
**Last Updated:** 2026-01-21  
**Prerequisite:** Phase 1 MVP Complete (Phases 0-6) ✅

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Implementation Status](#2-implementation-status) ← **NEW**
3. [Visual Design Evolution](#3-visual-design-evolution)
4. [Phase 2A: MVP Completion](#4-phase-2a-mvp-completion) ✅
5. [Phase 2B: Dead Pool (Prediction Market)](#5-phase-2b-dead-pool-prediction-market) ✅
6. [Phase 2C: Hack Runs (Mini-Game)](#6-phase-2c-hack-runs-mini-game) ✅
7. [Phase 2D: Crew System](#7-phase-2d-crew-system) ✅
8. [Phase 2E: Leaderboard & Rankings](#8-phase-2e-leaderboard--rankings) ✅
9. [Phase 2F: Daily Operations](#9-phase-2f-daily-operations) ❌
10. [Phase 2G: Consumables & Black Market](#10-phase-2g-consumables--black-market) ❌
11. [Phase 2H: Help & Onboarding](#11-phase-2h-help--onboarding) ✅
12. [Phase 2I: PvP Duels](#12-phase-2i-pvp-duels) ❌
13. [Technical Infrastructure](#13-technical-infrastructure)
14. [Implementation Schedule](#14-implementation-schedule)
15. [Appendix: Type Definitions](#15-appendix-type-definitions)
16. [Next Steps & Action Items](#16-next-steps--action-items) ← **NEW**

---

## 1. Executive Summary

### Current State (Post Phase 1)

The MVP implementation delivers:
- Command Center UI with live feed, position panel, network vitals
- Trace Evasion typing mini-game (3 rounds, reward tiers)
- Mock data provider architecture
- Audio system (19 sounds)
- Visual effects (scanlines, flicker, screen flash)
- Modals for Jack In, Extract, Settings

### Phase 2 Scope

Phase 2 completes the full product vision from `master-design.md`:

| Phase | Feature | Priority | Effort | Dependencies | Status |
|-------|---------|----------|--------|--------------|--------|
| 2A | MVP Completion | Critical | 1 week | None | ✅ Complete |
| 2B | Dead Pool | High | 2 weeks | 2A | ✅ Complete |
| 2C | Hack Runs | High | 3 weeks | 2A | ✅ Complete |
| 2D | Crew System | Medium | 2 weeks | 2A | ✅ Complete |
| 2E | Leaderboard | Medium | 1 week | 2A | ✅ Complete |
| 2F | Daily Ops | Low | 1 week | 2A | ❌ Not Started |
| 2G | Consumables | Low | 1 week | 2A, 2B | ❌ Not Started |
| 2H | Help System | Medium | 1 week | 2A | ✅ Complete |
| 2I | PvP Duels | Low | 2 weeks | 2A, 2C | ❌ Not Started |

**Total Estimated Duration:** 10-14 weeks (with parallelization)  
**Current Progress:** ~70% complete (6 of 9 phases done)

---

## 2. Implementation Status

> **Last verified:** 2026-01-21 (Updated: Navigation wiring complete, Help page implemented)

### Overview

```
PHASE 2 PROGRESS
═══════════════════════════════════════════════════════════════════════════

Phase 1 (MVP)         ████████████████████████████████████████  100%  ✅
Phase 2A (MVP Comp)   ████████████████████████████████████████  100%  ✅
Phase 2B (Dead Pool)  ████████████████████████████████████████  100%  ✅
Phase 2C (Hack Runs)  ████████████████████████████████████████  100%  ✅
Phase 2D (Crew)       ████████████████████████████████████████  100%  ✅
Phase 2E (Leaderboard)████████████████████████████████████████  100%  ✅
Phase 2F (Daily Ops)  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ❌
Phase 2G (Consumables)░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ❌
Phase 2H (Help)       ████████████████████████████████████████  100%  ✅
Phase 2I (PvP Duels)  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    0%  ❌

OVERALL PHASE 2:      ████████████████████████████░░░░░░░░░░░░   ~70%
```

### Completed Features

#### Phase 2A: MVP Completion ✅
- [x] Visual style migration to teal-cyan palette (`tokens.css`)
- [x] Responsive design (`responsive.css`, mobile nav)
- [x] Error handling system (`errors.ts` - 596 lines)
- [x] Toast notifications (`ToastContainer`, `TransactionToast`)
- [x] Transaction state management
- [x] Navigation "Coming Soon" states (implemented but need wiring)

#### Phase 2B: Dead Pool ✅
- [x] Type definitions (`DeadPoolRound`, `DeadPoolResult`, `DeadPoolHistory`, etc.)
- [x] Mock generator (`generators/deadpool.ts`)
- [x] Page route (`/market/+page.svelte` - 194 lines)
- [x] All UI components (Header, RoundCard, OddsDisplay, PoolBars, BetModal, ResultsPanel)
- [x] Live pool update simulation (5-second intervals)

#### Phase 2C: Hack Runs ✅
- [x] Type definitions (`hackrun.ts` - 287 lines)
- [x] Game state machine store
- [x] Run/node generators
- [x] Page route (`/games/hackrun/+page.svelte` - 473 lines)
- [x] All UI components (SelectionView, ActiveRunView, NodeMap, etc.)
- [x] Audio integration

#### Phase 2D: Crew System ✅
- [x] Type definitions (`Crew`, `CrewMember`, `CrewBonus`, `CrewActivity`, etc.)
- [x] Mock generator (`generators/crew.ts`)
- [x] Page route (`/crew/+page.svelte` - 261 lines)
- [x] All UI components (Header, BonusesPanel, MembersPanel, ActivityFeed, Modals)
- [x] Create/join/leave crew flows

#### Phase 2E: Leaderboard ✅
- [x] Type definitions (`leaderboard.ts` - 251 lines)
- [x] Mock generator (`generators/leaderboard.ts`)
- [x] Page route (`/leaderboard/+page.svelte` - 212 lines)
- [x] All UI components (CategoryTabs, TimeframeTabs, Table, CrewLeaderboard, YourRankCard)

### Outstanding Items

#### Phase 2F: Daily Operations ❌
- [ ] Type definitions (`daily.ts`) - NOT CREATED
- [ ] Mock generator - NOT CREATED
- [ ] UI components - NOT CREATED
- [ ] Integration with modifiers system - NOT DONE

#### Phase 2G: Consumables & Black Market ❌
- [ ] Type definitions (`market.ts`) - NOT CREATED
- [ ] Consumable definitions (Stimpack, EMP Jammer, etc.) - NOT CREATED
- [ ] Mock generator - NOT CREATED
- [ ] UI components - NOT CREATED
- [ ] Integration into `/market` page - NOT DONE

#### Phase 2H: Help & Onboarding ✅
- [x] Help page route (`/help/+page.svelte`) - Created with 7 sections
- [x] Help content - Written (Getting Started, Security Levels, Mini-Games, Crews, Tokenomics, Advanced, Keyboard)
- [ ] Contextual tooltips - NOT CREATED (future enhancement)
- [ ] First-time hints system - NOT CREATED (future enhancement)

#### Phase 2I: PvP Duels ❌
- [ ] Type definitions (`duel.ts`) - NOT CREATED
- [ ] Mock generator - NOT CREATED
- [ ] Page route (`/games/duels/+page.svelte`) - NOT CREATED
- [ ] All UI components - NOT CREATED

### Known Issues / Technical Debt

#### Navigation & Quick Actions - ✅ RESOLVED
~~The navigation bar and quick action handlers were showing "coming soon" for implemented features.~~

**Fixed 2026-01-21:** All navigation items now properly link to their routes. Quick action handlers use `goto()` instead of toast messages.

#### Provider Architecture Gap
The mock provider (`provider.svelte.ts`) has a basic interface. Phase 2 features use separate mock generators called directly from pages rather than through the provider interface. Consider:
- Integrating generators into the provider
- Or accepting the current pattern as intentional for mock mode

### File Inventory

#### Type Files
```
lib/core/types/
├── index.ts         # Core types + Crew + DeadPool (471 lines) ✅
├── hackrun.ts       # Hack Run types (287 lines) ✅
├── leaderboard.ts   # Leaderboard types (251 lines) ✅
├── errors.ts        # Error handling (596 lines) ✅
├── daily.ts         # ❌ MISSING
├── market.ts        # ❌ MISSING
└── duel.ts          # ❌ MISSING
```

#### Route Files
```
routes/
├── +page.svelte           # Command Center ✅
├── typing/+page.svelte    # Trace Evasion ✅
├── market/+page.svelte    # Dead Pool ✅
├── crew/+page.svelte      # Crew System ✅
├── leaderboard/+page.svelte # Rankings ✅
├── games/
│   ├── hackrun/+page.svelte # Hack Runs ✅
│   └── duels/+page.svelte   # ❌ MISSING
└── help/+page.svelte        # Help System ✅
```

#### Mock Generators
```
lib/core/providers/mock/generators/
├── feed.ts          ✅
├── network.ts       ✅
├── position.ts      ✅
├── deadpool.ts      ✅
├── crew.ts          ✅
├── leaderboard.ts   ✅
├── daily.ts         # ❌ MISSING
├── market.ts        # ❌ MISSING
└── duel.ts          # ❌ MISSING
```

---

## 3. Visual Design Evolution

### 3.1 Design Philosophy Shift

Phase 2 introduces a refined visual language: **Satellite Command Dashboard**. This evolves the current hacker terminal aesthetic into something more sophisticated—military operations center meets spacecraft engineering blueprint. The core terminal DNA remains, but with increased polish and professionalism.

---

## 3. Visual Design Evolution

> **Status:** ✅ Complete - Teal-cyan palette implemented in `tokens.css`

### 3.1 Design Philosophy Shift

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         VISUAL EVOLUTION                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  PHASE 1 (Current)              →      PHASE 2 (Target)                     │
│  ─────────────────                     ─────────────────                     │
│  Hacker Terminal                       Satellite Command                     │
│  Green phosphor glow                   Teal-cyan precision                   │
│  CRT effects (heavy)                   Subtle ambient glow                   │
│  Playful chaos                         Quiet confidence                      │
│  Matrix vibes                          Interstellar vibes                    │
│  "Underground hacker"                  "Mission control specialist"          │
│                                                                              │
│  WHAT STAYS:                                                                 │
│  • Monospace typography                                                      │
│  • Dark backgrounds                                                          │
│  • Information density                                                       │
│  • Terminal-style data display                                               │
│  • Sharp corners (no rounded)                                                │
│  • ASCII elements                                                            │
│                                                                              │
│  WHAT CHANGES:                                                               │
│  • Color: Green → Teal-Cyan                                                  │
│  • Glow: Heavy scanlines → Subtle luminescence                               │
│  • Tone: Chaotic → Controlled                                                │
│  • Feel: "Hacking" → "Operating"                                             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Updated Color Palette

```css
/* tokens.css - Phase 2 Updates */
:root {
  /* ════════════════════════════════════════════════════════════════ */
  /* BACKGROUNDS - Deeper, void-like blacks                           */
  /* ════════════════════════════════════════════════════════════════ */
  --color-bg-primary: #050507;      /* Near void - main background */
  --color-bg-secondary: #0a0a0c;    /* Panels, cards */
  --color-bg-tertiary: #0f0f12;     /* Elevated surfaces */
  --color-bg-elevated: #141418;     /* Modals, dropdowns */

  /* ════════════════════════════════════════════════════════════════ */
  /* ACCENT - Teal-Cyan (replaces green as primary)                   */
  /* ════════════════════════════════════════════════════════════════ */
  --color-accent: #00E5CC;          /* Primary accent - luminous teal */
  --color-accent-bright: #00FFE0;   /* Hover states, emphasis */
  --color-accent-dim: #00B8A3;      /* Secondary, less emphasis */
  --color-accent-muted: #007A6C;    /* Disabled, subtle */
  --color-accent-glow: rgba(0, 229, 204, 0.15);  /* Subtle glow */
  --color-accent-intense: rgba(0, 229, 204, 0.4); /* Active glow */

  /* ════════════════════════════════════════════════════════════════ */
  /* LEGACY GREEN (kept for specific contexts)                        */
  /* ════════════════════════════════════════════════════════════════ */
  --color-green: #00FF88;           /* Profit, success states */
  --color-green-dim: #00CC6A;       /* Secondary success */

  /* ════════════════════════════════════════════════════════════════ */
  /* TEXT - Strict hierarchy                                          */
  /* ════════════════════════════════════════════════════════════════ */
  --color-text-primary: #FFFFFF;    /* Key values, headings */
  --color-text-secondary: #B8B8C0;  /* Body text */
  --color-text-tertiary: #6B6B78;   /* Labels, captions */
  --color-text-muted: #404050;      /* Disabled, hints */

  /* ════════════════════════════════════════════════════════════════ */
  /* BORDERS - Minimal, dark                                          */
  /* ════════════════════════════════════════════════════════════════ */
  --color-border-subtle: #1a1a20;   /* Card borders */
  --color-border-default: #252530;  /* Dividers */
  --color-border-emphasis: #353545; /* Focus states */

  /* ════════════════════════════════════════════════════════════════ */
  /* STATUS COLORS                                                    */
  /* ════════════════════════════════════════════════════════════════ */
  --color-danger: #FF3B5C;          /* Deaths, errors, critical */
  --color-danger-dim: #CC2F4A;      /* Secondary danger */
  --color-danger-glow: rgba(255, 59, 92, 0.3);
  
  --color-warning: #FFAA00;         /* Caution, timers low */
  --color-warning-dim: #CC8800;
  --color-warning-glow: rgba(255, 170, 0, 0.2);
  
  --color-success: #00FF88;         /* Gains, completed */
  --color-success-glow: rgba(0, 255, 136, 0.2);
  
  --color-gold: #FFD700;            /* Jackpots, achievements */
  --color-gold-glow: rgba(255, 215, 0, 0.3);

  /* ════════════════════════════════════════════════════════════════ */
  /* LEVEL COLORS (Updated for teal harmony)                          */
  /* ════════════════════════════════════════════════════════════════ */
  --color-level-vault: #00E5CC;     /* Safe - primary teal */
  --color-level-mainframe: #00B8A3; /* Low risk - dim teal */
  --color-level-subnet: #FFAA00;    /* Medium - warning */
  --color-level-darknet: #FF6B35;   /* High - orange-red */
  --color-level-black-ice: #FF3B5C; /* Extreme - danger */
}
```

### 3.3 Typography Refinements

```css
/* Typography - Phase 2 */
:root {
  /* Font stack unchanged - monospace is core to identity */
  --font-mono: 'IBM Plex Mono', 'JetBrains Mono', 'Fira Code', monospace;
  
  /* Slightly tighter size scale for density */
  --text-2xs: 0.5625rem;  /* 9px - timestamps, micro labels */
  --text-xs: 0.625rem;    /* 10px - labels, captions */
  --text-sm: 0.6875rem;   /* 11px - secondary text */
  --text-base: 0.75rem;   /* 12px - body text */
  --text-lg: 0.875rem;    /* 14px - emphasis */
  --text-xl: 1rem;        /* 16px - section headers */
  --text-2xl: 1.25rem;    /* 20px - panel titles */
  --text-3xl: 1.75rem;    /* 28px - hero numbers */
  --text-4xl: 2.5rem;     /* 40px - large metrics */

  /* Letter spacing for uppercase labels */
  --tracking-tight: -0.01em;
  --tracking-normal: 0;
  --tracking-wide: 0.05em;
  --tracking-wider: 0.1em;   /* For uppercase labels */
  --tracking-widest: 0.15em; /* For emphasized labels */

  /* Font weights */
  --font-light: 300;      /* Large numbers */
  --font-normal: 400;     /* Body text */
  --font-medium: 500;     /* Emphasis */
  --font-semibold: 600;   /* Headers */
}
```

### 3.4 Visual Effects (Refined)

```css
/* Phase 2: Subtle, sophisticated effects */

/* Scanlines - much more subtle */
.scanlines::before {
  content: "";
  position: absolute;
  inset: 0;
  background: repeating-linear-gradient(
    0deg,
    transparent,
    transparent 2px,
    rgba(0, 229, 204, 0.01) 2px,
    rgba(0, 229, 204, 0.01) 4px
  );
  pointer-events: none;
  z-index: 100;
}

/* Glow effect - for active elements */
.glow {
  box-shadow: 
    0 0 4px var(--color-accent-glow),
    0 0 8px var(--color-accent-glow),
    inset 0 0 2px var(--color-accent-glow);
}

.glow-text {
  text-shadow: 
    0 0 4px var(--color-accent-glow),
    0 0 8px var(--color-accent-glow);
}

/* Status indicator pulse */
@keyframes status-pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.6; }
}

.status-active {
  animation: status-pulse 2s ease-in-out infinite;
}

/* Data update flash */
@keyframes data-update {
  0% { background-color: var(--color-accent-glow); }
  100% { background-color: transparent; }
}

.data-updated {
  animation: data-update 0.5s ease-out;
}

/* Screen flicker - much more subtle */
@keyframes subtle-flicker {
  0%, 100% { opacity: 1; }
  97% { opacity: 1; }
  97.5% { opacity: 0.95; }
  98% { opacity: 1; }
}

.subtle-flicker {
  animation: subtle-flicker 10s infinite;
}
```

### 3.5 Card & Container Patterns

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CARD ANATOMY                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ SECTION TITLE                                                     [↗] │ │
│  ├────────────────────────────────────────────────────────────────────────┤ │
│  │                                                                        │ │
│  │  LABEL                                                                 │ │
│  │  Primary Value                                                   ●     │ │
│  │                                                                        │ │
│  │  ████████████████████░░░░░░░░░░  67%                                  │ │
│  │                                                                        │ │
│  │  SECONDARY LABEL          ANOTHER LABEL                               │ │
│  │  Secondary Value          Another Value                               │ │
│  │                                                                        │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  CARD SPECIFICATIONS:                                                        │
│  • Background: var(--color-bg-secondary)                                     │
│  • Border: 1px solid var(--color-border-subtle)                             │
│  • Corners: 0px (sharp - NEVER rounded)                                      │
│  • Padding: 16px (--space-4)                                                 │
│  • Header: Uppercase, tracking-wider, text-tertiary                         │
│  • Values: text-primary, larger size                                         │
│  • Labels: Uppercase, text-xs, text-tertiary                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.6 Wireframe Illustrations

Phase 2 introduces **wireframe technical illustrations** for key visual elements:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         WIREFRAME STYLE GUIDE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  SATELLITE / NETWORK NODE VISUALIZATION:                                     │
│                                                                              │
│                    ╱╲                                                        │
│                   ╱  ╲     ╭─────╮                                          │
│      ╭──────────╱────╲────│ 72% │                                          │
│      │         ╱      ╲   ╰─────╯                                          │
│      │        ╱────────╲                                                    │
│      │       ╱╲        ╱╲                                                   │
│      │      ╱  ╲──────╱  ╲                                                  │
│      │     ╱    ╲    ╱    ╲     ╭─────╮                                    │
│      ╰────╱──────╲──╱──────╲────│ 90% │                                    │
│          ╱        ╲╱        ╲   ╰─────╯                                    │
│         ╱──────────╲─────────╲                                              │
│        ╱            ╲         ╲                                             │
│                                                                              │
│  STYLE RULES:                                                                │
│  • Stroke: 1px, var(--color-text-tertiary)                                  │
│  • Dashed lines for hidden edges                                             │
│  • Callout badges: var(--color-accent) background                           │
│  • Connection lines: horizontal jog before label                            │
│  • Minimal, schematic feel                                                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.7 Migration Strategy

```
VISUAL MIGRATION PLAN
═════════════════════════════════════════════════════════════════════════════

PHASE 2A (Week 1):
├── Update tokens.css with new color palette
├── Create tokens-legacy.css for backward compat
├── Update Shell.svelte with new background
└── Test: Existing components should still render

PHASE 2A (Week 2):
├── Update Scanlines.svelte with subtle effect
├── Update Flicker.svelte with subtle-flicker
├── Update ScreenFlash.svelte with new danger/success colors
└── Test: Visual effects should be more refined

ONGOING (Each Feature):
├── New components use Phase 2 styles by default
├── Existing components updated opportunistically
└── Full migration complete by end of Phase 2
```

---

## 4. Phase 2A: MVP Completion

> **Status:** ✅ COMPLETE

**Priority:** Critical  
**Duration:** 1 week  
**Dependencies:** None

### 4.1 Objectives

Complete the remaining ~5% of Phase 1:
1. Responsive design verification (mobile/tablet)
2. Error handling completion
3. Navigation "Coming Soon" states
4. Final polish checklist
5. Visual style migration foundation

### 4.2 Responsive Design

#### 3.2.1 Breakpoint System

```css
/* Breakpoints */
:root {
  --breakpoint-sm: 640px;   /* Mobile landscape */
  --breakpoint-md: 768px;   /* Tablet portrait */
  --breakpoint-lg: 1024px;  /* Tablet landscape / small desktop */
  --breakpoint-xl: 1280px;  /* Desktop */
  --breakpoint-2xl: 1536px; /* Large desktop */
}
```

#### 3.2.2 Mobile Layout (< 768px)

```
┌─────────────────────────────────────────┐
│ GHOSTNET v1.0.7              [≡] [👤]  │
├─────────────────────────────────────────┤
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ YOUR STATUS                         │ │
│ │ DARKNET • 500 $DATA                 │ │
│ │ Death: 32% ▼  Yield: +47 $DATA     │ │
│ │ Next Scan: 01:23:45                 │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ LIVE FEED                      [↗] │ │
│ │ > 0x7a3f jacked in [DARKNET]       │ │
│ │ > 0x9c2d ██ TRACED ██ 💀           │ │
│ │ > 0x3b1a extracted +312 gain       │ │
│ │ ▼ More                             │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ QUICK ACTIONS                       │ │
│ │ [JACK IN]  [EXTRACT]  [GAMES ▼]   │ │
│ └─────────────────────────────────────┘ │
│                                         │
├─────────────────────────────────────────┤
│ [NET] [POS] [GAME] [CREW] [MORE]       │
└─────────────────────────────────────────┘

MOBILE SPECIFICATIONS:
• Single column layout
• Position panel collapsed to summary bar
• Feed panel collapsible (shows 3 items)
• Network vitals hidden (accessible via MORE)
• Bottom navigation bar (fixed)
• Modals full-screen
• Touch targets: minimum 44px
```

#### 3.2.3 Tablet Layout (768px - 1024px)

```
┌───────────────────────────────────────────────────────────────┐
│ GHOSTNET v1.0.7 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ [👤] [⚙]    │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│ ┌─────────────────────────┐ ┌───────────────────────────────┐ │
│ │ LIVE FEED               │ │ YOUR STATUS                   │ │
│ │                         │ │                               │ │
│ │ > 0x7a3f jacked in...   │ │ LEVEL: DARKNET                │ │
│ │ > 0x9c2d TRACED...      │ │ STAKED: 500 $DATA             │ │
│ │ > 0x3b1a extracted...   │ │ DEATH: 32%  YIELD: +47       │ │
│ │ > SCAN WARNING...       │ │ SCAN: 01:23:45                │ │
│ │ > 0x8f2e survived...    │ │                               │ │
│ │                         │ ├───────────────────────────────┤ │
│ │                         │ │ MODIFIERS                     │ │
│ │                         │ │ ✓ Trace Evasion -15%         │ │
│ │                         │ │ ✓ Crew Bonus +10%            │ │
│ │                         │ └───────────────────────────────┘ │
│ │                         │                                   │
│ ├─────────────────────────┤ ┌───────────────────────────────┐ │
│ │ NETWORK VITALS          │ │ QUICK ACTIONS                 │ │
│ │ TVL: $4.8M  OPS: 1,247  │ │ [J] JACK IN  [E] EXTRACT     │ │
│ │ Reset: 04:32:17         │ │ [T] TYPING   [H] HACK RUN    │ │
│ └─────────────────────────┘ └───────────────────────────────┘ │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│ [NETWORK] [POSITION] [GAMES] [CREW] [MARKET] [RANKS] [?]     │
└───────────────────────────────────────────────────────────────┘

TABLET SPECIFICATIONS:
• Two-column layout (60/40 split)
• Feed and vitals in left column
• Position, modifiers, actions in right column
• All panels visible (may scroll)
• Navigation bar at bottom
• Modals: 80% width centered
```

#### 3.2.4 Implementation Tasks

```
RESPONSIVE IMPLEMENTATION CHECKLIST
═══════════════════════════════════════════════════════════════════════════

□ 3.2.4.1 Create responsive utility classes
  □ lib/ui/styles/responsive.css
  □ .hide-mobile, .hide-tablet, .hide-desktop
  □ .mobile-only, .tablet-only, .desktop-only
  □ Container queries for component-level responsiveness

□ 3.2.4.2 Update +page.svelte layout
  □ CSS Grid with responsive columns
  □ Reorder panels for mobile (position first)
  □ Add collapsible panel support

□ 3.2.4.3 Update NavigationBar.svelte
  □ Mobile: Icon-only mode with labels on active
  □ Tablet: Abbreviated labels
  □ Desktop: Full labels (current)

□ 3.2.4.4 Update FeedPanel.svelte
  □ Mobile: Collapsible with 3-item preview
  □ Swipe to expand gesture support

□ 3.2.4.5 Update PositionPanel.svelte
  □ Mobile: Compact horizontal summary bar
  □ Tap to expand full details

□ 3.2.4.6 Update all modals
  □ Mobile: Full-screen with close button
  □ Touch-friendly inputs (larger)

□ 3.2.4.7 Testing
  □ iPhone SE (375px)
  □ iPhone 14 Pro (393px)
  □ iPad Mini (744px)
  □ iPad Pro (1024px)
  □ Desktop (1280px+)
```

### 4.3 Error Handling

#### 3.3.1 Error Types

```typescript
// lib/core/types/errors.ts

/** Base error for all GHOSTNET errors */
export class GhostnetError extends Error {
  constructor(
    message: string,
    public code: ErrorCode,
    public recoverable: boolean = true
  ) {
    super(message);
    this.name = 'GhostnetError';
  }
}

/** Error codes */
export type ErrorCode =
  | 'WALLET_NOT_CONNECTED'
  | 'WALLET_REJECTED'
  | 'INSUFFICIENT_BALANCE'
  | 'INSUFFICIENT_ALLOWANCE'
  | 'TRANSACTION_FAILED'
  | 'TRANSACTION_REVERTED'
  | 'NETWORK_ERROR'
  | 'PROVIDER_ERROR'
  | 'POSITION_NOT_FOUND'
  | 'LEVEL_FULL'
  | 'MIN_STAKE_NOT_MET'
  | 'COOLDOWN_ACTIVE'
  | 'UNKNOWN_ERROR';

/** Error metadata */
export const ERROR_METADATA: Record<ErrorCode, {
  title: string;
  defaultMessage: string;
  severity: 'info' | 'warning' | 'error' | 'critical';
}> = {
  WALLET_NOT_CONNECTED: {
    title: 'Wallet Required',
    defaultMessage: 'Connect your wallet to continue',
    severity: 'info'
  },
  WALLET_REJECTED: {
    title: 'Transaction Rejected',
    defaultMessage: 'You rejected the transaction in your wallet',
    severity: 'warning'
  },
  INSUFFICIENT_BALANCE: {
    title: 'Insufficient Balance',
    defaultMessage: 'You do not have enough $DATA for this action',
    severity: 'error'
  },
  TRANSACTION_FAILED: {
    title: 'Transaction Failed',
    defaultMessage: 'The transaction could not be completed',
    severity: 'error'
  },
  NETWORK_ERROR: {
    title: 'Network Error',
    defaultMessage: 'Unable to connect to the network',
    severity: 'critical'
  },
  // ... etc
};
```

#### 3.3.2 Toast Notification System

```typescript
// lib/core/notifications/types.ts

export interface Toast {
  id: string;
  type: 'info' | 'success' | 'warning' | 'error';
  title: string;
  message?: string;
  duration?: number;  // ms, 0 = sticky
  action?: {
    label: string;
    onClick: () => void;
  };
}
```

```svelte
<!-- lib/ui/feedback/ToastContainer.svelte -->
<script lang="ts">
  import type { Toast } from '$lib/core/notifications/types';
  import ToastItem from './ToastItem.svelte';
  
  interface Props {
    toasts: Toast[];
    onDismiss: (id: string) => void;
  }
  
  let { toasts, onDismiss }: Props = $props();
</script>

<div class="toast-container" role="region" aria-label="Notifications">
  {#each toasts as toast (toast.id)}
    <ToastItem {toast} onDismiss={() => onDismiss(toast.id)} />
  {/each}
</div>

<style>
  .toast-container {
    position: fixed;
    bottom: var(--space-16);  /* Above nav bar */
    right: var(--space-4);
    z-index: 1000;
    display: flex;
    flex-direction: column-reverse;
    gap: var(--space-2);
    max-width: 400px;
  }
  
  @media (max-width: 640px) {
    .toast-container {
      left: var(--space-4);
      right: var(--space-4);
      max-width: none;
    }
  }
</style>
```

```svelte
<!-- lib/ui/feedback/ToastItem.svelte -->
<script lang="ts">
  import type { Toast } from '$lib/core/notifications/types';
  import { onMount } from 'svelte';
  
  interface Props {
    toast: Toast;
    onDismiss: () => void;
  }
  
  let { toast, onDismiss }: Props = $props();
  
  onMount(() => {
    if (toast.duration && toast.duration > 0) {
      const timer = setTimeout(onDismiss, toast.duration);
      return () => clearTimeout(timer);
    }
  });
  
  const icons: Record<Toast['type'], string> = {
    info: 'ℹ',
    success: '✓',
    warning: '⚠',
    error: '✗'
  };
</script>

<div class="toast toast-{toast.type}" role="alert">
  <span class="toast-icon">{icons[toast.type]}</span>
  <div class="toast-content">
    <strong class="toast-title">{toast.title}</strong>
    {#if toast.message}
      <p class="toast-message">{toast.message}</p>
    {/if}
  </div>
  {#if toast.action}
    <button class="toast-action" onclick={toast.action.onClick}>
      {toast.action.label}
    </button>
  {/if}
  <button class="toast-dismiss" onclick={onDismiss} aria-label="Dismiss">
    ×
  </button>
</div>
```

#### 3.3.3 Transaction State Management

```typescript
// lib/core/transactions/types.ts

export type TransactionStatus = 
  | 'idle'
  | 'preparing'
  | 'awaiting_signature'
  | 'pending'
  | 'confirmed'
  | 'failed';

export interface TransactionState {
  status: TransactionStatus;
  hash?: `0x${string}`;
  error?: GhostnetError;
}
```

```svelte
<!-- lib/ui/feedback/TransactionToast.svelte -->
<!-- Specialized toast for transaction progress -->
<script lang="ts">
  import type { TransactionState } from '$lib/core/transactions/types';
  import { Spinner } from '$lib/ui/primitives';
  
  interface Props {
    state: TransactionState;
    action: string;  // "Jack In", "Extract", etc.
  }
  
  let { state, action }: Props = $props();
  
  const messages: Record<TransactionStatus, string> = {
    idle: '',
    preparing: 'Preparing transaction...',
    awaiting_signature: 'Confirm in your wallet',
    pending: 'Transaction pending...',
    confirmed: 'Transaction confirmed!',
    failed: 'Transaction failed'
  };
</script>

<div class="tx-toast tx-{state.status}">
  {#if state.status === 'pending' || state.status === 'preparing'}
    <Spinner size="sm" />
  {:else if state.status === 'confirmed'}
    <span class="tx-icon">✓</span>
  {:else if state.status === 'failed'}
    <span class="tx-icon">✗</span>
  {/if}
  
  <div class="tx-content">
    <strong>{action}</strong>
    <span class="tx-message">{messages[state.status]}</span>
    {#if state.hash}
      <a href="https://megaexplorer.xyz/tx/{state.hash}" target="_blank" rel="noopener">
        View on Explorer ↗
      </a>
    {/if}
  </div>
</div>
```

### 4.4 Navigation "Coming Soon" States

```svelte
<!-- lib/features/nav/NavigationBar.svelte - Updated -->
<script lang="ts">
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  
  interface NavItem {
    id: string;
    label: string;
    href?: string;
    comingSoon?: boolean;
    disabled?: boolean;
  }
  
  const navItems: NavItem[] = [
    { id: 'network', label: 'NETWORK', href: '/' },
    { id: 'position', label: 'POSITION', href: '/' },  // Same page, scrolls
    { id: 'games', label: 'GAMES', href: '/typing' },
    { id: 'crew', label: 'CREW', comingSoon: true },
    { id: 'market', label: 'MARKET', comingSoon: true },
    { id: 'leaderboard', label: 'RANKS', comingSoon: true },
    { id: 'help', label: '?', href: '/help' }
  ];
  
  let showComingSoon = $state(false);
  let comingSoonFeature = $state('');
  
  function handleClick(item: NavItem) {
    if (item.comingSoon) {
      comingSoonFeature = item.label;
      showComingSoon = true;
      setTimeout(() => showComingSoon = false, 2000);
      return;
    }
    if (item.href) {
      goto(item.href);
    }
  }
</script>

<!-- Coming Soon tooltip -->
{#if showComingSoon}
  <div class="coming-soon-toast">
    {comingSoonFeature} coming soon...
  </div>
{/if}
```

### 4.5 Final Polish Checklist

```
MVP POLISH CHECKLIST
═══════════════════════════════════════════════════════════════════════════

VISUAL VERIFICATION:
□ All colors match Phase 2 design tokens
□ Typography hierarchy is clear
□ Spacing is consistent
□ All borders are sharp (0px radius)
□ Glow effects are subtle, not overwhelming
□ Scanlines are barely perceptible
□ Screen flash works for death/jackpot events

ANIMATION VERIFICATION:
□ Feed items animate in smoothly
□ Countdown numbers scale smoothly
□ Progress bars animate without jank
□ Modal open/close is smooth
□ Page transitions don't flash
□ Typing cursor blinks at correct rate

INTERACTION VERIFICATION:
□ All buttons have hover states
□ All buttons have focus states (keyboard)
□ All buttons have active (pressed) states
□ Touch targets are at least 44px on mobile
□ Keyboard navigation works throughout
□ Tab order is logical

AUDIO VERIFICATION:
□ Sounds play on correct events
□ Sounds don't stack/overlap badly
□ Volume control works
□ Mute persists across sessions
□ No audio plays if muted

CONTENT VERIFICATION:
□ No placeholder text remaining
□ All error messages are helpful
□ Timestamps format correctly
□ Numbers format with appropriate precision
□ Addresses truncate correctly

PERFORMANCE VERIFICATION:
□ Feed updates don't cause layout shifts
□ Typing game input latency < 16ms
□ Page load time < 3s on 3G
□ Memory doesn't grow unbounded
□ No React-style hydration warnings

ACCESSIBILITY VERIFICATION:
□ Color contrast meets WCAG AA
□ All interactive elements are focusable
□ Screen reader announces important changes
□ Reduced motion preference respected
□ All images have alt text (or aria-hidden)
```

### 4.6 Files to Create/Modify

```
PHASE 2A FILE LIST
═══════════════════════════════════════════════════════════════════════════

CREATE:
├── lib/ui/styles/responsive.css
├── lib/ui/styles/tokens-phase2.css
├── lib/core/types/errors.ts
├── lib/core/notifications/types.ts
├── lib/core/notifications/store.svelte.ts
├── lib/core/transactions/types.ts
├── lib/ui/feedback/ToastContainer.svelte
├── lib/ui/feedback/ToastItem.svelte
├── lib/ui/feedback/TransactionToast.svelte
└── routes/help/+page.svelte (placeholder)

MODIFY:
├── lib/ui/styles/tokens.css (merge Phase 2 colors)
├── lib/ui/terminal/Scanlines.svelte (subtle effect)
├── lib/ui/terminal/Flicker.svelte (subtle effect)
├── lib/ui/terminal/ScreenFlash.svelte (new colors)
├── lib/features/nav/NavigationBar.svelte (coming soon)
├── routes/+layout.svelte (toast container)
├── routes/+page.svelte (responsive grid)
└── app.css (import responsive.css)
```

---

## 5. Phase 2B: Dead Pool (Prediction Market)

> **Status:** ✅ COMPLETE
> 
> **Implemented Files:**
> - `routes/market/+page.svelte` (194 lines)
> - `lib/features/deadpool/*` (7 components)
> - `lib/core/providers/mock/generators/deadpool.ts`
> - Types integrated in `lib/core/types/index.ts`

**Priority:** High  
**Duration:** 2 weeks  
**Dependencies:** Phase 2A complete

### 5.1 Overview

Dead Pool is GHOSTNET's prediction market where players bet on network outcomes. It's a key engagement and revenue feature (5% rake burned).

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DEAD POOL CONCEPT                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  "The house always wins - and the house is the burn address."               │
│                                                                              │
│  PREDICTION TYPES:                                                           │
│  ├── Death Count:     "Will >50 operators be traced in DARKNET?"           │
│  ├── Whale Watch:     "Will a 5000+ $DATA position enter BLACK_ICE?"       │
│  ├── Survival Streak: "Will anyone hit a 20+ ghost streak?"                │
│  └── System Reset:    "Will timer hit critical (<30min) this hour?"        │
│                                                                              │
│  ECONOMICS:                                                                  │
│  ├── Players bet on OVER or UNDER the line                                  │
│  ├── Winning side splits the pot (minus 5% burn)                            │
│  ├── Odds are parimutuel (determined by bet distribution)                   │
│  └── Rounds last 15-60 minutes depending on type                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Type Definitions

Types already exist in `lib/core/types/index.ts`:

```typescript
// Already defined - extend as needed
export interface DeadPoolRound {
  id: string;
  roundNumber: number;
  type: 'death_count' | 'whale_watch' | 'survival_streak' | 'system_reset';
  targetLevel: Level;
  question: string;
  line: number;
  endsAt: number;
  pools: {
    under: bigint;
    over: bigint;
  };
  userBet: {
    side: 'under' | 'over';
    amount: bigint;
  } | null;
}

// NEW: Add these
export type DeadPoolStatus = 'betting' | 'locked' | 'resolving' | 'resolved';

export interface DeadPoolResult {
  roundId: string;
  outcome: 'under' | 'over';
  actualValue: number;
  totalPool: bigint;
  burnAmount: bigint;
  winnerPayout: bigint;
  userWon: boolean | null;  // null if didn't bet
  userPayout: bigint | null;
}

export interface DeadPoolHistory {
  round: DeadPoolRound;
  result: DeadPoolResult;
}
```

### 5.3 Provider Interface Extensions

```typescript
// lib/core/providers/types.ts - Add to DataProvider interface

interface DataProvider {
  // ... existing methods ...
  
  // Dead Pool
  readonly activeRounds: DeadPoolRound[];
  readonly deadPoolHistory: DeadPoolHistory[];
  getActiveRounds(): Promise<DeadPoolRound[]>;
  placeBet(roundId: string, side: 'under' | 'over', amount: bigint): Promise<string>;
  subscribeDeadPool(callback: (update: DeadPoolUpdate) => void): () => void;
}

type DeadPoolUpdate = 
  | { type: 'POOL_UPDATE'; roundId: string; pools: { under: bigint; over: bigint } }
  | { type: 'ROUND_LOCKED'; roundId: string }
  | { type: 'ROUND_RESOLVED'; result: DeadPoolResult }
  | { type: 'NEW_ROUND'; round: DeadPoolRound };
```

### 5.4 UI Components

#### 4.4.1 Dead Pool Page Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ GHOSTNET v1.0.7 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ [👤] [⚙]      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ DEAD POOL                                                          [?] ││
│  │ "Bet on the network. Feed the furnace."                                ││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │                                                                         ││
│  │  YOUR BALANCE: 1,247 $DATA       TOTAL WON: +3,420 $DATA (ALL TIME)   ││
│  │                                                                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌────────────────────────────────┐  ┌────────────────────────────────────┐ │
│  │ ACTIVE ROUND #1247             │  │ ACTIVE ROUND #1248                 │ │
│  │ TYPE: DEATH COUNT              │  │ TYPE: WHALE WATCH                  │ │
│  │                                │  │                                    │ │
│  │ "Will >50 operators be         │  │ "Will a 5000+ $DATA whale          │ │
│  │  traced in DARKNET?"           │  │  enter BLACK_ICE?"                 │ │
│  │                                │  │                                    │ │
│  │ LINE: 50 deaths                │  │ LINE: Yes/No                       │ │
│  │ ENDS IN: 23:45                 │  │ ENDS IN: 58:12                     │ │
│  │                                │  │                                    │ │
│  │ ┌─────────────────────────────┐│  │ ┌─────────────────────────────────┐│ │
│  │ │ UNDER 50    │    OVER 50   ││  │ │ NO          │         YES      ││ │
│  │ │ 12,450 Đ    │    8,320 Đ   ││  │ │ 4,200 Đ     │     15,800 Đ    ││ │
│  │ │ 1.67x       │    2.49x     ││  │ │ 4.76x       │     1.27x       ││ │
│  │ │             │ ● YOUR BET   ││  │ │             │                  ││ │
│  │ └─────────────────────────────┘│  │ └─────────────────────────────────┘│ │
│  │                                │  │                                    │ │
│  │ [BET UNDER]     [BET OVER]    │  │ [BET NO]         [BET YES]        │ │
│  └────────────────────────────────┘  └────────────────────────────────────┘ │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ RECENT RESULTS                                                         ││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │ #1246  DEATH COUNT [SUBNET]   OVER 30 ✓    You won +127 $DATA        ││
│  │ #1245  SYSTEM RESET           UNDER ✓      You didn't bet             ││
│  │ #1244  SURVIVAL STREAK        OVER 15 ✗    You lost -50 $DATA         ││
│  │ #1243  WHALE WATCH            YES ✓        You won +89 $DATA          ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│ [NETWORK] [POSITION] [GAMES] [CREW] [■MARKET] [RANKS] [?]                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 4.4.2 Component Hierarchy

```
routes/market/+page.svelte
├── DeadPoolHeader.svelte
│   ├── Balance display
│   └── Lifetime stats
├── ActiveRoundsGrid.svelte
│   └── RoundCard.svelte (×N)
│       ├── RoundHeader.svelte
│       ├── OddsDisplay.svelte
│       ├── PoolBars.svelte
│       └── BetButtons.svelte
├── ResultsPanel.svelte
│   └── ResultRow.svelte (×N)
└── BetModal.svelte
    ├── AmountInput
    ├── OddsPreview
    └── ConfirmButton
```

#### 4.4.3 Round Card Component

```svelte
<!-- lib/features/deadpool/RoundCard.svelte -->
<script lang="ts">
  import type { DeadPoolRound } from '$lib/core/types';
  import { Countdown } from '$lib/ui/primitives';
  import { LevelBadge } from '$lib/ui/data-display';
  import OddsDisplay from './OddsDisplay.svelte';
  import PoolBars from './PoolBars.svelte';
  
  interface Props {
    round: DeadPoolRound;
    onBet: (side: 'under' | 'over') => void;
  }
  
  let { round, onBet }: Props = $props();
  
  // Calculate odds (parimutuel)
  let totalPool = $derived(round.pools.under + round.pools.over);
  let underOdds = $derived(
    totalPool > 0n 
      ? Number(totalPool * 95n / 100n) / Number(round.pools.under) 
      : 0
  );
  let overOdds = $derived(
    totalPool > 0n 
      ? Number(totalPool * 95n / 100n) / Number(round.pools.over) 
      : 0
  );
  
  // Round type labels
  const typeLabels: Record<DeadPoolRound['type'], string> = {
    death_count: 'DEATH COUNT',
    whale_watch: 'WHALE WATCH',
    survival_streak: 'SURVIVAL STREAK',
    system_reset: 'SYSTEM RESET'
  };
</script>

<article class="round-card">
  <header class="round-header">
    <span class="round-number">#{round.roundNumber}</span>
    <span class="round-type">{typeLabels[round.type]}</span>
    {#if round.targetLevel}
      <LevelBadge level={round.targetLevel} compact />
    {/if}
  </header>
  
  <p class="round-question">"{round.question}"</p>
  
  <div class="round-meta">
    <span class="round-line">LINE: {round.line}</span>
    <Countdown 
      targetTime={round.endsAt} 
      format="mm:ss"
      urgent={round.endsAt - Date.now() < 60000}
    />
  </div>
  
  <OddsDisplay 
    {underOdds} 
    {overOdds}
    underPool={round.pools.under}
    overPool={round.pools.over}
    userBet={round.userBet}
  />
  
  <PoolBars 
    under={round.pools.under} 
    over={round.pools.over} 
  />
  
  <div class="round-actions">
    <button 
      class="bet-button bet-under"
      onclick={() => onBet('under')}
      disabled={!!round.userBet}
    >
      BET UNDER
    </button>
    <button 
      class="bet-button bet-over"
      onclick={() => onBet('over')}
      disabled={!!round.userBet}
    >
      BET OVER
    </button>
  </div>
</article>

<style>
  .round-card {
    background: var(--color-bg-secondary);
    border: 1px solid var(--color-border-subtle);
    padding: var(--space-4);
  }
  
  .round-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    margin-bottom: var(--space-3);
  }
  
  .round-number {
    font-size: var(--text-xs);
    color: var(--color-text-tertiary);
    text-transform: uppercase;
    letter-spacing: var(--tracking-wider);
  }
  
  .round-type {
    font-size: var(--text-sm);
    color: var(--color-accent);
    font-weight: var(--font-medium);
  }
  
  .round-question {
    font-size: var(--text-base);
    color: var(--color-text-primary);
    margin-bottom: var(--space-3);
    font-style: italic;
  }
  
  .round-meta {
    display: flex;
    justify-content: space-between;
    font-size: var(--text-xs);
    color: var(--color-text-tertiary);
    margin-bottom: var(--space-4);
  }
  
  .round-actions {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--space-2);
    margin-top: var(--space-4);
  }
  
  .bet-button {
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    font-weight: var(--font-medium);
    border: 1px solid var(--color-border-default);
    background: var(--color-bg-tertiary);
    color: var(--color-text-secondary);
    cursor: pointer;
    transition: all var(--duration-fast);
  }
  
  .bet-button:hover:not(:disabled) {
    border-color: var(--color-accent);
    color: var(--color-accent);
  }
  
  .bet-button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
</style>
```

#### 4.4.4 Bet Modal

```svelte
<!-- lib/features/deadpool/BetModal.svelte -->
<script lang="ts">
  import type { DeadPoolRound } from '$lib/core/types';
  import { Modal } from '$lib/ui/terminal';
  import { Button, AnimatedNumber } from '$lib/ui/primitives';
  import { AmountDisplay } from '$lib/ui/data-display';
  
  interface Props {
    round: DeadPoolRound;
    side: 'under' | 'over';
    userBalance: bigint;
    onConfirm: (amount: bigint) => void;
    onClose: () => void;
  }
  
  let { round, side, userBalance, onConfirm, onClose }: Props = $props();
  
  let amount = $state(0n);
  let inputValue = $state('');
  
  // Calculate projected odds with this bet
  let currentPool = $derived(side === 'under' ? round.pools.under : round.pools.over);
  let oppositePool = $derived(side === 'under' ? round.pools.over : round.pools.under);
  let newPool = $derived(currentPool + amount);
  let totalPool = $derived(newPool + oppositePool);
  let projectedOdds = $derived(
    newPool > 0n ? Number(totalPool * 95n / 100n) / Number(newPool) : 0
  );
  let projectedPayout = $derived(amount * BigInt(Math.floor(projectedOdds * 100)) / 100n);
  
  function handleInput(e: Event) {
    const value = (e.target as HTMLInputElement).value;
    inputValue = value;
    const parsed = parseFloat(value);
    if (!isNaN(parsed) && parsed > 0) {
      amount = BigInt(Math.floor(parsed * 1e18));
    } else {
      amount = 0n;
    }
  }
  
  function setQuickAmount(percent: number) {
    amount = userBalance * BigInt(percent) / 100n;
    inputValue = (Number(amount) / 1e18).toFixed(2);
  }
</script>

<Modal title="PLACE BET" onClose={onClose}>
  <div class="bet-modal">
    <div class="bet-info">
      <p class="bet-question">"{round.question}"</p>
      <p class="bet-side">
        Betting: <strong class="side-{side}">{side.toUpperCase()}</strong>
      </p>
    </div>
    
    <div class="amount-section">
      <label class="amount-label">BET AMOUNT ($DATA)</label>
      <input 
        type="number"
        class="amount-input"
        value={inputValue}
        oninput={handleInput}
        placeholder="0.00"
        min="0"
        step="0.01"
      />
      <div class="quick-amounts">
        <button onclick={() => setQuickAmount(10)}>10%</button>
        <button onclick={() => setQuickAmount(25)}>25%</button>
        <button onclick={() => setQuickAmount(50)}>50%</button>
        <button onclick={() => setQuickAmount(100)}>MAX</button>
      </div>
      <p class="balance-hint">
        Balance: <AmountDisplay amount={userBalance} symbol="$DATA" />
      </p>
    </div>
    
    <div class="projection">
      <div class="projection-row">
        <span class="projection-label">PROJECTED ODDS</span>
        <span class="projection-value">{projectedOdds.toFixed(2)}x</span>
      </div>
      <div class="projection-row">
        <span class="projection-label">POTENTIAL PAYOUT</span>
        <span class="projection-value payout">
          <AmountDisplay amount={projectedPayout} symbol="$DATA" />
        </span>
      </div>
      <p class="rake-note">* 5% of pool is burned (rake)</p>
    </div>
    
    <div class="bet-actions">
      <Button variant="ghost" onclick={onClose}>CANCEL</Button>
      <Button 
        variant="primary" 
        onclick={() => onConfirm(amount)}
        disabled={amount === 0n || amount > userBalance}
      >
        CONFIRM BET
      </Button>
    </div>
  </div>
</Modal>
```

### 5.5 Mock Provider Extensions

```typescript
// lib/core/providers/mock/generators/deadpool.ts

import type { DeadPoolRound, DeadPoolResult, Level } from '../../../types';

const ROUND_TEMPLATES = [
  {
    type: 'death_count' as const,
    questionTemplate: 'Will >{line} operators be traced in {level}?',
    levels: ['SUBNET', 'DARKNET', 'BLACK_ICE'] as Level[],
    lineRange: [20, 100],
    duration: 30 * 60 * 1000,  // 30 minutes
  },
  {
    type: 'whale_watch' as const,
    questionTemplate: 'Will a {line}+ $DATA whale enter {level}?',
    levels: ['DARKNET', 'BLACK_ICE'] as Level[],
    lineRange: [5000, 20000],
    duration: 60 * 60 * 1000,  // 1 hour
  },
  {
    type: 'survival_streak' as const,
    questionTemplate: 'Will anyone hit a {line}+ ghost streak?',
    levels: ['DARKNET', 'BLACK_ICE'] as Level[],
    lineRange: [10, 30],
    duration: 45 * 60 * 1000,  // 45 minutes
  },
  {
    type: 'system_reset' as const,
    questionTemplate: 'Will the reset timer hit critical (<{line}min)?',
    levels: [] as Level[],
    lineRange: [15, 60],
    duration: 60 * 60 * 1000,  // 1 hour
  },
];

let roundCounter = 1240;

export function generateMockRound(): DeadPoolRound {
  const template = ROUND_TEMPLATES[Math.floor(Math.random() * ROUND_TEMPLATES.length)];
  const level = template.levels.length > 0 
    ? template.levels[Math.floor(Math.random() * template.levels.length)]
    : 'DARKNET';
  const line = Math.floor(
    Math.random() * (template.lineRange[1] - template.lineRange[0]) + template.lineRange[0]
  );
  
  const question = template.questionTemplate
    .replace('{line}', line.toString())
    .replace('{level}', level);
  
  return {
    id: crypto.randomUUID(),
    roundNumber: ++roundCounter,
    type: template.type,
    targetLevel: level,
    question,
    line,
    endsAt: Date.now() + template.duration,
    pools: {
      under: BigInt(Math.floor(Math.random() * 20000 + 5000)) * 10n ** 18n,
      over: BigInt(Math.floor(Math.random() * 20000 + 5000)) * 10n ** 18n,
    },
    userBet: null,
  };
}

export function resolveRound(round: DeadPoolRound): DeadPoolResult {
  // Random outcome (in real impl, this comes from oracle/actual data)
  const outcome: 'under' | 'over' = Math.random() > 0.5 ? 'over' : 'under';
  const actualValue = round.line + (outcome === 'over' ? 1 : -1) * Math.floor(Math.random() * 10);
  
  const totalPool = round.pools.under + round.pools.over;
  const burnAmount = totalPool * 5n / 100n;
  const winnerPool = totalPool - burnAmount;
  
  return {
    roundId: round.id,
    outcome,
    actualValue,
    totalPool,
    burnAmount,
    winnerPayout: winnerPool,
    userWon: round.userBet ? round.userBet.side === outcome : null,
    userPayout: round.userBet?.side === outcome 
      ? round.userBet.amount * winnerPool / (outcome === 'under' ? round.pools.under : round.pools.over)
      : null,
  };
}
```

### 5.6 Implementation Checklist

```
PHASE 2B: DEAD POOL
═══════════════════════════════════════════════════════════════════════════

□ 4.6.1 Type Definitions
  □ Extend DeadPoolRound with status field
  □ Add DeadPoolResult interface
  □ Add DeadPoolHistory interface
  □ Add DeadPoolUpdate union type

□ 4.6.2 Provider Extensions
  □ Add activeRounds getter
  □ Add deadPoolHistory getter
  □ Add getActiveRounds() method
  □ Add placeBet() method
  □ Add subscribeDeadPool() method

□ 4.6.3 Mock Provider Implementation
  □ Create generators/deadpool.ts
  □ Add round generation logic
  □ Add round resolution logic
  □ Add pool update simulation
  □ Integrate with main provider

□ 4.6.4 Page & Layout
  □ Create routes/market/+page.svelte
  □ Create responsive layout
  □ Add navigation link

□ 4.6.5 Components
  □ DeadPoolHeader.svelte
  □ ActiveRoundsGrid.svelte
  □ RoundCard.svelte
  □ OddsDisplay.svelte
  □ PoolBars.svelte
  □ BetModal.svelte
  □ ResultsPanel.svelte
  □ ResultRow.svelte

□ 4.6.6 Audio
  □ Add betPlaced sound
  □ Add roundLocked sound
  □ Add winSound
  □ Add loseSound

□ 4.6.7 Feed Integration
  □ Add DEADPOOL_BET feed event
  □ Add DEADPOOL_WIN feed event
  □ Add DEADPOOL_RESOLVED feed event

□ 4.6.8 Testing
  □ Unit tests for odds calculation
  □ Unit tests for payout calculation
  □ Component tests for RoundCard
  □ E2E test for bet flow

ACCEPTANCE CRITERIA:
□ Can view active rounds
□ Can place bets (mock)
□ Odds update in real-time
□ Results show correctly
□ History displays past rounds
□ Audio plays on events
□ Responsive on all breakpoints
```

---

## 6. Phase 2C: Hack Runs (Mini-Game)

> **Status:** ✅ COMPLETE
> 
> **Implemented Files:**
> - `routes/games/hackrun/+page.svelte` (473 lines)
> - `lib/features/hackrun/*` (8 components + store + generators)
> - `lib/core/types/hackrun.ts` (287 lines)

**Priority:** High  
**Duration:** 3 weeks  
**Dependencies:** Phase 2A complete

### 5.1 Overview

Hack Runs is a multi-node exploration mini-game where players navigate through a virtual network, making decisions at each node and completing typing challenges to earn temporary yield multipliers.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           HACK RUN CONCEPT                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  STRUCTURE:                                                                  │
│  ├── 5 nodes per run                                                         │
│  ├── Each node has a typing challenge                                        │
│  ├── Some nodes have bonus loot / traps                                     │
│  └── Completion grants yield multiplier (1.5x - 3x)                         │
│                                                                              │
│  NODE PATH:                                                                  │
│                                                                              │
│  START ──▶ NODE 1 ──▶ NODE 2 ──▶ NODE 3 ──▶ NODE 4 ──▶ NODE 5 ──▶ EXTRACT  │
│              │          │          │          │          │                   │
│           FIREWALL   PATROL    DATA CACHE    TRAP      ICE WALL             │
│                         ╲                    ╱                               │
│                          ╲──── BACKDOOR ────╱  (shortcut, risky)            │
│                                                                              │
│  NODE TYPES:                                                                 │
│  ├── FIREWALL:   Medium risk, standard reward                               │
│  ├── PATROL:     Low risk, low reward                                       │
│  ├── DATA CACHE: High risk, high reward (bonus loot)                        │
│  ├── TRAP:       Very high risk, skip reward                                │
│  ├── ICE WALL:   Medium risk, hard typing challenge                         │
│  ├── HONEYPOT:   Looks good, but might be a trap                            │
│  └── BACKDOOR:   Skip nodes (risky shortcut)                                │
│                                                                              │
│  ENTRY COST: 50-200 $DATA (burned on failure, refunded on success)          │
│  DURATION: 3-5 minutes per run                                              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Type Definitions

```typescript
// lib/core/types/hackrun.ts

export type NodeType = 
  | 'firewall'
  | 'patrol'
  | 'data_cache'
  | 'trap'
  | 'ice_wall'
  | 'honeypot'
  | 'backdoor';

export interface HackRunNode {
  id: string;
  type: NodeType;
  position: number;  // 1-5
  name: string;
  description: string;
  challenge: TypingChallenge;
  reward: NodeReward;
  risk: 'low' | 'medium' | 'high' | 'extreme';
  alternativePaths?: string[];  // IDs of nodes this can skip to
}

export interface NodeReward {
  type: 'multiplier' | 'loot' | 'skip' | 'none';
  value: number;  // 1.5 = 1.5x multiplier
  label: string;
}

export interface HackRun {
  id: string;
  difficulty: 'easy' | 'medium' | 'hard';
  entryFee: bigint;
  nodes: HackRunNode[];
  baseMultiplier: number;  // Successful completion grants this
  timeLimit: number;  // Total time in ms
}

export type HackRunState = 
  | { status: 'idle' }
  | { status: 'selecting'; availableRuns: HackRun[] }
  | { status: 'countdown'; run: HackRun; secondsLeft: number }
  | { status: 'running'; run: HackRun; currentNode: number; progress: NodeProgress[] }
  | { status: 'node_typing'; run: HackRun; node: HackRunNode; typingState: TypingState }
  | { status: 'node_result'; run: HackRun; node: HackRunNode; result: NodeResult }
  | { status: 'complete'; run: HackRun; result: HackRunResult }
  | { status: 'failed'; run: HackRun; reason: string };

export interface NodeProgress {
  nodeId: string;
  status: 'pending' | 'current' | 'completed' | 'failed' | 'skipped';
  result?: NodeResult;
}

export interface NodeResult {
  success: boolean;
  accuracy: number;
  wpm: number;
  lootGained: bigint;
  multiplierGained: number;
}

export interface HackRunResult {
  success: boolean;
  nodesCompleted: number;
  totalNodes: number;
  finalMultiplier: number;
  lootGained: bigint;
  timeElapsed: number;
  xpGained: number;
}
```

### 6.3 UI Components

#### 5.3.1 Hack Run Page Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ GHOSTNET v1.0.7 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ [👤] [⚙]      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ HACK RUNS                                                               ││
│  │ "Navigate the network. Earn multipliers. Don't get caught."             ││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │                                                                         ││
│  │  CURRENT MULTIPLIER: 1.0x       RUNS COMPLETED: 12       XP: 2,450     ││
│  │                                                                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  SELECT YOUR RUN:                                                            │
│                                                                              │
│  ┌──────────────────────┐ ┌──────────────────────┐ ┌──────────────────────┐ │
│  │ EASY                 │ │ MEDIUM               │ │ HARD                 │ │
│  │                      │ │                      │ │                      │ │
│  │ Entry: 50 $DATA      │ │ Entry: 100 $DATA     │ │ Entry: 200 $DATA     │ │
│  │ Reward: 1.5x mult    │ │ Reward: 2.0x mult    │ │ Reward: 3.0x mult    │ │
│  │ Time: 5 min          │ │ Time: 4 min          │ │ Time: 3 min          │ │
│  │ Nodes: 5             │ │ Nodes: 5             │ │ Nodes: 5             │ │
│  │                      │ │                      │ │                      │ │
│  │ ● ─ ● ─ ● ─ ● ─ ●   │ │ ● ─ ● ─ ● ─ ● ─ ●   │ │ ● ─ ● ─ ● ─ ● ─ ●   │ │
│  │                      │ │   ╲     ╱           │ │   ╲   ╲ ╱   ╱       │ │
│  │                      │ │    ● ─ ●             │ │    ● ─ ● ─ ●         │ │
│  │                      │ │ (1 shortcut)        │ │ (2 shortcuts)        │ │
│  │                      │ │                      │ │                      │ │
│  │ [START RUN]          │ │ [START RUN]          │ │ [START RUN]          │ │
│  └──────────────────────┘ └──────────────────────┘ └──────────────────────┘ │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ RECENT RUNS                                                             ││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │ MEDIUM  5/5 nodes  2.0x multiplier  +127 loot  2:34 elapsed  ✓         ││
│  │ HARD    3/5 nodes  FAILED at ICE WALL  -200 $DATA entry  ✗             ││
│  │ EASY    5/5 nodes  1.5x multiplier  +45 loot   4:12 elapsed  ✓         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│ [NETWORK] [POSITION] [■GAMES] [CREW] [MARKET] [RANKS] [?]                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 5.3.2 Active Run View

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             HACK RUN - MEDIUM                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  TIME: 02:34 / 04:00                      MULTIPLIER: 1.3x → 2.0x          │
│  ████████████████████░░░░░░░░░░           LOOT: +87 $DATA                   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                                                                         ││
│  │                     NODE MAP                                            ││
│  │                                                                         ││
│  │  [✓]──────[✓]──────[●]──────[ ]──────[ ]                               ││
│  │   1        2        3        4        5                                 ││
│  │ FIREWALL PATROL  DATA_CACHE  ???      ???                              ││
│  │                                                                         ││
│  │               ╲                   ╱                                     ││
│  │                ╲─────[BACK]─────╱                                       ││
│  │                    (risky)                                              ││
│  │                                                                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ CURRENT NODE: DATA CACHE                                                ││
│  │ Risk: HIGH   Reward: +50 $DATA loot + 0.2x multiplier                  ││
│  │                                                                         ││
│  │ "A data cache has been detected. High value target, but heavily        ││
│  │  monitored. Type the extraction sequence to grab the data."            ││
│  │                                                                         ││
│  │ ─────────────────────────────────────────────────────────────────────  ││
│  │                                                                         ││
│  │  rsync -avz --progress /vault/data ghost@exit:/extracted/              ││
│  │  ████████████████████████████░░░░░░░░░░░░░░░░░░░░░  67%                ││
│  │                                                                         ││
│  │  WPM: 72    ACCURACY: 94%    TIME: 12s                                 ││
│  │                                                                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  [ESC] Abort Run (lose entry fee)                                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 5.3.3 Component Hierarchy

```
routes/games/hackrun/+page.svelte
├── HackRunHeader.svelte
│   ├── Current multiplier
│   ├── Runs completed
│   └── XP display
├── RunSelectionView.svelte (status: idle/selecting)
│   └── RunCard.svelte (×3 difficulties)
│       ├── Difficulty badge
│       ├── Entry fee
│       ├── Reward preview
│       └── Node path preview
├── ActiveRunView.svelte (status: running/node_*)
│   ├── RunProgress.svelte
│   │   ├── Timer
│   │   ├── Multiplier accumulator
│   │   └── Loot accumulator
│   ├── NodeMap.svelte
│   │   └── NodeMarker.svelte (×N)
│   ├── CurrentNodePanel.svelte
│   │   ├── Node info
│   │   └── TypingChallenge (reuse from Phase 1)
│   └── AbortButton.svelte
├── NodeResultView.svelte (status: node_result)
│   ├── Success/failure indicator
│   ├── Stats (WPM, accuracy)
│   └── Rewards gained
├── RunCompleteView.svelte (status: complete/failed)
│   ├── Final stats
│   ├── Total rewards
│   └── Action buttons
└── RunHistoryPanel.svelte
    └── HistoryRow.svelte (×N)
```

### 6.4 Game Logic

```typescript
// lib/features/hackrun/store.svelte.ts

import type { HackRun, HackRunState, HackRunNode, NodeResult } from '$lib/core/types/hackrun';

export function createHackRunStore() {
  let state = $state<HackRunState>({ status: 'idle' });
  let timeRemaining = $state(0);
  let timerInterval: ReturnType<typeof setInterval> | null = null;
  
  // Current run computed values
  let currentMultiplier = $derived(() => {
    if (state.status !== 'running') return 1;
    return state.progress
      .filter(p => p.status === 'completed' && p.result)
      .reduce((mult, p) => mult + (p.result?.multiplierGained || 0), state.run.baseMultiplier);
  });
  
  let totalLoot = $derived(() => {
    if (state.status !== 'running') return 0n;
    return state.progress
      .filter(p => p.status === 'completed' && p.result)
      .reduce((loot, p) => loot + (p.result?.lootGained || 0n), 0n);
  });
  
  function startRun(run: HackRun) {
    state = {
      status: 'countdown',
      run,
      secondsLeft: 3
    };
    
    // Countdown
    const countdown = setInterval(() => {
      if (state.status === 'countdown') {
        state = { ...state, secondsLeft: state.secondsLeft - 1 };
        if (state.secondsLeft <= 0) {
          clearInterval(countdown);
          beginRun(run);
        }
      }
    }, 1000);
  }
  
  function beginRun(run: HackRun) {
    timeRemaining = run.timeLimit;
    
    state = {
      status: 'running',
      run,
      currentNode: 0,
      progress: run.nodes.map(n => ({ nodeId: n.id, status: 'pending' }))
    };
    
    // Start timer
    timerInterval = setInterval(() => {
      timeRemaining -= 1000;
      if (timeRemaining <= 0) {
        failRun('Time expired');
      }
    }, 1000);
    
    // Start first node
    startNode(0);
  }
  
  function startNode(index: number) {
    if (state.status !== 'running') return;
    
    const node = state.run.nodes[index];
    state = {
      ...state,
      currentNode: index,
      progress: state.progress.map((p, i) => 
        i === index ? { ...p, status: 'current' } : p
      )
    };
    
    // Transition to typing state
    state = {
      status: 'node_typing',
      run: state.run,
      node,
      typingState: {
        status: 'active',
        challenge: node.challenge,
        progress: { typed: '', correct: 0, errors: 0, startTime: Date.now() }
      }
    };
  }
  
  function completeNode(result: NodeResult) {
    if (state.status !== 'node_typing') return;
    
    const { run, node } = state;
    const nodeIndex = run.nodes.findIndex(n => n.id === node.id);
    
    // Show result
    state = {
      status: 'node_result',
      run,
      node,
      result
    };
    
    // After delay, continue or finish
    setTimeout(() => {
      if (result.success) {
        // Update progress
        const newProgress = run.nodes.map((n, i) => {
          if (i === nodeIndex) return { nodeId: n.id, status: 'completed' as const, result };
          if (i > nodeIndex) return { nodeId: n.id, status: 'pending' as const };
          return state.status === 'running' ? state.progress[i] : { nodeId: n.id, status: 'pending' as const };
        });
        
        if (nodeIndex === run.nodes.length - 1) {
          // Run complete!
          completeRun(newProgress);
        } else {
          // Next node
          state = {
            status: 'running',
            run,
            currentNode: nodeIndex + 1,
            progress: newProgress
          };
          startNode(nodeIndex + 1);
        }
      } else {
        failRun('Failed typing challenge');
      }
    }, 2000);
  }
  
  function completeRun(progress: typeof state extends { progress: infer P } ? P : never) {
    if (timerInterval) clearInterval(timerInterval);
    
    const run = state.status === 'node_result' ? state.run : 
                state.status === 'running' ? state.run : null;
    if (!run) return;
    
    state = {
      status: 'complete',
      run,
      result: {
        success: true,
        nodesCompleted: progress.filter(p => p.status === 'completed').length,
        totalNodes: run.nodes.length,
        finalMultiplier: currentMultiplier(),
        lootGained: totalLoot(),
        timeElapsed: run.timeLimit - timeRemaining,
        xpGained: calculateXP(run, progress)
      }
    };
  }
  
  function failRun(reason: string) {
    if (timerInterval) clearInterval(timerInterval);
    
    const run = state.status === 'running' ? state.run :
                state.status === 'node_typing' ? state.run :
                state.status === 'node_result' ? state.run : null;
    if (!run) return;
    
    state = {
      status: 'failed',
      run,
      reason
    };
  }
  
  function abort() {
    failRun('Aborted by user');
  }
  
  function reset() {
    state = { status: 'idle' };
    timeRemaining = 0;
  }
  
  return {
    get state() { return state; },
    get timeRemaining() { return timeRemaining; },
    get currentMultiplier() { return currentMultiplier(); },
    get totalLoot() { return totalLoot(); },
    startRun,
    completeNode,
    abort,
    reset
  };
}

function calculateXP(run: HackRun, progress: any[]): number {
  const baseXP = { easy: 50, medium: 100, hard: 200 }[run.difficulty];
  const completionBonus = progress.filter(p => p.status === 'completed').length * 20;
  return baseXP + completionBonus;
}
```

### 6.5 Implementation Checklist

```
PHASE 2C: HACK RUNS
═══════════════════════════════════════════════════════════════════════════

□ 5.5.1 Type Definitions
  □ Create lib/core/types/hackrun.ts
  □ NodeType enum
  □ HackRunNode interface
  □ NodeReward interface
  □ HackRun interface
  □ HackRunState union
  □ NodeProgress interface
  □ NodeResult interface
  □ HackRunResult interface

□ 5.5.2 Game Logic
  □ Create lib/features/hackrun/store.svelte.ts
  □ State machine implementation
  □ Timer management
  □ Node progression logic
  □ Multiplier accumulation
  □ Loot accumulation
  □ XP calculation

□ 5.5.3 Node Generation
  □ Create lib/features/hackrun/generators/nodes.ts
  □ Node type definitions with challenges
  □ Difficulty-based challenge selection
  □ Path generation with shortcuts

□ 5.5.4 Run Configuration
  □ Create lib/features/hackrun/config.ts
  □ Easy/Medium/Hard run templates
  □ Entry fees
  □ Time limits
  □ Base multipliers

□ 5.5.5 Page & Layout
  □ Create routes/games/hackrun/+page.svelte
  □ Create responsive layout
  □ Add navigation from /games

□ 5.5.6 Components - Selection
  □ HackRunHeader.svelte
  □ RunSelectionView.svelte
  □ RunCard.svelte
  □ NodePathPreview.svelte

□ 5.5.7 Components - Active Run
  □ ActiveRunView.svelte
  □ RunProgress.svelte
  □ NodeMap.svelte
  □ NodeMarker.svelte
  □ CurrentNodePanel.svelte
  □ AbortButton.svelte

□ 5.5.8 Components - Results
  □ NodeResultView.svelte
  □ RunCompleteView.svelte
  □ RunFailedView.svelte
  □ RunHistoryPanel.svelte
  □ HistoryRow.svelte

□ 5.5.9 Integration
  □ Reuse typing challenge from Phase 1
  □ Connect to provider for fee payment
  □ Update modifiers on completion
  □ Add to feed events

□ 5.5.10 Audio
  □ Add nodeStart sound
  □ Add nodeComplete sound
  □ Add nodeFailed sound
  □ Add runComplete sound
  □ Add runFailed sound
  □ Add lootPickup sound

□ 5.5.11 Testing
  □ Unit tests for state machine
  □ Unit tests for multiplier calc
  □ Unit tests for XP calc
  □ Component tests
  □ E2E test for full run

ACCEPTANCE CRITERIA:
□ Can select difficulty
□ Entry fee deducted on start
□ Can navigate nodes
□ Typing challenges work
□ Multiplier accumulates correctly
□ Loot displays correctly
□ Timer works
□ Can abort (lose entry)
□ Success grants multiplier modifier
□ Failure loses entry fee
□ History shows past runs
□ Audio plays on events
□ Responsive on all breakpoints
```

---

## 7. Phase 2D: Crew System

> **Status:** ✅ COMPLETE
> 
> **Implemented Files:**
> - `routes/crew/+page.svelte` (261 lines)
> - `lib/features/crew/*` (9 components)
> - `lib/core/providers/mock/generators/crew.ts`
> - Types integrated in `lib/core/types/index.ts`

**Priority:** Medium  
**Duration:** 2 weeks  
**Dependencies:** Phase 2A complete

### 6.1 Overview

Crews are teams/guilds that provide social features and passive bonuses. Players in a crew share certain benefits and can participate in crew-wide activities.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CREW SYSTEM CONCEPT                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  BENEFITS:                                                                   │
│  ├── Shared death rate reduction (crew members' survival helps you)         │
│  ├── Crew bonuses (activated when conditions met)                           │
│  ├── Crew chat                                                              │
│  └── Crew raids (coordinated activities for rewards)                        │
│                                                                              │
│  STRUCTURE:                                                                  │
│  ├── Max 50 members per crew                                                │
│  ├── Crew leader can invite/kick                                            │
│  ├── Weekly crew rankings                                                   │
│  └── Crew treasury (shared rewards)                                         │
│                                                                              │
│  BONUSES (Examples):                                                         │
│  ├── "Safety in Numbers": >10 members online → -5% death rate              │
│  ├── "Whale Shield": Crew TVL >10k $DATA → -10% death rate                 │
│  ├── "Ghost Collective": 5+ members with streaks → +5% yield               │
│  └── "Risk Lovers": 3+ members in BLACK_ICE → +15% yield (risky)           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Type Definitions

Types already exist - extend as needed:

```typescript
// lib/core/types/index.ts - Already defined, extend:

export interface Crew {
  id: string;
  name: string;
  tag: string;  // 3-4 char tag like [PHTM]
  description: string;
  memberCount: number;
  maxMembers: number;
  rank: number;
  totalStaked: bigint;
  weeklyExtracted: bigint;
  bonuses: CrewBonus[];
  members: CrewMember[];
  leader: `0x${string}`;
  createdAt: number;
  isPublic: boolean;  // Can anyone join?
}

export interface CrewMember {
  address: `0x${string}`;
  level: Level;
  stakedAmount: bigint;
  ghostStreak: number;
  isOnline: boolean;
  isYou: boolean;
  role: 'leader' | 'officer' | 'member';
  joinedAt: number;
  weeklyContribution: bigint;
}

export interface CrewBonus {
  id: string;
  name: string;
  condition: string;
  effect: string;
  effectType: 'death_rate' | 'yield_multiplier';
  effectValue: number;
  active: boolean;
  progress?: number;  // 0-1, how close to activation
}

export interface CrewInvite {
  id: string;
  crewId: string;
  crewName: string;
  inviterAddress: `0x${string}`;
  expiresAt: number;
}

export interface CrewApplication {
  id: string;
  applicantAddress: `0x${string}`;
  message: string;
  appliedAt: number;
}
```

### 6.3 UI Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ GHOSTNET v1.0.7 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ [👤] [⚙]      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ CREW: PHANTOMS [PHTM]                                    RANK: #7      ││
│  │ "We ghost through the network. We never die."                          ││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │                                                                         ││
│  │  MEMBERS: 23/50          TVL: 127,450 $DATA         WEEKLY: +34,200   ││
│  │  ███████████░░░░░░░░░    ████████████████░░░░        ▲ +12% vs last    ││
│  │                                                                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────┐  ┌───────────────────────────────────────┐ │
│  │ ACTIVE BONUSES             │  │ MEMBERS ONLINE (12)                   │ │
│  │                            │  │                                       │ │
│  │ ✓ Safety in Numbers  -5%  │  │ 0x7a3f (you)  DARKNET  500Đ  🔥7    │ │
│  │   12/10 members online     │  │ 0x9c2d        BLACK_ICE 200Đ  🔥12  │ │
│  │                            │  │ 0x3b1a        DARKNET  750Đ  🔥3    │ │
│  │ ✓ Whale Shield      -10%  │  │ 0x8f2e        SUBNET   100Đ  🔥0    │ │
│  │   TVL > 100k $DATA         │  │ 0x1d4c        DARKNET  300Đ  🔥5    │ │
│  │                            │  │ ...                                   │ │
│  │ ○ Ghost Collective  +5%   │  │                                       │ │
│  │   3/5 members with streaks │  │ [VIEW ALL]                            │ │
│  │   ████████████░░░░░░░░     │  │                                       │ │
│  │                            │  ├───────────────────────────────────────┤ │
│  │ ○ Risk Lovers       +15%  │  │ OFFLINE (11)                          │ │
│  │   1/3 in BLACK_ICE         │  │ 0x2a9f  VAULT     1000Đ  Last: 2h   │ │
│  │   ████░░░░░░░░░░░░░░░░     │  │ 0x5e7b  MAINFRAME 500Đ   Last: 4h   │ │
│  │                            │  │ ...                                   │ │
│  └─────────────────────────────┘  └───────────────────────────────────────┘ │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ CREW ACTIVITY                                                          ││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │ > 0x9c2d survived [BLACK_ICE] streak: 12! 🔥                           ││
│  │ > 0x3b1a jacked in [DARKNET] 750 $DATA                                 ││
│  │ > BONUS ACTIVATED: "Safety in Numbers" -5% death rate                  ││
│  │ > 0x7a3f extracted +312 $DATA gain                                     ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  [INVITE]  [LEAVE CREW]  [CREW SETTINGS]                                    │
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│ [NETWORK] [POSITION] [GAMES] [■CREW] [MARKET] [RANKS] [?]                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.4 Component Hierarchy

```
routes/crew/+page.svelte
├── CrewHeader.svelte (if in crew)
│   ├── Crew name, tag, rank
│   ├── Description
│   └── Stats summary
├── NoCrew View (if not in crew)
│   ├── CreateCrewCard.svelte
│   ├── JoinCrewCard.svelte
│   └── PendingInvites.svelte
├── CrewDashboard.svelte (if in crew)
│   ├── BonusesPanel.svelte
│   │   └── BonusRow.svelte (×N)
│   ├── MembersPanel.svelte
│   │   ├── MemberRow.svelte (×N online)
│   │   └── MemberRow.svelte (×N offline)
│   ├── ActivityFeed.svelte
│   │   └── ActivityRow.svelte (×N)
│   └── ActionButtons.svelte
├── CrewSettingsModal.svelte (leader only)
│   ├── Description edit
│   ├── Public/private toggle
│   ├── Member management
│   └── Transfer leadership
├── InviteModal.svelte
│   └── Address input + send
└── CreateCrewModal.svelte
    ├── Name input
    ├── Tag input
    ├── Description
    └── Public/private
```

### 6.5 Implementation Checklist

```
PHASE 2D: CREW SYSTEM
═══════════════════════════════════════════════════════════════════════════

□ 6.5.1 Type Extensions
  □ Extend Crew interface
  □ Add CrewInvite interface
  □ Add CrewApplication interface
  □ Add crew-related feed events

□ 6.5.2 Provider Extensions
  □ Add crew getter
  □ Add crewInvites getter
  □ Add createCrew() method
  □ Add joinCrew() method
  □ Add leaveCrew() method
  □ Add inviteMember() method
  □ Add kickMember() method
  □ Add updateCrewSettings() method
  □ Add subscribeCrewActivity() method

□ 6.5.3 Mock Provider
  □ Generate mock crew data
  □ Generate mock members
  □ Simulate bonus activation
  □ Simulate member activity

□ 6.5.4 Page & Layout
  □ Create routes/crew/+page.svelte
  □ Create responsive layout
  □ Handle no-crew state

□ 6.5.5 Components - No Crew
  □ CreateCrewCard.svelte
  □ JoinCrewCard.svelte
  □ CrewBrowser.svelte (discover crews)
  □ PendingInvites.svelte

□ 6.5.6 Components - In Crew
  □ CrewHeader.svelte
  □ CrewDashboard.svelte
  □ BonusesPanel.svelte
  □ BonusRow.svelte
  □ MembersPanel.svelte
  □ MemberRow.svelte
  □ ActivityFeed.svelte
  □ ActivityRow.svelte
  □ ActionButtons.svelte

□ 6.5.7 Modals
  □ CreateCrewModal.svelte
  □ JoinCrewModal.svelte
  □ InviteModal.svelte
  □ CrewSettingsModal.svelte
  □ LeaveCrewConfirmModal.svelte

□ 6.5.8 Bonus Logic
  □ Create bonus condition evaluators
  □ Integrate with position modifiers
  □ Update death rate calculations
  □ Update yield calculations

□ 6.5.9 Feed Integration
  □ Add CREW_JOINED event
  □ Add CREW_LEFT event
  □ Add CREW_BONUS_ACTIVATED event
  □ Add CREW_BONUS_DEACTIVATED event
  □ Filter main feed for crew events

□ 6.5.10 Testing
  □ Unit tests for bonus conditions
  □ Component tests
  □ E2E test for create/join flow

ACCEPTANCE CRITERIA:
□ Can create a crew
□ Can join a crew (public)
□ Can apply to crew (private)
□ Can invite members
□ Can leave crew
□ Can kick members (leader)
□ Bonuses display correctly
□ Bonuses activate when conditions met
□ Member list updates in real-time
□ Activity feed shows crew events
□ Responsive on all breakpoints
```

---

## 8. Phase 2E: Leaderboard & Rankings

> **Status:** ✅ COMPLETE
> 
> **Implemented Files:**
> - `routes/leaderboard/+page.svelte` (212 lines)
> - `lib/features/leaderboard/*` (7 components)
> - `lib/core/providers/mock/generators/leaderboard.ts`
> - `lib/core/types/leaderboard.ts` (251 lines)

**Priority:** Medium  
**Duration:** 1 week  
**Dependencies:** Phase 2A complete

### 7.1 Overview

Global rankings by various metrics, creating competition and social proof.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           LEADERBOARD CONCEPT                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  RANKING CATEGORIES:                                                         │
│  ├── Ghost Streak:    Longest current survival streak                       │
│  ├── Total Extracted: All-time gains extracted                              │
│  ├── Risk Score:      Composite of level × streak × TVL                    │
│  ├── Crew Rankings:   Crew TVL and weekly performance                       │
│  └── Dead Pool:       Most accurate predictions                             │
│                                                                              │
│  TIME PERIODS:                                                               │
│  ├── All Time                                                                │
│  ├── This Week                                                               │
│  └── Today                                                                   │
│                                                                              │
│  REWARDS:                                                                    │
│  ├── Top 10: Special badge                                                  │
│  ├── Top 100: Leaderboard visibility                                        │
│  └── Weekly rewards for top performers (optional Phase 3)                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Type Definitions

```typescript
// lib/core/types/leaderboard.ts

export type LeaderboardCategory = 
  | 'ghost_streak'
  | 'total_extracted'
  | 'risk_score'
  | 'crew_tvl'
  | 'deadpool_accuracy';

export type LeaderboardPeriod = 'all_time' | 'weekly' | 'daily';

export interface LeaderboardEntry {
  rank: number;
  address: `0x${string}`;
  ensName?: string;
  value: bigint | number;
  previousRank?: number;  // For showing movement
  isYou: boolean;
  badges: LeaderboardBadge[];
}

export interface LeaderboardBadge {
  id: string;
  name: string;
  icon: string;
  description: string;
}

export interface CrewLeaderboardEntry {
  rank: number;
  crew: {
    id: string;
    name: string;
    tag: string;
    memberCount: number;
  };
  value: bigint;
  previousRank?: number;
  isYourCrew: boolean;
}

export interface LeaderboardData {
  category: LeaderboardCategory;
  period: LeaderboardPeriod;
  entries: LeaderboardEntry[];
  yourRank?: number;
  totalParticipants: number;
  lastUpdated: number;
}
```

### 7.3 UI Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ GHOSTNET v1.0.7 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ [👤] [⚙]      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ RANKINGS                                                                ││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │                                                                         ││
│  │  [STREAK] [EXTRACTED] [RISK] [CREWS] [PREDICTIONS]                     ││
│  │  ────────                                                               ││
│  │                                                                         ││
│  │  [ALL TIME]  [WEEKLY]  [DAILY]                                         ││
│  │                                                                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ GHOST STREAK - ALL TIME                          1,247 operators       ││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │                                                                         ││
│  │  RANK  OPERATOR              STREAK     LEVEL        CHANGE            ││
│  │  ────  ────────              ──────     ─────        ──────            ││
│  │                                                                         ││
│  │  #1    0x7a3f...9c2d  🏆    47 🔥      BLACK_ICE     ─                 ││
│  │  #2    0x9c2d...3b1a  🥈    42 🔥      DARKNET      ▲ +2               ││
│  │  #3    0x3b1a...8f2e  🥉    38 🔥      BLACK_ICE    ▼ -1               ││
│  │  #4    0x8f2e...1d4c        35 🔥      DARKNET       ─                 ││
│  │  #5    0x1d4c...5e7b        33 🔥      DARKNET      ▲ +3               ││
│  │  #6    0x5e7b...2a9f        31 🔥      SUBNET        ─                 ││
│  │  #7    0x2a9f...6c3d        29 🔥      DARKNET      ▼ -2               ││
│  │  #8    0x6c3d...4b8e        28 🔥      DARKNET       ─                 ││
│  │  #9    0x4b8e...7a3f        27 🔥      SUBNET       ▲ +5               ││
│  │  #10   0xa1b2...c3d4        26 🔥      DARKNET       ─                 ││
│  │                                                                         ││
│  │  ...                                                                    ││
│  │                                                                         ││
│  │  #127  0x7a3f (YOU)  ⬤     7 🔥       DARKNET      ▲ +12              ││
│  │                                                                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ YOUR STATS                                                              ││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │ Streak Rank: #127/1,247  |  Extracted Rank: #89/1,247  |  Risk: #203   ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│ [NETWORK] [POSITION] [GAMES] [CREW] [MARKET] [■RANKS] [?]                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.4 Implementation Checklist

```
PHASE 2E: LEADERBOARD
═══════════════════════════════════════════════════════════════════════════

□ 7.4.1 Type Definitions
  □ Create lib/core/types/leaderboard.ts
  □ LeaderboardCategory type
  □ LeaderboardPeriod type
  □ LeaderboardEntry interface
  □ CrewLeaderboardEntry interface
  □ LeaderboardData interface

□ 7.4.2 Provider Extensions
  □ Add getLeaderboard() method
  □ Add getYourRank() method
  □ Add caching for leaderboard data

□ 7.4.3 Mock Provider
  □ Generate mock leaderboard entries
  □ Include "you" in appropriate position
  □ Simulate rank changes

□ 7.4.4 Page & Layout
  □ Create routes/leaderboard/+page.svelte
  □ Create responsive layout

□ 7.4.5 Components
  □ LeaderboardHeader.svelte
  □ CategoryTabs.svelte
  □ PeriodTabs.svelte
  □ LeaderboardTable.svelte
  □ LeaderboardRow.svelte
  □ YourRankRow.svelte (highlighted)
  □ YourStatsPanel.svelte
  □ RankBadge.svelte

□ 7.4.6 Polish
  □ Rank change animations
  □ Top 3 special styling
  □ "Your position" highlight
  □ Loading states

□ 7.4.7 Testing
  □ Component tests
  □ Responsive testing

ACCEPTANCE CRITERIA:
□ Can view all categories
□ Can filter by time period
□ See own rank highlighted
□ Rank changes show movement
□ Top 3 have special styling
□ Data loads efficiently
□ Responsive on all breakpoints
```

---

## 9. Phase 2F: Daily Operations

> **Status:** ❌ NOT STARTED
> 
> **Missing Files:**
> - `lib/core/types/daily.ts`
> - `lib/core/providers/mock/generators/daily.ts`
> - `lib/features/daily/*` components
> - Integration into main page or modal

**Priority:** Low  
**Duration:** 1 week  
**Dependencies:** Phase 2A complete

### 8.1 Overview

Daily login rewards and streak bonuses to encourage consistent engagement.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DAILY OPS CONCEPT                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  DAILY CHECK-IN:                                                             │
│  ├── Day 1: +2% death rate reduction (24h)                                  │
│  ├── Day 2: +3% death rate reduction (24h)                                  │
│  ├── Day 3: +4% death rate reduction (24h)                                  │
│  ├── Day 4: +5% death rate reduction (24h)                                  │
│  ├── Day 5: +5% yield multiplier (24h)                                      │
│  ├── Day 6: +7% death rate reduction (24h)                                  │
│  └── Day 7: +10% death rate reduction + 50 $DATA bonus                      │
│                                                                              │
│  RESET: Miss a day = restart from Day 1                                     │
│                                                                              │
│  BONUS MISSIONS (random daily):                                              │
│  ├── "Survive a trace scan"      → +5% bonus                                │
│  ├── "Complete 3 typing games"   → +25 $DATA                                │
│  ├── "Win a Dead Pool bet"       → +10% yield (4h)                          │
│  └── "Refer a friend who jacks in" → +50 $DATA                              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.2 Type Definitions

```typescript
// lib/core/types/daily.ts

export interface DailyProgress {
  currentStreak: number;
  maxStreak: number;
  lastCheckIn: number | null;  // timestamp
  todayCheckedIn: boolean;
  nextReward: DailyReward;
  weekProgress: boolean[];  // [true, true, false, ...]
}

export interface DailyReward {
  day: number;
  type: 'death_rate' | 'yield' | 'bonus_tokens';
  value: number;
  description: string;
}

export interface DailyMission {
  id: string;
  title: string;
  description: string;
  progress: number;  // 0-1
  target: number;
  reward: {
    type: 'death_rate' | 'yield' | 'tokens';
    value: number;
    duration?: number;  // ms
  };
  expiresAt: number;
  completed: boolean;
  claimed: boolean;
}

export const DAILY_REWARDS: DailyReward[] = [
  { day: 1, type: 'death_rate', value: -0.02, description: '-2% death rate (24h)' },
  { day: 2, type: 'death_rate', value: -0.03, description: '-3% death rate (24h)' },
  { day: 3, type: 'death_rate', value: -0.04, description: '-4% death rate (24h)' },
  { day: 4, type: 'death_rate', value: -0.05, description: '-5% death rate (24h)' },
  { day: 5, type: 'yield', value: 0.05, description: '+5% yield (24h)' },
  { day: 6, type: 'death_rate', value: -0.07, description: '-7% death rate (24h)' },
  { day: 7, type: 'bonus_tokens', value: 50, description: '-10% death rate + 50 $DATA' },
];
```

### 8.3 UI Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ DAILY OPS                                           STREAK: 5 DAYS 🔥  ││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │                                                                         ││
│  │  CHECK-IN PROGRESS                                                      ││
│  │                                                                         ││
│  │  [✓]──[✓]──[✓]──[✓]──[✓]──[ ]──[★]                                    ││
│  │   1    2    3    4    5    6    7                                      ││
│  │  -2%  -3%  -4%  -5%  +5%  -7%  BONUS                                   ││
│  │                                                                         ││
│  │  TODAY'S REWARD: -5% death rate (24h)                                  ││
│  │                                                                         ││
│  │  [CLAIM DAILY REWARD]  ← Available!                                    ││
│  │                                                                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ TODAY'S MISSIONS                                                        ││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │                                                                         ││
│  │  □ SURVIVOR                                               0/1          ││
│  │    Survive a trace scan today                                          ││
│  │    Reward: +5% death rate reduction (4h)                               ││
│  │                                                                         ││
│  │  ■ SPEED DEMON                                            2/3          ││
│  │    Complete 3 typing games                   ████████░░░░              ││
│  │    Reward: +25 $DATA                                                   ││
│  │                                                                         ││
│  │  ✓ ORACLE  [CLAIM]                                        1/1          ││
│  │    Win a Dead Pool bet                       ████████████              ││
│  │    Reward: +10% yield (4h)                                             ││
│  │                                                                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.4 Implementation Checklist

```
PHASE 2F: DAILY OPERATIONS
═══════════════════════════════════════════════════════════════════════════

□ 8.4.1 Type Definitions
  □ Create lib/core/types/daily.ts
  □ DailyProgress interface
  □ DailyReward interface
  □ DailyMission interface
  □ DAILY_REWARDS constant

□ 8.4.2 Provider Extensions
  □ Add dailyProgress getter
  □ Add dailyMissions getter
  □ Add claimDailyReward() method
  □ Add claimMissionReward() method

□ 8.4.3 Mock Provider
  □ Generate daily progress
  □ Generate random missions
  □ Track mission progress

□ 8.4.4 Components
  □ DailyOpsPanel.svelte
  □ StreakProgress.svelte
  □ DayMarker.svelte
  □ ClaimButton.svelte
  □ MissionsList.svelte
  □ MissionCard.svelte
  □ MissionProgress.svelte

□ 8.4.5 Integration
  □ Add to main page (or modal)
  □ Update modifiers on claim
  □ Notification for available rewards

□ 8.4.6 Testing
  □ Unit tests for reward logic
  □ Component tests

ACCEPTANCE CRITERIA:
□ Shows current streak
□ Shows week progress
□ Can claim daily reward
□ Missions track correctly
□ Can claim mission rewards
□ Modifiers apply correctly
□ Streak resets on miss
```

---

## 10. Phase 2G: Consumables & Black Market

> **Status:** ❌ NOT STARTED
> 
> **Missing Files:**
> - `lib/core/types/market.ts`
> - `lib/core/providers/mock/generators/market.ts`
> - `lib/features/market/*` components (ConsumableCard, InventoryPanel, etc.)
> - Integration into `/market` page alongside Dead Pool

**Priority:** Low  
**Duration:** 1 week  
**Dependencies:** Phase 2A, 2B complete

### 9.1 Overview

Purchasable items that provide temporary boosts (all purchases are burned).

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           BLACK MARKET CONCEPT                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  CONSUMABLES:                                                                │
│  ├── Stimpack (50Đ):        +25% yield for 4 hours                         │
│  ├── EMP Jammer (100Đ):     Pause your scan timer for 1 hour               │
│  ├── Ghost Protocol (200Đ): Skip one trace scan completely                 │
│  ├── Exploit Kit (75Đ):     Unlock shortcut paths in Hack Runs             │
│  └── ICE Breaker (150Đ):    -10% death rate for 24 hours                   │
│                                                                              │
│  MECHANICS:                                                                  │
│  ├── All purchases burned (deflationary)                                    │
│  ├── Items have cooldowns                                                   │
│  ├── Some items require minimum level                                       │
│  └── Bulk discounts available                                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 9.2 Type Definitions

```typescript
// lib/core/types/market.ts

export interface Consumable {
  id: string;
  name: string;
  description: string;
  price: bigint;
  effect: ConsumableEffect;
  cooldown: number;  // ms until can use again
  minLevel?: Level;  // Minimum level to purchase
  maxStack?: number; // Max you can hold
  icon: string;
}

export type ConsumableEffect = 
  | { type: 'yield_boost'; value: number; duration: number }
  | { type: 'timer_pause'; duration: number }
  | { type: 'skip_scan'; scans: number }
  | { type: 'death_rate'; value: number; duration: number }
  | { type: 'hackrun_unlock'; feature: string };

export interface OwnedConsumable {
  consumableId: string;
  quantity: number;
  lastUsed: number | null;
  cooldownEnds: number | null;
}

export const CONSUMABLES: Consumable[] = [
  {
    id: 'stimpack',
    name: 'Stimpack',
    description: '+25% yield for 4 hours',
    price: 50n * 10n ** 18n,
    effect: { type: 'yield_boost', value: 0.25, duration: 4 * 60 * 60 * 1000 },
    cooldown: 8 * 60 * 60 * 1000,
    icon: '💉'
  },
  {
    id: 'emp_jammer',
    name: 'EMP Jammer',
    description: 'Pause your scan timer for 1 hour',
    price: 100n * 10n ** 18n,
    effect: { type: 'timer_pause', duration: 60 * 60 * 1000 },
    cooldown: 24 * 60 * 60 * 1000,
    minLevel: 'SUBNET',
    icon: '📡'
  },
  {
    id: 'ghost_protocol',
    name: 'Ghost Protocol',
    description: 'Skip one trace scan completely',
    price: 200n * 10n ** 18n,
    effect: { type: 'skip_scan', scans: 1 },
    cooldown: 48 * 60 * 60 * 1000,
    minLevel: 'DARKNET',
    icon: '👻'
  },
  {
    id: 'exploit_kit',
    name: 'Exploit Kit',
    description: 'Unlock shortcut paths in Hack Runs',
    price: 75n * 10n ** 18n,
    effect: { type: 'hackrun_unlock', feature: 'shortcuts' },
    cooldown: 0,
    maxStack: 5,
    icon: '🔓'
  },
  {
    id: 'ice_breaker',
    name: 'ICE Breaker',
    description: '-10% death rate for 24 hours',
    price: 150n * 10n ** 18n,
    effect: { type: 'death_rate', value: -0.10, duration: 24 * 60 * 60 * 1000 },
    cooldown: 48 * 60 * 60 * 1000,
    icon: '🧊'
  }
];
```

### 9.3 Implementation Checklist

```
PHASE 2G: CONSUMABLES & BLACK MARKET
═══════════════════════════════════════════════════════════════════════════

□ 9.3.1 Type Definitions
  □ Create lib/core/types/market.ts
  □ Consumable interface
  □ ConsumableEffect union
  □ OwnedConsumable interface
  □ CONSUMABLES constant

□ 9.3.2 Provider Extensions
  □ Add ownedConsumables getter
  □ Add purchaseConsumable() method
  □ Add useConsumable() method

□ 9.3.3 Mock Provider
  □ Track owned consumables
  □ Apply effects to modifiers

□ 9.3.4 Components
  □ MarketPanel.svelte
  □ ConsumableCard.svelte
  □ InventoryPanel.svelte
  □ InventoryItem.svelte
  □ PurchaseModal.svelte
  □ UseConfirmModal.svelte

□ 9.3.5 Integration
  □ Add to /market page (Dead Pool page)
  □ Show in modifiers panel when active
  □ Cooldown displays

□ 9.3.6 Testing
  □ Unit tests for effect application
  □ Component tests

ACCEPTANCE CRITERIA:
□ Can view available items
□ Can purchase items (mock)
□ Can view inventory
□ Can use items
□ Effects apply correctly
□ Cooldowns work
□ Min level requirements work
```

---

## 11. Phase 2H: Help & Onboarding

> **Status:** ✅ COMPLETE (Core Implementation)
> 
> **Implemented Files:**
> - `routes/help/+page.svelte` (370+ lines) - Full help page with 7 sections
> 
> **Future Enhancements (Optional):**
> - Contextual tooltip components
> - First-time hints system

**Priority:** Medium  
**Duration:** 1 week  
**Dependencies:** Phase 2A complete

### 10.1 Overview

Tutorial system and help documentation to explain the game.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           HELP SYSTEM CONCEPT                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  SECTIONS:                                                                   │
│  ├── Getting Started                                                        │
│  │   ├── What is GHOSTNET?                                                  │
│  │   ├── How to Jack In                                                     │
│  │   └── Understanding Trace Scans                                          │
│  ├── Security Levels                                                        │
│  │   ├── Level Overview                                                     │
│  │   └── Choosing Your Level                                                │
│  ├── Mini-Games                                                             │
│  │   ├── Trace Evasion (Typing)                                             │
│  │   ├── Hack Runs                                                          │
│  │   └── Dead Pool                                                          │
│  ├── Social Features                                                        │
│  │   ├── Crews                                                              │
│  │   └── Leaderboards                                                       │
│  ├── Tokenomics                                                             │
│  │   ├── $DATA Token                                                        │
│  │   └── Burn Mechanics                                                     │
│  └── FAQ                                                                    │
│                                                                              │
│  CONTEXTUAL HELP:                                                            │
│  ├── Tooltip on hover (desktop)                                             │
│  ├── Info icons with popovers                                               │
│  └── First-time hints for new features                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 10.2 Implementation Checklist

```
PHASE 2H: HELP & ONBOARDING
═══════════════════════════════════════════════════════════════════════════

□ 10.2.1 Help Content
  □ Write Getting Started guide
  □ Write Security Levels guide
  □ Write Mini-Games guides
  □ Write Social Features guides
  □ Write Tokenomics guide
  □ Write FAQ

□ 10.2.2 Page & Layout
  □ Create routes/help/+page.svelte
  □ Create section navigation
  □ Create content renderer

□ 10.2.3 Components
  □ HelpNavigation.svelte
  □ HelpSection.svelte
  □ HelpContent.svelte
  □ SearchBar.svelte (optional)

□ 10.2.4 Contextual Help
  □ Create Tooltip.svelte component
  □ Create InfoIcon.svelte component
  □ Add tooltips to key UI elements

□ 10.2.5 First-Time Hints
  □ Create hint tracking system
  □ Create HintOverlay.svelte
  □ Add hints for new features

□ 10.2.6 Testing
  □ Content review
  □ Navigation testing
  □ Mobile usability

ACCEPTANCE CRITERIA:
□ Can navigate all help sections
□ Content is clear and helpful
□ Tooltips work on desktop
□ Info icons work on mobile
□ First-time hints show once
□ Responsive on all breakpoints
```

---

## 12. Phase 2I: PvP Duels

> **Status:** ❌ NOT STARTED
> 
> **Missing Files:**
> - `lib/core/types/duel.ts`
> - `lib/core/providers/mock/generators/duel.ts`
> - `routes/games/duels/+page.svelte`
> - `lib/features/duels/*` components

**Priority:** Low  
**Duration:** 2 weeks  
**Dependencies:** Phase 2A, 2C complete

### 11.1 Overview

Head-to-head competitive typing matches for wagered $DATA.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PVP DUELS CONCEPT                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  MECHANICS:                                                                  │
│  ├── Challenge another player to a typing duel                              │
│  ├── Both players wager same amount                                         │
│  ├── Same typing challenge, race to complete                                │
│  ├── Winner takes pot (minus 5% rake burned)                                │
│  └── Can spectate ongoing duels                                             │
│                                                                              │
│  WAGER TIERS:                                                                │
│  ├── Quick Draw:   10-50 $DATA                                              │
│  ├── Showdown:     50-200 $DATA                                             │
│  └── High Noon:    200+ $DATA                                               │
│                                                                              │
│  MATCHMAKING:                                                                │
│  ├── Challenge specific player                                              │
│  ├── Open challenge (anyone can accept)                                     │
│  └── Quick match (random opponent)                                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 11.2 Type Definitions

```typescript
// lib/core/types/duel.ts

export type DuelStatus = 
  | 'open'        // Waiting for opponent
  | 'accepted'    // Opponent joined, countdown
  | 'active'      // Typing in progress
  | 'complete'    // Winner determined
  | 'cancelled'   // Expired or cancelled
  | 'declined';   // Opponent declined

export interface Duel {
  id: string;
  challenger: `0x${string}`;
  opponent: `0x${string}` | null;
  wagerAmount: bigint;
  tier: 'quick_draw' | 'showdown' | 'high_noon';
  status: DuelStatus;
  challenge: TypingChallenge;
  results: {
    challenger?: DuelResult;
    opponent?: DuelResult;
  };
  winner: `0x${string}` | null;
  createdAt: number;
  expiresAt: number;
  spectatorCount: number;
}

export interface DuelResult {
  completed: boolean;
  accuracy: number;
  wpm: number;
  timeElapsed: number;
  finishTime: number;
}

export interface DuelChallenge {
  targetAddress?: `0x${string}`;  // null = open challenge
  wagerAmount: bigint;
}
```

### 11.3 Implementation Checklist

```
PHASE 2I: PVP DUELS
═══════════════════════════════════════════════════════════════════════════

□ 11.3.1 Type Definitions
  □ Create lib/core/types/duel.ts
  □ DuelStatus type
  □ Duel interface
  □ DuelResult interface
  □ DuelChallenge interface

□ 11.3.2 Provider Extensions
  □ Add activeDuels getter
  □ Add openChallenges getter
  □ Add createDuel() method
  □ Add acceptDuel() method
  □ Add cancelDuel() method
  □ Add submitDuelResult() method
  □ Add subscribeDuel() method

□ 11.3.3 Mock Provider
  □ Generate mock duels
  □ Simulate opponent typing

□ 11.3.4 Page & Layout
  □ Create routes/games/duels/+page.svelte
  □ Create responsive layout

□ 11.3.5 Components - Lobby
  □ DuelsLobby.svelte
  □ OpenChallenges.svelte
  □ ChallengeCard.svelte
  □ CreateDuelModal.svelte

□ 11.3.6 Components - Active Duel
  □ ActiveDuel.svelte
  □ DuelProgress.svelte
  □ OpponentStatus.svelte
  □ DuelTypingArea.svelte

□ 11.3.7 Components - Results
  □ DuelResults.svelte
  □ WinnerAnnouncement.svelte

□ 11.3.8 Integration
  □ Add to games menu
  □ Feed events for duel results
  □ Audio for duel events

□ 11.3.9 Testing
  □ Unit tests for result calculation
  □ Component tests
  □ E2E test for duel flow

ACCEPTANCE CRITERIA:
□ Can create open challenge
□ Can challenge specific player
□ Can accept challenge
□ Duel typing works
□ Winner determined correctly
□ Pot distributed correctly
□ Rake burned correctly
□ Can spectate (future)
□ Feed shows duel results
□ Audio plays on events
```

---

## 13. Technical Infrastructure

### 12.1 Provider Architecture Evolution

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PROVIDER ARCHITECTURE - PHASE 2                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  lib/core/providers/                                                         │
│  ├── types.ts                    # DataProvider interface                    │
│  ├── mock/                                                                   │
│  │   ├── provider.svelte.ts      # Mock implementation                       │
│  │   ├── generators/                                                         │
│  │   │   ├── feed.ts                                                        │
│  │   │   ├── network.ts                                                     │
│  │   │   ├── position.ts                                                    │
│  │   │   ├── deadpool.ts         # NEW                                      │
│  │   │   ├── hackrun.ts          # NEW                                      │
│  │   │   ├── crew.ts             # NEW                                      │
│  │   │   ├── leaderboard.ts      # NEW                                      │
│  │   │   ├── daily.ts            # NEW                                      │
│  │   │   ├── market.ts           # NEW                                      │
│  │   │   └── duel.ts             # NEW                                      │
│  │   └── data/                                                              │
│  │       └── commands.ts                                                    │
│  └── web3/                       # FUTURE: Real Web3 provider               │
│      └── provider.svelte.ts                                                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 12.2 Extended DataProvider Interface

```typescript
// lib/core/providers/types.ts - Full interface for Phase 2

export interface DataProvider {
  // ════════════════════════════════════════════════════════════════
  // CONNECTION
  // ════════════════════════════════════════════════════════════════
  connect(): Promise<void>;
  disconnect(): void;
  readonly connectionStatus: ConnectionStatus;

  // ════════════════════════════════════════════════════════════════
  // USER & WALLET
  // ════════════════════════════════════════════════════════════════
  readonly currentUser: User | null;
  connectWallet(): Promise<void>;
  disconnectWallet(): void;

  // ════════════════════════════════════════════════════════════════
  // POSITION
  // ════════════════════════════════════════════════════════════════
  readonly position: Position | null;
  readonly modifiers: Modifier[];
  jackIn(level: Level, amount: bigint): Promise<string>;
  extract(): Promise<string>;

  // ════════════════════════════════════════════════════════════════
  // NETWORK
  // ════════════════════════════════════════════════════════════════
  readonly networkState: NetworkState;
  getLevelStats(level: Level): LevelStats;

  // ════════════════════════════════════════════════════════════════
  // FEED
  // ════════════════════════════════════════════════════════════════
  readonly feedEvents: FeedEvent[];
  subscribeFeed(callback: (event: FeedEvent) => void): () => void;

  // ════════════════════════════════════════════════════════════════
  // TYPING (Trace Evasion)
  // ════════════════════════════════════════════════════════════════
  getTypingChallenge(): TypingChallenge;
  submitTypingResult(result: TypingResult): Promise<void>;

  // ════════════════════════════════════════════════════════════════
  // DEAD POOL (Phase 2B)
  // ════════════════════════════════════════════════════════════════
  readonly activeRounds: DeadPoolRound[];
  readonly deadPoolHistory: DeadPoolHistory[];
  placeBet(roundId: string, side: 'under' | 'over', amount: bigint): Promise<string>;
  subscribeDeadPool(callback: (update: DeadPoolUpdate) => void): () => void;

  // ════════════════════════════════════════════════════════════════
  // HACK RUNS (Phase 2C)
  // ════════════════════════════════════════════════════════════════
  readonly availableHackRuns: HackRun[];
  readonly hackRunHistory: HackRunResult[];
  startHackRun(runId: string): Promise<void>;
  submitHackRunNode(nodeResult: NodeResult): Promise<void>;
  abortHackRun(): Promise<void>;

  // ════════════════════════════════════════════════════════════════
  // CREW (Phase 2D)
  // ════════════════════════════════════════════════════════════════
  readonly crew: Crew | null;
  readonly crewInvites: CrewInvite[];
  createCrew(name: string, tag: string, description: string, isPublic: boolean): Promise<string>;
  joinCrew(crewId: string): Promise<void>;
  leaveCrew(): Promise<void>;
  inviteToCrew(address: `0x${string}`): Promise<void>;
  kickFromCrew(address: `0x${string}`): Promise<void>;
  subscribeCrewActivity(callback: (event: CrewActivityEvent) => void): () => void;

  // ════════════════════════════════════════════════════════════════
  // LEADERBOARD (Phase 2E)
  // ════════════════════════════════════════════════════════════════
  getLeaderboard(category: LeaderboardCategory, period: LeaderboardPeriod): Promise<LeaderboardData>;

  // ════════════════════════════════════════════════════════════════
  // DAILY OPS (Phase 2F)
  // ════════════════════════════════════════════════════════════════
  readonly dailyProgress: DailyProgress;
  readonly dailyMissions: DailyMission[];
  claimDailyReward(): Promise<void>;
  claimMissionReward(missionId: string): Promise<void>;

  // ════════════════════════════════════════════════════════════════
  // CONSUMABLES (Phase 2G)
  // ════════════════════════════════════════════════════════════════
  readonly ownedConsumables: OwnedConsumable[];
  purchaseConsumable(consumableId: string, quantity: number): Promise<string>;
  useConsumable(consumableId: string): Promise<void>;

  // ════════════════════════════════════════════════════════════════
  // PVP DUELS (Phase 2I)
  // ════════════════════════════════════════════════════════════════
  readonly activeDuels: Duel[];
  readonly openChallenges: Duel[];
  createDuel(challenge: DuelChallenge): Promise<string>;
  acceptDuel(duelId: string): Promise<void>;
  cancelDuel(duelId: string): Promise<void>;
  submitDuelResult(duelId: string, result: DuelResult): Promise<void>;
  subscribeDuel(duelId: string, callback: (update: DuelUpdate) => void): () => void;
}
```

### 12.3 Route Structure

```
routes/
├── +layout.svelte              # Shell, provider, toasts
├── +page.svelte                # Command Center (main)
├── typing/+page.svelte         # Trace Evasion
├── games/
│   ├── +page.svelte            # Games hub (links to sub-games)
│   ├── hackrun/+page.svelte    # Hack Runs (Phase 2C)
│   └── duels/+page.svelte      # PvP Duels (Phase 2I)
├── market/+page.svelte         # Dead Pool + Consumables (Phase 2B, 2G)
├── crew/+page.svelte           # Crew system (Phase 2D)
├── leaderboard/+page.svelte    # Rankings (Phase 2E)
└── help/+page.svelte           # Help & docs (Phase 2H)
```

### 12.4 Testing Strategy

```
TESTING REQUIREMENTS
═══════════════════════════════════════════════════════════════════════════

UNIT TESTS (Vitest):
├── All utility functions
├── State machine logic (typing, hackrun, duel)
├── Calculation functions (odds, payouts, XP)
├── Provider generators

COMPONENT TESTS (Vitest + Testing Library):
├── All interactive components
├── State transitions
├── User interactions

E2E TESTS (Playwright):
├── Critical user flows:
│   ├── Jack In flow
│   ├── Typing game completion
│   ├── Hack Run completion
│   ├── Dead Pool bet placement
│   ├── Crew creation/joining
│   └── Duel completion
├── Navigation tests
├── Responsive layout tests

COVERAGE TARGETS:
├── Unit tests: 80%+
├── Component tests: 70%+
├── E2E: Critical paths covered
```

---

## 14. Implementation Schedule

### 13.1 Recommended Sequence

```
PHASE 2 TIMELINE (10-14 weeks)
═══════════════════════════════════════════════════════════════════════════

Week 1-2:   Phase 2A - MVP Completion
            ├── Visual style migration
            ├── Responsive design
            ├── Error handling
            └── Navigation updates

Week 3-4:   Phase 2B - Dead Pool
            ├── Types & provider
            ├── UI components
            └── Integration

Week 5-7:   Phase 2C - Hack Runs
            ├── Game logic
            ├── Node system
            ├── UI components
            └── Integration

Week 8-9:   Phase 2D - Crew System
            ├── Types & provider
            ├── UI components
            └── Bonus system

Week 10:    Phase 2E - Leaderboard
            └── Full implementation

Week 11:    Phase 2F + 2H - Daily Ops + Help
            └── Both in parallel

Week 12:    Phase 2G - Consumables
            └── Market integration

Week 13-14: Phase 2I - PvP Duels
            └── Full implementation

PARALLELIZATION OPPORTUNITIES:
├── 2B and 2E can overlap (different pages)
├── 2F, 2G, 2H can run in parallel (low complexity)
├── 2C and 2D should be sequential (shared typing)
├── 2I depends on 2C completion
```

### 13.2 Milestone Checkpoints

```
MILESTONE 1: Visual Refresh (End of Week 2)
├── New color scheme live
├── Responsive layouts working
├── Error handling in place
├── Navigation complete with "Coming Soon"

MILESTONE 2: Prediction Market (End of Week 4)
├── Dead Pool fully functional
├── Can place bets
├── Results display

MILESTONE 3: Second Mini-Game (End of Week 7)
├── Hack Runs fully functional
├── All node types working
├── Rewards applied correctly

MILESTONE 4: Social Features (End of Week 9)
├── Crew system functional
├── Leaderboard working

MILESTONE 5: Full Feature Complete (End of Week 14)
├── All features implemented
├── All tests passing
├── Performance verified
├── Ready for Web3 provider integration
```

---

## 15. Appendix: Type Definitions

All type definitions are provided inline in their respective sections. For a consolidated view, create these files:

```
lib/core/types/
├── index.ts         # Core types (existing)
├── hackrun.ts       # Hack Run types (Section 5.2)
├── leaderboard.ts   # Leaderboard types (Section 7.2)
├── daily.ts         # Daily Ops types (Section 8.2)
├── market.ts        # Consumable types (Section 9.2)
└── duel.ts          # PvP Duel types (Section 11.2)
```

---

## 16. Next Steps & Action Items

### Immediate (Quick Wins)

1. **Update NavigationBar.svelte** - Remove `comingSoon: true` from CREW, MARKET, RANKS
   ```typescript
   // Change from:
   { id: 'crew', label: 'CREW', comingSoon: true }
   // To:
   { id: 'crew', label: 'CREW', href: '/crew' }
   ```

2. **Wire up Main Page Quick Actions** - Update handlers in `+page.svelte`:
   ```typescript
   // Change from:
   handleHackRun() { toast.info('Hack Run coming soon...'); }
   // To:
   handleHackRun() { goto('/games/hackrun'); }
   ```

### Short Term (1-2 weeks)

3. **Implement Phase 2F: Daily Operations**
   - Create `lib/core/types/daily.ts`
   - Create `lib/core/providers/mock/generators/daily.ts`
   - Create daily ops components
   - Integrate into main page or dedicated modal

4. **Implement Phase 2H: Help System**
   - Create `routes/help/+page.svelte`
   - Write help content
   - Add contextual tooltips to key UI elements

### Medium Term (2-4 weeks)

5. **Implement Phase 2G: Consumables**
   - Create types, generators, and components
   - Integrate into `/market` page

6. **Implement Phase 2I: PvP Duels**
   - Create full duel system
   - Build matchmaking UI

### Technical Debt

7. **Provider Architecture** - Consider integrating mock generators into main provider interface for consistency

8. **Subsection Numbering** - Some subsection numbers in this document are inconsistent with parent sections (cosmetic issue)

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-20 | GHOSTNET Team | Initial Phase 2 plan |
| 1.1 | 2026-01-21 | Claude | Added Implementation Status section; marked completed phases (2A-2E); identified missing phases (2F-2I); added Next Steps |

---

*End of Phase 2 Implementation Plan*
