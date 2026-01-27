import { describe, it, expect } from 'vitest';
import {
	formatNumber,
	formatCompact,
	formatWei,
	formatPercentNumber,
	formatMultiplier,
	formatSmart,
} from './numbers';

// ════════════════════════════════════════════════════════════════
// formatNumber
// ════════════════════════════════════════════════════════════════

describe('formatNumber', () => {
	it('formats with default options (2 decimals, separators)', () => {
		expect(formatNumber(1234.5678)).toBe('1,234.57');
	});

	it('formats zero', () => {
		expect(formatNumber(0)).toBe('0');
	});

	it('formats negative zero as zero', () => {
		expect(formatNumber(-0)).toBe('0');
	});

	it('formats negative numbers', () => {
		expect(formatNumber(-1234.56)).toBe('-1,234.56');
	});

	it('returns dash for NaN', () => {
		expect(formatNumber(NaN)).toBe('—');
	});

	it('returns dash for Infinity', () => {
		expect(formatNumber(Infinity)).toBe('—');
		expect(formatNumber(-Infinity)).toBe('—');
	});

	it('respects custom decimals', () => {
		expect(formatNumber(3.14159, { decimals: 4 })).toBe('3.1416');
		expect(formatNumber(3.14159, { decimals: 0 })).toBe('3');
	});

	it('can disable separators', () => {
		expect(formatNumber(1234567.89, { separators: false })).toBe('1234567.89');
	});

	it('shows positive sign when requested', () => {
		expect(formatNumber(42, { showSign: true })).toBe('+42');
		expect(formatNumber(-42, { showSign: true })).toBe('-42');
		expect(formatNumber(0, { showSign: true })).toBe('0');
	});

	it('trims trailing zeros', () => {
		expect(formatNumber(1.5, { decimals: 4, trimZeros: true, separators: false })).toBe('1.5');
		expect(formatNumber(1.0, { decimals: 4, trimZeros: true, separators: false })).toBe('1');
	});

	it('respects minDecimals with separators', () => {
		expect(formatNumber(1.5, { decimals: 4, minDecimals: 2 })).toBe('1.50');
	});

	it('respects minDecimals with trimZeros and no separators', () => {
		expect(formatNumber(1.0, { decimals: 4, minDecimals: 2, trimZeros: true, separators: false })).toBe('1.00');
	});

	it('formats large numbers', () => {
		expect(formatNumber(1_000_000_000)).toBe('1,000,000,000');
	});

	it('formats small decimals', () => {
		expect(formatNumber(0.005, { decimals: 2 })).toBe('0.01');
		expect(formatNumber(0.004, { decimals: 2 })).toBe('0');
	});
});

// ════════════════════════════════════════════════════════════════
// formatCompact
// ════════════════════════════════════════════════════════════════

describe('formatCompact', () => {
	it('formats thousands', () => {
		expect(formatCompact(1500)).toBe('1.5K');
	});

	it('formats millions', () => {
		expect(formatCompact(2_500_000)).toBe('2.5M');
	});

	it('formats billions', () => {
		expect(formatCompact(1_200_000_000)).toBe('1.2B');
	});

	it('formats trillions', () => {
		expect(formatCompact(3_500_000_000_000)).toBe('3.5T');
	});

	it('passes through numbers below 1000', () => {
		expect(formatCompact(42)).toBe('42');
		expect(formatCompact(999)).toBe('999');
	});

	it('formats zero', () => {
		expect(formatCompact(0)).toBe('0');
	});

	it('formats negative numbers', () => {
		expect(formatCompact(-1500)).toBe('-1.5K');
	});

	it('trims trailing zeros by default', () => {
		expect(formatCompact(1000)).toBe('1K');
		expect(formatCompact(2_000_000)).toBe('2M');
	});

	it('keeps trailing zeros when asked', () => {
		expect(formatCompact(1000, { trimZeros: false })).toBe('1.0K');
	});

	it('supports custom decimal places', () => {
		expect(formatCompact(1234, { decimals: 2 })).toBe('1.23K');
	});

	it('handles very small positive numbers', () => {
		const result = formatCompact(0.00042);
		expect(result).toBe('0.00042');
	});

	it('supports lowercase suffixes', () => {
		expect(formatCompact(1500, { lowercase: true })).toBe('1.5k');
	});

	it('returns dash for NaN', () => {
		expect(formatCompact(NaN)).toBe('—');
	});
});

// ════════════════════════════════════════════════════════════════
// formatWei
// ════════════════════════════════════════════════════════════════

describe('formatWei', () => {
	const ONE_TOKEN = 1_000_000_000_000_000_000n; // 1e18

	it('formats one token', () => {
		expect(formatWei(ONE_TOKEN)).toBe('1.00');
	});

	it('formats fractional tokens', () => {
		expect(formatWei(ONE_TOKEN / 2n)).toBe('0.50');
	});

	it('formats zero with decimal places', () => {
		expect(formatWei(0n)).toBe('0.00');
	});

	it('formats large amounts with separators', () => {
		expect(formatWei(ONE_TOKEN * 1_000_000n)).toBe('1,000,000.00');
	});

	it('formats large amounts in compact mode', () => {
		expect(formatWei(ONE_TOKEN * 1_500_000n, { compact: true })).toBe('1.5M');
	});

	it('respects custom display decimals', () => {
		expect(formatWei(ONE_TOKEN * 3n + ONE_TOKEN / 3n, { displayDecimals: 4 })).toBe('3.3333');
	});

	it('handles negative amounts', () => {
		expect(formatWei(-ONE_TOKEN * 5n)).toBe('-5.00');
	});

	it('supports custom token decimals (e.g. USDC = 6)', () => {
		const oneUSDC = 1_000_000n;
		expect(formatWei(oneUSDC * 100n, { tokenDecimals: 6 })).toBe('100.00');
	});

	it('supports showSign', () => {
		expect(formatWei(ONE_TOKEN * 10n, { showSign: true })).toBe('+10.00');
	});
});

// ════════════════════════════════════════════════════════════════
// formatPercentNumber
// ════════════════════════════════════════════════════════════════

describe('formatPercentNumber', () => {
	it('formats a ratio as percentage', () => {
		expect(formatPercentNumber(0.856)).toBe('86%');
	});

	it('formats with decimal places', () => {
		expect(formatPercentNumber(0.856, { decimals: 1 })).toBe('85.6%');
	});

	it('handles already-scaled values', () => {
		expect(formatPercentNumber(85.6, { alreadyScaled: true, decimals: 1 })).toBe('85.6%');
	});

	it('shows positive sign', () => {
		expect(formatPercentNumber(0.05, { showSign: true })).toBe('+5%');
	});

	it('shows negative sign', () => {
		expect(formatPercentNumber(-0.05, { showSign: true })).toBe('-5%');
	});

	it('formats zero', () => {
		expect(formatPercentNumber(0)).toBe('0%');
	});

	it('can omit the % symbol', () => {
		expect(formatPercentNumber(0.5, { symbol: false })).toBe('50');
	});

	it('returns dash for NaN', () => {
		expect(formatPercentNumber(NaN)).toBe('—');
	});
});

// ════════════════════════════════════════════════════════════════
// formatMultiplier
// ════════════════════════════════════════════════════════════════

describe('formatMultiplier', () => {
	it('formats with default 2 decimals', () => {
		expect(formatMultiplier(2.5)).toBe('2.50x');
	});

	it('formats large multipliers', () => {
		expect(formatMultiplier(100)).toBe('100.00x');
	});

	it('formats with custom decimals', () => {
		expect(formatMultiplier(1.005, 3)).toBe('1.005x');
	});

	it('returns dash for NaN', () => {
		expect(formatMultiplier(NaN)).toBe('—');
	});
});

// ════════════════════════════════════════════════════════════════
// formatSmart
// ════════════════════════════════════════════════════════════════

describe('formatSmart', () => {
	it('uses compact for large numbers', () => {
		expect(formatSmart(1_234_567)).toBe('1.2M');
		expect(formatSmart(50_000)).toBe('50K');
	});

	it('uses separators + decimals for mid-range', () => {
		expect(formatSmart(1234)).toBe('1,234');
		expect(formatSmart(42.567)).toBe('42.57');
	});

	it('shows meaningful precision for small numbers', () => {
		expect(formatSmart(0.00042)).toBe('0.00042');
	});

	it('formats zero', () => {
		expect(formatSmart(0)).toBe('0');
	});

	it('formats negative numbers', () => {
		expect(formatSmart(-50_000)).toBe('-50K');
		expect(formatSmart(-42.5)).toBe('-42.5');
	});

	it('supports showSign', () => {
		expect(formatSmart(1234, { showSign: true })).toBe('+1,234');
	});

	it('returns dash for NaN', () => {
		expect(formatSmart(NaN)).toBe('—');
	});
});
