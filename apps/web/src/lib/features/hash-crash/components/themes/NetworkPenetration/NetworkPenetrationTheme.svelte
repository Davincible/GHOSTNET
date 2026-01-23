<script lang="ts">
	/**
	 * Network Penetration Theme - Complete visualization
	 * ===================================================
	 * Composes all Theme A components into a cohesive breach visualization.
	 * You're hacking through network firewalls - the multiplier is your
	 * penetration depth, the crash is when ICE traces you.
	 */

	import type { TerminalMessage } from '../../../messages';
	import {
		ROUND_START_MESSAGES,
		BETTING_MESSAGES,
		LOCK_MESSAGES,
		REVEAL_MESSAGES,
		WIN_MESSAGES,
		LOSE_MESSAGES,
		CRASH_MESSAGES,
		getPenetrationMessage,
	} from '../../../messages';
	import {
		TerminalOverlay,
		GlitchEffect,
		TraceFlash,
		TerminalLog,
		IceThreatMeter,
		DepthDisplay,
	} from '../shared';
	import PenetrationBar from './PenetrationBar.svelte';

	import type { HashCrashPhase } from '$lib/core/types/arcade';

	interface Props {
		/** Current penetration depth (multiplier) */
		depth: number;
		/** Player's exit point (target multiplier) */
		exitPoint?: number | null;
		/** Current game phase */
		phase: HashCrashPhase | null;
		/** Whether traced (crashed) */
		traced?: boolean;
		/** Player's result */
		playerResult?: 'pending' | 'won' | 'lost';
		/** Round ID for display */
		roundId?: number;
	}

	let {
		depth,
		exitPoint = null,
		phase = null,
		traced = false,
		playerResult = 'pending',
		roundId = 0,
	}: Props = $props();

	// ─────────────────────────────────────────────────────────────────────────
	// TERMINAL MESSAGES
	// ─────────────────────────────────────────────────────────────────────────

	let messages = $state<TerminalMessage[]>([]);

	// NON-REACTIVE tracking variables (to avoid effect loops)
	// These don't need to trigger re-renders, just track state for cleanup/guards
	let lastPhase: string | null = null;
	let lastDepthBucket = 0;
	let hasSentCrashMessages = false;
	let hasSentOutcomeMessages = false;

	// Track pending timeouts for cleanup (non-reactive - no $state)
	const pendingTimeouts: ReturnType<typeof setTimeout>[] = [];

	function clearPendingTimeouts() {
		while (pendingTimeouts.length > 0) {
			clearTimeout(pendingTimeouts.pop());
		}
	}

	function addMessages(msgs: TerminalMessage[]) {
		// Add with delays, tracking timeouts for cleanup
		msgs.forEach((msg, i) => {
			const delay = msg.delay ?? i * 200;
			const timeoutId = setTimeout(() => {
				messages = [...messages, msg];
			}, delay);
			pendingTimeouts.push(timeoutId);
		});
	}

	function getPhaseMessages(p: typeof phase): TerminalMessage[] {
		switch (p) {
			case 'betting':
				return [...ROUND_START_MESSAGES, ...BETTING_MESSAGES];
			case 'locked':
				return LOCK_MESSAGES;
			case 'revealed':
			case 'animating':
				return REVEAL_MESSAGES;
			default:
				return [];
		}
	}

	// Add messages based on phase changes
	$effect(() => {
		if (phase !== lastPhase) {
			// Reset state on new betting round
			if (phase === 'betting') {
				clearPendingTimeouts();
				messages = [];
				lastDepthBucket = 0;
				hasSentCrashMessages = false;
				hasSentOutcomeMessages = false;
			}

			const newMessages = getPhaseMessages(phase);
			if (newMessages.length > 0) {
				addMessages(newMessages);
			}
			lastPhase = phase;
		}
	});

	// Add messages based on depth changes during animation
	$effect(() => {
		if (phase === 'animating' && !traced) {
			const depthBucket = Math.floor(depth);
			if (depthBucket !== lastDepthBucket) {
				const msg = getPenetrationMessage(depth, exitPoint);
				if (msg) {
					addMessages([msg]);
				}
				lastDepthBucket = depthBucket;
			}
		}
	});

	// Add outcome messages (only once per round)
	$effect(() => {
		if (traced && playerResult !== 'pending' && !hasSentOutcomeMessages) {
			if (playerResult === 'won') {
				addMessages(WIN_MESSAGES);
			} else {
				addMessages(LOSE_MESSAGES);
			}
			hasSentOutcomeMessages = true;
		}
	});

	// Add crash messages (only once per round)
	$effect(() => {
		if (traced && !hasSentCrashMessages) {
			addMessages(CRASH_MESSAGES);
			hasSentCrashMessages = true;
		}
	});

	// Cleanup on unmount
	$effect(() => {
		return () => {
			clearPendingTimeouts();
		};
	});

	// ─────────────────────────────────────────────────────────────────────────
	// ICE THREAT CALCULATION
	// ─────────────────────────────────────────────────────────────────────────

	// Calculate threat level based on depth
	// Higher depth = more danger, exponential scaling
	let threatLevel = $derived.by(() => {
		if (traced) return 100;
		if (phase === 'betting' || phase === 'locked') return 0;

		// Threat grows exponentially with depth
		// At 1x = 5%, 2x = 20%, 5x = 50%, 10x = 80%, 20x+ = 95%+
		const base = Math.log(depth) / Math.log(20); // Normalize to 0-1 at 20x
		return Math.min(Math.round(base * 100), 99);
	});

	// ─────────────────────────────────────────────────────────────────────────
	// DYNAMIC MAX DEPTH
	// ─────────────────────────────────────────────────────────────────────────

	// Scale the bar's max based on current depth and exit point
	let maxDepth = $derived.by(() => {
		const max = Math.max(depth * 1.5, exitPoint ?? 5, 5);
		// Round up to nice numbers
		if (max <= 5) return 5;
		if (max <= 10) return 10;
		if (max <= 20) return 20;
		if (max <= 50) return 50;
		return 100;
	});

	// ─────────────────────────────────────────────────────────────────────────
	// STATE FLAGS
	// ─────────────────────────────────────────────────────────────────────────

	let isActive = $derived(phase === 'animating');
	let showGlitch = $derived(traced);
</script>

<TraceFlash active={traced}>
	<GlitchEffect active={showGlitch} intensity={3}>
		<TerminalOverlay>
			<div class="network-penetration-theme">
				<!-- Header -->
				<header class="theme-header">
					<span class="theme-title">ICE BREAKER</span>
					{#if roundId > 0}
						<span class="round-info">BREACH #{roundId}</span>
					{/if}
					<span
						class="status-indicator"
						class:betting={phase === 'betting'}
						class:active={isActive}
						class:traced
					>
						{#if traced}
							TRACED
						{:else if phase === 'betting'}
							AWAITING ENTRY
						{:else if phase === 'locked'}
							INITIALIZING
						{:else if isActive}
							BREACH ACTIVE
						{:else}
							STANDBY
						{/if}
					</span>
				</header>

				<!-- Main visualization area -->
				<div class="visualization-area">
					<!-- Large depth display -->
					<DepthDisplay {depth} target={exitPoint} crashed={traced} {phase} showStatus={true} />

					<!-- Penetration progress bar -->
					<div class="bar-section">
						<PenetrationBar {depth} {exitPoint} {maxDepth} active={isActive} {traced} />
					</div>

					<!-- Terminal log and threat meter side by side -->
					<div class="info-row">
						<div class="log-section">
							<TerminalLog {messages} maxLines={5} height="100px" />
						</div>

						<div class="threat-section">
							<IceThreatMeter level={threatLevel} active={isActive} />
						</div>
					</div>
				</div>

				<!-- Player bet info (if has bet) -->
				{#if exitPoint}
					<div
						class="bet-info"
						class:won={playerResult === 'won'}
						class:lost={playerResult === 'lost'}
					>
						<div class="bet-row">
							<span class="bet-label">EXIT POINT:</span>
							<span class="bet-value">{exitPoint.toFixed(2)}x</span>
						</div>
						{#if playerResult === 'won'}
							<div class="result-badge won">EXTRACTION SECURED</div>
						{:else if playerResult === 'lost'}
							<div class="result-badge lost">TRACED - EXTRACTION FAILED</div>
						{:else if isActive && depth >= exitPoint}
							<div class="result-badge safe">EXIT AVAILABLE - SAFE</div>
						{/if}
					</div>
				{/if}
			</div>
		</TerminalOverlay>
	</GlitchEffect>
</TraceFlash>

<style>
	.network-penetration-theme {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		padding: var(--space-4);
		background: var(--color-bg-primary);
		border: var(--border-width) solid var(--color-border-default);
		min-height: 400px;
	}

	/* Header */
	.theme-header {
		display: flex;
		align-items: center;
		gap: var(--space-4);
		padding-bottom: var(--space-3);
		border-bottom: var(--border-width) solid var(--color-border-subtle);
	}

	.theme-title {
		font-family: var(--font-mono);
		font-size: var(--text-lg);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-widest);
		color: var(--color-accent);
	}

	.round-info {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		color: var(--color-text-tertiary);
	}

	.status-indicator {
		margin-left: auto;
		padding: var(--space-1) var(--space-2);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		letter-spacing: var(--tracking-wider);
		border: var(--border-width) solid var(--color-border-default);
		color: var(--color-text-secondary);
	}

	.status-indicator.betting {
		border-color: var(--color-cyan);
		color: var(--color-cyan);
	}

	.status-indicator.active {
		border-color: var(--color-accent);
		color: var(--color-accent);
		animation: pulse-status 1s ease-in-out infinite;
	}

	.status-indicator.traced {
		border-color: var(--color-red);
		color: var(--color-red);
		background: var(--color-red-glow);
		animation: flash-status 0.3s ease-in-out infinite;
	}

	@keyframes pulse-status {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.6;
		}
	}

	@keyframes flash-status {
		0%,
		100% {
			opacity: 1;
		}
		50% {
			opacity: 0.3;
		}
	}

	/* Visualization area */
	.visualization-area {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		flex: 1;
	}

	.bar-section {
		margin-top: var(--space-2);
	}

	.info-row {
		display: grid;
		grid-template-columns: 1fr 200px;
		gap: var(--space-4);
		margin-top: auto;
	}

	.log-section {
		flex: 1;
	}

	.threat-section {
		display: flex;
		flex-direction: column;
		justify-content: flex-end;
	}

	/* Bet info */
	.bet-info {
		display: flex;
		align-items: center;
		gap: var(--space-4);
		padding: var(--space-3);
		background: var(--color-bg-tertiary);
		border: var(--border-width) solid var(--color-border-subtle);
	}

	.bet-info.won {
		border-color: var(--color-accent);
		background: var(--color-accent-glow);
	}

	.bet-info.lost {
		border-color: var(--color-red);
		background: var(--color-red-glow);
	}

	.bet-row {
		display: flex;
		gap: var(--space-2);
	}

	.bet-label {
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		color: var(--color-text-tertiary);
		letter-spacing: var(--tracking-wider);
	}

	.bet-value {
		font-family: var(--font-mono);
		font-size: var(--text-sm);
		font-weight: var(--font-bold);
		color: var(--color-cyan);
	}

	.result-badge {
		margin-left: auto;
		padding: var(--space-1) var(--space-3);
		font-family: var(--font-mono);
		font-size: var(--text-xs);
		font-weight: var(--font-bold);
		letter-spacing: var(--tracking-wider);
		text-transform: uppercase;
	}

	.result-badge.won {
		color: var(--color-accent);
		border: var(--border-width) solid var(--color-accent);
		box-shadow: 0 0 10px var(--color-accent-glow);
	}

	.result-badge.lost {
		color: var(--color-red);
		border: var(--border-width) solid var(--color-red);
	}

	.result-badge.safe {
		color: var(--color-accent);
		border: var(--border-width) dashed var(--color-accent);
		animation: pulse-safe 1s ease-in-out infinite;
	}

	@keyframes pulse-safe {
		0%,
		100% {
			opacity: 1;
			box-shadow: 0 0 5px var(--color-accent-glow);
		}
		50% {
			opacity: 0.8;
			box-shadow: 0 0 15px var(--color-accent-glow);
		}
	}

	/* Responsive */
	@media (max-width: 600px) {
		.info-row {
			grid-template-columns: 1fr;
		}

		.bet-info {
			flex-direction: column;
			align-items: flex-start;
			gap: var(--space-2);
		}

		.result-badge {
			margin-left: 0;
		}
	}
</style>
