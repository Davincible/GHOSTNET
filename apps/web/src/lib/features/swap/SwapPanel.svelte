<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { Button } from '$lib/ui/primitives';
	import { Stack } from '$lib/ui/layout';
	import TokenInput from './TokenInput.svelte';
	import SwapDetails from './SwapDetails.svelte';
	import { createSwapStore } from './store.svelte';

	const swap = createSwapStore();

	let isSuccess = $derived(swap.status === 'success');
	let isError = $derived(swap.status === 'error');
	let isSubmitting = $derived(swap.status === 'submitting');

	/** Determine the Box border color based on status */
	let borderColor = $derived.by(() => {
		if (isSuccess) return 'bright' as const;
		if (isError) return 'red' as const;
		return 'default' as const;
	});

	/** Determine the button variant */
	let buttonVariant = $derived.by(() => {
		if (isError) return 'danger' as const;
		if (swap.canSwap) return 'primary' as const;
		return 'secondary' as const;
	});
</script>

<Box title="ACQUIRE $DATA" {borderColor}>
	<Stack gap={4}>
		<!-- Input: FROM token -->
		<TokenInput
			label="From"
			value={swap.inputAmount}
			oninput={(v) => swap.setInputAmount(v)}
			token={swap.inputToken}
			tokens={swap.availableTokens}
			ontokenchange={(t) => swap.setInputToken(t)}
			balance={swap.inputBalance}
			showMax
			onmax={() => swap.setMaxInput()}
		/>

		<!-- Direction indicator -->
		<div class="direction-row">
			<span class="direction-icon">|</span>
			<span class="direction-icon">v</span>
		</div>

		<!-- Output: TO $DATA -->
		<TokenInput
			label="To"
			value={swap.outputDisplay}
			token={swap.outputToken}
			balance={swap.outputBalance}
			readonly
			tokenFixed
		/>

		<!-- Execute button -->
		<Button
			variant={buttonVariant}
			fullWidth
			disabled={!swap.canSwap}
			loading={isSubmitting}
			onclick={() => swap.executeSwap()}
		>
			{swap.buttonLabel}
		</Button>

		<!-- Error message -->
		{#if isError && swap.errorMessage}
			<div class="error-message">{swap.errorMessage}</div>
		{/if}

		<!-- Success flash -->
		{#if isSuccess}
			<div class="success-message">SWAP EXECUTED SUCCESSFULLY</div>
		{/if}

		<!-- Quote details -->
		<SwapDetails
			quote={swap.quote}
			slippage={swap.slippage}
			onslippagechange={(v) => swap.setSlippage(v)}
			inputSymbol={swap.inputToken.symbol}
			outputSymbol={swap.outputToken.symbol}
		/>
	</Stack>
</Box>

<style>
	.direction-row {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0;
		line-height: 1;
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		user-select: none;
		padding: var(--space-0-5, 2px) 0;
	}

	.direction-icon {
		line-height: 0.8;
	}

	.error-message {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-red);
		letter-spacing: var(--tracking-wider);
		text-align: center;
		padding: var(--space-1);
		background: var(--color-red-glow);
		border: 1px solid var(--color-red-dim);
	}

	.success-message {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-accent);
		letter-spacing: var(--tracking-wider);
		text-align: center;
		padding: var(--space-1);
		background: var(--color-accent-glow);
		border: 1px solid var(--color-accent-dim);
		animation: flash-success 0.3s ease-out;
	}

	@keyframes flash-success {
		0% {
			opacity: 0;
			transform: scale(0.98);
		}
		100% {
			opacity: 1;
			transform: scale(1);
		}
	}
</style>
