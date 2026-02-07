<script lang="ts">
	/**
	 * RiskLevelCards - Experimental component
	 *
	 * Goal: Present risk levels in a more visual, less overwhelming way.
	 * Each level is a clickable card with clear risk/reward information.
	 *
	 * Key design decisions:
	 * - Visual color coding for risk
	 * - Clear APY vs Death rate comparison
	 * - Selectable cards for direct "Jack In" flow
	 */

	type RiskLevel = 'vault' | 'mainframe' | 'subnet' | 'darknet' | 'blackice';

	interface Props {
		/** Currently selected level */
		selected?: RiskLevel;
		/** Callback when a level is selected */
		onSelect?: (level: RiskLevel) => void;
		/** Show compact version */
		compact?: boolean;
	}

	let { selected = $bindable(), onSelect, compact = false }: Props = $props();

	interface LevelData {
		id: RiskLevel;
		name: string;
		deathRate: string;
		apy: string;
		scanFreq: string;
		description: string;
		colorVar: string;
	}

	const levels: LevelData[] = [
		{
			id: 'vault',
			name: 'THE VAULT',
			deathRate: '0%',
			apy: '100-500%',
			scanFreq: 'Never',
			description: 'Safe haven. Earn from everyone below.',
			colorVar: '--color-profit',
		},
		{
			id: 'mainframe',
			name: 'MAINFRAME',
			deathRate: '2%',
			apy: '1,000%',
			scanFreq: '24h',
			description: 'Conservative. Low risk, steady gains.',
			colorVar: '--color-cyan',
		},
		{
			id: 'subnet',
			name: 'SUBNET',
			deathRate: '15%',
			apy: '5,000%',
			scanFreq: '8h',
			description: 'Balanced. Risk vs reward sweet spot.',
			colorVar: '--color-amber',
		},
		{
			id: 'darknet',
			name: 'DARKNET',
			deathRate: '40%',
			apy: '20,000%',
			scanFreq: '2h',
			description: 'High stakes. For the bold.',
			colorVar: '--color-level-darknet',
		},
		{
			id: 'blackice',
			name: 'BLACK ICE',
			deathRate: '90%',
			apy: '∞',
			scanFreq: '30m',
			description: 'Casino mode. Double or nothing.',
			colorVar: '--color-red',
		},
	];

	function handleSelect(level: RiskLevel) {
		selected = level;
		onSelect?.(level);
	}
</script>

<div class="levels-container" class:compact>
	{#each levels as level (level.id)}
		<button
			type="button"
			class="level-card"
			class:selected={selected === level.id}
			onclick={() => handleSelect(level.id)}
			style="--level-color: var({level.colorVar})"
		>
			<div class="level-indicator"></div>

			<div class="level-header">
				<span class="level-name">{level.name}</span>
				{#if !compact}
					<span class="level-scan">Scan: {level.scanFreq}</span>
				{/if}
			</div>

			<div class="level-stats">
				<div class="stat stat-death">
					<span class="stat-value">{level.deathRate}</span>
					<span class="stat-label">DEATH</span>
				</div>
				<div class="stat stat-apy">
					<span class="stat-value">{level.apy}</span>
					<span class="stat-label">APY</span>
				</div>
			</div>

			{#if !compact}
				<p class="level-description">{level.description}</p>
			{/if}
		</button>
	{/each}
</div>

<style>
	.levels-container {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		width: 100%;
	}

	.levels-container.compact {
		gap: var(--space-1);
	}

	/* ═══════════════════════════════════════════════════════════════
	   LEVEL CARD
	   ═══════════════════════════════════════════════════════════════ */

	.level-card {
		display: grid;
		grid-template-columns: 4px 1fr auto;
		grid-template-rows: auto auto;
		gap: var(--space-2) var(--space-3);
		padding: var(--space-3);
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-default);
		cursor: pointer;
		transition: all 0.15s ease;
		text-align: left;
		font-family: var(--font-mono);
	}

	.compact .level-card {
		padding: var(--space-2);
		gap: var(--space-1) var(--space-2);
	}

	.level-card:hover {
		background: var(--color-bg-tertiary);
		border-color: var(--level-color);
	}

	.level-card.selected {
		border-color: var(--level-color);
		box-shadow: 0 0 15px color-mix(in srgb, var(--level-color) 30%, transparent);
	}

	/* ═══════════════════════════════════════════════════════════════
	   LEVEL INDICATOR (color bar)
	   ═══════════════════════════════════════════════════════════════ */

	.level-indicator {
		grid-row: 1 / -1;
		width: 4px;
		background: var(--level-color);
		opacity: 0.6;
		transition: opacity 0.15s;
	}

	.level-card:hover .level-indicator,
	.level-card.selected .level-indicator {
		opacity: 1;
		box-shadow: 0 0 8px var(--level-color);
	}

	/* ═══════════════════════════════════════════════════════════════
	   LEVEL HEADER
	   ═══════════════════════════════════════════════════════════════ */

	.level-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.level-name {
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wider);
	}

	.compact .level-name {
		font-size: var(--text-xs);
	}

	.level-scan {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
	}

	/* ═══════════════════════════════════════════════════════════════
	   LEVEL STATS
	   ═══════════════════════════════════════════════════════════════ */

	.level-stats {
		display: flex;
		gap: var(--space-4);
	}

	.compact .level-stats {
		gap: var(--space-3);
	}

	.stat {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.stat-value {
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		line-height: 1;
	}

	.compact .stat-value {
		font-size: var(--text-base);
	}

	.stat-death .stat-value {
		color: var(--level-color);
	}

	.stat-apy .stat-value {
		color: var(--color-profit);
	}

	.stat-label {
		font-size: 0.5rem;
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wider);
	}

	/* ═══════════════════════════════════════════════════════════════
	   LEVEL DESCRIPTION
	   ═══════════════════════════════════════════════════════════════ */

	.level-description {
		grid-column: 2 / -1;
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		margin: 0;
	}
</style>
