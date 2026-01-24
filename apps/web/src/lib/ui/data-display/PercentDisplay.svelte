<script lang="ts">
	type Trend = 'up' | 'down' | 'stable' | 'none';
	type ColorMode = 'default' | 'inverted' | 'none';

	interface Props {
		/** Percentage value (0-100) */
		value: number;
		/** Trend direction */
		trend?: Trend;
		/** How to colorize (default: up=profit, down=loss; inverted: up=loss, down=profit) */
		colorMode?: ColorMode;
		/** Number of decimal places */
		decimals?: number;
		/** Show percent sign */
		showPercent?: boolean;
		/** Animate on urgent values */
		urgentAbove?: number;
		/** Animate on urgent values */
		urgentBelow?: number;
	}

	let {
		value,
		trend = 'none',
		colorMode = 'default',
		decimals = 0,
		showPercent = true,
		urgentAbove,
		urgentBelow,
	}: Props = $props();

	// Format the value
	let displayValue = $derived(value.toFixed(decimals) + (showPercent ? '%' : ''));

	// Determine trend arrow
	let trendArrow = $derived.by(() => {
		switch (trend) {
			case 'up':
				return '▲';
			case 'down':
				return '▼';
			case 'stable':
				return '─';
			default:
				return '';
		}
	});

	// Determine color based on colorMode and trend
	let colorClass = $derived.by(() => {
		if (colorMode === 'none') return '';

		const isInverted = colorMode === 'inverted';

		if (trend === 'up') {
			return isInverted ? 'color-loss' : 'color-profit';
		} else if (trend === 'down') {
			return isInverted ? 'color-profit' : 'color-loss';
		}
		return '';
	});

	// Check if urgent
	let isUrgent = $derived(
		(urgentAbove !== undefined && value >= urgentAbove) ||
			(urgentBelow !== undefined && value <= urgentBelow)
	);
</script>

<span class="percent {colorClass}" class:percent-urgent={isUrgent}>
	<span class="percent-value">{displayValue}</span>
	{#if trendArrow}
		<span class="percent-trend">{trendArrow}</span>
	{/if}
</span>

<style>
	.percent {
		display: inline-flex;
		align-items: center;
		gap: var(--space-1);
		font-family: var(--font-mono);
		font-variant-numeric: tabular-nums;
		white-space: nowrap;
	}

	.percent-value {
		color: inherit;
	}

	.percent-trend {
		font-size: 0.8em;
		color: inherit;
	}

	/* Color variants */
	.color-profit {
		color: var(--color-profit);
	}

	.color-loss {
		color: var(--color-loss);
	}

	/* Urgent animation */
	.percent-urgent {
		animation: urgent-pulse 1s ease-in-out infinite;
	}

	@keyframes urgent-pulse {
		0%,
		100% {
			text-shadow: 0 0 5px currentColor;
		}
		50% {
			text-shadow:
				0 0 15px currentColor,
				0 0 25px currentColor;
		}
	}
</style>
