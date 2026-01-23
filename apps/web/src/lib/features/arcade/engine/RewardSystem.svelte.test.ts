/**
 * Reward System Tests
 * ===================
 * Tests for payout calculations, burn logic, and session tracking.
 *
 * CRITICAL: File must have .svelte.test.ts extension for runes to work!
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { createRewardSystem, type RewardSystem, type RewardConfig } from './RewardSystem.svelte';

// ============================================================================
// TEST FIXTURES
// ============================================================================

const ONE_TOKEN = 10n ** 18n; // 1 token with 18 decimals

function createTestConfig(overrides: Partial<RewardConfig> = {}): RewardConfig {
	return {
		houseEdge: 0.03, // 3%
		burnRate: 1.0, // 100%
		minBet: 10n * ONE_TOKEN, // 10 tokens
		maxBet: 1000n * ONE_TOKEN, // 1000 tokens
		...overrides,
	};
}

// ============================================================================
// INITIAL STATE TESTS
// ============================================================================

describe('createRewardSystem', () => {
	let rewards: RewardSystem;

	beforeEach(() => {
		rewards = createRewardSystem(createTestConfig());
	});

	describe('initial state', () => {
		it('starts with zero values', () => {
			expect(rewards.state.currentBet).toBe(0n);
			expect(rewards.state.entryFee).toBe(0n);
			expect(rewards.state.sessionWinnings).toBe(0n);
			expect(rewards.state.sessionLosses).toBe(0n);
			expect(rewards.state.sessionPnL).toBe(0n);
			expect(rewards.state.gamesPlayed).toBe(0);
			expect(rewards.state.gamesWon).toBe(0);
			expect(rewards.state.winRate).toBe(0);
		});

		it('exposes config', () => {
			expect(rewards.config.houseEdge).toBe(0.03);
			expect(rewards.config.burnRate).toBe(1.0);
			expect(rewards.config.minBet).toBe(10n * ONE_TOKEN);
			expect(rewards.config.maxBet).toBe(1000n * ONE_TOKEN);
		});
	});
});

// ============================================================================
// BET MANAGEMENT TESTS
// ============================================================================

describe('bet management', () => {
	let rewards: RewardSystem;

	beforeEach(() => {
		rewards = createRewardSystem(createTestConfig());
	});

	describe('setBet', () => {
		it('sets bet within valid range', () => {
			const result = rewards.setBet(100n * ONE_TOKEN);
			expect(result).toBe(true);
			expect(rewards.state.currentBet).toBe(100n * ONE_TOKEN);
		});

		it('rejects bet below minimum', () => {
			const result = rewards.setBet(5n * ONE_TOKEN); // Below 10 min
			expect(result).toBe(false);
			expect(rewards.state.currentBet).toBe(0n);
		});

		it('rejects bet above maximum', () => {
			const result = rewards.setBet(2000n * ONE_TOKEN); // Above 1000 max
			expect(result).toBe(false);
			expect(rewards.state.currentBet).toBe(0n);
		});

		it('accepts minimum bet', () => {
			const result = rewards.setBet(10n * ONE_TOKEN);
			expect(result).toBe(true);
		});

		it('accepts maximum bet', () => {
			const result = rewards.setBet(1000n * ONE_TOKEN);
			expect(result).toBe(true);
		});
	});

	describe('setEntryFee', () => {
		it('sets entry fee', () => {
			rewards.setEntryFee(25n * ONE_TOKEN);
			expect(rewards.state.entryFee).toBe(25n * ONE_TOKEN);
		});
	});
});

// ============================================================================
// PAYOUT CALCULATION TESTS
// ============================================================================

describe('calculatePayout', () => {
	let rewards: RewardSystem;

	beforeEach(() => {
		rewards = createRewardSystem(
			createTestConfig({
				houseEdge: 0.03, // 3%
				burnRate: 1.0, // 100%
			})
		);
	});

	it('calculates gross payout correctly', () => {
		rewards.setBet(100n * ONE_TOKEN);
		const payout = rewards.calculatePayout(5.0);

		// 100 * 5.0 = 500
		expect(payout.grossPayout).toBe(500n * ONE_TOKEN);
	});

	it('calculates house edge on profit', () => {
		rewards.setBet(100n * ONE_TOKEN);
		const payout = rewards.calculatePayout(5.0);

		// Gross: 500, Profit: 400, House edge: 400 * 0.03 = 12
		expect(payout.houseEdgeAmount).toBe(12n * ONE_TOKEN);
	});

	it('calculates net payout after house edge', () => {
		rewards.setBet(100n * ONE_TOKEN);
		const payout = rewards.calculatePayout(5.0);

		// Gross: 500, House edge: 12, Net: 488
		expect(payout.netPayout).toBe(488n * ONE_TOKEN);
	});

	it('calculates burn amount', () => {
		rewards.setBet(100n * ONE_TOKEN);
		const payout = rewards.calculatePayout(5.0);

		// House edge: 12, Burn rate: 100%, Burn: 12
		expect(payout.burnAmount).toBe(12n * ONE_TOKEN);
	});

	it('calculates profit correctly', () => {
		rewards.setBet(100n * ONE_TOKEN);
		const payout = rewards.calculatePayout(5.0);

		// Net: 488, Bet: 100, Profit: 388
		expect(payout.profit).toBe(388n * ONE_TOKEN);
		expect(payout.isWin).toBe(true);
	});

	it('handles loss (multiplier < 1)', () => {
		rewards.setBet(100n * ONE_TOKEN);
		const payout = rewards.calculatePayout(0.5);

		// Gross: 50, Profit: -50 (loss)
		// House edge only applies to positive profit
		expect(payout.grossPayout).toBe(50n * ONE_TOKEN);
		expect(payout.houseEdgeAmount).toBe(0n); // No house edge on loss
		expect(payout.netPayout).toBe(50n * ONE_TOKEN);
		expect(payout.profit).toBe(-50n * ONE_TOKEN);
		expect(payout.isWin).toBe(false);
	});

	it('handles break-even (multiplier = 1)', () => {
		rewards.setBet(100n * ONE_TOKEN);
		const payout = rewards.calculatePayout(1.0);

		expect(payout.grossPayout).toBe(100n * ONE_TOKEN);
		expect(payout.houseEdgeAmount).toBe(0n); // No profit, no house edge
		expect(payout.profit).toBe(0n);
		expect(payout.isWin).toBe(false); // 0 is not > 0
	});

	it('uses provided bet instead of current bet', () => {
		rewards.setBet(100n * ONE_TOKEN);
		const payout = rewards.calculatePayout(2.0, 200n * ONE_TOKEN);

		expect(payout.bet).toBe(200n * ONE_TOKEN);
		expect(payout.grossPayout).toBe(400n * ONE_TOKEN);
	});

	it('handles fractional multipliers', () => {
		rewards.setBet(100n * ONE_TOKEN);
		const payout = rewards.calculatePayout(2.35);

		// 100 * 2.35 = 235
		expect(payout.grossPayout).toBe(235n * ONE_TOKEN);
	});
});

// ============================================================================
// POOL PAYOUT CALCULATION TESTS
// ============================================================================

describe('calculatePoolPayout', () => {
	let rewards: RewardSystem;

	beforeEach(() => {
		rewards = createRewardSystem(
			createTestConfig({
				burnRate: 1.0, // 100% of rake burned
			})
		);
	});

	it('calculates rake correctly', () => {
		const result = rewards.calculatePoolPayout(
			1000n * ONE_TOKEN, // Total pool
			600n * ONE_TOKEN, // Winning pool
			400n * ONE_TOKEN, // Losing pool
			0.05 // 5% rake
		);

		// Rake: 1000 * 0.05 = 50
		expect(result.rakeAmount).toBe(50n * ONE_TOKEN);
	});

	it('calculates distributable pool', () => {
		const result = rewards.calculatePoolPayout(
			1000n * ONE_TOKEN,
			600n * ONE_TOKEN,
			400n * ONE_TOKEN,
			0.05
		);

		// Total: 1000, Rake: 50, Distributable: 950
		expect(result.distributablePool).toBe(950n * ONE_TOKEN);
	});

	it('calculates burn amount', () => {
		const result = rewards.calculatePoolPayout(
			1000n * ONE_TOKEN,
			600n * ONE_TOKEN,
			400n * ONE_TOKEN,
			0.05
		);

		// Rake: 50, Burn rate: 100%, Burn: 50
		expect(result.burnAmount).toBe(50n * ONE_TOKEN);
	});

	it('calculates payout multiplier for winners', () => {
		const result = rewards.calculatePoolPayout(
			1000n * ONE_TOKEN,
			600n * ONE_TOKEN,
			400n * ONE_TOKEN,
			0.05
		);

		// Distributable: 950, Winning pool: 600
		// Multiplier: 950 / 600 = 1.583...
		expect(result.payoutMultiplier).toBeCloseTo(1.58, 1);
	});

	it('handles zero winning pool', () => {
		const result = rewards.calculatePoolPayout(
			1000n * ONE_TOKEN,
			0n, // No winners
			1000n * ONE_TOKEN,
			0.05
		);

		expect(result.payoutMultiplier).toBe(0);
	});

	it('uses default 5% rake', () => {
		const result = rewards.calculatePoolPayout(
			1000n * ONE_TOKEN,
			600n * ONE_TOKEN,
			400n * ONE_TOKEN
		);

		expect(result.rakeAmount).toBe(50n * ONE_TOKEN);
	});
});

// ============================================================================
// SESSION TRACKING TESTS
// ============================================================================

describe('session tracking', () => {
	let rewards: RewardSystem;

	beforeEach(() => {
		rewards = createRewardSystem(createTestConfig());
	});

	describe('recordWin', () => {
		it('updates session winnings', () => {
			rewards.recordWin(100n * ONE_TOKEN);
			expect(rewards.state.sessionWinnings).toBe(100n * ONE_TOKEN);
		});

		it('increments games played', () => {
			rewards.recordWin(100n * ONE_TOKEN);
			expect(rewards.state.gamesPlayed).toBe(1);
		});

		it('increments games won', () => {
			rewards.recordWin(100n * ONE_TOKEN);
			expect(rewards.state.gamesWon).toBe(1);
		});

		it('updates PnL', () => {
			rewards.recordWin(100n * ONE_TOKEN);
			expect(rewards.state.sessionPnL).toBe(100n * ONE_TOKEN);
		});

		it('updates win rate', () => {
			rewards.recordWin(100n * ONE_TOKEN);
			rewards.recordWin(100n * ONE_TOKEN);
			expect(rewards.state.winRate).toBe(1.0); // 2/2
		});

		it('accumulates multiple wins', () => {
			rewards.recordWin(100n * ONE_TOKEN);
			rewards.recordWin(200n * ONE_TOKEN);
			expect(rewards.state.sessionWinnings).toBe(300n * ONE_TOKEN);
			expect(rewards.state.gamesWon).toBe(2);
		});
	});

	describe('recordLoss', () => {
		it('updates session losses', () => {
			rewards.recordLoss(50n * ONE_TOKEN);
			expect(rewards.state.sessionLosses).toBe(50n * ONE_TOKEN);
		});

		it('increments games played', () => {
			rewards.recordLoss(50n * ONE_TOKEN);
			expect(rewards.state.gamesPlayed).toBe(1);
		});

		it('does not increment games won', () => {
			rewards.recordLoss(50n * ONE_TOKEN);
			expect(rewards.state.gamesWon).toBe(0);
		});

		it('updates PnL negatively', () => {
			rewards.recordLoss(50n * ONE_TOKEN);
			expect(rewards.state.sessionPnL).toBe(-50n * ONE_TOKEN);
		});

		it('updates win rate', () => {
			rewards.recordWin(100n * ONE_TOKEN);
			rewards.recordLoss(50n * ONE_TOKEN);
			expect(rewards.state.winRate).toBe(0.5); // 1/2
		});
	});

	describe('mixed session', () => {
		it('calculates correct PnL', () => {
			rewards.recordWin(100n * ONE_TOKEN);
			rewards.recordLoss(30n * ONE_TOKEN);
			rewards.recordWin(50n * ONE_TOKEN);
			rewards.recordLoss(20n * ONE_TOKEN);

			// Winnings: 150, Losses: 50, PnL: 100
			expect(rewards.state.sessionWinnings).toBe(150n * ONE_TOKEN);
			expect(rewards.state.sessionLosses).toBe(50n * ONE_TOKEN);
			expect(rewards.state.sessionPnL).toBe(100n * ONE_TOKEN);
		});

		it('calculates correct stats', () => {
			rewards.recordWin(100n * ONE_TOKEN);
			rewards.recordLoss(30n * ONE_TOKEN);
			rewards.recordWin(50n * ONE_TOKEN);
			rewards.recordLoss(20n * ONE_TOKEN);

			expect(rewards.state.gamesPlayed).toBe(4);
			expect(rewards.state.gamesWon).toBe(2);
			expect(rewards.state.winRate).toBe(0.5);
		});
	});
});

// ============================================================================
// REWARD TIER TESTS
// ============================================================================

describe('reward tiers', () => {
	let rewards: RewardSystem;

	beforeEach(() => {
		rewards = createRewardSystem(
			createTestConfig({
				tiers: [
					{ id: 'perfect', name: 'PERFECT', minThreshold: 1.0, value: -0.25, description: '-25%' },
					{
						id: 'excellent',
						name: 'Excellent',
						minThreshold: 0.95,
						value: -0.2,
						description: '-20%',
					},
					{ id: 'great', name: 'Great', minThreshold: 0.85, value: -0.15, description: '-15%' },
					{ id: 'good', name: 'Good', minThreshold: 0.7, value: -0.1, description: '-10%' },
				],
			})
		);
	});

	describe('getRewardTier', () => {
		it('returns perfect tier for 100%', () => {
			const tier = rewards.getRewardTier(1.0);
			expect(tier?.id).toBe('perfect');
			expect(tier?.value).toBe(-0.25);
		});

		it('returns excellent tier for 95-99%', () => {
			const tier = rewards.getRewardTier(0.97);
			expect(tier?.id).toBe('excellent');
		});

		it('returns great tier for 85-94%', () => {
			const tier = rewards.getRewardTier(0.9);
			expect(tier?.id).toBe('great');
		});

		it('returns good tier for 70-84%', () => {
			const tier = rewards.getRewardTier(0.75);
			expect(tier?.id).toBe('good');
		});

		it('returns null below minimum threshold', () => {
			const tier = rewards.getRewardTier(0.5);
			expect(tier).toBeNull();
		});

		it('returns highest matching tier', () => {
			// At exactly 0.95, should return excellent (not great)
			const tier = rewards.getRewardTier(0.95);
			expect(tier?.id).toBe('excellent');
		});
	});

	describe('no tiers configured', () => {
		it('returns null when no tiers', () => {
			rewards = createRewardSystem(createTestConfig()); // No tiers
			const tier = rewards.getRewardTier(1.0);
			expect(tier).toBeNull();
		});
	});
});

// ============================================================================
// RESET TESTS
// ============================================================================

describe('resetSession', () => {
	let rewards: RewardSystem;

	beforeEach(() => {
		rewards = createRewardSystem(createTestConfig());
	});

	it('resets all session state', () => {
		rewards.setBet(100n * ONE_TOKEN);
		rewards.setEntryFee(25n * ONE_TOKEN);
		rewards.recordWin(200n * ONE_TOKEN);
		rewards.recordLoss(50n * ONE_TOKEN);

		rewards.resetSession();

		expect(rewards.state.currentBet).toBe(0n);
		expect(rewards.state.entryFee).toBe(0n);
		expect(rewards.state.sessionWinnings).toBe(0n);
		expect(rewards.state.sessionLosses).toBe(0n);
		expect(rewards.state.sessionPnL).toBe(0n);
		expect(rewards.state.gamesPlayed).toBe(0);
		expect(rewards.state.gamesWon).toBe(0);
		expect(rewards.state.winRate).toBe(0);
	});
});

// ============================================================================
// EDGE CASE TESTS
// ============================================================================

describe('edge cases', () => {
	let rewards: RewardSystem;

	beforeEach(() => {
		rewards = createRewardSystem(
			createTestConfig({
				houseEdge: 0.03,
				burnRate: 0.5, // 50% burn rate
			})
		);
	});

	it('handles partial burn rate', () => {
		rewards.setBet(100n * ONE_TOKEN);
		const payout = rewards.calculatePayout(5.0);

		// House edge: 12, Burn rate: 50%, Burn: 6
		expect(payout.burnAmount).toBe(6n * ONE_TOKEN);
	});

	it('handles zero burn rate', () => {
		rewards = createRewardSystem(createTestConfig({ burnRate: 0 }));
		rewards.setBet(100n * ONE_TOKEN);
		const payout = rewards.calculatePayout(5.0);

		expect(payout.burnAmount).toBe(0n);
	});

	it('handles zero house edge', () => {
		rewards = createRewardSystem(createTestConfig({ houseEdge: 0 }));
		rewards.setBet(100n * ONE_TOKEN);
		const payout = rewards.calculatePayout(5.0);

		expect(payout.houseEdgeAmount).toBe(0n);
		expect(payout.grossPayout).toBe(payout.netPayout);
	});

	it('handles very small bets', () => {
		rewards = createRewardSystem(createTestConfig({ minBet: 1n }));
		rewards.setBet(1n);
		const payout = rewards.calculatePayout(2.0);

		expect(payout.grossPayout).toBe(2n);
	});

	it('handles very large multipliers', () => {
		rewards.setBet(100n * ONE_TOKEN);
		const payout = rewards.calculatePayout(1000.0);

		expect(payout.grossPayout).toBe(100000n * ONE_TOKEN);
	});
});
