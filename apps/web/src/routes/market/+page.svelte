<script lang="ts">
	import { goto } from '$app/navigation';
	import { Header } from '$lib/features/header';
	import { NavigationBar } from '$lib/features/nav';
	import {
		DeadPoolHeader,
		ActiveRoundsGrid,
		ResultsPanel,
		BetModal
	} from '$lib/features/deadpool';
	import {
		MarketPanel,
		InventoryPanel,
		PurchaseModal,
		UseConfirmModal
	} from '$lib/features/market';
	import { ToastContainer, getToasts } from '$lib/ui/toast';
	import { Stack } from '$lib/ui/layout';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import {
		generateActiveRounds,
		generateMockHistoryList,
		generateUserStats,
		updatePoolsWithBet
	} from '$lib/core/providers/mock/generators/deadpool';
	import type {
		DeadPoolRound,
		DeadPoolSide,
		DeadPoolHistory,
		DeadPoolUserStats,
		Consumable,
		OwnedConsumable
	} from '$lib/core/types';

	const provider = getProvider();
	const toast = getToasts();

	// Tab state
	type MarketTab = 'deadpool' | 'blackmarket';
	let activeTab = $state<MarketTab>('blackmarket');

	// Navigation state
	let activeNav = $state('pool');

	// Dead Pool state - load mock data
	let rounds = $state<DeadPoolRound[]>(generateActiveRounds());
	let history = $state<DeadPoolHistory[]>(generateMockHistoryList(10));
	let userStats = $state<DeadPoolUserStats>(generateUserStats());

	// Dead Pool modal state
	let showBetModal = $state(false);
	let selectedRound = $state<DeadPoolRound | null>(null);

	// Black Market modal state
	let showPurchaseModal = $state(false);
	let selectedConsumable = $state<Consumable | null>(null);
	let showUseModal = $state(false);
	let selectedOwned = $state<OwnedConsumable | null>(null);
	let purchaseLoading = $state(false);
	let useLoading = $state(false);

	// User balance (from provider or mock)
	const userBalance = $derived(provider.currentUser?.tokenBalance ?? 1000n * 10n ** 18n);
	const userLevel = $derived(provider.position?.level ?? null);
	const ownedConsumables = $derived(provider.ownedConsumables);

	// Handlers
	function handleBet(round: DeadPoolRound) {
		if (!provider.currentUser) {
			toast.warning('Connect wallet to place bets');
			return;
		}

		selectedRound = round;
		showBetModal = true;
	}

	function handleConfirmBet(side: DeadPoolSide, amount: bigint) {
		if (!selectedRound) return;

		// Update round with user's bet
		const roundIndex = rounds.findIndex((r) => r.id === selectedRound!.id);
		if (roundIndex !== -1) {
			rounds[roundIndex] = {
				...rounds[roundIndex],
				pools: updatePoolsWithBet(rounds[roundIndex].pools, side, amount),
				userBet: {
					side,
					amount,
					timestamp: Date.now()
				}
			};
		}

		toast.success(`Bet placed: ${(Number(amount) / 1e18).toFixed(2)} Đ on ${side.toUpperCase()}`);
		handleCloseBetModal();
	}

	function handleCloseBetModal() {
		showBetModal = false;
		selectedRound = null;
	}

	function handleNavigate(id: string) {
		activeNav = id;
		if (id === 'network') {
			goto('/');
		}
	}

	function handleHelp() {
		if (activeTab === 'deadpool') {
			toast.info('Dead Pool: Bet on network outcomes. Parimutuel odds, 5% rake burned.');
		} else {
			toast.info('Black Market: Buy consumables for temporary boosts. All purchases are burned.');
		}
	}

	// ─────────────────────────────────────────────────────────────
	// BLACK MARKET HANDLERS
	// ─────────────────────────────────────────────────────────────

	function handleBuyConsumable(consumable: Consumable) {
		if (!provider.currentUser) {
			toast.warning('Connect wallet to purchase items');
			return;
		}

		selectedConsumable = consumable;
		showPurchaseModal = true;
	}

	async function handleConfirmPurchase(consumableId: string, quantity: number) {
		purchaseLoading = true;
		try {
			await provider.purchaseConsumable(consumableId, quantity);
			toast.success(`Purchased ${quantity}x item!`);
			handleClosePurchaseModal();
		} catch (error) {
			const message = error instanceof Error ? error.message : 'Purchase failed';
			toast.error(message);
		} finally {
			purchaseLoading = false;
		}
	}

	function handleClosePurchaseModal() {
		showPurchaseModal = false;
		selectedConsumable = null;
	}

	function handleUseConsumable(consumableId: string) {
		if (!provider.currentUser) {
			toast.warning('Connect wallet to use items');
			return;
		}

		if (!provider.position) {
			toast.warning('Jack in first to use items');
			return;
		}

		const owned = ownedConsumables.find((o) => o.consumableId === consumableId);
		if (!owned) return;

		selectedOwned = owned;
		showUseModal = true;
	}

	async function handleConfirmUse(consumableId: string) {
		useLoading = true;
		try {
			const result = await provider.useConsumable(consumableId);
			if (result.success) {
				toast.success('Item used! Effect applied.');
			} else {
				toast.error(result.error ?? 'Failed to use item');
			}
			handleCloseUseModal();
		} catch (error) {
			const message = error instanceof Error ? error.message : 'Failed to use item';
			toast.error(message);
		} finally {
			useLoading = false;
		}
	}

	function handleCloseUseModal() {
		showUseModal = false;
		selectedOwned = null;
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
						over: round.pools.over + overChange
					}
				};
			});
		}, 5000);

		return () => clearInterval(interval);
	});
</script>

<svelte:head>
	<title>GHOSTNET - {activeTab === 'deadpool' ? 'Dead Pool' : 'Black Market'}</title>
	<meta name="description" content="Dead Pool prediction markets and Black Market consumables." />
</svelte:head>

<div class="market-page">
	<Header />

	<main class="main-content">
		<!-- Tab Navigation -->
		<div class="tab-nav" role="tablist">
			<button
				class="tab-button"
				class:active={activeTab === 'blackmarket'}
				role="tab"
				aria-selected={activeTab === 'blackmarket'}
				onclick={() => (activeTab = 'blackmarket')}
			>
				BLACK MARKET
			</button>
			<button
				class="tab-button"
				class:active={activeTab === 'deadpool'}
				role="tab"
				aria-selected={activeTab === 'deadpool'}
				onclick={() => (activeTab = 'deadpool')}
			>
				DEAD POOL
			</button>
		</div>

		<!-- Tab Content -->
		{#if activeTab === 'blackmarket'}
			<Stack gap={4}>
				<MarketPanel
					userBalance={userBalance}
					userLevel={userLevel}
					onBuy={handleBuyConsumable}
				/>

				<InventoryPanel
					inventory={ownedConsumables}
					onUse={handleUseConsumable}
				/>
			</Stack>
		{:else}
			<Stack gap={4}>
				<DeadPoolHeader stats={userStats} balance={userBalance} onHelp={handleHelp} />

				<section class="section">
					<h2 class="section-title">ACTIVE ROUNDS</h2>
					<ActiveRoundsGrid {rounds} onBet={handleBet} />
				</section>

				<section class="section">
					<ResultsPanel {history} limit={5} />
				</section>
			</Stack>
		{/if}
	</main>

	<NavigationBar active={activeNav} onNavigate={handleNavigate} />
</div>

<!-- Dead Pool Bet Modal -->
<BetModal
	open={showBetModal}
	round={selectedRound}
	balance={userBalance}
	onClose={handleCloseBetModal}
	onConfirm={handleConfirmBet}
/>

<!-- Black Market Purchase Modal -->
<PurchaseModal
	open={showPurchaseModal}
	consumable={selectedConsumable}
	balance={userBalance}
	loading={purchaseLoading}
	onClose={handleClosePurchaseModal}
	onConfirm={handleConfirmPurchase}
/>

<!-- Black Market Use Modal -->
<UseConfirmModal
	open={showUseModal}
	owned={selectedOwned}
	loading={useLoading}
	onClose={handleCloseUseModal}
	onConfirm={handleConfirmUse}
/>

<!-- Toast notifications -->
<ToastContainer />

<style>
	.market-page {
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

	/* Tab Navigation */
	.tab-nav {
		display: flex;
		gap: var(--space-1);
		margin-bottom: var(--space-4);
		border-bottom: 1px solid var(--color-border-subtle);
	}

	.tab-button {
		padding: var(--space-2) var(--space-4);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		font-family: var(--font-mono);
		letter-spacing: var(--tracking-wide);
		color: var(--color-text-tertiary);
		background: transparent;
		border: none;
		border-bottom: 2px solid transparent;
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.tab-button:hover {
		color: var(--color-text-secondary);
	}

	.tab-button.active {
		color: var(--color-accent);
		border-bottom-color: var(--color-accent);
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

		.tab-button {
			padding: var(--space-2) var(--space-3);
			font-size: var(--text-xs);
		}
	}
</style>
