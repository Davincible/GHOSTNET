# Randomness Timing Critical Fix

**Date:** 2026-01-21  
**Issue:** Critical Issue #2 - Randomness Reveal Window Too Tight  
**Status:** RESOLVED

## Problem

The original `FutureBlockRandomness.sol` had timing constants that were dangerous for MegaETH's 100ms block times:

```solidity
// BEFORE (problematic)
uint256 public constant SEED_BLOCK_DELAY = 5;      // Only 500ms!
uint256 public constant MAX_BLOCK_AGE = 256;       // EVM limit
uint256 public constant REVEAL_WINDOW = 200;       // Redundant and confusing
```

### Issues Identified

1. **500ms SEED_BLOCK_DELAY is insecure**: Block proposers could predict/influence such a short window
2. **REVEAL_WINDOW was redundant**: The actual window is always `MAX_BLOCK_AGE - SEED_BLOCK_DELAY`
3. **No fallback for network congestion**: 25.6 second total window is dangerous when tx confirmation can take 5-10+ seconds during congestion

## Solution Applied

### 1. Updated Constants

```solidity
// AFTER (secure)
uint256 public constant SEED_BLOCK_DELAY = 50;           // 5 seconds - unpredictable
uint256 public constant MAX_BLOCK_AGE = 256;             // EVM limit (unchanged)
uint256 public constant EXTENDED_HISTORY_WINDOW = 8191;  // EIP-2935 fallback
// REMOVED: REVEAL_WINDOW (was redundant)
```

### 2. Added EIP-2935 Integration

New `BlockhashHistory.sol` library provides extended block hash history (~13.6 minutes on MegaETH) via the Prague EVM system contract at `0x0000F90827F1C53a10Cb7A02335B175320002935`.

**Hybrid approach:**
- Try native `blockhash()` first (20 gas)
- Fall back to EIP-2935 if expired (2,600 gas)
- Graceful degradation if EIP-2935 unavailable

### 3. Added Failure Recovery Documentation

New Section 6.5 documents:
- Expiry detection patterns
- Refund process implementation
- Monitoring & alerting recommendations
- Edge case handling

## Timing Analysis Summary

| Constant | Old Value | New Value | MegaETH Time | Rationale |
|----------|-----------|-----------|--------------|-----------|
| `SEED_BLOCK_DELAY` | 5 | 50 | 5 seconds | Prevents prediction, good UX |
| `MAX_BLOCK_AGE` | 256 | 256 | 25.6 seconds | EVM limit, cannot change |
| `REVEAL_WINDOW` | 200 | REMOVED | N/A | Was redundant |
| `EXTENDED_HISTORY_WINDOW` | N/A | 8191 | ~13.6 minutes | EIP-2935 safety net |

**Effective reveal windows:**
- Without EIP-2935: 206 blocks = 20.6 seconds
- With EIP-2935: 8141 blocks = ~13.6 minutes

## Files Changed

- `docs/architecture/arcade-contracts-plan.md`:
  - Section 6.1: Added MegaETH timing analysis
  - Section 6.3: Updated FutureBlockRandomness.sol with new constants
  - Section 6.4: New BlockhashHistory.sol library
  - Section 6.5: New Randomness Failure Recovery documentation

## Verification

Run these checks to verify the fix:

```bash
# Verify constants
grep "SEED_BLOCK_DELAY = 50" docs/architecture/arcade-contracts-plan.md
grep "EXTENDED_HISTORY_WINDOW = 8191" docs/architecture/arcade-contracts-plan.md

# Verify EIP-2935 library exists
grep "BlockhashHistory" docs/architecture/arcade-contracts-plan.md

# Verify section structure
grep -n "^### 6\." docs/architecture/arcade-contracts-plan.md
```

## Risk Assessment After Fix

| Scenario | Delay | Risk Level |
|----------|-------|------------|
| Normal operation | 1-2s | ✅ Safe |
| Light congestion | 5s | ✅ Safe |
| Moderate congestion | 10s | ✅ Safe |
| Heavy congestion | 15s | ✅ Safe |
| Severe congestion | 20s | ⚠️ Marginal (but EIP-2935 extends to 13+ minutes) |
| Network incident | 25s+ | ✅ Safe with EIP-2935 |

## Lessons Learned

1. **Always calculate actual windows, not arbitrary numbers**: The `REVEAL_WINDOW = 200` constant was misleading because the actual constraint is `MAX_BLOCK_AGE - SEED_BLOCK_DELAY`.

2. **Fast chains need different constants**: What works on mainnet Ethereum (12s blocks) doesn't work on MegaETH (100ms blocks).

3. **Build in fallbacks**: EIP-2935 provides a ~30x safety margin when available.

4. **Document failure modes**: The new Section 6.5 ensures implementers know how to handle expiry gracefully.
