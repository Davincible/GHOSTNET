<script lang="ts">
	import { formatMultiplier, getMultiplierColor } from '../store.svelte';

	interface Props {
		/** Current multiplier value */
		multiplier: number;
		/** Whether the game has crashed */
		crashed?: boolean;
		/** Crash point (shown after crash) */
		crashPoint?: number | null;
	}

	let { multiplier, crashed = false, crashPoint = null }: Props = $props();

	// Scale increases slightly with multiplier for visual emphasis
	let scale = $derived(Math.min(1 + (multiplier - 1) * 0.02, 1.5));

	// Color class based on multiplier
	let colorClass = $derived(crashed ? 'crashed' : getMultiplierColor(multiplier));

	// Display value
	let displayValue = $derived(crashed && crashPoint ? crashPoint : multiplier);
</script>

<div class="multiplier-display {colorClass}" class:crashed style:--scale={scale}>
	{#if crashed}
		<div class="crash-label">CRASHED @</div>
	{/if}
	<div class="multiplier-value">
		{formatMultiplier(displayValue)}
	</div>
	{#if !crashed}
		<div class="pulse-ring"></div>
	{/if}
</div>

<style>
	.multiplier-display {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		position: relative;
		padding: var(--space-8);
	}

	.crash-label {
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-widest);
		text-transform: uppercase;
		color: var(--color-red);
		margin-bottom: var(--space-2);
		animation: flash 0.5s ease-in-out;
	}

	.multiplier-value {
		font-family: var(--font-mono);
		font-size: clamp(3rem, 10vw, 6rem);
		font-weight: var(--font-bold);
		font-variant-numeric: tabular-nums;
		line-height: 1;
		transform: scale(var(--scale));
		transition: transform 0.1s ease-out, color 0.3s ease;
	}

	/* Color states */
	.mult-low .multiplier-value {
		color: var(--color-accent);
		text-shadow: 0 0 20px var(--color-accent-glow);
	}

	.mult-mid .multiplier-value {
		color: var(--color-cyan);
		text-shadow: 0 0 30px var(--color-cyan-glow);
	}

	.mult-high .multiplier-value {
		color: var(--color-amber);
		text-shadow: 0 0 40px var(--color-amber-glow);
	}

	.mult-extreme .multiplier-value {
		color: var(--color-red);
		text-shadow: 0 0 50px var(--color-red-glow);
		animation: pulse 0.5s ease-in-out infinite;
	}

	.crashed .multiplier-value {
		color: var(--color-red);
		text-shadow: 0 0 60px var(--color-red);
		animation: shake 0.5s ease-in-out;
	}

	/* Pulse ring animation behind multiplier when active */
	.pulse-ring {
		position: absolute;
		width: 150%;
		height: 150%;
		border-radius: 50%;
		border: 2px solid currentColor;
		opacity: 0.3;
		animation: pulse-expand 2s ease-out infinite;
		pointer-events: none;
	}

	@keyframes pulse-expand {
		0% {
			transform: scale(0.8);
			opacity: 0.5;
		}
		100% {
			transform: scale(1.5);
			opacity: 0;
		}
	}

	@keyframes pulse {
		0%,
		100% {
			transform: scale(var(--scale));
		}
		50% {
			transform: scale(calc(var(--scale) * 1.05));
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
			transform: translateX(-5px);
		}
		20%,
		40%,
		60%,
		80% {
			transform: translateX(5px);
		}
	}

	@keyframes flash {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0;
		}
	}
</style>
