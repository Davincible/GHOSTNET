<!--
  BootSequence.svelte
  ====================
  Terminal boot animation that plays on first visit.
  Skippable via click/keypress. Persists seen-state to localStorage.
-->
<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';
	import { BOOT_SEEN_KEY } from './types';

	interface Props {
		oncomplete: () => void;
	}

	let { oncomplete }: Props = $props();

	// ── Boot sequence lines ──────────────────────────────────
	// The progress bar is handled specially (fills over time).
	const LINES = [
		'> Scanning frequencies...',
		'__PROGRESS__',
		'> SIGNAL DETECTED',
		'> Decrypting transmission...',
		'> SOURCE: GHOSTNET',
		'> STATUS: PRE-LAUNCH',
		'> PRESALE: ACTIVE',
		'>',
		'> Establishing connection...',
	] as const;

	const CHAR_DELAY_MS = 18;
	const LINE_PAUSE_MS = 120;
	const PROGRESS_DURATION_MS = 900;
	const PROGRESS_WIDTH = 30;

	let visibleLines = $state<string[]>([]);
	let currentChar = $state(0);
	let currentLineIndex = $state(0);
	let progressFill = $state(0);
	let cursorVisible = $state(true);
	let finished = $state(false);

	// Derived: the text being typed on the current line
	let typingLine = $derived(
		currentLineIndex < LINES.length && LINES[currentLineIndex] !== '__PROGRESS__'
			? LINES[currentLineIndex].slice(0, currentChar)
			: ''
	);

	// Derived: progress bar string
	let progressBar = $derived.by(() => {
		const filled = Math.round((progressFill / 100) * PROGRESS_WIDTH);
		const empty = PROGRESS_WIDTH - filled;
		return '> ' + '█'.repeat(filled) + '░'.repeat(empty);
	});

	let animationFrame: number | undefined;
	let timeout: ReturnType<typeof setTimeout> | undefined;

	function markSeen(): void {
		if (browser) {
			try {
				localStorage.setItem(BOOT_SEEN_KEY, '1');
			} catch {
				// Storage full or blocked — not critical
			}
		}
	}

	function finish(): void {
		if (finished) return;
		finished = true;

		// Clear any pending timers
		if (timeout !== undefined) clearTimeout(timeout);
		if (animationFrame !== undefined) cancelAnimationFrame(animationFrame);

		markSeen();
		oncomplete();
	}

	function skip(): void {
		finish();
	}

	function handleKeydown(): void {
		skip();
	}

	// ── Main animation loop ──────────────────────────────────
	function typeNextChar(): void {
		if (finished) return;

		if (currentLineIndex >= LINES.length) {
			// All lines done — brief pause then complete
			timeout = setTimeout(finish, 400);
			return;
		}

		const line = LINES[currentLineIndex];

		if (line === '__PROGRESS__') {
			// Animate progress bar
			animateProgress();
			return;
		}

		if (currentChar < line.length) {
			currentChar++;
			timeout = setTimeout(typeNextChar, CHAR_DELAY_MS);
		} else {
			// Line complete — commit it and move on
			visibleLines = [...visibleLines, line];
			currentLineIndex++;
			currentChar = 0;
			timeout = setTimeout(typeNextChar, LINE_PAUSE_MS);
		}
	}

	function animateProgress(): void {
		const start = performance.now();

		function tick(now: number): void {
			if (finished) return;

			const elapsed = now - start;
			progressFill = Math.min(100, (elapsed / PROGRESS_DURATION_MS) * 100);

			if (elapsed < PROGRESS_DURATION_MS) {
				animationFrame = requestAnimationFrame(tick);
			} else {
				// Progress complete — commit line and advance
				progressFill = 100;
				const filledBar = '> ' + '█'.repeat(PROGRESS_WIDTH);
				visibleLines = [...visibleLines, filledBar];
				currentLineIndex++;
				currentChar = 0;
				timeout = setTimeout(typeNextChar, LINE_PAUSE_MS);
			}
		}

		animationFrame = requestAnimationFrame(tick);
	}

	// ── Cursor blink ─────────────────────────────────────────
	let cursorInterval: ReturnType<typeof setInterval> | undefined;

	onMount(() => {
		// Check if already seen
		if (browser) {
			try {
				if (localStorage.getItem(BOOT_SEEN_KEY)) {
					oncomplete();
					return;
				}
			} catch {
				// Can't read storage — play animation anyway
			}
		}

		// Start typing
		timeout = setTimeout(typeNextChar, 300);

		// Cursor blink
		cursorInterval = setInterval(() => {
			cursorVisible = !cursorVisible;
		}, 530);

		return () => {
			if (timeout !== undefined) clearTimeout(timeout);
			if (animationFrame !== undefined) cancelAnimationFrame(animationFrame);
			if (cursorInterval !== undefined) clearInterval(cursorInterval);
		};
	});

	// Whether we're currently on the progress bar line
	let isOnProgress = $derived(
		currentLineIndex < LINES.length && LINES[currentLineIndex] === '__PROGRESS__'
	);
</script>

<svelte:window onkeydown={handleKeydown} />

<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions a11y_no_noninteractive_element_interactions -->
<div class="boot" onclick={skip} role="presentation">
	<div class="boot-terminal">
		{#each visibleLines as line}
			<div class="boot-line">{line}</div>
		{/each}

		{#if !finished && currentLineIndex < LINES.length}
			{#if isOnProgress}
				<div class="boot-line">{progressBar}</div>
			{:else}
				<div class="boot-line">
					{typingLine}<span class="cursor" class:hidden={!cursorVisible}>█</span>
				</div>
			{/if}
		{/if}
	</div>

	<div class="skip-hint">CLICK OR PRESS ANY KEY TO SKIP</div>
</div>

<style>
	.boot {
		position: fixed;
		inset: 0;
		z-index: 9999;
		background: var(--color-bg-void, #050505);
		display: flex;
		flex-direction: column;
		justify-content: center;
		align-items: center;
		cursor: pointer;
		padding: var(--space-4, 1rem);
	}

	.boot-terminal {
		font-family: var(--font-mono, 'IBM Plex Mono', monospace);
		font-size: var(--text-sm, 0.8125rem);
		color: var(--color-accent, #00e5cc);
		line-height: 1.6;
		max-width: 600px;
		width: 100%;
	}

	.boot-line {
		white-space: pre;
		min-height: 1.6em;
	}

	.cursor {
		animation: none;
		opacity: 1;
	}

	.cursor.hidden {
		opacity: 0;
	}

	.skip-hint {
		position: absolute;
		bottom: var(--space-6, 1.5rem);
		font-family: var(--font-mono, 'IBM Plex Mono', monospace);
		font-size: var(--text-xs, 0.625rem);
		color: var(--color-text-tertiary, rgba(255, 255, 255, 0.3));
		letter-spacing: var(--tracking-wider, 0.12em);
		text-transform: uppercase;
	}
</style>
