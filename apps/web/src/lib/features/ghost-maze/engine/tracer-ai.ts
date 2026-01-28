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
} from '../constants';
import { canMove, getValidDirections, getValidDirectionsExcept, hasLineOfSight } from './collision';
import { findPath, getPathDirection } from './pathfinding';
import { manhattanDistance, isInBounds } from './maze-generator';

// ============================================================================
// TICK TIMING
// ============================================================================

/**
 * Check if a tracer should move this tick based on its speed.
 * Speed is relative to player (1.0 = same speed as player).
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
	if (effectiveSpeed >= 1) return true;
	const period = Math.round(1 / effectiveSpeed);
	return tick % period === 0;
}

// ============================================================================
// PATROL TRACER
// ============================================================================

/**
 * Patrol tracer: follows a circuit of validated waypoints.
 * When reaching a waypoint, advances to the next one.
 * Uses A* to navigate between waypoints — predictable but navigates
 * the actual maze structure instead of getting stuck on walls.
 */
export function updatePatrol(
	tracer: TracerState,
	grid: MazeGrid,
	_playerPos: Coord,
	rng: () => number,
): Direction | null {
	const data = tracer.data as PatrolTracerData;

	if (data.waypoints.length === 0) {
		return randomDirection(grid, tracer.pos, tracer.dir, rng);
	}

	const target = data.waypoints[data.waypointIndex];

	// If we've reached the current waypoint, advance and clear cached path
	if (tracer.pos.x === target.x && tracer.pos.y === target.y) {
		data.waypointIndex = (data.waypointIndex + 1) % data.waypoints.length;
		data.currentPath = [];
	}

	const nextTarget = data.waypoints[data.waypointIndex];

	// Use cached path if available; recompute only when empty
	if (data.currentPath.length === 0) {
		data.currentPath = findPath(grid, tracer.pos, nextTarget) ?? [];
	}

	// Consume cached path
	if (data.currentPath.length > 0) {
		// Advance past current position if it matches
		if (data.currentPath[0].x === tracer.pos.x && data.currentPath[0].y === tracer.pos.y) {
			data.currentPath.shift();
		}
		if (data.currentPath.length > 0) {
			const dir = getPathDirection([tracer.pos, data.currentPath[0]]);
			if (dir && canMove(grid, tracer.pos, dir)) return dir;
			// Path is stale — recompute next tick
			data.currentPath = [];
		}
	}

	// Fallback: greedy direction toward target
	return directionToward(grid, tracer.pos, nextTarget, tracer.dir);
}

// ============================================================================
// HUNTER TRACER
// ============================================================================

/**
 * Hunter tracer: two modes — scatter and chase.
 *
 * Improvements over basic version:
 * - **Proximity chase**: enters chase mode if within proximity range, even without LOS
 * - **Ambush targeting**: targets where the player is heading (2 cells ahead),
 *   not just where the player currently is
 * - **Scatter patrol**: in scatter mode, patrols toward home corner via A* rather
 *   than greedy direction (avoids getting stuck at walls)
 * - **Chase persistence**: stays in chase longer when close to player
 */
const HUNTER_PROXIMITY_RANGE = 5; // Chase without LOS within this range

export function updateHunter(
	tracer: TracerState,
	grid: MazeGrid,
	playerPos: Coord,
	isScatter = false,
): Direction | null {
	const data = tracer.data as HunterTracerData;

	// In scatter mode: force scatter behavior — go to home corner
	if (isScatter) {
		data.chasing = false;
		data.chaseTicks = 0;
		const scatterPath = findPath(grid, tracer.pos, data.homeCorner);
		if (scatterPath && scatterPath.length > 1) {
			const dir = getPathDirection([tracer.pos, ...scatterPath.slice(1)]);
			if (dir && canMove(grid, tracer.pos, dir)) return dir;
		}
		return directionToward(grid, tracer.pos, data.homeCorner, tracer.dir);
	}

	const dist = manhattanDistance(tracer.pos, playerPos);
	const inLOS = dist <= HUNTER_LOS_RANGE && hasLineOfSight(grid, tracer.pos, playerPos);
	const inProximity = dist <= HUNTER_PROXIMITY_RANGE;

	// Enter chase: LOS or close proximity
	if ((inLOS || inProximity) && !data.chasing) {
		data.chasing = true;
		data.chaseTicks = 0;
		data.currentPath = [];
		data.pathRefreshTicks = 0;
	}

	if (data.chasing) {
		data.chaseTicks++;

		// Disengage: timeout AND out of range (stay longer when close)
		const chaseTimeout = dist <= HUNTER_PROXIMITY_RANGE
			? HUNTER_CHASE_TICKS * 2  // Double persistence when close
			: HUNTER_CHASE_TICKS;

		if (data.chaseTicks > chaseTimeout && !inLOS && !inProximity) {
			data.chasing = false;
			data.chaseTicks = 0;
			data.currentPath = [];
		} else {
			// Recompute path periodically
			data.pathRefreshTicks--;
			if (data.pathRefreshTicks <= 0 || data.currentPath.length === 0) {
				// Ambush: target 2 cells ahead of where the player is heading
				const ambushTarget = getAmbushTarget(grid, playerPos, tracer.pos);
				data.currentPath = findPath(grid, tracer.pos, ambushTarget) ?? [];
				data.pathRefreshTicks = HUNTER_PATH_REFRESH_TICKS;
			}

			// Follow path
			if (data.currentPath.length > 1) {
				if (
					data.currentPath[0].x === tracer.pos.x &&
					data.currentPath[0].y === tracer.pos.y
				) {
					data.currentPath.shift();
				}
				const dir = getPathDirection([tracer.pos, ...data.currentPath]);
				if (dir && canMove(grid, tracer.pos, dir)) return dir;
			}

			// Path failed — fall back to greedy pursuit
			return directionToward(grid, tracer.pos, playerPos, tracer.dir);
		}
	}

	// Scatter mode: A* toward home corner, gives varied behavior
	const scatterPath = findPath(grid, tracer.pos, data.homeCorner);
	if (scatterPath && scatterPath.length > 1) {
		const dir = getPathDirection([tracer.pos, ...scatterPath.slice(1)]);
		if (dir && canMove(grid, tracer.pos, dir)) return dir;
	}

	return directionToward(grid, tracer.pos, data.homeCorner, tracer.dir);
}

/**
 * Compute an ambush target: project the player's likely direction
 * of travel 2 cells ahead. Falls back to player's current position.
 */
function getAmbushTarget(grid: MazeGrid, playerPos: Coord, tracerPos: Coord): Coord {
	// Project 2 cells ahead in the axis the player is furthest from the tracer
	const dx = playerPos.x - tracerPos.x;
	const dy = playerPos.y - tracerPos.y;

	let tx: number;
	let ty: number;
	if (Math.abs(dx) > Math.abs(dy)) {
		tx = playerPos.x + Math.sign(dx) * 2;
		ty = playerPos.y;
	} else {
		tx = playerPos.x;
		ty = playerPos.y + Math.sign(dy) * 2;
	}

	// Clamp to bounds
	tx = Math.max(0, Math.min(grid.width - 1, tx));
	ty = Math.max(0, Math.min(grid.height - 1, ty));

	// If target is valid, use it
	const validDirs = getValidDirections(grid, { x: tx, y: ty });
	if (validDirs.length > 0) return { x: tx, y: ty };

	// Fallback: player's actual position
	return playerPos;
}

// ============================================================================
// PHANTOM TRACER
// ============================================================================

/**
 * Phantom tracer: slow stalker that teleports.
 *
 * Improvements:
 * - **Stalking walk**: between teleports, drifts toward the player instead of
 *   pure random walk — creates tension as the phantom slowly closes in
 * - **Smart teleport**: biases teleport destination toward positions that are
 *   ahead of the player's path (cuts off escape routes)
 * - **Adaptive teleport interval**: teleports faster when further from player
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
		const dest = findSmartTeleportDestination(grid, playerPos, tracer.pos, rng);
		data.teleportTimer = PHANTOM_TELEPORT_TICKS;
		data.teleportWarning = false;
		return { type: 'teleport', destination: dest };
	}

	if (data.teleportTimer <= PHANTOM_WARNING_TICKS && !data.teleportWarning) {
		data.teleportWarning = true;
		return { type: 'teleport_warning' };
	}

	// Stalking walk: 60% chance to move toward player, 40% random
	if (rng() < 0.6) {
		const dir = directionToward(grid, tracer.pos, playerPos, tracer.dir);
		return { type: 'move', direction: dir ?? undefined };
	}

	const dir = randomDirection(grid, tracer.pos, tracer.dir, rng);
	return { type: 'move', direction: dir ?? undefined };
}

/**
 * Smart teleport: favors positions that are:
 * 1. At least MIN_DISTANCE from the player
 * 2. Biased toward being *ahead* of the player (between player and nearest power node or edge)
 * 3. Near corridors with multiple exits (harder to escape from)
 */
function findSmartTeleportDestination(
	grid: MazeGrid,
	playerPos: Coord,
	phantomPos: Coord,
	rng: () => number,
): Coord {
	const candidates: { pos: Coord; score: number }[] = [];

	for (let y = 0; y < grid.height; y++) {
		for (let x = 0; x < grid.width; x++) {
			const pos = { x, y };
			const distToPlayer = manhattanDistance(pos, playerPos);

			if (distToPlayer < PHANTOM_MIN_TELEPORT_DISTANCE) continue;

			const validDirs = getValidDirections(grid, pos);
			if (validDirs.length === 0) continue;

			// Score the position
			let score = 0;

			// Prefer positions at a moderate distance from the player (5-12 cells)
			if (distToPlayer <= 12) score += 3;
			if (distToPlayer <= 8) score += 2;

			// Prefer junctions (multiple exits = harder for player to avoid)
			score += validDirs.length;

			// Prefer positions that are between the phantom and the player
			// (cutting off the player's escape)
			const distPhantomToPlayer = manhattanDistance(phantomPos, playerPos);
			const distNewToPlayer = manhattanDistance(pos, playerPos);
			if (distNewToPlayer < distPhantomToPlayer) score += 2;

			// Avoid spawning too close to previous position
			const distToPrev = manhattanDistance(pos, phantomPos);
			if (distToPrev < 5) score -= 3;

			candidates.push({ pos, score });
		}
	}

	if (candidates.length === 0) return { x: 0, y: 0 };

	// Weighted random selection from top candidates
	candidates.sort((a, b) => b.score - a.score);
	const topN = Math.min(candidates.length, Math.max(5, Math.floor(candidates.length * 0.15)));
	return candidates[Math.floor(rng() * topN)].pos;
}

// ============================================================================
// SWARM TRACER
// ============================================================================

/**
 * Swarm tracer: paired pursuit with flanking behavior.
 *
 * Improvements:
 * - **Flanking**: one partner chases the player directly, the other offsets
 *   to approach from the partner's flock direction (left/right/up/down of player)
 * - **Pincer detection**: when both partners are on opposite sides of the player,
 *   they commit to direct pursuit for the kill
 * - **Speed awareness**: swarm is fast (1.0×), compensated by the offset making
 *   one member less efficient at actual pursuit
 */
export function updateSwarm(
	tracer: TracerState,
	grid: MazeGrid,
	playerPos: Coord,
	allTracers?: TracerState[],
	isScatter = false,
): Direction | null {
	const data = tracer.data as SwarmTracerData;
	const validDirs = getValidDirectionsExcept(grid, tracer.pos, OPPOSITE_DIRECTION[tracer.dir]);

	if (validDirs.length === 0) {
		const reverse = OPPOSITE_DIRECTION[tracer.dir];
		return canMove(grid, tracer.pos, reverse) ? reverse : null;
	}

	// In scatter mode: random walk (loose formation)
	if (isScatter) {
		return validDirs[Math.floor(Math.random() * validDirs.length)];
	}

	// Find partner position (if available)
	const partner = allTracers?.find(
		(t) => t.id === data.partnerId && t.mode !== 'dead',
	);

	// Compute target: direct pursuit or flanked offset
	let target: Coord;

	if (partner) {
		// Check for pincer: player is between this tracer and partner
		const ourDist = manhattanDistance(tracer.pos, playerPos);
		const partnerDist = manhattanDistance(partner.pos, playerPos);
		const pairDist = manhattanDistance(tracer.pos, partner.pos);
		const isPincer = ourDist + partnerDist <= pairDist + 4; // Both close, player in middle

		if (isPincer) {
			// Pincer — both go straight for the player
			target = playerPos;
		} else {
			// Flanking — offset target by flock direction
			const offset = DIRECTION_VECTORS[data.flockOffset];
			const offsetDist = 3; // Offset by 3 cells
			const fx = Math.max(0, Math.min(grid.width - 1, playerPos.x + offset.x * offsetDist));
			const fy = Math.max(0, Math.min(grid.height - 1, playerPos.y + offset.y * offsetDist));
			target = { x: fx, y: fy };
		}
	} else {
		// No partner — direct pursuit
		target = playerPos;
	}

	// Pick direction that gets closest to target
	let bestDir = validDirs[0];
	let bestDist = Infinity;

	for (const dir of validDirs) {
		const v = DIRECTION_VECTORS[dir];
		const nx = tracer.pos.x + v.x;
		const ny = tracer.pos.y + v.y;
		const dist = manhattanDistance({ x: nx, y: ny }, target);
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
 * Frightened behavior: flee from player.
 * Picks the direction that maximizes distance to player,
 * but avoids dead ends when possible.
 */
export function updateFrightened(
	tracer: TracerState,
	grid: MazeGrid,
	playerPos: Coord,
): Direction | null {
	const validDirs = getValidDirections(grid, tracer.pos);
	if (validDirs.length === 0) return null;

	let bestDir = validDirs[0];
	let bestScore = -Infinity;

	for (const dir of validDirs) {
		const v = DIRECTION_VECTORS[dir];
		const nx = tracer.pos.x + v.x;
		const ny = tracer.pos.y + v.y;
		const dist = manhattanDistance({ x: nx, y: ny }, playerPos);

		// Bonus for positions with more exits (avoid dead ends)
		const nextDirs = getValidDirections(grid, { x: nx, y: ny });
		const exitBonus = nextDirs.length * 0.5;

		const score = dist + exitBonus;
		if (score > bestScore) {
			bestScore = score;
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
	rng: () => number,
): Direction | null {
	const dirs = getValidDirectionsExcept(grid, pos, OPPOSITE_DIRECTION[currentDir]);

	if (dirs.length > 0) {
		const idx = Math.floor(rng() * dirs.length);
		return dirs[idx];
	}

	const reverse = OPPOSITE_DIRECTION[currentDir];
	return canMove(grid, pos, reverse) ? reverse : null;
}

/**
 * Pick the best direction to move toward a target position.
 * Greedy — at each step, pick valid direction minimizing Manhattan distance.
 * Prefers not reversing unless it's the only option.
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
 * Validates each waypoint is a reachable corridor cell.
 * Scales patrol radius to grid dimensions.
 */
export function generatePatrolWaypoints(
	grid: MazeGrid,
	spawnPos: Coord,
	rng: () => number,
): Coord[] {
	const count = 4 + Math.floor(rng() * 5); // 4-8 waypoints
	const radius = Math.max(3, Math.floor(Math.min(grid.width, grid.height) / 4));
	const waypoints: Coord[] = [];

	for (let i = 0; i < count; i++) {
		const angle = (i / count) * Math.PI * 2;
		let bestCandidate: Coord | null = null;
		let bestDist = Infinity;

		// Try the ideal position and nearby cells to find a valid one
		for (let attempt = 0; attempt < 5; attempt++) {
			const r = radius - attempt;
			if (r <= 0) break;

			const x = Math.round(spawnPos.x + Math.cos(angle) * r);
			const y = Math.round(spawnPos.y + Math.sin(angle) * r);
			const cx = Math.max(0, Math.min(grid.width - 1, x));
			const cy = Math.max(0, Math.min(grid.height - 1, y));

			// Validate: cell must have at least one open passage
			const cellDirs = getValidDirections(grid, { x: cx, y: cy });
			if (cellDirs.length > 0) {
				const dist = Math.abs(cx - x) + Math.abs(cy - y);
				if (dist < bestDist) {
					bestDist = dist;
					bestCandidate = { x: cx, y: cy };
				}
			}
		}

		if (bestCandidate) {
			// Avoid duplicate consecutive waypoints
			const last = waypoints[waypoints.length - 1];
			if (!last || last.x !== bestCandidate.x || last.y !== bestCandidate.y) {
				waypoints.push(bestCandidate);
			}
		}
	}

	// Must have at least 2 waypoints for a circuit
	if (waypoints.length < 2) {
		// Fallback: create simple N-S-E-W cross from spawn
		const fallbackDist = Math.min(3, Math.floor(radius / 2));
		return [
			{ x: Math.min(grid.width - 1, spawnPos.x + fallbackDist), y: spawnPos.y },
			{ x: spawnPos.x, y: Math.min(grid.height - 1, spawnPos.y + fallbackDist) },
			{ x: Math.max(0, spawnPos.x - fallbackDist), y: spawnPos.y },
			{ x: spawnPos.x, y: Math.max(0, spawnPos.y - fallbackDist) },
		];
	}

	return waypoints;
}
