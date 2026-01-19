/**
 * Settings Store
 * ===============
 * Manages user preferences with localStorage persistence.
 */

import { browser } from '$app/environment';

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

const DEFAULT_SETTINGS: Settings = {
	audioEnabled: true,
	audioVolume: 0.5,
	effectsEnabled: true,
	scanlinesEnabled: true,
	flickerEnabled: false
};

const STORAGE_KEY = 'ghostnet_settings';

// ════════════════════════════════════════════════════════════════
// STORE
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

// Singleton state
let settings = $state<Settings>(loadSettings());

/**
 * Get the settings store
 */
export function getSettings() {
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
