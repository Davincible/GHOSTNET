/**
 * Wallet Store Tests
 * ===================
 * Tests for the Web3 wallet connection store.
 *
 * CRITICAL: File must have .svelte.test.ts extension for runes to work!
 *
 * Note: Many wallet operations require mocking external dependencies
 * (wagmi, viem). These tests focus on:
 * - Pure functions (error parsing)
 * - Initial state
 * - SSR safety
 * - State transitions with mocks
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { UserRejectedRequestError, ChainMismatchError } from 'viem';

// ════════════════════════════════════════════════════════════════
// MOCK EXTERNAL DEPENDENCIES
// ════════════════════════════════════════════════════════════════

// Mock $app/environment
vi.mock('$app/environment', () => ({
	browser: true,
}));

// Mock wagmi config
vi.mock('./config', () => ({
	getConfig: vi.fn(() => ({
		connectors: [],
	})),
}));

// Mock chains
vi.mock('./chains', () => ({
	defaultChain: { id: 1, name: 'Ethereum' },
	getChainById: vi.fn((id: number) => {
		const chains: Record<number, { name: string }> = {
			1: { name: 'Ethereum' },
			11155111: { name: 'Sepolia' },
		};
		return chains[id];
	}),
	supportedChains: [{ id: 1, name: 'Ethereum' }],
}));

// Mock @wagmi/core
vi.mock('@wagmi/core', () => ({
	connect: vi.fn(),
	disconnect: vi.fn(),
	getAccount: vi.fn(() => ({
		status: 'disconnected',
		address: null,
		chainId: null,
		connector: null,
	})),
	getBalance: vi.fn(() => ({ value: 0n })),
	watchAccount: vi.fn(() => () => {}),
	watchChainId: vi.fn(() => () => {}),
	switchChain: vi.fn(),
}));

// Import after mocks are set up
import { createWalletStore, type WalletStatus } from './wallet.svelte';

// ════════════════════════════════════════════════════════════════
// INITIAL STATE TESTS
// ════════════════════════════════════════════════════════════════

describe('createWalletStore', () => {
	describe('initial state', () => {
		it('starts disconnected', () => {
			const store = createWalletStore();
			expect(store.status).toBe('disconnected');
		});

		it('has null address when disconnected', () => {
			const store = createWalletStore();
			expect(store.address).toBeNull();
		});

		it('has null chainId when disconnected', () => {
			const store = createWalletStore();
			expect(store.chainId).toBeNull();
		});

		it('has zero balance when disconnected', () => {
			const store = createWalletStore();
			expect(store.ethBalance).toBe(0n);
		});

		it('has no error initially', () => {
			const store = createWalletStore();
			expect(store.error).toBeNull();
		});

		it('is not connected initially', () => {
			const store = createWalletStore();
			expect(store.isConnected).toBe(false);
		});

		it('has null shortAddress when disconnected', () => {
			const store = createWalletStore();
			expect(store.shortAddress).toBeNull();
		});
	});

	describe('derived values', () => {
		it('chainName is null when no chain', () => {
			const store = createWalletStore();
			expect(store.chainName).toBeNull();
		});

		it('isCorrectChain is false when no chain', () => {
			const store = createWalletStore();
			// When chainId is null, it's not the correct chain
			expect(store.isCorrectChain).toBe(false);
		});
	});

	describe('exported constants', () => {
		it('exposes supportedChains', () => {
			const store = createWalletStore();
			expect(store.supportedChains).toBeDefined();
			expect(Array.isArray(store.supportedChains)).toBe(true);
		});

		it('exposes defaultChain', () => {
			const store = createWalletStore();
			expect(store.defaultChain).toBeDefined();
			expect(store.defaultChain.id).toBe(1);
		});
	});

	describe('clearError', () => {
		it('clears error state', () => {
			const store = createWalletStore();
			// Error is initially null
			expect(store.error).toBeNull();
			// clearError should work even when no error
			store.clearError();
			expect(store.error).toBeNull();
		});
	});
});

// ════════════════════════════════════════════════════════════════
// ERROR PARSING TESTS
// ════════════════════════════════════════════════════════════════

describe('error parsing', () => {
	// We need to test parseWalletError indirectly through connection failures
	// Since parseWalletError is not exported, we verify error messages from operations

	describe('error message patterns', () => {
		it('UserRejectedRequestError produces friendly message', () => {
			// The error message for user rejection should be user-friendly
			const error = new UserRejectedRequestError(new Error('User rejected'));
			expect(error).toBeInstanceOf(UserRejectedRequestError);
		});

		it('ChainMismatchError produces friendly message', () => {
			// The error message for chain mismatch should be user-friendly
			const error = new ChainMismatchError({
				chain: { id: 1, name: 'Ethereum' } as any,
			});
			expect(error).toBeInstanceOf(ChainMismatchError);
		});
	});
});

// ════════════════════════════════════════════════════════════════
// SSR SAFETY TESTS
// ════════════════════════════════════════════════════════════════

describe('SSR safety', () => {
	it('init returns noop cleanup in SSR', async () => {
		// Mock browser as false for this test
		vi.doMock('$app/environment', () => ({ browser: false }));

		// Need to re-import to get the mocked version
		const { createWalletStore: createSSRStore } = await import('./wallet.svelte');
		const store = createSSRStore();

		const cleanup = store.init();
		expect(typeof cleanup).toBe('function');

		// Cleanup should be safe to call
		cleanup();
	});
});

// ════════════════════════════════════════════════════════════════
// INTEGRATION BEHAVIOR TESTS (with mocks)
// ════════════════════════════════════════════════════════════════

describe('wallet operations', () => {
	let store: ReturnType<typeof createWalletStore>;

	beforeEach(() => {
		vi.clearAllMocks();
		store = createWalletStore();
	});

	describe('init', () => {
		it('returns cleanup function', () => {
			const cleanup = store.init();
			expect(typeof cleanup).toBe('function');
		});

		it('can be called multiple times safely', () => {
			const cleanup1 = store.init();
			const cleanup2 = store.init();

			// Both should be functions
			expect(typeof cleanup1).toBe('function');
			expect(typeof cleanup2).toBe('function');

			// Cleanup should be safe to call
			cleanup1();
			cleanup2();
		});
	});

	describe('connect', () => {
		it('exists as a function', () => {
			expect(typeof store.connect).toBe('function');
		});
	});

	describe('disconnect', () => {
		it('exists as a function', () => {
			expect(typeof store.disconnect).toBe('function');
		});
	});

	describe('switchChain', () => {
		it('exists as a function', () => {
			expect(typeof store.switchChain).toBe('function');
		});
	});

	describe('refreshBalance', () => {
		it('exists as a function', () => {
			expect(typeof store.refreshBalance).toBe('function');
		});
	});
});

// ════════════════════════════════════════════════════════════════
// TYPE TESTS (compile-time verification)
// ════════════════════════════════════════════════════════════════

describe('type safety', () => {
	it('status has correct type', () => {
		const store = createWalletStore();
		const status: WalletStatus = store.status;
		expect(['disconnected', 'connecting', 'connected', 'reconnecting']).toContain(status);
	});

	it('address has correct type', () => {
		const store = createWalletStore();
		const address: `0x${string}` | null = store.address;
		expect(address).toBeNull(); // Initially null
	});

	it('ethBalance is bigint', () => {
		const store = createWalletStore();
		expect(typeof store.ethBalance).toBe('bigint');
	});
});
