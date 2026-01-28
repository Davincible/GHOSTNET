<script lang="ts">
	import { PricingMode } from './types';
	import type { PresaleProgress, CurveConfig } from './types';
	import Box from '$lib/ui/terminal/Box.svelte';
	import TrancheProgress from './TrancheProgress.svelte';
	import BondingCurveChart from './BondingCurveChart.svelte';

	interface Props {
		pricingMode: PricingMode;
		progress: PresaleProgress;
		curveConfig: CurveConfig;
	}

	let { pricingMode, progress, curveConfig }: Props = $props();

	function formatEth(wei: bigint, decimals = 2): string {
		return (Number(wei) / 1e18).toFixed(decimals);
	}

	function formatTokens(amount: bigint): string {
		const num = Number(amount) / 1e18;
		if (num >= 1_000_000) return `${(num / 1_000_000).toFixed(1)}M`;
		if (num >= 1_000) return `${(num / 1_000).toFixed(0)}K`;
		return num.toFixed(0);
	}
</script>

<Box title="PRICING + PROGRESS" variant="single" borderColor="cyan" borderFill>
	<div class="pricing-section">
		<div class="visualization">
			{#if pricingMode === PricingMode.TRANCHE}
				<TrancheProgress
					totalSold={progress.totalSold}
					totalSupply={progress.totalSupply}
					currentPrice={progress.currentPrice}
				/>
			{:else}
				<BondingCurveChart
					startPrice={curveConfig.startPrice}
					endPrice={curveConfig.endPrice}
					totalSupply={curveConfig.totalSupply}
					totalSold={progress.totalSold}
					currentPrice={progress.currentPrice}
				/>
			{/if}
		</div>

		<div class="stats">
			<span class="stat">RAISED: {formatEth(progress.totalRaised)} ETH</span>
			<span class="divider">│</span>
			<span class="stat"
				>SOLD: {formatTokens(progress.totalSold)} / {formatTokens(progress.totalSupply)} $DATA</span
			>
			<span class="divider">│</span>
			<span class="stat">{progress.contributorCount.toString()} OPERATORS</span>
		</div>
	</div>
</Box>

<style>
	.pricing-section {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	.visualization {
		min-height: 4rem;
	}

	.stats {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		flex-wrap: wrap;
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
		letter-spacing: var(--tracking-wider);
		text-transform: uppercase;
		border-top: 1px solid var(--color-border-default, rgba(255, 255, 255, 0.08));
		padding-top: var(--space-3);
	}

	.divider {
		color: var(--color-text-tertiary);
	}
</style>
