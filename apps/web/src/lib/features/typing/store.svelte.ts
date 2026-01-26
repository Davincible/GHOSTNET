/**
 * Typing Game Store (Trace Evasion)
 * ==================================
 * State machine for the typing mini-game that reduces death rate.
 *
 * States: idle → countdown → active → roundComplete → ... → complete → idle
 *
 * The game consists of multiple rounds (default 5), with cumulative scoring.
 */

import type { TypingChallenge, TypingResult } from '$lib/core/types';

// ════════════════════════════════════════════════════════════════
// CONFIGURATION
// ════════════════════════════════════════════════════════════════

/** Number of rounds per game */
export const TOTAL_ROUNDS = 3;

/** Delay between rounds (ms) */
const ROUND_TRANSITION_DELAY = 1500;

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

/** Result for a single round */
export interface RoundResult {
	/** Accuracy for this round (0-1) */
	accuracy: number;
	/** WPM for this round */
	wpm: number;
	/** Time elapsed in ms */
	timeElapsed: number;
	/** Correct characters */
	correctChars: number;
	/** Total characters typed */
	totalChars: number;
	/** Whether round was completed (vs timed out) */
	completed: boolean;
}

/** Complete result after all rounds */
export interface TypingGameResult {
	/** Final accuracy (0-1) - average across rounds */
	accuracy: number;
	/** Average WPM across rounds */
	wpm: number;
	/** Total time elapsed in milliseconds */
	timeElapsed: number;
	/** Whether all challenges were completed (vs any timed out) */
	completed: boolean;
	/** Number of rounds completed */
	roundsCompleted: number;
	/** Total rounds */
	totalRounds: number;
	/** Per-round results */
	roundResults: RoundResult[];
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
	| { status: 'countdown'; secondsLeft: number; currentRound: number; totalRounds: number }
	| {
			status: 'active';
			challenge: TypingChallenge;
			progress: TypingProgress;
			currentRound: number;
			totalRounds: number;
	  }
	| {
			status: 'roundComplete';
			lastRoundResult: RoundResult;
			currentRound: number;
			totalRounds: number;
	  }
	| { status: 'complete'; result: TypingGameResult };

// ════════════════════════════════════════════════════════════════
// REWARD CALCULATION
// ════════════════════════════════════════════════════════════════

/** Reward tiers based on accuracy */
const ACCURACY_TIERS = [
	{ minAccuracy: 1.0, reduction: -0.25, label: 'PERFECT -25%' },
	{ minAccuracy: 0.95, reduction: -0.2, label: 'Excellent -20%' },
	{ minAccuracy: 0.85, reduction: -0.15, label: 'Great -15%' },
	{ minAccuracy: 0.7, reduction: -0.1, label: 'Good -10%' },
	{ minAccuracy: 0.5, reduction: -0.05, label: 'Okay -5%' },
] as const;

/** Speed bonus tiers */
const SPEED_BONUSES = [
	{ minWpm: 100, minAccuracy: 0.95, bonus: -0.1, label: '+Speed Master -10%' },
	{ minWpm: 80, minAccuracy: 0.95, bonus: -0.05, label: '+Speed Bonus -5%' },
] as const;

/**
 * Calculate reward based on accuracy and WPM
 */
export function calculateReward(accuracy: number, wpm: number): TypingGameResult['reward'] {
	// Find accuracy tier
	const tier = ACCURACY_TIERS.find((t) => accuracy >= t.minAccuracy);
	if (!tier) return null;

	let totalReduction = tier.reduction;
	let label: string = tier.label;

	// Check for speed bonus
	const speedBonus = SPEED_BONUSES.find((b) => wpm >= b.minWpm && accuracy >= b.minAccuracy);
	if (speedBonus) {
		totalReduction += speedBonus.bonus;
		label = `${tier.label} ${speedBonus.label}`;
	}

	return {
		type: 'death_rate_reduction',
		value: totalReduction,
		label,
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
	/** Start the game with a challenge generator function */
	start(getChallenges: () => TypingChallenge[]): void;
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
	let transitionTimeout: ReturnType<typeof setTimeout> | null = null;

	// Challenges for all rounds
	let challenges: TypingChallenge[] = [];
	let currentRoundIndex = 0;

	// Accumulated results across rounds
	let roundResults: RoundResult[] = [];
	let totalTimeElapsed = 0;

	// ─────────────────────────────────────────────────────────────
	// CLEANUP
	// ─────────────────────────────────────────────────────────────

	function clearTimers(): void {
		if (countdownInterval) {
			clearInterval(countdownInterval);
			countdownInterval = null;
		}
		if (timeInterval) {
			clearInterval(timeInterval);
			timeInterval = null;
		}
		if (transitionTimeout) {
			clearTimeout(transitionTimeout);
			transitionTimeout = null;
		}
	}

	// ─────────────────────────────────────────────────────────────
	// STATE TRANSITIONS
	// ─────────────────────────────────────────────────────────────

	/**
	 * Start game: idle → countdown (round 1)
	 */
	function start(getChallenges: () => TypingChallenge[]): void {
		if (state.status !== 'idle') return;

		clearTimers();

		// Get all challenges upfront
		challenges = getChallenges();
		currentRoundIndex = 0;
		roundResults = [];
		totalTimeElapsed = 0;

		// Start countdown for first round
		startCountdown();
	}

	/**
	 * Start countdown for current round
	 */
	function startCountdown(): void {
		clearTimers();

		const totalRounds = challenges.length;
		const currentRound = currentRoundIndex + 1;

		state = {
			status: 'countdown',
			secondsLeft: 3,
			currentRound,
			totalRounds,
		};

		countdownInterval = setInterval(() => {
			if (state.status !== 'countdown') {
				clearTimers();
				return;
			}

			if (state.secondsLeft <= 1) {
				transitionToActive();
			} else {
				state = {
					...state,
					secondsLeft: state.secondsLeft - 1,
				};
			}
		}, 1000);
	}

	/**
	 * Transition from countdown to active
	 */
	function transitionToActive(): void {
		clearTimers();

		const challenge = challenges[currentRoundIndex];
		if (!challenge) {
			state = { status: 'idle' };
			return;
		}

		const now = Date.now();
		const totalRounds = challenges.length;
		const currentRound = currentRoundIndex + 1;

		state = {
			status: 'active',
			challenge,
			currentRound,
			totalRounds,
			progress: {
				typed: '',
				correctChars: 0,
				errorChars: 0,
				startTime: now,
				currentTime: now,
			},
		};

		// Time tracking interval
		timeInterval = setInterval(() => {
			if (state.status !== 'active') {
				clearTimers();
				return;
			}

			const elapsed = Date.now() - state.progress.startTime;
			const timeLimit = state.challenge.timeLimit * 1000;

			if (elapsed >= timeLimit) {
				completeRound(false);
			} else {
				state = {
					...state,
					progress: {
						...state.progress,
						currentTime: Date.now(),
					},
				};
			}
		}, 100);
	}

	/**
	 * Handle keystroke during active state
	 */
	function handleKey(key: string): void {
		if (state.status !== 'active') return;

		const { progress, currentRound, totalRounds, challenge } = state;
		const targetChar = challenge.command[progress.typed.length];

		// Ignore if already complete
		if (progress.typed.length >= challenge.command.length) return;

		// Handle backspace
		if (key === 'Backspace' && progress.typed.length > 0) {
			const lastChar = progress.typed[progress.typed.length - 1];
			const wasCorrect = lastChar === challenge.command[progress.typed.length - 1];

			state = {
				status: 'active',
				challenge,
				currentRound,
				totalRounds,
				progress: {
					...progress,
					typed: progress.typed.slice(0, -1),
					correctChars: wasCorrect ? progress.correctChars - 1 : progress.correctChars,
					errorChars: wasCorrect ? progress.errorChars : progress.errorChars - 1,
					currentTime: Date.now(),
				},
			};
			return;
		}

		// Only process printable characters
		if (key.length !== 1) return;

		const isCorrect = key === targetChar;
		const newTyped = progress.typed + key;

		state = {
			status: 'active',
			challenge,
			currentRound,
			totalRounds,
			progress: {
				...progress,
				typed: newTyped,
				correctChars: progress.correctChars + (isCorrect ? 1 : 0),
				errorChars: progress.errorChars + (isCorrect ? 0 : 1),
				currentTime: Date.now(),
			},
		};

		// Check if round complete
		if (newTyped.length >= challenge.command.length) {
			completeRound(true);
		}
	}

	/**
	 * Complete current round
	 */
	function completeRound(completed: boolean): void {
		if (state.status !== 'active') return;

		clearTimers();

		const { progress, currentRound, totalRounds } = state;
		const timeElapsed = progress.currentTime - progress.startTime;
		const totalChars = progress.typed.length;
		const accuracy = calculateAccuracy(progress.correctChars, totalChars);
		const wpm = calculateWpm(progress.correctChars, timeElapsed);

		// Store round result
		const roundResult: RoundResult = {
			accuracy,
			wpm,
			timeElapsed,
			correctChars: progress.correctChars,
			totalChars,
			completed,
		};
		roundResults.push(roundResult);
		totalTimeElapsed += timeElapsed;

		// Check if more rounds
		const hasMoreRounds = currentRoundIndex < challenges.length - 1;

		if (hasMoreRounds) {
			// Show round complete briefly, then start next round
			state = {
				status: 'roundComplete',
				lastRoundResult: roundResult,
				currentRound,
				totalRounds,
			};

			// Auto-advance to next round after delay
			transitionTimeout = setTimeout(() => {
				currentRoundIndex++;
				startCountdown();
			}, ROUND_TRANSITION_DELAY);
		} else {
			// All rounds done - calculate final result
			completeGame();
		}
	}

	/**
	 * Complete the entire game and calculate aggregate results
	 */
	function completeGame(): void {
		clearTimers();

		// Calculate aggregate stats
		const totalCorrectChars = roundResults.reduce((sum, r) => sum + r.correctChars, 0);
		const totalChars = roundResults.reduce((sum, r) => sum + r.totalChars, 0);
		const avgAccuracy = calculateAccuracy(totalCorrectChars, totalChars);
		const avgWpm = Math.round(
			roundResults.reduce((sum, r) => sum + r.wpm, 0) / roundResults.length
		);
		const allCompleted = roundResults.every((r) => r.completed);

		const reward = calculateReward(avgAccuracy, avgWpm);

		state = {
			status: 'complete',
			result: {
				accuracy: avgAccuracy,
				wpm: avgWpm,
				timeElapsed: totalTimeElapsed,
				completed: allCompleted,
				roundsCompleted: roundResults.filter((r) => r.completed).length,
				totalRounds: challenges.length,
				roundResults,
				reward,
			},
		};
	}

	/**
	 * Reset to idle state
	 */
	function reset(): void {
		clearTimers();
		challenges = [];
		currentRoundIndex = 0;
		roundResults = [];
		totalTimeElapsed = 0;
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
			reward: state.result.reward,
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
		getResult,
	};
}
