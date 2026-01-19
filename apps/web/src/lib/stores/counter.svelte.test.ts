/**
 * Unit tests for the counter store.
 *
 * IMPORTANT: The `.svelte.test.ts` filename is required for runes to work!
 * Files named `.test.ts` (without .svelte) will fail with "$state is not defined"
 *
 * See: docs/guides/SvelteBestPractices/26-TestingSetup.md
 */
import { describe, it, expect, beforeEach } from 'vitest';
import { createCounter } from './counter.svelte';

describe('Counter Store', () => {
	let counter: ReturnType<typeof createCounter>;

	beforeEach(() => {
		// Each test gets a fresh counter instance
		counter = createCounter();
	});

	describe('Initial State', () => {
		it('initializes with default value of 0', () => {
			expect(counter.count).toBe(0);
		});

		it('initializes with custom value', () => {
			const customCounter = createCounter(10);
			expect(customCounter.count).toBe(10);
		});
	});

	describe('$derived (doubled)', () => {
		it('computes doubled value from count', () => {
			expect(counter.doubled).toBe(0); // 0 * 2 = 0

			counter.increment();
			expect(counter.doubled).toBe(2); // 1 * 2 = 2

			counter.increment();
			expect(counter.doubled).toBe(4); // 2 * 2 = 4
		});

		it('updates derived when count changes via setter', () => {
			const customCounter = createCounter(5);
			expect(customCounter.doubled).toBe(10);
		});
	});

	describe('Actions', () => {
		it('increments count', () => {
			counter.increment();
			expect(counter.count).toBe(1);

			counter.increment();
			counter.increment();
			expect(counter.count).toBe(3);
		});

		it('decrements count', () => {
			counter.increment();
			counter.increment();
			counter.decrement();
			expect(counter.count).toBe(1);
		});

		it('allows negative counts', () => {
			counter.decrement();
			expect(counter.count).toBe(-1);
		});

		it('resets to initial value', () => {
			const customCounter = createCounter(5);
			customCounter.increment();
			customCounter.increment();
			expect(customCounter.count).toBe(7);

			customCounter.reset();
			expect(customCounter.count).toBe(5);
		});
	});
});
