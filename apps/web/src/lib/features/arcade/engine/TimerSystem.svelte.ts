/**
 * Timer System - Countdown & Clock Management
 * ============================================
 * Provides various timer utilities for arcade games:
 * - Countdowns (betting phase, pre-game, etc.)
 * - Game clocks (elapsed time tracking)
 * - Frame loops (smooth animations at 60fps)
 *
 * All timers clean up automatically when the store is destroyed.
 */

import type {
	TimerStatus,
	CountdownState,
	ClockState,
	CountdownConfig,
	ClockConfig,
} from '$lib/core/types/arcade';

// ============================================================================
// FORMATTING HELPERS
// ============================================================================

/**
 * Format milliseconds to MM:SS or SS.ms display
 */
export function formatTime(ms: number, showMilliseconds = false): string {
	const totalSeconds = Math.max(0, Math.ceil(ms / 1000));
	const minutes = Math.floor(totalSeconds / 60);
	const seconds = totalSeconds % 60;

	if (showMilliseconds && ms < 10000) {
		// Under 10 seconds, show SS.m
		const secs = Math.max(0, ms / 1000);
		return secs.toFixed(1);
	}

	if (minutes > 0) {
		return `${minutes}:${seconds.toString().padStart(2, '0')}`;
	}
	return seconds.toString();
}

/**
 * Format elapsed time to HH:MM:SS or MM:SS
 */
export function formatElapsed(ms: number): string {
	const totalSeconds = Math.floor(ms / 1000);
	const hours = Math.floor(totalSeconds / 3600);
	const minutes = Math.floor((totalSeconds % 3600) / 60);
	const seconds = totalSeconds % 60;

	if (hours > 0) {
		return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
	}
	return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
}

// ============================================================================
// COUNTDOWN TIMER
// ============================================================================

export interface Countdown {
	/** Current state (reactive) */
	readonly state: CountdownState;
	/** Start or restart the countdown */
	start(duration?: number): void;
	/** Pause the countdown */
	pause(): void;
	/** Resume a paused countdown */
	resume(): void;
	/** Stop and reset */
	stop(): void;
	/** Add time to the countdown */
	addTime(ms: number): void;
	/** Cleanup on destroy */
	cleanup(): void;
}

/**
 * Create a countdown timer.
 *
 * @example
 * ```typescript
 * const countdown = createCountdown({
 *   duration: 10000,
 *   onComplete: () => engine.transition('playing'),
 *   onTick: (remaining) => {
 *     if (remaining <= 3000) playSound('tick');
 *   },
 * });
 *
 * countdown.start();
 * ```
 */
export function createCountdown(config: CountdownConfig): Countdown {
	const {
		duration,
		interval = 100,
		criticalThreshold = 5000,
		showMilliseconds = false,
		onComplete,
		onTick,
	} = config;

	let state = $state<CountdownState>({
		status: 'idle',
		duration,
		remaining: duration,
		progress: 0,
		display: formatTime(duration, showMilliseconds),
		critical: false,
	});

	let intervalId: ReturnType<typeof setInterval> | null = null;
	let startTime = 0;
	let pausedRemaining = duration;

	function tick(): void {
		const elapsed = Date.now() - startTime;
		const remaining = Math.max(0, pausedRemaining - elapsed);
		const progress = 1 - remaining / state.duration;

		state = {
			...state,
			remaining,
			progress,
			display: formatTime(remaining, showMilliseconds),
			critical: remaining <= criticalThreshold && remaining > 0,
		};

		onTick?.(remaining);

		if (remaining <= 0) {
			complete();
		}
	}

	function complete(): void {
		clearIntervalTimer();
		state = {
			...state,
			status: 'complete',
			remaining: 0,
			progress: 1,
			display: formatTime(0, showMilliseconds),
			critical: false,
		};
		onComplete?.();
	}

	function clearIntervalTimer(): void {
		if (intervalId) {
			clearInterval(intervalId);
			intervalId = null;
		}
	}

	function start(newDuration?: number): void {
		clearIntervalTimer();

		const d = newDuration ?? duration;
		pausedRemaining = d;
		startTime = Date.now();

		state = {
			status: 'running',
			duration: d,
			remaining: d,
			progress: 0,
			display: formatTime(d, showMilliseconds),
			critical: d <= criticalThreshold,
		};

		intervalId = setInterval(tick, interval);
	}

	function pause(): void {
		if (state.status !== 'running') return;

		clearIntervalTimer();
		pausedRemaining = state.remaining;
		state = { ...state, status: 'paused' };
	}

	function resume(): void {
		if (state.status !== 'paused') return;

		startTime = Date.now();
		state = { ...state, status: 'running' };
		intervalId = setInterval(tick, interval);
	}

	function stop(): void {
		clearIntervalTimer();
		pausedRemaining = duration;
		state = {
			status: 'idle',
			duration,
			remaining: duration,
			progress: 0,
			display: formatTime(duration, showMilliseconds),
			critical: false,
		};
	}

	function addTime(ms: number): void {
		if (state.status === 'running') {
			pausedRemaining = state.remaining + ms;
			startTime = Date.now();
		} else if (state.status === 'paused') {
			pausedRemaining += ms;
		}
		state = {
			...state,
			remaining: state.remaining + ms,
			duration: state.duration + ms,
		};
	}

	function cleanup(): void {
		clearIntervalTimer();
	}

	return {
		get state() {
			return state;
		},
		start,
		pause,
		resume,
		stop,
		addTime,
		cleanup,
	};
}

// ============================================================================
// GAME CLOCK (ELAPSED TIME)
// ============================================================================

export interface Clock {
	/** Current state (reactive) */
	readonly state: ClockState;
	/** Start the clock */
	start(): void;
	/** Pause the clock */
	pause(): void;
	/** Resume the clock */
	resume(): void;
	/** Stop and reset */
	stop(): void;
	/** Get current elapsed time */
	getElapsed(): number;
	/** Cleanup on destroy */
	cleanup(): void;
}

/**
 * Create an elapsed time clock.
 *
 * @example
 * ```typescript
 * const clock = createClock({
 *   maxDuration: 60000, // 1 minute max
 *   onMaxReached: () => engine.transition('resolving'),
 * });
 *
 * clock.start();
 * // Later: clock.getElapsed() -> time in ms
 * ```
 */
export function createClock(config: ClockConfig = {}): Clock {
	const { interval = 100, maxDuration, onMaxReached } = config;

	let state = $state<ClockState>({
		status: 'idle',
		elapsed: 0,
		display: '00:00',
		startTime: 0,
	});

	let intervalId: ReturnType<typeof setInterval> | null = null;
	let pausedElapsed = 0;

	function tick(): void {
		const elapsed = pausedElapsed + (Date.now() - state.startTime);

		state = {
			...state,
			elapsed,
			display: formatElapsed(elapsed),
		};

		if (maxDuration && elapsed >= maxDuration) {
			stop();
			onMaxReached?.();
		}
	}

	function clearIntervalTimer(): void {
		if (intervalId) {
			clearInterval(intervalId);
			intervalId = null;
		}
	}

	function start(): void {
		clearIntervalTimer();
		pausedElapsed = 0;

		state = {
			status: 'running',
			elapsed: 0,
			display: '00:00',
			startTime: Date.now(),
		};

		intervalId = setInterval(tick, interval);
	}

	function pause(): void {
		if (state.status !== 'running') return;

		clearIntervalTimer();
		pausedElapsed = state.elapsed;
		state = { ...state, status: 'paused' };
	}

	function resume(): void {
		if (state.status !== 'paused') return;

		state = { ...state, status: 'running', startTime: Date.now() };
		intervalId = setInterval(tick, interval);
	}

	function stop(): void {
		clearIntervalTimer();
		pausedElapsed = 0;
		state = {
			status: 'idle',
			elapsed: 0,
			display: '00:00',
			startTime: 0,
		};
	}

	function getElapsed(): number {
		if (state.status === 'running') {
			return pausedElapsed + (Date.now() - state.startTime);
		}
		return pausedElapsed;
	}

	function cleanup(): void {
		clearIntervalTimer();
	}

	return {
		get state() {
			return state;
		},
		start,
		pause,
		resume,
		stop,
		getElapsed,
		cleanup,
	};
}

// ============================================================================
// ANIMATION FRAME LOOP
// ============================================================================

export interface FrameLoop {
	/** Whether loop is running */
	readonly running: boolean;
	/** Current frame timestamp */
	readonly frameTime: number;
	/** Delta since last frame (ms) */
	readonly delta: number;
	/** Start the loop */
	start(): void;
	/** Stop the loop */
	stop(): void;
}

/**
 * Create a requestAnimationFrame loop for smooth animations.
 *
 * @example
 * ```typescript
 * const loop = createFrameLoop((delta, time) => {
 *   multiplier += delta * growthRate;
 *   updateCurve();
 * });
 *
 * loop.start();
 * // Remember to call loop.stop() when done!
 * ```
 */
export function createFrameLoop(callback: (delta: number, time: number) => void): FrameLoop {
	let running = $state(false);
	let frameTime = $state(0);
	let delta = $state(0);
	let lastTime = 0;
	let rafId: number | null = null;

	function loop(time: number): void {
		if (!running) return;

		delta = lastTime ? time - lastTime : 0;
		lastTime = time;
		frameTime = time;

		callback(delta, time);

		rafId = requestAnimationFrame(loop);
	}

	function start(): void {
		if (running) return;
		running = true;
		lastTime = 0;
		rafId = requestAnimationFrame(loop);
	}

	function stop(): void {
		running = false;
		if (rafId) {
			cancelAnimationFrame(rafId);
			rafId = null;
		}
	}

	return {
		get running() {
			return running;
		},
		get frameTime() {
			return frameTime;
		},
		get delta() {
			return delta;
		},
		start,
		stop,
	};
}

// Re-export types for convenience
export type { TimerStatus, CountdownState, ClockState, CountdownConfig, ClockConfig };
