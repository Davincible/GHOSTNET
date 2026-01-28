<script lang="ts">
	import type { SwapQuote } from './types';
	import { SLIPPAGE_PRESETS } from './constants';

	interface Props {
		quote: SwapQuote | null;
		slippage: number;
		onslippagechange: (value: number) => void;
		inputSymbol: string;
		outputSymbol: string;
	}

	let { quote, slippage, onslippagechange, inputSymbol, outputSymbol }: Props = $props();

	let showSettings = $state(false);

	let impactSeverity = $derived.by(() => {
		if (!quote) return 'low';
		if (quote.priceImpact > 5) return 'high';
		if (quote.priceImpact > 1) return 'medium';
		return 'low';
	});
</script>

{#if quote}
	<div class="swap-details">
		<!-- Rate -->
		<div class="detail-row">
			<span class="detail-label">RATE</span>
			<span class="detail-value">
				1 {inputSymbol} = {quote.rate.toLocaleString('en-US')} {outputSymbol}
			</span>
		</div>

		<!-- Price Impact -->
		<div class="detail-row">
			<span class="detail-label">PRICE IMPACT</span>
			<span class="detail-value impact-{impactSeverity}">
				{quote.priceImpact < 0.01 ? '<0.01' : quote.priceImpact.toFixed(2)}%
			</span>
		</div>

		<!-- Minimum Received -->
		{#if quote.minimumReceived}
			<div class="detail-row">
				<span class="detail-label">MIN RECEIVED</span>
				<span class="detail-value">
					{quote.minimumReceived} {outputSymbol}
				</span>
			</div>
		{/if}

		<!-- Gas -->
		<div class="detail-row">
			<span class="detail-label">EST. GAS</span>
			<span class="detail-value">${quote.estimatedGasUsd.toFixed(2)}</span>
		</div>

		<!-- Route -->
		<div class="detail-row">
			<span class="detail-label">ROUTE</span>
			<span class="detail-value route">{quote.route}</span>
		</div>

		<!-- Slippage -->
		<div class="detail-row">
			<span class="detail-label">SLIPPAGE</span>
			<button class="slippage-toggle" onclick={() => (showSettings = !showSettings)}>
				{slippage}%
				<span class="edit-icon">[{showSettings ? '-' : '+'}]</span>
			</button>
		</div>

		{#if showSettings}
			<div class="slippage-settings">
				{#each SLIPPAGE_PRESETS as preset (preset)}
					<button
						class="slippage-btn"
						class:active={slippage === preset}
						onclick={() => onslippagechange(preset)}
					>
						{preset}%
					</button>
				{/each}
			</div>
		{/if}
	</div>
{/if}

<style>
	.swap-details {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		padding-top: var(--space-2);
		border-top: 1px solid var(--color-border-subtle);
	}

	.detail-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-size: var(--text-xs);
		font-family: var(--font-mono);
	}

	.detail-label {
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
		text-transform: uppercase;
	}

	.detail-value {
		color: var(--color-text-secondary);
	}

	.impact-low {
		color: var(--color-text-secondary);
	}

	.impact-medium {
		color: var(--color-amber);
	}

	.impact-high {
		color: var(--color-red);
		font-weight: var(--font-bold);
	}

	.route {
		color: var(--color-text-tertiary);
	}

	.slippage-toggle {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
		background: transparent;
		border: none;
		color: var(--color-text-secondary);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		cursor: pointer;
		padding: 0;
	}

	.slippage-toggle:hover {
		color: var(--color-accent);
	}

	.edit-icon {
		color: var(--color-text-tertiary);
		font-size: 10px;
	}

	.slippage-settings {
		display: flex;
		gap: var(--space-1);
		padding: var(--space-1) 0;
		justify-content: flex-end;
	}

	.slippage-btn {
		padding: var(--space-0-5, 2px) var(--space-2);
		background: var(--color-bg-tertiary);
		border: var(--border-width) solid var(--color-border-subtle);
		color: var(--color-text-secondary);
		font-family: var(--font-mono);
		font-size: 10px;
		letter-spacing: var(--tracking-wider);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.slippage-btn:hover {
		border-color: var(--color-accent-dim);
		color: var(--color-text-primary);
	}

	.slippage-btn.active {
		border-color: var(--color-accent);
		color: var(--color-accent);
		background: var(--color-accent-glow);
	}
</style>
