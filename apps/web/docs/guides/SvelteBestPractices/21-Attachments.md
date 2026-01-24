# 21. Attachments

> **Available since Svelte 5.29**

Attachments are functions that run when an element is mounted, with optional cleanup on unmount. They replace `use:action` with better reactivity and flexibility.

## Basic Attachment

An attachment is a function that receives a DOM element and optionally returns a cleanup function:

```svelte
<script>
	function highlight(element: HTMLElement) {
		element.style.backgroundColor = 'yellow';

		// Optional: return cleanup function
		return () => {
			element.style.backgroundColor = '';
		};
	}
</script>

<div {@attach highlight}>This is highlighted</div>
```

## Inline Attachments

For quick element references without named functions:

```svelte
<script>
	import { gsap } from 'gsap';
</script>

<!-- Inline attachment -->
<div
	{@attach (el) => {
		gsap.to(el, { rotation: 360, duration: 2 });
	}}
>
	Spinning
</div>

<!-- With cleanup -->
<div
	{@attach (el) => {
		const handler = () => console.log('clicked');
		el.addEventListener('click', handler);
		return () => el.removeEventListener('click', handler);
	}}
>
	Click me
</div>
```

## Attachment Factories (Parameters)

To pass parameters, create a factory function that returns the attachment:

```svelte
<script>
	import tippy from 'tippy.js';

	// Factory: returns an attachment
	function tooltip(content: string, options?: Partial<TippyOptions>) {
		return (element: HTMLElement) => {
			const instance = tippy(element, { content, ...options });
			return () => instance.destroy();
		};
	}
</script>

<button {@attach tooltip('Hello!')}> Hover me </button>

<button {@attach tooltip('With options', { placement: 'bottom' })}> Hover me too </button>
```

## Reactive Attachments

Attachments automatically re-run when reactive dependencies change:

```svelte
<script>
	import tippy from 'tippy.js';

	let content = $state('Initial tooltip');

	function tooltip(text: string) {
		return (element: HTMLElement) => {
			const instance = tippy(element, { content: text });
			return () => instance.destroy();
		};
	}
</script>

<input bind:value={content} />

<!-- Attachment re-runs when `content` changes -->
<button {@attach tooltip(content)}> Hover me </button>
```

## Multiple Attachments

Apply multiple attachments to a single element:

```svelte
<script>
	function logMount(el: HTMLElement) {
		console.log('mounted:', el);
		return () => console.log('unmounted');
	}

	function addBorder(el: HTMLElement) {
		el.style.border = '2px solid red';
		return () => {
			el.style.border = '';
		};
	}

	function trackClicks(el: HTMLElement) {
		let count = 0;
		const handler = () => console.log('click', ++count);
		el.addEventListener('click', handler);
		return () => el.removeEventListener('click', handler);
	}
</script>

<!-- Multiple attachments -->
<div {@attach logMount} {@attach addBorder} {@attach trackClicks}>Multiple attachments</div>
```

## Spreading Attachments

Attachments can be spread from objects using `createAttachmentKey`:

```svelte
<script>
	import { createAttachmentKey } from 'svelte/attachments';

	function tooltip(content: string) {
		return (el: HTMLElement) => {
			el.title = content;
		};
	}

	// Create spreadable attachment
	const tooltipKey = createAttachmentKey();

	const props = {
		class: 'button',
		[tooltipKey]: tooltip('Click me!'),
	};
</script>

<!-- Attachment is applied via spread -->
<button {...props}> Hover for tooltip </button>
```

## Attachments on Components

Unlike actions, attachments can be used on components:

```svelte
<!-- Button.svelte -->
<script>
  let { children, ...rest } = $props();
</script>

<button {...rest}>
  {@render children?.()}
</button>

<!-- Parent.svelte -->
<script>
  import Button from './Button.svelte';

  function track(el: HTMLElement) {
    console.log('Button element:', el);
  }
</script>

<!-- Attachment passes through to the <button> element -->
<Button {@attach track}>
  Click me
</Button>
```

## Converting Actions to Attachments

Use `fromAction` to convert existing actions:

```svelte
<script>
	import { fromAction } from 'svelte/attachments';

	// Existing action (old style)
	function legacyAction(node: HTMLElement, params: { color: string }) {
		node.style.color = params.color;
		return {
			update(newParams: { color: string }) {
				node.style.color = newParams.color;
			},
			destroy() {
				node.style.color = '';
			},
		};
	}

	// Convert to attachment
	const colorize = fromAction(legacyAction);

	let color = $state('red');
</script>

<!-- Use converted action as attachment --><p {@attach colorize({ color })}>Colored text</p>
```

## svelte/attachments Module

```typescript
// svelte/attachments

/**
 * Creates a unique key for spreading attachments onto elements
 */
function createAttachmentKey(): symbol;

/**
 * Converts a Svelte action to an attachment
 */
function fromAction<T>(
	action: (
		node: HTMLElement,
		params: T
	) => {
		update?: (params: T) => void;
		destroy?: () => void;
	} | void
): (params: T) => (node: HTMLElement) => void;
```

## Attachments vs Actions Comparison

| Feature             | Actions (`use:`)           | Attachments (`{@attach}`)        |
| ------------------- | -------------------------- | -------------------------------- |
| Syntax              | `use:action={params}`      | `{@attach factory(params)}`      |
| Parameter updates   | Manual `update()` function | Automatic re-run                 |
| Works on components | No                         | Yes                              |
| Spreadable          | No                         | Yes (with `createAttachmentKey`) |
| Inline functions    | No                         | Yes                              |
| Return value        | `{ update, destroy }`      | Cleanup function only            |

## Common Patterns

### Autofocus

```svelte
<script>
	function autofocus(el: HTMLElement) {
		el.focus();
	}
</script>

<input {@attach autofocus} />
```

### Focus Trap

```svelte
<script>
	function focusTrap(el: HTMLElement) {
		const focusable = el.querySelectorAll(
			'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
		);
		const first = focusable[0] as HTMLElement;
		const last = focusable[focusable.length - 1] as HTMLElement;

		function handleKeydown(e: KeyboardEvent) {
			if (e.key !== 'Tab') return;

			if (e.shiftKey && document.activeElement === first) {
				e.preventDefault();
				last.focus();
			} else if (!e.shiftKey && document.activeElement === last) {
				e.preventDefault();
				first.focus();
			}
		}

		el.addEventListener('keydown', handleKeydown);
		first?.focus();

		return () => el.removeEventListener('keydown', handleKeydown);
	}
</script>

<div {@attach focusTrap} class="modal">
	<input />
	<button>Submit</button>
	<button>Cancel</button>
</div>
```

### Click Outside

```svelte
<script>
	function clickOutside(callback: () => void) {
		return (element: HTMLElement) => {
			function handler(event: MouseEvent) {
				if (!element.contains(event.target as Node)) {
					callback();
				}
			}

			document.addEventListener('click', handler, true);
			return () => document.removeEventListener('click', handler, true);
		};
	}

	let open = $state(false);
</script>

{#if open}
	<div {@attach clickOutside(() => (open = false))} class="dropdown">Dropdown content</div>
{/if}
```

### Intersection Observer

```svelte
<script>
	function inView(callback: (visible: boolean) => void) {
		return (element: HTMLElement) => {
			const observer = new IntersectionObserver(([entry]) => callback(entry.isIntersecting));
			observer.observe(element);
			return () => observer.disconnect();
		};
	}

	let visible = $state(false);
</script>

<div {@attach inView((v) => (visible = v))}>
	{visible ? 'In view!' : 'Scroll to see me'}
</div>
```

### Resize Observer

```svelte
<script>
	function observeResize(callback: (entry: ResizeObserverEntry) => void) {
		return (element: HTMLElement) => {
			const observer = new ResizeObserver(([entry]) => callback(entry));
			observer.observe(element);
			return () => observer.disconnect();
		};
	}

	let width = $state(0);
	let height = $state(0);
</script>

<div
	{@attach observeResize((entry) => {
		width = entry.contentRect.width;
		height = entry.contentRect.height;
	})}
>
	{width} x {height}
</div>
```

---

**Next:** [22. Migration from Svelte 4](./22-MigrationFromSvelte4.md)
