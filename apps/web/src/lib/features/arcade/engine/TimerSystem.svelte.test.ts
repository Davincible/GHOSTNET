/**
 * Timer System Tests
 * ==================
 * Tests for countdown, clock, and frame loop utilities.
 *
 * CRITICAL: File must have .svelte.test.ts extension for runes to work!
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import {
	createCountdown,
	createClock,
	createFrameLoop,
	formatTime,
	formatElapsed,
	type Countdown,
	type Clock,
	type FrameLoop,
} from './TimerSystem.svelte';

// ============================================================================
// FORMAT HELPERS TESTS
// ============================================================================

describe('formatTime', () => {
	it('formats seconds correctly', () => {
		expect(formatTime(5000)).toBe('5');
		expect(formatTime(15000)).toBe('15');
		expect(formatTime(59000)).toBe('59');
	});

	it('formats minutes:seconds correctly', () => {
		expect(formatTime(60000)).toBe('1:00');
		expect(formatTime(90000)).toBe('1:30');
		expect(formatTime(125000)).toBe('2:05');
	});

	it('handles zero', () => {
		expect(formatTime(0)).toBe('0');
	});

	it('handles negative values', () => {
		expect(formatTime(-1000)).toBe('0');
	});

	it('shows milliseconds when enabled and under 10 seconds', () => {
		expect(formatTime(5500, true)).toBe('5.5');
		expect(formatTime(9999, true)).toBe('10.0'); // Rounds up
	});

	it('hides milliseconds when over 10 seconds', () => {
		expect(formatTime(15000, true)).toBe('15');
	});
});

describe('formatElapsed', () => {
	it('formats mm:ss correctly', () => {
		expect(formatElapsed(0)).toBe('00:00');
		expect(formatElapsed(30000)).toBe('00:30');
		expect(formatElapsed(90000)).toBe('01:30');
	});

	it('formats hh:mm:ss correctly', () => {
		expect(formatElapsed(3600000)).toBe('1:00:00');
		expect(formatElapsed(3661000)).toBe('1:01:01');
		expect(formatElapsed(7325000)).toBe('2:02:05');
	});
});

// ============================================================================
// COUNTDOWN TESTS
// ============================================================================

describe('createCountdown', () => {
	let countdown: Countdown;

	beforeEach(() => {
		vi.useFakeTimers();
	});

	afterEach(() => {
		countdown?.cleanup();
		vi.restoreAllMocks();
	});

	describe('initial state', () => {
		it('starts in idle status', () => {
			countdown = createCountdown({ duration: 10000 });
			expect(countdown.state.status).toBe('idle');
		});

		it('has correct initial values', () => {
			countdown = createCountdown({ duration: 10000 });
			expect(countdown.state.duration).toBe(10000);
			expect(countdown.state.remaining).toBe(10000);
			expect(countdown.state.progress).toBe(0);
		});

		it('formats display correctly', () => {
			countdown = createCountdown({ duration: 65000 }); // 1:05
			expect(countdown.state.display).toBe('1:05');
		});
	});

	describe('start', () => {
		it('changes status to running', () => {
			countdown = createCountdown({ duration: 10000 });
			countdown.start();
			expect(countdown.state.status).toBe('running');
		});

		it('allows custom duration on start', () => {
			countdown = createCountdown({ duration: 10000 });
			countdown.start(5000);
			expect(countdown.state.duration).toBe(5000);
			expect(countdown.state.remaining).toBe(5000);
		});
	});

	describe('ticking', () => {
		it('decrements remaining time', () => {
			countdown = createCountdown({ duration: 10000, interval: 100 });
			countdown.start();

			vi.advanceTimersByTime(1000);

			expect(countdown.state.remaining).toBeLessThanOrEqual(9100);
			expect(countdown.state.remaining).toBeGreaterThanOrEqual(8900);
		});

		it('updates progress', () => {
			countdown = createCountdown({ duration: 10000, interval: 100 });
			countdown.start();

			vi.advanceTimersByTime(5000);

			expect(countdown.state.progress).toBeCloseTo(0.5, 1);
		});

		it('calls onTick callback', () => {
			const onTick = vi.fn();
			countdown = createCountdown({ duration: 10000, interval: 100, onTick });
			countdown.start();

			vi.advanceTimersByTime(500);

			expect(onTick).toHaveBeenCalled();
		});
	});

	describe('completion', () => {
		it('sets status to complete when done', () => {
			countdown = createCountdown({ duration: 1000, interval: 100 });
			countdown.start();

			vi.advanceTimersByTime(1100);

			expect(countdown.state.status).toBe('complete');
		});

		it('calls onComplete callback', () => {
			const onComplete = vi.fn();
			countdown = createCountdown({ duration: 1000, interval: 100, onComplete });
			countdown.start();

			vi.advanceTimersByTime(1100);

			expect(onComplete).toHaveBeenCalledTimes(1);
		});

		it('sets remaining to 0 and progress to 1', () => {
			countdown = createCountdown({ duration: 1000, interval: 100 });
			countdown.start();

			vi.advanceTimersByTime(1100);

			expect(countdown.state.remaining).toBe(0);
			expect(countdown.state.progress).toBe(1);
		});
	});

	describe('critical threshold', () => {
		it('sets critical flag when under threshold', () => {
			countdown = createCountdown({
				duration: 10000,
				interval: 100,
				criticalThreshold: 5000,
			});
			countdown.start();

			vi.advanceTimersByTime(6000);

			expect(countdown.state.critical).toBe(true);
		});

		it('critical is false when above threshold', () => {
			countdown = createCountdown({
				duration: 10000,
				interval: 100,
				criticalThreshold: 5000,
			});
			countdown.start();

			vi.advanceTimersByTime(1000);

			expect(countdown.state.critical).toBe(false);
		});

		it('critical is false when complete', () => {
			countdown = createCountdown({
				duration: 1000,
				interval: 100,
				criticalThreshold: 5000,
			});
			countdown.start();

			vi.advanceTimersByTime(1100);

			expect(countdown.state.critical).toBe(false);
		});
	});

	describe('pause/resume', () => {
		it('pause changes status to paused', () => {
			countdown = createCountdown({ duration: 10000 });
			countdown.start();
			countdown.pause();
			expect(countdown.state.status).toBe('paused');
		});

		it('pause preserves remaining time', () => {
			countdown = createCountdown({ duration: 10000, interval: 100 });
			countdown.start();

			vi.advanceTimersByTime(3000);
			countdown.pause();

			const pausedRemaining = countdown.state.remaining;
			vi.advanceTimersByTime(5000);

			expect(countdown.state.remaining).toBe(pausedRemaining);
		});

		it('resume continues countdown', () => {
			countdown = createCountdown({ duration: 10000, interval: 100 });
			countdown.start();

			vi.advanceTimersByTime(3000);
			countdown.pause();
			countdown.resume();

			expect(countdown.state.status).toBe('running');

			vi.advanceTimersByTime(3000);
			expect(countdown.state.remaining).toBeLessThan(5000);
		});

		it('pause does nothing when not running', () => {
			countdown = createCountdown({ duration: 10000 });
			countdown.pause();
			expect(countdown.state.status).toBe('idle');
		});

		it('resume does nothing when not paused', () => {
			countdown = createCountdown({ duration: 10000 });
			countdown.resume();
			expect(countdown.state.status).toBe('idle');
		});
	});

	describe('stop', () => {
		it('resets to idle state', () => {
			countdown = createCountdown({ duration: 10000, interval: 100 });
			countdown.start();

			vi.advanceTimersByTime(5000);
			countdown.stop();

			expect(countdown.state.status).toBe('idle');
			expect(countdown.state.remaining).toBe(10000);
			expect(countdown.state.progress).toBe(0);
		});
	});

	describe('addTime', () => {
		it('adds time while running', () => {
			countdown = createCountdown({ duration: 10000, interval: 100 });
			countdown.start();

			vi.advanceTimersByTime(5000);
			const before = countdown.state.remaining;

			countdown.addTime(3000);

			expect(countdown.state.remaining).toBeGreaterThan(before);
		});

		it('adds time while paused', () => {
			countdown = createCountdown({ duration: 10000, interval: 100 });
			countdown.start();

			vi.advanceTimersByTime(5000);
			countdown.pause();
			const before = countdown.state.remaining;

			countdown.addTime(3000);

			expect(countdown.state.remaining).toBe(before + 3000);
		});
	});
});

// ============================================================================
// CLOCK TESTS
// ============================================================================

describe('createClock', () => {
	let clock: Clock;

	beforeEach(() => {
		vi.useFakeTimers();
	});

	afterEach(() => {
		clock?.cleanup();
		vi.restoreAllMocks();
	});

	describe('initial state', () => {
		it('starts in idle status', () => {
			clock = createClock();
			expect(clock.state.status).toBe('idle');
		});

		it('starts with zero elapsed', () => {
			clock = createClock();
			expect(clock.state.elapsed).toBe(0);
			expect(clock.state.display).toBe('00:00');
		});
	});

	describe('start', () => {
		it('changes status to running', () => {
			clock = createClock();
			clock.start();
			expect(clock.state.status).toBe('running');
		});
	});

	describe('ticking', () => {
		it('increments elapsed time', () => {
			clock = createClock({ interval: 100 });
			clock.start();

			vi.advanceTimersByTime(2000);

			expect(clock.state.elapsed).toBeGreaterThanOrEqual(1900);
			expect(clock.state.elapsed).toBeLessThanOrEqual(2100);
		});

		it('updates display', () => {
			clock = createClock({ interval: 100 });
			clock.start();

			vi.advanceTimersByTime(65000);

			expect(clock.state.display).toBe('01:05');
		});
	});

	describe('max duration', () => {
		it('stops at max duration', () => {
			clock = createClock({ maxDuration: 5000, interval: 100 });
			clock.start();

			vi.advanceTimersByTime(10000);

			expect(clock.state.status).toBe('idle');
		});

		it('calls onMaxReached callback', () => {
			const onMaxReached = vi.fn();
			clock = createClock({ maxDuration: 5000, interval: 100, onMaxReached });
			clock.start();

			vi.advanceTimersByTime(5100);

			expect(onMaxReached).toHaveBeenCalledTimes(1);
		});
	});

	describe('pause/resume', () => {
		it('pause preserves elapsed time', () => {
			clock = createClock({ interval: 100 });
			clock.start();

			vi.advanceTimersByTime(3000);
			clock.pause();

			const pausedElapsed = clock.state.elapsed;
			vi.advanceTimersByTime(5000);

			expect(clock.state.elapsed).toBe(pausedElapsed);
		});

		it('resume continues counting', () => {
			clock = createClock({ interval: 100 });
			clock.start();

			vi.advanceTimersByTime(3000);
			clock.pause();
			clock.resume();

			vi.advanceTimersByTime(2000);

			expect(clock.state.elapsed).toBeGreaterThan(4000);
		});
	});

	describe('getElapsed', () => {
		it('returns current elapsed while running', () => {
			clock = createClock({ interval: 100 });
			clock.start();

			vi.advanceTimersByTime(2000);

			expect(clock.getElapsed()).toBeGreaterThanOrEqual(1900);
		});

		it('returns paused elapsed when paused', () => {
			clock = createClock({ interval: 100 });
			clock.start();

			vi.advanceTimersByTime(3000);
			clock.pause();

			const elapsed = clock.getElapsed();
			vi.advanceTimersByTime(5000);

			expect(clock.getElapsed()).toBe(elapsed);
		});
	});

	describe('stop', () => {
		it('resets to idle state', () => {
			clock = createClock({ interval: 100 });
			clock.start();

			vi.advanceTimersByTime(5000);
			clock.stop();

			expect(clock.state.status).toBe('idle');
			expect(clock.state.elapsed).toBe(0);
		});
	});
});

// ============================================================================
// FRAME LOOP TESTS
// ============================================================================

describe('createFrameLoop', () => {
	let loop: FrameLoop;

	beforeEach(() => {
		vi.useFakeTimers();
		// Mock requestAnimationFrame
		let rafId = 0;
		vi.stubGlobal('requestAnimationFrame', (cb: FrameRequestCallback) => {
			rafId++;
			setTimeout(() => cb(performance.now()), 16); // ~60fps
			return rafId;
		});
		vi.stubGlobal('cancelAnimationFrame', (id: number) => {
			// No-op in tests
		});
	});

	afterEach(() => {
		loop?.stop();
		vi.restoreAllMocks();
	});

	it('starts in stopped state', () => {
		const callback = vi.fn();
		loop = createFrameLoop(callback);
		expect(loop.running).toBe(false);
	});

	it('starts running when start() called', () => {
		const callback = vi.fn();
		loop = createFrameLoop(callback);
		loop.start();
		expect(loop.running).toBe(true);
	});

	it('stops when stop() called', () => {
		const callback = vi.fn();
		loop = createFrameLoop(callback);
		loop.start();
		loop.stop();
		expect(loop.running).toBe(false);
	});

	it('calls callback on each frame', () => {
		const callback = vi.fn();
		loop = createFrameLoop(callback);
		loop.start();

		vi.advanceTimersByTime(50); // ~3 frames

		expect(callback).toHaveBeenCalled();
	});

	it('provides delta time to callback', () => {
		const callback = vi.fn();
		loop = createFrameLoop(callback);
		loop.start();

		vi.advanceTimersByTime(50);

		// Delta should be provided (will be 0 on first frame)
		expect(callback).toHaveBeenCalledWith(expect.any(Number), expect.any(Number));
	});

	it('does not call callback after stop', () => {
		const callback = vi.fn();
		loop = createFrameLoop(callback);
		loop.start();

		vi.advanceTimersByTime(16);
		const callCount = callback.mock.calls.length;

		loop.stop();
		vi.advanceTimersByTime(100);

		expect(callback.mock.calls.length).toBe(callCount);
	});

	it('can be restarted', () => {
		const callback = vi.fn();
		loop = createFrameLoop(callback);

		loop.start();
		vi.advanceTimersByTime(32);
		loop.stop();

		const callsAfterStop = callback.mock.calls.length;

		loop.start();
		vi.advanceTimersByTime(32);

		expect(callback.mock.calls.length).toBeGreaterThan(callsAfterStop);
	});
});
