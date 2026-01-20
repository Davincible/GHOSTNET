<script lang="ts">
	import { Button } from '$lib/ui/primitives';
	import { AddressDisplay } from '$lib/ui/data-display';
	import { Row } from '$lib/ui/layout';
	import { getProvider } from '$lib/core/stores/index.svelte';

	const provider = getProvider();

	let isConnecting = $state(false);

	async function handleClick() {
		if (provider.currentUser) {
			provider.disconnectWallet();
		} else {
			isConnecting = true;
			try {
				await provider.connectWallet();
			} finally {
				isConnecting = false;
			}
		}
	}
</script>

{#if provider.currentUser}
	<button class="wallet-connected" onclick={handleClick} type="button">
		<Row gap={2} align="center">
			<span class="wallet-indicator" aria-hidden="true"></span>
			<AddressDisplay address={provider.currentUser.address} />
		</Row>
	</button>
{:else}
	<Button variant="primary" size="sm" loading={isConnecting} onclick={handleClick}>
		Connect
	</Button>
{/if}

<style>
	.wallet-connected {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-1) var(--space-3);
		background: transparent;
		border: var(--border-width) solid var(--color-border-default);
		color: var(--color-text-primary);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.wallet-connected:hover {
		border-color: var(--color-red-dim);
		color: var(--color-red);
	}

	.wallet-connected:hover .wallet-indicator {
		background-color: var(--color-red);
		box-shadow: 0 0 6px var(--color-red-glow);
	}

	.wallet-connected:focus-visible {
		outline: 2px solid var(--color-accent);
		outline-offset: 2px;
	}

	.wallet-indicator {
		width: 6px;
		height: 6px;
		border-radius: 50%;
		background-color: var(--color-accent);
		box-shadow: 0 0 4px var(--color-accent-glow);
		transition: all var(--duration-fast) var(--ease-default);
	}
</style>
