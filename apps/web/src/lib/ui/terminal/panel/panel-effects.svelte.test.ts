import { describe, it, expect } from 'vitest';
import {
	resolveAttentionBorderColor,
	resolveAttentionGlow,
	isTransientAttention,
	getAnimationDuration,
	getCssDuration,
	isPanelAnimation,
	needsOverlay,
} from './panel-effects';

// ════════════════════════════════════════════════════════════════
// resolveAttentionBorderColor
// ════════════════════════════════════════════════════════════════

describe('resolveAttentionBorderColor', () => {
	it('returns null when attention is null', () => {
		expect(resolveAttentionBorderColor(null)).toBeNull();
	});

	it('returns red for alert', () => {
		expect(resolveAttentionBorderColor('alert')).toBe('red');
	});

	it('returns red for critical', () => {
		expect(resolveAttentionBorderColor('critical')).toBe('red');
	});

	it('returns cyan for success', () => {
		expect(resolveAttentionBorderColor('success')).toBe('cyan');
	});

	it('returns bright for highlight', () => {
		expect(resolveAttentionBorderColor('highlight')).toBe('bright');
	});

	it('returns bright for focused', () => {
		expect(resolveAttentionBorderColor('focused')).toBe('bright');
	});

	it('returns null for dimmed (no border override)', () => {
		expect(resolveAttentionBorderColor('dimmed')).toBeNull();
	});

	it('returns null for blackout (no border override)', () => {
		expect(resolveAttentionBorderColor('blackout')).toBeNull();
	});
});

// ════════════════════════════════════════════════════════════════
// resolveAttentionGlow
// ════════════════════════════════════════════════════════════════

describe('resolveAttentionGlow', () => {
	it('returns null when attention is null', () => {
		expect(resolveAttentionGlow(null)).toBeNull();
	});

	it('returns true for alert', () => {
		expect(resolveAttentionGlow('alert')).toBe(true);
	});

	it('returns true for critical', () => {
		expect(resolveAttentionGlow('critical')).toBe(true);
	});

	it('returns true for success', () => {
		expect(resolveAttentionGlow('success')).toBe(true);
	});

	it('returns true for highlight', () => {
		expect(resolveAttentionGlow('highlight')).toBe(true);
	});

	it('returns true for focused', () => {
		expect(resolveAttentionGlow('focused')).toBe(true);
	});

	it('returns false for blackout', () => {
		expect(resolveAttentionGlow('blackout')).toBe(false);
	});

	it('returns false for dimmed', () => {
		expect(resolveAttentionGlow('dimmed')).toBe(false);
	});
});

// ════════════════════════════════════════════════════════════════
// isTransientAttention
// ════════════════════════════════════════════════════════════════

describe('isTransientAttention', () => {
	it('identifies highlight as transient', () => {
		expect(isTransientAttention('highlight')).toBe(true);
	});

	it('identifies alert as transient', () => {
		expect(isTransientAttention('alert')).toBe(true);
	});

	it('identifies success as transient', () => {
		expect(isTransientAttention('success')).toBe(true);
	});

	it('identifies critical as transient', () => {
		expect(isTransientAttention('critical')).toBe(true);
	});

	it('identifies blackout as persistent', () => {
		expect(isTransientAttention('blackout')).toBe(false);
	});

	it('identifies dimmed as persistent', () => {
		expect(isTransientAttention('dimmed')).toBe(false);
	});

	it('identifies focused as persistent', () => {
		expect(isTransientAttention('focused')).toBe(false);
	});
});

// ════════════════════════════════════════════════════════════════
// getAnimationDuration
// ════════════════════════════════════════════════════════════════

describe('getAnimationDuration', () => {
	it('returns base duration at normal speed', () => {
		expect(getAnimationDuration('boot', 'normal')).toBe(960);
	});

	it('returns halved duration at fast speed', () => {
		expect(getAnimationDuration('boot', 'fast')).toBe(480);
	});

	it('returns 1.5x duration at slow speed', () => {
		expect(getAnimationDuration('boot', 'slow')).toBe(1440);
	});

	it('defaults to normal speed', () => {
		expect(getAnimationDuration('boot')).toBe(960);
	});

	it('handles glitch duration', () => {
		expect(getAnimationDuration('glitch', 'normal')).toBe(500);
	});

	it('handles expand duration', () => {
		expect(getAnimationDuration('expand', 'normal')).toBe(800);
	});

	it('handles attention duration', () => {
		expect(getAnimationDuration('attention', 'normal')).toBe(2000);
	});

	it('handles critical duration', () => {
		expect(getAnimationDuration('critical', 'normal')).toBe(1500);
	});

	it('handles shutdown duration', () => {
		expect(getAnimationDuration('shutdown', 'normal')).toBe(300);
	});
});

// ════════════════════════════════════════════════════════════════
// getCssDuration
// ════════════════════════════════════════════════════════════════

describe('getCssDuration', () => {
	it('returns CSS duration string at normal speed', () => {
		expect(getCssDuration('boot', 'normal')).toBe('960ms');
	});

	it('returns CSS duration string at fast speed', () => {
		expect(getCssDuration('boot', 'fast')).toBe('480ms');
	});

	it('defaults to normal speed', () => {
		expect(getCssDuration('attention')).toBe('2000ms');
	});
});

// ════════════════════════════════════════════════════════════════
// isPanelAnimation
// ════════════════════════════════════════════════════════════════

describe('isPanelAnimation', () => {
	it('matches panel animation names', () => {
		expect(isPanelAnimation('panel-enter-boot')).toBe(true);
		expect(isPanelAnimation('panel-attn-alert')).toBe(true);
		expect(isPanelAnimation('panel-ambient-pulse')).toBe(true);
	});

	it('rejects non-panel animation names', () => {
		expect(isPanelAnimation('fade-in')).toBe(false);
		expect(isPanelAnimation('slideUp')).toBe(false);
		expect(isPanelAnimation('')).toBe(false);
	});
});

// ════════════════════════════════════════════════════════════════
// needsOverlay
// ════════════════════════════════════════════════════════════════

describe('needsOverlay', () => {
	it('returns false when both null', () => {
		expect(needsOverlay(null, null)).toBe(false);
	});

	it('returns true for alert attention', () => {
		expect(needsOverlay('alert', null)).toBe(true);
	});

	it('returns true for critical attention', () => {
		expect(needsOverlay('critical', null)).toBe(true);
	});

	it('returns false for highlight attention (no overlay needed)', () => {
		expect(needsOverlay('highlight', null)).toBe(false);
	});

	it('returns false for persistent attention states', () => {
		expect(needsOverlay('blackout', null)).toBe(false);
		expect(needsOverlay('dimmed', null)).toBe(false);
		expect(needsOverlay('focused', null)).toBe(false);
	});

	it('returns true for static ambient', () => {
		expect(needsOverlay(null, 'static')).toBe(true);
	});

	it('returns true for scan ambient', () => {
		expect(needsOverlay(null, 'scan')).toBe(true);
	});

	it('returns false for pulse ambient (no overlay needed)', () => {
		expect(needsOverlay(null, 'pulse')).toBe(false);
	});

	it('returns false for heartbeat ambient (no overlay needed)', () => {
		expect(needsOverlay(null, 'heartbeat')).toBe(false);
	});

	it('returns true when attention needs overlay even if ambient does not', () => {
		expect(needsOverlay('alert', 'pulse')).toBe(true);
	});
});
