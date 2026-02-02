<script lang="ts">
	/**
	 * RiskSelector - Mode 2: Wallet Connected, No Position
	 *
	 * Complete jack-in flow in a single view:
	 * - Select risk level (left/top)
	 * - Enter amount + confirm (right/bottom)
	 * - Single JACK IN button executes the transaction
	 */

	import { formatWei } from '$lib/core/utils';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import { getToasts } from '$lib/ui/toast';
	import { LEVEL_CONFIG, type Level } from '$lib/core/types';
	import { parseUnits, formatUnits } from 'viem';
	import { Badge } from '$lib/ui/primitives';
	import { AmountDisplay } from '$lib/ui/data-display';

	interface Props {
		/** Token symbol */
		tokenSymbol?: string;
		/** Callback to skip directly to command center (demo mode) */
		onSkip?: () => void;
	}

	let { tokenSymbol = '$DATA', onSkip }: Props = $props();

	const provider = getProvider();
	const toast = getToasts();

	// State
	let selectedLevel = $state<Level>('SUBNET');
	let amountInput = $state('');
	let isSubmitting = $state(false);

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
			return `Min ${minStakeFormatted} for ${selectedLevel}`;
		}
		if (parsedAmount > userBalance) {
			return 'Insufficient balance';
		}
		return null;
	});

	interface LevelData {
		id: Level;
		name: string;
		deathRate: number;
		apy: string;
		riskLabel: string;
		colorVar: string;
		description: string;
	}

	const levels: LevelData[] = [
		{
			id: 'VAULT',
			name: 'THE VAULT',
			deathRate: 0,
			apy: '0%',
			riskLabel: 'SAFE',
			colorVar: '--color-profit',
			description: 'Safe storage. No scans.',
		},
		{
			id: 'MAINFRAME',
			name: 'MAINFRAME',
			deathRate: 2,
			apy: '~5%',
			riskLabel: 'MINIMAL',
			colorVar: '--color-cyan',
			description: 'Corporate systems. 24h scans.',
		},
		{
			id: 'SUBNET',
			name: 'SUBNET',
			deathRate: 15,
			apy: '~25%',
			riskLabel: 'MODERATE',
			colorVar: '--color-amber',
			description: 'Underground. 8h scans.',
		},
		{
			id: 'DARKNET',
			name: 'DARKNET',
			deathRate: 40,
			apy: '~80%',
			riskLabel: 'HIGH',
			colorVar: '--color-level-darknet',
			description: 'Illegal channels. 2h scans.',
		},
		{
			id: 'BLACK_ICE',
			name: 'BLACK ICE',
			deathRate: 90,
			apy: '~200%',
			riskLabel: 'EXTREME',
			colorVar: '--color-red',
			description: 'Military-grade. 30m scans.',
		},
	];

	function handleSelect(level: Level) {
		selectedLevel = level;
		// Pre-fill minimum stake for new level
		const config = LEVEL_CONFIG[level];
		amountInput = Number(formatUnits(config.minStake, 18)).toString();
	}

	function setMaxAmount() {
		amountInput = userBalanceFormatted.toString();
	}

	async function handleJackIn() {
		if (isSubmitting || !amountValid) return;
		isSubmitting = true;

		try {
			await provider.jackIn(selectedLevel, parsedAmount);
			toast.success(`Jacked in at ${selectedLevel}`);
			// The page will automatically transition to command-center mode
			// because provider.position will now be set
		} catch (err) {
			console.error('Jack In failed:', err);
			const message = err instanceof Error ? err.message : 'Jack In failed';
			toast.error(message);
		} finally {
			isSubmitting = false;
		}
	}

	// Pre-fill amount on mount
	$effect(() => {
		if (!amountInput) {
			amountInput = minStakeFormatted.toString();
		}
	});
</script>

<div class="risk-selector">
	<header class="header">
		<h1 class="title">JACK INTO THE NETWORK</h1>
		<p class="subtitle">Select risk level and stake amount</p>
	</header>

	<div class="main-content">
		<!-- Left: Level Selection -->
		<div class="levels-panel">
			<div class="panel-header">RISK LEVEL</div>
			<div class="levels-list">
				{#each levels as level (level.id)}
					{@const config = LEVEL_CONFIG[level.id]}
					<button
						type="button"
						class="level-row"
						class:selected={selectedLevel === level.id}
						onclick={() => handleSelect(level.id)}
						style="--level-color: var({level.colorVar})"
					>
						<div class="level-main">
							<span class="level-name">{level.name}</span>
							<span class="level-desc">{level.description}</span>
						</div>
						<div class="level-stats">
							<span class="level-death" class:zero={level.deathRate === 0}>
								{level.deathRate}% death
							</span>
							<span class="level-apy">{level.apy} APY</span>
						</div>
						<div class="level-meta">
							<span class="level-min">Min: <AmountDisplay amount={config.minStake} /></span>
						</div>
					</button>
				{/each}
			</div>
		</div>

		<!-- Right: Amount + Action -->
		<div class="action-panel">
			<div class="panel-header">STAKE AMOUNT</div>

			<div class="selected-level">
				<span class="selected-name">{selectedLevel}</span>
				<Badge
					variant={selectedLevel === 'BLACK_ICE'
						? 'danger'
						: selectedLevel === 'DARKNET'
							? 'warning'
							: 'default'}
				>
					{levels.find((l) => l.id === selectedLevel)?.riskLabel}
				</Badge>
			</div>

			<div class="amount-section">
				<div class="input-wrapper" class:error={!!amountError}>
					<input
						type="number"
						class="amount-input"
						bind:value={amountInput}
						placeholder="0.00"
						min="0"
						step="any"
						disabled={isSubmitting}
					/>
					<span class="input-suffix">{tokenSymbol}</span>
					<button class="max-btn" onclick={setMaxAmount} disabled={isSubmitting}>MAX</button>
				</div>
				{#if amountError}
					<span class="input-error">{amountError}</span>
				{/if}
				<div class="balance-row">
					<span class="balance-label">Balance:</span>
					<span class="balance-value">{formatWei(userBalance)} {tokenSymbol}</span>
				</div>
			</div>

			<div class="summary">
				<div class="summary-row">
					<span>Death Rate</span>
					<span class="summary-value danger"
						>{levels.find((l) => l.id === selectedLevel)?.deathRate}%</span
					>
				</div>
				<div class="summary-row">
					<span>Est. APY</span>
					<span class="summary-value profit">{levels.find((l) => l.id === selectedLevel)?.apy}</span
					>
				</div>
			</div>

			<button
				class="cta-primary"
				onclick={handleJackIn}
				disabled={!amountValid || isSubmitting}
				class:loading={isSubmitting}
			>
				{#if isSubmitting}
					JACKING IN...
				{:else}
					JACK IN →
				{/if}
			</button>

			<p class="warning">
				⚠ You may lose your stake if traced during a scan
			</p>
		</div>
	</div>

	<!-- Subtle skip link -->
	{#if onSkip}
		<button class="skip-link" onclick={onSkip}>skip to demo →</button>
	{/if}
</div>

<style>
	.risk-selector {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-6);
		padding: var(--space-6) var(--space-4);
		max-width: 900px;
		width: 100%;
		margin: 0 auto;
	}

	/* ═══════════════════════════════════════════════════════════════
	   HEADER
	   ═══════════════════════════════════════════════════════════════ */

	.header {
		text-align: center;
	}

	.title {
		font-family: var(--font-mono);
		font-size: clamp(1.25rem, 4vw, 1.75rem);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wider);
		margin: 0;
	}

	.subtitle {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
		margin: var(--space-2) 0 0;
	}

	/* ═══════════════════════════════════════════════════════════════
	   MAIN CONTENT - TWO COLUMN
	   ═══════════════════════════════════════════════════════════════ */

	.main-content {
		display: grid;
		grid-template-columns: 1.2fr 1fr;
		gap: var(--space-4);
		width: 100%;
	}

	.panel-header {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-widest);
		padding-bottom: var(--space-2);
		border-bottom: 1px solid var(--color-border-subtle);
		margin-bottom: var(--space-3);
	}

	/* ═══════════════════════════════════════════════════════════════
	   LEVELS PANEL (LEFT)
	   ═══════════════════════════════════════════════════════════════ */

	.levels-panel {
		background: rgba(0, 229, 204, 0.02);
		border: 1px solid var(--color-border-default);
		padding: var(--space-4);
	}

	.levels-list {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.level-row {
		display: grid;
		grid-template-columns: 1fr auto auto;
		gap: var(--space-2);
		align-items: center;
		padding: var(--space-3);
		background: transparent;
		border: 1px solid transparent;
		cursor: pointer;
		font-family: var(--font-mono);
		text-align: left;
		transition: all 0.15s ease;
	}

	.level-row:hover {
		background: rgba(0, 229, 204, 0.05);
		border-color: var(--color-border-subtle);
	}

	.level-row.selected {
		background: rgba(0, 229, 204, 0.08);
		border-color: var(--level-color);
		box-shadow: inset 3px 0 0 var(--level-color);
	}

	.level-main {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.level-name {
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
	}

	.level-desc {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
	}

	.level-stats {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		gap: 2px;
	}

	.level-death {
		font-size: var(--text-xs);
		color: var(--level-color);
	}

	.level-death.zero {
		color: var(--color-profit);
	}

	.level-apy {
		font-size: var(--text-xs);
		color: var(--color-profit);
	}

	.level-meta {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
	}

	.level-min {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
	}

	/* ═══════════════════════════════════════════════════════════════
	   ACTION PANEL (RIGHT)
	   ═══════════════════════════════════════════════════════════════ */

	.action-panel {
		background: rgba(0, 229, 204, 0.02);
		border: 1px solid var(--color-border-default);
		padding: var(--space-4);
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	.selected-level {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: var(--space-2) var(--space-3);
		background: var(--color-bg-secondary);
	}

	.selected-name {
		font-family: var(--font-mono);
		font-size: var(--text-base);
		font-weight: var(--font-bold);
		color: var(--color-accent);
	}

	.amount-section {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.input-wrapper {
		display: flex;
		align-items: center;
		background: var(--color-bg-primary);
		border: 1px solid var(--color-border-default);
		padding: var(--space-1);
		transition: border-color 0.15s ease;
	}

	.input-wrapper:focus-within {
		border-color: var(--color-accent);
	}

	.input-wrapper.error {
		border-color: var(--color-red);
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
		min-width: 0;
	}

	.amount-input::placeholder {
		color: var(--color-text-muted);
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
		font-family: var(--font-mono);
	}

	.max-btn {
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-default);
		color: var(--color-text-secondary);
		font-size: var(--text-xs);
		padding: var(--space-1) var(--space-2);
		cursor: pointer;
		font-family: var(--font-mono);
		transition: all 0.15s ease;
	}

	.max-btn:hover:not(:disabled) {
		background: var(--color-accent);
		color: var(--color-bg-void);
		border-color: var(--color-accent);
	}

	.max-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.input-error {
		color: var(--color-red);
		font-size: var(--text-xs);
		font-family: var(--font-mono);
	}

	.balance-row {
		display: flex;
		justify-content: space-between;
		font-size: var(--text-xs);
		font-family: var(--font-mono);
	}

	.balance-label {
		color: var(--color-text-muted);
	}

	.balance-value {
		color: var(--color-text-secondary);
	}

	.summary {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		padding: var(--space-3);
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-subtle);
	}

	.summary-row {
		display: flex;
		justify-content: space-between;
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
	}

	.summary-value {
		font-weight: var(--font-bold);
	}

	.summary-value.danger {
		color: var(--color-red);
	}

	.summary-value.profit {
		color: var(--color-profit);
	}

	/* ═══════════════════════════════════════════════════════════════
	   CTA
	   ═══════════════════════════════════════════════════════════════ */

	.cta-primary {
		width: 100%;
		padding: var(--space-4);
		background: var(--color-accent);
		color: var(--color-bg-void);
		border: 2px solid var(--color-accent);
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
		cursor: pointer;
		transition: all 0.2s ease;
		box-shadow: 0 0 20px var(--color-accent-glow);
	}

	.cta-primary:hover:not(:disabled) {
		background: var(--color-accent-bright);
		transform: scale(1.02);
		box-shadow: 0 0 40px var(--color-accent-glow);
	}

	.cta-primary:disabled {
		opacity: 0.5;
		cursor: not-allowed;
		transform: none;
		box-shadow: none;
	}

	.cta-primary.loading {
		animation: pulse 1.5s ease-in-out infinite;
	}

	@keyframes pulse {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.7;
		}
	}

	.warning {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-amber);
		text-align: center;
		margin: 0;
	}

	/* ═══════════════════════════════════════════════════════════════
	   SKIP LINK
	   ═══════════════════════════════════════════════════════════════ */

	.skip-link {
		margin-top: var(--space-2);
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
	   RESPONSIVE
	   ═══════════════════════════════════════════════════════════════ */

	@media (max-width: 768px) {
		.main-content {
			grid-template-columns: 1fr;
		}

		.level-row {
			grid-template-columns: 1fr auto;
		}

		.level-meta {
			display: none;
		}
	}
</style>
