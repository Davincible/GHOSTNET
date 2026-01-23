<script lang="ts">
	/**
	 * Large depth/multiplier display with themed styling.
	 * Shows current penetration depth with glow effects.
	 */

	import { formatDepth, getStatusText } from '../../../theme.svelte';

	interface Props {
		/** Current depth value */
		depth: number;
		/** Player's target depth */
		target?: number | null;
		/** Whether game has crashed */
		crashed?: boolean;
		/** Current phase */
		phase?: string | null;
		/** Show status text below */
		showStatus?: boolean;
	}

	let { depth, target = null, crashed = false, phase = null, showStatus = true }: Props = $props();

	// Determine color based on state
	let colorClass = $derived.by(() => {
		if (crashed) return 'crashed';
		if (!target) {
			// Default colors based on absolute value
			if (depth < 2) return 'depth-low';
			if (depth < 5) return 'depth-mid';
			if (depth < 10) return 'depth-high';
			return 'depth-extreme';
		}
		// Colors relative to player's target
		if (depth >= target) return 'depth-safe';
		if (depth >= target * 0.8) return 'depth-danger';
		return 'depth-active';
	});

	// Status text
	let status = $derived(showStatus ? getStatusText(phase ?? '', depth, target, crashed) : null);

	// Scale effect increases with depth
	let scale = $derived(Math.min(1 + (depth - 1) * 0.015, 1.3));
</script>

<div class="depth-display {colorClass}" class:crashed style:--scale={scale}>
	{#if crashed}
		<div class="crash-label">TRACED @</div>
	{/if}

	<div class="depth-value">
		{formatDepth(depth)}
	</div>

	{#if status}
		<div class="depth-status">{status}</div>
	{/if}

	{#if target && !crashed}
		<div class="target-info">
			<span class="target-label">EXIT:</span>
			<span class="target-value">{formatDepth(target)}</span>
		</div>
	{/if}
</div>

<style>
	.depth-display {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: var(--space-4);
		text-align: center;
	}

	.crash-label {
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-widest);
		text-transform: uppercase;
		color: var(--color-red);
		margin-bottom: var(--space-1);
		animation: flash 0.5s ease-in-out 3;
	}

	.depth-value {
		font-family: var(--font-mono);
		font-size: clamp(2.5rem, 8vw, 5rem);
		font-weight: var(--font-bold);
		font-variant-numeric: tabular-nums;
		line-height: 1;
		transform: scale(var(--scale));
		transition:
			transform 0.1s ease-out,
			color 0.3s ease;
	}

	.depth-status {
		margin-top: var(--space-2);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wider);
		opacity: 0.8;
	}

	.target-info {
		display: flex;
		gap: var(--space-2);
		margin-top: var(--space-3);
		padding: var(--space-1) var(--space-3);
		background: var(--color-bg-tertiary);
		border: var(--border-width) dashed var(--color-border-default);
	}

	.target-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.target-value {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		color: var(--color-cyan);
	}

	/* Color states */
	.depth-low .depth-value {
		color: var(--color-accent);
		text-shadow: 0 0 20px var(--color-accent-glow);
	}

	.depth-mid .depth-value {
		color: var(--color-cyan);
		text-shadow: 0 0 25px var(--color-cyan-glow);
	}

	.depth-high .depth-value {
		color: var(--color-amber);
		text-shadow: 0 0 30px var(--color-amber-glow);
	}

	.depth-extreme .depth-value {
		color: var(--color-red);
		text-shadow: 0 0 40px var(--color-red-glow);
		animation: pulse-extreme 0.5s ease-in-out infinite;
	}

	/* Target-relative colors */
	.depth-active .depth-value {
		color: var(--color-accent);
		text-shadow: 0 0 25px var(--color-accent-glow);
	}

	.depth-danger .depth-value {
		color: var(--color-amber);
		text-shadow: 0 0 30px var(--color-amber-glow);
		animation: pulse-danger 0.8s ease-in-out infinite;
	}

	.depth-safe .depth-value {
		color: var(--color-accent);
		text-shadow: 0 0 40px var(--color-accent-glow);
	}

	.depth-safe .depth-status {
		color: var(--color-accent);
	}

	/* Crashed state */
	.crashed .depth-value {
		color: var(--color-red);
		text-shadow: 0 0 50px var(--color-red);
		animation: shake 0.5s ease-in-out;
	}

	.crashed .depth-status {
		color: var(--color-red);
	}

	@keyframes pulse-extreme {
		0%,
		100% {
			transform: scale(var(--scale));
		}
		50% {
			transform: scale(calc(var(--scale) * 1.05));
		}
	}

	@keyframes pulse-danger {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.85;
		}
	}

	@keyframes shake {
		0%,
		100% {
			transform: translateX(0);
		}
		10%,
		30%,
		50%,
		70%,
		90% {
			transform: translateX(-4px);
		}
		20%,
		40%,
		60%,
		80% {
			transform: translateX(4px);
		}
	}

	@keyframes flash {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.3;
		}
	}
</style>
