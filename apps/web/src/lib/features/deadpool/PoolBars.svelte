<script lang="ts">
	interface Props {
		/** Pool sizes for each side */
		pools: { under: bigint; over: bigint };
		/** Width of the bar in characters */
		width?: number;
	}

	let { pools, width = 20 }: Props = $props();

	// Calculate percentages
	let total = $derived(pools.under + pools.over);
	let underPercent = $derived(total > 0n ? Number((pools.under * 100n) / total) : 50);
	let overPercent = $derived(100 - underPercent);

	// Calculate bar segments
	let underChars = $derived(Math.round((underPercent / 100) * width));
	let overChars = $derived(width - underChars);

	// Generate bar strings
	let underBar = $derived('█'.repeat(underChars));
	let overBar = $derived('█'.repeat(overChars));
</script>

<div
	class="pool-bars"
	role="img"
	aria-label="Pool distribution: {underPercent}% under, {overPercent}% over"
>
	<div class="pool-bar-container">
		<span class="pool-bar-under">{underBar}</span><span class="pool-bar-over">{overBar}</span>
	</div>
	<div class="pool-labels">
		<span class="pool-label-under">{underPercent}%</span>
		<span class="pool-label-over">{overPercent}%</span>
	</div>
</div>

<style>
	.pool-bars {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		line-height: 1;
	}

	.pool-bar-container {
		display: flex;
		letter-spacing: -0.05em;
		white-space: pre;
	}

	.pool-bar-under {
		color: var(--color-cyan);
	}

	.pool-bar-over {
		color: var(--color-amber);
	}

	.pool-labels {
		display: flex;
		justify-content: space-between;
		margin-top: var(--space-1);
		font-size: var(--text-xs);
	}

	.pool-label-under {
		color: var(--color-cyan-dim);
	}

	.pool-label-over {
		color: var(--color-amber-dim);
	}
</style>
