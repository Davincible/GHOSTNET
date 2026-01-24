<script lang="ts">
	import { BADGE_INFO, BADGE_IDS } from '$lib/core/types/daily';
	import type { RawBadge } from './contracts';

	interface Props {
		/** Player's earned badges */
		badges: RawBadge[];
		/** Whether to show all badges (locked ones too) */
		showAll?: boolean;
		/** Compact mode */
		compact?: boolean;
	}

	let { badges, showAll = false, compact = false }: Props = $props();

	// All possible badges in order
	const ALL_BADGES = [
		{ id: BADGE_IDS.WEEK_WARRIOR, days: 7 },
		{ id: BADGE_IDS.DEDICATED_OPERATOR, days: 30 },
		{ id: BADGE_IDS.LEGEND, days: 90 },
	] as const;

	// Check if a badge is earned
	function isEarned(badgeId: string): boolean {
		return badges.some((b) => b.badgeId === badgeId);
	}

	// Get badge info
	function getBadgeInfo(badgeId: string) {
		return BADGE_INFO[badgeId] ?? { name: 'UNKNOWN', description: 'Unknown badge' };
	}

	// Get earned timestamp
	function getEarnedAt(badgeId: string): bigint | null {
		const badge = badges.find((b) => b.badgeId === badgeId);
		return badge?.earnedAt ?? null;
	}

	// Format date
	function formatDate(timestamp: bigint): string {
		const date = new Date(Number(timestamp) * 1000);
		return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
	}

	// Badge icons
	const BADGE_ICONS: Record<string, string> = {
		[BADGE_IDS.WEEK_WARRIOR]: '🏅',
		[BADGE_IDS.DEDICATED_OPERATOR]: '🎖️',
		[BADGE_IDS.LEGEND]: '👑',
	};
</script>

{#if badges.length > 0 || showAll}
	<div class="badge-display" class:compact>
		<header class="badge-header">
			<span class="header-title">ACHIEVEMENTS</span>
			<span class="header-count">{badges.length}/{ALL_BADGES.length}</span>
		</header>

		<div class="badge-grid">
			{#each ALL_BADGES as { id, days } (id)}
				{@const earned = isEarned(id)}
				{@const info = getBadgeInfo(id)}
				{@const earnedAt = getEarnedAt(id)}
				{#if earned || showAll}
					<div class="badge-item" class:earned class:locked={!earned}>
						<div class="badge-icon">
							{#if earned}
								{BADGE_ICONS[id] ?? '🏆'}
							{:else}
								🔒
							{/if}
						</div>
						<div class="badge-info">
							<span class="badge-name">{info.name}</span>
							{#if !compact}
								<span class="badge-desc">{info.description}</span>
								{#if earned && earnedAt}
									<span class="badge-date">Earned {formatDate(earnedAt)}</span>
								{:else if !earned}
									<span class="badge-req">{days}-day streak</span>
								{/if}
							{/if}
						</div>
					</div>
				{/if}
			{/each}
		</div>

		{#if badges.length === 0 && !showAll}
			<div class="no-badges">
				<p>No badges earned yet.</p>
				<p class="hint">Build your streak to unlock achievements!</p>
			</div>
		{/if}
	</div>
{/if}

<style>
	.badge-display {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.badge-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.header-title {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.header-count {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		font-family: var(--font-mono);
	}

	.badge-grid {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.compact .badge-grid {
		flex-direction: row;
		flex-wrap: wrap;
		gap: var(--space-1);
	}

	.badge-item {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-2) var(--space-3);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
		transition: all var(--duration-fast) var(--ease-default);
	}

	.compact .badge-item {
		padding: var(--space-1) var(--space-2);
		gap: var(--space-1);
	}

	.badge-item.earned {
		border-color: var(--color-gold);
		background: rgba(255, 215, 0, 0.05);
	}

	.badge-item.locked {
		opacity: 0.5;
	}

	.badge-icon {
		font-size: var(--text-xl);
	}

	.compact .badge-icon {
		font-size: var(--text-lg);
	}

	.badge-info {
		display: flex;
		flex-direction: column;
		gap: var(--space-0-5);
	}

	.badge-name {
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wide);
	}

	.badge-item.earned .badge-name {
		color: var(--color-gold);
	}

	.badge-item.locked .badge-name {
		color: var(--color-text-tertiary);
	}

	.compact .badge-name {
		font-size: var(--text-xs);
	}

	.badge-desc {
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
	}

	.badge-date {
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
	}

	.badge-req {
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
		font-style: italic;
	}

	.no-badges {
		text-align: center;
		padding: var(--space-3);
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
	}

	.no-badges .hint {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		margin-top: var(--space-1);
	}
</style>
