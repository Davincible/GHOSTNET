# GHOSTNET MVP Scope (Ship The Basics)

**Date:** 2026-01-24  
**Status:** Active  

This document defines the **shipping boundary** for the first end-to-end release.

The MVP is one complete loop:

`Web App (player actions + UI) → Core Contracts (truth) → Indexer (events + APIs) → Web App (real-time updates)`

Anything outside this boundary is not allowed to drive architecture, interfaces, or CI gates.

---

## In Scope (MVP)

### Web (`apps/web`)

**Goal:** Basic gameplay loop and live visibility.

- Wallet connect + display address/balances
- Jack in (stake) into a level
- Show active position (stake, yield, timers, death risk)
- Survive/scan visibility (countdowns + warnings)
- Extract (exit) and show outcome
- Live feed (real-time events) and network vitals

Primary reference:
- `docs/archive/architecture/implementation-plan.md` (historical)

### Core Contracts (`packages/contracts`)

**Goal:** Minimal on-chain system that enforces the loop.

Core contracts:
- `packages/contracts/src/token/DataToken.sol`
- `packages/contracts/src/core/GhostCore.sol`
- `packages/contracts/src/core/TraceScan.sol`

Supporting (MVP-required if used by the core flow):
- `packages/contracts/src/core/RewardsDistributor.sol`
- `packages/contracts/src/core/FeeRouter.sol`
- `packages/contracts/src/token/TeamVesting.sol`

Primary references:
- `docs/design/contracts/specifications.md`
- `docs/archive/architecture/smart-contracts-plan.md` (historical)

### Indexer (`services/ghostnet-indexer`)

**Goal:** The canonical off-chain projection of chain events.

Must provide:
- Ingest blocks/logs from MegaETH (WS where available, HTTP fallback)
- Decode core contract events and persist to TimescaleDB
- Stream events via WebSocket API to power the web feed

Primary references:
- `docs/architecture/backend/indexer-architecture.md`
- `services/ghostnet-indexer/README.md`

---

## Out of Scope (Later)

These may exist in the repo, but are **not** part of the MVP shipping contract:

- Arcade / daily / duels / betting games
  - `packages/contracts/src/arcade/**`
  - `packages/contracts/test/arcade/**`
  - `packages/contracts/test/games/**`
  - `apps/web/src/routes/arcade/**`
  - `apps/web/src/lib/features/daily/**` (and other arcade-specific features)
- Ghost Fleet automation
  - `services/ghost-fleet/**`
  - `services/ghostnet-actions/**`
  - `services/crates/fleet-core/**`

---

## Definition of Done (MVP)

### End-to-end
- A user can jack in and extract using the web UI.
- Core contract events appear in the web feed through the indexer.

### Quality gates
- MVP commands exist and run locally:
  - `just mvp-check`
  - `just mvp-dev`
- CI validates the MVP Rust toolchain and the MVP service set.

---

## Operating Principle

**Contracts are the source of truth.**

- The web app is a view/controller.
- The indexer is derived state (projection) and must be rebuildable from chain history.
- Any state that cannot be rebuilt is a liability and must be justified explicitly.
