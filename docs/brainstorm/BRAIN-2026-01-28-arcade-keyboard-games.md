---
type: brainstorm
date: 2026-01-28
processed: false
promoted_to:
tags:
  - type/brainstorm
  - topic/minigames
  - topic/arcade
---

# BRAIN-2026-01-28: Arcade & Keyboard Games

## Context

GHOSTNET's Active Boost Layer currently includes typing-based games (Trace Evasion, Code Duel), a crash game (Hash Crash), and daily missions (Daily Ops). These are effective but limited in gameplay variety. The typing games are one-dimensional — you type, you get a score. There's no *world* inside the game. No spatial reasoning. No "one more run" feeling.

We want to explore **old-school arcade and keyboard-driven games** that:
- Feel like playing inside a hacker network
- Use the terminal/ASCII aesthetic natively
- Are keyboard-only (hackers don't use mice)
- Have genuine skill expression and depth
- Create streamable, watchable moments
- Integrate meaningfully with the GHOSTNET economy

The question driving this brainstorm: **What's the Pac-Man of a hostile network?**

---

## Design Constraints

Before any idea can be viable, it must satisfy these constraints:

### C1: Terminal Aesthetic
No sprites, no pixel art, no smooth gradients. ASCII characters, box-drawing characters, monospace font, green phosphor palette. The game must *look like a terminal* and still be fun to play. This is a feature, not a limitation — it creates a unique visual identity.

Available visual vocabulary:
```
Box Drawing:    ┌ ┐ └ ┘ │ ─ ├ ┤ ┬ ┴ ┼ ╔ ╗ ╚ ╝ ║ ═
Blocks:         █ ▓ ░ ▒ ▄ ▀ ▐ ▌
Shapes:         ◆ ◇ ● ○ ◉ ▲ ▼ ► ◄ ★ ☆
Progress:       ████░░░░ or ▰▰▰▱▱▱
Player:         @ ▲ ► ◉
Enemies:        T ✖ ☠ ▓
Items:          ◆ ◇ ♦ ★ ⚡
Walls:          ║ ═ ╔ ╗ ╚ ╝ █
Empty:          · . (space)
```

### C2: Keyboard-Only Controls
Arrow keys, WASD, or vim keys (hjkl). Maximum 2-3 additional action keys (Space, E, F). No mouse interaction during gameplay. Menu navigation can use mouse.

### C3: Economic Integration
Every game must connect to the GHOSTNET economy:
- **Entry fee** (burned, creating deflationary pressure)
- **Rewards** (boosts to main game position, $DATA payouts, or both)
- **Leaderboards** (competitive motivation, social proof in feed)

Entry should feel worth it. Reward should feel earned. The game should make your main GHOSTNET position stronger.

### C4: Session Length
Target: **1-5 minutes** per session. Not 30 seconds (too shallow for skill expression) and not 20 minutes (too much commitment, breaks the "quick game between scans" flow).

### C5: Skill Expression
The difference between a novice and an expert should be visible and meaningful. Score differential of at least 5x between casual and skilled play. This creates aspiration, content, and competitive legitimacy.

### C6: Streamability
Someone watching over your shoulder (or on a stream) should:
- Understand the state within 5 seconds
- Feel tension during critical moments
- React to outcomes (near misses, perfect plays, deaths)

### C7: Provably Fair
All randomness must use on-chain verifiable sources (FutureBlockRandomness pattern). Players must trust that the game isn't rigged. Procedural generation seeded from block hashes.

### C8: Mobile Consideration
While keyboard-first, the game should be *possible* on mobile with simple touch controls (swipe, tap). Not optimized for mobile, but not impossible.

---

## Raw Ideas

### IDEA 1: GHOST MAZE

**Elevator Pitch:** Pac-Man reimagined as network infiltration.

**Core Mechanic:** Navigate an ASCII maze as a ghost (@). Collect data packets (·). Avoid Tracers (T) that patrol the maze. Grab Power Nodes (◆) to become temporarily invisible (phase through Tracers). Clear all data to complete the level.

**Visual Concept:**
```
┌──────────────────────────────────────────────────────────┐
│ · · · · · ║ · · · · · · · · · ║ · · · · · · · · ·      │
│ · ╔═══╗ · ║ · ╔═══════════╗ · ║ · ╔═══╗ · ╔═══╗ ·      │
│ ◆ ║   ║ · · · ║           ║ ·   · ║   ║ · ║   ║ ◆      │
│ · ╚═══╝ · ║ · ╚═══════════╝ · ║ · ╚═══╝ · ╚═══╝ ·      │
│ · · · · · · · · · · @ · · · · · · · · · · · · · ·      │
│ · ╔═══╗ · ║ · ╔═══╗ · ╔═══╗ · ║ · ╔═══════════╗ ·      │
│ · ║   ║ · ║ · ║ T ║ · ║ T ║ · ║ · ║           ║ ·      │
│ · ╚═══╝ · ║ · ╚═══╝ · ╚═══╝ · ║ · ╚═══════════╝ ·      │
│ · · · · · ║ · · · · · · · · · ║ · · · · · ◆ · · ·      │
└──────────────────────────────────────────────────────────┘

@ = YOU (the ghost)    T = TRACER    · = DATA PACKET    ◆ = POWER NODE
```

**Full UI Wireframe:**
```
╔══════════════════════════════════════════════════════════════════╗
║  GHOST MAZE v1.0 ░░░░░░░░░░░░░░░░░░░░░░░  SECTOR: DARKNET      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  ┌──────────────────────────────────────────────────────────┐   ║
║  │                   [MAZE AREA]                             │   ║
║  │                                                           │   ║
║  │              (see maze layout above)                       │   ║
║  │                                                           │   ║
║  └──────────────────────────────────────────────────────────┘   ║
║                                                                  ║
║  DATA: 47/120     LIVES: ♥♥♡     LEVEL: 3/5     SCORE: 12,400  ║
║  POWER: ░░░░░░░░░░  INACTIVE                                    ║
║                                                                  ║
║  [WASD] Move   [SPACE] Deploy EMP   [Q] Quit Run                ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

**Game Mechanics:**

1. **Movement:** WASD or arrow keys. Grid-based movement (not free-form). Player moves one cell per input at walking speed, or holds direction for continuous movement.

2. **Data Packets (·):** Scattered throughout maze. Collecting all completes the level. Each packet = points. Collecting packets in rapid succession builds a combo multiplier.

3. **Tracers (T):** AI enemies that patrol the maze. Different behavior patterns:
   - **Patrol Tracer** — follows a fixed route, predictable
   - **Hunt Tracer** — actively pathfinds toward you when in line of sight
   - **Phantom Tracer** — teleports to random locations periodically
   - **Swarm Tracer** — slower but travels in packs of 2-3

4. **Power Nodes (◆):** 4 per level, placed at maze corners. Collecting one activates Ghost Mode for 8 seconds — you become invisible and can pass through Tracers. Tracers flee during this period (blue/dim color). Touching a fleeing Tracer destroys it temporarily (respawns after 15 seconds). Destroying Tracers = bonus points.

5. **EMP (limited):** One use per level. Freezes all Tracers for 5 seconds. Strategic tool — save it for emergencies or use it to clear a dense area.

6. **Level Progression:**

   | Level | Maze Size | Tracers | Data Packets | Speed | Theme |
   |-------|-----------|---------|--------------|-------|-------|
   | 1 | 15x15 | 2 (Patrol) | 60 | Slow | MAINFRAME |
   | 2 | 20x20 | 3 (Patrol + Hunt) | 90 | Medium | SUBNET |
   | 3 | 25x20 | 4 (Mixed) | 120 | Medium-Fast | DARKNET |
   | 4 | 25x25 | 5 (Mixed + Phantom) | 150 | Fast | BLACK ICE |
   | 5 | 30x25 | 6 (All types + Swarm) | 200 | Very Fast | CORE |

7. **Maze Generation:** Procedurally generated from block hash seeds (provably fair). Every run has a unique maze. Algorithm: recursive backtracker with guaranteed solvability, then post-processed to add loops and open areas for better gameplay.

8. **Scoring:**
   ```
   Data Packet:           10 points
   Combo (consecutive):   10 × combo_count
   Tracer destroyed:      200 points
   Level clear:           1,000 × level_number
   Perfect clear:         5,000 × level_number (all data + all Tracers destroyed)
   Time bonus:            Remaining seconds × 50
   No-hit bonus:          2,000 per level (never touched by Tracer)
   ```

9. **Lives:** Start with 3. Lose one when touched by a Tracer (you respawn at start position). Lose all 3 = game over. Extra life at 50,000 points.

**Thematic Fit:**
- You ARE a ghost in the network — the core GHOSTNET metaphor
- Tracers ARE trace scans — the enemies are the system hunting you
- Data packets ARE the yield — you're extracting value
- Power Nodes ARE Ghost Protocol — temporary invincibility
- The maze IS the network — navigating hostile infrastructure

**Skill Expression:**
- Route optimization (shortest path to clear all data)
- Tracer pattern recognition (predicting patrol routes)
- Power Node timing (when to use ghost mode for maximum value)
- EMP strategy (save for emergency vs. use proactively)
- Combo chaining (collecting packets without pause)
- Risk assessment (go for the dangerous data cluster or play safe?)

**Streamability:**
- Tense chase sequences (Tracer on your tail)
- Power Node clutch saves (grabbing it at the last second)
- Perfect clear celebrations
- Close calls (one cell away from a Tracer)
- "How is this person so fast?" moments for skilled players

**Audio Design:**
| Event | Sound | Description |
|-------|-------|-------------|
| Data collect | `blip` | Quick, satisfying, pitch rises with combo |
| Power Node | `power-up` | Ascending tone, energy sound |
| Ghost Mode active | `hum` | Ambient low hum while invincible |
| Tracer nearby | `proximity-beep` | Gets faster as Tracer approaches |
| Tracer destroyed | `shatter` | Glass break / digital disintegration |
| EMP deploy | `pulse` | Low-frequency pulse wave |
| Hit by Tracer | `flatline` | Brief alarm + static |
| Level clear | `fanfare` | Short triumphant sequence |
| Game over | `shutdown` | Power-down sound |

**Economy:**

| Aspect | Value | Notes |
|--------|-------|-------|
| Entry Fee | 25-100 $DATA (burned) | Scales with difficulty selection |
| Prize Pool | Entry fees - burn = pool | Distributed based on score |
| Score → $DATA | Top 25% of daily scores earn payouts | Prevents farming |
| Death Rate Boost | Complete 3+ levels = -10% for 4h | Meaningful edge |
| Perfect Run Boost | All 5 levels, no deaths = -20% for 8h | Aspirational |
| Leaderboard | Daily + all-time | Resets daily for fresh competition |

**Implementation Complexity:** Medium-High
- Maze generation algorithm
- Tracer AI pathfinding (A* or similar)
- Collision detection on grid
- 5 unique level layouts
- Animation system for movement

**Implementation Path:**
```
/lib/features/ghost-maze/
├── components/
│   ├── MazeGame.svelte          # Main game container + loop
│   ├── MazeRenderer.svelte      # ASCII maze rendering
│   ├── Player.svelte            # Ghost character
│   ├── Tracer.svelte            # Enemy characters
│   ├── HUD.svelte               # Score, lives, power meter
│   ├── LevelIntro.svelte        # Level start screen
│   ├── GameOver.svelte          # Results + rewards
│   └── Minimap.svelte           # Optional minimap for large mazes
├── engine/
│   ├── maze-generator.ts        # Procedural maze from seed
│   ├── tracer-ai.ts             # Enemy pathfinding + behaviors
│   ├── collision.ts             # Grid-based collision
│   ├── scoring.ts               # Score calculation
│   └── game-loop.ts             # Main update loop (requestAnimationFrame)
├── store.svelte.ts              # Game state
├── types.ts                     # Cell, Entity, Direction, etc.
├── audio.ts                     # ZzFX sound triggers
└── constants.ts                 # Level configs, tuning values
```

**Open Questions:**
- [ ] Should maze size adapt to screen/viewport?
- [ ] Should there be a practice/free mode with no entry fee?
- [ ] How to prevent botting? (Replay verification, input pattern analysis)
- [ ] Should Tracer AI difficulty scale with player skill (ELO-like)?
- [ ] Multiplayer variant? (2 players in same maze, competitive data collection)

---

### IDEA 2: SIGNAL SNAKE

**Elevator Pitch:** Snake reimagined as data exfiltration from a hostile network.

**Core Mechanic:** You're a data signal snaking through a network grid. Collect data fragments to grow. But your signal *decays from the tail* — you're constantly losing length. If you stop collecting, you shrink to nothing and die. ICE obstacles spawn over time, making the space tighter. Decrypt nodes slow you down but give score multipliers.

**Visual Concept:**
```
┌──────────────────────────────────────────────────────────┐
│                                                          │
│        ◆                                                 │
│                                                          │
│              ████████████████                             │
│                             █                             │
│                 ░           █                             │
│                             █                             │
│                    █████████@                             │
│                                                          │
│                                         ✖                │
│         ✖                                                │
│                                                          │
└──────────────────────────────────────────────────────────┘

@ = HEAD (direction indicator)    █ = SIGNAL BODY    ◆ = DATA FRAGMENT
✖ = ICE NODE (obstacle)    ░ = DECRYPT NODE (slow + multiplier)
```

**Full UI Wireframe:**
```
╔══════════════════════════════════════════════════════════════════╗
║  SIGNAL SNAKE v1.0 ░░░░░░░░░░░░░░░░░░░░░░░  EXTRACTING...      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  ┌──────────────────────────────────────────────────────────┐   ║
║  │                                                          │   ║
║  │                    [PLAY AREA]                            │   ║
║  │                                                          │   ║
║  └──────────────────────────────────────────────────────────┘   ║
║                                                                  ║
║  LENGTH: 14      SPEED: ████████░░  FAST    SCORE: 8,200       ║
║  DATA: 7         MULTIPLIER: x2.5           HIGH: 23,400       ║
║  DECAY: ▓▓▓▓▓▓░░░░ 60%                                         ║
║                                                                  ║
║  [WASD] Turn    [SPACE] Boost (spend length for speed burst)    ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

**Game Mechanics:**

1. **Movement:** Continuous movement in current direction. WASD/arrows to change direction. Cannot reverse (standard Snake rule). Movement speed increases over time.

2. **Signal Body:** Your snake is rendered as `█` characters with the head as `@` (with direction indicator: `▲▼►◄`). The body represents your data signal — longer = more data extracted.

3. **Signal Decay (The Core Twist):**
   - Your tail decays at a constant rate (1 segment every 2 seconds at start, accelerates over time)
   - If length reaches 0, you flatline — game over
   - This creates constant forward pressure: you can NEVER stop collecting
   - Decay rate displayed as a meter in the HUD
   - Decay speed increases every 60 seconds

4. **Data Fragments (◆):**
   - Spawn at random positions on the grid
   - Collecting one adds 3-5 segments to your length
   - Always 2-3 fragments visible at once (new one spawns when collected)
   - Fragments have a timer — uncollected fragments disappear and respawn elsewhere

5. **ICE Nodes (✖):**
   - Static obstacles that spawn over time
   - Every 15 seconds, a new ICE node appears at a random empty position
   - Hitting an ICE node = instant death
   - ICE nodes never spawn on or adjacent to the player
   - Over time, the play area becomes increasingly constrained
   - Creates natural difficulty ramp without changing speed alone

6. **Decrypt Nodes (░):**
   - Rare spawns (one every 30 seconds)
   - Passing through one slows your movement speed by 50% for 3 seconds
   - BUT activates a score multiplier: x1.5, x2.0, x2.5 (stacking)
   - Multiplier decays over 20 seconds if not refreshed
   - Risk/reward decision: Do I slow down (dangerous with ICE closing in) for the multiplier?

7. **Boost (SPACE):**
   - Spend 5 segments of body length for a 2-second speed burst
   - During boost, you leave a temporary trail that destroys ICE nodes on contact
   - High risk: you're shorter (closer to death) but can clear obstacles
   - Strategic use: Clear a path through dense ICE, or speed past danger

8. **Speed Ramp:**
   | Time | Speed | Decay Rate | ICE Frequency |
   |------|-------|------------|---------------|
   | 0-30s | Slow | 1 seg / 2s | 1 per 15s |
   | 30-60s | Medium | 1 seg / 1.5s | 1 per 12s |
   | 60-120s | Fast | 1 seg / 1s | 1 per 10s |
   | 120-180s | Very Fast | 1 seg / 0.8s | 1 per 8s |
   | 180s+ | Extreme | 1 seg / 0.5s | 1 per 5s |

9. **Scoring:**
   ```
   Data Fragment:          100 points × multiplier
   Survive 30 seconds:     500 points
   ICE destroyed (boost):  300 points
   Decrypt Node:           200 points (+ multiplier activation)
   Length bonus:            Final length × 50
   Time bonus:             Total seconds survived × 10
   ```

**Thematic Fit:**
- Signal = your connection to the network (fragile, decaying)
- Data fragments = extracting value before the network catches on
- ICE = Intrusion Countermeasure Electronics (standard cyberpunk)
- Decay = the network actively severing your connection
- Boost = overclocking your connection (burns resources)
- The play area closing in = the network tracing your location

**Skill Expression:**
- Path planning (route to data fragments while avoiding ICE and walls)
- Decay management (when to collect data, when to boost)
- Multiplier optimization (when to hit Decrypt nodes)
- Spatial awareness (predicting where ICE will box you in)
- Boost timing (spend length to clear ICE vs. save for survival)
- Speed adaptation (playing clean at extreme speeds)

**Streamability:**
- "The walls are closing in" moments (ICE everywhere, tiny paths remaining)
- Clutch boost plays (destroying ICE at the last second)
- Long runs (how long can they survive?)
- Multiplier stacking (x2.5 on a data fragment = huge points)
- Sudden deaths (one wrong turn = instant flatline)

**Economy:**

| Aspect | Value | Notes |
|--------|-------|-------|
| Entry Fee | 10-50 $DATA (burned) | Low barrier, high replay |
| Prize Pool | Score-based distribution | Top scores earn $DATA |
| Yield Boost | Survive 120s+ = +10% yield for 4h | Time-based reward |
| Death Rate Boost | Survive 180s+ = -8% death rate for 4h | Harder threshold |
| Leaderboard | Time survived + score | Dual ranking |

**Implementation Complexity:** Low-Medium
- Classic Snake logic is well-understood
- Decay mechanic is a simple timer
- ICE spawning is random placement
- No pathfinding AI needed
- Grid rendering is straightforward

**Implementation Path:**
```
/lib/features/signal-snake/
├── components/
│   ├── SnakeGame.svelte         # Main game + loop
│   ├── GridRenderer.svelte      # ASCII grid rendering
│   ├── HUD.svelte               # Score, length, decay meter
│   ├── GameOver.svelte          # Results screen
│   └── Leaderboard.svelte       # Top scores
├── engine/
│   ├── snake.ts                 # Snake state + movement
│   ├── spawner.ts               # Data, ICE, Decrypt spawning
│   ├── collision.ts             # Wall, self, ICE collision
│   ├── decay.ts                 # Signal decay logic
│   └── game-loop.ts             # Main update loop
├── store.svelte.ts              # Game state
├── audio.ts                     # Sound effects
└── constants.ts                 # Speed curves, tuning
```

**Open Questions:**
- [ ] Should the play area have walls or wrap around (torus)?
- [ ] Should there be a "safe zone" in the center that ICE can't spawn in?
- [ ] Power-up variants beyond Decrypt? (Shield, magnet, time slow?)
- [ ] Should length affect score multiplier? (Longer = more risk = more reward?)
- [ ] Two-player split-screen variant?

---

### IDEA 3: DATA MINER

**Elevator Pitch:** Tetris reimagined as data block assembly in hostile memory.

**Core Mechanic:** Classic Tetris falling-block mechanics. Complete lines to "defragment" memory sectors. But corrupted blocks appear randomly — lines containing corruption can't be cleared until you use a Purge block or fill the entire row around the corruption. The real twist: when a trace scan approaches in the main GHOSTNET game, Data Miner speeds up. Lines cleared during scan proximity give death rate reduction.

**Visual Concept:**
```
NEXT:    ┌────────────────────────────────────┐
┌──┐     │                                    │    SCORE: 24,800
│▓▓│     │                                    │    LEVEL: 7
│▓ │     │          ░░                        │    LINES: 34
└──┘     │          ░░                        │
         │                                    │    COMBO: x3
HOLD:    │                                    │
┌──┐     │                                    │    NEXT SCAN:
│██│     │                    ▓▓              │    00:47
│██│     │                    ▓▓▓▓            │
└──┘     │        ████        ▓▓              │    ┌──────────┐
         │      ████████    ▓▓▓▓▓▓▓▓          │    │CORRUPTED │
         │    ██████████████▓▓▓▓▓▓▓▓██        │    │░░░░░░░░░░│
         │  ████████████████▓▓██████████      │    │CLEAR TO  │
         │  ██████████████████████████████    │    │DEFRAG    │
         └────────────────────────────────────┘    └──────────┘

██ = Normal block    ▓▓ = Corrupted block    ░░ = Purge block (special)
```

**Game Mechanics:**

1. **Standard Tetris:** 7 standard tetrominoes (I, O, T, S, Z, J, L). Standard rotation system (SRS). Hold piece. Next piece preview. Hard drop, soft drop. Wall kicks.

2. **Corruption (The Core Twist):**
   - Every 4-6 pieces, one block in the falling piece is "corrupted" (▓▓ instead of ██)
   - Corrupted blocks prevent line clears — a row with ANY corruption in it won't clear
   - Corruption slowly spreads: every 30 seconds, one existing corrupted block infects an adjacent block
   - Creates urgency to deal with corruption before it overtakes the board

3. **Purge Blocks (░░):**
   - Special piece that spawns every 15-20 pieces
   - When placed, it destroys all corrupted blocks in its row AND adjacent rows
   - Purge blocks themselves don't count as filled cells (they vanish after purging)
   - Strategic decision: place the Purge where it maximizes corruption removal

4. **Defrag Combos:**
   - Clearing 2+ lines simultaneously = "Defrag Combo"
   - 2 lines = x2 score
   - 3 lines = x4 score
   - 4 lines (Tetris) = x8 score + "SECTOR CLEARED" celebration
   - Back-to-back Tetrises = x16

5. **Trace Scan Integration (The GHOSTNET Hook):**
   - HUD shows time until your next trace scan in the main game
   - When scan is < 5 minutes away: speed increases by 10%
   - When scan is < 2 minutes away: speed increases by 25%
   - Lines cleared during the "scan pressure" window earn Trace Reduction:
     - 1-4 lines during pressure = -3% death rate for this scan
     - 5-9 lines = -5%
     - 10-19 lines = -10%
     - 20+ lines = -15%
   - This creates the ultimate tension: the scan is coming, the blocks are falling faster, and your survival depends on how well you play RIGHT NOW

6. **Memory Overflow (Game Over):**
   - Standard: blocks reach the top = overflow = game over
   - Corruption overflow: if corruption spreads to cover > 50% of the board = system crash = game over
   - Dual threat keeps both clean stacking AND corruption management in play

7. **Level Progression:**
   - Speed increases every 10 lines cleared (standard Tetris gravity curve)
   - Corruption frequency increases every 5 levels
   - Purge block frequency stays constant (doesn't scale — creates pressure)

**Thematic Fit:**
- Memory defragmentation is a real computer concept
- Corruption = hostile network fighting your organization
- Purge = antivirus / cleanup operation
- The board IS memory — organizing data under pressure
- Scan pressure connects arcade directly to core game stakes

**Skill Expression:**
- Standard Tetris skills (stacking, T-spins, combos, speed)
- Corruption management (isolating corruption, planning Purge placement)
- Scan pressure performance (playing well under increasing speed)
- Risk management (build high for Tetris vs. play safe for corruption)

**Streamability:**
- Tetris is inherently watchable and universally understood
- Corruption spreading creates visible danger
- Scan pressure moments are peak tension
- Perfect clears and T-spins are satisfying to watch
- "Board recovery" moments (coming back from near-overflow)

**Economy:**

| Aspect | Value | Notes |
|--------|-------|-------|
| Entry Fee | Free (basic) or 25 $DATA (overclocked mode) | Low barrier |
| Overclocked | Faster, more corruption, 2x rewards | Risk/reward |
| Scan Pressure Boost | -3% to -15% death rate | Directly impacts survival |
| Score Payout | Weekly tournament, top 50 split pool | Competitive |
| Perfect Clear | All lines clear (empty board) = 1000 $DATA | Aspirational |

**Implementation Complexity:** High
- Tetris game logic is well-defined but has many edge cases (wall kicks, T-spins, rotation systems)
- Corruption system adds complexity (spreading, purging, visual distinction)
- Real-time integration with main game scan timer
- Must feel "right" — Tetris players are extremely sensitive to input delay and piece behavior

**IP Consideration:**
The Tetris Company aggressively protects the Tetris trademark and has sued clones. The game must NOT be called "Tetris" and should differentiate enough in mechanics (corruption, purge blocks, scan integration) to be a distinct game. "Data Miner" or "Defrag" as names. The falling-block genre itself is not protected, only the Tetris brand.

**Open Questions:**
- [ ] How to handle T-spin detection? (Standard SRS vs. simplified?)
- [ ] Should corruption be visible in the "Next" piece preview?
- [ ] Multiplayer battle mode? (Send corruption to opponent on line clears?)
- [ ] Should scan pressure be opt-in? (Some players might not have active positions)
- [ ] How to differentiate enough from Tetris to avoid IP issues?

---

### IDEA 4: BREACH

**Elevator Pitch:** Space Invaders reimagined as firewall assault.

**Core Mechanic:** You're an exploit at the bottom of the screen. Firewall nodes descend from the top in formation. Fire exploits upward to destroy them. Shields protect you but degrade. Clear all nodes to breach the firewall layer. 10 waves of increasing difficulty.

**Visual Concept:**
```
┌──────────────────────────────────────────────────────────┐
│  ╔╗ ╔╗ ╔╗ ╔╗ ╔╗ ╔╗ ╔╗ ╔╗ ╔╗ ╔╗ ╔╗                     │
│  ╚╝ ╚╝ ╚╝ ╚╝ ╚╝ ╚╝ ╚╝ ╚╝ ╚╝ ╚╝ ╚╝                     │
│    ╔═╗ ╔═╗ ╔═╗ ╔═╗ ╔═╗ ╔═╗ ╔═╗ ╔═╗                     │
│    ╚═╝ ╚═╝ ╚═╝ ╚═╝ ╚═╝ ╚═╝ ╚═╝ ╚═╝                     │
│      ╔══╗ ╔══╗ ╔══╗ ╔══╗ ╔══╗ ╔══╗                       │
│      ╚══╝ ╚══╝ ╚══╝ ╚══╝ ╚══╝ ╚══╝                       │
│                    │                                       │
│                    │  ← INCOMING PACKET                    │
│                                                            │
│         ═══╗    ═══╗    ═══╗     ← SHIELDS                │
│         ═══╝    ═══╝    ═══╝                               │
│                                                            │
│                    ▲                                       │
│                   ╔█╗  ← YOUR EXPLOIT                     │
└──────────────────────────────────────────────────────────┘
```

**Game Mechanics:**

1. **Movement:** Left/right only (←→ or A/D). Your exploit slides along the bottom. Shoot upward with SPACE. One shot on screen at a time (classic rule) OR rapid fire (modern variant — configurable).

2. **Firewall Nodes (Enemies):**
   - Move in formation: left, down one row, right, down one row (classic pattern)
   - Fire packets downward at random intervals
   - Speed increases as fewer nodes remain
   - Different node types per row:

   | Node | Symbol | HP | Points | Behavior |
   |------|--------|----|--------|----------|
   | Standard | `╔╗` | 1 | 100 | Basic, fires packets |
   | Hardened | `╔═╗` | 2 | 250 | Drops shield repair on death |
   | Encrypted | `╔══╗` | 3 | 500 | Drops data cache (big score) |
   | Honeypot | `╔▓╗` | 1 | -200 | Shooting spawns 2 more nodes! |
   | Backdoor | `╔░╗` | 1 | 1000 | Clears entire row on death |

3. **Shields:** Three destructible shields between you and the formation. Shields absorb both incoming packets AND your own exploits. Shields degrade pixel-by-pixel (like original Space Invaders). Strategic shield management is key.

4. **Special Weapons (limited):**
   - **EMP Blast (E key):** Freezes all nodes for 3 seconds. 2 per game.
   - **Spread Shot (S key):** Next shot fires 3 exploits in a fan. 3 per game.
   - **Piercing Shot (D key):** Next shot passes through nodes, hitting everything in column. 1 per game.

5. **Wave Progression:**

   | Wave | Node Count | Speed | Special Nodes | New Mechanic |
   |------|-----------|-------|---------------|--------------|
   | 1 | 22 | Slow | None | Tutorial |
   | 2 | 30 | Slow | Hardened | Shield drops |
   | 3 | 33 | Medium | +Encrypted | Data caches |
   | 4 | 36 | Medium | +Honeypot | Trap awareness |
   | 5 | 40 | Fast | +Backdoor | Row clear |
   | 6 | 44 | Fast | Mixed | Combined tactics |
   | 7 | 48 | Very Fast | Heavy Encrypted | Endurance |
   | 8 | 50 | Very Fast | Heavy Honeypot | Trap gauntlet |
   | 9 | 55 | Extreme | All types | Everything |
   | 10 | 60 | Extreme | BOSS NODE | Final breach |

6. **Boss Node (Wave 10):**
   - Large node (3x3 character size) that moves independently
   - 20 HP
   - Fires spread patterns
   - Spawns mini-nodes periodically
   - Defeating it = BREACH COMPLETE

7. **Scoring:**
   ```
   Standard node:     100
   Hardened node:     250
   Encrypted node:    500
   Backdoor trigger:  1,000 + (nodes in row × 100)
   Honeypot (avoid):  -200 (if shot)
   Wave clear:        2,000 × wave_number
   Perfect wave:      No damage taken = 5,000 bonus
   No shields used:   3,000 bonus per wave
   Boss defeated:     50,000
   ```

**Thematic Fit:**
- You're an exploit attacking a firewall — core hacking metaphor
- Firewall nodes = layers of network defense
- Shields = your limited protection
- Packets = the firewall fighting back
- Breach = breaking through to the core

**Skill Expression:**
- Shot timing (one shot on screen = must be precise)
- Honeypot avoidance (don't shoot the traps!)
- Backdoor targeting (clear a row at the right time)
- Shield management (don't waste your cover)
- Special weapon optimization (when to use EMP vs. Spread vs. Pierce)
- Node priority (which to kill first as they descend)

**Economy:**

| Aspect | Value | Notes |
|--------|-------|-------|
| Entry Fee | 25-75 $DATA (burned) | Per run |
| Wave Payout | Clear wave = small $DATA reward | Incremental |
| Full Breach | Clear all 10 waves = -15% death rate for 8h | Major boost |
| Boss Kill | 500 $DATA bonus | Aspirational |
| Leaderboard | Score-based weekly | Competitive |

**Implementation Complexity:** Medium
- Space Invaders logic is straightforward
- Node AI is simple (formation movement + random fire)
- Collision detection is grid-based
- Boss node adds some complexity
- Shield degradation needs pixel-level tracking

**Open Questions:**
- [ ] One shot at a time (classic) or rapid fire (modern)?
- [ ] Should formation speed up as nodes die (classic) or stay constant?
- [ ] Cooperative variant? (2 players share the screen)
- [ ] Should waves be repeatable (farm) or one-attempt?

---

### IDEA 5: TUNNEL RUN

**Elevator Pitch:** Endless runner through a network tunnel. Dodge obstacles, collect data, survive as long as possible.

**Core Mechanic:** You're a data packet escaping through a network tunnel. The tunnel scrolls vertically (toward you). Walls narrow, obstacles appear, data fragments float past. Dodge left and right. Speed increases. Phase Shift lets you pass through one obstacle (limited uses). Pure reflex. Pure flow state.

**Visual Concept:**
```
         ║                              ║
         ║      ◆                       ║
         ║                              ║
         ║          ████████            ║
         ║                              ║
         ║   ◆                    ◆     ║
         ║                              ║
         ╠══════════╗                   ║
         ║          ║                   ║
         ║          ║         ████████  ║
         ║          ║                   ║
         ║          ╚══════════════╗    ║
         ║                        ║    ║
         ║            @           ║    ║
         ║                        ║    ║
         ╚════════════════════════╩════╝
```

**Full UI Wireframe:**
```
╔══════════════════════════════════════════════════════════════════╗
║  TUNNEL RUN v1.0 ░░░░░░░░░░░░░░░░░░░░░░  SPEED: ████████░░     ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║         ║                              ║                         ║
║         ║      ◆                       ║                         ║
║         ║                              ║                         ║
║         ║          ████████            ║                         ║
║         ║                              ║                         ║
║         ║   ◆                    ◆     ║                         ║
║         ║                              ║                         ║
║         ╠══════════╗                   ║                         ║
║         ║          ║                   ║                         ║
║         ║          ║         ████████  ║                         ║
║         ║          ║                   ║                         ║
║         ║          ╚══════════════╗    ║                         ║
║         ║                        ║    ║                         ║
║         ║            @           ║    ║                         ║
║         ║                        ║    ║                         ║
║         ╚════════════════════════╩════╝                         ║
║                                                                  ║
║  DISTANCE: 4,847m    DATA: 23    PHASE SHIFTS: 2/3              ║
║  CLOSE CALLS: 7      BEST: 12,340m                              ║
║                                                                  ║
║  [←→] or [AD] Dodge    [SPACE] Phase Shift                      ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

**Game Mechanics:**

1. **Movement:** Left/right only (←→ or A/D). Player stays near the bottom of the screen. The tunnel scrolls from top to bottom. Player moves in discrete lanes (5-7 lanes) for clean ASCII rendering. Movement is instant (no animation delay — reflexes matter).

2. **Tunnel Generation:**
   - Tunnel walls define the playable width
   - Walls periodically narrow and widen (sinusoidal pattern + random variation)
   - Minimum width: 3 lanes (extreme difficulty)
   - Wall changes are telegraphed 4-5 rows in advance (visible on screen)

3. **Obstacles:**
   - **ICE Blocks (████):** Static horizontal barriers. Occupy 2-4 lanes. Must dodge around them.
   - **Patrol Beams (───):** Horizontal lines that move left/right within the tunnel. Timing-based dodge.
   - **Closing Gates (╠══╗ / ╚══╣):** Tunnel walls that jut inward temporarily. Creates narrow passages.
   - **Tracer Pulse (▓▓▓▓):** Vertical line that sweeps across the tunnel. Must be in a gap to survive.

4. **Data Fragments (◆):**
   - Float down the tunnel in patterns
   - Collecting them increases score and serves as "currency" for Phase Shifts
   - Every 10 data fragments = +1 Phase Shift charge
   - Risk/reward: some data is positioned dangerously (near walls, between obstacles)

5. **Phase Shift (SPACE):**
   - Start with 3 charges. Earn more from data collection.
   - Activating makes you intangible for 0.5 seconds (pass through one obstacle)
   - Visual: player character becomes `░` (transparent) briefly
   - Cannot be spammed — 2 second cooldown between shifts

6. **Speed Ramp:**

   | Distance | Speed | Tunnel Width | Obstacle Density |
   |----------|-------|--------------|-----------------|
   | 0-1000m | Slow | Wide (7 lanes) | Sparse |
   | 1000-3000m | Medium | Medium (5-7) | Moderate |
   | 3000-5000m | Fast | Narrow (4-6) | Dense |
   | 5000-8000m | Very Fast | Very Narrow (3-5) | Very Dense |
   | 8000m+ | Extreme | Minimum (3-4) | Maximum |

7. **Close Calls:**
   - Passing within 1 cell of an obstacle = "Close Call"
   - Close Calls build a multiplier: 1.1x, 1.2x, ... up to 2.0x
   - Multiplier resets on Phase Shift use (incentivizes NOT using Phase Shift)
   - Close Call counter displayed in HUD

8. **Scoring:**
   ```
   Distance:              1 point per meter
   Data Fragment:         100 points × multiplier
   Close Call:            50 points + multiplier increase
   Phase Shift unused:    500 bonus per unused shift at end
   Milestone (1000m):     1,000 points
   Milestone (5000m):     10,000 points
   Milestone (10000m):    50,000 points
   ```

**Thematic Fit:**
- You're a data packet escaping the network
- The tunnel is the connection being traced
- Walls closing in = the trace getting closer
- Obstacles = network countermeasures
- Phase Shift = Ghost Protocol (brief intangibility)
- Speed increasing = the network accelerating its pursuit

**Why this might be THE game to build first:**
- **Simplest controls** — literally just left, right, and space
- **Lowest implementation complexity** — no AI, no complex state
- **Infinite replayability** — procedural, endless, "just one more run"
- **Perfect session length** — runs are 1-3 minutes
- **Hypnotic flow state** — the scrolling ASCII tunnel is mesmerizing
- **Universal metric** — "how far did you get?" is the simplest leaderboard
- **Mobile friendly** — swipe left/right translates perfectly
- **Immediately understandable** — 2 seconds to grasp the concept

**Economy:**

| Aspect | Value | Notes |
|--------|-------|-------|
| Entry Fee | Free (practice) or 10-50 $DATA (ranked) | Lowest barrier |
| Reward | Distance × Data × Multiplier = score → $DATA | Score-based |
| Distance Boost | 1000m = +5% yield 2h / 5000m = +15% yield 4h | Milestone |
| Death Rate Boost | 3000m = -5% for 2h / 8000m = -10% for 4h | Harder milestones |
| Tournament | Weekly, top distances split pool | Competitive |

**Implementation Complexity:** Low
- Simple lane-based movement
- Procedural tunnel generation (noise function)
- Obstacle spawning on a timer
- No AI, no pathfinding
- Collision is just lane comparison
- Scroll speed is a single variable

**Implementation Path:**
```
/lib/features/tunnel-run/
├── components/
│   ├── TunnelGame.svelte        # Main game + loop
│   ├── TunnelRenderer.svelte    # ASCII tunnel drawing
│   ├── Player.svelte            # Player character
│   ├── HUD.svelte               # Distance, data, phase shifts
│   ├── GameOver.svelte          # Results + rewards
│   └── StartScreen.svelte       # Entry fee selection
├── engine/
│   ├── tunnel-generator.ts      # Procedural tunnel + obstacles
│   ├── collision.ts             # Lane-based collision
│   ├── scoring.ts               # Score + multiplier calc
│   └── game-loop.ts             # Frame update
├── store.svelte.ts              # Game state
├── audio.ts                     # Sound effects
└── constants.ts                 # Speed curves, tuning
```

**Open Questions:**
- [ ] Should the tunnel scroll from top-to-bottom or bottom-to-top?
- [ ] Landscape or portrait orientation preference?
- [ ] Should there be "zones" (visual theme changes at distance milestones)?
- [ ] Power-ups beyond Phase Shift? (Magnet, shield, slow-mo?)
- [ ] Should close calls have an audio cue? (Adds to tension)

---

### IDEA 6: GRID WARS

**Elevator Pitch:** Minesweeper reimagined as real-time network scanning with moving threats.

**Core Mechanic:** Scan a network grid to find ICE (mines). Numbers tell adjacency. But ICE nodes *move* every 30 seconds — you must constantly re-evaluate. Timed. Flagging all ICE nodes = sector cleared. Hit an ICE node = game over.

**Visual Concept:**
```
    A   B   C   D   E   F   G   H   I   J
  ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
 1│ 1 │ 1 │ ░ │ ░ │ ░ │ ░ │ ░ │ ░ │ ░ │ ░ │
  ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 2│   │ 1 │ 2 │ ░ │ ░ │ ░ │ ░ │ ░ │ ░ │ ░ │
  ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 3│   │   │ 1 │ 2 │ ░ │ ░ │ ░ │ ░ │ ░ │ ░ │
  ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 4│   │   │   │ 1 │ ░ │ ░ │ ░ │ ░ │ ░ │ ░ │
  ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 5│ 1 │ 1 │   │ 1 │ ░ │ ░ │ ░ │ ░ │ ░ │ ░ │
  └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

░ = UNKNOWN    ✖ = ICE (mine)    ⚑ = FLAGGED    [number] = adjacency
```

**Game Mechanics:**

1. **Grid Navigation:** Arrow keys to move cursor. SPACE to reveal cell. F to flag/unflag. R to use Radar Scan (reveals 3x3 area, limited uses).

2. **Standard Minesweeper Rules:** Numbers show adjacent ICE count. Revealing an ICE node = game over. Flag all ICE = win. Revealing a 0 auto-reveals all adjacent 0s.

3. **Moving ICE (The Core Twist):**
   - Every 30 seconds, a warning appears: `⚠ ICE SHIFT INCOMING ⚠`
   - Each ICE node moves to a random adjacent cell
   - Previously revealed numbers update to reflect new positions
   - Flags on cells that are no longer ICE become incorrect (visual warning)
   - This fundamentally breaks standard Minesweeper strategies — you can't just logic it out once, you must continuously scan and adapt

4. **Radar Scan (R key):**
   - Reveals all cells in a 3x3 area (including ICE, shown briefly then re-hidden)
   - 3 uses per game
   - Invaluable after an ICE Shift to quickly re-orient
   - Strategic decision: use early for progress or save for post-shift recovery

5. **Difficulty Levels:**

   | Difficulty | Grid | ICE Count | Shift Interval | Radar Uses |
   |------------|------|-----------|----------------|------------|
   | Easy | 8x8 | 8 | 45 seconds | 4 |
   | Medium | 10x10 | 15 | 30 seconds | 3 |
   | Hard | 12x12 | 25 | 25 seconds | 2 |
   | Extreme | 15x15 | 40 | 20 seconds | 1 |

6. **Scoring:**
   ```
   Cell revealed:         10 points
   Correct flag:          50 points
   Sector cleared:        1,000 × difficulty_multiplier
   Time bonus:            Remaining seconds × 20
   No Radar used:         500 bonus per unused Radar
   Post-shift clear:      200 bonus per correct flag placed after a shift
   ```

**Thematic Fit:**
- Scanning a network for intrusion countermeasures
- ICE = security nodes hidden in the grid
- Radar Scan = deep network probe
- ICE Shift = dynamic security reconfiguration (the network adapts to your scanning)
- Flagging = marking threats for avoidance

**Skill Expression:**
- Logic and deduction (core Minesweeper skill)
- Memory (remembering revealed information post-shift)
- Radar timing (when to use the limited resource)
- Speed (time pressure forces quick decisions)
- Risk assessment (when to guess vs. when to gather more info)
- Adaptation (re-evaluating after ICE shifts)

**Economy:**

| Aspect | Value | Notes |
|--------|-------|-------|
| Entry Fee | 15-50 $DATA (burned) | Per game |
| Clear Reward | Difficulty × 50 $DATA | Direct payout |
| Speed Bonus | Clear under par time = 2x reward | Skill reward |
| Streak Bonus | 3 consecutive clears = -5% death rate 4h | Consistency |
| Daily Puzzle | Fixed seed, everyone plays same board | Fair competition |

**Implementation Complexity:** Low-Medium
- Minesweeper logic is well-known
- Moving ICE adds state management complexity
- Grid rendering is straightforward ASCII
- No real-time physics or animation needed
- Cursor-based interaction is simple

**Why it might not be first priority:**
- Slower-paced than other options — doesn't match GHOSTNET's high-energy vibe as well
- Less streamable (watching someone think isn't as exciting as watching someone dodge)
- Moving ICE is a great twist but might frustrate minesweeper purists

**Potential Variant — Daily Puzzle:**
- Same seed for all players each day
- Everyone plays the same board with the same ICE shifts
- Leaderboard by time
- Creates "did you beat today's Grid Wars?" social moment
- No entry fee for daily puzzle (engagement driver)

**Open Questions:**
- [ ] Should revealed numbers update in real-time when ICE shifts? (Or only when you re-reveal?)
- [ ] Should there be visual hints about which direction ICE shifted?
- [ ] Is the daily puzzle variant more compelling than the standard game?
- [ ] Should there be a "no shift" classic mode for practice?

---

## Comparative Analysis

### Quick Comparison Matrix

| Game | Controls | Session | Complexity | Streamable | Mobile | Thematic Fit | Build Effort |
|------|----------|---------|------------|------------|--------|--------------|--------------|
| Ghost Maze | WASD + Space | 3-5 min | Med-High | High | Hard | Perfect | Medium-High |
| Signal Snake | WASD + Space | 1-3 min | Medium | Medium | Medium | Strong | Low-Medium |
| Data Miner | Standard Tetris | 3-10 min | High | High | Hard | Good | High |
| Breach | ←→ + Space | 3-5 min | Medium | High | Easy | Strong | Medium |
| Tunnel Run | ←→ + Space | 1-3 min | Low | Medium | Easy | Strong | Low |
| Grid Wars | Arrows + Space/F | 2-5 min | Medium | Low | Hard | Good | Low-Medium |

### Scoring Against Constraints

| Game | C1 Terminal | C2 Keyboard | C3 Economy | C4 Session | C5 Skill | C6 Stream | C7 Fair | C8 Mobile | TOTAL |
|------|-------------|-------------|------------|------------|----------|-----------|---------|-----------|-------|
| Ghost Maze | 5 | 5 | 5 | 5 | 5 | 5 | 4 | 2 | **36** |
| Signal Snake | 5 | 5 | 4 | 5 | 4 | 4 | 5 | 3 | **35** |
| Data Miner | 4 | 5 | 5 | 4 | 5 | 5 | 4 | 2 | **34** |
| Breach | 5 | 5 | 4 | 4 | 4 | 5 | 5 | 4 | **36** |
| Tunnel Run | 5 | 5 | 4 | 5 | 3 | 4 | 5 | 5 | **36** |
| Grid Wars | 5 | 5 | 4 | 4 | 5 | 2 | 5 | 2 | **32** |

(Scale: 1=poor fit, 5=perfect fit)

### Build Priority Recommendation

**Tier 1 — Build First (Maximum Impact, Minimum Risk):**

1. **TUNNEL RUN** — Lowest build effort, highest replayability, best mobile support, simplest to understand. This is the "snack game" — quick, addictive, always available. Build in 1-2 weeks.

2. **GHOST MAZE** — Highest thematic fit (you ARE a ghost!), most depth, best streamability. This is the "main course" — the game people tell others about. Build in 2-3 weeks.

**Tier 2 — Build Second (Strong Value, Higher Effort):**

3. **BREACH** — Familiar mechanic (Space Invaders), good variety (different from reflex/maze), boss fights create memorable moments. Build in 2 weeks.

4. **SIGNAL SNAKE** — Unique twist on Snake, strong thematic fit, good skill expression. Could replace Tunnel Run if we want more depth in the "quick game" slot. Build in 1-2 weeks.

**Tier 3 — Build Later (Good Ideas, Lower Priority):**

5. **GRID WARS** — Interesting twist on Minesweeper but doesn't match GHOSTNET's high-energy vibe. Best as a "daily puzzle" side feature. The moving ICE mechanic is genuinely novel.

6. **DATA MINER** — Would be fantastic but highest build effort and IP risk. Save for when the arcade is established and we need a deep skill game. The scan pressure integration is the best economy hook of any game here.

---

## Cross-Cutting Ideas

### Shared Arcade Infrastructure
All games should share:
- **ArcadeCore contract** (already deployed) for session tracking and payouts
- **FutureBlockRandomness** (already deployed) for seed generation
- **Leaderboard system** (shared backend, per-game rankings)
- **Reward framework** (boosts, $DATA payouts, streaks)
- **Sound system** (ZzFX, already in place)
- **Game shell component** (entry fee, results, back-to-lobby)

### Arcade Lobby
A central "Arcade" page that shows all available games:
```
╔══════════════════════════════════════════════════════════════════╗
║  GHOSTNET ARCADE ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  SELECT GAME    ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          ║
║  │  TUNNEL RUN  │  │  GHOST MAZE  │  │   BREACH     │          ║
║  │              │  │              │  │              │          ║
║  │  ►►►  @  ►►►  │  │  @ · · T ·  │  │  ╔╗ ╔╗ ╔╗   │          ║
║  │              │  │  · ═══ · ·  │  │     ▲       │          ║
║  │  BEST: 8,400m│  │  BEST: LVL 4│  │  BEST: W7   │          ║
║  │  [PLAY 10D]  │  │  [PLAY 25D]  │  │  [PLAY 25D]  │          ║
║  └──────────────┘  └──────────────┘  └──────────────┘          ║
║                                                                  ║
║  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          ║
║  │ SIGNAL SNAKE │  │  HASH CRASH  │  │  CODE DUEL   │          ║
║  │              │  │              │  │              │          ║
║  │  ████████@   │  │  ▲ 2.47x    │  │  VS          │          ║
║  │              │  │  █████░░░   │  │  ████░░ 67%  │          ║
║  │  BEST: 147s  │  │  LAST: 3.2x │  │  RECORD: 23W │          ║
║  │  [PLAY 10D]  │  │  [PLAY 10D]  │  │  [PLAY 50D]  │          ║
║  └──────────────┘  └──────────────┘  └──────────────┘          ║
║                                                                  ║
║  DAILY OPS: ✓✓○○○  │  TOURNAMENTS: BREACH Weekly (2d left)     ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### Tournament System
Weekly or daily tournaments for each game:
- Fixed seed (same conditions for everyone)
- Entry fee pooled (minus burn)
- Top 10/25/50 split the pool
- Creates recurring engagement loop
- "Tournament Tuesday" for Ghost Maze, "Speed Saturday" for Tunnel Run, etc.

### Cross-Game Achievements
Badges earned across the arcade:
- **Arcade Rat** — Play 100 total games
- **Ghost Runner** — 10,000m in Tunnel Run
- **Maze Master** — Perfect clear Ghost Maze on Level 5
- **Firewall Breacher** — Clear all 10 waves in Breach
- **Multitasker** — Play 3 different games in one day
- **Whale Gamer** — Spend 1,000 $DATA total in arcade

### Integration with Main Game Scans
The most powerful idea across all games: **playing during scan proximity earns bonus protection.** This creates a natural gameplay loop:

```
1. Check GHOSTNET → scan in 5 minutes
2. Open arcade → play Tunnel Run
3. Hit 3,000m milestone → -5% death rate earned
4. Scan executes → reduced death rate applied
5. Survive → back to arcade for next scan window
```

This turns the scan countdown (a passive waiting experience) into an active gameplay opportunity.

---

## Questions to Explore

- [ ] Which 2 games should we build first?
- [ ] Should all games share a single Arcade route (/arcade/) or have individual routes?
- [ ] What's the right entry fee range? Too high = barrier, too low = no burn impact
- [ ] Should there be a free practice mode for every game? (Builds skill without economic risk)
- [ ] How to prevent botting/automation? (Input pattern analysis, timing verification)
- [ ] Should games be playable without a GHOSTNET position? (Spectator arcade?)
- [ ] Tournament prize structure — flat split or weighted by rank?
- [ ] Cross-game progression — should playing more arcade games give compounding bonuses?
- [ ] Audio toggle per game or global arcade audio setting?
- [ ] Should game results appear in The Feed? (`> 0x7a3f hit 12,000m in Tunnel Run`)

---

## Connections

- Related to [[capabilities/minigames]] — All games become FR-GAME entries
- Related to [[capabilities/economy#burn-engine---mini-game-entry]] — FR-ECON-006 burn mechanics
- Related to [[architecture#indexer]] — Game results need indexing for leaderboards
- See [[design/arcade/]] — Existing arcade game specifications
- See ArcadeCore contract — Shared infrastructure already deployed
- See FutureBlockRandomness — Provably fair randomness ready to use

---

## Processing Notes

> [!info] Status: Unprocessed
> This brainstorm needs review to determine:
> 1. Which games to promote to capability specs (FR-GAME-011+)
> 2. Implementation timeline relative to H2/H3 roadmap
> 3. Contract requirements (new contracts vs. existing ArcadeCore)
> 4. Design specs to create in `docs/design/arcade/games/`
