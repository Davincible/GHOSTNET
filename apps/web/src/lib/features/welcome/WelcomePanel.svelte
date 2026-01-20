<script lang="ts">
	import { onMount } from 'svelte';
	import { Box } from '$lib/ui/terminal';
	import GlitchText from './GlitchText.svelte';
	import MatrixRain from './MatrixRain.svelte';
	import AsciiTypewriter from './AsciiTypewriter.svelte';

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
	let isTransitioning = $state(false);
	let slideKey = $state(0); // Force re-render of slide content
	
	const SLIDE_DURATION = 7000; // 7 seconds per slide
	const PROGRESS_INTERVAL = 50;
	const TRANSITION_DURATION = 400;
	
	const totalSlides = 7;

	// Auto-advance slides
	let progressInterval: ReturnType<typeof setInterval>;
	let slideTimeout: ReturnType<typeof setTimeout>;

	function startAutoPlay() {
		if (!isAutoPlaying) return;
		
		slideProgress = 0;
		
		progressInterval = setInterval(() => {
			slideProgress += (PROGRESS_INTERVAL / SLIDE_DURATION) * 100;
			if (slideProgress >= 100) {
				slideProgress = 100;
			}
		}, PROGRESS_INTERVAL);
		
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

	function transitionTo(newSlide: number) {
		isTransitioning = true;
		
		setTimeout(() => {
			currentSlide = newSlide;
			slideKey++; // Force re-mount of slide content
			isTransitioning = false;
		}, TRANSITION_DURATION / 2);
	}

	function nextSlide() {
		stopAutoPlay();
		transitionTo((currentSlide + 1) % totalSlides);
		setTimeout(startAutoPlay, TRANSITION_DURATION);
	}

	function prevSlide() {
		stopAutoPlay();
		transitionTo((currentSlide - 1 + totalSlides) % totalSlides);
		setTimeout(startAutoPlay, TRANSITION_DURATION);
	}

	function goToSlide(index: number) {
		if (index === currentSlide) return;
		stopAutoPlay();
		transitionTo(index);
		setTimeout(startAutoPlay, TRANSITION_DURATION);
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

	// Slide 0 animation states
	let logoTypingComplete = $state(false);  // When ASCII art finishes typing
	let logoSlidUp = $state(false);          // When logo has moved up
	let showTagline = $state(false);         // When tagline should start typing
	let taglineComplete = $state(false);     // When tagline finishes typing

	function handleLogoTypingComplete() {
		logoTypingComplete = true;
		// Quick beat, then slide up
		setTimeout(() => {
			logoSlidUp = true;
			// Start tagline after slide completes
			setTimeout(() => {
				showTagline = true;
			}, 500);
		}, 250);
	}

	function handleTaglineComplete() {
		taglineComplete = true;
	}

	// Reset states when slide changes
	$effect(() => {
		if (currentSlide === 0) {
			logoTypingComplete = false;
			logoSlidUp = false;
			showTagline = false;
			taglineComplete = false;
		}
	});

	// Matrix effect toggle
	let showMatrixRain = $state(true);
</script>

<div 
	class="welcome-panel"
	onmouseenter={handleMouseEnter}
	onmouseleave={handleMouseLeave}
	role="region"
	aria-label="Welcome to GHOSTNET"
>
	<Box title="/// NETWORK INITIALIZATION ///" borderColor="cyan" glow>
		<div class="panel-container">
			<!-- Matrix Rain Background -->
			{#if showMatrixRain}
				<MatrixRain density={25} speed={0.8} opacity={0.08} />
			{/if}
			
			<!-- Scanline Overlay -->
			<div class="scanlines"></div>
			
			<!-- Glitch Transition Overlay -->
			<div class="glitch-overlay" class:active={isTransitioning}></div>

			<div class="slides-container" class:transitioning={isTransitioning}>
				{#key slideKey}
					<!-- Slide 0: THE HOOK -->
					{#if currentSlide === 0}
						<div class="slide slide-hook" class:content-visible={logoSlidUp}>
							<div class="logo-container" class:slid-up={logoSlidUp}>
								<AsciiTypewriter 
									text={` ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗███╗   ██╗███████╗████████╗
██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝████╗  ██║██╔════╝╚══██╔══╝
██║  ███╗███████║██║   ██║███████╗   ██║   ██╔██╗ ██║█████╗     ██║   
██║   ██║██╔══██║██║   ██║╚════██║   ██║   ██║╚██╗██║██╔══╝     ██║   
╚██████╔╝██║  ██║╚██████╔╝███████║   ██║   ██║ ╚████║███████╗   ██║   
 ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ╚═══╝╚══════╝   ╚═╝`}
									charDelay={3}
									lineDelay={30}
									glitchChance={0.02}
									onComplete={handleLogoTypingComplete}
								/>
								<span class="logo-subtitle" class:visible={logoSlidUp}>THE RABBITZ HOLE</span>
							</div>
							<div class="hook-content" class:visible={showTagline}>
								<h2 class="tagline">
									{#if showTagline}
										<GlitchText 
											text="JACK IN. DON'T GET TRACED." 
											speed={35} 
											glitchIntensity={0.4}
											onComplete={handleTaglineComplete}
										/>
									{/if}
								</h2>
								<p class="subtitle" class:visible={taglineComplete}>
									A game where doing nothing can make you rich.<br/>
									<span class="glow-danger">Or lose you everything.</span>
								</p>
							</div>
						</div>
					{/if}

					<!-- Slide 1: THE MECHANIC -->
					{#if currentSlide === 1}
						<div class="slide slide-mechanic">
							<h2 class="slide-title">HOW IT WORKS</h2>
							<div class="flow-diagram">
								<div class="flow-step" style="--delay: 0">
									<span class="step-icon bracket">[&gt;&gt;]</span>
									<span class="step-name">JACK IN</span>
									<span class="step-desc">Stake $DATA</span>
								</div>
								<div class="flow-arrow" style="--delay: 1">▼</div>
								<div class="flow-step" style="--delay: 2">
									<span class="step-icon bracket">[++]</span>
									<span class="step-name">EARN</span>
									<span class="step-desc">Yield accumulates</span>
								</div>
								<div class="flow-arrow" style="--delay: 3">▼</div>
								<div class="flow-step" style="--delay: 4">
									<span class="step-icon bracket">[??]</span>
									<span class="step-name">SURVIVE</span>
									<span class="step-desc">The trace scan</span>
								</div>
								<div class="flow-arrow" style="--delay: 5">▼</div>
								<div class="flow-step" style="--delay: 6">
									<span class="step-icon bracket">[&lt;&lt;]</span>
									<span class="step-name">EXTRACT</span>
									<span class="step-desc">Take your gains</span>
								</div>
							</div>
						</div>
					{/if}

					<!-- Slide 2: THE TWIST -->
					{#if currentSlide === 2}
						<div class="slide slide-twist">
							<h2 class="twist-headline">
								WHEN OTHERS <span class="glow-danger">DIE</span>,<br/>
								<span class="glow-profit">YOU PROFIT.</span>
							</h2>
							<div class="twist-visual">
								<div class="death-icon pulse">💀</div>
								<div class="flow-arrows">
									<span class="arrow-down">↓</span>
									<span class="arrow-down">↓</span>
								</div>
								<div class="split-result">
									<div class="result-item survivors">
										<span class="result-icon">👻</span>
										<span class="result-label">70% to survivors</span>
									</div>
									<div class="result-item burned">
										<span class="result-icon">🔥</span>
										<span class="result-label">30% burned forever</span>
									</div>
								</div>
							</div>
							<p class="twist-footer">It's PvP economics. <span class="glow-accent">The traced feed the living.</span></p>
						</div>
					{/if}

					<!-- Slide 3: THE RISK -->
					{#if currentSlide === 3}
						<div class="slide slide-risk">
							<h2 class="slide-title">CHOOSE YOUR RISK</h2>
							<div class="risk-ladder">
								<div class="risk-level level-5" style="--delay: 0">
									<span class="level-indicator"></span>
									<span class="level-name">BLACK ICE</span>
									<span class="level-death">90% death</span>
									<span class="level-reward">∞ upside</span>
								</div>
								<div class="risk-level level-4" style="--delay: 1">
									<span class="level-indicator"></span>
									<span class="level-name">DARKNET</span>
									<span class="level-death">40% death</span>
									<span class="level-reward">20,000% APY</span>
								</div>
								<div class="risk-level level-3" style="--delay: 2">
									<span class="level-indicator"></span>
									<span class="level-name">SUBNET</span>
									<span class="level-death">15% death</span>
									<span class="level-reward">5,000% APY</span>
								</div>
								<div class="risk-level level-2" style="--delay: 3">
									<span class="level-indicator"></span>
									<span class="level-name">MAINFRAME</span>
									<span class="level-death">2% death</span>
									<span class="level-reward">1,000% APY</span>
								</div>
								<div class="risk-level level-1" style="--delay: 4">
									<span class="level-indicator"></span>
									<span class="level-name">THE VAULT</span>
									<span class="level-death">0% death</span>
									<span class="level-reward">100-500% APY</span>
								</div>
							</div>
							<p class="risk-tagline"><span class="glow-accent">The deeper you go, the more you earn.</span></p>
						</div>
					{/if}

					<!-- Slide 4: THE EDGE -->
					{#if currentSlide === 4}
						<div class="slide slide-edge">
							<h2 class="edge-headline">
								DON'T JUST WATCH.<br/>
								<span class="glow-accent">FIGHT BACK.</span>
							</h2>
							<div class="edge-options">
								<div class="edge-item" style="--delay: 0">
									<span class="edge-icon bracket">&gt;_</span>
									<div class="edge-info">
										<span class="edge-name">TRACE EVASION</span>
										<span class="edge-desc">Type fast. Reduce death rate up to <span class="highlight">-25%</span></span>
									</div>
								</div>
								<div class="edge-item" style="--delay: 1">
									<span class="edge-icon bracket">&lt;/&gt;</span>
									<div class="edge-info">
										<span class="edge-name">HACK RUNS</span>
										<span class="edge-desc">Complete runs. Earn <span class="highlight">3x yield</span> multipliers</span>
									</div>
								</div>
								<div class="edge-item" style="--delay: 2">
									<span class="edge-icon bracket">%$</span>
									<div class="edge-info">
										<span class="edge-name">DEAD POOL</span>
										<span class="edge-desc">Bet on outcomes. Win more <span class="highlight">$DATA</span></span>
									</div>
								</div>
							</div>
							<p class="edge-tagline">
								<span class="dim">Passive is fine.</span> 
								<span class="glow-profit">Active is better.</span>
							</p>
						</div>
					{/if}

					<!-- Slide 5: THE TRUST -->
					{#if currentSlide === 5}
						<div class="slide slide-trust">
							<div class="trust-icon-container">
								<div class="burn-animation">
									<span class="fire-emoji">🔥</span>
									<span class="fire-emoji delayed">🔥</span>
									<span class="fire-emoji delayed-2">🔥</span>
								</div>
							</div>
							<h2 class="trust-headline">
								<span class="glow-amber">LIQUIDITY IS BURNED.</span>
							</h2>
							<h3 class="trust-subline">WE CAN'T RUG YOU.</h3>
							<div class="trust-proof">
								<code class="burn-address">LP_TOKENS → 0xdead...0000</code>
							</div>
							<div class="trust-warning">
								<p>But you can still <span class="glow-danger">lose</span>.</p>
								<p class="dim">Only risk what you can afford.</p>
							</div>
						</div>
					{/if}

					<!-- Slide 6: THE CTA -->
					{#if currentSlide === 6}
						<div class="slide slide-cta">
							<h2 class="cta-headline">
								THE NETWORK IS <span class="glow-profit blink">LIVE</span>.<br/>
								THE FEED IS <span class="glow-amber">BURNING</span>.
							</h2>
							<p class="cta-question">How long can you survive?</p>
							<div class="cta-buttons">
								<button class="cta-btn primary" onclick={onJackIn}>
									<span class="btn-icon">⚡</span>
									<span class="btn-text">JACK IN</span>
								</button>
								<button class="cta-btn secondary" onclick={onWatchFeed}>
									<span class="btn-icon">👁️</span>
									<span class="btn-text">WATCH THE FEED</span>
								</button>
							</div>
							<p class="cta-disclaimer">⚠️ High risk. Only play what you can lose.</p>
						</div>
					{/if}
				{/key}
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
							{#if currentSlide === i && !isTransitioning}
								<div class="dot-progress" style="width: {slideProgress}%"></div>
							{/if}
						</button>
					{/each}
				</div>

				<!-- Matrix Effect Toggle -->
				<label class="matrix-toggle">
					<input 
						type="checkbox" 
						bind:checked={showMatrixRain}
						class="toggle-input"
					/>
					<span class="toggle-track">
						<span class="toggle-thumb"></span>
					</span>
					<span class="toggle-label">MATRIX</span>
				</label>

				<div class="nav-arrows">
					<button class="nav-arrow" onclick={prevSlide} aria-label="Previous slide">
						<span class="arrow-char">◀</span>
					</button>
					<span class="nav-counter">{currentSlide + 1}/{totalSlides}</span>
					<button class="nav-arrow" onclick={nextSlide} aria-label="Next slide">
						<span class="arrow-char">▶</span>
					</button>
				</div>
			</div>
		</div>
	</Box>
</div>

<style>
	.welcome-panel {
		width: 100%;
	}

	.panel-container {
		position: relative;
		overflow: hidden;
		animation: terminal-flicker 8s ease-in-out infinite;
	}

	@keyframes terminal-flicker {
		0%, 100% { opacity: 1; }
		92% { opacity: 1; }
		93% { opacity: 0.95; }
		94% { opacity: 1; }
		95% { opacity: 0.98; }
		96% { opacity: 1; }
	}

	/* ═══════════════════════════════════════════════════════════════
	   EFFECTS OVERLAYS
	   ═══════════════════════════════════════════════════════════════ */

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
			rgba(0, 255, 255, 0.015) 2px,
			rgba(0, 255, 255, 0.015) 4px
		);
		pointer-events: none;
		z-index: 10;
	}

	.glitch-overlay {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: transparent;
		pointer-events: none;
		z-index: 20;
		opacity: 0;
		transition: opacity 0.1s;
	}

	.glitch-overlay.active {
		opacity: 1;
		animation: glitch-flash 0.4s steps(3) forwards;
	}

	@keyframes glitch-flash {
		0% { 
			background: transparent;
			clip-path: inset(0 0 0 0);
		}
		20% { 
			background: rgba(0, 255, 255, 0.1);
			clip-path: inset(10% 0 80% 0);
		}
		40% { 
			background: rgba(255, 0, 100, 0.1);
			clip-path: inset(40% 0 40% 0);
		}
		60% { 
			background: rgba(0, 255, 255, 0.15);
			clip-path: inset(70% 0 10% 0);
		}
		80% { 
			background: transparent;
			clip-path: inset(0 0 0 0);
		}
		100% { 
			background: transparent;
		}
	}

	/* ═══════════════════════════════════════════════════════════════
	   SLIDES CONTAINER
	   ═══════════════════════════════════════════════════════════════ */

	.slides-container {
		min-height: 300px;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: var(--space-4) var(--space-2);
		position: relative;
		z-index: 5;
		transition: opacity 0.2s, transform 0.2s;
	}

	.slides-container.transitioning {
		opacity: 0;
		transform: scale(0.98);
	}

	.slide {
		width: 100%;
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		gap: var(--space-3);
		animation: slideEnter 0.5s ease-out;
	}

	@keyframes slideEnter {
		from {
			opacity: 0;
			transform: translateY(10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	/* ═══════════════════════════════════════════════════════════════
	   GLOW EFFECTS
	   ═══════════════════════════════════════════════════════════════ */

	.glow-accent {
		color: var(--color-accent);
		text-shadow: 0 0 10px var(--color-accent-glow), 0 0 20px var(--color-accent-glow);
	}

	.glow-profit {
		color: var(--color-profit);
		text-shadow: 0 0 10px var(--color-profit-glow), 0 0 20px var(--color-profit-glow);
	}

	.glow-danger {
		color: var(--color-red);
		text-shadow: 0 0 10px rgba(255, 0, 0, 0.5), 0 0 20px rgba(255, 0, 0, 0.3);
	}

	.glow-amber {
		color: var(--color-amber);
		text-shadow: 0 0 10px rgba(255, 170, 0, 0.5), 0 0 20px rgba(255, 170, 0, 0.3);
	}

	.blink {
		animation: blink-glow 1.5s ease-in-out infinite;
	}

	@keyframes blink-glow {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.7; }
	}

	.pulse {
		animation: pulse-scale 2s ease-in-out infinite;
	}

	@keyframes pulse-scale {
		0%, 100% { transform: scale(1); }
		50% { transform: scale(1.1); }
	}

	/* ═══════════════════════════════════════════════════════════════
	   SLIDE 0: THE HOOK
	   ═══════════════════════════════════════════════════════════════ */

	/* Slide hook - cinematic reveal sequence */
	.slide-hook {
		justify-content: flex-start;
		padding-top: var(--space-16);
		min-height: 260px;
		position: relative;
	}

	.logo-container {
		transition: transform 0.5s cubic-bezier(0.4, 0, 0.2, 1);
		transform: translateY(35px); /* Start centered vertically */
	}

	.logo-container.slid-up {
		transform: translateY(0); /* Slide to top position */
	}

	.logo-subtitle {
		display: block;
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		letter-spacing: var(--tracking-widest);
		margin-top: var(--space-2);
		text-align: center;
		opacity: 0;
		transition: opacity 0.5s ease-out 0.3s; /* 0.3s delay */
	}

	.logo-subtitle.visible {
		opacity: 1;
	}

	.hook-content {
		opacity: 0;
		transform: translateY(10px);
		transition: opacity 0.4s ease-out, transform 0.4s ease-out;
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		pointer-events: none;
	}

	.hook-content.visible {
		opacity: 1;
		transform: translateY(0);
		pointer-events: auto;
	}

	.tagline {
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wider);
		margin: var(--space-4) 0 0 0;
		min-height: 1.5em;
	}

	.subtitle {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		margin: var(--space-2) 0 0 0;
		line-height: var(--leading-relaxed);
		opacity: 0;
		transform: translateY(8px);
		transition: opacity 0.5s ease-out, transform 0.5s ease-out;
	}

	.subtitle.visible {
		opacity: 1;
		transform: translateY(0);
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
		text-shadow: 0 0 10px var(--color-accent-glow);
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
		background: rgba(0, 255, 255, 0.05);
		border: 1px solid var(--color-accent-dim);
		border-left: 3px solid var(--color-accent);
		opacity: 0;
		transform: translateX(-20px);
		animation: flowIn 0.4s ease-out forwards;
		animation-delay: calc(var(--delay) * 0.12s);
	}

	.flow-arrow {
		color: var(--color-accent);
		font-size: var(--text-base);
		opacity: 0;
		animation: flowIn 0.3s ease-out forwards;
		animation-delay: calc(var(--delay) * 0.12s);
		text-shadow: 0 0 5px var(--color-accent-glow);
	}

	@keyframes flowIn {
		to {
			opacity: 1;
			transform: translateX(0);
		}
	}

	.step-icon {
		font-size: var(--text-lg);
	}

	.step-icon.bracket {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-accent);
		font-weight: var(--font-bold);
		letter-spacing: -0.5px;
		text-shadow: 0 0 8px var(--color-accent-glow);
	}

	.step-name {
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		min-width: 7ch;
		text-align: left;
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

	.twist-visual {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-3);
		background: rgba(0, 0, 0, 0.3);
		border: 1px solid var(--color-border-default);
		animation: cascade-glow 3s ease-in-out infinite;
	}

	@keyframes cascade-glow {
		0%, 100% { 
			border-color: var(--color-border-default);
			box-shadow: none;
		}
		50% { 
			border-color: rgba(255, 0, 0, 0.3);
			box-shadow: inset 0 0 30px rgba(255, 0, 0, 0.1);
		}
	}

	.death-icon {
		font-size: var(--text-2xl);
		filter: drop-shadow(0 0 8px rgba(255, 0, 0, 0.5));
	}

	.flow-arrows {
		display: flex;
		gap: var(--space-4);
		color: var(--color-text-tertiary);
		font-size: var(--text-lg);
	}

	.arrow-down {
		animation: arrow-pulse 1s ease-in-out infinite;
	}

	.arrow-down:nth-child(2) {
		animation-delay: 0.2s;
	}

	@keyframes arrow-pulse {
		0%, 100% { opacity: 0.3; transform: translateY(0); }
		50% { opacity: 1; transform: translateY(3px); }
	}

	.split-result {
		display: flex;
		gap: var(--space-4);
	}

	.result-item {
		display: flex;
		align-items: center;
		gap: var(--space-1);
		font-size: var(--text-sm);
	}

	.result-item.survivors {
		color: var(--color-profit);
	}

	.result-item.burned {
		color: var(--color-amber);
	}

	.result-icon {
		font-size: var(--text-base);
	}

	.twist-footer {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		margin: 0;
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
		gap: 2px;
		width: 100%;
		max-width: 340px;
	}

	.risk-level {
		display: grid;
		grid-template-columns: 4px 1fr auto auto;
		gap: var(--space-2);
		padding: var(--space-1-5) var(--space-2);
		background: rgba(0, 0, 0, 0.3);
		font-size: var(--text-xs);
		opacity: 0;
		transform: translateY(-5px);
		animation: riskIn 0.3s ease-out forwards;
		animation-delay: calc(var(--delay) * 0.1s);
		align-items: center;
	}

	@keyframes riskIn {
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.level-indicator {
		width: 4px;
		height: 100%;
		border-radius: 2px;
	}

	.level-5 .level-indicator { background: var(--color-red); box-shadow: 0 0 8px var(--color-red); }
	.level-4 .level-indicator { background: #ff6600; box-shadow: 0 0 8px #ff6600; }
	.level-3 .level-indicator { background: var(--color-amber); box-shadow: 0 0 8px var(--color-amber); }
	.level-2 .level-indicator { background: var(--color-cyan); box-shadow: 0 0 8px var(--color-cyan); }
	.level-1 .level-indicator { background: var(--color-profit); box-shadow: 0 0 8px var(--color-profit); }

	.level-5 .level-death { color: var(--color-red); }
	.level-4 .level-death { color: #ff6600; }
	.level-3 .level-death { color: var(--color-amber); }
	.level-2 .level-death { color: var(--color-cyan); }
	.level-1 .level-death { color: var(--color-profit); }

	.level-name {
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		text-align: left;
	}

	.level-death {
		text-align: center;
		min-width: 8ch;
	}

	.level-reward {
		color: var(--color-text-secondary);
		text-align: right;
		min-width: 10ch;
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

	.edge-options {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		width: 100%;
		max-width: 320px;
	}

	.edge-item {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-2);
		background: rgba(0, 255, 255, 0.03);
		border: 1px solid var(--color-border-default);
		border-left: 3px solid var(--color-accent);
		text-align: left;
		opacity: 0;
		transform: translateX(-15px);
		animation: flowIn 0.4s ease-out forwards;
		animation-delay: calc(var(--delay) * 0.15s);
	}

	.edge-icon {
		font-size: var(--text-xl);
		width: 2.5ch;
		text-align: center;
	}

	.edge-icon.bracket {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-accent);
		font-weight: var(--font-bold);
		text-shadow: 0 0 8px var(--color-accent-glow);
		width: 3ch;
	}

	.edge-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
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

	.dim {
		color: var(--color-text-tertiary);
	}

	/* ═══════════════════════════════════════════════════════════════
	   SLIDE 5: THE TRUST
	   ═══════════════════════════════════════════════════════════════ */

	.slide-trust {
		gap: var(--space-3);
	}

	.trust-icon-container {
		position: relative;
		height: 50px;
	}

	.burn-animation {
		display: flex;
		gap: var(--space-1);
		font-size: var(--text-2xl);
	}

	.fire-emoji {
		animation: fire-dance 0.8s ease-in-out infinite;
	}

	.fire-emoji.delayed {
		animation-delay: 0.2s;
	}

	.fire-emoji.delayed-2 {
		animation-delay: 0.4s;
	}

	@keyframes fire-dance {
		0%, 100% { transform: translateY(0) scale(1); }
		50% { transform: translateY(-5px) scale(1.1); }
	}

	.trust-headline {
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
		margin: 0;
	}

	.trust-subline {
		font-size: var(--text-base);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		margin: 0;
	}

	.trust-proof {
		padding: var(--space-2) var(--space-3);
		background: rgba(0, 0, 0, 0.4);
		border: 1px solid var(--color-border-default);
	}

	.burn-address {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
	}

	.trust-warning {
		font-size: var(--text-sm);
	}

	.trust-warning p {
		margin: 0;
		color: var(--color-text-secondary);
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
		line-height: var(--leading-snug);
	}

	.cta-question {
		font-size: var(--text-base);
		color: var(--color-accent);
		margin: 0;
		text-shadow: 0 0 10px var(--color-accent-glow);
	}

	.cta-buttons {
		display: flex;
		gap: var(--space-3);
		flex-wrap: wrap;
		justify-content: center;
	}

	.cta-btn {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2) var(--space-4);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wide);
		cursor: pointer;
		transition: all 0.2s ease;
		position: relative;
		overflow: hidden;
	}

	.cta-btn::before {
		content: '';
		position: absolute;
		top: 0;
		left: -100%;
		width: 100%;
		height: 100%;
		background: linear-gradient(90deg, transparent, rgba(255,255,255,0.1), transparent);
		transition: left 0.5s ease;
	}

	.cta-btn:hover::before {
		left: 100%;
	}

	.cta-btn.primary {
		background: var(--color-accent);
		color: var(--color-bg-void);
		border: 2px solid var(--color-accent);
		animation: cta-pulse 2s ease-in-out infinite;
	}

	@keyframes cta-pulse {
		0%, 100% { 
			box-shadow: 0 0 10px var(--color-accent-glow);
		}
		50% { 
			box-shadow: 0 0 25px var(--color-accent-glow), 0 0 40px var(--color-accent-glow);
		}
	}

	.cta-btn.primary:hover {
		background: var(--color-accent-bright);
		box-shadow: 0 0 30px var(--color-accent-glow), 0 0 60px var(--color-accent-glow);
		transform: translateY(-2px);
		animation: none;
	}

	.cta-btn.secondary {
		background: transparent;
		color: var(--color-text-secondary);
		border: 2px solid var(--color-border-default);
	}

	.cta-btn.secondary:hover {
		color: var(--color-accent);
		border-color: var(--color-accent);
		box-shadow: 0 0 15px var(--color-accent-glow);
	}

	.btn-icon {
		font-size: var(--text-base);
	}

	.cta-disclaimer {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		margin: 0;
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
		position: relative;
		z-index: 15;
	}

	.nav-dots {
		display: flex;
		gap: var(--space-2);
	}

	.nav-dot {
		width: 28px;
		height: 4px;
		background: var(--color-border-default);
		border: none;
		cursor: pointer;
		position: relative;
		overflow: hidden;
		transition: all 0.2s;
	}

	.nav-dot:hover {
		background: var(--color-border-strong);
	}

	.nav-dot.active {
		background: rgba(0, 255, 255, 0.2);
	}

	.dot-progress {
		position: absolute;
		top: 0;
		left: 0;
		height: 100%;
		background: var(--color-accent);
		box-shadow: 0 0 8px var(--color-accent-glow);
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
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.nav-arrow:hover {
		color: var(--color-accent);
		border-color: var(--color-accent);
		box-shadow: 0 0 10px var(--color-accent-glow);
	}

	.arrow-char {
		font-size: var(--text-xs);
	}

	.nav-counter {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		min-width: 3ch;
		text-align: center;
		font-family: var(--font-mono);
	}

	/* ═══════════════════════════════════════════════════════════════
	   MATRIX TOGGLE
	   ═══════════════════════════════════════════════════════════════ */

	.matrix-toggle {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		cursor: pointer;
		user-select: none;
	}

	.toggle-input {
		position: absolute;
		opacity: 0;
		width: 0;
		height: 0;
	}

	.toggle-track {
		position: relative;
		width: 32px;
		height: 16px;
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-default);
		border-radius: 8px;
		transition: all 0.2s ease;
	}

	.toggle-thumb {
		position: absolute;
		top: 2px;
		left: 2px;
		width: 10px;
		height: 10px;
		background: var(--color-text-tertiary);
		border-radius: 50%;
		transition: all 0.2s ease;
	}

	.toggle-input:checked + .toggle-track {
		background: rgba(0, 255, 255, 0.2);
		border-color: var(--color-accent);
	}

	.toggle-input:checked + .toggle-track .toggle-thumb {
		left: 18px;
		background: var(--color-accent);
		box-shadow: 0 0 6px var(--color-accent-glow);
	}

	.toggle-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
		letter-spacing: var(--tracking-wide);
		transition: color 0.2s;
	}

	.toggle-input:checked ~ .toggle-label {
		color: var(--color-accent);
	}

	.matrix-toggle:hover .toggle-label {
		color: var(--color-text-secondary);
	}

	.matrix-toggle:hover .toggle-input:checked ~ .toggle-label {
		color: var(--color-accent);
	}

	/* ═══════════════════════════════════════════════════════════════
	   RESPONSIVE
	   ═══════════════════════════════════════════════════════════════ */

	@media (max-width: 640px) {
		.slides-container {
			min-height: 340px;
			padding: var(--space-3) var(--space-1);
		}

		.ascii-logo {
			font-size: 0.28rem;
		}

		.cta-buttons {
			flex-direction: column;
			width: 100%;
		}

		.cta-btn {
			width: 100%;
			justify-content: center;
		}

		.risk-ladder {
			max-width: 100%;
		}

		.edge-options {
			max-width: 100%;
		}

		.toggle-label {
			display: none;
		}

		.slide-nav {
			gap: var(--space-2);
		}
	}
</style>
