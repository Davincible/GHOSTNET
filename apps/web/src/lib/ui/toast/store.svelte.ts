/**
 * Toast Store
 * ===========
 * Simple notification system for GHOSTNET.
 *
 * Uses Svelte context for SSR safety - state is isolated per request.
 */

import { getContext, setContext } from 'svelte';

// ════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════

export type ToastType = 'info' | 'success' | 'warning' | 'error';

export interface Toast {
	id: string;
	message: string;
	type: ToastType;
	duration: number;
}

export interface ToastStore {
	/** Current list of toasts */
	readonly list: Toast[];
	/** Add a toast, returns the ID */
	add: (message: string, type?: ToastType, duration?: number) => string;
	/** Remove a toast by ID */
	remove: (id: string) => void;
	/** Clear all toasts */
	clear: () => void;
	/** Convenience: info toast */
	info: (message: string, duration?: number) => string;
	/** Convenience: success toast */
	success: (message: string, duration?: number) => string;
	/** Convenience: warning toast */
	warning: (message: string, duration?: number) => string;
	/** Convenience: error toast */
	error: (message: string, duration?: number) => string;
}

// ════════════════════════════════════════════════════════════════
// CONTEXT KEY
// ════════════════════════════════════════════════════════════════

const TOAST_CONTEXT_KEY = Symbol('toast-store');

// ════════════════════════════════════════════════════════════════
// STORE FACTORY
// ════════════════════════════════════════════════════════════════

/**
 * Create a new toast store instance.
 * This should be called once per request/page lifecycle.
 */
export function createToastStore(): ToastStore {
	let toasts = $state<Toast[]>([]);

	function add(message: string, type: ToastType = 'info', duration: number = 3000): string {
		const id = crypto.randomUUID();

		toasts = [...toasts, { id, message, type, duration }];

		// Auto-remove after duration
		if (duration > 0) {
			setTimeout(() => {
				remove(id);
			}, duration);
		}

		return id;
	}

	function remove(id: string): void {
		toasts = toasts.filter((t) => t.id !== id);
	}

	function clear(): void {
		toasts = [];
	}

	return {
		get list() {
			return toasts;
		},
		add,
		remove,
		clear,
		// Convenience methods
		info: (message: string, duration?: number) => add(message, 'info', duration),
		success: (message: string, duration?: number) => add(message, 'success', duration),
		warning: (message: string, duration?: number) => add(message, 'warning', duration),
		error: (message: string, duration?: number) => add(message, 'error', duration),
	};
}

// ════════════════════════════════════════════════════════════════
// CONTEXT HELPERS
// ════════════════════════════════════════════════════════════════

/**
 * Initialize the toast store and set it in context.
 * Call this once in your root +layout.svelte
 */
export function initializeToasts(): ToastStore {
	const store = createToastStore();
	setContext(TOAST_CONTEXT_KEY, store);
	return store;
}

/**
 * Get the toast store from context.
 * Must be called from a component that is a descendant of the layout
 * where initializeToasts() was called.
 */
export function getToasts(): ToastStore {
	const store = getContext<ToastStore>(TOAST_CONTEXT_KEY);
	if (!store) {
		throw new Error(
			'Toast store not found in context. Make sure initializeToasts() was called in +layout.svelte'
		);
	}
	return store;
}
