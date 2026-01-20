<script lang="ts">
	import { Button } from '$lib/ui/primitives';
	import { Row } from '$lib/ui/layout';

	interface NavItem {
		id: string;
		label: string;
		href?: string;
		disabled?: boolean;
		comingSoon?: boolean;
	}

	interface Props {
		/** Currently active nav item id */
		active?: string;
		/** Callback when nav item is clicked */
		onNavigate?: (id: string) => void;
	}

	let { active = 'network', onNavigate }: Props = $props();

	let showComingSoon = $state(false);
	let comingSoonFeature = $state('');

	const navItems: NavItem[] = [
		{ id: 'network', label: 'NETWORK' },
		{ id: 'position', label: 'POSITION' },
		{ id: 'games', label: 'GAMES' },
		{ id: 'crew', label: 'CREW', comingSoon: true },
		{ id: 'market', label: 'MARKET', comingSoon: true },
		{ id: 'leaderboard', label: 'RANKS', comingSoon: true },
		{ id: 'help', label: '?' }
	];

	function handleClick(item: NavItem) {
		if (item.comingSoon) {
			comingSoonFeature = item.label;
			showComingSoon = true;
			setTimeout(() => (showComingSoon = false), 2000);
			return;
		}
		onNavigate?.(item.id);
	}
</script>

{#if showComingSoon}
	<div class="coming-soon-toast">
		{comingSoonFeature} coming soon...
	</div>
{/if}

<nav class="nav-bar" aria-label="Main navigation">
	<Row gap={1} justify="center" wrap>
		{#each navItems as item (item.id)}
			<button
				type="button"
				class="nav-item"
				class:nav-item-active={active === item.id}
				class:nav-item-coming-soon={item.comingSoon}
				disabled={item.disabled}
				onclick={() => handleClick(item)}
				aria-current={active === item.id ? 'page' : undefined}
			>
				{item.label}
			</button>
		{/each}
	</Row>
</nav>

<style>
	.coming-soon-toast {
		position: fixed;
		bottom: calc(var(--space-3) + var(--space-12));
		left: 50%;
		transform: translateX(-50%);
		padding: var(--space-2) var(--space-4);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-border-default);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		z-index: var(--z-tooltip);
		animation: fade-in-up 0.2s ease-out;
	}

	@keyframes fade-in-up {
		from {
			opacity: 0;
			transform: translateX(-50%) translateY(8px);
		}
		to {
			opacity: 1;
			transform: translateX(-50%) translateY(0);
		}
	}

	.nav-bar {
		padding: var(--space-3) var(--space-4);
		background: var(--color-bg-secondary);
		border-top: var(--border-width) solid var(--color-border-subtle);
	}

	.nav-item {
		padding: var(--space-1-5) var(--space-3);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wider);
		color: var(--color-text-tertiary);
		background: transparent;
		border: var(--border-width) solid transparent;
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.nav-item:hover:not(:disabled) {
		color: var(--color-text-secondary);
		border-color: var(--color-border-default);
	}

	.nav-item:focus-visible {
		outline: 2px solid var(--color-accent);
		outline-offset: 2px;
	}

	.nav-item:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.nav-item-active {
		color: var(--color-accent);
		border-color: var(--color-accent-dim);
		background: var(--color-accent-glow);
	}

	.nav-item-active:hover {
		color: var(--color-accent-bright);
		border-color: var(--color-accent);
	}

	.nav-item-coming-soon {
		opacity: 0.5;
	}

	/* Responsive */
	@media (max-width: 640px) {
		.nav-item {
			padding: var(--space-1) var(--space-2);
			font-size: 0.5625rem;
		}
	}
</style>
