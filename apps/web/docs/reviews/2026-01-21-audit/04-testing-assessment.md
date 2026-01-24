# Testing Assessment

**Date**: 2026-01-21  
**Reviewer**: Akira (Automated)  
**Scope**: Test suite quality and coverage analysis

---

## Executive Summary

**7 test files reviewed**, **5 critical coverage gaps identified**, **3 test quality issues found**.

The test suite demonstrates solid foundational practices—correct file naming conventions, proper use of Vitest Browser Mode, and good behavioral testing patterns. However, there are significant coverage gaps in critical stores (settings, toast, duels, audio) and several UI components with complex logic remain untested. The E2E suite is minimal and relies on some fragile selectors.

**Overall Assessment**: The existing tests are well-written, but coverage is insufficient for a production application. Priority should be given to testing the settings store (persistence logic), toast store (timing behavior), and critical UI modals.

---

## Test File Naming Audit

| File                           | Extension Correct | Uses Runes | Status |
| ------------------------------ | ----------------- | ---------- | ------ |
| `counter.svelte.test.ts`       | `.svelte.test.ts` | Yes        | OK     |
| `wallet.svelte.test.ts`        | `.svelte.test.ts` | Yes        | OK     |
| `Counter.svelte.test.ts`       | `.svelte.test.ts` | Yes        | OK     |
| `provider.svelte.test.ts`      | `.svelte.test.ts` | Yes        | OK     |
| `hackrun/store.svelte.test.ts` | `.svelte.test.ts` | Yes        | OK     |
| `typing/store.svelte.test.ts`  | `.svelte.test.ts` | Yes        | OK     |
| `e2e/home.test.ts`             | `.test.ts`        | No (E2E)   | OK     |

### Misnamed Files (Critical)

**None found.** All test files that use Svelte 5 runes correctly use the `.svelte.test.ts` extension. This is excellent compliance with the documented convention.

---

## Test Quality Analysis

### File: `counter.svelte.test.ts`

**Location**: `src/lib/stores/counter.svelte.test.ts`

| Criteria              | Status |
| --------------------- | ------ |
| Tests Behavioral      | Yes    |
| Meaningful Assertions | Yes    |
| Edge Cases Covered    | Yes    |
| Clean Setup/Teardown  | Yes    |

**Assessment**: Excellent. This is a model test file.

**Strengths**:

- Tests behavior, not implementation
- Fresh instance per test via `beforeEach`
- Tests derived values reactively update
- Covers edge case (negative counts)
- Includes helpful documentation about file naming

**No issues found.**

---

### File: `wallet.svelte.test.ts`

**Location**: `src/lib/web3/wallet.svelte.test.ts`

| Criteria              | Status  |
| --------------------- | ------- |
| Tests Behavioral      | Yes     |
| Meaningful Assertions | Yes     |
| Edge Cases Covered    | Partial |
| Mock Boundaries       | Correct |

**Assessment**: Good quality with appropriate mocking strategy.

**Strengths**:

- Mocks external dependencies (`@wagmi/core`, `viem`), not data structures
- Tests initial state, derived values, error handling
- SSR safety tests included
- Type safety verification
- Comprehensive error scenario coverage

**Issues**:

1. **Incomplete SSR Test** (Line 179-192)

   ```typescript
   it('init returns noop cleanup in SSR', async () => {
     // Mock browser as false for this test
     vi.doMock('$app/environment', () => ({ browser: false }));
     // Need to re-import to get the mocked version
     const { createWalletStore: createSSRStore } = await import('./wallet.svelte');
   ```

   The `vi.doMock` inside a test doesn't affect already-imported modules. This test likely doesn't actually test SSR behavior. The mock needs to be set up before the import.

2. **Missing Tests**:
   - `connectWalletConnect` method not tested
   - Short address derivation edge cases (addresses of different lengths)

**Recommendations**:

- Move SSR mocks to a separate test file with proper module isolation
- Add tests for `connectWalletConnect`

---

### File: `Counter.svelte.test.ts`

**Location**: `src/lib/components/Counter.svelte.test.ts`

| Criteria               | Status |
| ---------------------- | ------ |
| Tests Behavioral       | Yes    |
| Meaningful Assertions  | Yes    |
| Edge Cases Covered     | Yes    |
| Uses Semantic Locators | Yes    |

**Assessment**: Excellent component test demonstrating best practices.

**Strengths**:

- Uses `page.getByRole()` and `page.getByTestId()` correctly
- Tests user interactions, not internal state
- Covers rendering, interactions, and edge cases
- Proper async/await with auto-retry locators

**No issues found.**

---

### File: `provider.svelte.test.ts`

**Location**: `src/lib/core/providers/mock/provider.svelte.test.ts`

| Criteria              | Status  |
| --------------------- | ------- |
| Tests Behavioral      | Yes     |
| Meaningful Assertions | Yes     |
| Edge Cases Covered    | Yes     |
| Timer Handling        | Correct |

**Assessment**: Very thorough test suite for the mock provider.

**Strengths**:

- Proper use of `vi.useFakeTimers()` and `vi.advanceTimersByTimeAsync()`
- Tests state machine transitions
- Tests subscription/unsubscription patterns
- Tests error paths (wallet not connected, no position)
- Comprehensive coverage of all provider methods

**Minor Issues**:

1. **Potential Timer Leak** (Line 26-28)
   ```typescript
   afterEach(() => {
   	provider.disconnect();
   	vi.useRealTimers();
   });
   ```
   The `disconnect()` should be wrapped in a try-catch or use `vi.restoreAllMocks()` in case the test threw before provider was created.

**Recommendations**:

- Add `try { provider?.disconnect(); } catch {}` pattern for resilience

---

### File: `hackrun/store.svelte.test.ts`

**Location**: `src/lib/features/hackrun/store.svelte.test.ts`

| Criteria               | Status    |
| ---------------------- | --------- |
| Tests Behavioral       | Yes       |
| Meaningful Assertions  | Yes       |
| Edge Cases Covered     | Yes       |
| State Machine Coverage | Excellent |

**Assessment**: Comprehensive state machine testing.

**Strengths**:

- Tests all state transitions: idle -> selecting -> countdown -> running -> complete/failed
- Tests timeout and abort scenarios
- Tests derived values (currentMultiplier, totalLoot, timeRemainingPercent)
- Proper cleanup with `store.cleanup()` and `store.reset()`
- Tests backdoor/skip functionality

**Issues**:

1. **Tautological Test** (Line 537-542)
   ```typescript
   it('resetHackRunStore clears singleton', () => {
   	resetHackRunStore();
   	// If we get here without error, the reset worked
   	expect(true).toBe(true);
   });
   ```
   This test asserts nothing meaningful. It will always pass.

**Fix**:

```typescript
it('resetHackRunStore clears singleton', () => {
	const store1 = createHackRunStore();
	store1.selectDifficulty();

	resetHackRunStore();

	const store2 = createHackRunStore();
	expect(store2.state.status).toBe('idle');
});
```

---

### File: `typing/store.svelte.test.ts`

**Location**: `src/lib/features/typing/store.svelte.test.ts`

| Criteria               | Status    |
| ---------------------- | --------- |
| Tests Behavioral       | Yes       |
| Meaningful Assertions  | Yes       |
| Pure Functions Tested  | Excellent |
| State Machine Coverage | Complete  |

**Assessment**: Exemplary test structure with separation of pure functions and state machine.

**Strengths**:

- Separates pure function tests (`calculateWpm`, `calculateAccuracy`, `calculateReward`) from state machine tests
- Comprehensive reward tier testing including speed bonuses
- Tests multi-round progression
- Tests edge cases (empty challenge list, mixed correct/incorrect, rapid key presses)
- Tests timeout behavior

**Minor Issues**:

1. **Missing `flushSync` Import Check**
   The file imports `flushSync` from 'svelte' (line 10) but never uses it in the tests. This appears to be dead code.

**Recommendations**:

- Remove unused `flushSync` import

---

### File: `e2e/home.test.ts`

**Location**: `e2e/home.test.ts`

| Criteria               | Status  |
| ---------------------- | ------- |
| Stable Selectors       | Partial |
| Meaningful Assertions  | Yes     |
| Critical Flows Covered | Minimal |
| Proper Async           | Yes     |

**Assessment**: Basic smoke test coverage, but needs expansion.

**Issues**:

1. **Fragile Selectors** (Multiple locations)

   ```typescript
   // Line 26-27: CSS class selector
   const header = page.locator('header');

   // Line 32-33: Text-based selector - fragile if copy changes
   const feedPanel = page.locator('text=LIVE FEED').first();

   // Line 77-78: CSS class pattern - breaks if class naming changes
   const feedItems = page.locator('[class*="feed-item"], [class*="FeedItem"]');

   // Line 92: Multiple selector patterns for modal
   const modal = page.locator('[role="dialog"], .modal');

   // Line 102-103: CSS class pattern
   const scanlines = page.locator('[class*="scanline"], [class*="Scanline"]');
   ```

2. **Magic Timeout** (Line 74)

   ```typescript
   await page.waitForTimeout(1000);
   ```

   Hard-coded waits are fragile. Prefer waiting for specific conditions.

3. **Test That Can't Fail** (Line 100-107)

   ```typescript
   test('scanlines overlay is present', async ({ page }) => {
   	const scanlines = page.locator('[class*="scanline"], [class*="Scanline"]');
   	const count = await scanlines.count();
   	// Either scanlines exist or they're disabled - both are valid states
   	expect(count).toBeGreaterThanOrEqual(0);
   });
   ```

   Any count >= 0 is valid, so this test literally cannot fail.

4. **Missing Critical User Flows**:
   - Jack In flow (staking)
   - Extract flow (withdrawal)
   - Typing game complete flow
   - Wallet connection flow (mocked or real)

**Recommendations**:

- Add `data-testid` attributes to key elements and use `page.getByTestId()`
- Replace text selectors with `page.getByRole()` where possible
- Remove or rewrite the scanlines test
- Add critical user journey tests

---

## Mock Boundary Issues

### Issue 1: SSR Mock Timing in wallet.svelte.test.ts

**File**: `src/lib/web3/wallet.svelte.test.ts`  
**Lines**: 179-192

**Problem**: Using `vi.doMock` inside a test after the module has already been imported doesn't affect the original import.

```typescript
describe('SSR safety', () => {
	it('init returns noop cleanup in SSR', async () => {
		// This mock is set AFTER wallet.svelte is already imported at line 65
		vi.doMock('$app/environment', () => ({ browser: false }));

		// Re-import doesn't help because vi.doMock was called after module load
		const { createWalletStore: createSSRStore } = await import('./wallet.svelte');
		// ...
	});
});
```

**Fix**: Create a separate test file for SSR scenarios:

```typescript
// wallet.ssr.test.ts (runs in node environment, no .svelte prefix)
vi.mock('$app/environment', () => ({ browser: false }));

import { createWalletStore } from './wallet.svelte';

describe('Wallet SSR Safety', () => {
	it('init returns noop cleanup in SSR', () => {
		const store = createWalletStore();
		const cleanup = store.init();
		expect(typeof cleanup).toBe('function');
		cleanup(); // Should be safe noop
	});
});
```

---

## Coverage Gap Analysis

### Untested Stores

| Store                      | Location                  | Has Tests | Priority     | Reason                                           |
| -------------------------- | ------------------------- | --------- | ------------ | ------------------------------------------------ |
| `settings/store.svelte.ts` | `src/lib/core/settings/`  | **No**    | **Critical** | Manages localStorage persistence, SSR safety     |
| `toast/store.svelte.ts`    | `src/lib/ui/toast/`       | **No**    | **High**     | Timer-based auto-removal, used throughout app    |
| `duels/store.svelte.ts`    | `src/lib/features/duels/` | **No**    | **High**     | Complex state machine, opponent simulation       |
| `audio/manager.svelte.ts`  | `src/lib/core/audio/`     | **No**    | Medium       | Integration with settings, browser-only behavior |
| `stores/index.svelte.ts`   | `src/lib/core/stores/`    | **No**    | Low          | Thin wrapper over provider                       |

### Critical Store: Settings Store

**File**: `src/lib/core/settings/store.svelte.ts`

**Why it needs tests**:

- Persists to `localStorage`
- Has SSR guards (`browser` checks)
- Validates volume range (0-1)
- Uses Svelte context API

**Recommended test coverage**:

```typescript
// settings/store.svelte.test.ts
describe('createSettingsStore', () => {
	describe('initial state', () => {
		it('loads default settings when no localStorage');
		it('loads saved settings from localStorage');
		it('merges partial saved settings with defaults');
		it('handles corrupted localStorage gracefully');
	});

	describe('persistence', () => {
		it('saves to localStorage on setting change');
		it('validates volume is clamped to 0-1 range');
	});

	describe('reset', () => {
		it('restores all defaults');
		it('persists reset to localStorage');
	});
});
```

### Critical Store: Toast Store

**File**: `src/lib/ui/toast/store.svelte.ts`

**Why it needs tests**:

- Uses `setTimeout` for auto-removal
- Relies on `crypto.randomUUID()`
- Must handle rapid add/remove sequences

**Recommended test coverage**:

```typescript
// toast/store.svelte.test.ts
describe('createToastStore', () => {
	beforeEach(() => vi.useFakeTimers());
	afterEach(() => vi.useRealTimers());

	it('adds toast with generated ID');
	it('removes toast after duration');
	it('does not auto-remove when duration is 0');
	it('manual remove works before auto-remove');
	it('clear removes all toasts');
	it('convenience methods set correct type');
});
```

### Untested Features

| Feature            | Location                        | Has Tests | Priority     |
| ------------------ | ------------------------------- | --------- | ------------ |
| `JackInModal`      | `src/lib/features/modals/`      | **No**    | **Critical** |
| `ExtractModal`     | `src/lib/features/modals/`      | **No**    | **Critical** |
| `WalletModal`      | `src/lib/features/modals/`      | **No**    | High         |
| `SettingsModal`    | `src/lib/features/modals/`      | **No**    | High         |
| `FeedPanel`        | `src/lib/features/feed/`        | **No**    | High         |
| `PositionPanel`    | `src/lib/features/position/`    | **No**    | High         |
| `LeaderboardTable` | `src/lib/features/leaderboard/` | **No**    | Medium       |

### Untested UI Primitives

| Component        | Location                 | Has Tests | Priority |
| ---------------- | ------------------------ | --------- | -------- |
| `Button`         | `src/lib/ui/primitives/` | **No**    | Medium   |
| `Modal`          | `src/lib/ui/modal/`      | **No**    | High     |
| `ProgressBar`    | `src/lib/ui/primitives/` | **No**    | Low      |
| `AnimatedNumber` | `src/lib/ui/primitives/` | **No**    | Low      |

### Untested Routes

| Route            | Has Tests             | Priority |
| ---------------- | --------------------- | -------- |
| `/typing`        | E2E only (navigation) | High     |
| `/leaderboard`   | E2E only (navigation) | Medium   |
| `/games/hackrun` | **No**                | High     |
| `/games/duels`   | **No**                | High     |
| `/market`        | **No**                | Medium   |
| `/crew`          | **No**                | Medium   |

---

## E2E Test Assessment

### Selector Stability Analysis

| Selector Type                  | Count | Risk     |
| ------------------------------ | ----- | -------- |
| `page.getByRole()`             | 2     | Low      |
| `page.getByTestId()`           | 1     | Low      |
| `page.locator('text=...')`     | 5     | Medium   |
| `page.locator('header')`       | 1     | Medium   |
| `page.locator('[class*=...]')` | 3     | **High** |
| `page.locator('nav')`          | 1     | Medium   |

### Fragile Selectors Identified

1. `page.locator('[class*="feed-item"], [class*="FeedItem"]')` - CSS class names may change
2. `page.locator('[class*="scanline"], [class*="Scanline"]')` - CSS class names may change
3. `page.locator('[role="dialog"], .modal')` - Mixing semantic and class selectors

### Missing User Flows

| Flow                    | Covered | Priority |
| ----------------------- | ------- | -------- |
| Page loads successfully | Yes     | -        |
| Connect wallet (mock)   | **No**  | Critical |
| Jack In (stake)         | **No**  | Critical |
| Extract (withdraw)      | **No**  | Critical |
| Play typing game        | **No**  | High     |
| Complete typing game    | **No**  | High     |
| Navigate between pages  | Partial | Medium   |
| Change settings         | **No**  | Medium   |

---

## Configuration Review

### vite.config.ts

| Check                        | Status         | Notes                     |
| ---------------------------- | -------------- | ------------------------- |
| Browser mode enabled         | Yes            | Line 32-34                |
| Playwright provider          | Yes            | Line 33                   |
| `.svelte` in include pattern | Yes            | Line 37                   |
| Setup files configured       | Yes            | Line 38                   |
| Multi-project setup          | Yes            | client/server/ssr         |
| `conditions: ['browser']`    | **Not needed** | Browser mode handles this |

**Assessment**: Configuration is correct and follows best practices.

```typescript
// Correctly configured multi-project setup
test: {
  projects: [
    {
      extends: true,
      test: {
        name: 'client',
        browser: {
          enabled: true,
          provider: playwright(),
          instances: [{ browser: 'chromium' }],
        },
        include: ['src/**/*.svelte.{test,spec}.{js,ts}'],
        setupFiles: ['./src/vitest-setup-client.ts'],
      },
    },
    // ...server and ssr projects
  ],
}
```

### playwright.config.ts

| Check              | Status | Notes                   |
| ------------------ | ------ | ----------------------- |
| Test directory     | Yes    | `./e2e`                 |
| Output directory   | Yes    | `./test-results`        |
| Parallel execution | Yes    | `fullyParallel: true`   |
| Retry on CI        | Yes    | 2 retries               |
| Base URL           | Yes    | `http://localhost:4173` |
| Trace on failure   | Yes    | `on-first-retry`        |
| Web server command | Yes    | Build + preview         |

**Assessment**: Configuration is solid. Consider adding multiple browser projects for cross-browser testing.

### vitest-setup-client.ts

```typescript
/// <reference types="vitest-browser-svelte" />
import 'vitest-browser-svelte';
```

**Assessment**: Minimal and correct.

---

## Recommendations

### Critical (Fix Now)

1. **Add Settings Store Tests**
   - Persistence logic has no test coverage
   - SSR guards need verification
   - Volume clamping needs verification
   - Priority: Day 1

2. **Add Toast Store Tests**
   - Timer-based removal is untested
   - Used throughout the application
   - Priority: Day 1

3. **Add JackIn/Extract Modal Tests**
   - Core game functionality
   - User can lose real value if broken
   - Priority: Day 2

4. **Fix Tautological Test in hackrun/store.svelte.test.ts**
   - Line 537-542: Test asserts nothing
   - Priority: Immediate

### High Priority

5. **Add Duels Store Tests**
   - Complex state machine with opponent simulation
   - Multiple failure modes possible
   - Priority: Week 1

6. **Expand E2E Coverage**
   - Add wallet connection flow (mocked)
   - Add Jack In -> Extract flow
   - Add typing game completion flow
   - Priority: Week 1

7. **Replace Fragile E2E Selectors**
   - Add `data-testid` to feed items, modals, scanlines
   - Use `page.getByRole()` over `page.locator('text=...')`
   - Priority: Week 1

8. **Fix SSR Test in wallet.svelte.test.ts**
   - Move to separate file with proper module isolation
   - Priority: Week 1

### Improvements

9. **Add FeedPanel Component Tests**
   - Tests event rendering, filtering, subscription
   - Priority: Week 2

10. **Add Modal Component Tests**
    - Test open/close, backdrop click, escape key
    - Priority: Week 2

11. **Add Button/ProgressBar Primitive Tests**
    - Test variants, disabled states, accessibility
    - Priority: Week 2

12. **Remove Unused Import in typing/store.svelte.test.ts**
    - `flushSync` is imported but never used
    - Priority: Low

---

## Test Metrics Summary

| Metric              | Current    | Target       |
| ------------------- | ---------- | ------------ |
| Test files          | 7          | 20+          |
| Stores with tests   | 5/10 (50%) | 10/10 (100%) |
| Features with tests | 2/15 (13%) | 8/15 (53%)   |
| E2E user flows      | 2          | 8+           |
| Fragile selectors   | 3          | 0            |

---

## Appendix: Test File Inventory

### Unit/Component Tests (Vitest Browser Mode)

| File                           | Lines | Tests | Quality   |
| ------------------------------ | ----- | ----- | --------- |
| `counter.svelte.test.ts`       | 81    | 8     | Excellent |
| `wallet.svelte.test.ts`        | 407   | 26    | Good      |
| `Counter.svelte.test.ts`       | 102   | 9     | Excellent |
| `provider.svelte.test.ts`      | 497   | 35    | Very Good |
| `hackrun/store.svelte.test.ts` | 544   | 33    | Very Good |
| `typing/store.svelte.test.ts`  | 636   | 47    | Excellent |

### E2E Tests (Playwright)

| File           | Lines | Tests | Quality    |
| -------------- | ----- | ----- | ---------- |
| `home.test.ts` | 143   | 12    | Needs Work |

**Total**: 158 test cases across 7 files.
