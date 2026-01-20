<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { Badge, ProgressBar } from '$lib/ui/primitives';
	import { Stack, Row } from '$lib/ui/layout';
	import type { HackRunNode, NodeResult } from '$lib/core/types/hackrun';
	import { NODE_TYPE_CONFIG } from '$lib/core/types/hackrun';

	interface Props {
		/** The current node */
		node: HackRunNode;
		/** User's typed input */
		typed: string;
		/** Callback when typing is complete */
		onComplete: (result: NodeResult) => void;
		/** Track start time for WPM calculation */
		startTime: number;
	}

	let { node, typed, onComplete, startTime }: Props = $props();

	// Get node type config
	let nodeConfig = $derived(NODE_TYPE_CONFIG[node.type]);

	// Risk badge variant mapping
	const riskVariants: Record<string, 'success' | 'warning' | 'danger' | 'info'> = {
		low: 'success',
		medium: 'warning',
		high: 'danger',
		extreme: 'danger',
	};

	// Target command
	let command = $derived(node.challenge.command);

	// Progress calculations
	let progressPercent = $derived(command.length > 0 ? (typed.length / command.length) * 100 : 0);

	// Accuracy calculation
	let correctChars = $derived.by(() => {
		let correct = 0;
		for (let i = 0; i < typed.length; i++) {
			if (typed[i] === command[i]) correct++;
		}
		return correct;
	});

	let accuracy = $derived(typed.length > 0 ? Math.round((correctChars / typed.length) * 100) : 100);

	// Time elapsed (recalculated when typed changes for reactivity)
	let elapsedSeconds = $derived.by(() => {
		// Reference typed to trigger recalculation
		void typed;
		return (Date.now() - startTime) / 1000;
	});

	// WPM calculation
	let wpm = $derived.by(() => {
		if (elapsedSeconds < 1 || correctChars < 1) return 0;
		// Standard WPM: (characters / 5) / minutes
		const minutes = elapsedSeconds / 60;
		return Math.round(correctChars / 5 / minutes);
	});

	// Time display
	let timeDisplay = $derived(Math.round(elapsedSeconds));

	// Split command into characters for display
	let commandChars = $derived(command.split(''));

	// Get character status for styling
	function getCharStatus(index: number): 'pending' | 'correct' | 'incorrect' | 'cursor' {
		if (index >= typed.length) {
			return index === typed.length ? 'cursor' : 'pending';
		}
		return typed[index] === command[index] ? 'correct' : 'incorrect';
	}

	// Track if we've already completed
	let hasCompleted = $state(false);

	// Reset completion flag when node changes
	$effect(() => {
		void node.id;
		hasCompleted = false;
	});

	// Check if complete
	$effect(() => {
		if (typed.length >= command.length && !hasCompleted) {
			hasCompleted = true;

			// Calculate final result
			const finalAccuracy = correctChars / command.length;
			const success = finalAccuracy >= 0.5; // 50% minimum accuracy to pass

			const result: NodeResult = {
				success,
				accuracy: finalAccuracy,
				wpm,
				timeElapsed: elapsedSeconds * 1000,
				lootGained:
					success && node.reward.type === 'loot'
						? BigInt(Math.floor(node.reward.value)) * 10n ** 18n
						: 0n,
				multiplierGained: success && node.reward.type === 'multiplier' ? node.reward.value : 0,
			};

			onComplete(result);
		}
	});
</script>

<div class="node-panel">
	<Box title={`NODE ${node.position}: ${node.name}`} borderColor="cyan">
		<Stack gap={3}>
			<!-- Node Info Header -->
			<Row justify="between" align="center">
				<span class="node-type">{nodeConfig.icon} {node.type.toUpperCase().replace('_', ' ')}</span>
				<Badge variant={riskVariants[node.risk]}>RISK: {node.risk.toUpperCase()}</Badge>
			</Row>

			<!-- Reward Preview -->
			<div class="reward-preview">
				<span class="reward-label">Reward:</span>
				<span class="reward-value">{node.reward.label}</span>
			</div>

			<!-- Description -->
			<p class="node-description">"{node.description}"</p>

			<!-- Typing Area -->
			<div class="typing-area">
				<div class="command-display">
					<span class="prompt">&gt;</span>
					<span class="command-text">
						{#each commandChars as char, i (i)}
							{@const status = getCharStatus(i)}
							<span class="char char-{status}" class:char-space={char === ' '}
								>{char === ' ' ? '\u00A0' : char}</span
							>
						{/each}
					</span>
				</div>

				<div class="input-display">
					<span class="prompt">&nbsp;&nbsp;</span>
					<span class="typed-text">
						{typed}<span class="cursor">_</span>
					</span>
				</div>
			</div>

			<!-- Progress Bar -->
			<div class="progress-section">
				<ProgressBar
					value={progressPercent}
					variant={accuracy < 50 ? 'danger' : accuracy < 70 ? 'warning' : 'default'}
					showPercent
					width={30}
				/>
			</div>

			<!-- Stats -->
			<div class="stats-row">
				<div class="stat">
					<span class="stat-label">WPM</span>
					<span class="stat-value">{wpm || '---'}</span>
				</div>
				<div class="stat">
					<span class="stat-label">ACCURACY</span>
					<span
						class="stat-value"
						class:stat-warning={accuracy < 70}
						class:stat-danger={accuracy < 50}
					>
						{accuracy}%
					</span>
				</div>
				<div class="stat">
					<span class="stat-label">TIME</span>
					<span class="stat-value">{timeDisplay}s</span>
				</div>
			</div>
		</Stack>
	</Box>
</div>

<style>
	.node-panel {
		width: 100%;
	}

	.node-type {
		color: var(--color-accent);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wide);
	}

	.reward-preview {
		display: flex;
		align-items: baseline;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--color-bg-primary);
		border: 1px solid var(--color-border-subtle);
	}

	.reward-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
	}

	.reward-value {
		color: var(--color-profit);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
	}

	.node-description {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		font-style: italic;
		margin: 0;
	}

	/* Typing Area */
	.typing-area {
		background: var(--color-bg-primary);
		border: 1px solid var(--color-accent-dim);
		padding: var(--space-3);
	}

	.command-display,
	.input-display {
		font-family: var(--font-mono);
		font-size: var(--text-base);
		white-space: nowrap;
		overflow-x: auto;
	}

	.prompt {
		color: var(--color-accent);
		margin-right: var(--space-2);
	}

	.command-text {
		display: inline;
	}

	.char {
		display: inline;
		transition: color var(--duration-instant) var(--ease-default);
	}

	.char-pending {
		color: var(--color-text-tertiary);
	}

	.char-correct {
		color: var(--color-profit);
	}

	.char-incorrect {
		color: var(--color-red);
		background: var(--color-red-glow);
		text-decoration: underline;
	}

	.char-cursor {
		color: var(--color-text-primary);
		position: relative;
	}

	.char-cursor::before {
		content: '';
		position: absolute;
		left: 0;
		top: 0;
		bottom: 0;
		width: 2px;
		background: var(--color-accent);
		animation: cursor-blink 0.8s step-end infinite;
	}

	.input-display {
		margin-top: var(--space-2);
		padding-top: var(--space-2);
		border-top: 1px dashed var(--color-border-subtle);
	}

	.typed-text {
		color: var(--color-text-primary);
	}

	.cursor {
		color: var(--color-accent);
		animation: cursor-blink 0.8s step-end infinite;
	}

	/* Progress Section */
	.progress-section {
		padding: var(--space-2) 0;
		border-top: 1px solid var(--color-border-subtle);
		border-bottom: 1px solid var(--color-border-subtle);
	}

	/* Stats */
	.stats-row {
		display: flex;
		justify-content: space-around;
	}

	.stat {
		text-align: center;
	}

	.stat-label {
		display: block;
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wide);
		margin-bottom: var(--space-1);
	}

	.stat-value {
		color: var(--color-text-primary);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		font-variant-numeric: tabular-nums;
	}

	.stat-warning {
		color: var(--color-amber);
	}

	.stat-danger {
		color: var(--color-red);
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
</style>
