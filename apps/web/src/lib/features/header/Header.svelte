<script lang="ts">
	import { Badge } from '$lib/ui/primitives';
	import { Row } from '$lib/ui/layout';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import WalletButton from './WalletButton.svelte';

	interface Props {
		/** Callback when settings is clicked */
		onSettings?: () => void;
		/** Callback when intro video is clicked */
		onIntro?: () => void;
	}

	let { onSettings, onIntro }: Props = $props();

	const provider = getProvider();

	// Animated glitch line state
	let glitchOffset = $state(0);

	$effect(() => {
		const interval = setInterval(() => {
			glitchOffset = Math.random() * 100;
		}, 100);
		return () => clearInterval(interval);
	});
</script>

<header class="header">
	<div class="header-left">
		<h1 class="logo">
			<span class="logo-text glow-green">GHOSTNET</span>
			<span class="logo-version">v1.0.7</span>
		</h1>
		<div class="glitch-line" style:--offset="{glitchOffset}%" aria-hidden="true"></div>
	</div>

	<div class="header-right">
		<Row gap={4} align="center">
			<div class="network-status">
				<span class="network-label">NETWORK:</span>
				{#if provider.connectionStatus === 'connected'}
					<Badge variant="success" glow>ONLINE</Badge>
				{:else if provider.connectionStatus === 'connecting' || provider.connectionStatus === 'reconnecting'}
					<Badge variant="warning" pulse>CONNECTING</Badge>
				{:else}
					<Badge variant="danger">OFFLINE</Badge>
				{/if}
			</div>
			{#if onIntro}
				<button
					class="intro-btn"
					onclick={onIntro}
					aria-label="Watch intro"
					title="Watch intro"
				>
					<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<polygon points="5,3 19,12 5,21" fill="currentColor" stroke="none"></polygon>
					</svg>
				</button>
			{/if}
			<button
				class="settings-btn"
				onclick={onSettings}
				aria-label="Settings"
				data-testid="settings-button"
			>
				<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<circle cx="12" cy="12" r="3"></circle>
					<path
						d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"
					></path>
				</svg>
			</button>
			<WalletButton />
		</Row>
	</div>
</header>

<style>
	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: var(--space-3) var(--space-4);
		border-bottom: var(--border-width) solid var(--color-border-subtle);
		background: var(--color-bg-secondary);
		position: relative;
	}

	.header-left {
		display: flex;
		align-items: center;
		gap: var(--space-4);
		flex: 1;
	}

	.header-right {
		display: flex;
		align-items: center;
	}

	.logo {
		display: flex;
		align-items: baseline;
		gap: var(--space-2);
		margin: 0;
	}

	.logo-text {
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-widest);
		color: var(--color-text-primary);
	}

	/* Override the glow-green class */
	:global(.logo-text.glow-green) {
		color: var(--color-text-primary);
		text-shadow: none;
	}

	.logo-version {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		font-weight: var(--font-normal);
	}

	.glitch-line {
		flex: 1;
		height: 1px;
		background: linear-gradient(
			90deg,
			transparent 0%,
			var(--color-border-subtle) var(--offset),
			var(--color-accent-dim) calc(var(--offset) + 3%),
			var(--color-border-subtle) calc(var(--offset) + 6%),
			transparent 100%
		);
		opacity: 0.5;
		max-width: 400px;
	}

	.network-status {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.network-label {
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
		text-transform: uppercase;
	}

	.settings-btn,
	.intro-btn {
		background: transparent;
		border: 1px solid var(--color-border-default);
		color: var(--color-text-tertiary);
		padding: var(--space-2);
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.settings-btn:hover,
	.intro-btn:hover {
		color: var(--color-accent);
		border-color: var(--color-accent-dim);
		background: var(--color-bg-tertiary);
	}

	.settings-btn svg,
	.intro-btn svg {
		width: 16px;
		height: 16px;
	}

	/* Responsive */
	@media (max-width: 640px) {
		.header {
			flex-direction: column;
			gap: var(--space-3);
		}

		.header-left {
			width: 100%;
			justify-content: center;
		}

		.glitch-line {
			display: none;
		}

		.header-right {
			width: 100%;
			justify-content: center;
		}

		.network-label {
			display: none;
		}
	}
</style>
