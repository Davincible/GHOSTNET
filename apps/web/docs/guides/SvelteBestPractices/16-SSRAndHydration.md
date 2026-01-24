# 16. SSR & Hydration

## Understanding SSR Flow

```
1. Browser requests page
2. Server runs +page.server.ts load()
3. Server renders component to HTML
4. Server sends HTML + serialized data
5. Browser shows HTML immediately
6. Browser downloads JavaScript
7. Svelte "hydrates" - attaches event listeners
8. Page is now interactive
```

## SSR-Safe Patterns

```svelte
<script>
	import { browser } from '$app/environment';

	// ✅ Safe: Check browser before using browser APIs
	let width = $state(0);

	$effect(() => {
		if (browser) {
			width = window.innerWidth;

			const handleResize = () => {
				width = window.innerWidth;
			};

			window.addEventListener('resize', handleResize);
			return () => window.removeEventListener('resize', handleResize);
		}
	});

	// ✅ Safe: Use $effect for client-only code
	$effect(() => {
		// This only runs in browser
		document.title = 'My Page';
	});
</script>
```

## Avoiding Hydration Mismatches

```svelte
<script>
  import { browser } from '$app/environment';

  // ❌ WRONG: Different values on server vs client
  let time = new Date().toLocaleTimeString(); // Different every render!

  // ✅ CORRECT: Initialize consistently
  let time = $state('--:--:--');

  $effect(() => {
    // Update only in browser
    const update = () => {
      time = new Date().toLocaleTimeString();
    };
    update();
    const id = setInterval(update, 1000);
    return () => clearInterval(id);
  });
</script>

<script>
  // ❌ WRONG: Random IDs
  const id = Math.random().toString(36);

  // ✅ CORRECT: Use $props.id()
  const id = $props.id();
</script>

<script>
  // ❌ WRONG: Browser-only globals
  const screenWidth = window.innerWidth; // Error on server!

  // ✅ CORRECT: Check browser first
  import { browser } from '$app/environment';
  const screenWidth = browser ? window.innerWidth : 0;
</script>
```

## Avoiding Hydration Flicker (Theme Example)

For client-only data like localStorage, the standard pattern causes a flash:

```svelte
<script>
	import { browser } from '$app/environment';

	// ❌ WRONG - flickers on hydration
	// Server renders 'light', then client switches to 'dark'
	let theme = $state(browser ? localStorage.getItem('theme') : 'light');
</script>

<div class={theme}>...</div>
```

**Solution: Inline script in app.html**

Set the class before any rendering occurs:

```html
<!-- src/app.html -->
<!doctype html>
<html lang="en">
	<head>
		<script>
			// Runs before any rendering - no flicker
			const theme = localStorage.getItem('theme') || 'light';
			document.documentElement.classList.add(theme);
		</script>
		%sveltekit.head%
	</head>
	<body data-sveltekit-preload-data="hover">
		<div style="display: contents">%sveltekit.body%</div>
	</body>
</html>
```

```svelte
<!-- Component reads from what app.html set -->
<script>
	import { browser } from '$app/environment';

	let theme = $state('light');

	if (browser) {
		// Read from DOM class that was set before hydration
		theme = document.documentElement.classList.contains('dark') ? 'dark' : 'light';
	}

	function toggleTheme() {
		const newTheme = theme === 'light' ? 'dark' : 'light';
		theme = newTheme;
		document.documentElement.classList.remove('light', 'dark');
		document.documentElement.classList.add(newTheme);
		localStorage.setItem('theme', newTheme);
	}
</script>
```

## Client-Only Components

```svelte
<!-- Chart.svelte -->
<script>
	import { browser } from '$app/environment';

	let mounted = $state(false);

	$effect(() => {
		mounted = true;
	});
</script>

{#if mounted}
	<!-- Only render on client -->
	<canvas bind:this={canvas}></canvas>
{:else}
	<!-- Server placeholder -->
	<div class="chart-placeholder">Loading chart...</div>
{/if}
```

## SSR-Safe Storage

```typescript
// storage.svelte.ts
import { browser } from '$app/environment';

export function createLocalStorage<T>(key: string, initial: T) {
	let value = $state<T>(initial);

	// Hydrate from localStorage on client
	$effect(() => {
		if (browser) {
			const stored = localStorage.getItem(key);
			if (stored) {
				try {
					value = JSON.parse(stored);
				} catch {}
			}
		}
	});

	// Persist changes
	$effect(() => {
		if (browser) {
			localStorage.setItem(key, JSON.stringify(value));
		}
	});

	return {
		get value() {
			return value;
		},
		set value(v: T) {
			value = v;
		},
	};
}
```

## Error Boundaries

Use `<svelte:boundary>` for declarative error handling:

```svelte
<svelte:boundary onerror={(e) => console.error(e)}>
	{#snippet failed(error)}
		<div class="error-fallback">
			<h2>Something went wrong</h2>
			<p>{error.message}</p>
			<button onclick={() => location.reload()}>Reload</button>
		</div>
	{/snippet}

	<RiskyComponent />
</svelte:boundary>
```

---

**Next:** [17. Async SSR](./17-AsyncSSR.md)
