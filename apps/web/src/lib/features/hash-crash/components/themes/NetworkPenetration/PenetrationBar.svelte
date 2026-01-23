<script lang="ts">
	/**
	 * Penetration Bar - Horizontal firewall breach visualization
	 * ==========================================================
	 * Shows current penetration depth as horizontal progress through
	 * network security layers. Markers show current position and exit point.
	 */

	interface Props {
		/** Current penetration depth (multiplier) */
		depth: number;
		/** Player's exit point (target multiplier) */
		exitPoint?: number | null;
		/** Maximum depth to show on scale */
		maxDepth?: number;
		/** Whether the game is active/animating */
		active?: boolean;
		/** Whether traced (crashed) */
		traced?: boolean;
	}

	let { depth, exitPoint = null, maxDepth = 10, active = false, traced = false }: Props = $props();

	// Calculate percentages for positioning
	let depthPercent = $derived(Math.min((depth / maxDepth) * 100, 100));
	let exitPercent = $derived(exitPoint ? Math.min((exitPoint / maxDepth) * 100, 100) : null);

	// Determine if past exit point
	let isPastExit = $derived(exitPoint ? depth >= exitPoint : false);

	// Color based on depth zone
	let zoneClass = $derived.by(() => {
		if (traced) return 'zone-traced';
		if (isPastExit) return 'zone-safe';
		const ratio = depth / maxDepth;
		if (ratio < 0.2) return 'zone-entry';
		if (ratio < 0.5) return 'zone-active';
		if (ratio < 0.8) return 'zone-danger';
		return 'zone-critical';
	});

	// Generate tick marks for the scale
	const ticks = [1, 2, 3, 5, 10];
	let visibleTicks = $derived(ticks.filter((t) => t <= maxDepth));
</script>

<div class="penetration-bar" class:active class:traced>
	<!-- Header labels -->
	<div class="bar-header">
		<span class="label-start">FIREWALL</span>
		<span class="label-end">ICE</span>
	</div>

	<!-- Main bar container -->
	<div class="bar-container">
		<!-- Background zones -->
		<div class="zone zone-1"></div>
		<div class="zone zone-2"></div>
		<div class="zone zone-3"></div>
		<div class="zone zone-4"></div>

		<!-- Progress fill -->
		<div class="bar-fill {zoneClass}" style:width="{depthPercent}%">
			<div class="fill-glow"></div>
		</div>

		<!-- Exit point marker -->
		{#if exitPercent !== null}
			<div
				class="exit-marker"
				class:reached={isPastExit}
				style:left="{exitPercent}%"
				title="Your exit point: {exitPoint?.toFixed(2)}x"
			>
				<div class="exit-line"></div>
				<div class="exit-label">EXIT</div>
			</div>
		{/if}

		<!-- Current position indicator -->
		<div class="position-marker {zoneClass}" style:left="{depthPercent}%">
			<div class="marker-dot"></div>
			{#if active && !traced}
				<div class="marker-pulse"></div>
			{/if}
		</div>

		<!-- Tick marks -->
		<div class="bar-ticks">
			{#each visibleTicks as tick (tick)}
				{@const tickPercent = (tick / maxDepth) * 100}
				<div class="tick" style:left="{tickPercent}%">
					<div class="tick-line"></div>
					<span class="tick-label">{tick}x</span>
				</div>
			{/each}
		</div>
	</div>

	<!-- Current depth display -->
	<div class="depth-readout {zoneClass}">
		<span class="readout-label">DEPTH:</span>
		<span class="readout-value">{depth.toFixed(2)}x</span>
	</div>
</div>

<style>
	.penetration-bar {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		font-family: var(--font-mono);
	}

	/* Header labels */
	.bar-header {
		display: flex;
		justify-content: space-between;
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	/* Main bar */
	.bar-container {
		position: relative;
		height: 24px;
		background: var(--color-bg-void);
		border: var(--border-width) solid var(--color-border-default);
	}

	/* Background zone colors */
	.zone {
		position: absolute;
		top: 0;
		bottom: 0;
		opacity: 0.1;
	}

	.zone-1 {
		left: 0;
		width: 20%;
		background: var(--color-accent);
	}

	.zone-2 {
		left: 20%;
		width: 30%;
		background: var(--color-cyan);
	}

	.zone-3 {
		left: 50%;
		width: 30%;
		background: var(--color-amber);
	}

	.zone-4 {
		left: 80%;
		width: 20%;
		background: var(--color-red);
	}

	/* Progress fill */
	.bar-fill {
		position: absolute;
		top: 0;
		left: 0;
		bottom: 0;
		transition: width 0.1s ease-out;
		overflow: hidden;
	}

	.bar-fill.zone-entry {
		background: linear-gradient(90deg, var(--color-accent), var(--color-accent));
	}

	.bar-fill.zone-active {
		background: linear-gradient(90deg, var(--color-accent), var(--color-cyan));
	}

	.bar-fill.zone-danger {
		background: linear-gradient(90deg, var(--color-accent), var(--color-cyan), var(--color-amber));
	}

	.bar-fill.zone-critical {
		background: linear-gradient(
			90deg,
			var(--color-accent),
			var(--color-cyan),
			var(--color-amber),
			var(--color-red)
		);
	}

	.bar-fill.zone-safe {
		background: linear-gradient(90deg, var(--color-accent), var(--color-accent));
		box-shadow: 0 0 15px var(--color-accent-glow);
	}

	.bar-fill.zone-traced {
		background: var(--color-red);
		opacity: 0.6;
	}

	.fill-glow {
		position: absolute;
		right: 0;
		top: 0;
		bottom: 0;
		width: 30px;
		background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2));
	}

	/* Exit marker */
	.exit-marker {
		position: absolute;
		top: -8px;
		bottom: -8px;
		transform: translateX(-50%);
		z-index: 10;
	}

	.exit-line {
		position: absolute;
		top: 8px;
		bottom: 8px;
		left: 50%;
		width: 2px;
		background: var(--color-cyan);
		transform: translateX(-50%);
		opacity: 0.8;
	}

	.exit-marker.reached .exit-line {
		background: var(--color-accent);
		box-shadow: 0 0 8px var(--color-accent);
	}

	.exit-label {
		position: absolute;
		bottom: -4px;
		left: 50%;
		transform: translateX(-50%);
		font-size: 9px;
		color: var(--color-cyan);
		letter-spacing: var(--tracking-wider);
		white-space: nowrap;
	}

	.exit-marker.reached .exit-label {
		color: var(--color-accent);
	}

	/* Position marker */
	.position-marker {
		position: absolute;
		top: 50%;
		transform: translate(-50%, -50%);
		z-index: 20;
	}

	.marker-dot {
		width: 12px;
		height: 12px;
		border-radius: 50%;
		border: 2px solid var(--color-bg-primary);
	}

	.zone-entry .marker-dot {
		background: var(--color-accent);
		box-shadow: 0 0 8px var(--color-accent);
	}

	.zone-active .marker-dot {
		background: var(--color-cyan);
		box-shadow: 0 0 8px var(--color-cyan);
	}

	.zone-danger .marker-dot {
		background: var(--color-amber);
		box-shadow: 0 0 10px var(--color-amber);
	}

	.zone-critical .marker-dot {
		background: var(--color-red);
		box-shadow: 0 0 12px var(--color-red);
		animation: pulse-critical 0.4s ease-in-out infinite;
	}

	.zone-safe .marker-dot {
		background: var(--color-accent);
		box-shadow: 0 0 15px var(--color-accent);
	}

	.zone-traced .marker-dot {
		background: var(--color-red);
		box-shadow: 0 0 20px var(--color-red);
	}

	.marker-pulse {
		position: absolute;
		top: 50%;
		left: 50%;
		width: 12px;
		height: 12px;
		border-radius: 50%;
		border: 2px solid currentColor;
		transform: translate(-50%, -50%);
		animation: pulse-ring 1s ease-out infinite;
		pointer-events: none;
	}

	.zone-entry .marker-pulse {
		border-color: var(--color-accent);
	}
	.zone-active .marker-pulse {
		border-color: var(--color-cyan);
	}
	.zone-danger .marker-pulse {
		border-color: var(--color-amber);
	}
	.zone-critical .marker-pulse {
		border-color: var(--color-red);
	}
	.zone-safe .marker-pulse {
		border-color: var(--color-accent);
	}

	/* Tick marks */
	.bar-ticks {
		position: absolute;
		inset: 0;
		pointer-events: none;
	}

	.tick {
		position: absolute;
		top: 100%;
		transform: translateX(-50%);
	}

	.tick-line {
		width: 1px;
		height: 4px;
		background: var(--color-border-default);
	}

	.tick-label {
		display: block;
		margin-top: 2px;
		font-size: 9px;
		color: var(--color-text-tertiary);
	}

	/* Depth readout */
	.depth-readout {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: var(--space-1) var(--space-2);
		background: var(--color-bg-tertiary);
		border: var(--border-width) solid var(--color-border-subtle);
	}

	.readout-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.readout-value {
		font-size: var(--text-base);
		font-weight: var(--font-bold);
	}

	.zone-entry .readout-value {
		color: var(--color-accent);
	}
	.zone-active .readout-value {
		color: var(--color-cyan);
	}
	.zone-danger .readout-value {
		color: var(--color-amber);
	}
	.zone-critical .readout-value {
		color: var(--color-red);
	}
	.zone-safe .readout-value {
		color: var(--color-accent);
	}
	.zone-traced .readout-value {
		color: var(--color-red);
	}

	/* Animations */
	@keyframes pulse-ring {
		0% {
			transform: translate(-50%, -50%) scale(1);
			opacity: 1;
		}
		100% {
			transform: translate(-50%, -50%) scale(2.5);
			opacity: 0;
		}
	}

	@keyframes pulse-critical {
		0%,
		100% {
			transform: scale(1);
		}
		50% {
			transform: scale(1.2);
		}
	}

	/* Traced state */
	.penetration-bar.traced .bar-container {
		animation: shake 0.5s ease-in-out;
	}

	@keyframes shake {
		0%,
		100% {
			transform: translateX(0);
		}
		20%,
		60% {
			transform: translateX(-3px);
		}
		40%,
		80% {
			transform: translateX(3px);
		}
	}
</style>
