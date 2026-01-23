<script lang="ts">
	import { formatMultiplier } from '../store.svelte';

	interface Props {
		/** Current multiplier value (animated) */
		multiplier: number;
		/** Player's target multiplier (if bet placed) */
		targetMultiplier?: number | null;
		/** Player's result */
		playerResult?: 'pending' | 'won' | 'lost';
		/** Whether the game has crashed/settled */
		crashed?: boolean;
		/** Crash point (shown after reveal) */
		crashPoint?: number | null;
	}

	let {
		multiplier,
		targetMultiplier = null,
		playerResult = 'pending',
		crashed = false,
		crashPoint = null,
	}: Props = $props();

	// Scale increases slightly with multiplier for visual emphasis
	let scale = $derived(Math.min(1 + (multiplier - 1) * 0.02, 1.5));

	// Color class based on multiplier and target
	let colorClass = $derived.by(() => {
		if (crashed) return 'crashed';
		if (!targetMultiplier) {
			// Default colors based on absolute value
			if (multiplier < 2) return 'mult-low';
			if (multiplier < 5) return 'mult-mid';
			if (multiplier < 10) return 'mult-high';
			return 'mult-extreme';
		}
		// Colors relative to player's target
		if (multiplier >= targetMultiplier) return 'mult-passed'; // Passed target = safe (for now)
		if (multiplier >= targetMultiplier * 0.8) return 'mult-danger'; // Approaching target
		return 'mult-safe'; // Well below target
	});

	// Status text
	let statusText = $derived.by(() => {
		if (crashed && crashPoint) return `CRASHED @ ${formatMultiplier(crashPoint)}`;
		if (playerResult === 'won') return 'SAFE!';
		if (playerResult === 'lost') return 'BUSTED';
		if (targetMultiplier && multiplier >= targetMultiplier) return 'TARGET REACHED!';
		return null;
	});

	// Display value
	let displayValue = $derived(crashed && crashPoint ? crashPoint : multiplier);
</script>

<div
	class="multiplier-display {colorClass}"
	class:crashed
	class:has-target={targetMultiplier}
	style:--scale={scale}
>
	{#if crashed}
		<div class="crash-label">CRASHED @</div>
	{/if}

	<div class="multiplier-value">
		{formatMultiplier(displayValue)}
	</div>

	{#if statusText && !crashed}
		<div
			class="status-text"
			class:won={playerResult === 'won'}
			class:lost={playerResult === 'lost'}
		>
			{statusText}
		</div>
	{/if}

	{#if targetMultiplier && !crashed}
		<div class="target-line">
			<span class="target-label">YOUR TARGET</span>
			<span class="target-value">{formatMultiplier(targetMultiplier)}</span>
		</div>
	{/if}

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
		transition:
			transform 0.1s ease-out,
			color 0.3s ease;
	}

	/* Status text */
	.status-text {
		margin-top: var(--space-2);
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	.status-text.won {
		color: var(--color-accent);
		animation: pulse-glow 0.5s ease-in-out infinite;
	}

	.status-text.lost {
		color: var(--color-red);
	}

	/* Target line */
	.target-line {
		display: flex;
		flex-direction: column;
		align-items: center;
		margin-top: var(--space-4);
		padding: var(--space-2) var(--space-4);
		background: var(--color-bg-tertiary);
		border: var(--border-width) dashed var(--color-cyan);
	}

	.target-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.target-value {
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		color: var(--color-cyan);
	}

	/* Default color states (no target) */
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

	/* Target-relative color states */
	.mult-safe .multiplier-value {
		color: var(--color-accent);
		text-shadow: 0 0 30px var(--color-accent-glow);
	}

	.mult-danger .multiplier-value {
		color: var(--color-amber);
		text-shadow: 0 0 40px var(--color-amber-glow);
		animation: pulse 0.8s ease-in-out infinite;
	}

	.mult-passed .multiplier-value {
		color: var(--color-accent);
		text-shadow: 0 0 50px var(--color-accent-glow);
	}

	/* Crashed state */
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

	@keyframes pulse-glow {
		0%,
		100% {
			text-shadow: 0 0 10px var(--color-accent);
		}
		50% {
			text-shadow: 0 0 30px var(--color-accent);
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
