/**
 * Typing Game Store (Trace Evasion)
 * ==================================
 * State machine for the typing mini-game that reduces death rate.
 *
 * States: idle → countdown → active → complete → idle
 */

import type { TypingChallenge, TypingResult, TypingGameState } from '$lib/core/types';

// ════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════

/** Progress during active typing */
export interface TypingProgress {
	/** Characters typed so far */
	typed: string;
	/** Number of correct characters */
	correctChars: number;
	/** Number of incorrect characters (errors) */
	errorChars: number;
	/** Timestamp when typing started */
	startTime: number;
	/** Current time for elapsed calculation */
	currentTime: number;
}

/** Complete result after typing */
export interface TypingGameResult {
	/** Final accuracy (0-1) */
	accuracy: number;
	/** Words per minute */
	wpm: number;
	/** Time elapsed in milliseconds */
	timeElapsed: number;
	/** Whether the challenge was completed (vs timed out) */
	completed: boolean;
	/** Reward earned, if any */
	reward: {
		type: 'death_rate_reduction';
		value: number;
		label: string;
	} | null;
}

/** Discriminated union for game state */
export type GameState =
	| { status: 'idle' }
	| { status: 'countdown'; secondsLeft: number }
	| { status: 'active'; challenge: TypingChallenge; progress: TypingProgress }
	| { status: 'complete'; challenge: TypingChallenge; result: TypingGameResult };

// ════════════════════════════════════════════════════════════════
// REWARD CALCULATION
// ════════════════════════════════════════════════════════════════

/** Reward tiers based on accuracy */
const ACCURACY_TIERS = [
	{ minAccuracy: 1.0, reduction: -0.25, label: 'PERFECT -25%' },
	{ minAccuracy: 0.95, reduction: -0.20, label: 'Excellent -20%' },
	{ minAccuracy: 0.85, reduction: -0.15, label: 'Great -15%' },
	{ minAccuracy: 0.70, reduction: -0.10, label: 'Good -10%' },
	{ minAccuracy: 0.50, reduction: -0.05, label: 'Okay -5%' }
] as const;

/** Speed bonus tiers */
const SPEED_BONUSES = [
	{ minWpm: 100, minAccuracy: 0.95, bonus: -0.10, label: '+Speed Master -10%' },
	{ minWpm: 80, minAccuracy: 0.95, bonus: -0.05, label: '+Speed Bonus -5%' }
] as const;

/**
 * Calculate reward based on accuracy and WPM
 */
export function calculateReward(
	accuracy: number,
	wpm: number
): TypingGameResult['reward'] {
	// Find accuracy tier
	const tier = ACCURACY_TIERS.find((t) => accuracy >= t.minAccuracy);
	if (!tier) return null;

	let totalReduction = tier.reduction;
	let label: string = tier.label;

	// Check for speed bonus
	const speedBonus = SPEED_BONUSES.find(
		(b) => wpm >= b.minWpm && accuracy >= b.minAccuracy
	);
	if (speedBonus) {
		totalReduction += speedBonus.bonus;
		label = `${tier.label} ${speedBonus.label}`;
	}

	return {
		type: 'death_rate_reduction',
		value: totalReduction,
		label
	};
}

/**
 * Calculate WPM from characters typed and time elapsed
 * Standard: 5 characters = 1 word
 */
export function calculateWpm(charsTyped: number, timeElapsedMs: number): number {
	if (timeElapsedMs <= 0) return 0;
	const minutes = timeElapsedMs / 60000;
	const words = charsTyped / 5;
	return Math.round(words / minutes);
}

/**
 * Calculate accuracy from correct/total characters
 */
export function calculateAccuracy(correct: number, total: number): number {
	if (total <= 0) return 0;
	return correct / total;
}

// ════════════════════════════════════════════════════════════════
// STORE FACTORY
// ════════════════════════════════════════════════════════════════

export interface TypingGameStore {
	/** Current game state (reactive) */
	readonly state: GameState;
	/** Start the game with a challenge */
	start(challenge: TypingChallenge): void;
	/** Handle a keystroke during active state */
	handleKey(key: string): void;
	/** Reset to idle state */
	reset(): void;
	/** Get result for provider submission */
	getResult(): TypingResult | null;
}

/**
 * Create a typing game store instance
 */
export function createTypingGameStore(): TypingGameStore {
	// ─────────────────────────────────────────────────────────────
	// STATE
	// ─────────────────────────────────────────────────────────────

	let state = $state<GameState>({ status: 'idle' });

	// Intervals for countdown and time tracking
	let countdownInterval: ReturnType<typeof setInterval> | null = null;
	let timeInterval: ReturnType<typeof setInterval> | null = null;

	// Challenge stored for transition from countdown to active
	let pendingChallenge: TypingChallenge | null = null;

	// ─────────────────────────────────────────────────────────────
	// CLEANUP
	// ─────────────────────────────────────────────────────────────

	function clearIntervals(): void {
		if (countdownInterval) {
			clearInterval(countdownInterval);
			countdownInterval = null;
		}
		if (timeInterval) {
			clearInterval(timeInterval);
			timeInterval = null;
		}
	}

	// ─────────────────────────────────────────────────────────────
	// STATE TRANSITIONS
	// ─────────────────────────────────────────────────────────────

	/**
	 * Start game: idle → countdown
	 */
	function start(challenge: TypingChallenge): void {
		if (state.status !== 'idle') return;

		clearIntervals();
		pendingChallenge = challenge;
		state = { status: 'countdown', secondsLeft: 3 };

		// Countdown interval
		countdownInterval = setInterval(() => {
			if (state.status !== 'countdown') {
				clearIntervals();
				return;
			}

			if (state.secondsLeft <= 1) {
				// Transition to active
				transitionToActive();
			} else {
				state = { status: 'countdown', secondsLeft: state.secondsLeft - 1 };
			}
		}, 1000);
	}

	/**
	 * Transition from countdown to active
	 */
	function transitionToActive(): void {
		clearIntervals();

		if (!pendingChallenge) {
			state = { status: 'idle' };
			return;
		}

		const now = Date.now();
		state = {
			status: 'active',
			challenge: pendingChallenge,
			progress: {
				typed: '',
				correctChars: 0,
				errorChars: 0,
				startTime: now,
				currentTime: now
			}
		};

		// Time tracking interval
		timeInterval = setInterval(() => {
			if (state.status !== 'active') {
				clearIntervals();
				return;
			}

			const elapsed = Date.now() - state.progress.startTime;
			const timeLimit = state.challenge.timeLimit * 1000;

			if (elapsed >= timeLimit) {
				// Time's up - complete with current progress
				completeGame(false);
			} else {
				// Update current time for display
				state = {
					...state,
					progress: {
						...state.progress,
						currentTime: Date.now()
					}
				};
			}
		}, 100);

		pendingChallenge = null;
	}

	/**
	 * Handle keystroke during active state
	 */
	function handleKey(key: string): void {
		if (state.status !== 'active') return;

		const { challenge, progress } = state;
		const targetChar = challenge.command[progress.typed.length];

		// Ignore if already complete
		if (progress.typed.length >= challenge.command.length) return;

		// Handle backspace
		if (key === 'Backspace' && progress.typed.length > 0) {
			const lastChar = progress.typed[progress.typed.length - 1];
			const wasCorrect = lastChar === challenge.command[progress.typed.length - 1];

			state = {
				...state,
				progress: {
					...progress,
					typed: progress.typed.slice(0, -1),
					correctChars: wasCorrect ? progress.correctChars - 1 : progress.correctChars,
					errorChars: wasCorrect ? progress.errorChars : progress.errorChars - 1,
					currentTime: Date.now()
				}
			};
			return;
		}

		// Only process printable characters
		if (key.length !== 1) return;

		const isCorrect = key === targetChar;
		const newTyped = progress.typed + key;

		state = {
			...state,
			progress: {
				...progress,
				typed: newTyped,
				correctChars: progress.correctChars + (isCorrect ? 1 : 0),
				errorChars: progress.errorChars + (isCorrect ? 0 : 1),
				currentTime: Date.now()
			}
		};

		// Check if complete
		if (newTyped.length >= challenge.command.length) {
			completeGame(true);
		}
	}

	/**
	 * Complete the game and calculate results
	 */
	function completeGame(completed: boolean): void {
		if (state.status !== 'active') return;

		clearIntervals();

		const { challenge, progress } = state;
		const timeElapsed = progress.currentTime - progress.startTime;
		const totalChars = progress.typed.length;
		const accuracy = calculateAccuracy(progress.correctChars, totalChars);
		const wpm = calculateWpm(progress.correctChars, timeElapsed);
		const reward = calculateReward(accuracy, wpm);

		state = {
			status: 'complete',
			challenge,
			result: {
				accuracy,
				wpm,
				timeElapsed,
				completed,
				reward
			}
		};
	}

	/**
	 * Reset to idle state
	 */
	function reset(): void {
		clearIntervals();
		pendingChallenge = null;
		state = { status: 'idle' };
	}

	/**
	 * Get result for provider submission
	 */
	function getResult(): TypingResult | null {
		if (state.status !== 'complete') return null;

		return {
			accuracy: state.result.accuracy,
			wpm: state.result.wpm,
			timeElapsed: state.result.timeElapsed,
			reward: state.result.reward
		};
	}

	// ─────────────────────────────────────────────────────────────
	// RETURN INTERFACE
	// ─────────────────────────────────────────────────────────────

	return {
		get state() {
			return state;
		},
		start,
		handleKey,
		reset,
		getResult
	};
}
