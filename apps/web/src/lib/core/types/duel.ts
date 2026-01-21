/**
 * GHOSTNET PvP Duels Types
 * =========================
 * Type definitions for the head-to-head typing duel system.
 *
 * Players challenge each other to typing races with wagered $DATA.
 * Winner takes the pot minus 5% rake (burned).
 */

// Note: TypingChallenge is defined in index.ts, not a separate file
// We define a compatible interface here to avoid circular imports

/** Typing challenge for duel (compatible with main TypingChallenge) */
export interface DuelTypingChallenge {
	command: string;
	difficulty: 'easy' | 'medium' | 'hard';
	timeLimit: number;
}

// ════════════════════════════════════════════════════════════════
// DUEL STATUS & TIERS
// ════════════════════════════════════════════════════════════════

/** Current status of a duel */
export type DuelStatus =
	| 'open' // Waiting for opponent to accept
	| 'accepted' // Opponent joined, countdown starting
	| 'active' // Typing in progress
	| 'complete' // Winner determined
	| 'cancelled' // Expired or cancelled by challenger
	| 'declined'; // Opponent declined (for direct challenges)

/** Wager tier determines the stakes */
export type DuelTier = 'quick_draw' | 'showdown' | 'high_noon';

/** Tier configuration with wager limits */
export interface DuelTierConfig {
	/** Minimum wager for this tier */
	minWager: bigint;
	/** Maximum wager for this tier */
	maxWager: bigint;
	/** Display label */
	label: string;
	/** Description */
	description: string;
	/** Expected opponent skill level for mock simulation */
	mockOpponentWpm: { min: number; max: number };
}

/** Tier configurations */
export const DUEL_TIERS: Record<DuelTier, DuelTierConfig> = {
	quick_draw: {
		minWager: 10n * 10n ** 18n,
		maxWager: 50n * 10n ** 18n,
		label: 'Quick Draw',
		description: 'Low stakes, casual duel',
		mockOpponentWpm: { min: 40, max: 60 },
	},
	showdown: {
		minWager: 50n * 10n ** 18n,
		maxWager: 200n * 10n ** 18n,
		label: 'Showdown',
		description: 'Medium stakes, competitive duel',
		mockOpponentWpm: { min: 55, max: 80 },
	},
	high_noon: {
		minWager: 200n * 10n ** 18n,
		maxWager: 1000n * 10n ** 18n,
		label: 'High Noon',
		description: 'High stakes, elite duel',
		mockOpponentWpm: { min: 70, max: 100 },
	},
};

/** Rake percentage burned from winnings (5%) */
export const DUEL_RAKE_PERCENT = 5;

/** How long an open challenge remains valid (5 minutes) */
export const DUEL_EXPIRY_MS = 5 * 60 * 1000;

/** Countdown duration before duel starts (seconds) */
export const DUEL_COUNTDOWN_SECONDS = 3;

// ════════════════════════════════════════════════════════════════
// DUEL INTERFACES
// ════════════════════════════════════════════════════════════════

/** Individual player's result in a duel */
export interface DuelPlayerResult {
	/** Whether they completed the challenge */
	completed: boolean;
	/** Typing accuracy (0-1) */
	accuracy: number;
	/** Words per minute */
	wpm: number;
	/** Time elapsed in milliseconds */
	timeElapsed: number;
	/** Unix timestamp when they finished */
	finishTime: number;
	/** Progress as percentage (0-100) for incomplete */
	progressPercent: number;
}

/** A PvP duel between two players */
export interface Duel {
	/** Unique identifier */
	id: string;
	/** Address of the player who created the challenge */
	challenger: `0x${string}`;
	/** Challenger's display name (ENS or truncated address) */
	challengerName?: string;
	/** Address of the opponent (null if open challenge) */
	opponent: `0x${string}` | null;
	/** Opponent's display name */
	opponentName?: string;
	/** Wager amount in $DATA (wei) */
	wagerAmount: bigint;
	/** Wager tier */
	tier: DuelTier;
	/** Current status */
	status: DuelStatus;
	/** The typing challenge both players complete */
	challenge: DuelTypingChallenge;
	/** Results for each player */
	results: {
		challenger?: DuelPlayerResult;
		opponent?: DuelPlayerResult;
	};
	/** Winner's address (null if not yet determined) */
	winner: `0x${string}` | null;
	/** Unix timestamp when duel was created */
	createdAt: number;
	/** Unix timestamp when duel expires (for open challenges) */
	expiresAt: number;
	/** Unix timestamp when typing started */
	startedAt?: number;
	/** Unix timestamp when duel completed */
	completedAt?: number;
	/** Number of spectators (future feature) */
	spectatorCount: number;
	/** Whether this is a direct challenge to a specific player */
	isDirectChallenge: boolean;
}

/** Parameters for creating a new duel */
export interface CreateDuelParams {
	/** Target address for direct challenge (null = open challenge) */
	targetAddress?: `0x${string}`;
	/** Wager amount in $DATA (wei) */
	wagerAmount: bigint;
}

/** Duel history entry for past duels */
export interface DuelHistoryEntry {
	/** The completed duel */
	duel: Duel;
	/** Whether the current user won */
	youWon: boolean;
	/** Amount won or lost (negative if lost) */
	netAmount: bigint;
}

/** Player's duel statistics */
export interface DuelStats {
	/** Total duels participated in */
	totalDuels: number;
	/** Number of wins */
	wins: number;
	/** Number of losses */
	losses: number;
	/** Win rate (0-1) */
	winRate: number;
	/** Total amount won */
	totalWon: bigint;
	/** Total amount lost */
	totalLost: bigint;
	/** Net profit/loss */
	netProfit: bigint;
	/** Best WPM in a duel */
	bestWpm: number;
	/** Average WPM across all duels */
	averageWpm: number;
	/** Current win streak */
	currentStreak: number;
	/** Best win streak */
	bestStreak: number;
}

// ════════════════════════════════════════════════════════════════
// DUEL UPDATES (for subscriptions)
// ════════════════════════════════════════════════════════════════

/** Updates emitted during duel lifecycle */
export type DuelUpdate =
	| { type: 'DUEL_CREATED'; duel: Duel }
	| { type: 'DUEL_ACCEPTED'; duel: Duel }
	| { type: 'DUEL_STARTED'; duel: Duel }
	| { type: 'OPPONENT_PROGRESS'; duelId: string; progressPercent: number }
	| { type: 'DUEL_COMPLETE'; duel: Duel }
	| { type: 'DUEL_CANCELLED'; duelId: string }
	| { type: 'DUEL_EXPIRED'; duelId: string };

// ════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ════════════════════════════════════════════════════════════════

/**
 * Determine the tier based on wager amount.
 * @param amount - Wager amount in wei
 * @returns The appropriate tier
 */
export function getDuelTier(amount: bigint): DuelTier {
	if (amount >= DUEL_TIERS.high_noon.minWager) return 'high_noon';
	if (amount >= DUEL_TIERS.showdown.minWager) return 'showdown';
	return 'quick_draw';
}

/**
 * Get configuration for a tier.
 * @param tier - The tier
 * @returns Tier configuration
 */
export function getTierConfig(tier: DuelTier): DuelTierConfig {
	return DUEL_TIERS[tier];
}

/**
 * Calculate winnings from a duel.
 * Winner gets both wagers minus the rake.
 * @param wager - Single player's wager amount
 * @returns Payout to winner and rake burned
 */
export function calculateDuelWinnings(wager: bigint): { payout: bigint; rake: bigint } {
	const totalPot = wager * 2n;
	const rake = (totalPot * BigInt(DUEL_RAKE_PERCENT)) / 100n;
	const payout = totalPot - rake;
	return { payout, rake };
}

/**
 * Check if a duel is still accepting opponents.
 * @param duel - The duel
 * @param now - Current timestamp (defaults to Date.now())
 * @returns True if still open and not expired
 */
export function isDuelOpen(duel: Duel, now: number = Date.now()): boolean {
	return duel.status === 'open' && duel.expiresAt > now;
}

/**
 * Check if the current user is in this duel.
 * @param duel - The duel
 * @param userAddress - Current user's address
 * @returns True if user is challenger or opponent
 */
export function isUserInDuel(duel: Duel, userAddress: `0x${string}`): boolean {
	return (
		duel.challenger.toLowerCase() === userAddress.toLowerCase() ||
		duel.opponent?.toLowerCase() === userAddress.toLowerCase()
	);
}

/**
 * Get the user's role in a duel.
 * @param duel - The duel
 * @param userAddress - Current user's address
 * @returns 'challenger', 'opponent', or null if not in duel
 */
export function getUserDuelRole(
	duel: Duel,
	userAddress: `0x${string}`
): 'challenger' | 'opponent' | null {
	if (duel.challenger.toLowerCase() === userAddress.toLowerCase()) return 'challenger';
	if (duel.opponent?.toLowerCase() === userAddress.toLowerCase()) return 'opponent';
	return null;
}

/**
 * Format duel tier for display.
 * @param tier - The tier
 * @returns Formatted tier name
 */
export function formatDuelTier(tier: DuelTier): string {
	return DUEL_TIERS[tier].label;
}

/**
 * Get CSS class for tier styling.
 * @param tier - The tier
 * @returns CSS class name
 */
export function getTierClass(tier: DuelTier): string {
	return `tier-${tier.replace('_', '-')}`;
}

/**
 * Determine the winner of a duel based on results.
 * Winner is whoever finished first (completed with lowest time).
 * If neither completed, it's whoever made more progress.
 * @param duel - The duel with results
 * @returns Winner's address or null if can't be determined
 */
export function determineDuelWinner(duel: Duel): `0x${string}` | null {
	const { challenger, opponent, results } = duel;
	if (!opponent || !results.challenger || !results.opponent) return null;

	const cResult = results.challenger;
	const oResult = results.opponent;

	// Both completed - winner is fastest
	if (cResult.completed && oResult.completed) {
		return cResult.finishTime <= oResult.finishTime ? challenger : opponent;
	}

	// Only one completed
	if (cResult.completed && !oResult.completed) return challenger;
	if (oResult.completed && !cResult.completed) return opponent;

	// Neither completed - more progress wins
	if (cResult.progressPercent > oResult.progressPercent) return challenger;
	if (oResult.progressPercent > cResult.progressPercent) return opponent;

	// Tie (rare) - challenger wins as tie-breaker
	return challenger;
}
