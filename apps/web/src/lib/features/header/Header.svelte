<script lang="ts">
	import { Badge } from '$lib/ui/primitives';
	import { Row } from '$lib/ui/layout';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import WalletButton from './WalletButton.svelte';

	interface Props {
		/** Callback when settings is clicked */
		onSettings?: () => void;
	}

	let { onSettings }: Props = $props();

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
			<button class="settings-btn" onclick={onSettings} aria-label="Settings">
				<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<circle cx="12" cy="12" r="3"></circle>
					<path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path>
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
		border-bottom: var(--border-width) solid var(--color-green-dim);
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
		font-size: var(--text-xl);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
	}

	.logo-version {
		font-size: var(--text-sm);
		color: var(--color-green-dim);
		font-weight: var(--font-normal);
	}

	.glitch-line {
		flex: 1;
		height: 2px;
		background: linear-gradient(
			90deg,
			transparent 0%,
			var(--color-green-dim) var(--offset),
			var(--color-green-bright) calc(var(--offset) + 5%),
			var(--color-green-dim) calc(var(--offset) + 10%),
			transparent 100%
		);
		opacity: 0.6;
		max-width: 300px;
	}

	.network-status {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.network-label {
		font-size: var(--text-sm);
		color: var(--color-green-mid);
		letter-spacing: var(--tracking-wide);
	}

	.settings-btn {
		background: none;
		border: 1px solid var(--color-green-dim);
		color: var(--color-green-mid);
		padding: var(--space-2);
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all var(--duration-fast) var(--ease-default);
	}

	.settings-btn:hover {
		color: var(--color-green-bright);
		border-color: var(--color-green-bright);
		background: var(--color-bg-tertiary);
	}

	.settings-btn svg {
		width: 18px;
		height: 18px;
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
