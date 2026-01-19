<script lang="ts">
	import type { Snippet } from 'svelte';
	import { onMount, onDestroy } from 'svelte';
	import '../app.css';
	import { Shell, Scanlines, Flicker, ScreenFlash } from '$lib/ui/terminal';
	import { initializeProvider } from '$lib/core/stores/index.svelte';

	interface Props {
		children: Snippet;
	}

	let { children }: Props = $props();

	// Initialize the data provider and set in context
	const provider = initializeProvider();

	// Screen flash state (controlled by feed events)
	let flashType: 'death' | 'jackpot' | 'warning' | 'success' | null = $state(null);

	// Connect provider on mount
	onMount(() => {
		provider.connect();

		// Subscribe to feed events for screen flashes
		const unsubscribe = provider.subscribeFeed((event) => {
			if (event.type === 'TRACED') {
				flashType = 'death';
			} else if (event.type === 'JACKPOT') {
				flashType = 'jackpot';
			}
		});

		return () => {
			unsubscribe();
		};
	});

	// Disconnect on destroy
	onDestroy(() => {
		provider.disconnect();
	});
</script>

<Shell>
	<Scanlines />
	<Flicker>
		{@render children()}
	</Flicker>
	<ScreenFlash type={flashType} onComplete={() => (flashType = null)} />
</Shell>
