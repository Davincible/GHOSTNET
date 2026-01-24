<script lang="ts">
	import { Modal } from '$lib/ui/modal';
	import { Box } from '$lib/ui/terminal';
	import { Button, Badge } from '$lib/ui/primitives';
	import { Stack, Row } from '$lib/ui/layout';
	import { LevelBadge, AmountDisplay } from '$lib/ui/data-display';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import { getToasts } from '$lib/ui/toast';
	import {
		UserRejectedRequestError,
		ContractFunctionExecutionError,
		InsufficientFundsError,
	} from 'viem';
	import { wallet } from '$lib/web3/wallet.svelte';
	import { defaultChain } from '$lib/web3/chains';

	interface Props {
		/** Whether the modal is open */
		open: boolean;
		/** Callback when modal should close */
		onclose: () => void;
	}

	let { open, onclose }: Props = $props();

	const provider = getProvider();
	const toast = getToasts();

	let isSubmitting = $state(false);

	// Transaction state for better UX
	type TxState = 'idle' | 'pending' | 'confirming' | 'success' | 'error';
	let txState = $state<TxState>('idle');
	let txHash = $state<`0x${string}` | null>(null);
	let txError = $state<string | null>(null);

	// Block explorer URL for transaction hash display
	let explorerUrl = $derived.by(() => {
		if (!txHash) return null;
		const chainId = wallet.chainId ?? defaultChain.id;
		if (chainId === 6343) return `https://megaeth-testnet-v2.blockscout.com/tx/${txHash}`;
		if (chainId === 4326) return `https://megaeth.blockscout.com/tx/${txHash}`;
		if (chainId === 31337) return null;
		return null;
	});

	// Computed values from position
	let position = $derived(provider.position);
	let totalValue = $derived.by(() => {
		if (!position) return 0n;
		return position.stakedAmount + position.earnedYield;
	});
	let yieldPercent = $derived.by(() => {
		if (!position || position.stakedAmount === 0n) return 0;
		return Number((position.earnedYield * 10000n) / position.stakedAmount) / 100;
	});

	// Calculate time in position
	let timeInPosition = $derived.by(() => {
		if (!position) return '';
		const now = Date.now();
		const entry = position.entryTimestamp;
		const diffMs = now - entry;
		const hours = Math.floor(diffMs / (1000 * 60 * 60));
		const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
		if (hours > 24) {
			const days = Math.floor(hours / 24);
			return `${days}d ${hours % 24}h`;
		}
		return `${hours}h ${minutes}m`;
	});

	// Reset transaction state when modal opens
	$effect(() => {
		if (open) {
			txState = 'idle';
			txHash = null;
			txError = null;
		}
	});

	async function handleExtract() {
		if (isSubmitting || !position) return;
		isSubmitting = true;
		txState = 'pending';
		txHash = null;
		txError = null;

		try {
			const hash = await provider.extract();

			// Store hash for display
			txHash = hash as `0x${string}`;
			txState = 'confirming';

			// Wait a moment for the UI to show the hash before closing
			await new Promise((resolve) => setTimeout(resolve, 1500));

			txState = 'success';
			toast.success('Successfully extracted');
			onclose();
		} catch (err) {
			console.error('Extract failed:', err);
			txState = 'error';

			// Provide user-friendly error messages
			// HIGH FIX: Handle InsufficientFundsError for gas issues
			if (err instanceof UserRejectedRequestError) {
				txError = 'Transaction cancelled';
				toast.error('Transaction cancelled');
			} else if (err instanceof InsufficientFundsError) {
				txError = 'Insufficient ETH for gas fees';
				toast.error('Insufficient ETH for gas fees. Please add ETH to your wallet.');
			} else if (err instanceof ContractFunctionExecutionError) {
				const msg = err.shortMessage || 'Transaction reverted';
				txError = msg;
				toast.error(msg);
			} else if (err instanceof Error) {
				if (err.message.includes('network') || err.message.includes('disconnect')) {
					txError = 'Network connection lost';
					toast.error('Network connection lost. Please check your connection.');
				} else {
					txError = err.message;
					toast.error(err.message);
				}
			} else {
				txError = 'Extract failed';
				toast.error('Extract failed. Please try again.');
			}
		} finally {
			isSubmitting = false;
		}
	}
</script>

<Modal {open} title="EXTRACT" maxWidth="sm" {onclose}>
	{#if position}
		<Stack gap={3}>
			<p class="extract-description">
				Extract your position and return to safety. All staked tokens and earned yield will be
				returned to your wallet.
			</p>

			<Box variant="single" borderColor="cyan" padding={3}>
				<Stack gap={2}>
					<Row justify="between">
						<span class="label">Level</span>
						<LevelBadge level={position.level} />
					</Row>
					<Row justify="between">
						<span class="label">Time In</span>
						<span class="value">{timeInPosition}</span>
					</Row>
					<Row justify="between">
						<span class="label">Ghost Streak</span>
						<span class="value streak">
							{position.ghostStreak > 0 ? `🔥 ${position.ghostStreak}` : '0'}
						</span>
					</Row>

					<div class="divider"></div>

					<Row justify="between">
						<span class="label">Staked</span>
						<AmountDisplay amount={position.stakedAmount} />
					</Row>
					<Row justify="between">
						<span class="label">Yield Earned</span>
						<span class="yield">
							+<AmountDisplay amount={position.earnedYield} />
							<span class="yield-percent">(+{yieldPercent.toFixed(2)}%)</span>
						</span>
					</Row>

					<div class="divider"></div>

					<Row justify="between">
						<span class="label total-label">TOTAL</span>
						<span class="total-value">
							<AmountDisplay amount={totalValue} />
						</span>
					</Row>
				</Stack>
			</Box>

			{#if position.ghostStreak > 0}
				<div class="streak-warning">
					<Badge variant="warning">STREAK RESET</Badge>
					<p>Your {position.ghostStreak}-scan ghost streak will be reset to 0.</p>
				</div>
			{/if}

			<!-- Transaction Status Display -->
			{#if txState !== 'idle'}
				<Box
					variant="single"
					borderColor={txState === 'error' ? 'red' : txState === 'success' ? 'bright' : 'cyan'}
					padding={3}
				>
					<Stack gap={2}>
						{#if txState === 'pending'}
							<Row align="center" gap={2}>
								<span class="tx-spinner"></span>
								<span class="tx-status">Waiting for wallet confirmation...</span>
							</Row>
						{:else if txState === 'confirming' && txHash}
							<Row align="center" gap={2}>
								<span class="tx-spinner"></span>
								<span class="tx-status">Confirming transaction...</span>
							</Row>
							<div class="tx-hash">
								<span class="tx-hash-label">TX:</span>
								<span class="tx-hash-value">{txHash.slice(0, 10)}...{txHash.slice(-8)}</span>
								{#if explorerUrl}
									<a
										href={explorerUrl}
										target="_blank"
										rel="noopener noreferrer"
										class="tx-explorer-link"
									>
										View on Explorer
									</a>
								{/if}
							</div>
						{:else if txState === 'error' && txError}
							<Row align="center" gap={2}>
								<span class="tx-error-icon">!</span>
								<span class="tx-error">{txError}</span>
							</Row>
						{/if}
					</Stack>
				</Box>
			{/if}

			<Row justify="end" gap={2}>
				<Button variant="ghost" onclick={onclose} disabled={isSubmitting}>Cancel</Button>
				<Button
					variant="primary"
					onclick={handleExtract}
					loading={isSubmitting}
					disabled={isSubmitting}
				>
					{#if txState === 'pending'}
						CONFIRM IN WALLET
					{:else if txState === 'confirming'}
						CONFIRMING...
					{:else}
						CONFIRM EXTRACT
					{/if}
				</Button>
			</Row>
		</Stack>
	{:else}
		<Stack gap={3}>
			<p class="no-position">You don't have an active position to extract.</p>
			<Row justify="end">
				<Button variant="ghost" onclick={onclose}>Close</Button>
			</Row>
		</Stack>
	{/if}
</Modal>

<style>
	.extract-description {
		color: var(--color-green-mid);
		font-size: var(--text-sm);
		line-height: var(--leading-relaxed);
	}

	.label {
		color: var(--color-green-dim);
		font-size: var(--text-sm);
	}

	.value {
		color: var(--color-green-bright);
		font-size: var(--text-sm);
	}

	.streak {
		color: var(--color-amber);
	}

	.yield {
		color: var(--color-profit);
		font-size: var(--text-sm);
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.yield-percent {
		color: var(--color-green-dim);
		font-size: var(--text-xs);
	}

	.total-label {
		color: var(--color-green-bright);
		font-weight: var(--font-bold);
	}

	.total-value {
		color: var(--color-cyan);
		font-weight: var(--font-bold);
	}

	.divider {
		height: 1px;
		background: var(--color-bg-tertiary);
		margin: var(--space-1) 0;
	}

	.streak-warning {
		display: flex;
		align-items: flex-start;
		gap: var(--space-2);
		padding: var(--space-2);
		background: rgba(var(--color-amber-rgb), 0.1);
	}

	.streak-warning p {
		color: var(--color-amber);
		font-size: var(--text-sm);
	}

	.no-position {
		color: var(--color-green-dim);
		text-align: center;
		padding: var(--space-4);
	}

	/* Transaction Status */
	.tx-spinner {
		display: inline-block;
		width: 16px;
		height: 16px;
		border: 2px solid var(--color-cyan);
		border-top-color: transparent;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.tx-status {
		color: var(--color-cyan);
		font-size: var(--text-sm);
	}

	.tx-hash {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		font-size: var(--text-xs);
		flex-wrap: wrap;
	}

	.tx-hash-label {
		color: var(--color-green-dim);
	}

	.tx-hash-value {
		color: var(--color-green-bright);
		font-family: var(--font-mono);
	}

	.tx-explorer-link {
		color: var(--color-cyan);
		text-decoration: none;
		border-bottom: 1px solid transparent;
	}

	.tx-explorer-link:hover {
		border-bottom-color: var(--color-cyan);
	}

	.tx-error-icon {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 18px;
		height: 18px;
		background: var(--color-red);
		color: var(--color-bg-primary);
		font-weight: var(--font-bold);
		font-size: var(--text-xs);
	}

	.tx-error {
		color: var(--color-red);
		font-size: var(--text-sm);
	}
</style>
