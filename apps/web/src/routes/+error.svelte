<script lang="ts">
	import { page } from '$app/state';
	import { Panel } from '$lib/ui/terminal';
	import { Button } from '$lib/ui/primitives';

	// SSR-safe timestamp: initialize with placeholder, update on client
	// Using $state + $effect (not $derived) because $derived runs during SSR,
	// causing hydration mismatch when server/client times differ
	// eslint-disable-next-line svelte/prefer-writable-derived
	let timestamp = $state('...');

	$effect(() => {
		timestamp = new Date().toISOString();
	});

	// ASCII art for different error types
	const errorArt: Record<string, string> = {
		'404': `
 ██╗  ██╗ ██████╗ ██╗  ██╗
 ██║  ██║██╔═████╗██║  ██║
 ███████║██║██╔██║███████║
 ╚════██║████╔╝██║╚════██║
      ██║╚██████╔╝     ██║
      ╚═╝ ╚═════╝      ╚═╝`,
		'500': `
 ███████╗ ██████╗  ██████╗
 ██╔════╝██╔═████╗██╔═████╗
 ███████╗██║██╔██║██║██╔██║
 ╚════██║████╔╝██║████╔╝██║
 ███████║╚██████╔╝╚██████╔╝
 ╚══════╝ ╚═════╝  ╚═════╝`,
		default: `
 ███████╗██████╗ ██████╗
 ██╔════╝██╔══██╗██╔══██╗
 █████╗  ██████╔╝██████╔╝
 ██╔══╝  ██╔══██╗██╔══██╗
 ███████╗██║  ██║██║  ██║
 ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝`,
	};

	// Get appropriate ASCII art
	let art = $derived(errorArt[String(page.status)] ?? errorArt['default']);

	// Error messages
	let errorMessages: Record<number, { title: string; description: string }> = {
		404: {
			title: 'SIGNAL LOST',
			description: 'The node you requested has been disconnected from the network.',
		},
		500: {
			title: 'SYSTEM FAILURE',
			description: 'Critical error in the neural pathway. The operators have been notified.',
		},
		403: {
			title: 'ACCESS DENIED',
			description: 'Your clearance level is insufficient for this sector.',
		},
	};

	let errorInfo = $derived(
		errorMessages[page.status] ?? {
			title: 'UNKNOWN ERROR',
			description: page.error?.message ?? 'An unexpected anomaly has occurred.',
		}
	);
</script>

<svelte:head>
	<title>{page.status} | GHOSTNET</title>
</svelte:head>

<div class="error-container">
	<Panel borderColor="red" glow>
		<div class="error-content">
			<pre class="error-art">{art}</pre>

			<div class="error-header">
				<span class="error-code">ERROR {page.status}</span>
				<span class="error-title">{errorInfo.title}</span>
			</div>

			<div class="error-divider">
				{'─'.repeat(48)}
			</div>

			<p class="error-description">{errorInfo.description}</p>

			<div class="error-log">
				<span class="log-prefix">&gt;</span>
				<span class="log-text">Timestamp: {timestamp}</span>
			</div>
			<div class="error-log">
				<span class="log-prefix">&gt;</span>
				<span class="log-text">Path: {page.url.pathname}</span>
			</div>
			{#if page.error?.message}
				<div class="error-log">
					<span class="log-prefix">&gt;</span>
					<span class="log-text">Details: {page.error.message}</span>
				</div>
			{/if}

			<div class="error-actions">
				<Button variant="secondary" onclick={() => history.back()}>&lt; GO BACK</Button>
				<Button variant="primary" onclick={() => (location.href = '/')}>RETURN TO BASE</Button>
			</div>

			<div class="error-hint">
				<span class="hint-icon">!</span>
				<span class="hint-text">Press ESC or click anywhere to dismiss</span>
			</div>
		</div>
	</Panel>
</div>

<style>
	.error-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 100vh;
		padding: var(--space-6);
		background: var(--color-bg-void);
	}

	.error-content {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-4);
		max-width: 600px;
		text-align: center;
	}

	.error-art {
		font-family: var(--font-mono);
		font-size: 0.5rem;
		line-height: 1;
		color: var(--color-red);
		text-shadow: 0 0 10px var(--color-red);
		white-space: pre;
		margin: 0;
	}

	@media (min-width: 640px) {
		.error-art {
			font-size: 0.7rem;
		}
	}

	.error-header {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.error-code {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-red);
		letter-spacing: var(--tracking-wider);
	}

	.error-title {
		font-family: var(--font-mono);
		font-size: var(--text-2xl);
		font-weight: var(--font-bold);
		color: var(--color-text-primary);
		letter-spacing: var(--tracking-wide);
	}

	.error-divider {
		font-family: var(--font-mono);
		color: var(--color-border-default);
		font-size: var(--text-xs);
		overflow: hidden;
		max-width: 100%;
	}

	.error-description {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-secondary);
		max-width: 40ch;
		margin: 0;
	}

	.error-log {
		display: flex;
		align-items: flex-start;
		gap: var(--space-2);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		text-align: left;
		width: 100%;
	}

	.log-prefix {
		color: var(--color-accent-dim);
		flex-shrink: 0;
	}

	.log-text {
		color: var(--color-text-tertiary);
		word-break: break-all;
	}

	.error-actions {
		display: flex;
		gap: var(--space-3);
		margin-top: var(--space-2);
	}

	.error-hint {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		margin-top: var(--space-2);
	}

	.hint-icon {
		color: var(--color-amber);
	}

	/* Glitch animation on the ASCII art */
	.error-art {
		animation: glitch 3s ease-in-out infinite;
	}

	@keyframes glitch {
		0%,
		100% {
			text-shadow: 0 0 10px var(--color-red);
			transform: translate(0);
		}
		2% {
			text-shadow:
				-2px 0 var(--color-cyan),
				2px 0 var(--color-red);
			transform: translate(2px, 0);
		}
		4% {
			text-shadow: 0 0 10px var(--color-red);
			transform: translate(0);
		}
		50% {
			text-shadow: 0 0 10px var(--color-red);
			transform: translate(0);
		}
		52% {
			text-shadow:
				2px 0 var(--color-cyan),
				-2px 0 var(--color-red);
			transform: translate(-2px, 0);
		}
		54% {
			text-shadow: 0 0 10px var(--color-red);
			transform: translate(0);
		}
	}
</style>
