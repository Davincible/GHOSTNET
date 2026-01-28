import { describe, it, expect } from 'vitest';
import { canMove, tryMove, overlaps, getValidDirections, hasLineOfSight } from './collision';
import { generateMaze } from './maze-generator';
import type { GenerateMazeConfig } from './maze-generator';

const CONFIG: GenerateMazeConfig = {
	width: 21,
	height: 15,
	seed: 42,
	loopFactor: 0.2,
	tracerCount: 2,
	dataPackets: 60,
};

describe('canMove', () => {
	it('respects walls', () => {
		const maze = generateMaze(CONFIG);
		const spawn = maze.playerSpawn;

		// At least one direction should be valid from spawn
		const validCount = ['up', 'down', 'left', 'right'].filter((d) =>
			canMove(maze, spawn, d as any),
		).length;
		expect(validCount).toBeGreaterThan(0);
	});

	it('blocks movement out of bounds', () => {
		const maze = generateMaze(CONFIG);
		// Top-left corner — up and left should always be blocked (boundary walls)
		expect(canMove(maze, { x: 0, y: 0 }, 'up')).toBe(false);
		expect(canMove(maze, { x: 0, y: 0 }, 'left')).toBe(false);
	});
});

describe('tryMove', () => {
	it('returns new position when valid', () => {
		const maze = generateMaze(CONFIG);
		const spawn = maze.playerSpawn;

		// Find a valid direction
		const dirs = getValidDirections(maze, spawn);
		if (dirs.length > 0) {
			const result = tryMove(maze, spawn, dirs[0]);
			expect(result).not.toBeNull();
			expect(result).not.toEqual(spawn);
		}
	});

	it('returns null when blocked', () => {
		const maze = generateMaze(CONFIG);
		// Out of bounds move
		const result = tryMove(maze, { x: 0, y: 0 }, 'up');
		expect(result).toBeNull();
	});
});

describe('overlaps', () => {
	it('returns true for same position', () => {
		expect(overlaps({ x: 5, y: 5 }, { x: 5, y: 5 })).toBe(true);
	});

	it('returns false for different positions', () => {
		expect(overlaps({ x: 5, y: 5 }, { x: 5, y: 6 })).toBe(false);
	});
});

describe('getValidDirections', () => {
	it('returns at least one direction for non-isolated cells', () => {
		const maze = generateMaze(CONFIG);
		const dirs = getValidDirections(maze, maze.playerSpawn);
		expect(dirs.length).toBeGreaterThan(0);
	});

	it('returns only valid directions', () => {
		const maze = generateMaze(CONFIG);
		const dirs = getValidDirections(maze, maze.playerSpawn);
		for (const dir of dirs) {
			expect(canMove(maze, maze.playerSpawn, dir)).toBe(true);
		}
	});
});

describe('hasLineOfSight', () => {
	it('returns true for same position', () => {
		const maze = generateMaze(CONFIG);
		expect(hasLineOfSight(maze, { x: 5, y: 5 }, { x: 5, y: 5 })).toBe(true);
	});

	it('returns false for diagonal positions', () => {
		const maze = generateMaze(CONFIG);
		expect(hasLineOfSight(maze, { x: 0, y: 0 }, { x: 1, y: 1 })).toBe(false);
	});
});
