# 10. GHOST MAZE

**Category:** Skill  
**Entry:** 25-100 $DATA (burned via ArcadeCore)  
**Burn:** 100% entry  
**Players:** 1 (solo)  
**Session:** 3-5 minutes  
**Status:** Design  
**Route:** `/arcade/ghost-maze`

---

## 1. Overview

Ghost Maze is a Pac-Man-inspired network infiltration game rendered entirely in ASCII within the terminal aesthetic. The player controls a ghost (`@`) navigating procedurally generated mazes, collecting data packets (`·`), avoiding Tracers (`T`), and using Power Nodes (`◆`) for temporary invincibility. The game integrates with GHOSTNET's economy through entry burns and reward boosts.

### The Metaphor

You ARE the ghost in the network. The maze IS the hostile infrastructure. Tracers ARE the system hunting you. Data packets ARE the value you're extracting. Power Nodes activate Ghost Protocol — temporary invincibility. Every element maps 1:1 to GHOSTNET's core vocabulary.

### Why This Game

1. **Pac-Man is universally understood** — zero learning curve on the core mechanic
2. **Spatial reasoning + reflexes** — different skill type from typing games
3. **Perfect thematic fit** — ghosts, traces, data, network navigation
4. **ASCII renders beautifully** — box-drawing mazes are a natural fit for terminal aesthetic
5. **High streamability** — chase sequences, clutch power-ups, perfect clears are watchable
6. **Procedural generation** — infinite replayability via block-hash-seeded mazes

---

## 2. Game Mechanics

### 2.1 Core Loop

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   1. NAVIGATE        Move through maze with WASD / arrows      │
│         ↓                                                       │
│   2. COLLECT         Gather data packets for points + combo     │
│         ↓                                                       │
│   3. EVADE           Avoid Tracers or get caught (lose life)   │
│         ↓                                                       │
│   4. POWER UP        Grab Power Nodes for Ghost Mode           │
│         ↓                                                       │
│   5. CLEAR           Collect all data → next level             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Movement

- **Grid-based:** Player moves one cell per tick on a grid. Hold direction for continuous movement.
- **Controls:** `WASD` or `Arrow keys`. Vim keys (`hjkl`) as alternative.
- **Cornering:** Input is buffered — pressing a direction before reaching a junction queues the turn. This is critical for feel; Pac-Man clones without input buffering feel terrible.
- **Speed:** Player moves at a constant rate. Speed increases per level (see 2.8).
- **Collision:** Walls block movement. No sliding along walls — clean stops.

### 2.3 Data Packets (`·`)

- Small dots placed throughout the maze corridors.
- Collecting one awards **10 base points**.
- Collecting all data packets on a level = **level clear**.
- **Combo system:** Collecting packets without pause (within 500ms of each other) builds a combo counter. Combo multiplies points:
  - Combo 1-4: ×1
  - Combo 5-9: ×2
  - Combo 10-19: ×3
  - Combo 20-49: ×5
  - Combo 50+: ×10
- Combo resets after 500ms of no collection.
- Combo counter displayed in HUD: `COMBO: ×5 (23)`

### 2.4 Tracers (`T`)

AI enemies that patrol the maze. Contact with a Tracer = lose a life.

**Tracer Types:**

| Type | Symbol | Color | Behavior | Speed | Introduced |
|------|--------|-------|----------|-------|------------|
| Patrol | `T` | Red | Follows fixed route, clockwise circuit | 0.8× player | Level 1 |
| Hunter | `H` | Magenta | Pathfinds toward player when in line-of-sight | 0.9× player | Level 2 |
| Phantom | `P` | Cyan | Teleports to random position every 15s | 0.7× player (when moving) | Level 3 |
| Swarm | `s` | Yellow | Travels in pairs, faster but dumber | 1.0× player | Level 4 |

**Tracer AI Details:**

**Patrol Tracer:** Follows a pre-computed circuit of waypoints. Predictable. The player can learn the pattern and plan routes around it. At each waypoint, Patrol chooses the next waypoint from its circuit list.

**Hunter Tracer:** Has two modes:
- **Scatter mode** (default): Moves toward its "home corner" of the maze.
- **Chase mode** (activated when player is within 8 cells line-of-sight, no walls between): Uses A* pathfinding toward the player's current position. Pathfinding is recomputed every 500ms to avoid being too precise.
- Chase mode disengages after 5 seconds or when line-of-sight is broken.

**Phantom Tracer:** Moves slowly in a random walk. Every 15 seconds, vanishes (brief fade animation) and reappears at a random valid position on the maze at least 5 cells from the player. The teleport is preceded by a 1-second warning sound cue.

**Swarm Tracer:** Always travels in a pair. They use a simplified flocking behavior — both aim for the player but with slight offsets. They're faster but don't pathfind intelligently (no A*, just choose direction closest to player at each intersection). They can be separated by walls.

**Ghost Mode Behavior:** When player activates a Power Node, ALL Tracers enter "frightened" state:
- Visual: Render as `░` (dim/transparent) instead of their letter
- Speed: Reduced to 0.5× player speed
- Behavior: Reverse direction, then random walk (flee)
- Touchable: Player can pass through them to "destroy" them (200 points, Tracer respawns at home position after 15s)
- Duration: 8 seconds (flashes at 6s to warn it's ending)

### 2.5 Power Nodes (`◆`)

- 4 per level, placed near maze corners.
- Collecting one activates **Ghost Mode** for 8 seconds.
- During Ghost Mode:
  - Player renders as `@` with a glow effect (text-shadow pulse)
  - Ambient hum sound effect
  - Tracers become vulnerable (see above)
  - Destroying a Tracer in Ghost Mode: 200 points (first), 400 (second), 800 (third), 1600 (fourth) — doubling cascade
- Strategic decision: Use Power Nodes reactively (escape danger) or proactively (maximize Tracer kills for points).

### 2.6 EMP Ability

- **1 use per level.** Replenishes on level clear.
- Activated with `SPACE` or `E`.
- **Effect:** Freezes ALL Tracers in place for 5 seconds. They cannot move or detect the player.
- **Visual:** Brief screen flash, all Tracers render as `█` (solid, frozen).
- **Sound:** Low-frequency pulse wave.
- **Strategy:** Emergency escape tool. Save for when cornered, or use proactively to clear a dense area.

### 2.7 Lives

- Start with **3 lives** per run. Displayed as `♥♥♥` in HUD.
- Lose a life when touched by an active Tracer.
- On death:
  - Brief death animation (player flashes red, 0.5s)
  - Respawn at maze starting position
  - Tracers return to their home positions
  - 2-second invincibility window after respawn (player blinks)
  - Collected data packets remain collected
- Extra life awarded at 50,000 points (maximum 5 lives).
- All lives lost = game over. Score is final.

### 2.8 Level Progression

5 levels per run. Each level introduces new challenges:

| Level | Grid Size | Tracers | Data Packets | Player Speed | Theme |
|-------|-----------|---------|--------------|-------------|-------|
| 1 | 21×15 | 2 Patrol | 60 | 1.0× | MAINFRAME |
| 2 | 25×17 | 2 Patrol + 1 Hunter | 90 | 1.1× | SUBNET |
| 3 | 29×19 | 2 Patrol + 1 Hunter + 1 Phantom | 120 | 1.2× | DARKNET |
| 4 | 33×21 | 1 Patrol + 1 Hunter + 1 Phantom + 2 Swarm | 150 | 1.3× | BLACK ICE |
| 5 | 37×23 | 2 Hunter + 1 Phantom + 4 Swarm | 200 | 1.5× | CORE |

**Level transition:**
1. All data collected → brief celebration (1s)
2. "LEVEL CLEAR" text display with score tally
3. Time bonus calculated (remaining time × 50 points)
4. Transition animation (maze dissolves, new maze builds)
5. New level begins with full EMP charge

**Grid sizing note:** These grids are designed for a rendering area of approximately 80×40 characters. On smaller viewports, the game scales by reducing grid size while maintaining the same number of data packets (denser placement). See Section 5.

### 2.9 Scoring

```
DATA PACKET:            10 points × combo_multiplier
TRACER DESTROYED:       200 → 400 → 800 → 1600 (cascade per Ghost Mode activation)
LEVEL CLEAR:            1,000 × level_number
PERFECT CLEAR:          5,000 × level_number (all data + all Tracers destroyed in level)
TIME BONUS:             remaining_seconds × 50 (per level)
NO-HIT BONUS:           2,000 per level (never touched by Tracer in that level)
FULL RUN CLEAR:         25,000 (complete all 5 levels)
FULL RUN PERFECT:       100,000 (perfect clear all 5 levels — extremely rare)
```

**Score thresholds for economy rewards (see Section 4):**

| Threshold | Achievement |
|-----------|------------|
| 10,000 | Survived (participated meaningfully) |
| 25,000 | Competent (cleared 2-3 levels) |
| 50,000 | Skilled (cleared 4+ levels or excelled) |
| 100,000 | Expert (cleared all 5, good performance) |
| 200,000 | Master (near-perfect run) |

---

## 3. Maze Generation

### 3.1 Algorithm

Mazes are procedurally generated to ensure every run is unique while maintaining quality gameplay.

**Algorithm: Recursive Backtracker + Post-Processing**

1. **Generate base maze** using recursive backtracker (depth-first search):
   - Start from random cell
   - Carve passages by removing walls between cells
   - Produces a perfect maze (exactly one path between any two points)

2. **Add loops** (critical for gameplay — perfect mazes are bad for Pac-Man):
   - Remove 15-25% of walls randomly to create multiple paths
   - Ensure no dead-end corridors longer than 3 cells (anti-frustration)
   - Preference for creating loops near the center (more action in the middle)

3. **Place elements:**
   - **Player spawn:** Bottom center
   - **Tracer spawns:** Distributed in corners/edges, at least 8 cells from player
   - **Power Nodes:** One near each corner quadrant
   - **Data packets:** All remaining corridor cells

4. **Validate:**
   - All cells reachable from player spawn
   - No isolated sections
   - Minimum path distance between player spawn and each Tracer spawn ≥ 8 cells

### 3.2 Seeding

Maze generation is seeded from block hashes for provable fairness:

```typescript
// Seed derivation
function deriveMazeSeed(blockHash: string, level: number, sessionId: number): number {
  const combined = keccak256(
    encodePacked(blockHash, uint8(level), uint256(sessionId))
  );
  return Number(BigInt(combined) % BigInt(2 ** 32));
}
```

This means:
- Same block hash + level + session = same maze layout
- Players can verify their maze was fair
- Different levels in the same run get different mazes (level included in seed)

### 3.3 Rendering

The maze is rendered using box-drawing characters:

```
╔══════════╗     ╔══════════╗
║ · · · · ·║     ║          ║
║ · ╔═══╗ ·║     ║   ═══╗   ║
║ · ║   ║ ·║  →  ║   ║   ║   ║  (walls use double-line box drawing)
║ · ╚═══╝ ·║     ║   ╚═══╝   ║
║ · · · · ·║     ║          ║
╚══════════╝     ╚══════════╝
```

**Character assignments:**

| Element | Character | CSS Color |
|---------|-----------|-----------|
| Wall (horizontal) | `═` | `var(--green-dim)` / `#006600` |
| Wall (vertical) | `║` | `var(--green-dim)` |
| Wall (corners) | `╔ ╗ ╚ ╝` | `var(--green-dim)` |
| Wall (tees) | `╠ ╣ ╦ ╩ ╬` | `var(--green-dim)` |
| Data packet | `·` | `var(--green-mid)` / `#00cc00` |
| Power Node | `◆` | `var(--gold)` / `#ffd700`, pulsing glow |
| Player | `@` | `var(--green-bright)` / `#00ff00`, glow |
| Player (Ghost Mode) | `@` | `var(--cyan)` / `#00ffff`, strong glow |
| Player (hit) | `@` | `var(--red)` / `#ff0000`, flash |
| Patrol Tracer | `T` | `var(--red)` / `#ff0000` |
| Hunter Tracer | `H` | `#ff00ff` (magenta) |
| Phantom Tracer | `P` | `var(--cyan)` / `#00ffff` |
| Swarm Tracer | `s` | `var(--amber)` / `#ffaa00` |
| Tracer (frightened) | `░` | `var(--green-dim)`, blinking |
| Tracer (frozen/EMP) | `█` | `var(--cyan)`, static |
| Empty corridor | ` ` | (background) |

---

## 4. Economy Integration

### 4.1 Entry & Burns

Ghost Maze uses the existing ArcadeCore infrastructure for session management.

**Entry flow:**
1. Player selects difficulty tier (affects entry fee)
2. ArcadeCore processes entry: transfers $DATA, applies rake/burn
3. Session created with maze seed committed
4. Game begins

**Entry tiers:**

| Tier | Entry Fee | Burn Rate | Prize Pool Contribution | Boost Eligible |
|------|-----------|-----------|------------------------|----------------|
| Free Play | 0 $DATA | N/A | None | No |
| Standard | 25 $DATA | 100% burned | Leaderboard only | Yes |
| Advanced | 50 $DATA | 100% burned | Leaderboard only | Yes |
| Elite | 100 $DATA | 100% burned | Leaderboard only | Yes |

**Note:** Ghost Maze is a **pure burn** game. 100% of entry fees are burned. There is no prize pool redistribution — rewards come as GHOSTNET position boosts, not $DATA payouts. This simplifies the contract significantly and maximizes deflationary pressure.

Free Play mode exists for practice — no entry fee, no leaderboard entry, no boosts earned.

### 4.2 Reward Boosts

Rewards are GHOSTNET position boosts, not $DATA:

| Achievement | Boost | Duration | Requirement |
|-------------|-------|----------|-------------|
| Clear Level 3+ | -5% death rate | 2 hours | Paid entry |
| Clear Level 5 | -10% death rate | 4 hours | Paid entry |
| Perfect Run (all 5 levels) | -20% death rate | 8 hours | Paid entry |
| Score > 100,000 | +10% yield | 4 hours | Paid entry |
| Score > 200,000 | +20% yield | 4 hours | Paid entry |

**Boost application:** Server verifies game result (score, levels cleared), signs a boost message, player submits to GhostCore contract. Same pattern as Trace Evasion and Daily Ops.

### 4.3 Leaderboard

- **Daily leaderboard:** Resets every 24 hours. Top scores for the day.
- **All-time leaderboard:** Persistent. Best scores ever recorded.
- **Weekly tournament:** Fixed seed (same maze for everyone). Top 50 split a prize pool funded by a portion of that week's arcade burns.

Leaderboard entries require paid entry (Free Play doesn't count).

---

## 5. Architecture

### 5.1 Component Architecture

Ghost Maze follows the established arcade game pattern: a feature module under `lib/features/` with a store, engine modules, and Svelte components.

```
apps/web/src/lib/features/ghost-maze/
├── components/
│   ├── GhostMazeGame.svelte        # Top-level game container
│   ├── MazeRenderer.svelte          # ASCII maze rendering (the big one)
│   ├── Player.svelte                # Player character overlay + animations
│   ├── Tracer.svelte                # Individual tracer entity + animation
│   ├── HUD.svelte                   # Score, lives, level, combo, EMP status
│   ├── LevelIntro.svelte            # "LEVEL 3: DARKNET" interstitial
│   ├── GameOver.svelte              # Final score, rewards, play again
│   ├── PauseOverlay.svelte          # Pause menu (ESC)
│   └── Minimap.svelte               # Optional minimap for large mazes (Level 4-5)
├── engine/
│   ├── maze-generator.ts            # Procedural maze from seed
│   ├── maze-types.ts                # Cell, Wall, Direction, Coord types
│   ├── tracer-ai.ts                 # Tracer behavior (patrol, hunt, phantom, swarm)
│   ├── pathfinding.ts               # A* for Hunter tracer
│   ├── collision.ts                 # Grid-based collision detection
│   ├── input.ts                     # Input buffering + key handling
│   └── game-loop.ts                 # Fixed-timestep game loop
├── store.svelte.ts                  # Game state (Svelte 5 runes)
├── types.ts                         # GhostMazeState, TracerState, etc.
├── audio.ts                         # ZzFX sound effect triggers
├── constants.ts                     # Level configs, speeds, scoring values
└── index.ts                         # Public exports
```

**Route:**
```
apps/web/src/routes/arcade/ghost-maze/
└── +page.svelte                     # Route page, loads GhostMazeGame
```

### 5.2 State Machine

Ghost Maze uses the shared `GameEngine` FSM from `lib/features/arcade/engine/`:

```typescript
type GhostMazePhase =
  | 'idle'           // Menu / not playing
  | 'entry'          // Paying entry fee (transaction pending)
  | 'level_intro'    // "LEVEL X: THEME" display (2 seconds)
  | 'playing'        // Active gameplay
  | 'ghost_mode'     // Player has Power Node active (sub-state of playing)
  | 'player_death'   // Death animation (0.5s)
  | 'respawn'        // Respawn + invincibility (2s)
  | 'level_clear'    // Level complete celebration (2s)
  | 'game_over'      // All lives lost or all levels cleared
  | 'results'        // Score tally, boost rewards
  | 'paused';        // ESC menu

// Valid transitions
const transitions: Record<GhostMazePhase, GhostMazePhase[]> = {
  idle:          ['entry'],
  entry:         ['level_intro', 'idle'],       // tx success or cancel
  level_intro:   ['playing'],
  playing:       ['ghost_mode', 'player_death', 'level_clear', 'game_over', 'paused'],
  ghost_mode:    ['playing', 'player_death', 'level_clear', 'paused'],
  player_death:  ['respawn', 'game_over'],
  respawn:       ['playing'],
  level_clear:   ['level_intro', 'game_over'],  // next level or final level done
  game_over:     ['results'],
  results:       ['idle'],
  paused:        ['playing', 'ghost_mode', 'idle'],
};
```

### 5.3 Game Loop

The game uses a **fixed-timestep loop** for deterministic simulation, separate from rendering:

```typescript
// engine/game-loop.ts

const TICK_RATE = 15;  // 15 ticks per second (66.67ms per tick)
// This is slow enough for ASCII to look intentional, fast enough to feel responsive

export function createGameLoop(config: {
  onTick: (tick: number) => void;     // Fixed-rate game logic
  onRender: (alpha: number) => void;  // Variable-rate rendering
}) {
  const TICK_MS = 1000 / TICK_RATE;
  let accumulator = 0;
  let lastTime = 0;
  let tick = 0;
  let rafId: number | null = null;

  function loop(time: number) {
    const delta = lastTime ? time - lastTime : 0;
    lastTime = time;
    accumulator += delta;

    // Fixed timestep updates
    while (accumulator >= TICK_MS) {
      config.onTick(tick++);
      accumulator -= TICK_MS;
    }

    // Render with interpolation alpha
    config.onRender(accumulator / TICK_MS);

    rafId = requestAnimationFrame(loop);
  }

  return {
    start() { rafId = requestAnimationFrame(loop); },
    stop()  { if (rafId) cancelAnimationFrame(rafId); rafId = null; },
    get tick() { return tick; },
  };
}
```

**Why fixed timestep:**
- Deterministic: Same inputs → same game state (important for replay verification)
- Consistent: Game speed doesn't vary with frame rate
- Separates logic from rendering: Logic at 15fps, rendering at 60fps with interpolation

### 5.4 Store Design

```typescript
// store.svelte.ts

import { createGameEngine } from '$lib/features/arcade/engine';
import { createScoreSystem } from '$lib/features/arcade/engine';

export interface GhostMazeState {
  // Game phase
  phase: GhostMazePhase;

  // Level state
  currentLevel: number;              // 1-5
  maze: MazeGrid | null;             // Current maze layout
  dataRemaining: number;             // Packets left to collect
  dataTotal: number;                 // Total packets this level

  // Player state
  playerPos: Coord;                  // Grid position
  playerDir: Direction;              // Current facing direction
  lives: number;                     // Remaining lives
  isInvincible: boolean;             // Post-respawn invincibility
  hasEmp: boolean;                   // EMP available

  // Ghost Mode
  ghostModeActive: boolean;
  ghostModeRemaining: number;        // ms remaining

  // Tracers
  tracers: TracerState[];

  // Score (delegated to ScoreSystem)
  score: number;
  combo: number;
  maxCombo: number;

  // Meta
  entryTier: 'free' | 'standard' | 'advanced' | 'elite';
  sessionId: number | null;
  seed: number | null;

  // UI
  isPaused: boolean;
  error: string | null;
}

export interface TracerState {
  id: number;
  type: 'patrol' | 'hunter' | 'phantom' | 'swarm';
  pos: Coord;
  dir: Direction;
  mode: 'normal' | 'frightened' | 'frozen' | 'dead';
  respawnTimer: number;              // Ticks until respawn (if dead)
}

export type Direction = 'up' | 'down' | 'left' | 'right';
export type Coord = { x: number; y: number };
```

### 5.5 Rendering Strategy

**The critical question:** How to render a grid-based game in ASCII at 60fps without janky updates.

**Approach: Canvas of characters**

The maze is rendered as a 2D array of styled characters inside a `<pre>` element. Each frame:
1. Build a character buffer (2D string array) from maze state
2. Overlay entities (player, tracers, power nodes) onto buffer
3. Render buffer to DOM as a single `<pre>` text update

**Why `<pre>` and not individual `<span>` elements:**
- A 37×23 maze = 851 cells. Creating 851 DOM elements is expensive.
- A single `<pre>` with colored text (via ANSI-to-CSS or character-level spans for colored entities) is much faster.
- Entities (player, tracers, items) are overlay `<span>` elements positioned absolutely over the `<pre>` grid using `ch` units for pixel-perfect alignment with monospace characters.

```svelte
<!-- MazeRenderer.svelte (simplified) -->
<div class="maze-container" style="--cols: {cols}; --rows: {rows}">
  <!-- Static maze walls + data packets -->
  <pre class="maze-grid">{mazeText}</pre>

  <!-- Entities overlaid with absolute positioning -->
  {#each entities as entity (entity.id)}
    <span
      class="entity entity-{entity.type}"
      style="left: {entity.x}ch; top: {entity.y}lh;"
    >
      {entity.char}
    </span>
  {/each}
</div>

<style>
  .maze-container {
    position: relative;
    font-family: 'IBM Plex Mono', monospace;
    font-size: 14px;
    line-height: 1.2;
    color: var(--green-dim);
  }
  .maze-grid {
    margin: 0;
    white-space: pre;
  }
  .entity {
    position: absolute;
    z-index: 10;
  }
  .entity-player {
    color: var(--green-bright);
    text-shadow: 0 0 8px var(--green-glow);
  }
  .entity-tracer-patrol { color: var(--red); }
  .entity-tracer-hunter { color: #ff00ff; }
  .entity-tracer-phantom { color: var(--cyan); }
  .entity-tracer-swarm { color: var(--amber); }
  .entity-tracer-frightened {
    color: var(--green-dim);
    animation: blink 0.3s infinite;
  }
  .entity-power-node {
    color: var(--gold);
    animation: pulse 1.5s infinite;
  }
</style>
```

**Performance budget:**
- Maze text update: < 1ms (string concatenation of static wall chars)
- Entity position updates: < 0.5ms (moving ~10 absolute `<span>` elements)
- Target: < 2ms total per frame. At 60fps we have 16ms budget — this leaves 14ms headroom.

### 5.6 Input Handling

Input is the make-or-break of any Pac-Man-style game. The player must feel instant responsiveness.

```typescript
// engine/input.ts

export interface InputState {
  /** Currently held direction (from key being held) */
  current: Direction | null;
  /** Buffered direction (next turn to execute) */
  buffered: Direction | null;
}

export function createInputHandler() {
  let state = $state<InputState>({ current: null, buffered: null });
  const held = new Set<string>();

  const KEY_MAP: Record<string, Direction> = {
    ArrowUp: 'up',    w: 'up',    k: 'up',
    ArrowDown: 'down',  s: 'down',  j: 'down',
    ArrowLeft: 'left',  a: 'left',  h: 'left',
    ArrowRight: 'right', d: 'right', l: 'right',
  };

  function onKeyDown(e: KeyboardEvent) {
    const dir = KEY_MAP[e.key];
    if (dir) {
      e.preventDefault();
      held.add(e.key);
      state = { ...state, buffered: dir, current: dir };
    }
  }

  function onKeyUp(e: KeyboardEvent) {
    held.delete(e.key);
    const dir = KEY_MAP[e.key];
    if (dir && state.current === dir) {
      // Find another held direction key, or clear
      const remaining = [...held].map(k => KEY_MAP[k]).filter(Boolean);
      state = { ...state, current: remaining[0] ?? null };
    }
  }

  /** Consume the buffered direction (called by game loop when turn is executed) */
  function consumeBuffer(): Direction | null {
    const dir = state.buffered;
    state = { ...state, buffered: null };
    return dir;
  }

  return {
    get state() { return state; },
    onKeyDown,
    onKeyUp,
    consumeBuffer,
  };
}
```

**Buffer behavior:** When the player presses a direction, it's stored as `buffered`. On each tick, the game loop checks if the buffered direction is valid (i.e., no wall in that direction from the player's current position). If valid, the player turns. If not, the buffer persists for up to 3 ticks (200ms), allowing pre-cornering. This matches classic Pac-Man feel.

### 5.7 Pathfinding (A*)

The Hunter Tracer needs A* pathfinding. Since the maze is grid-based, this is a straightforward implementation:

```typescript
// engine/pathfinding.ts

interface PathNode {
  x: number;
  y: number;
  g: number;  // Cost from start
  h: number;  // Heuristic to goal
  f: number;  // g + h
  parent: PathNode | null;
}

export function findPath(
  maze: MazeGrid,
  from: Coord,
  to: Coord
): Coord[] | null {
  // Standard A* with Manhattan distance heuristic
  // Returns array of coords from 'from' to 'to', or null if no path
  // ...implementation...
}
```

**Performance:** A* on a 37×23 grid (851 cells max) is trivially fast. Even worst-case is < 1ms. No optimization needed. We recompute every 500ms for the Hunter, which is ~2 A* calls per second.

---

## 6. UI Layout

### 6.1 Full Game Screen

```
╔══════════════════════════════════════════════════════════════════╗
║  GHOST MAZE v1.0 ░░░░░░░░░░░░░░░░░░░░░░░  SECTOR: DARKNET      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  ┌──────────────────────────────────────────────────────────┐   ║
║  │                                                          │   ║
║  │    · · · · ·║ · · · · · · · ·║ · · · · · · ·            │   ║
║  │    · ╔═══╗ ·║ · ╔═══════╗ · ·║ · ╔═══╗ · · ·            │   ║
║  │  ◆ · ║   ║ · · · ║       ║ ·   · ║   ║ · ◆ ·            │   ║
║  │    · ╚═══╝ ·║ · ╚═══════╝ · ·║ · ╚═══╝ · · ·            │   ║
║  │    · · · · · · · · · · @ · · · · · · · · · · ·            │   ║
║  │    · ╔═══╗ ·║ · ╔═══╗ · ╔═══╗║ · ╔═══════╗ ·            │   ║
║  │    · ║   ║ ·║ · ║ T ║ · ║ H ║║ · ║       ║ ·            │   ║
║  │    · ╚═══╝ ·║ · ╚═══╝ · ╚═══╝║ · ╚═══════╝ ·            │   ║
║  │    · · · · ·║ · · · · · · · ·║ · · · · · ◆ ·            │   ║
║  │                                                          │   ║
║  └──────────────────────────────────────────────────────────┘   ║
║                                                                  ║
║  SCORE: 12,400    LIVES: ♥♥♡    LVL: 3/5    DATA: 47/120       ║
║  COMBO: ×5 (23)   EMP: [READY]  GHOST: ░░░░░░░░░░               ║
║                                                                  ║
║  [WASD] Move   [SPACE] EMP   [ESC] Pause   [Q] Quit             ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### 6.2 HUD Elements

| Element | Position | Content | Updates |
|---------|----------|---------|---------|
| Score | Bottom-left | `SCORE: 12,400` | On every point gain |
| Lives | Bottom-center-left | `LIVES: ♥♥♡` | On death |
| Level | Bottom-center | `LVL: 3/5` | On level clear |
| Data | Bottom-center-right | `DATA: 47/120` | On packet collect |
| Combo | Bottom-left (row 2) | `COMBO: ×5 (23)` | On collect/break |
| EMP | Bottom-center (row 2) | `EMP: [READY]` / `EMP: [USED]` | On EMP use/level start |
| Ghost Mode | Bottom-right (row 2) | `GHOST: ████████░░` (progress bar) | During Ghost Mode |

### 6.3 Level Intro Screen

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║                                                                  ║
║                                                                  ║
║                    ░░░░░░░░░░░░░░░░░░░░░░░                      ║
║                                                                  ║
║                        L E V E L   3                             ║
║                                                                  ║
║                        D A R K N E T                             ║
║                                                                  ║
║                    ░░░░░░░░░░░░░░░░░░░░░░░                      ║
║                                                                  ║
║               TRACERS: 4    DATA PACKETS: 120                    ║
║               NEW: PHANTOM TRACER (teleports!)                   ║
║                                                                  ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### 6.4 Game Over Screen

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║                    G A M E   O V E R                             ║
║                                                                  ║
║  ┌────────────────────────────────────────────────────────┐      ║
║  │  FINAL SCORE:          34,800                          │      ║
║  │  LEVELS CLEARED:       3 / 5                           │      ║
║  │  DATA COLLECTED:       270 / 420                       │      ║
║  │  TRACERS DESTROYED:    7                               │      ║
║  │  MAX COMBO:            ×5 (34)                         │      ║
║  │  PERFECT LEVELS:       1 (Level 1)                     │      ║
║  ├────────────────────────────────────────────────────────┤      ║
║  │                                                        │      ║
║  │  REWARD EARNED:                                        │      ║
║  │  ✓ -5% death rate (2 hours)                           │      ║
║  │                                                        │      ║
║  │  LEADERBOARD: #147 today                              │      ║
║  │                                                        │      ║
║  └────────────────────────────────────────────────────────┘      ║
║                                                                  ║
║          [ENTER] Play Again     [ESC] Exit to Arcade             ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## 7. Audio Design

Uses the existing ZzFX sound system established by the arcade.

| Event | Sound | ZzFX Description | Trigger Rate |
|-------|-------|-------------------|-------------|
| Data collect | `blip` | Quick ascending blip. Pitch rises with combo level. | Very frequent |
| Power Node grab | `power-up` | Ascending arpeggio, 3 notes | 4 per level |
| Ghost Mode start | `hum-start` | Low sweep upward | 4 per level |
| Ghost Mode end | `hum-end` | Descending sweep | 4 per level |
| Ghost Mode warning (2s left) | `warning-pulse` | Quick triple beep | 4 per level |
| Tracer destroyed | `shatter` | Noise burst, descending pitch | Occasional |
| EMP deploy | `emp-pulse` | Low-frequency pulse, bass heavy | 1 per level |
| Player hit (death) | `flatline` | Harsh buzz, descending to silence | Rare |
| Respawn | `reconnect` | Ascending digital tone | Rare |
| Level clear | `fanfare` | 4-note ascending fanfare | 1 per level |
| Game over | `shutdown` | Descending power-down tone | 1 per game |
| Phantom teleport warning | `phase-shift` | Ethereal whoosh, rising pitch | Every 15s |
| Combo milestone (10, 20, 50) | `combo-chime` | Higher-pitched confirmation | Occasional |

**Music:** No background music. The game's tension comes from silence punctuated by sound effects. The ambient terminal hum (if enabled in settings) provides atmosphere.

---

## 8. Anti-Cheat

Ghost Maze is a client-side game with server-verified results. The game logic runs in the browser for responsiveness, but rewards require server validation.

### 8.1 Replay Verification

The game records an **input log** — a sequence of `(tick, input)` pairs:

```typescript
interface InputRecord {
  tick: number;
  action: 'up' | 'down' | 'left' | 'right' | 'emp' | 'pause' | 'unpause';
}

interface GameReplay {
  seed: number;
  level: number;
  entryTier: string;
  sessionId: number;
  inputs: InputRecord[];
  finalScore: number;
  levelsCleared: number;
  checksum: string;  // Hash of all inputs for tampering detection
}
```

The server can replay the input log against the deterministic game engine to verify:
- The score is correct
- The claimed levels were actually cleared
- No impossible moves occurred (moving through walls, etc.)
- Timing is humanly plausible

### 8.2 Statistical Detection

| Metric | Suspicious | Auto-reject |
|--------|------------|-------------|
| Perfect score (all 5 levels) | Flag for review | N/A (theoretically possible) |
| Reaction time to Tracers | < 100ms consistently | < 50ms consistently |
| Input frequency | > 20 inputs/second sustained | > 30 inputs/second |
| Identical replays | Same inputs across sessions | Exact duplicate |

### 8.3 Rate Limiting

- Maximum 1 paid game per 30 seconds (via ArcadeCore `minPlayInterval`)
- Maximum 20 paid games per hour
- Free Play: no rate limit but no rewards

---

## 9. Contract Integration

Ghost Maze does NOT need its own smart contract. It uses the existing ArcadeCore infrastructure:

1. **Entry:** `ArcadeCore.processEntry()` — handles $DATA transfer and burn
2. **Session tracking:** Session ID from ArcadeCore
3. **Rewards:** Server signs a boost message after game completion, player submits to GhostCore
4. **Leaderboard:** Off-chain (indexer stores scores from verified replays)

This is the same pattern as Trace Evasion — a client-side game with server-signed rewards. No new contract deployment needed.

**If we later want on-chain score submission** (for tournaments with prize pools), we could add a lightweight `GhostMaze.sol` that:
- Accepts replay hashes
- Distributes tournament prizes
- But this is deferred — not needed for initial launch

---

## 10. Implementation Plan

### Phase 1: Core Engine (1 week)

| Task | Priority | Estimate |
|------|----------|----------|
| `maze-generator.ts` — Recursive backtracker + loop creation | P0 | 4h |
| `maze-types.ts` — Cell, Grid, Coord types | P0 | 1h |
| `collision.ts` — Wall checking, entity overlap | P0 | 2h |
| `input.ts` — Input buffering, key mapping | P0 | 2h |
| `game-loop.ts` — Fixed timestep with render interpolation | P0 | 3h |
| `pathfinding.ts` — A* for Hunter tracer | P1 | 3h |
| `tracer-ai.ts` — All 4 tracer behaviors | P1 | 6h |
| Unit tests for maze generation | P0 | 3h |
| Unit tests for collision + pathfinding | P1 | 2h |

### Phase 2: Rendering & UI (1 week)

| Task | Priority | Estimate |
|------|----------|----------|
| `MazeRenderer.svelte` — ASCII grid + entity overlays | P0 | 6h |
| `Player.svelte` — Character + animations (glow, death, respawn) | P0 | 3h |
| `Tracer.svelte` — 4 tracer types + frightened/frozen states | P0 | 4h |
| `HUD.svelte` — Score, lives, combo, EMP, ghost mode bar | P0 | 3h |
| `LevelIntro.svelte` — Level transition screen | P1 | 2h |
| `GameOver.svelte` — Results + rewards display | P1 | 3h |
| `PauseOverlay.svelte` — Pause menu | P2 | 1h |
| Responsive sizing (viewport adaptation) | P1 | 3h |

### Phase 3: Game Integration (0.5 week)

| Task | Priority | Estimate |
|------|----------|----------|
| `store.svelte.ts` — Full game state with GameEngine FSM | P0 | 4h |
| `audio.ts` — ZzFX sound effects for all events | P1 | 3h |
| `constants.ts` — Level configs, scoring, speeds | P0 | 1h |
| Route page `/arcade/ghost-maze/+page.svelte` | P0 | 1h |
| ArcadeCore entry flow (free + paid) | P1 | 3h |
| Boost reward signing (server integration) | P2 | 4h |
| Replay recording + submission | P2 | 3h |

### Phase 4: Polish & Testing (0.5 week)

| Task | Priority | Estimate |
|------|----------|----------|
| Gameplay tuning (speeds, Tracer behavior, combo timing) | P0 | 4h |
| Component tests (`*.svelte.test.ts`) | P1 | 4h |
| E2E test (full game flow) | P2 | 3h |
| Mobile touch controls (swipe detection) | P2 | 3h |

**Total estimate: ~3 weeks**

---

## 11. Open Questions

- [ ] Should the maze size adapt to viewport, or should we enforce a fixed aspect ratio with scrolling?
- [ ] Should there be a "daily maze" mode with a fixed seed for fair competition?
- [ ] Should Tracer AI difficulty scale with player's historical performance (adaptive difficulty)?
- [ ] Should we support a 2-player competitive mode later? (Split maze, race to collect data)
- [ ] Should combo system use time-based decay or collection-based reset?
- [ ] What's the right tick rate? 15/s suggested but needs playtesting.
- [ ] Should Power Node effects stack? (Grab two = 16 seconds?)

---

## 12. Related Documents

- [[brainstorm/BRAIN-2026-01-28-arcade-keyboard-games]] — Original brainstorm
- [[design/arcade/infrastructure/game-engine]] — Shared game engine
- [[design/arcade/infrastructure/contracts]] — ArcadeCore architecture
- [[design/arcade/designs/visual-system]] — Design tokens
- [[design/arcade/designs/sound-design]] — Audio specifications
- [[capabilities/minigames]] — Mini-game capability specs
- [[capabilities/economy#burn-engine---mini-game-entry]] — Burn mechanics
