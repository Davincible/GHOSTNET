<script lang="ts">
	import { MAZE_CHARS } from '../types';
	import { MAX_LIVES } from '../constants';

	interface Props {
		score: number;
		lives: number;
		level: number;
		totalLevels: number;
		dataRemaining: number;
		dataTotal: number;
		combo: number;
		comboMultiplier: number;
		hasEmp: boolean;
		ghostModeActive: boolean;
		ghostModeRemaining: number;
		ghostModeTotal: number;
		dangerZone: boolean;
		scatterChasePhase: 'scatter' | 'chase';
	}

	let {
		score,
		lives,
		level,
		totalLevels,
		dataRemaining,
		dataTotal,
		combo,
		comboMultiplier,
		hasEmp,
		ghostModeActive,
		ghostModeRemaining,
		ghostModeTotal,
		dangerZone,
		scatterChasePhase,
	}: Props = $props();

	let livesDisplay = $derived(
		MAZE_CHARS.LIFE_FULL.repeat(lives) + MAZE_CHARS.LIFE_EMPTY.repeat(Math.max(0, MAX_LIVES - lives))
	);

	let dataCollected = $derived(dataTotal - dataRemaining);

	let ghostProgress = $derived(
		ghostModeActive && ghostModeTotal > 0 ? Math.round((ghostModeRemaining / ghostModeTotal) * 10) : 0
	);
	let ghostBar = $derived(
		ghostModeActive
			? '\u2588'.repeat(ghostProgress) + '\u2591'.repeat(10 - ghostProgress)
			: ''
	);

	let formattedScore = $derived(score.toLocaleString());
</script>

<div class="hud" class:danger-zone={dangerZone}>
	<div class="hud-row">
		<span class="hud-item">SCORE: <span class="hud-value">{formattedScore}</span></span>
		<span class="hud-item">LIVES: <span class="hud-lives">{livesDisplay}</span></span>
		<span class="hud-item">LVL: <span class="hud-value">{level}/{totalLevels}</span></span>
		<span class="hud-item" class:data-danger={dangerZone}>
			DATA: <span class="hud-value">{dataCollected}/{dataTotal}</span>
		</span>
	</div>
	<div class="hud-row">
		{#if combo > 0}
			<span class="hud-item combo" class:combo-high={comboMultiplier >= 5}>
				COMBO: <span class="hud-value">&times;{comboMultiplier}</span>
				<span class="combo-count">({combo})</span>
			</span>
		{:else}
			<span class="hud-item hud-dim">COMBO: ---</span>
		{/if}
		<span class="hud-item" class:emp-ready={hasEmp} class:emp-used={!hasEmp}>
			EMP: [{hasEmp ? 'READY' : 'USED'}]
		</span>
		<span class="hud-item phase-indicator" class:phase-chase={scatterChasePhase === 'chase'}>
			{scatterChasePhase === 'chase' ? 'ALERT' : 'CLEAR'}
		</span>
		{#if ghostModeActive}
			<span class="hud-item ghost-bar">
				GHOST: <span class="ghost-progress">{ghostBar}</span>
			</span>
		{/if}
	</div>
	{#if dangerZone}
		<div class="hud-row danger-warning">
			<span class="danger-text">⚠ LOW DATA — TRACERS ACCELERATING</span>
		</div>
	{/if}
</div>

<style>
	.hud {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		padding: var(--space-2) 0;
		border-top: 1px solid var(--color-border-subtle);
	}

	.hud-row {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-4);
	}

	.hud-item {
		white-space: nowrap;
	}

	.hud-value {
		color: var(--color-accent);
		font-weight: bold;
	}

	.hud-lives {
		color: var(--color-red);
		letter-spacing: 2px;
	}

	.hud-dim {
		opacity: 0.4;
	}

	.combo {
		color: var(--color-amber);
	}

	.combo-high {
		color: #ffd700;
		text-shadow: 0 0 4px rgba(255, 215, 0, 0.4);
		animation: combo-glow 0.5s ease-in-out infinite alternate;
	}

	.combo-count {
		opacity: 0.6;
	}

	.emp-ready {
		color: var(--color-cyan);
	}

	.emp-used {
		opacity: 0.3;
	}

	.ghost-bar {
		color: var(--color-cyan);
	}

	.ghost-progress {
		letter-spacing: 1px;
		text-shadow: 0 0 4px var(--color-cyan-glow);
	}

	/* Scatter/Chase phase indicator */
	.phase-indicator {
		color: var(--color-accent-dim);
		opacity: 0.5;
	}

	.phase-chase {
		color: var(--color-red);
		opacity: 1;
		animation: chase-blink 0.8s ease-in-out infinite alternate;
	}

	/* Danger zone */
	.danger-zone {
		border-top-color: var(--color-red);
	}

	.data-danger {
		color: var(--color-red);
		animation: danger-pulse 0.6s ease-in-out infinite alternate;
	}

	.danger-warning {
		justify-content: center;
	}

	.danger-text {
		color: var(--color-red);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
		animation: danger-pulse 0.6s ease-in-out infinite alternate;
	}

	@keyframes combo-glow {
		from { text-shadow: 0 0 2px rgba(255, 215, 0, 0.2); }
		to { text-shadow: 0 0 8px rgba(255, 215, 0, 0.6); }
	}

	@keyframes chase-blink {
		from { opacity: 0.6; }
		to { opacity: 1; }
	}

	@keyframes danger-pulse {
		from { opacity: 0.5; }
		to { opacity: 1; text-shadow: 0 0 4px var(--color-red-glow); }
	}
</style>
