<script lang="ts">
	import { Panel } from '$lib/ui/terminal';
	import { Badge } from '$lib/ui/primitives';
	import { Row } from '$lib/ui/layout';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import FeedItem from './FeedItem.svelte';

	interface Props {
		/** Number of events to show when collapsed */
		collapsedCount?: number;
		/** Number of events to show when expanded */
		expandedCount?: number;
		/** Maximum height when collapsed */
		collapsedHeight?: string;
		/** Maximum height when expanded */
		expandedHeight?: string;
	}

	let {
		collapsedCount = 6,
		expandedCount = 20,
		collapsedHeight = '145px',
		expandedHeight = '500px',
	}: Props = $props();

	const provider = getProvider();

	// Expansion state
	let expanded = $state(false);

	// Track newly added events for animation
	let lastEventId = $state<string | null>(null);

	$effect(() => {
		if (provider.feedEvents.length > 0) {
			lastEventId = provider.feedEvents[0].id;
		}
	});

	// Always show all events - height controls viewport, not item count
	let visibleEvents = $derived(provider.feedEvents);
	let hasMore = $derived(provider.feedEvents.length > collapsedCount);
	let currentHeight = $derived(expanded ? expandedHeight : collapsedHeight);

	function collapse() {
		expanded = false;
	}
</script>

<!-- Backdrop: click to collapse when expanded -->
{#if expanded}
	<button class="feed-backdrop" onclick={collapse} aria-label="Collapse feed"></button>
{/if}

<div class="feed-panel-wrapper" class:expanded>
<Panel title="LIVE FEED" scrollable maxHeight={currentHeight} minHeight={collapsedHeight}>
	{#snippet footer()}
		<Row justify="between" align="center">
			<Row gap={2} align="center">
				<span class="streaming-dot" aria-hidden="true"></span>
				<span class="streaming-text">STREAMING</span>
				{#if provider.connectionStatus === 'connected'}
					<Badge variant="success" compact>LIVE</Badge>
				{:else}
					<Badge variant="warning" compact pulse>BUFFERING</Badge>
				{/if}
			</Row>
			{#if hasMore}
				<button class="expand-btn" onclick={() => (expanded = !expanded)} aria-expanded={expanded}>
					{expanded ? '▲ LESS' : '▼ MORE'}
				</button>
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
</div>

<style>
	/* ═══════════════════════════════════════════════════════════════
	   EXPAND BACKDROP — click-away-to-close
	   ═══════════════════════════════════════════════════════════════ */

	.feed-backdrop {
		position: fixed;
		inset: 0;
		z-index: var(--z-overlay, 40);
		background: rgba(0, 0, 0, 0.5);
		border: none;
		cursor: pointer;
		backdrop-filter: blur(2px);
	}

	.feed-panel-wrapper {
		position: relative;
	}

	.feed-panel-wrapper.expanded {
		position: relative;
		z-index: calc(var(--z-overlay, 40) + 1);
	}

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

	.expand-btn {
		padding: var(--space-1) var(--space-2);
		background: transparent;
		border: 1px solid var(--color-border-subtle);
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.expand-btn:hover {
		color: var(--color-accent);
		border-color: var(--color-accent-dim);
		background: var(--color-accent-glow);
	}
</style>
