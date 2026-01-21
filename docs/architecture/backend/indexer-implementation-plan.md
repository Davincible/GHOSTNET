# GHOSTNET Event Indexer: Implementation Plan

> **Version**: 1.0.0  
> **Created**: 2026-01-21  
> **Last Updated**: 2026-01-21  
> **Status**: Planning  
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
| 0 | Project Scaffolding | 1 day | Complete | 2026-01-21 | 2026-01-21 |
| 1 | Type Foundation | 2 days | Complete | 2026-01-21 | 2026-01-21 |
| 2 | ABI Bindings | 2 days | Complete | 2026-01-21 | 2026-01-21 |
| 3 | Vertical Slice (Positions) | 5 days | In Progress | 2026-01-21 | - |
| 4 | WebSocket + Reorg Handling | 3 days | Not Started | - | - |
| 5 | Complete Event Handlers | 5 days | Not Started | - | - |
| 6 | Apache Iggy Streaming | 4 days | Not Started | - | - |
| 7 | In-Memory Caching | 2 days | Not Started | - | - |
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
- [x] All unit tests pass (106 tests)
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

**Status**: 🟡 In Progress (started 2026-01-21)

**This is the highest-risk phase** - it proves the architecture works.

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 3.1 | Create `src/ports/` module | [x] | Split into clock, cache, store, streaming |
| 3.2 | Implement `src/indexer/block_processor.rs` | [ ] | HTTP polling only (WS later) |
| 3.3 | Implement `src/indexer/event_router.rs` | [x] | Route to handlers |
| 3.4 | Create `src/handlers/mod.rs` | [x] | Module structure |
| 3.5 | Create `src/handlers/traits.rs` | [x] | Handler port traits (EventHandler) |
| 3.6 | Implement `src/handlers/position_handler.rs` | [ ] | JackedIn, StakeAdded, Extracted |
| 3.7 | Create `src/store/mod.rs` | [ ] | Store module (adapters) |
| 3.8 | Implement `src/store/postgres.rs` | [ ] | SQLx implementation |
| 3.9 | Create `migrations/00001_enable_timescaledb.sql` | [ ] | |
| 3.10 | Create `migrations/00002_indexer_state.sql` | [ ] | |
| 3.11 | Create `migrations/00003_positions.sql` | [ ] | |
| 3.12 | Write mock store for unit tests | [x] | MockCache in ports/cache.rs |
| 3.13 | Write integration tests with testcontainers | [ ] | |
| 3.14 | Test full flow: RPC → Handler → DB | [ ] | |

#### Files Created

- [x] `src/ports/mod.rs` (expanded from ports.rs)
- [x] `src/ports/clock.rs` (Clock trait + SystemClock + FakeClock)
- [x] `src/ports/cache.rs` (Cache trait + MockCache)
- [x] `src/ports/store.rs` (Store traits for all entities)
- [x] `src/ports/streaming.rs` (EventPublisher trait + MockEventPublisher)
- [ ] `src/indexer/block_processor.rs`
- [x] `src/indexer/event_router.rs`
- [x] `src/handlers/mod.rs`
- [x] `src/handlers/traits.rs`
- [ ] `src/handlers/position_handler.rs`
- [ ] `src/store/mod.rs` (adapters)
- [ ] `src/store/postgres.rs`
- [ ] `migrations/00001_enable_timescaledb.sql`
- [ ] `migrations/00002_indexer_state.sql`
- [ ] `migrations/00003_positions.sql`
- [ ] `tests/common/mocks.rs`

#### Acceptance Criteria

- [ ] Can connect to MegaETH RPC
- [ ] Can decode JackedIn events
- [ ] Can persist positions to TimescaleDB
- [ ] Integration tests pass with real TimescaleDB

---

### Phase 4: WebSocket Subscriptions + Reorg Handling

**Goal**: Real-time block processing with chain reorg resilience.

**Duration**: 3 days

**Status**: Not Started

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 4.1 | Add WebSocket subscription to `block_processor.rs` | [ ] | Alloy 1.4+ pattern |
| 4.2 | Implement `src/indexer/reorg_handler.rs` | [ ] | |
| 4.3 | Implement `src/indexer/checkpoint.rs` | [ ] | Progress tracking |
| 4.4 | Add block_history table migration | [ ] | For reorg detection |
| 4.5 | Implement reorg rollback SQL function | [ ] | |
| 4.6 | Write reorg simulation tests | [ ] | |
| 4.7 | Test checkpoint recovery | [ ] | |

#### Files Created/Modified

- [ ] `src/indexer/block_processor.rs` (modified)
- [ ] `src/indexer/reorg_handler.rs`
- [ ] `src/indexer/checkpoint.rs`
- [ ] Migration for `block_history` table

#### Acceptance Criteria

- [ ] Real-time block subscription works
- [ ] Reorg detection triggers rollback
- [ ] Indexer recovers from restart at correct block

---

### Phase 5: Complete Event Handlers

**Goal**: Handle ALL event types from all contracts.

**Duration**: 5 days

**Status**: Not Started

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 5.1 | Add BoostApplied, PositionCulled to position_handler | [ ] | |
| 5.2 | Implement `src/handlers/scan_handler.rs` | [ ] | |
| 5.3 | Implement `src/handlers/death_handler.rs` | [ ] | |
| 5.4 | Implement `src/handlers/market_handler.rs` | [ ] | |
| 5.5 | Implement `src/handlers/token_handler.rs` | [ ] | |
| 5.6 | Implement `src/handlers/fee_handler.rs` | [ ] | |
| 5.7 | Create `migrations/00004_scans.sql` | [ ] | |
| 5.8 | Create `migrations/00005_markets.sql` | [ ] | |
| 5.9 | Create `migrations/00006_analytics.sql` | [ ] | |
| 5.10 | Write tests for each handler | [ ] | |

#### Files Created

- [ ] `src/handlers/scan_handler.rs`
- [ ] `src/handlers/death_handler.rs`
- [ ] `src/handlers/market_handler.rs`
- [ ] `src/handlers/token_handler.rs`
- [ ] `src/handlers/fee_handler.rs`
- [ ] `migrations/00004_scans.sql`
- [ ] `migrations/00005_markets.sql`
- [ ] `migrations/00006_analytics.sql`

#### Acceptance Criteria

- [ ] All event types can be processed
- [ ] All handlers have unit tests
- [ ] Database schema complete

---

### Phase 6: Apache Iggy Streaming

**Goal**: Real-time event broadcasting for live feeds.

**Duration**: 4 days

**Status**: Not Started

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 6.1 | Create `src/streaming/mod.rs` | [ ] | |
| 6.2 | Implement `src/streaming/iggy.rs` | [ ] | Client wrapper |
| 6.3 | Implement `src/streaming/publisher.rs` | [ ] | |
| 6.4 | Implement `src/streaming/topics.rs` | [ ] | |
| 6.5 | Update handlers to publish events | [ ] | |
| 6.6 | Add Iggy to docker-compose.yml | [ ] | |
| 6.7 | Write integration tests | [ ] | |

#### Files Created

- [ ] `src/streaming/mod.rs`
- [ ] `src/streaming/iggy.rs`
- [ ] `src/streaming/publisher.rs`
- [ ] `src/streaming/topics.rs`
- [ ] `docker-compose.yml` (or modify)

#### Acceptance Criteria

- [ ] Events published to Iggy after DB write
- [ ] Can consume from Iggy topics
- [ ] Integration test passes

---

### Phase 7: In-Memory Caching

**Goal**: Fast access to hot data.

**Duration**: 2 days

**Status**: Not Started

#### Tasks

| # | Task | Status | Notes |
|---|------|--------|-------|
| 7.1 | Implement `src/store/cache.rs` | [ ] | moka + dashmap |
| 7.2 | Add Cache port trait | [ ] | |
| 7.3 | Update handlers for cache invalidation | [ ] | |
| 7.4 | Add rate limiting with dashmap | [ ] | |
| 7.5 | Write cache tests | [ ] | |

#### Files Created

- [ ] `src/store/cache.rs`

#### Acceptance Criteria

- [ ] Position lookups hit cache
- [ ] Cache invalidated on writes
- [ ] Rate limiting works

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
| R2 | Iggy 0.6 API unstable | Medium | Medium | Pin version, check examples | Open |
| R3 | TimescaleDB compression issues | Low | Medium | Test with realistic data volumes | Open |
| R4 | MegaETH RPC rate limits | Medium | Medium | Implement backoff, use WS subscriptions | Open |
| R5 | Rust 1.88 not released | Low | High | Fall back to 1.85 if needed | Open |

---

## 7. Decision Log

Record significant architectural decisions here.

| Date | Decision | Rationale | Alternatives Considered |
|------|----------|-----------|------------------------|
| 2026-01-21 | Start with HTTP polling, add WS later | Simpler to debug, proves architecture | WS from start |
| | | | |

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
