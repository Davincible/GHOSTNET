<script lang="ts">
	import { SHIELD_COSTS } from '$lib/core/types/daily';
	import { Button } from '$lib/ui/primitives';

	interface Props {
		/** Whether shield is currently active */
		shieldActive: boolean;
		/** Shield expiry info */
		shieldExpiry?: string | null;
		/** Whether player can purchase a shield */
		canPurchase: boolean;
		/** Player's DATA balance */
		balance: bigint;
		/** Whether a purchase is in progress */
		isPurchasing: boolean;
		/** Callback to purchase shield */
		onPurchase: (days: 1 | 7) => void;
	}

	let { shieldActive, shieldExpiry, canPurchase, balance, isPurchasing, onPurchase }: Props =
		$props();

	// Shield options
	const SHIELD_OPTIONS = [
		{
			days: 1 as const,
			cost: SHIELD_COSTS.ONE_DAY,
			label: '1 DAY',
			description: 'Protect for 1 day',
		},
		{
			days: 7 as const,
			cost: SHIELD_COSTS.SEVEN_DAY,
			label: '7 DAYS',
			description: 'Best value - protect for a week',
			recommended: true,
		},
	];

	// Format cost
	function formatCost(cost: bigint): string {
		return Number(cost / 10n ** 18n).toLocaleString();
	}

	// Check if player can afford
	function canAfford(cost: bigint): boolean {
		return balance >= cost;
	}

	// Handle purchase
	function handlePurchase(days: 1 | 7) {
		if (canPurchase && !isPurchasing) {
			onPurchase(days);
		}
	}
</script>

<div class="shield-purchase">
	<header class="shield-header">
		<span class="header-icon">🛡️</span>
		<div class="header-text">
			<span class="header-title">STREAK SHIELD</span>
			<span class="header-desc">Protect your streak from missed days</span>
		</div>
	</header>

	{#if shieldActive && shieldExpiry}
		<div class="shield-active">
			<div class="active-icon">✓</div>
			<div class="active-text">
				<span class="active-title">SHIELD ACTIVE</span>
				<span class="active-expiry">{shieldExpiry}</span>
			</div>
		</div>
	{:else}
		<div class="shield-options">
			{#each SHIELD_OPTIONS as option (option.days)}
				{@const affordable = canAfford(option.cost)}
				<button
					class="shield-option"
					class:recommended={option.recommended}
					class:disabled={!affordable || isPurchasing}
					disabled={!canPurchase || !affordable || isPurchasing}
					onclick={() => handlePurchase(option.days)}
				>
					<div class="option-main">
						<span class="option-label">{option.label}</span>
						<span class="option-cost">{formatCost(option.cost)} DATA</span>
					</div>
					<span class="option-desc">{option.description}</span>
					{#if option.recommended}
						<span class="option-badge">BEST VALUE</span>
					{/if}
					{#if !affordable}
						<span class="option-warning">Insufficient balance</span>
					{/if}
				</button>
			{/each}
		</div>

		<p class="shield-note">
			Shields are burned (not transferred). They protect your streak if you miss a day within the
			shield period.
		</p>
	{/if}
</div>

<style>
	.shield-purchase {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		padding: var(--space-4);
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-default);
	}

	.shield-header {
		display: flex;
		align-items: center;
		gap: var(--space-3);
	}

	.header-icon {
		font-size: var(--text-2xl);
	}

	.header-text {
		display: flex;
		flex-direction: column;
		gap: var(--space-0-5);
	}

	.header-title {
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wide);
	}

	.header-desc {
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
	}

	/* Active shield state */
	.shield-active {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-3);
		background: rgba(0, 229, 204, 0.1);
		border: 1px solid var(--color-accent);
	}

	.active-icon {
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: var(--color-accent);
		color: var(--color-bg-primary);
		font-weight: var(--font-bold);
	}

	.active-text {
		display: flex;
		flex-direction: column;
		gap: var(--space-0-5);
	}

	.active-title {
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		color: var(--color-accent);
	}

	.active-expiry {
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
	}

	/* Shield options */
	.shield-options {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: var(--space-3);
	}

	.shield-option {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-default);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
		position: relative;
		text-align: left;
	}

	.shield-option:hover:not(:disabled) {
		border-color: var(--color-accent);
		background: var(--color-accent-glow);
	}

	.shield-option.recommended {
		border-color: var(--color-accent-dim);
	}

	.shield-option:disabled,
	.shield-option.disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.option-main {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.option-label {
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		color: var(--color-text-primary);
	}

	.option-cost {
		font-size: var(--text-xs);
		color: var(--color-accent);
		font-family: var(--font-mono);
	}

	.option-desc {
		font-size: var(--text-2xs);
		color: var(--color-text-tertiary);
	}

	.option-badge {
		position: absolute;
		top: -8px;
		right: var(--space-2);
		padding: var(--space-0-5) var(--space-1);
		background: var(--color-accent);
		color: var(--color-bg-primary);
		font-size: var(--text-2xs);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wide);
	}

	.option-warning {
		font-size: var(--text-2xs);
		color: var(--color-danger);
	}

	/* Note */
	.shield-note {
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
		line-height: 1.5;
	}

	/* Mobile */
	@media (max-width: 480px) {
		.shield-options {
			grid-template-columns: 1fr;
		}
	}
</style>
