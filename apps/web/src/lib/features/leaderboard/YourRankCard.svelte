<script lang="ts">
	import { Panel } from '$lib/ui/terminal';
	import type { LeaderboardData, LeaderboardCategory } from '$lib/core/types/leaderboard';
	import { LEADERBOARD_CATEGORIES } from '$lib/core/types/leaderboard';
	import {
		getRankMovement,
		formatPercentile,
	} from '$lib/core/providers/mock/generators/leaderboard';

	interface Props {
		/** Complete leaderboard data (includes user entry) */
		data: LeaderboardData;
		/** Simulated position change (positive = improved) */
		positionChange?: number;
	}

	let { data, positionChange = 0 }: Props = $props();

	// Get category config
	let config = $derived(LEADERBOARD_CATEGORIES[data.category]);

	// Calculate percentile if we have user rank and total entries
	let percentile = $derived.by(() => {
		if (!data.userRank || !data.totalEntries) return null;
		return ((data.totalEntries - data.userRank) / data.totalEntries) * 100;
	});

	// Rank movement
	let movement = $derived.by(() => {
		if (!data.userEntry) return 'same';
		return getRankMovement(data.userEntry.rank, data.userEntry.previousRank);
	});

	let movementIcon = $derived(movement === 'up' ? '▲' : movement === 'down' ? '▼' : '●');
</script>

{#if data.userEntry || data.userRank}
	<Panel borderColor="cyan" padding={3}>
		<div class="rank-card">
			<div class="rank-main">
				<span class="rank-label">YOUR RANK:</span>
				<span class="rank-value">#{data.userRank?.toLocaleString() ?? '-'}</span>
			</div>

			{#if percentile !== null}
				<div class="rank-percentile">
					{formatPercentile(percentile)} of all operators
				</div>
			{/if}

			{#if data.userEntry}
				<div class="rank-metric">
					<span class="metric-label">{config.label}:</span>
					<span class="metric-value">
						{config.valuePrefix ?? ''}{data.userEntry.formattedValue}{config.valueSuffix ?? ''}
					</span>
				</div>
			{/if}

			{#if positionChange !== 0 || (data.userEntry?.previousRank && data.userEntry.previousRank !== data.userEntry.rank)}
				{@const change =
					positionChange ||
					(data.userEntry?.previousRank ? data.userEntry.previousRank - data.userEntry.rank : 0)}
				<div class="rank-change" class:positive={change > 0} class:negative={change < 0}>
					<span class="change-icon">{change > 0 ? '▲' : change < 0 ? '▼' : ''}</span>
					<span class="change-text">
						{change > 0 ? '+' : ''}{change} position{Math.abs(change) !== 1 ? 's' : ''} since last week
					</span>
				</div>
			{/if}
		</div>
	</Panel>
{:else}
	<Panel borderColor="default" padding={3}>
		<div class="rank-card unranked">
			<span class="unranked-text">You are not ranked in this category yet.</span>
			<span class="unranked-hint">Jack in and start climbing!</span>
		</div>
	</Panel>
{/if}

<style>
	.rank-card {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.rank-main {
		display: flex;
		align-items: baseline;
		gap: var(--space-2);
	}

	.rank-label {
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wide);
	}

	.rank-value {
		font-size: var(--text-xl);
		color: var(--color-accent);
		font-weight: var(--font-bold);
		font-variant-numeric: tabular-nums;
	}

	.rank-percentile {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
	}

	.rank-metric {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		margin-top: var(--space-1);
	}

	.metric-label {
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
	}

	.metric-value {
		font-size: var(--text-sm);
		color: var(--color-text-primary);
		font-variant-numeric: tabular-nums;
	}

	.rank-change {
		display: flex;
		align-items: center;
		gap: var(--space-1);
		font-size: var(--text-sm);
		margin-top: var(--space-1);
	}

	.rank-change.positive {
		color: var(--color-profit);
	}

	.rank-change.negative {
		color: var(--color-red);
	}

	.change-icon {
		font-size: var(--text-xs);
	}

	.rank-card.unranked {
		text-align: center;
		padding: var(--space-2);
	}

	.unranked-text {
		display: block;
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
	}

	.unranked-hint {
		display: block;
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		margin-top: var(--space-1);
		font-style: italic;
	}
</style>
