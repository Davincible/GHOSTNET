<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { page } from '$app/stores';

	/**
	 * Sidebar navigation item configuration.
	 * Icons use ASCII/Unicode characters to match the terminal aesthetic.
	 */
	interface SidebarItem {
		id: string;
		icon: string;
		label: string;
		href?: string;
		action?: () => void;
		/** Group separator - renders a divider before this item */
		divider?: boolean;
	}

	interface Props {
		/** Callback when Jack In is triggered */
		onJackIn?: () => void;
		/** Callback when Extract is triggered */
		onExtract?: () => void;
		/** Callback when Settings is triggered */
		onSettings?: () => void;
		/** Callback when Wallet is triggered */
		onWallet?: () => void;
	}

	let { onJackIn, onExtract, onSettings, onWallet }: Props = $props();

	// Derive current path for active state
	let currentPath = $derived($page.url.pathname);

	/**
	 * Sidebar items with terminal-style icons.
	 * Top section: Primary navigation
	 * Bottom section: System actions (after divider)
	 */
	let items: SidebarItem[] = $derived([
		// ═══════════════════════════════════════════
		// PRIMARY NAVIGATION
		// ═══════════════════════════════════════════
		{
			id: 'network',
			icon: '$_',
			label: 'NETWORK',
			href: '/',
		},
		{
			id: 'arcade',
			icon: '>_',
			label: 'ARCADE',
			href: '/arcade',
		},
		{
			id: 'typing',
			icon: '/_',
			label: 'TRACE EVASION',
			href: '/typing',
		},
		{
			id: 'crew',
			icon: '@@',
			label: 'CREW',
			href: '/crew',
		},
		{
			id: 'deadpool',
			icon: 'xx',
			label: 'DEAD POOL',
			href: '/deadpool',
		},
		{
			id: 'market',
			icon: '[]',
			label: 'MARKET',
			href: '/market',
		},
		{
			id: 'leaderboard',
			icon: '#1',
			label: 'RANKS',
			href: '/leaderboard',
		},

		// ═══════════════════════════════════════════
		// QUICK ACTIONS
		// ═══════════════════════════════════════════
		{
			id: 'jackin',
			icon: '=>',
			label: 'JACK IN',
			action: onJackIn,
			divider: true,
		},
		{
			id: 'extract',
			icon: '<=',
			label: 'EXTRACT',
			action: onExtract,
		},

		// ═══════════════════════════════════════════
		// SYSTEM
		// ═══════════════════════════════════════════
		{
			id: 'wallet',
			icon: '<>',
			label: 'WALLET',
			action: onWallet,
			divider: true,
		},
		{
			id: 'settings',
			icon: '::',
			label: 'SETTINGS',
			action: onSettings,
		},
		{
			id: 'help',
			icon: '??',
			label: 'HELP',
			href: '/help',
		},
	]);

	/**
	 * Check if an item is active based on current path.
	 */
	function isActive(item: SidebarItem): boolean {
		if (!item.href) return false;
		if (item.href === '/') return currentPath === '/';
		return currentPath.startsWith(item.href);
	}

	/**
	 * Handle item click - navigate or trigger action.
	 */
	function handleClick(item: SidebarItem) {
		if (item.action) {
			item.action();
		} else if (item.href) {
			goto(resolve(item.href));
		}
	}
</script>

<aside class="sidebar" aria-label="Quick navigation">
	<!-- ASCII frame top -->
	<div class="sidebar-frame frame-top">╔══════╗</div>

	<!-- Navigation items -->
	<nav class="sidebar-nav">
		{#each items as item (item.id)}
			{#if item.divider}
				<div class="sidebar-divider">╠──────╣</div>
			{/if}

			<button
				type="button"
				class="sidebar-item"
				class:sidebar-item-active={isActive(item)}
				onclick={() => handleClick(item)}
				title={item.label}
				aria-label={item.label}
				aria-current={isActive(item) ? 'page' : undefined}
			>
				<span class="item-border-l">║</span>
				<span class="item-icon">{item.icon}</span>
				<span class="item-border-r">║</span>

				<!-- Tooltip -->
				<span class="item-tooltip">
					<span class="tooltip-arrow">◀</span>
					<span class="tooltip-text">{item.label}</span>
				</span>
			</button>
		{/each}
	</nav>

	<!-- ASCII frame bottom -->
	<div class="sidebar-frame frame-bottom">╚══════╝</div>

	<!-- Data stream effect (decorative) -->
	<div class="data-stream" aria-hidden="true"></div>
</aside>

<style>
	/* ════════════════════════════════════════════════════════════════
	   SIDEBAR CONTAINER
	   Fixed position, left side, vertically centered
	   8 characters wide: ╔══════╗ (1 + 6 + 1)
	   ════════════════════════════════════════════════════════════════ */

	.sidebar {
		position: fixed;
		left: var(--space-3);
		top: 50%;
		transform: translateY(-50%);
		z-index: var(--z-sticky);
		display: flex;
		flex-direction: column;
		align-items: stretch;
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		line-height: 1;
		pointer-events: auto;
	}

	/* ════════════════════════════════════════════════════════════════
	   ASCII FRAME (TOP & BOTTOM)
	   ════════════════════════════════════════════════════════════════ */

	.sidebar-frame {
		text-align: center;
		color: var(--color-accent-dim);
		user-select: none;
		letter-spacing: 0;
	}

	/* ════════════════════════════════════════════════════════════════
	   NAVIGATION CONTAINER
	   ════════════════════════════════════════════════════════════════ */

	.sidebar-nav {
		display: flex;
		flex-direction: column;
		background: var(--color-bg-secondary);
	}

	/* ════════════════════════════════════════════════════════════════
	   DIVIDER
	   ════════════════════════════════════════════════════════════════ */

	.sidebar-divider {
		text-align: center;
		padding: var(--space-2) 0;
		color: var(--color-accent-dim);
		user-select: none;
		letter-spacing: 0;
	}

	/* ════════════════════════════════════════════════════════════════
	   SIDEBAR ITEM
	   ════════════════════════════════════════════════════════════════ */

	.sidebar-item {
		position: relative;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0;
		padding: var(--space-2) 0;
		background: transparent;
		border: none;
		cursor: pointer;
		transition: all var(--duration-fast) var(--ease-default);
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		line-height: 1;
	}

	.item-border-l,
	.item-border-r {
		color: var(--color-accent-dim);
		opacity: 0.6;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.item-icon {
		width: 6ch;
		text-align: center;
		color: var(--color-text-tertiary);
		font-weight: var(--font-bold);
		letter-spacing: 0;
		transition: all var(--duration-fast) var(--ease-default);
	}

	/* ════════════════════════════════════════════════════════════════
	   HOVER STATE
	   ════════════════════════════════════════════════════════════════ */

	.sidebar-item:hover .item-icon {
		color: var(--color-accent);
		text-shadow: 0 0 8px var(--color-accent-glow);
		animation: sidebar-glitch 0.15s ease-out;
	}

	.sidebar-item:hover .item-border-l,
	.sidebar-item:hover .item-border-r {
		color: var(--color-accent);
		opacity: 1;
	}

	@keyframes sidebar-glitch {
		0% {
			transform: translateX(0);
			opacity: 1;
		}
		20% {
			transform: translateX(-2px);
			opacity: 0.8;
		}
		40% {
			transform: translateX(2px);
			opacity: 0.9;
		}
		60% {
			transform: translateX(-1px);
			opacity: 0.85;
		}
		80% {
			transform: translateX(1px);
			opacity: 0.95;
		}
		100% {
			transform: translateX(0);
			opacity: 1;
		}
	}

	/* ════════════════════════════════════════════════════════════════
	   ACTIVE STATE
	   ════════════════════════════════════════════════════════════════ */

	.sidebar-item-active {
		background: var(--color-accent-glow);
	}

	.sidebar-item-active .item-icon {
		color: var(--color-accent-bright);
		text-shadow:
			0 0 4px var(--color-accent-glow),
			0 0 8px var(--color-accent-glow);
		animation: sidebar-pulse 2s ease-in-out infinite;
	}

	.sidebar-item-active .item-border-l,
	.sidebar-item-active .item-border-r {
		color: var(--color-accent);
		opacity: 1;
	}

	@keyframes sidebar-pulse {
		0%,
		100% {
			text-shadow:
				0 0 4px var(--color-accent-glow),
				0 0 8px var(--color-accent-glow);
		}
		50% {
			text-shadow:
				0 0 8px var(--color-accent-glow),
				0 0 16px var(--color-accent-glow),
				0 0 24px var(--color-accent-glow);
		}
	}

	/* ════════════════════════════════════════════════════════════════
	   FOCUS STATE
	   ════════════════════════════════════════════════════════════════ */

	.sidebar-item:focus-visible {
		outline: 2px solid var(--color-accent);
		outline-offset: 2px;
	}

	/* ════════════════════════════════════════════════════════════════
	   TOOLTIP
	   ════════════════════════════════════════════════════════════════ */

	.item-tooltip {
		position: absolute;
		left: 100%;
		top: 50%;
		transform: translateY(-50%);
		display: flex;
		align-items: center;
		gap: var(--space-1);
		padding-left: var(--space-3);
		opacity: 0;
		pointer-events: none;
		transition: opacity var(--duration-fast) var(--ease-default);
		white-space: nowrap;
	}

	.tooltip-arrow {
		color: var(--color-accent-dim);
		font-size: var(--text-sm);
	}

	.tooltip-text {
		padding: var(--space-1-5) var(--space-3);
		background: var(--color-bg-tertiary);
		border: 1px solid var(--color-accent-dim);
		color: var(--color-accent);
		font-size: var(--text-sm);
		font-weight: var(--font-medium);
		letter-spacing: var(--tracking-wider);
		box-shadow: 0 0 12px var(--color-accent-glow);
	}

	.sidebar-item:hover .item-tooltip {
		opacity: 1;
	}

	/* ════════════════════════════════════════════════════════════════
	   DATA STREAM (DECORATIVE)
	   Vertical line with flowing data effect
	   ════════════════════════════════════════════════════════════════ */

	.data-stream {
		position: absolute;
		left: 50%;
		top: 0;
		bottom: 0;
		width: 1px;
		background: linear-gradient(
			to bottom,
			transparent 0%,
			var(--color-accent-faint) 10%,
			var(--color-accent-faint) 90%,
			transparent 100%
		);
		opacity: 0.3;
		z-index: -1;
		pointer-events: none;
	}

	.data-stream::after {
		content: '';
		position: absolute;
		left: 0;
		top: 0;
		width: 100%;
		height: 20px;
		background: linear-gradient(to bottom, var(--color-accent), transparent);
		animation: data-flow 3s linear infinite;
	}

	@keyframes data-flow {
		0% {
			top: -20px;
			opacity: 0;
		}
		10% {
			opacity: 0.6;
		}
		90% {
			opacity: 0.6;
		}
		100% {
			top: 100%;
			opacity: 0;
		}
	}

	/* ════════════════════════════════════════════════════════════════
	   RESPONSIVE - Hide on mobile/tablet
	   ════════════════════════════════════════════════════════════════ */

	@media (max-width: 1023px) {
		.sidebar {
			display: none;
		}
	}

	/* ════════════════════════════════════════════════════════════════
	   REDUCED MOTION
	   ════════════════════════════════════════════════════════════════ */

	@media (prefers-reduced-motion: reduce) {
		.sidebar-item:hover .item-icon {
			animation: none;
		}

		.sidebar-item-active .item-icon {
			animation: none;
		}

		.data-stream::after {
			animation: none;
		}
	}
</style>
