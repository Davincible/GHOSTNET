/**
 * Tracer AI
 * ==========
 * Behavioral logic for all 4 tracer types.
 * Each tracer type has a unique movement strategy.
 *
 * Called once per tick for each tracer. Returns the direction to move.
 * Pure functions — no side effects, no state mutation.
 */

import type {
	Coord,
	Direction,
	MazeGrid,
	TracerState,
	TracerType,
	PatrolTracerData,
	HunterTracerData,
	PhantomTracerData,
	SwarmTracerData,
} from '../types';
import { OPPOSITE_DIRECTION, DIRECTION_VECTORS } from '../types';
import {
	TRACER_SPEED,
	HUNTER_LOS_RANGE,
	HUNTER_CHASE_TICKS,
	HUNTER_PATH_REFRESH_TICKS,
	PHANTOM_TELEPORT_TICKS,
	PHANTOM_WARNING_TICKS,
	PHANTOM_MIN_TELEPORT_DISTANCE,
	TRACER_RESPAWN_TICKS,
} from '../constants';
import { canMove, getValidDirections, getValidDirectionsExcept, hasLineOfSight } from './collision';
import { findPath, getPathDirection } from './pathfinding';
import { manhattanDistance, createRng, isInBounds } from './maze-generator';

// ============================================================================
// TICK TIMING
// ============================================================================

/**
 * Check if a tracer should move this tick based on its speed.
 * Speed is relative to player (1.0 = same speed as player).
 * Player moves every tick; tracers at 0.8x move every 1/0.8 = 1.25 ticks.
 */
export function shouldTracerMove(
	type: TracerType,
	tick: number,
	playerSpeed: number,
	isFrightened: boolean,
): boolean {
	const baseSpeed = TRACER_SPEED[type];
	const speed = isFrightened ? baseSpeed * 0.5 : baseSpeed;
	const effectiveSpeed = speed * playerSpeed;

	// Move every N ticks where N = 1/effectiveSpeed
	// Use modulo to distribute movement evenly
	if (effectiveSpeed >= 1) return true;
	const period = Math.round(1 / effectiveSpeed);
	return tick % period === 0;
}

// ============================================================================
// PATROL TRACER
// ============================================================================

/**
 * Patrol tracer: follows a circuit of waypoints.
 * When reaching a waypoint, advances to the next one.
 * Predictable — players can learn the pattern.
 */
export function updatePatrol(
	tracer: TracerState,
	grid: MazeGrid,
	_playerPos: Coord,
): Direction | null {
	const data = tracer.data as PatrolTracerData;

	if (data.waypoints.length === 0) {
		// No waypoints — random walk
		return randomDirection(grid, tracer.pos, tracer.dir);
	}

	const target = data.waypoints[data.waypointIndex];

	// If we've reached the current waypoint, advance
	if (tracer.pos.x === target.x && tracer.pos.y === target.y) {
		data.waypointIndex = (data.waypointIndex + 1) % data.waypoints.length;
		const nextTarget = data.waypoints[data.waypointIndex];
		return directionToward(grid, tracer.pos, nextTarget, tracer.dir);
	}

	return directionToward(grid, tracer.pos, target, tracer.dir);
}

// ============================================================================
// HUNTER TRACER
// ============================================================================

/**
 * Hunter tracer: two modes.
 * - Scatter: move toward home corner
 * - Chase: A* pathfind toward player when in line-of-sight range
 */
export function updateHunter(
	tracer: TracerState,
	grid: MazeGrid,
	playerPos: Coord,
): Direction | null {
	const data = tracer.data as HunterTracerData;

	// Check line-of-sight to player
	const dist = manhattanDistance(tracer.pos, playerPos);
	const inRange = dist <= HUNTER_LOS_RANGE && hasLineOfSight(grid, tracer.pos, playerPos);

	if (inRange && !data.chasing) {
		// Enter chase mode
		data.chasing = true;
		data.chaseTicks = 0;
		data.currentPath = [];
		data.pathRefreshTicks = 0;
	}

	if (data.chasing) {
		data.chaseTicks++;

		// Disengage after time limit or LOS broken
		if (data.chaseTicks > HUNTER_CHASE_TICKS || (!inRange && data.chaseTicks > HUNTER_PATH_REFRESH_TICKS)) {
			data.chasing = false;
			data.chaseTicks = 0;
			data.currentPath = [];
		} else {
			// Recompute path periodically
			data.pathRefreshTicks--;
			if (data.pathRefreshTicks <= 0 || data.currentPath.length === 0) {
				data.currentPath = findPath(grid, tracer.pos, playerPos) ?? [];
				data.pathRefreshTicks = HUNTER_PATH_REFRESH_TICKS;
			}

			// Follow path
			if (data.currentPath.length > 1) {
				// Remove current position from path
				if (
					data.currentPath[0].x === tracer.pos.x &&
					data.currentPath[0].y === tracer.pos.y
				) {
					data.currentPath.shift();
				}
				const dir = getPathDirection([tracer.pos, ...data.currentPath]);
				if (dir && canMove(grid, tracer.pos, dir)) return dir;
			}
		}
	}

	// Scatter mode: move toward home corner
	return directionToward(grid, tracer.pos, data.homeCorner, tracer.dir);
}

// ============================================================================
// PHANTOM TRACER
// ============================================================================

/**
 * Phantom tracer: slow random walk, teleports every 15 seconds.
 * Returns the direction to move, or null if teleporting.
 *
 * Teleport logic (state mutation) is handled by the caller using the
 * returned PhantomAction.
 */
export interface PhantomAction {
	type: 'move' | 'teleport_warning' | 'teleport';
	direction?: Direction;
	destination?: Coord;
}

export function updatePhantom(
	tracer: TracerState,
	grid: MazeGrid,
	playerPos: Coord,
	rng: () => number,
): PhantomAction {
	const data = tracer.data as PhantomTracerData;

	data.teleportTimer--;

	if (data.teleportTimer <= 0) {
		// Teleport!
		const dest = findTeleportDestination(grid, playerPos, rng);
		data.teleportTimer = PHANTOM_TELEPORT_TICKS;
		data.teleportWarning = false;
		return { type: 'teleport', destination: dest };
	}

	if (data.teleportTimer <= PHANTOM_WARNING_TICKS && !data.teleportWarning) {
		data.teleportWarning = true;
		return { type: 'teleport_warning' };
	}

	// Random walk
	const dir = randomDirection(grid, tracer.pos, tracer.dir);
	return { type: 'move', direction: dir ?? undefined };
}

function findTeleportDestination(
	grid: MazeGrid,
	playerPos: Coord,
	rng: () => number,
): Coord {
	// Find a random valid cell at least PHANTOM_MIN_TELEPORT_DISTANCE from player
	const candidates: Coord[] = [];

	for (let y = 0; y < grid.height; y++) {
		for (let x = 0; x < grid.width; x++) {
			if (manhattanDistance({ x, y }, playerPos) >= PHANTOM_MIN_TELEPORT_DISTANCE) {
				// Must be a passable cell (has at least one open direction)
				const validDirs = getValidDirections(grid, { x, y });
				if (validDirs.length > 0) {
					candidates.push({ x, y });
				}
			}
		}
	}

	if (candidates.length === 0) {
		// Fallback: any cell far-ish from player
		return { x: 0, y: 0 };
	}

	return candidates[Math.floor(rng() * candidates.length)];
}

// ============================================================================
// SWARM TRACER
// ============================================================================

/**
 * Swarm tracer: simple pursuit with no pathfinding.
 * At each intersection, picks the direction closest to player.
 * Faster but dumber than Hunter.
 */
export function updateSwarm(
	tracer: TracerState,
	grid: MazeGrid,
	playerPos: Coord,
): Direction | null {
	const _data = tracer.data as SwarmTracerData;

	// At each step, pick valid direction that minimizes distance to player
	const validDirs = getValidDirectionsExcept(grid, tracer.pos, OPPOSITE_DIRECTION[tracer.dir]);

	if (validDirs.length === 0) {
		// Dead end — must reverse
		const reverse = OPPOSITE_DIRECTION[tracer.dir];
		return canMove(grid, tracer.pos, reverse) ? reverse : null;
	}

	// Pick direction that gets closest to player
	let bestDir = validDirs[0];
	let bestDist = Infinity;

	for (const dir of validDirs) {
		const v = DIRECTION_VECTORS[dir];
		const nx = tracer.pos.x + v.x;
		const ny = tracer.pos.y + v.y;
		const dist = manhattanDistance({ x: nx, y: ny }, playerPos);
		if (dist < bestDist) {
			bestDist = dist;
			bestDir = dir;
		}
	}

	return bestDir;
}

// ============================================================================
// FRIGHTENED MODE (shared)
// ============================================================================

/**
 * Frightened behavior: reverse direction, then random walk (flee from player).
 * Called for all tracer types during Ghost Mode.
 */
export function updateFrightened(
	tracer: TracerState,
	grid: MazeGrid,
	playerPos: Coord,
): Direction | null {
	// Move away from player — pick direction that maximizes distance
	const validDirs = getValidDirections(grid, tracer.pos);

	if (validDirs.length === 0) return null;

	let bestDir = validDirs[0];
	let bestDist = -1;

	for (const dir of validDirs) {
		const v = DIRECTION_VECTORS[dir];
		const nx = tracer.pos.x + v.x;
		const ny = tracer.pos.y + v.y;
		const dist = manhattanDistance({ x: nx, y: ny }, playerPos);
		if (dist > bestDist) {
			bestDist = dist;
			bestDir = dir;
		}
	}

	return bestDir;
}

// ============================================================================
// SHARED HELPERS
// ============================================================================

/**
 * Pick a random valid direction, preferring not to reverse.
 */
function randomDirection(
	grid: MazeGrid,
	pos: Coord,
	currentDir: Direction,
): Direction | null {
	// Prefer not reversing
	const dirs = getValidDirectionsExcept(grid, pos, OPPOSITE_DIRECTION[currentDir]);

	if (dirs.length > 0) {
		// Simple deterministic "random" based on position + direction count
		// For true randomness in non-critical paths, this is sufficient
		const idx = (pos.x * 7 + pos.y * 13 + dirs.length) % dirs.length;
		return dirs[idx];
	}

	// Dead end — must reverse
	const reverse = OPPOSITE_DIRECTION[currentDir];
	return canMove(grid, pos, reverse) ? reverse : null;
}

/**
 * Pick the best direction to move toward a target position.
 * Simple greedy — at each step, pick the valid direction that minimizes Manhattan distance.
 */
function directionToward(
	grid: MazeGrid,
	pos: Coord,
	target: Coord,
	currentDir: Direction,
): Direction | null {
	const validDirs = getValidDirections(grid, pos);

	if (validDirs.length === 0) return null;
	if (validDirs.length === 1) return validDirs[0];

	// Prefer not reversing unless it's the only option
	const nonReverse = validDirs.filter((d) => d !== OPPOSITE_DIRECTION[currentDir]);
	const candidates = nonReverse.length > 0 ? nonReverse : validDirs;

	let bestDir = candidates[0];
	let bestDist = Infinity;

	for (const dir of candidates) {
		const v = DIRECTION_VECTORS[dir];
		const nx = pos.x + v.x;
		const ny = pos.y + v.y;
		const dist = manhattanDistance({ x: nx, y: ny }, target);
		if (dist < bestDist) {
			bestDist = dist;
			bestDir = dir;
		}
	}

	return bestDir;
}

// ============================================================================
// TRACER INITIALIZATION
// ============================================================================

/**
 * Generate patrol waypoints as a circuit around a region of the maze.
 */
export function generatePatrolWaypoints(
	grid: MazeGrid,
	spawnPos: Coord,
	rng: () => number,
): Coord[] {
	// Generate 4-8 waypoints in a rough circuit near the spawn
	const count = 4 + Math.floor(rng() * 5);
	const waypoints: Coord[] = [];
	const radius = Math.min(6, Math.floor(Math.min(grid.width, grid.height) / 3));

	for (let i = 0; i < count; i++) {
		const angle = (i / count) * Math.PI * 2;
		const x = Math.round(spawnPos.x + Math.cos(angle) * radius);
		const y = Math.round(spawnPos.y + Math.sin(angle) * radius);

		// Clamp to grid bounds
		const cx = Math.max(0, Math.min(grid.width - 1, x));
		const cy = Math.max(0, Math.min(grid.height - 1, y));

		waypoints.push({ x: cx, y: cy });
	}

	return waypoints;
}
