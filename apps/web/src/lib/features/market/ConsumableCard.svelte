<script lang="ts">
	import type { Consumable, Level } from '$lib/core/types';
	import { meetsLevelRequirement, getRarityClass } from '$lib/core/types/market';
	import { Button } from '$lib/ui/primitives';
	import { AmountDisplay, LevelBadge } from '$lib/ui/data-display';

	interface Props {
		/** Consumable item to display */
		consumable: Consumable;
		/** User's current level (null if not jacked in) */
		userLevel?: Level | null;
		/** Whether user can afford this item */
		canAfford?: boolean;
		/** Callback when buy button clicked */
		onBuy?: (consumable: Consumable) => void;
	}

	let { consumable, userLevel = null, canAfford = true, onBuy }: Props = $props();

	const meetsLevel = $derived(meetsLevelRequirement(consumable, userLevel));
	const canPurchase = $derived(canAfford && meetsLevel);
	const rarityClass = $derived(getRarityClass(consumable.rarity));

	function handleBuy() {
		onBuy?.(consumable);
	}
</script>

<article class="consumable-card {rarityClass}" class:locked={!meetsLevel}>
	<header class="card-header">
		<span class="item-icon">{consumable.icon}</span>
		<div class="item-info">
			<h3 class="item-name">{consumable.name}</h3>
			<span class="rarity-tag">{consumable.rarity.toUpperCase()}</span>
		</div>
	</header>

	<p class="item-description">{consumable.description}</p>

	{#if consumable.minLevel}
		<div class="level-requirement">
			<span class="req-label">Requires:</span>
			<LevelBadge level={consumable.minLevel} compact />
		</div>
	{/if}

	<footer class="card-footer">
		<div class="price">
			<AmountDisplay amount={consumable.price} symbol="DATA" decimals={0} />
		</div>

		<Button
			variant={canPurchase ? 'primary' : 'ghost'}
			size="sm"
			disabled={!canPurchase}
			onclick={handleBuy}
		>
			{#if !meetsLevel}
				LOCKED
			{:else if !canAfford}
				INSUFFICIENT
			{:else}
				BUY
			{/if}
		</Button>
	</footer>
</article>

<style>
	.consumable-card {
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		transition: border-color var(--duration-fast) var(--ease-default);
	}

	.consumable-card:hover {
		border-color: var(--color-border-default);
	}

	.consumable-card.locked {
		opacity: 0.6;
	}

	/* Rarity styling */
	.consumable-card.rarity-common {
		border-left: 3px solid var(--color-text-tertiary);
	}

	.consumable-card.rarity-rare {
		border-left: 3px solid var(--color-level-subnet);
	}

	.consumable-card.rarity-epic {
		border-left: 3px solid var(--color-level-darknet);
	}

	.consumable-card.rarity-legendary {
		border-left: 3px solid var(--color-warning);
		box-shadow: 0 0 8px rgba(255, 170, 0, 0.15);
	}

	.card-header {
		display: flex;
		align-items: flex-start;
		gap: var(--space-2);
	}

	.item-icon {
		font-size: var(--text-2xl);
		line-height: 1;
	}

	.item-info {
		flex: 1;
		min-width: 0;
	}

	.item-name {
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		color: var(--color-text-primary);
		margin: 0;
		letter-spacing: var(--tracking-wide);
	}

	.rarity-tag {
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-widest);
	}

	.rarity-rare .rarity-tag {
		color: var(--color-level-subnet);
	}

	.rarity-epic .rarity-tag {
		color: var(--color-level-darknet);
	}

	.rarity-legendary .rarity-tag {
		color: var(--color-warning);
	}

	.item-description {
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
		margin: 0;
		line-height: 1.5;
	}

	.level-requirement {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		font-size: var(--text-2xs);
	}

	.req-label {
		color: var(--color-text-muted);
	}

	.card-footer {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-top: auto;
		padding-top: var(--space-2);
		border-top: 1px solid var(--color-border-subtle);
	}

	.price {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-accent);
	}
</style>
