/**
 * Input Handler
 * ==============
 * Keyboard input with direction buffering for responsive Pac-Man-style movement.
 *
 * Key design: When a player presses a direction, it's buffered. Each tick,
 * the game loop checks if the buffered direction is valid. If not, the buffer
 * persists for INPUT_BUFFER_TICKS, enabling pre-cornering (pressing the turn
 * direction before reaching the junction). This matches classic Pac-Man feel.
 *
 * This module is pure logic — no Svelte runes, no DOM access.
 * DOM event listeners are attached by the component.
 */

import type { Direction, InputAction } from '../types';
import { INPUT_BUFFER_TICKS } from '../constants';

// ============================================================================
// KEY MAPPING
// ============================================================================

const KEY_MAP: Readonly<Record<string, Direction>> = {
	ArrowUp: 'up',
	ArrowDown: 'down',
	ArrowLeft: 'left',
	ArrowRight: 'right',
	w: 'up',
	W: 'up',
	s: 'down',
	S: 'down',
	a: 'left',
	A: 'left',
	d: 'right',
	D: 'right',
	// Vim keys
	k: 'up',
	j: 'down',
	h: 'left',
	l: 'right',
};

const EMP_KEYS = new Set([' ', 'e', 'E']);
const PAUSE_KEYS = new Set(['Escape']);

// ============================================================================
// INPUT STATE
// ============================================================================

export interface InputState {
	/** Currently held direction (from key being held) */
	current: Direction | null;
	/** Buffered direction (next turn to execute) */
	buffered: Direction | null;
	/** Ticks remaining for the buffer to persist */
	bufferTicks: number;
	/** Whether EMP was pressed this tick */
	empPressed: boolean;
	/** Whether pause was pressed this tick */
	pausePressed: boolean;
}

export interface InputHandler {
	/** Current input state */
	readonly state: InputState;
	/** Handle keydown event */
	onKeyDown(key: string): InputAction | null;
	/** Handle keyup event */
	onKeyUp(key: string): void;
	/** Called each tick to decay buffer. Returns consumed actions. */
	tick(): void;
	/** Consume the buffered direction (called when turn is executed) */
	consumeBuffer(): Direction | null;
	/** Consume EMP press */
	consumeEmp(): boolean;
	/** Consume pause press */
	consumePause(): boolean;
	/** Reset all input state */
	reset(): void;
}

// ============================================================================
// FACTORY
// ============================================================================

export function createInputHandler(): InputHandler {
	const state: InputState = {
		current: null,
		buffered: null,
		bufferTicks: 0,
		empPressed: false,
		pausePressed: false,
	};

	const held = new Set<string>();

	function onKeyDown(key: string): InputAction | null {
		const dir = KEY_MAP[key];
		if (dir) {
			held.add(key);
			state.current = dir;
			state.buffered = dir;
			state.bufferTicks = INPUT_BUFFER_TICKS;
			return dir;
		}

		if (EMP_KEYS.has(key)) {
			state.empPressed = true;
			return 'emp';
		}

		if (PAUSE_KEYS.has(key)) {
			state.pausePressed = true;
			return 'pause';
		}

		return null;
	}

	function onKeyUp(key: string): void {
		held.delete(key);

		const dir = KEY_MAP[key];
		if (dir && state.current === dir) {
			// Find another held direction
			const remaining = [...held]
				.map((k) => KEY_MAP[k])
				.filter((d): d is Direction => d !== undefined);
			state.current = remaining[0] ?? null;
		}
	}

	function tick(): void {
		// Decay buffer
		if (state.bufferTicks > 0) {
			state.bufferTicks--;
			if (state.bufferTicks === 0 && state.buffered !== state.current) {
				state.buffered = state.current;
			}
		}
	}

	function consumeBuffer(): Direction | null {
		const dir = state.buffered;
		if (dir) {
			state.buffered = state.current; // Fall back to held direction
			state.bufferTicks = 0;
		}
		return dir;
	}

	function consumeEmp(): boolean {
		const pressed = state.empPressed;
		state.empPressed = false;
		return pressed;
	}

	function consumePause(): boolean {
		const pressed = state.pausePressed;
		state.pausePressed = false;
		return pressed;
	}

	function reset(): void {
		state.current = null;
		state.buffered = null;
		state.bufferTicks = 0;
		state.empPressed = false;
		state.pausePressed = false;
		held.clear();
	}

	return {
		get state() {
			return state;
		},
		onKeyDown,
		onKeyUp,
		tick,
		consumeBuffer,
		consumeEmp,
		consumePause,
		reset,
	};
}
