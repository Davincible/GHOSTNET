// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces

declare global {
	namespace App {
		// interface Error {}
		// interface Locals {}
		// interface PageData {}
		// interface PageState {}
		// interface Platform {}
	}

	// ════════════════════════════════════════════════════════════════
	// EIP-1193 ETHEREUM PROVIDER
	// ════════════════════════════════════════════════════════════════

	/**
	 * EIP-1193 Provider interface for browser wallets.
	 * @see https://eips.ethereum.org/EIPS/eip-1193
	 */
	interface EIP1193Provider {
		/** Submits RPC request */
		request(args: { method: string; params?: unknown[] }): Promise<unknown>;
		/** Subscribe to events */
		on(event: string, listener: (...args: unknown[]) => void): void;
		/** Unsubscribe from events */
		removeListener(event: string, listener: (...args: unknown[]) => void): void;
	}

	/**
	 * Extended Ethereum provider with wallet detection flags.
	 * Different wallets inject different flags to identify themselves.
	 */
	interface EthereumProvider extends EIP1193Provider {
		/** MetaMask detection */
		isMetaMask?: boolean;
		/** Coinbase Wallet detection */
		isCoinbaseWallet?: boolean;
		/** Brave Wallet detection */
		isBraveWallet?: boolean;
		/** Trust Wallet detection */
		isTrust?: boolean;
		/** Rainbow Wallet detection */
		isRainbow?: boolean;
		/** Generic frame detection (for iframe wallets) */
		isFrame?: boolean;
		/** Provider chain ID (hex string) */
		chainId?: string;
		/** Selected address (deprecated but still used) */
		selectedAddress?: string | null;
		/** Whether provider is connected */
		isConnected?: () => boolean;
	}

	interface Window {
		/**
		 * Injected Ethereum provider (MetaMask, Coinbase, etc.)
		 * @see https://eips.ethereum.org/EIPS/eip-1193
		 */
		ethereum?: EthereumProvider;
	}
}

export {};
