/**
 * Collision Detection
 * ====================
 * Grid-based collision for maze entities.
 * All checks are O(1) — no physics engine needed.
 */

import type { Coord, Direction, MazeGrid } from '../types';
import { DIRECTION_VECTORS } from '../types';
import { hasWall, isInBounds } from './maze-generator';

/**
 * Check if an entity can move in a given direction from a position.
 * Returns false if there's a wall blocking movement.
 */
export function canMove(grid: MazeGrid, pos: Coord, dir: Direction): boolean {
	// Check wall on current cell in the given direction
	if (hasWall(grid, pos.x, pos.y, dir)) return false;

	// Check destination is in bounds
	const v = DIRECTION_VECTORS[dir];
	const nx = pos.x + v.x;
	const ny = pos.y + v.y;

	return isInBounds(nx, ny, grid.width, grid.height);
}

/**
 * Get the destination coordinate if movement is valid, null otherwise.
 */
export function tryMove(grid: MazeGrid, pos: Coord, dir: Direction): Coord | null {
	if (!canMove(grid, pos, dir)) return null;
	const v = DIRECTION_VECTORS[dir];
	return { x: pos.x + v.x, y: pos.y + v.y };
}

/**
 * Check if two entities occupy the same cell.
 */
export function overlaps(a: Coord, b: Coord): boolean {
	return a.x === b.x && a.y === b.y;
}

/**
 * Get all valid movement directions from a position.
 */
export function getValidDirections(grid: MazeGrid, pos: Coord): Direction[] {
	const dirs: Direction[] = [];
	if (canMove(grid, pos, 'up')) dirs.push('up');
	if (canMove(grid, pos, 'down')) dirs.push('down');
	if (canMove(grid, pos, 'left')) dirs.push('left');
	if (canMove(grid, pos, 'right')) dirs.push('right');
	return dirs;
}

/**
 * Get valid directions excluding a specific direction (e.g., don't reverse).
 */
export function getValidDirectionsExcept(
	grid: MazeGrid,
	pos: Coord,
	exclude: Direction,
): Direction[] {
	return getValidDirections(grid, pos).filter((d) => d !== exclude);
}

/**
 * Check if there's line-of-sight between two positions (no walls between them).
 * Only works on same row or column (cardinal line-of-sight).
 */
export function hasLineOfSight(grid: MazeGrid, from: Coord, to: Coord): boolean {
	if (from.x !== to.x && from.y !== to.y) return false; // Not on same axis

	if (from.x === to.x) {
		// Vertical line of sight
		const minY = Math.min(from.y, to.y);
		const maxY = Math.max(from.y, to.y);
		for (let y = minY; y < maxY; y++) {
			if (hasWall(grid, from.x, y, 'down')) return false;
		}
		return true;
	}

	// Horizontal line of sight
	const minX = Math.min(from.x, to.x);
	const maxX = Math.max(from.x, to.x);

	for (let x = minX; x < maxX; x++) {
		if (hasWall(grid, x, from.y, 'right')) return false;
	}
	return true;
}
