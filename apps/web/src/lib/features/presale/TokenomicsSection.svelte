<script lang="ts">
	import Box from '$lib/ui/terminal/Box.svelte';

	const TOTAL_SUPPLY = '100,000,000';
	const BAR_WIDTH = 30;

	const allocations = [
		{ label: 'THE MINE', pct: 60, amount: '60M' },
		{ label: 'PRESALE', pct: 15, amount: '15M' },
		{ label: 'LIQUIDITY', pct: 9, amount: '9M' },
		{ label: 'TEAM', pct: 8, amount: '8M' },
		{ label: 'TREASURY', pct: 8, amount: '8M' },
	] as const;

	const MAX_PCT = 60;

	function buildBar(pct: number): string {
		const filled = Math.round((pct / MAX_PCT) * BAR_WIDTH);
		return '█'.repeat(filled) + '░'.repeat(BAR_WIDTH - filled);
	}
</script>

<Box title="TOKENOMICS" variant="single" borderColor="default" borderFill>
	<div class="tokenomics">
		<div class="total-supply">
			<span class="label">TOTAL SUPPLY</span>
			<span class="value">{TOTAL_SUPPLY} $DATA</span>
		</div>

		<div class="allocations">
			{#each allocations as { label, pct, amount }}
				<div class="row">
					<span class="row-label">{label}</span>
					<span class="row-pct">{pct}%</span>
					<span class="row-bar">{buildBar(pct)}</span>
					<span class="row-amount">{amount}</span>
				</div>
			{/each}
		</div>

		<div class="burn-engines">
			<div class="burn-title">5 BURN ENGINES</div>
			<div class="burn-separator">──────────────</div>
			<div class="burn-list">Death tax · ETH toll · Trading tax · Bet rake · Items</div>
		</div>

		<div class="lp-statement">LP BURNED AT LAUNCH — ZERO RUG VECTOR</div>
	</div>
</Box>

<style>
	.tokenomics {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		font-family: var(--font-mono);
	}

	.total-supply {
		display: flex;
		gap: var(--space-3);
		align-items: baseline;
	}

	.total-supply .label {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		letter-spacing: 0.05em;
	}

	.total-supply .value {
		color: var(--color-accent);
		font-size: var(--text-base);
		font-weight: bold;
	}

	.allocations {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.row {
		display: flex;
		align-items: baseline;
		gap: var(--space-2);
		font-size: var(--text-sm);
		line-height: 1.6;
	}

	.row-label {
		width: 10ch;
		flex-shrink: 0;
		color: var(--color-text-secondary);
		text-align: left;
	}

	.row-pct {
		width: 4ch;
		flex-shrink: 0;
		text-align: right;
		color: var(--color-text-primary);
	}

	.row-bar {
		color: var(--color-accent);
		white-space: pre;
		font-size: var(--text-xs);
		line-height: 1.8;
	}

	.row-amount {
		width: 4ch;
		flex-shrink: 0;
		text-align: right;
		color: var(--color-text-tertiary);
	}

	.burn-engines {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.burn-title {
		color: var(--color-amber);
		font-size: var(--text-sm);
		font-weight: bold;
		letter-spacing: 0.05em;
	}

	.burn-separator {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
	}

	.burn-list {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
	}

	.lp-statement {
		color: var(--color-accent);
		font-size: var(--text-sm);
		font-weight: bold;
		letter-spacing: 0.05em;
	}
</style>
