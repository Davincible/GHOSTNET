<script lang="ts">
	import type { DeadPoolHistory } from '$lib/core/types';
	import { Box } from '$lib/ui/terminal';
	import { AmountDisplay, LevelBadge } from '$lib/ui/data-display';
	import { formatRelativeTime } from '$lib/core/utils';

	interface Props {
		/** Recent round results */
		history: DeadPoolHistory[];
		/** Maximum items to show (default: 5) */
		limit?: number;
	}

	let { history, limit = 5 }: Props = $props();

	const displayHistory = $derived(history.slice(0, limit));
</script>

<Box variant="single" title="RECENT RESULTS" padding={2}>
	<div class="results-list" role="list" aria-label="Recent round results">
		{#if displayHistory.length === 0}
			<div class="empty-state">
				<span class="empty-text">No resolved rounds yet</span>
			</div>
		{:else}
			{#each displayHistory as { round, result } (result.roundId)}
				<div
					class="result-row"
					class:user-won={result.userWon === true}
					class:user-lost={result.userWon === false}
					role="listitem"
				>
					<div class="result-header">
						<div class="result-meta">
							<span class="round-number">#{round.roundNumber}</span>
							{#if round.targetLevel}
								<LevelBadge level={round.targetLevel} compact />
							{/if}
						</div>
						<span class="result-time">{formatRelativeTime(round.endsAt)}</span>
					</div>

					<p class="result-question">{round.question}</p>

					<div class="result-details">
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
					</div>
				</div>
			{/each}
		{/if}
	</div>
</Box>

<style>
	.results-list {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

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
		background: var(--color-profit-glow);
	}

	.result-row.user-lost {
		border-color: var(--color-red-dim);
		background: var(--color-red-glow);
	}

	.result-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
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

	.result-details {
		display: flex;
		justify-content: space-between;
		align-items: center;
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
