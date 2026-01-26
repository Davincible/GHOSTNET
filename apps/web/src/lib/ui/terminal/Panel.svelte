<script lang="ts">
	import type { Snippet } from 'svelte';
	import Box from './Box.svelte';

	type Variant = 'single' | 'double' | 'rounded';
	type BorderColor = 'default' | 'bright' | 'dim' | 'cyan' | 'amber' | 'red';

	interface Props {
		/** Panel title */
		title?: string;
		/** Border style variant */
		variant?: Variant;
		/** Border color */
		borderColor?: BorderColor;
		/** Add glow effect to border */
		glow?: boolean;
		/** Enable scrolling for content */
		scrollable?: boolean;
		/** Max height when scrollable (CSS value) */
		maxHeight?: string;
		/** Min height when scrollable (CSS value) - use same as maxHeight for stable layout */
		minHeight?: string;
		/** Show scroll indicator */
		showScrollHint?: boolean;
		/** Padding inside the box */
		padding?: 0 | 1 | 2 | 3 | 4;
		children: Snippet;
		/** Optional footer snippet */
		footer?: Snippet;
	}

	let {
		title,
		variant = 'single',
		borderColor = 'default',
		glow = false,
		scrollable = false,
		maxHeight = '400px',
		minHeight,
		showScrollHint = true,
		padding = 3,
		children,
		footer,
	}: Props = $props();

	let scrollContainer = $state<HTMLDivElement | null>(null);
	let canScrollDown = $state(false);
	let canScrollUp = $state(false);

	function updateScrollState() {
		if (!scrollContainer) return;
		const { scrollTop, scrollHeight, clientHeight } = scrollContainer;
		canScrollUp = scrollTop > 0;
		canScrollDown = scrollTop + clientHeight < scrollHeight - 1;
	}

	$effect(() => {
		if (scrollable && scrollContainer) {
			updateScrollState();
			// Observe for content changes
			const observer = new ResizeObserver(updateScrollState);
			observer.observe(scrollContainer);
			return () => observer.disconnect();
		}
	});
</script>

<div class="panel" class:panel-scrollable={scrollable}>
	<Box {title} {variant} {borderColor} {glow} {padding}>
		{#if scrollable}
			<div
				class="panel-scroll-container"
				style:--panel-height={maxHeight}
				bind:this={scrollContainer}
				onscroll={updateScrollState}
			>
				{@render children()}
			</div>
			{#if showScrollHint && canScrollUp}
				<div class="scroll-hint scroll-hint-top">
					<span class="text-green-dim text-xs">▲ SCROLL UP</span>
				</div>
			{/if}
			{#if showScrollHint && canScrollDown}
				<div class="scroll-hint scroll-hint-bottom">
					<span class="text-green-dim text-xs">▼ SCROLL FOR MORE</span>
				</div>
			{/if}
		{:else}
			{@render children()}
		{/if}
		{#if footer}
			<div class="panel-footer">
				{@render footer()}
			</div>
		{/if}
	</Box>
</div>

<style>
	.panel {
		width: 100%;
	}

	.panel-scroll-container {
		height: var(--panel-height);
		min-height: var(--panel-height);
		max-height: var(--panel-height);
		overflow-y: auto;
		overflow-x: hidden;
		scrollbar-width: thin;
		scrollbar-color: var(--color-border-strong) var(--color-bg-tertiary);
		flex-shrink: 0;
	}

	.panel-scroll-container::-webkit-scrollbar {
		width: 4px;
	}

	.panel-scroll-container::-webkit-scrollbar-track {
		background: var(--color-bg-tertiary);
	}

	.panel-scroll-container::-webkit-scrollbar-thumb {
		background: var(--color-border-strong);
	}

	.panel-scroll-container::-webkit-scrollbar-thumb:hover {
		background: var(--color-accent-dim);
	}

	.scroll-hint {
		padding-top: var(--space-2);
		text-align: center;
		animation: pulse 2s ease-in-out infinite;
	}

	:global(.scroll-hint .text-green-dim) {
		color: var(--color-text-tertiary);
	}

	@keyframes pulse {
		0%,
		100% {
			opacity: 0.4;
		}
		50% {
			opacity: 0.8;
		}
	}

	.panel-footer {
		margin-top: var(--space-3);
		padding-top: var(--space-2);
		border-top: 1px solid var(--color-border-subtle);
	}
</style>
