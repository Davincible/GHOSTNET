# 18. Performance Patterns

## Bundle Size Optimization (CRITICAL)

### Avoid Barrel File Imports

Import directly from source files to avoid loading unused modules.

```typescript
// WRONG - imports entire library
import { Check, X, Menu } from 'lucide-svelte';
// Loads all 1,500+ icons

import { Button, TextField } from 'my-ui-library';
// May load entire component library
```

```typescript
// CORRECT - direct imports
import Check from 'lucide-svelte/icons/check';
import X from 'lucide-svelte/icons/x';
import Menu from 'lucide-svelte/icons/menu';
// Loads only 3 icons

import Button from 'my-ui-library/Button.svelte';
import TextField from 'my-ui-library/TextField.svelte';
```

**Commonly affected libraries:** `lucide-svelte`, `svelte-icons`, `date-fns`, `lodash`, `rxjs`

### Defer Third-Party Scripts

Load analytics, chat widgets, and logging after hydration.

```svelte
<script>
  import { onMount } from 'svelte';
  import { browser } from '$app/environment';
  
  onMount(async () => {
    // Load after hydration, non-blocking
    const { initAnalytics } = await import('heavy-analytics');
    
    // Further defer if not critical
    requestIdleCallback(() => {
      initAnalytics();
    });
  });
</script>
```

### Conditional Module Loading

Load feature modules only when activated.

```svelte
<script>
  let { enableMarkdown, content } = $props();
  let parsedContent = $state('');
  
  $effect(() => {
    if (enableMarkdown) {
      import('marked').then(({ marked }) => {
        parsedContent = marked(content);
      });
    }
  });
</script>

{#if enableMarkdown}
  {@html parsedContent}
{:else}
  {content}
{/if}
```

---

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

---

## Client-Side Data Fetching

### TanStack Query for Complex Fetching

For client-side data fetching with caching, deduplication, and revalidation:

```bash
npm install @tanstack/svelte-query
```

```svelte
<script>
  import { createQuery } from '@tanstack/svelte-query';
  
  const query = createQuery({
    queryKey: ['users'],
    queryFn: () => fetch('/api/users').then(r => r.json()),
    staleTime: 5 * 60 * 1000 // 5 minutes
  });
</script>

{#if $query.isPending}
  <p>Loading...</p>
{:else if $query.error}
  <p>Error: {$query.error.message}</p>
{:else}
  <UserList users={$query.data} />
{/if}
```

### Shared Event Listener Stores

Deduplicate global event listeners across components.

```typescript
// lib/stores/window.svelte.ts
import { browser } from '$app/environment';

function createWindowSize() {
  let width = $state(browser ? window.innerWidth : 0);
  let height = $state(browser ? window.innerHeight : 0);
  
  if (browser) {
    // Single listener shared by all components
    window.addEventListener('resize', () => {
      width = window.innerWidth;
      height = window.innerHeight;
    });
  }
  
  return {
    get width() { return width; },
    get height() { return height; }
  };
}

export const windowSize = createWindowSize();
```

```svelte
<script>
  import { windowSize } from '$lib/stores/window.svelte';
</script>

<p>Width: {windowSize.width}</p>
```

### Cache localStorage Reads

Don't read localStorage repeatedly in reactive code.

```svelte
<script>
  import { browser } from '$app/environment';
  
  // WRONG - would read on every access if in $derived
  // let theme = $derived(localStorage.getItem('theme') || 'light');
  
  // CORRECT - read once, sync on change
  let theme = $state(browser ? localStorage.getItem('theme') || 'light' : 'light');
  
  function setTheme(newTheme: string) {
    theme = newTheme;
    localStorage.setItem('theme', newTheme);
  }
</script>
```

---

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

---

## Rendering Performance

### CSS content-visibility for Long Lists

Defer rendering of off-screen content with CSS:

```css
.list-item {
  content-visibility: auto;
  contain-intrinsic-size: 0 80px; /* Estimated height */
}
```

```svelte
<div class="list">
  {#each items as item (item.id)}
    <div class="list-item">
      <ItemContent {item} />
    </div>
  {/each}
</div>
```

### CSS Visibility vs {#if} for Frequent Toggles

For frequently toggled UI, CSS visibility is faster than DOM removal.

```svelte
<!-- Frequent toggles: use CSS -->
<div class="tooltip" class:visible={showTooltip}>
  {tooltipContent}
</div>

<style>
  .tooltip {
    visibility: hidden;
    opacity: 0;
    transition: opacity 0.2s;
  }
  .tooltip.visible {
    visibility: visible;
    opacity: 1;
  }
</style>
```

```svelte
<!-- Infrequent toggles or heavy content: use {#if} -->
{#if showModal}
  <Modal onclose={() => showModal = false} />
{/if}
```

### SVG Optimization

**Reduce coordinate precision:**

```svelte
<!-- WRONG - excessive precision -->
<svg viewBox="0 0 100 100">
  <path d="M10.123456789 20.987654321 L30.111111111 40.222222222" />
</svg>

<!-- CORRECT - 2 decimal places is sufficient -->
<svg viewBox="0 0 100 100">
  <path d="M10.12 20.99 L30.11 40.22" />
</svg>
```

**Animate wrapper elements, not SVGs:**

```svelte
<!-- WRONG - SVG animations are expensive -->
<svg class="spinning" style="animation: spin 1s linear infinite">
  <path d="..." />
</svg>

<!-- CORRECT - wrap in div for transforms -->
<div class="spinning" style="animation: spin 1s linear infinite">
  <svg>
    <path d="..." />
  </svg>
</div>
```

---

## Reactivity Optimization

### Batch State Updates

Group related state updates to minimize reactive cycles.

```svelte
<script>
  // WRONG - multiple reactive updates
  let firstName = $state('');
  let lastName = $state('');
  let email = $state('');
  
  async function loadUser() {
    const user = await fetchUser();
    firstName = user.firstName;  // Triggers reactivity
    lastName = user.lastName;    // Triggers reactivity again
    email = user.email;          // Triggers reactivity again
  }
</script>
```

```svelte
<script>
  // CORRECT - single object update
  let user = $state({ firstName: '', lastName: '', email: '' });
  
  async function loadUser() {
    user = await fetchUser();  // Single reactive update
  }
</script>
```

### Derive Booleans to Reduce Update Frequency

```svelte
<script>
  import { windowSize } from '$lib/stores/window.svelte';
  
  // WRONG - updates on every pixel
  let navClass = $derived(windowSize.width < 768 ? 'mobile' : 'desktop');
</script>
```

```svelte
<script>
  import { windowSize } from '$lib/stores/window.svelte';
  
  // CORRECT - only changes when crossing threshold
  let isMobile = $derived(windowSize.width < 768);
  let navClass = $derived(isMobile ? 'mobile' : 'desktop');
</script>
```

**Even better - use CSS media query:**

```svelte
<script>
  import { browser } from '$app/environment';
  
  let isMobile = $state(false);
  
  if (browser) {
    const mq = window.matchMedia('(max-width: 767px)');
    isMobile = mq.matches;
    mq.addEventListener('change', e => isMobile = e.matches);
  }
</script>
```

---

## JavaScript Micro-Optimizations

These matter in hot paths and large datasets.

### Use Set/Map for O(1) Lookups

```typescript
// WRONG - O(n) per check
const allowedIds = ['a', 'b', 'c'];
items.filter(item => allowedIds.includes(item.id));

// CORRECT - O(1) per check
const allowedIds = new Set(['a', 'b', 'c']);
items.filter(item => allowedIds.has(item.id));
```

### Build Index Maps for Repeated Lookups

```typescript
// WRONG - O(n) each lookup
users.forEach(user => {
  const dept = departments.find(d => d.id === user.deptId);
});

// CORRECT - O(1) each lookup
const deptMap = new Map(departments.map(d => [d.id, d]));
users.forEach(user => {
  const dept = deptMap.get(user.deptId);
});
```

### Combine Multiple Array Iterations

```typescript
// WRONG - 3 iterations
const admins = users.filter(u => u.isAdmin);
const testers = users.filter(u => u.isTester);
const inactive = users.filter(u => !u.isActive);

// CORRECT - 1 iteration
const admins = [], testers = [], inactive = [];
for (const user of users) {
  if (user.isAdmin) admins.push(user);
  if (user.isTester) testers.push(user);
  if (!user.isActive) inactive.push(user);
}
```

### Use Passive Event Listeners for Scroll/Touch

```typescript
// WRONG - blocks scrolling
element.addEventListener('scroll', handler);

// CORRECT - allows browser optimization
element.addEventListener('scroll', handler, { passive: true });
```

---

**Next:** [19. Component Composition](./19-ComponentComposition.md)
