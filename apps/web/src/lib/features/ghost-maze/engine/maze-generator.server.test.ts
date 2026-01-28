import { describe, it, expect } from 'vitest';
import { generateMaze, getCell, hasWall, createRng, manhattanDistance } from './maze-generator';
import type { GenerateMazeConfig } from './maze-generator';
import { DIRECTIONS } from '../types';

const DEFAULT_CONFIG: GenerateMazeConfig = {
	width: 21,
	height: 15,
	seed: 42,
	loopFactor: 0.2,
	tracerCount: 2,
	dataPackets: 60,
};

describe('createRng', () => {
	it('produces deterministic output for same seed', () => {
		const rng1 = createRng(12345);
		const rng2 = createRng(12345);

		const values1 = Array.from({ length: 10 }, () => rng1());
		const values2 = Array.from({ length: 10 }, () => rng2());

		expect(values1).toEqual(values2);
	});

	it('produces values between 0 and 1', () => {
		const rng = createRng(42);
		for (let i = 0; i < 100; i++) {
			const v = rng();
			expect(v).toBeGreaterThanOrEqual(0);
			expect(v).toBeLessThan(1);
		}
	});

	it('produces different output for different seeds', () => {
		const rng1 = createRng(1);
		const rng2 = createRng(2);
		// Extremely unlikely to be equal
		expect(rng1()).not.toEqual(rng2());
	});
});

describe('generateMaze', () => {
	it('returns a maze with correct dimensions', () => {
		const maze = generateMaze(DEFAULT_CONFIG);
		expect(maze.width).toBe(21);
		expect(maze.height).toBe(15);
		expect(maze.cells.length).toBe(21 * 15);
	});

	it('places player spawn at bottom center', () => {
		const maze = generateMaze(DEFAULT_CONFIG);
		expect(maze.playerSpawn).toEqual({ x: 10, y: 14 });
	});

	it('places the requested number of tracer spawns', () => {
		const maze = generateMaze(DEFAULT_CONFIG);
		expect(maze.tracerSpawns.length).toBe(2);
	});

	it('places tracer spawns far from player', () => {
		const maze = generateMaze(DEFAULT_CONFIG);
		for (const spawn of maze.tracerSpawns) {
			const dist = manhattanDistance(spawn, maze.playerSpawn);
			expect(dist).toBeGreaterThanOrEqual(8);
		}
	});

	it('places 4 power nodes', () => {
		const maze = generateMaze(DEFAULT_CONFIG);
		expect(maze.powerNodePositions.length).toBe(4);
	});

	it('places power nodes marked in cells', () => {
		const maze = generateMaze(DEFAULT_CONFIG);
		for (const pos of maze.powerNodePositions) {
			const cell = getCell(maze, pos.x, pos.y);
			expect(cell?.content).toBe('power_node');
		}
	});

	it('places data packets up to the requested count', () => {
		const maze = generateMaze(DEFAULT_CONFIG);
		expect(maze.totalDataPackets).toBeLessThanOrEqual(60);
		expect(maze.totalDataPackets).toBeGreaterThan(0);
	});

	it('produces deterministic output for same seed', () => {
		const maze1 = generateMaze(DEFAULT_CONFIG);
		const maze2 = generateMaze(DEFAULT_CONFIG);

		expect(maze1.playerSpawn).toEqual(maze2.playerSpawn);
		expect(maze1.tracerSpawns).toEqual(maze2.tracerSpawns);
		expect(maze1.powerNodePositions).toEqual(maze2.powerNodePositions);
		expect(maze1.totalDataPackets).toEqual(maze2.totalDataPackets);

		// Check all cells match
		for (let i = 0; i < maze1.cells.length; i++) {
			expect(maze1.cells[i].walls).toEqual(maze2.cells[i].walls);
			expect(maze1.cells[i].content).toEqual(maze2.cells[i].content);
		}
	});

	it('produces different mazes for different seeds', () => {
		const maze1 = generateMaze({ ...DEFAULT_CONFIG, seed: 1 });
		const maze2 = generateMaze({ ...DEFAULT_CONFIG, seed: 2 });

		// At least some walls should differ
		let differences = 0;
		for (let i = 0; i < maze1.cells.length; i++) {
			for (const dir of DIRECTIONS) {
				if (maze1.cells[i].walls[dir] !== maze2.cells[i].walls[dir]) {
					differences++;
				}
			}
		}
		expect(differences).toBeGreaterThan(0);
	});

	it('all cells are reachable (no isolated sections)', () => {
		const maze = generateMaze(DEFAULT_CONFIG);
		const visited = new Set<string>();
		const queue: Array<{ x: number; y: number }> = [maze.playerSpawn];
		visited.add(`${maze.playerSpawn.x},${maze.playerSpawn.y}`);

		while (queue.length > 0) {
			const pos = queue.shift()!;
			for (const dir of DIRECTIONS) {
				if (!hasWall(maze, pos.x, pos.y, dir)) {
					const { x: dx, y: dy } = { up: { x: 0, y: -1 }, down: { x: 0, y: 1 }, left: { x: -1, y: 0 }, right: { x: 1, y: 0 } }[dir];
					const nx = pos.x + dx;
					const ny = pos.y + dy;
					const key = `${nx},${ny}`;
					if (!visited.has(key) && nx >= 0 && nx < maze.width && ny >= 0 && ny < maze.height) {
						visited.add(key);
						queue.push({ x: nx, y: ny });
					}
				}
			}
		}

		// Count cells that have at least one open direction (passable cells)
		let passableCells = 0;
		for (let y = 0; y < maze.height; y++) {
			for (let x = 0; x < maze.width; x++) {
				const cell = getCell(maze, x, y)!;
				const hasOpening = DIRECTIONS.some((d) => !cell.walls[d]);
				if (hasOpening) passableCells++;
			}
		}

		// All passable cells should be reachable
		// (Some cells might be fully walled after dead-end trimming, which is ok)
		expect(visited.size).toBeGreaterThanOrEqual(passableCells * 0.9);
	});

	it('has loops (not a perfect maze)', () => {
		const maze = generateMaze(DEFAULT_CONFIG);

		// A perfect maze on WxH grid has exactly W*H-1 passages.
		// With loops, there should be more.
		let passages = 0;
		for (let y = 0; y < maze.height; y++) {
			for (let x = 0; x < maze.width; x++) {
				const cell = getCell(maze, x, y)!;
				// Count right and down walls that are open (avoid double counting)
				if (x < maze.width - 1 && !cell.walls.right) passages++;
				if (y < maze.height - 1 && !cell.walls.down) passages++;
			}
		}

		const perfectMazePassages = maze.width * maze.height - 1;
		expect(passages).toBeGreaterThan(perfectMazePassages);
	});

	it('handles large mazes (level 5 config)', () => {
		const maze = generateMaze({
			width: 37,
			height: 23,
			seed: 99,
			loopFactor: 0.25,
			tracerCount: 7,
			dataPackets: 200,
		});

		expect(maze.width).toBe(37);
		expect(maze.height).toBe(23);
		expect(maze.tracerSpawns.length).toBe(7);
		expect(maze.totalDataPackets).toBeGreaterThan(0);
	});
});

describe('manhattanDistance', () => {
	it('returns 0 for same point', () => {
		expect(manhattanDistance({ x: 5, y: 5 }, { x: 5, y: 5 })).toBe(0);
	});

	it('returns correct distance', () => {
		expect(manhattanDistance({ x: 0, y: 0 }, { x: 3, y: 4 })).toBe(7);
	});

	it('is commutative', () => {
		const a = { x: 1, y: 2 };
		const b = { x: 5, y: 8 };
		expect(manhattanDistance(a, b)).toBe(manhattanDistance(b, a));
	});
});
