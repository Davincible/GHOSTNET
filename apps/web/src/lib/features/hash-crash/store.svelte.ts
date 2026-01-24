/**
 * HASH CRASH Game Store (Pre-Commit Model)
 * ==========================================
 * State management for the Hash Crash multiplier game.
 *
 * Pre-Commit Game Flow:
 * 1. BETTING  - Players set bet amount AND target multiplier (60 seconds)
 * 2. LOCKED   - Betting closes, waiting for seed block
 * 3. REVEALED - Crash point known, outcome determined instantly
 * 4. ANIMATING - Purely visual animation (outcome already decided)
 * 5. SETTLED  - Round complete, payouts processed
 *
 * Key difference: Players commit to their target BEFORE the crash point is revealed.
 * This eliminates timing advantages and bot sniping.
 */

import { browser } from '$app/environment';
import type { HashCrashRound, HashCrashBet, HashCrashPlayerResult } from '$lib/core/types/arcade';
import { createFrameLoop, createCountdown } from '$lib/features/arcade/engine';

// ============================================================================
// CONFIGURATION
// ============================================================================

/** Betting phase duration in ms (production) */
export const BETTING_DURATION = 60_000;

/** Betting phase duration in ms (simulation/demo) */
export const SIMULATION_BETTING_DURATION = 30_000;

/** Delay between rounds in ms (after loss or no bet) */
export const ROUND_DELAY = 4_000;

/** Delay between rounds in ms (after win - show longer for celebration) */
export const WIN_ROUND_DELAY = 5_000;

/** Multiplier growth rate (e^(rate * seconds)) */
export const GROWTH_RATE = 0.06;

/** Minimum bet in wei (10 $DATA) */
export const MIN_BET = 10n * 10n ** 18n;

/** Maximum bet in wei (1000 $DATA) */
export const MAX_BET = 1000n * 10n ** 18n;

/** Minimum target multiplier */
export const MIN_TARGET = 1.01;

/** Maximum target multiplier */
export const MAX_TARGET = 100;

/** Number of recent crashes to track */
const RECENT_CRASHES_LIMIT = 10;

// ============================================================================
// TYPES
// ============================================================================

export interface HashCrashState {
	/** Current round info */
	round: HashCrashRound | null;
	/** Current display multiplier (animated value) */
	multiplier: number;
	/** Player's bet for current round (includes target) */
	playerBet: HashCrashBet | null;
	/** Player's result for current round */
	playerResult: 'pending' | 'won' | 'lost';
	/** All players' results */
	players: HashCrashPlayerResult[];
	/** History of recent crash points */
	recentCrashPoints: number[];
	/** Connection status */
	isConnected: boolean;
	/** Loading state for transactions */
	isLoading: boolean;
	/** Error message if any */
	error: string | null;
}

export interface HashCrashStore {
	// State (reactive)
	readonly state: HashCrashState;

	// Derived values
	readonly canBet: boolean;
	readonly isAnimating: boolean;
	readonly hasWon: boolean;
	readonly potentialPayout: bigint;
	readonly winProbability: number;
	readonly timeRemaining: number;
	readonly timeDisplay: string;
	readonly isCritical: boolean;

	// Actions
	connect(): () => void;
	disconnect(): void;
	placeBet(amount: bigint, targetMultiplier: number): Promise<void>;

	// For testing/simulation
	_simulateRound(crashPoint: number): void;
}

// ============================================================================
// STORE FACTORY
// ============================================================================

export function createHashCrashStore(): HashCrashStore {
	// ─────────────────────────────────────────────────────────────────────────
	// STATE
	// ─────────────────────────────────────────────────────────────────────────

	let state = $state<HashCrashState>({
		round: null,
		multiplier: 1.0,
		playerBet: null,
		playerResult: 'pending',
		players: [],
		recentCrashPoints: [],
		isConnected: false,
		isLoading: false,
		error: null,
	});

	// Timer for betting phase countdown
	const bettingCountdown = createCountdown({
		duration: BETTING_DURATION,
		criticalThreshold: 10_000,
		onComplete: () => {
			// Betting phase ended - handled by WebSocket or simulation
		},
	});

	// Frame loop for smooth multiplier animation
	let animationStartTime = 0;
	let targetCrashPoint = 0;

	const frameLoop = createFrameLoop((_delta, _time) => {
		if (state.round?.state !== 'animating') return;

		// Calculate multiplier based on elapsed time
		const elapsed = (Date.now() - animationStartTime) / 1000;
		const newMultiplier = Math.pow(Math.E, GROWTH_RATE * elapsed);

		// Check if animation passed player's target (for visual feedback)
		if (
			state.playerBet &&
			state.playerResult === 'pending' &&
			newMultiplier >= state.playerBet.targetMultiplier
		) {
			// Player's target was below crash point = WIN
			if (state.playerBet.targetMultiplier < targetCrashPoint) {
				state = { ...state, playerResult: 'won' };
			}
		}

		// Check if animation reached crash point
		if (newMultiplier >= targetCrashPoint) {
			// Animation complete - show crash
			state = {
				...state,
				multiplier: targetCrashPoint,
				round: state.round ? { ...state.round, state: 'settled' } : null,
			};

			// Mark loss if player's target wasn't reached
			if (state.playerBet && state.playerResult === 'pending') {
				state = { ...state, playerResult: 'lost' };
			}

			frameLoop.stop();
		} else {
			state = { ...state, multiplier: newMultiplier };
		}
	});

	// ─────────────────────────────────────────────────────────────────────────
	// DERIVED STATE
	// ─────────────────────────────────────────────────────────────────────────

	const canBet = $derived(
		state.round?.state === 'betting' && state.playerBet === null && !state.isLoading
	);

	const isAnimating = $derived(state.round?.state === 'animating');

	const hasWon = $derived(state.playerResult === 'won');

	const potentialPayout = $derived(
		state.playerBet
			? BigInt(Math.floor(Number(state.playerBet.amount) * state.playerBet.targetMultiplier))
			: 0n
	);

	// Calculate win probability based on target multiplier
	// Formula: P(win) = 0.96 / target (approximately, with 4% house edge)
	const winProbability = $derived(
		state.playerBet ? Math.min(0.96 / state.playerBet.targetMultiplier, 0.99) : 0
	);

	const timeRemaining = $derived(bettingCountdown.state.remaining);
	const timeDisplay = $derived(bettingCountdown.state.display);
	const isCritical = $derived(bettingCountdown.state.critical);

	// ─────────────────────────────────────────────────────────────────────────
	// WEBSOCKET CONNECTION
	// ─────────────────────────────────────────────────────────────────────────

	let ws: WebSocket | null = null;

	function connect(): () => void {
		if (!browser) return () => {};

		// TODO: Replace with actual WebSocket endpoint
		const wsUrl = 'wss://api.ghostnet.io/arcade/hash-crash';

		try {
			ws = new WebSocket(wsUrl);

			ws.onopen = () => {
				state = { ...state, isConnected: true, error: null };
			};

			ws.onclose = () => {
				state = { ...state, isConnected: false };
				frameLoop.stop();
				bettingCountdown.stop();
			};

			ws.onerror = () => {
				state = { ...state, error: 'Connection error' };
			};

			ws.onmessage = (event) => {
				handleMessage(JSON.parse(event.data));
			};
		} catch {
			state = { ...state, error: 'Failed to connect' };
		}

		return () => disconnect();
	}

	function disconnect(): void {
		if (ws) {
			ws.close();
			ws = null;
		}
		frameLoop.stop();
		bettingCountdown.stop();
		state = { ...state, isConnected: false };
	}

	// ─────────────────────────────────────────────────────────────────────────
	// MESSAGE HANDLERS
	// ─────────────────────────────────────────────────────────────────────────

	interface WSMessage {
		type: string;
		[key: string]: unknown;
	}

	function handleMessage(data: WSMessage): void {
		switch (data.type) {
			case 'ROUND_STATE':
				handleRoundState(data);
				break;

			case 'BET_PLACED':
				handleBetPlaced(data);
				break;

			case 'BET_CONFIRMED':
				handleBetConfirmed(data);
				break;

			case 'ROUND_LOCKED':
				handleRoundLocked();
				break;

			case 'CRASH_REVEALED':
				handleCrashRevealed(data);
				break;

			case 'ROUND_SETTLED':
				handleRoundSettled(data);
				break;

			case 'ERROR':
				state = { ...state, error: String(data.message), isLoading: false };
				break;
		}
	}

	function handleRoundState(data: WSMessage): void {
		const roundData = data.round as HashCrashRound;
		state = {
			...state,
			round: roundData,
			players: (data.players as HashCrashPlayerResult[]) || [],
		};

		if (roundData.state === 'betting') {
			// Calculate remaining time for countdown
			const remaining = roundData.bettingEndsAt - Date.now();
			if (remaining > 0) {
				bettingCountdown.start(remaining);
			}
			state = { ...state, multiplier: 1.0, playerBet: null, playerResult: 'pending' };
		} else if (roundData.state === 'animating' && roundData.crashPoint) {
			startAnimation(roundData.crashPoint);
		}
	}

	function handleBetPlaced(data: WSMessage): void {
		// Another player placed a bet
		const player: HashCrashPlayerResult = {
			address: data.address as `0x${string}`,
			targetMultiplier: data.targetMultiplier as number,
			won: false,
			payout: 0n,
		};
		state = {
			...state,
			players: [...state.players, player],
		};
	}

	function handleBetConfirmed(data: WSMessage): void {
		// Our bet was confirmed
		state = {
			...state,
			playerBet: {
				amount: BigInt(data.amount as string),
				targetMultiplier: data.targetMultiplier as number,
			},
			isLoading: false,
		};
	}

	function handleRoundLocked(): void {
		bettingCountdown.stop();
		state = {
			...state,
			round: state.round ? { ...state.round, state: 'locked' } : null,
		};
	}

	function handleCrashRevealed(data: WSMessage): void {
		const crashPoint = data.crashPoint as number;

		// Immediately determine result (before animation)
		let playerResult: 'pending' | 'won' | 'lost' = 'pending';
		if (state.playerBet) {
			playerResult = state.playerBet.targetMultiplier < crashPoint ? 'won' : 'lost';
		}

		state = {
			...state,
			round: state.round ? { ...state.round, state: 'revealed', crashPoint } : null,
			playerResult,
			recentCrashPoints: [
				crashPoint,
				...state.recentCrashPoints.slice(0, RECENT_CRASHES_LIMIT - 1),
			],
		};

		// Start the animation
		startAnimation(crashPoint);
	}

	function handleRoundSettled(data: WSMessage): void {
		frameLoop.stop();
		state = {
			...state,
			round: state.round ? { ...state.round, state: 'settled' } : null,
			players: (data.results as HashCrashPlayerResult[]) || state.players,
		};
	}

	// ─────────────────────────────────────────────────────────────────────────
	// ANIMATION
	// ─────────────────────────────────────────────────────────────────────────

	function startAnimation(crashPoint: number): void {
		targetCrashPoint = crashPoint;
		animationStartTime = Date.now();
		state = {
			...state,
			multiplier: 1.0,
			round: state.round
				? { ...state.round, state: 'animating', startTime: animationStartTime }
				: null,
		};
		frameLoop.start();
	}

	// ─────────────────────────────────────────────────────────────────────────
	// ACTIONS
	// ─────────────────────────────────────────────────────────────────────────

	async function placeBet(amount: bigint, targetMultiplier: number): Promise<void> {
		if (!canBet) return;

		// Validate bet amount
		if (amount < MIN_BET || amount > MAX_BET) {
			state = { ...state, error: `Bet must be between 10 and 1000 $DATA` };
			return;
		}

		// Validate target multiplier
		if (targetMultiplier < MIN_TARGET || targetMultiplier > MAX_TARGET) {
			state = { ...state, error: `Target must be between ${MIN_TARGET}x and ${MAX_TARGET}x` };
			return;
		}

		// Optimistically set the bet immediately for responsive UI
		// In production with smart contracts, this would be confirmed after tx
		state = {
			...state,
			playerBet: { amount, targetMultiplier },
			isLoading: false,
			error: null,
		};

		// TODO: Call smart contract
		// For now, send via WebSocket (if connected)
		if (ws && ws.readyState === WebSocket.OPEN) {
			ws.send(
				JSON.stringify({
					type: 'PLACE_BET',
					amount: amount.toString(),
					targetMultiplier,
				})
			);
		}
	}

	// ─────────────────────────────────────────────────────────────────────────
	// SIMULATION (for testing/demo)
	// ─────────────────────────────────────────────────────────────────────────

	function _simulateRound(crashPoint: number): void {
		if (!browser) return;

		const roundId = (state.round?.roundId ?? 0) + 1;

		// Start betting phase
		state = {
			...state,
			round: {
				roundId,
				state: 'betting',
				totalBets: 0n,
				playerCount: 0,
				seedBlock: null,
				seedHash: null,
				crashPoint: null,
				startTime: 0,
				bettingEndsAt: Date.now() + SIMULATION_BETTING_DURATION,
			},
			multiplier: 1.0,
			playerBet: null,
			playerResult: 'pending',
			players: [],
		};

		bettingCountdown.start(SIMULATION_BETTING_DURATION);

		// After betting, transition to locked, then reveal
		setTimeout(() => {
			bettingCountdown.stop();

			// Locked phase (waiting for seed block)
			state = {
				...state,
				round: state.round ? { ...state.round, state: 'locked' } : null,
			};

			// After short delay, reveal crash point
			setTimeout(() => {
				// Determine player result immediately on reveal
				let playerResult: 'pending' | 'won' | 'lost' = 'pending';
				if (state.playerBet) {
					playerResult = state.playerBet.targetMultiplier < crashPoint ? 'won' : 'lost';
				}

				state = {
					...state,
					round: state.round ? { ...state.round, state: 'revealed', crashPoint } : null,
					playerResult,
					recentCrashPoints: [
						crashPoint,
						...state.recentCrashPoints.slice(0, RECENT_CRASHES_LIMIT - 1),
					],
				};

				// Start animation (purely cosmetic)
				startAnimation(crashPoint);
			}, 2000);
		}, SIMULATION_BETTING_DURATION);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// CLEANUP
	// ─────────────────────────────────────────────────────────────────────────

	// Note: Caller should call disconnect() when component unmounts

	// ─────────────────────────────────────────────────────────────────────────
	// RETURN INTERFACE
	// ─────────────────────────────────────────────────────────────────────────

	return {
		get state() {
			return state;
		},
		get canBet() {
			return canBet;
		},
		get isAnimating() {
			return isAnimating;
		},
		get hasWon() {
			return hasWon;
		},
		get potentialPayout() {
			return potentialPayout;
		},
		get winProbability() {
			return winProbability;
		},
		get timeRemaining() {
			return timeRemaining;
		},
		get timeDisplay() {
			return timeDisplay;
		},
		get isCritical() {
			return isCritical;
		},
		connect,
		disconnect,
		placeBet,
		_simulateRound,
	};
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Format multiplier for display (e.g., 1.00x, 23.47x)
 */
export function formatMultiplier(value: number): string {
	return value.toFixed(2) + 'x';
}

/**
 * Get color class for multiplier based on player's target
 */
export function getMultiplierColor(value: number, target?: number): string {
	if (target) {
		// Color based on proximity to player's target
		if (value < target * 0.8) return 'mult-safe'; // Green - well below target
		if (value < target) return 'mult-warning'; // Amber - approaching target
		return 'mult-danger'; // Red - above target
	}

	// Default colors based on absolute value
	if (value < 2) return 'mult-low';
	if (value < 5) return 'mult-mid';
	if (value < 10) return 'mult-high';
	return 'mult-extreme';
}

/**
 * Calculate profit from bet and target multiplier
 */
export function calculateProfit(bet: bigint, targetMultiplier: number): bigint {
	const payout = BigInt(Math.floor(Number(bet) * targetMultiplier));
	return payout - bet;
}

/**
 * Calculate win probability for a given target multiplier
 * Formula: P(win) ~= 0.96 / target (with 4% house edge)
 */
export function calculateWinProbability(targetMultiplier: number): number {
	return Math.min(0.96 / targetMultiplier, 0.99);
}
