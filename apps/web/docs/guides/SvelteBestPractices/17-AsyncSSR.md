# 17. Async SSR

> **Experimental Feature** — Available since Svelte 5.36 / SvelteKit 2.43. API may change.

Async SSR allows using `await` directly in component scripts without wrapper blocks.

## Setup

```javascript
// svelte.config.js
export default {
	compilerOptions: {
		experimental: {
			async: true,
		},
	},
};
```

## Basic Usage

```svelte
<!-- Before: Required {#await} blocks -->
<script>
  const dataPromise = fetch('/api/data').then(r => r.json());
</script>

{#await dataPromise}
  <p>Loading...</p>
{:then data}
  <h1>{data.title}</h1>
{:catch error}
  <p>Error: {error.message}</p>
{/await}

<!-- After: Direct await -->
<script>
  const data = await fetch('/api/data').then(r => r.json());
</script>

<h1>{data.title}</h1>
```

## With Remote Functions

```svelte
<script>
	import { getPosts, getUser } from '$lib/server/data.remote';

	// Multiple awaits
	const posts = await getPosts();
	const user = await getUser('current');
</script>

<h1>Welcome, {user.name}</h1>

{#each posts as post}
	<article>{post.title}</article>
{/each}
```

## Parallel Fetching

```svelte
<script>
	import { getPosts, getUser } from '$lib/server/data.remote';

	// Sequential (slower)
	const posts = await getPosts();
	const user = await getUser();

	// Parallel (faster) - PREFERRED
	const [posts, user] = await Promise.all([getPosts(), getUser()]);
</script>
```

## Error Handling

With async SSR, errors throw like normal async code:

```svelte
<script>
	import { getPost } from '$lib/server/posts.remote';

	let { postId } = $props();

	// Wrap in try-catch for error handling
	let post;
	let error;

	try {
		post = await getPost(postId);
	} catch (e) {
		error = e;
	}
</script>

{#if error}
	<p>Error: {error.message}</p>
{:else}
	<h1>{post.title}</h1>
{/if}
```

## Error Boundaries

Use `<svelte:boundary>` for declarative error handling with async components:

```svelte
<svelte:boundary onerror={(e) => console.error(e)}>
	{#snippet failed(error)}
		<p>Something went wrong: {error.message}</p>
	{/snippet}

	<AsyncComponent />
</svelte:boundary>
```

## Streaming with Async SSR

Async SSR works with SvelteKit's streaming:

```typescript
// +page.server.ts
export async function load() {
	return {
		// Fast data - awaited before HTML sent
		fastData: await getFastData(),

		// Slow data - streamed in later
		slowData: getSlowData(), // NOT awaited
	};
}
```

```svelte
<!-- +page.svelte -->
<script>
	let { data } = $props();

	// fastData is immediately available
	// slowData streams in when ready
	const slow = await data.slowData;
</script>

<h1>{data.fastData.title}</h1>

<section>
	<h2>{slow.title}</h2>
</section>
```

## Caveats

- **Experimental:** API may change in future releases
- **Load functions still recommended** for initial page data (SEO, caching)
- **No loading states:** Direct await means no loading UI during SSR — content appears when ready
- **Error handling:** Must use try-catch or error boundaries explicitly
- **Bundle size:** Async transforms add some overhead to the compiled output
- **Testing:** May require additional setup in test environments

## When to Use Async SSR

| Use Case              | Recommendation                          |
| --------------------- | --------------------------------------- |
| Initial page data     | Use `+page.server.ts` load functions    |
| Child component data  | Async SSR works well                    |
| Data that streams     | Combine with load function streaming    |
| Complex orchestration | Use `Promise.all` for parallel fetching |

---

**Next:** [18. Performance Patterns](./18-PerformancePatterns.md)
