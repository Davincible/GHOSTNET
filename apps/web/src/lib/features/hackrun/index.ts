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
	MULTIPLIER_DURATION
} from './generators';
