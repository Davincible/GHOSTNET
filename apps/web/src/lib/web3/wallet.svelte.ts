/**
 * Wallet Connection Store
 * ========================
 * Svelte 5 runes-based wallet state management
 *
 * SSR-SAFE: All browser APIs are guarded
 */

import { browser } from '$app/environment';
import {
	connect,
	disconnect,
	reconnect,
	getAccount,
	getBalance,
	watchAccount,
	watchChainId,
	switchChain,
	type GetAccountReturnType,
	type Connector,
} from '@wagmi/core';
import { UserRejectedRequestError, ChainMismatchError } from 'viem';
import { getConfig } from './config';
import {
	defaultChain,
	getChainById,
	isAcceptableChain,
	MEGAETH_TESTNET_LEGACY_CHAIN_ID,
	supportedChains,
} from './chains';

// ════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════

export type WalletStatus = 'disconnected' | 'connecting' | 'connected' | 'reconnecting';

export interface WalletState {
	status: WalletStatus;
	address: `0x${string}` | null;
	chainId: number | null;
	chainName: string | null;
	/** true if on correct chain, null if unknown (no chainId), false if wrong chain */
	isCorrectChain: boolean | null;
	/** true only when we KNOW the chain is wrong (chainId exists and doesn't match) */
	isWrongChain: boolean;
	ethBalance: bigint;
	connector: Connector | null;
	error: string | null;
}

// ════════════════════════════════════════════════════════════════
// ERROR PARSING
// ════════════════════════════════════════════════════════════════

/**
 * Parse wallet errors into user-friendly messages
 */
function parseWalletError(err: unknown): string {
	const message = err instanceof Error ? err.message : '';
	if (message.includes('Could not add network that points to same RPC endpoint')) {
		// This shouldn't normally be seen — switchToCorrectChain handles this
		// automatically by falling back to the legacy chain ID.
		return (
			'Network conflict detected. Your wallet has an older MegaETH Testnet configured. ' +
			'Please remove the existing "Mega Testnet" network from your wallet settings, then try again.'
		);
	}
	if (err instanceof UserRejectedRequestError) {
		return 'Transaction cancelled by user';
	}
	if (err instanceof ChainMismatchError) {
		return 'Please switch to the correct network';
	}
	if (err instanceof Error) {
		// Check for common error patterns
		if (err.message.includes('User rejected')) {
			return 'Transaction cancelled by user';
		}
		if (err.message.includes('Already processing')) {
			return 'Please check your wallet for pending requests';
		}
		if (err.message.includes('No connector found') || err.message.includes('Connector not found')) {
			return 'No wallet detected. Please install MetaMask.';
		}
		return err.message;
	}
	return 'An unknown error occurred';
}

// ════════════════════════════════════════════════════════════════
// WALLET STORE
// ════════════════════════════════════════════════════════════════

/**
 * Creates a reactive wallet connection store.
 * Uses Svelte 5 runes for reactivity.
 *
 * SSR-Safe: Returns a dummy store during SSR that does nothing.
 */
export function createWalletStore() {
	// ─────────────────────────────────────────────────────────────
	// State
	// ─────────────────────────────────────────────────────────────

	let status = $state<WalletStatus>('disconnected');
	let address = $state<`0x${string}` | null>(null);
	let chainId = $state<number | null>(null);
	let ethBalance = $state<bigint>(0n);
	let connector = $state<Connector | null>(null);
	let error = $state<string | null>(null);

	// Non-reactive flag to prevent double initialization
	// (not $state to avoid tracking in effects)
	let initialized = false;

	// ─────────────────────────────────────────────────────────────
	// Derived
	// ─────────────────────────────────────────────────────────────

	const chainName = $derived(chainId ? (getChainById(chainId)?.name ?? 'Unknown') : null);
	// isCorrectChain: true if on correct/acceptable chain, null if unknown, false if wrong
	const isCorrectChain = $derived(chainId === null ? null : isAcceptableChain(chainId));
	// isWrongChain: explicitly true only when we KNOW the chain and it's not acceptable
	const isWrongChain = $derived(chainId !== null && !isAcceptableChain(chainId));
	const isConnected = $derived(status === 'connected' && address !== null);
	const shortAddress = $derived(address ? `${address.slice(0, 6)}...${address.slice(-4)}` : null);

	// ─────────────────────────────────────────────────────────────
	// Event Handlers
	// ─────────────────────────────────────────────────────────────

	async function handleAccountChange(account: GetAccountReturnType) {
		const prevStatus = status;
		const prevAddress = address;
		const prevChainId = chainId;

		address = account.address ?? null;
		chainId = account.chainId ?? null;
		connector = account.connector ?? null;

		// Map wagmi status to our status
		switch (account.status) {
			case 'connected':
				status = 'connected';
				error = null;
				await refreshBalance();
				break;
			case 'connecting':
				status = 'connecting';
				break;
			case 'reconnecting':
				status = 'reconnecting';
				break;
			case 'disconnected':
				status = 'disconnected';
				ethBalance = 0n;
				break;
		}

		// Log state changes
		console.log('[Wallet] Account changed:', {
			status: { from: prevStatus, to: status },
			address: { from: prevAddress, to: address },
			chainId: { from: prevChainId, to: chainId },
			connector: connector?.name ?? null,
			isAcceptableChain: chainId === null ? 'unknown' : isAcceptableChain(chainId),
			expectedChain: defaultChain.id,
		});
	}

	async function handleChainChange(newChainId: number) {
		const prevChainId = chainId;
		chainId = newChainId;

		console.log('[Wallet] Chain changed:', {
			from: prevChainId,
			to: newChainId,
			isAcceptableChain: isAcceptableChain(newChainId),
			expectedChain: defaultChain.id,
			chainName: getChainById(newChainId)?.name ?? 'Unknown',
		});

		if (address) {
			await refreshBalance();
		}
	}

	// ─────────────────────────────────────────────────────────────
	// Actions
	// ─────────────────────────────────────────────────────────────

	/**
	 * Initialize the wallet store.
	 * Sets up watchers and checks for existing connection.
	 * Returns cleanup function for use with $effect or onMount.
	 */
	function init(): () => void {
		// SSR guard - expected during server-side rendering
		if (!browser) return () => {};

		console.log('[Wallet] Initializing wallet store...');

		const config = getConfig();
		if (!config) {
			error = 'Wallet configuration not available';
			console.error(
				'[Wallet] Config not available during init - possible SSR leak or initialization race'
			);
			return () => {};
		}

		// Already initialized - not an error
		if (initialized) {
			console.log('[Wallet] Already initialized, skipping');
			return () => {};
		}
		initialized = true;

		// Watch account changes
		const unwatchAccount = watchAccount(config, {
			onChange: handleAccountChange,
		});

		// Watch chain changes
		const unwatchChainId = watchChainId(config, {
			onChange: handleChainChange,
		});

		// Check if already connected
		const account = getAccount(config);
		console.log('[Wallet] Initial account state:', {
			status: account.status,
			address: account.address,
			chainId: account.chainId,
			connector: account.connector?.name ?? null,
		});
		handleAccountChange(account);

		// Attempt to reconnect if not already connected
		// This restores wallet sessions from previous page loads
		if (account.status === 'disconnected') {
			console.log('[Wallet] Attempting auto-reconnect...');
			reconnect(config)
				.then((connections) => {
					console.log('[Wallet] Reconnect result:', {
						success: connections.length > 0,
						connections: connections.map((c) => ({
							accounts: c.accounts,
							chainId: c.chainId,
						})),
					});
				})
				.catch((err) => {
					// Silent fail - user may have explicitly disconnected
				console.debug('[Wallet] Reconnect attempt:', err);
			});
		}

		// Return cleanup function
		return () => {
			unwatchAccount();
			unwatchChainId();
			initialized = false;
		};
	}

	/**
	 * Injected target — either a wagmi built-in string ('metaMask', 'coinbaseWallet', 'phantom')
	 * or a full target object with provider resolution function.
	 */
	type InjectedTarget =
		| string
		| {
				id: string;
				name: string;
				provider: string | ((window: Window & Record<string, unknown>) => unknown);
		  };

	/**
	 * Connect wallet using injected provider
	 * @param target - Wallet target: a built-in string, a target object with provider function, or undefined for any injected wallet
	 */
	async function connectWallet(target?: InjectedTarget) {
		// SSR guard - should not be called during SSR
		if (!browser) {
			console.error('[Wallet] connectWallet called in non-browser environment');
			return;
		}

		const config = getConfig();
		if (!config) {
			error = 'Wallet configuration not available';
			console.error(
				'[Wallet] Config not available during connect - possible SSR leak or initialization race'
			);
			return;
		}

		try {
			error = null;
			status = 'connecting';
			console.log('[Wallet] Connecting...', { target: target ?? 'any injected' });

			// Import injected connector dynamically to create with target
			const { injected } = await import('@wagmi/connectors');

			// Create connector with specific target if provided
			const connector = injected({
				target: target as Parameters<typeof injected>[0]['target'],
				shimDisconnect: true,
			});

			const result = await connect(config, {
				connector,
			});

			address = result.accounts[0];
			chainId = result.chainId;
			status = 'connected';

			console.log('[Wallet] Connected successfully:', {
				address: result.accounts[0],
				chainId: result.chainId,
				isAcceptableChain: isAcceptableChain(result.chainId),
				expectedChain: defaultChain.id,
			});

			await refreshBalance();
		} catch (err) {
			status = 'disconnected';
			error = parseWalletError(err);
			console.error('[Wallet] Connection error:', err);
		}
	}

	/**
	 * Connect using WalletConnect
	 */
	async function connectWalletConnect() {
		// SSR guard - should not be called during SSR
		if (!browser) {
			console.error('[Wallet] connectWalletConnect called in non-browser environment');
			return;
		}

		const config = getConfig();
		if (!config) {
			error = 'Wallet configuration not available';
			console.error(
				'[Wallet] Config not available during WalletConnect - possible SSR leak or initialization race'
			);
			return;
		}

		try {
			error = null;
			status = 'connecting';

			const connectors = config.connectors;
			const wcConnector = connectors.find((c) => c.id === 'walletConnect');

			if (!wcConnector) {
				throw new Error('WalletConnect not configured. Add VITE_WALLETCONNECT_PROJECT_ID to .env');
			}

			const result = await connect(config, {
				connector: wcConnector,
			});

			address = result.accounts[0];
			chainId = result.chainId;
			status = 'connected';
			await refreshBalance();
		} catch (err) {
			status = 'disconnected';
			error = parseWalletError(err);
			console.error('[Wallet] WalletConnect error:', err);
		}
	}

	/**
	 * Disconnect wallet
	 */
	async function disconnectWallet() {
		// SSR guard - should not be called during SSR
		if (!browser) {
			console.error('[Wallet] disconnectWallet called in non-browser environment');
			return;
		}

		const config = getConfig();
		if (!config) {
			error = 'Wallet configuration not available';
			console.error(
				'[Wallet] Config not available during disconnect - possible SSR leak or initialization race'
			);
			return;
		}

		try {
			console.log('[Wallet] Disconnecting...', { currentAddress: address });
			await disconnect(config);
			console.log('[Wallet] Disconnected successfully');
			status = 'disconnected';
			address = null;
			chainId = null;
			ethBalance = 0n;
			connector = null;
			error = null;
		} catch (err) {
			console.error('[Wallet] Disconnect error:', err);
		}
	}

	/**
	 * Switch to the correct chain
	 */
	async function switchToCorrectChain() {
		// SSR guard - should not be called during SSR
		if (!browser) {
			console.error('[Wallet] switchToCorrectChain called in non-browser environment');
			return;
		}

		// Already on an acceptable chain
		if (chainId !== null && isAcceptableChain(chainId)) {
			error = null;
			return;
		}

		const config = getConfig();
		if (!config) {
			error = 'Wallet configuration not available';
			console.error(
				'[Wallet] Config not available during chain switch - possible SSR leak or initialization race'
			);
			return;
		}

		try {
			error = null;
			console.log('[Wallet] Switching to chain:', defaultChain.id);
			await switchChain(config, { chainId: defaultChain.id });
			console.log('[Wallet] Chain switch successful');
		} catch (err) {
			const errMsg = err instanceof Error ? err.message : '';

			// Handle "same RPC endpoint" conflict — user has old MegaETH chain (6342)
			// that shares the same RPC URL as the new chain (6343).
			// Fall back: try switching to the old chain since it's the same network.
			if (errMsg.includes('Could not add network that points to same RPC endpoint')) {
				console.log(
					'[Wallet] RPC conflict detected — trying legacy chain ID:',
					MEGAETH_TESTNET_LEGACY_CHAIN_ID
				);

				try {
					// Try switching to the old chain ID that's already in the wallet
					const provider = await connector?.getProvider();
					if (provider && 'request' in (provider as Record<string, unknown>)) {
						await (provider as { request: (args: unknown) => Promise<unknown> }).request({
							method: 'wallet_switchEthereumChain',
							params: [
								{ chainId: `0x${MEGAETH_TESTNET_LEGACY_CHAIN_ID.toString(16)}` },
							],
						});
						console.log('[Wallet] Switched to legacy chain ID successfully');
						error = null;
						return;
					}
				} catch (legacyErr) {
					console.error('[Wallet] Legacy chain switch also failed:', legacyErr);
				}
			}

			error = parseWalletError(err);
			console.error('[Wallet] Chain switch error:', err);
		}
	}

	/**
	 * Refresh ETH balance
	 */
	async function refreshBalance() {
		// SSR guard and address check - silent return is OK here since this is
		// a background refresh that may be called before connection
		if (!browser || !address) return;

		const config = getConfig();
		if (!config) {
			// Don't set error state for balance refresh - it's a background operation
			// and will retry on next refresh cycle
			console.warn('[Wallet] Config not available during balance refresh - will retry');
			return;
		}

		try {
			const balance = await getBalance(config, { address });
			ethBalance = balance.value;
		} catch (err) {
			console.error('[Wallet] Balance fetch error:', err);
		}
	}

	/**
	 * Clear error state
	 */
	function clearError() {
		error = null;
	}

	// ─────────────────────────────────────────────────────────────
	// Return Store Interface
	// ─────────────────────────────────────────────────────────────

	return {
		// State (getters for reactivity)
		get status() {
			return status;
		},
		get address() {
			return address;
		},
		get chainId() {
			return chainId;
		},
		get chainName() {
			return chainName;
		},
		get isCorrectChain() {
			return isCorrectChain;
		},
		get isWrongChain() {
			return isWrongChain;
		},
		get isConnected() {
			return isConnected;
		},
		get shortAddress() {
			return shortAddress;
		},
		get ethBalance() {
			return ethBalance;
		},
		get connector() {
			return connector;
		},
		get error() {
			return error;
		},

		// Actions
		init,
		connect: connectWallet,
		connectWalletConnect,
		disconnect: disconnectWallet,
		switchChain: switchToCorrectChain,
		refreshBalance,
		clearError,

		// Constants
		supportedChains,
		defaultChain,
	};
}

// ════════════════════════════════════════════════════════════════
// SINGLETON INSTANCE
// ════════════════════════════════════════════════════════════════

/** Global wallet store instance */
export const wallet = createWalletStore();
