<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { Button, Badge } from '$lib/ui/primitives';
	import { Stack } from '$lib/ui/layout';
	import { PercentDisplay } from '$lib/ui/data-display';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import { LEVEL_CONFIG } from '$lib/core/types';
	import type { TypingGameResult } from './store.svelte';

	interface Props {
		/** Game result */
		result: TypingGameResult;
		/** Callback when practice again is clicked */
		onPracticeAgain: () => void;
		/** Callback when return is clicked */
		onReturn: () => void;
	}

	let { result, onPracticeAgain, onReturn }: Props = $props();

	const provider = getProvider();

	// Calculate death rate changes
	let baseDeathRate = $derived(
		provider.position ? LEVEL_CONFIG[provider.position.level].baseDeathRate : 0
	);

	let oldProtection = $derived.by(() => {
		const typingMod = provider.modifiers.find((m) => m.source === 'typing');
		return typingMod ? typingMod.value : 0;
	});

	let newProtection = $derived(result.reward?.value ?? 0);

	let oldEffectiveRate = $derived(baseDeathRate * (1 + oldProtection));
	let newEffectiveRate = $derived(baseDeathRate * (1 + newProtection));

	let hasImprovement = $derived(newProtection < oldProtection);
	let hasSameOrBetter = $derived(newProtection <= oldProtection && result.reward !== null);

	// Result tier - Badge variants: default, success, warning, danger, info, hotkey
	let resultTier = $derived.by(() => {
		if (result.accuracy >= 1.0)
			return {
				label: 'PERFECT',
				variant: 'success' as const,
				isPerfect: true,
				colorClass: 'tier-perfect',
			};
		if (result.accuracy >= 0.95)
			return {
				label: 'EXCELLENT',
				variant: 'success' as const,
				isPerfect: false,
				colorClass: 'tier-success',
			};
		if (result.accuracy >= 0.85)
			return {
				label: 'GREAT',
				variant: 'success' as const,
				isPerfect: false,
				colorClass: 'tier-success',
			};
		if (result.accuracy >= 0.7)
			return { label: 'GOOD', variant: 'info' as const, isPerfect: false, colorClass: 'tier-info' };
		if (result.accuracy >= 0.5)
			return {
				label: 'OKAY',
				variant: 'warning' as const,
				isPerfect: false,
				colorClass: 'tier-warning',
			};
		return {
			label: 'FAILED',
			variant: 'danger' as const,
			isPerfect: false,
			colorClass: 'tier-danger',
		};
	});
</script>

<div class="complete-view">
	<Box title="EVASION SEQUENCE COMPLETE">
		<div class="result-content">
			<!-- Success Icon & Tier -->
			<div class="result-header">
				<div class="result-icon" class:success={result.completed} class:timeout={!result.completed}>
					{#if result.completed}
						<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<polyline points="20 6 9 17 4 12"></polyline>
						</svg>
					{:else}
						<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="10"></circle>
							<polyline points="12 6 12 12 16 14"></polyline>
						</svg>
					{/if}
				</div>
				<span class:perfect-badge={resultTier.isPerfect}>
					<Badge variant={resultTier.variant}>{resultTier.label}</Badge>
				</span>
			</div>

			<!-- Stats Grid -->
			<div class="stats-grid {resultTier.colorClass}">
				<div class="stat-box">
					<span class="stat-value">{result.wpm}</span>
					<span class="stat-label">AVG WPM</span>
				</div>
				<div class="stat-box">
					<span class="stat-value">{Math.round(result.accuracy * 100)}%</span>
					<span class="stat-label">ACCURACY</span>
				</div>
				<div class="stat-box">
					<span class="stat-value">{result.roundsCompleted}/{result.totalRounds}</span>
					<span class="stat-label">ROUNDS</span>
				</div>
			</div>

			<!-- Divider -->
			<div class="divider"></div>

			<!-- Reward Section -->
			<div class="reward-section">
				<h3 class="section-title">PROTECTION ACQUIRED</h3>

				{#if result.reward}
					<div class="reward-display">
						<span class="reward-value">{result.reward.label}</span>
					</div>

					<!-- Before/After comparison -->
					{#if provider.position}
						<div class="comparison">
							<div class="comparison-row">
								<span class="comparison-label">BASE DEATH RATE</span>
								<PercentDisplay value={baseDeathRate * 100} />
							</div>

							<div class="comparison-row">
								<span class="comparison-label">BEFORE</span>
								<PercentDisplay
									value={oldEffectiveRate * 100}
									trend={oldProtection < 0 ? 'down' : 'stable'}
								/>
							</div>

							<div class="comparison-row highlight">
								<span class="comparison-label">AFTER</span>
								<PercentDisplay value={newEffectiveRate * 100} trend="down" />
							</div>

							{#if hasImprovement}
								<div class="improvement-note">
									<Badge variant="success">UPGRADED</Badge>
									<span>Protection improved!</span>
								</div>
							{:else if hasSameOrBetter}
								<div class="maintained-note">
									<Badge variant="info">MAINTAINED</Badge>
									<span>Protection extended</span>
								</div>
							{/if}
						</div>
					{/if}
				{:else}
					<div class="no-reward">
						<Badge variant="warning">NO PROTECTION</Badge>
						<p class="no-reward-text">Accuracy below 50% - no protection earned</p>
						<p class="no-reward-hint">Try again to earn death rate reduction</p>
					</div>
				{/if}
			</div>

			<!-- Duration Note -->
			{#if result.reward && provider.position}
				<div class="duration-note">
					<span class="duration-label">Protection lasts until next trace scan</span>
				</div>
			{/if}

			<!-- Action Buttons -->
			<Stack gap={2}>
				<Button variant="secondary" size="lg" fullWidth onclick={onPracticeAgain}>
					PRACTICE AGAIN
				</Button>
				<Button variant="ghost" size="md" fullWidth onclick={onReturn}>RETURN TO NETWORK</Button>
			</Stack>
		</div>
	</Box>
</div>

<style>
	.complete-view {
		max-width: 500px;
		margin: 0 auto;
	}

	.result-content {
		padding: var(--space-4) 0;
	}

	.result-header {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-3);
		margin-bottom: var(--space-6);
	}

	.result-icon {
		width: 64px;
		height: 64px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		animation: pop-in 0.4s ease-out;
	}

	.result-icon svg {
		width: 32px;
		height: 32px;
	}

	.result-icon.success {
		background: var(--color-profit-glow);
		color: var(--color-profit);
		box-shadow: 0 0 20px var(--color-profit-glow);
	}

	.result-icon.timeout {
		background: var(--color-amber-glow);
		color: var(--color-amber);
		box-shadow: 0 0 20px var(--color-amber-glow);
	}

	.perfect-badge :global(.badge) {
		background: var(--color-gold-glow);
		color: var(--color-gold);
		border-color: var(--color-gold);
		animation: gold-pulse 2s ease-in-out infinite;
	}

	@keyframes gold-pulse {
		0%,
		100% {
			box-shadow: 0 0 5px var(--color-gold-glow);
		}
		50% {
			box-shadow: 0 0 15px var(--color-gold-glow);
		}
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: var(--space-3);
		margin-bottom: var(--space-4);
	}

	.stat-box {
		background: var(--color-bg-secondary);
		padding: var(--space-3);
		text-align: center;
	}

	.stat-value {
		display: block;
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		font-variant-numeric: tabular-nums;
	}

	.stat-label {
		display: block;
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wide);
		margin-top: var(--space-1);
	}

	/* Tier-based stat colors */
	.tier-perfect .stat-value {
		color: var(--color-gold);
	}
	.tier-perfect .stat-label {
		color: var(--color-gold);
		opacity: 0.7;
	}

	.tier-success .stat-value {
		color: var(--color-profit);
	}
	.tier-success .stat-label {
		color: var(--color-profit);
		opacity: 0.6;
	}

	.tier-info .stat-value {
		color: var(--color-cyan);
	}
	.tier-info .stat-label {
		color: var(--color-cyan);
		opacity: 0.6;
	}

	.tier-warning .stat-value {
		color: var(--color-amber);
	}
	.tier-warning .stat-label {
		color: var(--color-amber);
		opacity: 0.6;
	}

	.tier-danger .stat-value {
		color: var(--color-red);
	}
	.tier-danger .stat-label {
		color: var(--color-red);
		opacity: 0.6;
	}

	.divider {
		height: 1px;
		background: var(--color-bg-tertiary);
		margin: var(--space-4) 0;
	}

	.section-title {
		color: var(--color-green-mid);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wide);
		text-align: center;
		margin-bottom: var(--space-3);
	}

	.reward-section {
		margin-bottom: var(--space-4);
	}

	.reward-display {
		background: var(--color-profit-glow);
		border: 1px solid var(--color-profit);
		padding: var(--space-3);
		text-align: center;
		margin-bottom: var(--space-3);
	}

	.reward-value {
		color: var(--color-profit);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
	}

	.comparison {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.comparison-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: var(--space-1) var(--space-2);
	}

	.comparison-row.highlight {
		background: var(--color-bg-secondary);
		border-left: 2px solid var(--color-profit);
	}

	.comparison-label {
		color: var(--color-green-dim);
		font-size: var(--text-sm);
	}

	.improvement-note,
	.maintained-note {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		margin-top: var(--space-2);
		padding: var(--space-2);
		font-size: var(--text-sm);
		color: var(--color-green-mid);
	}

	.no-reward {
		text-align: center;
		padding: var(--space-4);
	}

	.no-reward-text {
		color: var(--color-amber);
		margin-top: var(--space-2);
	}

	.no-reward-hint {
		color: var(--color-green-dim);
		font-size: var(--text-sm);
		margin-top: var(--space-1);
	}

	.duration-note {
		text-align: center;
		margin-bottom: var(--space-4);
	}

	.duration-label {
		color: var(--color-green-dim);
		font-size: var(--text-sm);
	}

	@keyframes pop-in {
		0% {
			transform: scale(0);
			opacity: 0;
		}
		70% {
			transform: scale(1.1);
		}
		100% {
			transform: scale(1);
			opacity: 1;
		}
	}
</style>
