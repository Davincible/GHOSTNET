<script lang="ts">
	import { Modal } from '$lib/ui/modal';
	import { Box } from '$lib/ui/terminal';
	import { Button, Badge } from '$lib/ui/primitives';
	import { Stack, Row } from '$lib/ui/layout';
	import { LevelBadge, AmountDisplay, PercentDisplay } from '$lib/ui/data-display';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import { LEVELS, LEVEL_CONFIG, type Level } from '$lib/core/types';

	interface Props {
		/** Whether the modal is open */
		open: boolean;
		/** Callback when modal should close */
		onclose: () => void;
	}

	let { open, onclose }: Props = $props();

	const provider = getProvider();

	// Modal state
	type Step = 'level' | 'amount' | 'confirm';
	let step = $state<Step>('level');
	let selectedLevel = $state<Level>('SUBNET');
	let amountInput = $state('');
	let isSubmitting = $state(false);

	// Computed values
	let levelConfig = $derived(LEVEL_CONFIG[selectedLevel]);
	let minStakeFormatted = $derived(Number(levelConfig.minStake / 10n ** 18n));
	let userBalance = $derived(provider.currentUser?.tokenBalance ?? 0n);
	let userBalanceFormatted = $derived(Number(userBalance / 10n ** 18n));

	let parsedAmount = $derived.by(() => {
		const num = parseFloat(amountInput);
		if (isNaN(num) || num <= 0) return 0n;
		return BigInt(Math.floor(num * 1e18));
	});

	let amountValid = $derived(
		parsedAmount >= levelConfig.minStake && parsedAmount <= userBalance
	);

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

	// Reset state when modal opens
	$effect(() => {
		if (open) {
			step = 'level';
			selectedLevel = 'SUBNET';
			amountInput = '';
			isSubmitting = false;
		}
	});

	// Actions
	function selectLevel(level: Level) {
		selectedLevel = level;
	}

	function proceedToAmount() {
		step = 'amount';
		// Pre-fill with minimum stake
		amountInput = minStakeFormatted.toString();
	}

	function proceedToConfirm() {
		if (!amountValid) return;
		step = 'confirm';
	}

	function goBack() {
		if (step === 'amount') step = 'level';
		else if (step === 'confirm') step = 'amount';
	}

	async function handleJackIn() {
		if (isSubmitting) return;
		isSubmitting = true;

		try {
			await provider.jackIn(selectedLevel, parsedAmount);
			onclose();
		} catch (error) {
			console.error('Jack In failed:', error);
			// Could show error toast here
		} finally {
			isSubmitting = false;
		}
	}

	function setMaxAmount() {
		amountInput = userBalanceFormatted.toString();
	}

	// Level descriptions for risk display
	const levelDescriptions: Record<Level, { risk: string; reward: string; description: string }> = {
		VAULT: {
			risk: 'NONE',
			reward: '0% APY',
			description: 'Safe storage. No risk, no reward.'
		},
		MAINFRAME: {
			risk: 'MINIMAL',
			reward: '~5% APY',
			description: 'Corporate systems. Low risk, steady yield.'
		},
		SUBNET: {
			risk: 'MODERATE',
			reward: '~25% APY',
			description: 'Underground networks. Balanced risk/reward.'
		},
		DARKNET: {
			risk: 'HIGH',
			reward: '~80% APY',
			description: 'Illegal channels. High risk, high reward.'
		},
		BLACK_ICE: {
			risk: 'EXTREME',
			reward: '~200% APY',
			description: 'Military-grade ICE. Maximum risk, maximum reward.'
		}
	};
</script>

<Modal {open} title="JACK IN" maxWidth="md" {onclose}>
	{#if step === 'level'}
		<!-- Level Selection -->
		<Stack gap={3}>
			<p class="step-description">
				Select your security clearance level. Higher levels offer better yields but greater risk of being traced.
			</p>

			<div class="level-grid">
				{#each LEVELS as level}
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
							<Badge variant={level === 'BLACK_ICE' ? 'danger' : level === 'DARKNET' ? 'warning' : 'default'}>
								{desc.risk}
							</Badge>
						</Row>
						<div class="level-details">
							<span class="level-reward">{desc.reward}</span>
							<span class="level-death">
								{config.baseDeathRate > 0 ? `${(config.baseDeathRate * 100).toFixed(0)}% death rate` : 'No scans'}
							</span>
						</div>
						<p class="level-desc">{desc.description}</p>
						<div class="level-min">
							Min: <AmountDisplay amount={config.minStake} />
						</div>
					</button>
				{/each}
			</div>

			<Row justify="end" gap={2}>
				<Button variant="ghost" onclick={onclose}>Cancel</Button>
				<Button variant="primary" onclick={proceedToAmount}>
					Continue
				</Button>
			</Row>
		</Stack>

	{:else if step === 'amount'}
		<!-- Amount Input -->
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
					{levelDescriptions[selectedLevel].reward} · {(levelConfig.baseDeathRate * 100).toFixed(0)}% death rate
				</span>
			</div>

			<div class="amount-input-group">
				<label class="amount-label" for="amount-input">
					Amount to stake
				</label>
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

			<Row justify="end" gap={2}>
				<Button variant="ghost" onclick={goBack}>Back</Button>
				<Button variant="primary" onclick={proceedToConfirm} disabled={!amountValid}>
					Continue
				</Button>
			</Row>
		</Stack>

	{:else if step === 'confirm'}
		<!-- Confirmation -->
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

			<div class="warning-text">
				<Badge variant="warning">WARNING</Badge>
				<p>
					Once jacked in, you may lose your stake if traced during a scan. 
					Make sure you understand the risks.
				</p>
			</div>

			<Row justify="end" gap={2}>
				<Button variant="ghost" onclick={goBack}>Back</Button>
				<Button 
					variant="primary" 
					onclick={handleJackIn}
					loading={isSubmitting}
				>
					JACK IN
				</Button>
			</Row>
		</Stack>
	{/if}
</Modal>

<style>
	.step-description {
		color: var(--color-green-mid);
		font-size: var(--text-sm);
		line-height: var(--leading-relaxed);
	}

	.step-title {
		color: var(--color-green-bright);
		font-size: var(--text-lg);
		font-weight: var(--font-medium);
	}

	.back-btn {
		background: none;
		border: none;
		color: var(--color-green-mid);
		cursor: pointer;
		padding: var(--space-1);
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.back-btn:hover {
		color: var(--color-green-bright);
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
		border: 1px solid var(--color-bg-tertiary);
		padding: var(--space-3);
		cursor: pointer;
		text-align: left;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.level-option:hover {
		border-color: var(--level-color, var(--color-green-dim));
		background: var(--color-bg-tertiary);
	}

	.level-option.selected {
		border-color: var(--level-color, var(--color-green-bright));
		box-shadow: 0 0 10px var(--level-color, var(--color-green-glow));
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
		color: var(--color-green-dim);
		font-size: var(--text-xs);
		margin-top: var(--space-1);
	}

	.level-min {
		color: var(--color-green-dim);
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
		color: var(--color-green-dim);
		font-size: var(--text-sm);
	}

	.amount-input-group {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.amount-label {
		color: var(--color-green-mid);
		font-size: var(--text-sm);
	}

	.input-wrapper {
		display: flex;
		align-items: center;
		background: var(--color-bg-primary);
		border: 1px solid var(--color-green-dim);
		padding: var(--space-1);
	}

	.amount-input {
		flex: 1;
		background: transparent;
		border: none;
		color: var(--color-green-bright);
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		padding: var(--space-2);
		outline: none;
	}

	.amount-input::placeholder {
		color: var(--color-green-dim);
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
		color: var(--color-green-dim);
		font-size: var(--text-sm);
		padding: 0 var(--space-2);
	}

	.max-btn {
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-green-dim);
		color: var(--color-green-mid);
		font-size: var(--text-xs);
		padding: var(--space-1) var(--space-2);
		cursor: pointer;
		font-family: var(--font-mono);
	}

	.max-btn:hover {
		background: var(--color-green-dim);
		color: var(--color-bg-primary);
	}

	.input-error {
		color: var(--color-red);
		font-size: var(--text-xs);
	}

	.balance-info {
		color: var(--color-green-dim);
		font-size: var(--text-xs);
	}

	/* Confirmation */
	.confirm-label {
		color: var(--color-green-dim);
		font-size: var(--text-sm);
	}

	.confirm-value {
		color: var(--color-green-bright);
		font-size: var(--text-sm);
	}

	.warning-text {
		display: flex;
		align-items: flex-start;
		gap: var(--space-2);
		padding: var(--space-2);
		background: rgba(var(--color-amber-rgb), 0.1);
	}

	.warning-text p {
		color: var(--color-amber);
		font-size: var(--text-sm);
		line-height: var(--leading-relaxed);
	}
</style>
