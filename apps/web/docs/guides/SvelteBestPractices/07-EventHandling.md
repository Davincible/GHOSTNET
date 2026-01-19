# 7. Event Handling

## New Syntax: `on` Prefix

Svelte 5 uses standard DOM event attributes:

```svelte
<!-- Svelte 4 -->
<button on:click={handleClick}>Click</button>
<input on:input={handleInput} />
<form on:submit|preventDefault={handleSubmit}>

<!-- Svelte 5 -->
<button onclick={handleClick}>Click</button>
<input oninput={handleInput} />
<form onsubmit={handleSubmit}>
```

## Inline Handlers

```svelte
<script>
  let count = $state(0);
</script>

<!-- Simple inline -->
<button onclick={() => count++}>Increment</button>

<!-- With event object -->
<button onclick={(e) => {
  console.log(e.clientX, e.clientY);
  count++;
}}>Click</button>

<!-- Multiple statements -->
<button onclick={() => {
  count++;
  saveToServer(count);
}}>Save</button>
```

## Event Modifiers → Manual Handling

Svelte 5 removes modifiers. Handle manually:

```svelte
<script>
  // preventDefault
  function handleSubmit(e: SubmitEvent) {
    e.preventDefault();
    // form logic
  }
  
  // stopPropagation
  function handleClick(e: MouseEvent) {
    e.stopPropagation();
    // click logic
  }
  
  // once - use { once: true } option
  let button: HTMLButtonElement;
  $effect(() => {
    button?.addEventListener('click', handleOnce, { once: true });
  });
  
  // passive
  $effect(() => {
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  });
  
  // capture
  function handleCapture(e: Event) {
    // Use capture phase listener
  }
</script>

<form onsubmit={handleSubmit}>...</form>
<div onclick={handleClick}>...</div>
<button bind:this={button}>Once only</button>
```

## Custom Events via Callbacks

```svelte
<!-- Child.svelte -->
<script lang="ts">
  interface Props {
    onSelect?: (item: Item) => void;
    onChange?: (value: string) => void;
    onSubmit?: (data: FormData) => Promise<void>;
  }
  
  let { onSelect, onChange, onSubmit }: Props = $props();
  
  function handleItemClick(item: Item) {
    onSelect?.(item);
  }
</script>

<button onclick={() => onSelect?.({ id: 1, name: 'Item' })}>
  Select
</button>

<!-- Parent.svelte -->
<Child 
  onSelect={(item) => selectedItem = item}
  onChange={(value) => console.log(value)}
/>
```

## Event Types

```svelte
<script lang="ts">
  function handleClick(e: MouseEvent) {
    console.log(e.clientX, e.clientY);
  }
  
  function handleInput(e: Event & { currentTarget: HTMLInputElement }) {
    console.log(e.currentTarget.value);
  }
  
  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter') {
      submit();
    }
  }
  
  function handleSubmit(e: SubmitEvent) {
    e.preventDefault();
    const form = e.currentTarget as HTMLFormElement;
    const data = new FormData(form);
  }
  
  // Custom event type helper
  type FormInputEvent = Event & { currentTarget: HTMLInputElement };
  
  function handleFormInput(e: FormInputEvent) {
    console.log(e.currentTarget.name, e.currentTarget.value);
  }
</script>
```

## Event Delegation

```svelte
<script>
  let items = $state(['A', 'B', 'C']);
  
  function handleClick(e: MouseEvent) {
    const target = e.target as HTMLElement;
    const button = target.closest('button[data-action]');
    
    if (button) {
      const action = button.dataset.action;
      const index = Number(button.dataset.index);
      
      if (action === 'delete') {
        items = items.filter((_, i) => i !== index);
      }
    }
  }
</script>

<!-- Single handler for all buttons -->
<div onclick={handleClick}>
  {#each items as item, i}
    <div class="item">
      {item}
      <button data-action="delete" data-index={i}>Delete</button>
    </div>
  {/each}
</div>
```

## Forwarding Events

```svelte
<!-- Button.svelte -->
<script lang="ts">
  import type { HTMLButtonAttributes } from 'svelte/elements';
  
  interface Props extends HTMLButtonAttributes {
    variant?: 'primary' | 'secondary';
  }
  
  let { variant = 'primary', children, ...rest }: Props = $props();
</script>

<!-- Events pass through via ...rest -->
<button class="btn btn-{variant}" {...rest}>
  {@render children?.()}
</button>

<!-- Usage: onclick passes through -->
<Button onclick={handleClick} variant="primary">
  Click Me
</Button>
```

---

**Next:** [8. Lifecycle in Svelte 5](./08-LifecycleInSvelte5.md)
