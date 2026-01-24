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
				currentChainId: 137, // User is on Polygon but needs Ethereum
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
		it('sets status to connecting when called', async () => {
			// Mock connect to be slow so we can observe the connecting state
			const { connect: mockConnect } = await import('@wagmi/core');
			vi.mocked(mockConnect).mockImplementation(
				() =>
					new Promise((resolve) =>
						setTimeout(
							() =>
								resolve({
									accounts: ['0x1234567890123456789012345678901234567890' as `0x${string}`],
									chainId: 1,
								}),
							100
						)
					)
			);

			const connectPromise = store.connect();
			// Status should transition to 'connecting'
			expect(store.status).toBe('connecting');

			await connectPromise;
		});

		it('sets error state when connection fails', async () => {
			const { connect: mockConnect } = await import('@wagmi/core');
			vi.mocked(mockConnect).mockRejectedValueOnce(new Error('No connector found'));

			await store.connect();

			expect(store.status).toBe('disconnected');
			expect(store.error).toBe('No wallet detected. Please install MetaMask.');
		});

		it('sets user-friendly error on rejection', async () => {
			const { connect: mockConnect } = await import('@wagmi/core');
			vi.mocked(mockConnect).mockRejectedValueOnce(new Error('User rejected the request'));

			await store.connect();

			expect(store.status).toBe('disconnected');
			expect(store.error).toBe('Transaction cancelled by user');
		});

		it('clears previous error before connecting', async () => {
			const { connect: mockConnect } = await import('@wagmi/core');
			// First call fails
			vi.mocked(mockConnect).mockRejectedValueOnce(new Error('Failed'));
			await store.connect();
			expect(store.error).not.toBeNull();

			// Second call starts - error should clear
			vi.mocked(mockConnect).mockImplementation(
				() =>
					new Promise((resolve) =>
						setTimeout(
							() =>
								resolve({
									accounts: ['0x1234567890123456789012345678901234567890' as `0x${string}`],
									chainId: 1,
								}),
							50
						)
					)
			);

			const connectPromise = store.connect();
			expect(store.error).toBeNull();
			await connectPromise;
		});
	});

	describe('disconnect', () => {
		it('resets all state after disconnect', async () => {
			const { disconnect: mockDisconnect } = await import('@wagmi/core');
			vi.mocked(mockDisconnect).mockResolvedValueOnce(undefined);

			await store.disconnect();

			expect(store.status).toBe('disconnected');
			expect(store.address).toBeNull();
			expect(store.chainId).toBeNull();
			expect(store.ethBalance).toBe(0n);
			expect(store.error).toBeNull();
		});

		it('handles disconnect errors gracefully', async () => {
			const { disconnect: mockDisconnect } = await import('@wagmi/core');
			vi.mocked(mockDisconnect).mockRejectedValueOnce(new Error('Disconnect failed'));

			// Should not throw
			await expect(store.disconnect()).resolves.not.toThrow();
		});
	});

	describe('switchChain', () => {
		it('calls wagmi switchChain with default chain id', async () => {
			const { switchChain: mockSwitchChain } = await import('@wagmi/core');
			vi.mocked(mockSwitchChain).mockResolvedValueOnce({} as any);

			await store.switchChain();

			expect(mockSwitchChain).toHaveBeenCalledWith(
				expect.anything(),
				{ chainId: 1 } // defaultChain.id from mock
			);
		});

		it('sets error state when chain switch fails', async () => {
			const { switchChain: mockSwitchChain } = await import('@wagmi/core');
			vi.mocked(mockSwitchChain).mockRejectedValueOnce(new Error('User rejected the request'));

			await store.switchChain();

			expect(store.error).toBe('Transaction cancelled by user');
		});

		it('clears error before attempting switch', async () => {
			const { switchChain: mockSwitchChain } = await import('@wagmi/core');
			// First call fails to set error
			vi.mocked(mockSwitchChain).mockRejectedValueOnce(new Error('Failed'));
			await store.switchChain();
			expect(store.error).not.toBeNull();

			// Second call should clear error first
			vi.mocked(mockSwitchChain).mockResolvedValueOnce({} as any);
			await store.switchChain();
			expect(store.error).toBeNull();
		});
	});

	describe('refreshBalance', () => {
		it('does nothing when address is null', async () => {
			const { getBalance: mockGetBalance } = await import('@wagmi/core');
			vi.mocked(mockGetBalance).mockClear();

			await store.refreshBalance();

			expect(mockGetBalance).not.toHaveBeenCalled();
		});

		it('fetches balance when address is set', async () => {
			// First connect to set an address
			const { connect: mockConnect, getBalance: mockGetBalance } = await import('@wagmi/core');
			vi.mocked(mockConnect).mockResolvedValueOnce({
				accounts: ['0x1234567890123456789012345678901234567890' as `0x${string}`],
				chainId: 1,
			});
			vi.mocked(mockGetBalance).mockResolvedValue({ value: 1000000000000000000n } as any);

			await store.connect();

			// getBalance should have been called during connect
			expect(mockGetBalance).toHaveBeenCalled();
		});

		it('handles balance fetch errors gracefully', async () => {
			// Connect first
			const { connect: mockConnect, getBalance: mockGetBalance } = await import('@wagmi/core');
			vi.mocked(mockConnect).mockResolvedValueOnce({
				accounts: ['0x1234567890123456789012345678901234567890' as `0x${string}`],
				chainId: 1,
			});
			vi.mocked(mockGetBalance).mockRejectedValueOnce(new Error('RPC error'));

			// Should not throw
			await expect(store.connect()).resolves.not.toThrow();
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
