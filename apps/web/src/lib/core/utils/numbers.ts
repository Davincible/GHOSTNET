/**
 * Number Formatting Utilities
 * ===========================
 * Single source of truth for all numeric display formatting.
 *
 * Design principles:
 *   - Pure functions, no side effects, no Svelte dependencies
 *   - Handles edge cases: NaN, Infinity, negative zero, very small values
 *   - Consistent locale-aware output (en-US for thousands separators)
 *   - Configurable via options objects, sensible defaults throughout
 *
 * Usage:
 *   import { formatNumber, formatCompact, formatWei, formatPercent, formatMultiplier } from '$lib/core/utils';
 */

// ════════════════════════════════════════════════════════════════
// Types
// ════════════════════════════════════════════════════════════════

export interface FormatNumberOptions {
	/** Maximum decimal places shown (default: 2) */
	decimals?: number;
	/** Minimum decimal places shown (default: 0) */
	minDecimals?: number;
	/** Add thousands separators (default: true) */
	separators?: boolean;
	/** Show '+' prefix for positive values (default: false) */
	showSign?: boolean;
	/** Strip trailing zeros after decimal point (default: false) */
	trimZeros?: boolean;
}

export interface FormatCompactOptions {
	/** Decimal places for the compact value (default: 1) */
	decimals?: number;
	/** Strip trailing zeros (default: true) */
	trimZeros?: boolean;
	/** Show '+' prefix for positive values (default: false) */
	showSign?: boolean;
	/** Lowercase suffixes — 'k' instead of 'K' (default: false) */
	lowercase?: boolean;
}

export interface FormatWeiOptions {
	/** Token decimals — 18 for standard ERC-20 (default: 18) */
	tokenDecimals?: number;
	/** Display decimal places (default: 2) */
	displayDecimals?: number;
	/** Use compact notation for large values (default: false) */
	compact?: boolean;
	/** Add thousands separators (default: true) */
	separators?: boolean;
	/** Show '+' prefix for positive values (default: false) */
	showSign?: boolean;
	/** Strip trailing zeros (default: false) */
	trimZeros?: boolean;
}

export interface FormatPercentOptions {
	/** Decimal places (default: 0) */
	decimals?: number;
	/** Input is already 0-100 scale, not 0-1 (default: false) */
	alreadyScaled?: boolean;
	/** Show '+' prefix for positive values (default: false) */
	showSign?: boolean;
	/** Append '%' symbol (default: true) */
	symbol?: boolean;
}

// ════════════════════════════════════════════════════════════════
// Constants
// ════════════════════════════════════════════════════════════════

const COMPACT_THRESHOLDS = [
	{ value: 1e12, suffix: 'T' },
	{ value: 1e9, suffix: 'B' },
	{ value: 1e6, suffix: 'M' },
	{ value: 1e3, suffix: 'K' },
] as const;

// ════════════════════════════════════════════════════════════════
// Core: formatNumber
// ════════════════════════════════════════════════════════════════

/**
 * Format a number for human display.
 *
 * The workhorse function — handles decimals, thousands separators,
 * trailing zero trimming, sign display, and edge cases.
 *
 * @example formatNumber(1234.5678)              => "1,234.57"
 * @example formatNumber(1234.5678, { decimals: 0 }) => "1,235"
 * @example formatNumber(0.1, { decimals: 4, trimZeros: true }) => "0.1"
 * @example formatNumber(42, { showSign: true })  => "+42"
 * @example formatNumber(NaN)                     => "—"
 */
export function formatNumber(value: number, options: FormatNumberOptions = {}): string {
	const {
		decimals = 2,
		minDecimals = 0,
		separators = true,
		showSign = false,
		trimZeros = false,
	} = options;

	// Edge cases first
	if (!Number.isFinite(value)) return '—';
	if (Object.is(value, -0)) value = 0;

	const absValue = Math.abs(value);

	let formatted: string;

	if (separators) {
		formatted = absValue.toLocaleString('en-US', {
			minimumFractionDigits: trimZeros ? 0 : minDecimals,
			maximumFractionDigits: decimals,
		});
	} else {
		formatted = absValue.toFixed(decimals);
		if (trimZeros && formatted.includes('.')) {
			// Trim trailing zeros, then trailing dot
			formatted = formatted.replace(/0+$/, '').replace(/\.$/, '');
		}
		// Enforce minDecimals when trimming
		if (trimZeros && minDecimals > 0) {
			const dotIndex = formatted.indexOf('.');
			const currentDecimals = dotIndex === -1 ? 0 : formatted.length - dotIndex - 1;
			if (currentDecimals < minDecimals) {
				formatted =
					dotIndex === -1
						? formatted + '.' + '0'.repeat(minDecimals)
						: formatted + '0'.repeat(minDecimals - currentDecimals);
			}
		}
	}

	return applySign(formatted, value, showSign);
}

// ════════════════════════════════════════════════════════════════
// Compact: formatCompact
// ════════════════════════════════════════════════════════════════

/**
 * Format a number with compact suffixes (K, M, B, T).
 *
 * Values below 1,000 are formatted normally. Above that, they're
 * reduced and suffixed. Handles very small positive values gracefully.
 *
 * @example formatCompact(1234)        => "1.2K"
 * @example formatCompact(1_500_000)   => "1.5M"
 * @example formatCompact(42)          => "42"
 * @example formatCompact(0.00042)     => "0.0004"
 * @example formatCompact(-1234)       => "-1.2K"
 */
export function formatCompact(value: number, options: FormatCompactOptions = {}): string {
	const { decimals = 1, trimZeros = true, showSign = false, lowercase = false } = options;

	if (!Number.isFinite(value)) return '—';
	if (Object.is(value, -0)) value = 0;

	const absValue = Math.abs(value);

	// Find the appropriate tier
	for (const tier of COMPACT_THRESHOLDS) {
		if (absValue >= tier.value) {
			const scaled = absValue / tier.value;
			let formatted = scaled.toFixed(decimals);
			if (trimZeros && formatted.includes('.')) {
				formatted = formatted.replace(/0+$/, '').replace(/\.$/, '');
			}
			const suffix = lowercase ? tier.suffix.toLowerCase() : tier.suffix;
			return applySign(formatted + suffix, value, showSign);
		}
	}

	// Below 1,000 — format normally
	if (absValue === 0) {
		return applySign('0', value, showSign);
	}

	// Very small positive numbers: show enough precision to be meaningful
	// Always show at least 2 significant digits regardless of compact decimals setting
	if (absValue > 0 && absValue < 1) {
		const formatted = formatSmallNumber(absValue, Math.max(decimals, 2));
		return applySign(formatted, value, showSign);
	}

	// Normal range (1–999)
	let formatted = absValue.toFixed(decimals);
	if (trimZeros && formatted.includes('.')) {
		formatted = formatted.replace(/0+$/, '').replace(/\.$/, '');
	}
	return applySign(formatted, value, showSign);
}

// ════════════════════════════════════════════════════════════════
// Wei/Token: formatWei
// ════════════════════════════════════════════════════════════════

/**
 * Format a bigint wei value to a human-readable token amount.
 *
 * Converts from raw token units (e.g. 18-decimal wei) to display string.
 * Replaces the three divergent `formatData()` implementations.
 *
 * @example formatWei(1_500_000_000_000_000_000n) => "1.50"
 * @example formatWei(1_500_000_000_000_000_000_000n, { compact: true }) => "1.5K"
 * @example formatWei(0n) => "0"
 */
export function formatWei(amount: bigint, options: FormatWeiOptions = {}): string {
	const {
		tokenDecimals = 18,
		displayDecimals = 2,
		compact = false,
		separators = true,
		showSign = false,
	} = options;

	// trimZeros: explicit false/true from caller wins;
	// otherwise compact mode trims by default, non-compact preserves decimals
	const trimZeros = options.trimZeros ?? (compact ? true : false);

	const numValue = bigintToNumber(amount, tokenDecimals);

	if (compact) {
		return formatCompact(numValue, {
			decimals: displayDecimals,
			showSign,
			trimZeros,
		});
	}

	return formatNumber(numValue, {
		decimals: displayDecimals,
		minDecimals: trimZeros ? 0 : displayDecimals,
		separators,
		showSign,
		trimZeros,
	});
}

// ════════════════════════════════════════════════════════════════
// Percentage: formatPercent (enhanced)
// ════════════════════════════════════════════════════════════════

/**
 * Format a value as a percentage string.
 *
 * By default, expects a ratio (0–1) and scales to 0–100%.
 * Use `alreadyScaled: true` if value is already on the 0–100 scale.
 *
 * @example formatPercent(0.856)                       => "86%"
 * @example formatPercent(0.856, { decimals: 1 })      => "85.6%"
 * @example formatPercent(85.6, { alreadyScaled: true, decimals: 1 }) => "85.6%"
 * @example formatPercent(0.05, { showSign: true })    => "+5%"
 */
export function formatPercentNumber(value: number, options: FormatPercentOptions = {}): string {
	const { decimals = 0, alreadyScaled = false, showSign = false, symbol = true } = options;

	if (!Number.isFinite(value)) return '—';

	const scaled = alreadyScaled ? value : value * 100;
	const absScaled = Math.abs(scaled);
	let formatted = absScaled.toFixed(decimals);

	if (symbol) formatted += '%';

	return applySign(formatted, scaled, showSign);
}

// ════════════════════════════════════════════════════════════════
// Multiplier: formatMultiplier
// ════════════════════════════════════════════════════════════════

/**
 * Format a value as a multiplier (e.g. for crash games).
 *
 * @example formatMultiplier(2.5)   => "2.50x"
 * @example formatMultiplier(100)   => "100.00x"
 * @example formatMultiplier(1.005) => "1.01x"
 */
export function formatMultiplier(value: number, decimals = 2): string {
	if (!Number.isFinite(value)) return '—';
	return value.toFixed(decimals) + 'x';
}

// ════════════════════════════════════════════════════════════════
// Smart: formatSmart
// ════════════════════════════════════════════════════════════════

/**
 * Intelligently format a number based on its magnitude.
 *
 * Picks the most readable representation automatically:
 *   - Very large (≥10K): compact with suffix
 *   - Normal (≥1): fixed decimals with separators
 *   - Small (>0 and <1): enough precision to show meaningful digits
 *   - Zero: "0"
 *
 * Use this when you don't know the value range ahead of time.
 *
 * @example formatSmart(1_234_567)   => "1.2M"
 * @example formatSmart(1234)        => "1,234"
 * @example formatSmart(42.567)      => "42.57"
 * @example formatSmart(0.00042)     => "0.0004"
 * @example formatSmart(0)           => "0"
 */
export function formatSmart(value: number, options: { showSign?: boolean } = {}): string {
	const { showSign = false } = options;

	if (!Number.isFinite(value)) return '—';
	if (Object.is(value, -0)) value = 0;

	const absValue = Math.abs(value);

	// Large numbers: compact
	if (absValue >= 10_000) {
		return formatCompact(value, { decimals: 1, showSign });
	}

	// Normal range: separators + 2 decimals
	if (absValue >= 1) {
		return formatNumber(value, { decimals: 2, trimZeros: true, showSign });
	}

	// Small positive: show meaningful digits
	if (absValue > 0) {
		const formatted = formatSmallNumber(absValue, 2);
		return applySign(formatted, value, showSign);
	}

	return '0';
}

// ════════════════════════════════════════════════════════════════
// Helpers (internal)
// ════════════════════════════════════════════════════════════════

/**
 * Convert a bigint token amount to a JavaScript number.
 * Handles the integer + fractional split to avoid precision loss
 * for values within Number.MAX_SAFE_INTEGER range.
 */
function bigintToNumber(amount: bigint, tokenDecimals: number): number {
	const divisor = 10n ** BigInt(tokenDecimals);
	const isNegative = amount < 0n;
	const abs = isNegative ? -amount : amount;
	const integerPart = abs / divisor;
	const fractionalPart = abs % divisor;
	const result = Number(integerPart) + Number(fractionalPart) / Number(divisor);
	return isNegative ? -result : result;
}

/**
 * Format a small number (0 < value < 1) with enough precision
 * to show at least `significantDigits` meaningful (non-zero) digits.
 *
 * @example formatSmallNumber(0.00042, 2) => "0.00042"
 * @example formatSmallNumber(0.1, 2)     => "0.10"
 */
function formatSmallNumber(value: number, significantDigits: number): string {
	if (value === 0) return '0';

	// How many leading zeros after the decimal point?
	const leadingZeros = Math.max(0, -Math.floor(Math.log10(value)) - 1);
	const precision = leadingZeros + significantDigits;

	// Cap at 8 decimal places to avoid absurd output
	const capped = Math.min(precision, 8);
	let formatted = value.toFixed(capped);

	// Trim trailing zeros but keep at least `significantDigits` meaningful digits
	if (formatted.includes('.')) {
		formatted = formatted.replace(/0+$/, '');
		if (formatted.endsWith('.')) formatted = formatted.slice(0, -1);
	}

	return formatted;
}

/**
 * Prepend sign to a pre-formatted absolute value string.
 */
function applySign(formatted: string, originalValue: number, showPositiveSign: boolean): string {
	if (originalValue < 0) return '-' + formatted;
	if (showPositiveSign && originalValue > 0) return '+' + formatted;
	return formatted;
}
