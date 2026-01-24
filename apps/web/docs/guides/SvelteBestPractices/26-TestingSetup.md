# 26. Testing Setup

> A comprehensive guide to configuring Vitest for Svelte 5 applications with runes support.

## The Problem: Why Runes Don't Work in Tests

If you've tried to test Svelte 5 code that uses runes (`$state`, `$derived`, `$effect`), you've likely encountered:

```
Error: $state is not defined
```

Or more subtle issues where `$derived` values don't update:

```typescript
// This test FAILS - $derived doesn't update!
import { test, expect } from 'vitest';
import { myStore } from './store.svelte';

test('derived updates', () => {
	const store = myStore();
	store.count = 5;
	expect(store.doubled).toBe(10); // ❌ Still returns 0!
});
```

**Why does this happen?**

Svelte 5 runes are **compile-time transformations**, not runtime features. The Svelte compiler transforms runes like `$state(0)` into reactive signal code. Without proper compilation, runes are just undefined variables.

---

## Understanding Svelte 5's Compile-Time Magic

### How Runes Work

When you write:

```svelte
<script>
	let count = $state(0);
	let doubled = $derived(count * 2);
</script>
```

The Svelte compiler transforms this into something like:

```javascript
import { source, derived } from 'svelte/internal/client';

let count = source(0);
let doubled = derived(() => count.v * 2);
```

### The Testing Challenge

In a test environment:

1. **Node.js doesn't understand runes** - They're syntax that only the Svelte compiler recognizes
2. **jsdom simulates browsers** - But it's not a real browser, so some APIs are missing or behave differently
3. **Reactivity requires context** - `$effect` needs a component context to work properly

### The Solution

Tests need to be processed by the Svelte compiler. This happens automatically when:

1. Your **test filename includes `.svelte`** (e.g., `counter.svelte.test.ts`)
2. Your **Vitest config has the Svelte plugin** configured correctly
3. You're using **browser mode** OR have **`conditions: ['browser']`** set

---

## Testing Approaches Overview

| Feature              | jsdom Approach            | Browser Mode            |
| -------------------- | ------------------------- | ----------------------- |
| **Speed**            | Fast                      | Very Fast               |
| **Accuracy**         | Simulated                 | Real Browser            |
| **Setup Complexity** | Low                       | Medium                  |
| **Runes Support**    | Partial (with config)     | Full                    |
| **Browser APIs**     | Mocked                    | Real                    |
| **Recommended For**  | Simple tests, legacy      | New projects, accuracy  |
| **Package**          | `@testing-library/svelte` | `vitest-browser-svelte` |

### Which Should You Choose?

**Choose jsdom if:**

- You have an existing test suite
- You need quick setup
- Your tests don't use complex browser APIs
- You're testing mostly logic, not DOM interactions

**Choose Browser Mode if:**

- Starting a new project
- You need accurate browser behavior
- You're testing Svelte 5 runes extensively
- You want to avoid mocking browser APIs
- You need pixel-perfect DOM testing

---

## Client-Server Alignment Strategy

A major testing pitfall is when server unit tests pass but production fails due to client-server mismatches. This happens when tests use heavy mocking that hides real integration issues.

### The Problem with Heavy Mocking

```typescript
// BRITTLE: Heavy mocking hides client-server mismatches
describe('User Registration - WRONG WAY', () => {
	it('should register user', async () => {
		// This mock doesn't test real FormData behavior
		const mockRequest = {
			formData: vi.fn().mockResolvedValue({
				get: vi.fn().mockReturnValue('test@example.com'),
			}),
		};

		const result = await registerUser(mockRequest);
		expect(result.success).toBe(true);
		// Passes! But what if client sends 'email' and server expects 'user_email'?
	});
});
```

### The Solution: Real Objects

```typescript
// ROBUST: Real FormData catches actual mismatches
describe('User Registration - CORRECT WAY', () => {
	it('should register user with real FormData', async () => {
		// Real FormData - catches field name mismatches
		const formData = new FormData();
		formData.append('email', 'test@example.com'); // Must match server expectations!
		formData.append('password', 'secure123');

		// Real Request object - catches header/method issues
		const request = new Request('http://localhost/register', {
			method: 'POST',
			body: formData,
		});

		// Only mock external services (database), not data structures
		vi.mocked(database.createUser).mockResolvedValue({
			id: '123',
			email: 'test@example.com',
		});

		const result = await registerUser(request);
		expect(result.success).toBe(true);
	});
});
```

### The Four-Layer Testing Approach

1. **Shared Validation Logic** - Use the same validation functions on client and server
2. **Real FormData/Request Objects** - Server tests use real web APIs, not mocks
3. **TypeScript Contracts** - Shared interfaces catch mismatches at compile time
4. **E2E Tests** - Final safety net for complete integration validation

### What to Mock vs. Keep Real

**Mock these (external dependencies):**

```typescript
// Database operations
vi.mock('$lib/server/database', () => ({
	users: {
		create: vi.fn(),
		findByEmail: vi.fn(),
	},
}));

// External APIs
vi.mock('$lib/server/email', () => ({
	sendWelcomeEmail: vi.fn(),
}));
```

**Keep these real (data contracts):**

```typescript
// Real FormData objects
const formData = new FormData();
formData.append('email', 'test@example.com');

// Real Request/Response objects
const request = new Request('http://localhost/api/users', {
	method: 'POST',
	body: formData,
});

// Real validation functions
const result = validateUserInput(formData);
```

---

## Critical: File Naming Convention

**For runes to work, your test files MUST include `.svelte` in the filename:**

```
✅ counter.svelte.test.ts    → Runes work
✅ store.svelte.spec.ts      → Runes work
❌ counter.test.ts           → Runes DON'T work
❌ store.spec.ts             → Runes DON'T work
```

This tells the build system to process these files through the Svelte compiler.

---

## Approach 1: Vitest + jsdom (Quick Setup)

This is the current default when creating a SvelteKit project with Vitest.

### Installation

```bash
# If using sv CLI
bunx sv create my-app
# Select: vitest (unit testing)

# Or manual installation
bun add -D vitest jsdom @testing-library/svelte @testing-library/jest-dom
```

### Configuration

**vite.config.ts:**

```typescript
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vitest/config';

export default defineConfig({
	plugins: [sveltekit()],
	test: {
		// Use jsdom to simulate browser environment
		environment: 'jsdom',

		// Include test files (note the .svelte in the pattern!)
		include: ['src/**/*.svelte.{test,spec}.{js,ts}'],

		// Setup file for jest-dom matchers
		setupFiles: ['./vitest-setup.ts'],
	},

	// CRITICAL: Tell Vitest to use browser entry points
	// This is what makes runes work!
	resolve: process.env.VITEST ? { conditions: ['browser'] } : undefined,
});
```

**vitest-setup.ts:**

```typescript
import '@testing-library/jest-dom/vitest';
```

**tsconfig.json (add types):**

```json
{
	"compilerOptions": {
		"types": ["@testing-library/jest-dom"]
	}
}
```

### Basic Test Example

**src/lib/counter.svelte.ts:**

```typescript
export function createCounter(initial = 0) {
	let count = $state(initial);

	return {
		get count() {
			return count;
		},
		get doubled() {
			return count * 2;
		},
		increment() {
			count++;
		},
		decrement() {
			count--;
		},
		reset() {
			count = initial;
		},
	};
}
```

**src/lib/counter.svelte.test.ts:**

```typescript
import { describe, it, expect } from 'vitest';
import { createCounter } from './counter.svelte';

describe('createCounter', () => {
	it('initializes with default value', () => {
		const counter = createCounter();
		expect(counter.count).toBe(0);
	});

	it('increments count', () => {
		const counter = createCounter(0);
		counter.increment();
		expect(counter.count).toBe(1);
	});

	it('computes derived values', () => {
		const counter = createCounter(5);
		expect(counter.doubled).toBe(10);

		counter.increment();
		expect(counter.doubled).toBe(12);
	});
});
```

### Component Testing with Testing Library

**src/lib/components/Button.svelte.test.ts:**

```typescript
import { render, screen, fireEvent } from '@testing-library/svelte';
import { describe, it, expect, vi } from 'vitest';
import Button from './Button.svelte';

describe('Button', () => {
	it('renders children', () => {
		render(Button, {
			props: { children: () => 'Click me' },
		});

		expect(screen.getByRole('button')).toHaveTextContent('Click me');
	});

	it('calls onclick when clicked', async () => {
		const handleClick = vi.fn();

		render(Button, {
			props: {
				onclick: handleClick,
				children: () => 'Click me',
			},
		});

		await fireEvent.click(screen.getByRole('button'));
		expect(handleClick).toHaveBeenCalledOnce();
	});

	it('can be disabled', () => {
		render(Button, {
			props: {
				disabled: true,
				children: () => 'Disabled',
			},
		});

		expect(screen.getByRole('button')).toBeDisabled();
	});
});
```

---

## Approach 2: Vitest Browser Mode (Recommended)

Browser Mode runs tests in a real browser using Playwright, providing the most accurate testing environment for Svelte 5.

### Why Browser Mode?

1. **Real Browser Environment** - No mocking needed for browser APIs
2. **Full Runes Support** - `$state`, `$derived`, `$effect` work as expected
3. **Accurate DOM Testing** - Real CSS, real layout, real events
4. **Auto-Retry Locators** - Built-in waiting for async updates
5. **Fast Execution** - Despite using real browsers, tests run quickly

### Installation

```bash
# Install browser mode dependencies
bun add -D @vitest/browser-playwright vitest-browser-svelte playwright

# Remove jsdom-based testing (optional but recommended)
bun remove @testing-library/svelte @testing-library/jest-dom jsdom

# Install Playwright browsers
bunx playwright install chromium
```

### Configuration

**vite.config.ts (Multi-Project Setup):**

```typescript
import { sveltekit } from '@sveltejs/kit/vite';
import { playwright } from '@vitest/browser-playwright';
import { defineConfig } from 'vitest/config';

export default defineConfig({
	plugins: [sveltekit()],
	test: {
		projects: [
			// Client-side tests (Browser Mode)
			{
				extends: true,
				test: {
					name: 'client',
					browser: {
						enabled: true,
						provider: playwright(),
						instances: [{ browser: 'chromium' }],
					},
					include: ['src/**/*.svelte.{test,spec}.{js,ts}'],
					setupFiles: ['./src/vitest-setup-client.ts'],
				},
			},

			// Server-side tests (Node)
			{
				extends: true,
				test: {
					name: 'server',
					environment: 'node',
					include: ['src/**/*.server.{test,spec}.{js,ts}'],
				},
			},

			// SSR tests
			{
				extends: true,
				test: {
					name: 'ssr',
					environment: 'node',
					include: ['src/**/*.ssr.{test,spec}.{js,ts}'],
				},
			},
		],
	},
});
```

**src/vitest-setup-client.ts:**

```typescript
/// <reference types="vitest-browser-svelte" />
import 'vitest-browser-svelte';
```

**tsconfig.json:**

```json
{
	"compilerOptions": {
		"types": ["vitest-browser-svelte"]
	}
}
```

### Basic Test Example

**src/lib/counter.svelte.test.ts:**

```typescript
import { describe, it, expect } from 'vitest';
import { render } from 'vitest-browser-svelte';
import { page } from 'vitest/browser';
import Counter from './Counter.svelte';

describe('Counter Component', () => {
	it('renders with initial count', async () => {
		render(Counter, { initialCount: 5 });

		await expect.element(page.getByText('Count: 5')).toBeVisible();
	});

	it('increments on button click', async () => {
		render(Counter, { initialCount: 0 });

		const button = page.getByRole('button', { name: 'Increment' });
		await button.click();

		await expect.element(page.getByText('Count: 1')).toBeVisible();
	});

	it('shows doubled value', async () => {
		render(Counter, { initialCount: 3 });

		await expect.element(page.getByText('Doubled: 6')).toBeVisible();
	});
});
```

### Server Testing with Real FormData/Request

For the "server" project in your multi-project setup, test API routes using real web objects:

**src/routes/api/register/+server.test.ts:**

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { POST } from './+server';
import * as db from '$lib/server/database';

// Mock only external services
vi.mock('$lib/server/database');

describe('POST /api/register', () => {
	beforeEach(() => {
		vi.clearAllMocks();
	});

	it('registers user with valid data', async () => {
		// Real FormData - catches field name mismatches
		const formData = new FormData();
		formData.append('email', 'user@example.com');
		formData.append('password', 'securePassword123');

		// Real Request object
		const request = new Request('http://localhost/api/register', {
			method: 'POST',
			body: formData,
		});

		vi.mocked(db.createUser).mockResolvedValue({
			id: '123',
			email: 'user@example.com',
		});

		const response = await POST({ request } as any);

		expect(response.status).toBe(201);
		expect(db.createUser).toHaveBeenCalledWith({
			email: 'user@example.com',
			password: expect.any(String), // Hashed password
		});
	});

	it('rejects invalid email', async () => {
		const formData = new FormData();
		formData.append('email', 'not-an-email');
		formData.append('password', 'securePassword123');

		const request = new Request('http://localhost/api/register', {
			method: 'POST',
			body: formData,
		});

		const response = await POST({ request } as any);

		expect(response.status).toBe(400);
		const data = await response.json();
		expect(data.errors.email).toBeDefined();
	});

	it('handles JSON body', async () => {
		const request = new Request('http://localhost/api/register', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				email: 'user@example.com',
				password: 'securePassword123',
			}),
		});

		vi.mocked(db.createUser).mockResolvedValue({
			id: '123',
			email: 'user@example.com',
		});

		const response = await POST({ request } as any);
		expect(response.status).toBe(201);
	});
});
```

---

### Key Differences from Testing Library

| Testing Library                 | Browser Mode                                  |
| ------------------------------- | --------------------------------------------- |
| `screen.getByRole()`            | `page.getByRole()`                            |
| `fireEvent.click()`             | `await button.click()`                        |
| `expect(element).toBeVisible()` | `await expect.element(locator).toBeVisible()` |
| Requires `act()` for updates    | Auto-retries built-in                         |
| `render()` returns `container`  | `render()` returns screen with locators       |

### Locator Best Practices

```typescript
// BEST: Semantic queries
page.getByRole('button', { name: 'Submit' });
page.getByLabel('Email address');
page.getByRole('heading', { level: 1 });

// GOOD: Text content
page.getByText('Welcome back');
page.getByPlaceholder('Enter your email');

// FALLBACK: Test IDs (when semantics aren't enough)
page.getByTestId('submit-button');

// AVOID: CSS selectors
page.locator('.btn-primary'); // Brittle!
```

### Handling Multiple Elements

```typescript
// Fails with "strict mode violation" if multiple matches
page.getByRole('link', { name: 'Home' });

// Use .first(), .nth(), .last()
page.getByRole('link', { name: 'Home' }).first();
page.getByRole('listitem').nth(2);
page.getByRole('button').last();
```

---

## Foundation First: Planning Tests with `it.skip`

A strategic approach to test planning: start with a complete test structure using `describe` and `it.skip`, then implement tests incrementally.

### Why Foundation First?

- **Complete picture** - See all requirements upfront before writing code
- **Incremental progress** - Remove `.skip` as you implement features
- **No forgotten tests** - Edge cases are planned from the start
- **Team alignment** - Everyone sees the testing scope
- **Flexible coverage** - Implement tests as needed, not for arbitrary metrics

### Example Structure

```typescript
describe('TodoManager Component', () => {
	describe('Initial Rendering', () => {
		it('should render empty state', async () => {
			render(TodoManager);
			await expect.element(page.getByText('No todos yet')).toBeInTheDocument();
		});

		it.skip('should render with initial todos', async () => {
			// TODO: Test with pre-populated data
		});
	});

	describe('User Interactions', () => {
		it('should add new todo', async () => {
			render(TodoManager);
			await page.getByLabel('New todo').fill('Buy groceries');
			await page.getByRole('button', { name: 'Add' }).click();
			await expect.element(page.getByText('Buy groceries')).toBeInTheDocument();
		});

		it.skip('should edit existing todo', async () => {
			// TODO: Test inline editing
		});

		it.skip('should delete todo', async () => {
			// TODO: Test deletion flow
		});
	});

	describe('Edge Cases', () => {
		it.skip('should handle empty input gracefully', async () => {
			// TODO: Test validation
		});

		it.skip('should handle very long todo text', async () => {
			// TODO: Test text truncation
		});
	});

	describe('Accessibility', () => {
		it.skip('should support keyboard navigation', async () => {
			// TODO: Test tab order and shortcuts
		});
	});
});
```

### Best Practices

1. **Don't chase 100% coverage** - Write tests that provide value
2. **Start with happy paths** - Implement core functionality tests first
3. **Add edge cases as discovered** - Let bugs guide your `.skip` list
4. **Review skipped tests regularly** - They're your testing roadmap

---

## CI/CD Configuration

### GitHub Actions with Browser Mode

**.github/workflows/test.yml:**

```yaml
name: Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest

    # Use Playwright's official Docker image for faster CI
    container:
      image: mcr.microsoft.com/playwright:v1.52.0-noble
      options: --user 1001

    steps:
      - uses: actions/checkout@v4

      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest

      - name: Install dependencies
        run: bun install

      - name: Run unit tests
        run: bun test:unit

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        if: always()
        with:
          files: ./coverage/lcov.info

  e2e-tests:
    name: E2E Tests
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest

      - name: Install dependencies
        run: bun install

      - name: Install Playwright browsers
        run: bunx playwright install --with-deps chromium

      - name: Run E2E tests
        run: bun test:e2e
```

### Package.json Scripts

```json
{
	"scripts": {
		"test": "vitest",
		"test:unit": "vitest run",
		"test:unit:watch": "vitest",
		"test:unit:ui": "vitest --ui",
		"test:unit:coverage": "vitest run --coverage",
		"test:e2e": "playwright test",
		"test:e2e:ui": "playwright test --ui"
	}
}
```

---

## Migration Guide

### From @testing-library/svelte to vitest-browser-svelte

**Step 1: Update dependencies**

```bash
# Remove old dependencies
bun remove @testing-library/svelte @testing-library/jest-dom jsdom

# Add new dependencies
bun add -D @vitest/browser-playwright vitest-browser-svelte playwright

# Install Playwright browsers
bunx playwright install chromium
```

**Step 2: Update vite.config.ts**

```typescript
// Before
export default defineConfig({
	plugins: [sveltekit()],
	test: {
		environment: 'jsdom',
		setupFiles: ['./vitest-setup.ts'],
	},
});

// After
import { playwright } from '@vitest/browser-playwright';

export default defineConfig({
	plugins: [sveltekit()],
	test: {
		browser: {
			enabled: true,
			provider: playwright(),
			instances: [{ browser: 'chromium' }],
		},
		include: ['src/**/*.svelte.{test,spec}.{js,ts}'],
		setupFiles: ['vitest-browser-svelte'],
	},
});
```

**Step 3: Update imports in test files**

```typescript
// Before
import { render, screen, fireEvent } from '@testing-library/svelte';

// After
import { render } from 'vitest-browser-svelte';
import { page } from 'vitest/browser';
```

**Step 4: Update test patterns**

```typescript
// Before
const { getByRole, getByText } = render(Component);
await fireEvent.click(getByRole('button'));
expect(getByText('Clicked')).toBeInTheDocument();

// After
render(Component);
await page.getByRole('button').click();
await expect.element(page.getByText('Clicked')).toBeVisible();
```

**Step 5: Remove act() calls**

```typescript
// Before - needed act() for updates
import { act } from '@testing-library/svelte';
await act(() => {
	/* update state */
});

// After - locators auto-retry
await page.getByText('Updated').click();
await expect.element(page.getByText('Result')).toBeVisible();
```

---

## Version Compatibility

| Package                 | Minimum Version | Notes                                   |
| ----------------------- | --------------- | --------------------------------------- |
| Svelte                  | 5.x             | Runes require Svelte 5                  |
| Vitest                  | 4.0.0           | Required for vitest-browser-svelte 1.0+ |
| vitest-browser-svelte   | 1.0.0           | Stable release                          |
| Playwright              | 1.40+           | For browser testing                     |
| @testing-library/svelte | 5.0.0           | For Svelte 5 support                    |

---

## Resources

### Official Documentation

- [Svelte Testing Docs](https://svelte.dev/docs/svelte/testing)
- [Vitest Documentation](https://vitest.dev/)
- [Vitest Browser Mode](https://vitest.dev/guide/browser/)
- [vitest-browser-svelte](https://github.com/vitest-dev/vitest-browser-svelte)

### Community Resources

- [Sveltest.dev](https://sveltest.dev/) - Comprehensive testing patterns guide
- [Scott Spence's Migration Guide](https://scottspence.com/posts/migrating-from-testing-library-svelte-to-vitest-browser-svelte)

---

**Next:** [27. Testing Patterns](./27-TestingPatterns.md)
