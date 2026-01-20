<script lang="ts">
	type Variant = 'default' | 'danger' | 'warning' | 'success' | 'cyan';

	interface Props {
		/** Current value (0-100) */
		value: number;
		/** Visual variant */
		variant?: Variant;
		/** Show percentage text */
		showPercent?: boolean;
		/** Number of characters in the bar */
		width?: number;
		/** Label text */
		label?: string;
		/** Animate changes */
		animated?: boolean;
	}

	let {
		value,
		variant = 'default',
		showPercent = false,
		width = 20,
		label,
		animated = false
	}: Props = $props();

	// Clamp value between 0-100
	let clampedValue = $derived(Math.max(0, Math.min(100, value)));

	// Calculate filled/empty characters
	let filledCount = $derived(Math.round((clampedValue / 100) * width));
	let emptyCount = $derived(width - filledCount);

	// Generate the bar string
	let filledChars = $derived('█'.repeat(filledCount));
	let emptyChars = $derived('░'.repeat(emptyCount));
</script>

<div
	class="progress"
	class:progress-animated={animated}
	role="progressbar"
	aria-valuenow={clampedValue}
	aria-valuemin={0}
	aria-valuemax={100}
	aria-label={label ?? `Progress: ${Math.round(clampedValue)}%`}
>
	{#if label}
		<span class="progress-label">{label}</span>
	{/if}
	<span class="progress-bar progress-{variant}">
		<span class="progress-filled">{filledChars}</span><span class="progress-empty">{emptyChars}</span>
	</span>
	{#if showPercent}
		<span class="progress-percent">{Math.round(clampedValue)}%</span>
	{/if}
</div>

<style>
	.progress {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		line-height: 1;
	}

	.progress-label {
		color: var(--color-text-tertiary);
		white-space: nowrap;
		text-transform: uppercase;
		letter-spacing: var(--tracking-wide);
		font-size: var(--text-xs);
	}

	.progress-bar {
		white-space: pre;
		letter-spacing: -0.05em;
	}

	.progress-percent {
		color: var(--color-text-secondary);
		min-width: 3.5ch;
		text-align: right;
		font-size: var(--text-xs);
	}

	/* Variants - Using new accent color */
	.progress-default .progress-filled {
		color: var(--color-accent);
	}

	.progress-default .progress-empty {
		color: var(--color-border-strong);
		opacity: 0.5;
	}

	.progress-danger .progress-filled {
		color: var(--color-red);
	}

	.progress-danger .progress-empty {
		color: var(--color-red-dim);
		opacity: 0.3;
	}

	.progress-warning .progress-filled {
		color: var(--color-amber);
	}

	.progress-warning .progress-empty {
		color: var(--color-amber-dim);
		opacity: 0.3;
	}

	.progress-success .progress-filled {
		color: var(--color-profit);
	}

	.progress-success .progress-empty {
		color: var(--color-profit-dim);
		opacity: 0.3;
	}

	.progress-cyan .progress-filled {
		color: var(--color-cyan);
	}

	.progress-cyan .progress-empty {
		color: var(--color-cyan-dim);
		opacity: 0.3;
	}

	/* Animation - subtle glow */
	.progress-animated .progress-filled {
		animation: glow-pulse 2s ease-in-out infinite;
	}

	@keyframes glow-pulse {
		0%, 100% {
			text-shadow: none;
		}
		50% {
			text-shadow: 0 0 4px currentColor;
		}
	}
</style>
