# 11. Reactive Collections

## SvelteSet

```svelte
<script>
	import { SvelteSet } from 'svelte/reactivity';

	let selectedIds = new SvelteSet<string>();

	function toggle(id: string) {
		if (selectedIds.has(id)) {
			selectedIds.delete(id);
		} else {
			selectedIds.add(id);
		}
	}

	function selectAll(ids: string[]) {
		ids.forEach((id) => selectedIds.add(id));
	}

	function clear() {
		selectedIds.clear();
	}

	// Reactive checks
	const count = $derived(selectedIds.size);
	const hasSelection = $derived(selectedIds.size > 0);
</script>

{#each items as item}
	<label>
		<input type="checkbox" checked={selectedIds.has(item.id)} onchange={() => toggle(item.id)} />
		{item.name}
	</label>
{/each}

<p>Selected: {count}</p>
```

## SvelteMap

```svelte
<script>
	import { SvelteMap } from 'svelte/reactivity';

	interface CacheEntry {
		data: unknown;
		timestamp: number;
	}

	let cache = new SvelteMap<string, CacheEntry>();

	function set(key: string, data: unknown) {
		cache.set(key, {
			data,
			timestamp: Date.now(),
		});
	}

	function get(key: string) {
		const entry = cache.get(key);
		if (!entry) return null;

		// Check expiration (5 minutes)
		if (Date.now() - entry.timestamp > 5 * 60 * 1000) {
			cache.delete(key);
			return null;
		}

		return entry.data;
	}

	function invalidate(key: string) {
		cache.delete(key);
	}

	function clearAll() {
		cache.clear();
	}

	// Iterate reactively
	const entries = $derived([...cache.entries()]);
</script>

{#each entries as [key, value]}
	<div>
		{key}: {JSON.stringify(value.data)}
		<button onclick={() => invalidate(key)}>Remove</button>
	</div>
{/each}
```

## SvelteURL and SvelteURLSearchParams

```svelte
<script>
	import { SvelteURL, SvelteURLSearchParams } from 'svelte/reactivity';

	// Reactive URL manipulation
	let url = new SvelteURL('https://example.com/search');

	// Reactive query params
	let params = new SvelteURLSearchParams(url.search);

	function setQuery(q: string) {
		params.set('q', q);
		url.search = params.toString();
	}

	function addFilter(key: string, value: string) {
		params.append('filter', `${key}:${value}`);
		url.search = params.toString();
	}
</script>

<input type="text" value={params.get('q') ?? ''} oninput={(e) => setQuery(e.currentTarget.value)} />

<p>URL: {url.toString()}</p>
```

## Reactive Date

```svelte
<script>
	import { SvelteDate } from 'svelte/reactivity';

	let date = new SvelteDate();

	// Reactive updates
	function nextDay() {
		date.setDate(date.getDate() + 1);
	}

	function setToNow() {
		date.setTime(Date.now());
	}

	// Derived formatting
	const formatted = $derived(
		date.toLocaleDateString('en-US', {
			weekday: 'long',
			year: 'numeric',
			month: 'long',
			day: 'numeric',
		})
	);
</script>

<p>{formatted}</p>
<button onclick={nextDay}>Next Day</button>
```

---

**Next:** [12. TypeScript Integration](./12-TypeScriptIntegration.md)
