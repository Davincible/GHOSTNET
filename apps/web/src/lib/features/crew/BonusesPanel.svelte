<script lang="ts">
	import type { CrewBonus } from '$lib/core/types';
	import { Panel } from '$lib/ui/terminal';
	import { ProgressBar } from '$lib/ui/primitives';
	import { Row } from '$lib/ui/layout';

	interface Props {
		/** Crew bonuses to display */
		bonuses: CrewBonus[];
	}

	let { bonuses }: Props = $props();

	// Separate active and inactive bonuses
	let activeBonuses = $derived(bonuses.filter((b) => b.active));
	let inactiveBonuses = $derived(bonuses.filter((b) => !b.active));

	// Format effect value for display
	function formatEffect(bonus: CrewBonus): string {
		if (bonus.effectType === 'death_rate') {
			// Negative value means reduction (good)
			const percent = Math.abs(bonus.effectValue * 100).toFixed(0);
			return bonus.effectValue < 0 ? `-${percent}%` : `+${percent}%`;
		} else {
			// Yield multiplier - positive means bonus
			const percent = (bonus.effectValue * 100).toFixed(0);
			return `+${percent}%`;
		}
	}

	// Format progress display
	function formatProgress(bonus: CrewBonus): string {
		const current = Math.floor(bonus.currentValue);
		const required = Math.floor(bonus.requiredValue);
		return `${current}/${required}`;
	}
</script>

<Panel title="ACTIVE BONUSES" maxHeight="300px" scrollable>
	<div class="bonuses-list">
		{#if activeBonuses.length > 0}
			{#each activeBonuses as bonus (bonus.id)}
				<div class="bonus-item bonus-active">
					<Row justify="between" align="center">
						<div class="bonus-info">
							<span class="bonus-check" aria-label="Active">+</span>
							<span class="bonus-name">{bonus.name}</span>
						</div>
						<span class="bonus-effect effect-active">{formatEffect(bonus)}</span>
					</Row>
					<div class="bonus-condition">[{bonus.condition}]</div>
				</div>
			{/each}
		{/if}

		{#if inactiveBonuses.length > 0}
			{#each inactiveBonuses as bonus (bonus.id)}
				<div class="bonus-item bonus-inactive">
					<Row justify="between" align="center">
						<div class="bonus-info">
							<span class="bonus-circle" aria-label="Inactive">o</span>
							<span class="bonus-name">{bonus.name}</span>
						</div>
						<span class="bonus-effect effect-inactive">{formatEffect(bonus)}</span>
					</Row>
					<div class="bonus-progress-row">
						<ProgressBar
							value={bonus.progress * 100}
							variant={bonus.effectType === 'death_rate' ? 'cyan' : 'success'}
							width={10}
						/>
						<span class="bonus-progress-text">{formatProgress(bonus)}</span>
					</div>
				</div>
			{/each}
		{/if}

		{#if bonuses.length === 0}
			<p class="no-bonuses">No bonuses available</p>
		{/if}
	</div>
</Panel>

<style>
	.bonuses-list {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.bonus-item {
		padding: var(--space-2);
		border-bottom: 1px solid var(--color-border-subtle);
	}

	.bonus-item:last-child {
		border-bottom: none;
	}

	.bonus-active {
		background: rgba(var(--color-profit-rgb, 0, 229, 163), 0.05);
	}

	.bonus-info {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.bonus-check {
		color: var(--color-profit);
		font-weight: var(--font-bold);
		font-size: var(--text-sm);
	}

	.bonus-circle {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
	}

	.bonus-name {
		color: var(--color-text-primary);
		font-size: var(--text-sm);
		font-family: var(--font-mono);
	}

	.bonus-effect {
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		font-family: var(--font-mono);
	}

	.effect-active {
		color: var(--color-profit);
	}

	.effect-inactive {
		color: var(--color-text-tertiary);
	}

	.bonus-condition {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		margin-top: var(--space-1);
		padding-left: calc(var(--space-2) + 1ch);
	}

	.bonus-progress-row {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		margin-top: var(--space-1);
		padding-left: calc(var(--space-2) + 1ch);
	}

	.bonus-progress-text {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		font-family: var(--font-mono);
		min-width: 4ch;
	}

	.no-bonuses {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
		text-align: center;
		padding: var(--space-4);
	}
</style>
