<script lang="ts">
	import { getMultiplierColor, GROWTH_RATE } from '../store.svelte';

	interface Props {
		/** Current multiplier (animated value from store) */
		multiplier: number;
		/** Whether game has crashed */
		crashed?: boolean;
	}

	let { multiplier, crashed = false }: Props = $props();

	// SVG dimensions
	const width = 400;
	const height = 200;
	const padding = { top: 20, right: 20, bottom: 30, left: 50 };

	// Calculate chart dimensions
	const chartWidth = width - padding.left - padding.right;
	const chartHeight = height - padding.top - padding.bottom;

	// Time scale (show ~30 seconds of history)
	const maxTime = 30;

	// Dynamic Y scale based on current multiplier
	let maxMultiplier = $derived(Math.max(multiplier * 1.2, 2));

	// Calculate elapsed time from multiplier (inverse of e^(rate*t))
	// multiplier = e^(GROWTH_RATE * t) => t = ln(multiplier) / GROWTH_RATE
	let elapsed = $derived(multiplier > 1 ? Math.log(multiplier) / GROWTH_RATE : 0);

	// Generate path points for the exponential curve
	let pathData = $derived.by(() => {
		if (elapsed <= 0) return '';

		const points: string[] = [];
		const numPoints = Math.min(100, Math.ceil(elapsed * 10)); // More points for longer times
		const step = elapsed / Math.max(numPoints, 1);

		for (let i = 0; i <= numPoints; i++) {
			const t = i * step;
			const m = Math.pow(Math.E, GROWTH_RATE * t);
			const x = padding.left + (t / maxTime) * chartWidth;
			const y = padding.top + chartHeight - ((m - 1) / (maxMultiplier - 1)) * chartHeight;

			if (points.length === 0) {
				points.push(`M ${x} ${y}`);
			} else {
				points.push(`L ${x} ${y}`);
			}
		}

		return points.join(' ');
	});

	// Current point position - derived from elapsed time (which comes from multiplier)
	let currentX = $derived(padding.left + (elapsed / maxTime) * chartWidth);
	let currentY = $derived(
		padding.top + chartHeight - ((multiplier - 1) / (maxMultiplier - 1)) * chartHeight
	);

	// Generate Y-axis labels
	let yLabels = $derived.by(() => {
		const labels: { value: number; y: number }[] = [];
		const step = Math.ceil(maxMultiplier / 4);
		for (let i = 1; i <= maxMultiplier; i += step) {
			const y = padding.top + chartHeight - ((i - 1) / (maxMultiplier - 1)) * chartHeight;
			labels.push({ value: i, y });
		}
		return labels;
	});

	// Color based on multiplier
	let colorClass = $derived(crashed ? 'crashed' : getMultiplierColor(multiplier));
</script>

<div class="crash-chart" class:crashed>
	<svg viewBox="0 0 {width} {height}" preserveAspectRatio="xMidYMid meet">
		<!-- Grid lines -->
		<g class="grid">
			{#each yLabels as label}
				<line
					x1={padding.left}
					y1={label.y}
					x2={width - padding.right}
					y2={label.y}
					class="grid-line"
				/>
			{/each}
		</g>

		<!-- Y-axis labels -->
		<g class="y-axis">
			{#each yLabels as label}
				<text x={padding.left - 10} y={label.y + 4} class="axis-label">
					{label.value}x
				</text>
			{/each}
		</g>

		<!-- Base line -->
		<line
			x1={padding.left}
			y1={padding.top + chartHeight}
			x2={width - padding.right}
			y2={padding.top + chartHeight}
			class="baseline"
		/>

		<!-- The curve -->
		{#if pathData}
			<path d={pathData} class="curve {colorClass}" />

			<!-- Glow effect on curve -->
			<path d={pathData} class="curve-glow {colorClass}" />
		{/if}

		<!-- Current point indicator -->
		{#if elapsed > 0 && !crashed}
			<circle cx={currentX} cy={currentY} r="6" class="current-point {colorClass}" />
			<circle cx={currentX} cy={currentY} r="10" class="current-point-pulse {colorClass}" />
		{/if}

		<!-- Crashed indicator -->
		{#if crashed}
			<text x={currentX} y={currentY - 20} class="crash-text">CRASHED!</text>
			<g transform="translate({currentX}, {currentY})">
				<line x1="-10" y1="-10" x2="10" y2="10" class="crash-x" />
				<line x1="-10" y1="10" x2="10" y2="-10" class="crash-x" />
			</g>
		{/if}
	</svg>
</div>

<style>
	.crash-chart {
		width: 100%;
		aspect-ratio: 2 / 1;
		background: var(--color-bg-void);
		border: var(--border-width) solid var(--color-border-subtle);
	}

	svg {
		width: 100%;
		height: 100%;
	}

	/* Grid */
	.grid-line {
		stroke: var(--color-border-subtle);
		stroke-width: 1;
		stroke-dasharray: 2 4;
		opacity: 0.3;
	}

	.baseline {
		stroke: var(--color-border-default);
		stroke-width: 1;
	}

	/* Axis labels */
	.axis-label {
		fill: var(--color-text-tertiary);
		font-family: var(--font-mono);
		font-size: 10px;
		text-anchor: end;
	}

	/* Curve */
	.curve {
		fill: none;
		stroke-width: 3;
		stroke-linecap: round;
		stroke-linejoin: round;
	}

	.curve-glow {
		fill: none;
		stroke-width: 8;
		stroke-linecap: round;
		stroke-linejoin: round;
		opacity: 0.3;
		filter: blur(4px);
	}

	/* Color variants */
	.curve.mult-low,
	.curve-glow.mult-low {
		stroke: var(--color-accent);
	}

	.curve.mult-mid,
	.curve-glow.mult-mid {
		stroke: var(--color-cyan);
	}

	.curve.mult-high,
	.curve-glow.mult-high {
		stroke: var(--color-amber);
	}

	.curve.mult-extreme,
	.curve-glow.mult-extreme {
		stroke: var(--color-amber);
	}

	.curve.crashed,
	.curve-glow.crashed {
		stroke: var(--color-red);
		opacity: 0.5;
	}

	/* Current point */
	.current-point {
		fill: currentColor;
	}

	.current-point.mult-low {
		fill: var(--color-accent);
	}

	.current-point.mult-mid {
		fill: var(--color-cyan);
	}

	.current-point.mult-high {
		fill: var(--color-amber);
	}

	.current-point.mult-extreme {
		fill: var(--color-amber);
	}

	.current-point-pulse {
		fill: none;
		stroke-width: 2;
		animation: pulse-ring 1s ease-out infinite;
	}

	.current-point-pulse.mult-low {
		stroke: var(--color-accent);
	}

	.current-point-pulse.mult-mid {
		stroke: var(--color-cyan);
	}

	.current-point-pulse.mult-high {
		stroke: var(--color-amber);
	}

	.current-point-pulse.mult-extreme {
		stroke: var(--color-amber);
	}

	@keyframes pulse-ring {
		0% {
			r: 6;
			opacity: 1;
		}
		100% {
			r: 20;
			opacity: 0;
		}
	}

	/* Crash indicator */
	.crash-text {
		fill: var(--color-red);
		font-family: var(--font-mono);
		font-size: 14px;
		font-weight: bold;
		text-anchor: middle;
		animation: flash 0.3s ease-in-out 3;
	}

	.crash-x {
		stroke: var(--color-red);
		stroke-width: 3;
		stroke-linecap: round;
	}

	@keyframes flash {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0;
		}
	}

	/* Crashed state */
	.crash-chart.crashed {
		animation: shake 0.3s ease-in-out;
	}

	@keyframes shake {
		0%,
		100% {
			transform: translateX(0);
		}
		25% {
			transform: translateX(-3px);
		}
		75% {
			transform: translateX(3px);
		}
	}
</style>
