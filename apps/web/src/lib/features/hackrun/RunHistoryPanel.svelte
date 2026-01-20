<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { Badge } from '$lib/ui/primitives';
	import { AmountDisplay } from '$lib/ui/data-display';
	import { Stack, Row } from '$lib/ui/layout';
	import type { HackRunHistoryEntry, HackRunDifficulty } from '$lib/core/types/hackrun';

	interface Props {
		/** History entries to display */
		history: HackRunHistoryEntry[];
		/** Maximum entries to show */
		maxEntries?: number;
	}

	let { history, maxEntries = 5 }: Props = $props();

	// Limit displayed entries
	let displayedHistory = $derived(history.slice(0, maxEntries));

	// Difficulty badge variants
	const difficultyVariants: Record<HackRunDifficulty, 'success' | 'warning' | 'danger'> = {
		easy: 'success',
		medium: 'warning',
		hard: 'danger',
	};

	// Format timestamp
	function formatTime(timestamp: number): string {
		const date = new Date(timestamp);
		const now = new Date();
		const diffMs = now.getTime() - date.getTime();
		const diffMins = Math.floor(diffMs / 60000);
		const diffHours = Math.floor(diffMins / 60);
		const diffDays = Math.floor(diffHours / 24);

		if (diffMins < 1) return 'Just now';
		if (diffMins < 60) return `${diffMins}m ago`;
		if (diffHours < 24) return `${diffHours}h ago`;
		if (diffDays < 7) return `${diffDays}d ago`;

		return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
	}
</script>

<div class="history-panel">
	<Box title="RECENT RUNS" padding={2}>
		{#if displayedHistory.length === 0}
			<div class="empty-state">
				<span class="empty-icon">[?]</span>
				<span class="empty-text">No hack runs yet</span>
			</div>
		{:else}
			<Stack gap={2}>
				{#each displayedHistory as entry (entry.id)}
					<div
						class="history-entry"
						class:entry-success={entry.result.success}
						class:entry-failed={!entry.result.success}
					>
						<Row justify="between" align="center">
							<Row gap={2} align="center">
								<span class="entry-status">{entry.result.success ? '[+]' : '[X]'}</span>
								<Badge variant={difficultyVariants[entry.difficulty]} compact>
									{entry.difficulty.toUpperCase()}
								</Badge>
							</Row>
							<span class="entry-time">{formatTime(entry.timestamp)}</span>
						</Row>

						<Row justify="between" align="center">
							<span class="entry-nodes">
								{entry.result.nodesCompleted}/{entry.result.totalNodes} nodes
							</span>
							<Row gap={3} align="center">
								{#if entry.result.success}
									<span class="entry-multiplier">{entry.result.finalMultiplier.toFixed(1)}x</span>
								{/if}
								<span class="entry-loot">
									+<AmountDisplay amount={entry.result.lootGained} format="compact" />
								</span>
							</Row>
						</Row>
					</div>
				{/each}
			</Stack>
		{/if}
	</Box>
</div>

<style>
	.history-panel {
		width: 100%;
	}

	.empty-state {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		padding: var(--space-4);
	}

	.empty-icon {
		color: var(--color-text-tertiary);
		font-weight: var(--font-bold);
	}

	.empty-text {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
	}

	.history-entry {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		padding: var(--space-2);
		background: var(--color-bg-primary);
		border: 1px solid var(--color-border-subtle);
		border-left: 3px solid;
		transition: border-color var(--duration-fast) var(--ease-default);
	}

	.entry-success {
		border-left-color: var(--color-profit);
	}

	.entry-failed {
		border-left-color: var(--color-red);
	}

	.entry-status {
		font-weight: var(--font-bold);
		font-size: var(--text-sm);
	}

	.entry-success .entry-status {
		color: var(--color-profit);
	}

	.entry-failed .entry-status {
		color: var(--color-red);
	}

	.entry-time {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
	}

	.entry-nodes {
		color: var(--color-text-secondary);
		font-size: var(--text-xs);
	}

	.entry-multiplier {
		color: var(--color-accent);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
	}

	.entry-loot {
		color: var(--color-profit);
		font-size: var(--text-sm);
	}
</style>
