<script lang="ts">
	// GHOSTNET Test Page
	// Phase 3: Live Data from Mock Provider

	import { Button, ProgressBar, AnimatedNumber, Countdown, Badge, Spinner } from '$lib/ui/primitives';
	import { AddressDisplay, AmountDisplay, PercentDisplay, LevelBadge } from '$lib/ui/data-display';
	import { Stack, Row } from '$lib/ui/layout';
	import { Box, Panel } from '$lib/ui/terminal';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import type { FeedEvent } from '$lib/core/types';

	// Get provider from context
	const provider = getProvider();

	// Local UI state
	let isConnecting = $state(false);

	// Connect/disconnect wallet
	async function toggleWallet() {
		if (provider.currentUser) {
			provider.disconnectWallet();
		} else {
			isConnecting = true;
			await provider.connectWallet();
			isConnecting = false;
		}
	}

	// Format feed event for display
	function formatFeedEvent(event: FeedEvent): { text: string; color: string } {
		const addr = (a: `0x${string}`) => `${a.slice(0, 6)}...${a.slice(-4)}`;
		const amt = (a: bigint) => `${Number(a / 10n ** 18n)}Đ`;

		switch (event.data.type) {
			case 'JACK_IN':
				return {
					text: `> ${addr(event.data.address)} jacked in [${event.data.level}] ${amt(event.data.amount)}`,
					color: 'text-green'
				};
			case 'EXTRACT':
				return {
					text: `> ${addr(event.data.address)} extracted ${amt(event.data.amount)} [+${amt(event.data.gain)} gain]`,
					color: 'text-profit'
				};
			case 'TRACED':
				return {
					text: `> ${addr(event.data.address)} ████ TRACED ████ -${amt(event.data.amountLost)}`,
					color: 'text-red'
				};
			case 'SURVIVED':
				return {
					text: `> ${addr(event.data.address)} survived [${event.data.level}] streak: ${event.data.streak}`,
					color: 'text-green-mid'
				};
			case 'TRACE_SCAN_WARNING':
				return {
					text: `> ⚠ TRACE SCAN [${event.data.level}] in ${event.data.secondsUntil}s`,
					color: 'text-amber'
				};
			case 'TRACE_SCAN_COMPLETE':
				return {
					text: `> SCAN COMPLETE [${event.data.level}] ${event.data.survivors} survived, ${event.data.traced} traced`,
					color: 'text-cyan'
				};
			case 'WHALE_ALERT':
				return {
					text: `> 🐋 WHALE: ${addr(event.data.address)} [${event.data.level}] ${amt(event.data.amount)}`,
					color: 'text-gold'
				};
			case 'JACKPOT':
				return {
					text: `> 🔥 JACKPOT: ${addr(event.data.address)} [${event.data.level}] +${amt(event.data.amount)}`,
					color: 'text-gold'
				};
			case 'CREW_EVENT':
				return {
					text: `> [${event.data.crewName}] ${event.data.message}`,
					color: 'text-cyan'
				};
			case 'MINIGAME_RESULT':
				return {
					text: `> ${addr(event.data.address)} ${event.data.game}: ${event.data.result}`,
					color: 'text-cyan'
				};
			default:
				return { text: `> Unknown event`, color: 'text-green-dim' };
		}
	}

	// Calculate TVL percentage
	let tvlPercent = $derived(
		provider.networkState.tvlCapacity > 0n
			? Number((provider.networkState.tvl * 100n) / provider.networkState.tvlCapacity)
			: 0
	);

	// Calculate operators percentage
	let operatorsPercent = $derived(
		provider.networkState.operatorsAth > 0
			? Math.round((provider.networkState.operatorsOnline / provider.networkState.operatorsAth) * 100)
			: 0
	);
</script>

<svelte:head>
	<title>GHOSTNET v1.0.7</title>
	<meta name="description" content="Jack In. Don't Get Traced." />
</svelte:head>

<main class="terminal">
	<!-- Header -->
	<header class="header">
		<h1 class="logo glow-green">GHOSTNET <span class="text-green-dim">v1.0.7</span></h1>
		<Row gap={4} align="center">
			<span class="text-green-mid text-sm">NETWORK:</span>
			{#if provider.connectionStatus === 'connected'}
				<Badge variant="success" glow>ONLINE</Badge>
			{:else if provider.connectionStatus === 'connecting'}
				<Badge variant="warning" pulse>CONNECTING</Badge>
			{:else}
				<Badge variant="danger">OFFLINE</Badge>
			{/if}
		</Row>
	</header>

	<div class="content">
		<div class="grid-layout">
			<!-- Left Column -->
			<div class="left-column">
				<!-- Live Feed -->
				<Panel title="LIVE FEED" scrollable maxHeight="300px">
					<Stack gap={1}>
						{#each provider.feedEvents.slice(0, 15) as event (event.id)}
							{@const formatted = formatFeedEvent(event)}
							<p class="feed-item text-sm {formatted.color}">
								{formatted.text}
							</p>
						{/each}
						{#if provider.feedEvents.length === 0}
							<p class="text-sm text-green-dim">Waiting for events...</p>
						{/if}
					</Stack>
				</Panel>

				<!-- Network Vitals -->
				<Box title="NETWORK VITALS">
					<Stack gap={3}>
						<div>
							<Row justify="between" class="mb-1">
								<span class="text-green-dim text-sm">TOTAL VALUE LOCKED</span>
								<AmountDisplay amount={provider.networkState.tvl} format="compact" />
							</Row>
							<ProgressBar value={tvlPercent} showPercent />
						</div>

						<div>
							<Row justify="between" class="mb-1">
								<span class="text-green-dim text-sm">OPERATORS ONLINE</span>
								<span class="text-green">
									<AnimatedNumber value={provider.networkState.operatorsOnline} />
								</span>
							</Row>
							<ProgressBar value={operatorsPercent} variant="cyan" showPercent />
						</div>

						<div>
							<Row justify="between">
								<span class="text-green-dim text-sm">SYSTEM RESET</span>
								<Countdown
									targetTime={provider.networkState.systemResetTimestamp}
									urgentThreshold={300}
								/>
							</Row>
						</div>

						<div class="stats-tree">
							<p class="text-green-dim text-sm">LAST HOUR:</p>
							<p class="text-sm">├─ Jacked In: <AmountDisplay amount={provider.networkState.hourlyStats.jackedIn} format="compact" /></p>
							<p class="text-sm">├─ Extracted: <AmountDisplay amount={provider.networkState.hourlyStats.extracted} format="compact" /></p>
							<p class="text-sm">└─ Traced: <AmountDisplay amount={provider.networkState.hourlyStats.traced} format="compact" /></p>
						</div>

						<Row justify="between">
							<span class="text-green-dim text-sm">BURN RATE</span>
							<span class="text-amber">
								<AmountDisplay amount={provider.networkState.burnRatePerHour} />/hr 🔥
							</span>
						</Row>
					</Stack>
				</Box>
			</div>

			<!-- Right Column -->
			<div class="right-column">
				<!-- Wallet Connection -->
				<Box title="WALLET">
					{#if provider.currentUser}
						<Stack gap={3}>
							<Row justify="between">
								<span class="text-green-dim text-sm">ADDRESS</span>
								<AddressDisplay address={provider.currentUser.address} />
							</Row>
							<Row justify="between">
								<span class="text-green-dim text-sm">$DATA BALANCE</span>
								<AmountDisplay amount={provider.currentUser.tokenBalance} />
							</Row>
							<Button variant="danger" size="sm" onclick={toggleWallet}>
								Disconnect
							</Button>
						</Stack>
					{:else}
						<Stack gap={3} align="center">
							<p class="text-green-dim text-sm">Connect wallet to play</p>
							<Button variant="primary" onclick={toggleWallet} loading={isConnecting}>
								Connect Wallet
							</Button>
						</Stack>
					{/if}
				</Box>

				<!-- Position -->
				{#if provider.currentUser}
					<Box title="YOUR POSITION">
						{#if provider.position}
							<Stack gap={3}>
								<Row justify="between">
									<span class="text-green-dim text-sm">STATUS</span>
									<Badge variant="success" glow>JACKED IN</Badge>
								</Row>
								<Row justify="between">
									<span class="text-green-dim text-sm">LEVEL</span>
									<LevelBadge level={provider.position.level} glow />
								</Row>
								<Row justify="between">
									<span class="text-green-dim text-sm">STAKED</span>
									<AmountDisplay amount={provider.position.stakedAmount} />
								</Row>
								<Row justify="between">
									<span class="text-green-dim text-sm">EARNED</span>
									<AmountDisplay amount={provider.position.earnedYield} showSign colorize />
								</Row>
								<Row justify="between">
									<span class="text-green-dim text-sm">NEXT SCAN</span>
									<Countdown
										targetTime={provider.position.nextScanTimestamp}
										urgentThreshold={60}
									/>
								</Row>
								<Row justify="between">
									<span class="text-green-dim text-sm">GHOST STREAK</span>
									<span class="text-amber">{provider.position.ghostStreak} 🔥</span>
								</Row>
							</Stack>
						{:else}
							<Stack gap={3} align="center">
								<p class="text-green-dim text-sm">Not jacked in</p>
								<Button variant="primary" hotkey="J">Jack In</Button>
							</Stack>
						{/if}
					</Box>

					<!-- Modifiers -->
					{#if provider.modifiers.length > 0}
						<Box title="ACTIVE MODIFIERS">
							<Stack gap={2}>
								{#each provider.modifiers as modifier (modifier.id)}
									<Row justify="between">
										<span class="text-sm">✓ {modifier.label}</span>
										{#if modifier.expiresAt}
											<Countdown targetTime={modifier.expiresAt} format="mm:ss" />
										{:else}
											<span class="text-green-dim text-xs">PERMANENT</span>
										{/if}
									</Row>
								{/each}
							</Stack>
						</Box>
					{/if}
				{/if}

				<!-- Quick Actions -->
				<Box title="QUICK ACTIONS">
					<Stack gap={2}>
						<Button variant="secondary" hotkey="J" fullWidth disabled={!provider.currentUser}>
							Jack In More
						</Button>
						<Button variant="danger" hotkey="E" fullWidth disabled={!provider.position}>
							Extract All
						</Button>
						<Button variant="secondary" hotkey="T" fullWidth disabled={!provider.position}>
							Trace Evasion
						</Button>
					</Stack>
				</Box>
			</div>
		</div>
	</div>

	<!-- Footer -->
	<footer class="footer">
		<p class="text-sm text-green-dim">
			Phase 3 Complete - Mock Provider with Live Data
		</p>
	</footer>
</main>

<style>
	.terminal {
		padding: var(--space-4);
		min-height: 100vh;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding-bottom: var(--space-4);
		border-bottom: 1px solid var(--color-green-dim);
		margin-bottom: var(--space-6);
	}

	.logo {
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	.content {
		max-width: 1200px;
		margin: 0 auto;
	}

	.grid-layout {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: var(--space-4);
	}

	@media (max-width: 768px) {
		.grid-layout {
			grid-template-columns: 1fr;
		}
	}

	.left-column,
	.right-column {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	.feed-item {
		padding: var(--space-1) 0;
		border-bottom: 1px solid var(--color-bg-tertiary);
		animation: fade-in-up 0.3s ease-out;
	}

	.feed-item:last-child {
		border-bottom: none;
	}

	.stats-tree {
		padding-left: var(--space-2);
	}

	.footer {
		margin-top: var(--space-8);
		padding-top: var(--space-4);
		border-top: 1px solid var(--color-bg-tertiary);
		text-align: center;
	}

	/* Utility overrides */
	:global(.mb-1) {
		margin-bottom: var(--space-1);
	}

	@keyframes fade-in-up {
		from {
			opacity: 0;
			transform: translateY(-5px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}
</style>
