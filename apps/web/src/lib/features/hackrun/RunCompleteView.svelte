<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { Button, Badge } from '$lib/ui/primitives';
	import { AmountDisplay } from '$lib/ui/data-display';
	import { Stack, Row } from '$lib/ui/layout';
	import type { HackRunResult } from '$lib/core/types/hackrun';

	interface Props {
		/** Final result of the run */
		result: HackRunResult;
		/** Callback for run again */
		onRunAgain: () => void;
		/** Callback for exit */
		onExit: () => void;
	}

	let { result, onRunAgain, onExit }: Props = $props();

	// Format time elapsed
	let timeSeconds = $derived(Math.floor(result.timeElapsed / 1000));
	let timeMinutes = $derived(Math.floor(timeSeconds / 60));
	let timeDisplay = $derived(`${timeMinutes}:${String(timeSeconds % 60).padStart(2, '0')}`);
</script>

<div class="complete-view">
	<Box borderColor={result.success ? 'cyan' : 'red'} glow>
		<Stack gap={4}>
			<!-- Result Banner -->
			<div class="result-banner" class:success={result.success} class:failure={!result.success}>
				{#if result.success}
					<div class="banner-icon">[+]</div>
					<h2 class="banner-title">RUN COMPLETE</h2>
					<p class="banner-subtitle">Infiltration successful</p>
				{:else}
					<div class="banner-icon">[X]</div>
					<h2 class="banner-title">RUN FAILED</h2>
					<p class="banner-subtitle">Connection terminated</p>
				{/if}
			</div>

			<!-- Stats Grid -->
			<div class="stats-grid">
				<div class="stat-item">
					<span class="stat-label">NODES</span>
					<span class="stat-value">
						{result.nodesCompleted}/{result.totalNodes}
					</span>
				</div>

				<div class="stat-item">
					<span class="stat-label">MULTIPLIER</span>
					<span class="stat-value multiplier">
						{result.finalMultiplier.toFixed(1)}x
					</span>
				</div>

				<div class="stat-item">
					<span class="stat-label">LOOT</span>
					<span class="stat-value loot">
						+<AmountDisplay amount={result.lootGained} />
					</span>
				</div>

				<div class="stat-item">
					<span class="stat-label">XP</span>
					<span class="stat-value xp">
						+{result.xpGained}
					</span>
				</div>

				<div class="stat-item">
					<span class="stat-label">TIME</span>
					<span class="stat-value">{timeDisplay}</span>
				</div>

				<div class="stat-item">
					<span class="stat-label">ENTRY FEE</span>
					<span class="stat-value" class:refunded={result.entryRefunded}>
						{#if result.entryRefunded}
							<Badge variant="success" compact>REFUNDED</Badge>
						{:else}
							<Badge variant="danger" compact>LOST</Badge>
						{/if}
					</span>
				</div>
			</div>

			<!-- Multiplier Duration Notice -->
			{#if result.success && result.finalMultiplier > 0}
				<div class="multiplier-notice">
					<span class="notice-icon">[!]</span>
					<span class="notice-text">
						{result.finalMultiplier.toFixed(1)}x yield multiplier active for 4 hours
					</span>
				</div>
			{/if}

			<!-- Actions -->
			<div class="actions">
				<Row gap={3} justify="center">
					<Button variant="primary" onclick={onRunAgain}>RUN AGAIN</Button>
					<Button variant="secondary" onclick={onExit}>EXIT</Button>
				</Row>
			</div>
		</Stack>
	</Box>
</div>

<style>
	.complete-view {
		max-width: 500px;
		margin: 0 auto;
	}

	/* Result Banner */
	.result-banner {
		text-align: center;
		padding: var(--space-4);
		margin: calc(-1 * var(--space-3)) calc(-1 * var(--space-3)) 0;
		border-bottom: 1px solid var(--color-border-subtle);
	}

	.result-banner.success {
		background: linear-gradient(to bottom, rgba(0, 229, 204, 0.1), transparent);
	}

	.result-banner.failure {
		background: linear-gradient(to bottom, rgba(255, 51, 102, 0.1), transparent);
	}

	.banner-icon {
		font-size: var(--text-2xl);
		font-weight: var(--font-bold);
		margin-bottom: var(--space-2);
	}

	.success .banner-icon {
		color: var(--color-profit);
	}

	.failure .banner-icon {
		color: var(--color-red);
	}

	.banner-title {
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
		margin: 0 0 var(--space-1) 0;
	}

	.success .banner-title {
		color: var(--color-accent);
	}

	.failure .banner-title {
		color: var(--color-red);
	}

	.banner-subtitle {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
		margin: 0;
	}

	/* Stats Grid */
	.stats-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: var(--space-3);
	}

	.stat-item {
		text-align: center;
		padding: var(--space-2);
		background: var(--color-bg-primary);
		border: 1px solid var(--color-border-subtle);
	}

	.stat-label {
		display: block;
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wide);
		margin-bottom: var(--space-1);
	}

	.stat-value {
		display: block;
		color: var(--color-text-primary);
		font-size: var(--text-base);
		font-weight: var(--font-bold);
		font-variant-numeric: tabular-nums;
	}

	.stat-value.multiplier {
		color: var(--color-accent);
	}

	.stat-value.loot {
		color: var(--color-profit);
	}

	.stat-value.xp {
		color: var(--color-amber);
	}

	/* Multiplier Notice */
	.multiplier-notice {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		padding: var(--space-3);
		background: var(--color-accent-glow);
		border: 1px solid var(--color-accent-dim);
	}

	.notice-icon {
		color: var(--color-accent);
		font-weight: var(--font-bold);
	}

	.notice-text {
		color: var(--color-accent);
		font-size: var(--text-sm);
	}

	/* Actions */
	.actions {
		padding-top: var(--space-2);
	}

	@media (max-width: 480px) {
		.stats-grid {
			grid-template-columns: repeat(2, 1fr);
		}
	}
</style>
