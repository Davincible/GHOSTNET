/**
 * Mock Feed Event Generator
 * ==========================
 * Generates realistic fake feed events for development
 */

import type { FeedEvent, FeedEventData, FeedEventType, Level } from '../../../types';
import { LEVELS } from '../../../types';

// ════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════

/** Generate a random Ethereum address */
export function generateRandomAddress(): `0x${string}` {
	const chars = '0123456789abcdef';
	let addr = '0x';
	for (let i = 0; i < 40; i++) {
		addr += chars[Math.floor(Math.random() * chars.length)];
	}
	return addr as `0x${string}`;
}

/** Pick a random item from an array */
function pickRandom<T>(arr: readonly T[]): T {
	return arr[Math.floor(Math.random() * arr.length)];
}

/** Pick a random level, weighted towards higher-risk levels */
function pickRandomLevel(): Level {
	const weights = [0.1, 0.15, 0.25, 0.3, 0.2]; // VAULT least common
	const rand = Math.random();
	let cumulative = 0;
	for (let i = 0; i < LEVELS.length; i++) {
		cumulative += weights[i];
		if (rand < cumulative) return LEVELS[i];
	}
	return 'DARKNET';
}

/** Generate a random token amount (in wei) */
function randomAmount(min: number, max: number): bigint {
	const value = Math.floor(Math.random() * (max - min) + min);
	return BigInt(value) * 10n ** 18n;
}

// ════════════════════════════════════════════════════════════════
// EVENT DATA GENERATORS
// ════════════════════════════════════════════════════════════════

function generateJackInData(): FeedEventData {
	return {
		type: 'JACK_IN',
		address: generateRandomAddress(),
		level: pickRandomLevel(),
		amount: randomAmount(10, 1000)
	};
}

function generateExtractData(): FeedEventData {
	const amount = randomAmount(50, 2000);
	const gain = randomAmount(5, 500);
	return {
		type: 'EXTRACT',
		address: generateRandomAddress(),
		amount,
		gain
	};
}

function generateTracedData(): FeedEventData {
	return {
		type: 'TRACED',
		address: generateRandomAddress(),
		level: pickRandom(['SUBNET', 'DARKNET', 'BLACK_ICE'] as const),
		amountLost: randomAmount(20, 500)
	};
}

function generateSurvivedData(): FeedEventData {
	return {
		type: 'SURVIVED',
		address: generateRandomAddress(),
		level: pickRandomLevel(),
		streak: Math.floor(Math.random() * 20) + 1
	};
}

function generateTraceScanWarningData(): FeedEventData {
	return {
		type: 'TRACE_SCAN_WARNING',
		level: pickRandom(['SUBNET', 'DARKNET', 'BLACK_ICE'] as const),
		secondsUntil: Math.floor(Math.random() * 60) + 10
	};
}

function generateTraceScanCompleteData(): FeedEventData {
	const total = Math.floor(Math.random() * 50) + 10;
	const traced = Math.floor(total * (Math.random() * 0.4));
	return {
		type: 'TRACE_SCAN_COMPLETE',
		level: pickRandom(['SUBNET', 'DARKNET', 'BLACK_ICE'] as const),
		survivors: total - traced,
		traced
	};
}

function generateWhaleAlertData(): FeedEventData {
	return {
		type: 'WHALE_ALERT',
		address: generateRandomAddress(),
		level: pickRandom(['VAULT', 'MAINFRAME'] as const),
		amount: randomAmount(5000, 50000)
	};
}

function generateJackpotData(): FeedEventData {
	return {
		type: 'JACKPOT',
		address: generateRandomAddress(),
		level: 'BLACK_ICE',
		amount: randomAmount(1000, 10000)
	};
}

function generateCrewEventData(): FeedEventData {
	const crewNames = ['PHANTOMS', 'NETRUNNERS', 'CIPHER', 'VOID WALKERS', 'GHOST PROTOCOL'];
	const events = [
		{ eventType: 'raid_complete', message: 'completed crew raid - all members +10% boost' },
		{ eventType: 'milestone', message: 'reached 100K total extracted' },
		{ eventType: 'member_join', message: 'new member joined' }
	];
	const event = pickRandom(events);
	return {
		type: 'CREW_EVENT',
		crewName: pickRandom(crewNames),
		eventType: event.eventType,
		message: event.message
	};
}

function generateMinigameResultData(): FeedEventData {
	const games = ['typing', 'hack_run'];
	const results = ['perfect score', '3x multiplier active', 'speed bonus earned'];
	return {
		type: 'MINIGAME_RESULT',
		address: generateRandomAddress(),
		game: pickRandom(games),
		result: pickRandom(results)
	};
}

// ════════════════════════════════════════════════════════════════
// MAIN GENERATOR
// ════════════════════════════════════════════════════════════════

/** Event type distribution (weighted) */
const EVENT_WEIGHTS: { type: FeedEventType; weight: number }[] = [
	{ type: 'JACK_IN', weight: 25 },
	{ type: 'EXTRACT', weight: 15 },
	{ type: 'TRACED', weight: 10 },
	{ type: 'SURVIVED', weight: 20 },
	{ type: 'TRACE_SCAN_WARNING', weight: 8 },
	{ type: 'TRACE_SCAN_COMPLETE', weight: 5 },
	{ type: 'WHALE_ALERT', weight: 3 },
	{ type: 'JACKPOT', weight: 1 },
	{ type: 'CREW_EVENT', weight: 5 },
	{ type: 'MINIGAME_RESULT', weight: 8 }
];

/** Pick a random event type based on weights */
function pickRandomEventType(): FeedEventType {
	const totalWeight = EVENT_WEIGHTS.reduce((sum, e) => sum + e.weight, 0);
	let rand = Math.random() * totalWeight;
	
	for (const { type, weight } of EVENT_WEIGHTS) {
		rand -= weight;
		if (rand <= 0) return type;
	}
	
	return 'JACK_IN';
}

/** Generate event data based on type */
function generateEventData(type: FeedEventType): FeedEventData {
	switch (type) {
		case 'JACK_IN':
			return generateJackInData();
		case 'EXTRACT':
			return generateExtractData();
		case 'TRACED':
			return generateTracedData();
		case 'SURVIVED':
			return generateSurvivedData();
		case 'TRACE_SCAN_WARNING':
			return generateTraceScanWarningData();
		case 'TRACE_SCAN_COMPLETE':
			return generateTraceScanCompleteData();
		case 'WHALE_ALERT':
			return generateWhaleAlertData();
		case 'JACKPOT':
			return generateJackpotData();
		case 'CREW_EVENT':
			return generateCrewEventData();
		case 'MINIGAME_RESULT':
			return generateMinigameResultData();
		default:
			return generateJackInData();
	}
}

/** Generate a single random feed event */
export function generateRandomFeedEvent(): FeedEvent {
	const type = pickRandomEventType();
	return {
		id: crypto.randomUUID(),
		type,
		timestamp: Date.now() - Math.floor(Math.random() * 60000), // Last minute
		data: generateEventData(type)
	};
}

/** Generate multiple feed events */
export function generateMockFeedEvents(count: number): FeedEvent[] {
	const events: FeedEvent[] = [];
	
	for (let i = 0; i < count; i++) {
		events.push(generateRandomFeedEvent());
	}
	
	// Sort by timestamp, newest first
	return events.sort((a, b) => b.timestamp - a.timestamp);
}
