<script lang="ts">
	import type { Snippet } from 'svelte';
	import { onMount, onDestroy } from 'svelte';
	import '../app.css';
	import { Shell, Scanlines, Flicker, ScreenFlash } from '$lib/ui/terminal';
	import { initializeProvider } from '$lib/core/stores/index.svelte';
	import { getSettings } from '$lib/core/settings';

	interface Props {
		children: Snippet;
	}

	let { children }: Props = $props();

	// Initialize the data provider and set in context
	const provider = initializeProvider();

	// Get settings for visual effects
	const settings = getSettings();

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
	<Scanlines enabled={settings.scanlinesEnabled} />
	<Flicker enabled={settings.flickerEnabled}>
		{@render children()}
	</Flicker>
	{#if settings.effectsEnabled}
		<ScreenFlash type={flashType} onComplete={() => (flashType = null)} />
	{/if}
</Shell>
