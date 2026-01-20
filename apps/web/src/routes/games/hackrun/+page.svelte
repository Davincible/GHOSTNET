<script lang="ts">
	import { goto } from '$app/navigation';
	import { browser } from '$app/environment';
	import { Shell } from '$lib/ui/terminal';
	import { Box } from '$lib/ui/terminal';
	import { Stack } from '$lib/ui/layout';
	import { getAudioManager } from '$lib/core/audio';
	import {
		getHackRunStore,
		RunSelectionView,
		ActiveRunView,
		RunCompleteView,
	} from '$lib/features/hackrun';
	import type { HackRun, NodeResult } from '$lib/core/types/hackrun';

	const store = getHackRunStore();
	const audio = getAudioManager();

	// Local state for typing
	let typed = $state('');
	let typingStartTime = $state(0);

	// Track previous state for audio
	let prevStatus = $state<string>('idle');

	// Initialize selection on mount
	$effect(() => {
		if (browser && store.state.status === 'idle') {
			store.selectDifficulty();
		}
	});

	// Handle run selection
	function handleSelectRun(run: HackRun): void {
		store.startRun(run);
	}

	// Handle starting node typing
	function handleStartNode(): void {
		typed = '';
		typingStartTime = Date.now();
		store.startNode();
	}

	// Handle node completion
	function handleNodeComplete(result: NodeResult): void {
		store.completeNode(result);
		typed = '';

		// Play sound
		if (result.success) {
			audio.roundComplete();
		} else {
			audio.traced();
		}
	}

	// Handle run again
	function handleRunAgain(): void {
		store.reset();
		store.selectDifficulty();
	}

	// Handle exit
	function handleExit(): void {
		store.reset();
		goto('/');
	}

	// Global keyboard handler
	function handleKeydown(event: KeyboardEvent): void {
		// Escape to abort
		if (event.key === 'Escape') {
			const status = store.state.status;
			if (
				status === 'running' ||
				status === 'node_typing' ||
				status === 'countdown' ||
				status === 'node_result'
			) {
				event.preventDefault();
				store.abort();
			}
			return;
		}

		// Only capture during typing state
		if (store.state.status !== 'node_typing') return;

		// Prevent default for most keys during typing
		if (!event.key.startsWith('F') && event.key !== 'Tab') {
			event.preventDefault();
		}

		// Handle backspace
		if (event.key === 'Backspace') {
			typed = typed.slice(0, -1);
			return;
		}

		// Handle printable characters
		if (event.key.length === 1) {
			typed += event.key;

			// Play keystroke sound
			const node = store.state.node;
			if (node) {
				const targetChar = node.challenge.command[typed.length - 1];
				const isCorrect = event.key === targetChar;
				if (isCorrect) {
					audio.keystroke();
				} else {
					audio.keystrokeError();
				}
			}
		}
	}

	// Setup keyboard listener
	$effect(() => {
		if (!browser) return;

		window.addEventListener('keydown', handleKeydown);
		return () => {
			window.removeEventListener('keydown', handleKeydown);
		};
	});

	// Audio for state transitions
	$effect(() => {
		const status = store.state.status;

		if (status !== prevStatus) {
			if (status === 'running' && prevStatus === 'countdown') {
				audio.countdownGo();
			} else if (status === 'complete') {
				audio.gameComplete();
			} else if (status === 'failed') {
				audio.traced();
			}
			prevStatus = status;
		}
	});

	// Countdown audio
	$effect(() => {
		if (store.state.status === 'countdown') {
			audio.countdown();
		}
	});
</script>

<svelte:head>
	<title>Hack Run | GHOSTNET</title>
</svelte:head>

<Shell>
	<div class="hackrun-page">
		<!-- Header -->
		<header class="page-header">
			<button class="back-button" onclick={() => goto('/')} aria-label="Return to network">
				<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<line x1="19" y1="12" x2="5" y2="12"></line>
					<polyline points="12 19 5 12 12 5"></polyline>
				</svg>
				<span>NETWORK</span>
			</button>
			<h1 class="page-title">HACK RUN</h1>
			<div class="spacer"></div>
		</header>

		<!-- Main Content -->
		<main class="page-content">
			{#if store.state.status === 'selecting'}
				<RunSelectionView availableRuns={store.state.availableRuns} onSelectRun={handleSelectRun} />
			{:else if store.state.status === 'countdown'}
				<div class="countdown-view">
					<Box borderColor="cyan" glow>
						<Stack gap={4} align="center">
							<span class="countdown-label">INITIATING HACK RUN</span>
							<span class="countdown-number">{store.state.secondsLeft}</span>
							<span class="countdown-hint">Prepare for infiltration...</span>
						</Stack>
					</Box>
				</div>
			{:else if store.state.status === 'running' || store.state.status === 'node_typing' || store.state.status === 'node_result'}
				<ActiveRunView
					run={store.state.run}
					currentNode={store.state.status === 'node_typing' ? store.state.node : null}
					progress={store.state.progress}
					timeRemaining={store.state.timeRemaining}
					currentMultiplier={store.currentMultiplier}
					totalLoot={store.totalLoot}
					{typed}
					{typingStartTime}
					isTyping={store.state.status === 'node_typing'}
					onNodeComplete={handleNodeComplete}
					onStartNode={handleStartNode}
				/>
			{:else if store.state.status === 'complete'}
				<RunCompleteView
					result={store.state.result}
					onRunAgain={handleRunAgain}
					onExit={handleExit}
				/>
			{:else if store.state.status === 'failed'}
				<div class="failed-view">
					<Box borderColor="red" glow>
						<Stack gap={4} align="center">
							<span class="failed-icon">[X]</span>
							<h2 class="failed-title">RUN FAILED</h2>
							<p class="failed-reason">
								{#if store.state.reason === 'TIME_EXPIRED'}
									Time limit exceeded
								{:else if store.state.reason === 'NODE_FAILED'}
									Node breach failed - accuracy too low
								{:else if store.state.reason === 'USER_ABORT'}
									Connection terminated by user
								{:else}
									{store.state.reason}
								{/if}
							</p>
							<p class="failed-penalty">Entry fee lost</p>
							<div class="failed-actions">
								<button class="action-btn" onclick={handleRunAgain}>TRY AGAIN</button>
								<button class="action-btn action-btn-secondary" onclick={handleExit}>EXIT</button>
							</div>
						</Stack>
					</Box>
				</div>
			{:else}
				<div class="loading-state">
					<span>Loading...</span>
				</div>
			{/if}
		</main>
	</div>
</Shell>

<style>
	.hackrun-page {
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
		border: 1px solid var(--color-border-default);
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		font-family: var(--font-mono);
		letter-spacing: var(--tracking-wide);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.back-button:hover {
		background: var(--color-bg-secondary);
		border-color: var(--color-accent-dim);
		color: var(--color-accent);
	}

	.back-button svg {
		width: 16px;
		height: 16px;
	}

	.page-title {
		color: var(--color-accent);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	.spacer {
		width: 100px;
	}

	.page-content {
		flex: 1;
		display: flex;
		flex-direction: column;
		justify-content: flex-start;
	}

	/* Countdown View */
	.countdown-view {
		max-width: 400px;
		margin: var(--space-8) auto;
		text-align: center;
	}

	.countdown-label {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		letter-spacing: var(--tracking-wider);
	}

	.countdown-number {
		color: var(--color-accent);
		font-size: 6rem;
		font-weight: var(--font-bold);
		line-height: 1;
		text-shadow: 0 0 20px var(--color-accent);
		animation: pulse-countdown 1s ease-in-out infinite;
	}

	.countdown-hint {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
	}

	/* Failed View */
	.failed-view {
		max-width: 400px;
		margin: var(--space-8) auto;
		text-align: center;
	}

	.failed-icon {
		color: var(--color-red);
		font-size: var(--text-4xl);
		font-weight: var(--font-bold);
	}

	.failed-title {
		color: var(--color-red);
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
		margin: 0;
	}

	.failed-reason {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		margin: 0;
	}

	.failed-penalty {
		color: var(--color-red-dim);
		font-size: var(--text-xs);
		margin: 0;
	}

	.failed-actions {
		display: flex;
		gap: var(--space-3);
		justify-content: center;
		margin-top: var(--space-2);
	}

	.action-btn {
		padding: var(--space-2) var(--space-4);
		background: transparent;
		border: 1px solid var(--color-accent);
		color: var(--color-accent);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.action-btn:hover {
		background: var(--color-accent);
		color: var(--color-bg-void);
	}

	.action-btn-secondary {
		border-color: var(--color-border-default);
		color: var(--color-text-secondary);
	}

	.action-btn-secondary:hover {
		background: var(--color-bg-tertiary);
		color: var(--color-text-primary);
	}

	/* Loading */
	.loading-state {
		text-align: center;
		padding: var(--space-8);
		color: var(--color-text-tertiary);
	}

	@keyframes pulse-countdown {
		0%,
		100% {
			transform: scale(1);
			opacity: 1;
		}
		50% {
			transform: scale(1.05);
			opacity: 0.8;
		}
	}
</style>
