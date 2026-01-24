# 23. Antipatterns Reference

## Using $effect for Derived State

```svelte
<script>
	let count = $state(0);

	// ❌ WRONG
	let doubled = $state(0);
	$effect(() => {
		doubled = count * 2;
	});

	// ✅ CORRECT
	const doubled = $derived(count * 2);
</script>
```

## Creating Runes Inside Functions

```svelte
<script>
	// ❌ WRONG - Compile error
	function createCounter() {
		return $state(0);
	}

	// ✅ CORRECT - Return object with reactive properties
	function createCounter() {
		let count = $state(0);
		return {
			get count() {
				return count;
			},
			increment() {
				count++;
			},
		};
	}
</script>
```

## Conditional Runes

```svelte
<script>
	// ❌ WRONG - Compile error
	if (condition) {
		let count = $state(0);
	}

	// ✅ CORRECT
	let count = $state(condition ? initialValue : 0);
</script>
```

## Reassigning to $state()

```svelte
<script>
	let count = $state(0);

	// ❌ WRONG - Creates new signal, breaks reactivity
	function reset() {
		count = $state(0);
	}

	// ✅ CORRECT
	function reset() {
		count = 0;
	}
</script>
```

## Mutating Props

```svelte
<script>
	let { items } = $props();

	// ❌ WRONG - Parent won't see changes
	function addItem(item) {
		items.push(item);
	}

	// ✅ CORRECT - Use callbacks
	let { items, onAdd } = $props();
	function addItem(item) {
		onAdd?.(item);
	}
</script>
```

## Infinite Effect Loops

```svelte
<script>
	let count = $state(0);

	// ❌ WRONG - Infinite loop
	$effect(() => {
		count = count + 1;
	});

	// ❌ WRONG - Array mutation triggers itself
	let items = $state([]);
	$effect(() => {
		items.push(Date.now());
	});

	// ✅ CORRECT - Use untrack
	import { untrack } from 'svelte';
	$effect(() => {
		const current = untrack(() => count);
		// Use current without creating dependency
	});
</script>
```

## Mixing Svelte 4 and 5 Syntax

```svelte
<script>
	// ❌ WRONG - Mixed syntax
	let count = $state(0);
	$: doubled = count * 2; // Svelte 4 syntax!

	// ✅ CORRECT - Consistent Svelte 5
	let count = $state(0);
	const doubled = $derived(count * 2);
</script>
```

## Global State Without SSR Awareness

```typescript
// ❌ WRONG - Shared across all server requests
export const userStore = $state({ user: null });

// ✅ CORRECT - Use context for per-request state
import { setContext, getContext } from 'svelte';

export function createUserContext() {
	let user = $state(null);
	setContext('user', {
		get user() {
			return user;
		},
	});
}
```

## Effects for Data Fetching

```svelte
<script>
  let userId = $state('123');

  // ❌ WRONG - Use load functions instead
  let user = $state(null);
  $effect(() => {
    fetch(`/api/users/${userId}`)
      .then(r => r.json())
      .then(data => user = data);
  });
</script>

<!-- ✅ CORRECT - Use SvelteKit load -->
<!-- +page.server.ts -->
export async function load({ params }) {
  return { user: await getUser(params.id) };
}
```

## Using on:event Instead of onevent

```svelte
<!-- ❌ WRONG - Svelte 4 syntax (deprecated) -->
<button on:click={handleClick}>Click</button>
<input on:input={handleInput} />

<!-- ✅ CORRECT - Svelte 5 syntax -->
<button onclick={handleClick}>Click</button>
<input oninput={handleInput} />
```

## Forgetting Cleanup in Effects

```svelte
<script>
	// ❌ WRONG - Memory leak
	$effect(() => {
		window.addEventListener('resize', handleResize);
	});

	// ✅ CORRECT - Return cleanup
	$effect(() => {
		window.addEventListener('resize', handleResize);
		return () => window.removeEventListener('resize', handleResize);
	});
</script>
```

## Heavy Computations in Templates

```svelte
<!-- ✅ CORRECT - Cache with $derived -->
<script>
	const total = $derived(items.reduce((a, b) => a + b, 0));
</script>

<!-- ❌ WRONG - Recalculates on every render -->
<p>Total: {items.reduce((a, b) => a + b, 0)}</p>
<p>Average: {items.reduce((a, b) => a + b, 0) / items.length}</p>
<p>Total: {total}</p>
<p>Average: {total / items.length}</p>
```

## Converting $derived to Getter Functions (CATASTROPHIC)

When refactoring, **never** replace `$derived` with getter functions called in templates.
`$derived` caches computed values; getter functions recalculate on every render.

```svelte
<script>
  let { value } = $props();

  // ❌ CATASTROPHIC - Looks like a reasonable refactor, but...
  const type = () => getType(value);
  const formatted = () => expensiveFormat(value);
  const matches = () => value.match(/complex-regex/g);
</script>

<!-- Each {@const} call runs the getter on EVERY render -->
{@const nodeType = type()}
{@const display = formatted()}
{@const found = matches()}

<script>
  // ✅ CORRECT - $derived caches the result
  const type = $derived(getType(value));
  const formatted = $derived(expensiveFormat(value));
  const matches = $derived(value.match(/complex-regex/g));
</script>

<!-- Uses cached values - no recalculation -->
<span class={type}>{formatted}</span>
```

**Why this is catastrophic in recursive components:**

For a JSON tree viewer with 10,000 nodes, where each node has 5 computed properties:

| Pattern             | Computations per render    |
| ------------------- | -------------------------- |
| `$derived` (cached) | 50,000 once, then 0        |
| Getter functions    | 50,000 × every render pass |

Real-world impact:

- **Before (with `$derived`):** 36ms render time
- **After (getter functions):** 6,697ms render time
- **Regression:** 197× slower

## Forgetting Keys in Each Blocks

```svelte
<!-- ❌ WRONG - Inefficient, bugs with state -->
{#each items as item}
	<Item data={item} />
{/each}

<!-- ✅ CORRECT - Efficient updates -->
{#each items as item (item.id)}
	<Item data={item} />
{/each}
```

---

**Next:** [24. Tips & Tricks](./24-TipsAndTricks.md)
