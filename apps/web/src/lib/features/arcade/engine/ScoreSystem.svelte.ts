/**
 * Score System - Points, Multipliers, Combos
 * ==========================================
 * Provides scoring utilities for arcade games:
 * - Point accumulation with multipliers
 * - Combo tracking with decay
 * - Streak counting (consecutive successes)
 * - High score tracking
 */

import type { ScoreState, ScoreEvent, ScoreConfig } from '$lib/core/types/arcade';

// ============================================================================
// STORE INTERFACE
// ============================================================================

export interface ScoreSystem {
	/** Current state (reactive) */
	readonly state: ScoreState;
	/** Add points with optional label */
	addScore(points: number, label?: string): ScoreEvent;
	/** Add points without affecting combo */
	addBonus(points: number, label?: string): ScoreEvent;
	/** Increment combo */
	incrementCombo(): void;
	/** Reset combo to 0 */
	breakCombo(): void;
	/** Increment streak */
	incrementStreak(): void;
	/** Reset streak to 0 */
	breakStreak(): void;
	/** Set base multiplier */
	setMultiplier(value: number): void;
	/** Add temporary multiplier modifier */
	addMultiplierModifier(modifier: number, duration?: number): void;
	/** Reset all scores */
	reset(): void;
	/** Cleanup timers */
	cleanup(): void;
}

// ============================================================================
// STORE FACTORY
// ============================================================================

let scoreIdCounter = 0;

/**
 * Create a score system instance.
 *
 * @example
 * ```typescript
 * const score = createScoreSystem({
 *   comboDecay: 2000,
 *   comboMultiplierBonus: 0.1, // +0.1x per combo level
 * });
 *
 * // On successful action
 * score.incrementCombo();
 * score.addScore(100, 'Perfect hit!');
 *
 * // On failure
 * score.breakCombo();
 * ```
 */
export function createScoreSystem(config: ScoreConfig = {}): ScoreSystem {
	const {
		initialMultiplier = 1,
		comboDecay = 0,
		maxCombo = 0,
		comboMultiplierBonus = 0,
		recentScoresLimit = 10
	} = config;

	// -------------------------------------------------------------------------
	// STATE
	// -------------------------------------------------------------------------

	let state = $state<ScoreState>({
		score: 0,
		multiplier: initialMultiplier,
		baseMultiplier: initialMultiplier,
		combo: 0,
		maxCombo: 0,
		streak: 0,
		maxStreak: 0,
		recentScores: []
	});

	// Timers
	let comboDecayTimer: ReturnType<typeof setTimeout> | null = null;
	const multiplierModifiers: Array<{ value: number; timerId?: ReturnType<typeof setTimeout> }> = [];

	// -------------------------------------------------------------------------
	// HELPERS
	// -------------------------------------------------------------------------

	function calculateMultiplier(): number {
		let mult = state.baseMultiplier;

		// Combo bonus
		if (comboMultiplierBonus > 0) {
			mult += state.combo * comboMultiplierBonus;
		}

		// Temporary modifiers
		for (const mod of multiplierModifiers) {
			mult += mod.value;
		}

		return Math.max(0, mult);
	}

	function updateMultiplier(): void {
		state = { ...state, multiplier: calculateMultiplier() };
	}

	function resetComboDecayTimer(): void {
		if (comboDecayTimer) {
			clearTimeout(comboDecayTimer);
			comboDecayTimer = null;
		}

		if (comboDecay > 0 && state.combo > 0) {
			comboDecayTimer = setTimeout(() => {
				breakCombo();
			}, comboDecay);
		}
	}

	function generateScoreId(): string {
		return `score-${++scoreIdCounter}-${Date.now()}`;
	}

	// -------------------------------------------------------------------------
	// SCORING
	// -------------------------------------------------------------------------

	function addScore(points: number, label?: string): ScoreEvent {
		const multiplier = state.multiplier;
		const finalPoints = Math.round(points * multiplier);

		const event: ScoreEvent = {
			id: generateScoreId(),
			basePoints: points,
			finalPoints,
			multiplier,
			combo: state.combo,
			timestamp: Date.now(),
			label
		};

		state = {
			...state,
			score: state.score + finalPoints,
			recentScores: [event, ...state.recentScores.slice(0, recentScoresLimit - 1)]
		};

		return event;
	}

	function addBonus(points: number, label?: string): ScoreEvent {
		// Bonus doesn't use multiplier
		const event: ScoreEvent = {
			id: generateScoreId(),
			basePoints: points,
			finalPoints: points,
			multiplier: 1,
			combo: state.combo,
			timestamp: Date.now(),
			label
		};

		state = {
			...state,
			score: state.score + points,
			recentScores: [event, ...state.recentScores.slice(0, recentScoresLimit - 1)]
		};

		return event;
	}

	// -------------------------------------------------------------------------
	// COMBO
	// -------------------------------------------------------------------------

	function incrementCombo(): void {
		let newCombo = state.combo + 1;

		if (maxCombo > 0 && newCombo > maxCombo) {
			newCombo = maxCombo;
		}

		state = {
			...state,
			combo: newCombo,
			maxCombo: Math.max(state.maxCombo, newCombo)
		};

		updateMultiplier();
		resetComboDecayTimer();
	}

	function breakCombo(): void {
		if (comboDecayTimer) {
			clearTimeout(comboDecayTimer);
			comboDecayTimer = null;
		}

		state = { ...state, combo: 0 };
		updateMultiplier();
	}

	// -------------------------------------------------------------------------
	// STREAK
	// -------------------------------------------------------------------------

	function incrementStreak(): void {
		const newStreak = state.streak + 1;
		state = {
			...state,
			streak: newStreak,
			maxStreak: Math.max(state.maxStreak, newStreak)
		};
	}

	function breakStreak(): void {
		state = { ...state, streak: 0 };
	}

	// -------------------------------------------------------------------------
	// MULTIPLIER
	// -------------------------------------------------------------------------

	function setMultiplier(value: number): void {
		state = { ...state, baseMultiplier: value };
		updateMultiplier();
	}

	function addMultiplierModifier(modifier: number, duration?: number): void {
		const entry: { value: number; timerId?: ReturnType<typeof setTimeout> } = {
			value: modifier
		};

		if (duration) {
			entry.timerId = setTimeout(() => {
				const index = multiplierModifiers.indexOf(entry);
				if (index > -1) {
					multiplierModifiers.splice(index, 1);
					updateMultiplier();
				}
			}, duration);
		}

		multiplierModifiers.push(entry);
		updateMultiplier();
	}

	// -------------------------------------------------------------------------
	// CLEANUP
	// -------------------------------------------------------------------------

	function reset(): void {
		cleanup();
		state = {
			score: 0,
			multiplier: initialMultiplier,
			baseMultiplier: initialMultiplier,
			combo: 0,
			maxCombo: 0,
			streak: 0,
			maxStreak: 0,
			recentScores: []
		};
	}

	function cleanup(): void {
		if (comboDecayTimer) {
			clearTimeout(comboDecayTimer);
			comboDecayTimer = null;
		}

		for (const mod of multiplierModifiers) {
			if (mod.timerId) {
				clearTimeout(mod.timerId);
			}
		}
		multiplierModifiers.length = 0;
	}

	return {
		get state() {
			return state;
		},
		addScore,
		addBonus,
		incrementCombo,
		breakCombo,
		incrementStreak,
		breakStreak,
		setMultiplier,
		addMultiplierModifier,
		reset,
		cleanup
	};
}

// Re-export types for convenience
export type { ScoreState, ScoreEvent, ScoreConfig };
