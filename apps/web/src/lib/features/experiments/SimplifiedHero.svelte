<script lang="ts">
	/**
	 * SimplifiedHero - Experimental component
	 *
	 * Goal: Communicate the value proposition in 5 seconds or less.
	 * Uses larger typography, simpler language, and a single CTA.
	 *
	 * Key differences from WelcomePanel:
	 * - No carousel/slides - everything visible at once
	 * - Much larger typography
	 * - Simple 3-step explanation
	 * - Single prominent CTA
	 * - Terminal aesthetic is background texture, not primary content
	 */

	interface Props {
		/** Callback when Jack In is triggered */
		onJackIn?: () => void;
		/** Callback when Watch Feed is triggered */
		onWatchFeed?: () => void;
		/** Whether to show the terminal decorations (scanlines) */
		showDecorations?: boolean;
	}

	let { onJackIn, onWatchFeed, showDecorations = true }: Props = $props();
</script>

<div class="hero-container">
	{#if showDecorations}
		<div class="scanlines"></div>
	{/if}

	<div class="hero-content">
		<!-- The Hook - Big and Clear -->
		<header class="hero-header">
			<h1 class="hero-title">
				Stake. Survive. <span class="highlight-profit">Profit.</span>
			</h1>
			<p class="hero-subtitle">
				When others get traced, <span class="highlight-accent">you earn their stake.</span>
			</p>
		</header>

		<!-- The How - 3 Simple Steps -->
		<div class="steps-container">
			<div class="step">
				<span class="step-number">1</span>
				<div class="step-content">
					<span class="step-label">STAKE</span>
					<span class="step-desc">Deposit $DATA at your chosen risk level</span>
				</div>
			</div>

			<div class="step-arrow">→</div>

			<div class="step">
				<span class="step-number">2</span>
				<div class="step-content">
					<span class="step-label">SURVIVE</span>
					<span class="step-desc">Don't get traced in periodic scans</span>
				</div>
			</div>

			<div class="step-arrow">→</div>

			<div class="step">
				<span class="step-number">3</span>
				<div class="step-content">
					<span class="step-label">PROFIT</span>
					<span class="step-desc">Earn from those who don't survive</span>
				</div>
			</div>
		</div>

		<!-- The CTA - One Clear Action -->
		<div class="cta-section">
			<button class="cta-primary" onclick={onJackIn}>
				<span class="cta-icon">⚡</span>
				<span class="cta-text">JACK IN</span>
			</button>

			<button class="cta-secondary" onclick={onWatchFeed}>
				<span class="cta-text">Watch the feed first →</span>
			</button>
		</div>

		<!-- The Warning - Clear but not scary -->
		<p class="disclaimer">
			High risk. You can lose everything. Only stake what you can afford to lose.
		</p>
	</div>
</div>

<style>
	.hero-container {
		position: relative;
		padding: var(--space-8) var(--space-6);
		background: transparent;
		border: none;
		overflow: hidden;
	}

	/* When inside a Box/Panel, add some padding */
	.hero-container.in-panel {
		padding: var(--space-4) 0;
	}

	.scanlines {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: repeating-linear-gradient(
			0deg,
			transparent,
			transparent 2px,
			rgba(0, 229, 204, 0.01) 2px,
			rgba(0, 229, 204, 0.01) 4px
		);
		pointer-events: none;
		z-index: 1;
	}

	.hero-content {
		position: relative;
		z-index: 2;
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		gap: var(--space-6);
		max-width: 700px;
		margin: 0 auto;
	}

	/* ═══════════════════════════════════════════════════════════════
	   HEADER - The Hook
	   ═══════════════════════════════════════════════════════════════ */

	.hero-header {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.hero-title {
		font-family: var(--font-mono);
		font-size: clamp(1.5rem, 5vw, 2.5rem);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wide);
		line-height: var(--leading-tight);
		margin: 0;
	}

	.hero-subtitle {
		font-family: var(--font-mono);
		font-size: clamp(0.875rem, 2vw, 1.125rem);
		color: var(--color-text-secondary);
		margin: 0;
		line-height: var(--leading-relaxed);
	}

	.highlight-profit {
		color: var(--color-profit);
		text-shadow: 0 0 20px var(--color-profit-glow);
	}

	.highlight-accent {
		color: var(--color-accent);
	}

	/* ═══════════════════════════════════════════════════════════════
	   STEPS - The How
	   ═══════════════════════════════════════════════════════════════ */

	.steps-container {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-3);
		flex-wrap: wrap;
		width: 100%;
	}

	.step {
		display: flex;
		align-items: flex-start;
		gap: var(--space-3);
		padding: var(--space-4);
		background: rgba(0, 229, 204, 0.03);
		border: 1px solid var(--color-border-default);
		border-left: 3px solid var(--color-accent);
		min-width: 160px;
		max-width: 200px;
	}

	.step-number {
		font-family: var(--font-mono);
		font-size: var(--text-2xl);
		font-weight: var(--font-bold);
		color: var(--color-accent);
		line-height: 1;
		text-shadow: 0 0 10px var(--color-accent-glow);
	}

	.step-content {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		text-align: left;
	}

	.step-label {
		font-family: var(--font-mono);
		font-size: var(--text-base);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wider);
	}

	.step-desc {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
		line-height: var(--leading-relaxed);
	}

	.step-arrow {
		font-size: var(--text-xl);
		color: var(--color-accent-dim);
	}

	/* ═══════════════════════════════════════════════════════════════
	   CTA - The Action
	   ═══════════════════════════════════════════════════════════════ */

	.cta-section {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-3);
	}

	.cta-primary {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-3) var(--space-8);
		background: var(--color-accent);
		color: var(--color-bg-void);
		border: 2px solid var(--color-accent);
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
		cursor: pointer;
		transition: all 0.2s ease;
		animation: cta-glow 2s ease-in-out infinite;
	}

	@keyframes cta-glow {
		0%,
		100% {
			box-shadow: 0 0 15px var(--color-accent-glow);
		}
		50% {
			box-shadow:
				0 0 30px var(--color-accent-glow),
				0 0 50px var(--color-accent-glow);
		}
	}

	.cta-primary:hover {
		background: var(--color-accent-bright);
		transform: translateY(-2px);
		animation: none;
		box-shadow: 0 0 40px var(--color-accent-glow);
	}

	.cta-icon {
		font-size: var(--text-xl);
	}

	.cta-secondary {
		background: transparent;
		border: none;
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		cursor: pointer;
		transition: color 0.2s;
		padding: var(--space-2);
	}

	.cta-secondary:hover {
		color: var(--color-accent);
	}

	/* ═══════════════════════════════════════════════════════════════
	   DISCLAIMER
	   ═══════════════════════════════════════════════════════════════ */

	.disclaimer {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-amber-dim);
		margin: 0;
	}

	/* ═══════════════════════════════════════════════════════════════
	   RESPONSIVE
	   ═══════════════════════════════════════════════════════════════ */

	@media (max-width: 768px) {
		.hero-container {
			padding: var(--space-6) var(--space-4);
		}

		.steps-container {
			flex-direction: column;
		}

		.step {
			width: 100%;
			max-width: none;
		}

		.step-arrow {
			transform: rotate(90deg);
		}
	}
</style>
