<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { HTMLAttributes } from 'svelte/elements';

	type Gap = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 8;
	type Align = 'start' | 'center' | 'end' | 'stretch';

	interface Props extends HTMLAttributes<HTMLDivElement> {
		/** Gap between items (uses spacing scale) */
		gap?: Gap;
		/** Horizontal alignment */
		align?: Align;
		children: Snippet;
	}

	let { gap = 2, align = 'stretch', children, ...restProps }: Props = $props();
</script>

<div class="stack stack-gap-{gap} stack-align-{align}" {...restProps}>
	{@render children()}
</div>

<style>
	.stack {
		display: flex;
		flex-direction: column;
	}

	/* Gap sizes */
	.stack-gap-0 {
		gap: var(--space-0);
	}
	.stack-gap-1 {
		gap: var(--space-1);
	}
	.stack-gap-2 {
		gap: var(--space-2);
	}
	.stack-gap-3 {
		gap: var(--space-3);
	}
	.stack-gap-4 {
		gap: var(--space-4);
	}
	.stack-gap-5 {
		gap: var(--space-5);
	}
	.stack-gap-6 {
		gap: var(--space-6);
	}
	.stack-gap-8 {
		gap: var(--space-8);
	}

	/* Alignment */
	.stack-align-start {
		align-items: flex-start;
	}
	.stack-align-center {
		align-items: center;
	}
	.stack-align-end {
		align-items: flex-end;
	}
	.stack-align-stretch {
		align-items: stretch;
	}
</style>
