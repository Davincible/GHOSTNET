/**
 * Typing Game Store Tests
 * ========================
 * Tests for the Trace Evasion mini-game logic.
 *
 * CRITICAL: File must have .svelte.test.ts extension for runes to work!
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { flushSync } from 'svelte';
import {
	createTypingGameStore,
	calculateWpm,
	calculateAccuracy,
	calculateReward,
	TOTAL_ROUNDS,
	type TypingGameStore,
	type RoundResult,
} from './store.svelte';
import type { TypingChallenge } from '$lib/core/types';

// ════════════════════════════════════════════════════════════════
// TEST FIXTURES
// ════════════════════════════════════════════════════════════════

/** Create a simple challenge for testing */
function createChallenge(command: string, timeLimit = 30): TypingChallenge {
	return {
		command,
		difficulty: 'easy' as const,
		timeLimit,
	};
}

/** Create multiple challenges for multi-round testing */
function createChallenges(count: number = TOTAL_ROUNDS): () => TypingChallenge[] {
	return () => Array.from({ length: count }, (_, i) => createChallenge(`test${i + 1}`, 30));
}

// ════════════════════════════════════════════════════════════════
// PURE FUNCTION TESTS (No runes needed)
// ════════════════════════════════════════════════════════════════

describe('calculateWpm', () => {
	it('calculates WPM correctly for standard typing', () => {
		// 50 characters in 60 seconds = 10 words per minute (5 chars = 1 word)
		expect(calculateWpm(50, 60000)).toBe(10);
	});

	it('calculates WPM for fast typing', () => {
		// 100 characters in 30 seconds = 40 WPM
		expect(calculateWpm(100, 30000)).toBe(40);
	});

	it('returns 0 for zero time elapsed', () => {
		expect(calculateWpm(50, 0)).toBe(0);
	});

	it('returns 0 for negative time', () => {
		expect(calculateWpm(50, -1000)).toBe(0);
	});

	it('rounds to nearest integer', () => {
		// 25 chars in 60 seconds = 5 WPM (exact)
		expect(calculateWpm(25, 60000)).toBe(5);
		// 26 chars in 60 seconds = 5.2 WPM → 5
		expect(calculateWpm(26, 60000)).toBe(5);
		// 27 chars in 60 seconds = 5.4 WPM → 5
		expect(calculateWpm(27, 60000)).toBe(5);
		// 28 chars in 60 seconds = 5.6 WPM → 6
		expect(calculateWpm(28, 60000)).toBe(6);
	});
});

describe('calculateAccuracy', () => {
	it('calculates accuracy correctly', () => {
		expect(calculateAccuracy(8, 10)).toBe(0.8);
		expect(calculateAccuracy(10, 10)).toBe(1.0);
		expect(calculateAccuracy(0, 10)).toBe(0);
	});

	it('returns 0 for zero total', () => {
		expect(calculateAccuracy(5, 0)).toBe(0);
	});

	it('handles perfect accuracy', () => {
		expect(calculateAccuracy(100, 100)).toBe(1.0);
	});
});

describe('calculateReward', () => {
	describe('accuracy tiers', () => {
		it('returns PERFECT tier for 100% accuracy', () => {
			const reward = calculateReward(1.0, 50);
			expect(reward).not.toBeNull();
			expect(reward?.value).toBe(-0.25);
			expect(reward?.label).toContain('PERFECT');
		});

		it('returns Excellent tier for 95-99% accuracy', () => {
			const reward = calculateReward(0.95, 50);
			expect(reward).not.toBeNull();
			expect(reward?.value).toBe(-0.2);
			expect(reward?.label).toContain('Excellent');
		});

		it('returns Great tier for 85-94% accuracy', () => {
			const reward = calculateReward(0.85, 50);
			expect(reward?.value).toBe(-0.15);
			expect(reward?.label).toContain('Great');
		});

		it('returns Good tier for 70-84% accuracy', () => {
			const reward = calculateReward(0.7, 50);
			expect(reward?.value).toBe(-0.1);
			expect(reward?.label).toContain('Good');
		});

		it('returns Okay tier for 50-69% accuracy', () => {
			const reward = calculateReward(0.5, 50);
			expect(reward?.value).toBe(-0.05);
			expect(reward?.label).toContain('Okay');
		});

		it('returns null for below 50% accuracy', () => {
			expect(calculateReward(0.49, 50)).toBeNull();
			expect(calculateReward(0.4, 50)).toBeNull();
			expect(calculateReward(0.0, 50)).toBeNull();
		});
	});

	describe('speed bonuses', () => {
		it('adds Speed Master bonus for 100+ WPM with 95%+ accuracy', () => {
			const reward = calculateReward(0.98, 100);
			expect(reward?.value).toBeCloseTo(-0.3, 5); // -0.20 (Excellent) + -0.10 (Speed Master)
			expect(reward?.label).toContain('Speed Master');
		});

		it('adds Speed Bonus for 80+ WPM with 95%+ accuracy', () => {
			const reward = calculateReward(0.96, 85);
			expect(reward?.value).toBeCloseTo(-0.25, 5); // -0.20 (Excellent) + -0.05 (Speed Bonus)
			expect(reward?.label).toContain('Speed Bonus');
		});

		it('prefers Speed Master over Speed Bonus when both qualify', () => {
			const reward = calculateReward(0.98, 120);
			expect(reward?.value).toBeCloseTo(-0.3, 5); // Speed Master, not cumulative
			expect(reward?.label).toContain('Speed Master');
			expect(reward?.label).not.toContain('Speed Bonus');
		});

		it('does not add speed bonus for low accuracy', () => {
			const reward = calculateReward(0.8, 100); // 80% accuracy, 100 WPM
			// 80% is in "Good" tier (70-84%), not "Great" (85-94%)
			expect(reward?.value).toBe(-0.1); // Just Good tier, no speed bonus (need 95%+)
			expect(reward?.label).not.toContain('Speed');
		});

		it('does not add speed bonus for low WPM', () => {
			const reward = calculateReward(0.98, 50); // 98% accuracy, 50 WPM
			expect(reward?.value).toBe(-0.2); // Just Excellent tier, no speed bonus
			expect(reward?.label).not.toContain('Speed');
		});
	});

	describe('reward type', () => {
		it('always returns death_rate_reduction type', () => {
			const reward = calculateReward(0.85, 60);
			expect(reward?.type).toBe('death_rate_reduction');
		});
	});
});

// ════════════════════════════════════════════════════════════════
// STORE STATE MACHINE TESTS
// ════════════════════════════════════════════════════════════════

describe('createTypingGameStore', () => {
	let store: TypingGameStore;

	beforeEach(() => {
		vi.useFakeTimers();
		store = createTypingGameStore();
	});

	afterEach(() => {
		vi.restoreAllMocks();
		store.reset();
	});

	describe('initial state', () => {
		it('starts in idle state', () => {
			expect(store.state.status).toBe('idle');
		});

		it('getResult returns null when idle', () => {
			expect(store.getResult()).toBeNull();
		});
	});

	describe('start', () => {
		it('transitions from idle to countdown', () => {
			store.start(createChallenges(1));
			expect(store.state.status).toBe('countdown');
		});

		it('does nothing if already started', () => {
			store.start(createChallenges(1));
			expect(store.state.status).toBe('countdown');

			// Try to start again
			store.start(createChallenges(1));
			expect(store.state.status).toBe('countdown');
		});

		it('initializes countdown with 3 seconds', () => {
			store.start(createChallenges(1));

			if (store.state.status === 'countdown') {
				expect(store.state.secondsLeft).toBe(3);
			} else {
				expect.fail('Expected countdown state');
			}
		});

		it('sets currentRound and totalRounds correctly', () => {
			store.start(createChallenges(3));

			if (store.state.status === 'countdown') {
				expect(store.state.currentRound).toBe(1);
				expect(store.state.totalRounds).toBe(3);
			} else {
				expect.fail('Expected countdown state');
			}
		});
	});

	describe('countdown', () => {
		it('decrements countdown each second', () => {
			store.start(createChallenges(1));

			expect(store.state.status).toBe('countdown');
			if (store.state.status === 'countdown') {
				expect(store.state.secondsLeft).toBe(3);
			}

			vi.advanceTimersByTime(1000);
			if (store.state.status === 'countdown') {
				expect(store.state.secondsLeft).toBe(2);
			}

			vi.advanceTimersByTime(1000);
			if (store.state.status === 'countdown') {
				expect(store.state.secondsLeft).toBe(1);
			}
		});

		it('transitions to active after countdown completes', () => {
			store.start(createChallenges(1));

			// Advance through full countdown
			vi.advanceTimersByTime(3000);

			expect(store.state.status).toBe('active');
		});
	});

	describe('active state', () => {
		beforeEach(() => {
			store.start(() => [createChallenge('test', 30)]);
			vi.advanceTimersByTime(3000); // Complete countdown
		});

		it('has challenge and progress in active state', () => {
			if (store.state.status === 'active') {
				expect(store.state.challenge.command).toBe('test');
				expect(store.state.progress.typed).toBe('');
				expect(store.state.progress.correctChars).toBe(0);
				expect(store.state.progress.errorChars).toBe(0);
			} else {
				expect.fail('Expected active state');
			}
		});

		it('updates time tracking', () => {
			if (store.state.status === 'active') {
				const initialTime = store.state.progress.currentTime;

				vi.advanceTimersByTime(500);

				if (store.state.status === 'active') {
					expect(store.state.progress.currentTime).toBeGreaterThan(initialTime);
				}
			}
		});
	});

	describe('handleKey', () => {
		beforeEach(() => {
			store.start(() => [createChallenge('test', 30)]);
			vi.advanceTimersByTime(3000); // Complete countdown
		});

		it('records correct character', () => {
			store.handleKey('t');

			if (store.state.status === 'active') {
				expect(store.state.progress.typed).toBe('t');
				expect(store.state.progress.correctChars).toBe(1);
				expect(store.state.progress.errorChars).toBe(0);
			}
		});

		it('records incorrect character', () => {
			store.handleKey('x'); // Should be 't'

			if (store.state.status === 'active') {
				expect(store.state.progress.typed).toBe('x');
				expect(store.state.progress.correctChars).toBe(0);
				expect(store.state.progress.errorChars).toBe(1);
			}
		});

		it('handles backspace on correct character', () => {
			store.handleKey('t'); // Correct
			store.handleKey('Backspace');

			if (store.state.status === 'active') {
				expect(store.state.progress.typed).toBe('');
				expect(store.state.progress.correctChars).toBe(0);
				expect(store.state.progress.errorChars).toBe(0);
			}
		});

		it('handles backspace on incorrect character', () => {
			store.handleKey('x'); // Incorrect
			store.handleKey('Backspace');

			if (store.state.status === 'active') {
				expect(store.state.progress.typed).toBe('');
				expect(store.state.progress.correctChars).toBe(0);
				expect(store.state.progress.errorChars).toBe(0);
			}
		});

		it('ignores backspace on empty input', () => {
			store.handleKey('Backspace');

			if (store.state.status === 'active') {
				expect(store.state.progress.typed).toBe('');
			}
		});

		it('ignores non-printable keys', () => {
			store.handleKey('Shift');
			store.handleKey('Control');
			store.handleKey('Alt');

			if (store.state.status === 'active') {
				expect(store.state.progress.typed).toBe('');
			}
		});

		it('does nothing when not in active state', () => {
			store.reset();
			store.handleKey('t');
			expect(store.state.status).toBe('idle');
		});

		it('completes round when full command typed', () => {
			store.handleKey('t');
			store.handleKey('e');
			store.handleKey('s');
			store.handleKey('t');

			// Should transition to complete (single round)
			expect(store.state.status).toBe('complete');
		});
	});

	describe('timeout', () => {
		it('completes round on timeout', () => {
			store.start(() => [createChallenge('test', 5)]); // 5 second limit
			vi.advanceTimersByTime(3000); // Complete countdown

			expect(store.state.status).toBe('active');

			// Advance past time limit
			vi.advanceTimersByTime(5100);

			expect(store.state.status).toBe('complete');
		});

		it('marks round as not completed on timeout', () => {
			store.start(() => [createChallenge('test', 5)]);
			vi.advanceTimersByTime(3000); // Complete countdown

			// Type some but not all
			store.handleKey('t');
			store.handleKey('e');

			// Timeout
			vi.advanceTimersByTime(5100);

			if (store.state.status === 'complete') {
				expect(store.state.result.completed).toBe(false);
			}
		});
	});

	describe('multi-round progression', () => {
		it('progresses through multiple rounds', () => {
			store.start(createChallenges(2));
			vi.advanceTimersByTime(3000); // Complete countdown for round 1

			expect(store.state.status).toBe('active');
			if (store.state.status === 'active') {
				expect(store.state.currentRound).toBe(1);
			}

			// Complete round 1 by typing command
			'test1'.split('').forEach((char) => store.handleKey(char));

			// Should show roundComplete briefly
			expect(store.state.status).toBe('roundComplete');

			// Advance through transition delay
			vi.advanceTimersByTime(1500);

			// Should be in countdown for round 2
			expect(store.state.status).toBe('countdown');
			if (store.state.status === 'countdown') {
				expect(store.state.currentRound).toBe(2);
			}
		});

		it('completes game after all rounds', () => {
			store.start(createChallenges(2));

			// Round 1
			vi.advanceTimersByTime(3000);
			'test1'.split('').forEach((char) => store.handleKey(char));
			vi.advanceTimersByTime(1500); // Transition

			// Round 2
			vi.advanceTimersByTime(3000);
			'test2'.split('').forEach((char) => store.handleKey(char));

			expect(store.state.status).toBe('complete');
			if (store.state.status === 'complete') {
				expect(store.state.result.roundsCompleted).toBe(2);
				expect(store.state.result.totalRounds).toBe(2);
			}
		});
	});

	describe('complete state', () => {
		it('calculates aggregate results correctly', () => {
			store.start(() => [createChallenge('ab', 30), createChallenge('cd', 30)]);

			// Round 1: perfect
			vi.advanceTimersByTime(3000);
			store.handleKey('a');
			store.handleKey('b');
			vi.advanceTimersByTime(1500);

			// Round 2: perfect
			vi.advanceTimersByTime(3000);
			store.handleKey('c');
			store.handleKey('d');

			if (store.state.status === 'complete') {
				expect(store.state.result.accuracy).toBe(1.0);
				expect(store.state.result.completed).toBe(true);
				expect(store.state.result.roundResults).toHaveLength(2);
			}
		});

		it('includes per-round results', () => {
			store.start(() => [createChallenge('ab', 30)]);
			vi.advanceTimersByTime(3000);
			store.handleKey('a');
			store.handleKey('b');

			if (store.state.status === 'complete') {
				const roundResult = store.state.result.roundResults[0];
				expect(roundResult.completed).toBe(true);
				expect(roundResult.correctChars).toBe(2);
				expect(roundResult.totalChars).toBe(2);
				expect(roundResult.accuracy).toBe(1.0);
			}
		});

		it('calculates reward for perfect game', () => {
			store.start(() => [createChallenge('ab', 30)]);
			vi.advanceTimersByTime(3000);
			store.handleKey('a');
			store.handleKey('b');

			if (store.state.status === 'complete') {
				expect(store.state.result.reward).not.toBeNull();
				expect(store.state.result.reward?.type).toBe('death_rate_reduction');
			}
		});
	});

	describe('reset', () => {
		it('returns to idle state', () => {
			store.start(createChallenges(1));
			vi.advanceTimersByTime(3000);

			store.reset();

			expect(store.state.status).toBe('idle');
		});

		it('clears all timers', () => {
			store.start(createChallenges(1));

			store.reset();

			// Advancing time should not change state
			vi.advanceTimersByTime(10000);
			expect(store.state.status).toBe('idle');
		});

		it('can start new game after reset', () => {
			store.start(createChallenges(1));
			vi.advanceTimersByTime(3000);
			store.reset();

			store.start(createChallenges(2));
			expect(store.state.status).toBe('countdown');
			if (store.state.status === 'countdown') {
				expect(store.state.totalRounds).toBe(2);
			}
		});
	});

	describe('getResult', () => {
		it('returns null when not complete', () => {
			expect(store.getResult()).toBeNull();

			store.start(createChallenges(1));
			expect(store.getResult()).toBeNull();

			vi.advanceTimersByTime(3000);
			expect(store.getResult()).toBeNull();
		});

		it('returns result when complete', () => {
			store.start(() => [createChallenge('ab', 30)]);
			vi.advanceTimersByTime(3000);
			store.handleKey('a');
			store.handleKey('b');

			const result = store.getResult();
			expect(result).not.toBeNull();
			expect(result?.accuracy).toBe(1.0);
			expect(result?.reward).not.toBeNull();
		});
	});
});

// ════════════════════════════════════════════════════════════════
// EDGE CASES
// ════════════════════════════════════════════════════════════════

describe('edge cases', () => {
	let store: TypingGameStore;

	beforeEach(() => {
		vi.useFakeTimers();
		store = createTypingGameStore();
	});

	afterEach(() => {
		vi.restoreAllMocks();
		store.reset();
	});

	it('handles empty challenge list gracefully', () => {
		store.start(() => []);
		vi.advanceTimersByTime(3000);

		// Should fall back to idle
		expect(store.state.status).toBe('idle');
	});

	it('handles mixed correct and incorrect characters', () => {
		store.start(() => [createChallenge('test', 30)]);
		vi.advanceTimersByTime(3000);

		// Target: 'test'
		store.handleKey('t'); // position 0: target='t' → correct
		store.handleKey('x'); // position 1: target='e' → incorrect
		store.handleKey('s'); // position 2: target='s' → correct
		store.handleKey('t'); // position 3: target='t' → correct

		if (store.state.status === 'complete') {
			// 3 correct out of 4 typed
			expect(store.state.result.accuracy).toBe(0.75);
		}
	});

	it('handles rapid key presses', () => {
		store.start(() => [createChallenge('test', 30)]);
		vi.advanceTimersByTime(3000);

		// Rapid typing without advancing timers
		store.handleKey('t');
		store.handleKey('e');
		store.handleKey('s');
		store.handleKey('t');

		expect(store.state.status).toBe('complete');
	});

	it('ignores keys after command is complete', () => {
		store.start(() => [createChallenge('ab', 30)]);
		vi.advanceTimersByTime(3000);

		store.handleKey('a');
		store.handleKey('b');

		// Extra keys should be ignored (game is complete)
		store.handleKey('c');
		store.handleKey('d');

		if (store.state.status === 'complete') {
			expect(store.state.result.roundResults[0].totalChars).toBe(2);
		}
	});
});
