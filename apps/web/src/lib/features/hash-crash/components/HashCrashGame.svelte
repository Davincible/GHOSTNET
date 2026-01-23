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

	// Create or use provided store
	function getStore(): HashCrashStore {
		return externalStore ?? createHashCrashStore();
	}
	const store = getStore();

	// Reactive state from store
	let state = $derived(store.state);
	let round = $derived(state.round);
	let phase = $derived(round?.state ?? null);
	let isCrashed = $derived(phase === 'settled');
	let isAnimating = $derived(phase === 'animating');
	let isBetting = $derived(phase === 'betting');

	// Connect on mount
	onMount(() => {
		if (simulate) {
			// Start a simulation for demo purposes
			startSimulation();
		} else {
			const cleanup = store.connect();
			return cleanup;
		}
	});

	// Generate random crash point for simulation
	function generateCrashPoint(): number {
		const random = Math.random();
		// Formula: crashPoint = 0.96 / (1 - random), clamped
		const crashPoint = 0.96 / (1 - random);
		return Math.max(1.01, Math.min(100, crashPoint));
	}

	// Start simulation
	function startSimulation() {
		store._simulateRound(generateCrashPoint());
	}

	// Handlers
	function handlePlaceBet(amount: bigint, targetMultiplier: number) {
		store.placeBet(amount, targetMultiplier);
	}

	// Auto-start next simulation round when settled
	$effect(() => {
		if (simulate && phase === 'settled') {
			setTimeout(() => {
				startSimulation();
			}, 3000);
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
		<div
			class="phase-indicator"
			class:betting={isBetting}
			class:animating={isAnimating}
			class:settled={isCrashed}
		>
			{#if phase === 'betting'}
				BETTING
			{:else if phase === 'locked'}
				LOCKED
			{:else if phase === 'revealed'}
				REVEALED
			{:else if phase === 'animating'}
				LIVE
			{:else if phase === 'settled'}
				SETTLED
			{:else}
				IDLE
			{/if}
		</div>
		<div class="connection-status" class:connected={state.isConnected || simulate}>
			{state.isConnected || simulate ? '+ CONNECTED' : '- DISCONNECTED'}
		</div>
	</header>

	<!-- Main game area -->
	<div class="game-layout">
		<!-- Left: Chart and multiplier -->
		<div class="game-main">
			<Box
				title="Multiplier"
				variant="double"
				borderColor={isCrashed ? 'red' : state.playerResult === 'won' ? 'bright' : 'default'}
				glow={isAnimating || state.playerResult === 'won'}
			>
				<div class="multiplier-area">
					<MultiplierDisplay
						multiplier={state.multiplier}
						targetMultiplier={state.playerBet?.targetMultiplier ?? null}
						playerResult={state.playerResult}
						crashed={isCrashed}
						crashPoint={round?.crashPoint ?? null}
					/>
					<CrashChart multiplier={state.multiplier} crashed={isCrashed} />
				</div>
			</Box>

			<!-- Recent crashes strip -->
			<RecentCrashes crashPoints={state.recentCrashPoints} />
		</div>

		<!-- Right: Betting panel and players -->
		<div class="game-sidebar">
			<BettingPanel
				canBet={store.canBet}
				{phase}
				multiplier={state.multiplier}
				targetMultiplier={state.playerBet?.targetMultiplier ?? null}
				currentBet={state.playerBet?.amount ?? null}
				potentialPayout={store.potentialPayout}
				playerResult={state.playerResult}
				crashPoint={round?.crashPoint ?? null}
				timeDisplay={store.timeDisplay}
				isCritical={store.isCritical}
				isLoading={state.isLoading}
				onPlaceBet={handlePlaceBet}
			/>

			<LivePlayersPanel
				players={state.players}
				crashPoint={round?.crashPoint ?? null}
				isActive={isAnimating}
			/>
		</div>
	</div>

	<!-- Error display -->
	{#if state.error}
		<div class="error-banner">
			<span class="error-icon">[!]</span>
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

	.phase-indicator {
		padding: var(--space-1) var(--space-2);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
		border: var(--border-width) solid var(--color-border-default);
		color: var(--color-text-secondary);
	}

	.phase-indicator.betting {
		border-color: var(--color-cyan);
		color: var(--color-cyan);
	}

	.phase-indicator.animating {
		border-color: var(--color-accent);
		color: var(--color-accent);
		animation: pulse-border 1s ease-in-out infinite;
	}

	.phase-indicator.settled {
		border-color: var(--color-red);
		color: var(--color-red);
	}

	@keyframes pulse-border {
		0%,
		100% {
			border-color: var(--color-accent);
		}
		50% {
			border-color: transparent;
		}
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
