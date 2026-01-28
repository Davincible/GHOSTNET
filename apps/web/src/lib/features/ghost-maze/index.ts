/**
 * Ghost Maze - Feature Module
 * ============================
 * Pac-Man inspired network infiltration game.
 *
 * @example
 * ```typescript
 * import { generateMaze, createGameLoop, createInputHandler } from '$lib/features/ghost-maze';
 * ```
 */

// Types
export type {
	Coord,
	Direction,
	Cell,
	CellContent,
	MazeGrid,
	TracerType,
	TracerMode,
	TracerState,
	TracerData,
	GhostMazePhase,
	EntryTier,
	InputAction,
	InputRecord,
	GameReplay,
	RenderEntity,
} from './types';

export { DIRECTIONS, DIRECTION_VECTORS, OPPOSITE_DIRECTION, MAZE_CHARS, PHASE_TRANSITIONS } from './types';

// Engine
export * from './engine';

// Constants
export * from './constants';

// Store
export { createGhostMazeStore, type GhostMazeStore, type GhostMazeState } from './store.svelte';

// Components
export { default as GhostMazeGame } from './components/GhostMazeGame.svelte';
