/**
 * Daily Ops Contract Provider
 * ============================
 * Provides contract-backed data for the Daily Ops feature.
 * Polls contract state for streak, badges, and death rate reduction.
 *
 * ARCHITECTURE:
 * - Polls DailyOps contract for player streak data
 * - Watches events for real-time claim updates
 * - Handles server-signed mission claims
 *
 * USAGE:
 * ```ts
 * const provider = createDailyOpsProvider();
 * provider.connect();
 * // Access state via provider.state
 * // Claim via provider.claimMission(params)
 * ```
 */

import { browser } from '$app/environment';
import { wallet } from '$lib/web3/wallet.svelte';
import {
	getStreak,
	getBadges,
	getCurrentDay,
	hasClaimedDay,
	isShieldActive,
	getDeathRateReduction,
	getTreasuryBalance,
	getDataBalance,
	claimDailyReward,
	purchaseShield,
	watchDailyRewardClaimed,
	watchMilestoneReached,
	watchBadgeEarned,
	watchStreakBroken,
	watchShieldPurchased,
	formatData,
	type RawPlayerStreak,
	type RawBadge,
	type ClaimParams,
} from './contracts';
import { STREAK_MILESTONES, BADGE_INFO } from '$lib/core/types/daily';

// ════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════

export interface DailyOpsState {
	/** Player's streak data */
	streak: RawPlayerStreak | null;
	/** Player's badges */
	badges: RawBadge[];
	/** Current UTC day number */
	currentDay: bigint;
	/** Whether player has claimed today */
	hasClaimedToday: boolean;
	/** Whether shield is active */
	shieldActive: boolean;
	/** Death rate reduction in basis points (300 = 3%) */
	deathRateReduction: number;
	/** Treasury balance (for display) */
	treasuryBalance: bigint;
	/** Player's DATA token balance */
	balance: bigint;
	/** Connection status */
	isConnected: boolean;
	/** Loading state for transactions */
	isLoading: boolean;
	/** Current transaction hash (if any) */
	pendingTx: `0x${string}` | null;
	/** Error message if any */
	error: string | null;
	/** Last poll timestamp */
	lastPoll: number;
}

export interface NextMilestone {
	days: number;
	daysRemaining: number;
	deathRateReduction: number;
	bonus: bigint;
	badge: string | null;
}

export interface DailyOpsProvider {
	/** Reactive state */
	readonly state: DailyOpsState;

	/** Derived: Can claim today (not claimed, wallet connected) */
	readonly canClaim: boolean;

	/** Derived: Can purchase shield (no active shield, wallet connected) */
	readonly canPurchaseShield: boolean;

	/** Derived: Next milestone info */
	readonly nextMilestone: NextMilestone | null;

	/** Derived: Progress to next milestone (0-100) */
	readonly milestoneProgress: number;

	/** Derived: Death rate reduction formatted (e.g., "-3%") */
	readonly deathRateFormatted: string;

	/** Derived: Shield expiry formatted */
	readonly shieldExpiryFormatted: string | null;

	/** Connect to contract (start polling/watching) */
	connect(): () => void;

	/** Disconnect (stop polling/watching) */
	disconnect(): void;

	/** Claim daily mission reward */
	claimMission(params: ClaimParams): Promise<void>;

	/** Purchase streak shield */
	buyShield(days: 1 | 7): Promise<void>;

	/** Force refresh state */
	refresh(): Promise<void>;
}

// ════════════════════════════════════════════════════════════════
// CONFIGURATION
// ════════════════════════════════════════════════════════════════

/** Poll interval in ms */
const POLL_INTERVAL = 10000; // 10 seconds (daily ops doesn't need fast updates)

// ════════════════════════════════════════════════════════════════
// PROVIDER FACTORY
// ════════════════════════════════════════════════════════════════

export function createDailyOpsProvider(): DailyOpsProvider {
	// ─────────────────────────────────────────────────────────────
	// STATE
	// ─────────────────────────────────────────────────────────────

	let state = $state<DailyOpsState>({
		streak: null,
		badges: [],
		currentDay: 0n,
		hasClaimedToday: false,
		shieldActive: false,
		deathRateReduction: 0,
		treasuryBalance: 0n,
		balance: 0n,
		isConnected: false,
		isLoading: false,
		pendingTx: null,
		error: null,
		lastPoll: 0,
	});

	// Polling and event cleanup functions
	let pollInterval: ReturnType<typeof setInterval> | null = null;
	let unwatchClaimed: (() => void) | null = null;
	let unwatchMilestone: (() => void) | null = null;
	let unwatchBadge: (() => void) | null = null;
	let unwatchStreakBroken: (() => void) | null = null;
	let unwatchShield: (() => void) | null = null;

	// Track if provider is active
	let isProviderActive = false;

	// ─────────────────────────────────────────────────────────────
	// EFFECTS
	// ─────────────────────────────────────────────────────────────

	// Start event watching when wallet connects
	$effect(() => {
		if (isProviderActive && wallet.isConnected && wallet.chainId) {
			startWatching();
		}
	});

	// ─────────────────────────────────────────────────────────────
	// DERIVED STATE
	// ─────────────────────────────────────────────────────────────

	const canClaim = $derived(
		!state.hasClaimedToday && !state.isLoading && wallet.isConnected && state.isConnected
	);

	const canPurchaseShield = $derived(
		!state.shieldActive && !state.isLoading && wallet.isConnected && state.isConnected
	);

	const nextMilestone = $derived.by((): NextMilestone | null => {
		if (!state.streak) return null;

		const currentStreak = state.streak.currentStreak;

		// Find next milestone
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

		// Already past all milestones
		return null;
	});

	const milestoneProgress = $derived.by(() => {
		if (!state.streak || !nextMilestone) return 100;

		const currentStreak = state.streak.currentStreak;

		// Find previous milestone
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

		return Math.min(100, Math.round((progress / range) * 100));
	});

	const deathRateFormatted = $derived(
		state.deathRateReduction > 0 ? `-${(state.deathRateReduction / 100).toFixed(0)}%` : '0%'
	);

	const shieldExpiryFormatted = $derived.by(() => {
		if (!state.streak || state.streak.shieldExpiryDay === 0n) return null;
		if (!state.shieldActive) return null;

		const expiryDay = Number(state.streak.shieldExpiryDay);
		const currentDay = Number(state.currentDay);
		const daysRemaining = expiryDay - currentDay;

		if (daysRemaining <= 0) return null;
		return `${daysRemaining} day${daysRemaining !== 1 ? 's' : ''} remaining`;
	});

	// ─────────────────────────────────────────────────────────────
	// POLLING
	// ─────────────────────────────────────────────────────────────

	async function poll(): Promise<void> {
		if (!browser || !wallet.isConnected || !wallet.address) return;

		try {
			const [
				streak,
				badges,
				currentDay,
				shieldActive,
				deathRateReduction,
				treasuryBalance,
				balance,
			] = await Promise.all([
				getStreak(wallet.address),
				getBadges(wallet.address),
				getCurrentDay(),
				isShieldActive(wallet.address),
				getDeathRateReduction(wallet.address),
				getTreasuryBalance(),
				getDataBalance(wallet.address),
			]);

			// Check if claimed today
			const hasClaimedToday = await hasClaimedDay(wallet.address, currentDay);

			state = {
				...state,
				streak,
				badges,
				currentDay,
				hasClaimedToday,
				shieldActive,
				deathRateReduction,
				treasuryBalance,
				balance,
				lastPoll: Date.now(),
				error: null,
			};
		} catch (err) {
			console.error('[DailyOpsProvider] Poll error:', err);
			// Don't overwrite state on poll errors
		}
	}

	function startPolling(): void {
		if (pollInterval) return;

		// Initial poll
		poll();

		// Set up interval
		pollInterval = setInterval(poll, POLL_INTERVAL);
	}

	function stopPolling(): void {
		if (pollInterval) {
			clearInterval(pollInterval);
			pollInterval = null;
		}
	}

	// ─────────────────────────────────────────────────────────────
	// EVENT WATCHING
	// ─────────────────────────────────────────────────────────────

	function startWatching(): void {
		if (!wallet.isConnected || !wallet.chainId || !wallet.address) {
			return;
		}

		if (unwatchClaimed) {
			return; // Already watching
		}

		try {
			// Watch for claims (filter by this player)
			unwatchClaimed = watchDailyRewardClaimed((event) => {
				if (wallet.address && event.player.toLowerCase() === wallet.address.toLowerCase()) {
					// Update streak from event
					state = {
						...state,
						hasClaimedToday: true,
						streak: state.streak
							? {
									...state.streak,
									currentStreak: event.newStreak,
									longestStreak: Math.max(state.streak.longestStreak, event.newStreak),
									lastClaimDay: event.day,
									totalMissionsCompleted: state.streak.totalMissionsCompleted + 1n,
									totalClaimed: state.streak.totalClaimed + event.reward,
								}
							: null,
					};
				}
			}, wallet.address);

			// Watch for milestones
			unwatchMilestone = watchMilestoneReached((event) => {
				if (wallet.address && event.player.toLowerCase() === wallet.address.toLowerCase()) {
					// Milestone reached - refresh to get updated data
					poll();
				}
			}, wallet.address);

			// Watch for badges
			unwatchBadge = watchBadgeEarned((event) => {
				if (wallet.address && event.player.toLowerCase() === wallet.address.toLowerCase()) {
					// Badge earned - refresh badges
					poll();
				}
			}, wallet.address);

			// Watch for streak breaks
			unwatchStreakBroken = watchStreakBroken((event) => {
				if (wallet.address && event.player.toLowerCase() === wallet.address.toLowerCase()) {
					// Streak broken - refresh
					poll();
				}
			}, wallet.address);

			// Watch for shield purchases
			unwatchShield = watchShieldPurchased((event) => {
				if (wallet.address && event.player.toLowerCase() === wallet.address.toLowerCase()) {
					state = {
						...state,
						shieldActive: true,
						streak: state.streak ? { ...state.streak, shieldExpiryDay: event.expiryDay } : null,
					};
				}
			}, wallet.address);
		} catch (err) {
			console.warn('[DailyOpsProvider] Event watching not available:', err);
		}
	}

	function stopWatching(): void {
		unwatchClaimed?.();
		unwatchMilestone?.();
		unwatchBadge?.();
		unwatchStreakBroken?.();
		unwatchShield?.();
		unwatchClaimed = null;
		unwatchMilestone = null;
		unwatchBadge = null;
		unwatchStreakBroken = null;
		unwatchShield = null;
	}

	// ─────────────────────────────────────────────────────────────
	// CONNECTION
	// ─────────────────────────────────────────────────────────────

	function connect(): () => void {
		if (!browser) return () => {};

		isProviderActive = true;
		state = { ...state, isConnected: true, error: null };

		startPolling();
		startWatching();

		return () => disconnect();
	}

	function disconnect(): void {
		isProviderActive = false;
		stopPolling();
		stopWatching();
		state = { ...state, isConnected: false };
	}

	// ─────────────────────────────────────────────────────────────
	// ACTIONS
	// ─────────────────────────────────────────────────────────────

	async function claimMission(params: ClaimParams): Promise<void> {
		if (!canClaim || state.isLoading) return;

		state = { ...state, isLoading: true, error: null };

		try {
			const hash = await claimDailyReward(params);
			state = { ...state, pendingTx: hash };

			// Refresh after tx
			await poll();
		} catch (err) {
			const errorMessage = err instanceof Error ? err.message : 'Failed to claim reward';
			state = { ...state, error: errorMessage };
			throw err;
		} finally {
			state = { ...state, isLoading: false, pendingTx: null };
		}
	}

	async function buyShield(days: 1 | 7): Promise<void> {
		if (!canPurchaseShield || state.isLoading) return;

		state = { ...state, isLoading: true, error: null };

		try {
			const hash = await purchaseShield(days);
			state = { ...state, pendingTx: hash };

			// Refresh after tx
			await poll();
		} catch (err) {
			const errorMessage = err instanceof Error ? err.message : 'Failed to purchase shield';
			state = { ...state, error: errorMessage };
			throw err;
		} finally {
			state = { ...state, isLoading: false, pendingTx: null };
		}
	}

	async function refresh(): Promise<void> {
		await poll();
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
