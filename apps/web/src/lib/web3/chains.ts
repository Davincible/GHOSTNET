/**
 * MegaETH Chain Definitions
 * ==========================
 * Custom chain configs for viem/wagmi
 */

import { defineChain } from 'viem';

// ════════════════════════════════════════════════════════════════
// MEGAETH TESTNET V2
// ════════════════════════════════════════════════════════════════

export const megaethTestnet = defineChain({
	id: 6343,
	name: 'MegaETH Testnet',
	nativeCurrency: {
		decimals: 18,
		name: 'Ether',
		symbol: 'ETH',
	},
	rpcUrls: {
		default: {
			http: ['https://carrot.megaeth.com/rpc'],
		},
	},
	blockExplorers: {
		default: {
			name: 'Blockscout',
			url: 'https://megaeth-testnet-v2.blockscout.com',
		},
	},
	testnet: true,
});

// ════════════════════════════════════════════════════════════════
// MEGAETH MAINNET (FRONTIER)
// ════════════════════════════════════════════════════════════════

export const megaethMainnet = defineChain({
	id: 4326,
	name: 'MegaETH',
	nativeCurrency: {
		decimals: 18,
		name: 'Ether',
		symbol: 'ETH',
	},
	rpcUrls: {
		default: {
			http: ['https://mainnet.megaeth.com/rpc'],
		},
	},
	blockExplorers: {
		default: {
			name: 'Blockscout',
			url: 'https://megaeth.blockscout.com',
		},
	},
	testnet: false,
});

// ════════════════════════════════════════════════════════════════
// LOCAL ANVIL (DEVELOPMENT)
// ════════════════════════════════════════════════════════════════

export const localhost = defineChain({
	id: 31337,
	name: 'Localhost',
	nativeCurrency: {
		decimals: 18,
		name: 'Ether',
		symbol: 'ETH',
	},
	rpcUrls: {
		default: {
			http: ['http://127.0.0.1:8545'],
		},
	},
	testnet: true,
});

// ════════════════════════════════════════════════════════════════
// CHAIN SELECTION
// ════════════════════════════════════════════════════════════════

/** All supported chains */
export const supportedChains = [megaethTestnet, megaethMainnet, localhost] as const;

/** Default chain for development */
export const defaultChain = megaethTestnet;

/**
 * Legacy MegaETH testnet chain ID.
 * MegaETH changed their testnet from 6342 to 6343.
 * Many wallets still have the old chain configured with the same RPC endpoint,
 * which prevents adding the new chain ID. We accept both as valid.
 */
export const MEGAETH_TESTNET_LEGACY_CHAIN_ID = 6342;

/**
 * Check if a chain ID is an acceptable MegaETH testnet chain.
 * Accepts both legacy (6342) and current (6343) chain IDs since
 * they share the same RPC endpoint.
 */
export function isAcceptableChain(chainId: number): boolean {
	// Current default chain
	if (chainId === defaultChain.id) return true;

	// Legacy MegaETH testnet — same RPC, different chain ID
	if (defaultChain.id === megaethTestnet.id && chainId === MEGAETH_TESTNET_LEGACY_CHAIN_ID) {
		return true;
	}

	return false;
}

/** Get chain by ID */
export function getChainById(chainId: number) {
	return supportedChains.find((chain) => chain.id === chainId);
}
