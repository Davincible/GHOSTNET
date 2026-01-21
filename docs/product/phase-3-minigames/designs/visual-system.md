# GHOSTNET Arcade Visual Design System

## Design Philosophy

**Version:** 1.0  
**Status:** Active  
**Applies to:** Phase 3 Minigames (HASH CRASH, CODE DUEL, ICE BREAKER, etc.)

---

### Shokunin Craftsmanship

The GHOSTNET visual system embodies **Shokunin** - the Japanese concept of mastering one's craft through relentless attention to detail. Every pixel, every animation, every interaction must serve the player's experience.

```
The Three Pillars of GHOSTNET Design:

1. TENSION    Every visual creates anticipation
              Countdowns pulse. Multipliers glow. Death lurks.

2. CLARITY    Information hierarchy is sacred
              Players must NEVER wonder "what just happened?"

3. IMMERSION  The terminal is your reality
              No rounded corners. No soft gradients. No escape.
```

**Design Mantras:**
- If it doesn't add tension, remove it
- If it obscures critical info, redesign it
- If it breaks the terminal aesthetic, reject it
- If you can't build it in ASCII, question whether you need it

---

## Color System

### Core Palette

```css
/* ═══════════════════════════════════════════════════════════════════
   CORE PALETTE - apps/web/src/lib/ui/styles/tokens.css
   ═══════════════════════════════════════════════════════════════════ */

:root {
  /* ─── BACKGROUNDS ─── */
  /* Deep void blacks - the digital abyss */
  --color-bg-void: #030305;         /* Deepest - true void */
  --color-bg-primary: #050507;      /* Near black - main background */
  --color-bg-secondary: #0a0a0e;    /* Panel backgrounds */
  --color-bg-tertiary: #12121a;     /* Elevated surfaces */
  --color-bg-elevated: #18182a;     /* Hover states, highlights */

  /* ─── PRIMARY ACCENT ─── */
  /* Teal/Cyan - The signature GHOSTNET phosphor */
  --color-accent: #00e5cc;          /* Primary - key metrics, active states */
  --color-accent-bright: #00fff2;   /* Bright - highlights, glows */
  --color-accent-mid: #00b8a3;      /* Medium - secondary elements */
  --color-accent-dim: #007a6b;      /* Dim - borders, subtle accents */
  --color-accent-faint: #004d43;    /* Very subtle accents */
  --color-accent-glow: rgba(0, 229, 204, 0.25);

  /* ─── TEXT HIERARCHY ─── */
  --color-text-primary: #ffffff;    /* Pure white - primary data */
  --color-text-secondary: #a0a0b0;  /* Medium gray - labels */
  --color-text-tertiary: #606070;   /* Dim gray - disabled, hints */
  --color-text-muted: #404050;      /* Very dim - borders as text */

  /* ─── BORDERS ─── */
  --color-border-subtle: #1a1a24;   /* Barely visible */
  --color-border-default: #252532;  /* Default card borders */
  --color-border-strong: #35354a;   /* Emphasized borders */
}
```

### Semantic Colors

```css
:root {
  /* ═══════════════════════════════════════════════════════════════════
     SEMANTIC COLORS - Functional, not decorative
     ═══════════════════════════════════════════════════════════════════ */

  /* SUCCESS / PROFIT - Green for gains */
  --color-success: #00e5cc;         /* Alias to accent */
  --color-profit: #00ff88;          /* Gains, positive numbers */
  --color-profit-dim: #00a058;
  --color-profit-glow: rgba(0, 255, 136, 0.2);

  /* DANGER / LOSS - Red for deaths, failures */
  --color-danger: #ff3366;          /* Deaths, losses, errors */
  --color-danger-dim: #a02040;
  --color-danger-glow: rgba(255, 51, 102, 0.25);
  --color-loss: #ff4466;            /* Financial losses */

  /* WARNING / CAUTION - Amber for alerts */
  --color-warning: #ffb000;         /* Warnings, caution */
  --color-warning-dim: #a07000;
  --color-warning-glow: rgba(255, 176, 0, 0.2);

  /* INFO / INTERACTIVE - Cyan for links */
  --color-info: #00e5ff;            /* Info, links, interactive */
  --color-info-dim: #00a0b0;
  --color-info-glow: rgba(0, 229, 255, 0.2);

  /* GOLD - Special achievements, jackpots */
  --color-gold: #ffd700;
  --color-gold-glow: rgba(255, 215, 0, 0.3);
}
```

### Risk Level Colors

```css
:root {
  /* ═══════════════════════════════════════════════════════════════════
     RISK LEVEL COLORS - Security clearance hierarchy
     ═══════════════════════════════════════════════════════════════════ */

  --color-level-vault: #00e5cc;       /* Teal - safe */
  --color-level-mainframe: #00e5ff;   /* Cyan - low risk */
  --color-level-subnet: #ffb000;      /* Amber - medium risk */
  --color-level-darknet: #ff6633;     /* Orange - high risk */
  --color-level-black-ice: #ff3366;   /* Red - extreme risk */
}
```

### Game-Specific Accent Colors

```css
:root {
  /* ═══════════════════════════════════════════════════════════════════
     GAME ACCENT COLORS - Each game has a signature color
     ═══════════════════════════════════════════════════════════════════ */

  /* HASH CRASH - Rising multiplier spectrum */
  --color-crash-low: #00ff88;         /* 1x-2x - green */
  --color-crash-mid: #00ffcc;         /* 2x-5x - teal */
  --color-crash-high: #00ffff;        /* 5x-10x - cyan */
  --color-crash-extreme: #ffff00;     /* 10x+ - gold */
  --color-crash-bust: #ff0000;        /* Crashed - red */

  /* CODE DUEL - Competitive PvP */
  --color-duel-player: #00e5cc;       /* You */
  --color-duel-opponent: #ff6633;     /* Opponent */
  --color-duel-spectator: #8888aa;    /* Spectators */

  /* ICE BREAKER - Ice type colors */
  --color-ice-static: #00ffff;        /* Static ice */
  --color-ice-blink: #ff00ff;         /* Blink ice */
  --color-ice-patrol: #ffff00;        /* Patrol ice */
  --color-ice-sequence: #00ff00;      /* Sequence ice */
  --color-ice-shadow: #8800ff;        /* Shadow ice */
  --color-ice-mirror: #ff8800;        /* Mirror ice */
  --color-ice-adaptive: #ff0000;      /* Boss ice */

  /* BINARY BET - Coin flip */
  --color-bet-heads: #00e5cc;         /* Heads */
  --color-bet-tails: #ff6633;         /* Tails */

  /* BOUNTY HUNT - Target acquisition */
  --color-bounty-active: #ffb000;     /* Active target */
  --color-bounty-claimed: #00ff88;    /* Claimed */
  --color-bounty-expired: #ff3366;    /* Expired */

  /* PROXY WAR - Crew battles */
  --color-crew-alpha: #00e5cc;        /* Your crew */
  --color-crew-beta: #ff3366;         /* Enemy crew */
  --color-territory: #ffb000;         /* Contested */

  /* DAILY OPS - Mission status */
  --color-mission-available: #00e5cc;
  --color-mission-active: #ffb000;
  --color-mission-complete: #00ff88;
  --color-mission-failed: #ff3366;
}
```

### Color Usage Guidelines

```
╔══════════════════════════════════════════════════════════════════════╗
║                    COLOR USAGE MATRIX                                 ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  CONTEXT          PRIMARY COLOR        SECONDARY           ACCENT    ║
║  ─────────────────────────────────────────────────────────────────── ║
║  Backgrounds      bg-primary           bg-secondary        -         ║
║  Panels/Cards     bg-secondary         bg-tertiary         accent    ║
║  Text (data)      text-primary         text-secondary      accent    ║
║  Text (labels)    text-secondary       text-tertiary       -         ║
║  Borders          border-default       border-subtle       accent-dim║
║  Active states    accent               accent-bright       -         ║
║  Hover states     bg-elevated          accent-glow         accent    ║
║  Success          profit               profit-dim          profit    ║
║  Error            danger               danger-dim          danger    ║
║  Warning          warning              warning-dim         warning   ║
║                                                                       ║
╚══════════════════════════════════════════════════════════════════════╝

RULES:
1. Never use more than 3 colors in a single component
2. Reserve bright accents for interactive/important elements only
3. Use glow effects sparingly - they lose impact when overused
4. Test all colors against bg-primary for contrast (min 4.5:1)
```

---

## Typography

### Font Stack

```css
:root {
  /* ═══════════════════════════════════════════════════════════════════
     TYPOGRAPHY - Monospace throughout
     ═══════════════════════════════════════════════════════════════════ */

  --font-mono: 'IBM Plex Mono', 'JetBrains Mono', 'Fira Code', 'Consolas', monospace;
}
```

**Why IBM Plex Mono?**
- Excellent readability at small sizes
- Clear distinction between similar characters (0/O, 1/l/I)
- Supports box-drawing characters
- Free and open source
- Modern aesthetic that fits the terminal vibe

### Type Scale

```css
:root {
  /* ─── FONT SIZES ─── */
  /* Dense, technical readability */
  --text-xs: 0.625rem;     /* 10px - Timestamps, minor data */
  --text-sm: 0.6875rem;    /* 11px - Labels, secondary info */
  --text-base: 0.75rem;    /* 12px - Primary text */
  --text-lg: 0.8125rem;    /* 13px - Emphasis */
  --text-xl: 0.875rem;     /* 14px - Section titles */
  --text-2xl: 1.25rem;     /* 20px - Major numbers */
  --text-3xl: 1.75rem;     /* 28px - Hero stats */
  --text-4xl: 2.5rem;      /* 40px - Huge displays */

  /* ─── FONT WEIGHTS ─── */
  --font-thin: 300;
  --font-normal: 400;
  --font-medium: 500;
  --font-bold: 600;

  /* ─── LINE HEIGHTS ─── */
  --leading-none: 1;
  --leading-tight: 1.2;
  --leading-normal: 1.4;
  --leading-relaxed: 1.6;

  /* ─── LETTER SPACING ─── */
  --tracking-tight: -0.02em;
  --tracking-normal: 0;
  --tracking-wide: 0.08em;
  --tracking-wider: 0.12em;
  --tracking-widest: 0.2em;
}
```

### Type Application Guide

```
╔══════════════════════════════════════════════════════════════════════╗
║                    TYPOGRAPHY USAGE                                   ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  ELEMENT              SIZE       WEIGHT    SPACING    TRANSFORM      ║
║  ─────────────────────────────────────────────────────────────────── ║
║  Game title           text-xl    bold      wider      UPPERCASE      ║
║  Section headers      text-lg    medium    wide       UPPERCASE      ║
║  Primary data         text-2xl   bold      tight      -              ║
║  Secondary data       text-base  normal    normal     -              ║
║  Labels               text-sm    medium    wider      UPPERCASE      ║
║  Timestamps           text-xs    normal    wide       -              ║
║  Buttons              text-sm    medium    wider      UPPERCASE      ║
║  Hotkeys              text-xs    normal    normal     -              ║
║  Feed messages        text-base  normal    normal     -              ║
║  Hero numbers         text-4xl   bold      tight      -              ║
║  Multipliers          text-3xl   bold      tight      -              ║
║                                                                       ║
╚══════════════════════════════════════════════════════════════════════╝
```

### ASCII Art Standards

```
╔══════════════════════════════════════════════════════════════════════╗
║                    ASCII ART GUIDELINES                               ║
╠══════════════════════════════════════════════════════════════════════╣

1. LOGO BANNERS - Use block characters for impact:

    ██╗  ██╗ █████╗ ███████╗██╗  ██╗     ██████╗██████╗  █████╗ ███████╗██╗  ██╗
    ██║  ██║██╔══██╗██╔════╝██║  ██║    ██╔════╝██╔══██╗██╔══██╗██╔════╝██║  ██║
    ███████║███████║███████╗███████║    ██║     ██████╔╝███████║███████╗███████║
    ██╔══██║██╔══██║╚════██║██╔══██║    ██║     ██╔══██╗██╔══██║╚════██║██╔══██║
    ██║  ██║██║  ██║███████║██║  ██║    ╚██████╗██║  ██║██║  ██║███████║██║  ██║
    ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝     ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝

2. STATUS INDICATORS - Use progress blocks:

   HEALTH: ████████████░░░░░░░░ 60%
   TIMER:  ████████████████████ 100%
   EMPTY:  ░░░░░░░░░░░░░░░░░░░░ 0%

3. ICONS - Keep simple, max 3 chars:

   Win:    [+]  ✓  +$
   Loss:   [X]  ✗  -$
   Death:  [!]  💀 ☠
   Fire:   🔥  >>>
   Gold:   [$]  ★
   Lock:   [#]  🔒

4. SEPARATORS - Horizontal rules:

   Light:  ─────────────────────────
   Heavy:  ═════════════════════════
   Dashed: - - - - - - - - - - - - -
   Dots:   ································

╚══════════════════════════════════════════════════════════════════════╝
```

---

## Terminal Aesthetic

### Box Drawing Characters

```css
:root {
  /* ═══════════════════════════════════════════════════════════════════
     ASCII BOX CHARACTERS
     ═══════════════════════════════════════════════════════════════════ */

  /* ─── SINGLE LINE BOX ─── */
  --box-top-left: '\250C';        /* ┌ */
  --box-top-right: '\2510';       /* ┐ */
  --box-bottom-left: '\2514';     /* └ */
  --box-bottom-right: '\2518';    /* ┘ */
  --box-horizontal: '\2500';      /* ─ */
  --box-vertical: '\2502';        /* │ */
  --box-t-down: '\252C';          /* ┬ */
  --box-t-up: '\2534';            /* ┴ */
  --box-t-right: '\251C';         /* ├ */
  --box-t-left: '\2524';          /* ┤ */
  --box-cross: '\253C';           /* ┼ */

  /* ─── DOUBLE LINE BOX ─── */
  --box-double-top-left: '\2554';       /* ╔ */
  --box-double-top-right: '\2557';      /* ╗ */
  --box-double-bottom-left: '\255A';    /* ╚ */
  --box-double-bottom-right: '\255D';   /* ╝ */
  --box-double-horizontal: '\2550';     /* ═ */
  --box-double-vertical: '\2551';       /* ║ */

  /* ─── ROUNDED BOX ─── */
  --box-round-top-left: '\256D';        /* ╭ */
  --box-round-top-right: '\256E';       /* ╮ */
  --box-round-bottom-left: '\2570';     /* ╰ */
  --box-round-bottom-right: '\256F';    /* ╯ */

  /* ─── PROGRESS BAR ─── */
  --progress-filled: '\2588';     /* █ */
  --progress-empty: '\2591';      /* ░ */
  --progress-half: '\2593';       /* ▓ */
  --progress-quarter: '\2592';    /* ▒ */
}
```

### Box Styles Reference

```
SINGLE LINE - Default panels, standard containers
┌─────────────────────────────────────┐
│  Content goes here                  │
│                                     │
└─────────────────────────────────────┘

DOUBLE LINE - Important panels, modals, headers
╔═════════════════════════════════════╗
║  CRITICAL CONTENT                   ║
║                                     ║
╚═════════════════════════════════════╝

ROUNDED - Softer panels (use sparingly)
╭─────────────────────────────────────╮
│  Gentler content                    │
│                                     │
╰─────────────────────────────────────╯

WITH TITLE - Labeled sections
┌─[ SECTION TITLE ]───────────────────┐
│  Section content                    │
│                                     │
└─────────────────────────────────────┘

NESTED BOXES - Complex layouts
╔═════════════════════════════════════╗
║  OUTER BOX                          ║
║  ┌───────────────────────────────┐  ║
║  │  Inner content                │  ║
║  └───────────────────────────────┘  ║
╚═════════════════════════════════════╝
```

### CRT Effects

```css
/* ═══════════════════════════════════════════════════════════════════
   CRT EFFECTS - Use sparingly for authenticity
   ═══════════════════════════════════════════════════════════════════ */

/* SCANLINES - Subtle horizontal lines */
.scanlines {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  pointer-events: none;
  z-index: var(--z-effects);
  background: repeating-linear-gradient(
    0deg,
    transparent,
    transparent 2px,
    rgba(0, 229, 204, 0.015) 3px,
    rgba(0, 229, 204, 0.015) 4px
  );
}

/* FLICKER - Random opacity variations */
@keyframes flicker {
  0%, 100% { opacity: 1; }
  92% { opacity: 1; }
  93% { opacity: 0.85; }
  94% { opacity: 1; }
  95% { opacity: 0.9; }
  96% { opacity: 1; }
}

.flicker {
  animation: flicker 8s infinite;
}

/* GLOW - Text shadow for phosphor effect */
.glow {
  text-shadow:
    0 0 4px var(--color-accent-glow),
    0 0 8px var(--color-accent-glow);
}

.glow-strong {
  text-shadow:
    0 0 8px var(--color-accent-glow),
    0 0 16px var(--color-accent-glow),
    0 0 32px var(--color-accent-glow);
}

/* SCREEN FLASH - Event feedback */
@keyframes screen-flash-danger {
  0% { background-color: transparent; }
  10% { background-color: var(--color-danger-glow); }
  20% { background-color: transparent; }
  30% { background-color: var(--color-danger-glow); }
  40% { background-color: transparent; }
  100% { background-color: transparent; }
}

@keyframes screen-flash-success {
  0% { background-color: transparent; }
  50% { background-color: var(--color-profit-glow); }
  100% { background-color: transparent; }
}

/* CRT VIGNETTE - Darkened edges */
.vignette {
  box-shadow: inset 0 0 100px rgba(0, 0, 0, 0.5);
}
```

### Effect Usage Guidelines

```
╔══════════════════════════════════════════════════════════════════════╗
║                    CRT EFFECT USAGE                                   ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  EFFECT            WHEN TO USE                    INTENSITY          ║
║  ─────────────────────────────────────────────────────────────────── ║
║  Scanlines         Always on (global)             3% opacity          ║
║  Flicker           Main app shell only            Subtle (90-100%)   ║
║  Glow              Important data, active state   Per-element        ║
║  Screen Flash      Critical events (death, win)   Brief (0.5s)       ║
║  Vignette          Full-screen game modes         Subtle             ║
║                                                                       ║
║  NEVER:                                                               ║
║  - Stack multiple effects on same element                            ║
║  - Use strong flicker during gameplay (distracting)                  ║
║  - Apply glow to body text (hard to read)                            ║
║                                                                       ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## Component Patterns

### Buttons

```svelte
<!-- Component: apps/web/src/lib/ui/primitives/Button.svelte -->

<!-- VARIANTS -->

<!-- PRIMARY - Main action -->
<Button variant="primary">JACK IN</Button>
<!--
  bg: accent
  color: bg-void
  border: accent
  hover: transparent bg, accent text, glow
-->

<!-- SECONDARY - Alternative action -->
<Button variant="secondary">CANCEL</Button>
<!--
  bg: transparent
  color: text-primary
  border: border-strong
  hover: border accent, accent text, glow
-->

<!-- DANGER - Destructive action -->
<Button variant="danger">EXTRACT ALL</Button>
<!--
  bg: transparent
  color: danger
  border: danger-dim
  hover: danger bg, void text, glow
-->

<!-- GHOST - Minimal action -->
<Button variant="ghost">SETTINGS</Button>
<!--
  bg: transparent
  color: text-secondary
  border: none
  hover: bg-tertiary, text-primary
-->
```

**Button CSS Reference:**

```css
/* Button base styles */
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-2);
  font-family: var(--font-mono);
  font-weight: var(--font-medium);
  letter-spacing: var(--tracking-wider);
  text-transform: uppercase;
  border: var(--border-width) solid transparent;
  cursor: pointer;
  transition: all var(--duration-fast) var(--ease-default);
}

/* Size variants */
.btn-sm { padding: var(--space-1) var(--space-2); font-size: var(--text-xs); }
.btn-md { padding: var(--space-2) var(--space-4); font-size: var(--text-sm); }
.btn-lg { padding: var(--space-3) var(--space-6); font-size: var(--text-base); }

/* Disabled state */
.btn:disabled {
  cursor: not-allowed;
  opacity: 0.4;
}
```

### Input Fields

```
╔══════════════════════════════════════════════════════════════════════╗
║  INPUT FIELD ANATOMY                                                  ║
╠══════════════════════════════════════════════════════════════════════╣

  LABEL                    [optional] HINT TEXT
  ┌────────────────────────────────────────────┐
  │ Placeholder text...                      │ ← SUFFIX
  └────────────────────────────────────────────┘
  [optional] ERROR MESSAGE

╚══════════════════════════════════════════════════════════════════════╝
```

```css
/* Input field styles */
.input {
  width: 100%;
  padding: var(--space-2) var(--space-3);
  font-family: var(--font-mono);
  font-size: var(--text-base);
  color: var(--color-text-primary);
  background: var(--color-bg-tertiary);
  border: var(--border-width) solid var(--color-border-default);
  transition: all var(--duration-fast) var(--ease-default);
}

.input:focus {
  outline: none;
  border-color: var(--color-accent);
  box-shadow: var(--shadow-glow-accent);
}

.input:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.input-error {
  border-color: var(--color-danger);
}

.input-error:focus {
  box-shadow: var(--shadow-glow-red);
}

/* Labels */
.input-label {
  display: block;
  margin-bottom: var(--space-1);
  font-size: var(--text-sm);
  font-weight: var(--font-medium);
  letter-spacing: var(--tracking-wider);
  text-transform: uppercase;
  color: var(--color-text-secondary);
}

/* Error message */
.input-error-message {
  margin-top: var(--space-1);
  font-size: var(--text-xs);
  color: var(--color-danger);
}
```

### Modals / Panels

```
╔══════════════════════════════════════════════════════════════════════╗
║  MODAL ANATOMY                                                        ║
╠══════════════════════════════════════════════════════════════════════╣

  ╔═════════════════════════════════════════════════════════╗
  ║─[ MODAL TITLE ]─────────────────────────────────────────║
  ╠═════════════════════════════════════════════════════════╣
  ║                                                         ║
  ║  Modal content goes here.                               ║
  ║                                                         ║
  ║  - Uses double-line box for importance                  ║
  ║  - Bright border color with glow                        ║
  ║  - Backdrop blur effect                                 ║
  ║                                                         ║
  ╠═════════════════════════════════════════════════════════╣
  ║          [ SECONDARY ]        [ PRIMARY ACTION ]        ║
  ╚═════════════════════════════════════════════════════════╝

╚══════════════════════════════════════════════════════════════════════╝
```

```css
/* Modal styles */
.modal {
  position: fixed;
  padding: 0;
  border: none;
  background: transparent;
  max-height: 90vh;
  max-width: 90vw;
}

.modal::backdrop {
  background: rgba(3, 3, 5, 0.92);
  backdrop-filter: blur(8px);
}

/* Size variants */
.modal-sm { width: 320px; }
.modal-md { width: 480px; }
.modal-lg { width: 640px; }

/* Animation */
@keyframes modal-enter {
  from {
    opacity: 0;
    transform: scale(0.98) translateY(-8px);
  }
  to {
    opacity: 1;
    transform: scale(1) translateY(0);
  }
}

.modal-container {
  animation: modal-enter 0.2s ease-out;
}
```

### Progress Indicators

```
╔══════════════════════════════════════════════════════════════════════╗
║  PROGRESS BAR VARIANTS                                                ║
╠══════════════════════════════════════════════════════════════════════╣

  DEFAULT (accent):
  PROGRESS ████████████████░░░░░░░░░░░░ 57%

  DANGER:
  HEALTH   ████░░░░░░░░░░░░░░░░░░░░░░░░ 15%

  WARNING:
  TIME     ████████████████████░░░░░░░░ 72%

  SUCCESS:
  SCORE    ████████████████████████████ 100%

  ANIMATED (glow pulse when active):
  LOADING  ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░ ...

╚══════════════════════════════════════════════════════════════════════╝
```

```css
/* Progress bar styles */
.progress {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  font-family: var(--font-mono);
  font-size: var(--text-sm);
}

.progress-bar {
  white-space: pre;
  letter-spacing: -0.05em;
}

.progress-filled { color: var(--color-accent); }
.progress-empty {
  color: var(--color-border-strong);
  opacity: 0.5;
}

/* Variant colors */
.progress-danger .progress-filled { color: var(--color-danger); }
.progress-warning .progress-filled { color: var(--color-warning); }
.progress-success .progress-filled { color: var(--color-profit); }

/* Animated glow */
.progress-animated .progress-filled {
  animation: glow-pulse 2s ease-in-out infinite;
}
```

### Badges / Tags

```
╔══════════════════════════════════════════════════════════════════════╗
║  BADGE VARIANTS                                                       ║
╠══════════════════════════════════════════════════════════════════════╣

  DEFAULT:    ┌─────────┐
              │ DEFAULT │
              └─────────┘

  SUCCESS:    ┌─────────┐
              │ SUCCESS │  (accent border + bg tint)
              └─────────┘

  WARNING:    ┌─────────┐
              │ WARNING │  (amber border + bg tint)
              └─────────┘

  DANGER:     ┌─────────┐
              │ DANGER  │  (red border + bg tint)
              └─────────┘

  INFO:       ┌─────────┐
              │  INFO   │  (cyan border + bg tint)
              └─────────┘

  HOTKEY:     ┌───┐
              │[E]│  (muted, for keyboard hints)
              └───┘

  WITH GLOW:  ┏━━━━━━━━━┓
              ┃ ACTIVE! ┃  (glowing border effect)
              ┗━━━━━━━━━┛

  PULSING:    [ LIVE ]    (opacity animation)

╚══════════════════════════════════════════════════════════════════════╝
```

```css
/* Badge base */
.badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-0-5) var(--space-2);
  font-family: var(--font-mono);
  font-size: var(--text-xs);
  font-weight: var(--font-medium);
  letter-spacing: var(--tracking-wider);
  text-transform: uppercase;
  border: var(--border-width) solid currentColor;
  background: transparent;
}

/* Compact variant */
.badge-compact {
  padding: 0 var(--space-1);
  font-size: 0.5625rem;
}

/* Color variants */
.badge-success {
  color: var(--color-accent);
  border-color: var(--color-accent-dim);
  background: rgba(0, 229, 204, 0.08);
}

.badge-warning {
  color: var(--color-warning);
  border-color: var(--color-warning-dim);
  background: rgba(255, 176, 0, 0.08);
}

.badge-danger {
  color: var(--color-danger);
  border-color: var(--color-danger-dim);
  background: rgba(255, 51, 102, 0.08);
}

/* Glow modifier */
.badge-glow.badge-success { box-shadow: var(--shadow-glow-accent); }
.badge-glow.badge-warning { box-shadow: var(--shadow-glow-amber); }
.badge-glow.badge-danger { box-shadow: var(--shadow-glow-red); }

/* Pulse animation */
.badge-pulse {
  animation: badge-pulse 2s ease-in-out infinite;
}
```

---

## Game-Specific Styles

### State Colors

```css
/* ═══════════════════════════════════════════════════════════════════
   GAME STATE COLORS - Consistent across all games
   ═══════════════════════════════════════════════════════════════════ */

:root {
  /* WINNING STATE - Player is ahead */
  --state-winning-text: var(--color-profit);
  --state-winning-bg: rgba(0, 255, 136, 0.1);
  --state-winning-border: var(--color-profit-dim);
  --state-winning-glow: var(--shadow-glow-profit);

  /* LOSING STATE - Player is behind */
  --state-losing-text: var(--color-danger);
  --state-losing-bg: rgba(255, 51, 102, 0.1);
  --state-losing-border: var(--color-danger-dim);
  --state-losing-glow: var(--shadow-glow-red);

  /* NEUTRAL STATE - No clear advantage */
  --state-neutral-text: var(--color-text-secondary);
  --state-neutral-bg: transparent;
  --state-neutral-border: var(--color-border-default);

  /* ACTIVE STATE - Game in progress */
  --state-active-text: var(--color-accent);
  --state-active-bg: rgba(0, 229, 204, 0.1);
  --state-active-border: var(--color-accent-dim);
  --state-active-glow: var(--shadow-glow-accent);

  /* WAITING STATE - Pending action */
  --state-waiting-text: var(--color-warning);
  --state-waiting-bg: rgba(255, 176, 0, 0.1);
  --state-waiting-border: var(--color-warning-dim);
}
```

### Animation Triggers

```css
/* ═══════════════════════════════════════════════════════════════════
   ANIMATION TRIGGERS - Event-driven animations
   ═══════════════════════════════════════════════════════════════════ */

/* TRIGGER: Player wins / positive event */
.animate-win {
  animation: win-celebration 0.5s ease-out;
}

@keyframes win-celebration {
  0% { transform: scale(1); }
  30% { transform: scale(1.05); }
  50% {
    transform: scale(1.1);
    text-shadow: 0 0 20px var(--color-profit-glow);
  }
  100% { transform: scale(1); }
}

/* TRIGGER: Player loses / negative event */
.animate-loss {
  animation: loss-shake 0.3s ease-out;
}

@keyframes loss-shake {
  0%, 100% { transform: translateX(0); }
  20% { transform: translateX(-4px); }
  40% { transform: translateX(4px); }
  60% { transform: translateX(-2px); }
  80% { transform: translateX(2px); }
}

/* TRIGGER: Multiplier increase */
.animate-multiplier-tick {
  animation: mult-tick 0.1s ease-out;
}

@keyframes mult-tick {
  0% { transform: scale(1); }
  50% { transform: scale(1.02); }
  100% { transform: scale(1); }
}

/* TRIGGER: Cash out success */
.animate-cashout {
  animation: cashout-flash 0.3s ease-out;
}

@keyframes cashout-flash {
  0% { background-color: transparent; }
  50% { background-color: var(--color-profit-glow); }
  100% { background-color: transparent; }
}

/* TRIGGER: Death / Game over */
.animate-death {
  animation: death-flash 0.5s ease-out, death-shake 0.3s ease-out;
}

/* TRIGGER: Countdown urgent (< 10 seconds) */
.animate-countdown-urgent {
  animation: countdown-pulse 1s ease-in-out infinite;
}

@keyframes countdown-pulse {
  0%, 100% {
    color: var(--color-danger);
    text-shadow: 0 0 5px var(--color-danger-glow);
  }
  50% {
    color: var(--color-warning);
    text-shadow: 0 0 15px var(--color-danger-glow);
  }
}

/* TRIGGER: Jackpot / Extreme win */
.animate-jackpot {
  animation: jackpot 0.5s ease-out 3;
}

@keyframes jackpot {
  0% {
    transform: scale(1);
    text-shadow: 0 0 5px var(--color-gold);
  }
  50% {
    transform: scale(1.1);
    text-shadow: 0 0 30px var(--color-gold), 0 0 60px var(--color-gold);
  }
  100% {
    transform: scale(1);
    text-shadow: 0 0 5px var(--color-gold);
  }
}

/* TRIGGER: New feed item */
.animate-feed-item {
  animation: feed-enter 0.3s ease-out;
}

@keyframes feed-enter {
  0% {
    opacity: 0;
    transform: translateY(-10px);
    max-height: 0;
  }
  100% {
    opacity: 1;
    transform: translateY(0);
    max-height: 100px;
  }
}
```

### Per-Game Visual Mockups

**HASH CRASH - Rising Multiplier**

```
╔══════════════════════════════════════════════════════════════════════╗
║  HASH CRASH                                    ROUND #4,847          ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║                            23.47x                                     ║
║                     [text-3xl, color: crash-extreme, glow-strong]    ║
║                                                                       ║
║                          ▄▄████                                       ║
║                        ▄███████                                       ║
║                      ▄█████████                                       ║
║                    ▄███████████                                       ║
║                  ▄█████████████                                       ║
║                ▄███████████████                                       ║
║              ▄█████████████████                                       ║
║            ▄███████████████████                                       ║
║  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀  ║
║                                                                       ║
║  YOUR BET         POTENTIAL PAYOUT          ACTION                   ║
║  100 $DATA        2,347 $DATA               [ CASH OUT ]             ║
║                                                                       ║
║  ─────────────────────────────────────────────────────────────────── ║
║  RECENT: 1.23x │ 4.56x │ 12.34x │ 1.01x │ 89.12x                     ║
╚══════════════════════════════════════════════════════════════════════╝
```

**ICE BREAKER - Weak Point Hit**

```
╔══════════════════════════════════════════════════════════════════════╗
║  ICE BREAKER          Layer 7/12              TIME: 00:23.47         ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  ┌────────────────────────────────────────────────────────────────┐  ║
║  │                        PATROL ICE                               │  ║
║  │                                                                 │  ║
║  │       ┌─────┐                                                   │  ║
║  │       │     │                                                   │  ║
║  │       │  ●──┼──→  [color: ice-patrol, animate]                 │  ║
║  │       │     │                                                   │  ║
║  │       └─────┘                                                   │  ║
║  │                                                                 │  ║
║  │                        ╭─────╮                                  │  ║
║  │                        │ HIT!│  [animate-win, scale 1.5x]      │  ║
║  │                        ╰─────╯                                  │  ║
║  │                                                                 │  ║
║  └────────────────────────────────────────────────────────────────┘  ║
║                                                                       ║
║  HEALTH: ████████████████████░░░░░░░░░░ 72/100                       ║
║  SCORE: 4,280        PERFECT: 12        AVG: 0.34s                   ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## Responsive Design

### Breakpoints

```css
:root {
  /* ═══════════════════════════════════════════════════════════════════
     BREAKPOINTS - Mobile-first approach
     ═══════════════════════════════════════════════════════════════════ */

  --breakpoint-sm: 640px;    /* Mobile landscape */
  --breakpoint-md: 768px;    /* Tablet portrait */
  --breakpoint-lg: 1024px;   /* Tablet landscape / small desktop */
  --breakpoint-xl: 1280px;   /* Desktop */
  --breakpoint-2xl: 1536px;  /* Large desktop */

  /* Touch target minimum (WCAG 2.2 AA) */
  --touch-target-min: 44px;
}
```

### Responsive Spacing

```css
:root {
  /* Base values - mobile first */
  --responsive-padding: var(--space-3);   /* 12px */
  --responsive-gap: var(--space-2);       /* 8px */
}

@media (min-width: 640px) {
  :root {
    --responsive-padding: var(--space-4); /* 16px */
    --responsive-gap: var(--space-3);     /* 12px */
  }
}

@media (min-width: 768px) {
  :root {
    --responsive-padding: var(--space-5); /* 20px */
    --responsive-gap: var(--space-4);     /* 16px */
  }
}

@media (min-width: 1024px) {
  :root {
    --responsive-padding: var(--space-6); /* 24px */
    --responsive-gap: var(--space-4);     /* 16px */
  }
}

@media (min-width: 1280px) {
  :root {
    --responsive-padding: var(--space-8); /* 32px */
    --responsive-gap: var(--space-5);     /* 20px */
  }
}
```

### Touch Targets

```css
/* ═══════════════════════════════════════════════════════════════════
   TOUCH TARGETS - Accessible tap/click areas
   ═══════════════════════════════════════════════════════════════════ */

.touch-target {
  /* Ensures minimum 44x44px touch area */
  position: relative;
  min-height: var(--touch-target-min);
  min-width: var(--touch-target-min);
}

/* Invisible expanded hit area */
.touch-target::before {
  content: '';
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  min-width: var(--touch-target-min);
  min-height: var(--touch-target-min);
  width: 100%;
  height: 100%;
}

/* Inline touch target */
.touch-target-inline {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: var(--touch-target-min);
  min-width: var(--touch-target-min);
  padding: var(--space-2);
}
```

### Compact Game Layouts

```
╔══════════════════════════════════════════════════════════════════════╗
║  RESPONSIVE LAYOUT STRATEGY                                           ║
╠══════════════════════════════════════════════════════════════════════╣

  MOBILE (<640px):
  ┌────────────────────┐
  │  GAME HEADER       │  (sticky)
  ├────────────────────┤
  │                    │
  │  GAME AREA         │  (full width)
  │  (touch-optimized) │
  │                    │
  ├────────────────────┤
  │  KEY STATS         │  (horizontal scroll if needed)
  ├────────────────────┤
  │  ACTION BUTTON     │  (sticky bottom)
  └────────────────────┘

  TABLET (768px-1024px):
  ┌─────────────┬──────────────┐
  │  GAME AREA  │  STATS       │
  │             │  SIDEBAR     │
  │             │              │
  ├─────────────┴──────────────┤
  │  FEED / PLAYERS            │
  └────────────────────────────┘

  DESKTOP (>1024px):
  ┌────────────┬───────────────┬──────────┐
  │  SIDEBAR   │  GAME AREA    │  STATS   │
  │            │               │  PANEL   │
  │  - Feed    │               │          │
  │  - Players │               │  - Bet   │
  │            │               │  - Timer │
  └────────────┴───────────────┴──────────┘

╚══════════════════════════════════════════════════════════════════════╝
```

### Mobile-Specific Adaptations

```css
/* ═══════════════════════════════════════════════════════════════════
   MOBILE ADAPTATIONS
   ═══════════════════════════════════════════════════════════════════ */

@media (max-width: 639.98px) {
  /* Increase text sizes for readability */
  :root {
    --text-base: 0.8125rem;  /* 13px instead of 12px */
    --text-sm: 0.75rem;      /* 12px instead of 11px */
  }

  /* Increase button padding for touch */
  .btn-md {
    padding: var(--space-3) var(--space-4);
    min-height: var(--touch-target-min);
  }

  /* Hide decorative elements */
  .hide-mobile {
    display: none !important;
  }

  /* Simplify box borders */
  .box {
    /* Use simpler border style on mobile */
    border: 1px solid var(--color-border-default);
  }

  /* Full-width buttons */
  .btn-mobile-full {
    width: 100%;
  }

  /* Sticky action bar */
  .action-bar-sticky {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    padding: var(--space-3);
    background: var(--color-bg-secondary);
    border-top: 1px solid var(--color-border-default);
    z-index: var(--z-sticky);
  }
}
```

---

## Accessibility

### Contrast Requirements

```
╔══════════════════════════════════════════════════════════════════════╗
║  CONTRAST RATIOS (WCAG 2.1 AA minimum: 4.5:1 for text)               ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  COLOR COMBINATION              RATIO    PASS/FAIL                   ║
║  ─────────────────────────────────────────────────────────────────── ║
║  text-primary (#fff) on bg-primary (#050507)    19.2:1    PASS      ║
║  text-secondary (#a0a0b0) on bg-primary         7.8:1     PASS      ║
║  text-tertiary (#606070) on bg-primary          4.1:1     FAIL*     ║
║  accent (#00e5cc) on bg-primary                 8.9:1     PASS      ║
║  danger (#ff3366) on bg-primary                 5.4:1     PASS      ║
║  warning (#ffb000) on bg-primary                8.7:1     PASS      ║
║                                                                       ║
║  * text-tertiary is intentionally low-contrast for de-emphasized     ║
║    content. Never use for critical information.                      ║
║                                                                       ║
╚══════════════════════════════════════════════════════════════════════╝
```

### Focus States

```css
/* ═══════════════════════════════════════════════════════════════════
   FOCUS STATES - Visible, consistent, accessible
   ═══════════════════════════════════════════════════════════════════ */

/* Global focus-visible style */
:focus-visible {
  outline: 2px solid var(--color-accent);
  outline-offset: 2px;
}

/* Remove outline for mouse users */
:focus:not(:focus-visible) {
  outline: none;
}

/* Custom focus for specific elements */
.btn:focus-visible {
  outline: 2px solid var(--color-accent);
  outline-offset: 2px;
  box-shadow: var(--shadow-glow-accent);
}

.input:focus-visible {
  outline: none; /* Using border instead */
  border-color: var(--color-accent);
  box-shadow: var(--shadow-glow-accent);
}

/* Skip link for keyboard users */
.skip-link {
  position: absolute;
  top: -40px;
  left: 0;
  padding: var(--space-2) var(--space-4);
  background: var(--color-accent);
  color: var(--color-bg-void);
  z-index: var(--z-tooltip);
  transition: top var(--duration-fast);
}

.skip-link:focus {
  top: 0;
}
```

### Motion Reduction

```css
/* ═══════════════════════════════════════════════════════════════════
   REDUCED MOTION - Respect user preferences
   ═══════════════════════════════════════════════════════════════════ */

@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }

  /* Disable specific animations */
  .flicker,
  .scanlines,
  .animate-glow-pulse,
  .animate-pulse {
    animation: none !important;
  }

  /* Keep critical feedback visible but instant */
  .animate-win,
  .animate-loss,
  .animate-cashout {
    animation: none !important;
    /* Use instant visual change instead */
  }
}
```

### Screen Reader Considerations

```svelte
<!-- ARIA labels for game states -->
<div
  role="status"
  aria-live="polite"
  aria-label="Current multiplier: {multiplier}x"
>
  {multiplier}x
</div>

<!-- Progress bar accessibility -->
<div
  class="progress"
  role="progressbar"
  aria-valuenow={value}
  aria-valuemin={0}
  aria-valuemax={100}
  aria-label={label}
>
  <!-- Visual representation -->
</div>

<!-- Game results announcement -->
<div
  role="alert"
  aria-live="assertive"
  class="sr-only"
>
  {#if gameOver}
    Game over. You {won ? 'won' : 'lost'} {amount} $DATA.
  {/if}
</div>

<!-- Screen reader only text -->
<style>
  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border-width: 0;
  }
</style>
```

---

## Quick Reference

### Design Token Checklist

```
When building a new game UI, ensure you use:

COLORS
[ ] Background: bg-secondary or bg-tertiary
[ ] Primary text: text-primary
[ ] Labels: text-secondary + uppercase + tracking-wider
[ ] Active elements: accent color
[ ] Borders: border-default or border-subtle

TYPOGRAPHY
[ ] Font: font-mono (always)
[ ] Data values: text-2xl or text-3xl, font-bold
[ ] Labels: text-sm, font-medium, uppercase
[ ] Buttons: text-sm, font-medium, uppercase, tracking-wider

SPACING
[ ] Use responsive-padding for containers
[ ] Use responsive-gap for flex/grid gaps
[ ] Min 8px (space-2) between related elements
[ ] Min 16px (space-4) between sections

COMPONENTS
[ ] Buttons use Button.svelte variants
[ ] Panels use Box.svelte with appropriate variant
[ ] Progress uses ProgressBar.svelte
[ ] Badges use Badge.svelte
[ ] Modals use Modal.svelte

EFFECTS
[ ] Glow only on active/important elements
[ ] Screen flash only on critical events
[ ] Animations have reduced-motion fallbacks

ACCESSIBILITY
[ ] All interactive elements are keyboard accessible
[ ] Focus states are visible
[ ] Contrast ratios meet WCAG AA
[ ] ARIA labels on dynamic content
```

### File Locations

```
apps/web/src/lib/ui/
├── styles/
│   ├── tokens.css          # Design tokens (colors, typography, etc.)
│   ├── animations.css      # Keyframe animations
│   ├── reset.css           # CSS reset
│   ├── utilities.css       # Utility classes
│   └── responsive.css      # Breakpoints, containers
├── primitives/
│   ├── Button.svelte       # Button component
│   ├── Badge.svelte        # Badge component
│   ├── ProgressBar.svelte  # Progress bar component
│   └── ...
├── terminal/
│   ├── Box.svelte          # Terminal box component
│   ├── Scanlines.svelte    # CRT scanlines overlay
│   ├── Flicker.svelte      # Flicker effect
│   └── ScreenFlash.svelte  # Screen flash effect
└── modal/
    └── Modal.svelte        # Modal dialog component
```

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-21 | Initial visual system documentation |

---

*"The terminal is your interface. The void is your canvas. Make every pixel count."*
