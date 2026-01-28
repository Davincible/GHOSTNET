<script lang="ts">
	import Shell from '$lib/ui/terminal/Shell.svelte';
	import Scanlines from '$lib/ui/terminal/Scanlines.svelte';
	import { NavigationBar } from '$lib/features/nav';
	import { Header, Breadcrumb } from '$lib/features/header';
	import { HashCrashGame } from '$lib/features/hash-crash';

	// Use simulation mode for now (no backend yet)
	const simulationMode = true;
</script>

<svelte:head>
	<title>HASH CRASH | GHOSTNET Arcade</title>
	<meta
		name="description"
		content="Bet on the multiplier. Cash out before it crashes. A provably fair crash game on GHOSTNET."
	/>
</svelte:head>

<Header />
<Breadcrumb
	path={[
		{ label: 'NETWORK', href: '/' },
		{ label: 'ARCADE', href: '/arcade' },
		{ label: 'HASH CRASH' },
	]}
/>

<Shell>
	<div class="hash-crash-page">
		<HashCrashGame simulate={simulationMode} />
	</div>
</Shell>
<Scanlines />
<NavigationBar active="arcade" />

<style>
	:global(body) {
		overflow-x: hidden;
	}

	.hash-crash-page {
		padding-bottom: var(--space-16);
	}
</style>
