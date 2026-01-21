/**
 * Black Market Mock Data Generator
 * =================================
 * Generates mock inventory data and handles consumable operations.
 */

import type { OwnedConsumable, Consumable, UseConsumableResult, Modifier } from '../../../types';
import { CONSUMABLES, getConsumable, canUseConsumable } from '../../../types/market';

// ════════════════════════════════════════════════════════════════
// INVENTORY GENERATION
// ════════════════════════════════════════════════════════════════

/**
 * Generate mock starting inventory for a user.
 * New users start with a few items for demo purposes.
 *
 * @param options - Configuration options
 * @returns Array of owned consumables
 */
export function generateMockInventory(options?: {
	/** Start with empty inventory */
	empty?: boolean;
	/** Specific items to include */
	items?: Array<{ id: string; quantity: number }>;
}): OwnedConsumable[] {
	if (options?.empty) {
		return [];
	}

	if (options?.items) {
		return options.items.map((item) => ({
			consumableId: item.id,
			quantity: item.quantity,
			lastUsed: null,
			cooldownEnds: null,
		}));
	}

	// Default: give user a few starter items
	return [
		{
			consumableId: 'stimpack',
			quantity: 2,
			lastUsed: null,
			cooldownEnds: null,
		},
		{
			consumableId: 'exploit_kit',
			quantity: 1,
			lastUsed: null,
			cooldownEnds: null,
		},
	];
}

// ════════════════════════════════════════════════════════════════
// PURCHASE SIMULATION
// ════════════════════════════════════════════════════════════════

/**
 * Simulate purchasing a consumable.
 * Returns updated inventory and whether purchase succeeded.
 *
 * @param inventory - Current inventory
 * @param consumableId - ID of consumable to purchase
 * @param quantity - Quantity to purchase
 * @param userBalance - User's current token balance
 * @returns Updated inventory and result
 */
export function simulatePurchase(
	inventory: OwnedConsumable[],
	consumableId: string,
	quantity: number,
	userBalance: bigint
): {
	inventory: OwnedConsumable[];
	success: boolean;
	error?: string;
	cost: bigint;
} {
	const consumable = getConsumable(consumableId);

	if (!consumable) {
		return {
			inventory,
			success: false,
			error: 'Item not found',
			cost: 0n,
		};
	}

	const totalCost = consumable.price * BigInt(quantity);

	if (userBalance < totalCost) {
		return {
			inventory,
			success: false,
			error: 'Insufficient balance',
			cost: totalCost,
		};
	}

	// Check max stack
	const existingItem = inventory.find((i) => i.consumableId === consumableId);
	const currentQuantity = existingItem?.quantity ?? 0;
	const maxStack = consumable.maxStack ?? 99;

	if (currentQuantity + quantity > maxStack) {
		return {
			inventory,
			success: false,
			error: `Max stack is ${maxStack}`,
			cost: totalCost,
		};
	}

	// Add to inventory
	const newInventory = [...inventory];
	const existingIndex = newInventory.findIndex((i) => i.consumableId === consumableId);

	if (existingIndex >= 0) {
		newInventory[existingIndex] = {
			...newInventory[existingIndex],
			quantity: newInventory[existingIndex].quantity + quantity,
		};
	} else {
		newInventory.push({
			consumableId,
			quantity,
			lastUsed: null,
			cooldownEnds: null,
		});
	}

	return {
		inventory: newInventory,
		success: true,
		cost: totalCost,
	};
}

// ════════════════════════════════════════════════════════════════
// USE CONSUMABLE SIMULATION
// ════════════════════════════════════════════════════════════════

/**
 * Simulate using a consumable.
 * Returns updated inventory, modifier to apply, and result.
 *
 * @param inventory - Current inventory
 * @param consumableId - ID of consumable to use
 * @returns Updated inventory, new modifier, and result
 */
export function simulateUseConsumable(
	inventory: OwnedConsumable[],
	consumableId: string
): {
	inventory: OwnedConsumable[];
	modifier: Modifier | null;
	result: UseConsumableResult;
} {
	const consumable = getConsumable(consumableId);
	const ownedItem = inventory.find((i) => i.consumableId === consumableId);

	if (!consumable) {
		return {
			inventory,
			modifier: null,
			result: { success: false, error: 'Item not found' },
		};
	}

	if (!ownedItem || ownedItem.quantity <= 0) {
		return {
			inventory,
			modifier: null,
			result: { success: false, error: 'You don\'t own this item' },
		};
	}

	if (!canUseConsumable(ownedItem)) {
		return {
			inventory,
			modifier: null,
			result: { success: false, error: 'Item is on cooldown' },
		};
	}

	const now = Date.now();
	const modifierId = crypto.randomUUID();

	// Create modifier based on effect type
	const modifier = createModifierFromEffect(consumable, modifierId, now);

	// Update inventory
	const newInventory = inventory.map((item) => {
		if (item.consumableId !== consumableId) return item;

		return {
			...item,
			quantity: item.quantity - 1,
			lastUsed: now,
			cooldownEnds: consumable.cooldown > 0 ? now + consumable.cooldown : null,
		};
	});

	// Remove items with 0 quantity (optional - keep for history)
	// const filteredInventory = newInventory.filter(i => i.quantity > 0);

	return {
		inventory: newInventory,
		modifier,
		result: { success: true, modifierId },
	};
}

/**
 * Create a modifier from a consumable's effect.
 */
function createModifierFromEffect(
	consumable: Consumable,
	modifierId: string,
	now: number
): Modifier | null {
	const { effect } = consumable;

	switch (effect.type) {
		case 'yield_boost':
			return {
				id: modifierId,
				source: 'consumable',
				type: 'yield_multiplier',
				value: 1 + effect.value, // e.g., 0.25 boost = 1.25 multiplier
				expiresAt: now + effect.duration,
				label: `${consumable.name}: +${Math.round(effect.value * 100)}% yield`,
			};

		case 'death_rate':
			return {
				id: modifierId,
				source: 'consumable',
				type: 'death_rate',
				value: effect.value, // e.g., -0.10 = -10% death rate
				expiresAt: now + effect.duration,
				label: `${consumable.name}: ${Math.round(effect.value * 100)}% death rate`,
			};

		case 'timer_pause':
			// Timer pause would need special handling in the position system
			// For now, represent as a large death rate reduction
			return {
				id: modifierId,
				source: 'consumable',
				type: 'death_rate',
				value: -0.99, // Nearly immune during pause
				expiresAt: now + effect.duration,
				label: `${consumable.name}: Scan paused`,
			};

		case 'skip_scan':
			// Skip scan is a one-time effect - represented as temp invincibility
			return {
				id: modifierId,
				source: 'consumable',
				type: 'death_rate',
				value: -1.0, // Complete immunity for next scan
				expiresAt: null, // Lasts until used
				label: `${consumable.name}: Next scan skipped`,
			};

		case 'hackrun_unlock':
			// Hack run unlock doesn't create a visible modifier
			// It would be tracked separately in hack run state
			return null;

		default:
			return null;
	}
}

// ════════════════════════════════════════════════════════════════
// BULK DISCOUNT CALCULATION
// ════════════════════════════════════════════════════════════════

/**
 * Calculate price with bulk discount.
 * - 3+: 5% off
 * - 5+: 10% off
 * - 10+: 15% off
 *
 * @param consumable - The consumable
 * @param quantity - Quantity to purchase
 * @returns Discounted total price
 */
export function calculateBulkPrice(consumable: Consumable, quantity: number): bigint {
	const baseTotal = consumable.price * BigInt(quantity);

	let discountPercent = 0;
	if (quantity >= 10) {
		discountPercent = 15;
	} else if (quantity >= 5) {
		discountPercent = 10;
	} else if (quantity >= 3) {
		discountPercent = 5;
	}

	if (discountPercent === 0) {
		return baseTotal;
	}

	// Calculate discount (integer math to avoid precision issues)
	const discountAmount = (baseTotal * BigInt(discountPercent)) / 100n;
	return baseTotal - discountAmount;
}

/**
 * Get the discount percentage for a quantity.
 */
export function getBulkDiscountPercent(quantity: number): number {
	if (quantity >= 10) return 15;
	if (quantity >= 5) return 10;
	if (quantity >= 3) return 5;
	return 0;
}
