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
		background-color: var(--color-bg-primary);
		color: var(--color-green-bright);
		font-family: var(--font-mono);
		font-size: var(--text-base);
		line-height: var(--leading-normal);
		position: relative;
		overflow-x: hidden;
	}
</style>
