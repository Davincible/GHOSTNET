<script lang="ts">
	import type { DeadPoolUserStats } from '$lib/core/types';
	import { Box } from '$lib/ui/terminal';
	import { AmountDisplay } from '$lib/ui/data-display';
	import { Button } from '$lib/ui/primitives';
	import { formatPercent } from '$lib/core/utils';

	interface Props {
		/** User statistics for Dead Pool */
		stats: DeadPoolUserStats;
		/** User's current balance (optional) */
		balance?: bigint;
		/** Help button handler (optional) */
		onHelp?: () => void;
	}

	let { stats, balance, onHelp }: Props = $props();

	// Win rate as percentage
	const winRatePercent = $derived(Math.round(stats.winRate * 100));

	// Streak display - using $derived.by for complex logic
	const streakText = $derived.by(() => {
		if (stats.currentStreak === 0) return '0';
		if (stats.currentStreak > 0) return `+${stats.currentStreak}W`;
		return `${stats.currentStreak}L`;
	});

	const streakClass = $derived.by(() => {
		if (stats.currentStreak > 0) return 'streak-win';
		if (stats.currentStreak < 0) return 'streak-loss';
		return '';
	});

	// Net P/L calculation
	const netProfit = $derived(stats.totalWon >= stats.totalLost);
	const netAmount = $derived(
		netProfit ? stats.totalWon - stats.totalLost : stats.totalLost - stats.totalWon
	);
</script>

<Box variant="double" borderColor="amber" padding={3}>
	<div class="deadpool-header">
		<!-- Title row -->
		<div class="header-row">
			<div class="title-section">
				<span class="title-label">DEAD</span>
				<span class="title-pool">POOL</span>
				<span class="subtitle">PREDICTION MARKET</span>
			</div>
			{#if onHelp}
				<Button variant="ghost" size="sm" onclick={onHelp} aria-label="Help">[?]</Button>
			{/if}
		</div>

		<!-- Divider -->
		<div class="divider" aria-hidden="true"></div>

		<!-- Stats row -->
		<div class="stats-row">
			{#if balance !== undefined}
				<div class="stat">
					<span class="stat-label">BALANCE:</span>
					<span class="stat-value">
						<AmountDisplay amount={balance} format="compact" />
					</span>
				</div>
			{/if}
			<div class="stat">
				<span class="stat-label">BETS:</span>
				<span class="stat-value">{stats.totalBets}</span>
			</div>
			<div class="stat">
				<span class="stat-label">WIN RATE:</span>
				<span
					class="stat-value"
					class:positive={winRatePercent >= 50}
					class:negative={winRatePercent < 50}
				>
					{winRatePercent}%
				</span>
			</div>
			<div class="stat">
				<span class="stat-label">NET P/L:</span>
				<span class="stat-value" class:positive={netProfit} class:negative={!netProfit}>
					{#if netProfit}+{:else}-{/if}<AmountDisplay amount={netAmount} format="compact" />
				</span>
			</div>
			<div class="stat">
				<span class="stat-label">STREAK:</span>
				<span class="stat-value {streakClass}">{streakText}</span>
			</div>
		</div>
	</div>
</Box>

<style>
	.deadpool-header {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.header-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.title-section {
		display: flex;
		align-items: baseline;
		gap: var(--space-2);
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
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-widest);
		margin-left: var(--space-2);
	}

	.divider {
		height: 1px;
		background: var(--color-border-subtle);
		margin: var(--space-1) 0;
	}

	.stats-row {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-4);
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
		.title-section {
			flex-direction: column;
			align-items: flex-start;
			gap: 0;
		}

		.subtitle {
			margin-left: 0;
		}

		.stats-row {
			flex-direction: column;
			gap: var(--space-1);
		}
	}
</style>
