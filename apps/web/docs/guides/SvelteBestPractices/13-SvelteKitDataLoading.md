# 13. SvelteKit Data Loading

## +page.server.ts (Server Load)

```typescript
// src/routes/users/+page.server.ts
import type { PageServerLoad } from './$types';
import { error, redirect } from '@sveltejs/kit';

export const load: PageServerLoad = async ({ 
  params, 
  locals, 
  url, 
  cookies,
  depends,
  parent 
}) => {
  // Auth check
  if (!locals.user) {
    redirect(303, '/login');
  }
  
  // Get query params
  const page = Number(url.searchParams.get('page')) || 1;
  const limit = Number(url.searchParams.get('limit')) || 20;
  
  // Declare cache dependency
  depends('users:list');
  
  try {
    // Parallel fetches
    const [users, stats] = await Promise.all([
      db.users.findMany({ skip: (page - 1) * limit, take: limit }),
      db.users.count()
    ]);
    
    return {
      users,
      pagination: {
        page,
        limit,
        total: stats,
        pages: Math.ceil(stats / limit)
      }
    };
  } catch (e) {
    console.error('Load error:', e);
    error(500, 'Failed to load users');
  }
};
```

## +page.ts (Universal Load)

```typescript
// src/routes/blog/+page.ts
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ fetch, url }) => {
  // fetch() handles SSR correctly
  const response = await fetch('/api/posts');
  
  if (!response.ok) {
    throw new Error('Failed to load posts');
  }
  
  return {
    posts: await response.json()
  };
};
```

## Streaming Data

```typescript
// +page.server.ts
export const load: PageServerLoad = async ({ locals }) => {
  // Fast: return immediately
  const summary = await db.getSummary();
  
  // Slow: stream later
  const detailedReport = db.getDetailedReport(); // Returns Promise, not awaited
  
  return {
    summary,
    detailedReport // Streamed to client
  };
};
```

```svelte
<!-- +page.svelte -->
<script>
  let { data } = $props();
</script>

<h1>{data.summary.title}</h1>

{#await data.detailedReport}
  <p>Loading detailed report...</p>
{:then report}
  <Report data={report} />
{:catch error}
  <p>Failed to load: {error.message}</p>
{/await}
```

## Layout Data Inheritance

```typescript
// src/routes/dashboard/+layout.server.ts
export const load: LayoutServerLoad = async ({ locals }) => {
  return {
    user: locals.user,
    permissions: await getPermissions(locals.user.id)
  };
};

// src/routes/dashboard/settings/+page.server.ts
export const load: PageServerLoad = async ({ parent }) => {
  // Access parent layout data
  const { user, permissions } = await parent();
  
  if (!permissions.includes('settings:read')) {
    error(403, 'No access to settings');
  }
  
  return {
    settings: await getSettings(user.id)
  };
};
```

## Invalidation

```svelte
<script>
  import { invalidate, invalidateAll } from '$app/navigation';
  
  async function refresh() {
    // Invalidate specific dependency
    await invalidate('users:list');
    
    // Invalidate URL pattern
    await invalidate('/api/users');
    
    // Invalidate everything
    await invalidateAll();
  }
</script>
```

## Page Options

```typescript
// +page.server.ts
export const prerender = true; // Static generation
export const ssr = false;      // Client-only
export const csr = true;       // Enable client-side rendering

// +page.ts
export const prerender = 'auto'; // Prerender if possible
```

---

## $app/state (SvelteKit 2.12+)

The `$app/state` module provides reactive state objects that replace the deprecated `$app/stores`.

### Migration from $app/stores

```svelte
<!-- OLD: $app/stores (deprecated) -->
<script>
  import { page, navigating, updated } from '$app/stores';
</script>

<p>Path: {$page.url.pathname}</p>
{#if $navigating}
  <Spinner />
{/if}

<!-- NEW: $app/state -->
<script>
  import { page, navigating, updated } from '$app/state';
</script>

<!-- No $ prefix needed -->
<p>Path: {page.url.pathname}</p>
{#if navigating}
  <Spinner />
{/if}
```

### page

A read-only reactive object with current page information:

```typescript
interface Page {
  /** Current URL */
  url: URL;
  
  /** Route parameters */
  params: Record<string, string>;
  
  /** Current route info */
  route: {
    id: string | null;
  };
  
  /** HTTP status code */
  status: number;
  
  /** Error object if on error page */
  error: App.Error | null;
  
  /** Combined data from all load functions */
  data: App.PageData;
  
  /** Page state (from history.pushState/replaceState) */
  state: App.PageState;
  
  /** Form action result */
  form: any;
}
```

```svelte
<script>
  import { page } from '$app/state';
</script>

<nav>
  <a href="/" class:active={page.url.pathname === '/'}>Home</a>
  <a href="/about" class:active={page.url.pathname === '/about'}>About</a>
</nav>

{#if page.error}
  <p>Error: {page.error.message}</p>
{/if}

<p>User: {page.data.user?.name}</p>
```

### navigating

A read-only reactive object representing in-progress navigation:

```typescript
interface Navigation {
  /** Starting page */
  from: {
    url: URL;
    params: Record<string, string>;
    route: { id: string | null };
  } | null;
  
  /** Destination page */
  to: {
    url: URL;
    params: Record<string, string>;
    route: { id: string | null };
  } | null;
  
  /** Navigation type */
  type: 'link' | 'popstate' | 'goto' | 'form' | null;
  
  /** For popstate: history delta */
  delta: number | null;
  
  /** Whether navigation will unload the page */
  willUnload: boolean | null;
  
  /** Promise that resolves when navigation completes */
  complete: Promise<void> | null;
}
```

```svelte
<script>
  import { navigating } from '$app/state';
</script>

{#if navigating}
  <div class="loading-bar">
    Navigating from {navigating.from?.url.pathname} 
    to {navigating.to?.url.pathname}
  </div>
{/if}
```

### updated

A read-only reactive object for app version changes:

```typescript
interface Updated {
  /** Whether a new version is available */
  current: boolean;
  
  /** Force an immediate version check */
  check(): Promise<boolean>;
}
```

```svelte
<script>
  import { updated } from '$app/state';
</script>

{#if updated.current}
  <div class="update-banner">
    A new version is available!
    <button onclick={() => location.reload()}>Refresh</button>
  </div>
{/if}

<!-- Manual check -->
<button onclick={() => updated.check()}>Check for updates</button>
```

### Key Differences from $app/stores

| $app/stores | $app/state |
|-------------|------------|
| Svelte stores (require `$` prefix) | Reactive objects (no prefix) |
| `$page.url` | `page.url` |
| Coarse reactivity (whole object) | Fine-grained (individual properties) |
| Works in Svelte 4 & 5 | Requires Svelte 5 |
| Can subscribe in any `.js` file | Must be in `.svelte` or `.svelte.ts` files |

### Fine-Grained Reactivity Benefit

With `$app/state`, updates are fine-grained:

```svelte
<script>
  import { page } from '$app/state';
  
  // This effect ONLY runs when page.data changes
  // NOT when page.url or page.state changes
  $effect(() => {
    console.log('Data changed:', page.data);
  });
</script>
```

---

**Next:** [14. Form Actions & Progressive Enhancement](./14-FormActionsProgressiveEnhancement.md)
