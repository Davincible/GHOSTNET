<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { Row } from '$lib/ui/layout';

	/**
	 * Navigation item configuration.
	 *
	 * The `comingSoon` flag is retained for future features that aren't yet implemented.
	 * When set, clicking the item shows a toast instead of navigating, and applies
	 * the `.nav-item-coming-soon` style (reduced opacity).
	 */
	interface NavItem {
		id: string;
		label: string;
		href?: string;
		disabled?: boolean;
		/** Shows "coming soon" toast instead of navigating. Retained for future features. */
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
		{ id: 'network', label: 'NETWORK', href: '/' },
		{ id: 'position', label: 'POSITION', href: '/' },
		{ id: 'games', label: 'GAMES', href: '/typing' },
		{ id: 'crew', label: 'CREW', href: '/crew' },
		{ id: 'market', label: 'MARKET', href: '/market' },
		{ id: 'leaderboard', label: 'RANKS', href: '/leaderboard' },
		{ id: 'help', label: '?', href: '/help' },
	];

	function handleClick(item: NavItem) {
		// Handle "coming soon" features - show toast and don't navigate
		if (item.comingSoon) {
			comingSoonFeature = item.label;
			showComingSoon = true;
			setTimeout(() => (showComingSoon = false), 2000);
			return;
		}

		// Update active state first (useful for same-page navigation like network/position)
		onNavigate?.(item.id);

		// Then navigate if there's an href
		if (item.href) {
			goto(resolve(item.href));
		}
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

	/* Responsive: Fixed at bottom on mobile */
	@media (max-width: 767px) {
		.nav-bar {
			position: fixed;
			bottom: 0;
			left: 0;
			right: 0;
			z-index: var(--z-sticky);
			padding-bottom: calc(var(--space-3) + env(safe-area-inset-bottom));
		}

		.nav-item {
			min-height: var(--touch-target-min);
			display: flex;
			align-items: center;
			justify-content: center;
		}
	}

	@media (max-width: 640px) {
		.nav-item {
			padding: var(--space-1) var(--space-2);
			font-size: 0.5625rem;
		}
	}
</style>
