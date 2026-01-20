<script lang="ts">
	import RoundCard from './RoundCard.svelte';
	import type { DeadPoolRound, DeadPoolSide } from '$lib/core/types';

	interface Props {
		/** Active betting rounds */
		rounds: DeadPoolRound[];
		/** Handler for placing a bet */
		onBet: (round: DeadPoolRound, side: DeadPoolSide) => void;
	}

	let { rounds, onBet }: Props = $props();
</script>

<div class="rounds-grid">
	{#if rounds.length === 0}
		<div class="empty-state">
			<p class="empty-title">NO ACTIVE ROUNDS</p>
			<p class="empty-description">New prediction markets will appear here</p>
		</div>
	{:else}
		{#each rounds as round (round.id)}
			<RoundCard {round} {onBet} />
		{/each}
	{/if}
</div>

<style>
	.rounds-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
		gap: var(--space-4);
	}

	.empty-state {
		grid-column: 1 / -1;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: var(--space-8);
		background: var(--color-bg-secondary);
		border: 1px dashed var(--color-border-subtle);
		text-align: center;
	}

	.empty-title {
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
		margin-bottom: var(--space-2);
	}

	.empty-description {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
	}

	@media (max-width: 640px) {
		.rounds-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
