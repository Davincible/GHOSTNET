<script lang="ts">
	import { Badge, Countdown, Button } from '$lib/ui/primitives';
	import { LevelBadge, AmountDisplay } from '$lib/ui/data-display';
	import { Row, Stack } from '$lib/ui/layout';
	import OddsDisplay from './OddsDisplay.svelte';
	import PoolBars from './PoolBars.svelte';
	import { calculateOdds, canBet } from '$lib/core/providers/mock/generators/deadpool';
	import type { DeadPoolRound, DeadPoolSide, DeadPoolRoundType } from '$lib/core/types';

	interface Props {
		/** The betting round data */
		round: DeadPoolRound;
		/** Handler for placing a bet */
		onBet: (round: DeadPoolRound, side: DeadPoolSide) => void;
	}

	let { round, onBet }: Props = $props();

	// Calculate live odds
	let odds = $derived(calculateOdds(round.pools));
	let bettingOpen = $derived(canBet(round));

	// Round type display mapping
	const typeLabels: Record<DeadPoolRoundType, string> = {
		death_count: 'DEATH COUNT',
		whale_watch: 'WHALE WATCH',
		survival_streak: 'SURVIVAL STREAK',
		system_reset: 'SYSTEM RESET',
	};

	// Round type badge variant
	const typeVariants: Record<DeadPoolRoundType, 'default' | 'danger' | 'warning' | 'info'> = {
		death_count: 'danger',
		whale_watch: 'warning',
		survival_streak: 'info',
		system_reset: 'danger',
	};

	// Determine button labels based on round type
	let buttonLabels = $derived.by(() => {
		if (round.type === 'whale_watch') {
			return { under: 'NO', over: 'YES' };
		}
		return { under: 'UNDER', over: 'OVER' };
	});

	function handleBetUnder() {
		onBet(round, 'under');
	}

	function handleBetOver() {
		onBet(round, 'over');
	}
</script>

<div
	class="round-card"
	class:card-locked={!bettingOpen}
	class:card-has-bet={round.userBet !== null}
>
	<!-- Header: Round number and type -->
	<div class="card-header">
		<span class="round-number">#{round.roundNumber}</span>
		<Badge variant={typeVariants[round.type]}>{typeLabels[round.type]}</Badge>
	</div>

	<!-- Target level (if applicable) -->
	{#if round.targetLevel}
		<div class="target-level">
			<LevelBadge level={round.targetLevel} glow />
		</div>
	{/if}

	<!-- Question -->
	<p class="question">"{round.question}"</p>

	<!-- Line and timer -->
	<div class="meta-row">
		<div class="meta-item">
			<span class="meta-label">LINE</span>
			<span class="meta-value">{round.line}</span>
		</div>
		<div class="meta-item">
			<span class="meta-label">ENDS</span>
			<Countdown targetTime={round.endsAt} urgentThreshold={300} />
		</div>
	</div>

	<!-- Pool distribution bar -->
	<PoolBars pools={round.pools} width={24} />

	<!-- Odds display -->
	<OddsDisplay pools={round.pools} {odds} userBetSide={round.userBet?.side ?? null} compact />

	<!-- Bet buttons -->
	<div class="bet-actions">
		<Button
			variant="secondary"
			size="sm"
			onclick={handleBetUnder}
			disabled={!bettingOpen || round.userBet !== null}
		>
			{buttonLabels.under}
		</Button>
		<Button
			variant="secondary"
			size="sm"
			onclick={handleBetOver}
			disabled={!bettingOpen || round.userBet !== null}
		>
			{buttonLabels.over}
		</Button>
	</div>

	<!-- Locked overlay -->
	{#if !bettingOpen}
		<div class="locked-overlay">
			<span class="locked-text">BETTING LOCKED</span>
		</div>
	{/if}
</div>

<style>
	.round-card {
		position: relative;
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		padding: var(--space-3);
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-subtle);
		font-family: var(--font-mono);
		transition: all var(--duration-fast) var(--ease-default);
	}

	.round-card:hover:not(.card-locked) {
		border-color: var(--color-border-default);
		background: var(--color-bg-tertiary);
	}

	.round-card.card-has-bet {
		border-color: var(--color-accent-dim);
		box-shadow: 0 0 8px var(--color-accent-glow);
	}

	.round-card.card-locked {
		opacity: 0.7;
	}

	.card-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-2);
	}

	.round-number {
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
		font-weight: var(--font-medium);
	}

	.target-level {
		font-size: var(--text-sm);
	}

	.question {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		line-height: var(--leading-relaxed);
		font-style: italic;
	}

	.meta-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: var(--space-1) 0;
		border-top: 1px solid var(--color-border-subtle);
		border-bottom: 1px solid var(--color-border-subtle);
	}

	.meta-item {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.meta-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.meta-value {
		font-size: var(--text-sm);
		color: var(--color-accent);
		font-weight: var(--font-bold);
	}

	.bet-actions {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: var(--space-2);
		margin-top: var(--space-1);
	}

	.locked-overlay {
		position: absolute;
		inset: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		background: rgba(3, 3, 5, 0.75);
		pointer-events: none;
	}

	.locked-text {
		font-size: var(--text-xs);
		color: var(--color-amber);
		letter-spacing: var(--tracking-widest);
		text-transform: uppercase;
		padding: var(--space-1) var(--space-2);
		border: 1px solid var(--color-amber-dim);
		background: var(--color-bg-secondary);
	}
</style>
