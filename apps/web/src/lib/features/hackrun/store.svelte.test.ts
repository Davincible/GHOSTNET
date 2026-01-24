/**
 * Hack Run Store Tests
 * ====================
 * Tests for the hack run mini-game state machine.
 *
 * CRITICAL: File must have .svelte.test.ts extension for runes to work!
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import {
	createHackRunStore,
	getHackRunStore,
	resetHackRunStore,
	type HackRunStore,
} from './store.svelte';
import type { HackRun, HackRunNode, NodeResult, NodeProgress } from '$lib/core/types/hackrun';

// ════════════════════════════════════════════════════════════════
// TEST FIXTURES
// ════════════════════════════════════════════════════════════════

/** Create a simple node for testing */
function createNode(
	id: string,
	position: number,
	type: HackRunNode['type'] = 'firewall'
): HackRunNode {
	return {
		id,
		type,
		position,
		name: `NODE_${id}`,
		description: 'Test node',
		challenge: {
			command: 'test',
			difficulty: 'easy',
			timeLimit: 30,
		},
		reward: {
			type: 'multiplier',
			value: 0.2,
			label: '+0.2x YIELD',
		},
		risk: 'low',
		hidden: false,
	};
}

/** Create a minimal hack run for testing */
function createTestRun(nodeCount: number = 3, timeLimit: number = 60000): HackRun {
	const nodes: HackRunNode[] = [];
	for (let i = 1; i <= nodeCount; i++) {
		nodes.push(createNode(`node_${i}`, i));
	}

	return {
		id: 'test_run',
		difficulty: 'easy',
		entryFee: 50n * 10n ** 18n,
		nodes,
		baseMultiplier: 1.5,
		timeLimit,
		shortcuts: 0,
	};
}

/** Create a successful node result */
function createSuccessResult(multiplier = 0.2, loot = 0n): NodeResult {
	return {
		success: true,
		accuracy: 0.95,
		wpm: 60,
		timeElapsed: 2000,
		multiplierGained: multiplier,
		lootGained: loot,
	};
}

/** Create a failed node result */
function createFailureResult(): NodeResult {
	return {
		success: false,
		accuracy: 0.3,
		wpm: 20,
		timeElapsed: 5000,
		multiplierGained: 0,
		lootGained: 0n,
	};
}

// ════════════════════════════════════════════════════════════════
// STORE TESTS
// ════════════════════════════════════════════════════════════════

describe('createHackRunStore', () => {
	let store: HackRunStore;

	beforeEach(() => {
		vi.useFakeTimers();
		store = createHackRunStore();
	});

	afterEach(() => {
		vi.restoreAllMocks();
		store.cleanup();
		store.reset();
	});

	describe('initial state', () => {
		it('starts in idle state', () => {
			expect(store.state.status).toBe('idle');
		});

		it('has zero multiplier when idle', () => {
			expect(store.currentMultiplier).toBe(0);
		});

		it('has zero loot when idle', () => {
			expect(store.totalLoot).toBe(0n);
		});

		it('has full time remaining when idle', () => {
			expect(store.timeRemainingPercent).toBe(1);
		});
	});

	describe('selectDifficulty', () => {
		it('transitions from idle to selecting', () => {
			store.selectDifficulty();
			expect(store.state.status).toBe('selecting');
		});

		it('generates available runs', () => {
			store.selectDifficulty();
			if (store.state.status === 'selecting') {
				expect(store.state.availableRuns).toHaveLength(3);
				expect(store.state.availableRuns[0].difficulty).toBe('easy');
				expect(store.state.availableRuns[1].difficulty).toBe('medium');
				expect(store.state.availableRuns[2].difficulty).toBe('hard');
			}
		});

		it('does nothing if not idle', () => {
			store.selectDifficulty();
			expect(store.state.status).toBe('selecting');

			// Try again
			store.selectDifficulty();
			expect(store.state.status).toBe('selecting');
		});
	});

	describe('startRun', () => {
		beforeEach(() => {
			store.selectDifficulty();
		});

		it('transitions to countdown when selecting', () => {
			const run = createTestRun();
			store.startRun(run);
			expect(store.state.status).toBe('countdown');
		});

		it('sets countdown to 3 seconds', () => {
			const run = createTestRun();
			store.startRun(run);

			if (store.state.status === 'countdown') {
				expect(store.state.secondsLeft).toBe(3);
			}
		});

		it('does nothing if not selecting', () => {
			store.reset();
			const run = createTestRun();
			store.startRun(run);
			expect(store.state.status).toBe('idle');
		});
	});

	describe('countdown', () => {
		beforeEach(() => {
			store.selectDifficulty();
			store.startRun(createTestRun());
		});

		it('decrements each second', () => {
			if (store.state.status !== 'countdown') {
				expect.fail('Expected countdown state');
				return;
			}

			expect(store.state.secondsLeft).toBe(3);

			vi.advanceTimersByTime(1000);
			if (store.state.status === 'countdown') {
				expect(store.state.secondsLeft).toBe(2);
			}

			vi.advanceTimersByTime(1000);
			if (store.state.status === 'countdown') {
				expect(store.state.secondsLeft).toBe(1);
			}
		});

		it('transitions to running after countdown completes', () => {
			vi.advanceTimersByTime(3000);
			expect(store.state.status).toBe('running');
		});

		it('initializes progress with first node as current', () => {
			vi.advanceTimersByTime(3000);

			if (store.state.status === 'running') {
				expect(store.state.currentNode).toBe(0);
				expect(store.state.progress[0].status).toBe('current');
			}
		});
	});

	describe('running state', () => {
		beforeEach(() => {
			store.selectDifficulty();
			store.startRun(createTestRun(3, 60000));
			vi.advanceTimersByTime(3000); // Complete countdown
		});

		it('tracks time remaining', () => {
			if (store.state.status !== 'running') {
				expect.fail('Expected running state');
				return;
			}

			expect(store.state.timeRemaining).toBe(60000);

			vi.advanceTimersByTime(10000);

			if (store.state.status === 'running') {
				expect(store.state.timeRemaining).toBeLessThan(60000);
				expect(store.state.timeRemaining).toBeGreaterThan(49000);
			}
		});

		it('has zero accumulated multiplier at start', () => {
			// currentMultiplier shows accumulated progress from completed nodes
			// At start of run, no nodes are completed, so it's 0
			expect(store.currentMultiplier).toBe(0);
		});
	});

	describe('startNode', () => {
		beforeEach(() => {
			store.selectDifficulty();
			store.startRun(createTestRun());
			vi.advanceTimersByTime(3000); // Complete countdown
		});

		it('transitions to node_typing from running', () => {
			store.startNode();
			expect(store.state.status).toBe('node_typing');
		});

		it('includes current node in state', () => {
			store.startNode();

			if (store.state.status === 'node_typing') {
				expect(store.state.node).toBeDefined();
				expect(store.state.node.id).toBe('node_1');
			}
		});

		it('does nothing if not running', () => {
			store.reset();
			store.startNode();
			expect(store.state.status).toBe('idle');
		});
	});

	describe('completeNode', () => {
		beforeEach(() => {
			store.selectDifficulty();
			store.startRun(createTestRun(3, 60000));
			vi.advanceTimersByTime(3000); // Complete countdown
			store.startNode();
		});

		it('transitions to node_result on success', () => {
			store.completeNode(createSuccessResult());
			expect(store.state.status).toBe('node_result');
		});

		it('advances to next node after delay', () => {
			store.completeNode(createSuccessResult());
			expect(store.state.status).toBe('node_result');

			vi.advanceTimersByTime(2000); // NODE_RESULT_DELAY

			expect(store.state.status).toBe('running');
			if (store.state.status === 'running') {
				expect(store.state.currentNode).toBe(1);
			}
		});

		it('fails run on failed node result', () => {
			store.completeNode(createFailureResult());
			expect(store.state.status).toBe('failed');

			if (store.state.status === 'failed') {
				expect(store.state.reason).toBe('NODE_FAILED');
			}
		});

		it('accumulates multiplier from completed nodes', () => {
			// Complete first node
			store.completeNode(createSuccessResult(0.2));
			expect(store.currentMultiplier).toBeCloseTo(0.2, 2);
		});

		it('accumulates loot from completed nodes', () => {
			store.completeNode(createSuccessResult(0.2, 100n));
			expect(store.totalLoot).toBe(100n);
		});
	});

	describe('full run completion', () => {
		it('completes after all nodes done', () => {
			store.selectDifficulty();
			store.startRun(createTestRun(2, 60000)); // 2 nodes
			vi.advanceTimersByTime(3000);

			// Node 1
			store.startNode();
			store.completeNode(createSuccessResult(0.2));
			vi.advanceTimersByTime(2000); // Wait for node_result delay

			// Node 2
			store.startNode();
			store.completeNode(createSuccessResult(0.3));
			vi.advanceTimersByTime(2000); // Wait for node_result delay to complete

			expect(store.state.status).toBe('complete');
		});

		it('calculates final result correctly', () => {
			store.selectDifficulty();
			store.startRun(createTestRun(2, 60000));
			vi.advanceTimersByTime(3000);

			// Complete both nodes
			store.startNode();
			store.completeNode(createSuccessResult(0.2, 50n));
			vi.advanceTimersByTime(2000); // Wait for node_result delay

			store.startNode();
			store.completeNode(createSuccessResult(0.3, 100n));
			vi.advanceTimersByTime(2000); // Wait for final node_result delay

			expect(store.state.status).toBe('complete');
			if (store.state.status === 'complete') {
				expect(store.state.result.success).toBe(true);
				expect(store.state.result.nodesCompleted).toBe(2);
				expect(store.state.result.finalMultiplier).toBeCloseTo(2.0, 1); // 1.5 + 0.2 + 0.3
				expect(store.state.result.lootGained).toBe(150n);
			}
		});
	});

	describe('timeout', () => {
		it('fails run when time expires', () => {
			store.selectDifficulty();
			store.startRun(createTestRun(3, 5000)); // 5 second limit
			vi.advanceTimersByTime(3000); // Complete countdown

			expect(store.state.status).toBe('running');

			// Wait for timeout
			vi.advanceTimersByTime(5100);

			expect(store.state.status).toBe('failed');
			if (store.state.status === 'failed') {
				expect(store.state.reason).toBe('TIME_EXPIRED');
			}
		});

		it('fails during node_typing if time expires', () => {
			store.selectDifficulty();
			store.startRun(createTestRun(3, 5000));
			vi.advanceTimersByTime(3000);

			store.startNode();
			expect(store.state.status).toBe('node_typing');

			vi.advanceTimersByTime(5100);

			expect(store.state.status).toBe('failed');
		});
	});

	describe('abort', () => {
		it('fails run when user aborts', () => {
			store.selectDifficulty();
			store.startRun(createTestRun());
			vi.advanceTimersByTime(3000);

			store.abort();

			expect(store.state.status).toBe('failed');
			if (store.state.status === 'failed') {
				expect(store.state.reason).toBe('USER_ABORT');
			}
		});

		it('does nothing if idle', () => {
			store.abort();
			expect(store.state.status).toBe('idle');
		});

		it('does nothing if complete', () => {
			store.selectDifficulty();
			store.startRun(createTestRun(1, 60000));
			vi.advanceTimersByTime(3000);
			store.startNode();
			store.completeNode(createSuccessResult());
			vi.advanceTimersByTime(2000); // Wait for node_result delay

			// After completing the only node, state should be complete
			expect(store.state.status).toBe('complete');

			store.abort();
			expect(store.state.status).toBe('complete');
		});
	});

	describe('reset', () => {
		it('returns to idle from any state', () => {
			store.selectDifficulty();
			store.startRun(createTestRun());
			vi.advanceTimersByTime(3000);

			store.reset();

			expect(store.state.status).toBe('idle');
		});

		it('clears all timers', () => {
			store.selectDifficulty();
			store.startRun(createTestRun(3, 5000));
			vi.advanceTimersByTime(3000);

			store.reset();

			// Advancing time should not cause state changes
			vi.advanceTimersByTime(10000);
			expect(store.state.status).toBe('idle');
		});

		it('resets derived values', () => {
			store.selectDifficulty();
			store.startRun(createTestRun());
			vi.advanceTimersByTime(3000);

			store.reset();

			expect(store.currentMultiplier).toBe(0);
			expect(store.totalLoot).toBe(0n);
		});
	});

	describe('skipNode (backdoor)', () => {
		it('marks pending nodes as skipped when jumping ahead', () => {
			// Create run with 5 nodes
			const run = createTestRun(5, 60000);

			store.selectDifficulty();
			store.startRun(run);
			vi.advanceTimersByTime(3000);

			expect(store.state.status).toBe('running');
			if (store.state.status !== 'running') return;

			// Initially: node 0 is 'current', nodes 1-4 are 'pending'
			expect(store.state.progress[0].status).toBe('current');
			expect(store.state.progress[1].status).toBe('pending');

			// Skip to node 3 (index 2)
			// The skipNode marks nodes with lower position and 'pending' status as 'skipped'
			// And sets the target node as 'current'
			// Note: The original 'current' node (index 0) stays unchanged since its status isn't 'pending'
			store.skipNode('node_3');

			if (store.state.status === 'running') {
				// Node 1 (position 2) was 'pending' and position < target -> 'skipped'
				expect(store.state.progress[1].status).toBe('skipped');
				// Node 2 (node_3) becomes 'current'
				expect(store.state.progress[2].status).toBe('current');
				// State remains running
				expect(store.state.status).toBe('running');
			}
		});
	});

	describe('timeRemainingPercent', () => {
		it('starts at 1 (100%)', () => {
			store.selectDifficulty();
			store.startRun(createTestRun(3, 60000));
			vi.advanceTimersByTime(3000);

			expect(store.timeRemainingPercent).toBe(1);
		});

		it('decreases as time passes', () => {
			store.selectDifficulty();
			store.startRun(createTestRun(3, 60000));
			vi.advanceTimersByTime(3000);

			vi.advanceTimersByTime(30000); // Half time

			expect(store.timeRemainingPercent).toBeLessThan(1);
			expect(store.timeRemainingPercent).toBeGreaterThan(0.4);
		});
	});
});

describe('singleton pattern', () => {
	beforeEach(() => {
		resetHackRunStore();
	});

	afterEach(() => {
		resetHackRunStore();
	});

	it('resetHackRunStore clears singleton and allows fresh creation', () => {
		// Get the singleton and make a state change
		const store1 = getHackRunStore();
		store1.selectDifficulty();
		expect(store1.state.status).toBe('selecting');

		// Reset the singleton
		resetHackRunStore();

		// Create a new singleton - should be in fresh idle state
		const store2 = getHackRunStore();
		expect(store2.state.status).toBe('idle');
	});
});
