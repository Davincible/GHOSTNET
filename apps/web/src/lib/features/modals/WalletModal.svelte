<script lang="ts">
	import { browser } from '$app/environment';
	import { Modal } from '$lib/ui/modal';
	import { Button } from '$lib/ui/primitives';
	import { Stack } from '$lib/ui/layout';
	import { wallet } from '$lib/web3';

	interface Props {
		open: boolean;
		onclose: () => void;
	}

	let { open, onclose }: Props = $props();

	let isConnecting = $state<string | null>(null);
	let error = $state<string | null>(null);

	// Check if WalletConnect is configured
	const hasWalletConnect =
		typeof import.meta.env.VITE_WALLETCONNECT_PROJECT_ID === 'string' &&
		import.meta.env.VITE_WALLETCONNECT_PROJECT_ID.length > 0;

	// Wallet definitions (static data, no detection functions)
	interface WalletOption {
		id: string;
		name: string;
		icon: string;
		description: string;
	}

	const walletDefinitions: WalletOption[] = [
		{
			id: 'metamask',
			name: 'MetaMask',
			icon: '🦊',
			description: 'Connect using MetaMask browser extension',
		},
		{
			id: 'coinbase',
			name: 'Coinbase Wallet',
			icon: '🔵',
			description: 'Connect using Coinbase Wallet',
		},
		{
			id: 'walletconnect',
			name: 'WalletConnect',
			icon: '🔗',
			description: 'Scan QR code with mobile wallet',
		},
		{
			id: 'injected',
			name: 'Browser Wallet',
			icon: '🌐',
			description: 'Connect using detected browser wallet',
		},
	];

	// SSR-safe: detect wallets only on client, empty during SSR for consistent hydration
	let availableWallets = $state<WalletOption[]>([]);

	$effect(() => {
		if (!browser) return;

		// Detect which wallets are available in the browser
		const detected = walletDefinitions.filter((w) => {
			switch (w.id) {
				case 'metamask':
					return window.ethereum?.isMetaMask === true;
				case 'coinbase':
					return window.ethereum?.isCoinbaseWallet === true;
				case 'walletconnect':
					return hasWalletConnect;
				case 'injected':
					return window.ethereum !== undefined;
				default:
					return false;
			}
		});

		// If MetaMask or Coinbase is detected, hide generic "Browser Wallet" to avoid duplicates
		const hasSpecificWallet = detected.some((w) => w.id === 'metamask' || w.id === 'coinbase');
		availableWallets = hasSpecificWallet ? detected.filter((w) => w.id !== 'injected') : detected;
	});

	async function connectWallet(walletId: string) {
		isConnecting = walletId;
		error = null;

		try {
			if (walletId === 'walletconnect') {
				// Close our modal first so WalletConnect QR modal is visible
				onclose();
				await wallet.connectWalletConnect();
			} else {
				// Map wallet ID to specific target
				const target =
					walletId === 'metamask'
						? 'metaMask'
						: walletId === 'coinbase'
							? 'coinbaseWallet'
							: undefined;

				await wallet.connect(target);

				// Check if connected successfully
				if (wallet.isConnected) {
					onclose();
				} else if (wallet.error) {
					error = wallet.error;
				}
			}
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to connect';
		} finally {
			isConnecting = null;
		}
	}

	// Reset state when modal opens
	$effect(() => {
		if (open) {
			isConnecting = null;
			error = null;
		}
	});
</script>

<Modal {open} {onclose} title="CONNECT WALLET" maxWidth="sm">
	<Stack gap={3}>
		<p class="description">Select a wallet to connect to GHOSTNET</p>

		<div class="wallet-list">
			{#each availableWallets as w (w.id)}
				<button
					class="wallet-option"
					class:connecting={isConnecting === w.id}
					onclick={() => connectWallet(w.id)}
					disabled={isConnecting !== null}
				>
					<span class="wallet-icon">{w.icon}</span>
					<div class="wallet-info">
						<span class="wallet-name">{w.name}</span>
						<span class="wallet-desc">{w.description}</span>
					</div>
					{#if isConnecting === w.id}
						<span class="connecting-indicator">...</span>
					{/if}
				</button>
			{/each}
		</div>

		{#if error}
			<div class="error-message" role="alert">
				{error}
			</div>
		{/if}

		<p class="network-note">
			Network: <span class="network-name">{wallet.defaultChain.name}</span>
		</p>
	</Stack>

	{#snippet footer()}
		<Button variant="ghost" onclick={onclose}>Cancel</Button>
	{/snippet}
</Modal>

<style>
	.description {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		margin: 0;
	}

	.wallet-list {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.wallet-option {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-3);
		background: var(--color-surface-raised);
		border: var(--border-width) solid var(--color-border-subtle);
		color: var(--color-text-primary);
		font-family: var(--font-mono);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
		text-align: left;
		width: 100%;
	}

	.wallet-option:hover:not(:disabled) {
		border-color: var(--color-accent);
		background: var(--color-surface-hover);
	}

	.wallet-option:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.wallet-option.connecting {
		border-color: var(--color-accent);
		animation: pulse 1.5s ease-in-out infinite;
	}

	@keyframes pulse {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.7;
		}
	}

	.wallet-icon {
		font-size: var(--text-2xl);
		width: 40px;
		text-align: center;
	}

	.wallet-info {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.wallet-name {
		font-size: var(--text-sm);
		font-weight: 500;
	}

	.wallet-desc {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
	}

	.connecting-indicator {
		color: var(--color-accent);
		animation: blink 1s step-end infinite;
	}

	@keyframes blink {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0;
		}
	}

	.error-message {
		padding: var(--space-2) var(--space-3);
		background: rgba(255, 0, 85, 0.1);
		border: var(--border-width) solid var(--color-red-dim);
		color: var(--color-red);
		font-size: var(--text-xs);
	}

	.network-note {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		text-align: center;
		margin: 0;
	}

	.network-name {
		color: var(--color-accent);
	}
</style>
