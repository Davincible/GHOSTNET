/**
 * Ghost Maze Engine
 * ==================
 * Pure TypeScript game engine — no Svelte dependencies.
 * All modules are testable without a browser.
 */

// Maze generation
export { generateMaze, getCell, getCellIndex, hasWall, isInBounds, manhattanDistance, createRng } from './maze-generator';
export type { GenerateMazeConfig } from './maze-generator';

// Collision detection
export { canMove, tryMove, overlaps, getValidDirections, getValidDirectionsExcept, hasLineOfSight } from './collision';

// Pathfinding
export { findPath, getPathDirection } from './pathfinding';

// Input handling
export { createInputHandler } from './input';
export type { InputHandler, InputState } from './input';

// Tracer AI
export {
	shouldTracerMove,
	updatePatrol,
	updateHunter,
	updatePhantom,
	updateSwarm,
	updateFrightened,
	generatePatrolWaypoints,
} from './tracer-ai';
export type { PhantomAction } from './tracer-ai';

// Game loop
export { createGameLoop, TICK_RATE, TICK_MS } from './game-loop';
export type { GameLoop, GameLoopCallbacks } from './game-loop';
