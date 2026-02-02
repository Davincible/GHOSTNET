<script lang="ts">
	/**
	 * JackInFlow - Inline Jack In Experience
	 *
	 * A step-by-step flow for jacking in, rendered inline (not in a modal).
	 * Uses the same visual components as JackInModal but in a Panel.
	 *
	 * Flow based on user's balance state:
	 * - No ETH: Show instructions to get ETH
	 * - Has ETH but no DATA: Show buy DATA interface
	 * - Has DATA: Level → Amount → Confirm
	 *
	 * Steps:
	 * 1. (Optional) Get ETH - Instructions for users with no ETH
	 * 2. (Optional) Buy DATA - Swap interface for users with no DATA
	 * 3. Level Selection - Choose risk level
	 * 4. Amount Input - Enter stake amount
	 * 5. Confirm - Review and execute
	 */

	import { Panel } from '$lib/ui/terminal';
	import { Box } from '$lib/ui/terminal';
	import { Button, Badge } from '$lib/ui/primitives';
	import { Stack, Row } from '$lib/ui/layout';
	import { LevelBadge, AmountDisplay, PercentDisplay } from '$lib/ui/data-display';
	import { SwapPanel } from '$lib/features/swap';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import { getToasts } from '$lib/ui/toast';
	import { LEVELS, LEVEL_CONFIG, type Level } from '$lib/core/types';
	import { parseUnits, formatUnits } from 'viem';
	import { formatWei } from '$lib/core/utils';

	interface Props {
		/** Callback to skip directly to command center (demo mode) */
		onSkip?: () => void;
		/** Callback when jack in succeeds */
		onSuccess?: () => void;
	}

	let { onSkip, onSuccess }: Props = $props();

	const provider = getProvider();
	const toast = getToasts();

	// User balance state
	let ethBalance = $derived(provider.currentUser?.ethBalance ?? 0n);
	let dataBalance = $derived(provider.currentUser?.tokenBalance ?? 0n);
	let hasEth = $derived(ethBalance > 0n);
	let hasData = $derived(dataBalance > 0n);

	// Determine initial step based on balances
	let initialStep = $derived.by((): Step => {
		if (!hasEth) return 'get-eth';
		if (!hasData) return 'buy-data';
		return 'level';
	});

	// Flow state
	type Step = 'get-eth' | 'buy-data' | 'level' | 'amount' | 'confirm';
	let step = $state<Step>('level');
	let selectedLevel = $state<Level>('SUBNET');
	let amountInput = $state('');
	let isSubmitting = $state(false);

	// Sync step with initial step when balances change
	$effect(() => {
		// Only auto-navigate to earlier steps, not forward
		// This ensures we show buy-data if user has no DATA
		if (initialStep === 'get-eth' && step !== 'get-eth') {
			step = 'get-eth';
		} else if (initialStep === 'buy-data' && step === 'level') {
			// Only redirect to buy-data if we're on level step
			// Don't interrupt if user is already past that
			step = 'buy-data';
		}
	});

	// Transaction state
	type TxState = 'idle' | 'pending' | 'confirming' | 'success' | 'error';
	let txState = $state<TxState>('idle');
	let txHash = $state<string | null>(null);
	let txError = $state<string | null>(null);

	// Computed values
	let levelConfig = $derived(LEVEL_CONFIG[selectedLevel]);
	let minStakeFormatted = $derived(Number(formatUnits(levelConfig.minStake, 18)));
	let userBalance = $derived(provider.currentUser?.tokenBalance ?? 0n);
	let userBalanceFormatted = $derived(Number(formatUnits(userBalance, 18)));

	let parsedAmount = $derived.by(() => {
		const trimmed = amountInput.trim();
		if (!trimmed || isNaN(Number(trimmed)) || Number(trimmed) <= 0) return 0n;
		try {
			return parseUnits(trimmed, 18);
		} catch {
			return 0n;
		}
	});

	let amountValid = $derived(parsedAmount >= levelConfig.minStake && parsedAmount <= userBalance);

	let amountError = $derived.by(() => {
		if (!amountInput) return null;
		if (parsedAmount < levelConfig.minStake) {
			return `Minimum ${minStakeFormatted} GHOST required for ${selectedLevel}`;
		}
		if (parsedAmount > userBalance) {
			return 'Insufficient balance';
		}
		return null;
	});

	// Level descriptions
	const levelDescriptions: Record<Level, { risk: string; reward: string; description: string }> = {
		VAULT: {
			risk: 'NONE',
			reward: '0% APY',
			description: 'Safe storage. No risk, no reward.',
		},
		MAINFRAME: {
			risk: 'MINIMAL',
			reward: '~5% APY',
			description: 'Corporate systems. Low risk, steady yield.',
		},
		SUBNET: {
			risk: 'MODERATE',
			reward: '~25% APY',
			description: 'Underground networks. Balanced risk/reward.',
		},
		DARKNET: {
			risk: 'HIGH',
			reward: '~80% APY',
			description: 'Illegal channels. High risk, high reward.',
		},
		BLACK_ICE: {
			risk: 'EXTREME',
			reward: '~200% APY',
			description: 'Military-grade ICE. Maximum risk, maximum reward.',
		},
	};

	// Track where user came from when navigating to buy-data
	let returnFromBuyData = $state<Step | null>(null);

	// Actions
	function selectLevel(level: Level) {
		selectedLevel = level;
	}

	function proceedToLevel() {
		step = 'level';
	}

	function proceedToBuyData() {
		// Remember where we came from so Back returns there
		returnFromBuyData = step;
		step = 'buy-data';
	}

	function proceedToAmount() {
		step = 'amount';
		amountInput = minStakeFormatted.toString();
	}

	function proceedToConfirm() {
		if (!amountValid) return;
		step = 'confirm';
	}

	function goBack() {
		if (step === 'buy-data') {
			// Return to where user came from, or get-eth if no ETH
			if (!hasEth) {
				step = 'get-eth';
			} else if (returnFromBuyData && returnFromBuyData !== 'buy-data') {
				step = returnFromBuyData;
			} else {
				step = 'level';
			}
			returnFromBuyData = null;
		} else if (step === 'level' && !hasData) {
			step = 'buy-data';
		} else if (step === 'amount') {
			step = 'level';
		} else if (step === 'confirm') {
			step = 'amount';
		}
	}

	async function handleJackIn() {
		if (isSubmitting) return;
		isSubmitting = true;
		txState = 'pending';
		txHash = null;
		txError = null;

		try {
			const hash = await provider.jackIn(selectedLevel, parsedAmount);
			txHash = hash;
			txState = 'confirming';

			await new Promise((resolve) => setTimeout(resolve, 1500));

			txState = 'success';
			toast.success('Successfully jacked in');
			onSuccess?.();
		} catch (err) {
			console.error('Jack In failed:', err);
			txState = 'error';
			txError = err instanceof Error ? err.message : 'Jack In failed';
			toast.error(txError);
		} finally {
			isSubmitting = false;
		}
	}

	function setMaxAmount() {
		amountInput = userBalanceFormatted.toString();
	}
</script>

<div class="jack-in-flow">
	<Panel title="JACK IN" variant="single">
		{#if step === 'get-eth'}
			<!-- Step: No ETH - Instructions -->
			<Stack gap={4}>
				<div class="status-header">
					<Badge variant="warning">NO ETH DETECTED</Badge>
				</div>

				<p class="step-description">
					You need ETH in your wallet to pay for gas fees and acquire $DATA tokens.
				</p>

				<Box variant="single" borderColor="amber" padding={3}>
					<Stack gap={3}>
						<div class="instruction">
							<span class="instruction-number">1</span>
							<div class="instruction-content">
								<span class="instruction-title">Buy ETH on an exchange</span>
								<span class="instruction-detail">Coinbase, Kraken, Binance, etc.</span>
							</div>
						</div>
						<div class="instruction">
							<span class="instruction-number">2</span>
							<div class="instruction-content">
								<span class="instruction-title">Withdraw to your wallet</span>
								<span class="instruction-detail">Send ETH to your connected wallet address</span>
							</div>
						</div>
						<div class="instruction">
							<span class="instruction-number">3</span>
							<div class="instruction-content">
								<span class="instruction-title">Bridge to MegaETH (if needed)</span>
								<span class="instruction-detail">Use the official MegaETH bridge</span>
							</div>
						</div>
					</Stack>
				</Box>

				<div class="balance-status">
					<span class="balance-label">Current ETH Balance:</span>
					<span class="balance-value zero">{formatWei(ethBalance, { displayDecimals: 4 })} ETH</span>
				</div>

				<Row justify="between" align="center">
					{#if onSkip}
						<button class="skip-link" onclick={onSkip}>skip to demo →</button>
					{:else}
						<div></div>
					{/if}
					<Button variant="secondary" disabled={!hasEth} onclick={proceedToBuyData}>
						{hasEth ? 'Continue →' : 'Waiting for ETH...'}
					</Button>
				</Row>
			</Stack>
		{:else if step === 'buy-data'}
			<!-- Step: Buy DATA -->
			<Stack gap={4}>
				<div class="status-header">
					<Badge variant="default">ACQUIRE $DATA</Badge>
					<span class="balance-inline">
						Balance: <span class="balance-value">{formatWei(dataBalance)} $DATA</span>
					</span>
				</div>

				<p class="step-description">
					Swap ETH for $DATA tokens to participate in GHOSTNET.
				</p>

				<!-- Embedded Swap Panel -->
				<div class="swap-container">
					<SwapPanel />
				</div>

				<Row justify="between" align="center">
					<Button variant="ghost" onclick={goBack}>← Back</Button>
					<Button variant="primary" disabled={!hasData} onclick={proceedToLevel}>
						{hasData ? 'Continue to Stake →' : 'Get $DATA First'}
					</Button>
				</Row>
			</Stack>
		{:else if step === 'level'}
			<!-- Step: Level Selection -->
			<Stack gap={3}>
				<p class="step-description">
					Select your security clearance level. Higher levels offer better yields but greater risk
					of being traced.
				</p>

				<div class="level-grid">
					{#each LEVELS as level (level)}
						{@const config = LEVEL_CONFIG[level]}
						{@const desc = levelDescriptions[level]}
						{@const isSelected = selectedLevel === level}
						<button
							class="level-option"
							class:selected={isSelected}
							onclick={() => selectLevel(level)}
							style:--level-color={config.color}
						>
							<Row justify="between" align="center">
								<LevelBadge {level} />
								<Badge
									variant={level === 'BLACK_ICE'
										? 'danger'
										: level === 'DARKNET'
											? 'warning'
											: 'default'}
								>
									{desc.risk}
								</Badge>
							</Row>
							<div class="level-details">
								<span class="level-reward">{desc.reward}</span>
								<span class="level-death">
									{config.baseDeathRate > 0
										? `${(config.baseDeathRate * 100).toFixed(0)}% death rate`
										: 'No scans'}
								</span>
							</div>
							<p class="level-desc">{desc.description}</p>
							<div class="level-min">
								Min: <AmountDisplay amount={config.minStake} />
							</div>
						</button>
					{/each}
				</div>

				<!-- Balance display -->
				<div class="balance-row">
					<span class="balance-label">Your $DATA Balance:</span>
					<span class="balance-value">{formatWei(dataBalance)}</span>
				</div>

				<Row justify="between" align="center">
					{#if onSkip}
						<button class="skip-link" onclick={onSkip}>skip to demo →</button>
					{:else}
						<div></div>
					{/if}
					<Row gap={2}>
						<Button variant="secondary" onclick={proceedToBuyData}>Buy More</Button>
						<Button variant="primary" onclick={proceedToAmount}>Continue →</Button>
					</Row>
				</Row>
			</Stack>
		{:else if step === 'amount'}
			<!-- Step 2: Amount Input -->
			<Stack gap={3}>
				<Row align="center" gap={2}>
					<button class="back-btn" onclick={goBack} aria-label="Go back">
						<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<polyline points="15 18 9 12 15 6"></polyline>
						</svg>
					</button>
					<span class="step-title">Enter Amount</span>
				</Row>

				<div class="selected-level-display">
					<LevelBadge level={selectedLevel} />
					<span class="level-info">
						{levelDescriptions[selectedLevel].reward} · {(levelConfig.baseDeathRate * 100).toFixed(
							0
						)}% death rate
					</span>
				</div>

				<div class="amount-input-group">
					<label class="amount-label" for="amount-input">Amount to stake</label>
					<div class="input-wrapper">
						<input
							id="amount-input"
							type="number"
							class="amount-input"
							class:error={amountError}
							bind:value={amountInput}
							placeholder="0.00"
							min="0"
							step="any"
						/>
						<span class="input-suffix">GHOST</span>
						<button class="max-btn" onclick={setMaxAmount}>MAX</button>
					</div>
					{#if amountError}
						<span class="input-error">{amountError}</span>
					{/if}
					<div class="balance-info">
						<span>Balance: </span>
						<AmountDisplay amount={userBalance} />
					</div>
				</div>

				<Row justify="between" align="center">
					<Button variant="ghost" onclick={goBack}>← Back</Button>
					<Row gap={2}>
						<Button variant="secondary" onclick={proceedToBuyData}>Buy More</Button>
						<Button variant="primary" onclick={proceedToConfirm} disabled={!amountValid}>
							Continue →
						</Button>
					</Row>
				</Row>
			</Stack>
		{:else if step === 'confirm'}
			<!-- Step 3: Confirmation -->
			<Stack gap={3}>
				<Row align="center" gap={2}>
					<button class="back-btn" onclick={goBack} aria-label="Go back">
						<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<polyline points="15 18 9 12 15 6"></polyline>
						</svg>
					</button>
					<span class="step-title">Confirm Jack In</span>
				</Row>

				<Box variant="single" borderColor="amber" padding={3}>
					<Stack gap={2}>
						<Row justify="between">
							<span class="confirm-label">Level</span>
							<LevelBadge level={selectedLevel} />
						</Row>
						<Row justify="between">
							<span class="confirm-label">Amount</span>
							<AmountDisplay amount={parsedAmount} />
						</Row>
						<Row justify="between">
							<span class="confirm-label">Death Rate</span>
							<PercentDisplay value={levelConfig.baseDeathRate * 100} />
						</Row>
						<Row justify="between">
							<span class="confirm-label">Scan Interval</span>
							<span class="confirm-value">
								{levelConfig.scanIntervalHours === Infinity
									? 'Never'
									: `Every ${levelConfig.scanIntervalHours}h`}
							</span>
						</Row>
					</Stack>
				</Box>

				<!-- Transaction Status -->
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
								</div>
							{:else if txState === 'error' && txError}
								<Row align="center" gap={2}>
									<span class="tx-error-icon">!</span>
									<span class="tx-error">{txError}</span>
								</Row>
							{/if}
						</Stack>
					</Box>
				{:else}
					<div class="warning-text">
						<Badge variant="warning">WARNING</Badge>
						<p>
							Once jacked in, you may lose your stake if traced during a scan. Make sure you
							understand the risks.
						</p>
					</div>
				{/if}

				<Row justify="between" align="center">
					<Button variant="ghost" onclick={goBack} disabled={isSubmitting}>← Back</Button>
					<Row gap={2}>
						<Button variant="secondary" onclick={proceedToBuyData} disabled={isSubmitting}>
							Buy More
						</Button>
						<Button
							variant="primary"
							onclick={handleJackIn}
							loading={isSubmitting}
							disabled={isSubmitting}
						>
							{#if txState === 'pending'}
								CONFIRM IN WALLET
							{:else if txState === 'confirming'}
								CONFIRMING...
							{:else}
								JACK IN →
							{/if}
						</Button>
					</Row>
				</Row>
			</Stack>
		{/if}
	</Panel>
</div>

<style>
	.jack-in-flow {
		width: 100%;
		max-width: 500px;
		margin: 0 auto;
	}

	.step-description {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		line-height: var(--leading-relaxed);
		margin: 0;
	}

	.step-title {
		color: var(--color-accent);
		font-size: var(--text-lg);
		font-weight: var(--font-medium);
	}

	.back-btn {
		background: none;
		border: none;
		color: var(--color-text-tertiary);
		cursor: pointer;
		padding: var(--space-1);
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.back-btn:hover {
		color: var(--color-accent);
	}

	.back-btn svg {
		width: 20px;
		height: 20px;
	}

	/* Level Selection */
	.level-grid {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.level-option {
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-subtle);
		padding: var(--space-3);
		cursor: pointer;
		text-align: left;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.level-option:hover {
		border-color: var(--level-color, var(--color-accent-dim));
		background: var(--color-bg-tertiary);
	}

	.level-option.selected {
		border-color: var(--level-color, var(--color-accent));
		box-shadow: 0 0 10px color-mix(in srgb, var(--level-color, var(--color-accent)) 50%, transparent);
	}

	.level-details {
		display: flex;
		gap: var(--space-3);
		margin-top: var(--space-2);
		font-size: var(--text-sm);
	}

	.level-reward {
		color: var(--color-profit);
	}

	.level-death {
		color: var(--color-red);
	}

	.level-desc {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		margin-top: var(--space-1);
	}

	.level-min {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		margin-top: var(--space-2);
	}

	/* Amount Input */
	.selected-level-display {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--color-bg-secondary);
	}

	.level-info {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
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
		padding: var(--space-1);
	}

	.amount-input {
		flex: 1;
		background: transparent;
		border: none;
		color: var(--color-accent);
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		padding: var(--space-2);
		outline: none;
	}

	.amount-input::placeholder {
		color: var(--color-text-muted);
	}

	.amount-input.error {
		color: var(--color-red);
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
		color: var(--color-text-muted);
		font-size: var(--text-sm);
		padding: 0 var(--space-2);
	}

	.max-btn {
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-default);
		color: var(--color-text-secondary);
		font-size: var(--text-xs);
		padding: var(--space-1) var(--space-2);
		cursor: pointer;
		font-family: var(--font-mono);
	}

	.max-btn:hover {
		background: var(--color-accent-dim);
		color: var(--color-bg-primary);
	}

	.input-error {
		color: var(--color-red);
		font-size: var(--text-xs);
	}

	.balance-info {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
	}

	/* Confirmation */
	.confirm-label {
		color: var(--color-text-muted);
		font-size: var(--text-sm);
	}

	.confirm-value {
		color: var(--color-accent);
		font-size: var(--text-sm);
	}

	.warning-text {
		display: flex;
		align-items: flex-start;
		gap: var(--space-2);
		padding: var(--space-2);
		background: rgba(255, 170, 0, 0.1);
	}

	.warning-text p {
		color: var(--color-amber);
		font-size: var(--text-sm);
		line-height: var(--leading-relaxed);
		margin: 0;
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
	}

	.tx-hash-label {
		color: var(--color-text-muted);
	}

	.tx-hash-value {
		color: var(--color-accent);
		font-family: var(--font-mono);
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

	/* Skip Link */
	.skip-link {
		padding: var(--space-2) var(--space-3);
		background: transparent;
		border: none;
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		cursor: pointer;
		opacity: 0.4;
		transition: opacity 0.2s ease;
	}

	.skip-link:hover {
		opacity: 0.8;
		color: var(--color-text-tertiary);
	}

	/* ═══════════════════════════════════════════════════════════════
	   GET ETH / BUY DATA STEPS
	   ═══════════════════════════════════════════════════════════════ */

	.status-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-2);
	}

	.balance-inline {
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
	}

	.balance-inline .balance-value {
		color: var(--color-accent);
		font-weight: var(--font-medium);
	}

	/* Instructions list */
	.instruction {
		display: flex;
		align-items: flex-start;
		gap: var(--space-3);
	}

	.instruction-number {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 24px;
		height: 24px;
		background: var(--color-accent-dim);
		color: var(--color-accent);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		flex-shrink: 0;
	}

	.instruction-content {
		display: flex;
		flex-direction: column;
		gap: var(--space-0-5);
	}

	.instruction-title {
		color: var(--color-text-primary);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
	}

	.instruction-detail {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
	}

	/* Balance status */
	.balance-status {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--color-bg-secondary);
		font-size: var(--text-sm);
	}

	.balance-status .balance-label {
		color: var(--color-text-tertiary);
	}

	.balance-status .balance-value {
		color: var(--color-accent);
		font-weight: var(--font-bold);
		font-family: var(--font-mono);
	}

	.balance-status .balance-value.zero {
		color: var(--color-amber);
	}

	/* Swap container */
	.swap-container {
		margin: 0 calc(-1 * var(--space-3));
	}

	.swap-container :global(.terminal-box) {
		border-left: none;
		border-right: none;
	}

	/* Balance row */
	.balance-row {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--color-bg-secondary);
		font-size: var(--text-sm);
	}

	.balance-row .balance-label {
		color: var(--color-text-tertiary);
	}

	.balance-row .balance-value {
		color: var(--color-accent);
		font-weight: var(--font-bold);
		font-family: var(--font-mono);
	}
</style>
