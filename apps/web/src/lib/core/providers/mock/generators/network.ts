/**
 * Mock Network State Generator
 * =============================
 * Generates realistic fake network state for development
 */

import type { NetworkState, Level } from '../../../types';
import { LEVELS, LEVEL_CONFIG } from '../../../types';

// ════════════════════════════════════════════════════════════════
// GENERATOR
// ════════════════════════════════════════════════════════════════

/** Generate initial mock network state */
export function generateMockNetworkState(): NetworkState {
	const now = Date.now();

	// Generate trace scan timestamps for each level
	const traceScanTimestamps: Record<Level, number> = {} as Record<Level, number>;

	for (const level of LEVELS) {
		const config = LEVEL_CONFIG[level];
		if (config.scanIntervalHours === Infinity) {
			// VAULT never has scans
			traceScanTimestamps[level] = now + 365 * 24 * 60 * 60 * 1000; // Far future
		} else {
			// Random time within the next interval
			const intervalMs = config.scanIntervalHours * 60 * 60 * 1000;
			traceScanTimestamps[level] = now + Math.random() * intervalMs;
		}
	}

	return {
		tvl: 4847291n * 10n ** 18n,
		tvlCapacity: 5500000n * 10n ** 18n,
		operatorsOnline: 1247,
		operatorsAth: 2150,
		systemResetTimestamp: now + 4 * 60 * 60 * 1000 + 32 * 60 * 1000, // 4:32 from now
		traceScanTimestamps,
		burnRatePerHour: 847n * 10n ** 18n,
		hourlyStats: {
			jackedIn: 127400n * 10n ** 18n,
			extracted: 89200n * 10n ** 18n,
			traced: 34100n * 10n ** 18n,
		},
	};
}

/** Update network state with small random changes */
export function updateNetworkState(current: NetworkState): NetworkState {
	const operatorChange = Math.floor(Math.random() * 10) - 5;
	const tvlChange = BigInt(Math.floor(Math.random() * 10000 - 5000)) * 10n ** 18n;

	return {
		...current,
		operatorsOnline: Math.max(100, current.operatorsOnline + operatorChange),
		tvl: current.tvl + tvlChange,
		hourlyStats: {
			jackedIn:
				current.hourlyStats.jackedIn + BigInt(Math.floor(Math.random() * 1000)) * 10n ** 18n,
			extracted:
				current.hourlyStats.extracted + BigInt(Math.floor(Math.random() * 500)) * 10n ** 18n,
			traced: current.hourlyStats.traced + BigInt(Math.floor(Math.random() * 200)) * 10n ** 18n,
		},
	};
}
