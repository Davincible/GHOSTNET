# 24. Tips & Tricks

## 1. Shorthand Props

```svelte
<script>
	let name = $state('Alice');
	let age = $state(30);
	let active = $state(true);
</script>

<!-- Shorthand when variable name matches prop name -->
<User {name} {age} {active} />

<!-- Equivalent to -->
<User {name} {age} {active} />
```

## 2. Conditional Classes

```svelte
<div
	class="card"
	class:active={isActive}
	class:disabled={isDisabled}
	class:large={size === 'large'}
>
	Content
</div>

<!-- Dynamic class names -->
<div class={`card ${variant} ${size}`}>Content</div>
```

## 3. Style Props

```svelte
<div style:color="red" style:font-size="{fontSize}px">Styled text</div>

<!-- Dynamic styles -->
<div style:--theme-color={themeColor}>Uses CSS variable</div>
```

## 4. Two-Way Binding Shortcuts

```svelte
<!-- Bind to same-named property -->
<input bind:value />

<!-- Equivalent to -->
<input bind:value />

<!-- Group bindings -->
<input type="checkbox" bind:group={selectedItems} value={item} />
<input type="radio" bind:group={selected} value="option1" />
```

## 5. Reactive Window Bindings

```svelte
<svelte:window
	bind:innerWidth={width}
	bind:innerHeight={height}
	bind:scrollY={scroll}
	onkeydown={handleKeydown}
/>
```

## 6. Local Constants in Templates

```svelte
{#each items as item}
	{@const total = item.price * item.quantity}
	{@const discounted = total * (1 - item.discount)}

	<div>
		{item.name}: ${discounted.toFixed(2)}
	</div>
{/each}
```

## 7. Optional Rendering

```svelte
<!-- Conditional with optional chaining -->
{user?.profile?.avatar && (
  <img src={user.profile.avatar} alt="" />
)}

<!-- Nullish coalescing -->
<p>{user?.name ?? 'Anonymous'}</p>
```

## 8. Component Export for Instance Methods

```svelte
<!-- Counter.svelte -->
<script>
  let count = $state(0);

  export function reset() {
    count = 0;
  }

  export function getValue() {
    return count;
  }
</script>

<!-- Parent.svelte -->
<script>
  let counter: Counter;
</script>

<Counter bind:this={counter} />
<button onclick={() => counter.reset()}>Reset</button>
```

## 9. Debug Rendering

```svelte
{@debug user, items}

<!-- Pauses execution when these values change -->
<!-- Only works with dev tools open -->
```

## 10. HTML Rendering

```svelte
<script>
	let htmlContent = $state('<strong>Bold</strong> and <em>italic</em>');
</script>

<!-- Render HTML (be careful with user content!) -->
{@html htmlContent}
```

## 11. Await Blocks

```svelte
{#await loadData()}
	<p>Loading...</p>
{:then data}
	<DataView {data} />
{:catch error}
	<ErrorMessage {error} />
{/await}

<!-- Short form when you don't need loading state -->
{#await loadData() then data}
	<DataView {data} />
{/await}
```

## 12. Key Blocks for Forcing Remount

```svelte
<script>
	let userId = $state('123');
</script>

<!-- Component remounts when userId changes -->
{#key userId}
	<UserProfile {userId} />
{/key}
```

## 13. Type-Safe Event Handlers

```typescript
// Utility types for common events
type FormInputEvent = Event & { currentTarget: HTMLInputElement };
type FormSelectEvent = Event & { currentTarget: HTMLSelectElement };
type FormTextareaEvent = Event & { currentTarget: HTMLTextAreaElement };

function handleInput(e: FormInputEvent) {
	console.log(e.currentTarget.value);
}
```

## 14. Slot Props to Snippet Migration

```svelte
<!-- When migrating complex slot props -->
<script>
	let { children } = $props();
</script>

{@render children?.({
	item: currentItem,
	index: currentIndex,
	isFirst: currentIndex === 0,
	isLast: currentIndex === items.length - 1,
})}
```

## 15. SSR-Safe Unique IDs

```svelte
<script>
	// Generates consistent ID between server and client
	const id = $props.id();
</script>

<label for={id}>Name</label>
<input {id} />
```

---

**Next:** [25. Quick Reference Cheatsheet](./25-QuickReferenceCheatsheet.md)
