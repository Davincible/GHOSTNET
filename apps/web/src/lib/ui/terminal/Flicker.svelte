<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		/** Enable/disable flicker effect */
		enabled?: boolean;
		/** Flicker intensity (affects opacity range) */
		intensity?: 'subtle' | 'normal' | 'intense';
		children: Snippet;
	}

	let { enabled = true, intensity = 'subtle', children }: Props = $props();
</script>

<div
	class="flicker"
	class:flicker-enabled={enabled}
	class:flicker-subtle={intensity === 'subtle'}
	class:flicker-normal={intensity === 'normal'}
	class:flicker-intense={intensity === 'intense'}
>
	{@render children()}
</div>

<style>
	.flicker {
		width: 100%;
		height: 100%;
	}

	/* Subtle flicker - barely noticeable */
	.flicker-enabled.flicker-subtle {
		animation: flicker-subtle 8s infinite;
	}

	/* Normal flicker */
	.flicker-enabled.flicker-normal {
		animation: flicker-normal 6s infinite;
	}

	/* Intense flicker - more noticeable */
	.flicker-enabled.flicker-intense {
		animation: flicker-intense 4s infinite;
	}

	@keyframes flicker-subtle {
		0%,
		100% {
			opacity: 1;
		}
		97% {
			opacity: 1;
		}
		97.5% {
			opacity: 0.97;
		}
		98% {
			opacity: 1;
		}
	}

	@keyframes flicker-normal {
		0%,
		100% {
			opacity: 1;
		}
		92% {
			opacity: 1;
		}
		93% {
			opacity: 0.9;
		}
		94% {
			opacity: 1;
		}
		95% {
			opacity: 0.95;
		}
		96% {
			opacity: 1;
		}
	}

	@keyframes flicker-intense {
		0%,
		100% {
			opacity: 1;
		}
		90% {
			opacity: 1;
		}
		91% {
			opacity: 0.85;
		}
		92% {
			opacity: 1;
		}
		93% {
			opacity: 0.9;
		}
		94% {
			opacity: 1;
		}
		95% {
			opacity: 0.88;
		}
		96% {
			opacity: 1;
		}
	}

	/* Respect reduced motion preference */
	@media (prefers-reduced-motion: reduce) {
		.flicker-enabled {
			animation: none;
		}
	}
</style>
