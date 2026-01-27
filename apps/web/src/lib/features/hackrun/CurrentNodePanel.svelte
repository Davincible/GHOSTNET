<script lang="ts">
	import type { HackRunNode } from '$lib/core/types/hackrun';
	import { NODE_TYPE_CONFIG } from '$lib/core/types/hackrun';
	import { Box } from '$lib/ui/terminal';
	import { Stack } from '$lib/ui/layout';
	import { Button } from '$lib/ui/primitives';

	interface Props {
		/** Current node to display */
		node: HackRunNode;
		/** Callback to start the typing challenge */
		onStart?: () => void;
	}

	let { node, onStart }: Props = $props();

	const config = $derived(NODE_TYPE_CONFIG[node.type]);

	// Risk color mapping
	const RISK_COLORS: Record<string, string> = {
		low: 'var(--color-profit)',
		medium: 'var(--color-amber)',
		high: 'var(--color-loss)',
		extreme: 'var(--color-red)',
	};

	const riskColor = $derived(RISK_COLORS[node.risk] ?? 'var(--color-text-tertiary)');
</script>

<Box variant="double" borderColor="cyan" title="CURRENT NODE" padding={3}>
	<Stack gap={3}>
		<!-- Node header -->
		<div class="node-header">
			<div class="node-icon" aria-hidden="true">{config.icon}</div>
			<div class="node-title">
				<span class="node-name">{node.name}</span>
				<span class="node-type">{node.type.replace('_', ' ').toUpperCase()}</span>
			</div>
		</div>

		<!-- Description -->
		<p class="node-description">{node.description}</p>

		<!-- Stats -->
		<div class="node-stats" role="list" aria-label="Node statistics">
			<div class="stat-row" role="listitem">
				<span class="stat-label">RISK LEVEL:</span>
				<span class="stat-value" style:color={riskColor}>{node.risk.toUpperCase()}</span>
			</div>
			<div class="stat-row" role="listitem">
				<span class="stat-label">REWARD:</span>
				<span class="stat-value reward">{node.reward.label}</span>
			</div>
			<div class="stat-row" role="listitem">
				<span class="stat-label">TIME LIMIT:</span>
				<span class="stat-value">{node.challenge.timeLimit}s</span>
			</div>
		</div>

		<!-- Challenge preview -->
		<div class="challenge-preview">
			<span class="challenge-label">COMMAND TO TYPE:</span>
			<code class="challenge-command">{node.challenge.command}</code>
		</div>

		<!-- Start button -->
		<Button variant="primary" fullWidth onclick={onStart}>[SPACE] BEGIN INFILTRATION</Button>

		<!-- Warning for high-risk nodes -->
		{#if node.risk === 'high' || node.risk === 'extreme'}
			<div class="warning-box" style:--warning-color={riskColor} role="alert">
				<span class="warning-icon" aria-hidden="true">[!]</span>
				<span class="warning-text">
					{#if node.risk === 'extreme'}
						EXTREME RISK: Failure may terminate run
					{:else}
						HIGH RISK: Proceed with caution
					{/if}
				</span>
			</div>
		{/if}
	</Stack>
</Box>

<style>
	.node-header {
		display: flex;
		align-items: center;
		gap: var(--space-3);
	}

	.node-icon {
		font-size: var(--text-2xl);
		font-weight: var(--font-bold);
		color: var(--color-cyan);
	}

	.node-title {
		display: flex;
		flex-direction: column;
	}

	.node-name {
		color: var(--color-text-primary);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	.node-type {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-widest);
	}

	.node-description {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		font-style: italic;
		margin: 0;
		padding-left: var(--space-2);
		border-left: 2px solid var(--color-border-subtle);
	}

	.node-stats {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.stat-row {
		display: flex;
		justify-content: space-between;
		font-size: var(--text-sm);
	}

	.stat-label {
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.stat-value {
		color: var(--color-text-primary);
		font-weight: var(--font-medium);
	}

	.stat-value.reward {
		color: var(--color-profit);
	}

	.challenge-preview {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		padding: var(--space-2);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
	}

	.challenge-label {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.challenge-command {
		color: var(--color-cyan);
		font-size: var(--text-sm);
		font-family: var(--font-mono);
		word-break: break-all;
	}

	.warning-box {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--color-red-glow);
		border: 1px solid var(--warning-color);
	}

	.warning-icon {
		color: var(--warning-color);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
	}

	.warning-text {
		color: var(--warning-color);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	/* Mobile responsiveness */
	@media (max-width: 768px) {
		.node-icon {
			font-size: var(--text-xl);
		}

		.node-name {
			font-size: var(--text-base);
		}

		.challenge-command {
			font-size: var(--text-xs);
		}
	}

	@media (max-width: 480px) {
		.node-header {
			gap: var(--space-2);
		}

		.node-icon {
			font-size: var(--text-lg);
		}

		.node-name {
			font-size: var(--text-sm);
		}

		.node-description {
			font-size: var(--text-xs);
		}

		.stat-row {
			font-size: var(--text-xs);
		}

		.challenge-preview {
			padding: var(--space-1);
		}

		.challenge-label {
			font-size: 10px;
		}

		.warning-box {
			padding: var(--space-1);
		}

		.warning-icon {
			font-size: var(--text-base);
		}

		.warning-text {
			font-size: 10px;
		}
	}
</style>
