/**
 * Settings Store
 * ===============
 * Manages user preferences with localStorage persistence.
 * 
 * Uses Svelte context for SSR safety - state is isolated per request.
 */

import { browser } from '$app/environment';
import { getContext, setContext } from 'svelte';

// ════════════════════════════════════════════════════════════════
// TYPES
// ════════════════════════════════════════════════════════════════

export interface Settings {
	/** Audio enabled */
	audioEnabled: boolean;
	/** Audio volume (0-1) */
	audioVolume: number;
	/** Visual effects enabled (screen flashes) */
	effectsEnabled: boolean;
	/** Scanlines overlay enabled */
	scanlinesEnabled: boolean;
	/** CRT flicker enabled */
	flickerEnabled: boolean;
}

export interface SettingsStore {
	audioEnabled: boolean;
	audioVolume: number;
	effectsEnabled: boolean;
	scanlinesEnabled: boolean;
	flickerEnabled: boolean;
	reset(): void;
}

// ════════════════════════════════════════════════════════════════
// CONSTANTS
// ════════════════════════════════════════════════════════════════

const DEFAULT_SETTINGS: Settings = {
	audioEnabled: true,
	audioVolume: 0.5,
	effectsEnabled: true,
	scanlinesEnabled: true,
	flickerEnabled: true
};

const STORAGE_KEY = 'ghostnet_settings';
const SETTINGS_CONTEXT_KEY = Symbol('settings-store');

// ════════════════════════════════════════════════════════════════
// PERSISTENCE HELPERS
// ════════════════════════════════════════════════════════════════

function loadSettings(): Settings {
	if (!browser) return DEFAULT_SETTINGS;

	try {
		const stored = localStorage.getItem(STORAGE_KEY);
		if (stored) {
			return { ...DEFAULT_SETTINGS, ...JSON.parse(stored) };
		}
	} catch (e) {
		console.warn('Failed to load settings:', e);
	}
	return DEFAULT_SETTINGS;
}

function saveSettings(settings: Settings): void {
	if (!browser) return;

	try {
		localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
	} catch (e) {
		console.warn('Failed to save settings:', e);
	}
}

// ════════════════════════════════════════════════════════════════
// STORE FACTORY
// ════════════════════════════════════════════════════════════════

/**
 * Create a new settings store instance.
 * This should be called once per request/page lifecycle.
 */
export function createSettingsStore(): SettingsStore {
	let settings = $state<Settings>(loadSettings());

	return {
		get audioEnabled() {
			return settings.audioEnabled;
		},
		set audioEnabled(value: boolean) {
			settings.audioEnabled = value;
			saveSettings(settings);
		},

		get audioVolume() {
			return settings.audioVolume;
		},
		set audioVolume(value: number) {
			settings.audioVolume = Math.max(0, Math.min(1, value));
			saveSettings(settings);
		},

		get effectsEnabled() {
			return settings.effectsEnabled;
		},
		set effectsEnabled(value: boolean) {
			settings.effectsEnabled = value;
			saveSettings(settings);
		},

		get scanlinesEnabled() {
			return settings.scanlinesEnabled;
		},
		set scanlinesEnabled(value: boolean) {
			settings.scanlinesEnabled = value;
			saveSettings(settings);
		},

		get flickerEnabled() {
			return settings.flickerEnabled;
		},
		set flickerEnabled(value: boolean) {
			settings.flickerEnabled = value;
			saveSettings(settings);
		},

		/** Reset all settings to defaults */
		reset() {
			settings = { ...DEFAULT_SETTINGS };
			saveSettings(settings);
		}
	};
}

// ════════════════════════════════════════════════════════════════
// CONTEXT HELPERS
// ════════════════════════════════════════════════════════════════

/**
 * Initialize the settings store and set it in context.
 * Call this once in your root +layout.svelte
 */
export function initializeSettings(): SettingsStore {
	const store = createSettingsStore();
	setContext(SETTINGS_CONTEXT_KEY, store);
	return store;
}

/**
 * Get the settings store from context.
 * Must be called from a component that is a descendant of the layout
 * where initializeSettings() was called.
 */
export function getSettings(): SettingsStore {
	const store = getContext<SettingsStore>(SETTINGS_CONTEXT_KEY);
	if (!store) {
		throw new Error(
			'Settings store not found in context. Make sure initializeSettings() was called in +layout.svelte'
		);
	}
	return store;
}
