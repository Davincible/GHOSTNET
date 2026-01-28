<script lang="ts">
	import Box from '$lib/ui/terminal/Box.svelte';
	import AddressDisplay from '$lib/ui/data-display/AddressDisplay.svelte';
	import { PricingMode } from './types';

	interface Props {
		presaleAddress?: `0x${string}` | null;
		pricingMode: PricingMode;
		totalPresaleSupply: bigint;
		ownerAddress?: `0x${string}`;
	}

	let { presaleAddress, pricingMode, totalPresaleSupply, ownerAddress }: Props = $props();

	let modeLabel = $derived(pricingMode === PricingMode.BONDING_CURVE ? 'BONDING CURVE' : 'TRANCHE');

	let formattedSupply = $derived(Number(totalPresaleSupply / 10n ** 18n).toLocaleString());
</script>

<Box title="TRUST ANCHORS" variant="single" borderColor="dim" borderFill>
	<div class="trust">
		<div class="row">
			<span class="label">CONTRACT</span>
			<span class="value">
				{#if presaleAddress}
					<AddressDisplay address={presaleAddress} truncate copyable />
					<span class="verified">(VERIFIED)</span>
				{:else}
					<span class="not-deployed">NOT DEPLOYED</span>
				{/if}
			</span>
		</div>

		<div class="row">
			<span class="label">MODE</span>
			<span class="value">{modeLabel}</span>
		</div>

		<div class="row">
			<span class="label">SUPPLY</span>
			<span class="value">{formattedSupply} $DATA</span>
		</div>

		<div class="row">
			<span class="label">NETWORK</span>
			<span class="value">MEGAETH</span>
		</div>

		{#if ownerAddress}
			<div class="row">
				<span class="label">OWNER</span>
				<span class="value">
					<AddressDisplay address={ownerAddress} truncate copyable />
				</span>
			</div>
		{/if}

		<div class="row">
			<span class="label">SOURCE</span>
			<span class="value">
				<a
					href="https://github.com/ghostnet/contracts"
					target="_blank"
					rel="noopener noreferrer"
					class="source-link"
				>
					github.com/ghostnet/contracts
				</a>
			</span>
		</div>

		<div class="warning">⚠ VERIFY ALL ADDRESSES BEFORE CONTRIBUTING</div>
	</div>
</Box>

<style>
	.trust {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		font-family: var(--font-mono);
	}

	.row {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		font-size: var(--text-sm);
	}

	.label {
		width: 10ch;
		flex-shrink: 0;
		color: var(--color-text-tertiary);
		letter-spacing: 0.05em;
	}

	.value {
		color: var(--color-text-primary);
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.verified {
		color: var(--color-accent);
		font-size: var(--text-xs);
	}

	.not-deployed {
		color: var(--color-amber);
	}

	.source-link {
		color: var(--color-text-secondary);
		text-decoration: none;
	}

	.source-link:hover {
		color: var(--color-accent);
		text-decoration: underline;
	}

	.warning {
		margin-top: var(--space-2);
		color: var(--color-amber);
		font-size: var(--text-sm);
		letter-spacing: 0.05em;
	}
</style>
