<script lang="ts">
	import { Modal } from '$lib/ui/modal';
	import { Box } from '$lib/ui/terminal';
	import { Button, Badge } from '$lib/ui/primitives';
	import { Stack, Row } from '$lib/ui/layout';
	import { LevelBadge, AmountDisplay } from '$lib/ui/data-display';
	import { calculateOdds } from '$lib/core/providers/mock/generators/deadpool';
	import type { DeadPoolRound, DeadPoolSide } from '$lib/core/types';

	interface Props {
		/** Whether the modal is open */
		open: boolean;
		/** The round being bet on */
		round: DeadPoolRound | null;
		/** The side selected for betting */
		side: DeadPoolSide | null;
		/** User's available balance */
		balance: bigint;
		/** Callback when modal should close */
		onclose: () => void;
		/** Callback when bet is confirmed */
		onConfirm: (amount: bigint) => void;
	}

	let { open, round, side, balance, onclose, onConfirm }: Props = $props();

	// Local state
	let amountInput = $state('');
	let isSubmitting = $state(false);

	// Parse input amount
	let parsedAmount = $derived.by(() => {
		const num = parseFloat(amountInput);
		if (isNaN(num) || num <= 0) return 0n;
		return BigInt(Math.floor(num * 1e18));
	});

	// Validation
	let minBet = 1n * 10n ** 18n; // 1 $DATA minimum
	let amountValid = $derived(parsedAmount >= minBet && parsedAmount <= balance);

	let amountError = $derived.by(() => {
		if (!amountInput) return null;
		if (parsedAmount < minBet) return 'Minimum bet is 1 Đ';
		if (parsedAmount > balance) return 'Insufficient balance';
		return null;
	});

	// Calculate potential payout
	let potentialOdds = $derived.by(() => {
		if (!round || !side || parsedAmount === 0n) return null;

		// Calculate odds with user's bet added
		const newPools = {
			under: side === 'under' ? round.pools.under + parsedAmount : round.pools.under,
			over: side === 'over' ? round.pools.over + parsedAmount : round.pools.over,
		};

		return calculateOdds(newPools);
	});

	let potentialPayout = $derived.by(() => {
		if (!potentialOdds || !side || parsedAmount === 0n) return 0n;
		const multiplier = side === 'under' ? potentialOdds.under : potentialOdds.over;
		return BigInt(Math.floor(Number(parsedAmount) * multiplier));
	});

	let potentialProfit = $derived(potentialPayout - parsedAmount);

	// Side display
	let sideLabel = $derived.by(() => {
		if (!round || !side) return '';
		if (round.type === 'whale_watch') {
			return side === 'over' ? 'YES' : 'NO';
		}
		return `${side.toUpperCase()} ${round.line}`;
	});

	// Quick amount buttons
	function setPercentage(percent: number) {
		const amount = (balance * BigInt(percent)) / 100n;
		const formatted = Number(amount / 10n ** 18n);
		amountInput = formatted.toString();
	}

	function setMax() {
		const formatted = Number(balance / 10n ** 18n);
		amountInput = formatted.toString();
	}

	// Reset on open
	$effect(() => {
		if (open) {
			amountInput = '';
			isSubmitting = false;
		}
	});

	// Submit handler
	async function handleConfirm() {
		if (!amountValid || isSubmitting) return;
		isSubmitting = true;

		try {
			onConfirm(parsedAmount);
		} finally {
			isSubmitting = false;
		}
	}
</script>

<Modal {open} title="PLACE BET" maxWidth="sm" {onclose}>
	{#if round && side}
		<Stack gap={3}>
			<!-- Round info -->
			<div class="round-info">
				<span class="round-number">#{round.roundNumber}</span>
				<p class="question">"{round.question}"</p>
				{#if round.targetLevel}
					<LevelBadge level={round.targetLevel} />
				{/if}
			</div>

			<!-- Selected side -->
			<Box variant="single" borderColor={side === 'under' ? 'cyan' : 'amber'} padding={2}>
				<Row justify="between" align="center">
					<span class="side-label">YOUR PICK</span>
					<Badge variant={side === 'under' ? 'info' : 'warning'} glow>
						{sideLabel}
					</Badge>
				</Row>
			</Box>

			<!-- Amount input -->
			<div class="amount-input-group">
				<label class="amount-label" for="bet-amount"> Bet Amount </label>
				<div class="input-wrapper">
					<input
						id="bet-amount"
						type="number"
						class="amount-input"
						class:error={amountError}
						bind:value={amountInput}
						placeholder="0.00"
						min="0"
						step="any"
					/>
					<span class="input-suffix">Đ</span>
				</div>
				{#if amountError}
					<span class="input-error">{amountError}</span>
				{/if}

				<!-- Quick buttons -->
				<div class="quick-buttons">
					<button class="quick-btn" onclick={() => setPercentage(10)}>10%</button>
					<button class="quick-btn" onclick={() => setPercentage(25)}>25%</button>
					<button class="quick-btn" onclick={() => setPercentage(50)}>50%</button>
					<button class="quick-btn" onclick={setMax}>MAX</button>
				</div>

				<div class="balance-info">
					<span>Balance: </span>
					<AmountDisplay amount={balance} />
				</div>
			</div>

			<!-- Potential payout -->
			{#if parsedAmount > 0n}
				<Box variant="single" borderColor="dim" padding={2}>
					<Stack gap={1}>
						<Row justify="between">
							<span class="payout-label">Potential Payout</span>
							<AmountDisplay amount={potentialPayout} format="full" />
						</Row>
						<Row justify="between">
							<span class="payout-label">Potential Profit</span>
							<AmountDisplay amount={potentialProfit} format="full" showSign colorize />
						</Row>
						<Row justify="between">
							<span class="payout-label">Effective Odds</span>
							<span class="odds-value">
								{potentialOdds
									? (side === 'under' ? potentialOdds.under : potentialOdds.over).toFixed(2)
									: '-'}x
							</span>
						</Row>
					</Stack>
				</Box>
			{/if}

			<!-- Rake notice -->
			<p class="rake-notice">5% rake burned on all winnings</p>

			<!-- Actions -->
			<Row justify="end" gap={2}>
				<Button variant="ghost" onclick={onclose}>Cancel</Button>
				<Button
					variant="primary"
					onclick={handleConfirm}
					disabled={!amountValid}
					loading={isSubmitting}
				>
					CONFIRM BET
				</Button>
			</Row>
		</Stack>
	{/if}
</Modal>

<style>
	.round-info {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.round-number {
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
	}

	.question {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		font-style: italic;
		line-height: var(--leading-relaxed);
	}

	.side-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.amount-input-group {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.amount-label {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
	}

	.input-wrapper {
		display: flex;
		align-items: center;
		background: var(--color-bg-primary);
		border: 1px solid var(--color-border-default);
	}

	.amount-input {
		flex: 1;
		background: transparent;
		border: none;
		color: var(--color-text-primary);
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		padding: var(--space-2);
		outline: none;
	}

	.amount-input::placeholder {
		color: var(--color-text-muted);
	}

	.amount-input.error {
		color: var(--color-loss);
	}

	.amount-input::-webkit-outer-spin-button,
	.amount-input::-webkit-inner-spin-button {
		-webkit-appearance: none;
		margin: 0;
	}

	.amount-input[type='number'] {
		appearance: textfield;
		-moz-appearance: textfield;
	}

	.input-suffix {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
		padding: 0 var(--space-2);
	}

	.input-error {
		color: var(--color-loss);
		font-size: var(--text-xs);
	}

	.quick-buttons {
		display: flex;
		gap: var(--space-1);
		margin-top: var(--space-1);
	}

	.quick-btn {
		flex: 1;
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
		color: var(--color-text-secondary);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		padding: var(--space-1);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.quick-btn:hover {
		background: var(--color-bg-elevated);
		color: var(--color-accent);
		border-color: var(--color-accent-dim);
	}

	.balance-info {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		margin-top: var(--space-1);
	}

	.payout-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
	}

	.odds-value {
		color: var(--color-accent);
		font-weight: var(--font-bold);
	}

	.rake-notice {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		text-align: center;
		font-style: italic;
	}
</style>
