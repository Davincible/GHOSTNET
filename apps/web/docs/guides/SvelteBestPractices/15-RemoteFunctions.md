# 15. Remote Functions

> **Experimental Feature** — Available since SvelteKit 2.27. API may change.

Remote functions provide type-safe communication between client and server. They run exclusively on the server but can be called from anywhere in your app.

## Setup

```javascript
// svelte.config.js
export default {
  kit: {
    experimental: {
      remoteFunctions: true
    }
  },
  // Optional: enable async SSR for top-level await
  compilerOptions: {
    experimental: {
      async: true
    }
  }
};
```

## File Convention

Remote functions must be defined in files ending with `.remote.ts` or `.remote.js`:

```
src/
├── lib/
│   └── server/
│       ├── posts.remote.ts    ← Remote functions
│       ├── users.remote.ts
│       └── database.ts        ← Regular server module
└── routes/
    └── +page.svelte
```

## query() — Read Data

Use `query` for read operations (GET-like semantics):

```typescript
// src/lib/server/posts.remote.ts
import { query } from '$app/server';
import { db } from '$lib/server/database';

// Simple query (no parameters)
export const getPosts = query(async () => {
  return await db.posts.findMany({
    orderBy: { createdAt: 'desc' }
  });
});

// Query with parameters
export const getPost = query(async (id: string) => {
  const post = await db.posts.findUnique({ where: { id } });
  if (!post) {
    throw error(404, 'Post not found');
  }
  return post;
});

// Query with multiple parameters (use object)
export const searchPosts = query(async (params: { 
  query: string; 
  page?: number; 
  limit?: number 
}) => {
  const { query: q, page = 1, limit = 10 } = params;
  return await db.posts.findMany({
    where: { title: { contains: q } },
    skip: (page - 1) * limit,
    take: limit
  });
});
```

## Using Queries in Components

```svelte
<!-- +page.svelte -->
<script>
  import { getPosts, getPost, searchPosts } from '$lib/server/posts.remote';
  
  // With async SSR enabled, you can await directly
  const posts = await getPosts();
  
  // Or use the returned object for more control
  let searchQuery = $state('');
  const searchResults = searchPosts({ query: searchQuery });
</script>

<h1>Posts</h1>
{#each posts as post}
  <article>
    <h2>{post.title}</h2>
    <p>{post.excerpt}</p>
  </article>
{/each}

<h2>Search</h2>
<input bind:value={searchQuery} />

{#await searchResults.current}
  <p>Searching...</p>
{:then results}
  {#each results as post}
    <p>{post.title}</p>
  {/each}
{/await}
```

## Query Object Properties and Methods

```typescript
interface RemoteQuery<Input, Output> {
  /** Call the query with arguments */
  (input: Input): Promise<Output>;
  
  /** Current cached result (reactive) */
  current: Output | undefined;
  
  /** Whether a request is in flight */
  pending: boolean;
  
  /** Most recent error, if any */
  error: Error | undefined;
  
  /** Re-fetch data from server */
  refresh(): Promise<Output>;
}
```

```svelte
<script>
  import { getPosts } from '$lib/server/posts.remote';
  
  const posts = getPosts();
</script>

{#if posts.pending}
  <Spinner />
{:else if posts.error}
  <p>Error: {posts.error.message}</p>
{:else}
  {#each posts.current ?? [] as post}
    <p>{post.title}</p>
  {/each}
{/if}

<button onclick={() => posts.refresh()}>
  Refresh
</button>
```

## action() — Write Data

Use `action` for write operations (POST-like semantics):

```typescript
// src/lib/server/posts.remote.ts
import { query, action } from '$app/server';
import { error } from '@sveltejs/kit';
import { db } from '$lib/server/database';

// Create
export const createPost = action(async (data: {
  title: string;
  content: string;
  authorId: string;
}) => {
  return await db.posts.create({ data });
});

// Update
export const updatePost = action(async (params: {
  id: string;
  data: { title?: string; content?: string };
}) => {
  const { id, data } = params;
  return await db.posts.update({
    where: { id },
    data
  });
});

// Delete
export const deletePost = action(async (id: string) => {
  await db.posts.delete({ where: { id } });
  return { success: true };
});
```

```svelte
<script>
  import { createPost, deletePost } from '$lib/server/posts.remote';
  import { goto } from '$app/navigation';
  
  let title = $state('');
  let content = $state('');
  let submitting = $state(false);
  
  async function handleSubmit() {
    submitting = true;
    try {
      const post = await createPost({ 
        title, 
        content, 
        authorId: 'user-123' 
      });
      goto(`/posts/${post.id}`);
    } catch (err) {
      console.error(err);
    } finally {
      submitting = false;
    }
  }
  
  async function handleDelete(id: string) {
    if (confirm('Delete this post?')) {
      await deletePost(id);
      // Optionally refresh the list
    }
  }
</script>

<form onsubmit={(e) => { e.preventDefault(); handleSubmit(); }}>
  <input bind:value={title} placeholder="Title" />
  <textarea bind:value={content} placeholder="Content"></textarea>
  <button disabled={submitting}>
    {submitting ? 'Creating...' : 'Create Post'}
  </button>
</form>
```

## form() — Form Handling with Validation

Use `form` for form submissions with built-in validation:

```typescript
// src/lib/server/contact.remote.ts
import { form } from '$app/server';
import { z } from 'zod';
import { sendEmail } from '$lib/server/email';

// Define schema
const contactSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  email: z.string().email('Invalid email address'),
  message: z.string().min(10, 'Message must be at least 10 characters')
});

export const submitContact = form(contactSchema, async (data) => {
  // `data` is fully typed and validated
  await sendEmail({
    to: 'support@example.com',
    subject: `Contact from ${data.name}`,
    body: data.message,
    replyTo: data.email
  });
  
  return { success: true, message: 'Thank you for your message!' };
});
```

```svelte
<script>
  import { submitContact } from '$lib/server/contact.remote';
</script>

<form {...submitContact.enhance()}>
  <div>
    <label for="name">Name</label>
    <input id="name" name="name" />
    {#if submitContact.issues?.name}
      <span class="error">{submitContact.issues.name}</span>
    {/if}
  </div>
  
  <div>
    <label for="email">Email</label>
    <input id="email" name="email" type="email" />
    {#if submitContact.issues?.email}
      <span class="error">{submitContact.issues.email}</span>
    {/if}
  </div>
  
  <div>
    <label for="message">Message</label>
    <textarea id="message" name="message"></textarea>
    {#if submitContact.issues?.message}
      <span class="error">{submitContact.issues.message}</span>
    {/if}
  </div>
  
  <button disabled={submitContact.submitting}>
    {submitContact.submitting ? 'Sending...' : 'Send Message'}
  </button>
  
  {#if submitContact.result?.success}
    <p class="success">{submitContact.result.message}</p>
  {/if}
</form>
```

## Error Handling

```typescript
// src/lib/server/posts.remote.ts
import { query, action } from '$app/server';
import { error } from '@sveltejs/kit';

export const getPost = query(async (id: string) => {
  const post = await db.posts.findUnique({ where: { id } });
  
  if (!post) {
    // Throws a SvelteKit error
    throw error(404, 'Post not found');
  }
  
  return post;
});

export const createPost = action(async (data: CreatePostInput) => {
  try {
    return await db.posts.create({ data });
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError) {
      if (err.code === 'P2002') {
        throw error(409, 'A post with this slug already exists');
      }
    }
    throw error(500, 'Failed to create post');
  }
});
```

## Accessing Request Context

```typescript
// src/lib/server/posts.remote.ts
import { query, action, getRequestEvent } from '$app/server';
import { error } from '@sveltejs/kit';

export const getMyPosts = query(async () => {
  const event = getRequestEvent();
  const user = event.locals.user;
  
  if (!user) {
    throw error(401, 'Not authenticated');
  }
  
  return await db.posts.findMany({
    where: { authorId: user.id }
  });
});

export const createPost = action(async (data: CreatePostInput) => {
  const event = getRequestEvent();
  const user = event.locals.user;
  
  if (!user) {
    throw error(401, 'Not authenticated');
  }
  
  return await db.posts.create({
    data: {
      ...data,
      authorId: user.id
    }
  });
});
```

## Batching Requests

Multiple requests in the same macrotask can be batched:

```typescript
// src/lib/server/users.remote.ts
import { query } from '$app/server';
import { db } from '$lib/server/database';

export const getUser = query(async (id: string) => {
  return await db.users.findUnique({ where: { id } });
}, {
  // Batch resolver
  batch: (ids: string[]) => {
    return async (id: string, index: number) => {
      // Fetch all users in one query
      const users = await db.users.findMany({
        where: { id: { in: ids } }
      });
      // Return the specific user for this call
      return users.find(u => u.id === id) ?? null;
    };
  }
});
```

```svelte
<script>
  import { getUser } from '$lib/server/users.remote';
  
  // These three calls are batched into ONE request
  const user1 = await getUser('id-1');
  const user2 = await getUser('id-2');
  const user3 = await getUser('id-3');
</script>
```

## When to Use What

| Scenario | Recommendation |
|----------|----------------|
| Initial page data | Load functions (`+page.server.ts`) |
| SEO-critical content | Load functions |
| User-triggered data fetching | Remote `query()` |
| Create/Update/Delete | Remote `action()` |
| Form submissions | Remote `form()` |
| Shared data across components | Remote `query()` |
| Real-time updates | Remote `query()` + `refresh()` |

---

**Next:** [16. SSR & Hydration](./16-SSRAndHydration.md)
