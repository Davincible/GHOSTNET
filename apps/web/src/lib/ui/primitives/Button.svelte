<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { HTMLButtonAttributes } from 'svelte/elements';

	type Variant = 'primary' | 'secondary' | 'danger' | 'ghost';
	type Size = 'sm' | 'md' | 'lg';

	interface Props extends HTMLButtonAttributes {
		variant?: Variant;
		size?: Size;
		hotkey?: string;
		loading?: boolean;
		fullWidth?: boolean;
		children: Snippet;
	}

	let {
		variant = 'primary',
		size = 'md',
		hotkey,
		loading = false,
		fullWidth = false,
		disabled,
		children,
		...restProps
	}: Props = $props();

	// Combine disabled states
	let isDisabled = $derived(disabled || loading);
</script>

<button
	class="btn btn-{variant} btn-{size}"
	class:btn-full-width={fullWidth}
	class:btn-loading={loading}
	disabled={isDisabled}
	{...restProps}
>
	{#if loading}
		<span class="spinner" aria-hidden="true"></span>
	{/if}
	<span class="btn-content" class:btn-content-hidden={loading}>
		{@render children()}
	</span>
	{#if hotkey}
		<kbd class="hotkey">[{hotkey}]</kbd>
	{/if}
</button>

<style>
	.btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		font-family: var(--font-mono);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wider);
		text-transform: uppercase;
		border: var(--border-width) solid transparent;
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
		position: relative;
	}

	.btn:focus-visible {
		outline: 2px solid var(--color-accent);
		outline-offset: 2px;
	}

	.btn:disabled {
		cursor: not-allowed;
		opacity: 0.4;
	}

	/* Sizes */
	.btn-sm {
		padding: var(--space-1) var(--space-2);
		font-size: var(--text-xs);
	}

	.btn-md {
		padding: var(--space-2) var(--space-4);
		font-size: var(--text-sm);
	}

	.btn-lg {
		padding: var(--space-3) var(--space-6);
		font-size: var(--text-base);
	}

	/* Primary variant - Teal accent */
	.btn-primary {
		background-color: var(--color-accent);
		color: var(--color-bg-void);
		border-color: var(--color-accent);
	}

	.btn-primary:hover:not(:disabled) {
		background-color: transparent;
		color: var(--color-accent-bright);
		box-shadow: var(--shadow-glow-accent);
	}

	.btn-primary:active:not(:disabled) {
		transform: translateY(1px);
		background-color: var(--color-accent-dim);
	}

	/* Secondary variant */
	.btn-secondary {
		background-color: transparent;
		color: var(--color-text-primary);
		border-color: var(--color-border-strong);
	}

	.btn-secondary:hover:not(:disabled) {
		border-color: var(--color-accent);
		color: var(--color-accent);
		box-shadow: var(--shadow-glow-accent);
	}

	.btn-secondary:active:not(:disabled) {
		background-color: var(--color-accent-glow);
	}

	/* Danger variant */
	.btn-danger {
		background-color: transparent;
		color: var(--color-red);
		border-color: var(--color-red-dim);
	}

	.btn-danger:hover:not(:disabled) {
		background-color: var(--color-red);
		color: var(--color-bg-void);
		border-color: var(--color-red);
		box-shadow: var(--shadow-glow-red);
	}

	.btn-danger:active:not(:disabled) {
		transform: translateY(1px);
	}

	/* Ghost variant */
	.btn-ghost {
		background-color: transparent;
		color: var(--color-text-secondary);
		border-color: transparent;
	}

	.btn-ghost:hover:not(:disabled) {
		color: var(--color-text-primary);
		background-color: var(--color-bg-tertiary);
	}

	/* Full width */
	.btn-full-width {
		width: 100%;
	}

	/* Content */
	.btn-content {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
	}

	.btn-content-hidden {
		visibility: hidden;
	}

	/* Hotkey badge */
	.hotkey {
		font-size: var(--text-xs);
		opacity: 0.5;
		font-weight: var(--font-normal);
		color: inherit;
	}

	/* Loading spinner */
	.spinner {
		position: absolute;
		width: 1em;
		height: 1em;
	}

	.spinner::before {
		content: '|';
		display: block;
		animation: spin-chars 0.5s steps(4, end) infinite;
	}

	@keyframes spin-chars {
		0% {
			content: '|';
		}
		25% {
			content: '/';
		}
		50% {
			content: '-';
		}
		75% {
			content: '\\';
		}
	}

	/* Loading state */
	.btn-loading {
		pointer-events: none;
	}
</style>
