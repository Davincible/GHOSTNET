<script lang="ts">
	import type { LeaderboardTimeframe } from '$lib/core/types/leaderboard';

	interface Props {
		/** Currently selected timeframe */
		selected: LeaderboardTimeframe;
		/** Callback when timeframe changes */
		onchange: (timeframe: LeaderboardTimeframe) => void;
	}

	let { selected, onchange }: Props = $props();

	const timeframes: { value: LeaderboardTimeframe; label: string }[] = [
		{ value: 'all_time', label: 'ALL TIME' },
		{ value: 'monthly', label: 'MONTHLY' },
		{ value: 'weekly', label: 'WEEKLY' },
		{ value: 'daily', label: 'DAILY' },
	];
</script>

<div class="timeframe-tabs" role="tablist" aria-label="Time period">
	{#each timeframes as { value, label }}
		{@const isActive = selected === value}
		<button
			type="button"
			role="tab"
			aria-selected={isActive}
			class="tab"
			class:tab-active={isActive}
			onclick={() => onchange(value)}
		>
			{isActive ? '[' : ''}{label}{isActive ? ']' : ''}
		</button>
	{/each}
</div>

<style>
	.timeframe-tabs {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-1);
	}

	.tab {
		padding: var(--space-1) var(--space-2);
		background: transparent;
		border: 1px solid var(--color-border-subtle);
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wide);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.tab:hover:not(.tab-active) {
		color: var(--color-text-secondary);
		border-color: var(--color-border-default);
	}

	.tab-active {
		color: var(--color-cyan);
		border-color: var(--color-cyan-dim);
		background: rgba(0, 229, 255, 0.06);
	}

	.tab:focus-visible {
		outline: 1px solid var(--color-cyan);
		outline-offset: 2px;
	}

	@media (max-width: 640px) {
		.tab {
			padding: var(--space-0-5) var(--space-1);
			font-size: 0.625rem;
		}
	}
</style>
