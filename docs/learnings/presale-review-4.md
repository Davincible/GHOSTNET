# Presale Review 4 — Lessons Learned

**Date:** 2026-01-28
**Context:** Fourth review of GhostPresale + PresaleClaim contracts

## Findings Applied

### Medium
- **M-1**: `recoverUnclaimed` transfers entire balance (spec updated to match — simpler, safe with deadline guard)
- **M-2**: `withdrawETH` accepted 0 balance — added `NoETHToWithdraw` guard
- **M-3**: `snapshotAllocations` callable after claiming — now restricted to pre-claiming

### Low
- **L-1**: Tranche dust (1 wei) leaked across boundaries — set `remainingETH = 0` in single-tranche branch
- **L-2**: `preview()` bonding curve is estimate only — documented in NatDoc
- **L-3**: `addTranche`/`setCurve`/`clearTranches` didn't enforce pricing mode — added `WrongPricingMode` error
- **L-4**: `clearTranches()` had no event — added `TranchesCleared` event

### Gas
- **G-1**: `totalPresaleSupply()` recomputed O(n) every call — cached in `_cachedTotalSupply`

### Test Gaps
- **T-1**: Added fuzz test for tranche boundary crossing
- **T-2**: Added round-trip cost verification for bonding curve
- **T-3**: Added monotonicity test for `currentPrice()`
- **T-4**: Added zero-value contribute test (documents griefing vector: contributor count inflation with minContribution=0)
- **T-5**: Added `emergencyRefunds` after `finalize` test
- **T-6**: Added `enableRefunds` after `finalize` test
- Additional tests for M-2, M-3, L-3, L-4 fixes

### Nitpicks
- **N-2**: Renamed `InvalidTrancheSupply` → `ZeroTrancheSupply`
- **N-3**: Renamed `Contributed` event param `currentPrice` → `spotPrice` to avoid shadowing

## Key Takeaway

After 4 review rounds, the presale contracts are hardened. The remaining findings were defense-in-depth (pricing mode enforcement, empty withdrawal guard), documentation accuracy (spec/code alignment), and test completeness. No critical or high-severity issues found.
