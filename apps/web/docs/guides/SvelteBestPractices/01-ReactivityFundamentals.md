# 1. Reactivity Fundamentals

## The Svelte 5 Paradigm Shift

Svelte 5 replaces implicit reactivity with **explicit runes**. Variables are reactive based on *how* they're declared, not *where*.

```svelte
<!-- Svelte 4: Implicit -->
<script>
  let count = 0;           // Reactive because top-level
  $: doubled = count * 2;  // Reactive statement
</script>

<!-- Svelte 5: Explicit -->
<script>
  let count = $state(0);              // Explicitly reactive
  const doubled = $derived(count * 2); // Explicitly derived
</script>
```

## Complete Runes Reference

| Rune | Purpose | Returns |
|------|---------|---------|
| `$state(value)` | Declare reactive state | Reactive proxy (objects/arrays) or primitive |
| `$state.raw(value)` | Non-deeply-reactive state | Plain value (no proxy) |
| `$state.snapshot(proxy)` | Extract plain object from proxy | Plain JavaScript object |
| `$derived(expression)` | Simple computed value | Cached computed value |
| `$derived.by(() => value)` | Complex computed value | Cached computed value |
| `$effect(() => {})` | Side effects | Cleanup function (optional) |
| `$effect.pre(() => {})` | Pre-DOM-update effects | Cleanup function (optional) |
| `$effect.root(() => {})` | Manual effect lifecycle | Cleanup function |
| `$effect.tracking()` | Check if in reactive context | Boolean |
| `$props()` | Declare component props | Props object |
| `$bindable(fallback?)` | Two-way bindable prop | Bindable value |
| `$inspect(value)` | Debug reactive values | void (dev only) |
| `$inspect.trace(label?)` | Trace effect dependencies | void (dev only) |
| `$host()` | Access custom element host | HTMLElement |

## Critical Rule: Declaration Context

Runes can **only** be used in:
1. Variable declaration initializers at module/component top level
2. Class field definitions

```svelte
<script>
  // ✅ Top-level declaration
  let count = $state(0);
  
  // ✅ Class field
  class Counter {
    count = $state(0);
    doubled = $derived(this.count * 2);
  }
  
  // ❌ Inside function - COMPILE ERROR
  function setup() {
    let count = $state(0);
  }
  
  // ❌ Conditional - COMPILE ERROR
  if (condition) {
    let count = $state(0);
  }
  
  // ❌ Loop - COMPILE ERROR
  for (let i = 0; i < 10; i++) {
    let item = $state(i);
  }
  
  // ❌ Reassignment to rune - LOGIC ERROR
  function reset() {
    count = $state(0); // Creates NEW signal, breaks reactivity!
  }
</script>
```

## Runes in `.svelte.ts` Files

Runes work in `.svelte.ts` and `.svelte.js` files for shared reactive logic:

```typescript
// counter.svelte.ts
let count = $state(0);

export function getCount() {
  return count;
}

export function increment() {
  count++;
}

// Works across components!
```

---

**Next:** [2. $state In Depth](./02-StateInDepth.md)
