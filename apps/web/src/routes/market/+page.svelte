<script lang="ts">
	import { goto } from '$app/navigation';
	import { Header } from '$lib/features/header';
	import { NavigationBar } from '$lib/features/nav';
	import { DeadPoolHeader, ActiveRoundsGrid, ResultsPanel, BetModal } from '$lib/features/deadpool';
	import { ToastContainer, getToasts } from '$lib/ui/toast';
	import { Stack } from '$lib/ui/layout';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import {
		generateActiveRounds,
		generateMockHistoryList,
		generateUserStats,
		updatePoolsWithBet,
	} from '$lib/core/providers/mock/generators/deadpool';
	import type {
		DeadPoolRound,
		DeadPoolSide,
		DeadPoolHistory,
		DeadPoolUserStats,
	} from '$lib/core/types';

	const provider = getProvider();
	const toast = getToasts();

	// Navigation state
	let activeNav = $state('pool');

	// Dead Pool state - load mock data
	let rounds = $state<DeadPoolRound[]>(generateActiveRounds());
	let history = $state<DeadPoolHistory[]>(generateMockHistoryList(10));
	let userStats = $state<DeadPoolUserStats>(generateUserStats());

	// Modal state
	let showBetModal = $state(false);
	let selectedRound = $state<DeadPoolRound | null>(null);
	let selectedSide = $state<DeadPoolSide | null>(null);

	// User balance (from provider or mock)
	let userBalance = $derived(provider.currentUser?.tokenBalance ?? 1000n * 10n ** 18n);

	// Handlers
	function handleBet(round: DeadPoolRound, side: DeadPoolSide) {
		if (!provider.currentUser) {
			toast.warning('Connect wallet to place bets');
			return;
		}

		selectedRound = round;
		selectedSide = side;
		showBetModal = true;
	}

	function handleConfirmBet(amount: bigint) {
		if (!selectedRound || !selectedSide) return;

		// Update round with user's bet
		const roundIndex = rounds.findIndex((r) => r.id === selectedRound!.id);
		if (roundIndex !== -1) {
			rounds[roundIndex] = {
				...rounds[roundIndex],
				pools: updatePoolsWithBet(rounds[roundIndex].pools, selectedSide!, amount),
				userBet: {
					side: selectedSide!,
					amount,
					timestamp: Date.now(),
				},
			};
		}

		toast.success(
			`Bet placed: ${(Number(amount) / 1e18).toFixed(2)} Đ on ${selectedSide!.toUpperCase()}`
		);
		showBetModal = false;
		selectedRound = null;
		selectedSide = null;
	}

	function handleCloseBetModal() {
		showBetModal = false;
		selectedRound = null;
		selectedSide = null;
	}

	function handleNavigate(id: string) {
		activeNav = id;
		if (id === 'network') {
			goto('/');
		}
	}

	function handleHelp() {
		toast.info('Dead Pool: Bet on network outcomes. Parimutuel odds, 5% rake burned.');
	}

	// Simulate pool updates every 5 seconds
	$effect(() => {
		const interval = setInterval(() => {
			rounds = rounds.map((round) => {
				if (round.userBet) return round; // Don't update rounds user has bet on

				// Random small pool changes
				const underChange =
					Math.random() < 0.3 ? BigInt(Math.floor(Math.random() * 20)) * 10n ** 18n : 0n;
				const overChange =
					Math.random() < 0.3 ? BigInt(Math.floor(Math.random() * 20)) * 10n ** 18n : 0n;

				return {
					...round,
					pools: {
						under: round.pools.under + underChange,
						over: round.pools.over + overChange,
					},
				};
			});
		}, 5000);

		return () => clearInterval(interval);
	});
</script>

<svelte:head>
	<title>GHOSTNET - Dead Pool</title>
	<meta name="description" content="Dead Pool prediction markets. Bet on network outcomes." />
</svelte:head>

<div class="deadpool-page">
	<Header />

	<main class="main-content">
		<Stack gap={4}>
			<DeadPoolHeader balance={userBalance} stats={userStats} onHelp={handleHelp} />

			<section class="section">
				<h2 class="section-title">ACTIVE ROUNDS</h2>
				<ActiveRoundsGrid {rounds} onBet={handleBet} />
			</section>

			<section class="section">
				<ResultsPanel {history} maxItems={5} />
			</section>
		</Stack>
	</main>

	<NavigationBar active={activeNav} onNavigate={handleNavigate} />
</div>

<!-- Bet Modal -->
<BetModal
	open={showBetModal}
	round={selectedRound}
	side={selectedSide}
	balance={userBalance}
	onclose={handleCloseBetModal}
	onConfirm={handleConfirmBet}
/>

<!-- Toast notifications -->
<ToastContainer />

<style>
	.deadpool-page {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
		padding-bottom: var(--space-16); /* Room for fixed nav */
	}

	.main-content {
		flex: 1;
		padding: var(--space-4) var(--space-6);
		width: 100%;
		max-width: 1200px;
		margin: 0 auto;
	}

	.section {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.section-title {
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-widest);
		border-bottom: 1px solid var(--color-border-subtle);
		padding-bottom: var(--space-2);
	}

	@media (max-width: 767px) {
		.main-content {
			padding: var(--space-2);
		}
	}
</style>
