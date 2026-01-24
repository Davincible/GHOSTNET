<script lang="ts">
	import { onMount } from 'svelte';
	import { browser } from '$app/environment';
	import Box from '$lib/ui/terminal/Box.svelte';
	import Button from '$lib/ui/primitives/Button.svelte';
	import { WalletModal } from '$lib/features/modals';
	import { wallet } from '$lib/web3/wallet.svelte';
	import { createContractProvider, formatData, parseData } from '$lib/features/hash-crash';

	// Create provider
	const provider = createContractProvider();

	// Local state for bet form
	let betAmount = $state('100');
	let targetMultiplier = $state('2.0');

	// Wallet modal state
	let showWalletModal = $state(false);

	// Connect on mount
	onMount(() => {
		if (browser) {
			// Initialize wallet watchers
			const cleanupWallet = wallet.init();
			// Connect provider
			const cleanupProvider = provider.connect();
			return () => {
				cleanupWallet();
				cleanupProvider();
			};
		}
	});

	// Format address for display
	function shortAddr(addr: `0x${string}`): string {
		return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
	}

	// Handle place bet
	async function handlePlaceBet() {
		const amount = parseData(betAmount);
		const target = parseFloat(targetMultiplier);
		await provider.placeBet(amount, target);
	}

	function openWalletModal() {
		showWalletModal = true;
	}

	function closeWalletModal() {
		showWalletModal = false;
	}
</script>

<svelte:head>
	<title>Hash Crash Testnet | GHOSTNET</title>
</svelte:head>

<div class="testnet-page">
	<header class="page-header">
		<h1>HASH CRASH - TESTNET</h1>
		<p class="subtitle">Contract integration test page (MegaETH Testnet)</p>
	</header>

	<!-- Wallet Status -->
	<Box title="Wallet" variant="single">
		<div class="section">
			{#if wallet.isConnected}
				<div class="status-row">
					<span class="label">Address:</span>
					<span class="value mono">{wallet.address}</span>
				</div>
				<div class="status-row">
					<span class="label">Chain:</span>
					<span class="value">{wallet.chainName ?? 'Unknown'} ({wallet.chainId})</span>
				</div>
				<div class="status-row">
					<span class="label">DATA Balance:</span>
					<span class="value">{formatData(provider.state.balance)} $DATA</span>
				</div>
				<div class="status-row">
					<span class="label">Withdrawable:</span>
					<span class="value">{formatData(provider.state.withdrawable)} $DATA</span>
				</div>
				<div class="actions">
					<Button variant="secondary" onclick={() => wallet.disconnect()}>Disconnect</Button>
					{#if provider.state.withdrawable > 0n}
						<Button onclick={() => provider.withdraw()} disabled={provider.state.isLoading}>
							Withdraw Winnings
						</Button>
					{/if}
				</div>
			{:else}
				<p>Connect your wallet to interact with the contract.</p>
				<Button onclick={openWalletModal}>Connect Wallet</Button>
			{/if}
		</div>
	</Box>

	<!-- Provider Status -->
	<Box title="Provider Status" variant="single">
		<div class="section">
			<div class="status-row">
				<span class="label">Connected:</span>
				<span class="value" class:success={provider.state.isConnected}>
					{provider.state.isConnected ? 'YES' : 'NO'}
				</span>
			</div>
			<div class="status-row">
				<span class="label">Loading:</span>
				<span class="value">{provider.state.isLoading ? 'YES' : 'NO'}</span>
			</div>
			{#if provider.state.pendingTx}
				<div class="status-row">
					<span class="label">Pending TX:</span>
					<span class="value mono">{provider.state.pendingTx}</span>
				</div>
			{/if}
			{#if provider.state.error}
				<div class="status-row error">
					<span class="label">Error:</span>
					<span class="value">{provider.state.error}</span>
				</div>
			{/if}
			<div class="status-row">
				<span class="label">Last Poll:</span>
				<span class="value">{new Date(provider.state.lastPoll).toLocaleTimeString()}</span>
			</div>
			<div class="actions">
				<Button variant="secondary" onclick={() => provider.refresh()}>Refresh</Button>
			</div>
		</div>
	</Box>

	<!-- Round State -->
	<Box
		title="Current Round"
		variant="double"
		borderColor={provider.phase === 'betting' ? 'bright' : 'default'}
	>
		<div class="section">
			<div class="status-row">
				<span class="label">Round ID:</span>
				<span class="value mono">{provider.state.roundId.toString()}</span>
			</div>
			<div class="status-row">
				<span class="label">Phase:</span>
				<span
					class="value phase-badge"
					class:betting={provider.phase === 'betting'}
					class:locked={provider.phase === 'locked'}
					class:revealed={provider.phase === 'revealed'}
					class:settled={provider.phase === 'settled'}
				>
					{provider.phase.toUpperCase()}
				</span>
			</div>
			{#if provider.state.round}
				<div class="status-row">
					<span class="label">Prize Pool:</span>
					<span class="value">{formatData(provider.state.round.prizePool)} $DATA</span>
				</div>
				<div class="status-row">
					<span class="label">Player Count:</span>
					<span class="value">{provider.state.round.playerCount.toString()}</span>
				</div>
				{#if provider.crashPoint > 0}
					<div class="status-row">
						<span class="label">Crash Point:</span>
						<span class="value crash-point">{provider.crashPoint.toFixed(2)}x</span>
					</div>
				{/if}
				{#if provider.bettingTimeRemaining > 0}
					<div class="status-row">
						<span class="label">Time Remaining:</span>
						<span class="value">{Math.ceil(provider.bettingTimeRemaining / 1000)}s</span>
					</div>
				{/if}
				{#if provider.state.seedReady}
					<div class="status-row">
						<span class="label">Seed Ready:</span>
						<span class="value success">YES - Can reveal!</span>
					</div>
				{/if}
			{/if}

			<!-- Round Actions -->
			<div class="actions">
				{#if provider.phase === 'none' || provider.phase === 'settled' || provider.phase === 'cancelled' || provider.phase === 'expired'}
					<Button onclick={() => provider.startRound()} disabled={provider.state.isLoading}>
						Start New Round
					</Button>
				{/if}
				{#if provider.phase === 'betting' && provider.bettingTimeRemaining === 0}
					<Button onclick={() => provider.lockRound()} disabled={provider.state.isLoading}>
						Lock Round
					</Button>
				{/if}
				{#if provider.phase === 'locked' && provider.state.seedReady}
					<Button onclick={() => provider.revealCrash()} disabled={provider.state.isLoading}>
						Reveal Crash
					</Button>
				{/if}
				{#if provider.phase === 'revealed'}
					<Button onclick={() => provider.settleAll()} disabled={provider.state.isLoading}>
						Settle All Players
					</Button>
				{/if}
			</div>
		</div>
	</Box>

	<!-- Place Bet -->
	{#if provider.phase === 'betting'}
		<Box title="Place Bet" variant="double" borderColor="bright">
			<div class="section">
				{#if provider.state.playerBet}
					<div class="bet-placed">
						<p>Bet placed!</p>
						<div class="status-row">
							<span class="label">Amount:</span>
							<span class="value">{formatData(provider.state.playerBet.amount)} $DATA</span>
						</div>
						<div class="status-row">
							<span class="label">Target:</span>
							<span class="value"
								>{(Number(provider.state.playerBet.targetMultiplier) / 100).toFixed(2)}x</span
							>
						</div>
					</div>
				{:else if provider.canBet}
					<div class="bet-form">
						<div class="form-group">
							<label for="betAmount">Amount ($DATA)</label>
							<input
								id="betAmount"
								type="text"
								bind:value={betAmount}
								placeholder="100"
								class="input"
							/>
						</div>
						<div class="form-group">
							<label for="targetMult">Target Multiplier</label>
							<input
								id="targetMult"
								type="text"
								bind:value={targetMultiplier}
								placeholder="2.0"
								class="input"
							/>
						</div>
						<Button onclick={handlePlaceBet} disabled={provider.state.isLoading}>Place Bet</Button>
					</div>
				{:else}
					<p>Connect wallet to place bet</p>
				{/if}
			</div>
		</Box>
	{/if}

	<!-- Player Result -->
	{#if provider.state.playerBet && provider.playerResult !== 'pending'}
		<Box
			title="Your Result"
			variant="double"
			borderColor={provider.playerResult === 'won' ? 'bright' : 'red'}
		>
			<div
				class="section result-section"
				class:won={provider.playerResult === 'won'}
				class:lost={provider.playerResult === 'lost'}
			>
				<div class="result-text">
					{provider.playerResult === 'won' ? 'YOU WON!' : 'YOU LOST'}
				</div>
				<div class="status-row">
					<span class="label">Your Target:</span>
					<span class="value"
						>{(Number(provider.state.playerBet.targetMultiplier) / 100).toFixed(2)}x</span
					>
				</div>
				<div class="status-row">
					<span class="label">Crash Point:</span>
					<span class="value">{provider.crashPoint.toFixed(2)}x</span>
				</div>
				{#if provider.playerResult === 'won'}
					<div class="status-row">
						<span class="label">Payout:</span>
						<span class="value"
							>{formatData(
								(provider.state.playerBet.amount * provider.state.playerBet.targetMultiplier) /
									BigInt(100)
							)} $DATA</span
						>
					</div>
				{/if}
			</div>
		</Box>
	{/if}

	<!-- Players List -->
	{#if provider.state.players.length > 0}
		<Box title="Players ({provider.state.players.length})" variant="single">
			<div class="section">
				<table class="players-table">
					<thead>
						<tr>
							<th>Address</th>
							<th>Amount</th>
							<th>Target</th>
							<th>Status</th>
						</tr>
					</thead>
					<tbody>
						{#each provider.state.players as player}
							<tr class:won={player.won === true} class:lost={player.won === false}>
								<td class="mono">{shortAddr(player.address)}</td>
								<td>{formatData(player.amount)}</td>
								<td>{player.targetMultiplier.toFixed(2)}x</td>
								<td>
									{#if player.settled}
										{player.won ? 'WON' : 'LOST'}
									{:else}
										Pending
									{/if}
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		</Box>
	{/if}

	<!-- Debug Info -->
	<Box title="Debug Info" variant="single">
		<div class="section">
			<pre class="debug-json">{JSON.stringify(
					{
						roundId: provider.state.roundId.toString(),
						phase: provider.phase,
						canBet: provider.canBet,
						crashPoint: provider.crashPoint,
						playerResult: provider.playerResult,
						bettingTimeRemaining: provider.bettingTimeRemaining,
						seedReady: provider.state.seedReady,
					},
					null,
					2
				)}</pre>
		</div>
	</Box>
</div>

<!-- Wallet Selection Modal -->
<WalletModal open={showWalletModal} onclose={closeWalletModal} />

<style>
	.testnet-page {
		max-width: 800px;
		margin: 0 auto;
		padding: var(--space-4);
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	.page-header {
		text-align: center;
		margin-bottom: var(--space-4);
	}

	.page-header h1 {
		font-family: var(--font-mono);
		font-size: var(--text-2xl);
		color: var(--color-accent);
		margin: 0;
	}

	.subtitle {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		margin: var(--space-2) 0 0;
	}

	.section {
		padding: var(--space-3);
	}

	.status-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: var(--space-1) 0;
		font-family: var(--font-mono);
		font-size: var(--text-sm);
	}

	.label {
		color: var(--color-text-secondary);
	}

	.value {
		color: var(--color-text-primary);
	}

	.value.success {
		color: var(--color-accent);
	}

	.value.mono {
		font-family: var(--font-mono);
	}

	.error .value {
		color: var(--color-red);
	}

	.actions {
		display: flex;
		gap: var(--space-2);
		margin-top: var(--space-3);
	}

	.phase-badge {
		padding: var(--space-1) var(--space-2);
		border: 1px solid var(--color-border-default);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
	}

	.phase-badge.betting {
		border-color: var(--color-cyan);
		color: var(--color-cyan);
	}

	.phase-badge.locked {
		border-color: var(--color-amber);
		color: var(--color-amber);
	}

	.phase-badge.revealed,
	.phase-badge.settled {
		border-color: var(--color-accent);
		color: var(--color-accent);
	}

	.crash-point {
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		color: var(--color-red);
	}

	.bet-form {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.form-group label {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider);
	}

	.input {
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-default);
		padding: var(--space-2) var(--space-3);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-primary);
	}

	.input:focus {
		outline: none;
		border-color: var(--color-accent);
	}

	.bet-placed {
		text-align: center;
	}

	.bet-placed p {
		font-size: var(--text-lg);
		color: var(--color-accent);
		margin-bottom: var(--space-2);
	}

	.result-section {
		text-align: center;
	}

	.result-text {
		font-size: var(--text-2xl);
		font-weight: var(--font-bold);
		margin-bottom: var(--space-3);
	}

	.result-section.won .result-text {
		color: var(--color-accent);
	}

	.result-section.lost .result-text {
		color: var(--color-red);
	}

	.players-table {
		width: 100%;
		border-collapse: collapse;
		font-family: var(--font-mono);
		font-size: var(--text-sm);
	}

	.players-table th,
	.players-table td {
		padding: var(--space-2);
		text-align: left;
		border-bottom: 1px solid var(--color-border-subtle);
	}

	.players-table th {
		color: var(--color-text-secondary);
		font-size: var(--text-xs);
		text-transform: uppercase;
		letter-spacing: var(--tracking-wider);
	}

	.players-table tr.won td {
		color: var(--color-accent);
	}

	.players-table tr.lost td {
		color: var(--color-red);
		opacity: 0.7;
	}

	.debug-json {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
		background: var(--color-bg-secondary);
		padding: var(--space-2);
		overflow-x: auto;
		white-space: pre-wrap;
	}
</style>
