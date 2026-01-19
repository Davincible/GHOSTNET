<script lang="ts">
	import { Button } from '$lib/ui/primitives';
	import { Row } from '$lib/ui/layout';

	interface NavItem {
		id: string;
		label: string;
		href?: string;
		disabled?: boolean;
	}

	interface Props {
		/** Currently active nav item id */
		active?: string;
		/** Callback when nav item is clicked */
		onNavigate?: (id: string) => void;
	}

	let { active = 'network', onNavigate }: Props = $props();

	const navItems: NavItem[] = [
		{ id: 'network', label: 'NETWORK' },
		{ id: 'position', label: 'POSITION' },
		{ id: 'games', label: 'GAMES' },
		{ id: 'crew', label: 'CREW' },
		{ id: 'market', label: 'MARKET' },
		{ id: 'leaderboard', label: 'RANKS' },
		{ id: 'help', label: '?' }
	];

	function handleClick(id: string) {
		onNavigate?.(id);
	}
</script>

<nav class="nav-bar" aria-label="Main navigation">
	<Row gap={1} justify="center" wrap>
		{#each navItems as item (item.id)}
			<button
				type="button"
				class="nav-item"
				class:nav-item-active={active === item.id}
				disabled={item.disabled}
				onclick={() => handleClick(item.id)}
				aria-current={active === item.id ? 'page' : undefined}
			>
				{item.label}
			</button>
		{/each}
	</Row>
</nav>

<style>
	.nav-bar {
		padding: var(--space-3) var(--space-4);
		background: var(--color-bg-secondary);
		border-top: var(--border-width) solid var(--color-green-dim);
	}

	.nav-item {
		padding: var(--space-2) var(--space-3);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wide);
		color: var(--color-green-mid);
		background: transparent;
		border: var(--border-width) solid transparent;
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.nav-item:hover:not(:disabled) {
		color: var(--color-green-bright);
		border-color: var(--color-green-dim);
	}

	.nav-item:focus-visible {
		outline: 2px solid var(--color-cyan);
		outline-offset: 2px;
	}

	.nav-item:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.nav-item-active {
		color: var(--color-green-bright);
		border-color: var(--color-green-bright);
		background: var(--color-green-glow);
	}

	.nav-item-active:hover {
		border-color: var(--color-green-bright);
	}

	/* Responsive */
	@media (max-width: 640px) {
		.nav-item {
			padding: var(--space-1) var(--space-2);
			font-size: var(--text-xs);
		}
	}
</style>
