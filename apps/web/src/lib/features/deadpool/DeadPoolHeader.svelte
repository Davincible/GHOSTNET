<script lang="ts">
	import { Panel } from '$lib/ui/terminal';
	import { AmountDisplay } from '$lib/ui/data-display';
	import { Row } from '$lib/ui/layout';
	import type { DeadPoolUserStats } from '$lib/core/types';

	interface Props {
		/** User's current $DATA balance */
		balance: bigint;
		/** User's Dead Pool statistics */
		stats: DeadPoolUserStats;
		/** Show help/info modal */
		onHelp?: () => void;
	}

	let { balance, stats, onHelp }: Props = $props();

	// Calculate net profit/loss
	let netProfitLoss = $derived(stats.totalWon - stats.totalLost);
	let winRatePercent = $derived(Math.round(stats.winRate * 100));
</script>

<Panel title="DEAD POOL" variant="double" borderColor="cyan" padding={3}>
	<div class="header-content">
		<p class="tagline">"Bet on the network. Feed the furnace."</p>

		<div class="stats-row">
			<div class="stat">
				<span class="stat-label">YOUR BALANCE</span>
				<span class="stat-value">
					<AmountDisplay amount={balance} format="full" />
				</span>
			</div>

			<div class="stat">
				<span class="stat-label">TOTAL WON</span>
				<span class="stat-value" class:profit={netProfitLoss > 0n} class:loss={netProfitLoss < 0n}>
					<AmountDisplay amount={netProfitLoss} format="full" showSign colorize />
				</span>
			</div>

			<div class="stat">
				<span class="stat-label">WIN RATE</span>
				<span class="stat-value">{winRatePercent}%</span>
			</div>

			{#if stats.currentStreak !== 0}
				<div class="stat">
					<span class="stat-label">STREAK</span>
					<span
						class="stat-value streak"
						class:win-streak={stats.currentStreak > 0}
						class:loss-streak={stats.currentStreak < 0}
					>
						{stats.currentStreak > 0 ? '+' : ''}{stats.currentStreak}
					</span>
				</div>
			{/if}
		</div>

		{#if onHelp}
			<button class="help-btn" onclick={onHelp} aria-label="How to play"> [?] </button>
		{/if}
	</div>
</Panel>

<style>
	.header-content {
		position: relative;
	}

	.tagline {
		color: var(--color-text-tertiary);
		font-style: italic;
		font-size: var(--text-sm);
		margin-bottom: var(--space-3);
	}

	.stats-row {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-4);
	}

	.stat {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.stat-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.stat-value {
		font-size: var(--text-base);
		color: var(--color-text-primary);
		font-weight: var(--font-medium);
	}

	.stat-value.profit {
		color: var(--color-profit);
	}

	.stat-value.loss {
		color: var(--color-loss);
	}

	.streak {
		font-weight: var(--font-bold);
	}

	.streak.win-streak {
		color: var(--color-profit);
	}

	.streak.loss-streak {
		color: var(--color-loss);
	}

	.help-btn {
		position: absolute;
		top: 0;
		right: 0;
		background: none;
		border: 1px solid var(--color-border-subtle);
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		padding: var(--space-1) var(--space-2);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.help-btn:hover {
		color: var(--color-accent);
		border-color: var(--color-accent-dim);
	}

	@media (max-width: 640px) {
		.stats-row {
			flex-direction: column;
			gap: var(--space-2);
		}

		.stat {
			flex-direction: row;
			justify-content: space-between;
			align-items: center;
		}
	}
</style>
