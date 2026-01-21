<script lang="ts">
	import type { DailyMission } from '$lib/core/types';
	import { Button, ProgressBar } from '$lib/ui/primitives';

	interface Props {
		/** Mission data */
		mission: DailyMission;
		/** Callback when claim button is clicked */
		onClaim?: (missionId: string) => void;
	}

	let { mission, onClaim }: Props = $props();

	// Calculate progress percentage
	let progressPercent = $derived(
		mission.target > 0 ? Math.min(100, (mission.progress / mission.target) * 100) : 0
	);

	// Format reward for display
	let rewardText = $derived(() => {
		const { type, value, duration } = mission.reward;
		const durationText = duration ? ` (${Math.round(duration / (60 * 60 * 1000))}h)` : '';

		switch (type) {
			case 'death_rate':
				return `${Math.abs(value * 100)}% death rate reduction${durationText}`;
			case 'yield':
				return `+${value * 100}% yield${durationText}`;
			case 'tokens':
				return `+${value} $DATA`;
			default:
				return 'Unknown reward';
		}
	});

	// Mission status icon
	let statusIcon = $derived(() => {
		if (mission.claimed) return '✓';
		if (mission.completed) return '●';
		if (mission.progress > 0) return '■';
		return '□';
	});

	function handleClaim() {
		onClaim?.(mission.id);
	}
</script>

<article class="mission-card" class:completed={mission.completed} class:claimed={mission.claimed}>
	<header class="mission-header">
		<span class="mission-status">{statusIcon()}</span>
		<span class="mission-title">{mission.title}</span>
		<span class="mission-progress-text">
			{mission.progress}/{mission.target}
		</span>
	</header>

	<p class="mission-description">{mission.description}</p>

	{#if !mission.claimed}
		<div class="mission-progress-bar">
			<ProgressBar value={progressPercent} variant={mission.completed ? 'success' : 'default'} />
		</div>
	{/if}

	<footer class="mission-footer">
		<span class="mission-reward">
			<span class="reward-label">Reward:</span>
			{rewardText()}
		</span>

		{#if mission.completed && !mission.claimed}
			<Button variant="primary" size="sm" onclick={handleClaim}>CLAIM</Button>
		{/if}

		{#if mission.claimed}
			<span class="claimed-badge">CLAIMED</span>
		{/if}
	</footer>
</article>

<style>
	.mission-card {
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
		transition: border-color var(--duration-fast) var(--ease-default);
	}

	.mission-card:hover {
		border-color: var(--color-border-default);
	}

	.mission-card.completed {
		border-color: var(--color-accent-dim);
	}

	.mission-card.claimed {
		opacity: 0.7;
		border-color: var(--color-border-subtle);
	}

	.mission-header {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		margin-bottom: var(--space-2);
	}

	.mission-status {
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
	}

	.mission-card.completed .mission-status {
		color: var(--color-accent);
	}

	.mission-card.claimed .mission-status {
		color: var(--color-success);
	}

	.mission-title {
		flex: 1;
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wide);
	}

	.mission-card.completed .mission-title {
		color: var(--color-accent);
	}

	.mission-progress-text {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
	}

	.mission-description {
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
		line-height: 1.5;
		margin: 0 0 var(--space-2);
	}

	.mission-progress-bar {
		margin-bottom: var(--space-2);
	}

	.mission-footer {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: var(--space-2);
	}

	.mission-reward {
		font-size: var(--text-2xs);
		color: var(--color-text-tertiary);
	}

	.reward-label {
		color: var(--color-text-muted);
		margin-right: var(--space-1);
	}

	.claimed-badge {
		font-size: var(--text-2xs);
		color: var(--color-success);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wider);
	}

	/* Mobile adjustments */
	@media (max-width: 640px) {
		.mission-card {
			padding: var(--space-2);
		}

		.mission-title {
			font-size: var(--text-xs);
		}

		.mission-description {
			font-size: var(--text-2xs);
		}
	}
</style>
