<script lang="ts">
	import { onMount } from 'svelte';
	import { Box } from '$lib/ui/terminal';
	import { Row } from '$lib/ui/layout';
	import { Badge } from '$lib/ui/primitives';
	import NetworkGlobe from './NetworkGlobe.svelte';

	interface Props {
		/** Number of active operators to display */
		operatorCount?: number;
		/** Show the header info */
		showStats?: boolean;
	}

	let {
		operatorCount = 1247,
		showStats = true
	}: Props = $props();

	let containerWidth = $state(0);
	let containerEl: HTMLDivElement;

	// Responsive size calculation
	let globeSize = $derived(Math.min(containerWidth - 24, 380));

	onMount(() => {
		// Get initial width
		if (containerEl) {
			containerWidth = containerEl.clientWidth;
		}

		// Watch for resize
		const observer = new ResizeObserver((entries) => {
			for (const entry of entries) {
				containerWidth = entry.contentRect.width;
			}
		});

		if (containerEl) {
			observer.observe(containerEl);
		}

		return () => observer.disconnect();
	});
</script>

<div class="viz-panel" bind:this={containerEl}>
	<Box title="NETWORK TOPOLOGY" borderColor="bright">
		{#if showStats}
			<div class="viz-header">
				<Row justify="between" align="center">
					<div class="stat">
						<span class="stat-label">ACTIVE NODES</span>
						<span class="stat-value">{operatorCount.toLocaleString()}</span>
					</div>
					<Badge variant="success" glow>SYNCHRONIZED</Badge>
				</Row>
			</div>
		{/if}

		<div class="viz-container">
			{#if globeSize > 100}
				<NetworkGlobe 
					width={globeSize} 
					height={globeSize * 0.85}
					particleCount={100}
					rotationSpeed={0.0008}
				/>
			{/if}
			
			<!-- Overlay data -->
			<div class="viz-overlay">
				<div class="overlay-corner overlay-tl">
					<span class="overlay-text">LAT: 47.6062</span>
					<span class="overlay-text">LNG: -122.3321</span>
				</div>
				<div class="overlay-corner overlay-tr">
					<span class="overlay-text">FREQ: 2.4GHz</span>
					<span class="overlay-text">PWR: 847mW</span>
				</div>
				<div class="overlay-corner overlay-bl">
					<span class="overlay-text">UPLINK: ACTIVE</span>
				</div>
				<div class="overlay-corner overlay-br">
					<span class="overlay-text">PING: 12ms</span>
				</div>
			</div>
		</div>

		<div class="viz-footer">
			<Row justify="between" align="center">
				<span class="footer-text">MESH INTEGRITY: 99.7%</span>
				<div class="signal-bars">
					<span class="bar bar-active"></span>
					<span class="bar bar-active"></span>
					<span class="bar bar-active"></span>
					<span class="bar bar-active"></span>
					<span class="bar"></span>
				</div>
			</Row>
		</div>
	</Box>
</div>

<style>
	.viz-panel {
		width: 100%;
	}

	.viz-header {
		padding-bottom: var(--space-3);
		border-bottom: 1px solid var(--color-border-subtle);
		margin-bottom: var(--space-3);
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
		text-transform: uppercase;
	}

	.stat-value {
		font-size: var(--text-xl);
		font-weight: var(--font-thin);
		color: var(--color-text-primary);
		font-variant-numeric: tabular-nums;
	}

	.viz-container {
		position: relative;
		display: flex;
		justify-content: center;
		align-items: center;
		min-height: 280px;
	}

	.viz-overlay {
		position: absolute;
		inset: 0;
		pointer-events: none;
		padding: var(--space-2);
	}

	.overlay-corner {
		position: absolute;
		display: flex;
		flex-direction: column;
		gap: var(--space-0-5);
	}

	.overlay-tl {
		top: var(--space-2);
		left: var(--space-2);
	}

	.overlay-tr {
		top: var(--space-2);
		right: var(--space-2);
		text-align: right;
	}

	.overlay-bl {
		bottom: var(--space-2);
		left: var(--space-2);
	}

	.overlay-br {
		bottom: var(--space-2);
		right: var(--space-2);
		text-align: right;
	}

	.overlay-text {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wide);
		font-variant-numeric: tabular-nums;
	}

	.viz-footer {
		padding-top: var(--space-3);
		border-top: 1px solid var(--color-border-subtle);
		margin-top: var(--space-3);
	}

	.footer-text {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.signal-bars {
		display: flex;
		align-items: flex-end;
		gap: 2px;
		height: 12px;
	}

	.bar {
		width: 3px;
		background: var(--color-border-strong);
		transition: background var(--duration-fast);
	}

	.bar:nth-child(1) { height: 4px; }
	.bar:nth-child(2) { height: 6px; }
	.bar:nth-child(3) { height: 8px; }
	.bar:nth-child(4) { height: 10px; }
	.bar:nth-child(5) { height: 12px; }

	.bar-active {
		background: var(--color-accent);
		box-shadow: 0 0 4px var(--color-accent-glow);
	}
</style>
