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
		dataDensity: 0.35,
		playerSpeed: 1.0,
		theme: 'MAINFRAME',
		loopFactor: 0.2,
	},
	{
		level: 2,
		gridWidth: 25,
		gridHeight: 17,
		tracerMix: { patrol: 2, hunter: 1, phantom: 0, swarm: 0 },
		tracerDensity: 0.8,       // ~3 tracers on 25×17
		dataDensity: 0.4,
		playerSpeed: 1.1,
		theme: 'SUBNET',
		loopFactor: 0.2,
	},
	{
		level: 3,
		gridWidth: 29,
		gridHeight: 19,
		tracerMix: { patrol: 2, hunter: 1, phantom: 1, swarm: 0 },
		tracerDensity: 0.9,       // ~5 tracers on 29×19
		dataDensity: 0.45,
		playerSpeed: 1.2,
		theme: 'DARKNET',
		loopFactor: 0.22,
	},
	{
		level: 4,
		gridWidth: 33,
		gridHeight: 21,
		tracerMix: { patrol: 1, hunter: 1, phantom: 1, swarm: 2 },
		tracerDensity: 1.0,       // ~7 tracers on 33×21
		dataDensity: 0.5,
		playerSpeed: 1.3,
		theme: 'BLACK ICE',
		loopFactor: 0.22,
	},
	{
		level: 5,
		gridWidth: 37,
		gridHeight: 23,
		tracerMix: { patrol: 0, hunter: 2, phantom: 1, swarm: 4 },
		tracerDensity: 1.2,       // ~10 tracers on 37×23
		dataDensity: 0.55,
		playerSpeed: 1.5,
		theme: 'CORE',
		loopFactor: 0.25,
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
export const DEATH_ANIMATION_TICKS = Math.round(0.5 * TICK_RATE); // 0.5 seconds

// ============================================================================
// GHOST MODE (Power Node)
// ============================================================================

/** Ghost mode duration (ticks) */
export const GHOST_MODE_TICKS = Math.round(8 * TICK_RATE); // 8 seconds

/** Ghost mode warning threshold (ticks remaining) */
export const GHOST_MODE_WARNING_TICKS = Math.round(2 * TICK_RATE); // 2 seconds before end

/** Tracer respawn delay after being destroyed in ghost mode (ticks) */
export const TRACER_RESPAWN_TICKS = Math.round(15 * TICK_RATE); // 15 seconds

/** Frightened tracer speed multiplier */
export const FRIGHTENED_SPEED_MULT = 0.5;

// ============================================================================
// EMP
// ============================================================================

/** EMP freeze duration (ticks) */
export const EMP_FREEZE_TICKS = Math.round(5 * TICK_RATE); // 5 seconds

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
export const PHANTOM_TELEPORT_TICKS = Math.round(15 * TICK_RATE); // 15 seconds

/** Phantom teleport warning duration before teleport (ticks) */
export const PHANTOM_WARNING_TICKS = Math.round(1 * TICK_RATE); // 1 second

/** Minimum distance from player for phantom teleport destination (cells) */
export const PHANTOM_MIN_TELEPORT_DISTANCE = 5;

// ============================================================================
// INPUT
// ============================================================================

/** Input buffer grace period (ticks) — how long a buffered direction persists */
export const INPUT_BUFFER_TICKS = 3; // ~200ms at 15 ticks/s

// ============================================================================
// COMBO
// ============================================================================

/** Combo decay timeout (ticks) — reset combo after this many ticks without collecting */
export const COMBO_DECAY_TICKS = Math.round(1.5 * TICK_RATE); // 1.5 seconds

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

/** Number of power nodes per level */
export const POWER_NODES_PER_LEVEL = 4;

// ============================================================================
// UI TIMING
// ============================================================================

/** Level intro display duration (ticks) */
export const LEVEL_INTRO_TICKS = Math.round(2 * TICK_RATE); // 2 seconds

/** Level clear celebration duration (ticks) */
export const LEVEL_CLEAR_TICKS = Math.round(2 * TICK_RATE); // 2 seconds
