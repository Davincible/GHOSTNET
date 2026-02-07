<script lang="ts">
	/**
	 * BigSteps - Experimental component
	 *
	 * Goal: Make the 4-step game loop crystal clear with larger typography.
	 * Each step is its own visual block, easy to scan.
	 *
	 * Key design decisions:
	 * - Large numbers for visual anchoring
	 * - Clear step labels
	 * - One sentence per step (no complexity)
	 * - Vertical layout for easy scanning
	 */

	import { Button } from '$lib/ui/primitives';

	interface Props {
		/** Callback when Connect Wallet is triggered */
		onConnectWallet?: () => void;
		/** Callback when Continue is clicked (already connected) */
		onContinue?: () => void;
		/** Whether user is already connected */
		isConnected?: boolean;
		/** Whether to show the CTA button */
		showCta?: boolean;
		/** Visual style variant */
		variant?: 'default' | 'compact';
	}

	let {
		onConnectWallet,
		onContinue,
		isConnected = false,
		showCta = true,
		variant = 'default',
	}: Props = $props();

	// Button action depends on connection state
	function handleCtaClick() {
		if (isConnected && onContinue) {
			onContinue();
		} else if (onConnectWallet) {
			onConnectWallet();
		}
	}

	// Button text depends on connection state
	const ctaText = $derived(isConnected ? 'CONTINUE' : 'CONNECT WALLET TO START');

	type StepStatus = 'current' | 'future';

	interface Step {
		number: string;
		label: string;
		description: string;
		status: StepStatus;
	}

	const steps: Step[] = [
		{
			number: '01',
			label: 'JACK IN',
			description: 'Connect wallet. Pick a risk level. Stake your $DATA.',
			status: 'current',
		},
		{
			number: '02',
			label: 'EARN',
			description: "Yield accrues every second while you're in.",
			status: 'future',
		},
		{
			number: '03',
			label: 'SURVIVE',
			description: 'Periodic scans roll for death. Get traced = lose stake.',
			status: 'future',
		},
		{
			number: '04',
			label: 'EXTRACT',
			description: 'Cash out anytime. Or stay in and keep earning.',
			status: 'future',
		},
	];
</script>

<div class="steps-container" class:compact={variant === 'compact'}>
	<ol class="steps-list">
		{#each steps as step, index (step.number)}
			<li class="step" class:step-current={step.status === 'current'}>
				<div class="step-indicator">
					<span class="step-number">{step.number}</span>
					{#if index < steps.length - 1}
						<div class="step-connector"></div>
					{/if}
				</div>
				<div class="step-content">
					<span class="step-label">{step.label}</span>
					<span class="step-description">{step.description}</span>
				</div>
			</li>
		{/each}
	</ol>

	{#if showCta}
		<div class="cta-wrapper">
			<div class="cta-button-wrapper">
				<Button variant="inverted" onclick={handleCtaClick} fullWidth>
					{ctaText}
				</Button>
			</div>
		</div>
	{/if}
</div>

<style>
	.steps-container {
		display: flex;
		flex-direction: column;
		gap: var(--space-5);
		padding: var(--space-2) 0;
		background: transparent;
	}

	.steps-container.compact {
		gap: var(--space-3);
	}

	/* ═══════════════════════════════════════════════════════════════
	   STEPS LIST
	   ═══════════════════════════════════════════════════════════════ */

	.steps-list {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		list-style: none;
		margin: 0;
		padding: 0;
	}

	/* ═══════════════════════════════════════════════════════════════
	   STEP ITEM
	   ═══════════════════════════════════════════════════════════════ */

	.step {
		display: flex;
		gap: var(--space-4);
		position: relative;
	}

	/* ═══════════════════════════════════════════════════════════════
	   STEP INDICATOR (number + connector line)
	   ═══════════════════════════════════════════════════════════════ */

	.step-indicator {
		display: flex;
		flex-direction: column;
		align-items: center;
		position: relative;
	}

	.step-number {
		font-family: var(--font-mono);
		font-size: var(--text-2xl);
		font-weight: var(--font-bold);
		color: var(--color-text-muted);
		line-height: 1;
		min-width: 3ch;
		text-align: center;
		transition:
			color 0.2s,
			text-shadow 0.2s;
	}

	.steps-container.compact .step-number {
		font-size: var(--text-lg);
	}

	.step-current .step-number {
		color: var(--color-accent);
		text-shadow: 0 0 15px var(--color-accent-glow);
	}

	.step-connector {
		width: 2px;
		height: var(--space-8);
		background: linear-gradient(to bottom, var(--color-border-default), transparent);
		margin-top: var(--space-2);
	}

	.steps-container.compact .step-connector {
		height: var(--space-4);
	}

	/* ═══════════════════════════════════════════════════════════════
	   STEP CONTENT
	   ═══════════════════════════════════════════════════════════════ */

	.step-content {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		padding-bottom: var(--space-4);
	}

	.steps-container.compact .step-content {
		padding-bottom: var(--space-2);
	}

	.step-label {
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wider);
	}

	.steps-container.compact .step-label {
		font-size: var(--text-base);
	}

	.step-current .step-label {
		color: var(--color-accent);
	}

	.step-description {
		font-family: var(--font-mono);
		font-size: var(--text-base);
		color: var(--color-text-tertiary);
		line-height: var(--leading-relaxed);
		max-width: 40ch;
	}

	.steps-container.compact .step-description {
		font-size: var(--text-sm);
	}

	/* ═══════════════════════════════════════════════════════════════
	   CTA
	   ═══════════════════════════════════════════════════════════════ */

	.cta-wrapper {
		padding-top: var(--space-2);
		border-top: 1px solid var(--color-border-subtle);
	}

	/* Rotating gradient border effect - matches GettingStartedPanel */
	.cta-button-wrapper {
		position: relative;
		width: 100%;
		padding: 2px;
		overflow: hidden;
		border-radius: 2px;
	}

	/* Rotating gradient layer - 4x larger to cover all corners during rotation */
	.cta-button-wrapper::before {
		content: '';
		position: absolute;
		inset: -100%;
		background: conic-gradient(
			from 0deg,
			var(--color-bg-secondary) 0deg,
			var(--color-bg-secondary) 60deg,
			var(--color-accent) 90deg,
			var(--color-accent-bright) 180deg,
			var(--color-accent) 270deg,
			var(--color-bg-secondary) 300deg,
			var(--color-bg-secondary) 360deg
		);
		animation: rotate-smooth 3s linear infinite;
		z-index: 0;
	}

	/* Mask layer - creates the border effect by covering center */
	.cta-button-wrapper::after {
		content: '';
		position: absolute;
		inset: 2px;
		background: var(--color-bg-secondary);
		border-radius: 1px;
		z-index: 1;
	}

	/* Button sits on top */
	.cta-button-wrapper :global(.btn) {
		position: relative;
		z-index: 2;
	}

	@keyframes rotate-smooth {
		from {
			transform: rotate(0deg);
		}
		to {
			transform: rotate(360deg);
		}
	}

	/* Pause animation on hover */
	.cta-button-wrapper:hover::before {
		animation-play-state: paused;
	}
</style>
