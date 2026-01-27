<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { Box } from '$lib/ui/terminal';

	const games = [
		{ name: 'TRACE EVASION', icon: '>_', href: '/typing', desc: 'Type to survive' },
		{ name: 'HACK RUN', icon: '</>', href: '/games/hackrun', desc: 'Hack for yield' },
		{ name: 'PVP DUELS', icon: '⚔', href: '/games/duels', desc: '1v1 battles' },
		{ name: 'HASH CRASH', icon: '↗', href: '/arcade/hash-crash', desc: 'Crash game' },
		{ name: 'DEAD POOL', icon: '💀', href: '/market', desc: 'Bet on outcomes' },
		{ name: 'DAILY OPS', icon: '☰', href: '/arcade/daily-ops', desc: 'Daily missions' },
	];

	function navigate(href: string) {
		// eslint-disable-next-line @typescript-eslint/no-explicit-any -- resolve() expects route union literals; dynamic hrefs require cast
		goto((resolve as any)(href));
	}
</script>

<Box title="ARCADE" borderColor="cyan">
	<div class="game-grid">
		{#each games as game (game.name)}
			<button class="game-tile" onclick={() => navigate(game.href)}>
				<span class="game-icon">{game.icon}</span>
				<div class="game-info">
					<span class="game-name">{game.name}</span>
					<span class="game-desc">{game.desc}</span>
				</div>
				<span class="game-arrow">→</span>
			</button>
		{/each}
	</div>
	<div class="arcade-link">
		<button class="view-all-btn" onclick={() => navigate('/arcade')}>
			VIEW ALL →
		</button>
	</div>
</Box>

<style>
	.game-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: var(--space-2, 0.5rem);
	}

	.game-tile {
		display: flex;
		align-items: center;
		gap: var(--space-2, 0.5rem);
		padding: var(--space-2, 0.5rem) var(--space-3, 0.75rem);
		background: rgba(0, 229, 204, 0.03);
		border: 1px solid var(--color-border-default, #333);
		border-left: 3px solid var(--color-accent-dim, rgba(0, 229, 204, 0.3));
		cursor: pointer;
		transition: all 0.15s;
		text-align: left;
		font-family: var(--font-mono, monospace);
	}

	.game-tile:hover {
		border-color: var(--color-accent, #00e5cc);
		border-left-color: var(--color-accent, #00e5cc);
		background: rgba(0, 229, 204, 0.06);
		box-shadow: 0 0 10px rgba(0, 229, 204, 0.1);
	}

	.game-icon {
		font-size: var(--text-sm, 0.875rem);
		color: var(--color-accent, #00e5cc);
		min-width: 2.5ch;
		text-align: center;
		text-shadow: 0 0 8px rgba(0, 229, 204, 0.4);
	}

	.game-info {
		display: flex;
		flex-direction: column;
		gap: 1px;
		flex: 1;
		min-width: 0;
	}

	.game-name {
		font-size: var(--text-xs, 0.75rem);
		font-weight: 700;
		color: var(--color-text-primary, #e0e0e0);
		letter-spacing: 0.05em;
	}

	.game-desc {
		font-size: 0.625rem;
		color: var(--color-text-tertiary, #555);
	}

	.game-arrow {
		color: var(--color-text-muted, #444);
		font-size: var(--text-xs, 0.75rem);
		transition: color 0.15s;
	}

	.game-tile:hover .game-arrow {
		color: var(--color-accent, #00e5cc);
	}

	.arcade-link {
		margin-top: var(--space-3, 0.75rem);
		padding-top: var(--space-2, 0.5rem);
		border-top: 1px solid var(--color-border-subtle, #1a1a1a);
		text-align: center;
	}

	.view-all-btn {
		background: none;
		border: none;
		color: var(--color-accent, #00e5cc);
		font-family: var(--font-mono, monospace);
		font-size: var(--text-xs, 0.75rem);
		letter-spacing: 0.1em;
		cursor: pointer;
		padding: var(--space-1, 0.25rem) var(--space-3, 0.75rem);
		transition: all 0.15s;
	}

	.view-all-btn:hover {
		text-shadow: 0 0 10px rgba(0, 229, 204, 0.5);
	}

	@media (max-width: 640px) {
		.game-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
