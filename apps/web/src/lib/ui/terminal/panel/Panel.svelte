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
		/** Show dash characters filling horizontal borders */
		borderFill?: boolean;
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

		// ── Visual modifiers ──
		/** Apply blur effect. `true` = content blurred + title masked, `'content'` = content blurred only (title stays readable). Borders always stay crisp. */
		blur?: boolean | 'content';
	}

	let {
		title,
		variant = 'single',
		borderColor = 'default',
		glow = false,
		borderFill = false,
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
		blur = false,
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

	// ── Background glow color ──
	// Maps border color to a CSS color value for box-shadow ambient glow
	const GLOW_COLORS: Record<string, string> = {
		default: 'var(--color-accent)',
		bright: 'var(--color-accent)',
		dim: 'var(--color-border-default)',
		cyan: 'var(--color-cyan)',
		amber: 'var(--color-amber)',
		red: 'var(--color-red)',
	};

	let glowColor = $derived(GLOW_COLORS[effectiveBorderColor] ?? 'var(--color-accent)');

	// ── Title masking ──
	// When blur={true}, replace title characters with * to obscure it while keeping borders crisp
	let effectiveTitle = $derived.by(() => {
		if (!effectsOn || blur !== true || !title) return title;
		return '*'.repeat(title.length);
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
			e.animationName === 'panel-enter-glitch' ||
			e.animationName === 'panel-enter-expand'
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
	class:panel-enter-expand={effectsOn && enterAnimation === 'expand' && !hasEntered}
	class:panel-attn-highlight={effectsOn && attention === 'highlight'}
	class:panel-attn-alert={effectsOn && attention === 'alert'}
	class:panel-attn-success={effectsOn && attention === 'success'}
	class:panel-attn-critical={effectsOn && attention === 'critical'}
	class:panel-attn-blackout={effectsOn && attention === 'blackout'}
	class:panel-attn-dimmed={effectsOn && attention === 'dimmed'}
	class:panel-attn-focused={effectsOn && attention === 'focused'}
	class:panel-glow={effectsOn && effectiveGlow}
	class:panel-blurred={effectsOn && !!blur}
	class:panel-ambient-pulse={effectsOn && ambientEffect === 'pulse'}
	class:panel-ambient-heartbeat={effectsOn && ambientEffect === 'heartbeat'}
	class:panel-ambient-static={effectsOn && ambientEffect === 'static'}
	class:panel-ambient-scan={effectsOn && ambientEffect === 'scan'}
	style:--panel-glow-color={glowColor}
	style:--panel-enter-duration={getCssDuration('boot', animationSpeed)}
	style:--panel-glitch-duration={getCssDuration('glitch', animationSpeed)}
	style:--panel-expand-duration={getCssDuration('expand', animationSpeed)}
	style:--panel-attn-duration={getCssDuration('attention', animationSpeed)}
	style:--panel-critical-duration={getCssDuration('critical', animationSpeed)}
	onanimationend={handleAnimationEnd}
>
	<Box
		title={effectiveTitle}
		{variant}
		borderColor={effectiveBorderColor}
		glow={effectiveGlow}
		{borderFill}
		{padding}
	>
		{#if scrollable}
			<div class="panel-content-wrapper" style:--panel-height={maxHeight}>
				<div
					class="panel-scroll-container"
					bind:this={scrollContainer}
					onscroll={updateScrollState}
				>
					<div class="panel-inner" class:panel-inner-blur={effectsOn && !!blur}>
						{@render children()}
					</div>
				</div>
				{#if showScrollHint && canScrollDown}
					<div class="scroll-hint scroll-hint-bottom">
						<span class="text-green-dim text-xs">&#9660; SCROLL FOR MORE</span>
					</div>
				{:else if showScrollHint && canScrollUp}
					<div class="scroll-hint scroll-hint-top">
						<span class="text-green-dim text-xs">&#9650; SCROLL UP</span>
					</div>
				{/if}
				{#if footer}
					<div class="panel-footer panel-footer-sticky">
						{@render footer()}
					</div>
				{/if}
			</div>
		{:else}
			<div class="panel-inner" class:panel-inner-blur={effectsOn && !!blur}>
				{@render children()}
			</div>
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

	/* ── Background glow — ambient halo around the panel ── */
	.panel-glow {
		box-shadow:
			0 0 12px -2px color-mix(in srgb, var(--panel-glow-color) 25%, transparent),
			0 0 30px -4px color-mix(in srgb, var(--panel-glow-color) 12%, transparent);
		transition: box-shadow var(--duration-slow) var(--ease-default);
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

	/* ── BOOT: CRT power-on ──
	   Thin horizontal line in the center → expands vertically.
	   Only start/end keyframes — the easing curve handles all the motion. */
	.panel-enter-boot {
		animation: panel-enter-boot var(--panel-enter-duration) cubic-bezier(0.16, 1, 0.3, 1) forwards;
	}

	@keyframes panel-enter-boot {
		0% {
			clip-path: inset(50% 0 50% 0);
			filter: brightness(3);
			opacity: 1;
		}
		100% {
			clip-path: inset(0 0 0 0);
			filter: brightness(1);
			opacity: 1;
		}
	}

	/* ── GLITCH: Corrupted data burst ──
	   Horizontal slice displacements, color channel splits,
	   jittery clip-path jumps. Feels broken, then resolves. */
	.panel-enter-glitch {
		animation: panel-enter-glitch var(--panel-glitch-duration) var(--ease-out) forwards;
	}

	@keyframes panel-enter-glitch {
		0% {
			clip-path: inset(0 0 100% 0);
			filter: hue-rotate(90deg) saturate(3);
			opacity: 0;
			transform: translateX(0);
		}
		15% {
			clip-path: inset(0 30% 60% 0);
			filter: hue-rotate(-60deg) saturate(2);
			opacity: 0.8;
			transform: translateX(4px);
		}
		25% {
			clip-path: inset(20% 0 30% 10%);
			filter: hue-rotate(45deg) saturate(2.5);
			transform: translateX(-6px);
		}
		35% {
			clip-path: inset(5% 15% 10% 0);
			filter: hue-rotate(-30deg) saturate(1.5);
			opacity: 0.9;
			transform: translateX(3px);
		}
		50% {
			clip-path: inset(0 5% 5% 5%);
			filter: hue-rotate(15deg) saturate(1.2);
			transform: translateX(-2px);
		}
		65% {
			clip-path: inset(3% 0 0 2%);
			filter: hue-rotate(-5deg);
			transform: translateX(1px);
		}
		80% {
			clip-path: inset(0 0 2% 0);
			filter: hue-rotate(2deg);
			transform: translateX(0);
		}
		100% {
			clip-path: inset(0 0 0 0);
			filter: hue-rotate(0deg) saturate(1);
			opacity: 1;
			transform: translateX(0);
		}
	}

	/* ── EXPAND: Left-to-right reveal ──
	   Only start/end keyframes — easing curve handles all motion. */
	.panel-enter-expand {
		animation: panel-enter-expand var(--panel-expand-duration) cubic-bezier(0.16, 1, 0.3, 1) forwards;
	}

	@keyframes panel-enter-expand {
		0% {
			clip-path: inset(0 100% 0 0);
			filter: brightness(1.5);
			opacity: 1;
		}
		100% {
			clip-path: inset(0 0 0 0);
			filter: brightness(1);
			opacity: 1;
		}
	}

	/* ═══════════════════════════════════════════════════════════
	   ATTENTION — TRANSIENT
	   ═══════════════════════════════════════════════════════════ */

	.panel-attn-highlight {
		animation: panel-attn-highlight var(--panel-attn-duration) var(--ease-out) forwards;
	}

	/* Transient attention animations: box-shadow is only set at PEAK keyframes.
	   At 0% and 100%, the browser interpolates from/to the cascade value:
	   - glow=true panels: smooth flare from/to static glow
	   - non-glow panels: smooth flare from/to nothing */
	@keyframes panel-attn-highlight {
		0% {
			filter: brightness(1);
		}
		10% {
			filter: brightness(1.5);
			box-shadow:
				0 0 20px -2px color-mix(in srgb, var(--panel-glow-color) 40%, transparent),
				0 0 50px -4px color-mix(in srgb, var(--panel-glow-color) 20%, transparent);
		}
		30% {
			filter: brightness(1.2);
			box-shadow:
				0 0 15px -2px color-mix(in srgb, var(--panel-glow-color) 30%, transparent),
				0 0 40px -4px color-mix(in srgb, var(--panel-glow-color) 15%, transparent);
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
			box-shadow:
				0 0 25px -2px color-mix(in srgb, var(--color-red) 45%, transparent),
				0 0 60px -4px color-mix(in srgb, var(--color-red) 20%, transparent);
		}
		25% {
			filter: brightness(1.1);
			box-shadow:
				0 0 15px -2px color-mix(in srgb, var(--color-red) 25%, transparent),
				0 0 35px -4px color-mix(in srgb, var(--color-red) 10%, transparent);
		}
		40% {
			filter: brightness(1.35);
			box-shadow:
				0 0 20px -2px color-mix(in srgb, var(--color-red) 35%, transparent),
				0 0 50px -4px color-mix(in srgb, var(--color-red) 15%, transparent);
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
			box-shadow:
				0 0 20px -2px color-mix(in srgb, var(--color-cyan) 40%, transparent),
				0 0 50px -4px color-mix(in srgb, var(--color-cyan) 18%, transparent);
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
			box-shadow:
				0 0 30px -2px color-mix(in srgb, var(--color-red) 50%, transparent),
				0 0 70px -4px color-mix(in srgb, var(--color-red) 25%, transparent);
		}
		20% {
			filter: brightness(1.1);
			transform: translateX(2px);
			box-shadow:
				0 0 10px -2px color-mix(in srgb, var(--color-red) 20%, transparent),
				0 0 30px -4px color-mix(in srgb, var(--color-red) 8%, transparent);
		}
		30% {
			filter: brightness(1.5);
			transform: translateX(-1px);
			box-shadow:
				0 0 25px -2px color-mix(in srgb, var(--color-red) 45%, transparent),
				0 0 60px -4px color-mix(in srgb, var(--color-red) 20%, transparent);
		}
		40% {
			filter: brightness(1.1);
			transform: translateX(1px);
			box-shadow:
				0 0 8px -2px color-mix(in srgb, var(--color-red) 15%, transparent),
				0 0 20px -4px color-mix(in srgb, var(--color-red) 6%, transparent);
		}
		50% {
			filter: brightness(1.4);
			transform: translateX(0);
			box-shadow:
				0 0 20px -2px color-mix(in srgb, var(--color-red) 35%, transparent),
				0 0 50px -4px color-mix(in srgb, var(--color-red) 15%, transparent);
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
		box-shadow:
			0 0 15px -2px color-mix(in srgb, var(--panel-glow-color) 25%, transparent),
			0 0 35px -4px color-mix(in srgb, var(--panel-glow-color) 12%, transparent);
		transition:
			filter var(--duration-normal) var(--ease-default),
			transform var(--duration-normal) var(--ease-default),
			box-shadow var(--duration-normal) var(--ease-default);
	}

	/* ═══════════════════════════════════════════════════════════
	   BLUR — content filter with crisp borders.
	   Both blur={true} and blur="content" use inner wrapper blur.
	   blur={true} also masks the title text (handled in script).
	   ═══════════════════════════════════════════════════════════ */

	.panel-blurred {
		user-select: none;
	}

	.panel-inner-blur {
		filter: blur(3px);
		user-select: none;
		transition: filter var(--duration-slow) var(--ease-default);
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
			box-shadow:
				0 0 12px -2px color-mix(in srgb, var(--panel-glow-color) 25%, transparent),
				0 0 30px -4px color-mix(in srgb, var(--panel-glow-color) 12%, transparent);
		}
		50% {
			filter: brightness(1.08);
			box-shadow:
				0 0 20px -2px color-mix(in srgb, var(--panel-glow-color) 40%, transparent),
				0 0 45px -4px color-mix(in srgb, var(--panel-glow-color) 20%, transparent);
		}
	}

	.panel-ambient-heartbeat {
		animation: panel-ambient-heartbeat 2s ease-in-out infinite;
	}

	@keyframes panel-ambient-heartbeat {
		0%,
		100% {
			filter: brightness(1);
			box-shadow:
				0 0 12px -2px color-mix(in srgb, var(--panel-glow-color) 25%, transparent),
				0 0 30px -4px color-mix(in srgb, var(--panel-glow-color) 12%, transparent);
		}
		14% {
			filter: brightness(1.12);
			box-shadow:
				0 0 24px -2px color-mix(in srgb, var(--panel-glow-color) 45%, transparent),
				0 0 50px -4px color-mix(in srgb, var(--panel-glow-color) 22%, transparent);
		}
		28% {
			filter: brightness(1);
			box-shadow:
				0 0 12px -2px color-mix(in srgb, var(--panel-glow-color) 25%, transparent),
				0 0 30px -4px color-mix(in srgb, var(--panel-glow-color) 12%, transparent);
		}
		42% {
			filter: brightness(1.08);
			box-shadow:
				0 0 18px -2px color-mix(in srgb, var(--panel-glow-color) 35%, transparent),
				0 0 40px -4px color-mix(in srgb, var(--panel-glow-color) 16%, transparent);
		}
		56% {
			filter: brightness(1);
			box-shadow:
				0 0 12px -2px color-mix(in srgb, var(--panel-glow-color) 25%, transparent),
				0 0 30px -4px color-mix(in srgb, var(--panel-glow-color) 12%, transparent);
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
		.panel-enter-expand,
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
		.panel-enter-glitch,
		.panel-enter-expand {
			clip-path: inset(0 0 0 0);
			opacity: 1;
			filter: none;
			transform: none;
		}

		/* Remove blur for reduced motion */
		.panel-inner-blur {
			filter: none;
		}
	}
</style>
