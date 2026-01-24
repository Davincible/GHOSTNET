<script lang="ts">
	import { onMount } from 'svelte';
	import { Box } from '$lib/ui/terminal';
	import { Row } from '$lib/ui/layout';
	import { Badge } from '$lib/ui/primitives';
	import HeartbeatMonitor from './HeartbeatMonitor.svelte';

	interface Props {
		status?: 'healthy' | 'warning' | 'critical';
	}

	let { status = 'healthy' }: Props = $props();

	let containerWidth = $state(0);
	let containerEl: HTMLDivElement;

	let visualWidth = $derived(Math.min(containerWidth - 24, 600));
	let visualHeight = $derived(Math.min(visualWidth * 0.6, 280));

	let statusBadge = $derived.by(() => {
		switch (status) {
			case 'healthy':
				return { variant: 'success' as const, text: 'NOMINAL', glow: true };
			case 'warning':
				return { variant: 'warning' as const, text: 'ELEVATED', glow: false };
			case 'critical':
				return { variant: 'danger' as const, text: 'CRITICAL', glow: true };
		}
	});

	onMount(() => {
		if (containerEl) {
			containerWidth = containerEl.clientWidth;
		}

		const observer = new ResizeObserver((entries) => {
			for (const entry of entries) {
				containerWidth = entry.contentRect.width;
			}
		});

		if (containerEl) observer.observe(containerEl);
		return () => observer.disconnect();
	});
</script>

<div class="panel-wrapper" bind:this={containerEl}>
	<Box title="PROTOCOL VITALS" borderColor="bright">
		<div class="panel-header">
			<Row justify="between" align="center">
				<div class="stat">
					<span class="stat-label">SYSTEM STATUS</span>
					<span class="stat-value">{statusBadge.text}</span>
				</div>
				<Badge variant={statusBadge.variant} glow={statusBadge.glow}>{statusBadge.text}</Badge>
			</Row>
		</div>

		<div class="viz-container">
			{#if visualWidth > 100}
				<HeartbeatMonitor width={visualWidth} height={visualHeight} />
			{/if}
		</div>

		<div class="panel-footer">
			<Row justify="between" align="center">
				<div class="metrics">
					<span class="metric">
						<span class="metric-dot tvl"></span>
						TVL
					</span>
					<span class="metric">
						<span class="metric-dot operators"></span>
						OPERATORS
					</span>
					<span class="metric">
						<span class="metric-dot trace"></span>
						TRACE
					</span>
					<span class="metric">
						<span class="metric-dot yield"></span>
						YIELD
					</span>
				</div>
				<span class="footer-text">LIVE TELEMETRY</span>
			</Row>
		</div>
	</Box>
</div>

<style>
	.panel-wrapper {
		width: 100%;
	}

	.panel-header {
		padding-bottom: var(--space-3);
		border-bottom: 1px solid var(--color-border-subtle);
		margin-bottom: var(--space-2);
	}

	.stat {
		display: flex;
		flex-direction: column;
		gap: var(--space-0-5);
	}

	.stat-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.stat-value {
		font-size: var(--text-lg);
		font-weight: var(--font-medium);
		color: var(--color-text-primary);
	}

	.viz-container {
		display: flex;
		justify-content: center;
		align-items: center;
		min-height: 200px;
	}

	.panel-footer {
		padding-top: var(--space-3);
		border-top: 1px solid var(--color-border-subtle);
		margin-top: var(--space-2);
	}

	.metrics {
		display: flex;
		gap: var(--space-3);
	}

	.metric {
		display: flex;
		align-items: center;
		gap: var(--space-1);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wide);
	}

	.metric-dot {
		width: 6px;
		height: 6px;
		border-radius: 50%;
	}

	.metric-dot.tvl {
		background: var(--color-accent, #00e5cc);
	}
	.metric-dot.operators {
		background: var(--color-profit, #00ff88);
	}
	.metric-dot.trace {
		background: var(--color-red, #ff3366);
	}
	.metric-dot.yield {
		background: var(--color-amber, #ffb000);
	}

	.footer-text {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}
</style>
