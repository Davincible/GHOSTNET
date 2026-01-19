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
		showScrollHint = true,
		padding = 3,
		children,
		footer
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
				style:max-height={maxHeight}
				bind:this={scrollContainer}
				onscroll={updateScrollState}
			>
				{@render children()}
			</div>
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
		overflow-y: auto;
		overflow-x: hidden;
		scrollbar-width: thin;
		scrollbar-color: var(--color-green-dim) var(--color-bg-secondary);
	}

	.panel-scroll-container::-webkit-scrollbar {
		width: 6px;
	}

	.panel-scroll-container::-webkit-scrollbar-track {
		background: var(--color-bg-secondary);
	}

	.panel-scroll-container::-webkit-scrollbar-thumb {
		background: var(--color-green-dim);
	}

	.panel-scroll-container::-webkit-scrollbar-thumb:hover {
		background: var(--color-green-mid);
	}

	.scroll-hint {
		padding-top: var(--space-2);
		text-align: center;
		animation: pulse 2s ease-in-out infinite;
	}

	@keyframes pulse {
		0%, 100% { opacity: 0.6; }
		50% { opacity: 1; }
	}

	.panel-footer {
		margin-top: var(--space-3);
		padding-top: var(--space-2);
		border-top: 1px solid var(--color-bg-tertiary);
	}
</style>
