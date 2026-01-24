# 3. $derived Mastery

## Simple Derived Values

```svelte
<script>
	let count = $state(0);
	let firstName = $state('John');
	let lastName = $state('Doe');

	// Simple expressions
	const doubled = $derived(count * 2);
	const fullName = $derived(`${firstName} ${lastName}`);
	const isEven = $derived(count % 2 === 0);

	// Derived from derived
	const quadrupled = $derived(doubled * 2);

	// Derived from arrays
	let items = $state([1, 2, 3, 4, 5]);
	const sum = $derived(items.reduce((a, b) => a + b, 0));
	const evenItems = $derived(items.filter((i) => i % 2 === 0));
</script>
```

## $derived.by() for Complex Logic

When you need more than a single expression:

```svelte
<script>
	let items = $state([
		{ name: 'Apple', price: 1.5, quantity: 3 },
		{ name: 'Banana', price: 0.75, quantity: 5 },
	]);
	let taxRate = $state(0.1);
	let discount = $state(0);

	const orderSummary = $derived.by(() => {
		const subtotal = items.reduce((sum, item) => sum + item.price * item.quantity, 0);
		const tax = subtotal * taxRate;
		const total = subtotal + tax - discount;

		return {
			subtotal,
			tax,
			discount,
			total,
			itemCount: items.reduce((sum, item) => sum + item.quantity, 0),
		};
	});
</script>

<p>Total: ${orderSummary.total.toFixed(2)}</p>
```

## Derived with Conditions

```svelte
<script>
	let user = $state<User | null>(null);
	let permissions = $state<string[]>([]);

	const accessLevel = $derived.by(() => {
		if (!user) return 'guest';
		if (permissions.includes('admin')) return 'admin';
		if (permissions.includes('editor')) return 'editor';
		return 'user';
	});

	const canEdit = $derived(accessLevel === 'admin' || accessLevel === 'editor');
</script>
```

## Derived Arrays and Objects

```svelte
<script>
	let users = $state([
		{ id: 1, name: 'Alice', role: 'admin', active: true },
		{ id: 2, name: 'Bob', role: 'user', active: false },
		{ id: 3, name: 'Charlie', role: 'user', active: true },
	]);

	let searchQuery = $state('');
	let roleFilter = $state<string | null>(null);
	let showInactive = $state(false);

	// Chained filtering
	const filteredUsers = $derived.by(() => {
		let result = users;

		if (!showInactive) {
			result = result.filter((u) => u.active);
		}

		if (roleFilter) {
			result = result.filter((u) => u.role === roleFilter);
		}

		if (searchQuery) {
			const query = searchQuery.toLowerCase();
			result = result.filter((u) => u.name.toLowerCase().includes(query));
		}

		return result;
	});

	// Derived object maps
	const usersById = $derived(Object.fromEntries(users.map((u) => [u.id, u])));

	// Grouped data
	const usersByRole = $derived.by(() => {
		const groups: Record<string, User[]> = {};
		for (const user of users) {
			(groups[user.role] ??= []).push(user);
		}
		return groups;
	});
</script>
```

## Overridable Derived (Svelte 5.25+)

For optimistic UI patterns:

```svelte
<script>
	let serverCount = $state(0);
	let optimisticCount = $derived(serverCount);

	async function increment() {
		// Optimistically update UI immediately
		optimisticCount = serverCount + 1;

		try {
			// Sync with server
			serverCount = await api.increment();
			// optimisticCount now derives from new serverCount
		} catch (error) {
			// On failure, derived recalculates from unchanged serverCount
			// UI automatically reverts
		}
	}
</script>

<p>Count: {optimisticCount}</p>
```

## Derived vs Inline Expressions

```svelte
<script>
	let items = $state([1, 2, 3, 4, 5]);

	// ✅ Cached - computed once per change
	const total = $derived(items.reduce((a, b) => a + b, 0));

	// Use in template multiple times - still one computation
</script>

<!-- All reference same cached value -->
<p>Total: {total}</p>
<p>Average: {total / items.length}</p>
<p>Is large: {total > 100 ? 'Yes' : 'No'}</p>

<!-- ❌ Inline - recomputes on every render -->
<p>Total: {items.reduce((a, b) => a + b, 0)}</p>
<p>Average: {items.reduce((a, b) => a + b, 0) / items.length}</p>
```

## Async in Derived (Limitations)

**$derived cannot be async directly.** Use patterns:

```svelte
<script>
	let query = $state('');

	// ❌ Won't work
	// const results = $derived(await fetch(`/api?q=${query}`));

	// ✅ Pattern 1: Separate state + effect
	let results = $state([]);
	$effect(() => {
		fetch(`/api?q=${query}`)
			.then((r) => r.json())
			.then((data) => (results = data));
	});

	// ✅ Pattern 2: Use SvelteKit load functions instead

	// ✅ Pattern 3: Async derived with $derived.by (returns Promise)
	const resultsPromise = $derived.by(async () => {
		if (!query) return [];
		const res = await fetch(`/api?q=${query}`);
		return res.json();
	});
</script>

<!-- Use with {#await} -->
{#await resultsPromise}
	<p>Loading...</p>
{:then results}
	{#each results as result}
		<p>{result.name}</p>
	{/each}
{/await}
```

> **Warning:** While async `$derived.by` compiles, it has significant drawbacks:
>
> - Creates a new Promise on every dependency change
> - No request cancellation (race conditions with rapid changes)
> - No caching or deduplication
>
> **Prefer these alternatives:**
>
> 1. SvelteKit load functions (for page data)
> 2. Remote functions (for interactive fetching) — see [Section 15](./15-RemoteFunctions.md)
> 3. Explicit state + effect with AbortController:

### Proper Async Pattern with AbortController

```svelte
<script>
	let query = $state('');
	let results = $state([]);
	let loading = $state(false);

	$effect(() => {
		const controller = new AbortController();

		if (query) {
			loading = true;
			fetch(`/api?q=${query}`, { signal: controller.signal })
				.then((r) => r.json())
				.then((data) => {
					results = data;
					loading = false;
				})
				.catch((e) => {
					if (e.name !== 'AbortError') loading = false;
				});
		} else {
			results = [];
		}

		// Cleanup: abort previous request when query changes
		return () => controller.abort();
	});
</script>

{#if loading}
	<p>Loading...</p>
{:else}
	{#each results as result}
		<p>{result.name}</p>
	{/each}
{/if}
```

---

**Next:** [4. $effect: When & How](./04-EffectWhenAndHow.md)
