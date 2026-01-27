# Lesson: Batch Array Length Validation - Critical Security Issue #2

**Date**: 2026-01-21  
**Context**: ArcadeCore `batchCreditPayouts` security hardening  
**Severity**: High (DoS and potential payout corruption)

## Problem

The `batchCreditPayouts` function accepts multiple arrays but lacked validation:

```solidity
function batchCreditPayouts(
    uint256[] calldata sessionIds,
    address[] calldata players,
    uint256[] calldata amounts,
    uint256[] calldata burnAmounts,
    bool[] calldata results
) external;
```

**Attack Vectors:**
1. **Mismatched arrays** - Could cause out-of-bounds reads (Solidity reverts but error is confusing)
2. **DoS via gas exhaustion** - Submitting huge arrays could consume entire block gas limit
3. **Partial processing** - If arrays differ, only shortest would be processed (data loss)

## Solution

Added three-layer validation at function entry:

```solidity
// 1. Array length validation - all must match
uint256 batchSize = sessionIds.length;
if (
    players.length != batchSize ||
    amounts.length != batchSize ||
    burnAmounts.length != batchSize ||
    results.length != batchSize
) {
    revert ArrayLengthMismatch(
        batchSize,
        players.length,
        amounts.length,
        burnAmounts.length,
        results.length
    );
}

// 2. Empty batch check
if (batchSize == 0) {
    revert EmptyBatch();
}

// 3. Batch size limit (DoS prevention)
if (batchSize > _MAX_BATCH_SIZE) {
    revert BatchTooLarge(batchSize, _MAX_BATCH_SIZE);
}
```

**Constants:**
- `_MAX_BATCH_SIZE = 100` - Keeps gas under block limits for mainnet

**Custom Errors (gas efficient):**
```solidity
error ArrayLengthMismatch(
    uint256 sessionIdsLen,
    uint256 playersLen,
    uint256 amountsLen,
    uint256 burnAmountsLen,
    uint256 resultsLen
);
error BatchTooLarge(uint256 size, uint256 maxSize);
error EmptyBatch();
```

## Design Decisions

### Why 100 as MAX_BATCH_SIZE?

- Each payout iteration: ~3 SLOADs + ~3 SSTOREs + potential token transfer
- Gas per iteration: ~20-30k gas
- 100 iterations: ~2-3M gas (well under 30M block limit)
- Leaves room for other transactions in same block

### Why check empty separately?

- Clear error message vs. confusing "array index out of bounds"
- Edge case documentation: empty batch is semantically wrong

### Atomicity

All payouts in batch are atomic - if ANY fails (e.g., exceeds prize pool), entire batch reverts. This prevents:
- Partial state corruption
- Difficult debugging of "which payouts succeeded"
- Non-deterministic outcomes

## Test Coverage

Created 34 tests including:
- Valid batch operations (1, 100, multi-session)
- Array length mismatches (each array independently mismatched)
- Empty batch revert
- Batch at exactly MAX_BATCH_SIZE
- Batch exceeding MAX_BATCH_SIZE
- Session validation per-payout
- Atomicity verification (partial failure reverts all)
- Fuzz testing for batch sizes and array lengths

## Key Takeaway

**Always validate parallel arrays at function entry.** Solidity won't catch mismatched calldata arrays until they're accessed, and by then state may be partially modified. Fail fast, fail explicitly.
