<script lang="ts">
	import type { TransactionState } from '$lib/core/types/errors';
	import { Spinner } from '$lib/ui/primitives';

	interface Props {
		state: TransactionState;
		action: string;
		onDismiss?: () => void;
	}

	let { state, action, onDismiss }: Props = $props();

	// Auto-dismiss on confirmed
	$effect(() => {
		if (state.status === 'confirmed' && onDismiss) {
			const timer = setTimeout(onDismiss, 5000);
			return () => clearTimeout(timer);
		}
	});

	const statusMessages: Record<TransactionState['status'], string> = {
		idle: '',
		preparing: 'Preparing transaction...',
		awaiting_signature: 'Confirm in your wallet',
		pending: 'Transaction pending...',
		confirmed: 'Transaction confirmed!',
		failed: 'Transaction failed',
	};

	const explorerUrl = $derived(state.hash ? `https://megaexplorer.xyz/tx/${state.hash}` : null);

	const statusMessage = $derived(statusMessages[state.status]);

	const errorMessage = $derived(state.error?.message || 'An unexpected error occurred');

	// Format tx hash for display: 0x1234...abcd
	function formatHash(hash: `0x${string}`): string {
		return `${hash.slice(0, 6)}...${hash.slice(-4)}`;
	}
</script>

{#if state.status !== 'idle'}
	<div class="tx-toast tx-toast-{state.status}" role="alert" aria-live="polite">
		<!-- Icon column -->
		<span class="tx-icon">
			{#if state.status === 'preparing' || state.status === 'pending'}
				<Spinner size="sm" />
			{:else if state.status === 'awaiting_signature'}
				<!-- Wallet icon -->
				<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
					<path d="M2 6h18a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6z" />
					<path d="M2 6V4a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v2" />
					<circle cx="16" cy="13" r="2" />
				</svg>
			{:else if state.status === 'confirmed'}
				<!-- Checkmark icon -->
				<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<polyline points="20 6 9 17 4 12"></polyline>
				</svg>
			{:else if state.status === 'failed'}
				<!-- X icon -->
				<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<line x1="18" y1="6" x2="6" y2="18"></line>
					<line x1="6" y1="6" x2="18" y2="18"></line>
				</svg>
			{/if}
		</span>

		<!-- Content column -->
		<div class="tx-content">
			<span class="tx-action">{action}</span>
			<span class="tx-status">{statusMessage}</span>

			{#if state.status === 'failed' && state.error}
				<span class="tx-error">{errorMessage}</span>
				{#if state.error.recoverable}
					<span class="tx-hint">Try again or check your wallet</span>
				{/if}
			{/if}

			{#if explorerUrl && (state.status === 'pending' || state.status === 'confirmed')}
				<a href={explorerUrl} target="_blank" rel="noopener noreferrer" class="tx-hash-link">
					{formatHash(state.hash!)} ↗
				</a>
			{/if}
		</div>

		<!-- Dismiss button -->
		{#if onDismiss}
			<button class="tx-dismiss" onclick={onDismiss} aria-label="Dismiss notification">
				<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<line x1="18" y1="6" x2="6" y2="18"></line>
					<line x1="6" y1="6" x2="18" y2="18"></line>
				</svg>
			</button>
		{/if}
	</div>
{/if}

<style>
	.tx-toast {
		display: flex;
		align-items: flex-start;
		gap: var(--space-3);
		padding: var(--space-3) var(--space-4);
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-default);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		min-width: 300px;
		max-width: 400px;
		animation: toast-slide-in 0.2s ease-out;
	}

	@keyframes toast-slide-in {
		from {
			opacity: 0;
			transform: translateX(100%);
		}
		to {
			opacity: 1;
			transform: translateX(0);
		}
	}

	/* State-specific border colors */
	.tx-toast-preparing,
	.tx-toast-awaiting_signature {
		border-color: var(--color-accent-dim);
	}

	.tx-toast-pending {
		border-color: var(--color-amber);
	}

	.tx-toast-confirmed {
		border-color: var(--color-profit);
	}

	.tx-toast-failed {
		border-color: var(--color-red);
	}

	/* Icon styling */
	.tx-icon {
		flex-shrink: 0;
		width: 18px;
		height: 18px;
		display: flex;
		align-items: center;
		justify-content: center;
		margin-top: 2px;
	}

	.tx-icon svg {
		width: 100%;
		height: 100%;
	}

	.tx-toast-preparing .tx-icon,
	.tx-toast-awaiting_signature .tx-icon {
		color: var(--color-accent);
	}

	.tx-toast-pending .tx-icon {
		color: var(--color-amber);
	}

	.tx-toast-confirmed .tx-icon {
		color: var(--color-profit);
	}

	.tx-toast-failed .tx-icon {
		color: var(--color-red);
	}

	/* Content area */
	.tx-content {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		min-width: 0;
	}

	.tx-action {
		color: var(--color-text-primary);
		font-weight: var(--font-medium);
		text-transform: uppercase;
		letter-spacing: var(--tracking-wide);
	}

	.tx-status {
		color: var(--color-text-secondary);
	}

	.tx-error {
		color: var(--color-red);
		font-size: var(--text-xs);
	}

	.tx-hint {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		font-style: italic;
	}

	.tx-hash-link {
		color: var(--color-cyan);
		font-size: var(--text-xs);
		text-decoration: none;
		transition: color var(--duration-fast) var(--ease-default);
	}

	.tx-hash-link:hover {
		color: var(--color-cyan-dim);
		text-decoration: underline;
	}

	/* Dismiss button */
	.tx-dismiss {
		flex-shrink: 0;
		width: 20px;
		height: 20px;
		background: none;
		border: none;
		color: var(--color-text-tertiary);
		cursor: pointer;
		padding: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: color var(--duration-fast) var(--ease-default);
	}

	.tx-dismiss:hover {
		color: var(--color-text-primary);
	}

	.tx-dismiss svg {
		width: 14px;
		height: 14px;
	}

	/* Subtle pulse animation for awaiting signature */
	.tx-toast-awaiting_signature .tx-icon {
		animation: pulse 2s ease-in-out infinite;
	}

	@keyframes pulse {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.5;
		}
	}
</style>
