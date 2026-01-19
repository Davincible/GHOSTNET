/**
 * Typing Game (Trace Evasion) Feature
 * ====================================
 * Mini-game that allows operators to reduce their death rate
 * through typing challenges.
 */

// Store
export {
	createTypingGameStore,
	calculateReward,
	calculateWpm,
	calculateAccuracy,
	type TypingProgress,
	type TypingGameResult,
	type GameState,
	type TypingGameStore
} from './store.svelte';

// Components
export { default as IdleView } from './IdleView.svelte';
export { default as CountdownView } from './CountdownView.svelte';
export { default as ActiveView } from './ActiveView.svelte';
export { default as CompleteView } from './CompleteView.svelte';
