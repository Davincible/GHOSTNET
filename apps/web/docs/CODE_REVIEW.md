# Code Review: apps/web/

**Date:** January 21, 2026  
**Reviewer:** Akira (Senior Code Reviewer)  
**Scope:** Full web application review

---

## Summary

The codebase is **well-architected** with solid Svelte 5 patterns, proper TypeScript usage, and thoughtful SSR handling. The separation of concerns (core/features/ui, providers/stores) is clean. Testing patterns are appropriate with correct file naming for runes compilation.

However, I've identified several issues ranging from potential bugs to code maintainability concerns.

**Overall Assessment:** Good foundation with specific issues requiring attention before production.

---

## Critical Issues

### 1. Floating-Point Precision in Financial Calculations

**File:** `src/lib/features/modals/JackInModal.svelte:34-38`

```svelte
let parsedAmount = $derived.by(() => {
  const num = parseFloat(amountInput);
  if (isNaN(num) || num <= 0) return 0n;
  return BigInt(Math.floor(num * 1e18));  // <- Precision loss
});
```

**Problem:** Floating-point multiplication for token amounts will introduce precision errors. For example, `0.1 * 1e18` doesn't equal exactly `100000000000000000`.

**Fix:** Use viem's `parseUnits` which handles decimal strings correctly:

```typescript
import { parseUnits } from 'viem';

let parsedAmount = $derived.by(() => {
  if (!amountInput || isNaN(Number(amountInput))) return 0n;
  try {
    return parseUnits(amountInput, 18);
  } catch {
    return 0n;
  }
});
```

---

### 2. Silent Failures in Web3 Operations

**File:** `src/lib/web3/wallet.svelte.ts:193-225`

```typescript
async function connectWallet(target?: 'metaMask' | 'coinbaseWallet') {
  if (!browser) return;  // Silent return - no error feedback
  const config = getConfig();
  if (!config) return;   // Silent return - no error feedback
  // ...
}
```

**Problem:** If config is null (SSR leak, initialization race), the function returns silently. User sees nothing. This masks bugs.

**Fix:** Either set error state or throw:

```typescript
if (!config) {
  error = 'Wallet configuration not available';
  console.error('[Wallet] Config not available - possible SSR leak');
  return;
}
```

---

### 3. Unhandled Promise Rejection in JackIn Modal

**File:** `src/lib/features/modals/JackInModal.svelte:86-99`

```typescript
async function handleJackIn() {
  // ...
  try {
    await provider.jackIn(selectedLevel, parsedAmount);
    onclose();
  } catch (error) {
    console.error('Jack In failed:', error);
    // Could show error toast here  <- This comment is not implemented
  }
  // ...
}
```

**Problem:** User gets no feedback when a transaction fails. The comment acknowledges this but it's not fixed.

**Fix:**

```typescript
import { getToasts } from '$lib/ui/toast';
const toast = getToasts();

// In catch block:
catch (err) {
  const message = err instanceof Error ? err.message : 'Transaction failed';
  toast.error(message);
  console.error('Jack In failed:', err);
}
```

---

## High Priority Issues

### 4. Type Safety Erosion with `any` Casts

**File:** `src/lib/web3/contracts.ts` (lines 193, 333, 353, 374, 395, 425, 509, 521, 542)

```typescript
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const hash = await writeContract(config, request as any);
```

**Problem:** Nine instances of `any` casting suppress type checking. This is a symptom of a type mismatch between `simulateContract` return and `writeContract` input.

**Root Cause:** Wagmi's `simulateContract` returns a request with slightly different types than `writeContract` expects. The proper fix is to use the correct generic parameters.

**Fix:** Cast to the specific expected type or use wagmi's proper patterns:

```typescript
const { request } = await simulateContract(config, {
  address: tokenAddress,
  abi: dataTokenAbi,
  functionName: 'approve',
  args: [ghostCoreAddress, amount]
});
const hash = await writeContract(config, request);  // Should work with proper generics
```

If wagmi types genuinely don't align, create a helper:

```typescript
function writeSimulated<T extends WriteContractParameters>(
  config: Config,
  request: T
) {
  return writeContract(config, request);
}
```

---

### 5. Magic String Selector Fragility

**File:** `src/routes/+page.svelte:74-78`

```typescript
function handleWatchFeed() {
  const feedElement = document.querySelector('.column-left');
  if (feedElement) {
    feedElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
}
```

**Problem:** Selector `.column-left` is a CSS class that could change. This coupling between logic and styling is fragile.

**Fix:** Use a data attribute or ref:

```svelte
<div class="column column-left" data-feed-column>
```

```typescript
const feedElement = document.querySelector('[data-feed-column]');
```

---

### 6. Empty Contract Addresses Will Cause Runtime Failures

**File:** `src/lib/web3/abis.ts:36-67`

All contract addresses are empty strings:

```typescript
6343: {
  dataToken: '' as `0x${string}`,
  ghostCore: '' as `0x${string}`,
  // ...
}
```

**Observation:** `getContractAddress` correctly returns `null` for empty addresses, and contract functions guard against this. Good defensive coding.

**Suggestion:** Add a development-time warning when contracts are called but not deployed:

```typescript
export function getContractAddress(chainId: number, contract: ContractName): `0x${string}` | null {
  const addresses = CONTRACT_ADDRESSES[chainId as ChainId];
  if (!addresses) return null;
  const addr = addresses[contract];
  if (!addr || addr.length < 3) {
    if (import.meta.env.DEV) {
      console.warn(`[Contracts] ${contract} not deployed on chain ${chainId}`);
    }
    return null;
  }
  return addr;
}
```

---

## Medium Priority Issues

### 7. Timer Leak Potential in HackRun Store

**File:** `src/lib/features/hackrun/store.svelte.ts:93-96`

```typescript
let countdownInterval: ReturnType<typeof setInterval> | null = null;
let timerInterval: ReturnType<typeof setInterval> | null = null;
let resultTimeout: ReturnType<typeof setTimeout> | null = null;
```

**Observation:** Timers are properly cleared in `clearTimers()`, and `cleanup()` calls `clearTimers()`. The test file properly calls `store.cleanup()` in `afterEach`.

**Concern:** Components using this store must call `cleanup()` on destroy. Document this requirement or use a cleanup pattern that's automatic.

**Suggestion:** Add to the store's JSDoc:

```typescript
/**
 * Cleanup timers on destroy.
 * IMPORTANT: Call this in onDestroy() or $effect cleanup.
 */
cleanup(): void
```

---

### 8. Large Switch Statement Could Be a Mapping

**File:** `src/routes/+layout.svelte:51-73`

```typescript
switch (event.type) {
  case 'JACK_IN':
    audio.jackIn();
    break;
  case 'EXTRACT':
    audio.extract();
    break;
  // ... 6 more cases
}
```

**Refactor:**

```typescript
const audioHandlers: Partial<Record<FeedEventType, () => void>> = {
  JACK_IN: () => audio.jackIn(),
  EXTRACT: () => audio.extract(),
  TRACED: () => audio.traced(),
  SURVIVED: () => audio.survived(),
  JACKPOT: () => audio.jackpot(),
  TRACE_SCAN_WARNING: () => audio.scanWarning(),
  TRACE_SCAN_START: () => audio.scanStart(),
};

const handler = audioHandlers[event.type];
if (handler) handler();
```

---

### 9. Test Coverage Gaps

**File:** `src/lib/web3/wallet.svelte.test.ts:227-249`

Several tests only verify function existence:

```typescript
describe('connect', () => {
  it('exists as a function', () => {
    expect(typeof store.connect).toBe('function');
  });
});
```

**Problem:** These tests provide no coverage of actual behavior. They'll pass even if the function is broken.

**Suggestion:** Add behavioral tests with mocked wagmi responses, or mark these as integration tests that require a test network.

---

### 10. E2E Test Fragility

**File:** `e2e/home.test.ts:85-106`

```typescript
const settingsButton = page.getByRole('button', { name: /settings|gear|cog/i });

if (await settingsButton.count() === 0) {
  const settingsIcon = page.locator('button:has-text("???"), [aria-label*="settings" i]').first();
  if (await settingsIcon.count() > 0) {
    await settingsIcon.click();
  }
}
```

**Problem:** Multiple fallback strategies suggest the locator is unreliable.

**Fix:** Add a consistent test ID to the settings button:

```svelte
<button data-testid="settings-button" aria-label="Settings">
```

```typescript
const settingsButton = page.getByTestId('settings-button');
await settingsButton.click();
```

---

## Low Priority / Suggestions

### 11. Blocking Transaction Receipts

**File:** `src/lib/web3/contracts.ts`

All write functions block on `waitForTransactionReceipt`:

```typescript
const hash = await writeContract(config, request as any);
await waitForTransactionReceipt(config, { hash });
return hash;
```

**Consideration:** This blocks the UI until the transaction confirms. For better UX, consider:

- Return hash immediately after submission
- Let the UI show pending state
- Poll for confirmation separately

---

### 12. Hardcoded RPC URLs

**File:** `src/lib/web3/chains.ts`

```typescript
rpcUrls: {
  default: {
    http: ['https://carrot.megaeth.com/rpc']
  }
}
```

**Suggestion:** Consider environment variables for production flexibility:

```typescript
http: [import.meta.env.VITE_MEGAETH_RPC || 'https://carrot.megaeth.com/rpc']
```

---

### 13. Large File: HackRun Store (573 lines)

**File:** `src/lib/features/hackrun/store.svelte.ts`

**Suggestion:** Consider extracting:

- State transition helpers into a separate file
- Derived value calculations into `derived.ts`
- Type guards into `guards.ts`

---

## What's Done Well

1. **Svelte 5 Runes**: Correct usage of `$state`, `$derived`, `$effect` throughout
2. **SSR Safety**: Consistent `browser` guards in web3 code
3. **Test File Naming**: `.svelte.test.ts` pattern correctly enables runes in tests
4. **Type Definitions**: Comprehensive types in `core/types/index.ts` with discriminated unions
5. **Context Pattern**: Clean provider/context pattern for dependency injection
6. **Documentation**: Excellent internal guides in `docs/guides/SvelteBestPractices/`
7. **State Machine Design**: HackRun store demonstrates good state machine thinking
8. **Error Parsing**: User-friendly error messages in `parseWalletError` and `parseContractError`
9. **Responsive Design**: Mobile-first approach with proper breakpoints
10. **Accessibility**: Proper `aria-label` usage on interactive elements

---

## Recommendations Summary

| Priority | Count | Category |
|----------|-------|----------|
| Critical | 3 | Correctness/UX bugs |
| High | 3 | Type safety, maintainability |
| Medium | 4 | Code quality, testing |
| Low | 3 | Suggestions |

---

## Top 3 Actions

1. **Fix floating-point precision** in `JackInModal.svelte` using `parseUnits` from viem
2. **Add error toasts** for failed transactions in modals (JackIn, Extract, etc.)
3. **Address the `any` casts** in `contracts.ts` with proper typing

---

## Files Reviewed

- `package.json` - Dependencies and scripts
- `vite.config.ts` - Build configuration
- `src/routes/+layout.svelte` - Root layout
- `src/routes/+page.svelte` - Home page
- `src/lib/index.ts` - Library exports
- `src/lib/web3/*` - Web3 integration (wallet, config, chains, contracts, abis)
- `src/lib/stores/counter.svelte.ts` - Example store
- `src/lib/features/hackrun/store.svelte.ts` - Game state machine
- `src/lib/features/modals/JackInModal.svelte` - Transaction modal
- `src/lib/core/stores/index.svelte.ts` - Provider context
- `src/lib/core/providers/types.ts` - Provider interface
- `src/lib/core/types/index.ts` - Type definitions
- `src/lib/stores/counter.svelte.test.ts` - Store tests
- `src/lib/web3/wallet.svelte.test.ts` - Wallet tests
- `src/lib/features/hackrun/store.svelte.test.ts` - Game tests
- `e2e/home.test.ts` - E2E tests
