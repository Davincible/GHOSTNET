---
type: epic
status: ready
created: 2026-02-07
updated: 2026-02-07
depends_on:
  - "[[EPIC-002-ishizue-foundation]]"
tags:
  - type/epic
  - feature/services
  - status/ready
---

# EPIC-003: ghostnet-api Service

## Summary

Build the `ghostnet-api` Ishizue service — the canonical off-chain projection of GHOSTNET's on-chain state. This is the primary data service: it ingests MegaETH chain events, persists them to TimescaleDB, publishes to Apache Iggy, and serves query APIs over REST, gRPC, and WebSocket.

This replaces the old hand-wired `ghostnet-indexer`. We cherry-pick the valuable logic (block processor, event router, postgres adapter, handlers) and wire it through Ishizue's handler/component patterns.

## Motivation

The game can't run without this. Every piece of frontend UI that shows positions, scans, deaths, stats, or live events depends on this service working correctly. It's the biggest and most complex service, so we build it incrementally — one layer at a time, tested at each step.

## Scope

### In Scope

- Implement `ApiServiceHandler` (generated from proto) — query endpoints
- Postgres adapter implementing domain port traits (cherry-picked from old indexer)
- Ingestion pipeline: block processor, event router, event handlers (cherry-picked, registered as Ishizue Components)
- Reorg detection and rollback
- Iggy publisher for event streaming
- Moka cache layer
- WebSocket / SSE streaming for real-time events
- Integration tests against real TimescaleDB (container)
- End-to-end tests (real HTTP requests to running service)

### Out of Scope

- Fleet / signer endpoints (those are separate services)
- Automated keeper triggering scans (that's a contract/keeper concern)
- CI/CD pipeline, Docker images (later epic)

## Success Criteria

- [ ] Query handlers return correct data from Postgres for: positions, scans, stats, leaderboard
- [ ] Full ingestion pipeline works: chain event → event router → handler → Postgres → query
- [ ] Reorg rollback correctly removes orphaned data
- [ ] Scan two-phase lifecycle (ScanExecuted → ScanFinalized) persists correctly
- [ ] WebSocket/SSE streaming delivers events to connected clients
- [ ] Integration tests pass against real TimescaleDB container
- [ ] E2E test: start service, hit REST endpoints, get correct responses
- [ ] Performance: query latency < 50ms p99, event ingestion < 100ms per block
- [ ] Any Ishizue framework issues logged in `docs/learnings/ishizue-framework-issues.md`

---

## Stories

| Story | Title | Status | Wave |
|-------|-------|--------|------|
| [[STORY-0020-postgres-adapter]] | Postgres Adapter | 🟣 Ready | 1 |
| [[STORY-0021-query-handlers]] | Query Handlers | 🟣 Ready | 1 |
| [[STORY-0022-ingestion-pipeline]] | Ingestion Pipeline | 🟣 Ready | 2 |
| [[STORY-0023-event-handlers]] | Event Handlers (Domain Services) | 🟣 Ready | 2 |
| [[STORY-0024-streaming]] | WebSocket / Event Streaming | 🟣 Ready | 3 |
| [[STORY-0025-cache-layer]] | Cache Layer | 🟣 Ready | 3 |

---

## Execution Order

**Pattern:** Waves — each wave adds a layer, tested before moving on.

### Wave 1: Query Path (The Read Side)

- **STORY-0020** → **STORY-0021** — Adapter first (it implements the port traits), then handlers (they use the adapter).
- At the end of this wave: `GetPosition`, `ListPositions`, `GetScan`, `GetGlobalStats` all work against a seeded database.
- **Max agents:** 1 (sequential — handler depends on adapter)

**Test checkpoint:** Integration test seeds Postgres, calls handler, verifies response.

### Wave 2: Write Path (Ingestion)

*Requires: Wave 1 complete (adapter exists to write to)*

- **STORY-0022** ∥ **STORY-0023** — Block processor and event handlers can be built in parallel. The block processor produces decoded events; the event handlers consume them.
- At the end of this wave: a fake block with a JackedIn event flows through the full pipeline and appears in Postgres.
- **Max agents:** 2

**Test checkpoint:** Integration test feeds a raw log through the event router, queries the handler, verifies the position exists.

### Wave 3: Real-Time + Polish

*Requires: Wave 2 complete (events flow into the database)*

- **STORY-0024** ∥ **STORY-0025** — Streaming and cache are independent.
- At the end of this wave: a WebSocket client can subscribe and receive events, queries are cached.
- **Max agents:** 2

**Test checkpoint:** E2E test starts the service, connects WebSocket, ingests an event, verifies it arrives over the WebSocket.

| Wave | Stories | Agents | Notes |
|------|---------|--------|-------|
| 1 | 2 | 1 | Read path: adapter → handlers (sequential) |
| 2 | 2 | 2 | Write path: block processor ∥ event handlers |
| 3 | 2 | 2 | Real-time: WebSocket ∥ cache |

---

## Technical Approach

**Layer by layer, cherry-picking from old indexer:**

| Layer | Old source | New location | Ishizue pattern |
|-------|-----------|-------------|-----------------|
| Domain types | `ghostnet-indexer/src/types/*` | `libs/ghostnet-domain/` (from EPIC-002) | N/A (plain crate) |
| Port traits | `ghostnet-indexer/src/ports/*` | `libs/ghostnet-domain/` (from EPIC-002) | N/A (plain traits) |
| Postgres adapter | `ghostnet-indexer/src/store/postgres.rs` | `services/ghostnet-api/src/adapters/` | Implements domain ports |
| Query handlers | (new) | `services/ghostnet-api/src/handlers/api.rs` | `#[ishizue::handler]` impl |
| Block processor | `ghostnet-indexer/src/indexer/block_processor.rs` | `services/ghostnet-api/src/ingestion/` | Ishizue `Component` |
| Event router | `ghostnet-indexer/src/indexer/event_router.rs` | `services/ghostnet-api/src/ingestion/` | Internal wiring |
| Event handlers | `ghostnet-indexer/src/handlers/*.rs` | `services/ghostnet-api/src/domain/` | Domain services |
| Reorg handler | `ghostnet-indexer/src/indexer/reorg_handler.rs` | `services/ghostnet-api/src/ingestion/` | Internal logic |
| Iggy publisher | `ghostnet-indexer/src/streaming/iggy_publisher.rs` | `services/ghostnet-api/src/adapters/` | Ishizue `Component` |
| Cache | `ghostnet-indexer/src/store/cache.rs` | `services/ghostnet-api/src/adapters/` | Implements domain port |
| ABIs | `ghostnet-indexer/src/abi/*.rs` | `services/ghostnet-api/src/abi/` | Direct copy |

**Test strategy:**

| Level | What | Tools |
|-------|------|-------|
| Unit | Handler returns correct status codes, domain service logic | `TestContext` |
| Integration | Full pipeline: event → DB → query (real Postgres) | `ContainerFixture`, Ishizue `TestHarness` |
| E2E | Real HTTP requests to running service | `TestHarness` with ephemeral ports |

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Cherry-picked code has hidden dependencies on old workspace | Medium | Low | Compile after each file copy; fix imports immediately |
| TimescaleDB container fixture not provided by Ishizue | High | Low | Write custom `ContainerFixture` (we have `testcontainers` code in old repo) |
| WebSocket/SSE mapping unclear in Ishizue HTTP | Medium | Medium | Implement as custom handler if framework doesn't support; file Ishizue issue |
| Ingestion Component lifecycle (start/stop/health) patterns unclear | Medium | Medium | Consult Ishizue handbook Section 6; file issue if inadequate |

---

## Notes

This is the largest epic. The old `ghostnet-indexer` has ~2500 lines of valuable logic across store, ingestion, and handler modules. We're not rewriting — we're cherry-picking and re-wiring through Ishizue patterns.

The integration tests from the old indexer (`tests/store_integration.rs`, `tests/full_flow_integration.rs`, `tests/reorg_integration.rs`) are gold — they test real scenarios. Cherry-pick the test logic too; adapt to the new handler/adapter structure.

Design references:
- `docs/design/services/ishizue-migration-plan.md` — Step 8
- `docs/design/services/ishizue-integration-plan.md` — Section 2.2 (API proto), Section 3.3 (ishizue.toml)
