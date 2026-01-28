<script lang="ts">
	import Shell from '$lib/ui/terminal/Shell.svelte';
	import Scanlines from '$lib/ui/terminal/Scanlines.svelte';
	import { NavigationBar } from '$lib/features/nav';
	import { Header, Breadcrumb } from '$lib/features/header';
	import GhostMazeGame from '$lib/features/ghost-maze/components/GhostMazeGame.svelte';
</script>

<svelte:head>
	<title>GHOST MAZE | GHOSTNET Arcade</title>
	<meta
		name="description"
		content="Navigate the maze. Collect data. Evade tracers. A Pac-Man inspired network infiltration game on GHOSTNET."
	/>
</svelte:head>

<Header />
<Breadcrumb
	path={[
		{ label: 'NETWORK', href: '/' },
		{ label: 'ARCADE', href: '/arcade' },
		{ label: 'GHOST MAZE' },
	]}
/>

<Shell>
	<div class="ghost-maze-page">
		<GhostMazeGame />
	</div>
</Shell>
<Scanlines />
<NavigationBar active="arcade" />

<style>
	:global(body) {
		overflow-x: hidden;
	}

	.ghost-maze-page {
		padding-bottom: var(--space-16);
	}
</style>
