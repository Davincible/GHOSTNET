<script lang="ts">
	/**
	 * Compact risk levels reference table.
	 *
	 * Displays the five risk tiers with color-coded indicators,
	 * death rates, and scan frequencies. Designed for quick scanning
	 * — a first-time visitor should grok the risk spectrum in seconds.
	 */

	interface RiskLevel {
		name: string;
		death: string;
		freq: string;
		color: string;
	}

	const RISK_LEVELS: RiskLevel[] = [
		{ name: 'VAULT', death: '0% death', freq: 'Safe haven', color: 'var(--color-profit)' },
		{ name: 'MAINFRAME', death: '2% death', freq: 'Every 24h', color: 'var(--color-cyan)' },
		{ name: 'SUBNET', death: '15% death', freq: 'Every 8h', color: 'var(--color-amber)' },
		{ name: 'DARKNET', death: '40% death', freq: 'Every 2h', color: '#ff6600' },
		{ name: 'BLACK ICE', death: '90% death', freq: 'Every 30min', color: 'var(--color-red)' },
	];
</script>

<div class="risk-table" role="table" aria-label="Risk levels">
	<div class="risk-header" role="row">
		<span class="risk-header-cell" role="columnheader"></span>
		<span class="risk-header-cell" role="columnheader">Level</span>
		<span class="risk-header-cell risk-header-death" role="columnheader">Death</span>
		<span class="risk-header-cell risk-header-freq" role="columnheader">Scan</span>
	</div>

	{#each RISK_LEVELS as level (level.name)}
		<div class="risk-row" role="row">
			<span
				class="risk-indicator"
				role="cell"
				style:background-color={level.color}
				aria-hidden="true"
			></span>
			<span class="risk-name" role="cell">{level.name}</span>
			<span class="risk-death" role="cell" style:color={level.color}>{level.death}</span>
			<span class="risk-freq" role="cell">{level.freq}</span>
		</div>
	{/each}
</div>

<div class="risk-context">
	<p>Higher risk = higher yield.</p>
	<p>Dead capital flows UP to safer levels.</p>
</div>

<style>
	.risk-table {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.risk-header {
		display: grid;
		grid-template-columns: 4px 1fr auto auto;
		gap: var(--space-2);
		padding: 0 var(--space-2);
	}

	.risk-header-cell {
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wider);
		text-transform: uppercase;
	}

	.risk-header-death {
		text-align: center;
		min-width: 8ch;
	}

	.risk-header-freq {
		text-align: right;
		min-width: 9ch;
	}

	.risk-row {
		display: grid;
		grid-template-columns: 4px 1fr auto auto;
		gap: var(--space-2);
		padding: var(--space-1) var(--space-2);
		align-items: center;
	}

	.risk-indicator {
		width: 4px;
		height: 100%;
		min-height: 14px;
		border-radius: 1px;
	}

	.risk-name {
		font-size: var(--text-xs);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		text-align: left;
	}

	.risk-death {
		font-size: var(--text-xs);
		text-align: center;
		min-width: 8ch;
	}

	.risk-freq {
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
		text-align: right;
		min-width: 9ch;
	}

	.risk-context {
		margin-top: var(--space-2);
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
		line-height: var(--leading-relaxed);
	}

	/* Very narrow: drop frequency column */
	@media (max-width: 400px) {
		.risk-header {
			grid-template-columns: 4px 1fr auto;
		}

		.risk-row {
			grid-template-columns: 4px 1fr auto;
		}

		.risk-freq,
		.risk-header-freq {
			display: none;
		}
	}
</style>
