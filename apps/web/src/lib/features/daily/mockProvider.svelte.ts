/**
 * Mock Daily Ops Provider
 * ========================
 * Provides mock data for testing the Daily Ops UI without a wallet or contract.
 *
 * Usage: Navigate to /arcade/daily-ops?mock=true
 *
 * URL parameters:
 * - ?mock=true                  Enable mock mode
 * - ?mock=true&streak=45        Set current streak
 * - ?mock=true&claimed=true     Mark today as claimed
 * - ?mock=true&shield=3         Set shield days remaining
 * - ?mock=true&badges=2         Number of badges earned (0-3)
 */

import { STREAK_MILESTONES, BADGE_IDS, BADGE_INFO } from '$lib/core/types/daily';
import type { DailyOpsState, DailyOpsProvider, NextMilestone } from './contractProvider.svelte';
import type { RawPlayerStreak, RawBadge } from './contracts';

// ════════════════════════════════════════════════════════════════
// MOCK DATA GENERATORS
// ════════════════════════════════════════════════════════════════

/** Generate mock streak data */
function createMockStreak(currentStreak: number, shieldDays: number): RawPlayerStreak {
	const currentDay = BigInt(Math.floor(Date.now() / 86400000));

	return {
		currentStreak,
		longestStreak: Math.max(currentStreak, currentStreak + 5), // Longest is slightly higher
		lastClaimDay: currentDay - 1n, // Claimed yesterday
		shieldExpiryDay: shieldDays > 0 ? currentDay + BigInt(shieldDays) : 0n,
		totalClaimed: BigInt(currentStreak * 100) * 10n ** 18n, // 100 DATA per day average
		totalMissionsCompleted: BigInt(currentStreak + 10),
	};
}

/** Generate mock badges based on streak */
function createMockBadges(numBadges: number): RawBadge[] {
	const badges: RawBadge[] = [];
	const now = BigInt(Math.floor(Date.now() / 1000));

	if (numBadges >= 1) {
		badges.push({
			badgeId: BADGE_IDS.WEEK_WARRIOR,
			earnedAt: now - 86400n * 30n, // 30 days ago
		});
	}
	if (numBadges >= 2) {
		badges.push({
			badgeId: BADGE_IDS.DEDICATED_OPERATOR,
			earnedAt: now - 86400n * 10n, // 10 days ago
		});
	}
	if (numBadges >= 3) {
		badges.push({
			badgeId: BADGE_IDS.LEGEND,
			earnedAt: now - 86400n * 2n, // 2 days ago
		});
	}

	return badges;
}

/** Calculate death rate reduction from streak */
function calculateDeathRateReduction(streak: number): number {
	if (streak >= 180) return 1000;
	if (streak >= 60) return 800;
	if (streak >= 14) return 500;
	if (streak >= 3) return 300;
	return 0;
}

// ════════════════════════════════════════════════════════════════
// MOCK PROVIDER FACTORY
// ════════════════════════════════════════════════════════════════

export interface MockProviderOptions {
	streak?: number;
	claimed?: boolean;
	shield?: number;
	badges?: number;
}

export function createMockDailyOpsProvider(options: MockProviderOptions = {}): DailyOpsProvider {
	const {
		streak: initialStreak = 12,
		claimed: hasClaimed = false,
		shield: shieldDays = 0,
		badges: numBadges = 1,
	} = options;

	const currentDay = BigInt(Math.floor(Date.now() / 86400000));
	const mockStreak = createMockStreak(initialStreak, shieldDays);
	const mockBadges = createMockBadges(numBadges);

	// ─────────────────────────────────────────────────────────────
	// STATE
	// ─────────────────────────────────────────────────────────────

	let state = $state<DailyOpsState>({
		streak: mockStreak,
		badges: mockBadges,
		currentDay,
		hasClaimedToday: hasClaimed,
		shieldActive: shieldDays > 0,
		deathRateReduction: calculateDeathRateReduction(initialStreak),
		treasuryBalance: 1000000n * 10n ** 18n, // 1M DATA
		balance: 5000n * 10n ** 18n, // 5000 DATA
		isConnected: true,
		isLoading: false,
		pendingTx: null,
		error: null,
		lastPoll: Date.now(),
	});

	// ─────────────────────────────────────────────────────────────
	// DERIVED STATE
	// ─────────────────────────────────────────────────────────────

	const canClaim = $derived(!state.hasClaimedToday && !state.isLoading && state.isConnected);

	const canPurchaseShield = $derived(!state.shieldActive && !state.isLoading && state.isConnected);

	const nextMilestone = $derived.by((): NextMilestone | null => {
		if (!state.streak) return null;

		const currentStreak = state.streak.currentStreak;

		for (const milestone of STREAK_MILESTONES) {
			if (currentStreak < milestone.days) {
				return {
					days: milestone.days,
					daysRemaining: milestone.days - currentStreak,
					deathRateReduction: milestone.deathRateReduction,
					bonus: milestone.bonus,
					badge: milestone.badge ? (BADGE_INFO[milestone.badge]?.name ?? null) : null,
				};
			}
		}

		return null;
	});

	const milestoneProgress = $derived.by(() => {
		if (!state.streak || !nextMilestone) return 100;

		const currentStreak = state.streak.currentStreak;

		let prevMilestoneDay = 0;
		for (const milestone of STREAK_MILESTONES) {
			if (milestone.days <= currentStreak) {
				prevMilestoneDay = milestone.days;
			} else {
				break;
			}
		}

		const range = nextMilestone.days - prevMilestoneDay;
		const progress = currentStreak - prevMilestoneDay;

		if (range <= 0) return 100;

		return Math.min(100, Math.round((progress / range) * 100));
	});

	const deathRateFormatted = $derived(
		state.deathRateReduction > 0 ? `-${(state.deathRateReduction / 100).toFixed(0)}%` : '0%'
	);

	const shieldExpiryFormatted = $derived.by(() => {
		if (!state.streak || state.streak.shieldExpiryDay === 0n) return null;
		if (!state.shieldActive) return null;

		const expiryDay = Number(state.streak.shieldExpiryDay);
		const currentDayNum = Number(state.currentDay);
		const daysRemaining = expiryDay - currentDayNum;

		if (daysRemaining <= 0) return null;
		return `${daysRemaining} day${daysRemaining !== 1 ? 's' : ''} remaining`;
	});

	// ─────────────────────────────────────────────────────────────
	// MOCK ACTIONS
	// ─────────────────────────────────────────────────────────────

	function connect(): () => void {
		console.log('[MockDailyOps] Connected (mock mode)');
		return () => disconnect();
	}

	function disconnect(): void {
		console.log('[MockDailyOps] Disconnected (mock mode)');
	}

	async function claimMission(): Promise<void> {
		if (!canClaim) return;

		state = { ...state, isLoading: true };

		// Simulate network delay
		await new Promise((resolve) => setTimeout(resolve, 1500));

		// Update state as if claim succeeded
		const newStreak = (state.streak?.currentStreak ?? 0) + 1;
		state = {
			...state,
			isLoading: false,
			hasClaimedToday: true,
			streak: state.streak
				? {
						...state.streak,
						currentStreak: newStreak,
						longestStreak: Math.max(state.streak.longestStreak, newStreak),
						lastClaimDay: state.currentDay,
						totalMissionsCompleted: state.streak.totalMissionsCompleted + 1n,
						totalClaimed: state.streak.totalClaimed + 100n * 10n ** 18n,
					}
				: null,
			deathRateReduction: calculateDeathRateReduction(newStreak),
		};

		console.log('[MockDailyOps] Claimed! New streak:', newStreak);
	}

	async function buyShield(days: 1 | 7): Promise<void> {
		if (!canPurchaseShield) return;

		state = { ...state, isLoading: true };

		// Simulate network delay
		await new Promise((resolve) => setTimeout(resolve, 1500));

		// Update state as if purchase succeeded
		const cost = days === 1 ? 50n * 10n ** 18n : 200n * 10n ** 18n;
		state = {
			...state,
			isLoading: false,
			shieldActive: true,
			balance: state.balance - cost,
			streak: state.streak
				? {
						...state.streak,
						shieldExpiryDay: state.currentDay + BigInt(days),
					}
				: null,
		};

		console.log('[MockDailyOps] Shield purchased! Days:', days);
	}

	async function refresh(): Promise<void> {
		state = { ...state, lastPoll: Date.now() };
		console.log('[MockDailyOps] Refreshed (mock mode)');
	}

	// ─────────────────────────────────────────────────────────────
	// RETURN INTERFACE
	// ─────────────────────────────────────────────────────────────

	return {
		get state() {
			return state;
		},
		get canClaim() {
			return canClaim;
		},
		get canPurchaseShield() {
			return canPurchaseShield;
		},
		get nextMilestone() {
			return nextMilestone;
		},
		get milestoneProgress() {
			return milestoneProgress;
		},
		get deathRateFormatted() {
			return deathRateFormatted;
		},
		get shieldExpiryFormatted() {
			return shieldExpiryFormatted;
		},
		connect,
		disconnect,
		claimMission,
		buyShield,
		refresh,
	};
}
