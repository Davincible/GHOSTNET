# Panel Enhancement — Architecture Plan

> **Status:** Planned
> **Component:** `apps/web/src/lib/ui/terminal/Panel.svelte`
> **Date:** 2026-01-27

---

## 1. Problem Statement

Panel is currently a **static container**. It holds content — that's it. But in a survival game where players are jacked into a network, getting traced, dying, winning — the containers themselves should be **alive**. They should breathe, react, alert, and transition.

In a hacker terminal, panels aren't just windows — they're **live system readouts**. When something changes, the panel *tells you* before you read the content. The terminal isn't a window into GHOSTNET. The terminal *is* GHOSTNET.

---

## 2. Forces & Constraints

Before drawing shapes, name the forces:

| Force | Implication |
|-------|-------------|
| **82 existing consumers** | Zero breaking changes. Every new prop must default to current behavior. |
| **Box.svelte is the border renderer** | Effects that touch the border must work *through* Box's existing props, not around them. No `:global()` hacks reaching into Box internals. |
| **Settings store has `effectsEnabled`** | All animations/effects must respect this toggle. When disabled, panels render instantly with no visual effects. |
| **`prefers-reduced-motion`** | CSS media query must disable or simplify all animations. |
| **Design tokens define timing** | We use `--duration-fast`, `--duration-normal`, `--duration-slow`, etc. No magic numbers. |
| **Svelte 5 scoped styles** | `@keyframes` defined in `<style>` are component-scoped. They live in Panel's style block. |
| **GPU compositing** | Animations must use compositor-friendly properties: `opacity`, `transform`, `clip-path`, `filter`. No animating `width`, `height`, `margin`, `padding`. |
| **Panel wraps Box** | Panel's outer `div.panel` is the control surface. CSS on this wrapper controls the visual state of everything inside — including Box — via `filter`, `opacity`, `transform`, `clip-path`. |

---

## 3. Three Enhancement Axes

### 3.1 Lifecycle Animations — How panels appear and disappear

| Animation | Description | Use Case |
|-----------|-------------|----------|
| `boot` | CRT power-on: panel expands from thin horizontal line via `clip-path`, then content fades in | Initial page load, panel first appearing |
| `glitch` | Brief clip-path displacement + hue-rotate, then resolves | Error recovery, unexpected events |
| `shutdown` | Content fades, panel collapses to center line via `clip-path` | Panel being removed |
| `none` | Instant, no animation (current behavior, **default**) | Backward compatibility |

### 3.2 Attention States — How panels signal importance

**Transient** (auto-resolve after animation completes):

| State | Visual | Duration | Use Case |
|-------|--------|----------|----------|
| `highlight` | Border brightens, subtle `filter: brightness()` pulse | ~2s | "Look here" — new data, action needed |
| `alert` | Border turns red (via prop), brightness pulse, faint red overlay | ~2s | Danger — trace scan incoming |
| `success` | Border turns cyan (via prop), brief brightness pulse | ~1.5s | Positive — extraction complete |
| `critical` | Border turns red, rapid pulse + panel shake (`translateX`) | ~1.5s | Immediate danger — about to die |

**Persistent** (remain until prop changes to `null`):

| State | Visual | Use Case |
|-------|--------|----------|
| `blackout` | `filter: brightness(0.15)` — nearly dark | Dead, offline, inactive |
| `dimmed` | `opacity: 0.5`, `filter: saturate(0.5)` | Secondary importance |
| `focused` | `filter: brightness(1.05)`, `transform: scale(1.01)` | Active panel in multi-panel layout |

### 3.3 Ambient Effects — Persistent visual behaviors

| Effect | Visual | Use Case |
|--------|--------|----------|
| `pulse` | Slow `filter: brightness()` breathing, infinite | Panel is "alive", active data |
| `heartbeat` | Brief brightness spike at regular intervals, infinite | Connected and healthy |
| `static` | Faint TV noise pattern on overlay div | Degraded connection, stale data |
| `scan` | Horizontal line sweeps down via overlay pseudo-element | Monitoring mode |

---

## 4. Architectural Decisions

### ADR-1: Effects work through prop mediation and wrapper CSS

**Context:** Effects need to change border color, glow, and visual appearance.

**Decision:** Two mechanisms:
1. Panel computes `effectiveBorderColor` and `effectiveGlow`, passes them to Box via its existing props. Box never knows about attention/effects.
2. CSS `filter`, `opacity`, `transform`, `clip-path` on the `.panel` wrapper div. These cascade to everything inside, including Box.
3. A single overlay div (absolutely positioned, `pointer-events: none`, `aria-hidden="true"`) for effects like red wash, static noise, scan sweep.

**Consequence:** Box.svelte remains **completely unchanged**. Panel mediates. Clean boundary.

### ADR-2: Attention states are declarative props with animationend callbacks

**Context:** Transient attention states play once and should auto-resolve. Need a clean API.

**Decision:**
- Parent sets `attention="alert"` prop.
- Panel applies CSS animation class. Animation plays once, ending at normal appearance (`animation-fill-mode: forwards` back to normal).
- Panel listens for `animationend` DOM event, calls `onAttentionEnd?.()`.
- Parent can clear its state in the callback.
- If parent never clears, panel still *looks* normal (animation ended at normal state).
- To re-trigger: parent sets `null` then back to `"alert"`. Svelte removes class then re-adds → animation restarts.
- No `setTimeout` — we use the actual CSS event.

**Consequence:** Fully declarative. No imperative methods. Predictable, testable.

### ADR-3: Three orthogonal concerns on one wrapper element

**Context:** Lifecycle, attention, and ambient effects must compose without conflict.

**Decision:** All three apply CSS classes to the same `.panel` wrapper div. They use different CSS properties:

| Concern | CSS Properties Used | Conflict Risk |
|---------|-------------------|---------------|
| Lifecycle (enter) | `clip-path`, `opacity` | None — plays once on mount |
| Attention (transient) | `filter` (brightness), overlay `background` | Low — short bursts |
| Attention (persistent) | `filter`, `opacity` | None — static values |
| Ambient | `filter` animation (infinite loop) | None — continuous |

A panel can simultaneously boot in, have a heartbeat ambient, and flash an alert.

**Consequence:** No wrapper nesting. No filter compositing conflicts. One element, clean CSS.

### ADR-4: Panel module gets its own folder

**Context:** Enhancement adds `panel-types.ts` and `panel-effects.ts` alongside `Panel.svelte`. Flat directory gets cluttered.

**Decision:** Group Panel files into a `panel/` subfolder with its own barrel export:

```
terminal/
├── panel/
│   ├── Panel.svelte           ← The component (orchestrator)
│   ├── panel-types.ts         ← Type definitions
│   ├── panel-effects.ts       ← Pure functions (resolution, timing, classification)
│   └── index.ts               ← Re-exports component + types
├── Box.svelte
├── Flicker.svelte
├── Scanlines.svelte
├── ScreenFlash.svelte
├── Shell.svelte
└── index.ts                   ← Updated: imports Panel from ./panel
```

`terminal/index.ts` changes from:
```ts
export { default as Panel } from './Panel.svelte';
```
to:
```ts
export { default as Panel } from './panel';
export type { PanelAttention, PanelAmbientEffect, PanelEnterAnimation } from './panel';
```

**Consequence:** All 82 consumers continue importing `{ Panel } from '$lib/ui/terminal'` — zero changes. Internal files are co-located and discoverable. Types are importable by consumers who need to programmatically construct prop values.

---

## 5. File Structure & Responsibilities

### `panel/panel-types.ts` — Type definitions

Importable by both Panel internals and consumers.

```typescript
// ════════════════════════════════════════════════════════════════
// LIFECYCLE
// ════════════════════════════════════════════════════════════════

/** How the panel enters the viewport */
export type PanelEnterAnimation = 'boot' | 'glitch' | 'none';

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
```

### `panel/panel-effects.ts` — Pure functions

Zero Svelte imports. Trivially unit-testable.

```typescript
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
  'highlight', 'alert', 'success', 'critical',
]);

export function isTransientAttention(
  state: PanelAttention
): state is PanelTransientAttention {
  return TRANSIENT_STATES.has(state);
}

// ════════════════════════════════════════════════════════════════
// ATTENTION → BOX PROP RESOLUTION
// ════════════════════════════════════════════════════════════════

const ATTENTION_BORDER_COLOR: Partial<Record<PanelAttention, PanelBorderColor>> = {
  alert:     'red',
  critical:  'red',
  success:   'cyan',
  highlight: 'bright',
  focused:   'bright',
};

const ATTENTION_GLOW: Partial<Record<PanelAttention, boolean>> = {
  alert:     true,
  critical:  true,
  success:   true,
  highlight: true,
  focused:   true,
  blackout:  false,
  dimmed:    false,
};

/**
 * Resolve effective border color.
 * Returns override color for attention state, or null to use configured.
 */
export function resolveAttentionBorderColor(
  attention: PanelAttention | null
): PanelBorderColor | null {
  if (!attention) return null;
  return ATTENTION_BORDER_COLOR[attention] ?? null;
}

/**
 * Resolve effective glow state.
 * Returns override for attention state, or null to use configured.
 */
export function resolveAttentionGlow(
  attention: PanelAttention | null
): boolean | null {
  if (!attention) return null;
  return ATTENTION_GLOW[attention] ?? null;
}

// ════════════════════════════════════════════════════════════════
// TIMING
// ════════════════════════════════════════════════════════════════

/** Speed multipliers applied to base animation durations */
const SPEED_MULTIPLIER: Record<PanelAnimationSpeed, number> = {
  fast:   0.5,
  normal: 1.0,
  slow:   1.5,
};

/** Base durations in ms for each animation type */
const BASE_DURATIONS = {
  boot:       400,
  glitch:     250,
  shutdown:   300,
  attention:  2000,
  critical:   1500,
} as const;

export type AnimationKey = keyof typeof BASE_DURATIONS;

export function getAnimationDuration(
  animation: AnimationKey,
  speed: PanelAnimationSpeed = 'normal'
): number {
  return BASE_DURATIONS[animation] * SPEED_MULTIPLIER[speed];
}

/**
 * Returns CSS duration string for use in style bindings.
 */
export function getCssDuration(
  animation: AnimationKey,
  speed: PanelAnimationSpeed = 'normal'
): string {
  return `${getAnimationDuration(animation, speed)}ms`;
}
```

### `panel/index.ts` — Barrel export

```typescript
export { default as default } from './Panel.svelte';
export type {
  PanelAttention,
  PanelTransientAttention,
  PanelPersistentAttention,
  PanelAmbientEffect,
  PanelEnterAnimation,
  PanelExitAnimation,
  PanelAnimationSpeed,
  PanelVariant,
  PanelBorderColor,
} from './panel-types';
```

### `panel/Panel.svelte` — Orchestrator

Contains:
- All props (existing unchanged + new with safe defaults)
- Settings integration (`effectsEnabled` gate)
- Box prop mediation (`effectiveBorderColor`, `effectiveGlow`)
- Enter animation state machine (`hasEntered`)
- Animation-end handlers (for transient attention + enter lifecycle)
- Overlay conditional rendering
- All CSS: base styles (existing), keyframes (new), effect classes (new), reduced-motion overrides

### Updated `terminal/index.ts`

```typescript
// GHOSTNET Terminal Components
export { default as Shell } from './Shell.svelte';
export { default as Scanlines } from './Scanlines.svelte';
export { default as Flicker } from './Flicker.svelte';
export { default as ScreenFlash } from './ScreenFlash.svelte';
export { default as Box } from './Box.svelte';
export { default as Panel } from './panel';
export type {
  PanelAttention,
  PanelAmbientEffect,
  PanelEnterAnimation,
} from './panel';
```

---

## 6. Component Structure (Panel.svelte)

### Props — Full interface

```typescript
interface Props {
  // ── Existing (all same defaults, zero breaking changes) ──
  title?: string;
  variant?: PanelVariant;            // default: 'single'
  borderColor?: PanelBorderColor;    // default: 'default'
  glow?: boolean;                    // default: false
  scrollable?: boolean;              // default: false
  maxHeight?: string;                // default: '400px'
  minHeight?: string;                // default: undefined
  showScrollHint?: boolean;          // default: true
  padding?: 0 | 1 | 2 | 3 | 4;     // default: 3
  children: Snippet;
  footer?: Snippet;

  // ── Lifecycle ──
  enterAnimation?: PanelEnterAnimation;     // default: 'none'
  exitAnimation?: PanelExitAnimation;       // default: 'none'
  animationSpeed?: PanelAnimationSpeed;     // default: 'normal'

  // ── Attention ──
  attention?: PanelAttention | null;        // default: null
  onAttentionEnd?: () => void;              // default: undefined

  // ── Ambient ──
  ambientEffect?: PanelAmbientEffect | null;  // default: null
}
```

### Script — Logic flow

```
Settings gate
│
├─ effectsOn = settings?.effectsEnabled ?? true
│
Box prop mediation
│
├─ effectiveBorderColor = attentionOverride ?? configured borderColor
├─ effectiveGlow = attentionOverride ?? configured glow
│
Enter animation state
│
├─ hasEntered = (enterAnimation === 'none') || !effectsOn
├─ On animationend → hasEntered = true
│
Attention animation end
│
├─ On animationend → if transient → call onAttentionEnd?.()
│
Overlay flag
│
├─ needsOverlay = effectsOn && (alert || critical || static || scan)
│
Scroll state (existing, unchanged)
│
├─ scrollContainer, canScrollDown, canScrollUp, updateScrollState
```

### Template — Structure

```svelte
<div
  class="panel"
  class:panel-scrollable={scrollable}
  class:panel-enter-boot={effectsOn && enterAnimation === 'boot' && !hasEntered}
  class:panel-enter-glitch={effectsOn && enterAnimation === 'glitch' && !hasEntered}
  class:panel-attn-highlight={effectsOn && attention === 'highlight'}
  class:panel-attn-alert={effectsOn && attention === 'alert'}
  class:panel-attn-success={effectsOn && attention === 'success'}
  class:panel-attn-critical={effectsOn && attention === 'critical'}
  class:panel-attn-blackout={effectsOn && attention === 'blackout'}
  class:panel-attn-dimmed={effectsOn && attention === 'dimmed'}
  class:panel-attn-focused={effectsOn && attention === 'focused'}
  class:panel-ambient-pulse={effectsOn && ambientEffect === 'pulse'}
  class:panel-ambient-heartbeat={effectsOn && ambientEffect === 'heartbeat'}
  class:panel-ambient-static={effectsOn && ambientEffect === 'static'}
  class:panel-ambient-scan={effectsOn && ambientEffect === 'scan'}
  style:--panel-enter-duration={getCssDuration('boot', animationSpeed)}
  style:--panel-attn-duration={getCssDuration('attention', animationSpeed)}
  onanimationend={handleAnimationEnd}
>
  <Box
    {title}
    {variant}
    borderColor={effectiveBorderColor}
    glow={effectiveGlow}
    {padding}
  >
    {#if scrollable}
      <!-- existing scroll structure, unchanged -->
    {:else}
      <!-- existing non-scroll structure, unchanged -->
    {/if}
  </Box>

  <!-- Effect overlay -->
  {#if needsOverlay}
    <div class="panel-overlay" aria-hidden="true"></div>
  {/if}
</div>
```

### Interaction diagram — How concerns compose

```
Parent sets props:              Panel computes:           Box receives:
─────────────────              ────────────────          ─────────────
borderColor="cyan"    ──┐
                        ├──►  effectiveBorderColor ──►  borderColor="red"
attention="alert"     ──┘     (alert overrides cyan)         (during alert)

glow=false            ──┐
                        ├──►  effectiveGlow ──────────►  glow=true
attention="alert"     ──┘     (alert forces glow)           (during alert)

                              CSS on .panel wrapper:
                              ──────────────────────
enterAnimation="boot" ──────► class:panel-enter-boot ──► clip-path animation
ambientEffect="pulse" ──────► class:panel-ambient-pulse ► filter animation
attention="alert"     ──────► class:panel-attn-alert ──► filter animation
                              + overlay div rendered ──► red wash background
```

When `attention` returns to `null`:
- CSS classes removed
- `effectiveBorderColor` falls back to configured `borderColor` ("cyan")
- `effectiveGlow` falls back to configured `glow` (false)
- Overlay div removed from DOM
- Persistent states (`blackout`, `dimmed`) transition out smoothly via CSS `transition`

---

## 7. CSS Architecture

All keyframes and effect classes live in Panel's `<style>` block, organized by section:

```
<style>
  /* ═══════════════════════════════════════════════════════════
     BASE — existing styles, unchanged
     ═══════════════════════════════════════════════════════════ */
  .panel { ... }
  .panel-content-wrapper { ... }
  .panel-scroll-container { ... }
  /* all existing scroll, footer styles */

  /* ═══════════════════════════════════════════════════════════
     ENTER ANIMATIONS
     ═══════════════════════════════════════════════════════════ */
  .panel-enter-boot { ... }
  @keyframes panel-enter-boot { ... }
  .panel-enter-glitch { ... }
  @keyframes panel-enter-glitch { ... }

  /* ═══════════════════════════════════════════════════════════
     ATTENTION — TRANSIENT
     ═══════════════════════════════════════════════════════════ */
  .panel-attn-highlight { ... }
  @keyframes panel-attn-highlight { ... }
  .panel-attn-alert { ... }
  @keyframes panel-attn-alert { ... }
  .panel-attn-success { ... }
  @keyframes panel-attn-success { ... }
  .panel-attn-critical { ... }
  @keyframes panel-attn-critical { ... }

  /* ═══════════════════════════════════════════════════════════
     ATTENTION — PERSISTENT
     ═══════════════════════════════════════════════════════════ */
  .panel-attn-blackout { ... }
  .panel-attn-dimmed { ... }
  .panel-attn-focused { ... }

  /* ═══════════════════════════════════════════════════════════
     AMBIENT EFFECTS
     ═══════════════════════════════════════════════════════════ */
  .panel-ambient-pulse { ... }
  @keyframes panel-ambient-pulse { ... }
  .panel-ambient-heartbeat { ... }
  @keyframes panel-ambient-heartbeat { ... }
  .panel-ambient-static { ... }
  .panel-ambient-scan { ... }
  @keyframes panel-ambient-scan { ... }

  /* ═══════════════════════════════════════════════════════════
     OVERLAY
     ═══════════════════════════════════════════════════════════ */
  .panel-overlay { ... }

  /* ═══════════════════════════════════════════════════════════
     REDUCED MOTION
     ═══════════════════════════════════════════════════════════ */
  @media (prefers-reduced-motion: reduce) {
    /* All animated classes: animation: none or opacity-only */
  }
</style>
```

### CSS property assignments per effect

| Effect | CSS Properties | Why These |
|--------|---------------|-----------|
| `boot` enter | `clip-path`, `opacity` | GPU-composited reveal. CRT power-on (thin line to full panel). |
| `glitch` enter | `clip-path`, `filter` (hue-rotate) | Brief displacement + color shift. |
| `highlight` | `filter: brightness()` animation | Brief brightening pulse. |
| `alert` | `filter: brightness()` animation + overlay `background` | Red wash + pulse. Border via prop mediation. |
| `success` | `filter: brightness()` animation | Brief cyan brightening. |
| `critical` | `filter: brightness()` + `transform: translateX()` | Shake + rapid pulse. Border via prop mediation. |
| `blackout` | `filter: brightness(0.15)`, `transition` | Persistent dim. Smooth enter/exit via transition. |
| `dimmed` | `opacity: 0.5`, `filter: saturate(0.5)`, `transition` | Persistent reduced presence. |
| `focused` | `filter: brightness(1.05)`, `transform: scale(1.01)`, `transition` | Persistent subtle emphasis. |
| `pulse` | `filter: brightness()` animation, `infinite` | Slow breathing glow. |
| `heartbeat` | `filter: brightness()` animation, `infinite` | Regular brief brightening spikes. |
| `static` | overlay `background` (CSS gradient noise pattern) | Faint TV static. |
| `scan` | overlay `::after` with `translateY` animation | Horizontal line sweeping down. |

### Boot animation detail

```css
.panel-enter-boot {
  animation: panel-enter-boot var(--panel-enter-duration) var(--ease-out) forwards;
}

@keyframes panel-enter-boot {
  0% {
    clip-path: inset(50% 0 50% 0);  /* invisible: clipped to zero height */
    opacity: 0.6;
  }
  60% {
    clip-path: inset(0 0 0 0);      /* fully revealed */
    opacity: 0.8;
  }
  100% {
    clip-path: inset(0 0 0 0);
    opacity: 1;                      /* content fully visible */
  }
}
```

CRT power-on: starts as thin horizontal line at center, expands vertically, then content brightens. Using `clip-path` preserves layout (no distortion). GPU-composited.

---

## 8. Edge Cases & Failure Modes

| Scenario | Behavior |
|----------|----------|
| `attention` changes mid-animation | New class replaces old. CSS restarts. `animationend` checks `animationName` prefix — no mis-fire. |
| `effectsEnabled` toggled while animating | Classes removed instantly. Panel snaps to final state. Correct for a settings toggle. |
| No settings context (used outside app layout) | `try/catch` on `getSettings()`. Falls back to `effectsOn = true`. |
| `enterAnimation` on SSR | `hasEntered` starts `false`. Hydration applies class. Animation plays on client. |
| Multiple `animationend` from children | We check `e.animationName` starts with `panel-`. Only our animations trigger handlers. |
| Both `attention="alert"` and `ambientEffect="pulse"` | Both apply. `filter: brightness` values compound. During alert burst, pulse modulation stacks — creates urgency. Visually correct. |
| Consumer never clears transient attention prop | Animation ends at normal appearance. Panel looks normal. No visual harm. |
| Re-trigger same attention value | Parent sets `null` then back to value. Svelte removes class, re-adds → CSS animation restarts. |

---

## 9. Accessibility

- All animations respect `prefers-reduced-motion: reduce` — fall back to instant transitions or opacity-only
- All overlay elements use `aria-hidden="true"` and `pointer-events: none`
- `blackout` dimming stays above `brightness(0.15)` — content remains technically accessible
- Attention states don't carry semantic meaning alone — parent components set `aria-live`, `role`, etc. as appropriate
- Screen readers don't see overlays — no phantom elements in the a11y tree
- `onAttentionEnd` callback lets parents update ARIA attributes after transient effects complete

---

## 10. Testing Strategy

### `panel-effects.test.ts` — Pure unit tests

No DOM. No Svelte. No runes.

```
- resolveAttentionBorderColor: alert → red, success → cyan, dimmed → null, null → null
- resolveAttentionGlow: alert → true, blackout → false, null → null
- isTransientAttention: highlight → true, blackout → false
- getAnimationDuration: boot/normal → 400, boot/fast → 200, boot/slow → 600
- getCssDuration: boot/normal → "400ms"
```

### `Panel.svelte.test.ts` — Component rendering tests

Requires `.svelte` in filename for runes support.

```
- Default render: matches current output (regression guard)
- New props at defaults: no change in rendered output
- attention="alert": Box receives borderColor="red", glow=true
- attention=null: Box receives configured borderColor/glow
- attention="blackout": .panel-attn-blackout class present
- effectsEnabled=false: no effect classes on wrapper
- ambientEffect="pulse": .panel-ambient-pulse class present
- enterAnimation="boot": .panel-enter-boot class present initially
- overlay: rendered when alert/critical/static/scan, absent otherwise
- onAttentionEnd: called after animationend event fires
- Scroll behavior: unchanged from current
```

---

## 11. Implementation Phases

### Phase 1 — Foundation + Attention States (highest gameplay impact)

Files created:
- `panel/panel-types.ts`
- `panel/panel-effects.ts`
- `panel/panel-effects.test.ts`
- `panel/index.ts`

Files modified:
- `Panel.svelte` → moved to `panel/Panel.svelte`, enhanced
- `terminal/index.ts` → updated import path

Delivers: `highlight`, `alert`, `success`, `critical`, `blackout`, `dimmed`, `focused`

### Phase 2 — Enter Animations

Files modified:
- `panel/Panel.svelte` — add enter classes, `hasEntered` state, CSS keyframes

Delivers: `boot`, `glitch` enter animations

### Phase 3 — Ambient Effects

Files modified:
- `panel/Panel.svelte` — add ambient classes, CSS keyframes, overlay patterns

Delivers: `pulse`, `heartbeat`, `static`, `scan`

### Phase 4 — Exit Animations (lowest priority)

Files modified:
- `panel/Panel.svelte` — add exit animation support

Delivers: `shutdown`, `glitch` exit animations

Each phase is independently shippable. Each maintains full backward compatibility.

---

## 12. Usage Examples

### Player jacks in — panels boot up

```svelte
<Panel title="POSITION" enterAnimation="boot" animationSpeed="normal">
<Panel title="LIVE FEED" enterAnimation="boot" animationSpeed="normal">
```

Stagger with delays at the parent level. Each panel draws its border, then content fills in.

### Trace scan approaching — danger

```svelte
<Panel title="POSITION" attention="alert" borderColor="cyan">
```

Border flashes red, faint red wash over content. Player *feels* the danger before reading.

### Player is dead — blackout

```svelte
<Panel title="POSITION" attention="blackout">
```

Panel goes nearly dark. Absence communicates loss.

### Live feed with heartbeat

```svelte
<Panel title="LIVE FEED" ambientEffect="heartbeat" scrollable>
```

Border subtly brightens every few seconds. Feed is alive. Network is breathing.

### Network degraded

```svelte
<Panel title="NETWORK" ambientEffect="static">
```

Faint static overlay. Something's wrong. Data might not be fresh.

### Combined — booting into a live, alerting panel

```svelte
<Panel
  title="POSITION"
  enterAnimation="boot"
  ambientEffect="pulse"
  attention={traceIncoming ? 'alert' : null}
  onAttentionEnd={() => traceIncoming = false}
>
```

---

## 13. Deliberate Omissions

| Omission | Reason |
|----------|--------|
| `corrupt` ambient (random char replacement) | Would require Panel to manipulate content it doesn't own. Breaks encapsulation. Build a `<GlitchText>` wrapper component instead. |
| `typeIn` enter (char by char) | Same — Panel doesn't own content text. A `<TypeWriter>` component is the right pattern. |
| `reload` transition (scramble on content change) | Requires intercepting content changes. Beyond Panel's responsibility. |
| Per-animation custom durations | One `animationSpeed` prop for simplicity. Can add per-animation overrides later without breaking. |
| Imperative API (`panel.flash()`) | Declarative props are more predictable, testable, Svelte-idiomatic. |
| Modifying Box.svelte | Box is the border renderer. It stays focused. Panel mediates through props. |

Each is a bet that **boundaries matter more than features**. If any proves wrong, the architecture supports adding them later without restructuring.
