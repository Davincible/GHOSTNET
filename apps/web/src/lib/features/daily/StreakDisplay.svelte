<script lang="ts">
	import { STREAK_MILESTONES } from '$lib/core/types/daily';
	import type { NextMilestone } from './contractProvider.svelte';

	interface Props {
		/** Current streak count */
		currentStreak: number;
		/** Longest streak ever */
		longestStreak: number;
		/** Death rate reduction in basis points (300 = 3%) */
		deathRateReduction: number;
		/** Whether shield is currently active */
		shieldActive: boolean;
		/** Days remaining on shield */
		shieldDaysRemaining?: number;
		/** Next milestone info */
		nextMilestone: NextMilestone | null;
		/** Progress to next milestone (0-100) */
		milestoneProgress: number;
	}

	let {
		currentStreak,
		longestStreak,
		deathRateReduction,
		shieldActive,
		shieldDaysRemaining,
		nextMilestone,
		milestoneProgress,
	}: Props = $props();

	// Format death rate reduction
	let deathRateFormatted = $derived(
		deathRateReduction > 0 ? `-${(deathRateReduction / 100).toFixed(0)}%` : '0%'
	);

	// Streak tier based on milestones
	let streakTier = $derived.by(() => {
		if (currentStreak >= 180) return 'legendary';
		if (currentStreak >= 90) return 'master';
		if (currentStreak >= 30) return 'veteran';
		if (currentStreak >= 14) return 'dedicated';
		if (currentStreak >= 7) return 'consistent';
		if (currentStreak >= 3) return 'promising';
		return 'new';
	});

	// Get streak emoji/icon
	let streakIcon = $derived.by(() => {
		if (currentStreak >= 90) return '⚡';
		if (currentStreak >= 30) return '🔥';
		if (currentStreak >= 7) return '✨';
		if (currentStreak >= 3) return '🌟';
		return '○';
	});
</script>

<div class="streak-display" data-tier={streakTier}>
	<!-- Main Streak Counter -->
	<div class="streak-main">
		<div class="streak-icon">{streakIcon}</div>
		<div class="streak-count">
			<span class="count-value">{currentStreak}</span>
			<span class="count-label">DAY{currentStreak !== 1 ? 'S' : ''}</span>
		</div>
		{#if shieldActive}
			<div class="shield-indicator" title={`Shield: ${shieldDaysRemaining} day(s) remaining`}>
				🛡️
			</div>
		{/if}
	</div>

	<!-- Stats Row -->
	<div class="streak-stats">
		<div class="stat">
			<span class="stat-label">BEST</span>
			<span class="stat-value">{longestStreak}</span>
		</div>
		<div class="stat-divider"></div>
		<div class="stat death-rate" class:active={deathRateReduction > 0}>
			<span class="stat-label">DEATH RATE</span>
			<span class="stat-value">{deathRateFormatted}</span>
		</div>
	</div>

	<!-- Milestone Progress -->
	{#if nextMilestone}
		<div class="milestone-section">
			<div class="milestone-header">
				<span class="milestone-label">NEXT: {nextMilestone.days} DAYS</span>
				<span class="milestone-remaining">{nextMilestone.daysRemaining} to go</span>
			</div>
			<div class="milestone-bar">
				<div class="milestone-fill" style:width="{milestoneProgress}%"></div>
			</div>
			<div class="milestone-reward">
				{#if nextMilestone.badge}
					<span class="reward-badge">🏆 {nextMilestone.badge}</span>
				{/if}
				{#if nextMilestone.bonus > 0n}
					<span class="reward-bonus">
						+{Number(nextMilestone.bonus / 10n ** 18n).toLocaleString()} DATA
					</span>
				{/if}
				<span class="reward-reduction">
					-{(nextMilestone.deathRateReduction / 100).toFixed(0)}% death rate
				</span>
			</div>
		</div>
	{:else}
		<div class="milestone-complete">
			<span class="complete-icon">★</span>
			<span class="complete-text">ALL MILESTONES ACHIEVED</span>
		</div>
	{/if}
</div>

<style>
	.streak-display {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		padding: var(--space-4);
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-default);
	}

	/* Tier-based styling */
	.streak-display[data-tier='legendary'] {
		border-color: var(--color-gold);
		box-shadow: 0 0 20px rgba(255, 215, 0, 0.2);
	}

	.streak-display[data-tier='master'] {
		border-color: var(--color-accent);
		box-shadow: 0 0 15px var(--color-accent-glow);
	}

	.streak-display[data-tier='veteran'] {
		border-color: var(--color-accent-dim);
	}

	/* Main streak counter */
	.streak-main {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-3);
	}

	.streak-icon {
		font-size: var(--text-2xl);
	}

	.streak-count {
		display: flex;
		flex-direction: column;
		align-items: center;
	}

	.count-value {
		font-size: var(--text-4xl);
		font-weight: var(--font-bold);
		font-family: var(--font-mono);
		color: var(--color-accent);
		line-height: 1;
	}

	.streak-display[data-tier='legendary'] .count-value {
		color: var(--color-gold);
	}

	.count-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-widest);
	}

	.shield-indicator {
		font-size: var(--text-xl);
		animation: shield-pulse 2s ease-in-out infinite;
	}

	@keyframes shield-pulse {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.6;
		}
	}

	/* Stats row */
	.streak-stats {
		display: flex;
		justify-content: center;
		align-items: center;
		gap: var(--space-4);
	}

	.stat {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-0-5);
	}

	.stat-label {
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wider);
	}

	.stat-value {
		font-size: var(--text-sm);
		font-family: var(--font-mono);
		color: var(--color-text-secondary);
	}

	.death-rate.active .stat-value {
		color: var(--color-success);
		font-weight: var(--font-medium);
	}

	.stat-divider {
		width: 1px;
		height: 24px;
		background: var(--color-border-subtle);
	}

	/* Milestone section */
	.milestone-section {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		padding-top: var(--space-3);
		border-top: 1px solid var(--color-border-subtle);
	}

	.milestone-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.milestone-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wide);
	}

	.milestone-remaining {
		font-size: var(--text-xs);
		color: var(--color-accent);
		font-family: var(--font-mono);
	}

	.milestone-bar {
		height: 4px;
		background: var(--color-bg-tertiary);
		overflow: hidden;
	}

	.milestone-fill {
		height: 100%;
		background: var(--color-accent);
		transition: width var(--duration-normal) var(--ease-default);
	}

	.milestone-reward {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
		font-size: var(--text-2xs);
	}

	.reward-badge {
		color: var(--color-gold);
	}

	.reward-bonus {
		color: var(--color-accent);
	}

	.reward-reduction {
		color: var(--color-success);
	}

	/* Complete state */
	.milestone-complete {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: rgba(255, 215, 0, 0.1);
		border: 1px solid var(--color-gold);
	}

	.complete-icon {
		color: var(--color-gold);
		font-size: var(--text-lg);
	}

	.complete-text {
		font-size: var(--text-xs);
		color: var(--color-gold);
		letter-spacing: var(--tracking-wide);
	}

	/* Mobile */
	@media (max-width: 640px) {
		.streak-display {
			padding: var(--space-3);
		}

		.count-value {
			font-size: var(--text-3xl);
		}
	}
</style>
