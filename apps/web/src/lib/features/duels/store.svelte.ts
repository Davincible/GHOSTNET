/**
 * PvP Duels Store
 * ================
 * State machine for managing duel lifecycle from lobby to results.
 *
 * States: idle → creating → waiting → countdown → active → complete
 */

import type {
	Duel,
	DuelPlayerResult,
	DuelStats,
	DuelHistoryEntry,
	CreateDuelParams,
} from '$lib/core/types';
import { DUEL_COUNTDOWN_SECONDS, calculateDuelWinnings } from '$lib/core/types/duel';
import {
	generateOpenChallenges,
	generateUserChallenges,
	generateDuelHistory,
	generateDuelStats,
	simulateCreateDuel,
	simulateAcceptDuel,
	simulateStartDuel,
	simulateCompleteDuel,
	createOpponentSimulator,
} from '$lib/core/providers/mock/generators/duel';

// ════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════

/** Typing progress during active duel */
export interface DuelTypingProgress {
	/** Characters typed so far */
	typed: string;
	/** Number of correct characters */
	correctChars: number;
	/** Number of error characters */
	errorChars: number;
	/** Timestamp when typing started */
	startTime: number;
	/** Current timestamp for elapsed calculation */
	currentTime: number;
}

/** Discriminated union for duel game state */
export type DuelGameState =
	| { status: 'idle' }
	| { status: 'creating' }
	| { status: 'waiting'; duel: Duel }
	| { status: 'countdown'; duel: Duel; secondsLeft: number }
	| {
			status: 'active';
			duel: Duel;
			yourProgress: DuelTypingProgress;
			opponentProgress: number;
	  }
	| { status: 'complete'; duel: Duel; youWon: boolean; payout: bigint };

// ════════════════════════════════════════════════════════════════
// STORE INTERFACE
// ════════════════════════════════════════════════════════════════

export interface DuelStore {
	/** Current game state (reactive) */
	readonly state: DuelGameState;
	/** Open challenges from other players (reactive) */
	readonly openChallenges: Duel[];
	/** Your pending challenges (reactive) */
	readonly yourChallenges: Duel[];
	/** Duel history (reactive) */
	readonly history: DuelHistoryEntry[];
	/** Your duel statistics (reactive) */
	readonly stats: DuelStats;

	/** Refresh lobby data */
	refreshLobby(): void;
	/** Create a new duel challenge */
	createDuel(params: CreateDuelParams): Promise<void>;
	/** Accept an open challenge */
	acceptDuel(duel: Duel): Promise<void>;
	/** Cancel your pending challenge */
	cancelDuel(duelId: string): void;
	/** Handle keystroke during active duel */
	handleKey(key: string): void;
	/** Reset to idle state */
	reset(): void;
}

// ════════════════════════════════════════════════════════════════
// STORE FACTORY
// ════════════════════════════════════════════════════════════════

export function createDuelStore(): DuelStore {
	// ─────────────────────────────────────────────────────────────
	// STATE
	// ─────────────────────────────────────────────────────────────

	let state = $state<DuelGameState>({ status: 'idle' });
	let openChallenges = $state<Duel[]>([]);
	let yourChallenges = $state<Duel[]>([]);
	// Use $state.raw since history is replaced entirely, not mutated
	let history = $state.raw<DuelHistoryEntry[]>([]);
	let stats = $state<DuelStats>(generateDuelStats());

	// Timers
	let countdownInterval: ReturnType<typeof setInterval> | null = null;
	let timeInterval: ReturnType<typeof setInterval> | null = null;
	let opponentAcceptTimeout: ReturnType<typeof setTimeout> | null = null;

	// Opponent simulator
	let opponentSim: { start: () => void; stop: () => void } | null = null;

	// ─────────────────────────────────────────────────────────────
	// INITIALIZATION
	// ─────────────────────────────────────────────────────────────

	function refreshLobby(): void {
		openChallenges = generateOpenChallenges(5);
		yourChallenges = generateUserChallenges();
		history = generateDuelHistory(10);
		stats = generateDuelStats();
	}

	// Initialize on creation
	refreshLobby();

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
		if (opponentAcceptTimeout) {
			clearTimeout(opponentAcceptTimeout);
			opponentAcceptTimeout = null;
		}
		if (opponentSim) {
			opponentSim.stop();
			opponentSim = null;
		}
	}

	// ─────────────────────────────────────────────────────────────
	// CREATE DUEL
	// ─────────────────────────────────────────────────────────────

	async function createDuel(params: CreateDuelParams): Promise<void> {
		if (state.status !== 'idle') return;

		state = { status: 'creating' };

		// Simulate transaction delay
		await sleep(800);

		const duel = simulateCreateDuel(params);

		// Add to your challenges
		yourChallenges = [duel, ...yourChallenges];

		// If it's an open challenge, wait for opponent
		state = { status: 'waiting', duel };

		// Simulate an opponent accepting after a short delay (for demo)
		opponentAcceptTimeout = setTimeout(
			() => {
				if (state.status === 'waiting' && state.duel.id === duel.id) {
					const acceptedDuel = simulateAcceptDuel(duel);
					// Pick a random mock opponent
					acceptedDuel.opponent = '0x9c2d3b1a8f2e4c5d6a7b8c9d0e1f2a3b4c5d6e7f';
					acceptedDuel.opponentName = 'ByteSlayer';
					acceptedDuel.status = 'accepted';

					startCountdown(acceptedDuel);
				}
			},
			2000 + Math.random() * 3000
		);
	}

	// ─────────────────────────────────────────────────────────────
	// ACCEPT DUEL
	// ─────────────────────────────────────────────────────────────

	async function acceptDuel(duel: Duel): Promise<void> {
		if (state.status !== 'idle') return;

		state = { status: 'creating' };

		// Simulate transaction delay
		await sleep(600);

		const acceptedDuel = simulateAcceptDuel(duel);
		acceptedDuel.status = 'accepted';

		// Remove from open challenges
		openChallenges = openChallenges.filter((c) => c.id !== duel.id);

		startCountdown(acceptedDuel);
	}

	// ─────────────────────────────────────────────────────────────
	// CANCEL DUEL
	// ─────────────────────────────────────────────────────────────

	function cancelDuel(duelId: string): void {
		// Remove from your challenges
		yourChallenges = yourChallenges.filter((c) => c.id !== duelId);

		// If we're waiting on this duel, go back to idle
		if (state.status === 'waiting' && state.duel.id === duelId) {
			state = { status: 'idle' };
		}
	}

	// ─────────────────────────────────────────────────────────────
	// COUNTDOWN
	// ─────────────────────────────────────────────────────────────

	function startCountdown(duel: Duel): void {
		clearTimers();

		state = {
			status: 'countdown',
			duel,
			secondsLeft: DUEL_COUNTDOWN_SECONDS,
		};

		countdownInterval = setInterval(() => {
			if (state.status !== 'countdown') {
				clearTimers();
				return;
			}

			if (state.secondsLeft <= 1) {
				startDuel(state.duel);
			} else {
				state = {
					...state,
					secondsLeft: state.secondsLeft - 1,
				};
			}
		}, 1000);
	}

	// ─────────────────────────────────────────────────────────────
	// ACTIVE DUEL
	// ─────────────────────────────────────────────────────────────

	function startDuel(duel: Duel): void {
		clearTimers();

		const activeDuel = simulateStartDuel(duel);
		const now = Date.now();

		state = {
			status: 'active',
			duel: activeDuel,
			yourProgress: {
				typed: '',
				correctChars: 0,
				errorChars: 0,
				startTime: now,
				currentTime: now,
			},
			opponentProgress: 0,
		};

		// Start time tracking
		timeInterval = setInterval(() => {
			if (state.status !== 'active') {
				clearTimers();
				return;
			}

			const elapsed = Date.now() - state.yourProgress.startTime;
			const timeLimit = state.duel.challenge.timeLimit * 1000;

			if (elapsed >= timeLimit) {
				// Time's up - complete with current progress
				completeWithTimeout();
			} else {
				state = {
					...state,
					yourProgress: {
						...state.yourProgress,
						currentTime: Date.now(),
					},
				};
			}
		}, 100);

		// Start opponent simulation
		opponentSim = createOpponentSimulator(
			activeDuel.tier,
			activeDuel.challenge.command.length,
			(progress) => {
				if (state.status === 'active') {
					state = {
						...state,
						opponentProgress: progress,
					};
				}
			},
			(result) => {
				// Opponent finished - check if we finished too
				if (state.status === 'active') {
					const userProgress = calculateUserProgress();
					if (userProgress >= 100) {
						// We both finished - compare actual finish times
						const userResult = createUserResult(true);
						const youWon = userResult.finishTime <= result.finishTime;
						completeDuel(youWon, result);
					} else {
						// Opponent finished first
						completeDuel(false, result);
					}
				}
			}
		);
		opponentSim.start();
	}

	function calculateUserProgress(): number {
		if (state.status !== 'active') return 0;
		const { duel, yourProgress } = state;
		return Math.min(100, (yourProgress.correctChars / duel.challenge.command.length) * 100);
	}

	// ─────────────────────────────────────────────────────────────
	// TYPING
	// ─────────────────────────────────────────────────────────────

	function handleKey(key: string): void {
		if (state.status !== 'active') return;

		const { duel, yourProgress } = state;
		const { command } = duel.challenge;
		const targetChar = command[yourProgress.typed.length];

		// Ignore if already complete
		if (yourProgress.typed.length >= command.length) return;

		// Handle backspace
		if (key === 'Backspace' && yourProgress.typed.length > 0) {
			const lastChar = yourProgress.typed[yourProgress.typed.length - 1];
			const wasCorrect = lastChar === command[yourProgress.typed.length - 1];

			state = {
				...state,
				yourProgress: {
					...yourProgress,
					typed: yourProgress.typed.slice(0, -1),
					correctChars: wasCorrect
						? Math.max(0, yourProgress.correctChars - 1)
						: yourProgress.correctChars,
					errorChars: wasCorrect
						? yourProgress.errorChars
						: Math.max(0, yourProgress.errorChars - 1),
					currentTime: Date.now(),
				},
			};
			return;
		}

		// Only process printable characters
		if (key.length !== 1) return;

		const isCorrect = key === targetChar;
		const newTyped = yourProgress.typed + key;

		state = {
			...state,
			yourProgress: {
				...yourProgress,
				typed: newTyped,
				correctChars: yourProgress.correctChars + (isCorrect ? 1 : 0),
				errorChars: yourProgress.errorChars + (isCorrect ? 0 : 1),
				currentTime: Date.now(),
			},
		};

		// Check if user completed
		if (yourProgress.correctChars + (isCorrect ? 1 : 0) >= command.length) {
			// User finished first - stop opponent sim
			if (opponentSim) {
				opponentSim.stop();
			}

			// Create mock opponent result (didn't finish)
			const opponentResult: DuelPlayerResult = {
				completed: false,
				accuracy: 0.85,
				wpm: 60,
				timeElapsed: Date.now() - state.yourProgress.startTime,
				finishTime: 0,
				progressPercent: state.opponentProgress,
			};

			completeDuel(true, opponentResult);
		}
	}

	function createUserResult(completed: boolean): DuelPlayerResult {
		if (state.status !== 'active') {
			return {
				completed: false,
				accuracy: 0,
				wpm: 0,
				timeElapsed: 0,
				finishTime: 0,
				progressPercent: 0,
			};
		}

		const { yourProgress, duel } = state;
		const timeElapsed = yourProgress.currentTime - yourProgress.startTime;
		const totalChars = yourProgress.typed.length;
		const accuracy = totalChars > 0 ? yourProgress.correctChars / totalChars : 0;
		const wpm =
			timeElapsed > 0 ? Math.round((yourProgress.correctChars / 5 / timeElapsed) * 60000) : 0;

		return {
			completed,
			accuracy,
			wpm,
			timeElapsed,
			finishTime: completed ? Date.now() : 0,
			progressPercent: Math.min(
				100,
				(yourProgress.correctChars / duel.challenge.command.length) * 100
			),
		};
	}

	function completeWithTimeout(): void {
		if (state.status !== 'active') return;

		const userResult = createUserResult(false);
		const opponentResult: DuelPlayerResult = {
			completed: state.opponentProgress >= 100,
			accuracy: 0.85,
			wpm: 65,
			timeElapsed: state.duel.challenge.timeLimit * 1000,
			finishTime: state.opponentProgress >= 100 ? Date.now() - 1000 : 0,
			progressPercent: state.opponentProgress,
		};

		completeDuel(userResult.progressPercent > state.opponentProgress, opponentResult);
	}

	// ─────────────────────────────────────────────────────────────
	// COMPLETE
	// ─────────────────────────────────────────────────────────────

	function completeDuel(youWon: boolean, opponentResult: DuelPlayerResult): void {
		if (state.status !== 'active') return;

		clearTimers();

		const userResult = createUserResult(youWon || calculateUserProgress() >= 100);
		const completedDuel = simulateCompleteDuel(state.duel, userResult, opponentResult);

		const { payout } = calculateDuelWinnings(completedDuel.wagerAmount);

		state = {
			status: 'complete',
			duel: completedDuel,
			youWon,
			payout: youWon ? payout : 0n,
		};

		// Add to history
		const netAmount = youWon ? payout - completedDuel.wagerAmount : -completedDuel.wagerAmount;
		history = [{ duel: completedDuel, youWon, netAmount }, ...history].slice(0, 50);

		// Update stats
		if (youWon) {
			stats = {
				...stats,
				totalDuels: stats.totalDuels + 1,
				wins: stats.wins + 1,
				totalWon: stats.totalWon + payout,
				winRate: (stats.wins + 1) / (stats.totalDuels + 1),
				currentStreak: stats.currentStreak > 0 ? stats.currentStreak + 1 : 1,
				bestStreak: Math.max(stats.bestStreak, stats.currentStreak + 1),
				bestWpm: Math.max(stats.bestWpm, userResult.wpm),
			};
		} else {
			stats = {
				...stats,
				totalDuels: stats.totalDuels + 1,
				losses: stats.losses + 1,
				totalLost: stats.totalLost + completedDuel.wagerAmount,
				winRate: stats.wins / (stats.totalDuels + 1),
				currentStreak: stats.currentStreak < 0 ? stats.currentStreak - 1 : -1,
			};
		}
	}

	// ─────────────────────────────────────────────────────────────
	// RESET
	// ─────────────────────────────────────────────────────────────

	function reset(): void {
		clearTimers();
		state = { status: 'idle' };
	}

	// ─────────────────────────────────────────────────────────────
	// RETURN INTERFACE
	// ─────────────────────────────────────────────────────────────

	return {
		get state() {
			return state;
		},
		get openChallenges() {
			return openChallenges;
		},
		get yourChallenges() {
			return yourChallenges;
		},
		get history() {
			return history;
		},
		get stats() {
			return stats;
		},
		refreshLobby,
		createDuel,
		acceptDuel,
		cancelDuel,
		handleKey,
		reset,
	};
}

// ════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════

function sleep(ms: number): Promise<void> {
	return new Promise((resolve) => setTimeout(resolve, ms));
}
