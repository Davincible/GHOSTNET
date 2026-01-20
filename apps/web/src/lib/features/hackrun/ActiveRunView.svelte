<script lang="ts">
	import { Stack } from '$lib/ui/layout';
	import RunProgress from './RunProgress.svelte';
	import NodeMap from './NodeMap.svelte';
	import CurrentNodePanel from './CurrentNodePanel.svelte';
	import type { HackRun, HackRunNode, NodeProgress, NodeResult } from '$lib/core/types/hackrun';

	interface Props {
		/** The active run */
		run: HackRun;
		/** Current node (when in node_typing state) */
		currentNode: HackRunNode | null;
		/** Progress for all nodes */
		progress: NodeProgress[];
		/** Time remaining in milliseconds */
		timeRemaining: number;
		/** Current accumulated multiplier */
		currentMultiplier: number;
		/** Total loot collected */
		totalLoot: bigint;
		/** User's typed input (for typing state) */
		typed: string;
		/** When typing started */
		typingStartTime: number;
		/** Whether user is in typing mode */
		isTyping: boolean;
		/** Callback when node typing is complete */
		onNodeComplete: (result: NodeResult) => void;
		/** Callback to start typing on current node */
		onStartNode: () => void;
	}

	let {
		run,
		currentNode,
		progress,
		timeRemaining,
		currentMultiplier,
		totalLoot,
		typed,
		typingStartTime,
		isTyping,
		onNodeComplete,
		onStartNode,
	}: Props = $props();

	// Get current node from progress if not explicitly provided
	let displayNode = $derived.by(() => {
		if (currentNode) return currentNode;
		const currentProgress = progress.find((p) => p.status === 'current');
		if (!currentProgress) return null;
		return run.nodes.find((n) => n.id === currentProgress.nodeId) ?? null;
	});
</script>

<div class="active-run-view">
	<Stack gap={0}>
		<!-- Progress Bar at Top -->
		<RunProgress
			difficulty={run.difficulty}
			{timeRemaining}
			timeLimit={run.timeLimit}
			{currentMultiplier}
			{totalLoot}
		/>

		<!-- Node Map -->
		<div class="map-section">
			<NodeMap nodes={run.nodes} {progress} />
		</div>

		<!-- Current Node / Action Area -->
		<div class="node-section">
			{#if isTyping && displayNode}
				<CurrentNodePanel
					node={displayNode}
					{typed}
					startTime={typingStartTime}
					onComplete={onNodeComplete}
				/>
			{:else if displayNode && !isTyping}
				<!-- Waiting to start node -->
				<div class="node-preview-panel">
					<div class="preview-header">
						<span class="preview-title">NEXT TARGET: {displayNode.name}</span>
					</div>
					<p class="preview-description">{displayNode.description}</p>
					<div class="preview-reward">
						<span class="reward-label">Reward:</span>
						<span class="reward-value">{displayNode.reward.label}</span>
					</div>
					<button class="start-node-btn" onclick={onStartNode}> BREACH NODE </button>
				</div>
			{:else}
				<!-- No current node (shouldn't happen) -->
				<div class="empty-state">
					<span>Loading node data...</span>
				</div>
			{/if}
		</div>

		<!-- Footer -->
		<div class="footer-hint">
			<span class="hint-text">Press <kbd>Esc</kbd> to abort run</span>
		</div>
	</Stack>
</div>

<style>
	.active-run-view {
		max-width: 700px;
		margin: 0 auto;
		width: 100%;
	}

	.map-section {
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-subtle);
		border-top: none;
	}

	.node-section {
		margin-top: var(--space-3);
	}

	/* Node Preview Panel (before typing) */
	.node-preview-panel {
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-subtle);
		padding: var(--space-4);
		text-align: center;
	}

	.preview-header {
		margin-bottom: var(--space-3);
	}

	.preview-title {
		color: var(--color-accent);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	.preview-description {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		margin: 0 0 var(--space-3) 0;
		font-style: italic;
	}

	.preview-reward {
		display: flex;
		justify-content: center;
		align-items: baseline;
		gap: var(--space-2);
		margin-bottom: var(--space-4);
		padding: var(--space-2);
		background: var(--color-bg-primary);
		border: 1px solid var(--color-border-subtle);
	}

	.reward-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
	}

	.reward-value {
		color: var(--color-profit);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
	}

	.start-node-btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		padding: var(--space-3) var(--space-6);
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

	.start-node-btn:hover {
		background: var(--color-accent);
		color: var(--color-bg-void);
		box-shadow: var(--shadow-glow-accent);
	}

	.start-node-btn:active {
		transform: translateY(1px);
	}

	/* Empty State */
	.empty-state {
		padding: var(--space-8);
		text-align: center;
		color: var(--color-text-tertiary);
	}

	/* Footer */
	.footer-hint {
		text-align: center;
		padding: var(--space-4);
	}

	.hint-text {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
	}

	.hint-text kbd {
		background: var(--color-bg-tertiary);
		padding: var(--space-1) var(--space-2);
		border: 1px solid var(--color-border-default);
		margin: 0 var(--space-1);
	}
</style>
