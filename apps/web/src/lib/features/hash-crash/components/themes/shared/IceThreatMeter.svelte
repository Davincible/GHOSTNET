<script lang="ts">
	/**
	 * ICE Threat Meter - shows danger level during extraction.
	 * Fills based on current depth relative to typical crash points.
	 */

	import { getIceThreatMessage, getIceThreatColor } from '../../../messages';

	interface Props {
		/** Current threat level (0-100) */
		level: number;
		/** Optional label override */
		label?: string;
		/** Whether to show the percentage */
		showPercent?: boolean;
		/** Whether the game is active (animates) */
		active?: boolean;
	}

	let { level, label, showPercent = true, active = true }: Props = $props();

	// Clamp level
	let clampedLevel = $derived(Math.max(0, Math.min(100, level)));

	// Get threat status
	let threatMessage = $derived(label || getIceThreatMessage(clampedLevel));
	let threatColor = $derived(getIceThreatColor(clampedLevel));

	// Determine if critical (for animation)
	let isCritical = $derived(clampedLevel >= 80);
</script>

<div class="ice-threat-meter" class:active class:critical={isCritical}>
	<div class="meter-header">
		<span class="meter-label">ICE THREAT</span>
		<span class="meter-status {threatColor}">{threatMessage}</span>
	</div>

	<div class="meter-bar">
		<div class="meter-fill {threatColor}" style:width="{clampedLevel}%">
			{#if clampedLevel > 5}
				<span class="fill-glow"></span>
			{/if}
		</div>
		<div class="meter-ticks">
			{#each [25, 50, 75] as tick (tick)}
				<div class="tick" style:left="{tick}%"></div>
			{/each}
		</div>
	</div>

	{#if showPercent}
		<div class="meter-percent {threatColor}">{clampedLevel.toFixed(0)}%</div>
	{/if}
</div>

<style>
	.ice-threat-meter {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		font-family: var(--font-mono);
	}

	.meter-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.meter-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.meter-status {
		font-size: var(--text-xs);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wide);
	}

	/* Color variants for status */
	.meter-status.accent {
		color: var(--color-accent);
	}
	.meter-status.cyan {
		color: var(--color-cyan);
	}
	.meter-status.amber {
		color: var(--color-amber);
	}
	.meter-status.red {
		color: var(--color-red);
	}

	/* Bar container */
	.meter-bar {
		position: relative;
		height: 8px;
		background: var(--color-bg-tertiary);
		border: var(--border-width) solid var(--color-border-subtle);
	}

	/* Fill bar */
	.meter-fill {
		position: absolute;
		top: 0;
		left: 0;
		height: 100%;
		transition: width 0.3s ease-out;
	}

	.meter-fill.accent {
		background: var(--color-accent);
		box-shadow: 0 0 8px var(--color-accent-glow);
	}
	.meter-fill.cyan {
		background: var(--color-cyan);
		box-shadow: 0 0 8px var(--color-cyan-glow);
	}
	.meter-fill.amber {
		background: var(--color-amber);
		box-shadow: 0 0 10px var(--color-amber-glow);
	}
	.meter-fill.red {
		background: var(--color-red);
		box-shadow: 0 0 12px var(--color-red-glow);
	}

	/* Glow effect on fill edge */
	.fill-glow {
		position: absolute;
		right: 0;
		top: 0;
		bottom: 0;
		width: 20px;
		background: linear-gradient(to left, rgba(255, 255, 255, 0.3), transparent);
	}

	/* Tick marks */
	.meter-ticks {
		position: absolute;
		inset: 0;
		pointer-events: none;
	}

	.tick {
		position: absolute;
		top: 0;
		bottom: 0;
		width: 1px;
		background: var(--color-border-default);
		opacity: 0.5;
	}

	/* Percentage display */
	.meter-percent {
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		text-align: right;
	}

	.meter-percent.accent {
		color: var(--color-accent);
	}
	.meter-percent.cyan {
		color: var(--color-cyan);
	}
	.meter-percent.amber {
		color: var(--color-amber);
	}
	.meter-percent.red {
		color: var(--color-red);
	}

	/* Critical state animation */
	.ice-threat-meter.active.critical .meter-fill {
		animation: threat-pulse 0.5s ease-in-out infinite;
	}

	.ice-threat-meter.active.critical .meter-status {
		animation: threat-blink 0.3s ease-in-out infinite;
	}

	@keyframes threat-pulse {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.7;
		}
	}

	@keyframes threat-blink {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.5;
		}
	}
</style>
