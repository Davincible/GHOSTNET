---
type: story
status: ready
epic: "[[EPIC-001-core-game-loop]]"
implements:
  - "[[FR-CORE-003]]"
  - "[[FR-CORE-006]]"
sprint: 
created: 2026-01-27
updated: 2026-01-27
tags:
  - type/story
  - feature/core
  - status/ready
---

# STORY-0002: Trace Scan Execution

## Summary

Trace scans execute on each risk level's schedule, rolling for deaths and processing the Cascade redistribution. For MVP, scans are triggered manually; automated keeper is Phase 2.

## Context

Trace scans are the core tension mechanic of GHOSTNET. Periodically, each risk tier runs a death check. Players who "get traced" lose their position — their stake is redistributed (60% to survivors, 30% burned, 10% to treasury).

- **Epic:** [[EPIC-001-core-game-loop]]
- **Implements:**
  - [[FR-CORE-003]] — Trace Scan (periodic survival check)
  - [[FR-CORE-006]] — Death Handling (position liquidation)

---

## Acceptance Criteria

- [ ] Admin/keeper can trigger trace scan for a risk level
- [ ] Scan processes death rolls based on risk level's death rate
- [ ] Dead positions are marked and removed from active positions
- [ ] Cascade executes: 60% → survivors, 30% → burn, 10% → treasury
- [ ] Death events appear in the feed with victim addresses
- [ ] Surviving positions show updated balances (redistribution share)
- [ ] Network vitals panel shows updated stats after scan
- [ ] Scan history is viewable (last scan time per level)

---

## Technical Approach

**Contracts:**
- `TraceScan.executeScan(riskLevel)` already implemented
- Uses prevrandao + 60-second lock period for randomness (per ADR-001)
- Emits `Scanned`, `PlayerDied`, `Redistributed` events

**Indexer:**
- Decode scan events
- Store deaths in TimescaleDB
- Stream to web clients via WebSocket

**Web App:**
- Display deaths in feed as they arrive
- Update position balances after redistribution
- Show "Last Scan" timestamp per risk level in Network Vitals

**MVP Scope:**
- Manual trigger only (dev/admin wallet)
- No automated keeper yet
- Basic feed display of death events

---

## Tasks

- [ ] Create viem hooks for TraceScan.executeScan (admin only)
- [ ] Indexer: decode Scanned/PlayerDied/Redistributed events
- [ ] Feed: add DEATH event type with victim info
- [ ] Position store: handle position removal on death
- [ ] Position store: handle balance update on redistribution
- [ ] Network vitals: add "Last Scan" per risk level
- [ ] Test scan execution on MegaETH testnet
- [ ] Test multi-death scenario
- [ ] Update documentation

---

## Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| TraceScan.sol deployed | 🟣 | Needs testnet deployment |
| Active positions exist | ⚠️ | Requires STORY-0001 complete |
| Indexer event decoding | 🚧 | In progress |
| WebSocket API | 🚧 | In progress |

---

## Test Plan

- **Unit tests:** Event decoding in indexer
- **Integration tests:** 
  - Trigger scan, verify death events in feed
  - Verify redistribution amounts correct
- **Manual testing:**
  - Scan with 0 players (no deaths)
  - Scan with 10+ players
  - Multiple scans in sequence
  - Watch feed update in real-time

---

## Notes

For MVP, we only need manual trigger capability. The keeper bot for automated scans is a separate story in a later epic.

Death rate is configured per risk level:
- VAULT: 0% (safe)
- MAINFRAME: 2%
- SUBNET: 15%
- DARKNET: 40%
- BLACK ICE: 90%

The randomness comes from prevrandao + 60-second lock period (per ADR-001). The lock period prevents extraction during the predictable window, while multi-component seed (prevrandao + timestamp + block number) adds entropy.

---

## Progress Log

*No progress yet — story ready for implementation (Wave 2).*
