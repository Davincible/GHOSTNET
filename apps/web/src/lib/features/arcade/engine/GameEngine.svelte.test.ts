/**
 * Game Engine Tests
 * =================
 * Tests for the arcade game engine FSM.
 *
 * CRITICAL: File must have .svelte.test.ts extension for runes to work!
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { createGameEngine, type GameEngine, type GameEngineConfig } from './GameEngine.svelte';

// ============================================================================
// TEST FIXTURES
// ============================================================================

type TestPhase = 'idle' | 'betting' | 'playing' | 'resolving' | 'complete';

function createTestConfig(
	overrides: Partial<GameEngineConfig<TestPhase>> = {}
): GameEngineConfig<TestPhase> {
	return {
		initialPhase: 'idle',
		phases: [
			{ phase: 'idle' },
			{ phase: 'betting' },
			{ phase: 'playing' },
			{ phase: 'resolving' },
			{ phase: 'complete' },
		],
		transitions: {
			idle: ['betting'],
			betting: ['playing', 'idle'],
			playing: ['resolving'],
			resolving: ['complete'],
			complete: ['idle'],
		},
		...overrides,
	};
}

// ============================================================================
// BASIC STATE MACHINE TESTS
// ============================================================================

describe('createGameEngine', () => {
	let engine: GameEngine<TestPhase>;

	beforeEach(() => {
		vi.useFakeTimers();
	});

	afterEach(() => {
		engine?.cleanup();
		vi.restoreAllMocks();
	});

	describe('initial state', () => {
		it('starts in the initial phase', () => {
			engine = createGameEngine(createTestConfig());
			expect(engine.phase).toBe('idle');
			expect(engine.state.phase).toBe('idle');
		});

		it('respects custom initial phase', () => {
			engine = createGameEngine(createTestConfig({ initialPhase: 'betting' }));
			expect(engine.phase).toBe('betting');
		});

		it('has empty history initially', () => {
			engine = createGameEngine(createTestConfig());
			expect(engine.state.history).toHaveLength(0);
		});

		it('is not transitioning initially', () => {
			engine = createGameEngine(createTestConfig());
			expect(engine.state.transitioning).toBe(false);
		});

		it('has no error initially', () => {
			engine = createGameEngine(createTestConfig());
			expect(engine.state.error).toBeNull();
		});

		it('has null previousPhase initially', () => {
			engine = createGameEngine(createTestConfig());
			expect(engine.state.previousPhase).toBeNull();
		});
	});

	describe('isPhase', () => {
		it('returns true for current phase', () => {
			engine = createGameEngine(createTestConfig());
			expect(engine.isPhase('idle')).toBe(true);
		});

		it('returns false for other phases', () => {
			engine = createGameEngine(createTestConfig());
			expect(engine.isPhase('betting')).toBe(false);
			expect(engine.isPhase('playing')).toBe(false);
		});
	});

	describe('phaseElapsed', () => {
		it('returns time since phase started', () => {
			engine = createGameEngine(createTestConfig());

			vi.advanceTimersByTime(1000);
			expect(engine.phaseElapsed).toBeGreaterThanOrEqual(1000);
		});
	});
});

// ============================================================================
// TRANSITION TESTS
// ============================================================================

describe('transitions', () => {
	let engine: GameEngine<TestPhase>;

	beforeEach(() => {
		vi.useFakeTimers();
		engine = createGameEngine(createTestConfig());
	});

	afterEach(() => {
		engine?.cleanup();
		vi.restoreAllMocks();
	});

	describe('valid transitions', () => {
		it('allows valid transitions', async () => {
			const result = await engine.transition('betting');
			expect(result).toBe(true);
			expect(engine.phase).toBe('betting');
		});

		it('updates previousPhase on transition', async () => {
			await engine.transition('betting');
			expect(engine.state.previousPhase).toBe('idle');
		});

		it('records transition in history', async () => {
			await engine.transition('betting');
			expect(engine.state.history).toHaveLength(1);
			expect(engine.state.history[0].from).toBe('idle');
			expect(engine.state.history[0].to).toBe('betting');
		});

		it('includes data in transition record', async () => {
			await engine.transition('betting', { roundId: 123 });
			expect(engine.state.history[0].data).toEqual({ roundId: 123 });
		});

		it('resets phaseStartTime on transition', async () => {
			vi.advanceTimersByTime(1000);
			const beforeTransition = engine.state.phaseStartTime;

			await engine.transition('betting');

			expect(engine.state.phaseStartTime).toBeGreaterThan(beforeTransition);
		});
	});

	describe('invalid transitions', () => {
		it('rejects invalid transitions', async () => {
			const result = await engine.transition('playing'); // idle -> playing not allowed
			expect(result).toBe(false);
			expect(engine.phase).toBe('idle');
		});

		it('does not record invalid transitions', async () => {
			await engine.transition('playing');
			expect(engine.state.history).toHaveLength(0);
		});
	});

	describe('concurrent transitions', () => {
		it('blocks concurrent transitions while transitioning flag is set', async () => {
			// The transitioning flag is set synchronously at the start of transition()
			// So we can test this by checking that a second call while transitioning returns false

			let resolveEnter: () => void = () => {};
			const enterPromise = new Promise<void>((resolve) => {
				resolveEnter = resolve;
			});

			engine = createGameEngine(
				createTestConfig({
					phases: [
						{ phase: 'idle' },
						{
							phase: 'betting',
							onEnter: () => enterPromise,
						},
						{ phase: 'playing' },
						{ phase: 'resolving' },
						{ phase: 'complete' },
					],
				})
			);

			// Start first transition (will be blocked on enterPromise)
			const firstTransition = engine.transition('betting');

			// Immediately try second transition - should be blocked because transitioning is true
			const secondResult = await engine.transition('betting');
			expect(secondResult).toBe(false);

			// Complete the first transition
			resolveEnter();
			const firstResult = await firstTransition;

			expect(firstResult).toBe(true);
			expect(engine.phase).toBe('betting');
		});
	});
});

// ============================================================================
// PHASE CALLBACKS TESTS
// ============================================================================

describe('phase callbacks', () => {
	let engine: GameEngine<TestPhase>;
	let onEnterBetting: ReturnType<typeof vi.fn<() => void>>;
	let onExitIdle: ReturnType<typeof vi.fn<() => void>>;

	beforeEach(() => {
		vi.useFakeTimers();
		onEnterBetting = vi.fn<() => void>();
		onExitIdle = vi.fn<() => void>();

		engine = createGameEngine(
			createTestConfig({
				phases: [
					{ phase: 'idle', onExit: onExitIdle },
					{ phase: 'betting', onEnter: onEnterBetting },
					{ phase: 'playing' },
					{ phase: 'resolving' },
					{ phase: 'complete' },
				],
			})
		);
	});

	afterEach(() => {
		engine?.cleanup();
		vi.restoreAllMocks();
	});

	it('calls onExit when leaving a phase', async () => {
		await engine.transition('betting');
		expect(onExitIdle).toHaveBeenCalledTimes(1);
	});

	it('calls onEnter when entering a phase', async () => {
		await engine.transition('betting');
		expect(onEnterBetting).toHaveBeenCalledTimes(1);
	});

	it('calls onExit before onEnter', async () => {
		const callOrder: string[] = [];
		onExitIdle.mockImplementation(() => callOrder.push('exit'));
		onEnterBetting.mockImplementation(() => callOrder.push('enter'));

		await engine.transition('betting');
		expect(callOrder).toEqual(['exit', 'enter']);
	});

	it('handles async callbacks', async () => {
		let asyncCompleted = false;
		engine = createGameEngine(
			createTestConfig({
				phases: [
					{ phase: 'idle' },
					{
						phase: 'betting',
						onEnter: async () => {
							await new Promise((resolve) => setTimeout(resolve, 50));
							asyncCompleted = true;
						},
					},
					{ phase: 'playing' },
					{ phase: 'resolving' },
					{ phase: 'complete' },
				],
			})
		);

		const promise = engine.transition('betting');
		expect(asyncCompleted).toBe(false);

		vi.advanceTimersByTime(50);
		await promise;

		expect(asyncCompleted).toBe(true);
	});
});

// ============================================================================
// GUARDS TESTS
// ============================================================================

describe('guards', () => {
	let engine: GameEngine<TestPhase>;

	beforeEach(() => {
		vi.useFakeTimers();
	});

	afterEach(() => {
		engine?.cleanup();
		vi.restoreAllMocks();
	});

	it('blocks transition when guard returns false', async () => {
		engine = createGameEngine(
			createTestConfig({
				phases: [
					{ phase: 'idle' },
					{ phase: 'betting', canEnter: () => false },
					{ phase: 'playing' },
					{ phase: 'resolving' },
					{ phase: 'complete' },
				],
			})
		);

		const result = await engine.transition('betting');
		expect(result).toBe(false);
		expect(engine.phase).toBe('idle');
	});

	it('allows transition when guard returns true', async () => {
		engine = createGameEngine(
			createTestConfig({
				phases: [
					{ phase: 'idle' },
					{ phase: 'betting', canEnter: () => true },
					{ phase: 'playing' },
					{ phase: 'resolving' },
					{ phase: 'complete' },
				],
			})
		);

		const result = await engine.transition('betting');
		expect(result).toBe(true);
		expect(engine.phase).toBe('betting');
	});

	it('guard can use external state', async () => {
		let canEnter = false;

		engine = createGameEngine(
			createTestConfig({
				phases: [
					{ phase: 'idle' },
					{ phase: 'betting', canEnter: () => canEnter },
					{ phase: 'playing' },
					{ phase: 'resolving' },
					{ phase: 'complete' },
				],
			})
		);

		expect(await engine.transition('betting')).toBe(false);

		canEnter = true;
		expect(await engine.transition('betting')).toBe(true);
	});
});

// ============================================================================
// TIMEOUT TESTS
// ============================================================================

describe('phase timeouts', () => {
	let engine: GameEngine<TestPhase>;

	beforeEach(() => {
		vi.useFakeTimers();
	});

	afterEach(() => {
		engine?.cleanup();
		vi.restoreAllMocks();
	});

	it('auto-transitions after timeout', async () => {
		engine = createGameEngine(
			createTestConfig({
				phases: [
					{ phase: 'idle' },
					{ phase: 'betting', timeout: 5000, timeoutTarget: 'playing' },
					{ phase: 'playing' },
					{ phase: 'resolving' },
					{ phase: 'complete' },
				],
			})
		);

		await engine.transition('betting');
		expect(engine.phase).toBe('betting');

		vi.advanceTimersByTime(5000);
		await vi.runAllTimersAsync();

		expect(engine.phase).toBe('playing');
	});

	it('clears timeout when transitioning manually', async () => {
		engine = createGameEngine(
			createTestConfig({
				phases: [
					{ phase: 'idle' },
					{ phase: 'betting', timeout: 5000, timeoutTarget: 'idle' },
					{ phase: 'playing' },
					{ phase: 'resolving' },
					{ phase: 'complete' },
				],
			})
		);

		await engine.transition('betting');
		await engine.transition('playing');

		vi.advanceTimersByTime(10000);
		await vi.runAllTimersAsync();

		expect(engine.phase).toBe('playing'); // Not idle
	});
});

// ============================================================================
// ERROR HANDLING TESTS
// ============================================================================

describe('error handling', () => {
	let engine: GameEngine<TestPhase>;
	let onError: ReturnType<typeof vi.fn<(error: Error, phase: TestPhase) => void>>;

	beforeEach(() => {
		vi.useFakeTimers();
		onError = vi.fn<(error: Error, phase: TestPhase) => void>();
	});

	afterEach(() => {
		engine?.cleanup();
		vi.restoreAllMocks();
	});

	it('catches errors in callbacks and sets error state', async () => {
		engine = createGameEngine(
			createTestConfig({
				phases: [
					{ phase: 'idle' },
					{
						phase: 'betting',
						onEnter: () => {
							throw new Error('Test error');
						},
					},
					{ phase: 'playing' },
					{ phase: 'resolving' },
					{ phase: 'complete' },
				],
				onError,
			})
		);

		const result = await engine.transition('betting');
		expect(result).toBe(false);
		expect(engine.state.error).toBeInstanceOf(Error);
		expect(engine.state.error?.message).toBe('Test error');
	});

	it('calls onError handler', async () => {
		engine = createGameEngine(
			createTestConfig({
				phases: [
					{ phase: 'idle' },
					{
						phase: 'betting',
						onEnter: () => {
							throw new Error('Test error');
						},
					},
					{ phase: 'playing' },
					{ phase: 'resolving' },
					{ phase: 'complete' },
				],
				onError,
			})
		);

		await engine.transition('betting');
		expect(onError).toHaveBeenCalledWith(expect.any(Error), 'idle');
	});
});

// ============================================================================
// RESET TESTS
// ============================================================================

describe('reset', () => {
	let engine: GameEngine<TestPhase>;

	beforeEach(() => {
		vi.useFakeTimers();
		engine = createGameEngine(createTestConfig());
	});

	afterEach(() => {
		engine?.cleanup();
		vi.restoreAllMocks();
	});

	it('returns to initial phase', async () => {
		await engine.transition('betting');
		await engine.transition('playing');

		engine.reset();

		expect(engine.phase).toBe('idle');
	});

	it('clears history', async () => {
		await engine.transition('betting');
		expect(engine.state.history).toHaveLength(1);

		engine.reset();

		expect(engine.state.history).toHaveLength(0);
	});

	it('clears error', async () => {
		engine = createGameEngine(
			createTestConfig({
				phases: [
					{ phase: 'idle' },
					{
						phase: 'betting',
						onEnter: () => {
							throw new Error('Test');
						},
					},
					{ phase: 'playing' },
					{ phase: 'resolving' },
					{ phase: 'complete' },
				],
			})
		);

		await engine.transition('betting');
		expect(engine.state.error).not.toBeNull();

		engine.reset();

		expect(engine.state.error).toBeNull();
	});

	it('clears pending timeouts', async () => {
		engine = createGameEngine(
			createTestConfig({
				phases: [
					{ phase: 'idle' },
					{ phase: 'betting', timeout: 5000, timeoutTarget: 'playing' },
					{ phase: 'playing' },
					{ phase: 'resolving' },
					{ phase: 'complete' },
				],
			})
		);

		await engine.transition('betting');
		engine.reset();

		vi.advanceTimersByTime(10000);

		expect(engine.phase).toBe('idle');
	});
});

// ============================================================================
// HISTORY LIMIT TESTS
// ============================================================================

describe('history limit', () => {
	beforeEach(() => {
		vi.useFakeTimers();
	});

	afterEach(() => {
		vi.restoreAllMocks();
	});

	it('limits history to 20 entries', async () => {
		// Create config that allows cycling
		type CyclePhase = 'a' | 'b';
		const cycleEngine = createGameEngine<CyclePhase>({
			initialPhase: 'a',
			phases: [{ phase: 'a' }, { phase: 'b' }],
			transitions: {
				a: ['b'],
				b: ['a'],
			},
		});

		// Make 30 transitions
		for (let i = 0; i < 30; i++) {
			const target = i % 2 === 0 ? 'b' : 'a';
			await cycleEngine.transition(target);
		}

		expect(cycleEngine.state.history.length).toBeLessThanOrEqual(20);
		cycleEngine.cleanup();
	});
});
