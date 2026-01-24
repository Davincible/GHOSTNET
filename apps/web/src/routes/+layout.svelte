<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { FeedEventType } from '$lib/core/types';
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

		// Subscribe to feed events for screen flashes and audio
		const unsubscribe = provider.subscribeFeed((event) => {
			// Visual effects
			if (event.type === 'TRACED') {
				flashType = 'death';
			} else if (event.type === 'JACKPOT') {
				flashType = 'jackpot';
			}

			// Audio effects
			const audioHandlers: Partial<Record<FeedEventType, () => void>> = {
				JACK_IN: () => audio.jackIn(),
				EXTRACT: () => audio.extract(),
				TRACED: () => audio.traced(),
				SURVIVED: () => audio.survived(),
				JACKPOT: () => audio.jackpot(),
				TRACE_SCAN_WARNING: () => audio.scanWarning(),
				TRACE_SCAN_START: () => audio.scanStart(),
			};

			const handler = audioHandlers[event.type];
			if (handler) handler();
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
