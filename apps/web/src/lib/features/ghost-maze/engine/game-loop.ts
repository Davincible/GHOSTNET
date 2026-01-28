/**
 * Fixed-Timestep Game Loop
 * =========================
 * Separates logic (fixed 15 ticks/sec) from rendering (variable 60fps).
 * Deterministic: same inputs at same ticks produce same game state.
 * Critical for replay verification.
 *
 * This is a pure game loop — no Svelte dependencies.
 * Use `createFrameLoop` from the arcade engine for the RAF wrapper;
 * this module handles the fixed-timestep accumulator inside that loop.
 */

import { TICK_RATE, TICK_MS } from '../constants';

// ============================================================================
// TYPES
// ============================================================================

export interface GameLoopCallbacks {
	/** Called at fixed rate for game logic. Receives current tick number. */
	onTick: (tick: number) => void;
	/** Called every frame for rendering. Receives interpolation alpha (0-1). */
	onRender: (alpha: number) => void;
}

export interface GameLoop {
	/** Process a frame delta (call from requestAnimationFrame). */
	update(deltaMs: number): void;
	/** Current tick count */
	readonly tick: number;
	/** Reset tick counter and accumulator */
	reset(): void;
	/** Pause the loop (stops tick processing but not frame callbacks) */
	pause(): void;
	/** Resume after pause */
	resume(): void;
	/** Whether paused */
	readonly paused: boolean;
}

// ============================================================================
// FACTORY
// ============================================================================

/**
 * Create a fixed-timestep game loop.
 *
 * Usage with the arcade engine's frame loop:
 * ```typescript
 * const gameLoop = createGameLoop({
 *   onTick: (tick) => { /* game logic at 15fps *\/ },
 *   onRender: (alpha) => { /* smooth rendering at 60fps *\/ },
 * });
 *
 * const frameLoop = createFrameLoop((delta) => {
 *   gameLoop.update(delta);
 * });
 * ```
 */
export function createGameLoop(callbacks: GameLoopCallbacks): GameLoop {
	let accumulator = 0;
	let tick = 0;
	let paused = false;

	// Cap max accumulated time to prevent spiral of death
	// (if a frame takes very long, don't try to catch up with 100 ticks)
	const MAX_ACCUMULATOR = TICK_MS * 5;

	function update(deltaMs: number): void {
		if (paused) {
			// Still call render but with 0 alpha (frozen frame)
			callbacks.onRender(0);
			return;
		}

		accumulator += deltaMs;

		// Cap to prevent spiral of death
		if (accumulator > MAX_ACCUMULATOR) {
			accumulator = MAX_ACCUMULATOR;
		}

		// Process fixed-timestep ticks
		while (accumulator >= TICK_MS) {
			callbacks.onTick(tick);
			tick++;
			accumulator -= TICK_MS;
		}

		// Render with interpolation alpha
		callbacks.onRender(accumulator / TICK_MS);
	}

	function reset(): void {
		accumulator = 0;
		tick = 0;
		paused = false;
	}

	function pause(): void {
		paused = true;
	}

	function resume(): void {
		paused = false;
		// Reset accumulator to prevent tick burst on resume
		accumulator = 0;
	}

	return {
		update,
		get tick() {
			return tick;
		},
		reset,
		pause,
		resume,
		get paused() {
			return paused;
		},
	};
}

// Re-export constants for convenience
export { TICK_RATE, TICK_MS };
