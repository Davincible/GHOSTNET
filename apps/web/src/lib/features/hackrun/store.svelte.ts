/**
 * Hack Run Game Store
 * ====================
 * State machine for the multi-node exploration mini-game.
 *
 * State Flow:
 *   idle → selecting → countdown → running ↔ node_typing ↔ node_result → complete
 *                                      ↓
 *                                   failed
 *
 * The game consists of navigating through 5 nodes, completing typing
 * challenges at each node, and earning yield multipliers upon success.
 */

import type {
	HackRun,
	HackRunState,
	HackRunNode,
	NodeResult,
	NodeProgress,
	HackRunResult
} from '$lib/core/types/hackrun';
import {
	generateAvailableRuns,
	initializeProgress,
	calculateXP,
	calculateFinalMultiplier,
	calculateTotalLoot,
	MULTIPLIER_DURATION
} from './generators';

// ════════════════════════════════════════════════════════════════
// CONFIGURATION
// ════════════════════════════════════════════════════════════════

/** Countdown before run starts (seconds) */
const COUNTDOWN_SECONDS = 3;

/** Delay after node result before continuing (ms) */
const NODE_RESULT_DELAY = 2000;

/** Timer update interval (ms) */
const TIMER_INTERVAL = 100;

// ════════════════════════════════════════════════════════════════
// STORE INTERFACE
// ════════════════════════════════════════════════════════════════

export interface HackRunStore {
	/** Current game state (reactive) */
	readonly state: HackRunState;
	/** Accumulated multiplier from completed nodes */
	readonly currentMultiplier: number;
	/** Total loot accumulated */
	readonly totalLoot: bigint;
	/** Percentage of run time remaining (0-1) */
	readonly timeRemainingPercent: number;

	/** Open run selection screen */
	selectDifficulty(): void;
	/** Start a run with the selected configuration */
	startRun(run: HackRun): void;
	/** Begin typing challenge for current node */
	startNode(): void;
	/** Complete current node with typing result */
	completeNode(result: NodeResult): void;
	/** Skip to next node (for backdoors) */
	skipNode(targetNodeId: string): void;
	/** Fail the run with a reason */
	failRun(reason: string): void;
	/** User-initiated abort */
	abort(): void;
	/** Reset to idle state */
	reset(): void;
	/** Cleanup timers on destroy */
	cleanup(): void;
}

// ════════════════════════════════════════════════════════════════
// STORE FACTORY
// ════════════════════════════════════════════════════════════════

/**
 * Create a hack run game store instance.
 *
 * This store manages internal timers for countdown, game timer, and result delays.
 * When creating a non-singleton instance, you MUST call `cleanup()` when the
 * component is destroyed to prevent memory leaks from lingering timers.
 *
 * For most use cases, prefer `getHackRunStore()` which returns a singleton instance
 * that persists across navigations.
 *
 * @example
 * ```svelte
 * <script lang="ts">
 *   import { createHackRunStore } from '$lib/features/hackrun';
 *
 *   const store = createHackRunStore();
 *
 *   // IMPORTANT: Clean up timers on component destroy
 *   $effect(() => {
 *     return () => store.cleanup();
 *   });
 * </script>
 * ```
 *
 * @returns A new HackRunStore instance
 */
export function createHackRunStore(): HackRunStore {
	// ─────────────────────────────────────────────────────────────
	// STATE
	// ─────────────────────────────────────────────────────────────

	let state = $state<HackRunState>({ status: 'idle' });

	// Timers
	let countdownInterval: ReturnType<typeof setInterval> | null = null;
	let timerInterval: ReturnType<typeof setInterval> | null = null;
	let resultTimeout: ReturnType<typeof setTimeout> | null = null;

	// Run tracking
	let runStartTime = 0;

	// ─────────────────────────────────────────────────────────────
	// DERIVED STATE
	// ─────────────────────────────────────────────────────────────

	/**
	 * Calculate accumulated multiplier from completed nodes
	 */
	const currentMultiplier = $derived.by(() => {
		if (state.status === 'idle' || state.status === 'selecting') {
			return 0;
		}

		if (state.status === 'complete') {
			return state.result.finalMultiplier;
		}

		if (state.status === 'failed') {
			// On failure, show what was accumulated before fail
			return calculateAccumulatedMultiplier(state.progress);
		}

		if ('progress' in state) {
			return calculateAccumulatedMultiplier(state.progress);
		}

		if ('run' in state) {
			return state.run.baseMultiplier;
		}

		return 0;
	});

	/**
	 * Calculate total loot from completed nodes
	 */
	const totalLoot = $derived.by(() => {
		if (state.status === 'complete') {
			return state.result.lootGained;
		}

		if ('progress' in state) {
			return calculateTotalLoot(state.progress);
		}

		return 0n;
	});

	/**
	 * Time remaining as percentage (0-1)
	 */
	const timeRemainingPercent = $derived.by(() => {
		if (!('run' in state) || !('timeRemaining' in state)) {
			return 1;
		}

		return Math.max(0, Math.min(1, state.timeRemaining / state.run.timeLimit));
	});

	// ─────────────────────────────────────────────────────────────
	// HELPER FUNCTIONS
	// ─────────────────────────────────────────────────────────────

	function calculateAccumulatedMultiplier(progress: NodeProgress[]): number {
		let multiplier = 0;
		for (const p of progress) {
			if (p.status === 'completed' && p.result) {
				multiplier += p.result.multiplierGained;
			}
		}
		return Math.round(multiplier * 100) / 100;
	}

	function getMainPathNodes(run: HackRun): HackRunNode[] {
		return run.nodes.filter((n) => n.type !== 'backdoor').sort((a, b) => a.position - b.position);
	}

	function getCurrentNodeIndex(progress: NodeProgress[]): number {
		return progress.findIndex((p) => p.status === 'current');
	}

	function getNodeById(run: HackRun, nodeId: string): HackRunNode | undefined {
		return run.nodes.find((n) => n.id === nodeId);
	}

	// ─────────────────────────────────────────────────────────────
	// CLEANUP
	// ─────────────────────────────────────────────────────────────

	function clearTimers(): void {
		if (countdownInterval) {
			clearInterval(countdownInterval);
			countdownInterval = null;
		}
		if (timerInterval) {
			clearInterval(timerInterval);
			timerInterval = null;
		}
		if (resultTimeout) {
			clearTimeout(resultTimeout);
			resultTimeout = null;
		}
	}

	// ─────────────────────────────────────────────────────────────
	// STATE TRANSITIONS
	// ─────────────────────────────────────────────────────────────

	/**
	 * Open run selection: idle → selecting
	 */
	function selectDifficulty(): void {
		if (state.status !== 'idle') return;

		clearTimers();
		state = {
			status: 'selecting',
			availableRuns: generateAvailableRuns()
		};
	}

	/**
	 * Start run: selecting → countdown → running
	 */
	function startRun(run: HackRun): void {
		if (state.status !== 'selecting') return;

		clearTimers();

		// Start countdown
		let secondsLeft = COUNTDOWN_SECONDS;
		state = { status: 'countdown', run, secondsLeft };

		countdownInterval = setInterval(() => {
			if (state.status !== 'countdown') {
				clearTimers();
				return;
			}

			secondsLeft--;

			if (secondsLeft <= 0) {
				// Transition to running
				clearTimers();
				transitionToRunning(run);
			} else {
				state = { status: 'countdown', run, secondsLeft };
			}
		}, 1000);
	}

	/**
	 * Transition to running state
	 */
	function transitionToRunning(run: HackRun): void {
		runStartTime = Date.now();
		const progress = initializeProgress(run);

		state = {
			status: 'running',
			run,
			currentNode: 0,
			progress,
			timeRemaining: run.timeLimit
		};

		// Start timer countdown
		startTimer(run);
	}

	/**
	 * Start the run timer
	 */
	function startTimer(run: HackRun): void {
		timerInterval = setInterval(() => {
			if (!('timeRemaining' in state)) {
				clearTimers();
				return;
			}

			const elapsed = Date.now() - runStartTime;
			const remaining = Math.max(0, run.timeLimit - elapsed);

			if (remaining <= 0) {
				failRun('TIME_EXPIRED');
				return;
			}

			// Update time remaining in current state
			if (state.status === 'running') {
				state = { ...state, timeRemaining: remaining };
			} else if (state.status === 'node_typing') {
				state = { ...state, timeRemaining: remaining };
			} else if (state.status === 'node_result') {
				state = { ...state, timeRemaining: remaining };
			}
		}, TIMER_INTERVAL);
	}

	/**
	 * Start typing challenge: running → node_typing
	 */
	function startNode(): void {
		if (state.status !== 'running') return;

		const { run, progress, timeRemaining } = state;
		const currentIndex = getCurrentNodeIndex(progress);

		if (currentIndex === -1) {
			// No current node - something went wrong
			failRun('INVALID_STATE');
			return;
		}

		const nodeId = progress[currentIndex].nodeId;
		const node = getNodeById(run, nodeId);

		if (!node) {
			failRun('NODE_NOT_FOUND');
			return;
		}

		state = {
			status: 'node_typing',
			run,
			node,
			progress,
			timeRemaining
		};
	}

	/**
	 * Complete node with result: node_typing → node_result → running/complete
	 */
	function completeNode(result: NodeResult): void {
		if (state.status !== 'node_typing') return;

		const { run, node, progress, timeRemaining } = state;

		// Update progress for completed node
		const updatedProgress = progress.map((p) =>
			p.nodeId === node.id ? { ...p, status: result.success ? 'completed' : 'failed', result } as NodeProgress : p
		);

		// If node failed, fail the run
		if (!result.success) {
			state = {
				status: 'failed',
				run,
				reason: 'NODE_FAILED',
				progress: updatedProgress
			};
			clearTimers();
			return;
		}

		// Show result
		state = {
			status: 'node_result',
			run,
			node,
			result,
			progress: updatedProgress,
			timeRemaining
		};

		// After delay, advance to next node or complete
		resultTimeout = setTimeout(() => {
			advanceToNextNode(run, updatedProgress);
		}, NODE_RESULT_DELAY);
	}

	/**
	 * Advance to next node or complete run
	 */
	function advanceToNextNode(run: HackRun, progress: NodeProgress[]): void {
		const currentIndex = progress.findIndex((p) => p.status === 'completed' || p.status === 'failed');
		const lastCompletedIndex = progress.reduce(
			(last, p, i) => (p.status === 'completed' ? i : last),
			-1
		);
		const nextIndex = lastCompletedIndex + 1;

		// Check if run complete
		if (nextIndex >= progress.length) {
			completeRun(run, progress);
			return;
		}

		// Update progress: mark next node as current
		const updatedProgress = progress.map((p, i) =>
			i === nextIndex ? { ...p, status: 'current' as const } : p
		);

		// Calculate remaining time
		const elapsed = Date.now() - runStartTime;
		const timeRemaining = Math.max(0, run.timeLimit - elapsed);

		state = {
			status: 'running',
			run,
			currentNode: nextIndex,
			progress: updatedProgress,
			timeRemaining
		};
	}

	/**
	 * Skip to a different node (backdoor)
	 */
	function skipNode(targetNodeId: string): void {
		if (state.status !== 'running') return;

		const { run, progress, timeRemaining } = state;

		// Find target node position
		const targetNode = getNodeById(run, targetNodeId);
		if (!targetNode) return;

		// Mark skipped nodes
		const updatedProgress = progress.map((p) => {
			const node = getNodeById(run, p.nodeId);
			if (!node) return p;

			if (node.position < targetNode.position && p.status === 'pending') {
				return { ...p, status: 'skipped' as const };
			}
			if (node.id === targetNodeId) {
				return { ...p, status: 'current' as const };
			}
			return p;
		});

		const newCurrentIndex = updatedProgress.findIndex((p) => p.status === 'current');

		state = {
			status: 'running',
			run,
			currentNode: newCurrentIndex,
			progress: updatedProgress,
			timeRemaining
		};
	}

	/**
	 * Complete the run successfully
	 */
	function completeRun(run: HackRun, progress: NodeProgress[]): void {
		clearTimers();

		const elapsed = Date.now() - runStartTime;
		const finalMultiplier = calculateFinalMultiplier(run, progress);
		const lootGained = calculateTotalLoot(progress);
		const xpGained = calculateXP(run, progress);
		const nodesCompleted = progress.filter((p) => p.status === 'completed').length;

		const result: HackRunResult = {
			success: true,
			nodesCompleted,
			totalNodes: progress.length,
			finalMultiplier,
			lootGained,
			timeElapsed: elapsed,
			xpGained,
			entryRefunded: true
		};

		state = { status: 'complete', run, result };
	}

	/**
	 * Fail the run
	 */
	function failRun(reason: string): void {
		clearTimers();

		if (!('run' in state)) {
			state = { status: 'idle' };
			return;
		}

		const run = state.run;
		const progress = 'progress' in state ? state.progress : [];

		state = {
			status: 'failed',
			run,
			reason,
			progress
		};
	}

	/**
	 * User-initiated abort
	 */
	function abort(): void {
		if (state.status === 'idle' || state.status === 'complete' || state.status === 'failed') {
			return;
		}

		failRun('USER_ABORT');
	}

	/**
	 * Reset to idle state
	 */
	function reset(): void {
		clearTimers();
		runStartTime = 0;
		state = { status: 'idle' };
	}

	/**
	 * Cleanup all active timers and intervals.
	 *
	 * **IMPORTANT:** When using `createHackRunStore()` directly (not the singleton),
	 * this MUST be called when the component is destroyed to prevent memory leaks
	 * from lingering timers (countdown, game timer, result delay).
	 *
	 * When using `getHackRunStore()` (singleton), cleanup is handled by `resetHackRunStore()`.
	 *
	 * @example
	 * In Svelte 5, use $effect cleanup:
	 * ```typescript
	 * $effect(() => {
	 *   return () => store.cleanup();
	 * });
	 * ```
	 */
	function cleanup(): void {
		clearTimers();
	}

	// ─────────────────────────────────────────────────────────────
	// RETURN INTERFACE
	// ─────────────────────────────────────────────────────────────

	return {
		get state() {
			return state;
		},
		get currentMultiplier() {
			return currentMultiplier;
		},
		get totalLoot() {
			return totalLoot;
		},
		get timeRemainingPercent() {
			return timeRemainingPercent;
		},
		selectDifficulty,
		startRun,
		startNode,
		completeNode,
		skipNode,
		failRun,
		abort,
		reset,
		cleanup
	};
}

// ════════════════════════════════════════════════════════════════
// SINGLETON INSTANCE
// ════════════════════════════════════════════════════════════════

let store: ReturnType<typeof createHackRunStore> | null = null;

/**
 * Get or create the singleton hack run store.
 *
 * This is the recommended way to access the store in components. The singleton
 * instance persists across navigations, allowing users to navigate away and
 * return without losing game state.
 *
 * **Timer Management:** Since the singleton persists, do NOT call `cleanup()`
 * on component destroy. Instead, the store's `reset()` method should be called
 * when the game ends, or use `resetHackRunStore()` to fully dispose of the singleton.
 *
 * @example
 * ```svelte
 * <script lang="ts">
 *   import { getHackRunStore } from '$lib/features/hackrun';
 *
 *   const store = getHackRunStore();
 *   // No cleanup needed - singleton persists across navigations
 * </script>
 * ```
 *
 * @returns The singleton HackRunStore instance
 */
export function getHackRunStore(): HackRunStore {
	if (!store) {
		store = createHackRunStore();
	}
	return store;
}

/**
 * Reset and dispose of the singleton store instance.
 *
 * This cleans up all timers and nullifies the singleton reference.
 * The next call to `getHackRunStore()` will create a fresh instance.
 *
 * Useful for:
 * - Testing (ensuring clean state between tests)
 * - App-level cleanup when leaving the game section entirely
 *
 * @example
 * ```typescript
 * // In tests
 * afterEach(() => {
 *   resetHackRunStore();
 * });
 * ```
 */
export function resetHackRunStore(): void {
	if (store) {
		store.cleanup();
		store = null;
	}
}
