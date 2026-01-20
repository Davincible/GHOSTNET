/**
 * Dead Pool Mock Data Generator
 * =============================
 * Generates realistic mock prediction market data for development
 */

import type {
	DeadPoolRound,
	DeadPoolResult,
	DeadPoolRoundType,
	DeadPoolStatus,
	DeadPoolSide,
	DeadPoolUserStats,
	DeadPoolHistory,
	Level
} from '../../../types';

// ════════════════════════════════════════════════════════════════
// CONSTANTS
// ════════════════════════════════════════════════════════════════

/** Round templates defining behavior for each prediction type */
const ROUND_TEMPLATES: Array<{
	type: DeadPoolRoundType;
	questionTemplate: string;
	/** Levels this bet type applies to (empty = system-wide) */
	levels: Level[];
	lineRange: [number, number];
	/** Round duration in milliseconds */
	durationMs: number;
	/** How long before end betting locks */
	lockBeforeEndMs: number;
}> = [
	{
		type: 'death_count',
		questionTemplate: 'Will >{line} operators be traced in {level}?',
		levels: ['SUBNET', 'DARKNET', 'BLACK_ICE'],
		lineRange: [20, 100],
		durationMs: 30 * 60 * 1000, // 30 minutes
		lockBeforeEndMs: 5 * 60 * 1000 // 5 minutes
	},
	{
		type: 'whale_watch',
		questionTemplate: 'Will a {line}+ $DATA whale enter {level}?',
		levels: ['DARKNET', 'BLACK_ICE'],
		lineRange: [2000, 10000],
		durationMs: 60 * 60 * 1000, // 60 minutes
		lockBeforeEndMs: 10 * 60 * 1000 // 10 minutes
	},
	{
		type: 'survival_streak',
		questionTemplate: 'Will anyone hit a {line}+ ghost streak in {level}?',
		levels: ['SUBNET', 'DARKNET', 'BLACK_ICE'],
		lineRange: [10, 30],
		durationMs: 45 * 60 * 1000, // 45 minutes
		lockBeforeEndMs: 5 * 60 * 1000 // 5 minutes
	},
	{
		type: 'system_reset',
		questionTemplate: 'Will the reset timer hit critical (<{line}min)?',
		levels: [], // System-wide, no specific level
		lineRange: [15, 45],
		durationMs: 15 * 60 * 1000, // 15 minutes (urgent)
		lockBeforeEndMs: 2 * 60 * 1000 // 2 minutes
	}
];

/** Persistent round counter for realistic round numbers */
let roundCounter = 1240;

// ════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════

/** Pick a random item from an array */
function pickRandom<T>(arr: readonly T[]): T {
	return arr[Math.floor(Math.random() * arr.length)];
}

/** Generate random integer in range (inclusive) */
function randomInt(min: number, max: number): number {
	return Math.floor(Math.random() * (max - min + 1)) + min;
}

/** Generate a random token amount (in wei) */
function randomAmount(min: number, max: number): bigint {
	const value = Math.floor(Math.random() * (max - min) + min);
	return BigInt(value) * 10n ** 18n;
}

/** Format question template with actual values */
function formatQuestion(template: string, line: number, level: Level | null): string {
	let question = template.replace('{line}', String(line));
	if (level) {
		question = question.replace('{level}', level);
	}
	return question;
}

// ════════════════════════════════════════════════════════════════
// ODDS CALCULATION
// ════════════════════════════════════════════════════════════════

/** Burn rate for Dead Pool (5% rake) */
const BURN_RATE = 0.05;

/**
 * Calculate parimutuel odds for each side
 * Returns multiplier for a winning bet (e.g., 1.8 means $1 bet wins $1.80)
 */
export function calculateOdds(pools: { under: bigint; over: bigint }): { under: number; over: number } {
	const underNum = Number(pools.under);
	const overNum = Number(pools.over);
	const total = underNum + overNum;

	if (total === 0) {
		return { under: 1.9, over: 1.9 }; // Default odds when pool is empty
	}

	const netPool = total * (1 - BURN_RATE);

	return {
		under: underNum > 0 ? netPool / underNum : 0,
		over: overNum > 0 ? netPool / overNum : 0
	};
}

/**
 * Calculate implied probability from pool distribution
 * Returns probability as 0-1 (e.g., 0.65 = 65% chance)
 */
export function calculateImpliedProbability(
	pools: { under: bigint; over: bigint },
	side: DeadPoolSide
): number {
	const total = Number(pools.under) + Number(pools.over);
	if (total === 0) return 0.5;

	const sideAmount = side === 'under' ? Number(pools.under) : Number(pools.over);
	return sideAmount / total;
}

// ════════════════════════════════════════════════════════════════
// POOL GENERATION
// ════════════════════════════════════════════════════════════════

/** Generate realistic pool sizes with natural imbalance */
export function generateMockPools(): { under: bigint; over: bigint } {
	// Base pool sizes (50-500 $DATA per side)
	const baseUnder = randomAmount(50, 500);
	const baseOver = randomAmount(50, 500);

	// Add some imbalance (real markets are rarely 50/50)
	const imbalanceFactor = 0.7 + Math.random() * 0.6; // 0.7x to 1.3x

	return {
		under: baseUnder,
		over: (baseOver * BigInt(Math.floor(imbalanceFactor * 100))) / 100n
	};
}

/** Update pools with a new bet (simulates other players betting) */
export function updatePoolsWithBet(
	pools: { under: bigint; over: bigint },
	side: DeadPoolSide,
	amount: bigint
): { under: bigint; over: bigint } {
	return {
		under: side === 'under' ? pools.under + amount : pools.under,
		over: side === 'over' ? pools.over + amount : pools.over
	};
}

// ════════════════════════════════════════════════════════════════
// ROUND GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate a single mock Dead Pool round
 * @param status - Force a specific status (useful for testing)
 */
export function generateMockRound(status?: DeadPoolStatus): DeadPoolRound {
	const template = pickRandom(ROUND_TEMPLATES);
	const now = Date.now();

	// Pick target level (null for system-wide bets)
	const targetLevel: Level | null = template.levels.length > 0 ? pickRandom(template.levels) : null;

	// Generate line within range
	const line = randomInt(template.lineRange[0], template.lineRange[1]);

	// Calculate timing based on status
	let startsAt: number;
	let endsAt: number;
	let locksAt: number;
	let roundStatus: DeadPoolStatus;

	if (status) {
		roundStatus = status;
		switch (status) {
			case 'betting':
				startsAt = now - randomInt(5, 15) * 60 * 1000; // Started 5-15 min ago
				endsAt = now + randomInt(10, 25) * 60 * 1000; // Ends in 10-25 min
				locksAt = endsAt - template.lockBeforeEndMs;
				break;
			case 'locked':
				startsAt = now - randomInt(20, 30) * 60 * 1000;
				endsAt = now + randomInt(1, 5) * 60 * 1000; // Ends in 1-5 min
				locksAt = now - randomInt(1, 3) * 60 * 1000; // Locked 1-3 min ago
				break;
			case 'resolving':
				startsAt = now - template.durationMs;
				endsAt = now - randomInt(10, 60) * 1000; // Ended 10-60 sec ago
				locksAt = endsAt - template.lockBeforeEndMs;
				break;
			case 'resolved':
				startsAt = now - template.durationMs - randomInt(5, 30) * 60 * 1000;
				endsAt = now - randomInt(5, 30) * 60 * 1000;
				locksAt = endsAt - template.lockBeforeEndMs;
				break;
		}
	} else {
		// Default: active betting round
		roundStatus = 'betting';
		startsAt = now - randomInt(5, 15) * 60 * 1000;
		endsAt = now + randomInt(10, 25) * 60 * 1000;
		locksAt = endsAt - template.lockBeforeEndMs;
	}

	const pools = generateMockPools();
	const question = formatQuestion(template.questionTemplate, line, targetLevel);

	roundCounter++;

	return {
		id: crypto.randomUUID(),
		roundNumber: roundCounter,
		type: template.type,
		status: roundStatus,
		targetLevel,
		question,
		line,
		startsAt,
		endsAt,
		locksAt,
		pools,
		userBet: null // No bet by default
	};
}

/** Generate multiple active rounds (one of each type is common) */
export function generateActiveRounds(): DeadPoolRound[] {
	// Generate one round per type for variety
	return ROUND_TEMPLATES.map((template) => {
		const round = generateMockRound('betting');
		// Override type to ensure variety
		const targetLevel: Level | null =
			template.levels.length > 0 ? pickRandom(template.levels) : null;
		const line = randomInt(template.lineRange[0], template.lineRange[1]);

		return {
			...round,
			type: template.type,
			targetLevel,
			line,
			question: formatQuestion(template.questionTemplate, line, targetLevel)
		};
	});
}

// ════════════════════════════════════════════════════════════════
// RESOLUTION
// ════════════════════════════════════════════════════════════════

/**
 * Resolve a round and generate result
 * @param round - The round to resolve
 * @param userBetSide - The side the user bet on (if any)
 * @param userBetAmount - The amount the user bet (if any)
 */
export function resolveRound(
	round: DeadPoolRound,
	userBetSide?: DeadPoolSide,
	userBetAmount?: bigint
): DeadPoolResult {
	// Generate actual value (slightly random around the line)
	const variance = round.line * 0.3; // 30% variance
	const actualValue = Math.round(round.line + (Math.random() - 0.5) * 2 * variance);

	// Determine outcome
	const outcome: DeadPoolSide = actualValue > round.line ? 'over' : 'under';

	// Calculate payouts
	const totalPool = round.pools.under + round.pools.over;
	const burnAmount = (totalPool * 5n) / 100n; // 5% burn
	const winnerPool = totalPool - burnAmount;

	// Calculate user payout if they bet
	let userWon: boolean | null = null;
	let userPayout: bigint | null = null;

	if (userBetSide && userBetAmount) {
		userWon = userBetSide === outcome;

		if (userWon) {
			// User gets proportional share of winner pool
			const winningSidePool = outcome === 'under' ? round.pools.under : round.pools.over;
			if (winningSidePool > 0n) {
				userPayout = (winnerPool * userBetAmount) / winningSidePool;
			} else {
				userPayout = 0n;
			}
		} else {
			userPayout = 0n;
		}
	}

	return {
		roundId: round.id,
		outcome,
		actualValue,
		totalPool,
		burnAmount,
		winnerPool,
		userWon,
		userPayout
	};
}

// ════════════════════════════════════════════════════════════════
// HISTORY GENERATION
// ════════════════════════════════════════════════════════════════

/** Generate a resolved round with result for history */
export function generateMockHistory(): DeadPoolHistory {
	const round = generateMockRound('resolved');

	// Randomly decide if user bet on this round (30% chance)
	const userParticipated = Math.random() < 0.3;
	let userBetSide: DeadPoolSide | undefined;
	let userBetAmount: bigint | undefined;

	if (userParticipated) {
		userBetSide = Math.random() < 0.5 ? 'under' : 'over';
		userBetAmount = randomAmount(10, 100);
		round.userBet = {
			side: userBetSide,
			amount: userBetAmount,
			timestamp: round.startsAt + randomInt(1, 10) * 60 * 1000
		};
	}

	const result = resolveRound(round, userBetSide, userBetAmount);

	return { round, result };
}

/** Generate multiple history entries */
export function generateMockHistoryList(count: number): DeadPoolHistory[] {
	const history: DeadPoolHistory[] = [];

	for (let i = 0; i < count; i++) {
		history.push(generateMockHistory());
	}

	// Sort by end time, most recent first
	return history.sort((a, b) => b.round.endsAt - a.round.endsAt);
}

// ════════════════════════════════════════════════════════════════
// USER STATS
// ════════════════════════════════════════════════════════════════

/** Generate mock user statistics */
export function generateUserStats(): DeadPoolUserStats {
	const totalBets = randomInt(15, 150);
	const winRate = 0.35 + Math.random() * 0.3; // 35% to 65% win rate
	const wins = Math.floor(totalBets * winRate);
	const losses = totalBets - wins;

	// Generate realistic totals
	const avgBetSize = randomInt(20, 100);
	const avgWinMultiplier = 1.7 + Math.random() * 0.5; // 1.7x to 2.2x

	const totalWon = randomAmount(wins * avgBetSize * avgWinMultiplier, wins * avgBetSize * avgWinMultiplier * 1.5);
	const totalLost = randomAmount(losses * avgBetSize * 0.8, losses * avgBetSize * 1.2);
	const biggestWin = randomAmount(avgBetSize * 3, avgBetSize * 10);

	// Current streak (-5 to +5)
	const currentStreak = randomInt(-5, 5);

	return {
		totalBets,
		totalWon,
		totalLost,
		winRate,
		biggestWin,
		currentStreak
	};
}

// ════════════════════════════════════════════════════════════════
// SIMULATION HELPERS
// ════════════════════════════════════════════════════════════════

/** Simulate pool changes over time (other players betting) */
export function simulatePoolActivity(pools: { under: bigint; over: bigint }): {
	under: bigint;
	over: bigint;
} {
	// Small random changes to simulate other players
	const underChange = randomAmount(0, 50) * (Math.random() < 0.5 ? 1n : 0n);
	const overChange = randomAmount(0, 50) * (Math.random() < 0.5 ? 1n : 0n);

	return {
		under: pools.under + underChange,
		over: pools.over + overChange
	};
}

/** Get time remaining until a round locks */
export function getTimeUntilLock(round: DeadPoolRound): number {
	return Math.max(0, round.locksAt - Date.now());
}

/** Get time remaining until a round ends */
export function getTimeUntilEnd(round: DeadPoolRound): number {
	return Math.max(0, round.endsAt - Date.now());
}

/** Check if a round is currently accepting bets */
export function canBet(round: DeadPoolRound): boolean {
	const now = Date.now();
	return round.status === 'betting' && now >= round.startsAt && now < round.locksAt;
}
