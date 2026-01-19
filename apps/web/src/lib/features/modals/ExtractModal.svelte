<script lang="ts">
	import { Modal } from '$lib/ui/modal';
	import { Box } from '$lib/ui/terminal';
	import { Button, Badge } from '$lib/ui/primitives';
	import { Stack, Row } from '$lib/ui/layout';
	import { LevelBadge, AmountDisplay } from '$lib/ui/data-display';
	import { getProvider } from '$lib/core/stores/index.svelte';

	interface Props {
		/** Whether the modal is open */
		open: boolean;
		/** Callback when modal should close */
		onclose: () => void;
	}

	let { open, onclose }: Props = $props();

	const provider = getProvider();

	let isSubmitting = $state(false);

	// Computed values from position
	let position = $derived(provider.position);
	let totalValue = $derived.by(() => {
		if (!position) return 0n;
		return position.stakedAmount + position.earnedYield;
	});
	let yieldPercent = $derived.by(() => {
		if (!position || position.stakedAmount === 0n) return 0;
		return Number((position.earnedYield * 10000n) / position.stakedAmount) / 100;
	});

	// Calculate time in position
	let timeInPosition = $derived.by(() => {
		if (!position) return '';
		const now = Date.now();
		const entry = position.entryTimestamp;
		const diffMs = now - entry;
		const hours = Math.floor(diffMs / (1000 * 60 * 60));
		const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
		if (hours > 24) {
			const days = Math.floor(hours / 24);
			return `${days}d ${hours % 24}h`;
		}
		return `${hours}h ${minutes}m`;
	});

	async function handleExtract() {
		if (isSubmitting || !position) return;
		isSubmitting = true;

		try {
			await provider.extract();
			onclose();
		} catch (error) {
			console.error('Extract failed:', error);
		} finally {
			isSubmitting = false;
		}
	}
</script>

<Modal {open} title="EXTRACT" maxWidth="sm" {onclose}>
	{#if position}
		<Stack gap={3}>
			<p class="extract-description">
				Extract your position and return to safety. All staked tokens and earned yield will be returned to your wallet.
			</p>

			<Box variant="single" borderColor="cyan" padding={3}>
				<Stack gap={2}>
					<Row justify="between">
						<span class="label">Level</span>
						<LevelBadge level={position.level} />
					</Row>
					<Row justify="between">
						<span class="label">Time In</span>
						<span class="value">{timeInPosition}</span>
					</Row>
					<Row justify="between">
						<span class="label">Ghost Streak</span>
						<span class="value streak">
							{position.ghostStreak > 0 ? `🔥 ${position.ghostStreak}` : '0'}
						</span>
					</Row>

					<div class="divider"></div>

					<Row justify="between">
						<span class="label">Staked</span>
						<AmountDisplay amount={position.stakedAmount} />
					</Row>
					<Row justify="between">
						<span class="label">Yield Earned</span>
						<span class="yield">
							+<AmountDisplay amount={position.earnedYield} />
							<span class="yield-percent">(+{yieldPercent.toFixed(2)}%)</span>
						</span>
					</Row>

					<div class="divider"></div>

					<Row justify="between">
						<span class="label total-label">TOTAL</span>
						<span class="total-value">
							<AmountDisplay amount={totalValue} />
						</span>
					</Row>
				</Stack>
			</Box>

			{#if position.ghostStreak > 0}
				<div class="streak-warning">
					<Badge variant="warning">STREAK RESET</Badge>
					<p>Your {position.ghostStreak}-scan ghost streak will be reset to 0.</p>
				</div>
			{/if}

			<Row justify="end" gap={2}>
				<Button variant="ghost" onclick={onclose}>Cancel</Button>
				<Button 
					variant="primary" 
					onclick={handleExtract}
					loading={isSubmitting}
				>
					CONFIRM EXTRACT
				</Button>
			</Row>
		</Stack>
	{:else}
		<Stack gap={3}>
			<p class="no-position">
				You don't have an active position to extract.
			</p>
			<Row justify="end">
				<Button variant="ghost" onclick={onclose}>Close</Button>
			</Row>
		</Stack>
	{/if}
</Modal>

<style>
	.extract-description {
		color: var(--color-green-mid);
		font-size: var(--text-sm);
		line-height: var(--leading-relaxed);
	}

	.label {
		color: var(--color-green-dim);
		font-size: var(--text-sm);
	}

	.value {
		color: var(--color-green-bright);
		font-size: var(--text-sm);
	}

	.streak {
		color: var(--color-amber);
	}

	.yield {
		color: var(--color-profit);
		font-size: var(--text-sm);
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.yield-percent {
		color: var(--color-green-dim);
		font-size: var(--text-xs);
	}

	.total-label {
		color: var(--color-green-bright);
		font-weight: var(--font-bold);
	}

	.total-value {
		color: var(--color-cyan);
		font-weight: var(--font-bold);
	}

	.divider {
		height: 1px;
		background: var(--color-bg-tertiary);
		margin: var(--space-1) 0;
	}

	.streak-warning {
		display: flex;
		align-items: flex-start;
		gap: var(--space-2);
		padding: var(--space-2);
		background: rgba(var(--color-amber-rgb), 0.1);
	}

	.streak-warning p {
		color: var(--color-amber);
		font-size: var(--text-sm);
	}

	.no-position {
		color: var(--color-green-dim);
		text-align: center;
		padding: var(--space-4);
	}
</style>
