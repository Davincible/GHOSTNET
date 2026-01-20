<script lang="ts">
	import type { CrewActivity } from '$lib/core/types';
	import { Panel } from '$lib/ui/terminal';

	interface Props {
		/** Activity events to display */
		activity: CrewActivity[];
		/** Maximum number of events to show */
		maxItems?: number;
	}

	let { activity, maxItems = 15 }: Props = $props();

	// Get visible activities
	let visibleActivity = $derived(activity.slice(0, maxItems));

	// Format timestamp for display
	function formatTime(timestamp: number): string {
		const now = Date.now();
		const diff = now - timestamp;
		const seconds = Math.floor(diff / 1000);
		const minutes = Math.floor(seconds / 60);
		const hours = Math.floor(minutes / 60);

		if (seconds < 60) return 'just now';
		if (minutes < 60) return `${minutes}m ago`;
		if (hours < 24) return `${hours}h ago`;
		return `${Math.floor(hours / 24)}d ago`;
	}

	// Get activity icon/prefix
	function getActivityPrefix(type: CrewActivity['type']): string {
		switch (type) {
			case 'member_joined':
				return '+';
			case 'member_left':
			case 'member_kicked':
				return '-';
			case 'bonus_activated':
				return '*';
			case 'bonus_deactivated':
				return 'x';
			case 'member_survived':
				return '>';
			case 'member_traced':
				return '!';
			case 'member_extracted':
				return '$';
			case 'raid_started':
			case 'raid_completed':
				return '#';
			default:
				return '>';
		}
	}

	// Get activity color class
	function getActivityColor(type: CrewActivity['type']): string {
		switch (type) {
			case 'member_joined':
			case 'member_survived':
			case 'bonus_activated':
				return 'activity-profit';
			case 'member_left':
			case 'member_kicked':
			case 'member_traced':
			case 'bonus_deactivated':
				return 'activity-danger';
			case 'member_extracted':
			case 'raid_completed':
				return 'activity-success';
			case 'raid_started':
				return 'activity-warning';
			default:
				return '';
		}
	}
</script>

<Panel title="CREW ACTIVITY" maxHeight="250px" scrollable>
	<div class="activity-feed" role="log" aria-live="polite" aria-label="Crew activity feed">
		{#each visibleActivity as event (event.id)}
			<div class="activity-item {getActivityColor(event.type)}">
				<span class="activity-prefix">{getActivityPrefix(event.type)}</span>
				<span class="activity-message">{event.message}</span>
				<span class="activity-time">{formatTime(event.timestamp)}</span>
			</div>
		{/each}
		{#if visibleActivity.length === 0}
			<p class="no-activity">No recent activity</p>
		{/if}
	</div>
</Panel>

<style>
	.activity-feed {
		display: flex;
		flex-direction: column;
	}

	.activity-item {
		display: flex;
		align-items: flex-start;
		gap: var(--space-2);
		padding: var(--space-1) 0;
		font-size: var(--text-sm);
		font-family: var(--font-mono);
		border-bottom: 1px solid var(--color-border-subtle);
	}

	.activity-item:last-child {
		border-bottom: none;
	}

	.activity-prefix {
		color: var(--color-text-tertiary);
		flex-shrink: 0;
		width: 1ch;
		text-align: center;
	}

	.activity-message {
		flex: 1;
		color: var(--color-text-secondary);
		word-break: break-word;
	}

	.activity-time {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		flex-shrink: 0;
	}

	/* Color variants */
	.activity-profit .activity-prefix,
	.activity-profit .activity-message {
		color: var(--color-profit);
	}

	.activity-danger .activity-prefix,
	.activity-danger .activity-message {
		color: var(--color-red);
	}

	.activity-success .activity-prefix,
	.activity-success .activity-message {
		color: var(--color-cyan);
	}

	.activity-warning .activity-prefix,
	.activity-warning .activity-message {
		color: var(--color-amber);
	}

	.no-activity {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
		text-align: center;
		padding: var(--space-4);
	}
</style>
