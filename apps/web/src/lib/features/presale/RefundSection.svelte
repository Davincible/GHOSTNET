<script lang="ts">
	import Box from '$lib/ui/terminal/Box.svelte';
	import Button from '$lib/ui/primitives/Button.svelte';
	import { refund } from './presale-contracts';
	import { presale } from './presale.store.svelte';
	import { parseContractError } from '$lib/web3/contracts';

	// ─────────────────────────────────────────────────────────────
	// Props
	// ─────────────────────────────────────────────────────────────

	interface Props {
		contributed: bigint;
	}

	let { contributed }: Props = $props();

	// ─────────────────────────────────────────────────────────────
	// State
	// ─────────────────────────────────────────────────────────────

	let isSubmitting = $state(false);
	let txError = $state<string | null>(null);
	let refundComplete = $state(false);
	let refundedAmount = $state(0n);

	// ─────────────────────────────────────────────────────────────
	// Derived
	// ─────────────────────────────────────────────────────────────

	let hasContribution = $derived(contributed > 0n);

	// ─────────────────────────────────────────────────────────────
	// Actions
	// ─────────────────────────────────────────────────────────────

	async function handleRefund() {
		if (!hasContribution || isSubmitting) return;

		isSubmitting = true;
		txError = null;

		try {
			await refund();
			refundedAmount = contributed;
			refundComplete = true;
			await presale.refresh();
		} catch (err) {
			txError = parseContractError(err);
		} finally {
			isSubmitting = false;
		}
	}

	// ─────────────────────────────────────────────────────────────
	// Effects
	// ─────────────────────────────────────────────────────────────

	/** Auto-dismiss tx error after 5 seconds */
	$effect(() => {
		if (!txError) return;

		const timer = setTimeout(() => {
			txError = null;
		}, 5_000);

		return () => clearTimeout(timer);
	});

	// ─────────────────────────────────────────────────────────────
	// Formatting
	// ─────────────────────────────────────────────────────────────

	function formatEth(wei: bigint, decimals = 4): string {
		return (Number(wei) / 1e18).toFixed(decimals);
	}
</script>

<Box title="REFUND" variant="single" borderColor="red" borderFill>
	{#if refundComplete}
		<!-- Refund success -->
		<div class="section">
			<p class="success-text">REFUND COMPLETE — {formatEth(refundedAmount)} ETH RETURNED</p>
			<p class="hint">Your $DATA allocation has been cancelled.</p>
		</div>
	{:else if !hasContribution}
		<!-- No contribution to refund -->
		<div class="section">
			<p class="warning-text">⚠ PRESALE REFUNDS HAVE BEEN ENABLED</p>
			<p class="dim-text">NO CONTRIBUTION TO REFUND</p>
		</div>
	{:else}
		<!-- Refund available -->
		<div class="section">
			<p class="warning-text">⚠ PRESALE REFUNDS HAVE BEEN ENABLED</p>

			<div class="row">
				<span class="label">YOUR CONTRIBUTION:</span>
				<span class="value">{formatEth(contributed)} ETH</span>
			</div>

			<div class="action">
				<Button
					variant="danger"
					size="lg"
					fullWidth
					loading={isSubmitting}
					disabled={isSubmitting}
					onclick={handleRefund}
				>
					{isSubmitting ? 'PROCESSING REFUND...' : 'CLAIM REFUND'}
				</Button>
			</div>

			<p class="hint">Once refunded, your $DATA allocation is cancelled.</p>
		</div>

		{#if txError}
			<div class="tx-error">{txError}</div>
		{/if}
	{/if}
</Box>

<style>
	.section {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		font-family: var(--font-mono);
	}

	.row {
		display: flex;
		align-items: baseline;
		gap: var(--space-3);
	}

	.label {
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
		letter-spacing: var(--tracking-wider);
		text-transform: uppercase;
	}

	.value {
		font-size: var(--text-sm);
		color: var(--color-text-primary);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wider);
	}

	.warning-text {
		font-size: var(--text-sm);
		color: var(--color-amber);
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider);
		font-weight: var(--font-medium);
	}

	.success-text {
		font-size: var(--text-sm);
		color: var(--color-profit);
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider);
		font-weight: var(--font-medium);
	}

	.dim-text {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider);
	}

	.hint {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider);
	}

	.action {
		margin-top: var(--space-1);
	}

	.tx-error {
		margin-top: var(--space-3);
		padding: var(--space-2);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-red);
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider);
		border: 1px solid var(--color-red-dim);
		background: transparent;
	}
</style>
