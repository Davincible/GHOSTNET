# Hash Crash Visual Themes

## Overview

Hash Crash supports two visual themes that transform the generic "crash game" into an immersive GHOSTNET experience. Both themes use the same underlying game mechanics but present the action through different metaphors.

**Core Principle:** The multiplier climbing represents your hack going deeper into a network. The "crash" is when ICE (Intrusion Countermeasures Electronics) detects you. Your "target" is your planned extraction point - get out before you're traced.

---

## Theme A: Network Penetration

### Concept

You're breaching through network security layers. The visualization shows horizontal progress through firewalls, with your extraction point marked. ICE detection builds as you go deeper.

### Visual Layout

```
╔══════════════════════════════════════════════════════════════════════════╗
║  ICE BREAKER v0.7.3            ░░░ ROUND #4,847 ░░░           [?] [X]   ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  ┌─────────────────────────────────────────────────────────────────────┐ ║
║  │  PENETRATION DEPTH                                                  │ ║
║  │                                                                     │ ║
║  │     2.31x                                                           │ ║
║  │                                                                     │ ║
║  │  ╔═══════════════════════════════════════════════════════════════╗ │ ║
║  │  ║▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░║ │ ║
║  │  ╚═══════════════════════════════════════════════════════════════╝ │ ║
║  │   1.00x          ↑              ↑                           10.00x │ ║
║  │              CURRENT        YOUR EXIT                              │ ║
║  │               2.31x          3.00x                                 │ ║
║  │                                                                     │ ║
║  │  ┌─────────────────────────────────────────────────────────────┐   │ ║
║  │  │ > Penetrating subnet layer 3...                             │   │ ║
║  │  │ > Firewall bypass: 67% complete                             │   │ ║
║  │  │ > ICE signature detected in sector 7G                       │   │ ║
║  │  │ > Extracting data packets...                                │   │ ║
║  │  └─────────────────────────────────────────────────────────────┘   │ ║
║  │                                                                     │ ║
║  │  ICE THREAT:  ▓▓▓▓▓▓▓░░░░░░░░░  43%   [!] CAUTION               │ ║
║  │                                                                     │ ║
║  └─────────────────────────────────────────────────────────────────────┘ ║
║                                                                          ║
║  ┌─ YOUR POSITION ──────────────────────────────────────────────────────┐║
║  │  BET: 100 $DATA    EXIT: 3.00x    PAYOUT: 300 $DATA    WIN: 61%    │║
║  └──────────────────────────────────────────────────────────────────────┘║
║                                                                          ║
║  RECENT TRACES: 1.23x │ 4.56x │ 12.34x │ 1.01x │ 89.12x                 ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

### Components

#### 1. Penetration Bar
- **Horizontal progress bar** showing depth from 1.00x to dynamic max
- **Filled portion** = current multiplier position
- **Two markers:**
  - Current position (animated, pulsing)
  - Your exit point (static, dashed line)
- **Color progression:**
  - Green (1.00x - 2.00x): Safe zone
  - Cyan (2.00x - 5.00x): Active zone  
  - Amber (5.00x - 10.00x): Danger zone
  - Red (10.00x+): Critical zone

#### 2. Depth Display
- Large monospace number showing current depth
- Slight scale animation as it increases
- Glow effect intensifies with depth

#### 3. Terminal Log
- Scrolling messages that add atmosphere:
  ```
  > Initiating breach sequence...
  > Layer 1 firewall bypassed
  > Scanning for ICE signatures...
  > WARNING: Anomaly detected in sector 4F
  > Extracting target data...
  > Connection holding stable...
  ```
- Messages contextual to current phase and depth

#### 4. ICE Threat Meter
- Secondary progress bar showing "danger level"
- Fills based on current depth vs. your target
- Changes color: green → amber → red
- At 100% = crash imminent

#### 5. Status Indicators
- **Pre-exit:** "PENETRATING..."
- **At exit point:** "EXIT AVAILABLE - EXTRACT NOW" (flashing)
- **Past exit:** "BEYOND EXIT - RIDING THE EDGE"
- **Traced:** "████ TRACED ████" with glitch effect

### Animation Sequences

#### Breach Start
```
> INITIATING BREACH PROTOCOL...
> Target: SUBNET-7G
> Encryption: AES-256-GCM
> Status: CONNECTED
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
```

#### During Penetration
- Bar fills smoothly left-to-right
- Terminal messages scroll
- ICE threat meter climbs
- Depth number ticks up

#### Passing Exit Point (WIN moment)
```
╔══════════════════════════════════════════════════╗
║         ✓ EXIT POINT REACHED - YOU'RE SAFE       ║
║                                                   ║
║    Continue for higher extraction value...        ║
║    or watch others get TRACED                     ║
╚══════════════════════════════════════════════════╝
```
- Flash of green
- "SAFE" sound effect
- Terminal: `> EXIT NODE SECURED - EXTRACTION GUARANTEED`

#### Trace (CRASH moment)
```
████████████████████████████████████████████████████
██                                                ██
██    ⚠ ICE DETECTED - BREACH TERMINATED ⚠       ██
██                                                ██
██         TRACED @ 3.47x DEPTH                   ██
██                                                ██
████████████████████████████████████████████████████
```
- Screen flash red
- Glitch effect on all text
- Static/noise overlay
- Terminal: `> CONNECTION SEVERED`, `> TRACE LOCK ACQUIRED`, `> EXTRACTION FAILED`

---

## Theme B: Data Stream

### Concept

You're extracting data from a target system. The visualization shows data flowing and accumulating, with the exponential curve representing extraction speed/volume. A cascading data stream adds atmosphere.

### Visual Layout

```
╔══════════════════════════════════════════════════════════════════════════╗
║  DATA EXTRACTION v0.7.3        ░░░ ROUND #4,847 ░░░           [?] [X]   ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  ┌─ DATA STREAM ─┬─ EXTRACTION RATE ────────────────────────────────────┐║
║  │               │                                                      │║
║  │ 0x7a3f9c2d   │                                    5.67x             │║
║  │ 4b8e1d4c3b   │                                   ▲                  │║
║  │ 9f2e8a7b6c   │                                  ██                  │║
║  │ 2c1d0e9f8a   │                                ███                   │║
║  │ 8b7a6c5d4e   │        YOUR TARGET ──────────███── 3.00x             │║
║  │ 1e0f9a8b7c   │        ─────────────────────███                      │║
║  │ 5d4e3c2b1a   │                           ████     ✓ SAFE            │║
║  │ 9a8b7c6d5e   │                        █████                         │║
║  │ 3c2b1a0f9e   │                     ██████                           │║
║  │ 7c6d5e4f3a   │                 ████████                             │║
║  │ 1a0f9e8d7c   │            ████████████                              │║
║  │ 5e4f3a2b1c   │      ██████████████████                              │║
║  │ ░░░░░░░░░░░░ │  ════════════════════════════════════════════════   │║
║  │              │  0s                                            30s   │║
║  └──────────────┴──────────────────────────────────────────────────────┘║
║                                                                          ║
║  EXTRACTED: 2.31 GB    RATE: 847 MB/s    ICE SCAN: ▓▓▓▓░░░░░░ 38%      ║
║                                                                          ║
║  ┌─ YOUR EXTRACTION ────────────────────────────────────────────────────┐║
║  │  BET: 100 $DATA    TARGET: 3.00x    PAYOUT: 300 $DATA    WIN: 61%  │║
║  └──────────────────────────────────────────────────────────────────────┘║
║                                                                          ║
║  RECENT TRACES: 1.23x │ 4.56x │ 12.34x │ 1.01x │ 89.12x                 ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

### Components

#### 1. Data Stream Column
- **Scrolling hex/address data** on the left
- Creates "Matrix rain" effect but horizontal
- Speed increases with multiplier
- Different colors for different "data types":
  - Green: Normal data packets
  - Cyan: High-value data
  - Amber: Encrypted chunks
  - Red: ICE signatures (warning)

#### 2. Extraction Chart
- **Exponential curve** (like current) but styled:
  - ASCII grid lines
  - Scanline overlay
  - Glow effect on the curve
- **Y-axis**: Extraction rate (1x - Nx)
- **X-axis**: Time elapsed
- **Target line**: Horizontal dashed line at player's target

#### 3. Metrics Bar
- **EXTRACTED**: Shows "data volume" (multiplier as GB)
- **RATE**: Current extraction speed (animated)
- **ICE SCAN**: Threat level meter

#### 4. Status Indicators
- Current multiplier with glow
- "SAFE" badge when past target
- Data extraction sounds

### Data Stream Generation

```typescript
// Generate scrolling data
const dataPatterns = [
  // Hex addresses
  () => `0x${randomHex(8)}`,
  // Binary chunks
  () => randomBinary(12),
  // File paths
  () => `/sys/${randomWord()}/${randomHex(4)}.dat`,
  // Memory addresses  
  () => `[${randomHex(4)}:${randomHex(4)}]`,
  // Encrypted blocks
  () => `█${randomHex(6)}█`,
];

// Color based on content
function getDataColor(data: string): string {
  if (data.includes('█')) return 'amber';  // Encrypted
  if (data.startsWith('0x')) return 'green';
  if (data.includes('/')) return 'cyan';
  return 'dim';
}
```

### Animation Sequences

#### Extraction Start
```
> CONNECTING TO TARGET...
> Establishing secure tunnel...
> Bypass protocols: ACTIVE
> Beginning data extraction...
```
- Data stream starts flowing
- Curve begins at 1.00x

#### During Extraction
- Data scrolls continuously (speed increases)
- Curve grows exponentially
- Occasional "high value" data flashes cyan
- ICE scan meter slowly fills

#### Target Reached (WIN)
```
┌──────────────────────────────────────┐
│  ✓ TARGET EXTRACTION COMPLETE        │
│                                      │
│    Your data is secured.             │
│    Watching others' extractions...   │
└──────────────────────────────────────┘
```
- Green flash on target line
- Data stream shows: `> PAYLOAD SECURED`
- "Safe" chime sound

#### Trace (CRASH)
```
> ████ ICE DETECTED ████
> TRACE LOCK: CONFIRMED  
> CONNECTION: SEVERED
> EXTRACTION: FAILED

    ▓▓▓ TRACED @ 3.47x ▓▓▓
```
- Data stream corrupts (garbled characters)
- Red glitch effect
- Chart freezes with static
- "Flatline" sound

---

## Shared Elements

### Terminal Effects

Both themes share these atmospheric effects:

#### 1. CRT Scanlines
```css
.theme-overlay::before {
  content: "";
  position: absolute;
  inset: 0;
  background: repeating-linear-gradient(
    0deg,
    transparent 0px,
    transparent 1px,
    rgba(0, 255, 0, 0.03) 1px,
    rgba(0, 255, 0, 0.03) 2px
  );
  pointer-events: none;
  z-index: 100;
}
```

#### 2. Screen Flicker
```css
@keyframes terminal-flicker {
  0%, 100% { opacity: 1; }
  92% { opacity: 1; }
  93% { opacity: 0.9; }
  94% { opacity: 1; }
  97% { opacity: 0.95; }
  98% { opacity: 1; }
}
```

#### 3. Glitch Effect (on crash)
```css
@keyframes glitch {
  0% { transform: translate(0); }
  20% { transform: translate(-2px, 2px); }
  40% { transform: translate(-2px, -2px); }
  60% { transform: translate(2px, 2px); }
  80% { transform: translate(2px, -2px); }
  100% { transform: translate(0); }
}

.glitch-text {
  animation: glitch 0.3s ease-in-out;
  text-shadow: 
    2px 0 var(--color-red),
    -2px 0 var(--color-cyan);
}
```

#### 4. Red Flash (on trace)
```css
@keyframes trace-flash {
  0% { background: transparent; }
  15% { background: rgba(255, 0, 0, 0.3); }
  30% { background: transparent; }
  45% { background: rgba(255, 0, 0, 0.2); }
  60% { background: transparent; }
  100% { background: transparent; }
}
```

### Terminology Mapping

| Generic Term | GHOSTNET Term |
|--------------|---------------|
| Multiplier | Extraction Depth / Penetration Level |
| Crash | Traced / ICE Detected |
| Crash Point | Trace Point / ICE Threshold |
| Target | Exit Point / Extraction Target |
| Cash Out | Extract / Exit |
| Bet | Stake / Entry Fee |
| Win | Safe / Extracted |
| Lose | Traced / Burned |

### Sound Design

| Event | Sound |
|-------|-------|
| Round Start | Low digital hum building |
| Data Flowing | Soft data transfer clicks |
| Multiplier Rising | Pitch increases with value |
| Approaching Target | Tension pulse |
| Target Reached | Triumphant "secure" chime |
| Danger Zone | Warning klaxon (subtle) |
| Crash/Trace | Alarm + flatline + static |
| Win Result | Victory cha-ching |
| Loss Result | Deflating buzz + disconnect |

---

## Implementation Plan

### Phase 1: Infrastructure
1. Create theme context/store for theme selection
2. Build shared terminal effect components (Scanlines, Glitch, Flash)
3. Create base game container with theme slots

### Phase 2: Theme A - Network Penetration
1. `PenetrationBar.svelte` - Horizontal progress visualization
2. `DepthDisplay.svelte` - Large multiplier with glow
3. `TerminalLog.svelte` - Scrolling status messages
4. `IceThreatMeter.svelte` - Danger level indicator
5. `NetworkPenetrationTheme.svelte` - Composed layout

### Phase 3: Theme B - Data Stream
1. `DataStream.svelte` - Scrolling hex/data column
2. `ExtractionChart.svelte` - Styled exponential curve
3. `MetricsBar.svelte` - Extracted/Rate/ICE display
4. `DataStreamTheme.svelte` - Composed layout

### Phase 4: Polish
1. Add sound effects integration
2. Refine animations and timing
3. Add theme switcher in settings
4. Test on various screen sizes

---

## File Structure

```
apps/web/src/lib/features/hash-crash/
├── components/
│   ├── themes/
│   │   ├── NetworkPenetration/
│   │   │   ├── PenetrationBar.svelte
│   │   │   ├── DepthDisplay.svelte
│   │   │   ├── TerminalLog.svelte
│   │   │   ├── IceThreatMeter.svelte
│   │   │   └── index.svelte
│   │   │
│   │   ├── DataStream/
│   │   │   ├── DataStreamColumn.svelte
│   │   │   ├── ExtractionChart.svelte
│   │   │   ├── MetricsBar.svelte
│   │   │   └── index.svelte
│   │   │
│   │   └── shared/
│   │       ├── Scanlines.svelte
│   │       ├── GlitchEffect.svelte
│   │       ├── TraceFlash.svelte
│   │       ├── StatusBadge.svelte
│   │       └── RecentTraces.svelte
│   │
│   ├── HashCrashGame.svelte      # Main game container
│   ├── BettingPanel.svelte       # Bet placement UI
│   └── LivePlayersPanel.svelte   # Other players
│
├── store.svelte.ts               # Game state management
├── theme.svelte.ts               # Theme selection store
├── messages.ts                   # Terminal message library
└── index.ts                      # Exports
```

---

## Theme Selection

Users can select their preferred theme in settings:

```typescript
// theme.svelte.ts
export type HashCrashTheme = 'network-penetration' | 'data-stream';

export function createThemeStore() {
  let theme = $state<HashCrashTheme>('network-penetration');
  
  // Persist to localStorage
  if (browser) {
    const saved = localStorage.getItem('hashcrash-theme');
    if (saved === 'data-stream') theme = 'data-stream';
  }
  
  return {
    get theme() { return theme; },
    set(newTheme: HashCrashTheme) {
      theme = newTheme;
      if (browser) {
        localStorage.setItem('hashcrash-theme', newTheme);
      }
    },
    toggle() {
      this.set(theme === 'network-penetration' ? 'data-stream' : 'network-penetration');
    }
  };
}
```

---

## Success Metrics

A successful implementation will:

1. **Feel native to GHOSTNET** - Uses terminal aesthetic, hacker terminology
2. **Enhance tension** - ICE threat meter, warning messages build suspense
3. **Reward attention** - Scrolling data, status messages keep eyes engaged
4. **Clear game state** - Always know: current depth, your target, win/loss status
5. **Satisfying feedback** - Sounds, flashes, animations for key moments
