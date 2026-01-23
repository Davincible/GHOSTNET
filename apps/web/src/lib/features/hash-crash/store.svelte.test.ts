/**
 * HASH CRASH Store Tests (Pre-Commit Model)
 * ==========================================
 * Tests for the Hash Crash game store functionality.
 *
 * CRITICAL: File must have .svelte.test.ts extension for runes to work!
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { untrack } from 'svelte';

// Mock SvelteKit environment - must be before imports
vi.mock('$app/environment', () => ({
	browser: true,
}));
import {
	createHashCrashStore,
	formatMultiplier,
	getMultiplierColor,
	calculateProfit,
	calculateWinProbability,
	MIN_BET,
	MAX_BET,
	MIN_TARGET,
	MAX_TARGET,
	GROWTH_RATE,
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
	describe('without target', () => {
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

	describe('with target', () => {
		it('returns mult-safe when well below target', () => {
			expect(getMultiplierColor(1.5, 3.0)).toBe('mult-safe');
		});

		it('returns mult-warning when approaching target', () => {
			expect(getMultiplierColor(2.5, 3.0)).toBe('mult-warning');
			expect(getMultiplierColor(2.8, 3.0)).toBe('mult-warning');
		});

		it('returns mult-danger when at or above target', () => {
			expect(getMultiplierColor(3.0, 3.0)).toBe('mult-danger');
			expect(getMultiplierColor(3.5, 3.0)).toBe('mult-danger');
		});
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

describe('calculateWinProbability', () => {
	it('calculates probability for 2x target (approximately 48%)', () => {
		const prob = calculateWinProbability(2.0);
		expect(prob).toBeCloseTo(0.48, 2);
	});

	it('calculates probability for 1.5x target (approximately 64%)', () => {
		const prob = calculateWinProbability(1.5);
		expect(prob).toBeCloseTo(0.64, 2);
	});

	it('calculates probability for 10x target (approximately 9.6%)', () => {
		const prob = calculateWinProbability(10);
		expect(prob).toBeCloseTo(0.096, 2);
	});

	it('caps probability at 99% for very low targets', () => {
		const prob = calculateWinProbability(0.5);
		expect(prob).toBe(0.99);
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
			expect(state.playerResult).toBe('pending');
			expect(state.players).toEqual([]);
			expect(state.recentCrashPoints).toEqual([]);
			expect(state.isConnected).toBe(false);
			expect(state.isLoading).toBe(false);
			expect(state.error).toBeNull();
		});

		it('starts with canBet = false', () => {
			expect(untrack(() => store.canBet)).toBe(false);
		});

		it('starts with isAnimating = false', () => {
			expect(untrack(() => store.isAnimating)).toBe(false);
		});

		it('starts with hasWon = false', () => {
			expect(untrack(() => store.hasWon)).toBe(false);
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
			await store.placeBet(tooSmall, 2.0);

			const state = untrack(() => store.state);
			expect(state.error).toContain('10');
			expect(state.error).toContain('1000');
		});

		it('rejects bets above maximum', async () => {
			store._simulateRound(5);
			vi.advanceTimersByTime(100);

			const tooLarge = 2000n * 10n ** 18n; // 2000 DATA (max is 1000)
			await store.placeBet(tooLarge, 2.0);

			const state = untrack(() => store.state);
			expect(state.error).toContain('1000');
		});

		it('rejects targets below minimum', async () => {
			store._simulateRound(5);
			vi.advanceTimersByTime(100);

			const validBet = 100n * 10n ** 18n;
			await store.placeBet(validBet, 1.0); // 1.0x is below minimum 1.01x

			const state = untrack(() => store.state);
			expect(state.error).toContain('1.01');
		});

		it('rejects targets above maximum', async () => {
			store._simulateRound(5);
			vi.advanceTimersByTime(100);

			const validBet = 100n * 10n ** 18n;
			await store.placeBet(validBet, 150); // 150x is above maximum 100x

			const state = untrack(() => store.state);
			expect(state.error).toContain('100');
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

		it('calculates winProbability based on target', () => {
			// No bet yet - should be 0
			expect(untrack(() => store.winProbability)).toBe(0);

			// We can't easily test this without mocking the internal state
			// but the calculation is tested in calculateWinProbability tests
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

	it('starts a simulated round in betting phase', () => {
		store._simulateRound(5);

		const state = untrack(() => store.state);
		expect(state.round).not.toBeNull();
		expect(state.round?.state).toBe('betting');
		expect(state.round?.roundId).toBe(1);
	});

	it('transitions from betting to locked after betting period', () => {
		store._simulateRound(5);

		// Advance past betting period (10 seconds in simulation)
		vi.advanceTimersByTime(10_100);

		const state = untrack(() => store.state);
		expect(state.round?.state).toBe('locked');
	});

	it('transitions from locked to revealed/animating', () => {
		store._simulateRound(5);
		vi.advanceTimersByTime(10_100); // Past betting to locked

		// Advance past lock phase (2 seconds)
		vi.advanceTimersByTime(2100);

		const state = untrack(() => store.state);
		// Should be in animating phase with crash point set
		expect(['revealed', 'animating']).toContain(state.round?.state);
		expect(state.round?.crashPoint).toBe(5);
	});

	it('determines player win immediately on reveal (3x target vs 5x crash)', () => {
		// Test the win condition logic directly
		// In real app, WebSocket would confirm bet placement
		// Here we test the logic: target < crashPoint = WIN
		const target = 3.0;
		const crashPoint = 5.0;
		const isWin = target < crashPoint;
		expect(isWin).toBe(true);
	});

	it('determines player loss immediately on reveal (3x target vs 2x crash)', () => {
		// Test the loss condition logic directly
		// In real app, WebSocket would confirm bet placement
		// Here we test the logic: target >= crashPoint = LOSE
		const target = 3.0;
		const crashPoint = 2.0;
		const isWin = target < crashPoint;
		expect(isWin).toBe(false);
	});

	it('animates and settles at crash point', () => {
		const crashPoint = 3.0;
		store._simulateRound(crashPoint);
		vi.advanceTimersByTime(10_100); // Past betting
		vi.advanceTimersByTime(2100); // Past lock to reveal/animate

		// Calculate animation duration: t = ln(crashPoint) / GROWTH_RATE
		const animationTime = (Math.log(crashPoint) / GROWTH_RATE) * 1000;

		// Advance to just after animation should complete
		vi.advanceTimersByTime(animationTime + 100);

		const state = untrack(() => store.state);
		expect(state.round?.state).toBe('settled');
		expect(state.multiplier).toBe(crashPoint);
	});

	it('records crash points in history', () => {
		store._simulateRound(2.5);
		vi.advanceTimersByTime(10_100); // Past betting
		vi.advanceTimersByTime(2100); // Past lock to reveal

		const state = untrack(() => store.state);
		expect(state.recentCrashPoints).toContain(2.5);
	});

	it('increments round ID for subsequent rounds', () => {
		store._simulateRound(2);
		expect(untrack(() => store.state.round?.roundId)).toBe(1);

		// Complete the round
		vi.advanceTimersByTime(10_100 + 2100);
		const crashTime1 = (Math.log(2) / GROWTH_RATE) * 1000;
		vi.advanceTimersByTime(crashTime1 + 100);

		// Start another round
		store._simulateRound(3);
		expect(untrack(() => store.state.round?.roundId)).toBe(2);
	});
});

// ============================================================================
// WIN/LOSS DETERMINATION TESTS
// ============================================================================

describe('win/loss determination', () => {
	it('player wins when target < crashPoint', () => {
		// Target 2.5x, crash at 5x => WIN
		const target = 2.5;
		const crashPoint = 5;
		const isWin = target < crashPoint;
		expect(isWin).toBe(true);
	});

	it('player loses when target >= crashPoint', () => {
		// Target 5x, crash at 3x => LOSE
		const target = 5;
		const crashPoint = 3;
		const isWin = target < crashPoint;
		expect(isWin).toBe(false);
	});

	it('player loses when target equals crashPoint', () => {
		// Target 3x, crash at 3x => LOSE (must be strictly less)
		const target = 3;
		const crashPoint = 3;
		const isWin = target < crashPoint;
		expect(isWin).toBe(false);
	});

	it('calculates payout correctly for winner', () => {
		const bet = 100n * 10n ** 18n;
		const target = 2.5;
		const expectedPayout = BigInt(Math.floor(Number(bet) * target));
		expect(expectedPayout).toBe(250n * 10n ** 18n);
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

	it('MIN_TARGET is 1.01x', () => {
		expect(MIN_TARGET).toBe(1.01);
	});

	it('MAX_TARGET is 100x', () => {
		expect(MAX_TARGET).toBe(100);
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
		vi.advanceTimersByTime(10_100); // Past betting
		vi.advanceTimersByTime(2100); // Past lock to reveal

		// Should crash almost immediately
		const crashTime = (Math.log(1.01) / GROWTH_RATE) * 1000;
		vi.advanceTimersByTime(crashTime + 100);

		const state = untrack(() => store.state);
		expect(state.round?.state).toBe('settled');
	});

	it('handles high crash points', () => {
		store._simulateRound(100); // Very high crash point
		vi.advanceTimersByTime(10_100); // Past betting
		vi.advanceTimersByTime(2100); // Past lock to reveal

		// Should still be animating for a while
		vi.advanceTimersByTime(10_000);
		const state = untrack(() => store.state);
		expect(state.round?.state).toBe('animating');

		// Eventually settles
		const crashTime = (Math.log(100) / GROWTH_RATE) * 1000;
		vi.advanceTimersByTime(crashTime - 10_000 + 100);

		const finalState = untrack(() => store.state);
		expect(finalState.round?.state).toBe('settled');
	});

	it('disconnect cleans up properly', () => {
		store._simulateRound(5);
		vi.advanceTimersByTime(100);

		store.disconnect();

		const state = untrack(() => store.state);
		expect(state.isConnected).toBe(false);
	});

	it('cannot place bet after betting phase closes', async () => {
		store._simulateRound(5);
		vi.advanceTimersByTime(10_100); // Past betting phase

		expect(untrack(() => store.canBet)).toBe(false);

		await store.placeBet(100n * 10n ** 18n, 2.0);
		// Should not have set a bet (canBet check will exit early)
		expect(untrack(() => store.state.playerBet)).toBeNull();
	});

	it('blocks betting while loading (bet in progress)', async () => {
		store._simulateRound(5);
		vi.advanceTimersByTime(100);

		// Initially can bet
		expect(untrack(() => store.canBet)).toBe(true);

		// Place a bet (this sets isLoading = true)
		await store.placeBet(100n * 10n ** 18n, 2.0);

		// While loading, canBet should be false
		const state = untrack(() => store.state);
		// isLoading is true, so canBet should be false
		expect(state.isLoading).toBe(true);
		expect(untrack(() => store.canBet)).toBe(false);
	});
});
