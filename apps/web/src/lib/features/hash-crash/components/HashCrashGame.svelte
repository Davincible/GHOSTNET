<script lang="ts">
	import { onMount } from 'svelte';
	import Box from '$lib/ui/terminal/Box.svelte';
	import MultiplierDisplay from './MultiplierDisplay.svelte';
	import BettingPanel from './BettingPanel.svelte';
	import LivePlayersPanel from './LivePlayersPanel.svelte';
	import RecentCrashes from './RecentCrashes.svelte';
	import CrashChart from './CrashChart.svelte';
	import { NetworkPenetrationTheme } from './themes/NetworkPenetration';
	import {
		createHashCrashStore,
		type HashCrashStore,
		ROUND_DELAY,
		WIN_ROUND_DELAY,
	} from '../store.svelte';
	import { createThemeStore, type HashCrashTheme } from '../theme.svelte';
	import { getSettings } from '$lib/core/settings';
	import { createAudioManager } from '$lib/core/audio';
	import { createHashCrashAudio } from '../audio';

	interface Props {
		/** Optional external store (for testing) */
		store?: HashCrashStore;
		/** Enable simulation mode */
		simulate?: boolean;
		/** Visual theme to use */
		theme?: HashCrashTheme;
	}

	let {
		store: externalStore,
		simulate = false,
		theme: initialTheme = 'network-penetration',
	}: Props = $props();

	// Theme store for persisting selection (initialTheme used if no saved preference)
	const themeStore = createThemeStore(initialTheme);

	// Audio setup
	const settings = getSettings();
	const audioManager = createAudioManager(settings);
	const audio = createHashCrashAudio(audioManager);

	// Create or use provided store
	function getStore(): HashCrashStore {
		return externalStore ?? createHashCrashStore();
	}
	const store = getStore();

	// Reactive state from store (using 'gameState' to avoid conflict with $state rune)
	let gameState = $derived(store.state);
	let round = $derived(gameState.round);
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
			// Show win state longer for celebration
			const delay = gameState.playerResult === 'won' ? WIN_ROUND_DELAY : ROUND_DELAY;
			setTimeout(() => {
				startSimulation();
			}, delay);
		}
	});

	// ═══════════════════════════════════════════════════════════════
	// AUDIO EFFECTS
	// ═══════════════════════════════════════════════════════════════

	// Track previous values for detecting transitions (avoid 'state' name collision)
	let lastPhase: string | null = $state(null);
	let lastMultiplier = $state(1);
	let lastPlayerResult = $state('pending');

	// Play sounds on phase transitions
	$effect(() => {
		const currentPhase = phase;

		// Only play on actual transitions
		if (currentPhase === lastPhase) return;

		if (currentPhase === 'betting' && lastPhase !== 'betting') {
			audio.bettingStart();
		} else if (currentPhase === 'locked') {
			audio.bettingEnd();
		} else if (currentPhase === 'animating' || currentPhase === 'revealed') {
			audio.launch();
		} else if (currentPhase === 'settled') {
			// Crash sound
			audio.crash();
		}

		lastPhase = currentPhase;
	});

	// Play multiplier tick sounds during animation (throttled in audio helper)
	$effect(() => {
		if (phase !== 'animating') return;

		const mult = gameState.multiplier;
		// Only play ticks when multiplier increases significantly
		if (mult - lastMultiplier >= 0.1) {
			audio.multiplierTick(mult);
			lastMultiplier = mult;
		}
	});

	// Play win/loss sound when result changes
	$effect(() => {
		const result = gameState.playerResult;
		if (result === lastPlayerResult) return;

		if (result === 'won') {
			// Play win sound based on target multiplier achieved
			const targetMult = gameState.playerBet?.targetMultiplier ?? 1;
			audio.win(targetMult);
		} else if (result === 'lost' && lastPlayerResult === 'pending') {
			audio.loss();
		}

		lastPlayerResult = result;
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
		<div class="connection-status" class:connected={gameState.isConnected || simulate}>
			{gameState.isConnected || simulate ? '+ CONNECTED' : '- DISCONNECTED'}
		</div>
	</header>

	<!-- Main game area -->
	<div class="game-layout" class:themed={themeStore.theme !== 'classic'}>
		<!-- Left: Chart and multiplier (themed or classic) -->
		<div class="game-main">
			{#if themeStore.theme === 'network-penetration'}
				<!-- Network Penetration Theme -->
				<NetworkPenetrationTheme
					depth={gameState.multiplier}
					exitPoint={gameState.playerBet?.targetMultiplier ?? null}
					{phase}
					traced={isCrashed}
					playerResult={gameState.playerResult}
					roundId={round?.roundId}
				/>
			{:else}
				<!-- Classic Theme (fallback) -->
				<Box
					title="Multiplier"
					variant="double"
					borderColor={isCrashed ? 'red' : gameState.playerResult === 'won' ? 'bright' : 'default'}
					glow={isAnimating || gameState.playerResult === 'won'}
				>
					<div class="multiplier-area">
						<MultiplierDisplay
							multiplier={gameState.multiplier}
							targetMultiplier={gameState.playerBet?.targetMultiplier ?? null}
							playerResult={gameState.playerResult}
							crashed={isCrashed}
							crashPoint={round?.crashPoint ?? null}
						/>
						<CrashChart multiplier={gameState.multiplier} crashed={isCrashed} />
					</div>
				</Box>
			{/if}

			<!-- Recent crashes strip -->
			<RecentCrashes crashPoints={gameState.recentCrashPoints} />
		</div>

		<!-- Right: Betting panel and players -->
		<div class="game-sidebar">
			<BettingPanel
				canBet={store.canBet}
				{phase}
				multiplier={gameState.multiplier}
				targetMultiplier={gameState.playerBet?.targetMultiplier ?? null}
				currentBet={gameState.playerBet?.amount ?? null}
				potentialPayout={store.potentialPayout}
				playerResult={gameState.playerResult}
				crashPoint={round?.crashPoint ?? null}
				timeDisplay={store.timeDisplay}
				isCritical={store.isCritical}
				isLoading={gameState.isLoading}
				onPlaceBet={handlePlaceBet}
			/>

			<LivePlayersPanel
				players={gameState.players}
				crashPoint={round?.crashPoint ?? null}
				isActive={isAnimating}
			/>
		</div>
	</div>

	<!-- Error display -->
	{#if gameState.error}
		<div class="error-banner">
			<span class="error-icon">[!]</span>
			<span>{gameState.error}</span>
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
