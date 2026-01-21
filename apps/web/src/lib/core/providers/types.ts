/**
 * GHOSTNET Data Provider Interface
 * =================================
 * Contract for data providers (mock, web3, etc.)
 */

import type {
	User,
	Position,
	Modifier,
	NetworkState,
	LevelStats,
	FeedEvent,
	Level,
	Crew,
	DeadPoolRound,
	TypingChallenge,
	TypingResult,
	ConnectionStatus,
	OwnedConsumable,
	UseConsumableResult
} from '../types';

// ════════════════════════════════════════════════════════════════
// DATA PROVIDER INTERFACE
// ════════════════════════════════════════════════════════════════

/**
 * Main data provider interface.
 * Implementations: MockProvider, Web3Provider (future)
 */
export interface DataProvider {
	// ─────────────────────────────────────────────────────────────
	// Connection
	// ─────────────────────────────────────────────────────────────
	
	/** Connect to data source (WebSocket, blockchain, etc.) */
	connect(): Promise<void>;
	
	/** Disconnect from data source */
	disconnect(): void;
	
	/** Current connection status (reactive) */
	readonly connectionStatus: ConnectionStatus;

	// ─────────────────────────────────────────────────────────────
	// User / Wallet
	// ─────────────────────────────────────────────────────────────
	
	/** Currently connected user (null if not connected) */
	readonly currentUser: User | null;
	
	/** Connect wallet */
	connectWallet(): Promise<void>;
	
	/** Disconnect wallet */
	disconnectWallet(): void;

	// ─────────────────────────────────────────────────────────────
	// Position
	// ─────────────────────────────────────────────────────────────
	
	/** Current user's position (null if not jacked in) */
	readonly position: Position | null;
	
	/** Active modifiers affecting position */
	readonly modifiers: Modifier[];
	
	/** 
	 * Jack into a level with specified amount 
	 * @returns Transaction hash
	 */
	jackIn(level: Level, amount: bigint): Promise<string>;
	
	/** 
	 * Extract current position 
	 * @returns Transaction hash
	 */
	extract(): Promise<string>;

	// ─────────────────────────────────────────────────────────────
	// Network State
	// ─────────────────────────────────────────────────────────────
	
	/** Global network state (reactive) */
	readonly networkState: NetworkState;
	
	/** Get stats for a specific level */
	getLevelStats(level: Level): LevelStats;

	// ─────────────────────────────────────────────────────────────
	// Live Feed
	// ─────────────────────────────────────────────────────────────
	
	/** Recent feed events (reactive, newest first) */
	readonly feedEvents: FeedEvent[];
	
	/** 
	 * Subscribe to new feed events
	 * @returns Unsubscribe function
	 */
	subscribeFeed(callback: (event: FeedEvent) => void): () => void;

	// ─────────────────────────────────────────────────────────────
	// Typing Game (Trace Evasion)
	// ─────────────────────────────────────────────────────────────
	
	/** Get a new typing challenge */
	getTypingChallenge(): TypingChallenge;
	
	/** Submit typing result and receive reward */
	submitTypingResult(result: TypingResult): Promise<void>;

	// ─────────────────────────────────────────────────────────────
	// Crew (Optional for MVP)
	// ─────────────────────────────────────────────────────────────
	
	/** Current user's crew (null if not in a crew) */
	readonly crew: Crew | null;

	// ─────────────────────────────────────────────────────────────
	// Dead Pool (Optional for MVP)
	// ─────────────────────────────────────────────────────────────
	
	/** Active betting rounds */
	readonly activeRounds: DeadPoolRound[];
	
	/** Place a bet on a round */
	placeBet(roundId: string, side: 'under' | 'over', amount: bigint): Promise<string>;

	// ─────────────────────────────────────────────────────────────
	// Black Market / Consumables
	// ─────────────────────────────────────────────────────────────
	
	/** User's owned consumables */
	readonly ownedConsumables: OwnedConsumable[];
	
	/**
	 * Purchase a consumable from the Black Market.
	 * All purchases are burned (deflationary).
	 * @param consumableId - ID of consumable to purchase
	 * @param quantity - Quantity to purchase (default 1)
	 * @returns Transaction hash
	 */
	purchaseConsumable(consumableId: string, quantity?: number): Promise<string>;
	
	/**
	 * Use a consumable from inventory.
	 * @param consumableId - ID of consumable to use
	 * @returns Result including success status and applied modifier
	 */
	useConsumable(consumableId: string): Promise<UseConsumableResult>;
}

// ════════════════════════════════════════════════════════════════
// CONTEXT KEY
// ════════════════════════════════════════════════════════════════

/** Symbol key for Svelte context */
export const DATA_PROVIDER_KEY = Symbol('dataProvider');

// ════════════════════════════════════════════════════════════════
// HELPER TYPES
// ════════════════════════════════════════════════════════════════

/** Extract the provider type from context */
export type DataProviderContext = DataProvider;
