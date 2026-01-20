/**
 * Leaderboard Mock Data Generator
 * ================================
 * Generates realistic mock leaderboard and achievement data for development
 */

import type {
	LeaderboardCategory,
	LeaderboardTimeframe,
	LeaderboardEntry,
	LeaderboardData,
	CrewLeaderboardEntry,
	UserRankings,
	Achievement,
	UserAchievements,
	AchievementRarity,
} from '../../../types/leaderboard';
import type { Level } from '../../../types';
import { LEVELS } from '../../../types';

// ════════════════════════════════════════════════════════════════
// CONSTANTS
// ════════════════════════════════════════════════════════════════

/** Crew tags for mock data */
const CREW_TAGS = ['PHTM', 'NTRN', 'CPHR', 'VOID', 'GHST', 'DARK', 'ICE', 'NET', 'SYS', 'ROOT'];

/** Crew names matching tags */
const CREW_NAMES: Record<string, string> = {
	PHTM: 'PHANTOMS',
	NTRN: 'NETRUNNERS',
	CPHR: 'CIPHER COLLECTIVE',
	VOID: 'VOID WALKERS',
	GHST: 'GHOST PROTOCOL',
	DARK: 'DARKSIDE',
	ICE: 'BLACK ICE GANG',
	NET: 'NET CRAWLERS',
	SYS: 'SYSTEM32',
	ROOT: 'ROOT ACCESS',
};

/** ENS-like names for realistic display */
const ENS_NAMES = [
	'ghostrunner.eth',
	'datapirate.eth',
	'netwalker.eth',
	'cryptophantom.eth',
	'voidhunter.eth',
	'darknet.eth',
	'icebreaker.eth',
	'systempunk.eth',
	'rootaccess.eth',
	'megawhale.eth',
	'cyberghost.eth',
	'dataminer.eth',
	null, // No ENS
	null,
	null,
];

/** Achievement templates */
const ACHIEVEMENT_TEMPLATES: Omit<Achievement, 'unlockedAt' | 'progress'>[] = [
	// Survival achievements
	{
		id: 'first_ghost',
		name: 'First Ghost',
		description: 'Survive your first trace scan',
		category: 'survival',
		icon: '👻',
		rarity: 'common',
		requirement: 'Survive 1 scan',
	},
	{
		id: 'ghost_5',
		name: 'Ghost Protocol',
		description: 'Reach a 5 scan ghost streak',
		category: 'survival',
		icon: '🔥',
		rarity: 'uncommon',
		requirement: '5 scan streak',
	},
	{
		id: 'ghost_10',
		name: 'Phantom',
		description: 'Reach a 10 scan ghost streak',
		category: 'survival',
		icon: '💀',
		rarity: 'rare',
		requirement: '10 scan streak',
	},
	{
		id: 'ghost_25',
		name: 'Spectre',
		description: 'Reach a 25 scan ghost streak',
		category: 'survival',
		icon: '👁️',
		rarity: 'epic',
		requirement: '25 scan streak',
	},
	{
		id: 'ghost_50',
		name: 'Immortal',
		description: 'Reach a 50 scan ghost streak',
		category: 'survival',
		icon: '⚡',
		rarity: 'legendary',
		requirement: '50 scan streak',
	},

	// Wealth achievements
	{
		id: 'first_extract',
		name: 'First Blood',
		description: 'Extract gains for the first time',
		category: 'wealth',
		icon: '💰',
		rarity: 'common',
		requirement: 'Extract once',
	},
	{
		id: 'extract_1k',
		name: 'Data Miner',
		description: 'Extract 1,000 $DATA total',
		category: 'wealth',
		icon: '📊',
		rarity: 'uncommon',
		requirement: '1,000 $DATA extracted',
	},
	{
		id: 'extract_10k',
		name: 'Data Baron',
		description: 'Extract 10,000 $DATA total',
		category: 'wealth',
		icon: '💎',
		rarity: 'rare',
		requirement: '10,000 $DATA extracted',
	},
	{
		id: 'extract_100k',
		name: 'Data Mogul',
		description: 'Extract 100,000 $DATA total',
		category: 'wealth',
		icon: '👑',
		rarity: 'epic',
		requirement: '100,000 $DATA extracted',
	},
	{
		id: 'extract_1m',
		name: 'Data Overlord',
		description: 'Extract 1,000,000 $DATA total',
		category: 'wealth',
		icon: '🏆',
		rarity: 'legendary',
		requirement: '1,000,000 $DATA extracted',
	},

	// Risk achievements
	{
		id: 'black_ice',
		name: 'Ice Walker',
		description: 'Jack into BLACK_ICE',
		category: 'risk',
		icon: '🖤',
		rarity: 'uncommon',
		requirement: 'Enter BLACK_ICE',
	},
	{
		id: 'black_ice_survive',
		name: 'Ice Survivor',
		description: 'Survive a BLACK_ICE scan',
		category: 'risk',
		icon: '❄️',
		rarity: 'rare',
		requirement: 'Survive BLACK_ICE scan',
	},
	{
		id: 'black_ice_5',
		name: 'Frostbite',
		description: 'Survive 5 BLACK_ICE scans',
		category: 'risk',
		icon: '🧊',
		rarity: 'epic',
		requirement: '5 BLACK_ICE survivals',
	},
	{
		id: 'high_roller',
		name: 'High Roller',
		description: 'Stake 10,000+ $DATA at once',
		category: 'risk',
		icon: '🎰',
		rarity: 'rare',
		requirement: 'Stake 10,000+ $DATA',
	},

	// Social achievements
	{
		id: 'join_crew',
		name: 'Team Player',
		description: 'Join a crew',
		category: 'social',
		icon: '🤝',
		rarity: 'common',
		requirement: 'Join any crew',
	},
	{
		id: 'create_crew',
		name: 'Leader',
		description: 'Create your own crew',
		category: 'social',
		icon: '👑',
		rarity: 'uncommon',
		requirement: 'Create a crew',
	},
	{
		id: 'crew_top_10',
		name: 'Elite Squad',
		description: 'Reach top 10 crew rankings',
		category: 'social',
		icon: '🏅',
		rarity: 'epic',
		requirement: 'Top 10 crew',
	},

	// Special achievements
	{
		id: 'early_adopter',
		name: 'Early Adopter',
		description: 'Jack in during the first week',
		category: 'special',
		icon: '🌟',
		rarity: 'rare',
		requirement: 'First week participation',
	},
	{
		id: 'jackpot',
		name: 'Jackpot Winner',
		description: 'Win a cascade jackpot',
		category: 'special',
		icon: '🎉',
		rarity: 'legendary',
		requirement: 'Win cascade jackpot',
	},
];

/** Points for each rarity tier */
const RARITY_POINTS: Record<AchievementRarity, number> = {
	common: 10,
	uncommon: 25,
	rare: 50,
	epic: 100,
	legendary: 250,
};

// ════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════

/** Generate a random Ethereum address */
function generateRandomAddress(): `0x${string}` {
	const chars = '0123456789abcdef';
	let addr = '0x';
	for (let i = 0; i < 40; i++) {
		addr += chars[Math.floor(Math.random() * chars.length)];
	}
	return addr as `0x${string}`;
}

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

/** Pick a weighted random level */
function pickRandomLevel(): Level {
	const weights = [0.1, 0.2, 0.3, 0.25, 0.15];
	const rand = Math.random();
	let cumulative = 0;
	for (let i = 0; i < LEVELS.length; i++) {
		cumulative += weights[i];
		if (rand < cumulative) return LEVELS[i];
	}
	return 'DARKNET';
}

// ════════════════════════════════════════════════════════════════
// VALUE FORMATTING
// ════════════════════════════════════════════════════════════════

/**
 * Format a leaderboard value for display
 * @param value - The raw value (bigint for token amounts, number for counts)
 * @param category - The leaderboard category for context
 * @returns Formatted string for display
 */
export function formatLeaderboardValue(value: bigint | number, category: LeaderboardCategory): string {
	if (category === 'ghost_streak') {
		return `${value}`;
	}

	if (category === 'risk_score') {
		return `${(value as number).toLocaleString()}`;
	}

	// Token amounts (bigint)
	const tokenValue = typeof value === 'bigint' ? value : BigInt(value);
	const wholeTokens = Number(tokenValue / 10n ** 18n);

	if (wholeTokens >= 1_000_000) {
		return `${(wholeTokens / 1_000_000).toFixed(1)}M`;
	}
	if (wholeTokens >= 1_000) {
		return `${(wholeTokens / 1_000).toFixed(1)}K`;
	}
	return wholeTokens.toLocaleString();
}

// ════════════════════════════════════════════════════════════════
// RISK SCORE CALCULATION
// ════════════════════════════════════════════════════════════════

/**
 * Calculate risk score based on level, stake, and streak
 * Higher scores = more risk-taking behavior
 *
 * Formula:
 * - Base score from level (VAULT=1, BLACK_ICE=5)
 * - Multiplied by stake tier (1-5 based on amount)
 * - Multiplied by streak bonus (1 + streak * 0.1)
 *
 * @param level - Current risk level
 * @param stake - Amount staked in wei
 * @param streak - Current ghost streak
 * @returns Risk score (0-1000+ range)
 */
export function calculateRiskScore(level: Level, stake: bigint, streak: number): number {
	// Level base scores
	const levelScores: Record<Level, number> = {
		VAULT: 1,
		MAINFRAME: 2,
		SUBNET: 3,
		DARKNET: 4,
		BLACK_ICE: 5,
	};

	// Stake tiers (in whole tokens)
	const stakeTokens = Number(stake / 10n ** 18n);
	let stakeTier = 1;
	if (stakeTokens >= 10000) stakeTier = 5;
	else if (stakeTokens >= 5000) stakeTier = 4;
	else if (stakeTokens >= 1000) stakeTier = 3;
	else if (stakeTokens >= 100) stakeTier = 2;

	// Streak multiplier (capped at 10 for 2x max)
	const streakMultiplier = 1 + Math.min(streak, 10) * 0.1;

	// Calculate score
	const baseScore = levelScores[level] * stakeTier * 20;
	const finalScore = Math.round(baseScore * streakMultiplier);

	return finalScore;
}

// ════════════════════════════════════════════════════════════════
// LEADERBOARD ENTRY GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate a single leaderboard entry
 * @param rank - The rank position (1-indexed)
 * @param category - The leaderboard category
 * @param isYou - Whether this entry represents the current user
 * @returns A complete leaderboard entry
 */
export function generateLeaderboardEntry(
	rank: number,
	category: LeaderboardCategory,
	isYou: boolean = false
): LeaderboardEntry {
	const address = generateRandomAddress();

	// Higher ranks get better values (exponential decay)
	const rankMultiplier = Math.max(0.1, 1 - Math.log10(rank) / 3);

	// Optionally assign crew membership (40% chance)
	const hasCrew = Math.random() < 0.4;
	const crewTag = hasCrew ? `[${pickRandom(CREW_TAGS)}]` : undefined;

	// Optionally assign ENS name (30% chance, higher for top ranks)
	const ensChance = rank <= 10 ? 0.6 : 0.3;
	const ensName = Math.random() < ensChance ? pickRandom(ENS_NAMES) ?? undefined : undefined;

	// Level for context
	const level = pickRandomLevel();
	const ghostStreak = randomInt(0, Math.floor(50 * rankMultiplier));

	// Generate value based on category
	let value: bigint | number;
	switch (category) {
		case 'ghost_streak':
			// Top streakers have 50+, drops off quickly
			value = Math.max(1, Math.floor(100 * rankMultiplier) - randomInt(0, 10));
			break;

		case 'total_extracted':
			// Top extractors have millions, drops to thousands
			value = randomAmount(
				Math.floor(100000 * rankMultiplier),
				Math.floor(1000000 * rankMultiplier) + 10000
			);
			break;

		case 'weekly_extracted':
			// Weekly is smaller, top players extract 10k+
			value = randomAmount(
				Math.floor(5000 * rankMultiplier),
				Math.floor(50000 * rankMultiplier) + 1000
			);
			break;

		case 'total_staked':
			// Top stakers have 100k+, drops to hundreds
			value = randomAmount(
				Math.floor(50000 * rankMultiplier),
				Math.floor(500000 * rankMultiplier) + 5000
			);
			break;

		case 'risk_score':
			// Calculate from simulated level/stake/streak
			const simulatedStake = randomAmount(
				Math.floor(1000 * rankMultiplier),
				Math.floor(10000 * rankMultiplier) + 100
			);
			value = calculateRiskScore(level, simulatedStake, ghostStreak);
			break;

		default:
			value = 0;
	}

	// Generate previous rank (small movement for realism)
	let previousRank: number | null = null;
	if (Math.random() < 0.7) {
		// 70% have previous rank
		const movement = randomInt(-5, 5);
		previousRank = Math.max(1, rank + movement);
	}

	return {
		rank,
		previousRank,
		address,
		ensName,
		crewTag,
		value,
		formattedValue: formatLeaderboardValue(value, category),
		level: Math.random() < 0.7 ? level : undefined, // 70% are jacked in
		ghostStreak: category !== 'ghost_streak' ? ghostStreak : undefined,
		isYou,
	};
}

// ════════════════════════════════════════════════════════════════
// LEADERBOARD DATA GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate complete leaderboard data for a category
 * @param category - The leaderboard category
 * @param timeframe - Time window for the data
 * @param count - Number of entries to generate (default 50)
 * @returns Complete leaderboard data
 */
export function generateLeaderboardData(
	category: LeaderboardCategory,
	timeframe: LeaderboardTimeframe,
	count: number = 50
): LeaderboardData {
	// Generate entries
	const entries: LeaderboardEntry[] = [];

	// Decide if user appears on the board (30% chance in top 50)
	const userRankPosition = Math.random() < 0.3 ? randomInt(1, count) : null;

	for (let i = 1; i <= count; i++) {
		const isYou = i === userRankPosition;
		entries.push(generateLeaderboardEntry(i, category, isYou));
	}

	// Extract user entry if present
	const userEntry = userRankPosition ? entries[userRankPosition - 1] : null;

	return {
		category,
		timeframe,
		entries,
		totalEntries: randomInt(count, count * 10), // More players exist beyond top 50
		lastUpdated: Date.now(),
		userRank: userRankPosition,
		userEntry,
	};
}

// ════════════════════════════════════════════════════════════════
// CREW LEADERBOARD GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate crew leaderboard entries
 * @param count - Number of crews to generate (default 20)
 * @returns Array of crew leaderboard entries
 */
export function generateCrewLeaderboard(count: number = 20): CrewLeaderboardEntry[] {
	const entries: CrewLeaderboardEntry[] = [];

	// Decide if user's crew appears (25% chance)
	const userCrewRank = Math.random() < 0.25 ? randomInt(1, count) : null;

	for (let i = 1; i <= Math.min(count, CREW_TAGS.length); i++) {
		const tag = CREW_TAGS[i - 1];
		const name = CREW_NAMES[tag];
		const rankMultiplier = Math.max(0.1, 1 - Math.log10(i) / 3);

		// Generate previous rank
		let previousRank: number | null = null;
		if (Math.random() < 0.7) {
			const movement = randomInt(-3, 3);
			previousRank = Math.max(1, i + movement);
		}

		entries.push({
			rank: i,
			previousRank,
			crewId: crypto.randomUUID(),
			crewName: name,
			crewTag: tag,
			memberCount: randomInt(Math.floor(5 * rankMultiplier), Math.floor(50 * rankMultiplier) + 5),
			totalStaked: randomAmount(
				Math.floor(100000 * rankMultiplier),
				Math.floor(1000000 * rankMultiplier) + 50000
			),
			weeklyExtracted: randomAmount(
				Math.floor(10000 * rankMultiplier),
				Math.floor(100000 * rankMultiplier) + 5000
			),
			activeBonuses: randomInt(0, 5),
			isYourCrew: i === userCrewRank,
		});
	}

	return entries;
}

// ════════════════════════════════════════════════════════════════
// USER RANKINGS GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate user's rankings across all categories
 * @returns User's rankings or null for categories they haven't participated in
 */
export function generateUserRankings(): UserRankings {
	// User might not be ranked in all categories
	const hasStreak = Math.random() < 0.8;
	const hasTotalExtracted = Math.random() < 0.9;
	const hasWeeklyExtracted = Math.random() < 0.7;
	const hasStaked = Math.random() < 0.85;
	const hasRiskScore = hasStaked; // Need to be staked to have risk score

	return {
		ghostStreak: hasStreak
			? {
					rank: randomInt(50, 5000),
					value: randomInt(1, 30),
					percentile: Math.random() * 100,
				}
			: null,
		totalExtracted: hasTotalExtracted
			? {
					rank: randomInt(100, 10000),
					value: randomAmount(500, 50000),
					percentile: Math.random() * 100,
				}
			: null,
		weeklyExtracted: hasWeeklyExtracted
			? {
					rank: randomInt(50, 3000),
					value: randomAmount(100, 10000),
					percentile: Math.random() * 100,
				}
			: null,
		totalStaked: hasStaked
			? {
					rank: randomInt(100, 8000),
					value: randomAmount(100, 20000),
					percentile: Math.random() * 100,
				}
			: null,
		riskScore: hasRiskScore
			? {
					rank: randomInt(200, 5000),
					value: randomInt(50, 500),
					percentile: Math.random() * 100,
				}
			: null,
	};
}

// ════════════════════════════════════════════════════════════════
// ACHIEVEMENT GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate user's achievements (unlocked and in-progress)
 * @returns User's complete achievement profile
 */
export function generateUserAchievements(): UserAchievements {
	const now = Date.now();
	const unlocked: Achievement[] = [];
	const inProgress: Achievement[] = [];
	let totalPoints = 0;

	for (const template of ACHIEVEMENT_TEMPLATES) {
		const roll = Math.random();

		// Common achievements more likely unlocked
		const unlockChance =
			{
				common: 0.7,
				uncommon: 0.5,
				rare: 0.25,
				epic: 0.1,
				legendary: 0.02,
			}[template.rarity] || 0.5;

		if (roll < unlockChance) {
			// Unlocked
			const unlockedAt = now - randomInt(1, 30) * 24 * 60 * 60 * 1000; // 1-30 days ago
			unlocked.push({
				...template,
				unlockedAt,
				progress: 1,
			});
			totalPoints += RARITY_POINTS[template.rarity];
		} else if (roll < unlockChance + 0.3) {
			// In progress
			inProgress.push({
				...template,
				unlockedAt: null,
				progress: Math.random() * 0.9, // 0-90% progress
			});
		}
		// Otherwise not started (not included)
	}

	// Sort unlocked by unlock time (newest first)
	unlocked.sort((a, b) => (b.unlockedAt ?? 0) - (a.unlockedAt ?? 0));

	// Sort in progress by progress (closest to completion first)
	inProgress.sort((a, b) => b.progress - a.progress);

	return {
		unlocked,
		inProgress,
		totalPoints,
	};
}

// ════════════════════════════════════════════════════════════════
// UTILITY EXPORTS
// ════════════════════════════════════════════════════════════════

/** Get achievement templates (for displaying all possible achievements) */
export function getAchievementTemplates(): Omit<Achievement, 'unlockedAt' | 'progress'>[] {
	return ACHIEVEMENT_TEMPLATES;
}

/** Get rank movement indicator */
export function getRankMovement(current: number, previous: number | null): 'up' | 'down' | 'same' | 'new' {
	if (previous === null) return 'new';
	if (current < previous) return 'up';
	if (current > previous) return 'down';
	return 'same';
}

/** Format percentile for display */
export function formatPercentile(percentile: number): string {
	if (percentile >= 99) return 'Top 1%';
	if (percentile >= 95) return 'Top 5%';
	if (percentile >= 90) return 'Top 10%';
	if (percentile >= 75) return 'Top 25%';
	if (percentile >= 50) return 'Top 50%';
	return `Top ${Math.ceil(100 - percentile)}%`;
}
