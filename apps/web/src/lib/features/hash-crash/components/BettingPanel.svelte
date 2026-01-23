<script lang="ts">
	import Button from '$lib/ui/primitives/Button.svelte';
	import Box from '$lib/ui/terminal/Box.svelte';
	import { MIN_BET, MAX_BET, formatMultiplier } from '../store.svelte';

	interface Props {
		/** Whether betting is allowed */
		canBet: boolean;
		/** Whether cash out is allowed */
		canCashOut: boolean;
		/** Current multiplier */
		multiplier: number;
		/** Potential payout if cashed out now */
		potentialPayout: bigint;
		/** Player's current bet amount */
		currentBet: bigint | null;
		/** Time remaining display */
		timeDisplay: string;
		/** Whether in critical time */
		isCritical: boolean;
		/** Loading state */
		isLoading: boolean;
		/** Callback when bet is placed */
		onPlaceBet: (amount: bigint, autoCashOut?: number) => void;
		/** Callback when cash out is triggered */
		onCashOut: () => void;
	}

	let {
		canBet,
		canCashOut,
		multiplier,
		potentialPayout,
		currentBet,
		timeDisplay,
		isCritical,
		isLoading,
		onPlaceBet,
		onCashOut
	}: Props = $props();

	// Local state for bet input
	let betAmount = $state('100');
	let autoCashOutEnabled = $state(false);
	let autoCashOutValue = $state('2.00');

	// Quick bet amounts
	const quickBets = [10n, 50n, 100n, 500n, 1000n];

	// Convert bet string to bigint (in wei)
	function parseBet(value: string): bigint {
		const num = parseFloat(value);
		if (isNaN(num) || num <= 0) return 0n;
		return BigInt(Math.floor(num)) * 10n ** 18n;
	}

	// Validate bet amount
	let betWei = $derived(parseBet(betAmount));
	let isValidBet = $derived(betWei >= MIN_BET && betWei <= MAX_BET);

	// Format bigint to display
	function formatData(wei: bigint): string {
		return (Number(wei) / 1e18).toFixed(0);
	}

	// Handle bet submission
	function handlePlaceBet() {
		if (!canBet || !isValidBet) return;

		const autoCashOut = autoCashOutEnabled ? parseFloat(autoCashOutValue) : undefined;
		onPlaceBet(betWei, autoCashOut);
	}

	// Set bet from quick bet button
	function setQuickBet(amount: bigint) {
		betAmount = formatData(amount);
	}
</script>

<Box title="Your Bet" variant="single" borderColor="default">
	<div class="betting-panel">
		{#if canBet}
			<!-- Betting Phase UI -->
			<div class="countdown" class:critical={isCritical}>
				<span class="countdown-label">BETTING CLOSES IN</span>
				<span class="countdown-value">{timeDisplay}</span>
			</div>

			<div class="bet-input-row">
				<label class="input-label" for="bet-amount">BET AMOUNT</label>
				<div class="input-wrapper">
					<input
						id="bet-amount"
						type="text"
						inputmode="numeric"
						class="bet-input"
						bind:value={betAmount}
						placeholder="100"
					/>
					<span class="input-suffix">$DATA</span>
				</div>
			</div>

			<div class="quick-bets">
				{#each quickBets as amount}
					<button
						type="button"
						class="quick-bet-btn"
						onclick={() => setQuickBet(amount)}
					>
						{formatData(amount)}
					</button>
				{/each}
			</div>

			<div class="auto-cashout">
				<label class="checkbox-label">
					<input type="checkbox" bind:checked={autoCashOutEnabled} />
					<span>Auto cash out at</span>
				</label>
				<input
					type="text"
					inputmode="decimal"
					class="auto-input"
					bind:value={autoCashOutValue}
					disabled={!autoCashOutEnabled}
					placeholder="2.00"
				/>
				<span class="auto-suffix">x</span>
			</div>

			<Button
				variant="primary"
				size="lg"
				fullWidth
				disabled={!isValidBet}
				loading={isLoading}
				onclick={handlePlaceBet}
			>
				PLACE BET
			</Button>

			{#if !isValidBet && betAmount !== ''}
				<p class="error-text">Bet must be 10-1000 $DATA</p>
			{/if}
		{:else if canCashOut}
			<!-- Active Game UI -->
			<div class="active-bet">
				<div class="bet-info">
					<span class="label">YOUR BET</span>
					<span class="value">{currentBet ? formatData(currentBet) : '0'} $DATA</span>
				</div>
				<div class="bet-info potential">
					<span class="label">POTENTIAL WIN</span>
					<span class="value">{formatData(potentialPayout)} $DATA</span>
				</div>
			</div>

			<Button
				variant="primary"
				size="lg"
				fullWidth
				loading={isLoading}
				onclick={onCashOut}
			>
				CASH OUT @ {formatMultiplier(multiplier)}
			</Button>
		{:else if currentBet}
			<!-- Cashed out or crashed -->
			<div class="result-display">
				<div class="bet-info">
					<span class="label">YOUR BET</span>
					<span class="value">{formatData(currentBet)} $DATA</span>
				</div>
				<div class="waiting">
					<span>Waiting for next round...</span>
				</div>
			</div>
		{:else}
			<!-- Waiting for betting phase -->
			<div class="waiting-phase">
				<p>Waiting for next round...</p>
			</div>
		{/if}
	</div>
</Box>

<style>
	.betting-panel {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	/* Countdown */
	.countdown {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
	}

	.countdown-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.countdown-value {
		font-size: var(--text-2xl);
		font-weight: var(--font-bold);
		font-family: var(--font-mono);
		color: var(--color-text-primary);
	}

	.countdown.critical .countdown-value {
		color: var(--color-red);
		animation: pulse-text 0.5s ease-in-out infinite;
	}

	@keyframes pulse-text {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.5;
		}
	}

	/* Bet Input */
	.bet-input-row {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.input-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.input-wrapper {
		display: flex;
		align-items: center;
		background: var(--color-bg-void);
		border: var(--border-width) solid var(--color-border-default);
	}

	.bet-input {
		flex: 1;
		background: transparent;
		border: none;
		padding: var(--space-3);
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		color: var(--color-text-primary);
	}

	.bet-input:focus {
		outline: none;
	}

	.input-suffix {
		padding-right: var(--space-3);
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
	}

	/* Quick Bets */
	.quick-bets {
		display: flex;
		gap: var(--space-2);
	}

	.quick-bet-btn {
		flex: 1;
		padding: var(--space-2);
		background: var(--color-bg-tertiary);
		border: var(--border-width) solid var(--color-border-subtle);
		color: var(--color-text-secondary);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		cursor: pointer;
		transition: all var(--duration-fast);
	}

	.quick-bet-btn:hover {
		border-color: var(--color-accent);
		color: var(--color-accent);
	}

	/* Auto Cash Out */
	.auto-cashout {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--color-bg-tertiary);
	}

	.checkbox-label {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		cursor: pointer;
	}

	.auto-input {
		width: 80px;
		padding: var(--space-1) var(--space-2);
		background: var(--color-bg-void);
		border: var(--border-width) solid var(--color-border-subtle);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-primary);
		text-align: right;
	}

	.auto-input:disabled {
		opacity: 0.5;
	}

	.auto-suffix {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
	}

	/* Active bet display */
	.active-bet {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
	}

	.bet-info {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.bet-info .label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.bet-info .value {
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		color: var(--color-text-primary);
	}

	.bet-info.potential .value {
		color: var(--color-accent);
	}

	/* Result display */
	.result-display {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
	}

	.waiting,
	.waiting-phase {
		text-align: center;
		color: var(--color-text-tertiary);
		padding: var(--space-4);
	}

	/* Error text */
	.error-text {
		font-size: var(--text-sm);
		color: var(--color-red);
		text-align: center;
	}
</style>
