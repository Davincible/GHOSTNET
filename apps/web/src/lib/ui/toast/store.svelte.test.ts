/**
 * Toast Store Tests
 * =================
 * Tests for the notification system with timer-based auto-removal.
 *
 * CRITICAL: File must have .svelte.test.ts extension for runes to work!
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { createToastStore, type ToastStore, type ToastType } from './store.svelte';

// ============================================================================
// MOCKS
// ============================================================================

// Mock crypto.randomUUID for deterministic IDs in tests
let uuidCounter = 0;
vi.stubGlobal('crypto', {
	randomUUID: () => `test-uuid-${++uuidCounter}`,
});

// ============================================================================
// TESTS
// ============================================================================

describe('createToastStore', () => {
	let store: ToastStore;

	beforeEach(() => {
		vi.useFakeTimers();
		uuidCounter = 0;
		store = createToastStore();
	});

	afterEach(() => {
		vi.useRealTimers();
		vi.clearAllMocks();
	});

	describe('initial state', () => {
		it('starts with empty toast list', () => {
			expect(store.list).toEqual([]);
		});
	});

	describe('add', () => {
		it('adds toast with generated ID', () => {
			const id = store.add('Test message');

			expect(id).toBe('test-uuid-1');
			expect(store.list).toHaveLength(1);
			expect(store.list[0]).toEqual({
				id: 'test-uuid-1',
				message: 'Test message',
				type: 'info',
				duration: 3000,
			});
		});

		it('uses default type of info', () => {
			store.add('Test message');

			expect(store.list[0].type).toBe('info');
		});

		it('uses default duration of 3000ms', () => {
			store.add('Test message');

			expect(store.list[0].duration).toBe(3000);
		});

		it('accepts custom type', () => {
			store.add('Error!', 'error');

			expect(store.list[0].type).toBe('error');
		});

		it('accepts custom duration', () => {
			store.add('Persistent', 'info', 10000);

			expect(store.list[0].duration).toBe(10000);
		});

		it('adds multiple toasts', () => {
			store.add('First');
			store.add('Second');
			store.add('Third');

			expect(store.list).toHaveLength(3);
			expect(store.list.map((t) => t.message)).toEqual(['First', 'Second', 'Third']);
		});
	});

	describe('auto-removal', () => {
		it('removes toast after duration', () => {
			store.add('Temporary', 'info', 3000);
			expect(store.list).toHaveLength(1);

			vi.advanceTimersByTime(3000);

			expect(store.list).toHaveLength(0);
		});

		it('does not auto-remove when duration is 0', () => {
			store.add('Persistent', 'info', 0);
			expect(store.list).toHaveLength(1);

			vi.advanceTimersByTime(10000);

			// Still there
			expect(store.list).toHaveLength(1);
		});

		it('handles multiple toasts with different durations', () => {
			store.add('Short', 'info', 1000);
			store.add('Medium', 'info', 2000);
			store.add('Long', 'info', 5000);

			expect(store.list).toHaveLength(3);

			vi.advanceTimersByTime(1000);
			expect(store.list).toHaveLength(2);
			expect(store.list.map((t) => t.message)).toEqual(['Medium', 'Long']);

			vi.advanceTimersByTime(1000);
			expect(store.list).toHaveLength(1);
			expect(store.list[0].message).toBe('Long');

			vi.advanceTimersByTime(3000);
			expect(store.list).toHaveLength(0);
		});
	});

	describe('manual remove', () => {
		it('removes toast by ID', () => {
			const id = store.add('Test');
			expect(store.list).toHaveLength(1);

			store.remove(id);

			expect(store.list).toHaveLength(0);
		});

		it('removes correct toast when multiple exist', () => {
			store.add('First');
			const secondId = store.add('Second');
			store.add('Third');

			store.remove(secondId);

			expect(store.list).toHaveLength(2);
			expect(store.list.map((t) => t.message)).toEqual(['First', 'Third']);
		});

		it('handles removal of non-existent ID gracefully', () => {
			store.add('Test');

			store.remove('non-existent-id');

			// Should not throw and list should be unchanged
			expect(store.list).toHaveLength(1);
		});

		it('manual remove works before auto-remove', () => {
			const id = store.add('Test', 'info', 5000);

			// Remove manually before timeout
			vi.advanceTimersByTime(2000);
			store.remove(id);

			expect(store.list).toHaveLength(0);

			// Even after the original duration passes, no errors
			vi.advanceTimersByTime(5000);
			expect(store.list).toHaveLength(0);
		});
	});

	describe('clear', () => {
		it('removes all toasts', () => {
			store.add('First');
			store.add('Second');
			store.add('Third');
			expect(store.list).toHaveLength(3);

			store.clear();

			expect(store.list).toHaveLength(0);
		});

		it('handles clearing empty list', () => {
			store.clear();

			expect(store.list).toHaveLength(0);
		});
	});

	describe('convenience methods', () => {
		it('info() creates info toast', () => {
			const id = store.info('Info message');

			expect(store.list[0].type).toBe('info');
			expect(store.list[0].message).toBe('Info message');
			expect(id).toBe('test-uuid-1');
		});

		it('success() creates success toast', () => {
			store.success('Success message');

			expect(store.list[0].type).toBe('success');
			expect(store.list[0].message).toBe('Success message');
		});

		it('warning() creates warning toast', () => {
			store.warning('Warning message');

			expect(store.list[0].type).toBe('warning');
			expect(store.list[0].message).toBe('Warning message');
		});

		it('error() creates error toast', () => {
			store.error('Error message');

			expect(store.list[0].type).toBe('error');
			expect(store.list[0].message).toBe('Error message');
		});

		it('convenience methods accept custom duration', () => {
			store.info('Info', 1000);
			store.success('Success', 2000);
			store.warning('Warning', 3000);
			store.error('Error', 4000);

			expect(store.list[0].duration).toBe(1000);
			expect(store.list[1].duration).toBe(2000);
			expect(store.list[2].duration).toBe(3000);
			expect(store.list[3].duration).toBe(4000);
		});
	});

	describe('rapid operations', () => {
		it('handles rapid add/remove sequences', () => {
			// Simulate rapid user interactions
			const id1 = store.add('First');
			store.remove(id1);
			const id2 = store.add('Second');
			const id3 = store.add('Third');
			store.remove(id3);

			expect(store.list).toHaveLength(1);
			expect(store.list[0].id).toBe(id2);
		});

		it('handles adding while others are expiring', () => {
			store.add('Short', 'info', 1000);

			vi.advanceTimersByTime(500);
			store.add('Long', 'info', 5000);

			vi.advanceTimersByTime(500);
			// First should be gone
			expect(store.list).toHaveLength(1);
			expect(store.list[0].message).toBe('Long');
		});
	});
});
