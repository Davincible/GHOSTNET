<script lang="ts">
	import type { Snippet } from 'svelte';

	type Variant = 'single' | 'double' | 'rounded';
	type BorderColor = 'default' | 'bright' | 'dim' | 'cyan' | 'amber' | 'red';

	interface Props {
		/** Box title (displayed in top border) */
		title?: string;
		/** Border style variant */
		variant?: Variant;
		/** Border color */
		borderColor?: BorderColor;
		/** Add glow effect to border */
		glow?: boolean;
		/** Padding inside the box */
		padding?: 0 | 1 | 2 | 3 | 4;
		children: Snippet;
	}

	let {
		title,
		variant = 'single',
		borderColor = 'default',
		glow = false,
		padding = 3,
		children,
	}: Props = $props();

	// Box drawing characters based on variant
	const chars = {
		single: {
			tl: '┌',
			tr: '┐',
			bl: '└',
			br: '┘',
			h: '─',
			v: '│',
			tDown: '┬',
			tUp: '┴',
		},
		double: {
			tl: '╔',
			tr: '╗',
			bl: '╚',
			br: '╝',
			h: '═',
			v: '║',
			tDown: '╦',
			tUp: '╩',
		},
		rounded: {
			tl: '╭',
			tr: '╮',
			bl: '╰',
			br: '╯',
			h: '─',
			v: '│',
			tDown: '┬',
			tUp: '┴',
		},
	};

	let c = $derived(chars[variant]);
</script>

<div class="box box-border-{borderColor}" class:box-glow={glow} style:--box-padding={padding}>
	<!-- Top border -->
	<div class="box-border box-border-top">
		<span class="box-corner">{c.tl}</span>
		{#if title}
			<span class="box-h">{c.h}</span>
			<span class="box-title">{title}</span>
		{/if}
		<span class="box-h box-h-fill">{c.h}</span>
		<span class="box-corner">{c.tr}</span>
	</div>

	<!-- Content with side borders -->
	<div class="box-content-wrapper">
		<span class="box-v">{c.v}</span>
		<div class="box-content">
			{@render children()}
		</div>
		<span class="box-v">{c.v}</span>
	</div>

	<!-- Bottom border -->
	<div class="box-border box-border-bottom">
		<span class="box-corner">{c.bl}</span>
		<span class="box-h box-h-fill">{c.h}</span>
		<span class="box-corner">{c.br}</span>
	</div>
</div>

<style>
	.box {
		display: flex;
		flex-direction: column;
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		line-height: 1;
		width: 100%;
		background: var(--color-bg-secondary);
	}

	/* Border colors - more subtle, barely-there */
	.box-border-default {
		color: var(--color-border-default);
	}

	.box-border-bright {
		color: var(--color-accent-dim);
	}

	.box-border-dim {
		color: var(--color-border-subtle);
	}

	.box-border-cyan {
		color: var(--color-cyan-dim);
	}

	.box-border-amber {
		color: var(--color-amber-dim);
	}

	.box-border-red {
		color: var(--color-red-dim);
	}

	/* Glow effect - more subtle */
	.box-glow {
		text-shadow: 0 0 4px currentColor;
	}

	/* Borders */
	.box-border {
		display: flex;
		white-space: nowrap;
	}

	.box-corner {
		flex-shrink: 0;
	}

	.box-h {
		flex-shrink: 0;
	}

	.box-h-fill {
		flex-grow: 1;
		overflow: hidden;
		/* Use repeating background for horizontal line */
		background: linear-gradient(to right, currentColor 0, currentColor 0.6em, transparent 0.6em);
		background-size: 0.6em 1px;
		background-repeat: repeat-x;
		background-position: 0 50%;
		color: transparent;
	}

	/* Fallback for the fill - use :before with repeating chars */
	.box-h-fill::before {
		content: '────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────';
		color: inherit;
		display: block;
		overflow: hidden;
	}

	/* Reset the color inheritance for the fill */
	.box-border-default .box-h-fill::before,
	.box-border-bright .box-h-fill::before,
	.box-border-dim .box-h-fill::before,
	.box-border-cyan .box-h-fill::before,
	.box-border-amber .box-h-fill::before,
	.box-border-red .box-h-fill::before {
		color: currentColor;
	}

	.box-title {
		flex-shrink: 0;
		padding: 0 0.75em;
		color: var(--color-text-secondary);
		font-weight: var(--font-medium);
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider);
		font-size: var(--text-xs);
	}

	.box-v {
		flex-shrink: 0;
	}

	/* Content wrapper */
	.box-content-wrapper {
		display: flex;
		min-height: 0;
		height: auto;
	}

	.box-content {
		flex: 1 1 auto;
		min-width: 0;
		padding: calc(var(--box-padding, 3) * var(--space-1));
		color: var(--color-text-primary);
		line-height: var(--leading-normal);
		font-size: var(--text-base);
	}
</style>
