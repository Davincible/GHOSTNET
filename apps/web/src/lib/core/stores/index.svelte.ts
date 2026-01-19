/**
 * GHOSTNET Store Setup
 * =====================
 * Central store configuration and context helpers
 */

import { getContext, setContext } from 'svelte';
import { createMockProvider } from '../providers/mock/provider.svelte';
import { DATA_PROVIDER_KEY, type DataProvider } from '../providers/types';

// ════════════════════════════════════════════════════════════════
// PROVIDER CONTEXT
// ════════════════════════════════════════════════════════════════

/**
 * Initialize the data provider and set it in context.
 * Call this in +layout.svelte
 */
export function initializeProvider(): DataProvider {
	// For now, always use mock provider
	// In production, this would check environment and use Web3Provider
	const provider = createMockProvider();
	setContext(DATA_PROVIDER_KEY, provider);
	return provider;
}

/**
 * Get the data provider from context.
 * Must be called from a component that is a child of the layout.
 */
export function getProvider(): DataProvider {
	const provider = getContext<DataProvider>(DATA_PROVIDER_KEY);
	if (!provider) {
		throw new Error(
			'DataProvider not found in context. Make sure initializeProvider() was called in +layout.svelte'
		);
	}
	return provider;
}

// ════════════════════════════════════════════════════════════════
// RE-EXPORTS
// ════════════════════════════════════════════════════════════════

// Re-export types for convenience
export type { DataProvider } from '../providers/types';
export { DATA_PROVIDER_KEY } from '../providers/types';
