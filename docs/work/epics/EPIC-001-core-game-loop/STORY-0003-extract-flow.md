---
type: story
status: ready
epic: "[[EPIC-001-core-game-loop]]"
implements:
  - "[[FR-CORE-002]]"
  - "[[FR-CORE-005]]"
sprint: 
created: 2026-01-27
updated: 2026-01-27
tags:
  - type/story
  - feature/core
  - status/ready
---

# STORY-0003: Extract Flow

## Summary

User can withdraw their stake plus accumulated yield from an active position through the web UI.

## Context

"Extract" is how players cash out of GHOSTNET. They take their original stake plus any yield earned while surviving. A 5% protocol fee is burned on extraction. The longer you stay (and survive), the more you earn — but the risk of death compounds.

- **Epic:** [[EPIC-001-core-game-loop]]
- **Implements:**
  - [[FR-CORE-002]] — Extract (withdraw stake + yield)
  - [[FR-CORE-005]] — Yield Accrual (real-time yield)

---

## Acceptance Criteria

- [ ] User can open Extract modal from Position panel
- [ ] Modal shows current stake, accumulated yield, and total
- [ ] Modal shows extraction fee (5% burn)
- [ ] Modal shows final receive amount (total - fee)
- [ ] User can confirm extraction
- [ ] Extract transaction executes successfully
- [ ] Tokens arrive in user's wallet
- [ ] Position is removed from UI after extraction
- [ ] Feed shows "EXTRACT" event with address and amount
- [ ] Error states handled (no position, network error)

---

## Technical Approach

**Web App:**
- Use existing Extract modal component
- Add viem hooks for:
  - `ghostCore.getPosition(address)` — current position data
  - `ghostCore.calculateYield(address)` — accumulated yield
  - `ghostCore.extract()` — execute extraction

**Contract Calls:**
1. Read current position and yield
2. Display breakdown in modal
3. Call `ghostCore.extract()` — wait for confirmation
4. Clear position from local store
5. Show success toast with received amount

**Yield Display:**
- Poll yield calculation every few seconds while modal is open
- Show updating number to emphasize real-time accrual

---

## Tasks

- [ ] Create viem hooks for GhostCore.extract
- [ ] Create viem hooks for GhostCore.calculateYield
- [ ] Wire Extract modal to contract hooks
- [ ] Add real-time yield polling in modal
- [ ] Add loading states during transaction
- [ ] Add success toast with received amount
- [ ] Clear position from store after extraction
- [ ] Integration test on MegaETH testnet
- [ ] Update documentation

---

## Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| GhostCore.sol deployed | ✅ | Ready on testnet |
| Active position exists | ⚠️ | Requires STORY-0001 complete |
| Extract modal UI | ✅ | Component exists |
| Position store | ✅ | Exists, needs contract integration |

---

## Test Plan

- **Unit tests:** Extract hook, yield calculation display
- **Integration tests:** E2E extraction flow on testnet
- **Manual testing:**
  - Extract immediately after jack in (minimal yield)
  - Extract after time passes (visible yield)
  - Extract with very large position
  - Extract with minimum position
  - Attempt extract with no position

---

## Notes

The Extract modal UI already exists from Phase 2. This story focuses on wiring it to real contracts.

Yield is calculated based on:
- Time elapsed since jack in
- Risk level's yield rate
- Current stake amount

The 5% burn happens automatically in the contract — the user receives (stake + yield) * 0.95.

Consider showing a "time to next scan" warning if user is in a high-risk tier and scan is imminent.

---

## Progress Log

*No progress yet — story ready for implementation (Wave 2).*
