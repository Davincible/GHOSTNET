<script lang="ts">
	import type { HackRun } from '$lib/core/types/hackrun';
	import { Box } from '$lib/ui/terminal';
	import { Stack } from '$lib/ui/layout';

	interface Props {
		/** Run about to start */
		run: HackRun;
		/** Seconds remaining in countdown */
		secondsLeft: number;
	}

	let { run, secondsLeft }: Props = $props();
</script>

<div class="countdown-view">
	<Box variant="double" borderColor="cyan" padding={4}>
		<Stack gap={4}>
			<div class="countdown-header">
				<span class="label">INITIATING</span>
				<span class="difficulty">{run.difficulty.toUpperCase()} RUN</span>
			</div>

			<div class="countdown-number">
				{secondsLeft}
			</div>

			<div class="countdown-message">
				{#if secondsLeft === 3}
					ESTABLISHING CONNECTION...
				{:else if secondsLeft === 2}
					BYPASSING SECURITY...
				{:else}
					ENTERING NETWORK...
				{/if}
			</div>

			<div class="tips">
				<span class="tip-label">TIP:</span>
				<span class="tip-text">Type commands accurately. Speed without accuracy will fail.</span>
			</div>
		</Stack>
	</Box>
</div>

<style>
	.countdown-view {
		width: 100%;
		max-width: 500px;
		margin: 0 auto;
	}

	.countdown-header {
		text-align: center;
	}

	.label {
		display: block;
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
		letter-spacing: var(--tracking-widest);
	}

	.difficulty {
		display: block;
		color: var(--color-cyan);
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
		margin-top: var(--space-1);
	}

	.countdown-number {
		text-align: center;
		font-size: 8rem;
		font-weight: var(--font-bold);
		color: var(--color-cyan);
		line-height: 1;
		text-shadow: 0 0 20px rgba(0, 229, 204, 0.5);
		animation: pulse-glow 1s ease-in-out infinite;
	}

	@keyframes pulse-glow {
		0%,
		100% {
			text-shadow: 0 0 20px rgba(0, 229, 204, 0.5);
		}
		50% {
			text-shadow:
				0 0 40px rgba(0, 229, 204, 0.8),
				0 0 60px rgba(0, 229, 204, 0.3);
		}
	}

	.countdown-message {
		text-align: center;
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		letter-spacing: var(--tracking-wider);
		animation: blink 0.5s step-end infinite;
	}

	@keyframes blink {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.5;
		}
	}

	.tips {
		text-align: center;
		padding-top: var(--space-4);
		border-top: 1px solid var(--color-border-subtle);
	}

	.tip-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.tip-text {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		display: block;
		margin-top: var(--space-1);
	}
</style>
