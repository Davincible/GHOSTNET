# 25. Quick Reference Cheatsheet

## Runes

```svelte
<script>
	// State
	let count = $state(0);
	let items = $state([]);
	let raw = $state.raw(largeData);
	const plain = $state.snapshot(proxyObj);

	// Derived
	const doubled = $derived(count * 2);
	const complex = $derived.by(() => {
		/* logic */
	});

	// Effects
	$effect(() => {
		/* side effect */
	});
	$effect.pre(() => {
		/* before DOM */
	});
	const cleanup = $effect.root(() => {
		/* manual */
	});

	// Props
	let { name, age = 18 } = $props();
	let { value = $bindable(0) } = $props();
	const id = $props.id();

	// Debug
	$inspect(value);
	$inspect.trace('label');
</script>
```

## Template Syntax

```svelte
<!-- Conditionals -->
{#if condition}...{:else if other}...{:else}...{/if}

<!-- Loops -->
{#each items as item, index (item.id)}...{/each}

<!-- Await -->
{#await promise}...{:then value}...{:catch error}...{/await}

<!-- Key (force remount) -->
{#key value}...{/key}

<!-- Snippets -->
{#snippet name(param)}...{/snippet}
{@render name(arg)}

<!-- Attachments -->
{@attach attachmentFn}
{@attach factory(params)}
{@attach (el) => { /* inline */ }}

<!-- Special -->
{@html rawHtml}
{@debug var1, var2}
{@const localVar = expression}
```

## Bindings

```svelte
<!-- Value bindings -->
<input bind:value />
<textarea bind:value />
<select bind:value />

<!-- Checked/group -->
<input type="checkbox" bind:checked />
<input type="checkbox" bind:group={arr} {value} />
<input type="radio" bind:group={selected} {value} />

<!-- Element reference -->
<div bind:this={element} />

<!-- Component instance -->
<Component bind:this={instance} />

<!-- Dimensions (readonly) -->
<div bind:clientWidth={w} bind:clientHeight={h} />

<!-- Media -->
<video bind:currentTime bind:duration bind:paused />
```

## Directives

```svelte
<!-- Class -->
<div class:active={isActive} />
<div class:active />

<!-- Style -->
<div style:color="red" />
<div style:--var={value} />

<!-- Actions (legacy, prefer attachments) -->
<div use:action />
<div use:action={params} />

<!-- Transitions -->
<div transition:fade />
<div transition:slide|local />
<div in:fly={{ y: 100 }} out:fade />
<div animate:flip />
```

## Special Elements

```svelte
<svelte:options immutable />

<svelte:window bind:innerWidth onkeydown={handler} />
<svelte:document onvisibilitychange={handler} />
<svelte:body onmouseenter={handler} />
<svelte:head><title>Page</title></svelte:head>
<svelte:element this={tag} />
<svelte:component this={Component} />
<svelte:fragment />

<svelte:boundary onerror={handler}>{#snippet failed(error)}...{/snippet}</svelte:boundary>
```

---

## Imports

### Svelte Core

```javascript
import { mount, unmount, untrack, tick } from 'svelte';
import { setContext, getContext, hasContext, createContext } from 'svelte';
import { onMount, onDestroy } from 'svelte'; // Legacy, use $effect
```

### Reactivity

```javascript
import { SvelteSet, SvelteMap, SvelteURL, SvelteDate } from 'svelte/reactivity';
```

### Motion (Svelte 5.8+)

```javascript
import { Spring, Tween, prefersReducedMotion } from 'svelte/motion';
```

### Transitions & Animations

```javascript
import { fade, fly, slide, scale, blur, draw, crossfade } from 'svelte/transition';
import { flip } from 'svelte/animate';
import { cubicOut, elasticOut, quintOut } from 'svelte/easing';
```

### Attachments (Svelte 5.29+)

```javascript
import { createAttachmentKey, fromAction } from 'svelte/attachments';
```

### SvelteKit State (2.12+)

```javascript
import { page, navigating, updated } from '$app/state';
```

### SvelteKit Navigation

```javascript
import { goto, invalidate, invalidateAll, preloadData, preloadCode } from '$app/navigation';
```

### SvelteKit Forms

```javascript
import { enhance } from '$app/forms';
```

### SvelteKit Environment

```javascript
import { browser, dev, building } from '$app/environment';
```

### SvelteKit Server (for Remote Functions)

```javascript
import { query, action, form, getRequestEvent } from '$app/server';
```

---

## sv CLI

```bash
# Create project
bunx sv create my-app
bunx sv create my-app --template minimal
bunx sv create my-app --template demo
bunx sv create my-app --add drizzle,lucia,paraglide

# Add features
bunx sv add drizzle
bunx sv add lucia
bunx sv add paraglide
bunx sv add vitest
bunx sv add playwright
bunx sv add storybook
bunx sv add mdsvex

# Migrations
bunx sv migrate svelte-5
bunx sv migrate sveltekit-2

# Check project
bunx sv check
```

### Available Add-ons

| Add-on       | Description                      |
| ------------ | -------------------------------- |
| `drizzle`    | Drizzle ORM with migrations      |
| `lucia`      | Authentication with demo pages   |
| `paraglide`  | i18n with type-safe translations |
| `vitest`     | Unit testing                     |
| `playwright` | E2E testing                      |
| `storybook`  | Component stories                |
| `mdsvex`     | Markdown preprocessing           |
| `prettier`   | Code formatting                  |
| `eslint`     | Linting                          |

---

## Testing

### Critical: File Naming Convention

```
src/lib/counter.svelte.ts      # Runes work here
src/lib/counter.svelte.test.ts # Runes work here too!

src/lib/counter.ts             # NO runes (not compiled)
src/lib/counter.test.ts        # NO runes (not compiled)
```

**Rule:** Any file using `$state`, `$derived`, `$effect` must have `.svelte.ts` extension.

### Testing Imports

```typescript
// Vitest Browser Mode (recommended)
import { render } from 'vitest-browser-svelte';
import { page } from 'vitest/browser';

// Vitest + jsdom
import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';

// Both approaches
import { describe, it, expect, vi } from 'vitest';
import { flushSync, tick, untrack } from 'svelte';
```

### Testing Runes

```typescript
// counter.svelte.ts
export function createCounter(initial = 0) {
	let count = $state(initial);
	return {
		get count() {
			return count;
		},
		increment() {
			count++;
		},
	};
}

// counter.svelte.test.ts
import { flushSync } from 'svelte';
import { createCounter } from './counter.svelte.js';

it('increments count', () => {
	const counter = createCounter(0);

	flushSync(() => counter.increment());

	expect(counter.count).toBe(1);
});
```

### Testing $effect

```typescript
import { flushSync } from 'svelte';

it('tracks effect calls', () => {
	const calls: number[] = [];
	let value = $state(0);

	// Create effect root for manual control
	const cleanup = $effect.root(() => {
		$effect(() => {
			calls.push(value);
		});
	});

	flushSync(); // Initial run
	expect(calls).toEqual([0]);

	flushSync(() => (value = 1));
	expect(calls).toEqual([0, 1]);

	cleanup(); // Cleanup effects
});
```

### Testing $derived with `untrack()`

```typescript
import { untrack, flushSync } from 'svelte';

it('reads derived values safely', () => {
	let count = $state(0);
	let doubled = $derived(count * 2);

	// Use untrack() to read $derived in test assertions
	expect(untrack(() => doubled)).toBe(0);

	count = 5;
	flushSync();
	expect(untrack(() => doubled)).toBe(10);
});
```

### Locator DOM Methods (`.element()`)

```typescript
// Vitest locators need .element() for DOM methods
const input = page.getByLabel('Email');

// WRONG: focus() doesn't exist on locators
// await input.focus();

// CORRECT: Use .element()
await input.element().focus();
await input.element().blur();
```

### Vitest Config (Browser Mode)

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig({
	plugins: [svelte()],
	test: {
		include: ['src/**/*.svelte.test.ts'],
		browser: {
			enabled: true,
			provider: 'playwright',
			instances: [{ browser: 'chromium' }],
		},
	},
});
```

### Common Test Patterns

```typescript
// Wait for state updates
flushSync(() => {
	/* mutations */
});

// Wait for async/tick
await tick();

// Mock timers
vi.useFakeTimers();
vi.advanceTimersByTime(1000);

// Cleanup effects
const cleanup = $effect.root(() => {
	/* effects */
});
cleanup(); // Call in afterEach or end of test

// Multiple elements (strict mode)
page.getByRole('link', { name: 'Home' }).first();
page.getByRole('listitem').nth(2);

// Real FormData for server tests
const formData = new FormData();
formData.append('email', 'test@example.com');
const request = new Request('http://localhost/api', {
	method: 'POST',
	body: formData,
});
```

### Input Role Quick Reference

| Input Type      | Use Role     |
| --------------- | ------------ |
| `text`, `email` | `textbox`    |
| `checkbox`      | `checkbox`   |
| `radio`         | `radio`      |
| `number`        | `spinbutton` |
| `<select>`      | `combobox`   |

---

## Version Compatibility

| Feature              | Minimum Version        | Status       |
| -------------------- | ---------------------- | ------------ |
| Core Runes           | Svelte 5.0.0           | Stable       |
| Spring/Tween Classes | Svelte 5.8.0           | Stable       |
| prefersReducedMotion | Svelte 5.7.0           | Stable       |
| Attachments          | Svelte 5.29.0          | Stable       |
| createContext        | Svelte 5.40.0          | Stable       |
| $app/state           | SvelteKit 2.12.0       | Stable       |
| Remote Functions     | SvelteKit 2.27.0       | Experimental |
| Async SSR            | Svelte 5.36 / Kit 2.43 | Experimental |
| sv CLI               | sv 0.5.0+              | Stable       |

---

_Reference Version: January 2026 | Svelte 5.x | SvelteKit 2.x_
