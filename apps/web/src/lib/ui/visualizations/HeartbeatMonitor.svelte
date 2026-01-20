<script lang="ts">
	import { onMount, onDestroy } from 'svelte';

	interface WaveformData {
		id: string;
		label: string;
		color: string;
		values: number[];
		type: 'smooth' | 'step' | 'spike' | 'flow';
		min: number;
		max: number;
		currentValue: number;
		unit?: string;
	}

	interface Props {
		width?: number;
		height?: number;
		waveforms?: WaveformData[];
		updateInterval?: number;
	}

	let {
		width = 500,
		height = 300,
		waveforms: initialWaveforms,
		updateInterval = 100
	}: Props = $props();

	let canvas: HTMLCanvasElement;
	let ctx: CanvasRenderingContext2D;
	let animationId: number;
	let intervalId: ReturnType<typeof setInterval>;

	const COLORS = {
		background: '#030305',
		grid: '#1a1a24',
		gridStrong: '#252532',
		text: '#606070',
		textBright: '#a0a0b0',
		accent: '#00e5cc',
		profit: '#00ff88',
		amber: '#ffb000',
		red: '#ff3366',
		sweep: '#00e5cc33'
	};

	const MAX_POINTS = 100;

	// Default waveform configurations (factory function to get fresh arrays)
	function getDefaultWaveforms(): WaveformData[] {
		return [
			{
				id: 'tvl',
				label: 'TVL',
				color: COLORS.accent,
				values: [],
				type: 'smooth',
				min: 0,
				max: 100,
				currentValue: 75,
				unit: 'M'
			},
			{
				id: 'operators',
				label: 'OPERATORS',
				color: COLORS.profit,
				values: [],
				type: 'step',
				min: 0,
				max: 100,
				currentValue: 60,
				unit: ''
			},
			{
				id: 'trace',
				label: 'TRACE RATE',
				color: COLORS.red,
				values: [],
				type: 'spike',
				min: 0,
				max: 100,
				currentValue: 5,
				unit: '%'
			},
			{
				id: 'yield',
				label: 'YIELD FLOW',
				color: COLORS.amber,
				values: [],
				type: 'flow',
				min: 0,
				max: 100,
				currentValue: 45,
				unit: ''
			}
		];
	}

	// Initialize with defaults, props will be applied in onMount
	let waveforms: WaveformData[] = $state(getDefaultWaveforms());

	let sweepPosition = $state(0);
	let time = 0;

	onMount(() => {
		ctx = canvas.getContext('2d')!;
		setupCanvas();

		// Use provided waveforms if available
		if (initialWaveforms) {
			waveforms = initialWaveforms.map(wf => ({ ...wf, values: [...wf.values] }));
		}

		// Initialize waveform data
		waveforms.forEach((wf) => {
			for (let i = 0; i < MAX_POINTS; i++) {
				wf.values.push(generateValue(wf, i));
			}
		});

		// Start animation
		animate();

		// Start data updates
		intervalId = setInterval(updateData, updateInterval);
	});

	onDestroy(() => {
		if (animationId) cancelAnimationFrame(animationId);
		if (intervalId) clearInterval(intervalId);
	});

	function setupCanvas() {
		const dpr = window.devicePixelRatio || 1;
		canvas.width = width * dpr;
		canvas.height = height * dpr;
		canvas.style.width = `${width}px`;
		canvas.style.height = `${height}px`;
		ctx.scale(dpr, dpr);
	}

	function generateValue(wf: WaveformData, index: number): number {
		const baseValue = wf.currentValue;
		const range = wf.max - wf.min;

		switch (wf.type) {
			case 'smooth':
				return baseValue + Math.sin(index * 0.1) * range * 0.1;
			case 'step':
				return baseValue + (Math.random() > 0.9 ? range * 0.2 : 0);
			case 'spike':
				return Math.random() > 0.95 ? baseValue + range * 0.5 : baseValue * 0.2;
			case 'flow':
				return baseValue + (Math.sin(index * 0.05) + Math.sin(index * 0.13)) * range * 0.1;
			default:
				return baseValue;
		}
	}

	function updateData() {
		time++;

		waveforms.forEach((wf) => {
			// Simulate value changes
			const noise = (Math.random() - 0.5) * 10;
			wf.currentValue = Math.max(wf.min, Math.min(wf.max, wf.currentValue + noise * 0.1));

			// Add new value and remove old
			wf.values.push(generateValue(wf, time));
			if (wf.values.length > MAX_POINTS) {
				wf.values.shift();
			}

			// Random events
			if (wf.type === 'spike' && Math.random() > 0.97) {
				wf.values[wf.values.length - 1] = wf.max * 0.8;
			}
		});

		// Update sweep
		sweepPosition = (sweepPosition + 2) % width;
	}

	function animate() {
		animationId = requestAnimationFrame(animate);
		draw();
	}

	function draw() {
		// Clear
		ctx.fillStyle = COLORS.background;
		ctx.fillRect(0, 0, width, height);

		// Draw grid
		drawGrid();

		// Calculate row height
		const rowHeight = height / waveforms.length;

		// Draw each waveform
		waveforms.forEach((wf, index) => {
			const y = index * rowHeight;
			drawWaveform(wf, y, rowHeight);
		});

		// Draw sweep line
		drawSweepLine();
	}

	function drawGrid() {
		ctx.strokeStyle = COLORS.grid;
		ctx.lineWidth = 1;

		// Vertical lines
		const vSpacing = width / 10;
		for (let x = 0; x <= width; x += vSpacing) {
			ctx.beginPath();
			ctx.moveTo(x, 0);
			ctx.lineTo(x, height);
			ctx.stroke();
		}

		// Horizontal lines per row
		const rowHeight = height / waveforms.length;
		for (let i = 0; i <= waveforms.length; i++) {
			const y = i * rowHeight;
			ctx.strokeStyle = COLORS.gridStrong;
			ctx.beginPath();
			ctx.moveTo(0, y);
			ctx.lineTo(width, y);
			ctx.stroke();

			// Sub-grid lines
			if (i < waveforms.length) {
				ctx.strokeStyle = COLORS.grid;
				ctx.beginPath();
				ctx.moveTo(0, y + rowHeight / 2);
				ctx.lineTo(width, y + rowHeight / 2);
				ctx.stroke();
			}
		}
	}

	function drawWaveform(wf: WaveformData, y: number, rowHeight: number) {
		const padding = 8;
		const chartHeight = rowHeight - padding * 2;
		const chartY = y + padding;

		// Draw label
		ctx.fillStyle = COLORS.text;
		ctx.font = '10px "IBM Plex Mono", monospace';
		ctx.textAlign = 'left';
		ctx.fillText(wf.label, 8, chartY + 12);

		// Draw current value
		ctx.fillStyle = wf.color;
		ctx.textAlign = 'right';
		const valueText = wf.currentValue.toFixed(1) + (wf.unit || '');
		ctx.fillText(valueText, width - 8, chartY + 12);

		// Draw waveform
		ctx.strokeStyle = wf.color;
		ctx.lineWidth = 1.5;
		ctx.beginPath();

		const pointWidth = (width - 80) / MAX_POINTS;
		const startX = 60;

		wf.values.forEach((value, i) => {
			const x = startX + i * pointWidth;
			const normalizedValue = (value - wf.min) / (wf.max - wf.min);
			const pointY = chartY + chartHeight - normalizedValue * chartHeight;

			if (i === 0) {
				ctx.moveTo(x, pointY);
			} else {
				if (wf.type === 'step') {
					// Step function
					const prevY = chartY + chartHeight - ((wf.values[i - 1] - wf.min) / (wf.max - wf.min)) * chartHeight;
					ctx.lineTo(x, prevY);
					ctx.lineTo(x, pointY);
				} else if (wf.type === 'spike') {
					// Sharp spikes
					ctx.lineTo(x, pointY);
				} else {
					// Smooth curves using quadratic bezier
					const prevX = startX + (i - 1) * pointWidth;
					const prevValue = wf.values[i - 1];
					const prevNorm = (prevValue - wf.min) / (wf.max - wf.min);
					const prevY = chartY + chartHeight - prevNorm * chartHeight;
					const cpX = (prevX + x) / 2;
					ctx.quadraticCurveTo(cpX, prevY, x, pointY);
				}
			}
		});

		ctx.stroke();

		// Add glow effect
		ctx.shadowColor = wf.color;
		ctx.shadowBlur = 4;
		ctx.stroke();
		ctx.shadowBlur = 0;

		// Fill under curve (subtle)
		ctx.lineTo(startX + (wf.values.length - 1) * pointWidth, chartY + chartHeight);
		ctx.lineTo(startX, chartY + chartHeight);
		ctx.closePath();
		ctx.fillStyle = wf.color + '10';
		ctx.fill();
	}

	function drawSweepLine() {
		// Vertical sweep line
		const gradient = ctx.createLinearGradient(sweepPosition - 30, 0, sweepPosition, 0);
		gradient.addColorStop(0, 'transparent');
		gradient.addColorStop(1, COLORS.sweep);

		ctx.fillStyle = gradient;
		ctx.fillRect(sweepPosition - 30, 0, 30, height);

		// Bright line at edge
		ctx.strokeStyle = COLORS.accent + '60';
		ctx.lineWidth = 1;
		ctx.beginPath();
		ctx.moveTo(sweepPosition, 0);
		ctx.lineTo(sweepPosition, height);
		ctx.stroke();
	}

	$effect(() => {
		if (ctx) {
			setupCanvas();
		}
	});
</script>

<div class="heartbeat-monitor">
	<canvas 
		bind:this={canvas}
		style:width="{width}px"
		style:height="{height}px"
	></canvas>
</div>

<style>
	.heartbeat-monitor {
		position: relative;
		background: var(--color-bg-void, #030305);
	}

	canvas {
		display: block;
	}
</style>
