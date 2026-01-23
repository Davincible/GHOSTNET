<script lang="ts">
	import Button from '$lib/ui/primitives/Button.svelte';
	import Box from '$lib/ui/terminal/Box.svelte';
	import {
		MIN_BET,
		MAX_BET,
		MIN_TARGET,
		MAX_TARGET,
		formatMultiplier,
		calculateWinProbability,
	} from '../store.svelte';

	interface Props {
		/** Whether betting is allowed */
		canBet: boolean;
		/** Current round phase */
		phase: 'idle' | 'betting' | 'locked' | 'revealed' | 'animating' | 'settled' | null;
		/** Current animated multiplier */
		multiplier: number;
		/** Player's target multiplier (if bet placed) */
		targetMultiplier: number | null;
		/** Player's bet amount */
		currentBet: bigint | null;
		/** Potential payout based on bet x target */
		potentialPayout: bigint;
		/** Player's result */
		playerResult: 'pending' | 'won' | 'lost';
		/** Actual crash point (after reveal) */
		crashPoint: number | null;
		/** Time remaining display */
		timeDisplay: string;
		/** Whether in critical time */
		isCritical: boolean;
		/** Loading state */
		isLoading: boolean;
		/** Callback when bet is placed */
		onPlaceBet: (amount: bigint, targetMultiplier: number) => void;
	}

	let {
		canBet,
		phase,
		multiplier,
		targetMultiplier,
		currentBet,
		potentialPayout,
		playerResult,
		crashPoint,
		timeDisplay,
		isCritical,
		isLoading,
		onPlaceBet,
	}: Props = $props();

	// Local state for bet input
	let betAmount = $state('100');
	let targetValue = $state('2.00');

	// Quick bet amounts
	const quickBets = [10n, 50n, 100n, 500n, 1000n];

	// Quick target multipliers
	const quickTargets = [1.5, 2, 3, 5, 10];

	// Convert bet string to bigint (in wei)
	function parseBet(value: string): bigint {
		const num = parseFloat(value);
		if (isNaN(num) || num <= 0) return 0n;
		return BigInt(Math.floor(num)) * 10n ** 18n;
	}

	// Parse target multiplier
	function parseTarget(value: string): number {
		const num = parseFloat(value);
		if (isNaN(num)) return 0;
		return num;
	}

	// Validate bet amount
	let betWei = $derived(parseBet(betAmount));
	let isValidBet = $derived(betWei >= MIN_BET && betWei <= MAX_BET);

	// Validate target
	let targetNum = $derived(parseTarget(targetValue));
	let isValidTarget = $derived(targetNum >= MIN_TARGET && targetNum <= MAX_TARGET);

	// Can submit bet
	let canSubmit = $derived(canBet && isValidBet && isValidTarget);

	// Win probability
	let winProb = $derived(isValidTarget ? calculateWinProbability(targetNum) : 0);

	// Expected payout if win
	let expectedPayout = $derived(
		isValidBet && isValidTarget ? BigInt(Math.floor(Number(betWei) * targetNum)) : 0n
	);

	// Profit if win
	let profitIfWin = $derived(expectedPayout - betWei);

	// Format bigint to display
	function formatData(wei: bigint): string {
		return (Number(wei) / 1e18).toFixed(0);
	}

	// Handle bet submission
	function handlePlaceBet() {
		if (!canSubmit) return;
		onPlaceBet(betWei, targetNum);
	}

	// Set bet from quick bet button
	function setQuickBet(amount: bigint) {
		betAmount = formatData(amount);
	}

	// Set target from quick target button
	function setQuickTarget(target: number) {
		targetValue = target.toFixed(2);
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

			<!-- Bet Amount Input -->
			<div class="input-section">
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
				<div class="quick-buttons">
					{#each quickBets as amount}
						<button type="button" class="quick-btn" onclick={() => setQuickBet(amount)}>
							{formatData(amount)}
						</button>
					{/each}
				</div>
			</div>

			<!-- Target Multiplier Input -->
			<div class="input-section">
				<label class="input-label" for="target-mult">CASH OUT AT</label>
				<div class="input-wrapper">
					<input
						id="target-mult"
						type="text"
						inputmode="decimal"
						class="bet-input"
						bind:value={targetValue}
						placeholder="2.00"
					/>
					<span class="input-suffix">x</span>
				</div>
				<div class="quick-buttons">
					{#each quickTargets as target}
						<button type="button" class="quick-btn" onclick={() => setQuickTarget(target)}>
							{target}x
						</button>
					{/each}
				</div>
			</div>

			<!-- Outcome Preview -->
			<div class="outcome-preview">
				<div class="outcome-row win">
					<span class="outcome-label">IF WIN (crash > {targetValue}x)</span>
					<span class="outcome-value">+{formatData(profitIfWin)} $DATA</span>
				</div>
				<div class="outcome-row lose">
					<span class="outcome-label">IF LOSE (crash &le; {targetValue}x)</span>
					<span class="outcome-value">-{formatData(betWei)} $DATA</span>
				</div>
				<div class="outcome-row probability">
					<span class="outcome-label">WIN PROBABILITY</span>
					<span class="outcome-value">{(winProb * 100).toFixed(0)}%</span>
				</div>
			</div>

			<Button
				variant="primary"
				size="lg"
				fullWidth
				disabled={!canSubmit}
				loading={isLoading}
				onclick={handlePlaceBet}
			>
				PLACE BET
			</Button>

			{#if !isValidBet && betAmount !== ''}
				<p class="error-text">Bet must be 10-1000 $DATA</p>
			{/if}
			{#if !isValidTarget && targetValue !== ''}
				<p class="error-text">Target must be {MIN_TARGET}x-{MAX_TARGET}x</p>
			{/if}
		{:else if currentBet && phase && ['locked', 'revealed', 'animating'].includes(phase)}
			<!-- Waiting for reveal / Watching animation -->
			<div class="bet-placed">
				<div class="bet-info">
					<span class="label">YOUR BET</span>
					<span class="value">{formatData(currentBet)} $DATA</span>
				</div>
				<div class="bet-info target">
					<span class="label">YOUR TARGET</span>
					<span class="value">{targetMultiplier ? formatMultiplier(targetMultiplier) : '-'}</span>
				</div>

				{#if phase === 'locked'}
					<div class="status-message">
						<span class="status-icon pulse">...</span>
						<span>Waiting for block hash...</span>
					</div>
				{:else if phase === 'revealed' || phase === 'animating'}
					{#if playerResult === 'won'}
						<div class="result-banner won">
							<span class="result-icon">+</span>
							<div class="result-text">
								<span class="result-title">TARGET REACHED!</span>
								<span class="result-detail"
									>{targetMultiplier ? formatMultiplier(targetMultiplier) : '-'} &lt; {crashPoint
										? formatMultiplier(crashPoint)
										: '-'}</span
								>
							</div>
						</div>
						<div class="payout-display">
							<span class="label">PAYOUT</span>
							<span class="value win">{formatData(potentialPayout)} $DATA</span>
						</div>
					{:else if playerResult === 'lost'}
						<div class="result-banner lost">
							<span class="result-icon">X</span>
							<div class="result-text">
								<span class="result-title">CRASHED!</span>
								<span class="result-detail"
									>{targetMultiplier ? formatMultiplier(targetMultiplier) : '-'} &ge; {crashPoint
										? formatMultiplier(crashPoint)
										: '-'}</span
								>
							</div>
						</div>
						<div class="payout-display">
							<span class="label">LOST</span>
							<span class="value lose">-{formatData(currentBet)} $DATA</span>
						</div>
					{:else}
						<!-- Still pending during animation -->
						<div class="animation-status">
							<span class="current-mult">{formatMultiplier(multiplier)}</span>
							<span class="target-indicator"
								>Target: {targetMultiplier ? formatMultiplier(targetMultiplier) : '-'}</span
							>
						</div>
					{/if}
				{/if}
			</div>
		{:else if phase === 'settled' && currentBet}
			<!-- Round settled -->
			<div class="settled-display">
				{#if playerResult === 'won'}
					<div class="final-result won">
						<span class="final-icon">+</span>
						<span class="final-text">YOU WON!</span>
					</div>
					<div class="payout-display">
						<span class="label">PROFIT</span>
						<span class="value win">+{formatData(potentialPayout - currentBet)} $DATA</span>
					</div>
				{:else}
					<div class="final-result lost">
						<span class="final-icon">X</span>
						<span class="final-text">YOU LOST</span>
					</div>
					<div class="payout-display">
						<span class="label">LOST</span>
						<span class="value lose">-{formatData(currentBet)} $DATA</span>
					</div>
				{/if}
				<div class="next-round">Next round starting soon...</div>
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

	/* Input sections */
	.input-section {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
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

	/* Quick buttons */
	.quick-buttons {
		display: flex;
		gap: var(--space-2);
	}

	.quick-btn {
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

	.quick-btn:hover {
		border-color: var(--color-accent);
		color: var(--color-accent);
	}

	/* Outcome preview */
	.outcome-preview {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
		border: var(--border-width) solid var(--color-border-subtle);
	}

	.outcome-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		font-size: var(--text-sm);
	}

	.outcome-label {
		color: var(--color-text-tertiary);
	}

	.outcome-value {
		font-family: var(--font-mono);
		font-weight: var(--font-medium);
	}

	.outcome-row.win .outcome-value {
		color: var(--color-accent);
	}

	.outcome-row.lose .outcome-value {
		color: var(--color-red);
	}

	.outcome-row.probability .outcome-value {
		color: var(--color-cyan);
	}

	/* Bet placed display */
	.bet-placed,
	.settled-display {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.bet-info {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: var(--space-2) var(--space-3);
		background: var(--color-bg-tertiary);
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

	.bet-info.target .value {
		color: var(--color-cyan);
	}

	/* Status message */
	.status-message {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		padding: var(--space-4);
		color: var(--color-text-secondary);
		font-family: var(--font-mono);
	}

	.status-icon.pulse {
		animation: pulse-text 1s ease-in-out infinite;
	}

	/* Result banner */
	.result-banner {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-3);
		border: var(--border-width) solid;
	}

	.result-banner.won {
		background: rgba(0, 229, 204, 0.1);
		border-color: var(--color-accent);
	}

	.result-banner.lost {
		background: rgba(255, 0, 64, 0.1);
		border-color: var(--color-red);
	}

	.result-icon {
		font-family: var(--font-mono);
		font-size: var(--text-2xl);
		font-weight: var(--font-bold);
	}

	.result-banner.won .result-icon {
		color: var(--color-accent);
	}

	.result-banner.lost .result-icon {
		color: var(--color-red);
	}

	.result-text {
		display: flex;
		flex-direction: column;
	}

	.result-title {
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		font-family: var(--font-mono);
	}

	.result-banner.won .result-title {
		color: var(--color-accent);
	}

	.result-banner.lost .result-title {
		color: var(--color-red);
	}

	.result-detail {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		font-family: var(--font-mono);
	}

	/* Payout display */
	.payout-display {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
	}

	.payout-display .label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.payout-display .value {
		font-family: var(--font-mono);
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
	}

	.payout-display .value.win {
		color: var(--color-accent);
	}

	.payout-display .value.lose {
		color: var(--color-red);
	}

	/* Animation status */
	.animation-status {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: var(--space-4);
		gap: var(--space-2);
	}

	.current-mult {
		font-family: var(--font-mono);
		font-size: var(--text-3xl);
		font-weight: var(--font-bold);
		color: var(--color-accent);
	}

	.target-indicator {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
	}

	/* Final result */
	.final-result {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-3);
		padding: var(--space-4);
		border: var(--border-width) solid;
	}

	.final-result.won {
		background: rgba(0, 229, 204, 0.1);
		border-color: var(--color-accent);
	}

	.final-result.lost {
		background: rgba(255, 0, 64, 0.1);
		border-color: var(--color-red);
	}

	.final-icon {
		font-family: var(--font-mono);
		font-size: var(--text-3xl);
		font-weight: var(--font-bold);
	}

	.final-result.won .final-icon,
	.final-result.won .final-text {
		color: var(--color-accent);
	}

	.final-result.lost .final-icon,
	.final-result.lost .final-text {
		color: var(--color-red);
	}

	.final-text {
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		font-family: var(--font-mono);
	}

	/* Waiting / next round */
	.waiting-phase,
	.next-round {
		text-align: center;
		color: var(--color-text-tertiary);
		padding: var(--space-4);
		font-family: var(--font-mono);
	}

	/* Error text */
	.error-text {
		font-size: var(--text-sm);
		color: var(--color-red);
		text-align: center;
	}
</style>
