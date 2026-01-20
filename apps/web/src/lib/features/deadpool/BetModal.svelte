<script lang="ts">
	import type { DeadPoolRound, DeadPoolSide } from '$lib/core/types';
	import { Box } from '$lib/ui/terminal';
	import { Button } from '$lib/ui/primitives';
	import { AmountDisplay } from '$lib/ui/data-display';
	import { Row, Stack } from '$lib/ui/layout';
	import OddsDisplay from './OddsDisplay.svelte';
	import PoolBars from './PoolBars.svelte';

	interface Props {
		/** Round to bet on */
		round: DeadPoolRound;
		/** User's available balance */
		balance: bigint;
		/** Callback when bet is placed */
		onPlaceBet?: (side: DeadPoolSide, amount: bigint) => void;
		/** Callback when modal is closed */
		onClose?: () => void;
		/** Loading state while placing bet */
		loading?: boolean;
	}

	let { round, balance, onPlaceBet, onClose, loading = false }: Props = $props();

	// Selected side
	let selectedSide = $state<DeadPoolSide | null>(null);

	// Bet amount (stored as string for input, converted to bigint)
	let amountInput = $state('100');
	let betAmount = $derived(() => {
		try {
			const num = parseFloat(amountInput);
			if (isNaN(num) || num <= 0) return 0n;
			return BigInt(Math.floor(num * 1e18));
		} catch {
			return 0n;
		}
	});

	// Calculate odds multipliers
	let totalPool = $derived(round.pools.under + round.pools.over);
	let odds = $derived({
		under: totalPool > 0n ? Number(totalPool) / Number(round.pools.under || 1n) : 2,
		over: totalPool > 0n ? Number(totalPool) / Number(round.pools.over || 1n) : 2
	});

	// Potential payout calculation
	let potentialPayout = $derived(() => {
		if (!selectedSide || betAmount() === 0n) return 0n;
		const multiplier = selectedSide === 'under' ? odds.under : odds.over;
		// Account for 5% rake
		const rakeMultiplier = 0.95;
		return BigInt(Math.floor(Number(betAmount()) * multiplier * rakeMultiplier));
	});

	// Validation
	let insufficientBalance = $derived(betAmount() > balance);
	let canSubmit = $derived(selectedSide !== null && betAmount() > 0n && !insufficientBalance && !loading);

	// Preset amounts
	const presets = ['50', '100', '250', '500'];

	function handleSubmit() {
		if (canSubmit && selectedSide) {
			onPlaceBet?.(selectedSide, betAmount());
		}
	}
</script>

<div class="modal-overlay" role="dialog" aria-modal="true">
	<div class="bet-modal">
		<Box variant="double" borderColor="amber" padding={4}>
		<Stack gap={4}>
			<!-- Header -->
			<Row justify="between" align="center">
				<h2 class="modal-title">PLACE BET</h2>
				<button class="close-btn" onclick={onClose} aria-label="Close">
					[X]
				</button>
			</Row>

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
				<Row gap={2}>
					<button
						class="side-btn side-under"
						class:selected={selectedSide === 'under'}
						onclick={() => (selectedSide = 'under')}
					>
						<span class="side-label">UNDER</span>
						<span class="side-odds">{odds.under.toFixed(2)}x</span>
					</button>
					<button
						class="side-btn side-over"
						class:selected={selectedSide === 'over'}
						onclick={() => (selectedSide = 'over')}
					>
						<span class="side-label">OVER</span>
						<span class="side-odds">{odds.over.toFixed(2)}x</span>
					</button>
				</Row>
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
					/>
					<span class="amount-suffix">$DATA</span>
				</div>
				<Row gap={1} class="presets">
					{#each presets as preset}
						<button class="preset-btn" onclick={() => (amountInput = preset)}>
							{preset}
						</button>
					{/each}
					<button class="preset-btn" onclick={() => (amountInput = (Number(balance) / 1e18).toFixed(0))}>
						MAX
					</button>
				</Row>
				{#if insufficientBalance}
					<span class="error-text">INSUFFICIENT BALANCE</span>
				{/if}
			</div>

			<!-- Potential payout -->
			{#if selectedSide && betAmount() > 0n}
				<div class="payout-preview">
					<span class="payout-label">POTENTIAL PAYOUT:</span>
					<span class="payout-value">
						<AmountDisplay amount={potentialPayout()} format="full" />
					</span>
					<span class="rake-note">(5% rake to burn pool)</span>
				</div>
			{/if}

			<!-- Actions -->
			<Row gap={2} justify="end">
				<Button variant="ghost" onclick={onClose}>
					CANCEL
				</Button>
				<Button variant="primary" disabled={!canSubmit} {loading} onclick={handleSubmit}>
					{loading ? 'PLACING...' : 'CONFIRM BET'}
				</Button>
			</Row>
		</Stack>
		</Box>
	</div>
</div>

<style>
	.modal-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.85);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: var(--z-modal);
		padding: var(--space-4);
	}

	.bet-modal {
		width: 100%;
		max-width: 480px;
		max-height: 90vh;
		overflow-y: auto;
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

	.side-under.selected {
		border-color: var(--color-cyan);
		background: rgba(0, 229, 204, 0.1);
	}

	.side-over.selected {
		border-color: var(--color-amber);
		background: rgba(255, 193, 7, 0.1);
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

	:global(.presets) {
		flex-wrap: wrap;
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
</style>
