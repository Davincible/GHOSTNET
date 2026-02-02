<script lang="ts">
	/**
	 * MatrixRain - Authentic Matrix-style digital rain effect
	 *
	 * Features:
	 * - Trail-based simulation with proper glyph fading
	 * - Bright head glyph with optional glow effect
	 * - Configurable character set, colors, and speeds
	 * - Performance optimized with frame limiting and visibility pause
	 * - HiDPI support for crisp rendering on retina displays
	 * - REACTIVE: All props update in real-time WITHOUT resetting animation
	 */
	import { onMount } from 'svelte';

	// ═══════════════════════════════════════════════════════════════════════════
	// PROPS INTERFACE
	// ═══════════════════════════════════════════════════════════════════════════

	interface Props {
		// === Core Visual ===
		columns?: number | 'auto';
		charset?: string;
		fontSize?: number;
		fontFamily?: string;

		// === Trail Configuration ===
		trailLength?: number;
		/** How much trail length varies between drops (0 = uniform, 1 = 50%-150% range). */
		trailLengthVariance?: number;
		glyphSpacing?: number;
		/** Multiplier for stream density (higher = more concurrent streams). */
		generationMultiplier?: number;
		fadeRate?: number;

		// === Motion ===
		/** Movement mode: 'smooth' for pixel-by-pixel, 'grid' for cell-based steps. */
		mode?: 'smooth' | 'grid';
		/** Grid step size as fraction of cell height (0.5 = half cell, 1 = full cell). */
		gridStep?: number;
		baseSpeed?: number;
		speedVariance?: number;

		// === Colors ===
		/** Primary color for trail glyphs. */
		color?: string;
		/** Color for head glyph (when brightHead is true). */
		headColor?: string;
		/** Whether head glyph uses separate bright color. */
		brightHead?: boolean;
		/** Whether to apply glow effect to head character. */
		glow?: boolean;
		/** Glow blur radius in pixels. */
		glowRadius?: number;

		// === Opacity ===
		headOpacity?: number;
		trailOpacity?: number;

		// === Character Mutation ===
		mutationRate?: number;
		headMutationRate?: number;

		// === Performance ===
		/** Target frame rate (adaptive - will run faster if needed). */
		targetFps?: number;
		/** Minimum frame rate floor (never drops below this). */
		minFps?: number;
		hiDpi?: boolean;
		pauseWhenHidden?: boolean;
		playing?: boolean;

		// ── Legacy prop aliases ──
		density?: number;
		speed?: number;
		opacity?: number;
	}

	// ═══════════════════════════════════════════════════════════════════════════
	// DEFAULTS & PROPS
	// ═══════════════════════════════════════════════════════════════════════════

	const DEFAULT_CHARSET =
		'ゴーストネット01アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン$DATA';

	let {
		columns = 'auto',
		charset = DEFAULT_CHARSET,
		fontSize = 14,
		fontFamily = 'monospace',
		trailLength = 20,
		trailLengthVariance = 0.5,
		glyphSpacing = 1.2,
		generationMultiplier = 1,
		fadeRate = 0.05,
		mode = 'grid',
		gridStep = 1,
		baseSpeed = 2,
		speedVariance = 0.5,
		color = 'var(--color-accent, #00ff41)',
		headColor = '#ffffff',
		brightHead = true,
		glow = true,
		glowRadius = 10,
		headOpacity = 1.0,
		trailOpacity = 0.7,
		mutationRate = 1.0,
		headMutationRate = 1.0,
		targetFps = 60,
		minFps = 24,
		hiDpi = true,
		pauseWhenHidden = true,
		playing = true,
		density,
		speed,
		opacity,
	}: Props = $props();

	// ═══════════════════════════════════════════════════════════════════════════
	// RESOLVED PROPS (reactive)
	// ═══════════════════════════════════════════════════════════════════════════

	const resolvedColumns = $derived(density !== undefined ? density : columns);
	const resolvedBaseSpeed = $derived(speed !== undefined ? speed * 2 : baseSpeed);
	const resolvedTrailOpacity = $derived(opacity !== undefined ? opacity * 2.5 : trailOpacity);
	const resolvedGenerationMultiplier = $derived(Math.max(0.1, generationMultiplier));

	// ═══════════════════════════════════════════════════════════════════════════
	// COLOR RESOLUTION
	// ═══════════════════════════════════════════════════════════════════════════

	function resolveColor(cssColor: string): string {
		if (typeof document === 'undefined') return cssColor;
		const temp = document.createElement('div');
		temp.style.color = cssColor;
		document.body.appendChild(temp);
		const computed = getComputedStyle(temp).color;
		document.body.removeChild(temp);
		return computed;
	}

	const resolvedRainColor = $derived.by(() => resolveColor(color));
	const resolvedHeadColor = $derived.by(() => resolveColor(headColor));

	// ═══════════════════════════════════════════════════════════════════════════
	// INTERNAL STATE
	// ═══════════════════════════════════════════════════════════════════════════

	let canvas: HTMLCanvasElement;
	let isVisible = $state(true);

	// Animation state (persists across prop changes)
	let drops: Drop[] = [];
	let canvasWidth = 0;
	let canvasHeight = 0;

	interface Glyph {
		char: string;
		alpha: number;
	}

	interface Drop {
		x: number;
		y: number;
		speed: number;
		trail: Glyph[];
		head: number;
		count: number;
		lastSpawnY: number;
		maxTrail: number; // Each drop remembers its trail length
		depthOpacity: number; // Per-drop depth multiplier for opacity
		lastGridY: number; // For grid mode: track last cell position for sync mutations
		moveAccum: number; // For grid mode: accumulator for fractional movement
	}

	// ═══════════════════════════════════════════════════════════════════════════
	// HELPER FUNCTIONS
	// ═══════════════════════════════════════════════════════════════════════════

	function randomChar(): string {
		return charset[Math.floor(Math.random() * charset.length)];
	}

	function createDrop(
		x: number,
		baseTrailLength: number,
		variance: number,
		isInitial = false
	): Drop {
		const speedMultiplier = 1 - speedVariance + Math.random() * speedVariance * 2;
		const spawnSpacing = fontSize * glyphSpacing;
		const depthOpacity = 0.55 + Math.random() * 0.45;

		// Randomize trail length per drop based on variance parameter
		// variance=0: all same length
		// variance=0.5: 40%-160% of base (e.g., base=20 → 8-32)
		// variance=1.0: 20%-180% of base (e.g., base=20 → 4-36)
		const minFactor = 1 - variance * 0.8;
		const maxFactor = 1 + variance * 0.8;
		const varianceFactor = minFactor + Math.random() * (maxFactor - minFactor);
		const maxTrail = Math.max(4, Math.floor(baseTrailLength * varianceFactor));

		// Pre-fill trails so screen isn't empty
		// Initial drops: 50-100% filled, positioned on-screen
		// Respawns: 30-80% filled, positioned off-screen but trail extends down
		const prefillRatio = isInitial
			? 0.5 + Math.random() * 0.5 // 50-100% for initial
			: 0.3 + Math.random() * 0.5; // 30-80% for respawns
		const prefillCount = Math.floor(maxTrail * prefillRatio);

		// Start position
		// Initial: random on-screen position
		// Respawn: off-screen top, but trail will show as it enters
		const startY = isInitial ? Math.random() * canvasHeight : -spawnSpacing * (Math.random() * 5); // Just above screen

		// Build pre-filled trail with characters
		const trail = new Array(maxTrail).fill(null).map((_, i) => ({
			char: i < prefillCount ? randomChar() : '',
			alpha: 1,
		}));

		return {
			x,
			y: startY,
			speed: resolvedBaseSpeed * speedMultiplier,
			trail,
			head: Math.max(0, prefillCount - 1),
			count: prefillCount,
			lastSpawnY: startY,
			maxTrail,
			depthOpacity,
			lastGridY: startY,
			moveAccum: Math.random() * 10, // Stagger initial movement
		};
	}

	// ═══════════════════════════════════════════════════════════════════════════
	// COLUMN COUNT SYNC (smooth add/remove drops without reset)
	// ═══════════════════════════════════════════════════════════════════════════

	function getTargetColumnCount(): number {
		if (canvasWidth === 0) return 0;
		const baseCount =
			resolvedColumns === 'auto'
				? Math.max(1, Math.floor(canvasWidth / (fontSize * 1.5)))
				: Math.max(1, Math.floor(resolvedColumns as number));
		return Math.max(1, Math.round(baseCount * resolvedGenerationMultiplier));
	}

	function syncDropCount() {
		const targetCount = getTargetColumnCount();
		if (targetCount === 0) return;

		const columnWidth = canvasWidth / targetCount;

		// Add drops if needed (initial drops are pre-filled)
		const isInitialSetup = drops.length === 0;
		while (drops.length < targetCount) {
			const x = drops.length * columnWidth + columnWidth / 2;
			drops.push(createDrop(x, trailLength, trailLengthVariance, isInitialSetup));
		}

		// Remove drops if needed
		while (drops.length > targetCount) {
			drops.pop();
		}

		// Update X positions for all drops
		for (let i = 0; i < drops.length; i++) {
			drops[i].x = i * columnWidth + columnWidth / 2;
		}
	}

	// React to column count changes
	$effect(() => {
		// Read reactive dependencies
		void resolvedColumns;
		void fontSize;
		void resolvedGenerationMultiplier;
		// Sync drops (only if canvas is initialized)
		if (canvasWidth > 0) {
			syncDropCount();
		}
	});

	// React to trail length/variance changes - recreate all drops
	$effect(() => {
		// Read reactive dependencies
		void trailLength;
		void trailLengthVariance;
		// Recreate all drops with new variance (only if already initialized)
		if (canvasWidth > 0 && drops.length > 0) {
			const columnWidth = canvasWidth / drops.length;
			for (let i = 0; i < drops.length; i++) {
				drops[i] = createDrop(
					i * columnWidth + columnWidth / 2,
					trailLength,
					trailLengthVariance,
					true
				);
			}
		}
	});

	// ═══════════════════════════════════════════════════════════════════════════
	// MAIN ANIMATION (onMount - runs once, reads props reactively in draw loop)
	// ═══════════════════════════════════════════════════════════════════════════

	onMount(() => {
		const ctx = canvas.getContext('2d');
		if (!ctx) return;

		let animationId: number;
		let lastFrameTime = 0;
		let dpr = 1;

		// ── Resize handler ──
		const resize = () => {
			dpr = hiDpi ? window.devicePixelRatio || 1 : 1;
			canvasWidth = canvas.offsetWidth;
			canvasHeight = canvas.offsetHeight;
			canvas.width = canvasWidth * dpr;
			canvas.height = canvasHeight * dpr;
			ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

			// Initialize or sync drops
			if (drops.length === 0) {
				syncDropCount();
			} else {
				// Just update X positions on resize
				const columnWidth = canvasWidth / drops.length;
				for (let i = 0; i < drops.length; i++) {
					drops[i].x = i * columnWidth + columnWidth / 2;
				}
			}
		};

		// ── Draw frame ──
		const draw = (timestamp: number) => {
			// Adaptive frame rate:
			// - Grid mode: runs at native refresh rate (accumulator handles timing)
			// - Smooth mode: respects targetFps
			// - Never drops below minFps
			const useGridMode = mode === 'grid';
			const effectiveFps = useGridMode ? 60 : targetFps; // Grid mode runs at 60fps for smooth accumulation
			const maxInterval = 1000 / minFps; // Never slower than minFps
			const targetInterval = 1000 / effectiveFps;
			const frameInterval = Math.min(targetInterval, maxInterval);

			const elapsed = timestamp - lastFrameTime;
			if (elapsed < frameInterval) {
				animationId = requestAnimationFrame(draw);
				return;
			}
			lastFrameTime = timestamp - (elapsed % frameInterval);

			// Skip if paused or hidden
			if (!playing || (pauseWhenHidden && !isVisible)) {
				animationId = requestAnimationFrame(draw);
				return;
			}

			// Clear canvas
			ctx.clearRect(0, 0, canvasWidth, canvasHeight);
			ctx.font = `${fontSize}px ${fontFamily}`;
			ctx.textAlign = 'center';

			// Read current prop values (reactive)
			// Note: We access props directly to ensure reactivity in the animation closure
			const spawnSpacing = fontSize * glyphSpacing;
			// generationMultiplier controls stream count, not per-stream spawn rate
			const spawnThreshold = spawnSpacing;
			const currentTrailLength = trailLength;
			const currentBaseSpeed = resolvedBaseSpeed;
			const currentFadeRate = fadeRate;
			const currentBrightHead = brightHead;
			const currentGlow = glow;
			const currentGlowRadius = glowRadius;
			const currentHeadOpacity = headOpacity;
			const currentTrailOpacity = resolvedTrailOpacity;
			const rainColor = resolvedRainColor;
			const headColorValue = currentBrightHead ? resolvedHeadColor : rainColor;

			// Grid mode settings
			const isGridMode = mode === 'grid';
			const cellHeight = spawnSpacing;
			const stepSize = isGridMode ? cellHeight * gridStep : 1;

			// Process each drop
			for (let i = 0; i < drops.length; i++) {
				const drop = drops[i];
				const depthOpacity = drop.depthOpacity;

				// Note: Trail length/variance changes are handled by the $effect that
				// recreates all drops. No per-frame sync needed here - each drop keeps
				// its own randomized maxTrail value.

				// Update speed if baseSpeed changed
				const speedMultiplier = drop.speed / (currentBaseSpeed || 1);
				if (Math.abs(speedMultiplier - 1) > 0.5) {
					// Speed changed significantly, adjust
					drop.speed = currentBaseSpeed * (0.5 + Math.random());
				}

				// Movement: smooth mode uses fractional pixels, grid mode uses accumulator-based stepping
				if (isGridMode) {
					// Accumulate speed each frame, step when threshold reached
					drop.moveAccum += drop.speed;
					if (drop.moveAccum >= stepSize) {
						// Calculate how many steps we can take (usually 1, but could be more at high speeds)
						const steps = Math.floor(drop.moveAccum / stepSize);
						drop.y += stepSize * steps;
						drop.moveAccum -= stepSize * steps;
					}
				} else {
					drop.y += drop.speed;
				}

				// Spawn new glyphs based on distance moved
				// Use while loop to spawn multiple glyphs if genMultiplier is high
				while (drop.y - drop.lastSpawnY >= spawnThreshold) {
					const char =
						Math.random() < headMutationRate
							? randomChar()
							: drop.trail[drop.head]?.char || randomChar();

					drop.head = (drop.head + 1) % drop.maxTrail;
					drop.trail[drop.head] = { char: char || randomChar(), alpha: 1 };
					if (drop.count < drop.maxTrail) {
						drop.count++;
					}
					// Increment by threshold, not set to drop.y - allows multiple spawns per frame
					drop.lastSpawnY += spawnThreshold;
				}

				// Draw trail glyphs
				// In grid mode, snap the base Y position to step grid (not cell grid)
				// Use spawnSpacing for drawing (keeps glyphs readable)
				const baseY = isGridMode ? Math.floor(drop.y / stepSize) * stepSize : drop.y;
				let glyphY = baseY - spawnSpacing * drop.count;

				// Grid mode: detect step change and batch-mutate all characters
				// Uses stepSize so mutations sync with visual movement
				const currentGridY = Math.floor(drop.y / stepSize);
				const lastGridY = Math.floor(drop.lastGridY / stepSize);
				const didStep = isGridMode && currentGridY !== lastGridY;

				// If we stepped to a new cell in grid mode, mutate all characters
				// (Grid mode uses position-based gradient for opacity, not time-based fade)
				if (didStep) {
					for (let j = 0; j < drop.count; j++) {
						const idx = (drop.head - drop.count + 1 + j + drop.maxTrail) % drop.maxTrail;
						const glyph = drop.trail[idx];
						if (glyph) {
							const isHead = j === drop.count - 1;
							// Mutate based on rate (read props directly for reactivity)
							const rate = isHead ? headMutationRate : mutationRate;
							if (Math.random() < rate) {
								glyph.char = randomChar();
							}
						}
					}
					drop.lastGridY = drop.y;
				}

				for (let j = 0; j < drop.count; j++) {
					const idx = (drop.head - drop.count + 1 + j + drop.maxTrail) % drop.maxTrail;
					const glyph = drop.trail[idx];

					// Grid mode: always draw if glyph exists (uses position-based opacity)
					// Smooth mode: only draw if alpha > 0 (uses time-based fade)
					const shouldDraw = glyph && (isGridMode || glyph.alpha > 0);
					if (shouldDraw) {
						const isHead = j === drop.count - 1;

						// In grid mode, snap each glyph Y to step grid
						const drawY = isGridMode ? Math.round(glyphY / stepSize) * stepSize : glyphY;

						if (isHead) {
							// Draw head with glow
							if (currentGlow) {
								ctx.shadowColor = headColorValue;
								ctx.shadowBlur = currentGlowRadius;
							}
							ctx.fillStyle = headColorValue;
							ctx.globalAlpha = currentHeadOpacity * currentTrailOpacity * depthOpacity;

							// Smooth mode: random per-frame mutation
							if (!isGridMode && Math.random() < headMutationRate) {
								glyph.char = randomChar();
							}
						} else {
							// Draw trail with position-based gradient (tail=dim, near-head=bright)
							ctx.shadowBlur = 0;
							ctx.fillStyle = rainColor;

							// Position factor: 0 at tail, approaches 1 near head
							// j=0 is oldest (tail), j=drop.count-2 is closest to head
							const positionFactor = (j + 1) / drop.count;

							// Grid mode: position-based gradient only
							// Smooth mode: position + time-based fade
							const alphaFactor = isGridMode ? positionFactor : positionFactor * glyph.alpha;
							ctx.globalAlpha = currentTrailOpacity * alphaFactor * depthOpacity;

							// Smooth mode: random per-frame mutation and fade
							if (!isGridMode) {
								if (Math.random() < mutationRate) {
									glyph.char = randomChar();
								}
								// Per-frame fade only in smooth mode
								glyph.alpha = Math.max(0, glyph.alpha - currentFadeRate);
							}
						}

						ctx.fillText(glyph.char, drop.x, drawY);
					}

					glyphY += spawnSpacing;
				}

				ctx.shadowBlur = 0;

				// Reset drop if fully off screen (respawns are not initial, so less prefill)
				if (drop.y - spawnSpacing * drop.maxTrail > canvasHeight) {
					const columnWidth = canvasWidth / drops.length;
					drops[i] = createDrop(
						i * columnWidth + columnWidth / 2,
						currentTrailLength,
						trailLengthVariance,
						false
					);
				}
			}

			ctx.globalAlpha = 1;
			animationId = requestAnimationFrame(draw);
		};

		// ── Visibility handler ──
		const handleVisibilityChange = () => {
			isVisible = document.visibilityState === 'visible';
		};

		// ── Initialize ──
		resize();
		window.addEventListener('resize', resize);
		document.addEventListener('visibilitychange', handleVisibilityChange);
		animationId = requestAnimationFrame(draw);

		// ── Cleanup ──
		return () => {
			cancelAnimationFrame(animationId);
			window.removeEventListener('resize', resize);
			document.removeEventListener('visibilitychange', handleVisibilityChange);
		};
	});
</script>

<canvas bind:this={canvas} class="matrix-rain"></canvas>

<style>
	.matrix-rain {
		position: absolute;
		inset: 0;
		width: 100%;
		height: 100%;
		pointer-events: none;
		z-index: 0;
	}
</style>
