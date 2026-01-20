<script lang="ts">
	import type { DeadPoolRound } from '$lib/core/types';
	import { Box } from '$lib/ui/terminal';
	import { Button } from '$lib/ui/primitives';
	import { LevelBadge } from '$lib/ui/data-display';
	import type { Level } from '$lib/core/types';
	import { Row } from '$lib/ui/layout';
	import OddsDisplay from './OddsDisplay.svelte';
	import PoolBars from './PoolBars.svelte';

	interface Props {
		/** Round data */
		round: DeadPoolRound;
		/** Callback when user wants to place a bet */
		onBet?: () => void;
	}

	let { round, onBet }: Props = $props();

	// Calculate odds multipliers
	let totalPool = $derived(round.pools.under + round.pools.over);
	let odds = $derived({
		under: totalPool > 0n ? Number(totalPool) / Number(round.pools.under || 1n) : 2,
		over: totalPool > 0n ? Number(totalPool) / Number(round.pools.over || 1n) : 2
	});

	// Time until lock/end
	let now = $state(Date.now());
	$effect(() => {
		const interval = setInterval(() => {
			now = Date.now();
		}, 1000);
		return () => clearInterval(interval);
	});

	let timeUntilLock = $derived(Math.max(0, round.locksAt - now));
	let timeUntilEnd = $derived(Math.max(0, round.endsAt - now));

	// Format time display
	function formatTime(ms: number): string {
		if (ms <= 0) return '00:00';
		const totalSeconds = Math.floor(ms / 1000);
		const minutes = Math.floor(totalSeconds / 60);
		const seconds = totalSeconds % 60;
		if (minutes >= 60) {
			const hours = Math.floor(minutes / 60);
			const mins = minutes % 60;
			return `${hours}h ${mins.toString().padStart(2, '0')}m`;
		}
		return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
	}

	// Status display
	let statusLabel = $derived(() => {
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

	let statusClass = $derived(() => {
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
	let canBet = $derived(round.status === 'betting' && timeUntilLock > 0);
</script>

<Box variant="single" borderColor={round.userBet ? 'cyan' : 'default'} padding={3}>
	<div class="round-card">
		<!-- Header: Round number, type, level -->
		<Row justify="between" align="center" class="round-header">
			<div class="round-meta">
				<span class="round-number">ROUND #{round.roundNumber}</span>
				{#if round.targetLevel}
					<LevelBadge level={round.targetLevel} compact />
				{/if}
			</div>
			<span class="round-status {statusClass()}">{statusLabel()}</span>
		</Row>

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
		<Row justify="between" align="center" class="round-footer">
			<div class="timer">
				{#if round.status === 'betting'}
					<span class="timer-label">LOCKS IN:</span>
					<span class="timer-value">{formatTime(timeUntilLock)}</span>
				{:else if round.status === 'locked' || round.status === 'resolving'}
					<span class="timer-label">RESOLVES IN:</span>
					<span class="timer-value">{formatTime(timeUntilEnd)}</span>
				{:else}
					<span class="timer-label">COMPLETE</span>
				{/if}
			</div>

			{#if canBet && !round.userBet}
				<Button variant="primary" size="sm" onclick={onBet}>
					PLACE BET
				</Button>
			{:else if round.userBet}
				<div class="user-bet-indicator">
					<span class="bet-side">{round.userBet.side.toUpperCase()}</span>
				</div>
			{/if}
		</Row>
	</div>
</Box>

<style>
	.round-card {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	:global(.round-header) {
		flex-wrap: wrap;
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
		background: rgba(0, 255, 136, 0.1);
	}

	.status-locked {
		color: var(--color-amber);
		background: rgba(255, 193, 7, 0.1);
	}

	.status-resolving {
		color: var(--color-cyan);
		background: rgba(0, 229, 204, 0.1);
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

	:global(.round-footer) {
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
		background: rgba(0, 229, 204, 0.1);
	}
</style>
