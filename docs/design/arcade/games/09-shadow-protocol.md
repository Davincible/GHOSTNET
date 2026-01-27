# SHADOW PROTOCOL

## Game Design Document

**Category:** Meta-Game (Stealth Mechanic)  
**Phase:** 3C (Deep Engagement)  
**Complexity:** High  
**Development Time:** 3 weeks  

---

## Overview

SHADOW PROTOCOL is a meta-game that fundamentally changes how players interact with GHOSTNET's core survival mechanics. Players can enter "Shadow Mode" to become invisible to trace scans—but they become targets for bounty hunters who can detect and expose them for massive rewards.

It creates a cat-and-mouse dynamic: shadows hiding in plain sight, hunters analyzing patterns to expose them.

```
╔══════════════════════════════════════════════════════════════════╗
║                      SHADOW PROTOCOL                              ║
║                  ░░░ STEALTH ACTIVE ░░░                           ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  ┌──────────────────────────────────────────────────────────┐    ║
║  │                                                           │    ║
║  │       ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓      │    ║
║  │       ▓                                           ▓      │    ║
║  │       ▓    Y O U   A R E   I N V I S I B L E     ▓      │    ║
║  │       ▓                                           ▓      │    ║
║  │       ▓   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    ▓      │    ║
║  │       ▓   ░  SHADOW DURATION: 03:42:18       ░    ▓      │    ║
║  │       ▓   ░  TRACE IMMUNITY: ACTIVE          ░    ▓      │    ║
║  │       ▓   ░  DETECTION RISK: ████░░░░░░ 38%  ░    ▓      │    ║
║  │       ▓   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    ▓      │    ║
║  │       ▓                                           ▓      │    ║
║  │       ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓      │    ║
║  │                                                           │    ║
║  └──────────────────────────────────────────────────────────┘    ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  ACTIVE HUNTERS: 12          YOUR BOUNTY: 400 $DATA              ║
║  SCANS EVADED: 3             NEXT SCAN: 00:17:42                 ║
║                                                                   ║
║              [ EXTEND SHADOW ]         [ EXTRACT NOW ]            ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Core Mechanics

### The Shadow/Hunter Dynamic

```
┌─────────────────────────────────────────────────────────────────┐
│                    THE SHADOW PROTOCOL                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   SHADOWS                          HUNTERS                      │
│   ───────                          ───────                      │
│   • Pay 200 $DATA to go dark       • Free to hunt               │
│   • Invisible to trace scans       • See detection mini-game    │
│   • Hidden from live feed          • Earn bounties on detection │
│   • Risk: 2x loss if detected      • Cooldown between attempts  │
│   • Max duration: 4 hours          • Pattern analysis tools     │
│                                                                 │
│                         ┌─────────┐                             │
│      SHADOW             │DETECTION│            HUNTER           │
│      ░░░░░░░ ──────────>│  GAME   │<────────── ○○○○○○○          │
│                         └─────────┘                             │
│                              │                                  │
│                    ┌─────────┴─────────┐                        │
│                    ▼                   ▼                        │
│              ╔═══════════╗       ╔═══════════╗                  │
│              ║  EVADED   ║       ║  EXPOSED  ║                  │
│              ║  Shadow   ║       ║  Shadow   ║                  │
│              ║  survives ║       ║  loses 2x ║                  │
│              ╚═══════════╝       ╚═══════════╝                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Game Flow

```
SHADOW FLOW:
═══════════════════════════════════════════════════════════════════

1. ACTIVATE SHADOW (200 $DATA burned)
   └── Position hidden from feed
   └── Immune to trace scans
   └── Bounty pool initialized (200 $DATA)

2. SHADOW DURATION (max 4 hours)
   └── Each evaded scan adds to bounty
   └── Detection risk increases over time
   └── Can extend with additional $DATA

3. RESOLUTION
   ├── EXPOSED: Lose staked position (2x normal loss)
   │            └── Bounty goes to hunter
   │            └── Feed announces exposure
   │
   └── CLEAN EXIT: Return to visible
                   └── Keep position
                   └── No rewards (safety cost)

HUNTER FLOW:
═══════════════════════════════════════════════════════════════════

1. VIEW SHADOW COUNT
   └── See how many active shadows exist
   └── No identifying information visible

2. INITIATE DETECTION (free, but cooldown)
   └── Pattern analysis mini-game
   └── Behavioral correlation puzzle
   └── Timing analysis challenge

3. RESOLUTION
   ├── MISS: 10 minute cooldown
   │         └── Shadow's detection risk decreases
   │
   └── HIT: Claim bounty
            └── Shadow exposed and loses 2x
            └── Hunter earns bounty pool
```

### Detection Mini-Game

Hunters don't simply guess—they play a skill-based detection game that analyzes on-chain patterns.

```
DETECTION GAME PHASES:
═══════════════════════════════════════════════════════════════════

PHASE 1: PATTERN ANALYSIS (15 seconds)
─────────────────────────────────────
Identify anomalous transaction patterns that suggest shadow activity.

┌──────────────────────────────────────────────────────────────┐
│  TRANSACTION FLOW ANALYSIS                                    │
│                                                               │
│  Normal:  ████ ███ █████ ██ ████ ███ ████ █████ ██          │
│  Target:  ████ ███ █████ ?? ???? ??? ???? █████ ██          │
│                      ▲                                        │
│           GAP DETECTED - Shadow entry point?                  │
│                                                               │
│  Select the timestamp range where shadow activated:           │
│  [ 14:23 ] [ 14:47 ] [ 15:02 ] [ 15:31 ]                     │
└──────────────────────────────────────────────────────────────┘

PHASE 2: BEHAVIORAL CORRELATION (20 seconds)
────────────────────────────────────────────
Match shadow behavior to known player patterns.

┌──────────────────────────────────────────────────────────────┐
│  BEHAVIORAL FINGERPRINT MATCHING                              │
│                                                               │
│  Shadow Profile:           Known Players:                     │
│  ┌─────────────────┐       ┌─────────────────┐               │
│  │ Avg stake: HIGH │       │ 0x7a3f: MED     │               │
│  │ Risk pref: AGGR │       │ 0x9c2d: HIGH ◄──┼── MATCH?     │
│  │ Session: LONG   │       │ 0x3b1a: LOW     │               │
│  │ Mini-game: YES  │       │ 0x8f2e: HIGH    │               │
│  └─────────────────┘       └─────────────────┘               │
│                                                               │
│  Select suspected shadow: [_______________]                   │
└──────────────────────────────────────────────────────────────┘

PHASE 3: TIMING ATTACK (10 seconds)
───────────────────────────────────
React to micro-transactions that betray shadow presence.

┌──────────────────────────────────────────────────────────────┐
│  MICRO-TRANSACTION SCANNER                                    │
│                                                               │
│  Monitoring for shadow heartbeat signals...                   │
│                                                               │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│  ░░░░░░░░░░░░░░░░░░░░░██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░██░░░░░░░░░░░░░░░░░░░░░░  │
│                           ▲              ▲                    │
│                      BLIP DETECTED   BLIP DETECTED           │
│                                                               │
│  Click when you see the next blip: [ DETECT ]                │
└──────────────────────────────────────────────────────────────┘
```

### Detection Scoring

```typescript
interface DetectionScore {
  patternScore: number;      // 0-100 from phase 1
  behaviorScore: number;     // 0-100 from phase 2
  timingScore: number;       // 0-100 from phase 3
  totalScore: number;        // Weighted average
  detectionThreshold: number; // Based on shadow's evasion skill
}

function calculateDetection(score: DetectionScore): boolean {
  // Weighted scoring: pattern matters most
  const weighted = 
    (score.patternScore * 0.4) +
    (score.behaviorScore * 0.35) +
    (score.timingScore * 0.25);
  
  // Must exceed shadow's current detection threshold
  return weighted >= score.detectionThreshold;
}
```

### Shadow Detection Risk

Detection risk increases based on multiple factors:

```
BASE DETECTION THRESHOLD: 70 (hunter needs 70+ to detect)

RISK MODIFIERS:
├── Time in shadow
│   └── +1 per 10 minutes (threshold decreases)
│
├── Position size
│   └── Large positions are harder to hide
│   └── >1000 $DATA: -5 threshold
│   └── >5000 $DATA: -10 threshold
│
├── Activity while shadowed
│   └── Playing mini-games: -3 threshold each
│   └── Interacting with contracts: -5 threshold
│
├── Previous shadow usage
│   └── Frequent shadows: -2 threshold per use (24h)
│
└── Failed detection attempts on you
    └── +5 threshold (you're harder to detect)

EXAMPLE:
Shadow active for 2 hours, large position, played 2 mini-games
Threshold: 70 - 12 (time) - 10 (position) - 6 (games) = 42
Hunter only needs 42+ score to detect!
```

### Shadow vs Shadow

When two shadows encounter each other in the detection mini-game:

```
SHADOW COLLISION:
═══════════════════════════════════════════════════════════════════

If a shadow attempts to hunt and selects another shadow:

1. Both shadows are revealed to each other (not to network)
2. Mutual detection standoff begins
3. Options:
   ├── TRUCE: Both remain hidden, share info
   ├── EXPOSE: Try to expose the other first
   └── FLEE: Both exit shadow mode immediately

If one exposes the other:
├── Exposer gets 50% of victim's bounty
├── Exposer remains in shadow
└── Victim loses 2x position value
```

---

## User Interface

### States

**1. Shadow Activation Screen**

```
╔══════════════════════════════════════════════════════════════════╗
║                      SHADOW PROTOCOL                              ║
║                   ░░░ INITIATE ░░░                                ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║       ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄           ║
║       █                                               █           ║
║       █   "IN THE SHADOW, YOU ARE INVISIBLE.         █           ║
║       █    BUT THE SHADOW HAS HUNTERS."              █           ║
║       █                                               █           ║
║       █▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄█           ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║   SHADOW BENEFITS:                                                ║
║   ├── Immune to trace scans                                      ║
║   ├── Hidden from live feed                                      ║
║   └── Position invisible to other players                        ║
║                                                                   ║
║   SHADOW RISKS:                                                  ║
║   ├── Hunters can detect you                                     ║
║   ├── If detected: lose 2x position value                        ║
║   └── Detection risk increases over time                         ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║   COST: 200 $DATA (burned on activation)                         ║
║   DURATION: 4 hours maximum                                       ║
║   YOUR POSITION: 2,500 $DATA in DARKNET                          ║
║   RISK IF DETECTED: 5,000 $DATA (2x)                             ║
║                                                                   ║
║               [ ENTER THE SHADOW ]        [ CANCEL ]              ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**2. Active Shadow Status**

```
╔══════════════════════════════════════════════════════════════════╗
║  SHADOW PROTOCOL                          STATUS: ░░░ ACTIVE ░░░  ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  ┌──────────────────────────────────────────────────────────┐    ║
║  │                                                           │    ║
║  │                    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                      │    ║
║  │                  ▒▒░░░░░░░░░░░░░░░░▒▒                    │    ║
║  │                ▒▒░░              ░░▒▒                    │    ║
║  │               ▒░░  CLOAKED  ░░▒                         │    ║
║  │               ▒░░    ◉◉     ░░▒   <- Your eyes only     │    ║
║  │                ▒▒░░              ░░▒▒                    │    ║
║  │                  ▒▒░░░░░░░░░░░░░░░░▒▒                    │    ║
║  │                    ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                      │    ║
║  │                                                           │    ║
║  └──────────────────────────────────────────────────────────┘    ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  SHADOW DURATION      ████████████████░░░░ 03:12:47 remaining    ║
║  DETECTION RISK       ████████░░░░░░░░░░░░ 42% (threshold: 58)   ║
║  BOUNTY ON YOUR HEAD  ████████████░░░░░░░░ 680 $DATA             ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  SHADOW INTEL:                                                    ║
║  ├── Active hunters: 15                                          ║
║  ├── Detection attempts on you: 3 (all failed)                   ║
║  ├── Scans evaded: 4                                             ║
║  └── Time until next scan: 00:23:18                              ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  [ EXTEND +1 HR (50 $DATA) ]    [ EXIT SHADOW (SAFE) ]           ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**3. Hunter Detection Interface**

```
╔══════════════════════════════════════════════════════════════════╗
║                     SHADOW HUNTER                                 ║
║                ░░░ DETECTION MODE ░░░                             ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  NETWORK STATUS                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  │ Active shadows in network:  ████████░░░░░░░░░░░░  23         │║
║  │ Total shadow bounty pool:   12,450 $DATA                     │║
║  │ Your successful detections: 7                                │║
║  │ Your lifetime earnings:     2,340 $DATA                      │║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  DETECTION TARGETS                                                ║
║  ┌──────────────────────────────────────────────────────────┐    ║
║  │                                                           │    ║
║  │  ?????  │ Est. Bounty: ~400 $DATA  │ Risk Level: ███░░   │    ║
║  │  ?????  │ Est. Bounty: ~850 $DATA  │ Risk Level: ████░   │    ║
║  │  ?????  │ Est. Bounty: ~200 $DATA  │ Risk Level: ██░░░   │    ║
║  │  ?????  │ Est. Bounty: ~1200 $DATA │ Risk Level: █████   │    ║
║  │  ?????  │ Est. Bounty: ~300 $DATA  │ Risk Level: ███░░   │    ║
║  │                                                           │    ║
║  │  ▼ Show 18 more shadows...                                │    ║
║  │                                                           │    ║
║  └──────────────────────────────────────────────────────────┘    ║
║                                                                   ║
║  Select a shadow profile to begin detection attempt.              ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  COOLDOWN: Ready                 SUCCESS RATE: 34%                ║
║                                                                   ║
║                    [ BEGIN DETECTION ]                            ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**4. Detection Mini-Game - Phase 1: Pattern Analysis**

```
╔══════════════════════════════════════════════════════════════════╗
║  DETECTION IN PROGRESS           PHASE 1/3: PATTERN ANALYSIS      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  TIME: 00:12                                                      ║
║                                                                   ║
║  ┌──────────────────────────────────────────────────────────┐    ║
║  │                                                           │    ║
║  │  NETWORK TRANSACTION FLOW - LAST 24 HOURS                 │    ║
║  │                                                           │    ║
║  │  06:00 ██████████████████████████████████████             │    ║
║  │  08:00 ████████████████████████████████████████████       │    ║
║  │  10:00 ██████████████████████████████████████████████     │    ║
║  │  12:00 ████████████████░░░░░░░░░░░░░████████████████      │    ║
║  │  14:00 ██████████████████████████████████████████████     │    ║
║  │  16:00 ████████████████████████████████████████           │    ║
║  │  18:00 ██████████████████████████████████████████████████ │    ║
║  │  20:00 ████████████████████████████████████████████       │    ║
║  │  22:00 ██████████████████████████████████████             │    ║
║  │  00:00 ████████████████████████████████                   │    ║
║  │                      ▲                                     │    ║
║  │               ANOMALY DETECTED                             │    ║
║  │                                                           │    ║
║  └──────────────────────────────────────────────────────────┘    ║
║                                                                   ║
║  When did this shadow likely activate?                            ║
║                                                                   ║
║     [ 10:00 ]    [ 12:00 ]    [ 14:00 ]    [ 16:00 ]             ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**5. Detection Mini-Game - Phase 2: Behavioral Correlation**

```
╔══════════════════════════════════════════════════════════════════╗
║  DETECTION IN PROGRESS        PHASE 2/3: BEHAVIORAL ANALYSIS      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  TIME: 00:17          PHASE 1 SCORE: 78/100                       ║
║                                                                   ║
║  ┌──────────────────────────────────────────────────────────┐    ║
║  │                                                           │    ║
║  │  SHADOW BEHAVIORAL FINGERPRINT:                           │    ║
║  │  ┌─────────────────────────────────────┐                  │    ║
║  │  │ Stake Size:    ████████░░ LARGE     │                  │    ║
║  │  │ Risk Profile:  ██████████ AGGRESSIVE│                  │    ║
║  │  │ Session Len:   ██████░░░░ MEDIUM    │                  │    ║
║  │  │ Mini-games:    ████░░░░░░ LOW       │                  │    ║
║  │  │ Trade Freq:    ████████░░ HIGH      │                  │    ║
║  │  └─────────────────────────────────────┘                  │    ║
║  │                                                           │    ║
║  │  MATCH TO KNOWN PLAYERS:                                  │    ║
║  │                                                           │    ║
║  │  ┌─────────────────────┬─────────────────────┐           │    ║
║  │  │ 0x7a3f...8e2d       │ Match: 34%          │           │    ║
║  │  │ 0x9c2d...1f4a       │ Match: 87% ◄        │           │    ║
║  │  │ 0x3b1a...7c9e       │ Match: 23%          │           │    ║
║  │  │ 0x8f2e...4d5b       │ Match: 61%          │           │    ║
║  │  │ 0x1d4c...9a2f       │ Match: 45%          │           │    ║
║  │  └─────────────────────┴─────────────────────┘           │    ║
║  │                                                           │    ║
║  └──────────────────────────────────────────────────────────┘    ║
║                                                                   ║
║  Select your target:  [ 0x9c2d...1f4a               ▼ ]          ║
║                                                                   ║
║                         [ CONFIRM TARGET ]                        ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**6. Detection Mini-Game - Phase 3: Timing Attack**

```
╔══════════════════════════════════════════════════════════════════╗
║  DETECTION IN PROGRESS          PHASE 3/3: TIMING ATTACK          ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  TIME: 00:08          PHASE 2 SCORE: 92/100                       ║
║                                                                   ║
║  ┌──────────────────────────────────────────────────────────┐    ║
║  │                                                           │    ║
║  │               SHADOW HEARTBEAT MONITOR                    │    ║
║  │                                                           │    ║
║  │  Detecting micro-transaction signatures...                │    ║
║  │                                                           │    ║
║  │  ─────────────────────────────────────────────────────   │    ║
║  │                                                           │    ║
║  │  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   │    ║
║  │  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   │    ║
║  │  ░░░░░░░░░░░░░░░██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   │    ║
║  │  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░██░░░░░░░░░░░░░░░░░░   │    ║
║  │  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   │    ║
║  │                                                           │    ║
║  │  ─────────────────────────────────────────────────────   │    ║
║  │                                                           │    ║
║  │            CLICK WHEN YOU SEE THE BLIP!                   │    ║
║  │                                                           │    ║
║  └──────────────────────────────────────────────────────────┘    ║
║                                                                   ║
║  HITS: 2/5          ACCURACY NEEDED: 60%                          ║
║                                                                   ║
║                       [ ████ DETECT ████ ]                        ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**7. Detection Success**

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║    ██████╗ ███████╗████████╗███████╗ ██████╗████████╗███████╗   ║
║    ██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔════╝╚══██╔══╝██╔════╝   ║
║    ██║  ██║█████╗     ██║   █████╗  ██║        ██║   █████╗     ║
║    ██║  ██║██╔══╝     ██║   ██╔══╝  ██║        ██║   ██╔══╝     ║
║    ██████╔╝███████╗   ██║   ███████╗╚██████╗   ██║   ███████╗   ║
║    ╚═════╝ ╚══════╝   ╚═╝   ╚══════╝ ╚═════╝   ╚═╝   ╚══════╝   ║
║                                                                   ║
║                    ░░░ SHADOW EXPOSED ░░░                         ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  TARGET: 0x9c2d...1f4a                                           ║
║                                                                   ║
║  YOUR DETECTION SCORE:                                            ║
║  ├── Pattern Analysis:   78/100                                  ║
║  ├── Behavioral Match:   92/100                                  ║
║  ├── Timing Attack:      85/100                                  ║
║  └── TOTAL:              84/100 (threshold was 58)               ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  BOUNTY CLAIMED: 680 $DATA                                       ║
║  VICTIM LOSS:    5,000 $DATA (2x position)                       ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  Your hunter rank: #34 → #29                                     ║
║                                                                   ║
║                    [ HUNT AGAIN ]      [ EXIT ]                   ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**8. Detection Failure**

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║          ███████╗██╗   ██╗ █████╗ ██████╗ ███████╗██████╗       ║
║          ██╔════╝██║   ██║██╔══██╗██╔══██╗██╔════╝██╔══██╗      ║
║          █████╗  ██║   ██║███████║██║  ██║█████╗  ██║  ██║      ║
║          ██╔══╝  ╚██╗ ██╔╝██╔══██║██║  ██║██╔══╝  ██║  ██║      ║
║          ███████╗ ╚████╔╝ ██║  ██║██████╔╝███████╗██████╔╝      ║
║          ╚══════╝  ╚═══╝  ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═════╝       ║
║                                                                   ║
║                  ░░░ TARGET EVADED ░░░                            ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  YOUR DETECTION SCORE:                                            ║
║  ├── Pattern Analysis:   65/100                                  ║
║  ├── Behavioral Match:   43/100                                  ║
║  ├── Timing Attack:      71/100                                  ║
║  └── TOTAL:              57/100 (threshold was 62)               ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  The shadow slipped away. Their detection threshold               ║
║  has increased by +5 (now harder to detect).                      ║
║                                                                   ║
║  COOLDOWN: 10 minutes before next attempt                        ║
║                                                                   ║
║  TIP: Focus on behavioral analysis - matching player             ║
║       patterns is key to successful detection.                   ║
║                                                                   ║
║                           [ EXIT ]                                ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**9. Shadow Exposed (Victim View)**

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║    ███████╗██╗  ██╗██████╗  ██████╗ ███████╗███████╗██████╗     ║
║    ██╔════╝╚██╗██╔╝██╔══██╗██╔═══██╗██╔════╝██╔════╝██╔══██╗    ║
║    █████╗   ╚███╔╝ ██████╔╝██║   ██║███████╗█████╗  ██║  ██║    ║
║    ██╔══╝   ██╔██╗ ██╔═══╝ ██║   ██║╚════██║██╔══╝  ██║  ██║    ║
║    ███████╗██╔╝ ██╗██║     ╚██████╔╝███████║███████╗██████╔╝    ║
║    ╚══════╝╚═╝  ╚═╝╚═╝      ╚═════╝ ╚══════╝╚══════╝╚═════╝     ║
║                                                                   ║
║              ████ YOUR SHADOW HAS BEEN BREACHED ████              ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  DETECTED BY: 0x8f2e...4d5b                                      ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  LOSSES:                                                          ║
║  ├── Shadow entry fee:     200 $DATA (already burned)            ║
║  ├── Position penalty:     5,000 $DATA (2x position)             ║
║  ├── Bounty forfeited:     680 $DATA                             ║
║  └── TOTAL LOSS:           5,880 $DATA                           ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  Your position in DARKNET has been liquidated.                    ║
║  You are now visible on the network.                              ║
║                                                                   ║
║                           [ ACCEPT ]                              ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Economic Model

### Entry & Fees

| Parameter | Value |
|-----------|-------|
| Shadow Entry | 200 $DATA (100% burned) |
| Shadow Extension | 50 $DATA per hour (100% burned) |
| Hunter Entry | Free |
| Hunter Cooldown | 10 minutes on failure |
| Detection Reward | 100% of shadow's bounty pool |

### Bounty Pool Mechanics

```
BOUNTY ACCUMULATION:
═══════════════════════════════════════════════════════════════════

Initial bounty: 200 $DATA (entry fee)

Growth:
├── Each evaded scan:        +50 $DATA to bounty
├── Each hour in shadow:     +25 $DATA to bounty
├── Each failed detection:   +30 $DATA to bounty
└── Shadow extension:        +50 $DATA per extension

Example 4-hour shadow run:
├── Entry:                   200 $DATA
├── 4 evaded scans:          200 $DATA
├── 4 hours duration:        100 $DATA
├── 2 failed detections:     60 $DATA
└── TOTAL BOUNTY:            560 $DATA

If detected: Hunter gets 560 $DATA, shadow loses 2x position
If clean exit: Shadow keeps position, loses entry fee only
```

### Risk/Reward Analysis

```
SHADOW PERSPECTIVE:
─────────────────────────────────────────────────────────────────
Entry: 200 $DATA (always burned)
Risk: 2x position value if detected

Value Proposition:
├── Complete trace scan immunity for duration
├── Hidden from competitors/social pressure
├── Allows strategic position building unseen
└── Psychological advantage

Expected Value (varies by skill):
├── Skilled shadow (20% detection rate): Positive EV if position >500 $DATA
├── Average shadow (40% detection rate): Negative EV, use for strategic value
└── New shadow (60% detection rate): Avoid unless critical

HUNTER PERSPECTIVE:
─────────────────────────────────────────────────────────────────
Entry: Free (only time investment)
Risk: None (only cooldown on failure)

Value Proposition:
├── Pure profit on successful detection
├── Skill-based earnings
├── Contributes to network health
└── Social status (hunter leaderboard)

Expected Value:
├── Skilled hunter (50% success): ~300 $DATA per hour active hunting
├── Average hunter (30% success): ~120 $DATA per hour
└── New hunter (15% success): Time sink, learning opportunity
```

### Burn Analysis

```
EVERY SHADOW SESSION BURNS:
├── Entry fee: 200 $DATA (guaranteed)
├── Extensions: 50 $DATA each (optional)
└── No matter the outcome, burns happen

ADDITIONAL BURNS FROM DETECTION:
├── Victim's 2x position loss → portion may be burned
├── Creates deflationary pressure
└── Incentivizes hunter activity

PROJECTED DAILY BURN (at scale):
├── 100 shadow activations: 20,000 $DATA entry burns
├── 50 detections (50% rate): Additional liquidation burns
└── Significant deflationary impact
```

---

## Technical Implementation

### Smart Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title ShadowProtocol
/// @notice Stealth mode mechanic for GHOSTNET - hide from trace scans
/// @dev Manages shadow state, bounties, and detection verification
contract ShadowProtocol is Ownable2Step, ReentrancyGuard {
    // ═══════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════
    
    error NotInShadow();
    error AlreadyInShadow();
    error ShadowExpired();
    error InvalidDuration();
    error InsufficientBalance();
    error HunterOnCooldown();
    error InvalidDetectionProof();
    error CannotHuntSelf();
    error ShadowNotFound();
    error PositionTooSmall();
    
    // ═══════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event ShadowActivated(
        address indexed shadow,
        uint256 indexed shadowId,
        uint256 bounty,
        uint256 expiresAt
    );
    
    event ShadowExtended(
        address indexed shadow,
        uint256 indexed shadowId,
        uint256 newExpiry,
        uint256 additionalBounty
    );
    
    event ShadowExited(
        address indexed shadow,
        uint256 indexed shadowId,
        uint256 duration,
        uint256 scansEvaded
    );
    
    event ShadowDetected(
        address indexed shadow,
        address indexed hunter,
        uint256 indexed shadowId,
        uint256 bountyPaid,
        uint256 positionLost
    );
    
    event DetectionFailed(
        address indexed hunter,
        uint256 indexed shadowId,
        uint256 score,
        uint256 threshold
    );
    
    event BountyIncreased(
        uint256 indexed shadowId,
        uint256 newBounty,
        string reason
    );
    
    // ═══════════════════════════════════════════════════════════════
    // TYPES
    // ═══════════════════════════════════════════════════════════════
    
    struct Shadow {
        address owner;
        uint256 shadowId;
        uint256 activatedAt;
        uint256 expiresAt;
        uint256 bountyPool;
        uint256 detectionThreshold;  // 0-100, hunter needs score >= this
        uint256 scansEvaded;
        uint256 failedDetections;
        bool isActive;
    }
    
    struct HunterStats {
        uint256 totalDetections;
        uint256 totalEarnings;
        uint256 cooldownUntil;
        uint256 lastDetectionTime;
    }
    
    struct DetectionProof {
        uint256 shadowId;
        uint256 patternScore;      // 0-100
        uint256 behaviorScore;     // 0-100
        uint256 timingScore;       // 0-100
        bytes32 commitmentHash;    // Prevents frontrunning
        uint256 timestamp;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════
    
    IERC20 public immutable dataToken;
    address public immutable ghostnetCore;
    
    uint256 public constant SHADOW_ENTRY_COST = 200 ether;      // 200 $DATA
    uint256 public constant SHADOW_EXTEND_COST = 50 ether;      // 50 $DATA per hour
    uint256 public constant MAX_SHADOW_DURATION = 4 hours;
    uint256 public constant MIN_POSITION_SIZE = 100 ether;      // 100 $DATA
    uint256 public constant HUNTER_COOLDOWN = 10 minutes;
    
    uint256 public constant BASE_DETECTION_THRESHOLD = 70;      // Hunter needs 70+ to detect
    uint256 public constant SCAN_EVADE_BOUNTY_BONUS = 50 ether; // +50 per evaded scan
    uint256 public constant HOURLY_BOUNTY_BONUS = 25 ether;     // +25 per hour
    uint256 public constant FAILED_DETECTION_BONUS = 30 ether;  // +30 per failed detection
    uint256 public constant FAILED_DETECTION_THRESHOLD_BONUS = 5; // +5 to threshold
    
    uint256 public shadowIdCounter;
    uint256 public activeShadowCount;
    uint256 public totalBountyPool;
    
    mapping(address => Shadow) public shadows;
    mapping(uint256 => address) public shadowIdToOwner;
    mapping(address => HunterStats) public hunters;
    mapping(bytes32 => bool) public usedCommitments;
    
    // ═══════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════
    
    constructor(
        address _dataToken,
        address _ghostnetCore,
        address _initialOwner
    ) Ownable(_initialOwner) {
        dataToken = IERC20(_dataToken);
        ghostnetCore = _ghostnetCore;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // SHADOW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Activate shadow mode for the caller
    /// @param duration Duration in seconds (max 4 hours)
    function activateShadow(uint256 duration) external nonReentrant {
        if (shadows[msg.sender].isActive) revert AlreadyInShadow();
        if (duration == 0 || duration > MAX_SHADOW_DURATION) revert InvalidDuration();
        
        // Check player has sufficient position in GHOSTNET
        uint256 positionSize = _getPlayerPosition(msg.sender);
        if (positionSize < MIN_POSITION_SIZE) revert PositionTooSmall();
        
        // Transfer and burn entry fee
        if (!dataToken.transferFrom(msg.sender, address(this), SHADOW_ENTRY_COST)) {
            revert InsufficientBalance();
        }
        _burnTokens(SHADOW_ENTRY_COST);
        
        // Create shadow
        uint256 shadowId = ++shadowIdCounter;
        uint256 expiresAt = block.timestamp + duration;
        
        shadows[msg.sender] = Shadow({
            owner: msg.sender,
            shadowId: shadowId,
            activatedAt: block.timestamp,
            expiresAt: expiresAt,
            bountyPool: SHADOW_ENTRY_COST,
            detectionThreshold: _calculateInitialThreshold(positionSize),
            scansEvaded: 0,
            failedDetections: 0,
            isActive: true
        });
        
        shadowIdToOwner[shadowId] = msg.sender;
        activeShadowCount++;
        totalBountyPool += SHADOW_ENTRY_COST;
        
        emit ShadowActivated(msg.sender, shadowId, SHADOW_ENTRY_COST, expiresAt);
    }
    
    /// @notice Extend shadow duration by 1 hour
    function extendShadow() external nonReentrant {
        Shadow storage shadow = shadows[msg.sender];
        if (!shadow.isActive) revert NotInShadow();
        if (block.timestamp >= shadow.expiresAt) revert ShadowExpired();
        
        uint256 newExpiry = shadow.expiresAt + 1 hours;
        uint256 totalDuration = newExpiry - shadow.activatedAt;
        if (totalDuration > MAX_SHADOW_DURATION) revert InvalidDuration();
        
        // Transfer and burn extension fee
        if (!dataToken.transferFrom(msg.sender, address(this), SHADOW_EXTEND_COST)) {
            revert InsufficientBalance();
        }
        _burnTokens(SHADOW_EXTEND_COST);
        
        shadow.expiresAt = newExpiry;
        shadow.bountyPool += SHADOW_EXTEND_COST;
        totalBountyPool += SHADOW_EXTEND_COST;
        
        emit ShadowExtended(msg.sender, shadow.shadowId, newExpiry, SHADOW_EXTEND_COST);
        emit BountyIncreased(shadow.shadowId, shadow.bountyPool, "extension");
    }
    
    /// @notice Exit shadow mode safely (no penalty, but no rewards)
    function exitShadow() external nonReentrant {
        Shadow storage shadow = shadows[msg.sender];
        if (!shadow.isActive) revert NotInShadow();
        
        uint256 duration = block.timestamp - shadow.activatedAt;
        uint256 scansEvaded = shadow.scansEvaded;
        uint256 shadowId = shadow.shadowId;
        
        // Clear shadow state
        _clearShadow(msg.sender);
        
        emit ShadowExited(msg.sender, shadowId, duration, scansEvaded);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // HUNTER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Attempt to detect a shadow using commit-reveal scheme
    /// @param proof Detection proof containing scores and commitment
    function attemptDetection(DetectionProof calldata proof) external nonReentrant {
        address shadowOwner = shadowIdToOwner[proof.shadowId];
        if (shadowOwner == address(0)) revert ShadowNotFound();
        if (shadowOwner == msg.sender) revert CannotHuntSelf();
        
        Shadow storage shadow = shadows[shadowOwner];
        if (!shadow.isActive) revert ShadowNotFound();
        if (block.timestamp >= shadow.expiresAt) revert ShadowExpired();
        
        HunterStats storage hunter = hunters[msg.sender];
        if (block.timestamp < hunter.cooldownUntil) revert HunterOnCooldown();
        
        // Verify commitment hasn't been used
        if (usedCommitments[proof.commitmentHash]) revert InvalidDetectionProof();
        usedCommitments[proof.commitmentHash] = true;
        
        // Calculate detection score (weighted average)
        uint256 totalScore = (
            (proof.patternScore * 40) +
            (proof.behaviorScore * 35) +
            (proof.timingScore * 25)
        ) / 100;
        
        // Check if detection succeeds
        if (totalScore >= shadow.detectionThreshold) {
            _executeDetection(shadowOwner, shadow, msg.sender, totalScore);
        } else {
            _handleFailedDetection(shadowOwner, shadow, msg.sender, totalScore);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    function _executeDetection(
        address shadowOwner,
        Shadow storage shadow,
        address hunter,
        uint256 score
    ) internal {
        uint256 bounty = shadow.bountyPool;
        uint256 shadowId = shadow.shadowId;
        
        // Get victim's position and calculate 2x penalty
        uint256 positionSize = _getPlayerPosition(shadowOwner);
        uint256 penalty = positionSize * 2;
        
        // Pay bounty to hunter
        // Note: Bounty comes from accumulated pool (entry fees + bonuses)
        // We mint new tokens for the bounty since entry was burned
        _mintBounty(hunter, bounty);
        
        // Liquidate victim's position (2x penalty)
        _liquidatePosition(shadowOwner, penalty);
        
        // Update hunter stats
        HunterStats storage hunterStats = hunters[hunter];
        hunterStats.totalDetections++;
        hunterStats.totalEarnings += bounty;
        hunterStats.lastDetectionTime = block.timestamp;
        // No cooldown on success
        
        // Clear shadow
        totalBountyPool -= bounty;
        _clearShadow(shadowOwner);
        
        emit ShadowDetected(shadowOwner, hunter, shadowId, bounty, penalty);
    }
    
    function _handleFailedDetection(
        address shadowOwner,
        Shadow storage shadow,
        address hunter,
        uint256 score
    ) internal {
        // Increase shadow's detection threshold (harder to detect)
        shadow.detectionThreshold += FAILED_DETECTION_THRESHOLD_BONUS;
        if (shadow.detectionThreshold > 95) {
            shadow.detectionThreshold = 95; // Cap at 95
        }
        
        // Increase bounty pool
        shadow.bountyPool += FAILED_DETECTION_BONUS;
        shadow.failedDetections++;
        totalBountyPool += FAILED_DETECTION_BONUS;
        
        // Put hunter on cooldown
        hunters[hunter].cooldownUntil = block.timestamp + HUNTER_COOLDOWN;
        
        emit DetectionFailed(hunter, shadow.shadowId, score, shadow.detectionThreshold);
        emit BountyIncreased(shadow.shadowId, shadow.bountyPool, "failed_detection");
    }
    
    function _calculateInitialThreshold(uint256 positionSize) internal pure returns (uint256) {
        uint256 threshold = BASE_DETECTION_THRESHOLD;
        
        // Large positions are harder to hide
        if (positionSize > 5000 ether) {
            threshold -= 10;
        } else if (positionSize > 1000 ether) {
            threshold -= 5;
        }
        
        return threshold;
    }
    
    function _clearShadow(address shadowOwner) internal {
        Shadow storage shadow = shadows[shadowOwner];
        delete shadowIdToOwner[shadow.shadowId];
        delete shadows[shadowOwner];
        activeShadowCount--;
    }
    
    function _getPlayerPosition(address player) internal view returns (uint256) {
        // Interface with GHOSTNET core contract
        // Returns player's staked position size
        (bool success, bytes memory data) = ghostnetCore.staticcall(
            abi.encodeWithSignature("getPosition(address)", player)
        );
        if (!success) return 0;
        return abi.decode(data, (uint256));
    }
    
    function _liquidatePosition(address player, uint256 amount) internal {
        // Interface with GHOSTNET core to liquidate position
        (bool success,) = ghostnetCore.call(
            abi.encodeWithSignature("liquidatePosition(address,uint256)", player, amount)
        );
        require(success, "Liquidation failed");
    }
    
    function _burnTokens(uint256 amount) internal {
        // Send to burn address or call burn function
        dataToken.transfer(address(0xdead), amount);
    }
    
    function _mintBounty(address recipient, uint256 amount) internal {
        // Transfer from protocol reserves or mint
        // Implementation depends on token design
        dataToken.transfer(recipient, amount);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // GHOSTNET CORE INTEGRATION
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Called by GHOSTNET core when a trace scan completes
    /// @dev Shadows evade the scan, their bounty increases
    function onTraceScan() external {
        require(msg.sender == ghostnetCore, "Only core");
        
        // Note: Actual implementation would iterate active shadows
        // and update their stats. For gas efficiency, this might
        // be done off-chain with merkle proofs for claims.
    }
    
    /// @notice Check if a player is in shadow mode (for core contract)
    function isInShadow(address player) external view returns (bool) {
        Shadow storage shadow = shadows[player];
        return shadow.isActive && block.timestamp < shadow.expiresAt;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /// @notice Get shadow stats for a player
    function getShadowStats(address player) external view returns (
        bool isActive,
        uint256 expiresAt,
        uint256 bountyPool,
        uint256 detectionThreshold,
        uint256 scansEvaded
    ) {
        Shadow storage shadow = shadows[player];
        return (
            shadow.isActive && block.timestamp < shadow.expiresAt,
            shadow.expiresAt,
            shadow.bountyPool,
            shadow.detectionThreshold,
            shadow.scansEvaded
        );
    }
    
    /// @notice Get hunter stats
    function getHunterStats(address hunter) external view returns (
        uint256 totalDetections,
        uint256 totalEarnings,
        uint256 cooldownUntil,
        bool canHunt
    ) {
        HunterStats storage stats = hunters[hunter];
        return (
            stats.totalDetections,
            stats.totalEarnings,
            stats.cooldownUntil,
            block.timestamp >= stats.cooldownUntil
        );
    }
    
    /// @notice Get network shadow statistics
    function getNetworkStats() external view returns (
        uint256 activeCount,
        uint256 totalBounty,
        uint256 totalShadowsCreated
    ) {
        return (activeShadowCount, totalBountyPool, shadowIdCounter);
    }
}
```

### Frontend Store

```typescript
// src/lib/features/arcade/shadow-protocol/store.svelte.ts

import { browser } from '$app/environment';

export type ShadowPhase = 'inactive' | 'activating' | 'active' | 'exposed' | 'exiting';
export type HunterPhase = 'idle' | 'scanning' | 'detecting' | 'success' | 'failed';
export type DetectionPhase = 'pattern' | 'behavior' | 'timing' | 'calculating';

interface ShadowState {
  isActive: boolean;
  shadowId: number;
  activatedAt: number;
  expiresAt: number;
  bountyPool: bigint;
  detectionThreshold: number;
  scansEvaded: number;
  failedDetections: number;
}

interface HunterState {
  totalDetections: number;
  totalEarnings: bigint;
  cooldownUntil: number;
  canHunt: boolean;
}

interface DetectionTarget {
  shadowId: number;
  estimatedBounty: bigint;
  riskLevel: number; // 1-5
  behaviorProfile: BehaviorProfile;
}

interface BehaviorProfile {
  stakeSize: 'low' | 'medium' | 'high';
  riskProfile: 'conservative' | 'moderate' | 'aggressive';
  sessionLength: 'short' | 'medium' | 'long';
  miniGameActivity: 'low' | 'medium' | 'high';
  tradeFrequency: 'low' | 'medium' | 'high';
}

interface DetectionScores {
  pattern: number;
  behavior: number;
  timing: number;
  total: number;
}

interface NetworkStats {
  activeShadows: number;
  totalBountyPool: bigint;
  recentDetections: RecentDetection[];
}

interface RecentDetection {
  hunter: string;
  shadow: string;
  bounty: bigint;
  timestamp: number;
}

export function createShadowProtocolStore() {
  // ═══════════════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════════════
  
  // Shadow state
  let shadowPhase = $state<ShadowPhase>('inactive');
  let shadowState = $state<ShadowState | null>(null);
  let timeRemaining = $state(0);
  let detectionRisk = $state(0);
  
  // Hunter state
  let hunterPhase = $state<HunterPhase>('idle');
  let hunterState = $state<HunterState | null>(null);
  let detectionTargets = $state<DetectionTarget[]>([]);
  let selectedTarget = $state<DetectionTarget | null>(null);
  
  // Detection mini-game state
  let detectionPhase = $state<DetectionPhase | null>(null);
  let detectionScores = $state<DetectionScores>({
    pattern: 0,
    behavior: 0,
    timing: 0,
    total: 0
  });
  let phaseTimeRemaining = $state(0);
  
  // Network state
  let networkStats = $state<NetworkStats>({
    activeShadows: 0,
    totalBountyPool: 0n,
    recentDetections: []
  });
  
  // Connection
  let isConnected = $state(false);
  
  // Timers
  let countdownInterval: ReturnType<typeof setInterval> | null = null;
  let phaseTimer: ReturnType<typeof setInterval> | null = null;
  
  // ═══════════════════════════════════════════════════════════════
  // DERIVED
  // ═══════════════════════════════════════════════════════════════
  
  let canActivateShadow = $derived(
    shadowPhase === 'inactive' && 
    isConnected
  );
  
  let canExtendShadow = $derived(
    shadowPhase === 'active' &&
    shadowState !== null &&
    timeRemaining > 0 &&
    (shadowState.expiresAt - shadowState.activatedAt) < 4 * 60 * 60 * 1000 // < 4 hours total
  );
  
  let canExitShadow = $derived(
    shadowPhase === 'active' &&
    shadowState !== null
  );
  
  let canHunt = $derived(
    hunterPhase === 'idle' &&
    (hunterState?.canHunt ?? true) &&
    isConnected
  );
  
  let formattedTimeRemaining = $derived(() => {
    const hours = Math.floor(timeRemaining / 3600);
    const minutes = Math.floor((timeRemaining % 3600) / 60);
    const seconds = timeRemaining % 60;
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  });
  
  let detectionRiskLevel = $derived(() => {
    if (detectionRisk < 30) return 'low';
    if (detectionRisk < 60) return 'medium';
    return 'high';
  });
  
  // ═══════════════════════════════════════════════════════════════
  // SHADOW ACTIONS
  // ═══════════════════════════════════════════════════════════════
  
  async function activateShadow(durationHours: number) {
    if (!canActivateShadow) return;
    
    shadowPhase = 'activating';
    
    try {
      // Contract interaction
      const tx = await sendTransaction('activateShadow', [durationHours * 3600]);
      await tx.wait();
      
      // Update local state
      shadowPhase = 'active';
      startCountdown();
      
    } catch (error) {
      shadowPhase = 'inactive';
      throw error;
    }
  }
  
  async function extendShadow() {
    if (!canExtendShadow) return;
    
    try {
      const tx = await sendTransaction('extendShadow', []);
      await tx.wait();
      
      // Refresh state from contract
      await refreshShadowState();
      
    } catch (error) {
      throw error;
    }
  }
  
  async function exitShadow() {
    if (!canExitShadow) return;
    
    shadowPhase = 'exiting';
    
    try {
      const tx = await sendTransaction('exitShadow', []);
      await tx.wait();
      
      // Clear local state
      stopCountdown();
      shadowPhase = 'inactive';
      shadowState = null;
      
    } catch (error) {
      shadowPhase = 'active';
      throw error;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════
  // HUNTER ACTIONS
  // ═══════════════════════════════════════════════════════════════
  
  async function startHunting() {
    if (!canHunt) return;
    
    hunterPhase = 'scanning';
    
    try {
      // Fetch available targets from backend
      const targets = await fetchDetectionTargets();
      detectionTargets = targets;
      hunterPhase = 'idle';
      
    } catch (error) {
      hunterPhase = 'idle';
      throw error;
    }
  }
  
  function selectTarget(target: DetectionTarget) {
    selectedTarget = target;
  }
  
  async function beginDetection() {
    if (!selectedTarget || hunterPhase !== 'idle') return;
    
    hunterPhase = 'detecting';
    detectionPhase = 'pattern';
    detectionScores = { pattern: 0, behavior: 0, timing: 0, total: 0 };
    phaseTimeRemaining = 15; // 15 seconds for pattern phase
    
    startPhaseTimer();
  }
  
  // ═══════════════════════════════════════════════════════════════
  // DETECTION MINI-GAME
  // ═══════════════════════════════════════════════════════════════
  
  function submitPatternAnswer(selectedTimestamp: string) {
    if (detectionPhase !== 'pattern') return;
    
    // Score based on correctness (would be verified server-side)
    const isCorrect = verifyPatternAnswer(selectedTimestamp);
    detectionScores.pattern = isCorrect ? 80 + Math.random() * 20 : 30 + Math.random() * 30;
    
    // Move to next phase
    detectionPhase = 'behavior';
    phaseTimeRemaining = 20;
    resetPhaseTimer();
  }
  
  function submitBehaviorAnswer(selectedAddress: string) {
    if (detectionPhase !== 'behavior') return;
    
    // Score based on match percentage
    const matchScore = calculateBehaviorMatch(selectedAddress);
    detectionScores.behavior = matchScore;
    
    // Move to timing phase
    detectionPhase = 'timing';
    phaseTimeRemaining = 10;
    resetPhaseTimer();
    startTimingGame();
  }
  
  let timingHits = $state(0);
  let timingRequired = 5;
  let blipVisible = $state(false);
  let blipTimeout: ReturnType<typeof setTimeout> | null = null;
  
  function startTimingGame() {
    timingHits = 0;
    scheduleNextBlip();
  }
  
  function scheduleNextBlip() {
    if (detectionPhase !== 'timing') return;
    
    const delay = 500 + Math.random() * 2000; // 0.5-2.5 seconds
    blipTimeout = setTimeout(() => {
      blipVisible = true;
      
      // Blip disappears after 400ms
      setTimeout(() => {
        blipVisible = false;
        if (detectionPhase === 'timing') {
          scheduleNextBlip();
        }
      }, 400);
    }, delay);
  }
  
  function handleTimingClick() {
    if (detectionPhase !== 'timing') return;
    
    if (blipVisible) {
      timingHits++;
      blipVisible = false;
      
      if (timingHits >= timingRequired) {
        detectionScores.timing = 85 + Math.random() * 15;
        completeDetection();
      } else {
        scheduleNextBlip();
      }
    } else {
      // Clicked when no blip - penalty
      timingHits = Math.max(0, timingHits - 1);
    }
  }
  
  async function completeDetection() {
    if (blipTimeout) {
      clearTimeout(blipTimeout);
      blipTimeout = null;
    }
    stopPhaseTimer();
    
    detectionPhase = 'calculating';
    
    // Calculate total score
    detectionScores.total = Math.round(
      (detectionScores.pattern * 0.4) +
      (detectionScores.behavior * 0.35) +
      (detectionScores.timing * 0.25)
    );
    
    try {
      // Submit to contract
      const proof = {
        shadowId: selectedTarget!.shadowId,
        patternScore: Math.round(detectionScores.pattern),
        behaviorScore: Math.round(detectionScores.behavior),
        timingScore: Math.round(detectionScores.timing),
        commitmentHash: generateCommitmentHash(),
        timestamp: Date.now()
      };
      
      const tx = await sendTransaction('attemptDetection', [proof]);
      const receipt = await tx.wait();
      
      // Check result from events
      const detected = parseDetectionResult(receipt);
      
      if (detected) {
        hunterPhase = 'success';
        await refreshHunterState();
      } else {
        hunterPhase = 'failed';
        // Start cooldown timer
      }
      
    } catch (error) {
      hunterPhase = 'idle';
      throw error;
    }
  }
  
  function resetDetection() {
    hunterPhase = 'idle';
    detectionPhase = null;
    selectedTarget = null;
    detectionScores = { pattern: 0, behavior: 0, timing: 0, total: 0 };
  }
  
  // ═══════════════════════════════════════════════════════════════
  // TIMERS
  // ═══════════════════════════════════════════════════════════════
  
  function startCountdown() {
    if (!browser || !shadowState) return;
    
    countdownInterval = setInterval(() => {
      const now = Date.now();
      timeRemaining = Math.max(0, Math.floor((shadowState!.expiresAt - now) / 1000));
      
      // Update detection risk based on time
      const elapsed = now - shadowState!.activatedAt;
      const elapsedMinutes = elapsed / 60000;
      detectionRisk = Math.min(100, 
        30 + (elapsedMinutes * 0.5) + (shadowState!.failedDetections * 5)
      );
      
      if (timeRemaining <= 0) {
        stopCountdown();
        shadowPhase = 'inactive';
        shadowState = null;
      }
    }, 1000);
  }
  
  function stopCountdown() {
    if (countdownInterval) {
      clearInterval(countdownInterval);
      countdownInterval = null;
    }
  }
  
  function startPhaseTimer() {
    if (!browser) return;
    
    phaseTimer = setInterval(() => {
      phaseTimeRemaining--;
      
      if (phaseTimeRemaining <= 0) {
        handlePhaseTimeout();
      }
    }, 1000);
  }
  
  function stopPhaseTimer() {
    if (phaseTimer) {
      clearInterval(phaseTimer);
      phaseTimer = null;
    }
  }
  
  function resetPhaseTimer() {
    stopPhaseTimer();
    startPhaseTimer();
  }
  
  function handlePhaseTimeout() {
    // Assign low score for timed-out phase
    if (detectionPhase === 'pattern') {
      detectionScores.pattern = 20 + Math.random() * 20;
      detectionPhase = 'behavior';
      phaseTimeRemaining = 20;
    } else if (detectionPhase === 'behavior') {
      detectionScores.behavior = 20 + Math.random() * 20;
      detectionPhase = 'timing';
      phaseTimeRemaining = 10;
      startTimingGame();
    } else if (detectionPhase === 'timing') {
      detectionScores.timing = (timingHits / timingRequired) * 100;
      completeDetection();
    }
  }
  
  // ═══════════════════════════════════════════════════════════════
  // WEBSOCKET / DATA FETCHING
  // ═══════════════════════════════════════════════════════════════
  
  function connect() {
    if (!browser) return;
    
    const ws = new WebSocket('wss://api.ghostnet.io/shadow');
    
    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      
      switch (data.type) {
        case 'SHADOW_STATE':
          if (data.shadow) {
            shadowState = data.shadow;
            shadowPhase = 'active';
            startCountdown();
          }
          break;
          
        case 'HUNTER_STATE':
          hunterState = data.hunter;
          break;
          
        case 'NETWORK_STATS':
          networkStats = data.stats;
          break;
          
        case 'SHADOW_DETECTED':
          if (data.shadow === getCurrentUserAddress()) {
            shadowPhase = 'exposed';
            shadowState = null;
            stopCountdown();
          }
          networkStats.recentDetections = [
            data.detection,
            ...networkStats.recentDetections.slice(0, 9)
          ];
          break;
          
        case 'DETECTION_FAILED':
          if (shadowState && data.shadowId === shadowState.shadowId) {
            shadowState.failedDetections++;
            shadowState.detectionThreshold += 5;
            shadowState.bountyPool += BigInt(data.bountyIncrease);
          }
          break;
      }
    };
    
    ws.onopen = () => { isConnected = true; };
    ws.onclose = () => { isConnected = false; };
    
    return () => {
      ws.close();
      stopCountdown();
      stopPhaseTimer();
    };
  }
  
  async function refreshShadowState() {
    // Fetch from contract
  }
  
  async function refreshHunterState() {
    // Fetch from contract
  }
  
  async function fetchDetectionTargets(): Promise<DetectionTarget[]> {
    // Fetch from backend API
    return [];
  }
  
  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════
  
  function verifyPatternAnswer(timestamp: string): boolean {
    // Would be verified server-side
    return Math.random() > 0.3;
  }
  
  function calculateBehaviorMatch(address: string): number {
    // Would be calculated server-side
    return 40 + Math.random() * 60;
  }
  
  function generateCommitmentHash(): string {
    return '0x' + Array.from(crypto.getRandomValues(new Uint8Array(32)))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');
  }
  
  function parseDetectionResult(receipt: unknown): boolean {
    // Parse transaction receipt for detection result
    return Math.random() > 0.5;
  }
  
  function getCurrentUserAddress(): string {
    return ''; // Get from wallet
  }
  
  async function sendTransaction(method: string, args: unknown[]): Promise<{ wait: () => Promise<unknown> }> {
    // Contract interaction
    return { wait: async () => ({}) };
  }
  
  // ═══════════════════════════════════════════════════════════════
  // RETURN
  // ═══════════════════════════════════════════════════════════════
  
  return {
    // Shadow state
    get shadowPhase() { return shadowPhase; },
    get shadowState() { return shadowState; },
    get timeRemaining() { return timeRemaining; },
    get formattedTimeRemaining() { return formattedTimeRemaining; },
    get detectionRisk() { return detectionRisk; },
    get detectionRiskLevel() { return detectionRiskLevel; },
    
    // Shadow derived
    get canActivateShadow() { return canActivateShadow; },
    get canExtendShadow() { return canExtendShadow; },
    get canExitShadow() { return canExitShadow; },
    
    // Hunter state
    get hunterPhase() { return hunterPhase; },
    get hunterState() { return hunterState; },
    get detectionTargets() { return detectionTargets; },
    get selectedTarget() { return selectedTarget; },
    get canHunt() { return canHunt; },
    
    // Detection game state
    get detectionPhase() { return detectionPhase; },
    get detectionScores() { return detectionScores; },
    get phaseTimeRemaining() { return phaseTimeRemaining; },
    get blipVisible() { return blipVisible; },
    get timingHits() { return timingHits; },
    get timingRequired() { return timingRequired; },
    
    // Network state
    get networkStats() { return networkStats; },
    get isConnected() { return isConnected; },
    
    // Shadow actions
    activateShadow,
    extendShadow,
    exitShadow,
    
    // Hunter actions
    startHunting,
    selectTarget,
    beginDetection,
    resetDetection,
    
    // Detection game actions
    submitPatternAnswer,
    submitBehaviorAnswer,
    handleTimingClick,
    
    // Connection
    connect
  };
}
```

---

## Visual Design

### Color Scheme

```css
.shadow-protocol {
  /* Shadow mode - dark, secretive */
  --shadow-bg: #0a0a0a;
  --shadow-primary: #1a1a2e;
  --shadow-accent: #4a0080;
  --shadow-glow: rgba(74, 0, 128, 0.4);
  --shadow-text: #8866aa;
  
  /* Cloaked state */
  --cloak-color: #2d1b4e;
  --cloak-pulse: #6b3fa0;
  
  /* Hunter mode - aggressive, scanning */
  --hunter-bg: #0a0f0a;
  --hunter-primary: #00ff41;
  --hunter-accent: #00cc33;
  --hunter-scan: rgba(0, 255, 65, 0.2);
  
  /* Detection states */
  --detect-pattern: #00ffff;
  --detect-behavior: #ffff00;
  --detect-timing: #ff00ff;
  
  /* Results */
  --success-color: #00ff00;
  --failure-color: #ff0040;
  --exposed-color: #ff0000;
  --bounty-color: #ffd700;
}
```

### Animations

**Shadow Cloak Effect:**
```css
@keyframes shadow-cloak {
  0% {
    opacity: 0.3;
    filter: blur(2px);
  }
  50% {
    opacity: 0.6;
    filter: blur(4px);
  }
  100% {
    opacity: 0.3;
    filter: blur(2px);
  }
}

.shadow-active {
  animation: shadow-cloak 3s ease-in-out infinite;
}
```

**Detection Scan Effect:**
```css
@keyframes hunter-scan {
  0% {
    transform: translateY(-100%);
    opacity: 0;
  }
  50% {
    opacity: 0.8;
  }
  100% {
    transform: translateY(100%);
    opacity: 0;
  }
}

.scan-line {
  background: linear-gradient(
    180deg,
    transparent 0%,
    var(--hunter-scan) 50%,
    transparent 100%
  );
  animation: hunter-scan 2s linear infinite;
}
```

**Exposure Flash:**
```css
@keyframes exposed-flash {
  0%, 100% {
    background: var(--shadow-bg);
  }
  10%, 30%, 50% {
    background: var(--exposed-color);
  }
  20%, 40% {
    background: var(--shadow-bg);
  }
}

.shadow-exposed {
  animation: exposed-flash 1s ease-out;
}
```

**Blip Pulse (Timing Game):**
```css
@keyframes blip-pulse {
  0% {
    transform: scale(0);
    opacity: 0;
  }
  30% {
    transform: scale(1.2);
    opacity: 1;
  }
  100% {
    transform: scale(1);
    opacity: 1;
  }
}

.timing-blip {
  animation: blip-pulse 0.15s ease-out forwards;
}
```

---

## Sound Design

| Event | Sound | Description |
|-------|-------|-------------|
| Shadow Activate | Low drone fade-in | Descending tone, world goes quiet |
| Shadow Heartbeat | Subtle pulse | Slow, rhythmic, increases with risk |
| Detection Risk High | Warning hum | Tension building |
| Scan Evaded | Whisper swoosh | Relief, close call |
| Shadow Extended | Power-up drone | Darkness deepens |
| Shadow Exit | Fade-up whoosh | Returning to light |
| Hunter Mode Enter | Scanner boot | Electronic initialization |
| Scanning Targets | Radar ping | Searching sound |
| Detection Start | Lock-on tone | Target acquired |
| Pattern Phase | Data processing | Sorting, analyzing |
| Behavior Phase | Heartbeat scan | Biological analysis |
| Timing Blip | Sharp ping | Quick, reactive |
| Timing Hit | Confirmation beep | Success feedback |
| Timing Miss | Error buzz | Failure feedback |
| Detection Success | Alarm + fanfare | Target exposed! |
| Detection Failed | Power-down | Lost the trail |
| Bounty Claimed | Cash register | Reward sound |
| Being Exposed | Alarm siren | Panic, caught! |

---

## Feed Integration

```
> 0x7a3f entered the SHADOW - disappeared from network 👻
> ░░░░░░░░░░░░░░░░░░░░░░░░░░ [3 active shadows] 
> 0x9c2d DETECTED shadow 0x7a3f - claimed 680 $DATA bounty 🎯
> 🔥 0x7a3f EXPOSED in shadow mode - lost 5,000 $DATA (2x penalty) 🔥
> 0x3b1a survived 4 hours in shadow - extracted safely 👤
> Hunter 0x8f2e achieved 10 successful detections - SHADOW HUNTER rank 🏆
> ░░░ HIGH VALUE SHADOW ACTIVE - estimated bounty >1,000 $DATA ░░░
> 0x1d4c extended shadow duration - bounty now 850 $DATA
> Detection attempt on unknown shadow FAILED - they're still out there...
```

### Feed Visibility Rules

```
SHADOW PLAYERS:
├── Activation: Shown (address only, "entered shadow")
├── Activity while shadowed: HIDDEN
├── Exposure: Shown (dramatic reveal)
└── Clean exit: Shown (address only, "exited shadow")

HUNTERS:
├── Scanning: Not shown
├── Detection attempts: Not shown (until result)
├── Successful detection: Shown (both parties)
└── Failed detection: Vague mention only

NETWORK:
├── Shadow count: Shown (aggregate only)
├── Total bounty pool: Shown (aggregate only)
├── High-value shadow alerts: Shown (no address)
└── Hunter leaderboard updates: Shown
```

---

## Testing Checklist

### Smart Contract Tests
- [ ] Shadow activation with valid parameters
- [ ] Shadow activation rejected without sufficient position
- [ ] Shadow activation rejected if already in shadow
- [ ] Shadow extension within time limits
- [ ] Shadow extension rejected if would exceed 4 hours
- [ ] Shadow exit clears all state correctly
- [ ] Detection with valid proof succeeds when score >= threshold
- [ ] Detection fails correctly when score < threshold
- [ ] Failed detection increases shadow threshold
- [ ] Failed detection increases bounty pool
- [ ] Hunter cooldown enforced after failed detection
- [ ] Cannot hunt yourself
- [ ] Bounty paid correctly on successful detection
- [ ] Position liquidated at 2x on exposure
- [ ] Integration with GHOSTNET core (trace scan immunity)

### Frontend Tests
- [ ] Shadow activation flow (confirm, transaction, state update)
- [ ] Shadow timer countdown accuracy
- [ ] Detection risk calculation and display
- [ ] Hunter target list loads correctly
- [ ] Detection mini-game Phase 1 (pattern) works
- [ ] Detection mini-game Phase 2 (behavior) works
- [ ] Detection mini-game Phase 3 (timing) works
- [ ] Phase timeouts handled correctly
- [ ] Detection result displayed correctly
- [ ] WebSocket reconnection handling
- [ ] Mobile touch support for timing game
- [ ] Exposed state transition (for victim)

### Integration Tests
- [ ] Shadow hides player from trace scans
- [ ] Shadow hides player from live feed
- [ ] Detection events appear in feed
- [ ] Bounty pool updates in real-time
- [ ] Network stats reflect actual state
- [ ] Multiple simultaneous shadows handled
- [ ] Multiple hunters can target same shadow

### Performance Tests
- [ ] Timing game runs at 60fps
- [ ] Blip detection latency < 50ms
- [ ] 100+ simultaneous shadows supported
- [ ] 500+ concurrent hunters supported
- [ ] WebSocket handles high message volume

### Security Tests
- [ ] Detection proofs cannot be frontrun
- [ ] Commitment scheme prevents replay attacks
- [ ] Rate limiting on detection attempts
- [ ] No information leakage about shadow identity
- [ ] Cannot manipulate detection scores client-side
