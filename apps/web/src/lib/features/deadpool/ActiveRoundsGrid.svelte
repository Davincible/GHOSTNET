<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { DeadPoolRound } from '$lib/core/types';
	import RoundCard from './RoundCard.svelte';

	interface Props {
		/** Active rounds to display */
		rounds: DeadPoolRound[];
		/** Callback when user wants to bet on a round */
		onBet?: (round: DeadPoolRound) => void;
		/** Empty state snippet */
		empty?: Snippet;
	}

	let { rounds, onBet, empty }: Props = $props();
</script>

<div class="rounds-grid">
	{#if rounds.length === 0}
		{#if empty}
			{@render empty()}
		{:else}
			<div class="empty-state">
				<span class="empty-icon">[?]</span>
				<p class="empty-text">NO ACTIVE ROUNDS</p>
				<p class="empty-subtext">Check back soon for new predictions</p>
			</div>
		{/if}
	{:else}
		{#each rounds as round (round.id)}
			<RoundCard {round} onBet={() => onBet?.(round)} />
		{/each}
	{/if}
</div>

<style>
	.rounds-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
		gap: var(--space-4);
	}

	.empty-state {
		grid-column: 1 / -1;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: var(--space-8);
		border: 1px dashed var(--color-border-subtle);
		text-align: center;
	}

	.empty-icon {
		font-size: var(--text-3xl);
		color: var(--color-text-muted);
		margin-bottom: var(--space-2);
	}

	.empty-text {
		color: var(--color-text-secondary);
		font-size: var(--text-base);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wider);
		margin: 0;
	}

	.empty-subtext {
		color: var(--color-text-muted);
		font-size: var(--text-sm);
		margin: var(--space-1) 0 0;
	}

	/* Responsive adjustments */
	@media (max-width: 480px) {
		.rounds-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
