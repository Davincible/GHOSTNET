<script lang="ts">
	import type { Snippet } from 'svelte';
	import { onMount, onDestroy } from 'svelte';
	import '../app.css';
	import { Shell, Scanlines, Flicker, ScreenFlash } from '$lib/ui/terminal';
	import { initializeProvider } from '$lib/core/stores/index.svelte';
	import { getSettings } from '$lib/core/settings';
	import { getAudioManager, initAudio } from '$lib/core/audio';

	interface Props {
		children: Snippet;
	}

	let { children }: Props = $props();

	// Initialize the data provider and set in context
	const provider = initializeProvider();

	// Get settings for visual effects
	const settings = getSettings();
	
	// Get audio manager
	const audio = getAudioManager();

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

		// Subscribe to feed events for screen flashes and audio
		const unsubscribe = provider.subscribeFeed((event) => {
			// Visual effects
			if (event.type === 'TRACED') {
				flashType = 'death';
			} else if (event.type === 'JACKPOT') {
				flashType = 'jackpot';
			}
			
			// Audio effects
			switch (event.type) {
				case 'JACK_IN':
					audio.jackIn();
					break;
				case 'EXTRACT':
					audio.extract();
					break;
				case 'TRACED':
					audio.traced();
					break;
				case 'SURVIVED':
					audio.survived();
					break;
				case 'JACKPOT':
					audio.jackpot();
					break;
				case 'TRACE_SCAN_WARNING':
					audio.scanWarning();
					break;
				case 'TRACE_SCAN_START':
					audio.scanStart();
					break;
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
