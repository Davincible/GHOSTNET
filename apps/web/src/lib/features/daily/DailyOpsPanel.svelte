<script lang="ts">
	import { browser } from '$app/environment';
	import type { DailyProgress, DailyMission } from '$lib/core/types';
	import { Box } from '$lib/ui/terminal';
	import { Stack } from '$lib/ui/layout';
	import { Button } from '$lib/ui/primitives';
	import StreakProgress from './StreakProgress.svelte';
	import MissionCard from './MissionCard.svelte';

	interface Props {
		/** Daily progress data */
		progress: DailyProgress;
		/** Daily missions */
		missions: DailyMission[];
		/** Callback when check-in button is clicked */
		onCheckIn?: () => void;
		/** Callback when mission claim button is clicked */
		onClaimMission?: (missionId: string) => void;
		/** Whether check-in action is in progress */
		checkingIn?: boolean;
	}

	let { progress, missions, onCheckIn, onClaimMission, checkingIn = false }: Props = $props();

	// Check if can claim today's reward
	let canCheckIn = $derived(!progress.todayCheckedIn);

	// Count claimable missions
	let claimableMissions = $derived(missions.filter((m) => m.completed && !m.claimed).length);

	// Count completed missions
	let completedMissions = $derived(missions.filter((m) => m.completed).length);

	// Format reset time - use UTC on server to avoid hydration mismatch
	let resetTimeFormatted = $state('00:00 UTC');

	$effect(() => {
		if (browser) {
			// Client-side: use local timezone
			resetTimeFormatted = new Date(progress.nextResetAt).toLocaleTimeString([], {
				hour: '2-digit',
				minute: '2-digit',
				timeZoneName: 'short',
			});
		} else {
			// Server-side: use UTC for consistency
			const date = new Date(progress.nextResetAt);
			const hours = date.getUTCHours().toString().padStart(2, '0');
			const minutes = date.getUTCMinutes().toString().padStart(2, '0');
			resetTimeFormatted = `${hours}:${minutes} UTC`;
		}
	});
</script>

<div class="daily-ops">
	<Box title="DAILY OPS">
		<Stack gap={4}>
			<!-- Check-in Section -->
			<section class="checkin-section">
				<StreakProgress {progress} />

				{#if canCheckIn}
					<div class="checkin-action">
						<Button variant="primary" onclick={onCheckIn} disabled={checkingIn} fullWidth>
							{checkingIn ? 'CLAIMING...' : 'CLAIM DAILY REWARD'}
						</Button>
					</div>
				{:else}
					<div class="checkin-complete">
						<span class="check-icon">✓</span>
						<span class="check-text">Today's reward claimed!</span>
					</div>
				{/if}
			</section>

			<!-- Missions Section -->
			<section class="missions-section">
				<header class="missions-header">
					<span class="missions-title">TODAY'S MISSIONS</span>
					<span class="missions-count">
						{completedMissions}/{missions.length}
						{#if claimableMissions > 0}
							<span class="claimable-badge">{claimableMissions} CLAIMABLE</span>
						{/if}
					</span>
				</header>

				<Stack gap={2}>
					{#each missions as mission (mission.id)}
						<MissionCard {mission} onClaim={onClaimMission} />
					{/each}

					{#if missions.length === 0}
						<div class="no-missions">
							<p>No missions available today.</p>
							<p class="no-missions-hint">Check back tomorrow!</p>
						</div>
					{/if}
				</Stack>
			</section>
		</Stack>
	</Box>

	<!-- Reset countdown -->
	<div class="reset-info">
		<span class="reset-label">Resets at</span>
		<span class="reset-time">{resetTimeFormatted}</span>
	</div>
</div>

<style>
	.daily-ops {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.checkin-section {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.checkin-action {
		margin-top: var(--space-2);
	}

	.checkin-complete {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--color-success-glow, rgba(0, 255, 136, 0.1));
		border: 1px solid var(--color-success);
	}

	.check-icon {
		color: var(--color-success);
		font-weight: var(--font-semibold);
	}

	.check-text {
		font-size: var(--text-sm);
		color: var(--color-success);
	}

	.missions-section {
		border-top: 1px solid var(--color-border-subtle);
		padding-top: var(--space-4);
	}

	.missions-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: var(--space-3);
	}

	.missions-title {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.missions-count {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
	}

	.claimable-badge {
		padding: var(--space-0-5) var(--space-1);
		background: var(--color-accent-glow);
		border: 1px solid var(--color-accent);
		font-size: var(--text-2xs);
		color: var(--color-accent);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wide);
		animation: pulse-glow 2s ease-in-out infinite;
	}

	@keyframes pulse-glow {
		0%,
		100% {
			box-shadow: 0 0 4px var(--color-accent-glow);
		}
		50% {
			box-shadow: 0 0 8px var(--color-accent-intense);
		}
	}

	.no-missions {
		text-align: center;
		padding: var(--space-4);
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
	}

	.no-missions-hint {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		margin-top: var(--space-1);
	}

	.reset-info {
		display: flex;
		justify-content: center;
		gap: var(--space-2);
		padding: var(--space-1);
		font-size: var(--text-2xs);
	}

	.reset-label {
		color: var(--color-text-muted);
	}

	.reset-time {
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
	}

	/* Mobile adjustments */
	@media (max-width: 640px) {
		.missions-header {
			flex-direction: column;
			align-items: flex-start;
			gap: var(--space-1);
		}
	}
</style>
