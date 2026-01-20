/**
 * Hack Run Feature
 * =================
 * Multi-node exploration mini-game for earning yield multipliers.
 *
 * @example
 * ```svelte
 * <script lang="ts">
 *   import { getHackRunStore } from '$lib/features/hackrun';
 *
 *   const store = getHackRunStore();
 *
 *   function handleStart() {
 *     store.selectDifficulty();
 *   }
 * </script>
 * ```
 */

// Store
export { createHackRunStore, getHackRunStore, resetHackRunStore } from './store.svelte';
export type { HackRunStore } from './store.svelte';

// Generators
export {
	generateRun,
	generateNode,
	generateTypingChallenge,
	generateAvailableRuns,
	initializeProgress,
	calculateXP,
	calculateFinalMultiplier,
	calculateTotalLoot,
	RUN_CONFIG,
	MULTIPLIER_DURATION,
} from './generators';

// Components
export { default as RunCard } from './RunCard.svelte';
export { default as RunSelectionView } from './RunSelectionView.svelte';
export { default as NodeMap } from './NodeMap.svelte';
export { default as RunProgress } from './RunProgress.svelte';
export { default as CurrentNodePanel } from './CurrentNodePanel.svelte';
export { default as ActiveRunView } from './ActiveRunView.svelte';
export { default as RunCompleteView } from './RunCompleteView.svelte';
export { default as RunHistoryPanel } from './RunHistoryPanel.svelte';
