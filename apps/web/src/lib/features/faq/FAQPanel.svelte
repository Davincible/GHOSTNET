<script lang="ts">
	import { Box } from '$lib/ui/terminal';
	import { Stack } from '$lib/ui/layout';

	interface FAQ {
		id: string;
		question: string;
		answer: string;
	}

	const faqs: FAQ[] = [
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
