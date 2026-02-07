<script lang="ts">
	/**
	 * QuickPitch - Ultra-minimal experimental component
	 *
	 * Goal: Maximum clarity in minimum space.
	 * Just the essential pitch + CTA. No steps, no details.
	 *
	 * Philosophy: "If someone only reads 10 words, what should they be?"
	 */

	interface Props {
		/** Callback when Jack In is triggered */
		onJackIn?: () => void;
		/** Live stats to show social proof */
		playersOnline?: number;
		/** Total value locked */
		tvl?: string;
	}

	let { onJackIn, playersOnline = 1223, tvl = '$4.8M' }: Props = $props();
</script>

<div class="pitch-container">
	<div class="pitch-content">
		<!-- The One-Liner -->
		<h1 class="pitch-headline">
			Stake tokens.<br />
			Survive the scan.<br />
			<span class="highlight">Take the pot.</span>
		</h1>

		<!-- The Twist -->
		<p class="pitch-subline">When others die, you profit.</p>

		<!-- Social Proof -->
		<div class="stats-bar">
			<span class="stat">
				<span class="stat-value">{playersOnline.toLocaleString()}</span>
				<span class="stat-label">playing now</span>
			</span>
			<span class="stat-divider">|</span>
			<span class="stat">
				<span class="stat-value">{tvl}</span>
				<span class="stat-label">at stake</span>
			</span>
		</div>

		<!-- CTA -->
		<button class="cta" onclick={onJackIn}> JACK IN → </button>
	</div>
</div>

<style>
	.pitch-container {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: var(--space-6) var(--space-4);
		background: transparent;
	}

	.pitch-content {
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		gap: var(--space-4);
		max-width: 500px;
	}

	/* ═══════════════════════════════════════════════════════════════
	   HEADLINE - The main hook
	   ═══════════════════════════════════════════════════════════════ */

	.pitch-headline {
		font-family: var(--font-mono);
		font-size: clamp(1.75rem, 6vw, 2.5rem);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		line-height: var(--leading-tight);
		letter-spacing: var(--tracking-tight);
		margin: 0;
	}

	.highlight {
		color: var(--color-profit);
		text-shadow: 0 0 30px var(--color-profit-glow);
	}

	/* ═══════════════════════════════════════════════════════════════
	   SUBLINE - The twist
	   ═══════════════════════════════════════════════════════════════ */

	.pitch-subline {
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		color: var(--color-text-tertiary);
		margin: 0;
	}

	/* ═══════════════════════════════════════════════════════════════
	   STATS - Social proof
	   ═══════════════════════════════════════════════════════════════ */

	.stats-bar {
		display: flex;
		align-items: center;
		gap: var(--space-4);
		padding: var(--space-2) var(--space-4);
		background: rgba(0, 229, 204, 0.03);
		border: 1px solid var(--color-border-subtle);
	}

	.stat {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.stat-value {
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		color: var(--color-accent);
	}

	.stat-label {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wide);
		text-transform: uppercase;
	}

	.stat-divider {
		color: var(--color-border-default);
	}

	/* ═══════════════════════════════════════════════════════════════
	   CTA - The action
	   ═══════════════════════════════════════════════════════════════ */

	.cta {
		padding: var(--space-3) var(--space-8);
		background: var(--color-accent);
		color: var(--color-bg-void);
		border: none;
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
		cursor: pointer;
		transition: all 0.2s ease;
		box-shadow: 0 0 20px var(--color-accent-glow);
	}

	.cta:hover {
		background: var(--color-accent-bright);
		transform: scale(1.02);
		box-shadow: 0 0 40px var(--color-accent-glow);
	}
</style>
