/**
 * PvP Duels Mock Data Generator
 * ==============================
 * Generates mock duel data and simulates opponent behavior for development.
 */

import type {
	Duel,
	DuelPlayerResult,
	DuelTier,
	DuelStatus,
	DuelHistoryEntry,
	DuelStats,
	DuelTypingChallenge,
	CreateDuelParams,
} from '../../../types';
import {
	DUEL_TIERS,
	DUEL_EXPIRY_MS,
	getDuelTier,
	calculateDuelWinnings,
} from '../../../types/duel';
import { getRandomCommand, getCommandDifficulty } from '../data/commands';

// ════════════════════════════════════════════════════════════════
// CONSTANTS
// ════════════════════════════════════════════════════════════════

/** Mock addresses for opponents */
const MOCK_OPPONENTS: Array<{ address: `0x${string}`; name: string }> = [
	{ address: '0x7a3f9c2d1e8b4a5f6c7d8e9f0a1b2c3d4e5f6a7b', name: 'GhostRunner' },
	{ address: '0x9c2d3b1a8f2e4c5d6a7b8c9d0e1f2a3b4c5d6e7f', name: 'ByteSlayer' },
	{ address: '0x3b1a8f2e9c4d5a6b7c8d9e0f1a2b3c4d5e6f7a8b', name: 'CipherPunk' },
	{ address: '0x8f2e1d4c3b5a6d7e8f9a0b1c2d3e4f5a6b7c8d9e', name: 'NullPointer' },
	{ address: '0x1d4c5e7b2a9f6c3d8e4a7b0c1d2e3f4a5b6c7d8e', name: 'DarkTrace' },
	{ address: '0x5e7b2a9f1d4c6c3d8e4a7b0c1d2e3f4a5b6c7d8e', name: 'HexMaster' },
	{ address: '0x2a9f6c3d1e5b4a8f7c2d9e0a1b3c4d5e6f7a8b9c', name: 'BitRunner' },
	{ address: '0x6c3d8e4a2f9b1c5d7e6a0b1c2d3e4f5a6b7c8d9e', name: 'VoidWalker' },
];

/** User's address for mock mode */
export const MOCK_USER_ADDRESS: `0x${string}` = '0x1234567890123456789012345678901234567890';

// ════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════

/** Pick a random item from an array */
function pickRandom<T>(arr: readonly T[]): T {
	return arr[Math.floor(Math.random() * arr.length)];
}

/** Generate random integer in range (inclusive) */
function randomInt(min: number, max: number): number {
	return Math.floor(Math.random() * (max - min + 1)) + min;
}

/** Generate a random token amount (in wei) */
function randomAmount(min: number, max: number): bigint {
	const value = Math.floor(Math.random() * (max - min) + min);
	return BigInt(value) * 10n ** 18n;
}

/** Generate a random wager within a tier's range */
function randomWagerForTier(tier: DuelTier): bigint {
	const config = DUEL_TIERS[tier];
	const minValue = Number(config.minWager / 10n ** 18n);
	const maxValue = Number(config.maxWager / 10n ** 18n);
	return randomAmount(minValue, maxValue);
}

/** Truncate address for display */
function truncateAddress(address: `0x${string}`): string {
	return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

// ════════════════════════════════════════════════════════════════
// CHALLENGE GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate a typing challenge for a duel.
 * Medium difficulty is standard for duels to balance skill and speed.
 */
export function generateDuelChallenge(): DuelTypingChallenge {
	const command = getRandomCommand('medium');
	return {
		command,
		difficulty: getCommandDifficulty(command),
		timeLimit: 60, // 60 seconds for duel challenges
	};
}

// ════════════════════════════════════════════════════════════════
// DUEL GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate a mock duel.
 * @param options - Configuration options
 */
export function generateMockDuel(options?: {
	status?: DuelStatus;
	tier?: DuelTier;
	isUserChallenger?: boolean;
	isUserOpponent?: boolean;
}): Duel {
	const now = Date.now();
	const status = options?.status ?? 'open';
	const tier = options?.tier ?? pickRandom(['quick_draw', 'showdown', 'high_noon'] as DuelTier[]);
	const wagerAmount = randomWagerForTier(tier);

	// Pick challenger and opponent
	const isUserChallenger = options?.isUserChallenger ?? Math.random() < 0.3;
	const isUserOpponent = options?.isUserOpponent ?? false;

	let challenger: `0x${string}`;
	let challengerName: string | undefined;
	let opponent: `0x${string}` | null = null;
	let opponentName: string | undefined;

	if (isUserChallenger) {
		challenger = MOCK_USER_ADDRESS;
		challengerName = 'You';
	} else {
		const mockChallenger = pickRandom(MOCK_OPPONENTS);
		challenger = mockChallenger.address;
		challengerName = mockChallenger.name;
	}

	// Add opponent based on status
	if (status !== 'open' && status !== 'cancelled') {
		if (isUserOpponent) {
			opponent = MOCK_USER_ADDRESS;
			opponentName = 'You';
		} else if (!isUserChallenger) {
			// Pick a different mock opponent
			const available = MOCK_OPPONENTS.filter((o) => o.address !== challenger);
			const mockOpponent = pickRandom(available);
			opponent = mockOpponent.address;
			opponentName = mockOpponent.name;
		} else {
			// User is challenger, pick any opponent
			const mockOpponent = pickRandom(MOCK_OPPONENTS);
			opponent = mockOpponent.address;
			opponentName = mockOpponent.name;
		}
	}

	// Generate timing
	let createdAt: number;
	let expiresAt: number;
	let startedAt: number | undefined;
	let completedAt: number | undefined;

	switch (status) {
		case 'open':
			createdAt = now - randomInt(30, 180) * 1000; // 30s - 3min ago
			expiresAt = createdAt + DUEL_EXPIRY_MS;
			break;
		case 'accepted':
			createdAt = now - randomInt(60, 120) * 1000;
			expiresAt = createdAt + DUEL_EXPIRY_MS;
			break;
		case 'active':
			createdAt = now - randomInt(120, 180) * 1000;
			expiresAt = createdAt + DUEL_EXPIRY_MS;
			startedAt = now - randomInt(5, 30) * 1000; // Started 5-30s ago
			break;
		case 'complete':
			createdAt = now - randomInt(5, 60) * 60 * 1000; // 5-60 min ago
			expiresAt = createdAt + DUEL_EXPIRY_MS;
			startedAt = createdAt + randomInt(30, 60) * 1000;
			completedAt = startedAt + randomInt(20, 50) * 1000;
			break;
		case 'cancelled':
		case 'declined':
		default:
			createdAt = now - randomInt(10, 60) * 60 * 1000;
			expiresAt = createdAt + DUEL_EXPIRY_MS;
			break;
	}

	// Generate results for completed duels
	const results: Duel['results'] = {};
	let winner: `0x${string}` | null = null;

	if (status === 'complete' && opponent) {
		results.challenger = generateMockResult(tier, true);
		results.opponent = generateMockResult(tier, Math.random() < 0.5);

		// Determine winner (faster completion time)
		if (results.challenger.completed && results.opponent.completed) {
			winner = results.challenger.finishTime <= results.opponent.finishTime ? challenger : opponent;
		} else if (results.challenger.completed) {
			winner = challenger;
		} else if (results.opponent.completed) {
			winner = opponent;
		} else {
			// Neither completed - higher progress wins
			winner =
				results.challenger.progressPercent >= results.opponent.progressPercent
					? challenger
					: opponent;
		}
	}

	return {
		id: crypto.randomUUID(),
		challenger,
		challengerName,
		opponent,
		opponentName,
		wagerAmount,
		tier,
		status,
		challenge: generateDuelChallenge(),
		results,
		winner,
		createdAt,
		expiresAt,
		startedAt,
		completedAt,
		spectatorCount: status === 'active' ? randomInt(0, 15) : 0,
		isDirectChallenge: false,
	};
}

/**
 * Generate a mock player result.
 */
function generateMockResult(tier: DuelTier, completed: boolean): DuelPlayerResult {
	const config = DUEL_TIERS[tier];
	const wpmRange = config.mockOpponentWpm;
	const wpm = randomInt(wpmRange.min, wpmRange.max);
	const accuracy = 0.85 + Math.random() * 0.15; // 85-100%
	const timeElapsed = completed ? randomInt(15000, 45000) : randomInt(5000, 30000);

	return {
		completed,
		accuracy,
		wpm,
		timeElapsed,
		finishTime: Date.now() - randomInt(1000, 60000),
		progressPercent: completed ? 100 : randomInt(30, 95),
	};
}

// ════════════════════════════════════════════════════════════════
// LIST GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate a list of open challenges (lobby).
 */
export function generateOpenChallenges(count: number = 5): Duel[] {
	const duels: Duel[] = [];

	for (let i = 0; i < count; i++) {
		duels.push(
			generateMockDuel({
				status: 'open',
				isUserChallenger: false,
			})
		);
	}

	// Sort by creation time (newest first)
	return duels.sort((a, b) => b.createdAt - a.createdAt);
}

/**
 * Generate user's active challenges (ones they created).
 */
export function generateUserChallenges(): Duel[] {
	// 0-2 pending challenges from user
	const count = randomInt(0, 2);
	const duels: Duel[] = [];

	for (let i = 0; i < count; i++) {
		duels.push(
			generateMockDuel({
				status: 'open',
				isUserChallenger: true,
			})
		);
	}

	return duels;
}

/**
 * Generate duel history.
 */
export function generateDuelHistory(count: number = 10): DuelHistoryEntry[] {
	const history: DuelHistoryEntry[] = [];

	for (let i = 0; i < count; i++) {
		const isUserChallenger = Math.random() < 0.5;
		const duel = generateMockDuel({
			status: 'complete',
			isUserChallenger,
			isUserOpponent: !isUserChallenger,
		});

		const youWon = duel.winner === MOCK_USER_ADDRESS;
		const { payout } = calculateDuelWinnings(duel.wagerAmount);
		const netAmount = youWon ? payout - duel.wagerAmount : -duel.wagerAmount;

		history.push({ duel, youWon, netAmount });
	}

	// Sort by completion time (newest first)
	return history.sort((a, b) => (b.duel.completedAt ?? 0) - (a.duel.completedAt ?? 0));
}

// ════════════════════════════════════════════════════════════════
// USER STATS
// ════════════════════════════════════════════════════════════════

/**
 * Generate mock user duel statistics.
 */
export function generateDuelStats(): DuelStats {
	const totalDuels = randomInt(10, 100);
	const winRate = 0.4 + Math.random() * 0.3; // 40-70%
	const wins = Math.floor(totalDuels * winRate);
	const losses = totalDuels - wins;

	const avgWager = randomInt(30, 100);
	const { payout } = calculateDuelWinnings(BigInt(avgWager) * 10n ** 18n);
	const avgPayout = Number(payout / 10n ** 18n);

	const totalWon = BigInt(Math.floor(wins * avgPayout)) * 10n ** 18n;
	const totalLost = BigInt(losses * avgWager) * 10n ** 18n;

	return {
		totalDuels,
		wins,
		losses,
		winRate,
		totalWon,
		totalLost,
		netProfit: totalWon - totalLost,
		bestWpm: randomInt(80, 120),
		averageWpm: randomInt(55, 85),
		currentStreak: randomInt(-3, 5),
		bestStreak: randomInt(3, 10),
	};
}

// ════════════════════════════════════════════════════════════════
// OPPONENT SIMULATION
// ════════════════════════════════════════════════════════════════

/**
 * Simulate opponent typing progress during a duel.
 * Returns progress updates at realistic intervals.
 */
export function createOpponentSimulator(
	tier: DuelTier,
	challengeLength: number,
	onProgress: (progress: number) => void,
	onComplete: (result: DuelPlayerResult) => void
): { start: () => void; stop: () => void } {
	const config = DUEL_TIERS[tier];
	const targetWpm = randomInt(config.mockOpponentWpm.min, config.mockOpponentWpm.max);

	// Calculate characters per second (WPM * 5 chars/word / 60 sec)
	const charsPerSecond = (targetWpm * 5) / 60;

	// Add some variance to make it feel more human
	const variance = 0.2; // 20% variance in speed

	let intervalId: ReturnType<typeof setInterval> | null = null;
	let progress = 0;
	let correctChars = 0;
	let totalChars = 0;
	let startTime = 0;
	const errorRate = 0.05 + Math.random() * 0.1; // 5-15% error rate

	function start() {
		startTime = Date.now();
		progress = 0;
		correctChars = 0;
		totalChars = 0;

		// Update every 100ms
		intervalId = setInterval(() => {
			const elapsed = Date.now() - startTime;

			// Calculate expected progress with variance
			const speedMultiplier = 1 + (Math.random() - 0.5) * variance;
			const expectedChars = (elapsed / 1000) * charsPerSecond * speedMultiplier;

			// Simulate typing with errors
			while (totalChars < expectedChars && progress < 100) {
				totalChars++;
				if (Math.random() > errorRate) {
					correctChars++;
				}
				progress = Math.min(100, (correctChars / challengeLength) * 100);
			}

			onProgress(Math.floor(progress));

			// Check if completed
			if (correctChars >= challengeLength) {
				stop();
				const timeElapsed = Date.now() - startTime;
				onComplete({
					completed: true,
					accuracy: totalChars > 0 ? correctChars / totalChars : 0,
					wpm: timeElapsed > 0 ? Math.round((correctChars / 5 / timeElapsed) * 60000) : 0,
					timeElapsed,
					finishTime: Date.now(),
					progressPercent: 100,
				});
			}
		}, 100);
	}

	function stop() {
		if (intervalId) {
			clearInterval(intervalId);
			intervalId = null;
		}
	}

	return { start, stop };
}

// ════════════════════════════════════════════════════════════════
// DUEL OPERATIONS
// ════════════════════════════════════════════════════════════════

/**
 * Simulate creating a new duel.
 */
export function simulateCreateDuel(params: CreateDuelParams): Duel {
	const tier = getDuelTier(params.wagerAmount);
	const now = Date.now();

	return {
		id: crypto.randomUUID(),
		challenger: MOCK_USER_ADDRESS,
		challengerName: 'You',
		opponent: params.targetAddress ?? null,
		opponentName: params.targetAddress ? truncateAddress(params.targetAddress) : undefined,
		wagerAmount: params.wagerAmount,
		tier,
		status: 'open',
		challenge: generateDuelChallenge(),
		results: {},
		winner: null,
		createdAt: now,
		expiresAt: now + DUEL_EXPIRY_MS,
		spectatorCount: 0,
		isDirectChallenge: !!params.targetAddress,
	};
}

/**
 * Simulate accepting a duel.
 */
export function simulateAcceptDuel(duel: Duel): Duel {
	return {
		...duel,
		status: 'accepted',
		opponent: MOCK_USER_ADDRESS,
		opponentName: 'You',
	};
}

/**
 * Simulate starting a duel (after countdown).
 */
export function simulateStartDuel(duel: Duel): Duel {
	return {
		...duel,
		status: 'active',
		startedAt: Date.now(),
	};
}

/**
 * Simulate completing a duel with results.
 */
export function simulateCompleteDuel(
	duel: Duel,
	userResult: DuelPlayerResult,
	opponentResult: DuelPlayerResult
): Duel {
	const isUserChallenger = duel.challenger === MOCK_USER_ADDRESS;

	const results: Duel['results'] = isUserChallenger
		? { challenger: userResult, opponent: opponentResult }
		: { challenger: opponentResult, opponent: userResult };

	// Determine winner
	let winner: `0x${string}` | null = null;
	const cResult = results.challenger;
	const oResult = results.opponent;

	if (cResult && oResult) {
		if (cResult.completed && oResult.completed) {
			winner = cResult.finishTime <= oResult.finishTime ? duel.challenger : duel.opponent;
		} else if (cResult.completed) {
			winner = duel.challenger;
		} else if (oResult.completed) {
			winner = duel.opponent;
		} else {
			winner = cResult.progressPercent >= oResult.progressPercent ? duel.challenger : duel.opponent;
		}
	}

	return {
		...duel,
		status: 'complete',
		results,
		winner,
		completedAt: Date.now(),
	};
}

/**
 * Simulate cancelling a duel.
 */
export function simulateCancelDuel(duel: Duel): Duel {
	return {
		...duel,
		status: 'cancelled',
	};
}
