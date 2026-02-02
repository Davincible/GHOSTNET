<script lang="ts">
	/**
	 * LandingHero - Mode 1: First Visit (No Wallet)
	 *
	 * Progressive disclosure: This is the FIRST thing new users see.
	 * Goal: Explain the game in 5 seconds, create FOMO, get wallet connection.
	 *
	 * Matches the vision:
	 * - GHOSTNET: THE RABBITZ HOLE header (animated ASCII logo)
	 * - Simple pitch
	 * - 1-2-3-4 steps clearly visible (BigSteps component)
	 * - CONNECT WALLET as primary CTA
	 * - Compact live feed (atmosphere, not information)
	 * - Live stats as social proof
	 */

	import { BigSteps } from '$lib/features/experiments';
	import { AsciiTypewriter } from '$lib/features/welcome';

	// Track when logo animation completes to show subtitle
	let logoComplete = $state(false);

	function handleLogoComplete() {
		logoComplete = true;
	}

	// The ASCII logo text
	const logoText = ` ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗███╗   ██╗███████╗████████╗
██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝████╗  ██║██╔════╝╚══██╔══╝
██║  ███╗███████║██║   ██║███████╗   ██║   ██╔██╗ ██║█████╗     ██║   
██║   ██║██╔══██║██║   ██║╚════██║   ██║   ██║╚██╗██║██╔══╝     ██║   
╚██████╔╝██║  ██║╚██████╔╝███████║   ██║   ██║ ╚████║███████╗   ██║   
 ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ╚═══╝╚══════╝   ╚═╝`;

	interface Props {
		/** Callback when Connect Wallet is clicked */
		onConnectWallet?: () => void;
		/** Live stats */
		playersOnline?: number;
		totalLocked?: string;
		tracedToday?: number;
	}

	let {
		onConnectWallet,
		playersOnline = 1223,
		totalLocked = '$4.8M',
		tracedToday = 847,
	}: Props = $props();
</script>

<div class="landing-hero">
	<!-- Large Flanking Rabbits -->
	<div class="rabbit-flank rabbit-left" class:visible={logoComplete}>
		<img src="/rabbit_head.svg" alt="" aria-hidden="true" />
	</div>
	<div class="rabbit-flank rabbit-right" class:visible={logoComplete}>
		<img src="/rabbit_head.svg" alt="" aria-hidden="true" />
	</div>

	<!-- Scanline Overlay -->
	<div class="scanlines"></div>
	<!-- Main Content -->
	<div class="hero-content">
		<!-- The Title - Animated ASCII Logo -->
		<header class="hero-header">
			<div class="ascii-logo">
				<div class="logo-container">
					<AsciiTypewriter
						text={logoText}
						charDelay={3}
						lineDelay={30}
						glitchChance={0.02}
						onComplete={handleLogoComplete}
					/>
				</div>
				<span class="logo-subtitle" class:visible={logoComplete}>THE RABBITZ HOLE</span>
			</div>

			<p class="tagline">
				Jack into the network. Survive the trace scans.<br />
				<span class="highlight-danger">When others die, you profit.</span>
			</p>
		</header>

		<!-- The Steps - BigSteps component (exactly as in showcase, with CTA button) -->
		<div class="steps-section">
			<BigSteps {onConnectWallet} showCta={true} variant="default" />
		</div>

		<!-- Live Stats - Social Proof -->
		<div class="stats-bar">
			<span class="stat">
				<span class="stat-label">LIVE:</span>
				<span class="stat-value">{playersOnline.toLocaleString()}</span>
				<span class="stat-unit">players</span>
			</span>
			<span class="stat-divider">|</span>
			<span class="stat">
				<span class="stat-value">{totalLocked}</span>
				<span class="stat-unit">locked</span>
			</span>
			<span class="stat-divider">|</span>
			<span class="stat">
				<span class="stat-value highlight-traced">{tracedToday.toLocaleString()}</span>
				<span class="stat-unit">traced today</span>
			</span>
		</div>
	</div>
</div>

<style>
	.landing-hero {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: var(--space-8) var(--space-4);
		position: relative;
		overflow: hidden;
		animation: terminal-flicker 8s ease-in-out infinite;
	}

	@keyframes terminal-flicker {
		0%,
		100% {
			opacity: 1;
		}
		92% {
			opacity: 1;
		}
		93% {
			opacity: 0.95;
		}
		94% {
			opacity: 1;
		}
		95% {
			opacity: 0.98;
		}
		96% {
			opacity: 1;
		}
	}

	/* ═══════════════════════════════════════════════════════════════
	   EFFECTS OVERLAYS
	   ═══════════════════════════════════════════════════════════════ */

	.scanlines {
		position: fixed;
		inset: 0;
		background: repeating-linear-gradient(
			0deg,
			transparent,
			transparent 2px,
			rgba(0, 255, 255, 0.015) 2px,
			rgba(0, 255, 255, 0.015) 4px
		);
		pointer-events: none;
		z-index: 10;
	}

	.hero-content {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-6);
		max-width: 720px;
		width: 100%;
		text-align: center;
		position: relative;
		z-index: 5;
	}

	/* ═══════════════════════════════════════════════════════════════
	   HEADER
	   ═══════════════════════════════════════════════════════════════ */

	.hero-header {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	/* ASCII Logo */
	.ascii-logo {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-2);
	}

	/* ═══════════════════════════════════════════════════════════════
	   FLANKING RABBITS
	   Large decorative rabbits on left/right edges, partially cut off
	   ═══════════════════════════════════════════════════════════════ */

	.rabbit-flank {
		position: fixed;
		top: 50%;
		transform: translateY(-50%);
		height: 66vh;
		width: auto;
		opacity: 0;
		transition: opacity 1.2s ease-out;
		pointer-events: none;
		z-index: 2;
		/* Cyberpunk glow effect */
		filter: drop-shadow(0 0 30px rgba(0, 229, 204, 0.3));
	}

	.rabbit-flank.visible {
		opacity: 0.1;
	}

	.rabbit-flank img {
		height: 100%;
		width: auto;
		/* Cyberpunk color treatment */
		filter: hue-rotate(-15deg) brightness(1.1) saturate(0.8);
	}

	.rabbit-left {
		left: 0;
		--rabbit-x: -45%;
		transform: translateY(-40%) translateX(-45%);
	}

	.rabbit-left.visible {
		animation: rabbit-float-left 8s ease-in-out infinite;
	}

	.rabbit-right {
		right: 0;
		transform: translateY(-40%) translateX(45%) scaleX(-1);
	}

	.rabbit-right.visible {
		animation: rabbit-float-right 8s ease-in-out infinite;
		animation-delay: -4s; /* Offset so they don't move in sync */
	}

	@keyframes rabbit-float-left {
		0%,
		100% {
			filter: drop-shadow(0 0 30px rgba(0, 229, 204, 0.3));
			transform: translateY(-40%) translateX(-45%);
		}
		50% {
			filter: drop-shadow(0 0 50px rgba(0, 229, 204, 0.5));
			transform: translateY(-42%) translateX(-45%);
		}
	}

	@keyframes rabbit-float-right {
		0%,
		100% {
			filter: drop-shadow(0 0 30px rgba(0, 229, 204, 0.3));
			transform: translateY(-40%) translateX(45%) scaleX(-1);
		}
		50% {
			filter: drop-shadow(0 0 50px rgba(0, 229, 204, 0.5));
			transform: translateY(-42%) translateX(45%) scaleX(-1);
		}
	}

	/* Container for the typewriter to prevent layout shift during animation */
	.logo-container {
		min-height: 4.5rem; /* Reserve space for 6 lines of ASCII art */
		display: flex;
		align-items: flex-start;
		justify-content: center;
	}

	/* AsciiTypewriter component styles are internal, but we can adjust container */
	.ascii-logo :global(.ascii-typewriter) {
		font-size: clamp(0.35rem, 1.2vw, 0.6rem) !important;
	}

	.logo-subtitle {
		font-family: var(--font-mono);
		font-size: clamp(0.75rem, 2vw, 1rem);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-widest);
		opacity: 0;
		transform: translateY(-5px);
		transition:
			opacity 0.5s ease-out,
			transform 0.5s ease-out;
	}

	.logo-subtitle.visible {
		opacity: 1;
		transform: translateY(0);
	}

	.tagline {
		font-family: var(--font-mono);
		font-size: clamp(1rem, 3vw, 1.25rem);
		color: var(--color-text-secondary);
		line-height: var(--leading-relaxed);
		margin: 0;
	}

	.highlight-danger {
		color: var(--color-red);
		text-shadow: 0 0 10px rgba(255, 0, 0, 0.5);
	}

	/* ═══════════════════════════════════════════════════════════════
	   STEPS SECTION (BigSteps component)
	   ═══════════════════════════════════════════════════════════════ */

	.steps-section {
		width: 100%;
		max-width: 420px;
		text-align: left;
	}

	/* ═══════════════════════════════════════════════════════════════
	   STATS BAR
	   ═══════════════════════════════════════════════════════════════ */

	.stats-bar {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-3);
		flex-wrap: wrap;
		font-family: var(--font-mono);
		font-size: var(--text-sm);
	}

	.stat {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.stat-label {
		color: var(--color-text-muted);
	}

	.stat-value {
		color: var(--color-accent);
		font-weight: var(--font-bold);
	}

	.stat-value.highlight-traced {
		color: var(--color-red);
	}

	.stat-unit {
		color: var(--color-text-tertiary);
	}

	.stat-divider {
		color: var(--color-border-default);
	}

	/* ═══════════════════════════════════════════════════════════════
	   RESPONSIVE
	   ═══════════════════════════════════════════════════════════════ */

	@media (max-width: 640px) {
		.landing-hero {
			padding: var(--space-6) var(--space-3);
		}

		/* Hide flanking rabbits on mobile - too distracting */
		.rabbit-flank {
			display: none;
		}

		/* ASCII logo scales down on mobile */
		.ascii-logo :global(.ascii-typewriter) {
			font-size: 0.28rem !important;
		}

		.logo-container {
			min-height: 3rem; /* Smaller reserved space on mobile */
		}

		.stats-bar {
			flex-direction: column;
			gap: var(--space-2);
		}

		.stat-divider {
			display: none;
		}
	}

	/* Tablet - smaller flanking rabbits */
	@media (max-width: 1024px) and (min-width: 641px) {
		.rabbit-flank {
			height: 50vh;
		}

		.rabbit-left {
			transform: translateY(-40%) translateX(-48%);
		}

		.rabbit-right {
			transform: translateY(-40%) translateX(48%) scaleX(-1);
		}
	}
</style>
