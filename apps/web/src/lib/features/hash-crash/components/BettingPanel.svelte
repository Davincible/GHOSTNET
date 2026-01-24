<script lang="ts">
	import Button from '$lib/ui/primitives/Button.svelte';
	import Box from '$lib/ui/terminal/Box.svelte';
	import { MIN_BET, MAX_BET, MIN_TARGET, MAX_TARGET, formatMultiplier } from '../store.svelte';
	import { SCANNING_MESSAGES } from '../messages';

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

	// Scanning message cycling state
	let scanningMessageIndex = $state(0);
	let scanningInterval: ReturnType<typeof setInterval> | null = null;

	// Cycle scanning messages during locked phase
	$effect(() => {
		if (phase === 'locked') {
			// Start with a random message
			scanningMessageIndex = Math.floor(Math.random() * SCANNING_MESSAGES.length);

			// Cycle every 2 seconds
			scanningInterval = setInterval(() => {
				scanningMessageIndex = (scanningMessageIndex + 1) % SCANNING_MESSAGES.length;
			}, 2000);

			return () => {
				if (scanningInterval) {
					clearInterval(scanningInterval);
					scanningInterval = null;
				}
			};
		} else if (scanningInterval) {
			clearInterval(scanningInterval);
			scanningInterval = null;
		}
	});

	// Get current scanning message
	let scanningMessage = $derived(SCANNING_MESSAGES[scanningMessageIndex]);

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

	// Check if a quick target is currently selected
	let selectedTarget = $derived(quickTargets.find((t) => t.toFixed(2) === targetValue) ?? null);

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
				<label class="input-label highlighted" for="bet-amount">BET AMOUNT</label>
				<div class="input-wrapper snake-border">
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
						<button
							type="button"
							class="quick-btn"
							class:selected={selectedTarget === target}
							class:recommended={target === Math.max(...quickTargets) && selectedTarget !== target}
							onclick={() => setQuickTarget(target)}
						>
							{target}x{#if target === Math.max(...quickTargets)}<span class="recommended-star"
									>★</span
								>{/if}
						</button>
					{/each}
				</div>
			</div>

			<!-- Outcome Preview -->
			<div class="outcome-preview">
				<div class="outcome-row win">
					<span class="outcome-label">POTENTIAL PROFIT</span>
					<span class="outcome-value">+{formatData(profitIfWin)} $DATA</span>
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
		{:else if currentBet && phase === 'betting'}
			<!-- Bet placed, waiting for betting to close -->
			<div class="bet-placed">
				<div class="countdown" class:critical={isCritical}>
					<span class="countdown-label">BETTING CLOSES IN</span>
					<span class="countdown-value">{timeDisplay}</span>
				</div>

				<div class="bet-confirmed">
					<span class="confirmed-icon">✓</span>
					<span class="confirmed-text">BET LOCKED IN</span>
				</div>

				<div class="bet-info">
					<span class="label">YOUR BET</span>
					<span class="value">{formatData(currentBet)} $DATA</span>
				</div>
				<div class="bet-info target">
					<span class="label">YOUR TARGET</span>
					<span class="value">{targetMultiplier ? formatMultiplier(targetMultiplier) : '-'}</span>
				</div>

				<div class="outcome-preview">
					<div class="outcome-row win">
						<span class="outcome-label">IF WIN</span>
						<span class="outcome-value">+{formatData(potentialPayout - currentBet)} $DATA</span>
					</div>
				</div>
			</div>
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
					<div class="locked-state">
						<!-- Animated loading bar -->
						<div class="loading-bar">
							<div class="loading-progress"></div>
						</div>

						<!-- Scanning status -->
						<div class="status-message scanning">
							<span class="scanning-text">{scanningMessage}</span>
						</div>

						<!-- Animated data stream -->
						<div class="data-stream">
							<span class="stream-line">0x{Math.random().toString(16).slice(2, 10)}</span>
							<span class="stream-line">PKT:{Math.random().toString(16).slice(2, 5)}</span>
							<span class="stream-line">[SYNC]</span>
						</div>

						<!-- Visual heartbeat -->
						<div class="heartbeat">
							<span class="beat"></span>
							<span class="beat"></span>
							<span class="beat"></span>
						</div>
					</div>
				{:else if phase === 'revealed' || phase === 'animating'}
					<!-- During animation - show live status, not final result -->
					<div class="animation-status">
						<span class="current-mult">{formatMultiplier(multiplier)}</span>
						<span class="target-indicator"
							>Target: {targetMultiplier ? formatMultiplier(targetMultiplier) : '-'}</span
						>
					</div>
					<!-- Show "safe" indicator when multiplier passes target (but don't spoil win/loss) -->
					{#if targetMultiplier && multiplier >= targetMultiplier}
						<div class="safe-indicator">
							<span class="safe-icon">+</span>
							<span class="safe-text">TARGET PASSED - EXIT SECURED</span>
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

	.input-label.highlighted {
		color: var(--color-accent);
	}

	.input-wrapper {
		display: flex;
		align-items: center;
		background: var(--color-bg-void);
		border: var(--border-width) solid var(--color-border-default);
		transition:
			border-color 0.3s,
			box-shadow 0.3s;
	}

	/* Snake border animation - a highlight that sweeps around the border */
	.input-wrapper.snake-border {
		position: relative;
		border: 2px solid transparent;
		background:
			linear-gradient(var(--color-bg-void), var(--color-bg-void)) padding-box,
			linear-gradient(
					90deg,
					var(--color-bg-tertiary) 0%,
					var(--color-accent) 25%,
					var(--color-cyan) 50%,
					var(--color-accent) 75%,
					var(--color-bg-tertiary) 100%
				)
				border-box;
		background-size:
			100% 100%,
			400% 100%;
		animation: snake-sweep 3s ease-in-out infinite;
	}

	@keyframes snake-sweep {
		0%,
		100% {
			background-position:
				0 0,
				100% 0;
		}
		50% {
			background-position:
				0 0,
				0% 0;
		}
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

	/* Selected state - clearly shows current selection */
	.quick-btn.selected {
		border-color: var(--color-accent);
		color: var(--color-accent);
		background: rgba(0, 229, 204, 0.15);
		box-shadow: 0 0 8px rgba(0, 229, 204, 0.3);
	}

	/* Recommended button - amber/gold highlight to draw attention */
	.quick-btn.recommended {
		border-color: var(--color-amber);
		color: var(--color-amber);
		background: rgba(255, 170, 0, 0.1);
		animation: recommended-pulse 2s ease-in-out infinite;
	}

	.quick-btn.recommended:hover {
		border-color: var(--color-amber);
		color: var(--color-amber);
		background: rgba(255, 170, 0, 0.2);
	}

	/* When recommended is also selected, selected wins */
	.quick-btn.selected.recommended {
		animation: none;
	}

	@keyframes recommended-pulse {
		0%,
		100% {
			box-shadow: 0 0 4px rgba(255, 170, 0, 0.3);
		}
		50% {
			box-shadow: 0 0 12px rgba(255, 170, 0, 0.5);
		}
	}

	/* Recommended star indicator */
	.recommended-star {
		margin-left: var(--space-1);
		font-size: var(--text-xs);
		color: var(--color-amber);
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

	/* Bet confirmed indicator */
	.bet-confirmed {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		padding: var(--space-3);
		background: rgba(0, 229, 204, 0.1);
		border: var(--border-width) solid var(--color-accent);
	}

	.confirmed-icon {
		color: var(--color-accent);
		font-size: var(--text-lg);
	}

	.confirmed-text {
		color: var(--color-accent);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
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

	/* Scanning animation for locked phase */
	.status-message.scanning {
		background: var(--color-bg-tertiary);
		border: var(--border-width) solid var(--color-border-subtle);
		flex-direction: column;
		gap: var(--space-1);
	}

	.scanning-text {
		color: var(--color-cyan);
		font-size: var(--text-sm);
		letter-spacing: var(--tracking-wide);
		animation: text-fade 2s ease-in-out infinite;
		text-align: center;
	}

	@keyframes text-fade {
		0%,
		100% {
			opacity: 0.6;
		}
		50% {
			opacity: 1;
		}
	}

	/* Safe indicator (shown during animation when target passed) */
	.safe-indicator {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		padding: var(--space-2) var(--space-3);
		background: rgba(0, 229, 204, 0.1);
		border: var(--border-width) dashed var(--color-accent);
		animation: pulse-safe 1s ease-in-out infinite;
	}

	.safe-icon {
		color: var(--color-accent);
		font-family: var(--font-mono);
		font-weight: var(--font-bold);
	}

	.safe-text {
		color: var(--color-accent);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	@keyframes pulse-safe {
		0%,
		100% {
			opacity: 1;
			box-shadow: 0 0 5px rgba(0, 229, 204, 0.2);
		}
		50% {
			opacity: 0.8;
			box-shadow: 0 0 15px rgba(0, 229, 204, 0.4);
		}
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

	/* Locked state - scanning animation */
	.locked-state {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
		border: var(--border-width) solid var(--color-border-subtle);
	}

	/* Loading bar - animated progress */
	.loading-bar {
		height: 4px;
		background: var(--color-bg-void);
		overflow: hidden;
		position: relative;
	}

	.loading-progress {
		position: absolute;
		height: 100%;
		width: 30%;
		background: linear-gradient(
			90deg,
			transparent,
			var(--color-cyan),
			var(--color-accent),
			var(--color-cyan),
			transparent
		);
		animation: loading-sweep 1.5s ease-in-out infinite;
	}

	@keyframes loading-sweep {
		0% {
			left: -30%;
		}
		100% {
			left: 100%;
		}
	}

	/* Data stream - hex codes flowing */
	.data-stream {
		display: flex;
		justify-content: space-around;
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		opacity: 0.6;
	}

	.stream-line {
		animation: stream-flicker 0.8s ease-in-out infinite;
	}

	.stream-line:nth-child(1) {
		animation-delay: 0s;
	}

	.stream-line:nth-child(2) {
		animation-delay: 0.15s;
	}

	.stream-line:nth-child(3) {
		animation-delay: 0.3s;
	}

	@keyframes stream-flicker {
		0%,
		100% {
			opacity: 0.4;
		}
		50% {
			opacity: 1;
		}
	}

	/* Heartbeat - pulsing dots */
	.heartbeat {
		display: flex;
		justify-content: center;
		gap: var(--space-2);
		padding: var(--space-2) 0;
	}

	.beat {
		width: 8px;
		height: 8px;
		background: var(--color-cyan);
		border-radius: 0;
		animation: heartbeat-pulse 1.2s ease-in-out infinite;
	}

	.beat:nth-child(1) {
		animation-delay: 0s;
	}

	.beat:nth-child(2) {
		animation-delay: 0.2s;
	}

	.beat:nth-child(3) {
		animation-delay: 0.4s;
	}

	@keyframes heartbeat-pulse {
		0%,
		100% {
			opacity: 0.3;
			transform: scale(0.8);
		}
		50% {
			opacity: 1;
			transform: scale(1.2);
		}
	}
</style>
