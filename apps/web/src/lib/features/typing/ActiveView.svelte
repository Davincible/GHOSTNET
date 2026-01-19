<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { ProgressBar } from '$lib/ui/primitives';
	import { Row } from '$lib/ui/layout';
	import type { TypingChallenge } from '$lib/core/types';
	import type { TypingProgress } from './store.svelte';
	import { calculateWpm, calculateAccuracy, calculateReward } from './store.svelte';

	interface Props {
		/** The current typing challenge */
		challenge: TypingChallenge;
		/** Current typing progress */
		progress: TypingProgress;
	}

	let { challenge, progress }: Props = $props();

	// Calculate stats
	let timeElapsed = $derived(progress.currentTime - progress.startTime);
	let timeRemaining = $derived(Math.max(0, challenge.timeLimit * 1000 - timeElapsed));
	let timeRemainingSeconds = $derived(Math.ceil(timeRemaining / 1000));

	let progressPercent = $derived(
		challenge.command.length > 0
			? (progress.typed.length / challenge.command.length) * 100
			: 0
	);

	let accuracy = $derived(
		calculateAccuracy(progress.correctChars, progress.typed.length)
	);

	let wpm = $derived(
		calculateWpm(progress.correctChars, timeElapsed)
	);

	// Project reward based on current performance
	let projectedReward = $derived(calculateReward(accuracy, wpm));

	// Is time running low?
	let isUrgent = $derived(timeRemainingSeconds <= 10);

	// Split command into typed and remaining parts for display
	let commandChars = $derived(challenge.command.split(''));

	// Determine character status
	function getCharStatus(index: number): 'pending' | 'correct' | 'incorrect' | 'cursor' {
		if (index >= progress.typed.length) {
			return index === progress.typed.length ? 'cursor' : 'pending';
		}
		return progress.typed[index] === challenge.command[index] ? 'correct' : 'incorrect';
	}
</script>

<div class="active-view">
	<Box title="SCRAMBLE SEQUENCE ACTIVE">
		<div class="typing-container">
			<!-- Command prompt -->
			<div class="prompt-section">
				<div class="prompt-label">TYPE THE FOLLOWING COMMAND:</div>

				<div class="command-display" role="textbox" aria-label="Typing target">
					<span class="prompt-symbol">$</span>
					<span class="command-text">
						{#each commandChars as char, i (i)}
							{@const status = getCharStatus(i)}
							<span
								class="char char-{status}"
								class:char-space={char === ' '}
								aria-hidden="true"
							>{char === ' ' ? '\u00A0' : char}</span>
						{/each}
					</span>
				</div>
			</div>

			<!-- Progress bar -->
			<div class="progress-section">
				<ProgressBar
					value={progressPercent}
					variant={accuracy < 0.5 ? 'danger' : accuracy < 0.7 ? 'warning' : 'default'}
					animated
				/>
			</div>

			<!-- Stats row -->
			<div class="stats-section">
				<Row justify="between">
					<div class="stat">
						<span class="stat-label">WPM</span>
						<span class="stat-value">{wpm || '---'}</span>
					</div>

					<div class="stat">
						<span class="stat-label">ACCURACY</span>
						<span class="stat-value" class:stat-warning={accuracy < 0.7} class:stat-danger={accuracy < 0.5}>
							{progress.typed.length > 0 ? `${Math.round(accuracy * 100)}%` : '---%'}
						</span>
					</div>

					<div class="stat">
						<span class="stat-label">TIME</span>
						<span class="stat-value" class:stat-urgent={isUrgent}>
							{timeRemainingSeconds}s
						</span>
					</div>
				</Row>
			</div>

			<!-- Projected reward -->
			{#if progress.typed.length > 5}
				<div class="reward-preview">
					<span class="reward-label">PROJECTED:</span>
					{#if projectedReward}
						<span class="reward-value">{projectedReward.label}</span>
					{:else}
						<span class="reward-none">No bonus (need 50%+ accuracy)</span>
					{/if}
				</div>
			{/if}

			<!-- Hidden instructions -->
			<p class="instructions">
				Type the command above. Press <kbd>Backspace</kbd> to fix errors.
			</p>
		</div>
	</Box>
</div>

<style>
	.active-view {
		max-width: 600px;
		margin: 0 auto;
	}

	.typing-container {
		padding: var(--space-2) 0;
	}

	.prompt-section {
		margin-bottom: var(--space-4);
	}

	.prompt-label {
		color: var(--color-green-mid);
		font-size: var(--text-sm);
		letter-spacing: var(--tracking-wide);
		margin-bottom: var(--space-2);
	}

	.command-display {
		background: var(--color-bg-primary);
		border: 1px solid var(--color-green-dim);
		padding: var(--space-3);
		font-size: var(--text-lg);
		font-family: var(--font-mono);
		overflow-x: auto;
		white-space: nowrap;
	}

	.prompt-symbol {
		color: var(--color-green-mid);
		margin-right: var(--space-2);
	}

	.command-text {
		position: relative;
	}

	.char {
		display: inline;
		transition: color var(--duration-instant) var(--ease-default);
	}

	.char-pending {
		color: var(--color-green-dim);
	}

	.char-correct {
		color: var(--color-green-bright);
	}

	.char-incorrect {
		color: var(--color-red);
		background: var(--color-red-glow);
		text-decoration: underline;
	}

	.char-cursor {
		color: var(--color-green-bright);
		position: relative;
	}

	.char-cursor::before {
		content: '';
		position: absolute;
		left: 0;
		top: 0;
		bottom: 0;
		width: 2px;
		background: var(--color-green-bright);
		animation: cursor-blink 0.8s step-end infinite;
	}

	.char-space.char-cursor::before {
		background: var(--color-cyan);
	}

	.progress-section {
		margin: var(--space-4) 0;
	}

	.stats-section {
		padding: var(--space-3) 0;
		border-top: 1px solid var(--color-bg-tertiary);
		border-bottom: 1px solid var(--color-bg-tertiary);
	}

	.stat {
		text-align: center;
	}

	.stat-label {
		display: block;
		color: var(--color-green-dim);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wide);
		margin-bottom: var(--space-1);
	}

	.stat-value {
		color: var(--color-green-bright);
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		font-variant-numeric: tabular-nums;
	}

	.stat-warning {
		color: var(--color-amber);
	}

	.stat-danger {
		color: var(--color-red);
	}

	.stat-urgent {
		color: var(--color-red);
		animation: pulse-urgent 0.5s ease-in-out infinite;
	}

	.reward-preview {
		margin-top: var(--space-3);
		padding: var(--space-2);
		background: var(--color-bg-secondary);
		text-align: center;
		font-size: var(--text-sm);
	}

	.reward-label {
		color: var(--color-green-dim);
		margin-right: var(--space-2);
	}

	.reward-value {
		color: var(--color-profit);
		font-weight: var(--font-medium);
	}

	.reward-none {
		color: var(--color-amber);
	}

	.instructions {
		margin-top: var(--space-4);
		color: var(--color-green-dim);
		font-size: var(--text-xs);
		text-align: center;
	}

	.instructions kbd {
		background: var(--color-bg-tertiary);
		padding: 0 var(--space-1);
		border: 1px solid var(--color-green-dim);
	}

	@keyframes cursor-blink {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0;
		}
	}

	@keyframes pulse-urgent {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.5;
		}
	}
</style>
