/**
 * Wagmi Configuration
 * ====================
 * Core wagmi config for wallet connections
 * 
 * SSR-SAFE: Config is lazily initialized only in browser
 */

import { browser } from '$app/environment';
import { createConfig, http, type Config } from '@wagmi/core';
import { injected, walletConnect } from '@wagmi/connectors';
import { megaethTestnet, megaethMainnet, localhost } from './chains';

// ════════════════════════════════════════════════════════════════
// CONFIGURATION
// ════════════════════════════════════════════════════════════════

/**
 * WalletConnect project ID
 * Get yours at: https://cloud.walletconnect.com
 */
const WALLETCONNECT_PROJECT_ID = browser
	? (import.meta.env.VITE_WALLETCONNECT_PROJECT_ID as string) || ''
	: '';

/**
 * Singleton config instance (browser only)
 */
let _config: Config | null = null;

/**
 * Get or create wagmi config.
 * Returns null during SSR.
 */
export function getConfig(): Config | null {
	if (!browser) return null;

	if (!_config) {
		_config = createConfig({
			chains: [megaethTestnet, megaethMainnet, localhost],
			connectors: [
				// MetaMask, Coinbase, etc.
				injected({
					shimDisconnect: true
				}),
				// WalletConnect for mobile wallets
				...(WALLETCONNECT_PROJECT_ID
					? [
							walletConnect({
								projectId: WALLETCONNECT_PROJECT_ID,
								metadata: {
									name: 'GHOSTNET',
									description: 'High-stakes crypto survival game',
									url: 'https://ghostnet.io',
									icons: ['https://ghostnet.io/icon.png']
								},
								showQrModal: true
							})
						]
					: [])
			],
			transports: {
				[megaethTestnet.id]: http(),
				[megaethMainnet.id]: http(),
				[localhost.id]: http()
			}
		});
	}

	return _config;
}

/**
 * Get config or throw if not in browser.
 * Use this in functions that require config.
 */
export function requireConfig(): Config {
	const config = getConfig();
	if (!config) {
		throw new Error('Wagmi config not available (SSR context)');
	}
	return config;
}

// Legacy export for compatibility (will be null during SSR)
export const config = browser ? getConfig()! : (null as unknown as Config);
