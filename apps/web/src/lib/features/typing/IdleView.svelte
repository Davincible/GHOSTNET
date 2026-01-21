<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { Button, Badge, Countdown } from '$lib/ui/primitives';
	import { LevelBadge, AmountDisplay, PercentDisplay } from '$lib/ui/data-display';
	import { Stack, Row } from '$lib/ui/layout';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import { LEVEL_CONFIG } from '$lib/core/types';

	interface Props {
		/** Callback when start button is clicked */
		onStart: () => void;
	}

	let { onStart }: Props = $props();

	const provider = getProvider();

	// Calculate current death rate with modifiers
	let baseDeathRate = $derived(
		provider.position ? LEVEL_CONFIG[provider.position.level].baseDeathRate : 0
	);

	let currentProtection = $derived.by(() => {
		const typingMod = provider.modifiers.find((m) => m.source === 'typing');
		return typingMod ? typingMod.value : 0;
	});

	let effectiveDeathRate = $derived(
		baseDeathRate * (1 + currentProtection)
	);

	let hasProtection = $derived(currentProtection < 0);

	// Reward tiers for display
	const rewardTiers = [
		{ accuracy: '100%', reduction: '-25%', label: 'Perfect', highlight: true },
		{ accuracy: '95-99%', reduction: '-20%', label: 'Excellent', highlight: false },
		{ accuracy: '85-94%', reduction: '-15%', label: 'Great', highlight: false },
		{ accuracy: '70-84%', reduction: '-10%', label: 'Good', highlight: false },
		{ accuracy: '50-69%', reduction: '-5%', label: 'Okay', highlight: false },
		{ accuracy: '<50%', reduction: 'None', label: 'Failed', highlight: false }
	];

	const speedBonuses = [
		{ wpm: '100+', accuracy: '95%+', bonus: '-10%' },
		{ wpm: '80+', accuracy: '95%+', bonus: '-5%' }
	];
</script>

<div class="idle-view">
	<Box title="TRACE EVASION PROTOCOL">
		<Stack gap={4}>
			<!-- Current Status -->
			{#if provider.position}
				<div class="status-section">
					<Row justify="between" align="center">
						<span class="label">POSITION</span>
						<Row gap={2} align="center">
							<LevelBadge level={provider.position.level} />
							<AmountDisplay amount={provider.position.stakedAmount} />
						</Row>
					</Row>

					<Row justify="between" align="center">
						<span class="label">BASE DEATH RATE</span>
						<PercentDisplay value={baseDeathRate * 100} />
					</Row>

					<Row justify="between" align="center">
						<span class="label">CURRENT PROTECTION</span>
						{#if hasProtection}
							<span class="protection-active">
								{(currentProtection * 100).toFixed(0)}% death rate
							</span>
						{:else}
							<Badge variant="warning">NONE</Badge>
						{/if}
					</Row>

					<Row justify="between" align="center">
						<span class="label">EFFECTIVE RATE</span>
						<PercentDisplay value={effectiveDeathRate * 100} trend={hasProtection ? 'down' : 'stable'} />
					</Row>

					<Row justify="between" align="center">
						<span class="label">NEXT SCAN</span>
						<Countdown targetTime={provider.position.nextScanTimestamp} urgentThreshold={300} />
					</Row>
				</div>
			{:else}
				<div class="no-position">
					<Badge variant="warning">NOT JACKED IN</Badge>
					<p class="hint">You must be jacked in to earn protection rewards.</p>
				</div>
			{/if}

			<!-- Divider -->
			<div class="divider"></div>

			<!-- Reward Tiers -->
			<div class="rewards-section">
				<h3 class="section-title">REWARD TIERS</h3>
				<table class="reward-table">
					<thead>
						<tr>
							<th>ACCURACY</th>
							<th>REDUCTION</th>
						</tr>
					</thead>
					<tbody>
						{#each rewardTiers as tier, i (i)}
							<tr class:highlight={tier.highlight}>
								<td>{tier.accuracy}</td>
								<td class="reduction">{tier.reduction}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>

			<!-- Speed Bonuses -->
			<div class="speed-section">
				<h3 class="section-title">SPEED BONUSES</h3>
				<table class="reward-table">
					<thead>
						<tr>
							<th>WPM</th>
							<th>MIN ACC</th>
							<th>BONUS</th>
						</tr>
					</thead>
					<tbody>
						{#each speedBonuses as bonus, i (i)}
							<tr>
								<td>{bonus.wpm}</td>
								<td>{bonus.accuracy}</td>
								<td class="reduction">{bonus.bonus}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>

			<!-- Start Button -->
			<div class="action-section">
				<p class="rounds-info">3 ROUNDS · BACKSPACE ALLOWED · ESC TO ABORT</p>
				<Button
					variant="primary"
					size="lg"
					fullWidth
					onclick={onStart}
					disabled={!provider.position}
				>
					ACTIVATE TRACE EVASION
				</Button>
				{#if !provider.position}
					<p class="hint">Jack in first to activate protection</p>
				{/if}
			</div>
		</Stack>
	</Box>
</div>

<style>
	.idle-view {
		max-width: 500px;
		margin: 0 auto;
	}

	.status-section {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.label {
		color: var(--color-green-dim);
		font-size: var(--text-sm);
		letter-spacing: var(--tracking-wide);
	}

	.protection-active {
		color: var(--color-profit);
		font-weight: var(--font-medium);
	}

	.no-position {
		text-align: center;
		padding: var(--space-4);
	}

	.hint {
		color: var(--color-green-dim);
		font-size: var(--text-sm);
		text-align: center;
		margin-top: var(--space-2);
	}

	.divider {
		height: 1px;
		background: var(--color-bg-tertiary);
	}

	.section-title {
		color: var(--color-green-mid);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wide);
		margin-bottom: var(--space-2);
	}

	.reward-table {
		width: 100%;
		border-collapse: collapse;
		font-size: var(--text-sm);
	}

	.reward-table th {
		color: var(--color-green-dim);
		font-weight: var(--font-medium);
		text-align: left;
		padding: var(--space-1) var(--space-2);
		border-bottom: 1px solid var(--color-bg-tertiary);
	}

	.reward-table td {
		padding: var(--space-1) var(--space-2);
		border-bottom: 1px solid var(--color-bg-tertiary);
	}

	.reward-table tr:last-child td {
		border-bottom: none;
	}

	.reward-table tr.highlight {
		background: var(--color-gold-glow);
	}

	.reward-table tr.highlight td {
		color: var(--color-gold);
		font-weight: var(--font-medium);
	}

	.reduction {
		color: var(--color-profit);
		font-weight: var(--font-medium);
	}

	.action-section {
		padding-top: var(--space-2);
	}

	.rounds-info {
		color: var(--color-green-dim);
		font-size: var(--text-xs);
		text-align: center;
		letter-spacing: var(--tracking-wide);
		margin-bottom: var(--space-2);
	}
</style>
