<script lang="ts">
	import { onMount } from 'svelte';

	interface Props {
		text: string;
		delay?: number; // Delay before starting (ms)
		speed?: number; // Ms per character
		glitchIntensity?: number; // 0-1, how often glitches occur
		class?: string;
		onComplete?: () => void;
	}

	let {
		text,
		delay = 0,
		speed = 50,
		glitchIntensity = 0.3,
		class: className = '',
		onComplete,
	}: Props = $props();

	const glitchChars = '!@#$%^&*()_+-=[]{}|;:,.<>?/\\~`0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

	let displayText = $state('');
	let isComplete = $state(false);
	let isGlitching = $state(false);
	let cursorVisible = $state(true);

	function getRandomGlitchChar(): string {
		return glitchChars[Math.floor(Math.random() * glitchChars.length)];
	}

	async function typeText() {
		// Wait for initial delay
		if (delay > 0) {
			await new Promise((r) => setTimeout(r, delay));
		}

		for (let i = 0; i <= text.length; i++) {
			// Occasionally glitch the current character
			if (i < text.length && Math.random() < glitchIntensity) {
				isGlitching = true;

				// Show glitch characters briefly
				const glitchCount = Math.floor(Math.random() * 3) + 1;
				for (let g = 0; g < glitchCount; g++) {
					displayText = text.slice(0, i) + getRandomGlitchChar();
					await new Promise((r) => setTimeout(r, 30));
				}

				isGlitching = false;
			}

			displayText = text.slice(0, i);
			await new Promise((r) => setTimeout(r, speed));
		}

		isComplete = true;
		onComplete?.();

		// Continue cursor blink for a moment then stop
		await new Promise((r) => setTimeout(r, 1500));
		cursorVisible = false;
	}

	// Cursor blink effect
	let cursorInterval: ReturnType<typeof setInterval>;

	onMount(() => {
		typeText();

		cursorInterval = setInterval(() => {
			if (!isComplete) {
				cursorVisible = !cursorVisible;
			}
		}, 530);

		return () => {
			clearInterval(cursorInterval);
		};
	});
</script>

<span class="glitch-text {className}" class:glitching={isGlitching}>
	{displayText}<span class="cursor" class:visible={cursorVisible} class:complete={isComplete}
		>_</span
	>
</span>

<style>
	.glitch-text {
		font-family: var(--font-mono);
		position: relative;
	}

	.glitching {
		animation: glitch-shake 0.1s ease-in-out;
	}

	@keyframes glitch-shake {
		0%,
		100% {
			transform: translateX(0);
		}
		25% {
			transform: translateX(-2px);
		}
		75% {
			transform: translateX(2px);
		}
	}

	.cursor {
		opacity: 0;
		color: var(--color-accent);
		animation: none;
	}

	.cursor.visible {
		opacity: 1;
	}

	.cursor.complete {
		animation: fade-out 0.5s ease-out forwards;
		animation-delay: 1s;
	}

	@keyframes fade-out {
		to {
			opacity: 0;
		}
	}
</style>
