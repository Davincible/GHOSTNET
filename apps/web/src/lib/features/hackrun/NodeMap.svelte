<script lang="ts">
	import type { NodeProgress, HackRunNode } from '$lib/core/types/hackrun';

	interface Props {
		/** All nodes in the run */
		nodes: HackRunNode[];
		/** Current progress for each node */
		progress: NodeProgress[];
	}

	let { nodes, progress }: Props = $props();

	// Get main path nodes (exclude backdoors)
	let mainNodes = $derived(
		nodes.filter((n) => n.type !== 'backdoor').sort((a, b) => a.position - b.position)
	);

	// Get status for each node
	function getNodeStatus(nodeId: string): NodeProgress['status'] {
		const p = progress.find((p) => p.nodeId === nodeId);
		return p?.status ?? 'pending';
	}

	// Get display character for status
	function getStatusChar(status: NodeProgress['status']): string {
		switch (status) {
			case 'completed':
				return '\u2713'; // ✓
			case 'current':
				return '\u25CF'; // ●
			case 'failed':
				return '\u2717'; // ✗
			case 'skipped':
				return '\u2192'; // →
			default:
				return ' ';
		}
	}
</script>

<div class="node-map" role="navigation" aria-label="Run progress">
	<div class="nodes-container">
		{#each mainNodes as node, index (node.id)}
			{@const status = getNodeStatus(node.id)}
			{@const statusChar = getStatusChar(status)}

			{#if index > 0}
				<span
					class="connector"
					class:connector-completed={status === 'completed' || status === 'skipped'}>──────</span
				>
			{/if}

			<div
				class="node"
				class:node-completed={status === 'completed'}
				class:node-current={status === 'current'}
				class:node-failed={status === 'failed'}
				class:node-skipped={status === 'skipped'}
				class:node-pending={status === 'pending'}
				aria-current={status === 'current' ? 'step' : undefined}
			>
				<span class="node-bracket">[</span>
				<span class="node-status">{statusChar}</span>
				<span class="node-bracket">]</span>
			</div>
		{/each}
	</div>

	<!-- Position labels -->
	<div class="labels-container">
		{#each mainNodes as node, index (node.id)}
			{#if index > 0}
				<span class="label-spacer"></span>
			{/if}
			<span class="node-label">{node.position}</span>
		{/each}
	</div>
</div>

<style>
	.node-map {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-1);
		padding: var(--space-3) var(--space-2);
		font-family: var(--font-mono);
		overflow-x: auto;
	}

	.nodes-container {
		display: flex;
		align-items: center;
		white-space: nowrap;
	}

	.connector {
		color: var(--color-border-default);
		letter-spacing: -0.1em;
		font-size: var(--text-sm);
	}

	.connector-completed {
		color: var(--color-profit);
	}

	.node {
		display: flex;
		align-items: center;
		font-size: var(--text-base);
		transition: all var(--duration-fast) var(--ease-default);
	}

	.node-bracket {
		color: inherit;
	}

	.node-status {
		width: 1ch;
		text-align: center;
	}

	/* Node states */
	.node-pending {
		color: var(--color-text-tertiary);
	}

	.node-completed {
		color: var(--color-profit);
	}

	.node-current {
		color: var(--color-accent);
		animation: pulse-node 1.5s ease-in-out infinite;
	}

	.node-failed {
		color: var(--color-red);
	}

	.node-skipped {
		color: var(--color-amber);
	}

	/* Labels */
	.labels-container {
		display: flex;
		align-items: center;
		white-space: nowrap;
	}

	.label-spacer {
		width: 6ch; /* Match connector width */
		letter-spacing: -0.1em;
	}

	.node-label {
		width: 3ch; /* Match node width */
		text-align: center;
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
	}

	@keyframes pulse-node {
		0%,
		100% {
			opacity: 1;
			text-shadow: 0 0 4px var(--color-accent);
		}
		50% {
			opacity: 0.7;
			text-shadow: 0 0 8px var(--color-accent);
		}
	}
</style>
