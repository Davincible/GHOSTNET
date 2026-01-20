<script lang="ts">
	import { AmountDisplay } from '$lib/ui/data-display';
	import type { DeadPoolSide } from '$lib/core/types';

	interface Props {
		/** Pool sizes for each side */
		pools: { under: bigint; over: bigint };
		/** Calculated odds multiplier for each side */
		odds: { under: number; over: number };
		/** Which side the user has bet on (if any) */
		userBetSide?: DeadPoolSide | null;
		/** Compact display mode */
		compact?: boolean;
	}

	let { pools, odds, userBetSide = null, compact = false }: Props = $props();
</script>

<div class="odds-display" class:odds-compact={compact}>
	<div class="odds-side odds-under" class:odds-user-bet={userBetSide === 'under'}>
		<span class="odds-label">UNDER</span>
		<div class="odds-pool">
			<AmountDisplay amount={pools.under} format="compact" />
		</div>
		<span class="odds-multiplier">{odds.under.toFixed(2)}x</span>
		{#if userBetSide === 'under'}
			<span class="odds-your-bet">YOUR BET</span>
		{/if}
	</div>

	<div class="odds-divider">
		<span class="odds-vs">VS</span>
	</div>

	<div class="odds-side odds-over" class:odds-user-bet={userBetSide === 'over'}>
		<span class="odds-label">OVER</span>
		<div class="odds-pool">
			<AmountDisplay amount={pools.over} format="compact" />
		</div>
		<span class="odds-multiplier">{odds.over.toFixed(2)}x</span>
		{#if userBetSide === 'over'}
			<span class="odds-your-bet">YOUR BET</span>
		{/if}
	</div>
</div>

<style>
	.odds-display {
		display: flex;
		align-items: stretch;
		gap: var(--space-2);
		font-family: var(--font-mono);
	}

	.odds-side {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-1);
		padding: var(--space-2);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
		transition: all var(--duration-fast) var(--ease-default);
	}

	.odds-under {
		border-color: var(--color-cyan-dim);
	}

	.odds-over {
		border-color: var(--color-amber-dim);
	}

	.odds-user-bet {
		background: var(--color-bg-elevated);
		box-shadow: var(--shadow-glow-accent);
	}

	.odds-user-bet.odds-under {
		border-color: var(--color-cyan);
	}

	.odds-user-bet.odds-over {
		border-color: var(--color-amber);
	}

	.odds-label {
		font-size: var(--text-xs);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wider);
		color: var(--color-text-tertiary);
	}

	.odds-pool {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
	}

	.odds-multiplier {
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
	}

	.odds-under .odds-multiplier {
		color: var(--color-cyan);
	}

	.odds-over .odds-multiplier {
		color: var(--color-amber);
	}

	.odds-your-bet {
		font-size: var(--text-xs);
		color: var(--color-accent);
		letter-spacing: var(--tracking-wide);
		animation: pulse-glow 2s ease-in-out infinite;
	}

	@keyframes pulse-glow {
		0%,
		100% {
			opacity: 0.7;
		}
		50% {
			opacity: 1;
		}
	}

	.odds-divider {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0 var(--space-1);
	}

	.odds-vs {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wide);
	}

	/* Compact mode */
	.odds-compact {
		gap: var(--space-1);
	}

	.odds-compact .odds-side {
		padding: var(--space-1);
	}

	.odds-compact .odds-pool {
		font-size: var(--text-xs);
	}

	.odds-compact .odds-multiplier {
		font-size: var(--text-sm);
	}
</style>
