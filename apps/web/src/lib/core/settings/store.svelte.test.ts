/**
 * Settings Store Tests
 * ====================
 * Tests for user preferences management with localStorage persistence.
 *
 * CRITICAL: File must have .svelte.test.ts extension for runes to work!
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { createSettingsStore, type SettingsStore } from './store.svelte';

// ============================================================================
// MOCKS
// ============================================================================

// Mock $app/environment - must be hoisted
vi.mock('$app/environment', () => ({
	browser: true
}));

// Mock localStorage
const localStorageMock = (() => {
	let store: Record<string, string> = {};
	return {
		getItem: vi.fn((key: string) => store[key] ?? null),
		setItem: vi.fn((key: string, value: string) => {
			store[key] = value;
		}),
		removeItem: vi.fn((key: string) => {
			delete store[key];
		}),
		clear: vi.fn(() => {
			store = {};
		}),
		get length() {
			return Object.keys(store).length;
		},
		key: vi.fn((index: number) => Object.keys(store)[index] ?? null),
		_getStore: () => store // Helper for debugging
	};
})();

Object.defineProperty(globalThis, 'localStorage', {
	value: localStorageMock,
	writable: true
});

// ============================================================================
// CONSTANTS
// ============================================================================

const STORAGE_KEY = 'ghostnet_settings';

const DEFAULT_SETTINGS = {
	audioEnabled: true,
	audioVolume: 0.5,
	effectsEnabled: true,
	scanlinesEnabled: true,
	flickerEnabled: true
};

// ============================================================================
// TESTS
// ============================================================================

describe('createSettingsStore', () => {
	let store: SettingsStore;

	beforeEach(() => {
		// Clear localStorage and mocks before each test
		localStorageMock.clear();
		vi.clearAllMocks();
	});

	afterEach(() => {
		vi.clearAllMocks();
	});

	describe('initial state', () => {
		it('loads default settings when no localStorage exists', () => {
			store = createSettingsStore();

			expect(store.audioEnabled).toBe(DEFAULT_SETTINGS.audioEnabled);
			expect(store.audioVolume).toBe(DEFAULT_SETTINGS.audioVolume);
			expect(store.effectsEnabled).toBe(DEFAULT_SETTINGS.effectsEnabled);
			expect(store.scanlinesEnabled).toBe(DEFAULT_SETTINGS.scanlinesEnabled);
			expect(store.flickerEnabled).toBe(DEFAULT_SETTINGS.flickerEnabled);
		});

		it('loads saved settings from localStorage', () => {
			// Pre-populate localStorage with custom settings
			const savedSettings = {
				audioEnabled: false,
				audioVolume: 0.8,
				effectsEnabled: false,
				scanlinesEnabled: false,
				flickerEnabled: true
			};
			localStorageMock.setItem(STORAGE_KEY, JSON.stringify(savedSettings));

			store = createSettingsStore();

			expect(store.audioEnabled).toBe(false);
			expect(store.audioVolume).toBe(0.8);
			expect(store.effectsEnabled).toBe(false);
			expect(store.scanlinesEnabled).toBe(false);
			expect(store.flickerEnabled).toBe(true);
		});

		it('merges partial saved settings with defaults', () => {
			// Only save some settings
			const partialSettings = {
				audioEnabled: false,
				audioVolume: 0.3
			};
			localStorageMock.setItem(STORAGE_KEY, JSON.stringify(partialSettings));

			store = createSettingsStore();

			// Saved values
			expect(store.audioEnabled).toBe(false);
			expect(store.audioVolume).toBe(0.3);
			// Default values for unsaved
			expect(store.effectsEnabled).toBe(DEFAULT_SETTINGS.effectsEnabled);
			expect(store.scanlinesEnabled).toBe(DEFAULT_SETTINGS.scanlinesEnabled);
			expect(store.flickerEnabled).toBe(DEFAULT_SETTINGS.flickerEnabled);
		});

		it('handles corrupted localStorage gracefully', () => {
			// Set invalid JSON
			localStorageMock.setItem(STORAGE_KEY, 'not valid json {{{');

			// Should not throw and should use defaults
			store = createSettingsStore();

			expect(store.audioEnabled).toBe(DEFAULT_SETTINGS.audioEnabled);
			expect(store.audioVolume).toBe(DEFAULT_SETTINGS.audioVolume);
		});
	});

	describe('persistence', () => {
		beforeEach(() => {
			store = createSettingsStore();
		});

		it('saves to localStorage when audioEnabled changes', () => {
			store.audioEnabled = false;

			expect(localStorageMock.setItem).toHaveBeenCalledWith(
				STORAGE_KEY,
				expect.stringContaining('"audioEnabled":false')
			);
		});

		it('saves to localStorage when audioVolume changes', () => {
			store.audioVolume = 0.75;

			expect(localStorageMock.setItem).toHaveBeenCalledWith(
				STORAGE_KEY,
				expect.stringContaining('"audioVolume":0.75')
			);
		});

		it('saves to localStorage when effectsEnabled changes', () => {
			store.effectsEnabled = false;

			expect(localStorageMock.setItem).toHaveBeenCalledWith(
				STORAGE_KEY,
				expect.stringContaining('"effectsEnabled":false')
			);
		});

		it('saves to localStorage when scanlinesEnabled changes', () => {
			store.scanlinesEnabled = false;

			expect(localStorageMock.setItem).toHaveBeenCalledWith(
				STORAGE_KEY,
				expect.stringContaining('"scanlinesEnabled":false')
			);
		});

		it('saves to localStorage when flickerEnabled changes', () => {
			store.flickerEnabled = false;

			expect(localStorageMock.setItem).toHaveBeenCalledWith(
				STORAGE_KEY,
				expect.stringContaining('"flickerEnabled":false')
			);
		});
	});

	describe('volume clamping', () => {
		beforeEach(() => {
			store = createSettingsStore();
		});

		it('clamps volume to minimum 0', () => {
			store.audioVolume = -0.5;

			expect(store.audioVolume).toBe(0);
		});

		it('clamps volume to maximum 1', () => {
			store.audioVolume = 1.5;

			expect(store.audioVolume).toBe(1);
		});

		it('accepts valid volume values', () => {
			store.audioVolume = 0.75;
			expect(store.audioVolume).toBe(0.75);

			store.audioVolume = 0;
			expect(store.audioVolume).toBe(0);

			store.audioVolume = 1;
			expect(store.audioVolume).toBe(1);
		});
	});

	describe('reset', () => {
		it('restores all defaults', () => {
			store = createSettingsStore();

			// Change all settings
			store.audioEnabled = false;
			store.audioVolume = 0.1;
			store.effectsEnabled = false;
			store.scanlinesEnabled = false;
			store.flickerEnabled = false;

			// Reset
			store.reset();

			// All should be back to defaults
			expect(store.audioEnabled).toBe(DEFAULT_SETTINGS.audioEnabled);
			expect(store.audioVolume).toBe(DEFAULT_SETTINGS.audioVolume);
			expect(store.effectsEnabled).toBe(DEFAULT_SETTINGS.effectsEnabled);
			expect(store.scanlinesEnabled).toBe(DEFAULT_SETTINGS.scanlinesEnabled);
			expect(store.flickerEnabled).toBe(DEFAULT_SETTINGS.flickerEnabled);
		});

		it('persists reset to localStorage', () => {
			store = createSettingsStore();
			store.audioEnabled = false;

			// Clear mock calls from the change
			vi.clearAllMocks();

			store.reset();

			// Should have saved the reset state
			expect(localStorageMock.setItem).toHaveBeenCalledWith(
				STORAGE_KEY,
				expect.any(String)
			);
		});
	});

	describe('multiple instances', () => {
		it('each instance has independent state', () => {
			const store1 = createSettingsStore();
			const store2 = createSettingsStore();

			store1.audioEnabled = false;

			// store2 loads from localStorage, which was just updated
			// This is expected behavior - they share persistence but not memory
			// In real app, we use context to ensure single instance
			expect(store1.audioEnabled).toBe(false);
			// store2 was created before the change, so it has its own state
			expect(store2.audioEnabled).toBe(true);
		});
	});
});
