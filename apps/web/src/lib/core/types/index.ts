/**
 * GHOSTNET Core Type Definitions
 * ===============================
 * All TypeScript interfaces for the application
 */

// Re-export error types
export * from './errors';

// Re-export daily operations types
export * from './daily';

// Re-export market/consumables types
export * from './market';

// Re-export duel types
export * from './duel';

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

/** Crew role within the team hierarchy */
export type CrewRole = 'leader' | 'officer' | 'member';

/** Crew (guild/team) - max 50 members */
export interface Crew {
	/** Unique identifier */
	id: string;
	/** Display name */
	name: string;
	/** 3-4 character tag displayed as [TAG] */
	tag: string;
	/** Crew description / mission statement */
	description: string;
	/** Current member count */
	memberCount: number;
	/** Maximum allowed members (50) */
	maxMembers: number;
	/** Global ranking position */
	rank: number;
	/** Total $DATA staked by all members */
	totalStaked: bigint;
	/** $DATA extracted this week */
	weeklyExtracted: bigint;
	/** Active and potential bonuses */
	bonuses: CrewBonus[];
	/** Crew leader's address */
	leader: `0x${string}`;
	/** Unix timestamp of creation */
	createdAt: number;
	/** Whether anyone can join (vs invite-only) */
	isPublic: boolean;
}

/** Crew member with full details */
export interface CrewMember {
	/** Wallet address */
	address: `0x${string}`;
	/** ENS name if available */
	ensName?: string;
	/** Current risk level (null if not jacked in) */
	level: Level | null;
	/** Amount currently staked */
	stakedAmount: bigint;
	/** Consecutive scan survivals */
	ghostStreak: number;
	/** Currently connected */
	isOnline: boolean;
	/** Is this the current user */
	isYou: boolean;
	/** Role within the crew */
	role: CrewRole;
	/** Unix timestamp when joined */
	joinedAt: number;
	/** $DATA contributed this week */
	weeklyContribution: bigint;
}

/** Crew bonus effect - can be active or progressing toward activation */
export interface CrewBonus {
	/** Unique identifier */
	id: string;
	/** Display name */
	name: string;
	/** Human-readable activation condition */
	condition: string;
	/** Human-readable effect description */
	effect: string;
	/** Type of effect applied */
	effectType: 'death_rate' | 'yield_multiplier';
	/** Effect value: -0.05 = -5% death rate, 0.15 = +15% yield */
	effectValue: number;
	/** Whether bonus is currently active */
	active: boolean;
	/** Progress toward activation (0-1) */
	progress: number;
	/** Threshold value to activate */
	requiredValue: number;
	/** Current progress value */
	currentValue: number;
}

/** Pending crew invitation */
export interface CrewInvite {
	/** Unique identifier */
	id: string;
	/** Target crew ID */
	crewId: string;
	/** Crew display name */
	crewName: string;
	/** Crew tag */
	crewTag: string;
	/** Address of the inviter */
	inviterAddress: `0x${string}`;
	/** Inviter's ENS name if available */
	inviterName?: string;
	/** Unix timestamp when invite expires */
	expiresAt: number;
	/** Unix timestamp when invite was created */
	createdAt: number;
}

/** Types of crew activity events */
export type CrewActivityType =
	| 'member_joined'
	| 'member_left'
	| 'member_kicked'
	| 'bonus_activated'
	| 'bonus_deactivated'
	| 'member_survived'
	| 'member_traced'
	| 'member_extracted'
	| 'raid_started'
	| 'raid_completed';

/** Crew activity feed event */
export interface CrewActivity {
	/** Unique identifier */
	id: string;
	/** Type of activity */
	type: CrewActivityType;
	/** Unix timestamp */
	timestamp: number;
	/** Address of the actor (if applicable) */
	actorAddress?: `0x${string}`;
	/** Display name of the actor */
	actorName?: string;
	/** Target address (if applicable) */
	targetAddress?: `0x${string}`;
	/** Display name of the target */
	targetName?: string;
	/** Bonus ID (for bonus events) */
	bonusId?: string;
	/** Bonus name (for bonus events) */
	bonusName?: string;
	/** Amount involved (for financial events) */
	amount?: bigint;
	/** Level involved (for level-specific events) */
	level?: Level;
	/** Pre-formatted display message */
	message: string;
}

/** Current user's crew membership status */
export interface UserCrewStatus {
	/** The crew the user belongs to (null if not in a crew) */
	crew: Crew | null;
	/** User's role in the crew (null if not in a crew) */
	role: CrewRole | null;
	/** Pending invitations to join crews */
	pendingInvites: CrewInvite[];
	/** Whether user can create a new crew */
	canCreateCrew: boolean;
}

// ════════════════════════════════════════════════════════════════
// DEAD POOL (PREDICTION MARKET)
// ════════════════════════════════════════════════════════════════

/** Types of prediction markets available */
export type DeadPoolRoundType = 'death_count' | 'whale_watch' | 'survival_streak' | 'system_reset';

/** Round lifecycle states */
export type DeadPoolStatus = 'betting' | 'locked' | 'resolving' | 'resolved';

/** Betting side (over/under the line) */
export type DeadPoolSide = 'under' | 'over';

/** Dead Pool betting round */
export interface DeadPoolRound {
	id: string;
	roundNumber: number;
	type: DeadPoolRoundType;
	status: DeadPoolStatus;
	/** Target level for the bet (null for system-wide bets like system_reset) */
	targetLevel: Level | null;
	question: string;
	/** The line to bet over/under */
	line: number;
	/** Round start timestamp */
	startsAt: number;
	/** Round end timestamp (resolution time) */
	endsAt: number;
	/** Betting closes at this time (before resolution) */
	locksAt: number;
	pools: {
		under: bigint;
		over: bigint;
	};
	userBet: {
		side: DeadPoolSide;
		amount: bigint;
		timestamp: number;
	} | null;
}

/** Result of a resolved Dead Pool round */
export interface DeadPoolResult {
	roundId: string;
	/** Winning side */
	outcome: DeadPoolSide;
	/** Actual value measured at resolution */
	actualValue: number;
	/** Total pool size (under + over) */
	totalPool: bigint;
	/** 5% rake burned */
	burnAmount: bigint;
	/** Pool distributed to winners */
	winnerPool: bigint;
	/** Whether current user won (null if didn't bet) */
	userWon: boolean | null;
	/** User's payout amount (null if didn't bet or lost) */
	userPayout: bigint | null;
}

/** Combined round with result for history display */
export interface DeadPoolHistory {
	round: DeadPoolRound;
	result: DeadPoolResult;
}

/** Real-time Dead Pool updates (discriminated union) */
export type DeadPoolUpdate =
	| { type: 'POOL_UPDATE'; roundId: string; pools: { under: bigint; over: bigint } }
	| { type: 'ROUND_LOCKED'; roundId: string }
	| { type: 'ROUND_RESOLVED'; result: DeadPoolResult }
	| { type: 'NEW_ROUND'; round: DeadPoolRound };

/** User's cumulative Dead Pool statistics */
export interface DeadPoolUserStats {
	totalBets: number;
	totalWon: bigint;
	totalLost: bigint;
	/** Win rate from 0 to 1 */
	winRate: number;
	biggestWin: bigint;
	/** Current streak: positive = consecutive wins, negative = consecutive losses */
	currentStreak: number;
}

// ════════════════════════════════════════════════════════════════
// HACK RUN (YIELD MULTIPLIER MINI-GAME)
// ════════════════════════════════════════════════════════════════

export * from './hackrun';
