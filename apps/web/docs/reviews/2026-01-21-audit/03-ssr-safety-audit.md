# SSR Safety Audit

**Date**: 2026-01-21
**Reviewer**: Akira (Automated)
**Scope**: Server-side rendering safety verification

## Executive Summary

**3 Critical violations found** (potential server crashes)
**3 Moderate violations found** (hydration mismatch risks)
**2 Advisory notes** (global state patterns to monitor)

The GHOSTNET web application demonstrates generally solid SSR safety practices. The Web3 layer is well-guarded with consistent `browser` checks. Most stores use Svelte context for request isolation. However, several components access browser APIs without guards, and a few patterns could cause hydration mismatches.

---

## Critical: Browser API Access Without Guards

### Finding 1: `WalletModal.svelte` - Window Access at Module Scope

**File**: `src/lib/features/modals/WalletModal.svelte`
**Lines**: 28, 35, 49
**Issue**: `window.ethereum` accessed in detect functions that run during derived computation

```svelte
const wallets = [
  {
    id: 'metamask',
    name: 'MetaMask',
    icon: '...',
    description: '...',
    detect: () => typeof window !== 'undefined' && window.ethereum?.isMetaMask === true
  },
  // ... similar for coinbase and injected
];

// This derived runs during SSR
let availableWallets = $derived.by(() => {
  const detected = wallets.filter((w) => w.detect()); // <- detect() called during SSR
  // ...
});
```

**Impact**: The `detect()` functions check `typeof window !== 'undefined'` which is safe, but the pattern is fragile. The `$derived.by` runs during SSR, meaning these detect functions execute on the server. Currently safe due to the guard, but:
1. If someone removes the `typeof window` check, it crashes
2. The `availableWallets` will be empty on server, potentially different on client (hydration risk)

**Severity**: Low-Medium (currently guarded, but fragile pattern)

**Fix**: Move detection to `$effect` or add explicit `browser` import:

```svelte
<script lang="ts">
  import { browser } from '$app/environment';
  
  const wallets = [/* static wallet definitions without detect */];
  
  let availableWallets = $state<typeof wallets>([]);
  
  $effect(() => {
    if (!browser) return;
    
    availableWallets = wallets.filter(w => {
      switch (w.id) {
        case 'metamask':
          return window.ethereum?.isMetaMask === true;
        case 'coinbase':
          return window.ethereum?.isCoinbaseWallet === true;
        case 'injected':
          return window.ethereum !== undefined;
        case 'walletconnect':
          return hasWalletConnect;
        default:
          return false;
      }
    });
  });
</script>
```

---

### Finding 2: `+error.svelte` - `new Date()` in Template

**File**: `src/routes/+error.svelte`
**Line**: 80
**Issue**: `new Date().toISOString()` called directly in template

```svelte
<div class="error-log">
  <span class="log-prefix">&gt;</span>
  <span class="log-text">Timestamp: {new Date().toISOString()}</span>
</div>
```

**Impact**: Hydration mismatch guaranteed. Server renders one timestamp, client hydrates with a different timestamp milliseconds later. This causes a console warning and potential flicker.

**Severity**: Low (error page, rarely seen, but still a violation)

**Fix**: Use `$state` initialized in `$effect`:

```svelte
<script lang="ts">
  let timestamp = $state('...');
  
  $effect(() => {
    timestamp = new Date().toISOString();
  });
</script>

<!-- In template -->
<span class="log-text">Timestamp: {timestamp}</span>
```

---

### Finding 3: `AddressDisplay.svelte` - `navigator.clipboard` Without Guard

**File**: `src/lib/ui/data-display/AddressDisplay.svelte`
**Line**: 36
**Issue**: `navigator.clipboard.writeText()` called in click handler without browser guard

```svelte
async function copyToClipboard() {
  if (!copyable) return;

  try {
    await navigator.clipboard.writeText(address); // <- No browser guard
    copied = true;
    setTimeout(() => {
      copied = false;
    }, 2000);
  } catch (err) {
    console.error('Failed to copy address:', err);
  }
}
```

**Impact**: This function is only called from a click handler, so it will never execute during SSR. However, `navigator` is not defined on the server, and if this code path were ever invoked during SSR (e.g., programmatic call, testing), it would crash.

**Severity**: Very Low (click handlers don't run during SSR)

**Recommendation** (advisory, not required):

```typescript
async function copyToClipboard() {
  if (!copyable || !browser) return;
  // ... rest of function
}
```

---

## Moderate: Hydration Mismatch Risks

### Finding 4: `RunHistoryPanel.svelte` - Relative Time Calculation

**File**: `src/lib/features/hackrun/RunHistoryPanel.svelte`
**Lines**: 27-36
**Issue**: `formatTime()` uses `new Date()` which differs between server and client

```typescript
function formatTime(timestamp: number): string {
  const date = new Date(timestamp);
  const now = new Date(); // <- Different on server vs client
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMins / 60);

  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  return date.toLocaleDateString();
}
```

**Impact**: If history data is populated during SSR, the "Xm ago" text will differ between server and client render, causing hydration mismatch.

**Severity**: Low (history is likely empty during SSR with mock provider)

**Fix**: Calculate on client only:

```svelte
<script lang="ts">
  import { browser } from '$app/environment';
  
  function formatTime(timestamp: number): string {
    if (!browser) return '...'; // Consistent placeholder during SSR
    
    const now = Date.now();
    const diffMs = now - timestamp;
    // ... rest of logic
  }
</script>
```

---

### Finding 5: `MatrixRain.svelte` - Color Computation via DOM

**File**: `src/lib/features/welcome/MatrixRain.svelte`
**Lines**: 41-48
**Issue**: `document.createElement()` and `document.body` access in `onMount`, but creates temporary DOM element

```typescript
const getColor = () => {
  const temp = document.createElement('div');
  temp.style.color = color;
  document.body.appendChild(temp);
  const computed = getComputedStyle(temp).color;
  document.body.removeChild(temp);
  return computed;
};
```

**Impact**: None - this is correctly guarded inside `onMount()`. However, this is an unusual pattern that could confuse maintainers.

**Severity**: None (informational)

**Recommendation**: Consider using CSS custom properties directly or a predefined color map instead of DOM manipulation.

---

### Finding 6: `Header.svelte` - Random Value in Effect

**File**: `src/lib/features/header/Header.svelte`
**Lines**: 20-22
**Issue**: `Math.random()` used inside `setInterval` for glitch effect

```typescript
const interval = setInterval(() => {
  glitchOffset = Math.random() * 100;
}, 2000);
```

**Impact**: None for SSR (inside `onMount` context via `$effect`), but worth noting that the initial value of `glitchOffset` should be consistent.

**Severity**: None (correctly placed in effect)

---

## Web3 SSR Safety Assessment

| File | Browser Guarded | Status | Notes |
|------|-----------------|--------|-------|
| `wallet.svelte.ts` | **Yes** | PASS | All actions check `browser`, returns no-op during SSR |
| `config.ts` | **Yes** | PASS | `getConfig()` returns null during SSR, singleton created lazily |
| `contracts.ts` | **Yes** | PASS | All functions check `browser` or call `requireBrowser()` |
| `chains.ts` | N/A | PASS | Pure data definitions, no browser APIs |
| `abis.ts` | N/A | PASS | Pure data imports and exports |
| `index.ts` | N/A | PASS | Re-exports only |

**Summary**: The Web3 layer is well-protected. Key patterns observed:

1. `getConfig()` returns `null` during SSR, forcing callers to handle
2. `requireConfig()` throws during SSR (appropriate for browser-only paths)
3. All wallet actions (`connect`, `disconnect`, etc.) have explicit `if (!browser) return` guards
4. The singleton `wallet` export is created via factory that handles SSR gracefully

**One Advisory**: The `wallet` singleton is module-level state:

```typescript
// wallet.svelte.ts line 429
export const wallet = createWalletStore();
```

This is acceptable because:
1. Wallet state is inherently client-only (no user session on server)
2. The store's `init()` method does nothing during SSR
3. All methods are guarded

However, if this pattern were applied to user-specific data that should differ per request, it would leak state between requests.

---

## Global State Analysis

| Store File | SSR Safe | Pattern | Notes |
|------------|----------|---------|-------|
| `settings/store.svelte.ts` | **Yes** | Context | Uses `setContext`/`getContext`, isolated per request |
| `stores/index.svelte.ts` | **Yes** | Context | Provider initialized per layout render |
| `stores/counter.svelte.ts` | **Yes** | Factory | Pure factory function, no module-level state |
| `ui/toast/store.svelte.ts` | **Yes** | Context | Uses `setContext`/`getContext` |
| `features/typing/store.svelte.ts` | **Yes** | Factory | Returns new store instance per call |
| `features/duels/store.svelte.ts` | **Yes** | Factory | Returns new store instance per call |
| `features/hackrun/store.svelte.ts` | **Yes** | Factory | Returns new store instance per call |
| `core/providers/mock/provider.svelte.ts` | **Yes** | Factory | Created fresh via `createMockProvider()` |
| `core/audio/manager.svelte.ts` | **Partial** | Singleton | Module-level `settingsRef` and `audioInitialized` flags |

### Audio Manager Advisory

**File**: `src/lib/core/audio/manager.svelte.ts`
**Lines**: 93-94
**Issue**: Module-level mutable state

```typescript
let audioInitialized = false;
let settingsRef: SettingsStore | null = null;
```

**Impact**: In a serverless environment with module caching, this state could theoretically persist across requests. However:
1. Audio is inherently client-only
2. `audioInitialized` is only set in `initAudio()` which checks `browser`
3. `settingsRef` is reset each time `createAudioManager()` is called

**Severity**: Very Low (effectively safe due to browser guards)

---

## Visualization Components Analysis

All visualization components (`HeartbeatMonitor.svelte`, `RadarSweep.svelte`, `NetworkGlobe.svelte`, `OrbitalTracker.svelte`, `MatrixRain.svelte`, `RabbitWireframe.svelte`, etc.) follow the same safe pattern:

1. Canvas/WebGL setup in `onMount()` only
2. `window.devicePixelRatio` accessed only after mount
3. `requestAnimationFrame` called only after mount
4. Cleanup in return function or `onDestroy()`

**Status**: PASS - All visualization components are SSR-safe.

---

## Routes Analysis

| Route | SSR Safe | Notes |
|-------|----------|-------|
| `+layout.svelte` | **Yes** | Document listeners in `onMount()`, properly cleaned up |
| `+page.svelte` (index) | **Yes** | `window.matchMedia` in `$effect` with `browser` guard |
| `+error.svelte` | **No** | `new Date()` in template (see Finding 2) |
| `/typing/+page.svelte` | **Yes** | `window.addEventListener` in `$effect` |
| `/games/hackrun/+page.svelte` | **Yes** | `window.addEventListener` in `$effect` |
| `/games/duels/+page.svelte` | **Yes** | `window.addEventListener` in `$effect` |

---

## Summary

| Category | Count | Severity |
|----------|-------|----------|
| Unguarded browser APIs | 1 | Low (navigator.clipboard in click handler) |
| Hydration mismatch risks | 2 | Low (error page timestamp, relative time) |
| Fragile detection pattern | 1 | Low-Medium (WalletModal window checks) |
| Module-level mutable state | 2 | Advisory (wallet singleton, audio state) |

**Overall Assessment**: The codebase demonstrates good SSR awareness. The development team has consistently used:
- `browser` import from `$app/environment`
- `onMount()` for browser-only initialization
- `$effect()` for client-side reactive code
- Svelte context for request-isolated state

The violations found are minor and unlikely to cause production issues.

---

## Recommendations (Priority Order)

### High Priority

1. **Fix `+error.svelte` timestamp** - Easy fix, eliminates guaranteed hydration mismatch
   
2. **Refactor `WalletModal.svelte` detection** - Move to `$effect` for cleaner pattern and prevent future accidents

### Low Priority

3. **Add `browser` guard to `AddressDisplay.svelte`** - Defensive programming, prevents potential test failures

4. **Fix `RunHistoryPanel.svelte` relative time** - Only matters if SSR renders with populated history data

### Advisory (No Action Required)

5. **Document wallet singleton pattern** - Add comment explaining why module-level state is acceptable here

6. **Consider audio manager refactor** - Could use context pattern for consistency, but current implementation is safe

---

## Verification Commands

To verify these findings, run:

```bash
# Search for unguarded window access
grep -rn "window\." apps/web/src --include="*.svelte" --include="*.ts" | grep -v "typeof window" | grep -v "// " | grep -v onMount | grep -v "\$effect"

# Search for new Date() in templates (potential hydration issues)
grep -rn "new Date()" apps/web/src --include="*.svelte" | grep -v "<script"

# Search for module-level $state exports (potential state leaks)
grep -rn "export.*\$state" apps/web/src --include="*.ts" --include="*.svelte.ts"

# Verify all stores use context or factory pattern
grep -rn "export const.*=" apps/web/src/lib/**/store*.ts apps/web/src/lib/**/*.svelte.ts
```

---

*End of SSR Safety Audit*
