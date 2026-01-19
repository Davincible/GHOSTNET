<script lang="ts">
	import type { Snippet } from 'svelte';

	type Variant = 'default' | 'success' | 'warning' | 'danger' | 'info' | 'hotkey';

	interface Props {
		variant?: Variant;
		/** Make badge glow */
		glow?: boolean;
		/** Pulsing animation */
		pulse?: boolean;
		children: Snippet;
	}

	let {
		variant = 'default',
		glow = false,
		pulse = false,
		children
	}: Props = $props();
</script>

<span
	class="badge badge-{variant}"
	class:badge-glow={glow}
	class:badge-pulse={pulse}
>
	{@render children()}
</span>

<style>
	.badge {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		padding: var(--space-1) var(--space-2);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wide);
		text-transform: uppercase;
		border: var(--border-width) solid currentColor;
		white-space: nowrap;
	}

	/* Variants */
	.badge-default {
		color: var(--color-green-mid);
		border-color: var(--color-green-dim);
	}

	.badge-success {
		color: var(--color-profit);
		border-color: var(--color-profit);
	}

	.badge-warning {
		color: var(--color-amber);
		border-color: var(--color-amber);
	}

	.badge-danger {
		color: var(--color-red);
		border-color: var(--color-red);
	}

	.badge-info {
		color: var(--color-cyan);
		border-color: var(--color-cyan);
	}

	.badge-hotkey {
		color: var(--color-green-dim);
		border-color: var(--color-bg-tertiary);
		font-weight: var(--font-normal);
	}

	/* Glow effect */
	.badge-glow {
		box-shadow: 0 0 8px currentColor;
	}

	/* Pulse animation */
	.badge-pulse {
		animation: badge-pulse 2s ease-in-out infinite;
	}

	@keyframes badge-pulse {
		0%, 100% {
			opacity: 1;
		}
		50% {
			opacity: 0.6;
		}
	}
</style>
