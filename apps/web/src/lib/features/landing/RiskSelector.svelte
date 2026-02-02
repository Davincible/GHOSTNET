<script lang="ts">
	/**
	 * RiskSelector - Mode 2: Wallet Connected, No Position
	 *
	 * Progressive disclosure: After wallet connection, show clear risk levels.
	 * User picks a level and clicks JACK IN.
	 *
	 * Matches the vision:
	 * - CHOOSE YOUR RISK LEVEL header
	 * - Clear risk level cards with death rate + APY
	 * - User balance display
	 * - JACK IN as primary CTA
	 */

	import { formatWei } from '$lib/core/utils';

	type RiskLevel = 'VAULT' | 'MAINFRAME' | 'SUBNET' | 'DARKNET' | 'BLACK_ICE';

	interface Props {
		/** User's token balance */
		balance?: bigint;
		/** Token symbol */
		tokenSymbol?: string;
		/** Currently selected level */
		selectedLevel?: RiskLevel;
		/** Callback when Jack In is clicked with selected level */
		onJackIn?: (level: RiskLevel) => void;
		/** Callback to skip directly to command center (demo mode) */
		onSkip?: () => void;
	}

	let {
		balance = 1847n,
		tokenSymbol = '$DATA',
		selectedLevel = $bindable<RiskLevel>('SUBNET'),
		onJackIn,
		onSkip,
	}: Props = $props();

	interface LevelData {
		id: RiskLevel;
		name: string;
		deathRate: string;
		apy: string;
		riskLabel: string;
		colorVar: string;
	}

	const levels: LevelData[] = [
		{
			id: 'VAULT',
			name: 'THE VAULT',
			deathRate: '0%',
			apy: '100-500%',
			riskLabel: 'SAFE',
			colorVar: '--color-profit',
		},
		{
			id: 'MAINFRAME',
			name: 'MAINFRAME',
			deathRate: '2%',
			apy: '1,000%',
			riskLabel: 'CONSERVATIVE',
			colorVar: '--color-cyan',
		},
		{
			id: 'SUBNET',
			name: 'SUBNET',
			deathRate: '15%',
			apy: '5,000%',
			riskLabel: 'MEDIUM',
			colorVar: '--color-amber',
		},
		{
			id: 'DARKNET',
			name: 'DARKNET',
			deathRate: '40%',
			apy: '20,000%',
			riskLabel: 'HIGH RISK',
			colorVar: '--color-level-darknet',
		},
		{
			id: 'BLACK_ICE',
			name: 'BLACK ICE',
			deathRate: '90%',
			apy: '2x or 0',
			riskLabel: 'CASINO',
			colorVar: '--color-red',
		},
	];

	function handleSelect(level: RiskLevel) {
		selectedLevel = level;
	}

	function handleJackIn() {
		onJackIn?.(selectedLevel);
	}
</script>

<div class="risk-selector">
	<header class="header">
		<h1 class="title">CHOOSE YOUR RISK LEVEL</h1>
	</header>

	<!-- Risk Level Cards -->
	<div class="levels-container">
		{#each levels as level (level.id)}
			<button
				type="button"
				class="level-row"
				class:selected={selectedLevel === level.id}
				onclick={() => handleSelect(level.id)}
				style="--level-color: var({level.colorVar})"
			>
				<span class="level-name">{level.name}</span>
				<span class="level-death">{level.deathRate} death</span>
				<span class="level-apy">{level.apy} APY</span>
				<span class="level-label">[ {level.riskLabel} ]</span>
			</button>
			{#if level.id !== 'BLACK_ICE'}
				<div class="level-divider"></div>
			{/if}
		{/each}
	</div>

	<!-- Balance Display -->
	<div class="balance-display">
		<span class="balance-label">Your balance:</span>
		<span class="balance-value">{formatWei(balance, { compact: true })} {tokenSymbol}</span>
	</div>

	<!-- CTA -->
	<button class="cta-primary" onclick={handleJackIn}> JACK IN → </button>

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
		padding: var(--space-8) var(--space-4);
		max-width: 600px;
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

	/* ═══════════════════════════════════════════════════════════════
	   LEVELS CONTAINER
	   ═══════════════════════════════════════════════════════════════ */

	.levels-container {
		display: flex;
		flex-direction: column;
		width: 100%;
		background: rgba(0, 229, 204, 0.02);
		border: 1px solid var(--color-border-default);
		padding: var(--space-2);
	}

	.level-row {
		display: grid;
		grid-template-columns: 1fr auto auto auto;
		gap: var(--space-3);
		align-items: center;
		padding: var(--space-3) var(--space-4);
		background: transparent;
		border: none;
		cursor: pointer;
		font-family: var(--font-mono);
		text-align: left;
		transition: all 0.15s ease;
	}

	.level-row:hover {
		background: rgba(0, 229, 204, 0.05);
	}

	.level-row.selected {
		background: rgba(0, 229, 204, 0.08);
		border-left: 3px solid var(--level-color);
		margin-left: -3px;
	}

	.level-divider {
		height: 1px;
		background: var(--color-border-subtle);
		margin: 0 var(--space-4);
	}

	.level-name {
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wide);
	}

	.level-death {
		font-size: var(--text-sm);
		color: var(--level-color);
		min-width: 10ch;
		text-align: center;
	}

	.level-apy {
		font-size: var(--text-sm);
		color: var(--color-profit);
		min-width: 12ch;
		text-align: center;
	}

	.level-label {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		min-width: 14ch;
		text-align: right;
	}

	/* ═══════════════════════════════════════════════════════════════
	   BALANCE
	   ═══════════════════════════════════════════════════════════════ */

	.balance-display {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		font-family: var(--font-mono);
		font-size: var(--text-base);
	}

	.balance-label {
		color: var(--color-text-tertiary);
	}

	.balance-value {
		color: var(--color-accent);
		font-weight: var(--font-bold);
	}

	/* ═══════════════════════════════════════════════════════════════
	   CTA
	   ═══════════════════════════════════════════════════════════════ */

	.cta-primary {
		padding: var(--space-4) var(--space-10);
		background: var(--color-accent);
		color: var(--color-bg-void);
		border: 2px solid var(--color-accent);
		font-family: var(--font-mono);
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
		cursor: pointer;
		transition: all 0.2s ease;
		box-shadow: 0 0 20px var(--color-accent-glow);
	}

	.cta-primary:hover {
		background: var(--color-accent-bright);
		transform: scale(1.02);
		box-shadow: 0 0 40px var(--color-accent-glow);
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

	@media (max-width: 640px) {
		.level-row {
			grid-template-columns: 1fr auto;
			grid-template-rows: auto auto;
			gap: var(--space-1) var(--space-2);
		}

		.level-name {
			grid-column: 1;
		}

		.level-label {
			grid-column: 2;
			text-align: right;
		}

		.level-death {
			grid-column: 1;
			text-align: left;
			font-size: var(--text-xs);
		}

		.level-apy {
			grid-column: 2;
			text-align: right;
			font-size: var(--text-xs);
		}
	}
</style>
