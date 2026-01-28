import { describe, it, expect } from 'vitest';
import { createInputHandler } from './input';

describe('createInputHandler', () => {
	it('starts with no input', () => {
		const input = createInputHandler();
		expect(input.state.current).toBeNull();
		expect(input.state.buffered).toBeNull();
	});

	it('maps arrow keys to directions', () => {
		const input = createInputHandler();
		expect(input.onKeyDown('ArrowUp')).toBe('up');
		expect(input.state.current).toBe('up');
		expect(input.state.buffered).toBe('up');
	});

	it('maps WASD keys', () => {
		const input = createInputHandler();
		expect(input.onKeyDown('w')).toBe('up');
		expect(input.onKeyDown('a')).toBe('left');
		expect(input.onKeyDown('s')).toBe('down');
		expect(input.onKeyDown('d')).toBe('right');
	});

	it('maps vim keys', () => {
		const input = createInputHandler();
		expect(input.onKeyDown('k')).toBe('up');
		expect(input.onKeyDown('h')).toBe('left');
		expect(input.onKeyDown('j')).toBe('down');
		expect(input.onKeyDown('l')).toBe('right');
	});

	it('detects EMP key', () => {
		const input = createInputHandler();
		expect(input.onKeyDown(' ')).toBe('emp');
		expect(input.consumeEmp()).toBe(true);
		expect(input.consumeEmp()).toBe(false);
	});

	it('detects pause key', () => {
		const input = createInputHandler();
		expect(input.onKeyDown('Escape')).toBe('pause');
		expect(input.consumePause()).toBe(true);
		expect(input.consumePause()).toBe(false);
	});

	it('clears current direction on keyup', () => {
		const input = createInputHandler();
		input.onKeyDown('ArrowUp');
		expect(input.state.current).toBe('up');

		input.onKeyUp('ArrowUp');
		expect(input.state.current).toBeNull();
	});

	it('keeps direction if another key for same direction is held', () => {
		const input = createInputHandler();
		input.onKeyDown('ArrowUp');
		input.onKeyDown('w'); // Also maps to 'up'

		input.onKeyUp('ArrowUp');
		expect(input.state.current).toBe('up'); // 'w' still held
	});

	it('consumeBuffer returns buffered direction', () => {
		const input = createInputHandler();
		input.onKeyDown('ArrowRight');

		const dir = input.consumeBuffer();
		expect(dir).toBe('right');
	});

	it('buffer decays after ticks', () => {
		const input = createInputHandler();
		input.onKeyDown('ArrowRight');
		input.onKeyUp('ArrowRight'); // Released immediately

		// Buffer should persist for INPUT_BUFFER_TICKS
		input.tick();
		expect(input.state.buffered).not.toBeNull();

		input.tick();
		input.tick();

		// After 3 ticks, buffer should have decayed (falls back to current which is null)
		input.tick();
		expect(input.state.buffered).toBeNull();
	});

	it('reset clears all state', () => {
		const input = createInputHandler();
		input.onKeyDown('ArrowUp');
		input.onKeyDown(' ');

		input.reset();
		expect(input.state.current).toBeNull();
		expect(input.state.buffered).toBeNull();
		expect(input.state.empPressed).toBe(false);
	});

	it('returns null for unrecognized keys', () => {
		const input = createInputHandler();
		expect(input.onKeyDown('x')).toBeNull();
	});
});
