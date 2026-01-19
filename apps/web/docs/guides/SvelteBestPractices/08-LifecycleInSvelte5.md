# 8. Lifecycle in Svelte 5

## The New Model

Svelte 5 simplifies lifecycle with `$effect`:

| Svelte 4 | Svelte 5 |
|----------|----------|
| `onMount(() => {})` | `$effect(() => {})` |
| `onDestroy(() => {})` | `$effect(() => { return cleanup; })` |
| `beforeUpdate(() => {})` | `$effect.pre(() => {})` |
| `afterUpdate(() => {})` | `$effect(() => {})` |
| `tick()` | `tick()` (unchanged) |

## Mount Equivalent

```svelte
<script>
  import { untrack } from 'svelte';
  
  // Runs once when component mounts
  $effect(() => {
    // Use untrack if you don't want reactive dependencies
    untrack(() => {
      console.log('Mounted!');
      initThirdPartyLib();
    });
  });
  
  // Or check for mount explicitly
  let mounted = false;
  $effect(() => {
    if (!mounted) {
      mounted = true;
      console.log('First run only');
    }
  });
</script>
```

## Cleanup on Unmount

```svelte
<script>
  let websocket: WebSocket;
  
  $effect(() => {
    websocket = new WebSocket('ws://example.com');
    
    websocket.onmessage = (e) => {
      console.log('Message:', e.data);
    };
    
    // Cleanup runs on unmount
    return () => {
      websocket.close();
    };
  });
</script>
```

## Before/After Update

```svelte
<script>
  let messages = $state<string[]>([]);
  let container: HTMLDivElement;
  let previousHeight = 0;
  
  // BEFORE DOM updates (like beforeUpdate)
  $effect.pre(() => {
    if (container) {
      previousHeight = container.scrollHeight;
    }
  });
  
  // AFTER DOM updates (like afterUpdate)
  $effect(() => {
    if (container && container.scrollHeight !== previousHeight) {
      // DOM has changed
      container.scrollTop = container.scrollHeight;
    }
  });
</script>
```

## Using tick()

```svelte
<script>
  import { tick } from 'svelte';
  
  let value = $state('');
  let input: HTMLInputElement;
  
  async function handlePaste() {
    value = 'Pasted content';
    
    // Wait for DOM to update
    await tick();
    
    // Now DOM reflects new value
    input.select();
  }
</script>

<input bind:this={input} bind:value />
```

## Lifecycle in `.svelte.ts` Files

```typescript
// timer.svelte.ts
import { untrack } from 'svelte';

let time = $state(new Date());
let intervalId: number | null = null;

// Manual effect management outside components
const cleanup = $effect.root(() => {
  $effect(() => {
    intervalId = setInterval(() => {
      time = new Date();
    }, 1000);
    
    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  });
});

export function getTime() {
  return time;
}

export function stopTimer() {
  cleanup();
}
```

---

**Next:** [9. State Management Patterns](./09-StateManagementPatterns.md)
