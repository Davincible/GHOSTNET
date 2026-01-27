# BOUNTY HUNT

## Game Design Document

**Category:** Strategy  
**Phase:** 3B (Skill Expansion)  
**Complexity:** High  
**Development Time:** 2-3 weeks  

---

## Overview

BOUNTY HUNT is a strategic deduction game where players become hunters and prey simultaneously. Each player receives a secret target assigned via **future block hash** - provably fair on-chain randomness. Players must deduce their target's identity through clues. Successfully identify your target to claim their stake. Get identified yourself, and you lose everything.

```
+======================================================================+
|                          BOUNTY HUNT                                  |
+======================================================================+
|                                                                       |
|  YOUR BOUNTY TARGET:  ???                   CYCLE: 7 of 12            |
|  +-----------------------------------------------------------------+  |
|  |                                                                 |  |
|  |  INTEL GATHERED:                                                |  |
|  |  > Entry amount between 200-300 $DATA                           |  |
|  |  > Joined in first 30 seconds                                   |  |
|  |  > Risk level: DARKNET or higher                                |  |
|  |  > Last 4 of address: **** (locked - 2 cycles)                  |  |
|  |                                                                 |  |
|  +-----------------------------------------------------------------+  |
|                                                                       |
|  SUSPECTS IN RANGE: 4 players match intel                             |
|  [0x7a3f..] [0x9c2d..] [0x3b1a..] [0x8f2e..]                         |
|                                                                       |
|  +-----------------------------------------------------------------+  |
|  |  [ ACQUIRE INTEL - 25 $DATA ]    [ EXECUTE BOUNTY ]            |  |
|  +-----------------------------------------------------------------+  |
|                                                                       |
|  HUNTERS ON YOU: 1-3 (estimated)       YOUR COVER: 67% INTACT        |
|                                                                       |
+======================================================================+
```

---

## Core Mechanics

### Game Flow

```
1. REGISTRATION PHASE (60 seconds)
   +-- Players stake 50-500 $DATA to enter
   +-- Future block committed for randomness
   +-- All stakes go to central prize pool

2. TARGET ASSIGNMENT
   +-- Each player receives a secret target (another player)
   +-- Circular chain: A hunts B, B hunts C, C hunts A...
   +-- Target identity hidden - only clues revealed

3. INTEL CYCLES (12 cycles, 30 seconds each = 6 minutes)
   +-- Each cycle: one new clue revealed about your target
   +-- Players can spend $DATA to reveal additional clues
   +-- Players can attempt bounty execution at any time
   +-- Players can lay false trails to confuse their hunters

4. EXECUTION PHASE
   +-- Guess your target's identity
   +-- Correct: Claim their stake + bonus from pool
   +-- Wrong: Reveal yourself, lose protection clues

5. SURVIVAL BONUS
   +-- Players never identified share remaining pool
   +-- Larger shares for players who also got their target
```

### Target Assignment Algorithm

```javascript
// Circular assignment ensures everyone is both hunter and prey
// Uses future block hash for provably fair randomness (MegaETH-compatible)
function assignTargets(players: address[], seedBlock: number, gameId: number): Map<address, address> {
  // Wait for seed block to be mined
  const blockHash = await getBlockHash(seedBlock);
  
  // Create deterministic seed from block hash + game context
  const seed = keccak256(encode(blockHash, gameId, contractAddress, players.length));
  
  // Shuffle players using Fisher-Yates with seed
  const shuffled = fisherYatesShuffle(players, seed);
  
  const targets = new Map();
  
  // Circular chain: each player hunts the next
  for (let i = 0; i < shuffled.length; i++) {
    const hunter = shuffled[i];
    const target = shuffled[(i + 1) % shuffled.length];
    targets.set(hunter, target);
  }
  
  return targets;
}

// Example with 5 players:
// A -> B -> C -> D -> E -> A (circular)
// Everyone hunts exactly one person
// Everyone is hunted by exactly one person
```

### Intel System

Players gather clues about their target. Clues are revealed progressively:

| Cycle | Free Clue Revealed | Specificity |
|-------|-------------------|-------------|
| 1 | Entry bracket (50-100, 100-200, 200-300, 300-500) | Low |
| 2 | Join timing (first/middle/last third of registration) | Low |
| 3 | Current risk level in main game | Medium |
| 4 | Number of previous bounty hunt games played | Medium |
| 5 | Whether they've acquired intel this game | Medium |
| 6 | Address prefix (first 2 hex chars after 0x) | High |
| 7 | Their stake amount (exact) | High |
| 8 | Whether they've attempted an execution | High |
| 9 | Number of hunters targeting them | Medium |
| 10 | Address suffix (last 2 hex chars) | High |
| 11 | Time since their last action | Medium |
| 12 | Full address revealed | Critical |

**Purchasable Intel (25 $DATA each):**
- Skip ahead to next clue tier
- Reveal if target is currently online
- Get target's recent feed activity (anonymized)
- Narrow down suspect list to 50%

### False Trail System

Players can spend $DATA to obscure their identity:

```
FALSE TRAIL OPTIONS (Cost: 15 $DATA each)
+-------------------------------------------------+
| [ ] Spoof Entry Bracket  - Appear in different range    |
| [ ] Mask Risk Level      - Show random level            |
| [ ] Ghost Timestamp      - Randomize join time          |
| [ ] Decoy Address        - Add noise to prefix/suffix   |
+-------------------------------------------------+
Active Trails: 2/4          Cover Integrity: 78%
```

Each false trail reduces hunter accuracy but degrades over cycles.

### Execution Mechanics

```
EXECUTE BOUNTY
+-------------------------------------------------------------+
|                                                             |
|  SELECT YOUR TARGET:                                        |
|                                                             |
|  [ ] 0x7a3f...8c2d  - 87% match to intel                   |
|  [ ] 0x9c2d...1a4b  - 73% match to intel                   |
|  [ ] 0x3b1a...f2e7  - 65% match to intel                   |
|  [ ] 0x8f2e...3c9a  - 52% match to intel                   |
|                                                             |
|  WARNING: Wrong execution reveals 2 clues about YOU        |
|                                                             |
|  [ CONFIRM EXECUTION ]              [ CANCEL ]              |
|                                                             |
+-------------------------------------------------------------+
```

**Execution Outcomes:**

| Result | Consequence |
|--------|-------------|
| Correct Target | Claim target's stake + 20% pool bonus |
| Wrong Target | Lose 2 cover layers, target notified |
| 3 Wrong Attempts | Eliminated from game, stake redistributed |

---

## User Interface

### States

**1. Registration Phase**
```
+======================================================================+
|  BOUNTY HUNT                                      ROUND #847          |
+======================================================================+
|                                                                       |
|                    HUNTERS ASSEMBLING                                 |
|                                                                       |
|                         [47]                                          |
|                                                                       |
|                    REGISTRATION CLOSES IN                             |
|                          00:34                                        |
|                                                                       |
|  +---------------------------------------------------------------+   |
|  |                                                               |   |
|  |  ENTRY STAKE:  [    250    ] $DATA                            |   |
|  |                                                               |   |
|  |  QUICK STAKE: [50] [100] [250] [500] [MAX]                   |   |
|  |                                                               |   |
|  +---------------------------------------------------------------+   |
|                                                                       |
|                      [ JACK IN TO HUNT ]                              |
|                                                                       |
|  +---------------------------------------------------------------+   |
|  |  PRIZE POOL: 8,450 $DATA          MIN HUNTERS: 8 (met)       |   |
|  |  YOUR ODDS: ~2.1% per player      MAX HUNTERS: 64            |   |
|  +---------------------------------------------------------------+   |
|                                                                       |
+======================================================================+
```

**2. Target Assignment (Reveal Animation)**
```
+======================================================================+
|  BOUNTY HUNT                                      ROUND #847          |
+======================================================================+
|                                                                       |
|                    ASSIGNING TARGETS...                               |
|                                                                       |
|               +-----------------------------+                         |
|               |                             |                         |
|               |   > Waiting for seed block...|                         |
|               |   > Block mined!            |                         |
|               |   > Shuffling hunters...    |                         |
|               |   > Assigning bounties...   |                         |
|               |                             |                         |
|               |   ████████████░░░░  73%     |                         |
|               |                             |                         |
|               +-----------------------------+                         |
|                                                                       |
|              BLOCK HASH: 0x7a3f...8c2d                               |
|              HUNTERS: 47                                              |
|              CHAIN LENGTH: 47                                         |
|                                                                       |
+======================================================================+
```

**3. Active Hunt - Early Cycles**
```
+======================================================================+
|  BOUNTY HUNT                        CYCLE 3/12          00:22        |
+======================================================================+
|                                                                       |
|  YOUR TARGET                           YOUR STATUS                    |
|  +--------------------------+          +--------------------------+   |
|  |                          |          |                          |   |
|  |  IDENTITY: UNKNOWN       |          |  COVER: 100% INTACT      |   |
|  |                          |          |  HUNTERS: 1 (confirmed)  |   |
|  |  INTEL GATHERED:         |          |  FALSE TRAILS: 0 active  |   |
|  |  > 200-300 $DATA entry   |          |                          |   |
|  |  > Joined: first third   |          |  BALANCE: 225 $DATA      |   |
|  |  > Risk: DARKNET+        |          |                          |   |
|  |                          |          +--------------------------+   |
|  |  SUSPECTS: 12 players    |                                        |
|  |                          |          NEXT CLUE IN: 00:22           |
|  +--------------------------+                                        |
|                                                                       |
|  +---------------------------------------------------------------+   |
|  |  [ ACQUIRE INTEL ]   [ LAY FALSE TRAIL ]   [ EXECUTE BOUNTY ] |   |
|  |      25 $DATA             15 $DATA            HIGH RISK       |   |
|  +---------------------------------------------------------------+   |
|                                                                       |
|  LIVE FEED:                                                          |
|  > Hunter executed bounty... MISS! Cover blown                       |
|  > 3 hunters acquired intel this cycle                               |
|  > Target eliminated - bounty redistributed                          |
|                                                                       |
+======================================================================+
```

**4. Active Hunt - Late Cycles (High Intel)**
```
+======================================================================+
|  BOUNTY HUNT                        CYCLE 10/12         00:15        |
+======================================================================+
|                                                                       |
|  YOUR TARGET                           YOUR STATUS                    |
|  +--------------------------+          +--------------------------+   |
|  |                          |          |                          |   |
|  |  IDENTITY: NARROWING     |          |  COVER: 34% [##----]     |   |
|  |                          |          |  HUNTERS: 1 (confirmed)  |   |
|  |  INTEL GATHERED:         |          |  FALSE TRAILS: 2 active  |   |
|  |  > Exactly 275 $DATA     |          |    - Bracket spoof       |   |
|  |  > 0x7a** prefix         |          |    - Risk mask           |   |
|  |  > **2d suffix           |          |                          |   |
|  |  > DARKNET risk level    |          |  BALANCE: 125 $DATA      |   |
|  |  > Made 1 execution      |          |                          |   |
|  |                          |          +--------------------------+   |
|  |  SUSPECTS: 2 players     |                                        |
|  |  > 0x7a3f...8c2d [94%]   |          !!! DANGER !!!                |
|  |  > 0x7a91...1e2d [78%]   |          Your hunter has high intel   |
|  |                          |          Consider false trails NOW     |
|  +--------------------------+                                        |
|                                                                       |
|  +---------------------------------------------------------------+   |
|  |  [ ACQUIRE INTEL ]   [ LAY FALSE TRAIL ]   [ EXECUTE BOUNTY ] |   |
|  |      25 $DATA             15 $DATA            >>> READY <<<   |   |
|  +---------------------------------------------------------------+   |
|                                                                       |
+======================================================================+
```

**5. Execution Confirmation**
```
+======================================================================+
|  BOUNTY HUNT                                      ROUND #847          |
+======================================================================+
|                                                                       |
|              +----------------------------------------+               |
|              |                                        |               |
|              |     !!!  EXECUTE BOUNTY  !!!           |               |
|              |                                        |               |
|              |     TARGET: 0x7a3f...8c2d              |               |
|              |     CONFIDENCE: 94%                    |               |
|              |     STAKE: 275 $DATA                   |               |
|              |                                        |               |
|              |     IF CORRECT:                        |               |
|              |     > Claim 275 $DATA stake            |               |
|              |     > Bonus: +55 $DATA (pool 20%)      |               |
|              |     > Total: 330 $DATA                 |               |
|              |                                        |               |
|              |     IF WRONG:                          |               |
|              |     > 2 cover layers revealed          |               |
|              |     > Target is notified               |               |
|              |     > Wrong attempts: 1/3              |               |
|              |                                        |               |
|              |  [ CONFIRM KILL ]    [ ABORT ]         |               |
|              |                                        |               |
|              +----------------------------------------+               |
|                                                                       |
+======================================================================+
```

**6. Successful Execution**
```
+======================================================================+
|  BOUNTY HUNT                                      ROUND #847          |
+======================================================================+
|                                                                       |
|              +----------------------------------------+               |
|              |                                        |               |
|              |     >>> BOUNTY CLAIMED <<<             |               |
|              |                                        |               |
|              |          +-----------+                 |               |
|              |          | CONFIRMED |                 |               |
|              |          +-----------+                 |               |
|              |                                        |               |
|              |     TARGET: 0x7a3f...8c2d              |               |
|              |     STATUS: ELIMINATED                 |               |
|              |                                        |               |
|              |     CLAIMED: 275 $DATA                 |               |
|              |     BONUS:   +55 $DATA                 |               |
|              |     -------------------------          |               |
|              |     TOTAL:   330 $DATA                 |               |
|              |                                        |               |
|              |     You still have a hunter.           |               |
|              |     Stay hidden until round ends.      |               |
|              |                                        |               |
|              +----------------------------------------+               |
|                                                                       |
+======================================================================+
```

**7. Got Hunted (Elimination)**
```
+======================================================================+
|  BOUNTY HUNT                                      ROUND #847          |
+======================================================================+
|                                                                       |
|              +----------------------------------------+               |
|              |                                        |               |
|              |         !!! TRACED !!!                 |               |
|              |                                        |               |
|              |     +-----------------------+          |               |
|              |     |   Y O U   D I E D     |          |               |
|              |     +-----------------------+          |               |
|              |                                        |               |
|              |     HUNTER: 0x9c2d...1a4b              |               |
|              |     YOUR STAKE: CLAIMED                |               |
|              |                                        |               |
|              |     -250 $DATA                         |               |
|              |                                        |               |
|              |     They gathered 9 intel clues       |               |
|              |     Your false trails failed at       |               |
|              |     cycle 8 when risk was revealed    |               |
|              |                                        |               |
|              |     [ SPECTATE ]    [ EXIT ]           |               |
|              |                                        |               |
|              +----------------------------------------+               |
|                                                                       |
+======================================================================+
```

**8. Round End - Survivor Results**
```
+======================================================================+
|  BOUNTY HUNT                               ROUND #847 COMPLETE        |
+======================================================================+
|                                                                       |
|                       HUNT CONCLUDED                                  |
|                                                                       |
|  YOUR RESULTS                                                         |
|  +---------------------------------------------------------------+   |
|  |                                                               |   |
|  |  STATUS: SURVIVOR                                             |   |
|  |                                                               |   |
|  |  Bounty Claimed:      275 $DATA  (target: 0x7a3f)            |   |
|  |  Survival Bonus:      +42 $DATA  (pool share)                |   |
|  |  Intel Spent:         -75 $DATA                               |   |
|  |  False Trails:        -30 $DATA                               |   |
|  |  Entry Returned:        0 $DATA  (burned)                     |   |
|  |  ----------------------------------------------------------- |   |
|  |  NET PROFIT:         +212 $DATA                               |   |
|  |                                                               |   |
|  +---------------------------------------------------------------+   |
|                                                                       |
|  ROUND STATISTICS                                                     |
|  +---------------------------------------------------------------+   |
|  |  Hunters:      47        |  Eliminations:     31              |   |
|  |  Survivors:    16        |  Bounties Claimed: 28              |   |
|  |  Prize Pool:   8,450     |  Total Burned:     2,112 $DATA     |   |
|  +---------------------------------------------------------------+   |
|                                                                       |
|  TOP HUNTERS                                                          |
|  > 0x1d4c - 2 bounties, survived, +892 $DATA                         |
|  > 0x8f2e - 1 bounty, survived, +445 $DATA                           |
|  > YOU   - 1 bounty, survived, +212 $DATA                            |
|                                                                       |
|                    [ PLAY AGAIN ]    [ EXIT ]                         |
|                                                                       |
+======================================================================+
```

### Intel Acquisition Panel

```
ACQUIRE INTEL
+-------------------------------------------------------------+
|                                                             |
|  CURRENT INTEL: 7/12 clues                                  |
|  SUSPECTS REMAINING: 4 players                              |
|                                                             |
|  AVAILABLE INTEL PACKAGES:                                  |
|                                                             |
|  [ ] SKIP AHEAD (25 $DATA)                                  |
|      Reveal next scheduled clue immediately                 |
|      Next: Address suffix (last 2 chars)                    |
|                                                             |
|  [ ] ACTIVITY SCAN (25 $DATA)                               |
|      See target's last 3 actions (anonymized)               |
|      "Acquired intel", "Laid trail", "Idle"                 |
|                                                             |
|  [ ] SUSPECT FILTER (25 $DATA)                              |
|      Eliminate 50% of current suspects                      |
|      Narrows 4 suspects to 2                                |
|                                                             |
|  [ ] ONLINE STATUS (15 $DATA)                               |
|      Check if target is currently active                    |
|                                                             |
|  BALANCE: 125 $DATA                                         |
|                                                             |
|  [ PURCHASE SELECTED ]                      [ CANCEL ]      |
|                                                             |
+-------------------------------------------------------------+
```

### False Trail Panel

```
LAY FALSE TRAIL
+-------------------------------------------------------------+
|                                                             |
|  CURRENT COVER: 67% [######----]                            |
|  ACTIVE TRAILS: 1/4                                         |
|                                                             |
|  YOUR TRUE PROFILE:                                         |
|  > Entry: 250 $DATA                                         |
|  > Joined: 0:12 (first third)                               |
|  > Risk Level: SUBNET                                       |
|  > Address: 0x3b1a...f2e7                                   |
|                                                             |
|  AVAILABLE DECOYS (15 $DATA each):                          |
|                                                             |
|  [ ] BRACKET SPOOF                                          |
|      Appear as 100-200 $DATA instead of 200-300             |
|      Duration: 4 cycles                                     |
|                                                             |
|  [ ] TIMING GHOST                                           |
|      Appear as last third joiner                            |
|      Duration: 3 cycles                                     |
|                                                             |
|  [ ] RISK MASK                                              |
|      Appear as MAINFRAME level                              |
|      Duration: 4 cycles                                     |
|                                                             |
|  [ ] ADDRESS NOISE                                          |
|      Add 2 fake prefix/suffix matches                       |
|      Duration: 2 cycles                                     |
|                                                             |
|  [ DEPLOY SELECTED ]                        [ CANCEL ]      |
|                                                             |
+-------------------------------------------------------------+
```

---

## Economic Model

### Entry & Fees

| Parameter | Value |
|-----------|-------|
| Minimum Entry | 50 $DATA |
| Maximum Entry | 500 $DATA |
| Entry Burn | 100% (all entries go to prize pool) |
| Intel Cost | 15-25 $DATA (burned) |
| False Trail Cost | 15 $DATA (burned) |
| Minimum Players | 8 |
| Maximum Players | 64 |

### Prize Distribution

```javascript
// All entry stakes form the prize pool
const prizePool = entries.reduce((sum, e) => sum + e.stake, 0n);

// Successful bounty claim = target's stake + 20% bonus from pool
function claimBounty(hunter: address, target: address) {
  const targetStake = entries.get(target).stake;
  const bonus = (prizePool * 20n) / 100n / totalBounties;
  const payout = targetStake + bonus;
  return payout;
}

// Survivors split remaining pool
function survivorBonus(survivor: address) {
  const remainingPool = prizePool - totalPayouts;
  const survivorCount = survivors.length;
  
  // Double share if survivor also claimed a bounty
  const claimedBounty = bounties.has(survivor);
  const shares = claimedBounty ? 2 : 1;
  const totalShares = survivors.reduce((s, p) => 
    s + (bounties.has(p) ? 2 : 1), 0);
  
  return (remainingPool * BigInt(shares)) / BigInt(totalShares);
}
```

### Burn Mechanics

Every round burns significant $DATA:

```
EXAMPLE ROUND (47 players, avg stake 180 $DATA):

Entry Pool:           8,460 $DATA (100% at risk)
Intel Purchases:      ~1,200 $DATA (burned immediately)
False Trails:         ~700 $DATA (burned immediately)
                      ──────────────────
Total In Play:        10,360 $DATA

OUTCOMES:
Bounties Claimed:     28 (28 players eliminated)
Payouts to Hunters:   ~6,720 $DATA
Survivor Bonuses:     ~1,740 $DATA
                      ──────────────────
Total Payouts:        8,460 $DATA

BURNED THIS ROUND:    1,900 $DATA (intel + trails)
```

### Strategy vs Luck Balance

| Strategy Element | Impact |
|-----------------|--------|
| Entry Timing | Low - affects one early clue |
| Entry Amount | Medium - affects clue difficulty |
| Intel Acquisition | High - faster identification |
| False Trails | High - survival defense |
| Execution Timing | Critical - early = less intel, late = more risk |

---

## Technical Implementation

### Smart Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title BountyHunt
/// @notice Strategic deduction game where players hunt assigned targets
/// @dev Uses future block hash for fair target assignment (MegaETH-compatible)
contract BountyHunt is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Errors ============
    error InvalidStake();
    error RegistrationClosed();
    error AlreadyRegistered();
    error NotEnoughPlayers();
    error GameNotActive();
    error InvalidTarget();
    error AlreadyEliminated();
    error TooManyAttempts();
    error InsufficientBalance();
    error NotYourTarget();
    error GameNotEnded();
    error SeedBlockNotMined();
    error SeedBlockExpired();

    // ============ Types ============
    enum GameState { REGISTRATION, ASSIGNING, ACTIVE, ENDED }
    
    struct Player {
        uint256 stake;
        uint256 joinTime;
        uint256 intelPurchased;
        uint256 falseTrailsActive;
        uint256 wrongAttempts;
        bool eliminated;
        bool claimedBounty;
        bytes32 targetHash;  // Hash of target address (revealed progressively)
    }
    
    struct Game {
        uint256 gameId;
        GameState state;
        uint256 registrationEnd;
        uint256 gameEnd;
        uint256 currentCycle;
        uint256 prizePool;
        uint256 totalBountiesClaimed;
        uint256 seedBlock;        // Block number for randomness
        bytes32 seedHash;         // Captured block hash
        address[] players;
        mapping(address => Player) playerData;
        mapping(address => address) targets;      // hunter => target
        mapping(address => address) huntedBy;     // target => hunter
        mapping(address => bool) isPlayer;
    }

    // ============ Constants ============
    uint256 public constant MIN_STAKE = 50 ether;
    uint256 public constant MAX_STAKE = 500 ether;
    uint256 public constant MIN_PLAYERS = 8;
    uint256 public constant MAX_PLAYERS = 64;
    uint256 public constant REGISTRATION_DURATION = 60 seconds;
    uint256 public constant TOTAL_CYCLES = 12;
    uint256 public constant CYCLE_DURATION = 30 seconds;
    uint256 public constant INTEL_COST = 25 ether;
    uint256 public constant FALSE_TRAIL_COST = 15 ether;
    uint256 public constant BOUNTY_BONUS_BPS = 2000; // 20%
    uint256 public constant MAX_WRONG_ATTEMPTS = 3;
    uint256 public constant SEED_BLOCK_DELAY = 5;  // 5 blocks for randomness

    // ============ State ============
    IERC20 public immutable dataToken;
    uint256 public currentGameId;
    mapping(uint256 => Game) public games;

    // ============ Events ============
    event GameCreated(uint256 indexed gameId, uint256 registrationEnd);
    event PlayerRegistered(uint256 indexed gameId, address indexed player, uint256 stake);
    event SeedBlockCommitted(uint256 indexed gameId, uint256 seedBlock);
    event TargetsAssigned(uint256 indexed gameId, uint256 playerCount, bytes32 seedHash);
    event CycleAdvanced(uint256 indexed gameId, uint256 cycle);
    event IntelPurchased(uint256 indexed gameId, address indexed player, uint256 cost);
    event FalseTrailDeployed(uint256 indexed gameId, address indexed player);
    event BountyExecuted(uint256 indexed gameId, address indexed hunter, address indexed target, bool success);
    event PlayerEliminated(uint256 indexed gameId, address indexed player, address indexed hunter);
    event GameEnded(uint256 indexed gameId, uint256 totalBurned);
    event RewardClaimed(uint256 indexed gameId, address indexed player, uint256 amount);

    // ============ Constructor ============
    constructor(address _dataToken) {
        dataToken = IERC20(_dataToken);
    }

    // ============ Game Lifecycle ============
    
    /// @notice Create a new bounty hunt game
    function createGame() external returns (uint256 gameId) {
        gameId = ++currentGameId;
        Game storage game = games[gameId];
        game.gameId = gameId;
        game.state = GameState.REGISTRATION;
        game.registrationEnd = block.timestamp + REGISTRATION_DURATION;
        
        emit GameCreated(gameId, game.registrationEnd);
    }

    /// @notice Register for an active game
    /// @param gameId The game to join
    /// @param stake Amount of $DATA to stake (50-500)
    function register(uint256 gameId, uint256 stake) external nonReentrant {
        Game storage game = games[gameId];
        
        if (stake < MIN_STAKE || stake > MAX_STAKE) revert InvalidStake();
        if (block.timestamp > game.registrationEnd) revert RegistrationClosed();
        if (game.isPlayer[msg.sender]) revert AlreadyRegistered();
        if (game.players.length >= MAX_PLAYERS) revert RegistrationClosed();

        // Transfer stake to contract (burned to prize pool)
        dataToken.safeTransferFrom(msg.sender, address(this), stake);

        // Register player
        game.players.push(msg.sender);
        game.isPlayer[msg.sender] = true;
        game.playerData[msg.sender] = Player({
            stake: stake,
            joinTime: block.timestamp,
            intelPurchased: 0,
            falseTrailsActive: 0,
            wrongAttempts: 0,
            eliminated: false,
            claimedBounty: false,
            targetHash: bytes32(0)
        });
        game.prizePool += stake;

        emit PlayerRegistered(gameId, msg.sender, stake);
    }

    /// @notice Start target assignment after registration ends
    /// @dev Commits to a future block for randomness (MegaETH-compatible)
    /// @param gameId The game to start
    function startGame(uint256 gameId) external {
        Game storage game = games[gameId];
        
        if (block.timestamp < game.registrationEnd) revert RegistrationClosed();
        if (game.players.length < MIN_PLAYERS) revert NotEnoughPlayers();
        if (game.state != GameState.REGISTRATION) revert GameNotActive();

        game.state = GameState.ASSIGNING;
        
        // Commit to future block for randomness
        // MegaETH has 1-second EVM blocks, 5 blocks = 5 seconds
        game.seedBlock = block.number + SEED_BLOCK_DELAY;
        
        emit SeedBlockCommitted(gameId, game.seedBlock);
    }

    /// @notice Assign targets using committed block hash
    /// @dev Must be called after seedBlock is mined but within 256 blocks
    /// @param gameId The game to assign targets for
    function assignTargets(uint256 gameId) external {
        Game storage game = games[gameId];
        
        if (game.state != GameState.ASSIGNING) revert GameNotActive();
        if (block.number <= game.seedBlock) revert SeedBlockNotMined();
        
        // Capture block hash (available for last 256 blocks on MegaETH)
        bytes32 blockHash = blockhash(game.seedBlock);
        if (blockHash == bytes32(0)) revert SeedBlockExpired();
        
        game.seedHash = blockHash;
        
        // Create seed from block hash + game context
        uint256 seed = uint256(keccak256(abi.encode(
            blockHash,
            gameId,
            address(this),
            game.players.length
        )));
        
        // Fisher-Yates shuffle using seed
        address[] memory shuffled = game.players;
        uint256 n = shuffled.length;
        
        for (uint256 i = n - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encode(seed, i))) % (i + 1);
            (shuffled[i], shuffled[j]) = (shuffled[j], shuffled[i]);
        }
        
        // Assign circular chain: each player hunts the next
        for (uint256 i = 0; i < n; i++) {
            address hunter = shuffled[i];
            address target = shuffled[(i + 1) % n];
            
            game.targets[hunter] = target;
            game.huntedBy[target] = hunter;
            
            // Store encrypted target hash for progressive reveal
            game.playerData[hunter].targetHash = keccak256(abi.encode(target, seed, i));
        }
        
        game.state = GameState.ACTIVE;
        game.currentCycle = 1;
        game.gameEnd = block.timestamp + (TOTAL_CYCLES * CYCLE_DURATION);
        
        emit TargetsAssigned(gameId, n, blockHash);
    }

    // ============ Game Actions ============

    /// @notice Purchase additional intel about your target
    /// @param gameId The active game
    function purchaseIntel(uint256 gameId) external nonReentrant {
        Game storage game = games[gameId];
        Player storage player = game.playerData[msg.sender];
        
        if (game.state != GameState.ACTIVE) revert GameNotActive();
        if (player.eliminated) revert AlreadyEliminated();
        
        // Burn intel cost
        dataToken.safeTransferFrom(msg.sender, address(this), INTEL_COST);
        // Intel payment is burned (not added to prize pool)
        dataToken.safeTransfer(address(0xdead), INTEL_COST);
        
        player.intelPurchased++;
        
        emit IntelPurchased(gameId, msg.sender, INTEL_COST);
    }

    /// @notice Deploy a false trail to confuse hunters
    /// @param gameId The active game
    function deployFalseTrail(uint256 gameId) external nonReentrant {
        Game storage game = games[gameId];
        Player storage player = game.playerData[msg.sender];
        
        if (game.state != GameState.ACTIVE) revert GameNotActive();
        if (player.eliminated) revert AlreadyEliminated();
        if (player.falseTrailsActive >= 4) revert TooManyAttempts();
        
        // Burn trail cost
        dataToken.safeTransferFrom(msg.sender, address(this), FALSE_TRAIL_COST);
        dataToken.safeTransfer(address(0xdead), FALSE_TRAIL_COST);
        
        player.falseTrailsActive++;
        
        emit FalseTrailDeployed(gameId, msg.sender);
    }

    /// @notice Execute a bounty on a suspected target
    /// @param gameId The active game
    /// @param suspectedTarget The address you believe is your target
    function executeBounty(uint256 gameId, address suspectedTarget) external nonReentrant {
        Game storage game = games[gameId];
        Player storage hunter = game.playerData[msg.sender];
        
        if (game.state != GameState.ACTIVE) revert GameNotActive();
        if (hunter.eliminated) revert AlreadyEliminated();
        if (hunter.wrongAttempts >= MAX_WRONG_ATTEMPTS) revert TooManyAttempts();
        if (!game.isPlayer[suspectedTarget]) revert InvalidTarget();
        if (game.playerData[suspectedTarget].eliminated) revert AlreadyEliminated();

        address actualTarget = game.targets[msg.sender];
        bool success = (suspectedTarget == actualTarget);
        
        emit BountyExecuted(gameId, msg.sender, suspectedTarget, success);
        
        if (success) {
            // Eliminate target
            Player storage target = game.playerData[actualTarget];
            target.eliminated = true;
            hunter.claimedBounty = true;
            game.totalBountiesClaimed++;
            
            // Calculate payout: target stake + bonus
            uint256 bonus = (game.prizePool * BOUNTY_BONUS_BPS) / 10000 / game.players.length;
            uint256 payout = target.stake + bonus;
            
            dataToken.safeTransfer(msg.sender, payout);
            
            emit PlayerEliminated(gameId, actualTarget, msg.sender);
            emit RewardClaimed(gameId, msg.sender, payout);
        } else {
            // Wrong guess - reveal cover
            hunter.wrongAttempts++;
            
            // If 3 wrong attempts, hunter is eliminated
            if (hunter.wrongAttempts >= MAX_WRONG_ATTEMPTS) {
                hunter.eliminated = true;
                emit PlayerEliminated(gameId, msg.sender, address(0));
            }
        }
    }

    /// @notice End the game and distribute survivor rewards
    /// @param gameId The game to end
    function endGame(uint256 gameId) external nonReentrant {
        Game storage game = games[gameId];
        
        if (game.state != GameState.ACTIVE) revert GameNotActive();
        if (block.timestamp < game.gameEnd) revert GameNotEnded();
        
        game.state = GameState.ENDED;
        
        // Calculate survivors and distribute remaining pool
        uint256 totalShares = 0;
        uint256 survivorCount = 0;
        
        for (uint256 i = 0; i < game.players.length; i++) {
            Player storage p = game.playerData[game.players[i]];
            if (!p.eliminated) {
                survivorCount++;
                // Double share if they claimed a bounty
                totalShares += p.claimedBounty ? 2 : 1;
            }
        }
        
        if (survivorCount > 0 && totalShares > 0) {
            uint256 remainingPool = dataToken.balanceOf(address(this));
            
            for (uint256 i = 0; i < game.players.length; i++) {
                address playerAddr = game.players[i];
                Player storage p = game.playerData[playerAddr];
                
                if (!p.eliminated) {
                    uint256 shares = p.claimedBounty ? 2 : 1;
                    uint256 reward = (remainingPool * shares) / totalShares;
                    
                    if (reward > 0) {
                        dataToken.safeTransfer(playerAddr, reward);
                        emit RewardClaimed(gameId, playerAddr, reward);
                    }
                }
            }
        }
        
        // Any remaining dust is burned
        uint256 dust = dataToken.balanceOf(address(this));
        if (dust > 0) {
            dataToken.safeTransfer(address(0xdead), dust);
        }
        
        emit GameEnded(gameId, dust);
    }

    // ============ View Functions ============

    /// @notice Get current cycle based on timestamp
    function getCurrentCycle(uint256 gameId) public view returns (uint256) {
        Game storage game = games[gameId];
        if (game.state != GameState.ACTIVE) return 0;
        
        uint256 elapsed = block.timestamp - (game.gameEnd - TOTAL_CYCLES * CYCLE_DURATION);
        return (elapsed / CYCLE_DURATION) + 1;
    }

    /// @notice Get player's intel level (determines clue access)
    function getIntelLevel(uint256 gameId, address player) public view returns (uint256) {
        Game storage game = games[gameId];
        uint256 baseCycle = getCurrentCycle(gameId);
        uint256 purchased = game.playerData[player].intelPurchased;
        
        // Each purchased intel skips ahead one clue
        return baseCycle + purchased > TOTAL_CYCLES ? TOTAL_CYCLES : baseCycle + purchased;
    }

    /// @notice Check if an address matches intel criteria (for UI filtering)
    /// @dev This would be called off-chain to filter suspect list
    function getPlayerProfile(uint256 gameId, address player) external view returns (
        uint256 stake,
        uint256 joinTime,
        bool eliminated,
        uint256 falseTrailsActive
    ) {
        Player storage p = games[gameId].playerData[player];
        return (p.stake, p.joinTime, p.eliminated, p.falseTrailsActive);
    }

    /// @notice Get list of all players in a game
    function getPlayers(uint256 gameId) external view returns (address[] memory) {
        return games[gameId].players;
    }

    /// @notice Get survivor count for a game
    function getSurvivorCount(uint256 gameId) external view returns (uint256 count) {
        Game storage game = games[gameId];
        for (uint256 i = 0; i < game.players.length; i++) {
            if (!game.playerData[game.players[i]].eliminated) {
                count++;
            }
        }
    }
}
```

### Frontend Store

```typescript
// src/lib/features/arcade/bounty-hunt/store.svelte.ts

import { browser } from '$app/environment';

export type GameState = 'registration' | 'assigning' | 'active' | 'ended';

interface GameInfo {
  gameId: number;
  state: GameState;
  registrationEnd: number;
  gameEnd: number;
  currentCycle: number;
  totalCycles: number;
  prizePool: bigint;
  playerCount: number;
  survivorCount: number;
}

interface PlayerInfo {
  address: string;
  stake: bigint;
  joinTime: number;
  eliminated: boolean;
  claimedBounty: boolean;
  intelLevel: number;
  falseTrailsActive: number;
  wrongAttempts: number;
}

interface TargetIntel {
  stakeRange: [number, number] | null;
  joinTiming: 'first' | 'middle' | 'last' | null;
  riskLevel: string | null;
  gamesPlayed: number | null;
  hasAcquiredIntel: boolean | null;
  addressPrefix: string | null;
  exactStake: bigint | null;
  hasAttemptedExecution: boolean | null;
  hunterCount: number | null;
  addressSuffix: string | null;
  lastActionTime: number | null;
  fullAddress: string | null;
}

interface Suspect {
  address: string;
  matchScore: number;
  matchedClues: string[];
}

interface HunterThreat {
  estimatedCount: number;
  threatLevel: 'low' | 'medium' | 'high' | 'critical';
  coverIntegrity: number;
}

interface FeedEvent {
  type: 'intel_purchased' | 'trail_deployed' | 'bounty_executed' | 'player_eliminated' | 'cycle_advanced';
  timestamp: number;
  data: Record<string, unknown>;
}

export function createBountyHuntStore() {
  // ============ State ============
  let game = $state<GameInfo | null>(null);
  let player = $state<PlayerInfo | null>(null);
  let targetIntel = $state<TargetIntel>({
    stakeRange: null,
    joinTiming: null,
    riskLevel: null,
    gamesPlayed: null,
    hasAcquiredIntel: null,
    addressPrefix: null,
    exactStake: null,
    hasAttemptedExecution: null,
    hunterCount: null,
    addressSuffix: null,
    lastActionTime: null,
    fullAddress: null,
  });
  let suspects = $state<Suspect[]>([]);
  let hunterThreat = $state<HunterThreat>({
    estimatedCount: 1,
    threatLevel: 'low',
    coverIntegrity: 100,
  });
  let feed = $state<FeedEvent[]>([]);
  let balance = $state<bigint>(0n);
  let isConnected = $state(false);
  let cycleTimeRemaining = $state(30);

  // ============ Derived ============
  let canRegister = $derived(
    game?.state === 'registration' && 
    player === null &&
    balance >= 50n * 10n ** 18n
  );

  let canPurchaseIntel = $derived(
    game?.state === 'active' &&
    player !== null &&
    !player.eliminated &&
    balance >= 25n * 10n ** 18n
  );

  let canDeployTrail = $derived(
    game?.state === 'active' &&
    player !== null &&
    !player.eliminated &&
    player.falseTrailsActive < 4 &&
    balance >= 15n * 10n ** 18n
  );

  let canExecute = $derived(
    game?.state === 'active' &&
    player !== null &&
    !player.eliminated &&
    !player.claimedBounty &&
    player.wrongAttempts < 3 &&
    suspects.length > 0
  );

  let topSuspect = $derived(
    suspects.length > 0 
      ? suspects.reduce((a, b) => a.matchScore > b.matchScore ? a : b)
      : null
  );

  let intelProgress = $derived(
    player ? (player.intelLevel / 12) * 100 : 0
  );

  let isInDanger = $derived(
    hunterThreat.threatLevel === 'high' || 
    hunterThreat.threatLevel === 'critical'
  );

  // ============ Cycle Timer ============
  let cycleInterval: ReturnType<typeof setInterval> | null = null;

  function startCycleTimer() {
    if (!browser) return;
    
    cycleInterval = setInterval(() => {
      if (game?.state === 'active') {
        const cycleStart = game.gameEnd - (game.totalCycles - game.currentCycle + 1) * 30 * 1000;
        const elapsed = Date.now() - cycleStart;
        cycleTimeRemaining = Math.max(0, 30 - Math.floor(elapsed / 1000));
        
        if (cycleTimeRemaining === 0) {
          // Cycle advanced - will be updated via WebSocket
        }
      }
    }, 1000);
  }

  function stopCycleTimer() {
    if (cycleInterval) {
      clearInterval(cycleInterval);
      cycleInterval = null;
    }
  }

  // ============ Intel Calculation ============
  function calculateSuspects(players: PlayerInfo[], intel: TargetIntel): Suspect[] {
    return players
      .filter(p => !p.eliminated && p.address !== player?.address)
      .map(p => {
        const matchedClues: string[] = [];
        let score = 0;
        const totalClues = Object.values(intel).filter(v => v !== null).length;
        
        // Check each intel clue
        if (intel.stakeRange) {
          const [min, max] = intel.stakeRange;
          const stake = Number(p.stake / 10n ** 18n);
          if (stake >= min && stake <= max) {
            matchedClues.push('stake_range');
            score++;
          }
        }
        
        if (intel.joinTiming) {
          // Simplified - would need actual timing data
          matchedClues.push('join_timing');
          score++;
        }
        
        if (intel.addressPrefix && p.address.toLowerCase().startsWith(`0x${intel.addressPrefix.toLowerCase()}`)) {
          matchedClues.push('address_prefix');
          score += 2; // Higher weight for address clues
        }
        
        if (intel.addressSuffix && p.address.toLowerCase().endsWith(intel.addressSuffix.toLowerCase())) {
          matchedClues.push('address_suffix');
          score += 2;
        }
        
        if (intel.exactStake !== null && p.stake === intel.exactStake) {
          matchedClues.push('exact_stake');
          score += 3;
        }
        
        if (intel.fullAddress && p.address.toLowerCase() === intel.fullAddress.toLowerCase()) {
          matchedClues.push('full_address');
          score = 100; // Certain match
        }
        
        return {
          address: p.address,
          matchScore: totalClues > 0 ? Math.round((score / (totalClues * 1.5)) * 100) : 0,
          matchedClues,
        };
      })
      .filter(s => s.matchScore > 0)
      .sort((a, b) => b.matchScore - a.matchScore);
  }

  // ============ WebSocket Connection ============
  let ws: WebSocket | null = null;

  function connect(gameId: number) {
    if (!browser) return;

    ws = new WebSocket(`wss://api.ghostnet.io/bounty-hunt/${gameId}`);

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);

      switch (data.type) {
        case 'GAME_STATE':
          game = data.game;
          if (data.game.state === 'active') {
            startCycleTimer();
          }
          break;

        case 'PLAYER_STATE':
          player = data.player;
          break;

        case 'INTEL_UPDATE':
          targetIntel = { ...targetIntel, ...data.intel };
          if (data.allPlayers) {
            suspects = calculateSuspects(data.allPlayers, targetIntel);
          }
          break;

        case 'THREAT_UPDATE':
          hunterThreat = data.threat;
          break;

        case 'CYCLE_ADVANCED':
          if (game) {
            game = { ...game, currentCycle: data.cycle };
          }
          cycleTimeRemaining = 30;
          break;

        case 'BOUNTY_EXECUTED':
          feed = [{
            type: 'bounty_executed',
            timestamp: Date.now(),
            data: data,
          }, ...feed.slice(0, 49)];
          break;

        case 'PLAYER_ELIMINATED':
          feed = [{
            type: 'player_eliminated',
            timestamp: Date.now(),
            data: data,
          }, ...feed.slice(0, 49)];
          
          // Update suspects list
          suspects = suspects.filter(s => s.address !== data.player);
          break;

        case 'BALANCE_UPDATE':
          balance = BigInt(data.balance);
          break;

        case 'GAME_ENDED':
          game = { ...game!, state: 'ended' };
          stopCycleTimer();
          break;
      }
    };

    ws.onopen = () => {
      isConnected = true;
    };

    ws.onclose = () => {
      isConnected = false;
      stopCycleTimer();
    };

    return () => {
      ws?.close();
      stopCycleTimer();
    };
  }

  // ============ Actions ============
  async function register(stake: bigint) {
    if (!canRegister || !game) return;
    
    // Contract interaction via wagmi
    // await writeContract({ ... });
    
    ws?.send(JSON.stringify({
      type: 'REGISTER',
      stake: stake.toString(),
    }));
  }

  async function purchaseIntel() {
    if (!canPurchaseIntel || !game) return;
    
    ws?.send(JSON.stringify({
      type: 'PURCHASE_INTEL',
    }));
  }

  async function deployFalseTrail(trailType: 'bracket' | 'timing' | 'risk' | 'address') {
    if (!canDeployTrail || !game) return;
    
    ws?.send(JSON.stringify({
      type: 'DEPLOY_TRAIL',
      trailType,
    }));
  }

  async function executeBounty(targetAddress: string) {
    if (!canExecute || !game) return;
    
    ws?.send(JSON.stringify({
      type: 'EXECUTE_BOUNTY',
      target: targetAddress,
    }));
  }

  // ============ Return ============
  return {
    // State (readonly)
    get game() { return game; },
    get player() { return player; },
    get targetIntel() { return targetIntel; },
    get suspects() { return suspects; },
    get hunterThreat() { return hunterThreat; },
    get feed() { return feed; },
    get balance() { return balance; },
    get isConnected() { return isConnected; },
    get cycleTimeRemaining() { return cycleTimeRemaining; },

    // Derived (readonly)
    get canRegister() { return canRegister; },
    get canPurchaseIntel() { return canPurchaseIntel; },
    get canDeployTrail() { return canDeployTrail; },
    get canExecute() { return canExecute; },
    get topSuspect() { return topSuspect; },
    get intelProgress() { return intelProgress; },
    get isInDanger() { return isInDanger; },

    // Actions
    connect,
    register,
    purchaseIntel,
    deployFalseTrail,
    executeBounty,
  };
}

// Type export for context usage
export type BountyHuntStore = ReturnType<typeof createBountyHuntStore>;
```

---

## Visual Design

### Color Scheme

```css
.bounty-hunt {
  /* Base terminal colors */
  --bg-primary: #0a0a0a;
  --bg-secondary: #111111;
  --border: #00E5CC;
  --text-primary: #00E5CC;
  --text-dim: #006655;
  
  /* Intel states */
  --intel-locked: #333333;
  --intel-partial: #00E5CC;
  --intel-complete: #00FF00;
  
  /* Threat levels */
  --threat-low: #00E5CC;
  --threat-medium: #FFAA00;
  --threat-high: #FF6600;
  --threat-critical: #FF0000;
  
  /* Execution */
  --execute-ready: #00FF00;
  --execute-warning: #FFAA00;
  --execute-success: #00FF00;
  --execute-fail: #FF0000;
  
  /* Cover/false trails */
  --cover-full: #00E5CC;
  --cover-degraded: #FFAA00;
  --cover-compromised: #FF0000;
}
```

### Key Animations

**Target Assignment:**
- Matrix-style character rain revealing "TARGET ACQUIRED"
- Scrambled address characters that slowly resolve
- Pulsing border around target intel panel

**Intel Reveal:**
- Typewriter effect for new clue text
- Glitch effect on locked clues
- Suspect list filters with slide animation

**Bounty Execution:**
- Targeting reticle animation over suspect
- Screen flash (green for success, red for failure)
- Elimination shows target "flatline" effect

**Threat Warning:**
- Border color pulses at threat level intensity
- "DANGER" text flickers when cover is low
- Scanline intensity increases with threat

**Cycle Advance:**
- Brief screen static between cycles
- Progress bar fills with glow effect
- New clue reveals with decrypt animation

---

## Sound Design

| Event | Sound Description |
|-------|-------------------|
| Game Start | Low synth drone building |
| Target Assigned | Sharp digital "lock on" tone |
| Cycle Advance | Soft tick + new data beep |
| Intel Purchased | Data download chirp sequence |
| Clue Revealed | Decryption complete ping |
| False Trail Deployed | Static burst + confirmation tone |
| Execution Attempt | Heartbeat tension build |
| Successful Execution | Kill confirmed + cash register |
| Failed Execution | Error buzz + alarm |
| Being Hunted (warning) | Subtle radar ping (intensity varies) |
| Elimination (you) | Flatline + system shutdown |
| Elimination (other) | Distant gunshot + body thud |
| Survival | Victory fanfare + relief sigh |
| High Threat | Pulsing alarm undertone |

---

## Feed Integration

```
> 0x7a3f executed bounty on 0x9c2d [+275 $DATA]
> BOUNTY HUNT round #847 - 4 hunters remain
> 0x3b1a acquired intel - suspects narrowing
> 0x8f2e deployed false trail - cover restored
> !!! 0x1d4c eliminated after 3 wrong guesses !!!
> BOUNTY HUNT survivor 0x7a3f claims +212 $DATA bonus
> 0x9c2d got traced by 0x7a3f - rekt [-250 $DATA]
```

---

## Strategic Depth

### Decision Points

**Early Game (Cycles 1-4):**
- Spend $DATA on intel to narrow suspects early?
- Deploy false trails preemptively or save resources?
- Wait for more free clues or act on limited data?

**Mid Game (Cycles 5-8):**
- Execute now with moderate confidence or wait?
- How much to invest in defense vs offense?
- Watch feed for eliminated players to narrow suspects

**Late Game (Cycles 9-12):**
- High intel but also high threat - timing critical
- Other hunters may have identified you
- Balance between claiming bounty and surviving

### Meta Strategies

**Aggressive Hunter:**
- Max intel purchases early
- Execute ASAP with 70%+ confidence
- Accept risk of wrong guesses
- Ignores defense

**Defensive Ghost:**
- Minimal intel spending
- Max false trails
- Survives for bonus pool share
- Only executes if certain

**Balanced Predator:**
- Moderate intel investment
- 1-2 false trails for cover
- Executes at 85%+ confidence
- Adapts to threat level

**Information Trader:**
- Watches feed for patterns
- Uses others' eliminations to narrow suspects
- Waits for late-game certainty
- Low risk, moderate reward

---

## Testing Checklist

### Smart Contract
- [ ] Registration within stake bounds (50-500 $DATA)
- [ ] Registration only during registration phase
- [ ] Cannot register twice
- [ ] Future block hash properly shuffles and assigns circular chain (per ADR-001)
- [ ] Every player has exactly one target and one hunter
- [ ] Intel purchase burns tokens correctly
- [ ] False trail deployment limited to 4
- [ ] Correct execution identifies target
- [ ] Wrong execution increments attempts and reveals cover
- [ ] 3 wrong attempts eliminates player
- [ ] Successful execution eliminates target and pays reward
- [ ] Game ends after 12 cycles
- [ ] Survivor bonus calculates correctly (2x for bounty claimers)
- [ ] Remaining dust is burned
- [ ] Reentrancy protection on all public functions

### Frontend
- [ ] Registration UI shows correct stake range
- [ ] Countdown timer accurate for registration and cycles
- [ ] Target intel panel updates each cycle
- [ ] Suspect list filters correctly based on intel
- [ ] Match percentage calculates accurately
- [ ] False trail panel shows active trails
- [ ] Cover integrity updates with trails
- [ ] Threat level indicator responds to hunter activity
- [ ] Execution confirmation shows correct payout/risk
- [ ] Feed events display in real-time
- [ ] Eliminated state prevents further actions
- [ ] Results screen shows accurate breakdown

### Integration
- [ ] WebSocket connection stable for 6+ minute games
- [ ] Contract events sync with frontend state
- [ ] Multiple concurrent games don't interfere
- [ ] Wallet balance updates after transactions
- [ ] Gas estimates accurate for all transactions

### Edge Cases
- [ ] Minimum players (8) scenario
- [ ] Maximum players (64) scenario
- [ ] All players eliminated before game end
- [ ] Player disconnects mid-game
- [ ] Seed block delay handling (future block hash pattern)
- [ ] Tie-breaking for survivor bonus

---

## Future Enhancements

### Phase 3C Integration
- **Crew Bounties:** Target entire crews, split rewards
- **Revenge Mode:** Eliminated players can sabotage their hunter
- **Prestige Targets:** High-value NPCs with bigger stakes

### Seasonal Events
- **Double Agent:** Random chance to have 2 targets
- **Ghost Protocol:** Start with 50% cover already degraded
- **Blood Moon:** All intel revealed by cycle 6

### Leaderboards
- Highest single-game profit
- Most bounties claimed (career)
- Best survival rate
- Fastest executions (by cycle)
