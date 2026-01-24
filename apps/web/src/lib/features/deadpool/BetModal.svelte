<script lang="ts">
	import { browser } from '$app/environment';
	import type { DeadPoolRound, DeadPoolSide } from '$lib/core/types';
	import { Box } from '$lib/ui/terminal';
	import { Button } from '$lib/ui/primitives';
	import { AmountDisplay } from '$lib/ui/data-display';
	import OddsDisplay from './OddsDisplay.svelte';
	import PoolBars from './PoolBars.svelte';

	interface Props {
		/** Whether the modal is visible */
		open: boolean;
		/** Round to bet on (can be null when closed) */
		round: DeadPoolRound | null;
		/** Pre-selected side (optional) */
		initialSide?: DeadPoolSide | null;
		/** User's available balance */
		balance: bigint;
		/** Loading state while placing bet */
		loading?: boolean;
		/** Callback when modal is closed */
		onClose?: () => void;
		/** Callback when bet is confirmed */
		onConfirm?: (side: DeadPoolSide, amount: bigint) => void;
	}

	let {
		open,
		round,
		initialSide = null,
		balance,
		loading = false,
		onClose,
		onConfirm,
	}: Props = $props();

	// Selected side - reset when modal opens with new round
	let selectedSide = $state<DeadPoolSide | null>(null);

	// Set initial side when opening with a pre-selection
	$effect(() => {
		if (open && initialSide) {
			selectedSide = initialSide;
		}
	});

	// Reset state when modal closes
	$effect(() => {
		if (!open) {
			selectedSide = null;
			amountInput = '100';
		}
	});

	// Bet amount (stored as string for input, converted to bigint)
	let amountInput = $state('100');

	const betAmount = $derived.by(() => {
		try {
			const num = parseFloat(amountInput);
			if (isNaN(num) || num <= 0) return 0n;
			return BigInt(Math.floor(num * 1e18));
		} catch {
			return 0n;
		}
	});

	// Calculate odds multipliers
	const totalPool = $derived(round ? round.pools.under + round.pools.over : 0n);
	const odds = $derived({
		under:
			round && round.pools.under > 0n && totalPool > 0n
				? Number(totalPool) / Number(round.pools.under)
				: 2,
		over:
			round && round.pools.over > 0n && totalPool > 0n
				? Number(totalPool) / Number(round.pools.over)
				: 2,
	});

	// Potential payout calculation
	const potentialPayout = $derived.by(() => {
		if (!selectedSide || betAmount === 0n) return 0n;
		const multiplier = selectedSide === 'under' ? odds.under : odds.over;
		// Account for 5% rake
		const rakeMultiplier = 0.95;
		return BigInt(Math.floor(Number(betAmount) * multiplier * rakeMultiplier));
	});

	// Validation
	const insufficientBalance = $derived(betAmount > balance);
	const canSubmit = $derived(
		selectedSide !== null && betAmount > 0n && !insufficientBalance && !loading
	);

	// Preset amounts
	const presets = ['50', '100', '250', '500'];

	function handleSubmit() {
		if (canSubmit && selectedSide) {
			onConfirm?.(selectedSide, betAmount);
		}
	}

	function handleClose() {
		onClose?.();
	}

	// Keyboard handler for escape
	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Escape') {
			handleClose();
		}
	}

	// Focus trap ref
	let modalRef = $state<HTMLDivElement | null>(null);

	// Focus modal when opened
	$effect(() => {
		if (open && modalRef && browser) {
			modalRef.focus();
		}
	});
</script>

{#if open && round}
	<div
		class="modal-overlay"
		role="dialog"
		aria-modal="true"
		aria-labelledby="bet-modal-title"
		onkeydown={handleKeydown}
		tabindex="-1"
	>
		<!-- Backdrop -->
		<button class="modal-backdrop" onclick={handleClose} aria-label="Close modal" tabindex="-1"
		></button>

		<!-- Modal content -->
		<div class="bet-modal" bind:this={modalRef} tabindex="-1">
			<Box variant="double" borderColor="amber" padding={4}>
				<div class="modal-content">
					<!-- Header -->
					<div class="modal-header">
						<h2 id="bet-modal-title" class="modal-title">PLACE BET</h2>
						<button class="close-btn" onclick={handleClose} aria-label="Close"> [X] </button>
					</div>

					<!-- Round info -->
					<div class="round-info">
						<span class="round-number">ROUND #{round.roundNumber}</span>
						<p class="round-question">{round.question}</p>
						<div class="line-display">
							<span class="line-label">LINE:</span>
							<span class="line-value">{round.line}</span>
						</div>
					</div>

					<!-- Current odds -->
					<div class="section">
						<span class="section-label">CURRENT ODDS</span>
						<OddsDisplay pools={round.pools} {odds} userBetSide={selectedSide} />
						<PoolBars pools={round.pools} width={28} />
					</div>

					<!-- Side selection -->
					<div class="section">
						<span class="section-label">SELECT SIDE</span>
						<div class="side-buttons">
							<button
								class="side-btn side-under"
								class:selected={selectedSide === 'under'}
								onclick={() => (selectedSide = 'under')}
								aria-pressed={selectedSide === 'under'}
							>
								<span class="side-label">UNDER</span>
								<span class="side-odds">{odds.under.toFixed(2)}x</span>
							</button>
							<button
								class="side-btn side-over"
								class:selected={selectedSide === 'over'}
								onclick={() => (selectedSide = 'over')}
								aria-pressed={selectedSide === 'over'}
							>
								<span class="side-label">OVER</span>
								<span class="side-odds">{odds.over.toFixed(2)}x</span>
							</button>
						</div>
					</div>

					<!-- Amount input -->
					<div class="section">
						<span class="section-label">BET AMOUNT</span>
						<div class="amount-input-wrapper">
							<input
								type="number"
								class="amount-input"
								bind:value={amountInput}
								placeholder="0"
								min="0"
								step="10"
								aria-label="Bet amount in DATA tokens"
							/>
							<span class="amount-suffix">$DATA</span>
						</div>
						<div class="presets">
							{#each presets as preset (preset)}
								<button class="preset-btn" onclick={() => (amountInput = preset)}>
									{preset}
								</button>
							{/each}
							<button
								class="preset-btn"
								onclick={() => (amountInput = (Number(balance) / 1e18).toFixed(0))}
							>
								MAX
							</button>
						</div>
						{#if insufficientBalance}
							<span class="error-text" role="alert">INSUFFICIENT BALANCE</span>
						{/if}
					</div>

					<!-- Potential payout -->
					{#if selectedSide && betAmount > 0n}
						<div class="payout-preview">
							<span class="payout-label">POTENTIAL PAYOUT:</span>
							<span class="payout-value">
								<AmountDisplay amount={potentialPayout} format="full" />
							</span>
							<span class="rake-note">(5% rake to burn pool)</span>
						</div>
					{/if}

					<!-- Actions -->
					<div class="modal-actions">
						<Button variant="ghost" onclick={handleClose}>CANCEL</Button>
						<Button variant="primary" disabled={!canSubmit} {loading} onclick={handleSubmit}>
							{loading ? 'PLACING...' : 'CONFIRM BET'}
						</Button>
					</div>
				</div>
			</Box>
		</div>
	</div>
{/if}

<style>
	.modal-overlay {
		position: fixed;
		inset: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: var(--z-modal, 1000);
		padding: var(--space-4);
	}

	.modal-backdrop {
		position: absolute;
		inset: 0;
		background: rgba(0, 0, 0, 0.85);
		border: none;
		cursor: default;
	}

	.bet-modal {
		position: relative;
		width: 100%;
		max-width: 480px;
		max-height: 90vh;
		overflow-y: auto;
		outline: none;
	}

	.modal-content {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.modal-title {
		color: var(--color-amber);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
		margin: 0;
	}

	.close-btn {
		background: none;
		border: none;
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
		font-size: var(--text-base);
		cursor: pointer;
		padding: var(--space-1);
		transition: color var(--duration-fast) var(--ease-default);
	}

	.close-btn:hover {
		color: var(--color-text-primary);
	}

	.round-info {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.round-number {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.round-question {
		color: var(--color-text-primary);
		font-size: var(--text-sm);
		margin: 0;
	}

	.line-display {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		margin-top: var(--space-1);
	}

	.line-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
	}

	.line-value {
		color: var(--color-text-primary);
		font-size: var(--text-base);
		font-weight: var(--font-bold);
	}

	.section {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.section-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.side-buttons {
		display: flex;
		gap: var(--space-2);
	}

	.side-btn {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-1);
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
		border: 2px solid var(--color-border-subtle);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
		font-family: var(--font-mono);
	}

	.side-btn:hover {
		background: var(--color-bg-elevated);
	}

	.side-btn:focus-visible {
		outline: 2px solid var(--color-accent);
		outline-offset: 2px;
	}

	.side-under.selected {
		border-color: var(--color-cyan);
		background: var(--color-cyan-glow);
	}

	.side-over.selected {
		border-color: var(--color-amber);
		background: var(--color-amber-glow);
	}

	.side-label {
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wider);
	}

	.side-under .side-label {
		color: var(--color-cyan);
	}

	.side-over .side-label {
		color: var(--color-amber);
	}

	.side-odds {
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
	}

	.amount-input-wrapper {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
	}

	.amount-input {
		flex: 1;
		background: transparent;
		border: none;
		color: var(--color-text-primary);
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		outline: none;
	}

	.amount-input::-webkit-outer-spin-button,
	.amount-input::-webkit-inner-spin-button {
		-webkit-appearance: none;
		margin: 0;
	}

	.amount-suffix {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
	}

	.presets {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-1);
	}

	.preset-btn {
		padding: var(--space-1) var(--space-2);
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-subtle);
		color: var(--color-text-secondary);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.preset-btn:hover {
		border-color: var(--color-accent);
		color: var(--color-accent);
	}

	.preset-btn:focus-visible {
		outline: 2px solid var(--color-accent);
		outline-offset: 2px;
	}

	.error-text {
		color: var(--color-loss);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.payout-preview {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--color-bg-elevated);
		border: 1px solid var(--color-profit-dim);
	}

	.payout-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
	}

	.payout-value {
		color: var(--color-profit);
		font-size: var(--text-base);
		font-weight: var(--font-bold);
	}

	.rake-note {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		margin-left: auto;
	}

	.modal-actions {
		display: flex;
		justify-content: flex-end;
		gap: var(--space-2);
	}
</style>
