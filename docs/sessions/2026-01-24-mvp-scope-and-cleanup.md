# Session Log: MVP Scope and Cleanup Plan

**Date:** 2026-01-24  
**Type:** Architecture / Cleanup  
**Status:** Completed

## Session Overview

Aligned the repository around a single near-term objective: ship the MVP (web basics + core contracts + indexer). Added concrete repo-level guardrails (docs + commands + CI alignment) so “later features” can exist without steering the system.

## Key Decisions Made

### 1) MVP Boundary

**Decision:** MVP includes only:
- Web basics (`apps/web`) supporting the core loop
- Core contracts (`DataToken`, `GhostCore`, `TraceScan`)
- Indexer service (`services/ghostnet-indexer`)

Arcade/daily/duels and Ghost Fleet are explicitly **later**.

### 2) Contracts are the source of truth

**Decision:** The stable interface between on-chain and off-chain is the contract events + semantics. Indexer is a projection; web is a view/controller.

### 3) Rust toolchain alignment

**Decision:** Use Rust `1.88` as the baseline across services, docs, and CI.

Rationale: indexer and docs already assume Alloy `1.4+`, which requires Rust `1.88+`.

## Assumptions Made

- The MVP contract tests can be logically separated from arcade/game tests via Foundry `--no-match-path` filtering.
- Running `cargo nextest -p ghostnet-indexer` is an acceptable MVP service gate.

## Artifacts Created

- `docs/architecture/mvp-scope.md`
- `docs/architecture/overview.md`

## Changes Made

- Added MVP-focused `just` commands: `mvp-check`, `mvp-test`, `mvp-dev`
- Added indexer-focused service commands: `svc-check-mvp`, `svc-test-mvp`, `svc-indexer-dev`
- Updated CI Rust toolchain to `1.88`

## Next Steps

1. Validate `just mvp-check` passes end-to-end.
2. Add a short “MVP contract event catalog” shared between contracts/indexer/web.
3. Trim web routes/features so arcade pages don’t look “shippable” (naming + navigation).
