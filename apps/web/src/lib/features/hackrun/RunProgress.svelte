<script lang="ts">
	import { ProgressBar } from '$lib/ui/primitives';
	import { AmountDisplay } from '$lib/ui/data-display';
	import { Row } from '$lib/ui/layout';
	import type { HackRunDifficulty } from '$lib/core/types/hackrun';

	interface Props {
		/** Run difficulty for display */
		difficulty: HackRunDifficulty;
		/** Time remaining in milliseconds */
		timeRemaining: number;
		/** Total time limit in milliseconds */
		timeLimit: number;
		/** Current accumulated multiplier */
		currentMultiplier: number;
		/** Total loot collected */
		totalLoot: bigint;
	}

	let { difficulty, timeRemaining, timeLimit, currentMultiplier, totalLoot }: Props = $props();

	// Calculate time display
	let minutes = $derived(Math.floor(timeRemaining / 60000));
	let seconds = $derived(Math.floor((timeRemaining % 60000) / 1000));
	let timeDisplay = $derived(
		`${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
	);

	// Total time display
	let totalMinutes = $derived(Math.floor(timeLimit / 60000));
	let totalSeconds = $derived(Math.floor((timeLimit % 60000) / 1000));
	let totalTimeDisplay = $derived(
		`${String(totalMinutes).padStart(2, '0')}:${String(totalSeconds).padStart(2, '0')}`
	);

	// Progress percentage
	let progressPercent = $derived(Math.max(0, Math.min(100, (timeRemaining / timeLimit) * 100)));

	// Is time low?
	let isUrgent = $derived(timeRemaining < 30000); // Less than 30 seconds
	let isCritical = $derived(timeRemaining < 15000); // Less than 15 seconds

	// Difficulty label
	const difficultyLabels: Record<HackRunDifficulty, string> = {
		easy: 'EASY',
		medium: 'MEDIUM',
		hard: 'HARD',
	};
</script>

<div class="run-progress">
	<div class="progress-header">
		<span class="run-title">HACK RUN - {difficultyLabels[difficulty]}</span>
	</div>

	<div class="progress-stats">
		<Row justify="between" align="center" gap={4}>
			<div class="stat stat-time" class:stat-urgent={isUrgent} class:stat-critical={isCritical}>
				<span class="stat-label">TIME:</span>
				<span class="stat-value">{timeDisplay}</span>
				<span class="stat-divider">/</span>
				<span class="stat-total">{totalTimeDisplay}</span>
			</div>

			<div class="stat stat-multiplier">
				<span class="stat-label">MULT:</span>
				<span class="stat-value">{currentMultiplier.toFixed(1)}x</span>
			</div>

			<div class="stat stat-loot">
				<span class="stat-label">LOOT:</span>
				<span class="stat-value">
					+<AmountDisplay amount={totalLoot} format="compact" />
				</span>
			</div>
		</Row>
	</div>

	<div class="progress-bar-container">
		<ProgressBar
			value={progressPercent}
			variant={isCritical ? 'danger' : isUrgent ? 'warning' : 'default'}
			width={40}
			animated={isUrgent}
		/>
	</div>
</div>

<style>
	.run-progress {
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-subtle);
		padding: var(--space-3);
	}

	.progress-header {
		margin-bottom: var(--space-2);
	}

	.run-title {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	.progress-stats {
		margin-bottom: var(--space-2);
	}

	.stat {
		display: flex;
		align-items: baseline;
		gap: var(--space-1);
	}

	.stat-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wide);
	}

	.stat-value {
		color: var(--color-text-primary);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		font-variant-numeric: tabular-nums;
	}

	.stat-divider {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
	}

	.stat-total {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
	}

	/* Multiplier styling */
	.stat-multiplier .stat-value {
		color: var(--color-accent);
	}

	/* Loot styling */
	.stat-loot .stat-value {
		color: var(--color-profit);
	}

	/* Time urgency states */
	.stat-urgent .stat-value {
		color: var(--color-amber);
	}

	.stat-critical .stat-value {
		color: var(--color-red);
		animation: pulse-urgent 0.5s ease-in-out infinite;
	}

	.progress-bar-container {
		margin-top: var(--space-1);
	}

	@keyframes pulse-urgent {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.5;
		}
	}
</style>
