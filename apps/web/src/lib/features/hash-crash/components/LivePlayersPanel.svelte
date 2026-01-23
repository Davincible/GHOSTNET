<script lang="ts">
	import Box from '$lib/ui/terminal/Box.svelte';
	import AddressDisplay from '$lib/ui/data-display/AddressDisplay.svelte';
	import type { HashCrashCashOut } from '$lib/core/types/arcade';
	import type { PlayerInfo } from '../store.svelte';
	import { formatMultiplier } from '../store.svelte';

	interface Props {
		/** All players in current round */
		players: PlayerInfo[];
		/** Recent cash-outs */
		recentCashOuts: HashCrashCashOut[];
		/** Whether game is active (rising) */
		isActive: boolean;
	}

	let { players, recentCashOuts, isActive }: Props = $props();

	// Stats
	let totalPlayers = $derived(players.length);
	let cashedOutCount = $derived(players.filter((p) => p.cashedOut).length);
	let stillInCount = $derived(totalPlayers - cashedOutCount);

	// Format wei to DATA
	function formatData(wei: bigint): string {
		return (Number(wei) / 1e18).toFixed(0);
	}
</script>

<Box title="Live Players" variant="single" borderColor="dim">
	<div class="players-panel">
		{#if isActive}
			<div class="stats-row">
				<div class="stat">
					<span class="stat-value in-play">{stillInCount}</span>
					<span class="stat-label">IN PLAY</span>
				</div>
				<div class="stat">
					<span class="stat-value cashed">{cashedOutCount}</span>
					<span class="stat-label">CASHED OUT</span>
				</div>
				<div class="stat">
					<span class="stat-value">{totalPlayers}</span>
					<span class="stat-label">TOTAL</span>
				</div>
			</div>
		{/if}

		<div class="player-list">
			{#if recentCashOuts.length > 0}
				{#each recentCashOuts as cashOut (cashOut.address + cashOut.timestamp)}
					<div class="player-row cashed-out">
						<AddressDisplay address={cashOut.address} truncate />
						<span class="amount">{formatData(cashOut.payout)} $DATA</span>
						<span class="multiplier">{formatMultiplier(cashOut.multiplier)}</span>
						<span class="status-icon">✓</span>
					</div>
				{/each}
			{/if}

			{#each players.filter((p) => !p.cashedOut) as player (player.address)}
				<div class="player-row in-play">
					<AddressDisplay address={player.address} truncate />
					<span class="amount">{formatData(player.betAmount)} $DATA</span>
					<span class="status-text">IN PLAY</span>
					<span class="status-dot"></span>
				</div>
			{/each}

			{#if players.length === 0 && recentCashOuts.length === 0}
				<div class="empty-state">
					<span>No players yet</span>
				</div>
			{/if}
		</div>
	</div>
</Box>

<style>
	.players-panel {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		max-height: 300px;
	}

	/* Stats row */
	.stats-row {
		display: flex;
		justify-content: space-around;
		padding: var(--space-2);
		background: var(--color-bg-tertiary);
	}

	.stat {
		display: flex;
		flex-direction: column;
		align-items: center;
	}

	.stat-value {
		font-family: var(--font-mono);
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
	}

	.stat-value.in-play {
		color: var(--color-amber);
	}

	.stat-value.cashed {
		color: var(--color-accent);
	}

	.stat-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	/* Player list */
	.player-list {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		overflow-y: auto;
	}

	.player-row {
		display: grid;
		grid-template-columns: 1fr auto auto auto;
		gap: var(--space-2);
		align-items: center;
		padding: var(--space-2);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
	}

	.player-row.cashed-out {
		background: var(--color-accent-glow);
		animation: fade-in 0.3s ease;
	}

	.player-row.in-play {
		background: var(--color-bg-tertiary);
	}

	@keyframes fade-in {
		from {
			opacity: 0;
			transform: translateY(-10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.amount {
		color: var(--color-text-secondary);
	}

	.multiplier {
		color: var(--color-accent);
		font-weight: var(--font-medium);
	}

	.status-icon {
		color: var(--color-accent);
		font-weight: var(--font-bold);
	}

	.status-text {
		color: var(--color-amber);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.status-dot {
		width: 8px;
		height: 8px;
		background: var(--color-amber);
		border-radius: 50%;
		animation: pulse-dot 1s ease-in-out infinite;
	}

	@keyframes pulse-dot {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.3;
		}
	}

	.empty-state {
		text-align: center;
		padding: var(--space-4);
		color: var(--color-text-tertiary);
	}
</style>
