# Svelte 5: $effect with Singleton Stores Causes Infinite Loops

**Date:** January 2026  
**Issue:** `effect_update_depth_exceeded` error with wallet store

## Problem

Using `$effect` to initialize a singleton store with reactive state causes infinite loops:

```svelte
<script>
  import { wallet } from '$lib/web3';

  // ❌ INFINITE LOOP
  $effect(() => {
    const cleanup = wallet.init();  // Reads state, then writes state
    return cleanup;
  });
</script>
```

Error:
```
Uncaught (in promise) Svelte error: effect_update_depth_exceeded
Maximum update depth exceeded. This typically indicates that an effect 
reads and writes the same piece of state
```

## Root Cause

1. `$effect` tracks all reactive state read during execution
2. `wallet.init()` reads from reactive state (like `initialized`)
3. `wallet.init()` writes to reactive state (like `status`, `address`)
4. State change triggers effect to re-run
5. Infinite loop

The `initialized` flag being `$state` was part of the problem:
```typescript
// ❌ BAD - This gets tracked in effects
let initialized = $state(false);
```

## Solution

### 1. Use `onMount` instead of `$effect` for one-time setup

```svelte
<script>
  import { onMount } from 'svelte';
  import { wallet } from '$lib/web3';

  // ✅ CORRECT - onMount doesn't track reactive dependencies
  onMount(() => {
    return wallet.init();
  });
</script>
```

### 2. Don't use `$state` for internal flags

```typescript
// ✅ CORRECT - Plain variable, not reactive
let initialized = false;  // Not $state!
```

## When to Use What

| Pattern | Use Case |
|---------|----------|
| `onMount` | One-time setup, subscriptions, library init |
| `$effect` | Reactive side effects that should re-run when deps change |
| `$effect` + `untrack()` | When you need to read state without tracking |

## Key Insight

Singleton stores with `$state` are "reactive at a distance" - accessing any property in an effect creates a dependency. For initialization:

- Use `onMount` for setup/teardown
- Use plain variables for internal bookkeeping
- Reserve `$state` for values that should trigger UI updates

## References

- [Svelte 5 Docs: $effect](https://svelte.dev/docs/svelte/$effect)
- [Svelte 5 Docs: untrack](https://svelte.dev/docs/svelte/svelte#untrack)
- [04-EffectWhenAndHow.md](../../apps/web/docs/guides/SvelteBestPractices/04-EffectWhenAndHow.md)
