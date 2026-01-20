/**
 * Toast Store
 * ===========
 * Simple notification system for GHOSTNET.
 */

export type ToastType = 'info' | 'success' | 'warning' | 'error';

export interface Toast {
	id: string;
	message: string;
	type: ToastType;
	duration: number;
}

// Singleton state
let toasts = $state<Toast[]>([]);

/**
 * Add a toast notification
 */
export function addToast(
	message: string,
	type: ToastType = 'info',
	duration: number = 3000
): string {
	const id = crypto.randomUUID();

	toasts = [...toasts, { id, message, type, duration }];

	// Auto-remove after duration
	if (duration > 0) {
		setTimeout(() => {
			removeToast(id);
		}, duration);
	}

	return id;
}

/**
 * Remove a toast by ID
 */
export function removeToast(id: string): void {
	toasts = toasts.filter((t) => t.id !== id);
}

/**
 * Clear all toasts
 */
export function clearToasts(): void {
	toasts = [];
}

/**
 * Get the toast store
 */
export function getToasts() {
	return {
		get list() {
			return toasts;
		},
		add: addToast,
		remove: removeToast,
		clear: clearToasts,

		// Convenience methods
		info: (message: string, duration?: number) => addToast(message, 'info', duration),
		success: (message: string, duration?: number) => addToast(message, 'success', duration),
		warning: (message: string, duration?: number) => addToast(message, 'warning', duration),
		error: (message: string, duration?: number) => addToast(message, 'error', duration),
	};
}
