# 10. Context API

## Basic Context

```svelte
<!-- Parent.svelte -->
<script>
  import { setContext } from 'svelte';

  let theme = $state<'light' | 'dark'>('light');

  // Pass reactive value via getter function
  setContext('theme', {
    get current() { return theme; },
    toggle() { theme = theme === 'light' ? 'dark' : 'light'; }
  });
</script>

<slot />

<!-- Child.svelte (any depth) -->
<script>
  import { getContext } from 'svelte';

  const theme = getContext<{
    current: 'light' | 'dark';
    toggle: () => void;
  }>('theme');
</script>

<button onclick={theme.toggle}>
  Current: {theme.current}
</button>
```

## Type-Safe Context Pattern

```typescript
// theme-context.svelte.ts
import { setContext, getContext } from 'svelte';

// Use Symbol for truly private keys
const THEME_KEY = Symbol('theme');

export interface ThemeContext {
	readonly theme: 'light' | 'dark';
	readonly isDark: boolean;
	toggle(): void;
	set(theme: 'light' | 'dark'): void;
}

export function createThemeContext(initial: 'light' | 'dark' = 'light') {
	let theme = $state(initial);

	const context: ThemeContext = {
		get theme() {
			return theme;
		},
		get isDark() {
			return theme === 'dark';
		},
		toggle() {
			theme = theme === 'light' ? 'dark' : 'light';
		},
		set(value) {
			theme = value;
		},
	};

	setContext(THEME_KEY, context);
	return context;
}

export function getThemeContext(): ThemeContext {
	const context = getContext<ThemeContext>(THEME_KEY);
	if (!context) {
		throw new Error('ThemeContext not found. Did you forget to use createThemeContext()?');
	}
	return context;
}
```

```svelte
<!-- App.svelte -->
<script>
  import { createThemeContext } from './theme-context.svelte.ts';

  // Initialize at top of tree
  const theme = createThemeContext('dark');
</script>

<div class="app" class:dark={theme.isDark}>
  <slot />
</div>

<!-- AnyChild.svelte -->
<script>
  import { getThemeContext } from './theme-context.svelte.ts';

  const { theme, toggle } = getThemeContext();
</script>

<button onclick={toggle}>Theme: {theme}</button>
```

## createContext Helper (Svelte 5.40+)

```svelte
<script lang="ts">
  import { createContext } from 'svelte';

  interface User {
    name: string;
    email: string;
  }

  // Returns [get, set] pair
  const [getUser, setUser] = createContext<User>();

  // In parent
  setUser({ name: 'Alice', email: 'alice@example.com' });
</script>

<!-- In child -->
<script>
  import { getUser } from './context';

  const user = getUser();
</script>
```

## Context with Snippets

```svelte
<!-- FormContext.svelte -->
<script lang="ts">
  import { setContext } from 'svelte';
  import type { Snippet } from 'svelte';

  interface Props {
    children: Snippet;
    onSubmit: (data: FormData) => void;
  }

  let { children, onSubmit }: Props = $props();

  let errors = $state<Record<string, string>>({});
  let touched = $state<Set<string>>(new Set());

  setContext('form', {
    get errors() { return errors; },
    get touched() { return touched; },
    setError(field: string, message: string) {
      errors[field] = message;
    },
    clearError(field: string) {
      delete errors[field];
    },
    touch(field: string) {
      touched.add(field);
    }
  });

  function handleSubmit(e: SubmitEvent) {
    e.preventDefault();
    const data = new FormData(e.currentTarget as HTMLFormElement);
    onSubmit(data);
  }
</script>

<form onsubmit={handleSubmit}>
  {@render children()}
</form>

<!-- FormInput.svelte -->
<script lang="ts">
  import { getContext } from 'svelte';

  interface Props {
    name: string;
    label: string;
    type?: string;
  }

  let { name, label, type = 'text' }: Props = $props();

  const form = getContext<{
    errors: Record<string, string>;
    touched: Set<string>;
    touch: (field: string) => void;
  }>('form');

  const error = $derived(
    form.touched.has(name) ? form.errors[name] : undefined
  );
</script>

<div class="field" class:error={!!error}>
  <label for={name}>{label}</label>
  <input
    {type}
    {name}
    id={name}
    onblur={() => form.touch(name)}
  />
  {#if error}
    <span class="error-message">{error}</span>
  {/if}
</div>
```

## hasContext Check

```svelte
<script>
	import { hasContext, getContext } from 'svelte';

	// Check if context exists before using
	const hasTheme = hasContext('theme');

	const theme = hasTheme ? getContext('theme') : { current: 'light' }; // Fallback
</script>
```

---

**Next:** [11. Reactive Collections](./11-ReactiveCollections.md)
