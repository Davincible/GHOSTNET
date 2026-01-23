/**
 * Reward System - Payout Calculations & Burn Logic
 * =================================================
 * Provides reward calculation utilities for arcade games:
 * - Bet/entry fee tracking
 * - Payout calculations with house edge
 * - Burn rate application
 * - Reward tier evaluation
 */

import type {
	RewardTier,
	RewardConfig,
	PayoutCalculation,
	PoolPayoutCalculation,
	RewardState,
} from '$lib/core/types/arcade';

// ============================================================================
// STORE INTERFACE
// ============================================================================

export interface RewardSystem {
	/** Current state (reactive) */
	readonly state: RewardState;
	/** Configuration */
	readonly config: RewardConfig;
	/** Set current bet amount */
	setBet(amount: bigint): boolean;
	/** Set entry fee */
	setEntryFee(amount: bigint): void;
	/** Calculate payout for a given multiplier */
	calculatePayout(multiplier: number, bet?: bigint): PayoutCalculation;
	/** Calculate pool-based payout (for betting games) */
	calculatePoolPayout(
		totalPool: bigint,
		winningPool: bigint,
		losingPool: bigint,
		rake?: number
	): PoolPayoutCalculation;
	/** Record a win */
	recordWin(amount: bigint): void;
	/** Record a loss */
	recordLoss(amount: bigint): void;
	/** Get reward tier for a value */
	getRewardTier(value: number): RewardTier | null;
	/** Reset session stats */
	resetSession(): void;
}

// ============================================================================
// STORE FACTORY
// ============================================================================

/**
 * Create a reward system instance.
 *
 * @example
 * ```typescript
 * const rewards = createRewardSystem({
 *   houseEdge: 0.03,     // 3% house edge
 *   burnRate: 1.0,       // 100% of edge burned
 *   minBet: 10n * 10n**18n,
 *   maxBet: 1000n * 10n**18n,
 *   tiers: [
 *     { id: 'perfect', name: 'PERFECT', minThreshold: 1.0, value: -0.25, description: '-25% death rate' },
 *     { id: 'excellent', name: 'Excellent', minThreshold: 0.95, value: -0.20, description: '-20% death rate' },
 *   ],
 * });
 *
 * // Calculate potential payout
 * const payout = rewards.calculatePayout(5.0);
 * console.log(`Win ${payout.netPayout} $DATA at 5x`);
 * ```
 */
export function createRewardSystem(config: RewardConfig): RewardSystem {
	// Sort tiers by threshold descending
	const sortedTiers = config.tiers
		? [...config.tiers].sort((a, b) => b.minThreshold - a.minThreshold)
		: [];

	// -------------------------------------------------------------------------
	// STATE
	// -------------------------------------------------------------------------

	let state = $state<RewardState>({
		currentBet: 0n,
		entryFee: 0n,
		sessionWinnings: 0n,
		sessionLosses: 0n,
		sessionPnL: 0n,
		gamesPlayed: 0,
		gamesWon: 0,
		winRate: 0,
	});

	// -------------------------------------------------------------------------
	// BET MANAGEMENT
	// -------------------------------------------------------------------------

	function setBet(amount: bigint): boolean {
		if (amount < config.minBet || amount > config.maxBet) {
			return false;
		}
		state = { ...state, currentBet: amount };
		return true;
	}

	function setEntryFee(amount: bigint): void {
		state = { ...state, entryFee: amount };
	}

	// -------------------------------------------------------------------------
	// PAYOUT CALCULATIONS
	// -------------------------------------------------------------------------

	function calculatePayout(multiplier: number, bet?: bigint): PayoutCalculation {
		const betAmount = bet ?? state.currentBet;

		// Convert multiplier to bigint-safe calculation
		// multiplier is like 5.67 -> 567 / 100
		const multiplierBps = BigInt(Math.floor(multiplier * 100));
		const grossPayout = (betAmount * multiplierBps) / 100n;

		// House edge applies to profit portion
		const profit = grossPayout - betAmount;
		const houseEdgeBps = BigInt(Math.floor(config.houseEdge * 10000));
		const houseEdgeAmount = profit > 0n ? (profit * houseEdgeBps) / 10000n : 0n;

		// Burn amount
		const burnRateBps = BigInt(Math.floor(config.burnRate * 10000));
		const burnAmount = (houseEdgeAmount * burnRateBps) / 10000n;

		// Net payout
		const netPayout = grossPayout - houseEdgeAmount;
		const netProfit = netPayout - betAmount;

		return {
			bet: betAmount,
			multiplier,
			grossPayout,
			houseEdgeAmount,
			burnAmount,
			netPayout,
			profit: netProfit,
			isWin: netProfit > 0n,
		};
	}

	function calculatePoolPayout(
		totalPool: bigint,
		winningPool: bigint,
		losingPool: bigint,
		rake = 0.05
	): PoolPayoutCalculation {
		const rakeBps = BigInt(Math.floor(rake * 10000));
		const rakeAmount = (totalPool * rakeBps) / 10000n;

		const burnRateBps = BigInt(Math.floor(config.burnRate * 10000));
		const burnAmount = (rakeAmount * burnRateBps) / 10000n;

		const distributablePool = totalPool - rakeAmount;

		// Payout multiplier for winners
		const payoutMultiplier =
			winningPool > 0n ? Number((distributablePool * 100n) / winningPool) / 100 : 0;

		return {
			totalPool,
			winningPool,
			losingPool,
			rakeAmount,
			burnAmount,
			distributablePool,
			payoutMultiplier,
		};
	}

	// -------------------------------------------------------------------------
	// SESSION TRACKING
	// -------------------------------------------------------------------------

	function recordWin(amount: bigint): void {
		const newGamesPlayed = state.gamesPlayed + 1;
		const newGamesWon = state.gamesWon + 1;
		const newWinnings = state.sessionWinnings + amount;
		const newPnL = newWinnings - state.sessionLosses;

		state = {
			...state,
			sessionWinnings: newWinnings,
			sessionPnL: newPnL,
			gamesPlayed: newGamesPlayed,
			gamesWon: newGamesWon,
			winRate: newGamesWon / newGamesPlayed,
		};
	}

	function recordLoss(amount: bigint): void {
		const newGamesPlayed = state.gamesPlayed + 1;
		const newLosses = state.sessionLosses + amount;
		const newPnL = state.sessionWinnings - newLosses;

		state = {
			...state,
			sessionLosses: newLosses,
			sessionPnL: newPnL,
			gamesPlayed: newGamesPlayed,
			winRate: state.gamesWon / newGamesPlayed,
		};
	}

	// -------------------------------------------------------------------------
	// REWARD TIERS
	// -------------------------------------------------------------------------

	function getRewardTier(value: number): RewardTier | null {
		for (const tier of sortedTiers) {
			if (value >= tier.minThreshold) {
				return tier;
			}
		}
		return null;
	}

	// -------------------------------------------------------------------------
	// RESET
	// -------------------------------------------------------------------------

	function resetSession(): void {
		state = {
			currentBet: 0n,
			entryFee: 0n,
			sessionWinnings: 0n,
			sessionLosses: 0n,
			sessionPnL: 0n,
			gamesPlayed: 0,
			gamesWon: 0,
			winRate: 0,
		};
	}

	return {
		get state() {
			return state;
		},
		get config() {
			return config;
		},
		setBet,
		setEntryFee,
		calculatePayout,
		calculatePoolPayout,
		recordWin,
		recordLoss,
		getRewardTier,
		resetSession,
	};
}

// Re-export types for convenience
export type { RewardTier, RewardConfig, PayoutCalculation, PoolPayoutCalculation, RewardState };
