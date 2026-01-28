<script lang="ts">
	interface Props {
		startPrice: bigint;
		endPrice: bigint;
		totalSupply: bigint;
		totalSold: bigint;
		currentPrice: bigint;
	}

	let { startPrice, endPrice, totalSupply, totalSold, currentPrice }: Props = $props();

	// SVG dimensions
	const W = 300;
	const H = 150;
	const PAD = { top: 16, right: 16, bottom: 28, left: 44 };

	const plotW = W - PAD.left - PAD.right;
	const plotH = H - PAD.top - PAD.bottom;

	function toNum(v: bigint): number {
		return Number(v) / 1e18;
	}

	let empty = $derived(totalSupply === 0n);

	// Normalized positions within the plot area
	let supplyNum = $derived(toNum(totalSupply));
	let soldNum = $derived(toNum(totalSold));
	let startP = $derived(toNum(startPrice));
	let endP = $derived(toNum(endPrice));
	let curP = $derived(toNum(currentPrice));

	let priceMax = $derived(Math.max(endP, startP) * 1.1 || 1);

	// Map data → SVG coords
	function xOf(supply: number): number {
		if (supplyNum === 0) return PAD.left;
		return PAD.left + (supply / supplyNum) * plotW;
	}
	function yOf(price: number): number {
		return PAD.top + plotH - (price / priceMax) * plotH;
	}

	// Curve endpoints
	let x0 = $derived(xOf(0));
	let y0 = $derived(yOf(startP));
	let x1 = $derived(xOf(supplyNum));
	let y1 = $derived(yOf(endP));

	// Current position marker
	let cx = $derived(xOf(soldNum));
	let cy = $derived(yOf(curP));

	// Filled area polygon: bottom-left → curve start → curve at sold → down to baseline
	let soldX = $derived(xOf(soldNum));
	// Y at the sold point on the line (interpolated)
	let soldY = $derived(() => {
		if (supplyNum === 0) return yOf(startP);
		const t = soldNum / supplyNum;
		const priceAtSold = startP + t * (endP - startP);
		return yOf(priceAtSold);
	});

	let fillPath = $derived(
		`M ${x0},${PAD.top + plotH} L ${x0},${y0} L ${soldX},${soldY()} L ${soldX},${PAD.top + plotH} Z`,
	);

	let linePath = $derived(`M ${x0},${y0} L ${x1},${y1}`);
</script>

<div class="bonding-curve">
	{#if empty}
		<div class="placeholder">CURVE NOT CONFIGURED</div>
	{:else}
		<svg viewBox="0 0 {W} {H}" xmlns="http://www.w3.org/2000/svg" class="chart">
			<!-- Filled area (ETH raised) -->
			<path d={fillPath} fill="var(--color-accent)" opacity="0.15" />

			<!-- Curve line -->
			<path d={linePath} stroke="var(--color-accent)" stroke-width="1.5" fill="none" />

			<!-- Current position marker -->
			<line
				x1={cx}
				y1={PAD.top}
				x2={cx}
				y2={PAD.top + plotH}
				stroke="var(--color-accent)"
				stroke-width="0.5"
				stroke-dasharray="2 2"
				opacity="0.5"
			/>
			<circle cx={cx} cy={cy} r="3" fill="var(--color-accent)" />

			<!-- YOU ARE HERE label -->
			<text
				x={cx}
				y={PAD.top - 4}
				text-anchor="middle"
				fill="var(--color-accent)"
				font-family="var(--font-mono)"
				font-size="7"
				letter-spacing="0.5"
			>
				YOU ARE HERE
			</text>

			<!-- X axis line -->
			<line
				x1={PAD.left}
				y1={PAD.top + plotH}
				x2={PAD.left + plotW}
				y2={PAD.top + plotH}
				stroke="var(--color-text-tertiary)"
				stroke-width="0.5"
			/>

			<!-- Y axis line -->
			<line
				x1={PAD.left}
				y1={PAD.top}
				x2={PAD.left}
				y2={PAD.top + plotH}
				stroke="var(--color-text-tertiary)"
				stroke-width="0.5"
			/>

			<!-- Axis labels -->
			<text
				x={PAD.left + plotW / 2}
				y={H - 4}
				text-anchor="middle"
				fill="var(--color-text-tertiary)"
				font-family="var(--font-mono)"
				font-size="7"
				letter-spacing="0.5"
			>
				$DATA SOLD
			</text>

			<text
				x={8}
				y={PAD.top + plotH / 2}
				text-anchor="middle"
				fill="var(--color-text-tertiary)"
				font-family="var(--font-mono)"
				font-size="7"
				letter-spacing="0.5"
				transform="rotate(-90 8 {PAD.top + plotH / 2})"
			>
				PRICE
			</text>

			<!-- Price labels on Y axis -->
			<text
				x={PAD.left - 4}
				y={y0 + 3}
				text-anchor="end"
				fill="var(--color-text-tertiary)"
				font-family="var(--font-mono)"
				font-size="6"
			>
				{startP.toFixed(4)}
			</text>
			<text
				x={PAD.left - 4}
				y={y1 + 3}
				text-anchor="end"
				fill="var(--color-text-tertiary)"
				font-family="var(--font-mono)"
				font-size="6"
			>
				{endP.toFixed(4)}
			</text>
		</svg>
	{/if}
</div>

<style>
	.bonding-curve {
		width: 100%;
	}

	.chart {
		width: 100%;
		height: auto;
		display: block;
	}

	.placeholder {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
		text-align: center;
		padding: var(--space-6) 0;
		letter-spacing: var(--tracking-wider);
	}
</style>
