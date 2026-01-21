# Performance Pattern Review

**Date**: 2026-01-21  
**Reviewer**: Akira (Automated)  
**Scope**: Bundle size, reactivity, and runtime performance

## Executive Summary

**11 performance issues found** across the codebase. The overall performance posture is **good**—no critical anti-patterns detected (no barrel file imports, no catastrophic getter functions). However, there are several **medium-priority optimizations** that would improve rendering efficiency and reduce reactivity overhead, particularly around unkeyed `{#each}` blocks and opportunities for `$state.raw`.

| Severity | Count | Categories |
|----------|-------|------------|
| Critical | 0 | None |
| Medium | 7 | Unkeyed `{#each}`, template computations, effect scope |
| Low | 4 | `$state.raw` opportunities, data structure optimizations |

**Estimated Impact**: Low to Medium. These are incremental optimizations rather than show-stopping issues.

---

## Bundle Size Issues

### Barrel File Imports

**Status: CLEAN**

No problematic barrel file imports detected. The codebase does not import from:
- `lucide-svelte` (barrel)
- `@heroicons/*` (barrel)  
- `date-fns` (barrel)
- `lodash` (barrel)
- `rxjs` (barrel)

The project appears to use direct imports or doesn't rely on these commonly-problematic libraries. This is excellent.

---

## Reactivity Issues

### Missing `$state.raw` Opportunities

The codebase correctly uses `$state()` for reactive data. However, several large data collections that are read-only or replaced entirely could benefit from `$state.raw()` to avoid deep proxy overhead.

#### 1. Mock Provider - Feed Events Array

**File**: `src/lib/core/providers/mock/provider.svelte.ts`  
**Line**: 46

```typescript
let feedEvents = $state<FeedEvent[]>([]);
```

**Issue**: Feed events are a large array (up to 100 items) that grows via prepending. The data is display-only and never mutated in place.

**Recommendation**: Use `$state.raw`:
```typescript
let feedEvents = $state.raw<FeedEvent[]>([]);
```

**Impact**: Low. Reduces proxy creation for ~100 objects per update.

---

#### 2. Crew Browser Modal - Rankings Data

**File**: `src/lib/features/crew/CrewBrowserModal.svelte`  
**Line**: 21

```typescript
let rankings = $state(generateCrewRankings(20));
```

**Issue**: Rankings are generated once when the modal opens and displayed read-only. They're never mutated—only filtered/sorted via `$derived`.

**Recommendation**: Use `$state.raw`:
```typescript
let rankings = $state.raw(generateCrewRankings(20));
```

**Impact**: Low. Reduces proxy overhead for 20 crew objects with nested bonuses arrays.

---

#### 3. Duel Store - History and Challenges Arrays

**File**: `src/lib/features/duels/store.svelte.ts`  
**Lines**: 101-104

```typescript
let openChallenges = $state<Duel[]>([]);
let yourChallenges = $state<Duel[]>([]);
let history = $state<DuelHistoryEntry[]>([]);
```

**Issue**: These arrays are replaced entirely on refresh, not mutated. History grows to 50 items.

**Recommendation**: Use `$state.raw` for `history`:
```typescript
let history = $state.raw<DuelHistoryEntry[]>([]);
```

**Impact**: Low. History array can grow to 50 duel entries.

---

#### 4. HeartbeatMonitor - Waveform Values

**File**: `src/lib/ui/visualizations/HeartbeatMonitor.svelte`  
**Line**: 101

```typescript
let waveforms: WaveformData[] = $state(getDefaultWaveforms());
```

**Issue**: Each waveform contains a `values[]` array of 100 numeric points that's updated every 100ms. The values are pushed/shifted but could be replaced entirely.

**Recommendation**: Consider restructuring to replace arrays rather than mutate, then use `$state.raw`. Alternatively, since this is canvas-based, the values don't need Svelte reactivity at all—they're only read in the `draw()` function.

**Impact**: Medium. This is a high-frequency update (10Hz) with 400 total data points proxied.

---

### Unkeyed `{#each}` Blocks

The following `{#each}` blocks lack identity keys, causing DOM recreation instead of efficient updates:

| File | Line | Collection | Severity |
|------|------|------------|----------|
| `src/lib/features/modals/JackInModal.svelte` | 166 | `LEVELS` | Medium |
| `src/lib/features/market/PurchaseModal.svelte` | 104 | `presets` | Low |
| `src/lib/features/welcome/WelcomePanel.svelte` | 386 | `Array(totalSlides)` | Low |
| `src/lib/features/daily/StreakProgress.svelte` | 52 | `Array(7)` | Low |
| `src/lib/features/deadpool/BetModal.svelte` | 213 | `presets` | Low |
| `src/lib/features/typing/IdleView.svelte` | 111, 133 | `rewardTiers`, `speedBonuses` | Low |
| `src/lib/features/header/KeyboardHints.svelte` | 28, 45, 62 | `shortcuts` arrays | Low |
| `src/routes/rabbit/+page.svelte` | 52, 65, 78, 92 | `rabbits`, `colors` | Low |

#### High Priority Fix: JackInModal.svelte

**File**: `src/lib/features/modals/JackInModal.svelte`  
**Line**: 166

```svelte
{#each LEVELS as level}
```

**Fix**:
```svelte
{#each LEVELS as level (level)}
```

This renders 5 level selection cards. Without a key, all cards re-render when any state changes.

#### Low Priority: Static Data

The remaining unkeyed iterations are over static data (`presets`, `rewardTiers`, etc.) that never changes during the component lifecycle. Adding keys won't improve performance, but it's good practice for consistency.

**Pattern fix**:
```svelte
<!-- Static arrays - add index key -->
{#each presets as preset, i (i)}
{#each rewardTiers as tier, i (i)}
```

---

## Template Computation Issues

### Heavy Computations in Templates

#### 1. Crew Browser - Inline Filter/Sort Chain

**File**: `src/lib/features/crew/CrewBrowserModal.svelte`  
**Line**: 26-53

The `filteredCrews` derived contains multiple chained operations:

```typescript
let filteredCrews = $derived.by(() => {
    let crews = rankings.map((r) => r.crew);
    
    if (searchQuery) {
        crews = crews.filter(/* ... */);
    }
    
    switch (sortBy) {
        case 'members':
            crews = [...crews].sort((a, b) => b.memberCount - a.memberCount);
            break;
        // ...
    }
    
    return crews;
});
```

**Assessment**: This is correctly using `$derived.by()` which is the right pattern. However, the `rankings.map()` runs even when only `sortBy` changes. 

**Optimization** (optional):
```typescript
// Separate the extraction from filtering/sorting
const crews = $derived(rankings.map((r) => r.crew));
const filteredCrews = $derived.by(() => {
    let result = crews;
    // ... filter and sort
});
```

**Impact**: Low. The list is 20 items maximum.

---

#### 2. KeyboardHints - Repeated Filter Calls

**File**: `src/lib/features/header/KeyboardHints.svelte`  
**Lines**: 19-21

```typescript
const actionShortcuts = shortcuts.filter(s => s.category === 'action');
const gameShortcuts = shortcuts.filter(s => s.category === 'game');
const socialShortcuts = shortcuts.filter(s => s.category === 'social');
```

**Issue**: Three separate filter iterations over the same 6-item array. This is evaluated at component creation, not reactively.

**Assessment**: This is actually fine—it's not inside `$derived`, it's a one-time computation. The array has only 6 items. No action needed.

---

### Getter Functions (Critical Pattern Check)

**Status: CLEAN**

No instances of the catastrophic getter-function-instead-of-derived pattern found:

```typescript
// This anti-pattern does NOT exist in the codebase
const type = () => getType(value);  // BAD - would recalculate every render
```

All computed values correctly use `$derived` or `$derived.by()`. This is excellent.

---

## Effect Scope Issues

### Effects with Multiple Concerns

#### 1. HackRun Page - Audio State Tracking

**File**: `src/routes/games/hackrun/+page.svelte`  
**Lines**: 170-183

```typescript
$effect(() => {
    const status = store.state.status;

    if (status !== prevStatus) {
        if (status === 'running' && prevStatus === 'countdown') {
            audio.countdownGo();
        } else if (status === 'complete') {
            audio.gameComplete();
        } else if (status === 'failed') {
            audio.traced();
        }
        prevStatus = status;
    }
});
```

**Assessment**: This effect correctly tracks a single dependency (`store.state.status`) and manages its own comparison state. This is the correct pattern for "on change" effects. No issue.

---

#### 2. BetModal - Multiple Reset Concerns

**File**: `src/lib/features/deadpool/BetModal.svelte`  
**Lines**: 41-48

```typescript
$effect(() => {
    if (open && initialSide) {
        selectedSide = initialSide;
    } else if (!open) {
        selectedSide = null;
        amountInput = '100';
    }
});
```

**Issue**: This effect handles two distinct concerns:
1. Setting initial side when modal opens
2. Resetting state when modal closes

**Recommendation**: Split into two effects:
```typescript
// Set initial side when opening
$effect(() => {
    if (open && initialSide) {
        selectedSide = initialSide;
    }
});

// Reset state when closing
$effect(() => {
    if (!open) {
        selectedSide = null;
        amountInput = '100';
    }
});
```

**Impact**: Low. The current implementation works correctly; this is a clarity improvement.

---

## Event Listener Issues

### Missing Passive Event Listeners

**Status: CLEAN**

No scroll/touch event listeners found without passive flags. The Panel component that handles scrolling uses CSS overflow rather than manual scroll event handling.

### Event Listener Duplication

**Status: CLEAN**

The codebase uses a good pattern for keyboard handling—individual components attach their own listeners in `$effect` blocks with proper cleanup:

```typescript
$effect(() => {
    if (!browser) return;
    window.addEventListener('keydown', handleKeydown);
    return () => {
        window.removeEventListener('keydown', handleKeydown);
    };
});
```

For truly global events (like window resize), consider creating a shared store as shown in the performance guide. However, I didn't find multiple components adding the same global listener.

---

## Data Structure Issues

### O(n) Lookups

#### 1. Array.includes() for Small Sets

**File**: `src/routes/+page.svelte`  
**Line**: 151

```typescript
if (['j', 'e', 't', 'h', 'c', 'p'].includes(key)) {
```

**Assessment**: This is a 6-element array checked on keypress. Converting to `Set` would be premature optimization—the cost is negligible.

**Verdict**: No action needed.

---

#### 2. HackRun Store - Node Lookups

**File**: `src/lib/features/hackrun/store.svelte.ts`  
**Lines**: 200-206

```typescript
function getCurrentNodeIndex(progress: NodeProgress[]): number {
    return progress.findIndex((p) => p.status === 'current');
}

function getNodeById(run: HackRun, nodeId: string): HackRunNode | undefined {
    return run.nodes.find((n) => n.id === nodeId);
}
```

**Issue**: `getNodeById` is called multiple times per node transition. With only 5 nodes per run, this is O(5) per call—negligible.

**Potential optimization** (only if profiling shows issues):
```typescript
// Build a lookup map once per run
const nodeMap = $derived(
    new Map(state.run?.nodes.map(n => [n.id, n]))
);
```

**Verdict**: No action needed for current scale.

---

## Rendering Efficiency

### CSS vs `{#if}` for Frequent Toggles

The codebase correctly uses `{#if}` for modals (heavy content, infrequent toggles):

```svelte
{#if showJackInModal}
    <JackInModal ... />
{/if}
```

I didn't find cases where CSS visibility would be clearly better than `{#if}`. The modals are appropriately handled.

---

## Summary Table

| Category | Count | Severity | Est. Impact |
|----------|-------|----------|-------------|
| Barrel imports | 0 | - | None |
| Missing `$state.raw` | 4 | Low | Memory overhead |
| Unkeyed `{#each}` | 7+ | Medium | Render inefficiency |
| Heavy template computations | 0 | - | None (correctly uses `$derived`) |
| Getter functions | 0 | - | None |
| Effect scope issues | 1 | Low | Code clarity |
| Missing passive listeners | 0 | - | None |
| Data structure inefficiencies | 0 | - | Acceptable for current scale |

---

## Recommendations

### Medium Priority

1. **Add keys to dynamic `{#each}` blocks**
   - Priority fix: `JackInModal.svelte` line 166
   - Pattern: `{#each LEVELS as level (level)}`

2. **Convert large read-only arrays to `$state.raw`**
   - `feedEvents` in mock provider
   - `history` in duel store
   - `rankings` in CrewBrowserModal

### Low Priority

3. **Add keys to static `{#each}` blocks for consistency**
   - Use index keys: `{#each items as item, i (i)}`
   - Applies to: `presets`, `rewardTiers`, `shortcuts`, etc.

4. **Split the BetModal reset effect into two separate effects**
   - Improves code clarity and follows single-responsibility principle

### Optimization Opportunities (Future)

5. **HeartbeatMonitor canvas data**
   - Consider moving waveform data outside Svelte reactivity entirely
   - The values are only read in `requestAnimationFrame` draw loop
   - Could use plain arrays and avoid proxy overhead completely

6. **Shared window event stores**
   - If multiple components need window resize/scroll events, create shared stores
   - Currently not an issue—keeping this note for future scale

---

## Conclusion

The GHOSTNET web application demonstrates **solid performance practices**. The team has:

- Avoided common bundle-size pitfalls (no barrel imports)
- Correctly used `$derived` and `$derived.by()` for computed values
- Properly managed event listener lifecycles
- Kept component complexity reasonable

The identified issues are incremental optimizations rather than architectural problems. The most impactful fix is adding keys to the `{#each}` block in `JackInModal.svelte`, which renders user-interactive level selection cards.

**Overall Performance Health: Good**
