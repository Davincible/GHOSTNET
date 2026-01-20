<script lang="ts">
	import type { HackRun, NodeProgress, HackRunNode } from '$lib/core/types/hackrun';
	import { Box } from '$lib/ui/terminal';
	import { Stack, Row } from '$lib/ui/layout';
	import { Button } from '$lib/ui/primitives';
	import { ProgressBar } from '$lib/ui/primitives';
	import { AmountDisplay } from '$lib/ui/data-display';
	import NodeMap from './NodeMap.svelte';
	import CurrentNodePanel from './CurrentNodePanel.svelte';

	interface Props {
		/** Current run */
		run: HackRun;
		/** Progress through nodes */
		progress: NodeProgress[];
		/** Current node index */
		currentNodeIndex: number;
		/** Time remaining in milliseconds */
		timeRemaining: number;
		/** Current accumulated multiplier */
		currentMultiplier: number;
		/** Total loot collected */
		totalLoot: bigint;
		/** Callback to start typing challenge */
		onStartNode?: () => void;
		/** Callback to abort run */
		onAbort?: () => void;
	}

	let {
		run,
		progress,
		currentNodeIndex,
		timeRemaining,
		currentMultiplier,
		totalLoot,
		onStartNode,
		onAbort
	}: Props = $props();

	// Get current node
	let currentNode = $derived(() => {
		const nodeId = progress[currentNodeIndex]?.nodeId;
		return run.nodes.find((n) => n.id === nodeId);
	});

	// Format time
	function formatTime(ms: number): string {
		const totalSeconds = Math.floor(ms / 1000);
		const minutes = Math.floor(totalSeconds / 60);
		const seconds = totalSeconds % 60;
		return `${minutes}:${seconds.toString().padStart(2, '0')}`;
	}

	// Time percentage
	let timePercent = $derived(Math.max(0, Math.min(100, (timeRemaining / run.timeLimit) * 100)));

	// Time warning states
	let timeWarning = $derived(timePercent < 30);
	let timeCritical = $derived(timePercent < 15);
</script>

<div class="active-run">
	<!-- Top bar: Timer and stats -->
	<Box variant="single" padding={2}>
		<Row justify="between" align="center" gap={4}>
			<div class="timer" class:warning={timeWarning} class:critical={timeCritical}>
				<span class="timer-label">TIME:</span>
				<span class="timer-value">{formatTime(timeRemaining)}</span>
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
			<Button variant="danger" size="sm" onclick={onAbort}>
				ABORT
			</Button>
		</Row>
		<div class="timer-bar">
			<ProgressBar value={timePercent} variant={timeCritical ? 'danger' : timeWarning ? 'warning' : 'default'} />
		</div>
	</Box>

	<!-- Main content: Node map and current node -->
	<div class="run-content">
		<div class="node-map-container">
			<NodeMap {run} {progress} currentIndex={currentNodeIndex} />
		</div>

		<div class="current-node-container">
			{#if currentNode()}
				<CurrentNodePanel node={currentNode()!} onStart={onStartNode} />
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
		0%, 100% { opacity: 1; }
		50% { opacity: 0.5; }
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
		grid-template-columns: 1fr 1fr;
		gap: var(--space-4);
		flex: 1;
		min-height: 0;
	}

	.node-map-container,
	.current-node-container {
		min-height: 300px;
	}

	/* Mobile layout */
	@media (max-width: 768px) {
		.run-content {
			grid-template-columns: 1fr;
		}
	}
</style>
