<script lang="ts">
	import type { SwapToken } from './types';

	interface Props {
		tokens: SwapToken[];
		selected: SwapToken;
		onselect: (token: SwapToken) => void;
		disabled?: boolean;
	}

	let { tokens, selected, onselect, disabled = false }: Props = $props();

	let open = $state(false);

	function toggle() {
		if (!disabled && tokens.length > 1) {
			open = !open;
		}
	}

	function select(token: SwapToken) {
		onselect(token);
		open = false;
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Escape') {
			open = false;
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} />

<div class="token-select" class:disabled>
	<button
		class="selected-token"
		class:open
		onclick={toggle}
		{disabled}
		aria-expanded={open}
		aria-haspopup="listbox"
	>
		<span class="token-icon">{selected.icon}</span>
		<span class="token-symbol">{selected.symbol}</span>
		{#if tokens.length > 1 && !disabled}
			<span class="chevron" class:chevron-open={open}>v</span>
		{/if}
	</button>

	{#if open}
		<div class="dropdown" role="listbox">
			{#each tokens as token (token.symbol)}
				<button
					class="dropdown-item"
					class:active={token.symbol === selected.symbol}
					onclick={() => select(token)}
					role="option"
					aria-selected={token.symbol === selected.symbol}
				>
					<span class="token-icon">{token.icon}</span>
					<span class="token-info">
						<span class="token-symbol">{token.symbol}</span>
						<span class="token-name">{token.name}</span>
					</span>
				</button>
			{/each}
		</div>
	{/if}
</div>

<style>
	.token-select {
		position: relative;
		flex-shrink: 0;
	}

	.selected-token {
		display: flex;
		align-items: center;
		gap: var(--space-1);
		padding: var(--space-1) var(--space-2);
		background: var(--color-bg-tertiary);
		border: var(--border-width) solid var(--color-border-subtle);
		color: var(--color-text-primary);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wider);
		text-transform: uppercase;
		cursor: pointer;
		transition: border-color var(--duration-fast) var(--ease-default);
	}

	.selected-token:hover:not(:disabled) {
		border-color: var(--color-accent-dim);
	}

	.selected-token.open {
		border-color: var(--color-accent);
	}

	.selected-token:disabled {
		cursor: default;
		opacity: 0.6;
	}

	.token-icon {
		color: var(--color-accent);
		font-weight: var(--font-bold);
	}

	.chevron {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		transition: transform var(--duration-fast) var(--ease-default);
	}

	.chevron-open {
		transform: rotate(180deg);
	}

	.dropdown {
		position: absolute;
		top: calc(100% + var(--space-1));
		right: 0;
		z-index: 50;
		min-width: 160px;
		background: var(--color-bg-primary);
		border: var(--border-width) solid var(--color-border-default);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
	}

	.dropdown-item {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		width: 100%;
		padding: var(--space-2) var(--space-3);
		background: transparent;
		border: none;
		color: var(--color-text-primary);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		text-align: left;
		cursor: pointer;
		transition: background var(--duration-fast) var(--ease-default);
	}

	.dropdown-item:hover {
		background: var(--color-bg-tertiary);
	}

	.dropdown-item.active {
		color: var(--color-accent);
	}

	.token-info {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.token-name {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		text-transform: none;
		letter-spacing: normal;
	}

	.disabled {
		pointer-events: none;
	}
</style>
