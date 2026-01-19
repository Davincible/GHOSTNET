# 19. Component Composition

## Compound Components

```svelte
<!-- Tabs/index.ts -->
export { default as Tabs } from './Tabs.svelte';
export { default as TabList } from './TabList.svelte';
export { default as Tab } from './Tab.svelte';
export { default as TabPanel } from './TabPanel.svelte';

<!-- Tabs.svelte -->
<script lang="ts">
  import { setContext } from 'svelte';
  import type { Snippet } from 'svelte';
  
  interface Props {
    value?: string;
    children: Snippet;
  }
  
  let { value = $bindable(''), children }: Props = $props();
  
  setContext('tabs', {
    get value() { return value; },
    set(v: string) { value = v; }
  });
</script>

<div class="tabs">
  {@render children()}
</div>

<!-- Tab.svelte -->
<script lang="ts">
  import { getContext } from 'svelte';
  
  interface Props {
    value: string;
    children: Snippet;
  }
  
  let { value, children }: Props = $props();
  const tabs = getContext<{ value: string; set(v: string): void }>('tabs');
  
  const isActive = $derived(tabs.value === value);
</script>

<button 
  class="tab" 
  class:active={isActive}
  onclick={() => tabs.set(value)}
>
  {@render children()}
</button>

<!-- Usage -->
<Tabs bind:value={activeTab}>
  <TabList>
    <Tab value="one">Tab 1</Tab>
    <Tab value="two">Tab 2</Tab>
  </TabList>
  
  <TabPanel value="one">Content 1</TabPanel>
  <TabPanel value="two">Content 2</TabPanel>
</Tabs>
```

## Render Props Pattern

```svelte
<!-- Disclosure.svelte -->
<script lang="ts">
  import type { Snippet } from 'svelte';
  
  interface Props {
    children: Snippet<[{
      isOpen: boolean;
      toggle: () => void;
      open: () => void;
      close: () => void;
    }]>;
  }
  
  let { children }: Props = $props();
  let isOpen = $state(false);
  
  function toggle() { isOpen = !isOpen; }
  function open() { isOpen = true; }
  function close() { isOpen = false; }
</script>

{@render children({ isOpen, toggle, open, close })}

<!-- Usage -->
<Disclosure>
  {#snippet children({ isOpen, toggle })}
    <button onclick={toggle}>
      {isOpen ? 'Hide' : 'Show'} Details
    </button>
    
    {#if isOpen}
      <div class="panel">
        Secret content here
      </div>
    {/if}
  {/snippet}
</Disclosure>
```

## Polymorphic Components

```svelte
<!-- Box.svelte -->
<script lang="ts">
  import type { Snippet } from 'svelte';
  
  interface Props {
    as?: keyof HTMLElementTagNameMap;
    children?: Snippet;
    [key: string]: unknown;
  }
  
  let { as = 'div', children, ...rest }: Props = $props();
</script>

<svelte:element this={as} {...rest}>
  {@render children?.()}
</svelte:element>

<!-- Usage -->
<Box as="article" class="card">
  <Box as="header">Title</Box>
  <Box as="p">Content</Box>
</Box>
```

## Higher-Order Components

```svelte
<!-- withLoading.svelte -->
<script lang="ts">
  import type { Component } from 'svelte';
  
  interface Props {
    component: Component<any>;
    loading: boolean;
    [key: string]: unknown;
  }
  
  let { component: Inner, loading, ...props }: Props = $props();
</script>

{#if loading}
  <div class="loading">Loading...</div>
{:else}
  <Inner {...props} />
{/if}

<!-- Usage -->
<WithLoading 
  component={UserProfile} 
  loading={isLoading}
  user={userData}
/>
```

---

**Next:** [20. Animations & Transitions](./20-AnimationsAndTransitions.md)
