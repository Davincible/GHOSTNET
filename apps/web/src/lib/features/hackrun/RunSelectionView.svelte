<script lang="ts">
	import type { HackRun } from '$lib/core/types/hackrun';
	import { Box } from '$lib/ui/terminal';
	import { Stack, Row } from '$lib/ui/layout';
	import RunCard from './RunCard.svelte';

	interface Props {
		/** Available runs to select from */
		availableRuns: HackRun[];
		/** Callback when a run is selected */
		onSelectRun?: (run: HackRun) => void;
		/** Callback to cancel selection */
		onCancel?: () => void;
	}

	let { availableRuns, onSelectRun, onCancel }: Props = $props();
</script>

<div class="selection-view">
	<Box variant="double" borderColor="cyan" padding={4}>
		<Stack gap={4}>
			<!-- Header -->
			<div class="header">
				<h2 class="title">SELECT HACK RUN</h2>
				<p class="subtitle">Choose difficulty level to begin infiltration</p>
			</div>

			<!-- Run cards grid -->
			<div class="runs-grid">
				{#each availableRuns as run (run.id)}
					<RunCard {run} onSelect={() => onSelectRun?.(run)} />
				{/each}
			</div>

			<!-- Cancel option -->
			<Row justify="center">
				<button class="cancel-btn" onclick={onCancel}>
					[ESC] ABORT MISSION
				</button>
			</Row>
		</Stack>
	</Box>
</div>

<style>
	.selection-view {
		width: 100%;
		max-width: 900px;
		margin: 0 auto;
	}

	.header {
		text-align: center;
	}

	.title {
		color: var(--color-cyan);
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
		margin: 0;
	}

	.subtitle {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		margin: var(--space-1) 0 0;
	}

	.runs-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
		gap: var(--space-4);
	}

	.cancel-btn {
		background: none;
		border: none;
		color: var(--color-text-tertiary);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		cursor: pointer;
		padding: var(--space-2);
		transition: color var(--duration-fast) var(--ease-default);
	}

	.cancel-btn:hover {
		color: var(--color-text-primary);
	}
</style>
