/**
 * Mock Position Generator
 * ========================
 * Generates realistic fake position data for development
 */

import type { Position, Level } from '../../../types';
import { LEVEL_CONFIG } from '../../../types';

// ════════════════════════════════════════════════════════════════
// GENERATOR
// ════════════════════════════════════════════════════════════════

/** Generate a mock position for a user */
export function generateMockPosition(address: `0x${string}`): Position {
	const level: Level = 'DARKNET';
	const now = Date.now();
	const config = LEVEL_CONFIG[level];

	// Calculate next scan time
	const scanIntervalMs = config.scanIntervalHours * 60 * 60 * 1000;
	const nextScanTimestamp = now + Math.random() * scanIntervalMs;

	return {
		id: crypto.randomUUID(),
		address,
		level,
		stakedAmount: 500n * 10n ** 18n,
		entryTimestamp: now - 2 * 60 * 60 * 1000, // 2 hours ago
		earnedYield: 47n * 10n ** 18n,
		ghostStreak: 7,
		nextScanTimestamp
	};
}

/** Update position with yield accumulation */
export function updatePositionYield(position: Position): Position {
	// Add small random yield
	const yieldIncrease = BigInt(Math.floor(Math.random() * 100)) * 10n ** 15n;
	
	return {
		...position,
		earnedYield: position.earnedYield + yieldIncrease
	};
}

/** Create a new position when jacking in */
export function createPosition(
	address: `0x${string}`,
	level: Level,
	amount: bigint
): Position {
	const now = Date.now();
	const config = LEVEL_CONFIG[level];
	
	// Calculate next scan time based on level
	let nextScanTimestamp: number;
	if (config.scanIntervalHours === Infinity) {
		nextScanTimestamp = now + 365 * 24 * 60 * 60 * 1000; // Far future for VAULT
	} else {
		const scanIntervalMs = config.scanIntervalHours * 60 * 60 * 1000;
		nextScanTimestamp = now + scanIntervalMs;
	}

	return {
		id: crypto.randomUUID(),
		address,
		level,
		stakedAmount: amount,
		entryTimestamp: now,
		earnedYield: 0n,
		ghostStreak: 0,
		nextScanTimestamp
	};
}
