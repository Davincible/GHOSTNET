<script lang="ts">
	import { goto } from '$app/navigation';
	import { browser } from '$app/environment';
	import { Shell } from '$lib/ui/terminal';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import { createTypingGameStore } from '$lib/features/typing/store.svelte';
	import IdleView from '$lib/features/typing/IdleView.svelte';
	import CountdownView from '$lib/features/typing/CountdownView.svelte';
	import ActiveView from '$lib/features/typing/ActiveView.svelte';
	import CompleteView from '$lib/features/typing/CompleteView.svelte';

	const provider = getProvider();
	const gameStore = createTypingGameStore();

	// Handle starting the game
	function handleStart(): void {
		const challenge = provider.getTypingChallenge();
		gameStore.start(challenge);
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
	async function handleReturn(): Promise<void> {
		// Submit result if we have one
		const result = gameStore.getResult();
		if (result) {
			await provider.submitTypingResult(result);
		}
		gameStore.reset();
		goto('/');
	}

	// Global keyboard handler for typing
	function handleKeydown(event: KeyboardEvent): void {
		// Handle Escape to abort during active/countdown
		if (event.key === 'Escape') {
			if (gameStore.state.status === 'active' || gameStore.state.status === 'countdown') {
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

		// Handle the keystroke
		gameStore.handleKey(event.key);
	}

	// Setup/teardown keyboard listener
	$effect(() => {
		if (!browser) return;

		window.addEventListener('keydown', handleKeydown);
		return () => {
			window.removeEventListener('keydown', handleKeydown);
		};
	});

	// Auto-submit result when game completes
	$effect(() => {
		if (gameStore.state.status === 'complete') {
			const result = gameStore.getResult();
			if (result) {
				provider.submitTypingResult(result);
			}
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
				<CountdownView secondsLeft={gameStore.state.secondsLeft} />
			{:else if gameStore.state.status === 'active'}
				<ActiveView
					challenge={gameStore.state.challenge}
					progress={gameStore.state.progress}
				/>
			{:else if gameStore.state.status === 'complete'}
				<CompleteView
					challenge={gameStore.state.challenge}
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
