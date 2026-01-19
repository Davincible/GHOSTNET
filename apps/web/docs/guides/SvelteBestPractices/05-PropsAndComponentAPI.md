# 5. $props & Component API

## Basic Props

```svelte
<!-- Greeting.svelte -->
<script>
  let { name, greeting = 'Hello' } = $props();
</script>

<p>{greeting}, {name}!</p>

<!-- Usage -->
<Greeting name="Alice" />
<Greeting name="Bob" greeting="Hi" />
```

## TypeScript Props

```svelte
<script lang="ts">
  // Inline type annotation
  let { 
    name, 
    age = 18,
    active = true 
  }: { 
    name: string; 
    age?: number;
    active?: boolean;
  } = $props();
</script>
```

## Interface Props (Recommended)

```svelte
<script lang="ts">
  interface Props {
    /** User's display name */
    name: string;
    /** User's age (defaults to 18) */
    age?: number;
    /** Callback when user clicks */
    onClick?: (name: string) => void;
    /** Child content */
    children?: import('svelte').Snippet;
  }
  
  let { name, age = 18, onClick, children }: Props = $props();
</script>
```

## $bindable() - Two-Way Binding

```svelte
<!-- TextInput.svelte -->
<script lang="ts">
  interface Props {
    value?: string;
    placeholder?: string;
  }
  
  let { 
    value = $bindable(''),  // Can be bound by parent
    placeholder = '' 
  }: Props = $props();
</script>

<input 
  bind:value 
  {placeholder}
/>

<!-- Usage -->
<script>
  let searchQuery = $state('');
</script>

<TextInput bind:value={searchQuery} placeholder="Search..." />
```

## Bindable with Fallback

```svelte
<script lang="ts">
  interface Props {
    open?: boolean;
  }
  
  // If parent doesn't bind, starts as false
  // If parent binds, uses parent's value
  let { open = $bindable(false) }: Props = $props();
</script>

<dialog {open}>
  <button onclick={() => open = false}>Close</button>
</dialog>
```

## Rest Props (Spread)

```svelte
<script lang="ts">
  import type { HTMLButtonAttributes } from 'svelte/elements';
  
  interface Props extends HTMLButtonAttributes {
    variant?: 'primary' | 'secondary' | 'danger';
    loading?: boolean;
  }
  
  let { 
    variant = 'primary', 
    loading = false,
    disabled,
    children,
    ...rest  // All other HTML button attributes
  }: Props = $props();
</script>

<button 
  class="btn btn-{variant}"
  class:loading
  disabled={disabled || loading}
  {...rest}
>
  {#if loading}
    <Spinner />
  {/if}
  {@render children?.()}
</button>

<!-- Usage: all button attrs pass through -->
<Button 
  variant="primary" 
  type="submit" 
  aria-label="Save" 
  onclick={handleClick}
>
  Save
</Button>
```

## Renamed Props (Reserved Words)

```svelte
<script lang="ts">
  // 'class' is reserved in JS
  let { 
    class: className = '',
    for: htmlFor,
    'aria-label': ariaLabel
  } = $props();
</script>

<label class={className} for={htmlFor} aria-label={ariaLabel}>
  <slot />
</label>
```

## $props.id() - SSR-Safe Unique IDs

```svelte
<script lang="ts">
  interface Props {
    label: string;
    id?: string;
  }
  
  // Generates unique ID per component instance
  // Consistent between server and client (no hydration mismatch)
  let { label, id = $props.id() }: Props = $props();
</script>

<label for={id}>{label}</label>
<input {id} />
```

## Readonly Props (Svelte 5.24+)

```svelte
<script lang="ts">
  interface Props {
    readonly data: Item[];  // TypeScript hint
    onUpdate: (items: Item[]) => void;
  }
  
  let { data, onUpdate }: Props = $props();
  
  // ❌ Don't mutate props
  // data.push(newItem);
  
  // ✅ Use callback
  function addItem(item: Item) {
    onUpdate([...data, item]);
  }
</script>
```

---

**Next:** [6. Snippets: The New Slots](./06-SnippetsTheNewSlots.md)
