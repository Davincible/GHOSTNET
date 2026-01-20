<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		children: Snippet;
	}

	let { children }: Props = $props();
</script>

<div class="shell">
	{@render children()}
</div>

<style>
	.shell {
		min-height: 100vh;
		min-height: 100dvh;
		width: 100%;
		background-color: var(--color-bg-void);
		color: var(--color-text-primary);
		font-family: var(--font-mono);
		font-size: var(--text-base);
		line-height: var(--leading-normal);
		position: relative;
		overflow-x: hidden;
		/* Subtle vignette effect for depth */
		background-image: radial-gradient(
			ellipse at 50% 50%,
			var(--color-bg-primary) 0%,
			var(--color-bg-void) 100%
		);
	}
</style>
