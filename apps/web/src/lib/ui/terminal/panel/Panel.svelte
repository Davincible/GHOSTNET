<script lang="ts">
	import type { Snippet } from 'svelte';
	import Box from '../Box.svelte';
	import { getSettings } from '$lib/core/settings/store.svelte';
	import type {
		PanelVariant,
		PanelBorderColor,
		PanelAttention,
		PanelAmbientEffect,
		PanelEnterAnimation,
		PanelExitAnimation,
		PanelAnimationSpeed,
	} from './panel-types';
	import {
		resolveAttentionBorderColor,
		resolveAttentionGlow,
		isTransientAttention,
		isPanelAnimation,
		getCssDuration,
		needsOverlay as computeNeedsOverlay,
	} from './panel-effects';

	interface Props {
		// ── Existing (all same defaults, zero breaking changes) ──
		/** Panel title */
		title?: string;
		/** Border style variant */
		variant?: PanelVariant;
		/** Border color */
		borderColor?: PanelBorderColor;
		/** Add glow effect to border */
		glow?: boolean;
		/** Enable scrolling for content */
		scrollable?: boolean;
		/** Max height when scrollable (CSS value) */
		maxHeight?: string;
		/** Min height when scrollable (CSS value) - use same as maxHeight for stable layout */
		minHeight?: string;
		/** Show scroll indicator */
		showScrollHint?: boolean;
		/** Padding inside the box */
		padding?: 0 | 1 | 2 | 3 | 4;
		children: Snippet;
		/** Optional footer snippet */
		footer?: Snippet;

		// ── Lifecycle ──
		/** How the panel enters the viewport */
		enterAnimation?: PanelEnterAnimation;
		/** How the panel exits (if removed from DOM) */
		exitAnimation?: PanelExitAnimation;
		/** Animation speed multiplier */
		animationSpeed?: PanelAnimationSpeed;

		// ── Attention ──
		/** Current attention state (transient auto-resolve, persistent remain until cleared) */
		attention?: PanelAttention | null;
		/** Called when a transient attention animation completes */
		onAttentionEnd?: () => void;

		// ── Ambient ──
		/** Persistent ambient visual effect */
		ambientEffect?: PanelAmbientEffect | null;
	}

	let {
		title,
		variant = 'single',
		borderColor = 'default',
		glow = false,
		scrollable = false,
		maxHeight = '400px',
		minHeight,
		showScrollHint = true,
		padding = 3,
		children,
		footer,
		enterAnimation = 'none',
		exitAnimation = 'none',
		animationSpeed = 'normal',
		attention = null,
		onAttentionEnd,
		ambientEffect = null,
	}: Props = $props();

	// ── Settings gate ──
	// Graceful fallback when Panel is used outside app context (e.g. Storybook, tests)
	let settings: ReturnType<typeof getSettings> | null = null;
	try {
		settings = getSettings();
	} catch {
		// No settings context — effects default to enabled
	}

	let effectsOn = $derived(settings?.effectsEnabled ?? true);

	// ── Box prop mediation ──
	// Attention states override border color and glow, falling back to configured values
	let effectiveBorderColor = $derived.by(() => {
		if (!effectsOn || !attention) return borderColor;
		return resolveAttentionBorderColor(attention) ?? borderColor;
	});

	let effectiveGlow = $derived.by(() => {
		if (!effectsOn || !attention) return glow;
		return resolveAttentionGlow(attention) ?? glow;
	});

	// ── Enter animation state ──
	let hasEntered = $state(true);

	$effect(() => {
		// Reset on mount: if enter animation is configured and effects are on, start un-entered
		if (enterAnimation !== 'none' && effectsOn) {
			hasEntered = false;
		}
	});

	// ── Overlay ──
	let showOverlay = $derived(effectsOn && computeNeedsOverlay(attention, ambientEffect));

	// ── Animation end handler ──
	function handleAnimationEnd(e: AnimationEvent) {
		// Only handle our own animations, not children's
		if (!isPanelAnimation(e.animationName)) return;

		// Enter animation completed
		if (
			e.animationName === 'panel-enter-boot' ||
			e.animationName === 'panel-enter-glitch'
		) {
			hasEntered = true;
			return;
		}

		// Transient attention completed
		if (attention && isTransientAttention(attention)) {
			onAttentionEnd?.();
		}
	}

	// ── Scroll state (existing, unchanged) ──
	let scrollContainer = $state<HTMLDivElement | null>(null);
	let canScrollDown = $state(false);
	let canScrollUp = $state(false);

	function updateScrollState() {
		if (!scrollContainer) return;
		const { scrollTop, scrollHeight, clientHeight } = scrollContainer;
		canScrollUp = scrollTop > 0;
		canScrollDown = scrollTop + clientHeight < scrollHeight - 1;
	}

	$effect(() => {
		if (scrollable && scrollContainer) {
			updateScrollState();
			const observer = new ResizeObserver(updateScrollState);
			observer.observe(scrollContainer);
			return () => observer.disconnect();
		}
	});
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
	class="panel"
	class:panel-scrollable={scrollable}
	class:panel-enter-boot={effectsOn && enterAnimation === 'boot' && !hasEntered}
	class:panel-enter-glitch={effectsOn && enterAnimation === 'glitch' && !hasEntered}
	class:panel-attn-highlight={effectsOn && attention === 'highlight'}
	class:panel-attn-alert={effectsOn && attention === 'alert'}
	class:panel-attn-success={effectsOn && attention === 'success'}
	class:panel-attn-critical={effectsOn && attention === 'critical'}
	class:panel-attn-blackout={effectsOn && attention === 'blackout'}
	class:panel-attn-dimmed={effectsOn && attention === 'dimmed'}
	class:panel-attn-focused={effectsOn && attention === 'focused'}
	class:panel-attn-locked={effectsOn && attention === 'locked'}
	class:panel-ambient-pulse={effectsOn && ambientEffect === 'pulse'}
	class:panel-ambient-heartbeat={effectsOn && ambientEffect === 'heartbeat'}
	class:panel-ambient-static={effectsOn && ambientEffect === 'static'}
	class:panel-ambient-scan={effectsOn && ambientEffect === 'scan'}
	style:--panel-enter-duration={getCssDuration('boot', animationSpeed)}
	style:--panel-glitch-duration={getCssDuration('glitch', animationSpeed)}
	style:--panel-attn-duration={getCssDuration('attention', animationSpeed)}
	style:--panel-critical-duration={getCssDuration('critical', animationSpeed)}
	onanimationend={handleAnimationEnd}
>
	<Box
		{title}
		{variant}
		borderColor={effectiveBorderColor}
		glow={effectiveGlow}
		{padding}
	>
		{#if scrollable}
			<div class="panel-content-wrapper" style:--panel-height={maxHeight}>
				<div
					class="panel-scroll-container"
					bind:this={scrollContainer}
					onscroll={updateScrollState}
				>
					{@render children()}
				</div>
				{#if showScrollHint && canScrollUp}
					<div class="scroll-hint scroll-hint-top">
						<span class="text-green-dim text-xs">&#9650; SCROLL UP</span>
					</div>
				{/if}
				{#if showScrollHint && canScrollDown}
					<div class="scroll-hint scroll-hint-bottom">
						<span class="text-green-dim text-xs">&#9660; SCROLL FOR MORE</span>
					</div>
				{/if}
				{#if footer}
					<div class="panel-footer panel-footer-sticky">
						{@render footer()}
					</div>
				{/if}
			</div>
		{:else}
			{@render children()}
			{#if footer}
				<div class="panel-footer">
					{@render footer()}
				</div>
			{/if}
		{/if}
	</Box>

	<!-- Effect overlay — pointer-events: none so it never blocks interaction -->
	{#if showOverlay}
		<div class="panel-overlay" aria-hidden="true"></div>
	{/if}
</div>

<style>
	/* ═══════════════════════════════════════════════════════════
	   BASE — existing styles, unchanged
	   ═══════════════════════════════════════════════════════════ */
	.panel {
		width: 100%;
		position: relative;
	}

	.panel-content-wrapper {
		display: flex;
		flex-direction: column;
		height: var(--panel-height);
		min-height: var(--panel-height);
		max-height: var(--panel-height);
	}

	.panel-scroll-container {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		overflow-x: hidden;
		scrollbar-width: thin;
		scrollbar-color: var(--color-border-strong) var(--color-bg-tertiary);
	}

	.panel-scroll-container::-webkit-scrollbar {
		width: 4px;
	}

	.panel-scroll-container::-webkit-scrollbar-track {
		background: var(--color-bg-tertiary);
	}

	.panel-scroll-container::-webkit-scrollbar-thumb {
		background: var(--color-border-strong);
	}

	.panel-scroll-container::-webkit-scrollbar-thumb:hover {
		background: var(--color-accent-dim);
	}

	.scroll-hint {
		padding-top: var(--space-2);
		text-align: center;
		animation: panel-scroll-pulse 2s ease-in-out infinite;
	}

	:global(.scroll-hint .text-green-dim) {
		color: var(--color-text-tertiary);
	}

	@keyframes panel-scroll-pulse {
		0%,
		100% {
			opacity: 0.4;
		}
		50% {
			opacity: 0.8;
		}
	}

	.panel-footer {
		margin-top: var(--space-3);
		padding-top: var(--space-2);
		border-top: 1px solid var(--color-border-subtle);
	}

	.panel-footer-sticky {
		flex-shrink: 0;
		margin-top: 0;
		background: var(--color-bg-secondary);
	}

	/* ═══════════════════════════════════════════════════════════
	   ENTER ANIMATIONS
	   ═══════════════════════════════════════════════════════════ */

	.panel-enter-boot {
		animation: panel-enter-boot var(--panel-enter-duration) var(--ease-out) forwards;
	}

	@keyframes panel-enter-boot {
		0% {
			clip-path: inset(50% 0 50% 0);
			opacity: 0.6;
		}
		60% {
			clip-path: inset(0 0 0 0);
			opacity: 0.8;
		}
		100% {
			clip-path: inset(0 0 0 0);
			opacity: 1;
		}
	}

	.panel-enter-glitch {
		animation: panel-enter-glitch var(--panel-glitch-duration) var(--ease-out) forwards;
	}

	@keyframes panel-enter-glitch {
		0% {
			clip-path: inset(0 0 100% 0);
			filter: hue-rotate(90deg);
			opacity: 0;
		}
		30% {
			clip-path: inset(0 0 20% 0);
			filter: hue-rotate(45deg);
			opacity: 0.7;
		}
		50% {
			clip-path: inset(10% 0 0 0);
			filter: hue-rotate(-20deg);
		}
		70% {
			clip-path: inset(0 0 5% 0);
			filter: hue-rotate(10deg);
			opacity: 0.9;
		}
		100% {
			clip-path: inset(0 0 0 0);
			filter: hue-rotate(0deg);
			opacity: 1;
		}
	}

	/* ═══════════════════════════════════════════════════════════
	   ATTENTION — TRANSIENT
	   ═══════════════════════════════════════════════════════════ */

	.panel-attn-highlight {
		animation: panel-attn-highlight var(--panel-attn-duration) var(--ease-out) forwards;
	}

	@keyframes panel-attn-highlight {
		0% {
			filter: brightness(1);
		}
		15% {
			filter: brightness(1.4);
		}
		40% {
			filter: brightness(1.15);
		}
		100% {
			filter: brightness(1);
		}
	}

	.panel-attn-alert {
		animation: panel-attn-alert var(--panel-attn-duration) var(--ease-out) forwards;
	}

	@keyframes panel-attn-alert {
		0% {
			filter: brightness(1);
		}
		10% {
			filter: brightness(1.5);
		}
		25% {
			filter: brightness(1.1);
		}
		40% {
			filter: brightness(1.35);
		}
		100% {
			filter: brightness(1);
		}
	}

	.panel-attn-success {
		animation: panel-attn-success var(--panel-attn-duration) var(--ease-out) forwards;
	}

	@keyframes panel-attn-success {
		0% {
			filter: brightness(1);
		}
		15% {
			filter: brightness(1.3);
		}
		100% {
			filter: brightness(1);
		}
	}

	.panel-attn-critical {
		animation: panel-attn-critical var(--panel-critical-duration) var(--ease-out) forwards;
	}

	@keyframes panel-attn-critical {
		0% {
			filter: brightness(1);
			transform: translateX(0);
		}
		10% {
			filter: brightness(1.6);
			transform: translateX(-2px);
		}
		20% {
			filter: brightness(1.1);
			transform: translateX(2px);
		}
		30% {
			filter: brightness(1.5);
			transform: translateX(-1px);
		}
		40% {
			filter: brightness(1.1);
			transform: translateX(1px);
		}
		50% {
			filter: brightness(1.4);
			transform: translateX(0);
		}
		100% {
			filter: brightness(1);
			transform: translateX(0);
		}
	}

	/* ═══════════════════════════════════════════════════════════
	   ATTENTION — PERSISTENT
	   ═══════════════════════════════════════════════════════════ */

	.panel-attn-blackout {
		filter: brightness(0.35) saturate(0.3);
		transition:
			filter var(--duration-slow) var(--ease-default),
			opacity var(--duration-slow) var(--ease-default);
	}

	.panel-attn-dimmed {
		opacity: 0.5;
		filter: saturate(0.5);
		transition:
			filter var(--duration-slow) var(--ease-default),
			opacity var(--duration-slow) var(--ease-default);
	}

	.panel-attn-focused {
		filter: brightness(1.05);
		transform: scale(1.01);
		transition:
			filter var(--duration-normal) var(--ease-default),
			transform var(--duration-normal) var(--ease-default);
	}

	.panel-attn-locked {
		filter: brightness(0.5) saturate(0.3) blur(2px);
		opacity: 0.6;
		user-select: none;
		transition:
			filter var(--duration-slow) var(--ease-default),
			opacity var(--duration-slow) var(--ease-default);
	}

	/* ═══════════════════════════════════════════════════════════
	   AMBIENT EFFECTS
	   ═══════════════════════════════════════════════════════════ */

	.panel-ambient-pulse {
		animation: panel-ambient-pulse 4s ease-in-out infinite;
	}

	@keyframes panel-ambient-pulse {
		0%,
		100% {
			filter: brightness(1);
		}
		50% {
			filter: brightness(1.08);
		}
	}

	.panel-ambient-heartbeat {
		animation: panel-ambient-heartbeat 2s ease-in-out infinite;
	}

	@keyframes panel-ambient-heartbeat {
		0%,
		100% {
			filter: brightness(1);
		}
		14% {
			filter: brightness(1.12);
		}
		28% {
			filter: brightness(1);
		}
		42% {
			filter: brightness(1.08);
		}
		56% {
			filter: brightness(1);
		}
	}

	/* Static and scan use the overlay div — styles defined on .panel-overlay */

	/* ═══════════════════════════════════════════════════════════
	   OVERLAY
	   ═══════════════════════════════════════════════════════════ */

	.panel-overlay {
		position: absolute;
		inset: 0;
		pointer-events: none;
		z-index: 1;
	}

	/* Alert overlay: faint red wash */
	.panel-attn-alert > .panel-overlay,
	.panel-attn-critical > .panel-overlay {
		background: var(--color-red-glow);
		animation: panel-overlay-fade var(--panel-attn-duration) var(--ease-out) forwards;
	}

	@keyframes panel-overlay-fade {
		0% {
			opacity: 0;
		}
		15% {
			opacity: 1;
		}
		100% {
			opacity: 0;
		}
	}

	/* Static overlay: repeating noise pattern */
	.panel-ambient-static > .panel-overlay {
		background: repeating-linear-gradient(
			0deg,
			transparent,
			transparent 2px,
			rgba(255, 255, 255, 0.015) 2px,
			rgba(255, 255, 255, 0.015) 4px
		);
		animation: panel-static-flicker 0.15s steps(2) infinite;
	}

	@keyframes panel-static-flicker {
		0% {
			opacity: 0.4;
		}
		100% {
			opacity: 0.7;
		}
	}

	/* Scan overlay: horizontal line sweep */
	.panel-ambient-scan > .panel-overlay {
		overflow: hidden;
	}

	.panel-ambient-scan > .panel-overlay::after {
		content: '';
		position: absolute;
		left: 0;
		right: 0;
		top: 0;
		height: 2px;
		background: var(--color-accent-glow);
		box-shadow: 0 0 8px var(--color-accent-glow);
		animation: panel-scan-sweep 3s linear infinite;
	}

	@keyframes panel-scan-sweep {
		0% {
			top: 0%;
		}
		100% {
			top: 100%;
		}
	}

	/* ═══════════════════════════════════════════════════════════
	   REDUCED MOTION
	   ═══════════════════════════════════════════════════════════ */

	@media (prefers-reduced-motion: reduce) {
		.panel-enter-boot,
		.panel-enter-glitch,
		.panel-attn-highlight,
		.panel-attn-alert,
		.panel-attn-success,
		.panel-attn-critical,
		.panel-ambient-pulse,
		.panel-ambient-heartbeat {
			animation: none;
		}

		.panel-ambient-static > .panel-overlay {
			animation: none;
			opacity: 0.5;
		}

		.panel-ambient-scan > .panel-overlay::after {
			animation: none;
		}

		/* Enter animations should still resolve to visible */
		.panel-enter-boot,
		.panel-enter-glitch {
			clip-path: inset(0 0 0 0);
			opacity: 1;
		}

		/* Remove blur for reduced motion — keep dim only */
		.panel-attn-locked {
			filter: brightness(0.5) saturate(0.3);
		}
	}
</style>
