<script lang="ts">
	interface Props {
		/** Opacity of scanlines (0-1) */
		opacity?: number;
		/** Enable/disable scanlines */
		enabled?: boolean;
	}

	let {
		opacity = 0.03,
		enabled = true
	}: Props = $props();
</script>

{#if enabled}
	<div
		class="scanlines"
		style:--scanline-opacity={opacity}
		aria-hidden="true"
	></div>
{/if}

<style>
	.scanlines {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		pointer-events: none;
		z-index: var(--z-effects);
		background: repeating-linear-gradient(
			0deg,
			transparent,
			transparent 2px,
			rgba(0, 229, 204, var(--scanline-opacity, 0.015)) 3px,
			rgba(0, 229, 204, var(--scanline-opacity, 0.015)) 4px
		);
	}
</style>
