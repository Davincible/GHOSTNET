<script lang="ts">
	import type { RenderEntity, MazeGrid, ScorePopup } from '../types';
	import { PROXIMITY_ALERT_RANGE } from '../constants';

	interface Props {
		/** ASCII text of the maze (walls + data packets) */
		mazeText: string;
		/** Entities to overlay on the maze */
		entities: RenderEntity[];
		/** Current maze grid (for dimensions) */
		maze: MazeGrid | null;
		/** Whether player is in ghost mode */
		ghostMode?: boolean;
		/** Whether ghost mode is about to expire (last 2s) */
		ghostModeWarning?: boolean;
		/** Whether player is invincible (blinking) */
		invincible?: boolean;
		/** Whether player is dead (flash red) */
		dead?: boolean;
		/** Whether EMP was just deployed (screen flash) */
		empFlash?: boolean;
		/** Floating score popups */
		scorePopups?: ScorePopup[];
		/** Near-miss this tick — adjacent to a tracer */
		nearMiss?: boolean;
		/** Nearest tracer distance (for proximity glow) */
		nearestTracerDistance?: number;
		/** Danger zone — low data remaining */
		dangerZone?: boolean;
		/** Scatter/chase phase */
		scatterChasePhase?: 'scatter' | 'chase';
	}

	let {
		mazeText,
		entities,
		maze,
		ghostMode = false,
		ghostModeWarning = false,
		invincible = false,
		dead = false,
		empFlash = false,
		scorePopups = [],
		nearMiss = false,
		nearestTracerDistance = Infinity,
		dangerZone = false,
		scatterChasePhase = 'scatter',
	}: Props = $props();

	// Text grid dimensions: (logical * 2 + 1)
	let cols = $derived(maze ? maze.width * 2 + 1 : 21);
	let rows = $derived(maze ? maze.height * 2 + 1 : 15);

	// Responsive font sizing: scale so the maze fills available width.
	// Monospace ch-to-fontSize ratio is ~0.6 (IBM Plex Mono).
	const CH_RATIO = 0.602;
	let containerWidth = $state(0);
	let fontSize = $derived.by(() => {
		if (containerWidth <= 0 || cols <= 0) return 14;
		const ideal = containerWidth / (cols * CH_RATIO);
		// Clamp between 8px (tiny screens) and 20px (large monitors)
		return Math.min(20, Math.max(8, Math.floor(ideal)));
	});

	// Proximity glow intensity (0-1)
	let proximityIntensity = $derived(
		nearestTracerDistance <= PROXIMITY_ALERT_RANGE
			? 1 - (nearestTracerDistance / PROXIMITY_ALERT_RANGE)
			: 0
	);

	// Score popup opacity based on remaining lifetime
	function popupOpacity(popup: ScorePopup): number {
		const totalLife = 12; // POPUP_LIFETIME in ticks (~0.8s at 15tps)
		return Math.min(1, popup.ticksLeft / (totalLife * 0.4));
	}
</script>

<div
	class="maze-container"
	class:emp-flash={empFlash}
	class:near-miss-flash={nearMiss}
	class:danger-zone={dangerZone}
	class:chase-mode={scatterChasePhase === 'chase'}
	style="--cols: {cols}; --rows: {rows}; font-size: {fontSize}px; --proximity-intensity: {proximityIntensity}"
	bind:clientWidth={containerWidth}
>
	<!-- Proximity edge glow -->
	{#if proximityIntensity > 0 && !ghostMode}
		<div class="proximity-glow" style="opacity: {proximityIntensity * 0.6}"></div>
	{/if}

	<!-- Static maze (walls + data packets) -->
	<pre class="maze-grid">{mazeText}</pre>

	<!-- Entity overlays -->
	{#each entities as entity (entity.id)}
		<span
			class="entity entity-{entity.type}"
			class:ghost-player={entity.type === 'player' && ghostMode}
			class:invincible-player={entity.type === 'player' && invincible}
			class:dead-player={entity.type === 'player' && dead}
			class:frightened-warning={entity.type === 'tracer-frightened' && ghostModeWarning}
			class:data-danger-pulse={dangerZone && entity.type === 'power-node'}
			style="left: {entity.x}ch; top: calc({entity.y} * var(--line-h));"
		>
			{entity.char}
		</span>
	{/each}

	<!-- Score popups -->
	{#each scorePopups as popup (popup.id)}
		<span
			class="score-popup score-popup-{popup.variant}"
			style="
				left: {popup.x}ch;
				top: calc({popup.y} * var(--line-h));
				opacity: {popupOpacity(popup)};
				transform: translateY(calc(-{(12 - popup.ticksLeft) * 2}px));
			"
		>
			{popup.text}
		</span>
	{/each}
</div>

<style>
	.maze-container {
		position: relative;
		font-family: var(--font-mono);
		/* font-size set dynamically via inline style for responsive scaling */
		--line-h: 1.2em;
		line-height: var(--line-h);
		color: var(--color-accent-dim);
		overflow: hidden;
		user-select: none;
		width: 100%;
		transition: box-shadow 0.3s ease;
	}

	.maze-grid {
		margin: 0;
		white-space: pre;
		pointer-events: none;
	}

	/* Proximity edge glow — red border glow when tracers are near */
	.proximity-glow {
		position: absolute;
		inset: 0;
		pointer-events: none;
		z-index: 20;
		box-shadow: inset 0 0 20px rgba(255, 0, 0, 0.4), inset 0 0 40px rgba(255, 0, 0, 0.2);
	}

	/* Near-miss flash — brief white flash */
	.near-miss-flash {
		animation: near-miss-burst 0.15s ease-out;
	}

	@keyframes near-miss-burst {
		0% { filter: brightness(1.8) contrast(1.2); }
		100% { filter: brightness(1) contrast(1); }
	}

	/* Danger zone — maze walls pulse red */
	.danger-zone {
		animation: danger-walls 1.2s ease-in-out infinite alternate;
	}

	@keyframes danger-walls {
		from { color: var(--color-accent-dim); }
		to { color: color-mix(in srgb, var(--color-red) 30%, var(--color-accent-dim)); }
	}

	/* Chase mode — subtle border throb */
	.chase-mode {
		box-shadow: 0 0 2px rgba(255, 0, 0, 0.15);
	}

	.entity {
		position: absolute;
		z-index: 10;
		pointer-events: none;
		font-weight: bold;
		/* Tracers glide smoothly between positions */
		transition: left 120ms ease-out, top 120ms ease-out;
		will-change: left, top;
	}

	/* Player — instant snap, no transition (crisp input feel) */
	.entity-player {
		color: var(--color-accent-bright);
		text-shadow: 0 0 8px var(--color-accent-glow);
		transition: none;
	}

	.ghost-player {
		color: var(--color-cyan);
		text-shadow: 0 0 12px var(--color-cyan-glow), 0 0 24px var(--color-cyan-glow);
		animation: ghost-pulse 0.5s ease-in-out infinite alternate;
	}

	.invincible-player {
		animation: blink 0.15s step-end infinite;
	}

	.dead-player {
		color: var(--color-red);
		text-shadow: 0 0 8px var(--color-red-glow);
		animation: death-flash 0.1s step-end 3;
	}

	/* Tracers */
	.entity-tracer-patrol {
		color: var(--color-red);
	}

	.entity-tracer-hunter {
		color: #ff00ff;
		text-shadow: 0 0 4px rgba(255, 0, 255, 0.4);
	}

	.entity-tracer-phantom {
		color: var(--color-cyan);
		text-shadow: 0 0 4px var(--color-cyan-glow);
	}

	.entity-tracer-swarm {
		color: var(--color-amber);
	}

	.entity-tracer-frightened {
		color: var(--color-accent-dim);
		animation: blink 0.3s step-end infinite;
	}

	.frightened-warning {
		animation: blink 0.1s step-end infinite !important;
		color: var(--color-red) !important;
	}

	.entity-tracer-frozen {
		color: var(--color-cyan);
		opacity: 0.8;
	}

	/* Returning tracers — eyes floating home */
	.entity-tracer-returning {
		color: var(--color-text-secondary);
		opacity: 0.6;
		text-shadow: 0 0 3px var(--color-accent-glow);
		transition: left 80ms ease-out, top 80ms ease-out; /* Faster than normal — they're rushing home */
	}

	/* Power nodes */
	.entity-power-node {
		color: #ffd700;
		text-shadow: 0 0 6px rgba(255, 215, 0, 0.5);
		animation: power-pulse 1.5s ease-in-out infinite;
	}

	.data-danger-pulse {
		animation: power-danger-pulse 0.6s ease-in-out infinite !important;
	}

	/* Bonus items */
	.entity-bonus-item {
		color: #00ff88;
		text-shadow: 0 0 8px rgba(0, 255, 136, 0.6);
		animation: bonus-sparkle 0.8s ease-in-out infinite alternate;
	}

	/* Score popups */
	.score-popup {
		position: absolute;
		z-index: 30;
		pointer-events: none;
		font-weight: bold;
		font-size: 0.85em;
		color: var(--color-accent);
		text-shadow: 0 0 4px var(--color-accent-glow);
		white-space: nowrap;
		transition: transform 60ms linear, opacity 60ms linear;
	}

	.score-popup-tracer {
		color: #ff00ff;
		text-shadow: 0 0 6px rgba(255, 0, 255, 0.6);
		font-size: 1em;
	}

	.score-popup-bonus {
		color: #00ff88;
		text-shadow: 0 0 6px rgba(0, 255, 136, 0.6);
		font-size: 1em;
	}

	.score-popup-combo {
		color: #ffd700;
		text-shadow: 0 0 6px rgba(255, 215, 0, 0.6);
	}

	/* Animations */
	/* EMP screen flash */
	.emp-flash {
		animation: emp-burst 0.3s ease-out;
	}

	@keyframes emp-burst {
		0% { filter: brightness(3) saturate(0); }
		30% { filter: brightness(2) saturate(0.3); }
		100% { filter: brightness(1) saturate(1); }
	}

	@keyframes ghost-pulse {
		from {
			text-shadow: 0 0 8px var(--color-cyan-glow);
		}
		to {
			text-shadow: 0 0 16px var(--color-cyan-glow), 0 0 32px var(--color-cyan-glow);
		}
	}

	@keyframes blink {
		0%, 49% {
			opacity: 1;
		}
		50%, 100% {
			opacity: 0;
		}
	}

	@keyframes death-flash {
		0%, 49% {
			opacity: 1;
		}
		50%, 100% {
			opacity: 0;
		}
	}

	@keyframes power-pulse {
		0%, 100% {
			text-shadow: 0 0 4px rgba(255, 215, 0, 0.3);
		}
		50% {
			text-shadow: 0 0 10px rgba(255, 215, 0, 0.7);
		}
	}

	@keyframes power-danger-pulse {
		0%, 100% {
			text-shadow: 0 0 6px rgba(255, 215, 0, 0.3);
			color: #ffd700;
		}
		50% {
			text-shadow: 0 0 12px rgba(255, 0, 0, 0.6);
			color: #ff4444;
		}
	}

	@keyframes bonus-sparkle {
		from {
			text-shadow: 0 0 4px rgba(0, 255, 136, 0.3);
		}
		to {
			text-shadow: 0 0 12px rgba(0, 255, 136, 0.8), 0 0 20px rgba(0, 255, 136, 0.4);
		}
	}
</style>
