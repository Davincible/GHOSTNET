<script lang="ts">
	import type { CrewMember, Level } from '$lib/core/types';
	import { LevelBadge, AmountDisplay, AddressDisplay } from '$lib/ui/data-display';
	import { Badge } from '$lib/ui/primitives';

	interface Props {
		/** Crew member data */
		member: CrewMember;
		/** Whether to show compact view (for lists) */
		compact?: boolean;
		/** Whether to show role badge */
		showRole?: boolean;
		/** Last seen time for offline members (formatted string) */
		lastSeen?: string;
	}

	let { member, compact = false, showRole = false, lastSeen }: Props = $props();

	// Format streak display
	let streakDisplay = $derived.by(() => {
		if (member.ghostStreak <= 0) return null;
		const fires = Math.min(member.ghostStreak, 5);
		return `${''.repeat(fires)}${member.ghostStreak}`;
	});
</script>

<div class="member-row" class:member-row-compact={compact} class:member-offline={!member.isOnline}>
	<!-- Online indicator -->
	<span class="online-indicator" class:online={member.isOnline} aria-hidden="true"></span>

	<!-- Address / Name -->
	<span class="member-identity">
		{#if member.ensName}
			<span class="member-ens">{member.ensName}</span>
		{:else}
			<span class="member-address">{member.address.slice(0, 6)}</span>
		{/if}
		{#if member.isYou}
			<span class="you-badge">(you)</span>
		{/if}
	</span>

	<!-- Role badge (optional) -->
	{#if showRole && member.role !== 'member'}
		<Badge variant={member.role === 'leader' ? 'warning' : 'default'} compact>
			{member.role.toUpperCase()}
		</Badge>
	{/if}

	<!-- Level (if jacked in) -->
	{#if member.level}
		<LevelBadge level={member.level} compact />
	{:else}
		<span class="no-level">-</span>
	{/if}

	<!-- Staked amount -->
	<span class="member-staked">
		{#if member.stakedAmount > 0n}
			<AmountDisplay amount={member.stakedAmount} format="compact" />
		{:else}
			<span class="no-stake">-</span>
		{/if}
	</span>

	<!-- Streak or Last Seen -->
	{#if member.isOnline && streakDisplay}
		<span class="member-streak">{streakDisplay}</span>
	{:else if !member.isOnline && lastSeen}
		<span class="last-seen">Last: {lastSeen}</span>
	{:else}
		<span class="no-streak">-</span>
	{/if}
</div>

<style>
	.member-row {
		display: grid;
		grid-template-columns: auto 1fr auto auto auto auto;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2) 0;
		font-size: var(--text-sm);
		font-family: var(--font-mono);
		border-bottom: 1px solid var(--color-border-subtle);
	}

	.member-row:last-child {
		border-bottom: none;
	}

	.member-row-compact {
		padding: var(--space-1) 0;
		font-size: var(--text-xs);
	}

	.member-offline {
		opacity: 0.6;
	}

	/* Online indicator */
	.online-indicator {
		width: 6px;
		height: 6px;
		border-radius: 50%;
		background: var(--color-text-tertiary);
		flex-shrink: 0;
	}

	.online-indicator.online {
		background: var(--color-profit);
		box-shadow: 0 0 4px var(--color-profit);
	}

	/* Identity */
	.member-identity {
		display: flex;
		align-items: center;
		gap: var(--space-1);
		min-width: 0;
		overflow: hidden;
	}

	.member-ens {
		color: var(--color-cyan);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.member-address {
		color: var(--color-text-secondary);
		white-space: nowrap;
	}

	.you-badge {
		color: var(--color-accent);
		font-size: var(--text-xs);
	}

	/* Level & Staked */
	.no-level,
	.no-stake,
	.no-streak {
		color: var(--color-text-tertiary);
	}

	.member-staked {
		text-align: right;
		white-space: nowrap;
	}

	/* Streak */
	.member-streak {
		color: var(--color-amber);
		white-space: nowrap;
	}

	.last-seen {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		white-space: nowrap;
	}
</style>
