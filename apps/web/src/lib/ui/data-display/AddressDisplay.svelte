<script lang="ts">
	import { browser } from '$app/environment';

	interface Props {
		/** Ethereum address */
		address: `0x${string}`;
		/** Truncate display (show first/last N chars) */
		truncate?: boolean;
		/** Number of chars to show at start/end when truncated */
		chars?: number;
		/** Allow copying to clipboard */
		copyable?: boolean;
		/** Show full address on hover */
		showFullOnHover?: boolean;
	}

	let {
		address,
		truncate = true,
		chars = 4,
		copyable = true,
		showFullOnHover = true,
	}: Props = $props();

	let copied = $state(false);

	// Format the display address
	let displayAddress = $derived(
		truncate ? `${address.slice(0, chars + 2)}...${address.slice(-chars)}` : address
	);

	async function copyToClipboard() {
		// Guard: only execute in browser environment
		if (!copyable || !browser) return;

		try {
			await navigator.clipboard.writeText(address);
			copied = true;
			setTimeout(() => {
				copied = false;
			}, 2000);
		} catch (err) {
			console.error('Failed to copy address:', err);
		}
	}
</script>

{#if copyable}
	<button
		type="button"
		class="address address-copyable"
		class:address-copied={copied}
		title={showFullOnHover ? address : undefined}
		onclick={copyToClipboard}
		aria-label={`Copy address ${address}`}
	>
		<span class="address-text">{displayAddress}</span>
		<span class="address-icon" aria-hidden="true">
			{copied ? '✓' : '⧉'}
		</span>
	</button>
{:else}
	<span class="address" title={showFullOnHover ? address : undefined}>
		<span class="address-text">{displayAddress}</span>
	</span>
{/if}

<style>
	.address {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
		font-family: var(--font-mono);
		font-size: inherit;
		color: var(--color-cyan);
		background: none;
		border: none;
		padding: 0;
		margin: 0;
	}

	.address-text {
		white-space: nowrap;
	}

	.address-copyable {
		cursor: pointer;
		transition: color var(--duration-fast) var(--ease-default);
	}

	.address-copyable:hover {
		color: var(--color-cyan);
		text-shadow: 0 0 8px var(--color-cyan-glow);
	}

	.address-copyable:focus-visible {
		outline: 1px solid var(--color-cyan);
		outline-offset: 2px;
	}

	.address-icon {
		font-size: 0.8em;
		opacity: 0.6;
		transition: opacity var(--duration-fast) var(--ease-default);
	}

	.address-copyable:hover .address-icon {
		opacity: 1;
	}

	.address-copied {
		color: var(--color-profit);
	}

	.address-copied .address-icon {
		opacity: 1;
	}
</style>
