import { describe, it, expect } from 'vitest';
import { findPath, getPathDirection } from './pathfinding';
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

describe('findPath', () => {
	it('returns single-element path for same start and goal', () => {
		const maze = generateMaze(CONFIG);
		const path = findPath(maze, { x: 5, y: 5 }, { x: 5, y: 5 });
		expect(path).toEqual([{ x: 5, y: 5 }]);
	});

	it('finds a path between player spawn and tracer spawn', () => {
		const maze = generateMaze(CONFIG);
		const path = findPath(maze, maze.playerSpawn, maze.tracerSpawns[0]);
		expect(path).not.toBeNull();
		expect(path!.length).toBeGreaterThan(1);
		// Path should start at player spawn
		expect(path![0]).toEqual(maze.playerSpawn);
		// Path should end at tracer spawn
		expect(path![path!.length - 1]).toEqual(maze.tracerSpawns[0]);
	});

	it('path steps are adjacent cells', () => {
		const maze = generateMaze(CONFIG);
		const path = findPath(maze, maze.playerSpawn, maze.tracerSpawns[0]);
		expect(path).not.toBeNull();

		for (let i = 1; i < path!.length; i++) {
			const dx = Math.abs(path![i].x - path![i - 1].x);
			const dy = Math.abs(path![i].y - path![i - 1].y);
			// Each step is exactly 1 cell in one cardinal direction
			expect(dx + dy).toBe(1);
		}
	});

	it('finds paths on large mazes efficiently', () => {
		const maze = generateMaze({
			width: 37,
			height: 23,
			seed: 99,
			loopFactor: 0.25,
			tracerCount: 7,
			dataPackets: 200,
		});

		const start = performance.now();
		const path = findPath(maze, maze.playerSpawn, maze.tracerSpawns[0]);
		const elapsed = performance.now() - start;

		expect(path).not.toBeNull();
		expect(elapsed).toBeLessThan(50); // Should be <1ms, generous 50ms limit
	});
});

describe('getPathDirection', () => {
	it('returns null for single-element path', () => {
		expect(getPathDirection([{ x: 5, y: 5 }])).toBeNull();
	});

	it('returns null for empty path', () => {
		expect(getPathDirection([])).toBeNull();
	});

	it('returns correct direction for right movement', () => {
		expect(getPathDirection([{ x: 5, y: 5 }, { x: 6, y: 5 }])).toBe('right');
	});

	it('returns correct direction for left movement', () => {
		expect(getPathDirection([{ x: 5, y: 5 }, { x: 4, y: 5 }])).toBe('left');
	});

	it('returns correct direction for down movement', () => {
		expect(getPathDirection([{ x: 5, y: 5 }, { x: 5, y: 6 }])).toBe('down');
	});

	it('returns correct direction for up movement', () => {
		expect(getPathDirection([{ x: 5, y: 5 }, { x: 5, y: 4 }])).toBe('up');
	});
});
