<script lang="ts">
	import { goto } from '$app/navigation';
	import { Header } from '$lib/features/header';
	import { FeedPanel } from '$lib/features/feed';
	import { PositionPanel, ModifiersPanel } from '$lib/features/position';
	import { NetworkVitalsPanel } from '$lib/features/network';
	import { QuickActionsPanel } from '$lib/features/actions';
	import { NavigationBar } from '$lib/features/nav';
	import { WelcomePanel } from '$lib/features/welcome';
	import { JackInModal, ExtractModal, SettingsModal } from '$lib/features/modals';
	import { ToastContainer, getToasts } from '$lib/ui/toast';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import { NetworkVisualizationPanel } from '$lib/ui/visualizations';

	const provider = getProvider();
	const toast = getToasts();

	// Navigation state
	let activeNav = $state('network');

	// Modal state
	let showJackInModal = $state(false);
	let showExtractModal = $state(false);
	let showSettingsModal = $state(false);

	// Action handlers
	function handleJackIn() {
		showJackInModal = true;
	}

	function handleExtract() {
		showExtractModal = true;
	}

	function handleTraceEvasion() {
		goto('/typing');
	}

	function handleHackRun() {
		toast.info('Hack Run coming soon...');
	}

	function handleCrew() {
		toast.info('Crew system coming soon...');
	}

	function handleDeadPool() {
		toast.info('Dead Pool coming soon...');
	}

	function handleWatchFeed() {
		// Scroll to the feed panel smoothly
		const feedElement = document.querySelector('.column-left');
		if (feedElement) {
			feedElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
		}
	}

	function handleNavigate(id: string) {
		activeNav = id;
	}

	// Keyboard shortcuts
	function handleKeydown(event: KeyboardEvent) {
		// Ignore if user is typing in an input
		if (
			event.target instanceof HTMLInputElement ||
			event.target instanceof HTMLTextAreaElement
		) {
			return;
		}

		switch (event.key.toLowerCase()) {
			case 'j':
				if (!provider.currentUser) {
					toast.warning('Connect wallet to Jack In');
				} else {
					handleJackIn();
				}
				break;
			case 'e':
				if (!provider.currentUser) {
					toast.warning('Connect wallet first');
				} else if (!provider.position) {
					toast.warning('Jack In first to Extract');
				} else {
					handleExtract();
				}
				break;
			case 't':
				if (!provider.currentUser) {
					toast.warning('Connect wallet first');
				} else if (!provider.position) {
					toast.warning('Jack In first to play Trace Evasion');
				} else {
					handleTraceEvasion();
				}
				break;
			case 'h':
				if (!provider.currentUser) {
					toast.warning('Connect wallet first');
				} else if (!provider.position) {
					toast.warning('Jack In first to play Hack Run');
				} else {
					handleHackRun();
				}
				break;
			case 'c':
				if (!provider.currentUser) {
					toast.warning('Connect wallet to access Crew');
				} else {
					handleCrew();
				}
				break;
			case 'p':
				if (!provider.currentUser) {
					toast.warning('Connect wallet to access Dead Pool');
				} else {
					handleDeadPool();
				}
				break;
		}
	}
</script>

<svelte:head>
	<title>GHOSTNET v1.0.7 - Command Center</title>
	<meta name="description" content="Jack In. Don't Get Traced. Real-time survival game on MegaETH." />
</svelte:head>

<svelte:window onkeydown={handleKeydown} />

<div class="command-center">
	<Header onSettings={() => showSettingsModal = true} />

	<main class="main-content">
		<div class="content-grid">
			<!-- Left Column: Feed, Welcome & Visualization -->
			<div class="column column-left">
				<FeedPanel maxHeight="300px" maxEvents={12} />
				<WelcomePanel 
					onJackIn={handleJackIn}
					onWatchFeed={handleWatchFeed}
				/>
				<NetworkVisualizationPanel 
					operatorCount={provider.networkState.operatorsOnline}
				/>
			</div>

			<!-- Right Column: Position, Network Stats, Actions -->
			<div class="column column-right">
				<PositionPanel />
				<ModifiersPanel />
				<NetworkVitalsPanel />
				<QuickActionsPanel
					onJackIn={handleJackIn}
					onExtract={handleExtract}
					onTraceEvasion={handleTraceEvasion}
					onHackRun={handleHackRun}
					onCrew={handleCrew}
					onDeadPool={handleDeadPool}
				/>
			</div>
		</div>
	</main>

	<NavigationBar active={activeNav} onNavigate={handleNavigate} />
</div>

<!-- Modals -->
<JackInModal open={showJackInModal} onclose={() => showJackInModal = false} />
<ExtractModal open={showExtractModal} onclose={() => showExtractModal = false} />
<SettingsModal open={showSettingsModal} onclose={() => showSettingsModal = false} />

<!-- Toast notifications -->
<ToastContainer />

<style>
	.command-center {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
	}

	.main-content {
		flex: 1;
		padding: var(--space-4) var(--space-6);
		width: 100%;
		max-width: 1200px;
		margin: 0 auto;
	}

	.content-grid {
		display: grid;
		grid-template-columns: minmax(0, 2fr) minmax(0, 1fr);
		gap: var(--space-4);
		height: 100%;
	}

	.column {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		min-width: 0; /* Allow column to shrink below content size */
	}



	/* Responsive Layout */
	@media (max-width: 1024px) {
		.content-grid {
			grid-template-columns: minmax(0, 1fr);
		}

		.column-left {
			order: 2;
		}

		.column-right {
			order: 1;
		}
	}

	@media (max-width: 640px) {
		.main-content {
			padding: var(--space-2);
		}

		.content-grid {
			gap: var(--space-2);
		}

		.column {
			gap: var(--space-2);
		}
	}
</style>
