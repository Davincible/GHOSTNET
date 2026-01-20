<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { Stack } from '$lib/ui/layout';

	interface FAQ {
		id: string;
		question: string;
		answer: string;
	}

	const faqs: FAQ[] = [
		// === BASICS ===
		{
			id: 'what-is-ghostnet',
			question: 'What is GHOSTNET?',
			answer: 'A real-time survival game on MegaETH. Stake $DATA tokens, earn yield, survive periodic trace scans. If you get traced, you lose your stake. If you survive, you profit from those who don\'t.'
		},
		{
			id: 'what-is-trace-scan',
			question: 'What is a Trace Scan?',
			answer: 'A periodic RNG death roll. Each level has different scan frequencies: VAULT (never), MAINFRAME (24h), SUBNET (8h), DARKNET (2h), BLACK ICE (30min). Higher risk = higher rewards.'
		},
		{
			id: 'what-happens-traced',
			question: 'What happens if I get traced?',
			answer: 'Your staked tokens are seized and redistributed via The Cascade: 60% to survivors, 30% burned forever, 10% to protocol. When others die, survivors profit.'
		},
		{
			id: 'risk-levels',
			question: 'What are the risk levels?',
			answer: 'VAULT (0% death, safe haven), MAINFRAME (2% death), SUBNET (15% death), DARKNET (40% death), BLACK ICE (90% death). Higher levels = higher yield but more frequent scans.'
		},
		{
			id: 'reduce-death-rate',
			question: 'How do I reduce my death rate?',
			answer: 'Play Trace Evasion (typing game) for up to -35% death reduction. Join a Crew for passive bonuses. Use consumables from the Black Market. More network TVL also reduces rates.'
		},
		{
			id: 'system-reset',
			question: 'What is the System Reset timer?',
			answer: 'A global countdown that resets when anyone deposits. If it hits zero, everyone loses 25% of their stake. Big deposits = longer resets. Last depositor before collapse wins a jackpot.'
		},
		{
			id: 'ghost-streak',
			question: 'What is a Ghost Streak?',
			answer: 'The number of consecutive trace scans you\'ve survived. Higher streaks appear on leaderboards and prove your skill (or luck). Streaks reset if you extract or get traced.'
		},
		{
			id: 'what-is-data',
			question: 'What is $DATA?',
			answer: 'The native token of GHOSTNET. Used for staking, betting, and purchases. Deflationary by design—30% of every death is burned. At scale, more burns than mints.'
		},
		// === ECONOMICS ===
		{
			id: 'cascade-rule',
			question: 'What is The Cascade (60/30/10)?',
			answer: 'When someone is traced, their stake is split: 60% to reward pool (survivors at same level + higher levels), 30% burned permanently, 10% to protocol treasury. Higher levels earn yield from all deaths below them.'
		},
		{
			id: 'burn-mechanics',
			question: 'How does $DATA get burned?',
			answer: '5 burn engines: (1) 30% of every death, (2) $1.80 of every $2 ETH fee via buyback, (3) 9% trading tax, (4) 5% Dead Pool rake, (5) all consumable purchases. At $450k daily volume, burns exceed emissions.'
		},
		{
			id: 'eth-toll',
			question: 'What is the $2 ETH fee?',
			answer: 'Every action (Jack In, Extract, Hack Run, Dead Pool bet) costs $2 in ETH. 90% ($1.80) auto-buys and burns $DATA. 10% ($0.20) covers operations. This creates constant buy pressure.'
		},
		{
			id: 'rug-proof',
			question: 'Can devs rug this?',
			answer: 'No. 100% of liquidity is BURNED (sent to dead address). The LP tokens are permanently locked. We literally cannot withdraw liquidity. Smart contracts are immutable once deployed.'
		},
		{
			id: 'network-modifier',
			question: 'Why does more TVL mean safer?',
			answer: 'Network modifier reduces death rates as TVL grows. <$100k TVL = 1.2x death rate (dangerous). >$1M TVL = 0.85x death rate (15% safer). More players = everyone benefits. Positive-sum growth.'
		},
		// === MINI-GAMES ===
		{
			id: 'hack-runs',
			question: 'What are Hack Runs?',
			answer: 'A 5-node exploration mini-game. Pay entry fee (50-200 $DATA), navigate obstacles with typing challenges, earn yield multipliers (1.5x-3x for 4 hours). Fail = lose entry fee. Perfect run = 3x multiplier.'
		},
		{
			id: 'dead-pool',
			question: 'What is the Dead Pool?',
			answer: 'A prediction market. Bet on network outcomes: death counts, whale movements, survival streaks. Parimutuel odds (winners split loser pool). 5% rake is burned. Use it to hedge your position!'
		},
		{
			id: 'pvp-duels',
			question: 'What are PvP Duels?',
			answer: 'Head-to-head typing races. Both players wager the same amount. Same challenge, first to finish wins. Winner takes 90% of pot, 10% burned. Challenge anyone or accept open challenges.'
		},
		// === SOCIAL ===
		{
			id: 'crews',
			question: 'What are Crews?',
			answer: 'Teams of up to 50 players with shared bonuses. Active bonuses include: "Safety in Numbers" (-5% death when 10+ online), "Whale Shield" (-10% when crew TVL >10k), "Ghost Collective" (+5% yield with streaks).'
		},
		{
			id: 'culling',
			question: 'What is The Culling?',
			answer: 'When a level is at max capacity and someone new jacks in, the lowest-staked position in the bottom 50% gets randomly eliminated. They lose 80% (redistributed) but get 20% severance. Stake big or get culled.'
		}
	];

	// Track which FAQ is expanded
	let expandedId = $state<string | null>(null);

	function toggleFaq(id: string) {
		expandedId = expandedId === id ? null : id;
	}

	function handleKeydown(event: KeyboardEvent, id: string) {
		if (event.key === 'Enter' || event.key === ' ') {
			event.preventDefault();
			toggleFaq(id);
		}
	}
</script>

<Box title="FAQ">
	<Stack gap={1}>
		{#each faqs as faq (faq.id)}
			<div class="faq-item" class:expanded={expandedId === faq.id}>
				<button
					class="faq-question"
					onclick={() => toggleFaq(faq.id)}
					onkeydown={(e) => handleKeydown(e, faq.id)}
					aria-expanded={expandedId === faq.id}
					aria-controls="faq-answer-{faq.id}"
				>
					<span class="faq-icon">{expandedId === faq.id ? '[-]' : '[+]'}</span>
					<span class="faq-text">{faq.question}</span>
				</button>
				{#if expandedId === faq.id}
					<div 
						class="faq-answer" 
						id="faq-answer-{faq.id}"
						role="region"
						aria-labelledby="faq-{faq.id}"
					>
						{faq.answer}
					</div>
				{/if}
			</div>
		{/each}
	</Stack>
</Box>

<style>
	.faq-item {
		border: 1px solid var(--color-border-subtle);
		background: var(--color-bg-tertiary);
		transition: all var(--duration-fast) var(--ease-default);
	}

	.faq-item:hover {
		border-color: var(--color-border-default);
	}

	.faq-item.expanded {
		border-color: var(--color-accent-dim);
	}

	.faq-question {
		width: 100%;
		display: flex;
		align-items: flex-start;
		gap: var(--space-2);
		padding: var(--space-2);
		background: transparent;
		border: none;
		cursor: pointer;
		text-align: left;
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
		transition: color var(--duration-fast);
	}

	.faq-question:hover {
		color: var(--color-text-primary);
	}

	.faq-question:focus-visible {
		outline: 2px solid var(--color-accent);
		outline-offset: -2px;
	}

	.faq-icon {
		color: var(--color-accent);
		font-weight: var(--font-medium);
		flex-shrink: 0;
	}

	.faq-text {
		flex: 1;
		line-height: 1.4;
	}

	.expanded .faq-text {
		color: var(--color-accent);
	}

	.faq-answer {
		padding: var(--space-2) var(--space-2) var(--space-3);
		padding-left: calc(var(--space-2) + 2.5ch + var(--space-2));
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		line-height: 1.6;
		border-top: 1px solid var(--color-border-subtle);
		background: var(--color-bg-secondary);
		animation: faq-expand 0.15s ease-out;
	}

	@keyframes faq-expand {
		from {
			opacity: 0;
			transform: translateY(-4px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	/* Compact on mobile */
	@media (max-width: 640px) {
		.faq-question {
			font-size: var(--text-2xs);
			padding: var(--space-1-5);
		}

		.faq-answer {
			font-size: var(--text-2xs);
			padding: var(--space-1-5);
			padding-left: calc(var(--space-1-5) + 2.5ch + var(--space-1-5));
		}
	}
</style>
