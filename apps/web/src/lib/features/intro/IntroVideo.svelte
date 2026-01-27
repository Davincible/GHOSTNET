<script lang="ts">
	interface Props {
		/** Video source URL */
		src?: string;
		/** Control playback from parent — starts/stops the video */
		active?: boolean;
	}

	let { src = 'https://i.imgur.com/59R2ABZ.mp4', active = true }: Props = $props();

	let videoEl: HTMLVideoElement | undefined = $state();
	let isMuted = $state(false);
	let isPlaying = $state(false);
	let hasEnded = $state(false);
	let progress = $state(0);
	let duration = $state(0);
	let loadError = $state(false);

	let progressPercent = $derived(duration > 0 ? (progress / duration) * 100 : 0);

	// ─── Smooth progress via requestAnimationFrame ─────────────
	// ontimeupdate fires ~4x/sec which causes visible stepping.
	// Instead we poll currentTime at display refresh rate (60fps).
	let rafId: number | undefined;

	function startProgressLoop() {
		function tick() {
			if (videoEl && !videoEl.paused && !videoEl.ended) {
				progress = videoEl.currentTime;
				duration = videoEl.duration || 0;
				rafId = requestAnimationFrame(tick);
			}
		}
		cancelProgressLoop();
		rafId = requestAnimationFrame(tick);
	}

	function cancelProgressLoop() {
		if (rafId !== undefined) {
			cancelAnimationFrame(rafId);
			rafId = undefined;
		}
	}

	// ─── Autoplay / pause when active changes ──────────────────
	$effect(() => {
		if (!videoEl) return;
		if (active) {
			videoEl.play().catch(() => {
				// Autoplay may be blocked — user can click play
			});
		} else {
			videoEl.pause();
			cancelProgressLoop();
		}
	});

	// Cleanup on unmount
	$effect(() => {
		return () => cancelProgressLoop();
	});

	// ─── Actions ───────────────────────────────────────────────

	/** Unmute requires a user gesture — this click satisfies the policy */
	function toggleMute() {
		if (videoEl) {
			videoEl.muted = !videoEl.muted;
			isMuted = videoEl.muted;
		}
	}

	function togglePlay() {
		if (!videoEl) return;
		if (videoEl.paused) {
			videoEl.play();
		} else {
			videoEl.pause();
			isPlaying = false;
		}
	}

	function replay() {
		if (!videoEl) return;
		videoEl.currentTime = 0;
		hasEnded = false;
		videoEl.play();
	}

	function seek(e: MouseEvent) {
		if (!videoEl || duration <= 0) return;
		const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
		const pct = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
		videoEl.currentTime = pct * duration;
	}

	// ─── Video events ──────────────────────────────────────────

	function handlePlay() {
		isPlaying = true;
		hasEnded = false;
		startProgressLoop();
	}

	function handlePause() {
		isPlaying = false;
		cancelProgressLoop();
		// Sync final position
		if (videoEl) progress = videoEl.currentTime;
	}

	function handleEnded() {
		isPlaying = false;
		hasEnded = true;
		cancelProgressLoop();
		// Snap to 100%
		if (videoEl) {
			progress = videoEl.duration || 0;
			duration = videoEl.duration || 0;
		}
	}

	function handleError() {
		loadError = true;
	}

	// ─── Helpers ───────────────────────────────────────────────

	function formatTime(seconds: number): string {
		const mins = Math.floor(seconds / 60);
		const secs = Math.floor(seconds % 60);
		return `${mins}:${secs.toString().padStart(2, '0')}`;
	}
</script>

<div class="video-player">
	{#if loadError}
		<div class="error-state">
			<span class="error-icon">[!]</span>
			<span class="error-text">VIDEO FEED CORRUPTED</span>
		</div>
	{:else}
		<!-- Video -->
		<div class="video-container">
			<video
				bind:this={videoEl}
			{src}
			class="video"
			playsinline
				preload="auto"
			onplay={handlePlay}
			onpause={handlePause}
			onended={handleEnded}
			onerror={handleError}
			>
				<track kind="captions" />
			</video>

			<!-- Play/Pause click zone — div (not button) to avoid nesting buttons -->
			<!-- svelte-ignore a11y_no_static_element_interactions -->
			<div class="video-click-zone" onclick={togglePlay} onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); togglePlay(); } }} role="button" tabindex="0" aria-label={isPlaying ? 'Pause' : 'Play'}>
				{#if !isPlaying && !hasEnded}
					<div class="play-indicator">
						<span class="play-icon">▶</span>
					</div>
				{/if}
				{#if hasEnded}
					<button class="replay-indicator" onclick={(e) => { e.stopPropagation(); replay(); }}>
						<span class="replay-icon">↻</span>
						<span class="replay-text">REPLAY</span>
					</button>
				{/if}
			</div>

			<!-- Scanlines -->
			<div class="scanlines"></div>
		</div>

		<!-- Controls -->
		<div class="controls">
			<!-- Progress bar -->
			<button class="progress-track" onclick={seek} aria-label="Seek video">
				<div class="progress-fill" style="width: {progressPercent}%"></div>
			</button>

			<div class="controls-row">
				<!-- Left: play/pause + time -->
				<div class="controls-left">
					<button class="ctrl-btn" onclick={togglePlay} aria-label={isPlaying ? 'Pause' : 'Play'}>
						<span class="ctrl-icon">{isPlaying ? '⏸' : '▶'}</span>
					</button>
					<span class="time-display">{formatTime(progress)} / {formatTime(duration)}</span>
				</div>

				<!-- Right: mute -->
				<div class="controls-right">
					<button class="ctrl-btn unmute-btn" class:muted={isMuted} onclick={toggleMute} aria-label={isMuted ? 'Unmute' : 'Mute'}>
						<span class="ctrl-icon">{isMuted ? '🔇' : '🔊'}</span>
						<span class="ctrl-label">{isMuted ? 'UNMUTE' : 'MUTE'}</span>
					</button>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.video-player {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	/* ═══════════════════════════════════════════════════════════════
	   VIDEO
	   ═══════════════════════════════════════════════════════════════ */

	.video-container {
		position: relative;
		width: 100%;
		background: #000;
		/* 16:9 aspect ratio fallback */
		aspect-ratio: 16 / 9;
		overflow: hidden;
	}

	.video {
		width: 100%;
		height: 100%;
		object-fit: contain;
		background: #000;
		display: block;
	}

	/* Click zone for play/pause */
	.video-click-zone {
		position: absolute;
		inset: 0;
		background: none;
		border: none;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 5;
	}

	/* Scanlines over video */
	.scanlines {
		position: absolute;
		inset: 0;
		background: repeating-linear-gradient(
			0deg,
			transparent,
			transparent 2px,
			rgba(0, 229, 204, 0.012) 2px,
			rgba(0, 229, 204, 0.012) 4px
		);
		pointer-events: none;
		z-index: 4;
	}

	/* Play indicator (shown when paused) */
	.play-indicator {
		width: 64px;
		height: 64px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: rgba(0, 0, 0, 0.6);
		border: 2px solid var(--color-accent, #00e5cc);
		border-radius: 50%;
		backdrop-filter: blur(4px);
		box-shadow: 0 0 20px rgba(0, 229, 204, 0.3);
		transition: all 0.2s;
	}

	.video-click-zone:hover .play-indicator {
		box-shadow: 0 0 30px rgba(0, 229, 204, 0.5);
		transform: scale(1.05);
	}

	.play-icon {
		font-size: 1.4rem;
		color: var(--color-accent, #00e5cc);
		margin-left: 3px; /* optical center for triangle */
	}

	/* Replay indicator */
	.replay-indicator {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-2, 0.5rem);
		padding: var(--space-3, 0.75rem) var(--space-6, 1.5rem);
		background: rgba(0, 0, 0, 0.7);
		border: 1px solid var(--color-accent, #00e5cc);
		backdrop-filter: blur(4px);
		cursor: pointer;
		transition: all 0.2s;
	}

	.replay-indicator:hover {
		background: rgba(0, 229, 204, 0.1);
		box-shadow: 0 0 20px rgba(0, 229, 204, 0.3);
	}

	.replay-icon {
		font-size: 1.5rem;
		color: var(--color-accent, #00e5cc);
	}

	.replay-text {
		font-family: var(--font-mono, monospace);
		font-size: var(--text-xs, 0.75rem);
		color: var(--color-accent, #00e5cc);
		letter-spacing: 0.15em;
	}

	/* ═══════════════════════════════════════════════════════════════
	   CONTROLS
	   ═══════════════════════════════════════════════════════════════ */

	.controls {
		display: flex;
		flex-direction: column;
		gap: var(--space-1, 0.25rem);
		padding: var(--space-2, 0.5rem) 0 0;
	}

	.progress-track {
		width: 100%;
		height: 4px;
		background: rgba(255, 255, 255, 0.1);
		border: none;
		padding: 0;
		cursor: pointer;
		position: relative;
		transition: height 0.15s;
	}

	.progress-track:hover {
		height: 6px;
		background: rgba(255, 255, 255, 0.15);
	}

	.progress-fill {
		position: absolute;
		top: 0;
		left: 0;
		height: 100%;
		background: var(--color-accent, #00e5cc);
		box-shadow: 0 0 6px rgba(0, 229, 204, 0.5);
		/* No transition — rAF provides smooth 60fps updates directly */
		pointer-events: none;
	}

	.controls-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: var(--space-1, 0.25rem) 0;
	}

	.controls-left {
		display: flex;
		align-items: center;
		gap: var(--space-2, 0.5rem);
	}

	.controls-right {
		display: flex;
		align-items: center;
	}

	.ctrl-btn {
		display: flex;
		align-items: center;
		gap: var(--space-1, 0.25rem);
		background: none;
		border: none;
		color: var(--color-text-secondary, #888);
		font-family: var(--font-mono, monospace);
		font-size: var(--text-xs, 0.75rem);
		cursor: pointer;
		padding: var(--space-1, 0.25rem);
		transition: color 0.15s;
	}

	.ctrl-btn:hover {
		color: var(--color-accent, #00e5cc);
	}

	.ctrl-icon {
		font-size: var(--text-sm, 0.875rem);
	}

	.ctrl-label {
		letter-spacing: 0.08em;
	}

	/* Highlight unmute when muted — draw attention */
	.unmute-btn.muted {
		color: var(--color-accent, #00e5cc);
		animation: unmute-pulse 2s ease-in-out 3;
	}

	@keyframes unmute-pulse {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.5; }
	}

	.time-display {
		font-family: var(--font-mono, monospace);
		font-size: var(--text-xs, 0.75rem);
		color: var(--color-text-tertiary, #555);
	}

	/* ═══════════════════════════════════════════════════════════════
	   ERROR STATE
	   ═══════════════════════════════════════════════════════════════ */

	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: var(--space-3, 0.75rem);
		padding: var(--space-8, 2rem);
		font-family: var(--font-mono, monospace);
		color: var(--color-red, #ff3366);
		aspect-ratio: 16 / 9;
		background: #000;
	}

	.error-icon {
		font-size: 1.5rem;
		animation: error-blink 1s step-end infinite;
	}

	.error-text {
		font-size: var(--text-sm, 0.875rem);
		letter-spacing: 0.1em;
	}

	@keyframes error-blink {
		0%, 100% { opacity: 1; }
		50% { opacity: 0; }
	}

	/* ═══════════════════════════════════════════════════════════════
	   RESPONSIVE
	   ═══════════════════════════════════════════════════════════════ */

	@media (max-width: 640px) {
		.play-indicator {
			width: 48px;
			height: 48px;
		}

		.play-icon {
			font-size: 1rem;
		}
	}
</style>
