# HASH CRASH

## Game Design Document

**Category:** Casino  
**Phase:** 3A (Quick Win)  
**Complexity:** Low  
**Development Time:** 1 week  

---

## Overview

HASH CRASH is a multiplier-based crash game where players bet $DATA and watch a multiplier climb. Cash out before it crashes to win. Wait too long and lose everything.

```
╔══════════════════════════════════════════════════════════════════╗
║                         HASH CRASH                                ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║                         MULTIPLIER                                ║
║                                                                   ║
║                          ██  23.47x                               ║
║                         ██                                        ║
║                        ██                                         ║
║                       ██                                          ║
║                     ███                                           ║
║                   ███                                             ║
║                ████                                               ║
║           ██████                                                  ║
║     ████████                                                      ║
║  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀  ║
║                                                                   ║
║  YOUR BET: 100 $DATA              POTENTIAL: 2,347 $DATA          ║
║                                                                   ║
║                    [ CASH OUT @ 23.47x ]                          ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  RECENT CRASHES: 1.23x │ 4.56x │ 12.34x │ 1.01x │ 89.12x         ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Core Mechanics

### Game Flow

```
1. BETTING PHASE (10 seconds)
   └── Players place bets (10-1000 $DATA)

2. LAUNCH PHASE
   └── Multiplier starts at 1.00x
   └── Increases exponentially

3. ACTIVE PHASE
   └── Players can cash out anytime
   └── Multiplier keeps climbing
   └── CRASH happens randomly

4. RESOLUTION PHASE
   └── Players who cashed out WIN
   └── Players still in LOSE
   └── New round starts
```

### Multiplier Curve

The multiplier follows an exponential curve:

```javascript
// Multiplier at time t (in seconds)
multiplier = 1.0 * Math.pow(E, growthRate * t)

// Where growthRate determines speed
// Typical: 0.05-0.08 per second
```

### Crash Point Algorithm

Crash point is determined by **future block hash** — a provably fair on-chain randomness source:

```javascript
// Pseudo-code for crash point calculation
function calculateCrashPoint(blockHashSeed: bytes32): number {
  // Convert block hash to uniform random [0, 1)
  const random = uint256(blockHashSeed) / MAX_UINT256;
  
  // House edge: 3%
  const houseEdge = 0.03;
  
  // Crash point formula (inverse of cumulative distribution)
  // This gives ~1% chance for >100x, ~3% for >33x, etc.
  const crashPoint = (1 - houseEdge) / (1 - random);
  
  // Minimum crash at 1.00x
  return Math.max(1.00, crashPoint);
}
```

**How it works:**
1. When betting phase closes, we commit to a block 5 blocks in the future
2. That block's hash becomes the seed once mined
3. No one can predict the hash until after all bets are locked
```

**Crash Point Distribution:**
| Crash Point | Probability |
|-------------|-------------|
| < 1.5x | 35% |
| 1.5x - 2x | 17% |
| 2x - 3x | 15% |
| 3x - 5x | 12% |
| 5x - 10x | 10% |
| 10x - 50x | 8% |
| 50x - 100x | 2% |
| > 100x | 1% |

---

## User Interface

### States

**1. Betting Phase**
```
╔══════════════════════════════════════════════════════════════════╗
║  HASH CRASH                           ROUND #4,847               ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║                    NEXT ROUND STARTING IN                         ║
║                           07                                      ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  YOUR BET:  [    100    ] $DATA                                  ║
║                                                                   ║
║  QUICK BET: [10] [50] [100] [500] [MAX]                         ║
║                                                                   ║
║  AUTO CASH OUT: [ ] Enable at [____] x                           ║
║                                                                   ║
║                    [ PLACE BET ]                                  ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  PLAYERS BETTING: 47        TOTAL POT: 12,450 $DATA              ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**2. Active Phase (Rising)**
```
╔══════════════════════════════════════════════════════════════════╗
║  HASH CRASH                           ROUND #4,847               ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║                          5.67x                                    ║
║                                                                   ║
║           ████████████████████                                    ║
║         ██████████████████                                        ║
║       ████████████████                                            ║
║     ██████████████                                                ║
║   ████████████                                                    ║
║  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀  ║
║                                                                   ║
║  YOUR BET: 100 $DATA              POTENTIAL: 567 $DATA           ║
║                                                                   ║
║              [ CASH OUT @ 5.67x → 567 $DATA ]                    ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  STILL IN: 23/47              CASHED OUT: 24/47                  ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**3. Crashed State**
```
╔══════════════════════════════════════════════════════════════════╗
║  HASH CRASH                           ROUND #4,847               ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║               ████  CRASHED @ 8.23x  ████                        ║
║                                                                   ║
║                    ░░░░░░░░░░░░░░░░░░░░                          ║
║                  ░░░░░░░░░░░░░░░░░░                              ║
║                ░░░░░░░░░░░░░░░░                                  ║
║              ░░░░░░░░░░░░░░                                      ║
║            ░░░░░░░░░░░░                                          ║
║  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀  ║
║                                                                   ║
║  YOU CASHED OUT @ 5.67x                    +467 $DATA             ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  WINNERS: 24        LOSERS: 23        BURNED: 373 $DATA 🔥       ║
║                                                                   ║
║                    NEXT ROUND IN: 05                              ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Live Players Panel

Shows real-time cash-outs:

```
LIVE PLAYERS
─────────────────────────────────────
0x7a3f   100 $DATA    CASHED @ 2.3x  ✓
0x9c2d   500 $DATA    IN PLAY...
0x3b1a    50 $DATA    CASHED @ 5.1x  ✓
0x8f2e   200 $DATA    IN PLAY...
0x1d4c  1000 $DATA    CASHED @ 1.5x  ✓
─────────────────────────────────────
```

---

## Economic Model

### Entry & Fees

| Parameter | Value |
|-----------|-------|
| Minimum Bet | 10 $DATA |
| Maximum Bet | 1,000 $DATA |
| House Edge | 3% |
| Burn Rate | 100% of house edge |

### Payout Calculation

```javascript
function calculatePayout(bet: bigint, cashOutMultiplier: number): bigint {
  const grossPayout = bet * BigInt(Math.floor(cashOutMultiplier * 100)) / 100n;
  return grossPayout;
}

// Example:
// Bet: 100 $DATA
// Cash out at 5.67x
// Payout: 567 $DATA (profit: 467 $DATA)
```

### Burn Mechanics

The 3% house edge is realized through the crash point formula:
- On average, 3% of all bets flow to the protocol
- 100% of this is burned (no protocol take)
- Every round burns tokens, win or lose

**Example Round:**
```
Total Bets: 12,450 $DATA
Crash Point: 8.23x
Winners: 24 players cashed out before crash
Losers: 23 players still in

Winner Payouts: ~8,200 $DATA (varied multipliers)
Loser Losses: ~4,250 $DATA (all goes to burn)

Net Burn: ~373 $DATA (3% of total action)
```

---

## Technical Implementation

### Smart Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title HashCrash
/// @notice Multiplier crash game using future block hash for provably fair randomness
/// @dev MegaETH-compatible: uses future block hash instead of VRF
contract HashCrash is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════
    // TYPES
    // ══════════════════════════════════════════════════════════════════

    enum RoundState { BETTING, PENDING, ACTIVE, CRASHED, SETTLING }
    
    struct Round {
        uint256 roundId;
        RoundState state;
        uint256 totalBets;
        uint256 seedBlock;      // Block number for randomness
        bytes32 seedHash;       // Captured block hash
        uint256 crashPoint;     // Stored as basis points (823 = 8.23x)
        uint256 startTime;
        uint256 bettingEndsAt;
    }
    
    struct Bet {
        uint256 amount;
        uint256 cashOutPoint;   // 0 = not cashed out
        bool settled;
    }

    // ══════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════
    
    uint256 public constant HOUSE_EDGE_BPS = 300;       // 3%
    uint256 public constant MIN_BET = 10 ether;         // 10 $DATA
    uint256 public constant MAX_BET = 1000 ether;       // 1000 $DATA
    uint256 public constant BETTING_DURATION = 10;      // 10 seconds
    uint256 public constant SEED_BLOCK_DELAY = 5;       // 5 blocks (~5 seconds on MegaETH)
    uint256 public constant BPS = 10000;

    // ══════════════════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════════════════

    IERC20 public immutable dataToken;
    uint256 public currentRound;
    
    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(address => Bet)) public bets;
    mapping(uint256 => address[]) internal roundPlayers;

    // ══════════════════════════════════════════════════════════════════
    // ERRORS
    // ══════════════════════════════════════════════════════════════════

    error NotBettingPhase();
    error BettingNotEnded();
    error InvalidBetAmount();
    error AlreadyBet();
    error NotActive();
    error NoBet();
    error AlreadyCashedOut();
    error SeedBlockNotMined();
    error SeedBlockTooOld();
    error GameNotCrashed();

    // ══════════════════════════════════════════════════════════════════
    // EVENTS
    // ══════════════════════════════════════════════════════════════════
    
    event RoundStarted(uint256 indexed roundId, uint256 bettingEndsAt);
    event BetPlaced(uint256 indexed roundId, address indexed player, uint256 amount);
    event SeedBlockCommitted(uint256 indexed roundId, uint256 seedBlock);
    event GameStarted(uint256 indexed roundId, uint256 crashPoint, bytes32 seedHash);
    event CashedOut(uint256 indexed roundId, address indexed player, uint256 multiplierBps, uint256 payout);
    event RoundCrashed(uint256 indexed roundId, uint256 crashPointBps);

    // ══════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ══════════════════════════════════════════════════════════════════

    constructor(address _dataToken, address _owner) Ownable(_owner) {
        dataToken = IERC20(_dataToken);
    }

    // ══════════════════════════════════════════════════════════════════
    // ROUND LIFECYCLE
    // ══════════════════════════════════════════════════════════════════

    /// @notice Start a new betting round
    function startRound() external {
        // Verify previous round is complete
        if (currentRound > 0) {
            require(
                rounds[currentRound].state == RoundState.CRASHED ||
                rounds[currentRound].state == RoundState.SETTLING,
                "Previous round not complete"
            );
        }

        uint256 roundId = ++currentRound;
        uint256 bettingEndsAt = block.timestamp + BETTING_DURATION;
        
        rounds[roundId] = Round({
            roundId: roundId,
            state: RoundState.BETTING,
            totalBets: 0,
            seedBlock: 0,
            seedHash: bytes32(0),
            crashPoint: 0,
            startTime: 0,
            bettingEndsAt: bettingEndsAt
        });

        emit RoundStarted(roundId, bettingEndsAt);
    }

    /// @notice Place a bet for current round
    function placeBet(uint256 amount) external nonReentrant {
        Round storage round = rounds[currentRound];
        
        if (round.state != RoundState.BETTING) revert NotBettingPhase();
        if (block.timestamp > round.bettingEndsAt) revert NotBettingPhase();
        if (amount < MIN_BET || amount > MAX_BET) revert InvalidBetAmount();
        if (bets[currentRound][msg.sender].amount > 0) revert AlreadyBet();

        dataToken.safeTransferFrom(msg.sender, address(this), amount);
        
        bets[currentRound][msg.sender] = Bet({
            amount: amount,
            cashOutPoint: 0,
            settled: false
        });
        
        roundPlayers[currentRound].push(msg.sender);
        round.totalBets += amount;
        
        emit BetPlaced(currentRound, msg.sender, amount);
    }

    /// @notice End betting phase and commit to future block for randomness
    function endBetting() external {
        Round storage round = rounds[currentRound];
        
        if (round.state != RoundState.BETTING) revert NotBettingPhase();
        if (block.timestamp < round.bettingEndsAt) revert BettingNotEnded();

        // Commit to a future block hash for randomness
        round.seedBlock = block.number + SEED_BLOCK_DELAY;
        round.state = RoundState.PENDING;

        emit SeedBlockCommitted(currentRound, round.seedBlock);
    }

    /// @notice Start the game once seed block is mined
    function startGame() external {
        Round storage round = rounds[currentRound];
        
        require(round.state == RoundState.PENDING, "Not pending");
        if (block.number <= round.seedBlock) revert SeedBlockNotMined();
        if (block.number > round.seedBlock + 256) revert SeedBlockTooOld();

        // Capture block hash and calculate crash point
        bytes32 hash = blockhash(round.seedBlock);
        require(hash != bytes32(0), "Block hash unavailable");

        uint256 seed = uint256(keccak256(abi.encode(hash, currentRound, address(this))));
        uint256 crashPoint = _calculateCrashPoint(seed);

        round.seedHash = hash;
        round.crashPoint = crashPoint;
        round.state = RoundState.ACTIVE;
        round.startTime = block.timestamp;

        emit GameStarted(currentRound, crashPoint, hash);
    }

    /// @notice Cash out at current multiplier
    function cashOut() external nonReentrant {
        Round storage round = rounds[currentRound];
        Bet storage bet = bets[currentRound][msg.sender];

        if (round.state != RoundState.ACTIVE) revert NotActive();
        if (bet.amount == 0) revert NoBet();
        if (bet.cashOutPoint > 0) revert AlreadyCashedOut();

        uint256 currentMultiplier = getCurrentMultiplier();
        
        // Check if game already crashed
        if (currentMultiplier >= round.crashPoint) {
            revert GameNotCrashed(); // Actually crashed, can't cash out
        }

        bet.cashOutPoint = currentMultiplier;
        bet.settled = true;
        
        uint256 payout = (bet.amount * currentMultiplier) / 100;
        dataToken.safeTransfer(msg.sender, payout);
        
        emit CashedOut(currentRound, msg.sender, currentMultiplier, payout);
    }

    /// @notice Trigger crash when multiplier reaches crash point
    function triggerCrash() external {
        Round storage round = rounds[currentRound];
        
        require(round.state == RoundState.ACTIVE, "Not active");
        
        uint256 currentMultiplier = getCurrentMultiplier();
        require(currentMultiplier >= round.crashPoint, "Not crashed yet");

        round.state = RoundState.CRASHED;
        
        emit RoundCrashed(currentRound, round.crashPoint);
    }

    // ══════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ══════════════════════════════════════════════════════════════════

    /// @notice Get current multiplier based on elapsed time
    function getCurrentMultiplier() public view returns (uint256) {
        Round storage round = rounds[currentRound];
        
        if (round.state != RoundState.ACTIVE) return 100;
        if (round.startTime == 0) return 100;

        uint256 elapsed = block.timestamp - round.startTime;
        
        // Exponential growth approximation: 100 + 6*t
        // 100 = 1.00x, increases by 0.06x per second
        uint256 multiplier = 100 + (elapsed * 6);
        
        return multiplier;
    }

    /// @notice Verify crash point calculation (for provable fairness)
    function verifyCrashPoint(bytes32 seedHash, uint256 roundId) external view returns (uint256) {
        uint256 seed = uint256(keccak256(abi.encode(seedHash, roundId, address(this))));
        return _calculateCrashPoint(seed);
    }

    // ══════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ══════════════════════════════════════════════════════════════════

    /// @notice Calculate crash point from seed
    /// @dev Uses inverse transform sampling for exponential distribution
    function _calculateCrashPoint(uint256 seed) internal pure returns (uint256) {
        // Convert seed to uniform random in [0, 1) with high precision
        uint256 random = seed % 1e18;
        if (random == 0) random = 1;

        // Crash point formula: (10000 - houseEdge) / (10000 - random_scaled)
        uint256 numerator = (BPS - HOUSE_EDGE_BPS) * 1e18;
        uint256 denominator = 1e18 - random;

        uint256 crashPoint = numerator / denominator;

        // Minimum crash of 1.00x (100 basis points)
        if (crashPoint < 100) crashPoint = 100;

        return crashPoint;
    }
}
```

### Frontend Store

```typescript
// src/lib/features/arcade/hash-crash/store.svelte.ts

import { browser } from '$app/environment';

export type RoundState = 'betting' | 'active' | 'crashed' | 'settling';

interface CrashRound {
  roundId: number;
  state: RoundState;
  totalBets: bigint;
  crashPoint: number | null;
  startTime: number;
  bettingEndsAt: number;
}

interface PlayerBet {
  amount: bigint;
  cashOutMultiplier: number | null;
  potentialPayout: bigint;
}

interface CashOut {
  address: string;
  multiplier: number;
  payout: bigint;
  timestamp: number;
}

export function createHashCrashStore() {
  // State
  let round = $state<CrashRound | null>(null);
  let currentMultiplier = $state(1.0);
  let playerBet = $state<PlayerBet | null>(null);
  let recentCashOuts = $state<CashOut[]>([]);
  let recentCrashPoints = $state<number[]>([]);
  let isConnected = $state(false);
  
  // Derived
  let canBet = $derived(round?.state === 'betting' && playerBet === null);
  let canCashOut = $derived(round?.state === 'active' && playerBet !== null && playerBet.cashOutMultiplier === null);
  let potentialPayout = $derived(
    playerBet ? BigInt(Math.floor(Number(playerBet.amount) * currentMultiplier)) : 0n
  );
  
  // Animation frame for smooth multiplier updates
  let animationFrame: number | null = null;
  
  function startMultiplierAnimation() {
    if (!browser || round?.state !== 'active') return;
    
    const startTime = round.startTime;
    const growthRate = 0.06; // 6% per second
    
    function update() {
      const elapsed = (Date.now() - startTime) / 1000;
      currentMultiplier = Math.pow(Math.E, growthRate * elapsed);
      
      if (round?.state === 'active') {
        animationFrame = requestAnimationFrame(update);
      }
    }
    
    animationFrame = requestAnimationFrame(update);
  }
  
  function stopMultiplierAnimation() {
    if (animationFrame) {
      cancelAnimationFrame(animationFrame);
      animationFrame = null;
    }
  }
  
  // WebSocket connection for real-time updates
  function connect() {
    if (!browser) return;
    
    const ws = new WebSocket('wss://api.ghostnet.io/crash');
    
    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      
      switch (data.type) {
        case 'ROUND_STATE':
          round = data.round;
          if (data.round.state === 'active') {
            startMultiplierAnimation();
          } else {
            stopMultiplierAnimation();
          }
          break;
          
        case 'CASH_OUT':
          recentCashOuts = [data.cashOut, ...recentCashOuts.slice(0, 19)];
          break;
          
        case 'CRASHED':
          round = { ...round!, state: 'crashed', crashPoint: data.crashPoint };
          currentMultiplier = data.crashPoint;
          recentCrashPoints = [data.crashPoint, ...recentCrashPoints.slice(0, 9)];
          stopMultiplierAnimation();
          break;
          
        case 'BET_CONFIRMED':
          playerBet = {
            amount: BigInt(data.amount),
            cashOutMultiplier: null,
            potentialPayout: BigInt(data.amount)
          };
          break;
          
        case 'CASH_OUT_CONFIRMED':
          if (playerBet) {
            playerBet = { ...playerBet, cashOutMultiplier: data.multiplier };
          }
          break;
      }
    };
    
    ws.onopen = () => { isConnected = true; };
    ws.onclose = () => { isConnected = false; };
    
    return () => {
      ws.close();
      stopMultiplierAnimation();
    };
  }
  
  async function placeBet(amount: bigint) {
    // Contract interaction
  }
  
  async function cashOut() {
    // Contract interaction
  }
  
  return {
    // State
    get round() { return round; },
    get currentMultiplier() { return currentMultiplier; },
    get playerBet() { return playerBet; },
    get recentCashOuts() { return recentCashOuts; },
    get recentCrashPoints() { return recentCrashPoints; },
    get isConnected() { return isConnected; },
    
    // Derived
    get canBet() { return canBet; },
    get canCashOut() { return canCashOut; },
    get potentialPayout() { return potentialPayout; },
    
    // Actions
    connect,
    placeBet,
    cashOut
  };
}
```

---

## Visual Design

### Color Scheme

```css
.hash-crash {
  /* Rising multiplier - green intensity increases */
  --mult-low: #00ff00;      /* 1x - 2x */
  --mult-mid: #00ffaa;      /* 2x - 5x */
  --mult-high: #00ffff;     /* 5x - 10x */
  --mult-extreme: #ffff00;  /* 10x+ */
  
  /* Crash - red flash */
  --crash-color: #ff0000;
  --crash-glow: rgba(255, 0, 0, 0.5);
}
```

### Animations

**Multiplier Growth:**
- Number scales slightly as it increases
- Glow intensifies with higher multipliers
- Color shifts through spectrum

**Cash Out:**
- Green flash on the player's row
- Payout amount animates in
- Checkmark appears

**Crash:**
- Screen flashes red
- Multiplier "shatters" animation
- Graph line turns to static/noise
- Losers' bets show red X

---

## Sound Design

| Event | Sound |
|-------|-------|
| Round Start | Low hum building |
| Multiplier Rising | Pitch increases with multiplier |
| Cash Out (self) | Satisfying "cha-ching" |
| Cash Out (others) | Soft click |
| Approaching Danger (>10x) | Warning pulse |
| Crash | Explosion + flatline |
| Big Win (>20x) | Victory fanfare |

---

## Feed Integration

```
> 0x7a3f cashed out HASH CRASH @ 12.4x [+1,240 $DATA] 💰
> HASH CRASH round #4847 crashed @ 8.23x - 23 traced 💥
> 0x9c2d rode HASH CRASH to 47.2x [+4,720 $DATA] 🚀
> 🔥 HASH CRASH hit 100x+ - 3 legends cashed out 🔥
```

---

## Testing Checklist

### Smart Contract
- [ ] Bet placement in betting phase only
- [ ] Cannot bet twice in same round
- [ ] Cash out works during active phase only
- [ ] Multiplier calculation accuracy
- [ ] Seed block commitment after betting closes
- [ ] Block hash capture within 256 block window
- [ ] Crash point calculation deterministic from seed
- [ ] Payout calculations correct
- [ ] Round state transitions: BETTING → PENDING → ACTIVE → CRASHED

### Provable Fairness
- [ ] `verifyCrashPoint()` matches actual crash point
- [ ] Seed hash matches `blockhash(seedBlock)`
- [ ] Cannot predict crash point during betting phase
- [ ] Same seed + roundId always produces same crash point

### Frontend
- [ ] WebSocket real-time updates
- [ ] UI animations smooth at 60fps
- [ ] Mobile responsiveness
- [ ] Fairness verification UI shows provenance chain
- [ ] Load test with 100+ concurrent players
