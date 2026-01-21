# PROXY WAR

## Game Design Document

**Category:** Team PvP / Strategy  
**Phase:** 3C (Deep Engagement)  
**Complexity:** High  
**Development Time:** 3 weeks  

---

## Overview

PROXY WAR is a crew vs crew territory control game where teams stake $DATA to capture and defend network nodes. Territories generate passive yield for controlling crews. Attack and defend through coordinated mini-game battles. Losing crew loses their entire stake to the victors.

```
╔══════════════════════════════════════════════════════════════════╗
║                         PROXY WAR                                 ║
║              TERRITORY CONTROL NETWORK MAP                        ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║     [ALPHA-7]────[BETA-3]────[GAMMA-9]                           ║
║         │            │            │                               ║
║         │       ┌────┴────┐       │                               ║
║         │       │         │       │                               ║
║     [CORE-1]──[NEXUS-0]──[CORE-2]──[DELTA-4]                     ║
║         │       │    ▲    │       │                               ║
║         │       └────┼────┘       │                               ║
║         │            │            │                               ║
║     [EDGE-5]────[NODE-6]────[EDGE-8]                             ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  YOUR CREW: SHADOW_COLLECTIVE      TERRITORIES: 4                 ║
║  CONTROLLED: NEXUS-0, CORE-1, ALPHA-7, EDGE-5                    ║
║  YIELD: +847 $DATA/hour            MEMBERS ONLINE: 5/8           ║
║                                                                   ║
║  ⚠ INCOMING ATTACK: CORE-1 by VOID_RUNNERS in 02:34             ║
║                                                                   ║
║          [ WAR ROOM ]    [ DEFEND ]    [ ATTACK ]                ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Core Mechanics

### Territory System

```
TERRITORY TYPES:
════════════════════════════════════════════════════════════════════

NEXUS (1 per map)           ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
├── Central node            ██████████████████████████████████████
├── 3x yield multiplier     YIELD: 300 $DATA/hr │ DEFENSE: +25%
├── +25% crew defense       CONTROL: Requires 3+ adjacent territories
└── Strategic chokepoint    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

CORE (2-3 per map)          ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
├── High-value nodes        ██████████████████████████████████████
├── 2x yield multiplier     YIELD: 200 $DATA/hr │ DEFENSE: +15%
├── +15% crew defense       CONTROL: Standard capture
└── Key strategic points    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

STANDARD (4-6 per map)      ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
├── Normal nodes            ██████████████████████████████████████
├── 1x yield                YIELD: 100 $DATA/hr │ DEFENSE: +0%
└── Expansion points        ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

EDGE (3-4 per map)          ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
├── Border nodes            ██████████████████████████████████████
├── 0.5x yield              YIELD: 50 $DATA/hr │ ATTACK: +10%
├── +10% attack bonus       CONTROL: Entry points for new crews
└── Entry points            ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
```

### Game Flow

```
1. CREW FORMATION
   └── 3-8 players form a crew
   └── Each member stakes 500 $DATA (entry)
   └── Crew funds pooled for war chest
   └── Elect War Commander (strategic decisions)

2. TERRITORY CLAIM
   └── Crew claims starting territory (EDGE node)
   └── Must stake crew minimum (1,500 $DATA)
   └── Territory begins generating yield

3. EXPANSION PHASE
   └── Attack adjacent neutral or enemy territories
   └── Declare attack (5-minute warning)
   └── Both sides rally defenders

4. BATTLE PHASE
   └── Combined mini-game scores determine winner
   └── All participating members play
   └── Attackers need 55% combined score to win

5. RESOLUTION
   └── Winner takes territory
   └── Loser's stake burns entirely
   └── Yield redistributes to new owner

6. DOMINATION (Win Condition)
   └── Control NEXUS + 5 territories = Victory
   └── Losing crews eliminated, stakes distributed
```

### Battle System

Battles are resolved through combined crew performance in mini-games:

```
BATTLE TYPES:
════════════════════════════════════════════════════════════════════

SIEGE (Default Attack)
├── Duration: 3 minutes
├── Games: TRACE EVASION (typing)
├── Win Condition: Combined crew WPM > Defenders
├── Attacker Threshold: 55% (attackers need edge)
└── Participants: Up to 5 per side

BLITZ (Quick Strike)
├── Duration: 1 minute
├── Games: ICE BREAKER (reaction time)
├── Win Condition: Combined reaction score
├── Attacker Threshold: 52%
└── Participants: Up to 3 per side

HACK WAR (Strategic)
├── Duration: 5 minutes
├── Games: CODE DUEL chain (sequential 1v1s)
├── Win Condition: Best of 5 individual duels
├── Each duel winner scores 1 point
└── Participants: 5 designated champions

SABOTAGE (Stealth Attack)
├── Duration: 2 minutes
├── Games: Pattern recognition
├── Win Condition: First to decode sequence
├── Only 1 attacker vs 1 defender
└── High risk, high reward
```

### Crew Coordination

```
WAR ROOM COMMANDS:
════════════════════════════════════════════════════════════════════

/rally [territory]     - Call crew to defend
/attack [territory]    - Declare attack (requires commander)
/scout [crew]          - View enemy crew stats
/fortify [territory]   - Boost defense (+10%, costs 100 $DATA)
/retreat               - Abandon territory (save 50% stake)
/alliance [crew]       - Propose non-aggression pact
/war [crew]            - Declare total war (3x rewards, 3x risk)
```

---

## User Interface

### States

**1. War Room (Crew HQ)**
```
╔══════════════════════════════════════════════════════════════════╗
║  PROXY WAR                           SHADOW_COLLECTIVE HQ        ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  WAR CHEST: 4,250 $DATA              YIELD: +847 $DATA/hr        ║
║  TERRITORIES: 4/12                   CREW RANK: #3                ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  CREW ROSTER                         STATUS                       ║
║  ────────────                        ──────                       ║
║  ★ 0x7a3f (Commander)                ONLINE  │ NEXUS-0           ║
║    0x9c2d                            ONLINE  │ CORE-1            ║
║    0x3b1a                            ONLINE  │ ALPHA-7           ║
║    0x8f2e                            AWAY    │ ---               ║
║    0x1d4c                            ONLINE  │ EDGE-5            ║
║    0x4b8e                            OFFLINE │ ---               ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  RECENT ACTIVITY                                                  ║
║  ───────────────                                                  ║
║  > [02:15] CORE-1 fortified (+10% DEF) -100 $DATA                ║
║  > [01:47] Yield collected: +423 $DATA                           ║
║  > [00:32] VOID_RUNNERS scouted our territory                    ║
║  > [00:05] 0x9c2d deployed to CORE-1                             ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  [ VIEW MAP ]   [ ATTACK ]   [ SCOUT ]   [ CREW CHAT ]          ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**2. Territory Map (Strategic View)**
```
╔══════════════════════════════════════════════════════════════════╗
║  PROXY WAR                                      SECTOR: OMEGA-7  ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║                    THE NETWORK                                    ║
║                                                                   ║
║     ┌─────┐      ┌─────┐      ┌─────┐                           ║
║     │░░░░░│──────│▓▓▓▓▓│──────│░░░░░│                           ║
║     │A-7  │      │B-3  │      │G-9  │                           ║
║     │ YOU │      │VOID │      │NEUT │                           ║
║     └──┬──┘      └──┬──┘      └──┬──┘                           ║
║        │            │            │                               ║
║     ┌──┴──┐      ┌──┴──┐      ┌──┴──┐      ┌─────┐             ║
║     │░░░░░│──────│█████│──────│▓▓▓▓▓│──────│▓▓▓▓▓│             ║
║     │C-1  │      │NEX-0│      │C-2  │      │D-4  │             ║
║     │ YOU │      │ YOU │      │VOID │      │VOID │             ║
║     └──┬──┘      └──┬──┘      └──┬──┘      └──┬──┘             ║
║        │            │            │            │                  ║
║     ┌──┴──┐      ┌──┴──┐      ┌──┴──┐                           ║
║     │░░░░░│──────│     │──────│▓▓▓▓▓│                           ║
║     │E-5  │      │N-6  │      │E-8  │                           ║
║     │ YOU │      │NEUT │      │VOID │                           ║
║     └─────┘      └─────┘      └─────┘                           ║
║                                                                   ║
║  LEGEND: ░░░ YOU  ▓▓▓ ENEMY  ███ NEXUS  [ ] NEUTRAL             ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  SELECT TERRITORY:  [C-1 selected]                               ║
║  TYPE: CORE         YIELD: 200/hr      DEFENSE: +15%            ║
║  STAKE: 750 $DATA   ADJACENT: NEX-0, A-7, E-5                   ║
║                                                                   ║
║  [ FORTIFY -100 ]   [ DEPLOY HERE ]   [ ATTACK ADJACENT ]       ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**3. Attack Declaration**
```
╔══════════════════════════════════════════════════════════════════╗
║                    ⚔ DECLARE ATTACK ⚔                            ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  TARGET: BETA-3                                                   ║
║  CONTROLLED BY: VOID_RUNNERS                                      ║
║  TERRITORY TYPE: STANDARD                                         ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  ENEMY INTEL (from scout):                                        ║
║  ├── Crew Size: 6 members                                        ║
║  ├── Online Now: 4 members                                       ║
║  ├── Avg WPM: 67                                                 ║
║  ├── Defense Bonus: +0%                                          ║
║  └── Stake on Territory: 600 $DATA                               ║
║                                                                   ║
║  YOUR FORCES:                                                     ║
║  ├── Available Attackers: 5 members                              ║
║  ├── Your Avg WPM: 78                                            ║
║  ├── Attack Bonus: +0%                                           ║
║  └── Required Stake: 600 $DATA (matched)                         ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  BATTLE TYPE:                                                     ║
║  [ SIEGE ]    [ BLITZ ]    [ HACK WAR ]    [ SABOTAGE ]         ║
║    3 min       1 min        5 min           2 min                ║
║   55% req     52% req      Best of 5       1v1 code             ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  WARNING: Attack begins in 5 minutes after declaration.          ║
║  Enemy will be notified. Ensure your crew is ready.             ║
║                                                                   ║
║  COMMIT STAKE: 600 $DATA from war chest                         ║
║                                                                   ║
║            [ DECLARE ATTACK ]        [ CANCEL ]                   ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**4. Battle View (Active Combat)**
```
╔══════════════════════════════════════════════════════════════════╗
║  ⚔ SIEGE BATTLE ⚔                      TERRITORY: BETA-3        ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  SHADOW_COLLECTIVE         vs         VOID_RUNNERS               ║
║      ATTACKERS                          DEFENDERS                 ║
║                                                                   ║
║  ████████████████████░░░░░░░░░░░░░░░░░████████████████████       ║
║          58%                                    52%               ║
║                                                                   ║
║  ATTACKERS NEED: 55%                TIME: 01:47                  ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  YOUR TEAM                           ENEMY TEAM                   ║
║  ─────────                           ──────────                   ║
║  0x7a3f  89 WPM  ████████████░░     0xf2a1  71 WPM  ████████░░░ ║
║  0x9c2d  82 WPM  ██████████░░░░     0xc3b2  68 WPM  ███████░░░░ ║
║  0x3b1a  76 WPM  █████████░░░░░     0xd4e3  65 WPM  ██████░░░░░ ║
║  0x1d4c  71 WPM  ████████░░░░░░     0xe5f4  74 WPM  ████████░░░ ║
║                                      0xa6b5  62 WPM  █████░░░░░░ ║
║                                                                   ║
║  ═══════════════════════════════════════════════════════════════ ║
║                                                                   ║
║  TYPE:                                                            ║
║  tar -xzvf payload.tar.gz && ./install.sh --silent              ║
║  ─────────────────────────────────────────────────────────────── ║
║  tar -xzvf payload.tar.gz && ./inst█                             ║
║                                                                   ║
║  ═══════════════════════════════════════════════════════════════ ║
║                                                                   ║
║  SPECTATOR BETS: SHADOW 62% │ VOID 38%        POOL: 2,450 $DATA ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**5. Victory Screen**
```
╔══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║  ████████╗███████╗██████╗ ██████╗ ██╗████████╗ ██████╗ ██████╗   ║
║  ╚══██╔══╝██╔════╝██╔══██╗██╔══██╗██║╚══██╔══╝██╔═══██╗██╔══██╗  ║
║     ██║   █████╗  ██████╔╝██████╔╝██║   ██║   ██║   ██║██████╔╝  ║
║     ██║   ██╔══╝  ██╔══██╗██╔══██╗██║   ██║   ██║   ██║██╔══██╗  ║
║     ██║   ███████╗██║  ██║██║  ██║██║   ██║   ╚██████╔╝██║  ██║  ║
║     ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝  ║
║                       ██████╗ ██████╗ ███╗   ██╗ ██████╗ ██╗   ██║
║                      ██╔════╝██╔═══██╗████╗  ██║██╔═══██╗██║   ██║
║                      ██║     ██║   ██║██╔██╗ ██║██║   ██║██║   ██║
║                      ██║     ██║   ██║██║╚██╗██║██║▄▄ ██║██║   ██║
║                      ╚██████╗╚██████╔╝██║ ╚████║╚██████╔╝╚██████╔║
║                       ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝ ╚══▀▀═╝  ╚═════╝║
║                                                                   ║
║                    SHADOW_COLLECTIVE                              ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  BATTLE STATS                         REWARDS                     ║
║  ────────────                         ───────                     ║
║  Your Score: 58%                      Territory: BETA-3           ║
║  Enemy Score: 52%                     Enemy Stake: +600 $DATA     ║
║  Battle Time: 2:47                    New Yield: +100 $DATA/hr   ║
║  MVP: 0x7a3f (89 WPM)                                            ║
║                                                                   ║
║  VOID_RUNNERS stake BURNED: 600 $DATA                            ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  TERRITORY OVERVIEW                                               ║
║  ──────────────────                                               ║
║  Total Controlled: 5/12                                           ║
║  Total Yield: +947 $DATA/hr                                      ║
║  War Chest: 4,850 $DATA (+600)                                   ║
║                                                                   ║
║              [ RETURN TO MAP ]        [ VIEW REPLAY ]             ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**6. Defeat Screen**
```
╔══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║     ████████╗██████╗  █████╗  ██████╗███████╗██████╗              ║
║     ╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██╔════╝██╔══██╗             ║
║        ██║   ██████╔╝███████║██║     █████╗  ██║  ██║             ║
║        ██║   ██╔══██╗██╔══██║██║     ██╔══╝  ██║  ██║             ║
║        ██║   ██║  ██║██║  ██║╚██████╗███████╗██████╔╝             ║
║        ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝╚═════╝              ║
║                                                                   ║
║                  TERRITORY LOST: CORE-1                          ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  BATTLE STATS                         LOSSES                      ║
║  ────────────                         ──────                      ║
║  Your Score: 48%                      Territory: CORE-1           ║
║  Enemy Score: 54%                     Stake Lost: 750 $DATA       ║
║  Battle Time: 3:00 (timeout)          Yield Lost: -200 $DATA/hr  ║
║  Top Defender: 0x9c2d (76 WPM)                                   ║
║                                                                   ║
║  YOUR STAKE BURNED: 750 $DATA                                    ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  TERRITORY OVERVIEW                                               ║
║  ──────────────────                                               ║
║  Total Controlled: 3/12                                           ║
║  Total Yield: +650 $DATA/hr                                      ║
║  War Chest: 3,500 $DATA (-750)                                   ║
║                                                                   ║
║  ⚠ WARNING: NEXUS-0 is now vulnerable without CORE-1 buffer     ║
║                                                                   ║
║         [ RETURN TO MAP ]    [ RALLY DEFENSE ]                   ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**7. Crew Creation**
```
╔══════════════════════════════════════════════════════════════════╗
║                      CREATE NEW CREW                              ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  CREW NAME: [SHADOW_COLLECTIVE_____]                             ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  ENTRY STAKE: 500 $DATA per member                               ║
║  MINIMUM MEMBERS: 3                                               ║
║  MAXIMUM MEMBERS: 8                                               ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  FOUNDING MEMBERS:                                                ║
║                                                                   ║
║  1. 0x7a3f (you)              ★ Commander                        ║
║  2. [0x________________]      Invite sent...                     ║
║  3. [0x________________]      Pending...                         ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  CREW RULES:                                                      ║
║  • Commander makes strategic decisions                            ║
║  • Yield splits equally among active members                     ║
║  • Members can leave (forfeit stake)                             ║
║  • Kicked members forfeit stake to crew                          ║
║  • Crew dissolves if < 3 members                                 ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  TOTAL FOUNDING STAKE: 1,500 $DATA (3 x 500)                     ║
║                                                                   ║
║           [ CREATE CREW ]        [ CANCEL ]                       ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Economic Model

### Entry & Stakes

| Parameter | Value |
|-----------|-------|
| Entry Stake | 500 $DATA per member |
| Minimum Crew Size | 3 members |
| Maximum Crew Size | 8 members |
| Minimum Crew Stake | 1,500 $DATA |
| Maximum Crew Stake | 4,000 $DATA |
| Territory Capture Stake | Match defender's stake |

### Yield Generation

| Territory Type | Hourly Yield | Multiplier |
|----------------|--------------|------------|
| EDGE | 50 $DATA | 0.5x |
| STANDARD | 100 $DATA | 1x |
| CORE | 200 $DATA | 2x |
| NEXUS | 300 $DATA | 3x |

### Battle Economics

**Attack Costs:**
```
ATTACK STAKE:
├── Must match defender's stake on territory
├── Attacker commits from war chest
├── If win: Gain territory + defender stake burns
├── If lose: Attacker stake burns entirely

FORTIFICATION:
├── Cost: 100 $DATA
├── Effect: +10% defense for 24 hours
├── Stacks up to 3x (+30% max)
├── Lost if territory captured

SCOUT:
├── Cost: 25 $DATA
├── Reveals enemy crew stats for 1 hour
└── Burns on use
```

**Payout Distribution:**

```
VICTORY:
├── Defender's stake: 100% BURNED
├── Territory control: Transfers to winner
├── Yield rights: Transfers to winner
└── War chest: Gains from future yield

DEFEAT:
├── Attacker's stake: 100% BURNED
├── Territory control: Unchanged
├── Yield rights: Unchanged
└── War chest: Loses committed stake

SPECTATOR BETS:
├── Winning side: Split pool (minus 5% rake)
├── Rake: 100% BURNED
└── No house take
```

### Domination Victory

When a crew achieves domination (NEXUS + 5 territories):

```
DOMINATION REWARDS:
═══════════════════════════════════════════════════════════════════

1. All enemy crews ELIMINATED
   └── Their remaining stakes: 50% to victors, 50% burned

2. Map RESETS after 24 hours
   └── All territories become neutral
   └── Winning crew keeps earned $DATA
   └── New season begins

3. Victory NFT minted
   └── Records crew name, members, date
   └── Permanent on-chain achievement
```

---

## Technical Implementation

### Smart Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title ProxyWarTerritory
/// @notice Crew vs Crew territory control battles for GHOSTNET
contract ProxyWarTerritory is ReentrancyGuard, Ownable2Step {
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════════
    // TYPES
    // ═══════════════════════════════════════════════════════════════════

    enum TerritoryType { EDGE, STANDARD, CORE, NEXUS }
    enum BattleType { SIEGE, BLITZ, HACK_WAR, SABOTAGE }
    enum BattleState { NONE, DECLARED, ACTIVE, RESOLVED }
    enum CrewState { ACTIVE, DISBANDED, ELIMINATED }

    struct Territory {
        uint8 id;
        TerritoryType territoryType;
        uint256 controllingCrew;      // 0 = neutral
        uint256 stakedAmount;
        uint256 fortificationExpiry;
        uint8 fortificationLevel;     // 0-3
        uint8[] adjacentTerritories;
    }

    struct Crew {
        uint256 id;
        bytes32 name;
        address commander;
        address[] members;
        uint256 warChest;
        uint256 totalYieldEarned;
        uint256[] controlledTerritories;
        CrewState state;
        uint256 createdAt;
    }

    struct Battle {
        uint256 id;
        uint256 attackingCrew;
        uint256 defendingCrew;
        uint8 territoryId;
        BattleType battleType;
        BattleState state;
        uint256 attackerStake;
        uint256 defenderStake;
        uint256 declaredAt;
        uint256 startsAt;
        uint256 endsAt;
        uint256 attackerScore;
        uint256 defenderScore;
        uint256 spectatorPoolAttacker;
        uint256 spectatorPoolDefender;
    }

    struct SpectatorBet {
        uint256 amount;
        bool onAttacker;
        bool claimed;
    }

    // ═══════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════════

    uint256 public constant ENTRY_STAKE = 500 ether;           // 500 $DATA per member
    uint256 public constant MIN_CREW_SIZE = 3;
    uint256 public constant MAX_CREW_SIZE = 8;
    uint256 public constant FORTIFY_COST = 100 ether;
    uint256 public constant SCOUT_COST = 25 ether;
    uint256 public constant ATTACK_DELAY = 5 minutes;
    uint256 public constant FORTIFY_DURATION = 24 hours;
    uint256 public constant SPECTATOR_RAKE_BPS = 500;          // 5%
    uint256 public constant DOMINATION_THRESHOLD = 6;          // NEXUS + 5

    // Battle thresholds (basis points, 10000 = 100%)
    uint256 public constant SIEGE_THRESHOLD = 5500;            // 55%
    uint256 public constant BLITZ_THRESHOLD = 5200;            // 52%

    // Yield per hour in basis points of 100 $DATA
    uint256 public constant EDGE_YIELD_BPS = 5000;             // 50 $DATA
    uint256 public constant STANDARD_YIELD_BPS = 10000;        // 100 $DATA
    uint256 public constant CORE_YIELD_BPS = 20000;            // 200 $DATA
    uint256 public constant NEXUS_YIELD_BPS = 30000;           // 300 $DATA

    // ═══════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════

    IERC20 public immutable dataToken;
    address public oracle;

    uint256 public crewCounter;
    uint256 public battleCounter;
    uint256 public currentSeason;

    mapping(uint256 => Crew) public crews;
    mapping(address => uint256) public memberToCrew;
    mapping(uint8 => Territory) public territories;
    mapping(uint256 => Battle) public battles;
    mapping(uint256 => mapping(address => SpectatorBet)) public spectatorBets;
    mapping(uint256 => uint256) public lastYieldClaim;         // crewId => timestamp

    // ═══════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════

    event CrewCreated(uint256 indexed crewId, bytes32 name, address commander);
    event MemberJoined(uint256 indexed crewId, address member);
    event MemberLeft(uint256 indexed crewId, address member, uint256 forfeitedStake);
    event TerritoryCapture(uint256 indexed crewId, uint8 territoryId, uint256 stake);
    event BattleDeclared(uint256 indexed battleId, uint256 attacker, uint256 defender, uint8 territory);
    event BattleStarted(uint256 indexed battleId);
    event BattleResolved(uint256 indexed battleId, uint256 winner, uint256 loserStakeBurned);
    event YieldClaimed(uint256 indexed crewId, uint256 amount);
    event TerritoryFortified(uint8 indexed territoryId, uint256 crewId, uint8 level);
    event SpectatorBetPlaced(uint256 indexed battleId, address bettor, bool onAttacker, uint256 amount);
    event DominationVictory(uint256 indexed crewId, uint256 season);
    event StakeBurned(uint256 amount, string reason);

    // ═══════════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════════

    error InvalidCrewSize();
    error AlreadyInCrew();
    error NotInCrew();
    error NotCommander();
    error InsufficientStake();
    error TerritoryNotAdjacent();
    error TerritoryNotNeutral();
    error TerritoryNotOwned();
    error BattleInProgress();
    error BattleNotActive();
    error InvalidBattleState();
    error BettingClosed();
    error NothingToClaim();
    error CrewEliminated();

    // ═══════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ═══════════════════════════════════════════════════════════════════

    modifier onlyOracle() {
        require(msg.sender == oracle, "Not oracle");
        _;
    }

    modifier onlyCommander(uint256 crewId) {
        if (crews[crewId].commander != msg.sender) revert NotCommander();
        _;
    }

    modifier crewActive(uint256 crewId) {
        if (crews[crewId].state != CrewState.ACTIVE) revert CrewEliminated();
        _;
    }

    // ═══════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════

    constructor(address _dataToken, address _oracle, address _owner) Ownable(_owner) {
        dataToken = IERC20(_dataToken);
        oracle = _oracle;
        currentSeason = 1;
        _initializeTerritories();
    }

    // ═══════════════════════════════════════════════════════════════════
    // CREW MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Create a new crew with founding members
    /// @param name The crew name (32 bytes max)
    /// @param foundingMembers Initial member addresses (including commander)
    function createCrew(
        bytes32 name,
        address[] calldata foundingMembers
    ) external nonReentrant returns (uint256) {
        if (foundingMembers.length < MIN_CREW_SIZE || foundingMembers.length > MAX_CREW_SIZE) {
            revert InvalidCrewSize();
        }

        uint256 totalStake = ENTRY_STAKE * foundingMembers.length;

        // Verify all members and collect stakes
        for (uint256 i = 0; i < foundingMembers.length; i++) {
            if (memberToCrew[foundingMembers[i]] != 0) revert AlreadyInCrew();
        }

        // Transfer stakes from all founding members
        for (uint256 i = 0; i < foundingMembers.length; i++) {
            dataToken.safeTransferFrom(foundingMembers[i], address(this), ENTRY_STAKE);
            memberToCrew[foundingMembers[i]] = crewCounter + 1;
        }

        crewCounter++;
        
        crews[crewCounter] = Crew({
            id: crewCounter,
            name: name,
            commander: foundingMembers[0],
            members: foundingMembers,
            warChest: totalStake,
            totalYieldEarned: 0,
            controlledTerritories: new uint256[](0),
            state: CrewState.ACTIVE,
            createdAt: block.timestamp
        });

        lastYieldClaim[crewCounter] = block.timestamp;

        emit CrewCreated(crewCounter, name, foundingMembers[0]);
        
        return crewCounter;
    }

    /// @notice Join an existing crew (requires commander approval off-chain)
    /// @param crewId The crew to join
    function joinCrew(uint256 crewId) external nonReentrant crewActive(crewId) {
        Crew storage crew = crews[crewId];
        
        if (memberToCrew[msg.sender] != 0) revert AlreadyInCrew();
        if (crew.members.length >= MAX_CREW_SIZE) revert InvalidCrewSize();

        dataToken.safeTransferFrom(msg.sender, address(this), ENTRY_STAKE);
        
        crew.members.push(msg.sender);
        crew.warChest += ENTRY_STAKE;
        memberToCrew[msg.sender] = crewId;

        emit MemberJoined(crewId, msg.sender);
    }

    /// @notice Leave a crew (forfeit stake to crew)
    function leaveCrew() external nonReentrant {
        uint256 crewId = memberToCrew[msg.sender];
        if (crewId == 0) revert NotInCrew();

        Crew storage crew = crews[crewId];
        
        // Remove member from array
        _removeMember(crew, msg.sender);
        memberToCrew[msg.sender] = 0;

        // Stake stays in war chest (forfeited)
        emit MemberLeft(crewId, msg.sender, ENTRY_STAKE);

        // Check if crew should disband
        if (crew.members.length < MIN_CREW_SIZE) {
            _disbandCrew(crewId);
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // TERRITORY CONTROL
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Claim a neutral territory
    /// @param territoryId The territory to claim
    /// @param stake Amount to stake on territory
    function claimTerritory(
        uint8 territoryId,
        uint256 stake
    ) external nonReentrant {
        uint256 crewId = memberToCrew[msg.sender];
        if (crewId == 0) revert NotInCrew();
        
        Crew storage crew = crews[crewId];
        if (crew.state != CrewState.ACTIVE) revert CrewEliminated();
        
        Territory storage territory = territories[territoryId];
        if (territory.controllingCrew != 0) revert TerritoryNotNeutral();
        
        // First territory must be EDGE, subsequent must be adjacent
        if (crew.controlledTerritories.length == 0) {
            require(territory.territoryType == TerritoryType.EDGE, "First territory must be EDGE");
        } else {
            if (!_isAdjacentToOwned(crewId, territoryId)) revert TerritoryNotAdjacent();
        }

        uint256 minStake = _getMinStake(territory.territoryType);
        if (stake < minStake || stake > crew.warChest) revert InsufficientStake();

        crew.warChest -= stake;
        territory.controllingCrew = crewId;
        territory.stakedAmount = stake;
        crew.controlledTerritories.push(territoryId);

        emit TerritoryCapture(crewId, territoryId, stake);
    }

    /// @notice Fortify a controlled territory
    /// @param territoryId The territory to fortify
    function fortifyTerritory(uint8 territoryId) external nonReentrant {
        uint256 crewId = memberToCrew[msg.sender];
        if (crewId == 0) revert NotInCrew();

        Crew storage crew = crews[crewId];
        Territory storage territory = territories[territoryId];

        if (territory.controllingCrew != crewId) revert TerritoryNotOwned();
        if (crew.warChest < FORTIFY_COST) revert InsufficientStake();
        
        require(territory.fortificationLevel < 3, "Max fortification");

        crew.warChest -= FORTIFY_COST;
        territory.fortificationLevel++;
        territory.fortificationExpiry = block.timestamp + FORTIFY_DURATION;

        // Burn fortification cost
        dataToken.safeTransfer(address(0xdead), FORTIFY_COST);
        emit StakeBurned(FORTIFY_COST, "fortification");
        emit TerritoryFortified(territoryId, crewId, territory.fortificationLevel);
    }

    // ═══════════════════════════════════════════════════════════════════
    // BATTLE SYSTEM
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Declare an attack on enemy territory
    /// @param territoryId Target territory
    /// @param battleType Type of battle
    function declareAttack(
        uint8 territoryId,
        BattleType battleType
    ) external nonReentrant returns (uint256) {
        uint256 attackerCrewId = memberToCrew[msg.sender];
        if (attackerCrewId == 0) revert NotInCrew();

        Crew storage attackerCrew = crews[attackerCrewId];
        if (attackerCrew.commander != msg.sender) revert NotCommander();
        if (attackerCrew.state != CrewState.ACTIVE) revert CrewEliminated();

        Territory storage territory = territories[territoryId];
        uint256 defenderCrewId = territory.controllingCrew;
        
        require(defenderCrewId != 0, "Territory is neutral");
        require(defenderCrewId != attackerCrewId, "Cannot attack own territory");
        require(_isAdjacentToOwned(attackerCrewId, territoryId), "Not adjacent");

        // Attacker must match defender's stake
        uint256 requiredStake = territory.stakedAmount;
        if (attackerCrew.warChest < requiredStake) revert InsufficientStake();

        attackerCrew.warChest -= requiredStake;

        battleCounter++;
        battles[battleCounter] = Battle({
            id: battleCounter,
            attackingCrew: attackerCrewId,
            defendingCrew: defenderCrewId,
            territoryId: territoryId,
            battleType: battleType,
            state: BattleState.DECLARED,
            attackerStake: requiredStake,
            defenderStake: territory.stakedAmount,
            declaredAt: block.timestamp,
            startsAt: block.timestamp + ATTACK_DELAY,
            endsAt: 0,
            attackerScore: 0,
            defenderScore: 0,
            spectatorPoolAttacker: 0,
            spectatorPoolDefender: 0
        });

        emit BattleDeclared(battleCounter, attackerCrewId, defenderCrewId, territoryId);
        
        return battleCounter;
    }

    /// @notice Place a spectator bet on a battle outcome
    /// @param battleId The battle to bet on
    /// @param onAttacker True to bet on attacker, false for defender
    /// @param amount Amount to bet
    function placeSpectatorBet(
        uint256 battleId,
        bool onAttacker,
        uint256 amount
    ) external nonReentrant {
        Battle storage battle = battles[battleId];
        
        if (battle.state != BattleState.DECLARED) revert BettingClosed();
        if (block.timestamp >= battle.startsAt) revert BettingClosed();

        dataToken.safeTransferFrom(msg.sender, address(this), amount);

        SpectatorBet storage bet = spectatorBets[battleId][msg.sender];
        require(bet.amount == 0, "Already bet");

        bet.amount = amount;
        bet.onAttacker = onAttacker;

        if (onAttacker) {
            battle.spectatorPoolAttacker += amount;
        } else {
            battle.spectatorPoolDefender += amount;
        }

        emit SpectatorBetPlaced(battleId, msg.sender, onAttacker, amount);
    }

    /// @notice Start a battle (called by oracle when timer expires)
    /// @param battleId The battle to start
    function startBattle(uint256 battleId) external onlyOracle {
        Battle storage battle = battles[battleId];
        
        require(battle.state == BattleState.DECLARED, "Invalid state");
        require(block.timestamp >= battle.startsAt, "Too early");

        battle.state = BattleState.ACTIVE;
        emit BattleStarted(battleId);
    }

    /// @notice Resolve a battle with final scores (called by oracle)
    /// @param battleId The battle to resolve
    /// @param attackerScore Attacker's combined score (basis points)
    /// @param defenderScore Defender's combined score (basis points)
    function resolveBattle(
        uint256 battleId,
        uint256 attackerScore,
        uint256 defenderScore
    ) external onlyOracle nonReentrant {
        Battle storage battle = battles[battleId];
        
        if (battle.state != BattleState.ACTIVE) revert BattleNotActive();

        battle.attackerScore = attackerScore;
        battle.defenderScore = defenderScore;
        battle.state = BattleState.RESOLVED;
        battle.endsAt = block.timestamp;

        uint256 threshold = _getBattleThreshold(battle.battleType);
        uint256 totalScore = attackerScore + defenderScore;
        uint256 attackerPercentage = (attackerScore * 10000) / totalScore;

        bool attackerWins = attackerPercentage >= threshold;

        Territory storage territory = territories[battle.territoryId];
        Crew storage attackerCrew = crews[battle.attackingCrew];
        Crew storage defenderCrew = crews[battle.defendingCrew];

        uint256 burnedStake;

        if (attackerWins) {
            // Attacker wins: defender stake burns, territory transfers
            burnedStake = battle.defenderStake;
            
            // Transfer territory
            _removeFromArray(defenderCrew.controlledTerritories, battle.territoryId);
            attackerCrew.controlledTerritories.push(battle.territoryId);
            
            territory.controllingCrew = battle.attackingCrew;
            territory.stakedAmount = battle.attackerStake;
            territory.fortificationLevel = 0;
            territory.fortificationExpiry = 0;

            // Check for domination
            if (_checkDomination(battle.attackingCrew)) {
                _handleDomination(battle.attackingCrew);
            }
        } else {
            // Defender wins: attacker stake burns
            burnedStake = battle.attackerStake;
        }

        // Burn losing stake
        dataToken.safeTransfer(address(0xdead), burnedStake);
        emit StakeBurned(burnedStake, "battle_loss");

        // Handle spectator payouts
        _settleSpectatorBets(battleId, attackerWins);

        emit BattleResolved(battleId, attackerWins ? battle.attackingCrew : battle.defendingCrew, burnedStake);
    }

    // ═══════════════════════════════════════════════════════════════════
    // YIELD SYSTEM
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Claim accumulated yield for crew
    /// @param crewId The crew claiming yield
    function claimYield(uint256 crewId) external nonReentrant crewActive(crewId) {
        Crew storage crew = crews[crewId];
        require(memberToCrew[msg.sender] == crewId, "Not in crew");

        uint256 pendingYield = calculatePendingYield(crewId);
        if (pendingYield == 0) revert NothingToClaim();

        lastYieldClaim[crewId] = block.timestamp;
        crew.warChest += pendingYield;
        crew.totalYieldEarned += pendingYield;

        emit YieldClaimed(crewId, pendingYield);
    }

    /// @notice Calculate pending yield for a crew
    /// @param crewId The crew to calculate for
    function calculatePendingYield(uint256 crewId) public view returns (uint256) {
        Crew storage crew = crews[crewId];
        if (crew.state != CrewState.ACTIVE) return 0;

        uint256 hoursSinceClaim = (block.timestamp - lastYieldClaim[crewId]) / 1 hours;
        if (hoursSinceClaim == 0) return 0;

        uint256 totalYield = 0;
        for (uint256 i = 0; i < crew.controlledTerritories.length; i++) {
            Territory storage territory = territories[uint8(crew.controlledTerritories[i])];
            uint256 baseYield = _getTerritoryYield(territory.territoryType);
            totalYield += baseYield * hoursSinceClaim;
        }

        return totalYield;
    }

    // ═══════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    function _initializeTerritories() internal {
        // Initialize 12 territories with adjacency graph
        // NEXUS-0 (center)
        territories[0] = Territory({
            id: 0,
            territoryType: TerritoryType.NEXUS,
            controllingCrew: 0,
            stakedAmount: 0,
            fortificationExpiry: 0,
            fortificationLevel: 0,
            adjacentTerritories: new uint8[](4)
        });
        territories[0].adjacentTerritories[0] = 1; // CORE-1
        territories[0].adjacentTerritories[1] = 2; // CORE-2
        territories[0].adjacentTerritories[2] = 6; // NODE-6
        territories[0].adjacentTerritories[3] = 3; // BETA-3

        // Additional territories initialized similarly...
        // (Simplified for contract size)
    }

    function _getBattleThreshold(BattleType battleType) internal pure returns (uint256) {
        if (battleType == BattleType.SIEGE) return SIEGE_THRESHOLD;
        if (battleType == BattleType.BLITZ) return BLITZ_THRESHOLD;
        return 5000; // 50% for others
    }

    function _getTerritoryYield(TerritoryType t) internal pure returns (uint256) {
        if (t == TerritoryType.EDGE) return 50 ether;
        if (t == TerritoryType.STANDARD) return 100 ether;
        if (t == TerritoryType.CORE) return 200 ether;
        return 300 ether; // NEXUS
    }

    function _getMinStake(TerritoryType t) internal pure returns (uint256) {
        if (t == TerritoryType.EDGE) return 300 ether;
        if (t == TerritoryType.STANDARD) return 500 ether;
        if (t == TerritoryType.CORE) return 750 ether;
        return 1000 ether; // NEXUS
    }

    function _isAdjacentToOwned(uint256 crewId, uint8 territoryId) internal view returns (bool) {
        Crew storage crew = crews[crewId];
        Territory storage target = territories[territoryId];
        
        for (uint256 i = 0; i < target.adjacentTerritories.length; i++) {
            uint8 adjId = target.adjacentTerritories[i];
            for (uint256 j = 0; j < crew.controlledTerritories.length; j++) {
                if (crew.controlledTerritories[j] == adjId) {
                    return true;
                }
            }
        }
        return false;
    }

    function _checkDomination(uint256 crewId) internal view returns (bool) {
        Crew storage crew = crews[crewId];
        if (crew.controlledTerritories.length < DOMINATION_THRESHOLD) return false;
        
        // Check if crew controls NEXUS
        for (uint256 i = 0; i < crew.controlledTerritories.length; i++) {
            if (territories[uint8(crew.controlledTerritories[i])].territoryType == TerritoryType.NEXUS) {
                return true;
            }
        }
        return false;
    }

    function _handleDomination(uint256 winningCrewId) internal {
        emit DominationVictory(winningCrewId, currentSeason);
        
        // Eliminate other crews and distribute stakes
        for (uint256 i = 1; i <= crewCounter; i++) {
            if (i != winningCrewId && crews[i].state == CrewState.ACTIVE) {
                Crew storage loser = crews[i];
                uint256 remaining = loser.warChest;
                
                // 50% to winners, 50% burned
                uint256 toWinners = remaining / 2;
                uint256 toBurn = remaining - toWinners;
                
                crews[winningCrewId].warChest += toWinners;
                dataToken.safeTransfer(address(0xdead), toBurn);
                
                loser.state = CrewState.ELIMINATED;
                loser.warChest = 0;
                
                emit StakeBurned(toBurn, "domination_elimination");
            }
        }
        
        currentSeason++;
    }

    function _settleSpectatorBets(uint256 battleId, bool attackerWon) internal {
        Battle storage battle = battles[battleId];
        
        uint256 totalPool = battle.spectatorPoolAttacker + battle.spectatorPoolDefender;
        if (totalPool == 0) return;

        uint256 rake = (totalPool * SPECTATOR_RAKE_BPS) / 10000;
        uint256 payoutPool = totalPool - rake;

        // Burn rake
        dataToken.safeTransfer(address(0xdead), rake);
        emit StakeBurned(rake, "spectator_rake");

        uint256 winningPool = attackerWon ? battle.spectatorPoolAttacker : battle.spectatorPoolDefender;
        
        // Note: Individual claims would be processed separately
        // This is simplified for the contract outline
    }

    function _removeMember(Crew storage crew, address member) internal {
        for (uint256 i = 0; i < crew.members.length; i++) {
            if (crew.members[i] == member) {
                crew.members[i] = crew.members[crew.members.length - 1];
                crew.members.pop();
                break;
            }
        }
    }

    function _removeFromArray(uint256[] storage arr, uint256 value) internal {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == value) {
                arr[i] = arr[arr.length - 1];
                arr.pop();
                break;
            }
        }
    }

    function _disbandCrew(uint256 crewId) internal {
        Crew storage crew = crews[crewId];
        crew.state = CrewState.DISBANDED;
        
        // Release all territories
        for (uint256 i = 0; i < crew.controlledTerritories.length; i++) {
            uint8 territoryId = uint8(crew.controlledTerritories[i]);
            territories[territoryId].controllingCrew = 0;
            territories[territoryId].stakedAmount = 0;
        }
        
        // Burn remaining war chest
        if (crew.warChest > 0) {
            dataToken.safeTransfer(address(0xdead), crew.warChest);
            emit StakeBurned(crew.warChest, "crew_disbanded");
            crew.warChest = 0;
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    function getCrewMembers(uint256 crewId) external view returns (address[] memory) {
        return crews[crewId].members;
    }

    function getCrewTerritories(uint256 crewId) external view returns (uint256[] memory) {
        return crews[crewId].controlledTerritories;
    }

    function getTerritoryAdjacent(uint8 territoryId) external view returns (uint8[] memory) {
        return territories[territoryId].adjacentTerritories;
    }

    function getDefenseBonus(uint8 territoryId) external view returns (uint256) {
        Territory storage t = territories[territoryId];
        uint256 typeBonus = 0;
        if (t.territoryType == TerritoryType.CORE) typeBonus = 1500;
        if (t.territoryType == TerritoryType.NEXUS) typeBonus = 2500;
        
        uint256 fortBonus = 0;
        if (block.timestamp < t.fortificationExpiry) {
            fortBonus = t.fortificationLevel * 1000; // 10% per level
        }
        
        return typeBonus + fortBonus;
    }

    // ═══════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    function setOracle(address _oracle) external onlyOwner {
        oracle = _oracle;
    }
}
```

### Frontend Store

```typescript
// src/lib/features/arcade/proxy-war/store.svelte.ts

import { browser } from '$app/environment';

// ═══════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════

export type TerritoryType = 'edge' | 'standard' | 'core' | 'nexus';
export type BattleType = 'siege' | 'blitz' | 'hack_war' | 'sabotage';
export type BattleState = 'none' | 'declared' | 'active' | 'resolved';
export type CrewState = 'active' | 'disbanded' | 'eliminated';

interface Territory {
  id: number;
  type: TerritoryType;
  controllingCrew: number | null;
  crewName: string | null;
  stakedAmount: bigint;
  fortificationLevel: number;
  fortificationExpiry: number;
  adjacentTerritories: number[];
  yieldPerHour: bigint;
  defenseBonus: number;
  position: { x: number; y: number };
}

interface CrewMember {
  address: string;
  isCommander: boolean;
  isOnline: boolean;
  currentTerritory: number | null;
  joinedAt: number;
}

interface Crew {
  id: number;
  name: string;
  commander: string;
  members: CrewMember[];
  warChest: bigint;
  totalYieldEarned: bigint;
  controlledTerritories: number[];
  state: CrewState;
  rank: number;
  totalYieldPerHour: bigint;
}

interface Battle {
  id: number;
  attackingCrew: number;
  attackingCrewName: string;
  defendingCrew: number;
  defendingCrewName: string;
  territoryId: number;
  battleType: BattleType;
  state: BattleState;
  attackerStake: bigint;
  defenderStake: bigint;
  declaredAt: number;
  startsAt: number;
  endsAt: number;
  attackerScore: number;
  defenderScore: number;
  spectatorPoolAttacker: bigint;
  spectatorPoolDefender: bigint;
}

interface BattleParticipant {
  address: string;
  crewId: number;
  wpm: number;
  accuracy: number;
  progress: number;
  score: number;
}

interface SpectatorBet {
  amount: bigint;
  onAttacker: boolean;
  potentialPayout: bigint;
}

interface WarRoomMessage {
  type: 'system' | 'chat' | 'alert' | 'battle';
  content: string;
  timestamp: number;
  sender?: string;
}

// ═══════════════════════════════════════════════════════════════════════════
// STORE
// ═══════════════════════════════════════════════════════════════════════════

export function createProxyWarStore() {
  // ─────────────────────────────────────────────────────────────────────────
  // STATE
  // ─────────────────────────────────────────────────────────────────────────

  // Map state
  let territories = $state<Territory[]>([]);
  let selectedTerritory = $state<number | null>(null);
  
  // Crew state
  let myCrew = $state<Crew | null>(null);
  let allCrews = $state<Crew[]>([]);
  let crewRankings = $state<{ crewId: number; name: string; territories: number; yield: bigint }[]>([]);
  
  // Battle state
  let activeBattles = $state<Battle[]>([]);
  let currentBattle = $state<Battle | null>(null);
  let battleParticipants = $state<BattleParticipant[]>([]);
  let myBattleProgress = $state<BattleParticipant | null>(null);
  let spectatorBet = $state<SpectatorBet | null>(null);
  
  // War room state
  let warRoomMessages = $state<WarRoomMessage[]>([]);
  let pendingYield = $state<bigint>(0n);
  
  // Connection state
  let isConnected = $state(false);
  let currentView = $state<'map' | 'war_room' | 'battle' | 'crew_create'>('map');

  // ─────────────────────────────────────────────────────────────────────────
  // DERIVED
  // ─────────────────────────────────────────────────────────────────────────

  let isInCrew = $derived(myCrew !== null);
  let isCommander = $derived(myCrew?.commander === getCurrentAddress());
  let onlineMemberCount = $derived(myCrew?.members.filter(m => m.isOnline).length ?? 0);
  let totalMemberCount = $derived(myCrew?.members.length ?? 0);
  
  let myTerritories = $derived(
    territories.filter(t => t.controllingCrew === myCrew?.id)
  );
  
  let totalYieldPerHour = $derived(
    myTerritories.reduce((sum, t) => sum + t.yieldPerHour, 0n)
  );
  
  let canAttack = $derived(
    isCommander && 
    myCrew !== null && 
    myCrew.warChest > 0n &&
    !activeBattles.some(b => b.attackingCrew === myCrew?.id || b.defendingCrew === myCrew?.id)
  );
  
  let selectedTerritoryData = $derived(
    selectedTerritory !== null ? territories.find(t => t.id === selectedTerritory) : null
  );
  
  let canCaptureSelected = $derived(() => {
    if (!selectedTerritoryData || !myCrew) return false;
    if (selectedTerritoryData.controllingCrew !== null) return false;
    
    // First territory must be edge
    if (myTerritories.length === 0) {
      return selectedTerritoryData.type === 'edge';
    }
    
    // Must be adjacent to owned territory
    return selectedTerritoryData.adjacentTerritories.some(
      adjId => myTerritories.some(t => t.id === adjId)
    );
  });
  
  let canAttackSelected = $derived(() => {
    if (!selectedTerritoryData || !myCrew || !isCommander) return false;
    if (selectedTerritoryData.controllingCrew === null) return false;
    if (selectedTerritoryData.controllingCrew === myCrew.id) return false;
    if (myCrew.warChest < selectedTerritoryData.stakedAmount) return false;
    
    // Must be adjacent to owned territory
    return selectedTerritoryData.adjacentTerritories.some(
      adjId => myTerritories.some(t => t.id === adjId)
    );
  });
  
  let battleTimeRemaining = $derived(() => {
    if (!currentBattle || currentBattle.state !== 'active') return 0;
    const duration = getBattleDuration(currentBattle.battleType);
    const elapsed = Date.now() - currentBattle.startsAt;
    return Math.max(0, duration - elapsed);
  });
  
  let attackerWinning = $derived(() => {
    if (!currentBattle) return false;
    const totalScore = currentBattle.attackerScore + currentBattle.defenderScore;
    if (totalScore === 0) return false;
    const attackerPercent = (currentBattle.attackerScore / totalScore) * 100;
    return attackerPercent >= getBattleThreshold(currentBattle.battleType);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  function getCurrentAddress(): string {
    // Would come from wallet connection
    return '0x0000000000000000000000000000000000000000';
  }

  function getBattleDuration(type: BattleType): number {
    switch (type) {
      case 'siege': return 3 * 60 * 1000;      // 3 minutes
      case 'blitz': return 1 * 60 * 1000;      // 1 minute
      case 'hack_war': return 5 * 60 * 1000;   // 5 minutes
      case 'sabotage': return 2 * 60 * 1000;   // 2 minutes
    }
  }

  function getBattleThreshold(type: BattleType): number {
    switch (type) {
      case 'siege': return 55;
      case 'blitz': return 52;
      case 'hack_war': return 50;
      case 'sabotage': return 50;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WEBSOCKET
  // ─────────────────────────────────────────────────────────────────────────

  let ws: WebSocket | null = null;

  function connect() {
    if (!browser) return;

    ws = new WebSocket('wss://api.ghostnet.io/proxy-war');

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);

      switch (data.type) {
        case 'MAP_STATE':
          territories = data.territories;
          allCrews = data.crews;
          activeBattles = data.battles;
          break;

        case 'CREW_STATE':
          myCrew = data.crew;
          pendingYield = BigInt(data.pendingYield);
          break;

        case 'TERRITORY_CAPTURED':
          updateTerritory(data.territoryId, data.controllingCrew, data.stake);
          addWarRoomMessage({
            type: 'system',
            content: `${data.crewName} captured ${data.territoryName}`,
            timestamp: Date.now()
          });
          break;

        case 'BATTLE_DECLARED':
          activeBattles = [...activeBattles, data.battle];
          if (data.battle.defendingCrew === myCrew?.id) {
            addWarRoomMessage({
              type: 'alert',
              content: `INCOMING ATTACK on ${data.territoryName} by ${data.attackerName}!`,
              timestamp: Date.now()
            });
          }
          break;

        case 'BATTLE_STARTED':
          currentBattle = data.battle;
          currentView = 'battle';
          break;

        case 'BATTLE_PROGRESS':
          battleParticipants = data.participants;
          if (currentBattle) {
            currentBattle = {
              ...currentBattle,
              attackerScore: data.attackerScore,
              defenderScore: data.defenderScore
            };
          }
          break;

        case 'MY_BATTLE_PROGRESS':
          myBattleProgress = data.progress;
          break;

        case 'BATTLE_RESOLVED':
          currentBattle = { ...currentBattle!, state: 'resolved', ...data.result };
          updateTerritoryAfterBattle(data);
          break;

        case 'MEMBER_ONLINE':
          if (myCrew) {
            myCrew = {
              ...myCrew,
              members: myCrew.members.map(m =>
                m.address === data.address ? { ...m, isOnline: true } : m
              )
            };
          }
          break;

        case 'MEMBER_OFFLINE':
          if (myCrew) {
            myCrew = {
              ...myCrew,
              members: myCrew.members.map(m =>
                m.address === data.address ? { ...m, isOnline: false } : m
              )
            };
          }
          break;

        case 'WAR_ROOM_MESSAGE':
          addWarRoomMessage(data.message);
          break;

        case 'YIELD_UPDATED':
          pendingYield = BigInt(data.amount);
          break;

        case 'DOMINATION_VICTORY':
          addWarRoomMessage({
            type: 'system',
            content: `DOMINATION: ${data.crewName} has conquered the network!`,
            timestamp: Date.now()
          });
          break;
      }
    };

    ws.onopen = () => {
      isConnected = true;
    };

    ws.onclose = () => {
      isConnected = false;
      // Reconnect after delay
      setTimeout(connect, 3000);
    };

    return () => {
      ws?.close();
    };
  }

  function updateTerritory(id: number, controllingCrew: number | null, stake: bigint) {
    territories = territories.map(t =>
      t.id === id ? { ...t, controllingCrew, stakedAmount: stake } : t
    );
  }

  function updateTerritoryAfterBattle(result: { territoryId: number; winner: number; newStake: bigint }) {
    territories = territories.map(t =>
      t.id === result.territoryId
        ? { ...t, controllingCrew: result.winner, stakedAmount: result.newStake }
        : t
    );
  }

  function addWarRoomMessage(message: WarRoomMessage) {
    warRoomMessages = [message, ...warRoomMessages.slice(0, 99)];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  async function createCrew(name: string, foundingMembers: string[]) {
    // Contract interaction: createCrew
  }

  async function joinCrew(crewId: number) {
    // Contract interaction: joinCrew
  }

  async function leaveCrew() {
    // Contract interaction: leaveCrew
  }

  async function claimTerritory(territoryId: number, stake: bigint) {
    // Contract interaction: claimTerritory
  }

  async function fortifyTerritory(territoryId: number) {
    // Contract interaction: fortifyTerritory
  }

  async function declareAttack(territoryId: number, battleType: BattleType) {
    // Contract interaction: declareAttack
  }

  async function placeSpectatorBet(battleId: number, onAttacker: boolean, amount: bigint) {
    // Contract interaction: placeSpectatorBet
    spectatorBet = {
      amount,
      onAttacker,
      potentialPayout: calculatePotentialPayout(battleId, onAttacker, amount)
    };
  }

  function calculatePotentialPayout(battleId: number, onAttacker: boolean, amount: bigint): bigint {
    const battle = activeBattles.find(b => b.id === battleId);
    if (!battle) return 0n;

    const totalPool = battle.spectatorPoolAttacker + battle.spectatorPoolDefender + amount;
    const rake = totalPool * 5n / 100n;
    const payoutPool = totalPool - rake;
    const winningPool = onAttacker
      ? battle.spectatorPoolAttacker + amount
      : battle.spectatorPoolDefender + amount;

    return (amount * payoutPool) / winningPool;
  }

  async function claimYield() {
    // Contract interaction: claimYield
  }

  function selectTerritory(id: number | null) {
    selectedTerritory = id;
  }

  function setView(view: 'map' | 'war_room' | 'battle' | 'crew_create') {
    currentView = view;
  }

  function sendCrewMessage(content: string) {
    ws?.send(JSON.stringify({
      type: 'CREW_CHAT',
      content
    }));
  }

  // Submit battle score (typing results)
  function submitBattleScore(wpm: number, accuracy: number, progress: number) {
    ws?.send(JSON.stringify({
      type: 'BATTLE_SCORE',
      battleId: currentBattle?.id,
      wpm,
      accuracy,
      progress
    }));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RETURN
  // ─────────────────────────────────────────────────────────────────────────

  return {
    // State
    get territories() { return territories; },
    get selectedTerritory() { return selectedTerritory; },
    get myCrew() { return myCrew; },
    get allCrews() { return allCrews; },
    get crewRankings() { return crewRankings; },
    get activeBattles() { return activeBattles; },
    get currentBattle() { return currentBattle; },
    get battleParticipants() { return battleParticipants; },
    get myBattleProgress() { return myBattleProgress; },
    get spectatorBet() { return spectatorBet; },
    get warRoomMessages() { return warRoomMessages; },
    get pendingYield() { return pendingYield; },
    get isConnected() { return isConnected; },
    get currentView() { return currentView; },

    // Derived
    get isInCrew() { return isInCrew; },
    get isCommander() { return isCommander; },
    get onlineMemberCount() { return onlineMemberCount; },
    get totalMemberCount() { return totalMemberCount; },
    get myTerritories() { return myTerritories; },
    get totalYieldPerHour() { return totalYieldPerHour; },
    get canAttack() { return canAttack; },
    get selectedTerritoryData() { return selectedTerritoryData; },
    get canCaptureSelected() { return canCaptureSelected; },
    get canAttackSelected() { return canAttackSelected; },
    get battleTimeRemaining() { return battleTimeRemaining; },
    get attackerWinning() { return attackerWinning; },

    // Actions
    connect,
    createCrew,
    joinCrew,
    leaveCrew,
    claimTerritory,
    fortifyTerritory,
    declareAttack,
    placeSpectatorBet,
    claimYield,
    selectTerritory,
    setView,
    sendCrewMessage,
    submitBattleScore
  };
}
```

---

## Visual Design

### Color Scheme

```css
.proxy-war {
  /* Territory ownership */
  --territory-neutral: #333333;
  --territory-owned: #00E5CC;
  --territory-enemy: #FF4444;
  --territory-allied: #44FF44;
  
  /* Territory types */
  --type-edge: #666666;
  --type-standard: #888888;
  --type-core: #AAAAAA;
  --type-nexus: #FFD700;
  
  /* Battle states */
  --battle-declared: #FFAA00;
  --battle-active: #FF0000;
  --battle-winning: #00FF00;
  --battle-losing: #FF0000;
  
  /* UI elements */
  --war-chest-full: #00FF00;
  --war-chest-low: #FFAA00;
  --war-chest-critical: #FF0000;
}
```

### Map Visualization

```
TERRITORY NODE STATES:
═══════════════════════════════════════════════════════════════════

NEUTRAL                     OWNED                      ENEMY
┌─────┐                    ┌─────┐                    ┌─────┐
│     │                    │░░░░░│                    │▓▓▓▓▓│
│ A-7 │                    │ A-7 │                    │ A-7 │
│     │                    │ YOU │                    │VOID │
└─────┘                    └─────┘                    └─────┘

NEXUS (Special)            UNDER ATTACK              FORTIFIED
┌─────┐                    ┌─────┐                    ┌─────┐
│█████│                    │▒▒▒▒▒│ ← pulsing        │░░░░░│
│NEX-0│                    │ C-1 │                    │ C-1 │ ★★★
│ 3x  │                    │!ATK!│                    │+30% │
└─────┘                    └─────┘                    └─────┘
```

### Animations

**Territory Capture:**
- Ownership color floods from center outward
- Screen flash on successful capture
- Defeated territory fades to new owner color

**Battle Declaration:**
- Red warning border pulses around territory
- Countdown timer appears above node
- Alert notification slides in

**Active Battle:**
- Progress bars animate smoothly
- Score differential highlighted
- Participant cards show live WPM/accuracy

**Domination Victory:**
- Map floods with victor's color
- ASCII art explosion
- Confetti particle effect
- Victory fanfare

---

## Sound Design

| Event | Sound |
|-------|-------|
| Territory Captured | Conquest horn + coin collect |
| Battle Declared | War horn + alert klaxon |
| Battle Starting | Countdown beeps + charge |
| Battle Won | Victory fanfare |
| Battle Lost | Defeat horn + burn crackle |
| Crew Member Online | Uplink connect tone |
| Crew Member Offline | Downlink disconnect |
| Yield Collected | Cash register + data transfer |
| Fortification Built | Construction + power up |
| Alert Incoming | Urgent pulse + warning |
| Domination Victory | Epic orchestral + cheering |
| Enemy Approaches | Proximity alarm |
| Type Correct (battle) | Soft click |
| Type Error (battle) | Sharp buzz |
| Score Update | Tick up/down sound |

---

## Feed Integration

```
> PROXY WAR: SHADOW_COLLECTIVE captured NEXUS-0! 🏰
> ⚔️ BATTLE DECLARED: VOID_RUNNERS attacking CORE-1 (SHADOW_COLLECTIVE)
> PROXY WAR BATTLE: SHADOW_COLLECTIVE defends CORE-1 - 58% vs 52% ⚔️
> 🔥 VOID_RUNNERS stake BURNED: 750 $DATA 🔥
> PROXY WAR: SHADOW_COLLECTIVE now controls 5 territories
> 💀 PROXY WAR: DARK_SYNDICATE eliminated by SHADOW_COLLECTIVE
> 👑 DOMINATION: SHADOW_COLLECTIVE conquers SECTOR OMEGA-7! Season 3 ends 👑
> PROXY WAR yield: SHADOW_COLLECTIVE earned +2,847 $DATA this hour
> SPECTATOR WIN: 0x7a3f bet 100 on SHADOW → +285 $DATA
```

---

## Testing Checklist

### Crew Management
- [ ] Crew creation with 3-8 founding members
- [ ] Entry stake of 500 $DATA collected from each member
- [ ] Commander assignment to first founding member
- [ ] Member joining existing crew
- [ ] Member leaving (stake forfeited to crew)
- [ ] Commander cannot leave unless transferring
- [ ] Crew disbands when < 3 members

### Territory Control
- [ ] First territory must be EDGE type
- [ ] Subsequent territories must be adjacent to owned
- [ ] Neutral territory claiming works
- [ ] Stake properly locked on territory
- [ ] Yield calculation correct per territory type
- [ ] Yield accumulates over time
- [ ] Yield claim transfers to war chest

### Battle System
- [ ] Attack declaration requires commander role
- [ ] Attack stake matches defender's territory stake
- [ ] 5-minute warning period before battle
- [ ] Spectator betting during warning period
- [ ] Betting closes at battle start
- [ ] Battle scores update in real-time
- [ ] Win condition thresholds correct (55%/52%)
- [ ] Territory transfers on attacker win
- [ ] Loser stake burns entirely
- [ ] Spectator payouts calculated correctly
- [ ] Spectator rake (5%) burns

### Fortification
- [ ] Costs 100 $DATA
- [ ] Stacks up to 3x
- [ ] +10% defense per level
- [ ] Expires after 24 hours
- [ ] Resets on territory capture

### Domination
- [ ] Triggers at NEXUS + 5 territories
- [ ] All other crews eliminated
- [ ] 50% of eliminated stakes to winner
- [ ] 50% of eliminated stakes burned
- [ ] Season counter increments
- [ ] Map resets after 24 hours

### Real-Time Updates
- [ ] WebSocket connection stable
- [ ] Map state syncs across all clients
- [ ] Battle progress updates < 100ms latency
- [ ] Member online/offline status
- [ ] War room messages delivered

### UI/UX
- [ ] Map renders correctly with 12 nodes
- [ ] Territory selection highlights adjacency
- [ ] Battle UI shows live progress
- [ ] War room messages chronological
- [ ] Mobile responsiveness
- [ ] ASCII art displays correctly in terminal font

### Economic Balance
- [ ] Entry cost balances with yield potential
- [ ] Battle risk/reward appropriate
- [ ] Domination payout satisfying
- [ ] Burn rate sufficient for deflation
