<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { Badge } from '$lib/ui/primitives';
	import type { RoundResult } from './store.svelte';

	interface Props {
		/** Result from the completed round */
		result: RoundResult;
		/** Current round number (1-indexed) */
		currentRound: number;
		/** Total number of rounds */
		totalRounds: number;
	}

	let { result, currentRound, totalRounds }: Props = $props();

	// Determine performance tier
	let tier = $derived.by(() => {
		if (result.accuracy >= 1.0) return { label: 'PERFECT', color: 'gold' };
		if (result.accuracy >= 0.95) return { label: 'EXCELLENT', color: 'success' };
		if (result.accuracy >= 0.85) return { label: 'GREAT', color: 'success' };
		if (result.accuracy >= 0.7) return { label: 'GOOD', color: 'info' };
		if (result.accuracy >= 0.5) return { label: 'OKAY', color: 'warning' };
		return { label: 'FAILED', color: 'danger' };
	});

	let nextRound = $derived(currentRound + 1);
</script>

<div class="round-complete-view">
	<Box>
		<div class="round-content">
			<div class="round-header">
				<span class="round-label">ROUND {currentRound}/{totalRounds}</span>
				<Badge
					variant={tier.color === 'gold'
						? 'success'
						: (tier.color as 'success' | 'info' | 'warning' | 'danger')}
				>
					{tier.label}
				</Badge>
			</div>

			<div class="stats-row">
				<div class="stat">
					<span class="stat-value">{result.wpm}</span>
					<span class="stat-label">WPM</span>
				</div>
				<div class="stat">
					<span class="stat-value">{Math.round(result.accuracy * 100)}%</span>
					<span class="stat-label">ACC</span>
				</div>
			</div>

			<div class="next-round">
				<span class="preparing">Preparing round {nextRound}...</span>
				<div class="loading-bar">
					<div class="loading-fill"></div>
				</div>
			</div>
		</div>
	</Box>
</div>

<style>
	.round-complete-view {
		max-width: 400px;
		margin: 0 auto;
	}

	.round-content {
		padding: var(--space-4);
		text-align: center;
	}

	.round-header {
		display: flex;
		justify-content: center;
		align-items: center;
		gap: var(--space-3);
		margin-bottom: var(--space-4);
	}

	.round-label {
		color: var(--color-green-mid);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wide);
	}

	.stats-row {
		display: flex;
		justify-content: center;
		gap: var(--space-6);
		margin-bottom: var(--space-4);
	}

	.stat {
		text-align: center;
	}

	.stat-value {
		display: block;
		color: var(--color-green-bright);
		font-size: var(--text-2xl);
		font-weight: var(--font-bold);
		font-variant-numeric: tabular-nums;
	}

	.stat-label {
		display: block;
		color: var(--color-green-dim);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wide);
		margin-top: var(--space-1);
	}

	.next-round {
		padding-top: var(--space-3);
		border-top: 1px solid var(--color-bg-tertiary);
	}

	.preparing {
		color: var(--color-green-dim);
		font-size: var(--text-sm);
		display: block;
		margin-bottom: var(--space-2);
	}

	.loading-bar {
		height: 4px;
		background: var(--color-bg-tertiary);
		border-radius: 2px;
		overflow: hidden;
	}

	.loading-fill {
		height: 100%;
		background: var(--color-green-mid);
		animation: loading 1.5s ease-in-out;
	}

	@keyframes loading {
		0% {
			width: 0%;
		}
		100% {
			width: 100%;
		}
	}
</style>
