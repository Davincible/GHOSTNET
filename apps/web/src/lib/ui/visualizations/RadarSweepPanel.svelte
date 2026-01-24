<script lang="ts">
	import { onMount } from 'svelte';
	import { Box } from '$lib/ui/terminal';
	import { Row } from '$lib/ui/layout';
	import { Badge, Countdown } from '$lib/ui/primitives';
	import RadarSweep from './RadarSweep.svelte';

	interface Props {
		nextScanTime?: number;
		operatorCount?: number;
		survivalRate?: number;
	}

	let {
		nextScanTime = Date.now() + 60000,
		operatorCount = 1247,
		survivalRate = 87.3,
	}: Props = $props();

	let containerWidth = $state(0);
	let containerEl: HTMLDivElement;

	let visualSize = $derived(Math.min(containerWidth - 24, 380));

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
	<Box title="TRACE SCANNER" borderColor="bright">
		<div class="panel-header">
			<Row justify="between" align="center">
				<div class="stat">
					<span class="stat-label">NEXT SCAN</span>
					<Countdown targetTime={nextScanTime} urgentThreshold={30} />
				</div>
				<Badge variant="warning" pulse>SCANNING</Badge>
			</Row>
		</div>

		<div class="viz-container">
			{#if visualSize > 100}
				<RadarSweep width={visualSize} height={visualSize} sweepDuration={12} />
			{/if}
		</div>

		<div class="panel-footer">
			<Row justify="between" align="center">
				<div class="stats-row">
					<div class="mini-stat">
						<span class="mini-label">TARGETS</span>
						<span class="mini-value">{operatorCount}</span>
					</div>
					<div class="mini-stat">
						<span class="mini-label">SURVIVAL</span>
						<span class="mini-value survival">{survivalRate.toFixed(1)}%</span>
					</div>
				</div>
				<span class="footer-text">SWEEP ACTIVE</span>
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
		gap: var(--space-1);
	}

	.stat-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.viz-container {
		display: flex;
		justify-content: center;
		align-items: center;
		min-height: 300px;
	}

	.panel-footer {
		padding-top: var(--space-3);
		border-top: 1px solid var(--color-border-subtle);
		margin-top: var(--space-2);
	}

	.stats-row {
		display: flex;
		gap: var(--space-4);
	}

	.mini-stat {
		display: flex;
		flex-direction: column;
		gap: var(--space-0-5);
	}

	.mini-label {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wider);
	}

	.mini-value {
		font-size: var(--text-sm);
		color: var(--color-text-primary);
		font-variant-numeric: tabular-nums;
	}

	.mini-value.survival {
		color: var(--color-profit, #00ff88);
	}

	.footer-text {
		font-size: var(--text-xs);
		color: var(--color-amber, #ffb000);
		letter-spacing: var(--tracking-wider);
		animation: pulse 1s ease-in-out infinite;
	}

	@keyframes pulse {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.5;
		}
	}
</style>
