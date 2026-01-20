<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { Stack, Row } from '$lib/ui/layout';
	import RunCard from './RunCard.svelte';
	import type { HackRun } from '$lib/core/types/hackrun';

	interface Props {
		/** Available runs to choose from */
		availableRuns: HackRun[];
		/** Callback when a run is selected */
		onSelectRun: (run: HackRun) => void;
		/** Whether selection is disabled (e.g., insufficient balance) */
		disabled?: boolean;
	}

	let { availableRuns, onSelectRun, disabled = false }: Props = $props();

	// Sort runs by difficulty
	let sortedRuns = $derived(
		[...availableRuns].sort((a, b) => {
			const order = { easy: 0, medium: 1, hard: 2 };
			return order[a.difficulty] - order[b.difficulty];
		})
	);
</script>

<div class="selection-view">
	<Stack gap={4}>
		<!-- Header -->
		<div class="header">
			<h2 class="title">SELECT INFILTRATION LEVEL</h2>
			<p class="subtitle">Higher risk = higher reward. Choose wisely.</p>
		</div>

		<!-- Run Cards -->
		<div class="cards-container">
			{#each sortedRuns as run (run.id)}
				<RunCard {run} onStart={onSelectRun} {disabled} />
			{/each}
		</div>

		<!-- Info Footer -->
		<div class="info-footer">
			<Box borderColor="dim" padding={2}>
				<Stack gap={2}>
					<Row gap={4} justify="center" wrap>
						<div class="info-item">
							<span class="info-icon">[?]</span>
							<span class="info-text">Complete typing challenges at each node</span>
						</div>
						<div class="info-item">
							<span class="info-icon">[!]</span>
							<span class="info-text">Multiplier lasts 4 hours after completion</span>
						</div>
						<div class="info-item">
							<span class="info-icon">[$]</span>
							<span class="info-text">Entry fee refunded on success</span>
						</div>
					</Row>
				</Stack>
			</Box>
		</div>
	</Stack>
</div>

<style>
	.selection-view {
		max-width: 900px;
		margin: 0 auto;
		padding: var(--space-4);
	}

	.header {
		text-align: center;
		margin-bottom: var(--space-2);
	}

	.title {
		color: var(--color-accent);
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
		margin-bottom: var(--space-2);
	}

	.subtitle {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
	}

	.cards-container {
		display: flex;
		justify-content: center;
		gap: var(--space-4);
		flex-wrap: wrap;
	}

	.info-footer {
		margin-top: var(--space-2);
	}

	.info-item {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		font-size: var(--text-xs);
	}

	.info-icon {
		color: var(--color-accent);
		font-weight: var(--font-bold);
	}

	.info-text {
		color: var(--color-text-secondary);
	}

	@media (max-width: 768px) {
		.cards-container {
			flex-direction: column;
			align-items: center;
		}
	}
</style>
