<script lang="ts">
	interface Props {
		totalSold: bigint;
		totalSupply: bigint;
		currentPrice: bigint;
	}

	let { totalSold, totalSupply, currentPrice }: Props = $props();

	function formatEth(wei: bigint, decimals = 4): string {
		return (Number(wei) / 1e18).toFixed(decimals);
	}

	function formatTokens(amount: bigint): string {
		const num = Number(amount) / 1e18;
		if (num >= 1_000_000) return `${(num / 1_000_000).toFixed(1)}M`;
		if (num >= 1_000) return `${(num / 1_000).toFixed(0)}K`;
		return num.toFixed(0);
	}

	const BAR_WIDTH = 20;

	let fillPercent = $derived(
		totalSupply > 0n ? Number((totalSold * 10000n) / totalSupply) / 100 : 0,
	);

	let filledChars = $derived(Math.round((fillPercent / 100) * BAR_WIDTH));
	let emptyChars = $derived(BAR_WIDTH - filledChars);

	let bar = $derived('█'.repeat(filledChars) + '░'.repeat(emptyChars));
	let percentLabel = $derived(fillPercent.toFixed(1) + '%');
</script>

<div class="tranche-progress">
	<!-- 
		TODO: Replace with per-tranche rows when the store exposes individual
		TrancheConfig[] data. For now we show aggregate progress against
		totalSupply with the current spot price.
		
		Future shape:
		  T1: $0.003  ████████████████████ 100%
		  T2: $0.005  ██████████░░░░░░░░░░  52%  ◄ ACTIVE
		  T3: $0.008  ░░░░░░░░░░░░░░░░░░░░   0%
	-->

	<div class="row active">
		<span class="label">PRICE:</span>
		<span class="price">${formatEth(currentPrice, 6)}</span>
		<span class="bar">{bar}</span>
		<span class="percent">{percentLabel}</span>
		<span class="marker">◄ ACTIVE</span>
	</div>

	<div class="summary">
		{formatTokens(totalSold)} / {formatTokens(totalSupply)} $DATA
	</div>
</div>

<style>
	.tranche-progress {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.row {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		color: var(--color-text-secondary);
		white-space: nowrap;
		flex-wrap: wrap;
	}

	.row.active {
		color: var(--color-accent);
		text-shadow: 0 0 6px var(--color-accent);
	}

	.label {
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider);
		color: var(--color-text-tertiary);
		min-width: 5ch;
	}

	.row.active .label {
		color: var(--color-text-secondary);
	}

	.price {
		min-width: 10ch;
	}

	.bar {
		letter-spacing: 0;
		line-height: 1;
	}

	.percent {
		min-width: 6ch;
		text-align: right;
	}

	.marker {
		font-size: var(--text-xs);
		animation: blink 1.2s step-end infinite;
	}

	.summary {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	@keyframes blink {
		50% {
			opacity: 0;
		}
	}
</style>
