---
type: backlog
updated: 2026-01-27
tags:
  - type/backlog
---

# Backlog

*Last groomed: 2026-01-27*

Parking lot for ideas, bugs, tech debt, and future work. Not everything here will be built.

---

## High Priority

*Items likely to be addressed soon*

### Features

| ID | Description | Source | Priority | Notes |
|----|-------------|--------|----------|-------|
| B-001 | Keeper bot for seed reveals | Phase 3 infra | [P1] | `services/keeper/` - needed for reliable randomness |
| B-002 | Matchmaking service | CODE DUEL | [P1] | `services/arcade-coordinator/` - blocks CODE DUEL frontend |
| B-003 | MVP contract event catalog | MVP scope | [P1] | Shared between contracts/indexer/web |

### Tech Debt

| ID | Description | Impact | Priority | Notes |
|----|-------------|--------|----------|-------|
| TD-001 | Archive old product/ docs | Documentation clarity | [P1] | After Blueprint complete |
| TD-002 | Consolidate remaining architecture docs | Navigation | [P1] | Into Blueprint structure |
| TD-003 | Trim arcade routes from MVP | User confusion | [P1] | Hide/rename so they don't look shippable |

---

## Medium Priority

*Items for next few sprints*

### Features

| ID | Description | Source | Priority | Notes |
|----|-------------|--------|----------|-------|
| B-010 | Spectator mode for CODE DUEL | Game design | [P2] | After core duel works |
| B-011 | Verification UI for randomness | Trust/transparency | [P2] | Show block hash, seed derivation |
| B-012 | Mobile responsive polish | UX | [P2] | Hash Crash done, others need work |

### Improvements

| ID | Description | Priority | Notes |
|----|-------------|----------|-------|
| B-020 | Better error messages in contract providers | [P2] | User-friendly parsing started |
| B-021 | Loading states across all features | [P2] | UX polish |
| B-022 | WebSocket real-time updates | [P2] | Structure ready, needs backend |

### Tech Debt

| ID | Description | Impact | Priority | Notes |
|----|-------------|--------|----------|-------|
| TD-010 | Slither analysis pass on arcade contracts | Security | [P2] | Pre-mainnet requirement |
| TD-011 | Add missing frontend tests | Quality | [P2] | E2E tests for games |
| TD-012 | Load testing (100+ players) | Scalability | [P2] | Hash Crash specifically |

---

## Low Priority / Someday

*Items we might do eventually*

### Features

| ID | Description | Priority | Notes |
|----|-------------|----------|-------|
| B-100 | Governance token for pool parameters | [P3] | Major feature, not MVP |
| B-101 | Cross-chain bridging | [P3] | Future expansion |
| B-102 | Mobile app | [P3] | Major undertaking |
| B-103 | API v2 for external integrations | [P3] | No compelling need yet |

### Phase 3B Games (Deferred)

| ID | Description | Priority | Notes |
|----|-------------|----------|-------|
| B-110 | ICE BREAKER (Skill) | [P3] | Phase 3B - after 3A complete |
| B-111 | BINARY BET (Casino) | [P3] | Phase 3B - after 3A complete |
| B-112 | BOUNTY HUNT (Strategy) | [P3] | Phase 3B - after 3A complete |

### Phase 3C Games (Future)

| ID | Description | Priority | Notes |
|----|-------------|----------|-------|
| B-120 | PROXY WAR (Team) | [P3] | Phase 3C - needs crew system |
| B-121 | ZERO DAY (Skill) | [P3] | Phase 3C - multi-stage engine |
| B-122 | SHADOW PROTOCOL (Meta) | [P3] | Phase 3C - full integration |

---

## Bugs

*Known issues to fix*

| ID | Description | Severity | Reported | Notes |
|----|-------------|----------|----------|-------|
| *None tracked* | — | — | — | — |

---

## Needs Investigation

*Items needing more info before prioritizing*

| ID | Description | Question |
|----|-------------|----------|
| B-200 | Formal verification of solvency invariant | Worth the effort? Pre-audit? |
| B-201 | Alternative randomness sources | Chainlink VRF if MegaETH adds support? |

---

## Declined / Won't Do

*Items we've decided against (kept for record)*

| ID | Description | Reason | Declined |
|----|-------------|--------|----------|
| *None yet* | — | — | — |

---

## Priority Legend

| Tag | Meaning |
|-----|---------|
| `[P0]` | Critical - blocks release |
| `[P1]` | High - do soon |
| `[P2]` | Medium - next few sprints |
| `[P3]` | Low - someday/maybe |
