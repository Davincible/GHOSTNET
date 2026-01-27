<script lang="ts">
	import type { HackRun, NodeProgress, HackRunNode } from '$lib/core/types/hackrun';
	import { NODE_TYPE_CONFIG } from '$lib/core/types/hackrun';
	import { Box } from '$lib/ui/terminal';
	import { Stack } from '$lib/ui/layout';

	interface Props {
		/** Current run configuration */
		run: HackRun;
		/** Progress through nodes */
		progress: NodeProgress[];
		/** Currently active node index */
		currentIndex: number;
	}

	let { run, progress, currentIndex }: Props = $props();

	// Get main path nodes (sorted by position, excluding backdoors)
	const mainNodes = $derived(
		run.nodes.filter((n) => n.type !== 'backdoor').sort((a, b) => a.position - b.position)
	);

	// Get node status from progress
	function getNodeStatus(nodeId: string): string {
		const p = progress.find((p) => p.nodeId === nodeId);
		return p?.status ?? 'pending';
	}

	// Get node icon from config
	function getNodeIcon(node: HackRunNode): string {
		return NODE_TYPE_CONFIG[node.type].icon;
	}
</script>

<Box variant="single" title="NETWORK MAP" padding={3}>
	<Stack gap={2}>
		<div class="map-container" role="list" aria-label="Network nodes">
			{#each mainNodes as node, i (node.id)}
				{@const status = getNodeStatus(node.id)}
				{@const isHidden = node.hidden && status === 'pending' && i > currentIndex + 1}

				<!-- Connection line -->
				{#if i > 0}
					<div
						class="connection-line"
						class:completed={status === 'completed' || status === 'skipped'}
						aria-hidden="true"
					></div>
				{/if}

				<!-- Node -->
				<div
					class="node"
					class:current={status === 'current'}
					class:completed={status === 'completed'}
					class:failed={status === 'failed'}
					class:skipped={status === 'skipped'}
					class:hidden={isHidden}
					role="listitem"
					aria-current={status === 'current' ? 'step' : undefined}
				>
					<div class="node-icon" aria-hidden="true">
						{#if isHidden}
							[?]
						{:else}
							{getNodeIcon(node)}
						{/if}
					</div>
					<div class="node-info">
						{#if isHidden}
							<span class="node-name">UNKNOWN</span>
							<span class="node-type">SCANNING...</span>
						{:else}
							<span class="node-name">{node.name}</span>
							<span class="node-type">{node.type.replace('_', ' ').toUpperCase()}</span>
						{/if}
					</div>
					<div class="node-status-indicator" aria-label="Status: {status}">
						{#if status === 'completed'}
							<span class="status-icon completed">[OK]</span>
						{:else if status === 'failed'}
							<span class="status-icon failed">[XX]</span>
						{:else if status === 'skipped'}
							<span class="status-icon skipped">[>>]</span>
						{:else if status === 'current'}
							<span class="status-icon current">[>>]</span>
						{:else}
							<span class="status-icon pending">[..]</span>
						{/if}
					</div>
				</div>
			{/each}
		</div>

		<!-- Legend -->
		<div class="legend" aria-label="Map legend">
			<span class="legend-item">
				<span class="legend-icon completed" aria-hidden="true">[OK]</span>
				<span>CLEARED</span>
			</span>
			<span class="legend-item">
				<span class="legend-icon current" aria-hidden="true">[>>]</span>
				<span>ACTIVE</span>
			</span>
			<span class="legend-item">
				<span class="legend-icon pending" aria-hidden="true">[..]</span>
				<span>LOCKED</span>
			</span>
		</div>
	</Stack>
</Box>

<style>
	.map-container {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.connection-line {
		width: 2px;
		height: var(--space-3);
		margin-left: var(--space-4);
		background: var(--color-border-subtle);
	}

	.connection-line.completed {
		background: var(--color-profit-dim);
	}

	.node {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		border: 1px solid var(--color-border-subtle);
		background: var(--color-bg-secondary);
		transition: all var(--duration-fast) var(--ease-default);
	}

	.node.current {
		border-color: var(--color-cyan);
		background: var(--color-cyan-glow);
		box-shadow: 0 0 8px var(--color-cyan-glow);
	}

	.node.completed {
		border-color: var(--color-profit-dim);
		background: var(--color-profit-glow);
	}

	.node.failed {
		border-color: var(--color-red-dim);
		background: var(--color-red-glow);
	}

	.node.skipped {
		border-color: var(--color-amber-dim);
		opacity: 0.6;
	}

	.node.hidden {
		opacity: 0.4;
	}

	.node-icon {
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		color: var(--color-text-tertiary);
		min-width: 2.5rem;
		text-align: center;
	}

	.node.current .node-icon {
		color: var(--color-cyan);
	}

	.node.completed .node-icon {
		color: var(--color-profit);
	}

	.node.failed .node-icon {
		color: var(--color-loss);
	}

	.node-info {
		flex: 1;
		display: flex;
		flex-direction: column;
		min-width: 0;
	}

	.node-name {
		color: var(--color-text-primary);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wider);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.node-type {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.node-status-indicator {
		font-size: var(--text-sm);
	}

	.status-icon {
		font-weight: var(--font-bold);
	}

	.status-icon.completed {
		color: var(--color-profit);
	}

	.status-icon.failed {
		color: var(--color-loss);
	}

	.status-icon.skipped {
		color: var(--color-amber);
	}

	.status-icon.current {
		color: var(--color-cyan);
		animation: blink 1s step-end infinite;
	}

	.status-icon.pending {
		color: var(--color-text-muted);
	}

	@keyframes blink {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.3;
		}
	}

	.legend {
		display: flex;
		gap: var(--space-4);
		padding-top: var(--space-2);
		border-top: 1px solid var(--color-border-subtle);
		font-size: var(--text-xs);
		color: var(--color-text-muted);
	}

	.legend-item {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.legend-icon {
		font-weight: var(--font-bold);
	}

	.legend-icon.completed {
		color: var(--color-profit);
	}

	.legend-icon.current {
		color: var(--color-cyan);
	}

	.legend-icon.pending {
		color: var(--color-text-muted);
	}

	/* Mobile responsiveness */
	@media (max-width: 768px) {
		.node {
			padding: var(--space-1) var(--space-2);
		}

		.node-icon {
			font-size: var(--text-base);
			min-width: 2rem;
		}

		.node-name {
			font-size: var(--text-xs);
		}

		.node-type {
			font-size: 10px;
		}

		.node-status-indicator {
			font-size: var(--text-xs);
		}

		.connection-line {
			height: var(--space-2);
		}

		.legend {
			flex-wrap: wrap;
			gap: var(--space-2);
			font-size: 10px;
		}
	}

	@media (max-width: 480px) {
		.node-icon {
			display: none;
		}

		.legend-item span:last-child {
			display: none;
		}
	}
</style>
