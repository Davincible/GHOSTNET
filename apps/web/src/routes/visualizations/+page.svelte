<script lang="ts">
	import { Header } from '$lib/features/header';
	import { NavigationBar } from '$lib/features/nav';
	import {
		NetworkVisualizationPanel,
		OrbitalTrackerPanel,
		RadarSweepPanel,
		HeartbeatPanel,
	} from '$lib/ui/visualizations';
</script>

<svelte:head>
	<title>GHOSTNET - Visualization Showcase</title>
	<meta name="description" content="GHOSTNET command center visualizations" />
</svelte:head>

<div class="showcase">
	<Header />

	<main class="main-content">
		<div class="page-header">
			<h1 class="page-title">VISUALIZATION SYSTEMS</h1>
			<p class="page-subtitle">Real-time network telemetry and monitoring displays</p>
		</div>

		<div class="viz-grid">
			<!-- Network Globe -->
			<div class="viz-card">
				<NetworkVisualizationPanel operatorCount={1247} />
			</div>

			<!-- Orbital Tracker -->
			<div class="viz-card">
				<OrbitalTrackerPanel operatorCount={1247} />
			</div>

			<!-- Radar Sweep -->
			<div class="viz-card">
				<RadarSweepPanel
					nextScanTime={Date.now() + 45000}
					operatorCount={1247}
					survivalRate={87.3}
				/>
			</div>

			<!-- Heartbeat Monitor -->
			<div class="viz-card full-width">
				<HeartbeatPanel status="healthy" />
			</div>
		</div>
	</main>

	<NavigationBar active="network" />
</div>

<style>
	.showcase {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
	}

	.main-content {
		flex: 1;
		padding: var(--space-4);
		max-width: var(--container-2xl);
		margin: 0 auto;
		width: 100%;
	}

	.page-header {
		margin-bottom: var(--space-6);
		text-align: center;
	}

	.page-title {
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-widest);
		color: var(--color-text-primary);
		margin: 0 0 var(--space-2) 0;
	}

	.page-subtitle {
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wide);
		margin: 0;
	}

	.viz-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: var(--space-4);
	}

	.viz-card {
		min-height: 400px;
	}

	.viz-card.full-width {
		grid-column: 1 / -1;
		min-height: 350px;
	}

	/* Responsive */
	@media (max-width: 1024px) {
		.viz-grid {
			grid-template-columns: 1fr;
		}

		.viz-card.full-width {
			grid-column: auto;
		}
	}

	@media (max-width: 640px) {
		.main-content {
			padding: var(--space-2);
		}

		.viz-grid {
			gap: var(--space-2);
		}

		.viz-card {
			min-height: 350px;
		}
	}
</style>
