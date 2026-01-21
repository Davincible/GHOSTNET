<script lang="ts">
	import type { OwnedConsumable, Consumable } from '$lib/core/types';
	import { getConsumable } from '$lib/core/types/market';
	import { Modal } from '$lib/ui/modal';
	import { Button } from '$lib/ui/primitives';
	import { Stack } from '$lib/ui/layout';

	interface Props {
		/** Whether the modal is open */
		open: boolean;
		/** The owned consumable to use (null when closed) */
		owned: OwnedConsumable | null;
		/** Loading state while using */
		loading?: boolean;
		/** Callback when modal is closed */
		onClose?: () => void;
		/** Callback when use is confirmed */
		onConfirm?: (consumableId: string) => void;
	}

	let {
		open,
		owned,
		loading = false,
		onClose,
		onConfirm
	}: Props = $props();

	const consumable = $derived(owned ? getConsumable(owned.consumableId) : null);

	function handleConfirm() {
		if (owned && consumable) {
			onConfirm?.(owned.consumableId);
		}
	}

	// Format effect description
	function getEffectDescription(c: Consumable): string {
		const { effect } = c;
		switch (effect.type) {
			case 'yield_boost':
				return `+${Math.round(effect.value * 100)}% yield for ${formatDuration(effect.duration)}`;
			case 'death_rate':
				return `${Math.round(effect.value * 100)}% death rate for ${formatDuration(effect.duration)}`;
			case 'timer_pause':
				return `Pause scan timer for ${formatDuration(effect.duration)}`;
			case 'skip_scan':
				return `Skip ${effect.scans} trace scan${effect.scans > 1 ? 's' : ''}`;
			case 'hackrun_unlock':
				return `Unlock ${effect.feature} in Hack Runs`;
			default:
				return 'Unknown effect';
		}
	}

	function formatDuration(ms: number): string {
		const totalHours = ms / (60 * 60 * 1000);
		if (totalHours >= 24) {
			const days = Math.round(totalHours / 24);
			return `${days} day${days !== 1 ? 's' : ''}`;
		}
		const hours = Math.round(totalHours);
		return `${hours} hour${hours !== 1 ? 's' : ''}`;
	}
</script>

<Modal {open} title="USE ITEM" maxWidth="sm" onclose={onClose}>
	{#if consumable && owned}
		<Stack gap={4}>
			<!-- Item preview -->
			<div class="item-preview">
				<span class="item-icon">{consumable.icon}</span>
				<div class="item-details">
					<h3 class="item-name">{consumable.name}</h3>
					<p class="item-description">{consumable.description}</p>
				</div>
			</div>

			<!-- Effect details -->
			<div class="effect-section">
				<span class="section-label">EFFECT</span>
				<p class="effect-text">{getEffectDescription(consumable)}</p>
			</div>

			<!-- Quantity remaining -->
			<div class="quantity-info">
				<span class="quantity-label">Remaining after use:</span>
				<span class="quantity-value">{owned.quantity - 1}</span>
			</div>

			<!-- Warning if cooldown will apply -->
			{#if consumable.cooldown > 0}
				<div class="cooldown-warning">
					This item has a {formatDuration(consumable.cooldown)} cooldown before you can use another.
				</div>
			{/if}

			<!-- Confirmation warning -->
			<div class="confirm-warning">
				Are you sure you want to use this item? This action cannot be undone.
			</div>
		</Stack>
	{/if}

	{#snippet footer()}
		<Button variant="ghost" onclick={onClose} disabled={loading}>
			CANCEL
		</Button>
		<Button
			variant="primary"
			onclick={handleConfirm}
			disabled={loading || !consumable}
			{loading}
		>
			{loading ? 'USING...' : 'USE ITEM'}
		</Button>
	{/snippet}
</Modal>

<style>
	.item-preview {
		display: flex;
		gap: var(--space-3);
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
	}

	.item-icon {
		font-size: var(--text-3xl);
	}

	.item-details {
		flex: 1;
	}

	.item-name {
		font-size: var(--text-base);
		font-weight: var(--font-medium);
		color: var(--color-text-primary);
		margin: 0 0 var(--space-1);
	}

	.item-description {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		margin: 0;
	}

	.effect-section {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.section-label {
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-widest);
	}

	.effect-text {
		font-size: var(--text-sm);
		color: var(--color-accent);
		margin: 0;
		font-weight: var(--font-medium);
	}

	.quantity-info {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: var(--space-2);
		background: var(--color-bg-tertiary);
	}

	.quantity-label {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
	}

	.quantity-value {
		font-size: var(--text-sm);
		font-family: var(--font-mono);
		color: var(--color-text-primary);
	}

	.cooldown-warning {
		padding: var(--space-2) var(--space-3);
		background: rgba(255, 170, 0, 0.1);
		border: 1px solid var(--color-warning);
		font-size: var(--text-xs);
		color: var(--color-warning);
	}

	.confirm-warning {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		text-align: center;
		padding: var(--space-2);
	}
</style>
