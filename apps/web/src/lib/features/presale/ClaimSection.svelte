<script lang="ts">
	import Box from '$lib/ui/terminal/Box.svelte';
	import Button from '$lib/ui/primitives/Button.svelte';
	import { claimTokens } from './presale-contracts';
	import { presale } from './presale.store.svelte';
	import { parseContractError } from '$lib/web3/contracts';

	// ─────────────────────────────────────────────────────────────
	// Props
	// ─────────────────────────────────────────────────────────────

	interface Props {
		allocation: bigint;
		claimable: bigint;
		hasClaimed: boolean;
	}

	let { allocation, claimable, hasClaimed }: Props = $props();

	// ─────────────────────────────────────────────────────────────
	// State
	// ─────────────────────────────────────────────────────────────

	let isSubmitting = $state(false);
	let txError = $state<string | null>(null);
	let claimSuccess = $state(false);

	// ─────────────────────────────────────────────────────────────
	// Derived
	// ─────────────────────────────────────────────────────────────

	let hasAllocation = $derived(allocation > 0n);
	let claimed = $derived(hasClaimed || claimSuccess);

	// ─────────────────────────────────────────────────────────────
	// Actions
	// ─────────────────────────────────────────────────────────────

	async function handleClaim() {
		if (!hasAllocation || isSubmitting || claimed) return;

		isSubmitting = true;
		txError = null;

		try {
			await claimTokens();
			claimSuccess = true;
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

	function formatTokens(amount: bigint): string {
		const num = Number(amount) / 1e18;
		if (num >= 1_000_000) return `${(num / 1_000_000).toFixed(1)}M`;
		if (num >= 1_000) return Math.round(num).toLocaleString();
		return num.toFixed(0);
	}
</script>

<Box title="CLAIM $DATA" variant="single" borderColor="cyan" borderFill>
	{#if !hasAllocation}
		<!-- No allocation -->
		<div class="section">
			<p class="dim-text">NO ALLOCATION</p>
		</div>
	{:else if claimed}
		<!-- Already claimed -->
		<div class="section">
			<p class="success-text">✓ CLAIMED: {formatTokens(allocation)} $DATA</p>

			<div class="welcome">
				<p class="hint">Welcome to GHOSTNET, operator.</p>
				<a href="/" class="enter-link">
					<Button variant="primary" size="lg" fullWidth>
						ENTER THE NETWORK →
					</Button>
				</a>
			</div>
		</div>
	{:else}
		<!-- Claim available -->
		<div class="section">
			<div class="row">
				<span class="label">YOUR ALLOCATION:</span>
				<span class="value accent">{formatTokens(allocation)} $DATA</span>
			</div>

			<div class="action">
				<Button
					variant="primary"
					size="lg"
					fullWidth
					loading={isSubmitting}
					disabled={isSubmitting || claimable === 0n}
					onclick={handleClaim}
				>
					{isSubmitting ? 'CLAIMING...' : 'CLAIM $DATA'}
				</Button>
			</div>

			<p class="hint">Tokens will be sent to your connected wallet.</p>
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

	.accent {
		color: var(--color-accent);
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

	.welcome {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.enter-link {
		text-decoration: none;
		display: block;
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
