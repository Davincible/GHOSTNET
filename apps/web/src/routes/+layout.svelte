<script lang="ts">
	import type { Snippet } from 'svelte';
	import { onMount, onDestroy } from 'svelte';
	import '../app.css';
	import { Shell, Scanlines, Flicker, ScreenFlash } from '$lib/ui/terminal';
	import { initializeProvider } from '$lib/core/stores/index.svelte';
	import { initializeSettings } from '$lib/core/settings';
	import { createAudioManager, initAudio } from '$lib/core/audio';
	import { initializeToasts } from '$lib/ui/toast';

	interface Props {
		children: Snippet;
	}

	let { children }: Props = $props();

	// Initialize context-based stores (must be done during component init)
	const provider = initializeProvider();
	const settings = initializeSettings();
	initializeToasts();

	// Create audio manager with settings reference (captured during init)
	const audio = createAudioManager(settings);

	// Screen flash state (controlled by feed events)
	let flashType: 'death' | 'jackpot' | 'warning' | 'success' | null = $state(null);

	// Connect provider on mount
	onMount(() => {
		provider.connect();

		// Initialize audio on first user interaction
		const initOnInteraction = () => {
			initAudio();
			document.removeEventListener('click', initOnInteraction);
			document.removeEventListener('keydown', initOnInteraction);
		};
		document.addEventListener('click', initOnInteraction);
		document.addEventListener('keydown', initOnInteraction);

		// Subscribe to feed events for screen flashes
		// Audio is intentionally NOT triggered here — feed events fire continuously
		// and background sounds are distracting. Sound should only play in response
		// to direct user actions or game-critical moments.
		const unsubscribe = provider.subscribeFeed((event) => {
			if (event.type === 'TRACED') {
				flashType = 'death';
			} else if (event.type === 'JACKPOT') {
				flashType = 'jackpot';
			}
		});

		return () => {
			unsubscribe();
			document.removeEventListener('click', initOnInteraction);
			document.removeEventListener('keydown', initOnInteraction);
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
