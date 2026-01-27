<script lang="ts">
	import { formatWei, formatNumber } from '$lib/core/utils';

	type Format = 'full' | 'compact' | 'precise';

	interface Props {
		/** Amount as bigint (wei-like units) */
		amount: bigint;
		/**
		 * Number of decimals in the token (default 18).
		 *
		 * @deprecated Use `tokenDecimals` instead — this name was ambiguous
		 * and frequently confused with display precision.
		 */
		decimals?: number;
		/** Number of decimals in the token (default 18) */
		tokenDecimals?: number;
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
		/** Maximum decimal places to show in formatted output */
		displayDecimals?: number;
	}

	let {
		amount,
		decimals = 18,
		tokenDecimals,
		symbol = '',
		useDataSymbol = true,
		format = 'compact',
		showSign = false,
		colorize = false,
		displayDecimals = 2,
	}: Props = $props();

	// tokenDecimals takes priority over deprecated decimals prop
	const resolvedTokenDecimals = $derived(tokenDecimals ?? decimals);

	function formatAmount(amt: bigint): string {
		switch (format) {
			case 'compact':
				return formatWei(amt, {
					tokenDecimals: resolvedTokenDecimals,
					displayDecimals,
					compact: true,
					showSign,
				});

			case 'precise':
				return formatWei(amt, {
					tokenDecimals: resolvedTokenDecimals,
					displayDecimals: 8,
					showSign,
				});

			case 'full':
			default:
				return formatWei(amt, {
					tokenDecimals: resolvedTokenDecimals,
					displayDecimals,
					separators: true,
					showSign,
					trimZeros: true,
				});
		}
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
		color: var(--color-text-tertiary);
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
