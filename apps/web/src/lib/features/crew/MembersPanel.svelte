<script lang="ts">
	import type { CrewMember } from '$lib/core/types';
	import { Panel } from '$lib/ui/terminal';
	import { Button } from '$lib/ui/primitives';
	import MemberRow from './MemberRow.svelte';

	interface Props {
		/** All crew members */
		members: CrewMember[];
		/** Maximum number of online members to show before collapse */
		maxOnlineVisible?: number;
		/** Maximum number of offline members to show before collapse */
		maxOfflineVisible?: number;
		/** Callback when "View All" is clicked */
		onViewAll?: () => void;
	}

	let { members, maxOnlineVisible = 5, maxOfflineVisible = 3, onViewAll }: Props = $props();

	// Separate online and offline members
	let onlineMembers = $derived(members.filter((m) => m.isOnline));
	let offlineMembers = $derived(members.filter((m) => !m.isOnline));

	// Visible members (limited)
	let visibleOnline = $derived(onlineMembers.slice(0, maxOnlineVisible));
	let visibleOffline = $derived(offlineMembers.slice(0, maxOfflineVisible));

	// Counts
	let hasMoreOnline = $derived(onlineMembers.length > maxOnlineVisible);
	let hasMoreOffline = $derived(offlineMembers.length > maxOfflineVisible);

	// Format "last seen" time
	function formatLastSeen(member: CrewMember): string {
		// For mock data, we'll use joinedAt as a proxy for last activity
		const lastActive = member.joinedAt + Math.random() * 86400000; // Random within last 24h
		const hoursAgo = Math.floor((Date.now() - lastActive) / 3600000);

		if (hoursAgo < 1) return '<1h';
		if (hoursAgo < 24) return `${hoursAgo}h`;
		const daysAgo = Math.floor(hoursAgo / 24);
		return `${daysAgo}d`;
	}
</script>

<Panel title="CREW MEMBERS" maxHeight="400px" scrollable>
	<div class="members-container">
		<!-- Online Section -->
		<div class="members-section">
			<h3 class="section-header">
				MEMBERS ONLINE
				<span class="section-count">({onlineMembers.length})</span>
			</h3>

			{#if visibleOnline.length > 0}
				<div class="members-list">
					{#each visibleOnline as member (member.address)}
						<MemberRow {member} showRole />
					{/each}
				</div>
				{#if hasMoreOnline}
					<button class="view-more-btn" onclick={onViewAll}>
						[VIEW ALL {onlineMembers.length}]
					</button>
				{/if}
			{:else}
				<p class="no-members">No members online</p>
			{/if}
		</div>

		<!-- Divider -->
		<div class="section-divider" aria-hidden="true"></div>

		<!-- Offline Section -->
		<div class="members-section">
			<h3 class="section-header">
				OFFLINE
				<span class="section-count">({offlineMembers.length})</span>
			</h3>

			{#if visibleOffline.length > 0}
				<div class="members-list">
					{#each visibleOffline as member (member.address)}
						<MemberRow {member} lastSeen={formatLastSeen(member)} />
					{/each}
				</div>
				{#if hasMoreOffline}
					<button class="view-more-btn" onclick={onViewAll}> [VIEW ALL OFFLINE] </button>
				{/if}
			{:else}
				<p class="no-members">All members online</p>
			{/if}
		</div>
	</div>
</Panel>

<style>
	.members-container {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.members-section {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.section-header {
		font-size: var(--text-xs);
		font-weight: var(--font-medium);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-widest);
		text-transform: uppercase;
		margin: 0;
	}

	.section-count {
		color: var(--color-accent);
	}

	.members-list {
		display: flex;
		flex-direction: column;
	}

	.section-divider {
		height: 1px;
		background: var(--color-border-subtle);
	}

	.view-more-btn {
		background: none;
		border: none;
		color: var(--color-cyan);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		cursor: pointer;
		padding: var(--space-2) 0;
		text-align: left;
		transition: color var(--duration-fast) var(--ease-default);
	}

	.view-more-btn:hover {
		color: var(--color-cyan);
		text-shadow: 0 0 4px var(--color-cyan-glow);
	}

	.no-members {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
		padding: var(--space-2) 0;
	}
</style>
