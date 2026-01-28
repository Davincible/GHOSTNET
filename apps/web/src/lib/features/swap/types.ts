/** A token available for swapping */
export interface SwapToken {
	/** Token symbol (e.g. "ETH", "USDC") */
	symbol: string;
	/** Display name */
	name: string;
	/** Token decimals */
	decimals: number;
	/** ASCII icon for terminal display */
	icon: string;
	/** Contract address (empty string for native ETH) */
	address: string;
}

/** A price quote for a swap */
export interface SwapQuote {
	/** Input amount (human-readable string) */
	inputAmount: string;
	/** Output amount (human-readable string) */
	outputAmount: string;
	/** Exchange rate: 1 input = N output */
	rate: number;
	/** Price impact as percentage (0-100) */
	priceImpact: number;
	/** Minimum received after slippage */
	minimumReceived: string;
	/** Estimated gas in USD */
	estimatedGasUsd: number;
	/** Route description */
	route: string;
}

/** Current state of the swap interaction */
export type SwapStatus =
	| 'idle'
	| 'quoting'
	| 'ready'
	| 'confirming'
	| 'submitting'
	| 'success'
	| 'error';

/** Validation result for swap inputs */
export interface SwapValidation {
	valid: boolean;
	reason?: string;
}
