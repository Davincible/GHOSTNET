<script lang="ts">
	import { goto } from '$app/navigation';
	import { NavigationBar } from '$lib/features/nav';
	import { Header, Breadcrumb } from '$lib/features/header';
	import { Box, Shell } from '$lib/ui/terminal';
	import { Stack, Row } from '$lib/ui/layout';
	import { Button } from '$lib/ui/primitives';

	// Help sections with content
	interface HelpSection {
		id: string;
		title: string;
		icon: string;
		content: HelpItem[];
	}

	interface HelpItem {
		question: string;
		answer: string;
		tip?: string;
	}

	const sections: HelpSection[] = [
		{
			id: 'getting-started',
			title: 'GETTING STARTED',
			icon: '>',
			content: [
				{
					question: 'What is GHOSTNET?',
					answer:
						'GHOSTNET is a real-time survival game on MegaETH. You "jack in" by staking $DATA tokens at your chosen risk level, earn yield every second, and try to survive periodic "trace scans" that can wipe your position. When others get traced, survivors profit.',
					tip: 'Start with MAINFRAME (2% death rate) to learn the mechanics safely.',
				},
				{
					question: 'How do I start playing?',
					answer:
						'1. Connect your wallet\n2. Get some $DATA tokens\n3. Click "JACK IN" and choose your risk level\n4. Choose how much $DATA to stake\n5. Survive trace scans and watch your yield grow\n6. Extract anytime to claim your gains',
				},
				{
					question: 'What happens during a Trace Scan?',
					answer:
						'At each level\'s scan interval, an RNG death roll occurs. If the roll hits your death probability, you get "traced" and lose your stake. The seized tokens are redistributed: 60% to survivors, 30% burned, 10% to protocol.',
					tip: 'Play Trace Evasion before scans to reduce your death rate by up to 35%!',
				},
			],
		},
		{
			id: 'security-levels',
			title: 'SECURITY LEVELS',
			icon: '#',
			content: [
				{
					question: 'What are the risk levels?',
					answer:
						'VAULT: 0% death, safe haven (no yield from deaths)\nMAINFRAME: 2% death every 24h (beginner-friendly)\nSUBNET: 15% death every 8h (moderate risk)\nDARKNET: 40% death every 2h (high risk, high reward)\nBLACK ICE: 90% death every 30min (extreme risk)',
				},
				{
					question: 'How do I choose the right level?',
					answer:
						'Consider your risk tolerance and time commitment. MAINFRAME is great for passive play. SUBNET balances risk/reward for active players. DARKNET and BLACK ICE are for thrill-seekers who can monitor their position and play mini-games to reduce death rates.',
					tip: 'Higher levels earn yield from ALL deaths below them, not just their own level.',
				},
				{
					question: 'Can I change levels?',
					answer:
						"Yes! Extract your position first, then Jack In at a different level. There's no cooldown for changing levels, but you'll need to go through the Jack In process again.",
				},
			],
		},
		{
			id: 'mini-games',
			title: 'MINI-GAMES',
			icon: '*',
			content: [
				{
					question: 'What is Trace Evasion?',
					answer:
						'A typing challenge where you type displayed text as fast and accurately as possible. Better performance = lower death rate in your next trace scan.\n\nTiers:\n- AMATEUR: <60 WPM = -5% death rate\n- OPERATOR: 60-80 WPM = -15% death rate\n- ELITE: 80-100 WPM = -25% death rate\n- GHOST: >100 WPM = -35% death rate',
					tip: 'You can play Trace Evasion once per scan period. The reduction lasts until your next scan.',
				},
				{
					question: 'What are Hack Runs?',
					answer:
						'A 5-node exploration mini-game. Pay an entry fee (50-200 $DATA), navigate through obstacles with typing challenges at each node, and earn yield multipliers.\n\nComplete the run = 1.5x-3x yield multiplier for 4 hours\nFail = lose your entry fee\n\nNode types include Firewalls, Patrols, Data Caches, Traps, and Backdoors (risky shortcuts).',
				},
				{
					question: 'What is the Dead Pool?',
					answer:
						'A prediction market where you bet on network outcomes:\n- Death counts in specific levels\n- Whale movements (big stakes entering)\n- Survival streaks achieved\n- System reset timer events\n\nPayouts are parimutuel (winners split loser pool minus 5% rake). Use it to hedge your position!',
				},
			],
		},
		{
			id: 'crews',
			title: 'CREWS',
			icon: '@',
			content: [
				{
					question: 'What are Crews?',
					answer:
						'Teams of up to 50 players who share bonuses. Join a crew or create your own to unlock passive advantages that stack with your individual performance.',
				},
				{
					question: 'What bonuses do Crews provide?',
					answer:
						'Active bonuses include:\n- SAFETY IN NUMBERS: -5% death rate when 10+ members online\n- WHALE SHIELD: -10% death rate when crew TVL >10k $DATA\n- GHOST COLLECTIVE: +5% yield when avg streak >5\n- RAID BONUS: +10% yield when crew completes 20+ Hack Runs/day',
					tip: 'Crew bonuses stack with your individual death reduction from Trace Evasion!',
				},
				{
					question: 'How do I join or create a Crew?',
					answer:
						'Navigate to CREW in the menu. You can browse open crews and request to join, or create your own crew with a custom name and invite others. Each player can only be in one crew at a time.',
				},
			],
		},
		{
			id: 'tokenomics',
			title: 'TOKENOMICS',
			icon: '$',
			content: [
				{
					question: 'What is $DATA?',
					answer:
						'The native token of GHOSTNET. Used for staking, betting, and purchases. Deflationary by design: more tokens are burned than minted at scale.',
				},
				{
					question: 'How does burning work?',
					answer:
						'5 burn engines:\n1. 30% of every traced position\n2. $1.80 of every $2 ETH fee (buyback & burn)\n3. 9% trading tax\n4. 5% Dead Pool rake\n5. All consumable purchases\n\nAt $450k daily volume, burns exceed emissions.',
				},
				{
					question: 'What is The Cascade (60/30/10)?',
					answer:
						'When someone gets traced:\n- 60% goes to reward pool (survivors)\n- 30% is burned permanently\n- 10% goes to protocol treasury\n\nHigher levels earn rewards from ALL deaths below them, creating an incentive to stake bigger.',
				},
				{
					question: 'Is this rug-proof?',
					answer:
						'Yes. 100% of liquidity is BURNED (sent to dead address). LP tokens are permanently locked. The team cannot withdraw liquidity. Smart contracts are immutable once deployed.',
				},
			],
		},
		{
			id: 'advanced',
			title: 'ADVANCED MECHANICS',
			icon: '!',
			content: [
				{
					question: 'What is the System Reset timer?',
					answer:
						'A global countdown that resets when anyone deposits. If it hits zero, everyone loses 25% of their stake. Big deposits = longer timer extensions. The last depositor before collapse wins a jackpot from the seized 25%.',
					tip: "Watch the timer! If it's getting low, either deposit to extend it or be ready to extract.",
				},
				{
					question: 'What is The Culling?',
					answer:
						'When a level reaches max capacity and someone new jacks in, the lowest-staked position in the bottom 50% gets randomly eliminated.\n\nThe culled player:\n- Loses 80% (redistributed to level)\n- Gets 20% severance (returned)\n\nStake big or get culled.',
				},
				{
					question: 'What is a Ghost Streak?',
					answer:
						"The number of consecutive trace scans you've survived. Higher streaks:\n- Appear on leaderboards\n- Prove your skill (or luck)\n- Contribute to crew bonuses\n\nStreaks reset if you extract or get traced.",
				},
				{
					question: 'How does the Network Modifier work?',
					answer:
						'Death rates scale with network TVL:\n- <$100k TVL = 1.2x death rate (20% more dangerous)\n- $100k-$500k = 1.0x (baseline)\n- $500k-$1M = 0.9x (10% safer)\n- >$1M TVL = 0.85x (15% safer)\n\nMore players = everyone benefits.',
				},
			],
		},
		{
			id: 'keyboard',
			title: 'KEYBOARD SHORTCUTS',
			icon: '~',
			content: [
				{
					question: 'What shortcuts are available?',
					answer:
						'All shortcuts require SHIFT + key:\n\nSHIFT + J = Jack In\nSHIFT + E = Extract\nSHIFT + T = Trace Evasion\nSHIFT + H = Hack Run\nSHIFT + C = Crew\nSHIFT + P = Dead Pool',
					tip: 'Keyboard shortcuts work from any page. Quick access when you need to act fast!',
				},
			],
		},
	];

	// Track active section
	let activeSection = $state<string>('getting-started');
	let expandedItems = $state<Set<string>>(new Set());

	function toggleItem(sectionId: string, index: number) {
		const key = `${sectionId}-${index}`;
		const newExpanded = new Set(expandedItems);
		if (newExpanded.has(key)) {
			newExpanded.delete(key);
		} else {
			newExpanded.add(key);
		}
		expandedItems = newExpanded;
	}

	function isExpanded(sectionId: string, index: number): boolean {
		return expandedItems.has(`${sectionId}-${index}`);
	}

	// Find current section
	let currentSection = $derived(sections.find((s) => s.id === activeSection) ?? sections[0]);
</script>

<svelte:head>
	<title>GHOSTNET - Help & Documentation</title>
	<meta
		name="description"
		content="Learn how to play GHOSTNET. Game mechanics, mini-games, crews, and tokenomics explained."
	/>
</svelte:head>

<Header />
<Breadcrumb path={[{ label: 'NETWORK', href: '/' }, { label: 'HELP' }]} />

<Shell>
	<div class="help-page">
		<header class="help-header">
			<h1 class="help-title">SYSTEM DOCUMENTATION</h1>
			<p class="help-subtitle">GHOSTNET v1.0.7 // OPERATOR MANUAL</p>
		</header>

		<div class="help-layout">
			<!-- Section Navigation -->
			<nav class="help-nav" aria-label="Help sections">
				<div class="nav-items">
					{#each sections as section (section.id)}
						<button
							type="button"
							class="nav-item"
							class:active={activeSection === section.id}
							onclick={() => (activeSection = section.id)}
							aria-current={activeSection === section.id ? 'page' : undefined}
						>
							<span class="nav-icon">{section.icon}</span>
							<span class="nav-label">{section.title}</span>
						</button>
					{/each}
				</div>
			</nav>

			<!-- Content Area -->
			<main class="help-content">
				<Box title={currentSection.title}>
					<Stack gap={2}>
						{#each currentSection.content as item, index (index)}
							{@const panelId = `panel-${currentSection.id}-${index}`}
							<div class="help-item" class:expanded={isExpanded(currentSection.id, index)}>
								<button
									type="button"
									class="item-header"
									onclick={() => toggleItem(currentSection.id, index)}
									aria-expanded={isExpanded(currentSection.id, index)}
									aria-controls={panelId}
								>
									<span class="item-icon"
										>{isExpanded(currentSection.id, index) ? '[-]' : '[+]'}</span
									>
									<span class="item-question">{item.question}</span>
								</button>
								{#if isExpanded(currentSection.id, index)}
									<div class="item-body" id={panelId} role="region">
										<p class="item-answer">{item.answer}</p>
										{#if item.tip}
											<div class="item-tip">
												<span class="tip-label">TIP:</span>
												{item.tip}
											</div>
										{/if}
									</div>
								{/if}
							</div>
						{/each}
					</Stack>
				</Box>

				<!-- Quick Links -->
				<div class="quick-links">
					<p class="links-label">QUICK ACTIONS</p>
					<Row gap={2} wrap>
						<Button variant="ghost" onclick={() => goto('/')}>COMMAND CENTER</Button>
						<Button variant="ghost" onclick={() => goto('/typing')}>TRACE EVASION</Button>
						<Button variant="ghost" onclick={() => goto('/games/hackrun')}>HACK RUNS</Button>
						<Button variant="ghost" onclick={() => goto('/market')}>DEAD POOL</Button>
						<Button variant="ghost" onclick={() => goto('/crew')}>CREWS</Button>
					</Row>
				</div>
			</main>
		</div>
	</div>
</Shell>
<NavigationBar active="help" />

<style>
	.help-page {
		max-width: 1000px;
		margin: 0 auto;
		padding: var(--space-4);
		padding-bottom: var(--space-16);
	}

	.help-header {
		text-align: center;
		margin-bottom: var(--space-6);
		padding-bottom: var(--space-4);
		border-bottom: 1px solid var(--color-border-subtle);
	}

	.help-title {
		font-family: var(--font-mono);
		font-size: var(--text-2xl);
		font-weight: var(--font-semibold);
		color: var(--color-accent);
		letter-spacing: var(--tracking-wider);
		margin: 0 0 var(--space-2);
	}

	.help-subtitle {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wide);
		margin: 0;
	}

	.help-layout {
		display: grid;
		grid-template-columns: 220px 1fr;
		gap: var(--space-6);
	}

	/* Navigation */
	.help-nav {
		position: sticky;
		top: var(--space-4);
		height: fit-content;
	}

	.nav-items {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.nav-item {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		width: 100%;
		padding: var(--space-2) var(--space-3);
		background: transparent;
		border: 1px solid transparent;
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		text-align: left;
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.nav-item:hover {
		color: var(--color-text-secondary);
		border-color: var(--color-border-default);
	}

	.nav-item.active {
		color: var(--color-accent);
		border-color: var(--color-accent-dim);
		background: var(--color-accent-glow);
	}

	.nav-icon {
		font-weight: var(--font-medium);
		opacity: 0.6;
	}

	.nav-item.active .nav-icon {
		opacity: 1;
	}

	.nav-label {
		letter-spacing: var(--tracking-wide);
	}

	/* Content */
	.help-content {
		min-width: 0;
	}

	.help-item {
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-subtle);
		transition: border-color var(--duration-fast);
	}

	.help-item:hover {
		border-color: var(--color-border-default);
	}

	.help-item.expanded {
		border-color: var(--color-accent-dim);
	}

	.item-header {
		display: flex;
		align-items: flex-start;
		gap: var(--space-2);
		width: 100%;
		padding: var(--space-3);
		background: transparent;
		border: none;
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		text-align: left;
		cursor: pointer;
		transition: color var(--duration-fast);
	}

	.item-header:hover {
		color: var(--color-text-primary);
	}

	.item-header:focus-visible {
		outline: 2px solid var(--color-accent);
		outline-offset: -2px;
	}

	.item-icon {
		color: var(--color-accent);
		font-weight: var(--font-medium);
		flex-shrink: 0;
	}

	.item-question {
		flex: 1;
		line-height: 1.4;
	}

	.expanded .item-question {
		color: var(--color-accent);
	}

	.item-body {
		padding: 0 var(--space-3) var(--space-3);
		padding-left: calc(var(--space-3) + 2.5ch + var(--space-2));
		border-top: 1px solid var(--color-border-subtle);
		background: var(--color-bg-secondary);
		animation: expand var(--duration-fast) ease-out;
	}

	@keyframes expand {
		from {
			opacity: 0;
			transform: translateY(-4px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.item-answer {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		line-height: 1.8;
		white-space: pre-line;
		margin: var(--space-3) 0 0;
	}

	.item-tip {
		margin-top: var(--space-3);
		padding: var(--space-2);
		background: var(--color-accent-glow);
		border-left: 2px solid var(--color-accent);
		font-size: var(--text-xs);
		color: var(--color-text-secondary);
		line-height: 1.6;
	}

	.tip-label {
		color: var(--color-accent);
		font-weight: var(--font-medium);
		margin-right: var(--space-1);
	}

	/* Quick Links */
	.quick-links {
		margin-top: var(--space-6);
		padding-top: var(--space-4);
		border-top: 1px solid var(--color-border-subtle);
	}

	.links-label {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
		margin: 0 0 var(--space-3);
	}

	/* Responsive: Stack on mobile */
	@media (max-width: 767px) {
		.help-page {
			padding: var(--space-2);
		}

		.help-layout {
			grid-template-columns: 1fr;
			gap: var(--space-4);
		}

		.help-nav {
			position: static;
			overflow-x: auto;
			padding-bottom: var(--space-2);
			margin-bottom: var(--space-2);
			border-bottom: 1px solid var(--color-border-subtle);
		}

		.nav-items {
			flex-direction: row;
			gap: var(--space-1);
		}

		.nav-item {
			flex-shrink: 0;
			padding: var(--space-1-5) var(--space-2);
			font-size: var(--text-2xs);
		}

		.nav-label {
			display: none;
		}

		.nav-icon {
			font-size: var(--text-sm);
		}

		.item-header {
			padding: var(--space-2);
			font-size: var(--text-xs);
		}

		.item-body {
			padding: 0 var(--space-2) var(--space-2);
			padding-left: calc(var(--space-2) + 2.5ch + var(--space-2));
		}

		.item-answer {
			font-size: var(--text-2xs);
		}

		.item-tip {
			font-size: var(--text-2xs);
		}

		.quick-links {
			margin-top: var(--space-4);
		}
	}
</style>
