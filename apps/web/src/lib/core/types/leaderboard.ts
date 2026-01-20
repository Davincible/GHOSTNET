/**
 * Leaderboard Type Definitions
 * ============================
 * Types for rankings, leaderboards, and achievements
 */

import type { Level } from './index';

// ════════════════════════════════════════════════════════════════
// RANKING CATEGORIES
// ════════════════════════════════════════════════════════════════

/** Available leaderboard ranking categories */
export type LeaderboardCategory =
	| 'ghost_streak'
	| 'total_extracted'
	| 'weekly_extracted'
	| 'total_staked'
	| 'risk_score'
	| 'crews';

/** Time windows for leaderboard data */
export type LeaderboardTimeframe = 'all_time' | 'monthly' | 'weekly' | 'daily';

// ════════════════════════════════════════════════════════════════
// PLAYER RANKINGS
// ════════════════════════════════════════════════════════════════

/** A single entry in a player leaderboard */
export interface LeaderboardEntry {
	/** Current rank position (1-indexed) */
	rank: number;
	/** Previous rank for showing movement (null if new entry) */
	previousRank: number | null;
	/** Player's wallet address */
	address: `0x${string}`;
	/** ENS name if available */
	ensName?: string;
	/** Crew tag display, e.g., [PHTM] */
	crewTag?: string;
	/** The metric value being ranked on */
	value: bigint | number;
	/** Pre-formatted display string for the value */
	formattedValue: string;
	/** Current risk level if jacked in */
	level?: Level;
	/** Ghost streak count (for context in non-streak boards) */
	ghostStreak?: number;
	/** Whether this entry represents the current user */
	isYou: boolean;
}

/** Complete leaderboard data for a category */
export interface LeaderboardData {
	/** Which category this leaderboard represents */
	category: LeaderboardCategory;
	/** Time window for the data */
	timeframe: LeaderboardTimeframe;
	/** Ranked entries (ordered by rank) */
	entries: LeaderboardEntry[];
	/** Total number of ranked players (may exceed entries.length) */
	totalEntries: number;
	/** Unix timestamp of last data refresh */
	lastUpdated: number;
	/** Current user's rank (null if not on board) */
	userRank: number | null;
	/** Current user's full entry (null if not on board) */
	userEntry: LeaderboardEntry | null;
}

// ════════════════════════════════════════════════════════════════
// CREW RANKINGS
// ════════════════════════════════════════════════════════════════

/** A single entry in the crew leaderboard */
export interface CrewLeaderboardEntry {
	/** Current rank position */
	rank: number;
	/** Previous rank for showing movement */
	previousRank: number | null;
	/** Unique crew identifier */
	crewId: string;
	/** Full crew name */
	crewName: string;
	/** Short crew tag, e.g., PHTM */
	crewTag: string;
	/** Number of active members */
	memberCount: number;
	/** Total value locked by all members */
	totalStaked: bigint;
	/** Gains extracted this week */
	weeklyExtracted: bigint;
	/** Number of currently active crew bonuses */
	activeBonuses: number;
	/** Whether this is the current user's crew */
	isYourCrew: boolean;
}

// ════════════════════════════════════════════════════════════════
// USER STATS
// ════════════════════════════════════════════════════════════════

/** Individual ranking data for a single metric */
export interface RankingMetric<T> {
	/** User's rank in this category */
	rank: number;
	/** User's value for this metric */
	value: T;
	/** Percentile (0-100, where 99 = top 1%) */
	percentile: number;
}

/** All of a user's rankings across categories */
export interface UserRankings {
	ghostStreak: RankingMetric<number> | null;
	totalExtracted: RankingMetric<bigint> | null;
	weeklyExtracted: RankingMetric<bigint> | null;
	totalStaked: RankingMetric<bigint> | null;
	riskScore: RankingMetric<number> | null;
}

// ════════════════════════════════════════════════════════════════
// ACHIEVEMENTS
// ════════════════════════════════════════════════════════════════

/** Achievement classification categories */
export type AchievementCategory = 'survival' | 'wealth' | 'risk' | 'social' | 'special';

/** Achievement rarity tiers */
export type AchievementRarity = 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary';

/** An achievement definition with unlock status */
export interface Achievement {
	/** Unique achievement identifier */
	id: string;
	/** Display name */
	name: string;
	/** Detailed description */
	description: string;
	/** Classification category */
	category: AchievementCategory;
	/** ASCII character or emoji for display */
	icon: string;
	/** Rarity tier */
	rarity: AchievementRarity;
	/** Unix timestamp when unlocked (null if locked) */
	unlockedAt: number | null;
	/** Progress toward unlock (0-1) */
	progress: number;
	/** Human-readable unlock requirement */
	requirement: string;
}

/** A user's complete achievement profile */
export interface UserAchievements {
	/** All unlocked achievements */
	unlocked: Achievement[];
	/** Achievements with partial progress */
	inProgress: Achievement[];
	/** Total achievement points earned */
	totalPoints: number;
}

// ════════════════════════════════════════════════════════════════
// CATEGORY METADATA
// ════════════════════════════════════════════════════════════════

/** Configuration for each leaderboard category */
export interface LeaderboardCategoryConfig {
	/** Full display label */
	label: string;
	/** Short label for compact displays */
	shortLabel: string;
	/** Description of what this category measures */
	description: string;
	/** Prefix for formatted values (e.g., '+') */
	valuePrefix?: string;
	/** Suffix for formatted values (e.g., ' $DATA') */
	valueSuffix?: string;
	/** Whether higher values are better (for sorting/display) */
	higherIsBetter: boolean;
}

/** Metadata for all leaderboard categories */
export const LEADERBOARD_CATEGORIES: Record<LeaderboardCategory, LeaderboardCategoryConfig> = {
	ghost_streak: {
		label: 'Ghost Streak',
		shortLabel: 'STREAK',
		description: 'Longest current survival streak',
		valueSuffix: ' scans',
		higherIsBetter: true,
	},
	total_extracted: {
		label: 'Total Extracted',
		shortLabel: 'EXTRACTED',
		description: 'All-time gains extracted',
		valuePrefix: '+',
		valueSuffix: ' $DATA',
		higherIsBetter: true,
	},
	weekly_extracted: {
		label: 'Weekly Extracted',
		shortLabel: 'WEEKLY',
		description: 'Gains extracted this week',
		valuePrefix: '+',
		valueSuffix: ' $DATA',
		higherIsBetter: true,
	},
	total_staked: {
		label: 'Total Staked',
		shortLabel: 'STAKED',
		description: 'Current amount staked',
		valueSuffix: ' $DATA',
		higherIsBetter: true,
	},
	risk_score: {
		label: 'Risk Score',
		shortLabel: 'RISK',
		description: 'Based on level, stake, and streak',
		higherIsBetter: true,
	},
	crews: {
		label: 'Top Crews',
		shortLabel: 'CREWS',
		description: 'Crew rankings by TVL',
		higherIsBetter: true,
	},
};

// ════════════════════════════════════════════════════════════════
// ACHIEVEMENT RARITY CONFIG
// ════════════════════════════════════════════════════════════════

/** Points awarded for each achievement rarity tier */
export const ACHIEVEMENT_POINTS: Record<AchievementRarity, number> = {
	common: 10,
	uncommon: 25,
	rare: 50,
	epic: 100,
	legendary: 250,
};

/** Display colors for achievement rarities (CSS variable names) */
export const ACHIEVEMENT_COLORS: Record<AchievementRarity, string> = {
	common: 'var(--color-text-muted)',
	uncommon: 'var(--color-phosphor)',
	rare: 'var(--color-level-mainframe)',
	epic: 'var(--color-level-darknet)',
	legendary: 'var(--color-level-black-ice)',
};
