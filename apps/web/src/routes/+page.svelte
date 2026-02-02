<script lang="ts">
	/**
	 * GHOSTNET Homepage - Progressive Disclosure
	 *
	 * Three modes based on user state:
	 * 1. No Wallet: LandingHero (simple pitch, connect wallet CTA)
	 * 2. Wallet, No Position: RiskSelector (choose risk level, jack in)
	 * 3. Has Position: Full Command Center (current complexity)
	 *
	 * The complexity is earned, not imposed.
	 */

	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { browser } from '$app/environment';

	// Layout components
	import { Header, KeyboardHints } from '$lib/features/header';
	import { NavigationBar } from '$lib/features/nav';
	import { Sidebar } from '$lib/features/sidebar';

	// Landing components (progressive disclosure)
	import { LandingHero, JackInFlow } from '$lib/features/landing';
	import { MatrixRain } from '$lib/features/welcome';

	// Command Center components (Mode 3: has position)
	import { FeedPanel } from '$lib/features/feed';
	import { PositionPanel, ModifiersPanel } from '$lib/features/position';
	import { NetworkVitalsPanel } from '$lib/features/network';
	import { GameNavigationCard } from '$lib/features/actions';
	import { DailyOpsPanel } from '$lib/features/daily';
	import { SwapPanel } from '$lib/features/swap';
	import { NetworkVisualizationPanel } from '$lib/ui/visualizations';

	// Modals
	import { IntroVideoModal } from '$lib/features/intro';
	import { JackInModal, ExtractModal, SettingsModal, WalletModal } from '$lib/features/modals';

	// UI components
	import { ToastContainer, getToasts } from '$lib/ui/toast';

	// State
	import { getProvider } from '$lib/core/stores/index.svelte';
	import {
		generateMockDailyState,
		simulateCheckIn,
		claimMission,
	} from '$lib/core/providers/mock/generators/daily';

	const provider = getProvider();
	const toast = getToasts();

	// ═══════════════════════════════════════════════════════════════
	// USER STATE - Determines which mode to show
	// ═══════════════════════════════════════════════════════════════

	// Derived state for progressive disclosure
	let userMode = $derived<'landing' | 'select-risk' | 'command-center'>(
		!provider.currentUser ? 'landing' : !provider.position ? 'select-risk' : 'command-center'
	);

	// ═══════════════════════════════════════════════════════════════
	// PAGE STATE
	// ═══════════════════════════════════════════════════════════════

	// Navigation state
	let activeNav = $state('network');

	// Daily Ops state
	let dailyState = $state(generateMockDailyState({ todayCheckedIn: false }));
	let checkingIn = $state(false);

	// Mobile detection
	let isMobile = $state(false);

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



	// ═══════════════════════════════════════════════════════════════
	// ACTION HANDLERS
	// ═══════════════════════════════════════════════════════════════

	function handleConnectWallet() {
		showWalletModal = true;
	}

	async function handleWalletConnected() {
		// Sync the mock provider with the real wallet connection
		// This triggers the transition from 'landing' to 'select-risk' mode
		await provider.connectWallet();
	}

	async function handleSkipToDemo() {
		// Skip directly to command center with a mock position
		// Connects wallet and creates a demo position in one step
		await provider.connectWallet();
		await provider.jackIn('SUBNET', 1000n * 10n ** 18n);
	}

	function handleJackIn() {
		showJackInModal = true;
	}

	function handleExtract() {
		showExtractModal = true;
	}

	function handleWatchFeed() {
		// Scroll to the feed panel (only visible in command center mode)
		const feedElement = document.querySelector('[data-feed-column]');
		if (feedElement) {
			feedElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
		}
	}

	function handleNavigate(id: string) {
		activeNav = id;
	}

	// Game navigation handlers
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

	// Daily Ops handlers
	async function handleDailyCheckIn() {
		if (dailyState.progress.todayCheckedIn) return;

		checkingIn = true;
		try {
			await new Promise((resolve) => setTimeout(resolve, 800));
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

	// ═══════════════════════════════════════════════════════════════
	// KEYBOARD SHORTCUTS
	// ═══════════════════════════════════════════════════════════════

	function handleKeydown(event: KeyboardEvent) {
		if (!event.shiftKey) return;
		if (event.target instanceof HTMLInputElement || event.target instanceof HTMLTextAreaElement) {
			return;
		}

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
	<title>GHOSTNET - Jack In. Don't Get Traced.</title>
	<meta
		name="description"
		content="Stake tokens. Survive the scan. Take the pot. Real-time survival game on MegaETH."
	/>
</svelte:head>

<svelte:window onkeydown={handleKeydown} />

<div class="page-container" data-mode={userMode}>
	<!-- Full-page Matrix Rain for landing mode -->
	{#if userMode === 'landing'}
		<div class="page-matrix-rain">
			<MatrixRain
				mode="grid"
				gridStep={1}
				columns={50}
				baseSpeed={5.5}
				trailOpacity={0.4}
				trailLength={15}
				generationMultiplier={0.46}
				fadeRate={0.1}
				brightHead={false}
				glow={true}
				glowRadius={24}
				headOpacity={0.5}
				headColor="#ffffff"
				color="#81e6f3"
				mutationRate={1}
				headMutationRate={1}
				targetFps={60}
			/>
		</div>
	{/if}

	<!-- Header is always visible -->
	<Header
		onSettings={() => (showSettingsModal = true)}
		onIntro={() => (showIntroVideo = true)}
		hideSettings={userMode === 'landing'}
	/>

	<!-- Sidebar only visible in command center mode -->
	{#if userMode === 'command-center'}
		<Sidebar
			onJackIn={handleJackIn}
			onExtract={handleExtract}
			onSettings={() => (showSettingsModal = true)}
			onWallet={handleConnectWallet}
		/>
		<KeyboardHints />
	{/if}

	<!-- ═══════════════════════════════════════════════════════════════
	     MODE 1: LANDING (No Wallet)
	     Simple pitch, connect wallet CTA
	     ═══════════════════════════════════════════════════════════════ -->
	{#if userMode === 'landing'}
		<main class="main-landing">
			<LandingHero
				onConnectWallet={handleConnectWallet}
				onSkip={handleSkipToDemo}
				playersOnline={provider.networkState.operatorsOnline}
				totalLocked="$4.8M"
				tracedToday={847}
			/>
		</main>

		<!-- ═══════════════════════════════════════════════════════════════
	     MODE 2: JACK IN FLOW (Wallet Connected, No Position)
	     Step-by-step: level selection → amount → confirm
	     ═══════════════════════════════════════════════════════════════ -->
	{:else if userMode === 'select-risk'}
		<main class="main-jack-in">
			<JackInFlow onSkip={handleSkipToDemo} />
		</main>

		<!-- ═══════════════════════════════════════════════════════════════
	     MODE 3: COMMAND CENTER (Has Position)
	     Full complexity - for invested users
	     ═══════════════════════════════════════════════════════════════ -->
	{:else}
		<main class="main-command-center">
			<div class="content-grid">
				<!-- Left Column: Feed, Arcade, Visualization -->
				<div class="column column-left" data-feed-column>
					<FeedPanel
						collapsedCount={isMobile ? 4 : 6}
						expandedCount={isMobile ? 12 : 20}
						collapsedHeight={isMobile ? '100px' : '140px'}
						expandedHeight={isMobile ? '300px' : '400px'}
					/>

					<GameNavigationCard />

					<div class="hide-mobile">
						<NetworkVisualizationPanel operatorCount={provider.networkState.operatorsOnline} />
					</div>
				</div>

				<!-- Right Column: Position, Stats, Actions -->
				<div class="column column-right">
					<PositionPanel />
					<SwapPanel />
					<ModifiersPanel />
					<DailyOpsPanel
						progress={dailyState.progress}
						missions={dailyState.missions}
						onCheckIn={handleDailyCheckIn}
						onClaimMission={handleClaimMission}
						{checkingIn}
					/>
					<div class="hide-mobile">
						<NetworkVitalsPanel />
					</div>
				</div>
			</div>
		</main>
	{/if}

	<!-- Navigation bar (hidden on landing) -->
	{#if userMode !== 'landing'}
		<NavigationBar active={activeNav} onNavigate={handleNavigate} />
	{/if}
</div>

<!-- Modals -->
<JackInModal open={showJackInModal} onclose={() => (showJackInModal = false)} />
<ExtractModal open={showExtractModal} onclose={() => (showExtractModal = false)} />
<SettingsModal open={showSettingsModal} onclose={() => (showSettingsModal = false)} />
<WalletModal
	open={showWalletModal}
	onclose={() => (showWalletModal = false)}
	onConnected={handleWalletConnected}
/>
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
	.page-container {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
		padding-bottom: var(--space-16); /* Room for fixed nav */
	}

	/* Full-page Matrix Rain background */
	.page-matrix-rain {
		position: fixed;
		inset: 0;
		z-index: 0;
		pointer-events: none;
	}

	.page-matrix-rain :global(.matrix-rain) {
		filter: blur(0.7px);
	}

	/* ═══════════════════════════════════════════════════════════════
	   MODE 1: LANDING
	   Full-page takeover, centered content
	   ═══════════════════════════════════════════════════════════════ */

	.main-landing {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		padding-bottom: 10vh; /* Push content slightly above center */
	}

	/* ═══════════════════════════════════════════════════════════════
	   MODE 2: JACK IN FLOW
	   Centered, focused experience
	   ═══════════════════════════════════════════════════════════════ */

	.main-jack-in {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: var(--space-4);
	}

	/* ═══════════════════════════════════════════════════════════════
	   MODE 3: COMMAND CENTER
	   Full complexity, two-column layout
	   ═══════════════════════════════════════════════════════════════ */

	.main-command-center {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		padding: var(--space-4) var(--space-6);
		width: 100%;
		max-width: 1200px;
		margin: 0 auto;
	}

	/* Make room for sidebar on desktop */
	@media (min-width: 1024px) {
		.page-container[data-mode='command-center'] .main-command-center {
			padding-left: calc(var(--space-6) + 60px);
		}
	}

	/* ═══════════════════════════════════════════════════════════════
	   RESPONSIVE GRID (Command Center only)
	   ═══════════════════════════════════════════════════════════════ */

	.content-grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: var(--space-4);
		height: 100%;
	}

	.column {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		min-width: 0;
	}

	/* Mobile: position panel first */
	@media (max-width: 767px) {
		.column-right {
			order: -1;
		}

		.column-left {
			order: 1;
		}

		.main-command-center {
			padding: var(--space-2);
		}

		.content-grid {
			gap: var(--space-2);
		}

		.column {
			gap: var(--space-2);
		}
	}

	/* Tablet: 60/40 split */
	@media (min-width: 768px) {
		.content-grid {
			grid-template-columns: 3fr 2fr;
		}
	}

	/* Desktop: 2fr/1fr split */
	@media (min-width: 1024px) {
		.content-grid {
			grid-template-columns: 2fr 1fr;
		}
	}

	/* ═══════════════════════════════════════════════════════════════
	   UTILITY CLASSES
	   ═══════════════════════════════════════════════════════════════ */

	.hide-mobile {
		display: block;
	}

	@media (max-width: 767px) {
		.hide-mobile {
			display: none;
		}
	}
</style>
