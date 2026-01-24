<script lang="ts">
	import { onMount } from 'svelte';
	import { Box, Shell } from '$lib/ui/terminal';
	import { Stack } from '$lib/ui/layout';
	import { Button } from '$lib/ui/primitives';
	import { wallet } from '$lib/web3/wallet.svelte';
	import { createDailyOpsProvider } from '$lib/features/daily/contractProvider.svelte';
	import StreakDisplay from '$lib/features/daily/StreakDisplay.svelte';
	import BadgeDisplay from '$lib/features/daily/BadgeDisplay.svelte';
	import ShieldPurchase from '$lib/features/daily/ShieldPurchase.svelte';
	import { formatTimeUntilReset } from '$lib/features/daily/contracts';

	// Create provider
	const provider = createDailyOpsProvider();

	// Time until reset (updates every second)
	let timeUntilReset = $state('--:--:--');
	let resetInterval: ReturnType<typeof setInterval> | null = null;

	onMount(() => {
		// Connect provider
		const disconnect = provider.connect();

		// Update reset timer
		const updateTimer = () => {
			timeUntilReset = formatTimeUntilReset();
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

	// Derived state from provider
	let streak = $derived(provider.state.streak);
	let badges = $derived(provider.state.badges);
	let shieldActive = $derived(provider.state.shieldActive);
	let balance = $derived(provider.state.balance ?? 0n);
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
</script>

<svelte:head>
	<title>DAILY OPS | GHOSTNET</title>
</svelte:head>

<Shell>
	<div class="daily-ops-page">
		<header class="page-header">
			<h1 class="page-title">DAILY OPS</h1>
			<p class="page-subtitle">Complete missions. Build your streak. Reduce your death rate.</p>
		</header>

		{#if !wallet.isConnected}
			<Box title="CONNECTION REQUIRED">
				<div class="connect-prompt">
					<p>Connect your wallet to view your daily progress.</p>
					<Button variant="primary" onclick={() => wallet.connect()}>CONNECT WALLET</Button>
				</div>
			</Box>
		{:else if !provider.state.isConnected}
			<Box title="LOADING">
				<div class="loading">
					<span class="loading-text">Connecting to contract...</span>
				</div>
			</Box>
		{:else}
			<div class="main-content">
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
								<span class="status-text">Mission claimed today!</span>
							</div>
						{:else}
							<div class="unclaimed-status">
								<span class="status-icon">!</span>
								<span class="status-text">Mission available - check the game!</span>
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

				<!-- Error Display -->
				{#if error}
					<div class="error-banner">
						<span class="error-icon">⚠</span>
						<span class="error-text">{error}</span>
					</div>
				{/if}
			</div>
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
	</div>
</Shell>

<style>
	.daily-ops-page {
		display: flex;
		flex-direction: column;
		gap: var(--space-6);
		max-width: 800px;
		margin: 0 auto;
		padding: var(--space-4);
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

	.main-content {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	.section {
		width: 100%;
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

	/* Mobile */
	@media (max-width: 640px) {
		.daily-ops-page {
			padding: var(--space-3);
		}

		.page-title {
			font-size: var(--text-2xl);
		}
	}
</style>
