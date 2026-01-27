# Session Log: Frontend Architecture Planning

**Date:** 2026-01-19  
**Type:** Architecture Planning  
**Status:** Completed (Updated)

---

## Session Overview

Initial deep-dive architecture planning session for the GHOSTNET frontend. Analyzed product requirements from master design document and created comprehensive frontend architecture.

## Documents Reviewed

- `docs/archive/product/master-design.md` - Full game mechanics, UI mockups, visual design (historical)
- `docs/archive/product/one-pager.md` - Product summary (historical)
- `docs/design/copy-writing-bible.md` - Brand voice and terminology

## Key Decisions Made

### 1. Event-Sourced UI (ADR-001)

**Decision:** All UI state flows through a central event bus.

**Rationale:**
- The live feed IS the game - everything is an event
- Sound effects and visual effects need to trigger from same events
- Enables replay/debugging
- Natural fit for WebSocket-first architecture

**Alternatives Considered:**
- Component-local state with prop drilling - Rejected: too coupled
- Global store without events - Rejected: harder to coordinate effects

---

### 2. Feature-Based Modules (ADR-002)

**Decision:** Organize code by feature domain, not technical layer.

**Rationale:**
- Mini-games need to evolve independently
- Clear boundaries make deletion/modification safer
- Easier developer onboarding

**Structure:**
```
lib/features/
├── feed/
├── position/
├── network/
├── typing/
├── hackrun/
├── deadpool/
├── crew/
└── pvp/
```

---

### 3. Three-Layer State (ADR-003)

**Decision:** Separate state into Server, Derived, and UI layers.

**Rationale:**
- Clear ownership prevents confusion
- Server state (contracts) is source of truth
- Derived state ($derived) auto-updates
- UI state is component-local

---

### 4. Centralized Effects (ADR-004)

**Decision:** Single effects manager coordinates all audio/visual feedback.

**Rationale:**
- "Dopamine levels" can be tuned in one place
- Easy to disable all effects (accessibility)
- Consistent event-to-effect mapping

---

### 5. CSS-First Effects (ADR-005)

**Decision:** Use CSS for terminal aesthetic, not canvas.

**Rationale:**
- Terminal is fundamentally text-based
- CSS transforms are GPU-accelerated
- Simpler maintenance
- Works with Svelte transitions

---

## Assumptions Made

| Assumption | Confidence | Verification Needed |
|------------|------------|---------------------|
| MegaETH provides WebSocket endpoints | Medium | Check with team |
| Sub-second block finality on MegaETH | Medium | Verify documentation |
| ZzFX works in all target browsers | High | Test on Safari/Firefox |
| Svelte 5 runes stable for production | High | Currently stable |

## Open Questions

1. **MegaETH WebSocket availability** - Need to confirm real-time event streaming is possible
2. **Chainlink VRF on MegaETH** - Required for trace scan randomness
3. **RPC rate limits** - Affects polling strategy if WS unavailable
4. **Backend API protocol** - Recommended tRPC, needs team discussion

## Risks Identified

| Risk | Mitigation |
|------|------------|
| WebSocket reliability | Reconnection logic, offline indicator |
| Animation jank on mobile | CSS-only effects, testing, disable option |
| MegaETH tooling immaturity | Abstract chain code, prepare for changes |
| Real-time sync issues | Optimistic UI with reconciliation |

## Artifacts Created

- `docs/architecture/frontend-architecture.md` - Full architecture document (~2500 lines)
- `docs/architecture/ui-components.md` - UI/Components architecture (~1800 lines)
- `docs/architecture/implementation-plan.md` - Phased implementation checklist (~1500 lines)
- `docs/architecture/README.md` - Architecture index
- `docs/sessions/README.md` - Session log template
- `docs/learnings/README.md` - Lessons learned template

## Next Steps

1. **Review architecture** with team
2. **Validate assumptions** about MegaETH
3. **Begin Phase 1** implementation:
   - Event bus
   - Design tokens CSS
   - Terminal shell
   - Box component
   - Audio manager

## Notes

The architecture intentionally front-loads infrastructure (event bus, effects system) because:
1. Everything else depends on these patterns
2. Retrofitting events into components is painful
3. Sound/visual coordination is critical to game feel

The product is heavily dopamine-driven (per master design doc). The effects system architecture acknowledges this as first-class concern.
