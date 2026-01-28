<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { Header, KeyboardHints } from '$lib/features/header';
	import { FeedPanel } from '$lib/features/feed';
	import { PositionPanel, ModifiersPanel } from '$lib/features/position';
	import { NetworkVitalsPanel } from '$lib/features/network';
	import { QuickActionsPanel, GameNavigationCard } from '$lib/features/actions';
	import { NavigationBar } from '$lib/features/nav';
	import { WelcomePanel } from '$lib/features/welcome';
	import { IntroVideoModal } from '$lib/features/intro';
	import { JackInModal, ExtractModal, SettingsModal } from '$lib/features/modals';

	import { DailyOpsPanel } from '$lib/features/daily';
	import { GettingStartedPanel } from '$lib/features/getting-started';
	import { WalletModal } from '$lib/features/modals';
	import { SwapPanel } from '$lib/features/swap';
	import { ToastContainer, getToasts } from '$lib/ui/toast';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import { NetworkVisualizationPanel } from '$lib/ui/visualizations';
	import {
		generateMockDailyState,
		simulateCheckIn,
		claimMission,
	} from '$lib/core/providers/mock/generators/daily';

	import { browser } from '$app/environment';

	const provider = getProvider();
	const toast = getToasts();

	// Navigation state
	let activeNav = $state('network');

	// Daily Ops state - initialize with mock data
	let dailyState = $state(generateMockDailyState({ todayCheckedIn: false }));
	let checkingIn = $state(false);

	// Mobile detection for responsive behavior
	let isMobile = $state(false);

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
	let showWalletModal = $state(false);
	let showIntroVideo = $state(
		browser ? localStorage.getItem('ghostnet_intro_seen') !== 'true' : false
	);

	// Action handlers
	function handleJackIn() {
		showJackInModal = true;
	}

	function handleExtract() {
		showExtractModal = true;
	}

	function handleTraceEvasion() {
		goto(resolve('/typing'));
	}

	function handleHackRun() {
		goto(resolve('/games/hackrun'));
	}

	function handleDuels() {
		goto(resolve('/games/duels'));
	}

	function handleCrew() {
		goto(resolve('/crew'));
	}

	function handleDeadPool() {
		goto(resolve('/deadpool'));
	}

	function handleWatchFeed() {
		// Scroll to the feed panel smoothly
		const feedElement = document.querySelector('[data-feed-column]');
		if (feedElement) {
			feedElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
		}
	}

	function handleConnectWallet() {
		showWalletModal = true;
	}

	function handleNavigate(id: string) {
		activeNav = id;
	}

	// Daily Ops handlers
	async function handleDailyCheckIn() {
		if (dailyState.progress.todayCheckedIn) return;

		checkingIn = true;
		try {
			// Simulate network delay
			await new Promise((resolve) => setTimeout(resolve, 800));

			// Update state
			dailyState = {
				...dailyState,
				progress: simulateCheckIn(dailyState.progress),
			};

			toast.success(`Day ${dailyState.progress.currentStreak} reward claimed!`);
		} catch (error) {
			const message = error instanceof Error ? error.message : 'Check-in failed';
			toast.error(message);
		} finally {
			checkingIn = false;
		}
	}

	function handleClaimMission(missionId: string) {
		const mission = dailyState.missions.find((m) => m.id === missionId);
		if (!mission || !mission.completed || mission.claimed) return;

		try {
			// Update mission state
			dailyState = {
				...dailyState,
				missions: dailyState.missions.map((m) => (m.id === missionId ? claimMission(m) : m)),
			};

			toast.success(
				`Mission reward claimed: ${mission.reward.type === 'tokens' ? `+${mission.reward.value} $DATA` : mission.title}`
			);
		} catch (error) {
			const message = error instanceof Error ? error.message : 'Failed to claim mission';
			toast.error(message);
		}
	}

	// Keyboard shortcuts (SHIFT + key)
	function handleKeydown(event: KeyboardEvent) {
		// Require SHIFT modifier for all shortcuts
		if (!event.shiftKey) return;

		// Ignore if user is typing in an input
		if (event.target instanceof HTMLInputElement || event.target instanceof HTMLTextAreaElement) {
			return;
		}

		// Prevent default browser behavior for our shortcuts
		const key = event.key.toLowerCase();
		if (['j', 'e', 't', 'h', 'c', 'p'].includes(key)) {
			event.preventDefault();
		}

		switch (key) {
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
			case 'd':
				if (!provider.currentUser) {
					toast.warning('Connect wallet first');
				} else if (!provider.position) {
					toast.warning('Jack In first to play Duels');
				} else {
					handleDuels();
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
	<Header onSettings={() => (showSettingsModal = true)} onIntro={() => (showIntroVideo = true)} />
	<KeyboardHints />

	<main class="main-content">
		<div class="content-grid">
			<!-- Left Column: Welcome, Feed, Arcade & Visualization -->
			<div class="column column-left" data-feed-column>
				<!-- Welcome panel (network initialization): hidden on mobile -->
				<div class="hide-mobile">
					<WelcomePanel onJackIn={handleJackIn} onWatchFeed={handleWatchFeed} />
				</div>

				<!-- Live Feed with built-in expand/collapse -->
				<FeedPanel
					collapsedCount={isMobile ? 4 : 6}
					expandedCount={isMobile ? 12 : 20}
					collapsedHeight={isMobile ? '100px' : '140px'}
					expandedHeight={isMobile ? '300px' : '400px'}
				/>

				<!-- Arcade navigation card -->
				<GameNavigationCard />

				<!-- Network Visualization: hidden on mobile (too heavy) -->
				<div class="hide-mobile">
					<NetworkVisualizationPanel operatorCount={provider.networkState.operatorsOnline} />
				</div>
			</div>

			<!-- Right Column: Position, Network Stats, Actions -->
			<div class="column column-right">
				<PositionPanel />
				<SwapPanel />
				<ModifiersPanel />
				<!-- Getting Started replaces Daily Ops when wallet not connected -->
				{#if provider.currentUser}
					<DailyOpsPanel
						progress={dailyState.progress}
						missions={dailyState.missions}
						onCheckIn={handleDailyCheckIn}
						onClaimMission={handleClaimMission}
						{checkingIn}
					/>
				{:else}
					<GettingStartedPanel onConnectWallet={handleConnectWallet} />
				{/if}
				<!-- Network Vitals: hidden on mobile (accessible via nav) -->
				<div class="hide-mobile">
					<NetworkVitalsPanel />
				</div>
				<QuickActionsPanel
					onJackIn={handleJackIn}
					onExtract={handleExtract}
					onTraceEvasion={handleTraceEvasion}
					onHackRun={handleHackRun}
					onDuels={handleDuels}
					onCrew={handleCrew}
					onDeadPool={handleDeadPool}
				/>
				<!-- FAQPanel hidden for now -->
			</div>
		</div>
	</main>

	<NavigationBar active={activeNav} onNavigate={handleNavigate} />
</div>

<!-- Modals -->
<JackInModal open={showJackInModal} onclose={() => (showJackInModal = false)} />
<ExtractModal open={showExtractModal} onclose={() => (showExtractModal = false)} />
<SettingsModal open={showSettingsModal} onclose={() => (showSettingsModal = false)} />
<WalletModal open={showWalletModal} onclose={() => (showWalletModal = false)} />
<IntroVideoModal
	open={showIntroVideo}
	onclose={() => {
		showIntroVideo = false;
		if (browser) localStorage.setItem('ghostnet_intro_seen', 'true');
	}}
/>

<!-- Toast notifications -->
<ToastContainer />

<style>
	.command-center {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
		padding-bottom: var(--space-16); /* Room for fixed nav */
	}

	.main-content {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
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
