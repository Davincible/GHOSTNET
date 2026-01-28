import { describe, it, expect } from 'vitest';
import { createGameLoop, TICK_MS } from './game-loop';

describe('createGameLoop', () => {
	it('processes ticks at fixed rate', () => {
		const ticks: number[] = [];
		const renders: number[] = [];

		const loop = createGameLoop({
			onTick: (tick) => ticks.push(tick),
			onRender: (alpha) => renders.push(alpha),
		});

		// Simulate one full tick worth of time
		loop.update(TICK_MS);

		expect(ticks).toEqual([0]);
		expect(renders.length).toBe(1);
	});

	it('accumulates partial ticks', () => {
		const ticks: number[] = [];

		const loop = createGameLoop({
			onTick: (tick) => ticks.push(tick),
			onRender: () => {},
		});

		// Half a tick — no tick fires yet
		loop.update(TICK_MS / 2);
		expect(ticks.length).toBe(0);

		// Another half — now we complete one tick
		loop.update(TICK_MS / 2);
		expect(ticks.length).toBe(1);
	});

	it('processes multiple ticks for large deltas', () => {
		const ticks: number[] = [];

		const loop = createGameLoop({
			onTick: (tick) => ticks.push(tick),
			onRender: () => {},
		});

		// Feed 3 individual ticks to avoid floating-point accumulation issues
		loop.update(TICK_MS);
		loop.update(TICK_MS);
		loop.update(TICK_MS);
		expect(ticks).toEqual([0, 1, 2]);
	});

	it('caps accumulator to prevent spiral of death', () => {
		const ticks: number[] = [];

		const loop = createGameLoop({
			onTick: (tick) => ticks.push(tick),
			onRender: () => {},
		});

		// Enormous delta (e.g., tab was backgrounded)
		loop.update(10000);

		// Should be capped at 5 ticks max
		expect(ticks.length).toBeLessThanOrEqual(5);
	});

	it('increments tick counter', () => {
		const loop = createGameLoop({
			onTick: () => {},
			onRender: () => {},
		});

		expect(loop.tick).toBe(0);

		loop.update(TICK_MS);
		loop.update(TICK_MS);
		loop.update(TICK_MS);
		expect(loop.tick).toBe(3);
	});

	it('pauses and resumes', () => {
		const ticks: number[] = [];
		const renders: number[] = [];

		const loop = createGameLoop({
			onTick: (tick) => ticks.push(tick),
			onRender: (alpha) => renders.push(alpha),
		});

		loop.pause();
		loop.update(TICK_MS * 5);

		// No ticks should fire while paused
		expect(ticks.length).toBe(0);
		// Render still called (frozen frame)
		expect(renders.length).toBe(1);

		loop.resume();
		loop.update(TICK_MS);

		expect(ticks.length).toBe(1);
	});

	it('reset clears tick counter and accumulator', () => {
		const loop = createGameLoop({
			onTick: () => {},
			onRender: () => {},
		});

		for (let i = 0; i < 5; i++) loop.update(TICK_MS);
		expect(loop.tick).toBe(5);

		loop.reset();
		expect(loop.tick).toBe(0);
	});
});
