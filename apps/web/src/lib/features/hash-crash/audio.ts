/**
 * Hash Crash Audio Helper
 * =======================
 * Game-specific audio logic for Hash Crash including:
 * - Dynamic multiplier tick sounds (pitch increases with multiplier)
 * - Tension levels based on multiplier
 * - Win tier selection based on multiplier
 */

import type { AudioManager } from '$lib/core/audio';
import type { ZzFXParams } from '$lib/core/audio/zzfx';

// ============================================================================
// TYPES
// ============================================================================

export interface HashCrashAudio {
	/** Play sound when betting phase starts */
	bettingStart: () => void;
	/** Play sound when betting phase ends */
	bettingEnd: () => void;
	/** Play sound when multiplier starts rising */
	launch: () => void;
	/** Play dynamic multiplier tick (pitch based on current multiplier) */
	multiplierTick: (multiplier: number) => void;
	/** Play sound when player cashes out */
	cashOut: () => void;
	/** Play sound when another player cashes out */
	cashOutOther: () => void;
	/** Play crash explosion sound */
	crash: () => void;
	/** Play win sound (tier based on multiplier) */
	win: (multiplier: number) => void;
	/** Play loss sound */
	loss: () => void;
}

// ============================================================================
// DYNAMIC SOUND PARAMETERS
// ============================================================================

/**
 * Generate multiplier tick sound params based on current multiplier.
 * Pitch increases with multiplier for rising tension.
 */
function getMultiplierTickParams(multiplier: number): ZzFXParams {
	// Base pitch at 400Hz, increases up to 1200Hz
	const basePitch = 400 + Math.min(multiplier * 50, 800);
	// Volume slightly increases with multiplier
	const volume = 0.1 + Math.min(multiplier * 0.02, 0.15);
	return [volume, , basePitch, , 0.01, 0.02, , 1, , , 20, 0.01];
}

// ============================================================================
// FACTORY
// ============================================================================

/**
 * Create a Hash Crash audio helper.
 * Wraps the base audio manager with game-specific logic.
 */
export function createHashCrashAudio(audio: AudioManager): HashCrashAudio {
	// Track last tick time to prevent spam
	let lastTickTime = 0;
	const TICK_COOLDOWN = 100; // ms between ticks

	return {
		bettingStart: () => {
			audio.crashBettingStart();
		},

		bettingEnd: () => {
			audio.crashBettingEnd();
		},

		launch: () => {
			audio.crashLaunch();
		},

		multiplierTick: (multiplier: number) => {
			const now = Date.now();
			if (now - lastTickTime < TICK_COOLDOWN) return;
			lastTickTime = now;

			const params = getMultiplierTickParams(multiplier);
			audio.playDynamic(params);
		},

		cashOut: () => {
			audio.crashCashOut();
		},

		cashOutOther: () => {
			audio.crashCashOutOther();
		},

		crash: () => {
			audio.crashExplosion();
		},

		win: (multiplier: number) => {
			// Select win tier based on multiplier achieved
			if (multiplier < 2) {
				audio.crashWinSmall();
			} else if (multiplier < 5) {
				audio.crashWinMedium();
			} else if (multiplier < 20) {
				audio.crashWinBig();
			} else {
				audio.crashWinMassive();
			}
		},

		loss: () => {
			audio.crashLoss();
		},
	};
}
