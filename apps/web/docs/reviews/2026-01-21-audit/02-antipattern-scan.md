# Svelte 5 Antipattern Scan

**Date**: 2026-01-21  
**Reviewer**: Akira (Automated)  
**Scope**: Systematic antipattern detection across web app

## Executive Summary

**6 antipatterns found across 15 files, 1 critical, 2 high, 3 moderate**

The codebase is generally well-structured and follows Svelte 5 best practices. The most significant issue is the incorrect use of `$derived(() => ...)` with arrow functions instead of direct expressions or `$derived.by()` in one file. There are also several missing keys in `{#each}` blocks that could cause subtle bugs with component state.

---

## Findings by Category

### Category 1: Incorrect $derived with Arrow Functions (CRITICAL)

**Severity**: Critical  
**Instances Found**: 5 (all in one file)

The pattern `$derived(() => expr)` creates a function that returns a value, **not** a reactive derived value. This means the value is recalculated on every access rather than being cached. In templates, this becomes a getter function call pattern - one of the catastrophic antipatterns documented.

#### Instance 1

**File**: `src/routes/games/duels/+page.svelte`  
**Lines**: 96-101

```svelte
const wagerAmount = $derived(() => {
    if (customWager) {
        return BigInt(Math.floor(parseFloat(customWager) || 0)) * 10n ** 18n;
    }
    return DUEL_TIERS[selectedTier].minWager;
});
```

**Problem**: `$derived()` takes an expression, not a function. This creates a function that must be called with `wagerAmount()` - and if called in a template, recalculates every render.

**Fix**:

```svelte
const wagerAmount = $derived.by(() => {
    if (customWager) {
        return BigInt(Math.floor(parseFloat(customWager) || 0)) * 10n ** 18n;
    }
    return DUEL_TIERS[selectedTier].minWager;
});
```

#### Instance 2

**File**: `src/routes/games/duels/+page.svelte`  
**Lines**: 103-106

```svelte
const potentialPayout = $derived(() => {
    const { payout } = calculateDuelWinnings(wagerAmount());
    return payout;
});
```

**Fix**:

```svelte
const potentialPayout = $derived.by(() => {
    const { payout } = calculateDuelWinnings(wagerAmount);
    return payout;
});
```

#### Instance 3

**File**: `src/routes/games/duels/+page.svelte`  
**Lines**: 109-113

```svelte
const userProgressPercent = $derived(() => {
    if (store.state.status !== 'active') return 0;
    const { yourProgress, duel } = store.state;
    return Math.min(100, (yourProgress.correctChars / duel.challenge.command.length) * 100);
});
```

**Fix**:

```svelte
const userProgressPercent = $derived.by(() => {
    if (store.state.status !== 'active') return 0;
    const { yourProgress, duel } = store.state;
    return Math.min(100, (yourProgress.correctChars / duel.challenge.command.length) * 100);
});
```

#### Instance 4

**File**: `src/routes/games/duels/+page.svelte`  
**Lines**: 115-121

```svelte
const userWpm = $derived(() => {
    if (store.state.status !== 'active') return 0;
    const { yourProgress } = store.state;
    const elapsed = yourProgress.currentTime - yourProgress.startTime;
    if (elapsed <= 0) return 0;
    return Math.round((yourProgress.correctChars / 5 / elapsed) * 60000);
});
```

**Fix**:

```svelte
const userWpm = $derived.by(() => {
    if (store.state.status !== 'active') return 0;
    const { yourProgress } = store.state;
    const elapsed = yourProgress.currentTime - yourProgress.startTime;
    if (elapsed <= 0) return 0;
    return Math.round((yourProgress.correctChars / 5 / elapsed) * 60000);
});
```

#### Instance 5

**File**: `src/routes/games/duels/+page.svelte`  
**Lines**: 123-128

```svelte
const timeRemaining = $derived(() => {
    if (store.state.status !== 'active') return 0;
    const { yourProgress, duel } = store.state;
    const elapsed = yourProgress.currentTime - yourProgress.startTime;
    return Math.max(0, duel.challenge.timeLimit * 1000 - elapsed);
});
```

**Fix**:

```svelte
const timeRemaining = $derived.by(() => {
    if (store.state.status !== 'active') return 0;
    const { yourProgress, duel } = store.state;
    const elapsed = yourProgress.currentTime - yourProgress.startTime;
    return Math.max(0, duel.challenge.timeLimit * 1000 - elapsed);
});
```

**Note**: After fixing these to use `$derived.by()`, the template usages must also be updated from `{wagerAmount()}` to `{wagerAmount}` (remove the function call).

---

### Category 2: Missing Keys in {#each} Blocks

**Severity**: High  
**Instances Found**: 10

Missing keys in `{#each}` blocks cause inefficient DOM updates and can lead to subtle bugs when components have internal state.

#### Instance 1

**File**: `src/lib/features/market/PurchaseModal.svelte`  
**Line**: 104

```svelte
{#each presets as preset}
```

**Fix**:

```svelte
{#each presets as preset (preset)}
```

#### Instance 2

**File**: `src/lib/features/deadpool/BetModal.svelte`  
**Line**: 213

```svelte
{#each presets as preset}
```

**Fix**:

```svelte
{#each presets as preset (preset)}
```

#### Instance 3

**File**: `src/lib/features/modals/JackInModal.svelte`  
**Line**: 166

```svelte
{#each LEVELS as level}
```

**Fix**:

```svelte
{#each LEVELS as level (level)}
```

#### Instance 4

**File**: `src/routes/rabbit/+page.svelte`  
**Line**: 52

```svelte
{#each rabbits as rabbit}
```

**Fix**:

```svelte
{#each rabbits as rabbit (rabbit.id)}
```

#### Instance 5

**File**: `src/routes/rabbit/+page.svelte`  
**Line**: 65

```svelte
{#each colors as c}
```

**Fix**:

```svelte
{#each colors as c (c.value)}
```

#### Instance 6

**File**: `src/routes/rabbit/+page.svelte`  
**Line**: 78

```svelte
{#each colors as c}
```

**Fix**:

```svelte
{#each colors as c (c.value)}
```

#### Instance 7

**File**: `src/routes/rabbit/+page.svelte`  
**Line**: 92

```svelte
{#each rabbits as rabbit}
```

**Fix**:

```svelte
{#each rabbits as rabbit (rabbit.id)}
```

#### Instance 8

**File**: `src/lib/features/typing/IdleView.svelte`  
**Line**: 111

```svelte
{#each rewardTiers as tier}
```

**Fix**:

```svelte
{#each rewardTiers as tier, i (i)}
```

Or if tiers have unique properties:

```svelte
{#each rewardTiers as tier (tier.accuracy)}
```

#### Instance 9

**File**: `src/lib/features/typing/IdleView.svelte`  
**Line**: 133

```svelte
{#each speedBonuses as bonus}
```

**Fix**:

```svelte
{#each speedBonuses as bonus, i (i)}
```

#### Instance 10

**File**: `src/lib/features/leaderboard/CategoryTabs.svelte`  
**Line**: 25

```svelte
{#each categories as category}
```

**Fix**:

```svelte
{#each categories as category (category)}
```

#### Instance 11

**File**: `src/lib/features/header/KeyboardHints.svelte`  
**Lines**: 28, 45, 62

```svelte
{#each actionShortcuts as shortcut}
{#each gameShortcuts as shortcut}
{#each socialShortcuts as shortcut}
```

**Fix**:

```svelte
{#each actionShortcuts as shortcut (shortcut.key)}
{#each gameShortcuts as shortcut (shortcut.key)}
{#each socialShortcuts as shortcut (shortcut.key)}
```

---

### Category 3: Global State in Module-Level Singletons

**Severity**: Moderate  
**Instances Found**: 1

The wallet store creates a singleton at module level. While this is guarded with `browser` checks, it creates global state that persists across HMR and could cause issues in SSR contexts.

#### Instance 1

**File**: `src/lib/web3/wallet.svelte.ts`  
**Line**: 429

```typescript
/** Global wallet store instance */
export const wallet = createWalletStore();
```

**Current Mitigations**: The store has proper `browser` guards throughout and doesn't export raw `$state` values (uses getters instead).

**Assessment**: This is an intentional design choice for wallet state that needs to persist across navigation. The implementation is SSR-safe due to the guards. **No immediate fix needed**, but document the intention.

---

### Category 4: Potential for Heavy Computation in Templates

**Severity**: Low  
**Instances Found**: 2 (acceptable patterns)

These are minor and don't require changes, but worth documenting for awareness.

#### Instance 1

**File**: `src/lib/features/hackrun/ActiveRunView.svelte`  
**Lines**: 158-162

The template calls `calculateAccuracy()` and `calculateWPM()` directly:

```svelte
<span class="typing-value"
	>{Math.round(calculateAccuracy(typed, currentNode.challenge.command) * 100)}%</span
>
...
<span class="typing-value">{calculateWPM(typed.length, Date.now() - typingStartTime)}</span>
```

**Assessment**: These calculations are simple O(1) operations and the component re-renders frequently during typing anyway. Using `$derived` here would add complexity without meaningful benefit. **No fix needed**.

#### Instance 2

**File**: `src/lib/features/typing/ActiveView.svelte`  
**Lines**: 36-45

Uses `$derived` correctly for computed values:

```svelte
let accuracy = $derived( calculateAccuracy(progress.correctChars, progress.typed.length) ); let wpm
= $derived( calculateWpm(progress.correctChars, timeElapsed) );
```

**Assessment**: Correct pattern. **No fix needed**.

---

## Summary Table

| Antipattern                                      | Count | Severity | Files Affected                    |
| ------------------------------------------------ | ----- | -------- | --------------------------------- |
| `$derived(() => ...)` instead of `$derived.by()` | 5     | Critical | `routes/games/duels/+page.svelte` |
| Missing `{#each}` keys                           | 11    | High     | 6 files                           |
| Module-level singleton                           | 1     | Moderate | `lib/web3/wallet.svelte.ts`       |

---

## Files with No Issues

The following files were scanned and found to follow Svelte 5 best practices:

### Stores (`.svelte.ts` files)

- `src/lib/features/duels/store.svelte.ts` - Correct factory pattern with getters
- `src/lib/core/providers/mock/provider.svelte.ts` - Correct factory pattern with getters
- `src/lib/features/hackrun/store.svelte.ts` - Excellent: uses `$derived.by()` correctly, proper cleanup
- `src/lib/core/audio/manager.svelte.ts` - No runes (plain TypeScript), correct
- `src/lib/core/settings/store.svelte.ts` - Correct context-based pattern
- `src/lib/ui/toast/store.svelte.ts` - Correct context-based pattern
- `src/lib/features/typing/store.svelte.ts` - Correct factory pattern with getters
- `src/lib/core/stores/index.svelte.ts` - Correct context-based pattern
- `src/lib/stores/counter.svelte.ts` - Correct example pattern

### Route Components

- `src/routes/+layout.svelte` - Correct effect cleanup, proper context initialization
- `src/routes/+page.svelte` - Proper effect cleanup for media queries
- `src/routes/typing/+page.svelte` - Correct effect cleanup
- `src/routes/market/+page.svelte` - Correct effect cleanup
- `src/routes/games/hackrun/+page.svelte` - Correct effect usage
- `src/routes/leaderboard/+page.svelte` - Simple, no antipatterns
- `src/routes/crew/+page.svelte` - No antipatterns

### Feature Components (Verified Clean)

- `src/lib/features/feed/FeedPanel.svelte` - Correct `$derived` usage, proper keys
- `src/lib/features/feed/FeedItem.svelte` - Correct `$derived.by()` usage
- `src/lib/features/position/PositionPanel.svelte` - Correct `$derived.by()` usage
- `src/lib/features/hackrun/ActiveRunView.svelte` - Correct patterns
- `src/lib/features/hackrun/NodeMap.svelte` - Correct `$derived` and keys
- `src/lib/features/typing/ActiveView.svelte` - Correct `$derived` usage

### UI Components (Verified Clean)

- `src/lib/ui/modal/Modal.svelte` - Correct effect for dialog sync
- `src/lib/ui/primitives/Countdown.svelte` - Correct lifecycle management
- `src/lib/ui/primitives/AnimatedNumber.svelte` - Correct effect for tweened updates
- `src/lib/ui/visualizations/HeartbeatMonitor.svelte` - Correct cleanup
- `src/lib/features/welcome/MatrixRain.svelte` - Correct cleanup in onMount

---

## Recommendations

### Priority 1: Critical (Fix Immediately)

1. **Fix `$derived` usage in duels page**
   - Change all `$derived(() => ...)` to `$derived.by(() => ...)`
   - Update template usages from `{value()}` to `{value}`
   - This is likely causing performance issues during active duels

### Priority 2: High (Fix Soon)

2. **Add keys to all `{#each}` blocks**
   - Each iteration should have a unique, stable identifier
   - For simple arrays, use the index: `{#each items as item, i (i)}`
   - For object arrays, use a unique property: `{#each items as item (item.id)}`

### Priority 3: Low (Improve Later)

3. **Document singleton pattern for wallet store**
   - Add a comment explaining why global singleton is intentional
   - Consider if context-based pattern would be more appropriate

---

## Antipatterns NOT Found (Good!)

The following antipatterns were searched for but not found:

- **$effect for derived state** - All uses of `$effect` are for side effects, not derived values
- **Creating runes inside functions** - All stores use correct factory pattern
- **Reassigning to $state()** - No instances found
- **Mutating props directly** - No direct mutations found
- **Infinite effect loops** - All effects properly structured
- **Mixing Svelte 4 and 5 syntax** - No `$:` statements, no `on:event` handlers
- **`on:event` instead of `onevent`** - All handlers use Svelte 5 `onclick` etc.
- **Forgetting $bindable** - Review needed for two-way binding scenarios

---

## Appendix: Files Scanned

**Total `.svelte` files**: 108  
**Total `.svelte.ts` files**: 10

All files in the following directories were scanned:

- `src/lib/stores/`
- `src/lib/core/`
- `src/lib/features/`
- `src/lib/ui/`
- `src/lib/web3/`
- `src/lib/components/`
- `src/routes/`
