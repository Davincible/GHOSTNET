<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';
	import { Button } from '$lib/ui/primitives';
	import { AddressDisplay } from '$lib/ui/data-display';
	import { Row } from '$lib/ui/layout';
	import { WalletModal } from '$lib/features/modals';
	import { wallet } from '$lib/web3';

	// Modal state
	let showWalletModal = $state(false);

	// Initialize wallet watchers on mount (one-time setup)
	onMount(() => {
		return wallet.init();
	});

	function openModal() {
		showWalletModal = true;
	}

	function closeModal() {
		showWalletModal = false;
	}

	async function handleDisconnect() {
		await wallet.disconnect();
	}
</script>

{#if browser}
	{#if wallet.isConnected && wallet.address}
		<button class="wallet-connected" onclick={handleDisconnect} type="button" title="Click to disconnect">
			<Row gap={2} align="center">
				<span class="wallet-indicator" aria-hidden="true"></span>
				<AddressDisplay address={wallet.address} />
			</Row>
		</button>
	{:else if wallet.status === 'connecting' || wallet.status === 'reconnecting'}
		<Button variant="primary" size="sm" loading={true} disabled>
			{wallet.status === 'reconnecting' ? 'Reconnecting...' : 'Connecting...'}
		</Button>
	{:else}
		<Button variant="primary" size="sm" onclick={openModal}>
			Connect
		</Button>
	{/if}

	{#if wallet.isConnected && !wallet.isCorrectChain}
		<button class="chain-warning" onclick={() => wallet.switchChain()} type="button">
			Wrong network - Click to switch to {wallet.defaultChain.name}
		</button>
	{/if}

	<!-- Wallet Selection Modal -->
	<WalletModal open={showWalletModal} onclose={closeModal} />
{:else}
	<!-- SSR fallback -->
	<Button variant="primary" size="sm" disabled>
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

	.chain-warning {
		position: absolute;
		top: 100%;
		right: 0;
		margin-top: var(--space-2);
		padding: var(--space-2) var(--space-3);
		background: var(--color-surface-raised);
		border: var(--border-width) solid var(--color-yellow-dim);
		color: var(--color-yellow);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
		z-index: 100;
	}

	.chain-warning:hover {
		background: var(--color-yellow-dim);
		color: var(--color-bg);
	}
</style>
