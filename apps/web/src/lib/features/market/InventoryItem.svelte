<script lang="ts">
	import type { OwnedConsumable, Consumable } from '$lib/core/types';
	import {
		canUseConsumable,
		formatCooldown,
		getConsumable,
		getRarityClass,
	} from '$lib/core/types/market';
	import { Button } from '$lib/ui/primitives';

	interface Props {
		/** Owned consumable instance */
		owned: OwnedConsumable;
		/** Callback when use button clicked */
		onUse?: (consumableId: string) => void;
	}

	let { owned, onUse }: Props = $props();

	const consumable = $derived(getConsumable(owned.consumableId));
	const canUse = $derived(canUseConsumable(owned));
	const cooldownText = $derived(formatCooldown(owned.cooldownEnds));
	const rarityClass = $derived(consumable ? getRarityClass(consumable.rarity) : '');

	function handleUse() {
		if (canUse) {
			onUse?.(owned.consumableId);
		}
	}
</script>

{#if consumable}
	<article class="inventory-item {rarityClass}" class:on-cooldown={!canUse}>
		<div class="item-main">
			<span class="item-icon">{consumable.icon}</span>
			<div class="item-info">
				<span class="item-name">{consumable.name}</span>
				<span class="item-quantity">x{owned.quantity}</span>
			</div>
		</div>

		<div class="item-status">
			{#if !canUse && owned.cooldownEnds}
				<span class="cooldown-text">{cooldownText}</span>
			{/if}
		</div>

		<Button
			variant={canUse ? 'primary' : 'ghost'}
			size="sm"
			disabled={!canUse || owned.quantity === 0}
			onclick={handleUse}
		>
			{#if !canUse && owned.cooldownEnds}
				COOLDOWN
			{:else if owned.quantity === 0}
				EMPTY
			{:else}
				USE
			{/if}
		</Button>
	</article>
{/if}

<style>
	.inventory-item {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-2) var(--space-3);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
		transition: border-color var(--duration-fast) var(--ease-default);
	}

	.inventory-item:hover {
		border-color: var(--color-border-default);
	}

	.inventory-item.on-cooldown {
		opacity: 0.7;
	}

	/* Rarity styling */
	.inventory-item.rarity-rare {
		border-left: 2px solid var(--color-level-subnet);
	}

	.inventory-item.rarity-epic {
		border-left: 2px solid var(--color-level-darknet);
	}

	.inventory-item.rarity-legendary {
		border-left: 2px solid var(--color-warning);
	}

	.item-main {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		flex: 1;
		min-width: 0;
	}

	.item-icon {
		font-size: var(--text-lg);
	}

	.item-info {
		display: flex;
		align-items: baseline;
		gap: var(--space-2);
		flex: 1;
		min-width: 0;
	}

	.item-name {
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		color: var(--color-text-primary);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.item-quantity {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
	}

	.item-status {
		flex-shrink: 0;
	}

	.cooldown-text {
		font-size: var(--text-xs);
		color: var(--color-warning);
		font-family: var(--font-mono);
	}

	/* Mobile layout */
	@media (max-width: 480px) {
		.inventory-item {
			flex-wrap: wrap;
		}

		.item-main {
			flex-basis: 100%;
		}

		.item-status {
			margin-left: auto;
		}
	}
</style>
