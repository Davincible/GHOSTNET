/**
 * Ghost Maze - Audio
 * ===================
 * ZzFX sound effect definitions for all game events.
 * Uses playDynamic() for custom sound parameters.
 */

import type { AudioManager } from '$lib/core/audio';
import type { ZzFXParams } from '$lib/core/audio/zzfx';

export interface GhostMazeAudio {
	dataCollect(combo: number): void;
	powerNodeGrab(): void;
	ghostModeStart(): void;
	ghostModeEnd(): void;
	ghostModeWarning(): void;
	tracerDestroyed(): void;
	empDeploy(): void;
	playerHit(): void;
	respawn(): void;
	levelClear(): void;
	gameOver(): void;
	phantomTeleport(): void;
	comboMilestone(): void;
}

export function createGhostMazeAudio(audioManager: AudioManager): GhostMazeAudio {
	return {
		dataCollect(combo: number) {
			// Quick ascending blip, pitch rises with combo
			const pitch = 400 + combo * 20;
			const params: ZzFXParams = [0.5, , pitch, 0.01, 0.02, 0.03, 1, 1.5, , , , , , , , , , 0.5, 0.01];
			audioManager.playDynamic(params);
		},

		powerNodeGrab() {
			const params: ZzFXParams = [0.7, , 500, 0.02, 0.05, 0.1, 1, 1.2, , , 200, 0.05];
			audioManager.playDynamic(params);
		},

		ghostModeStart() {
			const params: ZzFXParams = [0.6, , 200, 0.05, 0.2, 0.3, 3, 0.5, 50];
			audioManager.playDynamic(params);
		},

		ghostModeEnd() {
			const params: ZzFXParams = [0.5, , 400, 0.05, 0.1, 0.2, 3, 0.5, -50];
			audioManager.playDynamic(params);
		},

		ghostModeWarning() {
			const params: ZzFXParams = [0.4, , 600, 0.01, 0.03, 0.02, 1, 2];
			audioManager.playDynamic(params);
		},

		tracerDestroyed() {
			const params: ZzFXParams = [0.6, , 300, 0.03, 0.05, 0.1, 4, 2, -10];
			audioManager.playDynamic(params);
		},

		empDeploy() {
			const params: ZzFXParams = [0.8, , 80, 0.1, 0.3, 0.4, 3, 0.3];
			audioManager.playDynamic(params);
		},

		playerHit() {
			const params: ZzFXParams = [0.7, , 200, 0.05, 0.15, 0.3, 4, 1, -20];
			audioManager.playDynamic(params);
		},

		respawn() {
			const params: ZzFXParams = [0.5, , 300, 0.02, 0.08, 0.15, 1, 1.5, 30];
			audioManager.playDynamic(params);
		},

		levelClear() {
			const params: ZzFXParams = [0.8, , 500, 0.03, 0.1, 0.3, 1, 1, 20, , 100, 0.05];
			audioManager.playDynamic(params);
		},

		gameOver() {
			const params: ZzFXParams = [0.6, , 300, 0.1, 0.2, 0.5, 3, 0.5, -30];
			audioManager.playDynamic(params);
		},

		phantomTeleport() {
			const params: ZzFXParams = [0.4, , 150, 0.05, 0.15, 0.2, 3, 2, 40];
			audioManager.playDynamic(params);
		},

		comboMilestone() {
			const params: ZzFXParams = [0.5, , 700, 0.02, 0.04, 0.06, 1, 1.8];
			audioManager.playDynamic(params);
		},
	};
}
