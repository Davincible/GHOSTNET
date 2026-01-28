<script lang="ts">
	import { browser } from '$app/environment';
	import { parseUnits, formatUnits } from 'viem';
	import { wallet } from '$lib/web3/wallet.svelte';
	import { parseContractError } from '$lib/web3/contracts';
	import { presale } from './presale.store.svelte';
	import { previewContribution, contribute } from './presale-contracts';
	import { PricingMode } from './types';
	import type { PresaleConfig, PresaleProgress, ContributionPreview } from './types';
	import Box from '$lib/ui/terminal/Box.svelte';
	import Button from '$lib/ui/primitives/Button.svelte';

	// ─────────────────────────────────────────────────────────────
	// Props
	// ─────────────────────────────────────────────────────────────

	interface Props {
		config: PresaleConfig;
		progress: PresaleProgress;
		pricingMode: PricingMode;
		userContribution: bigint;
		userAllocation: bigint;
		oncontributed?: () => void;
	}

	let {
		config,
		progress,
		pricingMode,
		userContribution,
		userAllocation,
		oncontributed,
	}: Props = $props();

	// ─────────────────────────────────────────────────────────────
	// State
	// ─────────────────────────────────────────────────────────────

	let inputValue = $state('');
	let preview = $state<ContributionPreview | null>(null);
	let previewLoading = $state(false);
	let previewError = $state<string | null>(null);
	let isSubmitting = $state(false);
	let txError = $state<string | null>(null);
	let debounceTimer = $state<ReturnType<typeof setTimeout> | null>(null);

	// ─────────────────────────────────────────────────────────────
	// Derived
	// ─────────────────────────────────────────────────────────────

	/** Whether operator has already contributed and repeat contributions are blocked */
	let alreadyContributed = $derived(
		userContribution > 0n && !config.allowMultipleContributions,
	);

	/** Parsed wei from input (0n if invalid) */
	let parsedWei = $derived.by(() => {
		if (!inputValue.trim()) return 0n;
		try {
			return parseUnits(inputValue, 18);
		} catch {
			return 0n;
		}
	});

	/** Remaining wallet cap (how much more ETH the operator can contribute) */
	let remainingCap = $derived.by(() => {
		if (config.maxPerWallet === 0n) return config.maxContribution;
		const remaining = config.maxPerWallet - userContribution;
		return remaining > 0n ? remaining : 0n;
	});

	/** Effective max for this contribution (min of maxContribution, remaining cap, balance) */
	let effectiveMax = $derived.by(() => {
		let max = config.maxContribution;
		if (config.maxPerWallet > 0n) {
			const cap = config.maxPerWallet - userContribution;
			if (cap < max) max = cap;
		}
		if (wallet.ethBalance < max) max = wallet.ethBalance;
		return max > 0n ? max : 0n;
	});

	/** Validation result */
	let validation = $derived.by<{ valid: boolean; message: string | null }>(() => {
		if (!inputValue.trim()) return { valid: false, message: null };

		if (parsedWei === 0n) return { valid: false, message: 'INVALID AMOUNT' };

		if (parsedWei < config.minContribution) {
			return {
				valid: false,
				message: `MINIMUM: ${formatEth(config.minContribution)} ETH`,
			};
		}

		if (parsedWei > config.maxContribution) {
			return {
				valid: false,
				message: `MAXIMUM: ${formatEth(config.maxContribution)} ETH`,
			};
		}

		if (wallet.isConnected && parsedWei > wallet.ethBalance) {
			return { valid: false, message: 'INSUFFICIENT ETH' };
		}

		if (config.maxPerWallet > 0n && parsedWei + userContribution > config.maxPerWallet) {
			return {
				valid: false,
				message: `WALLET CAP: ${formatEth(config.maxPerWallet)} ETH (CONTRIBUTED: ${formatEth(userContribution)})`,
			};
		}

		return { valid: true, message: null };
	});

	/** Minimum allocation after 1% slippage */
	let minAllocation = $derived(
		preview ? (preview.allocation * 99n) / 100n : 0n,
	);

	/** Price impact percentage (bonding curve only) */
	let priceImpact = $derived.by(() => {
		if (pricingMode !== PricingMode.BONDING_CURVE) return null;
		if (!preview || progress.currentPrice === 0n) return null;

		const delta = preview.effectivePrice - progress.currentPrice;
		// (delta / currentPrice) * 100, using fixed-point math
		const impactBps = Number((delta * 10000n) / progress.currentPrice);
		return impactBps / 100;
	});

	/** Whether the submit button should be enabled */
	let canSubmit = $derived(
		validation.valid && preview !== null && !isSubmitting && !previewLoading,
	);

	// ─────────────────────────────────────────────────────────────
	// Effects
	// ─────────────────────────────────────────────────────────────

	/** Debounced preview fetch when input changes */
	$effect(() => {
		// Read parsedWei to track it
		const amount = parsedWei;

		if (debounceTimer) clearTimeout(debounceTimer);

		if (amount === 0n || !validation.valid) {
			preview = null;
			previewError = null;
			previewLoading = false;
			return;
		}

		previewLoading = true;
		previewError = null;

		debounceTimer = setTimeout(async () => {
			try {
				preview = await previewContribution(amount);
				previewError = null;
			} catch (err) {
				preview = null;
				previewError = parseContractError(err);
			} finally {
				previewLoading = false;
			}
		}, 500);

		return () => {
			if (debounceTimer) clearTimeout(debounceTimer);
		};
	});

	/** Auto-dismiss tx error after 5 seconds */
	$effect(() => {
		if (!txError) return;

		const timer = setTimeout(() => {
			txError = null;
		}, 5_000);

		return () => clearTimeout(timer);
	});

	// ─────────────────────────────────────────────────────────────
	// Actions
	// ─────────────────────────────────────────────────────────────

	function handleInput(event: Event) {
		const target = event.target as HTMLInputElement;
		// Allow only digits and a single decimal point
		const cleaned = target.value.replace(/[^0-9.]/g, '').replace(/(\..*)\./g, '$1');
		inputValue = cleaned;
		target.value = cleaned;
	}

	function handleMax() {
		if (effectiveMax <= 0n) return;
		inputValue = formatUnits(effectiveMax, 18);
	}

	async function handleSubmit() {
		if (!canSubmit || !preview) return;

		isSubmitting = true;
		txError = null;

		try {
			await contribute(parsedWei, minAllocation);
			await presale.refresh();
			inputValue = '';
			preview = null;
			oncontributed?.();
		} catch (err) {
			txError = parseContractError(err);
		} finally {
			isSubmitting = false;
		}
	}

	function handleConnect() {
		wallet.connect();
	}

	function handleSwitchChain() {
		wallet.switchChain();
	}

	// ─────────────────────────────────────────────────────────────
	// Formatting
	// ─────────────────────────────────────────────────────────────

	function formatEth(wei: bigint): string {
		return formatUnits(wei, 18);
	}

	function formatData(amount: bigint): string {
		const num = Number(formatUnits(amount, 18));
		return num.toLocaleString('en-US', { maximumFractionDigits: 0 });
	}

	function formatPrice(price: bigint): string {
		return Number(formatUnits(price, 18)).toFixed(6);
	}
</script>

<Box title="ACQUIRE $DATA" variant="single" borderColor="cyan" borderFill>
	{#if alreadyContributed}
		<!-- Already contributed, no repeat allowed -->
		<div class="already-contributed">
			<p class="label">STATUS</p>
			<p class="value accent">ALREADY CONTRIBUTED</p>
			<div class="row">
				<div class="stat">
					<span class="label">CONTRIBUTED</span>
					<span class="value">{formatEth(userContribution)} ETH</span>
				</div>
				<div class="stat">
					<span class="label">ALLOCATED</span>
					<span class="value">{formatData(userAllocation)} $DATA</span>
				</div>
			</div>
		</div>
	{:else}
		<!-- Input Row -->
		<div class="input-row">
			<label class="input-label" for="eth-amount">AMOUNT (ETH):</label>
			<div class="input-wrapper">
				<input
					id="eth-amount"
					type="text"
					inputmode="decimal"
					autocomplete="off"
					placeholder="0.0"
					value={inputValue}
					oninput={handleInput}
					disabled={isSubmitting}
					class="eth-input"
				/>
				<button
					type="button"
					class="max-btn"
					onclick={handleMax}
					disabled={isSubmitting || !wallet.isConnected}
				>
					MAX
				</button>
			</div>
		</div>

		<!-- Preview Section -->
		{#if previewLoading}
			<div class="preview">
				<div class="preview-row">
					<span class="label">CALCULATING...</span>
					<span class="value dim">▓▓▓▓▓▓▓▓</span>
				</div>
			</div>
		{:else if previewError}
			<div class="preview">
				<div class="preview-row error-text">
					<span class="label">ERROR</span>
					<span class="value">{previewError}</span>
				</div>
			</div>
		{:else if preview}
			<div class="preview">
				<div class="preview-row">
					<span class="label">YOU RECEIVE:</span>
					<span class="value accent">{formatData(preview.allocation)} $DATA</span>
				</div>
				<div class="preview-row">
					<span class="label">PRICE:</span>
					<span class="value">{formatPrice(preview.effectivePrice)} ETH / $DATA</span>
				</div>
				{#if priceImpact !== null}
					<div class="preview-row">
						<span class="label">PRICE IMPACT:</span>
						<span class="value" class:warn={priceImpact > 1} class:error-text={priceImpact > 5}>
							+{priceImpact.toFixed(2)}%
						</span>
					</div>
				{/if}
				<div class="preview-row">
					<span class="label">SLIPPAGE:</span>
					<span class="value dim">MIN {formatData(minAllocation)} $DATA</span>
				</div>
			</div>
		{/if}

		<!-- Validation Message -->
		{#if validation.message}
			<div class="validation-msg">{validation.message}</div>
		{/if}

		<!-- Action Button -->
		<div class="action">
			{#if !wallet.isConnected}
				<Button variant="primary" size="lg" fullWidth onclick={handleConnect}>
					CONNECT WALLET
				</Button>
			{:else if !wallet.isCorrectChain}
				<Button variant="secondary" size="lg" fullWidth onclick={handleSwitchChain}>
					SWITCH NETWORK
				</Button>
			{:else}
				<Button
					variant="primary"
					size="lg"
					fullWidth
					loading={isSubmitting}
					disabled={!canSubmit}
					onclick={handleSubmit}
				>
					{isSubmitting ? 'TRANSMITTING...' : 'ACQUIRE $DATA'}
				</Button>
			{/if}
		</div>

		<!-- Transaction Error -->
		{#if txError}
			<div class="tx-error">{txError}</div>
		{/if}
	{/if}
</Box>

<style>
	/* ── Layout ────────────────────────────────────────────── */

	.already-contributed {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.row {
		display: flex;
		gap: var(--space-6);
	}

	.stat {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	/* ── Input ─────────────────────────────────────────────── */

	.input-row {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		margin-bottom: var(--space-4);
	}

	.input-label {
		flex-shrink: 0;
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider);
	}

	.input-wrapper {
		display: flex;
		align-items: center;
		flex: 1;
		gap: var(--space-2);
	}

	.eth-input {
		flex: 1;
		background: transparent;
		border: none;
		border-bottom: 1px solid var(--color-border-default);
		font-family: var(--font-mono);
		font-size: var(--text-base);
		color: var(--color-accent);
		padding: var(--space-2) 0;
		outline: none;
		letter-spacing: var(--tracking-wider);
	}

	.eth-input::placeholder {
		color: var(--color-text-secondary);
		opacity: 0.4;
	}

	.eth-input:focus {
		border-bottom-color: var(--color-accent);
	}

	.eth-input:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.max-btn {
		flex-shrink: 0;
		background: transparent;
		border: 1px solid var(--color-border-default);
		color: var(--color-text-secondary);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		padding: var(--space-1) var(--space-2);
		cursor: pointer;
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider);
		transition: all var(--duration-fast) var(--ease-default);
	}

	.max-btn:hover:not(:disabled) {
		color: var(--color-accent);
		border-color: var(--color-accent);
	}

	.max-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	/* ── Preview ───────────────────────────────────────────── */

	.preview {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		margin-bottom: var(--space-4);
		padding: var(--space-3) 0;
		border-top: 1px solid var(--color-border-subtle);
	}

	.preview-row {
		display: flex;
		justify-content: space-between;
		align-items: baseline;
		gap: var(--space-4);
	}

	/* ── Typography ────────────────────────────────────────── */

	.label {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider);
	}

	.value {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-primary);
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider);
	}

	.accent {
		color: var(--color-accent);
	}

	.dim {
		color: var(--color-text-secondary);
	}

	.warn {
		color: var(--color-amber);
	}

	.error-text {
		color: var(--color-red);
	}

	/* ── Validation ────────────────────────────────────────── */

	.validation-msg {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-red);
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider);
		margin-bottom: var(--space-3);
	}

	/* ── Action ────────────────────────────────────────────── */

	.action {
		margin-top: var(--space-2);
	}

	/* ── Transaction Error ─────────────────────────────────── */

	.tx-error {
		margin-top: var(--space-3);
		padding: var(--space-2);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-red);
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider);
		border: 1px solid var(--color-red-dim);
		background: transparent;
	}
</style>
