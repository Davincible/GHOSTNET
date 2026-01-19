<script lang="ts">
	import { Box } from '$lib/ui/terminal';

	interface Props {
		/** Seconds remaining in countdown */
		secondsLeft: number;
	}

	let { secondsLeft }: Props = $props();

	// Animate the number
	let isAnimating = $state(true);

	$effect(() => {
		// Reset animation on each tick
		isAnimating = false;
		// Force re-render to trigger animation
		requestAnimationFrame(() => {
			isAnimating = true;
		});
	});
</script>

<div class="countdown-view">
	<Box>
		<div class="countdown-content">
			<h2 class="title">PREPARE FOR EVASION SEQUENCE</h2>

			<div class="countdown-display" aria-live="polite" aria-atomic="true">
				<span class="countdown-number" class:animate={isAnimating}>
					{secondsLeft}
				</span>
			</div>

			<p class="subtitle">Starting in...</p>

			<div class="hint-text">
				<p>Type the command as fast and accurately as possible</p>
				<p>Backspace is allowed to fix mistakes</p>
			</div>
		</div>
	</Box>
</div>

<style>
	.countdown-view {
		max-width: 500px;
		margin: 0 auto;
	}

	.countdown-content {
		text-align: center;
		padding: var(--space-8) var(--space-4);
	}

	.title {
		color: var(--color-amber);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
		margin-bottom: var(--space-8);
		animation: pulse 1s ease-in-out infinite;
	}

	.countdown-display {
		margin: var(--space-8) 0;
	}

	.countdown-number {
		font-size: var(--text-4xl);
		font-weight: var(--font-bold);
		color: var(--color-green-bright);
		text-shadow: var(--shadow-glow-green);
		display: inline-block;
	}

	.countdown-number.animate {
		animation: countdown-pop 0.3s ease-out;
	}

	.subtitle {
		color: var(--color-green-mid);
		font-size: var(--text-base);
		margin-bottom: var(--space-6);
	}

	.hint-text {
		color: var(--color-green-dim);
		font-size: var(--text-sm);
	}

	.hint-text p {
		margin: var(--space-1) 0;
	}

	@keyframes countdown-pop {
		0% {
			transform: scale(1.5);
			opacity: 0.5;
		}
		100% {
			transform: scale(1);
			opacity: 1;
		}
	}

	@keyframes pulse {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.7;
		}
	}
</style>
