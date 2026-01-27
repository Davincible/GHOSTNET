# Lesson 006: AMOUNT_SCALE Truncation and Precision in PlayerStats

**Date:** 2026-01-21  
**Category:** Smart Contract Design  
**Severity:** High (Architecture Review Issue #6)

## Problem

The `PlayerStats` struct uses `uint128` for amount fields (totalWagered, totalWon, totalBurned) with a scale factor to fit large values into smaller storage. This scaling introduces **truncation** that can cause issues if the scaled values are used for financial invariants.

## Original Issue

The architecture review identified that:

1. **AMOUNT_SCALE inconsistency**: Storage had `1e12`, comments had `1e6`
2. **Truncation behavior undocumented**: Amounts < AMOUNT_SCALE are lost entirely
3. **Potential misuse**: Scaled values might be used for solvency checks (wrong!)
4. **Accumulation drift**: Repeated small transactions accumulate truncation error

## Root Cause Analysis

### Why Scaling?

EVM storage is expensive. Packing multiple values into fewer storage slots saves gas:

```solidity
// Without packing: 5 storage slots (160 gas to read all)
struct PlayerStats {
    uint256 totalGamesPlayed;
    uint256 totalWagered;
    uint256 totalWon;
    uint256 totalWins;
    uint256 lastPlayTime;
}

// With packing: 2 storage slots (64 gas to read all)
struct PlayerStats {
    uint64 totalGamesPlayed;  // 8 bytes
    uint128 totalWagered;     // 16 bytes (scaled by 1e6)
    uint128 totalWon;         // 16 bytes (scaled by 1e6)
    uint64 totalWins;         // 8 bytes
    uint64 lastPlayTime;      // 8 bytes
}
```

### The Truncation Problem

```solidity
uint256 constant AMOUNT_SCALE = 1e6;

// Player deposits 999,999 wei (just under 1e6)
uint256 deposit = 999_999;
uint128 scaledValue = uint128(deposit / AMOUNT_SCALE);
// scaledValue = 0  (truncated to zero!)

// Even 1000 deposits of 999,999 wei each:
// Total actual: 999,999,000 wei
// Accumulated in stats: 0 (each truncated individually)
```

## Solution

### 1. Clear Documentation

Added comprehensive NatSpec to `AMOUNT_SCALE` constant:

```solidity
/// @notice Scale factor for packing large amounts into uint128 statistics fields
/// @dev PRECISION CHARACTERISTICS:
///      - Minimum trackable: 1e6 wei = 1 pico-DATA (1e-12 DATA)
///      - Maximum trackable: uint128.max * 1e6
///      - Truncation: Amounts < 1e6 wei are LOST (round toward zero)
///
///      IMPORTANT: These scaled values are APPROXIMATIONS for analytics/display.
///      DO NOT use for:
///      - Solvency calculations (use $.totalPendingPayouts instead)
///      - Payout bounds checking (use session.prizePool instead)
///      - Any financial invariant testing
```

### 2. Source of Truth Table

Documented which values to use for which purposes:

| Metric | Authoritative Source | Precision | Use For |
|--------|---------------------|-----------|---------|
| Total volume | `$.totalVolume` | Full (uint256) | Accounting, invariants |
| Total burned | `$.totalBurned` | Full (uint256) | Accounting, invariants |
| Pending payouts | `$.totalPendingPayouts` | Full (uint256) | Solvency checks |
| Session prize pool | `session.prizePool` | Full (uint256) | Payout bounds |
| Player wagered | `stats.totalWagered` | Scaled (uint128) | Analytics only |
| Player won | `stats.totalWon` | Scaled (uint128) | Analytics only |

### 3. Fixed Inconsistency

Changed `AMOUNT_SCALE` from `1e12` to `1e6` to match architecture plan rationale:

- With 1e12: Bets under 0.000001 DATA lost entirely
- With 1e6: Track down to 1 pico-DATA (more useful for arcade micro-bets)

### 4. Truncation Behavior Tests

Created `test/arcade/ArcadeCore.ScaledStats.t.sol` with:

- Pure math tests verifying truncation boundaries
- Accumulation drift demonstration
- Maximum value verification
- Precision loss analysis for typical wager sizes

## Key Takeaways

### DO

- Use scaled PlayerStats for leaderboards, UI display, analytics
- Use unscaled authoritative values (`$.totalVolume`, `$.totalPendingPayouts`) for invariants
- Document truncation behavior at every scaling operation
- Test boundary conditions around AMOUNT_SCALE

### DON'T

- Use `sum(stats.totalWagered)` to verify solvency (BROKEN!)
- Assume scaled values are exact
- Use AMOUNT_SCALE for values that must be precise
- Change AMOUNT_SCALE after deployment (breaks all historical data interpretation)

## Invariant Testing Pattern

```solidity
// WRONG: Using scaled values for solvency
function invariant_Solvency_WRONG() public {
    uint256 sumPlayerWon = ...; // Sum of scaled values - DRIFTS!
    assertGe(balance, sumPlayerWon * AMOUNT_SCALE); // BROKEN
}

// CORRECT: Using unscaled authoritative values
function invariant_Solvency_CORRECT() public {
    assertGe(
        dataToken.balanceOf(address(arcadeCore)),
        arcadeCore.totalPendingPayouts(),  // Unscaled, authoritative
        "Solvency invariant violated"
    );
}
```

## Files Changed

- `packages/contracts/src/arcade/ArcadeCoreStorage.sol` - Enhanced AMOUNT_SCALE documentation
- `packages/contracts/src/arcade/interfaces/IArcadeCore.sol` - PlayerStats and getPlayerStats() docs
- `packages/contracts/src/arcade/interfaces/IArcadeTypes.sol` - PlayerStats documentation
- `packages/contracts/test/arcade/ArcadeCore.ScaledStats.t.sol` - Truncation behavior tests (new)

## Related Issues

- Architecture Review Issue #6: AMOUNT_SCALE Truncation Documentation
- ADR for ArcadeCore Storage Layout (pending)

## References

- [Solidity Gas Optimization Guide](packages/contracts/docs/guides/solidity/gas-optimization.md)
- [OpenZeppelin Storage Packing](https://docs.openzeppelin.com/contracts/5.x/utilities#packing)
