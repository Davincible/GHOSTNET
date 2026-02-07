---
type: epic
status: in-progress
created: 2026-01-27
updated: 2026-01-27
implements:
  - "[[FR-CORE-001]]"
  - "[[FR-CORE-002]]"
  - "[[FR-CORE-003]]"
  - "[[FR-CORE-004]]"
  - "[[FR-CORE-005]]"
  - "[[FR-CORE-006]]"
tags:
  - type/epic
  - feature/core
  - status/in-progress
---

# EPIC-001: Core Game Loop

## Summary

Implement the complete GHOSTNET core gameplay loop: users can jack in (stake $DATA at a risk level), earn yield in real-time, survive periodic trace scans, and extract their gains. This is the foundational game mechanic that everything else builds upon.

## Motivation

The core game loop is what makes GHOSTNET unique — it combines DeFi staking mechanics with survival game tension. Without this working end-to-end, we have no product. This epic delivers the MVP experience: stake → survive → extract.

### Implements

- [[FR-CORE-001]] — Jack In (stake tokens at risk level)
- [[FR-CORE-002]] — Extract (withdraw stake + yield)
- [[FR-CORE-003]] — Trace Scan (periodic survival check)
- [[FR-CORE-004]] — Risk Levels (5 tiers with parameters)
- [[FR-CORE-005]] — Yield Accrual (real-time yield)
- [[FR-CORE-006]] — Death Handling (position liquidation)

## Scope

### In Scope

- Jack In transaction flow (web UI → contract)
- Extract transaction flow (web UI → contract)
- Real-time position display with yield accrual
- Live event feed showing jacks, deaths, extracts
- Trace scan execution (manual trigger for MVP)
- Death handling and cascade redistribution display
- 5 risk levels with distinct parameters

### Out of Scope

- Automated keeper for trace scans (Phase 2)
- Boost mechanics from mini-games (Phase 2)
- Crew bonuses (H2)
- Multi-pool support (H4)

## Success Criteria

- [ ] User can jack in from web UI and see position appear
- [ ] User can extract from web UI and receive tokens
- [ ] Feed shows JACK IN, EXTRACT, and DEATH events in real-time
- [ ] Position panel updates yield in real-time
- [ ] Trace scan can execute and kill positions based on death rate
- [ ] Dead positions are redistributed per Cascade rules

---

## Stories

| Story | Title | Status | Wave |
|-------|-------|--------|------|
| [[STORY-0001-jack-in-flow]] | Jack In Flow | 🟣 Ready | 1 |
| [[STORY-0002-trace-scan-execution]] | Trace Scan Execution | 🟣 Ready | 2 |
| [[STORY-0003-extract-flow]] | Extract Flow | 🟣 Ready | 2 |

---

## Execution Order

**Pattern:** Waves

### Wave 1: Foundation (Sequential)

- **STORY-0001** — Jack In Flow must work first; establishes the position creation path

### Wave 2: Full Loop (Parallel)

*Requires: Wave 1 complete (positions exist to scan/extract)*

- **STORY-0002** ∥ **STORY-0003** — Can build trace scan and extract independently
- Both depend on having active positions from Wave 1
- **Max agents:** 2

**Summary:**

| Wave | Stories | Agents | Notes |
|------|---------|--------|-------|
| 1 | 1 | 1 | Create positions first |
| 2 | 2 | 2 | Scan and extract in parallel |

---

## Progress

- **Start date:** 2026-01-27
- **Target completion:** Week 4 (2026-02-10)
- **Current status:** 0% complete (0/3 stories)

---

## Dependencies

### Internal Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| GhostCore.sol | ✅ Complete | Core staking contract |
| TraceScan.sol | ✅ Complete | Death roll mechanics |
| DataToken.sol | ✅ Complete | ERC20 with 10% tax |
| ghostnet-api (Ishizue) | 🟣 Ready | See [[EPIC-003-ghostnet-api]] — replaces old indexer |
| Web wallet integration | ✅ Complete | WalletConnect working |

### External Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| MegaETH Testnet | ✅ Available | Contracts can deploy |

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Indexer delays | Medium | High | Use mock data for UI testing |
| Gas estimation on MegaETH | Low | Medium | Use --skip-simulation, tested patterns |
| Real-time WebSocket issues | Medium | Medium | Fallback to polling |

---

## Technical Approach

**Web App:**
- Viem/Wagmi hooks for contract interaction
- WebSocket connection to indexer for real-time feed
- Svelte 5 runes for reactive position display

**Contracts:**
- GhostCore.jackIn() / extract() already implemented
- TraceScan.executeScan() for death rolls
- Events emitted for indexer to capture

**Indexer:**
- Decode JackIn, Extract, Death events
- Store in TimescaleDB
- Stream via WebSocket to web clients

Design reference: `docs/architecture/mvp-scope.md`

---

## Notes

This epic represents the core MVP scope. Everything else (arcade games, crews, etc.) builds on this foundation working correctly.

The contracts are complete with 1275+ tests. Focus is on integration:
1. Web → Contract (writes)
2. Contract → Indexer (events)
3. Indexer → Web (real-time feed)

---

## Timeline

| Milestone | Target | Status |
|-----------|--------|--------|
| Stories defined | 2026-01-27 | ✅ |
| First story complete | 2026-02-03 | 🟣 |
| All stories complete | 2026-02-10 | 🟣 |
| Epic closed | 2026-02-10 | 🧠 |
