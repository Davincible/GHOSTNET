---
type: story
status: ready
epic: "[[EPIC-001-core-game-loop]]"
implements:
  - "[[FR-CORE-001]]"
  - "[[FR-CORE-004]]"
sprint: 
created: 2026-01-27
updated: 2026-01-27
tags:
  - type/story
  - feature/core
  - status/ready
---

# STORY-0001: Jack In Flow

## Summary

User can stake $DATA tokens at their chosen risk level through the web UI, creating an active position in GhostCore.

## Context

"Jack In" is the core entry action for GHOSTNET. Users select a risk level (VAULT through BLACK ICE), specify an amount, and stake their $DATA. Higher risk = higher yield but more frequent scans and higher death rates.

- **Epic:** [[EPIC-001-core-game-loop]]
- **Implements:** 
  - [[FR-CORE-001]] — Jack In (stake tokens at risk level)
  - [[FR-CORE-004]] — Risk Levels (5 tiers with parameters)

---

## Acceptance Criteria

- [ ] User can open Jack In modal from the UI
- [ ] User can select one of 5 risk levels (VAULT, MAINFRAME, SUBNET, DARKNET, BLACK ICE)
- [ ] Risk level parameters (death rate, yield rate, scan frequency) are displayed
- [ ] User can input stake amount with validation (min/max)
- [ ] User must approve $DATA spend before first stake
- [ ] Jack In transaction executes successfully on MegaETH
- [ ] Position appears in the Position panel after transaction confirms
- [ ] Feed shows "JACK IN" event with address and amount
- [ ] Error states handled (insufficient balance, rejected tx, network error)

---

## Technical Approach

**Web App:**
- Use existing JackIn modal component
- Add viem hooks for:
  - `dataToken.approve(ghostCore, amount)`
  - `ghostCore.jackIn(amount, riskLevel)`
- Poll for position after tx confirms (or use event from indexer)
- Update position store with new position data

**Contract Calls:**
1. Check `dataToken.allowance()` — if insufficient, prompt approval
2. Call `dataToken.approve(ghostCore, amount)` — wait for confirmation
3. Call `ghostCore.jackIn(amount, riskLevel)` — wait for confirmation
4. Read `ghostCore.getPosition(address)` — update UI

**Error Handling:**
- Insufficient balance → Show error in modal
- User rejects → Reset modal state
- Network error → Retry prompt with error message

---

## Tasks

- [ ] Create viem hooks for GhostCore read/write
- [ ] Create viem hooks for DataToken approve/allowance
- [ ] Wire JackIn modal to contract hooks
- [ ] Add loading states during transaction
- [ ] Add success/error toast notifications
- [ ] Update position store after successful jack in
- [ ] Integration test on MegaETH testnet
- [ ] Update documentation

---

## Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| GhostCore.sol deployed | ✅ | Ready on testnet |
| DataToken.sol deployed | ✅ | MockERC20 on testnet for now |
| JackIn modal UI | ✅ | Component exists |
| Wallet connection | ✅ | WalletConnect working |
| ABI export | ✅ | ABIs in web app |

---

## Test Plan

- **Unit tests:** Contract hook functions (mocked)
- **Integration tests:** E2E flow on testnet with Playwright
- **Manual testing:** 
  - Fresh wallet with no approval
  - Wallet with existing approval
  - Insufficient balance
  - All 5 risk levels
  - Network disconnect mid-transaction

---

## Notes

The JackIn modal UI already exists from Phase 2. This story focuses on wiring it to real contracts.

Risk level parameters are defined in the contracts — the UI should read these dynamically rather than hardcoding.

Consider adding a "Max" button to stake entire balance minus gas.

---

## Progress Log

*No progress yet — story ready for implementation.*
