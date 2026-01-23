<script lang="ts">
	import Box from '$lib/ui/terminal/Box.svelte';
	import AddressDisplay from '$lib/ui/data-display/AddressDisplay.svelte';
	import type { HashCrashPlayerResult } from '$lib/core/types/arcade';
	import { formatMultiplier } from '../store.svelte';

	interface Props {
		/** All players and their results */
		players: HashCrashPlayerResult[];
		/** Crash point (once revealed) */
		crashPoint: number | null;
		/** Whether animation is in progress (reserved for future animation sync) */
		isActive?: boolean;
	}

	let { players, crashPoint, isActive: _isActive }: Props = $props();

	// Stats
	let totalPlayers = $derived(players.length);
	let winnersCount = $derived(players.filter((p) => p.won).length);
	let losersCount = $derived(players.filter((p) => !p.won && crashPoint !== null).length);

	// Sort players: winners first, then by target multiplier
	let sortedPlayers = $derived(
		[...players].sort((a, b) => {
			if (crashPoint === null) {
				// Before reveal: sort by target multiplier
				return a.targetMultiplier - b.targetMultiplier;
			}
			// After reveal: winners first, then by target
			if (a.won !== b.won) return a.won ? -1 : 1;
			return a.targetMultiplier - b.targetMultiplier;
		})
	);

	// Format wei to DATA
	function formatData(wei: bigint): string {
		return (Number(wei) / 1e18).toFixed(0);
	}

	// Get player status based on animation state
	function getPlayerStatus(
		player: HashCrashPlayerResult,
		currentCrash: number | null
	): 'waiting' | 'safe' | 'crashed' {
		if (currentCrash === null) return 'waiting';
		if (player.targetMultiplier < currentCrash) return 'safe';
		return 'crashed';
	}
</script>

<Box title="Players" variant="single" borderColor="dim">
	<div class="players-panel">
		{#if crashPoint !== null}
			<!-- After reveal: show win/loss stats -->
			<div class="stats-row">
				<div class="stat">
					<span class="stat-value winners">{winnersCount}</span>
					<span class="stat-label">WINNERS</span>
				</div>
				<div class="stat">
					<span class="stat-value losers">{losersCount}</span>
					<span class="stat-label">CRASHED</span>
				</div>
				<div class="stat">
					<span class="stat-value">{totalPlayers}</span>
					<span class="stat-label">TOTAL</span>
				</div>
			</div>
		{:else if totalPlayers > 0}
			<!-- Before reveal: show player count -->
			<div class="stats-row">
				<div class="stat">
					<span class="stat-value">{totalPlayers}</span>
					<span class="stat-label">PLAYERS BETTING</span>
				</div>
			</div>
		{/if}

		<div class="player-list">
			{#each sortedPlayers as player (player.address)}
				{@const status = getPlayerStatus(player, crashPoint)}
				<div
					class="player-row"
					class:won={status === 'safe'}
					class:lost={status === 'crashed'}
					class:waiting={status === 'waiting'}
				>
					<AddressDisplay address={player.address} truncate />
					<span class="target">{formatMultiplier(player.targetMultiplier)}</span>
					{#if status === 'safe'}
						<span class="payout">+{formatData(player.payout)} $DATA</span>
						<span class="status-icon won">+</span>
					{:else if status === 'crashed'}
						<span class="result-text">CRASHED</span>
						<span class="status-icon lost">X</span>
					{:else}
						<span class="waiting-text">waiting...</span>
						<span class="status-dot"></span>
					{/if}
				</div>
			{/each}

			{#if players.length === 0}
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

	.stat-value.winners {
		color: var(--color-accent);
	}

	.stat-value.losers {
		color: var(--color-red);
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
		background: var(--color-bg-tertiary);
		transition: background 0.3s ease;
	}

	.player-row.won {
		background: rgba(0, 229, 204, 0.1);
		animation: fade-in 0.3s ease;
	}

	.player-row.lost {
		background: rgba(255, 0, 64, 0.1);
		animation: fade-in 0.3s ease;
	}

	@keyframes fade-in {
		from {
			opacity: 0;
			transform: translateY(-5px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.target {
		color: var(--color-cyan);
		font-weight: var(--font-medium);
	}

	.payout {
		color: var(--color-accent);
	}

	.result-text {
		color: var(--color-red);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.waiting-text {
		color: var(--color-text-tertiary);
		font-size: var(--text-xs);
	}

	.status-icon {
		font-family: var(--font-mono);
		font-weight: var(--font-bold);
	}

	.status-icon.won {
		color: var(--color-accent);
	}

	.status-icon.lost {
		color: var(--color-red);
	}

	.status-dot {
		width: 8px;
		height: 8px;
		background: var(--color-text-tertiary);
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
