<script lang="ts">
	import Shell from '$lib/ui/terminal/Shell.svelte';
	import Scanlines from '$lib/ui/terminal/Scanlines.svelte';
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

<Shell>
	<HashCrashGame simulate={simulationMode} />
</Shell>
<Scanlines />

<style>
	:global(body) {
		overflow-x: hidden;
	}
</style>
