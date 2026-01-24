# 6. Snippets: The New Slots

Snippets replace slots with more power and flexibility.

## Basic Snippet

```svelte
<script>
	let items = $state(['Apple', 'Banana', 'Cherry']);
</script>

{#snippet item(text, index)}
	<li class="item" data-index={index}>
		{text}
	</li>
{/snippet}

<ul>
	{#each items as text, i}
		{@render item(text, i)}
	{/each}
</ul>
```

## Children Prop (Default Content)

```svelte
<!-- Card.svelte -->
<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		children?: Snippet;
	}

	let { children }: Props = $props();
</script>

<div class="card">
	{@render children?.()}
</div>

<!-- Usage -->
<Card>
	<p>This is the card content</p>
</Card>
```

## Named Snippets as Props

```svelte
<!-- Modal.svelte -->
<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		open?: boolean;
		title?: Snippet;
		children?: Snippet;
		footer?: Snippet;
		onClose?: () => void;
	}

	let { open = false, title, children, footer, onClose }: Props = $props();
</script>

{#if open}
	<div class="modal-backdrop" onclick={onClose}>
		<div class="modal" onclick={(e) => e.stopPropagation()}>
			{#if title}
				<header class="modal-title">
					{@render title()}
				</header>
			{/if}

			<main class="modal-body">
				{@render children?.()}
			</main>

			{#if footer}
				<footer class="modal-footer">
					{@render footer()}
				</footer>
			{/if}
		</div>
	</div>
{/if}

<!-- Usage -->
<Modal open={showModal} onClose={() => (showModal = false)}>
	{#snippet title()}
		<h2>Confirm Action</h2>
	{/snippet}

	<p>Are you sure you want to proceed?</p>

	{#snippet footer()}
		<button onclick={() => (showModal = false)}>Cancel</button>
		<button onclick={confirm}>Confirm</button>
	{/snippet}
</Modal>
```

## Snippets with Parameters

```svelte
<!-- DataTable.svelte -->
<script lang="ts" generics="T">
	import type { Snippet } from 'svelte';

	interface Props<T> {
		data: T[];
		columns: Array<{ key: keyof T; label: string }>;
		row?: Snippet<[item: T, index: number]>;
		cell?: Snippet<[value: unknown, key: keyof T, item: T]>;
		empty?: Snippet;
	}

	let { data, columns, row, cell, empty }: Props<T> = $props();
</script>

<table>
	<thead>
		<tr>
			{#each columns as col}
				<th>{col.label}</th>
			{/each}
		</tr>
	</thead>
	<tbody>
		{#if data.length === 0}
			<tr>
				<td colspan={columns.length}>
					{#if empty}
						{@render empty()}
					{:else}
						No data available
					{/if}
				</td>
			</tr>
		{:else}
			{#each data as item, index}
				{#if row}
					{@render row(item, index)}
				{:else}
					<tr>
						{#each columns as col}
							<td>
								{#if cell}
									{@render cell(item[col.key], col.key, item)}
								{:else}
									{item[col.key]}
								{/if}
							</td>
						{/each}
					</tr>
				{/if}
			{/each}
		{/if}
	</tbody>
</table>

<!-- Usage -->
<DataTable
	data={users}
	columns={[
		{ key: 'name', label: 'Name' },
		{ key: 'email', label: 'Email' },
		{ key: 'role', label: 'Role' },
	]}
>
	{#snippet cell(value, key, item)}
		{#if key === 'role'}
			<span class="badge badge-{value}">{value}</span>
		{:else if key === 'email'}
			<a href="mailto:{value}">{value}</a>
		{:else}
			{value}
		{/if}
	{/snippet}

	{#snippet empty()}
		<div class="empty-state">
			<p>No users found</p>
			<button onclick={addUser}>Add User</button>
		</div>
	{/snippet}
</DataTable>
```

## Recursive Snippets

```svelte
<script lang="ts">
	interface TreeNode {
		label: string;
		children?: TreeNode[];
	}

	let { nodes }: { nodes: TreeNode[] } = $props();
</script>

{#snippet tree(items: TreeNode[], depth = 0)}
	<ul style:padding-left="{depth * 20}px">
		{#each items as node}
			<li>
				{node.label}
				{#if node.children?.length}
					{@render tree(node.children, depth + 1)}
				{/if}
			</li>
		{/each}
	</ul>
{/snippet}

{@render tree(nodes)}
```

## Snippets vs Components

```svelte
<script>
	// Snippets: Lightweight, template-only, no own lifecycle
	// Components: Full-featured, own state, lifecycle, styles

	// Use snippets for:
	// - Repeated template patterns within a component
	// - Passing render functions between components
	// - Simple customization points

	// Use components for:
	// - Reusable across files
	// - Complex logic or state
	// - Encapsulated styles
</script>

{#snippet simpleItem(text)}
	<span class="item">{text}</span>
{/snippet}

<!-- Snippet usage - fast, lightweight -->
{@render simpleItem('Hello')}

<!-- Component usage - more overhead, more features -->
<ComplexItem text="Hello" onHover={handleHover} />
```

## Conditional Snippets

```svelte
<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		variant: 'card' | 'list' | 'grid';
		children?: Snippet;
		cardHeader?: Snippet;
		listBullet?: Snippet<[index: number]>;
	}

	let { variant, children, cardHeader, listBullet }: Props = $props();
</script>

{#if variant === 'card'}
	<div class="card">
		{#if cardHeader}
			<div class="card-header">{@render cardHeader()}</div>
		{/if}
		<div class="card-body">{@render children?.()}</div>
	</div>
{:else if variant === 'list'}
	<ul class="list">
		{#if listBullet}
			{@render listBullet(0)}
		{/if}
		{@render children?.()}
	</ul>
{:else}
	<div class="grid">
		{@render children?.()}
	</div>
{/if}
```

---

**Next:** [7. Event Handling](./07-EventHandling.md)
