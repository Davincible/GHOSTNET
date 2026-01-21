<script lang="ts">
	import type { Consumable, Level } from '$lib/core/types';
	import { CONSUMABLES } from '$lib/core/types/market';
	import { Panel } from '$lib/ui/terminal';
	import ConsumableCard from './ConsumableCard.svelte';

	interface Props {
		/** User's token balance for affordability check */
		userBalance: bigint;
		/** User's current level (null if not jacked in) */
		userLevel?: Level | null;
		/** Callback when item is selected for purchase */
		onBuy?: (consumable: Consumable) => void;
	}

	let { userBalance, userLevel = null, onBuy }: Props = $props();

	// Sort by rarity: legendary > epic > rare > common
	const rarityOrder = { legendary: 0, epic: 1, rare: 2, common: 3 };
	const sortedConsumables = $derived(
		[...CONSUMABLES].sort((a, b) => rarityOrder[a.rarity] - rarityOrder[b.rarity])
	);

	function canAfford(consumable: Consumable): boolean {
		return userBalance >= consumable.price;
	}
</script>

<Panel title="BLACK MARKET" scrollable maxHeight="500px">
	<div class="market-header">
		<p class="market-info">
			All purchases are <span class="burn-text">burned</span>. Items provide temporary boosts.
		</p>
	</div>

	<div class="consumables-grid">
		{#each sortedConsumables as consumable (consumable.id)}
			<ConsumableCard
				{consumable}
				{userLevel}
				canAfford={canAfford(consumable)}
				{onBuy}
			/>
		{/each}
	</div>

	{#snippet footer()}
		<span class="footer-text">
			Buy 3+ for 5% off | 5+ for 10% off | 10+ for 15% off
		</span>
	{/snippet}
</Panel>

<style>
	.market-header {
		margin-bottom: var(--space-3);
		padding-bottom: var(--space-2);
		border-bottom: 1px solid var(--color-border-subtle);
	}

	.market-info {
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
		margin: 0;
	}

	.burn-text {
		color: var(--color-danger);
		font-weight: var(--font-medium);
	}

	.consumables-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
		gap: var(--space-3);
	}

	.footer-text {
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
		font-family: var(--font-mono);
	}

	@media (max-width: 640px) {
		.consumables-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
