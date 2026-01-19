<script lang="ts">
	type Format = 'full' | 'compact' | 'precise';

	interface Props {
		/** Amount as bigint (wei-like units) */
		amount: bigint;
		/** Number of decimals in the token (default 18) */
		decimals?: number;
		/** Token symbol to display */
		symbol?: string;
		/** Use Đ symbol for $DATA */
		useDataSymbol?: boolean;
		/** Display format */
		format?: Format;
		/** Show + sign for positive amounts */
		showSign?: boolean;
		/** Color based on positive/negative */
		colorize?: boolean;
		/** Maximum decimal places to show */
		displayDecimals?: number;
	}

	let {
		amount,
		decimals = 18,
		symbol = '',
		useDataSymbol = true,
		format = 'compact',
		showSign = false,
		colorize = false,
		displayDecimals = 2
	}: Props = $props();

	// Convert bigint to number for display
	function formatAmount(amt: bigint): string {
		const divisor = 10n ** BigInt(decimals);
		const integerPart = amt / divisor;
		const fractionalPart = amt % divisor;

		// Convert to number for formatting
		const numValue = Number(integerPart) + Number(fractionalPart) / Number(divisor);
		const absValue = Math.abs(numValue);

		let formatted: string;

		switch (format) {
			case 'compact':
				if (absValue >= 1_000_000) {
					formatted = (absValue / 1_000_000).toFixed(displayDecimals) + 'M';
				} else if (absValue >= 1_000) {
					formatted = (absValue / 1_000).toFixed(displayDecimals) + 'K';
				} else if (absValue >= 1) {
					formatted = absValue.toFixed(displayDecimals);
				} else if (absValue > 0) {
					formatted = absValue.toFixed(Math.min(6, displayDecimals + 4));
				} else {
					formatted = '0';
				}
				break;

			case 'precise':
				formatted = absValue.toFixed(Math.min(8, decimals));
				break;

			case 'full':
			default:
				formatted = absValue.toLocaleString('en-US', {
					minimumFractionDigits: 0,
					maximumFractionDigits: displayDecimals
				});
		}

		// Handle sign
		if (numValue < 0) {
			formatted = '-' + formatted;
		} else if (showSign && numValue > 0) {
			formatted = '+' + formatted;
		}

		return formatted;
	}

	let displayAmount = $derived(formatAmount(amount));
	let displaySymbol = $derived(useDataSymbol && !symbol ? 'Đ' : symbol);
	let isPositive = $derived(amount > 0n);
	let isNegative = $derived(amount < 0n);
</script>

<span
	class="amount"
	class:amount-positive={colorize && isPositive}
	class:amount-negative={colorize && isNegative}
>
	<span class="amount-value">{displayAmount}</span>
	{#if displaySymbol}
		<span class="amount-symbol">{displaySymbol}</span>
	{/if}
</span>

<style>
	.amount {
		display: inline-flex;
		align-items: baseline;
		gap: 0.25ch;
		font-family: var(--font-mono);
		font-variant-numeric: tabular-nums;
		white-space: nowrap;
	}

	.amount-value {
		color: inherit;
	}

	.amount-symbol {
		color: var(--color-green-dim);
		font-size: 0.9em;
	}

	/* Colorized variants */
	.amount-positive {
		color: var(--color-profit);
	}

	.amount-negative {
		color: var(--color-loss);
	}
</style>
