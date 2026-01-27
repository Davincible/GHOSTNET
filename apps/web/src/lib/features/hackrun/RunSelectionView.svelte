<script lang="ts">
	import type { HackRun } from '$lib/core/types/hackrun';
	import { Box } from '$lib/ui/terminal';
	import { Stack } from '$lib/ui/layout';
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

	// Keyboard handler for escape
	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Escape' && onCancel) {
			event.preventDefault();
			onCancel();
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} />

<div class="selection-view" role="region" aria-label="Hack Run Selection">
	<Box variant="double" borderColor="cyan" padding={4}>
		<Stack gap={4}>
			<!-- Header -->
			<div class="header">
				<h2 class="title">SELECT HACK RUN</h2>
				<p class="subtitle">Choose difficulty level to begin infiltration</p>
			</div>

			<!-- Run cards grid -->
			<div class="runs-grid" role="list" aria-label="Available difficulty levels">
				{#each availableRuns as run (run.id)}
					<div role="listitem">
						<RunCard {run} onSelect={() => onSelectRun?.(run)} />
					</div>
				{/each}
			</div>

			<!-- Cancel option -->
			{#if onCancel}
				<div class="cancel-row">
					<button class="cancel-btn" onclick={onCancel} aria-label="Cancel and return">
						[ESC] ABORT MISSION
					</button>
				</div>
			{/if}
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

	.cancel-row {
		text-align: center;
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

	.cancel-btn:focus-visible {
		outline: 2px solid var(--color-accent);
		outline-offset: 2px;
	}

	/* Mobile responsiveness */
	@media (max-width: 768px) {
		.selection-view {
			max-width: 100%;
		}

		.runs-grid {
			grid-template-columns: 1fr;
		}

		.title {
			font-size: var(--text-lg);
		}
	}

	@media (max-width: 480px) {
		.title {
			font-size: var(--text-base);
		}

		.subtitle {
			font-size: var(--text-xs);
		}

		.cancel-btn {
			font-size: var(--text-xs);
		}
	}
</style>
