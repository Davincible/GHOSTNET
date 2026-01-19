# GHOSTNET Architecture Documentation

This directory contains technical architecture documentation for the GHOSTNET project.

## Documents

| Document | Description | Status |
|----------|-------------|--------|
| [Frontend Architecture](./frontend-architecture.md) | Core systems, state management, event bus | Planning |
| [UI Components](./ui-components.md) | Screens, components, design system | Planning |
| [Implementation Plan](./implementation-plan.md) | Phased checklist with dummy data approach | **Active** |
| Backend Architecture | Server-side systems (TBD) | Not Started |
| Contract Architecture | Smart contract design (TBD) | Not Started |

## Architecture Decision Records (ADRs)

Key decisions documented in the frontend architecture:

| ADR | Title | Status |
|-----|-------|--------|
| ADR-001 | Event-Sourced UI State | Accepted |
| ADR-002 | Feature-Based Module Boundaries | Accepted |
| ADR-003 | Three-Layer State Architecture | Accepted |
| ADR-004 | Centralized Effects System | Accepted |
| ADR-005 | CSS-First Visual Effects | Accepted |

## Quick Reference

### Technology Stack

```
Frontend:     SvelteKit 2.x + Svelte 5 (runes)
Styling:      CSS Custom Properties
Web3:         viem (custom wallet layer)
Real-time:    Native WebSocket
Audio:        ZzFX (procedural sounds)
Animation:    CSS + Motion One
Testing:      Vitest + Playwright
```

### Core Architecture Pattern

```
┌─────────────────────────────────────────────────────┐
│                    EVENT BUS                         │
│                                                      │
│  Sources:              Subscribers:                  │
│  ├── WebSocket         ├── Feed Store               │
│  ├── Contracts         ├── Position Store           │
│  ├── User Actions      ├── Sound Manager            │
│  └── Timers            └── Visual Effects           │
└─────────────────────────────────────────────────────┘
```

### File Structure Overview

```
apps/web/src/lib/
├── core/           # Infrastructure (events, web3, timers)
├── features/       # Feature modules (feed, position, typing, etc.)
├── ui/             # Presentational components
└── audio/          # Sound system
```

## Implementation Timeline

| Phase | Duration | Focus |
|-------|----------|-------|
| 1. Foundation | Week 1 | Event bus, terminal shell, CSS tokens |
| 2. Core UI | Week 2 | Feed, network vitals, position panel |
| 3. Web3 | Week 3 | Wallet connection, contract interactions |
| 4. Real-time | Week 4 | WebSocket, live data |
| 5. Typing Game | Week 5 | Trace Evasion mini-game |
| 6. Polish | Week 6 | Testing, performance, accessibility |

## Contributing

When modifying architecture:

1. Update relevant documentation
2. Add ADR for significant decisions
3. Update session log with rationale
4. Get review before implementing
