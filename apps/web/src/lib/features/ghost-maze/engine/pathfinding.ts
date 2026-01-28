/**
 * A* Pathfinding
 * ===============
 * Grid-based A* for Hunter tracer AI.
 * On a 37x23 grid (max 851 cells) this is trivially fast (<1ms).
 */

import type { Coord, Direction, MazeGrid } from '../types';
import { DIRECTIONS, DIRECTION_VECTORS } from '../types';
import { hasWall, isInBounds } from './maze-generator';
import { manhattanDistance } from './maze-generator';

interface PathNode {
	x: number;
	y: number;
	g: number; // Cost from start
	h: number; // Heuristic to goal
	f: number; // g + h
	parent: PathNode | null;
}

/**
 * Find the shortest path from `from` to `to` using A* with Manhattan distance heuristic.
 * Returns array of coordinates from start to goal (inclusive), or null if no path exists.
 */
export function findPath(grid: MazeGrid, from: Coord, to: Coord): Coord[] | null {
	if (from.x === to.x && from.y === to.y) return [from];

	const width = grid.width;
	const height = grid.height;

	// Open set as a simple sorted array (fine for small grids)
	const open: PathNode[] = [];
	const closedSet = new Set<number>(); // y * width + x

	const startNode: PathNode = {
		x: from.x,
		y: from.y,
		g: 0,
		h: manhattanDistance(from, to),
		f: manhattanDistance(from, to),
		parent: null,
	};
	open.push(startNode);

	// Best g-score per cell
	const gScore = new Map<number, number>();
	gScore.set(from.y * width + from.x, 0);

	while (open.length > 0) {
		// Find node with lowest f-score
		let bestIdx = 0;
		for (let i = 1; i < open.length; i++) {
			if (open[i].f < open[bestIdx].f) bestIdx = i;
		}
		const current = open[bestIdx];
		open.splice(bestIdx, 1);

		// Reached goal
		if (current.x === to.x && current.y === to.y) {
			return reconstructPath(current);
		}

		const key = current.y * width + current.x;
		if (closedSet.has(key)) continue;
		closedSet.add(key);

		// Explore neighbors
		for (const dir of DIRECTIONS) {
			// Check wall
			if (hasWall(grid, current.x, current.y, dir)) continue;

			const v = DIRECTION_VECTORS[dir];
			const nx = current.x + v.x;
			const ny = current.y + v.y;

			if (!isInBounds(nx, ny, width, height)) continue;

			const nKey = ny * width + nx;
			if (closedSet.has(nKey)) continue;

			const tentativeG = current.g + 1;
			const existingG = gScore.get(nKey);

			if (existingG !== undefined && tentativeG >= existingG) continue;

			gScore.set(nKey, tentativeG);

			const h = manhattanDistance({ x: nx, y: ny }, to);
			const neighbor: PathNode = {
				x: nx,
				y: ny,
				g: tentativeG,
				h,
				f: tentativeG + h,
				parent: current,
			};
			open.push(neighbor);
		}
	}

	return null; // No path found
}

function reconstructPath(node: PathNode): Coord[] {
	const path: Coord[] = [];
	let current: PathNode | null = node;
	while (current) {
		path.unshift({ x: current.x, y: current.y });
		current = current.parent;
	}
	return path;
}

/**
 * Get the next direction to move along a path.
 * Returns the direction from path[0] to path[1], or null if path is too short.
 */
export function getPathDirection(path: Coord[]): Direction | null {
	if (path.length < 2) return null;

	const dx = path[1].x - path[0].x;
	const dy = path[1].y - path[0].y;

	if (dx === 1) return 'right';
	if (dx === -1) return 'left';
	if (dy === 1) return 'down';
	if (dy === -1) return 'up';

	return null;
}
