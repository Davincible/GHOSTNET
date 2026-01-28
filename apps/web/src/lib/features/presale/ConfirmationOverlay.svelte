<script lang="ts">
	interface Props {
		allocation: bigint;
		address: `0x${string}`;
		ondismiss?: () => void;
	}

	let { allocation, address, ondismiss }: Props = $props();

	function formatTokens(amount: bigint): string {
		const num = Number(amount) / 1e18;
		if (num >= 1_000_000) return `${(num / 1_000_000).toFixed(1)}M`;
		if (num >= 1_000) return Math.round(num).toLocaleString();
		return num.toFixed(0);
	}

	function shortAddr(addr: `0x${string}`): string {
		return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
	}

	const PROGRESS_BAR = '░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░';
	const FILLED_CHAR = '█';

	let lines = $derived([
		PROGRESS_BAR,
		'ALLOCATION CONFIRMED',
		`${formatTokens(allocation)} $DATA reserved for ${shortAddr(address)}`,
		'Claim available at TGE',
		'',
		'Welcome to GHOSTNET, operator.',
		'The network remembers.',
	]);

	/** Index of the line currently being typed */
	let currentLine = $state(0);
	/** Characters revealed in the current line */
	let charIndex = $state(0);
	/** Whether all lines have finished typing */
	let complete = $state(false);

	// Build the progress bar: replace ░ with █ up to charIndex
	function renderProgressBar(chars: number): string {
		const filled = Math.min(chars, PROGRESS_BAR.length);
		return FILLED_CHAR.repeat(filled) + PROGRESS_BAR.slice(filled);
	}

	// Typing animation
	$effect(() => {
		if (complete) return;

		const line = lines[currentLine];
		const isProgressBar = currentLine === 0;
		// Progress bar types slower (fills visually), other lines type fast
		const delay = isProgressBar ? 20 : 15;

		if (charIndex < line.length) {
			const timeout = setTimeout(() => {
				charIndex++;
			}, delay);
			return () => clearTimeout(timeout);
		}

		// Line complete — pause briefly, then advance
		const pause = currentLine === 0 ? 300 : line === '' ? 100 : 200;
		const timeout = setTimeout(() => {
			if (currentLine < lines.length - 1) {
				currentLine++;
				charIndex = 0;
			} else {
				complete = true;
			}
		}, pause);
		return () => clearTimeout(timeout);
	});

	// Auto-dismiss after completion + pause
	$effect(() => {
		if (!complete) return;
		const timeout = setTimeout(() => {
			ondismiss?.();
		}, 3000);
		return () => clearTimeout(timeout);
	});

	function handleClick() {
		ondismiss?.();
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Escape' || event.key === 'Enter' || event.key === ' ') {
			ondismiss?.();
		}
	}
</script>

<!-- svelte-ignore a11y_no_static_element_interactions a11y_no_noninteractive_element_interactions -->
<div
	class="overlay"
	onclick={handleClick}
	onkeydown={handleKeydown}
	role="status"
	aria-live="polite"
	tabindex="-1"
>
	<div class="terminal">
		{#each lines as line, i}
			{#if i < currentLine}
				<!-- Fully typed previous lines -->
				<div class="line">
					<span class="prompt">&gt;</span>
					<span class="text">{i === 0 ? FILLED_CHAR.repeat(PROGRESS_BAR.length) : line}</span>
				</div>
			{:else if i === currentLine}
				<!-- Currently typing line -->
				<div class="line">
					<span class="prompt">&gt;</span>
					<span class="text">
						{#if i === 0}
							{renderProgressBar(charIndex)}
						{:else}
							{line.slice(0, charIndex)}
						{/if}
					</span>
					{#if !complete}
						<span class="cursor">█</span>
					{/if}
				</div>
			{/if}
		{/each}

		{#if complete}
			<div class="dismiss-hint">[ click or press any key to continue ]</div>
		{/if}
	</div>
</div>

<style>
	.overlay {
		position: absolute;
		inset: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		background: var(--color-bg-primary, rgba(0, 0, 0, 0.95));
		z-index: 10;
		cursor: pointer;
		outline: none;
	}

	.terminal {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		padding: var(--space-4);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		line-height: var(--leading-relaxed);
		width: 100%;
		max-width: 100%;
	}

	.line {
		display: flex;
		gap: var(--space-2);
		white-space: pre;
	}

	.prompt {
		color: var(--color-text-tertiary);
		flex-shrink: 0;
	}

	.text {
		color: var(--color-accent);
	}

	.cursor {
		color: var(--color-accent);
		animation: blink 0.6s step-end infinite;
	}

	@keyframes blink {
		50% {
			opacity: 0;
		}
	}

	.dismiss-hint {
		margin-top: var(--space-3);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
		text-align: center;
		animation: fade-in 0.5s ease-in;
	}

	@keyframes fade-in {
		from {
			opacity: 0;
		}
		to {
			opacity: 1;
		}
	}
</style>
