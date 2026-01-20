<script lang="ts">
	import type { HackRun, HackRunResult } from '$lib/core/types/hackrun';
	import { Box } from '$lib/ui/terminal';
	import { Stack, Row } from '$lib/ui/layout';
	import { Button } from '$lib/ui/primitives';
	import { AmountDisplay } from '$lib/ui/data-display';
	import { MULTIPLIER_DURATION } from './generators';

	interface Props {
		/** Completed run */
		run: HackRun;
		/** Run result */
		result: HackRunResult;
		/** Callback to start a new run */
		onNewRun?: () => void;
		/** Callback to return to dashboard */
		onExit?: () => void;
	}

	let { run, result, onNewRun, onExit }: Props = $props();

	// Format duration
	function formatDuration(ms: number): string {
		const hours = Math.floor(ms / 3600000);
		return `${hours} HOURS`;
	}

	// Format elapsed time
	function formatElapsed(ms: number): string {
		const totalSeconds = Math.floor(ms / 1000);
		const minutes = Math.floor(totalSeconds / 60);
		const seconds = totalSeconds % 60;
		return `${minutes}:${seconds.toString().padStart(2, '0')}`;
	}
</script>

<div class="complete-view">
	<Box variant="double" borderColor={result.success ? 'cyan' : 'red'} padding={4}>
		<Stack gap={4}>
			<!-- Header -->
			<div class="header" class:success={result.success} class:failure={!result.success}>
				{#if result.success}
					<div class="status-icon success">[OK]</div>
					<h2 class="status-title">INFILTRATION COMPLETE</h2>
					<p class="status-subtitle">Successfully extracted from {run.difficulty.toUpperCase()} network</p>
				{:else}
					<div class="status-icon failure">[XX]</div>
					<h2 class="status-title">INFILTRATION FAILED</h2>
					<p class="status-subtitle">Connection terminated by ICE</p>
				{/if}
			</div>

			<!-- Stats -->
			<div class="stats-grid">
				<div class="stat-card">
					<span class="stat-label">NODES CLEARED</span>
					<span class="stat-value">{result.nodesCompleted}/{result.totalNodes}</span>
				</div>
				<div class="stat-card">
					<span class="stat-label">TIME ELAPSED</span>
					<span class="stat-value">{formatElapsed(result.timeElapsed)}</span>
				</div>
				<div class="stat-card highlight">
					<span class="stat-label">YIELD MULTIPLIER</span>
					<span class="stat-value multiplier">{result.finalMultiplier.toFixed(2)}x</span>
				</div>
				<div class="stat-card">
					<span class="stat-label">LOOT EXTRACTED</span>
					<span class="stat-value loot">
						<AmountDisplay amount={result.lootGained} format="compact" />
					</span>
				</div>
				<div class="stat-card">
					<span class="stat-label">XP EARNED</span>
					<span class="stat-value xp">+{result.xpGained} XP</span>
				</div>
				<div class="stat-card">
					<span class="stat-label">ENTRY FEE</span>
					<span class="stat-value" class:refunded={result.entryRefunded}>
						{#if result.entryRefunded}
							REFUNDED
						{:else}
							BURNED
						{/if}
					</span>
				</div>
			</div>

			<!-- Multiplier info (if successful) -->
			{#if result.success && result.finalMultiplier > 0}
				<div class="multiplier-info">
					<span class="multiplier-icon">[*]</span>
					<div class="multiplier-text">
						<span class="multiplier-label">YIELD BOOST ACTIVE</span>
						<span class="multiplier-duration">
							{result.finalMultiplier.toFixed(2)}x multiplier for {formatDuration(MULTIPLIER_DURATION)}
						</span>
					</div>
				</div>
			{/if}

			<!-- Actions -->
			<Row gap={2} justify="center">
				<Button variant="secondary" onclick={onExit}>
					[ESC] EXIT
				</Button>
				<Button variant="primary" onclick={onNewRun}>
					[SPACE] NEW RUN
				</Button>
			</Row>
		</Stack>
	</Box>
</div>

<style>
	.complete-view {
		width: 100%;
		max-width: 600px;
		margin: 0 auto;
	}

	.header {
		text-align: center;
	}

	.status-icon {
		font-size: var(--text-3xl);
		font-weight: var(--font-bold);
		margin-bottom: var(--space-2);
	}

	.status-icon.success {
		color: var(--color-profit);
	}

	.status-icon.failure {
		color: var(--color-loss);
	}

	.status-title {
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
		margin: 0;
	}

	.header.success .status-title {
		color: var(--color-cyan);
	}

	.header.failure .status-title {
		color: var(--color-loss);
	}

	.status-subtitle {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		margin: var(--space-1) 0 0;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: var(--space-2);
	}

	.stat-card {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-1);
		padding: var(--space-2);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
	}

	.stat-card.highlight {
		background: rgba(0, 229, 204, 0.1);
		border-color: var(--color-cyan-dim);
	}

	.stat-label {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
		text-align: center;
	}

	.stat-value {
		color: var(--color-text-primary);
		font-size: var(--text-base);
		font-weight: var(--font-bold);
	}

	.stat-value.multiplier {
		color: var(--color-cyan);
		font-size: var(--text-lg);
	}

	.stat-value.loot {
		color: var(--color-profit);
	}

	.stat-value.xp {
		color: var(--color-amber);
	}

	.stat-value.refunded {
		color: var(--color-profit);
	}

	.multiplier-info {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-3);
		background: rgba(0, 229, 204, 0.1);
		border: 1px solid var(--color-cyan-dim);
	}

	.multiplier-icon {
		font-size: var(--text-2xl);
		font-weight: var(--font-bold);
		color: var(--color-cyan);
	}

	.multiplier-text {
		display: flex;
		flex-direction: column;
	}

	.multiplier-label {
		color: var(--color-cyan);
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	.multiplier-duration {
		color: var(--color-text-secondary);
		font-size: var(--text-xs);
	}

	/* Mobile responsiveness */
	@media (max-width: 480px) {
		.stats-grid {
			grid-template-columns: repeat(2, 1fr);
		}

		.stats-grid .stat-card:last-child {
			grid-column: 1 / -1;
		}
	}
</style>
