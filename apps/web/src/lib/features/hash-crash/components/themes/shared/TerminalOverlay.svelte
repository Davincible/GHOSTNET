<script lang="ts">
	/**
	 * Terminal overlay effects for Hash Crash themes.
	 * Adds CRT scanlines and optional screen flicker.
	 */

	import type { Snippet } from 'svelte';

	interface Props {
		/** Enable scanlines effect */
		scanlines?: boolean;
		/** Enable subtle screen flicker */
		flicker?: boolean;
		/** Scanline opacity (0-1) */
		opacity?: number;
		/** Content to render */
		children: Snippet;
	}

	let { scanlines = true, flicker = true, opacity = 0.03, children }: Props = $props();
</script>

<div class="terminal-overlay" class:flicker style:--scanline-opacity={opacity}>
	{#if scanlines}
		<div class="scanlines"></div>
	{/if}
	{@render children()}
</div>

<style>
	.terminal-overlay {
		position: relative;
		width: 100%;
		height: 100%;
	}

	.terminal-overlay.flicker {
		animation: terminal-flicker 8s infinite;
	}

	.scanlines {
		position: absolute;
		inset: 0;
		pointer-events: none;
		z-index: 100;
		background: repeating-linear-gradient(
			0deg,
			transparent 0px,
			transparent 1px,
			rgba(0, 255, 0, var(--scanline-opacity)) 1px,
			rgba(0, 255, 0, var(--scanline-opacity)) 2px
		);
	}

	@keyframes terminal-flicker {
		0%,
		100% {
			opacity: 1;
		}
		92% {
			opacity: 1;
		}
		93% {
			opacity: 0.95;
		}
		94% {
			opacity: 1;
		}
		97% {
			opacity: 0.98;
		}
		98% {
			opacity: 1;
		}
	}
</style>
