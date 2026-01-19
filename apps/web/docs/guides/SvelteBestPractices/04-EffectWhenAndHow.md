# 4. $effect: When & How

## The Golden Rule

> **$effect is an escape hatch.** If you can use `$derived`, do that instead.

Use `$effect` only for:
- DOM manipulation
- Third-party library integration
- Analytics/logging
- Browser APIs (localStorage, document.title)
- Subscriptions to external stores
- WebSocket/EventSource connections

## Basic Effect

```svelte
<script>
  let count = $state(0);
  
  // Runs after every change to count
  $effect(() => {
    console.log(`Count is now: ${count}`);
  });
  
  // Runs once on mount (no reactive dependencies)
  $effect(() => {
    console.log('Component mounted');
  });
</script>
```

## Effect with Cleanup

```svelte
<script>
  let interval = $state(1000);
  
  $effect(() => {
    const id = setInterval(() => {
      console.log('tick');
    }, interval);
    
    // Cleanup runs:
    // 1. Before effect re-runs (when interval changes)
    // 2. When component unmounts
    return () => {
      clearInterval(id);
    };
  });
</script>
```

## DOM Manipulation

```svelte
<script>
  let size = $state(100);
  let canvas: HTMLCanvasElement;
  
  $effect(() => {
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d')!;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = 'blue';
    ctx.fillRect(0, 0, size, size);
  });
</script>

<canvas bind:this={canvas} width="400" height="400"></canvas>
```

## Third-Party Library Integration

```svelte
<script>
  import { Chart } from 'chart.js';
  
  let data = $state([10, 20, 30, 40]);
  let chartElement: HTMLCanvasElement;
  let chart: Chart | null = null;
  
  $effect(() => {
    if (!chartElement) return;
    
    // Create or update chart
    if (chart) {
      chart.data.datasets[0].data = data;
      chart.update();
    } else {
      chart = new Chart(chartElement, {
        type: 'bar',
        data: {
          labels: data.map((_, i) => `Item ${i + 1}`),
          datasets: [{ data }]
        }
      });
    }
    
    // Cleanup on unmount
    return () => {
      chart?.destroy();
      chart = null;
    };
  });
</script>

<canvas bind:this={chartElement}></canvas>
```

## Browser APIs

```svelte
<script>
  let title = $state('My App');
  let theme = $state<'light' | 'dark'>('light');
  
  // Document title
  $effect(() => {
    document.title = title;
  });
  
  // localStorage sync
  $effect(() => {
    localStorage.setItem('theme', theme);
  });
  
  // Media query
  let isMobile = $state(false);
  $effect(() => {
    const query = window.matchMedia('(max-width: 768px)');
    isMobile = query.matches;
    
    const handler = (e: MediaQueryListEvent) => {
      isMobile = e.matches;
    };
    
    query.addEventListener('change', handler);
    return () => query.removeEventListener('change', handler);
  });
</script>
```

## $effect.pre() - Before DOM Updates

Runs before DOM updates. Useful for measurements:

```svelte
<script>
  let messages = $state<string[]>([]);
  let container: HTMLDivElement;
  let shouldAutoScroll = true;
  
  // Check scroll position BEFORE new messages render
  $effect.pre(() => {
    if (!container) return;
    
    const { scrollTop, scrollHeight, clientHeight } = container;
    // If user is near bottom, auto-scroll after update
    shouldAutoScroll = scrollTop + clientHeight >= scrollHeight - 50;
  });
  
  // Scroll AFTER DOM updates
  $effect(() => {
    if (shouldAutoScroll && container) {
      container.scrollTop = container.scrollHeight;
    }
  });
</script>

<div bind:this={container} class="messages">
  {#each messages as message}
    <p>{message}</p>
  {/each}
</div>
```

## $effect.root() - Manual Lifecycle

For effects outside component context (modules, stores):

```typescript
// timer.svelte.ts
let seconds = $state(0);

export function startTimer() {
  // Returns cleanup function
  const cleanup = $effect.root(() => {
    $effect(() => {
      const id = setInterval(() => {
        seconds++;
      }, 1000);
      
      return () => clearInterval(id);
    });
  });
  
  return cleanup; // Call to stop timer and cleanup
}

export function getSeconds() {
  return seconds;
}
```

## $effect.tracking() - Check Reactive Context

```svelte
<script>
  $effect(() => {
    console.log($effect.tracking()); // true - inside effect
  });
  
  function regularFunction() {
    console.log($effect.tracking()); // false - not in reactive context
  }
</script>
```

## Debugging with $inspect

```svelte
<script>
  let user = $state({ name: 'Alice', count: 0 });
  
  // Logs when user or any nested property changes
  $inspect(user);
  
  // With custom callback
  $inspect(user).with((type, value) => {
    if (type === 'update') {
      console.log('User updated:', value);
    }
  });
  
  // Trace what triggered an effect
  $effect(() => {
    $inspect.trace('userEffect');
    // When this effect runs, console shows which dependency changed
    doSomethingWith(user);
  });
</script>
```

## Effect Dependency Tracking

Effects automatically track dependencies read during execution:

```svelte
<script>
  let a = $state(0);
  let b = $state(0);
  let condition = $state(true);
  
  $effect(() => {
    // Dependencies: condition, and either a OR b (not both!)
    if (condition) {
      console.log('a:', a);  // Only tracks 'a' when condition is true
    } else {
      console.log('b:', b);  // Only tracks 'b' when condition is false
    }
  });
  
  // If condition is true:
  // - Changing 'a' triggers effect
  // - Changing 'b' does NOT trigger effect
  // - Changing 'condition' triggers effect AND changes future tracking
</script>
```

## Avoiding Infinite Loops

```svelte
<script>
  let count = $state(0);
  
  // ❌ INFINITE LOOP - reads and writes same state
  $effect(() => {
    count = count + 1;
  });
  
  // ❌ INFINITE LOOP - array push triggers itself
  let items = $state([]);
  $effect(() => {
    items.push(Date.now()); // Reads items, then mutates it
  });
  
  // ✅ Use untrack() to read without tracking
  import { untrack } from 'svelte';
  
  $effect(() => {
    const currentCount = untrack(() => count);
    // Can now use currentCount without creating dependency
    console.log('Count was:', currentCount);
  });
</script>
```

---

**Next:** [5. $props & Component API](./05-PropsAndComponentAPI.md)
