---
type: status
updated: 2026-01-27
tags:
  - type/status
---

# Project Status

*Last updated: 2026-01-27*

## Quick Summary

MVP scope defined. Core infrastructure complete (1275 tests passing). Phase 3A games in progress. Documentation consolidation underway.

---

## Current Focus: Pre-Sprint (MVP Definition)

**Goal:** Ship the core gameplay loop (web + core contracts + indexer)

**Phase:** MVP definition and architecture alignment

---

## Active Epics

| Epic | Description | Status | Progress |
|------|-------------|--------|----------|
| [[epics/EPIC-002-ishizue-foundation/epic\|EPIC-002]] | Ishizue workspace, protos, domain crate | 🟣 Ready | 0/4 stories |
| [[epics/EPIC-003-ghostnet-api/epic\|EPIC-003]] | ghostnet-api service (ingestion + queries) | 🟣 Ready | 0/6 stories |
| [[epics/EPIC-004-ghostnet-signer/epic\|EPIC-004]] | ghostnet-signer service (EIP-712 signing) | 🟣 Ready | 0/2 stories |
| [[epics/EPIC-001-core-game-loop/epic\|EPIC-001]] | Core game mechanics (jack in, scan, extract) | 🟣 Ready | 0/3 stories |

---

## Active Work

| Item | Status | Owner | Notes |
|------|--------|-------|-------|
| MVP Core Loop | 🚧 In Progress | — | Web + GhostCore + Indexer |
| Phase 3A: Hash Crash | 🚧 In Progress | — | Frontend complete, contract deployed to testnet |
| Phase 3A: Code Duel | 🚧 In Progress | — | Contract complete (101 tests), needs frontend |
| Phase 3A: Daily Ops | 🚧 In Progress | — | Frontend complete, awaiting testnet deploy |
| Documentation Consolidation | ✅ Complete | — | Blueprint, work tracking, design docs reorganized |

---

## Blocked

| Item | Blocker | Since | Action |
|------|---------|-------|--------|
| *None currently* | — | — | — |

---

## Ready (Next Up)

| Item | Dependencies | Notes |
|------|--------------|-------|
| Deploy DailyOps to testnet | None | Contract ready |
| Hash Crash E2E testing | Testnet deployment | Structure ready |
| Arcade Coordinator service | CODE DUEL frontend | Rust matchmaking service |
| Validate `just mvp-check` | MVP scope doc | End-to-end gate |

---

## Recently Completed

| Item | Completed | Notes |
|------|-----------|-------|
| MVP scope document | 2026-01-24 | `docs/work/mvp-scope.md` |
| Architecture overview | 2026-01-24 | `docs/blueprint/architecture.md` |
| Documentation consolidation | 2026-01-27 | Full restructure: blueprint/, work/, design/, operations/ |
| Blueprint structure | 2026-01-27 | `docs/blueprint/` created |
| Daily Ops frontend | 2026-01-25 | 7 components, contract provider |
| CODE DUEL security tests | 2026-01-25 | 57 additional tests |
| Hash Crash contract | 2026-01-23 | 84 tests, deployed to testnet |
| EIP-2935 verification | 2026-01-23 | 8191 block window confirmed |
| ArcadeCore + GameRegistry | 2026-01-22 | 1070 tests, deployed to testnet |

---

## Infrastructure Status

| Component | Status | Tests | Notes |
|-----------|--------|-------|-------|
| Smart Contracts Core | ✅ Complete | 1275 | ArcadeCore, GameRegistry, randomness |
| Shared Game Engine | ✅ Complete | 165 | State machine, timer, score, reward systems |
| Randomness (Future Block Hash) | ✅ Complete | 47 | EIP-2935 verified on MegaETH |
| Matchmaking Service | 🟣 Ready | — | Spec complete, not started |

---

## MegaETH Testnet Deployments

| Contract | Address |
|----------|---------|
| MockERC20 (mDATA) | `0xf278eb6Cd5255dC67CFBcdbD57F91baCB3735804` |
| ArcadeCore (proxy) | `0xC65338Eda8F8AEaDf89bA95042b99116dD899BD0` |
| HashCrash | `0x037e0554f10e5447e08e4EDdbB16d8D8F402F785` |

---

## Risks & Notes

| Issue | Impact | Action |
|-------|--------|--------|
| No external audit yet | Security risk | Schedule before mainnet |
| Arcade routes visible in MVP | User confusion | Trim/hide arcade navigation |

---

## Links

- [[blueprint/capabilities/index]] - What we're building
- [[blueprint/roadmap]] - Where we're going
- [[backlog]] - Ideas and future work
- [[dependencies]] - Dependency graph and blockers
- [[epics/EPIC-001-core-game-loop/epic]] - Primary active epic
- `docs/work/mvp-scope.md` - MVP boundary definition
