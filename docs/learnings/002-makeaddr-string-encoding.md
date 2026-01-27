# Lesson 002: Foundry makeAddr String Encoding Pitfall

## Date
2026-01-20

## Context
When writing tests that create multiple addresses in a loop and need to reference specific ones later.

## Problem
Test was failing because `makeAddr(string(abi.encodePacked("user", i)))` produces a different address than `makeAddr("user0")`.

The issue: `abi.encodePacked("user", uint256(0))` produces `"user\x00"` (with a 32-byte zero value appended as raw bytes), not the string `"user0"`.

## Symptoms
- Test checking user balance showed 0 when expected non-zero
- Debug trace showed two different addresses being labeled "user0"
- The addresses were:
  - Loop: `0xa3857F6Fa5A579444c8F79520B4A5d1b9771f4cE` (from `makeAddr(string(abi.encodePacked("user", 0)))`)
  - Later: `0xfcffC2ac94d461b4C7A334DD1b7F7197f73e2a8f` (from `makeAddr("user0")`)

## Root Cause
`abi.encodePacked` with a `uint256` doesn't convert it to an ASCII string - it appends the raw 32 bytes. So:
- `abi.encodePacked("user", uint256(0))` = `"user"` + 32 zero bytes
- `"user0"` = just the 5-byte ASCII string

## Solution
When referencing a specific user created in a loop, use the exact same encoding:

```solidity
// WRONG
address firstUser = makeAddr("user0"); // Different string!

// CORRECT
address firstUser = makeAddr(string(abi.encodePacked("cullUser", uint256(0))));
```

Or use `vm.toString()` for proper string conversion:

```solidity
// Alternative - convert number to string
address user = makeAddr(string.concat("user", vm.toString(i)));
```

## Prevention
1. When using `makeAddr` in loops, always use the exact same string encoding when referencing later
2. Consider using `vm.toString(i)` instead of `abi.encodePacked` for readability
3. Use unique prefixes for each test to avoid collision with other tests

## Related
- Foundry `makeAddr`: Uses keccak256 hash of the string to derive address
- `abi.encodePacked`: Raw byte concatenation, doesn't do type conversion
- `vm.toString()`: Proper number-to-string conversion

## Affected Files
- `test/EdgeCases.t.sol` - Fixed in `test_Culling_TriggeredWhenLevelFull()`
