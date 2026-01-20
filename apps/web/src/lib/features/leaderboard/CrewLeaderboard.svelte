<script lang="ts">
	import { Panel } from '$lib/ui/terminal';
	import { AmountDisplay } from '$lib/ui/data-display';
	import type { CrewLeaderboardEntry } from '$lib/core/types/leaderboard';
	import { getRankMovement } from '$lib/core/providers/mock/generators/leaderboard';

	interface Props {
		/** Crew leaderboard entries */
		entries: CrewLeaderboardEntry[];
	}

	let { entries }: Props = $props();
</script>

<Panel padding={0}>
	<div class="table-container">
		<table class="crew-table">
			<thead>
				<tr class="table-header">
					<th class="col-rank">RANK</th>
					<th class="col-crew">CREW</th>
					<th class="col-members">MEMBERS</th>
					<th class="col-tvl">TVL</th>
					<th class="col-weekly">WEEKLY</th>
				</tr>
			</thead>
			<tbody>
				{#each entries as entry (entry.crewId)}
					{@const movement = getRankMovement(entry.rank, entry.previousRank)}
					{@const movementIcon = movement === 'up' ? '▲' : movement === 'down' ? '▼' : '●'}
					{@const movementClass = movement === 'up' ? 'movement-up' : movement === 'down' ? 'movement-down' : 'movement-same'}

					<tr class="crew-row" class:is-your-crew={entry.isYourCrew}>
						<td class="col-rank">
							<span class="rank-number">#{entry.rank}</span>
							<span class="rank-movement {movementClass}">{movementIcon}</span>
						</td>

						<td class="col-crew">
							<span class="crew-info">
								{#if entry.isYourCrew}
									<span class="you-indicator">●</span>
								{/if}
								<span class="crew-name">{entry.crewName}</span>
								<span class="crew-tag">[{entry.crewTag}]</span>
							</span>
						</td>

						<td class="col-members">
							<span class="member-count">{entry.memberCount}/50</span>
						</td>

						<td class="col-tvl">
							<AmountDisplay amount={entry.totalStaked} format="compact" />
						</td>

						<td class="col-weekly">
							<span class="weekly-value">
								<AmountDisplay amount={entry.weeklyExtracted} format="compact" showSign colorize />
							</span>
						</td>
					</tr>
				{/each}
			</tbody>
		</table>

		{#if entries.length === 0}
			<div class="empty-state">
				<p>No crews found.</p>
			</div>
		{/if}
	</div>

	<div class="table-footer">
		<span class="total-count">
			Showing {entries.length} crews
		</span>
	</div>
</Panel>

<style>
	.table-container {
		overflow-x: auto;
		scrollbar-width: thin;
		scrollbar-color: var(--color-border-strong) var(--color-bg-tertiary);
	}

	.crew-table {
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

	.crew-row {
		border-bottom: 1px solid var(--color-border-subtle);
		transition: background var(--duration-fast) var(--ease-default);
	}

	.crew-row:hover {
		background: var(--color-bg-secondary);
	}

	.crew-row.is-your-crew {
		background: rgba(0, 229, 204, 0.06);
		border-left: 2px solid var(--color-accent);
	}

	.crew-row.is-your-crew:hover {
		background: rgba(0, 229, 204, 0.1);
	}

	.crew-row td {
		padding: var(--space-2) var(--space-3);
		font-size: var(--text-sm);
		vertical-align: middle;
	}

	.col-rank {
		width: 80px;
		white-space: nowrap;
	}

	.rank-number {
		color: var(--color-text-secondary);
		font-weight: var(--font-medium);
		margin-right: var(--space-1);
	}

	.rank-movement {
		font-size: var(--text-xs);
	}

	.movement-up {
		color: var(--color-profit);
	}

	.movement-down {
		color: var(--color-red);
	}

	.movement-same {
		color: var(--color-text-tertiary);
	}

	.col-crew {
		min-width: 200px;
	}

	.crew-info {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.you-indicator {
		color: var(--color-accent);
		font-size: var(--text-xs);
	}

	.crew-name {
		color: var(--color-text-primary);
		font-weight: var(--font-medium);
	}

	.crew-tag {
		color: var(--color-amber);
		font-size: var(--text-xs);
	}

	.col-members {
		width: 100px;
	}

	.member-count {
		color: var(--color-text-secondary);
	}

	.col-tvl {
		width: 120px;
		text-align: right;
	}

	.col-weekly {
		width: 120px;
		text-align: right;
	}

	.weekly-value {
		font-variant-numeric: tabular-nums;
	}

	.empty-state {
		padding: var(--space-8);
		text-align: center;
		color: var(--color-text-tertiary);
		font-style: italic;
	}

	.table-footer {
		display: flex;
		justify-content: flex-start;
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

		.crew-row td {
			padding: var(--space-1) var(--space-2);
			font-size: var(--text-xs);
		}

		.col-members,
		.col-weekly {
			display: none;
		}

		.col-crew {
			min-width: 150px;
		}
	}
</style>
