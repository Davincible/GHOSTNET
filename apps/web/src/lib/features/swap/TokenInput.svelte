<script lang="ts">
	import type { SwapToken } from './types';
	import TokenSelect from './TokenSelect.svelte';

	interface Props {
		/** Label above the input */
		label: string;
		/** Current input value (string for controlled input) */
		value: string;
		/** Called when user types */
		oninput?: (value: string) => void;
		/** Selected token */
		token: SwapToken;
		/** Available tokens for the selector */
		tokens?: SwapToken[];
		/** Called when token is changed */
		ontokenchange?: (token: SwapToken) => void;
		/** Balance to display */
		balance?: number;
		/** Whether to show the MAX button */
		showMax?: boolean;
		/** Called when MAX is clicked */
		onmax?: () => void;
		/** Whether the input is read-only (output side) */
		readonly?: boolean;
		/** Whether the token selector is disabled */
		tokenFixed?: boolean;
	}

	let {
		label,
		value,
		oninput,
		token,
		tokens = [],
		ontokenchange,
		balance,
		showMax = false,
		onmax,
		readonly = false,
		tokenFixed = false,
	}: Props = $props();

	let inputEl: HTMLInputElement | undefined = $state();

	function handleInput(event: Event) {
		const target = event.target as HTMLInputElement;
		oninput?.(target.value);
	}

	function handleFocus() {
		inputEl?.select();
	}
</script>

<div class="token-input" class:readonly>
	<div class="input-header">
		<span class="input-label">{label}</span>
		{#if balance !== undefined}
			<span class="input-balance">
				BAL: {balance.toLocaleString('en-US', { maximumFractionDigits: 4 })}
				{#if showMax && !readonly}
					<button class="max-btn" onclick={onmax}>MAX</button>
				{/if}
			</span>
		{/if}
	</div>

	<div class="input-row">
		<input
			bind:this={inputEl}
			type="text"
			inputmode="decimal"
			autocomplete="off"
			placeholder="0.00"
			{value}
			{readonly}
			oninput={handleInput}
			onfocus={handleFocus}
			class="amount-input"
			class:has-value={value !== ''}
		/>
		<TokenSelect
			{tokens}
			selected={token}
			onselect={(t) => ontokenchange?.(t)}
			disabled={tokenFixed || tokens.length <= 1}
		/>
	</div>
</div>

<style>
	.token-input {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		padding: var(--space-2) var(--space-3);
		background: var(--color-bg-primary);
		border: var(--border-width) solid var(--color-border-subtle);
		transition: border-color var(--duration-fast) var(--ease-default);
	}

	.token-input:focus-within:not(.readonly) {
		border-color: var(--color-accent-dim);
	}

	.input-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.input-label {
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
		text-transform: uppercase;
	}

	.input-balance {
		display: flex;
		align-items: center;
		gap: var(--space-1);
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
	}

	.max-btn {
		padding: 0 var(--space-1);
		background: transparent;
		border: var(--border-width) solid var(--color-accent-dim);
		color: var(--color-accent);
		font-family: var(--font-mono);
		font-size: 10px;
		letter-spacing: var(--tracking-wider);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.max-btn:hover {
		background: var(--color-accent-glow);
		border-color: var(--color-accent);
	}

	.input-row {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.amount-input {
		flex: 1;
		min-width: 0;
		padding: var(--space-1) 0;
		background: transparent;
		border: none;
		outline: none;
		color: var(--color-text-primary);
		font-family: var(--font-mono);
		font-size: var(--text-xl);
		font-weight: var(--font-medium);
		font-variant-numeric: tabular-nums;
		caret-color: var(--color-accent);
	}

	.amount-input::placeholder {
		color: var(--color-text-muted, var(--color-text-tertiary));
		opacity: 0.4;
	}

	.amount-input:read-only {
		cursor: default;
	}

	.readonly .amount-input {
		color: var(--color-accent);
	}

	.readonly {
		background: var(--color-bg-secondary);
		border-color: transparent;
	}
</style>
