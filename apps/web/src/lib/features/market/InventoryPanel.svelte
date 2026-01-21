<script lang="ts">
	import type { OwnedConsumable } from '$lib/core/types';
	import { Panel } from '$lib/ui/terminal';
	import { Stack } from '$lib/ui/layout';
	import InventoryItem from './InventoryItem.svelte';

	interface Props {
		/** User's owned consumables */
		inventory: OwnedConsumable[];
		/** Callback when item is selected for use */
		onUse?: (consumableId: string) => void;
	}

	let { inventory, onUse }: Props = $props();

	// Filter out items with 0 quantity (or keep them grayed out - keeping for now)
	const visibleItems = $derived(inventory.filter((item) => item.quantity > 0));
	const hasItems = $derived(visibleItems.length > 0);
</script>

<Panel title="INVENTORY" scrollable maxHeight="300px">
	{#if hasItems}
		<Stack gap={2}>
			{#each visibleItems as owned (owned.consumableId)}
				<InventoryItem {owned} {onUse} />
			{/each}
		</Stack>
	{:else}
		<div class="empty-state">
			<span class="empty-icon">📦</span>
			<p class="empty-text">No items in inventory</p>
			<p class="empty-hint">Purchase items from the Black Market above</p>
		</div>
	{/if}

	{#snippet footer()}
		<span class="footer-text">
			{visibleItems.length} item{visibleItems.length !== 1 ? 's' : ''} owned
		</span>
	{/snippet}
</Panel>

<style>
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: var(--space-6) var(--space-4);
		text-align: center;
	}

	.empty-icon {
		font-size: var(--text-3xl);
		opacity: 0.5;
		margin-bottom: var(--space-2);
	}

	.empty-text {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		margin: 0;
	}

	.empty-hint {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		margin: var(--space-1) 0 0;
	}

	.footer-text {
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
		font-family: var(--font-mono);
	}
</style>
