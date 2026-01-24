<script lang="ts">
	import { goto } from '$app/navigation';
	import { browser } from '$app/environment';
	import { Shell } from '$lib/ui/terminal';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import { createTypingGameStore, TOTAL_ROUNDS } from '$lib/features/typing/store.svelte';
	import { getAudioManager } from '$lib/core/audio';
	import IdleView from '$lib/features/typing/IdleView.svelte';
	import CountdownView from '$lib/features/typing/CountdownView.svelte';
	import ActiveView from '$lib/features/typing/ActiveView.svelte';
	import CompleteView from '$lib/features/typing/CompleteView.svelte';
	import RoundCompleteView from '$lib/features/typing/RoundCompleteView.svelte';

	const provider = getProvider();
	const gameStore = createTypingGameStore();
	const audio = getAudioManager();

	// Track if we've submitted the current result to avoid infinite loops
	let hasSubmittedResult = $state(false);

	// Track previous state for audio triggers
	let prevStatus = $state<string>('idle');
	let prevCountdown = $state<number>(0);

	// Handle starting the game
	function handleStart(): void {
		// Generate multiple challenges for the game
		gameStore.start(() => {
			const challenges = [];
			for (let i = 0; i < TOTAL_ROUNDS; i++) {
				challenges.push(provider.getTypingChallenge());
			}
			return challenges;
		});
	}

	// Handle practice again
	function handlePracticeAgain(): void {
		gameStore.reset();
		// Small delay before starting again
		setTimeout(() => {
			handleStart();
		}, 100);
	}

	// Handle return to network
	function handleReturn(): void {
		// Result is already auto-submitted when game completes
		gameStore.reset();
		goto('/');
	}

	// Global keyboard handler for typing
	function handleKeydown(event: KeyboardEvent): void {
		// Handle Escape to abort during active/countdown/roundComplete
		if (event.key === 'Escape') {
			const status = gameStore.state.status;
			if (status === 'active' || status === 'countdown' || status === 'roundComplete') {
				event.preventDefault();
				gameStore.reset();
			}
			return;
		}

		// Only capture during active state
		if (gameStore.state.status !== 'active') return;

		// Prevent default for most keys during typing
		// Allow: Tab (for accessibility), F keys (browser functions)
		if (!event.key.startsWith('F') && event.key !== 'Tab') {
			event.preventDefault();
		}

		// Get current position before handling key
		const { progress, challenge } = gameStore.state;
		const targetChar = challenge.command[progress.typed.length];
		const isCorrect = event.key === targetChar;

		// Handle the keystroke
		gameStore.handleKey(event.key);

		// Play keystroke sound (only for printable characters)
		if (event.key.length === 1) {
			if (isCorrect) {
				audio.keystroke();
			} else {
				audio.keystrokeError();
			}
		}
	}

	// Setup/teardown keyboard listener
	$effect(() => {
		if (!browser) return;

		window.addEventListener('keydown', handleKeydown);
		return () => {
			window.removeEventListener('keydown', handleKeydown);
		};
	});

	// Auto-submit result when game completes (only once)
	$effect(() => {
		if (gameStore.state.status === 'complete' && !hasSubmittedResult) {
			hasSubmittedResult = true;
			const result = gameStore.getResult();
			if (result) {
				provider.submitTypingResult(result);
			}
		} else if (gameStore.state.status === 'idle') {
			// Reset flag when game resets
			hasSubmittedResult = false;
		}
	});

	// Audio effects for state transitions
	$effect(() => {
		const status = gameStore.state.status;

		// Countdown ticks
		if (status === 'countdown') {
			const seconds = gameStore.state.secondsLeft;
			if (seconds !== prevCountdown) {
				prevCountdown = seconds;
				if (seconds > 0) {
					audio.countdown();
				}
			}
		}

		// State transition sounds
		if (status !== prevStatus) {
			if (status === 'active' && prevStatus === 'countdown') {
				// Countdown finished, game starting
				audio.countdownGo();
			} else if (status === 'roundComplete') {
				// Round completed
				audio.roundComplete();
			} else if (status === 'complete') {
				// Game completed
				audio.gameComplete();
			}
			prevStatus = status;
		}
	});
</script>

<svelte:head>
	<title>Trace Evasion | GHOSTNET</title>
</svelte:head>

<Shell>
	<div class="typing-page">
		<!-- Header -->
		<header class="page-header">
			<button class="back-button" onclick={() => goto('/')} aria-label="Return to network">
				<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<line x1="19" y1="12" x2="5" y2="12"></line>
					<polyline points="12 19 5 12 12 5"></polyline>
				</svg>
				<span>NETWORK</span>
			</button>
			<h1 class="page-title">TRACE EVASION</h1>
			<div class="spacer"></div>
		</header>

		<!-- Main Content -->
		<main class="page-content">
			{#if gameStore.state.status === 'idle'}
				<IdleView onStart={handleStart} />
			{:else if gameStore.state.status === 'countdown'}
				<CountdownView
					secondsLeft={gameStore.state.secondsLeft}
					currentRound={gameStore.state.currentRound}
					totalRounds={gameStore.state.totalRounds}
				/>
			{:else if gameStore.state.status === 'active'}
				<ActiveView
					challenge={gameStore.state.challenge}
					progress={gameStore.state.progress}
					currentRound={gameStore.state.currentRound}
					totalRounds={gameStore.state.totalRounds}
				/>
			{:else if gameStore.state.status === 'roundComplete'}
				<RoundCompleteView
					result={gameStore.state.lastRoundResult}
					currentRound={gameStore.state.currentRound}
					totalRounds={gameStore.state.totalRounds}
				/>
			{:else if gameStore.state.status === 'complete'}
				<CompleteView
					result={gameStore.state.result}
					onPracticeAgain={handlePracticeAgain}
					onReturn={handleReturn}
				/>
			{/if}
		</main>

		<!-- Footer hint during active state -->
		{#if gameStore.state.status === 'active'}
			<footer class="typing-hint">
				<span class="hint-text">Press <kbd>Esc</kbd> to abort</span>
			</footer>
		{/if}
	</div>
</Shell>

<style>
	.typing-page {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
		padding: var(--space-4);
	}

	.page-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: var(--space-6);
		padding-bottom: var(--space-3);
		border-bottom: 1px solid var(--color-bg-tertiary);
	}

	.back-button {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2) var(--space-3);
		background: transparent;
		border: 1px solid var(--color-green-dim);
		color: var(--color-green-mid);
		font-size: var(--text-sm);
		font-family: var(--font-mono);
		letter-spacing: var(--tracking-wide);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.back-button:hover {
		background: var(--color-bg-secondary);
		border-color: var(--color-green-mid);
		color: var(--color-green-bright);
	}

	.back-button svg {
		width: 16px;
		height: 16px;
	}

	.page-title {
		color: var(--color-green-bright);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	.spacer {
		width: 100px; /* Match back button width for centering */
	}

	.page-content {
		flex: 1;
		display: flex;
		flex-direction: column;
		justify-content: center;
	}

	.typing-hint {
		text-align: center;
		padding: var(--space-4);
	}

	.hint-text {
		color: var(--color-green-dim);
		font-size: var(--text-sm);
	}

	.hint-text kbd {
		background: var(--color-bg-tertiary);
		padding: var(--space-1) var(--space-2);
		border: 1px solid var(--color-green-dim);
		margin: 0 var(--space-1);
	}
</style>
