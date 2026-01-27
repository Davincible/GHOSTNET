# GHOSTNET System Overview (MVP)

**Date:** 2026-01-24  
**Status:** Active  

This is the one-page “map of the territory” for the MVP system.

---

## Shape

```
┌───────────────────────────────────────────────────────────────────────────┐
│                                 WEB APP                                   │
│                         (SvelteKit, player UX)                             │
│                                                                           │
│  - wallet connect     - jack in / extract     - live feed + timers         │
└───────────────┬───────────────────────────────────────────┬───────────────┘
                │                                           │
                │ (writes tx / reads views)                 │ (realtime feed)
                ▼                                           ▼
┌───────────────────────────────┐                 ┌──────────────────────────┐
│        CORE CONTRACTS          │                 │          INDEXER          │
│        (MegaETH chain)         │                 │   (Rust, derived state)   │
│                               │                 │                          │
│ DataToken / GhostCore / TraceScan              - ingest logs (WS/HTTP)      │
│  - truth + funds                              - decode + store (Timescale) │
│  - emits events                               - stream events (WS API)     │
└───────────────┬───────────────┘                 └─────────────┬────────────┘
                │                                              │
                │                                              │
                ▼                                              ▼
        MegaETH RPC (HTTP/WS)                         TimescaleDB + Iggy
```

---

## Boundaries (Load-Bearing)

### 1) Contracts → Events (the real interface)
- Anything observable on-chain becomes depended upon.
- The stable contract between on-chain and off-chain is:
  - event names
  - event fields
  - semantics (“what does this mean?”)

Reference:
- `docs/design/contracts/specifications.md`

### 2) Indexer is a projection, not a source of truth
- Indexer state must be rebuildable from chain history.
- If an indexer database is lost, we recover by reindexing.

Reference:
- `docs/architecture/backend/indexer-architecture.md`

### 3) Web reads reality via indexer (fast) and chain (authoritative)
- Web should prefer indexer for real-time feed and “dashboard views”.
- Web falls back to chain reads for verification / critical state.

Reference:
- `docs/architecture/implementation-plan.md`

---

## MVP “Golden Path” Flow

1. User connects wallet.
2. User calls `jackIn` (tx → chain).
3. Contract emits events.
4. Indexer ingests logs, persists, and pushes WS events.
5. Web feed updates from indexer event stream.
6. User calls `extract` (tx → chain).
7. Same event pipeline updates UI.

---

## Known Operational Reality (MegaETH)

- Testnet public WebSocket subscriptions can appear to succeed but never stream data.
- Design must support WS where available and HTTP polling fallback.

Reference:
- `docs/learnings/megaeth-rpc-endpoints.md`
