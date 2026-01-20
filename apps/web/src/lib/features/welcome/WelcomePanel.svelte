<script lang="ts">
	import { onMount } from 'svelte';
	import { Box } from '$lib/ui/terminal';

	// Props
	interface Props {
		onJackIn?: () => void;
		onWatchFeed?: () => void;
	}

	let { onJackIn, onWatchFeed }: Props = $props();

	// Current slide index
	let currentSlide = $state(0);
	let isAutoPlaying = $state(true);
	let slideProgress = $state(0);
	
	const SLIDE_DURATION = 6000; // 6 seconds per slide
	const PROGRESS_INTERVAL = 50; // Update progress every 50ms
	
	const totalSlides = 7;

	// Auto-advance slides
	let progressInterval: ReturnType<typeof setInterval>;
	let slideTimeout: ReturnType<typeof setTimeout>;

	function startAutoPlay() {
		if (!isAutoPlaying) return;
		
		slideProgress = 0;
		
		// Progress bar animation
		progressInterval = setInterval(() => {
			slideProgress += (PROGRESS_INTERVAL / SLIDE_DURATION) * 100;
			if (slideProgress >= 100) {
				slideProgress = 100;
			}
		}, PROGRESS_INTERVAL);
		
		// Advance slide
		slideTimeout = setTimeout(() => {
			if (isAutoPlaying) {
				nextSlide();
			}
		}, SLIDE_DURATION);
	}

	function stopAutoPlay() {
		clearInterval(progressInterval);
		clearTimeout(slideTimeout);
	}

	function nextSlide() {
		stopAutoPlay();
		currentSlide = (currentSlide + 1) % totalSlides;
		startAutoPlay();
	}

	function prevSlide() {
		stopAutoPlay();
		currentSlide = (currentSlide - 1 + totalSlides) % totalSlides;
		startAutoPlay();
	}

	function goToSlide(index: number) {
		stopAutoPlay();
		currentSlide = index;
		startAutoPlay();
	}

	function handleMouseEnter() {
		isAutoPlaying = false;
		stopAutoPlay();
	}

	function handleMouseLeave() {
		isAutoPlaying = true;
		startAutoPlay();
	}

	onMount(() => {
		startAutoPlay();
		return () => {
			stopAutoPlay();
		};
	});

	// Typing animation state for slide 0
	let logoVisible = $state(false);
	let taglineVisible = $state(false);
	let subtitleVisible = $state(false);

	$effect(() => {
		if (currentSlide === 0) {
			logoVisible = false;
			taglineVisible = false;
			subtitleVisible = false;
			
			setTimeout(() => logoVisible = true, 200);
			setTimeout(() => taglineVisible = true, 800);
			setTimeout(() => subtitleVisible = true, 1400);
		}
	});
</script>

<div 
	class="welcome-panel"
	onmouseenter={handleMouseEnter}
	onmouseleave={handleMouseLeave}
	role="region"
	aria-label="Welcome to GHOSTNET"
>
	<Box title="WELCOME TO THE NETWORK" borderColor="cyan" glow>
		<div class="slides-container">
			<!-- Slide 0: The Hook -->
			{#if currentSlide === 0}
				<div class="slide slide-hook">
					<div class="logo-container" class:visible={logoVisible}>
						<pre class="ascii-logo">{`
 ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗
██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝
██║  ███╗███████║██║   ██║███████╗   ██║   
██║   ██║██╔══██║██║   ██║╚════██║   ██║   
╚██████╔╝██║  ██║╚██████╔╝███████║   ██║   
 ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   `}</pre>
					</div>
					<h2 class="tagline" class:visible={taglineVisible}>
						JACK IN. DON'T GET TRACED.
					</h2>
					<p class="subtitle" class:visible={subtitleVisible}>
						A game where doing nothing can make you rich.<br/>
						<span class="danger">Or lose you everything.</span>
					</p>
				</div>
			{/if}

			<!-- Slide 1: The Mechanic -->
			{#if currentSlide === 1}
				<div class="slide slide-mechanic">
					<h2 class="slide-title">HOW IT WORKS</h2>
					<div class="flow-diagram">
						<div class="flow-step" style="--delay: 0">
							<span class="step-number">1</span>
							<span class="step-name">JACK IN</span>
							<span class="step-desc">Stake $DATA</span>
						</div>
						<div class="flow-arrow" style="--delay: 1">↓</div>
						<div class="flow-step" style="--delay: 2">
							<span class="step-number">2</span>
							<span class="step-name">EARN</span>
							<span class="step-desc">Yield accumulates</span>
						</div>
						<div class="flow-arrow" style="--delay: 3">↓</div>
						<div class="flow-step" style="--delay: 4">
							<span class="step-number">3</span>
							<span class="step-name">SURVIVE</span>
							<span class="step-desc">The trace scan</span>
						</div>
						<div class="flow-arrow" style="--delay: 5">↓</div>
						<div class="flow-step" style="--delay: 6">
							<span class="step-number">4</span>
							<span class="step-name">EXTRACT</span>
							<span class="step-desc">Take your gains</span>
						</div>
					</div>
				</div>
			{/if}

			<!-- Slide 2: The Twist -->
			{#if currentSlide === 2}
				<div class="slide slide-twist">
					<h2 class="twist-headline">
						WHEN OTHERS DIE,<br/>
						<span class="profit">YOU PROFIT.</span>
					</h2>
					<div class="twist-details">
						<p class="twist-line">Every death feeds survivors.</p>
						<p class="twist-line burn">30% is burned forever.</p>
					</div>
					<div class="cascade-visual">
						<span class="cascade-icon">💀</span>
						<span class="cascade-arrow">→</span>
						<span class="cascade-split">
							<span class="split-item survivors">👻 Survivors</span>
							<span class="split-item burned">🔥 Burned</span>
						</span>
					</div>
				</div>
			{/if}

			<!-- Slide 3: The Risk -->
			{#if currentSlide === 3}
				<div class="slide slide-risk">
					<h2 class="slide-title">CHOOSE YOUR RISK</h2>
					<div class="risk-ladder">
						<div class="risk-level level-5" style="--delay: 0">
							<span class="level-name">BLACK ICE</span>
							<span class="level-death danger">90% death</span>
							<span class="level-reward">∞ upside</span>
						</div>
						<div class="risk-level level-4" style="--delay: 1">
							<span class="level-name">DARKNET</span>
							<span class="level-death warning">40% death</span>
							<span class="level-reward">20,000%</span>
						</div>
						<div class="risk-level level-3" style="--delay: 2">
							<span class="level-name">SUBNET</span>
							<span class="level-death caution">15% death</span>
							<span class="level-reward">5,000%</span>
						</div>
						<div class="risk-level level-2" style="--delay: 3">
							<span class="level-name">MAINFRAME</span>
							<span class="level-death safe">2% death</span>
							<span class="level-reward">1,000%</span>
						</div>
						<div class="risk-level level-1" style="--delay: 4">
							<span class="level-name">THE VAULT</span>
							<span class="level-death safest">0% death</span>
							<span class="level-reward">100-500%</span>
						</div>
					</div>
					<p class="risk-tagline">The deeper you go, the more you earn.</p>
				</div>
			{/if}

			<!-- Slide 4: The Edge -->
			{#if currentSlide === 4}
				<div class="slide slide-edge">
					<h2 class="edge-headline">
						DON'T JUST WATCH.<br/>
						<span class="accent">FIGHT BACK.</span>
					</h2>
					<div class="edge-options">
						<div class="edge-item" style="--delay: 0">
							<span class="edge-icon">⌨</span>
							<div class="edge-info">
								<span class="edge-name">TRACE EVASION</span>
								<span class="edge-desc">Type fast. Reduce death rate up to <span class="highlight">-25%</span></span>
							</div>
						</div>
						<div class="edge-item" style="--delay: 1">
							<span class="edge-icon">🎮</span>
							<div class="edge-info">
								<span class="edge-name">HACK RUNS</span>
								<span class="edge-desc">Complete runs. Earn <span class="highlight">3x yield</span> multipliers</span>
							</div>
						</div>
						<div class="edge-item" style="--delay: 2">
							<span class="edge-icon">🎲</span>
							<div class="edge-info">
								<span class="edge-name">DEAD POOL</span>
								<span class="edge-desc">Bet on outcomes. Win more <span class="highlight">$DATA</span></span>
							</div>
						</div>
					</div>
					<p class="edge-tagline">
						<span class="dim">Passive is fine.</span> 
						<span class="bright">Active is better.</span>
					</p>
				</div>
			{/if}

			<!-- Slide 5: The Trust -->
			{#if currentSlide === 5}
				<div class="slide slide-trust">
					<div class="trust-main">
						<h2 class="trust-headline">LIQUIDITY IS BURNED.</h2>
						<h3 class="trust-subline">WE CAN'T RUG YOU.</h3>
					</div>
					<div class="trust-icon">
						<span class="fire-icon">🔥</span>
						<span class="lock-text">LP TOKENS = 0xdead</span>
					</div>
					<div class="trust-warning">
						<p>But you can still lose.</p>
						<p class="dim">Only risk what you can afford.</p>
					</div>
				</div>
			{/if}

			<!-- Slide 6: The CTA -->
			{#if currentSlide === 6}
				<div class="slide slide-cta">
					<h2 class="cta-headline">
						THE NETWORK IS LIVE.<br/>
						THE FEED IS BURNING.
					</h2>
					<div class="cta-question">
						How long can you survive?
					</div>
					<div class="cta-buttons">
						<button class="cta-btn primary" onclick={onJackIn}>JACK IN</button>
						<button class="cta-btn secondary" onclick={onWatchFeed}>WATCH THE FEED</button>
					</div>
				</div>
			{/if}
		</div>

		<!-- Navigation -->
		<div class="slide-nav">
			<div class="nav-dots">
				{#each Array(totalSlides) as _, i}
					<button 
						class="nav-dot" 
						class:active={currentSlide === i}
						onclick={() => goToSlide(i)}
						aria-label="Go to slide {i + 1}"
					>
						{#if currentSlide === i}
							<div class="dot-progress" style="width: {slideProgress}%"></div>
						{/if}
					</button>
				{/each}
			</div>
			<div class="nav-arrows">
				<button class="nav-arrow" onclick={prevSlide} aria-label="Previous slide">←</button>
				<span class="nav-counter">{currentSlide + 1}/{totalSlides}</span>
				<button class="nav-arrow" onclick={nextSlide} aria-label="Next slide">→</button>
			</div>
		</div>
	</Box>
</div>

<style>
	.welcome-panel {
		width: 100%;
	}

	.slides-container {
		min-height: 280px;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: var(--space-4) var(--space-2);
		position: relative;
		overflow: hidden;
	}

	.slide {
		width: 100%;
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		gap: var(--space-3);
		animation: slideIn 0.4s ease-out;
	}

	@keyframes slideIn {
		from {
			opacity: 0;
			transform: translateX(20px);
		}
		to {
			opacity: 1;
			transform: translateX(0);
		}
	}

	/* ═══════════════════════════════════════════════════════════════
	   SLIDE 0: THE HOOK
	   ═══════════════════════════════════════════════════════════════ */

	.logo-container {
		opacity: 0;
		transform: scale(0.9);
		transition: all 0.5s ease-out;
	}

	.logo-container.visible {
		opacity: 1;
		transform: scale(1);
	}

	.ascii-logo {
		font-family: var(--font-mono);
		font-size: 0.45rem;
		line-height: 1.1;
		color: var(--color-accent);
		text-shadow: 0 0 10px var(--color-accent-glow);
		white-space: pre;
		margin: 0;
	}

	.tagline {
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wider);
		margin: 0;
		opacity: 0;
		transform: translateY(10px);
		transition: all 0.4s ease-out;
	}

	.tagline.visible {
		opacity: 1;
		transform: translateY(0);
	}

	.subtitle {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		margin: 0;
		line-height: var(--leading-relaxed);
		opacity: 0;
		transition: opacity 0.4s ease-out;
	}

	.subtitle.visible {
		opacity: 1;
	}

	.subtitle .danger {
		color: var(--color-red);
	}

	/* ═══════════════════════════════════════════════════════════════
	   SLIDE 1: THE MECHANIC
	   ═══════════════════════════════════════════════════════════════ */

	.slide-title {
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		color: var(--color-accent);
		letter-spacing: var(--tracking-wider);
		margin: 0 0 var(--space-3) 0;
	}

	.flow-diagram {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-1);
	}

	.flow-step {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-2) var(--space-4);
		background: var(--color-bg-tertiary);
		border-left: 2px solid var(--color-accent-dim);
		opacity: 0;
		transform: translateX(-10px);
		animation: flowIn 0.3s ease-out forwards;
		animation-delay: calc(var(--delay) * 0.15s);
	}

	.flow-arrow {
		color: var(--color-accent-dim);
		font-size: var(--text-lg);
		opacity: 0;
		animation: flowIn 0.3s ease-out forwards;
		animation-delay: calc(var(--delay) * 0.15s);
	}

	@keyframes flowIn {
		to {
			opacity: 1;
			transform: translateX(0);
		}
	}

	.step-number {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		width: 1.5ch;
	}

	.step-name {
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		min-width: 8ch;
	}

	.step-desc {
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
	}

	/* ═══════════════════════════════════════════════════════════════
	   SLIDE 2: THE TWIST
	   ═══════════════════════════════════════════════════════════════ */

	.slide-twist {
		gap: var(--space-4);
	}

	.twist-headline {
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wide);
		margin: 0;
		line-height: var(--leading-tight);
	}

	.twist-headline .profit {
		color: var(--color-profit);
		text-shadow: 0 0 10px var(--color-profit-glow);
	}

	.twist-details {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.twist-line {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		margin: 0;
	}

	.twist-line.burn {
		color: var(--color-amber);
	}

	.cascade-visual {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--color-bg-tertiary);
		margin-top: var(--space-2);
	}

	.cascade-icon {
		font-size: var(--text-lg);
	}

	.cascade-arrow {
		color: var(--color-accent-dim);
	}

	.cascade-split {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		font-size: var(--text-xs);
	}

	.split-item.survivors {
		color: var(--color-profit);
	}

	.split-item.burned {
		color: var(--color-amber);
	}

	/* ═══════════════════════════════════════════════════════════════
	   SLIDE 3: THE RISK
	   ═══════════════════════════════════════════════════════════════ */

	.slide-risk {
		gap: var(--space-2);
	}

	.risk-ladder {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		width: 100%;
		max-width: 320px;
	}

	.risk-level {
		display: grid;
		grid-template-columns: 1fr auto auto;
		gap: var(--space-3);
		padding: var(--space-1-5) var(--space-2);
		background: var(--color-bg-tertiary);
		font-size: var(--text-xs);
		opacity: 0;
		transform: translateY(-5px);
		animation: riskIn 0.25s ease-out forwards;
		animation-delay: calc(var(--delay) * 0.12s);
	}

	@keyframes riskIn {
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.level-5 { border-left: 2px solid var(--color-red); }
	.level-4 { border-left: 2px solid var(--color-amber); }
	.level-3 { border-left: 2px solid var(--color-amber); }
	.level-2 { border-left: 2px solid var(--color-cyan); }
	.level-1 { border-left: 2px solid var(--color-profit); }

	.level-name {
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		text-align: left;
	}

	.level-death {
		text-align: center;
	}

	.level-death.danger { color: var(--color-red); }
	.level-death.warning { color: var(--color-amber); }
	.level-death.caution { color: var(--color-amber); }
	.level-death.safe { color: var(--color-cyan); }
	.level-death.safest { color: var(--color-profit); }

	.level-reward {
		color: var(--color-text-secondary);
		text-align: right;
	}

	.risk-tagline {
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
		margin: var(--space-2) 0 0 0;
	}

	/* ═══════════════════════════════════════════════════════════════
	   SLIDE 4: THE EDGE
	   ═══════════════════════════════════════════════════════════════ */

	.slide-edge {
		gap: var(--space-3);
	}

	.edge-headline {
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wide);
		margin: 0;
		line-height: var(--leading-tight);
	}

	.edge-headline .accent {
		color: var(--color-accent);
	}

	.edge-options {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		width: 100%;
		max-width: 300px;
	}

	.edge-item {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-2);
		background: var(--color-bg-tertiary);
		border-left: 2px solid var(--color-accent-dim);
		text-align: left;
		opacity: 0;
		transform: translateX(-10px);
		animation: flowIn 0.3s ease-out forwards;
		animation-delay: calc(var(--delay) * 0.2s);
	}

	.edge-icon {
		font-size: var(--text-lg);
		width: 2ch;
		text-align: center;
	}

	.edge-info {
		display: flex;
		flex-direction: column;
		gap: var(--space-0-5);
	}

	.edge-name {
		font-weight: var(--font-bold);
		font-size: var(--text-sm);
		color: var(--color-text-primary);
	}

	.edge-desc {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
	}

	.edge-desc .highlight {
		color: var(--color-accent);
		font-weight: var(--font-medium);
	}

	.edge-tagline {
		font-size: var(--text-sm);
		margin: 0;
	}

	.edge-tagline .dim {
		color: var(--color-text-tertiary);
	}

	.edge-tagline .bright {
		color: var(--color-accent);
		font-weight: var(--font-medium);
	}

	/* ═══════════════════════════════════════════════════════════════
	   SLIDE 5: THE TRUST
	   ═══════════════════════════════════════════════════════════════ */

	.slide-trust {
		gap: var(--space-4);
	}

	.trust-main {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.trust-headline {
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		color: var(--color-amber);
		letter-spacing: var(--tracking-wider);
		margin: 0;
	}

	.trust-subline {
		font-size: var(--text-base);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		margin: 0;
	}

	.trust-icon {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-1);
	}

	.fire-icon {
		font-size: var(--text-2xl);
		animation: burn 1s ease-in-out infinite;
	}

	@keyframes burn {
		0%, 100% { transform: scale(1); }
		50% { transform: scale(1.1); }
	}

	.lock-text {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
	}

	.trust-warning {
		font-size: var(--text-sm);
	}

	.trust-warning p {
		margin: 0;
		color: var(--color-text-secondary);
	}

	.trust-warning .dim {
		color: var(--color-text-tertiary);
	}

	/* ═══════════════════════════════════════════════════════════════
	   SLIDE 6: THE CTA
	   ═══════════════════════════════════════════════════════════════ */

	.slide-cta {
		gap: var(--space-4);
	}

	.cta-headline {
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wide);
		margin: 0;
		line-height: var(--leading-tight);
	}

	.cta-question {
		font-size: var(--text-sm);
		color: var(--color-accent);
	}

	.cta-buttons {
		display: flex;
		gap: var(--space-3);
	}

	.cta-btn {
		padding: var(--space-2) var(--space-4);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wide);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.cta-btn.primary {
		background: var(--color-accent);
		color: var(--color-bg-void);
		border: 1px solid var(--color-accent);
	}

	.cta-btn.primary:hover {
		background: var(--color-accent-bright);
		box-shadow: 0 0 20px var(--color-accent-glow);
	}

	.cta-btn.secondary {
		background: transparent;
		color: var(--color-text-secondary);
		border: 1px solid var(--color-border-default);
	}

	.cta-btn.secondary:hover {
		color: var(--color-accent);
		border-color: var(--color-accent-dim);
	}

	/* ═══════════════════════════════════════════════════════════════
	   NAVIGATION
	   ═══════════════════════════════════════════════════════════════ */

	.slide-nav {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: var(--space-3) var(--space-2) 0;
		border-top: 1px solid var(--color-border-subtle);
		margin-top: var(--space-2);
	}

	.nav-dots {
		display: flex;
		gap: var(--space-2);
	}

	.nav-dot {
		width: 24px;
		height: 4px;
		background: var(--color-border-default);
		border: none;
		cursor: pointer;
		position: relative;
		overflow: hidden;
		transition: background var(--duration-fast);
	}

	.nav-dot:hover {
		background: var(--color-border-strong);
	}

	.nav-dot.active {
		background: var(--color-bg-tertiary);
	}

	.dot-progress {
		position: absolute;
		top: 0;
		left: 0;
		height: 100%;
		background: var(--color-accent);
		transition: width 0.05s linear;
	}

	.nav-arrows {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.nav-arrow {
		background: transparent;
		border: 1px solid var(--color-border-default);
		color: var(--color-text-tertiary);
		padding: var(--space-1) var(--space-2);
		cursor: pointer;
		font-family: var(--font-mono);
		transition: all var(--duration-fast);
	}

	.nav-arrow:hover {
		color: var(--color-accent);
		border-color: var(--color-accent-dim);
	}

	.nav-counter {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		min-width: 3ch;
		text-align: center;
	}

	/* ═══════════════════════════════════════════════════════════════
	   RESPONSIVE
	   ═══════════════════════════════════════════════════════════════ */

	@media (max-width: 640px) {
		.slides-container {
			min-height: 320px;
			padding: var(--space-3) var(--space-1);
		}

		.ascii-logo {
			font-size: 0.35rem;
		}

		.cta-buttons {
			flex-direction: column;
			width: 100%;
		}

		.cta-btn {
			width: 100%;
		}
	}
</style>
