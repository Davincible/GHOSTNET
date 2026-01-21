<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import type { Duel, DuelHistoryEntry, CreateDuelParams } from '$lib/core/types/duel';
	import {
		formatDuelTier,
		getTierClass,
		calculateDuelWinnings,
		DUEL_TIERS,
	} from '$lib/core/types/duel';
	import { createDuelStore } from '$lib/features/duels';
	import { MOCK_USER_ADDRESS } from '$lib/core/providers/mock/generators/duel';
	import { Shell, Box } from '$lib/ui/terminal';
	import { Button, ProgressBar, Badge } from '$lib/ui/primitives';
	import { AmountDisplay, AddressDisplay } from '$lib/ui/data-display';
	import { Stack, Row } from '$lib/ui/layout';
	import { Modal } from '$lib/ui/modal';

	// ════════════════════════════════════════════════════════════════
	// STORE
	// ════════════════════════════════════════════════════════════════

	const store = createDuelStore();

	// ════════════════════════════════════════════════════════════════
	// LOCAL STATE
	// ════════════════════════════════════════════════════════════════

	let showCreateModal = $state(false);
	let selectedTier = $state<'quick_draw' | 'showdown' | 'high_noon'>('quick_draw');
	let customWager = $state('');
	let targetAddress = $state('');
	let createLoading = $state(false);

	// ════════════════════════════════════════════════════════════════
	// KEYBOARD HANDLING
	// ════════════════════════════════════════════════════════════════

	function handleKeydown(event: KeyboardEvent) {
		if (store.state.status === 'active') {
			event.preventDefault();
			store.handleKey(event.key);
		}
	}

	onMount(() => {
		window.addEventListener('keydown', handleKeydown);
	});

	onDestroy(() => {
		window.removeEventListener('keydown', handleKeydown);
	});

	// ════════════════════════════════════════════════════════════════
	// HANDLERS
	// ════════════════════════════════════════════════════════════════

	async function handleCreateDuel() {
		createLoading = true;
		const tierConfig = DUEL_TIERS[selectedTier];
		const wagerAmount = customWager
			? BigInt(Math.floor(parseFloat(customWager))) * 10n ** 18n
			: tierConfig.minWager;

		const params: CreateDuelParams = {
			wagerAmount,
			targetAddress: targetAddress ? (targetAddress as `0x${string}`) : undefined,
		};

		try {
			await store.createDuel(params);
			showCreateModal = false;
			customWager = '';
			targetAddress = '';
		} finally {
			createLoading = false;
		}
	}

	async function handleAcceptDuel(duel: Duel) {
		await store.acceptDuel(duel);
	}

	function handleCancelDuel(duelId: string) {
		store.cancelDuel(duelId);
	}

	function handleBackToLobby() {
		store.reset();
		store.refreshLobby();
	}

	// ════════════════════════════════════════════════════════════════
	// COMPUTED
	// ════════════════════════════════════════════════════════════════

	const wagerAmount = $derived.by(() => {
		if (customWager) {
			return BigInt(Math.floor(parseFloat(customWager) || 0)) * 10n ** 18n;
		}
		return DUEL_TIERS[selectedTier].minWager;
	});

	const potentialPayout = $derived.by(() => {
		const { payout } = calculateDuelWinnings(wagerAmount);
		return payout;
	});

	// Progress for active duel
	const userProgressPercent = $derived.by(() => {
		if (store.state.status !== 'active') return 0;
		const { yourProgress, duel } = store.state;
		return Math.min(100, (yourProgress.correctChars / duel.challenge.command.length) * 100);
	});

	const userWpm = $derived.by(() => {
		if (store.state.status !== 'active') return 0;
		const { yourProgress } = store.state;
		const elapsed = yourProgress.currentTime - yourProgress.startTime;
		if (elapsed <= 0) return 0;
		return Math.round((yourProgress.correctChars / 5 / elapsed) * 60000);
	});

	const timeRemaining = $derived.by(() => {
		if (store.state.status !== 'active') return 0;
		const { yourProgress, duel } = store.state;
		const elapsed = yourProgress.currentTime - yourProgress.startTime;
		return Math.max(0, duel.challenge.timeLimit * 1000 - elapsed);
	});
</script>

<svelte:head>
	<title>PvP Duels | GHOSTNET</title>
</svelte:head>

<Shell>
	<div class="duels-page">
		<!-- IDLE / LOBBY STATE -->
		{#if store.state.status === 'idle'}
			<div class="lobby">
				<!-- Header with Stats -->
				<Box title="DUEL ARENA">
					<div class="stats-row">
						<div class="stat">
							<span class="stat-label">RECORD</span>
							<span class="stat-value">{store.stats.wins}W - {store.stats.losses}L</span>
						</div>
						<div class="stat">
							<span class="stat-label">WIN RATE</span>
							<span class="stat-value">{Math.round(store.stats.winRate * 100)}%</span>
						</div>
						<div class="stat">
							<span class="stat-label">NET PROFIT</span>
							<span
								class="stat-value"
								class:positive={store.stats.netProfit > 0n}
								class:negative={store.stats.netProfit < 0n}
							>
								<AmountDisplay amount={store.stats.netProfit} symbol="DATA" decimals={0} showSign />
							</span>
						</div>
						<div class="stat">
							<span class="stat-label">BEST WPM</span>
							<span class="stat-value">{store.stats.bestWpm}</span>
						</div>
						<div class="stat">
							<span class="stat-label">STREAK</span>
							<span
								class="stat-value"
								class:positive={store.stats.currentStreak > 0}
								class:negative={store.stats.currentStreak < 0}
							>
								{store.stats.currentStreak > 0 ? '+' : ''}{store.stats.currentStreak}
							</span>
						</div>
					</div>
				</Box>

				<Row gap={4}>
					<!-- Open Challenges -->
					<div class="challenges-section">
						<Box title="OPEN CHALLENGES">
							{#if store.openChallenges.length === 0}
								<p class="empty-message">No open challenges. Create one!</p>
							{:else}
								<div class="challenges-list">
									{#each store.openChallenges as challenge (challenge.id)}
										<div class="challenge-card {getTierClass(challenge.tier)}">
											<div class="challenge-header">
												<Badge variant="default">{formatDuelTier(challenge.tier)}</Badge>
												<span class="challenger-name"
													>{challenge.challengerName ?? 'Anonymous'}</span
												>
											</div>
											<div class="challenge-wager">
												<AmountDisplay amount={challenge.wagerAmount} symbol="DATA" decimals={0} />
											</div>
											<div class="challenge-actions">
												<Button
													variant="primary"
													size="sm"
													onclick={() => handleAcceptDuel(challenge)}
												>
													ACCEPT
												</Button>
											</div>
										</div>
									{/each}
								</div>
							{/if}
						</Box>
					</div>

					<!-- Your Challenges -->
					<div class="your-challenges-section">
						<Box title="YOUR CHALLENGES">
							{#if store.yourChallenges.length === 0}
								<p class="empty-message">No pending challenges.</p>
							{:else}
								<div class="challenges-list">
									{#each store.yourChallenges as challenge (challenge.id)}
										<div class="challenge-card yours {getTierClass(challenge.tier)}">
											<div class="challenge-header">
												<Badge variant="default">{formatDuelTier(challenge.tier)}</Badge>
												<span class="status-text">Waiting for opponent...</span>
											</div>
											<div class="challenge-wager">
												<AmountDisplay amount={challenge.wagerAmount} symbol="DATA" decimals={0} />
											</div>
											<div class="challenge-actions">
												<Button
													variant="ghost"
													size="sm"
													onclick={() => handleCancelDuel(challenge.id)}
												>
													CANCEL
												</Button>
											</div>
										</div>
									{/each}
								</div>
							{/if}

							<div class="create-button-container">
								<Button variant="primary" onclick={() => (showCreateModal = true)}>
									CREATE CHALLENGE
								</Button>
							</div>
						</Box>
					</div>
				</Row>

				<!-- Recent Duels -->
				<Box title="RECENT DUELS">
					{#if store.history.length === 0}
						<p class="empty-message">No duel history yet.</p>
					{:else}
						<div class="history-list">
							{#each store.history.slice(0, 5) as entry (entry.duel.id)}
								<div class="history-row" class:won={entry.youWon} class:lost={!entry.youWon}>
									<span class="result-badge">{entry.youWon ? 'W' : 'L'}</span>
									<span class="opponent"
										>vs {entry.duel.challengerName === 'You'
											? entry.duel.opponentName
											: entry.duel.challengerName}</span
									>
									<Badge variant="default">{formatDuelTier(entry.duel.tier)}</Badge>
									<span
										class="net-amount"
										class:positive={entry.netAmount > 0n}
										class:negative={entry.netAmount < 0n}
									>
										<AmountDisplay amount={entry.netAmount} symbol="DATA" decimals={0} showSign />
									</span>
								</div>
							{/each}
						</div>
					{/if}
				</Box>
			</div>

			<!-- CREATING STATE -->
		{:else if store.state.status === 'creating'}
			<div class="centered-container">
				<Box title="CREATING CHALLENGE">
					<div class="loading-state">
						<div class="spinner"></div>
						<p>Creating duel challenge...</p>
					</div>
				</Box>
			</div>

			<!-- WAITING STATE -->
		{:else if store.state.status === 'waiting'}
			{@const waitingDuel = store.state.duel}
			<div class="centered-container">
				<Box title="WAITING FOR OPPONENT">
					<div class="waiting-state">
						<div class="pulse-ring"></div>
						<div class="wager-display">
							<span class="label">WAGER</span>
							<AmountDisplay amount={waitingDuel.wagerAmount} symbol="DATA" decimals={0} />
						</div>
						<p class="waiting-text">Searching for an opponent...</p>
						<Button variant="ghost" onclick={() => handleCancelDuel(waitingDuel.id)}>
							CANCEL
						</Button>
					</div>
				</Box>
			</div>

			<!-- COUNTDOWN STATE -->
		{:else if store.state.status === 'countdown'}
			<div class="centered-container">
				<Box title="DUEL STARTING">
					<div class="countdown-state">
						<div class="opponent-info">
							<span class="vs">VS</span>
							<span class="opponent-name">{store.state.duel.opponentName}</span>
						</div>
						<div class="countdown-number">{store.state.secondsLeft}</div>
						<p class="countdown-text">Get ready to type!</p>
					</div>
				</Box>
			</div>

			<!-- ACTIVE STATE -->
		{:else if store.state.status === 'active'}
			<div class="active-duel">
				<!-- Progress Header -->
				<div class="duel-header">
					<div class="player-progress you">
						<span class="player-label">YOU</span>
						<ProgressBar value={userProgressPercent} variant="cyan" />
						<span class="wpm">{userWpm} WPM</span>
					</div>
					<div class="vs-divider">
						<span class="time-remaining">{Math.ceil(timeRemaining / 1000)}s</span>
					</div>
					<div class="player-progress opponent">
						<span class="player-label">{store.state.duel.opponentName}</span>
						<ProgressBar value={store.state.opponentProgress} variant="danger" />
						<span class="wpm">--</span>
					</div>
				</div>

				<!-- Typing Area -->
				<Box title="TYPE THE COMMAND">
					<div class="typing-area">
						<div class="command-display">
							{#each store.state.duel.challenge.command.split('') as char, i}
								{@const typed = store.state.yourProgress.typed[i]}
								{@const isTyped = i < store.state.yourProgress.typed.length}
								{@const isCorrect = typed === char}
								{@const isCursor = i === store.state.yourProgress.typed.length}
								<span
									class="char"
									class:correct={isTyped && isCorrect}
									class:incorrect={isTyped && !isCorrect}
									class:cursor={isCursor}>{char}</span
								>
							{/each}
						</div>
						<p class="typing-hint">Focus on this window and start typing...</p>
					</div>
				</Box>

				<!-- Wager Info -->
				<div class="wager-info">
					<span class="label">WAGER:</span>
					<AmountDisplay amount={store.state.duel.wagerAmount} symbol="DATA" decimals={0} />
					<span class="potential">Win: </span>
					<AmountDisplay
						amount={calculateDuelWinnings(store.state.duel.wagerAmount).payout}
						symbol="DATA"
						decimals={0}
					/>
				</div>
			</div>

			<!-- COMPLETE STATE -->
		{:else if store.state.status === 'complete'}
			<div class="centered-container">
				<Box title={store.state.youWon ? 'VICTORY!' : 'DEFEAT'}>
					<div class="result-state" class:won={store.state.youWon} class:lost={!store.state.youWon}>
						<div class="result-icon">{store.state.youWon ? '🏆' : '💀'}</div>
						<div class="result-text">
							{store.state.youWon ? 'You won the duel!' : 'Better luck next time...'}
						</div>

						{#if store.state.youWon}
							<div class="payout-display">
								<span class="label">PAYOUT</span>
								<AmountDisplay amount={store.state.payout} symbol="DATA" decimals={0} />
							</div>
						{:else}
							<div class="loss-display">
								<span class="label">LOST</span>
								<AmountDisplay amount={store.state.duel.wagerAmount} symbol="DATA" decimals={0} />
							</div>
						{/if}

						<!-- Stats Comparison -->
						{#if store.state.duel.results.challenger && store.state.duel.results.opponent}
							{@const isChallenger = store.state.duel.challenger === MOCK_USER_ADDRESS}
							{@const yourResult = isChallenger
								? store.state.duel.results.challenger
								: store.state.duel.results.opponent}
							{@const theirResult = isChallenger
								? store.state.duel.results.opponent
								: store.state.duel.results.challenger}
							<div class="stats-comparison">
								<div class="stat-row">
									<span class="stat-label">WPM</span>
									<span class="your-stat">{yourResult.wpm}</span>
									<span class="vs">vs</span>
									<span class="their-stat">{theirResult.wpm}</span>
								</div>
								<div class="stat-row">
									<span class="stat-label">Accuracy</span>
									<span class="your-stat">{Math.round(yourResult.accuracy * 100)}%</span>
									<span class="vs">vs</span>
									<span class="their-stat">{Math.round(theirResult.accuracy * 100)}%</span>
								</div>
							</div>
						{/if}

						<div class="result-actions">
							<Button variant="primary" onclick={handleBackToLobby}>BACK TO LOBBY</Button>
						</div>
					</div>
				</Box>
			</div>
		{/if}
	</div>

	<!-- Create Duel Modal -->
	<Modal open={showCreateModal} title="CREATE DUEL" onclose={() => (showCreateModal = false)}>
		<Stack gap={4}>
			<div class="tier-selection">
				<span class="section-label">SELECT TIER</span>
				<div class="tier-buttons">
					{#each ['quick_draw', 'showdown', 'high_noon'] as const as tier}
						<button
							type="button"
							class="tier-btn"
							class:active={selectedTier === tier}
							onclick={() => (selectedTier = tier)}
						>
							<span class="tier-name">{formatDuelTier(tier)}</span>
							<span class="tier-range">
								{Number(DUEL_TIERS[tier].minWager / 10n ** 18n)}-{Number(
									DUEL_TIERS[tier].maxWager / 10n ** 18n
								)} DATA
							</span>
						</button>
					{/each}
				</div>
			</div>

			<div class="wager-input">
				<label for="wager">WAGER AMOUNT (optional)</label>
				<input
					id="wager"
					type="number"
					bind:value={customWager}
					placeholder={String(Number(DUEL_TIERS[selectedTier].minWager / 10n ** 18n))}
				/>
			</div>

			<div class="target-input">
				<label for="target">TARGET ADDRESS (optional - leave blank for open challenge)</label>
				<input id="target" type="text" bind:value={targetAddress} placeholder="0x..." />
			</div>

			<div class="payout-preview">
				<span class="label">POTENTIAL WIN:</span>
				<AmountDisplay amount={potentialPayout} symbol="DATA" decimals={0} />
				<span class="rake-note">(5% rake burned)</span>
			</div>
		</Stack>

		{#snippet footer()}
			<Button variant="ghost" onclick={() => (showCreateModal = false)}>CANCEL</Button>
			<Button variant="primary" onclick={handleCreateDuel} loading={createLoading}>
				CREATE DUEL
			</Button>
		{/snippet}
	</Modal>
</Shell>

<style>
	.duels-page {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		padding: var(--space-4);
		min-height: 100%;
	}

	/* ════════════════════════════════════════════════════════════════ */
	/* LOBBY STYLES */
	/* ════════════════════════════════════════════════════════════════ */

	.lobby {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	.stats-row {
		display: flex;
		justify-content: space-between;
		gap: var(--space-4);
		flex-wrap: wrap;
	}

	.stat {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.stat-label {
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-widest);
	}

	.stat-value {
		font-size: var(--text-lg);
		font-weight: var(--font-medium);
		color: var(--color-text-primary);
		font-family: var(--font-mono);
	}

	.stat-value.positive {
		color: var(--color-success);
	}

	.stat-value.negative {
		color: var(--color-danger);
	}

	.challenges-section,
	.your-challenges-section {
		flex: 1;
		min-width: 300px;
	}

	.challenges-list {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.challenge-card {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
	}

	.challenge-card.tier-quick-draw {
		border-left: 3px solid var(--color-accent);
	}

	.challenge-card.tier-showdown {
		border-left: 3px solid var(--color-warning);
	}

	.challenge-card.tier-high-noon {
		border-left: 3px solid var(--color-danger);
	}

	.challenge-header {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.challenger-name {
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
	}

	.status-text {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		font-style: italic;
	}

	.challenge-wager {
		font-family: var(--font-mono);
	}

	.create-button-container {
		margin-top: var(--space-4);
	}

	.empty-message {
		color: var(--color-text-muted);
		font-size: var(--text-sm);
		text-align: center;
		padding: var(--space-4);
	}

	/* History */
	.history-list {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.history-row {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-2);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
	}

	.result-badge {
		width: 24px;
		height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: var(--text-xs);
		font-weight: var(--font-semibold);
		border-radius: 0;
	}

	.history-row.won .result-badge {
		background: var(--color-success);
		color: var(--color-bg-primary);
	}

	.history-row.lost .result-badge {
		background: var(--color-danger);
		color: var(--color-bg-primary);
	}

	.opponent {
		flex: 1;
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
	}

	.net-amount {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
	}

	.net-amount.positive {
		color: var(--color-success);
	}

	.net-amount.negative {
		color: var(--color-danger);
	}

	/* ════════════════════════════════════════════════════════════════ */
	/* CENTERED STATES */
	/* ════════════════════════════════════════════════════════════════ */

	.centered-container {
		display: flex;
		align-items: center;
		justify-content: center;
		flex: 1;
		min-height: 400px;
	}

	.loading-state,
	.waiting-state,
	.countdown-state,
	.result-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-4);
		padding: var(--space-6);
		text-align: center;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 3px solid var(--color-border-subtle);
		border-top-color: var(--color-accent);
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.pulse-ring {
		width: 60px;
		height: 60px;
		border: 2px solid var(--color-accent);
		border-radius: 50%;
		animation: pulse-ring 1.5s ease-out infinite;
	}

	@keyframes pulse-ring {
		0% {
			transform: scale(0.8);
			opacity: 1;
		}
		100% {
			transform: scale(1.5);
			opacity: 0;
		}
	}

	.wager-display,
	.payout-display,
	.loss-display {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.label {
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-widest);
	}

	.waiting-text {
		color: var(--color-text-secondary);
		font-size: var(--text-sm);
	}

	/* Countdown */
	.opponent-info {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.vs {
		font-size: var(--text-sm);
		color: var(--color-text-muted);
	}

	.opponent-name {
		font-size: var(--text-lg);
		font-weight: var(--font-medium);
		color: var(--color-danger);
	}

	.countdown-number {
		font-size: var(--text-4xl);
		font-weight: var(--font-semibold);
		color: var(--color-accent);
		font-family: var(--font-mono);
		animation: countdown-pulse 1s ease-in-out infinite;
	}

	@keyframes countdown-pulse {
		0%,
		100% {
			transform: scale(1);
		}
		50% {
			transform: scale(1.1);
		}
	}

	.countdown-text {
		color: var(--color-text-secondary);
	}

	/* ════════════════════════════════════════════════════════════════ */
	/* ACTIVE DUEL */
	/* ════════════════════════════════════════════════════════════════ */

	.active-duel {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		flex: 1;
	}

	.duel-header {
		display: flex;
		align-items: center;
		gap: var(--space-4);
		padding: var(--space-3);
		background: var(--color-bg-secondary);
		border: 1px solid var(--color-border-subtle);
	}

	.player-progress {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.player-label {
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wider);
	}

	.player-progress.you .player-label {
		color: var(--color-accent);
	}

	.player-progress.opponent .player-label {
		color: var(--color-danger);
	}

	.wpm {
		font-size: var(--text-sm);
		font-family: var(--font-mono);
		color: var(--color-text-secondary);
	}

	.vs-divider {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 0 var(--space-2);
	}

	.time-remaining {
		font-size: var(--text-lg);
		font-weight: var(--font-medium);
		font-family: var(--font-mono);
		color: var(--color-warning);
	}

	.typing-area {
		padding: var(--space-4);
	}

	.command-display {
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		line-height: 1.6;
		word-break: break-all;
		padding: var(--space-4);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
	}

	.char {
		display: inline;
	}

	.char.correct {
		color: var(--color-success);
	}

	.char.incorrect {
		color: var(--color-danger);
		text-decoration: underline;
	}

	.char.cursor {
		background: var(--color-accent);
		color: var(--color-bg-primary);
		animation: blink 1s step-end infinite;
	}

	@keyframes blink {
		50% {
			background: transparent;
			color: inherit;
		}
	}

	.typing-hint {
		margin-top: var(--space-2);
		font-size: var(--text-xs);
		color: var(--color-text-muted);
		text-align: center;
	}

	.wager-info {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-3);
		padding: var(--space-2);
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
	}

	.potential {
		margin-left: var(--space-2);
	}

	/* ════════════════════════════════════════════════════════════════ */
	/* RESULT STATE */
	/* ════════════════════════════════════════════════════════════════ */

	.result-state.won {
		color: var(--color-success);
	}

	.result-state.lost {
		color: var(--color-danger);
	}

	.result-icon {
		font-size: 48px;
	}

	.result-text {
		font-size: var(--text-lg);
		font-weight: var(--font-medium);
	}

	.stats-comparison {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		margin-top: var(--space-4);
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
		width: 100%;
		max-width: 300px;
	}

	.stat-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: var(--space-2);
		font-size: var(--text-sm);
	}

	.stat-row .stat-label {
		color: var(--color-text-muted);
		flex: 1;
	}

	.your-stat {
		color: var(--color-accent);
		font-family: var(--font-mono);
	}

	.stat-row .vs {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
	}

	.their-stat {
		color: var(--color-danger);
		font-family: var(--font-mono);
	}

	.result-actions {
		margin-top: var(--space-4);
	}

	/* ════════════════════════════════════════════════════════════════ */
	/* MODAL STYLES */
	/* ════════════════════════════════════════════════════════════════ */

	.section-label {
		display: block;
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-widest);
		margin-bottom: var(--space-2);
	}

	.tier-buttons {
		display: flex;
		gap: var(--space-2);
	}

	.tier-btn {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-1);
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
		color: var(--color-text-secondary);
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.tier-btn:hover {
		border-color: var(--color-border-default);
		color: var(--color-text-primary);
	}

	.tier-btn.active {
		border-color: var(--color-accent);
		color: var(--color-accent);
	}

	.tier-name {
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
	}

	.tier-range {
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
	}

	.wager-input,
	.target-input {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.wager-input label,
	.target-input label {
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wider);
	}

	.wager-input input,
	.target-input input {
		padding: var(--space-2) var(--space-3);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
		color: var(--color-text-primary);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
	}

	.wager-input input:focus,
	.target-input input:focus {
		outline: none;
		border-color: var(--color-accent);
	}

	.payout-preview {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2);
		background: var(--color-bg-tertiary);
	}

	.rake-note {
		font-size: var(--text-2xs);
		color: var(--color-text-muted);
	}
</style>
