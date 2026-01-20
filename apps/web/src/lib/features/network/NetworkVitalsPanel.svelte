<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { ProgressBar, Countdown, AnimatedNumber } from '$lib/ui/primitives';
	import { AmountDisplay } from '$lib/ui/data-display';
	import { Stack, Row } from '$lib/ui/layout';
	import { getProvider } from '$lib/core/stores/index.svelte';

	const provider = getProvider();

	// Calculate TVL percentage of capacity
	let tvlPercent = $derived(
		provider.networkState.tvlCapacity > 0n
			? Number((provider.networkState.tvl * 100n) / provider.networkState.tvlCapacity)
			: 0
	);

	// Calculate operators percentage of ATH
	let operatorsPercent = $derived(
		provider.networkState.operatorsAth > 0
			? Math.round((provider.networkState.operatorsOnline / provider.networkState.operatorsAth) * 100)
			: 0
	);

	// System reset is critical if under 5 minutes
	let isSystemResetCritical = $derived(
		provider.networkState.systemResetTimestamp - Date.now() < 5 * 60 * 1000
	);

	// Calculate net flow (jacked in - extracted - traced)
	let netFlow = $derived(
		provider.networkState.hourlyStats.jackedIn -
			provider.networkState.hourlyStats.extracted -
			provider.networkState.hourlyStats.traced
	);

	let netFlowPositive = $derived(netFlow > 0n);
</script>

<Box title="NETWORK VITALS">
	<Stack gap={4}>
		<!-- Total Value Locked -->
		<div class="vital-section">
			<Row justify="between" align="center" class="vital-header">
				<span class="vital-label">TOTAL VALUE LOCKED</span>
				<span class="vital-value">
					<AmountDisplay amount={provider.networkState.tvl} format="compact" />
				</span>
			</Row>
			<ProgressBar value={tvlPercent} showPercent />
			<span class="vital-subtitle">{tvlPercent}% CAPACITY</span>
		</div>

		<!-- Operators Online -->
		<div class="vital-section">
			<Row justify="between" align="center" class="vital-header">
				<span class="vital-label">OPERATORS ONLINE</span>
				<span class="vital-value vital-value-animated">
					<AnimatedNumber value={provider.networkState.operatorsOnline} />
				</span>
			</Row>
			<ProgressBar value={operatorsPercent} variant="cyan" showPercent />
			<span class="vital-subtitle">{operatorsPercent}% OF ATH ({provider.networkState.operatorsAth})</span>
		</div>

		<!-- System Reset Timer -->
		<div class="vital-section" class:vital-critical={isSystemResetCritical}>
			<Row justify="between" align="center" class="vital-header">
				<span class="vital-label">SYSTEM RESET</span>
				<Countdown
					targetTime={provider.networkState.systemResetTimestamp}
					urgentThreshold={300}
					format="hh:mm:ss"
				/>
			</Row>
			{#if isSystemResetCritical}
				<div class="critical-warning">
					<span class="warning-icon" aria-hidden="true">!!</span>
					<span class="warning-text">CRITICAL - NEEDS DEPOSITS</span>
				</div>
			{/if}
		</div>

		<!-- Hourly Stats Tree -->
		<div class="vital-section stats-tree">
			<span class="vital-label">LAST HOUR:</span>
			<div class="tree-item">
				<span class="tree-branch">+-</span>
				<span class="tree-label">Jacked In:</span>
				<span class="tree-value tree-value-positive">
					+<AmountDisplay amount={provider.networkState.hourlyStats.jackedIn} format="compact" />
				</span>
			</div>
			<div class="tree-item">
				<span class="tree-branch">+-</span>
				<span class="tree-label">Extracted:</span>
				<span class="tree-value tree-value-negative">
					-<AmountDisplay amount={provider.networkState.hourlyStats.extracted} format="compact" />
				</span>
			</div>
			<div class="tree-item">
				<span class="tree-branch">'-</span>
				<span class="tree-label">Traced:</span>
				<span class="tree-value tree-value-negative">
					-<AmountDisplay amount={provider.networkState.hourlyStats.traced} format="compact" />
				</span>
			</div>
			<div class="tree-item tree-item-total">
				<span class="tree-branch"></span>
				<span class="tree-label">Net Flow:</span>
				<span class="tree-value" class:tree-value-positive={netFlowPositive} class:tree-value-negative={!netFlowPositive}>
					{netFlowPositive ? '+' : ''}<AmountDisplay amount={netFlow} format="compact" />
					{netFlowPositive ? '' : ''}
				</span>
			</div>
		</div>

		<!-- Burn Rate -->
		<div class="vital-section burn-section">
			<Row justify="between" align="center">
				<span class="vital-label">BURN RATE</span>
				<span class="burn-value">
					<AmountDisplay amount={provider.networkState.burnRatePerHour} format="compact" />/hr
				</span>
			</Row>
		</div>
	</Stack>
</Box>

<style>
	.vital-section {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.vital-label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
		text-transform: uppercase;
	}

	.vital-value {
		color: var(--color-text-primary);
		font-weight: var(--font-medium);
	}

	.vital-value-animated {
		font-variant-numeric: tabular-nums;
	}

	.vital-subtitle {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
	}

	.vital-critical {
		padding: var(--space-2);
		background: var(--color-red-glow);
		border: 1px solid var(--color-red-dim);
		animation: pulse-critical 1s ease-in-out infinite;
	}

	.critical-warning {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		margin-top: var(--space-1);
	}

	.warning-icon {
		color: var(--color-red);
		font-weight: var(--font-bold);
	}

	.warning-text {
		color: var(--color-red);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
		animation: blink 0.5s ease-in-out infinite;
	}

	/* Stats Tree */
	.stats-tree {
		padding-left: var(--space-2);
	}

	.tree-item {
		display: flex;
		gap: var(--space-2);
		font-size: var(--text-sm);
		padding: var(--space-1) 0;
	}

	.tree-item-total {
		border-top: 1px solid var(--color-border-subtle);
		margin-top: var(--space-1);
		padding-top: var(--space-2);
	}

	.tree-branch {
		color: var(--color-text-muted);
		font-family: var(--font-mono);
		user-select: none;
	}

	.tree-label {
		color: var(--color-text-secondary);
	}

	.tree-value {
		margin-left: auto;
	}

	.tree-value-positive {
		color: var(--color-profit);
	}

	.tree-value-negative {
		color: var(--color-loss);
	}

	/* Burn Section */
	.burn-section {
		padding-top: var(--space-2);
		border-top: 1px solid var(--color-border-subtle);
	}

	.burn-value {
		color: var(--color-amber);
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	/* Animations */
	@keyframes pulse-critical {
		0%,
		100% {
			background: var(--color-red-glow);
		}
		50% {
			background: transparent;
		}
	}

	@keyframes blink {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.5;
		}
	}
</style>
