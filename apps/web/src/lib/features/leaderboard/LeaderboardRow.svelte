<script lang="ts">
	import { LevelBadge, AddressDisplay } from '$lib/ui/data-display';
	import type { LeaderboardEntry, LeaderboardCategory } from '$lib/core/types/leaderboard';
	import { LEADERBOARD_CATEGORIES } from '$lib/core/types/leaderboard';
	import { getRankMovement } from '$lib/core/providers/mock/generators/leaderboard';

	interface Props {
		/** The leaderboard entry to display */
		entry: LeaderboardEntry;
		/** The category for value formatting context */
		category: LeaderboardCategory;
	}

	let { entry, category }: Props = $props();

	// Compute rank movement
	let movement = $derived(getRankMovement(entry.rank, entry.previousRank));
	let movementIcon = $derived(
		movement === 'up' ? '▲' : movement === 'down' ? '▼' : '●'
	);
	let movementClass = $derived(
		movement === 'up' ? 'movement-up' : movement === 'down' ? 'movement-down' : 'movement-same'
	);

	// Get config for value formatting
	let config = $derived(LEADERBOARD_CATEGORIES[category]);

	// Format display value with prefix/suffix
	let displayValue = $derived(() => {
		let val = entry.formattedValue;
		if (config.valuePrefix) val = config.valuePrefix + val;
		if (config.valueSuffix) val = val + config.valueSuffix;
		return val;
	});
</script>

<tr class="leaderboard-row" class:is-you={entry.isYou}>
	<td class="col-rank">
		<span class="rank-number">#{entry.rank}</span>
		<span class="rank-movement {movementClass}" title={movement}>{movementIcon}</span>
	</td>

	<td class="col-operator">
		<span class="operator-info">
			{#if entry.isYou}
				<span class="you-indicator">●</span>
				<span class="you-label">YOU</span>
			{/if}
			{#if entry.ensName}
				<span class="ens-name">{entry.ensName}</span>
			{:else}
				<AddressDisplay address={entry.address} copyable={!entry.isYou} />
			{/if}
			{#if entry.crewTag}
				<span class="crew-tag">{entry.crewTag}</span>
			{/if}
		</span>
	</td>

	<td class="col-level">
		{#if entry.level}
			<LevelBadge level={entry.level} compact />
		{:else}
			<span class="offline">OFFLINE</span>
		{/if}
	</td>

	<td class="col-value">
		{displayValue()}
	</td>

	<td class="col-streak">
		{#if entry.ghostStreak !== undefined && entry.ghostStreak > 0}
			<span class="streak-display">
				<span class="streak-icon">&#x1F525;</span>
				<span class="streak-count">{entry.ghostStreak}</span>
			</span>
		{:else if category === 'ghost_streak'}
			<span class="streak-display">
				<span class="streak-icon">&#x1F525;</span>
				<span class="streak-count">{entry.value}</span>
			</span>
		{:else}
			<span class="no-streak">-</span>
		{/if}
	</td>
</tr>

<style>
	.leaderboard-row {
		border-bottom: 1px solid var(--color-border-subtle);
		transition: background var(--duration-fast) var(--ease-default);
	}

	.leaderboard-row:hover {
		background: var(--color-bg-secondary);
	}

	.leaderboard-row.is-you {
		background: rgba(0, 229, 204, 0.06);
		border-left: 2px solid var(--color-accent);
	}

	.leaderboard-row.is-you:hover {
		background: rgba(0, 229, 204, 0.1);
	}

	td {
		padding: var(--space-2) var(--space-3);
		font-family: var(--font-mono);
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

	.col-operator {
		min-width: 180px;
	}

	.operator-info {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.you-indicator {
		color: var(--color-accent);
		font-size: var(--text-xs);
	}

	.you-label {
		color: var(--color-accent);
		font-weight: var(--font-bold);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.ens-name {
		color: var(--color-cyan);
	}

	.crew-tag {
		color: var(--color-amber);
		font-size: var(--text-xs);
		font-weight: var(--font-medium);
	}

	.col-level {
		width: 100px;
	}

	.offline {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wide);
	}

	.col-value {
		width: 120px;
		text-align: right;
		color: var(--color-text-primary);
		font-variant-numeric: tabular-nums;
	}

	.col-streak {
		width: 80px;
		text-align: center;
	}

	.streak-display {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
	}

	.streak-icon {
		font-size: var(--text-sm);
	}

	.streak-count {
		color: var(--color-amber);
		font-weight: var(--font-medium);
	}

	.no-streak {
		color: var(--color-text-tertiary);
	}

	@media (max-width: 640px) {
		td {
			padding: var(--space-1) var(--space-2);
			font-size: var(--text-xs);
		}

		.col-level,
		.col-streak {
			display: none;
		}

		.col-operator {
			min-width: 120px;
		}
	}
</style>
