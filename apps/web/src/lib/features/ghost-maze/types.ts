/**
 * Ghost Maze - Core Types
 * ========================
 * All type definitions for the Ghost Maze game engine.
 * Pure data types — no runtime behavior, no Svelte dependencies.
 */

// ============================================================================
// PRIMITIVES
// ============================================================================

/** Grid coordinate (integer positions) */
export interface Coord {
	readonly x: number;
	readonly y: number;
}

/** Cardinal direction */
export type Direction = 'up' | 'down' | 'left' | 'right';

/** All four directions for iteration */
export const DIRECTIONS: readonly Direction[] = ['up', 'down', 'left', 'right'] as const;

/** Direction vectors for grid movement */
export const DIRECTION_VECTORS: Readonly<Record<Direction, Coord>> = {
	up: { x: 0, y: -1 },
	down: { x: 0, y: 1 },
	left: { x: -1, y: 0 },
	right: { x: 1, y: 0 },
} as const;

/** Opposite direction lookup */
export const OPPOSITE_DIRECTION: Readonly<Record<Direction, Direction>> = {
	up: 'down',
	down: 'up',
	left: 'right',
	right: 'left',
} as const;

// ============================================================================
// MAZE
// ============================================================================

/**
 * A single cell in the maze grid.
 * Walls are stored per-cell on each edge (shared walls are kept in sync by the generator).
 */
export interface Cell {
	/** Whether a wall exists on each edge */
	readonly walls: Readonly<Record<Direction, boolean>>;
	/** What occupies this cell */
	readonly content: CellContent;
	/** Whether this cell has been visited (used during generation) */
	visited: boolean;
}

/** What a cell contains at any point in time */
export type CellContent = 'empty' | 'data' | 'power_node';

/**
 * The complete maze grid.
 * Stored as a flat array indexed by (y * width + x) for cache-friendly access.
 */
export interface MazeGrid {
	readonly width: number;
	readonly height: number;
	readonly cells: Cell[];
	readonly playerSpawn: Coord;
	readonly tracerSpawns: Coord[];
	readonly powerNodePositions: Coord[];
	readonly totalDataPackets: number;
}

// ============================================================================
// ENTITIES
// ============================================================================

/** Tracer AI type */
export type TracerType = 'patrol' | 'hunter' | 'phantom' | 'swarm';

/** Tracer behavioral mode */
export type TracerMode = 'normal' | 'frightened' | 'frozen' | 'dead' | 'returning';

/** State of a single tracer entity */
export interface TracerState {
	readonly id: number;
	readonly type: TracerType;
	pos: Coord;
	dir: Direction;
	mode: TracerMode;
	/** Ticks until respawn (when dead) */
	respawnTimer: number;
	/** Type-specific data */
	readonly data: TracerData;
}

/** Type-specific tracer data */
export type TracerData =
	| PatrolTracerData
	| HunterTracerData
	| PhantomTracerData
	| SwarmTracerData;

export interface PatrolTracerData {
	readonly type: 'patrol';
	/** Waypoints the patrol follows in order */
	waypoints: Coord[];
	/** Current waypoint index */
	waypointIndex: number;
	/** Cached A* path to current waypoint */
	currentPath: Coord[];
}

export interface HunterTracerData {
	readonly type: 'hunter';
	/** Whether currently chasing player */
	chasing: boolean;
	/** Ticks spent chasing (disengage after limit) */
	chaseTicks: number;
	/** Home corner to scatter toward */
	readonly homeCorner: Coord;
	/** Cached path to player */
	currentPath: Coord[];
	/** Ticks until next path recompute */
	pathRefreshTicks: number;
}

export interface PhantomTracerData {
	readonly type: 'phantom';
	/** Ticks until next teleport */
	teleportTimer: number;
	/** Whether currently in teleport warning phase */
	teleportWarning: boolean;
}

export interface SwarmTracerData {
	readonly type: 'swarm';
	/** ID of paired swarm partner */
	readonly partnerId: number;
	/** Offset from ideal pursuit direction for flocking */
	readonly flockOffset: Direction;
}

// ============================================================================
// SCATTER / CHASE
// ============================================================================

/** The current phase of the scatter/chase cycle */
export type ScatterChasePhase = 'scatter' | 'chase';

// ============================================================================
// BONUS ITEMS
// ============================================================================

import type { BonusType } from './constants';

/** A bonus item placed in the maze */
export interface BonusItem {
	readonly type: BonusType;
	readonly pos: Coord;
	/** Ticks remaining before the item vanishes */
	lifetime: number;
}

// ============================================================================
// SCORE POPUPS
// ============================================================================

/** A floating score popup that animates and fades */
export interface ScorePopup {
	readonly id: number;
	readonly text: string;
	/** Position in text-grid coordinates */
	readonly x: number;
	readonly y: number;
	/** Ticks remaining before removal */
	ticksLeft: number;
	/** Color class: 'default' | 'bonus' | 'tracer' | 'combo' */
	readonly variant: 'default' | 'bonus' | 'tracer' | 'combo';
}

// ============================================================================
// GAME STATE
// ============================================================================

/** Ghost Maze game phases */
export type GhostMazePhase =
	| 'idle'
	| 'entry'
	| 'level_intro'
	| 'playing'
	| 'ghost_mode'
	| 'player_death'
	| 'respawn'
	| 'level_clear'
	| 'game_over'
	| 'results'
	| 'paused';

/** Valid phase transitions */
export const PHASE_TRANSITIONS: Readonly<Record<GhostMazePhase, readonly GhostMazePhase[]>> = {
	idle: ['entry'],
	entry: ['level_intro', 'idle'],
	level_intro: ['playing'],
	playing: ['ghost_mode', 'player_death', 'level_clear', 'game_over', 'paused'],
	ghost_mode: ['playing', 'player_death', 'level_clear', 'paused'],
	player_death: ['respawn', 'game_over'],
	respawn: ['playing'],
	level_clear: ['level_intro', 'game_over'],
	game_over: ['results'],
	results: ['idle'],
	paused: ['playing', 'ghost_mode', 'idle'],
} as const;

/** Entry fee tier */
export type EntryTier = 'free' | 'standard' | 'advanced' | 'elite';

/** Input actions recorded for replay */
export type InputAction = Direction | 'emp' | 'pause' | 'unpause';

/** Single recorded input event */
export interface InputRecord {
	readonly tick: number;
	readonly action: InputAction;
}

/** Complete game replay for verification */
export interface GameReplay {
	readonly seed: number;
	readonly entryTier: EntryTier;
	readonly inputs: InputRecord[];
	readonly finalScore: number;
	readonly levelsCleared: number;
	readonly checksum: string;
}

// ============================================================================
// RENDERING
// ============================================================================

/** Character used to render each maze element */
export const MAZE_CHARS = {
	// Walls (box-drawing)
	WALL_H: '\u2550', // ═
	WALL_V: '\u2551', // ║
	CORNER_TL: '\u2554', // ╔
	CORNER_TR: '\u2557', // ╗
	CORNER_BL: '\u255A', // ╚
	CORNER_BR: '\u255D', // ╝
	TEE_L: '\u2560', // ╠
	TEE_R: '\u2563', // ╣
	TEE_T: '\u2566', // ╦
	TEE_B: '\u2569', // ╩
	CROSS: '\u256C', // ╬

	// Entities
	DATA_PACKET: '\u00B7', // ·
	POWER_NODE: '\u25C6', // ◆
	PLAYER: '@',
	TRACER_PATROL: 'T',
	TRACER_HUNTER: 'H',
	TRACER_PHANTOM: 'P',
	TRACER_SWARM: 's',
	TRACER_FRIGHTENED: '\u2591', // ░
	TRACER_FROZEN: '\u2588', // █
	TRACER_RETURNING: '\u25C9', // ◉ (eyes returning to base)
	BONUS_ITEM: '$',
	EMPTY: ' ',

	// HUD
	LIFE_FULL: '\u2665', // ♥
	LIFE_EMPTY: '\u2661', // ♡
} as const;

/** Entity type for rendering overlay */
export interface RenderEntity {
	readonly id: string;
	readonly type:
		| 'player'
		| 'tracer-patrol'
		| 'tracer-hunter'
		| 'tracer-phantom'
		| 'tracer-swarm'
		| 'tracer-frightened'
		| 'tracer-frozen'
		| 'tracer-returning'
		| 'power-node'
		| 'bonus-item';
	readonly x: number;
	readonly y: number;
	readonly char: string;
}
