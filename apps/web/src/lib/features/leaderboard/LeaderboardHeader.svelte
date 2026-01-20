<script lang="ts">
	import { Panel } from '$lib/ui/terminal';
	import type { UserRankings } from '$lib/core/types/leaderboard';
	import { formatPercentile } from '$lib/core/providers/mock/generators/leaderboard';

	interface Props {
		/** User's rankings across all categories */
		userRankings: UserRankings;
	}

	let { userRankings }: Props = $props();

	// Format rank with percentile
	function formatRank(rank: number, percentile: number): string {
		const pctStr = formatPercentile(percentile);
		return `#${rank.toLocaleString()} (${pctStr})`;
	}
</script>

<Panel title="LEADERBOARD" variant="double" borderColor="cyan" padding={3}>
	<div class="header-content">
		<p class="tagline">"Prove your worth. Climb the ranks."</p>

		<div class="rankings-section">
			<span class="rankings-label">YOUR RANKINGS</span>
			<div class="rankings-row">
				{#if userRankings.ghostStreak}
					<div class="rank-item">
						<span class="rank-category">STREAK:</span>
						<span class="rank-value">{formatRank(userRankings.ghostStreak.rank, userRankings.ghostStreak.percentile)}</span>
					</div>
				{/if}

				{#if userRankings.totalExtracted}
					<div class="rank-item">
						<span class="rank-category">EXTRACT:</span>
						<span class="rank-value">{formatRank(userRankings.totalExtracted.rank, userRankings.totalExtracted.percentile)}</span>
					</div>
				{/if}

				{#if userRankings.totalStaked}
					<div class="rank-item">
						<span class="rank-category">STAKED:</span>
						<span class="rank-value">#{userRankings.totalStaked.rank.toLocaleString()}</span>
					</div>
				{/if}

				{#if userRankings.riskScore}
					<div class="rank-item">
						<span class="rank-category">RISK:</span>
						<span class="rank-value">#{userRankings.riskScore.rank.toLocaleString()}</span>
					</div>
				{/if}

				{#if !userRankings.ghostStreak && !userRankings.totalExtracted && !userRankings.totalStaked && !userRankings.riskScore}
					<span class="no-rankings">No rankings yet. Jack in to start climbing.</span>
				{/if}
			</div>
		</div>
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
		margin-bottom: var(--space-4);
	}

	.rankings-section {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.rankings-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.rankings-row {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-4);
	}

	.rank-item {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.rank-category {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		font-weight: var(--font-medium);
	}

	.rank-value {
		font-size: var(--text-sm);
		color: var(--color-accent);
		font-variant-numeric: tabular-nums;
	}

	.no-rankings {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
		font-style: italic;
	}

	@media (max-width: 640px) {
		.rankings-row {
			flex-direction: column;
			gap: var(--space-2);
		}
	}
</style>
