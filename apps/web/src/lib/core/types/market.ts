/**
 * GHOSTNET Market & Consumables Types
 * ====================================
 * Type definitions for the Black Market consumable system.
 *
 * All consumable purchases are burned (deflationary).
 * Items provide temporary boosts to gameplay.
 */

import type { Level } from './index';

// ════════════════════════════════════════════════════════════════
// CONSUMABLE DEFINITIONS
// ════════════════════════════════════════════════════════════════

/** Effect types for consumables */
export type ConsumableEffectType =
	| 'yield_boost'
	| 'timer_pause'
	| 'skip_scan'
	| 'death_rate'
	| 'hackrun_unlock';

/** Discriminated union for consumable effects */
export type ConsumableEffect =
	| { type: 'yield_boost'; value: number; duration: number }
	| { type: 'timer_pause'; duration: number }
	| { type: 'skip_scan'; scans: number }
	| { type: 'death_rate'; value: number; duration: number }
	| { type: 'hackrun_unlock'; feature: string };

/** A purchasable consumable item */
export interface Consumable {
	/** Unique identifier */
	id: string;
	/** Display name */
	name: string;
	/** Description of what it does */
	description: string;
	/** Price in $DATA (wei) */
	price: bigint;
	/** Effect when used */
	effect: ConsumableEffect;
	/** Cooldown in ms until can use again after using */
	cooldown: number;
	/** Minimum level required to purchase (optional) */
	minLevel?: Level;
	/** Maximum quantity you can hold (optional) */
	maxStack?: number;
	/** Emoji icon for display */
	icon: string;
	/** Rarity tier for styling */
	rarity: 'common' | 'rare' | 'epic' | 'legendary';
}

/** A consumable owned by the user */
export interface OwnedConsumable {
	/** Reference to consumable definition */
	consumableId: string;
	/** Quantity owned */
	quantity: number;
	/** Timestamp of last use (null if never used) */
	lastUsed: number | null;
	/** When cooldown ends (null if not on cooldown) */
	cooldownEnds: number | null;
}

/** Result of using a consumable */
export interface UseConsumableResult {
	/** Whether the use was successful */
	success: boolean;
	/** Error message if failed */
	error?: string;
	/** The modifier that was applied (if successful) */
	modifierId?: string;
}

// ════════════════════════════════════════════════════════════════
// CONSUMABLE CATALOG
// ════════════════════════════════════════════════════════════════

/**
 * All available consumables in the Black Market.
 * Prices and effects are balanced for gameplay.
 */
export const CONSUMABLES: Consumable[] = [
	{
		id: 'stimpack',
		name: 'Stimpack',
		description: '+25% yield for 4 hours',
		price: 50n * 10n ** 18n,
		effect: { type: 'yield_boost', value: 0.25, duration: 4 * 60 * 60 * 1000 },
		cooldown: 8 * 60 * 60 * 1000, // 8h cooldown
		maxStack: 10,
		icon: '💉',
		rarity: 'common',
	},
	{
		id: 'emp_jammer',
		name: 'EMP Jammer',
		description: 'Pause your scan timer for 1 hour',
		price: 100n * 10n ** 18n,
		effect: { type: 'timer_pause', duration: 60 * 60 * 1000 },
		cooldown: 24 * 60 * 60 * 1000, // 24h cooldown
		minLevel: 'SUBNET',
		maxStack: 3,
		icon: '📡',
		rarity: 'rare',
	},
	{
		id: 'ghost_protocol',
		name: 'Ghost Protocol',
		description: 'Skip one trace scan completely',
		price: 200n * 10n ** 18n,
		effect: { type: 'skip_scan', scans: 1 },
		cooldown: 48 * 60 * 60 * 1000, // 48h cooldown
		minLevel: 'DARKNET',
		maxStack: 2,
		icon: '👻',
		rarity: 'epic',
	},
	{
		id: 'exploit_kit',
		name: 'Exploit Kit',
		description: 'Unlock shortcut paths in Hack Runs',
		price: 75n * 10n ** 18n,
		effect: { type: 'hackrun_unlock', feature: 'shortcuts' },
		cooldown: 0, // Single use, instant effect
		maxStack: 5,
		icon: '🔓',
		rarity: 'common',
	},
	{
		id: 'ice_breaker',
		name: 'ICE Breaker',
		description: '-10% death rate for 24 hours',
		price: 150n * 10n ** 18n,
		effect: { type: 'death_rate', value: -0.10, duration: 24 * 60 * 60 * 1000 },
		cooldown: 48 * 60 * 60 * 1000, // 48h cooldown
		maxStack: 3,
		icon: '🧊',
		rarity: 'rare',
	},
	{
		id: 'neural_boost',
		name: 'Neural Boost',
		description: '+50% yield for 1 hour (intense)',
		price: 120n * 10n ** 18n,
		effect: { type: 'yield_boost', value: 0.50, duration: 60 * 60 * 1000 },
		cooldown: 12 * 60 * 60 * 1000, // 12h cooldown
		minLevel: 'SUBNET',
		maxStack: 5,
		icon: '🧠',
		rarity: 'rare',
	},
	{
		id: 'phantom_cloak',
		name: 'Phantom Cloak',
		description: '-20% death rate for 8 hours',
		price: 300n * 10n ** 18n,
		effect: { type: 'death_rate', value: -0.20, duration: 8 * 60 * 60 * 1000 },
		cooldown: 72 * 60 * 60 * 1000, // 72h cooldown
		minLevel: 'DARKNET',
		maxStack: 2,
		icon: '🦇',
		rarity: 'legendary',
	},
];

// ════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ════════════════════════════════════════════════════════════════

/**
 * Get a consumable by ID.
 * @param id - Consumable ID
 * @returns The consumable or undefined
 */
export function getConsumable(id: string): Consumable | undefined {
	return CONSUMABLES.find((c) => c.id === id);
}

/**
 * Check if user can use a consumable (not on cooldown).
 * @param owned - The owned consumable instance
 * @param now - Current timestamp (defaults to Date.now())
 * @returns True if can be used
 */
export function canUseConsumable(owned: OwnedConsumable, now: number = Date.now()): boolean {
	if (owned.quantity <= 0) return false;
	if (owned.cooldownEnds && owned.cooldownEnds > now) return false;
	return true;
}

/**
 * Check if user meets level requirement to purchase.
 * @param consumable - The consumable to check
 * @param userLevel - User's current level (null if not jacked in)
 * @returns True if user meets requirement
 */
export function meetsLevelRequirement(consumable: Consumable, userLevel: Level | null): boolean {
	if (!consumable.minLevel) return true;
	if (!userLevel) return false;

	const levelOrder: Level[] = ['VAULT', 'MAINFRAME', 'SUBNET', 'DARKNET', 'BLACK_ICE'];
	const requiredIndex = levelOrder.indexOf(consumable.minLevel);
	const userIndex = levelOrder.indexOf(userLevel);

	return userIndex >= requiredIndex;
}

/**
 * Format cooldown for display.
 * @param cooldownEnds - Timestamp when cooldown ends
 * @param now - Current timestamp
 * @returns Formatted string like "2h 30m" or "Ready"
 */
export function formatCooldown(cooldownEnds: number | null, now: number = Date.now()): string {
	if (!cooldownEnds || cooldownEnds <= now) return 'Ready';

	const remaining = cooldownEnds - now;
	const hours = Math.floor(remaining / (60 * 60 * 1000));
	const minutes = Math.floor((remaining % (60 * 60 * 1000)) / (60 * 1000));

	if (hours > 0) {
		return `${hours}h ${minutes}m`;
	}
	return `${minutes}m`;
}

/**
 * Get CSS class for rarity styling.
 * @param rarity - Rarity tier
 * @returns CSS class name
 */
export function getRarityClass(rarity: Consumable['rarity']): string {
	return `rarity-${rarity}`;
}
