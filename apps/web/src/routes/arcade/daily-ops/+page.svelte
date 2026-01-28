<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { NavigationBar } from '$lib/features/nav';
	import { Header, Breadcrumb } from '$lib/features/header';
	import { Box, Shell } from '$lib/ui/terminal';
	import { Stack } from '$lib/ui/layout';
	import { Button } from '$lib/ui/primitives';
	import { wallet } from '$lib/web3/wallet.svelte';
	import { createDailyOpsProvider } from '$lib/features/daily/contractProvider.svelte';
	import { createMockDailyOpsProvider } from '$lib/features/daily/mockProvider.svelte';
	import StreakDisplay from '$lib/features/daily/StreakDisplay.svelte';
	import BadgeDisplay from '$lib/features/daily/BadgeDisplay.svelte';
	import ShieldPurchase from '$lib/features/daily/ShieldPurchase.svelte';
	import MissionCard from '$lib/features/daily/MissionCard.svelte';
	import StreakCalendar from '$lib/features/daily/StreakCalendar.svelte';
	import type { DailyMission } from '$lib/core/types/daily';

	// Check for mock mode from URL params
	let isMockMode = $derived($page.url.searchParams.get('mock') === 'true');

	// Parse mock options from URL
	let mockOptions = $derived.by(() => {
		if (!isMockMode) return {};
		const params = $page.url.searchParams;
		return {
			streak: params.has('streak') ? parseInt(params.get('streak')!, 10) : undefined,
			claimed: params.get('claimed') === 'true',
			shield: params.has('shield') ? parseInt(params.get('shield')!, 10) : undefined,
			badges: params.has('badges') ? parseInt(params.get('badges')!, 10) : undefined,
			missions: params.has('missions') ? parseInt(params.get('missions')!, 10) : undefined,
		};
	});

	// Create provider (mock or real based on URL param)
	const realProvider = createDailyOpsProvider();
	let mockProvider = $state<ReturnType<typeof createMockDailyOpsProvider> | null>(null);

	// Initialize mock provider when options change
	$effect(() => {
		if (isMockMode) {
			mockProvider = createMockDailyOpsProvider(mockOptions);
		}
	});

	// Use the appropriate provider
	let provider = $derived(isMockMode && mockProvider ? mockProvider : realProvider);

	// Time until reset (updates every second)
	let timeUntilReset = $state('--:--:--');
	let resetInterval: ReturnType<typeof setInterval> | null = null;

	// Calculate time until next day reset (UTC midnight)
	function getTimeUntilReset(): number {
		const now = Date.now();
		const nextDayStart = (Math.floor(now / 86400000) + 1) * 86400000;
		return nextDayStart - now;
	}

	// Format time as HH:MM:SS
	function formatTime(ms: number): string {
		const hours = Math.floor(ms / 3600000);
		const minutes = Math.floor((ms % 3600000) / 60000);
		const seconds = Math.floor((ms % 60000) / 1000);
		return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
	}

	onMount(() => {
		// Connect provider (mock connects instantly)
		const disconnect = provider.connect();

		// Update reset timer
		const updateTimer = () => {
			timeUntilReset = formatTime(getTimeUntilReset());
		};
		updateTimer();
		resetInterval = setInterval(updateTimer, 1000);

		return () => {
			disconnect();
			if (resetInterval) clearInterval(resetInterval);
		};
	});

	// Handle shield purchase
	async function handlePurchaseShield(days: 1 | 7) {
		try {
			await provider.buyShield(days);
		} catch (err) {
			console.error('Failed to purchase shield:', err);
		}
	}

	// Handle mission claim (mock only for now)
	async function handleClaimMission(missionId: string) {
		if (isMockMode && mockProvider) {
			try {
				// Access the mock-specific method
				const mp = mockProvider as { claimMissionReward?: (id: string) => Promise<void> };
				if (mp.claimMissionReward) {
					await mp.claimMissionReward(missionId);
				}
			} catch (err) {
				console.error('Failed to claim mission:', err);
			}
		}
	}

	// Derived state from provider
	let streak = $derived(provider.state.streak);
	let badges = $derived(provider.state.badges);
	let shieldActive = $derived(provider.state.shieldActive);
	// Balance exists on DailyOpsState
	let balance = $derived('balance' in provider.state ? (provider.state.balance as bigint) : 0n);
	let isLoading = $derived(provider.state.isLoading);
	let error = $derived(provider.state.error);
	let nextMilestone = $derived(provider.nextMilestone);
	let milestoneProgress = $derived(provider.milestoneProgress);
	let shieldExpiry = $derived(provider.shieldExpiryFormatted);
	let canPurchaseShield = $derived(provider.canPurchaseShield);
	let shieldDaysRemaining = $derived.by(() => {
		if (!streak || streak.shieldExpiryDay === 0n) return undefined;
		const remaining = Number(streak.shieldExpiryDay) - Number(provider.state.currentDay);
		return remaining > 0 ? remaining : undefined;
	});

	// Mock-only: missions and calendar data
	let missions = $derived<DailyMission[]>(
		isMockMode && mockProvider && 'missions' in mockProvider
			? (mockProvider.missions as DailyMission[])
			: []
	);
	let completedDays = $derived<Set<number>>(
		isMockMode && mockProvider && 'completedDays' in mockProvider
			? (mockProvider.completedDays as Set<number>)
			: new Set<number>()
	);
	let streakStartDay = $derived<number>(
		isMockMode && mockProvider && 'streakStartDay' in mockProvider
			? (mockProvider.streakStartDay as number)
			: 0
	);
	let currentDayNum = $derived(Number(provider.state.currentDay));

	// Count missions with explicit types
	let completedMissionCount = $derived(missions.filter((m: DailyMission) => m.completed).length);
	let claimableMissionCount = $derived(
		missions.filter((m: DailyMission) => m.completed && !m.claimed).length
	);

	// Check if we should show the main content
	let showContent = $derived(isMockMode || (wallet.isConnected && provider.state.isConnected));

	// Tab state for mobile
	let activeTab = $state<'overview' | 'missions' | 'calendar'>('overview');
</script>

<svelte:head>
	<title>DAILY OPS | GHOSTNET</title>
</svelte:head>

<Header />
<Breadcrumb
	path={[
		{ label: 'NETWORK', href: '/' },
		{ label: 'ARCADE', href: '/arcade' },
		{ label: 'DAILY OPS' },
	]}
/>

<Shell>
	<div class="daily-ops-page">
		<header class="page-header">
			<h1 class="page-title">DAILY OPS</h1>
			<p class="page-subtitle">Complete missions. Build your streak. Reduce your death rate.</p>
			{#if isMockMode}
				<div class="mock-banner">
					<span class="mock-icon">⚠</span>
					<span class="mock-text">MOCK MODE - Using simulated data</span>
				</div>
			{/if}
		</header>

		{#if !isMockMode && !wallet.isConnected}
			<Box title="CONNECTION REQUIRED">
				<div class="connect-prompt">
					<p>Connect your wallet to view your daily progress.</p>
					<Button variant="primary" onclick={() => wallet.connect()}>CONNECT WALLET</Button>
					<p class="mock-hint">
						Or try <a href="?mock=true">mock mode</a> to preview the UI
					</p>
				</div>
			</Box>
		{:else if !showContent}
			<Box title="LOADING">
				<div class="loading">
					<span class="loading-text">Connecting to contract...</span>
				</div>
			</Box>
		{:else}
			<!-- Tab Navigation (Mobile) -->
			<nav class="tab-nav">
				<button
					class="tab-btn"
					class:active={activeTab === 'overview'}
					onclick={() => (activeTab = 'overview')}
				>
					OVERVIEW
				</button>
				<button
					class="tab-btn"
					class:active={activeTab === 'missions'}
					onclick={() => (activeTab = 'missions')}
				>
					MISSIONS
					{#if claimableMissionCount > 0}
						<span class="tab-badge">{claimableMissionCount}</span>
					{/if}
				</button>
				<button
					class="tab-btn"
					class:active={activeTab === 'calendar'}
					onclick={() => (activeTab = 'calendar')}
				>
					CALENDAR
				</button>
			</nav>

			<div class="main-content">
				<!-- Overview Tab / Desktop Left Column -->
				<div class="content-column overview-column" class:hidden={activeTab !== 'overview'}>
					<!-- Streak Display -->
					<section class="section streak-section">
						<StreakDisplay
							currentStreak={streak?.currentStreak ?? 0}
							longestStreak={streak?.longestStreak ?? 0}
							deathRateReduction={provider.state.deathRateReduction}
							{shieldActive}
							{shieldDaysRemaining}
							{nextMilestone}
							{milestoneProgress}
						/>
					</section>

					<!-- Reset Timer -->
					<section class="section reset-section">
						<Box title="DAILY RESET">
							<div class="reset-timer">
								<span class="reset-label">Next reset in</span>
								<span class="reset-time">{timeUntilReset}</span>
							</div>
							{#if provider.state.hasClaimedToday}
								<div class="claimed-status">
									<span class="status-icon">✓</span>
									<span class="status-text">Missions claimed today!</span>
								</div>
							{:else}
								<div class="unclaimed-status">
									<span class="status-icon">!</span>
									<span class="status-text">
										{claimableMissionCount > 0
											? `${claimableMissionCount} mission(s) ready to claim!`
											: 'Complete missions to earn rewards'}
									</span>
								</div>
							{/if}
						</Box>
					</section>

					<!-- Shield Purchase -->
					<section class="section shield-section">
						<ShieldPurchase
							{shieldActive}
							{shieldExpiry}
							canPurchase={canPurchaseShield}
							{balance}
							isPurchasing={isLoading}
							onPurchase={handlePurchaseShield}
						/>
					</section>

					<!-- Badges -->
					<section class="section badges-section">
						<Box title="ACHIEVEMENTS">
							<BadgeDisplay {badges} showAll />
						</Box>
					</section>
				</div>

				<!-- Missions + Calendar / Desktop Right Column -->
				<div class="content-column missions-column" class:hidden={activeTab !== 'missions'}>
					<section class="section missions-section">
						<Box title="TODAY'S MISSIONS">
							<div class="missions-header">
								<span class="missions-count">
									{completedMissionCount}/{missions.length} completed
								</span>
								{#if claimableMissionCount > 0}
									<span class="claimable-badge">{claimableMissionCount} CLAIMABLE</span>
								{/if}
							</div>

							<Stack gap={2}>
								{#each missions as mission (mission.id)}
									<MissionCard {mission} onClaim={handleClaimMission} />
								{/each}

								{#if missions.length === 0}
									<div class="no-missions">
										<p>No missions available.</p>
										<p class="hint">
											{#if isMockMode}
												Add <code>?missions=3</code> to URL to see missions
											{:else}
												Missions are assigned daily at UTC midnight
											{/if}
										</p>
									</div>
								{/if}
							</Stack>
						</Box>
					</section>

					<!-- Calendar below missions on desktop, separate tab on mobile -->
					<section class="section calendar-section desktop-only">
						<Box title="STREAK CALENDAR">
							<StreakCalendar {completedDays} currentDay={currentDayNum} {streakStartDay} />
						</Box>
					</section>
				</div>

				<!-- Calendar Tab (Mobile only) -->
				<div
					class="content-column calendar-column mobile-only"
					class:hidden={activeTab !== 'calendar'}
				>
					<section class="section">
						<Box title="STREAK CALENDAR">
							<StreakCalendar {completedDays} currentDay={currentDayNum} {streakStartDay} />
						</Box>
					</section>
				</div>
			</div>

			<!-- Error Display -->
			{#if error}
				<div class="error-banner">
					<span class="error-icon">⚠</span>
					<span class="error-text">{error}</span>
				</div>
			{/if}
		{/if}

		<!-- Info Section -->
		<section class="info-section">
			<Box title="HOW IT WORKS">
				<Stack gap={3}>
					<div class="info-item">
						<span class="info-icon">1</span>
						<div class="info-text">
							<strong>Complete missions</strong> - Play games and hit objectives to earn daily rewards
						</div>
					</div>
					<div class="info-item">
						<span class="info-icon">2</span>
						<div class="info-text">
							<strong>Build your streak</strong> - Claim rewards on consecutive days to grow your streak
						</div>
					</div>
					<div class="info-item">
						<span class="info-icon">3</span>
						<div class="info-text">
							<strong>Reduce death rate</strong> - Higher streaks = lower chance of getting traced
						</div>
					</div>
					<div class="info-item">
						<span class="info-icon">4</span>
						<div class="info-text">
							<strong>Use shields</strong> - Protect your streak if you need to miss a day
						</div>
					</div>
				</Stack>
			</Box>
		</section>

		<!-- Mock Mode Instructions (only shown in mock mode) -->
		{#if isMockMode}
			<section class="info-section">
				<Box title="MOCK MODE OPTIONS">
					<Stack gap={2}>
						<p class="mock-instructions">Customize the mock data via URL parameters:</p>
						<ul class="mock-params">
							<li><code>?mock=true&streak=45</code> - Set streak to 45 days</li>
							<li><code>?mock=true&claimed=true</code> - Mark missions as claimed</li>
							<li><code>?mock=true&shield=3</code> - Set 3 days of shield</li>
							<li><code>?mock=true&badges=2</code> - Show 2 badges</li>
							<li><code>?mock=true&missions=3</code> - Show 3 missions</li>
						</ul>
						<div class="mock-examples">
							<a href="?mock=true&streak=5&missions=2">New Player</a>
							<a href="?mock=true&streak=25&badges=1&missions=3">Week Warrior</a>
							<a href="?mock=true&streak=45&badges=2&shield=5&missions=3">Dedicated Operator</a>
							<a href="?mock=true&streak=100&badges=3&claimed=true&missions=3">Legend</a>
						</div>
					</Stack>
				</Box>
			</section>
		{/if}
	</div>
</Shell>
<NavigationBar active="arcade" />

<style>
	.daily-ops-page {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		max-width: 1000px;
		margin: 0 auto;
		padding: var(--space-4);
		padding-bottom: var(--space-16);
	}

	.page-header {
		text-align: center;
	}

	.page-title {
		font-size: var(--text-3xl);
		font-weight: var(--font-bold);
		color: var(--color-accent);
		letter-spacing: var(--tracking-wider);
		margin: 0;
	}

	.page-subtitle {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		margin: var(--space-2) 0 0;
	}

	/* Mock mode banner */
	.mock-banner {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		margin-top: var(--space-3);
		padding: var(--space-2) var(--space-4);
		background: rgba(255, 193, 7, 0.15);
		border: 1px solid var(--color-warning);
	}

	.mock-icon {
		color: var(--color-warning);
	}

	.mock-text {
		font-size: var(--text-xs);
		color: var(--color-warning);
		letter-spacing: var(--tracking-wide);
	}

	/* Tab Navigation */
	.tab-nav {
		display: none;
		gap: var(--space-1);
		border-bottom: 1px solid var(--color-border-subtle);
		padding-bottom: var(--space-2);
	}

	.tab-btn {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-1);
		padding: var(--space-2);
		background: transparent;
		border: 1px solid var(--color-border-subtle);
		color: var(--color-text-secondary);
		font-size: var(--text-xs);
		font-family: var(--font-mono);
		letter-spacing: var(--tracking-wide);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.tab-btn:hover {
		border-color: var(--color-border-default);
		color: var(--color-text-primary);
	}

	.tab-btn.active {
		border-color: var(--color-accent);
		color: var(--color-accent);
		background: var(--color-accent-glow);
	}

	.tab-badge {
		background: var(--color-accent);
		color: var(--color-bg-primary);
		padding: 0 var(--space-1);
		font-size: var(--text-2xs);
		font-weight: var(--font-bold);
	}

	.connect-prompt {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-4);
		padding: var(--space-6);
		text-align: center;
	}

	.connect-prompt p {
		color: var(--color-text-secondary);
	}

	.mock-hint {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
	}

	.mock-hint a {
		color: var(--color-accent);
		text-decoration: underline;
	}

	.loading {
		display: flex;
		justify-content: center;
		padding: var(--space-6);
	}

	.loading-text {
		color: var(--color-text-tertiary);
		animation: pulse 2s ease-in-out infinite;
	}

	@keyframes pulse {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.5;
		}
	}

	/* Main Content - Desktop: 2 columns, Mobile: tabs */
	.main-content {
		display: grid;
		grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
		gap: var(--space-4);
		align-items: start; /* Don't stretch columns to match heights */
	}

	.content-column {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		min-width: 0; /* Allow shrinking below content size */
	}

	/* Desktop/Mobile visibility */
	.desktop-only {
		display: block;
	}

	.mobile-only {
		display: none;
	}

	/* Reset section */
	.reset-timer {
		display: flex;
		justify-content: center;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-3);
	}

	.reset-label {
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
	}

	.reset-time {
		font-size: var(--text-xl);
		font-family: var(--font-mono);
		color: var(--color-accent);
		font-weight: var(--font-medium);
	}

	.claimed-status,
	.unclaimed-status {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		padding: var(--space-2);
		margin-top: var(--space-2);
	}

	.claimed-status {
		background: rgba(0, 255, 136, 0.1);
		border: 1px solid var(--color-success);
	}

	.claimed-status .status-icon {
		color: var(--color-success);
	}

	.claimed-status .status-text {
		color: var(--color-success);
		font-size: var(--text-sm);
	}

	.unclaimed-status {
		background: rgba(255, 193, 7, 0.1);
		border: 1px solid var(--color-warning);
	}

	.unclaimed-status .status-icon {
		color: var(--color-warning);
	}

	.unclaimed-status .status-text {
		color: var(--color-warning);
		font-size: var(--text-sm);
	}

	/* Error banner */
	.error-banner {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-3);
		background: rgba(255, 0, 0, 0.1);
		border: 1px solid var(--color-danger);
	}

	.error-icon {
		color: var(--color-danger);
	}

	.error-text {
		color: var(--color-danger);
		font-size: var(--text-sm);
	}

	/* Info section */
	.info-section {
		margin-top: var(--space-4);
	}

	.info-item {
		display: flex;
		align-items: flex-start;
		gap: var(--space-3);
	}

	.info-icon {
		width: 24px;
		height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: var(--color-accent);
		color: var(--color-bg-primary);
		font-size: var(--text-xs);
		font-weight: var(--font-bold);
		flex-shrink: 0;
	}

	.info-text {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		line-height: 1.5;
	}

	.info-text strong {
		color: var(--color-text-primary);
	}

	/* Mock mode instructions */
	.mock-instructions {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		margin: 0;
	}

	.mock-params {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		list-style: none;
		padding: 0;
		margin: 0;
	}

	.mock-params li {
		margin: var(--space-1) 0;
	}

	.mock-params code {
		background: var(--color-bg-tertiary);
		padding: var(--space-0-5) var(--space-1);
		font-family: var(--font-mono);
		color: var(--color-accent);
	}

	.mock-examples {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
		margin-top: var(--space-2);
	}

	.mock-examples a {
		font-size: var(--text-xs);
		color: var(--color-accent);
		background: var(--color-bg-tertiary);
		padding: var(--space-1) var(--space-2);
		text-decoration: none;
		border: 1px solid var(--color-border-default);
	}

	.mock-examples a:hover {
		background: var(--color-bg-hover);
		border-color: var(--color-accent);
	}

	/* Mobile */
	@media (max-width: 768px) {
		.daily-ops-page {
			padding: var(--space-3);
		}

		.page-title {
			font-size: var(--text-2xl);
		}

		.tab-nav {
			display: flex;
		}

		.main-content {
			display: block;
		}

		.content-column.hidden {
			display: none;
		}

		/* Flip visibility for mobile */
		.desktop-only {
			display: none;
		}

		.mobile-only {
			display: block;
		}
	}
</style>
