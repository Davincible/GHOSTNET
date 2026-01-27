<script lang="ts">
	import { goto } from '$app/navigation';
	import { Header, Breadcrumb } from '$lib/features/header';
	import { NavigationBar } from '$lib/features/nav';
	import {
		MarketPanel,
		InventoryPanel,
		PurchaseModal,
		UseConfirmModal,
	} from '$lib/features/market';
	import { ToastContainer, getToasts } from '$lib/ui/toast';
	import { Stack } from '$lib/ui/layout';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import type { Consumable, OwnedConsumable } from '$lib/core/types';

	const provider = getProvider();
	const toast = getToasts();

	// Navigation state
	let activeNav = $state('market');

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

	// ─────────────────────────────────────────────────────────────
	// HANDLERS
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

	function handleNavigate(id: string) {
		activeNav = id;
		if (id === 'network') {
			goto('/');
		}
	}
</script>

<svelte:head>
	<title>GHOSTNET - Black Market</title>
	<meta name="description" content="Black Market consumables. Buy temporary boosts." />
</svelte:head>

<div class="market-page">
	<Header />
	<Breadcrumb path={[{ label: 'NETWORK', href: '/' }, { label: 'BLACK MARKET' }]} />

	<main class="main-content">
		<Stack gap={4}>
			<MarketPanel {userBalance} {userLevel} onBuy={handleBuyConsumable} />

			<InventoryPanel inventory={ownedConsumables} onUse={handleUseConsumable} />
		</Stack>
	</main>

	<NavigationBar active={activeNav} onNavigate={handleNavigate} />
</div>

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

	@media (max-width: 767px) {
		.main-content {
			padding: var(--space-2);
		}
	}
</style>
