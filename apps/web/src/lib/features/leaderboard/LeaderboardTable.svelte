<script lang="ts">
	import { Panel } from '$lib/ui/terminal';
	import LeaderboardRow from './LeaderboardRow.svelte';
	import type { LeaderboardData, LeaderboardCategory } from '$lib/core/types/leaderboard';
	import { LEADERBOARD_CATEGORIES } from '$lib/core/types/leaderboard';

	interface Props {
		/** Complete leaderboard data */
		data: LeaderboardData;
	}

	let { data }: Props = $props();

	// Get category config for column headers
	let config = $derived(LEADERBOARD_CATEGORIES[data.category]);

	// Determine value column header based on category
	let valueHeader = $derived(() => {
		switch (data.category) {
			case 'ghost_streak':
				return 'STREAK';
			case 'total_extracted':
			case 'weekly_extracted':
				return 'EXTRACTED';
			case 'total_staked':
				return 'STAKED';
			case 'risk_score':
				return 'SCORE';
			default:
				return 'VALUE';
		}
	});

	// Show streak column for all except ghost_streak (it's the main value there)
	let showStreakColumn = $derived(data.category !== 'ghost_streak');
</script>

<Panel padding={0}>
	<div class="table-container">
		<table class="leaderboard-table">
			<thead>
				<tr class="table-header">
					<th class="col-rank">RANK</th>
					<th class="col-operator">OPERATOR</th>
					<th class="col-level">LEVEL</th>
					<th class="col-value">{valueHeader()}</th>
					{#if showStreakColumn}
						<th class="col-streak">STREAK</th>
					{:else}
						<th class="col-streak"></th>
					{/if}
				</tr>
			</thead>
			<tbody>
				{#each data.entries as entry (entry.address + entry.rank)}
					<LeaderboardRow {entry} category={data.category} />
				{/each}
			</tbody>
		</table>

		{#if data.entries.length === 0}
			<div class="empty-state">
				<p>No rankings available for this timeframe.</p>
			</div>
		{/if}
	</div>

	<div class="table-footer">
		<span class="total-count">
			Showing {data.entries.length} of {data.totalEntries.toLocaleString()} operators
		</span>
		<span class="last-updated">
			Updated: {new Date(data.lastUpdated).toLocaleTimeString()}
		</span>
	</div>
</Panel>

<style>
	.table-container {
		overflow-x: auto;
		scrollbar-width: thin;
		scrollbar-color: var(--color-border-strong) var(--color-bg-tertiary);
	}

	.leaderboard-table {
		width: 100%;
		border-collapse: collapse;
		font-family: var(--font-mono);
	}

	.table-header {
		border-bottom: 2px solid var(--color-border-default);
	}

	.table-header th {
		padding: var(--space-3);
		text-align: left;
		font-size: var(--text-xs);
		font-weight: var(--font-bold);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
		white-space: nowrap;
	}

	.col-rank {
		width: 80px;
	}

	.col-operator {
		min-width: 180px;
	}

	.col-level {
		width: 100px;
	}

	.col-value {
		width: 120px;
		text-align: right;
	}

	.col-streak {
		width: 80px;
		text-align: center;
	}

	.empty-state {
		padding: var(--space-8);
		text-align: center;
		color: var(--color-text-tertiary);
		font-style: italic;
	}

	.table-footer {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: var(--space-3);
		border-top: 1px solid var(--color-border-subtle);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
	}

	@media (max-width: 640px) {
		.table-header th {
			padding: var(--space-2);
			font-size: 0.625rem;
		}

		.col-level,
		.col-streak {
			display: none;
		}

		.table-footer {
			flex-direction: column;
			gap: var(--space-1);
			text-align: center;
		}
	}
</style>
