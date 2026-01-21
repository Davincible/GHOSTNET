/**
 * Mock Data Provider
 * ===================
 * Simulated data provider for development without blockchain
 */

import type { DataProvider } from '../types';
import type {
	User,
	Position,
	Modifier,
	NetworkState,
	LevelStats,
	FeedEvent,
	FeedEventData,
	Level,
	Crew,
	DeadPoolRound,
	TypingChallenge,
	TypingResult,
	ConnectionStatus,
	OwnedConsumable,
	UseConsumableResult
} from '../../types';
import { LEVEL_CONFIG, getConsumable } from '../../types';
import { generateMockFeedEvents, generateRandomFeedEvent } from './generators/feed';
import { generateMockNetworkState, updateNetworkState } from './generators/network';
import { generateMockPosition, updatePositionYield, createPosition } from './generators/position';
import { getRandomCommand, getCommandDifficulty, getDifficultyReward } from './data/commands';
import { generateMockInventory, simulatePurchase, simulateUseConsumable, calculateBulkPrice } from './generators/market';

// ════════════════════════════════════════════════════════════════
// MOCK PROVIDER FACTORY
// ════════════════════════════════════════════════════════════════

export function createMockProvider(): DataProvider {
	// ─────────────────────────────────────────────────────────────
	// REACTIVE STATE
	// ─────────────────────────────────────────────────────────────

	let connectionStatus = $state<ConnectionStatus>('disconnected');
	let currentUser = $state<User | null>(null);
	let position = $state<Position | null>(null);
	let modifiers = $state<Modifier[]>([]);
	let networkState = $state<NetworkState>(generateMockNetworkState());
	let feedEvents = $state.raw<FeedEvent[]>([]);
	let crew = $state<Crew | null>(null);
	let activeRounds = $state<DeadPoolRound[]>([]);
	let ownedConsumables = $state<OwnedConsumable[]>([]);

	// Feed subscribers
	const feedSubscribers = new Set<(event: FeedEvent) => void>();

	// Simulation intervals
	let feedInterval: ReturnType<typeof setInterval> | null = null;
	let networkInterval: ReturnType<typeof setInterval> | null = null;
	let positionInterval: ReturnType<typeof setInterval> | null = null;

	// ─────────────────────────────────────────────────────────────
	// CONNECTION
	// ─────────────────────────────────────────────────────────────

	async function connect(): Promise<void> {
		connectionStatus = 'connecting';

		// Simulate connection delay
		await sleep(500);

		connectionStatus = 'connected';

		// Start simulations
		startFeedSimulation();
		startNetworkSimulation();
	}

	function disconnect(): void {
		connectionStatus = 'disconnected';
		stopSimulations();
	}

	// ─────────────────────────────────────────────────────────────
	// WALLET
	// ─────────────────────────────────────────────────────────────

	async function connectWallet(): Promise<void> {
		await sleep(300);

		currentUser = {
			address: '0x7a3f9c2d8b1e4a5f6c7d8e9f0a1b2c3d4e5f6789',
			tokenBalance: 10000n * 10n ** 18n, // 10,000 $DATA
			ethBalance: 5n * 10n ** 18n // 5 ETH
		};

		// Generate a position for the user
		position = generateMockPosition(currentUser.address);

		// Add some modifiers
		modifiers = [
			{
				id: '1',
				source: 'typing',
				type: 'death_rate',
				value: -0.15,
				expiresAt: position.nextScanTimestamp,
				label: 'Trace Evasion -15%'
			},
			{
				id: '2',
				source: 'crew',
				type: 'yield_multiplier',
				value: 1.1,
				expiresAt: null,
				label: 'Crew Bonus +10%'
			}
		];

		// Initialize inventory with starter items
		ownedConsumables = generateMockInventory();

		// Start position yield simulation
		startPositionSimulation();
	}

	function disconnectWallet(): void {
		currentUser = null;
		position = null;
		modifiers = [];
		ownedConsumables = [];
		stopPositionSimulation();
	}

	// ─────────────────────────────────────────────────────────────
	// POSITION ACTIONS
	// ─────────────────────────────────────────────────────────────

	async function jackIn(level: Level, amount: bigint): Promise<string> {
		if (!currentUser) throw new Error('Wallet not connected');

		await sleep(1000); // Simulate tx

		const txHash = `0x${Math.random().toString(16).slice(2)}`;

		position = createPosition(currentUser.address, level, amount);

		// Clear typing modifiers
		modifiers = modifiers.filter((m) => m.source !== 'typing');

		// Emit feed event
		emitFeedEvent({
			type: 'JACK_IN',
			address: currentUser.address,
			level,
			amount
		});

		// Start position simulation
		startPositionSimulation();

		return txHash;
	}

	async function extract(): Promise<string> {
		if (!currentUser || !position) throw new Error('No position');

		await sleep(1000);

		const txHash = `0x${Math.random().toString(16).slice(2)}`;
		const gain = position.earnedYield;
		const amount = position.stakedAmount + gain;

		emitFeedEvent({
			type: 'EXTRACT',
			address: currentUser.address,
			amount,
			gain
		});

		// Update user balance
		currentUser = {
			...currentUser,
			tokenBalance: currentUser.tokenBalance + amount
		};

		position = null;
		modifiers = modifiers.filter((m) => m.source !== 'typing');
		stopPositionSimulation();

		return txHash;
	}

	// ─────────────────────────────────────────────────────────────
	// NETWORK
	// ─────────────────────────────────────────────────────────────

	function getLevelStats(level: Level): LevelStats {
		const config = LEVEL_CONFIG[level];
		return {
			level,
			operatorCount: Math.floor(Math.random() * 500) + 50,
			totalStaked: BigInt(Math.floor(Math.random() * 100000)) * 10n ** 18n,
			baseDeathRate: config.baseDeathRate,
			effectiveDeathRate: config.baseDeathRate * 0.92, // Network modifier
			nextScanTimestamp: networkState.traceScanTimestamps[level]
		};
	}

	// ─────────────────────────────────────────────────────────────
	// FEED
	// ─────────────────────────────────────────────────────────────

	function subscribeFeed(callback: (event: FeedEvent) => void): () => void {
		feedSubscribers.add(callback);
		return () => feedSubscribers.delete(callback);
	}

	function emitFeedEvent(data: FeedEventData): void {
		const event: FeedEvent = {
			id: crypto.randomUUID(),
			type: data.type,
			timestamp: Date.now(),
			data
		};

		feedEvents = [event, ...feedEvents].slice(0, 100);
		feedSubscribers.forEach((cb) => cb(event));
	}

	// ─────────────────────────────────────────────────────────────
	// TYPING
	// ─────────────────────────────────────────────────────────────

	function getTypingChallenge(): TypingChallenge {
		const command = getRandomCommand();
		const difficulty = getCommandDifficulty(command);
		return {
			command,
			difficulty,
			timeLimit: difficulty === 'easy' ? 30 : difficulty === 'medium' ? 45 : 60
		};
	}

	async function submitTypingResult(result: TypingResult): Promise<void> {
		if (!position) return;

		if (result.reward) {
			// Remove old typing modifier
			modifiers = modifiers.filter((m) => m.source !== 'typing');

			// Add new modifier
			modifiers = [
				...modifiers,
				{
					id: crypto.randomUUID(),
					source: 'typing',
					type: 'death_rate',
					value: result.reward.value,
					expiresAt: position.nextScanTimestamp,
					label: result.reward.label
				}
			];
		}
	}

	// ─────────────────────────────────────────────────────────────
	// DEAD POOL (stub)
	// ─────────────────────────────────────────────────────────────

	async function placeBet(
		_roundId: string,
		_side: 'under' | 'over',
		_amount: bigint
	): Promise<string> {
		throw new Error('Dead Pool not implemented in mock provider');
	}

	// ─────────────────────────────────────────────────────────────
	// CONSUMABLES (Black Market)
	// ─────────────────────────────────────────────────────────────

	async function purchaseConsumable(consumableId: string, quantity = 1): Promise<string> {
		if (!currentUser) throw new Error('Wallet not connected');

		const consumable = getConsumable(consumableId);
		if (!consumable) throw new Error('Item not found');

		// Calculate price (with bulk discount)
		const totalCost = calculateBulkPrice(consumable, quantity);

		// Simulate purchase
		const result = simulatePurchase(
			ownedConsumables,
			consumableId,
			quantity,
			currentUser.tokenBalance
		);

		if (!result.success) {
			throw new Error(result.error ?? 'Purchase failed');
		}

		await sleep(800); // Simulate tx delay

		// Update state
		ownedConsumables = result.inventory;
		currentUser = {
			...currentUser,
			tokenBalance: currentUser.tokenBalance - totalCost
		};

		const txHash = `0x${Math.random().toString(16).slice(2)}`;
		return txHash;
	}

	async function useConsumable(consumableId: string): Promise<UseConsumableResult> {
		if (!currentUser) {
			return { success: false, error: 'Wallet not connected' };
		}

		if (!position) {
			return { success: false, error: 'Must be jacked in to use items' };
		}

		const result = simulateUseConsumable(ownedConsumables, consumableId);

		if (!result.result.success) {
			return result.result;
		}

		await sleep(500); // Simulate effect application

		// Update inventory
		ownedConsumables = result.inventory;

		// Apply modifier if one was created
		if (result.modifier) {
			// Remove any existing modifier from same consumable
			modifiers = modifiers.filter(
				(m) => !(m.source === 'consumable' && m.label.includes(getConsumable(consumableId)?.name ?? ''))
			);

			// Add new modifier
			modifiers = [...modifiers, result.modifier];
		}

		return result.result;
	}

	// ─────────────────────────────────────────────────────────────
	// SIMULATIONS
	// ─────────────────────────────────────────────────────────────

	function startFeedSimulation(): void {
		// Generate initial feed events
		feedEvents = generateMockFeedEvents(20);

		// Generate new events periodically
		feedInterval = setInterval(
			() => {
				const event = generateRandomFeedEvent();
				feedEvents = [event, ...feedEvents].slice(0, 100);
				feedSubscribers.forEach((cb) => cb(event));
			},
			2000 + Math.random() * 3000
		); // 2-5 seconds
	}

	function startNetworkSimulation(): void {
		networkInterval = setInterval(() => {
			networkState = updateNetworkState(networkState);
		}, 1000);
	}

	function startPositionSimulation(): void {
		if (positionInterval) return;

		positionInterval = setInterval(() => {
			if (position) {
				position = updatePositionYield(position);
			}
		}, 1000);
	}

	function stopPositionSimulation(): void {
		if (positionInterval) {
			clearInterval(positionInterval);
			positionInterval = null;
		}
	}

	function stopSimulations(): void {
		if (feedInterval) {
			clearInterval(feedInterval);
			feedInterval = null;
		}
		if (networkInterval) {
			clearInterval(networkInterval);
			networkInterval = null;
		}
		stopPositionSimulation();
	}

	// ─────────────────────────────────────────────────────────────
	// RETURN INTERFACE
	// ─────────────────────────────────────────────────────────────

	return {
		// Connection
		connect,
		disconnect,
		get connectionStatus() {
			return connectionStatus;
		},

		// User
		get currentUser() {
			return currentUser;
		},
		connectWallet,
		disconnectWallet,

		// Position
		get position() {
			return position;
		},
		get modifiers() {
			return modifiers;
		},
		jackIn,
		extract,

		// Network
		get networkState() {
			return networkState;
		},
		getLevelStats,

		// Feed
		get feedEvents() {
			return feedEvents;
		},
		subscribeFeed,

		// Typing
		getTypingChallenge,
		submitTypingResult,

		// Optional
		get crew() {
			return crew;
		},
		get activeRounds() {
			return activeRounds;
		},
		placeBet,

		// Consumables
		get ownedConsumables() {
			return ownedConsumables;
		},
		purchaseConsumable,
		useConsumable
	};
}

// ════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════

function sleep(ms: number): Promise<void> {
	return new Promise((resolve) => setTimeout(resolve, ms));
}
