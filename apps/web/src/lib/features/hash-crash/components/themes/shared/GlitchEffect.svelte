<script lang="ts">
	/**
	 * Glitch effect component for crash/trace events.
	 * Applies RGB split and shake animation to children.
	 */

	import type { Snippet } from 'svelte';

	interface Props {
		/** Whether the glitch is active */
		active?: boolean;
		/** Duration of glitch in ms */
		duration?: number;
		/** Intensity (1-3) */
		intensity?: 1 | 2 | 3;
		/** Content to render */
		children: Snippet;
	}

	let { active = false, duration = 500, intensity = 2, children }: Props = $props();

	// Auto-deactivate after duration
	let isGlitching = $state(false);

	$effect(() => {
		if (active && !isGlitching) {
			isGlitching = true;
			setTimeout(() => {
				isGlitching = false;
			}, duration);
		}
	});
</script>

<div
	class="glitch-container"
	class:glitching={isGlitching}
	class:intensity-1={intensity === 1}
	class:intensity-2={intensity === 2}
	class:intensity-3={intensity === 3}
	style:--glitch-duration="{duration}ms"
>
	{@render children()}
</div>

<style>
	.glitch-container {
		position: relative;
	}

	.glitch-container.glitching {
		animation: glitch-shake var(--glitch-duration) ease-in-out;
	}

	/* Intensity levels affect offset amount */
	.intensity-1.glitching {
		--glitch-offset: 2px;
	}

	.intensity-2.glitching {
		--glitch-offset: 4px;
	}

	.intensity-3.glitching {
		--glitch-offset: 8px;
	}

	/* Glitch animation */
	@keyframes glitch-shake {
		0%,
		100% {
			transform: translate(0);
			filter: none;
		}
		10% {
			transform: translate(calc(var(--glitch-offset) * -1), var(--glitch-offset));
		}
		20% {
			transform: translate(var(--glitch-offset), calc(var(--glitch-offset) * -1));
			filter: hue-rotate(90deg);
		}
		30% {
			transform: translate(calc(var(--glitch-offset) * -1), 0);
		}
		40% {
			transform: translate(0, var(--glitch-offset));
			filter: saturate(2);
		}
		50% {
			transform: translate(var(--glitch-offset), calc(var(--glitch-offset) * -1));
		}
		60% {
			transform: translate(calc(var(--glitch-offset) * -1), var(--glitch-offset));
			filter: hue-rotate(-90deg);
		}
		70% {
			transform: translate(var(--glitch-offset), 0);
		}
		80% {
			transform: translate(0, calc(var(--glitch-offset) * -1));
			filter: none;
		}
		90% {
			transform: translate(calc(var(--glitch-offset) * -1), var(--glitch-offset));
		}
	}

	/* RGB split effect on text (applied via global class) */
	:global(.glitch-text) {
		position: relative;
	}

	:global(.glitch-text::before),
	:global(.glitch-text::after) {
		content: attr(data-text);
		position: absolute;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
	}

	:global(.glitch-text::before) {
		color: var(--color-red);
		clip-path: inset(0 0 50% 0);
		transform: translate(-2px, -1px);
		animation: glitch-clip 0.3s infinite linear alternate-reverse;
	}

	:global(.glitch-text::after) {
		color: var(--color-cyan);
		clip-path: inset(50% 0 0 0);
		transform: translate(2px, 1px);
		animation: glitch-clip 0.3s infinite linear alternate;
	}

	@keyframes glitch-clip {
		0% {
			clip-path: inset(0 0 85% 0);
		}
		25% {
			clip-path: inset(30% 0 40% 0);
		}
		50% {
			clip-path: inset(70% 0 5% 0);
		}
		75% {
			clip-path: inset(10% 0 60% 0);
		}
		100% {
			clip-path: inset(50% 0 25% 0);
		}
	}
</style>
