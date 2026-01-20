<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { Button, Badge, Countdown, ProgressBar } from '$lib/ui/primitives';
	import { AmountDisplay, LevelBadge, PercentDisplay, AddressDisplay } from '$lib/ui/data-display';
	import { Stack, Row } from '$lib/ui/layout';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import { LEVEL_CONFIG } from '$lib/core/types';

	const provider = getProvider();

	// Calculate effective death rate with modifiers
	let effectiveDeathRate = $derived.by(() => {
		if (!provider.position) return 0;

		const baseRate = LEVEL_CONFIG[provider.position.level].baseDeathRate;
		let rate = baseRate;

		// Apply death rate modifiers
		for (const mod of provider.modifiers) {
			if (mod.type === 'death_rate') {
				// Value is like -0.15 for -15% reduction
				rate = rate * (1 + mod.value);
			}
		}

		return Math.max(0, rate);
	});

	// Calculate base death rate for comparison
	let baseDeathRate = $derived(
		provider.position ? LEVEL_CONFIG[provider.position.level].baseDeathRate : 0
	);

	// Death rate trend (is it lower than base?)
	let deathRateTrend = $derived.by((): 'up' | 'down' | 'stable' => {
		if (effectiveDeathRate < baseDeathRate) return 'down';
		if (effectiveDeathRate > baseDeathRate) return 'up';
		return 'stable';
	});

	// Calculate total value (staked + earned)
	let totalValue = $derived(
		provider.position
			? provider.position.stakedAmount + provider.position.earnedYield
			: 0n
	);
</script>

<Box title={provider.currentUser ? `OPERATOR: ${provider.currentUser.address.slice(0, 6)}...${provider.currentUser.address.slice(-4)}` : 'YOUR STATUS'}>
	{#if provider.currentUser}
		{#if provider.position}
			<Stack gap={3}>
				<!-- Status -->
				<Row justify="between" align="center">
					<span class="label">STATUS</span>
					<Badge variant="success" glow>JACKED IN</Badge>
				</Row>

				<!-- Level -->
				<Row justify="between" align="center">
					<span class="label">LEVEL</span>
					<LevelBadge level={provider.position.level} glow />
				</Row>

				<!-- Staked Amount -->
				<Row justify="between" align="center">
					<span class="label">STAKED</span>
					<AmountDisplay amount={provider.position.stakedAmount} />
				</Row>

				<!-- Death Rate -->
				<Row justify="between" align="center">
					<span class="label">DEATH RATE</span>
					<PercentDisplay value={effectiveDeathRate * 100} trend={deathRateTrend} />
				</Row>

				<!-- Earned Yield -->
				<Row justify="between" align="center">
					<span class="label">EARNED</span>
					<span class="value-profit">
						+<AmountDisplay amount={provider.position.earnedYield} />
					</span>
				</Row>

				<!-- Next Scan Countdown -->
				<Row justify="between" align="center">
					<span class="label">NEXT SCAN</span>
					<Countdown
						targetTime={provider.position.nextScanTimestamp}
						urgentThreshold={120}
					/>
				</Row>

				<!-- Ghost Streak -->
				<Row justify="between" align="center">
					<span class="label">GHOST STREAK</span>
					<span class="streak-value">
						{provider.position.ghostStreak}
						{#if provider.position.ghostStreak > 0}
							<span class="streak-fire" aria-label="fire">{''.repeat(Math.min(provider.position.ghostStreak, 5))}</span>
						{/if}
					</span>
				</Row>

				<!-- Progress to next scan -->
				<div class="scan-progress">
					<ProgressBar
						value={calculateScanProgress(provider.position.entryTimestamp, provider.position.nextScanTimestamp)}
						variant={effectiveDeathRate > 0.5 ? 'danger' : effectiveDeathRate > 0.2 ? 'warning' : 'default'}
					/>
				</div>

				<!-- Total Value -->
				<div class="total-section">
					<Row justify="between" align="center">
						<span class="label">TOTAL VALUE</span>
						<span class="total-value">
							<AmountDisplay amount={totalValue} />
						</span>
					</Row>
				</div>
			</Stack>
		{:else}
			<!-- Not Jacked In State -->
			<Stack gap={4} align="center">
				<div class="empty-state">
					<Badge variant="warning">NOT JACKED IN</Badge>
				</div>
				<p class="empty-text">Connect to the network to start earning</p>
				<Row justify="between" align="center" class="balance-row">
					<span class="label">BALANCE</span>
					<AmountDisplay amount={provider.currentUser.tokenBalance} />
				</Row>
				<Button variant="primary" hotkey="J" fullWidth>
					Jack In
				</Button>
			</Stack>
		{/if}
	{:else}
		<!-- Not Connected State -->
		<Stack gap={4} align="center">
			<div class="empty-state">
				<Badge variant="danger">DISCONNECTED</Badge>
			</div>
			<p class="empty-text">Connect wallet to view your status</p>
		</Stack>
	{/if}
</Box>

<script lang="ts" module>
	function calculateScanProgress(entryTimestamp: number, nextScanTimestamp: number): number {
		const now = Date.now();
		const total = nextScanTimestamp - entryTimestamp;
		const elapsed = now - entryTimestamp;
		return Math.min(100, Math.max(0, (elapsed / total) * 100));
	}
</script>

<style>
	.label {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
		text-transform: uppercase;
	}

	.value-profit {
		color: var(--color-profit);
	}

	.streak-value {
		color: var(--color-amber);
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.streak-fire {
		font-size: var(--text-base);
	}

	.scan-progress {
		padding-top: var(--space-2);
	}

	.total-section {
		padding-top: var(--space-2);
		border-top: 1px solid var(--color-border-subtle);
	}

	.total-value {
		color: var(--color-text-primary);
		font-weight: var(--font-bold);
	}

	.empty-state {
		padding: var(--space-4) 0;
	}

	.empty-text {
		color: var(--color-text-tertiary);
		font-size: var(--text-sm);
		text-align: center;
	}

	:global(.balance-row) {
		width: 100%;
	}
</style>
