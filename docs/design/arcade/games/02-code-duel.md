# CODE DUEL

## Game Design Document

**Category:** Competitive PvP  
**Phase:** 3A (Quick Win)  
**Complexity:** Medium  
**Development Time:** 1.5 weeks  

---

## Overview

CODE DUEL is a 1v1 real-time typing battle where two players race to type the same code sequence. Winner takes 90% of the combined pot. Spectators can bet on outcomes.

```
╔══════════════════════════════════════════════════════════════════╗
║                          CODE DUEL                                ║
║                     0x7a3f  vs  0x9c2d                           ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  ┌─────────────────────────┐  ┌─────────────────────────────┐   ║
║  │ 0x7a3f                  │  │ 0x9c2d                      │   ║
║  │ ████████████████░░░░ 78%│  │ ██████████████░░░░░░░░ 62%  │   ║
║  │ 87 WPM  │  96% ACC      │  │ 72 WPM  │  94% ACC          │   ║
║  └─────────────────────────┘  └─────────────────────────────┘   ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  TYPE:                                                            ║
║  ssh -L 8080:localhost:443 ghost@proxy.darknet.io                ║
║  ████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
║  ssh -L 8080:localhost:443 gh█                                   ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  POT: 200 $DATA          SPECTATORS: 47         BETS: 1,240 $DATA║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Core Mechanics

### Match Flow

```
1. MATCHMAKING
   └── Player enters queue with wager
   └── Matched with similar wager opponent
   └── Both confirm match

2. READY PHASE (5 seconds)
   └── Players see opponent
   └── Code sequence revealed
   └── Spectators place bets

3. COUNTDOWN (3 seconds)
   └── 3... 2... 1... GO!

4. DUEL PHASE (30-60 seconds max)
   └── Both type same sequence
   └── First to complete wins
   └── Or timeout → higher accuracy wins

5. RESOLUTION
   └── Winner announced
   └── Payouts distributed
   └── Stats updated
```

### Win Conditions

1. **Speed Win:** First to complete sequence with ≥90% accuracy
2. **Accuracy Win:** If both finish, higher accuracy wins
3. **Timeout Win:** After 60 seconds, player with more progress + accuracy wins
4. **Forfeit Win:** Opponent disconnects or fails to type for 10 seconds

### Tie Breaker

If tied on accuracy AND completion:
1. Compare WPM
2. If still tied, pot splits 45/45 (10% still burns)

---

## Matchmaking System

### Wager Tiers

| Tier | Wager | Queue |
|------|-------|-------|
| Bronze | 50 $DATA | Casual |
| Silver | 150 $DATA | Competitive |
| Gold | 300 $DATA | High Stakes |
| Diamond | 500 $DATA | Elite |

### Matchmaking Rules

```typescript
interface MatchmakingCriteria {
  wagerTier: 'bronze' | 'silver' | 'gold' | 'diamond';
  maxWaitTime: number; // seconds
  ratingRange: number; // ELO points
}

// Initial match: ±100 ELO
// After 15s: ±200 ELO
// After 30s: ±300 ELO
// After 60s: Any opponent in tier
```

### Rating System

```typescript
// ELO-based rating
const K = 32; // K-factor

function calculateNewRating(
  winnerRating: number,
  loserRating: number
): { winner: number; loser: number } {
  const expectedWinner = 1 / (1 + Math.pow(10, (loserRating - winnerRating) / 400));
  const expectedLoser = 1 - expectedWinner;
  
  return {
    winner: Math.round(winnerRating + K * (1 - expectedWinner)),
    loser: Math.round(loserRating + K * (0 - expectedLoser))
  };
}
```

---

## Spectator Betting

### Betting Phase

- Opens when match is confirmed
- Closes when countdown reaches 1
- Minimum bet: 10 $DATA
- Maximum bet: 500 $DATA

### Odds Calculation

```typescript
function calculateOdds(player1Bets: bigint, player2Bets: bigint) {
  const total = player1Bets + player2Bets;
  const rake = total * 5n / 100n; // 5% rake
  const pool = total - rake;
  
  return {
    player1Multiplier: total > 0n ? Number(pool * 100n / player1Bets) / 100 : 2.0,
    player2Multiplier: total > 0n ? Number(pool * 100n / player2Bets) / 100 : 2.0,
    rake,
    pool
  };
}

// Example:
// Player 1 bets: 800 $DATA
// Player 2 bets: 400 $DATA
// Total: 1,200 $DATA
// Rake (5%): 60 $DATA burned
// Pool: 1,140 $DATA
// P1 wins: 800 → 1,140 (1.425x)
// P2 wins: 400 → 1,140 (2.85x)
```

---

## User Interface

### Queue Screen

```
╔══════════════════════════════════════════════════════════════════╗
║                        CODE DUEL ARENA                            ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  YOUR STATS                         LEADERBOARD                  ║
║  ─────────────                      ─────────────                ║
║  Rating: 1,247                      1. 0x3b1a  1,847             ║
║  Wins: 23                           2. 0x9c2d  1,723             ║
║  Losses: 12                         3. 0x7a3f  1,698             ║
║  Win Rate: 65.7%                    4. 0x8f2e  1,654             ║
║  Avg WPM: 82                        5. 0x1d4c  1,612             ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  SELECT WAGER:                                                    ║
║                                                                   ║
║  [  50 $DATA  ]  [  150 $DATA  ]  [  300 $DATA  ]  [  500 $DATA ]║
║      BRONZE          SILVER           GOLD           DIAMOND     ║
║                                                                   ║
║                  [ ENTER QUEUE ]                                  ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  ACTIVE DUELS: 12        PLAYERS IN QUEUE: 47                    ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Match Found Screen

```
╔══════════════════════════════════════════════════════════════════╗
║                       ⚔️ MATCH FOUND ⚔️                          ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║      YOU                              OPPONENT                    ║
║    0x7a3f                              0x9c2d                    ║
║                                                                   ║
║   Rating: 1,247                      Rating: 1,189               ║
║   Wins: 23                           Wins: 18                    ║
║   Avg WPM: 82                        Avg WPM: 76                 ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║                   WAGER: 150 $DATA EACH                          ║
║                   PRIZE: 270 $DATA (winner)                      ║
║                   BURN: 30 $DATA (10%)                           ║
║                                                                   ║
║          [ ACCEPT MATCH ]        [ DECLINE ]                     ║
║                                                                   ║
║                    Match expires in: 15                           ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Duel Screen

```
╔══════════════════════════════════════════════════════════════════╗
║  CODE DUEL                                      TIME: 00:23.47   ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  0x7a3f                                              0x9c2d      ║
║  ████████████████████░░░░░░░░░░  ░░░░░░░░░░██████████████████    ║
║        78%                                           62%         ║
║  87 WPM │ 96% ACC                           72 WPM │ 94% ACC    ║
║                                                                   ║
║  ═══════════════════════════════════════════════════════════════ ║
║                                                                   ║
║  TYPE THIS COMMAND:                                               ║
║                                                                   ║
║  nmap -sS -sV -p- --script vuln 192.168.1.0/24                   ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  nmap -sS -sV -p- --scr█                                         ║
║                         ^                                         ║
║                                                                   ║
║  ═══════════════════════════════════════════════════════════════ ║
║                                                                   ║
║  SPECTATOR BETS: 0x7a3f 65% (1.4x) │ 0x9c2d 35% (2.8x)          ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Victory Screen

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║                     ██╗   ██╗██╗ ██████╗████████╗ ██████╗ ██████╗ ║
║                     ██║   ██║██║██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗║
║                     ██║   ██║██║██║        ██║   ██║   ██║██████╔╝║
║                     ╚██╗ ██╔╝██║██║        ██║   ██║   ██║██╔══██╗║
║                      ╚████╔╝ ██║╚██████╗   ██║   ╚██████╔╝██║  ██║║
║                       ╚═══╝  ╚═╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝║
║                                                                   ║
║                           0x7a3f                                  ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║      YOUR STATS                      OPPONENT STATS               ║
║      ──────────                      ─────────────                ║
║      Time: 18.3s                     Time: 22.7s                 ║
║      WPM: 92                         WPM: 74                     ║
║      Accuracy: 98%                   Accuracy: 96%               ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║                    PRIZE: +270 $DATA                              ║
║                    RATING: +18 (now 1,265)                        ║
║                                                                   ║
║          [ REMATCH ]        [ NEW OPPONENT ]        [ EXIT ]     ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Economic Model

### Player Payouts

| Outcome | Winner Gets | Loser Gets | Burned |
|---------|-------------|------------|--------|
| Normal Win | 90% of pot | 0 | 10% |
| Tie | 45% each | 45% each | 10% |
| Forfeit | 100% of pot | 0 | Entry fee still counts |

### Spectator Payouts

| Outcome | Correct Bet | Wrong Bet | Burned |
|---------|-------------|-----------|--------|
| Normal | Pool × (your bet / winning side) | 0 | 5% rake |

### Example Economics

```
DUEL:
├── Player A wagers: 150 $DATA
├── Player B wagers: 150 $DATA
├── Total pot: 300 $DATA
├── Winner takes: 270 $DATA
└── Burned: 30 $DATA

SPECTATOR BETS:
├── On Player A: 800 $DATA (3 bettors)
├── On Player B: 400 $DATA (2 bettors)
├── Total: 1,200 $DATA
├── Rake (5%): 60 $DATA burned
├── Pool: 1,140 $DATA
│
├── If A wins:
│   └── A bettors split 1,140 $DATA (1.425x return)
└── If B wins:
    └── B bettors split 1,140 $DATA (2.85x return)

TOTAL BURN THIS MATCH: 90 $DATA
```

---

## Code Sequences

### Difficulty Tiers

**Bronze (50 $DATA):** 40-60 characters
```
ssh ghost@192.168.1.100 -p 2222
curl -X GET https://api.ghost/status
git commit -m "stealth update"
```

**Silver (150 $DATA):** 60-80 characters
```
nmap -sS -sV -p- --script vuln 192.168.1.0/24
docker run -d --name ghost -p 8080:80 ghostnet/core
openssl enc -aes-256-cbc -salt -in data.bin -out cipher.enc
```

**Gold (300 $DATA):** 80-100 characters
```
ssh -L 8080:localhost:443 -i ~/.ssh/ghost_key ghost@proxy.darknet.io
iptables -A INPUT -p tcp --dport 22 -s 10.0.0.0/8 -j ACCEPT -m comment "ghost"
tar -czvf payload.tar.gz ./extracted && scp -P 2222 payload.tar.gz ghost:/drop
```

**Diamond (500 $DATA):** 100-120 characters
```
kubectl exec -it $(kubectl get pods -l app=ghost -o jsonpath='{.items[0].metadata.name}') -- /bin/bash
msfconsole -q -x "use exploit/multi/handler; set PAYLOAD linux/x64/meterpreter/reverse_tcp; run"
```

---

## Technical Implementation

### Smart Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

contract CodeDuel {
    struct Match {
        address player1;
        address player2;
        uint256 wager;
        uint256 player1Bets;
        uint256 player2Bets;
        MatchState state;
        address winner;
        uint256 startTime;
    }
    
    enum MatchState { PENDING, READY, ACTIVE, RESOLVED, CANCELLED }
    
    mapping(uint256 => Match) public matches;
    mapping(uint256 => mapping(address => uint256)) public spectatorBets; // matchId => bettor => amount
    mapping(uint256 => mapping(address => bool)) public bettedOnPlayer1;
    
    uint256 public matchCounter;
    uint256 public constant PLAYER_RAKE = 1000; // 10%
    uint256 public constant SPECTATOR_RAKE = 500; // 5%
    
    event MatchCreated(uint256 indexed matchId, address player1, address player2, uint256 wager);
    event MatchStarted(uint256 indexed matchId);
    event MatchResolved(uint256 indexed matchId, address winner, uint256 prize);
    event SpectatorBetPlaced(uint256 indexed matchId, address bettor, bool onPlayer1, uint256 amount);
    
    function createMatch(address opponent, uint256 wager) external returns (uint256) {
        require(wager >= 50 ether, "Min wager 50");
        
        dataToken.transferFrom(msg.sender, address(this), wager);
        
        uint256 matchId = ++matchCounter;
        matches[matchId] = Match({
            player1: msg.sender,
            player2: opponent,
            wager: wager,
            player1Bets: 0,
            player2Bets: 0,
            state: MatchState.PENDING,
            winner: address(0),
            startTime: 0
        });
        
        emit MatchCreated(matchId, msg.sender, opponent, wager);
        return matchId;
    }
    
    function acceptMatch(uint256 matchId) external {
        Match storage m = matches[matchId];
        require(m.state == MatchState.PENDING, "Not pending");
        require(msg.sender == m.player2, "Not opponent");
        
        dataToken.transferFrom(msg.sender, address(this), m.wager);
        m.state = MatchState.READY;
        
        emit MatchStarted(matchId);
    }
    
    function placeSpectatorBet(uint256 matchId, bool onPlayer1, uint256 amount) external {
        Match storage m = matches[matchId];
        require(m.state == MatchState.READY, "Betting closed");
        
        dataToken.transferFrom(msg.sender, address(this), amount);
        
        spectatorBets[matchId][msg.sender] += amount;
        bettedOnPlayer1[matchId][msg.sender] = onPlayer1;
        
        if (onPlayer1) {
            m.player1Bets += amount;
        } else {
            m.player2Bets += amount;
        }
        
        emit SpectatorBetPlaced(matchId, msg.sender, onPlayer1, amount);
    }
    
    // Called by oracle/backend with verified result
    function resolveMatch(uint256 matchId, address winner) external onlyOracle {
        Match storage m = matches[matchId];
        require(m.state == MatchState.ACTIVE, "Not active");
        require(winner == m.player1 || winner == m.player2, "Invalid winner");
        
        m.winner = winner;
        m.state = MatchState.RESOLVED;
        
        // Calculate payouts
        uint256 totalPot = m.wager * 2;
        uint256 rake = (totalPot * PLAYER_RAKE) / 10000;
        uint256 prize = totalPot - rake;
        
        // Burn rake
        dataToken.burn(rake);
        
        // Pay winner
        dataToken.transfer(winner, prize);
        
        // Handle spectator bets
        _settleSpectatorBets(matchId);
        
        emit MatchResolved(matchId, winner, prize);
    }
}
```

### Real-Time Sync

```typescript
// WebSocket message types for CODE DUEL

interface DuelMessage {
  type: 'OPPONENT_PROGRESS' | 'MATCH_RESULT' | 'SPECTATOR_BET' | 'COUNTDOWN';
  matchId: string;
  data: unknown;
}

interface OpponentProgress {
  progress: number;      // 0-100
  wpm: number;
  accuracy: number;
  currentPosition: number;
}

interface MatchResult {
  winner: string;
  player1Stats: PlayerStats;
  player2Stats: PlayerStats;
  prizeAmount: bigint;
  spectatorPayouts: SpectatorPayout[];
}
```

---

## Sound Design

| Event | Sound |
|-------|-------|
| Match Found | Alert chime |
| Countdown | 3-2-1 beeps |
| GO! | Starting horn |
| Keystroke (correct) | Soft click |
| Keystroke (wrong) | Error buzz |
| Opponent Progress | Distant typing |
| Opponent Near Finish | Warning pulse |
| Victory | Triumphant fanfare |
| Defeat | Somber tone |
| Spectator Win | Cash register |

---

## Feed Integration

```
> ⚔️ CODE DUEL: 0x7a3f vs 0x9c2d - 150 $DATA each
> 0x7a3f WINS CODE DUEL @ 92 WPM - +270 $DATA 🏆
> SPECTATORS: 5 correct bets split 1,140 $DATA
> 🔥 0x3b1a on 5-DUEL WIN STREAK - Rating: 1,847 🔥
```

---

## Testing Checklist

- [ ] Matchmaking queue functions correctly
- [ ] Both players see same code sequence
- [ ] Progress syncs in real-time (<50ms latency)
- [ ] Winner determined correctly (speed, then accuracy)
- [ ] Tie handling works
- [ ] Forfeit/disconnect handling
- [ ] Spectator bet placement during ready phase
- [ ] Spectator bet cutoff at countdown
- [ ] Payout calculations correct
- [ ] Rating updates correctly
- [ ] Mobile keyboard support
- [ ] Anti-cheat: no copy-paste
- [ ] Anti-cheat: no automation detection
