# 2. $state In Depth

## Primitive State

```svelte
<script>
	let count = $state(0);
	let name = $state('');
	let active = $state(false);
	let selectedId = $state<number | null>(null);

	// Direct mutation
	count++;
	count = 10;
	name = 'Alice';
	active = !active;
</script>
```

## Object State (Deep Reactivity)

Objects and arrays become **reactive proxies** automatically:

```svelte
<script>
	let user = $state({
		name: 'Alice',
		profile: {
			age: 30,
			settings: {
				theme: 'dark',
				notifications: true,
			},
		},
	});

	// ✅ All these trigger updates (deep reactivity)
	user.name = 'Bob';
	user.profile.age = 31;
	user.profile.settings.theme = 'light';

	// ✅ Adding new properties works
	user.profile.bio = 'Hello world';
</script>

<p>{user.profile.settings.theme}</p>
```

## Array State (Deep Reactivity)

```svelte
<script>
	let items = $state([
		{ id: 1, name: 'Item 1', done: false },
		{ id: 2, name: 'Item 2', done: true },
	]);

	// ✅ Array methods work reactively
	items.push({ id: 3, name: 'Item 3', done: false });
	items.pop();
	items.splice(1, 1);
	items[0].done = true; // Deep mutation

	// ✅ Reassignment also works
	items = items.filter((i) => !i.done);
	items = [...items, newItem];
</script>
```

## $state.raw() - Opting Out of Deep Reactivity

Use when:

- Large datasets you'll replace entirely (not mutate)
- External libraries that don't work with proxies
- Performance-critical paths
- Data from APIs that you display but don't modify

```svelte
<script>
	// Large chart data - replaced entirely, never mutated
	let chartData = $state.raw<DataPoint[]>([]);

	async function loadData() {
		const response = await fetch('/api/data');
		// ✅ Must replace entirely - mutations won't trigger updates
		chartData = await response.json();
	}

	function addPoint(point: DataPoint) {
		// ❌ Won't trigger update!
		chartData.push(point);

		// ✅ Must replace
		chartData = [...chartData, point];
	}
</script>
```

## $state.snapshot() - Extracting Plain Objects

When you need to pass reactive state to APIs that don't expect proxies:

```svelte
<script>
	let formData = $state({
		name: '',
		email: '',
		preferences: { newsletter: true },
	});

	async function submit() {
		// ❌ Some APIs choke on proxies
		// await api.submit(formData);

		// ✅ Get plain object
		const plain = $state.snapshot(formData);
		await api.submit(plain);

		// ✅ Works with structuredClone
		const cloned = structuredClone($state.snapshot(formData));

		// ✅ Works with JSON
		const json = JSON.stringify($state.snapshot(formData));
	}
</script>
```

## State Initialization Patterns

```svelte
<script>
	// Lazy initialization (function called once)
	let expensive = $state(computeExpensiveInitialValue());

	// Typed state with explicit type
	let items = $state<Item[]>([]);

	// Nullable state
	let selected = $state<User | null>(null);

	// State from props (snapshot on init)
	let { initialValue } = $props();
	let localValue = $state(initialValue); // Won't sync with prop changes!

	// State that syncs with props - use $derived instead
	let { value } = $props();
	const syncedValue = $derived(value); // Stays in sync
</script>
```

## Object Identity and Proxies

```svelte
<script>
	let obj = $state({ count: 0 });

	// The proxy wraps the original
	console.log(obj); // Proxy { count: 0 }

	// Comparisons work as expected
	let obj2 = $state({ count: 0 });
	console.log(obj === obj2); // false (different proxies)

	// Getting the same object returns same proxy
	let arr = $state([obj]);
	console.log(arr[0] === obj); // true
</script>
```

---

**Next:** [3. $derived Mastery](./03-DerivedMastery.md)
