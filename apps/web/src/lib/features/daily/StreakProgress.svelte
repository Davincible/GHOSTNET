<script lang="ts">
	import type { DailyProgress } from '$lib/core/types';
	import { DAILY_REWARDS } from '$lib/core/types/daily';

	interface Props {
		/** Daily progress data */
		progress: DailyProgress;
		/** Whether to show compact version */
		compact?: boolean;
	}

	let { progress, compact = false }: Props = $props();

	// Determine day marker state
	function getDayState(dayIndex: number): 'completed' | 'current' | 'future' | 'bonus' {
		const day = dayIndex + 1;
		if (day === 7) {
			// Day 7 is special bonus day
			if (progress.weekProgress[dayIndex]) return 'completed';
			if (day === progress.currentStreak && !progress.todayCheckedIn) return 'current';
			return 'bonus';
		}
		if (progress.weekProgress[dayIndex]) return 'completed';
		if (day === progress.currentStreak && !progress.todayCheckedIn) return 'current';
		return 'future';
	}

	// Get reward label for a day
	function getRewardLabel(dayIndex: number): string {
		const reward = DAILY_REWARDS[dayIndex];
		if (reward.type === 'death_rate') {
			return `${Math.abs(reward.value * 100)}%`;
		} else if (reward.type === 'yield') {
			return `+${reward.value * 100}%`;
		}
		return 'BONUS';
	}
</script>

<div class="streak-progress" class:compact>
	<header class="streak-header">
		<span class="streak-title">CHECK-IN PROGRESS</span>
		<span class="streak-count">
			STREAK: {progress.currentStreak} DAY{progress.currentStreak !== 1 ? 'S' : ''}
			{#if progress.currentStreak >= 3}
				<span class="streak-fire">🔥</span>
			{/if}
		</span>
	</header>

	<div class="days-track">
		{#each Array(7) as _, i}
			{@const state = getDayState(i)}
			{@const isToday = i + 1 === progress.currentStreak && !progress.todayCheckedIn}
			<div class="day-wrapper">
				<div
					class="day-marker"
					class:completed={state === 'completed'}
					class:current={state === 'current'}
					class:bonus={state === 'bonus'}
					class:today={isToday}
				>
					{#if state === 'completed'}
						<span class="day-icon">✓</span>
					{:else if i === 6}
						<span class="day-icon">★</span>
					{:else}
						<span class="day-number">{i + 1}</span>
					{/if}
				</div>
				{#if i < 6}
					<div class="day-connector" class:active={progress.weekProgress[i]}></div>
				{/if}
				{#if !compact}
					<span class="day-reward" class:highlight={isToday}>
						{getRewardLabel(i)}
					</span>
				{/if}
			</div>
		{/each}
	</div>

	{#if !compact}
		<div class="today-reward">
			<span class="reward-label">TODAY'S REWARD:</span>
			<span class="reward-value">{progress.nextReward.description}</span>
		</div>
	{/if}
</div>

<style>
	.streak-progress {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.streak-progress.compact {
		gap: var(--space-2);
	}

	.streak-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.streak-title {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.streak-count {
		font-size: var(--text-sm);
		color: var(--color-accent);
		font-weight: var(--font-medium);
	}

	.streak-fire {
		margin-left: var(--space-1);
	}

	.days-track {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
	}

	.day-wrapper {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-1);
		position: relative;
	}

	.day-marker {
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border: 1px solid var(--color-border-default);
		background: var(--color-bg-tertiary);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		transition: all var(--duration-fast) var(--ease-default);
	}

	.compact .day-marker {
		width: 24px;
		height: 24px;
		font-size: var(--text-2xs);
	}

	.day-marker.completed {
		border-color: var(--color-accent);
		background: var(--color-accent-glow);
		color: var(--color-accent);
	}

	.day-marker.current {
		border-color: var(--color-accent);
		box-shadow: 0 0 8px var(--color-accent-glow);
		animation: pulse 2s ease-in-out infinite;
	}

	.day-marker.today {
		border-width: 2px;
	}

	.day-marker.bonus {
		border-color: var(--color-gold);
		color: var(--color-gold);
	}

	.day-marker.bonus.completed {
		background: rgba(255, 215, 0, 0.15);
	}

	@keyframes pulse {
		0%,
		100% {
			box-shadow: 0 0 8px var(--color-accent-glow);
		}
		50% {
			box-shadow: 0 0 16px var(--color-accent-intense);
		}
	}

	.day-icon {
		font-weight: var(--font-semibold);
	}

	.day-number {
		opacity: 0.6;
	}

	.day-connector {
		position: absolute;
		top: 16px;
		left: 32px;
		width: calc(100% - 16px);
		height: 1px;
		background: var(--color-border-subtle);
	}

	.compact .day-connector {
		top: 12px;
		left: 24px;
	}

	.day-connector.active {
		background: var(--color-accent-dim);
	}

	.day-reward {
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wide);
	}

	.day-reward.highlight {
		color: var(--color-accent);
		font-weight: var(--font-medium);
	}

	.today-reward {
		display: flex;
		justify-content: space-between;
		padding: var(--space-2);
		background: var(--color-accent-glow);
		border-left: 2px solid var(--color-accent);
	}

	.reward-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wide);
	}

	.reward-value {
		font-size: var(--text-xs);
		color: var(--color-accent);
		font-weight: var(--font-medium);
	}

	/* Mobile adjustments */
	@media (max-width: 640px) {
		.day-marker {
			width: 28px;
			height: 28px;
		}

		.day-connector {
			top: 14px;
			left: 28px;
		}

		.day-reward {
			font-size: 0.5rem;
		}
	}
</style>
