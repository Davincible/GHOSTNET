# 20. Animations & Transitions

## Built-in Transitions

```svelte
<script>
  import { fade, fly, slide, scale, blur, draw } from 'svelte/transition';
  import { flip } from 'svelte/animate';
  
  let visible = $state(true);
  let items = $state([1, 2, 3, 4, 5]);
</script>

<!-- Basic transition -->
{#if visible}
  <div transition:fade>Fades in/out</div>
{/if}

<!-- In/out separately -->
{#if visible}
  <div 
    in:fly={{ y: 200, duration: 300 }}
    out:fade={{ duration: 200 }}
  >
    Flies in, fades out
  </div>
{/if}

<!-- List animations -->
{#each items as item (item)}
  <div 
    animate:flip={{ duration: 300 }}
    transition:slide
  >
    {item}
  </div>
{/each}
```

## The `|local` Modifier

By default, transitions in `{#each}` blocks run when:
1. The item enters/exits the list
2. The parent component re-renders

Use `|local` to only run transitions for the item's own enter/exit:

```svelte
{#each items as item (item.id)}
  <!-- Without |local: runs on ANY parent update -->
  <div transition:slide>...</div>
  
  <!-- With |local: runs ONLY when this item enters/exits -->
  <div transition:slide|local>...</div>
{/each}
```

This is important for performance with large lists or frequently updating parents.

## Custom Transitions

```svelte
<script lang="ts">
  import type { TransitionConfig } from 'svelte/transition';
  
  function typewriter(
    node: HTMLElement, 
    { speed = 1 }: { speed?: number } = {}
  ): TransitionConfig {
    const text = node.textContent ?? '';
    const duration = text.length / (speed * 0.01);
    
    return {
      duration,
      tick: (t) => {
        const i = Math.trunc(text.length * t);
        node.textContent = text.slice(0, i);
      }
    };
  }
  
  let show = $state(false);
</script>

{#if show}
  <p transition:typewriter={{ speed: 2 }}>
    This text will type out character by character
  </p>
{/if}
```

## Deferred Transitions (Crossfade)

```svelte
<script>
  import { crossfade } from 'svelte/transition';
  import { quintOut } from 'svelte/easing';
  
  const [send, receive] = crossfade({
    duration: 400,
    easing: quintOut,
    fallback: (node) => {
      return {
        duration: 300,
        css: (t) => `opacity: ${t}`
      };
    }
  });
  
  let items = $state([
    { id: 1, name: 'Item 1', done: false },
    { id: 2, name: 'Item 2', done: true }
  ]);
  
  const pending = $derived(items.filter(i => !i.done));
  const completed = $derived(items.filter(i => i.done));
</script>

<div class="todo-columns">
  <div class="pending">
    <h2>Pending</h2>
    {#each pending as item (item.id)}
      <div 
        in:receive={{ key: item.id }}
        out:send={{ key: item.id }}
      >
        {item.name}
      </div>
    {/each}
  </div>
  
  <div class="completed">
    <h2>Completed</h2>
    {#each completed as item (item.id)}
      <div 
        in:receive={{ key: item.id }}
        out:send={{ key: item.id }}
      >
        {item.name}
      </div>
    {/each}
  </div>
</div>
```

---

## Spring and Tween (Svelte 5.8+)

The `Spring` and `Tween` classes provide smooth value interpolation for animations.

### Tween: Time-Based Animation

`Tween` interpolates values over a fixed duration with easing.

```svelte
<script>
  import { Tween } from 'svelte/motion';
  import { cubicOut } from 'svelte/easing';
  
  // Create a tween with initial value and options
  const progress = new Tween(0, {
    duration: 400,
    easing: cubicOut
  });
</script>

<!-- Read current value via .current -->
<progress value={progress.current}></progress>

<!-- Set target value (animates automatically) -->
<button onclick={() => progress.target = 1}>Complete</button>
<button onclick={() => progress.target = 0}>Reset</button>
```

### Tween Constructor Options

```typescript
interface TweenOptions<T> {
  /** Milliseconds before animation starts. Default: 0 */
  delay?: number;
  
  /** Duration in ms, or function (from, to) => ms. Default: 400 */
  duration?: number | ((from: T, to: T) => number);
  
  /** Easing function. Default: linear (t => t) */
  easing?: (t: number) => number;
  
  /** Custom interpolation function for non-numeric values */
  interpolate?: (from: T, to: T) => (t: number) => T;
}

const tween = new Tween<T>(initialValue: T, options?: TweenOptions<T>);
```

### Tween Properties and Methods

```typescript
class Tween<T> {
  /** Current interpolated value (readonly, reactive) */
  get current(): T;
  
  /** Target value (writable, setting triggers animation) */
  get target(): T;
  set target(value: T);
  
  /** Set target with optional override options. Returns Promise */
  set(value: T, options?: TweenOptions<T>): Promise<void>;
  
  /** Static factory: creates Tween bound to reactive expression */
  static of<U>(fn: () => U, options?: TweenOptions<U>): Tween<U>;
}
```

### Tween.of() — Reactive Factory

Creates a tween that automatically follows a reactive value:

```svelte
<script>
  import { Tween } from 'svelte/motion';
  
  let { value } = $props();
  
  // Tween automatically animates when `value` prop changes
  const smoothValue = Tween.of(() => value, { duration: 300 });
</script>

<div style="width: {smoothValue.current}px">
  Smoothly resizes
</div>
```

### Spring: Physics-Based Animation

`Spring` uses spring physics for natural-feeling motion, especially for frequently changing values.

```svelte
<script>
  import { Spring } from 'svelte/motion';
  
  // Create spring with initial value and physics options
  const coords = new Spring({ x: 0, y: 0 }, {
    stiffness: 0.1,
    damping: 0.5
  });
  
  function handleMouseMove(e: MouseEvent) {
    coords.target = { x: e.clientX, y: e.clientY };
  }
</script>

<svelte:window onmousemove={handleMouseMove} />

<div 
  class="cursor-follower"
  style="transform: translate({coords.current.x}px, {coords.current.y}px)"
></div>
```

### Spring Constructor Options

```typescript
interface SpringOptions {
  /** 
   * Stiffness: 0 to 1. Higher = tighter/faster spring. 
   * Default: 0.15 
   */
  stiffness?: number;
  
  /** 
   * Damping: 0 to 1. Higher = less oscillation/bounce. 
   * Default: 0.8 
   */
  damping?: number;
  
  /** 
   * Precision threshold for considering spring "settled". 
   * Default: 0.01 
   */
  precision?: number;
}

const spring = new Spring<T>(initialValue: T, options?: SpringOptions);
```

### Spring Properties and Methods

```typescript
class Spring<T> {
  /** Current interpolated value (readonly, reactive) */
  get current(): T;
  
  /** Target value (writable, setting starts spring animation) */
  get target(): T;
  set target(value: T);
  
  /** Current stiffness (writable) */
  get stiffness(): number;
  set stiffness(value: number);
  
  /** Current damping (writable) */
  get damping(): number;
  set damping(value: number);
  
  /** 
   * Set target with options. Returns Promise that resolves when settled.
   * Options:
   * - hard: boolean — if true, sets value immediately (no animation)
   * - soft: boolean | number — preserves momentum
   */
  set(value: T, options?: { hard?: boolean; soft?: boolean | number }): Promise<void>;
  
  /** Static factory: creates Spring bound to reactive expression */
  static of<U>(fn: () => U, options?: SpringOptions): Spring<U>;
}
```

### Spring.of() — Reactive Factory

```svelte
<script>
  import { Spring } from 'svelte/motion';
  
  let size = $state(100);
  
  // Spring automatically animates when `size` changes
  const smoothSize = Spring.of(() => size);
</script>

<input type="range" bind:value={size} min="50" max="200" />

<div style="width: {smoothSize.current}px; height: {smoothSize.current}px">
  Bouncy resize
</div>
```

### Spring Set Options

```svelte
<script>
  import { Spring } from 'svelte/motion';
  
  const pos = new Spring({ x: 0, y: 0 });
  
  function teleport(x: number, y: number) {
    // Instant move, no animation
    pos.set({ x, y }, { hard: true });
  }
  
  function gentleMove(x: number, y: number) {
    // Preserve existing momentum for 0.5 seconds
    pos.set({ x, y }, { soft: true });
  }
  
  function smoothMove(x: number, y: number) {
    // Preserve momentum for 1 second before settling
    pos.set({ x, y }, { soft: 1 });
  }
</script>
```

### Custom Interpolation (Tween)

For non-numeric values like colors:

```svelte
<script>
  import { Tween } from 'svelte/motion';
  import { interpolateLab } from 'd3-interpolate';
  
  const color = new Tween('#ff0000', {
    duration: 800,
    interpolate: (from, to) => interpolateLab(from, to)
  });
</script>

<button onclick={() => color.target = '#0000ff'}>
  Blue
</button>

<div style="background: {color.current}">
  Smooth color transition
</div>
```

### Reduced Motion Support

```svelte
<script>
  import { Spring, prefersReducedMotion } from 'svelte/motion';
  
  const position = new Spring({ x: 0, y: 0 });
  
  function move(x: number, y: number) {
    if (prefersReducedMotion.current) {
      // Skip animation for users who prefer reduced motion
      position.set({ x, y }, { hard: true });
    } else {
      position.target = { x, y };
    }
  }
</script>
```

### Migration from Deprecated API

| Old API (Deprecated) | New API (Svelte 5.8+) |
|---------------------|----------------------|
| `import { spring, tweened }` | `import { Spring, Tween }` |
| `let x = spring(value, opts)` | `const x = new Spring(value, opts)` |
| `let x = tweened(value, opts)` | `const x = new Tween(value, opts)` |
| `$x` | `x.current` |
| `x.set(value)` | `x.set(value)` or `x.target = value` |
| `x.update(fn)` | `x.target = fn(x.target)` |

> **Note:** The old `spring()` and `tweened()` functions still work but emit deprecation warnings. Migrate to classes for new code.

---

**Next:** [21. Attachments](./21-Attachments.md)
