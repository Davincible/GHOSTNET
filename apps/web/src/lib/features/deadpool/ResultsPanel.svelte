<script lang="ts">
	import type { DeadPoolHistory } from '$lib/core/types';
	import { Box } from '$lib/ui/terminal';
	import { AmountDisplay, LevelBadge } from '$lib/ui/data-display';
	import { Row, Stack } from '$lib/ui/layout';

	interface Props {
		/** Recent round results */
		history: DeadPoolHistory[];
		/** Maximum items to show */
		limit?: number;
	}

	let { history, limit = 5 }: Props = $props();

	let displayHistory = $derived(history.slice(0, limit));

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

<Box variant="single" title="RECENT RESULTS" padding={2}>
	<Stack gap={2}>
		{#if displayHistory.length === 0}
			<div class="empty-state">
				<span class="empty-text">No resolved rounds yet</span>
			</div>
		{:else}
			{#each displayHistory as { round, result } (result.roundId)}
				<div class="result-row" class:user-won={result.userWon === true} class:user-lost={result.userWon === false}>
					<Row justify="between" align="center">
					<div class="result-meta">
						<span class="round-number">#{round.roundNumber}</span>
						{#if round.targetLevel}
							<LevelBadge level={round.targetLevel} compact />
						{/if}
					</div>
						<span class="result-time">{formatTime(round.endsAt)}</span>
					</Row>

					<p class="result-question">{round.question}</p>

					<Row justify="between" align="center" class="result-details">
						<div class="result-outcome">
							<span class="outcome-label">RESULT:</span>
							<span class="outcome-value">{result.actualValue}</span>
							<span class="outcome-side {result.outcome}">{result.outcome.toUpperCase()} WINS</span>
						</div>

						{#if result.userWon !== null}
							<div class="user-result">
								{#if result.userWon}
									<span class="payout-label">WON:</span>
									<span class="payout-value positive">
										+<AmountDisplay amount={result.userPayout ?? 0n} format="compact" />
									</span>
								{:else}
									<span class="payout-label">LOST</span>
								{/if}
							</div>
						{/if}
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

	.result-row {
		padding: var(--space-2);
		border: 1px solid var(--color-border-subtle);
		background: var(--color-bg-secondary);
		transition: all var(--duration-fast) var(--ease-default);
	}

	.result-row.user-won {
		border-color: var(--color-profit-dim);
		background: rgba(0, 255, 136, 0.05);
	}

	.result-row.user-lost {
		border-color: var(--color-loss-dim);
		background: rgba(255, 68, 68, 0.05);
	}

	.result-meta {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.round-number {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.result-time {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
	}

	.result-question {
		color: var(--color-text-secondary);
		font-size: var(--text-xs);
		margin: var(--space-1) 0;
		line-height: var(--leading-snug);
	}

	:global(.result-details) {
		margin-top: var(--space-1);
	}

	.result-outcome {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.outcome-label {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
	}

	.outcome-value {
		color: var(--color-text-primary);
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
	}

	.outcome-side {
		font-size: var(--text-xs);
		font-weight: var(--font-medium);
		padding: 0 var(--space-1);
	}

	.outcome-side.under {
		color: var(--color-cyan);
	}

	.outcome-side.over {
		color: var(--color-amber);
	}

	.user-result {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.payout-label {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
	}

	.payout-value {
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
	}

	.payout-value.positive {
		color: var(--color-profit);
	}
</style>
