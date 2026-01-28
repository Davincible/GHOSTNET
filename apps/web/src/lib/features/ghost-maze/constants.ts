/**
 * Ghost Maze - Constants
 * =======================
 * Level configurations, scoring values, speeds, and tuning parameters.
 * All gameplay-affecting numbers live here for easy tuning.
 */

import type { TracerType, EntryTier } from './types';

// ============================================================================
// GAME LOOP
// ============================================================================

/** Logic ticks per second (fixed timestep) */
export const TICK_RATE = 15;

/** Milliseconds per tick */
export const TICK_MS = 1000 / TICK_RATE;

// ============================================================================
// LEVELS
// ============================================================================

export interface TracerSpawnConfig {
	readonly type: TracerType;
	readonly count: number;
}

/**
 * Tracer mix: fractional weights for each type.
 * These are proportions — the dynamic count system distributes
 * the total tracer budget across types by these weights.
 */
export interface TracerMix {
	readonly patrol: number;
	readonly hunter: number;
	readonly phantom: number;
	readonly swarm: number;
}

export interface LevelConfig {
	readonly level: number;
	readonly gridWidth: number;
	readonly gridHeight: number;
	/** Tracer mix weights (proportional). Counts computed from grid area. */
	readonly tracerMix: TracerMix;
	/** Tracer density: tracers per 100 cells of grid area */
	readonly tracerDensity: number;
	/** Data packet density: fraction of corridor cells to fill (0-1) */
	readonly dataDensity: number;
	readonly playerSpeed: number;
	readonly theme: string;
	/** Percentage of walls to remove to create loops (0-1) */
	readonly loopFactor: number;
	/** Ghost mode duration in seconds (shrinks per level) */
	readonly ghostModeDuration: number;
	/** Number of power nodes placed in this level */
	readonly powerNodes: number;
}

/**
 * Compute concrete tracer spawn configs from level config and grid dimensions.
 * Total count = floor(area * density / 100), distributed by mix weights.
 * Swarm tracers are always rounded to even (they travel in pairs).
 */
export function computeTracers(config: LevelConfig): TracerSpawnConfig[] {
	const area = config.gridWidth * config.gridHeight;
	const total = Math.max(1, Math.floor(area * config.tracerDensity / 100));

	const mix = config.tracerMix;
	const totalWeight = mix.patrol + mix.hunter + mix.phantom + mix.swarm;
	if (totalWeight === 0) return [];

	const result: TracerSpawnConfig[] = [];
	let remaining = total;

	// Allocate in order: swarm first (needs even count), then others
	const types: TracerType[] = ['swarm', 'phantom', 'hunter', 'patrol'];
	for (const type of types) {
		const weight = mix[type];
		if (weight <= 0) continue;

		let count: number;
		if (type === 'patrol') {
			// Patrol gets whatever remains
			count = remaining;
		} else {
			count = Math.round((weight / totalWeight) * total);
			// Swarm must be even and at least 2
			if (type === 'swarm') {
				count = Math.max(2, count % 2 === 0 ? count : count + 1);
			}
			count = Math.min(count, remaining);
			// Re-enforce even constraint after min clamping
			if (type === 'swarm' && count % 2 !== 0) {
				count = Math.max(0, count - 1);
			}
		}

		if (count > 0) {
			result.push({ type, count });
			remaining -= count;
		}
	}

	return result;
}

/**
 * Compute data packet count from grid area and density.
 */
export function computeDataPackets(config: LevelConfig): number {
	const area = config.gridWidth * config.gridHeight;
	// Rough corridor estimate: ~60% of cells are corridors after generation
	const corridorEstimate = Math.floor(area * 0.6);
	return Math.max(10, Math.floor(corridorEstimate * config.dataDensity));
}

export const LEVELS: readonly LevelConfig[] = [
	{
		level: 1,
		gridWidth: 21,
		gridHeight: 15,
		tracerMix: { patrol: 1, hunter: 0, phantom: 0, swarm: 0 },
		tracerDensity: 0.7,       // ~2 tracers on 21×15
		dataDensity: 0.50,        // More dots — less empty walking
		playerSpeed: 1.0,
		theme: 'MAINFRAME',
		loopFactor: 0.2,
		ghostModeDuration: 7,     // Generous intro
		powerNodes: 2,            // Only 2 — don't trivialize
	},
	{
		level: 2,
		gridWidth: 25,
		gridHeight: 17,
		tracerMix: { patrol: 2, hunter: 1, phantom: 0, swarm: 0 },
		tracerDensity: 0.8,       // ~3 tracers
		dataDensity: 0.55,
		playerSpeed: 1.1,
		theme: 'SUBNET',
		loopFactor: 0.2,
		ghostModeDuration: 6,
		powerNodes: 3,
	},
	{
		level: 3,
		gridWidth: 29,
		gridHeight: 19,
		tracerMix: { patrol: 2, hunter: 1, phantom: 1, swarm: 0 },
		tracerDensity: 0.9,       // ~5 tracers
		dataDensity: 0.55,
		playerSpeed: 1.2,
		theme: 'DARKNET',
		loopFactor: 0.18,         // Fewer loops = more dead ends
		ghostModeDuration: 5,
		powerNodes: 3,
	},
	{
		level: 4,
		gridWidth: 33,
		gridHeight: 21,
		tracerMix: { patrol: 1, hunter: 1, phantom: 1, swarm: 2 },
		tracerDensity: 1.0,       // ~7 tracers
		dataDensity: 0.55,
		playerSpeed: 1.3,
		theme: 'BLACK ICE',
		loopFactor: 0.16,
		ghostModeDuration: 4.5,
		powerNodes: 3,
	},
	{
		level: 5,
		gridWidth: 37,
		gridHeight: 23,
		tracerMix: { patrol: 0, hunter: 2, phantom: 1, swarm: 4 },
		tracerDensity: 1.2,       // ~10 tracers
		dataDensity: 0.60,
		playerSpeed: 1.5,
		theme: 'CORE',
		loopFactor: 0.14,         // Tight mazes
		ghostModeDuration: 3.5,
		powerNodes: 4,
	},
] as const;

/** Total number of levels */
export const TOTAL_LEVELS = LEVELS.length;

// ============================================================================
// PLAYER
// ============================================================================

/** Starting lives */
export const INITIAL_LIVES = 3;

/** Maximum lives */
export const MAX_LIVES = 5;

/** Score threshold for extra life */
export const EXTRA_LIFE_SCORE = 50_000;

/** Invincibility duration after respawn (ticks) */
export const RESPAWN_INVINCIBILITY_TICKS = Math.round(2 * TICK_RATE); // 2 seconds

/** Death animation duration (ticks) */
export const DEATH_ANIMATION_TICKS = Math.round(1.2 * TICK_RATE); // 1.2 seconds (longer = weightier)

// ============================================================================
// GHOST MODE (Power Node)
// ============================================================================

/** Ghost mode warning threshold (ticks remaining) */
export const GHOST_MODE_WARNING_TICKS = Math.round(2 * TICK_RATE); // 2 seconds before end

/** Tracer respawn delay after being destroyed in ghost mode (ticks) */
export const TRACER_RESPAWN_TICKS = Math.round(8 * TICK_RATE); // 8 seconds (was 15 — too long)

/** Frightened tracer speed multiplier */
export const FRIGHTENED_SPEED_MULT = 0.5;

// ============================================================================
// EMP
// ============================================================================

/** EMP freeze duration (ticks) */
export const EMP_FREEZE_TICKS = Math.round(3 * TICK_RATE); // 3 seconds (was 5 — too generous)

// ============================================================================
// TRACER SPEEDS (relative to player speed of 1.0)
// ============================================================================

export const TRACER_SPEED: Readonly<Record<TracerType, number>> = {
	patrol: 0.8,
	hunter: 0.9,
	phantom: 0.7,
	swarm: 1.0,
} as const;

// ============================================================================
// TRACER AI
// ============================================================================

/** Hunter chase mode line-of-sight range (cells) */
export const HUNTER_LOS_RANGE = 8;

/** Hunter chase mode disengage after this many ticks */
export const HUNTER_CHASE_TICKS = Math.round(5 * TICK_RATE); // 5 seconds

/** Hunter path recompute interval (ticks) */
export const HUNTER_PATH_REFRESH_TICKS = Math.round(0.5 * TICK_RATE); // 500ms

/** Phantom teleport interval (ticks) */
export const PHANTOM_TELEPORT_TICKS = Math.round(10 * TICK_RATE); // 10s (was 15 — too infrequent)

/** Phantom teleport warning duration before teleport (ticks) */
export const PHANTOM_WARNING_TICKS = Math.round(1 * TICK_RATE); // 1 second

/** Minimum distance from player for phantom teleport destination (cells) */
export const PHANTOM_MIN_TELEPORT_DISTANCE = 5;

// ============================================================================
// SCATTER / CHASE CYCLE — The Heartbeat
// ============================================================================

/**
 * Tracers alternate between SCATTER (wander/patrol, predictable)
 * and CHASE (hunt the player, aggressive). This creates rhythm —
 * the player learns to recognize when danger escalates and relaxes.
 *
 * In scatter mode: patrol goes to waypoints, hunter goes to home corner,
 * phantom drifts randomly, swarm loosens formation.
 *
 * In chase mode: all tracers target the player with their unique behaviors.
 */
export interface ScatterChaseConfig {
	/** Duration of scatter phase (ticks) */
	readonly scatterTicks: number;
	/** Duration of chase phase (ticks) */
	readonly chaseTicks: number;
}

/**
 * Scatter/chase timings per level. Later levels = longer chase, shorter scatter.
 * Each cycle: scatter → chase → scatter → chase → ...
 */
export const SCATTER_CHASE_CONFIGS: readonly ScatterChaseConfig[] = [
	{ scatterTicks: Math.round(7 * TICK_RATE), chaseTicks: Math.round(7 * TICK_RATE) },   // L1: balanced
	{ scatterTicks: Math.round(6 * TICK_RATE), chaseTicks: Math.round(8 * TICK_RATE) },   // L2: slight chase bias
	{ scatterTicks: Math.round(5 * TICK_RATE), chaseTicks: Math.round(10 * TICK_RATE) },  // L3: aggressive
	{ scatterTicks: Math.round(4 * TICK_RATE), chaseTicks: Math.round(12 * TICK_RATE) },  // L4: relentless
	{ scatterTicks: Math.round(3 * TICK_RATE), chaseTicks: Math.round(15 * TICK_RATE) },  // L5: brutal
] as const;

// ============================================================================
// ESCALATION — Cruise Elroy
// ============================================================================

/**
 * When data remaining drops below thresholds, tracers speed up.
 * This creates end-of-level tension where the last few packets are frantic.
 */
export const ESCALATION_THRESHOLDS = [
	{ dataFraction: 0.30, speedBoost: 0.10 }, // 30% remaining: +10% speed
	{ dataFraction: 0.15, speedBoost: 0.20 }, // 15% remaining: +20% speed (danger zone)
] as const;

/**
 * Proximity alert range (Manhattan distance in cells).
 * When any tracer is within this range, UI shows danger indicators.
 */
export const PROXIMITY_ALERT_RANGE = 4;

/**
 * Near-miss range — adjacent cell. Triggers screen flash.
 */
export const NEAR_MISS_RANGE = 1;

// ============================================================================
// BONUS ITEMS
// ============================================================================

/**
 * Bonus items spawn mid-level and disappear after a timer.
 * They reward map awareness and risk-taking.
 */

/** Ticks between checking if a bonus should spawn */
export const BONUS_SPAWN_CHECK_INTERVAL = Math.round(12 * TICK_RATE); // Check every 12s

/** Probability of spawning when check fires (0-1) */
export const BONUS_SPAWN_CHANCE = 0.5;

/** How long a bonus item stays before vanishing (ticks) */
export const BONUS_LIFETIME_TICKS = Math.round(8 * TICK_RATE); // 8 seconds to grab it

/** Bonus item types and their effects */
export const BONUS_TYPES = {
	SCORE_BURST: { points: 500, label: '+500', char: '$' },
	SPEED_BOOST: { points: 100, label: 'SPEED', char: '»', durationTicks: Math.round(5 * TICK_RATE) },
	EXTRA_LIFE: { points: 0, label: '+LIFE', char: '♥' },
} as const;

export type BonusType = keyof typeof BONUS_TYPES;

/** Weighted pool for bonus selection. Extra life is rare. */
export const BONUS_WEIGHTS: readonly { type: BonusType; weight: number }[] = [
	{ type: 'SCORE_BURST', weight: 5 },
	{ type: 'SPEED_BOOST', weight: 3 },
	{ type: 'EXTRA_LIFE', weight: 1 },
] as const;

// ============================================================================
// INPUT
// ============================================================================

/** Input buffer grace period (ticks) — how long a buffered direction persists */
export const INPUT_BUFFER_TICKS = 3; // ~200ms at 15 ticks/s

// ============================================================================
// COMBO
// ============================================================================

/** Combo decay timeout (ticks) — reset combo after this many ticks without collecting */
export const COMBO_DECAY_TICKS = Math.round(0.8 * TICK_RATE); // 0.8 seconds (was 1.5 — too easy)

/** Combo multiplier thresholds */
export const COMBO_MULTIPLIERS: readonly { readonly minCombo: number; readonly multiplier: number }[] = [
	{ minCombo: 50, multiplier: 10 },
	{ minCombo: 20, multiplier: 5 },
	{ minCombo: 10, multiplier: 3 },
	{ minCombo: 5, multiplier: 2 },
	{ minCombo: 1, multiplier: 1 },
] as const;

// ============================================================================
// SCORING
// ============================================================================

/** Points per data packet (base, before combo multiplier) */
export const SCORE_DATA_PACKET = 10;

/** Points for destroying tracers in ghost mode (cascade doubles) */
export const SCORE_TRACER_DESTROY_BASE = 200;

/** Level clear bonus per level number */
export const SCORE_LEVEL_CLEAR = 1_000;

/** Perfect clear bonus per level number (all data + all tracers) */
export const SCORE_PERFECT_CLEAR = 5_000;

/** Time bonus per remaining second */
export const SCORE_TIME_BONUS_PER_SECOND = 50;

/** No-hit bonus per level */
export const SCORE_NO_HIT_BONUS = 2_000;

/** Full run clear bonus (all 5 levels) */
export const SCORE_FULL_RUN = 25_000;

/** Full run perfect bonus (all 5 levels perfect) */
export const SCORE_FULL_RUN_PERFECT = 100_000;

// ============================================================================
// SCORE THRESHOLDS (for economy rewards)
// ============================================================================

export const SCORE_THRESHOLDS = {
	SURVIVED: 10_000,
	COMPETENT: 25_000,
	SKILLED: 50_000,
	EXPERT: 100_000,
	MASTER: 200_000,
} as const;

// ============================================================================
// ENTRY FEES (in $DATA units, not wei)
// ============================================================================

export const ENTRY_FEES: Readonly<Record<EntryTier, number>> = {
	free: 0,
	standard: 25,
	advanced: 50,
	elite: 100,
} as const;

// ============================================================================
// MAZE GENERATION
// ============================================================================

/** Maximum dead-end corridor length (anti-frustration) */
export const MAX_DEAD_END_LENGTH = 3;

/** Minimum distance from player spawn to any tracer spawn (cells) */
export const MIN_TRACER_SPAWN_DISTANCE = 8;

// ============================================================================
// UI TIMING
// ============================================================================

/** Level intro display duration (ticks) */
export const LEVEL_INTRO_TICKS = Math.round(1.2 * TICK_RATE); // 1.2s (was 2 — too slow)

/** Level clear celebration duration (ticks) */
export const LEVEL_CLEAR_TICKS = Math.round(1.5 * TICK_RATE); // 1.5s (was 2 — too slow)
