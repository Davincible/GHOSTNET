import type { SwapToken, SwapQuote, SwapStatus, SwapValidation } from './types';
import {
	DATA_TOKEN,
	INPUT_TOKENS,
	DEFAULT_SLIPPAGE,
	MOCK_RATES,
	MOCK_BALANCES,
} from './constants';

/**
 * Creates a reactive swap store managing input/output state,
 * mock quote generation, and validation.
 */
export function createSwapStore() {
	// ── Core state ──────────────────────────────────────────────
	let inputToken = $state<SwapToken>(INPUT_TOKENS[0]);
	let outputToken = $state<SwapToken>(DATA_TOKEN);
	let inputAmount = $state('');
	let slippage = $state(DEFAULT_SLIPPAGE);
	let status = $state<SwapStatus>('idle');
	let errorMessage = $state('');

	// ── Derived ─────────────────────────────────────────────────

	/** Parsed numeric input (0 if empty/invalid) */
	let inputNumber = $derived.by(() => {
		const n = parseFloat(inputAmount);
		return Number.isFinite(n) && n >= 0 ? n : 0;
	});

	/** Mock balance for the selected input token */
	let inputBalance = $derived(MOCK_BALANCES[inputToken.symbol] ?? 0);

	/** Mock balance for $DATA */
	let outputBalance = $derived(MOCK_BALANCES[DATA_TOKEN.symbol] ?? 0);

	/** Exchange rate for the current input token */
	let rate = $derived(MOCK_RATES[inputToken.symbol] ?? 0);

	/** Computed output amount */
	let outputNumber = $derived(inputNumber * rate);

	/** Formatted output string */
	let outputDisplay = $derived.by(() => {
		if (inputNumber === 0) return '';
		if (outputNumber >= 1_000_000) return `${(outputNumber / 1_000_000).toFixed(2)}M`;
		if (outputNumber >= 1_000) return outputNumber.toLocaleString('en-US', { maximumFractionDigits: 2 });
		return outputNumber.toFixed(2);
	});

	/** Price impact (mock: scales with size relative to a fake pool) */
	let priceImpact = $derived.by(() => {
		const MOCK_POOL_SIZE = 1_000_000; // $1M fake liquidity
		const usdValue = inputToken.symbol === 'ETH' ? inputNumber * 3_400 : inputNumber;
		return Math.min((usdValue / MOCK_POOL_SIZE) * 100, 99);
	});

	/** Minimum received after slippage */
	let minimumReceived = $derived.by(() => {
		const min = outputNumber * (1 - slippage / 100);
		if (min === 0) return '';
		if (min >= 1_000) return min.toLocaleString('en-US', { maximumFractionDigits: 2 });
		return min.toFixed(2);
	});

	/** Full quote object */
	let quote = $derived.by((): SwapQuote | null => {
		if (inputNumber === 0) return null;
		return {
			inputAmount: inputAmount,
			outputAmount: outputDisplay,
			rate,
			priceImpact,
			minimumReceived,
			estimatedGasUsd: 0.42,
			route: `${inputToken.symbol} -> ${outputToken.symbol}`,
		};
	});

	/** Validation state */
	let validation = $derived.by((): SwapValidation => {
		if (inputAmount === '' || inputNumber === 0) {
			return { valid: false, reason: 'ENTER AMOUNT' };
		}
		if (inputNumber > inputBalance) {
			return { valid: false, reason: `INSUFFICIENT ${inputToken.symbol}` };
		}
		if (priceImpact > 15) {
			return { valid: false, reason: 'PRICE IMPACT TOO HIGH' };
		}
		return { valid: true };
	});

	/** Whether the swap button should be enabled */
	let canSwap = $derived(validation.valid && status !== 'submitting' && status !== 'quoting');

	/** Button label based on current state */
	let buttonLabel = $derived.by(() => {
		if (status === 'submitting') return 'EXECUTING...';
		if (status === 'success') return 'SWAP COMPLETE';
		if (!validation.valid) return validation.reason ?? 'ENTER AMOUNT';
		return 'EXECUTE SWAP';
	});

	// ── Actions ─────────────────────────────────────────────────

	function setInputToken(token: SwapToken) {
		inputToken = token;
		// Reset status when token changes
		if (status === 'error' || status === 'success') {
			status = 'idle';
			errorMessage = '';
		}
	}

	function setInputAmount(value: string) {
		// Allow empty string, digits, single decimal point
		if (value === '' || /^\d*\.?\d*$/.test(value)) {
			inputAmount = value;
			if (status === 'error' || status === 'success') {
				status = 'idle';
				errorMessage = '';
			}
		}
	}

	function setMaxInput() {
		inputAmount = inputBalance.toString();
	}

	function setSlippage(value: number) {
		slippage = value;
	}

	/** Simulate a swap execution */
	async function executeSwap() {
		if (!canSwap) return;

		status = 'submitting';
		errorMessage = '';

		// Simulate network delay
		await new Promise((r) => setTimeout(r, 1_800));

		// Mock: 90% success rate
		if (Math.random() > 0.1) {
			status = 'success';
			// Reset after showing success briefly
			setTimeout(() => {
				inputAmount = '';
				status = 'idle';
			}, 2_000);
		} else {
			status = 'error';
			errorMessage = 'TRANSACTION REVERTED — TRY AGAIN';
		}
	}

	function reset() {
		inputAmount = '';
		inputToken = INPUT_TOKENS[0];
		slippage = DEFAULT_SLIPPAGE;
		status = 'idle';
		errorMessage = '';
	}

	return {
		// State (read-only via getters)
		get inputToken() { return inputToken; },
		get outputToken() { return outputToken; },
		get inputAmount() { return inputAmount; },
		get inputNumber() { return inputNumber; },
		get inputBalance() { return inputBalance; },
		get outputBalance() { return outputBalance; },
		get outputDisplay() { return outputDisplay; },
		get rate() { return rate; },
		get priceImpact() { return priceImpact; },
		get minimumReceived() { return minimumReceived; },
		get slippage() { return slippage; },
		get quote() { return quote; },
		get validation() { return validation; },
		get canSwap() { return canSwap; },
		get buttonLabel() { return buttonLabel; },
		get status() { return status; },
		get errorMessage() { return errorMessage; },
		get availableTokens() { return INPUT_TOKENS; },

		// Actions
		setInputToken,
		setInputAmount,
		setMaxInput,
		setSlippage,
		executeSwap,
		reset,
	};
}

export type SwapStore = ReturnType<typeof createSwapStore>;
