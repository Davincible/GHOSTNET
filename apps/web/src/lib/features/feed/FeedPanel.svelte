<script lang="ts">
	import { Panel } from '$lib/ui/terminal';
	import { Badge } from '$lib/ui/primitives';
	import { Row } from '$lib/ui/layout';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import FeedItem from './FeedItem.svelte';

	interface Props {
		/** Maximum height for the feed panel */
		maxHeight?: string;
		/** Maximum number of events to display */
		maxEvents?: number;
	}

	let { maxHeight = '350px', maxEvents = 15 }: Props = $props();

	const provider = getProvider();

	// Track newly added events for animation
	let lastEventId = $state<string | null>(null);

	$effect(() => {
		if (provider.feedEvents.length > 0) {
			lastEventId = provider.feedEvents[0].id;
		}
	});

	// Get visible events
	let visibleEvents = $derived(provider.feedEvents.slice(0, maxEvents));
</script>

<Panel title="LIVE FEED" scrollable {maxHeight} minHeight={maxHeight}>
	{#snippet footer()}
		<Row justify="between" align="center">
			<Row gap={2} align="center">
				<span class="streaming-dot" aria-hidden="true"></span>
				<span class="streaming-text">STREAMING</span>
			</Row>
			{#if provider.connectionStatus === 'connected'}
				<Badge variant="success" compact>LIVE</Badge>
			{:else}
				<Badge variant="warning" compact pulse>BUFFERING</Badge>
			{/if}
		</Row>
	{/snippet}

	<div class="feed-list" role="log" aria-live="polite" aria-label="Live network events">
		{#each visibleEvents as event (event.id)}
			<FeedItem
				{event}
				currentUserAddress={provider.currentUser?.address}
				isNew={event.id === lastEventId}
			/>
		{/each}
		{#if visibleEvents.length === 0}
			<p class="feed-empty">Waiting for network events...</p>
		{/if}
	</div>
</Panel>

<style>
	.feed-list {
		display: flex;
		flex-direction: column;
		min-height: 100%;
	}

	.feed-empty {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
		text-align: center;
		padding: var(--space-4);
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.streaming-dot {
		width: 5px;
		height: 5px;
		border-radius: 50%;
		background-color: var(--color-accent);
		animation: pulse-glow 2s ease-in-out infinite;
	}

	.streaming-text {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	@keyframes pulse-glow {
		0%,
		100% {
			opacity: 1;
			box-shadow: 0 0 4px var(--color-accent-glow);
		}
		50% {
			opacity: 0.5;
			box-shadow: 0 0 8px var(--color-accent-glow);
		}
	}
</style>
