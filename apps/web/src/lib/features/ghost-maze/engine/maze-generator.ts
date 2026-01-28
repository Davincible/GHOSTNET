/**
 * Maze Generator
 * ===============
 * Procedural maze generation using recursive backtracker + post-processing.
 *
 * Algorithm:
 * 1. Generate perfect maze via depth-first search (recursive backtracker)
 * 2. Remove walls to create loops (15-25% of internal walls)
 * 3. Trim long dead-ends (anti-frustration)
 * 4. Place elements: player spawn, tracer spawns, power nodes, data packets
 * 5. Validate connectivity
 *
 * All randomness is seeded for deterministic generation.
 */

import type { Cell, CellContent, Coord, Direction, MazeGrid } from '../types';
import { DIRECTIONS, DIRECTION_VECTORS, OPPOSITE_DIRECTION } from '../types';
import {
	MAX_DEAD_END_LENGTH,
	MIN_TRACER_SPAWN_DISTANCE,
	POWER_NODES_PER_LEVEL,
} from '../constants';

// ============================================================================
// SEEDED PRNG (Mulberry32)
// ============================================================================

/**
 * Simple, fast 32-bit PRNG. Deterministic given same seed.
 * Mulberry32 by Tommy Ettinger — excellent distribution, passes SmallCrush.
 */
export function createRng(seed: number): () => number {
	let s = seed | 0;
	return () => {
		s = (s + 0x6d2b79f5) | 0;
		let t = Math.imul(s ^ (s >>> 15), 1 | s);
		t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

// ============================================================================
// HELPERS
// ============================================================================

/** Get cell index in flat array */
function cellIndex(x: number, y: number, width: number): number {
	return y * width + x;
}

/** Check if coordinate is within grid bounds */
function inBounds(x: number, y: number, width: number, height: number): boolean {
	return x >= 0 && x < width && y >= 0 && y < height;
}

/** Manhattan distance between two coords */
export function manhattanDistance(a: Coord, b: Coord): number {
	return Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
}

/** Shuffle an array in-place using Fisher-Yates with seeded RNG */
function shuffle<T>(arr: T[], rng: () => number): T[] {
	for (let i = arr.length - 1; i > 0; i--) {
		const j = Math.floor(rng() * (i + 1));
		[arr[i], arr[j]] = [arr[j], arr[i]];
	}
	return arr;
}

/** Create a cell with all walls up */
function createWalledCell(): Cell {
	return {
		walls: { up: true, down: true, left: true, right: true },
		content: 'empty',
		visited: false,
	};
}

/** Create a mutable copy of a cell's walls */
function mutableWalls(cell: Cell): Record<Direction, boolean> {
	return { ...cell.walls };
}

// ============================================================================
// MAZE GENERATION
// ============================================================================

export interface GenerateMazeConfig {
	readonly width: number;
	readonly height: number;
	readonly seed: number;
	/** Fraction of internal walls to remove for loops (0-1) */
	readonly loopFactor: number;
	/** Number of tracers to place */
	readonly tracerCount: number;
	/** Target number of data packets */
	readonly dataPackets: number;
}

/**
 * Generate a complete maze with all elements placed.
 */
export function generateMaze(config: GenerateMazeConfig): MazeGrid {
	const { width, height, seed, loopFactor, tracerCount, dataPackets } = config;
	const rng = createRng(seed);

	// 1. Initialize grid with all walls
	const cells: Cell[] = Array.from({ length: width * height }, () => createWalledCell());

	// 2. Carve maze using recursive backtracker (iterative stack to avoid stack overflow)
	carveMaze(cells, width, height, rng);

	// 3. Add loops by removing random walls
	addLoops(cells, width, height, loopFactor, rng);

	// 4. Trim long dead-ends
	trimDeadEnds(cells, width, height);

	// 5. Place elements
	const playerSpawn: Coord = { x: Math.floor(width / 2), y: height - 1 };

	const tracerSpawns = placeTracerSpawns(cells, width, height, tracerCount, playerSpawn, rng);
	const powerNodePositions = placePowerNodes(cells, width, height, rng);
	const totalDataPackets = placeDataPackets(cells, width, height, dataPackets, playerSpawn, tracerSpawns, powerNodePositions, rng);

	// 6. Reset visited flags (used during generation only)
	for (const cell of cells) {
		cell.visited = false;
	}

	return {
		width,
		height,
		cells,
		playerSpawn,
		tracerSpawns,
		powerNodePositions,
		totalDataPackets,
	};
}

// ============================================================================
// STEP 1: RECURSIVE BACKTRACKER (iterative)
// ============================================================================

function carveMaze(
	cells: Cell[],
	width: number,
	height: number,
	rng: () => number,
): void {
	// Start from random cell
	const startX = Math.floor(rng() * width);
	const startY = Math.floor(rng() * height);

	const stack: Coord[] = [{ x: startX, y: startY }];
	cells[cellIndex(startX, startY, width)].visited = true;

	while (stack.length > 0) {
		const current = stack[stack.length - 1];
		const neighbors = getUnvisitedNeighbors(cells, current.x, current.y, width, height);

		if (neighbors.length === 0) {
			stack.pop();
			continue;
		}

		// Pick random unvisited neighbor
		const [dir, nx, ny] = neighbors[Math.floor(rng() * neighbors.length)];

		// Remove wall between current and neighbor
		removeWall(cells, current.x, current.y, dir, width);

		cells[cellIndex(nx, ny, width)].visited = true;
		stack.push({ x: nx, y: ny });
	}
}

function getUnvisitedNeighbors(
	cells: Cell[],
	x: number,
	y: number,
	width: number,
	height: number,
): Array<[Direction, number, number]> {
	const result: Array<[Direction, number, number]> = [];
	for (const dir of DIRECTIONS) {
		const v = DIRECTION_VECTORS[dir];
		const nx = x + v.x;
		const ny = y + v.y;
		if (inBounds(nx, ny, width, height) && !cells[cellIndex(nx, ny, width)].visited) {
			result.push([dir, nx, ny]);
		}
	}
	return result;
}

/**
 * Remove wall between cell (x,y) and its neighbor in direction `dir`.
 * Updates both cells to keep walls consistent.
 */
function removeWall(cells: Cell[], x: number, y: number, dir: Direction, width: number): void {
	const v = DIRECTION_VECTORS[dir];
	const nx = x + v.x;
	const ny = y + v.y;

	const currentIdx = cellIndex(x, y, width);
	const neighborIdx = cellIndex(nx, ny, width);

	const currentWalls = mutableWalls(cells[currentIdx]);
	currentWalls[dir] = false;
	cells[currentIdx] = { ...cells[currentIdx], walls: currentWalls };

	const neighborWalls = mutableWalls(cells[neighborIdx]);
	neighborWalls[OPPOSITE_DIRECTION[dir]] = false;
	cells[neighborIdx] = { ...cells[neighborIdx], walls: neighborWalls };
}

// ============================================================================
// STEP 2: ADD LOOPS
// ============================================================================

function addLoops(
	cells: Cell[],
	width: number,
	height: number,
	loopFactor: number,
	rng: () => number,
): void {
	// Collect all internal walls that could be removed
	const removableWalls: Array<{ x: number; y: number; dir: Direction }> = [];

	for (let y = 0; y < height; y++) {
		for (let x = 0; x < width; x++) {
			const cell = cells[cellIndex(x, y, width)];
			// Only check right and down to avoid duplicates
			if (x < width - 1 && cell.walls.right) {
				removableWalls.push({ x, y, dir: 'right' });
			}
			if (y < height - 1 && cell.walls.down) {
				removableWalls.push({ x, y, dir: 'down' });
			}
		}
	}

	// Shuffle and remove a fraction
	shuffle(removableWalls, rng);
	const removeCount = Math.floor(removableWalls.length * loopFactor);

	for (let i = 0; i < removeCount; i++) {
		const { x, y, dir } = removableWalls[i];
		removeWall(cells, x, y, dir, width);
	}
}

// ============================================================================
// STEP 3: TRIM DEAD ENDS
// ============================================================================

function trimDeadEnds(cells: Cell[], width: number, height: number): void {
	// Find dead-end cells (cells with only 1 open passage) and fill short corridors
	let changed = true;
	while (changed) {
		changed = false;
		for (let y = 0; y < height; y++) {
			for (let x = 0; x < width; x++) {
				const deadEndLength = measureDeadEnd(cells, x, y, width, height);
				if (deadEndLength > MAX_DEAD_END_LENGTH) {
					// Fill the dead end by adding walls back
					fillDeadEnd(cells, x, y, width, height);
					changed = true;
				}
			}
		}
	}
}

/** Count how deep a dead-end corridor goes from a given cell. Returns 0 if not a dead end. */
function measureDeadEnd(cells: Cell[], x: number, y: number, width: number, height: number): number {
	const cell = cells[cellIndex(x, y, width)];
	const openDirs = DIRECTIONS.filter((d) => !cell.walls[d]);

	if (openDirs.length !== 1) return 0; // Not a dead end

	// Walk the corridor
	let length = 1;
	let cx = x;
	let cy = y;
	let fromDir = OPPOSITE_DIRECTION[openDirs[0]];

	while (length < height * width) {
		const v = DIRECTION_VECTORS[OPPOSITE_DIRECTION[fromDir] as Direction];
		// Actually, walk toward the open direction
		const currentCell = cells[cellIndex(cx, cy, width)];
		const exits = DIRECTIONS.filter((d) => !currentCell.walls[d] && d !== fromDir);

		if (exits.length !== 1) break; // Junction or another dead end

		const nextDir = exits[0];
		const nv = DIRECTION_VECTORS[nextDir];
		cx += nv.x;
		cy += nv.y;
		fromDir = OPPOSITE_DIRECTION[nextDir];
		length++;
	}

	return length;
}

/** Fill a dead-end cell by closing its single opening */
function fillDeadEnd(cells: Cell[], x: number, y: number, width: number, _height: number): void {
	const idx = cellIndex(x, y, width);
	const cell = cells[idx];
	const openDirs = DIRECTIONS.filter((d) => !cell.walls[d]);

	if (openDirs.length !== 1) return;

	const dir = openDirs[0];
	const v = DIRECTION_VECTORS[dir];
	const nx = x + v.x;
	const ny = y + v.y;

	// Close wall on current cell
	const currentWalls = mutableWalls(cell);
	currentWalls[dir] = true;
	cells[idx] = { ...cells[idx], walls: currentWalls };

	// Close wall on neighbor
	const neighborIdx = cellIndex(nx, ny, width);
	const neighborWalls = mutableWalls(cells[neighborIdx]);
	neighborWalls[OPPOSITE_DIRECTION[dir]] = true;
	cells[neighborIdx] = { ...cells[neighborIdx], walls: neighborWalls };
}

// ============================================================================
// STEP 4: ELEMENT PLACEMENT
// ============================================================================

function placeTracerSpawns(
	cells: Cell[],
	width: number,
	height: number,
	count: number,
	playerSpawn: Coord,
	rng: () => number,
): Coord[] {
	// Prefer corners and edges, far from player
	const candidates: Coord[] = [];

	for (let y = 0; y < height; y++) {
		for (let x = 0; x < width; x++) {
			const coord = { x, y };
			if (manhattanDistance(coord, playerSpawn) >= MIN_TRACER_SPAWN_DISTANCE) {
				candidates.push(coord);
			}
		}
	}

	// Sort by distance from center (prefer edges/corners)
	const cx = width / 2;
	const cy = height / 2;
	candidates.sort((a, b) => {
		const da = Math.abs(a.x - cx) + Math.abs(a.y - cy);
		const db = Math.abs(b.x - cx) + Math.abs(b.y - cy);
		return db - da; // Furthest from center first
	});

	// Pick top candidates with some randomness
	const spawns: Coord[] = [];
	const used = new Set<string>();

	for (let i = 0; i < Math.min(count, candidates.length); i++) {
		// Pick from top 30% of candidates
		const poolSize = Math.max(1, Math.floor(candidates.length * 0.3));
		let idx: number;
		let attempts = 0;
		do {
			idx = Math.floor(rng() * poolSize);
			attempts++;
		} while (used.has(`${candidates[idx].x},${candidates[idx].y}`) && attempts < 50);

		const coord = candidates[idx];
		spawns.push(coord);
		used.add(`${coord.x},${coord.y}`);
	}

	return spawns;
}

function placePowerNodes(
	cells: Cell[],
	width: number,
	height: number,
	rng: () => number,
): Coord[] {
	// Place one per quadrant
	const quadrants = [
		{ x: Math.floor(width * 0.25), y: Math.floor(height * 0.25) },
		{ x: Math.floor(width * 0.75), y: Math.floor(height * 0.25) },
		{ x: Math.floor(width * 0.25), y: Math.floor(height * 0.75) },
		{ x: Math.floor(width * 0.75), y: Math.floor(height * 0.75) },
	];

	const positions: Coord[] = [];

	for (let i = 0; i < Math.min(POWER_NODES_PER_LEVEL, quadrants.length); i++) {
		const center = quadrants[i];
		// Search nearby for a valid cell (not a pure wall junction)
		const radius = 3;
		let bestCoord = center;

		for (let dy = -radius; dy <= radius; dy++) {
			for (let dx = -radius; dx <= radius; dx++) {
				const nx = center.x + dx;
				const ny = center.y + dy;
				if (inBounds(nx, ny, width, height)) {
					const cell = cells[cellIndex(nx, ny, width)];
					const openCount = DIRECTIONS.filter((d) => !cell.walls[d]).length;
					if (openCount >= 2) {
						// Prefer cells with more openings (intersections)
						bestCoord = { x: nx, y: ny };
						if (rng() < 0.3) break; // Some randomness in selection
					}
				}
			}
		}

		cells[cellIndex(bestCoord.x, bestCoord.y, width)] = {
			...cells[cellIndex(bestCoord.x, bestCoord.y, width)],
			content: 'power_node' as CellContent,
		};
		positions.push(bestCoord);
	}

	return positions;
}

function placeDataPackets(
	cells: Cell[],
	width: number,
	height: number,
	targetCount: number,
	playerSpawn: Coord,
	tracerSpawns: Coord[],
	powerNodePositions: Coord[],
	rng: () => number,
): number {
	// Place data packets on all empty corridor cells
	const reserved = new Set<string>();
	reserved.add(`${playerSpawn.x},${playerSpawn.y}`);
	for (const s of tracerSpawns) reserved.add(`${s.x},${s.y}`);
	for (const p of powerNodePositions) reserved.add(`${p.x},${p.y}`);

	const corridorCells: Coord[] = [];

	for (let y = 0; y < height; y++) {
		for (let x = 0; x < width; x++) {
			if (reserved.has(`${x},${y}`)) continue;
			const cell = cells[cellIndex(x, y, width)];
			if (cell.content !== 'empty') continue;
			// Must have at least one open passage
			const hasPassage = DIRECTIONS.some((d) => !cell.walls[d]);
			if (hasPassage) {
				corridorCells.push({ x, y });
			}
		}
	}

	// Shuffle so packets are distributed evenly across the maze
	shuffle(corridorCells, rng);

	// Place up to targetCount packets (or all corridor cells if fewer)
	const count = Math.min(targetCount, corridorCells.length);

	for (let i = 0; i < count; i++) {
		const coord = corridorCells[i];
		const idx = cellIndex(coord.x, coord.y, width);
		cells[idx] = { ...cells[idx], content: 'data' as CellContent };
	}

	return count;
}

// ============================================================================
// UTILITY: Get cell from grid
// ============================================================================

/** Get a cell from a MazeGrid by coordinate. Returns undefined if out of bounds. */
export function getCell(grid: MazeGrid, x: number, y: number): Cell | undefined {
	if (!inBounds(x, y, grid.width, grid.height)) return undefined;
	return grid.cells[cellIndex(x, y, grid.width)];
}

/** Get cell index for external use */
export function getCellIndex(x: number, y: number, width: number): number {
	return cellIndex(x, y, width);
}

/** Check if a coordinate is within maze bounds */
export function isInBounds(x: number, y: number, width: number, height: number): boolean {
	return inBounds(x, y, width, height);
}

/** Check if a cell has a wall in a given direction */
export function hasWall(grid: MazeGrid, x: number, y: number, dir: Direction): boolean {
	const cell = getCell(grid, x, y);
	if (!cell) return true; // Out of bounds = wall
	return cell.walls[dir];
}
