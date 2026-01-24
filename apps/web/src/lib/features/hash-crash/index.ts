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

// Audio
export { createHashCrashAudio, type HashCrashAudio } from './audio';

// Contract provider (Option B - clean separation)
export {
	createContractProvider,
	type ContractProvider,
	type ContractProviderState,
	type PlayerInfo,
} from './contractProvider.svelte';

// Low-level contract interactions
export {
	// Types
	SessionState,
	type RoundData,
	type PlayerBetData,
	type SeedInfo,
	// Helpers
	formatMultiplier as formatContractMultiplier,
	parseMultiplier,
	formatData,
	parseData,
	// Read functions
	getCurrentRoundId,
	getRound,
	getPlayerBet,
	getRoundPlayers,
	isSeedReady,
	isSeedExpired,
	getSeedInfo,
	getDataBalance,
	getArcadeCoreAllowance,
	getWithdrawableBalance,
	// Write functions
	approveDataForArcade,
	startRound,
	placeBet as placeBetContract,
	lockRound,
	revealCrash,
	settleAll,
	withdraw,
	handleExpiredRound,
	// Event watchers
	watchBetPlaced,
	watchCrashPointRevealed,
	watchPlayerWon,
	watchPlayerLost,
	watchRoundStarted,
	// Errors
	parseContractError,
} from './contracts';

// Re-export player types from arcade
export type { HashCrashPlayerResult, HashCrashBet, HashCrashRound } from '$lib/core/types/arcade';
