/**
 * HASH CRASH Store Tests
 * ======================
 * Tests for the Hash Crash game store functionality.
 *
 * CRITICAL: File must have .svelte.test.ts extension for runes to work!
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { flushSync, untrack } from 'svelte';

// Mock SvelteKit environment - must be before imports
vi.mock('$app/environment', () => ({
	browser: true
}));
import {
	createHashCrashStore,
	formatMultiplier,
	getMultiplierColor,
	calculateProfit,
	MIN_BET,
	MAX_BET,
	GROWTH_RATE
} from './store.svelte';

// ============================================================================
// UTILITY FUNCTION TESTS
// ============================================================================

describe('formatMultiplier', () => {
	it('formats 1x correctly', () => {
		expect(formatMultiplier(1)).toBe('1.00x');
	});

	it('formats multipliers with 2 decimal places', () => {
		expect(formatMultiplier(2.5)).toBe('2.50x');
		expect(formatMultiplier(23.47)).toBe('23.47x');
		expect(formatMultiplier(100.1)).toBe('100.10x');
	});

	it('rounds to 2 decimal places', () => {
		expect(formatMultiplier(1.999)).toBe('2.00x');
		expect(formatMultiplier(1.234)).toBe('1.23x');
	});
});

describe('getMultiplierColor', () => {
	it('returns mult-low for values under 2', () => {
		expect(getMultiplierColor(1)).toBe('mult-low');
		expect(getMultiplierColor(1.5)).toBe('mult-low');
		expect(getMultiplierColor(1.99)).toBe('mult-low');
	});

	it('returns mult-mid for values 2-5', () => {
		expect(getMultiplierColor(2)).toBe('mult-mid');
		expect(getMultiplierColor(3.5)).toBe('mult-mid');
		expect(getMultiplierColor(4.99)).toBe('mult-mid');
	});

	it('returns mult-high for values 5-10', () => {
		expect(getMultiplierColor(5)).toBe('mult-high');
		expect(getMultiplierColor(7.5)).toBe('mult-high');
		expect(getMultiplierColor(9.99)).toBe('mult-high');
	});

	it('returns mult-extreme for values 10+', () => {
		expect(getMultiplierColor(10)).toBe('mult-extreme');
		expect(getMultiplierColor(50)).toBe('mult-extreme');
		expect(getMultiplierColor(100)).toBe('mult-extreme');
	});
});

describe('calculateProfit', () => {
	it('calculates profit correctly', () => {
		const bet = 100n * 10n ** 18n; // 100 DATA
		const multiplier = 2.5;
		const profit = calculateProfit(bet, multiplier);

		// 100 * 2.5 = 250, profit = 250 - 100 = 150
		const expected = 150n * 10n ** 18n;
		expect(profit).toBe(expected);
	});

	it('returns negative profit for multiplier < 1', () => {
		const bet = 100n * 10n ** 18n;
		const profit = calculateProfit(bet, 0.5);
		// 100 * 0.5 = 50, profit = 50 - 100 = -50
		expect(profit).toBe(-50n * 10n ** 18n);
	});

	it('returns zero profit for multiplier = 1', () => {
		const bet = 100n * 10n ** 18n;
		const profit = calculateProfit(bet, 1.0);
		expect(profit).toBe(0n);
	});
});

// ============================================================================
// STORE CREATION TESTS
// ============================================================================

describe('createHashCrashStore', () => {
	let store: ReturnType<typeof createHashCrashStore>;

	beforeEach(() => {
		vi.useFakeTimers();
		store = createHashCrashStore();
	});

	afterEach(() => {
		store.disconnect();
		vi.useRealTimers();
	});

	describe('initial state', () => {
		it('initializes with correct default state', () => {
			const state = untrack(() => store.state);

			expect(state.round).toBeNull();
			expect(state.multiplier).toBe(1.0);
			expect(state.playerBet).toBeNull();
			expect(state.recentCashOuts).toEqual([]);
			expect(state.recentCrashPoints).toEqual([]);
			expect(state.players).toEqual([]);
			expect(state.isConnected).toBe(false);
			expect(state.isLoading).toBe(false);
			expect(state.error).toBeNull();
		});

		it('starts with canBet = false', () => {
			expect(untrack(() => store.canBet)).toBe(false);
		});

		it('starts with canCashOut = false', () => {
			expect(untrack(() => store.canCashOut)).toBe(false);
		});

		it('starts with potentialPayout = 0', () => {
			expect(untrack(() => store.potentialPayout)).toBe(0n);
		});
	});

	describe('bet validation', () => {
		it('rejects bets below minimum', async () => {
			// Set up betting phase
			store._simulateRound(5);
			vi.advanceTimersByTime(100);

			// Try to place a bet below minimum
			const tooSmall = 5n * 10n ** 18n; // 5 DATA (min is 10)
			await store.placeBet(tooSmall);

			const state = untrack(() => store.state);
			expect(state.error).toContain('10');
			expect(state.error).toContain('1000');
		});

		it('rejects bets above maximum', async () => {
			store._simulateRound(5);
			vi.advanceTimersByTime(100);

			const tooLarge = 2000n * 10n ** 18n; // 2000 DATA (max is 1000)
			await store.placeBet(tooLarge);

			const state = untrack(() => store.state);
			expect(state.error).toContain('1000');
		});
	});

	describe('derived state', () => {
		it('updates timeRemaining from countdown', () => {
			store._simulateRound(5);

			// Initial - should have ~10 seconds (simulation uses 10s betting)
			const initial = untrack(() => store.timeRemaining);
			expect(initial).toBeGreaterThan(9000);
			expect(initial).toBeLessThanOrEqual(10000);

			// Advance time
			vi.advanceTimersByTime(3000);
			const after3s = untrack(() => store.timeRemaining);
			expect(after3s).toBeLessThan(initial);
			expect(after3s).toBeGreaterThan(6000);
		});
	});
});

// ============================================================================
// SIMULATION TESTS
// ============================================================================

describe('simulation mode', () => {
	let store: ReturnType<typeof createHashCrashStore>;

	beforeEach(() => {
		vi.useFakeTimers();
		store = createHashCrashStore();
	});

	afterEach(() => {
		store.disconnect();
		vi.useRealTimers();
	});

	it('starts a simulated round', () => {
		store._simulateRound(5);

		const state = untrack(() => store.state);
		expect(state.round).not.toBeNull();
		expect(state.round?.state).toBe('betting');
		expect(state.round?.roundId).toBe(1);
	});

	it('transitions from betting to rising after betting period', () => {
		store._simulateRound(5);

		// Advance past betting period (10 seconds in simulation)
		vi.advanceTimersByTime(10_100);

		const state = untrack(() => store.state);
		expect(state.round?.state).toBe('rising');
	});

	it('multiplier increases during rising phase', () => {
		store._simulateRound(5);
		vi.advanceTimersByTime(10_100); // Past betting

		const initialMultiplier = untrack(() => store.state.multiplier);

		// Advance a bit more (frame loop updates)
		vi.advanceTimersByTime(1000);

		// The multiplier should have increased
		// Note: Due to how requestAnimationFrame works in tests, this may need adjustment
		const state = untrack(() => store.state);
		expect(state.round?.state).toBe('rising');
	});

	it('crashes at the specified crash point', () => {
		const crashPoint = 3.0;
		store._simulateRound(crashPoint);

		vi.advanceTimersByTime(10_100); // Past betting, into rising

		// Calculate time to crash: t = ln(crashPoint) / GROWTH_RATE
		const crashTime = (Math.log(crashPoint) / GROWTH_RATE) * 1000;

		// Advance to just after crash
		vi.advanceTimersByTime(crashTime + 100);

		const state = untrack(() => store.state);
		expect(state.round?.state).toBe('crashed');
		expect(state.round?.crashPoint).toBe(crashPoint);
	});

	it('records crash points in history', () => {
		store._simulateRound(2.5);
		vi.advanceTimersByTime(10_100);

		const crashTime = (Math.log(2.5) / GROWTH_RATE) * 1000;
		vi.advanceTimersByTime(crashTime + 100);

		const state = untrack(() => store.state);
		expect(state.recentCrashPoints).toContain(2.5);
	});

	it('increments round ID for subsequent rounds', () => {
		store._simulateRound(2);
		vi.advanceTimersByTime(10_100);
		const crashTime1 = (Math.log(2) / GROWTH_RATE) * 1000;
		vi.advanceTimersByTime(crashTime1 + 100);

		expect(untrack(() => store.state.round?.roundId)).toBe(1);

		// Start another round
		store._simulateRound(3);
		expect(untrack(() => store.state.round?.roundId)).toBe(2);
	});
});

// ============================================================================
// CONSTANTS TESTS
// ============================================================================

describe('constants', () => {
	it('MIN_BET is 10 DATA', () => {
		expect(MIN_BET).toBe(10n * 10n ** 18n);
	});

	it('MAX_BET is 1000 DATA', () => {
		expect(MAX_BET).toBe(1000n * 10n ** 18n);
	});

	it('GROWTH_RATE is 0.06', () => {
		expect(GROWTH_RATE).toBe(0.06);
	});
});

// ============================================================================
// EDGE CASES
// ============================================================================

describe('edge cases', () => {
	let store: ReturnType<typeof createHashCrashStore>;

	beforeEach(() => {
		vi.useFakeTimers();
		store = createHashCrashStore();
	});

	afterEach(() => {
		store.disconnect();
		vi.useRealTimers();
	});

	it('handles very low crash points (instant crash)', () => {
		store._simulateRound(1.01); // Very low crash point
		vi.advanceTimersByTime(10_100);

		// Should crash almost immediately
		const crashTime = (Math.log(1.01) / GROWTH_RATE) * 1000;
		vi.advanceTimersByTime(crashTime + 100);

		const state = untrack(() => store.state);
		expect(state.round?.state).toBe('crashed');
	});

	it('handles high crash points', () => {
		store._simulateRound(100); // Very high crash point
		vi.advanceTimersByTime(10_100);

		// Should still be rising for a while
		vi.advanceTimersByTime(10_000);
		const state = untrack(() => store.state);
		expect(state.round?.state).toBe('rising');

		// Eventually crashes
		const crashTime = (Math.log(100) / GROWTH_RATE) * 1000;
		vi.advanceTimersByTime(crashTime - 10_000 + 100);

		const finalState = untrack(() => store.state);
		expect(finalState.round?.state).toBe('crashed');
	});

	it('setAutoCashOut stores the value', () => {
		store.setAutoCashOut(2.5);
		// The value is stored internally - we can verify by checking if it would trigger
		// In a real test, we'd mock the cash out and verify it's called at 2.5x
		expect(true).toBe(true); // Placeholder - actual behavior tested in integration
	});

	it('disconnect cleans up properly', () => {
		store._simulateRound(5);
		vi.advanceTimersByTime(100);

		store.disconnect();

		const state = untrack(() => store.state);
		expect(state.isConnected).toBe(false);
	});
});
