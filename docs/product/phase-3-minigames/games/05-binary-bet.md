# BINARY BET

## Game Design Document

**Category:** Casino  
**Phase:** 3B (Skill Expansion)  
**Complexity:** Medium  
**Development Time:** 2 weeks  

---

## Overview

BINARY BET is a provably fair multiplayer coin flip game where players commit to betting on 0 or 1. A future block hash determines the winning bit. Multiple players can bet on the same round, and those who chose correctly split the pot. Uses commit-reveal to prevent front-running.

```
+======================================================================+
|                         BINARY BET                                    |
+======================================================================+
|                                                                       |
|                    ROUND #8,472 - COMMIT PHASE                        |
|                                                                       |
|                         ?                                             |
|                        / \                                            |
|                       /   \                                           |
|                      /     \                                          |
|                     0       1                                         |
|                   [BET]   [BET]                                       |
|                                                                       |
|  -------------------------------------------------------------        |
|                                                                       |
|  POOL: 4,250 $DATA         PLAYERS: 34                               |
|  SIDE 0: 18 bets           SIDE 1: 16 bets                           |
|                                                                       |
|  YOUR STATUS: COMMITTED                                               |
|                                                                       |
|  [ REVEAL BLOCK: #1,847,293 in 00:47 ]                               |
|                                                                       |
|  -------------------------------------------------------------        |
|  RECENT: 1 | 0 | 0 | 1 | 1 | 0 | 1 | 0 | 1 | 1                       |
|                                                                       |
+======================================================================+
```

---

## Core Mechanics

### Game Flow

```
1. COMMIT PHASE (60 seconds)
   +-- Players hash their choice (0 or 1) + secret
   +-- Submit commitment hash on-chain
   +-- Cannot see others' actual choices, only that they committed

2. LOCK PHASE (5 blocks ~5 seconds)
   +-- No more commits accepted
   +-- Waiting for reveal block to be mined
   +-- MegaETH has 1-second EVM blocks

3. REVEAL PHASE (45 seconds)
   +-- Players reveal their choice + secret
   +-- Contract verifies hash matches commitment
   +-- Unrevealed bets are forfeit

4. RESOLUTION PHASE
   +-- Block hash of reveal block is read
   +-- Least significant bit determines winner (0 or 1)
   +-- Winners split the pot proportionally
   +-- Burns applied, payouts distributed
```

### Commit-Reveal Pattern

Prevents front-running and ensures fairness:

```
COMMIT:
  commitment = keccak256(abi.encodePacked(choice, secret, sender))
  
  // Player submits: commitment + bet amount
  // Cannot determine choice from commitment alone

REVEAL:
  // Player submits: choice (0 or 1), secret
  // Contract verifies: keccak256(...) == stored commitment
  // If mismatch -> bet forfeit
```

### Winning Bit Calculation

```javascript
// Determine winning side from block hash
function getWinningBit(blockHash: bytes32): number {
  // Use least significant bit of block hash
  return uint256(blockHash) & 1;
}

// Alternative: Use bit at specific position for variety
function getWinningBitAtPosition(blockHash: bytes32, position: number): number {
  return (uint256(blockHash) >> position) & 1;
}
```

### Payout Calculation

```javascript
function calculatePayout(
  playerBet: bigint,
  playerSideTotal: bigint,
  loserSideTotal: bigint,
  burnRate: number = 0.05
): bigint {
  // Total pot after burn
  const totalPot = playerSideTotal + loserSideTotal;
  const burnAmount = totalPot * BigInt(Math.floor(burnRate * 10000)) / 10000n;
  const distributablePot = totalPot - burnAmount;
  
  // Player's share of distributable pot (proportional to their bet)
  const playerShare = (playerBet * distributablePot) / playerSideTotal;
  
  return playerShare;
}

// Example:
// Player bets 100 $DATA on side 0
// Side 0 total: 2,000 $DATA
// Side 1 total: 2,250 $DATA
// Total pot: 4,250 $DATA
// Burn (5%): 212.5 $DATA
// Distributable: 4,037.5 $DATA
// Player share: (100 / 2000) * 4037.5 = 201.875 $DATA
// Profit: 101.875 $DATA (~102% ROI)
```

---

## Advanced Features

### Streak Bonuses

Consecutive correct predictions earn bonus multipliers:

| Streak | Bonus |
|--------|-------|
| 3 wins | +5% payout |
| 5 wins | +10% payout |
| 7 wins | +15% payout |
| 10 wins | +25% payout + "ORACLE" badge |

### Bit Position Betting (Advanced Mode)

Instead of just 0/1, players can bet on specific bit positions (0-255):

```
ADVANCED MODE: BIT POSITION
----------------------------------------------
Select position in block hash (0-255):

Position 0 (LSB): Standard play
Position 7: "Lucky Seven"
Position 42: "The Answer"
Position 255 (MSB): "High Roller"

Higher positions = smaller pools = bigger swings
```

### Room System

Players can create private rooms with custom parameters:

```
CREATE ROOM
----------------------------------------------
Room Name: [________________]
Entry Fee: [100] $DATA
Min Players: [2]
Max Players: [50]
Visibility: [PUBLIC] [PRIVATE] [CREW ONLY]
Bit Position: [0 (Standard)]

[ CREATE ROOM ] - costs 50 $DATA
```

---

## User Interface

### States

**1. Lobby State**
```
+======================================================================+
|  BINARY BET                                   BALANCE: 1,247 $DATA    |
+======================================================================+
|                                                                       |
|                       ACTIVE ROOMS                                    |
|                                                                       |
|  # | ROOM            | POOL      | PLAYERS | PHASE    | TIME         |
|  --|-----------------|-----------|---------|----------|------        |
|  1 | Main Arena      | 4,250     | 34/100  | COMMIT   | 00:47        |
|  2 | High Stakes     | 12,800    | 8/20    | REVEAL   | 00:12        |
|  3 | Degen Den       | 890       | 12/50   | COMMIT   | 01:02        |
|  4 | Crew: PHANTOM   | 2,100     | 6/10    | LOCKED   | 00:08        |
|                                                                       |
|  ---------------------------------------------------------------      |
|                                                                       |
|  [ JOIN MAIN ARENA ]  [ CREATE ROOM ]  [ QUICK BET: 50 $DATA ]       |
|                                                                       |
|  ---------------------------------------------------------------      |
|  YOUR STATS:                                                          |
|  Wins: 47 | Losses: 39 | Win Rate: 54.7% | Current Streak: 3          |
|                                                                       |
+======================================================================+
```

**2. Commit Phase**
```
+======================================================================+
|  BINARY BET                           ROUND #8,472 - COMMIT PHASE     |
+======================================================================+
|                                                                       |
|                    MAKE YOUR PREDICTION                               |
|                                                                       |
|                         TIME LEFT: 00:47                              |
|                                                                       |
|      +-------------+                 +-------------+                  |
|      |             |                 |             |                  |
|      |     ███     |                 |      █      |                  |
|      |    █   █    |                 |     ██      |                  |
|      |    █   █    |                 |      █      |                  |
|      |    █   █    |                 |      █      |                  |
|      |     ███     |                 |     ███     |                  |
|      |             |                 |             |                  |
|      +-------------+                 +-------------+                  |
|         [ BET 0 ]                       [ BET 1 ]                     |
|                                                                       |
|  ---------------------------------------------------------------      |
|                                                                       |
|  BET AMOUNT: [    100    ] $DATA                                     |
|                                                                       |
|  QUICK BET: [10] [25] [50] [100] [250] [500] [MAX]                   |
|                                                                       |
|  ---------------------------------------------------------------      |
|  POOL: 4,250 $DATA    |    0: 52%    |    1: 48%                     |
|                                                                       |
+======================================================================+
```

**3. Committed - Waiting for Lock**
```
+======================================================================+
|  BINARY BET                           ROUND #8,472 - COMMIT PHASE     |
+======================================================================+
|                                                                       |
|                    COMMITMENT LOCKED                                  |
|                                                                       |
|                         TIME LEFT: 00:23                              |
|                                                                       |
|      +-------------+                 +-------------+                  |
|      |  SELECTED   |                 |             |                  |
|      |    >███<    |                 |      █      |                  |
|      |   >█   █<   |                 |     ██      |                  |
|      |   >█   █<   |                 |      █      |                  |
|      |   >█   █<   |                 |      █      |                  |
|      |    >███<    |                 |     ███     |                  |
|      |  [LOCKED]   |                 |             |                  |
|      +-------------+                 +-------------+                  |
|                                                                       |
|  ---------------------------------------------------------------      |
|                                                                       |
|  YOUR BET: 100 $DATA on [0]                                          |
|  COMMITMENT: 0x7a3f...8c2d                                           |
|  SECRET: 0x9b4e...1f3a (SAVE THIS!)                                  |
|                                                                       |
|  ---------------------------------------------------------------      |
|  WAITING FOR COMMIT PHASE TO END...                                  |
|                                                                       |
+======================================================================+
```

**4. Lock Phase**
```
+======================================================================+
|  BINARY BET                           ROUND #8,472 - LOCK PHASE       |
+======================================================================+
|                                                                       |
|                       BETS LOCKED                                     |
|                                                                       |
|                    WAITING FOR BLOCK #1,847,293                       |
|                                                                       |
|                         +---------+                                   |
|                         |  ???    |                                   |
|                         |   ???   |                                   |
|                         |  ???    |                                   |
|                         +---------+                                   |
|                                                                       |
|                    BLOCKS UNTIL REVEAL: 7                             |
|                                                                       |
|  ---------------------------------------------------------------      |
|                                                                       |
|  FINAL STATS:                                                         |
|  Total Pool: 5,840 $DATA                                             |
|  Side 0: 2,780 $DATA (47.6%) - 19 bets                               |
|  Side 1: 3,060 $DATA (52.4%) - 21 bets                               |
|  Burn: 292 $DATA                                                     |
|                                                                       |
|  YOUR POTENTIAL PAYOUT: 199 $DATA (+99%)                             |
|                                                                       |
+======================================================================+
```

**5. Reveal Phase**
```
+======================================================================+
|  BINARY BET                           ROUND #8,472 - REVEAL PHASE     |
+======================================================================+
|                                                                       |
|                    REVEAL YOUR BET                                    |
|                                                                       |
|                         TIME LEFT: 00:34                              |
|                                                                       |
|                    BLOCK HASH CAPTURED:                               |
|           0x7a3f8c2d...e4b19f (awaiting reveals)                     |
|                                                                       |
|  ---------------------------------------------------------------      |
|                                                                       |
|  YOUR COMMITMENT MUST BE REVEALED TO WIN!                            |
|                                                                       |
|                    [ REVEAL BET ]                                     |
|                                                                       |
|  ---------------------------------------------------------------      |
|  REVEALS: 31/40 complete                                             |
|  [ ████████████████████████████░░░░░░░░░░ ] 77.5%                    |
|                                                                       |
|  UNREVEALED BETS: 9 players (1,340 $DATA at risk)                    |
|                                                                       |
+======================================================================+
```

**6. Revealed - Waiting for Resolution**
```
+======================================================================+
|  BINARY BET                           ROUND #8,472 - REVEAL PHASE     |
+======================================================================+
|                                                                       |
|                    BET REVEALED                                       |
|                                                                       |
|                    WAITING FOR ALL REVEALS...                         |
|                         TIME LEFT: 00:12                              |
|                                                                       |
|  ---------------------------------------------------------------      |
|                                                                       |
|  YOUR BET: 100 $DATA on [0] - REVEALED                               |
|                                                                       |
|  BLOCK HASH: 0x7a3f8c2d9e1b4a5c6d7e8f0a1b2c3d4e5f6a7b8c9d0e1f2a3b   |
|                                                                       |
|  WINNING BIT: CALCULATING...                                         |
|                                                                       |
|  ---------------------------------------------------------------      |
|  REVEALS: 38/40 complete                                             |
|  [ ████████████████████████████████████░░ ] 95%                      |
|                                                                       |
+======================================================================+
```

**7. Resolution - Win**
```
+======================================================================+
|  BINARY BET                           ROUND #8,472 - RESOLVED         |
+======================================================================+
|                                                                       |
|                         WINNER: 0                                     |
|                                                                       |
|      +-------------+                 +-------------+                  |
|      |   WINNER!   |                 |   LOSER     |                  |
|      |    >███<    |                 |    ░█░      |                  |
|      |   >█   █<   |                 |   ░██░      |                  |
|      |   >█   █<   |                 |    ░█░      |                  |
|      |   >█   █<   |                 |    ░█░      |                  |
|      |    >███<    |                 |   ░███░    |                  |
|      |   [PAYOUT]  |                 |   [BUST]   |                  |
|      +-------------+                 +-------------+                  |
|                                                                       |
|  ---------------------------------------------------------------      |
|                                                                       |
|  BLOCK HASH: 0x7a3f...8c2d                                           |
|  LEAST SIGNIFICANT BIT: 0                                            |
|                                                                       |
|  ---------------------------------------------------------------      |
|                                                                       |
|  YOUR RESULT: +106 $DATA                                             |
|  (Bet: 100 | Payout: 206 | Profit: 106)                              |
|                                                                       |
|  STREAK: 4 WINS (+5% BONUS ACTIVE!)                                   |
|                                                                       |
|  ---------------------------------------------------------------      |
|  [ PLAY AGAIN ]  [ DOUBLE DOWN ]  [ LOBBY ]                          |
|                                                                       |
+======================================================================+
```

**8. Resolution - Loss**
```
+======================================================================+
|  BINARY BET                           ROUND #8,472 - RESOLVED         |
+======================================================================+
|                                                                       |
|                         WINNER: 1                                     |
|                                                                       |
|      +-------------+                 +-------------+                  |
|      |   LOSER     |                 |   WINNER!   |                  |
|      |    ░███░    |                 |    >█<      |                  |
|      |   ░█   █░   |                 |   >██<      |                  |
|      |   ░█   █░   |                 |    >█<      |                  |
|      |   ░█   █░   |                 |    >█<      |                  |
|      |    ░███░    |                 |   >███<     |                  |
|      |   [BUST]    |                 |   [PAYOUT]  |                  |
|      +-------------+                 +-------------+                  |
|                                                                       |
|  ---------------------------------------------------------------      |
|                                                                       |
|  BLOCK HASH: 0x7a3f...8c2d                                           |
|  LEAST SIGNIFICANT BIT: 1                                            |
|                                                                       |
|  ---------------------------------------------------------------      |
|                                                                       |
|  YOUR RESULT: -100 $DATA                                             |
|  TRACED. Better luck next time, runner.                              |
|                                                                       |
|  STREAK RESET: 0 WINS                                                 |
|                                                                       |
|  ---------------------------------------------------------------      |
|  [ TRY AGAIN ]  [ REVENGE BET ]  [ LOBBY ]                           |
|                                                                       |
+======================================================================+
```

**9. Forfeit (Failed to Reveal)**
```
+======================================================================+
|  BINARY BET                           ROUND #8,472 - RESOLVED         |
+======================================================================+
|                                                                       |
|                       REVEAL FAILED                                   |
|                                                                       |
|                    !! BET FORFEITED !!                                |
|                                                                       |
|                    You did not reveal in time.                        |
|                    Your bet has been burned.                          |
|                                                                       |
|  ---------------------------------------------------------------      |
|                                                                       |
|  LOST: 100 $DATA (BURNED)                                            |
|                                                                       |
|  NOTE: Always reveal your bet before the reveal phase ends!          |
|        Enable AUTO-REVEAL in settings to prevent this.               |
|                                                                       |
|  ---------------------------------------------------------------      |
|  [ SETTINGS ]  [ LOBBY ]                                             |
|                                                                       |
+======================================================================+
```

### Live Players Panel

```
LIVE BETS - ROUND #8,472
-----------------------------------------
  ADDRESS     AMOUNT    STATUS    SIDE
-----------------------------------------
> 0x7a3f     100       COMMITTED   ?
  0x9c2d     500       COMMITTED   ?
  0x3b1a      50       COMMITTED   ?
  0x8f2e     200       COMMITTED   ?
  0x1d4c    1000       COMMITTED   ?
  0x4e7b     250       COMMITTED   ?
  ...
-----------------------------------------
TOTAL: 34 players | 4,250 $DATA
```

---

## Economic Model

### Entry & Fees

| Parameter | Value |
|-----------|-------|
| Minimum Bet | 10 $DATA |
| Maximum Bet | 500 $DATA |
| Burn Rate | 5% of total pot |
| Room Creation Fee | 50 $DATA (burned) |

### Expected Value Analysis

```
For a balanced 50/50 pool:
- Win probability: 50%
- Win payout: ~1.9x (after 5% burn)
- Expected value: 0.5 * 1.9 + 0.5 * 0 = 0.95
- House edge: 5%

For an imbalanced pool (30/70 split):
- Betting on minority side:
  - Win probability: 50%
  - Win payout: ~2.22x
  - Higher risk, higher reward

- Betting on majority side:
  - Win probability: 50%
  - Win payout: ~1.36x
  - Lower risk, lower reward
```

### Burn Distribution

```
ROUND ECONOMICS
===========================================
Total Pot: 5,840 $DATA

5% BURN: 292 $DATA
   +-- 292 $DATA -> Burned forever

DISTRIBUTABLE: 5,548 $DATA
   +-- All to winning side

If Side 0 wins (2,780 $DATA staked):
   +-- Each $DATA on 0 receives: 5,548/2,780 = 1.996 $DATA
   +-- ROI: +99.6%

If Side 1 wins (3,060 $DATA staked):
   +-- Each $DATA on 1 receives: 5,548/3,060 = 1.813 $DATA
   +-- ROI: +81.3%
```

### Streak Bonus Economics

Streak bonuses come from an additional 2% bonus pool:

```
Base burn: 5%
Streak pool: 2% (taken from winners' pot)

Streak bonus is multiplicative:
- 3-win streak: (payout * 1.05)
- 5-win streak: (payout * 1.10)
- 10-win streak: (payout * 1.25)

Max additional cost: 25% of 2% = 0.5% of pot
```

---

## Technical Implementation

### Smart Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title BinaryBet
/// @notice Provably fair coin flip game using block hash as randomness source
/// @dev Uses commit-reveal pattern to prevent front-running
contract BinaryBet is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════
    // TYPES
    // ══════════════════════════════════════════════════════════════════

    enum RoundPhase {
        COMMIT,     // Players submit commitments
        LOCKED,     // Waiting for reveal block
        REVEAL,     // Players reveal their bets
        RESOLVED    // Winner determined, payouts available
    }

    struct Round {
        uint256 roundId;
        RoundPhase phase;
        uint256 commitDeadline;
        uint256 revealBlock;
        uint256 revealDeadline;
        bytes32 blockHash;
        uint8 winningBit;
        uint256 totalSide0;
        uint256 totalSide1;
        uint256 burnAmount;
        uint256 playerCount;
        bool resolved;
    }

    struct Commitment {
        bytes32 commitHash;
        uint256 amount;
        uint8 revealedChoice;   // 0 or 1 after reveal; 255 = not revealed
        bool revealed;
        bool claimed;
    }

    struct PlayerStats {
        uint256 wins;
        uint256 losses;
        uint256 currentStreak;
        uint256 maxStreak;
        uint256 totalWagered;
        uint256 totalWon;
    }

    // ══════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════

    uint256 public constant MIN_BET = 10 ether;        // 10 $DATA
    uint256 public constant MAX_BET = 500 ether;       // 500 $DATA
    uint256 public constant BURN_RATE_BPS = 500;       // 5%
    uint256 public constant STREAK_POOL_BPS = 200;     // 2%
    uint256 public constant COMMIT_DURATION = 60;      // 60 seconds
    uint256 public constant LOCK_BLOCKS = 5;           // 5 seconds (MegaETH: 1s blocks)
    uint256 public constant REVEAL_DURATION = 45;      // 45 seconds
    uint256 public constant BPS_DENOMINATOR = 10000;

    // Streak thresholds and bonuses (in BPS)
    uint256 public constant STREAK_3_BONUS = 500;      // +5%
    uint256 public constant STREAK_5_BONUS = 1000;     // +10%
    uint256 public constant STREAK_7_BONUS = 1500;     // +15%
    uint256 public constant STREAK_10_BONUS = 2500;    // +25%

    // ══════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════

    IERC20 public immutable dataToken;
    
    uint256 public currentRoundId;
    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(address => Commitment)) public commitments;
    mapping(address => PlayerStats) public playerStats;

    // ══════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════

    error InvalidPhase();
    error InvalidAmount();
    error AlreadyCommitted();
    error CommitmentNotFound();
    error InvalidReveal();
    error AlreadyRevealed();
    error AlreadyClaimed();
    error RoundNotResolved();
    error NotWinner();
    error BlockHashNotAvailable();
    error RevealTooEarly();

    // ══════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════

    event RoundStarted(uint256 indexed roundId, uint256 commitDeadline, uint256 revealBlock);
    event BetCommitted(uint256 indexed roundId, address indexed player, bytes32 commitHash, uint256 amount);
    event BetRevealed(uint256 indexed roundId, address indexed player, uint8 choice);
    event RoundResolved(uint256 indexed roundId, uint8 winningBit, bytes32 blockHash, uint256 burnAmount);
    event WinningsClaimed(uint256 indexed roundId, address indexed player, uint256 payout, uint256 streakBonus);
    event BetForfeited(uint256 indexed roundId, address indexed player, uint256 amount);

    // ══════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════

    constructor(address _dataToken, address _owner) Ownable(_owner) {
        dataToken = IERC20(_dataToken);
    }

    // ══════════════════════════════════════════════════════════════════
    // EXTERNAL FUNCTIONS
    // ══════════════════════════════════════════════════════════════════

    /// @notice Start a new round (callable by anyone if previous round is resolved)
    function startRound() external {
        if (currentRoundId > 0) {
            Round storage prevRound = rounds[currentRoundId];
            if (!prevRound.resolved) revert InvalidPhase();
        }

        currentRoundId++;
        
        uint256 commitDeadline = block.timestamp + COMMIT_DURATION;
        uint256 revealBlock = block.number + LOCK_BLOCKS + 
            (COMMIT_DURATION / 2); // Approximate blocks during commit

        rounds[currentRoundId] = Round({
            roundId: currentRoundId,
            phase: RoundPhase.COMMIT,
            commitDeadline: commitDeadline,
            revealBlock: revealBlock,
            revealDeadline: 0, // Set when reveal phase starts
            blockHash: bytes32(0),
            winningBit: 255, // Invalid until resolved
            totalSide0: 0,
            totalSide1: 0,
            burnAmount: 0,
            playerCount: 0,
            resolved: false
        });

        emit RoundStarted(currentRoundId, commitDeadline, revealBlock);
    }

    /// @notice Commit a bet for the current round
    /// @param commitHash keccak256(abi.encodePacked(choice, secret, msg.sender))
    /// @param amount Amount to bet
    function commitBet(bytes32 commitHash, uint256 amount) external nonReentrant {
        Round storage round = rounds[currentRoundId];
        
        if (round.phase != RoundPhase.COMMIT) revert InvalidPhase();
        if (block.timestamp > round.commitDeadline) revert InvalidPhase();
        if (amount < MIN_BET || amount > MAX_BET) revert InvalidAmount();
        if (commitments[currentRoundId][msg.sender].amount > 0) revert AlreadyCommitted();

        dataToken.safeTransferFrom(msg.sender, address(this), amount);

        commitments[currentRoundId][msg.sender] = Commitment({
            commitHash: commitHash,
            amount: amount,
            revealedChoice: 255, // Not revealed yet
            revealed: false,
            claimed: false
        });

        round.playerCount++;
        playerStats[msg.sender].totalWagered += amount;

        emit BetCommitted(currentRoundId, msg.sender, commitHash, amount);
    }

    /// @notice Transition round to locked phase (callable by anyone)
    function lockRound() external {
        Round storage round = rounds[currentRoundId];
        
        if (round.phase != RoundPhase.COMMIT) revert InvalidPhase();
        if (block.timestamp <= round.commitDeadline) revert InvalidPhase();

        round.phase = RoundPhase.LOCKED;
    }

    /// @notice Capture block hash and start reveal phase (callable by anyone)
    function startRevealPhase() external {
        Round storage round = rounds[currentRoundId];
        
        if (round.phase != RoundPhase.LOCKED) revert InvalidPhase();
        if (block.number <= round.revealBlock) revert RevealTooEarly();

        bytes32 capturedHash = blockhash(round.revealBlock);
        if (capturedHash == bytes32(0)) revert BlockHashNotAvailable();

        round.blockHash = capturedHash;
        round.phase = RoundPhase.REVEAL;
        round.revealDeadline = block.timestamp + REVEAL_DURATION;

        // Determine winning bit (LSB of block hash)
        round.winningBit = uint8(uint256(capturedHash) & 1);
    }

    /// @notice Reveal your bet choice
    /// @param choice Your original choice (0 or 1)
    /// @param secret Your original secret
    function revealBet(uint8 choice, bytes32 secret) external nonReentrant {
        Round storage round = rounds[currentRoundId];
        Commitment storage commitment = commitments[currentRoundId][msg.sender];

        if (round.phase != RoundPhase.REVEAL) revert InvalidPhase();
        if (block.timestamp > round.revealDeadline) revert InvalidPhase();
        if (commitment.amount == 0) revert CommitmentNotFound();
        if (commitment.revealed) revert AlreadyRevealed();
        if (choice > 1) revert InvalidReveal();

        // Verify commitment
        bytes32 expectedHash = keccak256(abi.encodePacked(choice, secret, msg.sender));
        if (expectedHash != commitment.commitHash) revert InvalidReveal();

        commitment.revealed = true;
        commitment.revealedChoice = choice;

        if (choice == 0) {
            round.totalSide0 += commitment.amount;
        } else {
            round.totalSide1 += commitment.amount;
        }

        emit BetRevealed(currentRoundId, msg.sender, choice);
    }

    /// @notice Resolve the round after reveal phase ends
    function resolveRound() external {
        Round storage round = rounds[currentRoundId];

        if (round.phase != RoundPhase.REVEAL) revert InvalidPhase();
        if (block.timestamp <= round.revealDeadline) revert InvalidPhase();

        uint256 totalPot = round.totalSide0 + round.totalSide1;
        round.burnAmount = (totalPot * BURN_RATE_BPS) / BPS_DENOMINATOR;
        
        // Burn tokens
        if (round.burnAmount > 0) {
            dataToken.safeTransfer(address(0xdead), round.burnAmount);
        }

        round.phase = RoundPhase.RESOLVED;
        round.resolved = true;

        emit RoundResolved(currentRoundId, round.winningBit, round.blockHash, round.burnAmount);
    }

    /// @notice Claim winnings for a resolved round
    /// @param roundId The round to claim from
    function claimWinnings(uint256 roundId) external nonReentrant {
        Round storage round = rounds[roundId];
        Commitment storage commitment = commitments[roundId][msg.sender];

        if (!round.resolved) revert RoundNotResolved();
        if (!commitment.revealed) revert CommitmentNotFound();
        if (commitment.claimed) revert AlreadyClaimed();
        if (commitment.revealedChoice != round.winningBit) revert NotWinner();

        commitment.claimed = true;

        // Calculate payout
        uint256 totalPot = round.totalSide0 + round.totalSide1;
        uint256 distributablePot = totalPot - round.burnAmount;
        uint256 winningSideTotal = round.winningBit == 0 ? round.totalSide0 : round.totalSide1;
        
        uint256 basePayout = (commitment.amount * distributablePot) / winningSideTotal;

        // Apply streak bonus
        PlayerStats storage stats = playerStats[msg.sender];
        stats.wins++;
        stats.currentStreak++;
        if (stats.currentStreak > stats.maxStreak) {
            stats.maxStreak = stats.currentStreak;
        }

        uint256 streakBonus = _calculateStreakBonus(basePayout, stats.currentStreak);
        uint256 totalPayout = basePayout + streakBonus;

        stats.totalWon += totalPayout;
        dataToken.safeTransfer(msg.sender, totalPayout);

        emit WinningsClaimed(roundId, msg.sender, totalPayout, streakBonus);
    }

    /// @notice Handle unrevealed bets (forfeit)
    /// @param roundId The round to process
    /// @param player The player who didn't reveal
    function forfeitUnrevealed(uint256 roundId, address player) external {
        Round storage round = rounds[roundId];
        Commitment storage commitment = commitments[roundId][player];

        if (!round.resolved) revert RoundNotResolved();
        if (commitment.amount == 0) revert CommitmentNotFound();
        if (commitment.revealed) revert AlreadyRevealed();
        if (commitment.claimed) revert AlreadyClaimed();

        commitment.claimed = true; // Mark as processed

        // Update player stats
        PlayerStats storage stats = playerStats[player];
        stats.losses++;
        stats.currentStreak = 0;

        // Burn forfeited amount
        dataToken.safeTransfer(address(0xdead), commitment.amount);

        emit BetForfeited(roundId, player, commitment.amount);
    }

    // ══════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════

    /// @notice Generate commitment hash for a bet
    /// @param choice 0 or 1
    /// @param secret Random bytes32 secret
    /// @param player The player address
    function generateCommitment(
        uint8 choice,
        bytes32 secret,
        address player
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(choice, secret, player));
    }

    /// @notice Get current round info
    function getCurrentRound() external view returns (Round memory) {
        return rounds[currentRoundId];
    }

    /// @notice Get player's commitment for a round
    function getCommitment(
        uint256 roundId,
        address player
    ) external view returns (Commitment memory) {
        return commitments[roundId][player];
    }

    /// @notice Calculate potential payout for a bet
    function calculatePotentialPayout(
        uint256 amount,
        uint8 side,
        uint256 roundId
    ) external view returns (uint256) {
        Round storage round = rounds[roundId];
        
        uint256 totalPot = round.totalSide0 + round.totalSide1 + amount;
        uint256 burnAmount = (totalPot * BURN_RATE_BPS) / BPS_DENOMINATOR;
        uint256 distributablePot = totalPot - burnAmount;
        
        uint256 sideTotal = side == 0 
            ? round.totalSide0 + amount 
            : round.totalSide1 + amount;
        
        return (amount * distributablePot) / sideTotal;
    }

    // ══════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ══════════════════════════════════════════════════════════════════

    function _calculateStreakBonus(
        uint256 basePayout,
        uint256 streak
    ) internal pure returns (uint256) {
        uint256 bonusBps;
        
        if (streak >= 10) {
            bonusBps = STREAK_10_BONUS;
        } else if (streak >= 7) {
            bonusBps = STREAK_7_BONUS;
        } else if (streak >= 5) {
            bonusBps = STREAK_5_BONUS;
        } else if (streak >= 3) {
            bonusBps = STREAK_3_BONUS;
        } else {
            return 0;
        }

        return (basePayout * bonusBps) / BPS_DENOMINATOR;
    }
}
```

### Frontend Store

```typescript
// src/lib/features/arcade/binary-bet/store.svelte.ts

import { browser } from '$app/environment';

export type RoundPhase = 'commit' | 'locked' | 'reveal' | 'resolved';
export type BetChoice = 0 | 1;

interface Round {
  roundId: number;
  phase: RoundPhase;
  commitDeadline: number;
  revealBlock: number;
  revealDeadline: number;
  blockHash: string | null;
  winningBit: BetChoice | null;
  totalSide0: bigint;
  totalSide1: bigint;
  burnAmount: bigint;
  playerCount: number;
}

interface PlayerCommitment {
  commitHash: string;
  amount: bigint;
  choice: BetChoice;
  secret: string;
  revealed: boolean;
  claimed: boolean;
}

interface PlayerStats {
  wins: number;
  losses: number;
  currentStreak: number;
  maxStreak: number;
  totalWagered: bigint;
  totalWon: bigint;
}

interface RecentResult {
  roundId: number;
  winningBit: BetChoice;
  timestamp: number;
}

export function createBinaryBetStore() {
  // ══════════════════════════════════════════════════════════════════
  // STATE
  // ══════════════════════════════════════════════════════════════════

  let round = $state<Round | null>(null);
  let commitment = $state<PlayerCommitment | null>(null);
  let playerStats = $state<PlayerStats>({
    wins: 0,
    losses: 0,
    currentStreak: 0,
    maxStreak: 0,
    totalWagered: 0n,
    totalWon: 0n
  });
  let recentResults = $state<RecentResult[]>([]);
  let timeRemaining = $state(0);
  let blocksRemaining = $state(0);
  let isConnected = $state(false);
  let isLoading = $state(false);
  let error = $state<string | null>(null);

  // ══════════════════════════════════════════════════════════════════
  // DERIVED
  // ══════════════════════════════════════════════════════════════════

  let canCommit = $derived(
    round?.phase === 'commit' &&
    commitment === null &&
    timeRemaining > 0
  );

  let canReveal = $derived(
    round?.phase === 'reveal' &&
    commitment !== null &&
    !commitment.revealed &&
    timeRemaining > 0
  );

  let mustReveal = $derived(
    round?.phase === 'reveal' &&
    commitment !== null &&
    !commitment.revealed
  );

  let totalPool = $derived(
    round ? round.totalSide0 + round.totalSide1 : 0n
  );

  let side0Percentage = $derived(
    totalPool > 0n
      ? Number((round!.totalSide0 * 10000n) / totalPool) / 100
      : 50
  );

  let side1Percentage = $derived(
    totalPool > 0n
      ? Number((round!.totalSide1 * 10000n) / totalPool) / 100
      : 50
  );

  let potentialPayout = $derived(() => {
    if (!round || !commitment) return 0n;
    
    const pot = round.totalSide0 + round.totalSide1;
    const burnAmount = (pot * 500n) / 10000n; // 5%
    const distributablePot = pot - burnAmount;
    
    const sideTotal = commitment.choice === 0 
      ? round.totalSide0 
      : round.totalSide1;
    
    if (sideTotal === 0n) return distributablePot;
    
    return (commitment.amount * distributablePot) / sideTotal;
  });

  let streakBonusPercent = $derived(() => {
    const streak = playerStats.currentStreak;
    if (streak >= 10) return 25;
    if (streak >= 7) return 15;
    if (streak >= 5) return 10;
    if (streak >= 3) return 5;
    return 0;
  });

  let winRate = $derived(() => {
    const total = playerStats.wins + playerStats.losses;
    if (total === 0) return 0;
    return (playerStats.wins / total) * 100;
  });

  let isWinner = $derived(
    round?.phase === 'resolved' &&
    commitment?.revealed &&
    commitment?.choice === round?.winningBit
  );

  // ══════════════════════════════════════════════════════════════════
  // TIMERS
  // ══════════════════════════════════════════════════════════════════

  let timerInterval: ReturnType<typeof setInterval> | null = null;

  function startTimer() {
    if (!browser) return;
    stopTimer();

    timerInterval = setInterval(() => {
      if (!round) return;

      const now = Date.now();

      if (round.phase === 'commit') {
        timeRemaining = Math.max(0, Math.floor((round.commitDeadline - now) / 1000));
      } else if (round.phase === 'reveal' && round.revealDeadline) {
        timeRemaining = Math.max(0, Math.floor((round.revealDeadline - now) / 1000));
      } else {
        timeRemaining = 0;
      }
    }, 100);
  }

  function stopTimer() {
    if (timerInterval) {
      clearInterval(timerInterval);
      timerInterval = null;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // WEBSOCKET CONNECTION
  // ══════════════════════════════════════════════════════════════════

  let ws: WebSocket | null = null;

  function connect() {
    if (!browser) return;

    ws = new WebSocket('wss://api.ghostnet.io/binary-bet');

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);

      switch (data.type) {
        case 'ROUND_STATE':
          round = {
            ...data.round,
            totalSide0: BigInt(data.round.totalSide0),
            totalSide1: BigInt(data.round.totalSide1),
            burnAmount: BigInt(data.round.burnAmount)
          };
          startTimer();
          break;

        case 'PHASE_CHANGE':
          if (round) {
            round = { ...round, phase: data.phase };
            if (data.revealDeadline) {
              round.revealDeadline = data.revealDeadline;
            }
            if (data.blockHash) {
              round.blockHash = data.blockHash;
            }
          }
          break;

        case 'BET_COMMITTED':
          if (round) {
            round = {
              ...round,
              playerCount: round.playerCount + 1
            };
          }
          break;

        case 'BET_REVEALED':
          if (round) {
            if (data.choice === 0) {
              round = { ...round, totalSide0: round.totalSide0 + BigInt(data.amount) };
            } else {
              round = { ...round, totalSide1: round.totalSide1 + BigInt(data.amount) };
            }
          }
          break;

        case 'ROUND_RESOLVED':
          if (round) {
            round = {
              ...round,
              phase: 'resolved',
              winningBit: data.winningBit,
              blockHash: data.blockHash,
              burnAmount: BigInt(data.burnAmount)
            };
            recentResults = [
              { roundId: round.roundId, winningBit: data.winningBit, timestamp: Date.now() },
              ...recentResults.slice(0, 9)
            ];
          }
          stopTimer();
          break;

        case 'COMMIT_CONFIRMED':
          commitment = {
            commitHash: data.commitHash,
            amount: BigInt(data.amount),
            choice: data.choice,
            secret: data.secret,
            revealed: false,
            claimed: false
          };
          // Store secret locally for reveal
          if (browser) {
            localStorage.setItem(
              `binary-bet-secret-${round?.roundId}`,
              JSON.stringify({ choice: data.choice, secret: data.secret })
            );
          }
          break;

        case 'REVEAL_CONFIRMED':
          if (commitment) {
            commitment = { ...commitment, revealed: true };
          }
          break;

        case 'CLAIM_CONFIRMED':
          if (commitment) {
            commitment = { ...commitment, claimed: true };
          }
          playerStats = {
            ...playerStats,
            wins: playerStats.wins + 1,
            currentStreak: playerStats.currentStreak + 1,
            maxStreak: Math.max(playerStats.maxStreak, playerStats.currentStreak + 1),
            totalWon: playerStats.totalWon + BigInt(data.payout)
          };
          break;

        case 'PLAYER_STATS':
          playerStats = {
            ...data.stats,
            totalWagered: BigInt(data.stats.totalWagered),
            totalWon: BigInt(data.stats.totalWon)
          };
          break;

        case 'BLOCKS_UPDATE':
          blocksRemaining = data.blocksRemaining;
          break;

        case 'ERROR':
          error = data.message;
          break;
      }
    };

    ws.onopen = () => {
      isConnected = true;
      error = null;
    };

    ws.onclose = () => {
      isConnected = false;
      stopTimer();
    };

    ws.onerror = () => {
      error = 'Connection error';
    };

    return () => {
      ws?.close();
      stopTimer();
    };
  }

  // ══════════════════════════════════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════════════════════════════════

  function generateSecret(): string {
    if (!browser) return '';
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    return '0x' + Array.from(array).map(b => b.toString(16).padStart(2, '0')).join('');
  }

  async function commitBet(choice: BetChoice, amount: bigint) {
    if (!canCommit) {
      error = 'Cannot commit bet at this time';
      return;
    }

    isLoading = true;
    error = null;

    try {
      const secret = generateSecret();
      
      // In production, this would call the smart contract
      // For now, send via WebSocket for the backend to process
      ws?.send(JSON.stringify({
        type: 'COMMIT_BET',
        choice,
        amount: amount.toString(),
        secret
      }));
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to commit bet';
    } finally {
      isLoading = false;
    }
  }

  async function revealBet() {
    if (!canReveal || !commitment) {
      error = 'Cannot reveal bet at this time';
      return;
    }

    isLoading = true;
    error = null;

    try {
      // Retrieve stored secret
      const stored = browser
        ? localStorage.getItem(`binary-bet-secret-${round?.roundId}`)
        : null;

      if (!stored) {
        error = 'Secret not found - bet may be forfeited';
        return;
      }

      const { choice, secret } = JSON.parse(stored);

      ws?.send(JSON.stringify({
        type: 'REVEAL_BET',
        choice,
        secret
      }));
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to reveal bet';
    } finally {
      isLoading = false;
    }
  }

  async function claimWinnings() {
    if (!isWinner || commitment?.claimed) {
      error = 'Nothing to claim';
      return;
    }

    isLoading = true;
    error = null;

    try {
      ws?.send(JSON.stringify({
        type: 'CLAIM_WINNINGS',
        roundId: round?.roundId
      }));
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to claim winnings';
    } finally {
      isLoading = false;
    }
  }

  function clearError() {
    error = null;
  }

  function reset() {
    commitment = null;
    error = null;
    // Clear stored secret
    if (browser && round) {
      localStorage.removeItem(`binary-bet-secret-${round.roundId}`);
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // CLEANUP
  // ══════════════════════════════════════════════════════════════════

  $effect(() => {
    return () => {
      stopTimer();
      ws?.close();
    };
  });

  // ══════════════════════════════════════════════════════════════════
  // RETURN
  // ══════════════════════════════════════════════════════════════════

  return {
    // State
    get round() { return round; },
    get commitment() { return commitment; },
    get playerStats() { return playerStats; },
    get recentResults() { return recentResults; },
    get timeRemaining() { return timeRemaining; },
    get blocksRemaining() { return blocksRemaining; },
    get isConnected() { return isConnected; },
    get isLoading() { return isLoading; },
    get error() { return error; },

    // Derived
    get canCommit() { return canCommit; },
    get canReveal() { return canReveal; },
    get mustReveal() { return mustReveal; },
    get totalPool() { return totalPool; },
    get side0Percentage() { return side0Percentage; },
    get side1Percentage() { return side1Percentage; },
    get potentialPayout() { return potentialPayout(); },
    get streakBonusPercent() { return streakBonusPercent(); },
    get winRate() { return winRate(); },
    get isWinner() { return isWinner; },

    // Actions
    connect,
    commitBet,
    revealBet,
    claimWinnings,
    clearError,
    reset
  };
}

// Singleton instance
let store: ReturnType<typeof createBinaryBetStore> | null = null;

export function getBinaryBetStore() {
  if (!store) {
    store = createBinaryBetStore();
  }
  return store;
}
```

---

## Visual Design

### Color Scheme

```css
.binary-bet {
  /* Base terminal colors */
  --bg-primary: #0a0a0a;
  --bg-secondary: #111111;
  --border-color: #00E5CC;
  --text-primary: #00E5CC;
  --text-dim: #00E5CC80;
  
  /* Side colors */
  --side-0-color: #00ffff;      /* Cyan for 0 */
  --side-1-color: #ff00ff;      /* Magenta for 1 */
  --side-0-glow: rgba(0, 255, 255, 0.3);
  --side-1-glow: rgba(255, 0, 255, 0.3);
  
  /* Status colors */
  --commit-color: #ffff00;      /* Yellow - pending */
  --reveal-color: #ff9900;      /* Orange - urgent */
  --win-color: #00ff00;         /* Green - success */
  --lose-color: #ff0000;        /* Red - failure */
  --forfeit-color: #ff3333;     /* Bright red - burned */
  
  /* Streak colors */
  --streak-3: #00ff00;
  --streak-5: #00ffff;
  --streak-7: #ff00ff;
  --streak-10: #ffff00;
}
```

### Animations

**Commit Confirmation:**
- Hash scramble effect on commitment
- Brief "LOCKED" flash
- Subtle pulse on committed side

**Block Countdown:**
- Block numbers tick down
- Tension builds with faster pulse
- Block hash "reveal" animation (scrambling characters settling)

**Reveal Phase:**
- Urgent pulse animation
- Timer turns red in final 10 seconds
- Secret "decrypting" animation on reveal

**Resolution:**
- Binary digit cascade (like Matrix rain)
- Winning side glows and expands
- Losing side dims and shrinks
- Payout numbers count up
- Screen flash (green for win, red for loss)

**Streak Effects:**
- Fire effect on 3+ streak
- Electric effect on 5+ streak
- Rainbow effect on 10+ streak

---

## Sound Design

| Event | Sound |
|-------|-------|
| Round Start | Digital "connection" beep |
| Bet Committed | Lock click + confirmation tone |
| Phase Change | Alert chime |
| Block Countdown | Mechanical tick (faster as time runs out) |
| Block Hash Captured | Data stream sound |
| Reveal Submitted | Decryption whoosh |
| Reveal Urgent (10s left) | Warning alarm |
| Resolution - Calculating | Suspenseful pulse |
| Win | Victorious synth chord + coins |
| Loss | Low buzz + flatline |
| Forfeit | Harsh error buzz |
| Streak Achieved | Level-up fanfare |
| Streak Lost | Sad descending tone |
| Big Win (>200% ROI) | Jackpot celebration |

---

## Feed Integration

```
> 0x7a3f committed to BINARY BET round #8472 [100 $DATA]
> BINARY BET round #8472 locked - 34 players, 4,250 $DATA in pot
> 0x9c2d revealed in BINARY BET - side 1
> BINARY BET #8472: Block hash 0x7a3f...8c2d - WINNER: 0
> 0x7a3f won BINARY BET #8472 [+106 $DATA] - 4 win streak!
> 0x3b1a forfeited BINARY BET - failed to reveal [100 $DATA BURNED]
> 0x8f2e hit 10-WIN STREAK in BINARY BET - ORACLE STATUS
```

---

## Security Considerations

### Front-Running Prevention

1. **Commit-Reveal Pattern**: Players cannot see others' choices before committing
2. **Block Hash Randomness**: Future block hash is unpredictable
3. **Commitment Verification**: Cannot change bet after commitment

### Block Hash Limitations

1. **256 Block Window**: Block hashes are only available for ~256 blocks
2. **Reveal Phase Timing**: Must capture hash before it expires
3. **Miner Manipulation**: Theoretical but impractical for low-value games

### Reveal Enforcement

1. **Forfeit Mechanism**: Unrevealed bets are burned (disincentivizes griefing)
2. **Auto-Reveal Option**: Frontend can auto-reveal to prevent accidental forfeit
3. **Grace Period**: 45 seconds is sufficient for manual reveal

### Rate Limiting

1. **One Bet Per Round**: Prevents wash trading
2. **Max Bet Cap**: 500 $DATA limits exposure
3. **Cooldown Between Rounds**: Prevents rapid-fire betting

---

## Testing Checklist

### Smart Contract Tests

- [ ] Commit phase only accepts valid commitments
- [ ] Cannot commit twice in same round
- [ ] Cannot commit after deadline
- [ ] Lock phase transition works correctly
- [ ] Block hash capture works for valid blocks
- [ ] Block hash fails gracefully if too old
- [ ] Reveal verifies commitment hash correctly
- [ ] Invalid reveals are rejected
- [ ] Cannot reveal after deadline
- [ ] Resolution calculates correct winning bit
- [ ] Payout calculation is accurate
- [ ] Burn amount is correct (5%)
- [ ] Streak bonuses apply correctly
- [ ] Forfeit burns unrevealed bets
- [ ] Cannot claim if not winner
- [ ] Cannot claim twice
- [ ] Edge case: all bets on one side
- [ ] Edge case: single player round
- [ ] Edge case: tie (equal amounts on both sides)

### Frontend Tests

- [ ] Store initializes correctly
- [ ] WebSocket connection/reconnection
- [ ] Timer countdown accuracy
- [ ] Phase transitions update UI
- [ ] Commitment stored in localStorage
- [ ] Secret retrieval for reveal
- [ ] Error handling for failed transactions
- [ ] Derived values calculate correctly
- [ ] Pool percentages update in real-time
- [ ] Streak display updates
- [ ] Win/loss state displays correctly

### Integration Tests

- [ ] Full round flow: commit -> lock -> reveal -> resolve -> claim
- [ ] Multiple players in same round
- [ ] Forfeit flow for unrevealed bet
- [ ] Streak persistence across rounds
- [ ] Round auto-start after resolution
- [ ] Feed events emit correctly
- [ ] Mobile responsiveness
- [ ] Wallet connection flow
- [ ] Transaction confirmation UX

### Performance Tests

- [ ] 100+ concurrent commits
- [ ] UI smooth at 60fps during animations
- [ ] WebSocket handles high message volume
- [ ] Contract gas optimization
- [ ] Local storage doesn't grow unbounded

---

## Future Enhancements

### Phase 3C Integration

- **Crew Rooms**: Private rooms for crew members only
- **Territory Bonuses**: Streak bonuses from controlled territories
- **Tournament Mode**: Multi-round elimination brackets

### Advanced Features

- **Bit Position Leagues**: Separate leaderboards per bit position
- **Prediction Markets**: Bet on streak outcomes
- **Historical Analysis**: Past block hash distribution charts
- **Social Betting**: Follow and copy successful players

### Economic Tuning

- **Dynamic Burn Rate**: Adjust based on pool size
- **Loyalty Rewards**: Reduced burn for frequent players
- **Jackpot Pool**: Portion of burn goes to random jackpot
