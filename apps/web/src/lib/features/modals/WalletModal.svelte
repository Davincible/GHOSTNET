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
	let showAllWallets = $state(false);

	// Check if WalletConnect is configured
	const hasWalletConnect =
		typeof import.meta.env.VITE_WALLETCONNECT_PROJECT_ID === 'string' &&
		import.meta.env.VITE_WALLETCONNECT_PROJECT_ID.length > 0;

	// ════════════════════════════════════════════════════════════════
	// WALLET DEFINITIONS
	// ════════════════════════════════════════════════════════════════

	/**
	 * Target for wagmi's injected() connector.
	 * Uses provider functions to resolve the correct window.ethereum provider
	 * since wagmi's targetMap only knows 'metaMask', 'coinbaseWallet', 'phantom'.
	 *
	 * For all other wallets we pass a target object with:
	 *   - id: unique identifier
	 *   - name: display name
	 *   - provider: a function or EIP-5749 flag string to find the provider
	 *
	 * The provider function receives the window object and must return the
	 * matching EIP-1193 provider, or undefined if not installed.
	 */
	type WalletTarget =
		| string
		| {
				id: string;
				name: string;
				provider: string | ((window: Window & Record<string, unknown>) => unknown);
		  };

	interface WalletOption {
		id: string;
		name: string;
		icon: string;
		description: string;
		/** Connection method: 'walletconnect' | injected target */
		connectionType: 'walletconnect' | 'injected';
		/** wagmi injected() target — string for built-in targets, object for custom provider resolution */
		target?: WalletTarget;
		/** EIP-1193 flag on window.ethereum to detect if wallet is installed */
		detectFlag?: string;
		/** EIP-6963 rdns to detect via provider announcements */
		rdns?: string;
	}

	// ── Helper: find a provider from window.ethereum or .providers array ──
	function findProvider(
		flag: string
	): (win: Window & Record<string, unknown>) => unknown {
		return (win: Window & Record<string, unknown>) => {
			const eth = (win as Window & { ethereum?: Record<string, unknown> }).ethereum;
			if (!eth) return undefined;
			// Multi-provider (EIP-5749): array of providers
			if (Array.isArray(eth.providers)) {
				return eth.providers.find((p: Record<string, unknown>) => p[flag]);
			}
			return eth[flag] ? eth : undefined;
		};
	}

	/**
	 * Tier 1: Primary wallets — always shown prominently
	 * Order: MetaMask, Rabby, Coinbase, Trust Wallet, WalletConnect
	 */
	const tier1Wallets: WalletOption[] = [
		{
			id: 'metamask',
			name: 'MetaMask',
			icon: '🦊',
			description: 'Popular browser extension wallet',
			connectionType: 'injected',
			target: 'metaMask', // built-in wagmi targetMap
			detectFlag: 'isMetaMask',
			rdns: 'io.metamask',
		},
		{
			id: 'rabby',
			name: 'Rabby',
			icon: '🐰',
			description: 'Multi-chain browser wallet',
			connectionType: 'injected',
			target: { id: 'rabby', name: 'Rabby', provider: findProvider('isRabby') },
			detectFlag: 'isRabby',
			rdns: 'io.rabby',
		},
		{
			id: 'coinbase',
			name: 'Coinbase Wallet',
			icon: '🔵',
			description: 'Coinbase self-custody wallet',
			connectionType: 'injected',
			target: 'coinbaseWallet', // built-in wagmi targetMap
			detectFlag: 'isCoinbaseWallet',
			rdns: 'com.coinbase.wallet',
		},
		{
			id: 'trust',
			name: 'Trust Wallet',
			icon: '🛡️',
			description: 'Multi-chain mobile & extension wallet',
			connectionType: 'injected',
			target: { id: 'trust', name: 'Trust Wallet', provider: findProvider('isTrust') },
			detectFlag: 'isTrust',
			rdns: 'com.trustwallet.app',
		},
		{
			id: 'walletconnect',
			name: 'WalletConnect',
			icon: '🔗',
			description: 'Scan QR code with mobile wallet',
			connectionType: 'walletconnect',
		},
	];

	/**
	 * Tier 2: Extended wallets — shown when "Show all wallets" is expanded
	 * Alphabetical order. Each uses a provider function for correct detection.
	 */
	const tier2Wallets: WalletOption[] = [
		{ id: '1inch', name: '1inch Wallet', icon: '🦄', description: 'DeFi-native wallet', connectionType: 'injected', target: { id: '1inch', name: '1inch Wallet', provider: findProvider('isOneInchIOSWallet') }, detectFlag: 'isOneInchIOSWallet' },
		{ id: 'alphawallet', name: 'AlphaWallet', icon: 'α', description: 'Ethereum wallet for tokens', connectionType: 'injected', target: { id: 'alphaWallet', name: 'AlphaWallet', provider: findProvider('isAlphaWallet') }, detectFlag: 'isAlphaWallet' },
		{ id: 'argent', name: 'Argent', icon: '🔷', description: 'Smart contract wallet', connectionType: 'injected', target: { id: 'argent', name: 'Argent', provider: findProvider('isArgent') }, detectFlag: 'isArgent' },
		{ id: 'bitget', name: 'Bitget Wallet', icon: '🅱', description: 'Multi-chain Web3 wallet', connectionType: 'injected', target: { id: 'bitKeep', name: 'Bitget Wallet', provider: findProvider('isBitKeep') }, detectFlag: 'isBitKeep', rdns: 'com.bitget.web3' },
		{ id: 'coin98', name: 'Coin98', icon: '🪙', description: 'Multi-chain DeFi gateway', connectionType: 'injected', target: { id: 'coin98', name: 'Coin98', provider: findProvider('isCoin98') }, detectFlag: 'isCoin98' },
		{ id: 'enkrypt', name: 'Enkrypt', icon: '🔐', description: 'Multi-chain browser wallet', connectionType: 'injected', target: { id: 'enkrypt', name: 'Enkrypt', provider: findProvider('isEnkrypt') }, detectFlag: 'isEnkrypt' },
		{ id: 'exodus', name: 'Exodus', icon: '✦', description: 'Multi-asset desktop & mobile wallet', connectionType: 'injected', target: { id: 'exodus', name: 'Exodus', provider: findProvider('isExodus') }, detectFlag: 'isExodus' },
		{ id: 'frame', name: 'Frame', icon: '🖼', description: 'Privacy-focused system wallet', connectionType: 'injected', target: { id: 'frame', name: 'Frame', provider: findProvider('isFrame') }, detectFlag: 'isFrame' },
		{ id: 'gridplus', name: 'GridPlus Lattice', icon: '⬡', description: 'Hardware wallet with smart screen', connectionType: 'injected', target: { id: 'gridPlus', name: 'GridPlus Lattice', provider: findProvider('isGridPlus') }, detectFlag: 'isGridPlus' },
		{ id: 'imtoken', name: 'imToken', icon: '🔑', description: 'Digital asset wallet', connectionType: 'injected', target: { id: 'imToken', name: 'imToken', provider: findProvider('isImToken') }, detectFlag: 'isImToken' },
		{ id: 'keystone', name: 'Keystone', icon: '🗝', description: 'Air-gapped hardware wallet', connectionType: 'injected', target: { id: 'keystone', name: 'Keystone', provider: findProvider('isKeystone') }, detectFlag: 'isKeystone' },
		{ id: 'ledger', name: 'Ledger', icon: '📟', description: 'Hardware wallet via Ledger Live', connectionType: 'injected', target: { id: 'ledger', name: 'Ledger', provider: findProvider('isLedger') }, detectFlag: 'isLedger' },
		{ id: 'mathwallet', name: 'MathWallet', icon: '🔢', description: 'Multi-platform crypto wallet', connectionType: 'injected', target: { id: 'mathWallet', name: 'MathWallet', provider: findProvider('isMathWallet') }, detectFlag: 'isMathWallet' },
		{ id: 'mew', name: 'MyEtherWallet', icon: '🟢', description: 'Free client-side Ethereum wallet', connectionType: 'injected', target: { id: 'mew', name: 'MyEtherWallet', provider: findProvider('isMEW') }, detectFlag: 'isMEW' },
		{ id: 'okx', name: 'OKX Wallet', icon: '⬟', description: 'Multi-chain Web3 wallet', connectionType: 'injected', target: { id: 'okxWallet', name: 'OKX Wallet', provider: (win: Window & Record<string, unknown>) => (win as unknown as Record<string, Record<string, unknown>>).okxwallet ?? findProvider('isOkxWallet')(win) }, detectFlag: 'isOkxWallet', rdns: 'com.okex.wallet' },
		{ id: 'onekey', name: 'OneKey', icon: '🔏', description: 'Open-source hardware wallet', connectionType: 'injected', target: { id: 'oneKey', name: 'OneKey', provider: (win: Window & Record<string, unknown>) => (win as unknown as Record<string, Record<string, unknown>>).$onekey?.ethereum ?? findProvider('isOneKey')(win) }, detectFlag: 'isOneKey' },
		{ id: 'phantom', name: 'Phantom', icon: '👻', description: 'Multi-chain crypto wallet', connectionType: 'injected', target: 'phantom', detectFlag: 'isPhantom', rdns: 'app.phantom' },
		{ id: 'rainbow', name: 'Rainbow', icon: '🌈', description: 'Ethereum wallet for NFTs & DeFi', connectionType: 'injected', target: { id: 'rainbow', name: 'Rainbow', provider: findProvider('isRainbow') }, detectFlag: 'isRainbow', rdns: 'me.rainbow' },
		{ id: 'safe', name: 'Safe', icon: '🔒', description: 'Multi-sig smart contract wallet', connectionType: 'injected', target: { id: 'safe', name: 'Safe', provider: findProvider('isSafe') }, detectFlag: 'isSafe' },
		{ id: 'taho', name: 'Taho', icon: '🌿', description: 'Community-owned Web3 wallet', connectionType: 'injected', target: { id: 'taho', name: 'Taho', provider: findProvider('isTaho') }, detectFlag: 'isTaho' },
		{ id: 'tokenpocket', name: 'TokenPocket', icon: '👝', description: 'Multi-chain wallet', connectionType: 'injected', target: { id: 'tokenPocket', name: 'TokenPocket', provider: findProvider('isTokenPocket') }, detectFlag: 'isTokenPocket', rdns: 'pro.tokenpocket' },
		{ id: 'trezor', name: 'Trezor', icon: '🔳', description: 'Hardware wallet security', connectionType: 'injected', target: { id: 'trezor', name: 'Trezor', provider: findProvider('isTrezor') }, detectFlag: 'isTrezor' },
		{ id: 'xdefi', name: 'XDEFI (Ctrl)', icon: '⚡', description: 'Multi-chain DeFi wallet', connectionType: 'injected', target: { id: 'xdefi', name: 'XDEFI', provider: (win: Window & Record<string, unknown>) => (win as unknown as Record<string, Record<string, unknown>>).xfi?.ethereum ?? findProvider('isXDEFI')(win) }, detectFlag: 'isXDEFI' },
		{ id: 'zerion', name: 'Zerion', icon: '💎', description: 'DeFi portfolio & wallet', connectionType: 'injected', target: { id: 'zerion', name: 'Zerion', provider: findProvider('isZerion') }, detectFlag: 'isZerion', rdns: 'io.zerion.wallet' },
	];

	// ── Detection: which wallets are present in the browser? ──

	/** Check if a wallet is detected via its EIP-1193 flag on window.ethereum */
	function isWalletDetected(w: WalletOption): boolean {
		if (!browser) return false;
		if (!w.detectFlag) return false;
		const eth = window.ethereum as Record<string, unknown> | undefined;
		if (!eth) return false;
		// Check multi-provider array (EIP-5749)
		if (Array.isArray(eth.providers)) {
			return eth.providers.some((p: Record<string, unknown>) => !!p[w.detectFlag!]);
		}
		return !!eth[w.detectFlag];
	}

	// SSR-safe: detect wallets only on client
	let detectedTier1 = $state<WalletOption[]>([]);
	let detectedTier2 = $state<WalletOption[]>([]);
	let detectedIds = $state<Set<string>>(new Set());

	$effect(() => {
		if (!browser) return;

		// Build detection set
		const detected = new Set<string>();
		for (const w of [...tier1Wallets, ...tier2Wallets]) {
			if (isWalletDetected(w)) detected.add(w.id);
		}
		detectedIds = detected;

		// Tier 1: always show all (user can install or use WalletConnect fallback)
		detectedTier1 = tier1Wallets.filter((w) => {
			if (w.connectionType === 'walletconnect') return hasWalletConnect;
			return true;
		});

		// Tier 2: always show all
		detectedTier2 = tier2Wallets;
	});

	async function connectWallet(w: WalletOption) {
		isConnecting = w.id;
		error = null;

		try {
			if (w.connectionType === 'walletconnect') {
				// Close our modal first so WalletConnect QR modal is visible
				onclose();
				await wallet.connectWalletConnect();
			} else {
				// For injected wallets not detected, show helpful error before attempting
				if (!detectedIds.has(w.id)) {
					error = `${w.name} not detected. Install the extension or use WalletConnect.`;
					isConnecting = null;
					return;
				}

				await wallet.connect(w.target);

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
			showAllWallets = false;
		}
	});
</script>

<Modal {open} {onclose} title="CONNECT WALLET" maxWidth="md">
	<Stack gap={3}>
		<p class="description">Select a wallet to jack into GHOSTNET</p>

		<!-- Tier 1: Primary injected wallets (grid) -->
		<div class="primary-grid">
			{#each detectedTier1.filter((w) => w.connectionType === 'injected') as w (w.id)}
				<button
					class="wallet-card"
					class:connecting={isConnecting === w.id}
					class:not-detected={!detectedIds.has(w.id)}
					onclick={() => connectWallet(w)}
					disabled={isConnecting !== null}
				>
					<span class="card-icon">{w.icon}</span>
					<span class="card-name">{w.name}</span>
					{#if detectedIds.has(w.id)}
						<span class="detected-dot" title="Detected"></span>
					{/if}
					{#if isConnecting === w.id}
						<span class="connecting-indicator">...</span>
					{/if}
				</button>
			{/each}
		</div>

		<!-- WalletConnect: separate full-width option -->
		{#each detectedTier1.filter((w) => w.connectionType === 'walletconnect') as w (w.id)}
			<button
				class="walletconnect-option"
				class:connecting={isConnecting === w.id}
				onclick={() => connectWallet(w)}
				disabled={isConnecting !== null}
			>
				<span class="wc-icon">{w.icon}</span>
				<span class="wc-label">WalletConnect</span>
				<span class="wc-desc">Scan QR code with any mobile wallet</span>
				{#if isConnecting === w.id}
					<span class="connecting-indicator">...</span>
				{/if}
			</button>
		{/each}

		<!-- Tier 2: Extended wallets (collapsible) -->
		{#if detectedTier2.length > 0}
			<button class="tier2-toggle" onclick={() => (showAllWallets = !showAllWallets)}>
				<span class="toggle-label"
					>{showAllWallets ? '▼ HIDE' : '▶ MORE'} WALLETS ({detectedTier2.length})</span
				>
			</button>

			{#if showAllWallets}
				<div class="wallet-grid">
					{#each detectedTier2 as w (w.id)}
						<button
							class="wallet-cell"
							class:connecting={isConnecting === w.id}
							class:not-detected={!detectedIds.has(w.id)}
							onclick={() => connectWallet(w)}
							disabled={isConnecting !== null}
						>
							<span class="cell-icon">{w.icon}</span>
							<span class="cell-name">{w.name}</span>
							{#if detectedIds.has(w.id)}
								<span class="detected-dot small" title="Detected"></span>
							{/if}
						</button>
					{/each}
				</div>
			{/if}
		{/if}

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

	/* ═══════════════════════════════════════════════════════
	   TIER 1: Primary wallet grid (2x2 cards)
	   ═══════════════════════════════════════════════════════ */
	.primary-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: var(--space-2);
	}

	.wallet-card {
		position: relative;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		padding: var(--space-4) var(--space-3);
		background: var(--color-surface-raised);
		border: var(--border-width) solid var(--color-border-subtle);
		color: var(--color-text-primary);
		font-family: var(--font-mono);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
		text-align: center;
	}

	.wallet-card:hover:not(:disabled) {
		border-color: var(--color-accent);
		background: var(--color-surface-hover);
	}

	.wallet-card:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.wallet-card.connecting {
		border-color: var(--color-accent);
		animation: pulse 1.5s ease-in-out infinite;
	}

	.wallet-card.not-detected {
		opacity: 0.4;
	}

	.wallet-card.not-detected:hover:not(:disabled) {
		opacity: 0.7;
	}

	.card-icon {
		font-size: var(--text-3xl);
		line-height: 1;
	}

	.card-name {
		font-size: var(--text-sm);
		font-weight: 500;
		white-space: nowrap;
	}

	/* Green dot for detected wallets */
	.detected-dot {
		position: absolute;
		top: 8px;
		right: 8px;
		width: 8px;
		height: 8px;
		border-radius: 50%;
		background: var(--color-accent);
		box-shadow: 0 0 6px var(--color-accent);
	}

	.detected-dot.small {
		width: 6px;
		height: 6px;
		top: 6px;
		right: 6px;
	}

	/* ═══════════════════════════════════════════════════════
	   WALLETCONNECT: Full-width row
	   ═══════════════════════════════════════════════════════ */
	.walletconnect-option {
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

	.walletconnect-option:hover:not(:disabled) {
		border-color: var(--color-accent);
		background: var(--color-surface-hover);
	}

	.walletconnect-option:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.walletconnect-option.connecting {
		border-color: var(--color-accent);
		animation: pulse 1.5s ease-in-out infinite;
	}

	.wc-icon {
		font-size: var(--text-2xl);
		width: 36px;
		text-align: center;
		flex-shrink: 0;
	}

	.wc-label {
		font-size: var(--text-sm);
		font-weight: 500;
		flex-shrink: 0;
	}

	.wc-desc {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		margin-left: auto;
	}

	/* ═══════════════════════════════════════════════════════
	   SHARED
	   ═══════════════════════════════════════════════════════ */
	@keyframes pulse {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.7;
		}
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

	/* ═══════════════════════════════════════════════════════
	   TIER 2: Expandable grid
	   ═══════════════════════════════════════════════════════ */
	.tier2-toggle {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: var(--space-2);
		background: none;
		border: var(--border-width) solid var(--color-border-subtle);
		border-style: dashed;
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
		letter-spacing: 0.05em;
	}

	.tier2-toggle:hover {
		color: var(--color-accent);
		border-color: var(--color-accent);
	}

	.toggle-label {
		text-transform: uppercase;
	}

	.wallet-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: var(--space-1);
		max-height: 260px;
		overflow-y: auto;
		scrollbar-width: thin;
		scrollbar-color: var(--color-border-subtle) transparent;
	}

	.wallet-cell {
		position: relative;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 4px;
		padding: var(--space-2) var(--space-1);
		background: var(--color-surface-raised);
		border: var(--border-width) solid var(--color-border-subtle);
		color: var(--color-text-primary);
		font-family: var(--font-mono);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
		text-align: center;
	}

	.wallet-cell:hover:not(:disabled) {
		border-color: var(--color-accent);
		background: var(--color-surface-hover);
	}

	.wallet-cell:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.wallet-cell.connecting {
		border-color: var(--color-accent);
		animation: pulse 1.5s ease-in-out infinite;
	}

	.wallet-cell.not-detected {
		opacity: 0.35;
	}

	.wallet-cell.not-detected:hover:not(:disabled) {
		opacity: 0.65;
	}

	.cell-icon {
		font-size: var(--text-lg);
		line-height: 1;
	}

	.cell-name {
		font-size: 10px;
		font-weight: 500;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		max-width: 100%;
	}

	/* ═══════════════════════════════════════════════════════
	   STATUS
	   ═══════════════════════════════════════════════════════ */
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
