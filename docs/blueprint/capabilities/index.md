---
type: blueprint-capabilities
updated: 2026-01-27
tags:
  - type/blueprint
  - blueprint/capabilities
---

# Capability Registry

## Overview

This registry lists all functional requirements (FRs) for GHOSTNET. Capabilities are organized by domain: Core Game, Economy, Mini-Games, and Social.

**Status Legend:**

| Emoji | Status | Meaning |
|-------|--------|---------|
| 🧠 | Draft | Still being defined |
| 🟣 | Ready | Specified, ready to implement |
| 🚧 | In Progress | Actively being built |
| 👀 | In Review | In PR review |
| 🔴 | Blocked | Cannot proceed |
| ✅ | Implemented | Shipped and true |

---

## Core Game (CORE)

The fundamental staking, survival, and extraction mechanics.

| ID | Capability | Status | Detail |
|----|------------|--------|--------|
| FR-CORE-001 | Jack In (stake tokens at risk level) | 🟣 | [[capabilities/core#🟣-fr-core-001-jack-in]] |
| FR-CORE-002 | Extract (withdraw stake + yield) | 🟣 | [[capabilities/core#🟣-fr-core-002-extract]] |
| FR-CORE-003 | Trace Scan (periodic survival check) | 🟣 | [[capabilities/core#🟣-fr-core-003-trace-scan]] |
| FR-CORE-004 | Risk Levels (5 tiers with parameters) | 🟣 | [[capabilities/core#🟣-fr-core-004-risk-levels]] |
| FR-CORE-005 | Yield Accrual (real-time yield) | 🟣 | [[capabilities/core#🟣-fr-core-005-yield-accrual]] |
| FR-CORE-006 | Death Handling (position liquidation) | 🟣 | [[capabilities/core#🟣-fr-core-006-death-handling]] |
| FR-CORE-007 | System Reset Timer (starvation mechanic) | 🟣 | [[capabilities/core#🟣-fr-core-007-system-reset-timer]] |
| FR-CORE-008 | The Culling (capacity enforcement) | 🧠 | [[capabilities/core#🧠-fr-core-008-the-culling]] |
| FR-CORE-009 | Emergency Pause | 🟣 | [[capabilities/core#🟣-fr-core-009-emergency-pause]] |
| FR-CORE-010 | Emergency Withdraw | 🟣 | [[capabilities/core#🟣-fr-core-010-emergency-withdraw]] |
| FR-CORE-011 | Read-Only Mode | 🚧 | [[capabilities/core#🚧-fr-core-011-read-only-mode]] |

---

## Operations (OPS)

Keeper automation and governance.

| ID | Capability | Status | Detail |
|----|------------|--------|--------|
| FR-OPS-001 | Keeper Automation | 🧠 | [[capabilities/core#🧠-fr-ops-001-keeper-automation]] |
| FR-OPS-002 | Upgrade Governance | 🟣 | [[capabilities/core#🟣-fr-ops-002-upgrade-governance]] |

---

## Economy (ECON)

Tokenomics, redistribution, and deflationary mechanics.

| ID | Capability | Status | Detail |
|----|------------|--------|--------|
| FR-ECON-001 | The Cascade (60/30/10 redistribution) | 🟣 | [[capabilities/economy#🟣-fr-econ-001-the-cascade]] |
| FR-ECON-002 | Burn Engine - Protocol Fee (5% on extracts) | 🟣 | [[capabilities/economy#🟣-fr-econ-002-burn-engine---protocol-fee]] |
| FR-ECON-003 | Burn Engine - Death Tax (30% of dead positions burned) | 🟣 | [[capabilities/economy#🟣-fr-econ-003-burn-engine---death-tax]] |
| FR-ECON-004 | Burn Engine - Risk Boost (burns for upgrades) | 🧠 | [[capabilities/economy#🧠-fr-econ-004-burn-engine---risk-boost]] |
| FR-ECON-005 | Burn Engine - Crew Tax (crew formation) | 🧠 | [[capabilities/economy#🧠-fr-econ-005-burn-engine---crew-tax]] |
| FR-ECON-006 | Burn Engine - Mini-game Entry | 🚧 | [[capabilities/economy#🚧-fr-econ-006-burn-engine---mini-game-entry]] |
| FR-ECON-007 | Token Supply (100M fixed, deflationary) | 🟣 | [[capabilities/economy#🟣-fr-econ-007-token-supply]] |
| FR-ECON-008 | ETH Toll Booth ($2 fee per action) | 🧠 | [[capabilities/economy#🧠-fr-econ-008-eth-toll-booth]] |
| FR-ECON-009 | Trading Tax (10% buy/sell tax) | 🧠 | [[capabilities/economy#🧠-fr-econ-009-trading-tax]] |
| FR-ECON-010 | Claim Rewards Without Extract | 🧠 | [[capabilities/economy#🧠-fr-econ-010-claim-rewards-without-extract]] |
| FR-ECON-011 | Protocol Fee Distribution | 🟣 | [[capabilities/economy#🟣-fr-econ-011-protocol-fee-distribution]] |

---

## Mini-Games (GAME)

Active boost layer and arcade games.

| ID | Capability | Status | Detail |
|----|------------|--------|--------|
| FR-GAME-001 | Trace Evasion (typing, reduces death rate) | 🚧 | [[capabilities/minigames#🚧-fr-game-001-trace-evasion]] |
| FR-GAME-002 | Hack Runs (yield multiplier game) | 🧠 | [[capabilities/minigames#🧠-fr-game-002-hack-runs]] |
| FR-GAME-003 | Dead Pool (betting on survivors) | 🧠 | [[capabilities/minigames#🧠-fr-game-003-dead-pool]] |
| FR-GAME-004 | Hash Crash (casino crash game) | 🚧 | [[capabilities/minigames#🚧-fr-game-004-hash-crash]] |
| FR-GAME-005 | Code Duel (1v1 typing competition) | 🚧 | [[capabilities/minigames#🚧-fr-game-005-code-duel]] |
| FR-GAME-006 | Daily Ops (daily progression) | 🚧 | [[capabilities/minigames#🚧-fr-game-006-daily-ops]] |
| FR-GAME-007 | ICE Breaker (skill game) | 🟣 | [[capabilities/minigames#🟣-fr-game-007-ice-breaker]] |
| FR-GAME-008 | Binary Bet (binary options) | 🟣 | [[capabilities/minigames#🟣-fr-game-008-binary-bet]] |
| FR-GAME-009 | Bounty Hunt (strategy game) | 🟣 | [[capabilities/minigames#🟣-fr-game-009-bounty-hunt]] |
| FR-GAME-010 | Memory Dump (slot machine) | 🟣 | [[capabilities/minigames#🟣-fr-game-010-memory-dump-slot-machine]] |

---

## Social (SOCIAL)

Community, crews, and competitive features.

| ID | Capability | Status | Detail |
|----|------------|--------|--------|
| FR-SOCIAL-001 | The Feed (real-time event stream) | ✅ | [[capabilities/social#✅-fr-social-001-the-feed]] |
| FR-SOCIAL-002 | Leaderboards (top survivors, deaths) | 🟣 | [[capabilities/social#🟣-fr-social-002-leaderboards]] |
| FR-SOCIAL-003 | Crews (team formation with bonuses) | 🧠 | [[capabilities/social#🧠-fr-social-003-crews]] |
| FR-SOCIAL-004 | Crew Raids (inter-crew competition) | 🧠 | [[capabilities/social#🧠-fr-social-004-crew-raids]] |
| FR-SOCIAL-005 | Profile/Stats (player statistics) | 🟣 | [[capabilities/social#🟣-fr-social-005-profilestats]] |
| FR-SOCIAL-006 | PvP Duels (competitive typing battles) | 🧠 | [[capabilities/social#🧠-fr-social-006-pvp-duels]] |
| FR-SOCIAL-007 | Event Schema Contract | 🚧 | [[capabilities/social#🚧-fr-social-007-event-schema-contract]] |
| FR-SOCIAL-008 | Spectator Mode | 🧠 | [[capabilities/social#🧠-fr-social-008-spectator-mode]] |

---

## Summary

| Domain | Implemented | In Progress | Ready | Draft |
|--------|-------------|-------------|-------|-------|
| Core Game | 0 | 1 | 8 | 2 |
| Operations | 0 | 0 | 1 | 1 |
| Economy | 0 | 1 | 5 | 5 |
| Mini-Games | 0 | 4 | 4 | 2 |
| Social | 1 | 1 | 2 | 4 |
| **Total** | **1** | **7** | **20** | **14** |

---

## Related Documents

- [[capabilities/core]] - Core game mechanics
- [[capabilities/economy]] - Tokenomics and burns
- [[capabilities/minigames]] - Mini-game capabilities
- [[capabilities/social]] - Social features
- [[design/arcade/]] - Detailed mini-game specifications
- [[architecture]] - System architecture
