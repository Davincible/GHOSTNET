<script lang="ts">
	import { onMount } from 'svelte';

	interface Props {
		text: string;
		delay?: number; // Delay before starting (ms)
		charDelay?: number; // Ms per character
		lineDelay?: number; // Additional delay between lines
		glitchChance?: number; // 0-1, chance of glitch per char
		onComplete?: () => void;
	}

	let {
		text,
		delay = 0,
		charDelay = 8,
		lineDelay = 50,
		glitchChance = 0.03,
		onComplete,
	}: Props = $props();

	const glitchChars = '░▒▓█▀▄■□▪▫●○◐◑◒◓';

	let displayText = $state('');
	let isComplete = $state(false);
	let isGlitching = $state(false);

	// Split into lines for line-by-line processing (derived to react to text changes)
	const lines = $derived(text.split('\n'));

	function getRandomGlitchChar(): string {
		return glitchChars[Math.floor(Math.random() * glitchChars.length)];
	}

	async function typeText() {
		if (delay > 0) {
			await new Promise((r) => setTimeout(r, delay));
		}

		let result = '';

		for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
			const line = lines[lineIndex];

			for (let charIndex = 0; charIndex < line.length; charIndex++) {
				const char = line[charIndex];

				// Glitch effect - show random char briefly before real char
				if (char !== ' ' && Math.random() < glitchChance) {
					isGlitching = true;
					displayText = result + getRandomGlitchChar();
					await new Promise((r) => setTimeout(r, 20));
					isGlitching = false;
				}

				result += char;
				displayText = result;

				// Skip delay for spaces (faster typing through whitespace)
				if (char !== ' ') {
					await new Promise((r) => setTimeout(r, charDelay));
				}
			}

			// Add newline and pause between lines
			if (lineIndex < lines.length - 1) {
				result += '\n';
				displayText = result;
				await new Promise((r) => setTimeout(r, lineDelay));
			}
		}

		isComplete = true;
		onComplete?.();
	}

	onMount(() => {
		typeText();
	});
</script>

<pre
	class="ascii-typewriter"
	class:glitching={isGlitching}
	class:complete={isComplete}>{displayText}<span class="cursor" class:hidden={isComplete}>▌</span
	></pre>

<style>
	.ascii-typewriter {
		font-family: var(--font-mono);
		font-size: 0.38rem;
		line-height: 1.1;
		color: var(--color-accent);
		text-shadow:
			0 0 10px var(--color-accent-glow),
			0 0 30px var(--color-accent-glow);
		margin: 0;
		white-space: pre;
		position: relative;
	}

	.glitching {
		animation: glitch-shake 0.05s ease-in-out;
	}

	@keyframes glitch-shake {
		0%,
		100% {
			transform: translateX(0);
		}
		50% {
			transform: translateX(1px);
		}
	}

	.cursor {
		color: var(--color-accent);
		animation: cursor-blink 0.5s step-end infinite;
		text-shadow: 0 0 10px var(--color-accent-glow);
	}

	.cursor.hidden {
		opacity: 0;
		animation: none;
	}

	@keyframes cursor-blink {
		0%,
		50% {
			opacity: 1;
		}
		51%,
		100% {
			opacity: 0;
		}
	}

	.complete {
		animation: logo-pulse 3s ease-in-out infinite;
	}

	@keyframes logo-pulse {
		0%,
		100% {
			text-shadow:
				0 0 10px var(--color-accent-glow),
				0 0 30px var(--color-accent-glow);
		}
		50% {
			text-shadow:
				0 0 20px var(--color-accent-glow),
				0 0 50px var(--color-accent-glow),
				0 0 80px var(--color-accent-glow);
		}
	}

	@media (max-width: 640px) {
		.ascii-typewriter {
			font-size: 0.28rem;
		}
	}
</style>
