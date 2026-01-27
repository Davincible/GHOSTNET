<script lang="ts">
	import type { HackRun, HackRunDifficulty } from '$lib/core/types/hackrun';
	import { Box } from '$lib/ui/terminal';
	import { AmountDisplay } from '$lib/ui/data-display';
	import { Button } from '$lib/ui/primitives';
	import { Stack } from '$lib/ui/layout';
	import { formatDuration } from '$lib/core/utils';

	interface Props {
		/** Run configuration */
		run: HackRun;
		/** Callback when run is selected */
		onSelect?: () => void;
	}

	let { run, onSelect }: Props = $props();

	// Difficulty display config
	const DIFFICULTY_CONFIG: Record<
		HackRunDifficulty,
		{ label: string; color: string; borderColor: 'default' | 'cyan' | 'amber' | 'red' }
	> = {
		easy: { label: 'ROUTINE', color: 'var(--color-profit)', borderColor: 'cyan' },
		medium: { label: 'COMPLEX', color: 'var(--color-amber)', borderColor: 'amber' },
		hard: { label: 'CRITICAL', color: 'var(--color-loss)', borderColor: 'red' },
	};

	const config = $derived(DIFFICULTY_CONFIG[run.difficulty]);
	const mainNodeCount = $derived(run.nodes.filter((n) => n.type !== 'backdoor').length);
</script>

<Box variant="single" borderColor={config.borderColor} padding={3}>
	<Stack gap={3}>
		<!-- Difficulty header -->
		<div class="difficulty-header" style:--diff-color={config.color}>
			<span class="difficulty-label">{config.label}</span>
			<span class="difficulty-tier">{run.difficulty.toUpperCase()}</span>
		</div>

		<!-- Stats -->
		<div class="stats" role="list" aria-label="Run statistics">
			<div class="stat-row" role="listitem">
				<span class="stat-label">ENTRY FEE:</span>
				<span class="stat-value">
					<AmountDisplay amount={run.entryFee} format="compact" />
				</span>
			</div>
			<div class="stat-row" role="listitem">
				<span class="stat-label">BASE MULT:</span>
				<span class="stat-value multiplier">{run.baseMultiplier.toFixed(1)}x</span>
			</div>
			<div class="stat-row" role="listitem">
				<span class="stat-label">TIME LIMIT:</span>
				<span class="stat-value">{formatDuration(run.timeLimit)}</span>
			</div>
			<div class="stat-row" role="listitem">
				<span class="stat-label">NODES:</span>
				<span class="stat-value">{mainNodeCount}</span>
			</div>
			<div class="stat-row" role="listitem">
				<span class="stat-label">SHORTCUTS:</span>
				<span class="stat-value shortcut">{run.shortcuts > 0 ? run.shortcuts : '—'}</span>
			</div>
		</div>

		<!-- Select button -->
		<Button variant="primary" fullWidth onclick={onSelect}>INITIATE</Button>
	</Stack>
</Box>

<style>
	.difficulty-header {
		text-align: center;
		padding-bottom: var(--space-2);
		border-bottom: 1px solid var(--color-border-subtle);
	}

	.difficulty-label {
		display: block;
		color: var(--diff-color);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	.difficulty-tier {
		display: block;
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-widest);
		margin-top: var(--space-1);
	}

	.stats {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.stat-row {
		display: flex;
		justify-content: space-between;
		font-size: var(--text-sm);
	}

	.stat-label {
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.stat-value {
		color: var(--color-text-primary);
		font-weight: var(--font-medium);
	}

	.stat-value.multiplier {
		color: var(--color-cyan);
	}

	.stat-value.shortcut {
		color: var(--color-amber);
	}

	/* Mobile responsiveness */
	@media (max-width: 480px) {
		.difficulty-label {
			font-size: var(--text-base);
		}

		.difficulty-tier {
			font-size: 10px;
		}

		.stat-row {
			font-size: var(--text-xs);
		}
	}
</style>
