<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { Header, Breadcrumb } from '$lib/features/header';
	import { NavigationBar } from '$lib/features/nav';
	import { Box } from '$lib/ui/terminal';

	interface GameCard {
		icon: string;
		name: string;
		description: string;
		href: string;
	}

	const miniGames: GameCard[] = [
		{
			icon: '>_',
			name: 'Trace Evasion',
			description: 'Type fast to reduce your death rate by up to -35%',
			href: '/typing',
		},
		{
			icon: '</>',
			name: 'Hack Run',
			description: 'Complete hack runs for yield multipliers up to 3x',
			href: '/games/hackrun',
		},
		{
			icon: '⚔',
			name: 'PvP Duels',
			description: '1v1 typing battles. Winner takes the pot',
			href: '/games/duels',
		},
	];

	const arcadeGames: GameCard[] = [
		{
			icon: '↗',
			name: 'Hash Crash',
			description: 'Bet on the multiplier. Cash out before it crashes',
			href: '/arcade/hash-crash',
		},
		{
			icon: '☰',
			name: 'Daily Ops',
			description: 'Daily check-ins, missions, and streak rewards',
			href: '/arcade/daily-ops',
		},
	];

	const marketItems: GameCard[] = [
		{
			icon: '💀',
			name: 'Dead Pool',
			description: 'Bet on who lives and who dies',
			href: '/market',
		},
		{
			icon: '$',
			name: 'Black Market',
			description: 'Trade items and power-ups',
			href: '/market',
		},
	];

	function navigate(href: string) {
		// eslint-disable-next-line @typescript-eslint/no-explicit-any -- resolve() expects route union literals; dynamic hrefs require cast
		goto((resolve as any)(href));
	}
</script>

<svelte:head>
	<title>GHOSTNET Arcade</title>
	<meta name="description" content="Games, missions, and markets on GHOSTNET." />
</svelte:head>

<div class="arcade-page">
	<Header />
	<Breadcrumb path={[{ label: 'NETWORK', href: '/' }, { label: 'ARCADE' }]} />

	<main class="arcade-content">
		<Box title="Mini-Games" borderColor="cyan">
			<p class="section-subtitle">Games that affect your survival</p>
			<div class="card-grid">
				{#each miniGames as game (game.name)}
					<button class="game-card" onclick={() => navigate(game.href)}>
						<span class="game-icon">{game.icon}</span>
						<div class="game-info">
							<span class="game-name">{game.name}</span>
							<span class="game-desc">{game.description}</span>
						</div>
					</button>
				{/each}
			</div>
		</Box>

		<Box title="Arcade" borderColor="cyan">
			<p class="section-subtitle">Standalone games</p>
			<div class="card-grid">
				{#each arcadeGames as game (game.name)}
					<button class="game-card" onclick={() => navigate(game.href)}>
						<span class="game-icon">{game.icon}</span>
						<div class="game-info">
							<span class="game-name">{game.name}</span>
							<span class="game-desc">{game.description}</span>
						</div>
					</button>
				{/each}
			</div>
		</Box>

		<Box title="Markets" borderColor="cyan">
			<div class="card-grid">
				{#each marketItems as game (game.name)}
					<button class="game-card" onclick={() => navigate(game.href)}>
						<span class="game-icon">{game.icon}</span>
						<div class="game-info">
							<span class="game-name">{game.name}</span>
							<span class="game-desc">{game.description}</span>
						</div>
					</button>
				{/each}
			</div>
		</Box>
	</main>

	<NavigationBar active="arcade" />
</div>

<style>
	.arcade-page {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
		padding-bottom: var(--space-16);
	}

	.arcade-content {
		flex: 1;
		padding: var(--space-4) var(--space-6);
		width: 100%;
		max-width: 1000px;
		margin: 0 auto;
		display: flex;
		flex-direction: column;
		gap: var(--space-6);
	}

	/* ════════════════════════════════════════════════════════════════
	   SECTION SUBTITLE
	   ════════════════════════════════════════════════════════════════ */

	.section-subtitle {
		margin: 0 0 var(--space-3) 0;
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
		text-transform: uppercase;
	}

	/* ════════════════════════════════════════════════════════════════
	   CARD GRID — responsive columns
	   ════════════════════════════════════════════════════════════════ */

	.card-grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: var(--space-3);
	}

	@media (min-width: 600px) {
		.card-grid {
			grid-template-columns: repeat(2, 1fr);
		}
	}

	@media (min-width: 900px) {
		.card-grid {
			grid-template-columns: repeat(3, 1fr);
		}
	}

	/* ════════════════════════════════════════════════════════════════
	   GAME CARD — terminal aesthetic, left accent border
	   ════════════════════════════════════════════════════════════════ */

	.game-card {
		display: flex;
		align-items: flex-start;
		gap: var(--space-3);
		padding: var(--space-3) var(--space-4);
		background: var(--color-bg-tertiary);
		border: var(--border-width) solid var(--color-border-subtle);
		border-left: 3px solid var(--color-accent-dim);
		cursor: pointer;
		text-align: left;
		font-family: var(--font-mono);
		transition: all var(--duration-fast) var(--ease-default);
	}

	.game-card:hover {
		border-left-color: var(--color-accent);
		background: var(--color-bg-secondary);
		box-shadow: inset 0 0 12px var(--color-accent-glow);
	}

	.game-card:focus-visible {
		outline: 2px solid var(--color-accent);
		outline-offset: 2px;
	}

	/* ════════════════════════════════════════════════════════════════
	   CARD INTERNALS
	   ════════════════════════════════════════════════════════════════ */

	.game-icon {
		flex-shrink: 0;
		width: 2.5em;
		height: 2.5em;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: var(--text-base);
		font-weight: var(--font-bold);
		color: var(--color-accent);
		border: var(--border-width) solid var(--color-border-default);
		background: var(--color-bg-primary);
	}

	.game-info {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		min-width: 0;
	}

	.game-name {
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wide);
	}

	.game-desc {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		line-height: var(--leading-relaxed);
	}

	/* ════════════════════════════════════════════════════════════════
	   MOBILE
	   ════════════════════════════════════════════════════════════════ */

	@media (max-width: 767px) {
		.arcade-content {
			padding: var(--space-2);
		}
	}
</style>
