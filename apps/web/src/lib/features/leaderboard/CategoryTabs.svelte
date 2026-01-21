<script lang="ts">
	import type { LeaderboardCategory } from '$lib/core/types/leaderboard';
	import { LEADERBOARD_CATEGORIES } from '$lib/core/types/leaderboard';

	interface Props {
		/** Currently selected category */
		selected: LeaderboardCategory;
		/** Callback when category changes */
		onchange: (category: LeaderboardCategory) => void;
	}

	let { selected, onchange }: Props = $props();

	const categories: LeaderboardCategory[] = [
		'ghost_streak',
		'total_extracted',
		'weekly_extracted',
		'total_staked',
		'risk_score',
		'crews',
	];
</script>

<div class="category-tabs" role="tablist" aria-label="Leaderboard categories">
	{#each categories as category (category)}
		{@const config = LEADERBOARD_CATEGORIES[category]}
		{@const isActive = selected === category}
		<button
			type="button"
			role="tab"
			aria-selected={isActive}
			class="tab"
			class:tab-active={isActive}
			onclick={() => onchange(category)}
		>
			{isActive ? '[' : ''}{config.shortLabel}{isActive ? ']' : ''}
		</button>
	{/each}
</div>

<style>
	.category-tabs {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-1);
	}

	.tab {
		padding: var(--space-2) var(--space-3);
		background: transparent;
		border: 1px solid var(--color-border-subtle);
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wide);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.tab:hover:not(.tab-active) {
		color: var(--color-text-secondary);
		border-color: var(--color-border-default);
		background: var(--color-bg-secondary);
	}

	.tab-active {
		color: var(--color-accent);
		border-color: var(--color-accent-dim);
		background: rgba(0, 229, 204, 0.08);
	}

	.tab:focus-visible {
		outline: 1px solid var(--color-accent);
		outline-offset: 2px;
	}

	@media (max-width: 640px) {
		.category-tabs {
			gap: var(--space-0-5);
		}

		.tab {
			padding: var(--space-1) var(--space-2);
			font-size: var(--text-xs);
		}
	}
</style>
