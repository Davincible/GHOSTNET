/**
 * HASH CRASH Feature Module
 * =========================
 * Multiplier crash game - bet on how high the multiplier will go before it crashes.
 *
 * @example
 * ```svelte
 * <script>
 *   import { HashCrashGame } from '$lib/features/hash-crash';
 * </script>
 *
 * <HashCrashGame simulate />
 * ```
 */

// Main component
export { default as HashCrashGame } from './components/HashCrashGame.svelte';

// Sub-components (for custom layouts)
export { default as MultiplierDisplay } from './components/MultiplierDisplay.svelte';
export { default as BettingPanel } from './components/BettingPanel.svelte';
export { default as LivePlayersPanel } from './components/LivePlayersPanel.svelte';
export { default as RecentCrashes } from './components/RecentCrashes.svelte';
export { default as CrashChart } from './components/CrashChart.svelte';

// Store
export {
	createHashCrashStore,
	formatMultiplier,
	getMultiplierColor,
	calculateProfit,
	calculateWinProbability,
	BETTING_DURATION,
	GROWTH_RATE,
	MIN_BET,
	MAX_BET,
	MIN_TARGET,
	MAX_TARGET,
	type HashCrashStore,
	type HashCrashState,
} from './store.svelte';

// Re-export player types from arcade
export type { HashCrashPlayerResult, HashCrashBet, HashCrashRound } from '$lib/core/types/arcade';
