<script lang="ts">
	import { Panel } from '$lib/ui/terminal';
	import { Badge } from '$lib/ui/primitives';
	import { LevelBadge, AmountDisplay } from '$lib/ui/data-display';
	import type { DeadPoolHistory, DeadPoolRoundType } from '$lib/core/types';

	interface Props {
		/** Recent round history */
		history: DeadPoolHistory[];
		/** Maximum items to display */
		maxItems?: number;
	}

	let { history, maxItems = 5 }: Props = $props();

	// Limit displayed history
	let displayHistory = $derived(history.slice(0, maxItems));

	// Round type display mapping
	const typeLabels: Record<DeadPoolRoundType, string> = {
		death_count: 'DEATH COUNT',
		whale_watch: 'WHALE WATCH',
		survival_streak: 'SURVIVAL STREAK',
		system_reset: 'SYSTEM RESET',
	};

	// Format outcome display
	function formatOutcome(h: DeadPoolHistory): string {
		const { round, result } = h;
		const outcomeLabel = result.outcome.toUpperCase();

		if (round.type === 'whale_watch') {
			return result.outcome === 'over' ? 'YES' : 'NO';
		}

		return `${outcomeLabel} ${round.line}`;
	}
</script>

<Panel title="RECENT RESULTS" variant="single" borderColor="dim" padding={2}>
	{#if displayHistory.length === 0}
		<p class="empty-text">No resolved rounds yet</p>
	{:else}
		<div class="results-list">
			{#each displayHistory as item (item.round.id)}
				{@const userWon = item.result.userWon}
				{@const userBet = item.round.userBet}
				<div
					class="result-row"
					class:result-won={userWon === true}
					class:result-lost={userWon === false}
				>
					<span class="result-id">#{item.round.roundNumber}</span>

					<span class="result-type">{typeLabels[item.round.type]}</span>

					{#if item.round.targetLevel}
						<LevelBadge level={item.round.targetLevel} compact />
					{/if}

					<span class="result-outcome" class:outcome-win={userWon === true}>
						{formatOutcome(item)}
						{#if userWon === true}
							<span class="checkmark">✓</span>
						{:else if userWon === false}
							<span class="xmark">✗</span>
						{/if}
					</span>

					<span class="result-payout">
						{#if userBet === null}
							<span class="no-bet">No bet</span>
						{:else if userWon && item.result.userPayout}
							<AmountDisplay
								amount={item.result.userPayout - userBet.amount}
								format="compact"
								showSign
								colorize
							/>
						{:else if userBet}
							<AmountDisplay amount={-userBet.amount} format="compact" showSign colorize />
						{/if}
					</span>
				</div>
			{/each}
		</div>
	{/if}
</Panel>

<style>
	.empty-text {
		color: var(--color-text-muted);
		font-size: var(--text-sm);
		text-align: center;
		padding: var(--space-4);
	}

	.results-list {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.result-row {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-2);
		font-size: var(--text-sm);
		font-family: var(--font-mono);
		background: var(--color-bg-tertiary);
		border-left: 2px solid transparent;
	}

	.result-row.result-won {
		border-left-color: var(--color-profit);
		background: rgba(0, 229, 204, 0.05);
	}

	.result-row.result-lost {
		border-left-color: var(--color-loss);
		background: rgba(255, 51, 102, 0.05);
	}

	.result-id {
		color: var(--color-text-tertiary);
		min-width: 50px;
	}

	.result-type {
		color: var(--color-text-secondary);
		flex: 1;
		min-width: 100px;
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wide);
	}

	.result-outcome {
		color: var(--color-text-primary);
		display: flex;
		align-items: center;
		gap: var(--space-1);
		min-width: 80px;
	}

	.outcome-win {
		color: var(--color-profit);
	}

	.checkmark {
		color: var(--color-profit);
	}

	.xmark {
		color: var(--color-loss);
	}

	.result-payout {
		min-width: 80px;
		text-align: right;
	}

	.no-bet {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
	}

	@media (max-width: 640px) {
		.result-row {
			flex-wrap: wrap;
			gap: var(--space-2);
		}

		.result-type {
			order: 1;
			flex-basis: 100%;
		}

		.result-id {
			order: 0;
		}

		.result-outcome {
			order: 2;
		}

		.result-payout {
			order: 3;
			margin-left: auto;
		}
	}
</style>
