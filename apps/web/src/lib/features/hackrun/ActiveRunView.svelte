<script lang="ts">
	import type { HackRun, NodeProgress, HackRunNode, NodeResult } from '$lib/core/types/hackrun';
	import { Box } from '$lib/ui/terminal';
	import { Stack } from '$lib/ui/layout';
	import { Button } from '$lib/ui/primitives';
	import { ProgressBar } from '$lib/ui/primitives';
	import { AmountDisplay } from '$lib/ui/data-display';
	import { formatCountdown, calculateWPM, calculateAccuracy } from '$lib/core/utils';
	import NodeMap from './NodeMap.svelte';
	import CurrentNodePanel from './CurrentNodePanel.svelte';

	interface Props {
		/** Current run */
		run: HackRun;
		/** Progress through nodes */
		progress: NodeProgress[];
		/** Current node being typed (null if between nodes) */
		currentNode: HackRunNode | null;
		/** Time remaining in milliseconds */
		timeRemaining: number;
		/** Current accumulated multiplier */
		currentMultiplier: number;
		/** Total loot collected */
		totalLoot: bigint;
		/** Current typed input (for typing mode) */
		typed: string;
		/** When typing started (for WPM calculation) */
		typingStartTime: number;
		/** Whether currently in typing mode */
		isTyping: boolean;
		/** Callback to start typing challenge */
		onStartNode?: () => void;
		/** Callback when node is completed */
		onNodeComplete?: (result: NodeResult) => void;
		/** Callback to abort run */
		onAbort?: () => void;
	}

	let {
		run,
		progress,
		currentNode,
		timeRemaining,
		currentMultiplier,
		totalLoot,
		typed,
		typingStartTime,
		isTyping,
		onStartNode,
		onNodeComplete,
		onAbort,
	}: Props = $props();

	// Get current node index from progress
	const currentNodeIndex = $derived(progress.findIndex((p) => p.status === 'current'));

	// Time percentage
	const timePercent = $derived(Math.max(0, Math.min(100, (timeRemaining / run.timeLimit) * 100)));

	// Time warning states
	const timeWarning = $derived(timePercent < 30);
	const timeCritical = $derived(timePercent < 15);

	// Check if typing is complete
	$effect(() => {
		if (isTyping && currentNode && typed.length >= currentNode.challenge.command.length) {
			const command = currentNode.challenge.command;
			const elapsed = Date.now() - typingStartTime;
			const accuracy = calculateAccuracy(typed, command);
			const wpm = calculateWPM(typed.length, elapsed);

			// Success if accuracy is above 90%
			const success = accuracy >= 0.9;

			// Calculate rewards based on node
			const multiplierGained = success ? currentNode.reward.value : 0;
			const lootGained =
				success && currentNode.reward.type === 'loot'
					? BigInt(currentNode.reward.value) * 10n ** 18n
					: 0n;

			const result: NodeResult = {
				success,
				accuracy,
				wpm,
				timeElapsed: elapsed,
				lootGained,
				multiplierGained,
			};

			onNodeComplete?.(result);
		}
	});

	// Get variant for progress bar
	const progressVariant = $derived.by(() => {
		if (timeCritical) return 'danger';
		if (timeWarning) return 'warning';
		return 'default';
	});
</script>

<div class="active-run">
	<!-- Top bar: Timer and stats -->
	<Box variant="single" padding={2}>
		<div class="top-bar">
			<div class="timer" class:warning={timeWarning} class:critical={timeCritical}>
				<span class="timer-label">TIME:</span>
				<span class="timer-value" aria-live="polite">{formatCountdown(timeRemaining)}</span>
			</div>
			<div class="stat">
				<span class="stat-label">MULT:</span>
				<span class="stat-value multiplier">{currentMultiplier.toFixed(2)}x</span>
			</div>
			<div class="stat">
				<span class="stat-label">LOOT:</span>
				<span class="stat-value loot">
					<AmountDisplay amount={totalLoot} format="compact" />
				</span>
			</div>
			<Button variant="danger" size="sm" onclick={onAbort}>ABORT</Button>
		</div>
		<div class="timer-bar">
			<ProgressBar value={timePercent} variant={progressVariant} />
		</div>
	</Box>

	<!-- Main content -->
	<div class="run-content">
		<!-- Node map -->
		<div class="node-map-container">
			<NodeMap {run} {progress} currentIndex={currentNodeIndex} />
		</div>

		<!-- Current node / typing interface -->
		<div class="current-node-container">
			{#if isTyping && currentNode}
				<!-- Typing interface -->
				<Box variant="double" borderColor="cyan" title="TYPE COMMAND" padding={3}>
					<Stack gap={3}>
						<div class="command-display">
							<div class="command-target" aria-label="Command to type">
								{#each currentNode.challenge.command.split('') as char, i}
									<span
										class="char"
										class:correct={typed[i] === char}
										class:incorrect={typed[i] !== undefined && typed[i] !== char}
										class:current={i === typed.length}>{char}</span
									>
								{/each}
							</div>
						</div>

						<div class="typing-stats">
							<span class="typing-stat">
								<span class="typing-label">ACCURACY:</span>
								<span class="typing-value"
									>{Math.round(
										calculateAccuracy(typed, currentNode.challenge.command) * 100
									)}%</span
								>
							</span>
							<span class="typing-stat">
								<span class="typing-label">WPM:</span>
								<span class="typing-value"
									>{calculateWPM(typed.length, Date.now() - typingStartTime)}</span
								>
							</span>
						</div>

						<p class="typing-hint">Type the command above. Press BACKSPACE to correct errors.</p>
					</Stack>
				</Box>
			{:else if currentNode}
				<!-- Current node panel (not typing yet) -->
				<CurrentNodePanel node={currentNode} onStart={onStartNode} />
			{:else}
				<!-- Between nodes or loading -->
				<Box variant="single" padding={3}>
					<div class="loading-state">
						<span class="loading-text">LOADING NODE DATA...</span>
					</div>
				</Box>
			{/if}
		</div>
	</div>
</div>

<style>
	.active-run {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		height: 100%;
	}

	.top-bar {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-4);
		flex-wrap: wrap;
	}

	.timer {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.timer-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.timer-value {
		color: var(--color-text-primary);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		font-variant-numeric: tabular-nums;
	}

	.timer.warning .timer-value {
		color: var(--color-amber);
	}

	.timer.critical .timer-value {
		color: var(--color-loss);
		animation: pulse-danger 0.5s ease-in-out infinite;
	}

	@keyframes pulse-danger {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.5;
		}
	}

	.stat {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.stat-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.stat-value {
		color: var(--color-text-primary);
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
	}

	.stat-value.multiplier {
		color: var(--color-cyan);
	}

	.stat-value.loot {
		color: var(--color-profit);
	}

	.timer-bar {
		margin-top: var(--space-2);
	}

	.run-content {
		display: grid;
		grid-template-columns: minmax(280px, 1fr) minmax(320px, 1.2fr);
		gap: var(--space-4);
		flex: 1;
		min-height: 0;
		align-items: start;
	}

	.node-map-container {
		min-height: 0;
		max-height: 100%;
		overflow-y: auto;
	}

	.current-node-container {
		min-height: 0;
		position: sticky;
		top: 0;
	}

	/* Typing interface styles */
	.command-display {
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
	}

	.command-target {
		font-size: var(--text-lg);
		font-family: var(--font-mono);
		letter-spacing: 0.1em;
		word-break: break-all;
	}

	.char {
		color: var(--color-text-muted);
		transition: color var(--duration-fast) var(--ease-default);
	}

	.char.correct {
		color: var(--color-profit);
	}

	.char.incorrect {
		color: var(--color-loss);
		text-decoration: underline;
	}

	.char.current {
		background: var(--color-cyan-glow);
		animation: blink-cursor 0.5s step-end infinite;
	}

	@keyframes blink-cursor {
		0%,
		100% {
			background: var(--color-cyan-glow);
		}
		50% {
			background: transparent;
		}
	}

	.typing-stats {
		display: flex;
		gap: var(--space-4);
	}

	.typing-stat {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.typing-label {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
	}

	.typing-value {
		color: var(--color-text-primary);
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		font-variant-numeric: tabular-nums;
	}

	.typing-hint {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		text-align: center;
		margin: 0;
	}

	.loading-state {
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: 200px;
	}

	.loading-text {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
		letter-spacing: var(--tracking-wider);
		animation: pulse 1s ease-in-out infinite;
	}

	@keyframes pulse {
		0%,
		100% {
			opacity: 0.5;
		}
		50% {
			opacity: 1;
		}
	}

	/* Tablet/narrow layout - switch to stacked */
	@media (max-width: 900px) {
		.run-content {
			grid-template-columns: 1fr;
			grid-template-rows: auto 1fr;
		}

		.node-map-container {
			order: 2;
			max-height: 250px;
			overflow-y: auto;
		}

		.current-node-container {
			order: 1;
			position: static;
		}

		.top-bar {
			gap: var(--space-2);
		}

		.stat-label {
			display: none;
		}

		.command-target {
			font-size: var(--text-base);
			letter-spacing: 0.05em;
		}
	}

	/* Mobile layout */
	@media (max-width: 600px) {
		.active-run {
			gap: var(--space-2);
		}

		.top-bar {
			flex-wrap: wrap;
			justify-content: center;
			gap: var(--space-2);
		}

		.timer {
			width: 100%;
			justify-content: center;
			order: 1;
		}

		.stat {
			order: 2;
		}

		/* Show labels again on mobile since they're stacked */
		.stat-label {
			display: inline;
		}

		.timer-label,
		.stat-label {
			font-size: 10px;
		}

		.node-map-container {
			max-height: 180px;
		}

		.command-display {
			padding: var(--space-2);
		}

		.command-target {
			font-size: var(--text-sm);
			letter-spacing: 0.02em;
		}
	}

	/* Small mobile */
	@media (max-width: 400px) {
		.timer-value {
			font-size: var(--text-base);
		}

		.stat-value {
			font-size: var(--text-xs);
		}

		.typing-stats {
			flex-direction: column;
			gap: var(--space-1);
		}

		.typing-hint {
			font-size: 10px;
		}

		.node-map-container {
			max-height: 150px;
		}
	}
</style>
