<script lang="ts">
	import type { Snippet } from 'svelte';

	type Variant = 'default' | 'success' | 'warning' | 'danger' | 'info' | 'hotkey';

	interface Props {
		variant?: Variant;
		/** Make badge glow */
		glow?: boolean;
		/** Pulsing animation */
		pulse?: boolean;
		/** Compact size (smaller padding) */
		compact?: boolean;
		children: Snippet;
	}

	let {
		variant = 'default',
		glow = false,
		pulse = false,
		compact = false,
		children,
	}: Props = $props();
</script>

<span
	class="badge badge-{variant}"
	class:badge-glow={glow}
	class:badge-pulse={pulse}
	class:badge-compact={compact}
>
	{@render children()}
</span>

<style>
	.badge {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		padding: var(--space-0-5) var(--space-2);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wider);
		text-transform: uppercase;
		border: var(--border-width) solid currentColor;
		white-space: nowrap;
		background: transparent;
	}

	/* Variants - Using the new color system */
	.badge-default {
		color: var(--color-text-secondary);
		border-color: var(--color-border-default);
	}

	.badge-success {
		color: var(--color-accent);
		border-color: var(--color-accent-dim);
		background: rgba(0, 229, 204, 0.08);
	}

	.badge-warning {
		color: var(--color-amber);
		border-color: var(--color-amber-dim);
		background: rgba(255, 176, 0, 0.08);
	}

	.badge-danger {
		color: var(--color-red);
		border-color: var(--color-red-dim);
		background: rgba(255, 51, 102, 0.08);
	}

	.badge-info {
		color: var(--color-cyan);
		border-color: var(--color-cyan-dim);
		background: rgba(0, 229, 255, 0.08);
	}

	.badge-hotkey {
		color: var(--color-text-tertiary);
		border-color: var(--color-border-subtle);
		font-weight: var(--font-normal);
		background: var(--color-bg-tertiary);
	}

	/* Compact size */
	.badge-compact {
		padding: 0 var(--space-1);
		font-size: 0.5625rem; /* ~9px */
	}

	/* Glow effect - subtle, targeted */
	.badge-glow.badge-success {
		box-shadow: var(--shadow-glow-accent);
	}

	.badge-glow.badge-warning {
		box-shadow: var(--shadow-glow-amber);
	}

	.badge-glow.badge-danger {
		box-shadow: var(--shadow-glow-red);
	}

	.badge-glow.badge-info {
		box-shadow: var(--shadow-glow-cyan);
	}

	/* Pulse animation */
	.badge-pulse {
		animation: badge-pulse 2s ease-in-out infinite;
	}

	@keyframes badge-pulse {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.5;
		}
	}
</style>
