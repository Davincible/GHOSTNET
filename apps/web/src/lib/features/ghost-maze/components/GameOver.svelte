<script lang="ts">
	import { TOTAL_LEVELS, SCORE_THRESHOLDS } from '../constants';

	interface Props {
		score: number;
		levelsCleared: number;
		totalDataCollected: number;
		dataTotal: number;
		totalTracersDestroyed: number;
		maxCombo: number;
		perfectLevels: number;
		won: boolean;
		onPlayAgain: () => void;
		onExit: () => void;
	}

	let {
		score,
		levelsCleared,
		totalDataCollected,
		dataTotal,
		totalTracersDestroyed,
		maxCombo,
		perfectLevels,
		won,
		onPlayAgain,
		onExit,
	}: Props = $props();

	let achievement = $derived.by(() => {
		if (score >= SCORE_THRESHOLDS.MASTER) return 'MASTER';
		if (score >= SCORE_THRESHOLDS.EXPERT) return 'EXPERT';
		if (score >= SCORE_THRESHOLDS.SKILLED) return 'SKILLED';
		if (score >= SCORE_THRESHOLDS.COMPETENT) return 'COMPETENT';
		if (score >= SCORE_THRESHOLDS.SURVIVED) return 'SURVIVED';
		return 'TRACED';
	});

	let formattedScore = $derived(score.toLocaleString());
</script>

<div class="game-over" class:victory={won}>
	<h2 class="title">{won ? 'R U N   C O M P L E T E' : 'G A M E   O V E R'}</h2>

	<div class="results-box">
		<div class="result-row">
			<span class="label">FINAL SCORE:</span>
			<span class="value score-value">{formattedScore}</span>
		</div>
		<div class="result-row">
			<span class="label">LEVELS CLEARED:</span>
			<span class="value">{levelsCleared} / {TOTAL_LEVELS}</span>
		</div>
		<div class="result-row">
			<span class="label">DATA COLLECTED:</span>
			<span class="value">{totalDataCollected}</span>
		</div>
		<div class="result-row">
			<span class="label">TRACERS DESTROYED:</span>
			<span class="value">{totalTracersDestroyed}</span>
		</div>
		<div class="result-row">
			<span class="label">MAX COMBO:</span>
			<span class="value">{maxCombo}</span>
		</div>
		{#if perfectLevels > 0}
			<div class="result-row perfect">
				<span class="label">PERFECT LEVELS:</span>
				<span class="value">{perfectLevels}</span>
			</div>
		{/if}

		<div class="divider"></div>

		<div class="achievement">
			RANK: <span class="achievement-badge">{achievement}</span>
		</div>
	</div>

	<div class="actions">
		<button class="action-btn primary" onclick={onPlayAgain}>
			[ENTER] PLAY AGAIN
		</button>
		<button class="action-btn" onclick={onExit}>
			[ESC] EXIT TO ARCADE
		</button>
	</div>
</div>

<style>
	.game-over {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-6);
		padding: var(--space-8) var(--space-4);
		font-family: var(--font-mono);
		animation: fade-in 0.5s ease-out;
	}

	.title {
		font-size: var(--text-2xl);
		font-weight: bold;
		letter-spacing: var(--tracking-widest);
		color: var(--color-red);
		text-shadow: 0 0 8px var(--color-red-glow);
		margin: 0;
	}

	.victory .title {
		color: var(--color-accent-bright);
		text-shadow: 0 0 8px var(--color-accent-glow);
	}

	.results-box {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		padding: var(--space-4);
		border: 1px solid var(--color-border-default);
		min-width: 360px;
		background: var(--color-bg-secondary);
	}

	.result-row {
		display: flex;
		justify-content: space-between;
		gap: var(--space-4);
	}

	.label {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
	}

	.value {
		color: var(--color-accent);
		font-weight: bold;
		font-size: var(--text-sm);
	}

	.score-value {
		font-size: var(--text-lg);
		color: var(--color-accent-bright);
		text-shadow: 0 0 4px var(--color-accent-glow);
	}

	.perfect {
		color: #ffd700;
	}

	.perfect .value {
		color: #ffd700;
	}

	.divider {
		border-top: 1px solid var(--color-border-subtle);
		margin: var(--space-2) 0;
	}

	.achievement {
		text-align: center;
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
	}

	.achievement-badge {
		color: var(--color-amber);
		font-weight: bold;
		letter-spacing: var(--tracking-wider);
	}

	.actions {
		display: flex;
		gap: var(--space-4);
	}

	.action-btn {
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

	.action-btn:hover {
		border-color: var(--color-accent);
		color: var(--color-accent);
	}

	.action-btn.primary {
		border-color: var(--color-accent);
		color: var(--color-accent);
	}

	.action-btn.primary:hover {
		background: var(--color-accent-glow);
	}

	@keyframes fade-in {
		from { opacity: 0; transform: translateY(16px); }
		to { opacity: 1; transform: translateY(0); }
	}
</style>
