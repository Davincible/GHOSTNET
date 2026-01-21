<script lang="ts">
	import type { Consumable } from '$lib/core/types';
	import { calculateBulkPrice, getBulkDiscountPercent } from '$lib/core/providers/mock/generators/market';
	import { Modal } from '$lib/ui/modal';
	import { Button } from '$lib/ui/primitives';
	import { AmountDisplay } from '$lib/ui/data-display';
	import { Stack, Row } from '$lib/ui/layout';

	interface Props {
		/** Whether the modal is open */
		open: boolean;
		/** Consumable to purchase (null when closed) */
		consumable: Consumable | null;
		/** User's available balance */
		balance: bigint;
		/** Loading state while purchasing */
		loading?: boolean;
		/** Callback when modal is closed */
		onClose?: () => void;
		/** Callback when purchase is confirmed */
		onConfirm?: (consumableId: string, quantity: number) => void;
	}

	let {
		open,
		consumable,
		balance,
		loading = false,
		onClose,
		onConfirm
	}: Props = $props();

	// Quantity selection
	let quantity = $state(1);

	// Reset quantity when modal opens
	$effect(() => {
		if (open) {
			quantity = 1;
		}
	});

	// Calculate total with discount
	const totalPrice = $derived.by(() => {
		if (!consumable) return 0n;
		return calculateBulkPrice(consumable, quantity);
	});

	const discountPercent = $derived(getBulkDiscountPercent(quantity));
	const canAfford = $derived(totalPrice <= balance);
	const canPurchase = $derived(canAfford && !loading && consumable !== null);

	// Max quantity based on balance and max stack
	const maxQuantity = $derived.by(() => {
		if (!consumable) return 1;
		const maxStack = consumable.maxStack ?? 99;
		const maxByBalance = Number(balance / consumable.price);
		return Math.min(maxStack, Math.max(1, Math.floor(maxByBalance)));
	});

	// Preset quantities
	const presets = [1, 3, 5, 10];

	function handleConfirm() {
		if (canPurchase && consumable) {
			onConfirm?.(consumable.id, quantity);
		}
	}

	function adjustQuantity(delta: number) {
		const newVal = quantity + delta;
		if (newVal >= 1 && newVal <= maxQuantity) {
			quantity = newVal;
		}
	}
</script>

<Modal {open} title="PURCHASE ITEM" maxWidth="sm" onclose={onClose}>
	{#if consumable}
		<Stack gap={4}>
			<!-- Item info -->
			<div class="item-preview">
				<span class="item-icon">{consumable.icon}</span>
				<div class="item-details">
					<h3 class="item-name">{consumable.name}</h3>
					<p class="item-description">{consumable.description}</p>
				</div>
			</div>

			<!-- Quantity selector -->
			<div class="quantity-section">
				<span class="section-label" id="quantity-label">QUANTITY</span>
				<Row gap={2} align="center" aria-labelledby="quantity-label">
					<Button variant="ghost" size="sm" onclick={() => adjustQuantity(-1)} disabled={quantity <= 1}>
						-
					</Button>
					<span class="quantity-display">{quantity}</span>
					<Button variant="ghost" size="sm" onclick={() => adjustQuantity(1)} disabled={quantity >= maxQuantity}>
						+
					</Button>
				</Row>

				<div class="presets">
					{#each presets as preset}
						{#if preset <= maxQuantity}
							<button
								class="preset-btn"
								class:active={quantity === preset}
								onclick={() => (quantity = preset)}
							>
								{preset}
							</button>
						{/if}
					{/each}
				</div>
			</div>

			<!-- Price breakdown -->
			<div class="price-section">
				<div class="price-row">
					<span class="price-label">Unit Price:</span>
					<AmountDisplay amount={consumable.price} symbol="DATA" decimals={0} />
				</div>

				{#if discountPercent > 0}
					<div class="price-row discount">
						<span class="price-label">Bulk Discount:</span>
						<span class="discount-value">-{discountPercent}%</span>
					</div>
				{/if}

				<div class="price-row total">
					<span class="price-label">Total:</span>
					<AmountDisplay amount={totalPrice} symbol="DATA" decimals={0} />
				</div>
			</div>

			<!-- Balance check -->
			{#if !canAfford}
				<div class="error-message">
					Insufficient balance. You have <AmountDisplay amount={balance} symbol="DATA" decimals={0} />
				</div>
			{/if}
		</Stack>
	{/if}

	{#snippet footer()}
		<Button variant="ghost" onclick={onClose} disabled={loading}>
			CANCEL
		</Button>
		<Button
			variant="primary"
			onclick={handleConfirm}
			disabled={!canPurchase}
			{loading}
		>
			{loading ? 'PURCHASING...' : 'CONFIRM PURCHASE'}
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

	.quantity-section {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.section-label {
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-widest);
	}

	.quantity-display {
		font-size: var(--text-lg);
		font-weight: var(--font-medium);
		font-family: var(--font-mono);
		color: var(--color-accent);
		min-width: 3ch;
		text-align: center;
	}

	.presets {
		display: flex;
		gap: var(--space-2);
	}

	.preset-btn {
		padding: var(--space-1) var(--space-2);
		font-size: var(--text-xs);
		font-family: var(--font-mono);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
		color: var(--color-text-secondary);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.preset-btn:hover {
		border-color: var(--color-border-default);
		color: var(--color-text-primary);
	}

	.preset-btn.active {
		border-color: var(--color-accent);
		color: var(--color-accent);
	}

	.price-section {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		padding-top: var(--space-2);
		border-top: 1px solid var(--color-border-subtle);
	}

	.price-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-size: var(--text-sm);
	}

	.price-label {
		color: var(--color-text-secondary);
	}

	.price-row.discount {
		color: var(--color-success);
	}

	.discount-value {
		font-family: var(--font-mono);
	}

	.price-row.total {
		font-weight: var(--font-medium);
		font-size: var(--text-base);
		padding-top: var(--space-2);
		border-top: 1px solid var(--color-border-subtle);
	}

	.price-row.total .price-label {
		color: var(--color-text-primary);
	}

	.error-message {
		padding: var(--space-2) var(--space-3);
		background: rgba(255, 0, 68, 0.1);
		border: 1px solid var(--color-danger);
		font-size: var(--text-sm);
		color: var(--color-danger);
	}
</style>
