<script lang="ts">
	import type { DeadPoolRound } from '$lib/core/types';
	import { Box } from '$lib/ui/terminal';
	import { Button } from '$lib/ui/primitives';
	import { LevelBadge } from '$lib/ui/data-display';
	import { formatCountdown, formatDuration } from '$lib/core/utils';
	import OddsDisplay from './OddsDisplay.svelte';
	import PoolBars from './PoolBars.svelte';

	interface Props {
		/** Round data */
		round: DeadPoolRound;
		/** Callback when user wants to place a bet */
		onBet?: () => void;
	}

	let { round, onBet }: Props = $props();

	// Calculate odds multipliers - safe division
	const totalPool = $derived(round.pools.under + round.pools.over);
	const odds = $derived({
		under:
			round.pools.under > 0n && totalPool > 0n ? Number(totalPool) / Number(round.pools.under) : 2,
		over:
			round.pools.over > 0n && totalPool > 0n ? Number(totalPool) / Number(round.pools.over) : 2,
	});

	// Time tracking
	let now = $state(Date.now());

	$effect(() => {
		const interval = setInterval(() => {
			now = Date.now();
		}, 1000);
		return () => clearInterval(interval);
	});

	const timeUntilLock = $derived(Math.max(0, round.locksAt - now));
	const timeUntilEnd = $derived(Math.max(0, round.endsAt - now));

	// Status display using $derived.by for complex logic
	const statusLabel = $derived.by(() => {
		switch (round.status) {
			case 'betting':
				return 'BETTING OPEN';
			case 'locked':
				return 'BETS LOCKED';
			case 'resolving':
				return 'RESOLVING...';
			case 'resolved':
				return 'RESOLVED';
			default:
				return 'UNKNOWN';
		}
	});

	const statusClass = $derived.by(() => {
		switch (round.status) {
			case 'betting':
				return 'status-betting';
			case 'locked':
				return 'status-locked';
			case 'resolving':
				return 'status-resolving';
			case 'resolved':
				return 'status-resolved';
			default:
				return '';
		}
	});

	// Can user bet?
	const canBet = $derived(round.status === 'betting' && timeUntilLock > 0);
</script>

<Box variant="single" borderColor={round.userBet ? 'cyan' : 'default'} padding={3}>
	<div class="round-card">
		<!-- Header: Round number, type, level -->
		<div class="round-header">
			<div class="round-meta">
				<span class="round-number">ROUND #{round.roundNumber}</span>
				{#if round.targetLevel}
					<LevelBadge level={round.targetLevel} compact />
				{/if}
			</div>
			<span class="round-status {statusClass}" role="status">{statusLabel}</span>
		</div>

		<!-- Question -->
		<p class="round-question">{round.question}</p>

		<!-- Line display -->
		<div class="line-display">
			<span class="line-label">LINE:</span>
			<span class="line-value">{round.line}</span>
		</div>

		<!-- Odds display -->
		<OddsDisplay pools={round.pools} {odds} userBetSide={round.userBet?.side} compact />

		<!-- Pool bars -->
		<PoolBars pools={round.pools} width={24} />

		<!-- Timer and action -->
		<div class="round-footer">
			<div class="timer" aria-live="polite">
				{#if round.status === 'betting'}
					<span class="timer-label">LOCKS IN:</span>
					<span class="timer-value">{formatCountdown(timeUntilLock)}</span>
				{:else if round.status === 'locked' || round.status === 'resolving'}
					<span class="timer-label">RESOLVES IN:</span>
					<span class="timer-value">{formatCountdown(timeUntilEnd)}</span>
				{:else}
					<span class="timer-label">COMPLETE</span>
				{/if}
			</div>

			{#if canBet && !round.userBet}
				<Button variant="primary" size="sm" onclick={onBet}>PLACE BET</Button>
			{:else if round.userBet}
				<div class="user-bet-indicator" aria-label="Your bet: {round.userBet.side}">
					<span class="bet-side">{round.userBet.side.toUpperCase()}</span>
				</div>
			{/if}
		</div>
	</div>
</Box>

<style>
	.round-card {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.round-header {
		display: flex;
		flex-wrap: wrap;
		justify-content: space-between;
		align-items: center;
		gap: var(--space-2);
	}

	.round-meta {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.round-number {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.round-status {
		font-size: var(--text-xs);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wider);
		padding: var(--space-1) var(--space-2);
		border: 1px solid currentColor;
	}

	.status-betting {
		color: var(--color-profit);
		background: var(--color-profit-glow);
	}

	.status-locked {
		color: var(--color-amber);
		background: var(--color-amber-glow);
	}

	.status-resolving {
		color: var(--color-cyan);
		background: var(--color-cyan-glow);
		animation: pulse 1s ease-in-out infinite;
	}

	.status-resolved {
		color: var(--color-text-tertiary);
		background: var(--color-bg-tertiary);
	}

	@keyframes pulse {
		0%,
		100% {
			opacity: 0.7;
		}
		50% {
			opacity: 1;
		}
	}

	.round-question {
		color: var(--color-text-primary);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		line-height: var(--leading-relaxed);
		margin: 0;
	}

	.line-display {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
	}

	.line-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.line-value {
		color: var(--color-text-primary);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
	}

	.round-footer {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-top: var(--space-1);
	}

	.timer {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.timer-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
	}

	.timer-value {
		color: var(--color-text-primary);
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		font-variant-numeric: tabular-nums;
	}

	.user-bet-indicator {
		display: flex;
		align-items: center;
		gap: var(--space-1);
		color: var(--color-cyan);
		font-size: var(--text-xs);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wider);
	}

	.bet-side {
		padding: var(--space-1) var(--space-2);
		border: 1px solid var(--color-cyan);
		background: var(--color-cyan-glow);
	}
</style>
