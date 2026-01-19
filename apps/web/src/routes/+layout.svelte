<script lang="ts">
	import type { Snippet } from 'svelte';
	import '../app.css';
	import { Shell, Scanlines, Flicker, ScreenFlash } from '$lib/ui/terminal';

	interface Props {
		children: Snippet;
	}

	let { children }: Props = $props();

	// Screen flash state (will be controlled by event bus in Phase 3)
	let flashType: 'death' | 'jackpot' | 'warning' | 'success' | null = $state(null);
</script>

<Shell>
	<Scanlines />
	<Flicker>
		{@render children()}
	</Flicker>
	<ScreenFlash type={flashType} onComplete={() => flashType = null} />
</Shell>
