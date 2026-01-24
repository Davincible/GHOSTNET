/**
 * GHOSTNET Daily Operations Types
 * ================================
 * Type definitions for daily check-ins, streaks, and missions.
 *
 * The daily operations system encourages consistent engagement through:
 * - Daily mission completion streaks (on-chain via DailyOps contract)
 * - Milestone bonuses at 7, 21, 30, 90 day streaks
 * - Persistent death rate reduction while streak is active
 * - Shield protection to prevent streak loss
 *
 * Architecture:
 * - Mission selection/verification: Off-chain (server)
 * - Streak state & rewards: On-chain (DailyOps.sol)
 * - Death rate application: Via GhostCore boost
 */

// ════════════════════════════════════════════════════════════════
// ON-CHAIN TYPES (match DailyOps.sol contract)
// ════════════════════════════════════════════════════════════════

/** On-chain streak data from DailyOps contract */
export interface PlayerStreak {
	/** Current consecutive day streak */
	currentStreak: number;
	/** Highest streak ever achieved */
	longestStreak: number;
	/** UTC day number of last claim (0 = never claimed) */
	lastClaimDay: bigint;
	/** UTC day number when shield expires (0 = no shield) */
	shieldExpiryDay: bigint;
	/** Total DATA tokens claimed */
	totalClaimed: bigint;
	/** Total missions ever completed */
	totalMissionsCompleted: bigint;
}

/** Badge earned for achievements */
export interface Badge {
	/** Badge identifier (keccak256 hash) */
	badgeId: `0x${string}`;
	/** Timestamp when earned */
	earnedAt: bigint;
}

/** Known badge identifiers */
export const BADGE_IDS = {
	WEEK_WARRIOR: '0xbb05be1ac4f343cb5102c7e25b9859c60618ac81e9df70e923e36becfbf8bdec' as const,
	DEDICATED_OPERATOR: '0x9a2f36ab377f4ac4df22fa4e7beae925f4a0eb6bde8b03dce28fcea99a8c2cf0' as const,
	LEGEND: '0x68c4ba3f9a5a3ff0c0e5b6ef4f3f51ad96e5c9adb3e5c5e1b2a3f4d5e6f7a8b9' as const,
} as const;

/** Human-readable badge info */
export const BADGE_INFO: Record<string, { name: string; description: string }> = {
	[BADGE_IDS.WEEK_WARRIOR]: {
		name: 'WEEK WARRIOR',
		description: 'Completed a 7-day streak',
	},
	[BADGE_IDS.DEDICATED_OPERATOR]: {
		name: 'DEDICATED OPERATOR',
		description: 'Completed a 30-day streak',
	},
	[BADGE_IDS.LEGEND]: {
		name: 'LEGEND',
		description: 'Completed a 90-day streak',
	},
};

/** Streak milestone thresholds and rewards */
export const STREAK_MILESTONES = [
	{ days: 3, deathRateReduction: 300, bonus: 0n, badge: null },
	{ days: 7, deathRateReduction: 300, bonus: 500n * 10n ** 18n, badge: BADGE_IDS.WEEK_WARRIOR },
	{ days: 14, deathRateReduction: 500, bonus: 0n, badge: null },
	{ days: 21, deathRateReduction: 500, bonus: 1000n * 10n ** 18n, badge: null },
	{
		days: 30,
		deathRateReduction: 500,
		bonus: 5000n * 10n ** 18n,
		badge: BADGE_IDS.DEDICATED_OPERATOR,
	},
	{ days: 60, deathRateReduction: 800, bonus: 0n, badge: null },
	{ days: 90, deathRateReduction: 800, bonus: 15000n * 10n ** 18n, badge: BADGE_IDS.LEGEND },
	{ days: 180, deathRateReduction: 1000, bonus: 0n, badge: null },
] as const;

/** Shield pricing (in wei) */
export const SHIELD_COSTS = {
	ONE_DAY: 50n * 10n ** 18n, // 50 DATA
	SEVEN_DAY: 200n * 10n ** 18n, // 200 DATA
} as const;

/** Get death rate reduction for a streak (in basis points) */
export function getDeathRateReduction(streak: number): number {
	if (streak >= 180) return 1000; // -10%
	if (streak >= 60) return 800; // -8%
	if (streak >= 14) return 500; // -5%
	if (streak >= 3) return 300; // -3%
	return 0;
}

/** Calculate current UTC day number */
export function getCurrentDay(): bigint {
	return BigInt(Math.floor(Date.now() / 86400000));
}

/** Convert UTC day number to Date */
export function dayToDate(day: bigint): Date {
	return new Date(Number(day) * 86400000);
}

// ════════════════════════════════════════════════════════════════
// LEGACY TYPES (for mock provider compatibility)
// ════════════════════════════════════════════════════════════════

// Note: These types are used by the existing mock provider and UI components.
// They represent a 7-day rotating reward system, which differs from the
// on-chain contract that uses unlimited streaks with milestone bonuses.

// ════════════════════════════════════════════════════════════════
// DAILY CHECK-IN & STREAKS (Legacy)
// ════════════════════════════════════════════════════════════════

/** Type of reward granted for daily activities */
export type DailyRewardType = 'death_rate' | 'yield' | 'bonus_tokens';

/** A single daily reward definition */
export interface DailyReward {
	/** Day number in the streak (1-7) */
	day: number;
	/** Type of reward (primary effect) */
	type: DailyRewardType;
	/** Value: negative for death_rate reduction, positive for yield/tokens */
	value: number;
	/** Duration in milliseconds (null for instant rewards like tokens) */
	duration: number | null;
	/** Human-readable description */
	description: string;
	/** Optional bonus tokens for compound rewards (e.g., Day 7) */
	bonusTokens?: number;
}

/** User's daily check-in progress */
export interface DailyProgress {
	/** Current consecutive day streak (1-7, resets after 7 or on miss) */
	currentStreak: number;
	/** Highest streak ever achieved */
	maxStreak: number;
	/** Timestamp of last check-in (null if never) */
	lastCheckIn: number | null;
	/** Whether the user has checked in today */
	todayCheckedIn: boolean;
	/** The reward available for today's check-in */
	nextReward: DailyReward;
	/** Progress through the week [day1, day2, ...day7] */
	weekProgress: [boolean, boolean, boolean, boolean, boolean, boolean, boolean];
	/** Timestamp when daily resets (next UTC midnight) */
	nextResetAt: number;
}

/**
 * The 7-day reward schedule.
 * Rewards escalate through the week, with day 7 being the most valuable.
 * Missing a day resets progress to day 1.
 */
export const DAILY_REWARDS: DailyReward[] = [
	{
		day: 1,
		type: 'death_rate',
		value: -0.02,
		duration: 24 * 60 * 60 * 1000,
		description: '-2% death rate (24h)',
	},
	{
		day: 2,
		type: 'death_rate',
		value: -0.03,
		duration: 24 * 60 * 60 * 1000,
		description: '-3% death rate (24h)',
	},
	{
		day: 3,
		type: 'death_rate',
		value: -0.04,
		duration: 24 * 60 * 60 * 1000,
		description: '-4% death rate (24h)',
	},
	{
		day: 4,
		type: 'death_rate',
		value: -0.05,
		duration: 24 * 60 * 60 * 1000,
		description: '-5% death rate (24h)',
	},
	{
		day: 5,
		type: 'yield',
		value: 0.05,
		duration: 24 * 60 * 60 * 1000,
		description: '+5% yield (24h)',
	},
	{
		day: 6,
		type: 'death_rate',
		value: -0.07,
		duration: 24 * 60 * 60 * 1000,
		description: '-7% death rate (24h)',
	},
	{
		day: 7,
		type: 'death_rate',
		value: -0.1,
		duration: 24 * 60 * 60 * 1000,
		description: '-10% death rate (24h) + 50 $DATA',
		bonusTokens: 50,
	},
];

// ════════════════════════════════════════════════════════════════
// DAILY MISSIONS (GDD-aligned types)
// ════════════════════════════════════════════════════════════════

/** Type of mission objective */
export type MissionType =
	| 'survive_scan'
	| 'typing_games'
	| 'deadpool_win'
	| 'hackrun_complete'
	| 'refer_friend'
	| 'stake_amount'
	| 'earn_yield';

/** Mission reward configuration */
export interface MissionReward {
	/** Type of reward */
	type: 'death_rate' | 'yield' | 'tokens';
	/** Value of the reward */
	value: number;
	/** Duration in ms (null for instant rewards) */
	duration: number | null;
}

/** A daily mission */
export interface DailyMission {
	/** Unique mission ID */
	id: string;
	/** Mission type for tracking */
	missionType: MissionType;
	/** Display title */
	title: string;
	/** Description of what to do */
	description: string;
	/** Current progress (0 to target) */
	progress: number;
	/** Target to complete */
	target: number;
	/** Reward for completion */
	reward: MissionReward;
	/** When the mission expires (UTC midnight) */
	expiresAt: number;
	/** Whether the mission objective is complete */
	completed: boolean;
	/** Whether the reward has been claimed */
	claimed: boolean;
}

/** Mission template for generating daily missions */
export interface MissionTemplate {
	missionType: MissionType;
	title: string;
	descriptionTemplate: string;
	targetRange: [number, number];
	reward: MissionReward;
	/** Weight for random selection (higher = more likely) */
	weight: number;
}

/**
 * Available mission templates.
 * Each day, 3 missions are randomly selected from this pool.
 */
export const MISSION_TEMPLATES: MissionTemplate[] = [
	{
		missionType: 'survive_scan',
		title: 'SURVIVOR',
		descriptionTemplate: 'Survive {target} trace scan(s)',
		targetRange: [1, 1],
		reward: { type: 'death_rate', value: -0.05, duration: 4 * 60 * 60 * 1000 },
		weight: 3,
	},
	{
		missionType: 'typing_games',
		title: 'SPEED DEMON',
		descriptionTemplate: 'Complete {target} typing game(s)',
		targetRange: [2, 5],
		reward: { type: 'tokens', value: 25, duration: null },
		weight: 4,
	},
	{
		missionType: 'deadpool_win',
		title: 'ORACLE',
		descriptionTemplate: 'Win {target} Dead Pool bet(s)',
		targetRange: [1, 2],
		reward: { type: 'yield', value: 0.1, duration: 4 * 60 * 60 * 1000 },
		weight: 2,
	},
	{
		missionType: 'hackrun_complete',
		title: 'INFILTRATOR',
		descriptionTemplate: 'Complete {target} Hack Run(s)',
		targetRange: [1, 2],
		reward: { type: 'death_rate', value: -0.08, duration: 4 * 60 * 60 * 1000 },
		weight: 2,
	},
	{
		missionType: 'stake_amount',
		title: 'HIGH ROLLER',
		descriptionTemplate: 'Have {target}+ $DATA staked',
		targetRange: [100, 500],
		reward: { type: 'yield', value: 0.05, duration: 8 * 60 * 60 * 1000 },
		weight: 2,
	},
	{
		missionType: 'earn_yield',
		title: 'YIELD FARMER',
		descriptionTemplate: 'Earn {target}+ $DATA in yield',
		targetRange: [10, 50],
		reward: { type: 'tokens', value: 15, duration: null },
		weight: 3,
	},
];

// ════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ════════════════════════════════════════════════════════════════

/**
 * Get the reward for a specific day in the streak.
 * @param day - Day number (1-7)
 * @returns The reward for that day
 */
export function getDailyReward(day: number): DailyReward {
	const clampedDay = Math.max(1, Math.min(7, day));
	return DAILY_REWARDS[clampedDay - 1];
}

/**
 * Calculate the next UTC midnight timestamp.
 * @param from - Starting timestamp (defaults to now)
 * @returns Timestamp of next UTC midnight
 */
export function getNextResetTime(from: number = Date.now()): number {
	const date = new Date(from);
	date.setUTCHours(24, 0, 0, 0);
	return date.getTime();
}

/**
 * Check if two timestamps are on the same UTC day.
 * @param t1 - First timestamp
 * @param t2 - Second timestamp
 * @returns True if same UTC day
 */
export function isSameUTCDay(t1: number, t2: number): boolean {
	const d1 = new Date(t1);
	const d2 = new Date(t2);
	return (
		d1.getUTCFullYear() === d2.getUTCFullYear() &&
		d1.getUTCMonth() === d2.getUTCMonth() &&
		d1.getUTCDate() === d2.getUTCDate()
	);
}

/**
 * Check if a timestamp was yesterday (UTC).
 * @param timestamp - Timestamp to check
 * @param now - Current time (defaults to Date.now())
 * @returns True if timestamp was yesterday UTC
 */
export function wasYesterdayUTC(timestamp: number, now: number = Date.now()): boolean {
	const yesterday = new Date(now);
	yesterday.setUTCDate(yesterday.getUTCDate() - 1);
	return isSameUTCDay(timestamp, yesterday.getTime());
}
