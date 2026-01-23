<script lang="ts">
	import { formatMultiplier, getMultiplierColor } from '../store.svelte';

	interface Props {
		/** History of recent crash points */
		crashPoints: number[];
	}

	let { crashPoints }: Props = $props();
</script>

<div class="recent-crashes">
	<span class="label">RECENT:</span>
	<div class="crash-list">
		{#each crashPoints as point, i (i)}
			<span class="crash-point {getMultiplierColor(point)}">
				{formatMultiplier(point)}
			</span>
		{/each}
		{#if crashPoints.length === 0}
			<span class="no-data">-</span>
		{/if}
	</div>
</div>

<style>
	.recent-crashes {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-2) var(--space-3);
		background: var(--color-bg-tertiary);
		overflow-x: auto;
	}

	.label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
		flex-shrink: 0;
	}

	.crash-list {
		display: flex;
		gap: var(--space-2);
	}

	.crash-point {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		padding: var(--space-1) var(--space-2);
		background: var(--color-bg-void);
		white-space: nowrap;
	}

	/* Color variants */
	.crash-point.mult-low {
		color: var(--color-red);
	}

	.crash-point.mult-mid {
		color: var(--color-accent);
	}

	.crash-point.mult-high {
		color: var(--color-cyan);
	}

	.crash-point.mult-extreme {
		color: var(--color-amber);
		text-shadow: 0 0 10px var(--color-amber-glow);
	}

	.no-data {
		color: var(--color-text-tertiary);
	}
</style>
