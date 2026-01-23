/**
 * Game Engine - Core State Machine
 * =================================
 * Provides phase management for all arcade games.
 *
 * Standard Flow: idle -> betting -> playing -> resolving -> complete
 *
 * Games extend this by:
 * 1. Adding custom phases (e.g., 'countdown', 'matching')
 * 2. Adding transition guards
 * 3. Hooking into phase callbacks
 */

import type {
	StandardPhase,
	PhaseTransition,
	PhaseConfig,
	GameEngineConfig,
	GameEngineState,
} from '$lib/core/types/arcade';

// ============================================================================
// STORE INTERFACE
// ============================================================================

export interface GameEngine<TPhase extends string = StandardPhase> {
	/** Current engine state (reactive) */
	readonly state: GameEngineState<TPhase>;
	/** Current phase (convenience getter) */
	readonly phase: TPhase;
	/** Time spent in current phase (ms) */
	readonly phaseElapsed: number;
	/** Whether in a specific phase */
	isPhase(phase: TPhase): boolean;
	/** Transition to a new phase */
	transition(to: TPhase, data?: Record<string, unknown>): Promise<boolean>;
	/** Reset to initial state */
	reset(): void;
	/** Cleanup timers on destroy */
	cleanup(): void;
}

// ============================================================================
// STORE FACTORY
// ============================================================================

/** Maximum number of transitions to keep in history */
const MAX_HISTORY_SIZE = 20;

/**
 * Create a game engine instance with custom phases and transitions.
 *
 * @example
 * ```typescript
 * type CrashPhase = 'idle' | 'betting' | 'rising' | 'crashed' | 'settling';
 *
 * const engine = createGameEngine<CrashPhase>({
 *   initialPhase: 'idle',
 *   phases: [
 *     { phase: 'betting', timeout: 10000, timeoutTarget: 'rising' },
 *     { phase: 'rising', onEnter: () => startMultiplier() },
 *     { phase: 'crashed', onEnter: () => playSound('crash') },
 *   ],
 *   transitions: {
 *     idle: ['betting'],
 *     betting: ['rising', 'idle'],
 *     rising: ['crashed'],
 *     crashed: ['settling'],
 *     settling: ['betting', 'idle'],
 *   },
 * });
 * ```
 */
export function createGameEngine<TPhase extends string = StandardPhase>(
	config: GameEngineConfig<TPhase>
): GameEngine<TPhase> {
	// -------------------------------------------------------------------------
	// STATE
	// -------------------------------------------------------------------------

	const initialPhase = config.initialPhase ?? ('idle' as TPhase);

	let state = $state<GameEngineState<TPhase>>({
		phase: initialPhase,
		previousPhase: null,
		phaseStartTime: Date.now(),
		transitioning: false,
		error: null,
		history: [],
	});

	// Phase timeout timer
	let timeoutId: ReturnType<typeof setTimeout> | null = null;

	// Phase config lookup
	const phaseConfigs = new Map<TPhase, PhaseConfig<TPhase>>();
	for (const pc of config.phases) {
		phaseConfigs.set(pc.phase, pc);
	}

	// -------------------------------------------------------------------------
	// DERIVED STATE
	// -------------------------------------------------------------------------

	// Note: phaseElapsed is computed on access, not continuously
	// For continuous updates, use TimerSystem

	// -------------------------------------------------------------------------
	// HELPERS
	// -------------------------------------------------------------------------

	function clearPhaseTimeout(): void {
		if (timeoutId) {
			clearTimeout(timeoutId);
			timeoutId = null;
		}
	}

	function setupPhaseTimeout(phaseConfig: PhaseConfig<TPhase>): void {
		if (phaseConfig.timeout && phaseConfig.timeoutTarget) {
			timeoutId = setTimeout(() => {
				void transition(phaseConfig.timeoutTarget!);
			}, phaseConfig.timeout);
		}
	}

	function isValidTransition(from: TPhase, to: TPhase): boolean {
		const allowed = config.transitions[from];
		return allowed?.includes(to) ?? false;
	}

	// -------------------------------------------------------------------------
	// TRANSITIONS
	// -------------------------------------------------------------------------

	async function transition(to: TPhase, data?: Record<string, unknown>): Promise<boolean> {
		const from = state.phase;

		// Prevent concurrent transitions
		if (state.transitioning) {
			console.warn(`[GameEngine] Transition blocked: already transitioning`);
			return false;
		}

		// Validate transition
		if (!isValidTransition(from, to)) {
			console.warn(`[GameEngine] Invalid transition: ${from} -> ${to}`);
			return false;
		}

		// Check entry guard
		const targetConfig = phaseConfigs.get(to);
		if (targetConfig?.canEnter && !targetConfig.canEnter()) {
			console.warn(`[GameEngine] Guard blocked transition to: ${to}`);
			return false;
		}

		state = { ...state, transitioning: true };

		try {
			// Exit current phase
			clearPhaseTimeout();
			const currentConfig = phaseConfigs.get(from);
			if (currentConfig?.onExit) {
				await currentConfig.onExit();
			}

			// Record transition
			const transitionRecord: PhaseTransition<TPhase> = {
				from,
				to,
				timestamp: Date.now(),
				data,
			};

			// Update state
			state = {
				phase: to,
				previousPhase: from,
				phaseStartTime: Date.now(),
				transitioning: false,
				error: null,
				history: [...state.history.slice(-(MAX_HISTORY_SIZE - 1)), transitionRecord],
			};

			// Enter new phase
			if (targetConfig?.onEnter) {
				await targetConfig.onEnter();
			}

			// Setup timeout for new phase
			if (targetConfig) {
				setupPhaseTimeout(targetConfig);
			}

			return true;
		} catch (error) {
			const err = error instanceof Error ? error : new Error(String(error));
			state = { ...state, transitioning: false, error: err };
			config.onError?.(err, from);
			return false;
		}
	}

	// -------------------------------------------------------------------------
	// PUBLIC API
	// -------------------------------------------------------------------------

	function isPhase(phase: TPhase): boolean {
		return state.phase === phase;
	}

	function reset(): void {
		clearPhaseTimeout();
		state = {
			phase: initialPhase,
			previousPhase: null,
			phaseStartTime: Date.now(),
			transitioning: false,
			error: null,
			history: [],
		};
	}

	function cleanup(): void {
		clearPhaseTimeout();
	}

	return {
		get state() {
			return state;
		},
		get phase() {
			return state.phase;
		},
		get phaseElapsed() {
			return Date.now() - state.phaseStartTime;
		},
		isPhase,
		transition,
		reset,
		cleanup,
	};
}

// Re-export types for convenience
export type {
	StandardPhase,
	PhaseTransition,
	PhaseConfig,
	GameEngineConfig,
	GameEngineState,
} from '$lib/core/types/arcade';
