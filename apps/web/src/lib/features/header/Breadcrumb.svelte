<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';

	interface Crumb {
		label: string;
		href?: string;
	}

	interface Props {
		/** Breadcrumb trail, e.g. [{ label: 'NETWORK', href: '/' }, { label: 'ARCADE', href: '/arcade' }, { label: 'HACK RUN' }] */
		path: Crumb[];
	}

	let { path }: Props = $props();

	function navigate(href: string) {
		goto(resolve(href as any));
	}
</script>

<nav class="breadcrumb-bar" aria-label="Breadcrumb">
	{#each path as crumb, i (i)}
		{#if i > 0}
			<span class="separator">/</span>
		{/if}
		{#if crumb.href && i < path.length - 1}
			<button class="crumb crumb-link" onclick={() => navigate(crumb.href!)}>
				{crumb.label}
			</button>
		{:else}
			<span class="crumb crumb-current">{crumb.label}</span>
		{/if}
	{/each}
</nav>

<style>
	.breadcrumb-bar {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-1-5) var(--space-4);
		background: var(--color-bg-tertiary);
		border-bottom: 1px solid var(--color-border-subtle);
		font-family: var(--font-mono);
		font-size: var(--text-2xs);
		overflow-x: auto;
		white-space: nowrap;
	}

	.separator {
		color: var(--color-border-default);
	}

	.crumb {
		letter-spacing: var(--tracking-wider);
	}

	.crumb-link {
		background: none;
		border: none;
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
		font-size: var(--text-2xs);
		letter-spacing: var(--tracking-wider);
		cursor: pointer;
		padding: 0;
		transition: color 0.15s;
	}

	.crumb-link:hover {
		color: var(--color-accent);
	}

	.crumb-current {
		color: var(--color-text-secondary);
	}

	@media (max-width: 640px) {
		.breadcrumb-bar {
			padding: var(--space-1) var(--space-2);
		}
	}
</style>
