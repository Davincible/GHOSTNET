<script lang="ts">
	import { goto } from '$app/navigation';
	import { Header, KeyboardHints } from '$lib/features/header';
	import { FeedPanel } from '$lib/features/feed';
	import { PositionPanel, ModifiersPanel } from '$lib/features/position';
	import { NetworkVitalsPanel } from '$lib/features/network';
	import { QuickActionsPanel } from '$lib/features/actions';
	import { NavigationBar } from '$lib/features/nav';
	import { WelcomePanel } from '$lib/features/welcome';
	import { JackInModal, ExtractModal, SettingsModal } from '$lib/features/modals';
	import { FAQPanel } from '$lib/features/faq';
	import { ToastContainer, getToasts } from '$lib/ui/toast';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import { NetworkVisualizationPanel } from '$lib/ui/visualizations';

	import { browser } from '$app/environment';

	const provider = getProvider();
	const toast = getToasts();

	// Navigation state
	let activeNav = $state('network');

	// Mobile detection for responsive behavior
	let isMobile = $state(false);

	// Mobile feed expansion state (only used on mobile)
	let feedExpanded = $state(false);

	// Derived feed props: mobile uses collapsed/expanded, desktop always full
	let feedMaxHeight = $derived(isMobile ? (feedExpanded ? '300px' : '150px') : '300px');
	let feedMaxEvents = $derived(isMobile ? (feedExpanded ? 12 : 3) : 12);

	// Set up media query listener (client-side only)
	$effect(() => {
		if (!browser) return;

		const mediaQuery = window.matchMedia('(max-width: 767px)');
		isMobile = mediaQuery.matches;

		function handleChange(e: MediaQueryListEvent) {
			isMobile = e.matches;
		}

		mediaQuery.addEventListener('change', handleChange);
		return () => mediaQuery.removeEventListener('change', handleChange);
	});

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
		if (event.target instanceof HTMLInputElement || event.target instanceof HTMLTextAreaElement) {
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
	<meta
		name="description"
		content="Jack In. Don't Get Traced. Real-time survival game on MegaETH."
	/>
</svelte:head>

<svelte:window onkeydown={handleKeydown} />

<div class="command-center">
	<Header onSettings={() => (showSettingsModal = true)} />
	<KeyboardHints />

	<main class="main-content">
		<div class="content-grid">
			<!-- Left Column: Feed, Welcome & Visualization -->
			<div class="column column-left">
				<!-- Feed: collapsible on mobile, full on desktop -->
				<div class="feed-wrapper" class:feed-collapsed={isMobile && !feedExpanded}>
					<FeedPanel maxHeight={feedMaxHeight} maxEvents={feedMaxEvents} />
					{#if isMobile}
						<button
							class="feed-toggle"
							onclick={() => (feedExpanded = !feedExpanded)}
							aria-expanded={feedExpanded}
							aria-controls="feed-panel"
						>
							{feedExpanded ? '▲ Show Less' : '▼ Show More'}
						</button>
					{/if}
				</div>

				<!-- Welcome & Visualization: hidden on mobile (too heavy) -->
				<div class="hide-mobile">
					<WelcomePanel onJackIn={handleJackIn} onWatchFeed={handleWatchFeed} />
				</div>
				<div class="hide-mobile">
					<NetworkVisualizationPanel operatorCount={provider.networkState.operatorsOnline} />
				</div>
			</div>

			<!-- Right Column: Position, Network Stats, Actions -->
			<div class="column column-right">
				<PositionPanel />
				<ModifiersPanel />
				<!-- Network Vitals: hidden on mobile (accessible via nav) -->
				<div class="hide-mobile">
					<NetworkVitalsPanel />
				</div>
				<QuickActionsPanel
					onJackIn={handleJackIn}
					onExtract={handleExtract}
					onTraceEvasion={handleTraceEvasion}
					onHackRun={handleHackRun}
					onCrew={handleCrew}
					onDeadPool={handleDeadPool}
				/>
				<FAQPanel />
			</div>
		</div>
	</main>

	<NavigationBar active={activeNav} onNavigate={handleNavigate} />
</div>

<!-- Modals -->
<JackInModal open={showJackInModal} onclose={() => (showJackInModal = false)} />
<ExtractModal open={showExtractModal} onclose={() => (showExtractModal = false)} />
<SettingsModal open={showSettingsModal} onclose={() => (showSettingsModal = false)} />

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

	/* ════════════════════════════════════════════════════════════════
	   RESPONSIVE GRID
	   Mobile: single column, position panel first
	   Tablet: 60/40 split
	   Desktop: 2fr/1fr split
	   ════════════════════════════════════════════════════════════════ */

	.content-grid {
		display: grid;
		grid-template-columns: 1fr; /* Mobile first: single column */
		gap: var(--space-4);
		height: 100%;
	}

	.column {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		min-width: 0; /* Allow column to shrink below content size */
	}

	/* Mobile: position panel (right column) appears first */
	@media (max-width: 767px) {
		.command-center {
			padding-bottom: var(--space-16); /* Room for fixed nav */
		}

		.column-right {
			order: -1; /* Position panel first on mobile */
		}

		.column-left {
			order: 1;
		}
	}

	/* Tablet: 60/40 split */
	@media (min-width: 768px) {
		.content-grid {
			grid-template-columns: 3fr 2fr;
		}
	}

	/* Desktop: 2fr/1fr split (original layout) */
	@media (min-width: 1024px) {
		.content-grid {
			grid-template-columns: 2fr 1fr;
		}
	}

	/* ════════════════════════════════════════════════════════════════
	   MOBILE FEED COLLAPSIBLE
	   ════════════════════════════════════════════════════════════════ */

	.feed-wrapper {
		position: relative;
	}

	.feed-toggle {
		width: 100%;
		padding: var(--space-2) var(--space-3);
		margin-top: var(--space-1);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-default);
		color: var(--color-text-secondary);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		letter-spacing: var(--tracking-wide);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
		min-height: var(--touch-target-min); /* Accessible touch target */
	}

	.feed-toggle:hover {
		background: var(--color-bg-elevated);
		color: var(--color-accent);
		border-color: var(--color-accent-dim);
	}

	.feed-toggle:active {
		background: var(--color-bg-secondary);
	}

	/* ════════════════════════════════════════════════════════════════
	   MOBILE SPACING ADJUSTMENTS
	   ════════════════════════════════════════════════════════════════ */

	@media (max-width: 767px) {
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
