/**
 * Audio Manager
 * =============
 * Centralized audio system for GHOSTNET using ZzFX.
 * Integrates with settings store for volume and enable/disable.
 */

import { browser } from '$app/environment';
import { getSettings } from '$lib/core/settings';
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
	danger: [0.6, , 150, 0.01, 0.2, 0.15, 3, 1, , , , , 0.05, 0.3] as ZzFXParams
} as const;

export type SoundName = keyof typeof SOUNDS;

// ════════════════════════════════════════════════════════════════
// AUDIO MANAGER
// ════════════════════════════════════════════════════════════════

let initialized = false;

/**
 * Initialize audio system (call on first user interaction)
 */
export function initAudio(): void {
	if (!browser || initialized) return;
	initialized = true;
	resumeAudio();
}

/**
 * Play a sound effect
 */
export function playSound(name: SoundName): void {
	if (!browser) return;

	const settings = getSettings();
	if (!settings.audioEnabled) return;

	// Ensure audio context is resumed
	if (!initialized) {
		initAudio();
	}

	const params = SOUNDS[name];
	if (!params) {
		console.warn(`Unknown sound: ${name}`);
		return;
	}

	// Apply volume
	const volumeAdjusted = [...params] as ZzFXParams;
	volumeAdjusted[0] = (volumeAdjusted[0] ?? 1) * settings.audioVolume;

	try {
		zzfx(...volumeAdjusted);
	} catch (e) {
		// Audio might fail in certain contexts, ignore
	}
}

/**
 * Get the audio manager with all methods
 */
export function getAudioManager() {
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
		danger: () => playSound('danger')
	};
}
