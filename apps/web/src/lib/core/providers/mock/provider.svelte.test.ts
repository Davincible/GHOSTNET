/**
 * Mock Provider Tests
 * ====================
 * Tests for the mock data provider used during development.
 *
 * CRITICAL: File must have .svelte.test.ts extension for runes to work!
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { createMockProvider } from './provider.svelte';
import type { DataProvider } from '../types';
import type { FeedEvent } from '$lib/core/types';

// ════════════════════════════════════════════════════════════════
// TEST SETUP
// ════════════════════════════════════════════════════════════════

describe('createMockProvider', () => {
	let provider: DataProvider;

	beforeEach(() => {
		vi.useFakeTimers();
		provider = createMockProvider();
	});

	afterEach(() => {
		provider.disconnect();
		vi.useRealTimers();
	});

	// ════════════════════════════════════════════════════════════════
	// INITIAL STATE
	// ════════════════════════════════════════════════════════════════

	describe('initial state', () => {
		it('starts disconnected', () => {
			expect(provider.connectionStatus).toBe('disconnected');
		});

		it('has null currentUser', () => {
			expect(provider.currentUser).toBeNull();
		});

		it('has null position', () => {
			expect(provider.position).toBeNull();
		});

		it('has empty modifiers', () => {
			expect(provider.modifiers).toEqual([]);
		});

		it('has networkState defined', () => {
			expect(provider.networkState).toBeDefined();
			expect(provider.networkState.tvl).toBeGreaterThan(0n);
		});

		it('has empty feedEvents initially', () => {
			expect(provider.feedEvents).toEqual([]);
		});

		it('has null crew', () => {
			expect(provider.crew).toBeNull();
		});

		it('has empty activeRounds', () => {
			expect(provider.activeRounds).toEqual([]);
		});
	});

	// ════════════════════════════════════════════════════════════════
	// CONNECTION
	// ════════════════════════════════════════════════════════════════

	describe('connection', () => {
		it('transitions to connecting then connected', async () => {
			const connectPromise = provider.connect();

			// Should be connecting immediately
			expect(provider.connectionStatus).toBe('connecting');

			// Advance past connection delay (500ms)
			await vi.advanceTimersByTimeAsync(600);

			await connectPromise;

			expect(provider.connectionStatus).toBe('connected');
		});

		it('generates feed events on connect', async () => {
			const connectPromise = provider.connect();
			await vi.advanceTimersByTimeAsync(600);
			await connectPromise;

			expect(provider.feedEvents.length).toBeGreaterThan(0);
		});

		it('disconnect sets status to disconnected', async () => {
			const connectPromise = provider.connect();
			await vi.advanceTimersByTimeAsync(600);
			await connectPromise;

			provider.disconnect();

			expect(provider.connectionStatus).toBe('disconnected');
		});
	});

	// ════════════════════════════════════════════════════════════════
	// WALLET
	// ════════════════════════════════════════════════════════════════

	describe('wallet', () => {
		beforeEach(async () => {
			const connectPromise = provider.connect();
			await vi.advanceTimersByTimeAsync(600);
			await connectPromise;
		});

		it('connectWallet creates user', async () => {
			const walletPromise = provider.connectWallet();
			await vi.advanceTimersByTimeAsync(400);
			await walletPromise;

			expect(provider.currentUser).not.toBeNull();
			expect(provider.currentUser?.address).toBeDefined();
		});

		it('connectWallet creates position', async () => {
			const walletPromise = provider.connectWallet();
			await vi.advanceTimersByTimeAsync(400);
			await walletPromise;

			expect(provider.position).not.toBeNull();
			expect(provider.position?.level).toBeDefined();
		});

		it('connectWallet adds modifiers', async () => {
			const walletPromise = provider.connectWallet();
			await vi.advanceTimersByTimeAsync(400);
			await walletPromise;

			expect(provider.modifiers.length).toBeGreaterThan(0);
		});

		it('disconnectWallet clears user', async () => {
			const walletPromise = provider.connectWallet();
			await vi.advanceTimersByTimeAsync(400);
			await walletPromise;

			provider.disconnectWallet();

			expect(provider.currentUser).toBeNull();
		});

		it('disconnectWallet clears position', async () => {
			const walletPromise = provider.connectWallet();
			await vi.advanceTimersByTimeAsync(400);
			await walletPromise;

			provider.disconnectWallet();

			expect(provider.position).toBeNull();
		});

		it('disconnectWallet clears modifiers', async () => {
			const walletPromise = provider.connectWallet();
			await vi.advanceTimersByTimeAsync(400);
			await walletPromise;

			provider.disconnectWallet();

			expect(provider.modifiers).toEqual([]);
		});
	});

	// ════════════════════════════════════════════════════════════════
	// POSITION ACTIONS
	// ════════════════════════════════════════════════════════════════

	describe('position actions', () => {
		beforeEach(async () => {
			const connectPromise = provider.connect();
			await vi.advanceTimersByTimeAsync(600);
			await connectPromise;

			const walletPromise = provider.connectWallet();
			await vi.advanceTimersByTimeAsync(400);
			await walletPromise;
		});

		describe('jackIn', () => {
			it('creates new position', async () => {
				// First extract to clear existing position
				const extractPromise = provider.extract();
				await vi.advanceTimersByTimeAsync(1100);
				await extractPromise;

				const jackInPromise = provider.jackIn('SUBNET', 100n * 10n ** 18n);
				await vi.advanceTimersByTimeAsync(1100);
				await jackInPromise;

				expect(provider.position).not.toBeNull();
				expect(provider.position?.level).toBe('SUBNET');
			});

			it('returns transaction hash', async () => {
				const extractPromise = provider.extract();
				await vi.advanceTimersByTimeAsync(1100);
				await extractPromise;

				const jackInPromise = provider.jackIn('DARKNET', 200n * 10n ** 18n);
				await vi.advanceTimersByTimeAsync(1100);
				const txHash = await jackInPromise;

				expect(txHash).toMatch(/^0x/);
			});

			it('throws if wallet not connected', async () => {
				provider.disconnectWallet();

				await expect(provider.jackIn('MAINFRAME', 100n * 10n ** 18n)).rejects.toThrow(
					'Wallet not connected'
				);
			});

			it('emits JACK_IN feed event', async () => {
				const extractPromise = provider.extract();
				await vi.advanceTimersByTimeAsync(1100);
				await extractPromise;

				const jackInPromise = provider.jackIn('MAINFRAME', 100n * 10n ** 18n);
				await vi.advanceTimersByTimeAsync(1100);
				await jackInPromise;

				const jackInEvent = provider.feedEvents.find((e) => e.data.type === 'JACK_IN');
				expect(jackInEvent).toBeDefined();
			});
		});

		describe('extract', () => {
			it('clears position', async () => {
				expect(provider.position).not.toBeNull();

				const extractPromise = provider.extract();
				await vi.advanceTimersByTimeAsync(1100);
				await extractPromise;

				expect(provider.position).toBeNull();
			});

			it('returns transaction hash', async () => {
				const extractPromise = provider.extract();
				await vi.advanceTimersByTimeAsync(1100);
				const txHash = await extractPromise;

				expect(txHash).toMatch(/^0x/);
			});

			it('throws if no position', async () => {
				const extractPromise = provider.extract();
				await vi.advanceTimersByTimeAsync(1100);
				await extractPromise;

				await expect(provider.extract()).rejects.toThrow('No position');
			});

			it('emits EXTRACT feed event', async () => {
				const extractPromise = provider.extract();
				await vi.advanceTimersByTimeAsync(1100);
				await extractPromise;

				const extractEvent = provider.feedEvents.find((e) => e.data.type === 'EXTRACT');
				expect(extractEvent).toBeDefined();
			});
		});
	});

	// ════════════════════════════════════════════════════════════════
	// TYPING
	// ════════════════════════════════════════════════════════════════

	describe('typing', () => {
		it('getTypingChallenge returns challenge', () => {
			const challenge = provider.getTypingChallenge();

			expect(challenge).toBeDefined();
			expect(challenge.command).toBeTruthy();
			expect(challenge.difficulty).toBeDefined();
			expect(challenge.timeLimit).toBeGreaterThan(0);
		});

		it('challenge difficulty affects time limit', () => {
			// Get multiple challenges and verify time limits make sense
			const challenges = Array.from({ length: 10 }, () => provider.getTypingChallenge());

			for (const challenge of challenges) {
				if (challenge.difficulty === 'easy') {
					expect(challenge.timeLimit).toBe(30);
				} else if (challenge.difficulty === 'medium') {
					expect(challenge.timeLimit).toBe(45);
				} else {
					expect(challenge.timeLimit).toBe(60);
				}
			}
		});

		describe('submitTypingResult', () => {
			beforeEach(async () => {
				const connectPromise = provider.connect();
				await vi.advanceTimersByTimeAsync(600);
				await connectPromise;

				const walletPromise = provider.connectWallet();
				await vi.advanceTimersByTimeAsync(400);
				await walletPromise;
			});

			it('adds modifier when reward present', async () => {
				// Clear existing typing modifiers by submitting with no reward first
				await provider.submitTypingResult({
					accuracy: 0.4,
					wpm: 20,
					timeElapsed: 30000,
					reward: null
				});

				// Now submit with reward
				await provider.submitTypingResult({
					accuracy: 0.95,
					wpm: 60,
					timeElapsed: 20000,
					reward: {
						type: 'death_rate_reduction',
						value: -0.15,
						label: 'Great -15%'
					}
				});

				const typingModifiers = provider.modifiers.filter((m) => m.source === 'typing');
				expect(typingModifiers.length).toBe(1);
				expect(typingModifiers[0].value).toBe(-0.15);
			});

			it('replaces existing typing modifier', async () => {
				// Submit first result
				await provider.submitTypingResult({
					accuracy: 0.95,
					wpm: 60,
					timeElapsed: 20000,
					reward: {
						type: 'death_rate_reduction',
						value: -0.15,
						label: 'Great -15%'
					}
				});

				// Submit second result
				await provider.submitTypingResult({
					accuracy: 1.0,
					wpm: 80,
					timeElapsed: 15000,
					reward: {
						type: 'death_rate_reduction',
						value: -0.25,
						label: 'PERFECT -25%'
					}
				});

				const typingModifiers = provider.modifiers.filter((m) => m.source === 'typing');
				expect(typingModifiers.length).toBe(1);
				expect(typingModifiers[0].value).toBe(-0.25);
			});

			it('does nothing when no reward and no existing modifier', async () => {
				// Extract and jack in fresh to clear modifiers
				const extractPromise = provider.extract();
				await vi.advanceTimersByTimeAsync(1100);
				await extractPromise;

				const jackInPromise = provider.jackIn('MAINFRAME', 100n * 10n ** 18n);
				await vi.advanceTimersByTimeAsync(1100);
				await jackInPromise;

				const initialTypingCount = provider.modifiers.filter((m) => m.source === 'typing').length;
				expect(initialTypingCount).toBe(0);

				await provider.submitTypingResult({
					accuracy: 0.4,
					wpm: 20,
					timeElapsed: 30000,
					reward: null
				});

				const typingModifiers = provider.modifiers.filter((m) => m.source === 'typing');
				expect(typingModifiers.length).toBe(0);
			});
		});
	});

	// ════════════════════════════════════════════════════════════════
	// FEED SUBSCRIPTION
	// ════════════════════════════════════════════════════════════════

	describe('feed subscription', () => {
		it('subscribeFeed returns unsubscribe function', () => {
			const unsubscribe = provider.subscribeFeed(() => {});
			expect(typeof unsubscribe).toBe('function');
			unsubscribe();
		});

		it('subscriber receives events', async () => {
			const connectPromise = provider.connect();
			await vi.advanceTimersByTimeAsync(600);
			await connectPromise;

			const walletPromise = provider.connectWallet();
			await vi.advanceTimersByTimeAsync(400);
			await walletPromise;

			const events: FeedEvent[] = [];
			const unsubscribe = provider.subscribeFeed((event) => {
				events.push(event);
			});

			// Trigger an event by extracting
			const extractPromise = provider.extract();
			await vi.advanceTimersByTimeAsync(1100);
			await extractPromise;

			expect(events.length).toBeGreaterThan(0);

			unsubscribe();
		});

		it('unsubscribe stops receiving events', async () => {
			const connectPromise = provider.connect();
			await vi.advanceTimersByTimeAsync(600);
			await connectPromise;

			const walletPromise = provider.connectWallet();
			await vi.advanceTimersByTimeAsync(400);
			await walletPromise;

			const events: FeedEvent[] = [];
			const unsubscribe = provider.subscribeFeed((event) => {
				events.push(event);
			});

			// Unsubscribe before triggering event
			unsubscribe();
			const eventCountAfterUnsubscribe = events.length;

			// Trigger event
			const extractPromise = provider.extract();
			await vi.advanceTimersByTimeAsync(1100);
			await extractPromise;

			// Should not have received the new event
			expect(events.length).toBe(eventCountAfterUnsubscribe);
		});
	});

	// ════════════════════════════════════════════════════════════════
	// NETWORK
	// ════════════════════════════════════════════════════════════════

	describe('network', () => {
		it('getLevelStats returns stats for level', () => {
			const stats = provider.getLevelStats('SUBNET');

			expect(stats.level).toBe('SUBNET');
			expect(stats.operatorCount).toBeGreaterThanOrEqual(0);
			expect(stats.totalStaked).toBeGreaterThanOrEqual(0n);
			expect(stats.baseDeathRate).toBeGreaterThan(0);
		});

		it('different levels have different death rates', () => {
			const mainframe = provider.getLevelStats('MAINFRAME');
			const darknet = provider.getLevelStats('DARKNET');

			expect(darknet.baseDeathRate).toBeGreaterThan(mainframe.baseDeathRate);
		});
	});

	// ════════════════════════════════════════════════════════════════
	// DEAD POOL
	// ════════════════════════════════════════════════════════════════

	describe('dead pool', () => {
		it('placeBet throws not implemented', async () => {
			await expect(provider.placeBet('round1', 'over', 100n)).rejects.toThrow(
				'Dead Pool not implemented'
			);
		});
	});
});
