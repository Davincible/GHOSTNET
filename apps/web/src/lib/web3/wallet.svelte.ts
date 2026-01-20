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
	getAccount,
	getBalance,
	watchAccount,
	watchChainId,
	switchChain,
	type GetAccountReturnType,
	type Connector
} from '@wagmi/core';
import {
	UserRejectedRequestError,
	ChainMismatchError
} from 'viem';
import { getConfig } from './config';
import { defaultChain, getChainById, supportedChains } from './chains';

// ════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════

export type WalletStatus = 'disconnected' | 'connecting' | 'connected' | 'reconnecting';

export interface WalletState {
	status: WalletStatus;
	address: `0x${string}` | null;
	chainId: number | null;
	chainName: string | null;
	isCorrectChain: boolean;
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

	const chainName = $derived(chainId ? getChainById(chainId)?.name ?? 'Unknown' : null);
	const isCorrectChain = $derived(chainId === defaultChain.id);
	const isConnected = $derived(status === 'connected' && address !== null);
	const shortAddress = $derived(
		address ? `${address.slice(0, 6)}...${address.slice(-4)}` : null
	);

	// ─────────────────────────────────────────────────────────────
	// Event Handlers
	// ─────────────────────────────────────────────────────────────

	async function handleAccountChange(account: GetAccountReturnType) {
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
	}

	async function handleChainChange(newChainId: number) {
		chainId = newChainId;
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
		if (!browser) return () => {};

		const config = getConfig();
		if (!config) return () => {};

		// Already initialized
		if (initialized) return () => {};
		initialized = true;

		// Watch account changes
		const unwatchAccount = watchAccount(config, {
			onChange: handleAccountChange
		});

		// Watch chain changes
		const unwatchChainId = watchChainId(config, {
			onChange: handleChainChange
		});

		// Check if already connected
		const account = getAccount(config);
		handleAccountChange(account);

		// Return cleanup function
		return () => {
			unwatchAccount();
			unwatchChainId();
			initialized = false;
		};
	}

	/**
	 * Connect wallet using injected provider (MetaMask, etc.)
	 */
	async function connectWallet() {
		if (!browser) return;

		const config = getConfig();
		if (!config) return;

		try {
			error = null;
			status = 'connecting';

			// Get available connectors
			const connectors = config.connectors;
			const injectedConnector = connectors.find((c) => c.id === 'injected');

			if (!injectedConnector) {
				throw new Error('No wallet detected. Please install MetaMask.');
			}

			const result = await connect(config, {
				connector: injectedConnector,
				chainId: defaultChain.id
			});

			address = result.accounts[0];
			chainId = result.chainId;
			status = 'connected';
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
		if (!browser) return;

		const config = getConfig();
		if (!config) return;

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
				chainId: defaultChain.id
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
		if (!browser) return;

		const config = getConfig();
		if (!config) return;

		try {
			await disconnect(config);
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
		if (!browser) return;

		const config = getConfig();
		if (!config) return;

		try {
			error = null;
			await switchChain(config, { chainId: defaultChain.id });
		} catch (err) {
			error = parseWalletError(err);
			console.error('[Wallet] Chain switch error:', err);
		}
	}

	/**
	 * Refresh ETH balance
	 */
	async function refreshBalance() {
		if (!browser || !address) return;

		const config = getConfig();
		if (!config) return;

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
		defaultChain
	};
}

// ════════════════════════════════════════════════════════════════
// SINGLETON INSTANCE
// ════════════════════════════════════════════════════════════════

/** Global wallet store instance */
export const wallet = createWalletStore();
