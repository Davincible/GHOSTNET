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
	moveTick(): void;
	proximityWarning(distance: number): void;
	nearMiss(): void;
	comboBreak(): void;
	bonusAppear(): void;
	bonusCollect(): void;
	dangerZone(): void;
	scatterStart(): void;
	chaseStart(): void;
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

		moveTick() {
			// Soft mechanical click — very short, very quiet, high pitch
			const params: ZzFXParams = [0.15, , 1200, , 0.01, , 4, 2];
			audioManager.playDynamic(params);
		},

		proximityWarning(distance: number) {
			// Low heartbeat thump, volume scales inversely with distance
			const volume = Math.min(0.4, Math.max(0.1, 0.15 + (1 - distance / 4) * 0.25));
			const params: ZzFXParams = [volume, , 65, 0.02, 0.06, 0.1, 0, 0.5];
			audioManager.playDynamic(params);
		},

		nearMiss() {
			// Sharp whoosh — quick high-to-low sweep, slightly distorted
			const params: ZzFXParams = [0.4, , 900, , 0.04, 0.06, 3, 1.5, -80];
			audioManager.playDynamic(params);
		},

		comboBreak() {
			// Descending fail tone — 400 to 200Hz drop
			const params: ZzFXParams = [0.35, , 400, 0.01, 0.06, 0.08, 1, 1, -40];
			audioManager.playDynamic(params);
		},

		bonusAppear() {
			// Sparkly rising shimmer — treasure appearing
			const params: ZzFXParams = [0.4, , 600, 0.02, 0.08, 0.12, 1, 2, 30, , 150, 0.04];
			audioManager.playDynamic(params);
		},

		bonusCollect() {
			// Bright rewarding cha-ching — slightly louder than dataCollect
			const params: ZzFXParams = [0.6, , 800, 0.01, 0.04, 0.08, 1, 1.5, , , 400, 0.03];
			audioManager.playDynamic(params);
		},

		dangerZone() {
			// Ominous low rumble — sustained warning tone
			const params: ZzFXParams = [0.35, , 55, 0.1, 0.3, 0.4, 3, 0.3, , , , , , 0.2];
			audioManager.playDynamic(params);
		},

		scatterStart() {
			// Brief upward relief tone — relaxing
			const params: ZzFXParams = [0.4, , 350, 0.02, 0.06, 0.1, 1, 1.2, 25];
			audioManager.playDynamic(params);
		},

		chaseStart() {
			// Sharp staccato tension spike — alerting
			const params: ZzFXParams = [0.5, , 500, , 0.03, 0.02, 4, 2, , , , , , , , , , 0.4, 0.01];
			audioManager.playDynamic(params);
		},
	};
}
