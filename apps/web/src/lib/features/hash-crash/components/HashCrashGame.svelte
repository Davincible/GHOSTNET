<script lang="ts">
	import { onMount } from 'svelte';
	import Box from '$lib/ui/terminal/Box.svelte';
	import MultiplierDisplay from './MultiplierDisplay.svelte';
	import BettingPanel from './BettingPanel.svelte';
	import LivePlayersPanel from './LivePlayersPanel.svelte';
	import RecentCrashes from './RecentCrashes.svelte';
	import CrashChart from './CrashChart.svelte';
	import { createHashCrashStore, type HashCrashStore } from '../store.svelte';

	interface Props {
		/** Optional external store (for testing) */
		store?: HashCrashStore;
		/** Enable simulation mode */
		simulate?: boolean;
	}

	let { store: externalStore, simulate = false }: Props = $props();

	// Create or use provided store - use a function to avoid capturing initial value warning
	function getStore(): HashCrashStore {
		return externalStore ?? createHashCrashStore();
	}
	const store = getStore();

	// Reactive state from store
	let state = $derived(store.state);
	let round = $derived(state.round);
	let isCrashed = $derived(round?.state === 'crashed');
	let isRising = $derived(round?.state === 'rising');
	let isBetting = $derived(round?.state === 'betting');

	// Connect on mount
	onMount(() => {
		if (simulate) {
			// Start a simulation for demo purposes
			store._simulateRound(Math.random() * 10 + 1.5);
		} else {
			const cleanup = store.connect();
			return cleanup;
		}
	});

	// Handlers
	function handlePlaceBet(amount: bigint, autoCashOut?: number) {
		store.placeBet(amount, autoCashOut);
	}

	function handleCashOut() {
		store.cashOut();
	}

	// Demo: trigger new simulation round when crashed
	function startNewRound() {
		if (simulate && isCrashed) {
			setTimeout(() => {
				store._simulateRound(Math.random() * 15 + 1.2);
			}, 2000);
		}
	}

	// Auto-start next simulation round
	$effect(() => {
		if (simulate && isCrashed) {
			startNewRound();
		}
	});
</script>

<div class="hash-crash-game">
	<!-- Header -->
	<header class="game-header">
		<h1 class="game-title">HASH CRASH</h1>
		{#if round}
			<span class="round-number">ROUND #{round.roundId}</span>
		{/if}
		<div class="connection-status" class:connected={state.isConnected}>
			{state.isConnected ? '● CONNECTED' : '○ DISCONNECTED'}
		</div>
	</header>

	<!-- Main game area -->
	<div class="game-layout">
		<!-- Left: Chart and multiplier -->
		<div class="game-main">
			<Box title="Multiplier" variant="double" borderColor={isCrashed ? 'red' : 'bright'} glow>
				<div class="multiplier-area">
					<MultiplierDisplay
						multiplier={state.multiplier}
						crashed={isCrashed}
						crashPoint={round?.crashPoint}
					/>
					<CrashChart
						multiplier={state.multiplier}
						crashed={isCrashed}
						startTime={round?.startTime ?? 0}
					/>
				</div>
			</Box>

			<!-- Recent crashes strip -->
			<RecentCrashes crashPoints={state.recentCrashPoints} />
		</div>

		<!-- Right: Betting panel and players -->
		<div class="game-sidebar">
			<BettingPanel
				canBet={store.canBet}
				canCashOut={store.canCashOut}
				multiplier={state.multiplier}
				potentialPayout={store.potentialPayout}
				currentBet={state.playerBet?.amount ?? null}
				timeDisplay={store.timeDisplay}
				isCritical={store.isCritical}
				isLoading={state.isLoading}
				onPlaceBet={handlePlaceBet}
				onCashOut={handleCashOut}
			/>

			<LivePlayersPanel
				players={state.players}
				recentCashOuts={state.recentCashOuts}
				isActive={isRising}
			/>
		</div>
	</div>

	<!-- Error display -->
	{#if state.error}
		<div class="error-banner">
			<span class="error-icon">⚠</span>
			<span>{state.error}</span>
		</div>
	{/if}
</div>

<style>
	.hash-crash-game {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		padding: var(--space-4);
		max-width: 1200px;
		margin: 0 auto;
	}

	/* Header */
	.game-header {
		display: flex;
		align-items: center;
		gap: var(--space-4);
		padding: var(--space-2) 0;
		border-bottom: var(--border-width) solid var(--color-border-subtle);
	}

	.game-title {
		font-family: var(--font-mono);
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-widest);
		color: var(--color-accent);
		margin: 0;
	}

	.round-number {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
	}

	.connection-status {
		margin-left: auto;
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-red);
		letter-spacing: var(--tracking-wider);
	}

	.connection-status.connected {
		color: var(--color-accent);
	}

	/* Main layout */
	.game-layout {
		display: grid;
		grid-template-columns: 1fr 350px;
		gap: var(--space-4);
	}

	@media (max-width: 900px) {
		.game-layout {
			grid-template-columns: 1fr;
		}
	}

	/* Main area */
	.game-main {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.multiplier-area {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	/* Sidebar */
	.game-sidebar {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	/* Error banner */
	.error-banner {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-3);
		background: var(--color-red-glow);
		border: var(--border-width) solid var(--color-red);
		color: var(--color-red);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
	}

	.error-icon {
		font-size: var(--text-lg);
	}
</style>
