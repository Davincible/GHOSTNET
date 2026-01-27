# Animation Specifications for GHOSTNET Arcade

**Document Type:** Design Specification  
**Last Updated:** January 2026  
**Applies To:** All Phase 3 Mini-Games  

---

## Table of Contents

1. [Animation Philosophy](#animation-philosophy)
2. [Timing Guidelines](#timing-guidelines)
3. [Core Animations](#core-animations)
4. [Game-Specific Animations](#game-specific-animations)
5. [State Transitions](#state-transitions)
6. [Performance](#performance)
7. [Svelte Transitions](#svelte-transitions)

---

## Animation Philosophy

### Purpose Over Decoration

Every animation in GHOSTNET must serve one of these purposes:

1. **Feedback** - Confirm user actions (click, type, success, failure)
2. **Guidance** - Direct attention to important elements
3. **Continuity** - Maintain spatial awareness during state changes
4. **Atmosphere** - Reinforce the terminal/hacker aesthetic (used sparingly)

```
GOOD:                                   BAD:
+----------------------------------+    +----------------------------------+
|                                  |    |                                  |
|  Button flash on click           |    |  Decorative particle effects     |
|  Fade in for new content         |    |  Bouncing idle animations        |
|  Shake on error                  |    |  Spinning loaders everywhere     |
|  Glow pulse for warnings         |    |  Gratuitous screen transitions   |
|                                  |    |                                  |
+----------------------------------+    +----------------------------------+
```

### The Terminal Aesthetic

GHOSTNET animations should feel like:
- CRT monitor glitches
- Command line operations
- Data streams and transmissions
- System malfunction warnings

They should NOT feel like:
- Modern app micro-interactions
- Playful bounces or springs
- Smooth gradients or morphs
- Material Design ripples

### Animation Budget

Each screen should have a limited animation budget:

| Animation Type | Max Concurrent |
|----------------|----------------|
| Continuous loops (glow, pulse) | 2 |
| On-demand feedback | Unlimited |
| Attention-grabbing | 1 |
| Atmospheric (scanlines, flicker) | 1 |

---

## Timing Guidelines

### Duration Standards

```css
:root {
  --duration-instant: 50ms;   /* Micro-feedback, no perceived delay */
  --duration-fast: 100ms;     /* Button feedback, small state changes */
  --duration-normal: 200ms;   /* Standard transitions, modal enter */
  --duration-slow: 400ms;     /* Complex transitions, page changes */
  --duration-slower: 600ms;   /* Dramatic reveals, victory screens */
}
```

### When to Use Each Duration

| Duration | Use Cases |
|----------|-----------|
| `instant` (50ms) | Hover states, active states, micro-feedback |
| `fast` (100ms) | Button clicks, toggles, small reveals |
| `normal` (200ms) | Modal open/close, panel slides, fades |
| `slow` (400ms) | Page transitions, large component mounts |
| `slower` (600ms) | Victory/defeat screens, dramatic reveals |

### Easing Functions

```css
:root {
  /* Standard easing - use for most animations */
  --ease-default: cubic-bezier(0.4, 0, 0.2, 1);
  
  /* Enter animations - elements appearing */
  --ease-out: cubic-bezier(0, 0, 0.2, 1);
  
  /* Exit animations - elements leaving */
  --ease-in: cubic-bezier(0.4, 0, 1, 1);
  
  /* Terminal-style - sharp, mechanical */
  --ease-terminal: steps(4, end);
  
  /* Glitch - unpredictable */
  --ease-glitch: cubic-bezier(0.68, -0.55, 0.265, 1.55);
}
```

### Terminal-Appropriate Easings

For GHOSTNET, prefer stepped or linear easings over smooth curves:

```
SMOOTH (avoid for terminal UI):    STEPPED (prefer for terminal UI):
                                   
    ___________                        ___________
   /                                  |
  /                                   |____
 /                                    |
/___________                    ______|___________
```

---

## Core Animations

### Text Reveal (Typing Effect)

Creates the classic terminal typing effect for text that appears letter by letter.

#### CSS Implementation

```css
@keyframes typing-cursor {
  0%, 100% { 
    border-right-color: var(--color-accent);
  }
  50% { 
    border-right-color: transparent;
  }
}

@keyframes text-reveal {
  from {
    max-width: 0;
  }
  to {
    max-width: 100%;
  }
}

.typing-text {
  overflow: hidden;
  white-space: nowrap;
  border-right: 2px solid var(--color-accent);
  animation: 
    text-reveal 2s steps(40, end),
    typing-cursor 0.75s step-end infinite;
}
```

#### Svelte Component

```svelte
<!-- TypeWriter.svelte -->
<script lang="ts">
  interface Props {
    text: string;
    speed?: number; // ms per character
    delay?: number; // initial delay
  }

  let { text, speed = 50, delay = 0 }: Props = $props();

  let displayText = $state('');
  let cursorVisible = $state(true);
  let complete = $state(false);

  $effect(() => {
    let index = 0;
    let timeout: ReturnType<typeof setTimeout>;

    const startTyping = () => {
      const typeChar = () => {
        if (index < text.length) {
          displayText = text.slice(0, index + 1);
          index++;
          timeout = setTimeout(typeChar, speed);
        } else {
          complete = true;
        }
      };
      typeChar();
    };

    timeout = setTimeout(startTyping, delay);

    // Cursor blink
    const cursorInterval = setInterval(() => {
      cursorVisible = !cursorVisible;
    }, 530);

    return () => {
      clearTimeout(timeout);
      clearInterval(cursorInterval);
    };
  });
</script>

<span class="typewriter">
  {displayText}<span class="cursor" class:visible={cursorVisible}>|</span>
</span>

<style>
  .typewriter {
    font-family: var(--font-mono);
  }

  .cursor {
    opacity: 0;
    color: var(--color-accent);
  }

  .cursor.visible {
    opacity: 1;
  }

  @media (prefers-reduced-motion: reduce) {
    .cursor {
      animation: none;
      opacity: 1;
    }
  }
</style>
```

#### ASCII Mockup

```
BEFORE:                          AFTER (over 2 seconds):
+------------------------+       +------------------------+
|                        |       | > Initializing...      |
| > █                    |       | > System ready_        |
|                        |       |                        |
+------------------------+       +------------------------+
     Frame 1                          Frame 40
```

---

### Flicker (CRT Malfunction)

Simulates CRT monitor instability. Use sparingly for atmosphere.

#### CSS Implementation

```css
@keyframes flicker-subtle {
  0%, 100% { opacity: 1; }
  97% { opacity: 1; }
  97.5% { opacity: 0.95; }
  98% { opacity: 1; }
}

@keyframes flicker-normal {
  0%, 100% { opacity: 1; }
  92% { opacity: 1; }
  93% { opacity: 0.85; }
  94% { opacity: 1; }
  95% { opacity: 0.9; }
  96% { opacity: 1; }
}

@keyframes flicker-intense {
  0%, 100% { opacity: 1; }
  88% { opacity: 1; }
  89% { opacity: 0.7; }
  90% { opacity: 0.9; }
  91% { opacity: 0.75; }
  92% { opacity: 1; }
  93% { opacity: 0.85; }
  94% { opacity: 1; }
}

/* Apply to containers, not individual elements */
.flicker-subtle { animation: flicker-subtle 8s infinite; }
.flicker-normal { animation: flicker-normal 6s infinite; }
.flicker-intense { animation: flicker-intense 4s infinite; }
```

#### When to Use

| Intensity | Use Case |
|-----------|----------|
| Subtle | Background atmosphere on main shell |
| Normal | Warning states, system stress |
| Intense | Danger states, incoming attack, trace scan |

---

### Glow Pulse (Attention)

Draws attention to important elements without being disruptive.

#### CSS Implementation

```css
@keyframes glow-pulse {
  0%, 100% {
    text-shadow: 0 0 4px var(--color-accent-glow);
    box-shadow: 0 0 4px var(--color-accent-glow);
  }
  50% {
    text-shadow: 0 0 12px var(--color-accent-glow), 0 0 24px var(--color-accent-glow);
    box-shadow: 0 0 12px var(--color-accent-glow), 0 0 24px var(--color-accent-glow);
  }
}

@keyframes glow-pulse-warning {
  0%, 100% {
    text-shadow: 0 0 4px var(--color-amber-glow);
  }
  50% {
    text-shadow: 0 0 16px var(--color-amber-glow), 0 0 32px var(--color-amber-glow);
  }
}

@keyframes glow-pulse-danger {
  0%, 100% {
    text-shadow: 0 0 4px var(--color-red-glow);
  }
  50% {
    text-shadow: 0 0 16px var(--color-red-glow), 0 0 32px var(--color-red-glow);
  }
}

.glow-pulse { animation: glow-pulse 2s ease-in-out infinite; }
.glow-pulse-warning { animation: glow-pulse-warning 1.5s ease-in-out infinite; }
.glow-pulse-danger { animation: glow-pulse-danger 1s ease-in-out infinite; }
```

#### ASCII Mockup

```
FRAME 1 (dim):                   FRAME 2 (bright):
+------------------------+       +------------------------+
|                        |       |                        |
|    [ CASH OUT ]        |       |   [[ CASH OUT ]]       |
|         ^              |       |         ^              |
|    subtle glow         |       |    intense glow        |
|                        |       |                        |
+------------------------+       +------------------------+
```

---

### Glitch (Error/Damage)

Visual corruption effect for errors, damage, or malfunction states.

#### CSS Implementation

```css
@keyframes glitch {
  0% {
    clip-path: inset(40% 0 61% 0);
    transform: translate(-2px, 2px);
  }
  20% {
    clip-path: inset(92% 0 1% 0);
    transform: translate(2px, -2px);
  }
  40% {
    clip-path: inset(43% 0 1% 0);
    transform: translate(-1px, 1px);
  }
  60% {
    clip-path: inset(25% 0 58% 0);
    transform: translate(1px, -1px);
  }
  80% {
    clip-path: inset(54% 0 7% 0);
    transform: translate(-2px, 2px);
  }
  100% {
    clip-path: inset(58% 0 43% 0);
    transform: translate(2px, -2px);
  }
}

@keyframes glitch-overlay {
  0%, 100% {
    opacity: 0;
  }
  10%, 30%, 50%, 70%, 90% {
    opacity: 0.03;
    background: linear-gradient(
      transparent 0%,
      rgba(255, 0, 0, 0.1) 50%,
      transparent 100%
    );
  }
}

.glitch {
  position: relative;
}

.glitch::before,
.glitch::after {
  content: attr(data-text);
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: inherit;
}

.glitch::before {
  animation: glitch 0.3s linear infinite;
  color: var(--color-cyan);
  z-index: -1;
}

.glitch::after {
  animation: glitch 0.3s linear infinite reverse;
  color: var(--color-red);
  z-index: -2;
}
```

#### Svelte Component

```svelte
<!-- GlitchText.svelte -->
<script lang="ts">
  interface Props {
    text: string;
    active?: boolean;
    intensity?: 'low' | 'medium' | 'high';
  }

  let { text, active = false, intensity = 'medium' }: Props = $props();

  let duration = $derived(
    intensity === 'low' ? '0.5s' :
    intensity === 'medium' ? '0.3s' :
    '0.15s'
  );
</script>

<span 
  class="glitch-text" 
  class:active
  data-text={text}
  style:--glitch-duration={duration}
>
  {text}
</span>

<style>
  .glitch-text {
    position: relative;
  }

  .glitch-text.active::before,
  .glitch-text.active::after {
    content: attr(data-text);
    position: absolute;
    top: 0;
    left: 0;
    opacity: 0.8;
  }

  .glitch-text.active::before {
    animation: glitch-1 var(--glitch-duration) linear infinite;
    color: var(--color-cyan);
    clip-path: polygon(0 0, 100% 0, 100% 45%, 0 45%);
  }

  .glitch-text.active::after {
    animation: glitch-2 var(--glitch-duration) linear infinite;
    color: var(--color-red);
    clip-path: polygon(0 55%, 100% 55%, 100% 100%, 0 100%);
  }

  @keyframes glitch-1 {
    0%, 100% { transform: translate(0); }
    20% { transform: translate(-3px, 2px); }
    40% { transform: translate(3px, -2px); }
    60% { transform: translate(-2px, 1px); }
    80% { transform: translate(2px, -1px); }
  }

  @keyframes glitch-2 {
    0%, 100% { transform: translate(0); }
    20% { transform: translate(3px, -2px); }
    40% { transform: translate(-3px, 2px); }
    60% { transform: translate(2px, -1px); }
    80% { transform: translate(-2px, 1px); }
  }

  @media (prefers-reduced-motion: reduce) {
    .glitch-text.active::before,
    .glitch-text.active::after {
      animation: none;
      opacity: 0;
    }
  }
</style>
```

---

### Fade In/Out

Standard opacity transitions for content appearing and disappearing.

#### CSS Implementation

```css
@keyframes fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes fade-out {
  from { opacity: 1; }
  to { opacity: 0; }
}

@keyframes fade-in-up {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes fade-in-down {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.animate-fade-in { animation: fade-in var(--duration-normal) var(--ease-out); }
.animate-fade-out { animation: fade-out var(--duration-normal) var(--ease-in); }
.animate-fade-in-up { animation: fade-in-up var(--duration-normal) var(--ease-out); }
.animate-fade-in-down { animation: fade-in-down var(--duration-normal) var(--ease-out); }
```

---

### Slide Transitions

Directional movement for panels, drawers, and lists.

#### CSS Implementation

```css
@keyframes slide-in-left {
  from {
    opacity: 0;
    transform: translateX(-20px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

@keyframes slide-in-right {
  from {
    opacity: 0;
    transform: translateX(20px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

@keyframes slide-out-left {
  from {
    opacity: 1;
    transform: translateX(0);
  }
  to {
    opacity: 0;
    transform: translateX(-20px);
  }
}

@keyframes slide-out-right {
  from {
    opacity: 1;
    transform: translateX(0);
  }
  to {
    opacity: 0;
    transform: translateX(20px);
  }
}
```

---

## Game-Specific Animations

### HASH CRASH

#### Multiplier Climb

The multiplier number scales and intensifies as it rises.

```css
@keyframes multiplier-climb {
  0% {
    transform: scale(1);
    text-shadow: 0 0 4px var(--color-profit-glow);
  }
  50% {
    transform: scale(1.02);
    text-shadow: 0 0 8px var(--color-profit-glow);
  }
  100% {
    transform: scale(1);
    text-shadow: 0 0 4px var(--color-profit-glow);
  }
}

@keyframes multiplier-danger {
  0%, 100% {
    color: var(--color-amber);
    text-shadow: 0 0 8px var(--color-amber-glow);
  }
  50% {
    color: var(--color-red);
    text-shadow: 0 0 16px var(--color-red-glow);
  }
}

.multiplier {
  animation: multiplier-climb 0.5s ease-in-out infinite;
}

.multiplier.high-risk {
  animation: multiplier-danger 0.3s ease-in-out infinite;
}
```

#### Crash Shatter

When the game crashes, the multiplier shatters into fragments.

```css
@keyframes crash-shatter {
  0% {
    transform: scale(1) rotate(0deg);
    opacity: 1;
    filter: none;
  }
  10% {
    transform: scale(1.2) rotate(2deg);
    filter: brightness(2);
  }
  30% {
    transform: scale(0.9) rotate(-3deg);
    filter: blur(2px);
  }
  100% {
    transform: scale(0.5) rotate(10deg);
    opacity: 0;
    filter: blur(8px);
  }
}

@keyframes crash-flash {
  0% { background: transparent; }
  10% { background: rgba(255, 51, 102, 0.3); }
  30% { background: transparent; }
  50% { background: rgba(255, 51, 102, 0.1); }
  100% { background: transparent; }
}

.crashed {
  animation: crash-shatter 0.5s ease-out forwards;
}

.crash-overlay {
  animation: crash-flash 0.5s ease-out;
}
```

#### ASCII Mockup - Crash Sequence

```
FRAME 1 (before):                FRAME 2 (impact):
+------------------------+       +------------------------+
|                        |       |  ##################### |
|       23.47x           |       |       23.47x           |
|         ^              |       |    RED FLASH           |
|    climbing            |       |                        |
+------------------------+       +------------------------+

FRAME 3 (shatter):               FRAME 4 (aftermath):
+------------------------+       +------------------------+
|     2   4              |       |                        |
|       3.  7x           |       |   !! CRASHED @ 23.47 !!|
|          ^^^           |       |                        |
|    fragments scatter   |       |    static/glitch       |
+------------------------+       +------------------------+
```

---

### CODE DUEL

#### Keystroke Ripple

Visual feedback for each correct keystroke.

```css
@keyframes keystroke-ripple {
  0% {
    transform: scale(0);
    opacity: 0.6;
  }
  100% {
    transform: scale(2);
    opacity: 0;
  }
}

.keystroke-ripple {
  position: absolute;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: var(--color-accent);
  pointer-events: none;
  animation: keystroke-ripple 0.3s ease-out forwards;
}
```

#### Combo Explosion

When hitting a streak, show an explosive feedback.

```css
@keyframes combo-explosion {
  0% {
    transform: scale(0);
    opacity: 1;
  }
  50% {
    transform: scale(1.5);
    opacity: 0.8;
  }
  100% {
    transform: scale(2);
    opacity: 0;
  }
}

@keyframes combo-text-pop {
  0% {
    transform: scale(0.5) translateY(0);
    opacity: 0;
  }
  30% {
    transform: scale(1.2) translateY(-10px);
    opacity: 1;
  }
  100% {
    transform: scale(1) translateY(-30px);
    opacity: 0;
  }
}

.combo-explosion {
  position: absolute;
  border: 2px solid var(--color-gold);
  border-radius: 50%;
  animation: combo-explosion 0.4s ease-out forwards;
}

.combo-text {
  animation: combo-text-pop 0.6s ease-out forwards;
  color: var(--color-gold);
  font-weight: bold;
}
```

#### ASCII Mockup - Combo

```
FRAME 1:                         FRAME 2:                         FRAME 3:
+------------------+             +------------------+             +------------------+
|                  |             |                  |             |                  |
| ssh -L 8080:lo█  |             | ssh -L 8080:loc█ |             | ssh -L 8080:loca |
|              ^   |             |       5x COMBO!  |             |                  |
|          typing  |             |         ( * )    |             |   5x COMBO!      |
|                  |             |     explosion    |             |     ^^ floats up |
+------------------+             +------------------+             +------------------+
```

---

### ICE BREAKER

#### Target Spawn

Weak points appear with a scale-in animation.

```css
@keyframes target-spawn {
  0% {
    transform: scale(0);
    opacity: 0;
  }
  60% {
    transform: scale(1.3);
    opacity: 1;
  }
  100% {
    transform: scale(1);
    opacity: 1;
  }
}

@keyframes target-pulse {
  0%, 100% {
    box-shadow: 0 0 8px var(--color-profit);
  }
  50% {
    box-shadow: 0 0 20px var(--color-profit), 0 0 30px var(--color-profit);
  }
}

.weak-point {
  animation: target-spawn 0.2s ease-out, target-pulse 0.5s ease-in-out infinite;
}
```

#### Hit Reaction

Feedback when successfully clicking a target.

```css
@keyframes hit-success {
  0% {
    transform: scale(1);
    opacity: 1;
    background: var(--color-profit);
  }
  50% {
    transform: scale(1.8);
    opacity: 0.5;
  }
  100% {
    transform: scale(2.5);
    opacity: 0;
  }
}

@keyframes hit-perfect {
  0% {
    transform: scale(1);
    opacity: 1;
  }
  30% {
    transform: scale(2);
    box-shadow: 0 0 40px var(--color-gold);
  }
  100% {
    transform: scale(3);
    opacity: 0;
  }
}

@keyframes hit-miss {
  0%, 100% { transform: translateX(0); }
  20% { transform: translateX(-5px); }
  40% { transform: translateX(5px); }
  60% { transform: translateX(-3px); }
  80% { transform: translateX(3px); }
}

.hit-normal {
  animation: hit-success 0.25s ease-out forwards;
}

.hit-perfect {
  animation: hit-perfect 0.35s ease-out forwards;
}

.hit-miss {
  animation: hit-miss 0.3s ease-out;
  background: var(--color-red) !important;
}
```

---

### BINARY BET

#### Coin Flip 3D Rotation

Full 3D coin flip animation for the binary choice reveal.

```css
@keyframes coin-flip {
  0% {
    transform: rotateY(0deg) scale(1);
  }
  25% {
    transform: rotateY(450deg) scale(1.2);
  }
  50% {
    transform: rotateY(900deg) scale(1.3);
  }
  75% {
    transform: rotateY(1260deg) scale(1.2);
  }
  100% {
    transform: rotateY(1440deg) scale(1);
  }
}

@keyframes coin-landing {
  0% {
    transform: translateY(-20px);
    filter: brightness(1.5);
  }
  50% {
    transform: translateY(5px);
  }
  75% {
    transform: translateY(-3px);
  }
  100% {
    transform: translateY(0);
    filter: brightness(1);
  }
}

.coin {
  transform-style: preserve-3d;
  perspective: 1000px;
}

.coin.flipping {
  animation: coin-flip 1.5s ease-in-out;
}

.coin.landing {
  animation: coin-landing 0.3s ease-out;
}

.coin-face {
  backface-visibility: hidden;
}

.coin-face.back {
  transform: rotateY(180deg);
}
```

#### ASCII Mockup - Coin Flip

```
FRAME 1:        FRAME 2:        FRAME 3:        FRAME 4:
+--------+      +--------+      +--------+      +--------+
|        |      |        |      |        |      |        |
|  [?]   |      |  /_\   |      |  |_|   |      |  [0]   |
|        |      |  \ /   |      |        |      |        |
|  idle  |      | spinning|      | landing |      | result |
+--------+      +--------+      +--------+      +--------+
```

---

### BOUNTY HUNT

#### Radar Sweep

Scanning animation for detecting targets.

```css
@keyframes radar-sweep {
  0% {
    transform: rotate(0deg);
    opacity: 1;
  }
  100% {
    transform: rotate(360deg);
    opacity: 1;
  }
}

@keyframes radar-ping {
  0% {
    transform: scale(0);
    opacity: 1;
    border-width: 2px;
  }
  100% {
    transform: scale(3);
    opacity: 0;
    border-width: 0px;
  }
}

.radar-sweep {
  position: absolute;
  width: 100%;
  height: 100%;
  background: conic-gradient(
    from 0deg,
    transparent 0deg,
    var(--color-accent-glow) 30deg,
    transparent 60deg
  );
  animation: radar-sweep 2s linear infinite;
}

.radar-ping {
  position: absolute;
  border: 2px solid var(--color-accent);
  border-radius: 50%;
  animation: radar-ping 1s ease-out forwards;
}
```

#### Lock-On

Target acquisition animation.

```css
@keyframes lock-on-corners {
  0% {
    width: 200%;
    height: 200%;
    opacity: 0;
  }
  50% {
    width: 120%;
    height: 120%;
    opacity: 1;
  }
  100% {
    width: 100%;
    height: 100%;
    opacity: 1;
  }
}

@keyframes lock-on-pulse {
  0%, 100% {
    border-color: var(--color-red);
    box-shadow: inset 0 0 10px var(--color-red-glow);
  }
  50% {
    border-color: var(--color-red);
    box-shadow: inset 0 0 20px var(--color-red-glow), 0 0 10px var(--color-red-glow);
  }
}

.lock-on-reticle {
  position: absolute;
  border: 2px solid var(--color-red);
  animation: 
    lock-on-corners 0.3s ease-out,
    lock-on-pulse 0.5s ease-in-out infinite 0.3s;
}

.lock-on-reticle::before,
.lock-on-reticle::after {
  content: '';
  position: absolute;
  background: var(--color-red);
}

/* Corner brackets */
.lock-on-reticle::before {
  width: 10px;
  height: 2px;
  top: -2px;
  left: -2px;
}
```

---

### PROXY WAR

#### Territory Pulse

Indicates territory ownership and status.

```css
@keyframes territory-pulse-owned {
  0%, 100% {
    box-shadow: inset 0 0 10px var(--color-accent-glow);
  }
  50% {
    box-shadow: inset 0 0 20px var(--color-accent-glow);
  }
}

@keyframes territory-pulse-contested {
  0%, 100% {
    box-shadow: 
      inset 0 0 10px var(--color-accent-glow),
      inset 0 0 10px var(--color-red-glow);
  }
  50% {
    box-shadow: 
      inset 0 0 20px var(--color-accent-glow),
      inset 0 0 20px var(--color-red-glow);
  }
}

.territory-owned {
  animation: territory-pulse-owned 2s ease-in-out infinite;
}

.territory-contested {
  animation: territory-pulse-contested 1s ease-in-out infinite;
}
```

#### Battle Clash

Visual effect when two crews clash.

```css
@keyframes battle-clash-left {
  0% {
    transform: translateX(-100px);
    opacity: 0;
  }
  50% {
    transform: translateX(10px);
    opacity: 1;
  }
  100% {
    transform: translateX(0);
    opacity: 1;
  }
}

@keyframes battle-clash-right {
  0% {
    transform: translateX(100px);
    opacity: 0;
  }
  50% {
    transform: translateX(-10px);
    opacity: 1;
  }
  100% {
    transform: translateX(0);
    opacity: 1;
  }
}

@keyframes clash-spark {
  0% {
    transform: scale(0) rotate(0deg);
    opacity: 1;
  }
  100% {
    transform: scale(2) rotate(180deg);
    opacity: 0;
  }
}

.attacker-emblem {
  animation: battle-clash-left 0.5s ease-out;
}

.defender-emblem {
  animation: battle-clash-right 0.5s ease-out;
}

.clash-spark {
  animation: clash-spark 0.4s ease-out 0.4s forwards;
}
```

---

### ZERO DAY

#### Breach Cascade

Progressive system breach animation.

```css
@keyframes breach-cascade {
  0% {
    clip-path: polygon(0 0, 0 0, 0 100%, 0 100%);
    background: var(--color-red);
  }
  100% {
    clip-path: polygon(0 0, 100% 0, 100% 100%, 0 100%);
    background: transparent;
  }
}

@keyframes breach-line {
  0% {
    transform: translateY(-100%);
    opacity: 1;
  }
  100% {
    transform: translateY(100%);
    opacity: 0;
  }
}

.breach-overlay {
  animation: breach-cascade 0.8s ease-out forwards;
}

.breach-line {
  position: absolute;
  width: 100%;
  height: 2px;
  background: var(--color-red);
  animation: breach-line 0.3s linear forwards;
}
```

#### Firewall Crack

Visual representation of firewall breaking.

```css
@keyframes firewall-crack {
  0% {
    background-position: center;
    filter: none;
  }
  30% {
    filter: brightness(2);
  }
  50% {
    background-image: url("data:image/svg+xml,..."); /* crack pattern */
    filter: brightness(1.5);
  }
  100% {
    filter: none;
  }
}

@keyframes firewall-shatter {
  0% {
    transform: scale(1);
    opacity: 1;
  }
  50% {
    transform: scale(1.1);
  }
  100% {
    transform: scale(0.8);
    opacity: 0;
    filter: blur(4px);
  }
}

.firewall-breaking {
  animation: firewall-crack 0.6s ease-out;
}

.firewall-shattered {
  animation: firewall-shatter 0.4s ease-out forwards;
}
```

---

### SHADOW PROTOCOL

#### Cloak Fade

Entering shadow/stealth mode.

```css
@keyframes cloak-fade-in {
  0% {
    opacity: 1;
    filter: none;
  }
  30% {
    filter: blur(2px) brightness(1.5);
  }
  60% {
    opacity: 0.5;
    filter: blur(4px);
  }
  100% {
    opacity: 0.15;
    filter: blur(0) grayscale(0.5);
  }
}

@keyframes cloak-fade-out {
  0% {
    opacity: 0.15;
    filter: grayscale(0.5);
  }
  40% {
    filter: blur(4px) brightness(1.5);
  }
  100% {
    opacity: 1;
    filter: none;
  }
}

@keyframes cloak-shimmer {
  0%, 100% {
    opacity: 0.15;
  }
  50% {
    opacity: 0.25;
  }
}

.cloaking {
  animation: cloak-fade-in 0.8s ease-out forwards;
}

.uncloaking {
  animation: cloak-fade-out 0.6s ease-out forwards;
}

.cloaked {
  animation: cloak-shimmer 3s ease-in-out infinite;
  opacity: 0.15;
  filter: grayscale(0.5);
}
```

#### Detection Scan

Hunter scanning for shadows.

```css
@keyframes detection-scan {
  0% {
    transform: translateX(-100%);
    opacity: 0;
  }
  10% {
    opacity: 1;
  }
  90% {
    opacity: 1;
  }
  100% {
    transform: translateX(100%);
    opacity: 0;
  }
}

@keyframes scan-line-glow {
  0%, 100% {
    box-shadow: 0 0 20px var(--color-cyan);
  }
  50% {
    box-shadow: 0 0 40px var(--color-cyan), 0 0 60px var(--color-cyan);
  }
}

.detection-scan-line {
  position: absolute;
  width: 2px;
  height: 100%;
  background: var(--color-cyan);
  animation: 
    detection-scan 2s ease-in-out,
    scan-line-glow 0.3s ease-in-out infinite;
}

.detection-scan-area {
  position: absolute;
  width: 20%;
  height: 100%;
  background: linear-gradient(
    90deg,
    transparent,
    rgba(0, 229, 255, 0.1),
    transparent
  );
  animation: detection-scan 2s ease-in-out;
}
```

#### ASCII Mockup - Cloak

```
FRAME 1 (visible):               FRAME 2 (cloaking):              FRAME 3 (cloaked):
+------------------------+       +------------------------+       +------------------------+
|                        |       |                        |       |                        |
|    [PLAYER CARD]       |       |    [PLAY~~ C~RD]       |       |    . . . . . . . .     |
|    Position: 2500      |       |    Posit~~~: ~~~~      |       |    . . . . . . . .     |
|    Status: ACTIVE      |       |    Stat~~: ~~~~~~      |       |    . . . . . . . .     |
|        ^               |       |       blur effect      |       |     barely visible     |
+------------------------+       +------------------------+       +------------------------+
```

---

## State Transitions

### Page Transitions

```css
@keyframes page-enter {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes page-exit {
  from {
    opacity: 1;
    transform: translateY(0);
  }
  to {
    opacity: 0;
    transform: translateY(-20px);
  }
}

.page-transition-enter {
  animation: page-enter var(--duration-slow) var(--ease-out);
}

.page-transition-exit {
  animation: page-exit var(--duration-normal) var(--ease-in);
}
```

### Modal Enter/Exit

```css
@keyframes modal-enter {
  from {
    opacity: 0;
    transform: scale(0.95) translateY(-10px);
  }
  to {
    opacity: 1;
    transform: scale(1) translateY(0);
  }
}

@keyframes modal-exit {
  from {
    opacity: 1;
    transform: scale(1) translateY(0);
  }
  to {
    opacity: 0;
    transform: scale(0.95) translateY(-10px);
  }
}

@keyframes backdrop-enter {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes backdrop-exit {
  from { opacity: 1; }
  to { opacity: 0; }
}

.modal-enter {
  animation: modal-enter var(--duration-normal) var(--ease-out);
}

.modal-exit {
  animation: modal-exit var(--duration-fast) var(--ease-in);
}

.backdrop-enter {
  animation: backdrop-enter var(--duration-normal) var(--ease-out);
}

.backdrop-exit {
  animation: backdrop-exit var(--duration-fast) var(--ease-in);
}
```

### Component Mount/Unmount

```css
@keyframes mount-fade-up {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes unmount-fade-down {
  from {
    opacity: 1;
    transform: translateY(0);
  }
  to {
    opacity: 0;
    transform: translateY(10px);
  }
}

@keyframes mount-scale {
  from {
    opacity: 0;
    transform: scale(0.9);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}

.component-mount {
  animation: mount-fade-up var(--duration-normal) var(--ease-out);
}

.component-unmount {
  animation: unmount-fade-down var(--duration-fast) var(--ease-in);
}
```

### Feed Item Animation

```css
@keyframes feed-item-enter {
  from {
    opacity: 0;
    transform: translateY(-20px);
    max-height: 0;
  }
  to {
    opacity: 1;
    transform: translateY(0);
    max-height: 100px;
  }
}

@keyframes feed-item-highlight {
  0% { background: transparent; }
  20% { background: rgba(0, 229, 204, 0.15); }
  100% { background: transparent; }
}

.feed-item-new {
  animation: 
    feed-item-enter var(--duration-normal) var(--ease-out),
    feed-item-highlight 1s ease-out 0.2s;
}
```

---

## Performance

### GPU-Accelerated Properties

Always animate these properties for best performance:

```css
/* GOOD - GPU accelerated */
.performant {
  transform: translateX(100px);
  transform: scale(1.1);
  transform: rotate(45deg);
  opacity: 0.5;
}

/* AVOID - triggers layout */
.slow {
  left: 100px;
  width: 200px;
  height: 200px;
  margin: 10px;
  padding: 10px;
}

/* AVOID - triggers paint */
.slower {
  background-color: red;
  border-color: blue;
  box-shadow: 0 0 10px black;
}
```

### `will-change` Usage

Use `will-change` sparingly and remove after animation:

```css
/* Apply before animation starts */
.about-to-animate {
  will-change: transform, opacity;
}

/* Remove after animation completes */
.animation-complete {
  will-change: auto;
}
```

```svelte
<script lang="ts">
  let isAnimating = $state(false);
  
  function startAnimation() {
    isAnimating = true;
    // Animation runs...
  }
  
  function onAnimationEnd() {
    isAnimating = false;
  }
</script>

<div 
  class="animated-element"
  class:will-change-transform={isAnimating}
  onanimationend={onAnimationEnd}
>
```

### Animation Frame Budgets

Target 60fps = 16.67ms per frame budget.

| Animation Complexity | Budget |
|---------------------|--------|
| Simple (opacity, transform) | < 4ms |
| Medium (box-shadow, filter) | < 8ms |
| Complex (multiple properties) | < 12ms |

### Reducing Paint Operations

```css
/* Promote to own layer for complex animations */
.complex-animation {
  isolation: isolate;
  contain: layout style paint;
}

/* Use transform instead of position changes */
.sliding-panel {
  transform: translateX(var(--offset));
  /* NOT: left: var(--offset); */
}
```

### Reduced Motion Preferences

Always respect user preferences:

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
  
  /* Alternative: provide simplified animations */
  .animated-element {
    animation: none;
    transition: opacity 0.1ms;
  }
}
```

```svelte
<script lang="ts">
  import { browser } from '$app/environment';
  
  let prefersReducedMotion = $state(false);
  
  $effect(() => {
    if (browser) {
      const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
      prefersReducedMotion = mediaQuery.matches;
      
      const handler = (e: MediaQueryListEvent) => {
        prefersReducedMotion = e.matches;
      };
      
      mediaQuery.addEventListener('change', handler);
      return () => mediaQuery.removeEventListener('change', handler);
    }
  });
</script>

{#if prefersReducedMotion}
  <div class="static-content">{text}</div>
{:else}
  <TypeWriter {text} />
{/if}
```

---

## Svelte Transitions

### Using svelte/transition

Built-in transitions for common patterns:

```svelte
<script lang="ts">
  import { fade, fly, slide, scale, blur } from 'svelte/transition';
  import { quintOut, elasticOut } from 'svelte/easing';
  
  let visible = $state(true);
</script>

<!-- Basic fade -->
{#if visible}
  <div transition:fade={{ duration: 200 }}>
    Content
  </div>
{/if}

<!-- Fly in from direction -->
{#if visible}
  <div in:fly={{ y: 20, duration: 200 }} out:fade={{ duration: 100 }}>
    Content
  </div>
{/if}

<!-- Scale with custom easing -->
{#if visible}
  <div transition:scale={{ start: 0.95, opacity: 0, easing: quintOut }}>
    Content
  </div>
{/if}
```

### Custom Transition Functions

Terminal-style typing transition:

```typescript
// src/lib/ui/transitions/terminal.ts
import type { TransitionConfig } from 'svelte/transition';

export function typewriter(
  node: HTMLElement,
  { speed = 30, delay = 0 }: { speed?: number; delay?: number } = {}
): TransitionConfig {
  const text = node.textContent || '';
  const duration = text.length * speed;

  return {
    delay,
    duration,
    tick: (t: number) => {
      const i = Math.floor(text.length * t);
      node.textContent = text.slice(0, i);
    },
  };
}

export function glitchIn(
  node: HTMLElement,
  { duration = 300, delay = 0 }: { duration?: number; delay?: number } = {}
): TransitionConfig {
  const originalText = node.textContent || '';
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%&*';

  return {
    delay,
    duration,
    tick: (t: number) => {
      if (t === 1) {
        node.textContent = originalText;
        return;
      }

      const result = originalText
        .split('')
        .map((char, i) => {
          if (i < originalText.length * t) {
            return char;
          }
          return chars[Math.floor(Math.random() * chars.length)];
        })
        .join('');

      node.textContent = result;
    },
  };
}

export function scanLine(
  node: HTMLElement,
  { duration = 500, delay = 0 }: { duration?: number; delay?: number } = {}
): TransitionConfig {
  return {
    delay,
    duration,
    css: (t: number) => {
      return `
        clip-path: polygon(0 0, 100% 0, 100% ${t * 100}%, 0 ${t * 100}%);
        opacity: ${t};
      `;
    },
  };
}
```

### Usage in Components

```svelte
<script lang="ts">
  import { typewriter, glitchIn, scanLine } from '$lib/ui/transitions/terminal';
  
  let showMessage = $state(false);
  let showPanel = $state(false);
</script>

<button onclick={() => showMessage = !showMessage}>
  Toggle Message
</button>

{#if showMessage}
  <p in:typewriter={{ speed: 50 }} out:fade={{ duration: 100 }}>
    > System initialized. Welcome, operator.
  </p>
{/if}

{#if showPanel}
  <div in:scanLine={{ duration: 400 }} out:fade>
    <h2 in:glitchIn={{ duration: 300, delay: 400 }}>
      CLASSIFIED DATA
    </h2>
  </div>
{/if}
```

### Coordinated Transitions

Staggered animations for lists:

```svelte
<script lang="ts">
  import { fly, fade } from 'svelte/transition';
  
  interface Props {
    items: string[];
  }
  
  let { items }: Props = $props();
</script>

<ul>
  {#each items as item, i (item)}
    <li
      in:fly={{ y: 20, delay: i * 50, duration: 200 }}
      out:fade={{ duration: 100 }}
    >
      {item}
    </li>
  {/each}
</ul>
```

### Deferred Transitions

For complex coordinated enter/exit:

```svelte
<script lang="ts">
  import { crossfade } from 'svelte/transition';
  import { quintOut } from 'svelte/easing';

  const [send, receive] = crossfade({
    duration: 300,
    fallback(node) {
      return {
        duration: 300,
        easing: quintOut,
        css: (t) => `opacity: ${t}; transform: scale(${t})`,
      };
    },
  });

  let items = $state([
    { id: 1, name: 'Alpha' },
    { id: 2, name: 'Beta' },
  ]);
  
  let selected = $state<typeof items[0] | null>(null);
</script>

<div class="list">
  {#each items.filter(i => i !== selected) as item (item.id)}
    <div
      in:receive={{ key: item.id }}
      out:send={{ key: item.id }}
      onclick={() => selected = item}
    >
      {item.name}
    </div>
  {/each}
</div>

{#if selected}
  <div class="detail">
    <div
      in:receive={{ key: selected.id }}
      out:send={{ key: selected.id }}
    >
      {selected.name}
    </div>
    <button onclick={() => selected = null}>Close</button>
  </div>
{/if}
```

---

## Implementation Checklist

When implementing animations for a new game:

- [ ] Define animation purpose (feedback, guidance, continuity, atmosphere)
- [ ] Choose appropriate duration from standards
- [ ] Use GPU-accelerated properties only
- [ ] Add reduced motion fallbacks
- [ ] Test at 60fps on target devices
- [ ] Limit concurrent animations per budget
- [ ] Document in game's design doc
- [ ] Add to `animations.css` if reusable

---

## File Organization

```
apps/web/src/lib/ui/
+-- styles/
|   +-- animations.css       # Global keyframes and utility classes
|   +-- tokens.css           # Timing and easing variables
+-- transitions/
|   +-- terminal.ts          # Custom Svelte transitions
|   +-- game.ts              # Game-specific transitions
+-- components/
    +-- TypeWriter.svelte    # Reusable animation components
    +-- GlitchText.svelte
    +-- Flicker.svelte
```

---

## References

- [CSS Animations Performance](https://developer.chrome.com/docs/devtools/performance/reference/)
- [Svelte Transitions](https://svelte.dev/docs/svelte-transition)
- [prefers-reduced-motion](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion)
- [GHOSTNET Design Tokens](/apps/web/src/lib/ui/styles/tokens.css)
- [GHOSTNET Existing Animations](/apps/web/src/lib/ui/styles/animations.css)
