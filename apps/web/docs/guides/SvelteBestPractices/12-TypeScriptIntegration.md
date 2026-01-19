# 12. TypeScript Integration

## Typing Components

```svelte
<script lang="ts">
  import type { Snippet } from 'svelte';
  import type { HTMLAttributes } from 'svelte/elements';
  
  interface Props extends HTMLAttributes<HTMLDivElement> {
    // Required props
    title: string;
    items: Item[];
    
    // Optional props with defaults
    variant?: 'primary' | 'secondary';
    disabled?: boolean;
    
    // Callbacks
    onSelect?: (item: Item) => void;
    onClose?: () => void;
    
    // Snippets
    children?: Snippet;
    header?: Snippet<[title: string]>;
    footer?: Snippet;
  }
  
  let {
    title,
    items,
    variant = 'primary',
    disabled = false,
    onSelect,
    onClose,
    children,
    header,
    footer,
    ...rest
  }: Props = $props();
</script>

<div class="container {variant}" {...rest}>
  {#if header}
    {@render header(title)}
  {:else}
    <h2>{title}</h2>
  {/if}
  
  {@render children?.()}
  
  {#if footer}
    {@render footer()}
  {/if}
</div>
```

## Generic Components

```svelte
<!-- Select.svelte -->
<script lang="ts" generics="T extends { id: string; label: string }">
  import type { Snippet } from 'svelte';
  
  interface Props {
    options: T[];
    value?: T | null;
    onSelect?: (option: T) => void;
    optionSnippet?: Snippet<[option: T]>;
  }
  
  let { 
    options, 
    value = $bindable(null), 
    onSelect,
    optionSnippet 
  }: Props = $props();
  
  function select(option: T) {
    value = option;
    onSelect?.(option);
  }
</script>

<div class="select">
  {#each options as option (option.id)}
    <button 
      class:selected={value?.id === option.id}
      onclick={() => select(option)}
    >
      {#if optionSnippet}
        {@render optionSnippet(option)}
      {:else}
        {option.label}
      {/if}
    </button>
  {/each}
</div>

<!-- Usage -->
<script lang="ts">
  interface Country {
    id: string;
    label: string;
    flag: string;
    population: number;
  }
  
  let countries: Country[] = [
    { id: 'us', label: 'United States', flag: '🇺🇸', population: 331000000 },
    { id: 'uk', label: 'United Kingdom', flag: '🇬🇧', population: 67000000 }
  ];
  
  let selected: Country | null = $state(null);
</script>

<Select 
  options={countries} 
  bind:value={selected}
  onSelect={(country) => console.log('Selected:', country.label)}
>
  {#snippet optionSnippet(country)}
    <span>{country.flag} {country.label}</span>
    <small>{country.population.toLocaleString()}</small>
  {/snippet}
</Select>
```

## Typing Events

```svelte
<script lang="ts">
  // Standard DOM events
  function handleClick(e: MouseEvent) {
    console.log(e.clientX, e.clientY);
  }
  
  // Form input with typed currentTarget
  function handleInput(e: Event & { currentTarget: HTMLInputElement }) {
    const value = e.currentTarget.value;
    const name = e.currentTarget.name;
  }
  
  // Keyboard events
  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      submit();
    }
  }
  
  // Form submit
  function handleSubmit(e: SubmitEvent) {
    e.preventDefault();
    const form = e.currentTarget as HTMLFormElement;
    const data = new FormData(form);
  }
  
  // Custom event handler type
  type InputHandler = (e: Event & { currentTarget: HTMLInputElement }) => void;
  
  const onEmailChange: InputHandler = (e) => {
    email = e.currentTarget.value;
  };
</script>
```

## Component Instance Types

```typescript
// Get component type
import type { Component, ComponentProps } from 'svelte';
import MyComponent from './MyComponent.svelte';

// Props type from component
type MyComponentProps = ComponentProps<typeof MyComponent>;

// Typing a dynamic component variable
let DynamicComponent: Component<{ name: string }>;

// Component with generics
import type { Component } from 'svelte';

type ListComponent<T> = Component<{
  items: T[];
  renderItem: (item: T) => string;
}>;
```

## Store Types

```typescript
// Type-safe store factory
interface StoreState {
  count: number;
  items: string[];
}

function createStore<T>(initial: T) {
  let state = $state<T>(initial);
  
  return {
    get state() { return state; },
    set(value: T) { state = value; },
    update(fn: (current: T) => T) { state = fn(state); }
  };
}

const store = createStore<StoreState>({ count: 0, items: [] });
```

## Module Augmentation

```typescript
// app.d.ts
declare global {
  namespace App {
    interface Locals {
      user: User | null;
    }
    
    interface PageData {
      title?: string;
    }
    
    interface Error {
      message: string;
      code?: string;
    }
  }
}

export {};
```

---

**Next:** [13. SvelteKit Data Loading](./13-SvelteKitDataLoading.md)
