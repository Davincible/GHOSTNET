import type { SwapToken } from './types';

/** $DATA — the output token (fixed) */
export const DATA_TOKEN: SwapToken = {
	symbol: '$DATA',
	name: 'Data Token',
	decimals: 18,
	icon: 'D',
	address: '0x0000000000000000000000000000000000000000', // placeholder
};

/** Tokens available as swap input */
export const INPUT_TOKENS: SwapToken[] = [
	{
		symbol: 'ETH',
		name: 'Ether',
		decimals: 18,
		icon: 'E',
		address: '',
	},
	{
		symbol: 'USDC',
		name: 'USD Coin',
		decimals: 6,
		icon: '$',
		address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // placeholder
	},
	{
		symbol: 'USDT',
		name: 'Tether',
		decimals: 6,
		icon: '$',
		address: '0xdAC17F958D2ee523a2206206994597C13D831ec7', // placeholder
	},
];

/** Default slippage tolerance (percent) */
export const DEFAULT_SLIPPAGE = 0.5;

/** Slippage presets */
export const SLIPPAGE_PRESETS = [0.1, 0.5, 1.0] as const;

/** Mock exchange rates: 1 token = N $DATA */
export const MOCK_RATES: Record<string, number> = {
	ETH: 42_000,
	USDC: 12.5,
	USDT: 12.5,
};

/** Mock balances for demo */
export const MOCK_BALANCES: Record<string, number> = {
	ETH: 1.2847,
	USDC: 5_420.0,
	USDT: 2_100.0,
	$DATA: 18_750.0,
};
