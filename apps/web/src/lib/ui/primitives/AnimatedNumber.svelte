<script lang="ts">
	import { tweened } from 'svelte/motion';
	import { cubicOut } from 'svelte/easing';

	type Format = 'number' | 'currency' | 'compact' | 'percent';

	interface Props {
		/** The numeric value to display */
		value: number;
		/** Format type */
		format?: Format;
		/** Number of decimal places */
		decimals?: number;
		/** Animation duration in ms */
		duration?: number;
		/** Prefix string (e.g., "$") */
		prefix?: string;
		/** Suffix string (e.g., "%") */
		suffix?: string;
		/** Show + sign for positive numbers */
		showSign?: boolean;
		/** Color based on value (profit/loss) */
		colorize?: boolean;
	}

	let {
		value,
		format = 'number',
		decimals = 0,
		duration = 300,
		prefix = '',
		suffix = '',
		showSign = false,
		colorize = false,
	}: Props = $props();

	// Tweened store for smooth animation
	// Initialize with 0 to avoid capturing prop value at creation time
	const displayValue = tweened(0, {
		duration: 300,
		easing: cubicOut,
	});

	// Initialize and update when value or duration changes
	$effect(() => {
		displayValue.set(value, { duration });
	});

	// Format the display value
	function formatValue(val: number): string {
		let formatted: string;

		switch (format) {
			case 'currency':
				formatted = val.toLocaleString('en-US', {
					minimumFractionDigits: decimals,
					maximumFractionDigits: decimals,
				});
				break;

			case 'compact':
				if (Math.abs(val) >= 1_000_000) {
					formatted = (val / 1_000_000).toFixed(decimals) + 'M';
				} else if (Math.abs(val) >= 1_000) {
					formatted = (val / 1_000).toFixed(decimals) + 'K';
				} else {
					formatted = val.toFixed(decimals);
				}
				break;

			case 'percent':
				formatted = val.toFixed(decimals);
				break;

			default:
				formatted = val.toLocaleString('en-US', {
					minimumFractionDigits: decimals,
					maximumFractionDigits: decimals,
				});
		}

		// Add sign for positive numbers if requested
		if (showSign && val > 0) {
			formatted = '+' + formatted;
		}

		return prefix + formatted + suffix;
	}

	// Determine color class based on value
	let colorClass = $derived(
		colorize ? (value > 0 ? 'text-profit' : value < 0 ? 'text-loss' : '') : ''
	);
</script>

<span class="animated-number {colorClass}" aria-label={formatValue(value)}>
	{formatValue($displayValue)}
</span>

<style>
	.animated-number {
		font-family: var(--font-mono);
		font-variant-numeric: tabular-nums;
		white-space: nowrap;
	}

	.text-profit {
		color: var(--color-profit);
	}

	.text-loss {
		color: var(--color-loss);
	}
</style>
