/**
 * Audio Manager
 * =============
 * Centralized audio system for GHOSTNET using ZzFX.
 * Integrates with settings store for volume and enable/disable.
 *
 * IMPORTANT: The audio manager must be initialized during component
 * initialization (not in callbacks) to properly capture the settings context.
 */

import { browser } from '$app/environment';
import type { SettingsStore } from '$lib/core/settings';
import { zzfx, resumeAudio, type ZzFXParams } from './zzfx';

// ════════════════════════════════════════════════════════════════
// SOUND DEFINITIONS
// ════════════════════════════════════════════════════════════════

// Sound presets tuned for cyberpunk/terminal aesthetic
const SOUNDS = {
	// UI Sounds
	click: [0.3, , 800, , 0.01, 0.01, , 1, , , , , , , , , , 0.5] as ZzFXParams,
	hover: [0.1, , 1200, , 0.01, 0.01, , 1, , , , , , , , , , 0.3] as ZzFXParams,
	open: [0.3, , 400, 0.01, 0.02, 0.05, , 1, , , 100, 0.01] as ZzFXParams,
	close: [0.3, , 600, 0.01, 0.01, 0.03, , 1, , , -100, 0.01] as ZzFXParams,
	error: [0.5, , 200, 0.01, 0.05, 0.1, 4, 1, , , , , , 0.5] as ZzFXParams,
	success: [0.4, , 600, 0.01, 0.05, 0.1, , 1, , , 200, 0.02] as ZzFXParams,

	// Typing Game
	keystroke: [0.1, , 1000, , 0.01, 0.01, , 1, , , , , , , , , , 0.3] as ZzFXParams,
	keystrokeError: [0.2, , 200, , 0.02, 0.03, 4, 1, , , , , , 0.3] as ZzFXParams,
	countdown: [0.4, , 400, 0.01, 0.05, 0.1, , 1, , , 50, 0.05] as ZzFXParams,
	countdownGo: [0.5, , 600, 0.01, 0.1, 0.2, , 1, , , 200, 0.05] as ZzFXParams,
	roundComplete: [0.4, , 500, 0.02, 0.1, 0.2, , 1, , , 100, 0.02, , , , , , 0.8] as ZzFXParams,
	gameComplete: [0.5, , 400, 0.02, 0.2, 0.3, , 1, 5, , 200, 0.05, 0.1] as ZzFXParams,

	// Feed Events
	jackIn: [0.4, , 300, 0.02, 0.1, 0.2, , 1, , , 100, 0.05] as ZzFXParams,
	extract: [0.4, , 500, 0.02, 0.1, 0.15, , 1, , , -100, 0.05] as ZzFXParams,
	traced: [0.6, , 100, 0.01, 0.2, 0.3, 3, 1, , , , , , 0.5, , 0.5] as ZzFXParams,
	survived: [0.4, , 600, 0.01, 0.1, 0.2, , 1, , , 150, 0.03] as ZzFXParams,
	jackpot: [0.6, , 300, 0.02, 0.3, 0.4, , 1, 3, , 200, 0.05, 0.1, , , , 0.1, 0.9] as ZzFXParams,
	scanWarning: [0.4, , 250, 0.01, 0.1, 0.05, 2, 1, , , , , 0.1] as ZzFXParams,
	scanStart: [0.5, , 200, 0.02, 0.15, 0.1, 2, 1, , , , , 0.05] as ZzFXParams,

	// Alerts
	alert: [0.5, , 300, 0.01, 0.1, 0.1, 2, 1, , , , , 0.05] as ZzFXParams,
	warning: [0.5, , 200, 0.01, 0.15, 0.1, 2, 1, , , , , 0.1] as ZzFXParams,
	danger: [0.6, , 150, 0.01, 0.2, 0.15, 3, 1, , , , , 0.05, 0.3] as ZzFXParams,

	// Hash Crash
	crashBettingStart: [0.3, , 500, 0.01, 0.05, 0.08, , 1, , , 50, 0.02] as ZzFXParams,
	crashBettingEnd: [0.4, , 400, 0.01, 0.05, 0.1, , 1, , , 50, 0.05] as ZzFXParams,
	crashLaunch: [0.4, , 300, 0.02, 0.1, 0.2, , 1, , , 100, 0.02] as ZzFXParams,
	crashCashOut: [0.5, , 700, 0.01, 0.05, 0.1, , 1, , , 200, 0.02] as ZzFXParams,
	crashCashOutOther: [0.2, , 600, , 0.02, 0.03, , 1, , , 100, 0.01] as ZzFXParams,
	crashExplosion: [0.8, , 100, 0.01, 0.3, 0.5, 4, 1, -10, , -200, 0.1, , 0.8, , 0.2] as ZzFXParams,
	crashWinSmall: [0.4, , 600, 0.02, 0.1, 0.2, , 1, , , 100, 0.02, , , , , , 0.8] as ZzFXParams,
	crashWinMedium: [0.5, , 500, 0.02, 0.15, 0.25, , 1, 3, , 150, 0.03, 0.05] as ZzFXParams,
	crashWinBig: [
		0.6,
		,
		400,
		0.03,
		0.2,
		0.35,
		,
		1,
		5,
		,
		200,
		0.05,
		0.1,
		,
		,
		,
		0.1,
		0.9,
	] as ZzFXParams,
	crashWinMassive: [
		0.7,
		,
		300,
		0.03,
		0.3,
		0.4,
		,
		1,
		7,
		,
		250,
		0.07,
		0.15,
		,
		,
		,
		0.15,
		0.95,
	] as ZzFXParams,
	crashLoss: [0.4, , 250, 0.02, 0.15, 0.3, 3, 1, -3, , -100, 0.05, , 0.2] as ZzFXParams,
} as const;

export type SoundName = keyof typeof SOUNDS;

// ════════════════════════════════════════════════════════════════
// AUDIO MANAGER INTERFACE
// ════════════════════════════════════════════════════════════════

export interface AudioManager {
	init: () => void;
	play: (name: SoundName) => void;
	// Convenience methods
	click: () => void;
	hover: () => void;
	open: () => void;
	close: () => void;
	error: () => void;
	success: () => void;
	// Typing game
	keystroke: () => void;
	keystrokeError: () => void;
	countdown: () => void;
	countdownGo: () => void;
	roundComplete: () => void;
	gameComplete: () => void;
	// Feed events
	jackIn: () => void;
	extract: () => void;
	traced: () => void;
	survived: () => void;
	jackpot: () => void;
	scanWarning: () => void;
	scanStart: () => void;
	// Alerts
	alert: () => void;
	warning: () => void;
	danger: () => void;
	// Hash Crash
	crashBettingStart: () => void;
	crashBettingEnd: () => void;
	crashLaunch: () => void;
	crashCashOut: () => void;
	crashCashOutOther: () => void;
	crashExplosion: () => void;
	crashWinSmall: () => void;
	crashWinMedium: () => void;
	crashWinBig: () => void;
	crashWinMassive: () => void;
	crashLoss: () => void;
	// Dynamic sound (for custom params)
	playDynamic: (params: ZzFXParams) => void;
}

// ════════════════════════════════════════════════════════════════
// MODULE STATE
// ════════════════════════════════════════════════════════════════

let audioInitialized = false;
let settingsRef: SettingsStore | null = null;

// ════════════════════════════════════════════════════════════════
// CORE FUNCTIONS
// ════════════════════════════════════════════════════════════════

/**
 * Initialize audio system (call on first user interaction)
 */
export function initAudio(): void {
	if (!browser || audioInitialized) return;
	audioInitialized = true;
	resumeAudio();
}

/**
 * Play a sound effect
 * Uses the settings reference captured during createAudioManager()
 */
function playSound(name: SoundName): void {
	if (!browser) return;

	// Check settings if available
	if (settingsRef && !settingsRef.audioEnabled) return;

	// Ensure audio context is resumed
	if (!audioInitialized) {
		initAudio();
	}

	const params = SOUNDS[name];
	if (!params) {
		console.warn(`Unknown sound: ${name}`);
		return;
	}

	// Apply volume from settings
	const volume = settingsRef?.audioVolume ?? 0.5;
	const volumeAdjusted = [...params] as ZzFXParams;
	volumeAdjusted[0] = (volumeAdjusted[0] ?? 1) * volume;

	try {
		zzfx(...volumeAdjusted);
	} catch {
		// Audio might fail in certain contexts, ignore
	}
}

/**
 * Play a sound with custom ZzFX parameters (for dynamic sounds)
 */
function playDynamic(params: ZzFXParams): void {
	if (!browser) return;
	if (settingsRef && !settingsRef.audioEnabled) return;

	if (!audioInitialized) {
		initAudio();
	}

	const volume = settingsRef?.audioVolume ?? 0.5;
	const volumeAdjusted = [...params] as ZzFXParams;
	volumeAdjusted[0] = (volumeAdjusted[0] ?? 1) * volume;

	try {
		zzfx(...volumeAdjusted);
	} catch {
		// Ignore
	}
}

// ════════════════════════════════════════════════════════════════
// FACTORY FUNCTION
// ════════════════════════════════════════════════════════════════

/**
 * Create an audio manager with settings integration.
 *
 * MUST be called during component initialization to capture the settings context.
 * The returned manager can then be used in callbacks.
 *
 * @param settings - The settings store from getSettings()
 */
export function createAudioManager(settings: SettingsStore): AudioManager {
	// Store reference for use in playSound
	settingsRef = settings;

	return {
		init: initAudio,
		play: playSound,

		// Convenience methods
		click: () => playSound('click'),
		hover: () => playSound('hover'),
		open: () => playSound('open'),
		close: () => playSound('close'),
		error: () => playSound('error'),
		success: () => playSound('success'),

		// Typing game
		keystroke: () => playSound('keystroke'),
		keystrokeError: () => playSound('keystrokeError'),
		countdown: () => playSound('countdown'),
		countdownGo: () => playSound('countdownGo'),
		roundComplete: () => playSound('roundComplete'),
		gameComplete: () => playSound('gameComplete'),

		// Feed events
		jackIn: () => playSound('jackIn'),
		extract: () => playSound('extract'),
		traced: () => playSound('traced'),
		survived: () => playSound('survived'),
		jackpot: () => playSound('jackpot'),
		scanWarning: () => playSound('scanWarning'),
		scanStart: () => playSound('scanStart'),

		// Alerts
		alert: () => playSound('alert'),
		warning: () => playSound('warning'),
		danger: () => playSound('danger'),

		// Hash Crash
		crashBettingStart: () => playSound('crashBettingStart'),
		crashBettingEnd: () => playSound('crashBettingEnd'),
		crashLaunch: () => playSound('crashLaunch'),
		crashCashOut: () => playSound('crashCashOut'),
		crashCashOutOther: () => playSound('crashCashOutOther'),
		crashExplosion: () => playSound('crashExplosion'),
		crashWinSmall: () => playSound('crashWinSmall'),
		crashWinMedium: () => playSound('crashWinMedium'),
		crashWinBig: () => playSound('crashWinBig'),
		crashWinMassive: () => playSound('crashWinMassive'),
		crashLoss: () => playSound('crashLoss'),

		// Dynamic
		playDynamic,
	};
}

// ════════════════════════════════════════════════════════════════
// LEGACY SUPPORT (for components that don't need settings)
// ════════════════════════════════════════════════════════════════

/**
 * Get an audio manager without settings integration.
 * Audio will play at default volume (0.5) and always be enabled.
 *
 * @deprecated Use createAudioManager(settings) for proper settings integration
 */
export function getAudioManager(): AudioManager {
	return {
		init: initAudio,
		play: playSound,

		// Convenience methods
		click: () => playSound('click'),
		hover: () => playSound('hover'),
		open: () => playSound('open'),
		close: () => playSound('close'),
		error: () => playSound('error'),
		success: () => playSound('success'),

		// Typing game
		keystroke: () => playSound('keystroke'),
		keystrokeError: () => playSound('keystrokeError'),
		countdown: () => playSound('countdown'),
		countdownGo: () => playSound('countdownGo'),
		roundComplete: () => playSound('roundComplete'),
		gameComplete: () => playSound('gameComplete'),

		// Feed events
		jackIn: () => playSound('jackIn'),
		extract: () => playSound('extract'),
		traced: () => playSound('traced'),
		survived: () => playSound('survived'),
		jackpot: () => playSound('jackpot'),
		scanWarning: () => playSound('scanWarning'),
		scanStart: () => playSound('scanStart'),

		// Alerts
		alert: () => playSound('alert'),
		warning: () => playSound('warning'),
		danger: () => playSound('danger'),

		// Hash Crash
		crashBettingStart: () => playSound('crashBettingStart'),
		crashBettingEnd: () => playSound('crashBettingEnd'),
		crashLaunch: () => playSound('crashLaunch'),
		crashCashOut: () => playSound('crashCashOut'),
		crashCashOutOther: () => playSound('crashCashOutOther'),
		crashExplosion: () => playSound('crashExplosion'),
		crashWinSmall: () => playSound('crashWinSmall'),
		crashWinMedium: () => playSound('crashWinMedium'),
		crashWinBig: () => playSound('crashWinBig'),
		crashWinMassive: () => playSound('crashWinMassive'),
		crashLoss: () => playSound('crashLoss'),

		// Dynamic
		playDynamic,
	};
}
