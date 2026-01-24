# 22. Migration from Svelte 4

## Automated Migration

```bash
# Run migration script
bunx sv migrate svelte-5

# Or in VS Code:
# Cmd/Ctrl + Shift + P → "Migrate Component to Svelte 5 Syntax"
```

## Manual Migration Patterns

### Reactive Variables

```svelte
<!-- Svelte 4 -->
<script>
  let count = 0;
  let name = 'world';
</script>

<!-- Svelte 5 -->
<script>
  let count = $state(0);
  let name = $state('world');
</script>
```

### Reactive Statements

```svelte
<!-- Svelte 4 -->
<script>
  let count = 0;
  $: doubled = count * 2;
  $: if (count > 10) {
    console.log('Large count!');
  }
</script>

<!-- Svelte 5 -->
<script>
  let count = $state(0);
  const doubled = $derived(count * 2);

  $effect(() => {
    if (count > 10) {
      console.log('Large count!');
    }
  });
</script>
```

### Props

```svelte
<!-- Svelte 4 -->
<script>
  export let name;
  export let age = 18;
</script>

<!-- Svelte 5 -->
<script>
  let { name, age = 18 } = $props();
</script>
```

### Events

```svelte
<!-- Svelte 4 -->
<button on:click={handleClick}>Click</button>
<button on:click|preventDefault={handleSubmit}>Submit</button>

<!-- Svelte 5 -->
<button onclick={handleClick}>Click</button>
<button
	onclick={(e) => {
		e.preventDefault();
		handleSubmit(e);
	}}>Submit</button
>
```

### Event Dispatching

```svelte
<!-- Svelte 4 -->
<script>
  import { createEventDispatcher } from 'svelte';
  const dispatch = createEventDispatcher();

  function handleClick() {
    dispatch('select', { id: 123 });
  }
</script>

<!-- Svelte 5 -->
<script>
  let { onSelect } = $props();

  function handleClick() {
    onSelect?.({ id: 123 });
  }
</script>
```

### Slots to Snippets

```svelte
<!-- Svelte 5 -->
<script>
	let { children, header, item } = $props();
</script>

<!-- Svelte 4 -->
<div>
	<slot />
	<slot name="header" />
	<slot name="item" {item} {index} />
</div>

<div>
	{@render children?.()}
	{@render header?.()}
	{@render item?.(item, index)}
</div>
```

### Two-Way Binding

```svelte
<!-- Svelte 4 -->
<script>
  export let value;
</script>

<!-- Svelte 5 -->
<script>
  let { value = $bindable() } = $props();
</script>
```

### Lifecycle

```svelte
<!-- Svelte 4 -->
<script>
  import { onMount, onDestroy, beforeUpdate, afterUpdate } from 'svelte';

  onMount(() => {
    console.log('mounted');
    return () => console.log('cleanup');
  });
</script>

<!-- Svelte 5 -->
<script>
  $effect(() => {
    console.log('mounted');
    return () => console.log('cleanup');
  });
</script>
```

### Component Instantiation

```svelte
<!-- Svelte 4 -->
<script>
  const component = new MyComponent({ target, props });
</script>

<!-- Svelte 5 -->
<script>
  import { mount, unmount } from 'svelte';
  const component = mount(MyComponent, { target, props });
  // Later: unmount(component);
</script>
```

## Migration Gotchas

### Don't Convert $: to $effect for Derived Values

```svelte
<script>
	// ❌ Don't convert $: directly to $effect
	// Svelte 4
	$: doubled = count * 2;

	// ❌ Wrong
	$effect(() => {
		doubled = count * 2;
	});

	// ✅ Correct
	const doubled = $derived(count * 2);
</script>
```

### Store Subscriptions

```svelte
<!-- Svelte 4: Auto-subscription with $ -->
<script>
  import { writable } from 'svelte/store';
  const count = writable(0);
</script>
<p>{$count}</p>

<!-- Svelte 5: Use $state instead, or explicit subscription -->
<script>
  // Option 1: Convert to $state
  let count = $state(0);

  // Option 2: If keeping stores, subscribe explicitly
  import { writable } from 'svelte/store';
  const countStore = writable(0);
  let count = $state(0);

  $effect(() => {
    const unsubscribe = countStore.subscribe(value => {
      count = value;
    });
    return unsubscribe;
  });
</script>
```

### Actions to Attachments

```svelte
<!-- Svelte 4 -->
<div use:myAction={params}>

<!-- Svelte 5 (actions still work, but consider attachments) -->
<div use:myAction={params}>

<!-- Svelte 5 with attachments -->
<div {@attach myAttachment(params)}>
```

---

**Next:** [23. Antipatterns Reference](./23-AntipatternsReference.md)
