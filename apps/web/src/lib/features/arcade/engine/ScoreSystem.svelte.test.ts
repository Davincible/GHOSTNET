/**
 * Score System Tests
 * ==================
 * Tests for points, combos, and multiplier management.
 *
 * CRITICAL: File must have .svelte.test.ts extension for runes to work!
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { createScoreSystem, type ScoreSystem } from './ScoreSystem.svelte';

// ============================================================================
// BASIC SCORING TESTS
// ============================================================================

describe('createScoreSystem', () => {
	let score: ScoreSystem;

	beforeEach(() => {
		vi.useFakeTimers();
	});

	afterEach(() => {
		score?.cleanup();
		vi.restoreAllMocks();
	});

	describe('initial state', () => {
		it('starts with zero score', () => {
			score = createScoreSystem();
			expect(score.state.score).toBe(0);
		});

		it('starts with initial multiplier', () => {
			score = createScoreSystem();
			expect(score.state.multiplier).toBe(1);
			expect(score.state.baseMultiplier).toBe(1);
		});

		it('respects custom initial multiplier', () => {
			score = createScoreSystem({ initialMultiplier: 2 });
			expect(score.state.multiplier).toBe(2);
		});

		it('starts with zero combo and streak', () => {
			score = createScoreSystem();
			expect(score.state.combo).toBe(0);
			expect(score.state.streak).toBe(0);
		});

		it('starts with empty recent scores', () => {
			score = createScoreSystem();
			expect(score.state.recentScores).toHaveLength(0);
		});
	});

	describe('addScore', () => {
		it('adds points to score', () => {
			score = createScoreSystem();
			score.addScore(100);
			expect(score.state.score).toBe(100);
		});

		it('applies multiplier to points', () => {
			score = createScoreSystem({ initialMultiplier: 2 });
			score.addScore(100);
			expect(score.state.score).toBe(200);
		});

		it('returns score event', () => {
			score = createScoreSystem({ initialMultiplier: 2 });
			const event = score.addScore(100, 'Test');
			
			expect(event.basePoints).toBe(100);
			expect(event.finalPoints).toBe(200);
			expect(event.multiplier).toBe(2);
			expect(event.label).toBe('Test');
			expect(event.id).toBeDefined();
			expect(event.timestamp).toBeDefined();
		});

		it('adds to recent scores', () => {
			score = createScoreSystem();
			score.addScore(100, 'First');
			score.addScore(200, 'Second');
			
			expect(score.state.recentScores).toHaveLength(2);
			expect(score.state.recentScores[0].label).toBe('Second'); // Most recent first
			expect(score.state.recentScores[1].label).toBe('First');
		});

		it('limits recent scores', () => {
			score = createScoreSystem({ recentScoresLimit: 3 });
			
			for (let i = 0; i < 5; i++) {
				score.addScore(100, `Score ${i}`);
			}
			
			expect(score.state.recentScores).toHaveLength(3);
			expect(score.state.recentScores[0].label).toBe('Score 4'); // Most recent
		});

		it('rounds final points', () => {
			score = createScoreSystem({ initialMultiplier: 1.5 });
			const event = score.addScore(101);
			expect(event.finalPoints).toBe(152); // 101 * 1.5 = 151.5 -> 152
		});
	});

	describe('addBonus', () => {
		it('adds points without multiplier', () => {
			score = createScoreSystem({ initialMultiplier: 2 });
			score.addBonus(100, 'Bonus');
			expect(score.state.score).toBe(100); // Not 200
		});

		it('returns score event with multiplier of 1', () => {
			score = createScoreSystem({ initialMultiplier: 2 });
			const event = score.addBonus(100);
			
			expect(event.multiplier).toBe(1);
			expect(event.basePoints).toBe(100);
			expect(event.finalPoints).toBe(100);
		});
	});
});

// ============================================================================
// COMBO TESTS
// ============================================================================

describe('combo system', () => {
	let score: ScoreSystem;

	beforeEach(() => {
		vi.useFakeTimers();
	});

	afterEach(() => {
		score?.cleanup();
		vi.restoreAllMocks();
	});

	describe('incrementCombo', () => {
		it('increases combo count', () => {
			score = createScoreSystem();
			score.incrementCombo();
			expect(score.state.combo).toBe(1);
			
			score.incrementCombo();
			expect(score.state.combo).toBe(2);
		});

		it('tracks max combo', () => {
			score = createScoreSystem();
			score.incrementCombo();
			score.incrementCombo();
			score.incrementCombo();
			expect(score.state.maxCombo).toBe(3);
			
			score.breakCombo();
			score.incrementCombo();
			expect(score.state.maxCombo).toBe(3); // Still 3
		});

		it('respects max combo limit', () => {
			score = createScoreSystem({ maxCombo: 5 });
			
			for (let i = 0; i < 10; i++) {
				score.incrementCombo();
			}
			
			expect(score.state.combo).toBe(5);
		});
	});

	describe('breakCombo', () => {
		it('resets combo to zero', () => {
			score = createScoreSystem();
			score.incrementCombo();
			score.incrementCombo();
			score.breakCombo();
			expect(score.state.combo).toBe(0);
		});

		it('preserves max combo', () => {
			score = createScoreSystem();
			score.incrementCombo();
			score.incrementCombo();
			score.incrementCombo();
			score.breakCombo();
			expect(score.state.maxCombo).toBe(3);
		});
	});

	describe('combo multiplier bonus', () => {
		it('increases multiplier with combo', () => {
			score = createScoreSystem({ 
				initialMultiplier: 1,
				comboMultiplierBonus: 0.1 // +0.1x per combo
			});
			
			score.incrementCombo();
			expect(score.state.multiplier).toBeCloseTo(1.1, 5);
			
			score.incrementCombo();
			expect(score.state.multiplier).toBeCloseTo(1.2, 5);
		});

		it('resets multiplier when combo breaks', () => {
			score = createScoreSystem({ 
				initialMultiplier: 1,
				comboMultiplierBonus: 0.1
			});
			
			score.incrementCombo();
			score.incrementCombo();
			score.breakCombo();
			
			expect(score.state.multiplier).toBe(1);
		});
	});

	describe('combo decay', () => {
		it('auto-breaks combo after decay time', () => {
			score = createScoreSystem({ comboDecay: 2000 });
			
			score.incrementCombo();
			expect(score.state.combo).toBe(1);
			
			vi.advanceTimersByTime(2100);
			
			expect(score.state.combo).toBe(0);
		});

		it('resets decay timer on new combo', () => {
			score = createScoreSystem({ comboDecay: 2000 });
			
			score.incrementCombo();
			vi.advanceTimersByTime(1500); // Not yet decayed
			
			score.incrementCombo(); // Resets timer
			vi.advanceTimersByTime(1500); // Total 3000ms, but timer reset
			
			expect(score.state.combo).toBe(2); // Still active
			
			vi.advanceTimersByTime(600); // Now decays (total 2100ms since last increment)
			expect(score.state.combo).toBe(0);
		});
	});
});

// ============================================================================
// STREAK TESTS
// ============================================================================

describe('streak system', () => {
	let score: ScoreSystem;

	beforeEach(() => {
		score = createScoreSystem();
	});

	afterEach(() => {
		score?.cleanup();
	});

	describe('incrementStreak', () => {
		it('increases streak count', () => {
			score.incrementStreak();
			expect(score.state.streak).toBe(1);
			
			score.incrementStreak();
			expect(score.state.streak).toBe(2);
		});

		it('tracks max streak', () => {
			score.incrementStreak();
			score.incrementStreak();
			score.incrementStreak();
			expect(score.state.maxStreak).toBe(3);
		});
	});

	describe('breakStreak', () => {
		it('resets streak to zero', () => {
			score.incrementStreak();
			score.incrementStreak();
			score.breakStreak();
			expect(score.state.streak).toBe(0);
		});

		it('preserves max streak', () => {
			score.incrementStreak();
			score.incrementStreak();
			score.incrementStreak();
			score.breakStreak();
			expect(score.state.maxStreak).toBe(3);
		});
	});
});

// ============================================================================
// MULTIPLIER TESTS
// ============================================================================

describe('multiplier system', () => {
	let score: ScoreSystem;

	beforeEach(() => {
		vi.useFakeTimers();
	});

	afterEach(() => {
		score?.cleanup();
		vi.restoreAllMocks();
	});

	describe('setMultiplier', () => {
		it('sets base multiplier', () => {
			score = createScoreSystem();
			score.setMultiplier(3);
			expect(score.state.baseMultiplier).toBe(3);
			expect(score.state.multiplier).toBe(3);
		});
	});

	describe('addMultiplierModifier', () => {
		it('adds to multiplier', () => {
			score = createScoreSystem({ initialMultiplier: 1 });
			score.addMultiplierModifier(0.5);
			expect(score.state.multiplier).toBe(1.5);
		});

		it('stacks multiple modifiers', () => {
			score = createScoreSystem({ initialMultiplier: 1 });
			score.addMultiplierModifier(0.5);
			score.addMultiplierModifier(0.3);
			expect(score.state.multiplier).toBeCloseTo(1.8, 5);
		});

		it('removes modifier after duration', () => {
			score = createScoreSystem({ initialMultiplier: 1 });
			score.addMultiplierModifier(0.5, 5000);
			
			expect(score.state.multiplier).toBe(1.5);
			
			vi.advanceTimersByTime(5100);
			
			expect(score.state.multiplier).toBe(1);
		});

		it('permanent modifier without duration', () => {
			score = createScoreSystem({ initialMultiplier: 1 });
			score.addMultiplierModifier(0.5); // No duration
			
			vi.advanceTimersByTime(100000);
			
			expect(score.state.multiplier).toBe(1.5);
		});

		it('combines with combo bonus', () => {
			score = createScoreSystem({ 
				initialMultiplier: 1,
				comboMultiplierBonus: 0.1
			});
			
			score.incrementCombo(); // +0.1
			score.addMultiplierModifier(0.5); // +0.5
			
			expect(score.state.multiplier).toBeCloseTo(1.6, 5);
		});
	});
});

// ============================================================================
// RESET TESTS
// ============================================================================

describe('reset', () => {
	let score: ScoreSystem;

	beforeEach(() => {
		vi.useFakeTimers();
	});

	afterEach(() => {
		score?.cleanup();
		vi.restoreAllMocks();
	});

	it('resets all state', () => {
		score = createScoreSystem({ initialMultiplier: 1 });
		
		score.addScore(100);
		score.incrementCombo();
		score.incrementStreak();
		score.addMultiplierModifier(0.5);
		
		score.reset();
		
		expect(score.state.score).toBe(0);
		expect(score.state.combo).toBe(0);
		expect(score.state.maxCombo).toBe(0);
		expect(score.state.streak).toBe(0);
		expect(score.state.maxStreak).toBe(0);
		expect(score.state.multiplier).toBe(1);
		expect(score.state.recentScores).toHaveLength(0);
	});

	it('clears timers', () => {
		score = createScoreSystem({ comboDecay: 2000 });
		
		score.incrementCombo();
		score.reset();
		
		vi.advanceTimersByTime(5000);
		
		// Should not try to break combo (already reset)
		expect(score.state.combo).toBe(0);
	});
});
