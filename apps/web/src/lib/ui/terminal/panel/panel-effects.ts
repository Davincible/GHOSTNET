// ════════════════════════════════════════════════════════════════
// GHOSTNET Panel Effects — Pure Functions
// ════════════════════════════════════════════════════════════════
// Zero Svelte imports. Trivially unit-testable.
// Resolves attention states to Box props and computes timing values.

import type {
	PanelAttention,
	PanelTransientAttention,
	PanelBorderColor,
	PanelAnimationSpeed,
} from './panel-types';

// ════════════════════════════════════════════════════════════════
// ATTENTION CLASSIFICATION
// ════════════════════════════════════════════════════════════════

const TRANSIENT_STATES: ReadonlySet<PanelAttention> = new Set([
	'highlight',
	'alert',
	'success',
	'critical',
]);

export function isTransientAttention(state: PanelAttention): state is PanelTransientAttention {
	return TRANSIENT_STATES.has(state);
}

// ════════════════════════════════════════════════════════════════
// ATTENTION → BOX PROP RESOLUTION
// ════════════════════════════════════════════════════════════════

const ATTENTION_BORDER_COLOR: Partial<Record<PanelAttention, PanelBorderColor>> = {
	alert: 'red',
	critical: 'red',
	success: 'cyan',
	highlight: 'bright',
	focused: 'bright',
};

const ATTENTION_GLOW: Partial<Record<PanelAttention, boolean>> = {
	alert: true,
	critical: true,
	success: true,
	highlight: true,
	focused: true,
	blackout: false,
	dimmed: false,
};

/**
 * Resolve effective border color.
 * Returns override color for attention state, or null to use configured.
 */
export function resolveAttentionBorderColor(
	attention: PanelAttention | null,
): PanelBorderColor | null {
	if (!attention) return null;
	return ATTENTION_BORDER_COLOR[attention] ?? null;
}

/**
 * Resolve effective glow state.
 * Returns override for attention state, or null to use configured.
 */
export function resolveAttentionGlow(attention: PanelAttention | null): boolean | null {
	if (!attention) return null;
	return ATTENTION_GLOW[attention] ?? null;
}

// ════════════════════════════════════════════════════════════════
// TIMING
// ════════════════════════════════════════════════════════════════

/** Speed multipliers applied to base animation durations */
const SPEED_MULTIPLIER: Record<PanelAnimationSpeed, number> = {
	fast: 0.5,
	normal: 1.0,
	slow: 1.5,
};

/** Base durations in ms for each animation type */
const BASE_DURATIONS = {
	boot: 400,
	glitch: 250,
	shutdown: 300,
	attention: 2000,
	critical: 1500,
} as const;

export type AnimationKey = keyof typeof BASE_DURATIONS;

export function getAnimationDuration(
	animation: AnimationKey,
	speed: PanelAnimationSpeed = 'normal',
): number {
	return BASE_DURATIONS[animation] * SPEED_MULTIPLIER[speed];
}

/**
 * Returns CSS duration string for use in style bindings.
 */
export function getCssDuration(
	animation: AnimationKey,
	speed: PanelAnimationSpeed = 'normal',
): string {
	return `${getAnimationDuration(animation, speed)}ms`;
}

// ════════════════════════════════════════════════════════════════
// ANIMATION NAME PREFIX
// ════════════════════════════════════════════════════════════════

/** All panel animation names start with this prefix */
export const PANEL_ANIMATION_PREFIX = 'panel-' as const;

/**
 * Check if an animation name belongs to Panel.
 * Used in animationend handler to avoid responding to child animations.
 */
export function isPanelAnimation(animationName: string): boolean {
	return animationName.startsWith(PANEL_ANIMATION_PREFIX);
}

// ════════════════════════════════════════════════════════════════
// OVERLAY RESOLUTION
// ════════════════════════════════════════════════════════════════

/** Attention/ambient states that require the overlay div */
const OVERLAY_ATTENTION: ReadonlySet<PanelAttention> = new Set(['alert', 'critical']);
const OVERLAY_AMBIENT: ReadonlySet<string> = new Set(['static', 'scan']);

export function needsOverlay(
	attention: PanelAttention | null,
	ambientEffect: string | null,
): boolean {
	if (attention && OVERLAY_ATTENTION.has(attention)) return true;
	if (ambientEffect && OVERLAY_AMBIENT.has(ambientEffect)) return true;
	return false;
}
