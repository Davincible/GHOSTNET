<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { Button, Badge } from '$lib/ui/primitives';
	import { AmountDisplay } from '$lib/ui/data-display';
	import { Stack, Row } from '$lib/ui/layout';
	import type { HackRun, HackRunDifficulty } from '$lib/core/types/hackrun';

	interface Props {
		/** The run configuration */
		run: HackRun;
		/** Callback when start is clicked */
		onStart: (run: HackRun) => void;
		/** Whether selection is disabled */
		disabled?: boolean;
	}

	let { run, onStart, disabled = false }: Props = $props();

	// Difficulty display config
	const DIFFICULTY_CONFIG: Record<
		HackRunDifficulty,
		{ label: string; color: 'success' | 'warning' | 'danger' }
	> = {
		easy: { label: 'EASY', color: 'success' },
		medium: { label: 'MEDIUM', color: 'warning' },
		hard: { label: 'HARD', color: 'danger' },
	};

	let config = $derived(DIFFICULTY_CONFIG[run.difficulty]);
	let timeLimitMinutes = $derived(Math.floor(run.timeLimit / 60000));

	// ASCII node preview
	let nodePreview = $derived(
		run.nodes
			.filter((n) => n.type !== 'backdoor')
			.sort((a, b) => a.position - b.position)
			.map(() => '[ ]')
			.join('──')
	);
</script>

<div class="run-card" class:run-card-disabled={disabled}>
	<Box
		borderColor={config.color === 'success' ? 'cyan' : config.color === 'warning' ? 'amber' : 'red'}
	>
		<Stack gap={3}>
			<!-- Header -->
			<Row justify="between" align="center">
				<Badge variant={config.color} glow>{config.label}</Badge>
				<span class="multiplier">{run.baseMultiplier}x YIELD</span>
			</Row>

			<!-- Stats -->
			<div class="stats-grid">
				<div class="stat">
					<span class="stat-label">ENTRY FEE</span>
					<span class="stat-value">
						<AmountDisplay amount={run.entryFee} />
					</span>
				</div>
				<div class="stat">
					<span class="stat-label">TIME LIMIT</span>
					<span class="stat-value">{timeLimitMinutes} MIN</span>
				</div>
				<div class="stat">
					<span class="stat-label">SHORTCUTS</span>
					<span class="stat-value">{run.shortcuts > 0 ? run.shortcuts : 'NONE'}</span>
				</div>
				<div class="stat">
					<span class="stat-label">NODES</span>
					<span class="stat-value">{run.nodes.filter((n) => n.type !== 'backdoor').length}</span>
				</div>
			</div>

			<!-- Node Preview -->
			<div class="node-preview">
				<span class="preview-label">PATH:</span>
				<span class="preview-nodes">{nodePreview}</span>
			</div>

			<!-- Start Button -->
			<Button variant="secondary" fullWidth onclick={() => onStart(run)} {disabled}>
				INITIATE RUN
			</Button>
		</Stack>
	</Box>
</div>

<style>
	.run-card {
		width: 100%;
		max-width: 280px;
	}

	.run-card-disabled {
		opacity: 0.5;
		pointer-events: none;
	}

	.multiplier {
		color: var(--color-accent);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wide);
	}

	.stats-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: var(--space-2);
	}

	.stat {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.stat-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wide);
	}

	.stat-value {
		color: var(--color-text-primary);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
	}

	.node-preview {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--color-bg-primary);
		border: 1px solid var(--color-border-subtle);
		overflow-x: auto;
	}

	.preview-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		flex-shrink: 0;
	}

	.preview-nodes {
		color: var(--color-text-secondary);
		font-size: var(--text-xs);
		white-space: nowrap;
		letter-spacing: -0.05em;
	}
</style>
