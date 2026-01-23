<script lang="ts">
	/**
	 * Red screen flash effect for trace/crash events.
	 * Overlays the entire container with a pulsing red flash.
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

	let { active = false, duration = 600, children }: Props = $props();

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

<div class="trace-flash-container">
	{@render children()}
	{#if isFlashing}
		<div class="flash-overlay" style:--flash-duration="{duration}ms"></div>
	{/if}
</div>

<style>
	.trace-flash-container {
		position: relative;
		width: 100%;
		height: 100%;
	}

	.flash-overlay {
		position: absolute;
		inset: 0;
		pointer-events: none;
		z-index: 200;
		animation: trace-flash var(--flash-duration) ease-out forwards;
	}

	@keyframes trace-flash {
		0% {
			background: transparent;
		}
		10% {
			background: rgba(255, 0, 0, 0.4);
		}
		20% {
			background: transparent;
		}
		30% {
			background: rgba(255, 0, 0, 0.3);
		}
		40% {
			background: transparent;
		}
		50% {
			background: rgba(255, 0, 0, 0.2);
		}
		60% {
			background: transparent;
		}
		70% {
			background: rgba(255, 0, 0, 0.1);
		}
		100% {
			background: transparent;
		}
	}
</style>
