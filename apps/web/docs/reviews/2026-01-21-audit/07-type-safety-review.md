# Type Safety Review

**Date**: 2026-01-21
**Reviewer**: Akira (Automated)
**Scope**: TypeScript type safety analysis of `apps/web/src`

## Executive Summary

The GHOSTNET web application demonstrates **strong overall type safety**. The codebase follows TypeScript best practices with well-defined interfaces, proper use of generics, and comprehensive discriminated unions for event types.

| Metric | Count | Assessment |
|--------|-------|------------|
| `any` type usage | 4 (in test files only) | Acceptable |
| `as` type assertions | ~40 | Mostly justified |
| `@ts-ignore`/`@ts-expect-error` | 0 | Excellent |
| Component props typing | 91/91 | All typed |
| Missing function return types | 0 critical | Good |
| **Missing type exports** | **4** | **Needs fix** |
| **Missing interface methods** | **3** | **Needs fix** |

**Key Findings:**
- No `any` usage in production code - all instances are in test files where mocking requires it
- Type assertions are used appropriately, primarily for:
  - Contract ABI return type narrowing (justified)
  - ZzFX sound parameter arrays (justified)
  - One SSR workaround (documented and acceptable)
- All Svelte components use proper `Props` interface typing
- Core type definitions are well-structured with discriminated unions
- Error handling uses proper `unknown` type for catch clauses

**Issues Requiring Attention:**
- Several types (`DailyProgress`, `DailyMission`, `Consumable`, `OwnedConsumable`) are not exported from `$lib/core/types`
- `DataProvider` interface is missing consumable-related methods
- These cause compile-time TypeScript errors

## `any` Type Audit

### Count by File

| File | `any` Count | Justified | Location |
|------|-------------|-----------|----------|
| `wallet.svelte.test.ts` | 4 | Yes | Test mocks |
| Production code | 0 | N/A | N/A |

### Detailed Findings

#### File: `src/lib/web3/wallet.svelte.test.ts`

**Lines 166, 312, 339, 362**: `as any` casts for mock return values

```typescript
// Line 166
chain: { id: 1, name: 'Ethereum' } as any,

// Line 312, 339
vi.mocked(mockSwitchChain).mockResolvedValueOnce({} as any);

// Line 362
vi.mocked(mockGetBalance).mockResolvedValue({ value: 1000000000000000000n } as any);
```

**Justification**: These are test file mocks where the full type structure is not needed. The tests verify specific behaviors and only need partial type information.

**Fix Opportunity**: Could create mock types that satisfy the full interface, but the maintenance burden outweighs the benefit in test code. **Acceptable as-is.**

### Word "any" in Comments (Not Issues)

The grep results included several matches that are not type safety issues - they are natural English usage of "any" in comments:
- "pick any opponent" (comment in duel.ts)
- "Remove any existing modifier" (comment in provider.svelte.ts)
- "undefined for any" (documentation in wallet.svelte.ts)

These are correctly **not** type annotations.

## Unsafe Type Assertions

### Assessment Summary

| Category | Count | Risk Level |
|----------|-------|------------|
| Contract return narrowing | 5 | Low - Justified |
| ZzFX parameter arrays | 24 | Low - Justified |
| Empty record initialization | 1 | Low - Justified |
| Crew activity creation | 1 | Low - Justified |
| SSR config workaround | 1 | Medium - Documented |
| Chain ID narrowing | 1 | Low - Justified |
| Node progress update | 1 | Low - Type narrowing |

### Contract Return Type Assertions

**File**: `src/lib/web3/contracts.ts`

```typescript
// Lines 148, 170, 270, 285, 301
return readContract(config, { ... }) as Promise<bigint>;
```

**Justification**: Wagmi's `readContract` returns a generic type. The ABI is known at compile time, so asserting the return type matches the contract's actual return value is safe and provides better type inference downstream.

**Risk**: Low. If the ABI changes, the assertion would be incorrect, but this would be caught during integration testing.

**Alternative**: Could use wagmi's generated types from `@wagmi/cli`, but that requires additional toolchain setup. Current approach is pragmatic.

### ZzFX Sound Parameter Arrays

**File**: `src/lib/core/audio/manager.svelte.ts`

```typescript
// Lines 22-49
click: [0.3, , 800, , 0.01, 0.01, , 1, , , , , , , , , , 0.5] as ZzFXParams,
```

**Justification**: ZzFX uses tuple types with many optional parameters. The `as ZzFXParams` ensures the array literal is typed as a fixed-length tuple rather than `(number | undefined)[]`.

**Risk**: None. The ZzFX library defines these parameter positions. If parameters are wrong, audio will sound wrong but no runtime crash will occur.

### SSR Config Workaround

**File**: `src/lib/web3/config.ts`

```typescript
// Line 86
export const config = browser ? getConfig()! : (null as unknown as Config);
```

**Risk Assessment**: **Medium** - This is a double assertion that bypasses type checking.

**Justification**: This is an intentional SSR workaround. During SSR, the config is truly `null`, but code that runs only in the browser expects a `Config` type. The alternative approaches are:
1. Make all consumers handle `null` (verbose, error-prone)
2. Throw during SSR (breaks SSR)
3. This workaround (documents the constraint)

**Mitigation**: The file has documentation, and the `requireConfig()` function provides a safe accessor that throws if called during SSR.

**Recommendation**: Consider adding a more explicit comment:

```typescript
// During SSR, config is null. Browser-only code should use requireConfig().
// This assertion allows the type system to pass while SSR-unsafe usage will
// fail at runtime with a clear error from requireConfig().
export const config = browser ? getConfig()! : (null as unknown as Config);
```

### Record Initialization

**File**: `src/lib/core/providers/mock/generators/network.ts`

```typescript
// Line 19
const traceScanTimestamps: Record<Level, number> = {} as Record<Level, number>;
```

**Justification**: Starting with an empty record that will be populated in a loop. TypeScript can't verify that all keys will be set, so the assertion is necessary.

**Risk**: Low. The loop immediately below populates all `LEVELS` keys.

**Alternative**: Could use `Object.fromEntries()` with explicit typing, but less readable.

### Crew Activity Creation

**File**: `src/lib/core/providers/mock/generators/crew.ts`

```typescript
// Line 489
} as CrewActivity);
```

**Justification**: Building a partial object and asserting the full type. Common pattern when constructing complex objects incrementally.

**Risk**: Low. This is mock data generation code, not production business logic.

### Node Progress Update

**File**: `src/lib/features/hackrun/store.svelte.ts`

```typescript
// Line 364
{ ...p, status: result.success ? 'completed' : 'failed', result } as NodeProgress
```

**Justification**: Type narrowing after conditional assignment. TypeScript doesn't fully narrow the conditional expression.

**Risk**: Low. The types align semantically.

### Chain ID Narrowing

**File**: `src/lib/web3/abis.ts`

```typescript
// Line 82
const addresses = CONTRACT_ADDRESSES[chainId as ChainId];
```

**Justification**: `chainId` is a `number`, but `ChainId` is a union of literal types. The function immediately checks if `addresses` is defined.

**Risk**: Low. The null check on the next line handles unknown chain IDs.

## Component Props Typing

### Assessment

**All 91 Svelte components with props are properly typed.** Each component defines an explicit `Props` interface and destructures from `$props()` with the type annotation.

### Positive Examples

**Button.svelte** - Extends HTML attributes:
```typescript
interface Props extends HTMLButtonAttributes {
  variant?: Variant;
  size?: Size;
  hotkey?: string;
  loading?: boolean;
  fullWidth?: boolean;
  children: Snippet;
}
```

**FeedItem.svelte** - Clear prop documentation:
```typescript
interface Props {
  /** The feed event to display */
  event: FeedEvent;
  /** Current user's address for highlighting */
  currentUserAddress?: `0x${string}` | null;
  /** Whether this is a new event (for animation) */
  isNew?: boolean;
}
```

**ActiveRunView.svelte** - Complex props with callbacks:
```typescript
interface Props {
  state: HackRunState;
  onStartNode: () => void;
  onComplete: (result: NodeResult) => void;
  // ... more props
}
```

### Pattern Consistency

All components follow the same pattern:
1. Define `Props` interface
2. Destructure with default values
3. Use `$props()` with type annotation

This consistency makes the codebase predictable and maintainable.

## Function Type Annotations

### Return Types

All functions in utility modules have explicit return types:

**format.ts** - All 8 functions typed:
```typescript
export function formatCountdown(ms: number): string { ... }
export function formatDuration(ms: number): string { ... }
export function formatHours(ms: number): string { ... }
export function formatRelativeTime(timestamp: number): string { ... }
export function formatElapsed(startTime: number): string { ... }
export function calculateWPM(charCount: number, elapsedMs: number): number { ... }
export function calculateAccuracy(typed: string, target: string): number { ... }
export function formatPercent(value: number): string { ... }
```

### Error Handling Types

Error-related functions properly use `unknown`:

```typescript
// contracts.ts
export function parseContractError(err: unknown): string { ... }

// wallet.svelte.ts  
function parseWalletError(err: unknown): string { ... }

// errors.ts
export function parseError(err: unknown): GhostnetError { ... }
export function isGhostnetError(err: unknown): err is GhostnetError { ... }
export function isRecoverable(err: unknown): boolean { ... }
export function isUserRejection(err: unknown): boolean { ... }
export function isNetworkError(err: unknown): boolean { ... }
```

This is excellent - using `unknown` instead of `any` for caught errors forces proper type narrowing.

## Type Definition Quality

### `src/lib/core/types/index.ts`

**Assessment**: Excellent

**Strengths**:
- Well-documented with JSDoc comments
- Proper use of const arrays for ordered data: `LEVELS`, `FEED_EVENT_PRIORITY`
- Discriminated unions for `FeedEventData` - each variant has a `type` field
- Branded types for addresses: `` `0x${string}` ``
- Appropriate use of `bigint` for token amounts
- Clear separation of concerns with sub-modules

**Example of excellent discriminated union**:
```typescript
export type FeedEventData =
  | { type: 'JACK_IN'; address: `0x${string}`; level: Level; amount: bigint }
  | { type: 'EXTRACT'; address: `0x${string}`; amount: bigint; gain: bigint }
  | { type: 'TRACED'; address: `0x${string}`; level: Level; amountLost: bigint }
  // ... 11 more variants
```

This enables exhaustive switch statements with TypeScript's control flow analysis.

### `src/lib/core/types/errors.ts`

**Assessment**: Excellent

**Strengths**:
- Custom `GhostnetError` class with proper error chaining
- Error codes as string literal union
- Factory functions for common errors
- Type guards: `isGhostnetError()`, `isUserRejection()`, `isNetworkError()`
- `unknown` used properly for error parsing

### `src/lib/core/types/hackrun.ts`

**Assessment**: Excellent

**Strengths**:
- Discriminated union for `HackRunState` with different shapes per status
- Proper use of `as const` for configuration objects
- Optional fields marked with `?`

### `src/app.d.ts`

**Assessment**: Good

**Strengths**:
- Proper global type augmentation for `window.ethereum`
- EIP-1193 provider interface correctly typed
- Optional wallet detection flags

**Note**: The `request` method returns `Promise<unknown>` which is correct - the actual return type depends on the RPC method called.

## Third-Party Library Types

| Library | Has Types | Source | Issues |
|---------|-----------|--------|--------|
| viem | Yes | Built-in | None |
| @wagmi/core | Yes | Built-in | None |
| @wagmi/connectors | Yes | Built-in | None |
| svelte | Yes | Built-in | None |
| @sveltejs/kit | Yes | Built-in | None |
| vitest | Yes | Built-in | None |

All dependencies have proper TypeScript support. No `@types/*` packages are needed.

## Discriminated Union Exhaustiveness

### FeedItem.svelte - Event Type Handling

The `FeedItem.svelte` component handles all `FeedEventData` types in its derived `display` value:

```typescript
switch (data.type) {
  case 'JACK_IN': ...
  case 'EXTRACT': ...
  case 'TRACED': ...
  // ... all 15 cases
  default:
    return { prefix: '>', text: 'Unknown event', ... };
}
```

**Assessment**: Good - has a default case for forward compatibility.

**Note**: The default case prevents compile-time exhaustiveness checking from catching missing cases if new event types are added. Consider using the never pattern:

```typescript
default: {
  const _exhaustive: never = data;
  throw new Error(`Unhandled event type: ${_exhaustive}`);
}
```

However, the current approach with a graceful fallback is reasonable for a UI component.

### HackRunState Handling

The `store.svelte.ts` uses proper discriminated union narrowing:

```typescript
const currentMultiplier = $derived.by(() => {
  if (state.status === 'idle' || state.status === 'selecting') {
    return 0;
  }
  if (state.status === 'complete') {
    return state.result.finalMultiplier; // TypeScript knows state has result
  }
  // ...
});
```

**Assessment**: Excellent - TypeScript's control flow analysis is leveraged properly.

## LSP-Detected Type Errors

During review, the TypeScript language server identified several type errors that indicate missing type exports or incomplete interface definitions:

### Missing Type Exports

**Files affected**: `+page.svelte` (routes), `StreakProgress.svelte`, `MissionCard.svelte`, `DailyOpsPanel.svelte`

```
Module '"$lib/core/types"' has no exported member 'DailyProgress'.
Module '"$lib/core/types"' has no exported member 'DailyMission'.
```

**Analysis**: The types `DailyProgress` and `DailyMission` are defined in `$lib/core/types/daily.ts` and should be re-exported from `$lib/core/types/index.ts`. The `daily.ts` file IS listed in the re-exports, but these specific types may be missing from the file's exports.

**Files affected**: `market/+page.svelte`

```
Module '"$lib/core/types"' has no exported member 'Consumable'.
Module '"$lib/core/types"' has no exported member 'OwnedConsumable'.
```

**Analysis**: Similar issue - `Consumable` and `OwnedConsumable` should be exported from `$lib/core/types/market.ts`.

### Missing Provider Interface Methods

**File**: `market/+page.svelte`

```
Property 'ownedConsumables' does not exist on type 'DataProvider'.
Property 'purchaseConsumable' does not exist on type 'DataProvider'.
Property 'useConsumable' does not exist on type 'DataProvider'.
```

**Analysis**: The `DataProvider` interface is missing methods/properties for consumable functionality. The implementation may exist in the mock provider, but the interface type doesn't declare them.

### Implicit `any` in Callback

**File**: `market/+page.svelte`, Line 163

```typescript
const owned = ownedConsumables.find((o) => o.consumableId === consumableId);
//                                   ^ Parameter 'o' implicitly has an 'any' type
```

**Analysis**: This is a cascading error - because `ownedConsumables` has an implicit `any` type (due to the missing provider property), the callback parameter `o` also becomes `any`.

### Severity Assessment

| Issue | Severity | Impact |
|-------|----------|--------|
| Missing type exports | High | Compile-time errors |
| Missing provider methods | High | Compile-time errors |
| Implicit `any` | Medium | Type safety gap |

**Root Cause**: These appear to be integration issues where feature implementation proceeded faster than interface updates. The types and implementations exist but the interface contracts are incomplete.

**Recommendation**: 
1. Verify `DailyProgress`, `DailyMission` are exported from `daily.ts`
2. Verify `Consumable`, `OwnedConsumable` are exported from `market.ts`
3. Update `DataProvider` interface to include consumable-related methods
4. Run `just web-build` to catch all type errors

## Summary

| Category | Count | Severity |
|----------|-------|----------|
| `any` usage | 4 | Low (test files only) |
| Unsafe casts | 1 | Medium (documented SSR workaround) |
| Justified assertions | ~35 | N/A |
| Missing type exports | 4 | High (compile errors) |
| Missing interface methods | 3 | High (compile errors) |
| Implicit `any` (cascading) | 1 | Medium |
| Untyped props | 0 | N/A |

## Recommendations

### High Priority

1. **Fix missing type exports**

   Ensure these types are exported from their respective modules:
   - `DailyProgress`, `DailyMission` from `types/daily.ts`
   - `Consumable`, `OwnedConsumable` from `types/market.ts`

2. **Update DataProvider interface**

   Add missing consumable methods to the provider interface:
   ```typescript
   interface DataProvider {
     // ... existing properties
     ownedConsumables: OwnedConsumable[];
     purchaseConsumable(id: string, quantity: number): Promise<void>;
     useConsumable(id: string): Promise<UseConsumableResult>;
   }
   ```

### Medium Priority

1. **Add exhaustive checking to FeedItem switch**

   Consider adding a compile-time exhaustiveness check:
   ```typescript
   default: {
     // Uncomment in development to catch missing cases:
     // const _exhaustive: never = data;
     return { prefix: '>', text: 'Unknown event', ... };
   }
   ```

2. **Document SSR config assertion**

   Expand the comment on line 86 of `config.ts` to explain why the double assertion is necessary and safe.

### Low Priority / Nice-to-Have

1. **Consider mock types for tests**

   Create reusable mock type helpers to reduce `as any` in test files:
   ```typescript
   // test-utils/mocks.ts
   type MockChain = Pick<Chain, 'id' | 'name'>;
   type MockBalance = Pick<GetBalanceReturnType, 'value'>;
   ```

2. **Wagon CLI for contract types**

   If contract ABIs change frequently, consider using `@wagmi/cli` to generate type-safe contract hooks. This would eliminate the need for manual `as Promise<bigint>` assertions.

### Type System Improvements Already Implemented

The codebase already implements several best practices:
- Branded types for addresses (`\`0x${string}\``)
- Discriminated unions for complex state
- Proper use of `unknown` for error handling
- Const assertions for configuration objects
- Generic factory functions with proper type inference
- Explicit interface definitions for component props

## Conclusion

The GHOSTNET web application demonstrates **strong type safety practices** in its core architecture. The development team has clearly prioritized type correctness, using TypeScript's advanced features (discriminated unions, branded types, proper `unknown` usage) appropriately without over-engineering.

**Strengths:**
- No `any` in production code
- Well-designed type definitions with discriminated unions
- Consistent component props typing pattern
- Proper error handling with `unknown`

**Areas for Improvement:**
- Type exports and interface definitions are incomplete for the market/daily features
- These gaps cause compile-time errors that should be resolved

The absence of `any` in production code is particularly noteworthy - this indicates disciplined development practices where type safety is not sacrificed for convenience.

**Overall Grade: A-** (deducted for incomplete type exports causing compilation errors)

---

*Note: The high-priority issues identified (missing type exports, incomplete interface) are straightforward fixes that don't require architectural changes. Once resolved, this codebase would merit an A grade.*
