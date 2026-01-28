<script lang="ts">
	import { onMount } from 'svelte';
	import Box from '$lib/ui/terminal/Box.svelte';
	import MazeRenderer from './MazeRenderer.svelte';
	import HUD from './HUD.svelte';
	import LevelIntro from './LevelIntro.svelte';
	import GameOver from './GameOver.svelte';
	import PauseOverlay from './PauseOverlay.svelte';
	import { createGhostMazeStore, type GhostMazeStore } from '../store.svelte';
	import { LEVELS, TOTAL_LEVELS } from '../constants';
	import type { EntryTier } from '../types';

	interface Props {
		/** Optional external store (for testing) */
		store?: GhostMazeStore;
	}

	let { store: externalStore }: Props = $props();

	const store = externalStore ?? createGhostMazeStore();
	let gameState = $derived(store.state);
	let phase = $derived(gameState.phase);

	let isPlaying = $derived(
		phase === 'playing' ||
		phase === 'ghost_mode' ||
		phase === 'player_death' ||
		phase === 'respawn'
	);

	onMount(() => {
		return () => store.cleanup();
	});

	function handleStart(tier: EntryTier = 'free') {
		store.startGame(tier);
	}

	function handlePlayAgain() {
		store.startGame(gameState.entryTier);
	}

	function handleExit() {
		// Navigate back to arcade
		if (typeof window !== 'undefined') {
			window.location.href = '/arcade';
		}
	}

	function handleResume() {
		// Store handles pause/unpause via keyboard
		// This is a fallback for clicking the resume button
		const event = new KeyboardEvent('keydown', { key: 'Escape' });
		window.dispatchEvent(event);
	}

	function handleQuit() {
		store.cleanup();
		window.location.href = '/arcade';
	}
</script>

<div class="ghost-maze-game">
	<!-- Header -->
	<header class="game-header">
		<h1 class="game-title">GHOST MAZE</h1>
		{#if gameState.seed !== null}
			<span class="seed-display">SEED: {gameState.seed?.toString(16).toUpperCase().padStart(8, '0')}</span>
		{/if}
		{#if isPlaying}
			<span class="level-display">
				SECTOR: {LEVELS[gameState.currentLevel - 1]?.theme ?? 'UNKNOWN'}
			</span>
		{/if}
	</header>

	<!-- Game content -->
	<div class="game-content">
		{#if phase === 'idle'}
			<!-- Start screen -->
			<div class="start-screen">
				<div class="ascii-title">
					<pre class="title-art">{`
  ╔═══════════════════════════════╗
  ║     G H O S T   M A Z E      ║
  ║   Network Infiltration v1.0   ║
  ╚═══════════════════════════════╝`}</pre>
				</div>
				<p class="start-desc">
					Navigate the maze. Collect data. Evade tracers.<br/>
					You are the ghost in the machine.
				</p>
				<div class="start-actions">
					<button class="start-btn" onclick={() => handleStart('free')}>
						[F] FREE PLAY
					</button>
					<button class="start-btn paid" onclick={() => handleStart('standard')}>
						[S] STANDARD (25 $DATA)
					</button>
				</div>
				<div class="controls-info">
					<span>[WASD / Arrows] Move</span>
					<span>[SPACE] EMP</span>
					<span>[ESC] Pause</span>
				</div>
			</div>

		{:else if phase === 'level_intro'}
			<LevelIntro level={gameState.currentLevel} />

		{:else if isPlaying}
			<div class="game-area" style="position: relative;">
				<Box variant="double" borderColor={gameState.ghostModeActive ? 'cyan' : 'default'} borderFill>
					<MazeRenderer
						mazeText={store.mazeText}
						entities={store.renderEntities}
						maze={gameState.maze}
						ghostMode={gameState.ghostModeActive}
						invincible={gameState.isInvincible}
						dead={phase === 'player_death'}
					/>
				</Box>

				<HUD
					score={gameState.score}
					lives={gameState.lives}
					level={gameState.currentLevel}
					totalLevels={TOTAL_LEVELS}
					dataRemaining={gameState.dataRemaining}
					dataTotal={gameState.dataTotal}
					combo={gameState.combo}
					comboMultiplier={store.comboMultiplier}
					hasEmp={gameState.hasEmp}
					ghostModeActive={gameState.ghostModeActive}
					ghostModeRemaining={gameState.ghostModeRemaining}
				/>

				{#if phase === 'paused' || gameState.isPaused}
					<PauseOverlay
						onResume={handleResume}
						onQuit={handleQuit}
					/>
				{/if}
			</div>

		{:else if phase === 'level_clear'}
			<div class="level-clear">
				<h2 class="clear-title">L E V E L   C L E A R</h2>
				<p class="clear-score">+{(gameState.currentLevel * 1000).toLocaleString()} points</p>
			</div>

		{:else if phase === 'game_over' || phase === 'results'}
			<GameOver
				score={gameState.score}
				levelsCleared={gameState.levelsCleared}
				totalDataCollected={gameState.totalDataCollected}
				dataTotal={gameState.dataTotal}
				totalTracersDestroyed={gameState.totalTracersDestroyed}
				maxCombo={gameState.maxCombo}
				perfectLevels={gameState.perfectLevels}
				won={gameState.levelsCleared >= TOTAL_LEVELS}
				onPlayAgain={handlePlayAgain}
				onExit={handleExit}
			/>
		{/if}
	</div>

	<!-- Error display -->
	{#if gameState.error}
		<div class="error-banner">
			<span>[!]</span> {gameState.error}
		</div>
	{/if}
</div>

<style>
	.ghost-maze-game {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		padding: var(--space-4);
		max-width: 900px;
		margin: 0 auto;
	}

	/* Header */
	.game-header {
		display: flex;
		align-items: center;
		gap: var(--space-4);
		padding: var(--space-2) 0;
		border-bottom: 1px solid var(--color-border-subtle);
	}

	.game-title {
		font-family: var(--font-mono);
		font-size: var(--text-xl);
		font-weight: bold;
		letter-spacing: var(--tracking-widest);
		color: var(--color-accent);
		margin: 0;
	}

	.seed-display {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
		opacity: 0.5;
	}

	.level-display {
		margin-left: auto;
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-accent-mid);
		letter-spacing: var(--tracking-wider);
	}

	/* Game content */
	.game-content {
		min-height: 400px;
	}

	.game-area {
		position: relative;
	}

	/* Start screen */
	.start-screen {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-6);
		padding: var(--space-8) 0;
		font-family: var(--font-mono);
	}

	.title-art {
		color: var(--color-accent);
		text-shadow: 0 0 8px var(--color-accent-glow);
		font-size: var(--text-sm);
		margin: 0;
	}

	.start-desc {
		color: var(--color-text-secondary);
		text-align: center;
		font-size: var(--text-sm);
		line-height: 1.6;
		margin: 0;
	}

	.start-actions {
		display: flex;
		gap: var(--space-3);
	}

	.start-btn {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		padding: var(--space-2) var(--space-4);
		border: 1px solid var(--color-border-default);
		background: transparent;
		color: var(--color-text-secondary);
		cursor: pointer;
		letter-spacing: var(--tracking-wider);
		transition: all 0.15s;
	}

	.start-btn:hover {
		border-color: var(--color-accent);
		color: var(--color-accent);
	}

	.start-btn.paid {
		border-color: var(--color-accent-dim);
		color: var(--color-accent);
	}

	.start-btn.paid:hover {
		background: var(--color-accent-glow);
	}

	.controls-info {
		display: flex;
		gap: var(--space-4);
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
		opacity: 0.5;
	}

	/* Level clear */
	.level-clear {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-4);
		padding: var(--space-12) 0;
		font-family: var(--font-mono);
		animation: fade-in 0.3s ease-out;
	}

	.clear-title {
		font-size: var(--text-2xl);
		font-weight: bold;
		letter-spacing: var(--tracking-widest);
		color: var(--color-accent-bright);
		text-shadow: 0 0 12px var(--color-accent-glow);
		margin: 0;
	}

	.clear-score {
		color: var(--color-accent);
		font-size: var(--text-lg);
		margin: 0;
	}

	/* Error */
	.error-banner {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-3);
		border: 1px solid var(--color-red);
		color: var(--color-red);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		background: var(--color-red-glow);
	}

	@keyframes fade-in {
		from { opacity: 0; transform: translateY(8px); }
		to { opacity: 1; transform: translateY(0); }
	}
</style>
