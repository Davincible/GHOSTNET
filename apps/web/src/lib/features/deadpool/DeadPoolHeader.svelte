<script lang="ts">
	import type { DeadPoolUserStats } from '$lib/core/types';
	import { Box } from '$lib/ui/terminal';
	import { AmountDisplay } from '$lib/ui/data-display';
	import { Row } from '$lib/ui/layout';

	interface Props {
		/** User statistics for Dead Pool */
		stats: DeadPoolUserStats;
	}

	let { stats }: Props = $props();

	// Format win rate as percentage
	let winRatePercent = $derived(Math.round(stats.winRate * 100));

	// Streak display
	let streakText = $derived(() => {
		if (stats.currentStreak === 0) return '0';
		if (stats.currentStreak > 0) return `+${stats.currentStreak}W`;
		return `${stats.currentStreak}L`;
	});

	let streakClass = $derived(() => {
		if (stats.currentStreak > 0) return 'streak-win';
		if (stats.currentStreak < 0) return 'streak-loss';
		return '';
	});

	// Net P/L calculation (bigint comparison)
	let netProfit = $derived(stats.totalWon >= stats.totalLost);
	let netAmount = $derived(netProfit ? stats.totalWon - stats.totalLost : stats.totalLost - stats.totalWon);
</script>

<Box variant="double" borderColor="amber" padding={3}>
	<div class="deadpool-header">
		<!-- Title row -->
		<Row justify="between" align="center">
			<div class="title-section">
				<span class="title-label">DEAD</span>
				<span class="title-pool">POOL</span>
			</div>
			<div class="subtitle">PREDICTION MARKET</div>
		</Row>

		<!-- Divider -->
		<div class="divider" aria-hidden="true"></div>

		<!-- Stats row -->
		<Row justify="between" align="center" class="stats-row">
			<div class="stat">
				<span class="stat-label">BETS:</span>
				<span class="stat-value">{stats.totalBets}</span>
			</div>
			<div class="stat">
				<span class="stat-label">WIN RATE:</span>
				<span class="stat-value" class:positive={winRatePercent >= 50} class:negative={winRatePercent < 50}>
					{winRatePercent}%
				</span>
			</div>
			<div class="stat">
				<span class="stat-label">NET P/L:</span>
				<span class="stat-value" class:positive={netProfit} class:negative={!netProfit}>
					{#if netProfit}
						+<AmountDisplay amount={netAmount} format="compact" />
					{:else}
						-<AmountDisplay amount={netAmount} format="compact" />
					{/if}
				</span>
			</div>
			<div class="stat">
				<span class="stat-label">STREAK:</span>
				<span class="stat-value {streakClass()}">{streakText()}</span>
			</div>
		</Row>
	</div>
</Box>

<style>
	.deadpool-header {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.title-section {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.title-label {
		color: var(--color-text-primary);
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	.title-pool {
		color: var(--color-amber);
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	.subtitle {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
		letter-spacing: var(--tracking-widest);
	}

	.divider {
		height: 1px;
		background: var(--color-border-subtle);
		margin: var(--space-1) 0;
	}

	:global(.stats-row) {
		flex-wrap: wrap;
		gap: var(--space-3);
	}

	.stat {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.stat-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.stat-value {
		color: var(--color-text-primary);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
	}

	.stat-value.positive {
		color: var(--color-profit);
	}

	.stat-value.negative {
		color: var(--color-loss);
	}

	.streak-win {
		color: var(--color-profit);
	}

	.streak-loss {
		color: var(--color-loss);
	}

	/* Mobile responsiveness */
	@media (max-width: 480px) {
		.title-label,
		.title-pool {
			font-size: var(--text-lg);
		}

		.subtitle {
			font-size: var(--text-xs);
		}

		:global(.stats-row) {
			flex-direction: column;
			align-items: flex-start;
			gap: var(--space-1);
		}
	}
</style>
