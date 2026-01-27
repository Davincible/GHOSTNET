# GHOSTNET Architecture Documentation

Technical architecture documentation for the GHOSTNET project.

## Start Here

| Document | Purpose |
|----------|---------|
| [../blueprint/architecture.md](../blueprint/architecture.md) | System shape and component relationships |
| [mvp-scope.md](./mvp-scope.md) | Explicit MVP boundaries (what's in/out) |

## Core Architecture Documents

### Contracts
| Document | Description | Status |
|----------|-------------|--------|
| [../design/contracts/specifications.md](../design/contracts/specifications.md) | Solidity specs, storage layouts, ERC-7201 | **Authoritative** |

### Frontend
| Document | Description | Status |
|----------|-------------|--------|
| [frontend-architecture.md](./frontend-architecture.md) | Event bus, state layers, effects system | **Authoritative** |
| [ui-components.md](./ui-components.md) | Screens, components, design system | Reference |

### Backend
| Document | Description | Status |
|----------|-------------|--------|
| [backend/indexer-architecture.md](./backend/indexer-architecture.md) | TimescaleDB, Rust types, APIs, Iggy | **Authoritative** |
| [backend/indexer-implementation-plan.md](./backend/indexer-implementation-plan.md) | Implementation phases | Tracking |

### Operations & Security
| Document | Description |
|----------|-------------|
| [security-audit-scope.md](./security-audit-scope.md) | Audit scope, critical focus areas |
| [emergency-procedures.md](./emergency-procedures.md) | Incident response runbook |
| [runbook-circuit-breaker-response.md](./runbook-circuit-breaker-response.md) | Circuit breaker response procedures |

### Technical Deep Dives
| Document | Description |
|----------|-------------|
| [prevrandao-verification-plan.md](./prevrandao-verification-plan.md) | PREVRANDAO randomness verification |
| [randomness-congestion-mitigation.md](./randomness-congestion-mitigation.md) | Congestion mitigation strategies |
| [adr-circuit-breaker-reset-timelock.md](./adr-circuit-breaker-reset-timelock.md) | Circuit breaker ADR |
| [megaeth-networks.md](./megaeth-networks.md) | MegaETH network configuration |

### Planning Documents
| Document | Description |
|----------|-------------|
| [phase2-implementation-plan.md](./phase2-implementation-plan.md) | Phase 2 implementation details |
| [architecture-review-2026-01-20.md](./architecture-review-2026-01-20.md) | Architecture review session |

## Archived Documentation

See [../archive/README.md](../archive/README.md) for superseded documents:
- Original overview (replaced by blueprint/architecture.md)
- Smart contracts plan (replaced by design/contracts/)
- Ghost Fleet wallet automation (post-MVP)
- Arcade contracts plan (see design/arcade/)

## Related Documentation

- **Blueprint**: `docs/blueprint/` - Authoritative system documentation
- **Design**: `docs/design/` - Detailed technical designs
- **Guides**: `docs/guides/` - Development guides (Rust, TimescaleDB)
- **References**: `docs/references/` - External reference materials
- **Lessons**: `docs/learnings/` - Documented issues and fixes

## Architecture Decision Records (ADRs)

Key decisions documented in the architecture:

| ADR | Title | Location |
|-----|-------|----------|
| ADR-001 | Event-Sourced UI State | frontend-architecture.md |
| ADR-002 | Feature-Based Module Boundaries | frontend-architecture.md |
| ADR-003 | Three-Layer State Architecture | frontend-architecture.md |
| ADR-004 | Centralized Effects System | frontend-architecture.md |
| ADR-005 | CSS-First Visual Effects | frontend-architecture.md |
| ADR-006 | Circuit Breaker Reset Timelock | adr-circuit-breaker-reset-timelock.md |

## Technology Stack

```
Frontend:     SvelteKit 2.x + Svelte 5 (runes)
Styling:      CSS Custom Properties
Web3:         viem (custom wallet layer)
Real-time:    Native WebSocket + Iggy streaming
Audio:        ZzFX (procedural sounds)
Animation:    CSS + Motion One
Testing:      Vitest + Playwright

Backend:      Rust 1.85+ (Edition 2024)
Database:     TimescaleDB (PostgreSQL)
Streaming:    Iggy.rs
RPC:          ConnectRPC (Prost + tonic)

Contracts:    Solidity 0.8.33
Framework:    Foundry
Dependencies: OpenZeppelin 5.x
```

## Core Architecture Pattern

```
+-----------------------------------------------------------------+
|                         MEGAETH                                  |
|  +-------------+    +-------------+    +-------------+         |
|  | DataToken   |    | GhostNet    |    | TraceScan   |         |
|  | (ERC-20)    |<-->| (Core)      |<-->| (Randomness)|         |
|  +-------------+    +-------------+    +-------------+         |
+-----------------------------------------------------------------+
           |                   |                   |
           +-------------------+-------------------+
                               v
+-----------------------------------------------------------------+
|                        INDEXER (Rust)                            |
|  +-------------+    +-------------+    +-------------+         |
|  | Event       |--->| TimescaleDB |--->| Iggy        |         |
|  | Listener    |    |             |    | Streaming   |         |
|  +-------------+    +-------------+    +-------------+         |
+-----------------------------------------------------------------+
                               |
                               v
+-----------------------------------------------------------------+
|                      WEB APP (SvelteKit)                         |
|  +-------------+    +-------------+    +-------------+         |
|  | WebSocket   |--->| Event Bus   |--->| UI          |         |
|  | Client      |    |             |    | Components  |         |
|  +-------------+    +-------------+    +-------------+         |
+-----------------------------------------------------------------+
```

## Contributing

When modifying architecture:
1. Update relevant documentation
2. Add ADR for significant decisions
3. Update session log with rationale
4. Run `just check-all` before committing
