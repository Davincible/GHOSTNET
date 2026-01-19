<script lang="ts">
	import { Badge } from '$lib/ui/primitives';
	import { Row } from '$lib/ui/layout';
	import { getProvider } from '$lib/core/stores/index.svelte';
	import WalletButton from './WalletButton.svelte';

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
