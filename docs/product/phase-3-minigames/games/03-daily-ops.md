# DAILY OPS

## Game Design Document

**Category:** Progression/Retention  
**Phase:** 3A (Quick Win)  
**Complexity:** Low  
**Development Time:** 1 week  

---

## Overview

DAILY OPS is a daily challenge system that gives players one unique mission per day. Complete it for rewards. Build streaks for exponential bonuses. Miss a day, lose your streak.

```
╔══════════════════════════════════════════════════════════════════╗
║                         DAILY OPS                                 ║
║                    Day 12 of your infiltration                   ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  TODAY'S MISSION: SPEED DEMON                                     ║
║  ────────────────────────────                                    ║
║  Complete a Trace Evasion with 90+ WPM                           ║
║                                                                   ║
║  REWARD: 50 $DATA + 2% death rate reduction (24h)                ║
║                                                                   ║
║  STATUS: [ NOT COMPLETE ]                                         ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  YOUR STREAK: 11 days 🔥                                          ║
║                                                                   ║
║  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 0/7 this week                    ║
║  Mon  Tue  Wed  Thu  Fri  Sat  Sun                               ║
║   ✓    ✓    ✓    ✓    ✓    ✓    ○                                ║
║                                                                   ║
║  WEEKLY BONUS: Complete all 7 for 500 $DATA                      ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  STREAK MILESTONES:                                               ║
║  ✓ 3 days  → -3% death rate (permanent while streak active)      ║
║  ✓ 7 days  → 500 $DATA bonus                                     ║
║  ○ 14 days → -5% death rate (permanent while active)             ║
║  ○ 30 days → 5000 $DATA + "DEDICATED OPERATOR" badge             ║
║                                                                   ║
║  TIME REMAINING: 14:32:17                                         ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Core Mechanics

### Daily Reset

- New mission at 00:00 UTC daily
- 24-hour window to complete
- Incomplete mission = streak broken
- Cannot stack or save missions

### Mission Types

Missions are randomly selected from a pool, weighted by player history:

```typescript
interface Mission {
  id: string;
  name: string;
  description: string;
  type: MissionType;
  requirement: MissionRequirement;
  reward: MissionReward;
  difficulty: 'easy' | 'medium' | 'hard';
}

type MissionType = 
  | 'typing'      // Trace Evasion related
  | 'hackrun'     // Hack Run related
  | 'survival'    // Position survival
  | 'social'      // Crew/community
  | 'betting'     // Dead Pool related
  | 'trading'     // Buy/sell related
  | 'meta';       // Cross-game
```

### Mission Pool

**Easy Missions (40% chance):**
```
DAILY LOGIN
└── Requirement: Just show up
└── Reward: 10 $DATA

SURVIVOR
└── Requirement: Survive 1 trace scan
└── Reward: 25 $DATA + 1% death reduction

TYPIST
└── Requirement: Complete 1 Trace Evasion (any score)
└── Reward: 20 $DATA

WATCHER
└── Requirement: Watch the feed for 10 minutes
└── Reward: 15 $DATA
```

**Medium Missions (45% chance):**
```
SPEED DEMON
└── Requirement: Trace Evasion with 80+ WPM
└── Reward: 50 $DATA + 2% death reduction

ACCURATE OPERATOR  
└── Requirement: Trace Evasion with 95%+ accuracy
└── Reward: 50 $DATA + 2% death reduction

HACK RUNNER
└── Requirement: Complete a Hack Run (any difficulty)
└── Reward: 75 $DATA

FORTUNE TELLER
└── Requirement: Win a Dead Pool bet
└── Reward: 50 $DATA + your winnings

SOCIAL GHOST
└── Requirement: Participate in crew activity
└── Reward: 40 $DATA + 5% crew bonus

DEEP COVER
└── Requirement: Maintain position for 4 hours
└── Reward: 60 $DATA
```

**Hard Missions (15% chance):**
```
ELITE TYPER
└── Requirement: Trace Evasion with 100+ WPM and 98%+ accuracy
└── Reward: 150 $DATA + 5% death reduction

PERFECT RUN
└── Requirement: Complete Hack Run without any mistakes
└── Reward: 200 $DATA + 3x multiplier (2h)

SURVIVOR EXTREME
└── Requirement: Survive scan in DARKNET or higher
└── Reward: 100 $DATA + 3% death reduction

HIGH ROLLER
└── Requirement: Win 3 consecutive Dead Pool bets
└── Reward: 200 $DATA

DUEL CHAMPION
└── Requirement: Win a CODE DUEL
└── Reward: 150 $DATA + rating bonus
```

---

## Streak System

### Streak Benefits

| Streak | Benefit | Type |
|--------|---------|------|
| 3 days | -3% death rate | Persistent (while active) |
| 7 days | 500 $DATA bonus | One-time |
| 14 days | -5% death rate | Persistent |
| 21 days | 1,000 $DATA bonus | One-time |
| 30 days | 5,000 $DATA + Badge | One-time + Permanent |
| 60 days | -8% death rate | Persistent |
| 90 days | 15,000 $DATA + Title | One-time + Permanent |
| 180 days | -10% death rate + Legendary status | Persistent + Permanent |

### Streak Mechanics

```typescript
interface StreakState {
  currentStreak: number;
  longestStreak: number;
  lastCompletedAt: Date | null;
  activeBenefits: StreakBenefit[];
}

function updateStreak(state: StreakState, completed: boolean): StreakState {
  const now = new Date();
  const lastDate = state.lastCompletedAt;
  
  if (!completed) {
    // Streak broken
    return {
      ...state,
      currentStreak: 0,
      activeBenefits: [] // Lose persistent benefits
    };
  }
  
  if (lastDate && isConsecutiveDay(lastDate, now)) {
    // Continue streak
    const newStreak = state.currentStreak + 1;
    return {
      currentStreak: newStreak,
      longestStreak: Math.max(newStreak, state.longestStreak),
      lastCompletedAt: now,
      activeBenefits: calculateBenefits(newStreak)
    };
  }
  
  // New streak
  return {
    ...state,
    currentStreak: 1,
    lastCompletedAt: now,
    activeBenefits: calculateBenefits(1)
  };
}
```

### Streak Protection (Premium Feature)

Players can purchase "Streak Shield" items:
- **Single Shield (50 $DATA burned):** Protects streak for 1 missed day
- **Weekly Shield (200 $DATA burned):** Protects streak for 1 week
- Maximum 1 shield active at a time

---

## Weekly Bonus

Complete all 7 daily missions in a week for bonus rewards:

```
WEEKLY COMPLETION REWARDS:
─────────────────────────

Week 1:  500 $DATA
Week 2:  600 $DATA
Week 3:  700 $DATA
Week 4:  800 $DATA + Monthly Badge
Week 5+: 1,000 $DATA

Consecutive weeks multiply:
2 weeks in a row: 1.2x weekly reward
4 weeks in a row: 1.5x weekly reward
8 weeks in a row: 2x weekly reward
```

---

## User Interface

### Main Screen Integration

Daily Ops appears as a widget on the main dashboard:

```
┌─────────────────────────────────────┐
│ DAILY OPS          🔥 12 day streak │
├─────────────────────────────────────┤
│                                     │
│ TODAY: SPEED DEMON                  │
│ 90+ WPM in Trace Evasion            │
│                                     │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░ 14:32  │
│                                     │
│ [ VIEW MISSION ]                    │
│                                     │
└─────────────────────────────────────┘
```

### Mission Detail Modal

```
╔══════════════════════════════════════════════════════════════════╗
║                     DAILY OPS: DAY 12                             ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  ┌─────────────────────────────────────────────────────────────┐ ║
║  │                                                              │ ║
║  │  MISSION: SPEED DEMON                                        │ ║
║  │  ═══════════════════                                         │ ║
║  │                                                              │ ║
║  │  "The trace is closing in. Type faster."                     │ ║
║  │                                                              │ ║
║  │  OBJECTIVE:                                                  │ ║
║  │  Complete a Trace Evasion challenge with 90+ WPM             │ ║
║  │                                                              │ ║
║  │  REWARD:                                                     │ ║
║  │  • 50 $DATA                                                  │ ║
║  │  • -2% death rate (24 hours)                                 │ ║
║  │  • +1 streak day                                             │ ║
║  │                                                              │ ║
║  │  PROGRESS: 0/1 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░             │ ║
║  │                                                              │ ║
║  └─────────────────────────────────────────────────────────────┘ ║
║                                                                   ║
║  TIME REMAINING: 14:32:17                                         ║
║                                                                   ║
║  [ GO TO TRACE EVASION ]                      [ CLOSE ]          ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Streak Calendar

```
╔══════════════════════════════════════════════════════════════════╗
║                      STREAK CALENDAR                              ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  JANUARY 2026                                                     ║
║  ─────────────────────────────────────────────────────────       ║
║  Mon   Tue   Wed   Thu   Fri   Sat   Sun                         ║
║                     1     2     3     4     5                    ║
║                    ○     ○     ○     ○     ○                     ║
║                                                                   ║
║   6     7     8     9    10    11    12                          ║
║   ○     ○     ○     ✓     ✓     ✓     ✓                          ║
║                                                                   ║
║  13    14    15    16    17    18    19                          ║
║   ✓     ✓     ✓     ✓     ✓     ✓     ✓                          ║
║                                                                   ║
║  20    21    22    23    24    25    26                          ║
║   ✓     ●     ○     ○     ○     ○     ○                          ║
║        ↑                                                          ║
║      TODAY                                                        ║
║                                                                   ║
║  ✓ = Completed    ○ = Incomplete    ● = Today (pending)          ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  CURRENT STREAK: 12 days 🔥                                       ║
║  LONGEST STREAK: 12 days                                          ║
║  TOTAL COMPLETED: 89 missions                                     ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Economic Model

### Reward Budget

Daily Ops rewards are funded from the protocol treasury:

```
DAILY OPS ECONOMICS
───────────────────

Daily Mission Rewards (avg): ~50 $DATA per player
Weekly Bonus: 500-1000 $DATA per player
Streak Bonuses: Variable

Assuming 1,000 daily active players:
├── Daily: 50,000 $DATA distributed
├── Weekly: ~500,000 $DATA distributed
├── Monthly: ~2,500,000 $DATA distributed

Offset by:
├── Streak Shield purchases (burned)
├── Increased engagement → more game fees
├── Retention → lifetime value increase
```

### ROI Analysis

```
Player completes 30-day streak:
├── Daily rewards: ~1,500 $DATA
├── Weekly bonuses: ~2,000 $DATA
├── 30-day bonus: 5,000 $DATA
├── TOTAL: ~8,500 $DATA

Player engagement over 30 days:
├── Avg 2 Hack Runs/day: 60 entries × 100 = 6,000 $DATA burned
├── Avg 1 Dead Pool bet/day: 30 bets × 50 = 1,500 $DATA (5% rake = 75)
├── Position yield contribution: Variable
├── Increased session time → more core game engagement

NET: Positive ROI through engagement increase
```

---

## Technical Implementation

### Database Schema

```sql
CREATE TABLE daily_missions (
  id UUID PRIMARY KEY,
  mission_date DATE NOT NULL,
  mission_type VARCHAR(50) NOT NULL,
  mission_config JSONB NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE player_mission_progress (
  player_address VARCHAR(42) NOT NULL,
  mission_date DATE NOT NULL,
  mission_id UUID REFERENCES daily_missions(id),
  status VARCHAR(20) DEFAULT 'pending', -- pending, completed, expired
  completed_at TIMESTAMP,
  reward_claimed BOOLEAN DEFAULT FALSE,
  PRIMARY KEY (player_address, mission_date)
);

CREATE TABLE player_streaks (
  player_address VARCHAR(42) PRIMARY KEY,
  current_streak INTEGER DEFAULT 0,
  longest_streak INTEGER DEFAULT 0,
  last_completed_date DATE,
  shield_expiry TIMESTAMP,
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Mission Completion Detection

```typescript
// Listen for game events and check mission completion
class MissionTracker {
  async onGameEvent(event: GameEvent) {
    const mission = await this.getTodaysMission(event.playerAddress);
    if (!mission || mission.status !== 'pending') return;
    
    const completed = this.checkCompletion(mission, event);
    
    if (completed) {
      await this.completeMission(event.playerAddress, mission);
    }
  }
  
  private checkCompletion(mission: Mission, event: GameEvent): boolean {
    switch (mission.type) {
      case 'typing':
        return event.type === 'TRACE_EVASION_COMPLETE' &&
               this.meetsTypingRequirement(event, mission.requirement);
               
      case 'hackrun':
        return event.type === 'HACKRUN_COMPLETE' &&
               this.meetsHackrunRequirement(event, mission.requirement);
               
      case 'survival':
        return event.type === 'SURVIVED_SCAN' &&
               this.meetsSurvivalRequirement(event, mission.requirement);
               
      // ... other types
    }
  }
  
  private async completeMission(address: string, mission: Mission) {
    // Update database
    await db.query(`
      UPDATE player_mission_progress 
      SET status = 'completed', completed_at = NOW()
      WHERE player_address = $1 AND mission_date = CURRENT_DATE
    `, [address]);
    
    // Update streak
    await this.updateStreak(address);
    
    // Distribute rewards
    await this.distributeRewards(address, mission.reward);
    
    // Emit event for feed
    this.emitFeedEvent({
      type: 'DAILY_OPS_COMPLETE',
      address,
      missionName: mission.name,
      streak: await this.getCurrentStreak(address)
    });
  }
}
```

### Smart Contract (Rewards)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

contract DailyOps {
    struct PlayerStreak {
        uint256 currentStreak;
        uint256 longestStreak;
        uint256 lastClaimTimestamp;
        uint256 shieldExpiry;
    }
    
    mapping(address => PlayerStreak) public streaks;
    
    uint256 public constant STREAK_3_BONUS = 300;   // 3% death reduction
    uint256 public constant STREAK_7_BONUS = 500;   // 5% death reduction  
    uint256 public constant STREAK_14_BONUS = 500;  // +5% death reduction
    
    // Called by oracle when mission complete
    function claimDailyReward(
        address player,
        uint256 rewardAmount
    ) external onlyOracle {
        PlayerStreak storage streak = streaks[player];
        
        uint256 lastClaim = streak.lastClaimTimestamp;
        uint256 today = block.timestamp / 1 days;
        uint256 lastDay = lastClaim / 1 days;
        
        // Check if consecutive day (or shield active)
        if (lastDay == today - 1 || streak.shieldExpiry > block.timestamp) {
            streak.currentStreak++;
        } else if (lastDay != today) {
            streak.currentStreak = 1;
        }
        
        streak.lastClaimTimestamp = block.timestamp;
        
        if (streak.currentStreak > streak.longestStreak) {
            streak.longestStreak = streak.currentStreak;
        }
        
        // Check milestone bonuses
        _checkMilestoneBonus(player, streak.currentStreak);
        
        // Transfer base reward
        dataToken.transfer(player, rewardAmount);
        
        emit DailyRewardClaimed(player, rewardAmount, streak.currentStreak);
    }
    
    function getDeathRateReduction(address player) external view returns (uint256) {
        PlayerStreak storage streak = streaks[player];
        uint256 reduction = 0;
        
        if (streak.currentStreak >= 3) reduction += STREAK_3_BONUS;
        if (streak.currentStreak >= 14) reduction += STREAK_14_BONUS;
        // ... etc
        
        return reduction; // In basis points
    }
}
```

---

## Feed Integration

```
> 0x7a3f completed DAILY OPS: SPEED DEMON [12 day streak 🔥]
> 0x9c2d reached 30-DAY STREAK - DEDICATED OPERATOR badge earned! 🏆
> 0x3b1a used STREAK SHIELD - Streak protected for 24h 🛡️
> ⚠️ DAILY RESET in 00:30:00 - Complete your mission! ⚠️
```

---

## Notifications

### Push Notifications

```typescript
const notifications = {
  missionAvailable: {
    title: "DAILY OPS READY",
    body: "New mission available: {missionName}",
    timing: "00:00 UTC"
  },
  
  streakReminder: {
    title: "STREAK IN DANGER",
    body: "Complete your mission in {timeRemaining} or lose your {streak} day streak!",
    timing: "2 hours before reset"
  },
  
  streakMilestone: {
    title: "STREAK MILESTONE! 🔥",
    body: "You've reached a {days} day streak! Claim your bonus.",
    timing: "On achievement"
  },
  
  streakLost: {
    title: "STREAK BROKEN",
    body: "Your {days} day streak has ended. Start again today.",
    timing: "After reset with incomplete mission"
  }
};
```

---

## Testing Checklist

- [ ] Mission generation at UTC midnight
- [ ] Mission variety (no repeats 3 days in a row)
- [ ] Completion detection for all mission types
- [ ] Streak increment on completion
- [ ] Streak break on missed day
- [ ] Shield protection works
- [ ] Milestone rewards distributed
- [ ] Death rate reduction applied correctly
- [ ] Weekly bonus calculation
- [ ] Calendar display accuracy
- [ ] Time zone handling
- [ ] Notification timing
- [ ] Feed events emitted
