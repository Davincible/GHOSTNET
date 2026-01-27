<script lang="ts">
	import { goto } from '$app/navigation';
	import { browser } from '$app/environment';
	import { Shell, Box } from '$lib/ui/terminal';
	import { Stack } from '$lib/ui/layout';
	import { getSettings } from '$lib/core/settings';
	import { createAudioManager } from '$lib/core/audio';
	import { NavigationBar } from '$lib/features/nav';
	import { Header, Breadcrumb } from '$lib/features/header';
	import {
		getHackRunStore,
		RunSelectionView,
		ActiveRunView,
		RunCompleteView,
	} from '$lib/features/hackrun';
	import type { HackRun, HackRunNode, NodeResult } from '$lib/core/types/hackrun';

	const store = getHackRunStore();
	const settings = getSettings();
	const audio = createAudioManager(settings);

	// Local state for typing
	let typed = $state('');
	let typingStartTime = $state(0);

	// Track previous state for audio
	let prevStatus = $state<string>('idle');
	let prevCountdown = $state<number>(0);
	let prevTimePercent = $state<number>(100);
	let prevNodeIndex = $state<number>(-1);
	let correctStreak = $state<number>(0);
	
	// Time warning thresholds
	const TIME_WARNING_THRESHOLD = 30; // percent
	const TIME_DANGER_THRESHOLD = 15; // percent
	const STREAK_MILESTONE = 5; // correct chars for bonus sound

	// Initialize selection on mount
	$effect(() => {
		if (browser && store.state.status === 'idle') {
			store.selectDifficulty();
		}
	});

	// Handle run selection
	function handleSelectRun(run: HackRun): void {
		audio.click();
		store.startRun(run);
	}

	// Handle cancel/exit from selection
	function handleCancelSelection(): void {
		goto('/');
	}

	// Handle starting node typing
	function handleStartNode(): void {
		typed = '';
		typingStartTime = Date.now();
		correctStreak = 0; // Reset streak for new node
		audio.open();
		store.startNode();
	}

	// Handle node completion
	function handleNodeComplete(result: NodeResult): void {
		store.completeNode(result);
		typed = '';
		correctStreak = 0;

		// Play sound based on performance
		if (result.success) {
			// Tiered success sounds based on accuracy
			if (result.accuracy >= 0.99) {
				audio.jackpot(); // Perfect or near-perfect
			} else if (result.accuracy >= 0.95) {
				audio.survived(); // Excellent
			} else {
				audio.roundComplete(); // Good
			}
		} else {
			audio.traced();
		}
	}

	// Handle abort
	function handleAbort(): void {
		audio.close();
		store.abort();
	}

	// Handle run again
	function handleNewRun(): void {
		audio.click();
		store.reset();
		store.selectDifficulty();
	}

	// Handle exit
	function handleExit(): void {
		audio.close();
		store.reset();
		goto('/');
	}

	// Get current node for typing mode
	const currentNode = $derived.by((): HackRunNode | null => {
		if (store.state.status === 'node_typing') {
			return store.state.node;
		}
		if (store.state.status === 'running' || store.state.status === 'node_result') {
			const progress = store.state.progress;
			const currentIndex = progress.findIndex((p) => p.status === 'current');
			if (currentIndex >= 0) {
				const nodeId = progress[currentIndex].nodeId;
				return store.state.run.nodes.find((n) => n.id === nodeId) ?? null;
			}
		}
		return null;
	});

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
				handleAbort();
			}
			return;
		}

		// Space to start new run or continue
		if (event.key === ' ' && !event.repeat) {
			const status = store.state.status;
			if (status === 'complete' || status === 'failed') {
				event.preventDefault();
				handleNewRun();
				return;
			}
			if (status === 'running' && currentNode) {
				event.preventDefault();
				handleStartNode();
				return;
			}
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
					correctStreak++;
					
					// Milestone sound every N correct chars
					if (correctStreak > 0 && correctStreak % STREAK_MILESTONE === 0) {
						audio.success(); // Satisfying milestone sound
					} else {
						audio.keystroke();
					}
				} else {
					correctStreak = 0; // Reset streak on error
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

	// Countdown audio - play on each tick
	$effect(() => {
		if (store.state.status === 'countdown') {
			const currentSeconds = store.state.secondsLeft;
			if (currentSeconds !== prevCountdown && currentSeconds > 0) {
				audio.countdown();
				prevCountdown = currentSeconds;
			}
		} else {
			prevCountdown = 0;
		}
	});

	// Time warning audio - plays when crossing thresholds
	$effect(() => {
		const status = store.state.status;
		if (status === 'running' || status === 'node_typing' || status === 'node_result') {
			const timeRemaining = store.state.timeRemaining;
			const timeLimit = store.state.run.timeLimit;
			const timePercent = (timeRemaining / timeLimit) * 100;

			// Crossed into danger zone
			if (prevTimePercent > TIME_DANGER_THRESHOLD && timePercent <= TIME_DANGER_THRESHOLD) {
				audio.danger();
			}
			// Crossed into warning zone
			else if (prevTimePercent > TIME_WARNING_THRESHOLD && timePercent <= TIME_WARNING_THRESHOLD) {
				audio.warning();
			}

			prevTimePercent = timePercent;
		} else {
			prevTimePercent = 100;
		}
	});

	// Node advancement audio - plays when moving to next node
	$effect(() => {
		const status = store.state.status;
		if (status === 'running' || status === 'node_typing' || status === 'node_result') {
			const progress = store.state.progress;
			const currentIndex = progress.findIndex((p) => p.status === 'current');
			
			// Advanced to a new node (not the first one)
			if (currentIndex > prevNodeIndex && prevNodeIndex >= 0) {
				audio.success();
			}
			
			prevNodeIndex = currentIndex;
		} else if (status === 'countdown') {
			prevNodeIndex = -1; // Reset for new run
		}
	});

	// Danger zone ambient pulse - repeating warning when time critical
	$effect(() => {
		if (!browser) return;
		
		const status = store.state.status;
		const isActive = status === 'running' || status === 'node_typing' || status === 'node_result';
		
		if (!isActive) return;
		
		const timeRemaining = store.state.timeRemaining;
		const timeLimit = store.state.run.timeLimit;
		const timePercent = (timeRemaining / timeLimit) * 100;
		
		// Only pulse in danger zone during typing
		if (timePercent <= TIME_DANGER_THRESHOLD && status === 'node_typing') {
			const pulseInterval = setInterval(() => {
				audio.scanWarning(); // Subtle repeating pulse
			}, 2000); // Every 2 seconds
			
			return () => clearInterval(pulseInterval);
		}
	});
</script>

<svelte:head>
	<title>Hack Run | GHOSTNET</title>
</svelte:head>

<Header />
<Breadcrumb path={[{ label: 'NETWORK', href: '/' }, { label: 'ARCADE', href: '/arcade' }, { label: 'HACK RUN' }]} />

<Shell>
	<div class="hackrun-page">
		<!-- Main Content -->
		<main class="page-content">
			{#if store.state.status === 'selecting'}
				<RunSelectionView
					availableRuns={store.state.availableRuns}
					onSelectRun={handleSelectRun}
					onCancel={handleCancelSelection}
				/>
			{:else if store.state.status === 'countdown'}
				<div class="countdown-view">
					<Box borderColor="cyan" glow>
						<Stack gap={4} align="center">
							<span class="countdown-label">INITIATING HACK RUN</span>
							<span class="countdown-number" aria-live="polite" aria-atomic="true">
								{store.state.secondsLeft}
							</span>
							<span class="countdown-hint">Prepare for infiltration...</span>
						</Stack>
					</Box>
				</div>
			{:else if store.state.status === 'running' || store.state.status === 'node_typing' || store.state.status === 'node_result'}
				<ActiveRunView
					run={store.state.run}
					progress={store.state.progress}
					{currentNode}
					timeRemaining={store.state.timeRemaining}
					currentMultiplier={store.currentMultiplier}
					totalLoot={store.totalLoot}
					{typed}
					{typingStartTime}
					isTyping={store.state.status === 'node_typing'}
					onStartNode={handleStartNode}
					onNodeComplete={handleNodeComplete}
					onAbort={handleAbort}
				/>
			{:else if store.state.status === 'complete'}
				<RunCompleteView
					run={store.state.run}
					result={store.state.result}
					onNewRun={handleNewRun}
					onExit={handleExit}
				/>
			{:else if store.state.status === 'failed'}
				<div class="failed-view">
					<Box borderColor="red" glow>
						<Stack gap={4} align="center">
							<span class="failed-icon" aria-hidden="true">[X]</span>
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
								<button class="action-btn" onclick={handleNewRun}>TRY AGAIN</button>
								<button class="action-btn action-btn-secondary" onclick={handleExit}>EXIT</button>
							</div>
						</Stack>
					</Box>
				</div>
			{:else}
				<div class="loading-state" aria-live="polite">
					<span>Loading...</span>
				</div>
			{/if}
		</main>
	</div>
</Shell>
<NavigationBar active="arcade" />

<style>
	.hackrun-page {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
		min-height: 100dvh;
		padding: var(--space-4);
		padding-bottom: var(--space-16);
	}

	.page-content {
		flex: 1;
		display: flex;
		flex-direction: column;
		justify-content: flex-start;
		min-height: 0;
	}

	/* Mobile adjustments */
	@media (max-width: 480px) {
		.hackrun-page {
			padding: var(--space-2);
		}
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

	.action-btn:focus-visible {
		outline: 2px solid var(--color-accent);
		outline-offset: 2px;
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

	/* Responsive: countdown and failed views */
	@media (max-width: 480px) {
		.countdown-view,
		.failed-view {
			max-width: 100%;
			margin: var(--space-4) 0;
		}

		.countdown-number {
			font-size: 4rem;
		}

		.failed-actions {
			flex-direction: column;
		}

		.action-btn {
			width: 100%;
		}
	}
</style>
