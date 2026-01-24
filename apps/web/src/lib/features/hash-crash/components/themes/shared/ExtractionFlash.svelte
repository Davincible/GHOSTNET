<script lang="ts">
	/**
	 * Green screen flash effect for successful extraction/win events.
	 * Overlays the entire container with celebratory green pulses and particles.
	 */

	import type { Snippet } from 'svelte';

	interface Props {
		/** Whether the flash is active */
		active?: boolean;
		/** Duration of flash in ms */
		duration?: number;
		/** Content to render */
		children: Snippet;
	}

	let { active = false, duration = 1500, children }: Props = $props();

	// Track flash state
	let isFlashing = $state(false);

	$effect(() => {
		if (active && !isFlashing) {
			isFlashing = true;
			setTimeout(() => {
				isFlashing = false;
			}, duration);
		}
	});
</script>

<div class="extraction-flash-container">
	{@render children()}
	{#if isFlashing}
		<div class="flash-overlay" style:--flash-duration="{duration}ms">
			<!-- Radial burst effect -->
			<div class="burst"></div>
			<!-- Particle shower -->
			<div class="particles">
				{#each Array(12) as _, i}
					<div class="particle" style:--delay="{i * 50}ms" style:--angle="{i * 30}deg"></div>
				{/each}
			</div>
			<!-- Scan lines sweep -->
			<div class="scan-sweep"></div>
		</div>
	{/if}
</div>

<style>
	.extraction-flash-container {
		position: relative;
		width: 100%;
		height: 100%;
	}

	.flash-overlay {
		position: absolute;
		inset: 0;
		pointer-events: none;
		z-index: 200;
		overflow: hidden;
		animation: extraction-flash var(--flash-duration) ease-out forwards;
	}

	/* Main flash animation - pulsing green glow */
	@keyframes extraction-flash {
		0% {
			background: transparent;
			box-shadow: inset 0 0 0 transparent;
		}
		5% {
			background: rgba(0, 229, 204, 0.5);
			box-shadow: inset 0 0 100px rgba(0, 229, 204, 0.8);
		}
		15% {
			background: rgba(0, 229, 204, 0.2);
			box-shadow: inset 0 0 60px rgba(0, 229, 204, 0.5);
		}
		25% {
			background: rgba(0, 229, 204, 0.4);
			box-shadow: inset 0 0 80px rgba(0, 229, 204, 0.6);
		}
		40% {
			background: rgba(0, 229, 204, 0.15);
			box-shadow: inset 0 0 40px rgba(0, 229, 204, 0.3);
		}
		55% {
			background: rgba(0, 229, 204, 0.25);
			box-shadow: inset 0 0 50px rgba(0, 229, 204, 0.4);
		}
		70% {
			background: rgba(0, 229, 204, 0.1);
			box-shadow: inset 0 0 30px rgba(0, 229, 204, 0.2);
		}
		85% {
			background: rgba(0, 229, 204, 0.05);
		}
		100% {
			background: transparent;
			box-shadow: inset 0 0 0 transparent;
		}
	}

	/* Radial burst from center */
	.burst {
		position: absolute;
		top: 50%;
		left: 50%;
		width: 10px;
		height: 10px;
		background: var(--color-accent);
		border-radius: 50%;
		transform: translate(-50%, -50%);
		animation: burst-expand var(--flash-duration) ease-out forwards;
	}

	@keyframes burst-expand {
		0% {
			width: 10px;
			height: 10px;
			opacity: 1;
			box-shadow:
				0 0 20px var(--color-accent),
				0 0 40px var(--color-accent);
		}
		30% {
			width: 300%;
			height: 300%;
			opacity: 0.6;
			box-shadow:
				0 0 60px var(--color-accent),
				0 0 120px var(--color-accent);
		}
		100% {
			width: 400%;
			height: 400%;
			opacity: 0;
		}
	}

	/* Particle container */
	.particles {
		position: absolute;
		top: 50%;
		left: 50%;
		width: 0;
		height: 0;
	}

	/* Individual particles shooting outward */
	.particle {
		position: absolute;
		width: 4px;
		height: 4px;
		background: var(--color-accent);
		border-radius: 50%;
		box-shadow:
			0 0 6px var(--color-accent),
			0 0 12px var(--color-accent);
		animation: particle-shoot calc(var(--flash-duration) * 0.6) ease-out forwards;
		animation-delay: var(--delay);
		transform: rotate(var(--angle));
	}

	@keyframes particle-shoot {
		0% {
			transform: rotate(var(--angle)) translateY(0);
			opacity: 1;
		}
		100% {
			transform: rotate(var(--angle)) translateY(-200px);
			opacity: 0;
		}
	}

	/* Horizontal scan sweep */
	.scan-sweep {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		height: 3px;
		background: linear-gradient(
			90deg,
			transparent,
			var(--color-accent),
			rgba(0, 229, 204, 0.8),
			var(--color-accent),
			transparent
		);
		box-shadow:
			0 0 20px var(--color-accent),
			0 0 40px var(--color-accent);
		animation: scan-down var(--flash-duration) ease-in-out forwards;
	}

	@keyframes scan-down {
		0% {
			top: 0;
			opacity: 0;
		}
		10% {
			opacity: 1;
		}
		50% {
			top: 100%;
			opacity: 1;
		}
		60% {
			top: 100%;
			opacity: 0;
		}
		100% {
			top: 100%;
			opacity: 0;
		}
	}
</style>
