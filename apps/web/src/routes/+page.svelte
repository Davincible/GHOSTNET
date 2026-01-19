<script lang="ts">
	import { goto } from '$app/navigation';
	import { Header } from '$lib/features/header';
	import { FeedPanel } from '$lib/features/feed';
	import { PositionPanel, ModifiersPanel } from '$lib/features/position';
	import { NetworkVitalsPanel } from '$lib/features/network';
	import { QuickActionsPanel } from '$lib/features/actions';
	import { NavigationBar } from '$lib/features/nav';
	import { getProvider } from '$lib/core/stores/index.svelte';

	const provider = getProvider();

	// Navigation state
	let activeNav = $state('network');

	// Action handlers
	function handleJackIn() {
		// TODO: Open Jack In modal
		console.log('Jack In clicked');
	}

	function handleExtract() {
		// TODO: Confirm and extract
		provider.extract().catch(console.error);
	}

	function handleTraceEvasion() {
		goto('/typing');
	}

	function handleHackRun() {
		// TODO: Navigate to hack run
		console.log('Hack Run clicked');
	}

	function handleCrew() {
		// TODO: Navigate to crew page
		console.log('Crew clicked');
	}

	function handleDeadPool() {
		// TODO: Navigate to Dead Pool
		console.log('Dead Pool clicked');
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
				handleJackIn();
				break;
			case 'e':
				if (provider.position) handleExtract();
				break;
			case 't':
				if (provider.position) handleTraceEvasion();
				break;
			case 'h':
				if (provider.position) handleHackRun();
				break;
			case 'c':
				if (provider.currentUser) handleCrew();
				break;
			case 'p':
				if (provider.currentUser) handleDeadPool();
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
	<Header />

	<main class="main-content">
		<div class="content-grid">
			<!-- Left Column: Feed & Network -->
			<div class="column column-left">
				<FeedPanel maxHeight="350px" maxEvents={15} />
				<NetworkVitalsPanel />
			</div>

			<!-- Right Column: Position, Modifiers, Actions -->
			<div class="column column-right">
				<PositionPanel />
				<ModifiersPanel />
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

<style>
	.command-center {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
	}

	.main-content {
		flex: 1;
		padding: var(--space-4);
		max-width: var(--container-xl);
		margin: 0 auto;
		width: 100%;
	}

	.content-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: var(--space-4);
		height: 100%;
	}

	.column {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}



	/* Responsive Layout */
	@media (max-width: 1024px) {
		.content-grid {
			grid-template-columns: 1fr;
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
