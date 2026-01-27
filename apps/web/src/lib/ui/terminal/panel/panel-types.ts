// ════════════════════════════════════════════════════════════════
// GHOSTNET Panel Types
// ════════════════════════════════════════════════════════════════
// Type definitions for Panel lifecycle, attention, and ambient effects.
// Shared by Panel internals and consumers who need programmatic prop values.

// ════════════════════════════════════════════════════════════════
// LIFECYCLE
// ════════════════════════════════════════════════════════════════

/** How the panel enters the viewport */
export type PanelEnterAnimation = 'boot' | 'glitch' | 'expand' | 'none';

/** How the panel exits (if removed from DOM) */
export type PanelExitAnimation = 'shutdown' | 'glitch' | 'none';

/** Animation speed multiplier */
export type PanelAnimationSpeed = 'fast' | 'normal' | 'slow';

// ════════════════════════════════════════════════════════════════
// ATTENTION
// ════════════════════════════════════════════════════════════════

/** Transient attention states — auto-resolve after animation */
export type PanelTransientAttention = 'highlight' | 'alert' | 'success' | 'critical';

/** Persistent attention states — remain until cleared */
export type PanelPersistentAttention = 'blackout' | 'dimmed' | 'focused';

/** All attention states */
export type PanelAttention = PanelTransientAttention | PanelPersistentAttention;

// ════════════════════════════════════════════════════════════════
// AMBIENT
// ════════════════════════════════════════════════════════════════

/** Persistent ambient visual effects */
export type PanelAmbientEffect = 'pulse' | 'static' | 'scan' | 'heartbeat';

// ════════════════════════════════════════════════════════════════
// EXISTING (extracted, unchanged semantics)
// ════════════════════════════════════════════════════════════════

export type PanelVariant = 'single' | 'double' | 'rounded';
export type PanelBorderColor = 'default' | 'bright' | 'dim' | 'cyan' | 'amber' | 'red';
