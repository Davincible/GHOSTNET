<!--
  HeroSection.svelte
  ===================
  Hero block for the presale page: ASCII art, tagline, trust badges,
  and a contextual status banner driven by pageState.
-->
<script lang="ts">
	import type { PresalePageState } from './types';

	interface Props {
		pageState: PresalePageState;
	}

	let { pageState }: Props = $props();

	const STATUS_MAP: Record<PresalePageState, { text: string; class: string }> = {
		NOT_STARTED: { text: 'SIGNAL INTERCEPTED — AWAITING LAUNCH', class: 'pending' },
		LIVE: { text: '░░░ INTERCEPT ACTIVE ░░░', class: 'live' },
		SOLD_OUT: { text: 'ALL $DATA ALLOCATED', class: 'sold-out' },
		ENDED: { text: 'PRESALE FINALIZED', class: 'ended' },
		REFUNDING: { text: 'REFUNDS ENABLED — CLAIM ETH', class: 'refunding' },
		CLAIM_ACTIVE: { text: 'CLAIM YOUR $DATA', class: 'claim' },
		CLAIMED: { text: '$DATA CLAIMED — WELCOME, OPERATOR', class: 'claimed' },
	};

	let status = $derived(STATUS_MAP[pageState]);
</script>

<section class="hero">
	<pre class="ascii-art" aria-label="GHOSTNET">{@html `
 ██████  ██   ██  ██████  ███████ ████████ ███    ██ ███████ ████████
██       ██   ██ ██    ██ ██         ██    ████   ██ ██         ██
██   ███ ███████ ██    ██ ███████    ██    ██ ██  ██ █████      ██
██    ██ ██   ██ ██    ██      ██    ██    ██  ██ ██ ██         ██
 ██████  ██   ██  ██████  ███████    ██    ██   ████ ███████    ██`.trim()}</pre>

	<p class="tagline">
		A network is coming. Jack in. Survive trace scans. Extract gains.
		<span class="tagline-accent">When others die, you profit.</span>
	</p>

	<div class="trust-badges">
		<span class="badge">LP BURNED 🔥</span>
		<span class="separator">│</span>
		<span class="badge">TEAM 24mo VEST</span>
		<span class="separator">│</span>
		<span class="badge">30% DEATH BURN</span>
		<span class="separator">│</span>
		<span class="badge">MEGAETH</span>
	</div>

	<div class="status-banner {status.class}">
		{status.text}
	</div>
</section>

<style>
	.hero {
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		gap: var(--space-6, 1.5rem);
		padding: var(--space-8, 2rem) 0;
	}

	.ascii-art {
		font-family: var(--font-mono, 'IBM Plex Mono', monospace);
		font-size: clamp(0.35rem, 1.2vw, 0.55rem);
		line-height: 1.2;
		color: var(--color-accent, #00e5cc);
		margin: 0;
		overflow-x: auto;
		max-width: 100%;
		white-space: pre;
	}

	.tagline {
		font-family: var(--font-mono, 'IBM Plex Mono', monospace);
		font-size: var(--text-sm, 0.8125rem);
		color: var(--color-text-secondary, rgba(255, 255, 255, 0.7));
		line-height: 1.6;
		max-width: 520px;
		margin: 0;
	}

	.tagline-accent {
		color: var(--color-accent, #00e5cc);
		font-weight: 600;
	}

	.trust-badges {
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		align-items: center;
		gap: var(--space-2, 0.5rem);
		font-family: var(--font-mono, 'IBM Plex Mono', monospace);
		font-size: var(--text-xs, 0.625rem);
		color: var(--color-text-tertiary, rgba(255, 255, 255, 0.4));
		letter-spacing: var(--tracking-wider, 0.12em);
		text-transform: uppercase;
	}

	.separator {
		color: var(--color-text-tertiary, rgba(255, 255, 255, 0.2));
	}

	.badge {
		white-space: nowrap;
	}

	.status-banner {
		font-family: var(--font-mono, 'IBM Plex Mono', monospace);
		font-size: var(--text-base, 0.875rem);
		letter-spacing: var(--tracking-wider, 0.12em);
		text-transform: uppercase;
		padding: var(--space-3, 0.75rem) var(--space-6, 1.5rem);
		border: 1px solid var(--color-accent-dim, #007a6b);
		color: var(--color-text-secondary, rgba(255, 255, 255, 0.7));
	}

	.status-banner.live {
		color: var(--color-accent, #00e5cc);
		border-color: var(--color-accent, #00e5cc);
		text-shadow:
			0 0 8px var(--color-accent-glow, rgba(0, 229, 204, 0.25)),
			0 0 20px var(--color-accent-glow, rgba(0, 229, 204, 0.25));
		box-shadow:
			0 0 8px var(--color-accent-glow, rgba(0, 229, 204, 0.25)),
			inset 0 0 8px var(--color-accent-glow, rgba(0, 229, 204, 0.25));
		animation: glow-pulse 2s ease-in-out infinite;
	}

	.status-banner.pending {
		color: var(--color-text-secondary, rgba(255, 255, 255, 0.7));
		border-color: var(--color-accent-dim, #007a6b);
	}

	.status-banner.sold-out,
	.status-banner.ended {
		color: var(--color-warning, #ffaa00);
		border-color: var(--color-warning, #ffaa00);
	}

	.status-banner.refunding {
		color: var(--color-danger, #ff3333);
		border-color: var(--color-danger, #ff3333);
	}

	.status-banner.claim {
		color: var(--color-accent-bright, #00fff2);
		border-color: var(--color-accent-bright, #00fff2);
		text-shadow: 0 0 8px var(--color-accent-glow, rgba(0, 229, 204, 0.25));
	}

	.status-banner.claimed {
		color: var(--color-success, #00ff88);
		border-color: var(--color-success, #00ff88);
	}

	@keyframes glow-pulse {
		0%,
		100% {
			box-shadow:
				0 0 8px var(--color-accent-glow, rgba(0, 229, 204, 0.25)),
				inset 0 0 8px var(--color-accent-glow, rgba(0, 229, 204, 0.25));
		}
		50% {
			box-shadow:
				0 0 16px var(--color-accent-glow, rgba(0, 229, 204, 0.25)),
				0 0 32px rgba(0, 229, 204, 0.1),
				inset 0 0 16px var(--color-accent-glow, rgba(0, 229, 204, 0.25));
		}
	}
</style>
