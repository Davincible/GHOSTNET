<script lang="ts">
	import type { Snippet } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { Header, Breadcrumb } from '$lib/features/header';

	interface Props {
		children: Snippet;
	}

	let { children }: Props = $props();

	// Showcase section definitions
	const sections = [
		{ id: 'overview', label: 'OVERVIEW', icon: '>', href: '/dev/showcase' },
		{ id: 'panels', label: 'PANELS', icon: '#', href: '/dev/showcase/panels' },
		// Future sections:
		// { id: 'buttons', label: 'BUTTONS', icon: '*', href: '/dev/showcase/buttons' },
		// { id: 'badges', label: 'BADGES', icon: '@', href: '/dev/showcase/badges' },
		// { id: 'layout', label: 'LAYOUT', icon: '=', href: '/dev/showcase/layout' },
		// { id: 'terminal', label: 'TERMINAL', icon: '$', href: '/dev/showcase/terminal' },
		// { id: 'data-display', label: 'DATA DISPLAY', icon: '%', href: '/dev/showcase/data-display' },
	];

	// Derive active section from current path
	let activeSection = $derived.by(() => {
		const path = $page.url.pathname;
		// Find the most specific match (longest href that matches)
		const match = sections
			.filter((s) => path === s.href || (s.href !== '/dev/showcase' && path.startsWith(s.href)))
			.sort((a, b) => b.href.length - a.href.length)[0];
		return match?.id ?? 'overview';
	});

	function navigate(href: string) {
		goto(resolve(href as any));
	}
</script>

<svelte:head>
	<title>GHOSTNET - Component Showcase</title>
	<meta name="description" content="GHOSTNET design system component showcase" />
</svelte:head>

<Header />
<Breadcrumb
	path={[
		{ label: 'NETWORK', href: '/' },
		{ label: 'DEV', href: '/dev/showcase' },
		{ label: 'SHOWCASE' },
	]}
/>

<div class="showcase-page">
	<header class="showcase-header">
		<h1 class="showcase-title">COMPONENT SHOWCASE</h1>
		<p class="showcase-subtitle">GHOSTNET DESIGN SYSTEM // INTERACTIVE REFERENCE</p>
	</header>

	<div class="showcase-layout">
		<!-- Section Navigation -->
		<nav class="showcase-nav" aria-label="Component sections">
			<div class="nav-heading">COMPONENTS</div>
			<div class="nav-items">
				{#each sections as section (section.id)}
					<button
						type="button"
						class="nav-item"
						class:active={activeSection === section.id}
						onclick={() => navigate(section.href)}
						aria-current={activeSection === section.id ? 'page' : undefined}
					>
						<span class="nav-icon">{section.icon}</span>
						<span class="nav-label">{section.label}</span>
					</button>
				{/each}
			</div>
			<div class="nav-footer">
				<span class="nav-footer-text">v1.0 // DEV ONLY</span>
			</div>
		</nav>

		<!-- Content Area -->
		<main class="showcase-content">
			{@render children()}
		</main>
	</div>
</div>

<style>
	.showcase-page {
		max-width: 1400px;
		margin: 0 auto;
		padding: var(--space-4);
		padding-bottom: var(--space-16);
	}

	.showcase-header {
		text-align: center;
		margin-bottom: var(--space-6);
		padding-bottom: var(--space-4);
		border-bottom: 1px solid var(--color-border-subtle);
	}

	.showcase-title {
		font-family: var(--font-mono);
		font-size: var(--text-2xl);
		font-weight: var(--font-bold);
		color: var(--color-accent);
		letter-spacing: var(--tracking-widest);
		margin: 0 0 var(--space-2);
	}

	.showcase-subtitle {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wide);
		margin: 0;
	}

	.showcase-layout {
		display: grid;
		grid-template-columns: 200px 1fr;
		gap: var(--space-6);
	}

	/* ── Navigation ── */

	.showcase-nav {
		position: sticky;
		top: var(--space-4);
		height: fit-content;
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.nav-heading {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-widest);
		padding: 0 var(--space-3);
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
		flex-shrink: 0;
		width: 1.5ch;
		text-align: center;
	}

	.nav-item.active .nav-icon {
		opacity: 1;
	}

	.nav-label {
		letter-spacing: var(--tracking-wide);
	}

	.nav-footer {
		padding: var(--space-3);
		border-top: 1px solid var(--color-border-subtle);
		margin-top: var(--space-3);
	}

	.nav-footer-text {
		font-family: var(--font-mono);
		font-size: 0.5625rem;
		color: var(--color-text-muted);
		letter-spacing: var(--tracking-wider);
	}

	/* ── Content ── */

	.showcase-content {
		min-width: 0;
	}

	/* ── Responsive ── */

	@media (max-width: 900px) {
		.showcase-page {
			padding: var(--space-2);
		}

		.showcase-layout {
			grid-template-columns: 1fr;
			gap: var(--space-4);
		}

		.showcase-nav {
			position: static;
			overflow-x: auto;
			padding-bottom: var(--space-2);
			border-bottom: 1px solid var(--color-border-subtle);
		}

		.nav-heading {
			display: none;
		}

		.nav-items {
			flex-direction: row;
			gap: var(--space-1);
		}

		.nav-item {
			flex-shrink: 0;
			padding: var(--space-1-5) var(--space-2);
		}

		.nav-footer {
			display: none;
		}
	}
</style>
