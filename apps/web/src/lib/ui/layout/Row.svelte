<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { HTMLAttributes } from 'svelte/elements';

	type Gap = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 8;
	type Align = 'start' | 'center' | 'end' | 'stretch' | 'baseline';
	type Justify = 'start' | 'center' | 'end' | 'between' | 'around' | 'evenly';

	interface Props extends HTMLAttributes<HTMLDivElement> {
		/** Gap between items (uses spacing scale) */
		gap?: Gap;
		/** Vertical alignment */
		align?: Align;
		/** Horizontal distribution */
		justify?: Justify;
		/** Allow wrapping */
		wrap?: boolean;
		children: Snippet;
	}

	let {
		gap = 2,
		align = 'center',
		justify = 'start',
		wrap = false,
		children,
		...restProps
	}: Props = $props();
</script>

<div
	class="row row-gap-{gap} row-align-{align} row-justify-{justify}"
	class:row-wrap={wrap}
	{...restProps}
>
	{@render children()}
</div>

<style>
	.row {
		display: flex;
		flex-direction: row;
	}

	/* Gap sizes */
	.row-gap-0 {
		gap: var(--space-0);
	}
	.row-gap-1 {
		gap: var(--space-1);
	}
	.row-gap-2 {
		gap: var(--space-2);
	}
	.row-gap-3 {
		gap: var(--space-3);
	}
	.row-gap-4 {
		gap: var(--space-4);
	}
	.row-gap-5 {
		gap: var(--space-5);
	}
	.row-gap-6 {
		gap: var(--space-6);
	}
	.row-gap-8 {
		gap: var(--space-8);
	}

	/* Alignment */
	.row-align-start {
		align-items: flex-start;
	}
	.row-align-center {
		align-items: center;
	}
	.row-align-end {
		align-items: flex-end;
	}
	.row-align-stretch {
		align-items: stretch;
	}
	.row-align-baseline {
		align-items: baseline;
	}

	/* Justification */
	.row-justify-start {
		justify-content: flex-start;
	}
	.row-justify-center {
		justify-content: center;
	}
	.row-justify-end {
		justify-content: flex-end;
	}
	.row-justify-between {
		justify-content: space-between;
	}
	.row-justify-around {
		justify-content: space-around;
	}
	.row-justify-evenly {
		justify-content: space-evenly;
	}

	/* Wrap */
	.row-wrap {
		flex-wrap: wrap;
	}
</style>
