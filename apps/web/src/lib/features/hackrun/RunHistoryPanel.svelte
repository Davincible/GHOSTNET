<script lang="ts">
	import type { HackRunHistoryEntry, HackRunDifficulty } from '$lib/core/types/hackrun';
	import { Box } from '$lib/ui/terminal';
	import { Stack, Row } from '$lib/ui/layout';
	import { AmountDisplay } from '$lib/ui/data-display';

	interface Props {
		/** Recent run history */
		history: HackRunHistoryEntry[];
		/** Maximum items to show */
		limit?: number;
	}

	let { history, limit = 5 }: Props = $props();

	let displayHistory = $derived(history.slice(0, limit));

	// Difficulty colors
	const DIFF_COLORS: Record<HackRunDifficulty, string> = {
		easy: 'var(--color-profit)',
		medium: 'var(--color-amber)',
		hard: 'var(--color-loss)'
	};

	// Format timestamp
	function formatTime(timestamp: number): string {
		const date = new Date(timestamp);
		const now = new Date();
		const diffMs = now.getTime() - date.getTime();
		const diffMins = Math.floor(diffMs / 60000);
		const diffHours = Math.floor(diffMins / 60);

		if (diffMins < 60) return `${diffMins}m ago`;
		if (diffHours < 24) return `${diffHours}h ago`;
		return date.toLocaleDateString();
	}
</script>

<Box variant="single" title="RUN HISTORY" padding={2}>
	<Stack gap={2}>
		{#if displayHistory.length === 0}
			<div class="empty-state">
				<span class="empty-text">No runs completed yet</span>
			</div>
		{:else}
			{#each displayHistory as entry (entry.id)}
				<div
					class="history-row"
					class:success={entry.result.success}
					class:failure={!entry.result.success}
				>
					<Row justify="between" align="center">
						<div class="run-info">
							<span class="run-difficulty" style:color={DIFF_COLORS[entry.difficulty]}>
								{entry.difficulty.toUpperCase()}
							</span>
							<span class="run-status">
								{entry.result.success ? 'COMPLETE' : 'FAILED'}
							</span>
						</div>
						<span class="run-time">{formatTime(entry.timestamp)}</span>
					</Row>

					<Row justify="between" align="center" class="run-stats">
						<div class="stat">
							<span class="stat-label">NODES:</span>
							<span class="stat-value">{entry.result.nodesCompleted}/{entry.result.totalNodes}</span>
						</div>
						<div class="stat">
							<span class="stat-label">MULT:</span>
							<span class="stat-value multiplier">{entry.result.finalMultiplier.toFixed(1)}x</span>
						</div>
						<div class="stat">
							<span class="stat-label">XP:</span>
							<span class="stat-value xp">+{entry.result.xpGained}</span>
						</div>
					</Row>
				</div>
			{/each}
		{/if}
	</Stack>
</Box>

<style>
	.empty-state {
		padding: var(--space-4);
		text-align: center;
	}

	.empty-text {
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}

	.history-row {
		padding: var(--space-2);
		border: 1px solid var(--color-border-subtle);
		background: var(--color-bg-secondary);
	}

	.history-row.success {
		border-left: 3px solid var(--color-profit-dim);
	}

	.history-row.failure {
		border-left: 3px solid var(--color-loss-dim);
	}

	.run-info {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.run-difficulty {
		font-size: var(--text-xs);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	.run-status {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
	}

	.history-row.success .run-status {
		color: var(--color-profit);
	}

	.history-row.failure .run-status {
		color: var(--color-loss);
	}

	.run-time {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
	}

	:global(.run-stats) {
		margin-top: var(--space-1);
	}

	.stat {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.stat-label {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
	}

	.stat-value {
		color: var(--color-text-primary);
		font-size: var(--text-xs);
		font-weight: var(--font-medium);
	}

	.stat-value.multiplier {
		color: var(--color-cyan);
	}

	.stat-value.xp {
		color: var(--color-amber);
	}
</style>
