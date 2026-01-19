/**
 * GHOSTNET Core Type Definitions
 * ===============================
 * All TypeScript interfaces for the application
 */

// ════════════════════════════════════════════════════════════════
// ENUMS & CONSTANTS
// ════════════════════════════════════════════════════════════════

/** Security clearance levels (risk tiers) */
export type Level = 'VAULT' | 'MAINFRAME' | 'SUBNET' | 'DARKNET' | 'BLACK_ICE';

/** Ordered array of levels from safest to most dangerous */
export const LEVELS: Level[] = ['VAULT', 'MAINFRAME', 'SUBNET', 'DARKNET', 'BLACK_ICE'];

/** Level configuration */
export const LEVEL_CONFIG: Record<Level, {
	baseDeathRate: number;
	scanIntervalHours: number;
	minStake: bigint;
	color: string;
}> = {
	VAULT: {
		baseDeathRate: 0,
		scanIntervalHours: Infinity,
		minStake: 100n * 10n ** 18n,
		color: 'var(--color-level-vault)'
	},
	MAINFRAME: {
		baseDeathRate: 0.02,
		scanIntervalHours: 24,
		minStake: 50n * 10n ** 18n,
		color: 'var(--color-level-mainframe)'
	},
	SUBNET: {
		baseDeathRate: 0.15,
		scanIntervalHours: 8,
		minStake: 25n * 10n ** 18n,
		color: 'var(--color-level-subnet)'
	},
	DARKNET: {
		baseDeathRate: 0.40,
		scanIntervalHours: 2,
		minStake: 10n * 10n ** 18n,
		color: 'var(--color-level-darknet)'
	},
	BLACK_ICE: {
		baseDeathRate: 0.90,
		scanIntervalHours: 0.5,
		minStake: 5n * 10n ** 18n,
		color: 'var(--color-level-black-ice)'
	}
};

/** Connection status for WebSocket/provider */
export type ConnectionStatus = 'disconnected' | 'connecting' | 'connected' | 'reconnecting';

// ════════════════════════════════════════════════════════════════
// USER & WALLET
// ════════════════════════════════════════════════════════════════

/** Connected user/wallet information */
export interface User {
	address: `0x${string}`;
	ensName?: string;
	tokenBalance: bigint;
	ethBalance: bigint;
}

// ════════════════════════════════════════════════════════════════
// POSITION
// ════════════════════════════════════════════════════════════════

/** Active staking position */
export interface Position {
	id: string;
	address: `0x${string}`;
	level: Level;
	stakedAmount: bigint;
	entryTimestamp: number;
	earnedYield: bigint;
	ghostStreak: number;
	nextScanTimestamp: number;
}

/** Active modifier affecting position */
export interface Modifier {
	id: string;
	source: 'typing' | 'hackrun' | 'crew' | 'daily' | 'network' | 'consumable';
	type: 'death_rate' | 'yield_multiplier';
	/** Modifier value: -0.15 = -15% death rate, 1.5 = 1.5x yield */
	value: number;
	/** Expiration timestamp (null = permanent) */
	expiresAt: number | null;
	/** Human-readable label */
	label: string;
}

// ════════════════════════════════════════════════════════════════
// NETWORK STATE
// ════════════════════════════════════════════════════════════════

/** Global network/protocol state */
export interface NetworkState {
	tvl: bigint;
	tvlCapacity: bigint;
	operatorsOnline: number;
	operatorsAth: number;
	systemResetTimestamp: number;
	traceScanTimestamps: Record<Level, number>;
	burnRatePerHour: bigint;
	hourlyStats: {
		jackedIn: bigint;
		extracted: bigint;
		traced: bigint;
	};
}

/** Stats for a specific level */
export interface LevelStats {
	level: Level;
	operatorCount: number;
	totalStaked: bigint;
	baseDeathRate: number;
	effectiveDeathRate: number;
	nextScanTimestamp: number;
}

// ════════════════════════════════════════════════════════════════
// FEED EVENTS
// ════════════════════════════════════════════════════════════════

/** Types of events that appear in the live feed */
export type FeedEventType =
	| 'JACK_IN'
	| 'EXTRACT'
	| 'TRACED'
	| 'SURVIVED'
	| 'TRACE_SCAN_WARNING'
	| 'TRACE_SCAN_START'
	| 'TRACE_SCAN_COMPLETE'
	| 'CASCADE'
	| 'WHALE_ALERT'
	| 'SYSTEM_RESET_WARNING'
	| 'SYSTEM_RESET'
	| 'CREW_EVENT'
	| 'MINIGAME_RESULT'
	| 'JACKPOT';

/** Feed event with typed data payload */
export interface FeedEvent {
	id: string;
	type: FeedEventType;
	timestamp: number;
	data: FeedEventData;
}

/** Discriminated union of feed event data */
export type FeedEventData =
	| { type: 'JACK_IN'; address: `0x${string}`; level: Level; amount: bigint }
	| { type: 'EXTRACT'; address: `0x${string}`; amount: bigint; gain: bigint }
	| { type: 'TRACED'; address: `0x${string}`; level: Level; amountLost: bigint }
	| { type: 'SURVIVED'; address: `0x${string}`; level: Level; streak: number }
	| { type: 'TRACE_SCAN_WARNING'; level: Level; secondsUntil: number }
	| { type: 'TRACE_SCAN_START'; level: Level }
	| { type: 'TRACE_SCAN_COMPLETE'; level: Level; survivors: number; traced: number }
	| { type: 'CASCADE'; sourceLevel: Level; burned: bigint; distributed: bigint }
	| { type: 'WHALE_ALERT'; address: `0x${string}`; level: Level; amount: bigint }
	| { type: 'SYSTEM_RESET_WARNING'; secondsUntil: number }
	| { type: 'SYSTEM_RESET'; penaltyPercent: number; jackpotWinner: `0x${string}` }
	| { type: 'CREW_EVENT'; crewName: string; eventType: string; message: string }
	| { type: 'MINIGAME_RESULT'; address: `0x${string}`; game: string; result: string }
	| { type: 'JACKPOT'; address: `0x${string}`; level: Level; amount: bigint };

/** Priority levels for feed events (higher = more important) */
export const FEED_EVENT_PRIORITY: Record<FeedEventType, number> = {
	TRACED: 10,
	JACKPOT: 9,
	WHALE_ALERT: 8,
	SYSTEM_RESET: 8,
	SYSTEM_RESET_WARNING: 7,
	TRACE_SCAN_WARNING: 6,
	TRACE_SCAN_START: 6,
	TRACE_SCAN_COMPLETE: 6,
	CASCADE: 5,
	EXTRACT: 4,
	CREW_EVENT: 3,
	MINIGAME_RESULT: 3,
	SURVIVED: 2,
	JACK_IN: 1
};

// ════════════════════════════════════════════════════════════════
// TYPING GAME (TRACE EVASION)
// ════════════════════════════════════════════════════════════════

/** Typing challenge configuration */
export interface TypingChallenge {
	command: string;
	difficulty: 'easy' | 'medium' | 'hard';
	timeLimit: number;
}

/** Result of a typing challenge */
export interface TypingResult {
	accuracy: number;
	wpm: number;
	timeElapsed: number;
	reward: {
		type: 'death_rate_reduction';
		value: number;
		label: string;
	} | null;
}

/** Typing game state machine states */
export type TypingGameState = 'idle' | 'countdown' | 'active' | 'complete';

// ════════════════════════════════════════════════════════════════
// CREW SYSTEM
// ════════════════════════════════════════════════════════════════

/** Crew (guild/team) */
export interface Crew {
	id: string;
	name: string;
	memberCount: number;
	maxMembers: number;
	rank: number;
	totalStaked: bigint;
	weeklyExtracted: bigint;
	bonuses: CrewBonus[];
	members: CrewMember[];
}

/** Crew member */
export interface CrewMember {
	address: `0x${string}`;
	level: Level;
	stakedAmount: bigint;
	ghostStreak: number;
	isOnline: boolean;
	isYou: boolean;
}

/** Crew bonus effect */
export interface CrewBonus {
	name: string;
	condition: string;
	effect: string;
	active: boolean;
}

// ════════════════════════════════════════════════════════════════
// DEAD POOL (PREDICTION MARKET)
// ════════════════════════════════════════════════════════════════

/** Dead Pool betting round */
export interface DeadPoolRound {
	id: string;
	roundNumber: number;
	type: 'death_count' | 'whale_watch' | 'survival_streak' | 'system_reset';
	targetLevel: Level;
	question: string;
	line: number;
	endsAt: number;
	pools: {
		under: bigint;
		over: bigint;
	};
	userBet: {
		side: 'under' | 'over';
		amount: bigint;
	} | null;
}
