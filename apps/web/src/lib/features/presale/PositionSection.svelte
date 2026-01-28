<script lang="ts">
	import Box from '$lib/ui/terminal/Box.svelte';

	interface Props {
		allocation: bigint;
		contributed: bigint;
		contributorCount: bigint;
	}

	let { allocation, contributed, contributorCount }: Props = $props();

	function formatEth(wei: bigint, decimals = 4): string {
		return (Number(wei) / 1e18).toFixed(decimals);
	}

	function formatTokens(amount: bigint): string {
		const num = Number(amount) / 1e18;
		if (num >= 1_000_000) return `${(num / 1_000_000).toFixed(1)}M`;
		if (num >= 1_000) return Math.round(num).toLocaleString();
		return num.toFixed(0);
	}

	let avgPrice = $derived(
		allocation > 0n ? (Number(contributed) / Number(allocation)).toFixed(6) : '0',
	);
</script>

{#if allocation > 0n}
	<Box title="YOUR POSITION" variant="single" borderColor="cyan" borderFill>
		<div class="position">
			<div class="row">
				<span class="label">ACQUIRED:</span>
				<span class="value">{formatTokens(allocation)} $DATA</span>
			</div>
			<div class="row">
				<span class="label">CONTRIBUTED:</span>
				<span class="value">{formatEth(contributed)} ETH</span>
			</div>
			<div class="row">
				<span class="label">AVG PRICE:</span>
				<span class="value">{avgPrice} ETH / $DATA</span>
			</div>
			<div class="row">
				<span class="label">CLAIM:</span>
				<span class="value">AT TGE</span>
			</div>

			<div class="footer">
				{contributorCount.toString()} operators in the network
			</div>
		</div>
	</Box>
{/if}

<style>
	.position {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		font-family: var(--font-mono);
	}

	.row {
		display: flex;
		align-items: baseline;
		gap: var(--space-3);
	}

	.label {
		flex-shrink: 0;
		min-width: 14ch;
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
		letter-spacing: var(--tracking-wider);
		text-transform: uppercase;
	}

	.value {
		font-size: var(--text-sm);
		color: var(--color-accent);
		font-weight: var(--font-medium);
	}

	.footer {
		margin-top: var(--space-2);
		padding-top: var(--space-3);
		border-top: 1px solid var(--color-border-default, rgba(255, 255, 255, 0.08));
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
		text-transform: uppercase;
	}
</style>
