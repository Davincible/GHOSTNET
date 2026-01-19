# 27. Testing Patterns

> Patterns for testing Svelte 5 runes, components, stores, and context.

For setup and configuration, see [26. Testing Setup](./26-TestingSetup.md).

---

## Testing Runes

### Testing `$state`

Basic `$state` testing:

```typescript
// counter.svelte.ts
export function createCounter() {
  let count = $state(0);
  
  return {
    get count() { return count; },
    set count(value: number) { count = value; },
    increment() { count++; },
  };
}

// counter.svelte.test.ts
import { describe, it, expect } from 'vitest';
import { createCounter } from './counter.svelte';

describe('$state', () => {
  it('reads initial value', () => {
    const counter = createCounter();
    expect(counter.count).toBe(0);
  });

  it('updates via setter', () => {
    const counter = createCounter();
    counter.count = 10;
    expect(counter.count).toBe(10);
  });

  it('updates via method', () => {
    const counter = createCounter();
    counter.increment();
    expect(counter.count).toBe(1);
  });
});
```

### Testing `$derived`

`$derived` values update synchronously when dependencies change:

```typescript
// multiplier.svelte.ts
export function createMultiplier(factor: number) {
  let value = $state(0);
  let result = $derived(value * factor);
  
  return {
    get value() { return value; },
    set value(v: number) { value = v; },
    get result() { return result; },
  };
}

// multiplier.svelte.test.ts
import { describe, it, expect } from 'vitest';
import { createMultiplier } from './multiplier.svelte';

describe('$derived', () => {
  it('computes initial derived value', () => {
    const mult = createMultiplier(3);
    expect(mult.result).toBe(0); // 0 * 3 = 0
  });

  it('recomputes when dependency changes', () => {
    const mult = createMultiplier(3);
    mult.value = 5;
    expect(mult.result).toBe(15); // 5 * 3 = 15
  });

  it('tracks multiple updates', () => {
    const mult = createMultiplier(2);
    
    mult.value = 1;
    expect(mult.result).toBe(2);
    
    mult.value = 10;
    expect(mult.result).toBe(20);
  });
});
```

### Using `untrack()` for `$derived` Values

When testing `$derived` values outside of a reactive context (like in test assertions), you should use `untrack()` to avoid triggering reactive tracking:

```typescript
import { untrack, flushSync } from 'svelte';

describe('$derived with untrack', () => {
  it('accesses derived values safely', () => {
    let count = $state(0);
    let doubled = $derived(count * 2);
    
    // Use untrack() to read $derived values in tests
    expect(untrack(() => doubled)).toBe(0);
    
    count = 5;
    flushSync(); // Ensure derived updates
    expect(untrack(() => doubled)).toBe(10);
  });

  it('handles object getters with $derived', () => {
    const form = createFormState();
    
    // For getters that return $derived, get the function first
    const isValid = form.isFormValid;
    expect(untrack(() => isValid())).toBe(true);
    
    // Or if it's a direct getter:
    expect(untrack(() => form.hasChanges)).toBe(false);
  });
});
```

**When to use `untrack()`:**

| Scenario | Use `untrack()`? |
|----------|------------------|
| Reading `$derived` in test assertion | Yes |
| Reading `$state` in test assertion | No (but doesn't hurt) |
| Inside `$effect` in tests | No (already tracked) |
| Inside component template | No (Svelte handles it) |

**Why `untrack()` matters:**

Without `untrack()`, reading a `$derived` value can create unexpected reactive subscriptions in your test code. While tests often work without it, using `untrack()` is more explicit and matches how the sveltest community recommends testing derived state.

---

### Testing `$derived.by`

For complex derivations:

```typescript
// stats.svelte.ts
export function createStats() {
  let numbers = $state<number[]>([]);
  
  let stats = $derived.by(() => {
    if (numbers.length === 0) {
      return { sum: 0, avg: 0, count: 0 };
    }
    
    const sum = numbers.reduce((a, b) => a + b, 0);
    return {
      sum,
      avg: sum / numbers.length,
      count: numbers.length,
    };
  });
  
  return {
    add(n: number) { numbers.push(n); },
    get stats() { return stats; },
  };
}

// stats.svelte.test.ts
describe('$derived.by', () => {
  it('computes complex derived values', () => {
    const s = createStats();
    
    s.add(10);
    s.add(20);
    s.add(30);
    
    expect(s.stats).toEqual({
      sum: 60,
      avg: 20,
      count: 3,
    });
  });
});
```

### Testing `$effect`

`$effect` requires special handling - wrap in `$effect.root()`:

```typescript
// logger.svelte.test.ts
import { describe, it, expect } from 'vitest';
import { flushSync } from 'svelte';

describe('$effect', () => {
  it('runs effect when dependencies change', () => {
    const logs: number[] = [];
    
    // Wrap in $effect.root() for proper cleanup
    const cleanup = $effect.root(() => {
      let count = $state(0);
      
      $effect(() => {
        logs.push(count);
      });
      
      // Flush to run pending effects synchronously
      flushSync();
      expect(logs).toEqual([0]);
      
      count = 1;
      flushSync();
      expect(logs).toEqual([0, 1]);
      
      count = 2;
      flushSync();
      expect(logs).toEqual([0, 1, 2]);
    });
    
    // Always cleanup!
    cleanup();
  });
});
```

### When to Use `flushSync()`

| Scenario | Need `flushSync()`? |
|----------|---------------------|
| Testing `$state` getter | No |
| Testing `$derived` getter | No |
| Testing `$effect` | Yes |
| External state changes | Yes |
| Component DOM updates | Yes (or use locator auto-retry) |
| Browser mode with locators | No (auto-retry) |

---

## Testing Components

### Component with Props

**src/lib/components/Greeting.svelte:**

```svelte
<script lang="ts">
  interface Props {
    name: string;
    formal?: boolean;
  }
  
  let { name, formal = false }: Props = $props();
  
  let greeting = $derived(
    formal ? `Good day, ${name}.` : `Hey ${name}!`
  );
</script>

<p data-testid="greeting">{greeting}</p>
```

**src/lib/components/Greeting.svelte.test.ts:**

```typescript
import { describe, it, expect } from 'vitest';
import { render } from 'vitest-browser-svelte';
import { page } from 'vitest/browser';
import Greeting from './Greeting.svelte';

describe('Greeting', () => {
  it('renders informal greeting by default', async () => {
    render(Greeting, { name: 'World' });
    
    await expect
      .element(page.getByTestId('greeting'))
      .toHaveTextContent('Hey World!');
  });

  it('renders formal greeting when specified', async () => {
    render(Greeting, { name: 'Mr. Smith', formal: true });
    
    await expect
      .element(page.getByTestId('greeting'))
      .toHaveTextContent('Good day, Mr. Smith.');
  });
});
```

### Component with Events

**src/lib/components/SearchInput.svelte:**

```svelte
<script lang="ts">
  interface Props {
    value?: string;
    onsubmit?: (query: string) => void;
  }
  
  let { value = $bindable(''), onsubmit }: Props = $props();
  
  function handleSubmit(e: Event) {
    e.preventDefault();
    onsubmit?.(value);
  }
</script>

<form onsubmit={handleSubmit}>
  <input 
    type="search" 
    bind:value 
    placeholder="Search..."
    aria-label="Search"
  />
  <button type="submit">Search</button>
</form>
```

**src/lib/components/SearchInput.svelte.test.ts:**

```typescript
import { describe, it, expect, vi } from 'vitest';
import { render } from 'vitest-browser-svelte';
import { page } from 'vitest/browser';
import SearchInput from './SearchInput.svelte';

describe('SearchInput', () => {
  it('calls onsubmit with input value', async () => {
    const handleSubmit = vi.fn();
    
    render(SearchInput, { onsubmit: handleSubmit });
    
    const input = page.getByLabel('Search');
    const button = page.getByRole('button', { name: 'Search' });
    
    await input.fill('svelte testing');
    await button.click();
    
    expect(handleSubmit).toHaveBeenCalledWith('svelte testing');
  });

  it('uses initial value', async () => {
    render(SearchInput, { value: 'initial query' });
    
    await expect
      .element(page.getByLabel('Search'))
      .toHaveValue('initial query');
  });
});
```

### Locator DOM Methods (`.element()`)

Vitest browser locators don't have native DOM methods like `focus()` and `blur()` directly. Use `.element()` to access them:

```typescript
describe('Form Focus Management', () => {
  it('handles focus and blur events', async () => {
    const handleFocus = vi.fn();
    const handleBlur = vi.fn();
    
    render(Input, { 
      label: 'Email',
      onfocus: handleFocus,
      onblur: handleBlur,
    });
    
    const input = page.getByLabel('Email');
    
    // WRONG: focus() doesn't exist on Vitest locators
    // await input.focus();
    
    // CORRECT: Use .element() to access native DOM methods
    await input.element().focus();
    expect(handleFocus).toHaveBeenCalled();
    
    await input.element().blur();
    expect(handleBlur).toHaveBeenCalled();
  });

  it('tests keyboard navigation', async () => {
    render(TabPanel);
    
    const firstTab = page.getByRole('tab').first();
    
    // Focus the element using .element()
    await firstTab.element().focus();
    await expect.element(firstTab).toBeFocused();
    
    // Keyboard navigation
    await page.keyboard.press('ArrowRight');
    
    const secondTab = page.getByRole('tab').nth(1);
    await expect.element(secondTab).toBeFocused();
  });
});
```

**Note:** This is different from Playwright E2E tests where locators have `focus()` directly. In Vitest browser component tests, always use `.element()` for:
- `focus()`
- `blur()`
- `scrollIntoView()`
- Other native DOM methods

---

### Component with Snippets

Testing components that use snippets (Svelte 5's replacement for slots):

**src/lib/components/Card.svelte:**

```svelte
<script lang="ts">
  import type { Snippet } from 'svelte';
  
  interface Props {
    header?: Snippet;
    children: Snippet;
    footer?: Snippet;
  }
  
  let { header, children, footer }: Props = $props();
</script>

<article class="card">
  {#if header}
    <header>{@render header()}</header>
  {/if}
  
  <div class="content">
    {@render children()}
  </div>
  
  {#if footer}
    <footer>{@render footer()}</footer>
  {/if}
</article>
```

**src/lib/components/Card.svelte.test.ts:**

```typescript
import { describe, it, expect } from 'vitest';
import { render } from 'vitest-browser-svelte';
import { page } from 'vitest/browser';
import { createRawSnippet } from 'svelte';
import Card from './Card.svelte';

describe('Card', () => {
  it('renders children snippet', async () => {
    const children = createRawSnippet(() => ({
      render: () => '<p>Card content</p>',
    }));
    
    render(Card, { children });
    
    await expect
      .element(page.getByText('Card content'))
      .toBeVisible();
  });

  it('renders header when provided', async () => {
    const header = createRawSnippet(() => ({
      render: () => '<h2>Card Title</h2>',
    }));
    
    const children = createRawSnippet(() => ({
      render: () => '<p>Content</p>',
    }));
    
    render(Card, { header, children });
    
    await expect
      .element(page.getByRole('heading', { name: 'Card Title' }))
      .toBeVisible();
  });
});
```

### SSR Testing

**src/lib/components/BlogPost.ssr.test.ts:**

```typescript
import { describe, it, expect } from 'vitest';
import { render } from 'svelte/server';
import BlogPost from './BlogPost.svelte';

describe('BlogPost SSR', () => {
  it('renders post structure', () => {
    const { body } = render(BlogPost, {
      props: {
        title: 'Test Post',
        content: '<p>Post content here</p>',
        author: 'Jane Doe',
      },
    });
    
    expect(body).toContain('Test Post');
    expect(body).toContain('Post content here');
    expect(body).toContain('Jane Doe');
  });

  it('includes meta tags', () => {
    const { head } = render(BlogPost, {
      props: {
        title: 'SEO Test',
        description: 'A test description',
      },
    });
    
    expect(head).toContain('<meta name="description"');
  });
});
```

---

## Testing Stores and Context

### Universal State (`.svelte.ts` files)

**src/lib/stores/cart.svelte.ts:**

```typescript
export function createCart() {
  let items = $state<CartItem[]>([]);
  
  let total = $derived(
    items.reduce((sum, item) => sum + item.price * item.quantity, 0)
  );
  
  let itemCount = $derived(
    items.reduce((sum, item) => sum + item.quantity, 0)
  );
  
  return {
    get items() { return items; },
    get total() { return total; },
    get itemCount() { return itemCount; },
    
    add(item: CartItem) {
      const existing = items.find(i => i.id === item.id);
      if (existing) {
        existing.quantity += item.quantity;
      } else {
        items.push({ ...item });
      }
    },
    
    remove(id: string) {
      const index = items.findIndex(i => i.id === id);
      if (index !== -1) {
        items.splice(index, 1);
      }
    },
    
    clear() {
      items = [];
    },
  };
}

interface CartItem {
  id: string;
  name: string;
  price: number;
  quantity: number;
}
```

**src/lib/stores/cart.svelte.test.ts:**

```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { createCart } from './cart.svelte';

describe('Cart Store', () => {
  let cart: ReturnType<typeof createCart>;
  
  beforeEach(() => {
    cart = createCart();
  });

  it('starts empty', () => {
    expect(cart.items).toEqual([]);
    expect(cart.total).toBe(0);
    expect(cart.itemCount).toBe(0);
  });

  it('adds items', () => {
    cart.add({ id: '1', name: 'Widget', price: 10, quantity: 2 });
    
    expect(cart.items).toHaveLength(1);
    expect(cart.total).toBe(20);
    expect(cart.itemCount).toBe(2);
  });

  it('combines duplicate items', () => {
    cart.add({ id: '1', name: 'Widget', price: 10, quantity: 1 });
    cart.add({ id: '1', name: 'Widget', price: 10, quantity: 2 });
    
    expect(cart.items).toHaveLength(1);
    expect(cart.items[0].quantity).toBe(3);
    expect(cart.total).toBe(30);
  });

  it('removes items', () => {
    cart.add({ id: '1', name: 'Widget', price: 10, quantity: 1 });
    cart.add({ id: '2', name: 'Gadget', price: 20, quantity: 1 });
    
    cart.remove('1');
    
    expect(cart.items).toHaveLength(1);
    expect(cart.items[0].name).toBe('Gadget');
  });

  it('clears all items', () => {
    cart.add({ id: '1', name: 'Widget', price: 10, quantity: 1 });
    cart.add({ id: '2', name: 'Gadget', price: 20, quantity: 1 });
    
    cart.clear();
    
    expect(cart.items).toEqual([]);
    expect(cart.total).toBe(0);
  });
});
```

### Testing Context

When testing components that use Svelte's context API:

**src/lib/components/ThemeProvider.svelte:**

```svelte
<script lang="ts" module>
  import { getContext, setContext } from 'svelte';
  
  const THEME_KEY = Symbol('theme');
  
  export interface Theme {
    mode: 'light' | 'dark';
    toggle: () => void;
  }
  
  export function getTheme(): Theme {
    return getContext(THEME_KEY);
  }
</script>

<script lang="ts">
  import type { Snippet } from 'svelte';
  
  interface Props {
    initialMode?: 'light' | 'dark';
    children: Snippet;
  }
  
  let { initialMode = 'light', children }: Props = $props();
  let mode = $state<'light' | 'dark'>(initialMode);
  
  setContext<Theme>(THEME_KEY, {
    get mode() { return mode; },
    toggle() { mode = mode === 'light' ? 'dark' : 'light'; },
  });
</script>

<div data-theme={mode}>
  {@render children()}
</div>
```

**Testing components with context:**

```typescript
import { describe, it, expect } from 'vitest';
import { render } from 'vitest-browser-svelte';
import { page } from 'vitest/browser';
import { createRawSnippet } from 'svelte';
import ThemeProvider from './ThemeProvider.svelte';

describe('Theme Context', () => {
  it('provides theme to children', async () => {
    const children = createRawSnippet(() => ({
      render: () => '<span data-testid="theme-display">Themed content</span>',
    }));
    
    render(ThemeProvider, { children });
    
    await expect
      .element(page.getByTestId('theme-display'))
      .toBeVisible();
  });

  it('starts with initial mode', async () => {
    const children = createRawSnippet(() => ({
      render: () => '<span>Content</span>',
    }));
    
    render(ThemeProvider, { initialMode: 'dark', children });
    
    await expect
      .element(page.locator('[data-theme="dark"]'))
      .toBeVisible();
  });
});
```

---

## Common Issues and Solutions

### Issue 1: "$state is not defined"

**Cause:** Test file not processed by Svelte compiler.

**Solution:** Rename your test file to include `.svelte`:

```bash
mv store.test.ts store.svelte.test.ts
```

### Issue 2: "$derived doesn't update"

**Cause:** Missing `conditions: ['browser']` in config.

**Solution:** Update vite.config.ts:

```typescript
resolve: process.env.VITEST 
  ? { conditions: ['browser'] } 
  : undefined,
```

### Issue 3: "mount(...) is not available on the server"

**Cause:** Svelte thinks it's running on the server.

**Solution:** Ensure browser conditions are set:

```typescript
// vite.config.ts
test: {
  environment: 'jsdom', // or use browser mode
},
resolve: process.env.VITEST 
  ? { conditions: ['browser'] } 
  : undefined,
```

### Issue 4: Effects not running in tests

**Cause:** `$effect` needs component context.

**Solution:** Wrap in `$effect.root()`:

```typescript
test('effect runs', () => {
  const cleanup = $effect.root(() => {
    // Your effect code here
  });
  
  // Test assertions
  
  cleanup(); // Always cleanup!
});
```

### Issue 5: "effect_update_depth_exceeded"

**Cause:** Effect creating infinite loop.

**Solution:** Check for circular dependencies. Use `flushSync()` carefully:

```typescript
const cleanup = $effect.root(() => {
  let count = $state(0);
  
  $effect(() => {
    console.log(count);
    // DON'T modify count here - creates infinite loop!
  });
  
  flushSync();
  count = 1;
  flushSync();
});
cleanup();
```

### Issue 6: Strict mode violation with locators

**Cause:** Multiple elements match the locator.

**Solution:** Make locators more specific or use `.first()`, `.nth()`:

```typescript
// Fails if multiple links
page.getByRole('link', { name: 'Home' });

// Solutions
page.getByRole('link', { name: 'Home' }).first();
page.getByRole('navigation').getByRole('link', { name: 'Home' });
page.getByTestId('nav-home-link');
```

### Issue 7: Test hangs on form submission

**Cause:** SvelteKit's `enhance` action causes form submission to trigger navigation and server requests, which can hang in component tests.

**Solutions:**

```typescript
// PROBLEMATIC - can hang with SvelteKit enhance
it('submits form', async () => {
  render(ContactForm);
  await page.getByRole('button', { name: 'Submit' }).click();
  // Test hangs here waiting for navigation/response
});

// SOLUTION 1: Test validation state directly
it('shows validation errors', async () => {
  render(ContactForm, { 
    errors: { email: 'Email is required' } 
  });
  
  await expect
    .element(page.getByText('Email is required'))
    .toBeInTheDocument();
});

// SOLUTION 2: Use force: true for animated buttons
it('handles submit with animation', async () => {
  const onSubmit = vi.fn();
  render(ContactForm, { onsubmit: onSubmit });
  
  await page.getByRole('button', { name: 'Submit' }).click({ force: true });
  expect(onSubmit).toHaveBeenCalled();
});

// SOLUTION 3: Test form attributes instead of submission
it('has correct form action', async () => {
  render(ContactForm);
  
  await expect
    .element(page.getByRole('form'))
    .toHaveAttribute('action', '/api/contact');
});

// SOLUTION 4: Mock the enhance action
vi.mock('$app/forms', () => ({
  enhance: vi.fn(() => ({ destroy: vi.fn() })),
}));
```

**When to use E2E instead:** If you need to test the full form submission flow with server interaction, use Playwright E2E tests instead of component tests.

### Issue 8: SvelteSet/SvelteMap not reactive in tests

**Cause:** Known issue with reactive collections in jsdom.

**Solution:** Use browser mode, or wrap in `$effect.root()`:

```typescript
const cleanup = $effect.root(() => {
  const set = new SvelteSet<string>();
  // Now reactivity works correctly
});
cleanup();
```

### Issue 9: "global is not defined"

**Cause:** Browser API missing in jsdom.

**Solution A:** Add to setup file:

```typescript
// vitest-setup.ts
if (typeof global === 'undefined') {
  (window as any).global = window;
}
```

**Solution B:** Use browser mode (recommended).

### Issue 10: Recent Svelte versions break tests

**Cause:** Bug in some Svelte versions with Vitest.

**Solution:** Update to latest Svelte (5.33+):

```bash
bun update svelte@latest
```

### Issue 11: Role confusion (textbox vs input)

**Cause:** HTML input elements don't have a role of "input" - they have semantic roles like "textbox", "checkbox", etc.

**Common mistakes and fixes:**

```typescript
// WRONG: "input" is not a valid role
page.getByRole('input', { name: 'Email' });

// CORRECT: Use the semantic role
page.getByRole('textbox', { name: 'Email' });       // <input type="text">
page.getByRole('textbox', { name: 'Email' });       // <input type="email">
page.getByRole('checkbox', { name: 'Remember' });   // <input type="checkbox">
page.getByRole('radio', { name: 'Option 1' });      // <input type="radio">
page.getByRole('searchbox', { name: 'Search' });    // <input type="search">
page.getByRole('spinbutton', { name: 'Quantity' }); // <input type="number">

// WRONG: Looking for link when element has role="button"
// <a href="#" role="button">Submit</a>
page.getByRole('link', { name: 'Submit' });

// CORRECT: Use the actual role attribute
page.getByRole('button', { name: 'Submit' });
```

**Quick reference for input roles:**

| Input Type | ARIA Role |
|------------|-----------|
| `text`, `email`, `tel`, `url` | `textbox` |
| `password` | (no role, use `getByLabelText`) |
| `checkbox` | `checkbox` |
| `radio` | `radio` |
| `number` | `spinbutton` |
| `range` | `slider` |
| `search` | `searchbox` |
| `<select>` | `combobox` |
| `<textarea>` | `textbox` |

**Tip:** Use browser DevTools to inspect the accessibility tree and see actual roles.

---

## Best Practices

### 1. Test Behavior, Not Implementation

```typescript
// Testing implementation
it('sets internal count state to 5', () => {
  const counter = createCounter();
  counter._internalCount = 5; // Accessing internals
  expect(counter._internalCount).toBe(5);
});

// Testing behavior
it('increments count when increment is called', () => {
  const counter = createCounter();
  counter.increment();
  expect(counter.count).toBe(1);
});
```

**Avoid testing implementation details that break when libraries update:**

```typescript
// BRITTLE - breaks when icon library updates (Heroicons v1 -> v2, etc.)
it('renders success icon', () => {
  const { body } = render(StatusIcon, { status: 'success' });
  
  // This SVG path will change when the icon library updates!
  expect(body).toContain('M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z');
});

// ROBUST - tests user-visible behavior
it('indicates success state to users', async () => {
  render(StatusIcon, { status: 'success' });
  
  // Test what users actually see
  await expect
    .element(page.getByRole('img', { name: /success/i }))
    .toBeInTheDocument();
  
  // Test semantic CSS classes (stable)
  await expect
    .element(page.getByTestId('status-icon'))
    .toHaveClass('text-success');
});

// For SSR tests, test semantic structure
it('renders success icon structure', () => {
  const { body } = render(StatusIcon, { status: 'success' });
  
  // These are stable across library updates
  expect(body).toContain('<svg');
  expect(body).toContain('text-success');
  expect(body).toContain('aria-label');
});
```

**What to test vs. avoid:**

| Test | Avoid |
|------|-------|
| Semantic CSS classes (`btn-primary`, `text-success`) | SVG path coordinates |
| ARIA attributes and roles | Internal component IDs |
| User-visible text content | Generated class names |
| Element structure (`<svg>`, `<button>`) | Library-specific markup |

### 2. Use Semantic Queries

```typescript
// Fragile selectors
page.locator('.btn-primary');
page.locator('#submit-btn');

// Semantic queries
page.getByRole('button', { name: 'Submit' });
page.getByLabel('Email address');
```

### 3. Organize Tests by Feature

```
src/lib/
├── features/
│   └── cart/
│       ├── Cart.svelte
│       ├── Cart.svelte.test.ts      # Component tests
│       ├── cart.svelte.ts           # State logic
│       └── cart.svelte.test.ts      # State tests
```

### 4. Keep Tests Independent

```typescript
// Each test creates its own instance
describe('Counter', () => {
  it('test 1', () => {
    const counter = createCounter(); // Fresh instance
    // ...
  });

  it('test 2', () => {
    const counter = createCounter(); // Fresh instance
    // ...
  });
});
```

### 5. Test Edge Cases

```typescript
describe('Cart', () => {
  it('handles empty cart', () => { /* ... */ });
  it('handles single item', () => { /* ... */ });
  it('handles many items', () => { /* ... */ });
  it('handles negative quantities gracefully', () => { /* ... */ });
  it('handles removing non-existent item', () => { /* ... */ });
});
```

### 6. Use Descriptive Test Names

```typescript
// Vague
it('works', () => {});
it('test 1', () => {});

// Descriptive
it('increments count by 1 when increment button is clicked', () => {});
it('displays error message when email is invalid', () => {});
```

### 7. Separate Pure Logic from Runes

```typescript
// Pure logic in regular .ts file (easy to test)
// validation.ts
export function validateEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// Runes in .svelte.ts file
// form.svelte.ts
import { validateEmail } from './validation';

export function createForm() {
  let email = $state('');
  let isValid = $derived(validateEmail(email));
  // ...
}
```

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│                 SVELTE 5 TESTING QUICK REF                  │
├─────────────────────────────────────────────────────────────┤
│ FILE NAMING                                                 │
│   ✓ counter.svelte.test.ts  → Runes work                   │
│   ✗ counter.test.ts         → Runes DON'T work             │
├─────────────────────────────────────────────────────────────┤
│ TESTING $state & $derived                                   │
│   • Just call getters - they work synchronously             │
│   • No flushSync() needed for basic tests                   │
├─────────────────────────────────────────────────────────────┤
│ TESTING $effect                                             │
│   const cleanup = $effect.root(() => {                      │
│     let count = $state(0);                                  │
│     $effect(() => { /* ... */ });                           │
│     flushSync();  // Run pending effects                    │
│   });                                                       │
│   cleanup();  // Always cleanup!                            │
├─────────────────────────────────────────────────────────────┤
│ BROWSER MODE LOCATORS                                       │
│   page.getByRole('button', { name: 'Submit' })              │
│   page.getByLabel('Email')                                  │
│   page.getByText('Welcome')                                 │
│   page.getByTestId('my-element')                            │
├─────────────────────────────────────────────────────────────┤
│ ASSERTIONS                                                  │
│   await expect.element(locator).toBeVisible()               │
│   await expect.element(locator).toHaveTextContent('...')    │
│   await expect.element(locator).toHaveValue('...')          │
├─────────────────────────────────────────────────────────────┤
│ CONFIG ESSENTIALS (vite.config.ts)                          │
│   resolve: process.env.VITEST                               │
│     ? { conditions: ['browser'] }                           │
│     : undefined                                             │
└─────────────────────────────────────────────────────────────┘
```

---

**Previous:** [26. Testing Setup](./26-TestingSetup.md)
