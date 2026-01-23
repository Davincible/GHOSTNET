/**
 * GHOSTNET Arcade Type Definitions
 * =================================
 * Shared types for the arcade game engine and all mini-games.
 */

// ============================================================================
// GAME ENGINE TYPES
// ============================================================================

/** Standard game phases (games can extend with custom phases) */
export type StandardPhase = 'idle' | 'betting' | 'playing' | 'resolving' | 'complete';

/** Phase transition event */
export interface PhaseTransition<TPhase extends string = StandardPhase> {
	from: TPhase;
	to: TPhase;
	timestamp: number;
	data?: Record<string, unknown>;
}

/** Configuration for a game phase */
export interface PhaseConfig<TPhase extends string = StandardPhase> {
	/** Phase identifier */
	phase: TPhase;
	/** Optional timeout (auto-transitions after duration) */
	timeout?: number;
	/** Phase to transition to on timeout */
	timeoutTarget?: TPhase;
	/** Callback when entering phase */
	onEnter?: () => void | Promise<void>;
	/** Callback when exiting phase */
	onExit?: () => void | Promise<void>;
	/** Guard function - return false to prevent transition */
	canEnter?: () => boolean;
}

/** Game engine configuration */
export interface GameEngineConfig<TPhase extends string = StandardPhase> {
	/** Initial phase (defaults to 'idle') */
	initialPhase?: TPhase;
	/** Phase configurations */
	phases: PhaseConfig<TPhase>[];
	/** Valid transitions map: phase -> allowed target phases */
	transitions: Record<TPhase, TPhase[]>;
	/** Global error handler */
	onError?: (error: Error, phase: TPhase) => void;
}

/** Game engine state */
export interface GameEngineState<TPhase extends string = StandardPhase> {
	/** Current phase */
	phase: TPhase;
	/** Previous phase (null on initial) */
	previousPhase: TPhase | null;
	/** Timestamp when current phase started */
	phaseStartTime: number;
	/** Whether a transition is in progress */
	transitioning: boolean;
	/** Error state (if any) */
	error: Error | null;
	/** Phase history for debugging */
	history: PhaseTransition<TPhase>[];
}

// ============================================================================
// TIMER SYSTEM TYPES
// ============================================================================

export type TimerStatus = 'idle' | 'running' | 'paused' | 'complete';

export interface CountdownState {
	/** Timer status */
	status: TimerStatus;
	/** Initial duration in ms */
	duration: number;
	/** Remaining time in ms */
	remaining: number;
	/** Progress from 0 to 1 (1 = complete) */
	progress: number;
	/** Formatted time string (MM:SS or SS.ms) */
	display: string;
	/** Whether in final seconds (for visual urgency) */
	critical: boolean;
}

export interface ClockState {
	/** Timer status */
	status: TimerStatus;
	/** Elapsed time in ms */
	elapsed: number;
	/** Formatted time string */
	display: string;
	/** Start timestamp */
	startTime: number;
}

export interface CountdownConfig {
	/** Duration in milliseconds */
	duration: number;
	/** Update interval (default: 100ms) */
	interval?: number;
	/** Threshold for critical state in ms (default: 5000) */
	criticalThreshold?: number;
	/** Show milliseconds in display (default: false) */
	showMilliseconds?: boolean;
	/** Callback when countdown completes */
	onComplete?: () => void;
	/** Callback on each tick */
	onTick?: (remaining: number) => void;
}

export interface ClockConfig {
	/** Update interval (default: 100ms) */
	interval?: number;
	/** Maximum duration before auto-stop (optional) */
	maxDuration?: number;
	/** Callback when max duration reached */
	onMaxReached?: () => void;
}

// ============================================================================
// SCORE SYSTEM TYPES
// ============================================================================

export interface ScoreState {
	/** Current score */
	score: number;
	/** Current multiplier */
	multiplier: number;
	/** Base multiplier (before modifiers) */
	baseMultiplier: number;
	/** Current combo count */
	combo: number;
	/** Max combo this session */
	maxCombo: number;
	/** Current streak */
	streak: number;
	/** Max streak this session */
	maxStreak: number;
	/** Score history for animations */
	recentScores: ScoreEvent[];
}

export interface ScoreEvent {
	/** Unique ID for keying */
	id: string;
	/** Points added (before multiplier) */
	basePoints: number;
	/** Points added (after multiplier) */
	finalPoints: number;
	/** Multiplier at time of score */
	multiplier: number;
	/** Combo at time of score */
	combo: number;
	/** Timestamp */
	timestamp: number;
	/** Label for display */
	label?: string;
}

export interface ScoreConfig {
	/** Initial multiplier (default: 1) */
	initialMultiplier?: number;
	/** Combo decay time in ms (0 = no decay) */
	comboDecay?: number;
	/** Max combo (0 = unlimited) */
	maxCombo?: number;
	/** Multiplier increase per combo level */
	comboMultiplierBonus?: number;
	/** Number of recent scores to keep */
	recentScoresLimit?: number;
}

// ============================================================================
// REWARD SYSTEM TYPES
// ============================================================================

export interface RewardTier {
	/** Unique identifier */
	id: string;
	/** Display name */
	name: string;
	/** Minimum threshold to qualify */
	minThreshold: number;
	/** Reward value (interpretation depends on reward type) */
	value: number;
	/** Human-readable description */
	description: string;
}

export interface RewardConfig {
	/** House edge as decimal (0.03 = 3%) */
	houseEdge: number;
	/** Burn rate as decimal (1.0 = 100% of house edge burned) */
	burnRate: number;
	/** Minimum bet amount in wei */
	minBet: bigint;
	/** Maximum bet amount in wei */
	maxBet: bigint;
	/** Reward tiers (sorted by threshold descending) */
	tiers?: RewardTier[];
}

export interface PayoutCalculation {
	/** Original bet amount */
	bet: bigint;
	/** Multiplier applied */
	multiplier: number;
	/** Gross payout (bet * multiplier) */
	grossPayout: bigint;
	/** House edge amount */
	houseEdgeAmount: bigint;
	/** Amount burned */
	burnAmount: bigint;
	/** Net payout to player */
	netPayout: bigint;
	/** Profit (net - bet) */
	profit: bigint;
	/** Whether player is in profit */
	isWin: boolean;
}

export interface PoolPayoutCalculation {
	/** Total pool size */
	totalPool: bigint;
	/** Winning side total */
	winningPool: bigint;
	/** Losing side total */
	losingPool: bigint;
	/** Rake taken */
	rakeAmount: bigint;
	/** Amount burned */
	burnAmount: bigint;
	/** Distributable pool */
	distributablePool: bigint;
	/** Payout multiplier for winners */
	payoutMultiplier: number;
}

export interface RewardState {
	/** Current bet amount */
	currentBet: bigint;
	/** Entry fee (burned on entry) */
	entryFee: bigint;
	/** Accumulated winnings this session */
	sessionWinnings: bigint;
	/** Accumulated losses this session */
	sessionLosses: bigint;
	/** Net P&L this session */
	sessionPnL: bigint;
	/** Games played this session */
	gamesPlayed: number;
	/** Games won this session */
	gamesWon: number;
	/** Win rate (0-1) */
	winRate: number;
}

// ============================================================================
// GAME-SPECIFIC TYPES
// ============================================================================

/** HASH CRASH specific types */
export type HashCrashPhase = 'idle' | 'betting' | 'locked' | 'revealed' | 'animating' | 'settled';

export interface HashCrashRound {
	roundId: number;
	state: HashCrashPhase;
	totalBets: bigint;
	playerCount: number;
	seedBlock: number | null;
	seedHash: `0x${string}` | null;
	crashPoint: number | null;
	startTime: number;
	bettingEndsAt: number;
}

export interface HashCrashBet {
	/** Bet amount in wei */
	amount: bigint;
	/** Target cash-out multiplier (pre-committed) */
	targetMultiplier: number;
}

export interface HashCrashPlayerResult {
	address: `0x${string}`;
	targetMultiplier: number;
	won: boolean;
	payout: bigint;
}
