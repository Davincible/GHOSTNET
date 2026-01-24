# 9. State Management Patterns

## Pattern 1: Simple Module State

```typescript
// counter.svelte.ts
let count = $state(0);

export function getCount() {
	return count;
}

export function increment() {
	count++;
}

export function decrement() {
	count--;
}

export function reset() {
	count = 0;
}
```

```svelte
<!-- Usage -->
<script>
	import { getCount, increment, reset } from './counter.svelte.ts';
</script>

<p>Count: {getCount()}</p>
<button onclick={increment}>+</button>
<button onclick={reset}>Reset</button>
```

## Pattern 2: Object Store (Recommended)

```typescript
// user-store.svelte.ts
interface User {
	id: string;
	name: string;
	email: string;
	role: 'admin' | 'user';
}

function createUserStore() {
	let user = $state<User | null>(null);
	let loading = $state(false);
	let error = $state<string | null>(null);

	return {
		// Getters (reactive when used in components)
		get user() {
			return user;
		},
		get loading() {
			return loading;
		},
		get error() {
			return error;
		},
		get isLoggedIn() {
			return user !== null;
		},
		get isAdmin() {
			return user?.role === 'admin';
		},

		// Actions
		async login(email: string, password: string) {
			loading = true;
			error = null;

			try {
				const response = await fetch('/api/login', {
					method: 'POST',
					body: JSON.stringify({ email, password }),
				});

				if (!response.ok) throw new Error('Login failed');

				user = await response.json();
			} catch (e) {
				error = e instanceof Error ? e.message : 'Unknown error';
				throw e;
			} finally {
				loading = false;
			}
		},

		logout() {
			user = null;
		},

		updateProfile(updates: Partial<User>) {
			if (user) {
				user = { ...user, ...updates };
			}
		},
	};
}

export const userStore = createUserStore();
```

## Pattern 3: Class-Based Store

```typescript
// todo-store.svelte.ts
interface Todo {
	id: string;
	text: string;
	done: boolean;
}

export class TodoStore {
	items = $state<Todo[]>([]);
	filter = $state<'all' | 'active' | 'completed'>('all');

	// Derived state as getters
	get filtered() {
		switch (this.filter) {
			case 'active':
				return this.items.filter((t) => !t.done);
			case 'completed':
				return this.items.filter((t) => t.done);
			default:
				return this.items;
		}
	}

	get remaining() {
		return this.items.filter((t) => !t.done).length;
	}

	add(text: string) {
		this.items.push({
			id: crypto.randomUUID(),
			text,
			done: false,
		});
	}

	toggle(id: string) {
		const todo = this.items.find((t) => t.id === id);
		if (todo) todo.done = !todo.done;
	}

	remove(id: string) {
		this.items = this.items.filter((t) => t.id !== id);
	}

	clearCompleted() {
		this.items = this.items.filter((t) => !t.done);
	}
}

export const todoStore = new TodoStore();
```

## Pattern 4: Factory with Private State

```typescript
// auth.svelte.ts
type AuthState = 'idle' | 'loading' | 'authenticated' | 'error';

export function createAuth() {
	// Private state (not directly accessible)
	let state = $state<AuthState>('idle');
	let token = $state<string | null>(null);
	let user = $state<User | null>(null);
	let errorMessage = $state<string | null>(null);

	// Computed
	const isAuthenticated = $derived(state === 'authenticated' && !!token);

	async function login(credentials: Credentials) {
		state = 'loading';
		errorMessage = null;

		try {
			const response = await api.login(credentials);
			token = response.token;
			user = response.user;
			state = 'authenticated';
		} catch (e) {
			errorMessage = e.message;
			state = 'error';
		}
	}

	function logout() {
		token = null;
		user = null;
		state = 'idle';
	}

	// Public API
	return {
		get state() {
			return state;
		},
		get user() {
			return user;
		},
		get error() {
			return errorMessage;
		},
		get isAuthenticated() {
			return isAuthenticated;
		},
		login,
		logout,
	};
}

export const auth = createAuth();
```

## SSR Warning: Global State

```typescript
// ❌ DANGER: This state is shared across ALL server requests!
export const globalState = $state({ user: null });

// If User A logs in, User B might see User A's data!
```

**Solutions:**

```typescript
// ✅ Solution 1: Use context for per-request state
// See Context API section

// ✅ Solution 2: Create fresh state in load functions
export function load() {
	return {
		user: getCurrentUser(), // Fresh per request
	};
}

// ✅ Solution 3: Client-only stores with browser check
import { browser } from '$app/environment';

let user = $state<User | null>(null);

export function setUser(newUser: User | null) {
	if (browser) {
		user = newUser;
	}
}
```

---

**Next:** [10. Context API](./10-ContextAPI.md)
