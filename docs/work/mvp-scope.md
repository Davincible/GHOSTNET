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

### Backend Services (`services/` — Ishizue framework)

**Goal:** The canonical off-chain projection of chain events, signing infrastructure, and fleet orchestration.

The backend is built on the **Ishizue microservices framework** (which we also develop). GHOSTNET is the first real-world proof-of-concept for the framework.

**ghostnet-api** (MVP-critical):
- Ingest blocks/logs from MegaETH (WS where available, HTTP fallback)
- Decode core contract events and persist to TimescaleDB
- Serve REST + gRPC query APIs (positions, scans, stats)
- Stream events via WebSocket to power the web feed

**ghostnet-signer** (MVP-critical):
- EIP-712 typed data signing for daily missions / reward claims
- Signature verification

**ghostnet-fleet** (post-MVP):
- Wallet orchestration and automation
- Admin APIs

Primary references:
- `docs/design/services/ishizue-migration-plan.md` — Migration strategy and step-by-step plan
- `docs/design/services/ishizue-integration-plan.md` — Proto definitions, API contracts, workspace config

---

## Out of Scope (Later)

These may exist in the repo, but are **not** part of the MVP shipping contract:

- Arcade / daily / duels / betting games
  - `packages/contracts/src/arcade/**`
  - `packages/contracts/test/arcade/**`
  - `packages/contracts/test/games/**`
  - `apps/web/src/routes/arcade/**`
  - `apps/web/src/lib/features/daily/**` (and other arcade-specific features)
- Ghost Fleet automation (ghostnet-fleet service)
- Old pre-Ishizue services (archived on `archive/pre-ishizue-services` branch)
  - `services/ghost-fleet/` (old)
  - `services/ghostnet-actions/` (old — library logic migrates to libs/)
  - `services/ghostnet-indexer/` (old — replaced by ghostnet-api)

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
