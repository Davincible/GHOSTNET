/**
 * HASH CRASH Game Store
 * =====================
 * State management for the Hash Crash multiplier game.
 *
 * Game Flow:
 * 1. BETTING - Players place bets (60 seconds)
 * 2. PENDING - Waiting for seed block to be mined
 * 3. RISING  - Multiplier climbs, players can cash out
 * 4. CRASHED - Round over, losers lose, winners paid
 * 5. SETTLING - Payouts being processed
 *
 * Uses the shared arcade engine for timing and rewards.
 */

import { browser } from '$app/environment';
import type {
	HashCrashPhase,
	HashCrashRound,
	HashCrashBet,
	HashCrashCashOut
} from '$lib/core/types/arcade';
import { createFrameLoop, createCountdown } from '$lib/features/arcade/engine';

// ============================================================================
// CONFIGURATION
// ============================================================================

/** Betting phase duration in ms */
export const BETTING_DURATION = 60_000;

/** Delay between rounds in ms */
export const ROUND_DELAY = 5_000;

/** Multiplier growth rate (e^(rate * seconds)) */
export const GROWTH_RATE = 0.06;

/** Minimum bet in wei (10 $DATA) */
export const MIN_BET = 10n * 10n ** 18n;

/** Maximum bet in wei (1000 $DATA) */
export const MAX_BET = 1000n * 10n ** 18n;

/** Number of recent crashes to track */
const RECENT_CRASHES_LIMIT = 10;

/** Number of recent cash-outs to display */
const RECENT_CASHOUTS_LIMIT = 20;

// ============================================================================
// TYPES
// ============================================================================

export interface HashCrashState {
	/** Current round info */
	round: HashCrashRound | null;
	/** Current multiplier (1.00 = 1x) */
	multiplier: number;
	/** Player's bet for current round */
	playerBet: HashCrashBet | null;
	/** Recent cash-outs in current round */
	recentCashOuts: HashCrashCashOut[];
	/** History of recent crash points */
	recentCrashPoints: number[];
	/** All players in current round */
	players: PlayerInfo[];
	/** Connection status */
	isConnected: boolean;
	/** Loading state for transactions */
	isLoading: boolean;
	/** Error message if any */
	error: string | null;
}

export interface PlayerInfo {
	address: `0x${string}`;
	betAmount: bigint;
	cashedOut: boolean;
	cashOutMultiplier: number | null;
}

export interface HashCrashStore {
	// State (reactive)
	readonly state: HashCrashState;

	// Derived values
	readonly canBet: boolean;
	readonly canCashOut: boolean;
	readonly potentialPayout: bigint;
	readonly timeRemaining: number;
	readonly timeDisplay: string;
	readonly isCritical: boolean;

	// Actions
	connect(): () => void;
	disconnect(): void;
	placeBet(amount: bigint, autoCashOut?: number): Promise<void>;
	cashOut(): Promise<void>;
	setAutoCashOut(multiplier: number | null): void;

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
		recentCashOuts: [],
		recentCrashPoints: [],
		players: [],
		isConnected: false,
		isLoading: false,
		error: null
	});

	// Auto cash-out setting
	let autoCashOutMultiplier: number | null = null;

	// Timer for betting phase countdown
	const bettingCountdown = createCountdown({
		duration: BETTING_DURATION,
		criticalThreshold: 10_000,
		onComplete: () => {
			// Betting phase ended - handled by WebSocket
		}
	});

	// Frame loop for smooth multiplier animation
	let startTime = 0;
	const frameLoop = createFrameLoop((delta, time) => {
		if (state.round?.state !== 'rising') return;

		// Calculate multiplier based on elapsed time
		const elapsed = (Date.now() - startTime) / 1000;
		const newMultiplier = Math.pow(Math.E, GROWTH_RATE * elapsed);

		state = { ...state, multiplier: newMultiplier };

		// Check auto cash-out
		if (
			autoCashOutMultiplier &&
			state.playerBet &&
			!state.playerBet.cashOutMultiplier &&
			newMultiplier >= autoCashOutMultiplier
		) {
			cashOut();
		}
	});

	// ─────────────────────────────────────────────────────────────────────────
	// DERIVED STATE
	// ─────────────────────────────────────────────────────────────────────────

	let canBet = $derived(
		state.round?.state === 'betting' && state.playerBet === null && !state.isLoading
	);

	let canCashOut = $derived(
		state.round?.state === 'rising' &&
			state.playerBet !== null &&
			state.playerBet.cashOutMultiplier === null &&
			!state.isLoading
	);

	let potentialPayout = $derived(
		state.playerBet
			? BigInt(Math.floor(Number(state.playerBet.amount) * state.multiplier))
			: 0n
	);

	let timeRemaining = $derived(bettingCountdown.state.remaining);
	let timeDisplay = $derived(bettingCountdown.state.display);
	let isCritical = $derived(bettingCountdown.state.critical);

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

			case 'CASH_OUT':
				handleCashOut(data);
				break;

			case 'CASH_OUT_CONFIRMED':
				handleCashOutConfirmed(data);
				break;

			case 'GAME_STARTED':
				handleGameStarted(data);
				break;

			case 'CRASHED':
				handleCrashed(data);
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
			players: (data.players as PlayerInfo[]) || []
		};

		if (roundData.state === 'betting') {
			// Calculate remaining time for countdown
			const remaining = roundData.bettingEndsAt - Date.now();
			if (remaining > 0) {
				bettingCountdown.start(remaining);
			}
			state = { ...state, multiplier: 1.0, playerBet: null, recentCashOuts: [] };
		} else if (roundData.state === 'rising') {
			startTime = roundData.startTime;
			frameLoop.start();
		}
	}

	function handleBetPlaced(data: WSMessage): void {
		// Another player placed a bet
		const player: PlayerInfo = {
			address: data.address as `0x${string}`,
			betAmount: BigInt(data.amount as string),
			cashedOut: false,
			cashOutMultiplier: null
		};
		state = {
			...state,
			players: [...state.players, player]
		};
	}

	function handleBetConfirmed(data: WSMessage): void {
		// Our bet was confirmed
		state = {
			...state,
			playerBet: {
				amount: BigInt(data.amount as string),
				cashOutMultiplier: null,
				settled: false
			},
			isLoading: false
		};
	}

	function handleCashOut(data: WSMessage): void {
		// Someone cashed out
		const cashOut: HashCrashCashOut = {
			address: data.address as `0x${string}`,
			multiplier: data.multiplier as number,
			payout: BigInt(data.payout as string),
			timestamp: Date.now()
		};

		state = {
			...state,
			recentCashOuts: [cashOut, ...state.recentCashOuts.slice(0, RECENT_CASHOUTS_LIMIT - 1)],
			players: state.players.map((p) =>
				p.address === cashOut.address
					? { ...p, cashedOut: true, cashOutMultiplier: cashOut.multiplier }
					: p
			)
		};
	}

	function handleCashOutConfirmed(data: WSMessage): void {
		// Our cash-out was confirmed
		if (state.playerBet) {
			state = {
				...state,
				playerBet: {
					...state.playerBet,
					cashOutMultiplier: data.multiplier as number,
					settled: true
				},
				isLoading: false
			};
		}
	}

	function handleGameStarted(data: WSMessage): void {
		bettingCountdown.stop();
		startTime = data.startTime as number;

		state = {
			...state,
			round: state.round
				? { ...state.round, state: 'rising', startTime: startTime }
				: null,
			multiplier: 1.0
		};

		frameLoop.start();
	}

	function handleCrashed(data: WSMessage): void {
		frameLoop.stop();

		const crashPoint = data.crashPoint as number;

		state = {
			...state,
			round: state.round ? { ...state.round, state: 'crashed', crashPoint } : null,
			multiplier: crashPoint,
			recentCrashPoints: [crashPoint, ...state.recentCrashPoints.slice(0, RECENT_CRASHES_LIMIT - 1)]
		};
	}

	// ─────────────────────────────────────────────────────────────────────────
	// ACTIONS
	// ─────────────────────────────────────────────────────────────────────────

	async function placeBet(amount: bigint, autoCashOut?: number): Promise<void> {
		if (!canBet) return;

		// Validate bet amount
		if (amount < MIN_BET || amount > MAX_BET) {
			state = { ...state, error: `Bet must be between 10 and 1000 $DATA` };
			return;
		}

		state = { ...state, isLoading: true, error: null };

		if (autoCashOut !== undefined) {
			autoCashOutMultiplier = autoCashOut;
		}

		// TODO: Call smart contract
		// For now, send via WebSocket
		ws?.send(
			JSON.stringify({
				type: 'PLACE_BET',
				amount: amount.toString(),
				autoCashOut: autoCashOutMultiplier
			})
		);
	}

	async function cashOut(): Promise<void> {
		if (!canCashOut) return;

		state = { ...state, isLoading: true, error: null };

		// TODO: Call smart contract
		ws?.send(
			JSON.stringify({
				type: 'CASH_OUT',
				multiplier: state.multiplier
			})
		);
	}

	function setAutoCashOut(multiplier: number | null): void {
		autoCashOutMultiplier = multiplier;
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
				bettingEndsAt: Date.now() + 10_000 // 10 second betting for simulation
			},
			multiplier: 1.0,
			playerBet: null,
			recentCashOuts: [],
			players: []
		};

		bettingCountdown.start(10_000);

		// After betting, start rising
		setTimeout(() => {
			bettingCountdown.stop();
			startTime = Date.now();

			state = {
				...state,
				round: state.round
					? { ...state.round, state: 'rising', startTime }
					: null
			};

			frameLoop.start();

			// Calculate when to crash based on growth rate
			// crashPoint = e^(GROWTH_RATE * t) => t = ln(crashPoint) / GROWTH_RATE
			const crashTime = (Math.log(crashPoint) / GROWTH_RATE) * 1000;

			setTimeout(() => {
				frameLoop.stop();
				state = {
					...state,
					round: state.round
						? { ...state.round, state: 'crashed', crashPoint }
						: null,
					multiplier: crashPoint,
					recentCrashPoints: [
						crashPoint,
						...state.recentCrashPoints.slice(0, RECENT_CRASHES_LIMIT - 1)
					]
				};
			}, crashTime);
		}, 10_000);
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
		get canCashOut() {
			return canCashOut;
		},
		get potentialPayout() {
			return potentialPayout;
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
		cashOut,
		setAutoCashOut,
		_simulateRound
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
 * Get color class for multiplier
 */
export function getMultiplierColor(value: number): string {
	if (value < 2) return 'mult-low';
	if (value < 5) return 'mult-mid';
	if (value < 10) return 'mult-high';
	return 'mult-extreme';
}

/**
 * Calculate profit from bet and multiplier
 */
export function calculateProfit(bet: bigint, multiplier: number): bigint {
	const payout = BigInt(Math.floor(Number(bet) * multiplier));
	return payout - bet;
}
