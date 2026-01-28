/**
 * Presale Store
 * ==============
 * Runes-based reactive store for the presale page.
 * Polls contract state and derives page state.
 *
 * SSR-SAFE: Returns inert defaults during SSR.
 */

import { browser } from '$app/environment';
import { wallet } from '$lib/web3/wallet.svelte';
import {
	getPresaleState,
	getPricingMode,
	getPresaleConfig,
	getPresaleProgress,
	getUserAllocation,
	getUserContribution,
	isClaimingEnabled,
	hasClaimed,
	getClaimable,
	getCurveConfig,
} from './presale-contracts';
import { PresaleState, PricingMode, POLL_INTERVAL_MS } from './types';
import type {
	PresalePageState,
	PresaleConfig,
	PresaleProgress,
	CurveConfig,
	UserPresalePosition,
} from './types';

// ════════════════════════════════════════════════════════════════
// STORE
// ════════════════════════════════════════════════════════════════

function createPresaleStore() {
	// ─────────────────────────────────────────────────────────────
	// Contract State
	// ─────────────────────────────────────────────────────────────

	let contractState = $state<PresaleState>(PresaleState.PENDING);
	let pricingMode = $state<PricingMode>(PricingMode.TRANCHE);
	let config = $state<PresaleConfig>({
		minContribution: 0n,
		maxContribution: 0n,
		maxPerWallet: 0n,
		allowMultipleContributions: false,
		startTime: 0n,
		endTime: 0n,
		emergencyDeadline: 0n,
	});
	let progress = $state<PresaleProgress>({
		totalSold: 0n,
		totalSupply: 0n,
		totalRaised: 0n,
		currentPrice: 0n,
		contributorCount: 0n,
	});
	let curveConfig = $state<CurveConfig>({
		startPrice: 0n,
		endPrice: 0n,
		totalSupply: 0n,
	});

	// ─────────────────────────────────────────────────────────────
	// User State
	// ─────────────────────────────────────────────────────────────

	let userAllocation = $state<bigint>(0n);
	let userContribution = $state<bigint>(0n);
	let userHasClaimed = $state<boolean>(false);
	let userClaimable = $state<bigint>(0n);

	// ─────────────────────────────────────────────────────────────
	// Claim State
	// ─────────────────────────────────────────────────────────────

	let claimEnabled = $state<boolean>(false);

	// ─────────────────────────────────────────────────────────────
	// Loading / Error
	// ─────────────────────────────────────────────────────────────

	let loading = $state<boolean>(true);
	let error = $state<string | null>(null);

	// ─────────────────────────────────────────────────────────────
	// Derived: Page State
	// ─────────────────────────────────────────────────────────────

	const pageState = $derived<PresalePageState>(derivePageState());

	function derivePageState(): PresalePageState {
		// User already claimed
		if (userHasClaimed && userAllocation > 0n) return 'CLAIMED';

		// Claim phase active
		if (claimEnabled && contractState === PresaleState.FINALIZED) return 'CLAIM_ACTIVE';

		// Refunding
		if (contractState === PresaleState.REFUNDING) return 'REFUNDING';

		// Finalized (no claim yet)
		if (contractState === PresaleState.FINALIZED) return 'ENDED';

		// Open — check if sold out
		if (contractState === PresaleState.OPEN) {
			if (progress.totalSupply > 0n && progress.totalSold >= progress.totalSupply) {
				return 'SOLD_OUT';
			}
			return 'LIVE';
		}

		// Pending
		return 'NOT_STARTED';
	}

	const percentSold = $derived(
		progress.totalSupply > 0n
			? Number((progress.totalSold * 10000n) / progress.totalSupply) / 100
			: 0,
	);

	const userPosition = $derived<UserPresalePosition>({
		allocation: userAllocation,
		contributed: userContribution,
		hasClaimed: userHasClaimed,
		claimable: userClaimable,
	});

	const hasContributed = $derived(userContribution > 0n);

	// ─────────────────────────────────────────────────────────────
	// Polling
	// ─────────────────────────────────────────────────────────────

	let pollTimer: ReturnType<typeof setInterval> | null = null;

	/** Fetch all contract state. Called on init and every poll interval. */
	async function refresh() {
		if (!browser) return;

		try {
			// Parallel fetch of independent reads
			const [state, mode, cfg, prog, curve] = await Promise.all([
				getPresaleState(),
				getPricingMode(),
				getPresaleConfig(),
				getPresaleProgress(),
				getCurveConfig(),
			]);

			contractState = state;
			pricingMode = mode;
			config = cfg;
			progress = prog;
			curveConfig = curve;

			// User-specific reads (only if connected)
			const addr = wallet.address;
			if (addr) {
				const [alloc, contrib, claimed, claimable, claimEn] = await Promise.all([
					getUserAllocation(addr),
					getUserContribution(addr),
					hasClaimed(addr),
					getClaimable(addr),
					isClaimingEnabled(),
				]);

				userAllocation = alloc;
				userContribution = contrib;
				userHasClaimed = claimed;
				userClaimable = claimable;
				claimEnabled = claimEn;
			} else {
				// Reset user state when disconnected
				userAllocation = 0n;
				userContribution = 0n;
				userHasClaimed = false;
				userClaimable = 0n;

				// Still check claim status (public read)
				claimEnabled = await isClaimingEnabled();
			}

			loading = false;
			error = null;
		} catch (err) {
			console.error('[Presale] Refresh error:', err);
			error = err instanceof Error ? err.message : 'Failed to load presale data';
			loading = false;
		}
	}

	/**
	 * Initialize the store. Starts polling.
	 * Returns cleanup function for use with $effect.
	 */
	function init(): () => void {
		if (!browser) return () => {};

		// Initial fetch
		refresh();

		// Start polling
		pollTimer = setInterval(refresh, POLL_INTERVAL_MS);

		return () => {
			if (pollTimer) {
				clearInterval(pollTimer);
				pollTimer = null;
			}
		};
	}

	// ─────────────────────────────────────────────────────────────
	// Public Interface
	// ─────────────────────────────────────────────────────────────

	return {
		// Contract state
		get contractState() { return contractState; },
		get pricingMode() { return pricingMode; },
		get config() { return config; },
		get progress() { return progress; },
		get curveConfig() { return curveConfig; },

		// User state
		get userPosition() { return userPosition; },
		get hasContributed() { return hasContributed; },

		// Claim state
		get claimEnabled() { return claimEnabled; },

		// Derived
		get pageState() { return pageState; },
		get percentSold() { return percentSold; },

		// Loading / error
		get loading() { return loading; },
		get error() { return error; },

		// Actions
		init,
		refresh,
	};
}

// ════════════════════════════════════════════════════════════════
// SINGLETON
// ════════════════════════════════════════════════════════════════

export const presale = createPresaleStore();
