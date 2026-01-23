/**
 * Arcade Game Engine
 * ==================
 * Shared infrastructure for all GHOSTNET arcade games.
 *
 * @example
 * ```typescript
 * import {
 *   createGameEngine,
 *   createCountdown,
 *   createScoreSystem,
 *   createRewardSystem
 * } from '$lib/features/arcade/engine';
 * ```
 */

// Game Engine - Core FSM
export {
	createGameEngine,
	type GameEngine,
	type StandardPhase,
	type PhaseTransition,
	type PhaseConfig,
	type GameEngineConfig,
	type GameEngineState,
} from './GameEngine.svelte';

// Timer System - Countdowns, Clocks, Frame Loops
export {
	createCountdown,
	createClock,
	createFrameLoop,
	formatTime,
	formatElapsed,
	type Countdown,
	type Clock,
	type FrameLoop,
	type TimerStatus,
	type CountdownState,
	type ClockState,
	type CountdownConfig,
	type ClockConfig,
} from './TimerSystem.svelte';

// Score System - Points, Combos, Streaks
export {
	createScoreSystem,
	type ScoreSystem,
	type ScoreState,
	type ScoreEvent,
	type ScoreConfig,
} from './ScoreSystem.svelte';

// Reward System - Payouts, Burn Logic, Session Tracking
export {
	createRewardSystem,
	type RewardSystem,
	type RewardTier,
	type RewardConfig,
	type PayoutCalculation,
	type PoolPayoutCalculation,
	type RewardState,
} from './RewardSystem.svelte';
