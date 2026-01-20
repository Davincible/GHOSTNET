<script lang="ts">
	import { onMount } from 'svelte';
	import { Box } from '$lib/ui/terminal';
	import { Row } from '$lib/ui/layout';
	import { Badge } from '$lib/ui/primitives';
	import OrbitalTracker from './OrbitalTracker.svelte';

	interface Props {
		operatorCount?: number;
	}

	let { operatorCount = 1247 }: Props = $props();

	let containerWidth = $state(0);
	let containerEl: HTMLDivElement;

	let visualSize = $derived(Math.min(containerWidth - 24, 400));

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
	<Box title="ORBITAL STATUS" borderColor="bright">
		<div class="panel-header">
			<Row justify="between" align="center">
				<div class="stat">
					<span class="stat-label">SATELLITES IN ORBIT</span>
					<span class="stat-value">{operatorCount.toLocaleString()}</span>
				</div>
				<Badge variant="success" glow>STABLE</Badge>
			</Row>
		</div>

		<div class="viz-container">
			{#if visualSize > 100}
				<OrbitalTracker 
					width={visualSize} 
					height={visualSize * 0.85}
				/>
			{/if}
		</div>

		<div class="panel-footer">
			<Row justify="between" align="center">
				<div class="legend">
					<span class="legend-item vault">VAULT</span>
					<span class="legend-item mainframe">MAIN</span>
					<span class="legend-item subnet">SUB</span>
					<span class="legend-item darknet">DARK</span>
					<span class="legend-item blackice">ICE</span>
				</div>
				<span class="footer-text">ORBIT INTEGRITY: 98.2%</span>
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
		font-size: var(--text-xl);
		font-weight: var(--font-thin);
		color: var(--color-text-primary);
		font-variant-numeric: tabular-nums;
	}

	.viz-container {
		display: flex;
		justify-content: center;
		align-items: center;
		min-height: 280px;
	}

	.panel-footer {
		padding-top: var(--space-3);
		border-top: 1px solid var(--color-border-subtle);
		margin-top: var(--space-2);
	}

	.legend {
		display: flex;
		gap: var(--space-2);
	}

	.legend-item {
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wide);
		padding: 0 var(--space-1);
	}

	.legend-item.vault { color: var(--color-level-vault, #00e5cc); }
	.legend-item.mainframe { color: var(--color-level-mainframe, #00e5ff); }
	.legend-item.subnet { color: var(--color-level-subnet, #ffb000); }
	.legend-item.darknet { color: var(--color-level-darknet, #ff6633); }
	.legend-item.blackice { color: var(--color-level-black-ice, #ff3366); }

	.footer-text {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}
</style>
