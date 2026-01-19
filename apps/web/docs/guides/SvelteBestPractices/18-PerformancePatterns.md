# 18. Performance Patterns

## Fine-Grained Reactivity

Svelte 5 updates only what changed:

```svelte
<script>
  let items = $state([
    { id: 1, name: 'A', count: 0 },
    { id: 2, name: 'B', count: 0 },
    { id: 3, name: 'C', count: 0 }
  ]);
  
  // Only updates the specific item's DOM node
  function incrementItem(id: number) {
    const item = items.find(i => i.id === id);
    if (item) item.count++;
  }
</script>

{#each items as item (item.id)}
  <!-- Only this div re-renders when item.count changes -->
  <div>
    {item.name}: {item.count}
    <button onclick={() => incrementItem(item.id)}>+</button>
  </div>
{/each}
```

## Use $state.raw for Large Data

```svelte
<script>
  // Large dataset from API
  let chartData = $state.raw<DataPoint[]>([]);
  
  async function loadData() {
    // Replace entirely, don't mutate
    chartData = await fetchChartData();
  }
</script>
```

## Keyed Each Blocks

```svelte
<!-- ✅ With key - efficient updates -->
{#each items as item (item.id)}
  <Item data={item} />
{/each}

<!-- ❌ Without key - recreates all on change -->
{#each items as item}
  <Item data={item} />
{/each}
```

## Lazy Loading

```svelte
<script>
  let showHeavy = $state(false);
</script>

<button onclick={() => showHeavy = true}>
  Load Heavy Component
</button>

{#if showHeavy}
  {#await import('./HeavyComponent.svelte') then { default: Heavy }}
    <Heavy />
  {/await}
{/if}
```

## Debounced Reactivity

```svelte
<script>
  let searchQuery = $state('');
  let debouncedQuery = $state('');
  
  $effect(() => {
    const timeout = setTimeout(() => {
      debouncedQuery = searchQuery;
    }, 300);
    
    return () => clearTimeout(timeout);
  });
  
  // Use debouncedQuery for expensive operations
  const results = $derived.by(async () => {
    if (!debouncedQuery) return [];
    return await search(debouncedQuery);
  });
</script>

<input bind:value={searchQuery} />
```

## Minimize Effect Scope

```svelte
<script>
  let a = $state(0);
  let b = $state(0);
  let c = $state(0);
  
  // ❌ Runs when ANY dependency changes
  $effect(() => {
    expensiveOperation(a);
    console.log(b, c);
  });
  
  // ✅ Separate concerns
  $effect(() => {
    expensiveOperation(a); // Only runs when 'a' changes
  });
  
  $effect(() => {
    console.log(b, c); // Only runs when 'b' or 'c' change
  });
</script>
```

## Preloading

```svelte
<script>
  import { preloadData, preloadCode } from '$app/navigation';
</script>

<!-- Preload on hover -->
<a 
  href="/dashboard"
  onmouseenter={() => preloadData('/dashboard')}
>
  Dashboard
</a>

<!-- Built-in preload -->
<a href="/about" data-sveltekit-preload-data="hover">
  About
</a>

<!-- Preload code only (faster) -->
<a href="/settings" data-sveltekit-preload-code="eager">
  Settings
</a>
```

## Avoid Expensive Template Computations

```svelte
<!-- ❌ WRONG - Recalculates on every render -->
<p>Total: {items.reduce((a, b) => a + b, 0)}</p>
<p>Average: {items.reduce((a, b) => a + b, 0) / items.length}</p>

<!-- ✅ CORRECT - Cache with $derived -->
<script>
  const total = $derived(items.reduce((a, b) => a + b, 0));
</script>
<p>Total: {total}</p>
<p>Average: {total / items.length}</p>
```

---

**Next:** [19. Component Composition](./19-ComponentComposition.md)
