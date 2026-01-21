# GHOSTNET Event Indexer: Implementation Plan

> **Version**: 1.2.0  
> **Created**: 2026-01-21  
> **Last Updated**: 2026-01-21  
> **Status**: In Progress (Phases 3, 4, 6 Complete - Phase 7 or 8 Next)  
> **Reference**: See `indexer-architecture.md` for full specification

This document tracks the implementation progress of the GHOSTNET Event Indexer. Use this as the single source of truth for what's done, what's in progress, and what's next.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Implementation Principles](#2-implementation-principles)
3. [Phase Summary](#3-phase-summary)
4. [Detailed Phase Breakdown](#4-detailed-phase-breakdown)
5. [Dependency Graph](#5-dependency-graph)
6. [Risk Register](#6-risk-register)
7. [Decision Log](#7-decision-log)
8. [Session Notes](#8-session-notes)

---

## 1. Overview

### 1.1 What We're Building

A high-performance Rust-based event indexer that:
- Indexes all GHOSTNET smart contract events from MegaETH
- Persists data to TimescaleDB with time-series optimizations
- Streams events via Apache Iggy for real-time updates
- Exposes REST/WebSocket APIs for the frontend

### 1.2 Key Metrics

| Metric | Target |
|--------|--------|
| Block-to-client latency | < 500ms |
| API p99 response time | < 100ms |
| Reorg handling depth | 64 blocks |
| Availability | 99.9% |

### 1.3 Technology Stack

| Component | Technology | Version |
|-----------|------------|---------|
| Language | Rust | 1.88+ (Edition 2024) |
| Ethereum Client | Alloy | 1.4+ |
| Database | TimescaleDB | 2.22+ |
| Streaming | Apache Iggy | 0.6+ |
| API Framework | Axum | 0.7+ |

---

## 2. Implementation Principles

### 2.1 Phasing Strategy

1. **Foundation First**: Types, errors, and configuration before any logic
2. **Vertical Slice Early**: End-to-end flow for ONE event type to validate architecture
3. **Risk Front-Loading**: Tackle unknowns (Alloy, Iggy) before dependent features
4. **Incremental Value**: Each phase delivers testable, usable functionality

### 2.2 Quality Gates

Every phase must pass before moving to the next:

- [ ] All code compiles with zero warnings
- [ ] All tests pass (`cargo nextest run`)
- [ ] Clippy passes (`cargo clippy -- -D warnings`)
- [ ] Format check passes (`cargo fmt --check`)
- [ ] No new `unwrap()` or `expect()` in non-test code

### 2.3 Documentation Requirements

- Update this plan after completing each task
- Log significant decisions in the Decision Log
- Document lessons learned in `docs/lessons/`

---

## 3. Phase Summary

| Phase | Name | Duration | Status | Started | Completed |
|-------|------|----------|--------|---------|-----------|
| 0 | Project Scaffolding | 1 day | ✅ Complete | 2026-01-21 | 2026-01-21 |
| 1 | Type Foundation | 2 days | ✅ Complete | 2026-01-21 | 2026-01-21 |
| 2 | ABI Bindings | 2 days | ✅ Complete | 2026-01-21 | 2026-01-21 |
| 3 | Vertical Slice (Positions) | 5 days | ✅ Complete | 2026-01-21 | 2026-01-21 |
| 4 | WebSocket + Reorg Handling | 3 days | ✅ Complete | 2026-01-21 | 2026-01-21 |
| 5 | Complete Event Handlers | 5 days | ✅ Complete | 2026-01-21 | 2026-01-21 |
| 6 | Apache Iggy Streaming | 4 days | ✅ Complete | 2026-01-21 | 2026-01-21 |
| 7 | In-Memory Caching | 2 days | ✅ Complete | 2026-01-21 | 2026-01-21 |
| 8 | REST API | 6 days | Not Started | - | - |
| 9 | WebSocket Gateway | 3 days | Not Started | - | - |
| 10 | Continuous Aggregates | 3 days | Not Started | - | - |
| 11 | Observability | 2 days | Not Started | - | - |
| 12 | Production Hardening | 4 days | Not Started | - | - |

**Total Estimated Duration**: 42 days (~8-9 weeks)

---

## 4. Detailed Phase Breakdown

### Phase 0: Project Scaffolding

**Goal**: Set up project structure with all configuration files. Compilation succeeds.

**Duration**: 1 day

**Status**: ✅ Complete (2026-01-21)

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 0.1 | Create `services/ghostnet-indexer/` directory | [x] | |
| 0.2 | Run `cargo init --name ghostnet-indexer` | [x] | |
| 0.3 | Create `rust-toolchain.toml` (Rust 1.88) | [x] | Using Rust 1.88 Edition 2024 |
| 0.4 | Create `rustfmt.toml` (Edition 2024) | [x] | |
| 0.5 | Create `deny.toml` (dependency policy) | [x] | |
| 0.6 | Create `.cargo/config.toml` (fast linker) | [x] | Configured for macOS |
| 0.7 | Create `config/default.toml` | [x] | |
| 0.8 | Create `.env.example` | [x] | |
| 0.9 | Set up full `Cargo.toml` with dependencies | [x] | All deps from spec |
| 0.10 | Verify `cargo check` passes | [x] | |
| 0.11 | Verify `cargo clippy` passes | [x] | |

#### Deliverables

```
services/ghostnet-indexer/
├── Cargo.toml
├── Cargo.lock
├── rust-toolchain.toml
├── rustfmt.toml
├── deny.toml
├── .env.example
├── .cargo/
│   └── config.toml
├── config/
│   └── default.toml
└── src/
    ├── lib.rs
    └── main.rs
```

#### Acceptance Criteria

- [ ] `cargo check` succeeds
- [ ] `cargo clippy -- -D warnings` succeeds
- [ ] `cargo fmt --check` succeeds

---

### Phase 1: Type Foundation

**Goal**: Implement all core domain types with validation and tests.

**Duration**: 2 days

**Status**: ✅ Complete (2026-01-21)

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1.1 | Create `src/types/mod.rs` | [x] | Module exports |
| 1.2 | Implement `src/types/enums.rs` | [x] | Level, BoostType, RoundType, ExitReason |
| 1.3 | Implement `src/types/primitives.rs` | [x] | EthAddress, TokenAmount, GhostStreak, BlockNumber |
| 1.4 | Implement `src/types/events.rs` | [x] | EventMetadata, GhostnetEvent, all event structs |
| 1.5 | Implement `src/types/entities.rs` | [x] | Position, Scan, Death, Round, Bet, etc. |
| 1.6 | Implement `src/error.rs` | [x] | DomainError, InfraError, AppError, ApiError |
| 1.7 | Implement `src/config/mod.rs` | [x] | Settings with validation |
| 1.8 | Write unit tests for enums | [x] | TryFrom roundtrip |
| 1.9 | Write unit tests for primitives | [x] | Validation logic |
| 1.10 | Write property tests for Level | [ ] | Deferred - proptest setup later |

#### Files Created

- [x] `src/types/mod.rs`
- [x] `src/types/enums.rs`
- [x] `src/types/primitives.rs`
- [x] `src/types/events.rs`
- [x] `src/types/entities.rs`
- [x] `src/error.rs`
- [x] `src/config/mod.rs`
- [x] `src/config/settings.rs`

#### Acceptance Criteria

- [x] All types compile
- [x] All unit tests pass (125 tests as of Session 3)
- [ ] Property tests pass (deferred)
- [x] No `unwrap()` in non-test code

---

### Phase 2: ABI Bindings + Event Decoding

**Goal**: Generate type-safe ABI bindings and decode raw logs into typed events.

**Duration**: 2 days

**Status**: ✅ Complete (2026-01-21)

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 2.1 | Create `src/abi/mod.rs` | [x] | Module exports with ALL_SIGNATURES |
| 2.2 | Implement `src/abi/ghost_core.rs` | [x] | alloy::sol! macro |
| 2.3 | Implement `src/abi/trace_scan.rs` | [x] | |
| 2.4 | Implement `src/abi/dead_pool.rs` | [x] | |
| 2.5 | Implement `src/abi/data_token.rs` | [x] | |
| 2.6 | Implement `src/abi/fee_router.rs` | [x] | |
| 2.7 | Implement `src/abi/rewards_distributor.rs` | [x] | |
| 2.8 | Implement `src/indexer/log_decoder.rs` | [ ] | Deferred to Phase 3 |
| 2.9 | Write tests with sample log data | [x] | Signature verification tests |
| 2.10 | Test unknown event handling | [x] | Event router handles unknowns |

#### Files Created

- [x] `src/abi/mod.rs`
- [x] `src/abi/ghost_core.rs`
- [x] `src/abi/trace_scan.rs`
- [x] `src/abi/dead_pool.rs`
- [x] `src/abi/data_token.rs`
- [x] `src/abi/fee_router.rs`
- [x] `src/abi/rewards_distributor.rs`
- [x] `src/indexer/mod.rs`
- [ ] `src/indexer/log_decoder.rs` (deferred)

#### Acceptance Criteria

- [x] All ABI bindings compile
- [x] All event signatures verified unique
- [x] Unknown events handled gracefully (returns false, no panic)

---

### Phase 3: Vertical Slice (Positions)

**Goal**: End-to-end flow for position events. This validates the entire architecture.

**Duration**: 5 days

**Status**: ✅ Complete (2026-01-21)

**This was the highest-risk phase** - it proved the architecture works.

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 3.1 | Create `src/ports/` module | [x] | Split into clock, cache, store, streaming |
| 3.2 | Implement `src/indexer/block_processor.rs` | [x] | HTTP polling only (WS later) |
| 3.3 | Implement `src/indexer/event_router.rs` | [x] | Route to handlers |
| 3.4 | Create `src/handlers/mod.rs` | [x] | Module structure |
| 3.5 | Create `src/handlers/traits.rs` | [x] | Handler port traits (EventHandler) |
| 3.6 | Implement `src/handlers/position_handler.rs` | [x] | JackedIn, StakeAdded, Extracted, BoostApplied, PositionCulled |
| 3.7 | Create `src/store/mod.rs` | [x] | Store module with PostgresStore |
| 3.8 | Implement `src/store/postgres.rs` | [x] | SQLx implementation (Position, Scan, Death, IndexerState stores) |
| 3.9 | Create `migrations/00001_enable_timescaledb.sql` | [x] | Extension setup |
| 3.10 | Create `migrations/00002_indexer_state.sql` | [x] | indexer_state, block_hashes tables |
| 3.11 | Create `migrations/00003_positions.sql` | [x] | positions, position_history hypertables |
| 3.12 | Write mock store for unit tests | [x] | MockCache in ports/cache.rs, MockPositionStore in handlers |
| 3.13 | Write integration tests with testcontainers | [x] | 18 tests in tests/store_integration.rs |
| 3.14 | Test full flow: RPC → Handler → DB | [x] | 9 tests in tests/full_flow_integration.rs |
| 3.15 | Create `migrations/00004_scans_deaths.sql` | [x] | scans, deaths, level_stats, global_stats |
| 3.16 | Implement `src/indexer/realtime_processor.rs` | [x] | MegaETH WebSocket Realtime API (~10ms latency) |
| 3.17 | Add block timestamp caching | [x] | moka::future::Cache with 1hr TTL |

#### Files Created

- [x] `src/ports/mod.rs` (expanded from ports.rs)
- [x] `src/ports/clock.rs` (Clock trait + SystemClock + FakeClock)
- [x] `src/ports/cache.rs` (Cache trait + MockCache)
- [x] `src/ports/store.rs` (Store traits for all entities)
- [x] `src/ports/streaming.rs` (EventPublisher trait + MockEventPublisher)
- [x] `src/indexer/block_processor.rs`
- [x] `src/indexer/event_router.rs`
- [x] `src/indexer/realtime_processor.rs` (MegaETH Realtime API)
- [x] `src/handlers/mod.rs`
- [x] `src/handlers/traits.rs`
- [x] `src/handlers/position_handler.rs`
- [x] `src/store/mod.rs` (adapters)
- [x] `src/store/postgres.rs` (PositionStore, ScanStore, DeathStore, IndexerStateStore)
- [x] `migrations/20260121000001_enable_timescaledb.sql`
- [x] `migrations/20260121000002_indexer_state.sql`
- [x] `migrations/20260121000003_positions.sql`
- [x] `migrations/20260121000004_scans_deaths.sql`
- [x] `tests/common/mod.rs` (shared test utilities)
- [x] `tests/common/containers.rs` (TimescaleDB testcontainer)
- [x] `tests/common/fixtures.rs` (TestDb and fixture helpers)
- [x] `tests/store_integration.rs` (18 store integration tests)
- [x] `tests/full_flow_integration.rs` (9 end-to-end flow tests)

#### Acceptance Criteria

- [x] Can connect to MegaETH RPC (block_processor.rs with HTTP, realtime_processor.rs with WebSocket)
- [x] Can decode JackedIn events (via ABI bindings and EventRouter)
- [x] Can persist positions to TimescaleDB (PostgresStore implementation complete)
- [x] Integration tests pass with real TimescaleDB (18 store tests, 9 full flow tests)

---

### Phase 4: WebSocket Subscriptions + Reorg Handling

**Goal**: Real-time block processing with chain reorg resilience.

**Duration**: 3 days

**Status**: ✅ Complete (2026-01-21)

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 4.1 | Add WebSocket subscription to `block_processor.rs` | [x] | Done via `realtime_processor.rs` using MegaETH Realtime API |
| 4.2 | Implement `src/indexer/reorg_handler.rs` | [x] | ReorgHandler with detect/execute methods |
| 4.3 | Implement `src/indexer/checkpoint.rs` | [x] | CheckpointManager with recovery modes |
| 4.4 | Add block_history table migration | [x] | `block_hashes` table in migration 00002 |
| 4.5 | Implement reorg rollback SQL function | [x] | IndexerStateStore.execute_reorg_rollback() |
| 4.6 | Write reorg simulation tests | [x] | 10 tests in tests/reorg_integration.rs |
| 4.7 | Test checkpoint recovery | [x] | 8 tests in tests/reorg_integration.rs |

#### Files Created/Modified

- [x] `src/indexer/block_processor.rs` (modified)
- [x] `src/indexer/reorg_handler.rs` (ReorgHandler, ReorgCheckResult, ReorgStats)
- [x] `src/indexer/checkpoint.rs` (CheckpointManager, RecoveryMode, CheckpointState)
- [x] Migration for `block_history` table (in 00002)
- [x] `tests/reorg_integration.rs` (18 reorg/checkpoint integration tests)

#### Acceptance Criteria

- [x] Real-time block subscription works (via realtime_processor.rs)
- [x] Reorg detection triggers rollback (ReorgHandler.check_for_reorg + execute_rollback)
- [x] Indexer recovers from restart at correct block (CheckpointManager with recovery modes)

---

### Phase 5: Complete Event Handlers

**Goal**: Handle ALL event types from all contracts.

**Duration**: 5 days

**Status**: ✅ Complete (2026-01-21)

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 5.1 | Add BoostApplied, PositionCulled to position_handler | [x] | Implemented in position_handler.rs |
| 5.2 | Implement `src/handlers/scan_handler.rs` | [x] | ScanExecuted, ScanFinalized |
| 5.3 | Implement `src/handlers/death_handler.rs` | [x] | DeathsProcessed, SurvivorsUpdated, CascadeDistributed, SystemResetTriggered |
| 5.4 | Implement `src/handlers/market_handler.rs` | [x] | RoundCreated, BetPlaced, RoundResolved, WinningsClaimed |
| 5.5 | Implement `src/handlers/token_handler.rs` | [x] | Transfer, TaxExclusionSet (logging-only) |
| 5.6 | Implement `src/handlers/fee_handler.rs` | [x] | TollCollected, BuybackExecuted (logging-only) |
| 5.7 | Implement `src/handlers/emissions_handler.rs` | [x] | EmissionsDistributed, VestingScheduled (logging-only) |
| 5.8 | Write comprehensive tests for each handler | [x] | 203 tests total |

#### Files Created

- [x] `src/handlers/scan_handler.rs`
- [x] `src/handlers/death_handler.rs`
- [x] `src/handlers/market_handler.rs`
- [x] `src/handlers/token_handler.rs`
- [x] `src/handlers/fee_handler.rs`
- [x] `src/handlers/emissions_handler.rs`

#### Acceptance Criteria

- [x] All event types can be processed
- [x] All handlers have unit tests (203 tests)
- [x] Database schema complete (migrations already exist from Phase 3)

---

### Phase 6: Apache Iggy Streaming

**Goal**: Real-time event broadcasting for live feeds.

**Duration**: 4 days

**Status**: ✅ Complete (2026-01-21)

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 6.1 | Create `src/streaming/mod.rs` | [x] | Module exports, documentation |
| 6.2 | Implement `src/streaming/iggy_publisher.rs` | [x] | IggyPublisher + NoOpPublisher |
| 6.3 | Implement `src/streaming/topics.rs` | [x] | 7 topics, event routing |
| 6.4 | Add Serialize/Deserialize to GhostnetEvent | [x] | JSON transport |
| 6.5 | Implement EventPublisher trait | [x] | publish, publish_batch, flush |
| 6.6 | Add Iggy to docker-compose.yml | [ ] | Deferred to Phase 12 |
| 6.7 | Write unit tests | [x] | NoOpPublisher, topic routing |

#### Files Created

- [x] `src/streaming/mod.rs`
- [x] `src/streaming/iggy_publisher.rs`
- [x] `src/streaming/topics.rs`
- [ ] `docker-compose.yml` (deferred to Phase 12)

#### Acceptance Criteria

- [x] IggyPublisher implements EventPublisher trait
- [x] Events routed to correct topics (7 topics: positions, scans, deaths, market, system, token, fees)
- [x] NoOpPublisher for testing/disabled streaming
- [x] Auto-connect on first publish (lazy initialization)
- [ ] Integration test with real Iggy server (deferred)

---

### Phase 7: In-Memory Caching

**Goal**: Fast access to hot data.

**Duration**: 2 days

**Status**: ✅ Complete (2026-01-21)

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 7.1 | Implement `src/store/cache.rs` | [x] | moka + dashmap |
| 7.2 | Add Cache port trait | [x] | Already existed in ports/cache.rs; exported CacheStats |
| 7.3 | Add level stats and leaderboard caching | [x] | Extended API beyond base trait |
| 7.4 | Add rate limiting with dashmap | [x] | Sliding window with cleanup |
| 7.5 | Add block hash cache for reorg detection | [x] | 128 blocks, 5 min TTL |
| 7.6 | Write cache tests | [x] | 21 tests covering all operations |

#### Files Created

- [x] `src/store/cache.rs` (MemoryCache with moka + dashmap)

#### Acceptance Criteria

- [x] Position lookups hit cache (with negative caching support)
- [x] Cache invalidated on writes (by position, by level, all)
- [x] Rate limiting works (sliding window with cleanup mechanism)

---

### Phase 8: REST API

**Goal**: HTTP API for clients.

**Duration**: 6 days

**Status**: Not Started

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 8.1 | Implement `src/api/server.rs` | [ ] | Axum setup |
| 8.2 | Implement `src/api/routes/positions.rs` | [ ] | |
| 8.3 | Implement `src/api/routes/scans.rs` | [ ] | |
| 8.4 | Implement `src/api/routes/markets.rs` | [ ] | |
| 8.5 | Implement `src/api/routes/leaderboards.rs` | [ ] | |
| 8.6 | Implement `src/api/routes/analytics.rs` | [ ] | |
| 8.7 | Implement `src/api/middleware.rs` | [ ] | CORS, rate limiting |
| 8.8 | Implement `src/utils/health.rs` | [ ] | |
| 8.9 | Write API endpoint tests | [ ] | |
| 8.10 | Document API (OpenAPI spec) | [ ] | |

#### Files Created

- [ ] `src/api/mod.rs`
- [ ] `src/api/server.rs`
- [ ] `src/api/routes/mod.rs`
- [ ] `src/api/routes/positions.rs`
- [ ] `src/api/routes/scans.rs`
- [ ] `src/api/routes/markets.rs`
- [ ] `src/api/routes/leaderboards.rs`
- [ ] `src/api/routes/analytics.rs`
- [ ] `src/api/middleware.rs`
- [ ] `src/utils/mod.rs`
- [ ] `src/utils/health.rs`

#### Acceptance Criteria

- [ ] All endpoints respond correctly
- [ ] CORS configured
- [ ] Rate limiting works
- [ ] Health checks pass

---

### Phase 9: WebSocket Gateway

**Goal**: Real-time event streaming to browsers.

**Duration**: 3 days

**Status**: Not Started

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 9.1 | Implement `src/api/websocket.rs` | [ ] | |
| 9.2 | Implement Iggy → WebSocket bridge | [ ] | |
| 9.3 | Add subscription filtering | [ ] | |
| 9.4 | Write WebSocket tests | [ ] | |

#### Files Created

- [ ] `src/api/websocket.rs`

#### Acceptance Criteria

- [ ] Browsers can connect via WebSocket
- [ ] Events streamed in real-time
- [ ] Connection handling robust

---

### Phase 10: Continuous Aggregates + Analytics

**Goal**: Pre-computed analytics for dashboards.

**Duration**: 3 days

**Status**: Not Started

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 10.1 | Create `migrations/00007_continuous_aggregates.sql` | [ ] | |
| 10.2 | Create `migrations/00008_retention_policies.sql` | [ ] | |
| 10.3 | Update analytics API to use aggregates | [ ] | |
| 10.4 | Test aggregate refresh | [ ] | |

#### Files Created

- [ ] `migrations/00007_continuous_aggregates.sql`
- [ ] `migrations/00008_retention_policies.sql`

#### Acceptance Criteria

- [ ] Continuous aggregates created
- [ ] Retention policies active
- [ ] Analytics queries fast

---

### Phase 11: Observability

**Goal**: Production-ready monitoring.

**Duration**: 2 days

**Status**: Not Started

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 11.1 | Implement `src/utils/metrics.rs` | [ ] | Prometheus |
| 11.2 | Implement `src/utils/logging.rs` | [ ] | Structured JSON |
| 11.3 | Add metrics to all components | [ ] | |
| 11.4 | Add tracing spans | [ ] | |
| 11.5 | Create Grafana dashboards | [ ] | Optional |

#### Files Created

- [ ] `src/utils/metrics.rs`
- [ ] `src/utils/logging.rs`

#### Acceptance Criteria

- [ ] Prometheus metrics exposed at /metrics
- [ ] Structured JSON logs
- [ ] Key metrics tracked (block lag, latency, errors)

---

### Phase 12: Production Hardening

**Goal**: Deploy-ready artifact.

**Duration**: 4 days

**Status**: Not Started

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 12.1 | Create `Dockerfile` | [ ] | Multi-stage |
| 12.2 | Create/update `docker-compose.yml` | [ ] | Full stack |
| 12.3 | Create CI/CD workflow | [ ] | GitHub Actions |
| 12.4 | Write load tests | [ ] | |
| 12.5 | Security audit (`cargo deny`, `cargo audit`) | [ ] | |
| 12.6 | Write README | [ ] | |

#### Files Created

- [ ] `Dockerfile`
- [ ] `docker-compose.yml`
- [ ] `.github/workflows/indexer-ci.yml`
- [ ] `README.md`

#### Acceptance Criteria

- [ ] Docker image builds
- [ ] CI pipeline passes
- [ ] Load test passes
- [ ] Security audit clean

---

## 5. Dependency Graph

```
Phase 0 (Scaffolding)
    │
    ▼
Phase 1 (Types)
    │
    ▼
Phase 2 (ABI Bindings)
    │
    ▼
Phase 3 (Vertical Slice) ◀─── CRITICAL PATH
    │
    ├──────────────────┐
    ▼                  ▼
Phase 4 (WS+Reorg)  Phase 5 (Handlers)
    │                  │
    └────────┬─────────┘
             ▼
         Phase 6 (Iggy)
             │
             ▼
         Phase 7 (Cache)
             │
             ▼
         Phase 8 (REST API) ◀─── FRONTEND UNBLOCKED
             │
             ├──────────────────┐
             ▼                  ▼
         Phase 9 (WS)      Phase 10 (Analytics)
             │                  │
             └────────┬─────────┘
                      ▼
              Phase 11 (Observability)
                      │
                      ▼
              Phase 12 (Production)
```

**Critical Path**: 0 → 1 → 2 → 3 → 4/5 → 6 → 8 → 12

---

## 6. Risk Register

| ID | Risk | Likelihood | Impact | Mitigation | Status |
|----|------|------------|--------|------------|--------|
| R1 | Alloy 1.4+ API changed from spec | Medium | High | Check latest docs/examples before Phase 2 | Open |
| R2 | Iggy 0.6 API unstable | Medium | Medium | Pin version, check examples | Mitigated - implemented successfully |
| R3 | TimescaleDB compression issues | Low | Medium | Test with realistic data volumes | Open |
| R4 | MegaETH RPC rate limits | Medium | Medium | Implement backoff, use WS subscriptions | Open |
| R5 | Rust 1.88 not released | Low | High | Fall back to 1.85 if needed | Open |

---

## 7. Decision Log

Record significant architectural decisions here.

| Date | Decision | Rationale | Alternatives Considered |
|------|----------|-----------|------------------------|
| 2026-01-21 | Start with HTTP polling, add WS later | Simpler to debug, proves architecture | WS from start |
| 2026-01-21 | Use MegaETH Realtime API for WebSocket | ~10ms latency vs 1s+ for standard Ethereum | Standard eth_subscribe |
| 2026-01-21 | Use composite PKs for TimescaleDB hypertables | TimescaleDB requires partitioning column in PK | Regular tables, drop PK constraint |
| 2026-01-21 | No foreign keys on hypertables | TimescaleDB doesn't support FKs FROM hypertables | Application-level enforcement |
| 2026-01-21 | moka::future::Cache for block timestamps | Async cache matches async context, 1hr TTL since timestamps immutable | DashMap, sync Cache |
| 2026-01-21 | 7 Iggy topics by domain | Allows clients to subscribe only to relevant events | Single topic, per-event-type topics |
| 2026-01-21 | Lazy Iggy initialization | Auto-connect and create stream/topics on first publish | Eager initialization at startup |
| 2026-01-21 | NoOpPublisher for disabled streaming | Clean way to disable streaming without code changes | Feature flag, Option<Publisher> |

---

## 8. Session Notes

### Session 1: 2026-01-21 (Planning)

**What was done**:
- Reviewed full architecture spec (6600+ lines)
- Created this implementation plan
- Identified 12 phases with detailed tasks

**Decisions made**:
- Will start with HTTP polling in Phase 3, add WS in Phase 4
- Will verify Rust/Alloy versions before Phase 0

**Next steps**:
- Begin Phase 0: Project Scaffolding
- Verify Alloy 1.4+ MSRV requirement

**Blockers**: None

---

### Session 2: 2026-01-21 (Implementation Sprint)

**What was done**:
- Completed Phase 0: Full project scaffolding with Rust 1.88, Edition 2024
- Completed Phase 1: All domain types (enums, primitives, events, entities, errors, config)
- Completed Phase 2: All ABI bindings for 6 contracts (GhostCore, TraceScan, DeadPool, DataToken, FeeRouter, RewardsDistributor)
- Phase 3 partial: Event router, handler traits, and comprehensive port interfaces
- Port interfaces implemented: Clock, Cache, Store (6 traits), EventPublisher
- Added `test-utils` feature for downstream mock usage
- Code review performed - fixed missing chrono trait imports and test-utils export

**Decisions made**:
- Split `ports.rs` into `ports/` module with separate files for each concern
- Used `async_trait` for async port traits (standard pattern)
- Made FakeClock thread-safe using AtomicI64 instead of Mutex
- Store traits split by entity (PositionStore, ScanStore, etc.) for flexibility

**Test coverage**:
- 106 unit tests passing
- All ABI event signatures verified unique
- Clock, cache, and streaming mocks tested

**Next steps**:
- 3.2: Implement `block_processor.rs` (HTTP polling)
- 3.6: Implement `position_handler.rs` 
- 3.7-3.8: Store adapters (PostgreSQL with SQLx)
- 3.9-3.11: Database migrations

**Blockers**: None

---

### Session 3: 2026-01-21 (Phase 3 Store & Migrations)

**What was done**:
- Implemented `src/store/mod.rs` and `src/store/postgres.rs` with full SQLx implementation
- Created 4 TimescaleDB migrations: enable_timescaledb, indexer_state, positions, scans_deaths
- Implemented `src/indexer/realtime_processor.rs` for MegaETH Realtime API (WebSocket with ~10ms latency)
- Added block timestamp caching with moka::future::Cache (10K entries, 1hr TTL)
- Added `SubscriptionResult` enum for smarter reconnection logic
- Fixed critical TimescaleDB hypertable bug (composite primary keys required)
- Added `ExitReason::Superseded` for handling duplicate JackedIn events
- Code review performed and all critical findings addressed

**Store implementations complete**:
- PositionStore: 6 methods (get_active_position, save_position, get_at_risk_positions, etc.)
- ScanStore: 5 methods (save_scan, finalize_scan, get_recent_scans, etc.)
- DeathStore: 5 methods (record_deaths, get_deaths_for_scan, etc.)
- IndexerStateStore: 6 methods (reorg handling, block hash tracking, pruning)
- MarketStore/StatsStore: placeholder implementations

**Database schema complete**:
- `indexer_state`: track last indexed block
- `block_hashes`: reorg detection (256-block window)
- `positions`: hypertable partitioned by entry_timestamp
- `position_history`: audit trail hypertable
- `scans`: scan events hypertable
- `deaths`: death records hypertable
- `level_stats`: pre-computed per-level statistics
- `global_stats`: protocol-wide statistics

**Test coverage**:
- 125 unit tests passing
- MockPositionStore with RwLock for handler tests
- Block cache behavior tests

**Commits**:
- `c039546` feat(indexer): add block timestamp caching and complete position handler
- `71db063` feat(indexer): add PostgreSQL store adapter and TimescaleDB migrations
- `0176999` fix(indexer): address code review findings

**Next steps**:
- 3.13-3.14: Integration tests with testcontainers-postgres
- Phase 4: WebSocket subscriptions (partially complete via realtime_processor)
- Phase 5: Complete remaining event handlers (scan_handler, death_handler, etc.)

**Blockers**: None

---

### Session 4: 2026-01-21 (Phase 5 Completion + Clippy Fixes)

**What was done**:
- Fixed 101 clippy errors that were blocking compilation
- All 7 event handlers confirmed complete and tested:
  - `position_handler.rs` - JackedIn, StakeAdded, Extracted, BoostApplied, PositionCulled
  - `scan_handler.rs` - ScanExecuted, ScanFinalized
  - `death_handler.rs` - DeathsProcessed, SurvivorsUpdated, CascadeDistributed, SystemResetTriggered
  - `market_handler.rs` - RoundCreated, BetPlaced, RoundResolved, WinningsClaimed
  - `token_handler.rs` - Transfer, TaxExclusionSet (logging-only)
  - `fee_handler.rs` - TollCollected, BuybackExecuted (logging-only)
  - `emissions_handler.rs` - EmissionsDistributed, VestingScheduled (logging-only)
- Applied clippy lint configuration for database conversion code
- Updated Phase 5 to Complete status

**Fixes applied**:
- `doc_markdown` and `needless_raw_string_hashes` allowed crate-wide (documentation style)
- `cast_*` lints allowed in postgres.rs (safe DB boundary conversions)
- `cast_precision_loss` allowed for progress percentages (display only)
- Format string inlining (uninlined_format_args)
- let-else pattern in scan_handler
- const fn for PositionHandler::new and to_eth_address

**Test coverage**:
- 203 unit tests passing
- All handlers have comprehensive test coverage

**Commits**:
- (pending) fix(indexer): resolve clippy errors and update implementation plan

**Next steps**:
- Phase 6: Implement Apache Iggy streaming
- Or: Phase 8: Start REST API (unblocks frontend faster)

**Blockers**: None

---

### Session 5: 2026-01-21 (Phase 6 Apache Iggy Streaming)

**What was done**:
- Completed Phase 6: Apache Iggy Streaming integration
- Created `src/streaming/mod.rs` with module documentation and exports
- Created `src/streaming/topics.rs` with 7 topic definitions and event routing
- Created `src/streaming/iggy_publisher.rs` with IggyPublisher and NoOpPublisher
- Added `Serialize, Deserialize` to GhostnetEvent for JSON transport
- Changed `InfraError::Streaming` from `Box<dyn Error>` to `String` for simplicity
- Added `bytes` dependency for Iggy message payloads
- Code review performed and findings addressed:
  - Added separate `connected` state tracking (was incorrectly using `initialized`)
  - Added auto-connect in `ensure_initialized()` for lazy connection
  - Exported `NoOpPublisher` from streaming module
  - Fixed module documentation (added all 7 topics, fixed async example)

**Implementation details**:
- 7 topics: positions, scans, deaths, market, system, token, fees
- Event routing via `Topic::for_event()` const fn with exhaustive matching
- Double-checked locking for thread-safe lazy initialization
- Race condition handling for concurrent stream/topic creation
- IggyClient uses TCP transport with configurable server address

**Test coverage**:
- 210 unit tests passing
- NoOpPublisher behavior tests
- Topic routing tests

**Commits**:
- `93653ee` feat(indexer): add Phase 6 Apache Iggy streaming integration
- `f44bb67` fix(indexer): address code review findings for Phase 6 streaming

**Next steps**:
- Phase 7: Complete in-memory caching (position lookups, cache invalidation)
- Phase 8: REST API (unblocks frontend)

**Blockers**: None

---

### Session Template

```markdown
### Session N: YYYY-MM-DD (Topic)

**What was done**:
- 

**Decisions made**:
- 

**Next steps**:
- 

**Blockers**:
- 
```

---

## Appendix: Quick Reference

### Commands

```bash
# Build
just svc-build

# Test
just svc-test

# Lint
just svc-lint

# Full check (before commit)
just svc-check

# Run migrations
sqlx migrate run

# Start dev stack
docker-compose up -d
```

### Key Files

| Purpose | Location |
|---------|----------|
| Architecture Spec | `docs/architecture/backend/indexer-architecture.md` |
| This Plan | `docs/architecture/backend/indexer-implementation-plan.md` |
| Project Root | `services/ghostnet-indexer/` |
| Migrations | `services/ghostnet-indexer/migrations/` |
| Config | `services/ghostnet-indexer/config/` |

### Contacts

| Role | Contact |
|------|---------|
| Tech Lead | TBD |
| Product | TBD |

---

*Update this document after each session. Keep it as the single source of truth.*
